--!strict
-- Club visuals drawn on each client (user, 2026-10-20):
--
--   * Ceiling lasers: parts tagged "ClubLaser" (graybox 02_Club) shoot
--     coloured beams that sweep over the dance floor. Two patterns take turns
--     (circle sweep, fan sweep). The DJ switches them with 💡 조명
--     (attribute ClubLights; nil/true = on). Attribute "AimY" on the emitter
--     = height of the floor the beams land on.
--   * Round LED pillars (tag "LEDPillar"): the player chosen by
--     ClubScreenService (ShowUserId / ShowName) is drawn live (current dance /
--     movement) on the panels and turns slowly (360°). Idle: a rainbow.
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
-- Live avatar (user, 2026-10-22: "show the player's current animation, in
-- real time"). Each panel holds a ViewportFrame with a copy of the shown
-- player's character; every update the copy's parts are moved to the real
-- character's pose (relative to its root), so dances and walking show live.
-- The panels are slices of one wide picture that wraps half the pillar (the
-- avatar is shown twice around, so it is visible from any side) and the
-- avatar turns slowly for a 360° view. Back-facing panels are not updated.
-- When the character is not loaded here (streaming), the avatar thumbnail is
-- shown instead.

local Players = game:GetService("Players")

local IMAGE_SIZE = 420
-- The middle half of the square avatar thumbnail keeps the body proportions.
local CROP_X0, CROP_W = 105, 210
local TURN_SPEED = 0.45 -- radians per second
local VIEW_FOV = 30

type Panel = {
	part: BasePart,
	frame: Frame,
	image: ImageLabel,
	viewport: ViewportFrame,
	camera: Camera,
	clone: Model?,
	parts: {BasePart},
}
type Pillar = {
	model: Model,
	panels: {Panel},
	nameLabel: TextLabel?,
	center: Vector3,
	showing: number,
	source: Model?,
	sourceParts: {BasePart},
}
local pillars: {Pillar} = {}

-- "Accessory/Handle"-style path of a part inside its model.
local function pathOf(part: Instance, model: Instance): string
	local names = {}
	local node: Instance? = part
	while node and node ~= model do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end

local function partsByPath(model: Model): {[string]: BasePart}
	local map = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then map[pathOf(descendant, model)] = descendant end
	end
	return map
end

local function clearClones(pillar: Pillar)
	for _, panel in ipairs(pillar.panels) do
		if panel.clone then panel.clone:Destroy() end
		panel.clone = nil
		panel.parts = {}
	end
	pillar.source = nil
	pillar.sourceParts = {}
end

-- Copies `character` into every panel. Returns false when it cannot.
local function buildClones(pillar: Pillar, character: Model): boolean
	clearClones(pillar)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, template = pcall(function() return character:Clone() end)
	character.Archivable = wasArchivable
	if not ok or not template then return false end
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("ForceField")
			or descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt") or descendant:IsA("Beam") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	local humanoid = template:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	-- Pair the real character's parts with the copy's, by path.
	local templateParts = partsByPath(template)
	local sourceParts, paths = {}, {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local path = pathOf(descendant, character)
			if templateParts[path] then
				table.insert(sourceParts, descendant)
				table.insert(paths, path)
			end
		end
	end
	-- Camera: fit the standing avatar into the full height of the picture.
	local size = template:GetExtentsSize()
	local height = math.max(size.Y, 4)
	local centerY = template:GetBoundingBox().Position.Y - root.Position.Y
	local distance = (height * 0.6) / math.tan(math.rad(VIEW_FOV / 2))
	local cameraCFrame = CFrame.lookAt(Vector3.new(0, centerY, -distance), Vector3.new(0, centerY, 0))
	for index, panel in ipairs(pillar.panels) do
		local copy = if index == 1 then template else template:Clone()
		local map = if index == 1 then templateParts else partsByPath(copy)
		local list = {}
		for i, path in ipairs(paths) do list[i] = map[path] end
		copy.Parent = panel.viewport
		panel.clone = copy
		panel.parts = list
		panel.camera.CFrame = cameraCFrame
	end
	pillar.source = character
	pillar.sourceParts = sourceParts
	return true
end

-- Screens live in PlayerGui (Adornee = panel): a ViewportFrame in a
-- SurfaceGui parented to a Workspace part was not drawn (Studio test
-- 2026-10-22).
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screens: {[BasePart]: SurfaceGui} = {}

local function newPanel(part: BasePart, slice: number, repeatPanels: number): Panel
	local old = screens[part]
	if old then old:Destroy() end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "LEDScreen"
	surface.ResetOnSpawn = false
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.Brightness = 1.3
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 12
	surface.Adornee = part
	surface.Parent = playerGui
	screens[part] = surface
	-- Gone (rebuilt map, or streamed out): drop the screen with it.
	part.AncestryChanged:Connect(function()
		if part:IsDescendantOf(workspace) then return end
		if screens[part] == surface then screens[part] = nil end
		surface:Destroy()
	end)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = surface
	-- This panel shows slice `slice` of a picture `repeatPanels` panels wide.
	local slot = UDim2.new(-(slice % repeatPanels), 0, 0, 0)
	local wide = UDim2.new(repeatPanels, 0, 1, 0)
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.ImageRectOffset = Vector2.new(CROP_X0, 0)
	image.ImageRectSize = Vector2.new(CROP_W, IMAGE_SIZE)
	image.Position = slot
	image.Size = wide
	image.Visible = false
	image.Parent = frame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 190, 220)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0.3, -0.6, 1)
	viewport.Position = slot
	viewport.Size = wide
	viewport.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = VIEW_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return { part = part, frame = frame, image = image, viewport = viewport, camera = camera, clone = nil, parts = {} }
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
	local repeatPanels = math.max(1, math.floor(#list / 2))
	local pillar: Pillar = {
		model = model, panels = {}, nameLabel = nil, center = Vector3.zero, showing = -1,
		source = nil, sourceParts = {},
	}
	for _, item in ipairs(list) do
		table.insert(pillar.panels, newPanel(item.part, item.slice, repeatPanels))
	end
	local core = model:FindFirstChild("Core")
	pillar.center = if core and core:IsA("BasePart") then core.Position elseif list[1] then list[1].part.Position else model:GetPivot().Position
	local anchor = model:FindFirstChild("NameAnchor")
	if anchor and anchor:IsA("BasePart") then
		local oldBillboard = anchor:FindFirstChild("PillarName")
		if oldBillboard then oldBillboard:Destroy() end
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PillarName"
		billboard.Size = UDim2.fromOffset(220, 36)
		billboard.MaxDistance = 220
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
			if pillars[index] and pillars[index].model == model then
				clearClones(pillars[index])
				pillars[index] = buildPillar(model)
			end
		end)
	end)
