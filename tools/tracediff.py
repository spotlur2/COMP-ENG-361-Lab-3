#!/usr/bin/env python3
"""
Student-Facing Trace Diff Tool for CompEng 361 Lab 3 (tools/tracediff.py)

Usage:
    python3 tracediff.py <your_trace> <golden_trace>

Compares a student simulation trace against a golden reference trace and reports
the first instruction divergence in plain language with decoded RV32I assembly.
Exit code 0 on exact match, 1 on divergence or error.
"""

import os
import sys
from typing import Any, Dict, List, Optional, Tuple

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)
TOOLS_DIR = os.path.join(SCRIPT_DIR, "tools")
if os.path.isdir(TOOLS_DIR) and TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from disasm import disasm_hex


def parse_trace_line(line: str, line_num: int) -> Dict[str, Any]:
    """Parse a single trace line into a structured dictionary."""
    s = line.strip()
    if not s:
        return {"kind": "empty", "raw": s, "line_num": line_num}

    if s == "TIMEOUT":
        return {"kind": "timeout", "raw": s, "line_num": line_num}

    tokens = s.split()
    if tokens[0] == "HALT":
        rec: Dict[str, Any] = {
            "kind": "halt",
            "pc": None,
            "inst": None,
            "stray_rd": None,
            "stray_st": None,
            "raw": s,
            "line_num": line_num,
        }
        for tok in tokens[1:]:
            if tok.startswith("pc="):
                rec["pc"] = tok[3:]
            elif tok.startswith("inst="):
                rec["inst"] = tok[5:]
            elif tok.startswith("stray_rd="):
                rec["stray_rd"] = tok[9:]
            elif tok.startswith("stray_st="):
                rec["stray_st"] = tok[9:]
        return rec

    # Normal instruction record: <n> pc=<8 hex> inst=<8 hex> [rd=...] [ld=...] [st=...]
    try:
        step = int(tokens[0])
    except ValueError:
        return {"kind": "malformed", "raw": s, "line_num": line_num}

    rec = {
        "kind": "inst",
        "n": step,
        "pc": None,
        "inst": None,
        "rd": None,
        "ld": None,
        "st": None,
        "raw": s,
        "line_num": line_num,
    }
    for tok in tokens[1:]:
        if tok.startswith("pc="):
            rec["pc"] = tok[3:]
        elif tok.startswith("inst="):
            rec["inst"] = tok[5:]
        elif tok.startswith("rd="):
            rec["rd"] = tok[3:]
        elif tok.startswith("ld="):
            rec["ld"] = tok[3:]
        elif tok.startswith("st="):
            rec["st"] = tok[3:]
    return rec


def fmt_rd(rd_field: Optional[str]) -> str:
    if not rd_field:
        return "no register write"
    if ":" in rd_field:
        reg, val = rd_field.split(":", 1)
        return f"{reg} <- 0x{val}"
    return rd_field


def fmt_ld(ld_field: Optional[str]) -> str:
    if not ld_field:
        return "no memory load"
    if ":" in ld_field:
        addr, size = ld_field.split(":", 1)
        unit = "byte" if size == "1" else "bytes"
        return f"load mem[0x{addr}] ({size} {unit})"
    return ld_field


def fmt_st(st_field: Optional[str]) -> str:
    if not st_field:
        return "no memory store"
    parts = st_field.split(":")
    if len(parts) == 3:
        addr, size, data = parts
        unit = "byte" if size == "1" else "bytes"
        return f"mem[0x{addr}] ({size} {unit}) <- 0x{data}"
    return st_field


def load_trace(path: str) -> Tuple[Optional[List[Dict[str, Any]]], Optional[str]]:
    if not os.path.exists(path):
        return None, f"Missing trace file: '{path}' does not exist."
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw_lines = [ln.strip() for ln in f if ln.strip()]
    except OSError as e:
        return None, f"Could not read trace file '{path}': {e}"

    if not raw_lines:
        return None, f"Empty trace file: '{path}' contains no trace records."

    parsed = [parse_trace_line(ln, idx + 1) for idx, ln in enumerate(raw_lines)]
    return parsed, None


