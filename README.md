# iStoreOS H6XK 自动编译

基于 iStoreOS 官方 `istoreos-25.12` 分支（Linux 6.12 / apk 包管理器），使用 GitHub Actions 自动编译 HINLINK H6XK **H69K/H68K/H66K 合并固件**（Rockchip RK3568）。本仓库仅保存构建配置、脚本和工作流，编译时自动拉取 iStoreOS 上游源码。

## 已配置

| 组件 | 包名 / 说明 |
|---|---|
| iStoreOS | 官方 `istoreos-25.12` 分支；保留原版 feeds |
| QModem 魔改版 | [LianXia233/QModem](https://github.com/LianXia233/QModem)：`qmodem`、`luci-app-qmodem-next` |
| Realtek RTL8852BE | `kmod-rtw89-8852be`（含依赖和固件） |
| Realtek RTL8922AE | `kmod-rtw89-8922ae`（Wi-Fi 7，开启 11BE） |
| MediaTek MT7916 | `kmod-mt7915e`、`kmod-mt7916-firmware` |
| Qualcomm QCNFA765 | `kmod-ath11k-pci`、`ath11k-firmware-wcn6855` |
| 5G USB 模组 | QMI / MBIM / NCM / RNDIS / USB 串口驱动 |
| NVMe | `kmod-nvme` |

**已配置内置驱动不代表 AP 模式、160/320 MHz 或某款 5G PCIe 模组已经实机验证。** 默认 QModem 选择通用 QMI WWAN，不主动启用 PCIe MHI 驱动，以降低不同驱动相互冲突的风险。

## GitHub Actions 一键编译

打开仓库的 [Actions](https://github.com/PEIT98/iStoreOS-H6XK-AutoBuild/actions) → **Build iStoreOS H6XK** → **Run workflow**。为避免修改代码时未经确认就启动编译，本仓库仅支持手动触发 Actions，不配置 push 自动触发。首次完整编译可能受 GitHub Runner 磁盘、内存、运行时间以及上游依赖限制。

成功后到 [Releases](https://github.com/PEIT98/iStoreOS-H6XK-AutoBuild/releases) 下载固件，或者在 Actions 的 Artifacts 中获取。

## 自定义配置

- `build.env`：iStoreOS/QModem 源码和分支、编译并发数。
- `.config`：需要内置的 Wi-Fi、5G 驱动以及插件。
- `required-packages.txt`：必须被 `make defconfig` 选中的配置，缺失时直接报错停止，防止遗漏必需组件。
- `scripts/build.sh`：克隆源码、更新 feeds、编译、收集镜像及 SHA256。
- `.github/workflows/build.yml`：自动编译工作流。

## 刷机与兼容性

iStoreOS 25.12 使用 `apk` 而非 24.10 的 `opkg`；跨大版本升级建议先完整备份，并避免直接保留旧版软件包及配置。生成的 `sysupgrade.img.gz` **不能直接当作 RKDevTool 原始整盘镜像**。务必确认设备型号和刷机方法。

本仓库已经完成静态语法检查，但尚需真实 GitHub Actions 编译验证。如果上游软件包发生变化，依赖检查会报告缺失项。QModem 魔改版的许可证含额外限制，公开或商业分发前请检查原项目的授权条款。

上游：[iStoreOS](https://github.com/istoreos/istoreos) · [QModem 魔改版](https://github.com/LianXia233/QModem)
