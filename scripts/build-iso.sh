#!/bin/bash

ISO_NAME="my-custom-linux"
ISO_DIR="iso"
ROOTFS_DIR="rootfs"
KERNEL_PATH="src/linux/arch/x86/boot/bzImage"

echo "创建可启动 ISO..."

# 创建 ISO 目录结构
mkdir -p ${ISO_DIR}/boot/grub

# 复制内核
cp ${KERNEL_PATH} ${ISO_DIR}/boot/vmlinuz

# 创建 initramfs
echo "创建 initramfs..."
cd ${ROOTFS_DIR}
find . | cpio -H newc -o | gzip > ../${ISO_DIR}/boot/initrd.img
cd ..

# 创建 GRUB 配置
cat > ${ISO_DIR}/boot/grub/grub.cfg << EOF
set timeout=10
set default=0

menuentry "My Custom Linux" {
    linux /boot/vmlinuz console=tty0 console=ttyS0
    initrd /boot/initrd.img
}

menuentry "My Custom Linux (Debug)" {
    linux /boot/vmlinuz console=tty0 console=ttyS0 debug
    initrd /boot/initrd.img
}
EOF

# 创建 ISO
grub-mkrescue -o ${ISO_NAME}.iso ${ISO_DIR}

echo "ISO 创建完成: ${ISO_NAME}.iso"
