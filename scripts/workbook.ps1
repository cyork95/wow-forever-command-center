# Workbook generator (Phase 1c, Task 2).
# Emits an .xlsx from the PRIVATE canonical JSON into a gitignored output dir.
# Sheets: Roster, one per character, Collections, Economy. This generated
# workbook replaces the hand-kept Forever_Farm_Tracker.xlsx going forward;
# that legacy file is never modified. No external modules: minimal OOXML is
# written with System.IO.Compression. Local-only output, never committed.
# Usage: powershell -File scripts/workbook.ps1 [-PrivateDir <dir>] [-OutPath <file>]

param(
  [string]$PrivateDir = "",
  [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo = Split-Path -Parent (($PSScriptRoot -replace '^\\\\\?\\', ''))
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
if (-not $OutPath) { $OutPath = Join-Path $PrivateDir "workbook\forever-workbook.xlsx" }

function Read-JsonFile($path) {
  if (-not (Test-Path $path)) { return $null }
  return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

function Format-Gold($copper) {
  if ($null -eq $copper) { return "unknown" }
  $n = [long]$copper
  return "$([math]::Floor($n / 10000))g $([math]::Floor(($n % 10000) / 100))s $($n % 100)c"
}

function Sanitize-SheetName($name) {
  $clean = ([string]$name) -replace '[\[\]:\*?/\\]', ' '
  $clean = ($clean -replace '\s+', ' ').Trim()
  if (-not $clean) { $clean = "Sheet" }
  if ($clean.Length -gt 31) { $clean = $clean.Substring(0, 31) }
  return $clean
}

# ---- Minimal xlsx writer (shared strings, no styling) ----
$script:strings = New-Object System.Collections.Generic.List[string]
$script:stringIndex = @{}
function Add-SharedString($text) {
  $key = [string]$text
  if ($script:stringIndex.ContainsKey($key)) { return $script:stringIndex[$key] }
  $id = $script:strings.Count
  $script:strings.Add($key)
  $script:stringIndex[$key] = $id
  return $id
}
function Escape-Xml($text) {
  return (([string]$text) -replace ([string][char]38, ([string][char]38 + 'amp;')) -replace ([string][char]60, ([string][char]60 + 'lt;')) -replace ([string][char]62, ([string][char]62 + 'gt;')))
}
function ConvertTo-ColumnName($index) {
  $name = ""
  $i = $index
  do { $name = [char](65 + ($i % 26)) + $name; $i = [math]::Floor($i / 26) - 1 } while ($i -ge 0)
  return $name
}

function ConvertTo-SheetXml($rows) {
  $sb = New-Object System.Text.StringBuilder
  $sq = [char]39; $lt = '<'
  [void]$sb.Append($lt + '?xml version=' + $sq + '1.0' + $sq + ' encoding=' + $sq + 'UTF-8' + $sq + ' standalone=' + $sq + 'yes' + $sq + '?><worksheet xmlns=' + $sq + 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' + $sq + '><sheetData>') 
  $r = 1
  foreach ($row in $rows) {
    [void]$sb.Append($lt + 'row r=' + $sq + $r + $sq + '>')
    $c = 0
    foreach ($value in $row) {
      $ref = ((ConvertTo-ColumnName $c) + $r)
      if ($null -eq $value -or $value -eq '') { [void]$sb.Append($lt + 'c r=' + $sq + $ref + $sq + '/>') }
      elseif ($value -is [int] -or $value -is [long] -or $value -is [double]) { [void]$sb.Append($lt + 'c r=' + $sq + $ref + $sq + '><v>' + $value + $lt + '/v></c>') }
    else { $id = Add-SharedString $value; [void]$sb.Append($lt + 'c r=' + $sq + $ref + $sq + ' t=' + $sq + 's' + $sq + '><v>' + $id + $lt + '/v></c>') }
      $c++
    }
    [void]$sb.Append('</row>')
    $r++
  }
  [void]$sb.Append('</sheetData></worksheet>')
  return $sb.ToString()
}
function Build-Sheets($charsDoc, $collDoc, $econDoc) {
  $sheets = @()
  $roster = @(,@('Character', 'Race', 'Class', 'Level', 'Zone', 'Gold', 'Professions', 'Completed quests', 'Kills'))
  foreach ($char in @($charsDoc.characters)) {
    $profs = @($char.professions | ForEach-Object { "$($_.name) $($_.current)/$($_.max)" }) -join ', '
    $roster += ,@($char.name, $char.race, $char.className, $char.level, $char.location.zone, (Format-Gold $char.goldCopper), $profs, $char.quests.completedCount, $char.kills.total)
  }
  $sheets += ,@{ name = 'Roster'; rows = $roster }
  foreach ($char in @($charsDoc.characters)) {
    $rows = @(,@('Field', 'Value'))
    $rows += ,@('Name', $char.name)
    $rows += ,@('Realm', $char.realm)
    $rows += ,@('Race / Class', "$($char.race) / $($char.className)")
    $rows += ,@('Level', $char.level)
    $rows += ,@('Zone', $char.location.zone)
    $rows += ,@('Gold', (Format-Gold $char.goldCopper))
    foreach ($prof in @($char.professions)) { $rows += ,@("Profession: $($prof.name)", "$($prof.current)/$($prof.max)") }
    foreach ($rep in @($char.reputations)) { $rows += ,@("Reputation: $($rep.name)", "$($rep.standing) $($rep.value)/$($rep.max)") }
    $rows += ,@('Completed quests', $char.quests.completedCount)
    $rows += ,@('Kills', $char.kills.total)
    $rows += ,@('', '')
    $rows += ,@('Gear slot', 'Item (iLvl, quality)')
    foreach ($piece in @($char.gear)) { $rows += ,@($piece.slot, "$($piece.name) ($($piece.itemLevel), $($piece.quality))") }
    $sheets += ,@{ name = (Sanitize-SheetName $char.name); rows = $rows }
  }
  $collRows = @(,@('Character', 'Mounts', 'Battle pets', 'Toys', 'Completed quests'))
  foreach ($entry in @($collDoc.characters)) {
    $collRows += ,@($entry.id, "$($entry.collections.mounts.have)/$($entry.collections.mounts.total)", "$($entry.collections.battlePets.have)/$($entry.collections.battlePets.total)", "$($entry.collections.toys.have)/$($entry.collections.toys.total)", $entry.completedQuestCount)
  }
  $sheets += ,@{ name = 'Collections'; rows = $collRows }
  $econRows = @(,@('Character', 'Gold (copper)', 'Gold', 'Wealth notes'))
  foreach ($entry in @($econDoc.characters)) {
    $econRows += ,@($entry.id, $entry.goldCopper, (Format-Gold $entry.goldCopper), ((@($entry.wealth) | Select-Object -First 3) -join ' | '))
  }
  $sheets += ,@{ name = 'Economy'; rows = $econRows }
  return $sheets
}

# ---- Package ----
$charsDoc = Read-JsonFile (Join-Path $PrivateDir 'characters.json')
$collDoc = Read-JsonFile (Join-Path $PrivateDir 'collections.json')
$econDoc = Read-JsonFile (Join-Path $PrivateDir 'economy.json')
if (-not $charsDoc -or -not @($charsDoc.characters).Count) { throw "No canonical characters in $PrivateDir. Run scripts/parse-dossier-export.ps1 first." }
$sheets = Build-Sheets $charsDoc $collDoc $econDoc
$q = [char]34
$sheetXml = @()
$sheetRefs = @()
$n = 0
foreach ($sheet in $sheets) {
  $n++
  $sheetXml += ,(ConvertTo-SheetXml $sheet.rows)
  $sheetRefs += ,(@{ id = "rId$($n + 1)"; name = $sheet.name })
}
$workbookSheets = ''
foreach ($ref in $sheetRefs) { $workbookSheets += '<sheet name=' + $q + $ref.name + $q + ' sheetId=' + $q + "$($sheetRefs.IndexOf($ref) + 1)" + $q + ' r:id=' + $q + $ref.id + $q + '/>' }
$shared = ''
foreach ($text in $script:strings) { $shared += '<si><t>' + (Escape-Xml $text) + '</t></si>' }
$sheetOverrides = ''
$i = 0
foreach ($xml in $sheetXml) { $i++; $sheetOverrides += '<Override PartName=' + $q + "/xl/worksheets/sheet$i.xml" + $q + ' ContentType=' + $q + 'application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml' + $q + '/>' }
$workbookRels = '<Relationships xmlns=' + $q + 'http://schemas.openxmlformats.org/package/2006/relationships' + $q + '>'
$i = 0
foreach ($xml in $sheetXml) { $i++; $workbookRels += '<Relationship Id=' + $q + "rId$($i + 1)" + $q + ' Type=' + $q + 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet' + $q + ' Target=' + $q + "worksheets/sheet$i.xml" + $q + '/>' }
$workbookRels += '<Relationship Id=' + $q + 'rId99' + $q + ' Type=' + $q + 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings' + $q + ' Target=' + $q + 'sharedStrings.xml' + $q + '/>' + '<Relationship Id=' + $q + 'rId100' + $q + ' Type=' + $q + 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles' + $q + ' Target=' + $q + 'styles.xml' + $q + '/>' + '</Relationships>'
$contentTypes = '<?xml version=' + $q + '1.0' + $q + '?>' + '<Types xmlns=' + $q + 'http://schemas.openxmlformats.org/package/2006/content-types' + $q + '><Default Extension=' + $q + 'rels' + $q + ' ContentType=' + $q + 'application/vnd.openxmlformats-package.relationships+xml' + $q + '/><Default Extension=' + $q + 'xml' + $q + ' ContentType=' + $q + 'application/xml' + $q + '/><Override PartName=' + $q + '/xl/workbook.xml' + $q + ' ContentType=' + $q + 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml' + $q + '/><Override PartName=' + $q + '/xl/sharedStrings.xml' + $q + ' ContentType=' + $q + 'application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml' + $q + '/><Override PartName=' + $q + '/xl/styles.xml' + $q + ' ContentType=' + $q + 'application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml' + $q + '/>' + $sheetOverrides + '</Types>'
$rels = '<?xml version=' + $q + '1.0' + $q + '?>' + '<Relationships xmlns=' + $q + 'http://schemas.openxmlformats.org/package/2006/relationships' + $q + '><Relationship Id=' + $q + 'rId1' + $q + ' Type=' + $q + 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' + $q + ' Target=' + $q + 'xl/workbook.xml' + $q + '/></Relationships>'
$styles = '<?xml version=' + $q + '1.0' + $q + '?>' + '<styleSheet xmlns=' + $q + 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' + $q + '><fonts count=' + $q + '1' + $q + '><font><sz val=' + $q + '11' + $q + '/><name val=' + $q + 'Calibri' + $q + '/></font></fonts><fills count=' + $q + '1' + $q + '><fill><patternFill patternType=' + $q + 'none' + $q + '/></fill></fills><borders count=' + $q + '1' + $q + '><border/></borders><cellStyleXfs count=' + $q + '1' + $q + '><xf numFmtId=' + $q + '0' + $q + ' fontId=' + $q + '0' + $q + ' fillId=' + $q + '0' + $q + ' borderId=' + $q + '0' + $q + '/></cellStyleXfs><cellXfs count=' + $q + '1' + $q + '><xf numFmtId=' + $q + '0' + $q + ' fontId=' + $q + '0' + $q + ' fillId=' + $q + '0' + $q + ' borderId=' + $q + '0' + $q + ' xfId=' + $q + '0' + $q + '/></cellXfs></styleSheet>'
$dir = Split-Path -Parent $OutPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
if (Test-Path $OutPath) { Remove-Item -Force $OutPath }
$utf8 = New-Object System.Text.UTF8Encoding $false
$zip = [System.IO.Compression.ZipFile]::Open($OutPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  $add = { param($entryName, $content) $entry = $zip.CreateEntry($entryName); $writer = New-Object System.IO.StreamWriter($entry.Open(), $utf8); $writer.Write($content); $writer.Dispose() }
  &$add '[Content_Types].xml' $contentTypes
  &$add '_rels/.rels' $rels
  &$add 'xl/_rels/workbook.xml.rels' $workbookRels
  &$add 'xl/workbook.xml' ('<?xml version=' + $q + '1.0' + $q + '?>' + '<workbook xmlns=' + $q + 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' + $q + ' xmlns:r=' + $q + 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' + $q + '><sheets>' + $workbookSheets + '</sheets></workbook>')
  &$add 'xl/sharedStrings.xml' ('<?xml version=' + $q + '1.0' + $q + '?>' + '<sst xmlns=' + $q + 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' + $q + ' count=' + $q + $script:strings.Count + $q + ' uniqueCount=' + $q + $script:strings.Count + $q + '>' + $shared + '</sst>')
  &$add 'xl/styles.xml' $styles
  $i = 0
  foreach ($xml in $sheetXml) { $i++; &$add "xl/worksheets/sheet$i.xml" $xml }
} finally { $zip.Dispose() }
Write-Output "Wrote $OutPath ($($sheets.Count) sheets)"

