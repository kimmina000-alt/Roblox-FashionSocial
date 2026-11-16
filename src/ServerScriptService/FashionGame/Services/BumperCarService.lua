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
	-- the user's mesh at the size it has in the place (D-1414: two seats side by side), or
	-- scaled to BumperCarConfig.Length (idempotent)
	local length = BumperCarConfig.Length
	if length then body.Size = body.MeshSize * (length / body.MeshSize.X) end
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

	-- (D-1414, user: "범퍼카 하나에 두 명 탈 수 있게 하고 먼저 탄 사람이 왼쪽에 탑승해서 운전권 가지게 해")
	-- the driver's seat on the left (the car's -Z side, facing +X) is the VehicleSeat; the
	-- passenger's seat on the right is a plain Seat (no controls)
	local off = BumperCarConfig.SeatOffset
	local function newSeat(class: string, name: string, side: number): Seat
		local seat = Instance.new(class) :: any
		seat.Name = name
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Transparency = 1
		seat.CanCollide, seat.CanQuery, seat.CanTouch = false, false, false
		seat.Massless = true
		if class == "VehicleSeat" then
			seat.HeadsUpDisplay = false
			seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
		end
		seat.CollisionGroup = CAR_GROUP
		seat.CFrame = body.CFrame * CFrame.new(off.X, off.Y, side * off.Z) * CFrame.Angles(0, -math.pi / 2, 0) -- (a seat faces its -Z: turned to the car's +X)
		seat.Anchored = false
		seat.Parent = model
		weld(body, seat, body.CFrame:ToObjectSpace(seat.CFrame))
		return seat
	end
	local seat = newSeat("VehicleSeat", "BumperSeat", -1) :: any -- (driver, left)
	local passengerSeat = newSeat("Seat", "BumperSeatR", 1) -- (passenger, right)

	-- (D-1415) the steering wheel in front of the driver: a rim the hands hold (IK on every
	-- client, BumperCarController) and a column down to the floor; WheelWeld turns it
	local so = BumperCarConfig.SteeringOffset
	local hub = body.CFrame * CFrame.new(off.X + so.X, off.Y + so.Y, -off.Z + so.Z)
	local wheelBase = hub * CFrame.Angles(0, 0, math.pi / 2 + BumperCarConfig.SteeringTilt) -- (a cylinder's axis is its X: tipped up towards the driver)
	local ws = BumperCarConfig.SteeringSize
	local rim = Instance.new("Part")
	rim.Name = "SteeringWheel"
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.18, ws, ws)
	rim.Color = Color3.fromRGB(30, 30, 34)
	rim.Material = Enum.Material.SmoothPlastic
	rim.CanCollide, rim.CanQuery, rim.CanTouch, rim.Massless, rim.CastShadow = false, false, false, true, false
	rim.CollisionGroup = CAR_GROUP
	rim.CFrame = wheelBase
	rim.Parent = model
	local wheelWeld = weld(body, rim, body.CFrame:ToObjectSpace(wheelBase))
	wheelWeld.Name = "WheelWeld"
	local cap = Instance.new("Part")
	cap.Name = "SteeringHub"
	cap.Shape = Enum.PartType.Cylinder
	cap.Size = Vector3.new(0.22, ws * 0.35, ws * 0.35)
	cap.Color = Color3.fromRGB(230, 60, 60)
	cap.Material = Enum.Material.SmoothPlastic
	cap.CanCollide, cap.CanQuery, cap.CanTouch, cap.Massless, cap.CastShadow = false, false, false, true, false
	cap.CollisionGroup = CAR_GROUP
	cap.CFrame = wheelBase * CFrame.new(0.05, 0, 0)
	cap.Parent = model
	weld(rim, cap, CFrame.new(0.05, 0, 0))
	local column = Instance.new("Part")
	column.Name = "SteeringColumn"
	column.Size = Vector3.new(0.25, 0.25, 1.4)
	column.Color = Color3.fromRGB(40, 40, 44)
	column.Material = Enum.Material.Metal
	column.CanCollide, column.CanQuery, column.CanTouch, column.Massless, column.CastShadow = false, false, false, true, false
	column.CollisionGroup = CAR_GROUP
	-- (from the hub forward and down, away from the driver, along the wheel's axis)
	local axis = wheelBase.RightVector -- (towards the driver and up)
	column.CFrame = CFrame.lookAt(hub.Position, hub.Position - axis) * CFrame.new(0, 0, -0.75)
	column.Parent = model
	weld(body, column, body.CFrame:ToObjectSpace(column.CFrame))
	-- grips on the rim (left / right of the hub, a little up), turned with the wheel
	for _, side in ipairs({ { "GripL", -1 }, { "GripR", 1 } }) do
		local a = Instance.new("Attachment")
		a.Name = side[1]
		a.Position = Vector3.new(0, -ws * 0.18, side[2] * ws * 0.44) -- (the rim's -Y is "up" on the tipped wheel)
		a.Parent = rim
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "범퍼카 타기"
	prompt.ObjectText = "범퍼카"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	CollectionService:AddTag(root, BumperCarConfig.RootTag)

	-- the first one in takes the wheel (left); the second sits on the right
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		if humanoid.SeatPart == seat or humanoid.SeatPart == passengerSeat then return end
		local target = if not seat.Occupant then seat elseif not passengerSeat.Occupant then passengerSeat else nil
		if not target then return end
		if humanoid.SeatPart then humanoid.Sit = false end
		target:Sit(humanoid)
	end)

	local driver: Player? = nil
	local riders: {[Seat]: Model?} = {}
	local function refreshPrompt()
		prompt.Enabled = not (seat.Occupant and passengerSeat.Occupant)
	end
	passengerSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = passengerSeat.Occupant
		if humanoid then
			riders[passengerSeat] = humanoid.Parent :: Model
			setRider(riders[passengerSeat], true)
		else
			setRider(riders[passengerSeat], false)
			riders[passengerSeat] = nil
		end
		refreshPrompt()
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if humanoid then
			local rider = humanoid.Parent :: Model
			riders[seat] = rider
			driver = Players:GetPlayerFromCharacter(rider)
			setRider(rider, true)
			root:SetAttribute("Driver", if driver then driver.UserId else 0)
			-- (the seat weld first pulls the rider onto the seat while the car is still anchored;
			-- unanchored at once, the car was pulled to the rider instead)
			task.delay(0.2, function()
				if seat.Occupant ~= humanoid then return end
				root.Anchored = false
				if driver then pcall(function() root:SetNetworkOwner(driver) end) end
			end)
		else
			setRider(riders[seat], false)
			riders[seat], driver = nil, nil
			-- parked where it was left: flat on the floor, still
			local cf = root.CFrame
			local y = math.atan2(-cf.RightVector.Z, cf.RightVector.X)
			root.Anchored = true
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			root.CFrame = CFrame.new(cf.Position.X, hall.floorY + 0.5, cf.Position.Z) * CFrame.Angles(0, y, 0)
			root:SetAttribute("Driver", nil)
			-- the passenger moves over to the wheel
			local passenger = passengerSeat.Occupant
			if passenger then
				task.delay(0.3, function()
					if seat.Occupant or passengerSeat.Occupant ~= passenger then return end
					local weldR = passengerSeat:FindFirstChild("SeatWeld")
					if weldR then weldR:Destroy() end
					task.wait(0.1)
					if not seat.Occupant and passenger.Parent and passenger.Health > 0 then seat:Sit(passenger) end
				end)
			end
		end
		refreshPrompt()
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
