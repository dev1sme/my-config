# ============================================================
# UI prompts: multiselect, select, confirm, text
# Requires: UI.Core.ps1
# ============================================================

# Collapsed view of an answered prompt
function Write-UiAnswered([string]$Question, [string]$Answer) {
    Write-Ui "$($C.Green)$($G.Done)$($C.Reset)  $Question"
    Write-Ui "$script:UiBar  $($C.Dim)$Answer$($C.Reset)"
    Write-UiBar
}

function Write-UiCancelled([string]$Question) {
    Write-Ui "$($C.Red)$($G.Error)$($C.Reset)  $Question"
    Write-UiBar
}

# Multi-select
# Usage: Read-UiMultiSelect "Question" @("label|hint|on", "label|hint|off")
# Returns selected indices, or $null when cancelled.
function Read-UiMultiSelect([string]$Question, [string[]]$Options) {
    $labels = @(); $hints = @(); $sel = @()
    foreach ($opt in $Options) {
        $parts = $opt.Split('|')
        $labels += $parts[0]
        $hints += $(if ($parts.Count -gt 1) { $parts[1] } else { '' })
        $sel += $(if ($parts.Count -gt 2 -and $parts[2] -eq 'on') { 1 } else { 0 })
    }
    $n = $labels.Count
    $cur = 0; $drawn = 0
    $help = "$([char]0x2191)/$([char]0x2193) di chuyển $($G.Dot) space chọn $($G.Dot) a chọn tất cả $($G.Dot) enter xác nhận"
    if (-not $script:UiUnicode) { $help = 'up/down di chuyen - space chon - a chon tat ca - enter xac nhan' }
    $footer = $help

    Set-UiCursor $false
    while ($true) {
        Clear-UiLines $drawn
        Write-UiActive $Question
        for ($i = 0; $i -lt $n; $i++) {
            if ($sel[$i] -eq 1) { $box = "$($C.Green)$($G.BoxOn)$($C.Reset)" }
            elseif ($i -eq $cur) { $box = "$($C.Cyan)$($G.BoxOff)$($C.Reset)" }
            else { $box = "$($C.Dim)$($G.BoxOff)$($C.Reset)" }

            if ($i -eq $cur) {
                $text = $labels[$i]
                if ($hints[$i]) { $text += " $($C.Dim)($($hints[$i]))$($C.Reset)" }
            } else {
                $text = "$($C.Dim)$($labels[$i])$($C.Reset)"
            }
            Write-Ui "$($C.Cyan)$($G.Bar)$($C.Reset)  $box $text"
        }
        if ($footer -eq $help) {
            Write-Ui "$($C.Cyan)$($G.Bottom)$($C.Reset)  $($C.Dim)$footer$($C.Reset)"
        } else {
            Write-Ui "$($C.Yellow)$($G.Bottom)$($C.Reset)  $($C.Yellow)$footer$($C.Reset)"
        }
        $drawn = $n + 2
        $footer = $help

        switch (Read-UiKey) {
            'up'    { $cur = ($cur - 1 + $n) % $n }
            'down'  { $cur = ($cur + 1) % $n }
            'space' { $sel[$cur] = 1 - $sel[$cur] }
            'all' {
                $count = ($sel | Measure-Object -Sum).Sum
                for ($i = 0; $i -lt $n; $i++) { $sel[$i] = $(if ($count -eq $n) { 0 } else { 1 }) }
            }
            'enter' {
                if (($sel | Measure-Object -Sum).Sum -gt 0) {
                    Clear-UiLines $drawn
                    Set-UiCursor $true
                    $result = @(); $names = @()
                    for ($i = 0; $i -lt $n; $i++) {
                        if ($sel[$i] -eq 1) { $result += $i; $names += $labels[$i] }
                    }
                    Write-UiAnswered $Question ($names -join ', ')
                    return , $result
                }
                $footer = 'Chọn ít nhất 1 mục (bấm space để chọn)'
            }
            'cancel' {
                Clear-UiLines $drawn
                Set-UiCursor $true
                Write-UiCancelled $Question
                return $null
            }
        }
    }
}

