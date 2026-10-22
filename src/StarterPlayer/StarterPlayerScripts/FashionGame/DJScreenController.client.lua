--!strict
-- Big LED screen behind the DJ (the club's "LED_Wall", user 2026-10-22).
--   * No DJ: club visuals — a moving colour gradient (DJ light colour or a
--     rainbow), an equalizer bouncing to the music, the OHU CLUB logo.
--   * DJ time: the DJ is shown live from the waist up on top of the visuals
--     (current pose, DJing motion included), the whole DJ time, also when they
--     are not at the turntable. The DJ can switch this off (attribute
--     ClubDJScreen = false, DjService.Actions.Screen).
-- Same live-avatar method as the round LED pillars: a copy of the character in
-- a ViewportFrame whose parts follow the real character every frame. Small
-- avatars are framed to fill the screen, so every DJ shows up big.
-- The SurfaceGui lives in PlayerGui with Adornee (a ViewportFrame in a
-- Workspace SurfaceGui is not drawn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))

local DRAW_DISTANCE = 320
local BARS = 24

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

type Screen = {
	part: BasePart,
	gui: SurfaceGui,
	gradient: UIGradient,
	bars: {Frame},
	logo: TextLabel,
	viewport: ViewportFrame,
	camera: Camera,
	nameLabel: TextLabel,
	clone: Model?,
	cloneParts: {[BasePart]: BasePart},
	sourceUserId: number,
	-- outfit changes while DJing: the copy is rebuilt (user, 2026-10-22)
	watch: {RBXScriptConnection},
	dirtyAt: number?,
}
local screen: Screen? = nil

-- the face of the wall that looks at the dance floor (toward the DJ spot)
local function faceToward(part: BasePart, point: Vector3): Enum.NormalId
	-- horizontal direction only: the spot is far below the wall's centre
	local best, bestDot = Enum.NormalId.Front, -math.huge
	local flat = Vector3.new(point.X - part.Position.X, 0, point.Z - part.Position.Z).Unit
	for _, id in ipairs(Enum.NormalId:GetEnumItems()) do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(id))
		local d = normal:Dot(flat)
		if d > bestDot then best, bestDot = id, d end
	end
	return best
end

local function build(part: BasePart, spot: BasePart)
	local gui = create("SurfaceGui", {
		Name = "DJScreen",
		Adornee = part,
		Face = faceToward(part, spot.Position),
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 24,
		LightInfluence = 0,
		Brightness = 1.4,
		ResetOnSpawn = false,
		AlwaysOnTop = false,
	}, playerGui)
	local bg = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
	local gradient = create("UIGradient", {}, bg)
	local shade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0 }, gui)
	shade.ZIndex = 2
	local bars = {}
	for i = 1, BARS do
		local bar = create("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((i - 1) / BARS + 0.004, 0, 1, 0),
			Size = UDim2.new(1 / BARS - 0.008, 0, 0.2, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, gui)
		bars[i] = bar
	end
	local logo = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.7, 0.3),
		BackgroundTransparency = 1,
		Text = "OHU CLUB",
		TextScaled = true,
		Font = Enum.Font.Michroma,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		ZIndex = 4,
	}, gui)
	local viewport = create("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.62, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.3, -1, -0.6),
		ZIndex = 5,
		Visible = false,
	}, gui)
	local camera = create("Camera", { FieldOfView = 30 }, viewport)
	viewport.CurrentCamera = camera
	local nameLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.03),
		Size = UDim2.fromScale(0.6, 0.11),
		BackgroundTransparency = 1,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
		ZIndex = 6,
		Visible = false,
	}, gui)
	screen = {
		part = part, gui = gui, gradient = gradient, bars = bars, logo = logo,
		viewport = viewport, camera = camera, nameLabel = nameLabel,
		clone = nil, cloneParts = {}, sourceUserId = 0, watch = {}, dirtyAt = nil,
	}
end

local function find()
	local club = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("02_Club")
	local wall = club and club:FindFirstChild("LED_Wall")
	local spot = club and club:FindFirstChild("DJSpot")
	if wall and wall:IsA("BasePart") and spot and spot:IsA("BasePart") then build(wall, spot) end
end

local function clearClone(s: Screen)
	if s.clone then s.clone:Destroy() end
	s.clone = nil
	s.cloneParts = {}
	s.sourceUserId = 0
	for _, connection in ipairs(s.watch) do connection:Disconnect() end
	s.watch = {}
	s.dirtyAt = nil
end

-- things that change how a character looks
local function isLook(instance: Instance): boolean
	return instance:IsA("Accessory") or instance:IsA("Clothing") or instance:IsA("ShirtGraphic")
		or instance:IsA("BodyColors") or instance:IsA("CharacterMesh") or instance:IsA("BasePart")
		or instance:IsA("SpecialMesh") or instance:IsA("Decal") or instance:IsA("SurfaceAppearance")
		or instance:IsA("WrapLayer")
end

