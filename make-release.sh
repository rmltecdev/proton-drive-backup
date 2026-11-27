#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────
#
# make-release.sh — Release packaging for proton-drive-backup
#
# Builds the release tar ball FROM THE TAGGED COMMIT (never
# from the working tree — the v1.3.0 lesson: a tag pointing
# at a commit while edits sit uncommitted produces releases
# that miss a day's work), computes SHA-512 checksums, and
# generates a paste-ready release-notes draft.
#
# Publishing stays a DELIBERATE act: only --publish calls
# gh release create. Everything else is local, inspectable
# and reversible.
#
# Usage:
#   ./make-release.sh v1.3.0            # build + notes + checksums
#   ./make-release.sh v1.3.0 --publish  # additionally publish to GitHub
#
# Requires: git, tar, sha512sum, gh (only with --publish)
#
# Pipeline hygiene note (v1.3.0 lesson): this script runs
# under `set -o pipefail`. Never pipe a producer into an
# early-exiting consumer (`grep -m1`, `head`, ...): when the
# consumer stops reading, the producer dies of SIGPIPE (exit
# 141) and pipefail turns the WHOLE pipeline into a failure
# even though the match succeeded. Captured blobs are grepped
# from memory instead (`var=$(producer)` + `grep ... <<<"$var"`).
#
# ──────────────────────────────────────────────────────────

set -euo pipefail

# ───── Arguments ──────────────────────────────────────────

TAG="${1:?Usage: make-release.sh <tag> [--publish]}"
PUBLISH=false
[[ "${2:-}" == "--publish" ]] && PUBLISH=true

VER="${TAG#v}"

# ───── File manifest ──────────────────────────────────────
# Runtime: installer, main script, example config, locales.
# Docs:   README, FAQ, CHANGELOG — plus LICENSE (MIT must
#         ship with every distribution) and SECURITY.md
#         (users need the vulnerability contact).
# Everything else (MESSAGES.md, MANUAL_TESTS.md, test/,
# chartest.sh, extensions/) is contributor territory and
# stays in the repository.

RUNTIME_FILES=(
    "install.sh"
    "proton-drive-backup"
    "proton-drive-backup.cfg.example"
)
DOC_FILES=(
    "README.md"
    "FAQ.md"
    "CHANGELOG.md"
    "LICENSE"
    "SECURITY.md"
)

# ───── Preflight ──────────────────────────────────────────

command -v git  &>/dev/null || { echo "git not found"; exit 1; }
command -v tar  &>/dev/null || { echo "tar not found"; exit 1; }
command -v sha512sum &>/dev/null || { echo "sha512sum not found"; exit 1; }

# The tag must exist locally and point at a committed state
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
    || { echo "ERROR: tag $TAG does not exist (create it first: git tag -a $TAG -m ...)"; exit 1; }

[[ -z "$(git status --porcelain)" ]] \
    || echo "NOTE: working tree is dirty — building from tag $TAG, uncommitted changes are ignored by design."

# ───── Tagged blobs: capture once, grep from memory ───────
# Command substitution takes the FULL blob; the producer
# exits normally, no pipe, no pipefail hazard. The grep that
# follows works on an in-memory string — an early exit there
# can never kill an upstream process.

tagged_script=$(git show "$TAG:proton-drive-backup") \
    || { echo "ERROR: cannot read proton-drive-backup from tag $TAG"; exit 1; }

tagged_changelog=$(git show "$TAG:CHANGELOG.md") \
    || { echo "ERROR: cannot read CHANGELOG.md from tag $TAG"; exit 1; }

# Tag must match the VERSION inside the tagged script
tagged_version=$(grep -oP '^VERSION="\K[^"]+' <<<"$tagged_script") \
    || { echo "ERROR: could not extract VERSION= from tagged script"; exit 1; }
[[ "$tagged_version" == "$VER" ]] \
    || { echo "ERROR: tag $TAG carries VERSION=$tagged_version inside the script"; exit 1; }

# CHANGELOG must contain a dated section for this version
# ([v?] tolerates both heading styles: [1.3.0] / [v1.3.0])
changelog_date=$(grep -oP "^## \[v?$VER\] - \K[0-9]{4}-[0-9]{2}-[0-9]{2}" <<<"$tagged_changelog") \
    || { echo "ERROR: no '## [v$VER] - date' heading in tagged CHANGELOG.md"; exit 1; }

if [[ "$PUBLISH" == true ]]; then
    command -v gh &>/dev/null || { echo "gh CLI not found — required for --publish"; exit 1; }
    [[ -n "$(git ls-remote origin "refs/tags/$TAG" 2>/dev/null | awk '{print $1}')" ]] \
        || echo "NOTE: tag not pushed yet — run: git push origin $TAG"
fi

# ───── Staging: extract the tagged commit, select manifest ─

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

pkg_root="$stage/pkg/proton-drive-backup-$VER"
mkdir -p "$pkg_root"

