# PiSphere Simplis — 桌面 GUI 支持说明（v1.2.103）

本文件说明如何为 PiSphere Simplis v1.2.103 构建面向主流 PC 主板与其他硬件的带桌面 GUI 的镜像（包含 Java/.NET GUI 运行时与钉钉客户端的集成建议）。

## 目标
- 支持主流 PC 主板（x86_64 UEFI/Legacy）及常见 ARM 平台的桌面 GUI。
- 提供可启动的桌面环境（Wayland 或 X11）；
- 支持 JavaFX（OpenJFX）与 .NET GUI（Avalonia/GtkSharp）应用运行；
- 支持钉钉桌面或通过 Waydroid/容器运行 Android 客户端；
- 产出可在主流 PC 硬件上运行的镜像与安装方案，并提供 QA 测试矩阵。

## 支持的硬件范围（优先级）
1. x86_64 台式机/笔记本（Intel/AMD CPU）——首要支持对象；
2. 搭载 Intel/AMD/NVIDIA GPU 的系统（集成/独立显卡）；
3. 常见外围设备：声卡、网卡（有线/无线）、摄像头、蓝牙、触摸板；
4. ARM 单板（Raspberry Pi 4/5、常见 ARM 开发板）——次要支���，需特别固件。

## 高层次方案（面向 PC 硬件）
1. 基础镜像方式：使用 debootstrap（Debian/Ubuntu remaster）以最快速覆盖 x86_64 桌面场景；
2. 图形栈：优先 Wayland + XWayland（现代、性能优越）；保留 Xorg 以保证兼容老应用；
3. 桌面环境：推荐 XFCE/LXQt（体积较小，适配性强）或 KDE/GNOME（资源允许时）；
4. Display Manager：lightdm/sddm/gdm3（根据桌面环境选择）；
5. GPU 驱动与加速：
   - Intel：mesa + modesetting（通常无需专有驱动），可安装 intel-microcode；
   - AMD：mesa + firmware-amd-graphics；
   - NVIDIA：使用 nvidia-driver（non-free，需 DKMS 与 kernel headers 或使用 nouveau）；
6. Java/.NET：OpenJDK 17/21 + OpenJFX；.NET 7/8 runtime 或 Mono；建议使用 Avalonia 或 GtkSharp 编写 Linux GUI 应用；
7. 钉钉：
   - 若存在官方 Linux .deb/.rpm，直接打包入镜像；
   - 若无，推荐使用 Waydroid（运行 Android 客户端）或 Electron/Wine 整合（稳定性不同），或提供容器化运行；
8. 引导：支持 UEFI（推荐）与 Legacy BIOS，引导分区使用 GRUB（x86_64）并提供签名内核选项以支持 Secure Boot（可选）。

## 包与软件清单（Debian 示例，按需开启 non-free）
- 基础工具：sudo, ssh, locales, curl, wget, ca-certificates
- 图形：wayland-protocols, xwayland, xserver-xorg, mesa, xserver-xorg-video-*（可选）
- 桌面与管理器：xfce4 or lxde-core, lightdm/sddm/gdm3, network-manager, policykit-1
- 音视频：pipewire or pulseaudio, alsa-utils, ffmpeg
- GPU/固件：firmware-linux, firmware-misc-nonfree, firmware-amd-graphics, intel-microcode, amd64-microcode
- NVIDIA（可选/非自由）：nvidia-driver, nvidia-kernel-dkms, nvidia-utils
- Java/.NET：openjdk-17-jre-headless, openjdk-17-jdk, openjfx, dotnet-runtime-7.0 (或 dotnet 8), mono-runtime

## 安装与构建步骤概要（PC 案例）
1. 运行 scripts/build-debian-rootfs.sh (ARCH=amd64 默认) 生成 rootfs；
2. 在 chroot 中安装并配置显示管理器与桌面环境；
3. 针对目标硬件安装额外驱动（例如 NVIDIA），并安装相应 kernel-headers/DKMS；
4. 打包成镜像（.img/.iso）并制作可启动介质（UEFI 支持）；
5. 在 QEMU 与实际 PC 上测试引导与桌面环境；

## 针对主流 PC 的额外注意事项
- UEFI 与 Secure Boot：若启用 Secure Boot，需要对内核模块与驱动签名（尤其是 nvidia dkms 模块、第三方模块）；
- 内核配置：开启 modesetting、DRM、KMS、cgroups、namespaces、FUSE；
- 电源管理：安装 tlp、acpi-support，以适配笔记本电源管理；
- 多媒体权���：为浏览器/钉钉等配置 PipeWire 或 PulseAudio；
- 多显示器与 HiDPI：测试 XWayland/Wayland 下的缩放与多显示器布局；

## 测试矩阵（建议）
- CPU 平台：Intel CPU (i5/i7), AMD Ryzen (桌面/移动)
- GPU：Intel integrated, AMD (Radeon), NVIDIA (GeForce 10/20/30/40 系列)
- 驱动模式：mesa + nouveau / nvidia proprietary
- Peripherals：Wi-Fi (Intel/Realtek), Bluetooth, Webcam, Audio chipset (Realtek)
- 软件测试：JavaFX demo, Avalonia demo, 钉钉登录/消息/音视频测试

## QA 与验证步骤
1. 启动并登录 GUI，检查 display manager、session；
2. 运行 JavaFX demo：java -jar HelloFX.jar；
3. 运行 .NET GUI demo (Avalonia)：dotnet run 或 dotnet HelloAvalonia.dll；
4. 启动钉钉并登录，测试聊天与音视频（如可以）；
5. 验证 GPU 加速（vblank、egl、vaapi/vaapi-driver、vdpau 或 vulkan 工具）；

## CI/CD 与自动化测试建议
- 在 CI（GitHub Actions 或自托管 runner）中执行：
  - 构建 rootfs -> 打包镜像 -> QEMU 启动 -> 执行 smoke tests（systemd active, X/Wayland running, run JVM/.NET smoke app）；
- 为 NVIDIA/专有驱动测试准备物理机或自托管 runner。

## 部署与发布
- 标注版本文件 VERSION = 1.2.103；
- 生成 release artifacts（.img / .tar.gz / checksums）并发布 GitHub Release；

## 安全与许可
- 保持内核与关键组件及时打补丁；
- non-free 驱动需注意再分发条款（NVIDIA 驱动通常为闭源）；
- PiSphere Simplis 仓库采用 AGPL-3.0，确保与第三方二进制再分发合规.