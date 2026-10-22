-- TEMPORARY layout test v7 (docs/02_WORLDS/HONGDAE_LAYOUT.md "v7", user 2026-10-22):
--   * 강남역 사거리 instead of the roundabout (videos): wide roads with central
--     bus lanes, lane lines / arrows, crosswalks, yellow safety zones, planters
--   * subway exits 1-4 = real stair entrances coming up in the arrow direction
--     (pads keep the exit picker), spawn in front of exit 1
--   * 4 bus stops that teleport between each other (BusStop pads)
--   * 광안리 seafront: 2-lane road + red lane, promenade with round pine
--     planters, bollards, drains, crosswalks, 광안대교 in the sea
--   * 광화문 at the hanok village west entrance, stone plaza + lawn + 해태,
--     mountains behind the village
--   * 에버랜드-style amusement park gate, ticket booth, info booth, perimeter
--     wall, round symbol plaza inside
-- Run in the Studio command bar (Edit mode). MODE: "apply" / "revert".
-- Orientation = the Studio top view: screen up = -Z (north), right = +X (east).
-- The sun rises at +X and sets at -X (over the sea).
local MODE = ... or "apply"

local root = workspace:WaitForChild("Graybox_MainSocial")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local HIDE = "Hongdae_v1_HiddenParts"
local function R(deg) return CFrame.Angles(0, math.rad(deg), 0) end

-- crossroads centre C = (0,0). Big roads: asphalt 48 (bus 8+8 in the middle,
-- 2 car lanes of 8 each side), sidewalks 10 → buildings start 36 from the axes.
local MOVES = {
	["02_Club"] = CFrame.new(109, 0, -172) * R(-90) * CFrame.new(0, 0, 210), -- entrance faces west (club street)
	["03_Rooftop_Backstage"] = CFrame.new(109, 0, -366) * R(180) * CFrame.new(-125, 0, 160), -- runway behind the club
	["07_Hanok_Village"] = CFrame.new(161, 0, 126) * R(-90) * CFrame.new(-175, 0, -230), -- main gate east, back gate west (광화문)
	["08_PhotoBooth"] = CFrame.new(-126, 0, 51), -- 인생네컷 below the club
	["06_Park_Playground"] = CFrame.new(-455, 0, -171), -- amusement park north-west
	["05_Cafe"] = CFrame.new(-123.5, 0, 175) * R(-90) * CFrame.new(130, 0, -185), -- Glasshouse south-west
}
-- ground holes: club + the four subway stair pits (x0, z0, x1, z1)
local HOLES = {
	{ 49, -252, 169, -92 },
	{ 26, -59, 32, -41 }, { -32, -59, -26, -41 }, -- exits 1, 3 (come up northwards)
	{ 26, 41, 32, 59 }, { -32, 41, -26, 59 }, -- exits 2, 4 (come up southwards)
}
local MOUNTAINS = { -- terrain hills behind the hanok village (centre, radius)
	{ Vector3.new(400, -55, 60), 95 }, { Vector3.new(470, -60, 175), 110 }, { Vector3.new(420, -55, 295), 95 },
	{ Vector3.new(290, -70, 370), 90 }, { Vector3.new(150, -75, 390), 90 },
}

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
	local old = workspace:FindFirstChild("Hongdae_v1_Temp")
	if old then
		if old:GetAttribute("Mountains") then
			for _, m in ipairs(MOUNTAINS) do workspace.Terrain:FillBall(m[1], m[2] + 1, Enum.Material.Air) end
		end
		old:Destroy()
	end
	if spawn and spawn:GetAttribute("OldPosition") then
		spawn.CFrame = CFrame.new(spawn:GetAttribute("OldPosition"))
		spawn:SetAttribute("OldPosition", nil)
	end
end

if MODE == "revert" then
	revert()
	return "reverted (zones back to BuiltPivot, hidden parts restored, temp model + hills removed)"
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

