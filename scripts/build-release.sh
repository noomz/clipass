#!/bin/bash
# Build a Developer ID-signed, notarized, stapled clipass release.
# Usage: NOTARY_PROFILE=<notarytool keychain profile> scripts/build-release.sh VERSION
# Never substitute an ad-hoc artifact if signing or notarization fails.
set -euo pipefail

cd "$(dirname "$0")/.."

fail() { printf 'release blocked: %s\n' "$*" >&2; exit 1; }

APP_NAME="clipass"
VERSION="${1:?usage: scripts/build-release.sh VERSION}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool keychain profile}"
IDENTITY='Developer ID Application: Siriwat Uamngamsup (W6P9Y44LWU)'
TEAM='W6P9Y44LWU'

APP="dist/${APP_NAME}.app"
ZIP="dist/${APP_NAME}-v${VERSION}-macos-arm64.zip"
DMG="dist/${APP_NAME}-v${VERSION}-macos-arm64.dmg"

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || fail 'invalid version'
plist_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_NAME}/Info.plist")
[ "$plist_version" = "$VERSION" ] || fail "Info.plist says $plist_version, not $VERSION"
[[ "$(security find-identity -v -p codesigning)" == *"$IDENTITY"* ]] || fail 'Developer ID identity unavailable'
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json --no-progress >/dev/null \
  || fail 'notary profile unavailable'

[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_NAME}/Info.plist")" =~ ^[1-9][0-9]*$ ]] \
  || fail 'CFBundleVersion must be an integer build number (Sparkle compares it)'

echo "==> Building ${APP_NAME} v${VERSION} (release)..."
# SwiftPM's swift-build backend records LC_BUILD_VERSION sdk = deployment target (14.0),
# so AppKit applies old-SDK compatibility (opaque MenuBarExtra window). Tell the linker
# the real SDK version; the check below fails the release if it doesn't stick.
expected_sdk=$(xcrun --sdk macosx --show-sdk-version)
min_macos=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${APP_NAME}/Info.plist")
swift build -c release \
  -Xlinker -platform_version -Xlinker macos -Xlinker "$min_macos" -Xlinker "$expected_sdk"
built_sdk=$(otool -l ".build/release/${APP_NAME}" | awk '/LC_BUILD_VERSION/{f=1} f&&$1=="sdk"{print $2; exit}')
echo "    Xcode $(xcodebuild -version | head -1 | cut -d' ' -f2), SDK ${expected_sdk}, binary sdk ${built_sdk}"
[ "$built_sdk" = "$expected_sdk" ] || fail "binary links SDK $built_sdk, expected $expected_sdk"

echo "==> Creating app bundle..."
rm -rf dist
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources" "${APP}/Contents/Frameworks"
cp ".build/release/${APP_NAME}" "${APP}/Contents/MacOS/"
ditto ".build/release/Sparkle.framework" "${APP}/Contents/Frameworks/Sparkle.framework"
cp "${APP_NAME}/Info.plist" "${APP}/Contents/"
cp "${APP_NAME}/AppIcon.icns" "${APP}/Contents/Resources/"
# SwiftPM resource bundles (KeyboardShortcuts' recorder asserts without its Bundle.module).
for bundle in .build/release/*.bundle; do
  cp -R "$bundle" "${APP}/Contents/Resources/"
done
echo -n "APPL????" > "${APP}/Contents/PkgInfo"

echo "==> Signing with Developer ID + hardened runtime..."
# Inside-out, per Sparkle's "Distributing outside the Mac App Store" signing order.
sparkle="${APP}/Contents/Frameworks/Sparkle.framework"
sign() { codesign --force --timestamp --options runtime --sign "$IDENTITY" "$@"; }
sign "$sparkle/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
sign "$sparkle/Versions/B/Autoupdate"
sign "$sparkle/Versions/B/Updater.app"
sign "$sparkle"
for helper in "$sparkle/Versions/B/XPCServices/Installer.xpc" "$sparkle/Versions/B/XPCServices/Downloader.xpc" \
              "$sparkle/Versions/B/Autoupdate" "$sparkle/Versions/B/Updater.app" "$sparkle"; do
  [[ "$(codesign -dv --verbose=2 "$helper" 2>&1)" == *"TeamIdentifier=$TEAM"* ]] || fail "wrong signing team: $helper"
done
sign "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
sig=$(codesign -dv --verbose=2 "$APP" 2>&1)
[[ "$sig" == *"TeamIdentifier=$TEAM"* ]] || fail 'wrong signing team'
[[ "$sig" == *"Identifier=com.clipass.app"* ]] || fail 'wrong bundle identifier'
[[ "$sig" == *runtime* ]] || fail 'hardened runtime missing'

work=$(mktemp -d "${TMPDIR:-/tmp}/clipass-release.XXXXXXXX")

submit() {
  local artifact=$1 result=$2
  xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" --wait --no-progress --output-format json > "$result"
  python3 - "$result" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"    notarization {r.get('id')}: {r.get('status')}")
if r.get('status') != 'Accepted':
    raise SystemExit('release blocked: notarization not accepted')
PY
}

echo "==> Notarizing app..."
ditto -c -k --sequesterRsrc --keepParent "$APP" "$work/notary.zip"
submit "$work/notary.zip" "$work/app-notarization.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl -a -vvv "$APP"

echo "==> Creating zip of stapled app..."
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Creating and notarizing DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
submit "$DMG" "$work/dmg-notarization.json"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vvv -t open --context context:primary-signature "$DMG"

mount="$work/mount"
mkdir "$mount"
hdiutil attach -readonly -nobrowse -mountpoint "$mount" "$DMG" >/dev/null
trap 'hdiutil detach "$mount" >/dev/null' EXIT
xcrun stapler validate "$mount/${APP_NAME}.app"
codesign --verify --deep --strict --verbose=2 "$mount/${APP_NAME}.app"
spctl -a -vvv "$mount/${APP_NAME}.app"
hdiutil detach "$mount" >/dev/null
trap - EXIT

echo "==> Done!"
echo "    App: ${APP}"
echo "    Zip: ${ZIP} ($(shasum -a 256 "$ZIP" | cut -c1-16))"
echo "    DMG: ${DMG} ($(shasum -a 256 "$DMG" | cut -c1-16))"
