--!strict
-- (D-1104, user 2026-11-09: "삼각김밥 전자레인지에 5초 돌려서 먹는 기능 추가.
-- 삼각김밥 들고 전자레인지 클릭하면 윙- 소리 나면서 전자레인지 앞에 검은색 네모
-- 부분 주황색으로 변함. 5초 후 띵- 하면서 검은색으로 변하고 전자레인지 문 열리고
-- 안에 삼각김밥 보임. 삼각김밥 클릭하면 인벤토리로 들어옴.")
-- The OH24 microwave (one Part "OhuMicrowave" + its front picture, polish_1028)
-- is made into a working one when the server starts: the part is hidden and
-- rebuilt as a box with a hollow inside, a door on a hinge (the left part of
-- the picture, its window glows orange while it runs) and the control panel
-- (the right part, its 0:00 display counts down). Every part named
-- "OhuMicrowave" in Workspace works this way (the user placed a second one).
-- A tap on it with a 삼각김밥 in the hand (SnackController asks "Microwave")
-- puts that 삼각김밥 inside; a tap on it when the door is open ("MicrowaveTake")
-- gives it back to its owner's backpack.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Microwave = {}

local IMAGE = "rbxassetid://126360038963034" -- (microwave_front.png, 512 x 300)
local IMG_W, IMG_H = 512, 300
local SPLIT = 345 -- px: door to the left, control panel to the right
local WINDOW = { x = 47, y = 52, w = 274, h = 186 } -- px: the dark glass
local DISPLAY = { x = 397, y = 35, w = 83, h = 33 } -- px: "0:00"
local HEAT_SECONDS = 5
local SOUND_HUM = 9056753632 -- Microwave Humming [Perfect Loop]
local SOUND_DING = 106123953900389 -- microwave done ding sfx
local OPEN_ANGLE = math.rad(-105) -- (the free edge swings out toward the store)
local SWING_SECONDS = 0.4
local DOOR_T = 0.08
local WALL = 0.1
local REACH = 14
local KEEP_SECONDS = 90 -- not taken: back to the owner's backpack
local ORANGE = Color3.fromRGB(255, 140, 40)
local WHITE = Color3.fromRGB(246, 246, 244)
local INSIDE = Color3.fromRGB(214, 214, 208)

type Rig = {
	model: Model, door: BasePart, glow: Frame, display: TextLabel, light: PointLight,
	hum: Sound, ding: Sound, hinge: CFrame, doorW: number, cavity: CFrame, cavitySize: Vector3,
	state: string, token: number, food: Model?, tool: Tool?, owner: Player?,
}
local rigs: {[Model]: Rig} = {}

local function holdFolder(): Folder
	local f = ServerStorage:FindFirstChild("MicrowaveHold")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MicrowaveHold"
		f.Parent = ServerStorage
	end
	return f :: Folder
end

local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Parent = parent
	CollectionService:AddTag(p, "Microwave")
	return p
end

-- a crop of the front picture on the +Z face of a part
local function picture(part: BasePart, x0: number, w: number, lit: boolean): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(w, IMG_H)
	gui.LightInfluence = if lit then 1 else 0
	gui.ZOffset = if lit then 0 else 1 -- (the glow and the display over the picture)
	gui.Parent = part
	if lit then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = IMAGE
		img.ImageRectOffset = Vector2.new(x0, 0)
		img.ImageRectSize = Vector2.new(w, IMG_H)
		img.Parent = gui
	end
	return gui
end

local function setDoor(rig: Rig, angle: number)
	rig.door.CFrame = rig.hinge * CFrame.Angles(0, angle, 0) * CFrame.new(rig.doorW / 2, 0, -DOOR_T / 2)
end

local function swing(rig: Rig, from: number, to: number)
	local t = 0
	while t < SWING_SECONDS do
		t += RunService.Heartbeat:Wait()
		local a = math.min(1, t / SWING_SECONDS)
		a = a * a * (3 - 2 * a)
		setDoor(rig, from + (to - from) * a)
	end
	setDoor(rig, to)
end

local function build(body: BasePart)
	local L = body.CFrame
	local hx, hy, hz = body.Size.X / 2, body.Size.Y / 2, body.Size.Z / 2
	local doorW = SPLIT / IMG_W * body.Size.X
	local xSplit = -hx + doorW
	local model = Instance.new("Model")
	model.Name = "MicrowaveRig"
	model.Parent = body.Parent
	-- the old one-part microwave stays (the layout scripts find it), unseen
	body.Transparency = 1
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	for _, d in ipairs(body:GetChildren()) do
		if d:IsA("Decal") then d.Transparency = 1 end
	end
	local depth = 2 * hz - DOOR_T
	local panel = piece("Panel", Vector3.new(hx - xSplit, 2 * hy, 2 * hz), L * CFrame.new((xSplit + hx) / 2, 0, 0), WHITE, model)
	picture(panel, SPLIT, IMG_W - SPLIT, true)
	piece("Top", Vector3.new(doorW, WALL, depth), L * CFrame.new(-hx + doorW / 2, hy - WALL / 2, -DOOR_T / 2), WHITE, model)
	piece("Bottom", Vector3.new(doorW, WALL, depth), L * CFrame.new(-hx + doorW / 2, -hy + WALL / 2, -DOOR_T / 2), WHITE, model)
	piece("Side", Vector3.new(WALL, 2 * hy - 2 * WALL, depth), L * CFrame.new(-hx + WALL / 2, 0, -DOOR_T / 2), WHITE, model)
	piece("Back", Vector3.new(doorW - WALL, 2 * hy - 2 * WALL, WALL), L * CFrame.new(-hx + WALL + (doorW - WALL) / 2, 0, -hz + WALL / 2), WHITE, model)
	-- the inside: light walls (thin linings) and the glass turntable
	local cavitySize = Vector3.new(doorW - WALL, 2 * hy - 2 * WALL, depth - WALL)
	local cavity = L * CFrame.new(-hx + WALL + cavitySize.X / 2, 0, -hz + WALL + cavitySize.Z / 2)
	local lining = 0.01
	piece("LiningBack", Vector3.new(cavitySize.X, cavitySize.Y, lining), cavity * CFrame.new(0, 0, -cavitySize.Z / 2 + lining / 2), INSIDE, model)
	piece("LiningTop", Vector3.new(cavitySize.X, lining, cavitySize.Z), cavity * CFrame.new(0, cavitySize.Y / 2 - lining / 2, 0), INSIDE, model)
	piece("LiningFloor", Vector3.new(cavitySize.X, lining, cavitySize.Z), cavity * CFrame.new(0, -cavitySize.Y / 2 + lining / 2, 0), INSIDE, model)
	piece("LiningSide", Vector3.new(lining, cavitySize.Y, cavitySize.Z), cavity * CFrame.new(-cavitySize.X / 2 + lining / 2, 0, 0), INSIDE, model)
	piece("LiningPanel", Vector3.new(lining, cavitySize.Y, cavitySize.Z), cavity * CFrame.new(cavitySize.X / 2 - lining / 2, 0, 0), INSIDE, model)
	local d = math.min(cavitySize.X, cavitySize.Z) * 0.85
	local plate = piece("Turntable", Vector3.new(0.03, d, d), cavity * CFrame.new(0, -cavitySize.Y / 2 + lining + 0.015, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(235, 240, 240), model)
	plate.Shape = Enum.PartType.Cylinder
	plate.Material = Enum.Material.Glass
	plate.Transparency = 0.35
	local lamp = piece("Lamp", Vector3.new(0.1, 0.1, 0.1), cavity * CFrame.new(0, cavitySize.Y / 2 - 0.1, 0), INSIDE, model)
	lamp.Transparency = 1
	lamp.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 4
	light.Brightness = 1.6
	light.Enabled = false
	light.Parent = lamp
	-- the door: the left part of the picture, its glass glows while it runs
	local door = piece("Door", Vector3.new(doorW, 2 * hy, DOOR_T), CFrame.identity, WHITE, model)
	picture(door, 0, SPLIT, true)
	local glowGui = picture(door, 0, SPLIT, false)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Position = UDim2.fromScale(WINDOW.x / SPLIT, WINDOW.y / IMG_H)
	glow.Size = UDim2.fromScale(WINDOW.w / SPLIT, WINDOW.h / IMG_H)
	glow.BackgroundColor3 = ORANGE
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Parent = glowGui
	-- the display over the picture's 0:00
	local displayGui = picture(panel, SPLIT, IMG_W - SPLIT, false)
	local display = Instance.new("TextLabel")
	display.Name = "Display"
	display.Position = UDim2.fromScale((DISPLAY.x - SPLIT) / (IMG_W - SPLIT), DISPLAY.y / IMG_H)
	display.Size = UDim2.fromScale(DISPLAY.w / (IMG_W - SPLIT), DISPLAY.h / IMG_H)
	display.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	display.BorderSizePixel = 0
	display.Font = Enum.Font.Code
	display.TextScaled = true
	display.TextColor3 = Color3.fromRGB(240, 240, 240)
	display.Text = "0:00"
	display.Parent = displayGui
	local hum = Instance.new("Sound")
	hum.Name = "Hum"
	hum.SoundId = "rbxassetid://" .. SOUND_HUM
	hum.Looped = true
	hum.Volume = 0.6
	hum.RollOffMaxDistance = 30
	hum.Parent = panel
	local ding = Instance.new("Sound")
	ding.Name = "Ding"
	ding.SoundId = "rbxassetid://" .. SOUND_DING
	ding.Volume = 0.8
	ding.RollOffMaxDistance = 40
	ding.Parent = panel
	local rig: Rig = {
		model = model, door = door, glow = glow, display = display, light = light,
		hum = hum, ding = ding, hinge = L * CFrame.new(-hx, 0, hz), doorW = doorW,
		cavity = cavity, cavitySize = cavitySize, state = "idle", token = 0,
	}
	setDoor(rig, 0)
	rigs[model] = rig
end

local function rigOf(target: any): Rig?
	if typeof(target) ~= "Instance" then return nil end
	local m = target:FindFirstAncestorOfClass("Model")
	while m do
		local rig = rigs[m]
		if rig then return rig end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function near(player: Player, rig: Rig): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - rig.door.Position).Magnitude <= REACH
end

-- what is seen inside: a copy of the 삼각김밥 as it is (wrapped or not)
local function foodCopy(tool: Tool, rig: Rig): Model?
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return nil end
	local m = Instance.new("Model")
	m.Name = "MicrowaveFood"
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local c = p:Clone()
			for _, ch in ipairs(c:GetChildren()) do
				if not (ch:IsA("Decal") or ch:IsA("Texture") or ch:IsA("SpecialMesh") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
			end
			c.Anchored = true
			c.CanCollide = false
			c.CanTouch = false
			c.CanQuery = true
			c.CFrame = handle.CFrame:ToObjectSpace(p.CFrame)
			c.Parent = m
			CollectionService:AddTag(c, "MicrowaveFood")
		end
	end
	if #m:GetChildren() == 0 then m:Destroy() return nil end
	m.WorldPivot = CFrame.identity
	local box, size = m:GetBoundingBox()
	m.WorldPivot = box
	local fit = math.min(1, rig.cavitySize.X * 0.7 / size.X, rig.cavitySize.Y * 0.8 / size.Y, rig.cavitySize.Z * 0.7 / size.Z)
	if fit < 1 then m:ScaleTo(fit) end
	local h = size.Y * fit
	m:PivotTo(rig.cavity * CFrame.new(0, -rig.cavitySize.Y / 2 + 0.05 + h / 2, 0) * box.Rotation)
	-- a little steam when the door opens
	local wisp = Instance.new("ParticleEmitter")
	wisp.Name = "Steam"
	wisp.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisp.Color = ColorSequence.new(Color3.new(1, 1, 1))
	wisp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	wisp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.5) })
	wisp.Lifetime = NumberRange.new(1, 1.6)
	wisp.Speed = NumberRange.new(0.4, 0.8)
	wisp.SpreadAngle = Vector2.new(20, 20)
	wisp.Rate = 6
	wisp.Enabled = false
	local first = m:FindFirstChildWhichIsA("BasePart")
	if first then wisp.Parent = first end
	return m
