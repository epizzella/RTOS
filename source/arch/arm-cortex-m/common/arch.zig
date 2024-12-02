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

const OsTask = @import("../../../task.zig");
const OsCore = @import("../../../os_core.zig");

const task_ctrl = &OsTask.task_control;
const Task = OsTask.Task;

pub const Self = @This();

/////////////////////////////////////////////
//        System Control Registers        //
///////////////////////////////////////////
ICSR: *volatile ICSR_REG = @ptrFromInt(ICSR_ADDRESS),
SHPR3: *volatile SHPR3_REG = @ptrFromInt(SHPR3_ADDRESS),
DEMCR: *volatile DEMCR_REG = @ptrFromInt(DEMCR_ADDRESS),
DHCSR: *volatile DHCSR_REG = @ptrFromInt(DHCSR_ADDRESS),

/////////////////////////////////////////////////////////
//    Architecture specific Function Implemntations   //
///////////////////////////////////////////////////////
pub fn coreInit(self: *Self) void {
    self.SHPR3.PRI_PENDSV = LOWEST_PRIO_MSK; //Set the pendsv to the lowest priority to avoid context switch during ISR
    self.SHPR3.PRI_SYSTICK = ~LOWEST_PRIO_MSK; //Set sysTick to the highest priority.
}

pub fn initStack(self: *Self, task: *Task) void {
    _ = self;
    task._stack_ptr = @intFromPtr(&task._stack.ptr[task._stack.len - 16]);
    task._stack.ptr[task._stack.len - 1] = 0x1 << 24; // xPSR
    task._stack.ptr[task._stack.len - 2] = @intFromPtr(&OsTask.taskTopRoutine); // PC
}

pub fn interruptActive(self: *Self) bool {
    return self.ICSR.VECTACTIVE > 0;
}

///Enable Interrupts
pub inline fn criticalEnd(self: *Self) void {
    _ = self;
    asm volatile ("CPSIE    I");
}

///Disable Interrupts
pub inline fn criticalStart(self: *Self) void {
    _ = self;
    asm volatile ("CPSID    I");
}

pub inline fn runScheduler(self: *Self) void {
    _ = self;
    asm volatile ("SVC    #0");
}

pub inline fn runContextSwitch(self: *Self) void {
    self.ICSR.PENDSVSET = true;
}

pub inline fn startOs(self: *Self) void {
    _ = self;
    // firstContextSwitch();
}

pub inline fn isDebugAttached(self: *Self) bool {
    return self.DHCSR.C_DEBUGEN;
}

// extern var current_task: ?*volatile Task;
// extern var next_task: *volatile Task;
// extern var g_stack_offset: usize;

export var my_test: u32 = 10;

// pub export fn contextSwitch() void {
//     //var running = task_ctrl.getRunningTask();
//     // _ = current_task;
//     // asm volatile (
//     //     \\      CPSID   I                           /*disable interrupts*/
//     //     \\      LDR     R1,     =current_task
//     //     \\      LDR     R0,     [R1]
//     //     \\      PUSH    {R4-R11}                    /*push registers r4-r11 on the stack*/
//     //     \\      STR     SP,     [R0, %[offset]]     /*save the current stack pointer in current_task*/
//     //     \\      LDR     R3,     =next_task
//     //     \\      LDR     R3,     [R3]
//     //     \\      LDR     SP,     [R3, %[offset]]     /*Set stack pointer to next_task stack pointer*/
//     //     \\      STR     R3,     [R1, #0x00]         /*Set current_task to next_task*/
//     //     \\      POP     {r4-r11}                    /*pop registers r4-r11*/
//     //     \\      CPSIE   I                           /*enable interrupts*/
//     //     :
//     //     : [offset] "l" (g_stack_offset),
//     //       //[r_task] "l" (&running),
//     // );
//     // _ = my_test;
//     // asm volatile (
//     //     \\  LDR     R1, =my_test
//     // );
// }

// pub inline fn firstContextSwitch() void {
//     asm volatile (
//         \\      CPSID   I                           /*disable interrupts*/
//         \\      LDR     R0,     =next_task
//         \\      LDR     R0,     [R0]
//         \\      LDR     SP,     [R0, %[offset]]     /*Set stack pointer to next_task stack pointer*/
//         \\      POP     {r4-r11}                    /*pop registers r4-r11*/
//         \\      CPSIE   I                           /*enable interrupts*/
//         :
//         : [offset] "l" (g_stack_offset),
//     );
// }
/////////////////////////////////////////////
//         Exception Handlers             //
///////////////////////////////////////////

