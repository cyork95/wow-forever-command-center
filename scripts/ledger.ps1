# Account-wide DossierDB (WTF\Account\<account>\SavedVariables\Dossier.lua)
# holds the ledger, mail, professions, rares, lockouts, sessions, tasks, and quest history.

function Get-LuaRows($value) {
  if ($null -eq $value) { return @() }
  if ($value -is [System.Collections.IList]) { return @($value) }
  if ($value -is [System.Collections.IDictionary]) { return @($value.Values) }
  return @()
}

function Convert-LedgerCharacter($db, $key) {
  $gold = @()
  foreach ($row in (Get-LuaRows (LV $db "ledger" $key "gold"))) {
    if ($row -isnot [System.Collections.IDictionary]) { continue }
    $gold += [ordered]@{
      time = LV $row "time"
      delta = LV $row "delta"
      balance = LV $row "balance"
      source = LV $row "source"
      detail = LV $row "detail"
    }
  }

  $currencies = @()
  $currencyTable = LV $db "ledger" $key "currencies"
  if ($currencyTable -is [System.Collections.IDictionary]) {
    foreach ($id in $currencyTable.Keys) {
      $entry = $currencyTable[$id]
      $currencies += [ordered]@{
        id = [string]$id
        name = LV $entry "name"
        quantity = LV $entry "quantity"
      }
    }
  }

  $reputations = @()
  $repTable = LV $db "ledger" $key "reputations"
  if ($repTable -is [System.Collections.IDictionary]) {
    foreach ($id in $repTable.Keys) {
      $entry = $repTable[$id]
      $reputations += [ordered]@{
        id = [string]$id
        name = LV $entry "name"
        standing = LV $entry "standing"
        value = LV $entry "value"
      }
    }
  }

  $skills = @()
  foreach ($skill in (Get-LuaRows (LV $db "professions" $key "skills"))) {
    if ($skill -isnot [System.Collections.IDictionary]) { continue }
    $skills += [ordered]@{ name = LV $skill "name"; current = LV $skill "current"; max = LV $skill "max" }
  }

  $letters = @()
  foreach ($letter in (Get-LuaRows (LV $db "mail" $key "letters"))) {
    if ($letter -isnot [System.Collections.IDictionary]) { continue }
    $letters += [ordered]@{
      time = LV $letter "time"
      direction = LV $letter "direction"
      who = LV $letter "who"
      subject = LV $letter "subject"
      gold = LV $letter "gold"
      items = LV $letter "items"
      status = LV $letter "status"
    }
  }

  $sessions = @()
  foreach ($entry in (Get-LuaRows (LV $db "sessions" $key))) {
    if ($entry -isnot [System.Collections.IDictionary]) { continue }
    $sessions += [ordered]@{
      start = LV $entry "start"
      seconds = LV $entry "seconds"
      zone = LV $entry "zone"
      gold = LV $entry "gold"
      xp = LV $entry "xp"
      kills = LV $entry "kills"
    }
  }

  $tasks = @()
  foreach ($task in (Get-LuaRows (LV $db "tasks" $key "items"))) {
    if ($task -isnot [System.Collections.IDictionary]) { continue }
    $tasks += [ordered]@{
      name = LV $task "name"
      repeatKind = LV $task "repeatKind"
      zone = LV $task "zone"
      doneUntil = LV $task "doneUntil"
    }
  }

  $quests = @()
  foreach ($quest in (Get-LuaRows (LV $db "questHistory" $key "quests"))) {
    if ($quest -isnot [System.Collections.IDictionary]) { continue }
    $quests += [ordered]@{
      questID = LV $quest "questID"
      title = LV $quest "title"
      zone = LV $quest "zone"
      time = LV $quest "time"
    }
  }

  $saved = @()
  foreach ($lockout in (Get-LuaRows (LV $db "lockouts" $key "saved"))) {
    if ($lockout -isnot [System.Collections.IDictionary]) { continue }
    $saved += [ordered]@{
      name = LV $lockout "name"
      difficulty = LV $lockout "difficulty"
      progress = LV $lockout "progress"
      encounters = LV $lockout "encounters"
      resetText = LV $lockout "resetText"
    }
  }

  $runs = @()
  foreach ($run in (Get-LuaRows (LV $db "lockouts" $key "runs"))) {
    if ($run -isnot [System.Collections.IDictionary]) { continue }
    $runs += [ordered]@{
      name = LV $run "name"
      entered = LV $run "entered"
      seconds = LV $run "seconds"
      levelFrom = LV $run "levelFrom"
      levelTo = LV $run "levelTo"
      gold = LV $run "gold"
    }
  }

  return [ordered]@{
    gold = @($gold)
    currencies = @($currencies)
    reputations = @($reputations)
    professions = @($skills)
    mail = @($letters)
    sessions = @($sessions)
    tasks = @($tasks)
    quests = @($quests)
    lockouts = [ordered]@{ saved = @($saved); runs = @($runs) }
  }
}

function Update-Ledger($wtfRoot, $repo) {
  $accountRoot = Join-Path $wtfRoot "Account"
  $out = [ordered]@{ updated = $null; characters = [ordered]@{}; rares = @() }
  if (-not (Test-Path $accountRoot)) { return }

  foreach ($accountDir in (Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables\Dossier.lua") })) {
    $parsed = Get-SavedFile $accountDir.FullName "Dossier"
    $db = LV $parsed "DossierDB"
    if ($db -isnot [System.Collections.IDictionary]) { continue }
    $stamp = (Get-Item (Join-Path $accountDir.FullName "SavedVariables\Dossier.lua")).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
    if (-not $out.updated -or $stamp -gt $out.updated) { $out.updated = $stamp }

    $keys = @{}
    foreach ($bucket in @("ledger", "professions", "mail", "sessions", "tasks", "questHistory", "lockouts")) {
      $table = LV $db $bucket
      if ($table -is [System.Collections.IDictionary]) {
        foreach ($key in $table.Keys) { $keys[[string]$key] = $true }
      }
    }

    foreach ($key in $keys.Keys) {
      $out.characters[$key] = Convert-LedgerCharacter $db $key
    }

    $rares = LV $db "rares"
    if ($rares -is [System.Collections.IDictionary]) {
      $rows = @()
      foreach ($rare in $rares.Values) {
        if ($rare -isnot [System.Collections.IDictionary]) { continue }
        $loot = @()
        foreach ($item in (Get-LuaRows (LV $rare "loot"))) { if ($item) { $loot += [string]$item } }
        $rows += [ordered]@{
          name = LV $rare "name"
          zone = LV $rare "zone"
          x = LV $rare "x"
          y = LV $rare "y"
          kills = LV $rare "kills"
          character = LV $rare "character"
          time = LV $rare "time"
          loot = @($loot)
        }
      }
      $out.rares = @($rows)
    }
  }

  $path = Join-Path $repo "data\ledger.json"
  $json = $out | ConvertTo-Json -Depth 8
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json + "`n", $utf8)
  Write-Output "Wrote ledger data for $($out.characters.Count) characters to data/ledger.json"
}
