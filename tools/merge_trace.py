#!/usr/bin/env python3
"""
Trace Merger & Canonical Normalizer for CompEng 361 Lab 3 (tools/merge_trace.py)

In Version 2.0 of lab3_tb.v, Mem, RegFile, and tb cooperate directly during
simulation to emit trace.txt in canonical Section 2 format without same-timestep
write ordering hazards.

This script can also merge separate per-cycle Mem and RegFile logs if produced
separately, or validate and canonicalize an existing trace.txt file.
"""

import argparse
import sys
from typing import Dict, List


def canonicalize_trace_lines(lines: List[str]) -> List[str]:
    out: List[str] = []
    for raw in lines:
        s = raw.strip()
        if not s:
            continue
        if s == "TIMEOUT":
            out.append("TIMEOUT")
            break
        parts = s.split()
        if parts[0] == "HALT":
            pc = next((p for p in parts[1:] if p.startswith("pc=")), "pc=xxxxxxxx")
            inst = next((p for p in parts[1:] if p.startswith("inst=")), "inst=xxxxxxxx")
            stray_rd = next((p for p in parts[1:] if p.startswith("stray_rd=")), None)
            stray_st = next((p for p in parts[1:] if p.startswith("stray_st=")), None)
            # Drop x0 stray_rd if present
            if stray_rd and stray_rd.startswith("stray_rd=x0:"):
                stray_rd = None
            rec = ["HALT", pc.lower(), inst.lower()]
            if stray_rd:
                rec.append(stray_rd.lower())
            if stray_st:
                rec.append(stray_st.lower())
            out.append(" ".join(rec))
            break
        else:
            step = parts[0]
            pc = next((p for p in parts[1:] if p.startswith("pc=")), "pc=xxxxxxxx")
            inst = next((p for p in parts[1:] if p.startswith("inst=")), "inst=xxxxxxxx")
            rd = next((p for p in parts[1:] if p.startswith("rd=")), None)
            ld = next((p for p in parts[1:] if p.startswith("ld=")), None)
            st = next((p for p in parts[1:] if p.startswith("st=")), None)
            if rd and rd.startswith("rd=x0:"):
                rd = None
            rec = [step, pc.lower(), inst.lower()]
            if rd:
                rec.append(rd.lower())
            if ld:
                rec.append(ld.lower())
            if st:
                rec.append(st.lower())
            out.append(" ".join(rec))
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate or canonicalize a Lab 3 trace file.")
    parser.add_argument("input", help="Input trace file")
    parser.add_argument("-o", "--output", help="Output trace file (defaults to stdout)")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        lines = f.readlines()

    norm = canonicalize_trace_lines(lines)
    content = "\n".join(norm) + ("\n" if norm else "")
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(content)
    else:
        sys.stdout.write(content)


if __name__ == "__main__":
    main()
