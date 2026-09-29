# Screenshots from the game's Screenshots folder, taken by AIExport's Screenshotter or Memento.
# The files carry no character name, so data/screenshots.json records who took each one.
# Shots whose "who" is a roster character get a 1280px copy under assets/shots/<id>/ for the site.

Add-Type -AssemblyName System.Drawing

function Save-SmallJpeg($source, $target, $width) {
  $image = [System.Drawing.Image]::FromFile($source)
  try {
    $w = [Math]::Min($width, $image.Width)
    $h = [int][Math]::Round($image.Height * $w / $image.Width)
    $bitmap = New-Object System.Drawing.Bitmap $w, $h
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($image, 0, 0, $w, $h)
    $graphics.Dispose()
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $params = New-Object System.Drawing.Imaging.EncoderParameters 1
    $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]82)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    $bitmap.Save($target, $codec, $params)
    $bitmap.Dispose()
  } finally {
    $image.Dispose()
  }
}

# AIExport's Biography records a "screenshot" event each time the game saves one.
# An unnamed shot whose takenAt is within 10 seconds of such an event belongs to that character.
# Screenshotter events also carry a reason ("Reached level 12"), which becomes an empty caption.
function Set-ScreenshotOwners($repo, $characters, $log) {
  $result = [pscustomobject]@{ named = 0; captioned = 0 }
  $events = @()
  foreach ($character in $characters) {
    $path = Join-Path $repo "data\biography\$($character.id).json"
    if (-not (Test-Path $path)) { continue }
    $bio = Get-Content -Raw -Path $path | ConvertFrom-Json
    foreach ($event in @($bio.events)) {
      if (-not $event -or $event.kind -ne "screenshot" -or -not $event.t) { continue }
      $events += [pscustomobject]@{
        at = [DateTimeOffset]::FromUnixTimeSeconds([long]$event.t).LocalDateTime
        who = $character.name
        reason = $event.reason
      }
    }
  }
  if (-not $events.Count) { return $result }

  foreach ($entry in $log) {
    if (($entry.who -and $entry.caption) -or -not $entry.takenAt) { continue }
    $taken = [datetime]::ParseExact($entry.takenAt, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
    $match = $events |
      Where-Object { [Math]::Abs(($_.at - $taken).TotalSeconds) -le 10 } |
      Sort-Object { [Math]::Abs(($_.at - $taken).TotalSeconds) } |
      Select-Object -First 1
    if (-not $match) { continue }
    if (-not $entry.who) {
      $entry.who = $match.who
      $result.named++
    }
    if (-not $entry.caption -and $match.reason -and $entry.who -eq $match.who) {
      $entry.caption = [string]$match.reason
      $result.captioned++
    }
  }
  return $result
}

# "Reached level 12" -> "reached-level-12"
function Get-ShotSlug($caption) {
  $slug = ([string]$caption).ToLowerInvariant() -replace '[^a-z0-9]+', '-'
  $slug = $slug.Trim('-')
  if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).TrimEnd('-') }
  if (-not $slug) { $slug = "screenshot" }
  return $slug
}

# YYYY-MM-DD_HHMM_Character-Name_reason
function Get-ShotBaseName($entry) {
  $taken = [datetime]::ParseExact($entry.takenAt, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
  $who = (([string]$entry.who).Trim() -replace '[\\/:*?"<>|]', '') -replace '\s+', '-'
  return "$($taken.ToString('yyyy-MM-dd_HHmm'))_$($who)_$(Get-ShotSlug $entry.caption)"
}

# Moves an earlier copy to its new name, or makes one from the game's original.
function Set-ShotCopy($oldPath, $target, $source, [scriptblock]$make) {
  if ($oldPath -and (Test-Path $oldPath) -and $oldPath -ne $target) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Move-Item -LiteralPath $oldPath -Destination $target -Force
    return $true
  }
  if (-not (Test-Path $source)) { return $false }
  & $make $source $target
  return $true
}

