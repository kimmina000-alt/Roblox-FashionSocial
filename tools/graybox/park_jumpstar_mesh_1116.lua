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
local disc = Instance.new("Part")
disc.Name = "BaseCollider"
disc.Shape = Enum.PartType.Cylinder
disc.Anchored, disc.Transparency, disc.CastShadow = true, 1, false
disc.Size = Vector3.new(discTop - pivot.Y, radius * 2, radius * 2)
disc.CFrame = CFrame.new(pivot.Position + Vector3.new(0, (discTop - pivot.Y) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
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
local seatY = carRel.Position.Y - h / 2 + h * 0.2 -- (the seat pad's top, measured by a ray: 6.87 over the foot)
local seatZ = carRel.Position.Z - d * 0.25 -- (in front of the tower)
for i = 1, 6 do ride:SetAttribute("Seat" .. i, nil) end
for i = 1, 4 do
	local x = carRel.Position.X + (i - 2.5) * (w * 0.8 / 4)
	ride:SetAttribute("Seat" .. i, CFrame.new(x, seatY, seatZ))
end

local count = 0
for _, d in ipairs(owner:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
print(("[park_jumpstar_mesh_1116] parts %d, disc r %.2f top %.2f, car %s"):format(count, radius, discTop - pivot.Y, tostring(carPart.Size)))
return count
