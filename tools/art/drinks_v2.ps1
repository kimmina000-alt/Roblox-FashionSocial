param([string]$Out)
# Drink pictures v2 (user photos 2026-10-28 (3), D-458). Our own names and
# drawings in the colours and layouts of the user's photos: no brand names,
# logos or alcohol wording.
#   cans (store can mesh): label 435 x 696 at (0, 328), height across, round down
#   bottle skins (UV meshes): u = once round (front in the middle), v = foot..top;
#   transparent pixels show the part colour (the drink's glass colour)
Add-Type -AssemblyName System.Drawing
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Br($c) { New-Object System.Drawing.SolidBrush $c }
function Pn($c, $w) { $p = New-Object System.Drawing.Pen $c, $w; $p.LineJoin = 'Round'; $p.StartCap = 'Round'; $p.EndCap = 'Round'; $p }
function G($bmp) { $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g }
# text fitted into a box (cx, cy centre, maxW, size), optional outline
function Txt($g, $text, $font, $style, $size, $cx, $cy, $maxW, $fill, $outline, $ow) {
  $fam = New-Object System.Drawing.FontFamily $font
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddString($text, $fam, [int]$style, $size, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  $b = $p.GetBounds(); $sx = [math]::Min(1, $maxW / [math]::Max(1, $b.Width))
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate($cx - $b.Width * $sx / 2, $cy - $b.Height / 2); $m.Scale($sx, 1); $m.Translate(-$b.X, -$b.Y); $p.Transform($m)
  if ($outline) { $g.DrawPath((Pn $outline $ow), $p) }
  $g.FillPath((Br $fill), $p)
}

# ------------------------------------------------------------------ cans
$RW = 696; $RH = 435
function Can($name, $draw) {
  $up = New-Object System.Drawing.Bitmap $RW, $RH; $g = G $up
  & $draw $g
  $g.Dispose()
  $canBmp = New-Object System.Drawing.Bitmap 1024, 1024; $g2 = [System.Drawing.Graphics]::FromImage($canBmp); $g2.Clear((C 255 200 202 208))
  $up.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone); $g2.DrawImage($up, 0, 328, 435, 696)
  $g2.Dispose(); $up.Dispose(); $canBmp.Save((Join-Path $Out "$name.png")); $canBmp.Dispose()
}
# 콜라 v3 (user layout 2026-10-28 (6), our words): deep red with cold drops,
# a big white script name tilted up with a swoosh under it, a round badge
function Drops($g, $seed) {
  $rnd = New-Object System.Random $seed
  for ($i = 0; $i -lt 260; $i++) {
    $x = $rnd.Next(0, $RW); $y = $rnd.Next(0, $RH); $s = $rnd.Next(5, 15)
    $g.FillEllipse((Br (C 60 255 255 255)), $x, $y, $s, $s * 1.2)
    $g.FillEllipse((Br (C 90 0 0 0)), $x + $s * 0.15, $y + $s * 0.7, $s * 0.7, $s * 0.4)
    $g.FillEllipse((Br (C 200 255 255 255)), $x + $s * 0.25, $y + $s * 0.2, $s * 0.3, $s * 0.3)
  }
}
Can 'can_cola' { param($g)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, $RW, $RH), (C 255 150 10 25), (C 255 205 25 40), 0
  $bg.SetSigmaBellShape(0.5); $g.FillRectangle($bg, 0, 0, $RW, $RH)
  Drops $g 11
  $st = $g.Save(); $g.TranslateTransform($RW / 2, 150); $g.RotateTransform(-12)
  Txt $g '콜라' 'Nanum Brush Script' 0 230 0 -10 330 (C 255 255 255 255) (C 120 90 0 10) 6
  $g.Restore($st)
  $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 140, 285), (New-Object System.Drawing.PointF 330, 250), (New-Object System.Drawing.PointF 560, 140))
  $g.DrawCurve((Pn (C 255 255 255 255) 7), $pts)
  Txt $g 'OHU · since 2026' 'Segoe UI Black' 0 22 470 210 180 (C 255 255 255 255) $null 0
  $g.DrawEllipse((Pn (C 255 255 255 255) 6), 230, 300, 120, 120); $g.DrawEllipse((Pn (C 255 255 255 255) 3), 245, 315, 90, 90)
  Txt $g 'OHU' 'Georgia' 1 40 290 360 70 (C 255 255 255 255) $null 0
  Txt $g '355ml' 'Segoe UI Black' 0 18 620 410 90 (C 255 255 255 255) $null 0
}# 사이다: green, a pale diagonal band, a dark stripe, white name (sparkles, no star logo)
Can 'can_cider' { param($g)
  $g.Clear((C 255 22 120 60))
  $g.FillPolygon((Br (C 255 210 225 215)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 380, 0), (New-Object System.Drawing.PointF 520, 0), (New-Object System.Drawing.PointF 300, 435), (New-Object System.Drawing.PointF 160, 435)))
  $g.FillPolygon((Br (C 255 20 40 30)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 520, 0), (New-Object System.Drawing.PointF 580, 0), (New-Object System.Drawing.PointF 360, 435), (New-Object System.Drawing.PointF 300, 435)))
  Txt $g 'Cider' 'Segoe Script' 1 120 230 150 300 (C 255 255 255 255) (C 255 10 70 30) 8
  Txt $g '사이다' 'NanumSquare ExtraBold' 0 70 170 300 200 (C 255 255 255 255) $null 0
  foreach ($s in @(@(120, 60), @(470, 330), @(600, 120))) { $g.FillEllipse((Br (C 200 255 255 255)), $s[0], $s[1], 10, 10) }
  Txt $g 'ZERO' 'Arial Black' 0 34 600 330 120 (C 255 255 255 255) $null 0
}
# 오렌지: orange, a navy slanted block with a white name, an orange slice and a splash
Can 'can_orange' { param($g)
  $g.Clear((C 255 245 125 20))
  $g.FillPolygon((Br (C 255 40 40 120)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 130, 70), (New-Object System.Drawing.PointF 600, 30), (New-Object System.Drawing.PointF 590, 190), (New-Object System.Drawing.PointF 120, 220)))
  Txt $g 'ORANGE' 'Impact' 0 140 360 125 440 (C 255 255 255 255) (C 255 20 20 70) 10
  $g.FillEllipse((Br (C 255 255 200 60)), 330, 250, 150, 150)
  $g.FillEllipse((Br (C 255 250 150 30)), 342, 262, 126, 126)
  for ($i = 0; $i -lt 8; $i++) { $a = $i * [math]::PI / 4; $g.DrawLine((Pn (C 255 255 230 160) 5), 405, 325, 405 + 60 * [math]::Cos($a), 325 + 60 * [math]::Sin($a)) }
  $g.FillEllipse((Br (C 160 255 255 255)), 470, 240, 40, 22); $g.FillEllipse((Br (C 160 255 255 255)), 290, 360, 30, 16)
  Txt $g '오렌지' 'NanumSquare ExtraBold' 0 44 210 300 160 (C 255 255 255 255) $null 0
}
# 레몬에이드 v3 (user layout 2026-10-28 (6), our words): yellow with cold
# drops, a tilted lemon-shaped label with a green edge and a script name, two
# lemons with leaves under it
Can 'can_lemonade' { param($g)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, $RW, $RH), (C 255 225 190 0), (C 255 255 235 40), 0
  $bg.SetSigmaBellShape(0.5); $g.FillRectangle($bg, 0, 0, $RW, $RH)
  Drops $g 23
  $leaf = { param($x, $y, $rot) $st = $g.Save(); $g.TranslateTransform($x, $y); $g.RotateTransform($rot); $g.FillEllipse((Br (C 255 60 150 60)), -34, -14, 68, 28); $g.DrawEllipse((Pn (C 255 20 60 20) 4), -34, -14, 68, 28); $g.DrawLine((Pn (C 255 20 60 20) 2), -30, 0, 30, 0); $g.Restore($st) }
  foreach ($l in @(@(250, 90, -30), @(470, 120, 20), @(300, 330, -10), @(420, 300, 30), @(250, 400, 40))) { & $leaf $l[0] $l[1] $l[2] }
  foreach ($lm in @(@(270, 300), @(400, 330))) {
    $g.FillEllipse((Br (C 255 255 240 30)), $lm[0], $lm[1], 150, 100); $g.DrawEllipse((Pn (C 255 30 30 20) 4), $lm[0], $lm[1], 150, 100)
    $g.FillEllipse((Br (C 200 255 255 255)), $lm[0] + 30, $lm[1] + 15, 40, 18)
  }
  $st = $g.Save(); $g.TranslateTransform($RW / 2, 175); $g.RotateTransform(-18)
  $g.FillEllipse((Br (C 255 70 175 50)), -175, -95, 350, 190)
  $g.FillEllipse((Br (C 255 255 245 120)), -160, -82, 320, 164)
  Txt $g 'Hongdae' 'Segoe Script' 1 40 -20 -40 200 (C 255 120 80 20) $null 0
  Txt $g 'Lemonade' 'Segoe Script' 1 80 0 15 300 (C 255 255 255 255) (C 255 30 30 20) 9
  Txt $g 'lemon sparkling · 레몬에이드' 'Malgun Gothic' 1 18 10 62 220 (C 255 60 130 30) $null 0
  $g.Restore($st)
  Txt $g 'OHU · 355ml' 'Segoe UI Black' 0 20 ($RW / 2) 418 160 (C 255 40 40 30) $null 0
}# 블루에이드: blue, big yellow Korean name, lemon slices round it
Can 'can_blueade' { param($g)
  $g.Clear((C 255 30 95 200))
  $rnd = New-Object System.Random 9
  for ($i = 0; $i -lt 12; $i++) {
    $x = $rnd.Next(0, 660); $y = $rnd.Next(0, 400)
    if ($x -gt 200 -and $x -lt 480) { continue }
    $g.FillPie((Br (C 255 250 220 60)), $x, $y, 50, 50, $rnd.Next(0, 360), 180)
  }
  Txt $g '블루' 'Noto Sans KR Black' 0 120 345 120 240 (C 255 250 220 60) $null 0
  Txt $g '레몬' 'Noto Sans KR Black' 0 120 345 250 240 (C 255 250 220 60) $null 0
  Txt $g 'BLUE LEMON ADE' 'Segoe UI Black' 0 26 345 335 230 (C 255 255 255 255) $null 0
  $g.FillRectangle((Br (C 255 245 215 70)), 0, 400, $RW, 35)
}

