# ============================================================
# Package helpers for Windows module scripts
# Requires: UI.ps1 (dot-source it first)
#
# Usage: . (Join-Path $ScriptDir '..\lib\ps\Pkg.ps1')
#
#   Test-IsAdminSession               -> $true when elevated
#   Update-SessionPath                reload PATH from registry
#   Install-WingetPackage <id>        -> $true on success / already installed
#   Install-OpenSshClient             -> $true on success (needs Admin)
# ============================================================

# winget exit codes: package already installed / no newer version
$script:WingetAlreadyInstalled = @(-1978335189, -1978335135)

function Test-IsAdminSession {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Install-WingetPackage([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-UiLogWarn "Không có winget. Cài 'App Installer' từ Microsoft Store."
        return $false
    }
    Write-UiLog "winget install $Id ..."
    $rc = Invoke-UiRun { winget install --id $Id --exact --silent --accept-source-agreements --accept-package-agreements }
    Update-SessionPath
    return ($rc -eq 0 -or $script:WingetAlreadyInstalled -contains $rc)
}

function Install-OpenSshClient {
    if (-not (Test-IsAdminSession)) {
        Write-UiLogWarn "Cần quyền Admin để cài OpenSSH Client."
        return $false
    }
    Write-UiLog "Cài OpenSSH Client (Windows optional feature)..."
    try {
        $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Client*' | Select-Object -First 1
        if ($cap -and $cap.State -ne 'Installed') {
            Add-WindowsCapability -Online -Name $cap.Name | Out-Null
        }
        Update-SessionPath
        return [bool](Get-Command ssh-keygen -ErrorAction SilentlyContinue)
    } catch {
        Write-UiLogWarn $_.Exception.Message
        return $false
    }
}
