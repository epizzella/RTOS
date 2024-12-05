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

const std = @import("std");
const cpu = std.Target.arm.cpu;
const builtin = @import("builtin");

const OsTask = @import("../../task.zig");
const OsCore = @import("../../os_core.zig");
const Os = @import("../../../os.zig");

const V6 = @import("armv6-m.zig");
const V7 = @import("armv7-m.zig");
const V8 = @import("armv8-m.zig");
const V8P1 = @import("armv8.1-m.zig");

const core = getCore: {
    const cpu_model = builtin.cpu.model;

    if (cpu_model == &cpu.cortex_m0 or cpu_model == &cpu.cortex_m0plus) {
        break :getCore V6;
    } else if (cpu_model == &cpu.cortex_m3 or cpu_model == &cpu.cortex_m4 or cpu_model == &cpu.cortex_m7) {
        break :getCore V7;
    } else {
        @compileError("Unsupported architecture selected.");
    }
};

const task_ctrl = &OsTask.task_control;
const Task = OsTask.Task;

pub const Self = @This();

/////////////////////////////////////////////////////////
//    Architecture specific Function Implemntations   //
///////////////////////////////////////////////////////
pub const minStackSize = core.minStackSize;

pub fn coreInit() void {
    SHPR3.PRI_PENDSV = core.LOWEST_PRIO_MSK; //Set the pendsv to the lowest priority to avoid context switch during ISR
    SHPR3.PRI_SYSTICK = ~core.LOWEST_PRIO_MSK; //Set sysTick to the highest priority.
}

pub fn initStack(task: *Task) void {
    task._stack_ptr = @intFromPtr(&task._stack.ptr[task._stack.len - minStackSize]);
    task._stack.ptr[task._stack.len - 1] = 0x1 << 24; // xPSR
    task._stack.ptr[task._stack.len - 2] = @intFromPtr(&OsTask.taskTopRoutine); // PC
    task._stack.ptr[task._stack.len - 3] = 0x14141414; // LR (R14)
    task._stack.ptr[task._stack.len - 4] = 0x12121212; // R12
    task._stack.ptr[task._stack.len - 5] = 0x03030303; // R3
    task._stack.ptr[task._stack.len - 6] = 0x02020202; // R2
    task._stack.ptr[task._stack.len - 7] = 0x01010101; // R1
    task._stack.ptr[task._stack.len - 8] = 0x00000000; // R0
    task._stack.ptr[task._stack.len - 9] = 0xFFFFFFFD; // EXEC_RETURN (LR)
}

pub fn interruptActive() bool {
    return ICSR.VECTACTIVE > 0;
}

///Enable Interrupts
pub inline fn criticalEnd() void {
    asm volatile ("CPSIE    I");
}

///Disable Interrupts
pub inline fn criticalStart() void {
    asm volatile ("CPSID    I");
}

pub inline fn runScheduler() void {
    asm volatile ("SVC    #0");
}

pub inline fn runContextSwitch() void {
    OsTask.TaskControl.next_task._state = .running;
    ICSR.PENDSVSET = true;
}

pub inline fn startOs() void {
    // firstContextSwitch();
}

pub inline fn isDebugAttached() bool {
    return DHCSR.C_DEBUGEN;
}

/////////////////////////////////////////////
//         Exception Handlers             //
///////////////////////////////////////////

export fn SysTick_Handler() void {
    criticalStart();
    OsCore.OsTick();
    criticalEnd();
}

export fn SVC_Handler() void {
    criticalStart();
    OsCore.schedule();
    criticalEnd();
}

export fn PendSV_Handler() void {
    core.contextSwitch();
}

/////////////////////////////////////////////
//        System Control Registers        //
///////////////////////////////////////////
const ICSR: *volatile core.ICSR_REG = @ptrFromInt(core.ICSR_ADDRESS);
const SHPR3: *volatile core.SHPR3_REG = @ptrFromInt(core.SHPR3_ADDRESS);
const DHCSR: *volatile core.DHCSR_REG = @ptrFromInt(core.DHCSR_ADDRESS);
