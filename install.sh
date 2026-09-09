#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
#
#  Proton Drive Backup — Installer
#
# ──────────────────────────────────────────────────────────────────────
#
# Purpose   Install the Proton Drive Backup utility.
#
# Author    Copyright (c) 2026 RML Tec Dev
#           Contributions and feedback are welcome via rmltecdev@pm.me
#
# License   Licensed under the MIT License
#
# ──────────────────────────────────────────────────────────────────────



set -euo pipefail

readonly PROGNAME="proton-drive-backup"
readonly VERSION="1.0.0"  # keep in sync with main script (smoke test)

# Determine script source directory (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration follows the XDG contract of the main script:
# the installer pre-seeds the same path the script aborts on if missing.
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/${PROGNAME}"
CONFIG_FILE="${CONFIG_DIR}/${PROGNAME}.cfg"



# ───── Utility Functions ──────────────────────────────────────────────

log_info() {
    printf "  %b✓%b %s\n" "\033[32m" "\033[0m" "$*"
}

log_warn() {
    printf "  %b⚠%b %s\n" "\033[33m" "\033[0m" "$*"
}

log_error() {
    printf "  %b✗%b %s\n" "\033[31m" "\033[0m" "$*" >&2
}

check_command() {
    command -v "$1" &>/dev/null
}



# ───── Dependency Check ───────────────────────────────────────────────

check_dependencies() {
    local -a missing_required=()

    echo "Checking dependencies..."

    # Required — abort if missing
    check_command proton-drive   || missing_required+=("proton-drive")
    check_command jq             || missing_required+=("jq")
    check_command md5sum         || missing_required+=("md5sum")
    check_command tar            || missing_required+=("tar")

    if [[ ${#missing_required[@]} -gt 0 ]]; then
        for cmd in "${missing_required[@]}"; do
            log_error "Missing: ${cmd}"
        done
        log_error "Install missing packages and rerun the installer."
        exit 1
    fi

    log_info "Core dependencies satisfied."
    echo ""
}



# ───── Installation Target Detection ──────────────────────────────────

detect_install_target() {
    local target=""

    # Check if ~/.local/bin exists and is in PATH
    if [[ -d "${HOME}/.local/bin" ]] && echo "$PATH" | grep -q "${HOME}/.local/bin"; then
        target="${HOME}/.local/bin"
    # Check if ~/bin exists and is in PATH
    elif [[ -d "${HOME}/bin" ]] && echo "$PATH" | grep -q "${HOME}/bin"; then
        target="${HOME}/bin"
    else
        # Default to ~/.local/bin (will need PATH setup if not present)
        target="${HOME}/.local/bin"
    fi

    printf "%s" "${target}"
}

add_to_path() {
    local target="$1"
    local shell_rc=""

    # Detect shell
    case "${SHELL##*/}" in
        bash)
            shell_rc="${HOME}/.bashrc"
            ;;
        zsh)
            shell_rc="${HOME}/.zshrc"
            ;;
        *)
            shell_rc="${HOME}/.profile"
            ;;
    esac

    # Check if path is already there
    if grep -q "export PATH=\"\$PATH:${target}\"" "${shell_rc}" 2>/dev/null; then
        return 0
    fi

    # Add export line
    cat >> "${shell_rc}" <<EOF

# Added by proton-drive-backup installer ($(date '+%Y-%m-%d'))
export PATH="\$PATH:${target}"
EOF

    log_info "Added ${target} to PATH in ${shell_rc}"
    echo ""
    log_warn "Please restart your shell or run: source ${shell_rc}"
}



# ───── Privilege Handling ─────────────────────────────────────────────

# Under sudo, HOME points to /root — resolve the invoking user's home
# so the config is seeded where the actual user (and the script) finds it.
resolve_user_home() {
    local home_dir

    if [[ -n "${SUDO_USER:-}" ]]; then
        home_dir="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
    else
        home_dir="${HOME}"
    fi

    printf "%s" "${home_dir:-${HOME}}"
}



# ───── File Installation ──────────────────────────────────────────────