end

for _, model in ipairs(CollectionService:GetTagged("LEDPillar")) do addPillar(model) end
CollectionService:GetInstanceAddedSignal("LEDPillar"):Connect(addPillar)

local function setThumbnail(pillar: Pillar, id: number, on: boolean)
	local image = if id > 0 then string.format("rbxthumb://type=Avatar&id=%d&w=%d&h=%d", id, IMAGE_SIZE, IMAGE_SIZE) else ""
	for _, panel in ipairs(pillar.panels) do
		panel.image.Image = image
		panel.image.Visible = on
	end
end

local function updatePillars(t: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for _, pillar in ipairs(pillars) do
		if pillar.model.Parent and inRange(pillar.center) then
			local userId = pillar.model:GetAttribute("ShowUserId")
			local id = if typeof(userId) == "number" then userId else 0
			local shownPlayer = if id > 0 then Players:GetPlayerByUserId(id) else nil
			local character = shownPlayer and shownPlayer.Character
			if id ~= pillar.showing or (character and character ~= pillar.source) or (not character and pillar.source) then
				pillar.showing = id
				local live = character ~= nil and buildClones(pillar, character)
				if not live then clearClones(pillar) end
				setThumbnail(pillar, id, id > 0 and not live)
				if pillar.nameLabel then
					local name = pillar.model:GetAttribute("ShowName")
					pillar.nameLabel.Text = if id > 0 and typeof(name) == "string" then "✨ " .. name else "CLUB · FASHION SOCIAL"
				end
			end
			local root = pillar.source and pillar.source:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				-- Pose relative to the real root, turning slowly.
				local base = CFrame.Angles(0, t * TURN_SPEED, 0) * root.CFrame:Inverse()
				local poses = table.create(#pillar.sourceParts)
				for i, part in ipairs(pillar.sourceParts) do poses[i] = base * part.CFrame end
				for _, panel in ipairs(pillar.panels) do
					local facing = (cameraPosition - panel.part.Position):Dot(panel.part.CFrame.LookVector) > 0
					if facing then
						for i, copy in ipairs(panel.parts) do
							if copy then copy.CFrame = poses[i] end
						end
					end
				end
			end
			local count = #pillar.panels
			for k, panel in ipairs(pillar.panels) do
				if id > 0 then
					panel.frame.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
				else
					local hue = ((k - 1) / math.max(count, 1) + t * 0.08) % 1
					panel.frame.BackgroundColor3 = Color3.fromHSV(hue, 0.75, 0.95)
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

