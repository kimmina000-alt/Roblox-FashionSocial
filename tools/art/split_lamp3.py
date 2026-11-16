import sys, math; sys.path.insert(0,'.')
from glbio import mesh, write
OUT=sys.argv[1]
P,N,T,tris=mesh(r"D:/Roblox/오후/3D 물/street lamp.glb")
Y0,Y1=28.4,32.1   # the lantern's tapered band (rings at y 28.5 and 31.98)
# the lantern is a polygon, not a circle, so the panes are told from the bars by width: every tall face
# in the band is half of a quad; its two vertices on the same ring give that quad's width there. The
# bars are 0.108 wide at both rings, the panes 0.28-0.39 at the bottom and 0.60-0.71 at the top.
def isglass(t):
    ys=[P[v][1] for v in t]
    if min(ys)<Y0 or max(ys)>Y1 or max(ys)-min(ys)<2.5: return False
    lo=[P[v] for v in t if P[v][1]<30]; hi=[P[v] for v in t if P[v][1]>30]
    pair=lo if len(lo)==2 else hi
    w=math.hypot(pair[0][0]-pair[1][0],pair[0][2]-pair[1][2])
    return w>0.15
glass=[t for t in tris if isglass(t)]; body=[t for t in tris if not isglass(t)]
print("glass",len(glass),"body",len(body))
write(OUT+"/StreetLamp_split3.glb",[("LampBody",P,N,T,body,(0.25,0.16,0.1)),("LampGlass",P,N,T,glass,(1,1,1))])
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
xs=[p[0] for p in P]; cx=(max(xs)+min(xs))/2
gs=set(map(tuple,glass))
fig=plt.figure(figsize=(6,6)); ax=fig.add_subplot(111,projection='3d')
sel=[t for t in tris if min(P[v][1] for v in t)>26]
ax.add_collection3d(Poly3DCollection([[(P[v][0],P[v][2],P[v][1]) for v in t] for t in sel],facecolors=['gold' if tuple(t) in gs else 'dimgray' for t in sel],edgecolors='k',linewidths=0.1))
ax.set_xlim(cx-3,cx+3); ax.set_ylim(-3,3); ax.set_zlim(26,36); ax.view_init(10,30); ax.axis('off')
plt.savefig('lamp4.png',dpi=90)
