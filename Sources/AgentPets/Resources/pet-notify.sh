#!/usr/bin/env bash
# pet-notify.sh — reads Claude Code hook JSON from stdin and drops it as a file
# into ~/Library/Application Support/AgentPets/inbox/. The Agent Pets app
# watches that directory and consumes each file.
#
# Atomic write: temp file + rename, so the watcher never reads a partial file.
set -euo pipefail

INBOX="${AGENT_PETS_INBOX:-${TOUCHBAR_PET_INBOX:-$HOME/Library/Application Support/AgentPets/inbox}}"

mkdir -p "$INBOX"

# Nanosecond timestamp gives monotonic ordering even on rapid bursts.
ts="$(date +%s%N)"
tmp="$(mktemp "${INBOX}/.${ts}.XXXX.tmp")"

payload="$(cat)"
tty_value="$(tty 2>/dev/null || true)"
if [[ "$tty_value" == not\ a\ tty* ]]; then
  tty_value=""
fi

python3 - "$tmp" "${TERM_PROGRAM:-}" "${TERM_SESSION_ID:-}" "${ITERM_SESSION_ID:-}" "${PWD:-}" "$tty_value" "$payload" <<'PY'
import json
import pathlib
import sys

target = pathlib.Path(sys.argv[1])
term_program = sys.argv[2] or None
term_session_id = sys.argv[3] or None
iterm_session_id = sys.argv[4] or None
cwd = sys.argv[5] or None
tty_value = sys.argv[6] or None
raw = sys.argv[7]

try:
    parsed = json.loads(raw)
    if isinstance(parsed, dict):
        meta = parsed.get("task_meta")
        if not isinstance(meta, dict):
            meta = {}
        if term_program:
            meta["term_program"] = term_program
        if term_session_id:
            meta["term_session_id"] = term_session_id
        if iterm_session_id:
            meta["iterm_session_id"] = iterm_session_id
        if cwd:
            meta["cwd"] = cwd
        if tty_value:
            meta["tty"] = tty_value.removeprefix("/dev/")
        parsed["task_meta"] = meta
        target.write_text(json.dumps(parsed, ensure_ascii=False))
    else:
        target.write_text(raw)
except Exception:
    target.write_text(raw)
PY

mv "$tmp" "${INBOX}/${ts}.json"