def compare_traces(yours_path: str, golden_path: str) -> Tuple[bool, str]:
    """
    Compare student trace against golden trace.
    Returns (passed: bool, message: str).
    """
    golden, g_err = load_trace(golden_path)
    if g_err:
        return False, f"Golden trace error: {g_err}"

    yours, y_err = load_trace(yours_path)
    if y_err:
        return False, y_err

    assert golden is not None and yours is not None

    min_len = min(len(yours), len(golden))
    for i in range(min_len):
        y = yours[i]
        g = golden[i]
        step_num = i + 1

        if y["kind"] == "malformed":
            return (
                False,
                f"Malformed trace record at line {y['line_num']}:\n"
                f"  yours: {y['raw']}",
            )

        # Case 1: Both are regular retired instructions
        if y["kind"] == "inst" and g["kind"] == "inst":
            g_pc = g["pc"]
            g_inst = g["inst"]
            g_asm = disasm_hex(g_inst, g_pc)

            if y["pc"] != g_pc:
                y_asm = disasm_hex(y["inst"], y["pc"])
                return (
                    False,
                    f"Divergence at instruction {g['n']} (wrong PC fetched)\n"
                    f"  yours:    PC 0x{y['pc']} ({y_asm})\n"
                    f"  expected: PC 0x{g_pc} ({g_asm})",
                )

            if y["inst"] != g_inst:
                y_asm = disasm_hex(y["inst"], y["pc"])
                return (
                    False,
                    f"Divergence at instruction {g['n']} (instruction word mismatch at PC 0x{g_pc})\n"
                    f"  yours:    0x{y['inst']} ({y_asm})\n"
                    f"  expected: 0x{g_inst} ({g_asm})",
                )

            if y["rd"] != g["rd"]:
                return (
                    False,
                    f"Divergence at instruction {g['n']}\n"
                    f"  PC 0x{g_pc}: {g_asm}\n"
                    f"  yours:    {fmt_rd(y['rd'])}\n"
                    f"  expected: {fmt_rd(g['rd'])}",
                )

            if y["ld"] != g["ld"]:
                return (
                    False,
                    f"Divergence at instruction {g['n']}\n"
                    f"  PC 0x{g_pc}: {g_asm}\n"
                    f"  yours:    {fmt_ld(y['ld'])}\n"
                    f"  expected: {fmt_ld(g['ld'])}",
                )

            if y["st"] != g["st"]:
                return (
                    False,
                    f"Divergence at instruction {g['n']}\n"
                    f"  PC 0x{g_pc}: {g_asm}\n"
                    f"  yours:    {fmt_st(y['st'])}\n"
                    f"  expected: {fmt_st(g['st'])}",
                )
            continue

        # Case 2: Student halted early while golden expected an instruction to retire
        if y["kind"] == "halt" and g["kind"] == "inst":
            g_asm = disasm_hex(g["inst"], g["pc"])
            y_asm = disasm_hex(y["inst"], y["pc"])
            msg = (
                f"Halted early at instruction {g['n']}\n"
                f"  PC 0x{g['pc']}: {g_asm}\n"
                f"  yours:    HALT at PC 0x{y['pc']} ({y_asm})\n"
                f"  expected: instruction {g['n']} to execute normally"
            )
            if y.get("stray_rd") or y.get("stray_st"):
                stray_parts = []
                if y.get("stray_rd"):
                    stray_parts.append(fmt_rd(y["stray_rd"]))
                if y.get("stray_st"):
                    stray_parts.append(fmt_st(y["stray_st"]))
                msg += f"\n  note:     also modified state on halt ({', '.join(stray_parts)})"
            return False, msg

        # Case 3: Student kept running past where it should have halted
        if y["kind"] == "inst" and g["kind"] == "halt":
            g_asm = disasm_hex(g["inst"], g["pc"])
            y_asm = disasm_hex(y["inst"], y["pc"])
            extra_effects = []
            if y.get("rd"):
                extra_effects.append(fmt_rd(y["rd"]))
            if y.get("ld"):
                extra_effects.append(fmt_ld(y["ld"]))
            if y.get("st"):
                extra_effects.append(fmt_st(y["st"]))
            eff_str = f" [{', '.join(extra_effects)}]" if extra_effects else ""
            return (
                False,
                f"Ran past where CPU should have halted (at step {step_num})\n"
                f"  PC 0x{g['pc']}: {g_asm}\n"
                f"  yours:    executed instruction at PC 0x{y['pc']} ({y_asm}){eff_str}\n"
                f"  expected: HALT at PC 0x{g['pc']} ({g_asm})",
            )

        # Case 4: Student timed out
        if y["kind"] == "timeout":
            if g["kind"] == "halt":
                g_asm = disasm_hex(g["inst"], g["pc"])
                return (
                    False,
                    f"Simulation timed out (never halted; expected HALT at PC 0x{g['pc']}: {g_asm})",
                )
            g_asm = disasm_hex(g["inst"], g["pc"])
            return (
                False,
                f"Simulation timed out at instruction {g['n']} (PC 0x{g['pc']}: {g_asm})",
            )

        # Case 5: Both halted at the same step
        if y["kind"] == "halt" and g["kind"] == "halt":
            g_asm = disasm_hex(g["inst"], g["pc"])
            y_asm = disasm_hex(y["inst"], y["pc"])
            if y["pc"] != g["pc"] or y["inst"] != g["inst"]:
                return (
                    False,
                    f"Halted on the wrong instruction (at step {step_num})\n"
                    f"  yours:    HALT at PC 0x{y['pc']} (inst 0x{y['inst']}: {y_asm})\n"
                    f"  expected: HALT at PC 0x{g['pc']} (inst 0x{g['inst']}: {g_asm})",
                )
            if y.get("stray_rd") or y.get("stray_st"):
                stray_desc = []
                if y.get("stray_rd"):
                    stray_desc.append(f"stray register write ({fmt_rd(y['stray_rd'])})")
                if y.get("stray_st"):
                    stray_desc.append(f"stray memory store ({fmt_st(y['stray_st'])})")
                return (
                    False,
                    f"State changed on the halting instruction\n"
                    f"  PC 0x{g['pc']}: {g_asm}\n"
                    f"  yours:    HALT with {', '.join(stray_desc)}\n"
                    f"  expected: HALT with no register or memory writes",
                )
            continue

    # If one trace is longer than the other (e.g., student trace ended without HALT or TIMEOUT)
    if len(yours) < len(golden):
        next_g = golden[len(yours)]
        if next_g["kind"] == "halt":
            g_asm = disasm_hex(next_g["inst"], next_g["pc"])
            return (
                False,
                f"Trace ended prematurely before HALT\n"
                f"  expected: HALT at PC 0x{next_g['pc']} ({g_asm})",
            )
        g_asm = disasm_hex(next_g["inst"], next_g["pc"])
        return (
            False,
            f"Trace ended prematurely before instruction {next_g['n']}\n"
            f"  expected: PC 0x{next_g['pc']} ({g_asm})",
        )

    if len(yours) > len(golden):
        extra_y = yours[len(golden)]
        if extra_y["kind"] == "timeout":
            return False, "Simulation timed out after matching prefix."
        return (
            False,
            f"Ran past HALT: trace contains extra record at line {extra_y['line_num']}:\n"
            f"  yours: {extra_y['raw']}",
        )

    retired_count = sum(1 for r in golden if r["kind"] == "inst")
    return True, f"PASS ({retired_count} instructions retired, HALT matched)"


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python3 tracediff.py <your_trace> <golden_trace>", file=sys.stderr)
        sys.exit(2)

    yours_path, golden_path = sys.argv[1], sys.argv[2]
    ok, msg = compare_traces(yours_path, golden_path)
    print(msg)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
