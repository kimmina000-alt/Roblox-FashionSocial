# Renders the icons in dashboard_icons.html to 512x512 PNGs with headless Chrome.
#   dashboard icons (product keys)  -> docs\04_ART\dashboard_icons
#   -Menu: shop menu pictures (menu_* keys, transparent) -> docs\04_ART\menu_icons
# Usage: powershell -ExecutionPolicy Bypass -File tools\art\icons\render_icons.ps1 [-Menu] [-Only Key1,Key2] [-Out dir]
param([string[]]$Only = @(), [string]$Out = "", [switch]$Menu)
$chrome = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$html = (Resolve-Path "$PSScriptRoot\dashboard_icons.html").Path -replace '\\', '/'
if (-not $Out) { $Out = if ($Menu) { "docs\04_ART\menu_icons" } else { "docs\04_ART\dashboard_icons" } }
New-Item -ItemType Directory -Force $Out | Out-Null
$outDir = (Resolve-Path $Out).Path
$profileDir = Join-Path $env:TEMP "icon_chrome_profile"
# the keys, in the page's order
$pattern = if ($Menu) { '^\s+(menu_\w+):\(\)=>' } else { '^\s+(\w+):D\(' }
$keys = Select-String -Path "$PSScriptRoot\dashboard_icons.html" -Pattern $pattern | ForEach-Object { $_.Matches[0].Groups[1].Value }
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Only.Count -gt 0) { $keys = $keys | Where-Object { $Only -contains $_ } }
foreach ($k in $keys) {
	$png = Join-Path $outDir "$k.png"
	$args = @("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=512,512", "--virtual-time-budget=500", "--screenshot=$png", "--user-data-dir=$profileDir")
	if ($Menu) { $args += "--default-background-color=00000000" }
	$p = Start-Process -FilePath $chrome -ArgumentList ($args + "file:///$html#$k") -PassThru -Wait -WindowStyle Hidden
	"$k $($p.ExitCode)"
}
