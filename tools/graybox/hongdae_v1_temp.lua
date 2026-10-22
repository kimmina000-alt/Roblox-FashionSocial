-- TEMPORARY layout test v2 (docs/02_WORLDS/HONGDAE_LAYOUT.md "v2").
-- Run in the Studio command bar (Edit mode). Set MODE below:
--   "apply"  → moves zones to the layout, hides the old ring plaza paths and
--              ground pieces, adds Workspace.Hongdae_v1_Temp (station, streets,
--              ground with the club hole in its new place, sunset photo spot)
--   "revert" → puts everything back exactly as built
-- Real compass in Roblox (Lighting:GetSunDirection, measured 2026-10-22):
-- the sun rises at +X (east) and sets at -X (west); at noon it leans to -Z
-- (south). So north = +Z. The sea is already in the west (-X): sunset over it.
local MODE = ... or "apply"

local root = workspace:WaitForChild("Graybox_MainSocial")
local SS = game:GetService("ServerStorage")
local HIDE = "Hongdae_v1_HiddenParts"
local function R(deg) return CFrame.Angles(0, math.rad(deg), 0) end

-- zone → world move applied to the zone's built pivot
-- v3 = v1's Hongdae streets + v2's compass (user, 2026-10-22)
local MOVES = {
	-- ① club: north-east at the end of the red road, entrance + neon to the south (plaza side)
	["02_Club"] = CFrame.new(170, 0, 240) * R(180) * CFrame.new(0, 0, 210),
	-- fashion week runway right next to the club (show / concert space)
	["03_Rooftop_Backstage"] = CFrame.new(175, 0, 410),
	-- ② hanok village: east/south-east, gate turned to the east (morning sun) onto the book street
	["07_Hanok_Village"] = CFrame.new(260, 0, -215) * R(-90) * CFrame.new(-175, 0, -230),
	-- ⑤ 인생네컷 on the red road, east of the plaza, sign facing the road
	["08_PhotoBooth"] = CFrame.new(-95, 0, 122),
	-- ④ park rides at the end of the Gyeongui forest path (north-west)
	["06_Park_Playground"] = CFrame.new(-365, 0, 330),
}
local HOLE = { 90, 180, 250, 300 } -- club ground hole x0, z0, x1, z1 (follows 02_Club)
-- parts set aside while the layout is applied (restored by revert)
local function shouldHide(zn, p)
	if zn == "09_Paths" then return true end
	if zn == "01_Plaza_Street" then return p.Name == "Loop" or p.Name == "Spoke" or p.Name:find("^BG_Building") ~= nil end
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
		spawn.Position = spawn:GetAttribute("OldPosition")
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
		if p:IsA("BasePart") and shouldHide(zn, p) then
			if p.Name == "Ground_N" then groundTemplate = p end
			p:SetAttribute("HomeZone", zn)
			p.Parent = hidden
		end
	end
end

local T = Instance.new("Model")
T.Name = "Hongdae_v1_Temp"

-- ground around the club's new hole (x -80..80, z 170..290); the old ground
-- spans x -268..1024, z -1024..1024
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
	p.Parent = (opt and opt.parent) or T
	return p
end
-- flat strip from a to b on the ground (x,z), width w
local function strip(name, a: Vector2, b: Vector2, w, color, y)
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, y or 0.06, mid.Y), Vector3.new(b.X, y or 0.06, b.Y))
	return part(name, Vector3.new(w, 0.12, (b - a).Magnitude), cf, color)
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
local function marker(text, x, z, color, y, scale)
	local p = part("Marker", Vector3.new(1, 1, 1), CFrame.new(x, y or 3, z), color, { transparency = 1 })
	p.CanCollide = false
	p.CanQuery = false
	label(p, text, color, 0, scale)
	return p
end

local GREY = Color3.fromRGB(150, 146, 140)
local RED = Color3.fromRGB(205, 75, 70)
local PURPLE = Color3.fromRGB(110, 85, 160)
local SAND = Color3.fromRGB(215, 200, 170)

-- 양화로 (east-west boulevard along X, south of the plaza; station on it)
strip("Yanghwaro", Vector2.new(-198, -100), Vector2.new(420, -100), 36, GREY)
for x = -180, 400, 24 do
	part("LaneDash", Vector3.new(10, 0.14, 0.6), CFrame.new(x, 0.08, -100), Color3.new(1, 1, 1))
end
marker("양화로", -150, -100, Color3.fromRGB(80, 80, 80), 2, 0.8)
marker("홍대 놀이터 광장", 0, 0, Color3.fromRGB(200, 150, 40), 10)

-- ① 걷고싶은거리·레드로드: station → north-east past the playground plaza and
-- 인생네컷 to 클럽거리 in front of the club (entrance + neon seen from the road)
strip("RedRoad", Vector2.new(25, -80), Vector2.new(110, 146), 18, RED)
marker("① 걷고싶은거리 · 레드로드", 62, 20, RED, 3)
strip("ClubStreet", Vector2.new(60, 152), Vector2.new(330, 152), 16, PURPLE)
marker("클럽거리 (잔다리로)", 200, 152, Color3.fromRGB(160, 110, 230), 3)
marker("런웨이·공연 무대", 300, 184, Color3.fromRGB(160, 110, 230), 4)

