# Echo OS

Echo OS is a Real Time Operating System written in Zig.  As is tradition in the realm of RTOSes, Echo OS is really more of a real time kernel than an actual OS.

## Features

Echo OS has the following features:

- Premptive priority based scheduler
  - 32 priority levels for user tasks plus 1 resevered priority level (lowest prioirty) for the idle task
  - Unlimited tasks per priority level
- Task Syncronization
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

The following is a basic example of creating a task and starting multitasking.  One task is created and multitasking is started.
```
const Os = @import("EchoOS");   //Import Echo OS 
const Task = Os.Task

//task 1 subroutine
fn task1() !void {          
  while(true) {}
}

//task stack
const stackSize = 25;
var stack1: [stackSize]u32 = [_]u32{0xDEADC0DE} ** stackSize;   

//Create a task
var tcb = Task.create_task(.{
    .name = "task",
    .priority = 1,
    .stack = &stack1,
    .subroutine = &task1,
});

export fn main() void() {
  //Initialize drivers before starting

  // initalize the task & make the OS awares of it
  tcb.init();      

  //Start multitasking
  Os.startOS(        
    .clock_config = .{
        .cpu_clock_freq_hz = 64_000_000,
        .os_sys_clock_freq_hz = 1000,
    },
  )
  
  unreachable;
}
```

## Initalization and Start Up
### OS Config

## Tasks
### Task Config
### Time Managment
### Intertask Communication

## Synchronization
### Event Groups
### Mutexes
### Semaphores

## Software Timers
