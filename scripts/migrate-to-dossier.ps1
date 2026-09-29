# One-time move of AIExport saves to Dossier, the addon's name from 2.0.0.
# For each SavedVariables\AIExport.lua it writes Dossier.lua next to it with AIExportDBChar renamed to DossierDBChar.
# AIExport.lua stays in place, plus an AIExport.lua.dossier-backup copy.
# Usage: powershell -File scripts/migrate-to-dossier.ps1 [-WtfPath <game>\WTF] [-Force]
# -Force replaces a Dossier.lua that already exists. Close the game first: it rewrites saves when it exits.

param(
  [string]$WtfPath = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not $WtfPath) {
  $configPath = Join-Path $PSScriptRoot "addons.local.json"
  if (-not (Test-Path $configPath)) { throw "Pass -WtfPath, or set addonsPath in scripts/addons.local.json." }
  $addonsPath = (Get-Content -Raw -Path $configPath | ConvertFrom-Json).addonsPath
  $WtfPath = Join-Path (Split-Path -Parent (Split-Path -Parent $addonsPath)) "WTF"
}
if (-not (Test-Path $WtfPath)) { throw "WTF folder not found: $WtfPath" }

$running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Wow' })
if ($running.Count) { throw "World of Warcraft is running ($($running[0].ProcessName)). Close it, then run this again." }

# Latin-1 maps every byte to one character, so the rest of the file is written back byte for byte.
$bytes = [System.Text.Encoding]::GetEncoding(28591)
$saves = @(Get-ChildItem -Path $WtfPath -Recurse -Filter "AIExport.lua" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Directory.Name -eq "SavedVariables" })

$migrated = 0
$skipped = 0
foreach ($save in $saves) {
  $who = "$($save.Directory.Parent.Parent.Name)/$($save.Directory.Parent.Name)"
  $target = Join-Path $save.DirectoryName "Dossier.lua"
  if ((Test-Path $target) -and -not $Force) {
    Write-Output "Skipped ${who}: Dossier.lua already exists. Use -Force to replace it."
    $skipped++
    continue
  }

  $text = [System.IO.File]::ReadAllText($save.FullName, $bytes)
  $renamed = [regex]::Replace($text, '(?m)^AIExportDBChar(\s*=)', 'DossierDBChar$1')
  if ($renamed -eq $text) {
    Write-Output "Skipped ${who}: no AIExportDBChar in $($save.FullName)"
    $skipped++
    continue
  }

  $backup = "$($save.FullName).dossier-backup"
  if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $save.FullName -Destination $backup }
  [System.IO.File]::WriteAllText($target, $renamed, $bytes)
  Write-Output "Migrated $who"
  $migrated++
}

Write-Output "Done: $migrated migrated, $skipped skipped, from $WtfPath"
