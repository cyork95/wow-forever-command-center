# Scan the local WoW AddOns folder and refresh the command center data files.
# Usage: powershell -File scripts/scan-addons.ps1
# Path: copy scripts/addons.example.json to scripts/addons.local.json and set addonsPath.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "read-saves.ps1")
. (Join-Path $PSScriptRoot "screenshots.ps1")
$repo = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $PSScriptRoot "addons.local.json"
$catalogPath = Join-Path $repo "data\addon-catalog.json"
$charactersPath = Join-Path $repo "data\characters.json"
$statsPath = Join-Path $repo "data\stats.json"
$addonsOut = Join-Path $repo "data\addons.json"
$exportsDir = Join-Path $repo "data\exports"

function Write-JsonFile($path, $value) {
  $json = $value | ConvertTo-Json -Depth 8
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json + "`n", $utf8)
}

function Read-JsonFile($path) {
  Get-Content -Raw -Path $path | ConvertFrom-Json
}

function Normalize-Name($value) {
  if (-not $value) { return "" }
  $text = [string]$value
  $text = $text -replace '\|c[0-9a-fA-F]{8}', ''
  $text = $text -replace '\|r', ''
  $text = $text -replace '[^a-zA-Z0-9]+', ''
  return $text.ToLowerInvariant()
}

function Strip-Color($value) {
  if (-not $value) { return "" }
  $text = [string]$value
  $text = $text -replace '\|c[0-9a-fA-F]{8}', ''
  $text = $text -replace '\|r', ''
  return $text.Trim()
}

