#!/usr/bin/env bash
# install-launchagent.sh — register AgentPets to auto-start at login.
# Creates ~/Library/LaunchAgents/com.agentpets.app.plist and loads it.
set -euo pipefail

LABEL="com.agentpets.app"
APP_PATH="${HOME}/Applications/AgentPets.app"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "✗ ${APP_PATH} not found. Run scripts/build-and-install.sh first." >&2
    exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP_PATH}/Contents/MacOS/AgentPets</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Application Support/AgentPets/logs/launchagent.out.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Application Support/AgentPets/logs/launchagent.err.log</string>
</dict>
</plist>
EOF

# Unload existing (ignore errors)
launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
launchctl unload "${PLIST}" 2>/dev/null || true

# Load
launchctl load -w "${PLIST}"
launchctl enable "gui/$(id -u)/${LABEL}"

echo "✓ Installed LaunchAgent at ${PLIST}"
echo "  Agent Pets will start automatically next time you log in."
echo "  To start it now without logging out: launchctl start ${LABEL}"
echo ""
echo "Other commands:"
echo "  launchctl list | grep agentpets          # check status"
echo "  launchctl kickstart -k gui/\$(id -u)/${LABEL}   # force restart"
echo "  scripts/uninstall-launchagent.sh        # remove"
