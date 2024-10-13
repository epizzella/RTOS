const Semaphore = @import("source/synchronization/semaphore.zig").Semaphore;
const OsTask = @import("source/task.zig");
const std = @import("std");
const TestArch = @import("source/arch/test/test_arch.zig");
const OsCore = @import("source/os_core.zig");
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

fn setup() void {
    OsCore.setOsStarted();
    test_task1._init = true;
    test_task2._init = true;
    task_control.readyTask(&test_task1);
    task_control.readyTask(&test_task2);
    task_control.setNextRunningTask();
}

test "Aquire Test" {
    setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 1 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.getScheduler() == false);
    try expect(semaphore._count == 0);
    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.getScheduler() == true);
}

test "Release Test" {
    setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    try semaphore.release();

    try expect(semaphore._count == 1);
    try expect(TestArch.getScheduler() == false);
}

test "Release Test 2" {
    setup();
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
    try semaphore.release();
    try expect(semaphore._count == 0);
    try expect(TestArch.getScheduler() == true);
}

test "Release Test 3" {
    OsCore.setOsStarted();
    try test_task1.suspendMe();
    task_control.readyTask(&test_task2);
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 2);
    task_control.readyTask(&test_task1);
    var semaphore = Semaphore.create_semaphore(.{ .name = "test_sem", .inital_value = 0 });
    semaphore._syncContext._init = true;

    try semaphore.acquire(.{ .timeout_ms = 0 });
    try expect(TestArch.getScheduler() == true);
    task_control.setNextRunningTask();
    try expect(task_control.running_priority == 1);
    try semaphore.release();
    try expect(semaphore._count == 0);
    try expect(TestArch.getScheduler() == false);
}
