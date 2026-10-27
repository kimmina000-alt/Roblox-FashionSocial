# Map layout picture (2026-10-27, layout v8): an Edit-mode screen_capture
# straight down from (CX, H, CZ) with Studio's 70° vertical field of view
# (the shot comes out with +X up), turned so north (-Z) is up, cropped to the
# play area and labelled with place names at their world positions.
param([string]$In, [string]$Out, [double]$CX = -60, [double]$CZ = -60, [double]$H = 850)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($In)
$k = $src.Height / (2 * $H * [math]::Tan([math]::PI / 180 * 35)) # px per stud
$src.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) # clockwise: north up, east right
$W = $src.Width; $Hh = $src.Height
$mx = $W / 2; $my = $Hh / 2 # (not $cx / $cy: PowerShell names ignore case, $CX is the camera)
function U([double]$x) { $mx + ($x - $CX) * $k }
function V([double]$z) { $my + ($z - $CZ) * $k }
# crop to the play area with a margin
$x0 = [int][math]::Max(0, (U -420)); $x1 = [int][math]::Min($W, (U 320))
$y0 = [int][math]::Max(0, (V -560)); $y1 = [int][math]::Min($Hh, (V 440))
$top = 70
$bmp = New-Object System.Drawing.Bitmap ($x1 - $x0), ($y1 - $y0 + $top)
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::FromArgb(250, 246, 236))
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, $top, ($x1 - $x0), ($y1 - $y0)), (New-Object System.Drawing.Rectangle $x0, $y0, ($x1 - $x0), ($y1 - $y0)), [System.Drawing.GraphicsUnit]::Pixel)
$fontT = New-Object System.Drawing.Font 'Malgun Gothic', 24, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('오후 맵 배치도 (레이아웃 v8, 2026-10-27)', $fontT, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 30, 30))), 14, 18)
$font = New-Object System.Drawing.Font 'Malgun Gothic', 13, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
function Tag([double]$x, [double]$z, [string]$label, [int]$r, [int]$gg, [int]$b) {
  $px = (U $x) - $x0; $py = (V $z) - $y0 + $top
  $sz = $g.MeasureString($label, $font)
  $bx = $px - $sz.Width / 2 - 5; $by = $py - $sz.Height / 2 - 2
  $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, $r, $gg, $b))), $bx, $by, $sz.Width + 10, $sz.Height + 4)
  $g.DrawString($label, $font, [System.Drawing.Brushes]::White, $bx + 5, $by + 2)
}
$P = @(150, 40, 150); $B = @(30, 60, 120); $Gn = @(40, 120, 60); $S = @(110, 70, 160); $Sea = @(30, 110, 200); $Gy = @(90, 90, 90)
Tag 120 -178 'OHU 클럽 (3층)' @P
Tag 120 -334 '국밥집' @B
Tag 114 -80 '오후네컷' @B
Tag 158 195 '광화문' @B
Tag 250 140 '한옥 마을 (비움)' @Gy
Tag -95 138 'OH24 편의점' @B
Tag -98 -138 '포켓 공원' @Gn
Tag -100 -350 '놀이공원 (공사 중)' @Gn
Tag -290 276 '해변 카페' @B
Tag -236 -150 '해변' @Gn
Tag -340 -60 '바다' @Sea
Tag 0 0 '강남 사거리' @Gy
Tag 89 -470 '가짜 건물 블록 N' @Gy
Tag 250 -74 '블록 E' @Gy
Tag -103 300 '가짜 건물 블록 S' @Gy
Tag 29 -63 '지하철 1' @S
Tag 29 63 '지하철 2' @S
Tag -48 -51 '지하철 3' @S
Tag -48 44 '지하철 4' @S
Tag -26 -225 '버스 1' @Sea
Tag 148 26 '버스 2' @Sea
Tag 26 236 '버스 3' @Sea
Tag -158 102 '버스 4' @Sea
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 40, 40)), 3
$g.DrawLine($pen, $bmp.Width - 30, $top + 70, $bmp.Width - 30, $top + 20)
$g.DrawString('N', $fontT, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 40, 40))), $bmp.Width - 44, $top - 14)
$g.Dispose(); $src.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"saved $Out ($($bmp.Width) x $($bmp.Height))"
