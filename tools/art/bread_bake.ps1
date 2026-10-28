param([string]$In, [string]$Out, [double]$CreaseLo = 0.55, [double]$CreaseHi = 0.75, [switch]$Debug)
# Salt bread skin baked from the mesh (D-454): the Studio pass wrote, per
# 512x512 UV texel, height / concavity / position along the length / normal up.
# Crust colour by height, pale torn crumb in the creases (concave), salt only
# on the top middle.
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging;
public static class BreadBake4 {
  static byte[] Hex(string s){ var b=new byte[s.Length/2]; for(int i=0;i<b.Length;i++) b[i]=Convert.ToByte(s.Substring(i*2,2),16); return b; }
  public static byte[] Load(string[] files){ var all=new System.Collections.Generic.List<byte>(); foreach(var f in files) all.AddRange(Hex(System.IO.File.ReadAllText(f).Trim())); return all.ToArray(); }
  static double Noise(int x,int y,int seed){ uint h=(uint)(x*374761393+y*668265263+seed*1442695041); h=(h^(h>>13))*1274126177; return ((h^(h>>16))&0xffff)/65535.0; }
  static double Smooth(double x,double y,double s,int seed){ int xi=(int)Math.Floor(x/s), yi=(int)Math.Floor(y/s); double fx=x/s-xi, fy=y/s-yi; fx=fx*fx*(3-2*fx); fy=fy*fy*(3-2*fy);
    double a=Noise(xi,yi,seed),b=Noise(xi+1,yi,seed),c=Noise(xi,yi+1,seed),d=Noise(xi+1,yi+1,seed); return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy; }
  static int C(double v){ return Math.Max(0,Math.Min(255,(int)Math.Round(v))); }
  public static void Bake(byte[] d,int N,int M,string colPath,string rouPath,string dbgPath,double lo,double hi){
    // dilate uncovered texels so seams do not show
    var a=(byte[])d.Clone();
    for(int it=0;it<6;it++){ var b=(byte[])a.Clone(); for(int y=0;y<N;y++) for(int x=0;x<N;x++){ int o=(y*N+x)*4; if(a[o]!=0) continue;
      for(int k=0;k<4;k++){ int nx=x+(k==0?1:k==1?-1:0), ny=y+(k==2?1:k==3?-1:0); if(nx<0||ny<0||nx>=N||ny>=N) continue; int p=(ny*N+nx)*4; if(a[p]!=0){ for(int c=0;c<4;c++) b[o+c]=a[p+c]; break; } } } a=b; }
    var col=new Bitmap(M,M,PixelFormat.Format32bppArgb); var rou=new Bitmap(M,M,PixelFormat.Format32bppArgb); var dbg=new Bitmap(N,N,PixelFormat.Format32bppArgb);
    var rnd=new Random(1028);
    // salt crystals: random spots, kept only on the top middle
    var salt=new double[M*M];
    for(int i=0;i<9000;i++){ int sx=rnd.Next(M), sy=rnd.Next(M); int r=1+rnd.Next(3); for(int yy=-r;yy<=r;yy++) for(int xx=-r;xx<=r;xx++){ if(xx*xx+yy*yy>r*r+rnd.Next(2)) continue; int px=sx+xx, py=sy+yy; if(px<0||py<0||px>=M||py>=M) continue; salt[py*M+px]=Math.Max(salt[py*M+px],0.6+0.4*Math.Max(0,1-(xx*xx+yy*yy)/(double)(r*r+1))); } }
    for(int y=0;y<M;y++) for(int x=0;x<M;x++){
      int sx=x*N/M, sy=y*N/M; int o=(sy*N+sx)*4;
      double h=(a[o]-1)/254.0, cv=a[o+1]/255.0, lx=a[o+2]/255.0, up=a[o+3]/255.0;
      double crease=Math.Max(0,Math.Min(1,(cv-lo)/(hi-lo)));
      double n1=Smooth(x,y,40,1), n2=Smooth(x,y,9,2), n3=Noise(x,y,3);
      // crust: deep golden brown on top, lighter golden toward the bottom
      double t=Math.Max(0,Math.Min(1,h*1.15));
      double r0=226-52*t, g0=164-70*t, b0=88-50*t;
      double m=(n1-0.5)*34+(n2-0.5)*18;
      double R=r0+m, G=g0+m*0.8, B=b0+m*0.5;
      // pale stretched crumb in the creases, with fibres along the crease
      double fib=Smooth(x*0.35,y*2.2,3,4);
      double cr=244-18*fib, cg=222-24*fib, cb=176-30*fib;
      double edge=crease*(0.85+0.15*n3);
      R=R*(1-edge)+cr*edge; G=G*(1-edge)+cg*edge; B=B*(1-edge)+cb*edge;
      // butter gloss specks
      double gloss=(n3>0.985)?1:0;
      R+=gloss*30; G+=gloss*24; B+=gloss*14;
      // salt: top (high, facing up), middle of the length, not in a crease
      double top=Math.Max(0,Math.Min(1,(h-0.72)/0.12))*Math.Max(0,Math.Min(1,(up-0.8)/0.12));
      double mid=Math.Max(0,1-Math.Abs(lx-0.5)/0.16);
      double sv=salt[y*M+x]*top*mid*(1-crease)*(Smooth(x,y,26,5)>0.35?1:0);
      R=R*(1-sv)+250*sv; G=G*(1-sv)+248*sv; B=B*(1-sv)+242*sv;
      col.SetPixel(x,y,Color.FromArgb(255,C(R),C(G),C(B)));
      double rough=70*(1-edge)+200*edge; rough=rough*(1-sv)+150*sv;
      rou.SetPixel(x,y,Color.FromArgb(255,C(rough),C(rough),C(rough)));
    }
    for(int y=0;y<N;y++) for(int x=0;x<N;x++){ int o=(y*N+x)*4; dbg.SetPixel(x,y,d[o]==0?Color.Black:Color.FromArgb(255,d[o+1],d[o],d[o+2])); }
    col.Save(colPath); rou.Save(rouPath); dbg.Save(dbgPath);
  }
}
'@
$files = 0..3 | ForEach-Object { Join-Path $In "up_bake$_.hex" }
$d = [BreadBake4]::Load($files)
# concavity thresholds from the spread over the covered texels (a few sharp
# spots set the maximum, so fixed numbers miss the creases)
$h = New-Object int[] 256; $n = 0
for ($i = 0; $i -lt $d.Length; $i += 4) { if ($d[$i] -ne 0) { $h[$d[$i + 1]]++; $n++ } }
function Pct($p) { $acc = 0; for ($v = 0; $v -lt 256; $v++) { $acc += $h[$v]; if ($acc -ge $n * $p / 100) { return $v } } 255 }
if (-not $PSBoundParameters.ContainsKey('CreaseLo')) { $CreaseLo = (Pct 86) / 255.0 }
if (-not $PSBoundParameters.ContainsKey('CreaseHi')) { $CreaseHi = (Pct 97) / 255.0 }
"p50 $(Pct 50) p86 $(Pct 86) p97 $(Pct 97) -> lo $CreaseLo hi $CreaseHi"
[BreadBake4]::Bake($d, 512, 1024, (Join-Path $Out 'saltbread_color.png'), (Join-Path $Out 'saltbread_rough.png'), (Join-Path $Out 'saltbread_debug.png'), $CreaseLo, $CreaseHi)
"baked"
