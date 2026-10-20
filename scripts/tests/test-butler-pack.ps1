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
  $hunts = @(
    [ordered]@{ id = "g-mine"; name = "Fixture Sword"; kind = "Gear"; type = "gear"; zone = "Fixture"; minLevel = 1; priority = "High"; status = "Planned"; owners = @("Fixturin"); targetCharacters = @("Fixturin"); notes = ""; source = "Test" },
    [ordered]@{ id = "g-other"; name = "Far Sword"; kind = "Gear"; type = "gear"; zone = "Far"; minLevel = 1; priority = "Low"; status = "Planned"; owners = @("malavus"); targetCharacters = @("malavus"); notes = ""; source = "Test" },
    [ordered]@{ id = "m-mine"; name = "Fixture Mission"; kind = "Quest"; type = "mission"; zone = "Fixture"; minLevel = 1; priority = "High"; status = "Planned"; owners = @("fixturin"); targetCharacters = @("fixturin"); quests = @(7, 8); notes = ""; source = "Test" },
    [ordered]@{ id = "c-got"; name = "Fixture Helm"; kind = "Pet"; type = "collection"; zone = "Fixture"; minLevel = 1; priority = "Low"; status = "Planned"; owners = @("all"); accountWide = $true; assignedTo = @("all"); match = [ordered]@{ names = @("Fixture Helm") }; notes = ""; source = "Test" },
    [ordered]@{ id = "c-want"; name = "Fixture Mount"; kind = "Mount"; type = "collection"; zone = "Fixture"; minLevel = 1; priority = "Low"; status = "Planned"; owners = @("all"); accountWide = $true; assignedTo = @("all"); match = [ordered]@{ names = @("Fixture Mount") }; notes = ""; source = "Test" }
  )
  $huntsPath = Join-Path $tmp "hunts.json"
  Write-Utf8 $huntsPath ($hunts | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "collection-history.json") ([ordered]@{
      schemaVersion = 1; generatedAt = "2026-10-20T00:00:00"; sources = @(); count = 1
      types = [ordered]@{ ItemWithAppearance = 1 }
      entries = @([ordered]@{ collectedAt = "2026-10-01 18:32:02"; type = "ItemWithAppearance"; name = "Fixture Helm"; itemId = 424242; raw = "raw" })
    } | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "quest-history.json") ([ordered]@{
      schemaVersion = 1; generatedAt = "2026-10-20T00:00:00"; sources = @(); count = 0
      characters = @([ordered]@{ svKey = "Fixturin Testmend"; name = "Fixturin"; canonicalId = "fixturin"; guid = $null; journey = @(); completeIds = @(7); counts = [ordered]@{ source = "questie"; events = 0; accepts = 0; completes = 0; levelUps = 0; other = 0; completeIds = 1 } })
    } | ConvertTo-Json -Depth 20)
  $guidesPath = Join-Path $tmp "guides.json"
  Write-Utf8 $guidesPath ($guides | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $generator -PrivateDir $privateDir -OutDir $outDir -GuidesPath $guidesPath -HuntsPath $huntsPath | Out-Host

  $pack = Get-Content -Raw (Join-Path $outDir "fixturin.md")
  Assert ($pack -match "## Relevant guides") "pack has Relevant guides section"
  Assert ($pack -match "Sorinis Guide: https://example.invalid/sorinis") "mapped guide printed with title and url"
  Assert ($pack -notmatch "Malavus Guide") "unmapped guide excluded"
  Assert ($pack -match "## Hunts") "pack has Hunts section"
  Assert ($pack -match "Fixture Sword") "matching gear hunt listed"
  Assert ($pack -notmatch "Far Sword") "non-matching gear hunt excluded"
  Assert ($pack -match "Fixture Mission: 1 of 2 quests complete") "mission progress from Questie complete ids"
  Assert ($pack -match "Collections \(account-wide, identical in every pack\): 1 of 2 obtained") "account-wide collections line with obtained count"
  Assert ($pack -match "Fixture Helm \(obtained\)") "timeline-matched collection listed as obtained"

  Write-Output "PASS test-butler-pack"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
