/*
 Copyright 2024 Edward Pizzella

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

.extern  current_task
.extern  next_task
.extern  g_stack_offset

.global PendSV_Handler

.thumb_func
PendSV_Handler:
    CPSID   I                           /*disable interrupts*/
    LDR     R2,     =g_stack_offset
    LDR     R2,     [R2]
    AND     R2,     R2,     0x0000000F
    LDR     R0,     =current_task       
    LDR     R1,     [R0]                
    CMP.W   R1,     #0                  /*if current_task != null*/
    BEQ.N   SpEqlNextSp                 
    PUSH    {R4-R11}                    /*push registers r4-r11 on the stack*/
    STR     SP,     [R1, R2]            /*save the current stack pointer in current_task*/
SpEqlNextSp:                          
    LDR     R3,     =next_task          
    LDR     R3,     [R3]                
    LDR     SP,     [R3, R2]            /*Set stack pointer to next_task stack pointer*/
    STR     R3,     [R0,#0x00]          /*Set current_task to next_task*/
    POP     {r4-r11}                    /*pop registers r4-r11*/
    CPSIE   I                           /*enable interrupts*/
    BX      LR                          /*return to task*/
.size PendSV_Handler, .-PendSV_Handler
