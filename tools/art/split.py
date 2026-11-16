import sys, math; sys.path.insert(0,'.')
from glbio import mesh, write
OUT=sys.argv[1]
# bench: seat = triangles with every vertex at |y| <= 0.21 (the planks), legs = the rest
P,N,T,tris=mesh(r"D:/Roblox/오후/3D 물/Bench.glb")
seat=[t for t in tris if all(abs(P[v][1])<=0.21 for v in t)]
legs=[t for t in tris if not all(abs(P[v][1])<=0.21 for v in t)]
print("bench seat",len(seat),"legs",len(legs))
write(OUT+"/Bench_split.glb",[("BenchLegs",P,N,T,legs,(0.08,0.08,0.08)),("BenchSeat",P,N,T,seat,(0.55,0.36,0.2))])
# lamp: glass = the recessed panes of the head (y 29..34.5, tall faces, every vertex inside the bars' radius)
P,N,T,tris=mesh(r"D:/Roblox/오후/3D 물/street lamp.glb")
cx=(4.418265342712402+10.755037307739258)/2
def r(p): return math.hypot(p[0]-cx,p[2])
def isglass(t):
    ys=[P[v][1] for v in t]
    if min(ys)<29.0 or max(ys)>34.5 or max(ys)-min(ys)<4: return False
    # the panes are the wide faces; the narrow recessed strips (every vertex inside the outer
    # radius) are the frame bars between them
    inner=all(r(P[v])<(1.475 if P[v][1]<30 else 2.715) for v in t)
    return not inner
glass=[t for t in tris if isglass(t)]; body=[t for t in tris if not isglass(t)]
print("lamp glass",len(glass),"body",len(body))
write(OUT+"/StreetLamp_split.glb",[("LampBody",P,N,T,body,(0.25,0.22,0.18)),("LampGlass",P,N,T,glass,(1,1,1))])