-- ③ 와우산로: station → south-west → 상수 → beach (the sea is in the west)
strip("Wausanro", Vector2.new(-25, -116), Vector2.new(-198, -230), 22, GREY)
marker("③ 와우산로 → 상수 → 한강 해변", -110, -172, Color3.fromRGB(42, 143, 179), 3)

-- ④ 경의선숲길 (연트럴파크): station → north-west → 연남동 카페거리 → park rides
local forest = strip("ForestPark", Vector2.new(-40, -82), Vector2.new(-140, 150), 34, Color3.fromRGB(120, 185, 110))
forest.Material = Enum.Material.Grass
strip("ForestWalk", Vector2.new(-40, -82), Vector2.new(-140, 150), 6, SAND, 0.1)
local forest2 = strip("ForestPark2", Vector2.new(-140, 150), Vector2.new(-90, 228), 34, Color3.fromRGB(120, 185, 110))
forest2.Material = Enum.Material.Grass
marker("④ 경의선숲길 · 연트럴파크", -90, 40, Color3.fromRGB(60, 140, 60), 3)
marker("연남동 카페거리", -130, 185, Color3.fromRGB(60, 140, 60), 22)
-- sunset photo frame at the end of the north pier, facing the sea (west)
local frameCol = Color3.fromRGB(255, 150, 90)
local px, pz = -344, 80
part("SunsetFramePostN", Vector3.new(1, 10, 1), CFrame.new(px, 6, pz + 5), frameCol, { material = Enum.Material.Neon })
part("SunsetFramePostS", Vector3.new(1, 10, 1), CFrame.new(px, 6, pz - 5), frameCol, { material = Enum.Material.Neon })
part("SunsetFrameTop", Vector3.new(1, 1, 11), CFrame.new(px, 11.5, pz), frameCol, { material = Enum.Material.Neon })
marker("석양 포토 스팟 (서쪽 바다)", px, pz, frameCol, 16)

-- ② 경의선 책거리: 양화로 → east → south along the village to its gate (gate faces east)
strip("BookStreet_A", Vector2.new(380, -100), Vector2.new(362, -215), 16, Color3.fromRGB(185, 160, 122))
strip("BookStreet_B", Vector2.new(362, -215), Vector2.new(322, -215), 12, Color3.fromRGB(185, 160, 122))
marker("② 경의선 책거리 → 한옥 대문 (동향)", 390, -160, Color3.fromRGB(150, 110, 60), 3)

-- shops along the boulevard
for _, s in ipairs({ { "노래방", -110, -68 }, { "세탁소", -80, -68 }, { "스터디카페", 70, -134 }, { "붕어빵", 105, -134 } }) do
	local b = part("Shop_" .. s[1], Vector3.new(24, 12, 16), CFrame.new(s[2], 6, s[3]), Color3.fromRGB(225, 220, 210))
	label(b, s[1], Color3.fromRGB(70, 70, 70), 8, 0.6)
end

-- OHU입구역 on the boulevard just south of the plaza (spawn inside, facing north)
local ST = Instance.new("Model")
ST.Name = "OHU_Station"
ST.Parent = T
local GREEN = Color3.fromRGB(46, 125, 50)
local cx, cz = 0, -100
part("StationFloor", Vector3.new(56, 0.4, 44), CFrame.new(cx, 0.2, cz), Color3.fromRGB(205, 210, 205), { parent = ST })
local roof = part("StationRoof", Vector3.new(58, 1, 46), CFrame.new(cx, 14, cz), GREEN, { parent = ST, transparency = 0.35 })
label(roof, "OHU입구역", Color3.new(1, 1, 1), 5, 1.2)
for _, c in ipairs({ { -27, -21 }, { 27, -21 }, { -27, 21 }, { 27, 21 } }) do
	part("Pillar", Vector3.new(2, 14, 2), CFrame.new(cx + c[1], 7, cz + c[2]), GREEN, { parent = ST })
end
part("Gates", Vector3.new(30, 4, 2), CFrame.new(cx, 2, cz - 6), Color3.fromRGB(60, 60, 60), { parent = ST })
local EXITS = {
	{ "1", "클럽 (북동)", Color3.fromRGB(255, 122, 214), cx + 22, cz + 22 },
	{ "2", "한옥 마을 (동)", Color3.fromRGB(185, 135, 74), cx + 29, cz - 8 },
	{ "3", "한강 해변 (서남)", Color3.fromRGB(42, 143, 179), cx - 26, cz - 22 },
	{ "4", "연남·공원 (북서)", Color3.fromRGB(76, 175, 80), cx - 22, cz + 22 },
}
for _, e in ipairs(EXITS) do
	local post = part("Exit" .. e[1], Vector3.new(3, 9, 3), CFrame.new(e[4], 4.5, e[5]), e[3], { parent = ST })
	label(post, e[1] .. "번 출구 · " .. e[2], e[3], 7, 0.8)
end

if spawn then
	if not spawn:GetAttribute("OldPosition") then spawn:SetAttribute("OldPosition", spawn.Position) end
	spawn.CFrame = CFrame.new(cx, 0.5, cz - 12) -- default orientation looks -Z; players face the way they walk
end
T.Parent = workspace
return "applied v3: station at (" .. cx .. "," .. cz .. "), MODE=revert to undo"
