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

const OsTask = @import("../../task.zig");
const Os = @import("../../../os.zig");

pub inline fn contextSwitch() void {
    asm volatile (
        \\  CPSID   I                                      
        \\  LDR     R0, [%[current_task]]                   
        \\  CMP     R0, #0                                       /* If current_task is null skip context save */
        \\  BEQ     ContextRestore
        \\
        \\  MRS     R12, PSP                                     /* Move process stack pointer into R12 */
        \\  SUBS    R12, R12, #0x24                              /* Ajust stack point for R4-R11 plus EXC_RETURN (LR) */
        \\  STR     R12, [R0, %[offset]]                         /* Save the current stack pointer in current_task */ 
        \\  STMIA   R12!, {R4-R7}                                /* Push registers R4-R7 on the stack */
        \\
        \\  MOV     R4, R8                                       /* Push registers R8-R11 on the stack */
        \\  MOV     R5, R9
        \\  MOV     R6, R10
        \\  MOV     R7, R11
        \\  STMIA   R12!, {R4-R7}
        \\
        \\  MOV     R4, LR                                       /* Push EXC_RETURN (LR) onto the stack */                              
        \\  STMIA   R12!, {R4} 
        \\
        \\ContextRestore:                                           
        \\  LDR     R12, [%[next_task], %[offset]]               /* Set stack pointer to next_task stack pointer */
        \\  ADDS    R12, #0x10
        \\  LDMIA   R12!, {R4-R7}                                /* Pop registers R8-R11 */  
        \\  MOV     R8,  R4                                                                
        \\  MOV     R9,  R5
        \\  MOV     R10, R6
        \\  MOV     R11, R7  
        \\
        \\  LDMIA   R12!, {R4}                                   /* Pop EXC_RETURN (LR) */
        \\  MOV     LR, R4                     
        \\  ORR     LR,  LR, #0x04                               /* Set EXC_RETURN process stack */
        \\
        \\  MSR     PSP, R12                                     /* Load PSP with new stack pointer */
        \\
        \\  SUBS    R12, #0x24                                   /* Pop register R4-R7 */
        \\  LDMIA   R12!, {R4-R7}
        \\
        \\  STR     %[next_task], [%[current_task], #0x00]       /* Set current_task to next_task */
        \\  CPSIE   I                                            /* enable interrupts */
        :
        : [next_task] "l" (OsTask.TaskControl.next_task),
          [current_task] "l" (&OsTask.TaskControl.current_task),
          [offset] "l" (Os.g_stack_offset),
        : "R0", "R4", "R5", "R6", "R7", "R12"
    );
    OsTask.TaskControl.current_task.?._state = OsTask.State.running;
}

/////////////////////////////////////////////
//   System Control Register Addresses    //
///////////////////////////////////////////
pub const ACTLR_ADDRESS: u32 = 0xE000E008; // Auxiliary Control Register

//SysTic Timer is optional on armv6-m
pub const STCSR_ADDRESS: u32 = 0xE000E010; // SysTick Control and Status Register
pub const STRVR_ADDRESS: u32 = 0xE000E014; // SysTick Reload Value Register
pub const STCVR_ADDRESS: u32 = 0xE000E018; // SysTick Current Value Register
pub const STCALIB_ADDRESS: u32 = 0xE000E01C; //  SysTick Calibration Value Register (Implementation specific)

pub const CPUID_ADDRESS: u32 = 0xE000ED00; // CPUID Base Register
pub const ICSR_ADDRESS: u32 = 0xE000ED04; //  Interrupt Control and State Register (RW or RO)
pub const VTOR_ADDRESS: u32 = 0xE000ED08; //  Vector Table Offset Register
pub const AIRCR_ADDRESS: u32 = 0xE000ED0C; // Application Interrupt and Reset Control Register
pub const SCR_ADDRESS: u32 = 0xE000ED10; //   System Control Register
pub const CCR_ADDRESS: u32 = 0xE000ED14; //   Configuration and Control Register
pub const SHPR2_ADDRESS: u32 = 0xE000ED1C; // System Handler Priority Register 2
pub const SHPR3_ADDRESS: u32 = 0xE000ED20; // System Handler Priority Register 3
pub const SHCSR_ADDRESS: u32 = 0xE000ED24; // System Handler Control and State Register
pub const DFSR_ADDRESS: u32 = 0xE000ED30; //  Debug Fault Status Register

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
    RESERVED_9_11: u3,
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
    RESERVED_0_21: u22,
    /// RW - Systme Handler 14 Priority
    PRI_PENDSV: u2,
    RESERVED_24_29: u6,
    /// RW - Systme Handler 15 Priority
    PRI_SYSTICK: u2,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};

///Debug Halting Control and Status Register
pub const DHCSR_REG = packed struct {
    /// RO - 0 = No debugger attached; 1 = Debugger attached
    C_DEBUGEN: bool,
    /// RW - 0 = Request processor run; 1 = Request processor halt
    C_HALT: bool,
    /// RW - 0 = Single step disable; 1 = Single step enabled
    C_STEP: bool,
    /// RW - 0 = Do not Mask; 1 = Mask PendSV, SysTick, & external interrupts
    C_MASKINTS: bool,
    RESERVED_4_15: u12,
    ///Debug key. Write 0xA05F to this field to enable write accesses to bits[15:0]
    DBGKEY: u16,

    comptime {
        if (@bitSizeOf(@This()) != @bitSizeOf(u32)) @compileError("Register struct must be must be 32 bits");
    }
};
