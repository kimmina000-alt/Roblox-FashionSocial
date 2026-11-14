# 오픈 기념 프레임 (D-1412)

The user's drawing `opening_frame_source.png` (a 6-cut strip and a 2x2 frame) turned into the
opening event frame `opening2026` (PhotoConfig.Frames, style "art").

1. `python cut.py` — cut-out (누끼): a hand-drawn polygon per frame, removes the pink background
   (colour-near, connected to the outside) and the photo holes, keeps the biggest piece,
   opens away thin lines. Writes `strip_cut.png` / `grid_cut.png` + the hole masks.
2. `python warp.py` — straightens each frame (hole centres in line) and fits the holes to the
   game's cells (PhotoRender.newStrip: 4:3 cells, 0.35 gaps) with a piecewise-linear warp:
   holes are stretched to the cells, the border outside keeps its scale and reaches past the
   strip (ribbon, bears). The 1x4 uses rows 1, 2, 5, 6 of the strip's six.
   Writes `opening_1x4.png` / `opening_2x2.png` and `info.json` (x, y, w, h = the image's
   rectangle in strip fractions, for PhotoConfig `art[layout]`).
3. Upload both (Studio logged in as Vantablack_Dev) and put the ids + rectangles in PhotoConfig.

Uploaded 2026-11-14: 1x4 rbxassetid://98572338696618, 2x2 rbxassetid://126371730378535.
