# ============================================================
# my-config installer (Windows) - bootstrap
#
#   irm https://raw.githubusercontent.com/dev1sme/my-config/main/install.ps1 | iex
#
#   # with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/dev1sme/my-config/main/install.ps1))) -Only ssh,vscode -Yes
#
#   # from a local clone:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Env overrides: MY_CONFIG_REPO, MY_CONFIG_REF, MY_CONFIG_DIR
#
# NOTE: keep this file pure ASCII. It is run both through `irm | iex`
# and from disk by Windows PowerShell 5.1, which misreads UTF-8 without BOM.
# The real flow (Vietnamese UI) lives in lib\ps\Main.ps1.
# ============================================================

param(
    [string[]]$Only = @(),
    [switch]$All,
    [switch]$Yes,
    [switch]$List
)

function Invoke-MyConfigBootstrap {
    param([string[]]$Only, [switch]$All, [switch]$Yes, [switch]$List, [string]$ScriptPath)

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $repo = if ($env:MY_CONFIG_REPO) { $env:MY_CONFIG_REPO } else { 'dev1sme/my-config' }
    $ref = if ($env:MY_CONFIG_REF) { $env:MY_CONFIG_REF } else { 'main' }
    $dir = if ($env:MY_CONFIG_DIR) { $env:MY_CONFIG_DIR } else { Join-Path $HOME '.my-config' }

    # Local clone: use it directly
    $root = $null
    if ($ScriptPath) {
        $candidate = Split-Path -Parent $ScriptPath
        if (Test-Path (Join-Path $candidate 'lib/ps/Main.ps1')) { $root = $candidate }
    }

    if (-not $root) {
        Write-Host ''
        Write-Host '+  my-config bootstrap' -ForegroundColor DarkGray
        Write-Host '|' -ForegroundColor DarkGray

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        } catch {}

        if (Get-Command git -ErrorAction SilentlyContinue) {
            if (Test-Path (Join-Path $dir '.git')) {
                & git -C $dir pull --ff-only -q 2>$null
                if ($LASTEXITCODE -ne 0) { Write-Host "!  Khong pull duoc, dung ban hien co trong $dir" -ForegroundColor Yellow }
            } elseif (Test-Path $dir) {
                throw "$dir da ton tai nhung khong phai git repo. Dat MY_CONFIG_DIR khac."
            } else {
                & git clone -q --depth 1 -b $ref "https://github.com/$repo.git" $dir
                if ($LASTEXITCODE -ne 0) { throw 'git clone that bai.' }
            }
        } else {
            if ((Test-Path $dir) -and -not (Test-Path (Join-Path $dir 'lib/ps/Main.ps1'))) {
                throw "$dir da ton tai va khong phai my-config. Dat MY_CONFIG_DIR khac."
            }
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("my-config-" + [guid]::NewGuid().ToString('N'))
            $zip = "$tmp.zip"
            try {
                Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$repo/archive/refs/heads/$ref.zip" -OutFile $zip
                Expand-Archive -Path $zip -DestinationPath $tmp -Force
                $inner = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
                if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
                Move-Item -Path $inner.FullName -Destination $dir
                Get-ChildItem -Path $dir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
            } finally {
                Remove-Item -Path $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host "o  Da tai my-config ve $dir" -ForegroundColor Green
        Write-Host '+' -ForegroundColor DarkGray
        $root = $dir
    }

    # Quote each argument: Start-Process joins them with spaces as-is
    $fwd = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $root 'lib/ps/Main.ps1') + '"'),
        '-Repo', $repo, '-Ref', $ref)
    if ($Only.Count -gt 0) { $fwd += @('-Only', ($Only -join ',')) }
    if ($All) { $fwd += '-All' }
    if ($Yes) { $fwd += '-Yes' }
    if ($List) { $fwd += '-List' }

    # Start-Process -NoNewWindow keeps the child attached to this console
    # (a plain `& pwsh` here would have its output captured by the caller)
    $psExe = (Get-Process -Id $PID).Path
    $p = Start-Process -FilePath $psExe -ArgumentList ($fwd -join ' ') -NoNewWindow -Wait -PassThru
    return $p.ExitCode
}

try {
    $code = Invoke-MyConfigBootstrap -Only $Only -All:$All -Yes:$Yes -List:$List -ScriptPath $PSCommandPath
} catch {
    Write-Host "x  $($_.Exception.Message)" -ForegroundColor Red
    $code = 1
}

# Only exit when run as a file: `exit` inside `irm | iex` would close the user's shell
if ($PSCommandPath) { exit $code }
