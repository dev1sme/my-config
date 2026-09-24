#!/usr/bin/env bash
# ============================================================
# UI prompts: multiselect, select, confirm, text
# Requires: core.sh
# ============================================================

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
