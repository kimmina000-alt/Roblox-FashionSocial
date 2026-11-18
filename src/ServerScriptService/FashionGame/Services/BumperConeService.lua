--!strict
-- 범퍼카장 원뿔 (D-1827, user 2026-11-19: "가운데 세우는 원뿔도 차에 치이면 퉁 소리 나면 나뒹굴게 하자 1 시간에
-- 한 번씩 자기 자리로 리스폰해 주고 넘어지면 넘어진 상태로 두기"). The traffic cones of the bumper car track
-- (tag BumperCone, tools/graybox/park_bumper_track_1119.lua):
--   * standing, a cone is anchored at its spot (attribute Home = that pivot, set the first time it is seen);
--   * a driver's car that hits one (BumperCarController sees the overlap and fires Remotes.BumperCone with the
--     car's speed) knocks it: "퉁" (a hollow plastic thud, everyone hears it from the cone), the cone is let
--     go and thrown with the car's speed, up a little and spinning, and tumbles on the floor (real physics;
--     the hitter's client runs it for a smooth look). Where it comes to rest it stays, lying as it fell
--     (anchored again once still, so it costs nothing); another hit knocks it on again;
--   * once an hour (on the server clock's hour) every cone stands up again at its own spot.
-- Cars never collide with the cones physically (the car group collides with nothing: BumperCarService);
-- players walking can push a loose one.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local BumperCarConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("BumperCarConfig"))
local Remote = FashionGame:WaitForChild("Remotes"):WaitForChild("BumperCone") :: RemoteEvent

local BumperConeService = {}

local TAG = "BumperCone"
local RESPAWN = 3600 -- seconds: every cone back on its spot once an hour
local REACH = 16 -- the car must be this near the cone (studs) for a hit to count
local COOLDOWN = 0.35 -- seconds between two hits on one cone

type Cone = { model: Model, home: CFrame, loose: boolean, lastHit: number, stillSince: number? }
local cones: {[Model]: Cone} = {}

local function parts(m: Model): {BasePart}
	local list = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(list, d) end
	end
	return list
end

-- one rigid body: every part welded to the biggest one (its PrimaryPart)
local function prepare(m: Model)
	local list = parts(m)
	if #list == 0 then return end
	local main = m.PrimaryPart
	if not main then
		for _, p in ipairs(list) do
			if not main or p.Size.Magnitude > main.Size.Magnitude then main = p end
		end
		m.PrimaryPart = main
	end
	for _, p in ipairs(list) do
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		-- (light plastic: tumbles far, bounces a little)
		p.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.55, 0.25, 1, 1)
		if p ~= main and not p:FindFirstChild("ConeWeld") then
			local w = Instance.new("WeldConstraint")
			w.Name = "ConeWeld"
			w.Part0, w.Part1 = main, p
			w.Parent = p
		end
	end
end

local function setAnchored(m: Model, on: boolean)
	for _, p in ipairs(parts(m)) do p.Anchored = on end
end

local function track(m: Instance)
	if not m:IsA("Model") or not m:IsDescendantOf(workspace) or cones[m] then return end
	local home = m:GetAttribute("Home")
	if typeof(home) ~= "CFrame" then
		home = m:GetPivot()
		m:SetAttribute("Home", home)
	end
	prepare(m)
	setAnchored(m, true)
	cones[m] = { model = m, home = home :: CFrame, loose = false, lastHit = 0, stillSince = nil }
end

local function thud(m: Model, speed: number)
	local at = m.PrimaryPart
	if not at then return end
	local s = Instance.new("Sound")
	s.Name = "ConeThud"
	s.SoundId = BumperCarConfig.BumpSoundId -- (the hollow plastic hit the cars use: "퉁")
	s.Volume = math.clamp(0.45 + speed / 30, 0.5, 1.2)
	s.PlaybackSpeed = 1.15 + math.random() * 0.2 -- (a lighter thing than a car: a little higher)
	s.RollOffMaxDistance = 90
	s.Parent = at
	s:Play()
	game:GetService("Debris"):AddItem(s, 3)
