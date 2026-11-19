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
    Rall=R; R=[R[i] for i in rows_used]
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
    ysegs=[]; ys=[]; ysegsB=[]; joins=[]
    for ri,r in enumerate(R):
        t=np.mean([h['t'] for h in r]); b=np.mean([h['b'] for h in r])
        t0=gap+ri*(ch+gap); ys.append((t0,t0+ch,t,b))
    for i,sg in enumerate(ys):
        ysegs.append(sg)
        if i+1<len(ys):
            # the divider below this row in the art (the next art row may be further down)
            # (D-1871) the divider's real height in the art: to the art row right below this one
            nxt=ys[i+1]; ri0=rows_used[i]; artgap=min(np.mean([h['t'] for h in Rall[ri0+1]])-sg[3], 30)
            artgapB=min(nxt[2]-np.mean([h['b'] for h in Rall[rows_used[i+1]-1]]), 30)
            ysegs.append((sg[1],nxt[0],sg[3],sg[3]+max(artgap,5)))
            # (D-1871) B: the same divider read from just above the next used row; where the art
            # skips rows (1x4 = rows 1, 2, 5, 6) the divider fades from A to B, so no seam
            ysegsB.append((sg[1],nxt[0],nxt[2]-max(artgapB,5),nxt[2]))
            if rows_used[i+1]-rows_used[i]>1: joins.append((sg[1],nxt[0]))
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
    # (D-1871) x warp per output row: each art row's own hole edges (the drawn strip leans and
    # widens a little), blended between row centres, so the borders do not jump at the joins
    rowc=[gap+ri*(ch+gap)+ch/2 for ri in range(len(R))]
    def xsegs_for(rws):
        out=[]
        for c in range(cols):
            l=np.mean([r[c]['l'] for r in rws]); rr=np.mean([r[c]['r'] for r in rws])
            t0=gap+c*(cw+gap); out.append((t0,t0+cw,l,rr))
        segs=[]
        for i,sg in enumerate(out):
            segs.append(sg)
            if i+1<len(out): segs.append((sg[1],out[i+1][0],sg[3],out[i+1][2]))
        return segs
    rowx=[piecewise(xsegs_for([R[ri]]),s)(U) for ri in range(len(R))]
    mx=np.empty((Ho,Wo),np.float32)
    for j,v in enumerate(V):
        if v<=rowc[0]: mx[j]=rowx[0]
        elif v>=rowc[-1]: mx[j]=rowx[-1]
        else:
            i=max(q for q in range(len(rowc)) if rowc[q]<=v); t=(v-rowc[i])/(rowc[i+1]-rowc[i])
            mx[j]=rowx[i]*(1-t)+rowx[i+1]*t
    my=np.tile(fy(V).astype(np.float32)[:,None],(1,Wo))
    o=cv2.remap(a,mx,my,cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT,borderValue=(0,0,0,0)).astype(np.float32)
    for (j0,j1) in joins:
        segsB=[sg if not (abs(sg[0]-j0)<1e-9 and abs(sg[1]-j1)<1e-9) else [b for b in ysegsB if abs(b[0]-j0)<1e-9][0] for sg in ysegs]
        myB=np.tile(piecewise(segsB,s)(V).astype(np.float32)[:,None],(1,Wo))
        oB=cv2.remap(a,mx,myB,cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT,borderValue=(0,0,0,0)).astype(np.float32)
        w=np.clip((V-j0)/(j1-j0),0,1)[:,None,None]; inside=((V>=j0)&(V<j1))[:,None,None]
        o=np.where(inside,o*(1-w)+oB*w,o)
    o=np.clip(o,0,255)
    # (D-1871) exact photo holes: the game's cells as rounded rectangles (inset a hair so the
    # photo's edge stays under the frame), the frame right around them made solid
    px=lambda u,v:((u-u0)*k,(v-v0)*k)
    hole=np.zeros((Ho*4,Wo*4),np.uint8); ring=np.zeros((Ho,Wo),np.uint8)
    inset,rad=0.04,0.16; pad=gap/2+0.02
    for c in range(cols):
        for r in range(rows):
            x0=gap+c*(cw+gap); y0=gap+r*(ch+gap)
            X0,Y0=px(x0+inset,y0+inset); X1,Y1=px(x0+cw-inset,y0+ch-inset); R=rad*k
            for (sx0,sy0,sx1,sy1) in [(X0+R,Y0,X1-R,Y1),(X0,Y0+R,X1,Y1-R)]:
                cv2.rectangle(hole,(int(sx0*4),int(sy0*4)),(int(sx1*4),int(sy1*4)),255,-1)
            for (cx,cy) in [(X0+R,Y0+R),(X1-R,Y0+R),(X0+R,Y1-R),(X1-R,Y1-R)]:
                cv2.circle(hole,(int(cx*4),int(cy*4)),int(R*4),255,-1)
            RX0,RY0=px(x0-pad,y0-pad); RX1,RY1=px(x0+cw+pad,y0+ch+pad)
            cv2.rectangle(ring,(int(RX0),int(RY0)),(int(RX1),int(RY1)),1,-1)
    holeA=cv2.resize(hole.astype(np.float32)/255,(Wo,Ho),interpolation=cv2.INTER_AREA)
    al=o[:,:,3]/255.
    # gaps in the frame right around the holes: fill with the frame's colour (inpaint) and alpha 1
    weak=((ring>0)&(al<0.98)&(holeA<0.01)).astype(np.uint8)*255
    rgb=cv2.inpaint(np.clip(o[:,:,:3],0,255).astype(np.uint8),weak,4,cv2.INPAINT_TELEA).astype(np.float32)
    al=np.where(ring>0,1.0,al)*(1-holeA)
    o=np.dstack([rgb,al*255]).astype(np.uint8)
    cv2.imwrite(out,o)
    info=dict(x=u0/totalW,y=v0/totalH,w=(u1-u0)/totalW,h=(v1-v0)/totalH,px=[Wo,Ho])
    print(out,info); return info
a,hs=deskew('grid'); i1=build('grid',a,hs,[0,1],2,2,'opening_2x2.png')
a,hs=deskew('strip'); i2=build('strip',a,hs,[0,1,4,5],1,4,'opening_1x4.png')
json.dump({'2x2':i1,'1x4':i2},open('info.json','w'))
