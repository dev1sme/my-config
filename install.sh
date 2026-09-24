#!/usr/bin/env bash
# ============================================================
# my-config installer
#
#   curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --only zsh,docker --yes
#   ./install.sh                  # from a local clone
#
# Env overrides:
#   MY_CONFIG_REPO  GitHub repo       (default: dev1sme/my-config)
#   MY_CONFIG_REF   branch            (default: main)
#   MY_CONFIG_DIR   install location  (default: ~/.my-config)
# ============================================================

set -o pipefail

MY_CONFIG_REPO="${MY_CONFIG_REPO:-dev1sme/my-config}"
MY_CONFIG_REF="${MY_CONFIG_REF:-main}"
MY_CONFIG_DIR="${MY_CONFIG_DIR:-$HOME/.my-config}"

MODULE_IDS=(ssh zsh docker vscode)

# ============================================================
# Bootstrap: running via `curl | bash` -> fetch repo, re-exec locally
# ============================================================
self_dir() {
    local src="${BASH_SOURCE[0]:-}"
    if [ -n "$src" ] && [ -f "$src" ]; then
        (cd "$(dirname "$src")" && pwd)
    fi
}

bootstrap() {
    local gray="" green="" red="" reset=""
    if [ -t 1 ]; then
        gray=$'\033[90m' green=$'\033[32m' red=$'\033[31m' reset=$'\033[0m'
    fi
    local dir="$MY_CONFIG_DIR"

    _die() { printf '%s■%s  %s\n%s└%s\n' "$red" "$reset" "$1" "$gray" "$reset"; exit 1; }

    printf '\n%s┌%s  my-config bootstrap\n%s│%s\n' "$gray" "$reset" "$gray" "$reset"

    if command -v git >/dev/null 2>&1; then
        if [ -d "$dir/.git" ]; then
            git -C "$dir" pull --ff-only -q 2>/dev/null ||
                printf '▲  Không pull được, dùng bản hiện có trong %s\n' "$dir"
        elif [ -e "$dir" ]; then
            _die "$dir đã tồn tại nhưng không phải git repo. Đặt MY_CONFIG_DIR khác."
        else
            git clone -q --depth 1 -b "$MY_CONFIG_REF" \
                "https://github.com/${MY_CONFIG_REPO}.git" "$dir" ||
                _die "git clone thất bại."
        fi
    else
        command -v curl >/dev/null 2>&1 || _die "Cần git hoặc curl để tải my-config."
        if [ -e "$dir" ] && [ ! -f "$dir/lib/ui.sh" ]; then
            _die "$dir đã tồn tại và không phải my-config. Đặt MY_CONFIG_DIR khác."
        fi
        local tmp
        tmp="$(mktemp -d "${dir}.tmp.XXXXXX")" || _die "Không tạo được thư mục tạm."
        curl -fsSL "https://github.com/${MY_CONFIG_REPO}/archive/refs/heads/${MY_CONFIG_REF}.tar.gz" |
            tar -xz -C "$tmp" --strip-components=1 ||
            { rm -rf "$tmp"; _die "Tải tarball thất bại."; }
        rm -rf "$dir"
        mv "$tmp" "$dir"
    fi

    printf '%s◇%s  Đã tải my-config về %s\n' "$green" "$reset" "$dir"
    printf '%s└%s\n' "$gray" "$reset"

    export MY_CONFIG_BOOTSTRAPPED=1
    if ( exec </dev/tty ) 2>/dev/null; then
        exec bash "$dir/install.sh" "$@" </dev/tty
    fi
    exec bash "$dir/install.sh" "$@"
}

ROOT="$(self_dir)"
if [ -z "$ROOT" ] || [ ! -f "$ROOT/lib/ui.sh" ]; then
    if [ -n "${MY_CONFIG_BOOTSTRAPPED:-}" ]; then
        echo "my-config: không tìm thấy lib/ui.sh sau khi bootstrap." >&2
        exit 1
    fi
    bootstrap "$@"
fi

# shellcheck source=lib/ui.sh
. "$ROOT/lib/ui.sh"

# ============================================================
# Environment
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
            ui_error "Windows: hãy chạy trong PowerShell:  .\\ssh\\setup.ps1  và  .\\vscode\\setup.ps1"
            ui_cancel "Chưa hỗ trợ Windows trong installer này." 1
            ;;
        *)
            ui_intro "my-config"
            ui_cancel "Hệ điều hành không được hỗ trợ: $(uname -s)" 1
            ;;
    esac
}

