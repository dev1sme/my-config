# 🛠️ my-config

Bộ script tự động cài đặt và cấu hình môi trường phát triển trên **Linux**, **macOS** và **Windows**.

## ⚡ Cài đặt nhanh (1 lệnh)

**Linux / macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash
```

**Windows** (PowerShell, nên dùng Windows Terminal)

```powershell
irm https://raw.githubusercontent.com/dev1sme/my-config/main/install.ps1 | iex
```

Installer tự tải repo về `~/.my-config`, detect OS, rồi mở wizard để chọn module:

```
┌  my-config setup
│
◇  Hệ thống: Ubuntu 24.04 LTS · x86_64 · user root
│
◆  Chọn module cần cài
│  ◼ SSH key + ssh-agent
│  ◼ Zsh + Oh My Zsh
│  ◼ Docker Engine + Compose (docker-ce, buildx, compose v2)
│  ◻ VS Code extensions + settings
└  ↑/↓ di chuyển · space chọn · a chọn tất cả · enter xác nhận
```

| Module   | Linux | macOS | Windows                          |
| -------- | ----- | ----- | -------------------------------- |
| `ssh`    | ✔     | ✔     | ✔ (tự hỏi mở lại với quyền Admin) |
| `zsh`    | ✔     | ✔     | ✘                                |
| `docker` | ✔     | OrbStack | ✘                             |
| `vscode` | ✔     | ✔     | ✔                                |

### Non-interactive (VPS, CI)

```bash
curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash -s -- --only zsh,docker -y
curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash -s -- --all -y
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/dev1sme/my-config/main/install.ps1))) -Only ssh,vscode -Yes
```

| Bash          | PowerShell    | Mô tả                                            |
| ------------- | ------------- | ------------------------------------------------ |
| `--only LIST` | `-Only LIST`  | Chỉ cài module chỉ định, vd: `ssh,zsh`           |
| `--all`       | `-All`        | Cài tất cả module khả dụng trên OS hiện tại      |
| `-y, --yes`   | `-Yes`        | Bỏ qua bước xác nhận                             |
| `--list`      | `-List`       | Liệt kê module                                   |

| Biến môi trường  | Mặc định            | Mô tả           |
| ---------------- | ------------------- | --------------- |
| `MY_CONFIG_DIR`  | `~/.my-config`      | Nơi tải repo về |
| `MY_CONFIG_REF`  | `main`              | Branch          |
| `MY_CONFIG_REPO` | `dev1sme/my-config` | GitHub repo     |

Log của module chạy nền: `~/.local/state/my-config/logs/<timestamp>/` (Windows: `%LOCALAPPDATA%\my-config\logs\`).

### Thêm module mới

Tạo thư mục `<module>/` gồm script + `module.conf`, installer tự nhận:

```ini
label=SSH key + ssh-agent
hint=ed25519/rsa · ssh-agent · ~/.ssh/config
order=10
mode=tty
default=on
sudo=windows
requires=
linux=setup.sh
mac=setup_mac.sh
windows=setup.ps1
next=Thêm public key vào GitHub: https://github.com/settings/keys
```

| Key        | Mô tả                                                            |
| ---------- | ---------------------------------------------------------------- |
| `mode`     | `tty` = script hỏi tương tác, `bg` = chạy nền có spinner + log   |
| `sudo`     | OS cần sudo/Admin, phân cách dấu phẩy: `linux`, `mac`, `windows` |
| `requires` | Lệnh bắt buộc có sẵn, thiếu thì module mặc định bỏ chọn          |
| `linux` / `mac` / `windows` | Script cho từng OS, bỏ trống = không hỗ trợ     |
| `next`     | Gợi ý hiển thị sau khi cài xong                                  |

## 📁 Cấu trúc

```
my-config/
├── install.sh                # Installer Linux/macOS (bootstrap + flow)
├── install.ps1               # Installer Windows (bootstrap, ASCII only)
├── lib/
│   ├── banner.txt            # ASCII banner dùng chung
│   ├── sh/                   # Bash (3.2+)
│   │   ├── ui.sh             # Loader UI: ui/core.sh, ui/prompt.sh, ui/spinner.sh
│   │   ├── env.sh            # Detect OS / distro / root / WSL
│   │   ├── modules.sh        # Đọc module.conf
│   │   ├── runner.sh         # sudo, chạy module, tổng kết
│   │   └── banner.sh
│   └── ps/                   # PowerShell 5.1+ (UTF-8 BOM)
│       ├── Main.ps1          # Flow chính Windows
│       ├── UI.ps1            # Loader UI: UI.Core, UI.Prompt, UI.Spinner
│       └── Env.ps1  Modules.ps1  Runner.ps1  Banner.ps1
├── docker/
│   ├── module.conf
│   └── setup.sh              # Cài đặt Docker Engine + Docker Compose
├── ssh/
│   ├── module.conf
│   ├── setup.sh              # Linux: Tạo SSH key pair + cấu hình ssh-agent
│   ├── setup_mac.sh          # macOS: Tạo SSH key pair + Keychain
│   └── setup.ps1             # Windows: Tạo SSH key pair + OpenSSH service
├── vscode/
│   ├── module.conf
│   ├── setting.json          # Cấu hình VS Code settings
│   ├── extensions.txt        # Danh sách extensions
│   ├── setup.sh              # Linux: Cài extensions + apply settings
│   ├── setup_mac.sh          # macOS: Cài extensions + apply settings
│   └── setup.ps1             # Windows: Cài extensions + apply settings
├── zsh/
│   ├── module.conf
│   ├── .zshrc                # File cấu hình Zsh
│   ├── setup.sh              # Linux: Cài Zsh + Oh My Zsh + plugins
│   └── setup_mac.sh          # macOS: Cài Zsh + Oh My Zsh + plugins
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
<summary><strong>🔑 SSH Key</strong></summary>

