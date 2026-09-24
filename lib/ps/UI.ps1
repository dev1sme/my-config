# ============================================================
# Clack-style terminal UI (Windows PowerShell 5.1 / PowerShell 7+)
#
# Usage: . "$Root\lib\ps\UI.ps1"
#
#   Write-UiIntro "title"                   ┌  title
#   Write-UiStep "message"                  ◇  message
#   Write-UiInfo / Write-UiWarn / Write-UiError
#   Write-UiLine "text"                     │  text
#   Write-UiNote "title" @("line", ...)     boxed note
#   Read-UiMultiSelect "q" @("label|hint|on") -> selected indices
#   Read-UiSelect "q" @("label|hint")         -> index
#   Read-UiConfirm "q" [-DefaultNo]           -> $true / $false
#   Read-UiText "q" [default]                 -> string
#   Invoke-UiSpin "msg" log exe args          -> @{ ExitCode; Elapsed }
#   Write-UiOutro "message"                 └  message
# ============================================================

. (Join-Path $PSScriptRoot 'UI.Core.ps1')
. (Join-Path $PSScriptRoot 'UI.Prompt.ps1')
. (Join-Path $PSScriptRoot 'UI.Spinner.ps1')
