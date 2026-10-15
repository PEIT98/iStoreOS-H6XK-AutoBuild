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

# 官方 feeds 保留 packages、LuCI、routing、iStore，额外添加魔改 QModem
if ! grep -Eq '^src-git[[:space:]]+qmodem[[:space:]]' feeds.conf.default; then
  printf '\nsrc-git qmodem %s;%s\n' "${QMODEM_REPO%.git}.git" "$QMODEM_REF" >> feeds.conf.default
fi
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

make download -j"$JOBS" || make download -j1 V=s
# GitHub Actions Runner 资源可能限制大规模完整构建
make -j"$JOBS" V=sc

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
