#!/usr/bin/env bash

# ──────────────────────────────────────────────────────────
#
# Smoke Test — proton-drive-backup
#
# Pre-commit gate: run this before every git push.
# Passes only when ALL critical checks are green.
# Exit code 0 = safe to commit.
#
# Usage:  ./test/test.sh
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

readme_ver=$(grep -m1 -oP '^[Vv]ersion: \K\S+' "$README_FILE")
if [[ -n "$readme_ver" ]]; then
    [[ "$readme_ver" == "v$script_ver" ]] && print_pass "README version matches" \
       || print_fail "README version mismatch: $readme_ver vs v$script_ver"
else
    print_fail "No version line found in README (pattern 'Version:')"
fi

changelog_ver=$(grep -m1 -oP '^## \[\K[^\]]+' "$CHANGELOG_FILE")
if [[ -n "$changelog_ver" ]]; then
    [[ "$changelog_ver" == "$script_ver" ]] && print_pass "CHANGELOG version matches" \
       || print_fail "CHANGELOG mismatch: $changelog_ver vs $script_ver"
else
    print_fail "No '## [version]' heading in CHANGELOG"
fi



# ═══ SECTION 4: Build date sanity + cross-file consistency ═══

section "Build date"

# Main script

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

# ── Cross-file date consistency ──
# The release date is a contract between three files, same as the
# version number: script BUILD_DATE, CHANGELOG heading date, and
# the README date must agree. A mismatch means one file was
# forgotten during the release bump — the same class of drift the
# version checks in Section 3 catch.

# CHANGELOG: first "## [version] - YYYY-MM-DD" heading
changelog_date=$(grep -m1 -oP '^## \[[^]]+\] - \K[0-9]{4}-[0-9]{2}-[0-9]{2}' \
                "$CHANGELOG_FILE")

if [[ -n "$changelog_date" ]]; then
    if [[ -n "$build_date" ]]; then
        [[ "$changelog_date" == "$build_date" ]] \
            && print_pass "CHANGELOG date matches script BUILD_DATE" \
            || print_fail "Date mismatch: CHANGELOG $changelog_date vs BUILD_DATE $build_date"
    else
        print_fail "Cannot compare: BUILD_DATE missing in script"
    fi
else
    print_fail "No '## [version] - date' heading found in CHANGELOG"
fi

# README: date line next to the version line
readme_date=$(grep -m1 -oP '^[Bb]uild [Dd]ate: \K[0-9]{4}-[0-9]{2}-[0-9]{2}' \
              "$README_FILE")

if [[ -n "$readme_date" ]]; then
    if [[ -n "$build_date" ]]; then
        [[ "$readme_date" == "$build_date" ]] \
            && print_pass "README date matches script BUILD_DATE" \
            || print_fail "Date mismatch: README $readme_date vs BUILD_DATE $build_date"
    else
        print_fail "Cannot compare: BUILD_DATE missing in script"
    fi
else
    print_fail "No date line found in README (pattern 'Date:') — cross-check skipped"
fi



# ═══ SECTION 5: Declared dependencies runnable ═══════════

section "Dependencies (runtime environment)"

# These are hard runtime dependencies declared in the script
for dep in proton-drive jq md5sum tar curl; do
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



# ═══ SECTION 8: Localization contract (all locales) ══════

section "Localization alignment"

# Discovery: ALL two-letter locale files; fresh MSG scope per file —
# sourcing several files into one associative array would leak
# earlier keys and mask gaps.
mapfile -t locale_files < <(compgen -G "./proton-drive-backup.[a-z][a-z]")

