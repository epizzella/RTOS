const std = @import("std");
const Semaphore = @import("source/synchronization/semaphore.zig").Semaphore;
const OsTask = @import("source/task.zig");
const TestArch = @import("source/arch/test/test_arch.zig");
const OsCore = @import("source/os_core.zig");
const OS = @import("os.zig");

const expect = std.testing.expect;
const task_control = &OsTask.task_control;
const Task = OsTask.Task;

var test_stack: [20]u32 = [_]u32{0xDEADC0DE} ** 20;
fn test_fn() !void {}
var test_task1 = Task.create_task(.{
    .name = "test",
    .priority = 1,
    .stack = &test_stack,
    .subroutine = &test_fn,
});

var test_task2 = Task.create_task(.{
    .name = "test",
    .priority = 2,
    .stack = &test_stack,
    .subroutine = &test_fn,
});

var idle_task = Task.create_task(.{
    .name = "idle task",
    .priority = 0, //Idle task priority is ignored
    .stack = &test_stack,
    .subroutine = &test_fn,
});

fn setup() void {
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
//          Semaphore Unit Tests          //
///////////////////////////////////////////

test "Semaphore Init/Deinit" {
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
    setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 1 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == false);
    try expect(semaphore._count == 0);
    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.schedulerRan() == true);
}

test "Semaphore Release Test" {
    setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    try semaphore.release();

    try expect(semaphore._count == 1);
    try expect(TestArch.schedulerRan() == false);
}

test "Semaphore Release Test 2" {
    setup();
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
    setup();
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
    setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(semaphore.abortAcquire(&test_task2) == OsCore.Error.TaskNotBlockedBySync);
}

test "Semaphore timeout" {
    setup();
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
    setup();
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
