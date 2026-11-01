# Game thumbnail compositor (D-742): a Studio screenshot → 1920×1080 PNG with
# the neon "오후" logo, the "OHU" sub-mark and a one-line tagline.
#   powershell -ExecutionPolicy Bypass -File tools\thumbnail\compose_thumb.ps1 -In shot.jpg -Out docs\04_ART\thumbnails\main.png
# Trend notes (2026-11-02, the user's screenshot of club / dance games): big
# dancing characters, night + neon, a bold title with a short line saying what
# you do; logo-only thumbnails with no people did worse.
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Title = "오후",
    [string]$Sub = "OHU · CLUB & FASHION",
    [string]$Tagline = "춤추고 · 꾸미고 · 같이 놀자!",
    [int]$Width = 1920,
    [int]$Height = 1080
)
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $In).Path)
$bmp = New-Object System.Drawing.Bitmap $Width, $Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# the shot, scaled to cover the frame (centre crop)
$scale = [Math]::Max($Width / $src.Width, $Height / $src.Height)
$w = [int]($src.Width * $scale); $h = [int]($src.Height * $scale)
$g.DrawImage($src, [int](($Width - $w) / 2), [int](($Height - $h) / 2), $w, $h)

# darker top and bottom so the words stand out
function Shade([int]$y0, [int]$y1, [int]$a0, [int]$a1) {
    $rect = New-Object System.Drawing.Rectangle 0, $y0, $Width, ($y1 - $y0)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb($a0, 8, 4, 24)), ([System.Drawing.Color]::FromArgb($a1, 8, 4, 24)), 90
    $g.FillRectangle($brush, $rect); $brush.Dispose()
}
Shade 0 380 200 0
Shade ($Height - 300) $Height 0 210

# neon text: soft wide glow strokes, then a bright core, then a thin white fill
function Neon([string]$text, [string]$font, [float]$size, [System.Drawing.FontStyle]$style, [float]$cx, [float]$y, [System.Drawing.Color]$glow, [System.Drawing.Color]$fill) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath ([System.Drawing.Drawing2D.FillMode]::Winding) # (Winding: overlapping strokes of Korean glyphs stay filled)
    $family = New-Object System.Drawing.FontFamily $font
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $path.AddString($text, $family, [int]$style, $size, (New-Object System.Drawing.PointF $cx, $y), $fmt)
    foreach ($step in @(@(48, 18), @(32, 30), @(20, 60), @(11, 120))) {
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($step[1], $glow.R, $glow.G, $glow.B)), $step[0]
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($pen, $path); $pen.Dispose()
    }
    $core = New-Object System.Drawing.Pen $glow, 6
    $core.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($core, $path); $core.Dispose()
    $brush = New-Object System.Drawing.SolidBrush $fill
    $g.FillPath($brush, $path); $brush.Dispose(); $path.Dispose()
}
# solid text with a dark outline (the tagline)
function Bold([string]$text, [string]$font, [float]$size, [float]$cx, [float]$y, [System.Drawing.Color]$fill, [System.Drawing.Color]$edge) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath ([System.Drawing.Drawing2D.FillMode]::Winding) # (Winding: overlapping strokes of Korean glyphs stay filled)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $path.AddString($text, (New-Object System.Drawing.FontFamily $font), [int][System.Drawing.FontStyle]::Bold, $size, (New-Object System.Drawing.PointF $cx, $y), $fmt)
    $pen = New-Object System.Drawing.Pen $edge, 14
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $path); $pen.Dispose()
    $top = $path.GetBounds()
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $top, ([System.Drawing.Color]::FromArgb(255, 255, 240, 120)), $fill, 90
    $g.FillPath($brush, $path); $brush.Dispose(); $path.Dispose()
}

$pink = [System.Drawing.Color]::FromArgb(255, 255, 60, 200)
$cyan = [System.Drawing.Color]::FromArgb(255, 40, 230, 255)
Neon $Title "Noto Sans KR Black" 230 ([System.Drawing.FontStyle]::Regular) ($Width / 2) 0 $pink ([System.Drawing.Color]::FromArgb(255, 255, 235, 250))
Neon $Sub "Bahnschrift" 54 ([System.Drawing.FontStyle]::Bold) ($Width / 2) 300 $cyan ([System.Drawing.Color]::FromArgb(255, 225, 255, 255))
Bold $Tagline "Noto Sans KR Black" 104 ($Width / 2) ($Height - 190) ([System.Drawing.Color]::FromArgb(255, 255, 150, 40)) ([System.Drawing.Color]::FromArgb(255, 20, 8, 40))

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $src.Dispose()
"saved $Out"
