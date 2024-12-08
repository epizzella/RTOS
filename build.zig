const std = @import("std");
const cpu = std.Target.arm.cpu;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rtos = b.addModule("RTOS", .{
        .root_source_file = b.path("os.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cpu_model = target.query.cpu_model.explicit;
    if (cpu_model == &cpu.cortex_m0 or cpu_model == &cpu.cortex_m0plus) {
        //include armv6m assembly
    } else if (cpu_model == &cpu.cortex_m3 or cpu_model == &cpu.cortex_m4 or cpu_model == &cpu.cortex_m7) {
        rtos.addAssemblyFile(b.path("source/arch/arm-cortex-m/armv7m.s"));
        if (target.query.abi) |abi| {
            if (abi == std.Target.Abi.eabihf) {
                rtos.addCMacro("__HARD_FLOAT__", "");
            }
        }
    } else {
        @compileError("Unsupported architecture selected.");
    }
}
