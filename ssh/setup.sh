#!/bin/bash
# ============================================================
# SSH Key Setup Script
# Tạo SSH key pair, cấu hình ssh-agent và authorized_keys
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()   { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header() { echo -e "${BLUE}[====]${NC} $1"; }

# ============================================================
# Kiểm tra hệ điều hành
# ============================================================
case "$(uname -s)" in
    Linux)  ;;  # OK
    Darwin) error "Bạn đang dùng macOS. Hãy chạy: ./ssh/setup_mac.sh" ;;
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
PRINT_PUBKEY=true

# Helper: đọc input với giá trị mặc định
# Usage: prompt_input "Câu hỏi" "default" -> kết quả lưu vào $REPLY
prompt_input() {
    local question="$1"
    local default="$2"
    echo -ne "${BLUE}  ?${NC} ${question}"
    if [ -n "$default" ]; then
        echo -ne " ${YELLOW}[${default}]${NC}: "
    else
        echo -ne ": "
    fi
    read -r REPLY
    if [ -z "$REPLY" ]; then
        REPLY="$default"
    fi
}

# Helper: yes/no prompt
# Usage: prompt_yn "Câu hỏi" "y" -> trả về 0 (yes) hoặc 1 (no)
prompt_yn() {
    local question="$1"
    local default="${2:-y}"
    local hint
    if [[ "$default" =~ ^[Yy]$ ]]; then hint="Y/n"; else hint="y/N"; fi
    echo -ne "${BLUE}  ?${NC} ${question} ${YELLOW}[${hint}]${NC}: "
    read -r REPLY
    if [ -z "$REPLY" ]; then REPLY="$default"; fi
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# ============================================================
# Bước 0: Thu thập cấu hình từ người dùng (interactive)
# ============================================================
collect_config() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  Cấu hình SSH Key${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""

    # --- Key type ---
    echo -e "  Loại key được hỗ trợ:"
    echo -e "    ${YELLOW}1${NC}) ed25519  ${GREEN}(khuyên dùng)${NC}"
    echo -e "    ${YELLOW}2${NC}) rsa      (4096-bit)"
    echo -ne "${BLUE}  ?${NC} Chọn loại key ${YELLOW}[1]${NC}: "
    read -r _choice
    case "$_choice" in
        2|rsa) KEY_TYPE="rsa" ;;
        *)     KEY_TYPE="ed25519" ;;
    esac
    info "Loại key: $KEY_TYPE"
    echo ""

    # --- Key file ---
    local default_name
    if [ "$KEY_TYPE" = "rsa" ]; then
        default_name="id_rsa"
    else
        default_name="id_ed25519"
    fi
    echo -e "  ${YELLOW}Tip:${NC} Đặt tên riêng nếu bạn có nhiều key, vd: ${YELLOW}id_github${NC}, ${YELLOW}id_work${NC}"
    prompt_input "Tên file key (lưu vào ~/.ssh/)" "$default_name"
    KEY_FILE="$HOME/.ssh/$REPLY"
    info "File key: $KEY_FILE"
    echo ""

    # --- Comment ---
    echo -e "  ${YELLOW}Tip:${NC} Nên dùng email để dễ nhận diện key, vd: ${YELLOW}you@example.com${NC}"
    prompt_input "Comment / email cho key" "$KEY_COMMENT"
    KEY_COMMENT="$REPLY"
    info "Comment: $KEY_COMMENT"
    echo ""

    # --- Add to agent ---
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  Thêm key vào ssh-agent?${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}ssh-agent${NC} là gì?"
    echo    "    Chương trình chạy ngầm, giữ private key đã unlock trong RAM."
    echo    "    Giúp bạn không cần nhập passphrase mỗi lần dùng SSH."
    echo ""
    echo -e "  ${GREEN}[Y] Thêm vào ssh-agent${NC} ${GREEN}(khuyên dùng)${NC}"
    echo    "      Key được load sẵn → ssh/git dùng ngay, không hỏi passphrase."
    echo    "      Nếu có nhiều key, mỗi key chạy setup một lần → agent giữ tất cả."
    echo ""
    echo -e "  ${YELLOW}[N] Không thêm${NC}"
    echo    "      Phù hợp nếu bạn muốn quản lý key thủ công (ssh-add sau)."
    echo    "      Hoặc nếu dùng passphrase và chỉ muốn unlock khi cần."
    echo ""
    if prompt_yn "Thêm key vào ssh-agent sau khi tạo?" "y"; then
        ADD_TO_AGENT=true
        info "Sẽ thêm vào ssh-agent."
    else
        ADD_TO_AGENT=false
        info "Bỏ qua ssh-agent. Thêm thủ công sau bằng: ssh-add $KEY_FILE"
    fi
    echo ""

    echo -e "${BLUE}============================================================${NC}"
    echo -e "  Tóm tắt:"
    echo -e "    Loại key  : ${YELLOW}$KEY_TYPE${NC}"
    echo -e "    File      : ${YELLOW}$KEY_FILE${NC}"
    echo -e "    Comment   : ${YELLOW}$KEY_COMMENT${NC}"
    local agent_label
    if [ "$ADD_TO_AGENT" = true ]; then agent_label="có"; else agent_label="không"; fi
    echo -e "    ssh-agent : ${YELLOW}${agent_label}${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    if ! prompt_yn "Tiếp tục?" "y"; then
        info "Đã huỷ."
        exit 0
    fi
    echo ""
}

