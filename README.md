# iStoreOS H6XK 自动编译

基于 iStoreOS 官方 `istoreos-25.12` 分支（Linux 6.12 / apk 包管理器），使用 GitHub Actions 自动编译 HINLINK H6XK **H69K/H68K/H66K 合并固件**（Rockchip RK3568）。本仓库仅保存构建配置、脚本和工作流，编译时自动拉取 iStoreOS 上游源码。

## 已配置

| 组件 | 包名 / 说明 |
|---|---|
| iStoreOS | 官方 `istoreos-25.12` 分支；保留原版 feeds |
| QModem 官方版 | [FUjr/QModem](https://github.com/FUjr/QModem)：`qmodem`、`luci-app-qmodem-next`，不打自定义补丁 |
| Realtek RTL8852BE | `kmod-rtw89-8852be`（含依赖和固件） |
| Realtek RTL8922AE | `kmod-rtw89-8922ae`（Wi-Fi 7，开启 11BE） |
| MediaTek MT7916 | `kmod-mt7915e`、`kmod-mt7916-firmware` |
| Qualcomm QCNFA765 | `kmod-ath11k-pci`、`ath11k-firmware-wcn6855` |
| 5G USB 模组 | QModem USB：QMI / ECM / MBIM / NCM / RNDIS，华为 NCM，以及 `ttyUSB` / `ttyACM` AT 串口 |
| TD-TECH 5700 | 沿用[西瓜皮项目补丁](https://github.com/zzzz0317/immortalwrt-xgp-auto-build/blob/main/999-add-TD-TECH-option-id.patch)，增加 USB 厂商 ID `0x3466` 的六组串口接口匹配；仍需 `kmod-usb-serial-option` |
| NVMe | `kmod-nvme` |

**已配置内置驱动不代表 AP 模式、160/320 MHz 或某款 5G PCIe 模组已经实机验证。** 默认 QModem 选择通用 QMI WWAN，不主动启用 PCIe MHI 驱动，以降低不同驱动相互冲突的风险。

## GitHub Actions 一键编译

打开仓库的 [Actions](https://github.com/PEIT98/iStoreOS-H6XK-AutoBuild/actions) → **Build iStoreOS H6XK** → **Run workflow**。为避免修改代码时未经确认就启动编译，本仓库仅支持手动触发 Actions，不配置 push 自动触发。首次完整编译可能受 GitHub Runner 磁盘、内存、运行时间以及上游依赖限制。

成功后到 [Releases](https://github.com/PEIT98/iStoreOS-H6XK-AutoBuild/releases) 下载固件，或者在 Actions 的 Artifacts 中获取。

## 自定义配置

- `build.env`：iStoreOS/QModem 源码和分支、编译并发数。
- `.config`：需要内置的 Wi-Fi、5G 驱动以及插件。
- `required-packages.txt`：必须被 `make defconfig` 选中的配置，缺失时直接报错停止，防止遗漏必需组件。
- `patches/999-add-TD-TECH-option-id.patch`：西瓜皮项目的 TD-TECH 串口补丁，构建时放入 iStoreOS Rockchip 6.12 的内核补丁目录。
- `scripts/build.sh`：克隆源码、更新 feeds、编译、收集镜像及 SHA256。
- `.github/workflows/build.yml`：自动编译工作流。

## 刷机与兼容性

H6XK 合并镜像的内核启动分区设为 **32 MiB**（iStoreOS 默认 16 MiB），根分区仍为 1 GiB。升级前请备份；如果设备仍使用旧的 16 MiB 分区布局，应先确认所用刷机方式会更新分区表，不能仅把新内核写入旧分区。

iStoreOS 25.12 使用 `apk` 而非 24.10 的 `opkg`；跨大版本升级建议先完整备份，并避免直接保留旧版软件包及配置。生成的 `sysupgrade.img.gz` **不能直接当作 RKDevTool 原始整盘镜像**。务必确认设备型号和刷机方法。

此前曾使用第三方 QModem 分支；现在已恢复为 FUjr 官方仓库，构建脚本不再拉取魔改分支。保留官方 QModem 的 `qmodem`、`luci-app-qmodem-next` 以及已配置的通用 QMI 驱动选择。提交代码不会自动触发编译；请手动运行 Actions 验证。QModem 官方仓库许可证包含额外使用限制，公开或商业分发前请查看其 LICENSE。

上游：[iStoreOS](https://github.com/istoreos/istoreos) · [QModem 官方版](https://github.com/FUjr/QModem)

## 编译失败排查

工作流运行失败时，会在 Actions 页面打印该步骤最近 150 行日志以及错误摘要，并上传 `iStoreOS-H6XK-build-logs` Artifact（包含完整 `build.log` 与下载日志）。此日志仅用于排错，不包含可刷写的固件。注意：旧的 Actions 运行不能使用新提交的代码；提交后仍须手动点击 `Run workflow` 启动新版本构建。

## 光影猫1通用功能移植（H6XK）

- 保留 iStoreOS 25.12、H6XK 官方设备树、32 MiB 启动分区、网络配置和 root 密码。
- 移植 Generic QModem WebUI、OpenClash（带 arm64 稳定版内核）、Aurora、文件管理、Statistics、Travelmate、SQM、CAKE 自动限速、mwan3、Docker、Bandix Plus、CPU 调频、DiskMan、网页终端等通用组件。
- mwan3 顺序：有线 WAN → Wi-Fi 中继 wwan → 动态 QModem（不固定为 wwan_5g）。
- 不移植光影猫电池、PMU/MCU、pcat-manager、QCA9377 SDIO 板级补丁、光影猫 IP/SSID/密码及其专用在线升级。
- Bandix Plus、cake-autorate、Travelmate 默认不启用；不修改现有 APN 和用户自定义 WAN。
- 无 RTC 时最低时间设为固件构建时间 +2 小时，之后仍由 NTP 校正。
- 仅支持手动触发编译；离线静态检查：bash scripts/verify-migration.sh。