# ------------------------------------------------------------------ bottle skins
$S = 1024
function Skin($name, $draw) {
  $b = New-Object System.Drawing.Bitmap $S, $S; $g = G $b; $g.Clear([System.Drawing.Color]::Transparent)
  & $draw $g
  $g.Dispose(); $b.Save((Join-Path $Out "$name.png")); $b.Dispose()
}
function Y($v) { (1 - $v) * $S }        # v (0 foot .. 1 top) to pixel y
function X($u) { $u * $S }

# tier 2: printed straight on the bottle like the photos (big caps name,
# a flavour word under it, small script lines), colours per drink
$tier2 = @(
  @('ginger', 'GINGER', 'BREW', (C 255 255 255 255), (C 255 255 214 180)),
  @('monte', 'MONTE', 'SPARKLING', (C 255 235 255 160), (C 255 255 255 255)),
  @('french', 'FRENCH', 'LEMONADE', (C 255 255 255 255), (C 255 250 235 120)),
  @('apple', 'GOLDEN', 'APPLE', (C 255 255 255 255), (C 255 255 230 170)),
  @('zzang', 'ZZANG', 'POP', (C 255 255 255 255), (C 255 255 210 235)),
  @('hot', 'HOT', 'BOOST', (C 255 255 230 90), (C 255 255 255 255)),
  @('claw', 'GREEN', 'CLAW', (C 255 240 255 200), (C 255 255 255 255)),
  @('wing', 'BLUE', 'WING', (C 255 25 55 160), (C 255 25 55 160))
)
foreach ($t in $tier2) {
  Skin "skin_tier2_$($t[0])" {
    param($g)
    Txt $g $t[1] 'Arial Black' 0 64 (X 0.5) (Y 0.56) (X 0.17) $t[3] $null 0
    Txt $g $t[2] 'Arial Black' 0 54 (X 0.5) (Y 0.49) (X 0.15) $t[4] $null 0
    foreach ($i in 0..3) { Txt $g 'Made in Hongdae · OHU club · since 2026' 'Segoe Script' 0 22 (X 0.5) (Y (0.42 - $i * 0.028)) (X 0.16) $t[4] $null 0 }
    Txt $g 'OHU · SPARKLING' 'Segoe UI Black' 0 16 (X 0.5) (Y 0.29) (X 0.14) $t[3] $null 0
    $g.FillRectangle((Br (C 255 196 200 206)), 0, (Y 1.0), $S, (Y 0.895) - (Y 1.0))   # metal cap
  }
}

