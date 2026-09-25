# Read addon SavedVariables into one snapshot per roster character.
# Sources: Syndicator (items), Profession Master (recipes, skill), AllTheThings (collections, played, deaths),
# Nova Instance Tracker (level, gold, lockouts), KillDex (kills).

. (Join-Path $PSScriptRoot "lua-saved.ps1")

$ProfessionNames = @{
  "129" = "First Aid"; "164" = "Blacksmithing"; "165" = "Leatherworking"; "171" = "Alchemy"
  "182" = "Herbalism"; "185" = "Cooking"; "186" = "Mining"; "197" = "Tailoring"
  "202" = "Engineering"; "333" = "Enchanting"; "356" = "Fishing"; "393" = "Skinning"
  "755" = "Jewelcrafting"; "773" = "Inscription"
}

function LV($value) {
  foreach ($key in $args) {
    if ($null -eq $value) { return $null }
    if ($value -is [System.Collections.IDictionary]) {
      if (-not $value.ContainsKey([string]$key)) { return $null }
      $value = $value[[string]$key]
    } elseif ($value -is [System.Collections.IList]) {
      $index = 0
      if (-not [int]::TryParse([string]$key, [ref]$index)) { return $null }
      $index--
      if ($index -lt 0 -or $index -ge $value.Count) { return $null }
      $value = $value[$index]
    } else {
      return $null
    }
  }
  return $value
}

function From-Epoch($seconds) {
  if (-not $seconds) { return $null }
  return [DateTimeOffset]::FromUnixTimeSeconds([long]$seconds).LocalDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
}

function Get-LinkName($link) {
  if ($link -match '\|h\[([^\]]+)\]\|h') { return $Matches[1] }
  return $null
}

function Count-Of($value) {
  if ($value -is [System.Collections.ICollection]) { return $value.Count }
  return 0
}

function Split-SaveKey($key) {
  $text = ([string]$key).Trim()
  if ($text -match '^(.+)-([^-\s]+)$') { return $Matches[1].Trim() }
  return $text
}

function Test-SaveName($key, $character) {
  $name = Split-SaveKey $key
  $first = ($character.name -split ' ')[0]
  return ($name -ieq $character.name) -or ($name -ieq $first)
}

function Get-SavedFile($accountDir, $name) {
  $path = Join-Path $accountDir "SavedVariables\$name.lua"
  if (Test-Path $path) { return Read-LuaSaved $path }
  return $null
}

function Add-Items($set, $containers) {
  foreach ($container in @($containers)) {
    foreach ($item in @($container)) {
      if ($item -isnot [System.Collections.IDictionary]) { continue }
      $name = Get-LinkName (LV $item "itemLink")
      if ($name) { [void]$set.Add($name) }
    }
  }
}

