# Beach signs after the user's 광안리 photo (2026-10-26): the guide map board
# and the surfboard rules board. Writes docs/04_ART/textures/beach_map_board.png
# and beach_rules_board.png.
Add-Type -AssemblyName System.Drawing
$out = 'D:\Roblox\Roblox-FashionSocial\docs\04_ART\textures'
function C($r,$g,$b,$a=255){ [System.Drawing.Color]::FromArgb($a,$r,$g,$b) }
function B($c){ New-Object System.Drawing.SolidBrush $c }
function P($c,$w){ $p=New-Object System.Drawing.Pen $c,$w; $p.StartCap='Round'; $p.EndCap='Round'; $p.LineJoin='Round'; $p }
function F($size,$bold=$true){ New-Object System.Drawing.Font 'Malgun Gothic',$size,($(if($bold){[System.Drawing.FontStyle]::Bold}else{[System.Drawing.FontStyle]::Regular})),([System.Drawing.GraphicsUnit]::Pixel) }
$BROWN = C 92 52 40; $CREAM = C 250 246 236; $WHITE = C 255 255 255; $ORANGE = C 214 130 70
function Txt($g,$s,$font,$color,$x,$y,$w,$h,$align='Near'){
  $sf=New-Object System.Drawing.StringFormat; $sf.Alignment=$align; $sf.LineAlignment='Near'
  $b=B $color; $g.DrawString($s,$font,$b,(New-Object System.Drawing.RectangleF $x,$y,$w,$h),$sf); $b.Dispose() }

# ---------------------------------------------------------------- map board
$W=1612; $H=1200
$bmp=New-Object System.Drawing.Bitmap $W,$H; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
$g.Clear($BROWN)
# the white map panel
$g.FillRectangle((B $CREAM),40,30,$W-80,680)
Txt $g '2026년 오후 해변 종합안내도' (F 52) (C 40 30 30) 40 46 ($W-80) 70 'Center'
# map (user 2026-10-26: the real layout, simplified): drawn from the world
# coordinates like the Studio top view (north = -Z up, the sea on the left);
# X is squeezed less than Z so the beach strip stays readable
$mx=80; $my=130; $mw=$W-160; $mh=560
$WX0=-330; $WX1=140; $WZ0=-260; $WZ1=170   # (PowerShell names ignore case: not $X0, Rect has $x0)
function MX($x){ $mx+($x-$WX0)*$mw/($WX1-$WX0) }
function MZ($z){ $my+($z-$WZ0)*$mh/($WZ1-$WZ0) }
function Rect($c,$x0,$z0,$x1,$z1){ $a=MX $x0; $b=MZ $z0; $g.FillRectangle((B $c),$a,$b,(MX $x1)-$a,(MZ $z1)-$b) }
$g.SetClip((New-Object System.Drawing.RectangleF $mx,$my,$mw,$mh))
$g.FillRectangle((B (C 236 236 232)),$mx,$my,$mw,$mh) # blocks
$ROAD=C 196 196 192
Rect $ROAD -182 $WZ0 -158 $WZ1   # sea road
Rect $ROAD -158 -24 -24 24     # west road
Rect $ROAD -24 $WZ0 24 $WZ1      # north-south road
Rect $ROAD 24 -24 $WX1 24       # east road
Rect (C 168 210 150) -150 -229 -47 -47   # pocket park
Rect (C 210 205 195) -210 $WZ0 -48 -229   # amusement park (closed)
Rect (C 215 200 215) 41 $WZ0 $WX1 -100     # club
Rect (C 220 215 205) 44 -99 115 -43      # 오후네컷
Rect (C 215 220 230) -130 62 -52 104     # OH24
# sea with a soft shoreline, sand, steps and promenade
$shore=MX -266
$sea=New-Object System.Drawing.Drawing2D.GraphicsPath
$sea.AddBezier($shore,$my,$shore-30,$my+180,$shore+20,$my+380,$shore-10,$my+$mh)
$sea.AddLine($shore-10,$my+$mh,$mx,$my+$mh); $sea.AddLine($mx,$my+$mh,$mx,$my); $sea.CloseFigure()
Rect (C 245 220 160) -266 $WZ0 -200 $WZ1
$grad=New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point $mx,0),(New-Object System.Drawing.Point ([int]$shore),0),(C 30 90 200),(C 80 170 235))
$g.FillPath($grad,$sea)
Rect (C 190 120 100) -200 $WZ0 -182 $WZ1   # steps + promenade
Rect (C 244 242 236) -298 -4 -206 106    # beach cafe (over the water on piles)
$g.ResetClip()
# swimming zone buoys
for($i=0;$i -lt 9;$i++){ $y=$my+30+$i*62; $x=$mx+40+[math]::Sin($i/2.0)*10; $g.FillEllipse((B (C 255 140 40)),$x,$y,20,20) }
Txt $g '수영 구역' (F 26) $WHITE ($mx+70) ($my+(MZ -120)-$my) 150 40
# street names
Txt $g '해변로' (F 22) (C 90 90 90) ((MX -182)-6) ((MZ 120)) 90 30
# places (dot + label box)
function Spot($x,$z,$c,$label,$left=$false){ $px=MX $x; $py=MZ $z
  $g.FillEllipse((B $c),$px-13,$py-13,26,26); $g.DrawEllipse((P $WHITE 4),$px-13,$py-13,26,26)
  $f=F 24; $sz=$g.MeasureString($label,$f); $bx=if($left){$px-22-$sz.Width-16}else{$px+20}
  $g.FillRectangle((B (C 30 40 80)),$bx,$py-19,$sz.Width+16,38); Txt $g $label $f $WHITE ($bx+8) ($py-17) ($sz.Width+20) 38 }
