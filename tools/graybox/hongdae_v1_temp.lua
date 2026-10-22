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
local MOVES = {
	-- club north-east of the roundabout, entrance + neon facing west onto the club street
	["02_Club"] = CFrame.new(22, 0, -145) * R(-90) * CFrame.new(0, 0, 210),
	-- fashion week runway right behind the club (show / concert space), runway toward the club
	["03_Rooftop_Backstage"] = CFrame.new(22, 0, -337) * R(180) * CFrame.new(-125, 0, 160),
	-- hanok village south-east: main gate east (morning sun), back gate west
	["07_Hanok_Village"] = CFrame.new(65, 0, 120) * R(-90) * CFrame.new(-175, 0, -230),
	-- 인생네컷 between the roundabout and the east, below the club
	["08_PhotoBooth"] = CFrame.new(2, 0, -35) * CFrame.new(-205, 0, 112),
	-- park rides north-west (west part over the beach, as in the drawing)
	["06_Park_Playground"] = CFrame.new(-500, 0, -135),
	-- Glasshouse cafe south-west, long side along the road, terrace toward the road (north)
	["05_Cafe"] = CFrame.new(-128, 0, 145) * R(-90) * CFrame.new(130, 0, -185),
}
local HOLE = { -38, -225, 82, -65 } -- club ground hole x0, z0, x1, z1 (follows 02_Club)
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

local ASPHALT = Color3.fromRGB(110, 110, 115)
local W = 10 -- main road width (1/3 of v4)
local CS = game:GetService("CollectionService")

-- roundabout: asphalt ring around a round lawn (cylinders lying with the axis up)
local UP = CFrame.Angles(0, 0, math.rad(90))
part("Roundabout", Vector3.new(0.14, 52, 52), CFrame.new(C.X, 0.07, C.Z) * UP, ASPHALT, { shape = Enum.PartType.Cylinder, material = Enum.Material.Asphalt })
local lawn = part("RoundaboutLawn", Vector3.new(0.6, 26, 26), CFrame.new(C.X, 0.3, C.Z) * UP, Color3.fromRGB(90, 170, 80), { shape = Enum.PartType.Cylinder, material = Enum.Material.Grass })
label(lawn, "잔디밭", Color3.fromRGB(40, 110, 40), 4, 0.6)

-- roads (the drawing, gaps at about 1/3)
strip("Road_West", Vector2.new(-84, 0), Vector2.new(-190, 0), W, ASPHALT)
strip("Road_Beach", Vector2.new(-190, -5), Vector2.new(-190, 300), W, ASPHALT)
strip("Road_North", Vector2.new(-60, -24), Vector2.new(-60, -230), W, ASPHALT)
strip("Road_South", Vector2.new(-60, 24), Vector2.new(-60, 300), W, ASPHALT)
strip("Road_East", Vector2.new(-36, 0), Vector2.new(155, 0), W, ASPHALT)
strip("Road_SouthWest", Vector2.new(-190, 70), Vector2.new(-60, 70), W, ASPHALT)
strip("Road_EastNS", Vector2.new(92, -5), Vector2.new(92, -230), W, ASPHALT)
strip("Road_NorthEast", Vector2.new(92, -180), Vector2.new(152, -180), W, ASPHALT)
local LANE = Color3.fromRGB(185, 160, 122)
strip("HanokLane_East", Vector2.new(145, 5), Vector2.new(145, 120), 8, LANE)
strip("HanokLane_East2", Vector2.new(149, 120), Vector2.new(129, 120), 8, LANE)
strip("HanokLane_West", Vector2.new(-55, 150), Vector2.new(1, 150), 8, LANE)
local clubStreet = strip("ClubStreet", Vector2.new(-44.5, -65), Vector2.new(-44.5, -225), 13, Color3.fromRGB(110, 85, 160))
clubStreet.Material = Enum.Material.SmoothPlastic
label(clubStreet, "클럽거리 (잔다리로)", Color3.fromRGB(160, 110, 230), 3, 0.8)

-- background buildings (진입불가, red boxes in the drawing)
local BG = Color3.fromRGB(200, 190, 185)
block("BG_Building(진입불가)", 102, -225, 152, -190, 30, BG, "가짜 건물")
block("BG_Building(진입불가)", 102, -170, 152, -10, 26, BG, "가짜 건물")
block("BG_Building(진입불가)", -88, 40, -70, 60, 16, BG, "가짜 건물")
block("BG_Building(진입불가)", -95, 80, -70, 200, 24, BG, "가짜 건물")
-- between exit 2 and the hanok village: may become the prop shop later
block("BG_Building(소품샵 예정)", -45, 34, -8, 62, 16, Color3.fromRGB(235, 205, 190), "가짜 건물 (소품샵 예정)")
-- convenience store (blue box in the drawing)
block("ConvenienceStore", -140, 12, -95, 55, 12, Color3.fromRGB(120, 190, 235), "편의점", Color3.fromRGB(30, 100, 170))

-- subway exits at the roundabout corners: step on the pad → "몇 번 출구로
-- 가시겠습니까?" (SubwayService). Tag SubwayExit, ExitNumber, ExitName, Out.
local EXITS = {
	{ 1, "클럽", Color3.fromRGB(255, 122, 214), 24, -24 },
	{ 2, "한옥 마을", Color3.fromRGB(185, 135, 74), 24, 24 },
	{ 3, "공원 놀이기구", Color3.fromRGB(76, 175, 80), -24, -24 },
	{ 4, "해변 · 카페", Color3.fromRGB(42, 143, 179), -24, 24 },
}
for _, e in ipairs(EXITS) do
	local pos = C + Vector3.new(e[4], 0, e[5])
	local out = Vector3.new(e[4], 0, e[5]).Unit
	local pad = part("SubwayExit" .. e[1], Vector3.new(8, 0.4, 8), CFrame.lookAt(pos + Vector3.new(0, 0.2, 0), pos + Vector3.new(0, 0.2, 0) + out), e[3], { material = Enum.Material.Neon })
	pad:SetAttribute("ExitNumber", e[1])
	pad:SetAttribute("ExitName", e[2])
	pad:SetAttribute("Out", out)
	CS:AddTag(pad, "SubwayExit")
	local sign = part("ExitSign" .. e[1], Vector3.new(1, 8, 1), CFrame.new(pos - out * 5 + Vector3.new(0, 4, 0)), Color3.fromRGB(46, 125, 50))
	label(sign, e[1] .. "번 출구 · " .. e[2], e[3], 6, 0.8)
end
-- sunset photo frame at the end of the north pier, facing the sea (west)
local frameCol = Color3.fromRGB(255, 150, 90)
local px, pz = -344, 80
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
return "applied v4b (user's drawing, gaps 1/3), MODE=revert to undo"
