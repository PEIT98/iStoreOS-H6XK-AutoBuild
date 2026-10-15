#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/build.env"
SOURCE="$ROOT/workdir/istoreos"
OUTPUT="$ROOT/output"
JOBS="${BUILD_JOBS:-2}"
mkdir -p "$ROOT/workdir" "$OUTPUT"

if [[ ! -d "$SOURCE/.git" ]]; then
  git clone --depth 1 --single-branch --branch "$ISTOREOS_REF" "$ISTOREOS_REPO" "$SOURCE"
fi
cd "$SOURCE"
printf 'iStoreOS revision: %s\n' "$(git rev-parse HEAD)"

# 西瓜皮项目的 TD-TECH 5700 串口匹配补丁，仅作用于 Rockchip 6.12 内核。
PATCH_NAME=999-add-TD-TECH-option-id.patch
PATCH_DIR="$SOURCE/target/linux/rockchip/patches-6.12"
if [[ ! -d "$PATCH_DIR" ]]; then
  echo "ERROR: 未找到 Rockchip 6.12 内核补丁目录：$PATCH_DIR" >&2
  exit 23
fi
if [[ -e "$PATCH_DIR/$PATCH_NAME" ]]; then
  if ! cmp -s "$ROOT/patches/$PATCH_NAME" "$PATCH_DIR/$PATCH_NAME"; then
    echo "ERROR: 上游已存在不同内容的 $PATCH_NAME，请检查后再编译。" >&2
    exit 23
  fi
else
  install -m 0644 "$ROOT/patches/$PATCH_NAME" "$PATCH_DIR/$PATCH_NAME"
fi
echo "已安装 TD-TECH 0x3466 串口补丁：$PATCH_DIR/$PATCH_NAME"

# 保留 iStoreOS 官方 feeds；仅对 qmodem feed 采用 FUjr 官方版本
# 即使上游将来加入其它 qmodem feed，这里也明确使用 build.env 中配置的官方地址
sed -i '/^src-git[[:space:]]\+qmodem[[:space:]]/d' feeds.conf.default
printf '\nsrc-git qmodem %s;%s\n' "${QMODEM_REPO%.git}.git" "$QMODEM_REF" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a
cp "$ROOT/.config" .config
make defconfig

# 检查依赖是否真的使关键驱动和插件生效
failed=0
while IFS= read -r item; do
  [[ -z "$item" || "$item" == \#* ]] && continue
  if ! grep -Fqx "${item}=y" .config; then
    echo "ERROR: 必需配置未启用：${item}=y" >&2
    failed=1
  fi
done < "$ROOT/required-packages.txt"
if (( failed )); then
  echo '检查软件包名称、依赖条件和 repository root .config。' >&2
  exit 21
fi
echo '===== iStoreOS 25.12 + H6XK + QModem + Wi-Fi 配置检查通过 ====='
grep -E '^CONFIG_(TARGET_rockchip_armv8_DEVICE_hinlink_opc-h6xk|PACKAGE_(qmodem|luci-app-qmodem-next|kmod-rtw89-8852be|kmod-rtw89-8922ae|kmod-mt7915e|kmod-ath11k-pci))=y' .config

# 完整日志存到 output，避免超大 Actions 日志超出 GitHub/接口读取上限。
# 45 秒输出一次进度；编译失败则打印日志尾部和相关错误，供快速定位。
run_logged() {
  local stage="$1" logfile="$2"
  shift 2
  echo "===== ${stage}: $* ====="
  "$@" > "$logfile" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 45
    echo "===== ${stage} 仍在进行 $(date -u +'%F %T UTC') ====="
    tail -n 3 "$logfile" || true
    df -h . | tail -n 1 || true
  done
  if wait "$pid"; then
    echo "===== ${stage} 完成 ====="
    return 0
  else
    local status=$?
    echo "::error::${stage} 失败，退出码 ${status}；完整日志在 ${logfile}"
    echo "===== ${stage} 日志最后 150 行 ====="
    tail -n 150 "$logfile" || true
    echo "===== ${stage} 错误摘要（最近 100 条） ====="
    (grep -Ei '(^|[^a-z])(error:|fatal:|failed|failure|No space left|Killed|Error [0-9]+|out of memory)' "$logfile" || true) | tail -n 100
    return "$status"
  fi
}
run_logged "下载（并发）" "$OUTPUT/download.log" make download -j"$JOBS" || \
  run_logged "下载（单线程重试）" "$OUTPUT/download-retry.log" make download -j1 V=s
# 用 V=s 记录关键命令，避免 V=sc 产生数十 MB 的无关屏幕输出
run_logged "固件编译" "$OUTPUT/build.log" make -j"$JOBS" V=s

find bin/targets/rockchip/armv8 -maxdepth 1 -type f -name '*hinlink_opc-h6xk*sysupgrade.img.gz' -print -exec cp -v {} "$OUTPUT/" \;
if ! compgen -G "$OUTPUT/*sysupgrade.img.gz" >/dev/null; then
  echo 'ERROR: 编译完成但未找到 H6XK sysupgrade.img.gz 固件。' >&2
  exit 22
fi
(
  cd "$OUTPUT"
  sha256sum -- *sysupgrade.img.gz > SHA256SUMS
)
{
  printf 'iStoreOS source: %s\n' "$ISTOREOS_REPO"
  printf 'iStoreOS branch: %s\n' "$ISTOREOS_REF"
  printf 'iStoreOS commit: %s\n' "$(git rev-parse HEAD)"
  printf 'QModem repo: %s\n' "$QMODEM_REPO"
  printf 'QModem ref: %s\n' "$QMODEM_REF"
  [[ -d feeds/qmodem/.git ]] && printf 'QModem commit: %s\n' "$(git -C feeds/qmodem rev-parse HEAD)"
} > "$OUTPUT/BUILD-INFO.txt"
echo "固件与校验文件已生成：$OUTPUT"
