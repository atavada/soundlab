#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SoundLab"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building SoundLab release executable..."
swift build -c release

echo "Creating application bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

BIN_PATH=$(swift build -c release --show-bin-path)
cp "${BIN_PATH}/SoundLabApp" "${MACOS_DIR}/${APP_NAME}"
cp "Sources/SoundLabApp/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "Ad-hoc code signing bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Bundle successfully created at ${APP_BUNDLE}"
