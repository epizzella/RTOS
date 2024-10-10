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
const OsTask = @import("../os_task.zig");
const OsCore = @import("../os_core.zig");
const TaskQueue = OsTask.TaskQueue;
const Task = OsTask.Task;
const SyncControl = @import("sync_control.zig");
const ArchInterface = @import("../arch/arch_interface.zig");

const Self = @This();
var arch = ArchInterface.arch;
const Error = OsCore.Error;
const EventContext = OsCore.SyncContext;
const task_control = &OsTask.task_control;

pub const Control = SyncControl.getSyncControl(Self);

_name: []const u8,
_event: usize,
_pending: TaskQueue,
_next: ?*Self,
_init: bool = false,

pub const EventTrigger = OsCore.SyncContext.EventTrigger;

const EventGroupConfig = struct {
    //Name of the event group
    name: []const u8,
};

/// Create an event group object
pub fn createEventGroup(config: EventGroupConfig) Self {
    return Self{
        ._name = config.name,
        ._event = 0,
        ._pending = .{},
        ._next = null,
    };
}

/// Add the event group to the OS
pub fn initalize(self: *Self) void {
    if (!self._init) {
        Control.add(self);
        self._init = true;
    }
}

const writeOptions = struct {
    /// The event flag
    event: usize,
};

/// Set the event flag of an event group
pub fn writeEvent(self: *Self, options: writeOptions) Error!void {
    const running_task = try OsCore.validateCallMinor();
    if (!self._init) return Error.Uninitialized;

    arch.criticalStart();
    defer arch.criticalEnd();
    self._event = options.event;
    var pending_task = self._pending.head;
    var highest_pending_prio: usize = OsTask.IDLE_PRIORITY_LEVEL;
    while (true) {
        if (pending_task) |task| {
            const event_triggered = checkEventTriggered(task._SyncContext, self._event);
            if (event_triggered) {
                task_control.readyTask(task);
                task._SyncContext.triggering_event = self._event;
                if (task._priority < highest_pending_prio) {
                    highest_pending_prio = task._priority;
                }
            }
            pending_task = task._to_tail;
        } else {
            break;
        }
    }

    if (highest_pending_prio < running_task._priority) {
        arch.criticalEnd();
        arch.runScheduler();
    }
}

/// Read the event flag from the event group
pub fn readEvent(self: *Self) Error!usize {
    if (!self._init) return Error.Uninitialized;
    return self._event;
}

pub const PendEventOptions = struct {
    /// The event bits to pend on
    event_mask: usize,
    /// The state change of the event bits to pend on
    PendOn: EventTrigger,
    /// The timeout in milliseconds.  Set to 0 to pend indefinitely.
    timeout_ms: u32 = 0,
};

/// Block the running task until the pending event is set.  If the pending event
/// is set when pendEvent is called the running task will not be blocked.
pub fn pendEvent(self: *Self, options: PendEventOptions) Error!usize {
    const running_task = try OsCore.validateCallMajor();
    if (!self._init) return Error.Uninitialized;

    running_task._SyncContext.pending_event = options.event_mask;
    running_task._SyncContext.trigger_type = options.PendOn;

    arch.criticalStart();
    defer arch.criticalEnd();

    const event_triggered = checkEventTriggered(running_task._SyncContext, self._event);
    if (event_triggered) {
        running_task._SyncContext.triggering_event = self._event;
    } else {
        if (task_control.popActive()) |task| {
            self._pending.insertAfter(task, null);
            task._timeout = options.timeout_ms;
            task._state = OsTask.State.blocked;
            arch.criticalEnd();
            arch.runScheduler();
            if (task._SyncContext.timed_out) {
                task._SyncContext.timed_out = false;
                return Error.TimedOut;
            }
            if (task._SyncContext.aborted) {
                task._SyncContext.aborted = false;
                return Error.Aborted;
            }
        } else {
            return Error.RunningTaskNull;
        }
    }

    return running_task._SyncContext.triggering_event;
}

fn checkEventTriggered(eventContext: EventContext, current_event: usize) bool {
    return switch (eventContext.trigger_type) {
        EventTrigger.all_set => (current_event & eventContext.pending_event) == current_event,
        EventTrigger.all_clear => (~current_event & eventContext.pending_event) == current_event,
        EventTrigger.any_set => current_event & eventContext.pending_event > 0,
        EventTrigger.any_clear => ~current_event & eventContext.pending_event > 0,
    };
}

pub const AbortEventOptions = struct {
    /// The task to abort pend and ready
    task: Task,
};

/// Readys the task if it is waiting on the event group.  When the task next
/// runs pendEvent() will return OsError.Aborted
pub fn abortPend(self: *Self, options: AbortEventOptions) Error!void {
    const running_task = try OsCore.validateCallMinor();
    if (!self._init) return Error.Uninitialized;

    arch.criticalStart();
    defer arch.criticalEnd();

    var q = options.task._queue orelse return Error.ObjectNotBlocking;
    if (!q.contains(options.task)) return Error.ObjectNotBlocking;

    options.task._SyncContext.aborted = true;
    task_control.readyTask(options.task);
    if (options.task.priority < running_task._priority) {
        arch.criticalEnd();
        arch.runScheduler();
    }
}
