#!/usr/bin/env python3
"""Summarize existing UVM logs without recompiling or rerunning a testcase."""

from __future__ import print_function

import argparse
import json
import re
import sys
from pathlib import Path


SIM_DIR = Path(__file__).resolve().parents[1]
LOG_ROOT = SIM_DIR / "logs"


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Read existing UVM logs and print a testcase pass/fail table."
    )
    parser.add_argument(
        "--tests",
        help="Comma-separated testcase names. Default: every logs/<test>/<test>.log.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON instead of a Markdown table.",
    )
    parser.add_argument(
        "--fail-only",
        action="store_true",
        help="Show only cases with errors, fatals, or no UVM summary.",
    )
    return parser.parse_args()


def read_count(text, severity):
    match = re.search(r"UVM_{}\s*:\s*(\d+)".format(severity), text)
    return int(match.group(1)) if match else None


def collect_logs(requested_tests):
    if requested_tests:
        names = [name.strip() for name in requested_tests.split(",") if name.strip()]
        return [(name, LOG_ROOT / name / "{}.log".format(name)) for name in names]

    logs = []
    if LOG_ROOT.exists():
        for path in sorted(LOG_ROOT.glob("*/*.log")):
            # regression console logs are summarized separately by run_regression.py.
            if path.parent.parent.name != "regression":
                logs.append((path.stem, path))
    return logs


def summarize(test_name, path):
    if not path.exists():
        return {"test": test_name, "status": "NO_LOG", "errors": None, "fatals": None,
                "log": str(path.relative_to(SIM_DIR))}
    text = path.read_text(errors="replace")
    errors = read_count(text, "ERROR")
    fatals = read_count(text, "FATAL")
    if errors is None or fatals is None:
        status = "INCONCLUSIVE"
    elif errors == 0 and fatals == 0:
        status = "PASS"
    else:
        status = "FAIL"
    return {"test": test_name, "status": status, "errors": errors, "fatals": fatals,
            "log": str(path.relative_to(SIM_DIR))}


def main():
    args = parse_arguments()
    results = [summarize(name, path) for name, path in collect_logs(args.tests)]
    if args.fail_only:
        results = [item for item in results if item["status"] != "PASS"]

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print("| Testcase | Status | UVM_ERROR | UVM_FATAL | UVM log |")
        print("|---|---|---:|---:|---|")
        for item in results:
            print("| `{test}` | {status} | {errors} | {fatals} | `{log}` |".format(**item))
        if not results:
            print("| - | No matching logs | - | - | - |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
