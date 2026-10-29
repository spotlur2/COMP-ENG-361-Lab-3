# Halting Test: Misaligned word load (lw from address not divisible by 4)
# Expected end condition: misaligned_load

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, tdat
    addi x2, x0, 0x123
    sw   x2, 0(x1)
    lw   x4, 0(x1)
    # Misaligned lw from tdat + 2 (2-byte aligned, not 4-byte aligned, rd=x3)
    lw   x3, 2(x1)
    addi x10, x0, 99
    ecall
RVTEST_CODE_END

    .data
RVTEST_DATA_BEGIN
tdat:
    .word 0x00000000
    .word 0x00000000
RVTEST_DATA_END
