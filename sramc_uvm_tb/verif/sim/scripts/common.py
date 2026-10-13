"""Shared, dependency-free helpers for simulation management scripts."""

import re
import shlex
from pathlib import Path


FAIL_PATTERNS = (
    re.compile(r"UVM_(?:ERROR|FATAL)\s*:\s*[1-9][0-9]*"),
    re.compile(r"data mismatch", re.IGNORECASE),
    re.compile(r"\[SVA\]"),
)


def command_text(command):
    """Format a subprocess argument list for logs and dry-runs."""
    return " ".join(shlex.quote(str(part)) for part in command)


def parse_seeds(value):
    """Accept comma-separated seeds and inclusive ranges, such as 1,3-5."""
    seeds = []
    for item in re.split(r"[\s,]+", value.strip()):
        item = item.strip()
        if not item:
            continue
        if "-" in item:
            first, last = item.split("-", 1)
            start, stop = int(first), int(last)
            if start > stop:
                raise ValueError("invalid seed range: {}".format(item))
            seeds.extend(range(start, stop + 1))
        else:
            seeds.append(int(item))
    if not seeds or any(seed < 0 for seed in seeds):
        raise ValueError("seeds must be non-negative integers")
    return list(dict.fromkeys(seeds))


def classify_log(log_path, return_code):
    """Return failure reasons using the same criteria as the Make regression."""
    reasons = []
    if return_code:
        reasons.append("simv exited with {}".format(return_code))
    if not log_path.exists():
        reasons.append("simulation log was not created")
        return reasons
    text = log_path.read_text(encoding="utf-8", errors="replace")
    for pattern in FAIL_PATTERNS:
        if pattern.search(text):
            reasons.append("log matched: {}".format(pattern.pattern))
    return reasons


def resolve_results_dir(sim_dir, value):
    """Resolve a user output path relative to verif/sim."""
    result_dir = Path(value)
    return result_dir if result_dir.is_absolute() else sim_dir / result_dir
