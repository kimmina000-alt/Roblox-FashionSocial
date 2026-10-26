# Draws the cake atlases for docs/04_ART/models/cake_slice.obj (1024 px):
#   top   = circle centre (256,256) r 256 (the slice shows the wedge pointing right, -30..30 deg)
#   side  = x 512..1024, y 0..512 (y 0 = top edge of the cake)
#   cut   = x 0..512 (centre -> rim), y 512..1024 (y 512 = top, 1024 = bottom)
#   bottom= x 512..1024, y 512..1024
Add-Type -AssemblyName System.Drawing
$out = 'D:\Roblox\Roblox-FashionSocial\docs\04_ART\textures'
function C($r,$g,$b,$a=255){ [System.Drawing.Color]::FromArgb($a,$r,$g,$b) }
function Brush($c){ New-Object System.Drawing.SolidBrush $c }
function Pen($c,$w){ $p=New-Object System.Drawing.Pen $c,$w; $p.StartCap='Round'; $p.EndCap='Round'; $p }
$rnd = New-Object System.Random 11

function Sprinkles($g,$x0,$y0,$x1,$y1,$n){
  $cols=@((C 255 90 120),(C 255 210 60),(C 90 190 255),(C 120 220 120),(C 255 255 255),(C 200 120 255))
  for($i=0;$i -lt $n;$i++){ $x=$rnd.Next($x0,$x1); $y=$rnd.Next($y0,$y1); $p=Pen $cols[$rnd.Next(0,$cols.Count)] 4
    $a=$rnd.NextDouble()*6.28; $g.DrawLine($p,$x,$y,$x+[math]::Cos($a)*7,$y+[math]::Sin($a)*7); $p.Dispose() } }

function Layers($g,$list){ # list of @(height fraction, color) from top to bottom in the cut region
  $y=512.0; foreach($l in $list){ $h=512*$l[0]; $b=Brush $l[1]; $g.FillRectangle($b,0,$y,512,$h+1); $b.Dispose(); $y+=$h } }

