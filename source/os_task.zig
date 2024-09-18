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

const TaskQueue = @import("util/task_queue.zig");
const OsCore = @import("os_core.zig");
const ArchInterface = @import("arch/arch_interface.zig");

const TaskHandle = TaskQueue.TaskHandle;

var arch = ArchInterface.arch;
const os_config = &OsCore.getOsConfig;

pub const Task = struct {
    stack: []u32,
    stack_ptr: u32,
    subroutine: *const fn () anyerror!void,
    subroutineErrHandler: ?*const fn (err: anyerror) void = null,
    blocked_time: u32 = 0,
    priority: u5,
    name: []const u8,

    pub fn create_task(config: TaskConfig) Task {
        const task = Task{
            .name = config.name,
            .stack = config.stack,
            .priority = config.priority,
            .subroutine = config.subroutine,
            .subroutineErrHandler = config.subroutineErrHandler,
            .blocked_time = 0,
            .stack_ptr = 0,
        };

        return task;
    }
};

pub const TaskConfig = struct {
    /// Task name
    name: []const u8,
    /// Task stack
    stack: []u32,
    /// Function executed by task
    subroutine: *const fn () anyerror!void,
    /// If `subroutine` returns an erorr that error will be passed to `subroutineErrHandler`.
    /// The task is suspsended after `subroutineErrHandler` completes, or if `subroutine` returns void.
    subroutineErrHandler: ?*const fn (err: anyerror) void = null,
    priority: u5,
};

pub var task_control: TaskControl = .{};

const MAX_PRIO_LEVEL = 33; // 32 user accessable priority levels + idle task at lowest priority level
const IDLE_PRIORITY_LEVEL: u32 = 32; //     idle task is the lowest priority.
const PRIO_ADJUST: u5 = 31;

const ONE: u32 = 0x1;

const TaskControl = struct {
    table: [MAX_PRIO_LEVEL]TaskStateQ = [_]TaskStateQ{.{}} ** MAX_PRIO_LEVEL,
    readyMask: u32 = 0, //      mask of ready tasks
    runningPrio: u6 = 0x00, //  priority level of the currently running task

    export var current_task: ?*volatile TaskQueue.TaskHandle = null;
    export var next_task: *volatile TaskQueue.TaskHandle = undefined;

    pub fn initAllStacks(self: *TaskControl) void {
        if (!OsCore.isOsStarted()) {
            for (&self.table) |*row| {
                var active_task = row.active_tasks.head;
                var suspend_task = row.suspended_tasks.head;
                while (true) {
                    if (active_task) |a| {
                        arch.initStack(&a._data);
                        active_task = a._to_tail;
                    }

                    if (suspend_task) |s| {
                        arch.initStack(&s._data);
                        suspend_task = s._to_tail;
                    }

                    if (active_task == null and suspend_task == null) break;
                }
            }
        }
    }

    ///Add task to the active task queue
    pub fn addActive(self: *TaskControl, task: *TaskQueue.TaskHandle) void {
        self.table[task._data.priority].active_tasks.insertAfter(task, null);
        self.readyMask |= ONE << (priorityAdjust[task._data.priority]);
    }

    ///Add task to the yielded task queue
    pub fn addYeilded(self: *TaskControl, task: *TaskQueue.TaskHandle) void {
        self.table[task._data.priority].yielded_task.insertAfter(task, null);
    }

    ///Add task to the suspended task queue
    pub fn addSuspended(self: *TaskControl, task: *TaskQueue.TaskHandle) void {
        self.table[task._data.priority].suspended_tasks.insertAfter(task, null);
    }

    ///Remove task from the active task queue
    pub fn removeActive(self: *TaskControl, task: *TaskQueue.TaskHandle) void {
        _ = self.table[task._data.priority].active_tasks.remove(task);
        if (self.table[task._data.priority].active_tasks.head == null) {
            self.readyMask &= ~(ONE << (priorityAdjust[task._data.priority]));
        }
    }

    ///Remove task from the yielded task queue
    pub fn removeYielded(self: *TaskControl, task: *TaskQueue.TaskHandle) void {
        _ = self.table[task._data.priority].yielded_task.remove(task);
    }

    ///Remove task from the suspended task queue
    pub fn removeSuspended(self: *TaskControl, task: *TaskQueue.TaskHandle) void {
        self.table[task._data.priority].suspended_tasks.remove(task);
    }

    ///Pop the active task from its active queue
    pub fn popActive(self: *TaskControl) ?*TaskQueue.TaskHandle {
        const head = self.table[self.runningPrio].active_tasks.pop();
        if (self.table[self.runningPrio].active_tasks.head == null) {
            self.readyMask &= ~(ONE << (priorityAdjust[self.runningPrio]));
        }

        return head;
    }

    ///Move the head task to the tail position of the active queue
    pub fn cycleActive(self: *TaskControl) void {
        if (self.runningPrio < MAX_PRIO_LEVEL) {
            self.table[self.runningPrio].active_tasks.headToTail();
        }
    }

    ///Set `next_task` to the highest priority task that is ready to run
    pub fn readyNextTask(self: *TaskControl) void {
        self.runningPrio = @clz(self.readyMask);
        next_task = self.table[self.runningPrio].active_tasks.head.?;
    }

    ///Returns true if `current_task` and `next_task` are different
    pub fn validSwitch(self: *TaskControl) bool {
        _ = self;
        return current_task != next_task;
    }

    ///Updates the delayed time for each sleeping task
    pub fn updateTasksDelay(self: *TaskControl) void {
        const os_period = os_config().system_clock_period_ms;
        for (&self.table) |*taskState| {
            if (taskState.yielded_task.head) |head| {
                var task = head;
                while (true) { //iterate over the priority level list
                    if (task._data.blocked_time < os_period) {
                        task._data.blocked_time = 0;
                    } else {
                        task._data.blocked_time -= os_period;
                    }

                    if (task._data.blocked_time == 0) {
                        self.removeYielded(task);
                        self.addActive(task);
                    }

                    if (task._to_tail) |next| {
                        task = next;
                    } else {
                        break;
                    }
                }
            }
        }
    }

    pub fn addIdleTask(self: *TaskControl, idle_task: *TaskQueue.TaskHandle) void {
        self.table[IDLE_PRIORITY_LEVEL].active_tasks.insertAfter(idle_task, null);
    }

    const priorityAdjust: [32]u5 = .{ 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 };
};

const TaskStateQ = struct {
    active_tasks: TaskQueue = .{},
    yielded_task: TaskQueue = .{},
    suspended_tasks: TaskQueue = .{},
};

pub fn taskTopRoutine() void {
    if (task_control.table[task_control.runningPrio].active_tasks.head) |active_task| {
        active_task._data.subroutine() catch |err| {
            if (active_task._data.subroutineErrHandler) |errHandler| {
                errHandler(err);
            }
        };
    }

    arch.criticalStart();
    if (task_control.popActive()) |active_task| {
        task_control.addSuspended(active_task);
    }
    arch.criticalEnd();
    arch.runScheduler();
}

fn defaultErrorHandler(err: anyerror) void {
    if (arch.isDebugAttached()) @breakpoint();
    _ = err;
}
