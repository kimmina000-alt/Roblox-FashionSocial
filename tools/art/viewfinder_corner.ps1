# Photo booth viewfinder corner (D-329, 2026-10-26): one white rounded L
# bracket on a transparent 128 x 128 image (top-left corner; the game turns it
# for the other three). Writes docs/04_ART/textures/viewfinder_corner.png.
param([string]$copyTo = '')
Add-Type -AssemblyName System.Drawing
$root = Split-Path (Split-Path $PSScriptRoot)
$file = Join-Path $root 'docs\04_ART\textures\viewfinder_corner.png'
$bmp = New-Object System.Drawing.Bitmap 128, 128
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 9
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddLine(6, 122, 6, 40)
$path.AddArc(6, 6, 68, 68, 180, 90)
$path.AddLine(40, 6, 122, 6)
$g.DrawPath($pen, $path)
$g.Dispose()
$bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
if ($copyTo) { Copy-Item $file $copyTo }
"done"
