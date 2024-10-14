# RTOS

A Real Time Operating System written in Zig

## Features

- [X] Priority based scheduling
- [X] 32 priority levels for user tasks plus 1 resevered priority level (lowest prioirty) for the idle task
  - [X] Callback function for idle task
- [X] Unlimited tasks per priority level
- [X] Tasks return anyerror!void.  Users have the option to provide an error handler callback. 
- [X] Mutexes
  - [ ] Priority Inheritance
  - [X] Unit Tests
- [X] Semaphores
  - [X] Unit Tests
- [X] Event Groups
  - [ ] Unit Tests
- [X] Messages Queues
  - [ ] Unit Tests
- [ ] Software Timers
  - [ ] Unit Tests
- [ ] Debug information / Debug task
  - [ ] Unit Tests

## Supported Architectures

- [ ] ARMv6-M: Cortex M0 & M0+
- [X] ARMv7-M: Cortex M3
- [ ] ARMv7-M: M4, & M7
  - [ ] Floating Point Coprocessor
- [ ] ARMv8-M
  - [ ] Floating Point Coprocessor
