--!strict
-- (D-1413) Bumper cars (BumperCarConfig): turns each car model tagged "BumperCar" (the user's
-- mesh, Workspace.Scene.BumperCar*) into a ride car:
--   Root (invisible, on the floor, tagged BumperCarRoot)  ← weld ←  Body (the mesh)  ← weld ←  Seat
-- A VehicleSeat (no touch sitting; a "타기" prompt sits you), so the default controls give the
-- driver's pedal / wheel as ThrottleFloat / SteerFloat on PC and phones alike. While someone
-- drives, the car is unanchored and the driver's client owns it and moves it
-- (BumperCarController); empty, it is anchored where it was left. The rider's body parts go to
-- a collision group that hits nothing, so they never fight the car's own motion.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BumperCarConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("BumperCarConfig"))

local BumperCarService = {}

local RIDER_GROUP = "BumperRider"
local CAR_GROUP = "BumperCar"

local function setupGroups()
	for _, g in ipairs({ RIDER_GROUP, CAR_GROUP }) do
		pcall(function() PhysicsService:RegisterCollisionGroup(g) end)
	end
	for _, g in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		pcall(function() PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, g.name, false) end)
		pcall(function() PhysicsService:CollisionGroupSetCollidable(CAR_GROUP, g.name, false) end)
	end
end

local function weld(a: BasePart, b: BasePart, c0: CFrame): Weld
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, c0
	w.Parent = a
	return w
end

local riderGroups: {[Model]: {[BasePart]: string}} = {}

local function setRider(character: Model?, on: boolean)
	if not character then return end
	if on then
		local saved = {}
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") then
				saved[d] = d.CollisionGroup
				d.CollisionGroup = RIDER_GROUP
			end
		end
		riderGroups[character] = saved
	else
		local saved = riderGroups[character]
		riderGroups[character] = nil
		if saved then
			for part, group in pairs(saved) do
				if part.Parent then part.CollisionGroup = group end
			end
		end
	end
end

local function build(model: Model)
	if model:FindFirstChild("BumperRoot") or not model:IsDescendantOf(workspace) then return end
	local body = model:FindFirstChildWhichIsA("MeshPart")
	if not body then return end
	-- the user's mesh, scaled to a car one avatar fits in (keeps its proportions; idempotent)
	local scale = BumperCarConfig.Length / body.MeshSize.X
	body.Size = body.MeshSize * scale
	local hall = BumperCarConfig.Hall
	local r = body.CFrame.RightVector
	local yaw = math.atan2(-r.Z, r.X) -- (the car's +X; Euler angles flip near 180°)
	local base = CFrame.new(body.Position.X, hall.floorY + 0.5, body.Position.Z) * CFrame.Angles(0, yaw, 0)
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch, body.Massless = false, false, false, false, true
	body.CollisionGroup = CAR_GROUP
	body.CFrame = base * CFrame.new(0, body.Size.Y / 2 - 0.5, 0)

	local root = Instance.new("Part")
	root.Name = "BumperRoot"
	root.Size = Vector3.new(body.Size.X, 1, body.Size.Z)
	root.CFrame = base
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.CollisionGroup = CAR_GROUP
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 1, 1)
	root:SetAttribute("Length", body.Size.X)
	root:SetAttribute("Width", body.Size.Z + 2 * BumperCarConfig.RingPad)
	root.Parent = model
	local bodyWeld = weld(root, body, CFrame.new(0, body.Size.Y / 2 - 0.5, 0))
	bodyWeld.Name = "BodyWeld"

	local seat = Instance.new("VehicleSeat")
	seat.Name = "BumperSeat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Transparency = 1
	seat.CanCollide, seat.CanQuery, seat.CanTouch = false, false, false
	seat.Massless = true
	seat.HeadsUpDisplay = false
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
	seat.CollisionGroup = CAR_GROUP
	seat.CFrame = body.CFrame * CFrame.new(BumperCarConfig.SeatOffset) * CFrame.Angles(0, -math.pi / 2, 0) -- (a seat faces its -Z: turned to the car's +X)
	seat.Anchored = false
	seat.Parent = model
	weld(body, seat, body.CFrame:ToObjectSpace(seat.CFrame))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "범퍼카 타기"
	prompt.ObjectText = "범퍼카"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat

	CollectionService:AddTag(root, BumperCarConfig.RootTag)

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or seat.Occupant then return end
		if humanoid.SeatPart then humanoid.Sit = false end
		seat:Sit(humanoid)
	end)

	local driver: Player? = nil
	local riderModel: Model? = nil
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if humanoid then
			riderModel = humanoid.Parent :: Model
			driver = Players:GetPlayerFromCharacter(riderModel)
			prompt.Enabled = false
			setRider(riderModel, true)
			root:SetAttribute("Driver", if driver then driver.UserId else 0)
			-- (the seat weld first pulls the rider onto the seat while the car is still anchored;
			-- unanchored at once, the car was pulled to the rider instead)
			task.delay(0.2, function()
				if seat.Occupant ~= humanoid then return end
				root.Anchored = false
				if driver then pcall(function() root:SetNetworkOwner(driver) end) end
			end)
		else
			setRider(riderModel, false)
			riderModel, driver = nil, nil
			-- parked where it was left: flat on the floor, still
			local cf = root.CFrame
			local y = math.atan2(-cf.RightVector.Z, cf.RightVector.X)
			root.Anchored = true
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			root.CFrame = CFrame.new(cf.Position.X, hall.floorY + 0.5, cf.Position.Z) * CFrame.Angles(0, y, 0)
			root:SetAttribute("Driver", nil)
			prompt.Enabled = true
		end
	end)
end

function BumperCarService.Start()
	setupGroups()
	for _, m in ipairs(CollectionService:GetTagged(BumperCarConfig.Tag)) do
		if m:IsA("Model") then task.spawn(build, m) end
	end
	CollectionService:GetInstanceAddedSignal(BumperCarConfig.Tag):Connect(function(m)
		if m:IsA("Model") then task.defer(build, m) end
	end)
end

return BumperCarService
