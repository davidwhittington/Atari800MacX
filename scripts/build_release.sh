#!/usr/bin/env bash
# build_release.sh — Atari800MacX distribution build script
# Phase 9: Automates archive → export → DMG → notarize → staple workflow.
#
# USAGE
#   ./scripts/build_release.sh
#
# PREREQUISITES
#   1. Xcode 15+ installed with command-line tools.
#   2. A valid "Developer ID Application" certificate in your keychain.
#   3. Notarytool credentials stored under the profile name "Atari800MacX":
#        xcrun notarytool store-credentials "Atari800MacX" \
#            --apple-id  YOUR_APPLE_ID \
#            --team-id   X49M46V9N7 \
#            --password  YOUR_APP_SPECIFIC_PASSWORD
#      Generate an app-specific password at appleid.apple.com.
#
# ENVIRONMENT VARIABLES (all optional)
#   TEAM_ID            Apple Developer Team ID        (default: X49M46V9N7)
#   APP_VERSION        Version string for DMG name    (default: from Info.plist)
#   KEYCHAIN_PROFILE   notarytool keychain profile    (default: Atari800MacX)
#   SKIP_NOTARIZE      Set to 1 to skip notarization  (default: unset)

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_PATH="${PROJECT_ROOT}/atari800-MacOSX/src/Atari800MacX/Atari800MacX.xcodeproj"
INFO_PLIST="${PROJECT_ROOT}/atari800-MacOSX/src/Atari800MacX/Info-Atari800MacX.plist"
EXPORT_OPTIONS="${PROJECT_ROOT}/ExportOptions.plist"
BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/Atari800MacX.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"

# ── Configuration ─────────────────────────────────────────────────────────────
TEAM_ID="${TEAM_ID:-X49M46V9N7}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-Atari800MacX}"
APP_VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null || echo "unknown")}"
DMG_NAME="Atari800MacX-${APP_VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

log()  { printf '\033[1;34m[build_release]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[build_release] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1;32m══ %s\033[0m\n' "$*"; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ -f "${PROJECT_PATH}/project.pbxproj" ]] || die "Xcode project not found at: ${PROJECT_PATH}"
[[ -f "${EXPORT_OPTIONS}" ]]               || die "ExportOptions.plist not found at: ${EXPORT_OPTIONS}"
command -v xcodebuild  >/dev/null           || die "xcodebuild not found — install Xcode command-line tools"
command -v xcrun       >/dev/null           || die "xcrun not found"
command -v hdiutil     >/dev/null           || die "hdiutil not found"

mkdir -p "${BUILD_DIR}"

log "Project root : ${PROJECT_ROOT}"
log "App version  : ${APP_VERSION}"
log "Team ID      : ${TEAM_ID}"
log "Output DMG   : ${DMG_PATH}"

# ── Step 1: Archive ───────────────────────────────────────────────────────────
step "1/5  Archiving (Deployment configuration)"
xcodebuild archive \
    -project "${PROJECT_PATH}" \
    -scheme   Atari800MacX \
    -configuration Deployment \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    -allowProvisioningUpdates

log "Archive written to: ${ARCHIVE_PATH}"

# ── Step 2: Export (Developer ID) ────────────────────────────────────────────
step "2/5  Exporting for Developer ID distribution"
xcodebuild -exportArchive \
    -archivePath    "${ARCHIVE_PATH}" \
    -exportPath     "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -allowProvisioningUpdates

APP_PATH="${EXPORT_PATH}/Atari800MacX.app"
[[ -d "${APP_PATH}" ]] || die "Exported app not found at: ${APP_PATH}"
log "Exported app: ${APP_PATH}"

# ── Step 3: Create DMG ────────────────────────────────────────────────────────
step "3/5  Creating DMG"
[[ -f "${DMG_PATH}" ]] && { log "Removing existing DMG..."; rm "${DMG_PATH}"; }

hdiutil create \
    -volname  "Atari800MacX ${APP_VERSION}" \
    -srcfolder "${APP_PATH}" \
    -ov \
    -format   UDZO \
    "${DMG_PATH}"

log "DMG created: ${DMG_PATH}"

# ── Step 4: Notarize ──────────────────────────────────────────────────────────
if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    log "Skipping notarization (SKIP_NOTARIZE=1)"
else
    step "4/5  Submitting to Apple Notary Service (may take a few minutes)"
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${KEYCHAIN_PROFILE}" \
        --wait
    log "Notarization complete"
fi

# ── Step 5: Staple ────────────────────────────────────────────────────────────
step "5/5  Stapling notarization ticket"
xcrun stapler staple "${DMG_PATH}"

printf '\n\033[1;32m✓ Release build complete:\033[0m %s\n' "${DMG_PATH}"
