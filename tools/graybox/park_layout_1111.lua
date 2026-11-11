--!nocheck
-- 놀이공원 구성 · 배치 (D-1316, user 2026-11-11: "사진 보고 놀이공원 구성 및 배치 작업해 /
-- 기존에 기능 구현해 놓은 관람차, 그네, 회전목마 잘 이동해야 함", 사진
-- docs/04_ART/references/amusement_park_map.png, 놀이시설 안내도).
--
-- Run in Edit mode at the end of the layout chain (after park_raise). It can
-- run on its own and again: the rides go to fixed places (a move of 0 the
-- second time) and Hongdae_Layout.ParkBlockout is built anew.
--
-- The plot (inside the walls, raised 16): x -147..-53, z -282..-524, the gate
-- in the middle of the south side (z -278). The map is laid on it with its
-- entrance (bottom left) at the gate and its long side running north: the
-- map's left → south, right → north, top → west, bottom → east.
--   * the working rides are moved whole (their parts and their bases): the
--     ferris wheel to the north end (the park's landmark behind everything),
--     the carousel (6 회전목마) to the west middle, the swing set (as 18 파도그네)
--     beside it. ParkRidesController reads their Hub / Center / Pivot every
--     frame, so they ride the same at the new place.
--   * the playground (spring riders, slide, its floor), the flower tunnel and
--     the photo spot stay where they are (east middle).
--   * the other places of the map are blockout pieces in
--     Hongdae_Layout.ParkBlockout (boxes and cylinders, no function yet).

local Z = workspace.Graybox_MainSocial:FindFirstChild("06_Park_Playground")
local L = workspace:FindFirstChild("Hongdae_Layout")
assert(Z and L, "park zone or layout missing")
local GY = 16.25 -- the park's ground

-- ---------------------------------------------------------------------------
-- 1) the working rides, moved whole
local function near(name: string, p: Vector3, r: number): {Instance}
	local out = {}
	for _, c in ipairs(Z:GetChildren()) do
		if c.Name == name then
			local q = if c:IsA("Model") then c:GetPivot().Position elseif c:IsA("BasePart") then c.Position else nil
			if q and Vector3.new(q.X - p.X, 0, q.Z - p.Z).Magnitude <= r then table.insert(out, c) end
		end
	end
	return out
end
local function move(list: {Instance}, d: Vector3)
	for _, c in ipairs(list) do
		if c:IsA("Model") then c:PivotTo(c:GetPivot() + d) elseif c:IsA("BasePart") then c.CFrame = c.CFrame + d end
	end
