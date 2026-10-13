#!/usr/bin/env python3
"""Compile once, run a UVM test/seed matrix, then create a regression report."""

import argparse
import subprocess
import sys
from pathlib import Path

from common import command_text, parse_seeds


DEFAULT_TESTS = (
    "sramc_test",
    "sramc_testcase_test",
    "sramc_burst_test",
    "sramc_boundary_test",
    "sramc_legal_random_test",
    "sramc_reset_recovery_test",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests", default=",".join(DEFAULT_TESTS),
                        help="comma-separated UVM test names")
    parser.add_argument("--seeds", default="1-3", help="for example: 1-3,11")
    parser.add_argument("--run-args", default="", help="extra simv plusargs")
    parser.add_argument("--results-dir", default="results", help="result root")
    parser.add_argument("--no-compile", action="store_true", help="reuse existing simv")
    parser.add_argument("--dry-run", action="store_true", help="print all commands only")
    args = parser.parse_args()
    tests = [item for item in args.tests.replace(",", " ").split() if item]
    if not tests:
        parser.error("at least one test is required")
    try:
        seeds = parse_seeds(args.seeds)
    except ValueError as error:
        parser.error(str(error))

    sim_dir = Path(__file__).resolve().parents[1]
    if not args.no_compile:
        compile_command = ["make", "comp"]
        print("[COMPILE] {}".format(command_text(compile_command)))
        if not args.dry_run:
            completed = subprocess.run(compile_command, cwd=sim_dir, check=False)
            if completed.returncode:
                return completed.returncode

    overall_status = 0
    run_script = sim_dir / "scripts" / "run.py"
    for test in tests:
        for seed in seeds:
            command = [sys.executable, str(run_script), "--test", test,
                       "--seed", str(seed), "--results-dir", args.results_dir]
            if args.run_args:
                command.extend(["--run-args", args.run_args])
            if args.dry_run:
                command.append("--dry-run")
            if args.dry_run:
                print("[MATRIX] {}".format(command_text(command)))
            else:
                completed = subprocess.run(command, cwd=sim_dir, check=False)
                overall_status |= completed.returncode != 0

    if args.dry_run:
        return 0
    collect_command = [sys.executable, str(sim_dir / "scripts" / "collect_results.py"),
                       "--results-dir", args.results_dir]
    completed = subprocess.run(collect_command, cwd=sim_dir, check=False)
    return 1 if overall_status or completed.returncode else 0


if __name__ == "__main__":
    raise SystemExit(main())
