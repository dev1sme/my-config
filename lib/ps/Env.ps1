# ============================================================
# Environment detection (Windows)
# ============================================================

function Test-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-HasWsl {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    try {
        # wsl -l outputs UTF-16; any non-empty distro name means WSL is ready
        $distros = (& wsl.exe -l -q 2>$null) -replace "`0", '' | Where-Object { $_.Trim() }
        return [bool]$distros
    } catch {
        return $false
    }
}

function Get-MyConfigEnv {
    $osName = 'Windows'
    try {
        $osName = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption.Trim()
    } catch {
        try { $osName = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription } catch {}
    }

    $arch = $env:PROCESSOR_ARCHITECTURE
    if (-not $arch) {
        try { $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() } catch { $arch = '?' }
    }

    return [pscustomobject]@{
        OsName    = $osName
        Arch      = $arch
        User      = [Environment]::UserName
        IsAdmin   = Test-IsAdmin
        HasWsl    = Test-HasWsl
        PsVersion = $PSVersionTable.PSVersion.ToString()
        PsExe     = (Get-Process -Id $PID).Path
    }
}
