import json, sys, math
pose = json.load(open(sys.argv[1]))
cap = {}
for line in open(sys.argv[2], encoding="utf-8-sig"):
    line = line.strip()
    if not line: continue
    k, v = line.split(":")
    cap[k + ".mp4"] = [float(x) for x in v.split(",")]
def capat(arr, t):
    i = t / 0.1
    a = int(i)
    if a >= len(arr) - 1: return arr[-1]
    f = i - a
    return arr[a] * (1 - f) + arr[a + 1] * f
def wrap(d): return (d + 180) % 360 - 180
for name in sorted(pose, key=lambda x: int(x.split(".")[0])):
    rows = pose[name]["rows"]
    if name not in cap or not rows: 
        print(name, "no capture data" if name not in cap else "no pose"); continue
    pos = sorted(r[1] for r in rows if r[1] > 0)
    if len(pos) < 10: print(name, "no front at all"); continue
    rmax = pos[int(len(pos) * 0.95) - 1]
    front = [r for r in rows if r[1] > 0.85 * rmax and r[2] > 0.5 and abs(r[3]) < 0.12]
    if len(front) < 5: print(name, "few front frames", len(front)); continue
    ys = sorted(wrap(capat(cap[name], r[0])) for r in front)
    med = ys[len(ys) // 2]
    mad = sorted(abs(wrap(y - med)) for y in ys)[len(ys) // 2]
    span = (round(front[0][0], 1), round(front[-1][0], 1))
    print(f"{name}: front frames {len(front)} in {span}, capture yaw median {med:.0f} (MAD {mad:.0f}) -> faceOffset {-med:.0f}")
