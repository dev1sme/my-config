#!/usr/bin/env bash
# ============================================================
# Module runner: sudo keepalive, execution, summary
# Requires: ui.sh, modules.sh, env.sh
# ============================================================

# Module scripts check this to skip their own intro/outro (see ui_module_start)
export MY_CONFIG_INSTALLER=1

SUDO_KEEPALIVE_PID=""
RESULTS=()
LOG_DIR=""

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

stop_sudo_keepalive() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    fi
}

init_log_dir() {
    LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/my-config/logs/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"
}

run_module() {
    local id="$1" label script log rc start l
    label="$(module_label "$id")"
    script="$(module_script "$id")"
    log="$LOG_DIR/$id.log"

    if [ "$(module_mode "$id")" = "bg" ]; then
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

# Print result box + next steps. Returns number of failed modules.
print_summary() {
    local summary=() next=() r id rc sec hint failed=0
    for r in "${RESULTS[@]}"; do
        IFS=':' read -r id rc sec <<<"$r"
        if [ "$rc" -eq 0 ]; then
            summary+=("${UI_GREEN}✔${UI_RESET} $(module_label "$id") ${UI_DIM}${sec}s${UI_RESET}")
            hint="$(module_next "$id")"
            [ -n "$hint" ] && next+=("$hint")
        else
            summary+=("${UI_RED}✘${UI_RESET} $(module_label "$id") ${UI_DIM}exit $rc${UI_RESET}")
            failed=$((failed + 1))
        fi
    done
    summary+=("" "${UI_DIM}Logs: $LOG_DIR${UI_RESET}")
    ui_note "Kết quả" "${summary[@]}"

    if [ "${#next[@]}" -gt 0 ]; then
        ui_note "Bước tiếp theo" "${next[@]}"
    fi
    return "$failed"
}
