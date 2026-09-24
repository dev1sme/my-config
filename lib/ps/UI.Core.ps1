# ============================================================
# UI core: colors, glyphs, terminal helpers, static output
# Compatible with Windows PowerShell 5.1 and PowerShell 7+
# ============================================================

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$script:ESC = [char]27

# VT support -> ANSI colors + cursor movement
$script:UiVT = $false
try { $script:UiVT = [bool]$Host.UI.SupportsVirtualTerminal } catch {}
if (-not $script:UiVT -and $PSVersionTable.PSVersion.Major -ge 7) { $script:UiVT = $true }

$script:UiInteractive = $true
try { $script:UiInteractive = -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected } catch {}

$script:C = @{}
foreach ($pair in @(
        @('Reset', '0'), @('Bold', '1'), @('Dim', '2'), @('Inv', '7'),
        @('Red', '31'), @('Green', '32'), @('Yellow', '33'), @('Blue', '34'),
        @('Magenta', '35'), @('Cyan', '36'), @('Gray', '90'))) {
    if ($script:UiVT -and $script:UiInteractive -and -not $env:NO_COLOR) {
        $script:C[$pair[0]] = "$script:ESC[$($pair[1])m"
    } else {
        $script:C[$pair[0]] = ''
    }
}

# Unicode glyphs need a modern terminal (Windows Terminal, VS Code, non-Windows).
# Legacy conhost fonts miss several of them -> ASCII fallback.
$script:UiUnicode = [bool]($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:MY_CONFIG_UNICODE -or
    ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows))

