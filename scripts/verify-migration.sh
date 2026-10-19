#!/usr/bin/env bash
# 静态检查不联网、不触发编译。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$ROOT/scripts/build.sh" "$ROOT/scripts/prepare-features.sh" "$ROOT/scripts/build/bundle-openclash-core.sh"
for f in "$ROOT"/files/etc/uci-defaults/* "$ROOT"/files/etc/init.d/* "$ROOT"/files/etc/hotplug.d/iface/* "$ROOT"/files/usr/bin/* "$ROOT"/files/usr/libexec/rpcd/* "$ROOT"/packages/cake-autorate/files/98-cake-autorate "$ROOT"/packages/cake-autorate/files/cake-autorate-prepare "$ROOT"/packages/cake-autorate/files/cake-autorate.init; do
  [ -f "$f" ] && sh -n "$f"
done
find "$ROOT/files" -type f -name '*.json' -exec python3 -m json.tool {} \; >/dev/null
test ! -e "$ROOT/files/etc/config/network"
test ! -e "$ROOT/files/etc/config/wireless"
grep -Fxq CONFIG_TARGET_KERNEL_PARTSIZE=32 "$ROOT/.config"
grep -Fxq CONFIG_TARGET_rockchip_armv8_DEVICE_hinlink_opc-h6xk=y "$ROOT/.config"
grep -Fxq CONFIG_PACKAGE_kmod-fs-ext4=y "$ROOT/.config"
grep -Fxq CONFIG_CCACHE=y "$ROOT/.config"
for package in luci-app-diskman luci-app-autoreboot; do
  test -f "$ROOT/packages/$package/Makefile"
  grep -Fq '$(TOPDIR)/feeds/luci/luci.mk' "$ROOT/packages/$package/Makefile"
done
test -f "$ROOT/scripts/build/release-notes.sh"
grep -Fq -- '--prerelease' "$ROOT/.github/workflows/build.yml"
if grep -Eq '^CONFIG_PACKAGE_(luci-app-photonicat-power|pcat-manager-v1|luci-mod-battstatus)=y' "$ROOT/h6xk-features.config"; then
  echo 'ERROR: battery features' >&2; exit 1
fi
test "$(readlink "$ROOT/files/etc/rc.d/S01h6xk-time-floor")" = '../init.d/h6xk-time-floor'
echo 'H6XK migration static checks passed, build not launched.'
