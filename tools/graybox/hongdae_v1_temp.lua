-- TEMPORARY layout test v4 (docs/02_WORLDS/HONGDAE_LAYOUT.md "v4"): the user's
-- hand-drawn plan of 2026-10-22 (roundabout with a lawn in the middle,
-- asphalt roads, subway exits 1-4 at its corners, background buildings).
-- Scale read from the drawing: 1 stud ≈ 3 px (the club and park rides were
-- pasted at their real size); roundabout centre = world (0, 0).
-- Run in the Studio command bar (Edit mode). Set MODE below:
--   "apply"  → moves the zones, sets aside the old plaza / paths / ground
--              pieces, adds Workspace.Hongdae_v1_Temp (roads, lawn, exits,
--              background buildings, ground with the club hole in its new place)
--   "revert" → puts everything back exactly as built
-- Real compass in Roblox (Lighting:GetSunDirection, measured 2026-10-22):
-- the sun rises at +X (east) and sets at -X (west). The sea is
-- in the west (-X): sunset over it. North/south follow the Studio top view
-- the user draws on (screen up = -Z), not the sun's noon lean.
local MODE = ... or "apply"

local root = workspace:WaitForChild("Graybox_MainSocial")
local SS = game:GetService("ServerStorage")
local HIDE = "Hongdae_v1_HiddenParts"
local function R(deg) return CFrame.Angles(0, math.rad(deg), 0) end

-- zone → world move applied to the zone's built pivot
-- Map orientation = the Studio top view: screen up = -Z ("north"), right = +X (east).
-- v4b (user 2026-10-22: "거리 및 사이즈 1/3, 너무 멀어" → gaps, roads and the
-- roundabout at about 1/3, building sizes unchanged). Roundabout centre C.
local C = Vector3.new(-60, 0, 0)
-- v5 (user 2026-10-22, street photo of 강남대로61길): the four big roads from
-- the roundabout are wider (2 lanes + parking both sides) with raised
-- sidewalks, so buildings start 36 studs from the roundabout axes.
local MOVES = {
	-- club north-east of the roundabout, entrance + neon facing west onto the club street
	["02_Club"] = CFrame.new(49, 0, -172) * R(-90) * CFrame.new(0, 0, 210),
	-- fashion week runway right behind the club (show / concert space), runway toward the club
	["03_Rooftop_Backstage"] = CFrame.new(49, 0, -366) * R(180) * CFrame.new(-125, 0, 160),
	-- hanok village south-east: main gate east (morning sun), back gate west
	["07_Hanok_Village"] = CFrame.new(85, 0, 126) * R(-90) * CFrame.new(-175, 0, -230),
	-- 인생네컷 between the roundabout and the east, below the club
	["08_PhotoBooth"] = CFrame.new(6, 0, -61) * CFrame.new(-205, 0, 112),
	-- park rides north-west (west part over the beach, as in the drawing)
	["06_Park_Playground"] = CFrame.new(-506, 0, -141),
	-- Glasshouse cafe south-west, long side along the road, terrace toward the road (north)
	["05_Cafe"] = CFrame.new(-153.5, 0, 175) * R(-90) * CFrame.new(130, 0, -185),
}
local HOLE = { -11, -252, 109, -92 } -- club ground hole x0, z0, x1, z1 (follows 02_Club)
-- set aside while the layout is applied (restored by revert): the whole old
-- ring plaza (the roundabout replaces it), old paths, old ground pieces
local function shouldHide(zn, p)
	if zn == "09_Paths" or zn == "01_Plaza_Street" then return true end
	if zn == "00_Ground" then return p.Name == "Ground_N" or p.Name == "Ground_S" or p.Name == "Ground_W" or p.Name == "Ground_E" end
	return false
end

local function moveTo(m: Model, target: CFrame)
	local d = target * m:GetPivot():Inverse()
	m:PivotTo(target)
	local list = m:GetDescendants()
	table.insert(list, m)
	for _, x in ipairs(list) do
		for k, v in pairs(x:GetAttributes()) do
			if typeof(v) == "Vector3" then x:SetAttribute(k, d * v) end
		end
	end
end

local spawn = workspace:FindFirstChild("SpawnLocation") :: SpawnLocation?

local function revert()
	for _, z in ipairs(root:GetChildren()) do
		local b = z:GetAttribute("BuiltPivot")
		if z:IsA("Model") and typeof(b) == "CFrame" and z:GetPivot() ~= b then moveTo(z, b) end
	end
	local hidden = SS:FindFirstChild(HIDE)
	if hidden then
		for _, p in ipairs(hidden:GetChildren()) do
			local home = root:FindFirstChild(p:GetAttribute("HomeZone"))
			if home then p.Parent = home end
		end
		hidden:Destroy()
	end
	if workspace:FindFirstChild("Hongdae_v1_Temp") then workspace.Hongdae_v1_Temp:Destroy() end
	if spawn and spawn:GetAttribute("OldPosition") then
		spawn.CFrame = CFrame.new(spawn:GetAttribute("OldPosition"))
		spawn:SetAttribute("OldPosition", nil)
	end
end

if MODE == "revert" then
	revert()
	return "reverted (zones back to BuiltPivot, hidden parts restored, temp model removed)"
end

-- apply (always from the built layout, so it can be re-run) -----------------
revert()
for name, d in pairs(MOVES) do
	local z = root:FindFirstChild(name)
	local b = z and z:GetAttribute("BuiltPivot")
	if typeof(b) == "CFrame" then moveTo(z, d * b) end
end

local hidden = Instance.new("Folder")
hidden.Name = HIDE
hidden.Parent = SS
local groundTemplate: BasePart? = nil
for _, zn in ipairs({ "00_Ground", "01_Plaza_Street", "09_Paths" }) do
	for _, p in ipairs(root[zn]:GetChildren()) do
		if (p:IsA("BasePart") or p:IsA("Model")) and shouldHide(zn, p) then
			if p.Name == "Ground_N" then groundTemplate = p end
			p:SetAttribute("HomeZone", zn)
			p.Parent = hidden
		end
	end
