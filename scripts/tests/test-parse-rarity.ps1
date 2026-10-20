# Focused checks for scripts/parse-rarity.ps1 (Phase 2b parser 3).
# Run: powershell -NoProfile -File scripts/tests/test-parse-rarity.ps1
# Builds a temp WTF layout from the gitignored Rarity fixture (fake names
# only), parses into a temp private dir, and asserts the attempts layer (one
# item with attempts, one honest-empty item), the ingest guard (reset file
# keeps previous good data), that no public file is written, and the privacy
# rule: no fixture id may appear in any shipped file (git grep,
# scripts/tests/ excluded).

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$parser = Join-Path $repo "scripts\parse-rarity.ps1"
$fixture = Join-Path $repo "data\private\fixtures\Rarity.fixture.lua"
if (-not (Test-Path $fixture)) { throw "Missing fixture: $fixture" }

$tmp = Join-Path $repo ("data\private\test-tmp-" + [guid]::NewGuid().ToString("N"))
$wtf = Join-Path $tmp "wtf"
$svDir = Join-Path $wtf "Account\TestAcct\SavedVariables"
$privateDir = Join-Path $tmp "private"
New-Item -ItemType Directory -Force -Path $svDir | Out-Null
New-Item -ItemType Directory -Force -Path $privateDir | Out-Null

function Assert($condition, $message) {
  if (-not $condition) { throw "ASSERT FAILED: $message" }
  Write-Output "ok - $message"
}

function Write-Utf8($path, $value) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $value, $utf8)
}

try {
  Copy-Item $fixture (Join-Path $svDir "Rarity.lua")
  $seedChars = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @([ordered]@{ id = "fixturin"; name = "Fixturin Testmend"; displayName = $null })
  }
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seedChars | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir | Out-Host

  $rar = Get-Content -Raw (Join-Path $privateDir "rarity.json") -Encoding UTF8 | ConvertFrom-Json
  Assert (@($rar.items).Count -eq 2) "2 tracked items, got $(@($rar.items).Count)"
  $drop = @($rar.items | Where-Object { $_.name -eq "Fixture Dropper" })[0]
  Assert ($null -ne $drop) "attempted item present"
  Assert ($drop.attempts -eq 5) "attempts 5, got $($drop.attempts)"
  Assert ($drop.realAttempts -eq 7) "realAttempts 7"
  Assert ($drop.time -eq 3600) "time 3600"
  Assert ($drop.finds -eq 1) "finds 1"
  Assert ($drop.found -eq $false) "have/want NOT decided here (found recorded raw, no roll-up)"
  $quiet = @($rar.items | Where-Object { $_.name -eq "Fixture Testling" })[0]
  Assert ($null -ne $quiet -and $null -eq $quiet.attempts) "honest empty item keeps null attempts"
  Assert ($rar.summary.itemsTracked -eq 2) "summary tracks 2 items"
  Assert ($rar.summary.itemsWithAttempts -eq 1) "summary 1 item with attempts"
  Assert ($rar.summary.totalAttempts -eq 5) "summary total attempts 5"
  Assert ($rar.summary.source -eq "rarity") "summary source-tagged"
  Assert ($rar.tracked.Default.group -eq "pets") "tracked group pets"
  $stat = @($rar.statistics | Where-Object { $_.guid -eq "Player-9999-AAAAAAAA" })[0]
  Assert ($null -ne $stat -and $stat.canonicalId -eq "fixturin") "statistics matched to canonical fixturin"
  Assert ((@($stat.statistics | Where-Object { $_.id -eq 1097 })[0]).value -eq 3) "statistic 1097 value 3"
  Assert (-not (Test-Path (Join-Path $tmp "rarity.public.json"))) "no public projection written"

  # Ingest guard: a reset (empty) SV must WARN and keep the previous good data.
  # Zero attempts with items present is NOT a reset (covered above).
  $kept = Get-Content -Raw (Join-Path $privateDir "rarity.json") -Encoding UTF8
  Write-Utf8 (Join-Path $svDir "Rarity.lua") "RarityDB = {`n}`n"
  $second = & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir 2>&1 | Out-String
  Write-Output $second
  Assert ($second -match "KEPT previous") "reset source keeps previous good canonical"
  $still = Get-Content -Raw (Join-Path $privateDir "rarity.json") -Encoding UTF8
  Assert ($still -eq $kept) "previous rarity.json byte-identical after reset"

  $leaks = @(git -C $repo grep --name-only "Fixturin" -- . ":!scripts/tests/" 2>$null)
  Assert ($leaks.Count -eq 0) ("no fixture id in committed files" + $(if ($leaks.Count) { ": $($leaks -join ', ')" } else { "" }))

  Write-Output "PASS test-parse-rarity"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
