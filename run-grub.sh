#!/bin/bash
set -e

echo "=== Building Zig Kernel ==="
zig build

echo "=== Preparing ISO directory ==="
mkdir -p iso/boot/grub
cp zig-out/bin/kernel iso/boot/kernel

cat > iso/boot/grub/grub.cfg <<'EOF'
set timeout=3
set default=0

menuentry "Zig Kernel" {
    multiboot /boot/kernel
    boot
}
EOF

echo "=== Building GRUB ISO via Docker (amd64) ==="
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  ubuntu:22.04 bash -c \
  "apt-get update -qq && \
   apt-get install -y -qq grub-pc-bin grub-common xorriso mtools > /dev/null 2>&1 && \
   grub-mkrescue -o zig-kernel.iso iso/"

echo "=== ISO created: zig-kernel.iso ($(du -h zig-kernel.iso | cut -f1)) ==="

echo "=== Booting in QEMU ==="
qemu-system-i386 -cdrom zig-kernel.iso
