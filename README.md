# Minimal x86 Kernel - built in Zig

A minimal bare-metal kernel written entirely in Zig (zero assembly files).
It boots on an x86 (i386) machine via the Multiboot 1 protocol and prints a
coloured greeting to the VGA text-mode display, then halts the CPU.

The project is designed to be cross-compiled from any host (including Apple
Silicon Macs) and tested instantly with QEMU — no ISO image, no GRUB
installation, no bootloader binaries required.

## What it does

1. QEMU loads the ELF binary using its built-in Multiboot 1 support.
2. The CPU starts in 32-bit protected mode at the `_start` entry point.
3. `_start` sets up a 16 KiB stack and jumps to `kmain`.
4. `kmain` clears the VGA text buffer and writes a message to the screen.
5. The CPU enters an infinite `hlt` loop.

## Preconditions

| Tool | Version | Install |
|------|---------|---------|
| **Zig** | 0.14.0+ | [ziglang.org/download](https://ziglang.org/download/) or `brew install zig` |
| **QEMU** | any recent | `brew install qemu` / `nix-env -iA nixpkgs.qemu` |

No other dependencies. Zig bundles its own LLVM back-end and linker, so
cross-compilation to `x86-freestanding-none` works out of the box on any host
OS and architecture (macOS ARM, Linux x86_64, etc.).

## How to run

```bash
# Build the kernel (produces zig-out/bin/kernel)
zig build

# Boot it in QEMU (opens a graphical VGA window)
zig build run

# Or use the helper script (curses mode, auto-kills after a few seconds)
chmod +x run.sh
./run.sh
```

To run QEMU manually with custom flags:

```bash
qemu-system-i386 -kernel zig-out/bin/kernel
```

You should see this:

<img width="623" height="239" alt="Screenshot 2026-02-17 at 23 58 16" src="https://github.com/user-attachments/assets/e53f6920-c06b-4586-b551-6b916a7b3d5a" />

## Project structure

```
zig-kernel/
├── build.zig          Zig build script (target, linker, QEMU run step)
├── build.zig.zon      Package manifest
├── linker.ld          Linker script (section layout, entry point)
├── run.sh             Quick-test shell script
└── src/
    └── main.zig       Entire kernel: Multiboot header, VGA driver, kmain
```

## System diagram

```
 HOST (macOS ARM / any OS)                    EMULATED x86 MACHINE (QEMU)
 ─────────────────────────                    ──────────────────────────────

 ┌──────────────┐   zig build    ┌────────────────────┐
 │  src/main.zig│───────────────▶│  zig-out/bin/kernel│  (i386 ELF binary)
 │  linker.ld   │  cross-compile │  Multiboot 1 magic │
 │  build.zig   │  x86-free-     │  at offset 0       │
 └──────────────┘  standing-none └─────────┬──────────┘
                                          │
                               qemu-system-i386 -kernel
                                          │
                                          ▼
                               ┌──────────────────────┐
                               │      QEMU / TCG      │
                               │  (x86 CPU emulation) │
                               └─────────┬────────────┘
                                          │
                    ┌─────────────────────┼───────────────────────┐
                    │   Emulated i386 hardware                    │
                    │                     │                       │
                    │   1. Multiboot      │                       │
                    │      loader reads   ▼                       │
                    │      ELF, puts   ┌───────────┐              │
                    │      CPU in      │  _start   │  32-bit      │
                    │      protected   │  (naked)  │  protected   │
                    │      mode        └────┬──────┘  mode        │
                    │                       │                     │
                    │              set up   │ stack               │
                    │                       ▼                     │
                    │                 ┌──────────┐                │
                    │                 │  kmain   │                │
                    │                 └────┬─────┘                │
                    │                      │                      │
                    │          ┌───────────┼───────────┐          │
                    │          │           │           │          │
                    │          ▼           ▼           ▼          │
                    │   clearScreen()  print(...)   hlt loop      │
                    │          │           │                      │
                    │          ▼           ▼                      │
                    │   ┌──────────────────────────────────┐      │
                    │   │  VGA Text Buffer at 0xB8000      │      │
                    │   │  80×25 grid, 16-bit per cell     │      │
                    │   │  (ASCII byte + colour attribute) │      │
                    │   └──────────────────────────────────┘      │
                    │                     │                       │
                    └─────────────────────┼───────────────────────┘
                                          │
                                          ▼
                               ┌──────────────────────┐
                               │   QEMU VGA Window    │
                               │                      │
                               │  ════════════════    │
                               │  Hello from the      │
                               │    Zig Kernel!       │
                               │  ════════════════    │
                               │                      │
                               └──────────────────────┘
```

## Key technical details

- **Target:** `x86-freestanding-none` — 32-bit, no OS, no libc
- **Boot protocol:** Multiboot 1 — a 12-byte header (magic `0x1BADB002`,
  flags, checksum) placed in the first 8 KiB of the ELF
- **VGA output:** Direct memory-mapped I/O to `0xB8000` using Zig's
  `volatile` pointer semantics — no drivers, no BIOS calls
- **Red zone:** Disabled — the System V ABI red zone would be corrupted by
  hardware interrupts
- **SSE/AVX:** Disabled — avoids the need to save/restore FPU state
- **No assembly files:** The Multiboot header is a Zig `extern struct`
  exported to a linker section; the entry point uses inline `asm volatile`
