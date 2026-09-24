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

# Blocks (step, note, prompt...) end with a │ spacer; a ui_section does not.
# Close an open section with a spacer before the next block starts.
_UI_SECTION_OPEN=0
_ui_block_begin() {
    if [ "$_UI_SECTION_OPEN" -eq 1 ]; then
        printf '%s\n' "$UI_BAR"
        _UI_SECTION_OPEN=0
    fi
}

ui_line()    { printf '%s  %s\n' "$UI_BAR" "$1"; }
ui_step()    { _ui_block_begin; printf '%s◇%s  %s\n%s\n' "$UI_GREEN" "$UI_RESET" "$1" "$UI_BAR"; }
ui_info()    { _ui_block_begin; printf '%s●%s  %s\n%s\n' "$UI_BLUE" "$UI_RESET" "$1" "$UI_BAR"; }
ui_warn()    { _ui_block_begin; printf '%s▲%s  %s\n%s\n' "$UI_YELLOW" "$UI_RESET" "$1" "$UI_BAR"; }
ui_error()   { _ui_block_begin; printf '%s■%s  %s\n%s\n' "$UI_RED" "$UI_RESET" "$1" "$UI_BAR"; }
ui_active()  { _ui_block_begin; printf '%s◆%s  %s\n' "$UI_CYAN" "$UI_RESET" "$1"; }

# Print a cancel line and exit
ui_cancel() {
    ui_cursor_show
    printf '%s└%s  %s%s%s\n\n' "$UI_GRAY" "$UI_RESET" "$UI_RED" "${1:-Đã huỷ.}" "$UI_RESET"
    exit "${2:-130}"
}

# Boxed note (ends with a │ spacer)
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
    _ui_block_begin
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
    printf '%s\n' "$UI_BAR"
}

# ------------------------------------------------------------
# Module output (inside the │ rail of the installer)
#
#   ui_module_start "title"   ┌ title   (only when run standalone)
#   ui_section "title"        ◇ title
#   ui_log / ui_log_warn / ui_log_error "msg"
#   cmd 2>&1 | ui_indent      dim command output inside the rail
#   ui_module_end "msg"       └ msg     (only when run standalone)
#
# The installer exports MY_CONFIG_INSTALLER=1 and draws intro/outro itself.
# ------------------------------------------------------------
ui_is_standalone() { [ -z "${MY_CONFIG_INSTALLER:-}" ]; }

ui_module_start() {
    if ui_is_standalone; then
        ui_intro "$1"
    fi
    _UI_SECTION_OPEN=0
}

ui_module_end() {
    if ui_is_standalone; then
        _ui_block_begin
        ui_outro "$1"
    fi
}

ui_section() {
    if [ "$_UI_SECTION_OPEN" -eq 1 ]; then
        printf '%s\n' "$UI_BAR"
    fi
    printf '%s◇%s  %s\n' "$UI_GREEN" "$UI_RESET" "$1"
    _UI_SECTION_OPEN=1
}

# Print a (possibly multi-line) message inside the rail
# Usage: _ui_log_lines "<first-line marker>" "<color>" "text"
_ui_log_lines() {
    local marker="$1" color="$2" line first=1 pad
    _UI_SECTION_OPEN=1
    pad="$(_ui_repeat ' ' "$(_ui_width "$marker")")"
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$first" -eq 1 ]; then
            printf '%s  %s%s%s%s\n' "$UI_BAR" "$color" "$marker" "$line" "$UI_RESET"
            first=0
        else
            # continuation lines: drop the source indentation, align under the text
            line="${line#"${line%%[![:space:]]*}"}"
            printf '%s  %s%s%s%s\n' "$UI_BAR" "$color" "$pad" "$line" "$UI_RESET"
        fi
    done <<<"$3"
}

ui_log()       { _ui_log_lines "" "" "$1"; }
ui_log_warn()  { _ui_log_lines "▲ " "$UI_YELLOW" "$1"; }
ui_log_error() { _ui_log_lines "■ " "$UI_RED" "$1"; }

# Print an error inside the rail and exit
ui_fail() {
    ui_log_error "$1"
    if ui_is_standalone; then
        _UI_SECTION_OPEN=1
        _ui_block_begin
        ui_outro "${UI_RED}Thất bại${UI_RESET}"
    fi
    exit "${2:-1}"
}

# Prefix piped command output with the rail (strips carriage-return progress)
ui_indent() {
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line##*$'\r'}"
        printf '%s  %s%s%s\n' "$UI_BAR" "$UI_DIM" "$line" "$UI_RESET"
    done
}

# Run a command with its output indented in the rail, keep its exit code
# Usage: ui_run apt-get install -y zsh
ui_run() {
    "$@" 2>&1 | ui_indent
    local rc="${PIPESTATUS[0]}"
    _UI_SECTION_OPEN=1
    return "$rc"
}
