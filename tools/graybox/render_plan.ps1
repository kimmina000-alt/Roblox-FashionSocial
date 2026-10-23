param([string]$Name, [string]$Title, [int]$Width = 1600, [string]$Out, [string]$Extra = '')
Add-Type -AssemblyName System.Drawing
$dir = 'C:\Users\ma912\AppData\Local\Temp\claude\D--Roblox-Roblox-FashionSocial\07d430b0-67f6-4420-8c67-520056ed5aeb\scratchpad'
$data = Get-Content -Raw -Encoding UTF8 "$dir\up_plan_$Name.json" | ConvertFrom-Json
$x0, $z0, $x1, $z1 = $data.box
$s = $Width / ($x1 - $x0)
$H = [int](($z1 - $z0) * $s)
$top = 70
$bmp = New-Object Drawing.Bitmap $Width, ($H + $top + 30)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([Drawing.Color]::FromArgb(236, 238, 232))
function P($x, $z) { New-Object Drawing.PointF ([float](($x - $x0) * $s)), ([float](($z - $z0) * $s + $top)) }
$parts = $data.parts | Where-Object { $_.n -ne 'Terrain' } | Sort-Object { [double]$_.t }
foreach ($p in $parts) {
  $pts = @((P $p.p[0] $p.p[1]), (P $p.p[2] $p.p[3]), (P $p.p[4] $p.p[5]), (P $p.p[6] $p.p[7]))
  $a = if ($p.g -eq 1) { 110 } else { 255 }
  $br = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($a, $p.c[0], $p.c[1], $p.c[2]))
  $g.FillPolygon($br, $pts); $br.Dispose()
  $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(70, 0, 0, 0)), 1
  $g.DrawPolygon($pen, $pts); $pen.Dispose()
}
$font = New-Object Drawing.Font 'Malgun Gothic', 11, ([Drawing.FontStyle]::Bold)
function Label($x, $z, $text, $big) {
  $f = if ($big) { New-Object Drawing.Font 'Malgun Gothic', 14, ([Drawing.FontStyle]::Bold) } else { $font }
  $pt = P $x $z
  $sz = $g.MeasureString($text, $f)
  $rect = New-Object Drawing.RectangleF ($pt.X - $sz.Width / 2 - 4), ($pt.Y - $sz.Height / 2 - 2), ($sz.Width + 8), ($sz.Height + 4)
  $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(215, 25, 28, 36))), $rect)
  $g.DrawString($text, $f, [Drawing.Brushes]::White, ($rect.X + 4), ($rect.Y + 2))
}
foreach ($l in $data.labels) { $t = ($l.s -replace '<[^>]+>', '') -replace "`n", ' '; if ($t.Length -gt 0) { Label $l.x $l.z $t $false } }
if ($Extra -ne '') { foreach ($e in (Get-Content -Raw -Encoding UTF8 $Extra | ConvertFrom-Json)) { Label $e.x $e.z $e.s $true } }
# title, north arrow, scale bar
$g.FillRectangle([Drawing.Brushes]::White, 0, 0, $Width, $top - 6)
$g.DrawString($Title, (New-Object Drawing.Font 'Malgun Gothic', 20, ([Drawing.FontStyle]::Bold)), [Drawing.Brushes]::Black, 14, 12)
$g.DrawString('↑ 북 (화면 위 = -Z)', (New-Object Drawing.Font 'Malgun Gothic', 12), [Drawing.Brushes]::DimGray, ($Width - 420), 22)
$len = [Math]::Pow(10, [Math]::Floor([Math]::Log10(($x1 - $x0) / 5)))
$bx = $Width - 200; $by = $top + $H + 12
$g.FillRectangle([Drawing.Brushes]::Black, $bx, $by, [float]($len * $s), 6)
$g.DrawString(("{0} 스터드 (≈{1} m)" -f $len, [Math]::Round($len * 0.34)), (New-Object Drawing.Font 'Malgun Gothic', 10), [Drawing.Brushes]::Black, ($bx - 170), ($by - 6))
$bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
"saved $Out"
