"""Split ClubConfig.lua into ClubChoreo / ClubDances / ClubPlaylist / ClubDrinks (D-888).

Moves blocks verbatim (line ranges checked by hand), renames ClubConfig.X to
M.X in code lines of the moved blocks, and puts explicit re-exports into
ClubConfig so every ClubConfig.X keeps working (and keeps its type).
"""
import re
import sys

shared = sys.argv[1]
path = shared + "/ClubConfig.lua"
raw = open(path, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in raw else "\n"
L = raw.split(nl)


def block(a, b):
    return L[a - 1:b]


def to_m(lines):
    out = []
    for s in lines:
        if s.lstrip().startswith("--"):
            out.append(s)
            continue
        code, sep, comment = s.partition("--")
        out.append(re.sub(r"\bClubConfig\.", "M.", code) + sep + comment)
    return out


def keys(lines):
    ks = []
    for s in lines:
        m = re.match(r"^(?:function )?M\.(\w+)", s)
        if m and m.group(1) not in ks:
            ks.append(m.group(1))
    return ks


R = {
    "dance_type": (14, 21), "track_types": (22, 66),
    "choreo": (69, 411), "dances": (505, 547), "playlist": (549, 719),
    "drink_types": (744, 777), "drinks": (797, 888), "vis": (923, 937),
}
assert L[13].startswith("export type Dance") and L[21].startswith("export type Track")
assert L[68].startswith("-- (D-811") and L[410] == "end"
assert L[504].startswith("ClubConfig.Categories") and L[546].startswith("ClubConfig.JoinRadius")
assert L[552].startswith("ClubConfig.SavedLabs") and L[718].startswith("} :: {Track}")
assert L[743].startswith("-----") and L[775] == "}"
assert L[799].startswith("ClubConfig.Drinks") and L[887].startswith("ClubConfig.GulpSoundId")
assert L[923].startswith("ClubConfig.Visibility") and L[935] == "end"

HEAD = "--!strict" + nl + "-- (D-888, user 2026-11-05: ClubConfig split up, one file per kind) {what}." + nl + \
    "-- ClubConfig re-exports every field below, so ClubConfig.{eg} keeps working." + nl

modules = {
    "ClubChoreo": ("Choreography tuning: smoothing, retarget, per-animation fixes, shake / slide checks", "ChoreoFixes",
                   [], to_m(block(*R["choreo"]))),
    "ClubDances": ("The dance menu: categories, dances, tempo range, join radius", "Dances",
                   block(*R["dance_type"]), to_m(block(*R["dances"]))),
    "ClubPlaylist": ("Club music: track types, the saved lab values and the playlist (the user's own uploads at the end)",
                     "Playlist", block(*R["track_types"]), to_m(block(*R["playlist"]))),
    "ClubDrinks": ("Club drinks (non-alcoholic only, D-043), prices, bottles, who may pour", "Drinks",
                   to_m(block(*R["drink_types"])), to_m(block(*R["drinks"]) + [""] + block(*R["vis"]))),
}
exports = {}
for name, (what, eg, types, body) in modules.items():
    src = HEAD.format(what=what, eg=eg) + nl + nl.join(types) + nl + "local M = {}" + nl + nl + nl.join(body) + nl + nl + "return M" + nl
    open(f"{shared}/{name}.lua", "w", encoding="utf-8", newline="").write(src)
    exports[name] = keys(body)
    print(name, len(body), "lines", exports[name])

# ClubConfig: drop the moved ranges (from the bottom up), add requires + re-exports
drop = sorted([R[k] for k in R], reverse=True)
kept = list(L)
for a, b in drop:
    del kept[a - 1:b]
idx = kept.index("local ClubConfig = {}")
glue = [
    "local ClubConfig = {}",
    "",
    "-- (D-888) the big tables live in their own files next to this one; their",
    "-- fields are copied here one by one, so ClubConfig.X and the types still work",
    "local ClubChoreo = require(script.Parent:WaitForChild(\"ClubChoreo\"))",
    "local ClubDances = require(script.Parent:WaitForChild(\"ClubDances\"))",
    "local ClubPlaylist = require(script.Parent:WaitForChild(\"ClubPlaylist\"))",
    "local ClubDrinks = require(script.Parent:WaitForChild(\"ClubDrinks\"))",
    "export type Dance = ClubDances.Dance",
    "export type Track = ClubPlaylist.Track",
    "export type Lab = ClubPlaylist.Lab",
    "export type Joined = ClubPlaylist.Joined",
    "export type DrinkVariant = ClubDrinks.DrinkVariant",
    "export type Drink = ClubDrinks.Drink",
]
for mod, ks in exports.items():
    for k in ks:
        glue.append(f"ClubConfig.{k} = {mod}.{k}")
kept[idx:idx + 1] = glue
out = nl.join(kept)
open(path, "w", encoding="utf-8", newline="").write(out)
print("ClubConfig lines", len(L), "->", len(kept))
