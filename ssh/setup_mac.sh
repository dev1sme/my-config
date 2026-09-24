#!/bin/bash
# ============================================================
# SSH Key Setup Script - macOS
# Tạo SSH key pair, cấu hình ssh-agent (Keychain) và ~/.ssh/config
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../lib/sh/ui.sh
. "$SCRIPT_DIR/../lib/sh/ui.sh"

info()   { ui_log "$1"; }
warn()   { ui_log_warn "$1"; }
error()  { ui_fail "$1"; }
header() { ui_section "$1"; }

# ============================================================
# Kiểm tra hệ điều hành
# ============================================================
case "$(uname -s)" in
    Darwin) ;;  # OK
    Linux)  error "Bạn đang dùng Linux. Hãy chạy: ./ssh/setup.sh" ;;
    MINGW*|MSYS*|CYGWIN*)
            error "Bạn đang dùng Windows. Hãy chạy: .\\ssh\\setup.ps1  (PowerShell, quyền Administrator)" ;;
    *)      error "Hệ điều hành không được hỗ trợ: $(uname -s)" ;;
esac

# ============================================================
# Defaults
# ============================================================
KEY_TYPE="ed25519"
KEY_FILE=""
KEY_COMMENT=""
ADD_TO_AGENT=true

# ============================================================
# Bước 0: Thu thập cấu hình từ người dùng (interactive)
# ============================================================
collect_config() {
    ui_select "Loại key" "ed25519|khuyên dùng" "rsa|4096-bit" || error "Đã huỷ."
    if [ "$UI_ANSWER" -eq 1 ]; then KEY_TYPE="rsa"; else KEY_TYPE="ed25519"; fi

    ui_text "Tên file key trong ~/.ssh/ (đặt riêng nếu có nhiều key, vd id_github)" "id_$KEY_TYPE"
    KEY_FILE="$HOME/.ssh/$UI_ANSWER"

    ui_text "Comment / email cho key (vd you@example.com)" "$KEY_COMMENT"
    KEY_COMMENT="$UI_ANSWER"

    ui_note "ssh-agent + macOS Keychain" \
        "macOS tích hợp ssh-agent với Keychain: key giữ qua reboot," \
        "không cần ssh-add lại sau mỗi lần mở máy." \
        "Nhiều key: chạy setup mỗi key một lần, agent giữ tất cả." \
        "" \
        "${UI_DIM}Không thêm nếu muốn tự quản lý (ssh-add sau)${UI_RESET}" \
        "${UI_DIM}hoặc chỉ muốn unlock key khi cần.${UI_RESET}"
    if ui_confirm "Thêm key vào ssh-agent + Keychain sau khi tạo?" y; then
        ADD_TO_AGENT=true
    else
        ADD_TO_AGENT=false
    fi

    local agent_label="không"
    [ "$ADD_TO_AGENT" = true ] && agent_label="có"
    ui_note "Tóm tắt" \
        "Loại key  : $KEY_TYPE" \
        "File      : $KEY_FILE" \
        "Comment   : ${KEY_COMMENT:-(trống)}" \
        "ssh-agent : $agent_label"
    if ! ui_confirm "Tiếp tục?" y; then
        ui_module_end "Đã huỷ."
        exit 0
    fi
}

# ============================================================
# 1. Kiểm tra và tạo thư mục ~/.ssh
# ============================================================
setup_ssh_dir() {
    header "Kiểm tra thư mục ~/.ssh..."

    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        info "Đã tạo $HOME/.ssh với quyền 700."
    else
        chmod 700 "$HOME/.ssh"
        info "$HOME/.ssh đã tồn tại."
    fi
}

# ============================================================
# 2. Tạo SSH key pair
# ============================================================
generate_key() {
    header "Tạo SSH key ($KEY_TYPE)..."

    if [ -f "$KEY_FILE" ]; then
        warn "Key đã tồn tại: $KEY_FILE"
        if ! ui_confirm "Ghi đè key cũ? (key cũ sẽ được backup)" n; then
            info "Bỏ qua bước tạo key, dùng key hiện có."
            return
        fi
        local backup
        backup="${KEY_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$KEY_FILE" "$backup"
        mv "${KEY_FILE}.pub" "${backup}.pub" 2>/dev/null || true
        warn "Key cũ đã được backup: $backup"
    fi

    case "$KEY_TYPE" in
        ed25519) ui_run ssh-keygen -q -t ed25519 -f "$KEY_FILE" -C "$KEY_COMMENT" -N "" ;;
        rsa)     ui_run ssh-keygen -q -t rsa -b 4096 -f "$KEY_FILE" -C "$KEY_COMMENT" -N "" ;;
    esac

    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"

    info "Private key : $KEY_FILE"
    info "Public key  : ${KEY_FILE}.pub"
}

