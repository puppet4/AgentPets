#!/usr/bin/env bash
# install-hooks.sh — idempotently merges pet-notify into ~/.claude/settings.json
# under the "hooks" key, without touching other top-level fields (env, model, etc.).
set -euo pipefail

NOTIFY="${HOME}/.local/bin/pet-notify"
SETTINGS="${HOME}/.claude/settings.json"

if [[ ! -x "$NOTIFY" ]]; then
    echo "✗ pet-notify not found at $NOTIFY" >&2
    echo "  Run scripts/build-and-install.sh first." >&2
    exit 1
fi

python3 - "$SETTINGS" "$NOTIFY" <<'PY'
import json
import pathlib
import sys

settings_path = pathlib.Path(sys.argv[1])
notify_cmd = sys.argv[2]

data = {}
if settings_path.exists():
    try:
        data = json.loads(settings_path.read_text())
        if not isinstance(data, dict):
            data = {}
    except Exception:
        data = {}

hooks = data.setdefault("hooks", {})

EVENTS = [
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PostToolUseFailure",
    "Notification",
    "Stop",
    "SubagentStop",
    "PreCompact",
    "SessionEnd",
]

added = 0
for ev in EVENTS:
    arr = hooks.get(ev, [])
    if not isinstance(arr, list):
        arr = []
    already = any(
        isinstance(h, dict)
        and isinstance(h.get("hooks"), list)
        and any(
            isinstance(c, dict) and c.get("command") == notify_cmd
            for c in h["hooks"]
        )
        for h in arr
    )
    if not already:
        arr.append({
            "hooks": [{
                "type": "command",
                "command": notify_cmd,
                "timeout": 10
            }]
        })
        hooks[ev] = arr
        added += 1

# Write back with pretty formatting, preserving other fields.
settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(data, indent=2, ensure_ascii=False))

print(f"✓ Merged {added} hook entries into {settings_path}")
PY