# Build the profession craft list from Profession Master's Forever database and its account save.
# Crafts, reagents, skill ranges, trainers, and recipe sources ship inside the addon; names come from the save.

. (Join-Path $PSScriptRoot "lua-saved.ps1")

$craftQualities = @("Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary")

function Read-PmModel($path, $variable) {
  if (-not (Test-Path $path)) { return $null }
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $marker = "local $variable = "
  $start = $text.IndexOf($marker)
  if ($start -lt 0) { return $null }
  $end = $text.IndexOf("`n}", $start)
  if ($end -lt 0) { return $null }
  $body = "X = " + $text.Substring($start + $marker.Length, $end + 2 - $start - $marker.Length)
  return [LuaSaved]::Parse($body)["X"]
}

function Get-PmLinkParts($link) {
  if ([string]$link -match 'item:(\d+)[^\[]*\|h\[([^\]]+)\]') {
    $parts = @{ id = $Matches[1]; name = $Matches[2]; quality = $null }
    if ([string]$link -match '\|cnIQ(\d)') { $parts.quality = [int]$Matches[1] }
    return $parts
  }
  return $null
}

function Get-PmZone($zones, $id) {
  if ($null -eq $id -or -not $zones) { return $null }
  return $zones[[string]$id]
}

function Get-PmNpc($npcs, $zones, $row) {
  $list = @($row)
  $name = if ($npcs) { $npcs[[string]$list[0]] } else { $null }
  if (-not $name) { return $null }
  $zone = if ($list.Count -gt 1) { Get-PmZone $zones $list[1] } else { $null }
  if ($zone) { return "$name ($zone)" }
  return $name
}

function Test-PmSide($side, $faction) {
  return (-not $side) -or ($side -eq $faction.Substring(0, 1))
}

function Get-RecipeSources($source, $npcs, $zones, $quests, $faction) {
  $out = @()
  if (-not $source) { return $out }
  $sold = @()
  foreach ($row in @($source["vendors"])) {
    if ($null -eq $row -or -not (Test-PmSide ([object[]]$row)[2] $faction)) { continue }
    $npc = Get-PmNpc $npcs $zones $row
    if ($npc -and $sold -notcontains $npc) { $sold += $npc }
  }
  if ($sold.Count) { $out += "Sold by " + (($sold | Select-Object -First 3) -join ", ") }
  $questCount = 0
  foreach ($row in @($source["quests"])) {
    if ($null -eq $row -or $questCount -ge 2) { continue }
    $list = [object[]]$row
    if (-not (Test-PmSide $list[3] $faction)) { continue }
    $title = if ($quests) { $quests[[string]$list[0]] } else { $null }
    $zone = Get-PmZone $zones $list[2]
    if ($title) {
      $out += "Quest: $title" + $(if ($zone) { " ($zone)" } else { "" })
      $questCount++
    }
  }
  if ($source["worldDrop"]) {
    $out += "World drop"
    return $out
  }
  $drops = @()
  foreach ($row in @($source["drops"])) {
    if ($null -eq $row) { continue }
    $npc = Get-PmNpc $npcs $zones $row
    if ($npc -and $drops -notcontains $npc) { $drops += $npc }
  }
  if ($drops.Count) {
    $more = if ($drops.Count -gt 3) { " and $($drops.Count - 3) more" } else { "" }
    $out += "Drops from " + (($drops | Select-Object -First 3) -join ", ") + $more
  }
  return $out
}

