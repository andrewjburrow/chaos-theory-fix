#Requires -Version 5.1
<#
Installs ThirteenAG's official Chaos Theory release locally to this game only.
Close the game first. No admin rights required unless the game folder requires them.
Run again with -Undo to restore originals. No registry, driver or global settings changes.
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [switch]$Borderless,
    [switch]$Undo,
    [switch]$CloseGame
)
$ErrorActionPreference = 'Stop'
function NormalizeGamePath([string]$candidate) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { return $null }
    $candidate = [Environment]::ExpandEnvironmentVariables($candidate.Trim().Trim('"'))
    if (-not (Test-Path -LiteralPath $candidate)) { return $null }
    $item = Get-Item -LiteralPath $candidate
    if (-not $item.PSIsContainer) {
        if ($item.Name -ine 'SplinterCell3.exe') { return $null }
        $candidate = $item.Directory.FullName
    }
    if ((Split-Path -Leaf $candidate.TrimEnd('\')) -ieq 'System') { $candidate = Split-Path -Parent $candidate.TrimEnd('\') }
    if (Test-Path -LiteralPath (Join-Path $candidate 'System\SplinterCell3.exe') -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path.TrimEnd('\')
    }
    return $null
}
function FindSteamGame {
    $steamRoots = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        $reg = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        foreach ($name in @('SteamPath','InstallPath')) {
            if ($reg -and $reg.PSObject.Properties[$name]) { $steamRoots += $reg.$name }
        }
    }
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ($base) { $steamRoots += Join-Path $base 'Steam' }
    }
    $libraries = @($steamRoots)
    foreach ($steam in @($steamRoots | Select-Object -Unique)) {
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            $content = Get-Content -LiteralPath $vdf -Raw
            foreach ($match in [regex]::Matches($content, '"path"\s+"([^"]+)"')) {
                $libraries += $match.Groups[1].Value.Replace('\\','\')
            }
            # Older libraryfolders.vdf format.
            foreach ($match in [regex]::Matches($content, '"\d+"\s+"([A-Za-z]:[^"\r\n]+)"')) {
                $libraries += $match.Groups[1].Value.Replace('\\','\')
            }
        }
    }
    $found = @()
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $apps = Join-Path $library 'steamapps'
        $acf = Join-Path $apps 'appmanifest_13570.acf'
        if (Test-Path -LiteralPath $acf) {
            $content = Get-Content -LiteralPath $acf -Raw
            $match = [regex]::Match($content, '"installdir"\s+"([^"]+)"')
            if ($match.Success) {
                $folder = $match.Groups[1].Value
                if ($folder -match '[\\/:]' -or $folder -eq '..') { throw 'Unexpected Steam manifest directory.' }
                $resolved = NormalizeGamePath (Join-Path (Join-Path $apps 'common') $folder)
                if ($resolved) { $found += $resolved }
            }
        }
        $resolved = NormalizeGamePath (Join-Path $apps 'common\Splintercell Chaos Theory')
        if ($resolved) { $found += $resolved }
    }
    return @($found | Select-Object -Unique)
}
if ($GamePath) {
    $root = NormalizeGamePath $GamePath
    if (-not $root) { throw 'Could not find System\SplinterCell3.exe at the supplied path.' }
} else {
    $found = @(FindSteamGame)
    if ($found.Count -eq 1) {
        $root = $found[0]
        Write-Host "Detected: $root"
    } else {
        if ($found.Count -gt 1) {
            Write-Host 'Multiple installations found:'
            $found | ForEach-Object { Write-Host "  $_" }
        }
        $root = NormalizeGamePath (Read-Host 'Paste game folder, System folder, or SplinterCell3.exe path')
        if (-not $root) { throw 'No valid game selected. No files changed.' }
    }
}
$system = Join-Path $root 'System'
$exe = Join-Path $system 'SplinterCell3.exe'
$running = @(Get-Process -Name SplinterCell3 -ErrorAction SilentlyContinue)
foreach ($process in $running) {
    try { $processPath = $process.Path } catch { throw 'Cannot inspect running game. Close it manually and retry.' }
    if (-not $processPath) { throw 'Cannot inspect running game. Close it manually and retry.' }
    if ($processPath -ine $exe) { continue }
    if (-not $CloseGame) {
        $answer = Read-Host 'Chaos Theory is running. Unsaved progress may be lost. Close it? [y/N]'
        if ($answer -notmatch '^(?i:y|yes)$') { throw 'Close the game and retry. No files changed.' }
    }
    if ($process.CloseMainWindow()) { [void]$process.WaitForExit(5000) }
    $process.Refresh()
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    if (-not $process.WaitForExit(10000)) { throw 'Game did not exit. No files changed.' }
}
$backup = Join-Path $root 'ChaosTheory-Fix-Backup'
$manifest = Join-Path $backup 'manifest.json'
function SafePath([string]$base, [string]$relative) {
    $full = [IO.Path]::GetFullPath((Join-Path $base $relative))
    $prefix = $base.TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe path rejected.' }
    # Refuse junctions/symlinks that could redirect writes outside the selected directory.
    $cursor = $full
    while ($cursor -and $cursor.Length -ge $base.Length) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Junction/symlink rejected: $cursor"
            }
        }
        $cursor = Split-Path -Parent $cursor
    }
    return $full
}
function RestoreFiles($entries) {
    foreach ($entry in $entries) {
        $dest = SafePath $root $entry.Path
        if ($entry.Existed) {
            Copy-Item -LiteralPath (SafePath (Join-Path $backup 'originals') $entry.Path) -Destination $dest -Force
        } elseif (Test-Path -LiteralPath $dest -PathType Leaf) {
            Remove-Item -LiteralPath $dest -Force
        }
    }
}
if ($Undo) {
    if (-not (Test-Path -LiteralPath $manifest)) { throw 'No backup manifest found.' }
    $data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    # Check everything before undo; avoid silently overwriting subsequent mod changes.
    foreach ($entry in $data.Files) {
        $dest = SafePath $root $entry.Path
        if ((Test-Path -LiteralPath $dest) -and
            ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $entry.InstalledHash)) {
            throw "Changed since installation: $($entry.Path). Undo stopped; original files remain in $backup."
        }
        if ($entry.Existed) {
            $original = SafePath (Join-Path $backup 'originals') $entry.Path
            if ((Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash -ne $entry.OriginalHash) {
                throw "Backup validation failed: $($entry.Path)"
            }
        }
    }
    RestoreFiles $data.Files
    Move-Item -LiteralPath $manifest -Destination (Join-Path $backup ('restored-' + [Guid]::NewGuid().ToString() + '.json'))
    Write-Host "Original files restored. Backup retained at $backup" -ForegroundColor Green
    return
}
if (Test-Path -LiteralPath $backup) { throw "Backup folder already exists. Undo first; preserve/move that backup before installing again: $backup" }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ChaosTheory-' + [Guid]::NewGuid().ToString())
$entries = @()
$started = $false
$committed = $false
$oldTls = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = $oldTls -bor [Net.SecurityProtocolType]::Tls12
    New-Item -ItemType Directory -Path $temp | Out-Null
    Write-Host 'Downloading official ThirteenAG Chaos Theory release...'
    $headers = @{ 'User-Agent' = 'ChaosTheory-Local-Fix'; 'Accept' = 'application/vnd.github+json' }
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ThirteenAG/WidescreenFixesPack/releases/tags/scct' -Headers $headers
    $assets = @($release.assets | Where-Object { $_.name -eq 'SplinterCellChaosTheory.WidescreenFix.zip' })
    if ($assets.Count -ne 1) { throw 'Expected official ZIP asset not found; no game files changed.' }
    $asset = $assets[0]
    if ($asset.browser_download_url -notlike 'https://github.com/ThirteenAG/WidescreenFixesPack/releases/download/*') { throw 'Unexpected download URL.' }
    $zip = Join-Path $temp 'fix.zip'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($asset.PSObject.Properties.Name -contains 'digest') {
        if ($asset.digest -like 'sha256:*' -and $zipHash -ne $asset.digest.Substring(7)) { throw 'Download checksum mismatch.' }
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($item in $archive.Entries) {
            $name = $item.FullName.Replace('/', '\')
            if ($name -match '(^|\\)\.\.(\\|$)' -or $name.Contains(':') -or $name.StartsWith('\')) { throw 'Unsafe ZIP path.' }
        }
    } finally { $archive.Dispose() }
    $stage = Join-Path $temp 'stage'
    Expand-Archive -LiteralPath $zip -DestinationPath $stage
    $iniRelative = 'System\scripts\SplinterCellChaosTheory.WidescreenFix.ini'
    $ini = Join-Path $stage $iniRelative
    if (-not (Test-Path -LiteralPath $ini)) { throw 'Unexpected archive layout; no game files changed.' }
    $settings = [ordered]@{ FPSLimit='60'; RawInputMouse='1.0'; RawInputMouseRawData='1'; SkipIntro='1' }
    if ($Borderless) { $settings['ForceWindowedMode']='1'; $settings['ForceWindowStyle']='1' }
    $text = [IO.File]::ReadAllText($ini)
    foreach ($key in $settings.Keys) {
        $pattern = '(?m)^(\s*' + [regex]::Escape($key) + '\s*=\s*)[^\r\n]*'
        if (-not [regex]::IsMatch($text, $pattern)) { throw "Expected setting missing: $key" }
        $text = [regex]::Replace($text, $pattern, ('${1}' + $settings[$key]))
    }
    [IO.File]::WriteAllText($ini, $text, [Text.UTF8Encoding]::new($false))
    # Preserve supplied resolution and shadow defaults for the widest compatibility.
    $files = @(Get-ChildItem -LiteralPath (Join-Path $stage 'System') -File -Recurse)
    if ($files.Count -eq 0) { throw 'Empty patch.' }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($stage.Length + 1)
        $dest = SafePath $root $relative
        $existed = Test-Path -LiteralPath $dest -PathType Leaf
        if ((Test-Path -LiteralPath $dest) -and -not $existed) { throw "Destination is not a file: $dest" }
        $entries += [pscustomobject]@{
            Path=$relative; Existed=$existed
            OriginalHash=$(if ($existed) { (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash } else { $null })
            InstalledHash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    New-Item -ItemType Directory -Path $backup | Out-Null
    foreach ($entry in $entries) {
        if ($entry.Existed) {
            $saved = SafePath (Join-Path $backup 'originals') $entry.Path
            New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
            Copy-Item -LiteralPath (SafePath $root $entry.Path) -Destination $saved
        }
    }
    [pscustomobject]@{ Source=$asset.browser_download_url; ZipSHA256=$zipHash; Files=$entries } |
        ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifest -Encoding UTF8
    $started = $true
    foreach ($entry in $entries) {
        $dest = SafePath $root $entry.Path
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $stage $entry.Path) -Destination $dest -Force
        if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $entry.InstalledHash) { throw "Copy validation failed: $dest" }
    }
    $committed = $true
    Write-Host 'Installed: widescreen fix, supplied audio/controller components, raw mouse input, 60 FPS cap.' -ForegroundColor Green
    Write-Host "Backup: $backup"
    Write-Host 'Launch and test night vision, thermal vision, optic cable and sticky cameras.'
    Write-Host 'No Windows, registry, AMD driver, firewall or other-game settings changed.'
} catch {
    $failure = $_
    if ($started -and -not $committed) {
        try {
            RestoreFiles $entries
            if (Test-Path -LiteralPath $manifest) {
                Move-Item -LiteralPath $manifest -Destination (Join-Path $backup 'rolled-back.json')
            }
            Write-Warning 'Installation failed; original files restored. Backup retained.'
        } catch { Write-Warning "Automatic restore failed. Preserve backup: $backup. Details: $_" }
    }
    throw $failure
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $oldTls
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