# 스택 하이드로 (the square honey-whiskey photo, our words): a cream front
# label with a black frame, a bee, black serif lettering; a neck label; black cap
Skin 'skin_stack_hydro' { param($g)
  $l = X 0.29; $r = X 0.71; $t = Y 0.6; $b = Y 0.17
  $g.FillRectangle((Br (C 255 245 236 205)), $l, $t, $r - $l, $b - $t)
  $g.DrawRectangle((Pn (C 255 30 25 20) 6), $l + 10, $t + 10, $r - $l - 20, $b - $t - 20)
  $g.DrawRectangle((Pn (C 255 160 130 70) 2), $l + 22, $t + 22, $r - $l - 44, $b - $t - 44)
  Txt $g 'STACK HYDRO' 'Bodoni Bd BT' 0 60 (X 0.5) (Y 0.535) (X 0.36) (C 255 25 20 18) $null 0
  # bee: body stripes, wings
  $bx = X 0.5; $by = Y 0.47
  $g.FillEllipse((Br (C 120 200 210 220)), $bx - 50, $by - 22, 44, 26); $g.FillEllipse((Br (C 120 200 210 220)), $bx + 6, $by - 22, 44, 26)
  $g.FillEllipse((Br (C 255 30 25 20)), $bx - 14, $by - 16, 28, 44)
  foreach ($k in 0..2) { $g.FillRectangle((Br (C 255 230 180 40)), $bx - 12, $by - 6 + $k * 11, 24, 5) }
  Txt $g 'ORIGINAL RECIPE' 'Bodoni Bd BT' 0 30 (X 0.5) (Y 0.41) (X 0.3) (C 255 25 20 18) $null 0
  Txt $g 'Hydro Honey' 'Georgia' 1 56 (X 0.5) (Y 0.355) (X 0.3) (C 255 25 20 18) $null 0
  Txt $g 'SPARKLING HONEY WATER' 'Bodoni Bd BT' 0 26 (X 0.5) (Y 0.3) (X 0.3) (C 255 150 120 60) $null 0
  Txt $g 'OHU · Hongdae' 'Georgia' 2 24 (X 0.5) (Y 0.24) (X 0.24) (C 255 25 20 18) $null 0
  # neck label round, then a black cap
  $g.FillRectangle((Br (C 255 245 236 205)), 0, (Y 0.86), $S, (Y 0.79) - (Y 0.86))
  for ($u = 0.1; $u -lt 1; $u += 0.25) { Txt $g 'STACK HYDRO' 'Bodoni Bd BT' 0 24 (X $u) (Y 0.825) (X 0.16) (C 255 25 20 18) $null 0 }
  $g.FillRectangle((Br (C 255 20 20 22)), 0, (Y 1.0), $S, (Y 0.9) - (Y 1.0))
}

