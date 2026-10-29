# Halting Test: Misaligned halfword load (lh from odd address)
# Expected end condition: misaligned_load

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, tdat
    addi x2, x0, 0x123
    sh   x2, 2(x1)
    lh   x5, 2(x1)
    # Misaligned lh from tdat + 1 (odd address, rd=x4)
    lh   x4, 1(x1)
    addi x10, x0, 99
    ecall
RVTEST_CODE_END

    .data
RVTEST_DATA_BEGIN
tdat:
    .word 0x00000000
    .word 0x00000000
RVTEST_DATA_END
