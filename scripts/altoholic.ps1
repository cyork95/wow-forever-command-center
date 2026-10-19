# Read Altoholic's DataStore saves into data/altoholic.json.
# DataStore keeps one row per character: level, gold, gear, bags, stats, quests,
# professions, reputation, currencies, and mail.

function Get-LuaField($table, $name) {
  if ($table -isnot [System.Collections.IDictionary]) { return $null }
  if ($table.ContainsKey([string]$name)) { return ,$table[[string]$name] }
  return $null
}

function Get-LuaById($table, $id) {
  if ($null -eq $table) { return $null }
  $key = [string]$id
  if ($table -is [System.Collections.IDictionary] -and $table.ContainsKey($key)) { return ,$table[$key] }
  if ($table -is [System.Collections.IList]) {
    $index = [int]$id - 1
    if ($index -ge 0 -and $index -lt $table.Count) { return ,$table[$index] }
  }
  return $null
}

function Get-Bits([int64]$value, [int]$shift, [int]$width) {
  $mask = ([int64]1 -shl $width) - 1
  return [int64](($value -shr $shift) -band $mask)
}

function Get-DataStoreAccount($wtfRoot) {
  $accountRoot = Join-Path $wtfRoot "Account"
  if (-not (Test-Path $accountRoot)) { return $null }
  $best = $null
  foreach ($dir in (Get-ChildItem -Path $accountRoot -Directory)) {
    $file = Join-Path $dir.FullName "SavedVariables\DataStore.lua"
    if (-not (Test-Path $file)) { continue }
    $length = (Get-Item $file).Length
    if (-not $best -or $length -gt $best.Length) {
      $best = Get-Item $file
    }
  }
  if ($best) { return $best.Directory.FullName }
  return $null
}

function Get-IndexedSlots($table) {
  $slots = @()
  if ($table -is [System.Collections.IList]) {
    for ($i = 0; $i -lt $table.Count; $i++) {
      if ($null -eq $table[$i]) { continue }
      $slots += [pscustomobject]@{ Slot = ($i + 1); Value = $table[$i] }
    }
  } elseif ($table -is [System.Collections.IDictionary]) {
    foreach ($key in $table.Keys) {
      $slot = 0
      if (-not [int]::TryParse([string]$key, [ref]$slot)) { continue }
      if ($null -eq $table[$key]) { continue }
      $slots += [pscustomobject]@{ Slot = $slot; Value = $table[$key] }
    }
  }
  return ,$slots
}

function Convert-ItemLink($link) {
  if ($link -isnot [string] -or $link.Length -eq 0) { return $null }
  if ($link -match '\|Hitem:(\d+).*\|h\[([^\]]+)\]') {
    return @{ id = [int]$Matches[1]; name = $Matches[2] }
  }
  if ($link -match '\[([^\]]+)\]') {
    return @{ id = 0; name = $Matches[1] }
  }
  return $null
}

function Convert-PackedCount($packed) {
  if ($null -eq $packed) { return 1 }
  $value = [int64]$packed
  $version = ($value -shr 13) -band 7
  $width = $(if ($version -eq 0) { 16 } else { 10 })
  $mask = ([int64]1 -shl $width) - 1
  $count = [int]($value -band $mask)
  if ($count -le 0) { return 1 }
  return $count
}

function Convert-BagItems($container) {
  $packed = @{}
  foreach ($slot in (Get-IndexedSlots (Get-LuaField $container "items"))) {
    $packed[$slot.Slot] = $slot.Value
  }
  $links = @{}
  foreach ($slot in (Get-IndexedSlots (Get-LuaField $container "links"))) {
    $links[$slot.Slot] = $slot.Value
  }
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($slot in ($packed.Keys + $links.Keys | Select-Object -Unique | Sort-Object)) {
    $parsed = Convert-ItemLink $links[$slot]
    if (-not $parsed) { continue }
    $items.Add([ordered]@{
      name = $parsed.name
      id = $parsed.id
      count = (Convert-PackedCount $packed[$slot])
    })
  }
  return ,$items
}

