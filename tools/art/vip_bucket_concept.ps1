param([string]$Out)
# VIP bucket concept sheet (user 2026-10-29, design before building): two
# looks from the user's photos — A: a round glowing tray with neon "wing"
# guards, B: a horseshoe tray with light bricks — both with 5 VIP bottles
# (골목 공방 colours) and green lasers shooting up from the sides.
Add-Type -AssemblyName System.Drawing
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Br($c) { New-Object System.Drawing.SolidBrush $c }
function Pn($c, $w) { $p = New-Object System.Drawing.Pen $c, $w; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p }
$W = 1600; $H = 900
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, $W, $H), (C 255 10 8 24), (C 255 30 10 45), 90
$g.FillRectangle($bg, 0, 0, $W, $H)
$flav = @((C 255 212 168 70), (C 255 232 150 185), (C 255 165 35 85), (C 255 95 100 112), (C 255 212 168 70))

function Glow($cx, $cy, $rx, $ry, $col, $steps) {
  for ($i = $steps; $i -ge 1; $i--) { $a = [int](60 / $i); $g.FillEllipse((Br (C $a $col.R $col.G $col.B)), $cx - $rx * (1 + $i * 0.12), $cy - $ry * (1 + $i * 0.12), 2 * $rx * (1 + $i * 0.12), 2 * $ry * (1 + $i * 0.12)) }
}
function Laser($x, $y0, $x1, $y1) {
  foreach ($w in @(26, 14, 6, 2)) { $a = if ($w -gt 10) { 40 } else { 220 }; $g.DrawLine((Pn (C $a 60 255 90) $w), $x, $y0, $x1, $y1) }
  $g.FillEllipse((Br (C 255 180 255 190)), $x - 7, $y0 - 7, 14, 14)
}
function Bottle($cx, $by, $h, $col, $tilt) {
  $st = $g.Save(); $g.TranslateTransform($cx, $by); $g.RotateTransform($tilt)
  $w = $h * 0.3
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddBezier((-$w / 2), 0, (-$w / 2), (-$h * 0.45), (-$w * 0.55), (-$h * 0.62), (-$w * 0.12), (-$h * 0.78))
  $path.AddLine((-$w * 0.12), (-$h * 0.78), (-$w * 0.12), (-$h))
  $path.AddLine((-$w * 0.12), (-$h), ($w * 0.12), (-$h))
  $path.AddLine(($w * 0.12), (-$h), ($w * 0.12), (-$h * 0.78))
  $path.AddBezier(($w * 0.12), (-$h * 0.78), ($w * 0.55), (-$h * 0.62), ($w / 2), (-$h * 0.45), ($w / 2), 0)
  $path.CloseFigure()
  $gb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.RectangleF (-$w / 2), (-$h), $w, $h), ([System.Drawing.Color]::FromArgb(255, [Math]::Min(255, $col.R + 70), [Math]::Min(255, $col.G + 70), [Math]::Min(255, $col.B + 70))), $col, 0
  $g.FillPath($gb, $path)
  $g.FillRectangle((Br (C 255 20 20 22)), (-$w * 0.13), (-$h), ($w * 0.26), ($h * 0.24))            # foil
  $g.FillRectangle((Br (C 120 255 255 255)), (-$w * 0.3), (-$h * 0.5), ($w * 0.08), ($h * 0.42))    # shine
  # spade
  $sx = 0; $sy = -$h * 0.32; $s = $w * 0.22
  $g.FillEllipse((Br (C 200 40 30 20)), $sx - $s, $sy - $s * 0.2, $s, $s); $g.FillEllipse((Br (C 200 40 30 20)), $sx, $sy - $s * 0.2, $s, $s)
  $g.FillPolygon((Br (C 200 40 30 20)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ($sx - $s), ($sy + $s * 0.2)), (New-Object System.Drawing.PointF ($sx + $s), ($sy + $s * 0.2)), (New-Object System.Drawing.PointF $sx, ($sy - $s * 1.1))))
  $g.FillPolygon((Br (C 200 40 30 20)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ($sx - $s * 0.15), ($sy + $s * 0.5)), (New-Object System.Drawing.PointF ($sx + $s * 0.15), ($sy + $s * 0.5)), (New-Object System.Drawing.PointF ($sx + $s * 0.4), ($sy + $s * 1.1)), (New-Object System.Drawing.PointF ($sx - $s * 0.4), ($sy + $s * 1.1))))   # stem
  $g.FillRectangle((Br (C 255 120 80 50)), (-$w * 0.2), (-$h * 0.14), ($w * 0.4), ($h * 0.05))      # plate
  $g.Restore($st)
}
$title = New-Object System.Drawing.Font 'Malgun Gothic', 34, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$small = New-Object System.Drawing.Font 'Malgun Gothic', 20, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)

