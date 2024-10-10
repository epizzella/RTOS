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
const OsTask = @import("../os_task.zig");
const task_control = &OsTask.task_control;

pub fn getSyncControl(T: type) type {
    comptime {
        const info = @typeInfo(T);
        if ((info != .Struct)) @compileError("T must be Struct");
        //checking that _next is a *T should work in zig v.014
        //const field_info = std.meta.fieldInfo(T, ._next);
        //if (field_info != *T) @compileError("_next is not type *T");
    }

    return struct {
        var list: ?*T = null;

        pub fn add(new: *T) void {
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
    };
}
