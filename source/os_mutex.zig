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

pub var mutex_control_table: MutexControleTable = .{};

const MutexControleTable = struct {};

const Context = struct {
    owner: ?*Task = null,
    pending: TaskQueue = .{},
};

const Config = struct { name: []const u8, enable_priority_inheritance: bool = false };

pub fn setArch(cpu: *ArchInterface.Arch) void {
    arch = cpu;
}

pub const Mutex = struct {
    _name: []const u8,
    _context: Context,

    pub fn create_mutex(name: []const u8) Mutex {
        return Mutex{ ._name = name, ._context = .{} };
    }

    pub fn acquire(self: *Mutex) void {
        if (!OsCore.isOsStarted()) @breakpoint(); //TODO: return an error
        if (arch.interruptActive()) @breakpoint(); //TODO: return an error

        arch.criticalStart();
        if (self._context.owner) |owner| {
            //locked
            _ = owner; //TODO: add priority inheritance check

            if (task_control.popActive()) |active_task| {
                self._context.pending.insertSorted(active_task);
                arch.criticalEnd();
                arch.runScheduler();
                arch.criticalStart();
            } else {
                @breakpoint();
                //TODO: return error
            }
        } else {
            //unlocked
            if (task_control.table[task_control.runningPrio].active_tasks.head) |active_task| {
                self._context.owner = active_task;
            } else {
                @breakpoint();
                //TODO: return error
            }
        }
        arch.criticalEnd();
    }

    pub fn release(self: *Mutex) void {
        if (!OsCore.isOsStarted()) @breakpoint(); //TODO: return an error
        if (arch.interruptActive()) @breakpoint(); //TODO: return an error

        arch.criticalStart();
        if (task_control.table[task_control.runningPrio].active_tasks.head) |active_task| {
            if (active_task == self._context.owner) {
                self._context.owner = self._context.pending.head;
                if (self._context.pending.pop()) |head| {
                    task_control.addActive(head);
                    if (head._data.priority < task_control.runningPrio) {
                        arch.criticalEnd();
                        arch.runScheduler();
                        arch.criticalStart();
                    }
                }
            } else {
                @breakpoint();
                //TODO: return an error
            }
        } else {
            @breakpoint();
            //TODO: return an error
        }
        arch.criticalEnd();
    }
};

const MutexErrors = error{
    Mutex_OsOffline,
    Mutex_Interrupt,
    Mutex_ActiveTaskNull,
    Mutex_TaskNotOwner,
};
