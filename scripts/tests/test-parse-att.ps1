# Focused checks for scripts/parse-att.ps1 (Phase 2b parser 1).
# Run: powershell -NoProfile -File scripts/tests/test-parse-att.ps1
# Builds a temp WTF layout from the gitignored ATT fixture (fake names only),
# parses into a temp private dir, and asserts the merge, the roster-agnostic
# character flow, the ingest guard (reset file keeps previous good data), and
# the privacy rule: no fixture id may appear in any shipped file (git grep,
# scripts/tests/ excluded).

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$parser = Join-Path $repo "scripts\parse-att.ps1"
$fixture = Join-Path $repo "data\private\fixtures\AllTheThings.fixture.lua"
if (-not (Test-Path $fixture)) { throw "Missing fixture: $fixture" }

$tmp = Join-Path $repo ("data\private\test-tmp-" + [guid]::NewGuid().ToString("N"))
$wtf = Join-Path $tmp "wtf"
$svDir = Join-Path $wtf "Account\TestAcct\SavedVariables"
$privateDir = Join-Path $tmp "private"
$publicPath = Join-Path $tmp "att.public.json"
$rosterPath = Join-Path $tmp "roster.json"
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
  Copy-Item $fixture (Join-Path $svDir "AllTheThings.lua")

  # Seed canonical with one matching beta-style name (first-token match) and
  # one unrelated record; the parser must match roster-agnostically and must
  # never touch the dossier-anchored file beyond reading it.
  $seedChars = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @(
      [ordered]@{ id = "fixturin"; name = "Fixturin Testmend"; displayName = $null; goldCopper = 99999 },
      [ordered]@{ id = "other"; name = "Unrelated Person"; displayName = $null; goldCopper = 1 }
    )
  }
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seedChars | ConvertTo-Json -Depth 20)
  $charsBefore = [System.IO.File]::ReadAllText((Join-Path $privateDir "characters.json"), [System.Text.Encoding]::UTF8)
  # Launch-style roster: only the Fixturin entry matches, proving the public
  # projection is roster-gated.
  Write-Utf8 $rosterPath (@([ordered]@{ id = "fixturin-id"; name = "Fixturin Testmend" }) | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir -PublicPath $publicPath -RosterPath $rosterPath | Out-Host

  $att = Get-Content -Raw (Join-Path $privateDir "att.json") -Encoding UTF8 | ConvertFrom-Json
  Assert (@($att.characters).Count -eq 2) "both SV characters parsed roster-agnostically"
  $f = @($att.characters | Where-Object { $_.name -eq "Fixturin Testmend" })[0]
  Assert ($null -ne $f) "Fixturin record present"
  Assert ($f.canonicalId -eq "fixturin") "first-token canonical match, got $($f.canonicalId)"
  Assert ($f.have.quests.count -eq 2) "quest haves 2, got $($f.have.quests.count)"
  Assert ((@($f.have.quests.have) -contains 111) -and (@($f.have.quests.have) -contains 222)) "quest ids 111 and 222"
  Assert ($f.have.toys.count -eq 2) "list-form Toys parsed (2)"
  Assert ($f.have.mounts.count -eq 0) "empty Mounts stay empty"
  Assert ($f.have.battlepets.count -eq 1) "dict-form BattlePets parsed (1)"
  Assert ($f.customCollects.HOA -eq $true) "custom collect HOA true"
  Assert ($f.lastPlayed -like "2026*") "lastPlayed decoded, got $($f.lastPlayed)"
  $e = @($att.characters | Where-Object { $_.name -eq "Exempla Testmore" })[0]
  Assert ($null -ne $e -and $null -eq $e.canonicalId) "unmatched SV character flows through with null canonicalId"
  Assert ($att.account.quests.count -eq 2) "account quests 2"
  Assert ($att.account.sources.count -eq 2) "account sources 2"
  Assert ($att.sources[0].sizeBytes -gt 0) "ingest sources record file size"
  Assert ($null -ne $att.generatedAt) "ingest timestamp recorded"
  Assert ($null -eq $att.characters[0].PSObject.Properties["lvl"]) "dossier-owned level not duplicated, got lvl field"
  Assert ($null -eq $att.account.PSObject.Properties["deaths"]) "dossier-owned deaths not duplicated"

  $charsAfter = [System.IO.File]::ReadAllText((Join-Path $privateDir "characters.json"), [System.Text.Encoding]::UTF8)
  Assert ($charsAfter -eq $charsBefore) "dossier-anchored characters.json untouched"

  $public = Get-Content -Raw $publicPath -Encoding UTF8 | ConvertFrom-Json
  Assert ($public.account.questsHaveCount -eq 2) "public account quest count 2"
  Assert (@($public.characters).Count -eq 1) "public characters roster-gated to 1"
  Assert (@($public.characters)[0].canonicalId -eq "fixturin-id") "public character uses roster id"

  # Ingest guard: a reset (empty) SV must WARN and keep the previous good file.
  $kept = Get-Content -Raw (Join-Path $privateDir "att.json") -Encoding UTF8
  Write-Utf8 (Join-Path $svDir "AllTheThings.lua") "ATTCharacterData = {`n}`nATTAccountWideData = {`n}`n"
  $second = & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir -PublicPath $publicPath -RosterPath $rosterPath 2>&1 | Out-String
  Write-Output $second
  Assert ($second -match "KEPT previous") "reset source keeps previous good canonical"
  $still = Get-Content -Raw (Join-Path $privateDir "att.json") -Encoding UTF8
  Assert ($still -eq $kept) "previous att.json byte-identical after reset"

  # Fixture-leak: git grep only sees tracked files, so the gitignored fixture
  # dir and temp output can never match. scripts/tests/ is excluded; every
  # shipped path is still scanned.
  $leaks = @(git -C $repo grep --name-only "Fixturin" -- . ":!scripts/tests/" 2>$null)
  Assert ($leaks.Count -eq 0) ("no fixture id in committed files" + $(if ($leaks.Count) { ": $($leaks -join ', ')" } else { "" }))

  Write-Output "PASS test-parse-att"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
