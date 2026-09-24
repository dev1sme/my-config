#!/usr/bin/env bash
# ============================================================
# Package manager abstraction for module scripts
# Supports: apt, dnf, yum, pacman, zypper, apk, brew
#
# Usage: . "$ROOT/lib/sh/pkg.sh"
#
#   $SUDO                   "" when root, "sudo" otherwise
#   pkg_detect              sets PKG_MANAGER, returns 1 when none found
#   pkg_update              refresh package index (once per run)
#   pkg_install zsh fzf     install packages (non-interactive)
#   pkg_remove docker.io    remove packages, ignores missing ones
#   pkg_ensure_cmd git      install package providing a command if missing
#                           (pkg_ensure_cmd <cmd> [package])
#   require_sudo            fail early when not root and sudo is missing
# ============================================================

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

PKG_MANAGER="${PKG_MANAGER:-}"
_PKG_UPDATED=0

require_sudo() {
    if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then
        echo "Cần quyền root: chạy bằng root hoặc cài sudo." >&2
        return 1
    fi
}

pkg_detect() {
    [ -n "$PKG_MANAGER" ] && return 0
    if [ "$(uname -s)" = "Darwin" ]; then
        command -v brew >/dev/null 2>&1 && PKG_MANAGER="brew"
    else
        local pm
        for pm in apt-get dnf yum pacman zypper apk; do
            if command -v "$pm" >/dev/null 2>&1; then
                PKG_MANAGER="${pm%-get}"
                break
            fi
        done
    fi
    [ -n "$PKG_MANAGER" ]
}

pkg_update() {
    [ "$_PKG_UPDATED" -eq 1 ] && return 0
    pkg_detect || return 1
    case "$PKG_MANAGER" in
        apt)    $SUDO apt-get update -y ;;
        zypper) $SUDO zypper --non-interactive --quiet refresh ;;
        apk)    $SUDO apk update ;;
        pacman)
            # Only sync when the local database is empty (fresh system/container).
            # A full `pacman -Syu` is the user's call, partial -Sy upgrades are avoided.
            if [ -z "$(ls -A /var/lib/pacman/sync 2>/dev/null)" ]; then
                $SUDO pacman -Sy --noconfirm
            fi
            ;;
        dnf|yum|brew) ;;  # refresh metadata automatically
    esac
    _PKG_UPDATED=1
}

pkg_install() {
    if ! pkg_detect; then
        echo "Không tìm thấy package manager hỗ trợ (apt/dnf/yum/pacman/zypper/apk/brew)." >&2
        return 1
    fi
    require_sudo || return 1
    pkg_update || return 1
    case "$PKG_MANAGER" in
        apt)    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        dnf)    $SUDO dnf install -y "$@" ;;
        yum)    $SUDO yum install -y "$@" ;;
        pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
        zypper) $SUDO zypper --non-interactive install "$@" ;;
        apk)    $SUDO apk add "$@" ;;
        brew)   brew install "$@" ;;
    esac
}

pkg_remove() {
    pkg_detect || return 0
    local pkg
    for pkg in "$@"; do
        case "$PKG_MANAGER" in
            apt)    dpkg -s "$pkg" >/dev/null 2>&1 && $SUDO apt-get remove -y "$pkg" ;;
            dnf)    rpm -q "$pkg" >/dev/null 2>&1 && $SUDO dnf remove -y "$pkg" ;;
            yum)    rpm -q "$pkg" >/dev/null 2>&1 && $SUDO yum remove -y "$pkg" ;;
            pacman) pacman -Qi "$pkg" >/dev/null 2>&1 && $SUDO pacman -R --noconfirm "$pkg" ;;
            zypper) rpm -q "$pkg" >/dev/null 2>&1 && $SUDO zypper --non-interactive remove "$pkg" ;;
            apk)    apk info -e "$pkg" >/dev/null 2>&1 && $SUDO apk del "$pkg" ;;
            brew)   brew list "$pkg" >/dev/null 2>&1 && brew uninstall "$pkg" ;;
        esac
    done >/dev/null 2>&1
    return 0
}

pkg_ensure_cmd() {
    command -v "$1" >/dev/null 2>&1 && return 0
    pkg_install "${2:-$1}"
}
