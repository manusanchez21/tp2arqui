.section .text
.global _start

_start:
    ldr x0, =_stack_end
    mov sp, x0

    mov x0, #0x18
    movk x0, #0x0200, lsl #16
    mov x1, #0
    hlt #0xF000
