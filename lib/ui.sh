#!/usr/bin/env bash
# ============================================================
# Clack-style terminal UI helpers
# Compatible with bash 3.2+ (macOS default bash)
#
# Usage: . "$ROOT/lib/ui.sh"
#
#   ui_intro "title"                      ┌  title
#   ui_step "message"                     ◇  message
#   ui_info / ui_warn / ui_error "msg"    ● / ▲ / ■  msg
#   ui_line "text"                        │  text
#   ui_note "title" "line" "line"...      boxed note
#   ui_multiselect "q" "label|hint|on"... -> UI_RESULT=(indices)
#   ui_select "q" "label|hint" ...        -> UI_ANSWER=index
#   ui_confirm "q" [y|n]                  -> return 0 (yes) / 1 (no)
#   ui_text "q" [default]                 -> UI_ANSWER=string
#   ui_spin "msg" logfile cmd args...     -> spinner while cmd runs
#   ui_outro "message"                    └  message
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

# ------------------------------------------------------------
# Prompts
# ------------------------------------------------------------

# Collapsed view of an answered prompt
_ui_answered() {
    printf '%s◇%s  %s\n%s  %s%s%s\n%s\n' "$UI_GREEN" "$UI_RESET" "$1" \
        "$UI_BAR" "$UI_DIM" "$2" "$UI_RESET" "$UI_BAR"
}

# Multi-select
# Usage: ui_multiselect "Question" "label|hint|on" "label|hint|off" ...
# Result: UI_RESULT=(selected indices). Returns 1 when cancelled.
ui_multiselect() {
    local question="$1"; shift
    local labels=() hints=() sel=()
    local n=0 opt l h s
    for opt in "$@"; do
        IFS='|' read -r l h s <<<"$opt"
        labels[n]="$l"; hints[n]="$h"
        if [ "$s" = "on" ]; then sel[n]=1; else sel[n]=0; fi
        n=$((n + 1))
    done

    local cur=0 drawn=0 key i count box text footer
    local help="↑/↓ di chuyển · space chọn · a chọn tất cả · enter xác nhận"
    footer="$help"
    ui_cursor_hide
    while :; do
        _ui_clear_lines "$drawn"
        ui_active "$question"
        for ((i = 0; i < n; i++)); do
            if [ "${sel[i]}" -eq 1 ]; then
                box="${UI_GREEN}◼${UI_RESET}"
            elif [ "$i" -eq "$cur" ]; then
                box="${UI_CYAN}◻${UI_RESET}"
            else
                box="${UI_DIM}◻${UI_RESET}"
            fi
            if [ "$i" -eq "$cur" ]; then
                text="${labels[i]}"
                [ -n "${hints[i]}" ] && text+=" ${UI_DIM}(${hints[i]})${UI_RESET}"
            else
                text="${UI_DIM}${labels[i]}${UI_RESET}"
            fi
            printf '%s│%s  %s %s\n' "$UI_CYAN" "$UI_RESET" "$box" "$text"
        done
        if [ "$footer" = "$help" ]; then
            printf '%s└%s  %s%s%s\n' "$UI_CYAN" "$UI_RESET" "$UI_DIM" "$footer" "$UI_RESET"
        else
            printf '%s└%s  %s%s%s\n' "$UI_YELLOW" "$UI_RESET" "$UI_YELLOW" "$footer" "$UI_RESET"
        fi
        drawn=$((n + 2))
        footer="$help"

        key=$(_ui_read_key)
        case "$key" in
            up)    cur=$(((cur - 1 + n) % n)) ;;
            down)  cur=$(((cur + 1) % n)) ;;
            space) sel[cur]=$((1 - sel[cur])) ;;
            all)
                count=0
                for ((i = 0; i < n; i++)); do count=$((count + sel[i])); done
                for ((i = 0; i < n; i++)); do
                    if [ "$count" -eq "$n" ]; then sel[i]=0; else sel[i]=1; fi
                done
                ;;
            enter)
                count=0
                for ((i = 0; i < n; i++)); do count=$((count + sel[i])); done
                [ "$count" -gt 0 ] && break
                footer="Chọn ít nhất 1 mục (bấm space để chọn)"
                ;;
            cancel)
                _ui_clear_lines "$drawn"
                ui_cursor_show
                printf '%s■%s  %s\n%s\n' "$UI_RED" "$UI_RESET" "$question" "$UI_BAR"
                return 1
                ;;
        esac
    done

    _ui_clear_lines "$drawn"
    ui_cursor_show
    UI_RESULT=()
    local names=""
    for ((i = 0; i < n; i++)); do
        if [ "${sel[i]}" -eq 1 ]; then
            UI_RESULT+=("$i")
            names+="${names:+, }${labels[i]}"
        fi
    done
    _ui_answered "$question" "$names"
}

