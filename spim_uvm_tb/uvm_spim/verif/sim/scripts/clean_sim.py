#!/usr/bin/env python3
"""Safely list or remove generated simulation artifacts in this directory."""

from __future__ import print_function

import argparse
import shutil
import sys
from pathlib import Path


SIM_DIR = Path(__file__).resolve().parents[1]

# Each pattern is constrained to SIM_DIR.  Do not use a broad recursive glob.
ARTIFACTS = {
    "build": [
        "csrc", "simv", "simv.daidir", "simv.*", "vc_hdrs.h", "ucli.key",
        "DVEfiles", "comp.log", "*.log", "*.vpd", "*.vcd", "*.fsdb", "*.vdb",
    ],
    "logs": ["logs", "urgReport"],
    "verdi": ["verdiLog", "vdCovLog", "vfastLog", "novas.conf", "novas.rc"],
    "python": ["scripts/__pycache__"],
}


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="List or delete generated VCS/Verdi/Python artifacts under sim/."
    )
    parser.add_argument(
        "--scope",
        choices=["all", "build", "logs", "verdi", "python"],
        default="all",
        help="Artifact category to clean (default: all).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually delete files. Without this option, only print the plan.",
    )
    return parser.parse_args()


def targets_for(scope):
    categories = ARTIFACTS if scope == "all" else {scope: ARTIFACTS[scope]}
    targets = []
    for patterns in categories.values():
        for pattern in patterns:
            targets.extend(path for path in SIM_DIR.glob(pattern) if path.exists())
    return sorted(set(targets), key=lambda path: str(path))


def remove_target(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(str(path))
    else:
        path.unlink()


def main():
    args = parse_arguments()
    targets = targets_for(args.scope)
    action = "Delete" if args.apply else "Would delete"
    if not targets:
        print("No generated artifacts found for scope '{}'.".format(args.scope))
        return 0

    for path in targets:
        print("{} {}".format(action, path.relative_to(SIM_DIR)))

    if not args.apply:
        print("Dry run only. Re-run with --apply to delete these generated artifacts.")
        return 0

    for path in targets:
        remove_target(path)
    print("Removed {} generated artifact(s).".format(len(targets)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
