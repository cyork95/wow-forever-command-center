# Writes import CSVs for the command-center Google Sheet.
# Output stays in scripts/sheets/seed/ and is not committed.
# Book ids must match bookSheetId in assets/app.js.

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$out = Join-Path $PSScriptRoot "seed"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$characterColumns = @(
  "skyrinis", "sorinis", "taloninis", "lucinis", "vesperinis",
  "malavus", "bramblebeard", "flann", "ullrathor", "trendirun"
)

function ConvertTo-CsvField([string]$Value) {
  if ($null -eq $Value) { return "" }
  $text = [string]$Value
  if ($text -match '[",\r\n]') {
    return '"' + ($text -replace '"', '""') + '"'
  }
  return $text
}

function Join-CsvRow([string[]]$Cells) {
  return ($Cells | ForEach-Object { ConvertTo-CsvField $_ }) -join ","
}

function Get-BookSheetId([string]$Name) {
  $slug = $Name.ToLowerInvariant()
  $slug = $slug -replace "['’]", ""
  $slug = $slug -replace "[^a-z0-9]+", "-"
  $slug = $slug.Trim("-")
  return "book:$slug"
}

function Get-PipeList($Value) {
  if ($null -eq $Value) { return "" }
  $items = @($Value) | ForEach-Object { [string]$_ } | Where-Object { $_ }
  return ($items -join "|")
}

function Get-ProfessionText($Skills) {
  if ($null -eq $Skills) { return "" }
  $parts = @()
  foreach ($skill in @($Skills)) {
    if (-not $skill.name) { continue }
    if ($skill.max) {
      $parts += "$($skill.name) $($skill.current)/$($skill.max)"
    } elseif ($null -ne $skill.current) {
      $parts += "$($skill.name) $($skill.current)"
    } else {
      $parts += [string]$skill.name
    }
  }
  return ($parts -join ", ")
}

function Write-CsvFile([string]$Path, [string[]]$Lines) {
  $utf8 = New-Object System.Text.UTF8Encoding $true
  [System.IO.File]::WriteAllLines($Path, $Lines, $utf8)
}

$roster = Get-Content (Join-Path $root "data\characters.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$checklist = Get-Content (Join-Path $root "data\checklist.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$stats = Get-Content (Join-Path $root "data\stats.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$books = Get-Content (Join-Path $root "data\library-books.json") -Raw -Encoding UTF8 | ConvertFrom-Json

$snapshots = @{}
foreach ($prop in $stats.characters.PSObject.Properties) {
  $snapshots[$prop.Name] = $prop.Value
}

$characterHeader = @(
  "id", "name", "realm", "level", "zone", "subzone", "goldCopper",
  "health", "powerType", "playedSeconds", "exportedAt", "professions", "snapshot"
)
$characterLines = @(Join-CsvRow $characterHeader)
foreach ($person in @($roster)) {
  $live = $snapshots[$person.id]
  $snapshot = "{}"
  $realm = ""
  $level = ""
  $zone = ""
  $subzone = ""
  $gold = ""
  $health = ""
  $powerType = ""
  $played = ""
  $exportedAt = ""
  $professions = ""
  if ($live) {
    $snapshot = $live | ConvertTo-Json -Depth 30 -Compress
    $realm = [string]$live.realm
    if ($null -ne $live.level) { $level = [string]$live.level }
    $zone = [string]$live.zone
    $subzone = [string]$live.subzone
    if ($null -ne $live.goldCopper) { $gold = [string]$live.goldCopper }
    $health = [string]$live.health
    $powerType = [string]$live.powerType
    if ($null -ne $live.playedSeconds) { $played = [string]$live.playedSeconds }
    $exportedAt = [string]$live.exportedAt
    $professions = Get-ProfessionText $live.professions
  }
  $characterLines += Join-CsvRow @(
    $person.id, $person.name, $realm, $level, $zone, $subzone, $gold,
    $health, $powerType, $played, $exportedAt, $professions, $snapshot
  )
}

$huntHeader = @(
  "id", "parentId", "name", "type", "zone", "minLevel", "priority", "status",
  "owners", "notes", "how", "source", "mobs", "need", "defaultDone"
) + $characterColumns + @("tries")
$huntLines = @(Join-CsvRow $huntHeader)

function Add-HuntRow($Id, $ParentId, $Name, $Type, $Zone, $MinLevel, $Priority, $Status, $Owners, $Notes, $How, $Source, $Mobs, $Need, [bool]$DefaultDone) {
  $flag = "FALSE"
  if ($DefaultDone) { $flag = "TRUE" }
  $checks = @()
  foreach ($unused in $characterColumns) { $checks += $flag }
  $script:huntLines += Join-CsvRow (@(
    $Id, $ParentId, $Name, $Type, $Zone, $MinLevel, $Priority, $Status,
    $Owners, $Notes, $How, $Source, $Mobs, $Need, $flag
  ) + $checks + @("{}"))
}

foreach ($hunt in @($checklist)) {
  $done = $false
  if ($hunt.defaultDone -eq $true) { $done = $true }
  $need = ""
  if ($null -ne $hunt.need) { $need = [string]$hunt.need }
  $minLevel = ""
  if ($null -ne $hunt.minLevel) { $minLevel = [string]$hunt.minLevel }
  Add-HuntRow $hunt.id "" $hunt.name $hunt.type $hunt.zone $minLevel $hunt.priority $hunt.status (Get-PipeList $hunt.owners) ([string]$hunt.notes) ([string]$hunt.how) ([string]$hunt.source) (Get-PipeList $hunt.mobs) $need $done
  foreach ($part in @($hunt.parts)) {
    if (-not $part -or -not $part.id) { continue }
    Add-HuntRow $part.id $hunt.id $part.name "" "" "" "" "" "" "" ([string]$part.how) "" (Get-PipeList $part.mobs) "" $false
  }
}

$seenBooks = @{}
foreach ($book in @($books.books)) {
  if (-not $book.name) { continue }
  $id = Get-BookSheetId $book.name
  if ($seenBooks.ContainsKey($id)) { continue }
  $seenBooks[$id] = $true
  $notes = (@($book.notes) | ForEach-Object { [string]$_ } | Where-Object { $_ }) -join " "
  Add-HuntRow $id "" $book.name "Library" ([string]$book.zone) "" "" "" "" $notes ([string]$book.location) ([string]$books.source) "" "" $false
}

$taskHeader = @("id", "name", "cadence", "zone", "notes") + $characterColumns
$taskLines = @(Join-CsvRow $taskHeader)

$configLines = @(
  (Join-CsvRow @("id", "name"))
)
foreach ($person in @($roster)) {
  $configLines += Join-CsvRow @($person.id, $person.name)
}

$importLines = @(
  (Join-CsvRow @("note", "json")),
  (Join-CsvRow @("Paste the character JSON in the json column, then Command center, Parse import.", ""))
)

Write-CsvFile (Join-Path $out "characters.csv") $characterLines
Write-CsvFile (Join-Path $out "hunts.csv") $huntLines
Write-CsvFile (Join-Path $out "tasks.csv") $taskLines
Write-CsvFile (Join-Path $out "config.csv") $configLines
Write-CsvFile (Join-Path $out "import.csv") $importLines

Write-Output "Wrote seed CSVs to $out"
Write-Output ("Characters: " + (@($roster).Count))
Write-Output ("Hunt rows: " + ($huntLines.Count - 1))
Write-Output ("Sample book id: " + (Get-BookSheetId "Archmage Theocritus' Research Journal"))