function Convert-CharacterBags($containers) {
  if ($containers -isnot [System.Collections.IDictionary]) {
    return ,(New-Object System.Collections.Generic.List[object])
  }
  $bags = New-Object System.Collections.Generic.List[object]
  foreach ($key in $containers.Keys) {
    $id = 0
    if (-not [int]::TryParse([string]$key, [ref]$id)) { continue }
    $container = $containers[$key]
    if ($container -isnot [System.Collections.IDictionary]) { continue }
    $items = Convert-BagItems $container
    if ($null -eq $items -or $items.Count -eq 0) { continue }
    $bagLink = Convert-ItemLink (Get-LuaField $container "link")
    $label = "Bag $id"
    if ($id -eq 0) { $label = "Backpack" }
    elseif ($id -eq -1) { $label = "Bank" }
    elseif ($id -lt 0) { $label = "Bank bag" }
    elseif ($bagLink) { $label = $bagLink.name }
    $bags.Add([ordered]@{ id = $id; name = $label; items = $items })
  }
  $sorted = New-Object System.Collections.Generic.List[object]
  foreach ($bag in ($bags | Sort-Object { if ($_.id -ge 0) { $_.id } else { 1000 + [Math]::Abs($_.id) } })) {
    $sorted.Add($bag)
  }
  return ,$sorted
}

function Convert-CharacterGear($inventory, $average) {
  $slots = @(
    "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
    "Finger", "Finger", "Trinket", "Trinket", "Back", "Main Hand", "Off Hand", "Ranged", "Tabard"
  )
  $gear = New-Object System.Collections.Generic.List[object]
  $index = 0
  if ($inventory -is [System.Collections.IList]) {
    foreach ($link in $inventory) {
      $index++
      $parsed = Convert-ItemLink $link
      if (-not $parsed) { continue }
      $slot = if ($index -le $slots.Count) { $slots[$index - 1] } else { "Slot $index" }
      $gear.Add([ordered]@{ slot = $slot; name = $parsed.name; id = $parsed.id })
    }
  }
  $itemLevel = $null
  if ($null -ne $average -and "$average" -ne "") {
    $itemLevel = [math]::Round([double]$average, 1)
  }
  return [ordered]@{ itemLevel = $itemLevel; slots = $gear }
}

function Convert-CharacterStats($row) {
  if ($row -isnot [System.Collections.IDictionary]) { return $null }
  $base = @([string](Get-LuaField $row "Base") -split "\|")
  $melee = @([string](Get-LuaField $row "Melee") -split "\|")
  $spell = @([string](Get-LuaField $row "Spell") -split "\|")
  $power = @([string](Get-LuaField $row "MaxPower") -split "\|")
  $powerNames = @{ "0" = "Mana"; "1" = "Rage"; "2" = "Focus"; "3" = "Energy" }
  $powerType = $powerNames[[string]$power[0]]
  if (-not $powerType) { $powerType = "Power" }
  return [ordered]@{
    health = Get-LuaField $row "HealthMax"
    power = $(if ($power.Count -gt 1) { $power[1] } else { $null })
    powerType = $powerType
    strength = $(if ($base.Count -gt 0) { $base[0] } else { $null })
    agility = $(if ($base.Count -gt 1) { $base[1] } else { $null })
    stamina = $(if ($base.Count -gt 2) { $base[2] } else { $null })
    intellect = $(if ($base.Count -gt 3) { $base[3] } else { $null })
    armor = $(if ($base.Count -gt 4) { $base[4] } else { $null })
    melee = $(if ($melee.Count -gt 0) { $melee[0] } else { $null })
    attackPower = $(if ($melee.Count -gt 2) { $melee[2] } else { $null })
    spellDamage = $(if ($spell.Count -gt 0) { $spell[0] } else { $null })
    spellHealing = $(if ($spell.Count -gt 1) { $spell[1] } else { $null })
    spellCrit = $(if ($spell.Count -gt 3) { $spell[3] } else { $null })
  }
}

