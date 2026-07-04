#!/usr/bin/env bash
# uninstall-launchagent.sh — remove the auto-start LaunchAgent.
set -euo pipefail

LABEL="com.agentpets.app"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [[ ! -f "${PLIST}" ]]; then
    echo "No LaunchAgent found at ${PLIST}; nothing to do."
    exit 0
fi

launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
launchctl unload "${PLIST}" 2>/dev/null || true
launchctl disable "gui/$(id -u)/${LABEL}" 2>/dev/null || true

rm -f "${PLIST}"

echo "✓ Removed LaunchAgent."
echo "  Agent Pets will no longer auto-start at login."
echo "  Existing instance is still running; quit it from the menu bar icon."
