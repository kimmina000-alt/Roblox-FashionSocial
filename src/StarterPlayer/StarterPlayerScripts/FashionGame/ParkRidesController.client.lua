--!strict
-- PARK rides on the client (ParkConfig, docs/02_WORLDS/PARK.md).
--
--   * Moves the rides from the shared clock: ferris wheel and carousel turn,
--     carousel horses bob, swings swing, spring riders rock (only near).
--   * Puts every rider (own and other players) on their seat each frame, so
--     riders stay exactly on the cabin / horse / swing everyone sees.
--   * Buttons at the bottom: 🎡 관람차 타기 (when a cabin is at the bottom),
--     목마 타기, 그네 타기, 흔들 그네 타기, 내리기, 👁 1인칭 (wheel), − / +
--     (swing speed 0..5). Keys (user, 2026-10-22): E = the main button
--     (타기 / 내리기), V = 1인칭 ↔ 3인칭. In first person the view button is
--     Modal, so the mouse is free to click it.
--   * Slide: walking onto the top of the slide slides you down; at the
--     bottom everyone sees a "야호!" bubble.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local ParkConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ParkConfig"))
local remote = Remotes:WaitForChild("ParkRide") :: RemoteFunction
local notify = Remotes:WaitForChild("ParkNotify") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DRAW_DISTANCE = 450

-- (D-1427, user 2026-11-15: "바이킹 타면 덜커덕거림 매끄럽게") the shared clock, smoothed: the
-- server time comes in steps; the local clock runs smoothly and only follows it slowly, so the rides
-- and their riders never jump between frames.
local clockOffset: number? = nil
local function now(): number
	local target = workspace:GetServerTimeNow() - os.clock()
	if clockOffset == nil or math.abs(target - clockOffset) > 0.5 then
		clockOffset = target
	else
		clockOffset = (clockOffset :: number) + (target - (clockOffset :: number)) * 0.01
	end
	return os.clock() + (clockOffset :: number)
end

local function ownRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function ownHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- (D-1156) small things (tubes, ducks, swings, spring riders) only within 160
-- studs: at 450 every tube and duck in the sea was moved every frame from
-- anywhere on the map; the Ferris wheel and the carousel (seen from afar) keep 450
local NEAR_DISTANCE = 160
local function cameraNear(position: Vector3, far: boolean?): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < (if far then DRAW_DISTANCE else NEAR_DISTANCE)
end

