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

    const cpu_model = target.result.cpu.model.*;

    if (std.meta.eql(cpu_model, cortex_m0) or std.meta.eql(cpu_model, cortex_m0p)) {
        std.log.info("armv6m", .{});
        //include armv6m assembly
    } else if (std.meta.eql(cpu_model, cortex_m3) or std.meta.eql(cpu_model, cortex_m4) or std.meta.eql(cpu_model, cortex_m7)) {
        std.log.info("armv7m", .{});
        if (target.query.abi) |abi| {
            if (abi == std.Target.Abi.eabihf) {
                //rtos.addCMacro("__HARD_FLOAT__", "");
            }
        }

        rtos.addAssemblyFile(b.path("source/arch/arm-cortex-m/armv7m.s"));
    } else {
        std.log.err("Unsupported architecture selected.", .{});
    }
}

const cortex_m0 = std.Target.arm.cpu.cortex_m0;
const cortex_m0p = std.Target.arm.cpu.cortex_m0plus;
const cortex_m3 = std.Target.arm.cpu.cortex_m3;
const cortex_m4 = std.Target.arm.cpu.cortex_m4;
const cortex_m7 = std.Target.arm.cpu.cortex_m7;