end

local T = Instance.new("Model")
T.Name = "Hongdae_v1_Temp"

-- ground around the club's new hole; the old ground spans x -268..1024, z -1024..1024
if groundTemplate then
	local y = groundTemplate.Position.Y
	local h = groundTemplate.Size.Y
	local function ground(name, x0, z0, x1, z1)
		local g = groundTemplate:Clone()
		g.Name = name
		g.Size = Vector3.new(x1 - x0, h, z1 - z0)
		g.CFrame = CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2)
		g:SetAttribute("HomeZone", nil)
		g.Parent = T
	end
	local x0, z0, x1, z1 = HOLE[1], HOLE[2], HOLE[3], HOLE[4]
	ground("Ground_S", -268, -1024, 1024, z0)
	ground("Ground_N", -268, z1, 1024, 1024)
	ground("Ground_W", -268, z0, x0, z1)
	ground("Ground_E", x1, z0, 1024, z1)
end

local function part(name, size, cf, color, opt)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opt and opt.transparency) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	if opt and opt.shape then p.Shape = opt.shape end
	p.Parent = (opt and opt.parent) or T
	return p
end
-- flat strip from a to b on the ground (x,z), width w
local function strip(name, a: Vector2, b: Vector2, w, color, y)
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, y or 0.06, mid.Y), Vector3.new(b.X, y or 0.06, b.Y))
	return part(name, Vector3.new(w, 0.12, (b - a).Magnitude), cf, color, { material = Enum.Material.Asphalt })
end
local function label(adornee: BasePart, text, color, offsetY, scale)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Size = UDim2.fromOffset(260 * (scale or 1), 60 * (scale or 1))
	g.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	g.AlwaysOnTop = true
	g.MaxDistance = 900
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Parent = g
	g.Parent = adornee
	return g
end
-- solid block from (x0,z0) to (x1,z1), height h
local function block(name, x0, z0, x1, z1, h, color, text, textColor)
	local b = part(name, Vector3.new(x1 - x0, h, z1 - z0), CFrame.new((x0 + x1) / 2, h / 2, (z0 + z1) / 2), color)
	if text then label(b, text, textColor or Color3.fromRGB(70, 70, 70), h / 2 + 3, 0.7) end
	return b
end

local ASPHALT = Color3.fromRGB(78, 78, 82)
local WALK = Color3.fromRGB(150, 140, 138) -- sidewalk brick paving (reference video)
local CURB = 0.6 -- sidewalk height above the road (one easy step)
local WHITE = Color3.fromRGB(240, 240, 240)
local YELLOW = Color3.fromRGB(240, 190, 40)
local CS = game:GetService("CollectionService")

