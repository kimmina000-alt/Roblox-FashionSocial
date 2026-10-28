param([string]$Out)
# Construction netting tiles (user photo 2026-10-28): teal-green mesh on
# scaffold pipes (lower band) and a plain blue mesh (upper band). One tile =
# 8 x 8 studs: a vertical pipe on the left edge, a horizontal pipe at the top.
Add-Type -AssemblyName System.Drawing
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Tile($name, $base, $hi, $pipes) {
  $W = 512
  $b = New-Object System.Drawing.Bitmap $W, $W
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.Clear($base)
  # fine weave
  for ($i = 0; $i -lt $W; $i += 4) {
    $g.DrawLine((New-Object System.Drawing.Pen $hi, 1), $i, 0, $i, $W)
    $g.DrawLine((New-Object System.Drawing.Pen (C 40 0 0 0), 1), 0, $i, $W, $i)
  }
  # soft folds of the sheet
  $rnd = New-Object System.Random 7
  for ($i = 0; $i -lt 6; $i++) {
    $x = $rnd.Next(30, 480)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 26 255 255 255)), $x, 0, 10, $W)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 30 0 0 0)), $x + 10, 0, 14, $W)
  }
  # sewn seam halfway down
  $g.DrawLine((New-Object System.Drawing.Pen (C 70 255 255 255), 2), 0, 256, $W, 256)
  if ($pipes) {
    $pipe = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 16, 10), (C 255 210 212 214), (C 255 120 124 128), 0
    $g.FillRectangle($pipe, 0, 0, 16, $W)
    $pipeH = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 10, 14), (C 255 215 217 219), (C 255 125 128 132), 90
    $g.FillRectangle($pipeH, 0, 0, $W, 14)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 255 90 92 96)), 0, 0, 22, 20)   # clamp
  }
  $g.Dispose(); $b.Save((Join-Path $Out $name)); $b.Dispose()
}
Tile 'net_teal.png' (C 255 40 150 142) (C 60 120 220 210) $true
Tile 'net_blue.png' (C 255 36 86 196) (C 60 120 160 255) $false
"saved"
