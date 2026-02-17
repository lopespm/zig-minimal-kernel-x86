const std = @import("std");

// ── Multiboot 1 header ──────────────────────────────────────────────────
// Must reside in the first 8 KiB of the binary (placed by the linker script
// into the `.multiboot` section).
const MULTIBOOT_MAGIC: u32 = 0x1BADB002;
const MULTIBOOT_FLAGS: u32 = 0x00; // no special flags
const MULTIBOOT_CHECKSUM: u32 = @as(u32, 0) -% MULTIBOOT_MAGIC -% MULTIBOOT_FLAGS;

const MultibootHeader = extern struct {
    magic: u32 = MULTIBOOT_MAGIC,
    flags: u32 = MULTIBOOT_FLAGS,
    checksum: u32 = MULTIBOOT_CHECKSUM,
};

// Export the header into the .multiboot section so the linker script can
// place it at the very beginning of the binary where GRUB/QEMU expect it.
export const multiboot_header: MultibootHeader linksection(".multiboot") = .{};

// ── Stack ────────────────────────────────────────────────────────────────
// 16 KiB stack, placed in .bss (zero-initialised).
const STACK_SIZE = 16 * 1024;
export var stack_bytes: [STACK_SIZE]u8 align(16) linksection(".bss") = undefined;

// ── Entry point ──────────────────────────────────────────────────────────
// Naked calling convention: we control the prologue ourselves.
// Multiboot drops us here in 32-bit protected mode, no stack set up.
export fn _start() callconv(.naked) noreturn {
    // Point the stack pointer to the top of our stack buffer, then call kmain.
    asm volatile (
        \\.extern stack_bytes
        \\lea stack_bytes + 16384, %%esp
        \\jmp kmain
    );
}

// ── VGA text-mode driver ─────────────────────────────────────────────────
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER: u32 = 0xB8000;

const Color = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,
};

fn vgaEntry(char: u8, fg: Color, bg: Color) u16 {
    const color: u8 = @as(u8, @intFromEnum(bg)) << 4 | @intFromEnum(fg);
    return @as(u16, color) << 8 | char;
}

fn clearScreen() void {
    const vga: [*]volatile u16 = @ptrFromInt(VGA_BUFFER);
    for (0..VGA_WIDTH * VGA_HEIGHT) |i| {
        vga[i] = vgaEntry(' ', .light_grey, .black);
    }
}

fn print(msg: []const u8, row: usize, col: usize, fg: Color, bg: Color) void {
    const vga: [*]volatile u16 = @ptrFromInt(VGA_BUFFER);
    for (msg, 0..) |byte, i| {
        vga[(row * VGA_WIDTH) + col + i] = vgaEntry(byte, fg, bg);
    }
}

// ── Kernel main ──────────────────────────────────────────────────────────
export fn kmain() noreturn {
    clearScreen();

    print("========================================", 1, 20, .light_cyan, .black);
    print("   Hello from the Zig Kernel!           ", 2, 20, .light_green, .black);
    print("   Running on bare-metal x86 hardware   ", 3, 20, .white, .black);
    print("========================================", 4, 20, .light_cyan, .black);

    print("Kernel booted successfully.", 6, 27, .yellow, .black);

    // Halt the CPU in a loop — nothing else to do.
    while (true) {
        asm volatile ("hlt");
    }
}

// ── Panic handler ────────────────────────────────────────────────────────
// Required when using freestanding — the default handler tries to use OS
// facilities that don't exist here.
pub const panic = std.debug.no_panic;
