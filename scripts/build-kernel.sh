#!/bin/bash

KERNEL_VERSION="6.1"
ARCH="x86_64"
NUM_JOBS=$(nproc)

echo "下载 Linux 内核..."
if [ ! -d "src/linux" ]; then
    git clone --depth 1 --branch v${KERNEL_VERSION} \
        https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git src/linux
fi

cd src/linux

echo "配置内核..."
cp ../../config/kernel.config .config
make olddefconfig

# 自定义配置
make menuconfig

echo "编译内核..."
make -j${NUM_JOBS}

echo "安装内核模块..."
make modules_install INSTALL_MOD_PATH=../../rootfs

cd ../..
echo "内核构建完成!"
