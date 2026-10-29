# Halting Test: Unsupported M-extension instruction (mul x3, x1, x2)
# Expected end condition: illegal

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    addi x1, x0, 6
    addi x2, x0, 7
    # mul x3, x1, x2 (opcode=0110011, funct3=000, funct7=0000001, rd=x3)
    .word 0x022081b3
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