# 파스텔 스플래시 (the frosted orange photo, our words): a tall white serif
# letter, script and caps lines, a clear ring and an orange cap
Skin 'skin_pastel_splash' { param($g)
  Txt $g 'P' 'Bodoni Bk BT' 0 520 (X 0.5) (Y 0.46) (X 0.2) (C 245 255 255 255) $null 0
  Txt $g 'PASTEL' 'Bodoni Bd BT' 0 34 (X 0.5) (Y 0.2) (X 0.12) (C 255 200 40 40) $null 0
  Txt $g 'Splash Sparkling' 'Segoe Script' 0 30 (X 0.5) (Y 0.165) (X 0.16) (C 255 255 255 255) $null 0
  $g.DrawLine((Pn (C 255 255 255 255) 2), (X 0.42), (Y 0.145), (X 0.58), (Y 0.145))
  Txt $g 'PEACH BLUSH' 'Times New Roman' 0 40 (X 0.5) (Y 0.12) (X 0.16) (C 255 255 255 255) $null 0
  $g.DrawLine((Pn (C 255 255 255 255) 2), (X 0.42), (Y 0.1), (X 0.58), (Y 0.1))
  $g.FillRectangle((Br (C 150 245 248 250)), 0, (Y 0.92), $S, (Y 0.885) - (Y 0.92))
  $g.FillRectangle((Br (C 255 245 110 35)), 0, (Y 1.0), $S, (Y 0.92) - (Y 1.0))
}

