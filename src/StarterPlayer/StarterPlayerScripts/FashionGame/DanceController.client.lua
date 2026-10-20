--!strict
-- Club MVP client (Stage 4): dance panel, dance playback, 같이 추기, club music.
--
-- The server owns the dance state (character attributes DanceKey / DanceStart /
-- DanceSpeed, see ClubService). This script only plays what those attributes
-- say on the local character; Animator replication shows it to everyone.
-- Moving, jumping or sitting stops the dance. Music is one shared playlist
-- clock (FashionGame attributes ClubTrack / ClubTrackStart), played locally
-- with volume by distance to parts tagged "ClubZone".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local danceRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Dance") :: RemoteEvent

local COLORS = {
	panel = Color3.fromRGB(18, 18, 24),
	card = Color3.fromRGB(38, 38, 50),
	cardActive = Color3.fromRGB(255, 80, 200),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	accent = Color3.fromRGB(255, 80, 200),
	join = Color3.fromRGB(80, 200, 255),
}

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then instance.Parent = parent end
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

--------------------------------------------------
-- GUI
--------------------------------------------------

local gui = create("ScreenGui", {
	Name = "FashionDanceGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 19,
}, playerGui)

local danceButton = create("TextButton", {
	Name = "DanceButton",
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	Text = "💃",
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.text,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, danceButton)

-- Sits just left of the catalog "C" button at the right end of the top bar.
local function positionDanceButton()
	local inset = GuiService.TopbarInset
	local centerY, rightX, size = 34, -16, 44
	if inset.Height > 0 then
		centerY = inset.Min.Y + inset.Height / 2
		size = math.clamp(inset.Height - 12, 32, 44)
		local camera = workspace.CurrentCamera
		if camera and inset.Width > 0 then
			rightX = -(camera.ViewportSize.X - inset.Max.X) - 8
		end
	end
	danceButton.Size = UDim2.fromOffset(size, size)
	danceButton.Position = UDim2.new(1, rightX - size - 8, 0, centerY)
end
positionDanceButton()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(positionDanceButton)

local panel = create("Frame", {
	Name = "DancePanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.12,
	Visible = false,
}, gui)
corner(panel, 15)
create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, panel)

local header = create("TextLabel", {
	Size = UDim2.new(1, -40, 0, 26),
	BackgroundTransparency = 1,
	Text = "춤",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
}, panel)
local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = COLORS.card,
	Text = "✕",
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, panel)
corner(closeButton, 14)

-- Now dancing + stop
local nowLabel = create("TextLabel", {
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, -78, 0, 28),
	BackgroundTransparency = 1,
	Text = "춤을 고르세요",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.sub,
	TextSize = 14,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Font = Enum.Font.GothamMedium,
}, panel)
local stopButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 32),
	Size = UDim2.fromOffset(72, 28),
	BackgroundColor3 = COLORS.card,
	Text = "⏹ 멈추기",
	TextColor3 = COLORS.text,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
}, panel)
corner(stopButton, 8)

-- Tempo
local tempoRow = create("Frame", {
	Position = UDim2.fromOffset(0, 66),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
}, panel)
create("TextLabel", {
	Size = UDim2.fromOffset(40, 30),
	BackgroundTransparency = 1,
	Text = "템포",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, tempoRow)
local minusButton = create("TextButton", {
	Position = UDim2.fromOffset(40, 2),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = COLORS.card,
	Text = "−",
	TextColor3 = COLORS.text,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, tempoRow)
corner(minusButton, 13)
local bar = create("Frame", {
	Position = UDim2.new(0, 74, 0.5, -3),
	Size = UDim2.new(1, -74 - 34 - 52, 0, 6),
	BackgroundColor3 = COLORS.card,
}, tempoRow)
corner(bar, 3)
local fill = create("Frame", {
	Size = UDim2.fromScale(0.33, 1),
	BackgroundColor3 = COLORS.accent,
}, bar)
corner(fill, 3)
local knob = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.33, 0.5),
	Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = COLORS.text,
}, bar)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
local plusButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -52, 0, 2),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = COLORS.card,
	Text = "+",
	TextColor3 = COLORS.text,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, tempoRow)
corner(plusButton, 13)
local tempoLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(46, 30),
	BackgroundTransparency = 1,
	Text = "1.0x",
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, tempoRow)

-- Category tabs
local tabRow = create("Frame", {
	Position = UDim2.fromOffset(0, 102),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
}, tabRow)

-- Dance grid
local grid = create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 136),
	Size = UDim2.new(1, 0, 1, -136 - 150),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
