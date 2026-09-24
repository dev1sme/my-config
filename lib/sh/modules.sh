#!/usr/bin/env bash
# ============================================================
# Module registry — discovers <module>/module.conf under ROOT
#
# module.conf keys:
#   label, hint, order, mode (tty|bg), default (on|off),
#   sudo (comma-separated OS ids), requires / requires_<os> (command,
#   "a|b" = any of them),
#   linux / mac / windows (script file per OS), next (next-step hint)
#
# Requires: ROOT, OS_ID
# ============================================================

MODULE_IDS=()

# Read a key from a module manifest
# Usage: module_get <id> <key>
module_get() {
    sed -n "s/^$2=//p" "$ROOT/$1/module.conf" 2>/dev/null | head -n 1 | sed 's/[[:space:]]*$//'
}

# Populate MODULE_IDS with modules available on this OS, sorted by order
load_modules() {
    local conf id order
    MODULE_IDS=()
    for id in $(
        for conf in "$ROOT"/*/module.conf; do
            [ -f "$conf" ] || continue
            id="$(basename "$(dirname "$conf")")"
            order="$(module_get "$id" order)"
            echo "${order:-999} $id"
        done | sort -n | cut -d' ' -f2
    ); do
        [ -n "$(module_get "$id" "$OS_ID")" ] && MODULE_IDS+=("$id")
    done
}

module_label()  { module_get "$1" label; }
module_mode()   { local m; m="$(module_get "$1" mode)"; echo "${m:-bg}"; }
module_next()   { module_get "$1" next; }
module_script() { echo "$ROOT/$1/$(module_get "$1" "$OS_ID")"; }

module_needs_sudo() {
    case ",$(module_get "$1" sudo)," in
        *",$OS_ID,"*) return 0 ;;
    esac
    return 1
}

# Required command missing -> empty output means OK
# requires_<os> overrides requires; "a|b" = any of the commands is enough
module_missing() {
    local req cmd
    req="$(module_get "$1" "requires_$OS_ID")"
    [ -z "$req" ] && req="$(module_get "$1" requires)"
    [ -z "$req" ] && return 0
    for cmd in $(echo "$req" | tr '|' ' '); do
        command -v "$cmd" >/dev/null 2>&1 && return 0
    done
    echo "$req" | sed 's/|/ hoặc /g'
}

module_hint() {
    local missing
    missing="$(module_missing "$1")"
    if [ -n "$missing" ]; then
        echo "không tìm thấy lệnh $missing"
    else
        module_get "$1" hint
    fi
}

module_default() {
    if [ -n "$(module_missing "$1")" ]; then
        echo off
        return
    fi
    local d
    d="$(module_get "$1" default)"
    echo "${d:-on}"
}

module_exists() {
    local id
    for id in "${MODULE_IDS[@]}"; do
        [ "$id" = "$1" ] && return 0
    done
    return 1
}
