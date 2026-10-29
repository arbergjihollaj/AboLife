#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work outputs
ABOLIFE_STAGE_PARENT=$(mktemp -d "$PWD/work/homelab-package.XXXXXX")
trap 'rm -rf "$ABOLIFE_STAGE_PARENT"' EXIT
ABOLIFE_STAGE="$ABOLIFE_STAGE_PARENT/AboLife-Homelab"
mkdir -p "$ABOLIFE_STAGE/web" "$ABOLIFE_STAGE/AboLife/Features/Calendar" outputs
cp .dockerignore "$ABOLIFE_STAGE/"
for source in CalendarModels.swift ModuleStudyPlanner.swift StudyPlannerEngine.swift; do
  cp "AboLife/Features/Calendar/$source" "$ABOLIFE_STAGE/AboLife/Features/Calendar/"
done
for source in package.json server.mjs state.mjs news.mjs planner.mjs backup.mjs schema.json Dockerfile Dockerfile.homelab compose.yaml .env.example .dockerignore setup-homelab.sh README.md; do
  cp "web/$source" "$ABOLIFE_STAGE/web/"
done
cp -R web/public web/planner "$ABOLIFE_STAGE/web/"
tar -czf "$PWD/outputs/AboLife-0.4-Homelab.tar.gz" -C "$ABOLIFE_STAGE_PARENT" AboLife-Homelab
printf 'Homelab-Paket: %s\n' "$PWD/outputs/AboLife-0.4-Homelab.tar.gz"