function Read-ProfessionCrafts($addonsPath, $wtfRoot, $professionNames, $faction) {
  $models = Join-Path $addonsPath "ProfessionMaster\models"
  $skills = Read-PmModel (Join-Path $models "skills\forever.lua") "foreverSkills"
  if (-not $skills) { return $null }
  $skillSources = Read-PmModel (Join-Path $models "skill-sources\forever.lua") "foreverSkillSources"
  $recipeSources = Read-PmModel (Join-Path $models "recipe-sources\forever.lua") "foreverSources"
  $npcs = Read-PmModel (Join-Path $models "npc-names\forever.lua") "npcNames"
  $zones = Read-PmModel (Join-Path $models "zone-names\forever.lua") "zoneNames"
  $quests = Read-PmModel (Join-Path $models "quest-names\forever.lua") "questNames"

  $commentNames = @{}
  $sourcePath = Join-Path $models "skill-sources\forever.lua"
  if (Test-Path $sourcePath) {
    foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($sourcePath), '(?m)^\s*\[(\d+)\] = \{[^\n]*\},\s*--\s*(.+?)\s*$')) {
      $commentNames[$m.Groups[1].Value] = $m.Groups[2].Value
    }
  }

  $skillInfo = @{}
  $items = @{}
  foreach ($save in @(Get-ChildItem -Path (Join-Path $wtfRoot "Account") -Filter "ProfessionMaster.lua" -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.Directory.Parent.Parent.Name -eq "Account" })) {
    $pm = Read-LuaSaved $save.FullName
    $pmSkills = $pm["PM_Skills"]
    if ($pmSkills -is [System.Collections.IDictionary]) {
      foreach ($id in $pmSkills.Keys) {
        $row = $pmSkills[$id]
        $link = Get-PmLinkParts $row["itemLink"]
        $skillInfo[[string]$id] = @{ name = $row["name"]; quality = $(if ($link) { $link.quality } else { $null }); slot = $row["equipLoc"] }
        if ($link) { $items[$link.id] = $link.name }
      }
    }
    $pmRecipes = $pm["PM_Recipes"]
    if ($pmRecipes -is [System.Collections.IDictionary]) {
      foreach ($row in $pmRecipes.Values) {
        $link = Get-PmLinkParts $row["itemLink"]
        if ($link) { $items[$link.id] = $link.name }
      }
    }
  }
  $synPath = Get-ChildItem -Path (Join-Path $wtfRoot "Account") -Filter "Syndicator.lua" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Parent.Parent.Name -eq "Account" } | Select-Object -First 1
  if ($synPath) {
    foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($synPath.FullName), 'item:(\d+)[^\[]*\|h\[([^\]]+)\]')) {
      $items[$m.Groups[1].Value] = $m.Groups[2].Value
    }
  }

  $groups = if ($skillSources) { $skillSources["groups"] } else { $null }
  $trainerNpcs = if ($skillSources) { $skillSources["npcs"] } else { $null }
  $sourceRows = if ($skillSources) { $skillSources["skills"] } else { $null }

  $byProfession = [ordered]@{}
  $usedItems = @{}
  foreach ($id in ($skills.Keys | Sort-Object { [long]$_ })) {
    $row = $skills[$id]
    $profName = $professionNames[[string]$row["p"]]
    if (-not $profName) { continue }
    $info = $skillInfo[[string]$id]
    $name = if ($info -and $info.name) { $info.name } elseif ($commentNames[[string]$id]) { $commentNames[[string]$id] } elseif ($row["itemId"] -and $items[[string]$row["itemId"]]) { $items[[string]$row["itemId"]] } else { $null }
    if (-not $name) { continue }

    $reagents = @()
    if ($row["reagents"] -is [System.Collections.IDictionary]) {
      foreach ($rid in ($row["reagents"].Keys | Sort-Object { [long]$_ })) {
        $reagents += , @([long]$rid, [int]$row["reagents"][$rid])
        $usedItems[[string]$rid] = $true
      }
    }
    if (-not $reagents.Count) { continue }
    $levels = @($row["d"] | ForEach-Object { [int]$_ })

    $learn = [ordered]@{}
    $src = if ($sourceRows) { $sourceRows[[string]$id] } else { $null }
    if ($src -and $src["a"]) { $learn.how = "Known when you learn the profession" }
    elseif ($src -and $src["t"]) {
      $trainers = @()
      foreach ($npcId in @($groups[[string]$src["t"]])) {
        $npc = if ($trainerNpcs) { $trainerNpcs[[string]$npcId] } else { $null }
        if (-not $npc -or -not (Test-PmSide @($npc)[1] $faction)) { continue }
        $npcName = $npcs[[string]$npcId]
        $zone = Get-PmZone $zones @($npc)[0]
        if ($npcName) { $trainers += $(if ($zone) { "$npcName ($zone)" } else { $npcName }) }
      }
      $learn.how = "Trainer"
      if ($trainers.Count) { $learn.where = @($trainers | Select-Object -Unique -First 3) }
    }
    if ($row["r"]) {
      $recipeIds = @(foreach ($r in @($row["r"])) { [string]$r })
      $learn.how = "Recipe"
      $learn.recipes = @(foreach ($recipeId in $recipeIds) {
        $usedItems[$recipeId] = $true
        $entry = [ordered]@{ id = [long]$recipeId }
        $where = @(Get-RecipeSources $(if ($recipeSources) { $recipeSources[$recipeId] } else { $null }) $npcs $zones $quests $faction)
        if ($where.Count) { $entry.where = $where }
        [pscustomobject]$entry
      })
    }
    if ($src -and $src["u"]) { $learn.how = "Not available" }
    if (-not $learn.Contains("how")) { $learn.how = "Unknown" }

    $craft = [ordered]@{ id = [long]$id; name = $name }
    if ($row["itemId"]) {
      $craft.itemId = [long]$row["itemId"]
      $usedItems[[string]$row["itemId"]] = $true
    }
    if ($row["itemAmount"] -and [int]$row["itemAmount"] -gt 1) { $craft.makes = [int]$row["itemAmount"] }
    if ($info -and $null -ne $info.quality -and $info.quality -lt $craftQualities.Count) { $craft.quality = $craftQualities[$info.quality] }
    if ($levels.Count) { $craft.levels = $levels }
    $craft.reagents = $reagents
    $craft.learn = $learn
    if (-not $byProfession.Contains($profName)) { $byProfession[$profName] = @() }
    $byProfession[$profName] += [pscustomobject]$craft
  }

  $names = [ordered]@{}
  foreach ($id in ($usedItems.Keys | Sort-Object { [long]$_ })) {
    if ($items[$id]) { $names[$id] = $items[$id] }
  }
  $version = $null
  $toc = Get-ChildItem -Path (Join-Path $addonsPath "ProfessionMaster") -Filter "*.toc" | Select-Object -First 1
  if ($toc -and ((Get-Content -Raw $toc.FullName) -match '(?m)^##\s*Version:\s*(.+)$')) { $version = $Matches[1].Trim() }
  return [ordered]@{
    source = "Profession Master"
    version = $version
    professions = $byProfession
    items = $names
  }
}
