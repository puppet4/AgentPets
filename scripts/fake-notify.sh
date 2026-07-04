#!/usr/bin/env bash
# fake-notify.sh — drop a fake hook event into the inbox for testing.
# Usage: fake-notify.sh <kind> [tool] [file]
#   fake-notify.sh PreToolUse Edit PetModel.swift
#   fake-notify.sh Stop
set -euo pipefail

INBOX="${HOME}/Library/Application Support/AgentPets/inbox"
mkdir -p "$INBOX"

KIND="${1:-UserPromptSubmit}"
TOOL="${2:-}"
FILE="${3:-}"

ts="$(date +%s%N)"

python3 - "$INBOX" "$ts" "$KIND" "$TOOL" "$FILE" <<'PY'
import json
import pathlib
import sys
import time

inbox, ts, kind, tool, file = sys.argv[1:6]

payload = {
    "hook_event_name": kind,
    "tool_name": tool or None,
    "tool_input": {"file_path": file} if file else None,
    "prompt": "fake prompt" if kind == "UserPromptSubmit" else None,
    "ts": time.time(),
}
# Strip None values
payload = {k: v for k, v in payload.items() if v is not None}

out = pathlib.Path(inbox) / f"{ts}.json"
out.write_text(json.dumps(payload))
print(f"✓ {out}")
PY
