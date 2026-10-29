# Halting Test: Unsupported / Illegal Opcode (custom-0 opcode 0001011 with rd=x3)
# Expected end condition: illegal

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 15
    addi x2, x0, 27
    add  x4, x1, x2
    # Custom-0 opcode (0001011) with rd = x3 (bits [11:7] = 00011)
    .word 0x0020818b
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
