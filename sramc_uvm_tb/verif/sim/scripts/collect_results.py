#!/usr/bin/env python3
"""Classify logs under a result root and create Markdown/JSON regression reports."""

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from common import classify_log, resolve_results_dir


def load_result(result_file):
    """Load the metadata produced by scripts/run.py."""
    return json.loads(result_file.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results-dir", default="results", help="result root")
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parents[1]
    results_root = resolve_results_dir(sim_dir, args.results_dir)
    result_files = sorted(results_root.glob("*/seed*/result.json"))
    if not result_files:
        print("[FAIL] no result.json files under {}".format(results_root))
        return 2
    results = [load_result(result_file) for result_file in result_files]
    results.sort(key=lambda item: (item["test"], item["seed"]))
    passed = sum(item["status"] == "PASS" for item in results)
    payload = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "passed": passed,
        "failed": len(results) - passed,
        "results": results,
    }
    (results_root / "summary.json").write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8"
    )
    lines = [
        "# Regression Summary", "",
        "- PASS: {}".format(passed),
        "- FAIL: {}".format(len(results) - passed), "",
        "| Test | Seed | Status | Log | Reason |",
        "|---|---:|---|---|---|",
    ]
    for item in results:
        reason = "; ".join(item["reasons"]) if item["reasons"] else "-"
        lines.append("| {} | {} | {} | {} | {} |".format(
            item["test"], item["seed"], item["status"], item["log"], reason
        ))
    (results_root / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("[SUMMARY] PASS={} FAIL={} report={}".format(
        passed, len(results) - passed, results_root / "summary.md"
    ))
    return 1 if passed != len(results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
