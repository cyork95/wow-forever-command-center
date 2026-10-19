# Read the boss, loot, and quest tables built into the Forever Dungeon Journal addon.
# The data lives in the addon's Lua file, not in SavedVariables, so it refreshes when the addon updates.

. (Join-Path $PSScriptRoot "lua-saved.ps1")

$qualityNames = @("Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary")

function Get-JournalItem($entry, $hasSlot, $unverified) {
  $list = @($entry)
  $quality = if ($hasSlot) { $list[3] } else { $list[2] }
  $item = [ordered]@{ id = $list[0]; name = [string]$list[1] }
  if ($hasSlot) { $item.slot = [string]$list[2] }
  $item.quality = if ($null -ne $quality -and $quality -lt $qualityNames.Count) { $qualityNames[[int]$quality] } else { $null }
  # The addon marks some item IDs "-- ID unverified" in its own source.
  # That flag is preserved, never presented as a confirmed drop.
  if ($unverified -and $unverified.ContainsKey([int]$list[0])) { $item.verified = $false }
  return [pscustomobject]$item
}

function Get-JournalItems($entries, $hasSlot, $unverified) {
  $items = @()
  if ($null -eq $entries) { return $items }
  foreach ($entry in $entries) {
    if ($null -ne $entry) { $items += Get-JournalItem $entry $hasSlot $unverified }
  }
  return $items
}

function Get-JournalText($value) {
  if ($null -eq $value) { return $null }
  $text = ([string]$value) -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '' -replace '\s*\n\s*', ' · ' -replace '\s{2,}', ' '
  return $text.Trim()
}

function Get-JournalVersion($folder) {
  $toc = Join-Path $folder "ForeverDungeonJournal.toc"
  if ((Test-Path $toc) -and ((Get-Content -Raw $toc) -match '(?m)^##\s*Version:\s*(.+)$')) { return $Matches[1].Trim() }
  return $null
}

function Read-DungeonJournal($addonsPath) {
  $folder = Join-Path $addonsPath "ForeverDungeonJournal"
  $dataFile = Join-Path $folder "Data\Dungeons.lua"
  if (Test-Path $dataFile) { return Read-FDJDataFile $dataFile (Get-JournalVersion $folder) }
  return Read-FDJLegacyFile $folder
}