# ============================================================
# Module registry
# ============================================================
module_label() {
    case "$1" in
        ssh)    echo "SSH key + ssh-agent" ;;
        zsh)    echo "Zsh + Oh My Zsh" ;;
        docker) echo "Docker Engine + Compose" ;;
        vscode) echo "VS Code extensions + settings" ;;
    esac
}

# Script path relative to ROOT, empty when module is unavailable on this OS
module_script() {
    case "$1:$OS_ID" in
        ssh:linux)    echo "ssh/setup.sh" ;;
        ssh:mac)      echo "ssh/setup_mac.sh" ;;
        zsh:linux)    echo "zsh/setup.sh" ;;
        zsh:mac)      echo "zsh/setup_mac.sh" ;;
        docker:linux) echo "docker/setup.sh" ;;
        vscode:linux) echo "vscode/setup.sh" ;;
        vscode:mac)   echo "vscode/setup_mac.sh" ;;
    esac
}

# tty = interactive script (runs in foreground), bg = runs under spinner
module_mode() {
    case "$1" in
        ssh|zsh) echo "tty" ;;
        *)       echo "bg" ;;
    esac
}

module_needs_sudo() {
    case "$1:$OS_ID" in
        zsh:linux|docker:linux) return 0 ;;
    esac
    return 1
}

module_hint() {
    case "$1" in
        ssh)
            echo "ed25519/rsa · ssh-agent · ~/.ssh/config" ;;
        zsh)
            if [ "$(basename "${SHELL:-}")" = "zsh" ] && [ -d "$HOME/.oh-my-zsh" ]; then
                echo "đã có Oh My Zsh · cài lại plugins + .zshrc"
            else
                echo "plugins, fzf, theme strug"
            fi
            ;;
        docker)
            if command -v docker >/dev/null 2>&1; then
                echo "đã cài $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ,) · sẽ cập nhật"
            else
                echo "docker-ce, buildx, compose v2"
            fi
            ;;
        vscode)
            if command -v code >/dev/null 2>&1; then
                echo "35 extensions + setting.json"
            else
                echo "không tìm thấy lệnh code"
            fi
            ;;
    esac
}

module_default() {
    case "$1" in
        vscode) command -v code >/dev/null 2>&1 && echo on || echo off ;;
        *)      echo on ;;
    esac
}

# ============================================================
# CLI
# ============================================================
usage() {
    cat <<EOF
my-config installer

Usage: install.sh [options]

Options:
  --only LIST   Chỉ cài các module (phân cách bằng dấu phẩy): ${MODULE_IDS[*]}
  --all         Cài tất cả module khả dụng trên OS hiện tại
  -y, --yes     Bỏ qua bước xác nhận
  --list        Liệt kê module
  -h, --help    Hiển thị help

Ví dụ:
  curl -fsSL <url>/install.sh | bash
  curl -fsSL <url>/install.sh | bash -s -- --only zsh,docker -y
EOF
}

OPT_ONLY=""
OPT_ALL=0
OPT_YES=0

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --only)   OPT_ONLY="${2:-}"; shift ;;
            --only=*) OPT_ONLY="${1#*=}" ;;
            --all)    OPT_ALL=1 ;;
            -y|--yes) OPT_YES=1 ;;
            --list)   OPT_LIST=1 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Option không hợp lệ: $1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

# ============================================================
# UI pieces
# ============================================================
banner() {
    local cols lines colors i
    cols="$(tput cols 2>/dev/null || echo 80)"
    if [ "$cols" -lt 76 ]; then
        printf '\n  %smy-config%s %s· dev1sme%s\n' "$UI_BOLD$UI_CYAN" "$UI_RESET" "$UI_DIM" "$UI_RESET"
        return
    fi
    lines=(
        '███╗   ███╗██╗   ██╗       ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗'
        '████╗ ████║╚██╗ ██╔╝      ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝'
        '██╔████╔██║ ╚████╔╝ █████╗██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗'
        '██║╚██╔╝██║  ╚██╔╝  ╚════╝██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║'
        '██║ ╚═╝ ██║   ██║         ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝'
        '╚═╝     ╚═╝   ╚═╝          ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝'
    )
    colors=(51 45 39 33 63 99)
    echo
    for i in 0 1 2 3 4 5; do
        if [ -n "$UI_RESET" ]; then
            printf '  \033[38;5;%sm%s%s\n' "${colors[i]}" "${lines[i]}" "$UI_RESET"
        else
            printf '  %s\n' "${lines[i]}"
        fi
    done
    printf '  %sdev environment bootstrap · github.com/%s%s\n' "$UI_DIM" "$MY_CONFIG_REPO" "$UI_RESET"
}

