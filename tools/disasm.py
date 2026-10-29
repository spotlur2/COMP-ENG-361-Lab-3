#!/usr/bin/env python3
"""
RV32I Disassembler for CompEng 361 Lab 3 (tools/disasm.py)
Pure Python 3 standard library. Uses x0..x31 architectural register names
to match trace output fields (e.g., rd=x5:...).
"""

import sys


def sign_extend(val: int, bits: int) -> int:
    sign_bit = 1 << (bits - 1)
    return (val & (sign_bit - 1)) - (val & sign_bit)


def fmt_imm_hex_or_dec(val: int, signed: bool = True) -> str:
    if signed:
        return str(val)
    return f"0x{val & 0xFFFFFFFF:x}"


def disasm(inst_word: int, pc: int = None) -> str:
    """Disassemble a 32-bit RISC-V instruction word into a human-readable string."""
    inst = inst_word & 0xFFFFFFFF
    opcode = inst & 0x7F
    rd = (inst >> 7) & 0x1F
    funct3 = (inst >> 12) & 0x7
    rs1 = (inst >> 15) & 0x1F
    rs2 = (inst >> 20) & 0x1F
    funct7 = (inst >> 25) & 0x7F

    imm_i = sign_extend((inst >> 20) & 0xFFF, 12)
    imm_s = sign_extend(((inst >> 25) << 5) | ((inst >> 7) & 0x1F), 12)
    imm_b = sign_extend(
        (((inst >> 31) & 0x1) << 12)
        | (((inst >> 7) & 0x1) << 11)
        | (((inst >> 25) & 0x3F) << 5)
        | (((inst >> 8) & 0xF) << 1),
        13,
    )
    imm_u = (inst >> 12) & 0xFFFFF
    imm_j = sign_extend(
        (((inst >> 31) & 0x1) << 20)
        | (((inst >> 12) & 0xFF) << 12)
        | (((inst >> 20) & 0x1) << 11)
        | (((inst >> 21) & 0x3FF) << 1),
        21,
    )

    # LUI
    if opcode == 0b0110111:
        return f"lui x{rd}, 0x{imm_u:x}"

    # AUIPC
    if opcode == 0b0010111:
        return f"auipc x{rd}, 0x{imm_u:x}"

    # JAL
    if opcode == 0b1101111:
        if pc is not None:
            target = (pc + imm_j) & 0xFFFFFFFF
            return f"jal x{rd}, {imm_j} (target 0x{target:08x})"
        return f"jal x{rd}, {imm_j}"

    # JALR
    if opcode == 0b1100111:
        if funct3 == 0b000:
            return f"jalr x{rd}, {imm_i}(x{rs1})"
        return f"illegal_jalr (0x{inst:08x})"

    # BRANCH
    if opcode == 0b1100011:
        b_names = {
            0b000: "beq",
            0b001: "bne",
            0b100: "blt",
            0b101: "bge",
            0b110: "bltu",
            0b111: "bgeu",
        }
        mnem = b_names.get(funct3)
        if mnem:
            if pc is not None:
                target = (pc + imm_b) & 0xFFFFFFFF
                return f"{mnem} x{rs1}, x{rs2}, {imm_b} (target 0x{target:08x})"
            return f"{mnem} x{rs1}, x{rs2}, {imm_b}"
        return f"illegal_branch (0x{inst:08x})"

    # LOAD
    if opcode == 0b0000011:
        l_names = {
            0b000: "lb",
            0b001: "lh",
            0b010: "lw",
            0b100: "lbu",
            0b101: "lhu",
        }
        mnem = l_names.get(funct3)
        if mnem:
            return f"{mnem} x{rd}, {imm_i}(x{rs1})"
        return f"illegal_load (0x{inst:08x})"

    # STORE
    if opcode == 0b0100011:
        s_names = {
            0b000: "sb",
            0b001: "sh",
            0b010: "sw",
        }
        mnem = s_names.get(funct3)
        if mnem:
            return f"{mnem} x{rs2}, {imm_s}(x{rs1})"
        return f"illegal_store (0x{inst:08x})"

    # OP-IMM
    if opcode == 0b0010011:
        shamt = rs2
        if funct3 == 0b000:
            return f"addi x{rd}, x{rs1}, {imm_i}"
        if funct3 == 0b010:
            return f"slti x{rd}, x{rs1}, {imm_i}"
        if funct3 == 0b011:
            return f"sltiu x{rd}, x{rs1}, {imm_i}"
        if funct3 == 0b100:
            return f"xori x{rd}, x{rs1}, {imm_i}"
        if funct3 == 0b110:
            return f"ori x{rd}, x{rs1}, {imm_i}"
        if funct3 == 0b111:
            return f"andi x{rd}, x{rs1}, {imm_i}"
        if funct3 == 0b001 and funct7 == 0b0000000:
            return f"slli x{rd}, x{rs1}, {shamt}"
        if funct3 == 0b101 and funct7 == 0b0000000:
            return f"srli x{rd}, x{rs1}, {shamt}"
        if funct3 == 0b101 and funct7 == 0b0100000:
            return f"srai x{rd}, x{rs1}, {shamt}"
        return f"illegal_op_imm (0x{inst:08x})"

    # OP (Register-Register, including M-extension decoding for clarity on halt)
    if opcode == 0b0110011:
        if funct7 == 0b0000000:
            r_names = {
                0b000: "add",
                0b001: "sll",
                0b010: "slt",
                0b011: "sltu",
                0b100: "xor",
                0b101: "srl",
                0b110: "or",
                0b111: "and",
            }
            mnem = r_names.get(funct3)
            if mnem:
                return f"{mnem} x{rd}, x{rs1}, x{rs2}"
        elif funct7 == 0b0100000:
            if funct3 == 0b000:
                return f"sub x{rd}, x{rs1}, x{rs2}"
            if funct3 == 0b101:
                return f"sra x{rd}, x{rs1}, x{rs2}"
        elif funct7 == 0b0000001:
            m_names = {
                0b000: "mul",
                0b001: "mulh",
                0b010: "mulhsu",
                0b011: "mulhu",
                0b100: "div",
                0b101: "divu",
                0b110: "rem",
                0b111: "remu",
            }
            mnem = m_names.get(funct3, "muldiv")
            return f"{mnem} x{rd}, x{rs1}, x{rs2} [unsupported M-ext]"
        return f"illegal_op (0x{inst:08x})"

    # MISC-MEM (FENCE)
    if opcode == 0b0001111:
        if funct3 == 0b000:
            return "fence [unsupported]"
        if funct3 == 0b001:
            return "fence.i [unsupported]"
        return f"misc_mem (0x{inst:08x}) [unsupported]"

    # SYSTEM (ECALL / EBREAK / CSR)
    if opcode == 0b1110011:
        if inst == 0x00000073:
            return "ecall"
        if inst == 0x00100073:
            return "ebreak [unsupported]"
        csr_names = {
            0b001: "csrrw",
            0b010: "csrrs",
            0b011: "csrrc",
            0b101: "csrrwi",
            0b110: "csrrsi",
            0b111: "csrrci",
        }
        mnem = csr_names.get(funct3)
        if mnem:
            csr = (inst >> 20) & 0xFFF
            return f"{mnem} x{rd}, 0x{csr:03x}, x{rs1} [unsupported CSR]"
        return f"system (0x{inst:08x}) [unsupported]"

    return f"illegal (0x{inst:08x})"


def disasm_hex(inst_hex: str, pc_hex: str = None) -> str:
    """Disassemble hex strings (handling 'x' unknowns gracefully)."""
    if not inst_hex or any(c not in "0123456789abcdefABCDEF" for c in inst_hex):
        return f"unknown ({inst_hex})"
    pc_val = None
    if pc_hex and all(c in "0123456789abcdefABCDEF" for c in pc_hex):
        pc_val = int(pc_hex, 16)
    return disasm(int(inst_hex, 16), pc_val)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        val = int(arg, 16)
        print(f"0x{val:08x}: {disasm(val)}")