end
-- a group: its anchor (a model whose pivot is the group's place) and its other pieces
local function group(anchorName: string, target: Vector3, pieces: {{string | number}})
	local anchor = Z:FindFirstChild(anchorName)
	if not anchor then warn("[park_layout] missing " .. anchorName) return end
	-- (a model's middle, not its pivot: the wheel's pivot is not its hub)
	local a = if anchor:IsA("Model") then (anchor:GetBoundingBox()).Position else anchor:GetPivot().Position
	local d = Vector3.new(target.X - a.X, 0, target.Z - a.Z)
	if d.Magnitude < 0.01 then return end
	local list = { anchor }
	for _, piece in ipairs(pieces) do
		for _, c in ipairs(near(piece[1] :: string, a, piece[2] :: number)) do
			if c ~= anchor and not table.find(list, c) then table.insert(list, c) end
		end
	end
	move(list, d)
end
-- (the swing set: its four seats, legs, bar and label hang together; the
-- anchor is Swing2's pivot)
local ride = {
	-- 관람차: north end, in the middle (its circle stands along the plot)
	{ "FerrisWheel", Vector3.new(-98, 0, -462), { { "WheelPlatform", 30 }, { "WheelPlatformEdge", 30 }, { "WheelRamp", 45 }, { "Label", 30 } } },
	-- 6 회전목마: west middle
	{ "Carousel", Vector3.new(-123, 0, -420), { { "CarouselBase", 4 }, { "CarouselBaseRing", 4 }, { "Label", 4 } } },
	-- 18 파도그네 → the swing set, north of the carousel
	{ "Swing2", Vector3.new(-131, 0, -450), { { "Swing1", 16 }, { "Swing3", 16 }, { "Swing4", 22 }, { "SwingLeg", 22 }, { "SwingBar", 12 }, { "Label", 8 } } },
}
for _, r in ipairs(ride) do group(r[1], r[2], r[3]) end

-- ---------------------------------------------------------------------------
-- 2) the other places, as blockout pieces
local old = L:FindFirstChild("ParkBlockout")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "ParkBlockout"
local count = 0
local C = {
	stone = Color3.fromRGB(196, 190, 178), red = Color3.fromRGB(214, 64, 58), yellow = Color3.fromRGB(246, 196, 60),
	blue = Color3.fromRGB(64, 128, 214), green = Color3.fromRGB(74, 168, 96), pink = Color3.fromRGB(236, 120, 170),
	purple = Color3.fromRGB(140, 96, 200), orange = Color3.fromRGB(240, 140, 50), white = Color3.fromRGB(240, 238, 232),
	dark = Color3.fromRGB(54, 56, 62), water = Color3.fromRGB(90, 160, 214), wood = Color3.fromRGB(150, 104, 64),
	rail = Color3.fromRGB(120, 124, 132), roof = Color3.fromRGB(70, 72, 80),
}
local function grp(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	return m
end
local function part(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = m
	count += 1
	return p
end
local UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder stood up
local function at(x: number, y: number, z: number): CFrame return CFrame.new(x, GY + y, z) end
local function disc(m: Instance, name: string, x: number, z: number, d: number, y: number, h: number, color: Color3): Part
	return part(m, name, Vector3.new(h, d, d), at(x, y + h / 2, z) * UP, color, Enum.PartType.Cylinder)
end
local function box(m: Instance, name: string, x: number, z: number, sx: number, sz: number, y: number, h: number, color: Color3): Part
	return part(m, name, Vector3.new(sx, h, sz), at(x, y + h / 2, z), color)
end
-- a round ride: a platform, a pole, a canopy and seats round the edge
local function roundRide(name: string, x: number, z: number, d: number, seats: number, colors: {Color3}, canopy: boolean?)
	local m = grp(name)
	disc(m, "Platform", x, z, d, 0, 1, C.stone)
	disc(m, "Deck", x, z, d - 2, 1, 0.4, colors[1])
	disc(m, "Pole", x, z, 2, 1.4, 9, C.white)
	if canopy ~= false then
		disc(m, "Canopy", x, z, d - 1, 10.4, 1, colors[2])
		disc(m, "CanopyTop", x, z, d * 0.45, 11.4, 1.6, colors[1])
	end
	for k = 0, seats - 1 do
		local a = k / seats * math.pi * 2
		local r = d / 2 - 3
		part(m, "Seat", Vector3.new(2.4, 2, 2.4), at(x + math.cos(a) * r, 2.4, z + math.sin(a) * r) * CFrame.Angles(0, -a, 0), colors[(k % #colors) + 1])
	end
	return m
end
local function building(name: string, x: number, z: number, sx: number, sz: number, h: number, color: Color3, roof: Color3)
	local m = grp(name)
	box(m, "Body", x, z, sx, sz, 0, h, color)
	box(m, "Roof", x, z, sx + 2, sz + 2, h, 1.2, roof)
	box(m, "Door", x, z + sz / 2 + 0.05, 4, 0.2, 0, 6, C.dark) -- (the door on the south face)
	return m
end

-- 매표소 · 안내 · 화장실 by the gate (inside)
building("Kiosk_Info", -78, -292, 8, 6, 7, C.white, C.blue)
building("Restroom", -140, -292, 10, 7, 8, C.white, C.green)
building("Snack_Bar", -88, -350, 9, 7, 7, C.yellow, C.red) -- (매점)

-- 1 평화열차: a track along the west wall, a station, a locomotive and two cars
do
	local m = grp("01_PeaceTrain")
	box(m, "Track", -145, -390, 4, 90, 0, 0.4, C.rail)
	for k = 0, 14 do box(m, "Sleeper", -145, -347 - k * 6, 5, 0.8, 0, 0.3, C.wood) end
	building("01_Station", -136, -346, 6, 10, 7, C.wood, C.red).Parent = m
	box(m, "Locomotive", -145, -372, 3.2, 8, 0.4, 4.5, C.dark)
	disc(m, "Chimney", -145, -368, 1.2, 4.9, 2, C.dark)
	box(m, "Cab", -145, -375, 3.4, 3, 4.9, 2.4, C.red)
	box(m, "Car", -145, -382, 3, 6, 0.4, 3, C.green)
	box(m, "Car", -145, -389, 3, 6, 0.4, 3, C.yellow)
end

-- 2 슈퍼바이킹: an A-frame with the ship hanging along the plot
do
	local m = grp("02_SuperViking")
	local x, z = -122, -318
	for _, dz in ipairs({ -11, 11 }) do
		part(m, "Leg", Vector3.new(1.5, 22, 1.5), at(x - 4, 10, z + dz) * CFrame.Angles(0, 0, math.rad(-12)), C.rail)
		part(m, "Leg", Vector3.new(1.5, 22, 1.5), at(x + 4, 10, z + dz) * CFrame.Angles(0, 0, math.rad(12)), C.rail)
	end
	box(m, "Beam", x, z, 1.5, 24, 20, 1.5, C.rail)
	box(m, "Ship", x, z, 5, 22, 5, 4, C.wood)
	box(m, "ShipStripe", x, z, 5.2, 22, 8, 0.8, C.red)
	box(m, "Mast", x, z, 0.8, 0.8, 9, 11, C.white)
	box(m, "Base", x, z, 14, 28, 0, 0.6, C.stone)
end

-- 14 유레카 (east of the plaza) and 23 소방차 (a little round track with a fire truck)
roundRide("14_Eureka", -66, -312, 18, 8, { C.purple, C.yellow })
do
	local m = grp("23_FireTruck")
	disc(m, "Track", -70, -338, 14, 0, 0.4, C.rail)
	disc(m, "Lawn", -70, -338, 9, 0.4, 0.2, C.green)
	box(m, "Truck", -64, -338, 2.4, 5, 0.6, 2.6, C.red)
	box(m, "Ladder", -64, -338.5, 0.8, 4, 3.2, 0.4, C.white)
end

-- 10 물보트 (a pool with boats) and 9 미니바이킹
do
	local m = grp("10_WaterBoat")
	box(m, "Rim", -124, -362, 22, 16, 0, 1.2, C.stone)
	local w = box(m, "Water", -124, -362, 20, 14, 0.2, 1.2, C.water)
	w.Material = Enum.Material.Glass
	w.Transparency = 0.2
	for k = 0, 2 do box(m, "Boat", -130 + k * 6, -360 - (k % 2) * 3, 3, 4, 1.2, 1.2, ({ C.yellow, C.red, C.blue })[k + 1]) end
end
do
	local m = grp("09_MiniViking")
	local x, z = -104, -366
	box(m, "Base", x, z, 9, 14, 0, 0.6, C.stone)
	box(m, "Beam", x, z, 1, 12, 10, 1, C.rail)
	for _, dz in ipairs({ -5.5, 5.5 }) do box(m, "Post", x, z + dz, 1, 1, 0.6, 9.4, C.rail) end
	box(m, "Ship", x, z, 3, 10, 3, 2.5, C.orange)
end

-- 7 회전컵 and 3 점퍼보트
roundRide("07_TeaCups", -126, -387, 15, 5, { C.pink, C.blue, C.yellow, C.green, C.purple }, false)
roundRide("03_JumperBoat", -105, -394, 13, 6, { C.blue, C.white })

-- 24 점핑스타: a drop tower
do
	local m = grp("24_JumpingStar")
	local x, z = -107, -440
	disc(m, "Base", x, z, 8, 0, 1, C.stone)
	box(m, "Tower", x, z, 2.5, 2.5, 1, 30, C.red)
	box(m, "Crown", x, z, 4, 4, 31, 2, C.yellow)
	disc(m, "SeatRing", x, z, 7, 10, 1.5, C.blue)
end

-- 4 범퍼카: an arena with a roof on posts and cars
do
	local m = grp("04_BumperCars")
	local x, z = -66, -460 -- (clear of the wheel's cabins, x -78 and west)
	box(m, "Floor", x, z, 24, 16, 0, 0.4, C.dark)
	box(m, "Rail", x, z - 8, 24, 0.6, 0, 1.2, C.yellow)
	box(m, "Rail", x, z + 8, 24, 0.6, 0, 1.2, C.yellow)
	box(m, "Rail", x - 12, z, 0.6, 16, 0, 1.2, C.yellow)
	box(m, "Rail", x + 12, z, 0.6, 16, 0, 1.2, C.yellow)
	for _, dx in ipairs({ -11.5, 11.5 }) do for _, dz in ipairs({ -7.5, 7.5 }) do box(m, "Post", x + dx, z + dz, 0.8, 0.8, 0, 9, C.white) end end
	box(m, "Roof", x, z, 25, 17, 9, 0.8, C.blue)
	for k = 0, 3 do box(m, "Car", x - 7 + k * 5, z - 3 + (k % 2) * 6, 2.4, 3, 0.4, 1.4, ({ C.red, C.green, C.yellow, C.pink })[k + 1]) end
end

-- 5 뮤직익스프레스 (north-west), 8 모험여행 and 20 도깨비집 (houses at the north wall)
roundRide("05_MusicExpress", -132, -480, 22, 10, { C.purple, C.pink, C.yellow })
do
	local b = building("08_AdventureTour", -131, -510, 26, 14, 10, C.green, C.orange)
	local _ = b
	local h = building("20_GhostHouse", -70, -510, 24, 14, 10, C.dark, C.purple)
	local _2 = h
end

-- 22 아기기차 + 21 오토바이: an oval track with a little train and a motorbike
do
	local m = grp("22_KiddieTrain")
	local x, z = -66, -486
	box(m, "TrackN", x, z - 6, 22, 1.6, 0, 0.4, C.rail)
	box(m, "TrackS", x, z + 6, 22, 1.6, 0, 0.4, C.rail)
	box(m, "TrackW", x - 10.2, z, 1.6, 12, 0, 0.4, C.rail)
	box(m, "TrackE", x + 10.2, z, 1.6, 12, 0, 0.4, C.rail)
	box(m, "Lawn", x, z, 18, 10, 0, 0.3, C.green)
	box(m, "Engine", x - 4, z - 6, 4, 2, 0.4, 2.2, C.blue)
	box(m, "Wagon", x + 1, z - 6, 4, 2, 0.4, 1.6, C.yellow)
	box(m, "Motorbike", x + 6, z + 6, 2.4, 1.2, 0.4, 1.4, C.red) -- (21 오토바이)
end

-- 13 번개열차: a small, low roller coaster on posts behind the wheel's foot
-- (under the wheel's rim, which is 16+ studs up from z -505 on: at most 8 high)
do
	local m = grp("13_LightningCoaster")
	local pts = { Vector3.new(-114, 3, -506), Vector3.new(-104, 7, -505), Vector3.new(-92, 8, -508), Vector3.new(-86, 5, -513), Vector3.new(-92, 3, -519), Vector3.new(-106, 6, -519), Vector3.new(-114, 3, -506) }
	for k = 1, #pts - 1 do
		local a, b = pts[k], pts[k + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		part(m, "Track", Vector3.new(2, 0.5, len), CFrame.lookAt(Vector3.new(mid.X, GY + mid.Y, mid.Z), Vector3.new(b.X, GY + b.Y, b.Z)), C.yellow)
		box(m, "Post", a.X, a.Z, 0.7, 0.7, 0, a.Y, C.rail)
	end
	box(m, "Train", -104, -505, 2.2, 3, 7.4, 1.4, C.red)
	box(m, "Station", -114, -506, 6, 5, 0, 3, C.stone)
end

-- 11 하늘차 (Sky Cycle): a rail high along the west wall at the north end
do
	local m = grp("11_SkyCycle")
	box(m, "Rail", -146, -475, 1.4, 90, 12, 0.8, C.rail)
	for k = 0, 6 do box(m, "Post", -146, -432 - k * 14, 0.8, 0.8, 0, 12, C.rail) end
	box(m, "Cycle", -146, -458, 2.2, 3, 9.6, 2.4, C.yellow)
	box(m, "Station", -138, -432, 6, 6, 0, 12, C.white)
end

-- paths: the main walk from the gate north to the wheel, and a ring round the middle
do
	local m = grp("Paths")
	local function walk(x: number, z: number, sx: number, sz: number)
		local p = box(m, "Walk", x, z, sx, sz, 0, 0.12, Color3.fromRGB(226, 214, 190))
		p.CanCollide = false
	end
	walk(-97, -370, 10, 176) -- (gate → the wheel)
	walk(-97, -345, 80, 6)
	walk(-97, -470, 80, 6)
end

root.Parent = L
print(string.format("[park_layout] %d blockout parts", count))
return count
