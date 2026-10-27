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
local DOOR_Z0, DOOR_Z1 = -338, -330 -- (in the middle of the long front, 8 wide)

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
box("Floor", X0, 0, Z0, X1, FY, Z1, FLOOR, { material = Enum.Material.Slate })
box("Ceiling", X0, top1, Z0, X1, top1 + 0.6, Z1, Color3.fromRGB(244, 244, 240))
box("Roof", X0 - 0.3, top2, Z0 - 0.3, X1 + 0.3, top2 + 0.8, Z1 + 0.3, Color3.fromRGB(120, 120, 124), { material = Enum.Material.Concrete })
box("Parapet", X0 - 0.3, top2 + 0.8, Z0 - 0.3, X0 + 0.3, top2 + 2, Z1 + 0.3, Color3.fromRGB(120, 120, 124), { material = Enum.Material.Concrete })

-- walls: back, both sides (1F + 2F), 2F front ------------------------------
box("Wall_Back", X1 - WT, 0, Z0, X1, top2, Z1, WALL, { material = Enum.Material.Plaster })
box("Wall_N", X0, 0, Z0, X1, top2, Z0 + WT, WALL, { material = Enum.Material.Plaster })
box("Wall_S", X0, 0, Z1 - WT, X1, top2, Z1, WALL, { material = Enum.Material.Plaster })
box("Front2F", X0, top1, Z0, X0 + WT, top2, Z1, TILE2F, { material = Enum.Material.Brick })
-- 2F windows (old aluminium frames, dark glass), outside only
for wz = Z0 + 5, Z1 - 4, 7.5 do
	box("Window2F", X0 - 0.15, top1 + 2.5 * K2, wz - 2.6, X0, top1 + 7.5 * K2, wz + 2.6, Color3.fromRGB(60, 70, 80), { material = Enum.Material.Glass, t = 0.15, nocol = true })
	box("Window2FFrame", X0 - 0.25, top1 + 2.5 * K2 - 0.2, wz - 2.8, X0 - 0.1, top1 + 2.5 * K2, wz + 2.8, ALU, { nocol = true })
	box("Window2FMullion", X0 - 0.25, top1 + 2.5 * K2, wz - 0.1, X0 - 0.1, top1 + 7.5 * K2, wz + 0.1, ALU, { nocol = true })
end

-- 1F front: wainscot, glass, aluminium posts, open sliding door -----------
local GLASS = Color3.fromRGB(170, 200, 210)
for _, seg in ipairs({ { Z0, DOOR_Z0 }, { DOOR_Z1, Z1 } }) do
	local a, b = seg[1], seg[2]
	box("Wainscot", X0, FY, a, X0 + WT, FY + 2.6, b, Color3.fromRGB(210, 205, 196), { material = Enum.Material.Slate })
	local g = box("FrontGlass", X0 + 0.2, FY + 2.6, a, X0 + 0.4, top1 - 3.8, b, GLASS, { material = Enum.Material.Glass, t = 0.55 })
	box("GlassTopRail", X0, top1 - 3.8, a, X0 + WT, top1 - 3.4, b, ALU) -- (the glass runs up under the sign band)
	box("GlassBottomRail", X0, FY + 2.5, a, X0 + WT, FY + 2.7, b, ALU)
	-- red vinyl menu letters on the glass, read from the street (face -X = Left)
	local vinyl = box("GlassLetters", X0 + 0.05, FY + 4.6, a + 0.8, X0 + 0.1, FY + 7.4, b - 0.8, Color3.new(1, 1, 1), { t = 1, nocol = true, noshadow = true })
	vinyl.CanQuery = false
	label(vinyl, Enum.NormalId.Left, if a == Z0 then "돼지국밥 · 순대국밥" else "소고기국밥 · 수육", RED, { pps = 30, light = 1 })
	_ = g
end
for _, pz in ipairs({ Z0 + 0.3, DOOR_Z0, DOOR_Z1, Z1 - 0.3 }) do
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
box("SignBacking", X0, top1 - 3.4, Z0, X0 + WT, top1, Z1, WALL, { material = Enum.Material.Plaster })