# ============================================================
# 1. Kiểm tra và tạo thư mục ~/.ssh
# ============================================================
setup_ssh_dir() {
    header "Kiểm tra thư mục ~/.ssh..."

    if [ ! -d "$HOME/.ssh" ]; then
        info "Tạo thư mục $HOME/.ssh..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        info "Đã tạo $HOME/.ssh với quyền 700."
    else
        info "$HOME/.ssh đã tồn tại."
        # Đảm bảo quyền đúng
        chmod 700 "$HOME/.ssh"
    fi
}

# ============================================================
# 2. Tạo SSH key pair
# ============================================================
generate_key() {
    header "Tạo SSH key ($KEY_TYPE)..."

    if [ -f "$KEY_FILE" ]; then
        warn "Key đã tồn tại: $KEY_FILE"
        echo -n "Ghi đè key cũ? [y/N] "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Bỏ qua bước tạo key."
            return
        fi
        # Backup key cũ
        local backup="${KEY_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$KEY_FILE" "$backup"
        mv "${KEY_FILE}.pub" "${backup}.pub" 2>/dev/null || true
        warn "Key cũ đã được backup: $backup"
    fi

    info "Đang tạo key: $KEY_FILE ($KEY_TYPE)..."

    case "$KEY_TYPE" in
        ed25519)
            ssh-keygen -t ed25519 -f "$KEY_FILE" -C "$KEY_COMMENT" -N ""
            ;;
        rsa)
            ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -C "$KEY_COMMENT" -N ""
            ;;
    esac

    chmod 600 "$KEY_FILE"
    chmod 644 "${KEY_FILE}.pub"

    info "Đã tạo key thành công:"
    info "  Private key : $KEY_FILE"
    info "  Public key  : ${KEY_FILE}.pub"
}

# ============================================================
# 3. Khởi động ssh-agent và thêm key
# ============================================================
add_to_agent() {
    if [ "$ADD_TO_AGENT" = false ]; then
        return
    fi

    header "Thêm key vào ssh-agent..."

    # Kiểm tra agent có thực sự chạy không (ssh-add -l trả về 2 = không kết nối được)
    local agent_status
    ssh-add -l &>/dev/null; agent_status=$?

    if [ "$agent_status" -eq 2 ]; then
        info "Khởi động ssh-agent..."
        eval "$(ssh-agent -s)" &>/dev/null
        info "ssh-agent đã khởi động (PID $SSH_AGENT_PID)."
    fi

    if ssh-add -l 2>/dev/null | grep -qF "$(ssh-keygen -lf "${KEY_FILE}.pub" 2>/dev/null | awk '{print $2}')"; then
        info "Key đã có trong ssh-agent."
    else
        ssh-add "$KEY_FILE"
        info "Đã thêm key vào ssh-agent."
    fi
}

