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

const OsTask = @import("task.zig");
const Mutex = @import("synchronization/mutex.zig");
const Semaphore = @import("synchronization/semaphore.zig");
const EventGroup = @import("synchronization/event_group.zig");
const ArchInterface = @import("arch/arch_interface.zig");
const OsSyncControl = @import("synchronization/sync_control.zig");

pub const Task = OsTask.Task;

var arch = ArchInterface.arch;
const task_ctrl = &OsTask.task_control;
const SyncControl = OsSyncControl.SyncControl;

pub const DEFAULT_IDLE_TASK_SIZE = 17; //TODO: Change this based on the selected arch
const DEFAULT_SYS_CLK_FREQ = 1000; // 1 Khz

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

pub const OsConfig = struct {
    /// The frequency of the system clock in hz.  Note:  This does not set
    /// the system clock.  This only informs the OS of the system clock's frequenncy.  Default = 1000hz.
    system_clock_freq_hz: u32 = DEFAULT_SYS_CLK_FREQ,
    /// Function run by the idle task. Replaces the default idle task.  This
    /// subroutine cannot be suspended or blocked;
    idle_task_subroutine: *const fn () anyerror!void = &idle_subroutine,
    /// Number of words in the idle task stack.   Note:  if idle_task_subroutine is
    /// provided idle_stack_size must be larger than 17;
    idle_stack_size: u32 = DEFAULT_IDLE_TASK_SIZE,
    /// Function run at the beginning of the sysTick interrupt;
    sysTick_callback: ?*const fn () void = null,
};

var os_started: bool = false;
pub fn setOsStarted() void {
    os_started = true;
}

/// Returns true when the OS is running
pub fn isOsStarted() bool {
    return os_started;
}

/// Schedule the next task to run
pub fn schedule() void {
    task_ctrl.setNextRunningTask();
    if (task_ctrl.validSwitch()) {
        arch.runContextSwitch();
    }
}

//TODO: Move the validateCall functions into SyncControl & add checks for init
pub fn validateCallMajor() Error!*Task {
    if (!os_started) return Error.OsOffline;
    const running_task = task_ctrl.table[task_ctrl.running_priority].ready_tasks.head orelse return Error.RunningTaskNull;
    if (running_task._priority == OsTask.IDLE_PRIORITY_LEVEL) return Error.IllegalIdleTask;
    if (arch.interruptActive()) return Error.IllegalInterruptAccess;
    return running_task;
}

pub fn validateCallMinor() Error!*Task {
    if (!os_started) return Error.OsOffline;
    const running_task = task_ctrl.table[task_ctrl.running_priority].ready_tasks.head orelse return Error.RunningTaskNull;
    return running_task;
}

pub const SyncContext = struct {
    //Event context
    pending_event: usize = 0,
    triggering_event: usize = 0,
    trigger_type: EventTrigger = EventTrigger.all_set,
    //Common Sync Context
    aborted: bool = false,
    timed_out: bool = false,

    pub const EventTrigger = enum {
        all_set,
        all_clear,
        any_set,
        any_clear,
    };
};

var ticks: u64 = 0;

pub const Time = struct {
    const math = @import("std").math;

    /// Get the current number of elapsed ticks
    pub fn getTicks() u64 {
        return ticks;
    }

    /// Get the current number of elapsed ticks as milliseconds (rounded down)
    pub fn getTicksMs() u64 {
        return (ticks * 1000) / os_config.system_clock_freq_hz;
    }

    /// Put the active task to sleep.  It will become ready to run again after `time_ms` milliseconds.
    /// * `time_ms` when converted to system ticks cannot exceed 2^32 system ticks.
    pub fn delay(time_ms: u32) Error!void {
        var running_task = try validateCallMajor();
        if (time_ms != 0) {
            var timeout: u32 = math.mul(u32, time_ms, os_config.system_clock_freq_hz) catch return Error.SleepDurationOutOfRange;
            timeout /= 1000;
            arch.criticalStart();
            task_ctrl.yeildTask(running_task);
            running_task._timeout = timeout;
            arch.criticalEnd();
            arch.runScheduler();
        }
    }

    pub const SleepTime = struct {
        ms: u32 = 0,
        sec: u32 = 0,
        min: u32 = 0,
        hr: u32 = 0,
        days: u32 = 0,
    };

    fn sleepTimeToMs(time: *SleepTime) !u32 {
        var total_ms = time.ms;
        var temp_ms = try math.mul(u32, time.sec, 1000);
        total_ms = try math.add(u32, total_ms, temp_ms);
        temp_ms = try math.mul(u32, time.min, 60_000);
        total_ms = try math.add(u32, total_ms, temp_ms);
        temp_ms = try math.mul(u32, time.hr, 3_600_000);
        total_ms = try math.add(u32, total_ms, temp_ms);
        temp_ms = try math.mul(u32, time.hr, 86_400_000);
        total_ms = try math.add(u32, total_ms, temp_ms);
        return total_ms;
    }

    /// Put the active task to sleep.  The value of time must be less than 2^32 milliseconds (~49.7 days) and 2^32 system ticks.
    pub fn sleep(time: SleepTime) Error!void {
        const timeout = sleepTimeToMs(&time) catch return Error.SleepDurationOutOfRange;
        try delay(timeout);
    }
};

///System tick functionality.  Should be called from the System Clock interrupt. e.g. SysTick_Handler
pub inline fn systemTick() void {
    if (os_config.sysTick_callback) |callback| {
        callback();
    }

    if (os_started) {
        ticks +%= 1;
        SyncControl.updateTimeOut();
        task_ctrl.updateDelayedTasks();
        task_ctrl.cycleActive();
        schedule();
    }
}

pub const Error = error{
    /// The running task is null.  This is an illegal state once multi tasking as started.
    RunningTaskNull,
    /// The operating system has not started multi tasking.
    OsOffline,
    /// Illegal call from idle task
    IllegalIdleTask,
    /// Illegal call from interrupt
    IllegalInterruptAccess,
    /// A task that does not own this OS object attempted access
    TaskNotOwner,
    /// Time out limit reached.
    TimedOut,
    /// Function manually aborted
    Aborted,
    /// Os Object not initalized
    Uninitialized,
    /// The task is not blocked by the synchonization object
    TaskNotBlockedBySync,
    /// The synchonization object cannot be deleted because there is atleast 1 task pending on it.
    TaskPendingOnSync,
    /// The amount of time specified for the task to sleep exceeds the max value of 2^32 ms
    SleepDurationOutOfRange,
};
