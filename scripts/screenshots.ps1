# Screenshots from the game's Screenshots folder, mostly taken by Memento.
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

  $published = 0
  foreach ($entry in $log) {
    if (-not $entry.who) { continue }
    $character = $characters | Where-Object { Test-SaveName $entry.who $_ } | Select-Object -First 1
    if (-not $character) { continue }
    $relative = "assets/shots/$($character.id)/$($entry.takenAt.Replace(':', '').Replace('T', '-')).jpg"
    $target = Join-Path $repo $relative
    if ($entry.file -eq $relative -and (Test-Path $target)) { continue }
    $source = Join-Path $shotDir $entry.source
    if (-not (Test-Path $source)) { continue }
    Save-SmallJpeg $source $target 1280
    $entry.file = $relative
    $published++
  }

  $log = @($log | Sort-Object takenAt)
  if ($added -or $published) {
    $json = ConvertTo-Json -InputObject $log -Depth 4
    [System.IO.File]::WriteAllText($logPath, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
  }
  if ($added) { Write-Output "Found $added new screenshots" }
  if ($published) { Write-Output "Published $published screenshots to assets/shots" }
  $unknown = @($log | Where-Object { -not $_.who })
  if ($unknown.Count) {
    Write-Output "Screenshots with no character yet ($($unknown.Count)): $(($unknown | ForEach-Object { $_.source }) -join ', ')"
  }
}
