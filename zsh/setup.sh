#!/bin/bash
# ============================================================
# Zsh Setup Script
# Cài đặt Zsh, Oh My Zsh, plugins và set Zsh làm default shell
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# 1. Cài đặt Zsh
# ============================================================
install_zsh() {
    if command -v zsh &>/dev/null; then
        info "Zsh đã được cài đặt: $(zsh --version)"
    else
        info "Đang cài đặt Zsh..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y zsh
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y zsh
        elif command -v yum &>/dev/null; then
            sudo yum install -y zsh
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm zsh
        elif command -v brew &>/dev/null; then
            brew install zsh
        else
            error "Không tìm thấy package manager phù hợp. Hãy cài Zsh thủ công."
        fi
        info "Zsh đã được cài đặt thành công: $(zsh --version)"
    fi
}

# ============================================================
# 2. Đặt Zsh làm default shell
# ============================================================
set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"

    if [ "$SHELL" = "$zsh_path" ]; then
        info "Zsh đã là default shell."
    else
        info "Đặt Zsh ($zsh_path) làm default shell..."

        # Đảm bảo zsh có trong /etc/shells
        if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
            warn "Thêm $zsh_path vào /etc/shells..."
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi

        chsh -s "$zsh_path"
        info "Default shell đã được đổi sang Zsh. Hãy logout/login lại để có hiệu lực."
    fi
}

# ============================================================
# 3. Cài đặt Oh My Zsh
# ============================================================
install_ohmyzsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        info "Oh My Zsh đã được cài đặt."
    else
        info "Đang cài đặt Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        info "Oh My Zsh đã được cài đặt thành công."
    fi
}

# ============================================================
# 4. Cài đặt fzf (dependency cho fzf plugin)
# ============================================================
install_fzf() {
    if command -v fzf &>/dev/null; then
        info "fzf đã được cài đặt."
    else
        info "Đang cài đặt fzf..."
        if command -v apt &>/dev/null; then
            sudo apt install -y fzf
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y fzf
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm fzf
        elif command -v brew &>/dev/null; then
            brew install fzf
        else
            # Cài từ git nếu không có package manager
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ~/.fzf/install --all
        fi
        info "fzf đã được cài đặt thành công."
    fi
}

# ============================================================
# 5. Cài đặt custom plugins (external plugins)
# ============================================================
install_plugins() {
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh-autosuggestions
    if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        info "Plugin zsh-autosuggestions đã tồn tại."
    else
        info "Đang cài đặt zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        info "zsh-autosuggestions đã được cài đặt."
    fi

    # zsh-syntax-highlighting
    if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        info "Plugin zsh-syntax-highlighting đã tồn tại."
    else
        info "Đang cài đặt zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        info "zsh-syntax-highlighting đã được cài đặt."
    fi

    info "Các plugin built-in (git, docker, docker-compose, history, rsync, safe-paste, fzf) đã có sẵn trong Oh My Zsh."
}

# ============================================================
# 6. Copy file .zshrc
# ============================================================
copy_zshrc() {
    local zshrc_src="$SCRIPT_DIR/.zshrc"

    if [ ! -f "$zshrc_src" ]; then
        error "Không tìm thấy file .zshrc trong $SCRIPT_DIR"
    fi

    # Backup .zshrc cũ nếu có
    if [ -f "$HOME/.zshrc" ]; then
        local backup="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Backup .zshrc cũ -> $backup"
        cp "$HOME/.zshrc" "$backup"
    fi

    info "Copy .zshrc vào $HOME/.zshrc..."
    cp "$zshrc_src" "$HOME/.zshrc"
    info ".zshrc đã được cập nhật."
}

# ============================================================
# Main
# ============================================================
main() {
    echo "=========================================="
    echo "  Zsh + Oh My Zsh Setup Script"
    echo "=========================================="
    echo ""

    install_zsh
    set_default_shell
    install_ohmyzsh
    install_fzf
    install_plugins
    copy_zshrc

    echo ""
    echo "=========================================="
    info "Cài đặt hoàn tất!"
    echo "=========================================="
    echo ""
    echo "Plugins đã cài đặt:"
    echo "  - git (built-in)"
    echo "  - zsh-autosuggestions (external)"
    echo "  - docker (built-in)"
    echo "  - docker-compose (built-in)"
    echo "  - history (built-in)"
    echo "  - rsync (built-in)"
    echo "  - safe-paste (built-in)"
    echo "  - fzf (built-in + fzf binary)"
    echo "  - zsh-syntax-highlighting (external)"
    echo ""
    echo "Theme: strug"
    echo ""
    warn "Hãy logout và login lại (hoặc chạy 'exec zsh') để áp dụng cấu hình mới."
}

main "$@"
