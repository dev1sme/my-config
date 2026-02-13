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

### 2. Cài đặt theo module

<details>
<summary><strong>🐚 Zsh + Oh My Zsh</strong></summary>

#### Chạy

```bash
./zsh/setup.sh
```

#### Mô tả

Cài đặt Zsh shell, Oh My Zsh framework và các plugin hỗ trợ, đặt Zsh làm default shell.

#### Bao gồm

| Thành phần | Chi tiết                        |
| ---------- | ------------------------------- |
| Zsh        | Cài đặt & đặt làm default shell |
| Oh My Zsh  | Framework quản lý cấu hình Zsh  |
| fzf        | Fuzzy finder (binary + plugin)  |
| Theme      | **strug**                       |

#### Plugins

| Plugin                    | Loại     | Mô tả                             |
| ------------------------- | -------- | --------------------------------- |
| `git`                     | built-in | Git aliases & functions           |
| `zsh-autosuggestions`     | external | Gợi ý command dựa trên history    |
| `zsh-syntax-highlighting` | external | Highlight cú pháp trên terminal   |
| `docker`                  | built-in | Docker autocompletion             |
| `docker-compose`          | built-in | Docker Compose autocompletion     |
| `history`                 | built-in | Tìm kiếm history nâng cao         |
| `rsync`                   | built-in | Rsync aliases                     |
| `safe-paste`              | built-in | Chống chạy nhầm khi paste command |
| `fzf`                     | built-in | Fuzzy finder integration          |

#### Files

| File           | Mô tả                                       |
| -------------- | ------------------------------------------- |
| `zsh/setup.sh` | Script cài đặt tự động                      |
| `zsh/.zshrc`   | File cấu hình, được copy vào `$HOME/.zshrc` |

</details>

<details>
<summary><strong>🐳 Docker Engine</strong></summary>

#### Chạy

```bash
./docker/setup.sh
```

#### Mô tả

Cài đặt Docker Engine từ official repository, bao gồm Docker Compose v2 plugin.

> ⚠️ Không chạy với `sudo`. Script sẽ tự gọi `sudo` khi cần.

#### Bao gồm

| Thành phần        | Package                 |
| ----------------- | ----------------------- |
| Docker Engine     | `docker-ce`             |
| Docker CLI        | `docker-ce-cli`         |
| Containerd        | `containerd.io`         |
| Docker Buildx     | `docker-buildx-plugin`  |
| Docker Compose v2 | `docker-compose-plugin` |

#### Quy trình cài đặt

1. Gỡ các package Docker cũ / không chính thức
2. Cài đặt dependencies (`ca-certificates`, `curl`, `gnupg`)
3. Thêm Docker official GPG key & apt repository
4. Cài đặt Docker Engine + plugins
5. Thêm user hiện tại vào group `docker`
6. Bật Docker service tự khởi động (`systemctl enable`)
7. Chạy test `hello-world` để kiểm tra

#### Distro hỗ trợ

| Debian-based | RPM-based    |
| ------------ | ------------ |
| Ubuntu       | Fedora       |
| Debian       | CentOS       |
| Linux Mint   | RHEL         |
| Pop!\_OS     | Rocky / Alma |

#### Files

| File              | Mô tả                  |
| ----------------- | ---------------------- |
| `docker/setup.sh` | Script cài đặt tự động |

</details>

<details>
<summary><strong>💻 VS Code</strong></summary>

#### Chạy

```bash
# Cài tất cả (extensions + settings)
./vscode/setup.sh

# Chỉ cài extensions
./vscode/setup.sh --extensions

# Chỉ copy settings
./vscode/setup.sh --settings

# Export danh sách extensions hiện tại ra file
./vscode/setup.sh --export
```

#### Mô tả

Cài đặt 35 extensions và apply file `setting.json` vào VS Code. Tự động backup settings cũ trước khi ghi đè.

#### Extensions (35)

| Nhóm          | Extensions                                                                                                                                                                                                                                                                                           |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AI & Copilot  | `anthropic.claude-code`, `github.copilot-chat`                                                                                                                                                                                                                                                       |
| Java & Spring | `redhat.java`, `vscjava.vscode-java-pack`, `vscjava.vscode-java-debug`, `vscjava.vscode-java-dependency`, `vscjava.vscode-java-test`, `vscjava.vscode-maven`, `vmware.vscode-boot-dev-pack`, `vmware.vscode-spring-boot`, `vscjava.vscode-spring-boot-dashboard`, `vscjava.vscode-spring-initializr` |
| Gradle        | `vscjava.vscode-gradle`, `naco-siren.gradle-language`, `richardwillis.vscode-gradle-extension-pack`                                                                                                                                                                                                  |
| Python        | `ms-python.python`, `ms-python.vscode-pylance`, `ms-python.debugpy`, `ms-python.vscode-python-envs`                                                                                                                                                                                                  |
| Web Dev       | `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `ritwickdey.liveserver`                                                                                                                                                                                                                          |
| Docker        | `docker.docker`, `ms-azuretools.vscode-docker`, `ms-azuretools.vscode-containers`                                                                                                                                                                                                                    |
| Database      | `mtxr.sqltools`, `mtxr.sqltools-driver-mysql`, `mtxr.sqltools-driver-pg`, `mongodb.mongodb-vscode`, `redis.redis-for-vscode`, `inferrinizzard.prettier-sql-vscode`                                                                                                                                   |
| Git           | `eamodio.gitlens`                                                                                                                                                                                                                                                                                    |
| Theme & UI    | `dracula-theme.theme-dracula`, `pkief.material-icon-theme`, `spywhere.guides`                                                                                                                                                                                                                        |

#### Settings chính

| Cấu hình                 | Giá trị             |
| ------------------------ | ------------------- |
| Theme                    | Dracula Theme Soft  |
| Icon Theme               | Material Icon Theme |
| Auto Save                | Sau 1 giây          |
| Format On Save           | Bật                 |
| Java Formatter           | Red Hat             |
| JS/TS/React Formatter    | Prettier            |
| ESLint Fix On Save       | Bật                 |
| Organize Imports On Save | Bật                 |
| Terminal Font Size       | 10                  |
| Cursor Animation         | Smooth              |

#### Files

| File                    | Mô tả                   |
| ----------------------- | ----------------------- |
| `vscode/setup.sh`       | Script cài đặt tự động  |
| `vscode/extensions.txt` | Danh sách extension IDs |
| `vscode/setting.json`   | File cấu hình VS Code   |

</details>

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

## 👤 **[@dev1sme](https://github.com/dev1sme)**

[![GitHub](https://img.shields.io/badge/GitHub-dev1sme-blue?style=for-the-badge&logo=github)](https://github.com/dev1sme)
[![Website](https://img.shields.io/badge/Website-dev1sme-blue?style=for-the-badge&logo=safari)](https://dev1sme.github.io)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤️-pink?style=for-the-badge&logo=github-sponsors&logoColor=white)](https://github.com/sponsors/dev1sme)
