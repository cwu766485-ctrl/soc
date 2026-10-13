#!/usr/bin/env python3
"""Run one compiled UVM test/seed and write its log and VDB under results/."""

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path

from common import classify_log, command_text, resolve_results_dir


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test", required=True, help="UVM_TESTNAME")
    parser.add_argument("--seed", required=True, type=int, help="ntb random seed")
    parser.add_argument("--run-args", default="", help="extra simv plusargs")
    parser.add_argument("--results-dir", default="results", help="result root")
    parser.add_argument("--dry-run", action="store_true", help="print without running")
    args = parser.parse_args()
    if args.seed < 0:
        parser.error("seed must be non-negative")

    sim_dir = Path(__file__).resolve().parents[1]
    results_root = resolve_results_dir(sim_dir, args.results_dir)
    result_dir = results_root / args.test / "seed{}".format(args.seed)
    log_path = result_dir / "{}_seed{}.log".format(args.test, args.seed)
    vdb_path = result_dir / "{}_seed{}.vdb".format(args.test, args.seed)
    command = [
        "./simv",
        "+UVM_TESTNAME={}".format(args.test),
        "+UVM_VERBOSITY=UVM_MEDIUM",
        "+ntb_random_seed={}".format(args.seed),
        *shlex.split(args.run_args),
        "-cm", "line+cond+tgl+branch+assert",
        "-cm_dir", str(vdb_path.relative_to(sim_dir)),
        "-cm_name", "{}_seed{}".format(args.test, args.seed),
        "-l", str(log_path.relative_to(sim_dir)),
    ]
    print("[RUN] {}".format(command_text(command)))
    if args.dry_run:
        return 0
    if not (sim_dir / "simv").is_file():
        print("[FAIL] simv does not exist; run make comp first", file=sys.stderr)
        return 2

    result_dir.mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(command, cwd=sim_dir, check=False)
    reasons = classify_log(log_path, completed.returncode)
    status = "FAIL" if reasons else "PASS"
    result = {
        "test": args.test,
        "seed": args.seed,
        "status": status,
        "return_code": completed.returncode,
        "log": str(log_path.relative_to(sim_dir)),
        "vdb": str(vdb_path.relative_to(sim_dir)),
        "reasons": reasons,
    }
    (result_dir / "result.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    print("[{}] test={} seed={}".format(status, args.test, args.seed))
    return 1 if reasons else 0


if __name__ == "__main__":
    raise SystemExit(main())
