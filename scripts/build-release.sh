#!/bin/bash
set -euo pipefail

APP_NAME="clipass"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
APP_BUNDLE="dist/${APP_NAME}.app"
ZIP_FILE="dist/${APP_NAME}-v${VERSION}-macos-arm64.zip"

echo "==> Building ${APP_NAME} v${VERSION} (release)..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf dist
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
cp "${APP_NAME}/Info.plist" "${APP_BUNDLE}/Contents/"

# Copy app icon
if [ -f "${APP_NAME}/AppIcon.icns" ]; then
    cp "${APP_NAME}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "    Icon copied."
fi

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> Creating zip archive..."
(cd dist && zip -r -y "../${ZIP_FILE}" "${APP_NAME}.app")

echo "==> Done!"
echo "    App bundle: ${APP_BUNDLE}"
echo "    Archive:    ${ZIP_FILE}"
echo "    Size:       $(du -h "${ZIP_FILE}" | cut -f1)"
