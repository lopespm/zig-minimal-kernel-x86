const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Target: 32-bit x86, freestanding (no OS), no ABI.
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        // Disable SSE/AVX so the kernel doesn't need FPU state management.
        .cpu_features_sub = std.Target.x86.featureSet(&.{
            .sse,
            .sse2,
        }),
    });

    const kernel_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // Disable the red zone — interrupts would corrupt it.
        .red_zone = false,
    });

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_module = kernel_mod,
    });

    kernel.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(kernel);

    // ── QEMU run step ────────────────────────────────────────────────
    // `zig build run` will build the kernel and launch it in QEMU.
    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-i386",
        "-kernel",
    });
    run_cmd.addArtifactArg(kernel);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Boot the kernel in QEMU");
    run_step.dependOn(&run_cmd.step);
}