export fn SysTick_Handler() void {
    var self = Self{};
    self.criticalStart();
    OsCore.OsTick();
    self.criticalEnd();
}

export fn SVC_Handler() void {
    var self = Self{};
    self.criticalStart();
    OsCore.schedule();
    self.criticalEnd();
}

// export fn PendSV_Handler() void {
//     contextSwitch();
// }

/////////////////////////////////////////////
//   System Control Register Addresses    //
///////////////////////////////////////////
const ACTLR_ADDRESS: u32 = 0xE000E008; // Auxiliary Control Register
const STCSR_ADDRESS: u32 = 0xE000E010; // SysTick Control and Status Register
const STRVR_ADDRESS: u32 = 0xE000E014; // SysTick Reload Value Register (Unknown)
const STCVR_ADDRESS: u32 = 0xE000E018; // SysTick Current Value Register (clear Unknown)
const STCR_ADDRESS: u32 = 0xE000E01C; //  SysTick Calibration Value Register (Implementation specific)
const CPUID_ADDRESS: u32 = 0xE000ED00; // CPUID Base Register
const ICSR_ADDRESS: u32 = 0xE000ED04; //  Interrupt Control and State Register (RW or RO)
const VTOR_ADDRESS: u32 = 0xE000ED08; //  Vector Table Offset Register
const AIRCR_ADDRESS: u32 = 0xE000ED0C; // Application Interrupt and Reset Control Register
const SCR_ADDRESS: u32 = 0xE000ED10; //   System Control Register
const CCR_ADDRESS: u32 = 0xE000ED14; //   Configuration and Control Register
const SHPR1_ADDRESS: u32 = 0xE000ED18; // System Handler Priority Register 1
const SHPR2_ADDRESS: u32 = 0xE000ED1C; // System Handler Priority Register 2
const SHPR3_ADDRESS: u32 = 0xE000ED20; // System Handler Priority Register 3
const SHCSR_ADDRESS: u32 = 0xE000ED24; // System Handler Control and State Register
const CFSR_ADDRESS: u32 = 0xE000ED28; //  Configurable Fault Status Registers
const HFSR_ADDRESS: u32 = 0xE000ED2C; //  HardFault Status Register
const DFSR_ADDRESS: u32 = 0xE000ED30; //  Debug Fault Status Register
const MMFAR_ADDRESS: u32 = 0xE000ED34; // MemManage Address Register
const BFAR_ADDRESS: u32 = 0xE000ED38; //  BusFault Address Register
const AFSR_ADDRESS: u32 = 0xE000ED3C; //  Auxiliary Fault Status Register
const ID_PFR0_ADDRESS: u32 = 0xE000ED40; //  Processor Feature Register 0
const ID_PFR1_ADDRESS: u32 = 0xE000ED44; //  Processor Feature Register 1
const ID_DFR0_ADDRESS: u32 = 0xE000ED48; //  Debug Features Register 0
const ID_AFR0_ADDRESS: u32 = 0xE000ED4C; //  Auxiliary Features Register 0
const ID_MMFR0_ADDRESS: u32 = 0xE000ED50; // Memory Model Feature Register 0
const ID_MMFR1_ADDRESS: u32 = 0xE000ED54; // Memory Model Feature Register 1
const ID_MMFR2_ADDRESS: u32 = 0xE000ED58; // Memory Model Feature Register 2
const ID_MMFR3_ADDRESS: u32 = 0xE000ED5C; // Memory Model Feature Register 3
const ID_ISAR0_ADDRESS: u32 = 0xE000ED60; // Instruction Set Attributes Register 0
const ID_ISAR1_ADDRESS: u32 = 0xE000ED64; // Instruction Set Attributes Register 1
const ID_ISAR2_ADDRESS: u32 = 0xE000ED68; // Instruction Set Attributes Register 2
const ID_ISAR3_ADDRESS: u32 = 0xE000ED6C; // Instruction Set Attributes Register 3
const ID_ISAR4_ADDRESS: u32 = 0xE000ED70; // Instruction Set Attributes Register 4
const CPACR_ADDRESS: u32 = 0xE000ED88; //    Coprocessor Access Control Register
const STIR_ADDRESS: u32 = 0xE000EF00; //     Software Triggered Interrupt Register

