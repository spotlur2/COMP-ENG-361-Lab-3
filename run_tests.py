#!/usr/bin/env python3
"""
Student One-Command Test Runner for CompEng 361 Lab 3 (run_tests.py)

Usage:
    python3 run_tests.py <your_group_lab3.v>
    python3 run_tests.py <your_group_lab3.v> --tier A
    python3 run_tests.py <your_group_lab3.v> --test add

Compiles your SingleCycleCPU with lab3_tb.v, runs the public test suite,
compares each trace against the golden reference trace, and reports
Milestone A and Milestone B results with first-divergence diagnostics.
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, List

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.join(SCRIPT_DIR, "tools") if os.path.isdir(os.path.join(SCRIPT_DIR, "tools")) else SCRIPT_DIR
LAB3_DIR = SCRIPT_DIR if os.path.isdir(os.path.join(SCRIPT_DIR, "tests")) else os.path.dirname(SCRIPT_DIR)

if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from tracediff import compare_traces


def parse_manifest(manifest_path: str) -> List[Dict[str, str]]:
    entries: List[Dict[str, str]] = []
    with open(manifest_path, "r", encoding="utf-8") as f:
        for line_no, raw in enumerate(f, start=1):
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) < 3:
                raise ValueError(f"{manifest_path}:{line_no}: expected at least 3 columns, got: {raw!r}")
            name, tier, expected_end = parts[0], parts[1], parts[2]
            visibility = parts[3] if len(parts) >= 4 else "public"
            entries.append(
                {
                    "name": name,
                    "tier": tier,
                    "expected_end": expected_end,
                    "visibility": visibility,
                }
            )
    return entries


def check_structural_rules(verilog_path: str) -> List[str]:
    try:
        with open(verilog_path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except OSError as e:
        return [f"read_error:{e}"]

    code = re.sub(r"/\*.*?\*/", "", raw, flags=re.DOTALL)
    code = re.sub(r"//[^\n]*", "", code)
    flags: List[str] = []

    if re.search(r"`include\b", code):
        flags.append("uses `include directive")
    if re.search(r"\b(always|always_comb|always_ff|always_latch)\b", code):
        flags.append("contains 'always' block")
    if re.search(r"\binitial\b", code):
        flags.append("contains 'initial' block")
    if re.search(r"\breg\b", code):
        flags.append("declares 'reg' type")
    if re.search(r"\bif\s*\(", code):
        flags.append("contains procedural 'if'")
    if re.search(r"\b(case|casez|casex)\s*\(", code):
        flags.append("contains procedural 'case'")

    return flags


def run_suite(
    verilog_path: str,
    manifest_entries: List[Dict[str, str]],
    tb_path: str,
    build_dir: str,
    golden_dir: str,
    regs_in_path: str,
    wall_timeout: float = 5.0,
    max_cycles: int = 100000,
    half_period: int = 5,
) -> Dict[str, Any]:
    rule_flags = check_structural_rules(verilog_path)

    with tempfile.TemporaryDirectory() as tmpdir:
        dut_copy = os.path.join(tmpdir, "submission_dut.v")
        shutil.copyfile(verilog_path, dut_copy)
        sim_bin = os.path.join(tmpdir, "sim_cpu")

        iverilog_cmd = [
            "iverilog",
            f"-Ptb.HALF_PERIOD={half_period}",
            f"-Ptb.MAX_CYCLES={max_cycles}",
            "-o",
            sim_bin,
            dut_copy,
            tb_path,
        ]
        comp = subprocess.run(
            iverilog_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        if comp.returncode != 0:
            total_a = sum(1 for e in manifest_entries if e["tier"] == "A")
            total_b = sum(1 for e in manifest_entries if e["tier"] == "B")
            total_all = len(manifest_entries)
            return {
                "file": verilog_path,
                "compiled": False,
                "compile_error": comp.stderr.strip() or comp.stdout.strip(),
                "rule_flags": rule_flags,
                "results": [],
                "summary": {
                    "tier_a_passed": 0,
                    "tier_a_total": total_a,
                    "tier_a_pct": 0.0,
                    "tier_b_passed": 0,
                    "tier_b_total": total_b,
                    "tier_b_pct": 0.0,
                    "cumulative_passed": 0,
                    "cumulative_total": total_all,
                    "cumulative_pct": 0.0,
                },
            }

        results: List[Dict[str, Any]] = []
        for entry in manifest_entries:
            tname = entry["name"]
            tier = entry["tier"]
            vis = entry["visibility"]
            hex_path = os.path.join(build_dir, f"{tname}.hex")
            golden_path = os.path.join(golden_dir, f"{tname}.trace")
            trace_out = os.path.join(tmpdir, f"{tname}_trace.txt")
            regs_out = os.path.join(tmpdir, f"{tname}_regs.hex")
            mem_out = os.path.join(tmpdir, f"{tname}_mem.hex")

            sim_cmd = [
                sim_bin,
                f"+MEM_IN={hex_path}",
                f"+REGS_IN={regs_in_path}",
                f"+TRACE_OUT={trace_out}",
                f"+REGS_OUT={regs_out}",
                f"+MEM_OUT={mem_out}",
                f"+MAX_CYCLES={max_cycles}",
                "+NO_VCD=1",
            ]
            try:
                sim = subprocess.run(
                    sim_cmd,
                    cwd=tmpdir,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True,
                    timeout=wall_timeout,
                )
                if sim.returncode != 0:
                    err_detail = sim.stderr.strip() or sim.stdout.strip()
                    passed = False
                    msg = f"Simulator exited with non-zero code ({sim.returncode}): {err_detail}"
                else:
                    passed, msg = compare_traces(trace_out, golden_path)
            except subprocess.TimeoutExpired:
                passed = False
                msg = f"Simulation hung (exceeded {wall_timeout:.1f}s wall-clock timeout)"
            except Exception as e:
                passed = False
                msg = f"Simulation crash: {e}"

            results.append(
                {
                    "name": tname,
                    "tier": tier,
                    "visibility": vis,
                    "passed": passed,
                    "message": msg,
                }
            )

    tier_a_res = [r for r in results if r["tier"] == "A"]
    tier_b_res = [r for r in results if r["tier"] == "B"]

    a_pass = sum(1 for r in tier_a_res if r["passed"])
    a_tot = len(tier_a_res)
    b_pass = sum(1 for r in tier_b_res if r["passed"])
    b_tot = len(tier_b_res)
    all_pass = a_pass + b_pass
    all_tot = a_tot + b_tot

    summary = {
        "tier_a_passed": a_pass,
        "tier_a_total": a_tot,
        "tier_a_pct": round((a_pass / a_tot * 100.0) if a_tot else 0.0, 2),
        "tier_b_passed": b_pass,
        "tier_b_total": b_tot,
        "tier_b_pct": round((b_pass / b_tot * 100.0) if b_tot else 0.0, 2),
        "cumulative_passed": all_pass,
        "cumulative_total": all_tot,
        "cumulative_pct": round((all_pass / all_tot * 100.0) if all_tot else 0.0, 2),
    }

    return {
        "file": verilog_path,
        "compiled": True,
        "compile_error": None,
        "rule_flags": rule_flags,
        "results": results,
        "summary": summary,
    }


def format_report(report: Dict[str, Any]) -> str:
    lines: List[str] = []
    lines.append("=" * 72)
    lines.append(f"Submission: {report['file']}")
    if report["rule_flags"]:
        lines.append(f"Rule Check: WARNING - {', '.join(report['rule_flags'])} (flagged for review)")
    else:
        lines.append("Rule Check: OK (pure structural Verilog)")
    lines.append("=" * 72)

    if not report["compiled"]:
        lines.append("[COMPILE FAIL] iverilog failed to compile submission:")
        lines.append(report["compile_error"] or "Unknown compilation error")
        return "\n".join(lines)

    for tier_label, tier_title in [
        ("A", "Milestone A Tests (ALU, Loads/Stores, Branches, A-Tier Halts)"),
        ("B", "Milestone B Tests (LUI/AUIPC, Jumps, Fetch-Align Halts, C Programs)"),
    ]:
        t_res = [r for r in report["results"] if r["tier"] == tier_label]
        if not t_res:
            continue
        lines.append(f"\n--- {tier_title} ---")
        for r in t_res:
            status = "PASS" if r["passed"] else "FAIL"
            if r["passed"]:
                lines.append(f"  [{status}] {r['name']:24s} : {r['message']}")
            else:
                lines.append(f"  [{status}] {r['name']:24s}")
                for mline in r["message"].splitlines():
                    lines.append(f"         {mline}")

    s = report["summary"]
    lines.append("\n" + "-" * 72)
    lines.append(
        f"Milestone A Score:             {s['tier_a_passed']:2d} / {s['tier_a_total']:2d} "
        f"({s['tier_a_pct']:.1f}%)"
    )
    lines.append(
        f"Milestone B New Tests Score:   {s['tier_b_passed']:2d} / {s['tier_b_total']:2d} "
        f"({s['tier_b_pct']:.1f}%)"
    )
    lines.append(
        f"Milestone B Cumulative (A+B):  {s['cumulative_passed']:2d} / {s['cumulative_total']:2d} "
        f"({s['cumulative_pct']:.1f}%)"
    )
    lines.append("-" * 72)
    return "\n".join(lines)


def autodetect_cpu_file() -> str:
    candidates = sorted(glob.glob(os.path.join(LAB3_DIR, "*_lab3.v")))
    custom = [
        c
        for c in candidates
        if os.path.basename(c) not in ("template_lab3.v", "solution_lab3.v", "basic_lab3.v")
    ]
    if len(custom) == 1:
        return custom[0]
    default_tpl = os.path.join(LAB3_DIR, "template_lab3.v")
    if os.path.exists(default_tpl):
        return default_tpl
    if candidates:
        return candidates[0]
    return "template_lab3.v"


def check_iverilog() -> None:
    iv_path = shutil.which("iverilog")
    if not iv_path:
        print(
            "ERROR: 'iverilog' not found in PATH.\n"
            "On EECS/Wilkinson machines, make sure '/vol/eecs362/iverilog-new/bin' is in your PATH:\n"
            "  bash: export PATH=/vol/eecs362/iverilog-new/bin:$PATH\n"
            "  tcsh: set path = (/vol/eecs362/iverilog-new/bin $path)",
            file=sys.stderr,
        )
        sys.exit(1)

    real_iv = os.path.realpath(iv_path)
    ver_res = subprocess.run(
        [iv_path, "-V"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    first_line = (ver_res.stdout or ver_res.stderr or "").splitlines()
    ver_str = first_line[0].strip() if first_line else "unknown version"
    m_ver = re.search(r"version\s+(\d+)\.(\d+)", ver_str)
    major = int(m_ver.group(1)) if m_ver else 0

    if major < 10 or "/iverilog-old/" in real_iv or real_iv.startswith("/vol/eecs362/iverilog/"):
        print(
            f"ERROR: Outdated or broken Icarus Verilog detected: {iv_path} ({ver_str}).\n"
            "Please use '/vol/eecs362/iverilog-new/bin' (version 11.0+) instead of '/vol/eecs362/iverilog/bin':\n"
            "  bash: export PATH=/vol/eecs362/iverilog-new/bin:$PATH\n"
            "  tcsh: set path = (/vol/eecs362/iverilog-new/bin $path)",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compile and run your Lab 3 SingleCycleCPU against the golden trace test suite."
    )
    parser.add_argument(
        "cpu_file",
        nargs="?",
        default=None,
        help="Path to your Verilog file (e.g., group1_lab3.v; defaults to auto-detected *_lab3.v)",
    )
    parser.add_argument(
        "--tier",
        choices=["A", "B", "all"],
        default="all",
        help="Run only Milestone A tests (--tier A) or all Milestone A & B tests (default: all)",
    )
    parser.add_argument(
        "--test",
        help="Run a single named test (e.g., --test add) and write trace.txt to the current directory",
    )
    parser.add_argument(
        "--keep",
        action="store_true",
        help="When running with --test, keep trace.txt and single.vcd in the current directory",
    )
    args = parser.parse_args()

    check_iverilog()

    cpu_file = args.cpu_file or autodetect_cpu_file()
    if not os.path.exists(cpu_file):
        print(f"ERROR: Verilog file '{cpu_file}' not found.", file=sys.stderr)
        print("Usage: python3 run_tests.py <your_group_lab3.v>", file=sys.stderr)
        sys.exit(1)

    manifest_path = os.path.join(LAB3_DIR, "tests", "manifest")
    tb_path = os.path.join(LAB3_DIR, "lab3_tb.v")
    build_dir = os.path.join(LAB3_DIR, "tests", "build")
    golden_dir = os.path.join(LAB3_DIR, "tests", "golden")
    regs_in_path = os.path.join(LAB3_DIR, "regs_in.hex")

    entries = [e for e in parse_manifest(manifest_path) if e["visibility"] == "public"]

    if args.test:
        matched = [e for e in entries if e["name"] == args.test]
        if not matched:
            print(f"ERROR: Unknown test '{args.test}'. Available tests:", file=sys.stderr)
            print("  " + ", ".join(e["name"] for e in entries), file=sys.stderr)
            sys.exit(1)
        entries = matched
    elif args.tier == "A":
        entries = [e for e in entries if e["tier"] == "A"]

    report = run_suite(
        cpu_file,
        entries,
        tb_path,
        build_dir,
        golden_dir,
        regs_in_path,
    )

    if args.test and report["compiled"]:
        tname = args.test
        hex_path = os.path.join(build_dir, f"{tname}.hex")
        golden_path = os.path.join(golden_dir, f"{tname}.trace")
        sim_bin = os.path.join(LAB3_DIR, "single_test_sim")
        comp = subprocess.run(
            ["iverilog", "-o", sim_bin, cpu_file, tb_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        if comp.returncode == 0:
            try:
                subprocess.run(
                    [
                        sim_bin,
                        f"+MEM_IN={hex_path}",
                        f"+REGS_IN={regs_in_path}",
                        "+TRACE_OUT=trace.txt",
                    ],
                    timeout=5.0,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
            finally:
                if os.path.exists(sim_bin):
                    os.remove(sim_bin)
        print(format_report(report))
        print(f"\nWrote 'trace.txt' and 'single.vcd' for test '{tname}'.")
        print(f"To inspect the diff directly:\n  python3 tracediff.py trace.txt {golden_path}")
    else:
        print(format_report(report))

    s = report.get("summary", {})
    if args.tier == "A":
        ok = report["compiled"] and (s.get("tier_a_passed") == s.get("tier_a_total"))
    else:
        ok = report["compiled"] and (s.get("cumulative_passed") == s.get("cumulative_total"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
