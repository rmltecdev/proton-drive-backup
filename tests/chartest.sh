#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
#
# chartest.sh — unset behavior matrix for associative arrays
#
# PURPOSE
#   Measurement tool, not a gate. Documents which key
#   characters defeat `unset "ARR[$key]"` on the CURRENT
#   shell. Measured results:
#     bash 5.1.16 (MEL-0498):  ] ' " \   fail
#     bash 5.2.21 (FRA-0006):  ' " \     fail
#   Bracket removal was fixed in bash 5.2; quoting characters
#   fail in every bash version tested to date. Assignment
#   (ARR["$k"]=v) and expansion (${ARR[$k]+x}) are safe on
#   all versions — only unset parses the subscript itself.
#
# USAGE
#   ./test/chartest.sh   — prints PASS/FAIL per character class.
#   A FAIL is a property of the shell, not of this script.
#
# RELATION TO THE PRODUCT
#   retry_queue_remove() rebuilds the array instead of using
#   unset and is therefore immune to the entire matrix.
#   test.sh enforces that rule statically (Section 13); this
#   script explains WHY it exists. Re-run when re-evaluating
#   the declared bash minimum (4.2) or when targeting a new
#   deployment platform.
#
# ──────────────────────────────────────────────────────────

run_test() {
    local label="$1" key="$2"
    declare -A T=()
    T["$key"]="value"

    # Harness self-verification: a key that never entered the
    # array proves the TEST is broken, not the unset
    if [[ -z "${T["$key"]+x}" ]]; then
        printf 'HARNESS BROKEN [%s]: key not even set\n' "$label"
        return
    fi

    unset "T[$key]"

    if [[ -n "${T["$key"]+x}" ]]; then
        printf 'FAIL  %-11s [%s]\n' "$label" "$key"
    else
        printf 'PASS  %-11s [%s]\n' "$label" "$key"
    fi
}

run_test "space"       "a b c.mp4"
run_test "parens"      "Movie (2012).mp4"
run_test "en-dash"     "Bomb – A.mkv"
run_test "apostrophe"  "Kubrick's.mkv"
run_test "dquote"      'Say "Hi".mkv'
run_test "backslash"   'back\slash.mp4'
run_test "brackets"    "Film (2012) [EN].mkv"
run_test "curly"       "Film {EN}.mkv"