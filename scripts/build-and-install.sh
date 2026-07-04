#!/usr/bin/env bash
# build-and-install.sh — builds the SwiftPM executable and assembles it into a
# proper .app bundle at ~/Applications/AgentPets.app. Then installs
# pet-notify to ~/.local/bin and merges hooks into Claude/Codex settings.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="release"
APP_NAME="AgentPets"
BIN_NAME="AgentPets"
INSTALL_DIR="${HOME}/Applications"
NOTIFY_INSTALL="${HOME}/.local/bin/pet-notify"
SUPPORT_DIR="${HOME}/Library/Application Support/AgentPets"

echo "▶ Building (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"
EXE="${BIN_PATH}/${BIN_NAME}"
RES_BUNDLE="${BIN_PATH}/${BIN_NAME}_${BIN_NAME}.bundle"

if [[ ! -x "${EXE}" ]]; then
    echo "✗ Built executable not found at ${EXE}" >&2
    exit 1
fi

echo "▶ Assembling ${APP_NAME}.app..."
APP_DIR="${INSTALL_DIR}/${APP_NAME}.app"
pkill -x "${APP_NAME}" 2>/dev/null || true
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${EXE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cp "${ROOT}/Sources/AgentPets/App/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${ROOT}/Sources/AgentPets/App/AgentPets.icns" "${APP_DIR}/Contents/Resources/AgentPets.icns"

# Copy resource bundle (SwiftPM puts the pet-notify.sh here via .copy("Resources"))
if [[ -d "${RES_BUNDLE}" ]]; then
    # Copy contents directly — avoid nested Resources/Resources/ duplication
    cp -R "${RES_BUNDLE}/." "${APP_DIR}/Contents/Resources/"
fi

# Also place pet-notify.sh at a stable path inside Contents/Resources for direct copy.
if [[ -f "${ROOT}/Sources/AgentPets/Resources/pet-notify.sh" ]]; then
    cp "${ROOT}/Sources/AgentPets/Resources/pet-notify.sh" "${APP_DIR}/Contents/Resources/pet-notify.sh"
    chmod +x "${APP_DIR}/Contents/Resources/pet-notify.sh"
fi

# Ad-hoc sign (required for NSTouchBar on some macOS versions).
echo "▶ Ad-hoc signing..."
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

# Strip quarantine
xattr -cr "${APP_DIR}" 2>/dev/null || true

# Install pet-notify
echo "▶ Installing pet-notify..."
mkdir -p "${HOME}/.local/bin"
cp "${APP_DIR}/Contents/Resources/pet-notify.sh" "${NOTIFY_INSTALL}"
chmod +x "${NOTIFY_INSTALL}"

# Create user data dirs
mkdir -p "${SUPPORT_DIR}/inbox" "${SUPPORT_DIR}/logs"

# Install hooks (idempotent)
echo "▶ Installing hooks into ~/.claude/settings.json..."
"${ROOT}/scripts/install-hooks.sh"

echo "▶ Installing hooks into ~/.codex/hooks.json..."
"${ROOT}/scripts/install-codex-hooks.sh"

echo "▶ Ensuring bundled pet packs are available..."
"${EXE}" --gen-bundled-pet-packs >/dev/null

echo ""
echo "✓ Install complete"
echo "  App bundle:  ${APP_DIR}"
echo "  pet-notify:  ${NOTIFY_INSTALL}"
echo "  Support dir: ${SUPPORT_DIR}"
echo ""
echo "▶ Launch:"
echo "    open ${APP_DIR}"
echo ""
echo "▶ Manual test (drop fake events):"
echo "    ${ROOT}/scripts/fake-notify.sh UserPromptSubmit"
echo "    ${ROOT}/scripts/fake-notify.sh PreToolUse Edit PetModel.swift"
echo "    ${ROOT}/scripts/fake-notify.sh Stop"
echo ""
echo "▶ Tail event log:"
echo "    tail -f '${SUPPORT_DIR}/logs/events.log'"
