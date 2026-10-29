# Halting Test: slli with invalid nonzero funct7 (0100000)
# Expected end condition: illegal (must not write rd=x4)

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 5
    slli x3, x1, 2
    # opcode=0010011, rd=x4, funct3=001, rs1=x1, shamt=1, funct7=0100000
    .word 0x40109213
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
