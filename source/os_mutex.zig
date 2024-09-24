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
const OsCore = @import("os_core.zig");
const TaskQueue = @import("util/task_queue.zig");
const ArchInterface = @import("arch/arch_interface.zig");

const task_ctrl = &OsTask.task_control;
var arch = ArchInterface.arch;

const Task = TaskQueue.TaskHandle;
const task_control = &OsTask.task_control;
const os_config = &OsCore.getOsConfig;
const Error = OsCore.Error;

const Config = struct { name: []const u8, enable_priority_inheritance: bool = false };

pub const Control = struct {
    var list: ?*Mutex = null;

    pub fn add(new: *Mutex) void {
        new._next = list;
        list = new;
        new._init = true;
    }

    pub fn updateTimeOut() void {
        var mutex = list orelse return;
        while (true) {
            //var task = mutex._pending.head orelse break;
            if (mutex._pending.head) |head| {
                var task = head;
                while (true) {
                    if (task._data.timeout > 0) {
                        task._data.timeout -= 1;
                        if (task._data.timeout == 0) task._data.state = OsTask.State.blocked_timedout;
                    }

                    if (task._to_tail) |next| {
                        task = next;
                    } else {
                        break;
                    }
                }
            }

            if (mutex._next) |next| {
                mutex = next;
            } else {
                break;
            }
        }
    }
};

var control: Control = .{};

const AquireOptions = struct {
    timeout_ms: u32 = 0,
};

pub const Mutex = struct {
    _name: []const u8,
    _owner: ?*Task = null,
    _pending: TaskQueue = .{},
    _next: ?*Mutex = null,
    _init: bool = false,

    const Self = @This();

    pub fn create_mutex(name: []const u8) Mutex {
        return Mutex{
            ._name = name,
        };
    }

    //TODO: add timeout
    pub fn acquire(self: *Self, options: AquireOptions) Error!void {
        arch.criticalStart();
        defer arch.criticalEnd();
        const running_task = try OsCore.validateOsCall();

        if (self._init == false) {
            Control.add(self);
        }

        if (self._owner) |owner| {
            //locked
            _ = owner; //TODO: add priority inheritance check

            if (task_control.popActive()) |active_task| {
                self._pending.insertSorted(active_task);
                active_task._data.timeout = options.timeout_ms;
                active_task._data.state = OsTask.State.blocked;
                arch.criticalEnd();
                arch.runScheduler();
                arch.criticalStart();
                if (active_task._data.state == OsTask.State.blocked_timedout) return Error.TimeOut;
            } else {
                return Error.RunningTaskNull;
            }
        } else {
            //unlocked
            self._owner = running_task;
        }
    }

    pub fn release(self: *Mutex) Error!void {
        arch.criticalStart();
        defer arch.criticalEnd();
        const active_task = try OsCore.validateOsCall();

        if (active_task == self._owner) {
            self._owner = self._pending.head;
            if (self._pending.pop()) |head| {
                task_control.addActive(head);
                if (head._data.priority < task_control.running_priority) {
                    arch.criticalEnd();
                    arch.runScheduler();
                }
            }
        } else {
            return Error.TaskNotOwner;
        }
    }
};
