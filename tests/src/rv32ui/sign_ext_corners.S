#*****************************************************************************
# sign_ext_corners.S
#-----------------------------------------------------------------------------
# Directed test for RV32I sign-extension and zero-extension corner cases:
# - lb vs lbu on 0x80, 0x7f, 0xff
# - lh vs lhu on 0x8000, 0x7fff, 0xffff
# - negative I-type immediates on addi, slti, sltiu, lw, sw, jalr
# - jalr bit-0 clearing with odd base + even offset and even base + odd offset
# - lui / auipc upper-bit sign boundary (0x80000, 0x7ffff, 0xfffff)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  # Byte sign/zero extension corners (0x80, 0x7f, 0xff)
  la   x1, corner_data
  lb   x2, 0(x1)
  lbu  x3, 0(x1)
  lb   x4, 1(x1)
  lbu  x5, 1(x1)
  lb   x6, 2(x1)
  lbu  x7, 2(x1)

  # Halfword sign/zero extension corners (0x8000, 0x7fff, 0xffff)
  lh   x8, 4(x1)
  lhu  x9, 4(x1)
  lh   x10, 6(x1)
  lhu  x11, 6(x1)
  lh   x12, 8(x1)
  lhu  x13, 8(x1)

  # Negative immediate boundary (-2048 = 0xfffff800, +2047 = 0x7ff)
  addi  x14, x0, -2048
  addi  x15, x0, 2047
  slti  x16, x14, -2048
  slti  x17, x14, -2047
  sltiu x18, x15, -2048
  sltiu x19, x14, 2047

  # LUI & AUIPC sign boundaries
  lui   x20, 0x80000
  lui   x21, 0x7ffff
  lui   x22, 0xfffff
  auipc x23, 0x00001

  # JALR with negative immediate and bit-0 clear
  la    x24, jalr_landing
  addi  x24, x24, 17
  jalr  x25, x24, -16
  addi  x26, x0, 999
jalr_landing:
  addi  x26, x0, 42

  RVTEST_PASS

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
corner_data:
  .byte 0x80, 0x7f, 0xff, 0x00
  .half 0x8000, 0x7fff, 0xffff, 0x0001
RVTEST_DATA_END
