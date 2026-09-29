# Build the AIExport CurseForge zip and install it into the local WoW Forever client.
# Usage: powershell -File scripts/package-addon.ps1 [-SkipInstall]
# Source: addon/AIExport. Zip: dist/AIExport-<version>.zip with AIExport/ as its only top folder.
# Install path: Interface\AddOns\AIExport under addonsPath in scripts/addons.local.json.

param(
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo = Split-Path -Parent $PSScriptRoot
$addonName = "AIExport"
$source = Join-Path $repo "addon\$addonName"
$dist = Join-Path $repo "dist"
$toc = Join-Path $source "$addonName.toc"
$camelotToc = Join-Path $source "${addonName}_Camelot.toc"

function Read-Normalized($path) {
  return ([System.IO.File]::ReadAllText($path)) -replace "`r`n", "`n"
}

if (-not (Test-Path $toc)) { throw "Missing $toc" }
if (-not (Test-Path $camelotToc)) { throw "Missing $camelotToc" }
if ((Read-Normalized $toc) -ne (Read-Normalized $camelotToc)) {
  throw "$addonName.toc and ${addonName}_Camelot.toc differ. Make them identical before packaging."
}

$version = $null
$listed = @()
foreach ($line in Get-Content -Path $toc) {
  if ($line -match '^\s*##\s*Version:\s*(.+)$') { $version = $Matches[1].Trim() }
  elseif ($line -match '^\s*[^#\s].*\.(lua|xml)\s*$') { $listed += $line.Trim() }
}
if (-not $version) { throw "No ## Version line in $toc" }

$constants = Read-Normalized (Join-Path $source "Constants.lua")
if ($constants -notmatch "C\.VERSION = `"$([regex]::Escape($version))`"") {
  throw "Constants.lua C.VERSION does not match the toc version $version."
}

$missing = @($listed | Where-Object { -not (Test-Path (Join-Path $source $_)) })
if ($missing.Count) { throw "Files listed in the toc are missing: $($missing -join ', ')" }

$onDisk = @(Get-ChildItem -Path $source -Recurse -File -Include *.lua |
  ForEach-Object { $_.FullName.Substring($source.Length + 1).Replace('\', '/') })
$unlisted = @($onDisk | Where-Object { $listed -notcontains $_ })
if ($unlisted.Count) { throw "Lua files not listed in the toc: $($unlisted -join ', ')" }

New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zipPath = Join-Path $dist "$addonName-$version.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($file in Get-ChildItem -Path $source -Recurse -File) {
    $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
    $entry = "$addonName/$relative"
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
} finally {
  $zip.Dispose()
}
$fileCount = @(Get-ChildItem -Path $source -Recurse -File).Count
Write-Output "Wrote dist/$addonName-$version.zip ($fileCount files)"

if ($SkipInstall) { return }

$configPath = Join-Path $PSScriptRoot "addons.local.json"
if (-not (Test-Path $configPath)) {
  Write-Output "Skipped install: $configPath is missing. Copy scripts/addons.example.json and set addonsPath."
  return
}
$addonsPath = (Get-Content -Raw -Path $configPath | ConvertFrom-Json).addonsPath
if (-not $addonsPath -or -not (Test-Path $addonsPath)) {
  Write-Output "Skipped install: addonsPath is missing or not a folder: $addonsPath"
  return
}

$target = Join-Path $addonsPath $addonName
$isNew = -not (Test-Path $target)
if (-not $isNew) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse -Path $source -Destination $target
Write-Output "Installed $addonName $version to $target"

$oldFolder = Join-Path $addonsPath "CharacterExport-Forever"
if (Test-Path (Join-Path $target "$addonName.toc")) {
  if (Test-Path $oldFolder) {
    $backup = Join-Path $dist "CharacterExport-Forever-backup"
    if (Test-Path $backup) { Remove-Item -Recurse -Force $backup }
    Move-Item -Path $oldFolder -Destination $backup
    Write-Output "Moved the old CharacterExport-Forever folder out of AddOns to dist/CharacterExport-Forever-backup"
  }
}

if ($isNew) {
  Write-Output "Restart the game so it finds the new AIExport folder. After that, /reload picks up changes."
} else {
  Write-Output "Type /reload in game to load the new build. If files were added to the toc, restart the game instead."
}
