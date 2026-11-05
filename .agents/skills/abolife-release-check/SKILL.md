---
name: abolife-release-check
description: Validate AboLife's native and web contracts, quality gates, isolated visual states and local packaging before a release; report explicit skips and protect the existing SQLite data. Does not publish or deploy.
---

Read AGENTS.md and TESTING.md. Establish git status and separate the user's prior work from this task. Never stage the entire tree merely to produce a tidy release commit. Check VERSION, MARKETING_VERSION and package-local-app.sh agree.

Run scripts/check-quality.py and scripts/check-native.sh. Use the existing GRDB checkout, or resolve the pinned Xcode package first; never substitute a new persistence framework. Report the actual All tests count including skips, plus Node results. The fixture/schema comparison is part of check-native.sh.

For UI work run with ABOLIFE_RENDER_DIR pointing under ignored work/ and inspect the images. Use scripts/check-ui.sh only in an unlocked macOS login with UI automation permission. Its XCUIApplication must set ABOLIFE_DEMO=1 before launch. Distinguish built UI tests from executed UI tests and component renders from window screenshots.

For data/performance changes set ABOLIFE_PERFORMANCE_REPORT under work/ and run EvolutionPerformanceTests without competing builds. Read the fixture size, build configuration, median/P95 and state-publication counts. Do not claim FPS, launch or resident-memory improvements from repository microbenchmarks. Use Xcode Instruments when live evidence is needed.

Build the actual Xcode scheme (new source files must be included in project.pbxproj) and run scripts/package-local-app.sh for a local ad-hoc signed bundle. Check signature verification; no notarization claim. UI and performance fixtures must never open AboLife-Main or import credentials. Schema changes require an additive named migration, pre-upgrade consistent backup and round-trip tests; do not edit historical migrations.

Run scripts/check-publication.py; this is a local scan, not publication authorization. List real failures, remaining legacy lint findings and external prerequisites. Request release/deploy approval only if publishing has been requested and the concrete local result is ready. This skill alone never authorizes pushing, changing visibility, transmitting credentials or replacing user data.
