# ============================================================
# Package helpers for Windows module scripts
# Keep this file ASCII: module scripts are read by PowerShell 5.1
#
# Usage: . (Join-Path $ScriptDir '..\lib\ps\Pkg.ps1')
#
#   Test-IsAdminSession               -> $true when elevated
#   Update-SessionPath                reload PATH from registry
#   Install-WingetPackage <id>        -> $true on success / already installed
#   Install-OpenSshClient             -> $true on success (needs Admin)
# ============================================================

# winget exit code when the package is already installed / no newer version
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
        Write-Host "[WARN] Khong co winget. Cai 'App Installer' tu Microsoft Store." -ForegroundColor Yellow
        return $false
    }
    Write-Host "[INFO] winget install $Id ..." -ForegroundColor Green
    & winget install --id $Id --exact --silent --accept-source-agreements --accept-package-agreements | Out-Host
    $rc = $LASTEXITCODE
    Update-SessionPath
    return ($rc -eq 0 -or $script:WingetAlreadyInstalled -contains $rc)
}

function Install-OpenSshClient {
    if (-not (Test-IsAdminSession)) {
        Write-Host "[WARN] Can quyen Admin de cai OpenSSH Client." -ForegroundColor Yellow
        return $false
    }
    Write-Host "[INFO] Cai OpenSSH Client (Windows optional feature)..." -ForegroundColor Green
    try {
        $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Client*' | Select-Object -First 1
        if ($cap -and $cap.State -ne 'Installed') {
            Add-WindowsCapability -Online -Name $cap.Name | Out-Null
        }
        Update-SessionPath
        return [bool](Get-Command ssh-keygen -ErrorAction SilentlyContinue)
    } catch {
        Write-Host "[WARN] $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}
