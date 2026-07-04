#!/usr/bin/env bash
# uninstall-hooks.sh — removes pet-notify entries from ~/.claude/settings.json.
set -euo pipefail

SETTINGS="${HOME}/.claude/settings.json"
NOTIFY="${HOME}/.local/bin/pet-notify"

if [[ ! -f "$SETTINGS" ]]; then
    echo "No settings.json found; nothing to do."
    exit 0
fi

python3 - "$SETTINGS" "$NOTIFY" <<'PY'
import json
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
notify_cmd = sys.argv[2]
data = json.loads(p.read_text())
hooks = data.get("hooks", {})
removed = 0
for ev, arr in list(hooks.items()):
    if not isinstance(arr, list):
        continue
    new_arr = []
    for h in arr:
        if not isinstance(h, dict):
            new_arr.append(h)
            continue
        sub = h.get("hooks", [])
        if not isinstance(sub, list):
            new_arr.append(h)
            continue
        sub_filtered = [c for c in sub if not (isinstance(c, dict) and c.get("command") == notify_cmd)]
        if len(sub_filtered) != len(sub):
            removed += len(sub) - len(sub_filtered)
        if sub_filtered:
            new_h = dict(h)
            new_h["hooks"] = sub_filtered
            new_arr.append(new_h)
    if new_arr:
        hooks[ev] = new_arr
    else:
        del hooks[ev]

p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
print(f"✓ Removed {removed} pet-notify hook entries.")
PY