#### Chạy

```bash
# Linux
./ssh/setup.sh

# macOS
./ssh/setup_mac.sh

# Windows (PowerShell - chạy với quyền Administrator)
.\ssh\setup.ps1
```

Script chạy **hoàn toàn tương tác** — sẽ hỏi lần lượt từng bước trước khi thực thi.

#### Mô tả

Tạo SSH key pair, cấu hình `~/.ssh/config`, thêm key vào `ssh-agent` và in public key ra màn hình.

| OS      | Clipboard                  | ssh-agent                              | ssh config đặc biệt                     |
| ------- | -------------------------- | -------------------------------------- | --------------------------------------- |
| Linux   | `xclip` / `xsel` (auto)    | `ssh-agent` (session)                  | `AddKeysToAgent yes`                    |
| macOS   | `pbcopy` (built-in)        | Keychain (persistent qua reboot)       | `AddKeysToAgent yes`, `UseKeychain yes` |
| Windows | `Set-Clipboard` (built-in) | OpenSSH Authentication Agent (service) | `AddKeysToAgent yes`                    |

#### Quy trình tương tác

| Bước | Script hỏi                               | Mặc định     |
| ---- | ---------------------------------------- | ------------ |
| 1a   | Loại key (ed25519 / rsa)                 | `ed25519`    |
| 1b   | Tên file key (tự động lưu vào `~/.ssh/`) | `id_ed25519` |
| 1c   | Comment / email nhận diện key            | _(bỏ trống)_ |
| 1d   | Thêm key vào `ssh-agent` không?          | `y`          |
| 1e   | Xác nhận tóm tắt trước khi tiếp tục      | `y`          |
| 2    | Ghi đè nếu key đã tồn tại?               | `N`          |
| 3    | Cấu hình `~/.ssh/config` tự động không?  | `y`          |

#### Bao gồm