# ============================================================
# 3. Khởi động ssh-agent và thêm key
# ============================================================
add_to_agent() {
    if [ "$ADD_TO_AGENT" = false ]; then
        return
    fi

    header "Thêm key vào ssh-agent + Keychain..."

    # ssh-add -l: 0 = có key, 1 = agent chưa có key, 2 = không kết nối được agent
    local agent_status=0
    ssh-add -l >/dev/null 2>&1 || agent_status=$?

    if [ "$agent_status" -eq 2 ]; then
        eval "$(ssh-agent -s)" >/dev/null
        info "Đã khởi động ssh-agent (PID $SSH_AGENT_PID)."
    fi

    local fingerprint
    fingerprint="$(ssh-keygen -lf "${KEY_FILE}.pub" 2>/dev/null | cut -d' ' -f2)"
    if ssh-add -l 2>/dev/null | grep -qF "$fingerprint"; then
        info "Key đã có trong ssh-agent."
    else
        # --apple-use-keychain: lưu vào macOS Keychain (persistent qua reboot)
        ui_run ssh-add --apple-use-keychain "$KEY_FILE"
        info "Đã thêm key vào ssh-agent + Keychain."
    fi
}

# ============================================================
# 4. Cấu hình ~/.ssh/config
# ============================================================
configure_ssh_config() {
    if ! ui_confirm "Cấu hình ~/.ssh/config tự động?" y; then
        return
    fi

    header "Cấu hình ~/.ssh/config..."
    local config_file="$HOME/.ssh/config"

    if [ ! -f "$config_file" ]; then
        cat > "$config_file" <<EOF
# SSH Config - được tạo bởi ssh/setup_mac.sh

Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile $KEY_FILE
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 "$config_file"
        info "Đã tạo $config_file."
    elif grep -q "IdentityFile $KEY_FILE" "$config_file" 2>/dev/null; then
        info "$config_file đã được cấu hình cho key này."
    else
        warn "$config_file đã tồn tại và chưa có key này. Thêm thủ công nếu cần:
              IdentityFile $KEY_FILE"
    fi

    local lines=() line
    while IFS= read -r line || [ -n "$line" ]; do
        lines+=("$line")
    done <"$config_file"
    ui_note "~/.ssh/config" "${lines[@]}"

    ui_note "Thêm Host cho GitHub / server (open -e ~/.ssh/config)" \
        "Host github.com" \
        "    HostName github.com" \
        "    User git" \
        "    UseKeychain yes" \
        "    IdentityFile $KEY_FILE" \
        "" \
        "Host myserver" \
        "    HostName 192.168.1.100" \
        "    User ubuntu" \
        "    Port 22" \
        "    IdentityFile $KEY_FILE"
}

# ============================================================
# 5. In public key
# ============================================================
print_pubkey() {
    local pubkey_file="${KEY_FILE}.pub"

    header "Public key — copy và thêm vào GitHub / server"
    if [ ! -f "$pubkey_file" ]; then
        warn "Không tìm thấy public key: $pubkey_file"
        return
    fi

    local pubkey
    pubkey="$(cat "$pubkey_file")"

    # In nguyên dòng, không có viền │ để copy cho sạch
    printf '\n%s\n\n' "$pubkey"

    # pbcopy là built-in trên macOS
    echo "$pubkey" | pbcopy && info "Đã copy vào clipboard (pbcopy)."

    info "Xem lại        : cat $pubkey_file"
    info "Thêm vào GitHub: https://github.com/settings/keys"
    info "Thêm vào server: ssh-copy-id -i $pubkey_file user@host"
}

# ============================================================
# Main
# ============================================================
main() {
    ui_module_start "SSH key (macOS)"

    collect_config
    setup_ssh_dir
    generate_key
    add_to_agent
    configure_ssh_config
    print_pubkey

    ui_module_end "SSH key setup hoàn tất!"
}

main "$@"
