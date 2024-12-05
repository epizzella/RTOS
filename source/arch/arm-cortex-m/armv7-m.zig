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

const std = @import("std");
const builtin = @import("builtin");

const OsTask = @import("../../task.zig");
const Os = @import("../../../os.zig");

pub const minStackSize = 17;
pub const LOWEST_PRIO_MSK: u8 = 0xFF;

pub inline fn contextSwitch() void {
    if (builtin.abi == std.Target.Abi.eabi) {
        asm volatile (
            \\  CPSID   I                                      
            \\  LDR     R0, [%[current_task]]                   
            \\  CMP     R0, #0                                       /* If current_task is null skip context save */
            \\  BEQ     ContextRestore 
            \\  MRS     R12, PSP                                     /* Move process stack pointer into R12 */
            \\  STMDB   R12!, {R4-R11, LR}                           /* push registers R4-R11 on the stack */
            \\  STR     R12, [R0, %[offset]]                         /* Save the current stack pointer in current_task */
            \\ContextRestore:                                           
            \\  LDR     R12, [%[next_task], %[offset]]               /* Set stack pointer to next_task stack pointer */
            \\  LDMIA   R12!, {R4-R11, LR}                           /* Pop registers R4-R11 */                                  
            \\  MSR     PSP, R12                                     /* Load PSP with new stack pointer */
            \\  STR     %[next_task], [%[current_task], #0x00]       /* Set current_task to next_task */
            \\  CPSIE   I
            \\  BX      LR
            :
            : [next_task] "l" (OsTask.TaskControl.next_task),
              [current_task] "l" (&OsTask.TaskControl.current_task),
              [offset] "l" (Os.g_stack_offset),
            : "R0", "R12"
        );
    } else if (builtin.abi == std.Target.Abi.eabihf) {
        asm volatile (
            \\  CPSID    I                                      
            \\  LDR      R0, [%[current_task]]                   
            \\  CMP      R0, #0                                       /* If current_task is null skip context save */
            \\  BEQ      ContextRestore 
            \\  MRS      R12, PSP                                     /* Move process stack pointer into R12 */
            \\ 
            \\  TST      LR, #0x10                                    /* If the task was using FPU push FPU registers */
            \\  IT       EQ
            \\  VSTMDBEQ R12!,{S16-S31}
            \\ 
            \\  STMDB    R12!, {R4-R11, LR}                           /* Push registers R4-R11 & LR on the stack */
            \\  STR      R12, [R0, %[offset]]                         /* Save the current stack pointer in current_task */
            \\ContextRestore:                                           
            \\  LDR      R12, [%[next_task], %[offset]]               /* Set stack pointer to next_task stack pointer */
            \\  LDMIA    R12!, {R4-R11, LR}                           /* Pop registers R4-R11 & LR */
            \\
            \\  TST      LR, #0x10                                    /* If the task was using FPU pop FPU registers */
            \\  IT       EQ
            \\  VLDMIAEQ R12!,{S16-S31} 
            \\                                   
            \\  MSR      PSP, R12                                     /* Load PSP with new stack pointer */
            \\  STR      %[next_task], [%[current_task], #0x00]       /* Set current_task to next_task */
            \\  CPSIE    I
            \\  BX       LR
            :
            : [next_task] "l" (OsTask.TaskControl.next_task),
              [current_task] "l" (&OsTask.TaskControl.current_task),
              [offset] "l" (Os.g_stack_offset),
            : "R0", "R12"
        );
    } else {
        @compileError("Invalid abi; abi must equal eabi or eabihf.");
    }
}

/////////////////////////////////////////////
//   System Control Register Addresses    //
///////////////////////////////////////////
pub const ACTLR_ADDRESS: u32 = 0xE000E008; // Auxiliary Control Register
pub const STCSR_ADDRESS: u32 = 0xE000E010; // SysTick Control and Status Register
pub const STRVR_ADDRESS: u32 = 0xE000E014; // SysTick Reload Value Register
pub const STCVR_ADDRESS: u32 = 0xE000E018; // SysTick Current Value Register
pub const STCR_ADDRESS: u32 = 0xE000E01C; //  SysTick Calibration Value Register (Implementation specific)
pub const CPUID_ADDRESS: u32 = 0xE000ED00; // CPUID Base Register
pub const ICSR_ADDRESS: u32 = 0xE000ED04; //  Interrupt Control and State Register (RW or RO)
pub const VTOR_ADDRESS: u32 = 0xE000ED08; //  Vector Table Offset Register
pub const AIRCR_ADDRESS: u32 = 0xE000ED0C; // Application Interrupt and Reset Control Register
pub const SCR_ADDRESS: u32 = 0xE000ED10; //   System Control Register
pub const CCR_ADDRESS: u32 = 0xE000ED14; //   Configuration and Control Register
pub const SHPR1_ADDRESS: u32 = 0xE000ED18; // System Handler Priority Register 1
pub const SHPR2_ADDRESS: u32 = 0xE000ED1C; // System Handler Priority Register 2
pub const SHPR3_ADDRESS: u32 = 0xE000ED20; // System Handler Priority Register 3
pub const SHCSR_ADDRESS: u32 = 0xE000ED24; // System Handler Control and State Register
pub const CFSR_ADDRESS: u32 = 0xE000ED28; //  Configurable Fault Status Registers
pub const HFSR_ADDRESS: u32 = 0xE000ED2C; //  HardFault Status Register
pub const DFSR_ADDRESS: u32 = 0xE000ED30; //  Debug Fault Status Register
pub const MMFAR_ADDRESS: u32 = 0xE000ED34; // MemManage Address Register
pub const BFAR_ADDRESS: u32 = 0xE000ED38; //  BusFault Address Register
pub const AFSR_ADDRESS: u32 = 0xE000ED3C; //  Auxiliary Fault Status Register
pub const ID_PFR0_ADDRESS: u32 = 0xE000ED40; //  Processor Feature Register 0
pub const ID_PFR1_ADDRESS: u32 = 0xE000ED44; //  Processor Feature Register 1
pub const ID_DFR0_ADDRESS: u32 = 0xE000ED48; //  Debug Features Register 0
pub const ID_AFR0_ADDRESS: u32 = 0xE000ED4C; //  Auxiliary Features Register 0
pub const ID_MMFR0_ADDRESS: u32 = 0xE000ED50; // Memory Model Feature Register 0
pub const ID_MMFR1_ADDRESS: u32 = 0xE000ED54; // Memory Model Feature Register 1
pub const ID_MMFR2_ADDRESS: u32 = 0xE000ED58; // Memory Model Feature Register 2
pub const ID_MMFR3_ADDRESS: u32 = 0xE000ED5C; // Memory Model Feature Register 3
pub const ID_ISAR0_ADDRESS: u32 = 0xE000ED60; // Instruction Set Attributes Register 0
pub const ID_ISAR1_ADDRESS: u32 = 0xE000ED64; // Instruction Set Attributes Register 1
pub const ID_ISAR2_ADDRESS: u32 = 0xE000ED68; // Instruction Set Attributes Register 2
pub const ID_ISAR3_ADDRESS: u32 = 0xE000ED6C; // Instruction Set Attributes Register 3
pub const ID_ISAR4_ADDRESS: u32 = 0xE000ED70; // Instruction Set Attributes Register 4
pub const CPACR_ADDRESS: u32 = 0xE000ED88; //    Coprocessor Access Control Register
pub const STIR_ADDRESS: u32 = 0xE000EF00; //     Software Triggered Interrupt Register

//System Debug Registers
pub const DHCSR_ADDRESS: u32 = 0xE000EDF0; // Halting Control and Status Register
pub const DCRSR_ADDRESS: u32 = 0xE000EDF4; // Core Register Selector Register
pub const DCRDR_ADDRESS: u32 = 0xE000EDF8; // Core Register Data Register
pub const DEMCR_ADDRESS: u32 = 0xE000EDFC; // Exception and Monitor Control Register

/////////////////////////////////////////////
//    System Control Register Structs     //
///////////////////////////////////////////

///Interrupt Control State Register
pub const ICSR_REG = packed struct {
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

///System Handler Priority Register 3
pub const SHPR3_REG = packed struct {
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

///
pub const DEMCR_REG = packed struct {
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

///Debug Halting Control and Status Register
pub const DHCSR_REG = packed struct {
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
    ///Debug key. Write 0xA05F to this field to enable write accesses to bits[15:0]
    DBGKEY: u16,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};
