# Butler pack generator (Phase 1c, Task 1).
# Emits one Markdown file per character in the PRIVATE canonical JSON into a
# gitignored output dir, with a "What changed since last export" section
# diffed against the previous private snapshot (retained under prev/).
# Gold and ledger detail ARE included: this output is local-only, never
# committed. See docs/canonical-json.md.
# Usage: powershell -File scripts/butler-pack.ps1 [-PrivateDir <dir>] [-OutDir <dir>] [-GuidesPath <file>]

param(
  [string]$PrivateDir = "",
  [string]$OutDir = "",
  [string]$GuidesPath = ""
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (($PSScriptRoot -replace '^\\\\\?\\', ''))
if (-not $PrivateDir) { $PrivateDir = Join-Path $repo "data\private" }
if (-not $OutDir) { $OutDir = Join-Path $PrivateDir "butler" }

function Read-JsonFile($path) {
  if (-not (Test-Path $path)) { return $null }
  return (Get-Content -Raw -Path $path | ConvertFrom-Json)
}

function Format-Gold($copper) {
  if ($null -eq $copper) { return "unknown" }
  $n = [long]$copper
  $g = [math]::Floor($n / 10000)
  $s = [math]::Floor(($n % 10000) / 100)
  $c = $n % 100
  return "${g}g ${s}s ${c}c"
}

function Get-StackLabel($count, $word) {
  if ($count -eq 1) { return "1 $word" }
  return "$count $($word)s"
}

function Write-Pack($path, $lines) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, ($lines -join "`n") + "`n", $utf8)
}

function Get-DiffLines($now, $prev) {
  $lines = @()
  if (-not $prev) {
    return @("First recorded export - no previous snapshot to compare.")
  }
  if ($prev.level -ne $now.level) { $lines += "- Level: $($prev.level) -> $($now.level)." }
  $nowZone = $now.location.zone
  if ($prev.location.zone -ne $nowZone) { $lines += "- Zone: $($prev.location.zone) -> $nowZone." }
  if ($prev.goldCopper -ne $now.goldCopper) {
    $delta = [long]$now.goldCopper - [long]$prev.goldCopper
    $sign = if ($delta -ge 0) { "+" } else { "-" }
    $lines += "- Gold: $(Format-Gold $prev.goldCopper) -> $(Format-Gold $now.goldCopper) (${sign}$(Format-Gold ([math]::Abs($delta))))."
  }
  foreach ($prof in @($now.professions)) {
    $old = @($prev.professions | Where-Object { $_.name -eq $prof.name }) | Select-Object -First 1
    if ($old -and $old.current -ne $prof.current) {
      $lines += "- $($prof.name): $($old.current)/$($old.max) -> $($prof.current)/$($prof.max)."
    }
  }
  $oldGear = @($prev.gear | ForEach-Object { $_.name })
  $newGear = @($now.gear | ForEach-Object { $_.name })
  foreach ($gname in @($newGear | Where-Object { $oldGear -notcontains $_ })) { $lines += "- Equipped: $gname (new)." }
  foreach ($gname in @($oldGear | Where-Object { $newGear -notcontains $_ })) { $lines += "- Unequipped: $gname." }
  foreach ($rep in @($now.reputations)) {
    $old = @($prev.reputations | Where-Object { $_.name -eq $rep.name }) | Select-Object -First 1
    if ($old -and ($old.standing -ne $rep.standing -or $old.value -ne $rep.value)) {
      $lines += "- $($rep.name): $($old.standing) $($old.value)/$($old.max) -> $($rep.standing) $($rep.value)/$($rep.max)."
    }
  }
  if ($prev.quests.completedCount -ne $now.quests.completedCount) {
    $lines += "- Completed quests: $($prev.quests.completedCount) -> $($now.quests.completedCount)."
  }
  $oldDone = @($prev.quests.completedNames)
  $fresh = @($now.quests.completedNames | Where-Object { $oldDone -notcontains $_ } | Select-Object -First 20)
  foreach ($qname in $fresh) { $lines += "- Turned in: $qname." }
  if ($prev.kills.total -ne $now.kills.total) { $lines += "- Kills: $($prev.kills.total) -> $($now.kills.total)." }
  if ($prev.achievements.completed -ne $now.achievements.completed) {
    $lines += "- Achievements: $($prev.achievements.completed) -> $($now.achievements.completed)."
  }
  $oldCurrent = @($prev.quests.current | ForEach-Object { $_.name })
  foreach ($quest in @($now.quests.current)) {
    if ($oldCurrent -notcontains $quest.name) { $lines += "- Picked up: $($quest.name) ($($quest.zone))." }
  }
  $newBio = @($now.biography).Count - @($prev.biography).Count
  if ($newBio -gt 0) { $lines += "- Biography: $newBio new events." }
  if (-not $lines.Count) { $lines += "Nothing changed since last export." }
  return $lines
}

