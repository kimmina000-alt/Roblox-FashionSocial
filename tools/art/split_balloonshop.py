import sys; sys.path.insert(0,'.')
from glbio import mesh, write
OUT=sys.argv[1]
# primitive 0 of the shop mesh = the decoration: 4 balloons, 4 strings, the sign letters
P,N,T,tris=mesh(r"D:/Roblox/오후/3D 물/balloonshop.glb")
key=lambda v:(round(P[v][0],3),round(P[v][1],3),round(P[v][2],3))
parent={}
def f(x):
    while parent.setdefault(x,x)!=x: parent[x]=parent[parent[x]]; x=parent[x]
    return x
for t in tris:
    a,b,c=[key(v) for v in t]; parent[f(a)]=f(b); parent[f(b)]=f(c)
comps={}
for t in tris: comps.setdefault(f(key(t[0])),[]).append(t)
balloons=[]; strings=[]; sign=[]
for ts in comps.values():
    if len(ts)==318: balloons.append(ts)
    elif len(ts)==100: strings+=ts
    else: sign+=ts
balloons.sort(key=lambda ts: min(P[v][0] for t in ts for v in t))
cols=[(1,0.35,0.45),(1,0.8,0.25),(0.35,0.7,1),(0.6,0.95,0.5)]
parts=[("Balloon%d"%(i+1),P,N,T,ts,cols[i]) for i,ts in enumerate(balloons)]
parts.append(("BalloonStrings",P,N,T,strings,(1,1,1)))
parts.append(("ShopSign",P,N,T,sign,(0.45,0.3,0.6)))
write(OUT+"/BalloonShopDecor_split.glb",parts)
print(len(balloons),"balloons",len(strings),"string tris",len(sign),"sign tris")
