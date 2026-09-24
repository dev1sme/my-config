# ============================================================
# SSH Key Setup Script - Windows
# Tạo SSH key pair, cấu hình ssh-agent và ~/.ssh/config
# Yêu cầu: Windows 10 1809+ / Windows 11 (OpenSSH built-in)
# Chạy: PowerShell 5.1+ hoặc PowerShell 7+
# File lưu UTF-8 with BOM để PowerShell 5.1 đọc đúng tiếng Việt.
# ============================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '..\lib\ps\UI.ps1')
. (Join-Path $PSScriptRoot '..\lib\ps\Pkg.ps1')

function Info   { param($msg) Write-UiLog $msg }
function Warn   { param($msg) Write-UiLogWarn $msg }
function Err    { param($msg) Stop-UiFail $msg }
function Header { param($msg) Write-UiSection $msg }

# ============================================================
# Kiểm tra hệ điều hành
# ============================================================
# $IsWindows / $IsMacOS / $IsLinux có sẵn từ PowerShell 6+
# PS 5.1 chỉ chạy trên Windows nên mặc định là OK
$_os = if ($PSVersionTable.PSVersion.Major -ge 6) {
    if     ($IsWindows) { "Windows" }
    elseif ($IsMacOS)   { "macOS" }
    elseif ($IsLinux)   { "Linux" }
    else                { "Unknown" }
} else { "Windows" }

switch ($_os) {
    "Windows" { }  # OK
    "macOS"   { Err "Bạn đang dùng macOS. Hãy chạy: ./ssh/setup_mac.sh" }
    "Linux"   { Err "Bạn đang dùng Linux. Hãy chạy: ./ssh/setup.sh" }
    default   { Err "Hệ điều hành không được hỗ trợ: $_os" }
}

# ============================================================
# Defaults
# ============================================================
$KeyType    = "ed25519"
$KeyFile    = ""
$KeyComment = ""
$AddToAgent = $true

# ============================================================
# 0. Kiểm tra OpenSSH, thiếu thì cài OpenSSH Client (cần Admin)
# ============================================================
function Test-OpenSsh {
    if (Get-Command ssh-keygen -ErrorAction SilentlyContinue) { return }
    Header "Kiểm tra OpenSSH..."
    Warn "Không tìm thấy ssh-keygen."
    if (-not (Install-OpenSshClient)) {
        Err "Không cài được OpenSSH Client. Cài thủ công:
             Settings > Apps > Optional Features > Add a feature > OpenSSH Client"
    }
    Info "Đã cài OpenSSH Client."
}

# ============================================================
# Bước 1: Thu thập cấu hình (interactive)
# ============================================================
function Collect-Config {
    $idx = Read-UiSelect "Loại key" @("ed25519|khuyên dùng", "rsa|4096-bit")
    if ($null -eq $idx) { Err "Đã huỷ." }
    $script:KeyType = $(if ($idx -eq 1) { "rsa" } else { "ed25519" })

    $name = Read-UiText "Tên file key trong ~\.ssh\ (đặt riêng nếu có nhiều key, vd id_github)" "id_$script:KeyType"
    $script:KeyFile = Join-Path (Join-Path $env:USERPROFILE ".ssh") $name

    $script:KeyComment = Read-UiText "Comment / email cho key (vd you@example.com)" $script:KeyComment

    Write-UiNote "ssh-agent là gì?" @(
        "Service chạy ngầm, giữ private key đã unlock.",
        "ssh/git dùng key ngay, không hỏi passphrase mỗi lần.",
        "Nhiều key: chạy setup mỗi key một lần, agent giữ tất cả.",
        "",
        "$($C.Dim)Không thêm nếu muốn tự quản lý (ssh-add sau)$($C.Reset)",
        "$($C.Dim)hoặc chỉ muốn unlock key khi cần.$($C.Reset)"
    )
    $script:AddToAgent = [bool](Read-UiConfirm "Thêm key vào ssh-agent sau khi tạo?")

    Write-UiNote "Tóm tắt" @(
        "Loại key  : $script:KeyType",
        "File      : $script:KeyFile",
        "Comment   : $(if ($script:KeyComment) { $script:KeyComment } else { '(trống)' })",
        "ssh-agent : $(if ($script:AddToAgent) { 'có' } else { 'không' })"
    )
    if (-not (Read-UiConfirm "Tiếp tục?")) {
        Complete-UiModule "Đã huỷ."
        exit 0
    }
}

# ============================================================
# 2. Tạo thư mục .ssh
# ============================================================
function Setup-SshDir {
    Header "Kiểm tra thư mục .ssh..."
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir | Out-Null
        # Đặt quyền: chỉ owner đọc/ghi
        $acl = Get-Acl $sshDir
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl $sshDir $acl
        Info "Đã tạo $sshDir."
    } else {
        Info "$sshDir đã tồn tại."
    }
}

