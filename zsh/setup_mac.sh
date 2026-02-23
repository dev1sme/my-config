#!/bin/bash
# ============================================================
# Zsh Setup Script - macOS
# Cài đặt Zsh, Oh My Zsh, plugins và set Zsh làm default shell
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
    Darwin) ;;  # OK
    Linux)  error "Bạn đang dùng Linux. Hãy chạy: ./zsh/setup.sh" ;;
    MINGW*|MSYS*|CYGWIN*)
            error "Windows không hỗ trợ Zsh native. Script này chỉ dành cho macOS/Linux." ;;
    *)      error "Hệ điều hành không được hỗ trợ: $(uname -s)" ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# Kiểm tra Homebrew
# ============================================================
check_homebrew() {
    if ! command -v brew &>/dev/null; then
        error "Homebrew chưa được cài đặt. Hãy cài Homebrew trước:
       /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
    info "Homebrew đã được cài đặt."
}

# ============================================================
# 1. Cài đặt Zsh
# ============================================================
install_zsh() {
    header "Kiểm tra Zsh..."
    if command -v zsh &>/dev/null; then
        info "Zsh đã được cài đặt: $(zsh --version)"
        # macOS mặc định đã có zsh, nhưng có thể cài bản mới hơn qua Homebrew
        local system_zsh="/bin/zsh"
        local brew_zsh="$(brew --prefix)/bin/zsh"
        if [ -x "$brew_zsh" ]; then
            info "Đang dùng Zsh từ Homebrew: $brew_zsh"
        else
            warn "Đang dùng Zsh hệ thống ($system_zsh). Cài bản mới hơn qua Homebrew? (tùy chọn)"
        fi
    else
        info "Đang cài đặt Zsh qua Homebrew..."
        brew install zsh
        info "Zsh đã được cài đặt thành công: $(zsh --version)"
    fi
}

# ============================================================
# 2. Đặt Zsh làm default shell
# ============================================================
set_default_shell() {
    header "Kiểm tra default shell..."
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
    header "Kiểm tra Oh My Zsh..."
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
    header "Kiểm tra fzf..."
    if command -v fzf &>/dev/null; then
        info "fzf đã được cài đặt."
    else
        info "Đang cài đặt fzf qua Homebrew..."
        brew install fzf
        # Cài key bindings và fuzzy completion
        "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish
        info "fzf đã được cài đặt thành công."
    fi
}

# ============================================================
# 5. Cài đặt custom plugins (external plugins)
# ============================================================
install_plugins() {
    header "Cài đặt plugins..."
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
    header "Cập nhật .zshrc..."
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
    echo "  Zsh + Oh My Zsh Setup Script (macOS)"
    echo "=========================================="
    echo ""

    check_homebrew
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
