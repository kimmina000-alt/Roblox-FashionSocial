--!nocheck
-- 놀이터 (D-1475, user 2026-11-16: "놀이터 구현" + two photos: a playground on a blue rubber floor with
-- orange / green / red patches, a play tower (blue posts, red pyramid roof, yellow arch panel, red wall
-- with climbing holds, stairs, a red slide), a swing set with red and blue posts, red spring horses,
-- mushroom spinner seats, a small yellow merry-go-round).
-- Workspace["놀이터"], built anew each run, on the park floor inside the gate, west of the gate plaza
-- (x -178.5 .. -134, z -284 .. -371). Edit mode, after park_paths_1116.
--   * the old playground pieces in Graybox_MainSocial.06_Park_Playground.놀이 (swing set, slide, spring
--     riders) are removed: the slide's path (P0..P2) still pointed at its old place (z -590), so a
--     slide took riders across the park
--   * the working pieces are built again with the same tags and structure ParkRidesController /
--     ParkRideService read: Swing1..3 (tag ParkSwing: "Pivot" part, "SwingSeat" model pivoted at the
--     top, attribute Length), Horse1..3 (tag ParkSpring: "Rocker" model pivoted at the spring top,
--     attribute SeatY), "Slide" (tag ParkSlide: "SlideStart" box at the top, attributes P0, P1, P2 =
--     the bed's path a little over its surface)
--   * the rest is decor: rubber floor with coloured patches (each at its own height), the tower
--     (stairs, rails, climbing wall, arch panel, stepped red roof), two mushroom spinners, a small
--     merry-go-round, benches and a bin for parents
--   * Hongdae_Layout.BumperCarGates (four invisible walls left from the bumper cars' first place, two of
--     them across this ground, two across the paths) are removed

local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local G = 16.06
local FL = G + 0.12 -- (the rubber floor's top)

local old = workspace:FindFirstChild("놀이터")
if old then old:Destroy() end
local zone = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("06_Park_Playground")
local oldPlay = zone and zone:FindFirstChild("놀이")
if oldPlay then
	for _, c in ipairs(oldPlay:GetChildren()) do c:Destroy() end
end
local gates = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("BumperCarGates")
if gates then gates:Destroy() end

local root = Instance.new("Model")
root.Name = "놀이터"
root.Parent = workspace

local BLUE = Color3.fromRGB(46, 104, 196)
local RED = Color3.fromRGB(220, 44, 40)
local YELLOW = Color3.fromRGB(250, 200, 30)
local ORANGE = Color3.fromRGB(244, 128, 40)
local GREEN = Color3.fromRGB(60, 150, 80)
local STEEL = Color3.fromRGB(170, 176, 184)
local DARK = Color3.fromRGB(40, 42, 48)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- an upright cylinder from y0, h high
local function post(parent: Instance, name: string, x: number, z: number, y0: number, h: number, d: number, color: Color3, collide: boolean?): Part
	return part(parent, name, Vector3.new(h, d, d), CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Metal, Enum.PartType.Cylinder, collide)
end
local function bar(parent: Instance, name: string, a: Vector3, b: Vector3, t: number, color: Color3, collide: boolean?): Part
	return part(parent, name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Metal, nil, collide)
end
local function model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

---------------------------------------------------------------- floor
local X0, X1, Z0, Z1 = -178.5, -134, -371, -284
local floor = model("Floor")
part(floor, "Rubber", Vector3.new(X1 - X0, 0.4, Z1 - Z0), CFrame.new((X0 + X1) / 2, FL - 0.2, (Z0 + Z1) / 2), Color3.fromRGB(70, 132, 200), Enum.Material.Rubber, nil, true)
local patches = {
	{ -164.5, -297, 10.5, ORANGE }, -- (under the swings)
	{ -140.5, -300, 6.0, GREEN }, -- (under the horses)
	{ -161, -341, 11.5, Color3.fromRGB(226, 206, 160) }, -- (round the tower)
	{ -143.5, -326, 5.5, RED }, -- (under the spinners)
	{ -150, -361, 7.5, GREEN }, -- (under the merry-go-round)
}
for k, q in ipairs(patches) do
	local y = FL + 0.03 * k
	part(floor, "Patch", Vector3.new(0.3, q[3] * 2, q[3] * 2), CFrame.new(q[1], y - 0.15, q[2]) * CFrame.Angles(0, 0, math.pi / 2), q[4], Enum.Material.Rubber, Enum.PartType.Cylinder)
end
-- a low yellow rubber edge round it (0.35 high: walked over)
do
	local e, h = 0.8, 0.35
	local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
	part(floor, "Edge", Vector3.new(X1 - X0, h, e), CFrame.new(cx, G + h / 2, Z0 + e / 2), YELLOW, Enum.Material.Rubber, nil, true)
	part(floor, "Edge", Vector3.new(X1 - X0, h, e), CFrame.new(cx, G + h / 2, Z1 - e / 2), YELLOW, Enum.Material.Rubber, nil, true)
	part(floor, "Edge", Vector3.new(e, h, Z1 - Z0 - 2 * e), CFrame.new(X0 + e / 2, G + h / 2, cz), YELLOW, Enum.Material.Rubber, nil, true)
	part(floor, "Edge", Vector3.new(e, h, Z1 - Z0 - 2 * e), CFrame.new(X1 - e / 2, G + h / 2, cz), YELLOW, Enum.Material.Rubber, nil, true)
end

---------------------------------------------------------------- swing set (3 swings, swinging along z)
do
	local set = model("SwingSet")
	local BZ, BY = -297, FL + 9.4 -- (the top bar: along x at z BZ, its middle at BY)
	local xa, xb = -177, -152
	bar(set, "SwingBar", Vector3.new(xa, BY, BZ), Vector3.new(xb, BY, BZ), 0.7, RED, true)
	for _, end_ in ipairs({ { xa, RED }, { xb, BLUE } }) do
		local x = end_[1]
		for _, s in ipairs({ -1, 1 }) do
			bar(set, "SwingLeg", Vector3.new(x, FL, BZ + s * 4), Vector3.new(x, BY + 0.2, BZ), 0.7, end_[2], true)
		end
		bar(set, "SwingBrace", Vector3.new(x, FL + 3, BZ - 2.7), Vector3.new(x, FL + 3, BZ + 2.7), 0.35, end_[2], true)
	end
	local LEN = 8
	for k, x in ipairs({ -171, -164.5, -158 }) do
		local m = model("Swing" .. k, set)
		local pivotCF = CFrame.new(x, BY - 0.35, BZ)
		local pv = part(m, "Pivot", Vector3.one * 0.5, pivotCF, STEEL)
		pv.Transparency = 1
		local seat = model("SwingSeat", m)
		for _, s in ipairs({ -1, 1 }) do
			part(seat, "Chain", Vector3.new(0.12, LEN, 0.12), pivotCF * CFrame.new(s * 1.1, -LEN / 2, 0), STEEL, Enum.Material.Metal)
		end
		part(seat, "SwingBoard", Vector3.new(2.6, 0.3, 1.2), pivotCF * CFrame.new(0, -LEN, 0), if k == 2 then BLUE else ORANGE, Enum.Material.Rubber)
		seat.WorldPivot = pivotCF
		m:SetAttribute("Length", LEN)
		m:SetAttribute("Level", 0)
		m.WorldPivot = pivotCF * CFrame.new(0, -LEN, 0)
		CollectionService:AddTag(m, "ParkSwing")
	end
end

---------------------------------------------------------------- spring horses (rock along z, face -z)
for k, z in ipairs({ -290, -300, -310 }) do
	local x = -140.5
	local m = model("Horse" .. k)
	local top = FL + 1.3 -- (the spring's top: the rocker turns about it)
	part(m, "SpringBase", Vector3.new(0.3, 2.4, 2.4), CFrame.new(x, FL + 0.15, z) * CFrame.Angles(0, 0, math.pi / 2), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder, true)
	for i = 0, 4 do
		part(m, "SpringCoil", Vector3.new(0.16, 1.1, 1.1), CFrame.new(x, FL + 0.35 + i * 0.22, z) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	local rocker = model("Rocker", m)
	local P = CFrame.new(x, top, z) -- (LookVector -z: the way it faces)
	local body = if k == 2 then YELLOW else RED
	local trim = if k == 2 then RED else YELLOW
	part(rocker, "Body", Vector3.new(1.3, 1.2, 2.8), P * CFrame.new(0, 0.75, 0.1), body)
	part(rocker, "Neck", Vector3.new(1.0, 1.4, 0.9), P * CFrame.new(0, 1.55, -1.05) * CFrame.Angles(math.rad(-20), 0, 0), body)
	part(rocker, "Head", Vector3.new(1.0, 0.9, 1.5), P * CFrame.new(0, 2.25, -1.55), body)
	for _, s in ipairs({ -1, 1 }) do
		part(rocker, "Ear", Vector3.new(0.25, 0.5, 0.25), P * CFrame.new(s * 0.3, 2.85, -1.2), body)
		part(rocker, "Eye", Vector3.new(0.12, 0.22, 0.22), P * CFrame.new(s * 0.51, 2.4, -1.75), DARK, nil, Enum.PartType.Ball)
		part(rocker, "FootRest", Vector3.new(0.7, 0.2, 0.5), P * CFrame.new(s * 0.95, 0.35, 0.1), trim)
	end
	part(rocker, "Handle", Vector3.new(1.8, 0.22, 0.22), P * CFrame.new(0, 2.05, -0.95), trim, Enum.Material.Metal)
	part(rocker, "Seat", Vector3.new(1.35, 0.25, 1.2), P * CFrame.new(0, 1.42, 0.4), trim)
	part(rocker, "Tail", Vector3.new(0.3, 0.9, 0.3), P * CFrame.new(0, 1.0, 1.6) * CFrame.Angles(math.rad(30), 0, 0), trim)
	rocker.WorldPivot = P
	m:SetAttribute("SeatY", 1.6)
	m.WorldPivot = P
	CollectionService:AddTag(m, "ParkSpring")
end

---------------------------------------------------------------- the play tower + slide
do
	local tower = model("PlayTower")
	local CX, CZ, HALF = -161, -341, 4.5
	local DECK = FL + 5.5
	part(tower, "Deck", Vector3.new(HALF * 2, 0.5, HALF * 2), CFrame.new(CX, DECK - 0.25, CZ), YELLOW, Enum.Material.DiamondPlate, nil, true)
	local TOP = FL + 12
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		post(tower, "Post", CX + c[1] * (HALF - 0.4), CZ + c[2] * (HALF - 0.4), FL, TOP - FL, 0.8, BLUE, true)
	end
	-- stepped red roof (a pyramid) with a yellow ball on top
	for i = 0, 4 do
		local w = 11 - i * 2.2
		part(tower, "Roof", Vector3.new(w, 0.8, w), CFrame.new(CX, TOP + 0.4 + i * 0.8, CZ), RED)
	end
	part(tower, "RoofBall", Vector3.one * 1.1, CFrame.new(CX, TOP + 4.5, CZ), YELLOW, nil, Enum.PartType.Ball)
	-- west: a red climbing wall with coloured holds; north: a yellow arch panel; rails elsewhere
	part(tower, "ClimbWall", Vector3.new(0.4, 5.5, HALF * 2 - 1.6), CFrame.new(CX - HALF + 0.4, FL + 2.75, CZ), RED, nil, nil, true)
	local holds = { YELLOW, GREEN, BLUE, ORANGE }
	for i = 0, 7 do
		part(tower, "Hold", Vector3.one * 0.45, CFrame.new(CX - HALF + 0.1, FL + 0.8 + (i % 4) * 1.2, CZ - 2.4 + math.floor(i / 4) * 2.6 + (i % 2) * 1.1), holds[i % 4 + 1], nil, Enum.PartType.Ball)
	end
	part(tower, "ArchSide", Vector3.new(1.4, 5, 0.4), CFrame.new(CX - 2.6, DECK + 2.5, CZ - HALF + 0.4), YELLOW, nil, nil, true)
	part(tower, "ArchSide", Vector3.new(1.4, 5, 0.4), CFrame.new(CX + 2.6, DECK + 2.5, CZ - HALF + 0.4), YELLOW, nil, nil, true)
	part(tower, "ArchTop", Vector3.new(6.6, 1.2, 0.4), CFrame.new(CX, DECK + 4.4, CZ - HALF + 0.4), YELLOW, nil, nil, true)
	part(tower, "ArchLow", Vector3.new(3.8, 2.6, 0.4), CFrame.new(CX, DECK + 1.3, CZ - HALF + 0.4), YELLOW, nil, nil, true)
	-- rails: west (over the climbing wall) and the south side but its stairs opening; the east side is the slide
	local RH = DECK + 2.6
	bar(tower, "Rail", Vector3.new(CX - HALF + 0.4, RH, CZ - HALF + 0.4), Vector3.new(CX - HALF + 0.4, RH, CZ + HALF - 0.4), 0.3, BLUE, true)
	for _, xs in ipairs({ { CX - HALF + 0.4, CX - 1.6 }, { CX + 1.6, CX + HALF - 0.4 } }) do
		bar(tower, "Rail", Vector3.new(xs[1], RH, CZ + HALF - 0.4), Vector3.new(xs[2], RH, CZ + HALF - 0.4), 0.3, BLUE, true)
	end
	-- east: rails either side of the slide's mouth (3 wide)
	for _, zs in ipairs({ { CZ - HALF + 0.4, CZ - 1.6 }, { CZ + 1.6, CZ + HALF - 0.4 } }) do
		bar(tower, "Rail", Vector3.new(CX + HALF - 0.4, RH, zs[1]), Vector3.new(CX + HALF - 0.4, RH, zs[2]), 0.3, BLUE, true)
		part(tower, "RailPanel", Vector3.new(0.2, 2.4, math.abs(zs[2] - zs[1])), CFrame.new(CX + HALF - 0.4, DECK + 1.2, (zs[1] + zs[2]) / 2), BLUE, nil, nil, true)
	end
	for _, z in ipairs({ CZ - HALF + 0.4, CZ + HALF - 0.4 }) do
		for _, x in ipairs({ CX - HALF + 0.4 }) do
			part(tower, "RailPost", Vector3.new(0.3, 2.6, 0.3), CFrame.new(x, DECK + 1.3, z), BLUE, Enum.Material.Metal, nil, true)
		end
	end
	for i = 1, 5 do
		part(tower, "RailBar", Vector3.new(0.15, 2.6, 0.15), CFrame.new(CX - HALF + 0.4, DECK + 1.3, CZ - HALF + 0.4 + i * (HALF * 2 - 0.8) / 6), BLUE, Enum.Material.Metal)
	end
	-- stairs down to the south (+z): steps you walk up (0.55 each), yellow treads, red stringers
	local steps = 10
	local rise = (DECK - FL) / steps
	for i = 1, steps do
		local topY = DECK - (i - 1) * rise
		local z = CZ + HALF + (i - 0.5) * 1.0
		part(tower, "Step", Vector3.new(3, topY - FL, 1.0), CFrame.new(CX, FL + (topY - FL) / 2, z), if i % 2 == 0 then YELLOW else ORANGE, nil, nil, true)
	end
	for _, s in ipairs({ -1, 1 }) do
		bar(tower, "StairRail", Vector3.new(CX + s * 1.7, DECK + 2.4, CZ + HALF), Vector3.new(CX + s * 1.7, FL + 2.4, CZ + HALF + steps), 0.25, RED, true)
	end
	-- the slide: east from the deck's edge down to the floor (x -156.5 → -143)
	local slide = model("Slide", tower)
	local ax, bx = CX + HALF, CX + HALF + 11.5
	local topY, botY = DECK, FL + 0.9
	local a3, b3 = Vector3.new(ax, topY, CZ), Vector3.new(bx, botY, CZ)
	local mid = (a3 + b3) / 2
	local dir = (b3 - a3).Unit
	local L = (b3 - a3).Magnitude
	part(slide, "SlideBed", Vector3.new(3.0, 0.35, L), CFrame.lookAt(mid, b3) * CFrame.new(0, -0.17, 0), RED)
	for _, s in ipairs({ -1, 1 }) do
		part(slide, "SlideRail", Vector3.new(0.3, 0.9, L), CFrame.lookAt(mid, b3) * CFrame.new(s * 1.55, 0.25, 0), RED)
	end
	part(slide, "SlideRunout", Vector3.new(3.0, 0.35, 2.4), CFrame.new(bx + 1.2, botY - 0.17, CZ), RED)
	post(slide, "SlideLeg", bx - 1, CZ - 1.2, FL, botY - FL + 0.6, 0.35, BLUE)
	post(slide, "SlideLeg", bx - 1, CZ + 1.2, FL, botY - FL + 0.6, 0.35, BLUE)
	local start = part(slide, "SlideStart", Vector3.new(2.2, 5, 2.8), CFrame.new(ax - 0.7, DECK + 2.5, CZ), Color3.new(1, 1, 1))
	start.Transparency = 1
	local lift = 0.25
	slide:SetAttribute("P0", a3 + Vector3.new(0, lift, 0))
	slide:SetAttribute("P1", mid + Vector3.new(0, lift, 0))
	slide:SetAttribute("P2", Vector3.new(bx + 1.6, botY + lift, CZ))
	slide.WorldPivot = CFrame.new(a3)
	CollectionService:AddTag(slide, "ParkSlide")
end

---------------------------------------------------------------- mushroom spinners (still)
for _, q in ipairs({ { -146, -322, BLUE }, { -141, -330, RED } }) do
	local m = model("Spinner")
	post(m, "SpinPost", q[1], q[2], FL, 1.8, 0.7, q[3], true)
	local top = post(m, "SpinTop", q[1], q[2], FL + 1.8, 0.45, 3.2, q[3], true)
	top.Material = Enum.Material.SmoothPlastic
	post(m, "SpinKnob", q[1], q[2], FL + 2.25, 0.25, 0.5, ORANGE)
	for i = 0, 7 do
		local a = i / 8 * 2 * math.pi
		post(m, "SpinDot", q[1] + 1.05 * math.cos(a), q[2] + 1.05 * math.sin(a), FL + 2.25, 0.03, 0.35, Color3.fromRGB(230, 236, 244))
	end
end

---------------------------------------------------------------- a small merry-go-round (still)
do
	local m = model("MerryGoRound")
	local cx, cz = -150, -361
	post(m, "Base", cx, cz, FL, 0.5, 6.4, YELLOW, true)
	post(m, "Centre", cx, cz, FL + 0.5, 2.6, 0.7, RED, true)
	post(m, "CentreCap", cx, cz, FL + 3.1, 0.3, 1.2, GREEN)
	local n = 12
	for i = 0, n - 1 do
		local a0, a1 = i / n * 2 * math.pi, (i + 1) / n * 2 * math.pi
		bar(m, "Ring", Vector3.new(cx + 2.9 * math.cos(a0), FL + 2.3, cz + 2.9 * math.sin(a0)), Vector3.new(cx + 2.9 * math.cos(a1), FL + 2.3, cz + 2.9 * math.sin(a1)), 0.22, YELLOW)
	end
	for i = 0, 3 do
		local a = (i + 0.5) / 4 * 2 * math.pi
		local x, z = cx + 2.9 * math.cos(a), cz + 2.9 * math.sin(a)
		post(m, "RingPost", x, z, FL + 0.5, 1.8, 0.22, YELLOW)
		local sx, sz = cx + 1.7 * math.cos(a), cz + 1.7 * math.sin(a)
		post(m, "StoolLeg", sx, sz, FL + 0.5, 0.9, 0.3, STEEL)
		post(m, "Stool", sx, sz, FL + 1.4, 0.3, 1.0, GREEN)
	end
end

---------------------------------------------------------------- benches and a bin for parents
do
	local benchT = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("BusShelter") and SS.ArtAssets.BusShelter:FindFirstChild("Park Bench|공원 벤치", true)
	if benchT then
		for _, z in ipairs({ -326, -358 }) do
			local b = benchT:Clone()
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("BaseScript") or d:IsA("ModuleScript") then d:Destroy() end
				if d:IsA("BasePart") then d.Anchored = true d.CanTouch = false end
			end
			local _, s = b:GetBoundingBox()
			local c = Vector3.new(-176.2, FL + s.Y / 2, z)
			b:PivotTo(CFrame.lookAt(c, c + Vector3.xAxis))
			b.Parent = root
		end
	end
	local bin = model("ParkBin")
	post(bin, "BinBody", -176.4, -317, FL, 2.6, 1.6, Color3.fromRGB(44, 110, 70), true)
	post(bin, "BinLid", -176.4, -317, FL + 2.6, 0.35, 1.85, Color3.fromRGB(30, 80, 50))
end

local n = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
print("[park_playground_1116] parts " .. n)
return n
