const std = @import("std");
const Semaphore = @import("source/synchronization/semaphore.zig").Semaphore;
const Mutex = @import("source/synchronization/mutex.zig").Mutex;
const OsTask = @import("source/task.zig");
const TestArch = @import("source/arch/test/test_arch.zig");
const OsCore = @import("source/os_core.zig");
const OS = @import("os.zig");

const expect = std.testing.expect;
const task_control = &OsTask.task_control;
const Task = OsTask.Task;
const TaskQueue = OsTask.TaskQueue;

var test_stack: [20]usize = [_]usize{0xDEADC0DE} ** 20;
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
    test_task1._init = false;
    test_task2._init = false;
    test_task3._init = false;
    test_task4._init = false;

    test_task1.init();
    test_task2.init();
    test_task3.init();
    test_task4.init();

    test_task1._SyncContext.aborted = false;
    test_task2._SyncContext.aborted = false;
    test_task3._SyncContext.aborted = false;
    test_task4._SyncContext.aborted = false;
    test_task1._SyncContext.timed_out = false;
    test_task2._SyncContext.timed_out = false;
    test_task3._SyncContext.timed_out = false;
    test_task4._SyncContext.timed_out = false;
    task_control.addIdleTask(&idle_task);
    OsCore.setOsStarted();
    task_control.setNextRunningTask();
    //Clear test arch flags
    _ = TestArch.schedulerRan();
    _ = TestArch.contextSwitchRan();
}

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

/////////////////////////////////////////////
//            Task Unit Tests             //
///////////////////////////////////////////

test "Task Suspend Test" {
    task_setup();
    try test_task1.suspendMe();
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
}

test "Task Resume Test" {
    task_setup();
    try test_task1.suspendMe();
    task_control.setNextRunningTask();
    try test_task1.resumeMe();
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 1);
}

/////////////////////////////////////////////
//         Task Queue Unit Tests          //
///////////////////////////////////////////

test "Task Queue Insert After Append 1 Node Test" {
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

test "Task Queue Insert After Append 2 Nodes Test" {
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

test "Task Queue Insert After Append 3 Nodes Test" {
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

test "Task Queue Insert After 4 Nodes Test" {
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

test "Task Queue Insert Before Prepend 1 node Test" {
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

test "Task Queue Insert Before 2 nodes Test" {
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

test "Task Queue Insert Before Prepend 3 Nodes Test" {
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

test "Task Queue Insert Before 4 nodes Test" {
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

test "Task Queue Insert Sorted 1 node Test" {
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

test "Task Queue Insert Mixed Test" {
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

test "Task Queue Insert Sorted 4 Nodes - 1 Test" {
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

test "Task Queue Insert Sorted 4 Nodes - 2 Test" {
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

test "Task Queue Insert Sorted 4 Nodes - 3 Test" {
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

test "Task Queue Pop - 1 Test" {
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
//           Mutex Unit Tests             //
///////////////////////////////////////////

test "Mutex Init/Deinit Test" {
    var mutex1 = Mutex.create_mutex("test_mutex1");
    var mutex2 = Mutex.create_mutex("test_mutex1");
    var mutex3 = Mutex.create_mutex("test_mutex1");
    //init test
    try mutex1.init();
    try mutex2.init();
    try mutex3.init();

    try expect(mutex1._syncContext._init == true);
    try expect(mutex1._syncContext._prev == &mutex2._syncContext);
    try expect(mutex1._syncContext._next == null);

    try expect(mutex2._syncContext._init == true);
    try expect(mutex2._syncContext._prev == &mutex3._syncContext);
    try expect(mutex2._syncContext._next == &mutex1._syncContext);

    try expect(mutex3._syncContext._init == true);
    try expect(mutex3._syncContext._prev == null);
    try expect(mutex3._syncContext._next == &mutex2._syncContext);

    //deinit test
    try mutex2.deinit();
    try expect(mutex2._syncContext._init == false);
    try expect(mutex2._syncContext._prev == null);
    try expect(mutex2._syncContext._next == null);

    try expect(mutex3._syncContext._prev == null);
    try expect(mutex3._syncContext._next == &mutex1._syncContext);

    try expect(mutex1._syncContext._prev == &mutex3._syncContext);
    try expect(mutex1._syncContext._next == null);

    try mutex3.deinit();
    try expect(mutex3._syncContext._init == false);
    try expect(mutex3._syncContext._prev == null);
    try expect(mutex3._syncContext._next == null);

    try expect(mutex1._syncContext._init == true);
    try expect(mutex1._syncContext._prev == null);
    try expect(mutex1._syncContext._next == null);

    try mutex1.deinit();
}

test "Mutex Aquire Test" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    mutex1._syncContext._init = true;

    try mutex1.acquire(.{ .timeout_ms = 0 });
    try expect(mutex1.acquire(.{ .timeout_ms = 0 }) == OsCore.Error.MutexOwnerAquire);
}

test "Mutex Aquire Test 2" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    mutex1._syncContext._init = true;

    try mutex1.acquire(.{ .timeout_ms = 0 });
    try expect(!TestArch.schedulerRan());
    try expect(mutex1._owner == &test_task1);

    try test_task1.suspendMe();
    try expect(TestArch.schedulerRan());
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);

    try mutex1.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan());
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 3);
}

test "Mutex Release Test" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    try expect(mutex1.release() == OsCore.Error.InvalidMutexOwner);
}

test "Mutex Release Test 2" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    mutex1._syncContext._init = true;

    try mutex1.acquire(.{ .timeout_ms = 0 });
    try test_task1.suspendMe();
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);

    try expect(mutex1.release() == OsCore.Error.InvalidMutexOwner);
}

test "Mutex Release Test 3" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    mutex1._syncContext._init = true;

    try mutex1.acquire(.{ .timeout_ms = 0 });
    try expect(mutex1._owner == &test_task1);
    try mutex1.release();
    try expect(mutex1._owner == null);
    try expect(!TestArch.schedulerRan());
}

test "Mutex Abort Test" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    mutex1._syncContext._init = true;

    try mutex1.acquire(.{ .timeout_ms = 0 });
    try expect(mutex1._owner == &test_task1);
    try test_task1.suspendMe();
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);

    try mutex1.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 3);

    try mutex1.abortAcquire(&test_task2);
    try expect(TestArch.schedulerRan());
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);

    try expect(mutex1.acquire(.{ .timeout_ms = 0 }) == OsCore.Error.Aborted);
}

test "Mutex Abort Test 2" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    mutex1._syncContext._init = true;

    try mutex1.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(mutex1.abortAcquire(&test_task2) == OsCore.Error.TaskNotBlockedBySync);
}

