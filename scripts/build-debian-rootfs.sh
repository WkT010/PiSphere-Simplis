#!/usr/bin/env bash
# Build a Debian rootfs with desktop GUI, OpenJDK and .NET runtime, optimized for mainstream PC hardware.
# Usage: sudo ./build-debian-rootfs.sh [ARCH] [TARGET_DIR] [OPTIONS]
# Example: sudo ./build-debian-rootfs.sh amd64 ./rootfs --drivers=nvidia
set -euo pipefail

ARCH=${1:-amd64}            # amd64 or arm64
TARGET_DIR=${2:-./rootfs}   # output rootfs dir
DEBIAN_SUITE=${DEBIAN_SUITE:-bookworm}  # or bullseye / jammy
DRIVER_OPTIONS=${3:-""}    # e.g. --drivers=nvidia,intel,amd

echo "ARCH=$ARCH TARGET_DIR=$TARGET_DIR SUITE=$DEBIAN_SUITE DRIVER_OPTIONS=$DRIVER_OPTIONS"

if [ "
$(id -u)" -ne 0 ]; then
  echo "Please run as root or sudo"
  exit 1
fi

# Ensure prerequisites
apt update
apt install -y debootstrap qemu-user-static binfmt-support wget ca-certificates gnupg

# Prepare target dir
mkdir -p "$TARGET_DIR"
if [ "$ARCH" = "amd64" ]; then
  debootstrap --arch=amd64 --include=sudo,ca-certificates,ssh,locales "$DEBIAN_SUITE" "$TARGET_DIR" http://deb.debian.org/debian
else
  # arm64
  debootstrap --arch=arm64 --foreign --include=sudo,ca-certificates,ssh,locales "$DEBIAN_SUITE" "$TARGET_DIR" http://deb.debian.org/debian
  cp /usr/bin/qemu-aarch64-static "$TARGET_DIR/usr/bin/"
  chroot "$TARGET_DIR" /debootstrap/debootstrap --second-stage
fi

# Basic mounts for chroot
mount --bind /proc "$TARGET_DIR/proc"
mount --bind /sys "$TARGET_DIR/sys"
mount --bind /dev "$TARGET_DIR/dev"
cp /etc/resolv.conf "$TARGET_DIR/etc/"

# Configure apt sources (enable non-free for proprietary drivers)
cat > "$TARGET_DIR/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian ${DEBIAN_SUITE} main contrib non-free
deb http://deb.debian.org/debian ${DEBIAN_SUITE}-updates main contrib non-free
deb http://security.debian.org/ ${DEBIAN_SUITE}-security main contrib non-free
EOF

# Helper to install packages in chroot
chroot_install() {
  chroot "$TARGET_DIR" /bin/bash -c "set -e; export DEBIAN_FRONTEND=noninteractive; apt update; apt install -y --no-install-recommends $*"
}

# Core packages
chroot_install sudo ca-certificates locales curl wget gnupg lsb-release systemd-sysv dbus

# Desktop stack (Wayland + XWayland + light desktop)
chroot_install xwayland wayland-protocols weston xserver-xorg lightdm xfce4 xfce4-goodies
chroot_install pulseaudio alsa-utils pavucontrol pipewire pipewire-audio-client-libraries

# GPU, firmware and microcode (common for PC hardware)
chroot_install mesa-utils mesa libgl1-mesa-dri firmware-linux firmware-misc-nonfree
chroot_install intel-microcode amd64-microcode || true

# Optional: NVIDIA driver if requested
if echo "$DRIVER_OPTIONS" | grep -q "nvidia"; then
  chroot_install nvidia-driver nvidia-kernel-dkms nvidia-utils linux-headers-
$(chroot "$TARGET_DIR" bash -lc 'uname -r' || echo '');
fi

# Java and OpenJFX
chroot_install openjdk-17-jre-headless openjdk-17-jdk openjfx

# .NET runtime (install via Microsoft repo — best-effort; adjust per distro)
chroot "$TARGET_DIR" /bin/bash -c "set -e; export DEBIAN_FRONTEND=noninteractive; wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg || true; echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main' > /etc/apt/sources.list.d/microsoft-prod.list || true; apt update || true; apt install -y dotnet-runtime-7.0 || echo 'dotnet runtime may be unavailable for suite';"

# Networking and utilities
chroot_install network-manager resolvconf openssh-server

# Clean up
chroot "$TARGET_DIR" /bin/bash -c "apt -y autoremove; apt -y clean; rm -rf /var/lib/apt/lists/*"

# Unmount
umount "$TARGET_DIR/proc" || true
umount "$TARGET_DIR/sys" || true
umount "$TARGET_DIR/dev" || true

echo "Rootfs built at: $TARGET_DIR"

echo "Post-chroot steps:
  - chroot into $TARGET_DIR and create a user, set locales, enable lightdm, configure GPU drivers if needed.
  - For UEFI images, prepare /boot and GRUB (or use live-build).
  - Add JavaFX/Avalonia test apps to /opt/tests and run smoke tests."