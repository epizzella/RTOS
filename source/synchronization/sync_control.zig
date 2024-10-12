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
const OsTask = @import("../task.zig");
const OsCore = @import("../os_core.zig");
const ArchInterface = @import("../arch/arch_interface.zig");

const Error = OsCore.Error;
const task_control = &OsTask.task_control;
const Task = OsTask.Task;
const TaskQueue = OsTask.TaskQueue;
var arch = ArchInterface.arch;

pub const SyncContex = struct {
    _next: ?*SyncContex = null,
    _pending: TaskQueue = .{},
    _init: bool = false,
};

pub const SyncControl = struct {
    const Self = @This();
    var list: ?*SyncContex = null;

    pub fn add(new: *SyncContex) void {
        new._next = list;
        list = new;
        new._init = true;
    }

    /// Update the timeout of all the task pending on the synchronization object
    pub fn updateTimeOut() void {
        var syncObj = list orelse return;
        while (true) {
            if (syncObj._pending.head) |head| {
                var task = head;
                while (true) {
                    if (task._timeout > 0) {
                        task._timeout -= 1;
                        if (task._timeout == 0) task._SyncContext.timed_out = true;
                        task_control.readyTask(task);
                    }

                    if (task._to_tail) |next| {
                        task = next;
                    } else {
                        break;
                    }
                }
            }

            if (syncObj._next) |next| {
                syncObj = next;
            } else {
                break;
            }
        }
    }

    pub fn blockTask(blocker: *SyncContex, timeout_ms: u32) !void {
        if (task_control.popActive()) |task| {
            blocker._pending.insertSorted(task);
            task._timeout = (timeout_ms * OsCore.getOsConfig().system_clock_freq_hz) / 1000;
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
};
