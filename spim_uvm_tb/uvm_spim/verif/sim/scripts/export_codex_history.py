#!/usr/bin/env python3
"""Export user/assistant messages for this workspace from local Codex JSONL."""

from __future__ import print_function

import argparse
import datetime
import json
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[4]
# The repository was moved from Linux ext4 to the Windows E: drive. Keep the
# former location so the archived migration session remains exportable.
KNOWN_PROJECT_CWDS = {
    str(PROJECT_ROOT),
    "/home/ray/ic/spim_uvm_tb",
}
DEFAULT_CODEX_HOME = Path.home() / ".codex"


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Export local Codex conversations belonging to this project."
    )
    parser.add_argument(
        "--codex-home",
        type=Path,
        default=DEFAULT_CODEX_HOME,
        help="Codex data directory (default: ~/.codex).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=PROJECT_ROOT / "docs" / "codex_history" / "spim_uvm_tb_codex_dialogue.md",
        help="Markdown output path.",
    )
    return parser.parse_args()


def message_text(content):
    pieces = []
    for item in content:
        if item.get("type") in ("input_text", "output_text"):
            pieces.append(item.get("text", ""))
    return "\n".join(piece for piece in pieces if piece.strip()).strip()


def cleaned_text(text):
    # Keep the educational dialogue, not environment dumps or tool transcripts.
    if "<environment_context>" in text or "<permissions instructions>" in text:
        return ""
    if text.startswith("<skills_instructions>") or text.startswith("<collaboration_mode>"):
        return ""
    return text


def session_messages(path):
    cwd_matches = False
    messages = []
    for line in path.open(encoding="utf-8", errors="replace"):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        payload = event.get("payload", {})
        if event.get("type") == "session_meta":
            cwd_matches = payload.get("cwd") in KNOWN_PROJECT_CWDS
        if event.get("type") != "response_item" or payload.get("type") != "message":
            continue
        role = payload.get("role")
        if role not in ("user", "assistant"):
            continue
        text = cleaned_text(message_text(payload.get("content", [])))
        if text:
            messages.append((event.get("timestamp", ""), role, text))
    return cwd_matches, messages


def discover_sessions(codex_home):
    sessions = []
    for path in sorted((codex_home / "archived_sessions").glob("*.jsonl")):
        matched, messages = session_messages(path)
        if matched:
            sessions.append((path, messages))
    return sessions


def markdown_escape_heading(text):
    return re.sub(r"\s+", " ", text).strip()[:100]


def write_export(output, sessions):
    lines = [
        "# spim_uvm_tb Codex 学习对话记录",
        "",
        "此文件由 `export_codex_history.py` 从本机 Codex 已归档会话导出。",
        "仅保留用户与助手的文本对话；不含系统提示、环境配置、工具调用和隐藏推理。",
        "",
        "- 项目路径：`{}`".format(PROJECT_ROOT),
        "- 导出时间：`{}`".format(datetime.datetime.now().astimezone().isoformat(timespec="seconds")),
        "- 已导出会话数：`{}`".format(len(sessions)),
        "",
    ]
    for index, (path, messages) in enumerate(sessions, start=1):
        lines.extend(["## 会话 {}：`{}`".format(index, path.stem), ""])
        for timestamp, role, text in messages:
            title = "用户" if role == "user" else "Codex"
            lines.extend(["### {} `{}`".format(title, timestamp), "", text, ""])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")


def main():
    args = parse_arguments()
    sessions = discover_sessions(args.codex_home)
    write_export(args.output, sessions)
    print("Exported {} archived session(s) to {}".format(len(sessions), args.output))
    if not sessions:
        print("No matching archived sessions found. The current live conversation is exported after Codex archives it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
