#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
swift build --package-path "$project_root" -c release

mkdir -p "$project_root/bin"
cp "$project_root/.build/release/RillAIUsage" "$project_root/bin/RillAIUsage"
