#!/bin/bash
# scripts/build-busybox.sh

BUSYBOX_VERSION="1.36"

echo "下载 BusyBox..."
if [ ! -d "src/busybox" ]; then
    wget https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
    tar -xf busybox-${BUSYBOX_VERSION}.tar.bz2
    mv busybox-${BUSYBOX_VERSION} src/busybox
fi

cd src/busybox

echo "配置 BusyBox..."
cp ../../config/busybox.config .config
make oldconfig

echo "编译 BusyBox..."
make -j$(nproc)
make install

cd ../..

echo "创建根文件系统结构..."
mkdir -p rootfs/{bin,dev,etc,home,lib,lib64,mnt,opt,proc,root,run,sbin,sys,tmp,usr,var}
mkdir -p rootfs/usr/{bin,lib,sbin}
mkdir -p rootfs/var/log

echo "安装 BusyBox..."
cp -a src/busybox/_install/* rootfs/

echo "创建设备节点..."
sudo mknod rootfs/dev/console c 5 1
sudo mknod rootfs/dev/null c 1 3
sudo mknod rootfs/dev/zero c 1 5
sudo mknod rootfs/dev/tty c 5 0
sudo mknod rootfs/dev/tty0 c 4 0