| Bước | Mô tả                                                                                           |
| ---- | ----------------------------------------------------------------------------------------------- |
| 1    | Kiểm tra & tạo `~/.ssh/` với quyền `700`                                                        |
| 2    | Tạo key pair (ed25519 hoặc RSA 4096), backup key cũ nếu có                                      |
| 3    | Khởi động `ssh-agent` và thêm private key (macOS: Keychain, Windows: OpenSSH service)           |
| 4    | Tạo `~/.ssh/config` với `AddKeysToAgent`, `ServerAliveInterval` (macOS: thêm `UseKeychain yes`) |
| 5    | In public key ra màn hình & copy vào clipboard                                                  |

#### Files

| File               | OS      | Mô tả                                      |
| ------------------ | ------- | ------------------------------------------ |
| `ssh/setup.sh`     | Linux   | Tạo key, cấu hình ssh-agent, ~/.ssh/config |
| `ssh/setup_mac.sh` | macOS   | Tạo key, tích hợp Keychain, ~/.ssh/config  |
| `ssh/setup.ps1`    | Windows | Tạo key, bật OpenSSH service, .ssh\config  |

</details>

<details>
<summary><strong>�🐚 Zsh + Oh My Zsh</strong></summary>

#### Chạy

```bash
# Linux
./zsh/setup.sh

# macOS
./zsh/setup_mac.sh
```

> ⚠️ **Windows không hỗ trợ:** Zsh không chạy native trên Windows. Nếu cần Zsh trên Windows, hãy sử dụng WSL (Windows Subsystem for Linux) và chạy script Linux bên trong WSL.

#### Mô tả

Cài đặt Zsh shell, Oh My Zsh framework và các plugin hỗ trợ, đặt Zsh làm default shell.

#### Bao gồm

| Thành phần | Chi tiết                        |
| ---------- | ------------------------------- |
| Zsh        | Cài đặt & đặt làm default shell |
| Oh My Zsh  | Framework quản lý cấu hình Zsh  |
| fzf        | Fuzzy finder (binary + plugin)  |
| Theme      | **strug**                       |

