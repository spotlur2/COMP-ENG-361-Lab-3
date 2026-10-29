    .section .text.init
    .align 2
    .globl _start
_start:
    la   sp, _stack_top
    jal  ra, main
    ecall