create("UIGridLayout", {
	CellSize = UDim2.new(0.5, -4, 0, 34),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

-- 같이 추기
local joinHeader = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -118),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Text = "같이 추기 · 근처에서 춤추는 사람",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.join,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, panel)
local joinList = create("ScrollingFrame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 114),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, joinList)
local joinEmpty = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "근처에서 춤추는 사람이 없어요",
	TextColor3 = COLORS.sub,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
}, joinList)

-- Now playing banner (shown near the club)
local banner = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(320, 30),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.35,
	Text = "",
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
corner(banner, 15)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, banner)

local function layoutPanel()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local top = math.max(GuiService.TopbarInset.Max.Y, 36) + 8
	local width = math.clamp(math.floor(viewport.X * 0.3), 250, 330)
	-- Leave the bottom-left free for the touch thumbstick.
	local bottomFree = if UserInputService.TouchEnabled then 150 else 24
	local height = math.clamp(viewport.Y - top - bottomFree, 300, 560)
	panel.Position = UDim2.fromOffset(12, top)
	panel.Size = UDim2.fromOffset(width, height)
	banner.Position = UDim2.new(0.5, 0, 0, top - 4)
end
layoutPanel()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutPanel)
end

--------------------------------------------------
-- Dance state (local view)
--------------------------------------------------

local tempo = 1.0
local selectedCategory = ClubConfig.Categories[1]
local danceButtons: {[string]: TextButton} = {}
local animations: {[string]: Animation} = {}
local current: { key: string?, track: AnimationTrack?, start: number?, speed: number? } = {}
local stopSent = false

local function animationFor(key: string): Animation?
	local dance = ClubConfig.findDance(key)
	if not dance then return nil end
	local animation = animations[key]
	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(dance.animationId)
		animations[key] = animation
	end
	return animation
end

local function myCharacter(): (Model?, Humanoid?, Animator?)
	local character = player.Character
	if not character then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	return character, humanoid, animator
end

local function stopTrack()
	if current.track then
		current.track:Stop(0.2)
		current.track:Destroy()
	end
	current.track = nil
	current.key = nil
end

local function requestStop()
	if stopSent then return end
	stopSent = true
	stopTrack()
	danceRemote:FireServer("Stop")
end

local function refreshButtons()
	for key, button in pairs(danceButtons) do
		local active = current.key == key
		button.BackgroundColor3 = if active then COLORS.cardActive else COLORS.card
	end
	local dance = current.key and ClubConfig.findDance(current.key)
	if dance then
		local character = player.Character
		local joined = character and character:GetAttribute("DanceJoined")
		local joinedPlayer = typeof(joined) == "number" and Players:GetPlayerByUserId(joined)
		nowLabel.Text = if joinedPlayer
			then "♪ " .. dance.name .. " · " .. joinedPlayer.DisplayName .. "님과 함께"
			else "♪ " .. dance.name .. " 추는 중"
		nowLabel.TextColor3 = COLORS.text
	else
		nowLabel.Text = "춤을 고르세요"
		nowLabel.TextColor3 = COLORS.sub
	end
end

-- Plays whatever the character attributes say, at the shared frame.
local function applyDance()
	local character, _, animator = myCharacter()
	if not character or not animator then return end
	local key = character:GetAttribute("DanceKey")
	local start = character:GetAttribute("DanceStart")
	local speed = character:GetAttribute("DanceSpeed")
	if typeof(key) ~= "string" or typeof(start) ~= "number" or typeof(speed) ~= "number" then
		stopTrack()
		stopSent = false
		refreshButtons()
		return
	end
	local dance = ClubConfig.findDance(key)
	if not dance then return end
	stopSent = false
	if current.key ~= key or not current.track then
		stopTrack()
		local animation = animationFor(key)
		if not animation then return end
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not track then
			warn("[DanceController] Could not load dance", key, track)
			return
		end
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = dance.looped
		current.key = key
		current.track = track
		track:Play(0.2)
		if not dance.looped then
			track.Stopped:Connect(function()
				if current.track == track then
					requestStop()
				end
			end)
		end
	end
	local track = current.track :: AnimationTrack
	current.start = start
	current.speed = speed
	track:AdjustSpeed(speed)
	-- Align to the shared clock (needed for 같이 추기 and tempo changes).
	task.spawn(function()
		local waited = 0
		while track.Length == 0 and waited < 3 do
			task.wait(0.05)
			waited += 0.05
		end
		if current.track ~= track or track.Length == 0 then return end
		local elapsed = math.max(0, workspace:GetServerTimeNow() - start) * speed
		if dance.looped then
			track.TimePosition = elapsed % track.Length
		elseif elapsed < track.Length then
			track.TimePosition = elapsed
		end
	end)
	refreshButtons()
end