# ============================================================
# Sudo keepalive
# ============================================================
SUDO_KEEPALIVE_PID=""

ensure_sudo() {
    [ "$IS_ROOT" -eq 1 ] && return 0
    if ! command -v sudo >/dev/null 2>&1; then
        ui_warn "Không có sudo. Các module cần quyền root có thể lỗi."
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        ui_step "Quyền sudo: sẵn sàng"
    else
        ui_active "Cần quyền sudo để cài package"
        printf '%s│%s  ' "$UI_CYAN" "$UI_RESET"
        if ! sudo -v -p "Mật khẩu sudo cho %u: " </dev/tty; then
            ui_cancel "Không xác thực được sudo." 1
        fi
        printf '\033[2A\033[J'
        ui_step "Quyền sudo: đã xác thực"
    fi
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) >/dev/null 2>&1 &
    SUDO_KEEPALIVE_PID=$!
}

# ============================================================
# Run modules
# ============================================================
RESULTS=()

run_module() {
    local id="$1" label script mode log rc start
    label="$(module_label "$id")"
    script="$ROOT/$(module_script "$id")"
    mode="$(module_mode "$id")"
    log="$LOG_DIR/$id.log"

    if [ "$mode" = "bg" ]; then
        ui_spin "Cài $label" "$log" bash "$script"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            ui_line "${UI_DIM}Log: $log${UI_RESET}"
            tail -n 12 "$log" 2>/dev/null | sed $'s/\033\\[[0-9;]*m//g' | while IFS= read -r l; do
                ui_line "${UI_DIM}${l}${UI_RESET}"
            done
            printf '%s\n' "$UI_BAR"
        fi
    else
        ui_active "Cài $label ${UI_DIM}(tương tác)${UI_RESET}"
        printf '%s\n' "$UI_BAR"
        start=$SECONDS
        if ui_has_tty; then
            bash "$script" </dev/tty
        else
            bash "$script" </dev/null
        fi
        rc=$?
        UI_ELAPSED=$((SECONDS - start))
        printf '%s\n' "$UI_BAR"
        if [ "$rc" -eq 0 ]; then
            ui_step "Cài $label ${UI_DIM}(${UI_ELAPSED}s)${UI_RESET}"
        else
            ui_error "Cài $label ${UI_DIM}(exit $rc)${UI_RESET}"
        fi
    fi

    RESULTS+=("$id:$rc:$UI_ELAPSED")
    return "$rc"
}

# ============================================================
# Main
# ============================================================
cleanup() {
    [ -n "${UI_SPIN_PID:-}" ] && kill "$UI_SPIN_PID" 2>/dev/null
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    ui_cursor_show
}

