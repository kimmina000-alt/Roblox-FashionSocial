# (D-1424) Viking boats: re-UV the user's 09_MiniViking.glb / 02_SuperViking.glb (outer hull sides,
# ends, inside, seats, bars each get their own texture area) and paint the texture from the photos
# (mini: yellow/red with pastel star panels; super: deep red with gold trim). Writes *_Tex.glb + .png
# (copies in docs/04_ART/park/viking_tex). python tools/art/viking_tex.py
# (D-1428) *_Tex2.glb: the hull walls above the seat pans at half height (riders see out).
import json,struct,sys,io,math,numpy as np
from PIL import Image,ImageDraw,ImageFilter
def load(p):
    b=open(p,'rb').read(); jl=struct.unpack('<I',b[12:16])[0]; js=json.loads(b[20:20+jl]); bin_=b[20+jl+8:]
    pr=js['meshes'][0]['primitives'][0]
    def acc(i,dt,n):
        a=js['accessors'][i]; bv=js['bufferViews'][a['bufferView']]; o=bv.get('byteOffset',0)+a.get('byteOffset',0)
        r=np.frombuffer(bin_,dtype=dt,count=a['count']*n,offset=o); return r.reshape(-1,n) if n>1 else r
    P=acc(pr['attributes']['POSITION'],np.float32,3); N=acc(pr['attributes']['NORMAL'],np.float32,3)
    a=js['accessors'][pr['indices']]; I=acc(pr['indices'],{5123:np.uint16,5125:np.uint32}[a['componentType']],1).reshape(-1,3)
    return js,P,N,I
def comps(P,I):
    n=len(P); par=list(range(n))
    def f(x):
        while par[x]!=x: par[x]=par[par[x]]; x=par[x]
        return x
    key={}
    for i,q in enumerate(np.round(P,4)):
        k=tuple(q)
        if k in key: par[f(i)]=f(key[k])
        else: key[k]=i
    for t in I: par[f(t[1])]=f(t[0]); par[f(t[2])]=f(t[0])
    return np.array([f(t[0]) for t in I])
