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

const OsTask = @import("os_task.zig");
const mutex = @import("os_mutex.zig");
const ArchInterface = @import("arch/arch_interface.zig");
const builtin = @import("builtin");
pub const Task = OsTask.Task;

const task_ctrl = &OsTask.task_control;
var arch = ArchInterface.arch;

const DEFAULT_IDLE_TASK_SIZE = 17;
const DEFAULT_SYS_CLK_PERIOD = 1;

var os_config: OsConfig = .{};

pub fn getOsConfig() OsConfig {
    return os_config;
}

pub fn setOsConfig(config: OsConfig) void {
    if (!os_started) {
        os_config = config;
    }
}

fn idle_subroutine() !void {
    while (true) {}
}

/// `system_clock_period_ms` - The peroid of the system clock in milliseconds.  Note:  This does not set
/// the system clock.  This only informs the OS of the system clock's peroid.  Default = 1ms.
/// `idle_task_subroutine` - function run by the idle task. Replaces the default idle task.  This
/// subroutine cannot be suspended or blocked;
/// `idle_stack_size` - number of words in the idle task stack.   Note:  if idle_task_subroutine is
/// provided idle_stack_size must be larger than 17;
/// `sysTick_callback` - function run at the beginning of the sysTick interrupt;
pub const OsConfig = struct {
    system_clock_period_ms: u32 = DEFAULT_SYS_CLK_PERIOD,
    idle_task_subroutine: *const fn () anyerror!void = &idle_subroutine,
    idle_stack_size: u32 = DEFAULT_IDLE_TASK_SIZE,
    sysTick_callback: ?*const fn () void = null,
};

var os_started: bool = false;
pub fn setOsStarted() void {
    os_started = true;
}

pub fn isOsStarted() bool {
    return os_started;
}

pub fn schedule() void {
    task_ctrl.readyNextTask();
    if (task_ctrl.validSwitch()) {
        arch.runContextSwitch();
    }
}

pub fn systemTick() void {
    if (os_config().sysTick_callback) |callback| {
        callback();
    }

    if (os_started()) {
        task_ctrl.updateTasksDelay();
        task_ctrl.cycleActive();
        schedule();
    }
}
