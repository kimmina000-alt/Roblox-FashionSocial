param(
  [Parameter(Mandatory = $true)][string]$InputFile,
  [double]$SegLen = 30,
  [double]$Tail = 4,
  [string]$OutDir = '',
  [string]$Title = ''
)
# Cuts one audio file into clips for JoinedSongPlayer (user 2026-11-03):
# clip n = SegLen seconds from (n-1)*SegLen, plus the next clip's first Tail
# seconds, so two clips can cross over and the shared sound lines up.
# Writes into D:\Roblox\음원\<Title> (or -OutDir):
# 1.mp3, 2.mp3, … (upload them in this order), 구간표.txt, and
# song.lua: the line to paste into a song list, with the ids left as 0.
# Only for audio you have the rights to.
$ErrorActionPreference = 'Stop'
$ffmpeg = (Get-Command ffmpeg).Source
$ffprobe = Join-Path (Split-Path $ffmpeg) 'ffprobe.exe'
if (-not (Test-Path -LiteralPath $InputFile)) { throw "no file: $InputFile" }
$name = [IO.Path]::GetFileNameWithoutExtension($InputFile)
if ($Title -eq '') { $Title = $name }
# (user 2026-11-03) one folder per song under D:\Roblox\음원
if ($OutDir -eq '') { $OutDir = Join-Path 'D:\Roblox\음원' $Title }
New-Item -ItemType Directory -Force $OutDir | Out-Null

$total = [double](& $ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $InputFile)
# (2026-11-03) splitting is only for audio longer than Roblox's upload limit
# (7 minutes); a shorter file is uploaded whole. Cutting a short song into
# clips would only hide it from Roblox's copyright check.
if ($total -le 420) { throw ("{0:N1} s is under the 7-minute upload limit: upload the file as it is, no split" -f $total) }
$inv = [Globalization.CultureInfo]::InvariantCulture
$table = @()
$i = 1
for ($s = 0.0; $s -lt $total - 0.05; $s += $SegLen) {
  $d = [Math]::Min($SegLen + $Tail, $total - $s)
  $out = Join-Path $OutDir "$i.mp3"
  & $ffmpeg -hide_banner -loglevel error -y -ss $s.ToString($inv) -t $d.ToString($inv) -i $InputFile -c:a libmp3lame -b:a 192k $out
  $table += ('{0}.mp3  {1}~{2}초 (본 구간 {1}~{3}초 + 뒤 {4}초 겹침용)' -f $i, $s, [Math]::Round($s + $d, 2), [Math]::Round([Math]::Min($s + $SegLen, $total), 2), [Math]::Round([Math]::Max(0, $d - $SegLen), 2))
  $i++
}
$count = $i - 1
$table += ''
$table += ('원본 {0}초, 구간 {1}개, 구간 길이 {2}초, 꼬리 {3}초' -f [Math]::Round($total, 2), $count, $SegLen, $Tail)
$table | Out-File -Encoding utf8 (Join-Path $OutDir '구간표.txt')

$ids = (1..$count | ForEach-Object { "0 --[[$_]]" }) -join ', '
$line = '{{ title = "{0}", joined = {{ parts = {{ {1} }}, segLen = {2}, tail = {3}, total = {4} }} }},' -f $Title, $ids, $SegLen.ToString($inv), $Tail.ToString($inv), [Math]::Round($total, 2).ToString($inv)
$line | Out-File -Encoding utf8 (Join-Path $OutDir 'song.lua')
Write-Output "clips: $count  total: $([Math]::Round($total, 2)) s  -> $OutDir"
Write-Output $line
