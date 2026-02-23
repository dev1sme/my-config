# ============================================================
# SSH Key Setup Script - Windows
# Tao SSH key pair, cau hinh ssh-agent va ~/.ssh/config
# Yeu cau: Windows 10 1809+ / Windows 11 (OpenSSH built-in)
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

function Prompt-Input {
    param([string]$Question, [string]$Default = "")
    if ($Default) {
        Write-Host -NoNewline "  ? $Question [$Default]: " -ForegroundColor Cyan
    } else {
        Write-Host -NoNewline "  ? $Question : " -ForegroundColor Cyan
    }
    $reply = Read-Host
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = $Default }
    return $reply
}

function Prompt-YN {
    param([string]$Question, [string]$Default = "y")
    $hint = if ($Default -eq "y") { "Y/n" } else { "y/N" }
    Write-Host -NoNewline "  ? $Question [$hint]: " -ForegroundColor Cyan
    $reply = Read-Host
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = $Default }
    return $reply -match "^[Yy]"
}

# ============================================================
# Kiem tra he dieu hanh
# ============================================================
# $IsWindows / $IsMacOS / $IsLinux co san tu PowerShell 6+
# PS 5.1 chi chay tren Windows nen mac dinh la OK
$_os = if ($PSVersionTable.PSVersion.Major -ge 6) {
    if     ($IsWindows) { "Windows" }
    elseif ($IsMacOS)   { "macOS" }
    elseif ($IsLinux)   { "Linux" }
    else                { "Unknown" }
} else { "Windows" }

switch ($_os) {
    "Windows" { }  # OK
    "macOS"   { Err "Ban dang dung macOS. Hay chay: ./ssh/setup_mac.sh" }
    "Linux"   { Err "Ban dang dung Linux. Hay chay: ./ssh/setup.sh" }
    default   { Err "He dieu hanh khong duoc ho tro: $_os" }
}

# Kiem tra OpenSSH co san khong
if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    Err "Khong tim thay ssh-keygen. Hay cai OpenSSH:
    Settings > Apps > Optional Features > Add a feature > OpenSSH Client"
}

# ============================================================
# Defaults
# ============================================================
$KeyType    = "ed25519"
$KeyFile    = ""
$KeyComment = ""
$AddToAgent = $true