-- world-aligned box from (x0,y0,z0) to (x1,y1,z1)
local function box(name, x0, y0, z0, x1, y1, z1, color, opt)
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local ly, hy = math.min(y0, y1), math.max(y0, y1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	return part(name, Vector3.new(hx - lx, hy - ly, hz - lz), CFrame.new((lx + hx) / 2, (ly + hy) / 2, (lz + hz) / 2), color, opt)
end
local function walk(x0, z0, x1, z1)
	return box("Sidewalk", x0, 0, z0, x1, CURB, z1, WALK, { material = Enum.Material.Brick })
end
local function vcyl(name, pos: Vector3, d, h, color, opt)
	opt = opt or {}
	opt.shape = Enum.PartType.Cylinder
	return part(name, Vector3.new(h, d, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, opt)
end

-- roundabout: asphalt ring around a raised round lawn
local UP = CFrame.Angles(0, 0, math.rad(90))
part("Roundabout", Vector3.new(0.14, 68, 68), CFrame.new(C.X, 0.07, C.Z) * UP, ASPHALT, { shape = Enum.PartType.Cylinder, material = Enum.Material.Asphalt })
local lawn = part("RoundaboutLawn", Vector3.new(CURB, 28, 28), CFrame.new(C.X, CURB / 2, C.Z) * UP, Color3.fromRGB(90, 170, 80), { shape = Enum.PartType.Cylinder, material = Enum.Material.Grass })
label(lawn, "잔디밭", Color3.fromRGB(40, 110, 40), 4, 0.6)
-- corner sidewalks between the arms (exits stand here)
for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
	walk(C.X + s[1] * 24, C.Z + s[2] * 24, C.X + s[1] * 36, C.Z + s[2] * 36)
	walk(C.X + s[1] * 16, C.Z + s[2] * 30, C.X + s[1] * 24, C.Z + s[2] * 36)
	walk(C.X + s[1] * 30, C.Z + s[2] * 16, C.X + s[1] * 36, C.Z + s[2] * 24)
end

-- a big road from the roundabout: asphalt 32 (parking 7 | lane 9 | lane 9 | parking 7),
-- sidewalks 8 both sides, crosswalk, centre line, parked cars, poles, traffic light.
-- dir = unit axis (±X or ±Z); u = distance along it from C, v = across.
local CAR_COLORS = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(25, 25, 30), Color3.fromRGB(150, 155, 160), Color3.fromRGB(40, 60, 110), Color3.fromRGB(160, 30, 35), Color3.fromRGB(230, 230, 225) }
local carCount = 0
local function car(pos: Vector3, along: Vector3)
	carCount += 1
	local m = Instance.new("Model")
	m.Name = "ParkedCar"
	local cf = CFrame.lookAt(pos, pos + along)
	local col = CAR_COLORS[(carCount % #CAR_COLORS) + 1]
	part("Body", Vector3.new(6.4, 2.4, 14), cf * CFrame.new(0, 2.1, 0), col, { parent = m })
	part("Cabin", Vector3.new(5.8, 2.2, 7.5), cf * CFrame.new(0, 4.4, 0.6), Color3.fromRGB(35, 40, 50), { parent = m, material = Enum.Material.Glass })
	for _, w in ipairs({ { -3.1, -4.5 }, { 3.1, -4.5 }, { -3.1, 4.5 }, { 3.1, 4.5 } }) do
		part("Wheel", Vector3.new(1.2, 2.6, 2.6), cf * CFrame.new(w[1], 1.3, w[2]), Color3.fromRGB(20, 20, 20), { parent = m, shape = Enum.PartType.Cylinder })
	end
	m.Parent = T
end
local function pole(pos: Vector3)
	vcyl("UtilityPole", pos, 1.2, 26, Color3.fromRGB(165, 165, 160), { material = Enum.Material.Concrete })
	box("PoleArm", pos.X - 3.5, 23.6, pos.Z - 0.25, pos.X + 3.5, 24.1, pos.Z + 0.25, Color3.fromRGB(70, 70, 70))
	return pos + Vector3.new(0, 24.1, 0)
end
local function wire(a: Vector3, b: Vector3)
	for _, dx in ipairs({ -3, 3 }) do
		local p, q = a + Vector3.new(dx, 0, 0), b + Vector3.new(dx, 0, 0)
		local w = part("Wire", Vector3.new(0.12, 0.12, (q - p).Magnitude), CFrame.lookAt((p + q) / 2, q), Color3.fromRGB(20, 20, 20))
		w.CanCollide = false
		w.CanQuery = false
	end
end
-- street lamp: slim pole, arm over the road, warm light (shows at night)
local function streetLamp(base: Vector3, toward: Vector3)
	base = base + Vector3.new(0, CURB, 0)
	vcyl("LampPole", base, 0.6, 16, Color3.fromRGB(60, 62, 66))
	local tip = base + toward * 3 + Vector3.new(0, 16, 0)
	local arm = part("LampArm", Vector3.new(0.4, 0.4, 3), CFrame.lookAt(base + toward * 1.5 + Vector3.new(0, 16, 0), tip), Color3.fromRGB(60, 62, 66))
	arm.CanCollide = false
	local head = part("LampHead", Vector3.new(1.6, 0.5, 1.6), CFrame.new(tip - Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 225, 160), { material = Enum.Material.Neon })
	head.CanCollide = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 26
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 215, 160)
	light.Parent = head
end
local function trafficLight(base: Vector3, toward: Vector3)
	vcyl("SignalPole", base, 1, 18, Color3.fromRGB(70, 75, 80))
	local tip = base + toward * 12 + Vector3.new(0, 17, 0)
	local arm = part("SignalArm", Vector3.new(0.6, 0.6, 12), CFrame.lookAt(base + toward * 6 + Vector3.new(0, 17, 0), tip), Color3.fromRGB(70, 75, 80))
	arm.CanCollide = false
	local head = part("SignalHead", Vector3.new(4.2, 1.5, 1.2), CFrame.lookAt(tip - Vector3.new(0, 1.2, 0), tip - Vector3.new(0, 1.2, 0) + toward:Cross(Vector3.yAxis)), Color3.fromRGB(25, 25, 25))
	for i, c in ipairs({ Color3.fromRGB(255, 60, 50), Color3.fromRGB(255, 190, 40), Color3.fromRGB(60, 230, 110) }) do
		local l = part("SignalLamp", Vector3.new(0.9, 0.9, 0.3), head.CFrame * CFrame.new((i - 2) * 1.3, 0, -0.65), c, { material = Enum.Material.Neon })
		l.CanCollide = false
	end
end

local function bigRoad(dir: Vector3, len: number, cars: { number }, carsOther: { number })
	local across = Vector3.new(dir.Z, 0, -dir.X) -- 90° to the right of dir
	local function at(u, v) return C + dir * u + across * v end
	local function boxUV(name, u0, v0, u1, v1, y0, y1, color, opt)
		local a, b = at(u0, v0), at(u1, v1)
		return box(name, a.X, y0, a.Z, b.X, y1, b.Z, color, opt)
	end
	boxUV("Road", 30, -16, len, 16, 0, 0.12, ASPHALT, { material = Enum.Material.Asphalt })
	boxUV("Sidewalk", 36, -24, len, -16, 0, CURB, WALK, { material = Enum.Material.Brick })
	boxUV("Sidewalk", 36, 16, len, 24, 0, CURB, WALK, { material = Enum.Material.Brick })
	-- centre double yellow line, white parking lines
	boxUV("CenterLine", 46, -0.55, len, -0.25, 0.12, 0.16, YELLOW)
	boxUV("CenterLine", 46, 0.25, len, 0.55, 0.12, 0.16, YELLOW)
	boxUV("ParkingLine", 46, -9.15, len, -8.85, 0.12, 0.16, WHITE)
	boxUV("ParkingLine", 46, 8.85, len, 9.15, 0.12, 0.16, WHITE)
	for u = 52, len - 8, 16 do -- parking bay ticks
		boxUV("ParkingTick", u, -16, u + 0.3, -9, 0.12, 0.16, WHITE)
		boxUV("ParkingTick", u, 9, u + 0.3, 16, 0.12, 0.16, WHITE)
	end
	-- zebra crosswalk + stop lines near the roundabout
	for v = -14.4, 14.4, 3.2 do boxUV("Crosswalk", 37, v - 0.8, 43, v + 0.8, 0.12, 0.16, WHITE) end
	boxUV("StopLine", 44.5, 0, 45.2, 16, 0.12, 0.16, WHITE)
	boxUV("StopLine", 44.5, -16, 45.2, 0, 0.12, 0.16, WHITE)
	-- parked cars (bays at v ±12.5)
	for _, u in ipairs(cars) do car(at(u, -12.5), dir) end
	for _, u in ipairs(carsOther) do car(at(u, 12.5), -dir) end
	-- utility poles with wires on one side, a pole on the other
	local last: Vector3? = nil
	for u = 56, len - 4, 48 do
		local top = pole(at(u, -22.5))
		if last then wire(last, top) end
		last = top
		streetLamp(at(u + 24, 21), -across)
		streetLamp(at(u + 24, -21), across)
	end
	boxUV("TactileStrip", 36, -17.8, len, -17, CURB, CURB + 0.05, YELLOW)
	boxUV("TactileStrip", 36, 17, len, 17.8, CURB, CURB + 0.05, YELLOW)
	trafficLight(at(47, 22.5), -across)
end
bigRoad(Vector3.new(-1, 0, 0), 136, { 62, 96 }, { 80, 112 }) -- west, to the beach road
bigRoad(Vector3.new(1, 0, 0), 320, { 64, 112, 192, 272 }, { 80, 144, 224, 288 }) -- east
bigRoad(Vector3.new(0, 0, -1), 470, { 64, 128, 208, 320, 400 }, { 96, 176, 256, 352 }) -- north
bigRoad(Vector3.new(0, 0, 1), 300, { 64, 144, 224 }, { 96, 192, 272 }) -- south

-- smaller roads: asphalt 12 with a dashed centre line, sidewalks 4
local function smallRoad(a: Vector2, b: Vector2)
	local dir = Vector3.new(b.X - a.X, 0, b.Y - a.Y)
	local len = dir.Magnitude
	dir = dir.Unit
	local across = Vector3.new(dir.Z, 0, -dir.X)
	local o = Vector3.new(a.X, 0, a.Y)
	local function bx(name, u0, v0, u1, v1, y0, y1, color, opt)
		local p, q = o + dir * u0 + across * v0, o + dir * u1 + across * v1
		return box(name, p.X, y0, p.Z, q.X, y1, q.Z, color, opt)
	end
	bx("Road", 0, -6, len, 6, 0, 0.12, ASPHALT, { material = Enum.Material.Asphalt })
	bx("Sidewalk", 0, -10, len, -6, 0, CURB, WALK, { material = Enum.Material.Brick })
	bx("Sidewalk", 0, 6, len, 10, 0, CURB, WALK, { material = Enum.Material.Brick })
	for u = 4, len - 6, 10 do bx("LaneDash", u, -0.15, u + 5, 0.15, 0.12, 0.16, WHITE) end
	for u = 20, len - 4, 60 do pole(o + dir * u + across * 8) end
end
smallRoad(Vector2.new(121, -24), Vector2.new(121, -470)) -- east of the club
smallRoad(Vector2.new(-84, 98), Vector2.new(-190, 98)) -- south-west, to the beach road
smallRoad(Vector2.new(-190, 24), Vector2.new(-190, 300)) -- along the beach
local LANE = Color3.fromRGB(185, 160, 122)
strip("HanokLane_East", Vector2.new(162, 24), Vector2.new(162, 130), 8, LANE)
strip("HanokLane_East2", Vector2.new(166, 126), Vector2.new(148, 126), 8, LANE)
strip("HanokLane_West", Vector2.new(-36, 156), Vector2.new(22, 156), 8, LANE)
local clubStreet = box("ClubStreet", -36, 0, -252, -11, 0.14, -92, Color3.fromRGB(110, 85, 160))
label(clubStreet, "클럽거리 (잔다리로)", Color3.fromRGB(160, 110, 230), 3, 0.8)

-- high-rise background buildings along the roads (진입불가): glass towers and
-- concrete mid-rises with window bands and shop signs, like the street photo
local SIGNS = { Color3.fromRGB(230, 60, 70), Color3.fromRGB(40, 120, 220), Color3.fromRGB(250, 200, 40), Color3.fromRGB(60, 180, 90), Color3.fromRGB(240, 120, 40) }
-- ground-floor shop front on the street face (W/E/N/S): dark glass + name board
local FACE = { W = Enum.NormalId.Left, E = Enum.NormalId.Right, N = Enum.NormalId.Front, S = Enum.NormalId.Back }
local function storefront(m, x0, z0, x1, z1, face, name, color)
	local a, b
	if face == "W" then a, b = Vector3.new(x0 - 0.4, 0, z0 + 2), Vector3.new(x0, 0, z1 - 2)
	elseif face == "E" then a, b = Vector3.new(x1, 0, z0 + 2), Vector3.new(x1 + 0.4, 0, z1 - 2)
	elseif face == "N" then a, b = Vector3.new(x0 + 2, 0, z0 - 0.4), Vector3.new(x1 - 2, 0, z0)
	else a, b = Vector3.new(x0 + 2, 0, z1), Vector3.new(x1 - 2, 0, z1 + 0.4) end
	box("ShopGlass", a.X, CURB, a.Z, b.X, 10, b.Z, Color3.fromRGB(35, 45, 55), { parent = m, material = Enum.Material.Glass })
	local out = (if face == "W" then Vector3.new(-0.6, 0, 0) elseif face == "E" then Vector3.new(0.6, 0, 0) elseif face == "N" then Vector3.new(0, 0, -0.6) else Vector3.new(0, 0, 0.6))
	local board = box("ShopBoard", a.X + out.X, 10.4, a.Z + out.Z, b.X + out.X, 13.4, b.Z + out.Z, Color3.fromRGB(25, 25, 30), { parent = m })
	local g = Instance.new("SurfaceGui")
	g.Face = FACE[face]
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.Parent = board
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = name
	l.Parent = g
end
local function tower(x0, z0, x1, z1, h, kind, face, shop)
	local m = Instance.new("Model")
	m.Name = "BG_Tower(진입불가)"
	local glass = kind == "glass"
	local body = box("Body", x0, 0, z0, x1, h, z1, if glass then Color3.fromRGB(105, 135, 160) else Color3.fromRGB(185, 180, 172), { parent = m, material = if glass then Enum.Material.Glass else Enum.Material.Concrete })
	if glass then body.Reflectance = 0.15 end
	local step = if glass then 6 else 7
	for y = step, h - 2, step do
		if glass then
			box("FloorBand", x0 - 0.2, y - 0.3, z0 - 0.2, x1 + 0.2, y + 0.3, z1 + 0.2, Color3.fromRGB(70, 80, 90), { parent = m })
		else
			box("WindowBand", x0 - 0.2, y - 3.6, z0 - 0.2, x1 + 0.2, y - 1, z1 + 0.2, Color3.fromRGB(45, 55, 65), { parent = m, material = Enum.Material.Glass })
		end
	end
	box("Roof", x0 - 0.5, h, z0 - 0.5, x1 + 0.5, h + 1.5, z1 + 0.5, Color3.fromRGB(90, 90, 95), { parent = m })
	if face and shop then storefront(m, x0, z0, x1, z1, face, shop, SIGNS[(#shop % #SIGNS) + 1]) end
	if not glass then -- vertical shop signs on the street face corners
		for i = 0, 2 do
			local c = SIGNS[((x0 + z0 + i) % #SIGNS) + 1]
			box("ShopSign", x0 - 1.2, 8 + i * 12, z0 + 2, x0 - 0.2, 17 + i * 12, z0 + 5, c, { parent = m, material = Enum.Material.Neon })
		end
	end
	m.Parent = T
end
tower(133, -470, 183, -380, 150, "glass", "W", "OHU 타워")
tower(133, -370, 183, -262, 96, "concrete", "W", "PC방")
tower(133, -252, 183, -170, 128, "glass", "W", "HOMME")
tower(133, -160, 183, -36, 70, "concrete", "W", "뷰티 & 샵")
tower(170, 36, 215, 120, 90, "concrete", "W", "치킨")
tower(170, 130, 215, 220, 60, "concrete", "W", "꽃집")
tower(-126, 110, -92, 170, 120, "glass", "E", "카페")
tower(-126, 180, -92, 250, 80, "concrete", "E", "약국")
tower(-176, 36, -146, 80, 60, "concrete", "S", "노래방")
tower(200, -120, 260, -36, 110, "glass", "S", "OHU 마트")

-- construction site look for buildings that will get a function later
-- (photo: white hoarding with a blue line mural, crane, cones)
local function construction(x0, z0, x1, z1, title)
	local m = Instance.new("Model")
	m.Name = "ConstructionSite(" .. title .. ")"
	box("Dirt", x0, 0, z0, x1, 0.2, z1, Color3.fromRGB(150, 120, 90), { parent = m, material = Enum.Material.Ground })
	local H = 9
	local walls = {
		box("Hoarding", x0, 0, z0, x1, H, z0 + 0.4, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x0, 0, z1 - 0.4, x1, H, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x0, 0, z0, x0 + 0.4, H, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x1 - 0.4, 0, z0, x1, H, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
	}
	for i, w in ipairs(walls) do -- blue line mural + title on every face
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local long = (face == Enum.NormalId.Front or face == Enum.NormalId.Back) == (w.Size.X > w.Size.Z)
			if long then
				local g = Instance.new("SurfaceGui")
				g.Face = face
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 20
				g.Parent = w
				for k = 0, 5 do
					local line = Instance.new("Frame")
					line.BackgroundColor3 = Color3.fromRGB(70, 90, 190)
					line.BorderSizePixel = 0
					line.AnchorPoint = Vector2.new(0.5, 0.5)
					line.Position = UDim2.fromScale(0.12 + k * 0.16, 0.45 + ((k % 2) - 0.5) * 0.25)
					line.Size = UDim2.new(0.14, 0, 0, 6)
					line.Rotation = (k % 2) * 30 - 15
					line.Parent = g
				end
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 0.22)
				t.Position = UDim2.fromScale(0, 0.72)
				t.Font = Enum.Font.GothamBold
				t.TextScaled = true
				t.TextColor3 = Color3.fromRGB(70, 90, 190)
				t.Text = title .. " · 공사 중"
				t.Parent = g
			end
		end
		if i == 1 then label(w, title .. " (공사 중)", Color3.fromRGB(70, 90, 190), 8, 0.7) end
	end
	-- tower crane in the back corner
	local cx, cz = x1 - 4, z1 - 4
	box("CraneMast", cx - 1, 0, cz - 1, cx + 1, 46, cz + 1, Color3.fromRGB(240, 180, 30), { parent = m })
	local jib = part("CraneJib", Vector3.new(1.4, 1.4, 34), CFrame.new(cx, 46.7, cz) * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, -11), Color3.fromRGB(240, 180, 30), { parent = m })
	jib.CanCollide = false
	box("CraneCab", cx - 1.5, 43, cz - 1.5, cx + 1.5, 46, cz + 1.5, Color3.fromRGB(60, 60, 60), { parent = m })
	box("CraneCounterweight", cx - 1.5, 45, cz + 4, cx + 1.5, 48, cz + 9, Color3.fromRGB(120, 120, 120), { parent = m })
	-- traffic cones along the front
	for x = x0 + 3, x1 - 3, 6 do
		local cone = part("Cone", Vector3.new(1.2, 2, 1.2), CFrame.new(x, 1, z0 - 2), Color3.fromRGB(255, 110, 30), { parent = m })
		cone.CanCollide = false
	end
	m.Parent = T
end
construction(-24, 36, 14, 66, "소품샵 예정")

-- convenience store with automatic sliding doors and a counter (front = north, to the west road)
do
	local x0, z0, x1, z1, H = -140, 36, -100, 68, 14
	local S = Instance.new("Model")
	S.Name = "ConvenienceStore"
	S.Parent = T
	local wallC = Color3.fromRGB(240, 240, 238)
	walk(x0, 24, x1, z0) -- forecourt up to the sidewalk
	box("StoreFloor", x0, 0, z0, x1, CURB, z1, Color3.fromRGB(235, 235, 235), { parent = S, material = Enum.Material.Marble })
	box("WallBack", x0, CURB, z1 - 0.6, x1, H, z1, wallC, { parent = S })
	box("WallW", x0, CURB, z0, x0 + 0.6, H, z1, wallC, { parent = S })
	box("WallE", x1 - 0.6, CURB, z0, x1, H, z1, wallC, { parent = S })
	box("Roof", x0 - 0.5, H, z0 - 1, x1 + 0.5, H + 1, z1 + 0.5, Color3.fromRGB(70, 70, 75), { parent = S })
	-- glass front with a door gap in the middle (8 wide)
	local mid = (x0 + x1) / 2
	box("FrontGlass", x0, CURB, z0, mid - 4, H - 3, z0 + 0.4, Color3.fromRGB(200, 230, 240), { parent = S, material = Enum.Material.Glass, transparency = 0.5 })
	box("FrontGlass", mid + 4, CURB, z0, x1, H - 3, z0 + 0.4, Color3.fromRGB(200, 230, 240), { parent = S, material = Enum.Material.Glass, transparency = 0.5 })
	box("DoorHeader", x0, H - 3, z0, x1, H, z0 + 0.4, Color3.fromRGB(70, 70, 75), { parent = S })
	-- sign band (no real brand)
	local sign = box("StoreSign", x0, H - 2.6, z0 - 0.6, x1, H - 0.4, z0, Color3.fromRGB(30, 110, 205), { parent = S, material = Enum.Material.Neon })
	box("StoreSignStripe", x0, H - 3.2, z0 - 0.7, x1, H - 2.6, z0, Color3.fromRGB(255, 255, 255), { parent = S, material = Enum.Material.Neon })
	-- half-lowered roller shutter over the west window (reference video)
	for k = 0, 5 do box("Shutter", x0 + 0.6, H - 3.2 - k * 0.8, z0 - 0.35, mid - 5, H - 2.5 - k * 0.8, z0 - 0.05, Color3.fromRGB(150 + (k % 2) * 20, 152 + (k % 2) * 20, 158 + (k % 2) * 20), { parent = S }) end
	-- picnic tables on the forecourt
	for _, px in ipairs({ x0 + 6, x1 - 10 }) do
		box("PicnicTable", px, CURB + 2.8, 27, px + 6, CURB + 3.1, 32, Color3.fromRGB(70, 50, 40), { parent = S })
		box("PicnicLeg", px + 2.8, CURB, 28.5, px + 3.2, CURB + 2.8, 30.5, Color3.fromRGB(40, 40, 40), { parent = S })
		for _, bz in ipairs({ 25.6, 33.4 }) do
			local seatP = Instance.new("Seat")
			seatP.Name = "PicnicBench"
			seatP.Anchored = true
			seatP.Size = Vector3.new(6, 0.4, 1.4)
			seatP.CFrame = CFrame.lookAt(Vector3.new(px + 3, CURB + 1.7, bz), Vector3.new(px + 3, CURB + 1.7, 29.5))
			seatP.Color = Color3.fromRGB(70, 50, 40)
			seatP.Parent = S
			CS:AddTag(seatP, "PromptSeat")
		end
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = sign
	local st = Instance.new("TextLabel")
	st.Size = UDim2.fromScale(1, 1)
	st.BackgroundTransparency = 1
	st.Font = Enum.Font.GothamBlack
	st.TextScaled = true
	st.TextColor3 = Color3.new(1, 1, 1)
	st.Text = "OHU 24 편의점"
	st.Parent = sg
	-- automatic doors: two glass panels that slide apart (AutoDoorController)
	local door = Instance.new("Model")
	door.Name = "AutoDoor"
	door:SetAttribute("Range", 9)
	for _, s in ipairs({ -1, 1 }) do
		local panel = box("DoorPanel", mid + s * 4, CURB, z0 + 0.05, mid, H - 3, z0 + 0.35, Color3.fromRGB(190, 225, 240), { parent = door, material = Enum.Material.Glass, transparency = 0.45 })
		panel:SetAttribute("Slide", Vector3.new(s * 3.8, 0, 0))
		box("DoorFrame", mid + s * 4 - 0.15, CURB, z0, mid + s * 4 + 0.15, H - 3, z0 + 0.4, Color3.fromRGB(150, 150, 155), { parent = S })
	end
	door.WorldPivot = CFrame.new(mid, CURB + 4, z0)
	door.Parent = S
	CS:AddTag(door, "AutoDoor")
	-- counter by the door with a register, shelves, drink fridges at the back
	box("Counter", x1 - 12, CURB, z0 + 3, x1 - 2, CURB + 3.6, z0 + 6, Color3.fromRGB(250, 250, 250), { parent = S })
	box("CounterTop", x1 - 12.3, CURB + 3.6, z0 + 2.7, x1 - 1.7, CURB + 3.9, z0 + 6.3, Color3.fromRGB(30, 110, 205), { parent = S })
	box("Register", x1 - 6, CURB + 3.9, z0 + 4, x1 - 4, CURB + 5.3, z0 + 5.5, Color3.fromRGB(40, 40, 45), { parent = S })
	box("CardKeypad", x1 - 9, CURB + 3.9, z0 + 3.2, x1 - 7.6, CURB + 4.2, z0 + 4.4, Color3.fromRGB(225, 225, 230), { parent = S })
	box("CigaretteShelfBack", x1 - 12, CURB, z0 + 9, x1 - 2, CURB + 8, z0 + 10, Color3.fromRGB(220, 220, 225), { parent = S })
	for i = 0, 2 do
		local sx = x0 + 6 + i * 8
		box("Shelf", sx, CURB, z0 + 10, sx + 2.5, CURB + 5.5, z1 - 8, Color3.fromRGB(230, 230, 232), { parent = S })
		for k = 1, 3 do box("Goods", sx - 0.3, CURB + k * 1.6, z0 + 10.5, sx + 2.8, CURB + k * 1.6 + 1, z1 - 8.5, SIGNS[((i + k) % #SIGNS) + 1], { parent = S }) end
	end
	box("Fridge", x0 + 2, CURB, z1 - 3.5, x1 - 2, CURB + 9, z1 - 0.6, Color3.fromRGB(170, 215, 235), { parent = S, material = Enum.Material.Glass, transparency = 0.25 })
	for fx = x0 + 2, x1 - 2, 4 do box("FridgeFrame", fx - 0.2, CURB, z1 - 3.7, fx + 0.2, CURB + 9, z1 - 3.4, Color3.fromRGB(120, 125, 135), { parent = S }) end
	local fl = box("FridgeLight", x0 + 2, CURB + 9, z1 - 3.6, x1 - 2, CURB + 9.4, z1 - 0.6, Color3.fromRGB(240, 250, 255), { parent = S, material = Enum.Material.Neon })
	local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 10 sl.Brightness = 1.2 sl.Parent = fl
	local ceil = box("CeilingLight", x0 + 4, H - 0.4, z0 + 4, x1 - 4, H - 0.2, z1 - 4, Color3.fromRGB(250, 252, 255), { parent = S, material = Enum.Material.Neon })
	local cl = Instance.new("SurfaceLight") cl.Face = Enum.NormalId.Bottom cl.Range = 16 cl.Brightness = 1 cl.Parent = ceil
	label(sign, "편의점", Color3.fromRGB(30, 120, 90), 4, 0.7)
end

-- BUS STOP on the east road (reference video): shelter, lit ad panel, wooden bench
do
	local x0, x1, z0, z1 = 76, 90, 16.5, 23.5
	local B = Instance.new("Model")
	B.Name = "BusStop"
	B.Parent = T
	local frameC = Color3.fromRGB(45, 45, 50)
	for _, x in ipairs({ x0, x1 }) do box("ShelterPost", x - 0.3, CURB, z1 - 0.6, x + 0.3, CURB + 9, z1, frameC, { parent = B }) end
	box("ShelterRoof", x0 - 0.5, CURB + 9, z0, x1 + 0.5, CURB + 9.5, z1 + 0.3, Color3.fromRGB(170, 200, 215), { parent = B, material = Enum.Material.Glass, transparency = 0.3 })
	box("ShelterBack", x0 + 4, CURB + 1, z1 - 0.4, x1, CURB + 8, z1 - 0.2, Color3.fromRGB(190, 215, 225), { parent = B, material = Enum.Material.Glass, transparency = 0.5 })
	local ad = box("AdPanel", x0, CURB, z1 - 0.8, x0 + 4, CURB + 8, z1 - 0.2, Color3.fromRGB(250, 250, 250), { parent = B, material = Enum.Material.Neon })
	local g = Instance.new("SurfaceGui") g.Face = Enum.NormalId.Front g.LightInfluence = 0 g.Parent = ad
	local l = Instance.new("TextLabel") l.Size = UDim2.fromScale(1, 1) l.BackgroundTransparency = 1 l.Font = Enum.Font.GothamBold l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(60, 60, 70) l.Text = "광고 문의\nOHU 광고" l.Parent = g
	box("BenchFrame", x0 + 5, CURB, z1 - 2.6, x1 - 1, CURB + 1.6, z1 - 1, frameC, { parent = B })
	local bench = Instance.new("Seat")
	bench.Name = "BusBench"
	bench.Anchored = true
	bench.Size = Vector3.new(x1 - x0 - 6, 0.4, 1.8)
	bench.CFrame = CFrame.lookAt(Vector3.new((x0 + 5 + x1 - 1) / 2, CURB + 1.8, z1 - 1.8), Vector3.new((x0 + 5 + x1 - 1) / 2, CURB + 1.8, z0 - 5))
	bench.Color = Color3.fromRGB(190, 120, 60)
	bench.Parent = B
	CS:AddTag(bench, "PromptSeat")
	label(ad, "🚌 버스 정류장", Color3.fromRGB(40, 90, 160), 7, 0.6)
end

-- CLUB ENTRANCE dressing (reference video): queue line with red ropes, pop-up
-- tent, blue neon lines and a digital clock board on the club wall
do
	local K = Instance.new("Model")
	K.Name = "ClubEntranceDressing"
	K.Parent = T
	for _, x in ipairs({ -33, -27 }) do
		local last: Vector3? = nil
		for zz = -150, -112, 6 do
			local top = Vector3.new(x, 3.2, zz)
			vcyl("Stanchion", Vector3.new(x, 0.14, zz), 0.4, 3, Color3.fromRGB(200, 170, 80), { parent = K })
			if last then
				local rope = part("Rope", Vector3.new(0.25, 0.25, (top - last).Magnitude), CFrame.lookAt((top + last) / 2 - Vector3.new(0, 0.3, 0), top - Vector3.new(0, 0.3, 0)), Color3.fromRGB(180, 20, 30), { parent = K })
				rope.CanCollide = false
			end
			last = top
		end
	end
	-- pop-up tent
	for _, c in ipairs({ { -34, -104 }, { -26, -104 }, { -34, -96 }, { -26, -96 } }) do vcyl("TentLeg", Vector3.new(c[1], 0.14, c[2]), 0.3, 8, Color3.fromRGB(230, 230, 235), { parent = K }) end
	local tent = box("TentRoof", -35, 8, -105, -25, 8.4, -95, Color3.fromRGB(245, 245, 250), { parent = K })
	tent.CanCollide = false
	part("TentPeak", Vector3.new(10, 1.6, 10), CFrame.new(-30, 9.2, -100), Color3.fromRGB(245, 245, 250), { parent = K, material = Enum.Material.Fabric }).CanCollide = false
	for _, zz in ipairs({ -200, -144 }) do box("NeonLine", -11.4, 0.2, zz - 0.25, -10.9, 24, zz + 0.25, Color3.fromRGB(40, 80, 255), { parent = K, material = Enum.Material.Neon }) end
	local clock = box("ClockBoard", -11.6, 9, -134, -11.1, 13, -120, Color3.fromRGB(10, 10, 15), { parent = K })
	local g = Instance.new("SurfaceGui") g.Face = Enum.NormalId.Left g.LightInfluence = 0 g.Brightness = 2 g.Parent = clock
	local l = Instance.new("TextLabel") l.Size = UDim2.fromScale(1, 1) l.BackgroundTransparency = 1 l.Font = Enum.Font.Michroma l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(80, 230, 255) l.Text = "OPEN 22:00" l.Parent = g
end

-- ALLEY between two towers (reference video): dumpsters, trash bags, a fire
-- barrel and a purple neon roller shutter
do
	local A = Instance.new("Model")
	A.Name = "Alley"
	A.Parent = T
	box("AlleyFloor", 133, 0, -380, 183, 0.1, -370, Color3.fromRGB(60, 58, 60), { parent = A, material = Enum.Material.Asphalt })
	for _, dx in ipairs({ 138, 146 }) do
		box("Dumpster", dx, 0, -379, dx + 6, 3.4, -375, Color3.fromRGB(40, 90, 55), { parent = A })
		box("DumpsterLid", dx - 0.1, 3.4, -379.2, dx + 6.1, 3.7, -374.8, Color3.fromRGB(30, 70, 45), { parent = A })
	end
	for k = 0, 4 do part("TrashBag", Vector3.new(1.8, 1.5, 1.8), CFrame.new(154 + k * 1.6, 0.75, -376 + (k % 2)), Color3.fromRGB(25, 25, 28), { parent = A, shape = Enum.PartType.Ball }) end
	local barrel = vcyl("FireBarrel", Vector3.new(172, 0.1, -376), 2.4, 3.2, Color3.fromRGB(90, 60, 40), { parent = A })
	local fire = part("FireGlow", Vector3.new(1.6, 1.2, 1.6), CFrame.new(172, 3.9, -376), Color3.fromRGB(255, 140, 40), { parent = A, material = Enum.Material.Neon, shape = Enum.PartType.Ball })
	fire.CanCollide = false
	local fl = Instance.new("PointLight") fl.Color = Color3.fromRGB(255, 150, 60) fl.Range = 16 fl.Brightness = 1.5 fl.Parent = fire
	local sh = box("NeonShutter", 150, 0.1, -370.6, 168, 9, -370.1, Color3.fromRGB(150, 60, 230), { parent = A, material = Enum.Material.Neon, transparency = 0.15 })
	sh.CanCollide = false
	local pl = Instance.new("PointLight") pl.Color = Color3.fromRGB(170, 80, 255) pl.Range = 18 pl.Brightness = 1.2 pl.Parent = sh
end

-- subway exits at the roundabout corners: step on the pad → "몇 번 출구로
-- 가시겠습니까?" (SubwayService). Tag SubwayExit, ExitNumber, ExitName, Out.
local EXITS = {
	{ 1, "클럽", Color3.fromRGB(255, 122, 214), 29, -29 },
	{ 2, "한옥 마을", Color3.fromRGB(185, 135, 74), 29, 29 },
	{ 3, "공원 놀이기구", Color3.fromRGB(76, 175, 80), -29, -29 },
	{ 4, "해변 · 카페", Color3.fromRGB(42, 143, 179), -29, 29 },
}
for _, e in ipairs(EXITS) do
	local pos = C + Vector3.new(e[4], CURB, e[5])
	local out = Vector3.new(e[4], 0, e[5]).Unit
	local pad = part("SubwayExit" .. e[1], Vector3.new(7, 0.4, 7), CFrame.lookAt(pos + Vector3.new(0, 0.2, 0), pos + Vector3.new(0, 0.2, 0) + out), e[3], { material = Enum.Material.Neon })
	pad:SetAttribute("ExitNumber", e[1])
	pad:SetAttribute("ExitName", e[2])
	pad:SetAttribute("Out", out)
	CS:AddTag(pad, "SubwayExit")
	local sign = part("ExitSign" .. e[1], Vector3.new(1, 8, 1), CFrame.new(pos - out * 5 + Vector3.new(0, 4, 0)), Color3.fromRGB(46, 125, 50))
	label(sign, e[1] .. "번 출구 · " .. e[2], e[3], 6, 0.8)
end

-- sunset photo frame at the end of the north pier, facing the sea (west)
local frameCol = Color3.fromRGB(255, 150, 90)
local px, pz = -344, 122 -- end of the sunset pier (moved north of the bigger beach cafe)
part("SunsetFramePostN", Vector3.new(1, 10, 1), CFrame.new(px, 6, pz + 5), frameCol, { material = Enum.Material.Neon })
part("SunsetFramePostS", Vector3.new(1, 10, 1), CFrame.new(px, 6, pz - 5), frameCol, { material = Enum.Material.Neon })
local top = part("SunsetFrameTop", Vector3.new(1, 1, 11), CFrame.new(px, 11.5, pz), frameCol, { material = Enum.Material.Neon })
label(top, "석양 포토 스팟 (서쪽 바다)", frameCol, 4, 0.8)

-- spawn on the lawn in the middle of the roundabout
if spawn then
	if not spawn:GetAttribute("OldPosition") then spawn:SetAttribute("OldPosition", spawn.Position) end
	spawn.CFrame = CFrame.new(C.X, 1.1, C.Z)
end
T.Parent = workspace
return "applied v5 (big roads, sidewalks, towers, store), MODE=revert to undo"
