#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ABOLIFE_PROJECT_DIR="$PWD"
if [ -z "${ABOLIFE_GRDB_CHECKOUT:-}" ]; then
  for candidate in "$HOME/Library/Developer/Xcode/DerivedData"/AboLife-*/SourcePackages/checkouts/GRDB.swift; do
    if [ -f "$candidate/Package.swift" ]; then export ABOLIFE_GRDB_CHECKOUT="$candidate"; break; fi
  done
fi
if [ -z "${ABOLIFE_GRDB_CHECKOUT:-}" ]; then
  echo 'GRDB-Checkout fehlt. Einmal in Xcode Pakete auflösen oder ABOLIFE_GRDB_CHECKOUT setzen.' >&2
  exit 1
fi
mkdir -p work/native-harness work/cache
ln -sfn ../../AboLife work/native-harness/Sources
ln -sfn ../../AboLifeTests work/native-harness/Tests
cat > work/native-harness/Package.swift <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription
import Foundation
let package = Package(name: "AboLife", platforms: [.macOS(.v14)], products: [.executable(name: "AboLife", targets: ["AboLife"])], dependencies: [.package(path: ProcessInfo.processInfo.environment["ABOLIFE_GRDB_CHECKOUT"]!)], targets: [.executableTarget(name: "AboLife", dependencies: [.product(name: "GRDB", package: "GRDB.swift")], path: "Sources", exclude: ["Assets.xcassets"]), .testTarget(name: "AboLifeTests", dependencies: ["AboLife"], path: "Tests")])
SWIFT
export CLANG_MODULE_CACHE_PATH="$ABOLIFE_PROJECT_DIR/work/cache"
export ABOLIFE_NATIVE_FIXTURE="$ABOLIFE_PROJECT_DIR/work/native-contract.json"
export ABOLIFE_PLAN_FIXTURE="$ABOLIFE_PROJECT_DIR/work/planned-workout-contract.json"
export ABOLIFE_WEB_FIXTURE="$ABOLIFE_PROJECT_DIR/work/web-contract.json"
export ABOLIFE_SCHEMA_FIXTURE="$ABOLIFE_PROJECT_DIR/work/schema-verified.json"
swiftc -O -module-cache-path "$PWD/work/cache" AboLife/Features/Calendar/CalendarModels.swift AboLife/Features/Calendar/ModuleStudyPlanner.swift AboLife/Features/Calendar/StudyPlannerEngine.swift web/planner/main.swift -o work/abolife-planner
export ABOLIFE_PLANNER_BINARY="$PWD/work/abolife-planner"
# Generate the web side first; the native contract is checked again after Swift exports it.
if [ -f "$ABOLIFE_NATIVE_FIXTURE" ]; then
  node --test web/test/*.test.mjs > work/web-tests.log 2>&1
else
  env -u ABOLIFE_NATIVE_FIXTURE node --test web/test/*.test.mjs > work/web-tests.log 2>&1
fi
swift test --package-path work/native-harness --disable-sandbox --cache-path "$ABOLIFE_PROJECT_DIR/work/spm-cache" --scratch-path "$ABOLIFE_PROJECT_DIR/work/swift-build" --manifest-cache local > work/swift-tests.log 2>&1
cmp web/schema.json work/schema-verified.json
node --test web/test/*.test.mjs > work/web-tests.log 2>&1
printf 'Native tests: '
grep -E 'Executed [0-9]+ tests' work/swift-tests.log | tail -1
cat work/web-tests.log | tail -9
