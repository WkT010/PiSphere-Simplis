#!/bin/bash

set -e

echo "开始构建 PiSphere Simplis x64..."

# 清理之前的构建
# rm -rf iso/*.iso rootfs/* src/linux src/busybox

# 构建各组件
echo "=== 构建内核 ==="
./scripts/build-kernel.sh

echo "=== 构建根文件系统 ==="
./scripts/build-busybox.sh

echo "=== 创建 ISO ==="
./scripts/build-iso.sh

echo "构建完成!"
echo "生成的 ISO: pisphere.iso"