-- copy of the DJ's character (no scripts, anchored), parts mapped to the real ones
local function makeClone(s: Screen, character: Model)
	clearClone(s)
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then return end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("IKControl") or d:IsA("BillboardGui") then d:Destroy() end
	end
	local map = {}
	local function index(model: Instance, list: {[string]: BasePart}, prefix: string)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then list[d:GetFullName():sub(#model:GetFullName() + 2)] = d end
		end
	end
	local srcParts, dstParts = {}, {}
	index(character, srcParts, "")
	copy.Parent = s.viewport
	index(copy, dstParts, "")
	for path, dst in pairs(dstParts) do
		dst.Anchored = true
		local src = srcParts[path]
		if src then map[dst] = src end
	end
	s.clone = copy
	s.cloneParts = map
	local function changed(instance: Instance)
		if isLook(instance) and not s.dirtyAt then s.dirtyAt = os.clock() end
	end
	s.watch = {
		character.DescendantAdded:Connect(changed),
		character.DescendantRemoving:Connect(changed),
	}
end

local function djUserId(): number
	local untilTime = FashionGame:GetAttribute("ClubDJUntil")
	local id = FashionGame:GetAttribute("ClubDJ")
	if typeof(id) == "number" and id ~= 0 and typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow() then
		return id
	end
	return 0
end

local function musicLoudness(): number
	local scripts = player:FindFirstChild("PlayerScripts")
	local sound = scripts and scripts:FindFirstChild("ClubMusic", true)
	if sound and sound:IsA("Sound") and sound.Volume > 0 then
		return math.clamp(sound.PlaybackLoudness / 400, 0, 1)
	end
	return 0
end

RunService.RenderStepped:Connect(function()
	if not screen or not screen.part.Parent then
		screen = nil
		find()
		if not screen then return end
	end
	local s = screen :: Screen
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - s.part.Position).Magnitude > DRAW_DISTANCE then
		s.gui.Enabled = false
		return
	end
	s.gui.Enabled = true
	local t = os.clock()
	-- background visuals
	local picked = ClubConfig.findLightColor(FashionGame:GetAttribute("ClubLightColor"))
	local lightsOff = FashionGame:GetAttribute("ClubLights") == false
	local base: Color3? = picked and picked.color
	local c1 = if base then base else Color3.fromHSV((t * 0.05) % 1, 0.85, 1)
	local c2 = if base then base:Lerp(Color3.new(0, 0, 0), 0.55) else Color3.fromHSV((t * 0.05 + 0.33) % 1, 0.85, 1)
	local c3 = if base then base:Lerp(Color3.new(1, 1, 1), 0.3) else Color3.fromHSV((t * 0.05 + 0.66) % 1, 0.85, 1)
	if lightsOff then c1, c2, c3 = Color3.fromRGB(25, 25, 35), Color3.fromRGB(10, 10, 15), Color3.fromRGB(40, 40, 55) end
	s.gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(0.5, c2), ColorSequenceKeypoint.new(1, c3) })
	s.gradient.Rotation = (t * 25) % 360
	local loud = musicLoudness()
	for i, bar in ipairs(s.bars) do
		local wave = 0.5 + 0.5 * math.sin(t * 6 + i * 0.7)
		local h = 0.06 + (0.15 + 0.55 * loud) * wave * (0.6 + 0.4 * math.sin(t * 2.3 + i))
		bar.Size = UDim2.new(1 / BARS - 0.008, 0, math.max(h, 0.04), 0)
		bar.BackgroundColor3 = c3
	end
	-- DJ on the screen
	local id = djUserId()
	local dj = if id ~= 0 then Players:GetPlayerByUserId(id) else nil
	local character = dj and dj.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local show = dj ~= nil and root ~= nil and FashionGame:GetAttribute("ClubDJScreen") ~= false
	s.logo.Visible = not show
	s.viewport.Visible = show
	s.nameLabel.Visible = show
	if not show or not character or not root or not dj then
		if s.clone then clearClone(s) end
		return
	end
	local outfitChanged = s.dirtyAt ~= nil and os.clock() - (s.dirtyAt :: number) > 0.4
	if s.sourceUserId ~= id or outfitChanged or not s.clone or not s.clone.Parent then
		makeClone(s, character)
		s.sourceUserId = id
		s.nameLabel.Text = "🎧 DJ " .. dj.DisplayName
	end
	-- copy the pose relative to the root; the copy faces -Z at the origin
	local rootCf = root.CFrame
	local top, bottom = -math.huge, math.huge
	for dst, src in pairs(s.cloneParts) do
		if src.Parent then
			local rel = rootCf:ToObjectSpace(src.CFrame)
			dst.CFrame = rel
			if src.Name == "Head" then top = rel.Position.Y + src.Size.Y / 2 end
		end
	end
	bottom = -0.6 -- about the waist
	if top == -math.huge then top = 2.5 end
	local span = math.max(top - bottom, 1.5)
	local centerY = (top + bottom) / 2 + span * 0.05
	local distance = span * 0.5 / math.tan(math.rad(s.camera.FieldOfView / 2)) * 1.15
	s.camera.CFrame = CFrame.lookAt(Vector3.new(0, centerY, -distance), Vector3.new(0, centerY, 0))
end)
