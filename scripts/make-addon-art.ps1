# Builds Dossier's in-game textures and the CurseForge avatar from addon/art/logo-master.png.
# WoW loads 32-bit uncompressed TGA at power-of-two sizes.
param(
    [string]$Master = "",
    [double]$CropFraction = 0.82
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repo = Split-Path -Parent $PSScriptRoot
if (-not $Master) { $Master = Join-Path $repo "addon\art\logo-master.png" }
if (-not (Test-Path $Master)) { throw "Logo master not found: $Master" }

$media = Join-Path $repo "addon\Dossier\Media"
$dist = Join-Path $repo "dist"
New-Item -ItemType Directory -Force -Path $media, $dist | Out-Null

function New-Resized([System.Drawing.Image]$source, [int]$size, [double]$crop, [bool]$circle) {
    $side = [int]([Math]::Min($source.Width, $source.Height) * $crop)
    $srcX = [int](($source.Width - $side) / 2)
    $srcY = [int](($source.Height - $side) / 2)

    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    if ($circle) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse(0, 0, $size - 1, $size - 1)
        $g.SetClip($path)
    }

    $dest = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $g.DrawImage($source, $dest, $srcX, $srcY, $side, $side, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $bmp
}

function Write-Tga([System.Drawing.Bitmap]$bmp, [string]$path) {
    $w = $bmp.Width
    $h = $bmp.Height
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $w -band 0xFF
    $header[13] = ($w -shr 8) -band 0xFF
    $header[14] = $h -band 0xFF
    $header[15] = ($h -shr 8) -band 0xFF
    $header[16] = 32
    # Bit 5 marks top-left origin; low nibble is 8 alpha bits.
    $header[17] = 0x28

    $pixels = New-Object byte[] ($w * $h * 4)
    $i = 0
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $pixels[$i] = $c.B
            $pixels[$i + 1] = $c.G
            $pixels[$i + 2] = $c.R
            $pixels[$i + 3] = $c.A
            $i += 4
        }
    }

    $stream = [System.IO.File]::Create($path)
    try {
        $stream.Write($header, 0, $header.Length)
        $stream.Write($pixels, 0, $pixels.Length)
    } finally {
        $stream.Dispose()
    }
}

$source = [System.Drawing.Image]::FromFile((Resolve-Path $Master))
try {
    $logo = New-Resized $source 128 $CropFraction $true
    Write-Tga $logo (Join-Path $media "Logo.tga")
    $logo.Dispose()

    $icon = New-Resized $source 64 $CropFraction $true
    Write-Tga $icon (Join-Path $media "MinimapIcon.tga")
    $icon.Dispose()

    $avatar = New-Resized $source 400 $CropFraction $false
    $avatar.Save((Join-Path $dist "curseforge-logo.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $avatar.Dispose()
} finally {
    $source.Dispose()
}

Write-Host "Wrote Media\Logo.tga (128), Media\MinimapIcon.tga (64), dist\curseforge-logo.png (400)"
