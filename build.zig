const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const RTOS = b.addObject(.{
        .name = "RTOS",
        .root_source_file = b.path("os.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.getInstallStep().dependOn(&b.addInstallArtifact(RTOS, .{ .dest_dir = .{ .override = .{ .custom = "" } } }).step);
}
