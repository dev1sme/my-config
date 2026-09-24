#!/bin/bash
# ============================================================
# Docker Engine Setup Script
# Cài đặt Docker Engine, Docker Compose trên Linux
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

require_sudo || exit 1
USER_NAME="$(id -un)"

# ============================================================
# Detect distro
# Sets: DISTRO, DISTRO_VERSION, DISTRO_LIKE, INSTALL_METHOD, DOCKER_REPO, APT_CODENAME
# ============================================================
detect_distro() {
    if [ ! -f /etc/os-release ]; then
        error "Không thể xác định distro. File /etc/os-release không tồn tại."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="$ID"
    DISTRO_VERSION="${VERSION_ID:-}"
    DISTRO_LIKE="${ID_LIKE:-}"

    # Docker official repo chỉ có cho: ubuntu, debian, raspbian, fedora, rhel, centos.
    # Distro dẫn xuất dùng repo của distro gốc.
    case "$DISTRO" in
        ubuntu|debian|raspbian)
            INSTALL_METHOD="apt-repo"
            DOCKER_REPO="$DISTRO"
            APT_CODENAME="${VERSION_CODENAME:-}"
            ;;
        fedora)
            INSTALL_METHOD="rpm-repo"; DOCKER_REPO="fedora" ;;
        rhel)
            INSTALL_METHOD="rpm-repo"; DOCKER_REPO="rhel" ;;
        centos|rocky|almalinux|ol)
            INSTALL_METHOD="rpm-repo"; DOCKER_REPO="centos" ;;
        arch|manjaro|endeavouros|cachyos)
            INSTALL_METHOD="distro" ;;
        opensuse*|sles)
            INSTALL_METHOD="distro" ;;
        alpine)
            INSTALL_METHOD="distro" ;;
        *)
            case " $DISTRO_LIKE " in
                *" ubuntu "*)
                    # Mint, Pop!_OS, Zorin, elementary...: codename của Ubuntu gốc
                    INSTALL_METHOD="apt-repo"; DOCKER_REPO="ubuntu"
                    APT_CODENAME="${UBUNTU_CODENAME:-}"
                    ;;
                *" debian "*)
                    INSTALL_METHOD="apt-repo"; DOCKER_REPO="debian"
                    APT_CODENAME="${DEBIAN_CODENAME:-${VERSION_CODENAME:-}}"
                    ;;
                *" rhel "*|*" centos "*|*" fedora "*)
                    INSTALL_METHOD="rpm-repo"; DOCKER_REPO="centos" ;;
                *" arch "*|*" suse "*)
                    INSTALL_METHOD="distro" ;;
                *)
                    error "Distro '$DISTRO' chưa được hỗ trợ trong script này.
       Xem hướng dẫn: https://docs.docker.com/engine/install/"
                    ;;
            esac
            ;;
    esac

    if [ "$INSTALL_METHOD" = "apt-repo" ] && [ -z "$APT_CODENAME" ]; then
        error "Không xác định được codename cho repo Docker ($DISTRO)."
    fi

    info "Distro: $DISTRO $DISTRO_VERSION (cài qua: $INSTALL_METHOD${DOCKER_REPO:+, repo $DOCKER_REPO})"
}

# ============================================================
# Debian-based: official apt repository
# ============================================================
install_docker_apt() {
    header "Gỡ các package Docker cũ (nếu có)..."
    pkg_remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
    info "Đã dọn dẹp các package Docker cũ."

    header "Cài đặt dependencies..."
    ui_run pkg_install ca-certificates curl gnupg
    info "Dependencies đã sẵn sàng."

    header "Thêm Docker GPG key & repository..."
    $SUDO install -m 0755 -d /etc/apt/keyrings
    local gpg_key="/etc/apt/keyrings/docker.asc"
    if [ ! -f "$gpg_key" ]; then
        info "Download Docker GPG key..."
        $SUDO curl -fsSL "https://download.docker.com/linux/${DOCKER_REPO}/gpg" -o "$gpg_key"
        $SUDO chmod a+r "$gpg_key"
    else
        info "Docker GPG key đã tồn tại."
    fi

    local arch
    arch="$(dpkg --print-architecture)"
    echo "deb [arch=${arch} signed-by=${gpg_key}] https://download.docker.com/linux/${DOCKER_REPO} ${APT_CODENAME} stable" |
        $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
    ui_run $SUDO apt-get update -y
    info "Docker repository đã được thêm."

    header "Cài đặt Docker Engine..."
    ui_run pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# ============================================================
# RPM-based: official yum/dnf repository
# ============================================================
install_docker_rpm() {
    header "Gỡ các package Docker cũ (nếu có)..."
    pkg_remove docker docker-client docker-client-latest docker-common docker-latest \
        docker-latest-logrotate docker-logrotate docker-engine podman runc
    info "Đã dọn dẹp các package Docker cũ."

    header "Thêm Docker repository..."
    # Tải thẳng file .repo: chạy được với cả dnf4, dnf5 (Fedora 41+) và yum
    ui_run pkg_ensure_cmd curl
    $SUDO curl -fsSL "https://download.docker.com/linux/${DOCKER_REPO}/docker-ce.repo" \
        -o /etc/yum.repos.d/docker-ce.repo
    info "Docker repository đã được thêm."

    header "Cài đặt Docker Engine..."
    ui_run pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# ============================================================
# Arch / openSUSE / Alpine: package của distro
# ============================================================
install_docker_distro() {
    header "Cài đặt Docker Engine (package của distro)..."
    case "$PKG_MANAGER" in
        pacman) ui_run pkg_install docker docker-compose docker-buildx ;;
        zypper) ui_run pkg_install docker docker-compose docker-buildx ;;
        apk)    ui_run pkg_install docker docker-cli-compose docker-cli-buildx ;;
        *)      error "Không hỗ trợ cài Docker qua $PKG_MANAGER." ;;
    esac
}

