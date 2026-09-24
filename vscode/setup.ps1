# ============================================================
# VS Code Setup Script - Windows
# Cài đặt extensions và cấu hình settings cho VS Code
# Chạy: PowerShell 5.1+ hoặc PowerShell 7+
# File lưu UTF-8 with BOM để PowerShell 5.1 đọc đúng tiếng Việt.
# ============================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ExtensionsFile = Join-Path $ScriptDir "extensions.txt"
$SettingsFile   = Join-Path $ScriptDir "setting.json"

. (Join-Path $ScriptDir '..\lib\ps\UI.ps1')
. (Join-Path $ScriptDir '..\lib\ps\Pkg.ps1')

function Info   { param($msg) Write-UiLog $msg }
function Warn   { param($msg) Write-UiLogWarn $msg }
function Err    { param($msg) Stop-UiFail $msg }
function Header { param($msg) Write-UiSection $msg }

# ============================================================
# Kiểm tra hệ điều hành
# ============================================================
$_os = if ($PSVersionTable.PSVersion.Major -ge 6) {
    if     ($IsWindows) { "Windows" }
    elseif ($IsMacOS)   { "macOS" }
    elseif ($IsLinux)   { "Linux" }
    else                { "Unknown" }
} else { "Windows" }

switch ($_os) {
    "Windows" { }  # OK
    "macOS"   { Err "Bạn đang dùng macOS. Hãy chạy: ./vscode/setup_mac.sh" }
    "Linux"   { Err "Bạn đang dùng Linux. Hãy chạy: ./vscode/setup.sh" }
    default   { Err "Hệ điều hành không được hỗ trợ: $_os" }
}

# ============================================================
# VS Code settings path (Windows)
# ============================================================
function Get-VscodeSettingsDir {
    return "$env:APPDATA\Code\User"
}

# ============================================================
# 1. Kiểm tra VS Code đã cài chưa
# ============================================================
# Đường dẫn VS Code khi cài bằng .exe (mặc định)
$VscodePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
)

function Check-Vscode {
    param([switch]$AfterInstall)
    Header "Kiểm tra VS Code..."

    if (Get-Command code -ErrorAction SilentlyContinue) {
        Info "VS Code đã được cài đặt: $(code --version | Select-Object -First 1)"
        return
    }

    # Cài bằng .exe nhưng chưa có 'code' trong PATH
    $found = $VscodePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($found) {
        $binDir = Split-Path $found
        Warn "VS Code đã cài ($binDir) nhưng lệnh 'code' chưa có trong PATH."

        # Thêm vào PATH của User (persistent qua reboot)
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$binDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
            Info "Đã thêm '$binDir' vào User PATH."
        }

        # Thêm vào PATH cho session hiện tại
        $env:Path = "$binDir;$env:Path"

        if (Get-Command code -ErrorAction SilentlyContinue) {
            Info "VS Code: $(code --version | Select-Object -First 1)"
        } else {
            Warn "Không xác nhận được lệnh 'code'. Thử đóng rồi mở lại PowerShell."
        }
    } elseif (-not $AfterInstall) {
        Warn "VS Code chưa được cài đặt."
        if (Install-WingetPackage "Microsoft.VisualStudioCode") {
            Info "Đã cài VS Code qua winget."
            Check-Vscode -AfterInstall
            return
        }
        Err "Không cài được VS Code qua winget.
             Download: https://code.visualstudio.com/download"
    } else {
        Err "Không tìm thấy VS Code sau khi cài. Đóng rồi mở lại PowerShell, chạy lại script."
    }
}

# ============================================================
# 2. Cài đặt Extensions
# ============================================================
function Install-Extensions {
    Header "Cài đặt VS Code Extensions..."

    if (-not (Test-Path $ExtensionsFile)) {
        Err "Không tìm thấy file $ExtensionsFile"
    }

    $total = 0; $installed = 0; $failed = 0; $skipped = 0

    # Danh sách extensions đã cài
    $currentExtensions = @(code --list-extensions 2>$null)

    foreach ($line in (Get-Content $ExtensionsFile)) {
        $ext = $line.Trim()
        # Bỏ qua dòng trống và comment
        if ([string]::IsNullOrWhiteSpace($ext) -or $ext.StartsWith("#")) { continue }

        $total++

        # -contains so sánh không phân biệt hoa thường
        if ($currentExtensions -contains $ext) {
            Info "$($C.Dim)$([char]0x2713) Đã có: $ext$($C.Reset)"
            $skipped++
            continue
        }

        # Lệnh native không throw khi lỗi: kiểm tra exit code
        $ErrorActionPreference = 'Continue'
        $null = code --install-extension $ext --force 2>&1
        $rc = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        if ($rc -eq 0) {
            Info "$($C.Green)$($G.Check)$($C.Reset) Đã cài: $ext"
            $installed++
        } else {
            Write-UiLogError "Lỗi: $ext (exit $rc)"
            $failed++
        }
    }

    Info "Tổng: $total $($G.Dot) Đã có: $skipped $($G.Dot) Mới cài: $installed $($G.Dot) Lỗi: $failed"
}

# ============================================================
# 3. Cấu hình Settings
# ============================================================
function Setup-Settings {
    Header "Cấu hình VS Code Settings..."

    if (-not (Test-Path $SettingsFile)) {
        Err "Không tìm thấy file $SettingsFile"
    }

    $vscodeDir = Get-VscodeSettingsDir
    $targetSettings = Join-Path $vscodeDir "settings.json"

    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    }

    # Backup settings cũ nếu có
    if (Test-Path $targetSettings) {
        $backup = "$targetSettings.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Warn "Backup settings cũ -> $backup"
        Copy-Item $targetSettings $backup
    }

    Copy-Item $SettingsFile $targetSettings -Force
    Info "Settings đã được cập nhật tại: $targetSettings"
}

# ============================================================
# 4. Export extensions hiện tại (tiện ích)
# ============================================================
function Export-CurrentExtensions {
    Header "Export danh sách extensions hiện tại..."
    $exportFile = Join-Path $ScriptDir "extensions.txt"
    code --list-extensions | Set-Content $exportFile -Encoding ASCII
    $count = (Get-Content $exportFile).Count
    Info "Đã export $count extensions vào: $exportFile"
}

# ============================================================
# Menu & Main
# ============================================================
function Show-Help {
    Write-Host ""
    Write-Host "Usage: .\setup.ps1 [OPTION]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --all          Cài đặt extensions + settings (mặc định)"
    Write-Host "  --extensions   Chỉ cài đặt extensions"
    Write-Host "  --settings     Chỉ cấu hình settings"
    Write-Host "  --export       Export danh sách extensions hiện tại"
    Write-Host "  --help         Hiển thị help"
    Write-Host ""
}

$action = if ($args.Count -gt 0) { $args[0] } else { "--all" }

if ($action -eq "--help" -or $action -eq "-h") {
    Show-Help
    exit 0
}

Start-UiModule "VS Code (Windows)"
Check-Vscode

switch ($action) {
    "--all"        { Install-Extensions; Setup-Settings }
    "--extensions" { Install-Extensions }
    "--settings"   { Setup-Settings }
    "--export"     { Export-CurrentExtensions }
    default {
        Warn "Option không hợp lệ: $action"
        Show-Help
        exit 1
    }
}

Complete-UiModule "Hoàn tất! Khởi động lại VS Code để áp dụng thay đổi."
