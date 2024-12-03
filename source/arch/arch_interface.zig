/////////////////////////////////////////////////////////////////////////////////
// Copyright 2024 Edward Pizzella
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
/////////////////////////////////////////////////////////////////////////////////

const TestArch = @import("test/test_arch.zig");
const ArmCortexM = if (builtin.is_test != true) @import("arm-cortex-m/arch.zig") else @import("test/test_arch.zig");
const Task = @import("../task.zig").Task;
const builtin = @import("builtin");
const std = @import("std");
const cpu = std.Target.arm.cpu;

pub const arch: Arch = getArch: {
    const cpu_model = builtin.cpu.model;
    if (builtin.is_test == true) {
        break :getArch Arch{ .test_arch = TestArch{} };
    } else if (cpu_model == &cpu.cortex_m0 or //
        cpu_model == &cpu.cortex_m0plus or //
        cpu_model == &cpu.cortex_m3 or //
        cpu_model == &cpu.cortex_m4 or //
        cpu_model == &cpu.cortex_m7)
    {
        break :getArch Arch{ .cortexM = ArmCortexM{} };
    } else if (cpu_model == &cpu.cortex_m23 or //
        cpu_model == &cpu.cortex_m33 or //
        cpu_model == &cpu.cortex_m55 or //
        cpu_model == &cpu.cortex_m85)
    {
        @compileError("Unsupported architecture selected.");
    } else {
        @compileError("Unsupported architecture selected.");
    }
};

const Arch = union(enum) {
    cortexM: ArmCortexM,
    test_arch: TestArch,

    const Self = @This();

    pub fn coreInit(self: *Self) void {
        switch (self.*) {
            inline else => |*case| return case.coreInit(),
        }
    }

    pub fn initStack(self: *Self, task: *Task) void {
        switch (self.*) {
            inline else => |*case| return case.initStack(task),
        }
    }

    pub fn interruptActive(self: *Self) bool {
        switch (self.*) {
            inline else => |*case| return case.interruptActive(),
        }
    }

    pub inline fn criticalEnd(self: *Self) void {
        switch (self.*) {
            inline else => |*case| return case.criticalEnd(),
        }
    }

    pub inline fn criticalStart(self: *Self) void {
        switch (self.*) {
            inline else => |*case| return case.criticalStart(),
        }
    }

    pub inline fn runScheduler(self: *Self) void {
        switch (self.*) {
            inline else => |*case| return case.runScheduler(),
        }
    }

    pub inline fn runContextSwitch(self: *Self) void {
        switch (self.*) {
            inline else => |*case| return case.runContextSwitch(),
        }
    }

    pub inline fn startOs(self: *Self) void {
        switch (self.*) {
            inline else => |*case| return case.startOs(),
        }
    }

    pub inline fn isDebugAttached(self: *Self) bool {
        switch (self.*) {
            inline else => |*case| return case.isDebugAttached(),
        }
    }
};
