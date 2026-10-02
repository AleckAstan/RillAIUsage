#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
rill_app="$project_root/../Rill/.build/DerivedData/Build/Products/Debug/Rill.app"
if [[ ! -x "$rill_app/Contents/MacOS/Rill" || ! -x "$project_root/.build/release/RillAIUsage" ]]; then
    echo 'Build Rill and RillAIUsage first.' >&2
    exit 1
fi
preview_runtime="$(mktemp -d "${TMPDIR:-/tmp}/rill-aiusage-preview.XXXXXX")"
trap 'rm -rf "$preview_runtime"' EXIT
RILL_RUNTIME_DIR="$preview_runtime" RILL_AI_USAGE_DEMO=1 "$rill_app/Contents/MacOS/Rill" --config "$project_root/config.toml"