-- the big sign band: a lit white box with big red letters. The faces are
-- SurfaceGuis that ignore the light (LightInfluence 0), so the box looks lit
-- at night and the letters stay readable; Neon washed the letters out in the
-- bloom (first try 2026-10-26). A SurfaceLight throws its light on the sidewalk.
local SIGN_WHITE = Color3.fromRGB(250, 250, 246)
local band = box("SignBand", X0 - 1.1, top1 - 3.2, Z0 + 0.2, X0, top1 + 0.2, Z1 - 0.2, SIGN_WHITE)
local bandText = box("SignBandText", X0 - 1.15, top1 - 3.2, Z0 + 0.2, X0 - 1.1, top1 + 0.2, Z1 - 0.2, SIGN_WHITE, { t = 1, nocol = true, noshadow = true })
local bandLabel = label(bandText, Enum.NormalId.Left, "오후 돼지국밥", RED, { pps = 24, bg = SIGN_WHITE, pad = 0.2 })
-- "24시" in a red box at the club end (the viewer's right is +z) of the same
-- surface (a separate part in front of it hid behind the band text)
local hours = Instance.new("TextLabel")
hours.Name = "Hours"
hours.AnchorPoint = Vector2.new(1, 0.5)
hours.Position = UDim2.fromScale(0.97, 0.5)
hours.Size = UDim2.fromScale(0.13, 0.42)
hours.BackgroundColor3 = RED
hours.BorderSizePixel = 0
hours.Font = Enum.Font.GothamBlack
hours.TextScaled = true
hours.TextColor3 = Color3.new(1, 1, 1)
hours.Text = "24시"
hours.ZIndex = 2
hours.Parent = bandLabel.Parent
local bandLight = Instance.new("SurfaceLight")
bandLight.Face = Enum.NormalId.Left
bandLight.Range = 16
bandLight.Brightness = 1.2
bandLight.Angle = 100
bandLight.Color = Color3.fromRGB(255, 248, 236)
bandLight.Parent = band
-- a vertical sign sticking out at the club-side corner (seen along the sidewalk)
local vs = box("VerticalSign", X0 - 3.6, top1 + 0.6, Z1 - 1.0, X0 - 0.6, top1 + 8.6, Z1 - 0.4, SIGN_WHITE)
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	label(vs, face, "국\n밥", RED, { pps = 30, lh = 0.95, bg = SIGN_WHITE })
end
local vsLight = Instance.new("PointLight")
vsLight.Range = 10
vsLight.Brightness = 0.8
vsLight.Color = Color3.fromRGB(255, 240, 230)
vsLight.Parent = vs
box("VerticalSignArm", X0 - 0.6, top1 + 4.4, Z1 - 0.8, X0, top1 + 4.8, Z1 - 0.6, DARK, { nocol = true })

-- outside: cauldron on a brick stove with steam, AC unit, standing sign -----
do
	local cx, cz = X0 - 2.6, Z0 + 3.2
	box("Stove", cx - 1.6, FY, cz - 1.6, cx + 1.6, FY + 2.2, cz + 1.6, Color3.fromRGB(150, 80, 60), { material = Enum.Material.Brick })
	local pot = vcyl("Gamasot", Vector3.new(cx, FY + 2.2, cz), 3.4, 1.6, Color3.fromRGB(30, 30, 32), { material = Enum.Material.Metal })
	vcyl("GamasotRim", Vector3.new(cx, FY + 3.6, cz), 3.8, 0.25, Color3.fromRGB(24, 24, 26), { material = Enum.Material.Metal })
	local lid = vcyl("GamasotLid", Vector3.new(cx, FY + 3.85, cz), 3.0, 0.4, Color3.fromRGB(70, 50, 34), { material = Enum.Material.Wood })
	vcyl("LidKnob", Vector3.new(cx, FY + 4.25, cz), 0.5, 0.35, Color3.fromRGB(50, 36, 26), { material = Enum.Material.Wood })
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	steam.Lifetime = NumberRange.new(2, 3)
	steam.Rate = 6
	steam.Speed = NumberRange.new(1.5, 2.5)
	steam.SpreadAngle = Vector2.new(15, 15)
	steam.LightInfluence = 0.6
	steam.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis (local X) points up
	steam.Parent = lid
	_ = pot
	-- AC outdoor unit against the 1F glass wainscot, south of the door
	box("ACUnit", X0 - 1.4, FY, Z1 - 6.5, X0 - 0.1, FY + 2.4, Z1 - 3.3, Color3.fromRGB(232, 232, 228))
	local fan = vcyl("ACFan", Vector3.new(X0 - 1.42, FY + 1.2, Z1 - 4.9), 1.8, 0.05, Color3.fromRGB(70, 70, 74), { nocol = true })
	fan.CFrame = CFrame.new(X0 - 1.42, FY + 1.2, Z1 - 4.9)
	-- A-frame standing sign by the door
	local sign = part("StandSign", Vector3.new(0.2, 3.6, 2.2), CFrame.new(X0 - 2.4, FY + 1.8, DOOR_Z1 + 1.8) * CFrame.Angles(0, 0, math.rad(8)), RED)
	label(sign, Enum.NormalId.Left, "24시간\n영업", Color3.new(1, 1, 1), { pps = 40 })
	label(sign, Enum.NormalId.Right, "국밥\n💰20", Color3.new(1, 1, 1), { pps = 40 })
end

-- inside ---------------------------------------------------------------------
-- lower walls: light wood panels; tube lights on the ceiling
for _, w in ipairs({ { X0 + WT, Z0 + WT, X1 - WT, Z0 + WT + 0.1 }, { X0 + WT, Z1 - WT - 0.1, X1 - WT, Z1 - WT } }) do
	box("WallPanel", w[1], FY, w[2], w[3], FY + 4, w[4], Color3.fromRGB(196, 160, 116), { material = Enum.Material.WoodPlanks, nocol = true })
end
for lz = Z0 + 8, Z1 - 5, 16 do -- (5 × 7 tubes over the big hall; their range grows with the 21-stud ceiling)
	for lx = X0 + 8, X1 - 18, 18 do
		local tube = box("TubeLight", lx - 2.2, top1 - 0.25, lz - 0.25, lx + 2.2, top1, lz + 0.25, Color3.fromRGB(248, 250, 255), { material = Enum.Material.Neon, nocol = true, noshadow = true })
		local l = Instance.new("SurfaceLight")
		l.Face = Enum.NormalId.Bottom
		l.Range = 26
		l.Brightness = 0.9
		l.Angle = 120
		l.Color = Color3.fromRGB(245, 248, 255)
		l.Parent = tube
	end
end

-- kitchen along the back wall: steel counter with a pass, stock pots, bowls
local KX = X1 - 14 -- counter front
box("KitchenFloor", KX, FY, Z0 + WT, X1 - WT, FY + 0.05, Z1 - WT, Color3.fromRGB(120, 118, 114), { material = Enum.Material.Slate, nocol = true })
local counter = box("KitchenCounter", KX, FY, Z0 + 4, KX + 1.6, FY + 3.6, Z1 - 4, STEEL, { material = Enum.Material.DiamondPlate })
CS:AddTag(counter, "GukbapCounter")
-- the order point: "주문하기" opens the 국밥집 menu (SnackService, D-317)
counter:SetAttribute("Shop", "Gukbap")
CS:AddTag(counter, "SnackShop")
box("CounterTop", KX - 0.3, FY + 3.6, Z0 + 3.8, KX + 1.9, FY + 3.8, Z1 - 3.8, Color3.fromRGB(214, 218, 222), { material = Enum.Material.Metal })
box("KitchenSideWall_N", KX, FY, Z0 + WT, KX + 0.4, FY + 3.6, Z0 + 4, STEEL, { material = Enum.Material.Metal })
box("KitchenSideWall_S", KX, FY, Z1 - 4, KX + 0.4, FY + 3.6, Z1 - WT, STEEL, { material = Enum.Material.Metal })
box("Range", X1 - WT - 3, FY, Z0 + 6, X1 - WT, FY + 3, Z1 - 6, Color3.fromRGB(70, 70, 74), { material = Enum.Material.Metal })
for pz = Z0 + 9, Z1 - 8, 6 do
	local pot = vcyl("StockPot", Vector3.new(X1 - WT - 1.5, FY + 3, pz), 2.6, 2.6, Color3.fromRGB(205, 208, 212), { material = Enum.Material.Metal })
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
-- stacks of earthenware bowls (뚝배기) on the counter
for bz = Z0 + 6, Z1 - 6, 5 do
	for k = 0, 2 do
		vcyl("Ttukbaegi", Vector3.new(KX + 0.9, FY + 3.8 + k * 0.55, bz), 1.2, 0.5, Color3.fromRGB(70, 46, 38), { material = Enum.Material.Slate, nocol = true })
	end
end
-- the menu board over the kitchen (seen from the hall: face -X = Left)
local menu = box("MenuBoard", X1 - WT - 0.2, FY + 6.2, Z0 + 4, X1 - WT, FY + 11.4, Z1 - 4, Color3.fromRGB(60, 44, 32), { material = Enum.Material.Wood })
label(menu, Enum.NormalId.Left, "메 뉴\n돼지국밥 💰20   순대국밥 💰20\n소고기국밥 💰20   수육 한 접시 R$19\n공깃밥 · 김치 · 깍두기 무료", Color3.fromRGB(255, 244, 214), { pps = 30, font = Enum.Font.GothamBold, lh = 1.1 })
-- water purifier + cups by the north wall near the door
box("WaterPurifier", X0 + 1.2, FY, Z0 + WT, X0 + 3, FY + 4.2, Z0 + WT + 1.6, Color3.fromRGB(240, 240, 244))
box("PurifierPanel", X0 + 1.4, FY + 3.2, Z0 + WT + 1.6, X0 + 2.8, FY + 3.8, Z0 + WT + 1.65, Color3.fromRGB(60, 140, 220), { material = Enum.Material.Neon, nocol = true })
-- a framed "since" poster on the north wall
local poster = box("Poster", 60, FY + 6, Z0 + WT, 65, FY + 9, Z0 + WT + 0.1, Color3.fromRGB(250, 240, 210), { nocol = true })
label(poster, Enum.NormalId.Back, "SINCE 1985\n가마솥 24시간", Color3.fromRGB(120, 40, 30), { pps = 40, font = Enum.Font.GothamBold })

-- tables: stainless tops, four round stools each, kimchi jars on top ------
local function gukbapTable(tx, tz)
	box("TableLeg", tx - 0.2, FY, tz - 0.2, tx + 0.2, FY + 2.3, tz + 0.2, DARK)
	local top = box("TableTop", tx - 1.4, FY + 2.3, tz - 2.3, tx + 1.4, FY + 2.5, tz + 2.3, STEEL, { material = Enum.Material.Metal })
	CS:AddTag(top, "GukbapTable")
	vcyl("KkakdugiJar", Vector3.new(tx + 0.6, FY + 2.5, tz - 1.6), 0.7, 0.6, Color3.fromRGB(200, 70, 50), { nocol = true })
	vcyl("KimchiJar", Vector3.new(tx + 0.6, FY + 2.5, tz - 0.8), 0.7, 0.6, Color3.fromRGB(180, 40, 30), { nocol = true })
	box("SpoonBox", tx - 0.8, FY + 2.5, tz - 1.9, tx - 0.2, FY + 3.0, tz - 1.1, Color3.fromRGB(150, 110, 70), { material = Enum.Material.Wood, nocol = true })
	-- tissue box: the user's pick (#3 of the restaurant sheet) retextured as
	-- wood (ServerStorage.ArtAssets.TissueBoxWood), else a plain white box
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local tissue = art and art:FindFirstChild("TissueBoxWood")
	if tissue then
		local m = tissue:Clone()
		m.Name = "NapkinBox"
		local _, sz = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * 0.75 / sz.Y)
		local _, sz2 = m:GetBoundingBox()
		m:PivotTo(CFrame.new(tx - 0.5, FY + 2.5 + sz2.Y / 2, tz - 0.6) * CFrame.Angles(0, math.rad(90), 0))
		for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false end end
		m.Parent = M
	else
		box("NapkinBox", tx - 0.8, FY + 2.5, tz - 0.9, tx - 0.2, FY + 2.9, tz - 0.3, Color3.fromRGB(245, 245, 245), { nocol = true })
	end
	for _, s in ipairs({ { -2.1, -1.1 }, { -2.1, 1.1 }, { 2.1, -1.1 }, { 2.1, 1.1 } }) do
		-- the round top is a plain cylinder; the Seat is an invisible upright
		-- block on it (a Seat takes the sitter's up from its own axes, so the
		-- turned cylinder laid players flat, phone test 2026-10-26)
		vcyl("Stool", Vector3.new(tx + s[1], FY + 1.35, tz + s[2]), 1.4, 0.3, RED)
		local seat = Instance.new("Seat")
		seat.Name = "StoolSeat"
		seat.Anchored = true
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Size = Vector3.new(1.2, 0.2, 1.2)
		seat.CFrame = CFrame.lookAt(Vector3.new(tx + s[1], FY + 1.6, tz + s[2]), Vector3.new(tx, FY + 1.6, tz + s[2]))
		seat.Parent = M
		vcyl("StoolLeg", Vector3.new(tx + s[1], FY, tz + s[2]), 0.3, 1.35, ALU, { nocol = true })
	end
end
-- (layout v8) 32 tables in four rows, an aisle from the door to the kitchen
for _, tz in ipairs({ -366, -352, -316, -302 }) do
	for _, tx in ipairs({ 56, 69, 82, 95, 108, 121, 134 }) do -- (seven a row in the narrower hall)
		gukbapTable(tx, tz)
	end
end

M.Parent = T
local n = 0
for _, d in ipairs(M:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return "gukbap built, parts " .. n