function Cake($name,[scriptblock]$draw){
  $bmp=New-Object System.Drawing.Bitmap 1024,1024; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAlias'
  & $draw $g
  $g.Dispose(); $bmp.Save("$out\cake_$name.png",[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose() }

# --- vintage lettering cake, one colour set ---------------------------------
function Vintage($name,$base,$frost,$accent){
  Cake $name {
    param($g)
    $sponge=C 246 214 140; $cream=C 252 250 244
    $g.Clear($base)
    # top: base colour, a ring of piped cream along the rim, sprinkles, a little heart in the slice
    $b=Brush $base; $g.FillEllipse($b,0,0,512,512); $b.Dispose()
    $rp=Pen $frost 34; $g.DrawEllipse($rp,22,22,468,468); $rp.Dispose()
    for($k=0;$k -lt 36;$k++){ $a=$k*10*[math]::PI/180; $x=256+232*[math]::Cos($a); $y=256+232*[math]::Sin($a); $b=Brush $frost; $g.FillEllipse($b,$x-22,$y-22,44,44); $b.Dispose(); $b=Brush (C 255 255 255 120); $g.FillEllipse($b,$x-12,$y-16,14,10); $b.Dispose() }
    Sprinkles $g 300 170 470 340 60
    $hp=Brush $accent; $g.FillEllipse($hp,340,236,22,22); $g.FillEllipse($hp,358,236,22,22); $g.FillPolygon($hp,[System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 342,250),(New-Object System.Drawing.PointF 378,250),(New-Object System.Drawing.PointF 360,272))); $hp.Dispose()
    # side: base colour, cream drips from the top, little stars, a piped border at the bottom
    $b=Brush $base; $g.FillRectangle($b,512,0,512,512); $b.Dispose()
    $cb=Brush $frost; $g.FillRectangle($cb,512,0,512,70)
    for($x=512;$x -lt 1024;$x+=34){ $len=$rnd.Next(60,170); $g.FillRectangle($cb,$x+6,40,20,$len); $g.FillEllipse($cb,$x+6,30+$len,20,22) }
    for($x=512;$x -lt 1040;$x+=40){ $g.FillEllipse($cb,$x-6,452,52,60) }
    $cb.Dispose()
    for($k=0;$k -lt 5;$k++){ $x=560+$k*96; $sb=Brush $accent; $g.FillEllipse($sb,$x,300,30,30); $sb.Dispose() }
    # cut: frosting / sponge / cream / sponge / cream / sponge / frosting
    Layers $g @(@(0.08,$frost),@(0.2,$sponge),@(0.1,$cream),@(0.2,$sponge),@(0.1,$accent),@(0.24,$sponge),@(0.08,$base))
    # bottom
    $b=Brush (C 240 230 210); $g.FillRectangle($b,512,512,512,512); $b.Dispose()
  } }

Vintage 'vintage_pink'  (C 245 170 185) (C 252 248 240) (C 120 200 235)
Vintage 'vintage_sky'   (C 135 200 240) (C 252 248 240) (C 250 210 90)
Vintage 'vintage_teal'  (C 60 150 140)  (C 252 248 240) (C 230 70 80)
Vintage 'vintage_blue'  (C 245 175 185) (C 80 140 230)  (C 250 215 90)

# --- strawberry cream cake ----------------------------------------------------
Cake 'strawberry' {
  param($g)
  $white=C 252 250 246; $sponge=C 246 214 140; $berry=C 220 40 60
  $g.Clear($white)
  $rp=Pen (C 240 236 228) 30; $g.DrawEllipse($rp,24,24,464,464); $rp.Dispose()
  for($k=0;$k -lt 30;$k++){ $a=$k*12*[math]::PI/180; $x=256+232*[math]::Cos($a); $y=256+232*[math]::Sin($a); $b=Brush (C 245 242 235); $g.FillEllipse($b,$x-18,$y-18,36,36); $b.Dispose() }
  # side: smooth white cream with a strawberry-slice ring near the bottom
  for($x=520;$x -lt 1024;$x+=56){ $b=Brush $berry; $g.FillEllipse($b,$x,380,40,30); $b.Dispose() }
  Layers $g @(@(0.1,$white),@(0.22,$sponge),@(0.06,$white),@(0.06,$berry),@(0.06,$white),@(0.22,$sponge),@(0.08,$white),@(0.2,$sponge))
  # strawberry halves in the cream layer
  for($x=40;$x -lt 512;$x+=90){ $b=Brush $berry; $g.FillEllipse($b,$x,700,46,34); $b.Dispose() }
}

# --- tiramisu -------------------------------------------------------------------
Cake 'tiramisu' {
  param($g)
  $cocoa=C 110 70 45; $masc=C 245 232 205; $finger=C 170 115 70
  $g.Clear($cocoa)
  for($i=0;$i -lt 9000;$i++){ $c=$rnd.Next(70,140); $b=Brush (C $c ([int]($c*0.62)) ([int]($c*0.4)) 160); $g.FillRectangle($b,$rnd.Next(0,512),$rnd.Next(0,512),3,3); $b.Dispose() }
  # side and cut: alternating mascarpone and coffee-soaked ladyfingers
  foreach($r in @(@(512,0,512,512),@(0,512,512,512))){ }
  $bands=@(@(0.12,$cocoa),@(0.2,$masc),@(0.16,$finger),@(0.2,$masc),@(0.16,$finger),@(0.16,$masc))
  $y=0.0; foreach($l in $bands){ $h=512*$l[0]; $b=Brush $l[1]; $g.FillRectangle($b,512,$y,512,$h+1); $b.Dispose(); $y+=$h }
  Layers $g $bands
}

# --- basque cheesecake ---------------------------------------------------------
Cake 'basque' {
  param($g)
  $burnt=C 70 40 20; $caramel=C 160 95 40; $inside=C 245 220 160
  $g.Clear($burnt)
  for($i=0;$i -lt 300;$i++){ $c=$rnd.Next(40,120); $b=Brush (C $c ([int]($c*0.6)) ([int]($c*0.3)) 120); $s=$rnd.Next(10,50); $g.FillEllipse($b,$rnd.Next(0,512),$rnd.Next(0,512),$s,$s); $b.Dispose() }
  # side: deep caramel with darker burnt patches near the top
  $b=Brush $caramel; $g.FillRectangle($b,512,0,512,512); $b.Dispose()
  for($i=0;$i -lt 120;$i++){ $c=$rnd.Next(50,110); $b=Brush (C $c ([int]($c*0.6)) ([int]($c*0.3)) 150); $s=$rnd.Next(20,70); $g.FillEllipse($b,$rnd.Next(512,1024),$rnd.Next(0,200),$s,$s); $b.Dispose() }
  # cut: a thin dark crust, then creamy custard
  Layers $g @(@(0.06,$burnt),@(0.86,$inside),@(0.08,$caramel))
}
"done"

# (the atlases are right as drawn; the imported slice mesh is mirrored in X, see SnackService cakeSlice)
