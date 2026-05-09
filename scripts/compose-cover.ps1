param(
  [string]$BaseCover = "",
  [string[]]$DetailImages = @(),
  [string[]]$CardTitles = @(),
  [string]$Subtitle = "",
  [string]$Output = "",
  [string]$PublishDir = "",
  [string]$RunDir = "",
  [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
if ($ConfigPath.Trim().Length -eq 0) {
  $ConfigPath = Join-Path $skillRoot "config\config.json"
}

if ($RunDir.Trim().Length -eq 0) {
  $RunDir = Join-Path $skillRoot "output\native3x4"
}
if ($BaseCover.Trim().Length -eq 0) {
  $BaseCover = Join-Path $RunDir "xhs_locked_1_base.jpg"
}
if ($DetailImages.Count -eq 0) {
  $DetailImages = @(
    (Join-Path $RunDir "xhs_locked_2.jpg"),
    (Join-Path $RunDir "xhs_locked_3.jpg"),
    (Join-Path $RunDir "xhs_locked_4.jpg")
  )
}
if ($Output.Trim().Length -eq 0) {
  $Output = Join-Path $RunDir "xhs_locked_1.jpg"
}
if ($PublishDir.Trim().Length -eq 0 -and (Test-Path -LiteralPath $ConfigPath)) {
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$config.publish_dir -ne "") {
    $PublishDir = [string]$config.publish_dir
  }
}

Add-Type -AssemblyName System.Drawing

function ConvertFrom-CodePointHex {
  param([string]$Hex)

  $chars = New-Object System.Collections.Generic.List[char]
  foreach ($part in $Hex.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)) {
    $codePoint = [Convert]::ToInt32($part, 16)
    foreach ($ch in [System.Char]::ConvertFromUtf32($codePoint).ToCharArray()) {
      $chars.Add($ch)
    }
  }
  return -join $chars
}

function New-RoundedRect {
  param(
    [float]$X,
    [float]$Y,
    [float]$W,
    [float]$H,
    [float]$R
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $R * 2
  $path.AddArc($X, $Y, $d, $d, 180, 90)
  $path.AddArc(($X + $W - $d), $Y, $d, $d, 270, 90)
  $path.AddArc(($X + $W - $d), ($Y + $H - $d), $d, $d, 0, 90)
  $path.AddArc($X, ($Y + $H - $d), $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

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

if (-not (Test-Path -LiteralPath $BaseCover)) {
  throw "Base cover not found: $BaseCover"
}

if ($Subtitle.Trim().Length -eq 0) {
  $Subtitle = ConvertFrom-CodePointHex "9644 4FDD 59C6 7EA7 6253 5047 20 2B 20 9009 8D2D 653B 7565"
}

if ($CardTitles.Count -eq 0) {
  $CardTitles = @(
    (ConvertFrom-CodePointHex "667A 80FD 529F 80FD 20 2F 20 98CE 91CF 98CE 538B"),
    (ConvertFrom-CodePointHex "62E2 70DF 7ED3 6784 20 2F 20 6E05 6D01 4FBF 6377"),
    (ConvertFrom-CodePointHex "566A 97F3 20 2F 20 989C 503C 20 2F 20 552E 540E")
  )
}

if ($DetailImages.Count -ne 3 -or $CardTitles.Count -ne 3) {
  throw "This cover composer expects exactly 3 detail images and 3 card titles."
}

foreach ($imgPath in $DetailImages) {
  if (-not (Test-Path -LiteralPath $imgPath)) {
    throw "Detail image not found: $imgPath"
  }
}

$base = [System.Drawing.Image]::FromFile($BaseCover)
try {
  $bitmap = New-Object System.Drawing.Bitmap $base.Width, $base.Height
  $g = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.DrawImage($base, 0, 0, $base.Width, $base.Height)

    $coverBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(252, 250, 246))
    $g.FillRectangle($coverBrush, 30, 895, 1026, 500)
    $coverBrush.Dispose()

    $stripBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(190, 160, 112))
    $whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(35, 110, 90, 55))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(206, 184, 143)), 4
    $thinPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(226, 211, 181)), 2
    $subtitleFont = New-Object System.Drawing.Font("Microsoft YaHei UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleFont = New-Object System.Drawing.Font("Microsoft YaHei UI", 14, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    try {
      $strip = New-RoundedRect 276 908 534 52 10
      $g.FillPath($stripBrush, $strip)
      $g.DrawString($Subtitle, $subtitleFont, $whiteBrush, [System.Drawing.RectangleF]::new(276, 908, 534, 52), $sf)
      $strip.Dispose()

      $slots = @(
        @(55, 995, 300, 350),
        @(393, 995, 300, 350),
        @(731, 995, 300, 350)
      )

      for ($i = 0; $i -lt 3; $i++) {
        $x = [int]$slots[$i][0]
        $y = [int]$slots[$i][1]
        $w = [int]$slots[$i][2]
        $h = [int]$slots[$i][3]

        $shadow = New-RoundedRect ($x + 8) ($y + 10) $w $h 16
        $g.FillPath($shadowBrush, $shadow)
        $shadow.Dispose()

        $card = New-RoundedRect $x $y $w $h 16
        $g.FillPath($whiteBrush, $card)
        $g.DrawPath($borderPen, $card)

        $header = New-RoundedRect ($x + 24) ($y + 20) ($w - 48) 40 10
        $g.FillPath($stripBrush, $header)
        $g.DrawString($CardTitles[$i], $titleFont, $whiteBrush, [System.Drawing.RectangleF]::new(($x + 24), ($y + 20), ($w - 48), 40), $sf)
        $header.Dispose()

        $detail = [System.Drawing.Image]::FromFile($DetailImages[$i])
        try {
          $dx = $x + 20
          $dy = $y + 72
          $dw = $w - 40
          $dh = $h - 92

          $srcX = 0
          $srcY = 0
          $srcW = $detail.Width
          $srcH = [int]($srcW * ($dh / $dw))
          if ($srcH -gt $detail.Height) {
            $srcH = $detail.Height
            $srcW = [int]($srcH * ($dw / $dh))
            $srcX = [int](($detail.Width - $srcW) / 2)
          }

          $src = [System.Drawing.Rectangle]::new($srcX, $srcY, $srcW, $srcH)
          $dst = [System.Drawing.Rectangle]::new($dx, $dy, $dw, $dh)
          $clip = New-RoundedRect $dx $dy $dw $dh 10
          $oldClip = $g.Clip
          $g.SetClip($clip)
          $g.DrawImage($detail, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
          $g.Clip = $oldClip
          $g.DrawPath($thinPen, $clip)
          $clip.Dispose()
        } finally {
          $detail.Dispose()
        }

        $card.Dispose()
      }
    } finally {
      $stripBrush.Dispose()
      $whiteBrush.Dispose()
      $shadowBrush.Dispose()
      $borderPen.Dispose()
      $thinPen.Dispose()
      $subtitleFont.Dispose()
      $titleFont.Dispose()
      $sf.Dispose()
    }

    Save-Jpeg -Bitmap $bitmap -Path $Output
  } finally {
    $g.Dispose()
    $bitmap.Dispose()
  }
} finally {
  $base.Dispose()
}

if ($PublishDir.Trim().Length -gt 0) {
  New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null
  Copy-Item -LiteralPath $Output -Destination (Join-Path $PublishDir (Split-Path -Leaf $Output)) -Force
}

$item = Get-Item -LiteralPath $Output
[pscustomobject]@{
  status_code = 0
  output = $item.FullName
  size_bytes = $item.Length
  publish_dir = $PublishDir
} | ConvertTo-Json -Compress
