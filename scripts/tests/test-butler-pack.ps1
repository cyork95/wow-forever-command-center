# Focused checks for scripts/butler-pack.ps1 guide mapping (board #42).
# Run: powershell -NoProfile -File scripts/tests/test-butler-pack.ps1
# Seeds a temp private dir with one roster-matched fake character and a temp
# guides file, runs the generator, and asserts the per-character mapping:
# only appliesTo-matching entries print, with title + url.

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

try {
  $seed = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @([ordered]@{
        id = "fixturin"; rosterId = "sorinis"; name = "Fixturin Testmend"
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
      })
  }
  $guides = [ordered]@{
    schemaVersion = 1
    guides        = @(
      [ordered]@{ id = "g-sorinis"; title = "Sorinis Guide"; url = "https://example.invalid/sorinis"; appliesTo = @("sorinis") },
      [ordered]@{ id = "g-malavus"; title = "Malavus Guide"; url = "https://example.invalid/malavus"; appliesTo = @("malavus") }
    )
  }
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seed | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "collections.json") '{"schemaVersion":1,"generatedAt":null,"characters":[]}'
  $guidesPath = Join-Path $tmp "guides.json"
  Write-Utf8 $guidesPath ($guides | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $generator -PrivateDir $privateDir -OutDir $outDir -GuidesPath $guidesPath | Out-Host

  $pack = Get-Content -Raw (Join-Path $outDir "fixturin.md")
  Assert ($pack -match "## Relevant guides") "pack has Relevant guides section"
  Assert ($pack -match "Sorinis Guide: https://example.invalid/sorinis") "mapped guide printed with title and url"
  Assert ($pack -notmatch "Malavus Guide") "unmapped guide excluded"

  Write-Output "PASS test-butler-pack"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
