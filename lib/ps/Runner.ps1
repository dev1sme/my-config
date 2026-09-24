# ============================================================
# Module runner: execution, summary
# Requires: UI.ps1, Env.ps1
# ============================================================

$script:Results = @()

# Module scripts check this to skip their own intro/outro (see Start-UiModule)
$env:MY_CONFIG_INSTALLER = '1'

function New-LogDir {
    if ($env:LOCALAPPDATA) {
        $base = Join-Path $env:LOCALAPPDATA 'my-config/logs'
    } else {
        $base = Join-Path $HOME '.local/state/my-config/logs'
    }
    $dir = Join-Path $base (Get-Date -Format 'yyyyMMdd_HHmmss')
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Invoke-MyConfigModule($Module, [string]$PsExe, [string]$LogDir) {
    $label = $Module.Label
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$($Module.Script)`""

    if ($Module.Mode -eq 'bg') {
        $log = Join-Path $LogDir "$($Module.Id).log"
        $r = Invoke-UiSpin "Cài $label" $log $PsExe $psArgs
        $rc = $r.ExitCode; $elapsed = $r.Elapsed
        if ($rc -ne 0) {
            Write-UiLine "$($C.Dim)Log: $log$($C.Reset)"
            foreach ($l in (Get-Content $log -Tail 12 -ErrorAction SilentlyContinue)) {
                Write-UiLine "$($C.Dim)$($l -replace "$([char]27)\[[0-9;]*m", '')$($C.Reset)"
            }
            Write-UiBar
        }
    } else {
        Write-UiActive "Cài $label $($C.Dim)(tương tác)$($C.Reset)"
        Write-UiBar
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $p = Start-Process -FilePath $PsExe -ArgumentList $psArgs -NoNewWindow -Wait -PassThru
        $rc = $p.ExitCode
        $elapsed = [int]$watch.Elapsed.TotalSeconds
        Write-UiBar
        if ($rc -eq 0) {
            Write-UiStep "Cài $label $($C.Dim)($($elapsed)s)$($C.Reset)"
        } else {
            Write-UiError "Cài $label $($C.Dim)(exit $rc)$($C.Reset)"
        }
    }

    $script:Results += [pscustomobject]@{ Module = $Module; ExitCode = $rc; Elapsed = $elapsed }
}

# Print result box + next steps. Returns number of failed modules.
function Write-MyConfigSummary([string]$LogDir) {
    $summary = @(); $next = @(); $failed = 0
    foreach ($r in $script:Results) {
        if ($r.ExitCode -eq 0) {
            $summary += "$($C.Green)$($G.Check)$($C.Reset) $($r.Module.Label) $($C.Dim)$($r.Elapsed)s$($C.Reset)"
            if ($r.Module.Next) { $next += $r.Module.Next }
        } else {
            $summary += "$($C.Red)$($G.Cross)$($C.Reset) $($r.Module.Label) $($C.Dim)exit $($r.ExitCode)$($C.Reset)"
            $failed++
        }
    }
    $summary += ''
    $summary += "$($C.Dim)Logs: $LogDir$($C.Reset)"
    Write-UiNote 'Kết quả' $summary

    if ($next.Count -gt 0) {
        Write-UiNote 'Bước tiếp theo' $next
    }
    return $failed
}
