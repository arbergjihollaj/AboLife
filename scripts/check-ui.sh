#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# UI tests always launch an isolated temporary demo via ABOLIFE_DEMO.
# Requires an unlocked graphical login session with XCTest UI automation permissions.
test -d work/app-build.noindex/AboLife-Demo.app || {
  echo 'Zuerst scripts/package-local-app.sh und scripts/package-demo-app.sh ausführen.' >&2
  exit 1
}
# XCTest must execute a signed runner. Local ad-hoc signing needs no certificate.
xcodebuild test -project AboLife.xcodeproj -scheme AboLife -destination 'platform=macOS' \
  -derivedDataPath work/xcode-quality -only-testing:AboLifeUITests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES "$@"