end

local function knock(player: Player, m: Model, carVel: Vector3)
	local cone = cones[m]
	local main = m.PrimaryPart
	if not cone or not main then return end
	local now = os.clock()
	if now - cone.lastHit < COOLDOWN then return end
	cone.lastHit = now
	local flatVel = Vector3.new(carVel.X, 0, carVel.Z)
	local speed = math.min(flatVel.Magnitude, BumperCarConfig.MaxSpeed + 10)
	if speed < 1.5 then return end -- (a touch, not a hit)
	thud(m, speed)
	setAnchored(m, false)
	cone.loose = true
	cone.stillSince = nil
	-- thrown on ahead of the car, a bit up, spinning over (axis across the way it flies) plus a twist
	local dir = flatVel.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local jitter = side * ((math.random() - 0.5) * 0.6 * speed)
	main.AssemblyLinearVelocity = flatVel * 1.15 + jitter + Vector3.new(0, 6 + speed * 0.25, 0)
	main.AssemblyAngularVelocity = side * -(4 + speed * 0.35) + Vector3.new(0, (math.random() - 0.5) * 8, 0)
	-- the hitter's client runs the tumble (smooth on the screen that caused it)
	pcall(function() main:SetNetworkOwner(player) end)
end

local function standUp(cone: Cone)
	local m = cone.model
	setAnchored(m, true)
	local main = m.PrimaryPart
	if main then
		main.AssemblyLinearVelocity = Vector3.zero
		main.AssemblyAngularVelocity = Vector3.zero
	end
	m:PivotTo(cone.home)
	cone.loose = false
	cone.stillSince = nil
end

local function driverCar(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "BumperSeat" then return nil end
	local model = seat.Parent
	local root = model and model:FindFirstChild("BumperRoot")
	return if root and root:IsA("BasePart") then root else nil
end

function BumperConeService.Start()
	for _, m in ipairs(CollectionService:GetTagged(TAG)) do track(m) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m) task.defer(track, m) end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
		if m:IsA("Model") then cones[m] = nil end
	end)

	Remote.OnServerEvent:Connect(function(player: Player, m: any, carVel: any)
		if typeof(m) ~= "Instance" or not m:IsA("Model") or typeof(carVel) ~= "Vector3" then return end
		if carVel.Magnitude ~= carVel.Magnitude then return end -- (nan)
		local car = driverCar(player)
		local cone = cones[m]
		if not car or not cone or not m.PrimaryPart then return end
		if (car.Position - m.PrimaryPart.Position).Magnitude > REACH then return end
		knock(player, m, carVel)
	end)

	-- a loose cone that has come to rest: anchored where it lies (lying as it fell); the hourly stand-up
	local hour = math.floor(os.time() / RESPAWN)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then return end
		acc = 0
		local now = os.clock()
		local h = math.floor(os.time() / RESPAWN)
		if h ~= hour then
			hour = h
			for _, cone in pairs(cones) do standUp(cone) end
			return
		end
		for m, cone in pairs(cones) do
			if not m.Parent then
				cones[m] = nil
			elseif cone.loose then
				local main = m.PrimaryPart
				local moving = main and not main.Anchored
					and (main.AssemblyLinearVelocity.Magnitude > 0.3 or main.AssemblyAngularVelocity.Magnitude > 0.3)
				if main and not main.Anchored and not moving then
					cone.stillSince = cone.stillSince or now
					if now - (cone.stillSince :: number) > 1.5 then setAnchored(m, true) end
				else
					cone.stillSince = nil
				end
				-- (fell out of the world somehow: back home now)
				if main and main.Position.Y < BumperCarConfig.Hall.floorY - 20 then standUp(cone) end
			end
		end
	end)
end

return BumperConeService
