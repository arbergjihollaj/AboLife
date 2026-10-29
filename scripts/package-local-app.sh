#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ABOLIFE_PROJECT_DIR="$PWD"
if [ -z "${ABOLIFE_GRDB_CHECKOUT:-}" ]; then
  for candidate in "$HOME/Library/Developer/Xcode/DerivedData"/AboLife-*/SourcePackages/checkouts/GRDB.swift; do
    if [ -f "$candidate/Package.swift" ]; then export ABOLIFE_GRDB_CHECKOUT="$candidate"; break; fi
  done
fi
if [ ! -f work/native-harness/Package.swift ]; then
  echo 'Zuerst scripts/check-native.sh ausführen.' >&2
  exit 1
fi
if [ -z "${ABOLIFE_GRDB_CHECKOUT:-}" ]; then
  echo 'GRDB-Checkout fehlt; ABOLIFE_GRDB_CHECKOUT setzen.' >&2
  exit 1
fi
export CLANG_MODULE_CACHE_PATH="$PWD/work/cache"
swift build -c release -debug-info-format none --product AboLife --package-path work/native-harness --disable-sandbox --cache-path "$PWD/work/spm-cache" --scratch-path "$PWD/work/swift-build" --manifest-cache local > work/release-build.log 2>&1
ABOLIFE_BINARY=$(find "$ABOLIFE_PROJECT_DIR/work/swift-build" -path '*/Release/AboLife' -type f -print -quit)
if [ -z "$ABOLIFE_BINARY" ]; then
  ABOLIFE_BINARY=$(find "$ABOLIFE_PROJECT_DIR/work/swift-build" -path '*/release/AboLife' -type f -print -quit)
fi
test -n "$ABOLIFE_BINARY"
ABOLIFE_BUNDLE="$PWD/outputs/AboLife.app"
mkdir -p "$ABOLIFE_BUNDLE/Contents/MacOS" "$ABOLIFE_BUNDLE/Contents/Resources"
cp "$ABOLIFE_BINARY" "$ABOLIFE_BUNDLE/Contents/MacOS/AboLife"
xcrun actool AboLife/Assets.xcassets --compile "$ABOLIFE_BUNDLE/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$PWD/work/icon-info.plist" > work/assets-build.log 2>&1
python3 - "$ABOLIFE_BUNDLE" <<'PY'
import plistlib,sys,pathlib
bundle=pathlib.Path(sys.argv[1]);info={'CFBundleName':'AboLife','CFBundleDisplayName':'AboLife','CFBundleExecutable':'AboLife','CFBundleIdentifier':'com.private.AboLife','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.4.0','CFBundleVersion':'4','LSMinimumSystemVersion':'14.0','NSPrincipalClass':'NSApplication','LSApplicationCategoryType':'public.app-category.productivity','NSHighResolutionCapable':True}
info.update(plistlib.load(open('work/icon-info.plist','rb')))
plistlib.dump(info,open(bundle/'Contents/Info.plist','wb'))
PY
# GRDB has no third-party dynamic libraries; its privacy resource is retained.
for resource in "$PWD/work/swift-build/out/Products/Release"/*.bundle; do
  if [ -d "$resource" ]; then cp -R "$resource" "$ABOLIFE_BUNDLE/Contents/Resources/"; fi
done
codesign --force --sign - "$ABOLIFE_BUNDLE" > work/codesign.log 2>&1
codesign --verify --deep --strict "$ABOLIFE_BUNDLE"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$ABOLIFE_BUNDLE" "$PWD/outputs/AboLife-0.4-macOS.zip"
printf 'App bereit: %s\n' "$ABOLIFE_BUNDLE"
