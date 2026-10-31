# Renders thumbs.html to PNGs with headless Chrome -> docs\04_ART\thumbnails
#   icon = 512x512 game icon; club / cafe / booth = 1920x1080 thumbnails
# Usage: powershell -ExecutionPolicy Bypass -File tools\art\thumbnails\render.ps1 [-Only club,icon]
# -Page thumbs_looks.html renders v2 (marketplace avatars, D-683) as ohu_v2_<key>.png
param([string[]]$Only = @(), [string]$Page = "thumbs.html")
$chrome = @("C:\Program Files\Google\Chrome\Application\chrome.exe", "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$html = (Resolve-Path "$PSScriptRoot\$Page").Path -replace '\\', '/'
$prefix = if ($Page -eq "thumbs.html") { "ohu_" } else { "ohu_v2_" }
$outDir = (Resolve-Path "$PSScriptRoot\..\..\..\docs\04_ART\thumbnails").Path
$profileDir = Join-Path $env:TEMP "thumb_chrome_profile"
$cards = [ordered]@{ icon = "512,512"; club = "1920,1080"; cafe = "1920,1080"; booth = "1920,1080"; bartender = "1920,1080" }
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
foreach ($k in $cards.Keys) {
	if ($Only.Count -gt 0 -and -not ($Only -contains $k)) { continue }
	$png = Join-Path $outDir "$prefix$k.png"
	$args = @("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=$($cards[$k])", "--virtual-time-budget=4000", "--screenshot=$png", "--user-data-dir=$profileDir", "file:///$html#$k")
	$p = Start-Process -FilePath $chrome -ArgumentList $args -PassThru -Wait -WindowStyle Hidden
	"$k $($p.ExitCode)"
}