function Update-Screenshots($gameRoot, $repo, $characters) {
  $logPath = Join-Path $repo "data\screenshots.json"
  $shotDir = Join-Path $gameRoot "Screenshots"
  $log = @()
  if (Test-Path $logPath) { $log = @(Get-Content -Raw $logPath | ConvertFrom-Json | ForEach-Object { $_ }) }
  $known = @{}
  foreach ($entry in $log) { $known[$entry.source] = $entry }

  $added = 0
  if (Test-Path $shotDir) {
    foreach ($file in Get-ChildItem $shotDir -File | Where-Object { $_.Extension -match '^\.(jpe?g|png)$' }) {
      if ($known.ContainsKey($file.Name)) { continue }
      $takenAt = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")
      if ($file.BaseName -match '_(\d{2})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$') {
        $takenAt = "20$($Matches[3])-$($Matches[1])-$($Matches[2])T$($Matches[4]):$($Matches[5]):$($Matches[6])"
      }
      $entry = [pscustomobject][ordered]@{ source = $file.Name; takenAt = $takenAt; who = $null; caption = $null; file = $null }
      $log += $entry
      $known[$file.Name] = $entry
      $added++
    }
  }

  $owners = Set-ScreenshotOwners $repo $characters $log
  $named = $owners.named
  $captioned = $owners.captioned

  foreach ($entry in $log) {
    if (-not $entry.PSObject.Properties["archive"]) { $entry | Add-Member -NotePropertyName archive -NotePropertyValue $null }
  }

  # Base names already in use, so a clash gets -2, -3. Sorting by takenAt keeps the suffixes stable between runs.
  $taken = @{}
  foreach ($entry in $log) {
    foreach ($path in @($entry.file, $entry.archive)) {
      if ($path) { $taken[[System.IO.Path]::GetFileNameWithoutExtension($path)] = $entry }
    }
  }

  $published = 0
  $renamed = 0
  $archiveDir = Join-Path $shotDir "AIExport"
  foreach ($entry in @($log | Sort-Object takenAt)) {
    if (-not $entry.who -or -not $entry.takenAt) { continue }
    $source = Join-Path $shotDir $entry.source
    $base = Get-ShotBaseName $entry
    $name = $base
    $n = 2
    while ($taken.ContainsKey($name) -and -not [object]::ReferenceEquals($taken[$name], $entry)) {
      $name = "$base-$n"
      $n++
    }
    $taken[$name] = $entry

    $character = $characters | Where-Object { Test-SaveName $entry.who $_ } | Select-Object -First 1
    if ($character) {
      $relative = "assets/shots/$($character.id)/$name.jpg"
      $target = Join-Path $repo $relative
      if (-not ($entry.file -eq $relative -and (Test-Path $target))) {
        $old = if ($entry.file) { Join-Path $repo $entry.file } else { $null }
        $moved = $old -and (Test-Path $old)
        if (Set-ShotCopy $old $target $source { param($s, $t) Save-SmallJpeg $s $t 1280 }) {
          $entry.file = $relative
          if ($moved) { $renamed++ } else { $published++ }
        }
      }
    }

    $archiveName = "AIExport/$name$([System.IO.Path]::GetExtension($entry.source).ToLowerInvariant())"
    $archiveTarget = Join-Path $shotDir $archiveName
    if ($entry.archive -eq $archiveName -and (Test-Path $archiveTarget)) { continue }
    $old = if ($entry.archive) { Join-Path $shotDir $entry.archive } else { $null }
    $copied = Set-ShotCopy $old $archiveTarget $source {
      param($s, $t)
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $t) | Out-Null
      Copy-Item -LiteralPath $s -Destination $t -Force
    }
    if ($copied) {
      $entry.archive = $archiveName
      $renamed++
    }
  }

  $log = @($log | Sort-Object takenAt)
  if ($added -or $named -or $captioned -or $published -or $renamed) {
    $json = ConvertTo-Json -InputObject $log -Depth 4
    [System.IO.File]::WriteAllText($logPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
  if ($added) { Write-Output "Found $added new screenshots" }
  if ($named) { Write-Output "Named $named screenshots from AIExport biography events" }
  if ($captioned) { Write-Output "Captioned $captioned screenshots from Screenshotter reasons" }
  if ($published) { Write-Output "Published $published screenshots to assets/shots" }
  if ($renamed) { Write-Output "Named $renamed files (assets/shots and Screenshots\AIExport)" }
  $unknown = @($log | Where-Object { -not $_.who })
  if ($unknown.Count) {
    Write-Output "Screenshots with no character yet ($($unknown.Count)): $(($unknown | ForEach-Object { $_.source }) -join ', ')"
  }
}
