#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────
#
# Smoke Test — proton-drive-backup
#
# Pre-commit gate: run this before every git push.
# Passes only when ALL critical checks are green.
# Exit code 0 = safe to commit.
#
# Usage:  ./smoketest.sh
#
# ──────────────────────────────────────────────────────────

set -uo pipefail

# ───── Configuration ──────────────────────────────────────

MAIN_SCRIPT="./proton-drive-backup"
LOC_FILE="./proton-drive-backup.en"
CFG_EXAMPLE="./proton-drive-backup.cfg.example"
README_FILE="./README.md"
CHANGELOG_FILE="./CHANGELOG.md"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# ───── Helpers ────────────────────────────────────────────

print_pass() {
    echo -e "  \033[32m●\033[0m PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_warn() {
    echo -e "  \033[93m▲\033[0m WARN: $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

print_fail() {
    echo -e "  \033[31m■\033[0m FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
    echo ""
    echo "── $1 ──"
}

# ═══ SECTION 1: File presence ════════════════════════════

section "Required files"

for f in "$MAIN_SCRIPT" "$LOC_FILE" "$CFG_EXAMPLE" \
         "$README_FILE" "$CHANGELOG_FILE"; do
    [[ -f "$f" ]] && print_pass "Exists: $f" || print_fail "Missing: $f"
done

[[ -x "$MAIN_SCRIPT" ]] && print_pass "Script is executable" \
                       || print_fail "Script not executable (chmod +x)"

# ═══ SECTION 2: Syntax check ══════════════════════════════

section "Bash syntax"

if bash -n "$MAIN_SCRIPT" 2>/dev/null; then
    print_pass "bash -n: no syntax errors"
else
    print_fail "bash -n: syntax errors found"
fi

if bash -n "$LOC_FILE" 2>/dev/null; then
    print_pass "Localization file: valid Bash"
else
    print_fail "Localization file: invalid Bash"
fi

# ═══ SECTION 3: Version consistency ═══════════════════════

section "Version metadata"

script_ver=$(grep -m1 -oP '^VERSION="\K[^"]+' "$MAIN_SCRIPT")
[[ -n "$script_ver" ]] && print_pass "Script version: v$script_ver" \
                       || print_fail "No VERSION found in script"

[[ "$script_ver" != *alpha* && "$script_ver" != *beta* ]] \
    && print_pass "No pre-release marker" \
    || print_fail "Version contains pre-release marker: $script_ver"

readme_ver=$(grep -m1 -oP '^\*\*[Vv]ersion:\*\* ?\K\S+' "$README_FILE")
if [[ -n "$readme_ver" ]]; then
    [[ "$readme_ver" == "v$script_ver" ]] && print_pass "README version matches" \
       || print_fail "README version mismatch: $readme_ver vs v$script_ver"
else
    print_warn "No version line found in README (pattern '**Version:**')"
fi

changelog_ver=$(grep -m1 -oP '^## \[\K[^\]]+' "$CHANGELOG_FILE")
if [[ -n "$changelog_ver" ]]; then
    [[ "$changelog_ver" == "$script_ver" ]] && print_pass "CHANGELOG version matches" \
       || print_fail "CHANGELOG mismatch: $changelog_ver vs $script_ver"
else
    print_fail "No '## [version]' heading in CHANGELOG"
fi

# ═══ SECTION 4: Build date sanity ═════════════════════════

section "Build date"

build_date=$(grep -m1 -oP '^BUILD_DATE="\K[^"]+' "$MAIN_SCRIPT")
today=$(date +%F)

if [[ "$build_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    if [[ "$build_date" > "$today" ]]; then
        print_fail "BUILD_DATE ($build_date) lies in the future (today: $today)"
    else
        print_pass "BUILD_DATE plausible: $build_date"
    fi
else
    print_fail "BUILD_DATE missing or not ISO format (YYYY-MM-DD)"
fi

# ═══ SECTION 5: Declared dependencies runnable ═══════════

section "Dependencies (runtime environment)"

# These are hard runtime dependencies declared in the script
for dep in proton-drive jq md5sum tar; do
    if command -v "$dep" &>/dev/null; then
        print_pass "Installed: $dep"
    else
        print_fail "Not installed: $dep (required by script)"
    fi
done

# numfmt is cosmetic-only: script degrades to raw bytes by design
if command -v numfmt &>/dev/null; then
    print_pass "Installed: numfmt (cosmetic sizes)"
else
    print_warn "numfmt not installed — sizes display raw (by design)"
fi

# ═══ SECTION 6: ShellCheck ════════════════════════════════

section "ShellCheck"

if command -v shellcheck &>/dev/null; then
    if shellcheck -S warning "$MAIN_SCRIPT" &>/dev/null; then
        print_pass "ShellCheck: clean"
    else
        print_fail "ShellCheck: findings (severity >= warning)"
    fi
else
    print_warn "ShellCheck not installed — skipped (mandatory before release)"
fi

# ═══ SECTION 7: Function definition guard ════════════════

section "Function definitions"

# Trap payload must resolve: every name referenced in a trap
# must have a top-level definition (the release_lock lesson).
for fn in $(grep -oP "^trap '\K[a-z_]+" "$MAIN_SCRIPT" | sort -u); do
    if grep -q "^${fn}()" "$MAIN_SCRIPT"; then
        print_pass "Trap target defined: $fn()"
    else
        print_fail "Trap references undefined function: $fn()"
    fi
done

# Core lifecycle pair must exist and be top-level (not nested)
for fn in acquire_lock release_lock progress_init progress_teardown \
           load_locale load_config cleanup; do
    if grep -q "^${fn}()" "$MAIN_SCRIPT"; then
        print_pass "Defined: $fn()"
    else
        print_fail "Missing or nested definition: $fn()"
    fi
done

# ═══ SECTION 8: Localization contract ═════════════════════

section "Localization alignment"

# Direction 1: every MSG[...] referenced by the script must exist in .en
# - accepts both assignment (MSG[key]=) and heredoc ('MSG[key]') forms
# - keys ending in '_' are dynamic composition prefixes (MSG[pfx_${var}])
#   and are validated separately below, not here
missing_keys=0
while read -r key; do
    grep -qE "MSG\[$key\]=|'MSG\[$key\]'" "$LOC_FILE" \
        || { print_fail "Missing in .en: $key"; missing_keys=1; }
done < <(grep -oP 'MSG\[\K[a-z_0-9]+' "$MAIN_SCRIPT" | grep -v '_$' | sort -u)
[[ $missing_keys -eq 0 ]] && print_pass "All script keys exist in .en"

# Dynamic key families: MSG[<prefix>_${VAR}] resolves at runtime.
# Validate against the option-value contract instead of static greps.
dyn_ok=0
for mode in trash delete; do
    grep -q "MSG\[mode_verb_$mode\]=" "$LOC_FILE" \
        || { print_fail "Missing dynamic family member: mode_verb_$mode"; dyn_ok=1; }
done
[[ $dyn_ok -eq 0 ]] && print_pass "Dynamic key family (mode_verb_*) complete"

# Direction 2: no corpse keys — except members of dynamic families
dyn_prefixes=$(grep -oP 'MSG\[\K[a-z_0-9]+(?=\$\{)' "$MAIN_SCRIPT" | sort -u)
corpses=0
while read -r key; do
    grep -q "MSG\[$key\]" "$MAIN_SCRIPT" && continue
    covered=0
    for dp in $dyn_prefixes; do
        [[ "$key" == "$dp"* ]] && { covered=1; break; }
    done
    [[ $covered -eq 0 ]] && { print_fail "Corpse key in .en: $key"; corpses=1; }
done < <(grep -oP 'MSG\[\K[a-z_0-9]+(?=\]=)' "$LOC_FILE" | sort -u)
[[ $corpses -eq 0 ]] && print_pass "No corpse keys in .en"

# Locale printf safety: no literal % outside %s placeholders
# (this replaces blanket SC2059 suppression with a real check)
bad_pct=$(grep -P '="(?:[^%]|%s)*%(?!s)[^"]*"' "$LOC_FILE" | grep -v '\$' || true)
if [[ -n "$bad_pct" ]]; then
    print_fail "Locale value contains non-%s percent escape:"
    echo "$bad_pct" | sed 's/^/      /'
else
    print_pass "No stray % escapes in locale values"
fi

# PAD_* widths must be pure numbers (type separation: locales
# carry VALUES, scripts own format strings)
while read -r padline; do
    key=$(echo "$padline" | grep -oP '^PAD_\K[A-Z_0-9]+(?==)')
    val=$(echo "$padline" | grep -oP '"\K[0-9]+(?=")')
    [[ -n "$val" ]] || print_fail "PAD_ value not numeric: $key"
done < <(grep '^PAD_' "$LOC_FILE")
print_pass "All PAD_ widths numeric"

# Templates must carry placeholders (pattern B contract)
tmpl_ok=0
while read -r line; do
    key=$(echo "$line" | grep -oP 'MSG\[\K[a-z_0-9]+(?=\])')
    if [[ "$line" == *%s* ]]; then
        tmpl_ok=$((tmpl_ok + 1))
    else
        print_fail "tmpl_ key without %s placeholder: $key"
    fi
done < <(grep 'MSG\[tmpl_' "$LOC_FILE")
[[ $tmpl_ok -gt 0 ]] && print_pass "$tmpl_ok template keys carry %s placeholders"

# ═══ SECTION 9: Configuration example contract ═══════════

section "Configuration example (.cfg.example)"

# Required variables must be present in the example
for var in SOURCE_DIRS REMOTE_BASE_PATH DELETE_MODE \
           UPLOAD_CONFLICT_STRATEGY CRON_INTERVAL_MINUTES KEEP_LOG_RUNS; do
    grep -q "^$var" "$CFG_EXAMPLE" && print_pass "Declared: $var" \
                                         || print_fail "Missing in .cfg.example: $var"
done

# CRON_INTERVAL must fit cron semantics:
# divisor of 60 (minute steps) or multiple of 60 (hour steps)
interval=$(grep -oP '^CRON_INTERVAL_MINUTES=\K[0-9]+' "$CFG_EXAMPLE")
if [[ -n "$interval" ]]; then
    if (( interval % 60 == 0 || 60 % interval == 0 )); then
        print_pass "CRON_INTERVAL_MINUTES=$interval fits cron semantics"
    else
        print_fail "CRON_INTERVAL_MINUTES=$interval fires irregularly (*/N over 0-59)"
    fi
else
    print_fail "CRON_INTERVAL_MINUTES not numeric in .cfg.example"
fi

# DELETE_MODE values are a contract, not free text
delete_mode=$(grep -oP '^DELETE_MODE="\K[a-z]+' "$CFG_EXAMPLE")
[[ "$delete_mode" == "trash" || "$delete_mode" == "delete" ]] \
    && print_pass "DELETE_MODE valid: $delete_mode" \
    || print_fail "DELETE_MODE invalid: '$delete_mode' (must be trash|delete)"

# KEEP_LOG_RUNS sane bound
keep_runs=$(grep -oP '^KEEP_LOG_RUNS=\K[0-9]+' "$CFG_EXAMPLE")
[[ "$keep_runs" -ge 1 && "$keep_runs" -le 100 ]] \
    && print_pass "KEEP_LOG_RUNS in sane range: $keep_runs" \
    || print_fail "KEEP_LOG_RUNS out of range: $keep_runs"

# XDG convention: enabled (uncommented) SOURCE_DIRS defaults must
# match the uppercase user-dirs names. Personal lowercase configs
# are legitimate — this check ONLY guards the tracked example.
# NOTE: upon migration to lowercase-dirs systems the release default
# may change deliberately; adjust the pattern list then.
xdg_bad=0
while read -r entry; do
    [[ "$entry" =~ ^(Documents|Downloads|Music|Pictures|Public|Templates|Videos)$ ]] \
        || { print_warn "SOURCE_DIRS default not XDG-conventional: $entry"; xdg_bad=1; }
done < <(sed -n '/^SOURCE_DIRS=(/,/^)/p' "$CFG_EXAMPLE" \
         | grep -oP '"\K[^"]+' )
[[ $xdg_bad -eq 0 ]] && print_pass "SOURCE_DIRS defaults follow XDG naming"

# ═══ SECTION 10: Script hygiene ═══════════════════════════

section "Script hygiene"

# set -uo pipefail is project minimum (-e deliberately omitted)
grep -q '^set -uo pipefail' "$MAIN_SCRIPT" \
    && print_pass "Error handling header present" \
    || print_fail "Missing 'set -uo pipefail'"

# No on-the-fly tput calls in the draw path (geometry cache contract)
draw_tput=$(sed -n '/^show_progress_bar()/,/^}/p' "$MAIN_SCRIPT" \
            | grep -v '^\s*#' | grep -c 'tput ' || true)
[[ "$draw_tput" -eq 0 ]] \
    && print_pass "Progress draw path free of tput calls" \
    || print_fail "show_progress_bar measures geometry (cache contract violated)"

# No 'proton-drive version' outside show_version (network-call hygiene)
ver_calls=$(grep -n 'proton-drive version' "$MAIN_SCRIPT" | wc -l)
ver_calls_in_fn=$(sed -n '/^show_version()/,/^}/p' "$MAIN_SCRIPT" \
                   | grep -c 'proton-drive version' || true)
[[ "$ver_calls" -eq "$ver_calls_in_fn" ]] \
    && print_pass "CLI version call confined to show_version()" \
    || print_fail "proton-drive version called outside show_version (startup latency)"

# TZ harmonization: run stamps in UTC
grep -q "date -u '+%Y%m%d" "$MAIN_SCRIPT" \
    && print_pass "Archive stamps use UTC" \
    || print_warn "UTC archive stamping not confirmed — verify manually"

# ═══ SECTION 11: Git commit message mood (uncommitted check) ═══

section "Commit message"

if [[ -x "$(command -v git)" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
    last_msg=$(git log -1 --pretty=%s)
    if [[ "$last_msg" =~ ^(Added|Fixed|Updated|Removed|Changed) ]] && [[ "$last_msg" != *. ]]; then
        print_pass "Last commit message follows mood convention"
    else
        print_warn "Commit message deviates: '$last_msg'"
    fi
else
    print_warn "Not a git repository — commit check skipped"
fi

# ═══ SUMMARY ══════════════════════════════════════════════

echo ""
echo "══ Smoke Test Summary ══"
echo "  Passed:    $PASS_COUNT"
echo "  Warnings:  $WARN_COUNT"
echo "  Failures:  $FAIL_COUNT"

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo ""
    echo "  ■ COMMIT BLOCKED — fix failures before pushing."
    exit 1
elif [[ $WARN_COUNT -gt 0 ]]; then
    echo ""
    echo "  ▲ Safe to commit — review warnings above."
    exit 0
else
    echo ""
    echo "  ● All checks passed."
    exit 0
fi
