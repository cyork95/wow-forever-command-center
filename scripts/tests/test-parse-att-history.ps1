# Focused checks for scripts/parse-att-history.ps1 (Phase 2b parser 2).
# Run: powershell -NoProfile -File scripts/tests/test-parse-att-history.ps1
# Builds a temp WTF layout from the gitignored history fixture (fake names
# only), parses into a temp private dir, and asserts cleaned names, item ids,
# the public merge (other att.public.json keys preserved), the ingest guard
# (reset file keeps previous good data), and the privacy rule: no fixture id
# may appear in any shipped file (git grep, scripts/tests/ excluded).

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$parser = Join-Path $repo "scripts\parse-att-history.ps1"
$fixture = Join-Path $repo "data\private\fixtures\ATTCollectionHistory.fixture.lua"
if (-not (Test-Path $fixture)) { throw "Missing fixture: $fixture" }

$tmp = Join-Path $repo ("data\private\test-tmp-" + [guid]::NewGuid().ToString("N"))
$wtf = Join-Path $tmp "wtf"
$svDir = Join-Path $wtf "Account\TestAcct\SavedVariables"
$privateDir = Join-Path $tmp "private"
$publicPath = Join-Path $tmp "att.public.json"
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
  Copy-Item $fixture (Join-Path $svDir "ATTCollectionHistory.lua")
  # Seed a public file with parser-1 keys; the history parser must preserve them.
  Write-Utf8 $publicPath ([ordered]@{
      schemaVersion = 1
      account = [ordered]@{ questsHaveCount = 2 }
      characters = @()
    } | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir -PublicPath $publicPath | Out-Host

  $hist = Get-Content -Raw (Join-Path $privateDir "collection-history.json") -Encoding UTF8 | ConvertFrom-Json
  Assert ($hist.count -eq 3) "3 history entries, got $($hist.count)"
  $q = @($hist.entries | Where-Object { $_.name -eq "Return to Fixturin" })[0]
  Assert ($null -ne $q -and $q.type -eq "Quest") "colour-wrapped quest name cleaned"
  Assert ($q.collectedAt -eq "2026-10-01 18:25:57") "timestamp first-class, got $($q.collectedAt)"
  Assert ($null -ne $q.raw -and $q.raw -match "\|cff") "raw text retained privately"
  $item = @($hist.entries | Where-Object { $_.itemId -eq 424242 })[0]
  Assert ($null -ne $item -and $item.name -eq "Fixture Test Helm") "item id 424242 with hyperlink name"
  Assert ($item.type -eq "ItemWithAppearance") "item type preserved"
  $plain = @($hist.entries | Where-Object { $_.name -eq "Finding Fixture Warmth" })[0]
  Assert ($null -ne $plain) "plain quest text passes through"
  Assert ($hist.types.Quest -eq 2) "type histogram Quest 2"
  Assert ($hist.sources[0].sizeBytes -gt 0) "ingest sources record file size"

  $public = Get-Content -Raw $publicPath -Encoding UTF8 | ConvertFrom-Json
  Assert ($public.obtainedCount -eq 3) "public obtainedCount 3"
  Assert (@($public.obtainedTimeline).Count -eq 3) "public timeline 3 entries"
  Assert ($public.account.questsHaveCount -eq 2) "parser-1 public keys preserved"
  $pubItem = @($public.obtainedTimeline | Where-Object { $_.itemId -eq 424242 })[0]
  Assert ($null -ne $pubItem -and $pubItem.name -eq "Fixture Test Helm") "public timeline carries name + item id"
  Assert ($null -eq $pubItem.PSObject.Properties["raw"]) "raw colour text not projected public"

  # Ingest guard: a reset (empty) history must WARN and keep previous good data.
  $kept = Get-Content -Raw (Join-Path $privateDir "collection-history.json") -Encoding UTF8
  Write-Utf8 (Join-Path $svDir "ATTCollectionHistory.lua") "ATTCollectionHistoryDB = {`n[`"history`"] = {`n},`n}`n"
  $second = & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir -PublicPath $publicPath 2>&1 | Out-String
  Write-Output $second
  Assert ($second -match "KEPT previous") "reset source keeps previous good canonical"
  $still = Get-Content -Raw (Join-Path $privateDir "collection-history.json") -Encoding UTF8
  Assert ($still -eq $kept) "previous collection-history.json byte-identical after reset"

  $leaks = @(git -C $repo grep --name-only "Fixturin" -- . ":!scripts/tests/" 2>$null)
  Assert ($leaks.Count -eq 0) ("no fixture id in committed files" + $(if ($leaks.Count) { ": $($leaks -join ', ')" } else { "" }))

  Write-Output "PASS test-parse-att-history"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
