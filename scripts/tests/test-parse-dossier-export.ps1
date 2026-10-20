# Focused checks for scripts/parse-dossier-export.ps1 (Phase 1a).
# Run: powershell -File scripts/tests/test-parse-dossier-export.ps1
# Parses the example export into a temp folder and asserts canonical
# values plus the privacy rule: no gold/bags/bank/mail keys in public JSON.

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$parser = Join-Path $repo "scripts\parse-dossier-export.ps1"
$fixture = Join-Path $repo "Exported By Dossier 2.2.18 (Example Export).txt"
if (-not (Test-Path $fixture)) { throw "Missing fixture: $fixture" }

$tmp = Join-Path $repo ("data\private\test-tmp-" + [guid]::NewGuid().ToString("N"))
$privateDir = Join-Path $tmp "private"
$publicPath = Join-Path $tmp "characters.public.json"
New-Item -ItemType Directory -Force -Path $privateDir | Out-Null

function Assert($condition, $message) {
  if (-not $condition) { throw "ASSERT FAILED: $message" }
  Write-Output "ok - $message"
}

try {
  & powershell -NoProfile -File $parser -ExportPath $fixture -PrivateDir $privateDir -PublicPath $publicPath | Out-Host

  $chars = Get-Content -Raw (Join-Path $privateDir "characters.json") | ConvertFrom-Json
  Assert ($chars.schemaVersion -eq 1) "private characters schemaVersion 1"
  Assert ($chars.characters.Count -eq 1) "one character parsed"
  $c = $chars.characters[0]
  Assert ($c.id -eq "flann") "id is slug of in-game name (flann), got $($c.id)"
  Assert ($c.level -eq 20) "level 20, got $($c.level)"
  Assert ($c.realm -eq "Classic Beta PvE 2") "realm parsed, got $($c.realm)"
  Assert ($c.goldCopper -eq 22067) "gold 2g 20s 67c = 22067 copper, got $($c.goldCopper)"
  $mining = @($c.professions | Where-Object { $_.name -eq "Mining" })[0]
  Assert ($mining.current -eq 47 -and $mining.max -eq 75) "Mining 47/75"
  $bs = @($c.professions | Where-Object { $_.name -eq "Blacksmithing" })[0]
  Assert ($bs.current -eq 19) "Blacksmithing 19"
  Assert ($c.quests.completedCount -eq 172) "completed quest count 172, got $($c.quests.completedCount)"
  $expanding = @($c.quests.current | Where-Object { $_.id -eq 97914 })[0]
  Assert ($null -ne $expanding -and $expanding.name -eq "Expanding Horizons") "Forever quest 97914 resolved by export as Expanding Horizons"
  Assert ($c.kills.total -eq 1509) "kills total 1509, got $($c.kills.total)"
  Assert (@($c.bags).Count -ge 1) "bags present in PRIVATE file"
  Assert (@($c.biography).Count -eq 13) "biography 13 events, got $(@($c.biography).Count)"
  Assert ($c.talents.importString -like "CEdBzT2eoXLGqEykspPS*") "talent import string captured"
  Assert (@($c.addonsLoaded) -contains "Dossier") "addons loaded includes Dossier"

  $coll = Get-Content -Raw (Join-Path $privateDir "collections.json") | ConvertFrom-Json
  Assert ($coll.characters[0].collections.battlePets.have -eq 2) "battle pets 2"
  Assert (@($coll.characters[0].collections.battlePets.names) -contains "Musical Gustjumper") "pet name captured"

  $econ = Get-Content -Raw (Join-Path $privateDir "economy.json") | ConvertFrom-Json
  Assert ($econ.characters[0].goldCopper -eq 22067) "economy gold matches"

  # Privacy: public file is allowlist + roster-only. Flann is a beta
  # throwaway, not on the launch roster, so he must not appear at all.
  $publicRaw = Get-Content -Raw $publicPath
  $public = $publicRaw | ConvertFrom-Json
  Assert ($public.characters.Count -eq 0) "public file excludes non-roster beta character"
  foreach ($forbidden in @("goldCopper", '"bags"', '"bank"', '"mail"', "22067")) {
    Assert ($publicRaw -notmatch [regex]::Escape($forbidden)) "public file has no $forbidden"
  }

  # Older beta format: gear is one subsection per slot
  $betaFixture = Join-Path $repo "exports\beta\flann-anvilhew-2026-09-26-2.txt"
  if (Test-Path $betaFixture) {
    $betaDir = Join-Path $tmp "beta-private"
    & powershell -NoProfile -File $parser -ExportPath $betaFixture -PrivateDir $betaDir -PublicPath (Join-Path $tmp "beta-public.json") | Out-Host
    $beta = (Get-Content -Raw (Join-Path $betaDir "characters.json") | ConvertFrom-Json).characters[0]
    Assert (@($beta.gear).Count -eq 10) "beta-format gear 10 pieces, got $(@($beta.gear).Count)"
    Assert (@($beta.gear | Where-Object { $_.name -eq "Timberland Cape" }).Count -eq 1) "beta gear includes Timberland Cape"
    Assert ($beta.goldCopper -eq 28863) "beta gold 28863 matches legacy export JSON"
  }

  # Phase 2a projection: a roster-matched synthetic export projects reputation
  # and currency NAMES only — no values, no raw text, no gold.
  $synDir = Join-Path $tmp "synthetic"
  New-Item -ItemType Directory -Force -Path $synDir | Out-Null
  $synExport = Join-Path $synDir "fixturin-export.txt"
  $synRoster = Join-Path $synDir "roster.json"
  $exportText = @(
    "Dossier 2.2.18 - Character Export",
    "Character Stats:",
    "Character: Fixturin Testmend-Fixture",
    "Faction: Alliance",
    "Race: Human",
    "Class: Warrior",
    "Level: 10",
    "Currencies:",
    "Gold: 1g 2s 3c",
    "Honor Points: 12/25000",
    "Skills:",
    "== Professions ==",
    "Mining 5 / 75",
    "Reputations:",
    "Ironforge Honored 2315 / 9000"
  ) -join "`n"
  $noBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($synExport, $exportText + "`n", $noBom)
  [System.IO.File]::WriteAllText($synRoster, '[{"id":"fixturin-test","name":"Fixturin Testmend"}]', $noBom)
  $synOut = Join-Path $synDir "public.json"
  & powershell -NoProfile -File $parser -ExportPath $synExport -PrivateDir (Join-Path $synDir "private") -PublicPath $synOut -RosterPath $synRoster | Out-Host
  $synPublic = Get-Content -Raw $synOut | ConvertFrom-Json
  Assert (@($synPublic.characters).Count -eq 1) "synthetic roster char projected"
  $sp = $synPublic.characters[0]
  Assert ($sp.id -eq "fixturin-test") "roster id carried into public"
  Assert (@($sp.reputations).Count -eq 1 -and $sp.reputations[0].name -eq "Ironforge" -and $sp.reputations[0].standing -eq "Honored") "reputation name+standing projected"
  Assert (@($sp.reputations[0].PSObject.Properties.Name | Where-Object { $_ -notin @("name", "standing") }).Count -eq 0) "no reputation values in public"
  Assert (@($sp.currencies).Count -eq 1 -and $sp.currencies[0].name -eq "Honor Points") "currency name projected"
  Assert (@($sp.currencies[0].PSObject.Properties.Name | Where-Object { $_ -ne "name" }).Count -eq 0) "no currency values in public"
  $synRaw = Get-Content -Raw $synOut
  foreach ($forbidden in @("2315", "9000", "12/25000", "10203", '"goldCopper"', '"raw"', '"quantity"')) {
    Assert ($synRaw -notmatch [regex]::Escape($forbidden)) "public file has no $forbidden"
  }


  # Datastore preference + merge preservation: inject a Phase 2a merge result,
  # re-parse the same export, and prove the merge survives with datastore first.
  $privCharsPath = Join-Path (Join-Path $synDir "private") "characters.json"
  $privChars = Get-Content -Raw $privCharsPath | ConvertFrom-Json
  $seed = $privChars.characters[0]
  $seed | Add-Member -NotePropertyName "syndicator" -NotePropertyValue ([ordered]@{ moneyCopper = 12345 }) -Force
  $seed | Add-Member -NotePropertyName "datastore" -NotePropertyValue ([ordered]@{
      source = "datastore"
      reputations = @(
        [ordered]@{ id = 47; name = "Ironforge"; standing = "Revered"; standingId = 7; value = 15000; source = "datastore" },
        [ordered]@{ id = 9999; standing = "Friendly"; standingId = 5; value = 1234; source = "datastore" }
      )
      currencies = @([ordered]@{ name = "Honor Points"; quantity = 12; source = "datastore" })
    }) -Force
  $noBom2 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($privCharsPath, ($privChars | ConvertTo-Json -Depth 20), $noBom2)
  & powershell -NoProfile -File $parser -ExportPath $synExport -PrivateDir (Join-Path $synDir "private") -PublicPath $synOut -RosterPath $synRoster | Out-Host
  $reparsed = Get-Content -Raw $privCharsPath | ConvertFrom-Json
  Assert ($reparsed.characters[0].syndicator.moneyCopper -eq 12345) "syndicator block survives re-parse"
  Assert (@($reparsed.characters[0].datastore.reputations).Count -eq 2) "datastore block survives re-parse"
  $repub = Get-Content -Raw $synOut | ConvertFrom-Json
  $rIron = @($repub.characters[0].reputations | Where-Object { $_.name -eq "Ironforge" })[0]
  Assert ($rIron.standing -eq "Revered") "datastore standing wins over dossier export"
  Assert (@($repub.characters[0].reputations | Where-Object { $_.id -eq 9999 }).Count -eq 0) "unresolved id never projected"
  $synRaw2 = Get-Content -Raw $synOut
  Assert ($synRaw2 -notmatch "9999") "public file has no unresolved id"

  Write-Output "PASS test-parse-dossier-export"


} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
