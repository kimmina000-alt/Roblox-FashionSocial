# OH24 shelf row pictures (D-322, 2026-10-26): one 8-stud tile per goods
# category, drawn from src/.../Shared/OH24Products.lua, so a shelf row is one
# Texture instead of a SurfaceGui with a text label per pack (1,286 labels).
# (PowerShell names ignore case: $IMGW is not $w.) Tile = 8 studs x 1.75 studs (1024 x 256 px): packs on the bottom edge of the
# goods area, price strip under it (not for fridge categories).
# Writes docs/04_ART/textures/oh24_row_<category>.png (and copies to $copyTo).
param([string]$copyTo = '')
Add-Type -AssemblyName System.Drawing
$root = Split-Path (Split-Path $PSScriptRoot)
$out = Join-Path $root 'docs\04_ART\textures'
$src = Get-Content (Join-Path $root 'src\ReplicatedStorage\FashionGame\Shared\OH24Products.lua') -Raw -Encoding UTF8

$shapes = @{}
foreach ($m in [regex]::Matches($src, '(\w+) = \{ size = Vector3\.new\(([\d.]+), ([\d.]+), ([\d.]+)\)')) {
  $shapes[$m.Groups[1].Value] = @([double]$m.Groups[2].Value, [double]$m.Groups[3].Value)
}
$cats = [ordered]@{}
$cur = $null
foreach ($line in $src -split "`n") {
  if ($line -match '^\t(\w+) = \{\s*$') { $cur = $Matches[1]; $cats[$cur] = @() ; continue }
  if ($cur -and $line -match 'p\("(\w+)", "([^"]*)", "(\w+)", (\d+), (\d+), (\d+)\)') {
    $cats[$cur] += ,@($Matches[2].Replace('\n', "`n"), $Matches[3], [int]$Matches[4], [int]$Matches[5], [int]$Matches[6])
  }
  if ($line -match '^\t\},\s*$') { $cur = $null }
}

$IMGW = 1024; $IMGH = 256; $TILE = 8.0; $FACE = 1.75; $STRIP = 0.3
$pxU = $IMGW / $TILE; $pxV = $IMGH / $FACE
$noTags = @('drink_bottle', 'drink_can', 'milk')
$prices = @('1,500', '1,800', '2,200', '1,200', '2,500', '1+1', '2+1')
$round = @('bottle', 'can', 'milk', 'tube')

function RoundRect($g, $brush, $x, $y, $w, $h, $r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $r = [math]::Min($r, [math]::Min($w, $h) / 2)
  $p.AddArc($x, $y, 2 * $r, 2 * $r, 180, 90); $p.AddArc($x + $w - 2 * $r, $y, 2 * $r, 2 * $r, 270, 90)
  $p.AddArc($x + $w - 2 * $r, $y + $h - 2 * $r, 2 * $r, 2 * $r, 0, 90); $p.AddArc($x, $y + $h - 2 * $r, 2 * $r, 2 * $r, 90, 90)
  $p.CloseFigure(); $g.FillPath($brush, $p); $p.Dispose()
}

foreach ($cat in $cats.Keys) {
  $list = $cats[$cat]
  $tags = -not ($noTags -contains $cat)
  $goodsH = if ($tags) { $FACE - $STRIP } else { $FACE }
  $bmp = New-Object System.Drawing.Bitmap $IMGW, $IMGH
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear([System.Drawing.Color]::FromArgb(240, 240, 242))
  $baseY = $goodsH * $pxV
  $x = 0.1; $i = 0
  while ($true) {
    $pr = $list[$i % $list.Count]; $i++
    $base = $shapes[$pr[1]]
    $scale = [math]::Min(1, ($goodsH - 0.12) / $base[1])
    $w = $base[0] * $scale; $ph = $base[1] * $scale
    if ($x + $w -gt $TILE - 0.1) { break }
    $rx = $x * $pxU; $rw = $w * $pxU; $rh = $ph * $pxV; $ry = $baseY - $rh
    $col = [System.Drawing.Color]::FromArgb($pr[2], $pr[3], $pr[4])
    $b = New-Object System.Drawing.SolidBrush $col
    $rad = if ($round -contains $pr[1]) { $rw * 0.25 } else { 4 }
    RoundRect $g $b $rx $ry $rw $rh $rad
    $b.Dispose()
    $wb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(204, 255, 255, 255))
    $g.FillRectangle($wb, [single]($rx + $rad * 0.3), [single]$ry, [single]($rw - $rad * 0.6), [single]($rh * 0.16)); $wb.Dispose()
    $light = ($pr[2] + $pr[3] + $pr[4]) -gt 561
    $tc = if ($light) { [System.Drawing.Color]::FromArgb(40, 40, 50) } else { [System.Drawing.Color]::White }
    $lines = ($pr[0] -split "`n").Count
    $size = [math]::Max(8, [math]::Min($rh * 0.5 / $lines, $rw * 0.82 / [math]::Max(2, (($pr[0] -split "`n") | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)))
    $font = New-Object System.Drawing.Font 'Malgun Gothic', ([single]$size), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'; $sf.FormatFlags = 'NoWrap'
    $tb = New-Object System.Drawing.SolidBrush $tc
    $g.DrawString($pr[0], $font, $tb, (New-Object System.Drawing.RectangleF ([single]$rx), ([single]($ry + $rh * 0.2)), ([single]$rw), ([single]($rh * 0.75))), $sf)
    $tb.Dispose(); $font.Dispose()
    $x += $w + [math]::Max(0.45, $w * 0.5)
  }
  if ($tags) {
    $sy = $baseY
    $sb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 215, 220))
    $g.FillRectangle($sb, 0, [single]$sy, $IMGW, [single]($IMGH - $sy)); $sb.Dispose()
    $font = New-Object System.Drawing.Font 'Arial', 15, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $tw = 1.4 * $pxU
    for ($k = 0; $k -lt [math]::Floor($TILE / 1.4); $k++) {
      $bg = if (($k + 1) % 5 -eq 0) { [System.Drawing.Color]::FromArgb(250, 220, 60) } else { [System.Drawing.Color]::White }
      $bb = New-Object System.Drawing.SolidBrush $bg
      $tx = 10 + $k * $tw
      $g.FillRectangle($bb, [single]$tx, [single]($sy + 6), [single]70, [single]($IMGH - $sy - 12)); $bb.Dispose()
      $g.DrawString($prices[($k + 1) % 7], $font, [System.Drawing.Brushes]::Black, (New-Object System.Drawing.RectangleF ([single]$tx), ([single]($sy + 6)), 70, ([single]($IMGH - $sy - 12))), $sf)
    }
    $font.Dispose()
  }
  $g.Dispose()
  $file = Join-Path $out "oh24_row_$cat.png"
  # saved at half size (512 x 128): the full size cost as much texture memory as the labels it replaced
  $small = New-Object System.Drawing.Bitmap 512, 128
  $sg = [System.Drawing.Graphics]::FromImage($small); $sg.InterpolationMode = 'HighQualityBicubic'; $sg.DrawImage($bmp, 0, 0, 512, 128); $sg.Dispose()
  $small.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $small.Dispose(); $bmp.Dispose()
  if ($copyTo) { Copy-Item $file $copyTo }
}
"done: " + ($cats.Keys -join ',')
