--!nocheck
-- 회전목마 꾸미기 (D-1428, user 2026-11-15: "회전목자 가운데 기둥 및 바닥 등 기타 디자인 구현", photos:
-- a carousel with a cream centre drum framed by bulbs and mirrors, gold trims, bulb-lined ceiling
-- beams, a wooden floor and a white fence round it).
--   * floor: the base becomes warm wooden planks, its edge a gold band lined with bulbs
--   * centre (turns with the Rotor): a cream drum round the pink column with gold bands, six mirror
--     panels framed in warm light and a red crown; the column above it cream with gold rings
--   * ceiling (turns): twelve gold beams from the column to the edge, each with a strip of light
--   * poles (turn): gold caps where each horse pole meets the floor and the ceiling
--   * a white fence round the carousel (posts, top and middle rails), open towards the park's
--     gate (+z)
-- Run in Edit mode after park_carousel_horses_1115 (it uses the HorsePole parts). Idempotent: the
-- "Dress" folders are built anew.

local zone = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("06_Park_Playground")
local group = zone:WaitForChild("회전목")
local carousel = group:WaitForChild("Carousel")
local rotor = carousel:WaitForChild("Rotor")
local center = carousel:WaitForChild("Center") :: BasePart
local base = group:WaitForChild("CarouselBase") :: BasePart
local ring = group:FindFirstChild("CarouselBaseRing") :: BasePart?
local canopy = rotor:WaitForChild("Canopy") :: BasePart
local column = rotor:FindFirstChild("CenterPole") :: BasePart?

local C = center.Position
local FLOOR = base.Position.Y + base.Size.X / 2
local CEIL = canopy.Position.Y - canopy.Size.X / 2
local R_BASE = base.Size.Y / 2

local GOLD = Color3.fromRGB(214, 176, 92)
local CREAM = Color3.fromRGB(246, 236, 218)
local RED = Color3.fromRGB(200, 40, 52)
local BULB = Color3.fromRGB(255, 236, 190)
local WHITE = Color3.fromRGB(245, 245, 245)

local function folder(parent: Instance): Folder
	local old = parent:FindFirstChild("Dress")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "Dress"
	f.Parent = parent
	return f
end

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

