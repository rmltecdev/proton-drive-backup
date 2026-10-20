#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
#
# deploy.sh — transport with verifiable build identity
#
# PURPOSE
#   Version numbers classify releases; they say nothing about
#   the code BETWEEN releases. On 2026-10-17 a production run
#   executed stale code carrying the same version string as
#   the fixed repo — invisible to every version-based check.
#   This script makes the deployed copy identifiable: it
#   stamps the git describe token into BUILD_ID, so every
#   log line of the deployed instance names its exact code
#   state.
#
# USAGE
#   ./test/deploy.sh [TARGET]
#   TARGET   installation path (default: ~/.local/bin)
#
# WHEN TO RUN
#   1. test.sh green (all sections, no FAILs)
#   2. changes committed (the script REFUSES dirty trees —
#      production runs may only start from code that exists
#      in git)
#   3. before starting any run of productive workload
#
# WHAT IT DOES
#   - Refuses dirty working trees
#   - Stamps BUILD_ID into the COPY (the repo keeps "unset";
#     the stamp never dirties the working tree)
#   - Installs atomically (temp file + mv — a running
#     instance never sees its own binary change mid-flight)
#   - Appends a SHA-512 line to the deployment manifest
#     (~/.local/state/proton-drive-backup.deploys), giving
#     M-19 (deployment verification) its input
#
# RELATION TO test.sh — deliberate separation of lifecycles
#   test.sh gates COMMITS (repo state), deploy.sh gates
#   TRANSPORT (installed state). They are never merged: a
#   deployment is a release action, a smoke test is a
#   pre-commit obligation. The overlap is covered from the
#   other side: the metadata section of test.sh verifies the
#   BUILD_ID slot contract on the repo copy.
#
# ──────────────────────────────────────────────────────────

set -euo pipefail

MAIN_SCRIPT="./proton-drive-backup"
TARGET_DIR="${1:-$HOME/.local/bin}"
MANIFEST="$HOME/.local/state/proton-drive-backup.deploys"

cd "$(git rev-parse --show-toplevel)"

[[ -f "$MAIN_SCRIPT" ]] || { echo "REFUSING: $MAIN_SCRIPT not found" >&2; exit 1; }

# Production code must be committed code
if [[ -n "$(git status --porcelain)" ]]; then
    echo "REFUSING: working tree is dirty (uncommitted changes):" >&2
    git status --short >&2
    exit 1
fi

BUILD_ID=$(git describe --tags --always)

install -m 755 "$MAIN_SCRIPT" "$TARGET_DIR/proton-drive-backup.tmp"
sed -i "s/^BUILD_ID=\"unset\"/BUILD_ID=\"$BUILD_ID\"/" \
    "$TARGET_DIR/proton-drive-backup.tmp"
mv "$TARGET_DIR/proton-drive-backup.tmp" "$TARGET_DIR/proton-drive-backup"

mkdir -p "$(dirname "$MANIFEST")"
sha512sum "$TARGET_DIR/proton-drive-backup" >> "$MANIFEST"
echo "Deployed $BUILD_ID"
echo "Verify anytime:  sha512sum $TARGET_DIR/proton-drive-backup"
