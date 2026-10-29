#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ABOLIFE_MAIN_BUNDLE="$PWD/work/app-build.noindex/AboLife.app"
test -d "$ABOLIFE_MAIN_BUNDLE" || { echo 'Zuerst scripts/package-local-app.sh ausführen.' >&2; exit 1; }
ABOLIFE_DEMO_BUNDLE="$PWD/work/app-build.noindex/AboLife-Demo.app"
mkdir -p "$ABOLIFE_DEMO_BUNDLE"
/usr/bin/ditto "$ABOLIFE_MAIN_BUNDLE" "$ABOLIFE_DEMO_BUNDLE"
python3 - "$ABOLIFE_DEMO_BUNDLE/Contents/Info.plist" <<'PY'
import plistlib,sys
path=sys.argv[1]
with open(path,'rb') as f:info=plistlib.load(f)
info['CFBundleIdentifier']='com.private.AboLife.demo'
info['CFBundleDisplayName']='AboLife Demo'
with open(path,'wb') as f:plistlib.dump(info,f)
PY
codesign --force --sign - "$ABOLIFE_DEMO_BUNDLE"
codesign --verify --deep --strict "$ABOLIFE_DEMO_BUNDLE"
printf 'Isolierte Demo-App: %s\n' "$ABOLIFE_DEMO_BUNDLE"
