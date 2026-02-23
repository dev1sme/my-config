# ============================================================
# VS Code Setup Script - Windows
# Cai dat extensions va cau hinh settings cho VS Code
# Chay: PowerShell 5.1+ hoac PowerShell 7+
# ============================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# ============================================================
# Colors / helpers
# ============================================================
function Info   { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Green }
function Warn   { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err    { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }
function Header { param($msg) Write-Host "[====] $msg" -ForegroundColor Cyan }

# ============================================================
# Kiem tra he dieu hanh
# ============================================================
$_os = if ($PSVersionTable.PSVersion.Major -ge 6) {
    if     ($IsWindows) { "Windows" }
    elseif ($IsMacOS)   { "macOS" }
    elseif ($IsLinux)   { "Linux" }
    else                { "Unknown" }
} else { "Windows" }

switch ($_os) {
    "Windows" { }  # OK
    "macOS"   { Err "Ban dang dung macOS. Hay chay: ./vscode/setup_mac.sh" }
    "Linux"   { Err "Ban dang dung Linux. Hay chay: ./vscode/setup.sh" }
    default   { Err "He dieu hanh khong duoc ho tro: $_os" }
}

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ExtensionsFile = Join-Path $ScriptDir "extensions.txt"
$SettingsFile   = Join-Path $ScriptDir "setting.json"

# ============================================================
# VS Code settings path (Windows)
# ============================================================
function Get-VscodeSettingsDir {
    return "$env:APPDATA\Code\User"
}

# ============================================================
# 1. Kiem tra VS Code da cai chua
# ============================================================
# Duong dan VS Code khi cai bang .exe (mac dinh)
$VscodePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
)

function Check-Vscode {
    Header "Kiem tra VS Code..."

    if (Get-Command code -ErrorAction SilentlyContinue) {
        $ver = (code --version | Select-Object -First 1)
        Info "VS Code da duoc cai dat: $ver"
        return
    }

    # Cai bang .exe nhung chua co 'code' trong PATH
    $found = $null
    foreach ($p in $VscodePaths) {
        if (Test-Path $p) {
            $found = $p
            break
        }
    }

    if ($found) {
        $binDir = Split-Path $found
        Warn "VS Code da cai ($binDir) nhung lenh 'code' chua co trong PATH."
        Info "Dang them vao PATH..."

        # Them vao PATH cua User (persistent qua reboot)
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$binDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
            Info "Da them '$binDir' vao User PATH (persistent)."
        }

        # Them vao PATH cho session hien tai
        $env:Path = "$binDir;$env:Path"

        if (Get-Command code -ErrorAction SilentlyContinue) {
            $ver = (code --version | Select-Object -First 1)
            Info "VS Code: $ver"
        } else {
            Warn "Khong the xac nhan lenh 'code'. Thu dong lai PowerShell."
        }
    } else {
        Err "VS Code chua duoc cai dat. Hay cai VS Code truoc khi chay script nay.
       Download: https://code.visualstudio.com/download
       Hoac qua winget: winget install Microsoft.VisualStudioCode
       
       Neu da cai bang .exe, thu dong lai PowerShell de PATH duoc cap nhat."
    }
}

# ============================================================
# 2. Cai dat Extensions
# ============================================================
function Install-Extensions {
    Header "Cai dat VS Code Extensions..."

    if (-not (Test-Path $ExtensionsFile)) {
        Err "Khong tim thay file $ExtensionsFile"
    }

    $total     = 0
    $installed = 0
    $failed    = 0
    $skipped   = 0

    # Doc danh sach extensions da cai
    $currentExtensions = @(code --list-extensions 2>$null)

    $lines = Get-Content $ExtensionsFile
    foreach ($line in $lines) {
        $ext = $line.Trim()
        # Bo qua dong trong va comment
        if ([string]::IsNullOrWhiteSpace($ext) -or $ext.StartsWith("#")) { continue }

        $total++

        # Kiem tra extension da cai chua (case-insensitive)
        if ($currentExtensions -contains $ext) {
            Info ([char]0x2713 + " Da co: $ext")
            $skipped++
        } else {
            Write-Host -NoNewline "  Dang cai: $ext ... "
            try {
                $null = code --install-extension $ext --force 2>&1
                Write-Host "OK" -ForegroundColor Green
                $installed++
            } catch {
                Write-Host "FAILED" -ForegroundColor Red
                $failed++
            }
        }
    }

    Write-Host ""
    Info "Tong ket Extensions:"
    Write-Host "  Tong: $total | Da co: $skipped | Moi cai: $installed | Loi: $failed"
}

# ============================================================
# 3. Cau hinh Settings
# ============================================================
function Setup-Settings {
    Header "Cau hinh VS Code Settings..."

    if (-not (Test-Path $SettingsFile)) {
        Err "Khong tim thay file $SettingsFile"
    }

    $vscodeDir = Get-VscodeSettingsDir
    $targetSettings = Join-Path $vscodeDir "settings.json"

    # Tao thu muc settings neu chua co
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    }

    # Backup settings cu neu co
    if (Test-Path $targetSettings) {
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup = "$targetSettings.backup.$ts"
        Warn "Backup settings cu -> $backup"
        Copy-Item $targetSettings $backup
    }

    # Copy settings moi
    Copy-Item $SettingsFile $targetSettings -Force
    Info "Settings da duoc cap nhat tai: $targetSettings"
}

# ============================================================
# 4. Export extensions hien tai (tien ich)
# ============================================================
function Export-CurrentExtensions {
    Header "Export danh sach extensions hien tai..."
    $exportFile = Join-Path $ScriptDir "extensions.txt"
    code --list-extensions | Set-Content $exportFile -Encoding UTF8
    $count = (Get-Content $exportFile).Count
    Info "Da export $count extensions vao: $exportFile"
}

# ============================================================
# Menu & Main
# ============================================================
function Show-Help {
    Write-Host ""
    Write-Host "Usage: .\setup.ps1 [OPTION]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --all          Cai dat extensions + settings (mac dinh)"
    Write-Host "  --extensions   Chi cai dat extensions"
    Write-Host "  --settings     Chi cau hinh settings"
    Write-Host "  --export       Export danh sach extensions hien tai"
    Write-Host "  --help         Hien thi help"
    Write-Host ""
}

# ============================================================
# Main
# ============================================================
Write-Host "=========================================="
Write-Host "  VS Code Setup Script (Windows)"
Write-Host "=========================================="
Write-Host ""

Check-Vscode

$action = if ($args.Count -gt 0) { $args[0] } else { "--all" }

switch ($action) {
    "--all" {
        Install-Extensions
        Write-Host ""
        Setup-Settings
    }
    "--extensions" {
        Install-Extensions
    }
    "--settings" {
        Setup-Settings
    }
    "--export" {
        Export-CurrentExtensions
    }
    { $_ -eq "--help" -or $_ -eq "-h" } {
        Show-Help
        exit 0
    }
    default {
        Warn "Option khong hop le: $action"
        Show-Help
        exit 1
    }
}

Write-Host ""
Write-Host "=========================================="
Info "Hoan tat! Khoi dong lai VS Code de ap dung thay doi."
Write-Host "=========================================="
