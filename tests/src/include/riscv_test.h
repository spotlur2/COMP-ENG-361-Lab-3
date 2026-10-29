// Custom Minimal Bare-Metal RV32I Test Environment for CompEng 361 Lab 3
// Replaces upstream riscv-tests 'p' environment (no CSRs, no M-mode trap handler).
// Programs start at 0x00000000 and terminate with ecall (0x00000073).
// Self-check failures jump to RVTEST_FAIL (.word 0x00000000, illegal instruction)
// so make_golden.py detects any broken test immediately.

#ifndef _ENV_LAB3_RISCV_TEST_H
#define _ENV_LAB3_RISCV_TEST_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM x28

#define RVTEST_CODE_BEGIN \
    .section .text.init; \
    .align 2; \
    .globl _start; \
_start:

#define RVTEST_PASS ecall
#define RVTEST_FAIL .word 0x00000000
#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .align 4;
#define RVTEST_DATA_END

#ifdef SPIKE_RUN
#define DATA_PAGE_HI 0x101
#else
#define DATA_PAGE_HI 0x001
#endif

// For Milestone A tests, expand `li` and `la` using only Milestone A instructions
// (addi and slli) so Milestone A cores are not required to implement lui or auipc.
#ifndef MILESTONE_B
.macro li reg, val
    .set _uval, ((\val) & 0xffffffff)
    .if (_uval < 0x800)
        addi \reg, x0, _uval
    .elseif (_uval >= 0xfffff800)
        addi \reg, x0, (_uval - 0x100000000)
    .else
        addi \reg, x0, ((_uval >> 22) & 0x3ff)
        slli \reg, \reg, 11
        .if (((_uval >> 11) & 0x7ff) != 0)
            addi \reg, \reg, ((_uval >> 11) & 0x7ff)
        .endif
        slli \reg, \reg, 11
        .if ((_uval & 0x7ff) != 0)
            addi \reg, \reg, (_uval & 0x7ff)
        .endif
    .endif
.endm

.macro la reg, sym
    addi \reg, x0, DATA_PAGE_HI
    slli \reg, \reg, 12
    addi \reg, \reg, %lo(\sym)
.endm
#endif

#endif