# Extract tagged tree to a scratch dir (with prefix layout)
extract="$stage/extract"
mkdir -p "$extract"
git archive --format=tar --prefix="proton-drive-backup-$VER/" "$TAG" \
    | tar -x -C "$extract"

# Manifest check inside the TAGGED tree — a missing file in
# the manifest is a FAIL condition, never a silent skip
missing=0
for f in "${RUNTIME_FILES[@]}" "${DOC_FILES[@]}"; do
    [[ -f "$extract/proton-drive-backup-$VER/$f" ]] \
        || { echo "ERROR: $f missing in tag $TAG"; missing=1; }
done
# Locales are glob-discovered (any two-letter extension);
# zero locales found is a FAIL condition, not a silent skip.
# NOTE: the locale naming convention lives in TWO places
# (here and in test.sh) — change them together.
shopt -s nullglob
locales=("$extract"/proton-drive-backup-"$VER"/proton-drive-backup.[a-z][a-z])
shopt -u nullglob
(( ${#locales[@]} > 0 )) || { echo "ERROR: no locale files found in tag $TAG"; missing=1; }
(( missing == 1 )) && exit 1

# Copy the selection into the package root
(
    cd "$extract/proton-drive-backup-$VER"
    cp "${RUNTIME_FILES[@]}" "${DOC_FILES[@]}" \
       proton-drive-backup.[a-z][a-z] "$pkg_root/"
)

# ───── Build the tar ball ─────────────────────────────────

TARBALL="proton-drive-backup-$VER.tar.gz"
tar -czf "$TARBALL" -C "$stage/pkg" "proton-drive-backup-$VER"

# Contents self-verification: the tar ball must carry exactly
# the manifest plus locales — count is printed for the report
tar_count=$(tar -tzf "$TARBALL" | grep -vc '/$')
echo "Packaged: $TARBALL ($tar_count files)"

# ───── Generate checksums ──────────────────────────────────

sum_tarball=$(sha512sum "$TARBALL" | awk '{print $1}')
sum_script=$(sha512sum "$pkg_root/proton-drive-backup" | awk '{print $1}')
sum_installer=$(sha512sum "$pkg_root/install.sh" | awk '{print $1}')


# ───── Release notes draft ─────────────────────────────────

NOTES_FILE="RELEASE_NOTES_$VER.md"

# Pull the changelog section for this version: from its
# heading up to (excluding) the next version heading.
# index() treats the version heading as a literal string —
# dots and brackets in version names are not regex metachars.
awk -v ver="## [v$VER]" '
    index($0, ver) == 1 { in_section = 1; next }
    in_section && /^## \[/ { exit }
    in_section { print }
' <<<"$tagged_changelog" > "$stage/changelog_section.md"

[[ -s "$stage/changelog_section.md" ]] \
    || { echo "ERROR: changelog section extraction failed (empty)"; exit 1; }

cat > "$NOTES_FILE" <<HEADER
# Proton Drive Backup — $TAG

**Release date:** $changelog_date

## What's New

HEADER
cat "$stage/changelog_section.md" >> "$NOTES_FILE"
cat >> "$NOTES_FILE" <<QUICKSTART

## Installation

\`\`\`bash
curl -L -o /tmp/pdb-$VER.tar.gz \\
  https://github.com/rmltecdev/proton-drive-backup/releases/download/$TAG/proton-drive-backup-$VER.tar.gz
sha512sum /tmp/pdb-$VER.tar.gz     # compare with Checksums below
tar -xzf /tmp/pdb-$VER.tar.gz -C /tmp
cd /tmp/proton-drive-backup-$VER
./install.sh
\`\`\`

QUICKSTART
cat <<CHECKSUMS >> "$NOTES_FILE"
## SHA-512 Checksums

Verify before installing: \`sha512sum <downloaded-file>\`. A mismatch means an incomplete download or tampering — do not execute the file and report to rmltecdev@pm.me.

### Tar Ball

\`\`\`bash
sha512sum proton-drive-backup-$VER.tar.gz
$sum_tarball
\`\`\`

### Main Script

\`\`\`bash
sha512sum proton-drive-backup
$sum_script
\`\`\`

### Installer

\`\`\`bash
sha512sum install.sh
$sum_installer
\`\`\`
CHECKSUMS
cat >> "$NOTES_FILE" <<FOOTER

## License

MIT — see [LICENSE](https://github.com/rmltecdev/proton-drive-backup/blob/$TAG/LICENSE).
FOOTER

echo ""
echo "Release notes draft: $NOTES_FILE (review Features/Requirements before publishing)"

# ───── Publish (deliberate, explicit) ──────────────────────

if [[ "$PUBLISH" == true ]]; then
    gh release create "$TAG" "$TARBALL" \
        --title "$TAG" \
        --notes-file "$NOTES_FILE"
    echo "Published release $TAG."
else
    echo ""
    echo "Dry run only. To publish after reviewing the notes:"
    echo "  gh release create $TAG $TARBALL --title $TAG --notes-file $NOTES_FILE"
fi