> **macOS:** Yêu cầu [Homebrew](https://brew.sh/). Zsh và fzf được cài qua `brew install`.

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

| File               | OS    | Mô tả                                       |
| ------------------ | ----- | ------------------------------------------- |
| `zsh/setup.sh`     | Linux | Script cài đặt tự động                      |
| `zsh/setup_mac.sh` | macOS | Script cài đặt tự động (Homebrew)           |
| `zsh/.zshrc`       | All   | File cấu hình, được copy vào `$HOME/.zshrc` |

</details>

<details>
<summary><strong>🐳 Docker Engine</strong></summary>

#### Chạy

```bash
# Linux only
./docker/setup.sh
```

#### Mô tả

Cài đặt Docker Engine từ official repository, bao gồm Docker Compose v2 plugin.

> ⚠️ Không chạy với `sudo`. Script sẽ tự gọi `sudo` khi cần.

> 🐧 **Linux only:** Script này chỉ hỗ trợ Linux vì Docker Engine chạy native trên Linux kernel.
>
> Trên các nền tảng khác, khuyến nghị sử dụng:
>
> | OS      | Khuyến nghị                          | Lý do                                                          |
> | ------- | ------------------------------------ | -------------------------------------------------------------- |
> | macOS   | [OrbStack](https://orbstack.dev/)    | Nhẹ, nhanh, thay thế Docker Desktop, tích hợp tốt với macOS    |
> | Windows | WSL2 + Docker CLI + Windows Terminal | Chạy Docker Engine native trong WSL2, không cần Docker Desktop |

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

| File              | OS    | Mô tả                  |
| ----------------- | ----- | ---------------------- |
| `docker/setup.sh` | Linux | Script cài đặt tự động |

</details>

<details>
<summary><strong>💻 VS Code</strong></summary>

#### Chạy

```bash
# Linux
./vscode/setup.sh              # Cài tất cả (extensions + settings)
./vscode/setup.sh --extensions  # Chỉ cài extensions
./vscode/setup.sh --settings    # Chỉ copy settings
./vscode/setup.sh --export      # Export extensions hiện tại ra file

# macOS
./vscode/setup_mac.sh
./vscode/setup_mac.sh --extensions
./vscode/setup_mac.sh --settings
./vscode/setup_mac.sh --export

# Windows (PowerShell)
.\vscode\setup.ps1
.\vscode\setup.ps1 --extensions
.\vscode\setup.ps1 --settings
.\vscode\setup.ps1 --export
```

#### Mô tả

Cài đặt 35 extensions và apply file `setting.json` vào VS Code. Tự động backup settings cũ trước khi ghi đè.

> **macOS:** Script tự detect VS Code cài qua `.dmg` và thêm lệnh `code` vào PATH nếu chưa có. Hoặc cài qua `brew install --cask visual-studio-code`.
>
> **Windows:** Script tự detect VS Code trong PATH. Nếu chưa có, thêm vào User PATH tự động. Hoặc cài qua `winget install Microsoft.VisualStudioCode`.

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

| Cấu hình                      | Giá trị                 |
| ----------------------------- | ----------------------- |
| Theme                         | Dracula Theme Soft      |
| Icon Theme                    | Material Icon Theme     |
| Auto Save                     | Sau 1 giây              |
| Format On Save                | Bật                     |
| Java Formatter                | Red Hat                 |
| JS/TS/React Formatter         | Prettier                |
| ESLint Fix On Save            | Bật                     |
| Prettier Fix On Save          | Bật                     |
| Organize Imports On Save      | Bật                     |
| Terminal Font Size            | 10                      |
| Terminal Cursor Style         | Line                    |
| Cursor Animation              | Smooth                  |
| Menu Bar                      | Compact                 |
| Copilot Next Edit Suggestions | Bật                     |
| GitLens AI Model              | GPT-4.1 (via Copilot)   |
| Claude Code Location          | Panel                   |
| Container Client              | Docker + Docker Compose |

#### Files

| File                    | OS      | Mô tả                                           |
| ----------------------- | ------- | ----------------------------------------------- |
| `vscode/setup.sh`       | Linux   | Script cài đặt tự động                          |
| `vscode/setup_mac.sh`   | macOS   | Script cài đặt tự động (auto-detect PATH)       |
| `vscode/setup.ps1`      | Windows | Script cài đặt tự động (auto-detect PATH)       |
| `vscode/extensions.txt` | All     | Danh sách extension IDs                         |
| `vscode/setting.json`   | All     | File cấu hình VS Code (shared across platforms) |

</details>

## 🧩 Chạy thủ công từng script (tất cả)

```bash
git clone https://github.com/dev1sme/my-config.git
cd my-config

# Linux
./ssh/setup.sh
./zsh/setup.sh
./docker/setup.sh
./vscode/setup.sh

# macOS (Docker → dùng OrbStack thay thế)
./ssh/setup_mac.sh
./zsh/setup_mac.sh
./vscode/setup_mac.sh

# Windows (PowerShell) — Docker → dùng WSL2 + Docker CLI
.\ssh\setup.ps1
.\vscode\setup.ps1
```

> ⚠️ Sau khi chạy xong, **logout và login lại** để áp dụng Zsh default shell và Docker group.

## 📋 Yêu cầu

- **Linux:** Ubuntu/Debian/Fedora/CentOS
- **macOS:** macOS 10.15+ với Homebrew
- **Windows:** Chỉ hỗ trợ SSH và VS Code (PowerShell). Zsh không có bản Windows native. Docker nên dùng WSL2 + Docker CLI + Windows Terminal.
- `curl`, `git`
- VS Code đã cài đặt (cho vscode setup)
- Quyền `sudo`

## 👤 **[@dev1sme](https://github.com/dev1sme)**

[![GitHub](https://img.shields.io/badge/GitHub-dev1sme-blue?style=for-the-badge&logo=github)](https://github.com/dev1sme)
[![Website](https://img.shields.io/badge/Website-dev1sme-blue?style=for-the-badge&logo=safari)](https://dev1sme.github.io)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤️-pink?style=for-the-badge&logo=github-sponsors&logoColor=white)](https://github.com/sponsors/dev1sme)