function Get-SaveSnapshots($wtfRoot, $characters) {
  $snapshots = @{}
  $accountRoot = Join-Path $wtfRoot "Account"
  if (-not (Test-Path $accountRoot)) { return $snapshots }
  foreach ($character in $characters) {
    $snapshots[$character.id] = [ordered]@{ sources = [ordered]@{} }
  }

  foreach ($accountDir in (Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables") })) {
    $nit = Get-SavedFile $accountDir.FullName "NovaInstanceTracker"
    $syn = Get-SavedFile $accountDir.FullName "Syndicator"
    $pm = Get-SavedFile $accountDir.FullName "ProfessionMaster"
    $att = Get-SavedFile $accountDir.FullName "AllTheThings"
    $accountKillFiles = @(Get-ChildItem -Path $accountDir.FullName -Recurse -Filter "KillDex.lua" -ErrorAction SilentlyContinue)

    foreach ($character in $characters) {
      $snap = $snapshots[$character.id]

      $nitBest = $null
      foreach ($realm in @((LV $nit "NITdatabase" "global").Values)) {
        $mine = LV $realm "myChars"
        if ($mine -isnot [System.Collections.IDictionary]) { continue }
        foreach ($key in $mine.Keys) {
          $row = $mine[$key]
          if (-not (Test-SaveName $key $character) -or -not (LV $row "time")) { continue }
          if (-not $nitBest -or [long](LV $row "time") -gt [long](LV $nitBest "time")) { $nitBest = $row }
        }
      }
      if ($nitBest) {
        $snap.nova = [ordered]@{
          at = From-Epoch (LV $nitBest "time")
          level = LV $nitBest "level"
          goldCopper = LV $nitBest "gold"
          lockouts = Count-Of (LV $nitBest "savedInstances")
        }
        $snap.sources["Nova Instance Tracker"] = $snap.nova.at
      }

      $synChars = LV $syn "SYNDICATOR_DATA" "Characters"
      if ($synChars -is [System.Collections.IDictionary]) {
        $candidates = @($synChars.Keys | Where-Object { Test-SaveName $_ $character })
        $pick = $null
        if ($snap.nova) { $pick = $candidates | Where-Object { (LV $synChars $_ "money") -eq $snap.nova.goldCopper } | Select-Object -First 1 }
        if (-not $pick) { $pick = $candidates | Sort-Object { if ((Split-SaveKey $_) -ieq $character.name) { 1 } else { 0 } } | Select-Object -First 1 }
        if ($pick) {
          $row = $synChars[$pick]
          $items = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
          Add-Items $items (LV $row "bags")
          Add-Items $items (LV $row "bank")
          Add-Items $items (LV $row "bankTabs")
          Add-Items $items (LV $row "mail")
          Add-Items $items (LV $row "equipped")
          Add-Items $items (LV $row "containerInfo" "bags")
          $snap.items = @($items | Sort-Object)
          $snap.sources["Syndicator"] = $null
        }
      }

      $pmRealms = LV $pm "PM_Data"
      $skills = LV $pm "PM_Skills"
      if ($pmRealms -is [System.Collections.IDictionary]) {
        $recipes = [ordered]@{}
        $levels = [ordered]@{}
        $pmTime = $null
        foreach ($realm in $pmRealms.Values) {
          foreach ($key in @((LV $realm "own").Keys)) {
            if (-not (Test-SaveName $key $character)) { continue }
            foreach ($profId in (LV $realm "own" $key).Keys) {
              $prof = $ProfessionNames[[string]$profId]
              if (-not $prof) { continue }
              $names = @()
              foreach ($entry in @(LV $realm "own" $key $profId)) {
                $skillId = [long](LV $entry "skillId")
                if ($skillId -ge 9000000) { continue }
                $skillName = LV $skills ([string]$skillId) "name"
                if ($skillName) { $names += $skillName }
              }
              if ($names.Count) { $recipes[$prof] = @($names | Sort-Object -Unique) }
            }
            foreach ($profId in @((LV $realm "ownLevels" $key).Keys)) {
              $prof = $ProfessionNames[[string]$profId]
              if ($prof) { $levels[$prof] = [int](LV $realm "ownLevels" $key $profId) }
            }
            foreach ($stamp in @((LV $realm "skillTimes" $key).Values)) {
              $when = From-Epoch $stamp
              if ($when -and (-not $pmTime -or $when -gt $pmTime)) { $pmTime = $when }
            }
          }
        }
        if ($recipes.Count -or $levels.Count) {
          $snap.recipes = $recipes
          $snap.skillLevels = $levels
          $snap.sources["Profession Master"] = $pmTime
        }
      }

      $attBest = $null
      $attChars = LV $att "ATTCharacterData"
      if ($attChars -is [System.Collections.IDictionary]) {
        $last = ($character.name -split ' ', 2)[1]
        $first = ($character.name -split ' ')[0]
        foreach ($row in $attChars.Values) {
          $name = LV $row "name"
          $realm = LV $row "realm"
          $match = ("$name $realm" -ieq $character.name) -or ($name -ieq $character.name) -or ($name -ieq $first -and (-not $last -or $realm -ieq $last))
          if (-not $match) { continue }
          if (-not $attBest -or [long](LV $row "lastPlayed") -gt [long](LV $attBest "lastPlayed")) { $attBest = $row }
        }
      }
      if ($attBest) {
        $snap.att = [ordered]@{
          at = From-Epoch (LV $attBest "lastPlayed")
          level = LV $attBest "lvl"
          playedSeconds = LV $attBest "totalTimePlayed"
          deaths = LV $attBest "Deaths"
          quests = Count-Of (LV $attBest "Quests")
          achievements = Count-Of (LV $attBest "Achievements")
          exploration = Count-Of (LV $attBest "Exploration")
          mounts = Count-Of (LV $attBest "Mounts")
          pets = Count-Of (LV $attBest "BattlePets")
          toys = Count-Of (LV $attBest "Toys")
          titles = Count-Of (LV $attBest "Titles")
        }
        $snap.sources["AllTheThings"] = $snap.att.at
      }

      $first = ($character.name -split ' ')[0]
      $last = ($character.name -split ' ', 2)[1]
      $killFiles = @($accountKillFiles | Where-Object { $_.Directory.Parent.Name -ieq "$first-$last" })
      $killFile = $killFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($killFile) {
        $mobs = LV (Read-LuaSaved $killFile.FullName) "KillDexCharDB" "mobs"
        if ($mobs -is [System.Collections.IDictionary] -and $mobs.Count) {
          $rows = @($mobs.Values | ForEach-Object {
            [pscustomobject]@{ name = LV $_ "name"; kills = [int](LV $_ "kills"); gold = [long](LV $_ "gold") }
          })
          $snap.kills = [ordered]@{
            total = ($rows | Measure-Object kills -Sum).Sum
            creatures = $rows.Count
            goldCopper = ($rows | Measure-Object gold -Sum).Sum
            top = @($rows | Where-Object { $_.name } | Sort-Object kills -Descending | Select-Object -First 5)
          }
          $snap.sources["KillDex"] = $killFile.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
        }
      }
    }
  }
  return $snapshots
}