//System Debug Registers
const DHCSR_ADDRESS: u32 = 0xE000EDF0; // Halting Control and Status Register
const DCRSR_ADDRESS: u32 = 0xE000EDF4; // Core Register Selector Register
const DCRDR_ADDRESS: u32 = 0xE000EDF8; // Core Register Data Register
const DEMCR_ADDRESS: u32 = 0xE000EDFC; // Exception and Monitor Control Register

//Bit Masks
const LOWEST_PRIO_MSK: u8 = 0xFF;

/////////////////////////////////////////////
//    System Control Register Structs     //
///////////////////////////////////////////
const REGISTER_SIZE = 32; //32 bit registers

const ICSR_REG = packed struct {
    /// RO - Current executing exception's number. A value of 0 = Thread mode
    VECTACTIVE: u9,
    RESERVED_9_10: u2,
    /// RO - Handler mode: Indicates if there is active exception other than the  one indicated by IPSR; Thread mode: N/A
    RETTOBASE: bool,
    /// RO - Highest priority pending enabled execption's number
    VECTPENDING: u9,
    RESERVED_21: u1,
    /// RO - Extneral interrrupt pending
    ISRPENDING: bool,
    /// RO - Service pending execption on on exit from debug halt
    ISRPREEMPT: bool,
    RESERVED_24: u1,
    /// WO - 0 = No effect; 1 = Clear SysTick pending status
    PENDSTCLR: bool,
    /// WR - Write: sets SysTick exception pending. Reads: indicates state of SysTick exception
    PENDSTSET: bool,
    /// WO - 0 = No effect; 1 = Clear PendSV pending status
    PENDSVCLR: bool,
    /// WR - Write: sets PendSV exception pending. Reads: indicates state of PendSV exception
    PENDSVSET: bool,
    RESERVED_29_30: u2,
    /// RW - Write: sets NMI exception pending. Reads: indicates state of NMI exception
    NMIPENDSET: bool,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};

const SHPR3_REG = packed struct {
    /// RW - Systme Handler 12 Priority
    PRI_DEBUG_MON: u8,
    RESERVED: u8,
    /// RW - Systme Handler 14 Priority
    PRI_PENDSV: u8,
    /// RW - Systme Handler 12 Priority
    PRI_SYSTICK: u8,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};

const DEMCR_REG = packed struct {
    /// RW - Enable Reset Vector Catch.  This will cause a local reset to halt the system.
    VC_CORERESET: bool,
    RESERVED_1_3: u3,
    /// RW - Enable halting debug trap: MemManage Execption
    VC_MMERR: bool,
    /// RW - Enable halting debug trap: UsageFault caused by coprocessor
    VC_NOCERR: bool,
    /// RW - Enable halting debug trap: UsageFault caused by checking error
    VC_CHKERR: bool,
    /// RW - Enable halting debug trap: UsageFault caused by state information error
    VC_STATERR: bool,
    /// RW - Enable halting debug trap: BusFault Execption
    VC_BUSERR: bool,
    /// RW - Enable halting debug trap: Exception entry or return
    VC_INTER: bool,
    /// RW - Enable halting debug trap: HardFault Execption
    VC_HARDERR: bool,
    RESERVED_11_15: u5,
    /// RW - Enable DebugMonitor execption
    MON_EN: bool,
    /// RW - Write: 0 = Clear; 1 Set;  Pending state of DebugMonitor execption
    MON_PEND: bool,
    /// RW - When MON_EN == 1; Write: 0 = Do not step; 1 = Step the processor
    MON_STEP: bool,
    ///DebugMonitor semaphore bit. The processor does not use this bit. The monitor software defines the meaning and use of this bit.
    MON_REQ: bool,
    RESERVED_20_23: u4,
    /// RW - Write: 0 = DWT and ITM units disabled; 1 = DWT and ITM units enabled
    TRCENA: bool,
    RESERVED_25_31: u7,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};

const DHCSR_REG = packed struct {
    /// RO - 0 = No debugger attached; 1 = Debugger attached
    C_DEBUGEN: bool,
    /// RW -
    C_HALT: bool,
    ///
    C_STEP: bool,
    ///
    C_MASKINTS: bool,
    RESERVED_4: bool,
    ///
    C_SNAPSTALL: bool,
    RESERVED_6_15: u10,
    ///Debug key. A debugger must write 0xA05F to this field to enable write accesses to bits[15:0]
    DBGKEY: u16,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};
