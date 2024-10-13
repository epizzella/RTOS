const std = @import("std");
const Semaphore = @import("source/synchronization/semaphore.zig").Semaphore;
const OsTask = @import("source/task.zig");
const TestArch = @import("source/arch/test/test_arch.zig");
const OsCore = @import("source/os_core.zig");
const OS = @import("os.zig");

const expect = std.testing.expect;
const task_control = &OsTask.task_control;
const Task = OsTask.Task;
const TaskQueue = OsTask.TaskQueue;

var test_stack: [20]u32 = [_]u32{0xDEADC0DE} ** 20;
fn test_fn() !void {}

var test_task1 = Task.create_task(.{
    .name = "test1",
    .priority = 1,
    .stack = &test_stack,
    .subroutine = &test_fn,
});

var test_task2 = Task.create_task(.{
    .name = "test2",
    .priority = 2,
    .stack = &test_stack,
    .subroutine = &test_fn,
});

var test_task3: Task = Task.create_task(.{
    .name = "test3",
    .priority = 3,
    .stack = &test_stack,
    .subroutine = &test_fn,
});

var test_task4 = Task.create_task(.{
    .name = "test4",
    .priority = 4,
    .stack = &test_stack,
    .subroutine = &test_fn,
});

var idle_task = Task.create_task(.{
    .name = "idle_task",
    .priority = 0, //ignored
    .stack = &test_stack,
    .subroutine = &test_fn,
});

fn task_setup() void {
    test_task1.init();
    test_task1.init();
    task_control.readyTask(&test_task1);
    task_control.readyTask(&test_task2);
    test_task1._SyncContext.aborted = false;
    test_task2._SyncContext.aborted = false;
    test_task1._SyncContext.timed_out = false;
    test_task2._SyncContext.timed_out = false;
    task_control.addIdleTask(&idle_task);
    OsCore.setOsStarted();
    task_control.setNextRunningTask();
}

/////////////////////////////////////////////
//         Task Queue Unit Tests          //
///////////////////////////////////////////

fn clearPointers() void {
    test_task1._to_head = null;
    test_task1._to_tail = null;
    test_task2._to_head = null;
    test_task2._to_tail = null;
    test_task3._to_head = null;
    test_task3._to_tail = null;
    test_task4._to_head = null;
    test_task4._to_tail = null;
}

test "Task Queue Insert After Append 1 Node" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertAfter(&test_task1, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task1);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == null);
}

test "Task Queue Insert After Append 2 Nodes" {
    //clear pointers
    clearPointers();
    var queue: TaskQueue = .{};
    queue.insertAfter(&test_task1, null);
    queue.insertAfter(&test_task2, &test_task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task2);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == null);
}

test "Task Queue Insert After Append 3 Nodes" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertAfter(&test_task1, null);
    queue.insertAfter(&test_task2, null);
    queue.insertAfter(&test_task3, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task3);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == null);
}

test "Task Queue Insert After 4 Nodes" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertAfter(&test_task1, null);
    queue.insertAfter(&test_task2, null);
    queue.insertAfter(&test_task3, null);
    queue.insertAfter(&test_task4, &test_task2);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task3);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task4);
    try expect(test_task4._to_head == &test_task2);
    try expect(test_task4._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task4);
    try expect(test_task3._to_tail == null);
}

test "Task Queue Insert Before Prepend 1 node" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertBefore(&test_task1, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task1);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == null);
}

test "Task Queue Insert Before 2 nodes" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertBefore(&test_task1, null);
    queue.insertBefore(&test_task2, &test_task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task2);
    try expect(queue.tail == &test_task1);
    try expect(test_task2._to_head == null);
    try expect(test_task2._to_tail == &test_task1);
    try expect(test_task1._to_head == &test_task2);
    try expect(test_task1._to_tail == null);
}

test "Task Queue Insert Before Prepend 3 Nodes" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertBefore(&test_task3, null);
    queue.insertBefore(&test_task2, null);
    queue.insertBefore(&test_task1, null);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task3);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == null);
}

test "Task Queue Insert Before 4 nodes" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertBefore(&test_task3, null);
    queue.insertBefore(&test_task2, null);
    queue.insertBefore(&test_task1, null);
    queue.insertBefore(&test_task4, &test_task2);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task3);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task4);
    try expect(test_task4._to_head == &test_task1);
    try expect(test_task4._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task4);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == null);
}

test "Task Queue Insert Sorted 1 node" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertSorted(&test_task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task1);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == null);
}

test "Task Queue Insert Mixed" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};

    queue.insertBefore(&test_task3, null);
    queue.insertAfter(&test_task4, &test_task3);
    queue.insertBefore(&test_task1, null);
    queue.insertAfter(&test_task2, &test_task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task4);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == &test_task4);
    try expect(test_task4._to_head == &test_task3);
    try expect(test_task4._to_tail == null);
}

test "Task Queue Insert Sorted 4 Nodes - 1" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertSorted(&test_task1);
    queue.insertSorted(&test_task2);
    queue.insertSorted(&test_task3);
    queue.insertSorted(&test_task4);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task4);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == &test_task4);
    try expect(test_task4._to_head == &test_task3);
    try expect(test_task4._to_tail == null);
}

test "Task Queue Insert Sorted 4 Nodes - 2" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertSorted(&test_task4);
    queue.insertSorted(&test_task3);
    queue.insertSorted(&test_task2);
    queue.insertSorted(&test_task1);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task4);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == &test_task4);
    try expect(test_task4._to_head == &test_task3);
    try expect(test_task4._to_tail == null);
}

