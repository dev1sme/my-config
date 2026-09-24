# ============================================================
# Module registry — discovers <module>\module.conf under Root
# Same manifest format as lib/sh/modules.sh (key=value per line)
# ============================================================

function Read-ModuleConf([string]$Path) {
    $conf = @{}
    foreach ($line in (Get-Content -Path $Path -Encoding UTF8)) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $idx = $line.IndexOf('=')
        $key = $line.Substring(0, $idx).Trim()
        if (-not $conf.ContainsKey($key)) { $conf[$key] = $line.Substring($idx + 1).Trim() }
    }
    return $conf
}

# Modules available on Windows, sorted by order
function Get-MyConfigModules([string]$Root, [string]$OsId = 'windows') {
    $modules = @()
    foreach ($file in (Get-ChildItem -Path $Root -Filter 'module.conf' -Recurse -Depth 1 -File)) {
        $conf = Read-ModuleConf $file.FullName
        if (-not $conf[$OsId]) { continue }

        $id = Split-Path -Leaf $file.DirectoryName
        $missing = ''
        if ($conf['requires'] -and -not (Get-Command $conf['requires'] -ErrorAction SilentlyContinue)) {
            $missing = $conf['requires']
        }
        $order = 999
        if ($conf['order']) { $order = [int]$conf['order'] }

        $modules += [pscustomobject]@{
            Id        = $id
            Label     = $conf['label']
            Hint      = $(if ($missing) { "không tìm thấy lệnh $missing" } else { $conf['hint'] })
            Order     = $order
            Mode      = $(if ($conf['mode']) { $conf['mode'] } else { 'bg' })
            Default   = $(if ($missing) { 'off' } elseif ($conf['default']) { $conf['default'] } else { 'on' })
            NeedAdmin = (",$($conf['sudo'])," -like "*,$OsId,*")
            Script    = Join-Path $file.DirectoryName $conf[$OsId]
            Next      = $conf['next']
        }
    }
    return , @($modules | Sort-Object Order)
}
