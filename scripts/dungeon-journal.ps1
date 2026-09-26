# Read the boss, loot, and quest tables built into the Forever Dungeon Journal addon.
# The data lives in the addon's Lua file, not in SavedVariables, so it refreshes when the addon updates.

. (Join-Path $PSScriptRoot "lua-saved.ps1")

$qualityNames = @("Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary")

function Get-JournalItem($entry, $hasSlot) {
  $list = @($entry)
  $quality = if ($hasSlot) { $list[3] } else { $list[2] }
  $item = [ordered]@{ id = $list[0]; name = [string]$list[1] }
  if ($hasSlot) { $item.slot = [string]$list[2] }
  $item.quality = if ($null -ne $quality -and $quality -lt $qualityNames.Count) { $qualityNames[[int]$quality] } else { $null }
  return [pscustomobject]$item
}

function Get-JournalItems($entries, $hasSlot) {
  $items = @()
  if ($null -eq $entries) { return $items }
  foreach ($entry in $entries) {
    if ($null -ne $entry) { $items += Get-JournalItem $entry $hasSlot }
  }
  return $items
}

function Get-JournalText($value) {
  if ($null -eq $value) { return $null }
  $text = ([string]$value) -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '' -replace '\s*\n\s*', ' · ' -replace '\s{2,}', ' '
  return $text.Trim()
}

function Read-DungeonJournal($addonsPath) {
  $folder = Join-Path $addonsPath "ForeverDungeonJournal"
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

  $version = $null
  $toc = Join-Path $folder "ForeverDungeonJournal.toc"
  if ((Test-Path $toc) -and ((Get-Content -Raw $toc) -match '(?m)^##\s*Version:\s*(.+)$')) { $version = $Matches[1].Trim() }
  return [ordered]@{
    source = "Forever Dungeon Journal"
    version = $version
    dungeons = @($dungeons)
  }
}
