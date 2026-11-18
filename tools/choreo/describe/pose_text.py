"""Korean pose text from pose json files, and the original against the game (D-1863, README.md).

python pose_text.py describe <pose.json> [--from s] [--to s] [--min 0.25]
python pose_text.py compare <video.json> <game.json> [--from s] [--to s] [--mirror auto|on|off] [--sheet out_dir]
"""
import argparse, json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pose_common as pc


def load(path, t0=None, t1=None):
    d = json.load(open(path, encoding="utf-8"))
    d["_path"] = os.path.abspath(path)
    s = [r for r in d["samples"] if (t0 is None or r["t"] >= t0 - 1e-6) and (t1 is None or r["t"] <= t1 + 1e-6)]
    return d, s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["describe", "compare"])
    ap.add_argument("files", nargs="+")
    ap.add_argument("--from", dest="t0", type=float)
    ap.add_argument("--to", dest="t1", type=float)
    ap.add_argument("--min", type=float, default=0.25)
    ap.add_argument("--mirror", default="auto")
    ap.add_argument("--sheet")
    ap.add_argument("--out")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    lines = []
    if a.mode == "describe":
        _, s = load(a.files[0], a.t0, a.t1)
        lines = pc.describe(s, a.min)
    else:
        import pose_compare
        dv, v = load(a.files[0], a.t0, a.t1)
        dg, g = load(a.files[1], a.t0, a.t1)
        lines = pose_compare.compare(dv, v, dg, g, a.mirror, a.min, a.sheet)
    text = "\n".join(lines)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
