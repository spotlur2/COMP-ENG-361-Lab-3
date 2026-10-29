# Halting Test: Store (opcode=0100011) with reserved funct3 (011, RV64 sd)
# Expected end condition: illegal (must not write memory)

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    la   x1, tdat
    addi x2, x0, 0x77
    sw   x2, 0(x1)
    # opcode=0100011, funct3=011, rs1=x1, rs2=x2, imm=4
    .word 0x0020b223
    addi x10, x0, 99
    ecall
RVTEST_CODE_END

    .data
RVTEST_DATA_BEGIN
tdat:
    .word 0x00000000
    .word 0x00000000
RVTEST_DATA_END