# ============================================================
# Buoc 0: Thu thap cau hinh (interactive)
# ============================================================
function Collect-Config {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Cau hinh SSH Key (Windows)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # --- Key type ---
    Write-Host "  Loai key duoc ho tro:"
    Write-Host "    1) ed25519  " -NoNewline; Write-Host "(khuyen dung)" -ForegroundColor Green
    Write-Host "    2) rsa      (4096-bit)"
    Write-Host -NoNewline "  ? Chon loai key [1]: " -ForegroundColor Cyan
    $choice = Read-Host
    $script:KeyType = if ($choice -eq "2" -or $choice -eq "rsa") { "rsa" } else { "ed25519" }
    Info "Loai key: $script:KeyType"
    Write-Host ""

    # --- Key file ---
    $defaultName = if ($script:KeyType -eq "rsa") { "id_rsa" } else { "id_ed25519" }
    Write-Host "  " -NoNewline
    Write-Host "Tip:" -NoNewline -ForegroundColor Yellow
    Write-Host " Dat ten rieng neu ban co nhieu key, vd: " -NoNewline
    Write-Host "id_github" -NoNewline -ForegroundColor Yellow
    Write-Host ", " -NoNewline
    Write-Host "id_work" -ForegroundColor Yellow
    $name = Prompt-Input "Ten file key (luu vao $env:USERPROFILE\.ssh\)" $defaultName
    $script:KeyFile = "$env:USERPROFILE\.ssh\$name"
    Info "File key: $script:KeyFile"
    Write-Host ""

    # --- Comment ---
    Write-Host "  " -NoNewline
    Write-Host "Tip:" -NoNewline -ForegroundColor Yellow
    Write-Host " Nen dung email de de nhan dien key, vd: " -NoNewline
    Write-Host "you@example.com" -ForegroundColor Yellow
    $script:KeyComment = Prompt-Input "Comment / email cho key" ""
    Info "Comment: $script:KeyComment"
    Write-Host ""

    # --- Add to agent ---
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Them key vao ssh-agent?" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  " -NoNewline; Write-Host "ssh-agent" -NoNewline -ForegroundColor Yellow; Write-Host " tren Windows:"
    Write-Host "    Dich vu OpenSSH Authentication Agent chay ngam trong Windows."
    Write-Host "    Giu private key da unlock → ssh/git dung ngay, khong hoi passphrase."
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[Y] Them vao ssh-agent" -NoNewline -ForegroundColor Green
    Write-Host " (khuyen dung)" -ForegroundColor Green
    Write-Host "      Script se bat dich vu va them key tu dong."
    Write-Host "      Neu co nhieu key, moi key chay setup mot lan → agent giu tat ca."
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[N] Khong them" -ForegroundColor Yellow
    Write-Host "      Phu hop neu ban muon quan ly key thu cong (ssh-add sau)."
    Write-Host "      Hoac neu dung passphrase va chi muon unlock khi can."
    Write-Host ""
    $script:AddToAgent = Prompt-YN "Them key vao ssh-agent sau khi tao?" "y"
    if ($script:AddToAgent) {
        Info "Se them vao ssh-agent."
    } else {
        Info "Bo qua. Them thu cong sau bang: ssh-add `"$script:KeyFile`""
    }
    Write-Host ""

    $agentLabel = if ($script:AddToAgent) { "co" } else { "khong" }
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Tom tat:"
    Write-Host "    Loai key  : " -NoNewline; Write-Host $script:KeyType -ForegroundColor Yellow
    Write-Host "    File      : " -NoNewline; Write-Host $script:KeyFile -ForegroundColor Yellow
    Write-Host "    Comment   : " -NoNewline; Write-Host $script:KeyComment -ForegroundColor Yellow
    Write-Host "    ssh-agent : " -NoNewline; Write-Host $agentLabel -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    $ok = Prompt-YN "Tiep tuc?" "y"
    if (-not $ok) { Info "Da huy."; exit 0 }
    Write-Host ""
}

# ============================================================
# 1. Tao thu muc .ssh
# ============================================================
function Setup-SshDir {
    Header "Kiem tra thu muc .ssh..."
    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) {
        Info "Tao thu muc $sshDir..."
        New-Item -ItemType Directory -Path $sshDir | Out-Null
        # Dat quyen: chi owner doc/ghi
        $acl = Get-Acl $sshDir
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl $sshDir $acl
        Info "Da tao $sshDir."
    } else {
        Info "$sshDir da ton tai."
    }
}

# ============================================================
# 2. Tao SSH key pair
# ============================================================
function Generate-Key {
    Header "Tao SSH key ($script:KeyType)..."

    if (Test-Path $script:KeyFile) {
        Warn "Key da ton tai: $script:KeyFile"
        $confirm = Prompt-YN "Ghi de key cu?" "n"
        if (-not $confirm) {
            Info "Bo qua buoc tao key."
            return
        }
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup = "$script:KeyFile.bak.$ts"
        Move-Item $script:KeyFile $backup -Force
        if (Test-Path "$script:KeyFile.pub") {
            Move-Item "$script:KeyFile.pub" "$backup.pub" -Force
        }
        Warn "Key cu da duoc backup: $backup"
    }

    Info "Dang tao key: $script:KeyFile ($script:KeyType)..."

    if ($script:KeyType -eq "rsa") {
        ssh-keygen -t rsa -b 4096 -f $script:KeyFile -C $script:KeyComment -N '""'
    } else {
        ssh-keygen -t ed25519 -f $script:KeyFile -C $script:KeyComment -N '""'
    }

    Info "Da tao key thanh cong:"
    Info "  Private key : $script:KeyFile"
    Info "  Public key  : $script:KeyFile.pub"
}

# ============================================================
# 3. Bat dich vu ssh-agent va them key
# ============================================================
function Add-ToAgent {
    if (-not $script:AddToAgent) { return }

    Header "Them key vao ssh-agent..."

    # Kiem tra dich vu ssh-agent
    $svc = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
    if (-not $svc) {
        Warn "Khong tim thay dich vu ssh-agent."
        Warn "Hay cai OpenSSH Client qua Settings > Apps > Optional Features."
        return
    }

    if ($svc.StartType -ne "Automatic") {
        Info "Chuyen ssh-agent sang khoi dong tu dong (Automatic)..."
        Set-Service -Name ssh-agent -StartupType Automatic
    }

    if ($svc.Status -ne "Running") {
        Info "Khoi dong dich vu ssh-agent..."
        Start-Service ssh-agent
        Info "ssh-agent da khoi dong."
    } else {
        Info "ssh-agent dang chay."
    }

    # Kiem tra key da co trong agent chua
    $fingerprint = (ssh-keygen -lf "$script:KeyFile.pub" 2>$null) -split ' ' | Select-Object -Index 1
    $inAgent = (ssh-add -l 2>$null) -match [regex]::Escape($fingerprint)
    if ($inAgent) {
        Info "Key da co trong ssh-agent."
    } else {
        ssh-add $script:KeyFile
        Info "Da them key vao ssh-agent."
    }
}

# ============================================================
# 4. Cau hinh ~/.ssh/config
# ============================================================
function Configure-SshConfig {
    Header "Cau hinh .ssh\config..."

    $ok = Prompt-YN "Cau hinh .ssh\config tu dong?" "y"
    if (-not $ok) {
        Info "Bo qua buoc cau hinh .ssh\config."
        return
    }

    $configFile = "$env:USERPROFILE\.ssh\config"
    $keyFileUnix = $script:KeyFile -replace '\\', '/'

    if (-not (Test-Path $configFile)) {
        Info "Tao file $configFile..."
        @"
# SSH Config - duoc tao boi ssh/setup.ps1

Host *
    AddKeysToAgent yes
    IdentityFile $keyFileUnix
    ServerAliveInterval 60
    ServerAliveCountMax 3
"@ | Set-Content $configFile -Encoding UTF8
        Info "Da tao $configFile."
    } else {
        if ((Get-Content $configFile -Raw) -match [regex]::Escape($script:KeyFile)) {
            Info "$configFile da duoc cau hinh cho key nay."
        } else {
            Warn "$configFile da ton tai va chua co IdentityFile $script:KeyFile."
            Warn "Them thu cong dong sau vao $configFile neu can:"
            Write-Host ""
            Write-Host "    IdentityFile $keyFileUnix"
            Write-Host ""
        }
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  Noi dung .ssh\config hien tai" -ForegroundColor Green
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Get-Content $configFile
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "De chinh sua them (them Host cho tung server/GitHub):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    notepad  $configFile"
    Write-Host "    code     $configFile"
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "Vi du them Host cho GitHub:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Host github.com"
    Write-Host "        HostName github.com"
    Write-Host "        User git"
    Write-Host "        AddKeysToAgent yes"
    Write-Host "        IdentityFile $keyFileUnix"
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "Vi du them Host cho server:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Host myserver"
    Write-Host "        HostName 192.168.1.100"
    Write-Host "        User ubuntu"
    Write-Host "        AddKeysToAgent yes"
    Write-Host "        IdentityFile $keyFileUnix"
    Write-Host "        Port 22"
    Write-Host ""
}

# ============================================================
# 5. In public key
# ============================================================
function Print-Pubkey {
    $pubkeyFile = "$script:KeyFile.pub"

    if (-not (Test-Path $pubkeyFile)) {
        Warn "Khong tim thay public key: $pubkeyFile"
        return
    }

    $pubkey = Get-Content $pubkeyFile -Raw
    $pubkey = $pubkey.Trim()

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  PUBLIC KEY - Copy va them vao GitHub / server"
    Write-Host "============================================================"
    Write-Host $pubkey
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Xem lai bat cu luc nao:" -ForegroundColor Yellow
    Write-Host "    type $pubkeyFile"
    Write-Host "    Get-Content $pubkeyFile"
    Write-Host ""

    try {
        Set-Clipboard -Value $pubkey
        Info "Public key da duoc copy vao clipboard."
    } catch {
        Warn "Khong the copy vao clipboard tu dong. Copy thu cong tu tren."
    }

    Info "Them vao GitHub  : https://github.com/settings/keys"
    Info "Them vao server  : type $pubkeyFile | ssh user@host `"cat >> ~/.ssh/authorized_keys`""
}

# ============================================================
# Main
# ============================================================
Header "SSH Key Setup (Windows)"
Collect-Config
Setup-SshDir
Generate-Key
Add-ToAgent
Configure-SshConfig
Print-Pubkey

Write-Host ""
Info "SSH key setup hoan tat!"
