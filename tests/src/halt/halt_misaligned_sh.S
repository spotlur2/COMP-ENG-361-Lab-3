# Halting Test: Misaligned halfword store (sh to odd address)
# Expected end condition: misaligned_store

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, tdat
    addi x2, x0, 0x77
    sh   x2, 2(x1)
    # Misaligned sh to tdat + 1 (odd address)
    sh   x2, 1(x1)
    addi x10, x0, 99
    ecall
RVTEST_CODE_END

    .data
RVTEST_DATA_BEGIN
tdat:
    .word 0x00000000
    .word 0x00000000
RVTEST_DATA_END
