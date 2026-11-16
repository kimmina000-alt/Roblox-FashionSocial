import json, struct, sys, math
import numpy as np
from PIL import Image
glb, png = sys.argv[1], sys.argv[2]
d = open(glb,'rb').read(); L = struct.unpack('<I', d[12:16])[0]
j = json.loads(d[20:20+L]); off = 20+L
BL = struct.unpack('<I', d[off:off+4])[0]; buf = d[off+8:off+8+BL]
prim = j['meshes'][0]['primitives'][0]
def acc(i, comps):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    st = bv.get('byteOffset',0)+a.get('byteOffset',0)
    dt = {5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']]
    arr=np.frombuffer(buf,dtype=dt,count=a['count']*comps,offset=st)
    return arr.reshape(-1,comps) if comps>1 else arr
P = acc(prim['attributes']['POSITION'],3).astype(float)
UV = acc(prim['attributes']['TEXCOORD_0'],2).astype(float)
I = acc(prim['indices'],1).astype(int).reshape(-1,3)
img = np.asarray(Image.open(png).convert('RGB')).astype(int); H,W,_ = img.shape
band = (np.abs(img-np.array([189,154,106])).sum(2) < 12)
mn, mx = P.min(0), P.max(0); ctr=(mn+mx)/2
rr = np.hypot(P[:,0]-ctr[0], P[:,2]-ctr[2]); rmax=rr.max()
crown=[t for t in I if rr[t].min() > rmax*0.85]
cov=np.zeros((H,W),bool)
tri_uv=[]
for t in crown:
    a,b,c = UV[t]*np.array([W,H]); tri_uv.append((t,a,b,c))
    x0=int(max(0,math.floor(min(a[0],b[0],c[0])))); x1=int(min(W-1,math.ceil(max(a[0],b[0],c[0]))))
    y0=int(max(0,math.floor(min(a[1],b[1],c[1])))); y1=int(min(H-1,math.ceil(max(a[1],b[1],c[1]))))
    if x1<x0 or y1<y0: continue
    gx,gy=np.meshgrid(np.arange(x0,x1+1)+0.5,np.arange(y0,y1+1)+0.5)
    v0=b-a; v1=c-a; den=v0[0]*v1[1]-v1[0]*v0[1]
    if abs(den)<1e-12: continue
    px=gx-a[0]; py=gy-a[1]
    l1=(px*v1[1]-v1[0]*py)/den; l2=(v0[0]*py-px*v0[1])/den
    inside=(l1>=-1e-3)&(l2>=-1e-3)&(l1+l2<=1+1e-3)
    cov[y0:y1+1,x0:x1+1]|=inside
vis = band & cov
Image.fromarray((np.stack([vis*255,cov*120,band*80],2)).astype(np.uint8)).save('vis.png')
# per column runs of the visible band -> tracks
tracks=[]; open_runs=[]
for x in range(W):
    col=vis[:,x]; runs=[]; y=0
    while y<H:
        if col[y]:
            s=y
            while y<H and col[y]: y+=1
            if y-s>=3: runs.append((s,y-1))
        else: y+=1
    new=[]
    for (s,e) in runs:
        tid=None
        for (ti,ps,pe) in open_runs:
            if s<=pe+3 and e>=ps-3: tid=ti; break
        if tid is None: tracks.append([]); tid=len(tracks)-1
        tracks[tid].append((x+0.5,(s+e+1)/2))
        new.append((tid,s,e))
    open_runs=new
def to3d(u,v):
    out=[]
    for t,a,b,c in tri_uv:
        v0=b-a; v1=c-a; v2=np.array([u,v])-a
        den=v0[0]*v1[1]-v1[0]*v0[1]
        if abs(den)<1e-12: continue
        l1=(v2[0]*v1[1]-v1[0]*v2[1])/den; l2=(v0[0]*v2[1]-v2[0]*v0[1])/den
        if l1>=-1e-3 and l2>=-1e-3 and l1+l2<=1+1e-3:
            out.append(P[t[0]]*(1-l1-l2)+P[t[1]]*l1+P[t[2]]*l2)
    return out
K = 48.5/(mx-mn)[0]
SP = 1.25/K
bulbs=[]
info=[]
for tr in tracks:
    if len(tr)<8: continue
    # map every column centre; group the 3D points into instances by angle (16 panels)
    inst={}
    for (x,y) in tr:
        for p in to3d(x,y):
            q=p-ctr; ang=math.degrees(math.atan2(q[2],q[0]))%360
            key=None
            for k0 in inst:
                if abs(((ang-k0+180)%360)-180)<12 and abs(((ang-inst[k0]['last']+180)%360)-180)<3: key=k0; break
            if key is None: key=ang; inst[key]={'pts':[],'last':ang}
            inst[key]['pts'].append(q); inst[key]['last']=ang
    for k0,g in inst.items():
        pts=g['pts']; walked=SP/2; prev=None
        for q in pts:
            if prev is not None: walked+=np.linalg.norm(q-prev)
            if walked>=SP:
                bulbs.append(q.tolist()); walked=0
            prev=q
    info.append((len(tr),len(inst)))
# drop near-duplicates (seams where two panels meet)
out=[]
for b in bulbs:
    if all(np.linalg.norm(np.array(b)-np.array(o))>SP*0.6 for o in out): out.append(b)
json.dump({'k':K,'bulbs':out}, open('bulbs.json','w'))
print('tracks used',info,'bulbs',len(out), file=sys.stderr)
