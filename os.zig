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
const OsCore = @import("source/os_core.zig");
const OsTask = @import("source/task.zig");
const ArchInterface = @import("source/arch/arch_interface.zig");
pub const OsTimer = @import("source/synchronization/timer.zig");
const builtin = @import("builtin");

const Arch = ArchInterface.Arch;

pub const Task = OsTask.Task;
pub const Semaphore = @import("source/synchronization/semaphore.zig").Semaphore;
pub const Mutex = @import("source/synchronization/mutex.zig").Mutex;
pub const EventGroup = @import("source/synchronization/event_group.zig").EventGroup;
pub const createMsgQueueType = @import("source/synchronization/msg_queue.zig").createMsgQueueType;

pub const Timer = OsTimer.Timer;
pub const Time = OsCore.Time;
pub const OsError = OsCore.Error;
pub const OsConfig = OsCore.OsConfig;

pub fn init() void {
    Arch.coreInit();
}

const task_ctrl = &OsTask.task_control;

///Returns a new task.
pub fn create_task(config: OsTask.Task.TaskConfig) Task {
    return Task.create_task(config);
}

pub var g_stack_offset: usize = 0x08;

/// The operating system will begin multitasking.  This function should only be
/// called once.  Subsequent calls have no effect.  The frist time this function
/// is called it will not return as multitasking started.
pub fn startOS(comptime config: OsConfig) void {
    if (OsCore.isOsStarted() == false) {
        comptime {
            if (config.idle_stack_size < OsCore.DEFAULT_IDLE_TASK_SIZE) {
                @compileError("Idle stack size cannont be less than the default size.");
            }
        }

        OsCore.setOsConfig(config);

        var idle_stack: [config.idle_stack_size]u32 = [_]u32{0xDEADC0DE} ** config.idle_stack_size;

        var idle_task = create_task(.{
            .name = "idle task",
            .priority = 0, //Idle task priority is ignored
            .stack = &idle_stack,
            .subroutine = config.idle_task_subroutine,
        });

        task_ctrl.addIdleTask(&idle_task);

        var timer_task: Task = undefined;
        var timer_stack: [config.timer_config.timer_stack_size]u32 = undefined;

        if (config.timer_config.timer_enable) {
            comptime {
                if (config.timer_config.timer_stack_size < OsCore.DEFAULT_IDLE_TASK_SIZE) {
                    @compileError("Timer stack size cannont be less than the default size.");
                }
            }
            timer_stack = [_]u32{0xDEADC0DE} ** config.timer_config.timer_stack_size;
            timer_task = create_task(.{
                .name = "timer task",
                .priority = config.timer_config.timer_task_priority,
                .stack = &timer_stack,
                .subroutine = OsTimer.timerSubroutine,
            });

            timer_task.init();
            OsTimer.timer_sem.init() catch unreachable;
        }

        task_ctrl.initAllStacks();

        //Find offset to stack ptr as zig does not guarantee struct field order
        g_stack_offset = @abs(@intFromPtr(&idle_task._stack_ptr) -% @intFromPtr(&idle_task));
        std.mem.doNotOptimizeAway(g_stack_offset);

        OsCore.setOsStarted();
        Arch.runScheduler(); //begin os

        if (Arch.isDebugAttached()) {
            @breakpoint();
        }

        if (!builtin.is_test) unreachable;
    }
}
