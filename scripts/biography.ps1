# Dossier biography: every event the addon recorded, one file per roster character.
# The addon keeps the full log in DossierDBChar.biography inside each character's SavedVariables\Dossier.lua
# (AIExportDBChar in AIExport.lua before the 2.0.0 rename).
# data/biography/<id>.json keeps every event already copied, so a later scan only adds to it.

function Get-BiographyKey($event) {
  $detail = $event.text
  if ($null -ne $event.questID) { $detail = "quest:$($event.questID)" }
  elseif ($event.profession) { $detail = "profession:$($event.profession)" }
  return "$($event.t)|$($event.kind)|$detail"
}

function Convert-BiographyEvent($entry) {
  if ($entry -isnot [System.Collections.IDictionary]) { return $null }
  $t = LV $entry "t"
  $text = LV $entry "text"
  if (-not $t -or -not $text) { return $null }
  $row = [ordered]@{
    t = [long]$t
    at = From-Epoch $t
    kind = LV $entry "kind"
    text = [string]$text
  }
  foreach ($key in @("zone", "level", "questID", "achievementID", "profession", "fromRank", "rank", "reason", "encounterID", "difficultyID")) {
    $value = LV $entry $key
    if ($null -ne $value) { $row[$key] = $value }
  }
  return [pscustomobject]$row
}

function Update-Biography($wtfRoot, $repo, $characters) {
  $accountRoot = Join-Path $wtfRoot "Account"
  if (-not (Test-Path $accountRoot)) { return }
  $saves = Get-DossierSaves $accountRoot
  if (-not $saves.Count) { return }
  $outDir = Join-Path $repo "data\biography"

  foreach ($character in $characters) {
    $first = ($character.name -split ' ')[0]
    $last = ($character.name -split ' ', 2)[1]
    $folder = if ($last) { "$first-$last" } else { $first }
    $save = Find-DossierSave $saves $folder
    if (-not $save) { continue }

    $log = LV (Read-DossierSave $save) "biography"
    if ($log -isnot [System.Collections.IList] -or -not $log.Count) { continue }

    $path = Join-Path $outDir "$($character.id).json"
    $events = [ordered]@{}
    if (Test-Path $path) {
      $existing = Get-Content -Raw -Path $path | ConvertFrom-Json
      foreach ($event in @($existing.events)) {
        if ($event) { $events[(Get-BiographyKey $event)] = $event }
      }
    }
    $before = $events.Count

    foreach ($entry in $log) {
      $event = Convert-BiographyEvent $entry
      if ($event) { $events[(Get-BiographyKey $event)] = $event }
    }

    $sorted = @($events.Values | Sort-Object t)
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $json = [ordered]@{
      character = $character.name
      updated = $save.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
      count = $sorted.Count
      events = $sorted
    } | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($path, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Output "Wrote $($sorted.Count) biography events for $($character.name) to data/biography/$($character.id).json ($($sorted.Count - $before) new)"
  }
}
