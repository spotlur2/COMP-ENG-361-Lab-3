# Halting Test: jalr to a misaligned target (after clearing bit 0, bit 1 is 1)
# Expected end condition: misaligned_fetch (must not write rd=x3 on halt)
# First verifies jalr with bit 0 = 1 that clears to a 4-byte aligned target succeeds.

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, ok_target
    addi x1, x1, 1
    # (x1 + 0) has bit 0 = 1; clearing bit 0 gives ok_target (4-byte aligned)
    jalr x2, x1, 0
    addi x10, x0, 88
ok_target:
    la   x1, bad_base
    # (x1 + 3) & ~1 == bad_base + 2 (2-byte aligned, NOT 4-byte aligned -> HALT)
    jalr x3, x1, 3
bad_base:
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
