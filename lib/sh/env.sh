#!/usr/bin/env bash
# ============================================================
# Environment detection
# Sets: OS_ID (linux|mac), OS_NAME, DISTRO, ARCH, USER_NAME, IS_ROOT, IS_WSL
# Requires: ui.sh
# ============================================================

detect_env() {
    ARCH="$(uname -m)"
    USER_NAME="$(id -un)"
    IS_ROOT=0
    [ "$(id -u)" -eq 0 ] && IS_ROOT=1
    IS_WSL=0

    case "$(uname -s)" in
        Linux)
            OS_ID="linux"
            OS_NAME="$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")"
            DISTRO="$( . /etc/os-release 2>/dev/null && echo "${ID:-}")"
            grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1
            ;;
        Darwin)
            OS_ID="mac"
            OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null)"
            DISTRO="macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            ui_intro "my-config"
            ui_warn "Windows: hãy mở PowerShell và chạy:"
            ui_line "irm ${MY_CONFIG_WIN_URL} | iex"
            printf '%s\n' "$UI_BAR"
            ui_cancel "Git Bash không được hỗ trợ." 1
            ;;
        *)
            ui_intro "my-config"
            ui_cancel "Hệ điều hành không được hỗ trợ: $(uname -s)" 1
            ;;
    esac
}
