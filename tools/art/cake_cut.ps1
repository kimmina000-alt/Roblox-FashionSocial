# Cut a cake STL into six slices for the game (D-781): .\tools\art\cake_cut.ps1 -Kind tiramisu -Width 3.0
# Kinds: tiramisu, basque, strawberry (CakeKinds.cs). Writes docs/04_ART/models/<Name>Sliced.gltf + a preview.
param([string]$Kind, [double]$Width, [int]$Target = 20000)
$sp = $env:TEMP
. "$PSScriptRoot\cake_load.ps1"
$repo = 'D:\Roblox\Roblox-FashionSocial'
$stl = "$repo\docs\04_ART\models\source\${Kind}_cake_meshy.stl"
$m = [StlTool]::Load($stl)
$span = [Math]::Max($m.Max[0] - $m.Min[0], $m.Max[1] - $m.Min[1])
$scale = $Width / $span
[CakeCut]::Use($Kind)
$cache = "$sp\$Kind.cache"
$t0 = Get-Date
[CakeCut]::ReduceAndCache($stl, $cache, $Target)
"reduce {0:F0}s" -f ((Get-Date) - $t0).TotalSeconds
$best = [CakeCut]::BestStart($cache, 6)
"best start $best"
$start = [double]($best.Split(' ')[0])
$names = @{ tiramisu = 'TiramisuCakeSliced'; basque = 'BasqueCheesecakeSliced'; strawberry = 'StrawberryCreamCakeSliced' }
$gltf = "$repo\docs\04_ART\models\$($names[$Kind]).gltf"
[CakeCut]::Cut($cache, $gltf, 6, $start, $scale, 0.5, "$repo\docs\04_ART\textures\cakes\${Kind}_sliced_preview.png")
"scale $scale  gltf $((Get-Item $gltf).Length) bytes"