# ============================================================
# 3. Tạo SSH key pair
# ============================================================
function Generate-Key {
    Header "Tạo SSH key ($script:KeyType)..."

    if (Test-Path $script:KeyFile) {
        Warn "Key đã tồn tại: $script:KeyFile"
        if (-not (Read-UiConfirm "Ghi đè key cũ? (key cũ sẽ được backup)" -DefaultNo)) {
            Info "Bỏ qua bước tạo key, dùng key hiện có."
            return
        }
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup = "$script:KeyFile.bak.$ts"
        Move-Item $script:KeyFile $backup -Force
        if (Test-Path "$script:KeyFile.pub") {
            Move-Item "$script:KeyFile.pub" "$backup.pub" -Force
        }
        Warn "Key cũ đã được backup: $backup"
    }

    if ($script:KeyType -eq "rsa") {
        $rc = Invoke-UiRun { ssh-keygen -q -t rsa -b 4096 -f $script:KeyFile -C $script:KeyComment -N '""' }
    } else {
        $rc = Invoke-UiRun { ssh-keygen -q -t ed25519 -f $script:KeyFile -C $script:KeyComment -N '""' }
    }
    if ($rc -ne 0) { Err "ssh-keygen thất bại (exit $rc)." }

    Info "Private key : $script:KeyFile"
    Info "Public key  : $script:KeyFile.pub"
}

# ============================================================
# 4. Bật dịch vụ ssh-agent và thêm key
# ============================================================
function Add-ToAgent {
    if (-not $script:AddToAgent) { return }

    Header "Thêm key vào ssh-agent..."

    $svc = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
    if (-not $svc) {
        Warn "Không tìm thấy dịch vụ ssh-agent. Cài OpenSSH Client qua
              Settings > Apps > Optional Features."
        return
    }

    if ($svc.StartType -ne "Automatic") {
        Set-Service -Name ssh-agent -StartupType Automatic
        Info "Đã chuyển ssh-agent sang khởi động tự động."
    }

    if ($svc.Status -ne "Running") {
        Start-Service ssh-agent
        Info "Đã khởi động ssh-agent."
    } else {
        Info "ssh-agent đang chạy."
    }

    $fingerprint = (ssh-keygen -lf "$script:KeyFile.pub" 2>$null) -split ' ' | Select-Object -Index 1
    $inAgent = (ssh-add -l 2>$null) -match [regex]::Escape($fingerprint)
    if ($inAgent) {
        Info "Key đã có trong ssh-agent."
    } else {
        $null = Invoke-UiRun { ssh-add $script:KeyFile }
        Info "Đã thêm key vào ssh-agent."
    }
}

# ============================================================
# 5. Cấu hình ~/.ssh/config
# ============================================================
function Configure-SshConfig {
    if (-not (Read-UiConfirm "Cấu hình .ssh\config tự động?")) { return }

    Header "Cấu hình .ssh\config..."
    $configFile = Join-Path (Join-Path $env:USERPROFILE ".ssh") "config"
    $keyFileUnix = $script:KeyFile -replace '\\', '/'

    if (-not (Test-Path $configFile)) {
        $content = @"
# SSH Config - duoc tao boi ssh/setup.ps1

Host *
    AddKeysToAgent yes
    IdentityFile $keyFileUnix
    ServerAliveInterval 60
    ServerAliveCountMax 3
"@
        # UTF-8 không BOM: OpenSSH không đọc được BOM, ASCII làm hỏng tên user có dấu
        [IO.File]::WriteAllText($configFile, $content, (New-Object System.Text.UTF8Encoding $false))
        Info "Đã tạo $configFile."
    } elseif ((Get-Content $configFile -Raw) -match [regex]::Escape($keyFileUnix)) {
        Info "$configFile đã được cấu hình cho key này."
    } else {
        Warn "$configFile đã tồn tại và chưa có key này. Thêm thủ công nếu cần:
              IdentityFile $keyFileUnix"
    }

    Write-UiNote ".ssh\config" @(Get-Content $configFile)
    Write-UiNote "Thêm Host cho GitHub / server (notepad $configFile)" @(
        "Host github.com",
        "    HostName github.com",
        "    User git",
        "    IdentityFile $keyFileUnix",
        "",
        "Host myserver",
        "    HostName 192.168.1.100",
        "    User ubuntu",
        "    Port 22",
        "    IdentityFile $keyFileUnix"
    )
}

# ============================================================
# 6. In public key
# ============================================================
function Print-Pubkey {
    $pubkeyFile = "$script:KeyFile.pub"

    Header "Public key $($G.Dash) copy và thêm vào GitHub / server"
    if (-not (Test-Path $pubkeyFile)) {
        Warn "Không tìm thấy public key: $pubkeyFile"
        return
    }

    $pubkey = (Get-Content $pubkeyFile -Raw).Trim()

    # In nguyên dòng, không có viền │ để copy cho sạch
    Write-Ui ""
    Write-Ui $pubkey
    Write-Ui ""

    try {
        Set-Clipboard -Value $pubkey
        Info "Đã copy vào clipboard."
    } catch {
        Warn "Không copy được vào clipboard, copy thủ công từ trên."
    }

    Info "Xem lại        : Get-Content $pubkeyFile"
    Info "Thêm vào GitHub: https://github.com/settings/keys"
    Info "Thêm vào server: type $pubkeyFile | ssh user@host `"cat >> ~/.ssh/authorized_keys`""
}

# ============================================================
# Main
# ============================================================
Start-UiModule "SSH key (Windows)"
Test-OpenSsh
Collect-Config
Setup-SshDir
Generate-Key
Add-ToAgent
Configure-SshConfig
Print-Pubkey
Complete-UiModule "SSH key setup hoàn tất!"