install_files() {
    local target_dir="$1"
    local config_dir="$2"

    echo "Installing files to ${target_dir}..."

    # Create directory if needed
    mkdir -p "${target_dir}"

    # Copy main script
    cp -f "${SCRIPT_DIR}/${PROGNAME}" "${target_dir}/${PROGNAME}"
    chmod +x "${target_dir}/${PROGNAME}"

    # Copy localization files — two-letter language suffixes only
    # (.en, .de, ...); excludes .cfg.example and repo metadata.
    # Glob stays OUTSIDE quotes so it expands.
    local locale_file

    for locale_file in "${SCRIPT_DIR}/${PROGNAME}".[a-z][a-z]; do
        if [[ -f "${locale_file}" ]]; then
            cp -f "${locale_file}" "${target_dir}/"
        fi
    done

    # Install config ONLY if absent — updates never overwrite user
    # settings. Seeded into the same XDG path the main script reads.
    if [[ ! -f "${config_dir}/${PROGNAME}.cfg" ]]; then
        mkdir -p "${config_dir}"
        cp "${SCRIPT_DIR}/${PROGNAME}.cfg.example" "${config_dir}/${PROGNAME}.cfg"
        log_info "Configuration created: ${config_dir}/${PROGNAME}.cfg"
        echo "  Adjust the values to your system before first run."
    else
        log_info "Existing configuration preserved: ${config_dir}/${PROGNAME}.cfg"
    fi

    log_info "Files installed successfully."
}



# ───── Usage ──────────────────────────────────────────────────────────

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install proton-drive-backup to your system.

OPTIONS:
    -h, --help          Show this help message
    -t, --target DIR    Specify installation directory (default: auto-detect)
    --sysadmin          Install system-wide to /usr/local/bin (requires sudo)

EXAMPLES:
    ./install.sh                          # Auto-detect target
    ./install.sh -t ~/my_scripts          # Custom target
    ./install.sh --sysadmin               # System-wide installation

NOTES:
    • User installation (~/.local/bin or ~/bin) requires no sudo
    • System installation (/usr/local/bin) requires elevated privileges
    • After installation, restart your shell if the target wasn't in \$PATH
EOF
}



# ───── Main ───────────────────────────────────────────────────────────

main() {
    local target_dir=""
    local sysadmin_mode=false
    local user_home

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_usage
                exit 0
                ;;
            -t|--target)
                target_dir="$2"
                shift 2
                ;;
            --sysadmin)
                sysadmin_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Resolve the home directory that owns the config: the invoking
    # user under sudo, otherwise the current one.
    user_home="$(resolve_user_home)"

    # Determine target directory
    if [[ -n "${target_dir:-}" ]]; then
        : # Use explicit target
    elif [[ "${sysadmin_mode}" == true ]]; then
        if [[ "${EUID}" -ne 0 ]]; then
            log_error "System-wide installation requires sudo. Run: sudo ./install.sh --sysadmin"
            exit 1
        fi
        target_dir="/usr/local/bin"
    else
        target_dir=$(detect_install_target)
    fi

    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "  Proton Drive Backup Installer v${VERSION}"
    echo "────────────────────────────────────────────────────────────"
    echo ""

    # Check dependencies
    check_dependencies

    # Install files (config always seeds the invoking user's XDG dir,
    # never root's, even when run via sudo --sysadmin)
    install_files "${target_dir}" "${user_home}/.config/${PROGNAME}"

    # Confirm installation
    echo ""
    log_info "Installation complete!"
    echo ""
    echo "Proton Drive Backup script location:"
    log_info "${target_dir}/${PROGNAME}"
    echo ""

    # PATH warning if needed
    if ! echo "$PATH" | grep -q "${target_dir}"; then
        log_warn "Target directory '${target_dir}' is NOT in your \$PATH."
        read -rp "  Add it now? This will modify your shell config. [Y/n] "
        if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
            add_to_path "${target_dir}"
            echo ""
        fi
    fi

    # ── Next Steps ────────────────────────────────────────────────────
    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "  Next steps:"
    echo ""
    printf "  1. Close this terminal and open a new one (if PATH was modified)\n"
    printf "  2. Adjust your configuration if needed:\n"
    printf "     %s/.config/%s/%s.cfg\n" "${user_home}" "${PROGNAME}" "${PROGNAME}"
    printf "  3. Preview your first run (nothing is executed): %s --dry-run\n" "${PROGNAME}"
    printf "  4. Run for real: %s\n" "${PROGNAME}"
    echo ""
}

main "$@"

# End of script
