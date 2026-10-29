# Halting Test: jal to a misaligned (non-multiple-of-4) target
# Expected end condition: misaligned_fetch (must not write rd=x3 on halt)

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 5
    jal  x2, aligned_target
    addi x1, x0, 99
aligned_target:
    addi x1, x1, 10
    # jal x3, +6 (imm = 6, target = PC + 6, not 4-byte aligned, rd = x3)
    .word 0x006001ef
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
