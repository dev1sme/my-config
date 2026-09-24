# ============================================================
# Gradient ASCII banner (art shared with Linux: lib/banner.txt)
# ============================================================

function Write-MyConfigBanner([string]$Root, [string]$Repo) {
    $file = Join-Path $Root 'lib/banner.txt'
    $cols = 80
    try { $cols = [Console]::WindowWidth } catch {}

    if ($cols -lt 76 -or -not $script:UiUnicode -or -not (Test-Path $file)) {
        Write-Ui ''
        Write-Ui "  $($C.Bold)$($C.Cyan)my-config$($C.Reset) $($C.Dim)- dev1sme$($C.Reset)"
        return
    }

    $colors = @(51, 45, 39, 33, 63, 99)
    $i = 0
    Write-Ui ''
    foreach ($line in (Get-Content -Path $file -Encoding UTF8)) {
        if ($C.Reset) {
            Write-Ui "  $script:ESC[38;5;$($colors[$i % 6])m$line$($C.Reset)"
        } else {
            Write-Ui "  $line"
        }
        $i++
    }
    Write-Ui "  $($C.Dim)dev environment bootstrap $($G.Dot) github.com/$Repo$($C.Reset)"
}
