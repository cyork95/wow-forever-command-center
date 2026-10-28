# Parse AllTheThings SavedVariables in place (never copied into the repo) and
# merge them into the PRIVATE canonical JSON set. Phase 2b parser 1 of 4:
# ATT full lists (ATTAccountWideData / ATTCharacterData) -- collection
# have-detail beyond the counts Dossier already summarises.
# This is independent of the Dossier addon track: no addon changes here.
# Chattynator content is never read (names/sizes only). Polestar progress is
# never parsed (guides stay pointer-only).
# Usage:
#   powershell -File scripts/parse-att.ps1 [-WtfRoot <wtf>] [-PrivateDir <dir>] [-PublicPath <file>] [-RosterPath <file>]
# Private output: data/private/att.json (gitignored).
# Public output:  data/att.public.json (allowlist projection, roster-matched
# characters only; account have-sets are public-safe armory-like data).
# See docs/canonical-json.md. One source per field: ATT owns have-detail
# (quest/spell/appearance id sets); Dossier remains the aggregator for what it
# already exports (counts, names, level, time played, deaths) and is never
# overwritten here. The SV only records haves; want-detail is not derivable
# from it and stays with the Dossier totals.

param(
  [string]$WtfRoot = "",
  [string]$PrivateDir = "",
  [string]$PublicPath = "",
  [string]$RosterPath = "",
  [long]$MaxFileBytes = 5242880
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent ($PSScriptRoot -replace '^\\\\\?\\','')
. (Join-Path $PSScriptRoot "lua-saved.ps1")
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
if (-not $PublicPath) { $PublicPath = Join-Path $repo "data\att.public.json" }
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

function ConvertFrom-EpochLocal($seconds) {
  if (-not $seconds) { return $null }
  return [DateTimeOffset]::FromUnixTimeSeconds([long]$seconds).LocalDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
}

# ATT have-sets this parser owns. Everything else in the character/account
# tables (level, time played, deaths, professions, build ids) already has a
# source in Dossier and is deliberately NOT extracted here.
$script:HaveCategories = @(
  "Quests", "Spells", "Exploration", "FlightPaths", "Achievements",
  "Titles", "Toys", "Mounts", "BattlePets", "PriorQuests", "OneTimeQuests"
)

# Account-wide only: per-character tables do not carry these.
$script:AccountCategories = @("Sources")

# Sorted id list from an ATT category node. Nodes are dicts (id -> 1/2) when
# populated and empty lists when the character has nothing collected yet;
# both forms occur in real files, so both are handled.
function Get-AttIds($node) {
  if ($null -eq $node) { return @() }
  $ids = New-Object System.Collections.Generic.List[object]
  if ($node -is [System.Collections.IDictionary]) {
    foreach ($key in $node.Keys) {
      $n = 0
      if ([long]::TryParse([string]$key, [ref]$n)) { $ids.Add($n) }
      else { $ids.Add([string]$key) }
    }
  } elseif ($node -is [System.Collections.IList]) {
    foreach ($v in $node) {
      $n = 0
      if ([long]::TryParse([string]$v, [ref]$n)) { $ids.Add($n) }
      else { $ids.Add([string]$v) }
    }
  }
  $arr = $ids.ToArray()
  if (-not $arr.Count) { return @() }
  if ($arr[0] -is [long]) { return @($arr | Sort-Object) }
  return @($arr | Sort-Object { [string]$_ })
}

function Get-FirstToken($text) {
  $t = ([string]$text).Trim()
  if (-not $t) { return "" }
  return (($t -split '\s+'))[0]
}

# ---- Main: read account SavedVariables in place, merge into private set ----

$attPath = Join-Path $PrivateDir "att.json"
$prev = Read-JsonFile $attPath

$canonicalChars = @()
$charsDoc = Read-JsonFile (Join-Path $PrivateDir "characters.json")
if ($charsDoc -and $charsDoc.characters) { $canonicalChars = @($charsDoc.characters) }

$roster = @()
if (Test-Path $RosterPath) {
  $rosterDoc = ([System.IO.File]::ReadAllText($RosterPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
  if ($rosterDoc -is [System.Collections.IList]) { $roster = @($rosterDoc) }
  elseif ($rosterDoc.roster) { $roster = @($rosterDoc.roster) }
  elseif ($rosterDoc.name) { $roster = @($rosterDoc) }
}

$accountRoot = Join-Path $WtfRoot "Account"
$found = $false
$capped = @()
$charRows = [ordered]@{}
$accountNode = $null
$sources = New-Object System.Collections.Generic.List[object]
foreach ($accountDir in @(Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables") })) {
  $file = Join-Path $accountDir.FullName "SavedVariables\AllTheThings.lua"
  if (-not (Test-Path $file)) { continue }
  $info = Get-Item $file
  if ($info.Length -gt $MaxFileBytes) {
    $capped += $file
    continue
  }
  $found = $true
  $sources.Add([ordered]@{
      file = "AllTheThings.lua"
      account = $accountDir.Name
      sizeBytes = $info.Length
      mtime = $info.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
    })
  $table = Read-LuaSaved $file
  $charData = $table["ATTCharacterData"]
  if ($charData -is [System.Collections.IDictionary]) {
    foreach ($guid in $charData.Keys) {
      # GUIDs are globally unique, so multi-account merges are a straight union.
      $charRows[[string]$guid] = $charData[$guid]
    }
  }
  $wide = $table["ATTAccountWideData"]
  if ($wide -is [System.Collections.IDictionary]) { $accountNode = $wide }
}
# A reset/empty table parses to an empty list, not a dict; coerce so the
# category reads below see an (empty) table instead of a null index.
if (-not ($accountNode -is [System.Collections.IDictionary])) { $accountNode = @{} }
if ($capped.Count) {
  Write-Warning ("AllTheThings.lua over size cap ($MaxFileBytes bytes), skipped: " + ($capped -join ", "))
}
if (-not $found -and -not $prev) {
  throw "No AllTheThings.lua found under $accountRoot (and no previous att.json to keep)"
}
if (-not $found -and $prev) {
  Write-Warning "No AllTheThings.lua found under $accountRoot; keeping previous att.json ($(@($prev.characters).Count) characters, parsed $($prev.generatedAt))"
  Write-Output "ATT: source missing, KEPT previous att.json"
  return
}

$account = [ordered]@{ source = "att" }
foreach ($cat in ($script:HaveCategories + $script:AccountCategories)) {
  $ids = @(Get-AttIds $accountNode[$cat])
  $account[$cat.ToLower()] = [ordered]@{ count = $ids.Count; have = $ids }
}
$sourcesText = ($sources | ForEach-Object { "$($_.account) ($($_.sizeBytes) bytes, $($_.mtime))" }) -join "; "

$characters = New-Object System.Collections.Generic.List[object]
foreach ($guid in ($charRows.Keys | Sort-Object)) {
  $row = $charRows[$guid]
  $name = [string]$row["name"]
  $realm = [string]$row["realm"]
  $tok = Get-FirstToken $name
  $canonicalId = $null
  foreach ($c in $canonicalChars) {
    $full = if ($c.displayName) { [string]$c.displayName } else { [string]$c.name }
    if ($tok -and ((Get-FirstToken $full) -ieq $tok)) { $canonicalId = [string]$c.id; break }
  }
  $have = [ordered]@{ source = "att" }
  foreach ($cat in $script:HaveCategories) {
    $ids = @(Get-AttIds $row[$cat])
    $have[$cat.ToLower()] = [ordered]@{ count = $ids.Count; have = $ids }
  }
  $custom = [ordered]@{}
  if ($row["CustomCollects"] -is [System.Collections.IDictionary]) {
    foreach ($key in ($row["CustomCollects"].Keys | Sort-Object)) { $custom[[string]$key] = [bool]$row["CustomCollects"][$key] }
  }
  $stamps = [ordered]@{}
  if ($row["TimeStamps"] -is [System.Collections.IDictionary]) {
    foreach ($key in ($row["TimeStamps"].Keys | Sort-Object)) { $stamps[[string]$key] = (ConvertFrom-EpochLocal $row["TimeStamps"][$key]) }
  }
  $characters.Add([ordered]@{
      guid = [string]$guid
      name = $name
      realm = $realm
      canonicalId = $canonicalId
      lastPlayed = (ConvertFrom-EpochLocal $row["lastPlayed"])
      have = $have
      customCollects = $custom
      scanTimes = $stamps
    })
}

$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$newDoc = [ordered]@{
  schemaVersion = 1
  generatedAt = $stamp
  sources = $sources.ToArray()
  account = $account
  characters = $characters.ToArray()
}

function Get-AttTotals($doc) {
  if (-not $doc) { return $null }
  $charQuests = 0
  foreach ($c in @($doc.characters)) { $charQuests += [int]$c.have.quests.count }
  return [ordered]@{
    characters = @($doc.characters).Count
    charQuests = $charQuests
    accountQuests = [int]$doc.account.quests.count
    accountSources = [int]$doc.account.sources.count
  }
}

# Ingest safety (Forever beta quirk: an SV can come back empty/reset after a
# patch or a bad logout). Timestamp and diff every ingest; a source that
# shrinks unexpectedly or parses to zero records WARNS and keeps the previous
# good canonical -- good data is never overwritten with a reset file.
$newTotals = Get-AttTotals $newDoc
$prevTotals = Get-AttTotals $prev
$keepReason = $null
if ($prev -and $newTotals.characters -eq 0 -and $prevTotals.characters -gt 0) {
  $keepReason = "parsed 0 SV characters (previous had $($prevTotals.characters)); source looks reset"
} else {
  $prevBytes = 0
  foreach ($s in @($prev.sources)) { $prevBytes += [long]$s.sizeBytes }
  $newBytes = 0
  foreach ($s in $sources.ToArray()) { $newBytes += [long]$s.sizeBytes }
  if ($prev -and $newBytes -lt $prevBytes -and $newTotals.charQuests -lt $prevTotals.charQuests) {
    $keepReason = "source shrank ($prevBytes -> $newBytes bytes) and quest-haves dropped ($($prevTotals.charQuests) -> $($newTotals.charQuests))"
  }
}
if ($keepReason) {
  Write-Warning ("ATT ingest guard: $keepReason; keeping previous att.json (parsed $($prev.generatedAt))")
  Write-Output "ATT: KEPT previous att.json ($keepReason)"
  return
}

Write-JsonFile $attPath $newDoc
$prevDir = Join-Path $PrivateDir "prev"
if (-not (Test-Path $prevDir)) { New-Item -ItemType Directory -Force -Path $prevDir | Out-Null }
Copy-Item -Force $attPath (Join-Path $prevDir "att.json")
if ($prevTotals) {
  Write-Output ("ATT diff: characters $($prevTotals.characters) -> $($newTotals.characters); char quest-haves $($prevTotals.charQuests) -> $($newTotals.charQuests); account quests $($prevTotals.accountQuests) -> $($newTotals.accountQuests), sources $($prevTotals.accountSources) -> $($newTotals.accountSources)")
} else {
  Write-Output ("ATT: first ingest ($($newTotals.characters) SV characters, account quests $($newTotals.accountQuests), sources $($newTotals.accountSources); $sourcesText)")
}
foreach ($c in @($newDoc.characters)) {
  $match = if ($c.canonicalId) { " -> $($c.canonicalId)" } else { " (no canonical match)" }
  Write-Output ("ATT: $($c.name) [$($c.realm)] quests $($c.have.quests.count), spells $($c.have.spells.count), exploration $($c.have.exploration.count), flightpaths $($c.have.flightpaths.count), achievements $($c.have.achievements.count), toys $($c.have.toys.count), mounts $($c.have.mounts.count), battlepets $($c.have.battlepets.count)$match")
}
Write-Output "Private: $attPath ($($newTotals.characters) characters)"

# Public redaction (allowlist): account have-sets are public-safe armory-like
# data; per-character detail is roster-matched only, like
# characters.public.json. Beta SV names match no launch-roster entry, so the
# character list is honestly empty until Nov 4 names flow through.
$publicChars = New-Object System.Collections.Generic.List[object]
foreach ($c in @($newDoc.characters)) {
  $tok = Get-FirstToken $c.name
  foreach ($r in $roster) {
    if ($tok -and ((Get-FirstToken $r.name) -ieq $tok)) {
      $publicChars.Add([ordered]@{
          canonicalId = [string]$r.id
          name = $c.name
          questsHave = @($c.have.quests.have)
          questsHaveCount = [int]$c.have.quests.count
          spellsHave = [int]$c.have.spells.count
          explorationHave = @($c.have.exploration.have)
          flightPathsHave = [int]$c.have.flightpaths.count
          achievementsHave = [int]$c.have.achievements.count
          toysHave = [int]$c.have.toys.count
          mountsHave = [int]$c.have.mounts.count
          battlePetsHave = [int]$c.have.battlepets.count
        })
      break
    }
  }
}
$public = Read-JsonFile $PublicPath
if (-not $public) { $public = [ordered]@{ schemaVersion = 1 } }
$public.schemaVersion = 1
$public | Add-Member -NotePropertyName "generatedAt" -NotePropertyValue $stamp -Force
$public | Add-Member -NotePropertyName "account" -NotePropertyValue ([ordered]@{
    questsHave = $newDoc.account.quests.have
    questsHaveCount = $newDoc.account.quests.count
    sourcesHave = $newDoc.account.sources.have
    sourcesHaveCount = $newDoc.account.sources.count
    spellsHaveCount = $newDoc.account.spells.count
    explorationHaveCount = $newDoc.account.exploration.count
    achievementsHaveCount = $newDoc.account.achievements.count
    flightPathsHaveCount = $newDoc.account.flightpaths.count
    source = "att"
  }) -Force
$public | Add-Member -NotePropertyName "characters" -NotePropertyValue $publicChars.ToArray() -Force
Write-JsonFile $PublicPath $public
Write-Output "Public: $PublicPath ($($publicChars.Count) roster-matched characters)"
