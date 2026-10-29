# Writes zone_run.lua = graybox prelude + the requested zone blocks, for
# loadstring in Studio. A zone block starts at the last top-level "do" line
# before its `local z=zone("NAME")` line and ends where the next zone block
# starts (or before `return "graybox built"`).
param([string[]]$Zones)
$u = New-Object Text.UTF8Encoding $false
$src = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\graybox\build_main_social_graybox.lua'), $u) -replace "`r`n", "`n"
$l = $src -split "`n"
$zoneLines = @(); $names = @()
for ($i = 0; $i -lt $l.Count; $i++) { if ($l[$i] -match '^local z=zone\("([^"]+)"\)') { $zoneLines += $i; $names += $Matches[1] } }
$starts = @()
foreach ($zi in $zoneLines) { $j = $zi; while ($j -gt 0 -and $l[$j] -notmatch '^do') { $j-- }; $starts += $j }
$rootLine = ($l | Select-String -Pattern '^local root=' | Select-Object -First 1).LineNumber - 1
$prelude = $l[$rootLine..($starts[0] - 1)] -join "`n"
$retLine = ($l | Select-String -Pattern '^return "graybox built"').LineNumber - 1
$out = @($prelude)
for ($k = 0; $k -lt $starts.Count; $k++) {
  $s = $starts[$k]; $e = if ($k + 1 -lt $starts.Count) { $starts[$k + 1] - 1 } else { $retLine - 1 }
  if ($Zones -contains $names[$k]) { $out += ($l[$s..$e] -join "`n") }
}
if ($Zones -contains '04_Beach_Aquarium') {
  $park = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\graybox\park_beach_hidden.lua'), $u) -replace "`r`n", "`n"
  $out += "local parkMsg = (function()`n$park`nend)()"
}
$out += 'return "ok " .. #root:GetDescendants()'
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'serve\zone_run.lua'), ($out -join "`n"), $u)
"blocks: " + ($out.Count - 2) + " of " + ($names -join ",")
