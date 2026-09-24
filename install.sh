#!/usr/bin/env bash
# ============================================================
# my-config installer (Linux / macOS)
#
#   curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --only zsh,docker --yes
#   ./install.sh                  # from a local clone
#
# Env overrides:
#   MY_CONFIG_REPO  GitHub repo       (default: dev1sme/my-config)
#   MY_CONFIG_REF   branch            (default: main)
#   MY_CONFIG_DIR   install location  (default: ~/.my-config)
#
# Modules are discovered from <module>/module.conf (see lib/sh/modules.sh).
# ============================================================

set -o pipefail

MY_CONFIG_REPO="${MY_CONFIG_REPO:-dev1sme/my-config}"
MY_CONFIG_REF="${MY_CONFIG_REF:-main}"
MY_CONFIG_DIR="${MY_CONFIG_DIR:-$HOME/.my-config}"
MY_CONFIG_WIN_URL="https://raw.githubusercontent.com/${MY_CONFIG_REPO}/${MY_CONFIG_REF}/install.ps1"

# ============================================================
# Bootstrap: running via `curl | bash` -> fetch repo, re-exec locally
# Must stay self-contained: lib/ is not available yet at this point.
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
        if [ -e "$dir" ] && [ ! -f "$dir/lib/sh/ui.sh" ]; then
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
if [ -z "$ROOT" ] || [ ! -f "$ROOT/lib/sh/ui.sh" ]; then
    if [ -n "${MY_CONFIG_BOOTSTRAPPED:-}" ]; then
        echo "my-config: không tìm thấy lib/sh/ui.sh sau khi bootstrap." >&2
        exit 1
    fi
    bootstrap "$@"
fi

. "$ROOT/lib/sh/ui.sh"
. "$ROOT/lib/sh/banner.sh"
. "$ROOT/lib/sh/env.sh"
. "$ROOT/lib/sh/modules.sh"
. "$ROOT/lib/sh/runner.sh"

# ============================================================
# CLI
# ============================================================
OPT_ONLY=""
OPT_ALL=0
OPT_YES=0
OPT_LIST=0

usage() {
    cat <<EOF
my-config installer

Usage: install.sh [options]

Options:
  --only LIST   Chỉ cài các module (phân cách bằng dấu phẩy), xem --list
  --all         Cài tất cả module khả dụng trên OS hiện tại
  -y, --yes     Bỏ qua bước xác nhận
  --list        Liệt kê module
  -h, --help    Hiển thị help

Ví dụ:
  curl -fsSL <url>/install.sh | bash
  curl -fsSL <url>/install.sh | bash -s -- --only zsh,docker -y
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --only)    OPT_ONLY="${2:-}"; shift ;;
            --only=*)  OPT_ONLY="${1#*=}" ;;
            --all)     OPT_ALL=1 ;;
            -y|--yes)  OPT_YES=1 ;;
            --list)    OPT_LIST=1 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Option không hợp lệ: $1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

# ============================================================
# Flow
# ============================================================
SELECTED=()

select_modules() {
    local id item i opts=()
    if [ -n "$OPT_ONLY" ]; then
        for item in $(echo "$OPT_ONLY" | tr ',' ' '); do
            module_exists "$item" ||
                ui_cancel "Module '$item' không khả dụng trên $OS_NAME. Có: ${MODULE_IDS[*]}" 2
            SELECTED+=("$item")
        done
        ui_step "Module: ${SELECTED[*]}"
    elif [ "$OPT_ALL" -eq 1 ]; then
        SELECTED=("${MODULE_IDS[@]}")
        ui_step "Module: ${SELECTED[*]}"
    elif ui_has_tty; then
        for id in "${MODULE_IDS[@]}"; do
            opts+=("$(module_label "$id")|$(module_hint "$id")|$(module_default "$id")")
        done
        ui_multiselect "Chọn module cần cài" "${opts[@]}" || ui_cancel "Đã huỷ."
        for i in "${UI_RESULT[@]}"; do
            SELECTED+=("${MODULE_IDS[i]}")
        done
    else
        ui_cancel "Không có terminal tương tác. Dùng --only <module> hoặc --all." 2
    fi
}

confirm_plan() {
    local id plan=() how
    for id in "${SELECTED[@]}"; do
        how="tự động"
        [ "$(module_mode "$id")" = "tty" ] && how="sẽ hỏi thêm vài câu"
        plan+=("${UI_CYAN}•${UI_RESET} $(module_label "$id") ${UI_DIM}— ${how}${UI_RESET}")
    done
    ui_note "Kế hoạch" "${plan[@]}"

    if [ "$OPT_YES" -eq 0 ] && ui_has_tty; then
        ui_confirm "Bắt đầu cài đặt?" y || ui_cancel "Đã huỷ, chưa thay đổi gì."
    fi
}

cleanup() {
    [ -n "${UI_SPIN_PID:-}" ] && kill "$UI_SPIN_PID" 2>/dev/null
    stop_sudo_keepalive
    ui_cursor_show
}

main() {
    parse_args "$@"
    detect_env
    load_modules

    if [ "$OPT_LIST" -eq 1 ]; then
        local id
        for id in "${MODULE_IDS[@]}"; do
            printf '%-8s %s\n' "$id" "$(module_label "$id")"
        done
        exit 0
    fi

    trap cleanup EXIT
    trap 'printf "\n"; ui_cancel "Đã huỷ."' INT TERM

    banner
    ui_intro "my-config setup"

    local who="$USER_NAME"
    [ "$IS_ROOT" -eq 1 ] && who="root"
    ui_step "Hệ thống: $OS_NAME · $ARCH · user $who"
    [ "$IS_WSL" -eq 1 ] && ui_info "Đang chạy trong WSL"
    [ "$OS_ID" = "mac" ] && ui_info "Docker trên macOS: khuyên dùng OrbStack (https://orbstack.dev)"

    select_modules
    confirm_plan

    local id need_sudo=0
    for id in "${SELECTED[@]}"; do
        module_needs_sudo "$id" && need_sudo=1
    done
    [ "$need_sudo" -eq 1 ] && ensure_sudo

    init_log_dir
    for id in "${SELECTED[@]}"; do
        run_module "$id"
    done

    local failed
    print_summary
    failed=$?
    if [ "$failed" -eq 0 ]; then
        ui_outro "${UI_GREEN}Hoàn tất!${UI_RESET}"
    else
        ui_outro "${UI_YELLOW}Xong, có $failed module lỗi. Xem log ở trên.${UI_RESET}"
        exit 1
    fi
}

main "$@"