if [[ ${#locale_files[@]} -eq 0 ]]; then
    print_fail "No localization files found"
else
    for loc_file in "${locale_files[@]}"; do
        lang="${loc_file##*.}"
        unset MSG
        declare -A MSG
        # shellcheck disable=SC1090
        source "$loc_file"

        # ── Key parity: every key in .en must exist here ──
        parity_bad=0
        while read -r key; do
            [[ -n "${MSG[$key]+x}" ]] \
                || { print_fail "[$lang] Missing key: $key"; parity_bad=1; }
        done < <(grep -oP 'MSG\[\K[a-z_0-9]+(?=\]=)' "$LOC_FILE" | sort -u)
        [[ $parity_bad -eq 0 ]] && print_pass "[$lang] Key parity vs .en"

        # ── PAD_* present and numeric ──
        pad_bad=0
        while read -r padline; do
            key=$(printf '%s\n' "$padline" | grep -oP '^PAD_\K[A-Z_0-9]+(?==)')
            val=$(printf '%s\n' "$padline" | grep -oP '=\K"[0-9]+"')
            [[ -n "$val" ]] || { print_fail "[$lang] PAD_ value not numeric: $key"; pad_bad=1; }
        done < <(grep '^PAD_' "$loc_file")
        [[ $pad_bad -eq 0 ]] && print_pass "[$lang] All PAD_ widths numeric"

        # ── Locale printf safety: no literal % outside %s ──
        bad_pct=$(grep -P '%(?!s)' "$loc_file" \
                  | grep 'MSG\[' | grep -v 'tmpl_\|fail_config_syntax\|fail_config_hint' || true)
        if [[ -n "$bad_pct" ]]; then
            print_fail "[$lang] Locale value contains non-%s percent escape"
            printf '%s\n' "$bad_pct" | sed 's/^/      /'
        else
            print_pass "[$lang] No stray % escapes in locale values"
        fi

        # ── Templates must carry placeholders (pattern B contract) ──
        tmpl_count=0
        tmpl_bad=0
        while read -r key; do
            tmpl_count=$((tmpl_count + 1))
            [[ -n "${MSG[$key]}" ]] && [[ "${MSG[$key]}" != *%s* ]] \
                && { print_fail "[$lang] tmpl_ key without %s: $key"; tmpl_bad=1; }
        done < <(grep -oP 'MSG\[\K(tmpl_[a-z_0-9]+)(?=\]=)' "$loc_file" | sort -u)
        [[ $tmpl_bad -eq 0 ]] && [[ $tmpl_count -gt 0 ]] \
            && print_pass "[$lang] $tmpl_count template keys carry %s"

        # ── Dynamic families complete in THIS locale ──
        dyn_bad=0
        for mode in trash delete; do
            [[ -n "${MSG[mode_verb_$mode]+x}" ]] \
                || { print_fail "[$lang] Missing family member: mode_verb_$mode"; dyn_bad=1; }
        done
        [[ $dyn_bad -eq 0 ]] && print_pass "[$lang] Dynamic key family (mode_verb_*) complete"
    done
fi

# Corpse keys: keys in a locale unused by the main script — except
# members of dynamic families (resolved at runtime via ${VAR}).
mapfile -t dyn_prefixes < <(grep -oP 'MSG\[\K[a-z_0-9]+(?=\$\{)' "$MAIN_SCRIPT" | sort -u)

for loc_file in "${locale_files[@]}"; do
    lang="${loc_file##*.}"
    corpse_bad=0
    while read -r key; do
        grep -q "MSG\[$key\]" "$MAIN_SCRIPT" && continue
        covered=0
        for dp in "${dyn_prefixes[@]}"; do
            [[ "$key" == "$dp"* ]] && { covered=1; break; }
        done
        [[ $covered -eq 0 ]] && { print_fail "[$lang] Corpse key: $key"; corpse_bad=1; }
    done < <(grep -oP 'MSG\[\K[a-z_0-9]+(?=\]=)' "$loc_file" | sort -u)
    [[ $corpse_bad -eq 0 ]] && print_pass "[$lang] No corpse keys"
done



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



# ═══ SECTION 10: CLI options ↔ --help parity ═════════════

section "CLI/help parity"

# The option set is a contract between two places: what
# parse_args() accepts in the main script and what the localized
# help_text heredoc documents. The option NAMES are identical in
# every locale by design — a localized flag spelling would be a
# different program. Drift between either side is the classic
# CLI bug: an implemented option nobody can discover, or a
# documented option that silently does nothing.

# Comments stripped before scanning: dead-code doc-drift in
# commented-out cases must not satisfy the parity check.
parse_body=$(sed -n '/^parse_args()/,/^}/p' "$MAIN_SCRIPT" | grep -v '^[[:space:]]*#')
args_opts=$(grep -oP -- '--[a-z][a-z-]+' <<< "$parse_body" | sort -u)

# Gate self-verification: the args side must yield options —
# empty discovery is a FAIL condition, never a silent pass.
if [[ -z "$args_opts" ]]; then
    print_fail "No options discovered in parse_args() — extraction pattern broken?"
fi

if [[ -n "$args_opts" ]]; then
    print_pass "Option discovery: $(wc -l <<< "$args_opts") options in parse_args()"
fi

for loc_file in "${locale_files[@]}"; do
    lang="${loc_file##*.}"

    # Extract the help_text heredoc BODY (between <<'EOF' and EOF)
    help_body=$(sed -n "/help_text\]/,/^EOF$/p" "$loc_file" | head -n -1)

    # Gate self-verification — the help side needs options too;
    # a broken extraction or a missing heredoc must never
    # masquerade as parity.
    help_opts=$(grep -oP -- '--[a-z][a-z-]+' <<< "$help_body" | sort -u)
    if [[ -z "$help_opts" ]]; then
        print_fail "[$lang] No options discovered in help_text — extraction pattern broken?"
        continue
    fi

    # comm needs two FILE operands — process substitution supplies
    # them; here-strings would collide on stdin (the "missing
    # operand" lesson).
    only_in_args=$(comm -23 <(printf '%s\n' "$args_opts") <(printf '%s\n' "$help_opts"))
    only_in_help=$(comm -13 <(printf '%s\n' "$args_opts") <(printf '%s\n' "$help_opts"))

    parity_bad=0

    while read -r opt; do
        [[ "$opt" == "--" || -z "$opt" ]] && continue
        print_fail "[$lang] Implemented but undocumented in --help: $opt"
        parity_bad=1
    done <<< "$only_in_args"

    while read -r opt; do
        [[ "$opt" == "--" || -z "$opt" ]] && continue
        print_fail "[$lang] Documented in --help but not implemented: $opt"
        parity_bad=1
    done <<< "$only_in_help"

    [[ $parity_bad -eq 0 ]] \
        && print_pass "[$lang] parse_args() and --help option sets identical"
done



# ═══ SECTION 11: Script hygiene ═══════════════════════════

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



# ═══ SECTION 12: Git commit message mood (uncommitted check) ═══

section "Commit message"

if [[ -x "$(command -v git)" ]] && git rev-parse --is-inside-work-tree &>/dev/null; then
    # Merge commits carry git-generated subject lines outside the
    # mood convention — the last AUTHORED commit is the review target
    last_msg=$(git log --author-date-order -1 --no-merges --pretty=%s)
    if [[ -z "$last_msg" ]]; then
        print_warn "No non-merge commit found"
    elif [[ "$last_msg" =~ ^(Added|Fixed|Updated|Removed|Changed) ]] && [[ "$last_msg" != *. ]]; then
        print_pass "Last authored commit follows mood convention"
    else
        print_warn "Commit message deviates: '$last_msg'"
    fi
else
    print_warn "Not a git repository — commit check skipped"
fi





# ═══ SUMMARY ══════════════════════════════════════════════

echo ""
echo "══ Smoke Test Summary ══"
echo "   Passed:    $PASS_COUNT"
echo "   Warnings:  $WARN_COUNT"
echo "   Failures:  $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    print_fail "COMMIT BLOCKED — fix failures before pushing.\n"
    exit 1
elif [[ $WARN_COUNT -gt 0 ]]; then
    print_warn "Safe to commit — review warnings above.\n"
    exit 0
else
    print_pass "All checks passed. Safe to commit.\n"
    exit 0
fi
