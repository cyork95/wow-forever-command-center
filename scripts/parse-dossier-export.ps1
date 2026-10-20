# Parse a Dossier text export into the canonical private JSON set,
# and generate the redacted public JSON for the site.
# Usage:
#   powershell -File scripts/parse-dossier-export.ps1 -ExportPath <file.txt> [-ExportPath <file2.txt>]
#   powershell -File scripts/parse-dossier-export.ps1 -ExportPath (Get-ChildItem exports/raw/*.txt)
# Private output: data/private/characters.json, collections.json, economy.json (gitignored).
# Public output:  data/characters.public.json (allowlist projection, roster-matched only).
# See docs/canonical-json.md. Phase 1: Dossier text only. No SavedVariables are read here.

param(
  [Parameter(Mandatory = $true)][string[]]$ExportPath,
  [string]$PrivateDir = "",
  [string]$PublicPath = "",
  [string]$RosterPath = ""
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent ($PSScriptRoot -replace '^\\\\\?\\','')
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
if (-not $PublicPath) { $PublicPath = Join-Path $repo "data\characters.public.json" }
if (-not $RosterPath) { $RosterPath = Join-Path $repo "data\characters.json" }

function Write-JsonFile($path, $value) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json = $value | ConvertTo-Json -Depth 20
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json + "`n", $utf8)
}

