# Halting Test: Misaligned word store (sw to address not divisible by 4)
# Expected end condition: misaligned_store

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, tdat
    addi x2, x0, 0x55
    sw   x2, 0(x1)
    # Misaligned sw to tdat + 2 (not divisible by 4)
    sw   x2, 2(x1)
    addi x10, x0, 99
    ecall
RVTEST_CODE_END

    .data
RVTEST_DATA_BEGIN
tdat:
    .word 0x00000000
    .word 0x00000000
RVTEST_DATA_END
