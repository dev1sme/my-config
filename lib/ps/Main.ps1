# ============================================================
# my-config installer — Windows main flow
# Launched by install.ps1 (bootstrap) in a child process with
# -ExecutionPolicy Bypass so the lib files can be dot-sourced.
# ============================================================

#Requires -Version 5.1

param(
    [string]$Only = '',
    [switch]$All,
    [switch]$Yes,
    [switch]$List,
    [string]$Repo = 'dev1sme/my-config',
    [string]$Ref = 'main'
)

$Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

. (Join-Path $PSScriptRoot 'UI.ps1')
. (Join-Path $PSScriptRoot 'Banner.ps1')
. (Join-Path $PSScriptRoot 'Env.ps1')
. (Join-Path $PSScriptRoot 'Modules.ps1')
. (Join-Path $PSScriptRoot 'Runner.ps1')

$modules = Get-MyConfigModules $Root

if ($List) {
    foreach ($m in $modules) { Write-Ui ('{0,-8} {1}' -f $m.Id, $m.Label) }
    exit 0
}

try {
    Write-MyConfigBanner $Root $Repo
    Write-UiIntro 'my-config setup'

    $envInfo = Get-MyConfigEnv
    $who = $envInfo.User
    if ($envInfo.IsAdmin) { $who += ' (Admin)' }
    Write-UiStep "Hệ thống: $($envInfo.OsName) $($G.Dot) $($envInfo.Arch) $($G.Dot) PowerShell $($envInfo.PsVersion) $($G.Dot) user $who"

    # ---- Select modules ----
    $selected = @()
    if ($Only) {
        foreach ($item in ($Only -split '[,\s]+' | Where-Object { $_ })) {
            $m = $modules | Where-Object { $_.Id -eq $item }
            if (-not $m) {
                Stop-UiCancel "Module '$item' không khả dụng trên Windows. Có: $(($modules | ForEach-Object Id) -join ', ')" 2
            }
            $selected += $m
        }
        Write-UiStep "Module: $(($selected | ForEach-Object Id) -join ', ')"
    } elseif ($All) {
        $selected = $modules
        Write-UiStep "Module: $(($selected | ForEach-Object Id) -join ', ')"
    } elseif ($script:UiInteractive) {
        $opts = @($modules | ForEach-Object { "$($_.Label)|$($_.Hint)|$($_.Default)" })
        $picked = Read-UiMultiSelect 'Chọn module cần cài' $opts
        if ($null -eq $picked) { Stop-UiCancel 'Đã huỷ.' }
        foreach ($i in $picked) { $selected += $modules[$i] }
    } else {
        Stop-UiCancel 'Không có terminal tương tác. Dùng -Only <module> hoặc -All.' 2
    }

    # ---- Confirm ----
    $plan = @()
    foreach ($m in $selected) {
        $how = $(if ($m.Mode -eq 'tty') { 'sẽ hỏi thêm vài câu' } else { 'tự động' })
        if ($m.NeedAdmin -and -not $envInfo.IsAdmin) { $how += ', cần Admin' }
        $plan += "$($C.Cyan)$($G.Bullet)$($C.Reset) $($m.Label) $($C.Dim)$($G.Dash) $how$($C.Reset)"
    }
    Write-UiNote 'Kế hoạch' $plan
    Write-UiBar

    if (-not $Yes -and $script:UiInteractive) {
        $ok = Read-UiConfirm 'Bắt đầu cài đặt?'
        if (-not $ok) { Stop-UiCancel 'Đã huỷ, chưa thay đổi gì.' }
    }

    # ---- Admin: relaunch the whole installer elevated ----
    $needAdmin = @($selected | Where-Object { $_.NeedAdmin }).Count -gt 0
    if ($needAdmin -and -not $envInfo.IsAdmin) {
        $relaunch = $true
        if (-not $Yes -and $script:UiInteractive) {
            $relaunch = Read-UiConfirm 'Mở lại installer với quyền Admin? (Không = chạy tiếp, bước cần Admin có thể lỗi)'
            if ($null -eq $relaunch) { Stop-UiCancel 'Đã huỷ, chưa thay đổi gì.' }
        }
        if ($relaunch) {
            $ids = ($selected | ForEach-Object Id) -join ','
            $argLine = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" -Only $ids -Yes -Repo $Repo -Ref $Ref"
            try {
                Start-Process -FilePath $envInfo.PsExe -Verb RunAs -ArgumentList $argLine | Out-Null
                Write-UiOutro "$($C.Cyan)Đã mở cửa sổ Admin, tiếp tục ở đó.$($C.Reset)"
                exit 0
            } catch {
                Write-UiWarn 'Không mở được quyền Admin (UAC bị từ chối). Chạy tiếp không Admin.'
            }
        }
    }

    # ---- Run ----
    $logDir = New-LogDir
    foreach ($m in $selected) {
        Invoke-MyConfigModule $m $envInfo.PsExe $logDir
    }

    $failed = Write-MyConfigSummary $logDir
    if ($failed -eq 0) {
        Write-UiOutro "$($C.Green)Hoàn tất!$($C.Reset)"
    } else {
        Write-UiOutro "$($C.Yellow)Xong, có $failed module lỗi. Xem log ở trên.$($C.Reset)"
        exit 1
    }
} finally {
    Set-UiCursor $true
    if ($script:UiSpinProcess -and -not $script:UiSpinProcess.HasExited) {
        try { $script:UiSpinProcess.Kill() } catch {}
    }
}