function Convert-CharacterQuests($row, $names) {
  if ($row -isnot [System.Collections.IDictionary]) { return @() }
  $headers = @(Get-LuaRows (Get-LuaField $row "QuestHeaders"))
  $groups = @{}
  $order = New-Object System.Collections.Generic.List[string]
  foreach ($packed in (Get-LuaRows (Get-LuaField $row "Quests"))) {
    $value = [int64]$packed
    $headerIndex = [int](($value -shr 1) -band 31)
    $questId = [int](($value -shr 6) -band 262143)
    if ($questId -le 0) { continue }
    $zone = "Quest log"
    if ($headerIndex -gt 0 -and $headerIndex -le $headers.Count) { $zone = [string]$headers[$headerIndex - 1] }
    if (-not $groups.ContainsKey($zone)) {
      $groups[$zone] = New-Object System.Collections.Generic.List[object]
      $order.Add($zone)
    }
    $title = $null
    if ($names -and $names.ContainsKey([string]$questId)) { $title = [string]$names[[string]$questId] }
    if (-not $title) { $title = "Quest $questId" }
    $groups[$zone].Add([ordered]@{
      id = $questId
      name = $title
      ready = (($value -band 1) -eq 1)
    })
  }
  $result = New-Object System.Collections.Generic.List[object]
  foreach ($zone in $order) {
    $result.Add([ordered]@{ zone = $zone; quests = $groups[$zone] })
  }
  return ,$result
}

function Get-QuestNameMap($repo) {
  $map = @{}
  $path = Join-Path $repo "data\quests.json"
  if (-not (Test-Path $path)) { return $map }
  $data = Get-Content -Path $path -Raw | ConvertFrom-Json
  foreach ($quest in @($data.quests)) {
    if ($quest.id) { $map[[string]$quest.id] = [string]$quest.name }
  }
  return $map
}

