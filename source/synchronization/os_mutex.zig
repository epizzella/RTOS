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
const SyncControl = @import("sync_control.zig");
const ArchInterface = @import("../arch/arch_interface.zig");

const Self = @This();
var arch = ArchInterface.arch;

const task_control = &OsTask.task_control;
const os_config = &OsCore.getOsConfig;
const Error = OsCore.Error;
pub const Control = SyncControl.getSyncControl(Self);

const Config = struct { name: []const u8, enable_priority_inheritance: bool = false };

_name: []const u8,
_owner: ?*OsTask.Task = null,
_pending: TaskQueue = .{},
_next: ?*Self = null,
_init: bool = false,

pub fn create_mutex(comptime name: []const u8) Self {
    return Self{
        ._name = name,
    };
}

const AquireOptions = struct {
    timeout_ms: u32 = 0,
};

pub fn acquire(self: *Self, options: AquireOptions) Error!void {
    const running_task = try OsCore.validateCallMajor();
    arch.criticalStart();
    defer arch.criticalEnd();

    if (self._init == false) {
        Control.add(self);
    }

    if (self._owner) |owner| {
        //locked
        _ = owner; //TODO: add priority inheritance check

        if (task_control.popActive()) |task| {
            self._pending.insertSorted(task);
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
    } else {
        //unlocked
        self._owner = running_task;
    }
}

pub fn release(self: *Self) Error!void {
    arch.criticalStart();
    defer arch.criticalEnd();
    const active_task = try OsCore.validateCallMajor();

    if (active_task == self._owner) {
        self._owner = self._pending.head;
        if (self._pending.pop()) |head| {
            task_control.addReady(head);
            if (head._priority < task_control.running_priority) {
                arch.criticalEnd();
                arch.runScheduler();
            }
        }
    } else {
        return Error.TaskNotOwner;
    }
}

/// Readys the task if it is waiting on the mutex.  When the task next
/// runs acquire() will return OsError.Aborted
pub fn abortPend(self: *Self, task: OsTask) Error!void {
    const running_task = try OsCore.validateCallMinor();
    if (!self._init) return Error.Uninitialized;

    arch.criticalStart();
    defer arch.criticalEnd();
    task._SyncContext.aborted = true;
    task_control.readyTask(task);
    if (task.priority < running_task._priority) {
        arch.criticalEnd();
        arch.runScheduler();
    }
}
