# Journey #51 pack checks for scripts/butler-pack.ps1.
# Run: powershell -NoProfile -File scripts/tests/test-journey-pack.ps1
# Seeds a temp private dir with a Skyrinis test character and runs the
# generator twice: once with no ATT scan (honest pending states) and once
# with a quest have plus a collection-history name (computed progress).
# Uses the real committed data/journey.json as the route.

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
        id = "skyrinis"; rosterId = "skyrinis"; name = "Skyrinis Testmend"
        race = "Skyborne"; className = "Druid"; realm = "Fixture"; faction = "Alliance"
        level = 1; goldCopper = 100; health = "100/100"
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
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seed | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "collections.json") '{"schemaVersion":1,"generatedAt":null,"characters":[]}'
  Write-Utf8 (Join-Path $privateDir "quest-history.json") '{"schemaVersion":1,"generatedAt":null,"characters":[]}'

  # Case A: no ATT scan yet.
  Write-Utf8 (Join-Path $privateDir "att.json") '{"schemaVersion":1,"generatedAt":null,"characters":[]}'
  Write-Utf8 (Join-Path $privateDir "collection-history.json") '{"schemaVersion":1,"generatedAt":null,"entries":[]}'

  & powershell -NoProfile -File $generator -PrivateDir $privateDir -OutDir $outDir | Out-Host

  $pack = Get-Content -Raw (Join-Path $outDir "skyrinis.md")
  Assert ($pack -match "## Journey") "pack has Journey section for the journey character"
  Assert ($pack -match "Current zone: Zephras Isle") "current zone is the first not-DONE zone"
  Assert ($pack -match "no ATT scan yet") "honest no-scan state when the character has no canonical data"
  Assert ($pack -match "Next: The Cirrusfly Queen \(Zephras Isle, quests, quest 92463\)") "next unfinished gating item named"
  Assert ($pack -match "Manual ticks \(rares, BoEs, profession milestones\) live in the browser only") "manual-only sections disclaimed"

  # Case B: one quest have plus one collection-history name.
  Write-Utf8 (Join-Path $privateDir "att.json") ([ordered]@{
      schemaVersion = 1; generatedAt = "2026-10-20T00:00:00"
      characters = @([ordered]@{
          canonicalId = "skyrinis"; name = "Skyrinis Testmend"
          have = [ordered]@{
            quests = [ordered]@{ count = 1; have = @(92463) }
            exploration = [ordered]@{ count = 0; have = @() }
          }
        })
    } | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "collection-history.json") ([ordered]@{
      schemaVersion = 1; generatedAt = "2026-10-20T00:00:00"
      entries = @([ordered]@{ collectedAt = "2026-10-01 18:32:02"; type = "Pet"; name = "Musical Gustjumper"; itemId = $null })
    } | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $generator -PrivateDir $privateDir -OutDir $outDir | Out-Host

  $pack = Get-Content -Raw (Join-Path $outDir "skyrinis.md")
  Assert ($pack -match "Route: 2 of 70 route items \(3%\)") "computed overall progress from quest have plus history name"
  Assert ($pack -notmatch "no ATT scan yet") "no-scan note clears once scans exist"
  Assert ($pack -match "Zephras Isle: 2 of 36 \(2 of 30 gating\)") "zone line with gating sub-count"
  Assert ($pack -match "Next: Elemental Unrest \(Zephras Isle, quests, quest 92464\)") "next advances past the completed quest"

  Write-Output "PASS test-journey-pack"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
