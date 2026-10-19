#!/usr/bin/env bash
# 光影猫1通用插件迁移：不触碰设备树、H6XK 网口和电池管理。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
phase="${1:?usage: prepare-features.sh feeds|packages SOURCE}"
SRC="${2:?missing source}"
case "$phase" in
 feeds)
   grep -Eq '^src-git[[:space:]]+qmodem_generic ' "$SRC/feeds.conf.default" ||
     printf 'src-git qmodem_generic https://github.com/PEIT98/luci-app-qmodem-generic.git;main\n' >> "$SRC/feeds.conf.default"
   grep -Eq '^src-git[[:space:]]+openclash ' "$SRC/feeds.conf.default" ||
     printf 'src-git openclash https://github.com/vernesong/OpenClash.git;master\n' >> "$SRC/feeds.conf.default"
   ;;
 packages)
   for name in luci-app-cpufreq cake-autorate luci-app-diskman luci-app-autoreboot; do
     for path in "$SRC/package/$name" "$SRC/package/feeds/luci/$name" "$SRC/package/feeds/packages/$name"; do
       test ! -e "$path" || { echo "ERROR: 重名包：$path" >&2; exit 1; }
     done
     mkdir -p "$SRC/package/$name"
     cp -a "$ROOT/packages/$name/." "$SRC/package/$name/"
   done
   for name in luci-theme-aurora luci-app-aurora-config; do
     case "$name" in
       luci-theme-aurora) url=https://github.com/eamonxg/luci-theme-aurora.git ;;
       *) url=https://github.com/eamonxg/luci-app-aurora-config.git ;;
     esac
     for path in "$SRC/package/$name" "$SRC/package/feeds/luci/$name"; do
       test ! -e "$path" || { echo "ERROR: 重名主题：$path" >&2; exit 1; }
     done
     git clone --depth 1 --branch master "$url" "$SRC/package/$name"
     test -f "$SRC/package/$name/Makefile"
   done
   temp="$(mktemp -d)"
   trap 'rm -rf "$temp"' EXIT
   git clone --depth 1 --branch main https://github.com/timsaya/openwrt-bandix-plus.git "$temp/core"
   git clone --depth 1 --branch main https://github.com/timsaya/luci-app-bandix-plus.git "$temp/luci"
   test ! -e "$SRC/package/bandix-plus" && test ! -e "$SRC/package/luci-app-bandix-plus"
   mkdir -p "$SRC/package/bandix-plus" "$SRC/package/luci-app-bandix-plus"
   cp -a "$temp/core/openwrt-bandix-plus/." "$SRC/package/bandix-plus/"
   cp -a "$temp/luci/luci-app-bandix-plus/." "$SRC/package/luci-app-bandix-plus/"
   cfg="$SRC/package/bandix-plus/files/bandix_plus.config"
   grep -Fq "option enable_traffic '1'" "$cfg" || { echo "ERROR: Bandix 默认配置变化" >&2; exit 1; }
   sed -i "s/option enable_traffic '1'/option enable_traffic '0'/" "$cfg"
   mkdir -p "$SRC/files"
   cp -a "$ROOT/files/." "$SRC/files/"
   printf '%s\n' "$(($(date -u +%s) + 7200))" > "$SRC/files/etc/h6xk-time-floor"
   {
     printf 'Build time: %s\n' "$(date -u +'%Y-%m-%d %H:%M UTC')"
     printf 'Builder commit: %s\n' "${GITHUB_SHA:-unknown}"
     printf 'iStoreOS: %s\n' "$(git -C "$SRC" rev-parse HEAD)"
     printf 'QModem: %s\n' "$(git -C "$SRC/feeds/qmodem" rev-parse HEAD)"
     printf 'Aurora theme: %s\n' "$(git -C "$SRC/package/luci-theme-aurora" rev-parse HEAD)"
   } > "$SRC/files/etc/h6xk-build-info"
   ;;
 *) echo "Unknown phase $phase" >&2; exit 2 ;;
esac
