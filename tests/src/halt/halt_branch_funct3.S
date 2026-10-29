# Halting Test: Conditional branch (opcode=1100011) with reserved funct3 (010)
# Expected end condition: illegal

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 10
    addi x2, x0, 20
    beq  x1, x2, 1f
    # opcode=1100011, funct3=010, rs1=x1, rs2=x2, offset=+8
    .word 0x0020a463
1:
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