local characterConnections: {RBXScriptConnection} = {}
local function watchCharacter(character: Model)
	for _, connection in ipairs(characterConnections) do connection:Disconnect() end
	table.clear(characterConnections)
	current.track = nil
	current.key = nil
	stopSent = false
	for _, name in ipairs({ "DanceKey", "DanceStart", "DanceSpeed", "DanceJoined" }) do
		table.insert(characterConnections, character:GetAttributeChangedSignal(name):Connect(function()
			-- Attributes arrive one by one; apply once after the batch.
			task.defer(applyDance)
		end))
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		table.insert(characterConnections, humanoid.Seated:Connect(function(active)
			if active and current.track then requestStop() end
		end))
		table.insert(characterConnections, humanoid.Died:Connect(stopTrack))
	end
	refreshButtons()
end
if player.Character then task.spawn(watchCharacter, player.Character) end
player.CharacterAdded:Connect(watchCharacter)

-- Moving or jumping ends the dance (like real emotes).
local movingFor = 0
RunService.Heartbeat:Connect(function(dt)
	if not current.track then
		movingFor = 0
		return
	end
	local _, humanoid = myCharacter()
	if not humanoid then return end
	local moving = humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump
	movingFor = if moving then movingFor + dt else 0
	if movingFor > 0.12 then
		movingFor = 0
		requestStop()
	end
end)

--------------------------------------------------
-- Panel content
--------------------------------------------------

local function setTempo(value: number, send: boolean)
	tempo = ClubConfig.clampTempo(value)
	local alpha = (tempo - ClubConfig.TempoMin) / (ClubConfig.TempoMax - ClubConfig.TempoMin)
	fill.Size = UDim2.fromScale(alpha, 1)
	knob.Position = UDim2.fromScale(alpha, 0.5)
	tempoLabel.Text = string.format("%.1fx", tempo)
	if send and current.key then
		danceRemote:FireServer("Speed", tempo)
	end
end
setTempo(1, false)

local function startDance(key: string)
	if current.key == key then
		requestStop()
		return
	end
	stopSent = false
	danceRemote:FireServer("Start", key, tempo)
end

local function renderGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	table.clear(danceButtons)
	for index, dance in ipairs(ClubConfig.Dances) do
		if dance.category == selectedCategory then
			local button = create("TextButton", {
				Name = dance.key,
				LayoutOrder = index,
				BackgroundColor3 = COLORS.card,
				Text = dance.name,
				TextColor3 = COLORS.text,
				TextSize = 14,
				TextWrapped = true,
				Font = Enum.Font.GothamBold,
			}, grid)
			corner(button, 8)
			button.MouseButton1Click:Connect(function()
				startDance(dance.key)
			end)
			danceButtons[dance.key] = button
		end
	end
	refreshButtons()
end

local tabButtons: {[string]: TextButton} = {}
for index, category in ipairs(ClubConfig.Categories) do
	local tab = create("TextButton", {
		LayoutOrder = index,
		Size = UDim2.fromOffset(96, 28),
		BackgroundColor3 = COLORS.card,
		Text = category,
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	}, tabRow)
	corner(tab, 14)
	tabButtons[category] = tab
	tab.MouseButton1Click:Connect(function()
		selectedCategory = category
		for name, button in pairs(tabButtons) do
			button.BackgroundColor3 = if name == category then COLORS.accent else COLORS.card
		end
		renderGrid()
	end)
end
tabButtons[selectedCategory].BackgroundColor3 = COLORS.accent
renderGrid()

-- Tempo slider: drag on the bar or knob; −/+ for touch precision.
local dragging = false
local function tempoFromX(x: number)
	local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
	setTempo(ClubConfig.TempoMin + alpha * (ClubConfig.TempoMax - ClubConfig.TempoMin), false)
end
local function beginDrag(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		tempoFromX(input.Position.X)
	end
end
bar.InputBegan:Connect(beginDrag)
knob.InputBegan:Connect(beginDrag)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		tempoFromX(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = false
		setTempo(tempo, true)
	end
end)
minusButton.MouseButton1Click:Connect(function() setTempo(tempo - ClubConfig.TempoStep, true) end)
plusButton.MouseButton1Click:Connect(function() setTempo(tempo + ClubConfig.TempoStep, true) end)

stopButton.MouseButton1Click:Connect(function()
	if current.key then requestStop() end
end)

-- 같이 추기 list
local function renderJoinList()
	for _, child in ipairs(joinList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local _, myHumanoid = myCharacter()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not myRoot or not myHumanoid then
		joinEmpty.Visible = true
		return
	end
	local myJoined = player.Character and player.Character:GetAttribute("DanceJoined")
	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local key = character and character:GetAttribute("DanceKey")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local dance = ClubConfig.findDance(key)
		if other ~= player and dance and root and (root.Position - myRoot.Position).Magnitude <= ClubConfig.JoinRadius then
			count += 1
			local row = create("Frame", {
				LayoutOrder = count,
				Size = UDim2.new(1, -6, 0, 34),
				BackgroundColor3 = COLORS.card,
			}, joinList)
			corner(row, 8)
			create("TextLabel", {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -96, 1, 0),
				BackgroundTransparency = 1,
				Text = other.DisplayName .. " · " .. dance.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = COLORS.text,
				TextSize = 13,
				Font = Enum.Font.GothamMedium,
			}, row)
			local together = myJoined == other.UserId and current.key == dance.key
			local button = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.fromOffset(84, 26),
				BackgroundColor3 = if together then COLORS.card else COLORS.join,
				Text = if together then "함께 추는 중" else "같이 추기",
				TextColor3 = COLORS.text,
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = not together,
			}, row)
			corner(button, 13)
			if not together then
				button.MouseButton1Click:Connect(function()
					stopSent = false
					danceRemote:FireServer("Join", other.UserId)
				end)
			end
		end
	end
	joinEmpty.Visible = count == 0
