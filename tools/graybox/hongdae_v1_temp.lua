-- TEMPORARY layout test: OHU 배치도 v1 (docs/02_WORLDS/HONGDAE_LAYOUT.md).
-- Run in the Studio command bar (Edit mode). Set MODE below:
--   "apply"  → moves the zones to the Hongdae layout, hides the old ring
--              plaza, adds the station + streets (Workspace.Hongdae_v1_Temp)
--   "revert" → puts everything back exactly as built
-- Compass for this layout: north = +X, east = +Z (so the beach/sea in the
-- west of the old map becomes the Han river in the south, like the real map).
-- The club (underground hole in 00_Ground) and the beach (terrain sea) stay
-- where they are; everything else is placed around them.
local MODE = ... or "apply"

local root = workspace:WaitForChild("Graybox_MainSocial")
local SS = game:GetService("ServerStorage")
local HIDE = "Hongdae_v1_HiddenParts"

-- zone → target move (applied to the zone's built pivot)
local MOVES = {
	["03_Rooftop_Backstage"] = CFrame.new(40, 0, 130) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(-125, 0, 160),
	["05_Cafe"] = CFrame.new(250, 0, -70) * CFrame.new(130, 0, -185),
	["06_Park_Playground"] = CFrame.new(25, 0, -230),
	["08_PhotoBooth"] = CFrame.new(70, 0, -32) * CFrame.new(-205, 0, 112),
}

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

if MODE == "revert" then
	for name in pairs(MOVES) do
		local z = root:FindFirstChild(name)
		local b = z and z:GetAttribute("BuiltPivot")
		if typeof(b) == "CFrame" then moveTo(z, b) end
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
	return "reverted (zones back to BuiltPivot, ring plaza restored, temp model removed)"
end

-- apply ------------------------------------------------------------------
for name, d in pairs(MOVES) do
	local z = root:FindFirstChild(name)
	local b = z and z:GetAttribute("BuiltPivot")
	if typeof(b) == "CFrame" then moveTo(z, d * b) end
end

-- hide the old ring plaza (Loop/Spoke) and the old connecting paths
local hidden = SS:FindFirstChild(HIDE) or Instance.new("Folder")
hidden.Name = HIDE
hidden.Parent = SS
for _, zn in ipairs({ "01_Plaza_Street", "09_Paths" }) do
	for _, p in ipairs(root[zn]:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Loop" or p.Name == "Spoke" or zn == "09_Paths") then
			p:SetAttribute("HomeZone", zn)
			p.Parent = hidden
		end
	end
end

local old = workspace:FindFirstChild("Hongdae_v1_Temp")
if old then old:Destroy() end
local T = Instance.new("Model")
T.Name = "Hongdae_v1_Temp"

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
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(Vector3.new(mid.X, y or 0.06, mid.Y), Vector3.new(b.X, y or 0.06, b.Y))
	return part(name, Vector3.new(w, 0.12, len), cf, color)
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
-- 양화로 (east-west boulevard, along Z)
strip("Yanghwaro", Vector2.new(150, -420), Vector2.new(150, 420), 36, GREY)
for z = -400, 400, 24 do
	part("LaneDash", Vector3.new(0.6, 0.14, 10), CFrame.new(150, 0.08, z), Color3.new(1, 1, 1))
end
marker("양화로", 150, -300, Color3.fromRGB(80, 80, 80), 2, 0.8)
-- ① 걷고싶은거리 · 레드로드 → 클럽거리 → OHU CLUB
strip("RedRoad", Vector2.new(128, -50), Vector2.new(0, -104), 18, RED)
marker("① 걷고싶은거리 · 레드로드", 70, -82, RED, 3)
-- 클럽 입구 앞 클럽거리(잔다리로)
strip("ClubStreet", Vector2.new(-80, -108), Vector2.new(80, -108), 16, Color3.fromRGB(110, 85, 160))
marker("클럽거리 (잔다리로)", -40, -108, Color3.fromRGB(160, 110, 230), 3)
-- 홍대 놀이터 광장 (버스킹) = the old round center plaza, joined to the red road
strip("PlaygroundLink", Vector2.new(70, -76), Vector2.new(40, -40), 12, RED)
marker("홍대 놀이터 광장", 0, 0, Color3.fromRGB(200, 150, 40), 8)
-- ③ 와우산로 → 상수 → 한강 해변 (passes east of the plaza)
strip("Wausanro_A", Vector2.new(124, -12), Vector2.new(70, 75), 22, GREY)
strip("Wausanro_B", Vector2.new(78, 75), Vector2.new(-200, 75), 22, GREY)
marker("③ 와우산로 → 상수 → 한강", -60, 75, Color3.fromRGB(42, 143, 179), 3)
-- ② 경의선 책거리 → 한옥 마을
strip("BookStreet", Vector2.new(168, 0), Vector2.new(180, 160), 16, Color3.fromRGB(185, 160, 122))
marker("② 경의선 책거리 → 한옥", 175, 80, Color3.fromRGB(150, 110, 60), 3)
-- ④ 경의선숲길 (연트럴파크) → 연남동 카페거리 → 공원
local forest = strip("ForestPark", Vector2.new(168, -50), Vector2.new(300, -160), 34, Color3.fromRGB(120, 185, 110))
forest.Material = Enum.Material.Grass
strip("ForestWalk", Vector2.new(168, -50), Vector2.new(300, -160), 6, Color3.fromRGB(215, 200, 170), 0.1)
marker("④ 경의선숲길 · 연트럴파크", 235, -110, Color3.fromRGB(60, 140, 60), 3)
marker("연남동 카페거리", 250, -40, Color3.fromRGB(60, 140, 60), 22)
-- street shops on 양화로 (blocks)
for i, s in ipairs({ { "노래방", 185, 30 }, { "세탁소", 185, 60 }, { "스터디카페", 120, 40 }, { "붕어빵", 120, -10 } }) do
	local b = part("Shop_" .. s[1], Vector3.new(16, 12, 20), CFrame.new(s[2], 6, s[3]), Color3.fromRGB(225, 220, 210))
	label(b, s[1], Color3.fromRGB(70, 70, 70), 8, 0.6)
end

-- OHU입구역 (station hall on 양화로, spawn inside)
local ST = Instance.new("Model")
ST.Name = "OHU_Station"
ST.Parent = T
local GREEN = Color3.fromRGB(46, 125, 50)
local cx, cz = 150, -30
part("StationFloor", Vector3.new(56, 0.4, 44), CFrame.new(cx, 0.2, cz), Color3.fromRGB(205, 210, 205), { parent = ST })
local roof = part("StationRoof", Vector3.new(58, 1, 46), CFrame.new(cx, 14, cz), GREEN, { parent = ST, transparency = 0.35 })
label(roof, "OHU입구역", Color3.new(1, 1, 1), 5, 1.2)
for _, c in ipairs({ { -27, -21 }, { 27, -21 }, { -27, 21 }, { 27, 21 } }) do
	part("Pillar", Vector3.new(2, 14, 2), CFrame.new(cx + c[1], 7, cz + c[2]), GREEN, { parent = ST })
end
part("Gates", Vector3.new(2, 4, 30), CFrame.new(cx + 6, 2, cz), Color3.fromRGB(60, 60, 60), { parent = ST })
-- exits ① SW ② E ③ S ④ NW
local EXITS = {
	{ "1", "클럽", Color3.fromRGB(255, 122, 214), cx - 28, cz - 22 },
	{ "2", "한옥 마을", Color3.fromRGB(185, 135, 74), cx + 4, cz + 23 },
	{ "3", "한강 해변", Color3.fromRGB(42, 143, 179), cx - 29, cz + 10 },
	{ "4", "연남·공원", Color3.fromRGB(76, 175, 80), cx + 28, cz - 22 },
}
for _, e in ipairs(EXITS) do
	local post = part("Exit" .. e[1], Vector3.new(3, 9, 3), CFrame.new(e[4], 4.5, e[5]), e[3], { parent = ST })
	label(post, e[1] .. "번 출구 · " .. e[2], e[3], 7, 0.8)
end

if spawn then
	if not spawn:GetAttribute("OldPosition") then spawn:SetAttribute("OldPosition", spawn.Position) end
	spawn.Position = Vector3.new(cx - 8, 0.5, cz)
end
T.Parent = workspace
return "applied: station at (" .. cx .. "," .. cz .. "), MODE=revert to undo"
