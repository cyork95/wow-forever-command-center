# Journal pack checks for scripts/butler-pack.ps1 (board: backstories-journal).
# Run: powershell -NoProfile -File scripts/tests/test-journal-pack.ps1
# Seeds a temp private dir with two fixture characters and a temp journals
# file: one roster-matched character with two entries (latest wins), one with
# none (honest empty line). Uses obviously-fake fixture text only.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$generator = Join-Path $repo "scripts\butler-pack.ps1"

$tmp = Join-Path $repo ("data\private\test-tmp-" + [guid]::NewGuid().ToString("N"))
$privateDir = Join-Path $tmp "private"
$outDir = Join-Path $tmp "butler"
New-Item -ItemType Directory -Force -Path $privateDir | Out-Null

function Assert($condition, $message) {
  if (-not $condition) { throw "ASSERT FAILED: $message" }
  Write-Output "ok - $message"
}

function Write-Utf8($path, $text) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $text, $utf8)
}

function Seed-Character($id, $rosterId, $name) {
  return [ordered]@{
    id = $id; rosterId = $rosterId; name = $name
    race = "Night Elf"; className = "Druid"; realm = "Fixture"; faction = "Alliance"
    level = 10; goldCopper = 100; health = "100/100"
    xp = [ordered]@{ current = 0; max = 0; rested = 0 }
    itemLevel = [ordered]@{ average = 1; equipped = 1; pvp = 1 }
    location = [ordered]@{ zone = "Fixture"; map = "Fixture"; coordinates = ""; hearthstone = "" }
    currencies = @(); professions = @(); gear = @(); bags = @()
    bank = [ordered]@{ note = ""; items = @() }
    reputations = @()
    quests = [ordered]@{ current = @(); completedNames = @(); completedCount = 0 }
    kills = [ordered]@{ total = 0; creatures = 0; goldLootedCopper = 0; byType = [ordered]@{}; top = @() }
    sessions = @(); statistics = [ordered]@{}
    achievements = [ordered]@{ completed = 0; total = 0; recent = @() }
    talents = [ordered]@{ specialization = "Druid"; loadout = ""; importString = $null; tree = @() }
    spells = @(); biography = @()
    lockouts = [ordered]@{ instanceCount = 0; lines = @() }
    sources = [ordered]@{ export = [ordered]@{ file = "synthetic.txt"; addonVersion = "0"; parsedAt = "2026-10-20T00:00:00" } }
  }
}

try {
  $seed = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @((Seed-Character "fixturin" "sorinis" "Fixturin Testmend"), (Seed-Character "malavus" "malavus" "Malavus Testmend"))
  }
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seed | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "collections.json") '{"schemaVersion":1,"generatedAt":null,"characters":[]}'
  $journals = [ordered]@{
    schemaVersion = 1
    entries       = @(
      [ordered]@{ id = "j-old"; character = "sorinis"; date = "2026-10-01"; title = "First Fixture Tale"; body = @("Older."); facts = @(); source = "fixture" },
      [ordered]@{ id = "j-new"; character = "sorinis"; date = "2026-10-05"; title = "Second Fixture Tale"; body = @("Newer."); facts = @("A fact"); source = "fixture" }
    )
  }
  $journalsPath = Join-Path $tmp "journals.json"
  Write-Utf8 $journalsPath ($journals | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $generator -PrivateDir $privateDir -OutDir $outDir -JournalsPath $journalsPath | Out-Host

  $pack = Get-Content -Raw (Join-Path $outDir "fixturin.md")
  Assert ($pack -match "## Journal") "pack has Journal section"
  Assert ($pack -match "Latest journal entry: Second Fixture Tale \(2026-10-05\)") "latest entry wins by date"
  Assert ($pack -notmatch "First Fixture Tale") "older entry not printed in the pack"

  $other = Get-Content -Raw (Join-Path $outDir "malavus.md")
  Assert ($other -match "## Journal") "pack has Journal section for the entry-less character"
  Assert ($other -match "No journal entries yet") "honest empty line when the character has no entries"

  Write-Output "PASS test-journal-pack"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
