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
const TaskQueue = @import("util/task_queue.zig");
const Task = @import("os_task.zig");
const os = @import("os.zig");
const print = std.debug.print;

const TaskHandle = TaskQueue.TaskHandle;
const expect = std.testing.expect;

fn testSubroutine() void {
    while (true) {}
}

const stackSize = 17;
var stack: [stackSize]u32 = [_]u32{0xDEADC0DE} ** stackSize;

var task1: TaskHandle = .{ ._data = .{
    .name = "TestHandle",
    .priority = 1,
    .stack = &stack,
    .stack_ptr = 0x00,
    .subroutine = &testSubroutine,
}, .name = "TestHandle" };

var task2: TaskHandle = .{ ._data = .{
    .name = "TestHandle",
    .priority = 2,
    .stack = &stack,
    .stack_ptr = 0x00,
    .subroutine = &testSubroutine,
}, .name = "TestHandle" };

var task3: TaskHandle = .{ ._data = .{
    .name = "TestHandle",
    .priority = 3,
    .stack = &stack,
    .stack_ptr = 0x00,
    .subroutine = &testSubroutine,
}, .name = "TestHandle" };

var task4: TaskHandle = .{ ._data = .{
    .name = "TestHandle",
    .priority = 4,
    .stack = &stack,
    .stack_ptr = 0x00,
    .subroutine = &testSubroutine,
}, .name = "TestHandle" };

//Tests

test "Test Insert After Append 1 Node" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertAfter(&task1, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task1);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == null);
}

test "Test Insert After Append 2 Nodes" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertAfter(&task1, null);
    queue.insertAfter(&task2, &task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task2);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == null);
}

test "Test Insert After Append 3 Nodes" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertAfter(&task1, null);
    queue.insertAfter(&task2, null);
    queue.insertAfter(&task3, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task3);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == null);
}

test "Test Insert After 4 Nodes" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertAfter(&task1, null);
    queue.insertAfter(&task2, null);
    queue.insertAfter(&task3, null);
    queue.insertAfter(&task4, &task2);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task3);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task4);
    try expect(task4._to_head == &task2);
    try expect(task4._to_tail == &task3);
    try expect(task3._to_head == &task4);
    try expect(task3._to_tail == null);
}

test "Test Insert Before Prepend 1 node" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertBefore(&task1, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task1);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == null);
}

test "Test Insert Before 2 nodes" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertBefore(&task1, null);
    queue.insertBefore(&task2, &task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task2);
    try expect(queue.tail == &task1);
    try expect(task2._to_head == null);
    try expect(task2._to_tail == &task1);
    try expect(task1._to_head == &task2);
    try expect(task1._to_tail == null);
}

test "Test Insert Before Prepend 3 Nodes" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertBefore(&task3, null);
    queue.insertBefore(&task2, null);
    queue.insertBefore(&task1, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task3);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == null);
}

test "Test Insert Before 4 nodes" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertBefore(&task3, null);
    queue.insertBefore(&task2, null);
    queue.insertBefore(&task1, null);
    queue.insertBefore(&task4, &task2);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task3);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task4);
    try expect(task4._to_head == &task1);
    try expect(task4._to_tail == &task2);
    try expect(task2._to_head == &task4);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == null);
}

test "Test Insert Sorted 1 node" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertSorted(&task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task1);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == null);
}

test "Test Insert Mixed" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};

    queue.insertBefore(&task3, null);
    queue.insertAfter(&task4, &task3);
    queue.insertBefore(&task1, null);
    queue.insertAfter(&task2, &task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task4);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == &task4);
    try expect(task4._to_head == &task3);
    try expect(task4._to_tail == null);
}

test "Test Insert Sorted 4 Nodes - 1" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertSorted(&task1);
    queue.insertSorted(&task2);
    queue.insertSorted(&task3);
    queue.insertSorted(&task4);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task4);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == &task4);
    try expect(task4._to_head == &task3);
    try expect(task4._to_tail == null);
}

test "Test Insert Sorted 4 Nodes - 2" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertSorted(&task4);
    queue.insertSorted(&task3);
    queue.insertSorted(&task2);
    queue.insertSorted(&task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task4);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == &task4);
    try expect(task4._to_head == &task3);
    try expect(task4._to_tail == null);
}

test "Test Insert Sorted 4 Nodes - 3" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};

    queue.insertSorted(&task3);
    queue.insertSorted(&task4);
    queue.insertSorted(&task1);
    queue.insertSorted(&task2);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &task1);
    try expect(queue.tail == &task4);
    try expect(task1._to_head == null);
    try expect(task1._to_tail == &task2);
    try expect(task2._to_head == &task1);
    try expect(task2._to_tail == &task3);
    try expect(task3._to_head == &task2);
    try expect(task3._to_tail == &task4);
    try expect(task4._to_head == &task3);
    try expect(task4._to_tail == null);
}

test "Test Pop- 1" {
    //clear pointers
    task1._to_head = null;
    task1._to_tail = null;
    task2._to_head = null;
    task2._to_tail = null;
    task3._to_head = null;
    task3._to_tail = null;
    task4._to_head = null;
    task4._to_tail = null;

    var queue: TaskQueue = .{};
    queue.insertSorted(&task1);
    queue.insertSorted(&task2);
    queue.insertSorted(&task3);
    queue.insertSorted(&task4);

    try expect(queue.elements == 4);
    var head = queue.pop();
    try expect(head == &task1);
    head = queue.pop();
    try expect(head == &task2);
    head = queue.pop();
    try expect(head == &task3);
    head = queue.pop();
    try expect(head == &task4);
    try expect(queue.elements == 0);
}
