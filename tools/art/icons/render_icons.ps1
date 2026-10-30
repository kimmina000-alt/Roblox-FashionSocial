# Renders every icon in dashboard_icons.html to a 512x512 PNG with headless Chrome.
# Usage: powershell -ExecutionPolicy Bypass -File tools\art\icons\render_icons.ps1 [-Only Key1,Key2] [-Out docs\04_ART\dashboard_icons]
param([string[]]$Only = @(), [string]$Out = "docs\04_ART\dashboard_icons")
$chrome = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$html = (Resolve-Path "$PSScriptRoot\dashboard_icons.html").Path -replace '\\', '/'
New-Item -ItemType Directory -Force $Out | Out-Null
$outDir = (Resolve-Path $Out).Path
$profileDir = Join-Path $env:TEMP "icon_chrome_profile"
# the keys, in the page's order (the page lists them when there is no hash)
$keys = Select-String -Path "$PSScriptRoot\dashboard_icons.html" -Pattern '^\s+(\w+):D\(' | ForEach-Object { $_.Matches[0].Groups[1].Value }
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Only.Count -gt 0) { $keys = $keys | Where-Object { $Only -contains $_ } }
foreach ($k in $keys) {
	$png = Join-Path $outDir "$k.png"
	$p = Start-Process -FilePath $chrome -ArgumentList "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=512,512", "--virtual-time-budget=500", "--screenshot=$png", "--user-data-dir=$profileDir", "file:///$html#$k" -PassThru -Wait -WindowStyle Hidden
	"$k $($p.ExitCode)"
}