# ============================================================
# 4. Cấu hình ~/.ssh/config
# ============================================================
configure_ssh_config() {
    header "Cấu hình ~/.ssh/config..."

    if ! prompt_yn "Cấu hình ~/.ssh/config tự động?" "y"; then
        info "Bỏ qua bước cấu hình ~/.ssh/config."
        return
    fi

    local config_file="$HOME/.ssh/config"

    if [ ! -f "$config_file" ]; then
        info "Tạo file $config_file..."
        cat > "$config_file" <<EOF
# SSH Config - được tạo bởi ssh/setup.sh

Host *
    AddKeysToAgent yes
    IdentityFile $KEY_FILE
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 "$config_file"
        info "Đã tạo $config_file."
    else
        # Kiểm tra xem IdentityFile đã có chưa
        if grep -q "IdentityFile $KEY_FILE" "$config_file" 2>/dev/null; then
            info "$config_file đã được cấu hình cho key này."
        else
            warn "$config_file đã tồn tại và chưa có IdentityFile $KEY_FILE."
            warn "Thêm thủ công dòng sau vào $config_file nếu cần:"
            echo ""
            echo "    IdentityFile $KEY_FILE"
            echo ""
        fi
    fi

    # Hiển thị nội dung config và hướng dẫn mở/chỉnh sửa
    echo ""
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo -e "${GREEN}  Nội dung ~/.ssh/config hiện tại${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    cat "$config_file"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo ""
    echo -e "  ${YELLOW}Để chỉnh sửa thêm (thêm Host cho từng server/GitHub):${NC}"
    echo ""
    echo -e "    ${GREEN}nano${NC}  ~/.ssh/config"
    echo -e "    ${GREEN}code${NC}  ~/.ssh/config"
    echo ""
    echo -e "  ${YELLOW}Ví dụ thêm Host cho GitHub:${NC}"
    echo ""
    echo    "    Host github.com"
    echo    "        HostName github.com"
    echo    "        User git"
    echo    "        AddKeysToAgent yes"
    echo    "        IdentityFile $KEY_FILE"
    echo ""
    echo -e "  ${YELLOW}Ví dụ thêm Host cho server:${NC}"
    echo ""
    echo    "    Host myserver"
    echo    "        HostName 192.168.1.100"
    echo    "        User ubuntu"
    echo    "        AddKeysToAgent yes"
    echo    "        IdentityFile $KEY_FILE"
    echo    "        Port 22"
    echo ""
}

# ============================================================
# 5. In public key
# ============================================================
print_pubkey() {
    if [ "$PRINT_PUBKEY" = false ]; then
        return
    fi

    local pubkey_file="${KEY_FILE}.pub"

    if [ ! -f "$pubkey_file" ]; then
        warn "Không tìm thấy public key: $pubkey_file"
        return
    fi

    local pubkey
    pubkey="$(cat "$pubkey_file")"

    echo ""
    echo "============================================================"
    echo "  PUBLIC KEY - Copy và thêm vào GitHub / server"
    echo "============================================================"
    echo "$pubkey"
    echo "============================================================"
    echo ""
    echo -e "  ${YELLOW}Xem lại bất cứ lúc nào:${NC}"
    echo "    cat ${pubkey_file}"
    echo ""

    # Thử copy vào clipboard nếu có xclip / xsel / pbcopy
    if command -v xclip &>/dev/null; then
        echo "$pubkey" | xclip -selection clipboard
        info "Public key đã được copy vào clipboard (xclip)."
    elif command -v xsel &>/dev/null; then
        echo "$pubkey" | xsel --clipboard --input
        info "Public key đã được copy vào clipboard (xsel)."
    elif command -v pbcopy &>/dev/null; then
        echo "$pubkey" | pbcopy
        info "Public key đã được copy vào clipboard (pbcopy)."
    fi

    info "Thêm vào GitHub  : https://github.com/settings/keys"
    info "Thêm vào server  : ssh-copy-id -i ${pubkey_file} user@host"
}

# ============================================================
# Main
# ============================================================
main() {
    header "SSH Key Setup"
    collect_config

    setup_ssh_dir
    generate_key
    add_to_agent
    configure_ssh_config
    print_pubkey

    echo ""
    info "SSH key setup hoàn tất!"
}

main "$@"
