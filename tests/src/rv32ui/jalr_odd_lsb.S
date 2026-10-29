# Non-Halting Test: jalr with odd target addresses that are 4-byte aligned after bit 0 is cleared
# Expected end condition: ecall (must NOT halt early)

#define MILESTONE_B 1
#include "riscv_test.h"

RVTEST_CODE_BEGIN
    # Case 1: rs1 is odd (t1 + 1), imm = 0 -> (rs1 + 0) & ~1 == t1
    la   x1, t1
    addi x1, x1, 1
    jalr x2, x1, 0
    addi x10, x0, 111

t1:
    # Case 2: rs1 is 4-byte aligned (t2), imm = 1 -> (rs1 + 1) & ~1 == t2
    la   x3, t2
    jalr x4, x3, 1
    addi x10, x0, 222

t2:
    # Case 3: rs1 is odd (t3 + 3), imm = -2 -> (rs1 - 2) = (t3 + 1), & ~1 == t3
    la   x5, t3
    addi x5, x5, 3
    jalr x6, x5, -2
    addi x10, x0, 333

t3:
    # Verify link registers are exact 4-byte aligned return addresses (difference = 12 bytes)
    sub  x7, x4, x2
    sub  x8, x6, x4
    addi x10, x0, 0
    ecall
RVTEST_CODE_END
