# 🛠️ my-config

Bộ script tự động cài đặt và cấu hình môi trường phát triển trên Linux.

## 📁 Cấu trúc

```
my-config/
├── docker/
│   └── setup.sh              # Cài đặt Docker Engine + Docker Compose
├── vscode/
│   ├── setting.json           # Cấu hình VS Code settings
│   ├── extensions.txt         # Danh sách extensions
│   └── setup.sh              # Cài extensions + apply settings
├── zsh/
│   ├── .zshrc                 # File cấu hình Zsh
│   └── setup.sh              # Cài Zsh + Oh My Zsh + plugins
└── README.md
```

## 🚀 Hướng dẫn sử dụng

### 1. Clone repo

```bash
git clone https://github.com/dev1sme/my-config.git
cd my-config
```

### 2. Cài đặt Zsh + Oh My Zsh

```bash
./zsh/setup.sh
```

**Bao gồm:**

- Cài đặt Zsh và đặt làm default shell
- Cài đặt Oh My Zsh
- Cài đặt fzf
- Cài đặt plugins:
  - `git` - Git aliases & functions
  - `zsh-autosuggestions` - Gợi ý command
  - `zsh-syntax-highlighting` - Highlight cú pháp
  - `docker` - Docker autocompletion
  - `docker-compose` - Docker Compose autocompletion
  - `history` - Tìm kiếm history
  - `rsync` - Rsync aliases
  - `safe-paste` - Chống paste nhầm
  - `fzf` - Fuzzy finder
- Theme: **strug**
- Copy file `.zshrc` vào `$HOME`

### 3. Cài đặt Docker Engine

```bash
./docker/setup.sh
```

**Bao gồm:**

- Gỡ các package Docker cũ/không chính thức
- Thêm Docker official GPG key & repository
- Cài đặt Docker Engine, Docker CLI, Containerd
- Cài đặt Docker Buildx & Docker Compose v2
- Thêm user vào group `docker` (chạy không cần sudo)
- Bật Docker service tự khởi động

**Hỗ trợ:** Ubuntu, Debian, Linux Mint, Pop!\_OS, Fedora, CentOS, RHEL, Rocky, Alma

### 4. Cài đặt VS Code

```bash
# Cài tất cả (extensions + settings)
./vscode/setup.sh

# Chỉ cài extensions
./vscode/setup.sh --extensions

# Chỉ copy settings
./vscode/setup.sh --settings

# Export danh sách extensions hiện tại
./vscode/setup.sh --export
```

**Extensions đã cấu hình (35 extensions):**

| Nhóm          | Extensions                                               |
| ------------- | -------------------------------------------------------- |
| AI & Copilot  | Claude Code, GitHub Copilot Chat                         |
| Java & Spring | Java Extension Pack, Spring Boot Dev Pack, Gradle, Maven |
| Python        | Python, Pylance, Debugpy, Python Environments            |
| Web Dev       | ESLint, Prettier, Live Server                            |
| Docker        | Docker, Docker Explorer, VS Code Containers              |
| Database      | SQLTools (MySQL, PostgreSQL), MongoDB, Redis             |
| Git           | GitLens                                                  |
| Theme & UI    | Dracula Theme Soft, Material Icon Theme, Guides          |

## ⚡ Setup nhanh (tất cả)

```bash
git clone https://github.com/dev1sme/my-config.git
cd my-config
./zsh/setup.sh
./docker/setup.sh
./vscode/setup.sh
```

> ⚠️ Sau khi chạy xong, **logout và login lại** để áp dụng Zsh default shell và Docker group.

## 📋 Yêu cầu

- Linux (Ubuntu/Debian/Fedora/CentOS)
- `curl`, `git`
- VS Code đã cài đặt (cho vscode setup)
- Quyền `sudo`

## 👤 Author

**dev1sme** - [GitHub](https://github.com/dev1sme)
