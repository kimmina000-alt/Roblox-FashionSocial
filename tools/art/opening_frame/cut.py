import cv2, numpy as np
import sys
im=cv2.imread(sys.argv[1] if len(sys.argv)>1 else 'opening_frame_source.png'); H,W=im.shape[:2]
hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV).astype(int)
rgb=im[:,:,::-1].astype(int)
d=lambda c:np.abs(rgb-np.array(c)).max(axis=2)
pinkish=(d((253,201,228))<20)|(d((248,194,220))<14)|(d((244,186,214))<12)
def strip_poly():
    pts=[(78,105),(92,62),(150,40),(190,18),(430,0),(500,120)]
    for y in range(250,1006,50): pts.append((470+0.15*y,y))
    pts += [(190,1005),(158,972),(118,930),(118,800),(195,800)]
    for y in range(780,159,-40): pts.append((110+0.15*(y-200),y))
    pts += [(104,160),(78,120)]
    return pts
def grid_poly():
    return [(548,112),(1390,112),(1395,135),(1462,140),(1462,150),(1482,160),(1482,845),(548,845)]
def cut(name,poly):
    m=np.zeros((H,W),np.uint8); cv2.fillPoly(m,[np.array(poly,np.int32)],1)
    cand=(pinkish&(m>0)).astype(np.uint8)
    n,lab,st,_=cv2.connectedComponentsWithStats(cand,connectivity=4)
    # components touching the polygon's outside
    edge=cv2.dilate((m==0).astype(np.uint8),np.ones((3,3),np.uint8))
    remove=np.zeros(n,bool); holes=[]
    touch=np.unique(lab[(edge>0)&(cand>0)])
    remove[touch]=True
    for i in range(1,n):
        if st[i,4]>5000 and not remove[i]: remove[i]=True; holes.append(i)
    remove[0]=False
    alpha=((m>0)&~remove[lab]).astype(np.uint8)
    # keep the biggest piece only
    n2,l2,s2,_=cv2.connectedComponentsWithStats(alpha,connectivity=8)
    big=1+np.argmax(s2[1:,4]); alpha=(l2==big).astype(np.uint8)
    holemask=np.isin(lab,holes)
    print(name,'holes',len(holes))
    alpha=cv2.morphologyEx(alpha,cv2.MORPH_OPEN,np.ones((5,5),np.uint8))
    n3,l3,s3,_=cv2.connectedComponentsWithStats(alpha,connectivity=8)
    alpha=(l3==1+np.argmax(s3[1:,4])).astype(np.uint8)
    # (D-1871, user 2026-11-19: "프레임 누끼 더 정교하게") a finer cut:
    # 1. fill specks inside the frame (not the photo holes, not the outside)
    inv=(alpha==0).astype(np.uint8)
    n4,l4,s4,_=cv2.connectedComponentsWithStats(inv,connectivity=4)
    border=np.unique(np.concatenate([l4[0],l4[-1],l4[:,0],l4[:,-1]]))
    hole_ids=np.unique(l4[holemask&(inv>0)])
    for i in range(1,n4):
        if i not in border and i not in hole_ids and s4[i,4]<3000: alpha[l4==i]=1
    # 2. eat the light-pink fringe the background leaves on the edge (1 px), then a smooth
    #    contour: blur at 4x, threshold, area-downsample = anti-aliased edges without stair steps
    alpha=cv2.erode(alpha,np.ones((3,3),np.uint8))
    big4=cv2.resize(alpha.astype(np.float32),(W*4,H*4),interpolation=cv2.INTER_LINEAR)
    big4=cv2.GaussianBlur(big4,(0,0),4.5)
    big4=(big4>0.5).astype(np.float32)
    soft=cv2.resize(big4,(W,H),interpolation=cv2.INTER_AREA)
    # 3. colour clean-up on the edge: pixels near the background pink in the outer 4 px get the
    #    colour of the frame just inside (inpaint), so no pink halo on dark backgrounds
    inner=cv2.erode((soft>0.99).astype(np.uint8),np.ones((9,9),np.uint8))
    band=(soft>0)&(inner==0)
    bad=(band&pinkish).astype(np.uint8)*255
    clean=cv2.inpaint(im,bad,5,cv2.INPAINT_TELEA)
    a=np.clip(soft*255+0.5,0,255).astype(np.uint8)
    out=np.dstack([clean,a])
    cv2.imwrite(name+'_cut.png',out)
    np.save(name+'_holes.npy',holemask)
    return out,holemask
cut('strip',strip_poly()); cut('grid',grid_poly())
