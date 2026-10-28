param([string]$Json, [string]$Out, [string]$Colors)
# Reduced food mesh JSON (tools/art/StlTool.cs ExportNamed: {group: {v, f}})
# -> one glTF 2.0 file with a separate mesh + material per group, so the
# Roblox 3D importer keeps the parts apart with their colours (an OBJ came in
# as one merged mesh, user 2026-10-29). Colors: "Name=r,g,b[,a];..." (0..1).
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 100000000
$data = $ser.DeserializeObject([IO.File]::ReadAllText($Json))
$col = @{}
foreach ($c in $Colors.Split(';')) { if ($c) { $kv = $c.Split('='); $col[$kv[0]] = [double[]]($kv[1].Split(',') | ForEach-Object { [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture) }) } }
$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter $ms
$bufferViews = @(); $accessors = @(); $meshes = @(); $materials = @(); $nodes = @()
foreach ($g in $data.Keys) {
  $v = $data[$g]['v']; $f = $data[$g]['f']
  $nv = $v.Count / 3
  $pos = New-Object 'double[]' ($v.Count)
  for ($i = 0; $i -lt $v.Count; $i++) { $pos[$i] = [double]$v[$i] }
  # smooth normals: face normals added up at each corner
  $nrm = New-Object 'double[]' ($v.Count)
  for ($k = 0; $k -lt $f.Count; $k += 3) {
    $a = [int]$f[$k] * 3; $b = [int]$f[$k + 1] * 3; $c = [int]$f[$k + 2] * 3
    $ux = $pos[$b] - $pos[$a]; $uy = $pos[$b + 1] - $pos[$a + 1]; $uz = $pos[$b + 2] - $pos[$a + 2]
    $wx = $pos[$c] - $pos[$a]; $wy = $pos[$c + 1] - $pos[$a + 1]; $wz = $pos[$c + 2] - $pos[$a + 2]
    $nx = $uy * $wz - $uz * $wy; $ny = $uz * $wx - $ux * $wz; $nz = $ux * $wy - $uy * $wx
    foreach ($o in $a, $b, $c) { $nrm[$o] += $nx; $nrm[$o + 1] += $ny; $nrm[$o + 2] += $nz }
  }
  $min = @([double]::MaxValue, [double]::MaxValue, [double]::MaxValue); $max = @([double]::MinValue, [double]::MinValue, [double]::MinValue)
  $start = $ms.Position
  for ($i = 0; $i -lt $nv; $i++) { for ($a = 0; $a -lt 3; $a++) { $x = $pos[$i * 3 + $a]; $bw.Write([single]$x); if ($x -lt $min[$a]) { $min[$a] = $x }; if ($x -gt $max[$a]) { $max[$a] = $x } } }
  $bufferViews += @{ buffer = 0; byteOffset = [int]$start; byteLength = [int]($ms.Position - $start); target = 34962 }
  $accessors += @{ bufferView = $bufferViews.Count - 1; componentType = 5126; count = [int]$nv; type = 'VEC3'; min = $min; max = $max }
  $posAcc = $accessors.Count - 1
  $start = $ms.Position
  for ($i = 0; $i -lt $nv; $i++) {
    $x = $nrm[$i * 3]; $y = $nrm[$i * 3 + 1]; $z = $nrm[$i * 3 + 2]; $l = [Math]::Sqrt($x * $x + $y * $y + $z * $z); if ($l -lt 1e-12) { $l = 1; $y = 1 }
    $bw.Write([single]($x / $l)); $bw.Write([single]($y / $l)); $bw.Write([single]($z / $l))
  }
  $bufferViews += @{ buffer = 0; byteOffset = [int]$start; byteLength = [int]($ms.Position - $start); target = 34962 }
  $accessors += @{ bufferView = $bufferViews.Count - 1; componentType = 5126; count = [int]$nv; type = 'VEC3' }
  $nrmAcc = $accessors.Count - 1
  $start = $ms.Position
  foreach ($x in $f) { $bw.Write([uint32]$x) }
  $bufferViews += @{ buffer = 0; byteOffset = [int]$start; byteLength = [int]($ms.Position - $start); target = 34963 }
  $accessors += @{ bufferView = $bufferViews.Count - 1; componentType = 5125; count = [int]$f.Count; type = 'SCALAR' }
  $idxAcc = $accessors.Count - 1
  $c = if ($col.ContainsKey($g)) { $col[$g] } else { @(1, 1, 1) }
  $alpha = if ($c.Count -gt 3) { $c[3] } else { 1 }
  $mat = @{ name = $g; pbrMetallicRoughness = @{ baseColorFactor = @($c[0], $c[1], $c[2], $alpha); metallicFactor = 0; roughnessFactor = 0.6 } }
  if ($alpha -lt 1) { $mat.alphaMode = 'BLEND' }
  $materials += $mat
  $meshes += @{ name = $g; primitives = @(@{ attributes = @{ POSITION = $posAcc; NORMAL = $nrmAcc }; indices = $idxAcc; material = $materials.Count - 1 }) }
  $nodes += @{ name = $g; mesh = $meshes.Count - 1 }
}
$bw.Flush()
$bytes = $ms.ToArray()
$gltf = @{
  asset = @{ version = '2.0'; generator = 'OHU json_to_gltf.ps1' }
  scene = 0
  scenes = @(@{ nodes = @(0..($nodes.Count - 1)) })
  nodes = $nodes; meshes = $meshes; materials = $materials; accessors = $accessors; bufferViews = $bufferViews
  buffers = @(@{ byteLength = $bytes.Length; uri = 'data:application/octet-stream;base64,' + [Convert]::ToBase64String($bytes) })
}
[IO.File]::WriteAllText($Out, $ser.Serialize($gltf))
"$Out : $($nodes.Count) parts, $([Math]::Round((Get-Item $Out).Length / 1024)) KB"
