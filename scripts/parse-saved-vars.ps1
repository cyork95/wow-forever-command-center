# Parse SavedVariables in place (never copied into the repo) and merge them
# into the PRIVATE canonical JSON set. Phase 2a: Syndicator (inventory, mail,
# bank, gold) and DataStore (reputations, currencies) for the SITE pipeline.
# This is independent of the Dossier addon track (tickets #34-38): no addon
# changes here. Chattynator content is never read (names/sizes only).
# Usage:
#   powershell -File scripts/parse-saved-vars.ps1 [-WtfRoot <wtf>] [-PrivateDir <dir>] [-CatalogsPath <file>]
# Private output: data/private/characters.json, economy.json (gitignored).
# Public catalog: data/catalogs.json (factions resolved/unresolved only).
# See docs/canonical-json.md. One source per field: new data lands in
# source-tagged `syndicator` / `datastore` blocks; dossier-export fields are
# never overwritten (snapshot times differ).

param(
  [string]$WtfRoot = "",
  [string]$PrivateDir = "",
  [string]$CatalogsPath = "",
  [string]$RosterPath = ""
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent ($PSScriptRoot -replace '^\\\\\?\\','')
. (Join-Path $PSScriptRoot "lua-saved.ps1")
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
if (-not $CatalogsPath) { $CatalogsPath = Join-Path $repo "data\catalogs.json" }
if (-not $RosterPath) { $RosterPath = Join-Path $repo "data\characters.json" }
if (-not $WtfRoot) {
  $local = Join-Path $PSScriptRoot "addons.local.json"
  if (Test-Path $local) {
    $addonsPath = (Get-Content -Raw $local | ConvertFrom-Json).addonsPath
    # addonsPath points at Interface\AddOns; the WTF root is two levels up.
    if ($addonsPath) { $WtfRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $addonsPath)) "WTF" }
  }
}
if (-not $WtfRoot -or -not (Test-Path $WtfRoot)) { throw "WTF root not found: $WtfRoot (pass -WtfRoot or set scripts/addons.local.json)" }

function Write-JsonFile($path, $value) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json = $value | ConvertTo-Json -Depth 20
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $json + "`n", $utf8)
}

