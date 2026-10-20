# Parse the Questie SavedVariables in place (never copied into the repo) into
# the PRIVATE canonical JSON set. Phase 2b parser 4 of 4: quest
# accept/complete/abandon history with timestamps (Questie Journey).
# The Journey lives in the ACCOUNT-level Questie.lua under
# QuestieConfig.char["<name>"].journey; per-character Questie.lua files are
# nil in game and are never read here.
# This is independent of the Dossier addon track: no addon changes here.
# Chattynator content is never read (names/sizes only). Polestar progress is
# never parsed (guides stay pointer-only).
# Usage:
#   powershell -File scripts/parse-questie.ps1 [-WtfRoot <wtf>] [-PrivateDir <dir>]
# Private output: data/private/quest-history.json (gitignored). No public
# output: quest history stays private-local, like gold and mail.
# See docs/canonical-json.md. One source per field: Questie owns quest
# history; Dossier remains the aggregator for what it already exports
# (current quests, completed names/count) and is never overwritten here.
# Parsers are roster-agnostic: every character key actually present in the SV
# is parsed (beta throwaways included); stale short-name session keys
# ("<name> - PvE") resolve to the same canonical id as current full names.

param(
  [string]$WtfRoot = "",
  [string]$PrivateDir = "",
  [long]$MaxFileBytes = 5242880
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent ($PSScriptRoot -replace '^\\\\\?\\','')
. (Join-Path $PSScriptRoot "lua-saved.ps1")
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
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

function Get-FirstToken($text) {
  $t = ([string]$text).Trim()
  if (-not $t) { return "" }
  return (($t -split '\s+'))[0]
}

function Get-NullableLong($value) {
  if ($null -eq $value) { return $null }
  $n = 0
  if ([long]::TryParse([string]$value, [ref]$n)) { return $n }
  return $null
}

# ---- Main: read account SavedVariables in place, merge into private set ----

$questPath = Join-Path $PrivateDir "quest-history.json"
$prev = Read-JsonFile $questPath

$canonicalChars = @()
$charsDoc = Read-JsonFile (Join-Path $PrivateDir "characters.json")
if ($charsDoc -and $charsDoc.characters) { $canonicalChars = @($charsDoc.characters) }

$accountRoot = Join-Path $WtfRoot "Account"
$found = $false
$capped = @()
$charRows = [ordered]@{}
$sources = New-Object System.Collections.Generic.List[object]
foreach ($accountDir in @(Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables") })) {
  $file = Join-Path $accountDir.FullName "SavedVariables\Questie.lua"
  if (-not (Test-Path $file)) { continue }
  $info = Get-Item $file
  if ($info.Length -gt $MaxFileBytes) {
    $capped += $file
    continue
  }
  $found = $true
  $sources.Add([ordered]@{
      file = "Questie.lua"
      account = $accountDir.Name
      sizeBytes = $info.Length
      mtime = $info.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
    })
  $table = Read-LuaSaved $file
  $chars = $null
  if ($table["QuestieConfig"] -is [System.Collections.IDictionary]) { $chars = $table["QuestieConfig"]["char"] }
  if ($chars -isnot [System.Collections.IDictionary]) { continue }
  foreach ($key in $chars.Keys) {
    # Later accounts win on key collision; keys are per-character names so
    # this is a straight union in practice.
    $charRows[[string]$key] = $chars[$key]
  }
}
if ($capped.Count) {
  Write-Warning ("Questie.lua over size cap ($MaxFileBytes bytes), skipped: " + ($capped -join ", "))
}
if (-not $found -and -not $prev) {
  throw "No Questie.lua found under $accountRoot (and no previous quest-history.json to keep)"
}
if (-not $found -and $prev) {
  Write-Warning "No Questie.lua found under $accountRoot; keeping previous quest-history.json ($(@($prev.characters).Count) character keys, parsed $($prev.generatedAt))"
  Write-Output "QUESTIE: source missing, KEPT previous quest-history.json"
  return
}

$characters = New-Object System.Collections.Generic.List[object]
$totalEvents = 0
foreach ($svKey in ($charRows.Keys | Sort-Object)) {
  $row = $charRows[$svKey]
  if ($row -isnot [System.Collections.IDictionary]) { continue }
  $tok = Get-FirstToken ($svKey -replace ' - [^-]+$', '')
  $canonicalId = $null
  foreach ($c in $canonicalChars) {
    $full = if ($c.displayName) { [string]$c.displayName } else { [string]$c.name }
    if ($tok -and ((Get-FirstToken $full) -ieq $tok)) { $canonicalId = [string]$c.id; break }
  }
  $journey = New-Object System.Collections.Generic.List[object]
  $accepts = 0
  $completes = 0
  $levels = 0
  $other = 0
  $raw = $row["journey"]
  if ($raw -is [System.Collections.IList]) {
    foreach ($e in $raw) {
      if ($e -isnot [System.Collections.IDictionary]) { continue }
      $event = [string]$e["Event"]
      $sub = [string]$e["SubType"]
      if ($event -ieq "Quest" -and $sub -ieq "Accept") { $accepts++ }
      elseif ($event -ieq "Quest" -and $sub -ieq "Complete") { $completes++ }
      elseif ($event -ieq "Level") { $levels++ }
      else { $other++ }
      $journey.Add([ordered]@{
          timestamp = (Get-NullableLong $e["Timestamp"])
          timestampIso = (ConvertFrom-EpochLocal $e["Timestamp"])
          event = $event
          subType = $(if ($sub) { $sub } else { $null })
          quest = (Get-NullableLong $e["Quest"])
          level = (Get-NullableLong $e["Level"])
          newLevel = (Get-NullableLong $e["NewLevel"])
        })
      $totalEvents++
    }
  }
  $completeIds = @()
  if ($row["complete"] -is [System.Collections.IDictionary]) {
    foreach ($qid in $row["complete"].Keys) {
      $n = 0
      if ([long]::TryParse([string]$qid, [ref]$n)) { $completeIds += $n }
    }
    $completeIds = @($completeIds | Sort-Object)
  }
  $characters.Add([ordered]@{
      svKey = [string]$svKey
      name = $tok
      canonicalId = $canonicalId
      guid = $(if ($null -ne $row["guid"]) { [string]$row["guid"] } else { $null })
      journey = $journey.ToArray()
      completeIds = $completeIds
      counts = [ordered]@{
        source = "questie"
        events = $journey.Count
        accepts = $accepts
        completes = $completes
        levelUps = $levels
        other = $other
        completeIds = $completeIds.Count
      }
    })
}

$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$newDoc = [ordered]@{
  schemaVersion = 1
  generatedAt = $stamp
  sources = $sources.ToArray()
  count = $totalEvents
  characters = $characters.ToArray()
}

# Ingest safety (Forever beta quirk: an SV can come back empty/reset after a
# patch or a bad logout). Timestamp and diff every ingest; a source that
# parses to zero character keys when the previous ingest had keys WARNS and
# keeps the previous good canonical -- good data is never overwritten with a
# reset file. (Zero journey events with keys still present is NOT a reset:
# current-name keys legitimately carry complete[] with no journey.)
$prevKeys = 0
if ($prev) { $prevKeys = @($prev.characters).Count }
$keepReason = $null
if ($prev -and $characters.Count -eq 0 -and $prevKeys -gt 0) {
  $keepReason = "parsed 0 character keys (previous had $prevKeys); source looks reset"
}
if ($keepReason) {
  Write-Warning ("QUESTIE ingest guard: $keepReason; keeping previous quest-history.json (parsed $($prev.generatedAt))")
  Write-Output "QUESTIE: KEPT previous quest-history.json ($keepReason)"
  return
}

Write-JsonFile $questPath $newDoc
$prevDir = Join-Path $PrivateDir "prev"
if (-not (Test-Path $prevDir)) { New-Item -ItemType Directory -Force -Path $prevDir | Out-Null }
Copy-Item -Force $questPath (Join-Path $prevDir "quest-history.json")
if ($prev) {
  Write-Output ("QUESTIE diff: character keys $prevKeys -> $($characters.Count); journey events $([int]$prev.count) -> $totalEvents")
} else {
  $sourcesText = ($sources.ToArray() | ForEach-Object { "$($_.account) ($($_.sizeBytes) bytes, $($_.mtime))" }) -join "; "
  Write-Output ("QUESTIE: first ingest ($($characters.Count) character keys, $totalEvents journey events; $sourcesText)")
}
foreach ($c in $characters.ToArray()) {
  $match = if ($c.canonicalId) { " -> $($c.canonicalId)" } else { " (no canonical match)" }
  Write-Output ("QUESTIE: $($c.svKey): $($c.counts.events) events ($($c.counts.accepts) accept / $($c.counts.completes) complete / $($c.counts.levelUps) level), $($c.counts.completeIds) complete ids$match")
}
Write-Output "Private: $questPath ($totalEvents events, PRIVATE ONLY -- no public projection)"
