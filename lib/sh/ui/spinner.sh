#!/usr/bin/env bash
# ============================================================
# UI spinner for long-running background commands
# Requires: core.sh
# ============================================================

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
