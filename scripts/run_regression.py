"""Questa regression: compile once, time-bound runs, strict PASS and JSON report.

Uses only the Python standard library. Run from any directory; RTL stays in place.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
TB = ROOT / "model_tb"
MODULES = (
    "alu", "branch_unit", "forward_unit", "imm_gen", "wb_stage",
    "hazard_unit", "regfile", "if_stage", "csr_file",
    "lsu", "decoder", "id_stage", "ex_stage", "mem_stage", "rv32_core", "top",
)
BENCHES = {m: "tb_" + ("top_module" if m == "top" else m) for m in MODULES}


def verdict(output: str, bench: str, returncode: int) -> tuple[bool, str]:
    """Never accept a PASS string in a command echo or after an HDL error."""
    if returncode:
        return False, f"process exit {returncode}"
    if re.search(r"(?im)^\s*#?\s*\*\*\s*(Fatal|Error)\b|\[FAIL\]|\bErrors:\s*[1-9]\d*", output):
        return False, "simulator/testbench reported an error"
    if bench == "tb_top":
        marker = r"\[PASS\] tb_top completed with no errors\."
    else:
        marker = re.escape("PASS " + bench) + r"\s+\d+\s+checks?"
    if not re.search(r"(?m)^\s*#?\s*" + marker + r"\s*$", output):
        return False, "completion marker missing (failure, stop or watchdog)"
    return True, "passed"


def run_process(command: list[str], cwd: Path, timeout: float) -> tuple[int, str]:
    """Capture both streams and terminate the simulator tree on a wall timeout."""
    proc = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    try:
        raw, _ = proc.communicate(timeout=timeout)
        return proc.returncode, raw.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=10, check=False)
        proc.kill()
        raw, _ = proc.communicate()
        return 124, raw.decode("utf-8", errors="replace") + "\nTIMEOUT\n"


def check_manifest() -> None:
    """Fail if an active RTL module loses its own direct-instantiation bench."""
    active = set()
    for line in (TB / "filelist.f").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("../rtl/"):
            continue
        source = (TB / line).read_text(encoding="utf-8")
        source = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)
        active.update(re.findall(r"\bmodule\s+(\w+)", source))
    if active != set(MODULES):
        raise ValueError(f"bench manifest differs from RTL: missing={active-set(MODULES)}, stale={set(MODULES)-active}")
    for module, bench in BENCHES.items():
        source = (TB / "unit" / (bench + ".sv")).read_text(encoding="utf-8")
        if not re.search(r"\b" + re.escape(module) + r"\s+dut\s*\(", source):
            raise ValueError(f"{bench} does not directly instantiate {module}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("unit", "system", "all"), default="all")
    parser.add_argument("--bench", choices=tuple(BENCHES.values()) + ("tb_top",))
    parser.add_argument("--timeout", type=float, default=60, help="wall seconds per tool process")
    for tool in ("vlib", "vlog", "vsim"):
        parser.add_argument("--" + tool, default=os.getenv(tool.upper(), tool))
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    results = TB / "results"
    results.mkdir(exist_ok=True)
    report = {"suite": args.suite, "bench": args.bench, "passed": False, "tests": []}
    started = time.monotonic()
    try:
        check_manifest()
        selected = ([args.bench] if args.bench else
                    (list(BENCHES.values()) if args.suite != "system" else []) +
                    (["tb_top"] if args.suite != "unit" else []))
        resolved = {}
        for name in ("vlib", "vlog", "vsim"):
            candidate = getattr(args, name)
            resolved[name] = shutil.which(candidate)
            if not resolved[name]:
                raise FileNotFoundError(f"{name} unavailable: add Questa bin to PATH or pass --{name} <path>")
        library = TB / "work"
        commands = []
        if not (library / "_info").exists():
            commands.append(("vlib", [resolved["vlib"], "work"]))
        includes = ["+incdir+../rtl/core" + suffix for suffix in
                    ("", "/if_stage", "/id_stage", "/ex_stage", "/mem_stage", "/wb_stage")]
        commands.append(("compile", [resolved["vlog"], "-sv", "-work", "work", *includes,
                                     "-f", "filelist.f", *["unit/" + b + ".sv" for b in selected if b != "tb_top"]]))
        for phase, command in commands:
            rc, output = run_process(command, TB, args.timeout)
            (results / (phase + ".log")).write_text(output, encoding="utf-8")
            if rc or re.search(r"\*\*\s*(Error|Fatal)\b|\bErrors:\s*[1-9]\d*", output):
                raise RuntimeError(f"{phase} failed; see results/{phase}.log")
        print(f"Compiled RTL and {len(selected)} benches", flush=True)
        for bench in selected:
            t = time.monotonic()
            rc, output = run_process([resolved["vsim"], "-c", "-voptargs=+acc", "work." + bench,
                "-do", "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], TB, args.timeout)
            log = results / (bench + ".log")
            log.write_text(output, encoding="utf-8")
            ok, reason = verdict(output, bench, rc)
            item = {"bench": bench, "passed": ok, "reason": reason,
                    "seconds": round(time.monotonic()-t, 3), "log": log.name}
            count = re.search(r"(?m)^\s*#?\s*PASS " + re.escape(bench) + r"\s+(\d+)\s+checks?\s*$", output)
            if ok and count:
                item["checks"] = int(count.group(1))
            report["tests"].append(item)
            print(f"[{'PASS' if ok else 'FAIL'}] {bench}: {reason}", flush=True)
        report["passed"] = all(test["passed"] for test in report["tests"])
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        report["error"] = str(exc)
        print(f"[FAIL] {exc}", file=sys.stderr, flush=True)
    report["seconds"] = round(time.monotonic()-started, 3)
    report["unit_checks"] = sum(test.get("checks", 0) for test in report["tests"])
    (results / "summary.json").write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    print(f"Report: {results / 'summary.json'}", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
