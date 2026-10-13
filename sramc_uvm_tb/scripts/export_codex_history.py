#!/usr/bin/env python3
"""Export Codex user/assistant messages for one workspace as Markdown.

Codex keeps session JSONL files outside a repository. This utility locates
only sessions whose metadata cwd matches --project-root, skips tool traffic
and framework prompts, then writes a readable project transcript.
"""

from __future__ import print_function

import argparse
import datetime
import glob
import json
import os
import re
import sys


DEFAULT_CODEX_DIR = os.path.expanduser("~/.codex")
NOISE_PREFIXES = (
    "# AGENTS.md instructions for ",
    "<environment_context>",
    "<permissions instructions>",
    "<collaboration_mode>",
    "<skills_instructions>",
)
INTERNAL_ASSISTANT_PREFIXES = (
    "## Handoff Summary",
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Export Codex conversation records for this project to Markdown."
    )
    parser.add_argument(
        "--project-root",
        default=os.getcwd(),
        help="Repository path stored as the Codex session cwd (default: current directory).",
    )
    parser.add_argument(
        "--codex-dir",
        default=DEFAULT_CODEX_DIR,
        help="Codex data directory (default: ~/.codex).",
    )
    parser.add_argument(
        "--output",
        default="docs/codex_conversation_export.md",
        help="Markdown output path (default: docs/codex_conversation_export.md).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print matching sessions and message count without writing a file.",
    )
    return parser.parse_args()


def jsonl_paths(codex_dir):
    patterns = (
        os.path.join(codex_dir, "sessions", "**", "*.jsonl"),
        os.path.join(codex_dir, "archived_sessions", "*.jsonl"),
    )
    paths = []
    for pattern in patterns:
        paths.extend(glob.glob(pattern, recursive=True))
    return sorted(set(paths))


def read_records(path):
    records = []
    with open(path, "r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            try:
                records.append(json.loads(line))
            except ValueError:
                print("warning: skip invalid JSON at {0}:{1}".format(path, line_number),
                      file=sys.stderr)
    return records


def belongs_to_project(records, project_root):
    for record in records:
        if record.get("type") != "session_meta":
            continue
        payload = record.get("payload", {})
        # Review/guardian subagent sessions can carry this cwd while embedding
        # another conversation as their input; they are not this project's chat.
        source = payload.get("source", {})
        if isinstance(source, dict) and source.get("subagent"):
            return False
        cwd = payload.get("cwd")
        if cwd and os.path.realpath(cwd) == project_root:
            return True
    return False


def text_from_content(content):
    pieces = []
    for item in content or []:
        if not isinstance(item, dict):
            continue
        if item.get("type") in ("input_text", "output_text"):
            text = item.get("text", "").strip()
            if text:
                pieces.append(text)
        elif item.get("type") == "input_image":
            pieces.append("[图片已省略]")
    return "\n".join(pieces).strip()


def is_framework_noise(role, text):
    if role == "user":
        return any(text.startswith(prefix) for prefix in NOISE_PREFIXES)
    if role == "assistant":
        return any(text.startswith(prefix) for prefix in INTERNAL_ASSISTANT_PREFIXES)
    return False


def redact(text):
    """Remove common credential forms while preserving ordinary technical text."""
    text = re.sub(
        r"(?im)^(\s*(?:password|passwd|token|api[_ -]?key|secret)\s*[:=]\s*).*?$",
        r"\1[REDACTED]",
        text,
    )
    text = re.sub(r"(https?://[^\s/:@]+:)[^\s@/]+@", r"\1[REDACTED]@", text)
    text = re.sub(
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----",
        "[PRIVATE KEY REDACTED]",
        text,
        flags=re.DOTALL,
    )
    return text


def extract_messages(path, records):
    messages = []
    for record in records:
        payload = record.get("payload", {})
        if record.get("type") != "response_item" or payload.get("type") != "message":
            continue
        role = payload.get("role")
        if role not in ("user", "assistant"):
            continue
        text = text_from_content(payload.get("content"))
        if not text or is_framework_noise(role, text):
            continue
        messages.append({
            "role": role,
            "text": redact(text),
            "timestamp": record.get("timestamp", ""),
            "source": os.path.basename(path),
        })
    return messages


def markdown(messages, project_root, session_paths):
    created = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    lines = [
        "# sramc_uvm_tb Codex 对话导出",
        "",
        "- 导出时间: `{0}`".format(created),
        "- 项目根目录: `{0}`".format(project_root),
        "- 匹配会话: `{0}`，有效消息: `{1}`".format(len(session_paths), len(messages)),
        "- 范围: 仅用户与 Codex 文本消息；已省略工具调用、系统/开发者提示、子代理会话和图片。",
        "- 安全: 常见的 `password/token/api_key/secret` 赋值与私钥会被脱敏；提交前仍应人工检查。",
        "",
    ]
    last_source = None
    for message in messages:
        if message["source"] != last_source:
            last_source = message["source"]
            lines.extend(["---", "", "## 会话 `{0}`".format(last_source), ""])
        speaker = "用户" if message["role"] == "user" else "Codex"
        timestamp = message["timestamp"] or "未知时间"
        lines.extend([
            "### {0} ({1})".format(speaker, timestamp),
            "",
            message["text"],
            "",
        ])
    return "\n".join(lines)


def main():
    args = parse_args()
    project_root = os.path.realpath(args.project_root)
    session_paths = []
    messages = []
    for path in jsonl_paths(args.codex_dir):
        records = read_records(path)
        if belongs_to_project(records, project_root):
            session_paths.append(path)
            messages.extend(extract_messages(path, records))

    if args.dry_run:
        print("project root: {0}".format(project_root))
        print("matching sessions: {0}".format(len(session_paths)))
        for path in session_paths:
            print("  {0}".format(path))
        print("exported messages: {0}".format(len(messages)))
        return 0

    output = os.path.abspath(args.output)
    output_dir = os.path.dirname(output)
    if not os.path.isdir(output_dir):
        os.makedirs(output_dir)
    with open(output, "w", encoding="utf-8") as target:
        target.write(markdown(messages, project_root, session_paths))
    print("exported {0} messages from {1} sessions to {2}".format(
        len(messages), len(session_paths), output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