test "Task Queue Insert Sorted 4 Nodes - 3" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};

    queue.insertSorted(&test_task3);
    queue.insertSorted(&test_task4);
    queue.insertSorted(&test_task1);
    queue.insertSorted(&test_task2);

    try expect(queue.head.?._to_head == null);
    try expect(queue.tail.?._to_tail == null);
    try expect(queue.head == &test_task1);
    try expect(queue.tail == &test_task4);
    try expect(test_task1._to_head == null);
    try expect(test_task1._to_tail == &test_task2);
    try expect(test_task2._to_head == &test_task1);
    try expect(test_task2._to_tail == &test_task3);
    try expect(test_task3._to_head == &test_task2);
    try expect(test_task3._to_tail == &test_task4);
    try expect(test_task4._to_head == &test_task3);
    try expect(test_task4._to_tail == null);
}

test "Task Queue Pop - 1" {
    //clear pointers
    clearPointers();

    var queue: TaskQueue = .{};
    queue.insertSorted(&test_task1);
    queue.insertSorted(&test_task2);
    queue.insertSorted(&test_task3);
    queue.insertSorted(&test_task4);

    try expect(queue.elements == 4);
    var head = queue.pop();
    try expect(head == &test_task1);
    head = queue.pop();
    try expect(head == &test_task2);
    head = queue.pop();
    try expect(head == &test_task3);
    head = queue.pop();
    try expect(head == &test_task4);
    try expect(queue.elements == 0);
}

/////////////////////////////////////////////
//          Semaphore Unit Tests          //
///////////////////////////////////////////

test "Semaphore Init/Deinit Test" {
    var semaphore1 = Semaphore.create_semaphore(.{ .name = "test_sem1", .inital_value = 1 });
    var semaphore2 = Semaphore.create_semaphore(.{ .name = "test_sem2", .inital_value = 1 });
    var semaphore3 = Semaphore.create_semaphore(.{ .name = "test_sem3", .inital_value = 1 });
    //init test
    semaphore1.init();
    semaphore2.init();
    semaphore3.init();

    try expect(semaphore1._syncContext._init == true);
    try expect(semaphore1._syncContext._prev == &semaphore2._syncContext);
    try expect(semaphore1._syncContext._next == null);

    try expect(semaphore2._syncContext._init == true);
    try expect(semaphore2._syncContext._prev == &semaphore3._syncContext);
    try expect(semaphore2._syncContext._next == &semaphore1._syncContext);

    try expect(semaphore3._syncContext._init == true);
    try expect(semaphore3._syncContext._prev == null);
    try expect(semaphore3._syncContext._next == &semaphore2._syncContext);

    //deinit test
    try semaphore2.deinit();
    try expect(semaphore2._syncContext._init == false);
    try expect(semaphore2._syncContext._prev == null);
    try expect(semaphore2._syncContext._next == null);

    try expect(semaphore3._syncContext._prev == null);
    try expect(semaphore3._syncContext._next == &semaphore1._syncContext);

    try expect(semaphore1._syncContext._prev == &semaphore3._syncContext);
    try expect(semaphore1._syncContext._next == null);

    try semaphore3.deinit();
    try expect(semaphore3._syncContext._init == false);
    try expect(semaphore3._syncContext._prev == null);
    try expect(semaphore3._syncContext._next == null);

    try expect(semaphore1._syncContext._init == true);
    try expect(semaphore1._syncContext._prev == null);
    try expect(semaphore1._syncContext._next == null);

    try semaphore1.deinit();
}

test "Semaphore Aquire Test" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 1 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == false);
    try expect(semaphore._count == 0);
    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == true);
}

test "Semaphore Release Test" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    try semaphore.release();

    try expect(semaphore._count == 1);
    try expect(TestArch.schedulerRan() == false);
}

test "Semaphore Release Test 2" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
    try semaphore.release();
    try expect(semaphore._count == 0);
    try expect(TestArch.schedulerRan() == true);
}

test "Semaphore Release Test 3" {
    OsCore.setOsStarted();
    try test_task1.suspendMe();
    task_control.readyTask(&test_task2);
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
    task_control.readyTask(&test_task1);
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == true);
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 1);
    try semaphore.release();
    try expect(semaphore._count == 0);
    try expect(TestArch.schedulerRan() == false);
}

test "Semaphore Abort Test" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try semaphore.abortAcquire(&test_task1);
    try expect(test_task1._SyncContext.aborted == true);
    try expect(TestArch.schedulerRan());
    task_control.setNextRunningTask();
    try expect(semaphore.acquire(.{ .timeout_ms = 0 }) == OsCore.Error.Aborted);
}

test "Semaphore Abort Test2" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(semaphore.abortAcquire(&test_task2) == OsCore.Error.TaskNotBlockedBySync);
}

test "Semaphore timeout" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore.init();

    try semaphore.acquire(.{ .timeout_ms = 1 });
    OsCore.systemTick();
    try expect(task_control.running_priority == 1);
    try expect(semaphore.acquire(.{}) == OsCore.Error.TimedOut);
    task_control.setNextRunningTask();
    try semaphore.abortAcquire(&test_task1);

    //clean up
    try semaphore.deinit();
}

test "Semaphore timeout2" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    var semaphore2 = Semaphore.create_semaphore(.{ .name = "test_sem2", .inital_value = 0 });

    semaphore.init();
    semaphore2.init();

    try semaphore.acquire(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try semaphore2.acquire(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 32);

    OsCore.systemTick();
    try expect(test_task1._state == OsTask.State.running);
    try expect(test_task1._SyncContext.timed_out);
    try expect(test_task2._state == OsTask.State.ready);
    try expect(test_task2._SyncContext.timed_out);
}