function Build-Pack($char, $coll, $econ, $prev, $guides, $extra) {
  $out = @()
  $title = if ($char.displayName) { $char.displayName } else { $char.name }
  $out += "# Butler pack: $title"
  $out += ""
  $out += "Exported from $($char.sources.export.file) (Dossier $($char.sources.export.addonVersion), parsed $($char.sources.export.parsedAt))."
  $out += ""
  $out += "## Identity"
  $out += ""
  $out += "- Character: $($char.name) ($($char.race) $($char.className)) on $($char.realm), $($char.faction)."
  $spec = if ($char.talents.specialization) { $char.talents.specialization } else { "unknown" }
  $out += "- Spec: $spec."
  foreach ($prof in @($char.professions)) { $out += "- Profession: $($prof.name) $($prof.current)/$($prof.max)." }
  if ($char.talents.importString) { $out += "- Talent import: $($char.talents.importString)." }
  $out += ""
  $out += "## Level, zone, gold"
  $out += ""
  $out += "- Level $($char.level), $($char.location.zone) ($($char.location.map))."
  $out += "- Gold: $(Format-Gold $char.goldCopper)."
  $out += "- Health: $($char.health). Item level: $($char.itemLevel.equipped)."
  $out += ""
  $out += "## Gear"
  $out += ""
  foreach ($piece in @($char.gear)) { $out += "- $($piece.slot): $($piece.name) (iLvl $($piece.itemLevel), $($piece.quality))." }
  if (-not @($char.gear).Count) { $out += "No gear recorded." }
  $out += ""
  $out += "## Bags and bank"
  $out += ""
  foreach ($bag in @($char.bags)) {
    $items = @($bag.items)
    $out += "- $($bag.name) ($(Get-StackLabel $items.Count "stack")): $($items -join ", ")."
  }
  if (-not @($char.bags).Count) { $out += "No bag contents recorded." }
  $bankItems = @($char.bank.items)
  $out += "- Bank ($(Get-StackLabel $bankItems.Count "stack")): $($bankItems -join ", ")."
  $out += ""
  $out += "## Reputations"
  $out += ""
  foreach ($rep in @($char.reputations)) { $out += "- $($rep.name): $($rep.standing) $($rep.value)/$($rep.max)." }
  if (-not @($char.reputations).Count) { $out += "No reputations recorded." }
  $out += ""
  $out += "## Currencies"
  $out += ""
  foreach ($cur in @($char.currencies)) { $out += "- $($cur.name): $($cur.raw)." }
  if (-not @($char.currencies).Count) { $out += "No currencies recorded." }
  $out += ""
  $out += "## Quests"
  $out += ""
  $out += "- Current: $(@($char.quests.current).Count). Completed: $($char.quests.completedCount)."
  foreach ($quest in @($char.quests.current)) { $out += "- [$($quest.status)] $($quest.name) (lvl $($quest.level), ID $($quest.id), $($quest.zone))." }
  $out += ""
  $out += "## Kills"
  $out += ""
  $k = $char.kills
  $out += "- Total: $($k.total) across $($k.creatures) creatures. Gold looted: $(Format-Gold $k.goldLootedCopper)."
  foreach ($prop in @($k.byType.PSObject.Properties)) { $out += "- $($prop.Name): $($prop.Value)." }
  $out += "- Top creatures: $(@($k.top | Select-Object -First 10 | ForEach-Object { "$($_.name) $($_.kills)" }) -join ", ")."
  $out += ""
  $out += "## Biography"
  $out += ""
  foreach ($event in @($char.biography)) { $out += "- $($event.date) $($event.time): $($event.text)." }
  if (-not @($char.biography).Count) { $out += "No biography events recorded." }
  $out += ""
  $out += "## Lockouts"
  $out += ""
  $out += "- Saved instances: $($char.lockouts.instanceCount)."
  foreach ($ln in @($char.lockouts.lines | Where-Object { $_ -notmatch "^==.*==$" })) { $out += "- $ln" }
  $out += ""
  $out += "## Mail"
  $out += ""
  $out += "No mail section in this export."
  $out += ""
  $out += "## Tasks and notes"
  $out += ""
  $out += "No tasks or notes sections in this export."
  $out += ""
  if ($coll) {
    $out += "## Collections"
    $out += ""
    foreach ($prop in @($coll.collections.PSObject.Properties)) {
      $out += "- $($prop.Name): $($prop.Value.have)/$($prop.Value.total)."
    }
    $petNames = @($coll.collections.battlePets.names)
    if ($petNames.Count) { $out += "- Battle pets: $($petNames -join ", ")." }
    $out += ""
  }
  $att = $null
  if ($extra -and $extra.attById -and $extra.attById.ContainsKey([string]$char.id)) { $att = $extra.attById[[string]$char.id] }
  if ($att) {
    $out += "## Collections detail (AllTheThings)"
    $out += ""
    $h = $att.have
    $out += "- ATT haves: $($h.quests.count) quests, $($h.spells.count) spells, $($h.exploration.count) exploration, $($h.flightpaths.count) flight paths, $($h.achievements.count) achievements, $($h.toys.count) toys, $($h.mounts.count) mounts, $($h.battlepets.count) battle pets, $($h.titles.count) titles."
    $out += "- Last played (ATT): $($att.lastPlayed)."
    $out += ""
  }
  $recent = @()
  if ($extra -and $extra.history) { $recent = @($extra.history | Select-Object -Last 5) }
  if ($recent.Count) {
    $out += "## Recently obtained (account-wide, ATT Collection History)"
    $out += ""
    [array]::Reverse($recent)
    foreach ($got in $recent) { $out += "- $($got.collectedAt): $($got.name) ($($got.type))." }
    $out += ""
  }
  if ($extra -and $extra.rarityById -and $extra.rarityById.ContainsKey([string]$char.id) -and $extra.rarity) {
    $out += "## Rarity attempts"
    $out += ""
    $ritems = @()
    if ($extra.rarity.items) { $ritems = @($extra.rarity.items) }
    $out += "- $($ritems.Count) items tracked, $($extra.rarity.summary.itemsWithAttempts) with attempts, $($extra.rarity.summary.totalAttempts) total attempts."
    foreach ($rit in @($ritems | Select-Object -First 20)) {
      $rline = if ($null -ne $rit.attempts) { "$($rit.attempts) attempts" } else { "no attempts recorded" }
      $out += "- $($rit.name) [$($rit.group)]: $rline."
    }
    $out += ""
  }
  if ($extra -and $extra.questieById -and $extra.questieById.ContainsKey([string]$char.id)) {
    $out += "## Quest history (Questie Journey)"
    $out += ""
    $qlist = $extra.questieById[[string]$char.id]
    if ($qlist -is [System.Collections.Generic.List[object]]) { $qlist = $qlist.ToArray() }
    $qrecs = @($qlist)
    $qacc = 0; $qcomp = 0; $qcids = 0
    foreach ($qr in $qrecs) { $qacc += [int]$qr.counts.accepts; $qcomp += [int]$qr.counts.completes; $qcids += [int]$qr.counts.completeIds }
    $out += "- $(@($qrecs).Count) tracked keys, $qacc accepts, $qcomp completes, $qcids complete quest ids."
    $qevents = @($qrecs | ForEach-Object { if ($_.journey) { @($_.journey) } } | Sort-Object timestamp | Select-Object -Last 5)
    foreach ($qe in $qevents) {
      $qlabel = if ($qe.event -ieq "Level") { "reached level $($qe.newLevel)" } else { "$($qe.subType) quest $($qe.quest) (level $($qe.level))" }
      $out += "- $($qe.timestampIso): $qlabel."
    }
    $out += ""
  }
  $out += "## Relevant guides"
  $out += ""
  $mine = @($guides | Where-Object { @($_.appliesTo) -contains $char.rosterId })
  foreach ($guide in $mine) { $out += "- $($guide.title): $($guide.url)" }
  if (-not $mine.Count) { $out += "No curated guides for this character yet." }
  $out += ""
  $out += "## What changed since last export"
  $out += ""
  $out += @(Get-DiffLines $char $prev)
  $out += ""
  return $out
}

