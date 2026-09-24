#!/usr/bin/env bash
# ============================================================
# Gradient ASCII banner (art shared with Windows: lib/banner.txt)
# Requires: ui.sh, ROOT
# ============================================================

banner() {
    local cols colors i=0 line
    cols="$(tput cols 2>/dev/null || echo 80)"
    if [ "$cols" -lt 76 ] || [ ! -f "$ROOT/lib/banner.txt" ]; then
        printf '\n  %smy-config%s %s· dev1sme%s\n' "$UI_BOLD$UI_CYAN" "$UI_RESET" "$UI_DIM" "$UI_RESET"
        return
    fi
    colors=(51 45 39 33 63 99)
    echo
    while IFS= read -r line; do
        if [ -n "$UI_RESET" ]; then
            printf '  \033[38;5;%sm%s%s\n' "${colors[i % 6]}" "$line" "$UI_RESET"
        else
            printf '  %s\n' "$line"
        fi
        i=$((i + 1))
    done <"$ROOT/lib/banner.txt"
    printf '  %sdev environment bootstrap · github.com/%s%s\n' "$UI_DIM" "$MY_CONFIG_REPO" "$UI_RESET"
}
