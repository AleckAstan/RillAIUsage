#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/build.sh"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin" "$root/.build/releases"
cp "$root/bin/RillAIUsage" "$stage/bin/"
cp "$root/extension.toml" "$root/config.toml" "$root/README.md" "$stage/"
cp -R "$root/Resources" "$stage/"
cp -R "$root/ThirdParty" "$stage/"
archive="$root/.build/releases/rill-plugin-macos-arm64.zip"
ditto -c -k "$stage" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "$archive"
