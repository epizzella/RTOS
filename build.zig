const std = @import("std");
const cpu = std.Target.arm.cpu;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cpu_model = target.query.cpu_model;
    if (cpu_model == cpu.cortex_m0 or cpu_model == cpu.cortex_m0plus) {
        //include armv6m assembly
    } else if (cpu_model == cpu.cortex_m3 or cpu_model == cpu.cortex_m4 or cpu_model == cpu.cortex_m7) {
        @compileError("Compile Error Test");
        //include armv7m assembly
    } else {
        @compileError("Unsupported architecture selected.");
    }

    _ = b.addModule("RTOS", .{
        .root_source_file = b.path("os.zig"),
        .target = target,
        .optimize = optimize,
    });
}
