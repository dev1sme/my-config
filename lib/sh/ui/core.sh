#!/usr/bin/env bash
# ============================================================
# UI core: colors, terminal helpers, static output
# Compatible with bash 3.2+ (macOS default bash)
# ============================================================

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    UI_RESET=$'\033[0m'
    UI_BOLD=$'\033[1m'
    UI_DIM=$'\033[2m'
    UI_INV=$'\033[7m'
    UI_RED=$'\033[31m'
    UI_GREEN=$'\033[32m'
    UI_YELLOW=$'\033[33m'
    UI_BLUE=$'\033[34m'
    UI_MAGENTA=$'\033[35m'
    UI_CYAN=$'\033[36m'
    UI_GRAY=$'\033[90m'
else
    UI_RESET="" UI_BOLD="" UI_DIM="" UI_INV=""
    UI_RED="" UI_GREEN="" UI_YELLOW="" UI_BLUE=""
    UI_MAGENTA="" UI_CYAN="" UI_GRAY=""
fi

UI_BAR="${UI_GRAY}│${UI_RESET}"
UI_RESULT=()
UI_ANSWER=""

# ------------------------------------------------------------
# Low-level helpers
# ------------------------------------------------------------

# True when an interactive terminal can be opened (works under `curl | bash`)
ui_has_tty() {
    ( exec </dev/tty ) 2>/dev/null
}

ui_cursor_hide() { if [ -t 1 ]; then printf '\033[?25l'; fi; }
ui_cursor_show() { if [ -t 1 ]; then printf '\033[?25h'; fi; }

# Visible width of a string: strip ANSI codes, count UTF-8 chars
# (drop continuation bytes so it works regardless of the current locale)
_ui_width() {
    printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

_ui_repeat() {
    local char="$1" n="$2" out=""
    while [ "$n" -gt 0 ]; do
        out+="$char"
        n=$((n - 1))
    done
    printf '%s' "$out"
}

# Clear the last N printed lines
_ui_clear_lines() {
    if [ "$1" -gt 0 ]; then
        printf '\033[%dA\033[J' "$1"
    fi
}

# Read one key from the terminal, print a normalized name
_ui_read_key() {
    local key rest timeout=1
    [ "${BASH_VERSINFO[0]}" -ge 4 ] && timeout=0.05
    IFS= read -rsn1 key </dev/tty || { echo cancel; return; }
    if [ "$key" = $'\033' ]; then
        IFS= read -rsn2 -t "$timeout" rest </dev/tty || true
        key+="$rest"
    fi
    case "$key" in
        $'\033[A'|k|K)  echo up ;;
        $'\033[B'|j|J)  echo down ;;
        $'\033[C'|l|L)  echo right ;;
        $'\033[D'|h|H)  echo left ;;
        $'\t')          echo tab ;;
        ' ')            echo space ;;
        '')             echo enter ;;
        a|A)            echo all ;;
        y|Y)            echo yes ;;
        n|N)            echo no ;;
        q|Q|$'\033')    echo cancel ;;
        *)              echo other ;;
    esac
}

# ------------------------------------------------------------
# Static output
# ------------------------------------------------------------

ui_intro() {
    printf '\n%s┌%s  %s %s %s\n%s\n' "$UI_GRAY" "$UI_RESET" "$UI_INV" "$1" "$UI_RESET" "$UI_BAR"
}

ui_outro() {
    printf '%s└%s  %s\n\n' "$UI_GRAY" "$UI_RESET" "$1"
}

ui_line()    { printf '%s  %s\n' "$UI_BAR" "$1"; }
ui_step()    { printf '%s◇%s  %s\n%s\n' "$UI_GREEN" "$UI_RESET" "$1" "$UI_BAR"; }
ui_info()    { printf '%s●%s  %s\n%s\n' "$UI_BLUE" "$UI_RESET" "$1" "$UI_BAR"; }
ui_warn()    { printf '%s▲%s  %s\n%s\n' "$UI_YELLOW" "$UI_RESET" "$1" "$UI_BAR"; }
ui_error()   { printf '%s■%s  %s\n%s\n' "$UI_RED" "$UI_RESET" "$1" "$UI_BAR"; }
ui_active()  { printf '%s◆%s  %s\n' "$UI_CYAN" "$UI_RESET" "$1"; }

# Print a cancel line and exit
ui_cancel() {
    ui_cursor_show
    printf '%s└%s  %s%s%s\n\n' "$UI_GRAY" "$UI_RESET" "$UI_RED" "${1:-Đã huỷ.}" "$UI_RESET"
    exit "${2:-130}"
}

# Boxed note
#   ◇  Title ──────╮
#   │              │
#   │  line        │
#   │              │
#   ├──────────────╯
ui_note() {
    local title="$1"; shift
    local line len width tlen
    width=0
    for line in "$@"; do
        len=$(_ui_width "$line")
        [ "$len" -gt "$width" ] && width=$len
    done
    tlen=$(_ui_width "$title")
    [ "$tlen" -gt "$width" ] && width=$tlen

    local blank
    blank="$(_ui_repeat ' ' $((width + 4)))"
    printf '%s◇%s  %s %s%s╮%s\n' "$UI_GREEN" "$UI_RESET" "$title" \
        "$UI_GRAY" "$(_ui_repeat '─' $((width + 1 - tlen)))" "$UI_RESET"
    printf '%s│%s%s%s│%s\n' "$UI_GRAY" "$UI_RESET" "$blank" "$UI_GRAY" "$UI_RESET"
    for line in "$@"; do
        len=$(_ui_width "$line")
        printf '%s│%s  %s%s  %s│%s\n' "$UI_GRAY" "$UI_RESET" "$line" \
            "$(_ui_repeat ' ' $((width - len)))" "$UI_GRAY" "$UI_RESET"
    done
    printf '%s│%s%s%s│%s\n' "$UI_GRAY" "$UI_RESET" "$blank" "$UI_GRAY" "$UI_RESET"
    printf '%s├%s╯%s\n' "$UI_GRAY" "$(_ui_repeat '─' $((width + 4)))" "$UI_RESET"
}
