# Draws the top bar icons (user 2026-10-30 mock-up), our own drawings:
# white line icons on transparent (bag, hands + heart, note) and a gold won coin.
# Usage: powershell -ExecutionPolicy Bypass -File tools\dev\icons\draw_icons.ps1 <outDir>
param([string]$Out = "tools\dev\serve")
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null

function New-Canvas([int]$s) {
	$bmp = New-Object System.Drawing.Bitmap $s, $s
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = 'AntiAlias'
	$g.Clear([System.Drawing.Color]::Transparent)
	return @($bmp, $g)
}
function New-Pen([int]$w) {
	$p = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), $w
	$p.StartCap = 'Round'; $p.EndCap = 'Round'; $p.LineJoin = 'Round'
	return $p
}
$white = [System.Drawing.Brushes]::White

# bag: a trapezoid with round corners, an arch handle, two dots
$c = New-Canvas 256; $bmp = $c[0]; $g = $c[1]; $pen = New-Pen 18
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddLines([System.Drawing.PointF[]]@(
	(New-Object System.Drawing.PointF 58, 96), (New-Object System.Drawing.PointF 198, 96),
	(New-Object System.Drawing.PointF 214, 226), (New-Object System.Drawing.PointF 42, 226)))
$path.CloseFigure()
$g.DrawPath($pen, $path)
$g.DrawArc($pen, 88, 34, 80, 110, 180, 180)
$g.DrawLine($pen, 88, 89, 88, 120); $g.DrawLine($pen, 168, 89, 168, 120)
$g.FillEllipse($white, 76, 116, 24, 24); $g.FillEllipse($white, 156, 116, 24, 24)
$g.Dispose(); $bmp.Save((Join-Path $Out "icon_bag.png")); $bmp.Dispose()

# note: a filled eighth note
$c = New-Canvas 256; $bmp = $c[0]; $g = $c[1]
$g.FillEllipse($white, 56, 168, 82, 62)
$g.FillRectangle($white, 120, 34, 20, 168)
$flag = New-Object System.Drawing.Drawing2D.GraphicsPath
$flag.AddBezier(140, 34, 150, 70, 200, 80, 196, 150)
$flag.AddBezier(196, 150, 192, 120, 170, 104, 140, 100)
$flag.CloseFigure()
$g.FillPath($white, $flag)
$g.Dispose(); $bmp.Save((Join-Path $Out "icon_note.png")); $bmp.Dispose()

# hands + heart: two open hands (outlines) holding up a filled heart
$c = New-Canvas 256; $bmp = $c[0]; $g = $c[1]; $pen = New-Pen 13
foreach ($s in @(-1, 1)) {
	# one open hand, palm up and in: wrist, outer edge up to the fingertips,
	# inner edge down to the thumb, the thumb up, back to the wrist
	$pts = @(
		@(66, 244), @(66, 206), @(30, 150), @(24, 112), @(40, 104), @(54, 118), @(84, 168), @(96, 146), @(112, 152), @(108, 206), @(108, 244))
	$pf = foreach ($p in $pts) { New-Object System.Drawing.PointF ($(if ($s -lt 0) { $p[0] } else { 256 - $p[0] })), $p[1] }
	$g.DrawLines($pen, [System.Drawing.PointF[]]$pf)
}
# the heart: two round lobes and a point, above the thumbs
$g.FillEllipse($white, 80, 30, 54, 54)
$g.FillEllipse($white, 122, 30, 54, 54)
$g.FillPolygon($white, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 83, 68), (New-Object System.Drawing.PointF 173, 68), (New-Object System.Drawing.PointF 128, 126)))
$g.Dispose(); $bmp.Save((Join-Path $Out "icon_give.png")); $bmp.Dispose()

# coin: gold disc, darker rim and edge, a ring, the ₩ sign
$c = New-Canvas 256; $bmp = $c[0]; $g = $c[1]
$edge = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 230, 150, 20))
$face = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 205, 60))
$inner = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 220, 100))
$ringPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 238, 168, 30)), 7
$g.FillEllipse($edge, 14, 20, 228, 228)
$g.FillEllipse($face, 14, 10, 228, 228)
$g.FillEllipse($inner, 40, 36, 176, 176)
$g.DrawEllipse($ringPen, 40, 36, 176, 176)
$font = New-Object System.Drawing.Font("Arial", 136, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
$shade = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 226, 140, 10))
$g.DrawString([string][char]0x20A9, $font, $shade, (New-Object System.Drawing.RectangleF 4, 8, 256, 256), $fmt)
$g.DrawString([string][char]0x20A9, $font, $face, (New-Object System.Drawing.RectangleF 0, 4, 256, 256), $fmt)
$g.Dispose(); $bmp.Save((Join-Path $Out "icon_coin.png")); $bmp.Dispose()
"done"
