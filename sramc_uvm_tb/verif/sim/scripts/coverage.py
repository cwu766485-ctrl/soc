#!/usr/bin/env python3
"""Create an URG text report from VDBs produced under the standard results/."""

import argparse
import subprocess
from pathlib import Path

from common import command_text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", default="urgReport", help="URG text report directory")
    parser.add_argument("--dry-run", action="store_true", help="print command without running")
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parents[1]
    results_dir = sim_dir / "results"
    vdbs = list(results_dir.glob("*/seed*/*.vdb"))
    if not vdbs:
        print("[FAIL] no VDB found under {}".format(results_dir))
        return 2
    command = ["make", "cov_txt", "COV_REPORT_DIR={}".format(args.report_dir)]
    print("[COVERAGE] {}".format(command_text(command)))
    if args.dry_run:
        return 0
    return subprocess.run(command, cwd=sim_dir, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
