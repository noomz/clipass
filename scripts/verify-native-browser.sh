#!/bin/bash
set -euo pipefail

# Build a disposable app entry point against the production sources. Never initialize AppServices.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d /tmp/clipass-native-browser.XXXXXX)"
export CLIPASS_NATIVE_RENDER_EVIDENCE="$WORK/evidence"
mkdir -p "$CLIPASS_NATIVE_RENDER_EVIDENCE"
if [[ "${CLIPASS_NATIVE_SCREENSHOTS:-0}" == 1 ]]; then
    export CLIPASS_NATIVE_EVIDENCE="$WORK/evidence"
    mkdir -p "$CLIPASS_NATIVE_EVIDENCE"
else
    unset CLIPASS_NATIVE_EVIDENCE
fi
python3 - "$ROOT" "$WORK" <<'PY'
import pathlib
import shutil
import sys

root, work = map(pathlib.Path, sys.argv[1:])
shutil.copytree(root / 'clipass', work / 'clipass')
shutil.copytree(root / 'clipassTests', work / 'clipassTests')
for name in ['Package.swift', 'Package.resolved']:
    shutil.copy2(root / name, work / name)
app = work / 'clipass/clipassApp.swift'
source = app.read_text()
entry = '@main\nstruct clipassApp: App {'
if source.count(entry) != 1:
    raise SystemExit('App entry point changed; update the native check harness.')
app.write_text(source.split(entry)[0])
shutil.copy2(root / 'scripts/native-browser/NativeBrowserChecks.swift', work / 'clipass/NativeBrowserChecks.swift')
PY
printf 'Isolated native check workspace: %s\n' "$WORK"
sdk=$(xcrun --sdk macosx --show-sdk-version)
min_macos=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT/clipass/Info.plist")
swift run --package-path "$WORK" \
    -Xlinker -platform_version -Xlinker macos -Xlinker "$min_macos" -Xlinker "$sdk" clipass
