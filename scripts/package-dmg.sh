#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

APP_NAME="SoundLab"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
DMG_STAGE="${BUILD_DIR}/dmg-staging"

./scripts/bundle.sh

rm -rf "${DMG_STAGE}" "${BUILD_DIR}/${DMG_NAME}"
mkdir -p "${DMG_STAGE}"

cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGE}" \
  -ov -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

rm -rf "${DMG_STAGE}"
echo "DMG successfully created at ${BUILD_DIR}/${DMG_NAME}"
