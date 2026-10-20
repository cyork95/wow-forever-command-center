# Parse the Rarity SavedVariables in place (never copied into the repo) into
# the PRIVATE canonical JSON set. Phase 2b parser 3 of 4: per-collectible
# attempts / time / luck. ATTEMPTS LAYER ONLY -- Rarity never decides
# have/want (that is ATT's field); have/want is deliberately NOT extracted.
# This is independent of the Dossier addon track: no addon changes here.
# Chattynator content is never read (names/sizes only). Polestar progress is
# never parsed (guides stay pointer-only).
# Usage:
#   powershell -File scripts/parse-rarity.ps1 [-WtfRoot <wtf>] [-PrivateDir <dir>]
# Private output: data/private/rarity.json (gitignored). No public output:
# attempt histories stay private-local, like gold and mail.
# See docs/canonical-json.md. One source per field: Rarity owns attempts;
# Collection History owns the obtained-timeline; ATT owns have/want; Dossier
# remains the aggregator for what it already exports. An honest empty result
# (zero attempts recorded) is correct output, not a failure -- attempts are
# never manufactured. Per-item SavedVariables fields follow the installed
# addon's DB/Item.lua expectedFields (attempts, lastAttempts, realAttempts,
# enabled, known, finds, found, totalFinds, time, lastTime).

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

$rarityPath = Join-Path $PrivateDir "rarity.json"
$prev = Read-JsonFile $rarityPath

$canonicalChars = @()
$charsDoc = Read-JsonFile (Join-Path $PrivateDir "characters.json")
if ($charsDoc -and $charsDoc.characters) { $canonicalChars = @($charsDoc.characters) }