function Read-JsonFile($path) {
  if (-not (Test-Path $path)) { return $null }
  return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

function ConvertTo-Slug($text) {
  if (-not $text) { return "" }
  return (($text.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '^-+|-+$', '')
}

function ConvertFrom-Money($text) {
  if (-not $text) { return $null }
  $total = 0; $found = $false
  if ($text -match '(\d+)\s*g\b') { $total += [int]$Matches[1] * 10000; $found = $true }
  if ($text -match '(\d+)\s*s\b') { $total += [int]$Matches[1] * 100; $found = $true }
  if ($text -match '(\d+)\s*c\b') { $total += [int]$Matches[1]; $found = $true }
  if (-not $found) { return $null }
  return $total
}

$script:TopHeadings = @(
  "Location", "Character Stats", "Currencies", "Collections", "Bags", "Bank",
  "Shopping list", "Equipment", "Combat pet", "Lockouts", "Progress", "Kills",
  "Sessions", "Statistics", "Achievements", "Achievement (completed)",
  "Appearance (collected)", "Appearances", "Reputations", "Quests",
  "Quest (completed)", "Skills", "Profession Details", "Talents", "Spellbook",
  "Biography", "Companions", "AddOns", "Mail", "Tasks", "Notes"
)

function Split-ExportSections($lines) {
  $sections = [ordered]@{}
  foreach ($heading in $script:TopHeadings) { $sections[$heading] = New-Object System.Collections.Generic.List[string] }
  $current = "_header"
  $sections[$current] = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    $matched = $null
    foreach ($heading in $script:TopHeadings) {
      if ($trimmed -eq ($heading + ":")) { $matched = $heading; break }
    }
    if ($matched) {
      $current = $matched
      if (-not $sections.Contains($current)) { $sections[$current] = New-Object System.Collections.Generic.List[string] }
      continue
    }
    $sections[$current].Add($line)
  }
  return $sections
}

function Get-Subsections($lines) {
  $subs = [ordered]@{}
  $current = "_root"
  $subs[$current] = New-Object System.Collections.Generic.List[string]
  foreach ($line in @($lines)) {
    if ($line -match '^==\s*(.+?)\s*==\s*$') {
      $current = $Matches[1]
      if (-not $subs.Contains($current)) { $subs[$current] = New-Object System.Collections.Generic.List[string] }
      continue
    }
    $subs[$current].Add($line)
  }
  return $subs
}

function Get-KeyValues($lines) {
  $map = @{}
  foreach ($line in @($lines)) {
    if ($line -match '^\s*([^:=]+):\s*(.*)$') { $map[$Matches[1].Trim()] = $Matches[2].Trim() }
  }
  return $map
}

function Split-ListText($text) {
  if (-not $text) { return @() }
  return @($text -split ',\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Parse-DossierExport($path, $roster) {
  $lines = @(Get-Content -Path $path)
  $sections = Split-ExportSections $lines

  $version = $null
  foreach ($line in @($sections["_header"])) {
    if ($line -match 'Dossier\s+([0-9][0-9A-Za-z.\-]*)') { $version = $Matches[1]; break }
  }

  $charKv = Get-KeyValues $sections["Character Stats"]
  $rawChar = [string]$charKv["Character"]
  $fullName = $rawChar; $realm = $null
  if ($rawChar -match '^(.+)-([^-]+)$' -and $rawChar -match '-') {
    # Split realm at the LAST dash segment boundary: realm names contain
    # spaces but no dash, so the first dash separates name from realm.
    $dash = $rawChar.IndexOf('-')
    $fullName = $rawChar.Substring(0, $dash).Trim()
    $realm = $rawChar.Substring($dash + 1).Trim()
  }
  # Older exports include the surname ("Flann Anvilhew-Realm"); newer
  # ones use the in-game name only ("Flann-Realm"). In-game name is the
  # first token; the full form is kept for roster matching.
  $name = ([string]$fullName -split '\s+')[0]
  $id = ConvertTo-Slug $name

  $displayName = $null; $rosterId = $null
  foreach ($entry in @($roster)) {
    $first = ([string]$entry.name -split '\s+')[0]
    if ([string]$entry.name -eq $fullName -or $first -eq $name) { $displayName = [string]$entry.name; $rosterId = [string]$entry.id; break }
  }

  $locKv = Get-KeyValues $sections["Location"]

  $goldCopper = $null; $currencies = @()
  foreach ($line in @($sections["Currencies"])) {
    if ($line -match '^\s*Gold:\s*(.+)$') { $goldCopper = ConvertFrom-Money $Matches[1] }
    elseif ($line -match '^\s*([^:]+):\s*(.+)$') { $currencies += [ordered]@{ name = $Matches[1].Trim(); raw = $Matches[2].Trim(); source = "dossier-export" } }
  }

  # Skills -> professions (Professions + Secondary Skills subsections)
  $professions = @()
  $skillSubs = Get-Subsections $sections["Skills"]
  foreach ($group in @("Professions", "Secondary Skills")) {
    if ($skillSubs.Contains($group)) {
      foreach ($line in @($skillSubs[$group])) {
        if ($line -match '^\s*(.+?)\s+(\d+)\s*/\s*(\d+)\s*$') {
          $professions += [ordered]@{ name = $Matches[1].Trim(); current = [int]$Matches[2]; max = [int]$Matches[3]; source = "dossier-export" }
        }
      }
    }
  }

  # Equipment
  $gear = @()
  $qualities = @("Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom")
  foreach ($line in @($sections["Equipment"])) {
    if ($line -match '^\s*([^:]+):\s*\[(.+?)\]\s*iLvl\s*(\d+)(?:,\s*([A-Za-z]+))?') {
      $slot = $Matches[1].Trim(); $itemName = $Matches[2].Trim(); $ilvl = [int]$Matches[3]
      $quality = $null
      foreach ($q in $qualities) { if ($line -match "\b$q\b") { $quality = $q; break } }
      $gear += [ordered]@{ slot = $slot; name = $itemName; itemLevel = $ilvl; quality = $quality }
    }
  }

  if (-not $gear.Count) {
    # Older export format: one subsection per slot, "[Name] x1 [ID: n, iLvl: n, Q: n]"
    $equipSubs = Get-Subsections $sections["Equipment"]
    foreach ($slot in $equipSubs.Keys) {
      if ($slot -eq "_root") { continue }
      $rarity = $null; $found = $null
      foreach ($line in @($equipSubs[$slot])) {
        if ($line -match '^\s*\[(.+?)\](?:\s+x\d+)?\s*\[ID:\s*\d+,\s*iLvl:\s*(\d+)') { $found = [ordered]@{ slot = $slot; name = $Matches[1].Trim(); itemLevel = [int]$Matches[2]; quality = $null } }
        if ($line -match '^\s*-\s*Rarity:\s*(\w+)') { $rarity = $Matches[1] }
      }
      if ($found) { $found.quality = $rarity; $gear += $found }
    }
  }

  # Bags and bank stay private (canonical file only, never projected to public)
  $bags = @()
  foreach ($line in @($sections["Bags"])) {
    if ($line -match '^\s*(.+?)\s*\(\d+\s*/\s*\d+\)\s*:\s*(.*)$') {
      $bags += [ordered]@{ name = $Matches[1].Trim(); items = @(Split-ListText $Matches[2]) }
    } elseif ($line -match '^\s{2,}(\S.*)$' -and $bags.Count) {
      $bags[$bags.Count - 1].items = @($bags[$bags.Count - 1].items) + @(Split-ListText $Matches[1])
    }
  }
  $bankItems = @(); $bankNote = ""
  foreach ($line in @($sections["Bank"])) {
    if ($line -match 'Bank tabs:\s*(.*)$') { $bankItems = @(Split-ListText $Matches[1]) }
    elseif ($line.Trim()) { $bankNote = ($bankNote + " " + $line.Trim()).Trim() }
  }

  $shopping = @()
  foreach ($line in @($sections["Shopping list"])) {
    $t = $line.Trim()
    if ($t -and $t -notmatch '^Nothing on the shopping list') { $shopping += $t }
  }

  $lockoutCount = $null
  foreach ($line in @($sections["Lockouts"])) {
    if ($line -match 'Instance Lockout Count:\s*(\d+)') { $lockoutCount = [int]$Matches[1] }
  }

  $reputations = @()
  foreach ($line in @($sections["Reputations"])) {
    if ($line -match '^\s*Saved standings\s*$') { break }
    if ($line -match '^\s*(.+?)\s+(Neutral|Friendly|Honored|Revered|Exalted)\s+(\d+)\s*/\s*(\d+)\s*$') {
      $reputations += [ordered]@{ name = $Matches[1].Trim(); standing = $Matches[2]; value = [int]$Matches[3]; max = [int]$Matches[4]; source = "dossier-export" }
    }
  }

  # Quests: current (by zone subsection) + completed names/count
  $currentQuests = @()
  $questSubs = Get-Subsections $sections["Quests"]
  foreach ($zone in $questSubs.Keys) {
    if ($zone -eq "_root") { continue }
    foreach ($line in @($questSubs[$zone])) {
      if ($line -match '^\s*(.+?)\s*\((\d+),\s*([^,]+),\s*ID\s*(\d+)\)\s*(?::\s*(.*))?$') {
        $objectives = @()
        if ($Matches[5]) { $objectives = @(Split-ListText ($Matches[5] -replace ';', ',')) }
        $currentQuests += [ordered]@{ name = $Matches[1].Trim(); level = [int]$Matches[2]; status = $Matches[3].Trim(); id = [int]$Matches[4]; zone = $zone; objectives = $objectives }
      }
    }
  }
  $completedNames = @(); $completedCount = $null
  $completedText = (@($sections["Quest (completed)"]) -join "`n")
  if ($completedText -match 'Completed Quest Count:\s*(\d+)') { $completedCount = [int]$Matches[1] }
  $questListText = ""
  $capture = $false
  foreach ($line in @($sections["Quest (completed)"])) {
    if ($line -match '^\s*Quests:\s*(.*)$') { $questListText = $Matches[1]; $capture = $true; continue }
    if ($capture -and $line -match '^\s{2,}(\S.*)$') { $questListText += ", " + $Matches[1].Trim(); continue }
    if ($capture -and -not $line.Trim()) { $capture = $false }
  }
  foreach ($entry in @(Split-ListText $questListText)) {
    $clean = ($entry -replace '\s+x\d+\s*$', '').Trim()
    if ($clean) { $completedNames += $clean }
  }
  if ($null -eq $completedCount) { $completedCount = $completedNames.Count }

  # Collections
  $collectionsText = (@($sections["Collections"]) -join "`n")
  $collections = [ordered]@{}
  foreach ($kind in @("Mount", "Pet", "Toy")) {
    $have = $null; $total = $null
    if ($collectionsText -match ($kind + '\s*Count:\s*(\d+)\s*/\s*(\d+)')) { $have = [int]$Matches[1]; $total = [int]$Matches[2] }
    $key = switch ($kind) { "Mount" { "mounts" } "Pet" { "battlePets" } default { "toys" } }
    $collections[$key] = [ordered]@{ have = $have; total = $total; names = @() }
  }
  $collSubs = Get-Subsections $sections["Collections"]
  if ($collSubs.Contains("Battle Pets")) {
    foreach ($line in @($collSubs["Battle Pets"])) {
      if ($line -match '^\s*(.+?)\s*\(Species ID:\s*\d+\)') { $collections["battlePets"].names = @($collections["battlePets"].names) + @($Matches[1].Trim()) }
    }
  }

  # Kills
  $killsTotal = $null; $killsCreatures = $null; $killsGold = $null; $byType = [ordered]@{}
  foreach ($line in @($sections["Kills"])) {
    if ($line -match 'Total kills:\s*(\d+)\s+across\s+(\d+)') { $killsTotal = [int]$Matches[1]; $killsCreatures = [int]$Matches[2] }
    if ($line -match 'Gold looted:\s*(.+)$') { $killsGold = ConvertFrom-Money $Matches[1] }
    if ($line -match 'By type:\s*(.+)$') {
      foreach ($part in @(Split-ListText $Matches[1])) {
        if ($part -match '^(.+?)\s+(\d+)$') { $byType[$Matches[1].Trim()] = [int]$Matches[2] }
      }
    }
  }
  $topCreatures = @()
  $killSubs = Get-Subsections $sections["Kills"]
  $topKey = @($killSubs.Keys | Where-Object { $_ -match 'Top \d+ creatures' } | Select-Object -First 1)
  if ($topKey) {
    $topText = (@($killSubs[$topKey[0]]) -join ", ")
    foreach ($part in @(Split-ListText $topText)) {
      if ($part -match '^(.+?)\s+(\d+)$') { $topCreatures += [ordered]@{ name = $Matches[1].Trim(); kills = [int]$Matches[2] } }
    }
  }

  # Statistics: keep raw lines per subsection (values mix text and numbers)
  $statistics = [ordered]@{}
  $statSubs = Get-Subsections $sections["Statistics"]
  foreach ($group in $statSubs.Keys) {
    if ($group -eq "_root") { continue }
    $statistics[$group] = @(@($statSubs[$group]) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  }

  $achievements = [ordered]@{ completed = $null; total = $null; recent = @() }
  foreach ($line in @($sections["Achievements"])) {
    if ($line -match 'Achievements Completed:\s*(\d+)\s*/\s*(\d+)') { $achievements.completed = [int]$Matches[1]; $achievements.total = [int]$Matches[2] }
    if ($line -match '^\s*Recent:\s*(.+)$') { $achievements.recent = @(Split-ListText $Matches[1]) }
  }

  $professionDetails = @()
  $detailSubs = Get-Subsections $sections["Profession Details"]
  foreach ($key in $detailSubs.Keys) {
    if ($key -eq "_root") { continue }
    if ($key -match '^(.+?)\s+(\d+)\s*/\s*(\d+)$') {
      $detailName = $Matches[1].Trim(); $detailCur = [int]$Matches[2]; $detailMax = [int]$Matches[3]
      $known = [ordered]@{}; $notLearned = $null
      foreach ($line in @($detailSubs[$key])) {
        if ($line -match '^\s*(Orange|Yellow|Green|Grey|Gray):\s*(.+)$') { $known[$Matches[1]] = @(Split-ListText $Matches[2]) }
        if ($line -match 'Not learned yet:\s*(\d+)') { $notLearned = [int]$Matches[1] }
      }
      $professionDetails += [ordered]@{ name = $detailName; current = $detailCur; max = $detailMax; knownByColor = $known; notLearnedYet = $notLearned }
    }
  }

  $talentKv = Get-KeyValues $sections["Talents"]
  $importString = $null
  $talentLines = @($sections["Talents"])
  for ($i = 0; $i -lt $talentLines.Count; $i++) {
    if ($talentLines[$i] -match 'Talent Import String') {
      for ($j = $i + 1; $j -lt $talentLines.Count; $j++) {
        if ($talentLines[$j].Trim()) { $importString = $talentLines[$j].Trim(); break }
      }
      break
    }
  }
  $tree = @()
  $talentSubs = Get-Subsections $sections["Talents"]
  foreach ($key in $talentSubs.Keys) {
    if ($key -match 'Talent Tree') {
      foreach ($line in @($talentSubs[$key])) {
        if ($line -match '^\s*(.+?)\s+(\d+)\s*/\s*(\d+)\s*$') { $tree += [ordered]@{ name = $Matches[1].Trim(); rank = [int]$Matches[2]; max = [int]$Matches[3] } }
      }
    }
  }

  $spells = @()
  foreach ($line in @($sections["Spellbook"])) {
    if ($line -match '^\s*([^:]+):\s*(.+)$') { $spells += [ordered]@{ group = $Matches[1].Trim(); names = @(Split-ListText $Matches[2]) } }
  }

  $biography = @()
  $bioSubs = Get-Subsections $sections["Biography"]
  foreach ($date in $bioSubs.Keys) {
    if ($date -eq "_root") { continue }
    foreach ($line in @($bioSubs[$date])) {
      if ($line -match '^\s*(\d{1,2}:\d{2})\s+(.+)$') { $biography += [ordered]@{ date = $date; time = $Matches[1]; text = $Matches[2].Trim() } }
    }
  }

  $addonsLoaded = @()
  $addonSubs = Get-Subsections $sections["AddOns"]
  if ($addonSubs.Contains("Loaded")) {
    foreach ($line in @($addonSubs["Loaded"])) {
      if ($line -match '^\s*(.+?)(?:\s+by\s+.+?)?\s*\[[^\]]*\]\s*$') { $addonsLoaded += $Matches[1].Trim() }
    }
  }

  $sessions = @()
  $sessSubs = Get-Subsections $sections["Sessions"]
  foreach ($key in $sessSubs.Keys) {
    foreach ($line in @($sessSubs[$key])) { if ($line.Trim()) { $sessions += $line.Trim() } }
  }

  $character = [ordered]@{
    id = $id; name = $name; displayName = $displayName; rosterId = $rosterId; realm = $realm
    faction = $charKv["Faction"]; race = $charKv["Race"]; className = $charKv["Class"]
    level = $(if ($charKv["Level"]) { [int]$charKv["Level"] } else { $null })
    xp = [ordered]@{
      current = $(if ($charKv["XP"] -match '^(\d+)') { [int]$Matches[1] } else { $null })
      max = $(if ($charKv["XP"] -match '/\s*(\d+)') { [int]$Matches[1] } else { $null })
      rested = $(if ($charKv["Rested XP"]) { [int]$charKv["Rested XP"] } else { $null })
    }
    itemLevel = [ordered]@{
      average = $(if ($charKv["Average Item Level"]) { [double]$charKv["Average Item Level"] } else { $null })
      equipped = $(if ($charKv["Equipped Item Level"]) { [double]$charKv["Equipped Item Level"] } else { $null })
      pvp = $(if ($charKv["PvP Item Level"]) { [double]$charKv["PvP Item Level"] } else { $null })
    }
    health = $charKv["Health"]
    location = [ordered]@{ zone = $locKv["Zone"]; map = $locKv["Map"]; coordinates = $locKv["Coordinates"]; hearthstone = $locKv["Hearthstone Location"] }
    goldCopper = $goldCopper
    currencies = $currencies
    professions = $professions
    gear = $gear
    bags = $bags
    bank = [ordered]@{ note = $bankNote; items = $bankItems }
    shopping = $shopping
    lockouts = [ordered]@{ instanceCount = $lockoutCount; lines = @(@($sections["Lockouts"]) | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    reputations = $reputations
    quests = [ordered]@{ current = $currentQuests; completedNames = $completedNames; completedCount = $completedCount }
    kills = [ordered]@{ total = $killsTotal; creatures = $killsCreatures; goldLootedCopper = $killsGold; byType = $byType; top = $topCreatures }
    sessions = $sessions
    statistics = $statistics
    achievements = $achievements
    professionDetails = $professionDetails
    talents = [ordered]@{ specialization = $talentKv["Active Specialization"]; loadout = $talentKv["Loadout Name"]; importString = $importString; tree = $tree }
    spells = $spells
    biography = $biography
    addonsLoaded = $addonsLoaded
    exportedAt = $null
    sources = [ordered]@{ export = [ordered]@{ file = (Split-Path -Leaf $path); addonVersion = $version; parsedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") } }
  }

  return [ordered]@{
    character = $character
    collections = [ordered]@{ id = $id; collections = $collections; completedQuestNames = $completedNames; completedQuestCount = $completedCount }
    economy = [ordered]@{ id = $id; goldCopper = $goldCopper; wealth = $(if ($statistics.Contains("Character - Wealth")) { @($statistics["Character - Wealth"]) } else { @() }) }
  }
}


# ---- Main: merge into canonical private set, then project public ----
$roster = @()
if (Test-Path $RosterPath) { $roster = @(Read-JsonFile $RosterPath | ForEach-Object { $_ }) }

$charactersPath = Join-Path $PrivateDir "characters.json"
$collectionsPath = Join-Path $PrivateDir "collections.json"
$economyPath = Join-Path $PrivateDir "economy.json"

function Load-Canonical($path) {
  $existing = Read-JsonFile $path
  if ($existing -and $existing.characters) { return $existing }
  return [ordered]@{ schemaVersion = 1; generatedAt = $null; characters = @() }
}

$canonicalChars = Load-Canonical $charactersPath
$canonicalColl = Load-Canonical $collectionsPath
$canonicalEcon = Load-Canonical $economyPath

function Upsert-ById($list, $record) {
  $out = @($list | Where-Object { $_.id -ne $record.id })
  return @($out + @($record))
}

foreach ($exportFile in $ExportPath) {
  if (-not (Test-Path $exportFile)) { throw "Export not found: $exportFile" }
  $parsed = Parse-DossierExport $exportFile $roster
  # Preserve Phase 2a SavedVariables merges across re-parses: a fresh export
  # must not wipe the syndicator/datastore blocks merged by parse-saved-vars.ps1.
  $priorChar = @($canonicalChars.characters | Where-Object { $_.id -eq $parsed.character.id } | Select-Object -First 1)
  if ($priorChar.Count) {
    foreach ($field in @("syndicator", "datastore")) {
      if ($null -ne $priorChar[0].$field) { $parsed.character[$field] = $priorChar[0].$field }
    }
  }
  $priorEcon = @($canonicalEcon.characters | Where-Object { $_.id -eq $parsed.economy.id } | Select-Object -First 1)
  if ($priorEcon.Count) {
    foreach ($field in @("syndicatorMoneyCopper", "datastoreMoneyCopper")) {
      if ($null -ne $priorEcon[0].$field) { $parsed.economy[$field] = $priorEcon[0].$field }
    }
  }
  $canonicalChars.characters = @(Upsert-ById @($canonicalChars.characters) $parsed.character)
  $canonicalColl.characters = @(Upsert-ById @($canonicalColl.characters) $parsed.collections)
  $canonicalEcon.characters = @(Upsert-ById @($canonicalEcon.characters) $parsed.economy)
  Write-Output "Parsed $($parsed.character.name) (level $($parsed.character.level)) from $(Split-Path -Leaf $exportFile)"
}

$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
foreach ($doc in @($canonicalChars, $canonicalColl, $canonicalEcon)) { $doc.generatedAt = $stamp }
Write-JsonFile $charactersPath $canonicalChars
Write-JsonFile $collectionsPath $canonicalColl
Write-JsonFile $economyPath $canonicalEcon
Write-Output "Private: $charactersPath ($($canonicalChars.characters.Count) characters)"

# Public projection: ALLOWLIST only, roster-matched only.
# No gold, bags, bank, mail, ledger detail or item locations can reach this file.
$public = [ordered]@{ schemaVersion = 1; generatedAt = $stamp; characters = @() }
foreach ($char in @($canonicalChars.characters)) {
  if (-not $char.rosterId) { continue }
  $coll = @($canonicalColl.characters | Where-Object { $_.id -eq $char.id } | Select-Object -First 1)
  $counts = [ordered]@{}
  if ($coll.Count -and $coll[0].collections) {
    foreach ($prop in $coll[0].collections.PSObject.Properties) {
      $counts[$prop.Name] = [ordered]@{ have = $prop.Value.have; total = $prop.Value.total }
    }
  }
  # Phase 2a: names only, values stay private. DataStore (designated Phase 2
  # source) wins when present; unresolved IDs without a name never project.
  $pubReps = New-Object System.Collections.Generic.List[object]
  $dsReps = @()
  if ($char.datastore -and $char.datastore.reputations) { $dsReps = @($char.datastore.reputations) }
  $repSource = if (@($dsReps).Count) { $dsReps } else { @($char.reputations) }
  foreach ($rep in $repSource) {
    if ([string]::IsNullOrEmpty($rep.name)) { continue }
    $pubReps.Add([ordered]@{ name = [string]$rep.name; standing = [string]$rep.standing })
  }
  $pubCurs = New-Object System.Collections.Generic.List[object]
  $dsCurs = @()
  if ($char.datastore -and $char.datastore.currencies) { $dsCurs = @($char.datastore.currencies) }
  $curSource = if (@($dsCurs).Count) { $dsCurs } else { @($char.currencies) }
  foreach ($cur in $curSource) {
    if ([string]::IsNullOrEmpty($cur.name)) { continue }
    $pubCurs.Add([ordered]@{ name = [string]$cur.name })
  }
  $public.characters = @($public.characters) + @([ordered]@{
    id = $char.rosterId
    name = $char.displayName
    level = $char.level
    race = $char.race
    className = $char.className
    professions = @($char.professions | ForEach-Object { [ordered]@{ name = $_.name; current = $_.current; max = $_.max } })
    reputations = $pubReps.ToArray()
    currencies = $pubCurs.ToArray()
    collections = $counts
    completedQuestCount = $char.quests.completedCount
    totalKills = $char.kills.total
  })
}
Write-JsonFile $PublicPath $public
Write-Output "Public: $PublicPath ($($public.characters.Count) roster characters)"
