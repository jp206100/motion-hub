#!/bin/bash
set -euo pipefail

# create-dmg.sh — Build MotionHub.app and package it into a DMG for distribution.
#
# Usage:
#   ./create-dmg.sh              # Build Release and create DMG
#   ./create-dmg.sh --skip-build # Create DMG from existing build artifacts

APP_NAME="MotionHub"
SCHEME="MotionHub"
PROJECT="MotionHub.xcodeproj"
CONFIGURATION="Release"
BUILD_DIR="$(pwd)/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_OUTPUT="${BUILD_DIR}/${APP_NAME}.dmg"

SKIP_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
    esac
done

echo "==> Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${EXPORT_DIR}" "${DMG_DIR}"

if [ "$SKIP_BUILD" = false ]; then
    echo "==> Archiving ${APP_NAME} (${CONFIGURATION})..."
    xcodebuild archive \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -archivePath "${ARCHIVE_PATH}" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=NO \
        | xcbeautify 2>/dev/null || xcodebuild archive \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -archivePath "${ARCHIVE_PATH}" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=NO

    echo "==> Exporting app from archive..."
    # Copy the .app directly from the archive (no signing needed for ad-hoc distribution)
    cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"
fi

if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: ${APP_PATH} not found. Run without --skip-build first."
    exit 1
fi

echo "==> Creating DMG..."

# Stage the DMG contents: app + Applications symlink for drag-install
cp -R "${APP_PATH}" "${DMG_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_DIR}/Applications"

# Create the DMG
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_OUTPUT}"

DMG_SIZE=$(du -h "${DMG_OUTPUT}" | cut -f1)
echo ""
echo "==> Done! DMG created at:"
echo "    ${DMG_OUTPUT} (${DMG_SIZE})"
