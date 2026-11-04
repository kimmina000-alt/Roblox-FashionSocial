import json
import sys

S = json.load(open(sys.argv[1], encoding="utf-8"))
for s in S:
    tops = []
    for p in s["people"]:
        t = p["top"][0] if p["top"] else None
        tops.append(f'{p["n"]}:{t["h"]:.2f}{"A" if t["ankle"] else ""}{"K" if t["knee"] else ""}{"H" if t["hip"] else ""}' if t else f'{p["n"]}:-')
    print(f'{s["i"]:2d} {s["s0"]:6.2f}-{s["s1"]:6.2f} ({s["dur"]:4.2f}) z{s["zoom"]:.2f} px{s["panx"]:+.2f} py{s["pany"]:+.2f} r{s["roll"]:+.1f} {s["prog"]} | ' + " ".join(tops))
