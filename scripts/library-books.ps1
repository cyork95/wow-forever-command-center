# Refresh data/library-books.json from the Zockify library book guide.
# Usage: powershell -File scripts/library-books.ps1

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$url = "https://www.zockify.com/forever/library-books/"
$outPath = Join-Path $repo "data\library-books.json"

function Get-PlainText($html) {
  $text = $html -replace '<[^>]+>', ''
  $text = [System.Net.WebUtility]::HtmlDecode($text)
  return ($text -replace '\s+', ' ').Trim()
}

$html = (Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{ "User-Agent" = "Mozilla/5.0" }).Content

$regions = @(
  [pscustomobject]@{ at = $html.IndexOf('id="locations-eastern-kingdoms"'); region = "Eastern Kingdoms"; kind = "library" },
  [pscustomobject]@{ at = $html.IndexOf('id="locations-kalimdor"'); region = "Kalimdor"; kind = "library" },
  [pscustomobject]@{ at = $html.IndexOf('id="mage-book-locations-in-wow-forever"'); region = "Mage books"; kind = "mage" }
) | Where-Object { $_.at -ge 0 } | Sort-Object at

$books = @()
$sections = [regex]::Matches($html, '(?s)<section[^>]*z-todo-block[^>]*data-z-todo-id="([^"]+)"[^>]*>(.*?)</section>')
foreach ($section in $sections) {
  $body = $section.Groups[2].Value
  $where = $regions | Where-Object { $_.at -lt $section.Index } | Select-Object -Last 1
  if (-not $where) { continue }

  $zone = $null
  if ($body -match '(?s)<h[34][^>]*>(.*?)</h[34]>') { $zone = Get-PlainText $Matches[1] }
  $name = $null
  if ($body -match '<span class="text-\w+ cursor-default"[^>]*><img[^>]*>&nbsp;([^<]+)</span>') { $name = Get-PlainText $Matches[1] }
  if (-not $name -or -not $zone) { continue }

  $location = $null
  $notes = @()
  foreach ($p in [regex]::Matches($body, '(?s)<p[^>]*>(.*?)</p>')) {
    $text = Get-PlainText $p.Groups[1].Value
    if (-not $text -or $text -match '^Thanks for the feedback' -or $text.Contains("has not yet been found")) { continue }
    if (-not $location -and $text.Contains($name)) { $location = $text -replace '^SoD:\s*', 'Season of Discovery spot: ' }
    else { $notes += $text }
  }

  $mapId = $null
  if ($body -match 'z-wowmap-image" src="[^"]*/maps/en/(\d+)\.webp') { $mapId = [int]$Matches[1] }
  $pins = @(foreach ($pin in [regex]::Matches($body, '<span class="z-wowmap-pin"[^>]*data-z-x="([\d.]+)" data-z-y="([\d.]+)"(?: title="([^"]*)")?')) {
    [pscustomobject][ordered]@{
      x = [double]$pin.Groups[1].Value
      y = [double]$pin.Groups[2].Value
      label = [System.Net.WebUtility]::HtmlDecode($pin.Groups[3].Value)
    }
  })

  $books += [pscustomobject][ordered]@{
    id = $section.Groups[1].Value
    name = $name
    kind = $where.kind
    region = $where.region
    zone = $zone
    location = $location
    notes = @($notes)
    moved = $body.Contains("has not yet been found")
    mapId = $mapId
    pins = $pins
  }
}

$updated = $null
if ($html -match 'Last updated on <time datetime="(\d{4}-\d{2}-\d{2})') { $updated = $Matches[1] }

$payload = [ordered]@{
  source = "Zockify"
  url = $url
  updated = $updated
  mapUrl = "https://www.zockify.com/db/wow/maps/en/preview/{mapId}.webp"
  books = @($books)
}
$json = $payload | ConvertTo-Json -Depth 6
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outPath, $json + "`n", $utf8)
$distinct = @($books | Where-Object { $_.kind -eq "library" } | ForEach-Object { $_.name } | Select-Object -Unique).Count
Write-Output "Wrote $($books.Count) book spots ($distinct distinct library books) to data/library-books.json"