test "Mutex Timeout Test" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    try mutex1.init();
    mutex1._owner = &test_task4;

    try mutex1.acquire(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);

    OsCore.systemTick();
    try expect(task_control.running_priority == 1);
    try expect(mutex1.acquire(.{}) == OsCore.Error.TimedOut);
    task_control.setNextRunningTask();
    try mutex1.abortAcquire(&test_task1);

    //clean up
    try mutex1.deinit();
}

test "Mutex Timeout Test 2" {
    task_setup();
    var mutex1 = Mutex.create_mutex("test_mutex1");
    var mutex2 = Mutex.create_mutex("test_mutex1");
    try mutex1.init();
    try mutex2.init();
    mutex1._owner = &test_task4;
    mutex2._owner = &test_task4;

    try mutex1.acquire(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
    try mutex2.acquire(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 3);

    OsCore.systemTick();
    try expect(test_task1._state == OsTask.State.running);
    try expect(test_task1._SyncContext.timed_out);
    try expect(test_task2._state == OsTask.State.ready);
    try expect(test_task2._SyncContext.timed_out);

    //clean up
    try mutex1.deinit();
    try mutex2.deinit();
}

/////////////////////////////////////////////
//          Semaphore Unit Tests          //
///////////////////////////////////////////

test "Semaphore Init/Deinit Test" {
    var semaphore1 = Semaphore.create_semaphore(.{ .name = "test_sem1", .inital_value = 1 });
    var semaphore2 = Semaphore.create_semaphore(.{ .name = "test_sem2", .inital_value = 1 });
    var semaphore3 = Semaphore.create_semaphore(.{ .name = "test_sem3", .inital_value = 1 });
    //init test
    try semaphore1.init();
    try semaphore2.init();
    try semaphore3.init();

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

    try semaphore.wait(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == false);
    try expect(semaphore._count == 0);
    try semaphore.wait(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == true);
}

test "Semaphore Release Test" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    try semaphore.post(.{});

    try expect(semaphore._count == 1);
    try expect(TestArch.schedulerRan() == false);
}

test "Semaphore Release Test 2" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.wait(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
    try semaphore.post(.{});
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

    try semaphore.wait(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == true);
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 1);
    try semaphore.post(.{});
    try expect(semaphore._count == 0);
    try expect(TestArch.schedulerRan() == false);
}

test "Semaphore Abort Test" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.wait(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try semaphore.abortAcquire(&test_task1);
    try expect(test_task1._SyncContext.aborted == true);
    try expect(TestArch.schedulerRan());
    task_control.setNextRunningTask();
    try expect(semaphore.wait(.{ .timeout_ms = 0 }) == OsCore.Error.Aborted);
}

test "Semaphore Abort Test2" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.wait(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(semaphore.abortAcquire(&test_task2) == OsCore.Error.TaskNotBlockedBySync);
}

test "Semaphore timeout" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    try semaphore.init();

    try semaphore.wait(.{ .timeout_ms = 1 });
    OsCore.systemTick();
    try expect(task_control.running_priority == 1);
    try expect(semaphore.wait(.{}) == OsCore.Error.TimedOut);
    task_control.setNextRunningTask();
    try semaphore.abortAcquire(&test_task1);

    //clean up
    try semaphore.deinit();
}

test "Semaphore timeout2" {
    task_setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    var semaphore2 = Semaphore.create_semaphore(.{ .name = "test_sem2", .inital_value = 0 });

    try semaphore.init();
    try semaphore2.init();

    try semaphore.wait(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try semaphore2.wait(.{ .timeout_ms = 1 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 3);

    OsCore.systemTick();
    try expect(test_task1._state == OsTask.State.running);
    try expect(test_task1._SyncContext.timed_out);
    try expect(test_task2._state == OsTask.State.ready);
    try expect(test_task2._SyncContext.timed_out);
}

/////////////////////////////////////////////
//         Event Group Unit Tests         //
///////////////////////////////////////////

/////////////////////////////////////////////
//          Msg Queue Unit Tests          //
///////////////////////////////////////////

/////////////////////////////////////////////
//           Os Time Unit Tests           //
///////////////////////////////////////////

/////////////////////////////////////////////
//           Os Core Unit Tests           //
///////////////////////////////////////////

/////////////////////////////////////////////
//           Os Api Unit Tests            //
///////////////////////////////////////////
