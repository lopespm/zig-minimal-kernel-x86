#!/usr/bin/env bash
set -euo pipefail

# Build the kernel
zig build

# Launch QEMU with the kernel
qemu-system-i386 -kernel zig-out/bin/kernel -display curses 2>&1 &
QEMU_PID=$!
sleep 13
kill $QEMU_PID 2>/dev/null
echo "QEMU launched and terminated successfully"
