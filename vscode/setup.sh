#!/bin/bash
# ============================================================
# VS Code Setup Script
# Cài đặt extensions và cấu hình settings cho VS Code
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
    Darwin) error "Bạn đang dùng macOS. Hãy chạy: ./vscode/setup_mac.sh" ;;
    MINGW*|MSYS*|CYGWIN*)
            error "Bạn đang dùng Windows. Hãy chạy: .\\vscode\\setup.ps1  (PowerShell)" ;;
    *)      error "Hệ điều hành không được hỗ trợ: $(uname -s)" ;;
esac

EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"
SETTINGS_FILE="$SCRIPT_DIR/setting.json"

# ============================================================
# VS Code settings path (Linux)
# ============================================================
get_vscode_settings_dir() {
    echo "$HOME/.config/Code/User"
}

# ============================================================
# 1. Kiểm tra VS Code đã cài chưa
# ============================================================
check_vscode() {
    header "Kiểm tra VS Code..."
    if command -v code &>/dev/null; then
        info "VS Code đã được cài đặt: $(code --version | head -1)"
    else
        error "VS Code chưa được cài đặt. Hãy cài VS Code trước khi chạy script này.
       Download: https://code.visualstudio.com/download"
    fi
}

# ============================================================
# 2. Cài đặt Extensions
# ============================================================
install_extensions() {
    header "Cài đặt VS Code Extensions..."

    if [ ! -f "$EXTENSIONS_FILE" ]; then
        error "Không tìm thấy file $EXTENSIONS_FILE"
    fi

    local total=0
    local installed=0
    local failed=0
    local skipped=0

    # Đọc danh sách extensions đã cài
    local current_extensions
    current_extensions=$(code --list-extensions 2>/dev/null)

    while IFS= read -r ext || [ -n "$ext" ]; do
        # Bỏ qua dòng trống và comment
        ext=$(echo "$ext" | xargs)
        [[ -z "$ext" || "$ext" == \#* ]] && continue

        total=$((total + 1))

        # Kiểm tra extension đã cài chưa (case-insensitive)
        if echo "$current_extensions" | grep -qi "^${ext}$"; then
            ui_log "${UI_DIM}✓ Đã có: $ext${UI_RESET}"
            skipped=$((skipped + 1))
        else
            if code --install-extension "$ext" --force >/dev/null 2>&1; then
                ui_log "${UI_GREEN}✔${UI_RESET} Đã cài: $ext"
                installed=$((installed + 1))
            else
                ui_log_error "Lỗi: $ext"
                failed=$((failed + 1))
            fi
        fi
    done < "$EXTENSIONS_FILE"

    info "Tổng: $total · Đã có: $skipped · Mới cài: $installed · Lỗi: $failed"
}

# ============================================================
# 3. Cấu hình Settings
# ============================================================
setup_settings() {
    header "Cấu hình VS Code Settings..."

    if [ ! -f "$SETTINGS_FILE" ]; then
        error "Không tìm thấy file $SETTINGS_FILE"
    fi

    local vscode_dir
    vscode_dir="$(get_vscode_settings_dir)"
    local target_settings="$vscode_dir/settings.json"

    # Tạo thư mục settings nếu chưa có
    mkdir -p "$vscode_dir"

    # Backup settings cũ nếu có
    if [ -f "$target_settings" ]; then
        local backup="$target_settings.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Backup settings cũ -> $backup"
        cp "$target_settings" "$backup"
    fi

    # Copy settings mới
    cp "$SETTINGS_FILE" "$target_settings"
    info "Settings đã được cập nhật tại: $target_settings"
}

# ============================================================
# 4. Export extensions hiện tại (tiện ích)
# ============================================================
export_current_extensions() {
    header "Export danh sách extensions hiện tại..."
    local export_file="$SCRIPT_DIR/extensions.txt"
    code --list-extensions > "$export_file"
    info "Đã export $(wc -l < "$export_file") extensions vào: $export_file"
}

# ============================================================
# Menu & Main
# ============================================================
show_help() {
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --all          Cài đặt extensions + settings (mặc định)"
    echo "  --extensions   Chỉ cài đặt extensions"
    echo "  --settings     Chỉ cấu hình settings"
    echo "  --export       Export danh sách extensions hiện tại"
    echo "  --help         Hiển thị help"
    echo ""
}

main() {
    ui_module_start "VS Code"

    check_vscode

    local action="${1:---all}"

    case "$action" in
        --all)
            install_extensions
            setup_settings
            ;;
        --extensions)
            install_extensions
            ;;
        --settings)
            setup_settings
            ;;
        --export)
            export_current_extensions
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            warn "Option không hợp lệ: $action"
            show_help
            exit 1
            ;;
    esac

    ui_module_end "Hoàn tất! Khởi động lại VS Code để áp dụng thay đổi."
}

main "$@"
