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

const Task = @import("../../os_task.zig").Task;
const Self = @This();

pub fn coreInit(self: *Self) void {
    _ = self;
}

pub fn initStack(self: *Self, task: *Task) void {
    _ = self;
    _ = task;
}

pub fn interruptActive(self: *Self) bool {
    _ = self;
    return false;
}

pub inline fn criticalEnd(self: *Self) void {
    _ = self;
}

//Enable Interrupts
pub inline fn criticalStart(self: *Self) void {
    _ = self;
}

//Disable Interrupts
pub inline fn runScheduler(self: *Self) void {
    _ = self;
}

pub inline fn runContextSwitch(self: *Self) void {
    _ = self;
}

pub inline fn isDebugAttached(self: *Self) bool {
    _ = self;
    return false;
}
