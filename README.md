# RTOS

A Real Time Operating System written in Zig

## Features

- [X] Priority based scheduling
- [X] 32 priority levels for user tasks plus 1 resevered priority level (lowest prioirty) for the idle task
- [X] Unlimited tasks per priority level
- [X] Mutexes
  - [ ] Priority Inheritance
- [ ] Semaphores
- [X] Event Groups
- [ ] Messages Queues
- [ ] Software Timers
- [ ] Error System
- [ ] Debug information / Debug task

## Supported Architectures

- [ ] ARMv6-M: Cortex M0 & M0+
- [X] ARMv7-M: Cortex M3
- [ ] ARMv7-M: M4, & M7
  - [ ] Floating Point Coprocessor
- [ ] ARMv8-M
  - [ ] Floating Point Coprocessor
