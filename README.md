# RTOS

A Real Time Operating System written in Zig

## Features

- [X] Priority based scheduling
- [X] 32 priority levels for user tasks plus 1 resevered priority level (lowest prioirty) for the idle task
- [ ] Callback functions
  - [X] Idle task
  - [X] OS Tick
  - [ ] Task Return
    - [x] Individual Task Error Handler
    - [ ] Individual Task Exit Handler
  - [ ] Context Switch 
- [X] Unlimited tasks per priority level
- [X] Tasks return anyerror!void.  Users have the option to provide an error handler callback. 
- [X] Mutexes
  - [X] Priority Inheritance
  - [X] Unit Tests
- [X] Semaphores
  - [X] Unit Tests
- [X] Event Groups
  - [ ] Unit Tests
- [X] Messages Queues
  - [ ] Unit Tests
- [X] Software Timers
  - [ ] Unit Tests
- [ ] Debug information / Debug task
  - [ ] Unit Tests

## Supported Architectures

- [X] ARMv6-M
- [X] ARMv7-M
- [ ] ARMv8-M:
- [ ] ARMv8.1-M:
