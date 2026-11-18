--!nocheck
-- 범퍼카 트랙 (D-1826, user 2026-11-19 + two pictures (a traffic cone, a race track's straight and oval):
-- "범퍼카 바닥에 레일 그려서 사람 없어도 범퍼카 타고 한 바퀴 돌 수 있도록 하자. 가운데 원뿔형 표지판 세워
-- 놓고. 3d로 만들어. 레일은 아래 원형을 범퍼카 장소 크기에 맞춰서 넣자.")
-- On the bumper car floor (Workspace["범퍼"]["04_BumperCars"].Floor, top y 18.03, inside the rails x
-- -251.65..-66.35, z -758.65..-646.35) an oval race track like the picture's lower one, as big as the hall:
--   * an asphalt stadium ring (outer radius 51, inner 29: 22 wide, straights 73.3 long), the infield in the
--     floor's own colour on top of it;
--   * red / white curbs along both edges, a white dashed centre line, a checkered START / FINISH line across
--     the +Z straight (the entrance side) in the middle;
--   * traffic cones in the infield (3D: a square foot, the cone, two white reflective bands), a slalom row
--     along the middle; tag "BumperCone" (attribute Radius): driven cars bounce off them (BumperCarController).
-- Flat paint only (CanCollide / CanQuery off, just over the floor): the cars drive over it as before.
-- Workspace["범퍼"]["04_BumperCars"].Track, built anew each run (idempotent). Run after park_bumper_big_1116 /
-- park_bumper_dress_1115 (it reads the floor they leave).

local CS = game:GetService("CollectionService")

local area = workspace:FindFirstChild("범퍼") and workspace["범퍼"]:FindFirstChild("04_BumperCars")
local floor = area and area:FindFirstChild("Floor")
assert(floor, "no 범퍼.04_BumperCars.Floor")

local CX, CZ = -159, -702.5
local TOP = floor.Position.Y + floor.Size.Y / 2 -- (18.03)
local R_OUT, R_IN = 51, 29
local HALF = 36.65 -- half the straights (the round ends' centres at CX ± HALF)
local CURB = 1.3
local CURB_LEN = 3
local ASPHALT = Color3.fromRGB(58, 58, 62)
local RED = Color3.fromRGB(214, 36, 40)
local WHITE = Color3.fromRGB(242, 242, 242)
local ORANGE = Color3.fromRGB(255, 92, 22)

local old = area:FindFirstChild("Track")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "Track"

local function paint(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
-- a flat stadium (box between the two round ends) whose top is at y
local function stadium(name: string, r: number, y: number, color: Color3, material: Enum.Material)
	local th = 0.1
	paint(name .. "Mid", Vector3.new(HALF * 2, th, r * 2), CFrame.new(CX, y - th / 2, CZ), color, material)
	for _, s in ipairs({ -1, 1 }) do
		local c = paint(name .. "End", Vector3.new(th, r * 2, r * 2), CFrame.new(CX + s * HALF, y - th / 2, CZ) * CFrame.Angles(0, 0, math.pi / 2), color, material)
		c.Shape = Enum.PartType.Cylinder
	end
end
stadium("Asphalt", R_OUT, TOP + 0.02, ASPHALT, Enum.Material.Asphalt)
stadium("Infield", R_IN, TOP + 0.04, floor.Color, floor.Material)

-- a path round the oval at radius r: calls f(pos, tangent yaw, length) every `step` studs (straights and
-- round ends), so curbs / dashes follow it
local function along(r: number, step: number, f: (Vector3, number, number, number) -> ())
	local i = 0
	-- the +Z straight (x from -HALF to +HALF), the +X end, the -Z straight back, the -X end
	local n = math.max(1, math.floor(HALF * 2 / step + 0.5))
	local len = HALF * 2 / n
	for k = 0, n - 1 do
		i += 1
		f(Vector3.new(CX - HALF + (k + 0.5) * len, 0, CZ + r), 0, len, i)
	end
	local m = math.max(2, math.floor(math.pi * r / step + 0.5))
	local da = math.pi / m
	for k = 0, m - 1 do
		i += 1
		local a = math.pi / 2 - (k + 0.5) * da -- (from +Z round through +X to -Z)
		local p = Vector3.new(CX + HALF + r * math.cos(a), 0, CZ + r * math.sin(a))
		f(p, a + math.pi / 2, 2 * r * math.sin(da / 2), i)
	end
	for k = 0, n - 1 do
		i += 1
		f(Vector3.new(CX + HALF - (k + 0.5) * len, 0, CZ - r), math.pi, len, i)
	end
	for k = 0, m - 1 do
		i += 1
		local a = -math.pi / 2 - (k + 0.5) * da -- (from -Z round through -X to +Z)
		local p = Vector3.new(CX - HALF + r * math.cos(a), 0, CZ + r * math.sin(a))
		f(p, a + math.pi / 2, 2 * r * math.sin(da / 2), i)
	end
end
-- (yaw: the direction of travel, 0 = +X; a part's X runs along it)
local function flatCF(p: Vector3, yaw: number, y: number): CFrame
	return CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, -yaw, 0)
end

-- the curbs: red / white blocks on both edges
for _, edge in ipairs({ R_OUT - CURB / 2, R_IN + CURB / 2 }) do
	along(edge, CURB_LEN, function(p, yaw, len, i)
		paint("Curb", Vector3.new(len + 0.05, 0.1, CURB), flatCF(p, yaw, TOP + 0.06), if i % 2 == 0 then RED else WHITE)
	end)
end
-- the dashed centre line: a 4.5 dash every 9
along((R_OUT + R_IN) / 2, 9, function(p, yaw, len, i)
	paint("Dash", Vector3.new(4.5, 0.08, 0.6), flatCF(p, yaw, TOP + 0.05), WHITE)
end)

-- START / FINISH across the +Z straight in the middle: two columns of checks, the words either side
do
	local z0, z1 = CZ + R_IN + CURB, CZ + R_OUT - CURB
	local sq = (z1 - z0) / 10
	-- (a white strip under, black checks on it)
	paint("Finish", Vector3.new(sq * 2, 0.08, z1 - z0), CFrame.new(CX, TOP + 0.07, (z0 + z1) / 2), WHITE)
	for row = 0, 9 do
		for col = 0, 1 do
			if (row + col) % 2 == 0 then
				paint("Check", Vector3.new(sq, 0.08, sq), CFrame.new(CX - sq / 2 + col * sq, TOP + 0.08, z0 + (row + 0.5) * sq), Color3.fromRGB(20, 20, 22))
			end
		end
	end
	for _, w in ipairs({ { "FINISH", -1 }, { "START", 1 } }) do
		-- the word lies on the asphalt along the line (read from the side of the track it is on)
		local board = paint("Word" .. w[1], Vector3.new(3.4, 0.05, z1 - z0 - 2), CFrame.new(CX + w[2] * (sq + 2.6), TOP + 0.05, (z0 + z1) / 2), ASPHALT)
		board.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 1
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		-- (the face's width is the board's X: the word turned a quarter to run along Z)
		label.Size = UDim2.fromOffset((z1 - z0 - 2) * 30, 3.4 * 30)
		label.Rotation = if w[2] > 0 then 90 else -90
		label.Text = w[1]
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = WHITE
		label.Parent = gui
	end
end

-- the cones: a slalom row along the infield's middle (3D: foot, cone, two reflective bands)
local CONE_H, CONE_R, FOOT = 4.2, 1.25, 3
local function cone(x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "TrafficCone"
	local foot = paint("Foot", Vector3.new(FOOT, 0.3, FOOT), CFrame.new(x, TOP + 0.04 + 0.15, z), ORANGE)
	foot.Parent = m
	local body = paint("Cone", Vector3.new(CONE_R * 2, CONE_H, CONE_R * 2), CFrame.new(x, TOP + 0.34 + CONE_H / 2, z), ORANGE)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://1033714" -- (Roblox's plain cone mesh: point up, as tall as the part)
	mesh.Scale = Vector3.new(CONE_R * 2, CONE_H, CONE_R * 2) * 0.5
	mesh.Parent = body
	body.Parent = m
	-- the bands: thin rings just wider than the cone where they sit
	for _, h in ipairs({ 0.45, 0.68 }) do
		local r = CONE_R * (1 - h) + 0.06
		local band = paint("Band", Vector3.new(0.4, r * 2, r * 2), CFrame.new(x, TOP + 0.34 + CONE_H * h, z) * CFrame.Angles(0, 0, math.pi / 2), WHITE)
		band.Shape = Enum.PartType.Cylinder
		band.Reflectance = 0.35
		band.Parent = m
	end
	m:SetAttribute("Radius", FOOT / 2)
	CS:AddTag(m, "BumperCone")
	m.WorldPivot = CFrame.new(x, TOP, z)
	m.Parent = model
end
for k = -3, 3 do
	cone(CX + k * 15, CZ)
end

model.Parent = area
print(("[park_bumper_track_1119] %d parts"):format(#model:GetDescendants()))