$accountRoot = Join-Path $WtfRoot "Account"
$found = $false
$capped = @()
$profiles = [ordered]@{}
$profileKeys = [ordered]@{}
$sources = New-Object System.Collections.Generic.List[object]
foreach ($accountDir in @(Get-ChildItem -Path $accountRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SavedVariables") })) {
  $file = Join-Path $accountDir.FullName "SavedVariables\Rarity.lua"
  if (-not (Test-Path $file)) { continue }
  $info = Get-Item $file
  if ($info.Length -gt $MaxFileBytes) {
    $capped += $file
    continue
  }
  $found = $true
  $sources.Add([ordered]@{
      file = "Rarity.lua"
      account = $accountDir.Name
      sizeBytes = $info.Length
      mtime = $info.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
    })
  $table = Read-LuaSaved $file
  $db = $table["RarityDB"]
  if ($db -isnot [System.Collections.IDictionary]) { continue }
  if ($db["profiles"] -is [System.Collections.IDictionary]) {
    foreach ($key in $db["profiles"].Keys) { $profiles[[string]$key] = $db["profiles"][$key] }
  }
  if ($db["profileKeys"] -is [System.Collections.IDictionary]) {
    foreach ($key in $db["profileKeys"].Keys) { $profileKeys[[string]$key] = [string]$db["profileKeys"][$key] }
  }
}
if ($capped.Count) {
  Write-Warning ("Rarity.lua over size cap ($MaxFileBytes bytes), skipped: " + ($capped -join ", "))
}
if (-not $found -and -not $prev) {
  throw "No Rarity.lua found under $accountRoot (and no previous rarity.json to keep)"
}
if (-not $found -and $prev) {
  Write-Warning "No Rarity.lua found under $accountRoot; keeping previous rarity.json ($(@($prev.items).Count) items, parsed $($prev.generatedAt))"
  Write-Output "RARITY: source missing, KEPT previous rarity.json"
  return
}

$items = New-Object System.Collections.Generic.List[object]
$totalAttempts = 0
$itemsWithAttempts = 0
foreach ($profileName in ($profiles.Keys | Sort-Object)) {
  $profile = $profiles[$profileName]
  $groups = $null
  if ($profile -is [System.Collections.IDictionary]) { $groups = $profile["groups"] }
  if ($groups -isnot [System.Collections.IDictionary]) { continue }
  foreach ($groupName in ($groups.Keys | Sort-Object)) {
    $group = $groups[$groupName]
    if ($group -isnot [System.Collections.IDictionary]) { continue }
    foreach ($itemName in ($group.Keys | Sort-Object)) {
      $raw = $group[$itemName]
      if ($raw -isnot [System.Collections.IDictionary]) { continue }
      $attempts = Get-NullableLong $raw["attempts"]
      if ($attempts -gt 0) {
        $itemsWithAttempts++
        $totalAttempts += $attempts
      }
      $items.Add([ordered]@{
          profile = [string]$profileName
          group = [string]$groupName
          name = [string]$itemName
          known = $(if ($null -ne $raw["known"]) { [bool]$raw["known"] } else { $null })
          enabled = $(if ($null -ne $raw["enabled"]) { [bool]$raw["enabled"] } else { $null })
          found = $(if ($null -ne $raw["found"]) { [bool]$raw["found"] } else { $null })
          attempts = $attempts
          lastAttempts = (Get-NullableLong $raw["lastAttempts"])
          realAttempts = (Get-NullableLong $raw["realAttempts"])
          finds = (Get-NullableLong $raw["finds"])
          totalFinds = (Get-NullableLong $raw["totalFinds"])
          time = (Get-NullableLong $raw["time"])
          lastTime = (Get-NullableLong $raw["lastTime"])
        })
    }
  }
}

$statistics = New-Object System.Collections.Generic.List[object]
foreach ($profileName in ($profiles.Keys | Sort-Object)) {
  $profile = $profiles[$profileName]
  $aws = $null
  if ($profile -is [System.Collections.IDictionary]) { $aws = $profile["accountWideStatistics"] }
  if ($aws -isnot [System.Collections.IDictionary]) { continue }
  foreach ($guid in ($aws.Keys | Sort-Object)) {
    $entry = $aws[$guid]
    if ($entry -isnot [System.Collections.IDictionary]) { continue }
    $playerName = [string]$entry["playerName"]
    $tok = Get-FirstToken $playerName
    $canonicalId = $null
    foreach ($c in $canonicalChars) {
      $full = if ($c.displayName) { [string]$c.displayName } else { [string]$c.name }
      if ($tok -and ((Get-FirstToken $full) -ieq $tok)) { $canonicalId = [string]$c.id; break }
    }
    $stats = New-Object System.Collections.Generic.List[object]
    if ($entry["statistics"] -is [System.Collections.IDictionary]) {
      foreach ($sid in $entry["statistics"].Keys) {
        $n = 0
        $idOut = $(if ([long]::TryParse([string]$sid, [ref]$n)) { $n } else { [string]$sid })
        $stats.Add([ordered]@{ id = $idOut; value = (Get-NullableLong $entry["statistics"][$sid]) })
      }
    }
    $statistics.Add([ordered]@{
        profile = [string]$profileName
        guid = [string]$guid
        playerName = $playerName
        server = [string]$entry["server"]
        canonicalId = $canonicalId
        statistics = $stats.ToArray()
      })
  }
}

$tracked = [ordered]@{}
foreach ($profileName in ($profiles.Keys | Sort-Object)) {
  $profile = $profiles[$profileName]
  if ($profile -isnot [System.Collections.IDictionary]) { continue }
  $tracked[[string]$profileName] = [ordered]@{
    group = $(if ($null -ne $profile["trackedGroup"]) { [string]$profile["trackedGroup"] } else { $null })
    item = $(if ($null -ne $profile["trackedItem"]) { [string]$profile["trackedItem"] } else { $null })
  }
}

$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$newDoc = [ordered]@{
  schemaVersion = 1
  generatedAt = $stamp
  sources = $sources.ToArray()
  summary = [ordered]@{
    source = "rarity"
    itemsTracked = $items.Count
    itemsWithAttempts = $itemsWithAttempts
    totalAttempts = $totalAttempts
  }
  tracked = $tracked
  items = $items.ToArray()
  statistics = $statistics.ToArray()
}

# Ingest safety (Forever beta quirk: an SV can come back empty/reset after a
# patch or a bad logout). Timestamp and diff every ingest; a source that
# parses to zero items when the previous ingest had items WARNS and keeps the
# previous good canonical -- good data is never overwritten with a reset file.
# (Zero attempts with items still present is NOT a reset: it is the honest
# empty state and overwrites normally.)
$prevItems = 0
if ($prev) { $prevItems = @($prev.items).Count }
$keepReason = $null
if ($prev -and $items.Count -eq 0 -and $prevItems -gt 0) {
  $keepReason = "parsed 0 tracked items (previous had $prevItems); source looks reset"
}
if ($keepReason) {
  Write-Warning ("RARITY ingest guard: $keepReason; keeping previous rarity.json (parsed $($prev.generatedAt))")
  Write-Output "RARITY: KEPT previous rarity.json ($keepReason)"
  return
}

Write-JsonFile $rarityPath $newDoc
$prevDir = Join-Path $PrivateDir "prev"
if (-not (Test-Path $prevDir)) { New-Item -ItemType Directory -Force -Path $prevDir | Out-Null }
Copy-Item -Force $rarityPath (Join-Path $prevDir "rarity.json")
if ($prev) {
  Write-Output ("RARITY diff: items $prevItems -> $($items.Count); with attempts $([int]$prev.summary.itemsWithAttempts) -> $itemsWithAttempts; total attempts $([int]$prev.summary.totalAttempts) -> $totalAttempts")
} else {
  $sourcesText = ($sources.ToArray() | ForEach-Object { "$($_.account) ($($_.sizeBytes) bytes, $($_.mtime))" }) -join "; "
  Write-Output ("RARITY: first ingest ($($items.Count) items, $itemsWithAttempts with attempts, $totalAttempts total attempts; $sourcesText)")
}
foreach ($item in $items.ToArray()) {
  $att = if ($null -ne $item.attempts) { "attempts $($item.attempts)" } else { "no attempts recorded" }
  Write-Output ("RARITY: [$($item.group)] $($item.name) (known $($item.known), found $($item.found)): $att")
}
Write-Output "Private: $rarityPath ($($items.Count) items, PRIVATE ONLY -- no public projection)"