function Split-CsvField($value) {
  if (-not $value) { return @() }
  return @($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if (-not (Test-Path $configPath)) {
  Write-Error "Missing $configPath. Copy scripts/addons.example.json and set addonsPath to your Interface\AddOns folder."
}

$config = Read-JsonFile $configPath
$addonsPath = $config.addonsPath
if (-not $addonsPath -or -not (Test-Path $addonsPath)) {
  Write-Error "addonsPath is missing or not a folder: $addonsPath"
}

$interfaceDir = Split-Path -Parent $addonsPath
$gameRoot = Split-Path -Parent $interfaceDir
$wtfRoot = Join-Path $gameRoot "WTF"
$catalog = Read-JsonFile $catalogPath
$characters = @(Read-JsonFile $charactersPath | ForEach-Object { $_ })

$saveFiles = @()
if (Test-Path $wtfRoot) {
  $saveFiles = @(Get-ChildItem -Path (Join-Path $wtfRoot "Account") -Recurse -Filter "*.lua" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\SavedVariables\\' })
}

function Find-CatalogEntry($folder, $title) {
  $folderKey = Normalize-Name $folder
  $titleKey = Normalize-Name $title
  foreach ($prop in $catalog.PSObject.Properties) {
    $names = @($prop.Name) + @($prop.Value.match)
    foreach ($name in $names) {
      $key = Normalize-Name $name
      if ($key -and ($key -eq $folderKey -or $key -eq $titleKey)) {
        return $prop.Value
      }
    }
  }
  return $null
}

function Read-Toc($folderPath) {
  $folderName = Split-Path $folderPath -Leaf
  $candidates = @(Get-ChildItem -Path $folderPath -Filter "*.toc" -File -ErrorAction SilentlyContinue)
  if (-not $candidates) { return $null }
  $preferred = $candidates | Where-Object { $_.BaseName -eq $folderName } | Select-Object -First 1
  $toc = if ($preferred) { $preferred } else { $candidates | Select-Object -First 1 }
  $fields = @{}
  foreach ($line in Get-Content -Path $toc.FullName) {
    if ($line -match '^\s*##\s*([^:]+):\s*(.*)$') {
      $key = $Matches[1].Trim()
      if (-not $fields.ContainsKey($key)) { $fields[$key] = $Matches[2].Trim() }
    }
  }
  [pscustomobject]@{
    Folder = $folderName
    Title = Strip-Color $(if ($fields["Title"]) { $fields["Title"] } else { $folderName })
    Notes = Strip-Color $fields["Notes"]
    Version = $fields["Version"]
    Author = Strip-Color $fields["Author"]
    SavedVariables = @(Split-CsvField $fields["SavedVariables"])
    SavedVariablesPerCharacter = @(Split-CsvField $fields["SavedVariablesPerCharacter"])
  }
}

function Find-Save($names) {
  foreach ($name in $names) {
    $hit = $saveFiles | Where-Object { $_.BaseName -eq $name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($hit) { return $hit }
  }
  return $null
}

$runtime = @{}
$exportRoots = @(
  (Join-Path $repo "exports"),
  (Join-Path $repo "data\exports")
)
$dump = $null
foreach ($root in $exportRoots) {
  if (-not (Test-Path $root)) { continue }
  $found = Get-ChildItem -Path $root -Recurse -File -Include *.txt,*.json,*.lua -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
  foreach ($file in $found) {
    $head = Get-Content -Path $file.FullName -TotalCount 5 -ErrorAction SilentlyContinue
    $sample = Get-Content -Raw -Path $file.FullName -ErrorAction SilentlyContinue
    if ($sample -and $sample.Contains("AddOns Count:")) {
      $dump = $file
      break
    }
  }
  if ($dump) { break }
}

if ($dump) {
  $dumpText = Get-Content -Raw -Path $dump.FullName
  foreach ($line in ($dumpText -split "`r?`n")) {
    if ($line -match '^(.+?) - Enabled: (yes|no) - Loadable: \S+ - Loaded: (yes|no)(?: - Reason: .+?)? - Version: (.+)$') {
      $runtime[(Normalize-Name $Matches[1])] = @{
        enabled = ($Matches[2] -eq "yes")
        loaded = ($Matches[3] -eq "yes")
        version = $Matches[4].Trim()
      }
    }
  }
}

$addons = @()
$folders = Get-ChildItem -Path $addonsPath -Directory
foreach ($folder in $folders) {
  $toc = Read-Toc $folder.FullName
  if (-not $toc) { continue }
  $entry = Find-CatalogEntry $toc.Folder $toc.Title
  $saveNames = @($toc.Folder) + @($toc.SavedVariables) + @($toc.SavedVariablesPerCharacter)
  $save = Find-Save $saveNames
  $run = $runtime[(Normalize-Name $toc.Title)]
  if (-not $run) { $run = $runtime[(Normalize-Name $toc.Folder)] }
  $row = [ordered]@{
    folder = $toc.Folder
    title = $toc.Title
    version = $(if ($toc.Version) { $toc.Version } elseif ($run) { $run.version } else { $null })
    author = $(if ($toc.Author) { $toc.Author } else { $null })
    purpose = $(if ($entry) { $entry.purpose } elseif ($toc.Notes) { $toc.Notes } else { "No catalog entry yet." })
    feedsSite = $(if ($entry) { [bool]$entry.feedsSite } else { $false })
    uncataloged = $(-not $entry)
    collects = $(if ($entry -and $entry.collects) { @($entry.collects) } else { @() })
    savedVariables = @($toc.SavedVariables + $toc.SavedVariablesPerCharacter | Select-Object -Unique)
    saveOnDisk = [bool]$save
    saveModified = $(if ($save) { $save.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss") } else { $null })
    enabled = $(if ($run) { $run.enabled } else { $null })
    loaded = $(if ($run) { $run.loaded } else { $null })
  }
  $addons += [pscustomobject]$row
}

$addons = @($addons | Sort-Object title, folder)
$scannedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
Write-JsonFile $addonsOut ([ordered]@{
  scannedAt = $scannedAt
  count = $addons.Count
  addons = $addons
})
Write-Output "Wrote $($addons.Count) addons to data/addons.json"

function Unescape-LuaString($value) {
  $text = $value -replace '\\n', "`n" -replace '\\r', '' -replace '\\"', '"' -replace '\\t', "`t"
  return $text
}

function Get-ExportBodies($text) {
  $bodies = @()
  if ($text -match '"character"\s*:') { $bodies += $text }
  $pattern = '"((?:\\.|[^"\\])*(?:Character Stats:|Character:)(?:\\.|[^"\\])*)"'
  $stringMatches = [regex]::Matches($text, $pattern)
  foreach ($m in $stringMatches) {
    $body = Unescape-LuaString $m.Groups[1].Value
    if ($body -match 'Character:') { $bodies += $body }
  }
  if ($text -match '(?m)^Character Stats:' -or $text -match '(?m)^Character:') {
    $bodies += $text
  }
  return $bodies
}

function Parse-Gold($line) {
  if ($line -match '(\d+)\s*g\s*(\d+)\s*s\s*(\d+)\s*c') {
    return ([int]$Matches[1] * 10000) + ([int]$Matches[2] * 100) + [int]$Matches[3]
  }
  return $null
}

function Parse-TextExport($text, $when) {
  if ($text -notmatch '(?m)^Character:\s*(.+)$') { return $null }
  $rawName = $Matches[1].Trim()
  $known = $null
  foreach ($character in ($characters | Sort-Object { $_.name.Length } -Descending)) {
    if ($rawName.StartsWith($character.name, [System.StringComparison]::OrdinalIgnoreCase)) {
      $known = $character
      break
    }
  }
  $name = if ($known) { $known.name } else { ($rawName -split '-')[0].Trim() }
  $realm = $null
  if ($rawName.Length -gt $name.Length -and $rawName.Substring($name.Length, 1) -eq '-') {
    $realm = $rawName.Substring($name.Length + 1).Trim()
  }

  $level = $null
  if ($text -match '(?m)^Level:\s*(\d+)') { $level = [int]$Matches[1] }
  $zone = $null
  if ($text -match '(?m)^Zone:\s*(.+)$') { $zone = $Matches[1].Trim() }
  $subzone = $null
  if ($text -match '(?m)^Subzone:\s*(.+)$') { $subzone = $Matches[1].Trim() }
  $gold = $null
  if ($text -match '(?m)^Gold:\s*(.+)$') { $gold = Parse-Gold $Matches[1] }
  $health = $null
  if ($text -match '(?m)^Health:\s*(.+)$') {
    $healthRaw = $Matches[1].Trim()
    if ($healthRaw -match 'n/a/(\d+)') { $health = "$($Matches[1]) max" }
    elseif ($healthRaw -match '(\d+)\s*/\s*(\d+)') { $health = "$($Matches[2]) max" }
    else { $health = $healthRaw }
  }

  $stats = [ordered]@{}
  foreach ($pair in @(
    @('Strength', 'Strength'),
    @('Agility', 'Agility'),
    @('Stamina', 'Stamina'),
    @('Intellect', 'Intellect'),
    @('Spirit', 'Spirit'),
    @('Armor', 'Armor'),
    @('Attack Power', 'Attack Power')
  )) {
    $label = [regex]::Escape($pair[0])
    if ($text -match "(?m)^${label}:\s*(.+)$") { $stats[$pair[1]] = $Matches[1].Trim() }
  }
  if ($text -match '(?m)^Critical Strike:\s*.*?/\s*([0-9.]+%)') {
    $stats["Melee Crit"] = $Matches[1]
    $stats["Spell Crit"] = $Matches[1]
  }

  $professions = @()
  $profBlock = [regex]::Match($text, '(?s)== Professions ==\s*(.*?)(?:\r?\n== |\r?\nProfession Details:|\z)')
  $secBlock = [regex]::Match($text, '(?s)== Secondary Skills ==\s*(.*?)(?:\r?\n== |\r?\nProfession Details:|\z)')
  foreach ($block in @($profBlock, $secBlock)) {
    if (-not $block.Success) { continue }
    foreach ($line in ($block.Groups[1].Value -split "`r?`n")) {
      if ($line -match '^([A-Za-z][A-Za-z ]+?)\s+(\d+)/(\d+)\s*$') {
        $professions += [ordered]@{
          name = $Matches[1].Trim()
          current = [int]$Matches[2]
          max = [int]$Matches[3]
        }
      }
    }
  }

  $gear = @()
  $equip = [regex]::Match($text, '(?ms)^Equipment:\s*(.*?)(?=^Lockouts:|^AddOns:|^Progress:|\z)')
  if ($equip.Success) {
    $chunks = [regex]::Matches($equip.Groups[1].Value, '(?s)== ([^=\r\n]+) ==\s*(.*?)(?=\r?\n== |\z)')
    foreach ($chunk in $chunks) {
      $slot = $chunk.Groups[1].Value.Trim()
      $body = $chunk.Groups[2].Value
      if ($body -match '\[Empty\]') { continue }
      if ($body -notmatch '\[([^\]]+)\]') { continue }
      $item = $Matches[1].Trim()
      $quality = $null
      if ($body -match '(?m)^- Rarity:\s*(.+)$') { $quality = $Matches[1].Trim() }
      $ilvl = $null
      if ($body -match '(?m)^- Item Level:\s*(\d+)') { $ilvl = [int]$Matches[1] }
      $gear += [ordered]@{
        slot = $slot
        name = $item
        itemLevel = $ilvl
        quality = $quality
      }
    }
  }

  [ordered]@{
    character = $name
    exportedAt = $when
    addon = "CharacterExport Forever"
    realm = $realm
    level = $level
    zone = $zone
    subzone = $subzone
    goldCopper = $gold
    health = $health
    powerType = $null
    stats = $stats
    professions = $professions
    gear = $gear
    owned = @()
    matchedId = $(if ($known) { $known.id } else { $null })
  }
}

function Parse-JsonExport($text, $when) {
  try { $data = $text | ConvertFrom-Json } catch { return $null }
  if (-not $data.character) { return $null }
  $known = $characters | Where-Object { $_.name -eq $data.character } | Select-Object -First 1
  if (-not $data.exportedAt) { $data | Add-Member -NotePropertyName exportedAt -NotePropertyValue $when -Force }
  $data | Add-Member -NotePropertyName matchedId -NotePropertyValue $(if ($known) { $known.id } else { $null }) -Force
  return $data
}

function Get-RowField($row, $name) {
  if ($null -eq $row) { return $null }
  if ($row -is [System.Collections.IDictionary]) {
    if ($row.Contains($name)) { return $row[$name] }
    return $null
  }
  $prop = $row.PSObject.Properties[$name]
  if ($prop) { return $prop.Value }
  return $null
}

function Add-CarriedField($payload, $row, $existing, $name) {
  $value = Get-RowField $row $name
  if ($null -eq $value) { $value = Get-RowField $existing $name }
  if ($null -ne $value) { $payload[$name] = $value }
}

$sources = @()
$sources += @($saveFiles | Where-Object { $_.BaseName -match 'CharacterExport|CharExport' })
if (Test-Path $gameRoot) {
  $sources += @(Get-ChildItem -Path $gameRoot -File -Recurse -Depth 2 -Include *.txt,*.json -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\Interface\\' -and $_.Length -lt 5MB })
}
foreach ($root in $exportRoots) {
  if (-not (Test-Path $root)) { continue }
  $sources += @(Get-ChildItem -Path $root -Recurse -File -Include *.txt,*.json,*.lua -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -lt 5MB })
}

$parsed = @()
$seen = @{}
foreach ($source in ($sources | Sort-Object LastWriteTime -Descending)) {
  if (-not $source) { continue }
  $raw = Get-Content -Raw -Path $source.FullName -ErrorAction SilentlyContinue
  if (-not $raw) { continue }
  $when = $source.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
  $fileDate = $null
  if ($source.BaseName -match '(\d{4}-\d{2}-\d{2})') { $fileDate = $Matches[1] }
  elseif ($source.BaseName -match '(\d{1,2})_(\d{1,2})_(\d{2})$') {
    $fileDate = "20{0}-{1:D2}-{2:D2}" -f $Matches[3], [int]$Matches[1], [int]$Matches[2]
  }
  if ($fileDate -and -not $when.StartsWith($fileDate)) { $when = "${fileDate}T12:00:00" }
  foreach ($body in (Get-ExportBodies $raw)) {
    $row = $null
    if ($body.TrimStart().StartsWith("{") -or $body.TrimStart().StartsWith("[")) {
      $row = Parse-JsonExport $body $when
    }
    if (-not $row) { $row = Parse-TextExport $body $when }
    if (-not $row) { continue }
    $stamp = "$($row.character)|$($row.exportedAt)"
    if ($seen.ContainsKey($stamp)) { continue }
    $seen[$stamp] = $true
    $parsed += $row
  }
}

if (-not $parsed.Count) {
  Write-Output "No CharacterExport dump found. Addon saves still update the sheet."
}

$stats = Read-JsonFile $statsPath
if (-not $stats.characters) {
  $stats | Add-Member -NotePropertyName characters -NotePropertyValue ([pscustomobject]@{}) -Force
}
$merged = 0
$unmatched = @()
$kept = @{}
foreach ($row in ($parsed | Sort-Object { [datetime]$_.exportedAt } -Descending)) {
  $key = if ($row.matchedId) { [string]$row.matchedId } else { "name:" + [string]$row.character }
  if (-not $kept.ContainsKey($key)) { $kept[$key] = $row }
}
foreach ($row in $kept.Values) {
  if (-not $row.matchedId) {
    $unmatched += $row.character
    continue
  }
  $date = ([datetime]$row.exportedAt).ToString("yyyy-MM-dd")
  $slug = ($row.character.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
  $exportPath = Join-Path $exportsDir "$slug-$date.json"
  $existing = $stats.characters.PSObject.Properties[$row.matchedId]
  $existingRecord = if ($existing) { $existing.Value } else { $null }
  $payload = [ordered]@{
    character = $row.character
    exportedAt = $row.exportedAt
    addon = "CharacterExport Forever"
    realm = $row.realm
    level = $row.level
    zone = $row.zone
    subzone = $row.subzone
    goldCopper = $row.goldCopper
    health = $row.health
    powerType = $row.powerType
    stats = $row.stats
    professions = @($row.professions)
    gear = @($row.gear)
    owned = @($row.owned)
  }
  $carried = @("power", "playedSeconds", "statistics")
  foreach ($field in $carried) { Add-CarriedField $payload $row $null $field }
  Write-JsonFile $exportPath $payload
  foreach ($field in $carried) {
    if (-not $payload.Contains($field)) { Add-CarriedField $payload $null $existingRecord $field }
  }
  $stats.characters | Add-Member -NotePropertyName $row.matchedId -NotePropertyValue ([pscustomobject]$payload) -Force
  $merged++
  Write-Output "Merged $($row.character) into data/stats.json ($($row.matchedId))"
}

function Merge-StatRows($statistics, $group, $rows) {
  $groups = [ordered]@{}
  if ($statistics -is [System.Collections.IDictionary]) {
    foreach ($k in $statistics.Keys) { $groups[$k] = @($statistics[$k]) }
  } elseif ($statistics -is [System.Collections.IList]) {
    if ($statistics.Count) { $groups["Statistics"] = @($statistics) }
  } elseif ($statistics) {
    foreach ($p in $statistics.PSObject.Properties) { $groups[$p.Name] = @($p.Value) }
  }
  $names = @($rows | ForEach-Object { $_.name })
  $kept = @($groups[$group] | Where-Object { $_ -and $names -notcontains $_.name })
  $groups[$group] = @($rows) + $kept
  return $groups
}

function Apply-Snapshot($record, $snap, $character) {
  $rec = [ordered]@{}
  if ($record) { foreach ($p in $record.PSObject.Properties) { $rec[$p.Name] = $p.Value } }
  if (-not $rec.Contains("character")) { $rec["character"] = $character.name }
  $exportedAt = $rec["exportedAt"]

  $best = $exportedAt
  foreach ($source in @($snap.nova, $snap.att)) {
    if (-not $source -or $null -eq $source.level) { continue }
    if (-not $best -or $source.at -gt $best) {
      $rec["level"] = $source.level
      $best = $source.at
    }
  }
  if ($snap.nova -and $null -ne $snap.nova.goldCopper -and (-not $exportedAt -or $snap.nova.at -gt $exportedAt)) {
    $rec["goldCopper"] = $snap.nova.goldCopper
  }
  if ($snap.att -and $snap.att.playedSeconds) { $rec["playedSeconds"] = $snap.att.playedSeconds }

  if ($snap.skillLevels) {
    $profs = @()
    $seen = @{}
    foreach ($p in @($rec["professions"])) {
      if (-not $p) { continue }
      $current = [int]$p.current
      if ($snap.skillLevels.Contains($p.name) -and $snap.skillLevels[$p.name] -gt $current) { $current = $snap.skillLevels[$p.name] }
      $profs += [ordered]@{ name = $p.name; current = $current; max = $p.max }
      $seen[$p.name] = $true
    }
    foreach ($name in ($snap.skillLevels.Keys | Sort-Object)) {
      if (-not $seen.ContainsKey($name)) { $profs += [ordered]@{ name = $name; current = $snap.skillLevels[$name]; max = $null } }
    }
    $rec["professions"] = $profs
  }
  if ($snap.recipes) { $rec["recipes"] = $snap.recipes }
  if ($snap.items) { $rec["items"] = $snap.items }

  if ($snap.att) {
    $rec["collections"] = [ordered]@{
      Mounts = $snap.att.mounts
      Pets = $snap.att.pets
      Toys = $snap.att.toys
      Titles = $snap.att.titles
      Achievements = $snap.att.achievements
    }
    $rows = @(
      [ordered]@{ name = "Deaths"; value = [string]$snap.att.deaths },
      [ordered]@{ name = "Quests completed"; value = [string]$snap.att.quests },
      [ordered]@{ name = "Areas explored"; value = [string]$snap.att.exploration }
    )
    if ($snap.nova) { $rows += [ordered]@{ name = "Instance lockouts"; value = [string]$snap.nova.lockouts } }
    $rec["statistics"] = Merge-StatRows $rec["statistics"] "Character" $rows
  }
  if ($snap.kills) {
    $huntKills = [ordered]@{}
    foreach ($mob in $snap.kills.byMob) {
      if ($mob.name -and $huntMobs.ContainsKey(([string]$mob.name).ToLowerInvariant())) { $huntKills[[string]$mob.name] = $mob.kills }
    }
    $rec["huntKills"] = $huntKills
    $rec["looted"] = @($snap.kills.looted | Where-Object {
      $huntNames.ContainsKey($_.ToLowerInvariant()) -or $huntNames.ContainsKey(($_ -replace $recipePrefix, '').ToLowerInvariant())
    })
    $rows = @(
      [ordered]@{ name = "Total kills"; value = [string]$snap.kills.total },
      [ordered]@{ name = "Creature types"; value = [string]$snap.kills.creatures }
    )
    foreach ($mob in $snap.kills.top) { $rows += [ordered]@{ name = $mob.name; value = [string]$mob.kills } }
    $rec["statistics"] = Merge-StatRows $rec["statistics"] "Kills" $rows
  }

  $sources = [ordered]@{}
  if ($exportedAt) { $sources["CharacterExport"] = $exportedAt }
  foreach ($k in $snap.sources.Keys) { $sources[$k] = $snap.sources[$k] }
  $rec["sources"] = $sources
  return [pscustomobject]$rec
}

$recipePrefix = '^(Recipe|Plans|Pattern|Formula|Schematic|Manual|Design|Technique):\s*'
$huntNames = @{}
$huntMobs = @{}
foreach ($hunt in @(Read-JsonFile (Join-Path $repo "data\checklist.json") | ForEach-Object { $_ })) {
  foreach ($entry in @($hunt) + @($hunt.parts | Where-Object { $_ })) {
    if ($entry.name) { $huntNames[([string]$entry.name).ToLowerInvariant()] = $true }
    foreach ($mob in @($entry.mobs | Where-Object { $_ })) { $huntMobs[([string]$mob).ToLowerInvariant()] = $true }
  }
}

$snapshots = Get-SaveSnapshots $wtfRoot $characters
$applied = 0
foreach ($character in $characters) {
  $snap = $snapshots[$character.id]
  if (-not $snap -or -not $snap.sources.Count) { continue }
  $existing = $stats.characters.PSObject.Properties[$character.id]
  $record = Apply-Snapshot $(if ($existing) { $existing.Value } else { $null }) $snap $character
  $stats.characters | Add-Member -NotePropertyName $character.id -NotePropertyValue $record -Force
  $applied++
  Write-Output "Updated $($character.name) from $(@($snap.sources.Keys) -join ', ')"
}

if ($merged -gt 0 -or $applied -gt 0) {
  $stats.updated = (Get-Date).ToString("yyyy-MM-dd")
  Write-JsonFile $statsPath $stats
} else {
  Write-Output "No export or addon save matched data/characters.json. Left data/stats.json unchanged."
}

$unmatched | Select-Object -Unique | ForEach-Object {
  Write-Output "Skipped unmatched character: $_"
}

Update-Screenshots $gameRoot $repo $characters
