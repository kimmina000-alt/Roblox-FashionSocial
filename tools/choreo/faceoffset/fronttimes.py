# (D-1002) the moments in each clip where the member faces the camera, as a Lua table
# for frontcheck.lua: python fronttimes.py pose.json "1:id,2:id,..." > front.lua
import json, sys
pose = json.load(open(sys.argv[1]))
ids = dict(p.split(":") for p in sys.argv[2].split(","))
items = []
for name in sorted(pose, key=lambda x: int(x.split(".")[0])):
    clip = name.split(".")[0]
    if clip not in ids: continue
    rows = pose[name]["rows"]
    pos = sorted(r[1] for r in rows if r[1] > 0)
    if len(pos) < 10: continue
    rmax = pos[int(len(pos) * 0.95) - 1]
    ts = [round(r[0], 2) for r in rows if r[1] > 0.85 * rmax and r[2] > 0.5 and abs(r[3]) < 0.12]
    ts = [round(x, 1) for x in ts]
    ts = sorted(set(ts))
    if len(ts) > 40: ts = ts[::int(len(ts) / 40 + 1)]
    items.append("[%s]={id=%s,t={%s}}" % (clip, ids[clip], ",".join("%g" % t for t in ts)))
print("{" + ",".join(items) + "}")