local function attrNumber(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

--------------------------------------------------
-- Ride registry
--------------------------------------------------

type Slot = { kind: string, ride: Model, slot: Instance, key: string, seat: (t: number) -> CFrame? }
local slots: {Slot} = {}
local wheels: {{ model: Model, rotor: Model?, rel: CFrame }} = {}
local carousels: {{ model: Model, rotor: Model?, rel: CFrame }} = {}
local swings: {{ model: Model, seat: Model?, amp: number, phase: number }} = {}
local springs: {{ model: Model, rocker: Model?, base: CFrame }} = {}
local slides: {Model} = {}
local vikings: {{ model: Model, swing: Model?, rel: CFrame }} = {} -- (D-1425)
local teacups: {{ model: Model, rotor: Model?, rel: CFrame, pot: Model?, potRel: CFrame }} = {} -- (D-1432)
local jumpstars: {{ model: Model, car: Model?, rel: CFrame }} = {} -- (D-1457)
local seatRides: {Model} = {} -- (vikings, tea cups, jumping star: seats picked, a shared run)
-- (D-1481) peace train: cars run along a closed track (the model's PathData = "x,y,z;…" rail-top points)
local trains: {{ model: Model, pts: {Vector3}, acc: {number}, length: number }} = {}

-- (D-1441, 2P test 2026-11-15: on Player2's screen the tea cups' parts stood up to 2 × their radius
-- from where the cups turned) Moving a Model with PivotTo while its parts are still streaming in
-- moves only the empty pivot; parts that arrive later come in at the server's resting place and keep
-- a wrong offset from then on. So every moving piece of a ride keeps, for each part, its offset from
-- the model's RESTING pivot (the server's, read the first time the model is moved, before this
-- client has touched it); a part that streams in later is at the server's resting place too, so its
-- offset is right. Each frame the parts go to cf * offset in one BulkMoveTo.
type Rig = { rest: CFrame, parts: {[BasePart]: CFrame} }
local rigs: {[Instance]: Rig} = {}
local function moveModel(model: Instance, cf: CFrame)
	local rig = rigs[model]
	if not rig then
		local rest = (model :: Model):GetPivot()
		local r: Rig = { rest = rest, parts = {} }
		local function add(d: Instance)
			-- (D-1463: a part marked OwnMove, the cabin doors, is moved by its own code)
			if d:IsA("BasePart") and not d:GetAttribute("OwnMove") then r.parts[d] = rest:ToObjectSpace(d.CFrame) end
		end
		for _, d in ipairs(model:GetDescendants()) do add(d) end
		model.DescendantAdded:Connect(add)
		model.DescendantRemoving:Connect(function(d: Instance)
			if d:IsA("BasePart") then r.parts[d] = nil end
		end)
		rigs[model] = r
		rig = r
	end
	local ps, cfs = {}, {}
	for part, offset in pairs((rig :: Rig).parts) do
		table.insert(ps, part)
		table.insert(cfs, cf * offset)
	end
	if #ps > 0 then workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

local function hubCFrame(model: Model, name: string): CFrame?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part.CFrame else nil
end

local function addWheel(model: Model)
	local hub = hubCFrame(model, "Hub")
	local rotor = model:FindFirstChild("Rotor") :: Model?
	if not hub then return end
	table.insert(wheels, { model = model, rotor = rotor, rel = if rotor then hub:Inverse() * rotor:GetPivot() else CFrame.new() })
	for index = 1, ParkConfig.cabinCount(model) do
		local cabin = model:FindFirstChild("Cabin" .. index)
		for seatIndex, seat in ipairs(ParkConfig.CabinSeats) do
			table.insert(slots, {
				kind = "ParkWheel", ride = model, slot = cabin :: Instance, key = "Rider" .. seatIndex,
				seat = function(t: number): CFrame?
					local cf = ParkConfig.cabinCFrame(model, index, t)
					return cf and cf * CFrame.lookAt(seat.offset, seat.offset + seat.facing)
				end,
			})
		end
	end
end

local ridesRunningNow: () -> boolean -- (set below, D-1420)
local function addCarousel(model: Model)
	local center = hubCFrame(model, "Center")
	local rotor = model:FindFirstChild("Rotor") :: Model?
	if not center then return end
	table.insert(carousels, { model = model, rotor = rotor, rel = if rotor then center:Inverse() * rotor:GetPivot() else CFrame.new() })
	for index = 1, ParkConfig.horseCount(model) do
		local horse = model:FindFirstChild("Horse" .. index) :: Instance
		table.insert(slots, {
			kind = "ParkCarousel", ride = model, slot = horse, key = "Rider",
			-- (D-1420) a stopped carousel (ParkConfig.RidesRunning) leaves its horses where they stand:
			-- the rider sits on the horse there, not where the turning clock would put it
			-- (D-1428, user: "회전목마 말에 조금 더 뒤쪽에 앉기 기둥에 안 겹치게") the rider sits SeatBack
			-- studs behind the pole (the horse's pivot is on the pole, LookVector = the way it rides)
			seat = function(t: number): CFrame?
				local back = CFrame.new(0, attrNumber(model, "SeatDrop", 0), attrNumber(model, "SeatBack", 1.5))
				if not ridesRunningNow() and horse and horse:IsA("Model") then return horse:GetPivot() * back end
				local cf = ParkConfig.horseCFrame(model, index, t)
				return cf and cf * back
			end,
		})
	end
end

local function addSwing(model: Model)
	local seatModel = model:FindFirstChild("SwingSeat") :: Model?
	local entry = { model = model, seat = seatModel, amp = 0, phase = 0 }
	table.insert(swings, entry)
	local length = attrNumber(model, "Length", 8)
	table.insert(slots, {
		kind = "ParkSwing", ride = model, slot = model, key = "Rider",
		seat = function(_t: number): CFrame?
			local pivot = if seatModel then seatModel:GetPivot() else nil
			return pivot and pivot * CFrame.new(0, -length + 0.15, 0)
		end,
	})
end

local function addSpring(model: Model)
	local rocker = model:FindFirstChild("Rocker") :: Model?
	table.insert(springs, { model = model, rocker = rocker, base = if rocker then rocker:GetPivot() else model:GetPivot() })
	local seatY = attrNumber(model, "SeatY", 1.6)
	table.insert(slots, {
		kind = "ParkSpring", ride = model, slot = model, key = "Rider",
		seat = function(_t: number): CFrame?
			return if rocker then rocker:GetPivot() * CFrame.new(0, seatY, 0) else nil
		end,
	})
end

-- (D-1425) Viking: the Swing model turns about the axle (the Ride's pivot); a rider per seat.
local addSeatPicks: ((Model) -> ())? = nil -- (D-1428, set below with the UI)
local function addViking(model: Model)
	local swing = model:FindFirstChild("Swing") :: Model?
	table.insert(vikings, { model = model, swing = swing, rel = if swing then model:GetPivot():Inverse() * swing:GetPivot() else CFrame.new() })
	table.insert(seatRides, model)
	for index = 1, ParkConfig.vikingSeatCount(model) do
		table.insert(slots, {
			kind = "ParkViking", ride = model, slot = model, key = "Rider" .. index,
			seat = function(t: number): CFrame?
				return ParkConfig.vikingSeatCFrame(model, index, t)
			end,
		})
	end
	task.spawn(function()
		while not addSeatPicks do task.wait(0.2) end -- (the UI part of this script sets it)
		local add = addSeatPicks
		if add then add(model) end
	end)
end

-- Floating tubes (rideable) and decorations on the sea (beach).
-- Each tube part is placed from where it sits in the server's pose (around
-- Base). Moving the model by its pivot went wrong on phones: the model
-- arrived before its parts (streaming), the pivot moved alone, and the ring
-- then floated up to Drift studs away from where the rider sat (user phone
-- test 2026-10-26).
type TubePart = { part: BasePart, offset: CFrame }
local floaters: {Model} = {}
local tubeParts: {[Model]: {TubePart}} = {}
local tubeShown: {[Model]: CFrame} = {} -- smoothed pose of tubes others paddle
local myTube: Model? = nil
local drivePos: Vector3? = nil
local driveYaw = 0

local function tubeCFrame(model: Model, t: number): CFrame?
	if model == myTube and drivePos then return ParkConfig.floatAt(model, t, drivePos, driveYaw) end
	return tubeShown[model] or ParkConfig.floatCFrame(model, t)
end

local function addTube(model: Model)
	local base = model:GetAttribute("Base")
	if typeof(base) ~= "Vector3" then return end
	local origin = CFrame.new(base)
	local list: {TubePart} = {}
	tubeParts[model] = list
	local function add(d: Instance)
		if d:IsA("BasePart") then table.insert(list, { part = d, offset = origin:ToObjectSpace(d.CFrame) }) end
	end
	for _, d in ipairs(model:GetDescendants()) do add(d) end
	model.DescendantAdded:Connect(add)
	model.DescendantRemoving:Connect(function(d)
		for i, entry in ipairs(list) do
			if entry.part == d then table.remove(list, i) break end
		end
	end)
	table.insert(floaters, model)
	table.insert(slots, {
		kind = "FloatTube", ride = model, slot = model, key = "Rider",
		-- sitting low in the middle of the ring
		seat = function(t: number): CFrame?
			local cf = tubeCFrame(model, t)
			return cf and cf * CFrame.new(0, -0.6, 0)
		end,
	})
end

local function register(tag: string, add: (Model) -> ())
	local function try(instance: Instance)
		if not instance:IsA("Model") then return end
		-- streaming: wait a moment for the parts
		task.delay(1, function()
			if instance.Parent then add(instance) end
		end)
	end
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do try(instance) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(try)
end
register("ParkWheel", addWheel)
register("ParkCarousel", addCarousel)
register("ParkSwing", addSwing)
register("ParkSpring", addSpring)
register("ParkSlide", function(model) table.insert(slides, model) end)
register("FloatTube", addTube)
-- (D-1591) a ring a player put on the water (TubeRentService) goes again when it is picked up: its slot
-- and its parts are forgotten
CollectionService:GetInstanceRemovedSignal("FloatTube"):Connect(function(model: Instance)
	for i = #slots, 1, -1 do
		if slots[i].ride == model then table.remove(slots, i) end
	end
	for i = #floaters, 1, -1 do
		if floaters[i] == model then table.remove(floaters, i) end
	end
	if model:IsA("Model") then
		tubeParts[model] = nil
		tubeShown[model] = nil
	end
end)
register("ParkViking", addViking)
register("ParkTrain", function(model: Model)
	local data = model:GetAttribute("PathData")
	if typeof(data) ~= "string" then return end
	local pts: {Vector3} = {}
	for x, y, z in data:gmatch("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number))
	end
	if #pts < 3 then return end
	table.insert(pts, pts[1]) -- (closed)
	local acc, total = { 0 }, 0
	for k = 2, #pts do
		total += (pts[k] - pts[k - 1]).Magnitude
		acc[k] = total
	end
	table.insert(trains, { model = model, pts = pts, acc = acc, length = total })
end)
-- the point s studs along a train's track (wraps)
local function trainAt(tr: { pts: {Vector3}, acc: {number}, length: number }, s: number): Vector3
	s %= tr.length
	local lo, hi = 1, #tr.acc
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if tr.acc[mid] <= s then lo = mid else hi = mid end
	end
	local span = tr.acc[hi] - tr.acc[lo]
	return tr.pts[lo]:Lerp(tr.pts[hi], if span > 0 then (s - tr.acc[lo]) / span else 0)
end
-- (D-1432) Tea cups: the Rotor turns with the table, each Cup<k> turns with it and spins itself.
register("ParkTeaCups", function(model: Model)
	local rotor = model:FindFirstChild("Rotor") :: Model?
	-- (D-1474) the middle piece turns slowly on its own, all the time (the ride's PotPeriod, seconds a turn)
	local pot = model:FindFirstChild("Teapot") :: Model?
	table.insert(teacups, {
		model = model,
		rotor = rotor,
		rel = if rotor then model:GetPivot():Inverse() * rotor:GetPivot() else CFrame.new(),
		pot = pot,
		potRel = if pot then model:GetPivot():Inverse() * pot:GetPivot() else CFrame.new(),
	})
	table.insert(seatRides, model)
	for index = 1, ParkConfig.rideSeatCount(model) do
		table.insert(slots, {
			kind = "ParkTeaCups", ride = model, slot = model, key = "Rider" .. index,
			seat = function(t: number): CFrame?
				return ParkConfig.teacupSeatCFrame(model, index, t)
			end,
		})
	end
	task.spawn(function()
		while not addSeatPicks do task.wait(0.2) end
		local add = addSeatPicks
		if add then add(model) end
	end)
end)

-- (D-1457) Jumping star: the Car goes up and down the tower; a rider per seat.
register("ParkJumpStar", function(model: Model)
	local car = model:FindFirstChild("Car") :: Model?
	table.insert(jumpstars, { model = model, car = car, rel = if car then model:GetPivot():Inverse() * car:GetPivot() else CFrame.new() })
	table.insert(seatRides, model)
	for index = 1, ParkConfig.rideSeatCount(model) do
		table.insert(slots, {
			kind = "ParkJumpStar", ride = model, slot = model, key = "Rider" .. index,
			seat = function(t: number): CFrame?
				return ParkConfig.jumpStarSeatCFrame(model, index, t)
			end,
		})
	end
	task.spawn(function()
		while not addSeatPicks do task.wait(0.2) end
		local add = addSeatPicks
		if add then add(model) end
	end)
end)

-- Rubber ducks (tag "FloatDeco", user 2026-10-25): they sit on the real water
-- surface, ride the waves along their drift path and get pushed by anyone
-- swimming or walking into them. Each client moves its own copy from the
-- characters it sees, so everyone sees about the same thing (no network).
type Duck = { model: Model, waterY: number?, pos: Vector3, vel: Vector3, yaw: number, probeAt: number, inWater: boolean }
local ducks: {Duck} = {}
local DUCK_PUSH_RADIUS = 2.4
local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include
waterParams.FilterDescendantsInstances = { workspace.Terrain }
waterParams.IgnoreWater = false

-- top of the sea at (x, z), or nil when there is no water there
local function waterAt(x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), waterParams)
	return if hit and hit.Material == Enum.Material.Water then hit.Position.Y else nil
end

local function addDuck(model: Model)
	local base = model:GetAttribute("Base")
	if typeof(base) ~= "Vector3" then return end
	-- the pivot goes right under the duck itself (a tiny resized union can sit
	-- a few studs off the model's pivot, and rocking would swing it up and down)
	local body = model:FindFirstChildWhichIsA("BasePart")
	if body then
		local p = body.Position
		model.WorldPivot = CFrame.new(p.X, p.Y - body.Size.Y * 0.35, p.Z)
	end
	local start = ParkConfig.floatCFrame(model, now())
	local pos = if start then start.Position else base
	table.insert(ducks, {
		model = model, waterY = waterAt(base.X, base.Z), -- nil until the sea has streamed in
		pos = Vector3.new(pos.X, 0, pos.Z), vel = Vector3.zero, yaw = 0, probeAt = 0, inWater = true,
	})
end
register("FloatDeco", addDuck)

local function moveDucks(t: number, dt: number)
	local roots = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then table.insert(roots, root) end
	end
	for _, duck in ipairs(ducks) do
		local model = duck.model
		if not model.Parent or not cameraNear(duck.pos) then continue end
		local waterY = duck.waterY
		if not waterY then
			if t < duck.probeAt then continue end
			duck.probeAt = t + 1
			local base = model:GetAttribute("Base") :: Vector3
			waterY = waterAt(base.X, base.Z)
			if not waterY then continue end
			duck.waterY = waterY
		end
		-- the waves pull it gently along its drift path
		local path = ParkConfig.floatCFrame(model, t)
		if path then
			local toPath = Vector3.new(path.Position.X - duck.pos.X, 0, path.Position.Z - duck.pos.Z)
			duck.vel += toPath * (0.08 * dt)
		end
		-- pushed by bodies (swimming or wading) that touch it
		for _, root in ipairs(roots) do
			local away = Vector3.new(duck.pos.X - root.Position.X, 0, duck.pos.Z - root.Position.Z)
			local dist = away.Magnitude
			if dist < DUCK_PUSH_RADIUS and math.abs(root.Position.Y - waterY) < 4 then
				local dir = if dist > 0.05 then away / dist else Vector3.new(1, 0, 0)
				local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
				-- out of the body, then carried along with a little of its speed
				duck.pos = Vector3.new(root.Position.X, 0, root.Position.Z) + dir * DUCK_PUSH_RADIUS
				local push = math.max(moving:Dot(dir), 0) * 0.9 + 1.5
				if duck.vel:Dot(dir) < push then duck.vel += dir * (push - duck.vel:Dot(dir)) end
			end
		end
		duck.vel *= math.exp(-0.7 * dt)
		local nextPos = duck.pos + duck.vel * dt
		-- stay on the sea: check the water a few times a second, bounce back off the sand
		if t >= duck.probeAt then
			duck.probeAt = t + 0.25
			duck.inWater = waterAt(nextPos.X, nextPos.Z) ~= nil
		end
		if duck.inWater then
			duck.pos = nextPos
		else
			local base = model:GetAttribute("Base") :: Vector3
			local back = Vector3.new(base.X - duck.pos.X, 0, base.Z - duck.pos.Z)
			duck.vel = if back.Magnitude > 0.1 then back.Unit * 2 else Vector3.zero
			duck.inWater = true
			duck.probeAt = t + 0.25
		end
		-- turn slowly to face where it floats
		local flat = Vector3.new(duck.vel.X, 0, duck.vel.Z)
		if flat.Magnitude > 0.3 then
			local target = math.atan2(-flat.X, -flat.Z)
			local diff = (target - duck.yaw + math.pi) % (2 * math.pi) - math.pi
			duck.yaw += diff * math.min(1, dt * 3)
		end
		local phase = attrNumber(model, "Phase", 0)
		local bob = 0.06 * math.sin((t % 1000) * 1.8 + phase * 3)
		local rock = math.rad(6) * math.sin((t % 1000) * 1.3 + phase)
		model:PivotTo(CFrame.new(duck.pos.X, waterY + bob, duck.pos.Z) * CFrame.Angles(0, duck.yaw, 0) * CFrame.Angles(rock, 0, rock * 0.5))
	end
end

--------------------------------------------------
-- Ride motion
--------------------------------------------------

-- (D-831, user) the Ferris wheel and the carousel can be stopped (ParkConfig.RidesRunning,
-- or live with the attribute ParkRidesRunning on ReplicatedStorage.FashionGame)
local function ridesRunning(kind: string?): boolean
	return ParkConfig.isRunning(kind or "ParkWheel") -- (D-1420: the carousel on its own switch)
end
ridesRunningNow = function() return ridesRunning("ParkCarousel") end

local function animate(t: number, dt: number)
	local running = ridesRunning()
	for _, wheel in ipairs(running and wheels or {}) do
		local hub = hubCFrame(wheel.model, "Hub")
		if hub and cameraNear(hub.Position, true) then
			if wheel.rotor then
				moveModel(wheel.rotor, hub * CFrame.Angles(ParkConfig.wheelAngle(wheel.model, t), 0, 0) * wheel.rel)
			end
			for index = 1, ParkConfig.cabinCount(wheel.model) do
				local cabin = wheel.model:FindFirstChild("Cabin" .. index)
				local cf = ParkConfig.cabinCFrame(wheel.model, index, t)
				if cabin and cabin:IsA("Model") and cf then
					moveModel(cabin, cf)
					-- (D-1463, user: "바닥에 닿을 때 문 열리게 하고 공중에 뜨면서 닫히게") the door swings open
					-- on its hinge near the bottom (the boarding window) and shuts as the cabin rises
					local door = cabin:FindFirstChild("CabinDoor")
					local hinge, rel = door and door:GetAttribute("HingeRel"), door and door:GetAttribute("DoorRel")
					if door and door:IsA("BasePart") and typeof(hinge) == "CFrame" and typeof(rel) == "CFrame" then
						local gap = ParkConfig.cabinFromBottom(wheel.model, index, t)
						local b = ParkConfig.WheelBoardAngle
						local f = math.clamp((b * 2 - gap) / b, 0, 1) -- (open within b, shut past 2b)
						f = f * f * (3 - 2 * f)
						local yaw = (door:GetAttribute("OpenYaw") :: number?) or 1.6
						door.CFrame = cf * hinge * CFrame.Angles(0, yaw * f, 0) * rel
					end
				end
			end
		end
	end
	for _, carousel in ipairs(ridesRunning("ParkCarousel") and carousels or {}) do
		local center = hubCFrame(carousel.model, "Center")
		if center and cameraNear(center.Position, true) then
			if carousel.rotor then
				moveModel(carousel.rotor, center * CFrame.Angles(0, ParkConfig.carouselAngle(carousel.model, t), 0) * carousel.rel)
			end
			for index = 1, ParkConfig.horseCount(carousel.model) do
				local horse = carousel.model:FindFirstChild("Horse" .. index)
				local cf = ParkConfig.horseCFrame(carousel.model, index, t)
				if horse and horse:IsA("Model") and cf then moveModel(horse, cf) end
			end
		end
	end
	for _, viking in ipairs(vikings) do
		local pivot = viking.model:GetPivot()
		if viking.swing and viking.model.Parent and cameraNear(pivot.Position, true) then
			moveModel(viking.swing, pivot * ParkConfig.vikingTurn(viking.model, t) * viking.rel)
		end
	end
	for _, tr in ipairs(ridesRunning("ParkTrain") and trains or {}) do
		local model = tr.model
		if model.Parent and cameraNear(model:GetPivot().Position, true) then
			local period = attrNumber(model, "Period", 40)
			local gap = attrNumber(model, "CarGap", 4.6)
			local head = (t / period % 1) * tr.length
			for index = 1, 12 do
				local car = model:FindFirstChild("Car" .. index)
				if not car then break end
				if car:IsA("Model") then
					local s = head - (index - 1) * gap
					local front, back = trainAt(tr, s + 1.4), trainAt(tr, s - 1.4)
					local mid = trainAt(tr, s)
					moveModel(car, CFrame.lookAt(mid, mid + (front - back)))
				end
			end
		end
	end
	for _, js in ipairs(jumpstars) do
		local pivot = js.model:GetPivot()
		if js.car and js.model.Parent and cameraNear(pivot.Position, true) then
			local h = ParkConfig.jumpStarState(js.model, t)
			moveModel(js.car, pivot * CFrame.new(0, h, 0) * js.rel)
		end
	end
	for _, tc in ipairs(teacups) do
		local pivot = tc.model:GetPivot()
		if tc.model.Parent and cameraNear(pivot.Position, true) then
			local turn = ParkConfig.teacupState(tc.model, t)
			if tc.rotor then moveModel(tc.rotor, pivot * CFrame.Angles(0, turn, 0) * tc.rel) end
			local potPeriod = tc.model:GetAttribute("PotPeriod")
			if tc.pot and tc.pot.Parent and type(potPeriod) == "number" and potPeriod > 0 then
				moveModel(tc.pot, pivot * CFrame.Angles(0, ((t / potPeriod) % 1) * 2 * math.pi, 0) * tc.potRel)
			end
			for cup = 1, ParkConfig.teacupCount(tc.model) do
				local m = tc.model:FindFirstChild("Cup" .. cup)
				local cf = ParkConfig.teacupCFrame(tc.model, cup, t)
				if m and m:IsA("Model") and cf then moveModel(m, cf) end
			end
		end
	end
	for _, swing in ipairs(swings) do
		local pivot = hubCFrame(swing.model, "Pivot")
		if pivot and swing.seat and cameraNear(pivot.Position) then
			local level = if swing.model:GetAttribute("Rider") then attrNumber(swing.model, "Level", 0) else 0
			local target = math.rad(level * ParkConfig.SwingDegreesPerLevel)
			-- speed changes ease in over a few swings (no jolts)
			swing.amp += (target - swing.amp) * math.min(1, dt * 0.6)
			swing.phase = (swing.phase + dt * 2 * math.pi / ParkConfig.SwingPeriod) % (2 * math.pi)
			moveModel(swing.seat, pivot * CFrame.Angles(swing.amp * math.sin(swing.phase), 0, 0))
		end
	end
	for _, model in ipairs(floaters) do
		if not model.Parent then continue end
		local cf: CFrame?
		if model == myTube and drivePos then
			cf = tubeCFrame(model, t)
		else
			-- a tube someone paddles is sent ~10 times a second: glide to it
			local target = ParkConfig.floatCFrame(model, t)
			local shown = tubeShown[model]
			if target and shown and (shown.Position - target.Position).Magnitude < 25 then
				target = shown:Lerp(target, math.min(1, dt * 10))
			end
			tubeShown[model] = target
			cf = target
		end
		local list = tubeParts[model]
		if cf and list and cameraNear(cf.Position) then
			local parts, cframes = {}, {}
			for _, entry in ipairs(list) do
				table.insert(parts, entry.part)
				table.insert(cframes, cf * entry.offset)
			end
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	moveDucks(t, dt)
	for _, spring in ipairs(springs) do
		if spring.rocker and cameraNear(spring.base.Position) then
			local angle = 0
			if spring.model:GetAttribute("Rider") then
				angle = ParkConfig.SpringAngle * math.sin(t * 2 * math.pi / ParkConfig.SpringPeriod)
			end
			moveModel(spring.rocker, spring.base * CFrame.Angles(angle, 0, 0))
		end
	end
end

--------------------------------------------------
-- Riders
--------------------------------------------------

local mySlot: Slot? = nil
local boardedAt = 0
local slideCFrame: CFrame? = nil

local function liftFor(root: BasePart): number
	return root.Size.Y / 2 + 0.35
end

local function riderCFrame(entry: Slot, root: BasePart, t: number): CFrame?
	local seat = entry.seat(t)
	return seat and seat * CFrame.new(0, liftFor(root), 0)
end

local function placeOwn(cf: CFrame)
	local root = ownRoot()
	if not root then return end
	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local humanoid = ownHumanoid()
	if humanoid and not humanoid.Sit then humanoid.Sit = true end
end

local function placeRiders(t: number)
	for _, entry in ipairs(slots) do
		local userId = entry.slot:GetAttribute(entry.key)
		if typeof(userId) == "number" then
			local rider = Players:GetPlayerByUserId(userId)
			local character = rider and rider.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (rider == player or cameraNear(root.Position)) then
				local cf = riderCFrame(entry, root, t)
				if cf then
					if rider == player then placeOwn(cf) else root.CFrame = cf end
				end
			end
		end
	end
end

-- Paddling a tube: the move stick / WASD push it over the sea (never onto
-- the sand); the server hears where it is 10 times a second. (A seated
-- humanoid still gets MoveDirection from the controls, in world space.)
local driveSentAt = 0
local lastSent: Vector3? = nil
local tubeBump = Vector3.zero

-- swimming strokes while the tube moves (user 2026-10-27; docs/04_ART/SOUNDS.md)
local paddleSound = Instance.new("Sound")
paddleSound.Name = "TubePaddle"
paddleSound.SoundId = "rbxassetid://106239090346339" -- "swimminglp" (Creator Store)
paddleSound.Looped = true
paddleSound.Volume = 0.6
paddleSound.Parent = game:GetService("SoundService")

local function paddle(dt: number)
	local tube = myTube
	local pos = drivePos
	local humanoid = ownHumanoid()
	local moving = tube ~= nil and pos ~= nil and humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
	if moving and not paddleSound.IsPlaying then paddleSound:Play()
	elseif not moving and paddleSound.IsPlaying then paddleSound:Stop() end
	if not tube or not pos or not humanoid then return end
	local move = humanoid.MoveDirection
	if move.Magnitude > 0.05 then
		local dir = Vector3.new(move.X, 0, move.Z)
		if dir.Magnitude > 1 then dir = dir.Unit end
		local nextPos = pos + dir * (ParkConfig.TubeSpeed * dt)
		if waterAt(nextPos.X, nextPos.Z) then drivePos = Vector3.new(nextPos.X, pos.Y, nextPos.Z) end
		-- turn to face where it goes
		local target = math.atan2(-dir.X, -dir.Z)
		local diff = (target - driveYaw + math.pi) % (2 * math.pi) - math.pi
		driveYaw += diff * math.min(1, dt * 4)
	end
	-- bumping another tube (user 2026-10-30): pushed off, slowing down
	do
		local p = drivePos :: Vector3
		for _, other in ipairs(CollectionService:GetTagged("FloatTube")) do
			if other ~= tube and other:IsDescendantOf(workspace) then
				local cf = ParkConfig.floatCFrame(other, now())
				if cf then
					local d = Vector3.new(p.X - cf.X, 0, p.Z - cf.Z)
					if d.Magnitude < ParkConfig.TubeTouch and d.Magnitude > 0.01 and tubeBump:Dot(d) <= 0 then
						tubeBump = d.Unit * ParkConfig.BumpSpeed
					end
				end
			end
		end
		if tubeBump.Magnitude > 0.05 then
			local nextPos = p + tubeBump * dt
			if waterAt(nextPos.X, nextPos.Z) then drivePos = Vector3.new(nextPos.X, p.Y, nextPos.Z) else tubeBump = Vector3.zero end
			tubeBump *= math.exp(-ParkConfig.BumpDrag * dt)
		end
	end
	local current = drivePos :: Vector3
	if os.clock() - driveSentAt > 0.1 and (lastSent == nil or (lastSent - current).Magnitude > 0.05) then
		driveSentAt = os.clock()
		lastSent = current
		notify:FireServer("TubeDrive", current, driveYaw)
	end
end

RunService.PreSimulation:Connect(function(dt)
	paddle(dt)
	if slideCFrame then
		placeOwn(slideCFrame)
		return
	end
	local entry = mySlot
	local root = ownRoot()
	if entry and root then
		-- in the water the swimming body drifted out of the ring between frames
		-- (it showed the rider beside the tube, user phone test 2026-10-26):
		-- on a tube the rider is held anchored at the seat
		-- (D-1427) on a viking too: the body falling a little between frames made the ride judder
		if (entry.kind == "FloatTube" or ParkConfig.isSeatRide(entry.kind)) and not root.Anchored then root.Anchored = true end
		local cf = riderCFrame(entry, root, now())
		if cf then placeOwn(cf) end
	end
end)

--------------------------------------------------
-- UI
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ParkRideGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = playerGui

-- Key hints only with a keyboard; phones show plain buttons, placed low
-- between the thumbstick and the jump button (user mobile test 2026-10-22).
local KEY = if UserInputService.KeyboardEnabled then "[E] " else ""
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = if TOUCH then UDim2.new(0.5, 0, 1, -24) else UDim2.new(0.5, 0, 1, -110)
bar.Size = UDim2.fromOffset(0, 48)
bar.AutomaticSize = Enum.AutomaticSize.X
bar.BackgroundTransparency = 1
bar.Visible = false
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

local function button(name: string, order: number, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(width, 46)
	b.BackgroundColor3 = Color3.fromRGB(255, 110, 170)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 17
	b.AutoButtonColor = true
	b.Visible = false
	b.Parent = bar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 23)
	corner.Parent = b
	return b
end
local minusButton = button("Minus", 1, 46)
local levelLabel = button("Level", 2, 110)
levelLabel.AutoButtonColor = false
levelLabel.BackgroundColor3 = Color3.fromRGB(40, 36, 52)
local plusButton = button("Plus", 3, 46)
local mainButton = button("Main", 4, 240)
local viewButton = button("View", 5, 140)
viewButton.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
minusButton.Text = "−"
minusButton.TextSize = 26
plusButton.Text = "+"
plusButton.TextSize = 24

-- (D-1546, user 2026-11-16: "파란 줄에 화면을 마구 클릭해 보세요! 넣기. 흰색 폰트에 검은색 그림자") over the
-- button bar while a tea cup can be spun by tapping (updateSpinTap)
local tapHint = Instance.new("TextLabel")
tapHint.Name = "TapHint"
tapHint.AnchorPoint = Vector2.new(0.5, 1)
tapHint.Position = if TOUCH then UDim2.new(0.5, 0, 1, -24 - 48 - 6) else UDim2.new(0.5, 0, 1, -110 - 48 - 6)
tapHint.Size = UDim2.fromOffset(420, 30)
tapHint.BackgroundTransparency = 1
tapHint.Text = "화면을 마구 클릭해 보세요!"
tapHint.TextColor3 = Color3.new(1, 1, 1)
tapHint.Font = Enum.Font.GothamBlack
tapHint.TextSize = 22
tapHint.TextStrokeColor3 = Color3.new(0, 0, 0)
tapHint.TextStrokeTransparency = 0.2
tapHint.Visible = false
tapHint.Parent = gui
local tapShadow = Instance.new("UIStroke")
tapShadow.Color = Color3.new(0, 0, 0)
tapShadow.Thickness = 2
tapShadow.Transparency = 0.15
tapShadow.Parent = tapHint

local toastLabel = Instance.new("TextLabel")
toastLabel.AnchorPoint = Vector2.new(0.5, 1)
toastLabel.Position = UDim2.new(0.5, 0, 1, -168)
toastLabel.Size = UDim2.fromOffset(380, 36)
toastLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toastLabel.BackgroundTransparency = 0.3
toastLabel.TextColor3 = Color3.new(1, 1, 1)
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextSize = 15
toastLabel.TextWrapped = true
toastLabel.Visible = false
toastLabel.Parent = gui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = toastLabel
end
local toastToken = 0
local function toast(message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(2.8, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

local firstPerson = false
-- (D-1595, user 2026-11-17 with a first-person screenshot: "관람차 공중에 떠 있어서 비현실적이야 / 안 보이게
-- 감춘 거 다 삭제해") the code that hid the wheel's frame in first person (D-1520 / D-1546 / D-1590) is
-- gone: the cabins hang on a whole wheel again
local function setFirstPerson(on: boolean)
	firstPerson = on
	player.CameraMode = if on then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	-- Modal frees the mouse in first person, so 🎥 3인칭 can be clicked
	-- (user report: stuck in first person with the mouse locked).
	viewButton.Modal = on
	if not on then
		-- Classic alone keeps the camera zoomed in at the head (user report:
		-- V switched to first person but not back): push it out, then free it.
		player.CameraMinZoomDistance = 12
		task.delay(0.1, function()
			if not firstPerson then player.CameraMinZoomDistance = 0.5 end
		end)
	end
end

local function setJump(enabled: boolean)
	local humanoid = ownHumanoid()
	if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end
end

local function stopRiding(exit: CFrame?)
	mySlot = nil
	myTube = nil
	drivePos = nil
	lastSent = nil
	if firstPerson then setFirstPerson(false) end
	local humanoid = ownHumanoid()
	local root = ownRoot()
	if root and root.Anchored then root.Anchored = false end -- (tubes hold the rider anchored)
	if humanoid then humanoid.Sit = false end
	setJump(true)
	if root and exit then
		root.CFrame = exit
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- What the main button would do right now (not riding).
type Offer = { text: string, ride: Model?, slot: Instance?, ready: boolean }
local function currentOffer(t: number): Offer?
	local root = ownRoot()
	if not root then return nil end
	local position = root.Position
	for _, wheel in ipairs(wheels) do
		local boardPoint = wheel.model:FindFirstChild("BoardPoint")
		if boardPoint and boardPoint:IsA("BasePart") and (boardPoint.Position - position).Magnitude <= ParkConfig.BoardDistance then
			local index, wait = ParkConfig.cabinAtBottom(wheel.model, t)
			if index then return { text = "🎡 관람차 타기", ride = wheel.model, slot = nil, ready = true } end
			return { text = string.format("🎡 다음 칸까지 %d초", math.ceil(wait)), ride = nil, slot = nil, ready = false }
		end
	end
	for _, ride in ipairs(seatRides) do -- (D-1425 / D-1432) one button per viking / tea cups
		local pivot = ride:GetPivot()
		local reach = attrNumber(ride, "Reach", 20)
		if Vector3.new(position.X - pivot.X, 0, position.Z - pivot.Z).Magnitude <= reach and math.abs(position.Y - pivot.Y) <= 60 then
			local kind = ParkConfig.seatRideKind(ride) or "ParkViking"
			local icon, label = ParkConfig.SeatRideIcons[kind] or "⛵", ParkConfig.SeatRideNames[kind] or "바이킹"
			local still, left = ParkConfig.rideState(ride, t)
			if not still then
				return { text = string.format("%s 운행 중 · %d초 뒤 탑승", icon, math.ceil(left)), ride = nil, slot = nil, ready = false }
			end
			local free = false
			for index = 1, ParkConfig.rideSeatCount(ride) do
				if ride:GetAttribute("Rider" .. index) == nil then free = true break end
			end
			if free then
				return { text = string.format("%s %s 타기 (%d초 뒤 출발)", icon, label, math.ceil(left)), ride = ride, slot = nil, ready = true }
			end
			return { text = icon .. " 자리가 가득 찼어요", ride = nil, slot = nil, ready = false }
		end
	end
	local best: Offer? = nil
	local bestDistance = math.huge
	local function consider(entry: Slot, text: string, reach: number)
		if entry.slot:GetAttribute(entry.key) ~= nil then return end
		local seat = entry.seat(t)
		if not seat then return end
		local distance = (Vector3.new(seat.X, 0, seat.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
		if distance <= reach and distance < bestDistance then
			bestDistance = distance
			best = { text = text, ride = entry.ride, slot = entry.slot, ready = true }
		end
	end
	for _, entry in ipairs(slots) do
		-- (D-1477: a ride built on the carousel's code, the fire trucks, names itself: attribute RideText)
		if entry.kind == "ParkCarousel" then consider(entry, entry.ride:GetAttribute("RideText") or "🎠 목마 타기", 5)
		elseif entry.kind == "ParkSwing" then consider(entry, "그네 타기", 4.5)
		elseif entry.kind == "ParkSpring" then consider(entry, "흔들 그네 타기", 4.5)
		elseif entry.kind == "FloatTube" then consider(entry, "튜브 타기", 6) end
	end
	return best
end

local busy = false
local offer: Offer? = nil

local function pressMain()
	if busy then return end
	busy = true
	if mySlot then
		local ok, result = remote:InvokeServer("Leave")
		if ok then stopRiding(if typeof(result) == "CFrame" then result else nil)
		elseif typeof(result) == "string" then toast(result) end
	elseif offer and offer.ready and offer.ride then
		local ok, result = remote:InvokeServer("Board", offer.ride, offer.slot)
		if ok and typeof(result) == "table" then
			for _, entry in ipairs(slots) do
				if entry.slot == result.slot and entry.key == result.key then mySlot = entry boardedAt = os.clock() end
			end
			local ride = offer.ride
			if mySlot and mySlot.kind == "FloatTube" and ride then
				-- from here on this client moves the tube
				local cf = tubeCFrame(ride, now())
				if cf then
					myTube = ride
					drivePos = Vector3.new(cf.X, (ride:GetAttribute("Base") :: Vector3).Y, cf.Z)
					local look = cf.LookVector
					driveYaw = math.atan2(-look.X, -look.Z)
				end
			end
			setJump(false)
		elseif typeof(result) == "string" then
			toast(result)
		end
	end
	busy = false
end

-- (D-1591) TubeCarryController: walking into the sea with the beach ring put it on the water; get in it
local boardTube = Instance.new("BindableEvent")
boardTube.Name = "ParkBoardTube"
boardTube.Parent = script
boardTube.Event:Connect(function(model: Instance)
	if mySlot or not model:IsA("Model") then return end
	-- (its slot is made a moment after the tag shows up: register's delay)
	for _ = 1, 30 do
		for _, entry in ipairs(slots) do
			if entry.ride == model then
				offer = { text = "", ride = model, slot = model, ready = true }
				pressMain()
				return
			end
		end
		task.wait(0.1)
	end
end)
mainButton.MouseButton1Click:Connect(pressMain)

-- (D-1428, user 2026-11-15: "바이킹 비어 있는 자리 클릭하면 자리 선택해서 앉을 수 있게"; D-1430:
-- "플러스 모양 그냥 없애 그냥 누르면 앉게 해") while a viking stands still and you are near it, every
-- free seat is an invisible button over the seat itself: a click or tap there seats you on it, or,
-- already on that boat, moves you to it. The main button still takes the first free seat.
type SeatPick = { ride: Model, index: number, gui: BillboardGui, anchor: Attachment }
local seatPicks: {SeatPick} = {}
local pickFolder = Instance.new("Folder")
pickFolder.Name = "VikingSeatPicks"
pickFolder.Parent = playerGui
local pickHolder = Instance.new("Part")
pickHolder.Name = "VikingSeatPickAnchors"
pickHolder.Anchored = true
pickHolder.CanCollide = false
pickHolder.CanQuery = false
pickHolder.CanTouch = false
pickHolder.Transparency = 1
pickHolder.Size = Vector3.new(0.2, 0.2, 0.2)
pickHolder.CFrame = CFrame.new()
pickHolder.Parent = workspace

local function pickSeat(ride: Model, index: number)
	local current = mySlot
	if busy or (current and current.ride ~= ride) then return end
	busy = true
	local ok, result = remote:InvokeServer("Board", ride, index)
	if ok and typeof(result) == "table" then
		for _, entry in ipairs(slots) do
			if entry.slot == result.slot and entry.key == result.key then mySlot = entry boardedAt = os.clock() end
		end
		setJump(false)
	elseif typeof(result) == "string" then
		toast(result)
	end
	busy = false
end

addSeatPicks = function(model: Model)
	for index = 1, ParkConfig.rideSeatCount(model) do
		local anchor = Instance.new("Attachment")
		anchor.Name = model.Parent and model.Parent.Name .. index or tostring(index)
		anchor.Parent = pickHolder -- (placed over the seat while it shows, updateSeatPicks)
		local g = Instance.new("BillboardGui")
		g.Name = "Seat" .. index
		g.Size = UDim2.fromScale(3, 2.6) -- (studs: about one seat)
		g.AlwaysOnTop = false -- (AlwaysOnTop billboards were not drawn in the Studio test)
		g.Active = true
		g.MaxDistance = 80
		g.Adornee = anchor
		g.Enabled = false
		g.Parent = pickFolder
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromScale(1, 1)
		b.BackgroundTransparency = 1 -- (nothing drawn: the seat itself is what you press)
		b.Text = ""
		b.Parent = g
		b.Activated:Connect(function() task.spawn(pickSeat, model, index) end)
		table.insert(seatPicks, { ride = model, index = index, gui = g, anchor = anchor })
	end
end

-- (D-1442, user: "회전컵은 가운데 핸들 클릭하면 점점 더 빨라지고 클릭 안 하면 점점 느려지게") while a tea
-- cup runs, its rider taps to spin the cup faster; ParkConfig.teacupExtra / ParkRideService "Spin".
-- (D-1448, user: "핸들만 누르는 거 에임 어렵다 … 화면 자체를 광클하는 걸로") any tap or click on the
-- screen counts (not on buttons or the thumbstick: those come in as processed); the label over
-- the wheel only says so.
local spinGui = Instance.new("BillboardGui")
spinGui.Name = "TeaCupWheelTap"
spinGui.Size = UDim2.fromScale(7, 1.4) -- (studs)
spinGui.StudsOffset = Vector3.new(0, 2.2, 0)
spinGui.AlwaysOnTop = false
spinGui.Active = false
spinGui.MaxDistance = 60
spinGui.Enabled = false
spinGui.Parent = pickFolder
local spinHint = Instance.new("TextLabel")
spinHint.Size = UDim2.fromScale(1, 1)
spinHint.BackgroundTransparency = 1
spinHint.Font = Enum.Font.GothamBold
spinHint.TextScaled = true
spinHint.TextColor3 = Color3.new(1, 1, 1)
spinHint.TextStrokeTransparency = 0.35
spinHint.Text = "화면 연타! 🔄"
-- (D-1477, user: "화면 연타 텍스트 삭제") the label is not shown; spinGui.Enabled still says when taps count
spinHint.Visible = false
spinHint.Parent = spinGui
local spinSending = false
local function spinTap()
	if spinSending or not spinGui.Enabled then return end
	spinSending = true
	spinHint.TextColor3 = Color3.fromRGB(255, 220, 90)
	task.spawn(function()
		remote:InvokeServer("Spin")
		spinSending = false
	end)
	task.delay(0.12, function() spinHint.TextColor3 = Color3.new(1, 1, 1) end)
end
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		spinTap()
	end
end)

-- (D-1565) a ferris wheel rider taps the other bench of their cabin (it is free): they move there
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or busy then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local entry = mySlot
	if not entry or entry.kind ~= "ParkWheel" then return end
	local cabin = entry.slot
	local other = if entry.key == "Rider1" then "Rider2" else "Rider1"
	if not cabin or not cabin.Parent or cabin:GetAttribute(other) ~= nil then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { cabin }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 60, params)
	if not hit then return end
	-- which bench the tap is on: the side of the cabin's middle (hub frame z) of the other seat
	local index = ParkConfig.cabinCount(entry.ride) > 0 and tonumber(string.match(cabin.Name, "%d+")) or nil
	local cf = index and ParkConfig.cabinCFrame(entry.ride, index, workspace:GetServerTimeNow())
	if not cf then return end
	local seatOffset = ParkConfig.CabinSeats[if other == "Rider1" then 1 else 2].offset
	local z = cf:PointToObjectSpace(hit.Position).Z
	if z * seatOffset.Z <= 0 then return end
	busy = true
	task.spawn(function()
		local ok, result = remote:InvokeServer("SwitchSeat")
		if ok and typeof(result) == "table" then
			for _, e in ipairs(slots) do
				if e.slot == result.slot and e.key == result.key then mySlot = e end
			end
		end
		busy = false
	end)
end)

local function updateSpinTap(t: number)
	local entry = mySlot
	local show = false
	if entry and entry.kind == "ParkTeaCups" and entry.ride and entry.ride.Parent then
		local _, _, still, left = ParkConfig.teacupState(entry.ride, t)
		if not still and left > ParkConfig.SpinStopGap then
			local seat = tonumber(string.match(entry.key, "%d+")) or 1
			local cup = entry.ride:FindFirstChild("Cup" .. math.ceil(seat / attrNumber(entry.ride, "SeatsPerCup", 4)))
			local wheel = cup and cup:FindFirstChild("Wheel")
			if wheel then
				spinGui.Adornee = wheel
				show = true
			end
		end
	end
	spinGui.Enabled = show
	tapHint.Visible = show -- (D-1546)
end

local function updateSeatPicks(t: number)
	updateSpinTap(t)
	local root = ownRoot()
	local stillRide: {[Model]: boolean} = {}
	for _, pick in ipairs(seatPicks) do
		local show = false
		local current = mySlot
		if root and (current == nil or ((ParkConfig.isSeatRide(current.kind)) and current.ride == pick.ride)) and pick.ride.Parent then
			local still = stillRide[pick.ride]
			if still == nil then
				local pivot = pick.ride:GetPivot()
				local reach = attrNumber(pick.ride, "Reach", 20)
				local near = Vector3.new(root.Position.X - pivot.X, 0, root.Position.Z - pivot.Z).Magnitude <= reach
					and math.abs(root.Position.Y - pivot.Y) <= 60
				local standing = ParkConfig.rideState(pick.ride, t)
				still = near and standing
				stillRide[pick.ride] = still
			end
			show = still and pick.ride:GetAttribute("Rider" .. pick.index) == nil
			if show then
				local seat = ParkConfig.seatRideSeatCFrame(pick.ride, pick.index, t)
				if seat then pick.anchor.WorldCFrame = seat * CFrame.new(0, 1.2, 0) else show = false end -- (over the seat pan)
			end
		end
		pick.gui.Enabled = show
	end
end

viewButton.MouseButton1Click:Connect(function()
	setFirstPerson(not firstPerson)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		if bar.Visible and mainButton.Visible then task.spawn(pressMain) end
	elseif input.KeyCode == Enum.KeyCode.V then
		if mySlot and (mySlot.kind == "ParkWheel" or ParkConfig.isSeatRide(mySlot.kind)) then setFirstPerson(not firstPerson) end
	end
end)

local function changeLevel(delta: number)
	if busy then return end
	busy = true
	remote:InvokeServer("Level", delta)
	busy = false
end
minusButton.MouseButton1Click:Connect(function() changeLevel(-1) end)
plusButton.MouseButton1Click:Connect(function() changeLevel(1) end)

local function refreshUi(t: number)
	updateSeatPicks(t)
	local entry = mySlot
	if entry then
		bar.Visible = true
		mainButton.Visible = true
		mainButton.Text = KEY .. "내리기"
		mainButton.BackgroundColor3 = Color3.fromRGB(255, 110, 170)
		if entry.kind == "ParkWheel" then
			local index = tonumber(string.match(entry.slot.Name, "^Cabin(%d+)$")) or 1
			local gap = ParkConfig.cabinFromBottom(entry.ride, index, t)
			if gap > ParkConfig.WheelBoardAngle * 1.6 then
				local speed = 2 * math.pi / attrNumber(entry.ride, "Period", 150)
				local a = ParkConfig.cabinAngle(entry.ride, index, t) % (2 * math.pi)
				local toBottom = (2 * math.pi - ParkConfig.WheelBoardAngle) - a
				if toBottom < 0 then toBottom += 2 * math.pi end
				mainButton.Text = string.format(KEY .. "내리기 (아래까지 %d초)", math.ceil(toBottom / speed))
				mainButton.BackgroundColor3 = Color3.fromRGB(120, 110, 130)
			end
		end
		if ParkConfig.isSeatRide(entry.kind) then -- (D-1425) off only while it stands still
			local still, left = ParkConfig.rideState(entry.ride, t)
			if not still then
				mainButton.Text = string.format(KEY .. "내리기 (멈추면 · %d초)", math.ceil(left))
				mainButton.BackgroundColor3 = Color3.fromRGB(120, 110, 130)
			end
		end
		viewButton.Visible = entry.kind == "ParkWheel" or ParkConfig.isSeatRide(entry.kind)
		viewButton.Text = if firstPerson then (if KEY ~= "" then "🎥 3인칭 (V)" else "🎥 3인칭") else (if KEY ~= "" then "👁 1인칭 (V)" else "👁 1인칭")
		local isSwing = entry.kind == "ParkSwing"
		minusButton.Visible = isSwing
		plusButton.Visible = isSwing
		levelLabel.Visible = isSwing
		if isSwing then
			levelLabel.Text = string.format("속도 %d/%d", attrNumber(entry.slot, "Level", 0), ParkConfig.SwingLevels)
		end
		return
	end
	viewButton.Visible = false
	minusButton.Visible = false
	plusButton.Visible = false
	levelLabel.Visible = false
	offer = if slideCFrame then nil else currentOffer(t)
	local current = offer
	if current then
		bar.Visible = true
		mainButton.Visible = true
		mainButton.Text = if current.ready then KEY .. current.text else current.text
		mainButton.BackgroundColor3 = if current.ready then Color3.fromRGB(255, 110, 170) else Color3.fromRGB(120, 110, 130)
	else
		bar.Visible = false
	end
end

--------------------------------------------------
-- Slide
--------------------------------------------------

local function inBox(box: BasePart, position: Vector3): boolean
	local p = box.CFrame:PointToObjectSpace(position)
	local half = box.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local slideCooldown = 0
local function slideDown(model: Model)
	local root = ownRoot()
	local humanoid = ownHumanoid()
	if not root or not humanoid then return end
	setJump(false)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. ParkConfig.SlideSoundId
	sound.Volume = 0.7
	sound.Parent = root
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 4)
	local lift = liftFor(root)
	local start = os.clock()
	local last: CFrame = root.CFrame
	while true do
		local e = (os.clock() - start) / ParkConfig.SlideSeconds
		if e >= 1 then break end
		local point, tangent = ParkConfig.slidePoint(model, e ^ 1.4)
		local flat = Vector3.new(tangent.X, 0, tangent.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		last = CFrame.lookAt(point, point + flat.Unit) * CFrame.new(0, lift, 0)
		slideCFrame = last
		RunService.RenderStepped:Wait()
	end
	slideCFrame = nil
	local endPoint, tangent = ParkConfig.slidePoint(model, 1)
	local flat = Vector3.new(tangent.X, 0, tangent.Z).Unit
	local landing = endPoint + flat * 2.5 + Vector3.new(0, 2.6, 0)
	root.CFrame = CFrame.lookAt(landing, landing + flat)
	root.AssemblyLinearVelocity = flat * 8
	humanoid.Sit = false
	setJump(true)
	slideCooldown = os.clock() + 1.5
	task.spawn(function() remote:InvokeServer("Slid") end)
end

local function checkSlides()
	if mySlot or slideCFrame or os.clock() < slideCooldown then return end
	local root = ownRoot()
	if not root then return end
	for _, model in ipairs(slides) do
		local start = model:FindFirstChild("SlideStart")
		if start and start:IsA("BasePart") and inBox(start, root.Position) then
			slideCooldown = os.clock() + 99
			task.spawn(slideDown, model)
			return
		end
	end
end

-- "야호!" above whoever came down the slide.
notify.OnClientEvent:Connect(function(kind: any, who: any)
	if kind ~= "Yahoo" or typeof(who) ~= "Instance" or not who:IsA("Player") then return end
	local character = who.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	-- "야호" voice for everyone near (the slider included).
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. ParkConfig.YahooSoundId
	sound.Volume = 0.8
	sound.RollOffMaxDistance = 80
	sound.Parent = head
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 5)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 50)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "야호! 🎉"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 110, 170)
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 4.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(billboard, 1.7)
end)

--------------------------------------------------
-- Loop
--------------------------------------------------

player.CharacterAdded:Connect(function()
	-- the server already cleared the seat (CharacterRemoving); a new character is never anchored
	mySlot = nil
	myTube = nil
	drivePos = nil
	slideCFrame = nil
	if firstPerson then setFirstPerson(false) end
end)

local uiTimer = 0
-- (D-1427) just before the camera: the camera then follows where the rider already is this frame
-- (a RenderStepped handler could run after it, and a moving rider looked like it judders)
RunService:BindToRenderStep("ParkRides", Enum.RenderPriority.Camera.Value - 1, function(dt)
	local t = now()
	-- Rides and riders move every frame from the same clock (at 30 updates a
	-- second the ride and the rider drifted apart and looked jerky, user
	-- report 2026-10-22).
	animate(t, dt)
	placeRiders(t)
	-- The server cleared my seat (🏠 home button, reset): stop riding.
	local entry = mySlot
	if entry and os.clock() - boardedAt > 1.5 and entry.slot:GetAttribute(entry.key) ~= player.UserId then stopRiding(nil) end
	if slideCFrame then placeOwn(slideCFrame) end
	checkSlides()
	uiTimer += dt
	if uiTimer >= 0.2 then
		uiTimer = 0
		refreshUi(t)
	end
end)
