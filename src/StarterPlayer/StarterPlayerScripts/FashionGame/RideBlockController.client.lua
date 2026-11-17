--!strict
-- (D-1561, user 2026-11-17 with a phone screenshot of someone walking inside the super viking's boat:
-- "탑승 외에는 놀이기구 통과 못 하게 막아") The park rides are built with CanCollide off (riders are held
-- in their seats by the ride code, and a solid boat would shove them out). On each screen this makes the
-- rides solid for this player's own character while they are not riding: the vikings' boats, the
-- carousels (and the fire truck), the tea cups, the jumping star and the ferris wheel. While this player
-- rides (seated, or their UserId is on the ride as a seat / rider attribute) the rides go back to
-- walk-through for them. Only the local character is affected (each character moves on its own screen),
-- so other players' rides are unchanged.
-- Left out: invisible parts, Seats, bulbs / glows / lights (tiny decorations), beams' ends.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local TAGS = { "ParkViking", "ParkCarousel", "ParkTeaCups", "ParkJumpStar", "ParkWheel" }
local SKIP_NAME = { "Bulb", "Glow", "Light", "Lamp", "WireEnd", "BeamEnd", "Spark" }

type Ride = { model: Model, parts: {[BasePart]: boolean} }
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
	if d:IsA("BasePart") and ride.parts[d] == nil and wanted(d) then
		ride.parts[d] = true
		if solid then d.CanCollide = true end
	end
end

local function addRide(model: Instance)
	if not model:IsA("Model") or rides[model] or not model:IsDescendantOf(workspace) then return end
	local ride: Ride = { model = model, parts = {} }
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
		if m:IsA("Model") then rides[m] = nil end
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

local function set(want: boolean)
	if want == solid then return end
	solid = want
	for _, ride in pairs(rides) do
		for p in pairs(ride.parts) do
			if p.Parent then p.CanCollide = want end
		end
	end
end

while true do
	set(not riding())
	task.wait(0.2)
end