# ---------------- A: round tray, neon wings ----------------
$cx = 400; $cy = 640
Laser 150 600 120 150; Laser 650 600 680 150; Laser 230 560 260 150; Laser 570 560 540 150
Glow $cx ($cy + 40) 300 60 (C 255 120 80 255) 5
$g.FillEllipse((Br (C 255 18 18 26)), $cx - 270, $cy - 40, 540, 150)                       # base
$ring = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle ($cx - 270), ($cy - 40), 540, 150), (C 255 255 60 200), (C 255 60 200 255), 0
$g.FillEllipse($ring, $cx - 255, $cy - 30, 510, 110)
$g.FillEllipse((Br (C 255 230 240 255)), $cx - 220, $cy - 20, 440, 80)                     # lit top
$g.FillRectangle((Br (C 255 18 18 26)), $cx - 270, $cy + 35, 540, 70); $g.FillEllipse((Br (C 255 18 18 26)), $cx - 270, $cy + 30, 540, 120)
for ($i = 0; $i -lt 18; $i++) { $x = $cx - 240 + $i * 28; $g.FillRectangle((Br (C 255 210 230 255)), $x, $cy + 60, 8, 40) }
$g.FillRectangle((Br (C 255 240 245 255)), $cx - 80, $cy + 62, 160, 34)                      # front window
foreach ($side in @(-1, 1)) {                                                                 # wing guards
  for ($k = 0; $k -lt 3; $k++) { $g.DrawArc((Pn (C 255 120 170 255) 9), $cx + $side * 230 - 70 - $k * 14 * $side, $cy - 210 + $k * 22, 140, 220, $(if ($side -lt 0) { 120 } else { -60 }), 120) }
}
$xs = @(-160, -80, 0, 80, 160); $hs = @(250, 270, 290, 270, 250); $ts = @(-8, -4, 0, 4, 8)
for ($i = 0; $i -lt 5; $i++) { Bottle ($cx + $xs[$i]) ($cy + 15) $hs[$i] $flav[$i] $ts[$i] }
$g.DrawString('A · 원형 네온 트레이', $title, (Br (C 255 255 255 255)), 40, 30)
$g.DrawString('RGB 링 받침 + 양옆 네온 날개 · 병 5개 · 레이저 4줄', $small, (Br (C 255 200 200 220)), 40, 80)

# ---------------- B: horseshoe tray, light bricks ----------------
$cx = 1200; $cy = 650
Laser 930 600 900 150; Laser 1470 600 1500 150; Laser 1010 610 1040 150; Laser 1390 610 1360 150
Glow $cx ($cy + 40) 300 60 (C 255 255 190 60) 5
$g.FillPie((Br (C 255 20 18 22)), $cx - 290, $cy - 70, 580, 220, 0, 180)                    # horseshoe body
$g.FillRectangle((Br (C 255 20 18 22)), $cx - 290, $cy + 30, 580, 60)
$g.FillEllipse((Br (C 255 40 36 44)), $cx - 200, $cy - 30, 400, 110)                         # inner floor
for ($r = 0; $r -lt 4; $r++) { for ($k = 0; $k -lt 6; $k++) {                               # light bricks on both arms
  foreach ($side in @(-1, 1)) { $x = $cx + $side * (190 + $k * 15) - 20; $y = $cy + 15 + $r * 18 - $k * 4; $g.FillRectangle((Br (C 255 255 200 90)), $x, $y, 34, 8) } } }
$g.FillRectangle((Br (C 255 255 245 220)), $cx - 90, $cy + 45, 180, 30)                      # front light window
foreach ($p in @(-230, -150, 150, 230)) { $g.FillEllipse((Br (C 255 60 255 90)), $cx + $p - 9, $cy + 20, 18, 10) }
for ($i = 0; $i -lt 5; $i++) { Bottle ($cx + $xs[$i]) ($cy + 30) $hs[$i] $flav[$i] $ts[$i] }
$g.DrawString('B · 말굽형 라이트 트레이', $title, (Br (C 255 255 255 255)), 840, 30)
$g.DrawString('검은 말굽 받침 + 노란 빛 벽돌 · 병 5개 · 초록 레이저 4줄', $small, (Br (C 255 200 200 220)), 840, 80)
$g.Dispose(); $bmp.Save((Join-Path $Out 'vip_bucket_concepts.png')); $bmp.Dispose(); 'saved'
