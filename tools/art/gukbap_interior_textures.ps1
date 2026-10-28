param([string]$Out)
# 국밥집 interior textures (user 2026-10-29: build the hall like an old Busan
# 돼지국밥 restaurant): hangul-pattern wallpaper, a strip of handwritten guest
# notes for the walls, and the white menu board with a bowl picture.
# No alcohol on the menu (content rules); generic names only.
Add-Type -AssemblyName System.Drawing
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Br($c) { New-Object System.Drawing.SolidBrush $c }
function F($name, $px, $style = 'Regular') { New-Object System.Drawing.Font $name, $px, ([System.Drawing.FontStyle]::$style), ([System.Drawing.GraphicsUnit]::Pixel) }
$rnd = New-Object System.Random 7

# ---- 1. hangul wallpaper (tiles) ------------------------------------------
$bmp = New-Object System.Drawing.Bitmap 512, 512
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
$g.Clear((C 255 226 216 192))
$syll = '가나다라마바사아자차카타파하국밥맛집정성손님고맙습니다오후한글사랑봄여름가을겨울하늘바다별꽃'.ToCharArray()
$font = F 'Batang' 30
for ($row = 0; $row -lt 12; $row++) {
  for ($col = 0; $col -lt 12; $col++) {
    $x = $col * 43 + 4; $y = $row * 43 + 4
    if ($rnd.NextDouble() -lt 0.12) {
      $g.FillRectangle((Br (C 200 92 70 52)), $x + 6, $y + 6, 28, 28)   # dark seal square
      $g.DrawString([string]$syll[$rnd.Next($syll.Length)], (F 'Batang' 22), (Br (C 255 226 216 192)), $x + 7, $y + 7)
    } else {
      $g.DrawString([string]$syll[$rnd.Next($syll.Length)], $font, (Br (C 150 120 96 70)), $x, $y)
    }
  }
}
$g.Dispose(); $bmp.Save((Join-Path $Out 'gukbap_wallpaper.png')); $bmp.Dispose()

# ---- 2. guest notes strip ---------------------------------------------------
$bmp = New-Object System.Drawing.Bitmap 1024, 256
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
$g.Clear((C 0 0 0 0))
$msgs = @('맛있어요!!', 'So nice :)', '또 올게요~', 'Delicious!', 'おいしかった', '好吃极了', '국물 최고', 'Must try!', '사장님 짱', 'Very good', '부산 최고!', '♡ 또 와요', 'Yummy!!', '든든해요')
$pens = @((C 255 30 30 34), (C 255 30 60 160), (C 255 180 30 40), (C 255 60 60 60))
$fonts = @('Ink Free', 'Segoe Print', 'Malgun Gothic', 'Yu Gothic', 'Microsoft YaHei')
$x = 0
while ($x -lt 1024) {
  $w = $rnd.Next(110, 160); $h = $rnd.Next(150, 230); $y = $rnd.Next(4, 256 - $h)
  $st = $g.Save(); $g.TranslateTransform($x + $w / 2, $y + $h / 2); $g.RotateTransform($rnd.Next(-4, 5))
  $paper = if ($rnd.NextDouble() -lt 0.3) { C 255 246 240 222 } else { C 255 250 250 246 }
  $g.FillRectangle((Br (C 50 0 0 0)), -$w / 2 + 3, -$h / 2 + 3, $w, $h)
  $g.FillRectangle((Br $paper), -$w / 2, -$h / 2, $w, $h)
  $g.FillRectangle((Br (C 120 230 230 220)), -14, -$h / 2 - 4, 28, 10)          # tape
  $pen = $pens[$rnd.Next($pens.Count)]
  $lines = $rnd.Next(2, 5)
  for ($k = 0; $k -lt $lines; $k++) {
    $f = F $fonts[$rnd.Next($fonts.Count)] $rnd.Next(15, 22)
    $g.DrawString($msgs[$rnd.Next($msgs.Count)], $f, (Br $pen), -$w / 2 + 6, -$h / 2 + 10 + $k * ($h - 30) / $lines)
  }
  $g.DrawLine((New-Object System.Drawing.Pen $pen, 1.5), -$w / 2 + 10, $h / 2 - 16, $w / 2 - 30, $h / 2 - 20) # signature
  $g.Restore($st)
  $x += $w - $rnd.Next(0, 12)
}
$g.Dispose(); $bmp.Save((Join-Path $Out 'gukbap_notes.png')); $bmp.Dispose()

# ---- 3. menu board -----------------------------------------------------------
$bmp = New-Object System.Drawing.Bitmap 1024, 320
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
$g.Clear((C 255 250 250 248))
# picture: warm background, a black 뚝배기 of milky soup with pork slices and green onion
$g.FillRectangle((Br (C 255 214 150 90)), 0, 0, 300, 320)
$g.FillEllipse((Br (C 255 24 22 22)), 20, 120, 270, 190)
$g.FillEllipse((Br (C 255 238 232 218)), 38, 132, 234, 150)
foreach ($s in @(@(80, 170), @(140, 160), @(180, 200), @(110, 215))) { $g.FillEllipse((Br (C 255 232 200 190)), $s[0], $s[1], 70, 34); $g.FillEllipse((Br (C 255 200 150 140)), $s[0] + 6, $s[1] + 4, 58, 10) }
for ($k = 0; $k -lt 14; $k++) { $g.FillEllipse((Br (C 255 70 150 60)), $rnd.Next(70, 240), $rnd.Next(150, 250), 12, 9) }
$g.DrawString('정성 가득', (F 'Malgun Gothic' 26 'Bold'), (Br (C 255 120 40 30)), 24, 18)
$g.DrawString('오후 돼지국밥', (F 'Malgun Gothic' 40 'Bold'), (Br (C 255 30 24 20)), 18, 52)
$items = @(@('돼지국밥', '20 코인'), @('순대국밥', '20 코인'), @('소고기국밥', '20 코인'))
for ($i = 0; $i -lt $items.Count; $i++) {
  $g.DrawString($items[$i][0], (F 'Malgun Gothic' 30 'Bold'), (Br (C 255 25 25 25)), 330, 50 + $i * 80)
  $g.DrawString($items[$i][1], (F 'Malgun Gothic' 30 'Bold'), (Br (C 255 200 30 36)), 520, 50 + $i * 80)
}
$g.DrawLine((New-Object System.Drawing.Pen (C 255 200 200 200), 2), 680, 20, 680, 300)
$items2 = @(@('수육 한 접시', 'R$ 19'), @('공깃밥', '무료'), @('김치·깍두기', '무료'))
for ($i = 0; $i -lt $items2.Count; $i++) {
  $g.DrawString($items2[$i][0], (F 'Malgun Gothic' 28 'Bold'), (Br (C 255 25 25 25)), 700, 22 + $i * 56)
  $g.DrawString($items2[$i][1], (F 'Malgun Gothic' 28 'Bold'), (Br (C 255 200 30 36)), 900, 22 + $i * 56)
}
$g.DrawString('※ 24시간 연중무휴', (F 'Malgun Gothic' 22 'Bold'), (Br (C 255 200 30 36)), 700, 262)
$g.Dispose(); $bmp.Save((Join-Path $Out 'gukbap_menu.png')); $bmp.Dispose()
'saved'
