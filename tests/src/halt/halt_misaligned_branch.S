# Halting Test: Taken branch to a misaligned (non-multiple-of-4) target
# Expected end condition: misaligned_fetch
# Also verifies that an UNTAKEN branch with a misaligned offset does NOT halt.

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 10
    addi x2, x0, 20
    # Untaken branch with offset +6 (beq x1, x2, +6 -> NOT taken, must NOT halt)
    .word 0x00208363
    addi x3, x0, 30
    # Taken branch with offset +6 (beq x1, x1, +6 -> taken to PC+6, must HALT)
    .word 0x00108363
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
