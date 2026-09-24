# ============================================================
# UI spinner for long-running background processes
# Requires: UI.Core.ps1
# ============================================================

$script:UiSpinProcess = $null

# Run a process with a spinner, stdout + stderr go to LogFile
# Usage: Invoke-UiSpin "message" "C:\path\to.log" "powershell.exe" "-File `"x.ps1`""
# Returns @{ ExitCode; Elapsed }
function Invoke-UiSpin([string]$Message, [string]$LogFile, [string]$FilePath, [string]$Arguments) {
    $errFile = "$LogFile.err"
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $LogFile -RedirectStandardError $errFile
    $null = $p.Handle   # keep handle so ExitCode stays available after exit
    $script:UiSpinProcess = $p

    Set-UiCursor $false
    $i = 0
    while (-not $p.HasExited) {
        if ($script:UiInteractive) {
            $frame = $G.Spin[$i % $G.Spin.Count]
            $sec = [int]$watch.Elapsed.TotalSeconds
            Write-Ui "`r$($C.Magenta)$frame$($C.Reset)  $Message $($C.Dim)($($sec)s)$($C.Reset)   " -NoNewline
        }
        $i++
        Start-Sleep -Milliseconds 120
    }
    $p.WaitForExit()
    $watch.Stop()
    $script:UiSpinProcess = $null

    if (Test-Path $errFile) {
        Get-Content $errFile | Add-Content $LogFile
        Remove-Item $errFile -Force
    }

    if ($script:UiInteractive) {
        Write-Ui ("`r" + (' ' * ((Get-UiWidth $Message) + 16)) + "`r") -NoNewline
    }
    Set-UiCursor $true

    $elapsed = [int]$watch.Elapsed.TotalSeconds
    if ($p.ExitCode -eq 0) {
        Write-UiStep "$Message $($C.Dim)($($elapsed)s)$($C.Reset)"
    } else {
        Write-UiError "$Message $($C.Dim)(exit $($p.ExitCode))$($C.Reset)"
    }
    return @{ ExitCode = $p.ExitCode; Elapsed = $elapsed }
}