if ($script:UiUnicode) {
    $script:G = @{
        Top = [string][char]0x250C; Bottom = [string][char]0x2514; Bar = [string][char]0x2502
        Active = [string][char]0x25C6; Done = [string][char]0x25C7
        Info = [string][char]0x25CF; Warn = [string][char]0x25B2; Error = [string][char]0x25A0
        BoxOn = [string][char]0x25FC; BoxOff = [string][char]0x25FB
        RadioOn = [string][char]0x25CF; RadioOff = [string][char]0x25CB
        H = [string][char]0x2500; TopRight = [string][char]0x256E; BottomRight = [string][char]0x256F
        Tee = [string][char]0x251C; Check = [string][char]0x2714; Cross = [string][char]0x2718
        Bullet = [string][char]0x2022; Dot = [string][char]0x00B7; Dash = [string][char]0x2014
        Spin = @([string][char]0x25D2, [string][char]0x25D0, [string][char]0x25D3, [string][char]0x25D1)
    }
} else {
    $script:G = @{
        Top = '+'; Bottom = '+'; Bar = '|'
        Active = '*'; Done = 'o'
        Info = 'i'; Warn = '!'; Error = 'x'
        BoxOn = '[x]'; BoxOff = '[ ]'
        RadioOn = '(*)'; RadioOff = '( )'
        H = '-'; TopRight = '+'; BottomRight = '+'
        Tee = '+'; Check = 'v'; Cross = 'x'
        Bullet = '-'; Dot = '-'; Dash = '-'
        Spin = @('|', '/', '-', '\')
    }
}

$script:UiBar = "$($C.Gray)$($G.Bar)$($C.Reset)"

# ------------------------------------------------------------
# Low-level helpers
# ------------------------------------------------------------

function Write-Ui([string]$Text, [switch]$NoNewline) {
    if ($NoNewline) { [Console]::Write($Text) } else { [Console]::WriteLine($Text) }
}

function Get-UiWidth([string]$Text) {
    return ($Text -replace "$([char]27)\[[0-9;]*m", '').Length
}

function Set-UiCursor([bool]$Visible) {
    if (-not $script:UiInteractive) { return }
    try { [Console]::CursorVisible = $Visible } catch {}
}

function Clear-UiLines([int]$Count) {
    if ($Count -le 0 -or -not $script:UiInteractive) { return }
    if ($script:UiVT) {
        Write-Ui "$script:ESC[$($Count)A$script:ESC[J" -NoNewline
        return
    }
    try {
        $top = [Console]::CursorTop - $Count
        [Console]::SetCursorPosition(0, $top)
        $blank = ' ' * ([Console]::BufferWidth - 1)
        for ($i = 0; $i -lt $Count; $i++) { Write-Ui $blank }
        [Console]::SetCursorPosition(0, $top)
    } catch {}
}

function Read-UiKey {
    $k = [Console]::ReadKey($true)
    switch ($k.Key) {
        'UpArrow'    { return 'up' }
        'DownArrow'  { return 'down' }
        'LeftArrow'  { return 'left' }
        'RightArrow' { return 'right' }
        'Tab'        { return 'tab' }
        'Spacebar'   { return 'space' }
        'Enter'      { return 'enter' }
        'Escape'     { return 'cancel' }
    }
    switch (([string]$k.KeyChar).ToLower()) {
        'k' { return 'up' }
        'j' { return 'down' }
        'h' { return 'left' }
        'l' { return 'right' }
        ' ' { return 'space' }
        'a' { return 'all' }
        'y' { return 'yes' }
        'n' { return 'no' }
        'q' { return 'cancel' }
    }
    return 'other'
}

# ------------------------------------------------------------
# Static output
# ------------------------------------------------------------

function Write-UiBar { Write-Ui $script:UiBar }

function Write-UiIntro([string]$Title) {
    Write-Ui ''
    Write-Ui "$($C.Gray)$($G.Top)$($C.Reset)  $($C.Inv) $Title $($C.Reset)"
    Write-UiBar
}

function Write-UiOutro([string]$Message) {
    Write-Ui "$($C.Gray)$($G.Bottom)$($C.Reset)  $Message"
    Write-Ui ''
}

function Write-UiLine([string]$Text)   { Write-Ui "$script:UiBar  $Text" }
function Write-UiActive([string]$Text) { Write-Ui "$($C.Cyan)$($G.Active)$($C.Reset)  $Text" }
function Write-UiStep([string]$Text)   { Write-Ui "$($C.Green)$($G.Done)$($C.Reset)  $Text"; Write-UiBar }
function Write-UiInfo([string]$Text)   { Write-Ui "$($C.Blue)$($G.Info)$($C.Reset)  $Text"; Write-UiBar }
function Write-UiWarn([string]$Text)   { Write-Ui "$($C.Yellow)$($G.Warn)$($C.Reset)  $Text"; Write-UiBar }
function Write-UiError([string]$Text)  { Write-Ui "$($C.Red)$($G.Error)$($C.Reset)  $Text"; Write-UiBar }

# Print a cancel line and exit the current script
function Stop-UiCancel([string]$Message = 'Đã huỷ.', [int]$Code = 130) {
    Set-UiCursor $true
    Write-Ui "$($C.Gray)$($G.Bottom)$($C.Reset)  $($C.Red)$Message$($C.Reset)"
    Write-Ui ''
    exit $Code
}

# Boxed note
function Write-UiNote([string]$Title, [string[]]$Lines) {
    $width = Get-UiWidth $Title
    foreach ($line in $Lines) {
        $len = Get-UiWidth $line
        if ($len -gt $width) { $width = $len }
    }
    $tlen = Get-UiWidth $Title
    $gray = $C.Gray; $reset = $C.Reset
    $blank = ' ' * ($width + 4)

    Write-Ui "$($C.Green)$($G.Done)$reset  $Title $gray$($G.H * ($width + 1 - $tlen))$($G.TopRight)$reset"
    Write-Ui "$gray$($G.Bar)$reset$blank$gray$($G.Bar)$reset"
    foreach ($line in $Lines) {
        $pad = ' ' * ($width - (Get-UiWidth $line))
        Write-Ui "$gray$($G.Bar)$reset  $line$pad  $gray$($G.Bar)$reset"
    }
    Write-Ui "$gray$($G.Bar)$reset$blank$gray$($G.Bar)$reset"
    Write-Ui "$gray$($G.Tee)$($G.H * ($width + 4))$($G.BottomRight)$reset"
}
