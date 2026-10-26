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

local function now(): number
	return workspace:GetServerTimeNow()
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

local function cameraNear(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < DRAW_DISTANCE
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

local function addCarousel(model: Model)
	local center = hubCFrame(model, "Center")
	local rotor = model:FindFirstChild("Rotor") :: Model?
	if not center then return end
	table.insert(carousels, { model = model, rotor = rotor, rel = if rotor then center:Inverse() * rotor:GetPivot() else CFrame.new() })
	for index = 1, ParkConfig.horseCount(model) do
		local horse = model:FindFirstChild("Horse" .. index) :: Instance
		table.insert(slots, {
			kind = "ParkCarousel", ride = model, slot = horse, key = "Rider",
			seat = function(t: number): CFrame? return ParkConfig.horseCFrame(model, index, t) end,
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

local function animate(t: number, dt: number)
	for _, wheel in ipairs(wheels) do
		local hub = hubCFrame(wheel.model, "Hub")
		if hub and cameraNear(hub.Position) then
			if wheel.rotor then
				wheel.rotor:PivotTo(hub * CFrame.Angles(ParkConfig.wheelAngle(wheel.model, t), 0, 0) * wheel.rel)
			end
			for index = 1, ParkConfig.cabinCount(wheel.model) do
				local cabin = wheel.model:FindFirstChild("Cabin" .. index)
				local cf = ParkConfig.cabinCFrame(wheel.model, index, t)
				if cabin and cabin:IsA("Model") and cf then cabin:PivotTo(cf) end
			end
		end
	end
	for _, carousel in ipairs(carousels) do
		local center = hubCFrame(carousel.model, "Center")
		if center and cameraNear(center.Position) then
			if carousel.rotor then
				carousel.rotor:PivotTo(center * CFrame.Angles(0, ParkConfig.carouselAngle(carousel.model, t), 0) * carousel.rel)
			end
			for index = 1, ParkConfig.horseCount(carousel.model) do
				local horse = carousel.model:FindFirstChild("Horse" .. index)
				local cf = ParkConfig.horseCFrame(carousel.model, index, t)
				if horse and horse:IsA("Model") and cf then horse:PivotTo(cf) end
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
			swing.seat:PivotTo(pivot * CFrame.Angles(swing.amp * math.sin(swing.phase), 0, 0))
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
			spring.rocker:PivotTo(spring.base * CFrame.Angles(angle, 0, 0))
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

local function paddle(dt: number)
	local tube = myTube
	local pos = drivePos
	local humanoid = ownHumanoid()
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
		if entry.kind == "FloatTube" and not root.Anchored then root.Anchored = true end
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
		if entry.kind == "ParkCarousel" then consider(entry, "🎠 목마 타기", 5)
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
mainButton.MouseButton1Click:Connect(pressMain)

viewButton.MouseButton1Click:Connect(function()
	setFirstPerson(not firstPerson)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		if bar.Visible and mainButton.Visible then task.spawn(pressMain) end
	elseif input.KeyCode == Enum.KeyCode.V then
		if mySlot and mySlot.kind == "ParkWheel" then setFirstPerson(not firstPerson) end
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
		viewButton.Visible = entry.kind == "ParkWheel"
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
RunService.RenderStepped:Connect(function(dt)
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
