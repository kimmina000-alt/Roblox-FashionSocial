--!strict
-- Club visuals drawn on each client (user, 2026-10-20):
--
--   * Ceiling lasers: parts tagged "ClubLaser" (graybox 02_Club) shoot
--     coloured beams that sweep over the dance floor. Two patterns take turns
--     (circle sweep, fan sweep). The DJ switches them with 💡 조명
--     (attribute ClubLights; nil/true = on). Attribute "AimY" on the emitter
--     = height of the floor the beams land on.
--   * Round LED pillars (tag "LEDPillar"): the player chosen by
--     ClubScreenService (ShowUserId / ShowName) is drawn on all panels and
--     turns slowly around the pillar (360°). Idle: a rainbow turning around.
--
-- Everything here is local: beams and screens cost nothing on the server.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")

local DRAW_DISTANCE = 260

local function inRange(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < DRAW_DISTANCE
end

--------------------------------------------------
-- Lasers
--------------------------------------------------

local BEAMS_PER_EMITTER = 4
local targetHolder = Instance.new("Part")
targetHolder.Name = "ClubLaserTargets"
targetHolder.Anchored = true
targetHolder.CanCollide = false
targetHolder.CanQuery = false
targetHolder.CanTouch = false
targetHolder.Transparency = 1
targetHolder.Size = Vector3.new(0.2, 0.2, 0.2)
targetHolder.CFrame = CFrame.new()
targetHolder.Parent = workspace

type Emitter = { part: BasePart, beams: {Beam}, targets: {Attachment}, index: number }
local emitters: {Emitter} = {}

local function addEmitter(instance: Instance)
	if not instance:IsA("BasePart") then return end
	for _, entry in ipairs(emitters) do
		if entry.part == instance then return end
	end
	local origin = Instance.new("Attachment")
	origin.Name = "LaserOrigin"
	origin.Position = Vector3.new(0, -instance.Size.Y / 2, 0)
	origin.Parent = instance
	local entry: Emitter = { part = instance, beams = {}, targets = {}, index = #emitters }
	for i = 1, BEAMS_PER_EMITTER do
		local target = Instance.new("Attachment")
		target.Name = "LaserTarget"
		target.Parent = targetHolder
		local beam = Instance.new("Beam")
		beam.Attachment0 = origin
		beam.Attachment1 = target
		beam.Width0 = 0.12
		beam.Width1 = 0.4
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Transparency = NumberSequence.new(0.05, 0.35)
		beam.Enabled = false
		beam.Parent = instance
		entry.beams[i] = beam
		entry.targets[i] = target
	end
	table.insert(emitters, entry)
end

for _, part in ipairs(CollectionService:GetTagged("ClubLaser")) do addEmitter(part) end
CollectionService:GetInstanceAddedSignal("ClubLaser"):Connect(addEmitter)

local function updateLasers(t: number)
	local on = FashionGame:GetAttribute("ClubLights") ~= false
	-- Pattern changes every 12 s: 0 = circle sweep, 1 = fan sweep.
	local pattern = math.floor(t / 12) % 2
	for _, entry in ipairs(emitters) do
		local part = entry.part
		local visible = on and part.Parent ~= nil and inRange(part.Position)
		local aimY = part:GetAttribute("AimY")
		local floorY = if typeof(aimY) == "number" then aimY else part.Position.Y - 40
		local base = Vector3.new(part.Position.X, floorY, part.Position.Z)
		for i, beam in ipairs(entry.beams) do
			beam.Enabled = visible
			if visible then
				local phase = entry.index * 0.9 + i * (math.pi * 2 / BEAMS_PER_EMITTER)
				local offset: Vector3
				if pattern == 0 then
					local radius = 10 + 6 * math.sin(t * 0.8 + phase)
					local angle = t * 1.3 + phase
					offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				else
					local spread = (i - (BEAMS_PER_EMITTER + 1) / 2) * 7
					local swing = math.sin(t * 1.6 + entry.index) * 14
					offset = Vector3.new(spread + swing, 0, math.cos(t * 0.9 + entry.index) * 10)
				end
				entry.targets[i].WorldPosition = base + offset
				local hue = (t * 0.05 + entry.index * 0.13 + i * 0.07) % 1
				local color = Color3.fromHSV(hue, 0.85, 1)
				beam.Color = ColorSequence.new(color)
			end
		end
	end
end

--------------------------------------------------
-- LED pillars
--------------------------------------------------

local IMAGE_SIZE = 420
-- The middle half of the square avatar thumbnail keeps the body proportions.
local CROP_X0, CROP_W = 105, 210
local TURN_SPEED = 0.6 -- panels per second

type Pillar = {
	model: Model,
	panels: {{ frame: Frame, a: ImageLabel, b: ImageLabel }},
	nameLabel: TextLabel?,
	center: Vector3,
	showing: number,
}
local pillars: {Pillar} = {}

local function portraitLabel(parent: Instance): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Stretch
	image.ImageRectOffset = Vector2.new(CROP_X0, 0)
	image.ImageRectSize = Vector2.new(CROP_W, IMAGE_SIZE)
	image.Parent = parent
	return image
end

-- (Re)builds the screens from the panels streamed in so far (StreamingEnabled:
-- a pillar's parts can arrive after its tag).
local function buildPillar(model: Model): Pillar
	local list = {}
	for _, panel in ipairs(model:GetChildren()) do
		local slice = panel:GetAttribute("Slice")
		if panel:IsA("BasePart") and panel.Name == "Panel" and typeof(slice) == "number" and slice >= 0 then
			table.insert(list, { part = panel, slice = slice })
		end
	end
	table.sort(list, function(x, y) return x.slice < y.slice end)
	local pillar: Pillar = { model = model, panels = {}, nameLabel = nil, center = Vector3.zero, showing = -1 }
	for _, item in ipairs(list) do
		local old = item.part:FindFirstChild("LEDScreen")
		if old then old:Destroy() end
	end
	local core = model:FindFirstChild("Core")
	pillar.center = if core and core:IsA("BasePart") then core.Position elseif list[1] then list[1].part.Position else model:GetPivot().Position
	for _, item in ipairs(list) do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "LEDScreen"
		surface.Face = Enum.NormalId.Front
		surface.LightInfluence = 0
		surface.Brightness = 2.5
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 16
		surface.Adornee = item.part
		surface.Parent = item.part
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
		frame.BorderSizePixel = 0
		frame.ClipsDescendants = true
		frame.Parent = surface
		table.insert(pillar.panels, { frame = frame, a = portraitLabel(frame), b = portraitLabel(frame) })
	end
	local anchor = model:FindFirstChild("NameAnchor")
	if anchor and anchor:IsA("BasePart") then
		local oldBillboard = anchor:FindFirstChild("PillarName")
		if oldBillboard then oldBillboard:Destroy() end
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PillarName"
		billboard.Size = UDim2.fromOffset(220, 36)
		billboard.MaxDistance = 180
		billboard.LightInfluence = 0
		billboard.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = "CLUB"
		label.Parent = billboard
		pillar.nameLabel = label
	end
	return pillar
end

local function addPillar(model: Instance)
	if not model:IsA("Model") then return end
	for _, entry in ipairs(pillars) do
		if entry.model == model then return end
	end
	local index = #pillars + 1
	pillars[index] = buildPillar(model)
	local pending = false
	model.ChildAdded:Connect(function()
		if pending then return end
		pending = true
		task.delay(0.5, function()
			pending = false
			local at = table.find(pillars, pillars[index])
			if at and pillars[at].model == model then pillars[at] = buildPillar(model) end
		end)
	end)
end

for _, model in ipairs(CollectionService:GetTagged("LEDPillar")) do addPillar(model) end
CollectionService:GetInstanceAddedSignal("LEDPillar"):Connect(addPillar)

local function updatePillars(t: number)
	for _, pillar in ipairs(pillars) do
		if pillar.model.Parent and inRange(pillar.center) then
			local userId = pillar.model:GetAttribute("ShowUserId")
			local id = if typeof(userId) == "number" then userId else 0
			if id ~= pillar.showing then
				pillar.showing = id
				local image = if id > 0
					then string.format("rbxthumb://type=Avatar&id=%d&w=%d&h=%d", id, IMAGE_SIZE, IMAGE_SIZE)
					else ""
				for _, panel in ipairs(pillar.panels) do
					panel.a.Image = image
					panel.b.Image = image
					panel.a.Visible = id > 0
					panel.b.Visible = id > 0
				end
				if pillar.nameLabel then
					local name = pillar.model:GetAttribute("ShowName")
					pillar.nameLabel.Text = if id > 0 and typeof(name) == "string" then "✨ " .. name else "CLUB · FASHION SOCIAL"
				end
			end
			local count = #pillar.panels
			if count > 0 then
				-- The portrait repeats twice around the pillar (visible from any side).
				local repeatPanels = math.max(1, math.floor(count / 2))
				local shift = (t * TURN_SPEED) % repeatPanels
				for k, panel in ipairs(pillar.panels) do
					if id > 0 then
						local position = ((k - 1 + shift) % repeatPanels)
						panel.a.Size = UDim2.new(repeatPanels, 0, 1, 0)
						panel.b.Size = UDim2.new(repeatPanels, 0, 1, 0)
						panel.a.Position = UDim2.new(-position, 0, 0, 0)
						panel.b.Position = UDim2.new(repeatPanels - position, 0, 0, 0)
						panel.frame.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
					else
						local hue = ((k - 1) / count + t * 0.08) % 1
						panel.frame.BackgroundColor3 = Color3.fromHSV(hue, 0.75, 0.95)
					end
				end
			end
		end
	end
end

--------------------------------------------------

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	-- 30 updates a second is smooth enough for both.
	if accumulator < 1 / 30 then return end
	accumulator = 0
	local t = workspace:GetServerTimeNow()
	updateLasers(t)
	updatePillars(t)
end)

