param([string]$Dir = (Join-Path $PSScriptRoot 'serve'))
# Serves files from $Dir on http://localhost:8765/ so Studio (Edit mode,
# HttpEnabled on) can GetAsync them: see CLAUDE.md 'Sync without Rojo'.
New-Item -ItemType Directory -Force $Dir | Out-Null
$dir = $Dir
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:8765/')
$listener.Start()
$deadline = (Get-Date).AddHours(6)
while ((Get-Date) -lt $deadline) {
  try {
    $ctx = $listener.GetContext()
    $name = [IO.Path]::GetFileName($ctx.Request.Url.AbsolutePath)
    $path = Join-Path $dir $name
    if ($ctx.Request.HttpMethod -eq 'POST') {
      $ms = New-Object IO.MemoryStream; $ctx.Request.InputStream.CopyTo($ms)
      [IO.File]::WriteAllBytes((Join-Path $dir ('up_' + $name)), $ms.ToArray())
      $bytes = [Text.Encoding]::UTF8.GetBytes('saved'); $ctx.Response.StatusCode = 200
    } elseif (Test-Path $path) { $bytes = [IO.File]::ReadAllBytes($path); $ctx.Response.StatusCode = 200 } else { $bytes = [Text.Encoding]::UTF8.GetBytes('missing'); $ctx.Response.StatusCode = 404 }
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
  } catch { Start-Sleep -Milliseconds 200 }
}
$listener.Stop()
