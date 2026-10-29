# Halting Test: Unsupported fence instruction
# Expected end condition: illegal

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, tdat
    addi x2, x0, 42
    sw   x2, 0(x1)
    fence
    lw   x3, 0(x1)
    ecall
RVTEST_CODE_END

    .data
RVTEST_DATA_BEGIN
tdat:
    .word 0x00000000
RVTEST_DATA_END
