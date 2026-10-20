# Focused checks for scripts/parse-saved-vars.ps1 (Phase 2a).
# Run: powershell -NoProfile -File scripts/tests/test-parse-saved-vars.ps1
# Builds a temp WTF layout from gitignored fixtures (fake names only), parses
# into a temp private dir, and asserts the merge plus the privacy rule:
# no fixture id may appear in any committed file (git grep, test file excluded).

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent (Split-Path -Parent ($scriptDir -replace '^\\\\\?\\',''))
$parser = Join-Path $repo "scripts\parse-saved-vars.ps1"
$fixtureDir = Join-Path $repo "data\private\fixtures"
foreach ($f in @("Syndicator.fixture.lua", "DataStore_Reputations.fixture.lua", "DataStore_Currencies.fixture.lua", "DataStore_Characters.fixture.lua")) {
  if (-not (Test-Path (Join-Path $fixtureDir $f))) { throw "Missing fixture: $f" }
}

$tmp = Join-Path $repo ("data\private\test-tmp-" + [guid]::NewGuid().ToString("N"))
$wtf = Join-Path $tmp "wtf"
$svDir = Join-Path $wtf "Account\TestAcct\SavedVariables"
$privateDir = Join-Path $tmp "private"
$catalogsPath = Join-Path $tmp "catalogs.json"
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
  Copy-Item (Join-Path $fixtureDir "Syndicator.fixture.lua") (Join-Path $svDir "Syndicator.lua")
  Copy-Item (Join-Path $fixtureDir "DataStore_Reputations.fixture.lua") (Join-Path $svDir "DataStore_Reputations.lua")
  Copy-Item (Join-Path $fixtureDir "DataStore_Currencies.fixture.lua") (Join-Path $svDir "DataStore_Currencies.lua")
  Copy-Item (Join-Path $fixtureDir "DataStore_Characters.fixture.lua") (Join-Path $svDir "DataStore_Characters.lua")

  # Seed canonical: dossier gold deliberately differs from fixture money so the
  # test proves Syndicator never overwrites the export-anchored goldCopper.
  $seedChars = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @([ordered]@{
        id = "fixturin"; name = "Fixturin Testmend"; displayName = $null
        goldCopper = 99999; reputations = @()
      })
  }
  $seedEcon = [ordered]@{
    schemaVersion = 1; generatedAt = $null
    characters    = @([ordered]@{ id = "fixturin"; goldCopper = 99999 })
  }
  $seedCatalogs = [ordered]@{
    schemaVersion = 1
    quests = [ordered]@{ source = "data/quests.json"; extra = [ordered]@{} }
    factions = [ordered]@{}
    unresolved = [ordered]@{ quests = @(); factions = @() }
  }
  Write-Utf8 (Join-Path $privateDir "characters.json") ($seedChars | ConvertTo-Json -Depth 20)
  Write-Utf8 (Join-Path $privateDir "economy.json") ($seedEcon | ConvertTo-Json -Depth 20)
  Write-Utf8 $catalogsPath ($seedCatalogs | ConvertTo-Json -Depth 20)

  & powershell -NoProfile -File $parser -WtfRoot $wtf -PrivateDir $privateDir -CatalogsPath $catalogsPath | Out-Host

  $chars = Get-Content -Raw (Join-Path $privateDir "characters.json") -Encoding UTF8 | ConvertFrom-Json
  $c = @($chars.characters | Where-Object { $_.id -eq "fixturin" })[0]
  Assert ($null -ne $c) "fixture character merged"
  Assert ($c.goldCopper -eq 99999) "dossier goldCopper untouched by Syndicator, got $($c.goldCopper)"
  Assert ($c.syndicator.moneyCopper -eq 12345) "syndicator money 12345, got $($c.syndicator.moneyCopper)"
  Assert ($c.syndicator.source -eq "syndicator") "syndicator block source-tagged"
  $sword = @($c.syndicator.bags | Where-Object { $_.name -eq "Fixture Sword" })[0]
  Assert ($null -ne $sword -and $sword.id -eq 111) "bag item Fixture Sword id 111"
  $helm = @($c.syndicator.equipped | Where-Object { $_.name -eq "Fixture Helm" })[0]
  Assert ($null -ne $helm) "equipped item Fixture Helm parsed"
  $letter = @($c.syndicator.mail | Where-Object { $_.itemName -eq "Fixture Letter" })[0]
  Assert ($null -ne $letter -and $letter.count -eq 2) "mail item with count 2"
  Assert ($letter.expiresAt -like "2026*") "mail expiration decoded, got $($letter.expiresAt)"

  $rep47 = @($c.datastore.reputations | Where-Object { $_.id -eq 47 })[0]
  Assert ($rep47.name -eq "Ironforge" -and $rep47.standing -eq "Friendly" -and $rep47.value -eq 100) "faction 47 resolves to Ironforge Friendly 100"
  $rep9999 = @($c.datastore.reputations | Where-Object { $_.id -eq 9999 })[0]
  Assert ($null -ne $rep9999 -and $rep9999.standing -eq "Friendly" -and $rep9999.value -eq 1234) "unresolved faction keeps id, standing, value"
  Assert ([string]::IsNullOrEmpty($rep9999.name)) "unresolved faction has no invented name"
  $tok = @($c.datastore.currencies | Where-Object { $_.name -eq "Fixture Token" })[0]
  Assert ($null -ne $tok -and $tok.quantity -eq 7) "currency Fixture Token quantity 7"

  $econ = Get-Content -Raw (Join-Path $privateDir "economy.json") -Encoding UTF8 | ConvertFrom-Json
  $e = @($econ.characters | Where-Object { $_.id -eq "fixturin" })[0]
  Assert ($e.goldCopper -eq 99999) "economy goldCopper untouched"
  Assert ($e.syndicatorMoneyCopper -eq 12345) "economy syndicator money recorded"
  Assert ($e.datastoreMoneyCopper -eq 12345) "economy datastore money recorded"

  $catalogs = Get-Content -Raw $catalogsPath -Encoding UTF8 | ConvertFrom-Json
  Assert ($catalogs.factions."47" -eq "Ironforge") "catalog gains verified faction 47"
  Assert (@($catalogs.unresolved.factions) -contains 9999) "catalog lists 9999 as unresolved"

  # Fixture-leak: git grep only sees tracked files, so the gitignored fixture
  # dir and temp output can never match. The only allowed hit is this file.
  $leaks = @(git -C $repo grep --name-only "Fixturin" -- . ":!scripts/tests/test-parse-saved-vars.ps1" 2>$null)
  Assert ($leaks.Count -eq 0) ("no fixture id in committed files" + $(if ($leaks.Count) { ": $($leaks -join ', ')" } else { "" }))

  Write-Output "PASS test-parse-saved-vars"
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
