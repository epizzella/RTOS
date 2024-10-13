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

const OsTask = @import("../task.zig");
const OsCore = @import("../os_core.zig");
const TaskQueue = OsTask.TaskQueue;
const SyncControl = @import("sync_control.zig");
const ArchInterface = @import("../arch/arch_interface.zig");

var arch = ArchInterface.arch;

const task_control = &OsTask.task_control;
const Task = OsTask.Task;
const os_config = &OsCore.getOsConfig;
const Error = OsCore.Error;
pub const Control = SyncControl.SyncControl;
const SyncContex = SyncControl.SyncContext;

pub const Mutex = struct {
    const Self = @This();
    const Config = struct { name: []const u8, enable_priority_inheritance: bool = false };

    _name: []const u8,
    _owner: ?*Task = null,
    _syncContext: SyncContex = .{},

    /// Create a mutex object
    pub fn create_mutex(comptime name: []const u8) Self {
        return Self{
            ._name = name,
        };
    }

    /// Add the semaphore to the OS
    pub fn init(self: *Self) void {
        if (!self._syncContext._init) {
            Control.add(&self._syncContext);
            self._syncContext._init = true;
        }
    }

    pub const AquireOptions = struct {
        /// An optional timeout in milliseconds.  When set to a non-zero value the task
        /// will block for the amount of time specified. If the timeout expires before
        /// the mutex is unlocked acquire() will return OsError.TimedOut. When set to
        /// zero the task will block until the mutex unlocks.
        timeout_ms: u32 = 0,
    };

    /// Locks the mutex and gives the calling task ownership. If the mutex
    /// is lock when acquire() is called the running task will be blocked until
    /// the mutex is unlocked. Cannot be called from an interrupt.
    pub fn acquire(self: *Self, options: AquireOptions) Error!void {
        const running_task = try OsCore.validateCallMajor();
        arch.criticalStart();
        defer arch.criticalEnd();

        if (self._owner) |owner| {
            //locked
            _ = owner; //TODO: add priority inheritance check

            try Control.blockTask(&self._syncContext, options.timeout_ms);
        } else {
            //unlocked
            self._owner = running_task;
        }
    }

    /// Unlocks the mutex and removes ownership from the running task. If the
    /// running task is not the owner OsError.TaskNotOwner is returned. Cannot be
    /// called from an interrupt.
    pub fn release(self: *Self) Error!void {
        arch.criticalStart();
        defer arch.criticalEnd();
        const active_task = try OsCore.validateCallMajor();

        if (active_task == self._owner) {
            self._owner = self._syncContext._pending.head;
            if (self._owner) |head| {
                task_control.readyTask(head);
                if (head._priority < task_control.running_priority) {
                    arch.criticalEnd();
                    arch.runScheduler();
                }
            }
        } else {
            return Error.TaskNotOwner;
        }
    }

    /// Readys the task if it is waiting on the mutex. When the task next
    /// runs acquire() will return OsError.Aborted.
    /// * task - The task to abort & ready
    pub fn abortAcquire(self: *Self, task: *Task) Error!void {
        try Control.abort(&self._syncContext, task);
    }
};