end

local preloaded = false
local function setPanelOpen(open: boolean)
	panel.Visible = open
	danceButton.BackgroundColor3 = if open then COLORS.accent else Color3.fromRGB(0, 0, 0)
	if open then
		layoutPanel()
		renderJoinList()
		if not preloaded then
			preloaded = true
			local list = {}
			for _, dance in ipairs(ClubConfig.Dances) do
				local animation = animationFor(dance.key)
				if animation then table.insert(list, animation) end
			end
			task.spawn(function()
				pcall(function() ContentProvider:PreloadAsync(list) end)
			end)
		end
	end
end
danceButton.MouseButton1Click:Connect(function() setPanelOpen(not panel.Visible) end)
closeButton.MouseButton1Click:Connect(function() setPanelOpen(false) end)

task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible then renderJoinList() end
	end
end)

--------------------------------------------------
-- Club music
--------------------------------------------------

local music = create("Sound", {
	Name = "ClubMusic",
	Volume = 0,
	Looped = false,
}, script)
local currentTrack = 0

local function syncMusic()
	local index = FashionGame:GetAttribute("ClubTrack")
	local start = FashionGame:GetAttribute("ClubTrackStart")
	if typeof(index) ~= "number" or typeof(start) ~= "number" then return end
	local track = ClubConfig.Playlist[index]
	if not track then return end
	if currentTrack ~= index then
		currentTrack = index
		music:Stop()
		music.SoundId = "rbxassetid://" .. tostring(track.soundId)
	end
	if not music.IsLoaded then
		music.Loaded:Wait()
	end
	if currentTrack ~= index then return end
	music.TimePosition = math.clamp(workspace:GetServerTimeNow() - start, 0, math.max(music.TimeLength - 0.5, 0))
	if not music.IsPlaying then music:Play() end
	banner.Text = "♪ NOW PLAYING · " .. track.channel .. " · " .. track.title
end
FashionGame:GetAttributeChangedSignal("ClubTrack"):Connect(function() task.spawn(syncMusic) end)
FashionGame:GetAttributeChangedSignal("ClubTrackStart"):Connect(function() task.spawn(syncMusic) end)
task.spawn(syncMusic)

local function distanceToZone(position: Vector3): number
	local best = math.huge
	for _, zone in ipairs(CollectionService:GetTagged("ClubZone")) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			local outside = Vector3.new(
				math.max(math.abs(p.X) - half.X, 0),
				math.max(math.abs(p.Y) - half.Y, 0),
				math.max(math.abs(p.Z) - half.Z, 0)
			)
			best = math.min(best, outside.Magnitude)
		end
	end
	return best
end

-- Beat lights: parts tagged "ClubBeat" brighten with the music loudness.
local beatBase: {[BasePart]: Color3} = {}
local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	local camera = workspace.CurrentCamera
	if accumulator >= 0.2 and camera then
		accumulator = 0
		local focus = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local position = if focus then focus.Position else camera.CFrame.Position
		local distance = distanceToZone(position)
		local level = math.clamp(1 - distance / ClubConfig.FadeDistance, 0, 1)
		music.Volume = ClubConfig.MusicVolume * level
		banner.Visible = level > 0 and banner.Text ~= ""
	end
	if music.Volume > 0 then
		local pulse = math.clamp(music.PlaybackLoudness / 500, 0, 1)
		for _, part in ipairs(CollectionService:GetTagged("ClubBeat")) do
			if part:IsA("BasePart") then
				local base = beatBase[part]
				if not base then
					base = part.Color
					beatBase[part] = base
				end
				part.Color = base:Lerp(Color3.new(1, 1, 1), pulse * 0.45)
			end
		end
	end
end)
