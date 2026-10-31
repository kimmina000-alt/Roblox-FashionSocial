--!nocheck
-- 국밥집 (D-314, user 2026-10-26): an old-style 노포 gukbap restaurant on the
-- first lot north of the club, on the same sidewalk (club door → walk north).
-- Run in Edit mode AFTER build_hongdae_layout + street_dress (tools/graybox/LAYOUT.md).
-- Idempotent: rebuilds Workspace.Hongdae_Layout.Gukbap (since layout v8 the
-- lot is clear and the boundary goes round it in build_hongdae_layout).
-- Reference photos: docs/04_ART/references/gukbap_ref_classic.jpg (white sign
-- band with big red letters, aluminium sliding doors, red vinyl menu letters on
-- the glass, a cauldron by the door; inside stainless tables, round stools,
-- bright tube lights, a menu board over the kitchen).
-- No alcohol anywhere (content rules); one open dining hall, no private rooms.

local CS = game:GetService("CollectionService")
local T = workspace:FindFirstChild("Hongdae_Layout")
assert(T, "Hongdae_Layout missing: run build_hongdae_layout first")

-- the lot (world): front (street side) at x 48. Layout v8 (user map 2026-10-27:
-- "국밥집 대확장 ... 클럽 가로 길이에 맞춰서 확장"): as deep as the club is wide
-- (x 48..193), z -375..-293 between the long shop block and the club (which
-- moved 24 north); the play-area boundary is in build_hongdae_layout now
local X0, X1, Z0, Z1 = 48, 158, -375, -293 -- (east end 193 → 158, user map 2026-10-27)
local FY = 0.6 -- floor top = sidewalk top (no step at the door)
local H1 = 21 -- 1F floor to ceiling (12 → 21: as high as the club 1F, user 2026-10-27)
local H2 = 10 * H1 / 12 -- 2F (outside only); (it grows like the 1F did, 10 → 17.5, user 2026-10-27)
local K2 = H2 / 10 -- the 2F windows grow with it
local WT = 0.6 -- wall thickness
local DOOR_Z0, DOOR_Z1 = -311, -303 -- (8 wide; moved south next to the order counter, user plan 2026-10-29 (14))
-- (user plan 2026-10-29 (14)) the hall is smaller than the shell: inner walls at
-- z HZ0 (north) and x HX1 (east); the strips behind them stay empty, nothing in them
local HZ0, HX1 = -350, 134

-- old pieces ------------------------------------------------------------
local old = T:FindFirstChild("Gukbap")
if old then old:Destroy() end
local M = Instance.new("Model")
M.Name = "Gukbap"

local function part(name, size, cf, color, opt)
	local p = Instance.new((opt and opt.class) or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opt and opt.t) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt and opt.shape then p.Shape = opt.shape end
	if opt and opt.nocol then
		p.CanCollide = false
		p.CanTouch = false
	end
	if opt and opt.noshadow then p.CastShadow = false end
	p.Parent = (opt and opt.parent) or M
	return p
