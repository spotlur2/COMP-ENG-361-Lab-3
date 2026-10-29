# Halting Test: R-type add/sub class (opcode=0110011, funct3=000) with invalid funct7 (0010000)
# Expected end condition: illegal (must not write rd=x5)

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 20
    addi x2, x0, 7
    add  x3, x1, x2
    sub  x4, x1, x2
    # opcode=0110011, rd=x5, funct3=000, rs1=x1, rs2=x2, funct7=0010000
    .word 0x202082b3
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
