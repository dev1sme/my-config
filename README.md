# 🛠️ my-config

Cài đặt và cấu hình môi trường phát triển trên **Linux**, **macOS** và **Windows** bằng 1 lệnh.

## ⚡ Cài đặt

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash
```

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/dev1sme/my-config/main/install.ps1 | iex
```

Installer tải repo về `~/.my-config`, detect OS rồi mở wizard chọn module.

**Non-interactive** (VPS, CI):

```bash
curl -fsSL https://raw.githubusercontent.com/dev1sme/my-config/main/install.sh | bash -s -- --only zsh,docker -y
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/dev1sme/my-config/main/install.ps1))) -Only ssh,vscode -Yes
```

| Bash          | PowerShell   | Mô tả                                   |
| ------------- | ------------ | --------------------------------------- |
| `--only LIST` | `-Only LIST` | Chỉ cài module chỉ định, vd `ssh,zsh`   |
| `--all`       | `-All`       | Cài tất cả module khả dụng              |
| `-y, --yes`   | `-Yes`       | Bỏ qua bước xác nhận                    |
| `--list`      | `-List`      | Liệt kê module                          |

## 🧩 Module

| Module   | Cài gì                                              | Linux | macOS | Windows |
| -------- | --------------------------------------------------- | :---: | :---: | :-----: |
| `ssh`    | SSH key (ed25519/rsa), ssh-agent, `~/.ssh/config`   | ✔     | ✔     | ✔       |
| `zsh`    | Zsh, Oh My Zsh, plugins, fzf, [`.zshrc`](zsh/.zshrc) | ✔     | ✔     |         |
| `docker` | Docker Engine, Buildx, Compose v2                   | ✔     |       |         |
| `vscode` | [Extensions](vscode/extensions.txt) + [settings](vscode/setting.json) | ✔ | ✔ | ✔ |

- Docker trên macOS: dùng [OrbStack](https://orbstack.dev). Trên Windows: vào WSL rồi chạy lệnh Linux.
- Sau khi cài: logout/login lại để áp dụng default shell và group `docker`.

## 🔧 Chạy thủ công

```bash
git clone https://github.com/dev1sme/my-config.git && cd my-config
./install.sh              # wizard
./zsh/setup.sh            # hoặc từng module: ssh/ zsh/ docker/ vscode/ (setup_mac.sh cho macOS)
```

```powershell
.\ssh\setup.ps1
.\vscode\setup.ps1
```

## 📋 Yêu cầu

- **Linux:** Debian/Ubuntu, Fedora/RHEL/Rocky/Alma, Arch, openSUSE, Alpine (cần `bash`). Chạy root hoặc user có `sudo`.
- **macOS:** Homebrew.
- **Windows:** PowerShell 5.1+, nên dùng Windows Terminal. Thiếu VS Code / OpenSSH Client thì tự cài qua `winget`.

Thêm module, cấu trúc repo: xem [docs/development.md](docs/development.md).

## 👤 **[@dev1sme](https://github.com/dev1sme)**

[![GitHub](https://img.shields.io/badge/GitHub-dev1sme-blue?style=for-the-badge&logo=github)](https://github.com/dev1sme)
[![Website](https://img.shields.io/badge/Website-dev1sme-blue?style=for-the-badge&logo=safari)](https://dev1sme.github.io)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤️-pink?style=for-the-badge&logo=github-sponsors&logoColor=white)](https://github.com/sponsors/dev1sme)
