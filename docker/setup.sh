#!/bin/bash
# ============================================================
# Docker Engine Setup Script
# Cài đặt Docker Engine, Docker Compose trên Linux
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header() { echo -e "${BLUE}[====]${NC} $1"; }

# Dùng sudo khi không phải root, bỏ qua khi đã là root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ============================================================
# Detect distro
# ============================================================
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_CODENAME="$VERSION_CODENAME"
    else
        error "Không thể xác định distro. File /etc/os-release không tồn tại."
    fi

    info "Distro: $DISTRO $DISTRO_VERSION ($DISTRO_CODENAME)"
}

# ============================================================
# 1. Gỡ các package Docker cũ/không chính thức
# ============================================================
remove_old_docker() {
    header "Gỡ các package Docker cũ (nếu có)..."

    local old_packages=(
        docker.io
        docker-doc
        docker-compose
        docker-compose-v2
        podman-docker
        containerd
        runc
    )

    for pkg in "${old_packages[@]}"; do
        if dpkg -l "$pkg" &>/dev/null 2>&1; then
            warn "Gỡ package cũ: $pkg"
            $SUDO apt-get remove -y "$pkg" >/dev/null 2>&1 || true
        fi
    done

    info "Đã dọn dẹp các package Docker cũ."
}

# ============================================================
# 2. Cài đặt dependencies
# ============================================================
install_dependencies() {
    header "Cài đặt dependencies..."

    $SUDO apt-get update -y
    $SUDO apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    info "Dependencies đã sẵn sàng."
}

# ============================================================
# 3. Thêm Docker GPG key & repository
# ============================================================
setup_docker_repo() {
    header "Thêm Docker GPG key & repository..."

    # Tạo thư mục keyrings
    $SUDO install -m 0755 -d /etc/apt/keyrings

    local gpg_key="/etc/apt/keyrings/docker.asc"

    # Download GPG key
    if [ ! -f "$gpg_key" ]; then
        info "Download Docker GPG key..."
        $SUDO curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" -o "$gpg_key"
        $SUDO chmod a+r "$gpg_key"
    else
        info "Docker GPG key đã tồn tại."
    fi

    # Thêm repository
    local repo_file="/etc/apt/sources.list.d/docker.list"
    local arch
    arch="$(dpkg --print-architecture)"

    echo "deb [arch=${arch} signed-by=${gpg_key}] https://download.docker.com/linux/${DISTRO} ${DISTRO_CODENAME} stable" | \
        $SUDO tee "$repo_file" > /dev/null

    $SUDO apt-get update -y

    info "Docker repository đã được thêm."
}

# ============================================================
# 4. Cài đặt Docker Engine
# ============================================================
install_docker_engine() {
    header "Cài đặt Docker Engine..."

    if command -v docker &>/dev/null; then
        info "Docker đã được cài đặt: $(docker --version)"
        warn "Cài đặt lại/cập nhật Docker Engine..."
    fi

    $SUDO apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    info "Docker Engine đã được cài đặt: $(docker --version)"
    info "Docker Compose: $(docker compose version)"
}

# ============================================================
# 5. Thêm user vào group docker (chạy không cần sudo)
# ============================================================
setup_docker_group() {
    header "Cấu hình Docker group..."

    # Root đã có toàn quyền, không cần thêm vào group
    if [ "$EUID" -eq 0 ]; then
        info "Đang chạy với root, bỏ qua cấu hình Docker group."
        return
    fi

    # Tạo group docker nếu chưa có
    if ! getent group docker &>/dev/null; then
        $SUDO groupadd docker
        info "Đã tạo group 'docker'."
    fi

    # Thêm user hiện tại vào group
    if id -nG "$USER" | grep -qw docker; then
        info "User '$USER' đã thuộc group 'docker'."
    else
        $SUDO usermod -aG docker "$USER"
        info "Đã thêm user '$USER' vào group 'docker'."
        warn "Cần logout/login lại để chạy Docker không cần sudo."
    fi
}

# ============================================================
# 6. Bật Docker service tự khởi động
# ============================================================
enable_docker_service() {
    header "Bật Docker service..."

    $SUDO systemctl enable docker.service
    $SUDO systemctl enable containerd.service
    $SUDO systemctl start docker.service

    if $SUDO systemctl is-active --quiet docker; then
        info "Docker service đang chạy."
    else
        error "Docker service không thể khởi động!"
    fi
}

# ============================================================
# 7. Kiểm tra cài đặt
# ============================================================
verify_installation() {
    header "Kiểm tra cài đặt..."

    echo ""
    info "Docker version:"
    docker --version
    echo ""
    info "Docker Compose version:"
    docker compose version
    echo ""
    info "Containerd version:"
    containerd --version 2>/dev/null || echo "  (không lấy được version)"
    echo ""

    # Test chạy hello-world (cần sudo nếu chưa logout/login)
    info "Chạy test container hello-world..."
    if $SUDO docker run --rm hello-world >/dev/null 2>&1; then
        info "✓ Docker hoạt động bình thường!"
    else
        warn "Không thể chạy test container. Kiểm tra lại Docker service."
    fi
}

# ============================================================
# Hỗ trợ Fedora / RHEL / CentOS
# ============================================================
install_docker_rpm() {
    header "Cài đặt Docker Engine (RPM-based)..."

    # Gỡ package cũ
    $SUDO dnf remove -y docker docker-client docker-client-latest \
        docker-common docker-latest docker-latest-logrotate \
        docker-logrotate docker-engine podman runc 2>/dev/null || true

    # Cài dependencies
    $SUDO dnf install -y dnf-plugins-core

    # Thêm repo
    $SUDO dnf config-manager --add-repo "https://download.docker.com/linux/${DISTRO}/docker-ce.repo"

    # Cài Docker
    $SUDO dnf install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    info "Docker Engine đã được cài đặt: $(docker --version)"
}

# ============================================================
# Main
# ============================================================
main() {
    echo "=========================================="
    echo "  Docker Engine Setup Script"
    echo "=========================================="
    echo ""

    # Cảnh báo nếu chạy bằng root
    if [ "$EUID" -eq 0 ]; then
        warn "Đang chạy với quyền root. Bỏ qua sudo."
    fi

    detect_distro

    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            remove_old_docker
            install_dependencies
            setup_docker_repo
            install_docker_engine
            ;;
        fedora)
            install_docker_rpm
            ;;
        centos|rhel|rocky|alma)
            install_docker_rpm
            ;;
        *)
            error "Distro '$DISTRO' chưa được hỗ trợ trong script này.
       Xem hướng dẫn: https://docs.docker.com/engine/install/"
            ;;
    esac

    setup_docker_group
    enable_docker_service
    verify_installation

    echo ""
    echo "=========================================="
    info "Cài đặt Docker Engine hoàn tất!"
    echo "=========================================="
    echo ""
    echo "  Đã cài đặt:"
    echo "    - Docker Engine (docker-ce)"
    echo "    - Docker CLI (docker-ce-cli)"
    echo "    - Containerd (containerd.io)"
    echo "    - Docker Buildx"
    echo "    - Docker Compose Plugin (v2)"
    echo ""
    if [ "$EUID" -ne 0 ]; then
        warn "Hãy logout và login lại để chạy Docker không cần sudo."
    fi
    echo ""
    echo "  Lệnh test: docker run hello-world"
    echo ""
}

main "$@"
