# Whole-map picture (2026-10-27): a top-down Studio capture (camera at
# (-35, 5000, -85) looking down, up = +X, FOV 7.4, 1808 x 886) turned so that
# north (-Z) is up, with place names drawn at their world positions.
param([string]$In, [string]$Out)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($In)
$src.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) # clockwise: +Z (south) down, +X (east) right
$W = $src.Width; $H = $src.Height
$k = $W / (2 * 5000 * [math]::Tan([math]::PI / 180 * 3.7)) # px per stud (the capture height = the turned width)
$cx = $W / 2; $cy = $H / 2
function U([double]$x){ $cx + ($x + 35) * $k }
function V([double]$z){ $cy + ($z + 85) * $k }
$top = 90
$bmp = New-Object System.Drawing.Bitmap $W, ($H + $top)
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::FromArgb(250, 246, 236))
$g.DrawImage($src, 0, $top, $W, $H)
$fontT = New-Object System.Drawing.Font 'Malgun Gothic', 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('오후 전체 지도 (2026-10-27)', $fontT, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 30, 30))), 20, 24)
$font = New-Object System.Drawing.Font 'Malgun Gothic', 15, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
function Tag([double]$x, [double]$z, [string]$label, [int]$r, [int]$gg, [int]$b) { # (typed: a bare -186 arrives as a string)
  $px = U $x; $py = (V $z) + $top
  $sz = $g.MeasureString($label, $font)
  $bx = $px - $sz.Width / 2 - 6; $by = $py - $sz.Height / 2 - 3
  $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, $r, $gg, $b))), $bx, $by, $sz.Width + 12, $sz.Height + 6)
  $g.DrawString($label, $font, [System.Drawing.Brushes]::White, $bx + 6, $by + 3)
}
$cPink = @(150, 40, 150); $cBlue = @(30, 60, 120); $cGreen = @(40, 120, 60); $cSub = @(110, 70, 160); $cSea = @(30, 110, 200) # (not $G / $B: PowerShell names ignore case, $g is the Graphics)
Tag 111 -186 'OHU 클럽 (밤에만)' @cPink
Tag 109 -368 '클럽 옥상·백스테이지' @cPink
Tag 61 -285 '국밥집' @cBlue
Tag 80 -71 '오후네컷' @cBlue
Tag 164 138 '한옥 마을' @cBlue
Tag 78 236 '광화문' @cBlue
Tag -91 83 'OH24 편의점' @cBlue
Tag -98 -138 '포켓 공원' @cGreen
Tag -129 -330 '놀이공원 (공사 중)' @cGreen
Tag -252 61 '해변 카페' @cBlue
Tag -236 -150 '해변' @cGreen
Tag -300 -60 '바다' @cSea
Tag 0 0 '강남 사거리' 80 80 80
Tag 29 -63 '지하철 1' @cSub
Tag 29 63 '지하철 2' @cSub
Tag -48 -51 '지하철 3' @cSub
Tag -48 44 '지하철 4' @cSub
Tag -26 -192 '버스' @cSea
Tag 139 26 '버스' @cSea
Tag 26 226 '버스' @cSea
Tag -158 93 '버스' @cSea
# compass
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 40, 40)), 4
$g.DrawLine($pen, $W - 40, $top + 90, $W - 40, $top + 30)
$g.DrawString('N', $fontT, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 40, 40))), $W - 58, $top - 10)
$g.Dispose(); $src.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"saved $Out ($W x $($H + $top))"
