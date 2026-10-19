#!/usr/bin/env bash
# 无需联网、无需执行固件编译。
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$ROOT/scripts/build.sh" "$ROOT/scripts/prepare-features.sh" "$ROOT/scripts/build/bundle-openclash-core.sh"
for f in "$ROOT"/files/etc/uci-defaults/* "$ROOT"/files/etc/init.d/* "$ROOT"/files/etc/hotplug.d/iface/* "$ROOT"/files/usr/bin/*; do
  [ -f "$f" ] && sh -n "$f"
done
find "$ROOT/files" -name '*.json' -type f -exec python3 -m json.tool {} \; >/dev/null
[ ! -e "$ROOT/files/etc/config/network" ]
[ ! -e "$ROOT/files/etc/config/wireless" ]
grep -Fxq CONFIG_TARGET_KERNEL_PARTSIZE=32 "$ROOT/.config"
echo 'H6XK 通用迁移静态检查通过；未做实际固件编译。'
