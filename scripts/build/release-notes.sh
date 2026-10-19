#!/usr/bin/env bash
# Create a reviewable H6XK pre-release note from the exact built sources.
set -euo pipefail
out="${1:-output}"
test -s "$out/BUILD-INFO.txt"
test -s "$out/SHA256SUMS"
{
  echo '# H69K / H68K / H66K iStoreOS 25.12 预发布'
  echo
  echo '此固件先作为 Pre-release 供实机测试；确认启动、网络和模组后再手动改为正式版本。'
  echo
  echo '## 功能与补丁'
  echo
  echo '- 官方 FUjr/QModem Next、QModem Generic；USB QMI/MBIM/ECM/NCM/RNDIS 与 AT 串口。'
  echo '- TD-TECH MT5700M-CN：包含西瓜皮的 `999-add-TD-TECH-option-id.patch`，为 USB 厂商 ID `3466` 增加 option 串口匹配；不保证所有 USB 模式已实机验证。'
  echo '- mwan3 故障切换：有线 WAN → Wi-Fi 中继 wwan → QModem 动态 IPv4 拨号接口。'
  echo '- OpenClash Meta 内核、Docker、ext4/NVMe、SQM/CAKE 等已按构建配置选择。'
  echo
  echo '## 构建来源'
  echo
  echo '```text'
  cat "$out/BUILD-INFO.txt"
  echo '```'
  echo
  echo '## 镜像 SHA256'
  echo
  echo '```text'
  cat "$out/SHA256SUMS"
  echo '```'
  echo
  echo '刷机前备份配置，确认设备型号及分区布局；本镜像是 sysupgrade 格式。'
} > "$out/release-notes.md"