function Convert-AltoholicCharacters($saved, $questNames) {
  $classes = @{
    1 = "Warrior"; 2 = "Paladin"; 3 = "Hunter"; 4 = "Rogue"; 5 = "Priest"; 6 = "Death Knight"
    7 = "Shaman"; 8 = "Mage"; 9 = "Warlock"; 11 = "Druid"
  }
  $races = @{
    1 = "Human"; 2 = "Orc"; 3 = "Dwarf"; 4 = "Night Elf"; 5 = "Undead"; 6 = "Tauren"; 7 = "Gnome"; 8 = "Troll"
    10 = "Blood Elf"; 11 = "Draenei"
  }
  $standings = @{
    1 = "Hated"; 2 = "Hostile"; 3 = "Unfriendly"; 4 = "Neutral"; 5 = "Friendly"; 6 = "Honored"; 7 = "Revered"; 8 = "Exalted"
  }
  $bottoms = @{ 1 = -42000; 2 = -6000; 3 = -3000; 4 = 0; 5 = 3000; 6 = 9000; 7 = 21000; 8 = 42000 }
  $tops = @{ 1 = -6000; 2 = -3000; 3 = 0; 4 = 3000; 5 = 9000; 6 = 21000; 7 = 42000; 8 = 42999 }
  $factions = @{
    21 = "Booty Bay"; 47 = "Ironforge"; 54 = "Gnomeregan"; 59 = "Thorium Brotherhood"; 68 = "Undercity"
    69 = "Darnassus"; 70 = "Syndicate"; 72 = "Stormwind"; 76 = "Orgrimmar"; 81 = "Thunder Bluff"
    87 = "Bloodsail Buccaneers"; 92 = "Gelkis Clan Centaur"; 93 = "Magram Clan Centaur"; 270 = "Zandalar Tribe"
    349 = "Ravenholdt"; 369 = "Gadgetzan"; 470 = "Ratchet"; 509 = "The League of Arathor"; 510 = "The Defilers"
    529 = "Argent Dawn"; 530 = "Darkspear Trolls"; 576 = "Timbermaw Hold"; 577 = "Everlook"
    589 = "Wintersaber Trainers"; 609 = "Cenarion Circle"; 729 = "Frostwolf Clan"; 730 = "Stormpike Guard"
    749 = "Hydraxian Waterlords"; 809 = "Shen'dralar"; 889 = "Warsong Outriders"; 890 = "Silverwing Sentinels"
    909 = "Darkmoon Faire"; 910 = "Brood of Nozdormu"; 469 = "Alliance"
  }

  $ids = Get-LuaField $saved "DataStore_CharacterIDs"
  $set = Get-LuaField $ids "Set"
  $infoTable = Get-LuaField $saved "DataStore_Characters_Info"
  $craftTable = Get-LuaField $saved "DataStore_Crafts_Characters"
  $repTable = Get-LuaField $saved "DataStore_Reputations_Characters"
  $currencyTable = Get-LuaField $saved "DataStore_Currencies_Characters"
  $currencyCatalog = Get-LuaField (Get-LuaField $saved "DataStore_Currencies_Catalog") "List"
  $mailTable = Get-LuaField $saved "DataStore_Mails_Characters"
  $containerTable = Get-LuaField $saved "DataStore_Containers_Characters"
  $inventoryTable = Get-LuaField $saved "DataStore_Inventory_Characters"
  $statsTable = Get-LuaField $saved "DataStore_Stats_Characters"
  $questTable = Get-LuaField $saved "DataStore_Quests_Characters"

  $characters = @()
  if ($set -isnot [System.Collections.IDictionary]) { return @() }

  foreach ($key in $set.Keys) {
    if ($key -eq "LastID") { continue }
    $id = $set[$key]
    $info = Get-LuaById $infoTable $id
    $name = Get-LuaField $info "name"
    if (-not $name) { continue }

    $parts = ([string]$key) -split '\.'
    $realm = ""
    if ($parts.Count -ge 3) { $realm = ($parts[1..($parts.Count - 2)] -join ".") }

    $base = [int64](Get-LuaField $info "BaseInfo")
    $level = [int](Get-Bits $base 0 7)
    $classId = [int](Get-Bits $base 7 4)
    $raceId = [int](Get-Bits $base 11 7)
    $resting = (Get-Bits $base 21 1) -eq 1

    $professions = @()
    $craft = Get-LuaById $craftTable $id
    $professionTable = Get-LuaField $craft "Professions"
    $rankRows = @(Get-LuaRows (Get-LuaField $craft "Ranks"))
    $profIndex = 0
    foreach ($prof in (Get-LuaRows $professionTable)) {
      $profName = $null
      $rank = 0
      $max = 0
      if ($prof -is [System.Collections.IDictionary]) {
        $profName = Get-LuaField $prof "Name"
        if (-not $profName) { $profName = Get-LuaField $prof "name" }
        $rank = [int](Get-LuaField $prof "Rank")
        $max = [int](Get-LuaField $prof "MaxRank")
      } elseif ($prof -is [string]) {
        $profName = $prof
      }
      if ($profIndex -lt $rankRows.Count) {
        $packed = [int64]$rankRows[$profIndex]
        $low = [int]($packed -band 65535)
        $high = [int](($packed -shr 16) -band 65535)
        if ($high -gt 0) {
          $rank = $low
          $max = $high
        }
      }
      $profIndex++
      if (-not $profName) { continue }
      if ($rank -le 0 -and $max -le 0) { continue }
      $professions += [ordered]@{ name = [string]$profName; rank = $rank; max = $max }
    }
    if ($professionTable -is [System.Collections.IDictionary] -and -not ($professionTable.ContainsKey("1") -or $professionTable.ContainsKey(1))) {
      foreach ($profName in $professionTable.Keys) {
        if ($profName -eq "LastID") { continue }
        $prof = $professionTable[$profName]
        if ($prof -isnot [System.Collections.IDictionary]) { continue }
        $rank = [int](Get-LuaField $prof "Rank")
        $max = [int](Get-LuaField $prof "MaxRank")
        if ($rank -le 0 -and $max -le 0) { continue }
        $professions += [ordered]@{ name = [string]$profName; rank = $rank; max = $max }
      }
    }

    $reputations = @()
    $rep = Get-LuaById $repTable $id
    $factionTable = Get-LuaField $rep "Factions"
    if ($factionTable -is [System.Collections.IDictionary]) {
      foreach ($factionId in $factionTable.Keys) {
        $packed = [int64]$factionTable[$factionId]
        $negative = (Get-Bits $packed 3 1) -eq 1
        $standingId = [int](Get-Bits $packed 4 4)
        $earned = [int64]($packed -shr 8)
        if ($negative) { $earned = -$earned }
        if ($standingId -le 0) { continue }
        $bottom = [int64]$bottoms[$standingId]
        $top = [int64]$tops[$standingId]
        $span = [Math]::Max(1, $top - $bottom)
        $progress = [int]([Math]::Max(0, [Math]::Min($span, $earned - $bottom)))
        $label = $standings[$standingId]
        if (-not $label) { $label = "Standing $standingId" }
        $factionName = $factions[[int]$factionId]
        if (-not $factionName) { $factionName = "Faction $factionId" }
        $reputations += [ordered]@{
          name = $factionName
          standing = $label
          progress = $progress
          next = [int]$span
        }
      }
    }

    $currencies = @()
    $currency = Get-LuaById $currencyTable $id
    foreach ($row in (Get-LuaRows (Get-LuaField $currency "Currencies"))) {
      $packed = [int64]$row
      $index = [int](Get-Bits $packed 8 10)
      $count = [int64]($packed -shr 18)
      if ($count -le 0) { continue }
      $currencyName = Get-LuaById $currencyCatalog $index
      if (-not $currencyName) { $currencyName = "Currency $index" }
      $currencies += [ordered]@{ name = [string]$currencyName; quantity = [int]$count }
    }

    $letters = @()
    $mail = Get-LuaById $mailTable $id
    foreach ($letter in (Get-LuaRows (Get-LuaField $mail "Mails"))) {
      if ($letter -isnot [System.Collections.IDictionary]) { continue }
      if ($letters.Count -ge 20) { break }
      $letters += [ordered]@{
        sender = Get-LuaField $letter "sender"
        subject = Get-LuaField $letter "subject"
        money = Get-LuaField $letter "money"
        daysLeft = Get-LuaField $letter "daysLeft"
      }
    }

    $containers = Get-LuaById $containerTable $id
    $inventory = Get-LuaById $inventoryTable $id
    $stats = Get-LuaById $statsTable $id
    $quests = Get-LuaById $questTable $id
    $gear = Convert-CharacterGear (Get-LuaField $inventory "Inventory") (Get-LuaField $inventory "averageItemLvl")

    $characters += [ordered]@{
      name = [string]$name
      realm = $realm
      level = $level
      class = $(if ($classes.ContainsKey($classId)) { $classes[$classId] } else { "" })
      race = $(if ($races.ContainsKey($raceId)) { $races[$raceId] } else { "" })
      zone = Get-LuaField $info "zone"
      subZone = Get-LuaField $info "subZone"
      gold = [int64](Get-LuaField $info "money")
      rested = $resting
      xp = Get-LuaField $info "XP"
      maxXp = Get-LuaField $info "maxXP"
      played = Get-LuaField $info "played"
      lastUpdate = Get-LuaField $info "lastUpdate"
      itemLevel = $gear.itemLevel
      gear = $gear.slots
      bags = (Convert-CharacterBags (Get-LuaField $containers "Containers"))
      stats = (Convert-CharacterStats $stats)
      quests = (Convert-CharacterQuests $quests $questNames)
      professions = @($professions | Sort-Object name)
      reputations = @($reputations | Sort-Object { $_.standing }, name)
      currencies = @($currencies | Sort-Object name)
      mail = @($letters)
    }
  }

  return @($characters | Sort-Object name)
}

