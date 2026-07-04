#!/usr/bin/env bash
# install-codex-hooks.sh — idempotently merges pet-notify into ~/.codex/hooks.json
# next to existing Codex/OMX hooks.
set -euo pipefail

NOTIFY="${HOME}/.local/bin/pet-notify"
HOOKS="${HOME}/.codex/hooks.json"

if [[ ! -x "$NOTIFY" ]]; then
    echo "✗ pet-notify not found at $NOTIFY" >&2
    echo "  Run scripts/build-and-install.sh first." >&2
    exit 1
fi

python3 - "$HOOKS" "$NOTIFY" <<'PY'
import json
import pathlib
import sys

hooks_path = pathlib.Path(sys.argv[1])
notify_cmd = sys.argv[2]

data = {"hooks": {}}
if hooks_path.exists():
    try:
        parsed = json.loads(hooks_path.read_text())
        if isinstance(parsed, dict):
            data = parsed
    except Exception:
        pass

hooks = data.setdefault("hooks", {})

events = [
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PostToolUseFailure",
    "Notification",
    "Stop",
    "PreCompact",
    "PostCompact",
    "SessionEnd",
]

added = 0
for ev in events:
    arr = hooks.get(ev, [])
    if not isinstance(arr, list):
        arr = []
    already = any(
        isinstance(group, dict)
        and isinstance(group.get("hooks"), list)
        and any(
            isinstance(command, dict)
            and command.get("command") == notify_cmd
            for command in group["hooks"]
        )
        for group in arr
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

hooks_path.parent.mkdir(parents=True, exist_ok=True)
hooks_path.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(f"✓ Merged {added} Codex hook entries into {hooks_path}")
PY