-- ground with holes: split x / z at every hole edge, keep the cells outside
-- the holes, merge runs along x (old ground: x -268..1024, z -1024..1024)
if groundTemplate then
	local y, h = groundTemplate.Position.Y, groundTemplate.Size.Y
	local xs, zs = { -268, 1024 }, { -1024, 1024 }
	for _, o in ipairs(HOLES) do table.insert(xs, o[1]) table.insert(xs, o[3]) table.insert(zs, o[2]) table.insert(zs, o[4]) end
	table.sort(xs) table.sort(zs)
	local function inHole(x, z)
		for _, o in ipairs(HOLES) do if x > o[1] and x < o[3] and z > o[2] and z < o[4] then return true end end
		return false
	end
	local function slab(xa, xb, za, zb)
		local g = groundTemplate:Clone()
		g.Name = "Ground"
		g.Size = Vector3.new(xb - xa, h, zb - za)
		g.CFrame = CFrame.new((xa + xb) / 2, y, (za + zb) / 2)
		g:SetAttribute("HomeZone", nil)
		g.Parent = T
	end
	for j = 1, #zs - 1 do
		local z0, z1 = zs[j], zs[j + 1]
		if z1 > z0 then
			local runStart: number? = nil
			for i = 1, #xs - 1 do
				local xa, xb = xs[i], xs[i + 1]
				if xb > xa then
					local solid = not inHole((xa + xb) / 2, (z0 + z1) / 2)
					if solid and not runStart then runStart = xa end
					if not solid and runStart then slab(runStart, xa, z0, z1) runStart = nil end
				end
			end
			if runStart then slab(runStart, xs[#xs], z0, z1) end
		end
	end
end

------------------------------------------------------------------ helpers
local function part(name, size, cf, color, opt)
	local p = Instance.new((opt and opt.class) or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opt and opt.transparency) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt and opt.shape then p.Shape = opt.shape end
	if opt and opt.nocol then p.CanCollide = false end
	p.Parent = (opt and opt.parent) or T
	return p
end
local function box(name, x0, y0, z0, x1, y1, z1, color, opt)
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local ly, hy = math.min(y0, y1), math.max(y0, y1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	return part(name, Vector3.new(hx - lx, hy - ly, hz - lz), CFrame.new((lx + hx) / 2, (ly + hy) / 2, (lz + hz) / 2), color, opt)
end
local function vcyl(name, pos: Vector3, d, h, color, opt) -- pos = bottom centre
	local o = {}
	for k, v in pairs(opt or {}) do o[k] = v end
	o.shape = Enum.PartType.Cylinder
	return part(name, Vector3.new(h, d, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, o)
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
local function surfaceText(p: BasePart, face, text, color, font, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.Brightness = 1.5
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = if bg then 0 else 1
	if bg then l.BackgroundColor3 = bg end
	l.Font = font or Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = g
end
local function seat(name, cf, size, color, parent)
	local s = Instance.new("Seat")
	s.Name = name
	s.Anchored = true
	s.Size = size
	s.CFrame = cf
	s.Color = color
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = parent or T
	CS:AddTag(s, "PromptSeat")
	return s
end

local ASPHALT = Color3.fromRGB(70, 70, 74)
local WALK = Color3.fromRGB(165, 158, 152)
local CURB = 0.6
local WHITE = Color3.fromRGB(240, 240, 240)
local YELLOW = Color3.fromRGB(240, 190, 40)
local BLUE = Color3.fromRGB(40, 90, 200)
local SIGNS = { Color3.fromRGB(230, 60, 70), Color3.fromRGB(40, 120, 220), Color3.fromRGB(250, 200, 40), Color3.fromRGB(60, 180, 90), Color3.fromRGB(240, 120, 40) }
local function paint(name, x0, z0, x1, z1, color) return box(name, x0, 0.12, z0, x1, 0.16, z1, color, { nocol = true }) end
local function walk(x0, z0, x1, z1) return box("Sidewalk", x0, 0, z0, x1, CURB, z1, WALK, { material = Enum.Material.Brick }) end

local function streetLamp(base: Vector3, toward: Vector3)
	vcyl("LampPole", base, 0.6, 16, Color3.fromRGB(60, 62, 66))
	local tip = base + toward * 3 + Vector3.new(0, 16, 0)
	part("LampArm", Vector3.new(0.4, 0.4, 3), CFrame.lookAt(base + toward * 1.5 + Vector3.new(0, 16, 0), tip), Color3.fromRGB(60, 62, 66), { nocol = true })
	local head = part("LampHead", Vector3.new(1.6, 0.5, 1.6), CFrame.new(tip - Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 225, 160), { material = Enum.Material.Neon, nocol = true })
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 26
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 215, 160)
	light.Parent = head
end
local function trafficLight(base: Vector3, toward: Vector3, reach)
	vcyl("SignalPole", base, 1, 18, Color3.fromRGB(70, 75, 80))
	local tip = base + toward * reach + Vector3.new(0, 17, 0)
	part("SignalArm", Vector3.new(0.6, 0.6, reach), CFrame.lookAt(base + toward * reach / 2 + Vector3.new(0, 17, 0), tip), Color3.fromRGB(70, 75, 80), { nocol = true })
	local head = part("SignalHead", Vector3.new(4.2, 1.5, 1.2), CFrame.lookAt(tip - Vector3.new(0, 1.2, 0), tip - Vector3.new(0, 1.2, 0) + toward:Cross(Vector3.yAxis)), Color3.fromRGB(25, 25, 25), { nocol = true })
	for i, c in ipairs({ Color3.fromRGB(255, 60, 50), Color3.fromRGB(255, 190, 40), Color3.fromRGB(60, 230, 110) }) do
		part("SignalLamp", Vector3.new(0.9, 0.9, 0.3), head.CFrame * CFrame.new((i - 2) * 1.3, 0, -0.65), c, { material = Enum.Material.Neon, nocol = true })
	end
end
local function planter(pos: Vector3, along: Vector3)
	local cf = CFrame.lookAt(pos, pos + along)
	part("Planter", Vector3.new(2.4, 1.4, 7), cf * CFrame.new(0, CURB + 0.7, 0), Color3.fromRGB(110, 105, 100), { material = Enum.Material.Concrete })
	part("Hedge", Vector3.new(2.2, 1.6, 6.6), cf * CFrame.new(0, CURB + 2.1, 0), Color3.fromRGB(70, 140, 60), { material = Enum.Material.Grass })
end
-- painted arrow on the road (pointing along dir)
local function arrow(pos: Vector3, dir: Vector3, turn)
	local cf = CFrame.lookAt(pos + Vector3.new(0, 0.14, 0), pos + Vector3.new(0, 0.14, 0) + dir)
	part("Arrow", Vector3.new(0.8, 0.04, 8), cf, WHITE, { nocol = true })
	local headCf = cf * CFrame.new(0, 0, -5)
	part("ArrowHead", Vector3.new(0.7, 0.04, 3), headCf * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, 1), WHITE, { nocol = true })
	part("ArrowHead", Vector3.new(0.7, 0.04, 3), headCf * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(0, 0, 1), WHITE, { nocol = true })
	if turn then part("ArrowTurn", Vector3.new(0.8, 0.04, 4), cf * CFrame.new(-1.6, 0, -1) * CFrame.Angles(0, math.rad(-60), 0), WHITE, { nocol = true }) end
end

local CAR_COLORS = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(25, 25, 30), Color3.fromRGB(150, 155, 160), Color3.fromRGB(40, 60, 110), Color3.fromRGB(160, 30, 35) }
local carCount = 0
local carDesigns = (SS:FindFirstChild("Cars") and SS.Cars:GetChildren()) or {}
table.sort(carDesigns, function(a, b) return a.Name < b.Name end)
local function car(pos: Vector3, along: Vector3)
	carCount += 1
	if #carDesigns > 0 then -- Creator Store cars picked by the user (anchored, scripts removed, 15 long)
		local c = carDesigns[((carCount - 1) % #carDesigns) + 1]:Clone()
		c:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 0.12, 0), pos + Vector3.new(0, 0.12, 0) + along))
		c.Parent = T
		return
	end
	local m = Instance.new("Model")
	m.Name = "Car"
	local cf = CFrame.lookAt(pos, pos + along)
	local col = CAR_COLORS[(carCount % #CAR_COLORS) + 1]
	part("Body", Vector3.new(6.4, 2.4, 14), cf * CFrame.new(0, 2.1, 0), col, { parent = m })
	part("Cabin", Vector3.new(5.8, 2.2, 7.5), cf * CFrame.new(0, 4.4, 0.6), Color3.fromRGB(35, 40, 50), { parent = m, material = Enum.Material.Glass })
	for _, w in ipairs({ { -3.1, -4.5 }, { 3.1, -4.5 }, { -3.1, 4.5 }, { 3.1, 4.5 } }) do
		part("Wheel", Vector3.new(1.2, 2.6, 2.6), cf * CFrame.new(w[1], 1.3, w[2]), Color3.fromRGB(20, 20, 20), { parent = m, shape = Enum.PartType.Cylinder })
	end
	m.Parent = T
end

------------------------------------------------------- 강남역 사거리 (crossroads)
box("IntersectionRoad", -24, 0, -24, 24, 0.12, 24, ASPHALT, { material = Enum.Material.Asphalt })
for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do walk(s[1] * 24, s[2] * 24, s[1] * 34, s[2] * 34) end
for _, o in ipairs({ -24, 24 }) do paint("JunctionLine", -24, o - 0.2, 24, o + 0.2, YELLOW) paint("JunctionLine", o - 0.2, -24, o + 0.2, 24, YELLOW) end

-- a big road from the crossroads; dir = ±X/±Z; u along, v across (+v = right of dir)
-- pits = sidewalk cut-outs for stair pits {u0, u1, v0, v1}; cars = {u, v}
-- sidewalk areas kept free of lamps / planters (entrances)
local KEEP_CLEAR = { { -196, -40, -104, -20 } } -- park gate
local function clear(p: Vector3)
	for _, k in ipairs(KEEP_CLEAR) do if p.X > k[1] and p.X < k[3] and p.Z > k[2] and p.Z < k[4] then return false end end
	return true
end
local function bigRoad(dir: Vector3, len: number, pits, cars)
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local function at(u, v) return dir * u + across * v end
	local function uv(name, u0, v0, u1, v1, y0, y1, color, opt)
		local a, b = at(u0, v0), at(u1, v1)
		return box(name, a.X, y0, a.Z, b.X, y1, b.Z, color, opt)
	end
	uv("Road", 24, -24, len, 24, 0, 0.12, ASPHALT, { material = Enum.Material.Asphalt })
	for _, side in ipairs({ -1, 1 }) do
		local v0, v1 = if side < 0 then -34 else 24, if side < 0 then -24 else 34
		local cuts = {}
		for _, p in ipairs(pits) do if p[3] >= v0 and p[4] <= v1 then table.insert(cuts, p) end end
		table.sort(cuts, function(a, b) return a[1] < b[1] end)
		local u = 34
		for _, p in ipairs(cuts) do
			uv("Sidewalk", u, v0, p[1], v1, 0, CURB, WALK, { material = Enum.Material.Brick })
			uv("Sidewalk", p[1], v0, p[2], p[3], 0, CURB, WALK, { material = Enum.Material.Brick })
			uv("Sidewalk", p[1], p[4], p[2], v1, 0, CURB, WALK, { material = Enum.Material.Brick })
			u = p[2]
		end
		uv("Sidewalk", u, v0, len, v1, 0, CURB, WALK, { material = Enum.Material.Brick })
	end
	local function line(name, v, col, dashed)
		if dashed then
			for u = 40, len - 6, 12 do uv(name, u, v - 0.2, u + 6, v + 0.2, 0.12, 0.16, col, { nocol = true }) end
		else
			uv(name, 38, v - 0.2, len, v + 0.2, 0.12, 0.16, col, { nocol = true })
		end
	end
	line("CenterLine", -0.45, YELLOW) line("CenterLine", 0.45, YELLOW)
	line("BusLane", -8, BLUE) line("BusLane", 8, BLUE)
	line("LaneDash", -16, WHITE, true) line("LaneDash", 16, WHITE, true)
	for v = -22.5, 22.5, 3 do uv("Crosswalk", 26, v - 0.75, 34, v + 0.75, 0.12, 0.16, WHITE, { nocol = true }) end
	uv("StopLine", 36, 0, 36.6, 24, 0.12, 0.16, WHITE, { nocol = true })
	arrow(at(46, 12), -dir, true) arrow(at(46, 20), -dir, false)
	-- yellow safety zone (안전지대) at the median start
	for u = 39, 57, 3 do
		local a = at(u, 0) + Vector3.new(0, 0.15, 0)
		part("SafetyStripe", Vector3.new(0.4, 0.04, 4), CFrame.lookAt(a, a + dir + across), YELLOW, { nocol = true })
	end
	uv("SafetyEdge", 38, -1.8, 58, -1.5, 0.12, 0.16, YELLOW, { nocol = true }) uv("SafetyEdge", 38, 1.5, 58, 1.8, 0.12, 0.16, YELLOW, { nocol = true })
	for u = 62, len - 6, 18 do
		local free = true
		for _, p in ipairs(pits) do if u > p[1] - 6 and u < p[2] + 6 then free = false end end
		if free then for _, v in ipairs({ -25.5, 25.5 }) do if clear(at(u, v)) then planter(at(u, v), dir) end end end
	end
	for u = 70, len - 6, 40 do
		if clear(at(u, -32.5)) then streetLamp(at(u, -32.5) + Vector3.new(0, CURB, 0), across) end
		if clear(at(u, 32.5)) then streetLamp(at(u, 32.5) + Vector3.new(0, CURB, 0), -across) end
	end
	trafficLight(at(38, 30) + Vector3.new(0, CURB, 0), -across, 26)
	for _, c in ipairs(cars) do car(at(c[1], c[2]), if c[2] > 0 then -dir else dir) end
end
bigRoad(Vector3.new(0, 0, -1), 470, { { 41, 59, 26, 32 }, { 41, 59, -32, -26 } }, { { 48, 12 }, { 66, 20 } }) -- north
bigRoad(Vector3.new(0, 0, 1), 300, { { 41, 59, 26, 32 }, { 41, 59, -32, -26 } }, { { 48, 20 }, { 120, -12 } }) -- south
bigRoad(Vector3.new(1, 0, 0), 260, {}, { { 46, 12 }, { 64, 12 }, { 90, -20 } }) -- east
bigRoad(Vector3.new(-1, 0, 0), 158, {}, { { 48, 20 }, { 80, -12 } }) -- west, to the seafront road

local function smallRoad(a: Vector2, b: Vector2)
	local dir = Vector3.new(b.X - a.X, 0, b.Y - a.Y)
	local len = dir.Magnitude
	dir = dir.Unit
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local o = Vector3.new(a.X, 0, a.Y)
	local function bx(name, u0, v0, u1, v1, y0, y1, color, opt)
		local p, q = o + dir * u0 + across * v0, o + dir * u1 + across * v1
		return box(name, p.X, y0, p.Z, q.X, y1, q.Z, color, opt)
	end
	bx("Road", 0, -6, len, 6, 0, 0.12, ASPHALT, { material = Enum.Material.Asphalt })
	bx("Sidewalk", 0, -10, len, -6, 0, CURB, WALK, { material = Enum.Material.Brick })
	bx("Sidewalk", 0, 6, len, 10, 0, CURB, WALK, { material = Enum.Material.Brick })
	for u = 4, len - 6, 10 do bx("LaneDash", u, -0.15, u + 5, 0.15, 0.12, 0.16, WHITE, { nocol = true }) end
end
smallRoad(Vector2.new(181, -34), Vector2.new(181, -470)) -- east of the club
smallRoad(Vector2.new(-34, 98), Vector2.new(-150, 98)) -- south-west, to the seafront
-- lane from the east road to the hanok main gate (east side, gate at x 225, z 126)
local LANE = Color3.fromRGB(185, 160, 122)
box("HanokLane", 232, 0, 34, 240, 0.3, 130, LANE, { material = Enum.Material.Slate })
box("HanokLane2", 225, 0, 122, 240, 0.3, 130, LANE, { material = Enum.Material.Slate })

------------------------------------------------------- subway exits (stairs)
-- stairs come up in the arrow direction under a glass canopy that slopes
-- down toward the back; the pad is the landing at the bottom of the stairs
-- (like going down to the platform): step on it → exit picker; arrivals
-- appear at the foot of the stairs and walk up (user 2026-10-22)
local EXITS = {
	{ 1, "클럽", Color3.fromRGB(255, 122, 214), 29, -50, Vector3.new(0, 0, -1) },
	{ 2, "한옥 마을", Color3.fromRGB(185, 135, 74), 29, 50, Vector3.new(0, 0, 1) },
	{ 3, "놀이공원", Color3.fromRGB(76, 175, 80), -29, -50, Vector3.new(0, 0, -1) },
	{ 4, "광안리 해변 · 카페", Color3.fromRGB(42, 143, 179), -29, 50, Vector3.new(0, 0, 1) },
}
local exitPads, exitMouths = {}, {}
for _, e in ipairs(EXITS) do
	local m = Instance.new("Model")
	m.Name = "SubwayExit" .. e[1]
	m.Parent = T
	local out = e[6]
	local c = Vector3.new(e[4], 0, e[5]) -- pit centre: 6 wide, 18 long (u -9..9 along out)
	local side = Vector3.new(1, 0, 0)
	local function at(u) return c + out * u end
	local bottom = CURB - 10 * 0.86
	for k = 1, 10 do -- stairs from the mouth (u 9) down to u -3
		local a, b = at(9 - (k - 1) * 1.2), at(9 - k * 1.2)
		box("Step", a.X - 3, -9, a.Z, b.X + 3, CURB - k * 0.86, b.Z, Color3.fromRGB(150, 150, 155), { parent = m, material = Enum.Material.Concrete })
	end
	local l0, l1 = at(-3), at(-9)
	box("Landing", l0.X - 3, -9, l0.Z, l1.X + 3, bottom, l1.Z, Color3.fromRGB(120, 120, 128), { parent = m, material = Enum.Material.Concrete })
	box("PitWallL", c.X - 3.4, -9, c.Z - 9, c.X - 3, CURB, c.Z + 9, Color3.fromRGB(200, 200, 205), { parent = m })
	box("PitWallR", c.X + 3, -9, c.Z - 9, c.X + 3.4, CURB, c.Z + 9, Color3.fromRGB(200, 200, 205), { parent = m })
	local back = at(-9)
	local bw = box("PitBack", back.X - 3, -9, back.Z - 0.2, back.X + 3, CURB + 2.6, back.Z + 0.2, Color3.fromRGB(40, 40, 45), { parent = m })
	surfaceText(bw, if out.Z < 0 then Enum.NormalId.Front else Enum.NormalId.Back, "🚇 승강장\n발판을 밟으면 출구 선택", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	-- canopy: high at the mouth (+5.2), low at the back (+2.6)
	local hiY, loY = CURB + 5.2, CURB + 2.6
	for _, sx in ipairs({ -1, 1 }) do
		local front, rear = at(9) + side * (sx * 3.2), at(-9) + side * (sx * 3.2)
		vcyl("ShelterPost", front + Vector3.new(0, CURB, 0), 0.3, hiY - CURB, Color3.fromRGB(110, 115, 120), { parent = m })
		vcyl("ShelterPost", rear + Vector3.new(0, CURB, 0), 0.3, loY - CURB, Color3.fromRGB(110, 115, 120), { parent = m })
		box("ShelterGlass", c.X + sx * 3.2 - 0.1, CURB, c.Z - 9, c.X + sx * 3.2 + 0.1, loY, c.Z + 9, Color3.fromRGB(190, 220, 230), { parent = m, material = Enum.Material.Glass, transparency = 0.55 })
		local mid = c + side * (sx * 3.2) + Vector3.new(0, loY + (hiY - loY) / 2, 0)
		part("ShelterGlassTop", Vector3.new(0.2, hiY - loY, 18), CFrame.lookAt(mid, mid - out), Color3.fromRGB(190, 220, 230), { parent = m, class = "WedgePart", material = Enum.Material.Glass, transparency = 0.55 })
	end
	local rTop, rBack = at(9) + Vector3.new(0, hiY, 0), at(-9) + Vector3.new(0, loY, 0)
	part("ShelterRoof", Vector3.new(7, 0.3, (rTop - rBack).Magnitude), CFrame.lookAt((rTop + rBack) / 2, rTop), Color3.fromRGB(170, 205, 220), { parent = m, material = Enum.Material.Glass, transparency = 0.35 })
	-- number pole (blue / yellow, like a Seoul exit sign) next to the mouth
	local mouth = at(9)
	local polePos = mouth + side * 5 * math.sign(e[4]) + out * 1
	vcyl("ExitPole", polePos + Vector3.new(0, CURB, 0), 0.5, 8, Color3.fromRGB(40, 110, 200), { parent = m })
	local sign = box("ExitNumberSign", polePos.X - 0.9, CURB + 6, polePos.Z - 0.9, polePos.X + 0.9, CURB + 10.5, polePos.Z + 0.9, Color3.fromRGB(40, 110, 200), { parent = m })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do surfaceText(sign, face, tostring(e[1]), Color3.new(1, 1, 1), Enum.Font.GothamBlack) end
	box("ExitPoleBand", polePos.X - 0.95, CURB + 5.4, polePos.Z - 0.95, polePos.X + 0.95, CURB + 6, polePos.Z + 0.95, YELLOW, { parent = m })
	label(sign, e[1] .. "번 출구 · " .. e[2], e[3], 4, 0.8)
	local hedgePos = c + side * 6.5 * math.sign(e[4])
	box("ExitHedge", hedgePos.X - 0.8, CURB, hedgePos.Z - 8, hedgePos.X + 0.8, CURB + 1.8, hedgePos.Z + 8, Color3.fromRGB(70, 140, 60), { parent = m, material = Enum.Material.Grass })
	-- the landing pad (exit picker)
	local padPos = at(-6) + Vector3.new(0, bottom + 0.2, 0)
	local pad = part("SubwayExitPad", Vector3.new(6, 0.4, 6), CFrame.lookAt(padPos, padPos + out), e[3], { parent = m, material = Enum.Material.Neon })
	pad:SetAttribute("ExitNumber", e[1])
	pad:SetAttribute("ExitName", e[2])
	pad:SetAttribute("Out", out) -- arrivals step off toward the stairs (up)
	CS:AddTag(pad, "SubwayExit")
	exitPads[e[1]] = pad
	exitMouths[e[1]] = mouth
end
------------------------------------------------------- bus stops (4)
local function busStop(n, name, center: Vector3, roadDir: Vector3, along: Vector3)
	local m = Instance.new("Model")
	m.Name = "BusStop" .. n
	m.Parent = T
	local base = center + Vector3.new(0, CURB, 0)
	local cf = CFrame.lookAt(base, base + roadDir) -- -Z local = toward the road
	local frameC = Color3.fromRGB(45, 45, 50)
	for _, s in ipairs({ -6, 6 }) do part("ShelterPost", Vector3.new(0.5, 9, 0.5), cf * CFrame.new(s, 4.5, 1.6), frameC, { parent = m }) end
	part("ShelterRoof", Vector3.new(14, 0.4, 5), cf * CFrame.new(0, 9.2, 0), Color3.fromRGB(170, 200, 215), { parent = m, material = Enum.Material.Glass, transparency = 0.3 })
	part("ShelterBack", Vector3.new(9, 6.5, 0.2), cf * CFrame.new(1.5, 4, 1.8), Color3.fromRGB(190, 215, 225), { parent = m, material = Enum.Material.Glass, transparency = 0.5 })
	local ad = part("AdPanel", Vector3.new(3.6, 7.5, 0.6), cf * CFrame.new(-4.6, 3.75, 1.8), Color3.fromRGB(250, 250, 250), { parent = m, material = Enum.Material.Neon })
	surfaceText(ad, Enum.NormalId.Front, "광고 문의\nOHU 광고", Color3.fromRGB(60, 60, 70), Enum.Font.GothamBold)
	part("BenchFrame", Vector3.new(8, 1.6, 1.4), cf * CFrame.new(1.5, 0.8, 0.9), frameC, { parent = m })
	seat("BusBench", cf * CFrame.new(1.5, 1.8, 0.9), Vector3.new(8, 0.4, 1.6), Color3.fromRGB(190, 120, 60), m)
	local info = part("RouteBoard", Vector3.new(1.6, 6, 0.3), cf * CFrame.new(7.5, 3, 1.6), Color3.fromRGB(30, 80, 150), { parent = m })
	surfaceText(info, Enum.NormalId.Front, "BUS\n" .. name, Color3.new(1, 1, 1), Enum.Font.GothamBold)
	local padPos = base + roadDir * 2.6 + along * 9 + Vector3.new(0, 0.2, 0)
	local pad = part("BusStopPad", Vector3.new(5, 0.4, 5), CFrame.lookAt(padPos, padPos + along), Color3.fromRGB(60, 160, 255), { parent = m, material = Enum.Material.Neon })
	pad:SetAttribute("ExitNumber", n)
	pad:SetAttribute("ExitName", name)
	pad:SetAttribute("Out", along)
	CS:AddTag(pad, "BusStop")
	label(info, "🚌 " .. name .. " 정류장", Color3.fromRGB(60, 140, 230), 6, 0.7)
end
busStop(1, "OHU CLUB 앞", Vector3.new(-31, 0, -130), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1))
busStop(2, "고층 빌딩가", Vector3.new(130, 0, 31), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))
busStop(3, "한옥 마을 · 광화문", Vector3.new(31, 0, 230), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
busStop(4, "광안리 해변", Vector3.new(-153, 0, 150), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))

------------------------------------------------------- 광안리 seafront
do
	local z0, z1 = -30, 300
	box("Promenade", -198, 0, z0, -182, CURB, z1, Color3.fromRGB(175, 135, 120), { material = Enum.Material.Brick })
	box("SeaRoad", -182, 0, 34, -158, 0.12, z1, ASPHALT, { material = Enum.Material.Asphalt })
	box("SeaRoadJoin", -182, 0, -24, -158, 0.12, 34, ASPHALT, { material = Enum.Material.Asphalt }) -- T-junction with the west road
	paint("RedLane", -182, 34, -174, z1, Color3.fromRGB(190, 85, 75))
	paint("EdgeLine", -174.2, 34, -173.8, z1, WHITE)
	paint("CenterLine", -166.5, 34, -166.1, z1, YELLOW) paint("CenterLine", -165.9, 34, -165.5, z1, YELLOW)
	walk(-158, 34, -150, z1)
	for _, cz in ipairs({ 60, 180, 260 }) do
		for x = -181, -159, 3 do paint("Crosswalk", x, cz - 4, x + 1.5, cz + 4, WHITE) end
	end
	for zz = 40, z1 - 6, 18 do -- drains along both curbs
		for _, x in ipairs({ -181.4, -158.6 }) do
			box("Drain", x - 0.6, 0.12, zz, x + 0.6, 0.15, zz + 2.4, Color3.fromRGB(35, 35, 38), { nocol = true })
			for k = 0, 3 do box("DrainBar", x - 0.6, 0.15, zz + 0.3 + k * 0.6, x + 0.6, 0.17, zz + 0.45 + k * 0.6, Color3.fromRGB(90, 90, 95), { nocol = true }) end
		end
	end
	for zz = z0 + 4, z1 - 2, 7 do vcyl("Bollard", Vector3.new(-183.5, CURB, zz), 1.1, 1.6, Color3.fromRGB(150, 145, 140), { material = Enum.Material.Slate }) end
	local function pine(pos: Vector3)
		vcyl("PlanterRing", pos + Vector3.new(0, CURB, 0), 8, 1.4, Color3.fromRGB(170, 160, 150), { material = Enum.Material.Slate })
		vcyl("PlanterSoil", pos + Vector3.new(0, CURB, 0), 6.6, 1.5, Color3.fromRGB(120, 95, 70), { material = Enum.Material.Ground })
		local base = pos + Vector3.new(0, CURB + 1.5, 0)
		local trunkTop = pos + Vector3.new(1.2, 13, 0.6)
		part("PineTrunk", Vector3.new(0.9, 0.9, (trunkTop - base).Magnitude), CFrame.lookAt((base + trunkTop) / 2, trunkTop), Color3.fromRGB(120, 85, 60), { material = Enum.Material.Wood })
		for k, o in ipairs({ { 0, 0, 0, 7 }, { 2, -1.5, 1, 5 }, { -1.6, -1, -1.4, 4.6 }, { 0.8, 1.6, -0.6, 4 } }) do
			part("PineCanopy", Vector3.new(o[4], o[4], o[4]), CFrame.new(trunkTop + Vector3.new(o[1], o[2], o[3])), Color3.fromRGB(40 + k * 6, 90 + k * 4, 50), { material = Enum.Material.Grass, nocol = true, shape = Enum.PartType.Ball })
		end
		for k = 0, 3 do
			local a = k * math.pi / 2
			local foot = pos + Vector3.new(math.cos(a) * 3, CURB + 1.4, math.sin(a) * 3)
			local tip = pos + Vector3.new(0, 7, 0)
			part("PineSupport", Vector3.new(0.25, 0.25, (tip - foot).Magnitude), CFrame.lookAt((foot + tip) / 2, tip), Color3.fromRGB(110, 80, 55), { nocol = true })
		end
	end
	for zz = z0 + 14, z1 - 10, 30 do if math.abs(zz - 61) > 8 then pine(Vector3.new(-190, 0, zz)) end end
	for zz = z0 + 10, z1, 40 do streetLamp(Vector3.new(-196.5, CURB, zz), Vector3.new(1, 0, 0)) end
	for zz = z0 + 28, z1, 60 do
		box("BenchBase", -197.5, CURB, zz, -195.5, CURB + 1.6, zz + 6, Color3.fromRGB(110, 110, 115))
		seat("PromenadeBench", CFrame.lookAt(Vector3.new(-196.5, CURB + 1.8, zz + 3), Vector3.new(-260, CURB + 1.8, zz + 3)), Vector3.new(2, 0.4, 6), Color3.fromRGB(160, 110, 70))
	end
	-- 광안대교 (suspension bridge) out in the sea, lit purple at night
	local bx, deckY = -820, 34
	local purple = Color3.fromRGB(190, 90, 255)
	box("BridgeDeck", bx - 10, deckY - 2, -760, bx + 10, deckY, 760, Color3.fromRGB(200, 200, 205))
	for _, s in ipairs({ -1, 1 }) do box("BridgeLight", bx + s * 10 - 0.3, deckY - 2.5, -760, bx + s * 10 + 0.3, deckY - 1.8, 760, purple, { material = Enum.Material.Neon, nocol = true }) end
	for _, tz in ipairs({ -260, 260 }) do
		for _, s in ipairs({ -1, 1 }) do box("BridgeTowerLeg", bx + s * 9 - 2, -24, tz - 2, bx + s * 9 + 2, 150, tz + 2, Color3.fromRGB(215, 215, 220)) end
		box("BridgeTowerBeam", bx - 11, 120, tz - 2, bx + 11, 126, tz + 2, Color3.fromRGB(215, 215, 220))
		box("BridgeTowerBeam", bx - 11, 70, tz - 2, bx + 11, 75, tz + 2, Color3.fromRGB(215, 215, 220))
	end
	for _, s in ipairs({ -1, 1 }) do
		local pts = {}
		for k = 0, 24 do
			local zz = -760 + k * (1520 / 24)
			local y
			if math.abs(zz) <= 260 then y = deckY + 12 + (150 - deckY - 12) * (zz / 260) ^ 2 else y = 150 - (150 - deckY - 4) * ((math.abs(zz) - 260) / 500) end
			table.insert(pts, Vector3.new(bx + s * 9, y, zz))
		end
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			part("BridgeCable", Vector3.new(0.8, 0.8, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), purple, { material = Enum.Material.Neon, nocol = true })
		end
	end
	label(box("BridgeLabel", bx - 1, 160, -1, bx + 1, 161, 1, purple, { transparency = 1, nocol = true }), "광안대교", purple, 0, 1)
end

------------------------------------------------------- 광화문 + plaza + 해태 + hills
do
	local G = Instance.new("Model")
	G.Name = "Gwanghwamun"
	G.Parent = T
	local stone = Color3.fromRGB(185, 178, 165)
	local granite = Color3.fromRGB(200, 196, 188)
	local wood = Color3.fromRGB(150, 55, 40)
	local roofC = Color3.fromRGB(60, 62, 66)
	local gx0, gx1, gz0, gz1 = 82, 96, 128, 184 -- in front of the village back wall (gate at z 156)
	local H = 12
	-- stone base with 3 arched openings (centre 10 wide, sides 6)
	local cuts = { gz0, 137, 143, 151, 161, 169, 175, gz1 }
	for i = 1, #cuts - 1, 2 do box("GateStone", gx0, 0, cuts[i], gx1, H, cuts[i + 1], stone, { parent = G, material = Enum.Material.Slate }) end
	for _, o in ipairs({ { 151, 161, 9 }, { 137, 143, 7 }, { 169, 175, 7 } }) do
		box("GateStoneTop", gx0, o[3], o[1], gx1, H, o[2], stone, { parent = G, material = Enum.Material.Slate })
		box("ArchTrim", gx0 - 0.2, o[3] - 0.6, o[1], gx0, o[3], o[2], Color3.fromRGB(120, 115, 105), { parent = G })
	end
	box("PavilionFloor", gx0 + 1, H, gz0 + 4, gx1 - 1, H + 1, gz1 - 4, granite, { parent = G })
	for zz = gz0 + 6, gz1 - 6, 8 do
		for _, xx in ipairs({ gx0 + 2.5, gx1 - 2.5 }) do vcyl("PavilionColumn", Vector3.new(xx, H + 1, zz), 1, 7, wood, { parent = G }) end
	end
	box("PavilionWall", gx0 + 3, H + 5, gz0 + 6, gx1 - 3, H + 8, gz1 - 6, Color3.fromRGB(60, 120, 90), { parent = G })
	local function hipRoof(y, x0, x1, z0, z1, rise)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local w, d = x1 - x0, z1 - z0
		part("RoofSlope", Vector3.new(d, rise, w / 2), CFrame.new(cx - w / 4, y + rise / 2, cz) * CFrame.Angles(0, math.rad(90), 0), roofC, { parent = G, class = "WedgePart", material = Enum.Material.Slate })
		part("RoofSlope", Vector3.new(d, rise, w / 2), CFrame.new(cx + w / 4, y + rise / 2, cz) * CFrame.Angles(0, math.rad(-90), 0), roofC, { parent = G, class = "WedgePart", material = Enum.Material.Slate })
		box("RoofRidge", cx - 0.5, y + rise, z0 + 2, cx + 0.5, y + rise + 0.8, z1 - 2, Color3.fromRGB(230, 230, 230), { parent = G })
		box("Eave", x0, y - 0.4, z0, x1, y, z1, roofC, { parent = G })
	end
	hipRoof(H + 8, gx0 - 3, gx1 + 3, gz0 + 1, gz1 - 1, 4)
	box("UpperFloor", gx0 + 2, H + 12, gz0 + 10, gx1 - 2, H + 15, gz1 - 10, wood, { parent = G })
	hipRoof(H + 15, gx0 - 1, gx1 + 1, gz0 + 6, gz1 - 6, 5)
	local plaque = box("NamePlaque", gx0 - 0.4, H + 12.4, 152, gx0 - 0.1, H + 14.6, 160, Color3.fromRGB(30, 30, 35), { parent = G })
	surfaceText(plaque, Enum.NormalId.Left, "光化門", Color3.fromRGB(230, 200, 120), Enum.Font.Antique)
	label(plaque, "광화문 (한옥 마을 서쪽 입구)", Color3.fromRGB(150, 60, 40), 8, 0.9)
	-- plaza in front: stone paving, central path, lawns on both sides
	box("PlazaStone", 34, 0, 106, 82, 0.3, 206, granite, { parent = G, material = Enum.Material.Slate })
	box("PlazaPath", 34, 0.3, 148, 82, 0.35, 164, Color3.fromRGB(215, 210, 200), { parent = G, material = Enum.Material.Slate })
	box("PlazaLawn", 38, 0.3, 110, 66, 0.45, 142, Color3.fromRGB(90, 165, 80), { parent = G, material = Enum.Material.Grass })
	box("PlazaLawn", 38, 0.3, 170, 66, 0.45, 202, Color3.fromRGB(90, 165, 80), { parent = G, material = Enum.Material.Grass })
	local function haetae(pos: Vector3, facing: Vector3)
		local cf = CFrame.lookAt(pos, pos + facing)
		local c1, c2 = Color3.fromRGB(170, 165, 155), Color3.fromRGB(160, 155, 145)
		part("HaetaePedestal", Vector3.new(4, 5, 5), cf * CFrame.new(0, 2.5, 0), stone, { parent = G, material = Enum.Material.Slate })
		part("HaetaeBody", Vector3.new(2.6, 2.6, 3.6), cf * CFrame.new(0, 6.3, 0.3), c1, { parent = G, material = Enum.Material.Slate })
		part("HaetaeChest", Vector3.new(2.4, 3, 1.6), cf * CFrame.new(0, 7.4, -1.2), c1, { parent = G, material = Enum.Material.Slate })
		part("HaetaeHead", Vector3.new(2.6, 2.6, 2.6), cf * CFrame.new(0, 9.6, -1.6), c1, { parent = G, material = Enum.Material.Slate, shape = Enum.PartType.Ball })
		part("HaetaeMane", Vector3.new(3, 2, 1.2), cf * CFrame.new(0, 9.2, -0.6), c2, { parent = G, material = Enum.Material.Slate })
		part("HaetaeHorn", Vector3.new(0.5, 1, 0.5), cf * CFrame.new(0, 11.2, -1.6), c2, { parent = G })
		for _, lx in ipairs({ -0.8, 0.8 }) do part("HaetaeLeg", Vector3.new(0.7, 2, 0.7), cf * CFrame.new(lx, 6, -1.6), c2, { parent = G, material = Enum.Material.Slate }) end
	end
	haetae(Vector3.new(74, 0.3, 140), Vector3.new(-1, 0, 0))
	haetae(Vector3.new(74, 0.3, 172), Vector3.new(-1, 0, 0))
	for _, mnt in ipairs(MOUNTAINS) do
		workspace.Terrain:FillBall(mnt[1], mnt[2], Enum.Material.Grass)
		workspace.Terrain:FillBall(mnt[1] + Vector3.new(0, mnt[2] * 0.55, 0), mnt[2] * 0.35, Enum.Material.Rock)
	end
	T:SetAttribute("Mountains", true)
end

------------------------------------------------------- 에버랜드-style park gate
do
	local E = Instance.new("Model")
	E.Name = "AmusementParkGate"
	E.Parent = T
	local cream = Color3.fromRGB(245, 235, 210)
	local blue = Color3.fromRGB(70, 110, 170)
	local roofBlue = Color3.fromRGB(60, 90, 140)
	local x0, x1, z0, z1 = -258, -42, -280, -60
	local gateX0, gateX1 = -192, -108
	-- perimeter wall: parks are closed off by themed walls so the outside is
	-- hidden and everyone enters through the main gate
	local function wallSeg(ax, az, bx, bz)
		box("ParkWall", ax, 0, az, bx, 12, bz, cream, { parent = E })
		box("ParkWallTop", ax - 0.3, 12, az - 0.3, bx + 0.3, 13, bz + 0.3, roofBlue, { parent = E })
	end
	wallSeg(x0, z0, x0 + 1, z1) wallSeg(x1 - 1, z0, x1, z1) wallSeg(x0, z0, x1, z0 + 1)
	wallSeg(x0, z1 - 1, gateX0, z1) wallSeg(gateX1, z1 - 1, x1, z1)
	local function turret(cx, cz, s, h, base)
		box("Turret", cx - s / 2, base or 0, cz - s / 2, cx + s / 2, h, cz + s / 2, cream, { parent = E })
		box("TurretBand", cx - s / 2 - 0.2, h - 1, cz - s / 2 - 0.2, cx + s / 2 + 0.2, h, cz + s / 2 + 0.2, blue, { parent = E })
		for k = 0, 3 do
			part("TurretRoof", Vector3.new(s + 1, s * 0.8, (s + 1) / 2), CFrame.new(cx, h + s * 0.4, cz) * CFrame.Angles(0, math.rad(k * 90), 0) * CFrame.new(0, 0, (s + 1) / 4), roofBlue, { parent = E, class = "WedgePart" })
		end
		vcyl("Pinnacle", Vector3.new(cx, h + s * 0.8, cz), 0.4, 3, Color3.fromRGB(220, 190, 90), { parent = E })
	end
	for _, c in ipairs({ { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } }) do turret(c[1], c[2], 8, 16) end
	local gz0, gz1 = z1 - 2, z1 + 6
	local n = 7
	local w = (gateX1 - gateX0) / n
	for i = 0, n do box("GatePier", gateX0 + i * w - 1.5, 0, gz0, gateX0 + i * w + 1.5, 16, gz1, cream, { parent = E }) end
	for i = 0, n - 1 do
		local ax = gateX0 + i * w
		box("ArchTop", ax + 1.5, 10, gz0, ax + w - 1.5, 16, gz1, cream, { parent = E })
		box("ArchTrim", ax + 1.5, 9.4, gz1, ax + w - 1.5, 10, gz1 + 0.3, blue, { parent = E })
		box("ArchWindow", ax + w / 2 - 1.5, 11.5, gz1, ax + w / 2 + 1.5, 14.5, gz1 + 0.2, Color3.fromRGB(120, 150, 190), { parent = E })
	end
	part("GateRoof", Vector3.new(gateX1 - gateX0 + 4, 4, 5), CFrame.new((gateX0 + gateX1) / 2, 18, gz0 + 2) * CFrame.Angles(0, math.rad(180), 0), roofBlue, { parent = E, class = "WedgePart" })
	box("GateCornice", gateX0 - 2, 16, gz0 - 0.5, gateX1 + 2, 16.6, gz1 + 0.5, Color3.fromRGB(230, 220, 195), { parent = E })
	turret(gateX0 - 4, (gz0 + gz1) / 2, 7, 22) turret(gateX1 + 4, (gz0 + gz1) / 2, 7, 22)
	turret((gateX0 + gateX1) / 2, (gz0 + gz1) / 2, 7, 24, 16) -- centre tower sits on the gate roof (keeps the middle arch open)
	local sign = box("GateSign", -164, 17, gz1 + 0.6, -136, 21, gz1 + 1, Color3.fromRGB(255, 250, 235), { parent = E })
	surfaceText(sign, Enum.NormalId.Back, "OHU LAND", Color3.fromRGB(60, 90, 140), Enum.Font.FredokaOne)
	label(sign, "놀이공원 정문", Color3.fromRGB(60, 90, 140), 8, 0.9)
	local function booth(bx0, bz0, bx1, bz1, title, windows)
		box("BoothBody", bx0, 0, bz0, bx1, 9, bz1, cream, { parent = E })
		box("BoothBase", bx0 - 0.3, 0, bz0 - 0.3, bx1 + 0.3, 1.5, bz1 + 0.3, blue, { parent = E })
		for k = 0, 3 do
			part("BoothRoof", Vector3.new(bx1 - bx0 + 2, 4, (bz1 - bz0 + 2) / 2), CFrame.new((bx0 + bx1) / 2, 11, (bz0 + bz1) / 2) * CFrame.Angles(0, math.rad(k * 90), 0) * CFrame.new(0, 0, (bz1 - bz0 + 2) / 4), roofBlue, { parent = E, class = "WedgePart" })
		end
		local ww = (bx1 - bx0) / windows
		for k = 0, windows - 1 do
			box("BoothWindow", bx0 + k * ww + 0.8, 3, bz1, bx0 + (k + 1) * ww - 0.8, 7, bz1 + 0.2, Color3.fromRGB(150, 190, 220), { parent = E, material = Enum.Material.Glass })
			box("BoothSill", bx0 + k * ww + 0.6, 2.8, bz1, bx0 + (k + 1) * ww - 0.6, 3.1, bz1 + 0.8, blue, { parent = E })
		end
		local b = box("BoothSign", bx0 + 1, 7.4, bz1 + 0.2, bx1 - 1, 8.8, bz1 + 0.4, blue, { parent = E })
		surfaceText(b, Enum.NormalId.Back, title, Color3.new(1, 1, 1), Enum.Font.GothamBold)
		label(b, title, Color3.fromRGB(60, 90, 140), 6, 0.6)
	end
	booth(-226, -58, -206, -48, "매표소 TICKETS", 3)
	booth(-94, -56, -84, -48, "i 안내", 1)
	-- inside: round symbol plaza (round flower bed + a pedestal for the park's
	-- landmark / character sculpture, to be designed)
	local pc = Vector3.new(-150, 0, -95)
	vcyl("SymbolPlaza", pc, 50, 0.35, Color3.fromRGB(215, 205, 190), { parent = E, material = Enum.Material.Slate })
	vcyl("FlowerBed", pc + Vector3.new(0, 0.35, 0), 24, 1.4, Color3.fromRGB(90, 160, 80), { parent = E, material = Enum.Material.Grass })
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		part("Flower", Vector3.new(1.6, 1.6, 1.6), CFrame.new(pc + Vector3.new(math.cos(a) * 10, 2.3, math.sin(a) * 10)), SIGNS[(k % #SIGNS) + 1], { parent = E, shape = Enum.PartType.Ball, nocol = true })
	end
	local ped = vcyl("SymbolPedestal", pc + Vector3.new(0, 1.75, 0), 8, 2, Color3.fromRGB(235, 230, 220), { parent = E })
	label(ped, "★ 상징물 자리 (캐릭터 조형물 예정)", Color3.fromRGB(200, 120, 40), 6, 0.8)
	box("GatePlaza", gateX0 - 8, 0, -34, gateX1 + 8, 0.3, gz1, Color3.fromRGB(215, 205, 190), { parent = E, material = Enum.Material.Slate })
end

------------------------------------------------------- club facade (references)
do
	local K = Instance.new("Model")
	K.Name = "ClubFacade"
	K.Parent = T
	box("ClubStreet", 36, 0, -252, 49, 0.14, -36, Color3.fromRGB(70, 60, 90), { parent = K })
	box("FacadePanel", 48.2, 13, -205, 48.9, 34, -139, Color3.fromRGB(28, 28, 34), { parent = K, material = Enum.Material.DiamondPlate })
	local sign = box("ClubSign", 47.6, 20, -196, 48.2, 30, -148, Color3.fromRGB(15, 15, 25), { parent = K })
	surfaceText(sign, Enum.NormalId.Left, "OHU CLUB", Color3.fromRGB(90, 160, 255), Enum.Font.Michroma)
	local glow = Instance.new("SurfaceLight") glow.Face = Enum.NormalId.Left glow.Color = Color3.fromRGB(80, 140, 255) glow.Range = 20 glow.Brightness = 2 glow.Parent = sign
	for _, zz in ipairs({ -205, -139 }) do box("NeonEdge", 47.8, 0.2, zz - 0.3, 48.4, 34, zz + 0.3, Color3.fromRGB(40, 80, 255), { parent = K, material = Enum.Material.Neon }) end
	for _, zz in ipairs({ -182, -162 }) do box("DoorFrameGold", 47.8, 0.2, zz - 0.4, 48.6, 12, zz + 0.4, Color3.fromRGB(230, 180, 80), { parent = K, material = Enum.Material.Neon }) end
	box("DoorLintelGold", 47.8, 12, -182.4, 48.6, 12.8, -161.6, Color3.fromRGB(230, 180, 80), { parent = K, material = Enum.Material.Neon })
	for _, x in ipairs({ 39, 45 }) do
		local last: Vector3? = nil
		for zz = -150, -112, 6 do
			local top = Vector3.new(x, 3.2, zz)
			vcyl("Stanchion", Vector3.new(x, 0.14, zz), 0.4, 3, Color3.fromRGB(200, 170, 80), { parent = K })
			if last then part("Rope", Vector3.new(0.25, 0.25, (top - last).Magnitude), CFrame.lookAt((top + last) / 2 - Vector3.new(0, 0.3, 0), top - Vector3.new(0, 0.3, 0)), Color3.fromRGB(180, 20, 30), { parent = K, nocol = true }) end
			last = top
		end
	end
	for _, c in ipairs({ { 37.5, -104 }, { 47.5, -104 }, { 37.5, -94 }, { 47.5, -94 } }) do vcyl("TentLeg", Vector3.new(c[1], 0.14, c[2]), 0.3, 8, Color3.fromRGB(230, 230, 235), { parent = K }) end
	box("TentRoof", 37, 8, -105, 48, 8.4, -93, Color3.fromRGB(245, 245, 250), { parent = K, nocol = true })
	local clock = box("ClockBoard", 48.2, 9, -134, 48.7, 13, -120, Color3.fromRGB(10, 10, 15), { parent = K })
	surfaceText(clock, Enum.NormalId.Left, "OPEN 22:00", Color3.fromRGB(80, 230, 255), Enum.Font.Michroma)
end

------------------------------------------------------- high-rises + shop fronts
local FACE = { W = Enum.NormalId.Left, E = Enum.NormalId.Right, N = Enum.NormalId.Front, S = Enum.NormalId.Back }
local function tower(x0, z0, x1, z1, h, kind, face, shop, screen)
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
	if face then
		local a, b
		if face == "W" then a, b = Vector3.new(x0 - 0.4, 0, z0 + 2), Vector3.new(x0, 0, z1 - 2)
		elseif face == "E" then a, b = Vector3.new(x1, 0, z0 + 2), Vector3.new(x1 + 0.4, 0, z1 - 2)
		elseif face == "N" then a, b = Vector3.new(x0 + 2, 0, z0 - 0.4), Vector3.new(x1 - 2, 0, z0)
		else a, b = Vector3.new(x0 + 2, 0, z1), Vector3.new(x1 - 2, 0, z1 + 0.4) end
		box("ShopGlass", a.X, 0, a.Z, b.X, 10, b.Z, Color3.fromRGB(35, 45, 55), { parent = m, material = Enum.Material.Glass })
		local out = if face == "W" then Vector3.new(-0.6, 0, 0) elseif face == "E" then Vector3.new(0.6, 0, 0) elseif face == "N" then Vector3.new(0, 0, -0.6) else Vector3.new(0, 0, 0.6)
		local board = box("ShopBoard", a.X + out.X, 10.4, a.Z + out.Z, b.X + out.X, 13.4, b.Z + out.Z, Color3.fromRGB(25, 25, 30), { parent = m })
		surfaceText(board, FACE[face], shop, SIGNS[(#shop % #SIGNS) + 1])
		if screen then -- big LED billboard (강남 towers)
			local s = box("LEDScreen", a.X + out.X * 1.5, h * 0.45, a.Z + out.Z * 1.5, b.X + out.X * 1.5, h * 0.45 + 20, b.Z + out.Z * 1.5, Color3.fromRGB(20, 20, 30), { parent = m })
			surfaceText(s, FACE[face], screen, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack, Color3.fromRGB(40, 90, 200))
		end
	end
	m.Parent = T
end
tower(193, -470, 243, -380, 150, "glass", "W", "OHU 타워", "OHU FASHION WEEK")
tower(193, -370, 243, -262, 96, "concrete", "W", "PC방")
tower(193, -252, 243, -170, 128, "glass", "W", "HOMME", "NEW SEASON")
tower(193, -160, 243, -36, 70, "concrete", "W", "뷰티 & 샵")
tower(250, -130, 310, -36, 110, "glass", "S", "OHU 마트", "인생네컷 SALE")
tower(-76, 110, -40, 170, 120, "glass", "E", "카페")
tower(-76, 180, -40, 250, 80, "concrete", "E", "약국")
tower(-146, 36, -126, 80, 60, "concrete", "N", "노래방")

do -- alley between two towers: dumpsters, bags, fire barrel, purple neon shutter
	local A = Instance.new("Model")
	A.Name = "Alley"
	A.Parent = T
	box("AlleyFloor", 193, 0, -380, 243, 0.1, -370, Color3.fromRGB(60, 58, 60), { parent = A, material = Enum.Material.Asphalt })
	for _, dx in ipairs({ 198, 206 }) do
		box("Dumpster", dx, 0, -379, dx + 6, 3.4, -375, Color3.fromRGB(40, 90, 55), { parent = A })
		box("DumpsterLid", dx - 0.1, 3.4, -379.2, dx + 6.1, 3.7, -374.8, Color3.fromRGB(30, 70, 45), { parent = A })
	end
	for k = 0, 4 do part("TrashBag", Vector3.new(1.8, 1.5, 1.8), CFrame.new(214 + k * 1.6, 0.75, -376 + (k % 2)), Color3.fromRGB(25, 25, 28), { parent = A, shape = Enum.PartType.Ball }) end
	vcyl("FireBarrel", Vector3.new(232, 0.1, -376), 2.4, 3.2, Color3.fromRGB(90, 60, 40), { parent = A })
	local fire = part("FireGlow", Vector3.new(1.6, 1.6, 1.6), CFrame.new(232, 3.9, -376), Color3.fromRGB(255, 140, 40), { parent = A, material = Enum.Material.Neon, shape = Enum.PartType.Ball, nocol = true })
	local fl = Instance.new("PointLight") fl.Color = Color3.fromRGB(255, 150, 60) fl.Range = 16 fl.Brightness = 1.5 fl.Parent = fire
	local sh = box("NeonShutter", 210, 0.1, -370.6, 228, 9, -370.1, Color3.fromRGB(150, 60, 230), { parent = A, material = Enum.Material.Neon, transparency = 0.15, nocol = true })
	local pl = Instance.new("PointLight") pl.Color = Color3.fromRGB(170, 80, 255) pl.Range = 18 pl.Brightness = 1.2 pl.Parent = sh
end

do -- construction site (future prop shop)
	local x0, z0, x1, z1, title = 36, 36, 74, 66, "소품샵 예정"
	local m = Instance.new("Model")
	m.Name = "ConstructionSite(" .. title .. ")"
	m.Parent = T
	box("Dirt", x0, 0, z0, x1, 0.2, z1, Color3.fromRGB(150, 120, 90), { parent = m, material = Enum.Material.Ground })
	local walls = {
		box("Hoarding", x0, 0, z0, x1, 9, z0 + 0.4, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x0, 0, z1 - 0.4, x1, 9, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x0, 0, z0, x0 + 0.4, 9, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x1 - 0.4, 0, z0, x1, 9, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
	}
	for _, w in ipairs(walls) do
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			if (face == Enum.NormalId.Front or face == Enum.NormalId.Back) == (w.Size.X > w.Size.Z) then
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
	end
	label(walls[1], title .. " (공사 중)", Color3.fromRGB(70, 90, 190), 8, 0.7)
	local cx, cz = x1 - 4, z1 - 4
	box("CraneMast", cx - 1, 0, cz - 1, cx + 1, 46, cz + 1, Color3.fromRGB(240, 180, 30), { parent = m })
	part("CraneJib", Vector3.new(1.4, 1.4, 34), CFrame.new(cx, 46.7, cz) * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, -11), Color3.fromRGB(240, 180, 30), { parent = m, nocol = true })
	box("CraneCab", cx - 1.5, 43, cz - 1.5, cx + 1.5, 46, cz + 1.5, Color3.fromRGB(60, 60, 60), { parent = m })
	for x = x0 + 3, x1 - 3, 6 do part("Cone", Vector3.new(1.2, 2, 1.2), CFrame.new(x, 1, z0 - 2), Color3.fromRGB(255, 110, 30), { parent = m, nocol = true }) end
end

do -- convenience store with automatic sliding doors (front = north, to the west road)
	local x0, z0, x1, z1, H = -120, 44, -80, 76, 14
	local S = Instance.new("Model")
	S.Name = "ConvenienceStore"
	S.Parent = T
	local wallC = Color3.fromRGB(240, 240, 238)
	walk(x0, 34, x1, z0)
	box("StoreFloor", x0, 0, z0, x1, CURB, z1, Color3.fromRGB(235, 235, 235), { parent = S, material = Enum.Material.Marble })
	box("WallBack", x0, CURB, z1 - 0.6, x1, H, z1, wallC, { parent = S })
	box("WallW", x0, CURB, z0, x0 + 0.6, H, z1, wallC, { parent = S })
	box("WallE", x1 - 0.6, CURB, z0, x1, H, z1, wallC, { parent = S })
	box("Roof", x0 - 0.5, H, z0 - 1, x1 + 0.5, H + 1, z1 + 0.5, Color3.fromRGB(70, 70, 75), { parent = S })
	local mid = (x0 + x1) / 2
	box("FrontGlass", x0, CURB, z0, mid - 4, H - 3, z0 + 0.4, Color3.fromRGB(200, 230, 240), { parent = S, material = Enum.Material.Glass, transparency = 0.5 })
	box("FrontGlass", mid + 4, CURB, z0, x1, H - 3, z0 + 0.4, Color3.fromRGB(200, 230, 240), { parent = S, material = Enum.Material.Glass, transparency = 0.5 })
	box("DoorHeader", x0, H - 3, z0, x1, H, z0 + 0.4, Color3.fromRGB(70, 70, 75), { parent = S })
	local sign = box("StoreSign", x0, H - 2.6, z0 - 0.6, x1, H - 0.4, z0, Color3.fromRGB(30, 110, 205), { parent = S, material = Enum.Material.Neon })
	surfaceText(sign, Enum.NormalId.Front, "OHU 24 편의점", Color3.new(1, 1, 1))
	box("StoreSignStripe", x0, H - 3.2, z0 - 0.7, x1, H - 2.6, z0, Color3.fromRGB(255, 255, 255), { parent = S, material = Enum.Material.Neon })
	for k = 0, 5 do box("Shutter", x0 + 0.6, H - 3.2 - k * 0.8, z0 - 0.35, mid - 5, H - 2.5 - k * 0.8, z0 - 0.05, Color3.fromRGB(150 + (k % 2) * 20, 152 + (k % 2) * 20, 158 + (k % 2) * 20), { parent = S }) end
	for _, px in ipairs({ x0 + 6, x1 - 10 }) do
		box("PicnicTable", px, CURB + 2.8, 37, px + 6, CURB + 3.1, 41, Color3.fromRGB(70, 50, 40), { parent = S })
		box("PicnicLeg", px + 2.8, CURB, 38, px + 3.2, CURB + 2.8, 40, Color3.fromRGB(40, 40, 40), { parent = S })
		for _, bz in ipairs({ 35.6, 42.4 }) do seat("PicnicBench", CFrame.lookAt(Vector3.new(px + 3, CURB + 1.7, bz), Vector3.new(px + 3, CURB + 1.7, 39)), Vector3.new(6, 0.4, 1.4), Color3.fromRGB(70, 50, 40), S) end
	end
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
	label(sign, "편의점", Color3.fromRGB(30, 110, 205), 4, 0.7)
end

do -- sunset photo frame at the end of the pier, facing the sea (west)
	local frameCol = Color3.fromRGB(255, 150, 90)
	local px, pz = -344, 122
	part("SunsetFramePostN", Vector3.new(1, 10, 1), CFrame.new(px, 6, pz + 5), frameCol, { material = Enum.Material.Neon })
	part("SunsetFramePostS", Vector3.new(1, 10, 1), CFrame.new(px, 6, pz - 5), frameCol, { material = Enum.Material.Neon })
	local top = part("SunsetFrameTop", Vector3.new(1, 1, 11), CFrame.new(px, 11.5, pz), frameCol, { material = Enum.Material.Neon })
	label(top, "석양 포토 스팟 (서쪽 바다)", frameCol, 4, 0.8)
end

-- first spawn: in front of exit 1 (players come up facing north)
if spawn then
	if not spawn:GetAttribute("OldPosition") then spawn:SetAttribute("OldPosition", spawn.Position) end
	local p = exitMouths[1] + Vector3.new(0, 0, -7)
	spawn.CFrame = CFrame.lookAt(Vector3.new(p.X, CURB + 0.5, p.Z), Vector3.new(p.X, CURB + 0.5, p.Z - 10))
end
T.Parent = workspace
return "applied v7 (강남 사거리, 광안리, 광화문, 놀이공원 정문), MODE=revert to undo"