# ============================================================
# Thêm user vào group docker (chạy không cần sudo)
# ============================================================
setup_docker_group() {
    header "Cấu hình Docker group..."

    # Root đã có toàn quyền, không cần thêm vào group
    if [ "$(id -u)" -eq 0 ]; then
        info "Đang chạy với root, bỏ qua cấu hình Docker group."
        return
    fi

    if ! getent group docker &>/dev/null; then
        $SUDO groupadd docker
        info "Đã tạo group 'docker'."
    fi

    if id -nG "$USER_NAME" | grep -qw docker; then
        info "User '$USER_NAME' đã thuộc group 'docker'."
    else
        $SUDO usermod -aG docker "$USER_NAME"
        info "Đã thêm user '$USER_NAME' vào group 'docker'."
        warn "Cần logout/login lại để chạy Docker không cần sudo."
    fi
}

# ============================================================
# Bật Docker service tự khởi động (systemd hoặc OpenRC)
# ============================================================
enable_docker_service() {
    header "Bật Docker service..."

    if [ -d /run/systemd/system ]; then
        $SUDO systemctl enable --now containerd.service 2>/dev/null || true
        ui_run $SUDO systemctl enable --now docker.service
        if $SUDO systemctl is-active --quiet docker; then
            info "Docker service đang chạy."
        else
            error "Docker service không thể khởi động!"
        fi
    elif command -v rc-update &>/dev/null; then
        $SUDO rc-update add docker default
        $SUDO rc-service docker start || warn "Không start được docker (OpenRC)."
    else
        warn "Không phát hiện systemd/OpenRC (container?). Bỏ qua bật service."
    fi
}

# ============================================================
# Kiểm tra cài đặt
# ============================================================
verify_installation() {
    header "Kiểm tra cài đặt..."

    info "Docker: $(docker --version)"
    info "Compose: $(docker compose version 2>/dev/null || echo 'không lấy được version')"

    info "Chạy test container hello-world..."
    if $SUDO docker run --rm hello-world >/dev/null 2>&1; then
        info "✓ Docker hoạt động bình thường!"
    else
        warn "Không thể chạy test container. Kiểm tra lại Docker service."
    fi
}

# ============================================================
# Main
# ============================================================
main() {
    ui_module_start "Docker Engine + Compose"

    if [ "$(id -u)" -eq 0 ]; then
        info "Đang chạy với quyền root, không dùng sudo."
    fi

    pkg_detect || error "Không tìm thấy package manager hỗ trợ."
    header "Kiểm tra distro..."
    detect_distro

    case "$INSTALL_METHOD" in
        apt-repo) install_docker_apt ;;
        rpm-repo) install_docker_rpm ;;
        distro)   install_docker_distro ;;
    esac
    info "Docker Engine đã được cài đặt: $(docker --version)"

    setup_docker_group
    enable_docker_service
    verify_installation

    ui_section "Hoàn tất"
    ui_log "Đã cài: Docker Engine + CLI, containerd, Buildx, Compose v2"
    ui_log "Lệnh test: docker run hello-world"
    if [ "$(id -u)" -ne 0 ]; then
        warn "Logout/login lại để chạy Docker không cần sudo."
    fi
    ui_module_end "Docker setup hoàn tất!"
}

main "$@"
