# Parse the ATT Collection History SavedVariables in place (never copied into
# the repo) into the PRIVATE canonical JSON set. Phase 2b parser 2 of 4: the
# obtained-timeline -- history[] with collectedAt timestamps, first-class.
# This is independent of the Dossier addon track: no addon changes here.
# Chattynator content is never read (names/sizes only). Polestar progress is
# never parsed (guides stay pointer-only).
# Usage:
#   powershell -File scripts/parse-att-history.ps1 [-WtfRoot <wtf>] [-PrivateDir <dir>] [-PublicPath <file>]
# Private output: data/private/collection-history.json (gitignored).
# Public output:  data/att.public.json gains obtainedTimeline/obtainedCount
# (public-safe names + timestamps; other keys preserved).
# See docs/canonical-json.md. One source per field: Collection History owns
# the obtained-timeline; ATT owns have/want; Dossier remains the aggregator
# for what it already exports. History entries carry no character attribution
# in the SV, so the timeline is account-wide by construction.

param(
  [string]$WtfRoot = "",
  [string]$PrivateDir = "",
  [string]$PublicPath = "",
  [long]$MaxFileBytes = 5242880
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent ($PSScriptRoot -replace '^\\\\\?\\','')
. (Join-Path $PSScriptRoot "lua-saved.ps1")
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
if (-not $PublicPath) { $PublicPath = Join-Path $repo "data\att.public.json" }
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

function Get-HistoryItemId($text) {
  if ($text -isnot [string]) { return $null }
  if ($text -match '\|Hitem:(\d+)') { return [long]$Matches[1] }
  return $null
}

# Clean display name from ATT history text: hyperlink-wrapped item names come
# out of the |h brackets, colour codes are stripped, plain quest text passes
# through untouched.
function Get-HistoryName($text) {
  if ($text -isnot [string]) { return "" }
  if ($text -match '\|h\[([^\]]+)\]\|h') { return $Matches[1].Trim() }
  $clean = $text -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', ''
  $clean = $clean -replace '\|cn[A-Z0-9]+:', ''
  return $clean.Trim()
}

# ---- Main: read account SavedVariables in place, merge into private set ----

$historyPath = Join-Path $PrivateDir "collection-history.json"
$prev = Read-JsonFile $historyPath

$accountRoot = Join-Path $WtfRoot "Account"
$found = $false
$capped = @()
$rawEntries = New-Object System.Collections.Generic.List[object]
$sources = New-Object System.Collections.Generic.List[object]
foreach ($accountDir in @(Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables") })) {
  $file = Join-Path $accountDir.FullName "SavedVariables\ATTCollectionHistory.lua"
  if (-not (Test-Path $file)) { continue }
  $info = Get-Item $file
  if ($info.Length -gt $MaxFileBytes) {
    $capped += $file
    continue
  }
  $found = $true
  $sources.Add([ordered]@{
      file = "ATTCollectionHistory.lua"
      account = $accountDir.Name
      sizeBytes = $info.Length
      mtime = $info.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
    })
  $table = Read-LuaSaved $file
  $db = $table["ATTCollectionHistoryDB"]
  $hist = $null
  if ($db -is [System.Collections.IDictionary]) { $hist = $db["history"] }
  if ($hist -is [System.Collections.IList]) {
    foreach ($entry in $hist) { $rawEntries.Add($entry) }
  }
}
if ($capped.Count) {
  Write-Warning ("ATTCollectionHistory.lua over size cap ($MaxFileBytes bytes), skipped: " + ($capped -join ", "))
}
if (-not $found -and -not $prev) {
  throw "No ATTCollectionHistory.lua found under $accountRoot (and no previous collection-history.json to keep)"
}
if (-not $found -and $prev) {
  Write-Warning "No ATTCollectionHistory.lua found under $accountRoot; keeping previous collection-history.json ($(@($prev.entries).Count) entries, parsed $($prev.generatedAt))"
  Write-Output "ATT-HISTORY: source missing, KEPT previous collection-history.json"
  return
}

$entries = New-Object System.Collections.Generic.List[object]
$typeCounts = [ordered]@{}
foreach ($entry in $rawEntries.ToArray()) {
  if ($entry -isnot [System.Collections.IDictionary]) { continue }
  $type = [string]$entry["type"]
  if (-not $type) { $type = "Unknown" }
  if (-not $typeCounts.Contains($type)) { $typeCounts[$type] = 0 }
  $typeCounts[$type]++
  $entries.Add([ordered]@{
      collectedAt = [string]$entry["collectedAt"]
      type = $type
      name = (Get-HistoryName $entry["text"])
      itemId = (Get-HistoryItemId $entry["text"])
      raw = [string]$entry["text"]
    })
}

$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$newDoc = [ordered]@{
  schemaVersion = 1
  generatedAt = $stamp
  sources = $sources.ToArray()
  count = $entries.Count
  types = $typeCounts
  entries = $entries.ToArray()
}

# Ingest safety (Forever beta quirk: an SV can come back empty/reset after a
# patch or a bad logout). Timestamp and diff every ingest; a source that
# shrinks unexpectedly or parses to zero entries WARNS and keeps the previous
# good canonical -- good data is never overwritten with a reset file.
$prevCount = 0
if ($prev) { $prevCount = [int]$prev.count }
$keepReason = $null
if ($prev -and $entries.Count -eq 0 -and $prevCount -gt 0) {
  $keepReason = "parsed 0 history entries (previous had $prevCount); source looks reset"
} else {
  $prevBytes = 0
  foreach ($s in @($prev.sources)) { $prevBytes += [long]$s.sizeBytes }
  $newBytes = 0
  foreach ($s in $sources.ToArray()) { $newBytes += [long]$s.sizeBytes }
  if ($prev -and $newBytes -lt $prevBytes -and $entries.Count -lt $prevCount) {
    $keepReason = "source shrank ($prevBytes -> $newBytes bytes) and entries dropped ($prevCount -> $($entries.Count))"
  }
}
if ($keepReason) {
  Write-Warning ("ATT-HISTORY ingest guard: $keepReason; keeping previous collection-history.json (parsed $($prev.generatedAt))")
  Write-Output "ATT-HISTORY: KEPT previous collection-history.json ($keepReason)"
  return
}

Write-JsonFile $historyPath $newDoc
$prevDir = Join-Path $PrivateDir "prev"
if (-not (Test-Path $prevDir)) { New-Item -ItemType Directory -Force -Path $prevDir | Out-Null }
Copy-Item -Force $historyPath (Join-Path $prevDir "collection-history.json")
$typeText = (($typeCounts.Keys | ForEach-Object { "$_ $($typeCounts[$_])" }) -join ", ")
if ($prev) {
  Write-Output ("ATT-HISTORY diff: entries $prevCount -> $($entries.Count) ($typeText)")
} else {
  $sourcesText = ($sources.ToArray() | ForEach-Object { "$($_.account) ($($_.sizeBytes) bytes, $($_.mtime))" }) -join "; "
  Write-Output ("ATT-HISTORY: first ingest ($($entries.Count) entries: $typeText; $sourcesText)")
}
Write-Output "Private: $historyPath ($($entries.Count) entries)"

# Public redaction (allowlist): names + timestamps + type are public-safe;
# raw colour-code text stays private. Other att.public.json keys (written by
# parse-att.ps1) are preserved, never overwritten.
$public = Read-JsonFile $PublicPath
if (-not $public) { $public = [ordered]@{ schemaVersion = 1 } }
$public.schemaVersion = 1
$public | Add-Member -NotePropertyName "generatedAt" -NotePropertyValue $stamp -Force
$timeline = New-Object System.Collections.Generic.List[object]
foreach ($e in $entries.ToArray()) {
  $timeline.Add([ordered]@{
      collectedAt = $e.collectedAt
      type = $e.type
      name = $e.name
      itemId = $e.itemId
    })
}
$public | Add-Member -NotePropertyName "obtainedTimeline" -NotePropertyValue $timeline.ToArray() -Force
$public | Add-Member -NotePropertyName "obtainedCount" -NotePropertyValue $entries.Count -Force
Write-JsonFile $PublicPath $public
Write-Output "Public: $PublicPath (obtainedTimeline $($entries.Count) entries)"