end

local function stopRunning(rig: Rig)
	rig.hum:Stop()
	rig.glow.BackgroundTransparency = 1
	rig.light.Enabled = false
	rig.display.Text = "0:00"
end

-- the 삼각김밥 back to its owner (or gone with them), the door shut
local function giveBack(rig: Rig)
	local tool, owner = rig.tool, rig.owner
	rig.tool, rig.owner = nil, nil
	if rig.food then rig.food:Destroy() rig.food = nil end
	if tool then
		local backpack = owner and owner.Parent and owner:FindFirstChildOfClass("Backpack")
		if backpack then tool.Parent = backpack else tool:Destroy() end
	end
	stopRunning(rig)
	local wasOpen = rig.state == "open"
	rig.token += 1
	local token = rig.token
	rig.state = "closing"
	task.spawn(function()
		if wasOpen then
			task.wait(0.4)
			swing(rig, OPEN_ANGLE, 0)
		end
		if rig.token == token then rig.state = "idle" end
	end)
end

function Microwave.heat(player: Player, target: any): (boolean, string?)
	local rig = rigOf(target)
	if not rig then return false, nil end
	-- (D-1113) theirs is done and waiting: out it comes first
	if rig.state == "open" and rig.owner == player and near(player, rig) then
		giveBack(rig)
		return true, nil
	end
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local key = tool and tool:GetAttribute("Snack")
	if not tool or typeof(key) ~= "string" or string.sub(key, 1, 6) ~= "samgak" then
		return false, "삼각김밥을 들고 눌러 주세요."
	end
	if tool:GetAttribute("Busy") then return false, nil end
	if not near(player, rig) then return false, "전자레인지 가까이에서 눌러 주세요." end
	if rig.state ~= "idle" then return false, "전자레인지를 쓰고 있어요." end
	rig.token += 1
	local token = rig.token
	rig.state = "heating"
	rig.owner, rig.tool = player, tool
	rig.food = foodCopy(tool, rig)
	if rig.food then rig.food.Parent = rig.model end
	tool.Parent = holdFolder()
	rig.glow.BackgroundTransparency = 0.12
	rig.light.Enabled = true
	rig.hum.TimePosition = 0
	rig.hum:Play()
	task.spawn(function()
		for left = HEAT_SECONDS, 1, -1 do
			if rig.token ~= token then return end
			rig.display.Text = string.format("0:%02d", left)
			task.wait(1)
		end
		if rig.token ~= token then return end
		stopRunning(rig)
		rig.ding.TimePosition = 0
		rig.ding:Play()
		rig.state = "open"
		swing(rig, 0, OPEN_ANGLE)
		local food = rig.food
		local wisp = food and food:FindFirstChild("Steam", true)
		if wisp and wisp:IsA("ParticleEmitter") then
			wisp.Enabled = true
			task.delay(4, function() if wisp.Parent then wisp.Enabled = false end end)
		end
		task.delay(KEEP_SECONDS, function()
			if rig.token == token and rig.state == "open" then giveBack(rig) end
		end)
	end)
	return true, nil
end

-- (D-1113, user 2026-11-09: "전자레인지 다 돌아가고 삼각김밥 안 꺼내짐") a tap on
-- the 삼각김밥 or on any part of the open microwave takes it out (the small
-- 삼각김밥 was hard to hit; the tap usually landed on the frame round it)
function Microwave.take(player: Player, target: any): (boolean, string?)
	if typeof(target) ~= "Instance" then return false, nil end
	if not CollectionService:HasTag(target, "MicrowaveFood") and not CollectionService:HasTag(target, "Microwave") then return false, nil end
	local rig = rigOf(target)
	if not rig or rig.state ~= "open" then return false, nil end
	if rig.owner ~= player then return false, "다른 사람이 데운 삼각김밥이에요." end
	if not near(player, rig) then return false, "전자레인지 가까이에서 눌러 주세요." end
	giveBack(rig)
	return true, nil
end

function Microwave.Start()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "OhuMicrowave" then
			local ok, err = pcall(build, d)
			if not ok then warn("[Microwave]", err) end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, rig in pairs(rigs) do
			if rig.owner == player then giveBack(rig) end
		end
	end)
end

return Microwave
