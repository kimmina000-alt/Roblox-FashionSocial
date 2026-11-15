--!nocheck
-- 점핑스타 = the user's own model (D-1483, user 2026-11-16: "점핑스타 만들었어 교체해 봐" +
-- D:\Roblox\오후\3D 물\jumpingstar.glb). Run after park_jumpingstar_1115.lua (which builds the
-- block version, the fence, the Ride tag and its attributes).
-- Source (place only, imported by the user): ServerStorage.ArtAssets.JumpStarMesh with three
-- MeshParts as they came from Blender: "Cylinder" (base disc, tower, star arms, JUMPIN STAR sign),
-- "Plane" (the car with its four seats) and "BézierCurve" (the lap bar). The import faces +z
-- (the seats' front); it is turned to face the Ride pivot's front (the park's middle) and scaled
-- by SCALE (4.5: four seats 2.3 apart, like the block car's).
-- What changes in Workspace["점핑스타"]:
--   * the block tower, star, machine box, light poles and bulbs are removed (fence, signs and
--     the queue stay);
--   * Ride.Car's block parts are replaced by Plane + BézierCurve (they go up and down as before);
--   * the tower mesh stands as "TowerMesh" (CanCollide false) on an invisible collision disc;
--   * Ride's Seat1..Seat4 sit on the new seats (Seat5 / Seat6 go: four seats).
-- Idempotent: running it again rebuilds the mesh parts from the source.

local SCALE = 4.5
local KEEP = { FencePanel = true, FenceWall = true, SignBoard = true, SignPost = true, Ride = true }

local owner = workspace:FindFirstChild("점핑스타")
local src = game.ServerStorage:FindFirstChild("ArtAssets") and game.ServerStorage.ArtAssets:FindFirstChild("JumpStarMesh")
assert(owner and owner:FindFirstChild("Ride"), "run park_jumpingstar_1115.lua first")
assert(src, "ServerStorage.ArtAssets.JumpStarMesh is missing (the user's import)")
local ride = owner.Ride
local car = ride:FindFirstChild("Car")
local pivot = ride:GetPivot() -- (the tower's foot; -z = the front)

local function find(name)
	for _, d in ipairs(src:GetDescendants()) do
		-- (the importer names the lap bar "BézierCurve" as plain text: match its first letter)
		if d:IsA("MeshPart") and (d.Name == name or name:sub(1, 1) == "B" and d.Name:sub(1, 1) == "B") then return d end
	end
	error("no " .. name .. " in JumpStarMesh")
end
local tower, carMesh, bar = find("Cylinder"), find("Plane"), find("BézierCurve")
-- the import's foot: under the tower's middle, at its bottom
local foot = Vector3.new(tower.Position.X, tower.Position.Y - tower.Size.Y / 2, tower.Position.Z)
local turn = pivot -- (the import's front, its readable sign side, lines up with the Ride's -z front as it is)

local function place(part: MeshPart, name: string, parent: Instance): MeshPart
	local p = part:Clone()
	p.Name = name
	local rel = CFrame.new(foot):ToObjectSpace(part.CFrame)
	p.Size = part.Size * SCALE
	p.CFrame = turn * (CFrame.new(rel.Position * SCALE) * rel.Rotation)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- 1. clear the block version (and an earlier run of this script)
for _, c in ipairs(owner:GetChildren()) do
	if not KEEP[c.Name] then c:Destroy() end
end
if car then
	for _, c in ipairs(car:GetChildren()) do c:Destroy() end
else
	car = Instance.new("Model")
	car.Name = "Car"
	car.Parent = ride
end
car.WorldPivot = pivot

-- 2. the tower, the car, the lap bar
local towerPart = place(tower, "TowerMesh", owner)
local carPart = place(carMesh, "CarMesh", car)
local barPart = place(bar, "LapBarMesh", car)
carPart.CanQuery = false
barPart.CanQuery = false
-- (D-1488, user: "점핑스타에 알맞는 재질 좀 입혀 줘") glossy painted steel for the tower and the car,
-- leather for the padded lap bar
towerPart.Material, towerPart.Reflectance = Enum.Material.SmoothPlastic, 0.08
carPart.Material, carPart.Reflectance = Enum.Material.SmoothPlastic, 0.06
barPart.Material = Enum.Material.Leather
-- (D-1485, user: "의자 사이즈 캐릭터 크기에 맞춰서 조절해 봐 안전바 조금 더 내리고") the car is
-- CAR_SCALE of the tower's scale (seats 2.3 wide, 3 deep, like a sitting avatar), shrunk about its
-- back-bottom edge so it stays against the tower; the lap bar drops BAR_DROP more onto the laps.
local CAR_SCALE = 0.75
local BAR_DROP = 0.5
do
	local c = pivot:ToObjectSpace(carPart.CFrame)
	local anchor = c.Position + Vector3.new(0, -carPart.Size.Y / 2, carPart.Size.Z / 2)
	for _, p in ipairs({ carPart, barPart }) do
		local r = pivot:ToObjectSpace(p.CFrame)
		p.Size *= CAR_SCALE
		p.CFrame = pivot * (CFrame.new(anchor + (r.Position - anchor) * CAR_SCALE) * r.Rotation)
	end
	barPart.CFrame = pivot * CFrame.new(0, -BAR_DROP, 0) * pivot:ToObjectSpace(barPart.CFrame)
end

-- 3. a walkable disc where the mesh's base disc is (radius = half the tower mesh's width at the floor)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { towerPart }
local radius, discTop = 0, pivot.Y
for r = 0.5, 12, 0.25 do
	local p = pivot * Vector3.new(r, 0, 0)
	local hit = workspace:Raycast(Vector3.new(p.X, pivot.Y + 3, p.Z), Vector3.new(0, -4, 0), params)
	if not hit then break end
	radius, discTop = r, math.max(discTop, hit.Position.Y)
end
towerPart.CanQuery = false
-- (D-1488) a grey diamond-plate floor over the mesh's disc, 0.03 above it (the walkable part too)
local disc = Instance.new("Part")
disc.Name = "BasePlate"
disc.Shape = Enum.PartType.Cylinder
disc.Anchored, disc.Transparency, disc.CastShadow = true, 0, false
disc.Material, disc.Color = Enum.Material.DiamondPlate, Color3.fromRGB(150, 154, 160)
disc.Size = Vector3.new(discTop - pivot.Y + 0.03, radius * 2, radius * 2)
disc.CFrame = CFrame.new(pivot.Position + Vector3.new(0, (discTop - pivot.Y + 0.03) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
disc.Parent = owner
-- the tower pole itself (riders and walkers do not pass through it)
local pole = Instance.new("Part")
pole.Name = "PoleCollider"
pole.Anchored, pole.Transparency, pole.CastShadow = true, 1, false
pole.Size = Vector3.new(1.2 * SCALE / 4.5 * 2, 30, 1.2 * SCALE / 4.5 * 2)
pole.CFrame = pivot * CFrame.new(0, 15, 0)
pole.Parent = owner

-- 4. four seats along the car's front (seat tops, from the pivot with the car at the bottom)
local carRel = pivot:ToObjectSpace(carPart.CFrame)
local w, h, d = carPart.Size.X, carPart.Size.Y, carPart.Size.Z
local seatZ = carRel.Position.Z - d * 0.25 -- (in front of the tower)
-- the seat pad's top: a ray down onto the car mesh at each seat (fallback a fifth up the car)
carPart.CanQuery = true
local carParams = RaycastParams.new()
carParams.FilterType = Enum.RaycastFilterType.Include
carParams.FilterDescendantsInstances = { carPart }
for i = 1, 6 do ride:SetAttribute("Seat" .. i, nil) end
for i = 1, 4 do
	-- (D-1490, user: "좌석마다 색깔 넣은 거 캐릭터 앉는 위치에 맞춰서") on the middles of the four coloured
	-- seat panels, measured from the front: 0.2104 of the car apart, 0.033 off its box middle
	local x = carRel.Position.X + 0.033 + (i - 2.5) * (w * 0.2104)
	local from = pivot * Vector3.new(x, carRel.Position.Y + h / 2 + 1, seatZ)
	local hit = workspace:Raycast(from, -pivot.UpVector * (h + 2), carParams)
	local seatY = if hit then pivot:PointToObjectSpace(hit.Position).Y else carRel.Position.Y - h / 2 + h * 0.2
	ride:SetAttribute("Seat" .. i, CFrame.new(x, seatY, seatZ))
end
carPart.CanQuery = false

-- 5. jump height in step with the tower (D-1484: the user's v2 tower is 66 high): the car's top
-- stops under the arms, JUMP_TOP over the foot (ParkConfig.JumpKeys go up to 22; Ride JumpScale)
local JUMP_TOP = 41
local topKey = 22
ride:SetAttribute("JumpScale", math.max(1, (JUMP_TOP - (carRel.Position.Y + h / 2)) / topKey))

-- 6. bulbs like the photo (D-1484, user: "사진 참고해서 조명 추가해 줘"): the real ride has bulb
-- columns up both sides of the tower and bulbs round its stars and its red letters. Here: a column
-- of red / blue bulbs on each outer side of the tower, and bulbs along every outline of the top
-- (arms, small stars, the big star in warm white; the JUMPIN STAR letters in red), found by rays
-- from the front on a 0.25 grid (an outline = a hit next to a miss or a step in depth).
local lights = Instance.new("Model")
lights.Name = "Lights"
towerPart.CanQuery = true
local BULB = 0.42
local WARM = Color3.fromRGB(255, 236, 170)
local RED = Color3.fromRGB(255, 60, 60)
local BLUE = Color3.fromRGB(70, 130, 255)
local function bulb(localPos: Vector3, color: Color3)
	local b = Instance.new("Part")
	b.Name = "Bulb"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * BULB
	b.Material = Enum.Material.Neon
	b.Color = color
	b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery, b.CastShadow = true, false, false, false, false
	b.CFrame = pivot * CFrame.new(localPos)
	b.Parent = lights
end
local function frontHit(x: number, y: number): number?
	local a = pivot * Vector3.new(x, y, -20)
	local hit = workspace:Raycast(a, pivot * Vector3.new(x, y, 20) - a, params)
	return hit and pivot:PointToObjectSpace(hit.Position).Z or nil
end
-- 6a. the side columns: the tower's outer edges below the arms
local function sideX(y: number, dir: number): number?
	local last
	for x = 0, dir * 6, dir * 0.1 do
		if frontHit(x, y) then last = x elseif last then break end
	end
	return last
end
local ARM_Y = JUMP_TOP + 0.5
local n = 0
for y = discTop - pivot.Y + 4.1, ARM_Y, 1.1 do -- (D-1488: from 4 up; lower down the bulbs stood off the flared foot)
	n += 1
	for _, dir in ipairs({ -1, 1 }) do
		local x = sideX(y, dir)
		if x then
			local z = frontHit(x - dir * 0.2, y) or 2
			bulb(Vector3.new(x + dir * 0.12, y, z + 0.1), if (n + (dir > 0 and 1 or 0)) % 2 == 0 then RED else BLUE)
		end
	end
end
-- 6b. outlines above the arms' foot
local STEP = 0.25
local grid, xs, ys = {}, {}, {}
for x = -10, 10, STEP do table.insert(xs, x) end
for y = ARM_Y - 1, towerPart.Size.Y + 1, STEP do table.insert(ys, y) end
for i, x in ipairs(xs) do
	grid[i] = {}
	for j, y in ipairs(ys) do grid[i][j] = frontHit(x, y) or false end
end
local edges = {}
for i = 2, #xs - 1 do
	for j = 2, #ys - 1 do
		local z = grid[i][j]
		if z then
			local edge = false
			for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nz = grid[i + o[1]][j + o[2]]
				if not nz or nz - z > 0.5 then edge = true end
			end
			if edge then table.insert(edges, Vector3.new(xs[i], ys[j], z)) end
		end
	end
end
local placed = {}
for _, p in ipairs(edges) do
	local gap = if p.Z < 1.4 then 0.75 else 1.0 -- (letters closer)
	local ok = true
	for _, q in ipairs(placed) do
		if (q - p).Magnitude < gap then ok = false break end
	end
	if ok then
		table.insert(placed, p)
		bulb(Vector3.new(p.X, p.Y, p.Z - 0.12), if p.Z < 1.4 then RED else WARM)
	end
end
towerPart.CanQuery = false
lights.Parent = owner

local count = 0
for _, d in ipairs(owner:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
print(("[park_jumpstar_mesh_1116] parts %d, disc r %.2f top %.2f, car %s"):format(count, radius, discTop - pivot.Y, tostring(carPart.Size)))
return count
