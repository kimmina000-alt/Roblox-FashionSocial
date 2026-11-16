import sys, math; sys.path.insert(0,'.')
from glbio import mesh, write
OUT=sys.argv[1]
P,N,T,tris=mesh(r"D:/Roblox/오후/3D 물/street lamp.glb")
xs=[p[0] for p in P]; cx=(max(xs)+min(xs))/2
def r(p): return math.hypot(p[0]-cx,p[2])
Y0,Y1=28.4,32.1   # the lantern's tapered glass band (rings at 28.5 and 31.98)
band=[v for v in range(len(P)) if Y0<P[v][1]<Y1]
rmaxLo=max(r(P[v]) for v in band if abs(P[v][1]-28.5)<0.006); rmaxHi=max(r(P[v]) for v in band if abs(P[v][1]-31.98)<0.006)
def inner(v): return r(P[v]) < (rmaxLo if P[v][1]<30 else rmaxHi)*0.994
def isglass(t):
    ys=[P[v][1] for v in t]
    if min(ys)<Y0 or max(ys)>Y1 or max(ys)-min(ys)<2.5: return False
    return not all(inner(v) for v in t)
glass=[t for t in tris if isglass(t)]; body=[t for t in tris if not isglass(t)]
print("rmax",rmaxLo,rmaxHi,"glass",len(glass),"body",len(body))
write(OUT+"/StreetLamp_split2.glb",[("LampBody",P,N,T,body,(0.4,0.3,0.22)),("LampGlass",P,N,T,glass,(1,1,1))])
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
gs=set(map(tuple,glass))
fig=plt.figure(figsize=(6,6)); ax=fig.add_subplot(111,projection='3d')
sel=[t for t in tris if min(P[v][1] for v in t)>26]
ax.add_collection3d(Poly3DCollection([[(P[v][0],P[v][2],P[v][1]) for v in t] for t in sel],facecolors=['gold' if tuple(t) in gs else 'dimgray' for t in sel],edgecolors='k',linewidths=0.1))
ax.set_xlim(cx-3,cx+3); ax.set_ylim(-3,3); ax.set_zlim(26,36); ax.view_init(10,30); ax.axis('off')
plt.savefig('lamp3.png',dpi=90)
