param(
  [string]$InputDir = "",
  [string]$OutputDir = "",
  [int]$TargetWidth = 1080,
  [int]$TargetHeight = 1440,
  [string]$Pattern = "xhs_locked_*.jpg",
  [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
if ($ConfigPath.Trim().Length -eq 0) {
  $ConfigPath = Join-Path $skillRoot "config\config.json"
}

if (Test-Path -LiteralPath $ConfigPath) {
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($TargetWidth -eq 1080 -and $config.image_generation.target_width) {
    $TargetWidth = [int]$config.image_generation.target_width
  }
  if ($TargetHeight -eq 1440 -and $config.image_generation.target_height) {
    $TargetHeight = [int]$config.image_generation.target_height
  }
}

if ($InputDir.Trim().Length -eq 0) {
  $InputDir = Join-Path $skillRoot "output"
}
if ($OutputDir.Trim().Length -eq 0) {
  $OutputDir = Join-Path $InputDir "3x4"
}

Add-Type -AssemblyName System.Drawing

function Save-Jpeg {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    [string]$Path,
    [long]$Quality = 95
  )

  $dir = Split-Path -Parent $Path
  if ($dir) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq "image/jpeg" }
  $params = New-Object System.Drawing.Imaging.EncoderParameters 1
  $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter (
    [System.Drawing.Imaging.Encoder]::Quality,
    $Quality
  )
  $Bitmap.Save($Path, $encoder, $params)
}

if (-not (Test-Path -LiteralPath $InputDir)) {
  throw "Input directory not found: $InputDir"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$targetRatio = $TargetWidth / $TargetHeight
$files = Get-ChildItem -LiteralPath $InputDir -Filter $Pattern -File |
  Where-Object { $_.FullName -notlike (Join-Path $OutputDir "*") }

$results = @()

foreach ($file in $files) {
  $img = [System.Drawing.Image]::FromFile($file.FullName)
  try {
    $canvasW = $img.Width
    $canvasH = $img.Height
    $srcRatio = $img.Width / $img.Height

    if ([Math]::Abs($srcRatio - $targetRatio) -gt 0.0001) {
      if ($srcRatio -lt $targetRatio) {
        $canvasW = [int][Math]::Ceiling($img.Height * $targetRatio)
        $canvasH = $img.Height
      } else {
        $canvasW = $img.Width
        $canvasH = [int][Math]::Ceiling($img.Width / $targetRatio)
      }
    }

    $canvas = New-Object System.Drawing.Bitmap $canvasW, $canvasH
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    try {
      $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g.Clear([System.Drawing.Color]::FromArgb(228, 212, 182))
      $x = [int](($canvasW - $img.Width) / 2)
      $y = [int](($canvasH - $img.Height) / 2)
      $g.DrawImage($img, $x, $y, $img.Width, $img.Height)
    } finally {
      $g.Dispose()
    }

    $final = New-Object System.Drawing.Bitmap $TargetWidth, $TargetHeight
    $g2 = [System.Drawing.Graphics]::FromImage($final)
    try {
      $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $g2.Clear([System.Drawing.Color]::FromArgb(228, 212, 182))
      $g2.DrawImage($canvas, 0, 0, $TargetWidth, $TargetHeight)
    } finally {
      $g2.Dispose()
    }

    $out = Join-Path $OutputDir $file.Name
    Save-Jpeg -Bitmap $final -Path $out
    $item = Get-Item -LiteralPath $out
    $results += [pscustomobject]@{
      input = $file.FullName
      output = $item.FullName
      width = $TargetWidth
      height = $TargetHeight
      size_bytes = $item.Length
    }

    $canvas.Dispose()
    $final.Dispose()
  } finally {
    $img.Dispose()
  }
}

[pscustomobject]@{
  status_code = 0
  output_dir = (Resolve-Path -LiteralPath $OutputDir).Path
  count = $results.Count
  files = $results
} | ConvertTo-Json -Depth 4 -Compress