# 스컬 앤 워터 (the black swing-top photo, our words): a black label with
# orange blackletter-style lettering and a gold line-art melting skull; the top
# wrapped in crinkled silver foil with a red tag
Skin 'skin_skull_water' { param($g)
  $l = X 0.3; $r = X 0.7; $t = Y 0.6; $b = Y 0.1
  $g.FillRectangle((Br (C 255 12 12 14)), $l, $t, $r - $l, $b - $t)
  Txt $g 'Skull &' 'Times New Roman' 1 96 (X 0.5) (Y 0.55) (X 0.32) (C 255 240 120 30) (C 255 120 40 10) 4
  Txt $g 'Water' 'Times New Roman' 1 96 (X 0.5) (Y 0.48) (X 0.32) (C 255 240 120 30) (C 255 120 40 10) 4
  Txt $g 'CHILLED TO THE BONE' 'Times New Roman' 1 28 (X 0.5) (Y 0.43) (X 0.26) (C 255 240 140 40) $null 0
  Txt $g '— FLAVORED SPARKLING WATER —' 'Times New Roman' 0 18 (X 0.5) (Y 0.405) (X 0.26) (C 255 230 190 90) $null 0
  # the skull: gold lines, dripping
  $gold = C 255 235 185 60; $cx = X 0.5; $cy = Y 0.28
  $g.DrawEllipse((Pn $gold 6), $cx - 80, $cy - 90, 160, 140)
  $g.FillEllipse((Br $gold), $cx - 50, $cy - 40, 38, 42); $g.FillEllipse((Br $gold), $cx + 12, $cy - 40, 38, 42)
  $g.FillEllipse((Br (C 255 12 12 14)), $cx - 42, $cy - 32, 22, 26); $g.FillEllipse((Br (C 255 12 12 14)), $cx + 20, $cy - 32, 22, 26)
  $g.FillPolygon((Br $gold), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ($cx - 8), ($cy + 10)), (New-Object System.Drawing.PointF ($cx + 8), ($cy + 10)), (New-Object System.Drawing.PointF $cx, ($cy - 6))))
  for ($k = -3; $k -le 3; $k++) { $g.DrawLine((Pn $gold 5), $cx + $k * 14, $cy + 30, $cx + $k * 14, $cy + 46) }
  $rnd = New-Object System.Random 13
  for ($k = 0; $k -lt 26; $k++) { $x = $cx - 120 + $rnd.Next(0, 240); $y0 = $cy + 20 + $rnd.Next(0, 40); $g.DrawBezier((Pn $gold 3), $x, $y0, $x + $rnd.Next(-20, 20), $y0 + 30, $x + $rnd.Next(-25, 25), $y0 + 60, $x + $rnd.Next(-10, 10), $y0 + 90 + $rnd.Next(0, 40)) }
  for ($k = 0; $k -lt 14; $k++) { $a = $k / 14 * 2 * [math]::PI; $g.DrawBezier((Pn $gold 3), $cx + 85 * [math]::Cos($a), $cy - 20 + 75 * [math]::Sin($a), $cx + 120 * [math]::Cos($a), $cy - 20 + 100 * [math]::Sin($a), $cx + 140 * [math]::Cos($a + 0.3), $cy - 20 + 110 * [math]::Sin($a + 0.3), $cx + 150 * [math]::Cos($a + 0.5), $cy - 20 + 120 * [math]::Sin($a + 0.5)) }
  # silver foil over the top (v 0.8..1.0): crinkled bands of light and shade
  $top = Y 1.0; $bot = Y 0.8
  $g.FillRectangle((Br (C 255 190 192 196)), 0, $top, $S, $bot - $top)
  $rnd = New-Object System.Random 21
  for ($k = 0; $k -lt 420; $k++) {
    $x = $rnd.Next(0, $S); $y = $rnd.Next([int]$top, [int]$bot); $w = $rnd.Next(10, 46); $h = $rnd.Next(4, 16)
    $c = if ($rnd.NextDouble() -lt 0.5) { C 170 250 252 255 } else { C 140 110 114 120 }
    $g.FillPolygon((Br $c), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF $x, $y), (New-Object System.Drawing.PointF ($x + $w), ($y + $rnd.Next(-6, 6))), (New-Object System.Drawing.PointF ($x + $w * 0.6), ($y + $h))))
  }
  # ragged lower edge of the foil and a red tag strip
  for ($x = 0; $x -lt $S; $x += 18) { $g.FillPolygon((Br (C 255 175 178 182)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF $x, $bot), (New-Object System.Drawing.PointF ($x + 18), $bot), (New-Object System.Drawing.PointF ($x + 9), ($bot + $rnd.Next(6, 22))))) }
  $g.FillRectangle((Br (C 255 200 30 40)), 0, (Y 0.95), $S, (Y 0.925) - (Y 0.95))
}
"saved"
