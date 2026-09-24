# Development

## Cấu trúc

```
my-config/
├── install.sh              # Installer Linux/macOS (bootstrap + flow)
├── install.ps1             # Installer Windows (bootstrap, ASCII only)
├── lib/
│   ├── banner.txt          # ASCII banner dùng chung
│   ├── sh/                 # Bash 3.2+
│   │   ├── ui.sh           # Loader: ui/core.sh, ui/prompt.sh, ui/spinner.sh
│   │   ├── env.sh          # Detect OS / distro / root / WSL
│   │   ├── modules.sh      # Đọc module.conf
│   │   ├── runner.sh       # sudo keepalive, chạy module, tổng kết
│   │   ├── pkg.sh          # Package manager: apt/dnf/yum/pacman/zypper/apk/brew
│   │   └── banner.sh
│   └── ps/                 # PowerShell 5.1+ (UTF-8 BOM)
│       ├── Main.ps1        # Flow chính Windows
│       ├── UI.ps1          # Loader: UI.Core, UI.Prompt, UI.Spinner
│       ├── Pkg.ps1         # winget, OpenSSH Client
│       └── Env.ps1  Modules.ps1  Runner.ps1  Banner.ps1
└── <module>/               # ssh, zsh, docker, vscode
    ├── module.conf
    └── setup.sh / setup_mac.sh / setup.ps1
```

## Thêm module mới

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

| Key                         | Mô tả                                                                 |
| --------------------------- | --------------------------------------------------------------------- |
| `mode`                      | `tty` = script hỏi tương tác, `bg` = chạy nền có spinner + log        |
| `sudo`                      | OS cần sudo/Admin, phân cách dấu phẩy: `linux`, `mac`, `windows`      |
| `requires`                  | Lệnh bắt buộc, thiếu thì bỏ chọn mặc định. `a\|b` = có 1 lệnh là đủ   |
| `requires_<os>`             | Ghi đè `requires` cho 1 OS, vd `requires_windows=code\|winget`        |
| `linux` / `mac` / `windows` | Script cho từng OS, bỏ trống = không hỗ trợ                           |
| `next`                      | Gợi ý hiển thị sau khi cài xong                                       |

Format: `key=value` mỗi dòng, không comment cuối dòng.

## Cài package trong script

```bash
. "$SCRIPT_DIR/../lib/sh/pkg.sh"
require_sudo || exit 1

pkg_install zsh fzf          # tự chọn apt/dnf/pacman/...
pkg_ensure_cmd git           # chỉ cài khi thiếu lệnh
$SUDO tee -a /etc/shells     # "" khi root, "sudo" khi user thường
```

```powershell
. (Join-Path $PSScriptRoot '..\lib\ps\UI.ps1')
. (Join-Path $PSScriptRoot '..\lib\ps\Pkg.ps1')

Install-WingetPackage 'Microsoft.VisualStudioCode'
Install-OpenSshClient        # cần Admin
```

## Lưu ý

- `install.ps1` phải giữ ASCII: chạy qua cả `irm | iex` lẫn từ file trên PowerShell 5.1.
- Script bash phải chạy được trên bash 3.2 (macOS): không dùng `declare -A`, `mapfile`, `${var,,}`, `local -n`.
- Không dùng `awk` trong installer: image tối giản (openSUSE) không có.
- Log module chạy nền: `~/.local/state/my-config/logs/` (Windows: `%LOCALAPPDATA%\my-config\logs\`).