end
local function box(name, x0, y0, z0, x1, y1, z1, color, opt)
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local ly, hy = math.min(y0, y1), math.max(y0, y1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	return part(name, Vector3.new(hx - lx, hy - ly, hz - lz), CFrame.new((lx + hx) / 2, (ly + hy) / 2, (lz + hz) / 2), color, opt)
end
local function vcyl(name, pos, d, h, color, opt) -- pos = bottom centre
	local o = {}
	for k, v in pairs(opt or {}) do o[k] = v end
	o.shape = Enum.PartType.Cylinder
	return part(name, Vector3.new(h, d, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, o)
end
-- text on a face of a part
local function label(p, face, text, color, opt)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = (opt and opt.pps) or 40
	g.LightInfluence = (opt and opt.light) or 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	if opt and opt.bg then
		t.BackgroundColor3 = opt.bg
		t.BackgroundTransparency = 0
		t.BorderSizePixel = 0
	end
	t.Font = (opt and opt.font) or Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.LineHeight = (opt and opt.lh) or 1
	if opt and opt.align then t.TextXAlignment = opt.align end
	local pad = Instance.new("UIPadding")
	local px = (opt and opt.pad) or 0.06
	pad.PaddingLeft = UDim.new(px, 0) pad.PaddingRight = UDim.new(px, 0)
	pad.PaddingTop = UDim.new(0.08, 0) pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = t
	t.Parent = g
	return t
end

local WALL = Color3.fromRGB(236, 232, 222) -- painted plaster
local TILE2F = Color3.fromRGB(150, 92, 72) -- 2F brown tiles
local ALU = Color3.fromRGB(196, 200, 204)
local STEEL = Color3.fromRGB(188, 192, 196)
local RED = Color3.fromRGB(205, 30, 36)
local FLOOR = Color3.fromRGB(150, 146, 140)
local DARK = Color3.fromRGB(40, 40, 44)

local top1 = FY + H1 local DOOR_H = 8.1 * H1 / 12 -- (the door grows with the 1F, 8.1 → 14.2: tall avatars, user 2026-10-27)
local top2 = top1 + H2

-- floor, ceiling, roof ---------------------------------------------------
-- (interior 2026-10-29: beige stone-look tiles and a cream ceiling, like the
-- old Busan 돼지국밥 halls in the user's reference)
box("Floor", X0, 0, Z0, X1, FY, Z1, Color3.fromRGB(214, 200, 176), { material = Enum.Material.CeramicTiles })
-- (inside the walls: its ends shared the planes of the front and side walls
-- and flickered as a line across the front, user 2026-10-30)
box("Ceiling", X0 + 0.05, top1, Z0 + 0.05, X1 - 0.05, top1 + 0.6, Z1 - 0.05, Color3.fromRGB(236, 226, 204))
box("Roof", X0 - 0.3, top2, Z0 - 0.3, X1 + 0.3, top2 + 0.8, Z1 + 0.3, Color3.fromRGB(120, 120, 124), { material = Enum.Material.Concrete })
box("Parapet", X0 - 0.3, top2 + 0.8, Z0 - 0.3, X0 + 0.3, top2 + 2, Z1 + 0.3, Color3.fromRGB(120, 120, 124), { material = Enum.Material.Concrete })

-- walls: back, both sides (1F + 2F), 2F front ------------------------------
box("Wall_Back", X1 - WT, 0, Z0 + 0.03, X1, top2, Z1 - 0.03, WALL, { material = Enum.Material.Plaster }) -- (inside the side walls' ends)
-- (the side walls start behind the front walls: their faces met the front
-- walls' faces at the corner and flickered, user 2026-10-29 (17); the north
-- wall seen over the lower neighbour is brick like the 2F front)
box("Wall_N", X0 + WT, 0, Z0, X1, top2, Z0 + WT, TILE2F, { material = Enum.Material.Brick })
box("Wall_S", X0 + WT, 0, Z1 - WT, X1, top2, Z1, WALL, { material = Enum.Material.Plaster })
box("Front2F", X0, top1, Z0, X0 + WT, top2, Z1, TILE2F, { material = Enum.Material.Brick })
-- 2F windows (old aluminium frames, dark glass), outside only
for wz = Z0 + 5, Z1 - 4, 7.5 do
	box("Window2F", X0 - 0.15, top1 + 2.5 * K2, wz - 2.6, X0, top1 + 7.5 * K2, wz + 2.6, Color3.fromRGB(60, 70, 80), { material = Enum.Material.Glass, t = 0.15, nocol = true })
	box("Window2FFrame", X0 - 0.25, top1 + 2.5 * K2 - 0.2, wz - 2.8, X0 - 0.1, top1 + 2.5 * K2, wz + 2.8, ALU, { nocol = true })
	box("Window2FMullion", X0 - 0.25, top1 + 2.5 * K2, wz - 0.1, X0 - 0.1, top1 + 7.5 * K2, wz + 0.1, ALU, { nocol = true })
end

-- 1F front: wainscot, glass, aluminium posts, open sliding door -----------
local GLASS = Color3.fromRGB(170, 200, 210)
-- (the front of the empty north strip is plain wall; glass only on the hall)
-- (one piece up to the 2F wall: the seam with the sign backing showed as a line, user 2026-10-30)
box("FrontWall_N", X0, FY, Z0, X0 + WT, top1, HZ0 - 0.3, TILE2F, { material = Enum.Material.Brick })
-- a fake back door in it (closed, nothing behind), user 2026-10-29 (17)
do
	local dz, DW, DHh = -362.5, 5, 9.5
	box("FakeDoorFrame", X0 - 0.25, FY, dz - DW / 2 - 0.35, X0, FY + DHh + 0.35, dz + DW / 2 + 0.35, Color3.fromRGB(60, 62, 66), { material = Enum.Material.Metal, nocol = true })
	box("FakeDoor", X0 - 0.35, FY, dz - DW / 2, X0 - 0.25, FY + DHh, dz + DW / 2, Color3.fromRGB(110, 115, 120), { material = Enum.Material.DiamondPlate, nocol = true })
	box("FakeDoorHandle", X0 - 0.5, FY + 4.4, dz + DW / 2 - 0.9, X0 - 0.35, FY + 4.6, dz + DW / 2 - 0.4, Color3.fromRGB(200, 200, 205), { material = Enum.Material.Metal, nocol = true })
	box("FakeDoorStep", X0 - 1.2, 0, dz - DW / 2 - 0.4, X0, FY + 0.2, dz + DW / 2 + 0.4, Color3.fromRGB(150, 150, 150), { material = Enum.Material.Concrete })
end
for _, seg in ipairs({ { HZ0, DOOR_Z0 }, { DOOR_Z1, Z1 } }) do
	local a, b = seg[1], seg[2]
	box("Wainscot", X0, FY, a, X0 + WT, FY + 2.6, b, Color3.fromRGB(210, 205, 196), { material = Enum.Material.Slate })
	local g = box("FrontGlass", X0 + 0.2, FY + 2.6, a, X0 + 0.4, top1 - 3.8, b, GLASS, { material = Enum.Material.Glass, t = 0.55 })
	box("GlassTopRail", X0, top1 - 3.8, a, X0 + WT, top1 - 3.4, b, ALU) -- (the glass runs up under the sign band)
	box("GlassBottomRail", X0, FY + 2.5, a, X0 + WT, FY + 2.7, b, ALU)
	-- red vinyl menu letters on the glass, read from the street (face -X = Left)
	-- (raised clear of the cauldrons, user 2026-10-29 (17))
	local vinyl = box("GlassLetters", X0 + 0.05, FY + 9.6, a + 0.8, X0 + 0.1, FY + 12.4, b - 0.8, Color3.new(1, 1, 1), { t = 1, nocol = true, noshadow = true })
	vinyl.CanQuery = false
	label(vinyl, Enum.NormalId.Left, if a == HZ0 then "돼지국밥 · 순대국밥" else "소고기국밥 · 수육", RED, { pps = 30, light = 1 })
	_ = g
end
for _, pz in ipairs({ HZ0, DOOR_Z0, DOOR_Z1, Z1 - 0.3 }) do
	box("AluPost", X0 - 0.1, FY, pz - 0.3, X0 + WT, top1, pz + 0.3, ALU)
end
box("DoorHeader", X0, FY + DOOR_H + 0.1, DOOR_Z0, X0 + WT, FY + DOOR_H + 0.5, DOOR_Z1, ALU)
box("DoorTransom", X0 + 0.2, FY + DOOR_H + 0.5, DOOR_Z0, X0 + 0.4, top1 - 3.8, DOOR_Z1, GLASS, { material = Enum.Material.Glass, t = 0.55 })
box("DoorTransomRail", X0, top1 - 3.8, DOOR_Z0, X0 + WT, top1 - 3.4, DOOR_Z1, ALU)
-- the sliding door stands open: both glass leaves pushed to the north side
for k = 0, 1 do
	local x = X0 + 0.9 + k * 0.25
	box("DoorLeaf", x, FY, DOOR_Z0 - 2.9, x + 0.12, FY + DOOR_H, DOOR_Z0 + 0.1, GLASS, { material = Enum.Material.Glass, t = 0.5, nocol = true })
	box("DoorLeafFrame", x - 0.02, FY, DOOR_Z0 - 2.95, x + 0.14, FY + DOOR_H + 0.05, DOOR_Z0 - 2.75, ALU, { nocol = true })
end
-- a short 1F wall stub above the glass so the sign has a backing
box("SignBacking", X0, top1 - 3.4, HZ0 - 0.3, X0 + WT, top1, Z1, TILE2F, { material = Enum.Material.Brick }) -- (brick: it shows over the north strip now, 2026-10-29 (17))

-- the sign band: the user's yellow "오후할매 돼지국밥" sign (2026-10-29 (14),
-- docs/04_ART/textures/gukbap/sign_band.png) in the middle of a yellow band as
-- long as the front, taller than before so it reads from the street; the
-- vertical sign at the corner carries the user's vertical picture
local SIGN_YELLOW = Color3.fromRGB(248, 219, 1)
local IMG_SIGN = "rbxassetid://99001432106647" -- (the user's sign for this band, 1700 x 200, 2026-10-29 (17))
local IMG_SIGN_V = "rbxassetid://83197994918392"
local BAND_Y0, BAND_Y1 = top1 - 3.4, top1 + 3.2
-- (only over the hall glass, HZ0..Z1, user 2026-10-29 (16): 56.8 x 6.6 studs;
-- the user makes a picture of that shape, until then the old one in the middle)
local band = box("SignBand", X0 - 1.1, BAND_Y0, HZ0, X0, BAND_Y1, Z1 - 0.2, SIGN_YELLOW)
do
	local h = BAND_Y1 - BAND_Y0 - 0.2
	local w = h * 1700 / 200 -- the picture's shape
	local mid = (HZ0 + Z1 - 0.2) / 2
	local img = box("SignBandImage", X0 - 1.15, BAND_Y0 + 0.1, mid - w / 2, X0 - 1.1, BAND_Y1 - 0.1, mid + w / 2, SIGN_YELLOW, { nocol = true, noshadow = true })
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Left
	d.Texture = IMG_SIGN
	d.Parent = img
end
local bandLight = Instance.new("SurfaceLight")
bandLight.Face = Enum.NormalId.Left
bandLight.Range = 16
bandLight.Brightness = 1.2
bandLight.Angle = 100
bandLight.Color = Color3.fromRGB(255, 248, 236)
bandLight.Parent = band
-- a vertical sign sticking out at the club-side corner (seen along the sidewalk)
local vs = box("VerticalSign", X0 - 3.6, top1 + 3.6, Z1 - 1.0, X0 - 0.6, top1 + 3.6 + 3 * 609 / 184, Z1 - 0.4, SIGN_YELLOW)
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local d = Instance.new("Decal")
	d.Face = face
	d.Texture = IMG_SIGN_V
	d.Parent = vs
end
local vsLight = Instance.new("PointLight")
vsLight.Range = 10
vsLight.Brightness = 0.8
vsLight.Color = Color3.fromRGB(255, 240, 230)
vsLight.Parent = vs
box("VerticalSignArm", X0 - 0.6, top1 + 7.4, Z1 - 0.8, X0, top1 + 7.8, Z1 - 0.6, DARK, { nocol = true })
-- outside: two big cauldrons on brick stoves with steam (2.5 times bigger,
-- user 2026-10-29 (14); 80 % of that and both stoves the same height again,
-- 2026-10-29 (16): K 2.0), AC unit, standing sign -----------
local function cauldron(cx, cz, stoveH)
	local K = 2.0
	box("Stove", cx - 1.6 * K, FY, cz - 1.6 * K, cx + 1.6 * K, FY + stoveH, cz + 1.6 * K, Color3.fromRGB(150, 80, 60), { material = Enum.Material.Brick })
	local y = FY + stoveH
	vcyl("Gamasot", Vector3.new(cx, y, cz), 3.4 * K, 1.6 * K, Color3.fromRGB(30, 30, 32), { material = Enum.Material.Metal })
	vcyl("GamasotRim", Vector3.new(cx, y + 1.4 * K, cz), 3.8 * K, 0.25 * K, Color3.fromRGB(24, 24, 26), { material = Enum.Material.Metal })
	local lid = vcyl("GamasotLid", Vector3.new(cx, y + 1.65 * K, cz), 3.0 * K, 0.4 * K, Color3.fromRGB(70, 50, 34), { material = Enum.Material.Wood })
	vcyl("LidKnob", Vector3.new(cx, y + 2.05 * K, cz), 0.5 * K, 0.35 * K, Color3.fromRGB(50, 36, 26), { material = Enum.Material.Wood })
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * K), NumberSequenceKeypoint.new(1, 3.2 * K) })
	steam.Lifetime = NumberRange.new(2, 3)
	steam.Rate = 6
	steam.Speed = NumberRange.new(1.5 * K, 2.5 * K)
	steam.SpreadAngle = Vector2.new(15, 15)
	steam.LightInfluence = 0.6
	steam.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis (local X) points up
	steam.Parent = lid
end
do
	-- on the sidewalk in front of the hall glass, north of the door, 14 apart
	-- (stoves half as high, the north one a little nearer the other, user 2026-10-29 (17))
	cauldron(X0 - 4.4, -342.5, 2.2)
	cauldron(X0 - 4.4, -331, 2.2)
	-- AC outdoor unit against the 1F glass wainscot, south of the door
	box("ACUnit", X0 - 1.4, FY, Z1 - 6.5, X0 - 0.1, FY + 2.4, Z1 - 3.3, Color3.fromRGB(232, 232, 228))
	local fan = vcyl("ACFan", Vector3.new(X0 - 1.42, FY + 1.2, Z1 - 4.9), 1.8, 0.05, Color3.fromRGB(70, 70, 74), { nocol = true })
	fan.CFrame = CFrame.new(X0 - 1.42, FY + 1.2, Z1 - 4.9)
	-- A-frame standing sign by the door
	-- (two boards leaning together into an A, user 2026-10-29 (17))
	local lean = math.rad(12)
	local dx = 1.8 * math.sin(lean)
	local front = part("StandSign", Vector3.new(0.2, 3.6, 2.2), CFrame.new(X0 - 2.4 - dx, FY + 1.76, DOOR_Z1 + 1.8) * CFrame.Angles(0, 0, -lean), RED)
	label(front, Enum.NormalId.Left, "24시간\n영업", Color3.new(1, 1, 1), { pps = 40 })
	local back = part("StandSign", Vector3.new(0.2, 3.6, 2.2), CFrame.new(X0 - 2.4 + dx, FY + 1.76, DOOR_Z1 + 1.8) * CFrame.Angles(0, 0, lean), RED)
	label(back, Enum.NormalId.Right, "국밥\n💰20", Color3.new(1, 1, 1), { pps = 40 })
end

-- inside ---------------------------------------------------------------------
-- (user 2026-10-29: the hall like an old Busan 돼지국밥 restaurant, reference
-- photos seen on DiningCode: hangul-pattern wallpaper over a dark wood
-- wainscot, handwritten guest notes stuck all along the walls, a white menu
-- board with a bowl picture, wall fans, a TV, a standing aircon, a big plant
-- by the kitchen, round downlights in a cream ceiling, light wood tables with
-- black legs and wooden chairs with cream cushions. No private room, no
-- alcohol. Images: tools/art/gukbap_interior_textures.ps1)
local IMG_WALLPAPER = "rbxassetid://116206010315485"
local IMG_NOTES = "rbxassetid://73936729248802"
local IMG_MENU = "rbxassetid://80482796040073" -- (the user's menu picture, 2026-10-29 (14); the drinks column and the shop logo cut off: no alcohol, no real brand)
local WOOD_DARK = Color3.fromRGB(112, 72, 44)
local WOOD_RAIL = Color3.fromRGB(150, 100, 60)
local RAIL_Y = FY + 6 -- wainscot top
local function tex(p, face, id, u, v)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	t.Parent = p
	return t
end
-- (user plan 2026-10-29 (14)) the hall is X0..HX1 x HZ0..Z1. The kitchen sits
-- in its north-east corner (x KX..HX1, z HZ0..KZ) behind a pass counter, and
-- runs on south as a small back room east of the aircon (x KX2..HX1); the
-- order counter stands by the door. The strips north of HZ0 and east of HX1
-- are empty.
local KX, KZ, KX2 = 121, -312.5, 128.7
-- inner walls, full height
box("InnerWall_N", X0 + WT, 0, HZ0, HX1 + WT, top1, HZ0 + WT, WALL, { material = Enum.Material.Plaster })
box("InnerWall_E", HX1, 0, HZ0, HX1 + WT, top1, Z1 - WT, WALL, { material = Enum.Material.Plaster })
box("KitchenWall_S", KX, 0, KZ - WT, KX2 + WT, top1, KZ, WALL, { material = Enum.Material.Plaster })
box("KitchenWall_W", KX2, 0, KZ, KX2 + WT, top1, Z1 - WT, WALL, { material = Enum.Material.Plaster })
-- the pass into the kitchen: a steel counter with the wall above it, open
-- from 3.8 to 9; north of it the staff way in under a short cloth (노렌)
local PASS_Z0 = -330
box("PassCounter", KX, FY, PASS_Z0, KX + 1.6, FY + 3.6, KZ - WT, STEEL, { material = Enum.Material.DiamondPlate })
box("PassCounterTop", KX - 0.3, FY + 3.6, PASS_Z0, KX + 1.9, FY + 3.8, KZ - WT, Color3.fromRGB(214, 218, 222), { material = Enum.Material.Metal })
box("PassWallUpper", KX, FY + 9, PASS_Z0, KX + WT, top1, KZ - WT, WALL, { material = Enum.Material.Plaster })
box("PassPost", KX, FY, PASS_Z0 - WT, KX + WT, top1, PASS_Z0, WALL, { material = Enum.Material.Plaster })
box("Noren", KX - 0.05, FY + 10, HZ0 + WT, KX + 0.05, FY + 14, PASS_Z0 - WT, Color3.fromRGB(40, 50, 90), { material = Enum.Material.Fabric, nocol = true })
-- the wall comes down over the staff way to the noren (the kitchen ceiling
-- showed above it, user 2026-10-29 (17))
box("StaffWayHeader", KX, FY + 14, HZ0 + WT, KX + WT, top1, PASS_Z0 - WT, WALL, { material = Enum.Material.Plaster })
do
	local wp = box("Wallpaper", KX - 0.05, FY + 14, HZ0 + WT, KX, top1, PASS_Z0 - WT, Color3.fromRGB(226, 216, 192), { nocol = true, noshadow = true })
	tex(wp, Enum.NormalId.Left, IMG_WALLPAPER, 6, 6)
end
-- walls: each run = {x0, z0, x1, z1, face into the hall, outward normal}
local runs = {
	{ X0 + WT, HZ0 + WT, KX, HZ0 + WT, Enum.NormalId.Back, Vector3.new(0, 0, -1) }, -- inner north wall, faces +z
	{ X0 + WT, Z1 - WT, KX2, Z1 - WT, Enum.NormalId.Front, Vector3.new(0, 0, 1) }, -- south wall, faces -z
}
for _, r in ipairs(runs) do
	local x0, z0, x1, z1, face, out = r[1], r[2], r[3], r[4], r[5], r[6]
	local zin = z0 - out.Z * 0.15 -- 0.15 in front of the wall
	box("Wainscot_In", x0, FY, z0, x1, RAIL_Y, zin, WOOD_DARK, { material = Enum.Material.WoodPlanks, nocol = true })
	box("ChairRail", x0, RAIL_Y, z0, x1, RAIL_Y + 0.35, z0 - out.Z * 0.4, WOOD_RAIL, { material = Enum.Material.Wood, nocol = true })
	local wp = box("Wallpaper", x0, RAIL_Y + 0.35, z0, x1, top1, z0 - out.Z * 0.05, Color3.fromRGB(226, 216, 192), { nocol = true, noshadow = true })
	tex(wp, face, IMG_WALLPAPER, 6, 6)
	-- two rows of guest notes over the rail
	for row = 0, 1 do
		local y0 = RAIL_Y + 0.6 + row * 3.4
		local n = box("GuestNotes", x0 + 1, y0, z0 - out.Z * 0.06, x1 - 2, y0 + 3, z0 - out.Z * 0.08, Color3.new(1, 1, 1), { t = 1, nocol = true, noshadow = true })
		n.CanQuery = false
		local t = tex(n, face, IMG_NOTES, 12, 3)
		t.OffsetStudsU = row * 5.5
	end
	-- a cornice pipe along the top, as in the photo
	part("CornicePipe", Vector3.new(x1 - x0, 0.4, 0.4), CFrame.new((x0 + x1) / 2, top1 - 0.5, z0 - out.Z * 0.35), Color3.fromRGB(230, 222, 204), { shape = Enum.PartType.Cylinder, nocol = true, noshadow = true })
end
-- the kitchen walls' hall faces: wallpaper (the pass wall above the opening,
-- the short south wall, the back-room wall by the aircon)
do
	local function paper(x0, y0, z0, x1, y1, z1, face, u)
		local wp = box("Wallpaper", x0, y0, z0, x1, y1, z1, Color3.fromRGB(226, 216, 192), { nocol = true, noshadow = true })
		tex(wp, face, IMG_WALLPAPER, u or 6, 6)
	end
	paper(KX - 0.05, FY + 9, PASS_Z0, KX, top1, KZ - WT, Enum.NormalId.Left)
	paper(KX - 0.05, FY + 3.8, PASS_Z0 - WT, KX, top1, PASS_Z0, Enum.NormalId.Left)
	paper(KX, FY, KZ, KX2, top1, KZ + 0.05, Enum.NormalId.Back)
	paper(KX2 - 0.05, FY, KZ, KX2, top1, Z1 - WT, Enum.NormalId.Left)
end
-- round downlights in rows over the hall (one in three carries a light), a
-- few plain tube lights over the kitchen
local nLight = 0
for lz = HZ0 + 6, Z1 - 5, 10 do
	for lx = X0 + 6, KX - 3, 11 do
		local d = part("Downlight", Vector3.new(0.1, 1.3, 1.3), CFrame.new(lx, top1 - 0.04, lz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 250, 238), { shape = Enum.PartType.Cylinder, material = Enum.Material.Neon, nocol = true, noshadow = true })
		nLight += 1
		if nLight % 3 == 1 then
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Left -- the cylinder's axis (local X) is turned to point down
			l.Range = 28
			l.Brightness = 1.4
			l.Angle = 120
			l.Color = Color3.fromRGB(255, 244, 222)
			l.Parent = d
		end
	end
end
for _, lz in ipairs({ -342, -324, -303 }) do
	local tube = box("TubeLight", (KX2 + HX1) / 2 - 2.2, top1 - 0.25, lz - 0.25, (KX2 + HX1) / 2 + 2.2, top1, lz + 0.25, Color3.fromRGB(248, 250, 255), { material = Enum.Material.Neon, nocol = true, noshadow = true })
	local l = Instance.new("SurfaceLight")
	l.Face = Enum.NormalId.Bottom
	l.Range = 18
	l.Brightness = 0.8
	l.Color = Color3.fromRGB(245, 248, 255)
	l.Parent = tube
end
-- wall fans: a white motor and a grey cage, high on both long walls, clear
-- of the menu boards, the closed door and the TV
for ri, r in ipairs(runs) do
	local out = r[6]
	for _, fx in ipairs(if ri == 1 then { 64, 104 } else { 60, 98 }) do
		local zw = r[2] - out.Z * 0.4
		box("FanMount", fx - 0.4, FY + 12.4, zw, fx + 0.4, FY + 13.6, zw - out.Z * 0.5, Color3.fromRGB(240, 240, 236), { nocol = true })
		part("FanMotor", Vector3.new(1.2, 1, 1), CFrame.new(fx, FY + 13, zw - out.Z * 1.2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(245, 245, 242), { shape = Enum.PartType.Cylinder, nocol = true })
		part("FanCage", Vector3.new(0.5, 3.2, 3.2), CFrame.new(fx, FY + 13, zw - out.Z * 2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(150, 152, 156), { shape = Enum.PartType.Cylinder, t = 0.45, nocol = true, noshadow = true })
	end
end
-- the menu board, twice: the user's picture (2.2 : 1) high on the inner north
-- wall and on the south wall, both looking into the hall
local function menuBoard(cx, zw, face, out)
	local H = 6.2
	local W = H * 1300 / 592
	local y0 = FY + 12.6
	box("MenuFrame", cx - W / 2 - 0.25, y0 - 0.25, zw, cx + W / 2 + 0.25, y0 + H + 0.25, zw - out * 0.12, Color3.fromRGB(70, 50, 36), { material = Enum.Material.Wood, nocol = true })
	local b = box("MenuBoard", cx - W / 2, y0, zw - out * 0.12, cx + W / 2, y0 + H, zw - out * 0.18, Color3.fromRGB(240, 232, 214), { nocol = true })
	local d = Instance.new("Decal")
	d.Face = face
	d.Texture = IMG_MENU
	d.Parent = b
end
menuBoard(89, HZ0 + WT + 0.1, Enum.NormalId.Back, -1)
menuBoard(77, Z1 - WT - 0.1, Enum.NormalId.Front, 1)
-- a closed door in the inner north wall (the empty strip behind it is not used)
do
	local dx, zw = 113.4, HZ0 + WT
	box("ClosedDoorFrame", dx - 2.8, FY, zw, dx + 2.8, FY + 14.6, zw + 0.25, Color3.fromRGB(60, 42, 30), { material = Enum.Material.Wood })
	box("ClosedDoor", dx - 2.5, FY, zw + 0.25, dx + 2.5, FY + 14.3, zw + 0.35, Color3.fromRGB(110, 76, 50), { material = Enum.Material.WoodPlanks })
	vcyl("ClosedDoorKnob", Vector3.new(dx + 1.8, FY + 6.5, zw + 0.45), 0.4, 0.25, Color3.fromRGB(200, 190, 160), { material = Enum.Material.Metal, nocol = true }).CFrame = CFrame.new(dx + 1.8, FY + 6.5, zw + 0.5) * CFrame.Angles(0, math.rad(90), 0)
	local s = box("ClosedDoorSign", dx - 1.6, FY + 10, zw + 0.36, dx + 1.6, FY + 11.2, zw + 0.4, Color3.fromRGB(250, 250, 246), { nocol = true })
	label(s, Enum.NormalId.Back, "관계자 외 출입금지", Color3.fromRGB(150, 30, 30), { pps = 40, font = Enum.Font.GothamBold })
end
-- a TV high on the south wall, facing the hall
do
	local zw = Z1 - WT - 0.2
	box("TVFrame", 108.5, FY + 11, zw - 0.4, 117.5, FY + 16, zw, Color3.fromRGB(20, 20, 22), { nocol = true })
	local s = box("TVScreen", 108.8, FY + 11.3, zw - 0.45, 117.2, FY + 15.7, zw - 0.4, Color3.fromRGB(70, 120, 170), { material = Enum.Material.Neon, nocol = true, noshadow = true })
	s.Transparency = 0.35
end
-- standing aircon against the back-room wall, facing the hall; the cafe's
-- potted plant next to it (ServerStorage.ArtAssets.CafePotPlant)
box("StandAC", KX2 - 2.6, FY, -304, KX2, FY + 9, -301, Color3.fromRGB(242, 242, 240))
for gy = FY + 5, FY + 8.2, 0.5 do
	box("StandACGrille", KX2 - 2.65, gy, -303.7, KX2 - 2.6, gy + 0.2, -301.3, Color3.fromRGB(190, 192, 196), { nocol = true })
end
do
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local plant = art and art:FindFirstChild("CafePotPlant")
	-- (four of them, a little bigger, the black stand sunk into the floor so
	-- the pot sits on it, user 2026-10-29 (17))
	if plant then
		for _, at in ipairs({ Vector2.new(KX2 - 2.4, -308.4), Vector2.new(124, -297.6), Vector2.new(54, -347.4), Vector2.new(52.6, -296.6) }) do
			local m = plant:Clone()
			m.Name = "CafePotPlant"
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") then d:Destroy() end
				if d:IsA("BasePart") then d.Anchored = true end
			end
			m:ScaleTo(m:GetScale() * 1.2)
			-- the pot's bottom in world terms (the legs hang below it)
			local potBottom = math.huge
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Pot" then
					local c, h = d.CFrame, d.Size / 2
					potBottom = math.min(potBottom, d.Position.Y - (math.abs(c.XVector.Y) * h.X + math.abs(c.YVector.Y) * h.Y + math.abs(c.ZVector.Y) * h.Z))
				end
			end
			local cf = m:GetBoundingBox()
			m:PivotTo(m:GetPivot() + Vector3.new(at.X - cf.Position.X, FY - potBottom, at.Y - cf.Position.Z))
			m.Parent = M
		end
	end
end
-- the kitchen: slate floor, a range with stock pots along the inner east
-- wall (on into the back room), a fridge at the north end, bowls on the pass
box("KitchenFloor", KX, FY, HZ0 + WT, HX1, FY + 0.05, KZ - WT, Color3.fromRGB(120, 118, 114), { material = Enum.Material.Slate, nocol = true })
box("KitchenFloor", KX2 + WT, FY, KZ - WT, HX1, FY + 0.05, Z1 - WT, Color3.fromRGB(120, 118, 114), { material = Enum.Material.Slate, nocol = true })
box("Range", HX1 - 3, FY, HZ0 + 4, HX1, FY + 3, Z1 - 3, Color3.fromRGB(70, 70, 74), { material = Enum.Material.Metal })
for pz = HZ0 + 7, Z1 - 5, 6 do
	local pot = vcyl("StockPot", Vector3.new(HX1 - 1.5, FY + 3, pz), 2.6, 2.6, Color3.fromRGB(205, 208, 212), { material = Enum.Material.Metal })
	local st = Instance.new("ParticleEmitter")
	st.Texture = "rbxasset://textures/particles/smoke_main.dds"
	st.Color = ColorSequence.new(Color3.fromRGB(250, 250, 250))
	st.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	st.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	st.Lifetime = NumberRange.new(1.5, 2.5)
	st.Rate = 4
	st.Speed = NumberRange.new(1, 2)
	st.LightInfluence = 0.5
	st.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis is local X (up)
	st.Parent = pot
end
box("KitchenFridge", KX + 2, FY, HZ0 + WT, HX1 - 3.2, FY + 11, HZ0 + WT + 2.6, Color3.fromRGB(235, 236, 238), { material = Enum.Material.Metal })
for bz = PASS_Z0 + 2, KZ - 3, 4 do
	for k = 0, 2 do
		vcyl("Ttukbaegi", Vector3.new(KX + 0.9, FY + 3.8 + k * 0.55, bz), 1.2, 0.5, Color3.fromRGB(70, 46, 38), { material = Enum.Material.Slate, nocol = true })
	end
end

-- the order counter by the door (L-shaped, user plan): a long arm along the
-- hall from the north and a short arm toward the front glass. "주문하기" opens
-- the 국밥집 menu (SnackService, D-317)
do
	-- (smaller, user 2026-10-29 (17): the long arm 8 long, the short one to x 62)
	local CZ0, CZ1, AX = -325, -317.4, 58.4
	box("OrderCounter", AX, FY, CZ0, AX + 3.6, FY + 3.6, CZ1, WOOD_DARK, { material = Enum.Material.Wood })
	-- (the short arm runs right up to the front glass, user 2026-10-29 (16);
	-- the order point, the till and the sign are on it, seen straight from the door)
	local arm = box("OrderCounterArm", X0 + WT, FY, -321, AX, FY + 3.6, CZ1, WOOD_DARK, { material = Enum.Material.Wood })
	CS:AddTag(arm, "GukbapCounter")
	arm:SetAttribute("Shop", "Gukbap")
	CS:AddTag(arm, "SnackShop")
	box("CounterTop", AX - 0.3, FY + 3.6, CZ0 - 0.3, AX + 3.9, FY + 3.85, CZ1 + 0.3, Color3.fromRGB(214, 218, 222), { material = Enum.Material.Marble })
	box("CounterTop", X0 + WT, FY + 3.6, -321.3, AX - 0.3, FY + 3.85, CZ1 + 0.3, Color3.fromRGB(214, 218, 222), { material = Enum.Material.Marble })
	-- the till: the OH24 one (ServerStorage.ArtAssets.Register37), keys to the
	-- staff side (north), else a dark block
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local reg = art and art:FindFirstChild("Register37")
	local RX, RZ = 53.6, -319.2
	if reg then
		local r = reg:Clone()
		r:ScaleTo(r:GetScale() * 1.5) -- (the cafe till's size, user 2026-10-31)
		local cf, size = r:GetBoundingBox()
		r:PivotTo(CFrame.new(RX, FY + 3.85 + size.Y / 2, RZ) * CFrame.Angles(0, math.pi, 0) * cf:ToObjectSpace(r:GetPivot()))
		for _, p in ipairs(r:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
			if p:IsA("LuaSourceContainer") then p:Destroy() end
		end
		r.Name = "Register37"
		r.Parent = M
	else
		box("CashRegister", RX - 0.9, FY + 3.85, RZ - 1, RX + 0.9, FY + 4.9, RZ + 1, Color3.fromRGB(40, 40, 44))
	end
	-- "주문하는 곳" standing next to the till, its face to the door (south)
	local s = box("OrderSign", RX + 2, FY + 3.85, -318.6, RX + 5.4, FY + 5.9, -318.4, Color3.fromRGB(250, 250, 246), { nocol = true })
	label(s, Enum.NormalId.Back, "주문하는 곳", RED, { pps = 40, font = Enum.Font.GothamBold })
end
-- water purifier + cups at the west end of the inner north wall
box("WaterPurifier", X0 + 1.2, FY, HZ0 + WT, X0 + 3, FY + 4.2, HZ0 + WT + 1.6, Color3.fromRGB(240, 240, 244))
box("PurifierPanel", X0 + 1.4, FY + 3.2, HZ0 + WT + 1.6, X0 + 2.8, FY + 3.8, HZ0 + WT + 1.65, Color3.fromRGB(60, 140, 220), { material = Enum.Material.Neon, nocol = true })
-- a framed "since" poster on the inner north wall
local poster = box("Poster", 58, FY + 7, HZ0 + WT, 63, FY + 10, HZ0 + WT + 0.1, Color3.fromRGB(250, 240, 210), { nocol = true })
label(poster, Enum.NormalId.Back, "SINCE 1985\n가마솥 24시간", Color3.fromRGB(120, 40, 30), { pps = 40, font = Enum.Font.GothamBold })
-- tables: stainless tops, four round stools each, kimchi jars on top ------
local function gukbapTable(tx, tz)
	-- (user 2026-10-27: bigger tops, the stools further out; the kimchi jars are
	-- gone, the wooden block is the tissue box. scale_furniture then grows the
	-- whole group 1.5x)
	local HX, HZ = 1.9, 2.9 -- half the top
	-- (2026-10-29) light wood top on four black legs, as in the reference hall
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		local lx, lz = tx + c[1] * (HX - 0.25), tz + c[2] * (HZ - 0.25)
		box("TableLeg", lx - 0.1, FY, lz - 0.1, lx + 0.1, FY + 2.3, lz + 0.1, Color3.fromRGB(28, 28, 30))
	end
	local top = box("TableTop", tx - HX, FY + 2.3, tz - HZ, tx + HX, FY + 2.5, tz + HZ, Color3.fromRGB(226, 198, 150), { material = Enum.Material.Wood })
	CS:AddTag(top, "GukbapTable")
	-- tissue box: the user's pick (#3 of the restaurant sheet) retextured as
	-- wood (ServerStorage.ArtAssets.TissueBoxWood), else a plain wooden box
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local tissue = art and art:FindFirstChild("TissueBoxWood")
	if tissue then
		local m = tissue:Clone()
		m.Name = "TissueBox"
		local _, sz = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * 0.6 / sz.Y)
		local _, sz2 = m:GetBoundingBox()
		m:PivotTo(CFrame.new(tx - HX + 0.5, FY + 2.5 + sz2.Y / 2, tz - HZ + 0.6) * CFrame.Angles(0, math.rad(90), 0))
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.Name = "TissueBox" end
		end
		m.Parent = M
	else
		box("TissueBox", tx - HX + 0.2, FY + 2.5, tz - HZ + 0.3, tx - HX + 0.8, FY + 3.0, tz - HZ + 0.9, Color3.fromRGB(150, 110, 70), { material = Enum.Material.Wood, nocol = true })
	end
	for _, s in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		-- (HX + 1.0: the chair frame must come within 0.6 of a table leg, or
		-- scale_furniture grows each chair alone and it ends up under the top)
		local sx, sz = s[1] * (HX + 1.0), s[2] * 1.4
		-- (2026-10-29) a wooden chair with a cream cushion and a bent-wood back
		-- on the side away from the table (was a red round stool). The Seat is
		-- an invisible upright block on it (a Seat takes the sitter's up from
		-- its own axes, phone test 2026-10-26)
		local cx, cz = tx + sx, tz + sz
		local CHAIR = Color3.fromRGB(128, 84, 50)
		-- (user pick 2026-10-30, candidate C4 "Стул" by TimaYT_2022: a bent-wood
		-- chair, 2 meshes, ServerStorage.ArtAssets.GukbapChairC4, pivot on the
		-- floor, its back on -X). The old box chair stays as the fallback.
		local c4 = art and art:FindFirstChild("GukbapChairC4")
		if c4 then
			local m = c4:Clone()
			m.Name = "Chair"
			-- scaled so the seat stands like the old one (3.27 tall → 3.5); the back
			-- away from the table: -X points out along s[1]
			local _, sz0 = m:GetBoundingBox()
			m:ScaleTo(m:GetScale() * 3.5 / sz0.Y)
			m:PivotTo(CFrame.new(cx, FY, cz) * CFrame.Angles(0, if s[1] < 0 then 0 else math.pi, 0))
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.Name = "Chair" end
			end
			-- an invisible block for the seat's collision (the mesh hull is the whole chair)
			box("Chair", cx - 0.68, FY, cz - 0.68, cx + 0.68, FY + 1.5, cz + 0.68, CHAIR, { t = 1, noshadow = true })
			m.Parent = M
		else
			box("Chair", cx - 0.68, FY + 1.18, cz - 0.68, cx + 0.68, FY + 1.3, cz + 0.68, CHAIR, { material = Enum.Material.Wood })
			box("Chair", cx - 0.62, FY + 1.3, cz - 0.62, cx + 0.62, FY + 1.5, cz + 0.62, Color3.fromRGB(236, 228, 210), { material = Enum.Material.Fabric })
			for _, l in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
				local lx, lz = cx + l[1] * 0.55, cz + l[2] * 0.55
				box("Chair", lx - 0.07, FY, lz - 0.07, lx + 0.07, FY + 1.18, lz + 0.07, CHAIR, { material = Enum.Material.Wood, nocol = true })
			end
			local bx = cx + s[1] * 0.6 -- the back, on the far side from the table
			box("Chair", bx - 0.08, FY + 1.5, cz - 0.6, bx + 0.08, FY + 3.5, cz + 0.6, CHAIR, { material = Enum.Material.Wood, nocol = true })
		end
		local seat = Instance.new("Seat")
		seat.Name = "StoolSeat"
		seat.Anchored = true
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Size = Vector3.new(1.2, 0.2, 1.2)
		seat.CFrame = CFrame.lookAt(Vector3.new(tx + sx, FY + 1.6, tz + sz), Vector3.new(tx, FY + 1.6, tz + sz))
		seat.Parent = M
	end
end
-- (user plan 2026-10-29 (14)) nine tables: three along the north wall, two
-- in the middle, four along the south wall
for _, p in ipairs({ { 68.5, -344.5 }, { 86, -344.5 }, { 102, -344.5 }, { 86, -332 }, { 102, -332 }, { 71.3, -303 }, { 85.6, -303 }, { 98.4, -303 }, { 112, -303 } }) do
	gukbapTable(p[1], p[2])
end

M.Parent = T
local n = 0
for _, d in ipairs(M:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return "gukbap built, parts " .. n
