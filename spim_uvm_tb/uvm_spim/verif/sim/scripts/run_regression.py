#!/usr/bin/env python3
"""Run SPI UVM tests serially and create a compact regression report."""

from __future__ import print_function

import argparse
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path


SIM_DIR = Path(__file__).resolve().parents[1]
LOG_ROOT = SIM_DIR / "logs" / "regression"

SUITES = {
    "smoke": [
        "spi_poll_test",
        "spi_interrupt_test",
        "spi_interrupt_mask_test",
        "spi_shift_mode_test",
    ],
    "coverage": [
        "spi_transfer_cov_test",
        "spi_shift_mode_test",
        "spi_busy_write_cov_test",
        "spi_interrupt_test",
        "spi_interrupt_mask_test",
        "spi_poll_test",
        "spi_mid_reset_test",
    ],
    "all": [
        "spi_reg_test",
        "spi_poll_test",
        "spi_interrupt_test",
        "spi_interrupt_mask_test",
        "spi_mid_reset_test",
        "spi_shift_mode_test",
        "spi_transfer_cov_test",
        "spi_busy_write_cov_test",
    ],
}


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Serial regression wrapper for the SPI UVM Makefile."
    )
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument(
        "--suite",
        choices=sorted(SUITES),
        default="smoke",
        help="Predefined testcase suite (default: smoke).",
    )
    selection.add_argument(
        "--tests",
        help="Comma-separated testcase names, for example spi_poll_test,spi_interrupt_test.",
    )
    parser.add_argument("--seed", type=int, default=1, help="VCS random seed (default: 1).")
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="Continue with later tests after a failure.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print selected tests and Make commands without running simulation.",
    )
    return parser.parse_args()


def choose_tests(args):
    if not args.tests:
        return SUITES[args.suite]

    tests = [name.strip() for name in args.tests.split(",") if name.strip()]
    if not tests:
        raise ValueError("--tests must contain at least one testcase name")
    return tests


def read_uvm_count(text, severity):
    match = re.search(r"UVM_{}\s*:\s*(\d+)".format(severity), text)
    return int(match.group(1)) if match else None


def evaluate_result(return_code, text):
    errors = read_uvm_count(text, "ERROR")
    fatals = read_uvm_count(text, "FATAL")

    # A licence outage is an infrastructure problem, not a DUT testcase fail.
    if "Cannot connect to the license server" in text or "Failed to obtain license" in text:
        return "INFRA_LICENSE", errors, fatals
    if return_code != 0:
        return "FAIL", errors, fatals
    if errors is None or fatals is None:
        return "INCONCLUSIVE", errors, fatals
    if errors != 0 or fatals != 0:
        return "FAIL", errors, fatals
    return "PASS", errors, fatals


def run_test(test_name, seed, run_dir, dry_run):
    command = ["make", "all", "TEST={}".format(test_name), "SEED={}".format(seed)]
    printable = " ".join(command)
    if dry_run:
        return {
            "test": test_name,
            "status": "DRY_RUN",
            "return_code": None,
            "uvm_errors": None,
            "uvm_fatals": None,
            "console_log": None,
            "command": printable,
        }

    completed = subprocess.run(
        command,
        cwd=str(SIM_DIR),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    console_log = run_dir / "{}.console.log".format(test_name)
    console_log.write_text(completed.stdout)

    uvm_log = SIM_DIR / "logs" / test_name / "{}.log".format(test_name)
    uvm_text = uvm_log.read_text(errors="replace") if uvm_log.exists() else ""
    status, errors, fatals = evaluate_result(completed.returncode, completed.stdout + uvm_text)
    return {
        "test": test_name,
        "status": status,
        "return_code": completed.returncode,
        "uvm_errors": errors,
        "uvm_fatals": fatals,
        "console_log": str(console_log.relative_to(SIM_DIR)),
        "uvm_log": str(uvm_log.relative_to(SIM_DIR)) if uvm_log.exists() else None,
        "waveform": "logs/{0}/{0}.vpd".format(test_name),
        "command": printable,
    }


def write_reports(run_dir, seed, results):
    report = {
        "seed": seed,
        "generated_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "results": results,
    }
    (run_dir / "summary.json").write_text(json.dumps(report, indent=2) + "\n")

    lines = [
        "# SPI UVM Regression Report",
        "",
        "- Seed: `{}`".format(seed),
        "- Generated: `{}`".format(report["generated_at"]),
        "",
        "| Testcase | Status | UVM_ERROR | UVM_FATAL | Return code |",
        "|---|---|---:|---:|---:|",
    ]
    for result in results:
        lines.append(
            "| `{test}` | {status} | {uvm_errors} | {uvm_fatals} | {return_code} |".format(
                **result
            )
        )
    lines.extend(["", "## Logs", ""])
    for result in results:
        if result.get("console_log"):
            lines.append("- `{}`: `{}`".format(result["test"], result["console_log"]))
    (run_dir / "summary.md").write_text("\n".join(lines) + "\n")


def main():
    args = parse_arguments()
    try:
        tests = choose_tests(args)
    except ValueError as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        return 2

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = LOG_ROOT / timestamp
    if not args.dry_run:
        run_dir.mkdir(parents=True, exist_ok=False)

    print("SPI UVM regression")
    print("  seed : {}".format(args.seed))
    print("  tests: {}".format(", ".join(tests)))
    if args.dry_run:
        print("  mode : dry-run")

    results = []
    for index, test_name in enumerate(tests, start=1):
        print("[{}/{}] {}".format(index, len(tests), test_name))
        result = run_test(test_name, args.seed, run_dir, args.dry_run)
        results.append(result)
        print("  -> {}".format(result["status"]))
        if result["status"] in ("FAIL", "INCONCLUSIVE", "INFRA_LICENSE") and not args.keep_going:
            print("Stopping after {}. Use --keep-going to run remaining tests.".format(result["status"]))
            break

    if args.dry_run:
        for result in results:
            print("  {}".format(result["command"]))
        return 0

    write_reports(run_dir, args.seed, results)
    print("Report: {}".format(run_dir / "summary.md"))
    return 0 if all(item["status"] == "PASS" for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
