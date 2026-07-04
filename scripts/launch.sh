#!/usr/bin/env bash
# launch.sh — quick-launch the app. Use this whenever you want to start it.
set -euo pipefail

APP="${HOME}/Applications/AgentPets.app"

if [[ ! -d "${APP}" ]]; then
    echo "✗ ${APP} not found." >&2
    echo "  Build it first: cd /Users/kangjialv/Desktop/AgentPets && bash scripts/build-and-install.sh" >&2
    exit 1
fi

# If already running, just activate; otherwise open.
if pgrep -f "AgentPets.app/Contents/MacOS/AgentPets" > /dev/null; then
    echo "✓ Already running. Bringing to front."
    open -a "${APP}"
else
    echo "▶ Launching ${APP}"
    open "${APP}"
    sleep 1
fi

echo ""
echo "Look for these indicators:"
echo "  • Menu bar: Agent Pets status icon"
echo "  • Desktop: floating robot panel near the bottom-right corner"
echo ""
echo "If the menu bar icon isn't visible, the app may be quarantined."
echo "Fix: xattr -dr com.apple.quarantine ${APP}"