function Read-JsonFile($path) {
  if (-not (Test-Path $path)) { return $null }
  # Explicit UTF8: Get-Content -Raw would decode UTF-8 files as ANSI on
  # Windows PowerShell 5.1 and mangle non-ASCII notes on round-trip.
  return ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Get-Bits([int64]$value, [int]$shift, [int]$width) {
  $mask = ([int64]1 -shl $width) - 1
  return [int64](($value -shr $shift) -band $mask)
}

function Get-SaveItemName($link) {
  if ($link -isnot [string]) { return $null }
  if ($link -match '\|h\[([^\]]+)\]\|h') { return $Matches[1] }
  return $null
}

function Get-SaveItemId($link) {
  if ($link -isnot [string]) { return $null }
  if ($link -match '\|Hitem:(\d+)') { return [long]$Matches[1] }
  return $null
}

function ConvertFrom-EpochLocal($seconds) {
  if (-not $seconds) { return $null }
  return [DateTimeOffset]::FromUnixTimeSeconds([long]$seconds).LocalDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
}

# Flatten Syndicator's nested slot lists into item records (id, name, count, bound).
# Explicit stack, not recursive scriptblock calls: the DLR call-site cache in
# Windows PowerShell 5.1 can throw "Argument types do not match" when one
# & $walk $child site sees mixed node types across a long run.
function Convert-SaveItems($node) {
  $found = New-Object System.Collections.Generic.List[object]
  $stack = New-Object System.Collections.Generic.Stack[object]
  $stack.Push($node)
  while ($stack.Count) {
    $n = $stack.Pop()
    if ($n -is [System.Collections.IDictionary]) {
      $name = Get-SaveItemName $n["itemLink"]
      if ($name) {
        $found.Add([ordered]@{
            id = Get-SaveItemId $n["itemLink"]
            name = $name
            count = $(if ($n["itemCount"]) { [int]$n["itemCount"] } else { 1 })
            bound = [bool]$n["isBound"]
          })
      }
    } elseif ($n -is [System.Collections.IList]) {
      foreach ($child in $n) { $stack.Push($child) }
    }
  }
  return $found.ToArray()
}

function Split-SaveKey($key) {
  $text = ([string]$key).Trim()
  if ($text -match '^(.+)-([^-\s]+)$') { return $Matches[1].Trim() }
  return $text
}

# Pick the Syndicator row for an in-game full name. Duplicate keys exist
# (realm suffix variants and stale short names); prefer the row whose
# details block names the character exactly.
function Find-SaveRow($rows, $fullName, $dossierGold, $datastoreMoney) {
  if ($rows -isnot [System.Collections.IDictionary]) { return $null }
  $first = ([string]$fullName -split '\s+')[0]
  $cands = @()
  foreach ($key in $rows.Keys) {
    $detailName = [string]$rows[$key]["details"]["character"]
    $candidate = if ($detailName) { ($detailName -split '\s+')[0] } else { (Split-SaveKey $key) }
    if ($candidate -ieq $first) { $cands += $key }
  }
  if (-not $cands.Count) { return $null }
  # Veto stale duplicates: a row whose money matches a known snapshot wins
  # over rows matching neither. Datastore (same session) outranks dossier.
  foreach ($tier in @($datastoreMoney, $dossierGold)) {
    if ($null -eq $tier) { continue }
    $hit = @($cands | Where-Object { $null -ne $rows[$_]["money"] -and [long]$rows[$_]["money"] -eq [long]$tier })
    if ($hit.Count) { $cands = $hit; break }
  }
  # First-token fallback: duplicate keys exist (stale short names, realm
  # suffix variants). Score candidates: exact names beat prefixes, a
  # realm-qualified row beats a stale short name, and money agreeing with
  # the dossier/datastore snapshots beats both (same-session data agrees).
  $best = $null; $bestScore = -1
  foreach ($key in $rows.Keys) {
    $detailName = [string]$rows[$key]["details"]["character"]
    $candidate = if ($detailName) { ($detailName -split '\s+')[0] } else { (Split-SaveKey $key) }
    if ($candidate -ine $first) { continue }
    $score = 0
    if ((Split-SaveKey $key) -ieq $fullName) { $score += 4 }
    if ([string]$rows[$key]["details"]["realm"]) { $score += 2 }
    $rowMoney = $rows[$key]["money"]
    if ($null -ne $rowMoney -and @($datastoreMoney, $dossierGold) -contains [long]$rowMoney) { $score += 16 }
    $score += (Count-SaveItems $rows[$key])
    if ($score -gt $bestScore) { $bestScore = $score; $best = $rows[$key] }
  }
  return $best
}

function Count-SaveItems($row) {
  $n = 0
  foreach ($loc in @("bags", "bank", "bankTabs", "equipped", "mail")) {
    $items = @(Convert-SaveItems $row[$loc])
    $n += $items.Count
  }
  return $n
}

$script:Standings = @{ 1 = "Hated"; 2 = "Hostile"; 3 = "Unfriendly"; 4 = "Neutral"; 5 = "Friendly"; 6 = "Honored"; 7 = "Revered"; 8 = "Exalted" }

# Faction IDs verified by the repo map in scripts/altoholic.ps1, corroborated
# in-data by the Flann Dossier export (same standings; Gadgetzan value 600 == 600).
$script:VerifiedFactions = [ordered]@{
  "47" = "Ironforge"; "54" = "Gnomeregan Exiles"; "69" = "Darnassus"; "72" = "Stormwind"
  "369" = "Gadgetzan"; "469" = "Alliance"; "609" = "Cenarion Circle"
}

# Decode one DataStore_Reputations packed value. Bit layout is defined by the
# installed addon (Interface/AddOns/DataStore_Reputations/DataStore_Reputations.lua,
# ScanSingleFaction: FACTION_TYPE_NORMAL=0 in bits 0-2, isNegative bit 3,
# standing bits 4-7, earned value bits 8+). Same layout as scripts/altoholic.ps1.
function Convert-RepValue([int64]$packed) {
  $type = [int](Get-Bits $packed 0 3)
  if ($type -ne 0) { return [ordered]@{ type = $type; raw = $packed; source = "datastore" } }
  $negative = (Get-Bits $packed 3 1) -eq 1
  $standingId = [int](Get-Bits $packed 4 4)
  $value = [int64]($packed -shr 8)
  if ($negative) { $value = -$value }
  $label = $script:Standings[$standingId]
  if (-not $label) { $label = "Standing $standingId" }
  return [ordered]@{ standing = $label; standingId = $standingId; negative = [bool]$negative; value = $value; source = "datastore" }
}

# Decode one DataStore_Currencies packed entry against the in-file catalog.
function Convert-CurrencyValue([int64]$packed, $catalog) {
  $index = [int](Get-Bits $packed 8 10)
  $count = [int64]($packed -shr 18)
  $name = $null
  if ($catalog -is [System.Collections.IList] -and $index -ge 1 -and $index -le $catalog.Count) { $name = [string]$catalog[$index - 1] }
  if (-not $name) { $name = "Currency $index" }
  return [ordered]@{ name = $name; quantity = $count; source = "datastore" }
}

# Attribute anonymous DataStore character entries (lists, no names) to
# canonical characters. Each entry's lastUpdate precedes that character's next
# logout; pairing in time order requires every delta to fall inside one hour.
function Resolve-DataStoreOwners($entries, $characters) {
  $owners = @{}
  $stamps = @()
  for ($i = 0; $i -lt $entries.Count; $i++) {
    $t = $entries[$i]["lastUpdate"]
    if ($t) { $stamps += [pscustomobject]@{ index = $i; at = [long]$t } }
  }
  $logouts = @()
  foreach ($c in $characters) {
    $t = $c["datastoreLogout"]
    if ($t) { $logouts += [pscustomobject]@{ id = [string]$c["id"]; at = [long]$t } }
  }
  # Entries outnumber known logouts (beta throwaways without exports), so pair
  # positionally would misalign. Each character takes its nearest preceding
  # stamp inside one hour.
  foreach ($logout in $logouts) {
    $bestIdx = $null; $bestAt = -1
    foreach ($stamp in $stamps) {
      if ($stamp.at -le $logout.at -and ($logout.at - $stamp.at) -le 3600 -and $stamp.at -gt $bestAt) {
        $bestAt = $stamp.at; $bestIdx = $stamp.index
      }
    }
    if ($null -ne $bestIdx) { $owners[$bestIdx] = $logout.id }
  }
  return $owners
}

# ---- Main: read account SavedVariables in place, merge into private set ----

$charactersPath = Join-Path $PrivateDir "characters.json"
$economyPath = Join-Path $PrivateDir "economy.json"
$canonicalChars = Read-JsonFile $charactersPath
$canonicalEcon = Read-JsonFile $economyPath
if (-not $canonicalChars -or -not $canonicalChars.characters) { throw "No private canonical characters at $charactersPath (run parse-dossier-export.ps1 first)" }
if (-not $canonicalEcon -or -not $canonicalEcon.characters) { throw "No private canonical economy at $economyPath" }

$accountRoot = Join-Path $WtfRoot "Account"
$check = @()
foreach ($accountDir in @(Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables") })) {
  $sv = Join-Path $accountDir.FullName "SavedVariables"
  $synRows = $null
  $synStamp = $null
  if (Test-Path (Join-Path $sv "Syndicator.lua")) {
    $synStamp = (Get-Item (Join-Path $sv "Syndicator.lua")).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
    $synRows = (Read-LuaSaved (Join-Path $sv "Syndicator.lua"))["SYNDICATOR_DATA"]["Characters"]
  }
  $repEntries = $null; $curEntries = $null; $curCatalog = $null; $charEntries = $null
  foreach ($pair in @(
      @("DataStore_Reputations.lua", "DataStore_Reputations_Characters"),
      @("DataStore_Currencies.lua", "DataStore_Currencies_Characters"),
      @("DataStore_Characters.lua", "DataStore_Characters_Info")
    )) {
    $file = Join-Path $sv $pair[0]
    if (-not (Test-Path $file)) { continue }
    $table = Read-LuaSaved $file
    if ($pair[0] -like "DataStore_Reputations*") { $repEntries = @($table[$pair[1]]) }
    if ($pair[0] -like "DataStore_Currencies*") {
      $curEntries = @($table[$pair[1]])
      $curCatalog = $table["DataStore_Currencies_Catalog"]["List"]
    }
    if ($pair[0] -like "DataStore_Characters*") { $charEntries = @($table[$pair[1]]) }
  }

  # Logout times for owner attribution come from DataStore_Characters.
  # DataStore names are full ("Flann Anvilhew"); canonical beta names may be
  # first-token only ("Flann"). Match on first token, latest logout wins.
  $logoutByName = @{}
  foreach ($info in @($charEntries)) {
    $nm = [string]$info["name"]
    if (-not $nm -or -not $info["lastLogoutTimestamp"]) { continue }
    $tok = ($nm -split '\s+')[0]
    if (-not $logoutByName.ContainsKey($tok) -or [long]$info["lastLogoutTimestamp"] -gt $logoutByName[$tok]) {
      $logoutByName[$tok] = [long]$info["lastLogoutTimestamp"]
    }
  }
  $attrChars = @()
  foreach ($char in @($canonicalChars.characters)) {
    $full2 = if ($char.displayName) { [string]$char.displayName } else { [string]$char.name }
    $tok = (($full2 -split '\s+'))[0]
    if ($logoutByName.ContainsKey($tok)) {
      $attrChars += [ordered]@{ id = [string]$char.id; datastoreLogout = $logoutByName[$tok] }
    }
  }
  $repOwners = Resolve-DataStoreOwners @($repEntries) $attrChars
  $curOwners = Resolve-DataStoreOwners @($curEntries) $attrChars

  foreach ($char in @($canonicalChars.characters)) {
    $id = [string]$char.id
    $full = if ($char.displayName) { [string]$char.displayName } else { [string]$char.name }
    $dossierGold = $char.goldCopper
    $dsMoney = $null
    $firstTok = (($full -split '\s+'))[0]
    if ($logoutByName.ContainsKey($firstTok)) {
      foreach ($info in @($charEntries)) {
        $infoTok = (([string]$info["name"] -split '\s+'))[0]
        if ($infoTok -eq $firstTok) { $dsMoney = [long]$info["money"]; break }
      }
    }

    if ($synRows) {
      $row = Find-SaveRow $synRows $full $dossierGold $dsMoney
      if ($row) {
        # Walk mail directly: Convert-SaveItems drops the expiration wrapper.
        # Explicit stack (see Convert-SaveItems: no recursive & calls).
        $mail = New-Object System.Collections.Generic.List[object]
        $mailStack = New-Object System.Collections.Generic.Stack[object]
        $mailStack.Push($row["mail"])
        while ($mailStack.Count) {
          $mn = $mailStack.Pop()
          if ($mn -is [System.Collections.IDictionary]) {
            $name = Get-SaveItemName $mn["itemLink"]
            if ($name) {
              $mail.Add([ordered]@{
                  itemName = $name
                  itemId = Get-SaveItemId $mn["itemLink"]
                  count = $(if ($mn["itemCount"]) { [int]$mn["itemCount"] } else { 1 })
                  expiresAt = ConvertFrom-EpochLocal $mn["expirationTime"]
                })
            }
          } elseif ($mn -is [System.Collections.IList]) {
            foreach ($child in $mn) { $mailStack.Push($child) }
          }
        }
        $synMoney = $null
        if ($null -ne $row["money"]) { $synMoney = [long]$row["money"] }
        $char | Add-Member -NotePropertyName "syndicator" -NotePropertyValue ([ordered]@{
            moneyCopper = $synMoney
            bags = @(Convert-SaveItems $row["bags"])
            bank = @(Convert-SaveItems $row["bank"])
            bankTabs = @(Convert-SaveItems $row["bankTabs"])
            equipped = @(Convert-SaveItems $row["equipped"])
            mail = $mail.ToArray()
            source = "syndicator"
            scannedAt = $synStamp
          }) -Force
        foreach ($econ in @($canonicalEcon.characters)) {
          if ([string]$econ.id -eq $id) {
            $econ | Add-Member -NotePropertyName "syndicatorMoneyCopper" -NotePropertyValue $char.syndicator.moneyCopper -Force
          }
        }
      }
    }

    $ds = [ordered]@{ source = "datastore" }
    $hasDs = $false
    foreach ($idx in $repOwners.Keys) {
      if ([string]$repOwners[$idx] -ne $id) { continue }
      $factions = $repEntries[$idx]["Factions"]
      $reps = New-Object System.Collections.Generic.List[object]
      if ($factions -is [System.Collections.IDictionary]) {
        foreach ($fid in $factions.Keys) {
          $dec = Convert-RepValue ([int64]$factions[$fid])
          $entry = [ordered]@{ id = [long]$fid }
          foreach ($key in @($dec.Keys)) { $entry[[string]$key] = $dec[$key] }
          if ($script:VerifiedFactions.Contains([string]$fid)) { $entry["name"] = $script:VerifiedFactions[[string]$fid] }
          $reps.Add($entry)
        }
      }
      $ds["reputations"] = @($reps | Sort-Object id)
      $hasDs = $true
    }
    foreach ($idx in $curOwners.Keys) {
      if ([string]$curOwners[$idx] -ne $id) { continue }
      $list = $curEntries[$idx]["Currencies"]
      $curs = New-Object System.Collections.Generic.List[object]
      foreach ($packed in $list) {
        if ($null -eq $packed) { continue }
        $curs.Add((Convert-CurrencyValue ([int64]$packed) $curCatalog))
      }
      $totals = $curEntries[$idx]["Totals"]
      if ($totals -is [System.Collections.IDictionary]) {
        foreach ($cid in $totals.Keys) {
          if (@($curs | Where-Object { $_.quantity -eq [long]$totals[$cid] }).Count) { continue }
          $curs.Add([ordered]@{ id = [long]$cid; name = $null; quantity = [long]$totals[$cid]; source = "datastore" })
        }
      }
      $ds["currencies"] = $curs.ToArray()
      $hasDs = $true
    }
    if ($hasDs) { $char | Add-Member -NotePropertyName "datastore" -NotePropertyValue $ds -Force }

    foreach ($econ in @($canonicalEcon.characters)) {
      if ([string]$econ.id -eq $id -and $null -ne $dsMoney) {
        $econ | Add-Member -NotePropertyName "datastoreMoneyCopper" -NotePropertyValue $dsMoney -Force
      }
    }
    $check += [pscustomobject]@{
      id = $id
      dossierGold = $dossierGold
      syndicatorMoney = $(if ($char.syndicator) { $char.syndicator.moneyCopper } else { $null })
      datastoreMoney = $dsMoney
    }
  }
}

$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$canonicalChars.generatedAt = $stamp
$canonicalEcon.generatedAt = $stamp
Write-JsonFile $charactersPath $canonicalChars
Write-JsonFile $economyPath $canonicalEcon
Write-Output "Private: $charactersPath ($($canonicalChars.characters.Count) characters)"

# Faction catalog: resolve IDs to names only from verified sources.
# Verified base = repo map in scripts/altoholic.ps1, corroborated in-data by
# the Flann Dossier export (same standings; Gadgetzan value 600 == 600).
$catalog = Read-JsonFile $CatalogsPath
if (-not $catalog) { $catalog = [ordered]@{ schemaVersion = 1; quests = [ordered]@{ source = "data/quests.json"; extra = [ordered]@{} }; factions = [ordered]@{}; unresolved = [ordered]@{ quests = @(); factions = @() } } }
$verified = $script:VerifiedFactions
$seenIds = @()
foreach ($char in @($canonicalChars.characters)) {
  foreach ($rep in @($char.datastore.reputations)) { $seenIds += [string]$rep.id }
}
$seenIds = @($seenIds | Sort-Object -Unique)
$unresolved = @()
foreach ($fid in $seenIds) {
  if ($verified.Contains($fid)) {
    $catalog.factions | Add-Member -NotePropertyName $fid -NotePropertyValue $verified[$fid] -Force
  } else {
    $unresolved += [long]$fid
  }
}
$unresolved = @($unresolved | Sort-Object -Unique)
$prior = @()
if ($catalog.unresolved -and $catalog.unresolved.factions) { $prior = @($catalog.unresolved.factions) }
$merged = @((@($prior) + @($unresolved) | Sort-Object -Unique))
# Keep prior unresolved IDs too (never drop evidence); drop any now verified.
$catalog.unresolved.factions = @($merged | Where-Object { -not $verified.Contains([string]$_) })
Write-JsonFile $CatalogsPath $catalog
Write-Output "Catalogs: $($verified.Count) verified factions, $($catalog.unresolved.factions.Count) unresolved"

Write-Output ""
Write-Output "Gold cross-check (copper; snapshot times differ):"
Write-Output ("{0,-12} {1,12} {2,12} {3,12}  {4}" -f "character", "dossier", "syndicator", "datastore", "verdict")
foreach ($row in $check) {
  $verdict = "no export/SV comparison"
  $vals = @($row.dossierGold, $row.syndicatorMoney, $row.datastoreMoney | Where-Object { $null -ne $_ })
  if ($vals.Count -ge 2) {
    $verdict = if (@($vals | Sort-Object -Unique).Count -eq 1) { "AGREE" } else { "DIFFER (snapshot times differ)" }
  } elseif ($vals.Count -eq 1) { $verdict = "single source only" }
  Write-Output ("{0,-12} {1,12} {2,12} {3,12}  {4}" -f $row.id, $row.dossierGold, $row.syndicatorMoney, $row.datastoreMoney, $verdict)
}