# Single select
# Usage: ui_select "Question" "label|hint" "label|hint" ...
# Result: UI_ANSWER=index. Returns 1 when cancelled.
ui_select() {
    local question="$1"; shift
    local labels=() hints=()
    local n=0 opt l h
    for opt in "$@"; do
        IFS='|' read -r l h <<<"$opt"
        labels[n]="$l"; hints[n]="$h"
        n=$((n + 1))
    done

    local cur=0 drawn=0 key i text
    ui_cursor_hide
    while :; do
        _ui_clear_lines "$drawn"
        ui_active "$question"
        for ((i = 0; i < n; i++)); do
            if [ "$i" -eq "$cur" ]; then
                text="${UI_GREEN}●${UI_RESET} ${labels[i]}"
                [ -n "${hints[i]}" ] && text+=" ${UI_DIM}(${hints[i]})${UI_RESET}"
            else
                text="${UI_DIM}○ ${labels[i]}${UI_RESET}"
            fi
            printf '%s│%s  %s\n' "$UI_CYAN" "$UI_RESET" "$text"
        done
        printf '%s└%s\n' "$UI_CYAN" "$UI_RESET"
        drawn=$((n + 2))

        key=$(_ui_read_key)
        case "$key" in
            up|left)    cur=$(((cur - 1 + n) % n)) ;;
            down|right|tab) cur=$(((cur + 1) % n)) ;;
            enter|space) break ;;
            cancel)
                _ui_clear_lines "$drawn"
                ui_cursor_show
                printf '%s■%s  %s\n%s\n' "$UI_RED" "$UI_RESET" "$question" "$UI_BAR"
                return 1
                ;;
        esac
    done

    _ui_clear_lines "$drawn"
    ui_cursor_show
    UI_ANSWER="$cur"
    _ui_answered "$question" "${labels[cur]}"
}

# Yes/No confirm
# Usage: ui_confirm "Question" [y|n]  -> return 0 (yes) / 1 (no), 130 when cancelled
ui_confirm() {
    local question="$1" yes=1 drawn=0 key yes_txt no_txt
    [ "${2:-y}" = "n" ] && yes=0

    ui_cursor_hide
    while :; do
        _ui_clear_lines "$drawn"
        ui_active "$question"
        if [ "$yes" -eq 1 ]; then
            yes_txt="${UI_GREEN}●${UI_RESET} Có"
            no_txt="${UI_DIM}○ Không${UI_RESET}"
        else
            yes_txt="${UI_DIM}○ Có${UI_RESET}"
            no_txt="${UI_GREEN}●${UI_RESET} Không"
        fi
        printf '%s│%s  %s %s/%s %s\n' "$UI_CYAN" "$UI_RESET" "$yes_txt" "$UI_DIM" "$UI_RESET" "$no_txt"
        printf '%s└%s\n' "$UI_CYAN" "$UI_RESET"
        drawn=3

        key=$(_ui_read_key)
        case "$key" in
            left|right|up|down|tab) yes=$((1 - yes)) ;;
            yes)   yes=1; break ;;
            no)    yes=0; break ;;
            enter) break ;;
            cancel)
                _ui_clear_lines "$drawn"
                ui_cursor_show
                printf '%s■%s  %s\n%s\n' "$UI_RED" "$UI_RESET" "$question" "$UI_BAR"
                return 130
                ;;
        esac
    done

    _ui_clear_lines "$drawn"
    ui_cursor_show
    if [ "$yes" -eq 1 ]; then
        _ui_answered "$question" "Có"
        return 0
    fi
    _ui_answered "$question" "Không"
    return 1
}

# Free text input
# Usage: ui_text "Question" [default]  -> UI_ANSWER
ui_text() {
    local question="$1" default="${2:-}" reply
    ui_active "$question"
    if [ -n "$default" ]; then
        printf '%s│%s  %s(%s)%s ' "$UI_CYAN" "$UI_RESET" "$UI_DIM" "$default" "$UI_RESET"
    else
        printf '%s│%s  ' "$UI_CYAN" "$UI_RESET"
    fi
    IFS= read -r reply </dev/tty || reply=""
    [ -z "$reply" ] && reply="$default"
    _ui_clear_lines 2
    UI_ANSWER="$reply"
    _ui_answered "$question" "${reply:-(trống)}"
}

# ------------------------------------------------------------
# Spinner
# ------------------------------------------------------------

# Run a command in background with a spinner, output goes to logfile
# Usage: ui_spin "message" /path/to/log cmd args...
# Returns the command's exit code. Sets UI_ELAPSED (seconds).
ui_spin() {
    local msg="$1" log="$2"; shift 2
    local frames=('◒' '◐' '◓' '◑') i=0 start=$SECONDS rc

    "$@" >"$log" 2>&1 </dev/null &
    UI_SPIN_PID=$!

    ui_cursor_hide
    while [ -t 1 ] && kill -0 "$UI_SPIN_PID" 2>/dev/null; do
        printf '\r\033[2K%s%s%s  %s %s(%ss)%s' "$UI_MAGENTA" "${frames[i % 4]}" "$UI_RESET" \
            "$msg" "$UI_DIM" "$((SECONDS - start))" "$UI_RESET"
        i=$((i + 1))
        sleep 0.12
    done
    wait "$UI_SPIN_PID"
    rc=$?
    UI_SPIN_PID=""
    UI_ELAPSED=$((SECONDS - start))
    if [ -t 1 ]; then printf '\r\033[2K'; fi
    ui_cursor_show

    if [ "$rc" -eq 0 ]; then
        ui_step "$msg ${UI_DIM}(${UI_ELAPSED}s)${UI_RESET}"
    else
        ui_error "$msg ${UI_DIM}(exit $rc)${UI_RESET}"
    fi
    return "$rc"
}
