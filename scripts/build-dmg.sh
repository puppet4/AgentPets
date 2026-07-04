#!/usr/bin/env bash
# build-dmg.sh — builds a release app bundle and packages it into a distributable DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="release"
APP_NAME="AgentPets"
BIN_NAME="AgentPets"
PLIST_PATH="${ROOT}/Sources/AgentPets/App/Info.plist"
DIST_DIR="${ROOT}/dist"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentpets-dmg.XXXXXX")"
APP_DIR="${TMP_DIR}/${APP_NAME}.app"
DMG_ROOT="${TMP_DIR}/dmg-root"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST_PATH}")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
RES_BUNDLE=""

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

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
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${EXE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cp "${PLIST_PATH}" "${APP_DIR}/Contents/Info.plist"
cp "${ROOT}/Sources/AgentPets/App/AgentPets.icns" "${APP_DIR}/Contents/Resources/AgentPets.icns"

if [[ -d "${RES_BUNDLE}" ]]; then
    cp -R "${RES_BUNDLE}/." "${APP_DIR}/Contents/Resources/"
fi

if [[ -f "${ROOT}/Sources/AgentPets/Resources/pet-notify.sh" ]]; then
    cp "${ROOT}/Sources/AgentPets/Resources/pet-notify.sh" "${APP_DIR}/Contents/Resources/pet-notify.sh"
    chmod +x "${APP_DIR}/Contents/Resources/pet-notify.sh"
fi

echo "▶ Ad-hoc signing..."
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true
xattr -cr "${APP_DIR}" 2>/dev/null || true

echo "▶ Preparing DMG layout..."
rm -rf "${DMG_ROOT}"
mkdir -p "${DMG_ROOT}"
cp -R "${APP_DIR}" "${DMG_ROOT}/${APP_NAME}.app"
ln -s /Applications "${DMG_ROOT}/Applications"

mkdir -p "${DIST_DIR}"
rm -f "${DMG_PATH}"

echo "▶ Creating ${DMG_NAME}..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_ROOT}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" >/dev/null

echo ""
echo "✓ DMG created"
echo "  File: ${DMG_PATH}"
