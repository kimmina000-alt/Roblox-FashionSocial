--!strict
-- (D-1562, user 2026-11-17 with a phone screenshot of someone walking inside the super viking's boat:
-- "탑승 외에는 놀이기구 통과 못 하게 막아") The park rides are built with CanCollide off (riders are held
-- in their seats by the ride code, and a solid boat would shove them out). On each screen this makes the
-- rides solid for this player's own character while they are not riding: the vikings' boats, the
-- carousels (and the fire truck), the tea cups, the jumping star and the ferris wheel. While this player
-- rides (seated, or their UserId is on the ride as a seat / rider attribute) the rides go back to
-- walk-through for them. Only the local character is affected (each character moves on its own screen),
-- so other players' rides are unchanged.
-- Left out: invisible parts, Seats, bulbs / glows / lights (tiny decorations), beams' ends.
-- The vikings are different: their boat hangs above the floor at rest and swings through the pit, so a
-- solid boat lets people walk under it, stand on it and get thrown off when it swings. For a viking an
-- invisible box is made on this screen instead, round the boat where it rests (as wide and long as the
-- boat, from the floor up to just under the axle), solid for this player while not riding; the boat itself stays as it is.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParkConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ParkConfig"))

local player = Players.LocalPlayer
local TAGS = { "ParkViking", "ParkCarousel", "ParkTeaCups", "ParkJumpStar", "ParkWheel" }
local SKIP_NAME = { "Bulb", "Glow", "Light", "Lamp", "WireEnd", "BeamEnd", "Spark" }

type Ride = { model: Model, parts: {[BasePart]: boolean}, viking: boolean, box: Part? }
local rides: {[Model]: Ride} = {}
local solid = false -- (what the rides are now for this player)

local function wanted(p: BasePart): boolean
	if p.Transparency >= 0.95 or p:IsA("Seat") or p:IsA("VehicleSeat") then return false end
	if p.CanCollide then return false end -- (already solid: the ride's own build decides)
	for _, s in ipairs(SKIP_NAME) do
		if string.find(p.Name, s, 1, true) then return false end
	end
	return true
end

local function addPart(ride: Ride, d: Instance)
	if ride.viking then return end
	if d:IsA("BasePart") and ride.parts[d] == nil and wanted(d) then
		ride.parts[d] = true
		if solid then d.CanCollide = true end
	end
end

local function addRide(model: Instance)
	if not model:IsA("Model") or rides[model] or not model:IsDescendantOf(workspace) then return end
	local ride: Ride = { model = model, parts = {}, viking = CollectionService:HasTag(model, "ParkViking") }
	rides[model] = ride
	for _, d in ipairs(model:GetDescendants()) do addPart(ride, d) end
	model.DescendantAdded:Connect(function(d: Instance) addPart(ride, d) end)
	model.DescendantRemoving:Connect(function(d: Instance)
		if d:IsA("BasePart") then ride.parts[d] = nil end
	end)
end

for _, tag in ipairs(TAGS) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do addRide(m) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m: Instance) task.defer(addRide, m) end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(m: Instance)
		if m:IsA("Model") and rides[m] then
			local box = rides[m].box
			if box then box:Destroy() end
			rides[m] = nil
		end
	end)
end

-- this player's UserId on a ride (seat keys on the ride, "Rider" on a slot, keys on a cabin)
local function onRide(): boolean
	local id = player.UserId
	for model in pairs(rides) do
		for _, v in pairs(model:GetAttributes()) do
			if v == id then return true end
		end
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("Model") or d:IsA("BasePart") then
				for _, v in pairs(d:GetAttributes()) do
					if v == id then return true end
				end
			end
		end
	end
	return false
end

local function riding(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Sit then return true end
	return onRide()
end

-- a viking's box, made the first time this screen sees the boat at rest
local function vikingBox(ride: Ride)
	if ride.box or not ride.viking then return end
	local boat = ride.model:FindFirstChild("Boat", true)
	if not boat or not boat:IsA("BasePart") then return end
	local still = ParkConfig.rideState(ride.model, workspace:GetServerTimeNow())
	if not still then return end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local skip: {Instance} = { ride.model }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(skip, p.Character) end
	end
	rp.FilterDescendantsInstances = skip
	local bottom = boat.Position - Vector3.new(0, boat.Size.Y / 2, 0)
	local hit = workspace:Raycast(bottom, Vector3.new(0, -40, 0), rp)
	local floorY = if hit then hit.Position.Y else bottom.Y - 8
	local topY = ride.model:GetPivot().Position.Y - 3 -- (up to just under the axle: nobody jumps onto it from the boarding deck)
	local look = boat.CFrame.LookVector
	local yaw = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
	local box = Instance.new("Part")
	box.Name = "RideKeepOut"
	box.Anchored, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false
	box.Transparency = 1
	box.Size = Vector3.new(boat.Size.X + 2, topY - floorY, boat.Size.Z + 2)
	box.CFrame = yaw + Vector3.new(boat.Position.X, (floorY + topY) / 2, boat.Position.Z)
	box.CanCollide = false -- (set() decides)
	box.Parent = workspace
	ride.box = box
end

-- this player's root inside a box (a rider let off in the pit, or someone already there when the box was
-- made): that box stays walk-through for them until they are out of it, so nobody is shut inside
local function inBox(box: Part): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	local rel = box.CFrame:PointToObjectSpace(root.Position)
	local half = box.Size / 2 + Vector3.new(0, 3, 0) -- (someone pressed against a side is outside it)
	return math.abs(rel.X) < half.X and math.abs(rel.Y) < half.Y and math.abs(rel.Z) < half.Z
end

local function set(want: boolean)
	for _, ride in pairs(rides) do
		vikingBox(ride)
		local box = ride.box
		if box then
			local on = want and not inBox(box)
			if box.CanCollide ~= on then box.CanCollide = on end
		end
	end
	if want == solid then return end
	solid = want
	for _, ride in pairs(rides) do
		for p in pairs(ride.parts) do
			if p.Parent then p.CanCollide = want end
		end
	end
end

local function update()
	set(not riding())
end
-- (a seat key put on a ride, or this player sitting down, turns the rides walk-through at once: the
-- server moves a new rider into the seat right after it writes the key)
local function watch(inst: Instance)
	inst.AttributeChanged:Connect(update)
end
local watched: {[Instance]: boolean} = {}
local function watchRide(ride: Ride)
	for _, d in ipairs({ ride.model :: Instance, table.unpack(ride.model:GetChildren()) }) do
		if not watched[d] and (d:IsA("Model") or d:IsA("BasePart")) then
			watched[d] = true
			watch(d)
		end
	end
end
local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then humanoid.Seated:Connect(update) end
end
if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)

while true do
	for _, ride in pairs(rides) do watchRide(ride) end
	update()
	task.wait(0.2)
end