# ---- Main ----
if (-not $GuidesPath) { $GuidesPath = Join-Path $repo "data\guides.json" }
$guidesDoc = Read-JsonFile $GuidesPath
$guides = @()
if ($guidesDoc -and $guidesDoc.guides) { $guides = @($guidesDoc.guides) }
$charsDoc = Read-JsonFile (Join-Path $PrivateDir "characters.json")
$collDoc = Read-JsonFile (Join-Path $PrivateDir "collections.json")
$attDoc = Read-JsonFile (Join-Path $PrivateDir "att.json")
$attById = @{}
if ($attDoc) { foreach ($entry in @($attDoc.characters)) { if ($entry.canonicalId) { $attById[[string]$entry.canonicalId] = $entry } } }
$historyDoc = Read-JsonFile (Join-Path $PrivateDir "collection-history.json")
$historyEntries = @()
if ($historyDoc) { $historyEntries = @($historyDoc.entries) }
$rarityDoc = Read-JsonFile (Join-Path $PrivateDir "rarity.json")
$rarityById = @{}
if ($rarityDoc) { foreach ($s in @($rarityDoc.statistics)) { if ($s.canonicalId) { $rarityById[[string]$s.canonicalId] = $s } } }
$questieDoc = Read-JsonFile (Join-Path $PrivateDir "quest-history.json")
$questieById = @{}
if ($questieDoc) { foreach ($q in @($questieDoc.characters)) { if ($q.canonicalId) { $qid = [string]$q.canonicalId; if (-not $questieById.ContainsKey($qid)) { $questieById[$qid] = New-Object System.Collections.Generic.List[object] }; $questieById[$qid].Add($q) } } }
if (-not $charsDoc -or -not @($charsDoc.characters).Count) { throw "No canonical characters in $PrivateDir. Run scripts/parse-dossier-export.ps1 first." }
$prevDir = Join-Path $PrivateDir "prev"
$prevDoc = Read-JsonFile (Join-Path $prevDir "characters.json")
$prevById = @{}
if ($prevDoc) { foreach ($entry in @($prevDoc.characters)) { $prevById[$entry.id] = $entry } }
foreach ($char in @($charsDoc.characters)) {
  $coll = @($collDoc.characters | Where-Object { $_.id -eq $char.id } | Select-Object -First 1)
  $pack = Build-Pack $char $(if ($coll.Count) { $coll[0] } else { $null }) $null $prevById[$char.id] $guides @{ attById = $attById; history = $historyEntries; rarityById = $rarityById; rarity = $rarityDoc; questieById = $questieById }
  Write-Pack (Join-Path $OutDir "$($char.id).md") $pack
  Write-Output "Wrote $($char.id).md ($($pack.Count) lines)"
}
# Retain this run as the previous snapshot for the next diff.
foreach ($name in @("characters.json", "collections.json", "economy.json")) {
  $src = Join-Path $PrivateDir $name
  if (Test-Path $src) {
    if (-not (Test-Path $prevDir)) { New-Item -ItemType Directory -Force -Path $prevDir | Out-Null }
    Copy-Item -Force $src (Join-Path $prevDir $name)
  }
}
Write-Output "Butler packs in $OutDir"