-- a cylinder standing up (Roblox cylinders run along X)
local function disc(parent: Instance, name: string, y0: number, h: number, d: number, color: Color3, mat: Enum.Material?): Part
	return part(parent, name, Vector3.new(h, d, d), CFrame.new(C.X, y0 + h / 2, C.Z) * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

local function around(r: number, a: number, y: number): Vector3
	return Vector3.new(C.X + r * math.cos(a), y, C.Z + r * math.sin(a))
end

---------------------------------------------------------------- floor (stands still)
local still = folder(group)
base.Material = Enum.Material.WoodPlanks
base.Color = Color3.fromRGB(196, 150, 104)
if ring then
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = GOLD
	local ry = ring.Position.Y
	local rr = ring.Size.Y / 2 + 0.15
	for k = 0, 35 do
		part(still, "EdgeBulb", Vector3.one * 0.45, CFrame.new(around(rr, k / 36 * 2 * math.pi, ry)), BULB, Enum.Material.Neon, Enum.PartType.Ball)
	end
end

-- the fence: 24 posts round, rails between them, two bays left open towards +z (the gate side)
do
	local R = R_BASE + 3.2
	local N = 24
	local open = { [5] = true, [6] = true } -- (bay k runs from post k to post k+1; these two face +z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { group }
	local function ground(p: Vector3): number -- (the park floor under the post)
		local hit = workspace:Raycast(Vector3.new(p.X, FLOOR + 30, p.Z), Vector3.new(0, -80, 0), params)
		return if hit then hit.Position.Y else base.Position.Y - base.Size.X / 2
	end
	for k = 0, N - 1 do
		local a = (k + 0.5) / N * 2 * math.pi
		local b = (k + 1.5) / N * 2 * math.pi
		local p0, p1 = around(R, a, 0), around(R, b, 0)
		p0 = Vector3.new(p0.X, ground(p0), p0.Z)
		p1 = Vector3.new(p1.X, ground(p1), p1.Z)
		part(still, "FencePost", Vector3.new(0.4, 3.4, 0.4), CFrame.new(p0 + Vector3.new(0, 1.7, 0)), WHITE, nil, nil, true)
		part(still, "FencePostCap", Vector3.one * 0.55, CFrame.new(p0 + Vector3.new(0, 3.5, 0)), GOLD, nil, Enum.PartType.Ball)
		if not open[k] then
			for _, h in ipairs({ 3.1, 1.6 }) do
				local a3, b3 = p0 + Vector3.new(0, h, 0), p1 + Vector3.new(0, h, 0)
				part(still, "FenceRail", Vector3.new(0.25, 0.25, (b3 - a3).Magnitude), CFrame.lookAt((a3 + b3) / 2, b3), WHITE, nil, nil, true)
			end
		end
	end
end

---------------------------------------------------------------- centre drum (turns)
local turn = folder(rotor)
local DRUM_D, DRUM_H = 9, 8.5
disc(turn, "Drum", FLOOR, DRUM_H, DRUM_D, CREAM)
disc(turn, "DrumBandLow", FLOOR, 0.7, DRUM_D + 0.5, GOLD)
disc(turn, "DrumBandHigh", FLOOR + DRUM_H - 0.5, 0.5, DRUM_D + 0.5, GOLD)
disc(turn, "DrumCrown", FLOOR + DRUM_H, 1.3, DRUM_D + 1.0, RED)
disc(turn, "DrumCrownTrim", FLOOR + DRUM_H + 1.3, 0.35, DRUM_D + 1.2, GOLD)
for k = 0, 5 do
	local a = k / 6 * 2 * math.pi
	local mid = around(DRUM_D / 2 + 0.06, a, FLOOR + DRUM_H * 0.52)
	local face = CFrame.lookAt(mid, mid + (mid - Vector3.new(C.X, mid.Y, C.Z)))
	part(turn, "MirrorGlow", Vector3.new(3.0, 4.4, 0.12), face * CFrame.new(0, 0, 0.02), BULB, Enum.Material.Neon)
	local m = part(turn, "Mirror", Vector3.new(2.4, 3.8, 0.12), face * CFrame.new(0, 0, -0.08), Color3.fromRGB(190, 205, 220), Enum.Material.Glass)
	m.Reflectance = 0.5
end
if column then
	column.Color = CREAM
	column.Material = Enum.Material.SmoothPlastic
	local top = column.Position.Y + column.Size.X / 2
	for _, y in ipairs({ FLOOR + DRUM_H + 3, FLOOR + DRUM_H + 6, top - 1.2 }) do
		disc(turn, "ColumnRing", y, 0.5, column.Size.Y + 0.5, GOLD)
	end
end

---------------------------------------------------------------- ceiling beams (turn)
for k = 0, 11 do
	local a = (k + 0.5) / 12 * 2 * math.pi
	local p0, p1 = around(3.4, a, CEIL - 0.35), around(R_BASE + 0.6, a, CEIL - 0.35)
	part(turn, "CeilingBeam", Vector3.new(0.8, 0.6, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), GOLD)
	part(turn, "CeilingLight", Vector3.new(0.28, 0.2, (p1 - p0).Magnitude - 0.6), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, -0.38, 0), BULB, Enum.Material.Neon)
end

---------------------------------------------------------------- pole caps (turn)
for _, pole in ipairs(rotor:GetChildren()) do
	if pole:IsA("BasePart") and string.match(pole.Name, "^HorsePole%d+$") then
		local p = pole.Position
		for _, y in ipairs({ FLOOR, CEIL - 0.6 }) do
			part(turn, "PoleCap", Vector3.new(0.6, 0.75, 0.75), CFrame.new(p.X, y + 0.3, p.Z) * CFrame.Angles(0, 0, math.pi / 2), GOLD, nil, Enum.PartType.Cylinder)
		end
	end
end

local n = #still:GetChildren() + #turn:GetChildren()
print("[park_carousel_dress_1115] parts " .. n)
return n
