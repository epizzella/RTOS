# Echo OS

Echo OS is a Real Time Operating System written in Zig.  As is tradition in the realm of RTOSes, Echo OS is really more of a real time kernel than an actual OS.

## Features

Echo OS has the following features:

- Premptive priority based scheduler
  - 32 priority levels for user tasks plus 1 resevered priority level (lowest prioirty) for the idle task
  - Unlimited tasks per priority level
- Syncronization
  - Event Groups
  - Mutexes
  - Semaphores
- Message Queues
- Software Timers
- Tasks return anyerror!void.  Users have the option to provide an error handler callback.

## Supported Architectures

- [X] ARMv6-M
- [X] ARMv7-M
- [ ] ARMv8-M
- [ ] ARMv8.1-M
- [ ] RISC-V

## Getting Started

Echo OS can be added to your project via zig fetch

```zig fetch --save git+https://github.com/epizzella/Echo-OS```

Then add the following to your ```build.zig```:

```
const rtos = b.dependency("EchoOS", .{ .target = target, .optimize = optimize });
elf.root_module.addImport("EchoOS", rtos.module("EchoOS"));
```

Echo OS uses the ```target``` argument at comptime to pull in the architecture specific files.

The entire API is accessabile through a single file:  os.zig.  You can use os.zig via @import: ```const Os = @import("EchoOS");```

The following is a basic example of creating a task and starting multitasking.  One task is created, the
OS is initalized, and multitasking is started.
```
const Os = @import("EchoOS");   //Import Echo OS 
const Task = Os.Task

//task 1 subroutine
fn task1() !void {          
  while(true) {}
}

//task 1 stack
const stackSize = 25;
var stack1: [stackSize]u32 = [_]u32{0xDEADC0DE} ** stackSize;   

//task 1
var tcb1 = Task.create_task(.{
    .name = "task1",
    .priority = 1,
    .stack = &stack1,
    .subroutine = &task1,
});

export fn main() void() {
  //Initialize  here

  Os.init();        // runtime hardware specific initalization
  tcb1.init();      // initalize the task & make the OS awares of it
  Os.startOS(.{});  // begin multitasking
  unreachable;
}
```

## Initalization and Start Up
### OS Config

## Tasks

### Time Managment

### Intertask Communication

## Synchronization
### Event Groups
### Mutexes
### Semaphores

## Software Timers
