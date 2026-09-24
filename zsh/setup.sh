#!/bin/bash
# ============================================================
# Zsh Setup Script
# Cài đặt Zsh, Oh My Zsh, plugins và set Zsh làm default shell
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../lib/sh/ui.sh
. "$SCRIPT_DIR/../lib/sh/ui.sh"
# shellcheck source=../lib/sh/pkg.sh
. "$SCRIPT_DIR/../lib/sh/pkg.sh"

info()   { ui_log "$1"; }
warn()   { ui_log_warn "$1"; }
error()  { ui_fail "$1"; }
header() { ui_section "$1"; }

# ============================================================
# Kiểm tra hệ điều hành
# ============================================================
case "$(uname -s)" in
    Linux)  ;;  # OK
    Darwin) error "Bạn đang dùng macOS. Hãy chạy: ./zsh/setup_mac.sh" ;;
    MINGW*|MSYS*|CYGWIN*)
            error "Windows không hỗ trợ Zsh native. Script này chỉ dành cho macOS/Linux." ;;
    *)      error "Hệ điều hành không được hỗ trợ: $(uname -s)" ;;
esac

require_sudo || exit 1
USER_NAME="$(id -un)"

# ============================================================
# 1. Cài đặt Zsh
# ============================================================
install_zsh() {
    header "Kiểm tra Zsh..."
    if command -v zsh &>/dev/null; then
        info "Zsh đã được cài đặt: $(zsh --version)"
    else
        info "Đang cài đặt Zsh..."
        ui_run pkg_install zsh || error "Không cài được Zsh. Hãy cài thủ công."
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

    # Shell trong /etc/passwd (chính xác hơn $SHELL của session hiện tại)
    local current_shell
    current_shell="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f7)"
    current_shell="${current_shell:-$SHELL}"

    if [ "$current_shell" = "$zsh_path" ]; then
        info "Zsh đã là default shell."
    else
        info "Đặt Zsh ($zsh_path) làm default shell..."

        # Đảm bảo zsh có trong /etc/shells
        if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
            warn "Thêm $zsh_path vào /etc/shells..."
            echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null
        fi

        # usermod (qua sudo) không hỏi lại mật khẩu như chsh.
        # Alpine/minimal image không có sẵn -> cài package shadow.
        if ! command -v usermod &>/dev/null && ! command -v chsh &>/dev/null; then
            ui_run pkg_install shadow || true
        fi
        if command -v usermod &>/dev/null; then
            $SUDO usermod -s "$zsh_path" "$USER_NAME"
        elif command -v chsh &>/dev/null; then
            chsh -s "$zsh_path"
        else
            warn "Không có usermod/chsh. Đổi shell thủ công: chsh -s $zsh_path"
            return
        fi
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
        ui_run pkg_ensure_cmd curl || error "Không cài được curl."
        ui_run pkg_ensure_cmd git || error "Không cài được git."
        ui_run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
        info "Đang cài đặt fzf..."
        if ! ui_run pkg_install fzf; then
            # Distro không có package fzf -> cài từ git
            warn "Không cài được fzf qua package manager, cài từ git..."
            ui_run git clone -q --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ui_run ~/.fzf/install --all
        fi
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
        ui_run git clone -q https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        info "zsh-autosuggestions đã được cài đặt."
    fi

    # zsh-syntax-highlighting
    if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        info "Plugin zsh-syntax-highlighting đã tồn tại."
    else
        info "Đang cài đặt zsh-syntax-highlighting..."
        ui_run git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
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
    ui_module_start "Zsh + Oh My Zsh"

    install_zsh
    set_default_shell
    install_ohmyzsh
    install_fzf
    install_plugins
    copy_zshrc

    ui_section "Hoàn tất"
    ui_log "Plugins: git, zsh-autosuggestions, zsh-syntax-highlighting, docker,"
    ui_log "         docker-compose, history, rsync, safe-paste, fzf"
    ui_log "Theme: strug"
    ui_log_warn "Logout/login lại (hoặc chạy 'exec zsh') để áp dụng cấu hình mới."
    ui_module_end "Zsh setup hoàn tất!"
}

main "$@"
