# Halting Test: Misaligned lw at offset +3 near the end of 16 KiB memory (0x00003ff3)
# Expected end condition: misaligned_load (must not write rd=x5)

#include "riscv_test.h"

RVTEST_CODE_BEGIN
    # Construct x1 = 0x00003ff0 (16 bytes below end of 16 KiB memory) using Milestone A ops
    addi x1, x0, (DATA_PAGE_HI + 2)
    slli x1, x1, 12
    addi x1, x1, -16
    addi x1, x1, 0x400
    addi x1, x1, 0x400
    addi x1, x1, 0x400
    addi x1, x1, 0x400
    addi x2, x0, 0x5a
    sw   x2, 0(x1)
    lw   x4, 0(x1)
    # Misaligned lw at 0x00003ff3 (offset +3 -> addr[1:0] == 2'b11)
    lw   x5, 3(x1)
    addi x10, x0, 99
    ecall
RVTEST_CODE_END
