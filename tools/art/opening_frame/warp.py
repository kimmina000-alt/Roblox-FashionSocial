import cv2, numpy as np, json
def holes_of(mask):
    n,lab,st,_=cv2.connectedComponentsWithStats(mask.astype(np.uint8),connectivity=8)
    hs=[]
    for i in range(1,n):
        if st[i,4]>3000:
            ys,xs=np.where(lab==i)
            # robust edges: 5th/95th percentiles of the hole's own pixels
            hs.append(dict(l=np.percentile(xs,1),r=np.percentile(xs,99),t=np.percentile(ys,1),b=np.percentile(ys,99),cx=xs.mean(),cy=ys.mean()))
    return hs
def deskew(name):
    a=cv2.imread(name+'_cut.png',cv2.IMREAD_UNCHANGED); hm=np.load(name+'_holes.npy').astype(np.uint8)*255
    ys,xs=np.where(hm>0); c=(float(xs.mean()),float(ys.mean()))
    n,lab,st,cen=cv2.connectedComponentsWithStats((hm>127).astype(np.uint8),connectivity=8)
    C=np.array([cen[i] for i in range(1,n) if st[i,4]>3000])
    best=None
    for ang in np.arange(-12,12.001,0.02):
        M=cv2.getRotationMatrix2D(c,ang,1)
        P=(M[:,:2]@C.T).T+M[:,2]
        if len(C)==4:
            P=P[np.argsort(P[:,1])]; sc=abs(P[0,1]-P[1,1])+abs(P[2,1]-P[3,1])+abs(min(P[0,0],P[1,0])-min(P[2,0],P[3,0]))
        else:
            sc=np.std(P[:,0])
        if best is None or sc<best[0]: best=(sc,ang)
    ang=best[1]; M=cv2.getRotationMatrix2D(c,ang,1)
    a2=cv2.warpAffine(a,M,(a.shape[1],a.shape[0]),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT,borderValue=(0,0,0,0))
    h2=cv2.warpAffine(hm,M,(a.shape[1],a.shape[0]))>127
    print(name,'angle',round(ang,2))
    return a2,holes_of(h2)
def piecewise(segs, s):
    # segs: list of (t0,t1,a0,a1) sorted; outside: uniform scale s (units per px)
    def f(t):
        t=np.asarray(t,float); out=np.empty_like(t)
        first,last=segs[0],segs[-1]
        out[:]=np.nan
        m=t<first[0]; out[m]=first[2]-(first[0]-t[m])/s
        m=t>=last[1]; out[m]=last[3]+(t[m]-last[1])/s
        for t0,t1,a0,a1 in segs:
            m=(t>=t0)&(t<t1); out[m]=a0+(t[m]-t0)/(t1-t0)*(a1-a0)
        return out
    return f
def build(name,a,hs,rows_used,cols,rows,out):
    hs=sorted(hs,key=lambda h:h['cy'])
    # group into rows
    R=[]; 
    for h in hs:
        if R and abs(R[-1][0]['cy']-h['cy'])<40: R[-1].append(h)
        else: R.append([h])
    for r in R: r.sort(key=lambda h:h['cx'])
    R=[R[i] for i in rows_used]
    gap,cw,ch=0.35,4,3
    totalW=cols*cw+(cols+1)*gap; totalH=rows*ch+(rows+1)*gap+1.4
    # x segments
    xs=[]
    for c in range(cols):
        l=np.mean([r[c]['l'] for r in R]); rr=np.mean([r[c]['r'] for r in R])
        t0=gap+c*(cw+gap); xs.append((t0,t0+cw,l,rr))
    xsegs=[]
    for i,sg in enumerate(xs):
        xsegs.append(sg)
        if i+1<len(xs): xsegs.append((sg[1],xs[i+1][0],sg[3],xs[i+1][2]))
    ysegs=[]; ys=[]
    for ri,r in enumerate(R):
        t=np.mean([h['t'] for h in r]); b=np.mean([h['b'] for h in r])
        t0=gap+ri*(ch+gap); ys.append((t0,t0+ch,t,b))
    for i,sg in enumerate(ys):
        ysegs.append(sg)
        if i+1<len(ys):
            # the divider below this row in the art (the next art row may be further down)
            nxt=ys[i+1]; artgap=min(nxt[2]-sg[3], 30)
            ysegs.append((sg[1],nxt[0],sg[3],sg[3]+max(artgap,5)))
            # (the art after the divider continues at the next used row)
    # fix: segment after a divider must start at next row top: handled since row seg uses its own a0
    s=np.mean([(sg[1]-sg[0])/(sg[3]-sg[2]) for sg in xs])
    fx=piecewise(xsegs,s); fy=piecewise(ysegs,s)
    # canvas extents: invert over the alpha bbox
    al=a[:,:,3]; yy,xx=np.where(al>8)
    def inv(segs,v):
        # art px -> units (monotonic): sample
        T=np.linspace(-6,40,46001); A=piecewise(segs,s)(T)
        return np.interp(v,A,T)
    u0,u1=inv(xsegs,xx.min()),inv(xsegs,xx.max()); v0,v1=inv(ysegs,yy.min()),inv(ysegs,yy.max())
    if name=='strip': # the rows left out: art y between used rows, bbox fine
        pass
    k=min(1024/(u1-u0),1024/(v1-v0))
    Wo,Ho=int((u1-u0)*k),int((v1-v0)*k)
    U=u0+(np.arange(Wo)+0.5)/k; V=v0+(np.arange(Ho)+0.5)/k
    mx=np.tile(fx(U).astype(np.float32),(Ho,1)); my=np.tile(fy(V).astype(np.float32)[:,None],(1,Wo))
    o=cv2.remap(a,mx,my,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=(0,0,0,0))
    cv2.imwrite(out,o)
    info=dict(x=u0/totalW,y=v0/totalH,w=(u1-u0)/totalW,h=(v1-v0)/totalH,px=[Wo,Ho])
    print(out,info); return info
a,hs=deskew('grid'); i1=build('grid',a,hs,[0,1],2,2,'opening_2x2.png')
a,hs=deskew('strip'); i2=build('strip',a,hs,[0,1,4,5],1,4,'opening_1x4.png')
json.dump({'2x2':i1,'1x4':i2},open('info.json','w'))
