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

    if (std.meta.eql(cpu_model, cpu.cortex_m0) or //
        std.meta.eql(cpu_model, cpu.cortex_m0plus))
    {
        std.log.info("RTOS build for: armv6m", .{});
        rtos.addAssemblyFile(b.path("source/arch/arm-cortex-m/armv6m.s"));
    } else if (std.meta.eql(cpu_model, cpu.cortex_m3) or //
        std.meta.eql(cpu_model, cpu.cortex_m4) or //
        std.meta.eql(cpu_model, cpu.cortex_m7))
    {
        std.log.info("RTOS build for: armv7m", .{});
        if (target.query.abi) |abi| {
            if (abi == std.Target.Abi.eabihf) {
                rtos.addAssemblyFile(b.path("source/arch/arm-cortex-m/armv7m_hf.s"));
            } else if (abi == std.Target.Abi.eabi) {
                rtos.addAssemblyFile(b.path("source/arch/arm-cortex-m/armv7m.s"));
            } else {
                std.log.err("Invalid Abi: Abi should equal 'eabi' or 'eabihf'", .{});
            }
        } else {
            std.log.err("Abi not set. Abi should equal 'eabi' or 'eabihf'", .{});
        }
    } else {
        std.log.err("Unsupported architecture selected.", .{});
    }
}