function Update-Altoholic($wtfRoot, $repo) {
  . (Join-Path $PSScriptRoot "lua-saved.ps1")
  . (Join-Path $PSScriptRoot "ledger.ps1")

  $folder = Get-DataStoreAccount $wtfRoot
  $saved = @{}
  $updated = $null
  if ($folder) {
    foreach ($name in @(
      "DataStore", "DataStore_Characters", "DataStore_Crafts", "DataStore_Reputations",
      "DataStore_Currencies", "DataStore_Mails", "DataStore_Containers", "DataStore_Inventory",
      "DataStore_Stats", "DataStore_Quests"
    )) {
      $path = Join-Path $folder "$name.lua"
      if (-not (Test-Path $path)) { continue }
      $parsed = Read-LuaSaved $path
      if ($parsed -is [System.Collections.IDictionary]) {
        foreach ($key in $parsed.Keys) { $saved[$key] = $parsed[$key] }
      }
      $stamp = (Get-Item $path).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
      if (-not $updated -or $stamp -gt $updated) { $updated = $stamp }
    }
  }

  $payload = [ordered]@{
    updated = $updated
    source = "Altoholic"
    characters = @(Convert-AltoholicCharacters $saved (Get-QuestNameMap $repo))
  }
  $path = Join-Path $repo "data\altoholic.json"
  $json = $payload | ConvertTo-Json -Depth 8
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json + "`n", $utf8)
  Write-Output "Altoholic: $($payload.characters.Count) characters"
}