W=1024
SOLID={} # name -> (cx,cy) pixel
def build(src,dst,style,squash=None):
    js,P,N,I=load(src)
    cid=comps(P,I); sizes={c:(cid==c).sum() for c in set(cid)}
    hullc=max(sizes,key=sizes.get)
    if squash:  # (D-1428) lower the hull walls above the seat pans: y' = pan + (y - pan) * k
        pan,k=squash; P=P.copy()
        hv=np.unique(I[cid==hullc].ravel())
        up=hv[P[hv,1]>pan]; P[up,1]=pan+(P[up,1]-pan)*k
    hv=np.unique(I[cid==hullc].ravel()); lo=P[hv].min(0); hi=P[hv].max(0); ctr=(lo+hi)/2
    img=Image.new('RGB',(W,W),(0,0,0)); d=ImageDraw.Draw(img)
    S=style
    # region A: hull outer side painting (0..W, 0..W/2)
    paint_side(img,(0,0,W,W//2),S)
    # solid squares in the lower half
    names=['inner','rim','bottom','end','seat','seatside','bar']
    for k,nm in enumerate(names):
        x0=16+k*140; y0=W//2+40
        d.rectangle([x0,y0,x0+120,y0+120],fill=S[nm]); SOLID[nm]=((x0+60)/W,(y0+60)/W)
    # end panels (bow/stern outer faces) get their own painted square
    paint_end(img,(16,W//2+200,16+400,W//2+200+300),S); endrect=(16,W//2+200,416,W//2+500)
    outP=[];outN=[];outUV=[]
    for ti,t in enumerate(I):
        v=P[t]; nn=N[t].mean(0); nn/=np.linalg.norm(nn)+1e-9; c=v.mean(0)
        if cid[ti]==hullc:
            if nn[1]>0.6: kind='rim'
            elif nn[1]<-0.6: kind='bottom'
            elif abs(nn[0])>=abs(nn[2]):
                kind='side' if np.sign(nn[0])==np.sign(c[0]-ctr[0]) and abs(c[0]-ctr[0])>0.02 else 'inner'
            else:
                kind='endp' if np.sign(nn[2])==np.sign(c[2]-ctr[2]) else 'inner'
        else:
            ext=P[np.unique(I[cid==cid[ti]].ravel())]; h=ext.max(0)-ext.min(0)
            if h[1]<0.08 or min(h[0],h[2])<0.08 and sizes[cid[ti]]<=12: kind='bar'
            else: kind='seat' if nn[1]>0.5 else 'seatside'
        for k in range(3):
            p=v[k]
            if kind=='side':
                u=(p[2]-lo[2])/(hi[2]-lo[2]); yn=(p[1]-lo[1])/(hi[1]-lo[1])
                uv=(0.004+u*0.992, (1-yn)*0.5*0.99+0.002)
            elif kind=='endp':
                u=(p[0]-lo[0])/(hi[0]-lo[0]); yn=(p[1]-lo[1])/(hi[1]-lo[1])
                uv=((endrect[0]+u*(endrect[2]-endrect[0]))/W,(endrect[3]-yn*(endrect[3]-endrect[1]))/W)
            else:
                uv=SOLID[kind]
            outP.append(p); outN.append(N[t[k]]); outUV.append(uv)
        if cid[ti]==hullc:  # the hull is an outer shell only: add its inside (reversed, a hair inward)
            ik='bottom' if nn[1]<-0.6 else 'inner'
            for k in (0,2,1):
                outP.append(v[k]-nn*0.012); outN.append(-N[t[k]]); outUV.append(SOLID[ik])
    outP=np.array(outP,np.float32); outN=np.array(outN,np.float32); outUV=np.array(outUV,np.float32)
    idx=np.arange(len(outP),dtype=np.uint32)
    img=img.filter(ImageFilter.SMOOTH)
    buf=io.BytesIO(); img.save(buf,'PNG'); png=buf.getvalue()
    img.save(dst.replace('.glb','.png'))
    write_glb(dst,js['nodes'][0]['name'],outP,outN,outUV,idx,png)
    print(dst,len(idx)//3,'tris','min',outP.min(0).round(4).tolist(),'max',outP.max(0).round(4).tolist())
def write_glb(dst,name,P,N,UV,I,png):
    blobs=[P.tobytes(),N.tobytes(),UV.tobytes(),I.tobytes(),png]
    views=[];off=0;data=b''
    for k,bb in enumerate(blobs):
        pad=(-len(bb))%4; v={'buffer':0,'byteOffset':off,'byteLength':len(bb)}
        if k<3: v['target']=34962
        elif k==3: v['target']=34963
        views.append(v); data+=bb+b'\0'*pad; off+=len(bb)+pad
    js={'asset':{'version':'2.0','generator':'ohu viking_tex'},'scene':0,'scenes':[{'nodes':[0]}],
        'nodes':[{'mesh':0,'name':name}],
        'meshes':[{'name':name,'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'TEXCOORD_0':2},'indices':3,'material':0}]}],
        'materials':[{'name':name+'_mat','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':0.7}}],
        'textures':[{'source':0}],'images':[{'bufferView':4,'mimeType':'image/png','name':name+'_tex'}],
        'accessors':[{'bufferView':0,'componentType':5126,'count':len(P),'type':'VEC3','min':P.min(0).tolist(),'max':P.max(0).tolist()},
                     {'bufferView':1,'componentType':5126,'count':len(N),'type':'VEC3'},
                     {'bufferView':2,'componentType':5126,'count':len(UV),'type':'VEC2'},
                     {'bufferView':3,'componentType':5125,'count':len(I),'type':'SCALAR'}],
        'bufferViews':views,'buffers':[{'byteLength':len(data)}]}
    j=json.dumps(js).encode(); j+=b' '*((-len(j))%4)
    out=struct.pack('<III',0x46546C67,2,12+8+len(j)+8+len(data))+struct.pack('<II',len(j),0x4E4F534A)+j+struct.pack('<II',len(data),0x004E4942)+data
    open(dst,'wb').write(out)
def paint_side(img,r,S):
    x0,y0,x1,y1=r; d=ImageDraw.Draw(img); h=y1-y0; w=x1-x0
    d.rectangle(r,fill=S['body'])
    d.rectangle([x0,y0,x1,y0+int(h*0.16)],fill=S['band'])            # top rim band
    d.rectangle([x0,y0+int(h*0.16),x1,y0+int(h*0.19)],fill=S['line'])
    d.rectangle([x0,y1-int(h*0.20),x1,y1],fill=S['low'])               # lower band
    d.rectangle([x0,y1-int(h*0.23),x1,y1-int(h*0.20)],fill=S['line'])
    n=S['panels']; py0=y0+int(h*0.27); py1=y1-int(h*0.30); gap=w/(n)
    for k in range(n):
        cx=x0+gap*(k+0.5); pw=gap*0.70
        col=S['panelcols'][k%len(S['panelcols'])]
        d.rounded_rectangle([cx-pw/2,py0,cx+pw/2,py1],radius=int(pw*0.12),fill=S['panelrim'])
        d.rounded_rectangle([cx-pw/2+7,py0+7,cx+pw/2-7,py1-7],radius=int(pw*0.10),fill=col)
        star(d,cx,(py0+py1)/2,min(pw,py1-py0)*0.22,S['panelmark'])
    for k in range(int(w/38)):   # bulbs on the top band
        cx=x0+19+k*38; cy=y0+int(h*0.08)
        d.ellipse([cx-8,cy-8,cx+8,cy+8],fill=S['bulb'])
def paint_end(img,r,S):
    d=ImageDraw.Draw(img); x0,y0,x1,y1=r
    d.rectangle(r,fill=S['panelrim'])
    d.rounded_rectangle([x0+18,y0+18,x1-18,y1-18],radius=30,fill=S['body'])
    star(d,(x0+x1)/2,(y0+y1)/2,80,S['endstar'])
def star(d,cx,cy,R,col):
    pts=[]
    for k in range(10):
        a=-math.pi/2+k*math.pi/5; rr=R if k%2==0 else R*0.45
        pts.append((cx+rr*math.cos(a),cy+rr*math.sin(a)))
    d.polygon(pts,fill=col)
MINI=dict(body=(250,200,30),band=(215,35,40),line=(255,255,255),low=(215,35,40),panels=6,
    panelrim=(215,35,40),panelcols=[(120,200,240),(255,160,200),(140,220,150),(190,160,240),(255,200,120),(130,210,230)],
    panelmark=(255,255,255),bulb=(255,245,200),inner=(205,40,45),rim=(215,35,40),bottom=(120,28,28),end=(250,200,30),
    seat=(35,35,40),seatside=(55,55,60),bar=(205,205,210),endstar=(215,35,40))
SUPER=dict(body=(140,32,32),band=(110,22,22),line=(230,185,80),low=(95,45,30),panels=12,
    panelrim=(230,185,80),panelcols=[(200,40,45)],panelmark=(250,235,200),bulb=(255,230,160),
    inner=(180,40,40),rim=(230,185,80),bottom=(80,35,25),end=(140,32,32),seat=(45,30,30),seatside=(170,40,40),bar=(205,205,210),endstar=(230,185,80))
base="D:/Roblox/오후/3D 물/"
build(base+"09_MiniViking.glb",base+"viking_tex/09_MiniViking_Tex.glb",MINI)
build(base+"02_SuperViking.glb",base+"viking_tex/02_SuperViking_Tex.glb",SUPER)
# (D-1428, user: "바이킹 둘 다 윗부분 블록 높이 낮추기. 캐릭터 시야 다 가려져서 옆이 안 보임")
# v2: the hull walls above the seat pans at half height (seats and bars stay)
build(base+"09_MiniViking.glb",base+"viking_tex/09_MiniViking_Tex2.glb",MINI,squash=(0.66,0.5))
build(base+"02_SuperViking.glb",base+"viking_tex/02_SuperViking_Tex2.glb",SUPER,squash=(1.016,0.5))