function Read-FDJLegacyFile($folder) {
  $luaPath = Join-Path $folder "ForeverDungeonJournal.lua"
  if (-not (Test-Path $luaPath)) { return $null }
  $text = [System.IO.File]::ReadAllText($luaPath, [System.Text.Encoding]::UTF8)
  $start = $text.IndexOf("local DB = {")
  $end = $text.IndexOf("local ORDER = {")
  if ($start -lt 0 -or $end -lt $start) { return $null }

  $script:journalExtra = 0
  $body = [regex]::Replace($text.Substring($start, $end - $start), '(?m)^DB\[("[^"]+")\] = \{', {
    param($m)
    $script:journalExtra++
    "DB_$($script:journalExtra) = { __name = $($m.Groups[1].Value),"
  })
  $body = $body -replace '^local DB = \{', 'DB = {'
  $parsed = [LuaSaved]::Parse($body)
  $all = [ordered]@{}
  if ($parsed["DB"]) { foreach ($key in $parsed["DB"].Keys) { $all[$key] = $parsed["DB"][$key] } }
  foreach ($key in $parsed.Keys) {
    if ($key -ne "DB" -and $parsed[$key] -is [System.Collections.IDictionary] -and $parsed[$key]["__name"]) {
      $all[$parsed[$key]["__name"]] = $parsed[$key]
    }
  }

  $order = @()
  if ($text.Substring($end) -match '^local ORDER = \{([^}]*)\}') {
    $order = @([regex]::Matches($Matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  }
  $names = @($order | Where-Object { $all.Contains($_) }) + @($all.Keys | Where-Object { $order -notcontains $_ })

  $dungeons = foreach ($name in $names) {
    $d = $all[$name]
    $bosses = foreach ($boss in $(if ($d["bosses"]) { $d["bosses"] } else { @() })) {
      [pscustomobject][ordered]@{
        name = [string]$boss["name"]
        aliases = @($boss["aliases"] | Where-Object { $_ -and $_ -ne $boss["name"] })
        note = Get-JournalText $boss["description"]
        loot = @(Get-JournalItems $boss["loot"] $true)
      }
    }
    $quests = foreach ($quest in $(if ($d["quests"]) { $d["quests"] } else { @() })) {
      $starter = if ($quest["startItem"]) { @($quest["startItem"]) } elseif ($quest["noteItem"]) { @($quest["noteItem"]) } else { $null }
      [pscustomobject][ordered]@{
        name = [string]$quest["name"]
        level = $quest["level"]
        requires = $quest["requires"]
        faction = $(if ($quest["faction"]) { [string]$quest["faction"] } else { "Both" })
        classOnly = $(if ($quest["classOnly"]) { [string]$quest["classOnly"] } else { $null })
        pickup = Get-JournalText $quest["pickup"]
        objective = Get-JournalText $quest["objective"]
        turnin = Get-JournalText $quest["turnin"]
        rewardChoice = [bool]$quest["rewardChoice"]
        rewardItems = @(Get-JournalItems $quest["rewardItems"] $false)
        rewards = Get-JournalText $quest["rewardSummary"]
        note = Get-JournalText $quest["note"]
        noteItems = @(Get-JournalItems $quest["noteRewardItems"] $false)
        startItem = $(if ($starter) { [pscustomobject][ordered]@{ name = Get-JournalText $starter[1]; from = Get-JournalText $starter[3] } } else { $null })
      }
    }
    [pscustomobject][ordered]@{
      name = $name
      level = [string]$d["level"]
      location = Get-JournalText $d["location"]
      description = Get-JournalText $d["description"]
      bosses = @($bosses)
      quests = @($quests)
    }
  }

  return [ordered]@{
    source = "Forever Dungeon Journal"
    version = (Get-JournalVersion $folder)
    dungeons = @($dungeons)
  }
}

# New addon layout (Data/Dungeons.lua): dungeons live in FDJ.DB["Name"],
# ordered by FDJ.ORDER. Loot lines the addon itself marks "-- ID unverified"
# keep that flag in the site data instead of looking confirmed.
function Read-FDJDataFile($dataFile, $version) {
  $raw = [System.IO.File]::ReadAllText($dataFile, [System.Text.Encoding]::UTF8)
  $unverified = @{}
  foreach ($line in ($raw -split "`n")) {
    if ($line -match '\{\s*(\d+),') {
      $id = [int]$Matches[1]
      $dash = $line.IndexOf('--')
      if ($dash -ge 0 -and $line.Substring($dash) -match '(?i)unverified') { $unverified[$id] = $true }
    }
  }
  $script:fdjExtra = 0
  $expand = {
    param($m)
    $script:fdjExtra++
    "DB_$($script:fdjExtra) = { __name = `"$($m.Groups[1].Value)`","
  }
  $body = [regex]::Replace($raw, '(?m)^FDJ\.DB\["([^"]+)"\] = \{', $expand)
  $body = [regex]::Replace($body, '(?m)^DB\["([^"]+)"\] = \{', $expand)
  $body = [regex]::Replace($body, 'FDJ\.DB = \{', 'DBROOT = {')
  $body = [regex]::Replace($body, 'FDJ\.ORDER = \{', 'ORDERLIST = {')
  $parsed = [LuaSaved]::Parse($body)
  $all = [ordered]@{}
  if ($parsed["DBROOT"] -is [System.Collections.IDictionary]) {
    foreach ($key in @($parsed["DBROOT"].Keys)) { $all[[string]$key] = $parsed["DBROOT"][$key] }
  }
  foreach ($key in $parsed.Keys) {
    if ($key -ne "ORDERLIST" -and $key -ne "DBROOT" -and $parsed[$key] -is [System.Collections.IDictionary] -and $parsed[$key]["__name"]) {
      $all[$parsed[$key]["__name"]] = $parsed[$key]
    }
  }
  $order = @($parsed["ORDERLIST"])
  $names = @($order | Where-Object { $all.Contains($_) }) + @($all.Keys | Where-Object { $order -notcontains $_ })
  $dungeons = foreach ($name in $names) {
    $d = $all[$name]
    $bosses = foreach ($boss in $(if ($d["bosses"]) { $d["bosses"] } else { @() })) {
      [pscustomobject][ordered]@{
        name = [string]$boss["name"]
        npcId = $boss["npcID"]
        aliases = @($boss["aliases"] | Where-Object { $_ -and $_ -ne $boss["name"] })
        note = Get-JournalText $boss["description"]
        loot = @(Get-JournalItems $boss["loot"] $true $unverified)
      }
    }
    $quests = foreach ($quest in $(if ($d["quests"]) { $d["quests"] } else { @() })) {
      $starter = if ($quest["startItem"]) { @($quest["startItem"]) } elseif ($quest["noteItem"]) { @($quest["noteItem"]) } else { $null }
      [pscustomobject][ordered]@{
        name = [string]$quest["name"]
        level = $quest["level"]
        requires = $quest["requires"]
        faction = $(if ($quest["faction"]) { [string]$quest["faction"] } else { "Both" })
        classOnly = $(if ($quest["classOnly"]) { [string]$quest["classOnly"] } else { $null })
        pickup = Get-JournalText $quest["pickup"]
        objective = Get-JournalText $quest["objective"]
        turnin = Get-JournalText $quest["turnin"]
        rewardChoice = [bool]$quest["rewardChoice"]
        rewardItems = @(Get-JournalItems $quest["rewardItems"] $false $unverified)
        rewards = Get-JournalText $quest["rewardSummary"]
        note = Get-JournalText $quest["note"]
        noteItems = @(Get-JournalItems $quest["noteRewardItems"] $false $unverified)
        startItem = $(if ($starter) { [pscustomobject][ordered]@{ name = Get-JournalText $starter[1]; from = Get-JournalText $starter[3] } } else { $null })
      }
    }
    [pscustomobject][ordered]@{
      name = $name
      level = [string]$d["level"]
      location = Get-JournalText $d["location"]
      description = Get-JournalText $d["description"]
      bosses = @($bosses)
      quests = @($quests)
    }
  }
  return [ordered]@{
    source = "Forever Dungeon Journal"
    version = $version
    dungeons = @($dungeons)
  }
}
