# Shop-block facade images (layout v8, user 2026-10-27: "가짜 건물 블록 하나로
#길게 배치 ... 이미지 간판으로 처리"). Each image is one building front, 40 studs
# wide × 60 tall (640 × 960 px): stone/glass facade, stacked shop signs on
# every floor like a Hongdae street, a lit shop front with a big sign below.
# build_hongdae_layout.lua (SHOP_BLOCKS) puts them side by side as decals.
param([string]$OutDir, [int]$Count = 8)
Add-Type -AssemblyName System.Drawing
$W = 640; $H = 960
function C([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$shops = @(
  @('보드게임카페', (C 200 40 50)), @('코인노래연습장', (C 30 30 35)), @('하나투어', (C 40 50 140)), @('VELVET', (C 35 35 40)),
  @('PASTA BAR', (C 60 60 64)), @('로라 헤어', (C 245 245 245)), @('경희 한의원', (C 40 50 120)), @('GS25', (C 30 140 220)),
  @('한우 곱창', (C 150 30 30)), @('세무사 사무소', (C 250 250 250)), @('필라테스', (C 230 120 160)), @('OHU 치과', (C 60 160 140)),
  @('PC방 24시', (C 20 20 25)), @('셀프 사진관', (C 245 245 245)), @('내과 · 검진', (C 250 248 240)), @('마라탕', (C 220 30 30)),
  @('스터디카페', (C 40 110 70)), @('네일 아트', (C 250 190 210)), @('떡볶이', (C 240 90 40)), @('안경원', (C 20 60 140)),
  @('빈티지샵', (C 120 80 50)), @('영어학원', (C 40 80 170)), @('치킨 & 호프', (C 250 200 30)), @('부동산', (C 30 120 60)),
  @('타로 카페', (C 90 40 130)), @('헬스 24', (C 25 25 30)), @('스시 오마카세', (C 245 240 230)), @('포토 스튜디오', (C 230 230 235))
)
$walls = @((C 205 196 182), (C 120 124 130), (C 178 150 130), (C 228 226 220), (C 90 96 104), (C 196 176 150))
New-Item -ItemType Directory -Force $OutDir | Out-Null
for ($v = 0; $v -lt $Count; $v++) {
  $bmp = New-Object System.Drawing.Bitmap $W, $H
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $wall = $walls[$v % $walls.Count]
  $g.Clear($wall)
  $glassy = ($v % 3 -eq 1)
  $dark = New-Object System.Drawing.SolidBrush (C 38 46 56)
  $floorH = 112; $ground = 176
  # windows on every floor
  for ($y = 40; $y -lt $H - $ground - 40; $y += $floorH) {
    if ($glassy) {
      $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 70 96 120)), 16, $y, $W - 32, $floorH - 18)
      for ($x = 16; $x -lt $W - 16; $x += 78) { $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 60 64 70)), $x, $y, 5, $floorH - 18) }
    } else {
      for ($x = 28; $x -lt $W - 60; $x += 152) { $g.FillRectangle($dark, $x, $y + 6, 128, $floorH - 34) }
    }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 0, 0, 0))), 0, $y + $floorH - 18, $W, 6)
  }
  # stacked signs: one or two per floor, plus a tall vertical sign on one side
  $k = $v * 5
  $fl = 2
  for ($y = 52; $y -lt $H - $ground - 60; $y += $floorH) {
    $two = (($k + $fl) % 2 -eq 0)
    $n = if ($two) { 2 } else { 1 }
    for ($i = 0; $i -lt $n; $i++) {
      $s = $shops[($k * 3 + $fl * 2 + $i) % $shops.Count]
      $bw = if ($two) { 250 } else { 470 }
      $bx = if ($two) { 40 + $i * 290 } else { 60 + (($k + $fl) % 2) * 70 }
      $bg = $s[1]
      $g.FillRectangle((New-Object System.Drawing.SolidBrush $bg), $bx, $y + 26, $bw, 52)
      $lum = $bg.R + $bg.G + $bg.B
      $fg = if ($lum -lt 380) { [System.Drawing.Color]::White } else { C 30 40 110 }
      $txt = "$($s[0]) $($fl)F"
      $size = 34
      $font = New-Object System.Drawing.Font 'Malgun Gothic', $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
      while ($g.MeasureString($txt, $font).Width -gt $bw - 16 -and $size -gt 14) { $size -= 2; $font = New-Object System.Drawing.Font 'Malgun Gothic', $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel) }
      $m = $g.MeasureString($txt, $font)
      $g.DrawString($txt, $font, (New-Object System.Drawing.SolidBrush $fg), $bx + ($bw - $m.Width) / 2, $y + 26 + (52 - $m.Height) / 2)
    }
    $fl++
  }
  # tall vertical sign
  $vs = $shops[($k + 7) % $shops.Count]
  $vx = if ($v % 2 -eq 0) { $W - 64 } else { 14 }
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $vs[1]), $vx, 70, 50, 470)
  $vfont = New-Object System.Drawing.Font 'Malgun Gothic', 32, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $vfg = if (($vs[1].R + $vs[1].G + $vs[1].B) -lt 380) { [System.Drawing.Color]::White } else { C 30 40 110 }
  $chars = ($vs[0] -replace ' ', '').ToCharArray() | Select-Object -First 9
  $cy = 84
  foreach ($ch in $chars) { $m = $g.MeasureString([string]$ch, $vfont); $g.DrawString([string]$ch, $vfont, (New-Object System.Drawing.SolidBrush $vfg), $vx + (50 - $m.Width) / 2, $cy); $cy += 50 }
  # ground floor: lit shop window, big sign, awning stripe
  $gy = $H - $ground
  $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 50 46 44)), 0, $gy, $W, $ground)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 255 226 170)), 26, $gy + 78, $W - 52, $ground - 92)
  for ($x = 26; $x -lt $W - 26; $x += 118) { $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 40 40 44)), $x, $gy + 78, 6, $ground - 92) }
  $bs = $shops[($k + 3) % $shops.Count]
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $bs[1]), 0, $gy, $W, 66)
  $bfont = New-Object System.Drawing.Font 'Malgun Gothic', 44, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $bfg = if (($bs[1].R + $bs[1].G + $bs[1].B) -lt 380) { [System.Drawing.Color]::White } else { C 30 40 110 }
  $m = $g.MeasureString($bs[0], $bfont)
  $g.DrawString($bs[0], $bfont, (New-Object System.Drawing.SolidBrush $bfg), ($W - $m.Width) / 2, $gy + (66 - $m.Height) / 2)
  # roof edge
  $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 70 70 76)), 0, 0, $W, 18)
  $g.Dispose()
  $f = Join-Path $OutDir ("facade_{0}.png" -f ($v + 1))
  $bmp.Save($f, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  $f
}