Spot -250 50 (C 230 60 60) '해변 카페'
Spot -292 -70 (C 60 170 90) '튜브'
Spot -214 -19 (C 240 180 40) '아이스크림 트럭'
Spot -199 -190 (C 60 130 220) '발 씻는 곳'
Spot -48 -51 (C 140 80 200) '지하철 3번 출구'
Spot -48 44 (C 140 80 200) '지하철 4번 출구'
Spot 80 -70 (C 230 120 160) '오후네컷'
Spot -91 83 (C 120 120 130) 'OH24 편의점'
Spot -98 -140 (C 70 150 80) '포켓 공원'
Spot -129 -245 (C 150 140 120) '놀이공원 (공사 중)'
Spot 90 -200 (C 160 60 170) '클럽'
# you are here (the board itself)
$hx=MX -212; $hz=MZ -152
$g.FillEllipse((B (C 220 30 30)),$hx-17,$hz-17,34,34); $g.DrawEllipse((P $WHITE 5),$hx-17,$hz-17,34,34)
$g.FillRectangle((B (C 220 30 30)),$hx-150,$hz+20,130,38); Txt $g '현재 위치' (F 24) $WHITE ($hx-146) ($hz+22) 130 38
# legend
$lx=MX 50; $ly=$my+$mh-200
$g.FillRectangle((B $WHITE),$lx,$ly,290,190); $g.DrawRectangle((P (C 120 120 120) 3),$lx,$ly,290,190)
Txt $g '범   례' (F 26) (C 40 30 30) $lx ($ly+6) 290 36 'Center'
$items=@(@((C 230 60 60),'카페'),@((C 60 130 220),'샤워·발 씻는 곳'),@((C 140 80 200),'지하철 출구'),@((C 255 140 40),'안전 부표'))
for($i=0;$i -lt 4;$i++){ $g.FillEllipse((B $items[$i][0]),$lx+22,$ly+50+$i*34,20,20); Txt $g $items[$i][1] (F 22 $false) (C 40 30 30) ($lx+52) ($ly+45+$i*34) 230 32 }
# compass
$g.DrawLine((P (C 60 60 60) 5),$mx+$mw-40,$my+100,$mx+$mw-40,$my+30); Txt $g 'N' (F 30) (C 60 60 60) ($mx+$mw-54) ($my-6) 40 40
# ----- lower part: three columns on brown
Txt $g "개장기간`n2026. 7. 1. ~ 8. 31.`n`n개장시간`n10:00 ~ 19:00`n*8월 이후 해가 지는 시간에 따라 운영" (F 30) $CREAM 60 740 460 400
Txt $g '피서객 준수사항' (F 34) $CREAM 560 735 520 50
$rules=@('쓰레기 금지','흡연 금지','폭죽놀이 금지','텐트·취사 금지','배설물 치우기','낚시 금지')
for($i=0;$i -lt 6;$i++){ $col=[math]::Floor($i/3); $row=$i%3; $x=560+$col*270; $y=800+$row*110
  $g.FillEllipse((B $WHITE),$x,$y,80,80); $g.DrawEllipse((P (C 200 40 40) 8),$x+6,$y+6,68,68); $g.DrawLine((P (C 200 40 40) 8),$x+18,$y+18,$x+62,$y+62)
  Txt $g $rules[$i] (F 24) $CREAM ($x+90) ($y+18) 180 70 }
Txt $g "바다 이용 수칙`n· 수영은 안전 부표 안에서만`n· 어린이는 보호자와 함께`n· 쓰레기는 되가져가기`n· 해가 지면 바다 입수 금지" (F 28) $CREAM 1120 740 460 330
Txt $g "문의  해변 안내소  ·  오후 시티" (F 26 $false) (C 230 210 190) 60 1135 1000 50
$g.FillRectangle((B (C 120 70 55)),0,$H-30,$W,30)
$g.Dispose(); $bmp.Save("$out\beach_map_board.png",[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

# ---------------------------------------------------------------- surfboard
$W=420; $H=1080
$bmp=New-Object System.Drawing.Bitmap $W,$H; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
$g.Clear($BROWN)
$g.FillRectangle((B $WHITE),30,40,$W-60,80)
Txt $g '바다 이용 수칙' (F 40) (C 40 30 30) 30 52 ($W-60) 60 'Center'
$lines=@('수영은 안전 부표 안에서만 하기','어린이는 꼭 보호자와 함께 물에 들어가기','튜브는 대여소에서 빌려 쓰기','쓰레기는 되가져가기','해가 지면 바다에 들어가지 않기')
$y=160; foreach($l in $lines){ Txt $g ('* '+$l) (F 32) $CREAM 34 $y ($W-60) 150; $y+=140 }
# the bridge (광안대교 style) line art at the bottom
$pen=P $ORANGE 5
$g.DrawLine($pen,20,980,400,980)
foreach($tx in 130,290){ $g.DrawLine($pen,$tx-14,980,$tx-14,860); $g.DrawLine($pen,$tx+14,980,$tx+14,860); $g.DrawLine($pen,$tx-14,880,$tx+14,880) }
$g.DrawBezier($pen,20,960,70,930,100,880,116,862); $g.DrawBezier($pen,144,862,190,930,230,930,276,862); $g.DrawBezier($pen,304,862,330,890,360,940,400,960)
for($x=40;$x -lt 400;$x+=24){ $yy=980-[math]::Max(0,100-[math]::Abs((($x-20)%160)-80)*1.2); $g.DrawLine((P $ORANGE 2),$x,980,$x,[math]::Max(870,$yy)) }
foreach($sx in 300,340){ Txt $g '✱' (F 36) $ORANGE $sx 780 60 60 }
$g.Dispose(); $bmp.Save("$out\beach_rules_board.png",[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"done"
