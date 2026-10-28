param([string]$Out)
# The honey caramel bread atlas (user photo 2026-10-29): 1024 x 1024, four
# squares used by tools/art/FoodGltf.cs mode "bread":
#   top-left  the top of the loaf: toasted gold, a 3 x 3 grid of cuts, caramel
#             drizzled across in loose zigzags with a gloss
#   top-right the sides: gold with a darker toasted top edge, two cut lines,
#             caramel running down from the top
#   bottom-left  the plate: warm white, caramel drizzled round the loaf
#   bottom-right the whipped cream: white swirls with cinnamon dust
Add-Type -AssemblyName System.Drawing
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Br($c) { New-Object System.Drawing.SolidBrush $c }
function Pn($c, $w) { $p = New-Object System.Drawing.Pen $c, $w; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p.LineJoin = 'Round'; $p }
$rnd = New-Object System.Random 11
$bmp = New-Object System.Drawing.Bitmap 1024, 1024
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
function Grad($x, $y, $w, $h, $c1, $c2, $angle) { $b = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle $x, $y, $w, $h), $c1, $c2, $angle; $g.FillRectangle($b, $x, $y, $w, $h) }
function Caramel($pts, $w) {
  $g.DrawCurve((Pn (C 255 150 82 25) ($w + 4)), $pts, 0.5)
  $g.DrawCurve((Pn (C 255 196 118 44) $w), $pts, 0.5)
  $g.DrawCurve((Pn (C 150 255 220 160) ([Math]::Max(2, $w / 4))), $pts, 0.5)   # gloss
}
function P($x, $y) { New-Object System.Drawing.PointF $x, $y }

# ---- top of the loaf (0..512, 0..512) ----
Grad 0 0 512 512 (C 255 214 150 70) (C 255 196 128 52) 45
for ($i = 0; $i -lt 900; $i++) { $x = $rnd.Next(512); $y = $rnd.Next(512); $s = $rnd.Next(4, 14); $g.FillEllipse((Br (C 40 120 70 25)), $x, $y, $s, $s) }   # toast speckle
$g.DrawRectangle((Pn (C 255 150 90 35) 18), 9, 9, 494, 494)                     # browned rim
foreach ($k in 1, 2) { $p = 512 * $k / 3; $g.DrawLine((Pn (C 255 140 82 30) 12), $p, 20, $p, 492); $g.DrawLine((Pn (C 255 140 82 30) 12), 20, $p, 492, $p)
  $g.DrawLine((Pn (C 255 236 190 120) 4), $p + 9, 20, $p + 9, 492); $g.DrawLine((Pn (C 255 236 190 120) 4), 20, $p + 9, 492, $p + 9) }   # cut edges catching light
for ($r = 0; $r -lt 5; $r++) {                                                    # caramel zigzags across the top
  $y0 = 60 + $r * 95; $pts = @()
  for ($x = 10; $x -le 502; $x += 70) { $pts += P $x ($y0 + $rnd.Next(-28, 28)) }
  Caramel ([System.Drawing.PointF[]]$pts) 14
}

# ---- sides (512..1024, 0..512): v 0 = top of the side ----
Grad 512 0 512 512 (C 255 205 140 62) (C 255 236 190 115) 90
$g.FillRectangle((Br (C 255 165 96 38)), 512, 0, 512, 40)                         # toasted top edge
foreach ($x in 682, 853) { $g.DrawLine((Pn (C 255 160 100 45) 8), $x, 0, $x, 512) }
for ($i = 0; $i -lt 500; $i++) { $g.FillEllipse((Br (C 35 120 70 25)), 512 + $rnd.Next(512), $rnd.Next(512), 6, 6) }
for ($i = 0; $i -lt 9; $i++) {                                                    # caramel drips from the top
  $x = 530 + $rnd.Next(470); $len = $rnd.Next(60, 260)
  Caramel ([System.Drawing.PointF[]]@((P $x 0), (P ($x + $rnd.Next(-8, 8)) ($len / 2)), (P ($x + $rnd.Next(-6, 6)) $len))) 12
  $g.FillEllipse((Br (C 255 180 104 36)), $x - 9, $len - 6, 18, 20)
}

# ---- plate (0..512, 512..1024) ----
$g.FillRectangle((Br (C 255 246 241 230)), 0, 512, 512, 512)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath; $path.AddEllipse(0, 512, 512, 512)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path; $pg.CenterColor = (C 255 250 247 238); $pg.SurroundColors = @((C 255 222 214 198)); $g.FillPath($pg, $path)
# (plain plate, no caramel: user 2026-10-29 (23))

# ---- cream (512..1024, 512..1024) ----
$g.FillRectangle((Br (C 255 250 248 242)), 512, 512, 512, 512)
for ($k = 0; $k -lt 7; $k++) { $rr = 30 + $k * 34; $g.DrawEllipse((Pn (C 70 200 190 175) 6), 768 - $rr, 768 - $rr, 2 * $rr, 2 * $rr) }   # swirl ridges
for ($i = 0; $i -lt 1400; $i++) { $a = $rnd.NextDouble() * 6.283; $rr = [Math]::Sqrt($rnd.NextDouble()) * 230; $g.FillEllipse((Br (C 190 150 95 50)), 768 + $rr * [Math]::Cos($a), 768 + $rr * [Math]::Sin($a), 4, 4) }   # cinnamon

$g.Dispose(); $bmp.Save((Join-Path $Out 'honeybread_tex.png')); $bmp.Dispose(); 'saved'