main() {
    parse_args "$@"
    detect_env

    trap cleanup EXIT
    trap 'printf "\n"; ui_cancel "Đã huỷ."' INT TERM

    # Modules available on this OS
    local available=() id
    for id in "${MODULE_IDS[@]}"; do
        [ -n "$(module_script "$id")" ] && available+=("$id")
    done

    if [ -n "${OPT_LIST:-}" ]; then
        for id in "${available[@]}"; do
            printf '%-8s %s\n' "$id" "$(module_label "$id")"
        done
        exit 0
    fi

    banner
    ui_intro "my-config setup"

    local who="$USER_NAME"
    [ "$IS_ROOT" -eq 1 ] && who="root"
    ui_step "Hệ thống: $OS_NAME · $ARCH · user $who"
    [ "$IS_WSL" -eq 1 ] && ui_info "Đang chạy trong WSL"
    [ "$OS_ID" = "mac" ] && ui_info "Docker trên macOS: khuyên dùng OrbStack (https://orbstack.dev)"

    local interactive=0
    ui_has_tty && interactive=1

    # ---- Select modules ----
    local selected=()
    if [ -n "$OPT_ONLY" ]; then
        local item found
        for item in $(echo "$OPT_ONLY" | tr ',' ' '); do
            found=0
            for id in "${available[@]}"; do
                [ "$id" = "$item" ] && found=1
            done
            [ "$found" -eq 1 ] || ui_cancel "Module '$item' không khả dụng trên $OS_NAME. Có: ${available[*]}" 2
            selected+=("$item")
        done
        ui_step "Module: ${selected[*]}"
    elif [ "$OPT_ALL" -eq 1 ]; then
        selected=("${available[@]}")
        ui_step "Module: ${selected[*]}"
    elif [ "$interactive" -eq 1 ]; then
        local opts=() i
        for id in "${available[@]}"; do
            opts+=("$(module_label "$id")|$(module_hint "$id")|$(module_default "$id")")
        done
        ui_multiselect "Chọn module cần cài" "${opts[@]}" || ui_cancel "Đã huỷ."
        for i in "${UI_RESULT[@]}"; do
            selected+=("${available[i]}")
        done
    else
        ui_cancel "Không có terminal tương tác. Dùng --only <module> hoặc --all." 2
    fi

    # ---- Confirm ----
    local plan=() mode
    for id in "${selected[@]}"; do
        mode="$(module_mode "$id")"
        if [ "$mode" = "tty" ]; then
            plan+=("${UI_CYAN}•${UI_RESET} $(module_label "$id") ${UI_DIM}— sẽ hỏi thêm vài câu${UI_RESET}")
        else
            plan+=("${UI_CYAN}•${UI_RESET} $(module_label "$id") ${UI_DIM}— tự động${UI_RESET}")
        fi
    done
    ui_note "Kế hoạch" "${plan[@]}"
    printf '%s\n' "$UI_BAR"

    if [ "$OPT_YES" -eq 0 ] && [ "$interactive" -eq 1 ]; then
        ui_confirm "Bắt đầu cài đặt?" y || ui_cancel "Đã huỷ, chưa thay đổi gì."
    fi

    # ---- Sudo ----
    local need_sudo=0
    for id in "${selected[@]}"; do
        module_needs_sudo "$id" && need_sudo=1
    done
    [ "$need_sudo" -eq 1 ] && ensure_sudo

    # ---- Run ----
    LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/my-config/logs/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"

    local failed=0
    for id in "${selected[@]}"; do
        run_module "$id" || failed=$((failed + 1))
    done

    # ---- Summary ----
    local summary=() r rid rrc rsec
    for r in "${RESULTS[@]}"; do
        IFS=':' read -r rid rrc rsec <<<"$r"
        if [ "$rrc" -eq 0 ]; then
            summary+=("${UI_GREEN}✔${UI_RESET} $(module_label "$rid") ${UI_DIM}${rsec}s${UI_RESET}")
        else
            summary+=("${UI_RED}✘${UI_RESET} $(module_label "$rid") ${UI_DIM}exit $rrc${UI_RESET}")
        fi
    done
    summary+=("" "${UI_DIM}Logs: $LOG_DIR${UI_RESET}")
    ui_note "Kết quả" "${summary[@]}"
    printf '%s\n' "$UI_BAR"

    # ---- Next steps ----
    local next=()
    for r in "${RESULTS[@]}"; do
        IFS=':' read -r rid rrc rsec <<<"$r"
        [ "$rrc" -eq 0 ] || continue
        case "$rid" in
            zsh)    next+=("Chạy ${UI_CYAN}exec zsh${UI_RESET} để dùng shell mới") ;;
            docker) [ "$IS_ROOT" -eq 0 ] && next+=("Logout/login lại để dùng docker không cần sudo") ;;
            ssh)    next+=("Thêm public key: ${UI_CYAN}https://github.com/settings/keys${UI_RESET}") ;;
        esac
    done
    [ "${#next[@]}" -gt 0 ] && { ui_note "Bước tiếp theo" "${next[@]}"; printf '%s\n' "$UI_BAR"; }

    if [ "$failed" -eq 0 ]; then
        ui_outro "${UI_GREEN}Hoàn tất!${UI_RESET}"
    else
        ui_outro "${UI_YELLOW}Xong, có $failed module lỗi. Xem log ở trên.${UI_RESET}"
        exit 1
    fi
}

main "$@"