# Single select
# Usage: Read-UiSelect "Question" @("label|hint", ...)
# Returns selected index, or $null when cancelled.
function Read-UiSelect([string]$Question, [string[]]$Options) {
    $labels = @(); $hints = @()
    foreach ($opt in $Options) {
        $parts = $opt.Split('|')
        $labels += $parts[0]
        $hints += $(if ($parts.Count -gt 1) { $parts[1] } else { '' })
    }
    $n = $labels.Count
    $cur = 0; $drawn = 0

    Set-UiCursor $false
    while ($true) {
        Clear-UiLines $drawn
        Write-UiActive $Question
        for ($i = 0; $i -lt $n; $i++) {
            if ($i -eq $cur) {
                $text = "$($C.Green)$($G.RadioOn)$($C.Reset) $($labels[$i])"
                if ($hints[$i]) { $text += " $($C.Dim)($($hints[$i]))$($C.Reset)" }
            } else {
                $text = "$($C.Dim)$($G.RadioOff) $($labels[$i])$($C.Reset)"
            }
            Write-Ui "$($C.Cyan)$($G.Bar)$($C.Reset)  $text"
        }
        Write-Ui "$($C.Cyan)$($G.Bottom)$($C.Reset)"
        $drawn = $n + 2

        $key = Read-UiKey
        if ($key -in 'up', 'left') { $cur = ($cur - 1 + $n) % $n }
        elseif ($key -in 'down', 'right', 'tab') { $cur = ($cur + 1) % $n }
        elseif ($key -in 'enter', 'space') { break }
        elseif ($key -eq 'cancel') {
            Clear-UiLines $drawn
            Set-UiCursor $true
            Write-UiCancelled $Question
            return $null
        }
    }

    Clear-UiLines $drawn
    Set-UiCursor $true
    Write-UiAnswered $Question $labels[$cur]
    return $cur
}

# Yes/No confirm
# Usage: Read-UiConfirm "Question" [-DefaultNo]
# Returns $true / $false, or $null when cancelled.
function Read-UiConfirm([string]$Question, [switch]$DefaultNo) {
    $yes = -not $DefaultNo
    $drawn = 0

    Set-UiCursor $false
    while ($true) {
        Clear-UiLines $drawn
        Write-UiActive $Question
        if ($yes) {
            $yesTxt = "$($C.Green)$($G.RadioOn)$($C.Reset) Có"
            $noTxt = "$($C.Dim)$($G.RadioOff) Không$($C.Reset)"
        } else {
            $yesTxt = "$($C.Dim)$($G.RadioOff) Có$($C.Reset)"
            $noTxt = "$($C.Green)$($G.RadioOn)$($C.Reset) Không"
        }
        Write-Ui "$($C.Cyan)$($G.Bar)$($C.Reset)  $yesTxt $($C.Dim)/$($C.Reset) $noTxt"
        Write-Ui "$($C.Cyan)$($G.Bottom)$($C.Reset)"
        $drawn = 3

        $key = Read-UiKey
        if ($key -in 'left', 'right', 'up', 'down', 'tab') { $yes = -not $yes }
        elseif ($key -eq 'yes') { $yes = $true; break }
        elseif ($key -eq 'no') { $yes = $false; break }
        elseif ($key -eq 'enter') { break }
        elseif ($key -eq 'cancel') {
            Clear-UiLines $drawn
            Set-UiCursor $true
            Write-UiCancelled $Question
            return $null
        }
    }

    Clear-UiLines $drawn
    Set-UiCursor $true
    Write-UiAnswered $Question $(if ($yes) { 'Có' } else { 'Không' })
    return $yes
}

# Free text input
# Usage: Read-UiText "Question" [default]
function Read-UiText([string]$Question, [string]$Default = '') {
    Write-UiActive $Question
    if ($Default) {
        Write-Ui "$($C.Cyan)$($G.Bar)$($C.Reset)  $($C.Dim)($Default)$($C.Reset) " -NoNewline
    } else {
        Write-Ui "$($C.Cyan)$($G.Bar)$($C.Reset)  " -NoNewline
    }
    $reply = [Console]::ReadLine()
    if ([string]::IsNullOrEmpty($reply)) { $reply = $Default }
    Clear-UiLines 2
    Write-UiAnswered $Question $(if ($reply) { $reply } else { '(trống)' })
    return $reply
}
