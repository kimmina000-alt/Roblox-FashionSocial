# Fake-building pictures without real brands (D-744, user 2026-11-02: before
# the launch, real shop names → made-up ones). Reads docs/04_ART/facades/<name>.png,
# writes <name>_nobrand.png next to it. Each patch: a box painted in the sign's
# own colour (sampled at a corner of the box) and a made-up name drawn on it.
#   powershell -ExecutionPolicy Bypass -File tools\art\debrand_facades.ps1
Add-Type -AssemblyName System.Drawing
$dir = (Resolve-Path "docs\04_ART\facades").Path

function C([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

# a patch = @(x, y, w, h, text, textColour, fontSize, fill?) ; fill $null = sample the box's top-left pixel
$jobs = @{
	"facade_4_user" = @(
		@(150, 700, 245, 60, "OHU SHOES", (C 214 30 40), 34, $null),           # ABC-MART on the white band
		@(397, 600, 243, 62, "SNEAKERS · BOOTS", (C 255 255 255), 22, (C 214 30 40)), # brand logos (red band)
		@(397, 662, 243, 45, "OHU SHOES", (C 214 30 40), 24, (C 25 28 36))     # ABC-MART + logos (black band)
	)
	"facade_7_user" = @(
		@(262, 322, 228, 140, "OHU HAIR", (C 55 60 68), 46, $null),            # JUNO HAIR letters on the glass
		@(280, 466, 236, 48, "OHU SHOES", (C 214 30 40), 34, $null)            # ABC-MART
	)
	"facade_2_user" = @(
		@(8, 232, 180, 42, "VR GAME", (C 255 255 255), 26, $null), @(0, 0, 0, 0, "", $null, 0, $null) # PLAYSTATION
	)
	"facade_9" = @(
		@(355, 478, 266, 72, "OHU CHICKEN", (C 255 205 40), 34, $null),        # bhc CHICKEN · B(EER)
		@(205, 492, 140, 52, "", $null, 0, $null),                              # "Korean-style Chicken & Beer" mark
		@(60, 660, 80, 34, "", $null, 0, $null), @(268, 660, 80, 34, "", $null, 0, $null), @(530, 660, 80, 34, "", $null, 0, $null), # bhc on the glass rail
		@(395, 752, 226, 90, "오후설", (C 245 245 245), 44, $null)             # 신선(설농탕), a real chain
	)
	"facade_10" = @(
		@(0, 498, 310, 52, "· SODA · PLATE", (C 255 205 40), 28, $null),       # BEER · PLATE 세계맥주 셀프존 (no alcohol)
		@(95, 660, 80, 34, "", $null, 0, $null), @(272, 660, 80, 34, "", $null, 0, $null), @(462, 660, 80, 34, "", $null, 0, $null),
		@(0, 752, 300, 90, "렁탕", (C 245 245 245), 44, $null)                  # 선설농탕®
	)
	"facade_11" = @(
		@(0, 660, 80, 34, "", $null, 0, $null), @(258, 660, 80, 34, "", $null, 0, $null), @(448, 660, 80, 34, "", $null, 0, $null)
	)
}

foreach ($name in $jobs.Keys) {
	$src = [System.Drawing.Image]::FromFile("$dir\$name.png")
	$bmp = New-Object System.Drawing.Bitmap $src
	$src.Dispose()
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
	foreach ($p in $jobs[$name]) { if ($p[2] -le 0) { continue }
		$x, $y, $w, $h, $text, $ink, $size, $fill = $p
		if ($null -eq $fill) { $fill = $bmp.GetPixel([Math]::Max($x, 0) + 2, $y + 2) }
		$g.FillRectangle((New-Object System.Drawing.SolidBrush $fill), $x, $y, $w, $h)
		if ($size -gt 0 -and $text -ne "") {
			$font = New-Object System.Drawing.Font "Noto Sans KR Black", $size, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
			$fmt = New-Object System.Drawing.StringFormat
			$fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
			$g.DrawString($text, $font, (New-Object System.Drawing.SolidBrush $ink), (New-Object System.Drawing.RectangleF $x, $y, $w, $h), $fmt)
			$font.Dispose()
		}
	}
	$g.Dispose()
	$bmp.Save("$dir\${name}_nobrand.png", [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
	"saved ${name}_nobrand.png"
}
