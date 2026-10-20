# Focused checks for scripts/parse-questie.ps1 (Phase 2b parser 4).
# Run: powershell -NoProfile -File scripts/tests/test-parse-questie.ps1
# Builds a temp WTF layout from the gitignored Questie fixture (fake names
# only), parses into a temp private dir, and asserts journey events (accept /
# complete / level), stale-key canonical merging, the complete-id set, the
# ingest guard (reset file keeps previous good data), that no public file is
# written, and the privacy rule: no fixture id may appear in any shipped file
# (git grep, scripts/tests/ excluded).

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$parser = Join-Path $repo "scripts\parse-questie.ps1"
$fixture = Join-Path $repo "data\private\fixtures\Questie.fixture.lua"
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
  Copy-Item $fixture (Join-Path $svDir "Questie.lua")
  $seedChars = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @([ordered]@{ id = "fixturin"; name = "Fixturin Testmend"; displayName = $null })
  }
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seedChars | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir | Out-Host

  $qh = Get-Content -Raw (Join-Path $privateDir "quest-history.json") -Encoding UTF8 | ConvertFrom-Json
  Assert (@($qh.characters).Count -eq 2) "both SV character keys parsed roster-agnostically"
  Assert ($qh.count -eq 3) "3 journey events total, got $($qh.count)"
  $stale = @($qh.characters | Where-Object { $_.svKey -eq "Fixturin - PvE" })[0]
  Assert ($null -ne $stale) "stale short-name key present"
  Assert ($stale.canonicalId -eq "fixturin") "stale key merges to canonical fixturin"
  Assert ($stale.counts.accepts -eq 1 -and $stale.counts.completes -eq 1 -and $stale.counts.levelUps -eq 1) "accept/complete/level counted"
  $acc = @($stale.journey | Where-Object { $_.subType -eq "Accept" })[0]
  Assert ($acc.quest -eq 111 -and $acc.level -eq 9) "accept carries quest 111 level 9"
  Assert ($acc.timestampIso -like "2026*") "epoch decoded to ISO, got $($acc.timestampIso)"
  $lvl = @($stale.journey | Where-Object { $_.event -eq "Level" })[0]
  Assert ($lvl.newLevel -eq 10) "level event carries newLevel 10"
  Assert ((@($stale.completeIds) -contains 111)) "complete ids parsed"
  $cur = @($qh.characters | Where-Object { $_.svKey -eq "Fixturin Testmend" })[0]
  Assert ($null -ne $cur -and $cur.canonicalId -eq "fixturin") "current-name key merges to same canonical id"
  Assert ($cur.counts.events -eq 0 -and $cur.counts.completeIds -eq 2) "journey-less key keeps complete ids honestly empty"
  Assert ($cur.guid -eq "Player-9999-AAAAAAAA") "guid recorded"
  Assert (-not (Test-Path (Join-Path $tmp "quest-history.public.json"))) "no public projection written"

  # Ingest guard: a reset (empty) SV must WARN and keep the previous good data.
  # Keys present with zero journey events is NOT a reset (covered above).
  $kept = Get-Content -Raw (Join-Path $privateDir "quest-history.json") -Encoding UTF8
  Write-Utf8 (Join-Path $svDir "Questie.lua") "QuestieConfig = {`n}`n"
  $second = & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir 2>&1 | Out-String
  Write-Output $second
  Assert ($second -match "KEPT previous") "reset source keeps previous good canonical"
  $still = Get-Content -Raw (Join-Path $privateDir "quest-history.json") -Encoding UTF8
  Assert ($still -eq $kept) "previous quest-history.json byte-identical after reset"

  $leaks = @(git -C $repo grep --name-only "Fixturin" -- . ":!scripts/tests/" 2>$null)
  Assert ($leaks.Count -eq 0) ("no fixture id in committed files" + $(if ($leaks.Count) { ": $($leaks -join ', ')" } else { "" }))

  Write-Output "PASS test-parse-questie"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
