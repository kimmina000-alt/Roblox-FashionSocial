--!strict
-- Club client: dance panel, dance playback, 같이 추기 (sync), club music.
--
-- The server owns the dance state (character attributes DanceKey / DanceStart /
-- DanceSpeed / DanceJoined, see ClubService). This script only plays what
-- those attributes say on the local character; Animator replication shows it
-- to everyone. Moving and jumping keep the dance going (user, 2026-10-20);
-- 멈추기, sitting, or leaving the club ends it.
--
-- 같이 추기 (MIDNIGHT PLAZA reference, 2026-10-20): tap/click another player in
-- the club → their card → [같이 추기]. While synced you follow their dance AND
-- tempo, including every change they make; the top pill shows who you follow
-- and has [해제] (→ stop and wait). Picking your own dance or touching the
-- tempo turns it into your own dance. The DJ also sees [DJ 존 초대] on cards.
-- The panel's "같이 추기" tab lists nearby players for the same thing.
--
-- The 💃 button shows everywhere (user 2026-10-26; outside the club only the
-- dancers themselves hear the music). Music is one
-- shared playlist clock (FashionGame attributes ClubTrack / ClubTrackStart),
-- played locally with volume by distance to parts tagged "ClubZone".

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
local musicRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Music") :: RemoteFunction
local HttpService = game:GetService("HttpService")

-- DJ zone guests (ClubDJGuests attribute, JSON list of userIds).
local function isGuest(userId: number): boolean
	local raw = FashionGame:GetAttribute("ClubDJGuests")
	if typeof(raw) ~= "string" then return false end
	local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and typeof(list) == "table" and table.find(list, userId) ~= nil
end

local COLORS = {
	panel = Color3.fromRGB(18, 18, 24),
	card = Color3.fromRGB(38, 38, 50),
	cardActive = Color3.fromRGB(255, 80, 200),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	accent = Color3.fromRGB(255, 80, 200),
	join = Color3.fromRGB(80, 200, 255),
}

local JOIN_TAB = "같이 추기"

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

local function label(props: {[string]: any}, parent: Instance): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.Font = props.Font or Enum.Font.GothamBold
	return create("TextLabel", props, parent)
end

local function button(props: {[string]: any}, parent: Instance, radius: number?): TextButton
	props.BackgroundColor3 = props.BackgroundColor3 or COLORS.card
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.Font = props.Font or Enum.Font.GothamBold
	local instance = create("TextButton", props, parent)
	corner(instance, radius or 8)
	return instance
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
	Text = "🎵", -- (a note instead of 💃, user 2026-10-30)
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.text,
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, danceButton)

-- In the top bar's left group (TopBar.lua has the order), a white note icon (user mock-up 2026-10-30).
require(script.Parent:WaitForChild("TopBar")).icon(danceButton, require(script.Parent:WaitForChild("Icons")).note, 0.56)
require(script.Parent:WaitForChild("TopBar")).add(danceButton, 1)

local panel = create("Frame", {
	Name = "DancePanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.12,
	Active = true,
	Visible = false,
}, gui)
corner(panel, 15)
create("UIPadding", {
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}, panel)

-- Row 1: title · now dancing · 멈추기 · X (one row so phones keep room for the list)
label({
	Name = "Header",
	Size = UDim2.fromOffset(34, 28),
	Text = "춤",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 20,
}, panel)
local nowLabel = label({
	Name = "NowLabel",
	Position = UDim2.fromOffset(34, 0),
	Size = UDim2.new(1, -34 - 76 - 34, 0, 28),
	Text = "춤을 고르세요",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.sub,
	TextSize = 14,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Font = Enum.Font.GothamMedium,
}, panel)
local stopButton = button({
	Name = "StopButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -34, 0, 0),
	Size = UDim2.fromOffset(72, 28),
	Text = "■ 멈추기",
	TextSize = 14,
}, panel)
local closeButton = button({
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(28, 28),
	-- "✕" renders as an empty box in the Roblox font; plain X is safe.
	Text = "X",
	TextSize = 15,
}, panel, 14)

-- Row 2: tempo
local tempoRow = create("Frame", {
	Name = "TempoRow",
	Position = UDim2.fromOffset(0, 34),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
}, panel)
label({
	Size = UDim2.fromOffset(40, 28),
	Text = "템포",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 15,
}, tempoRow)
local minusButton = button({
	Name = "TempoMinus",
	Position = UDim2.fromOffset(40, 1),
	Size = UDim2.fromOffset(26, 26),
	Text = "−",
	TextSize = 18,
}, tempoRow, 13)
local bar = create("Frame", {
	Name = "TempoBar",
	Position = UDim2.new(0, 74, 0.5, -3),
	Size = UDim2.new(1, -74 - 34 - 50, 0, 6),
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
	Size = UDim2.fromOffset(20, 20),
	BackgroundColor3 = COLORS.text,
}, bar)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
local plusButton = button({
	Name = "TempoPlus",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -50, 0, 1),
	Size = UDim2.fromOffset(26, 26),
	Text = "+",
	TextSize = 18,
}, tempoRow, 13)
local tempoLabel = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(44, 28),
	Text = "1.0x",
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 15,
}, tempoRow)

-- Row 3: tabs (댄스 / 포즈·응원 / 같이 추기)
local tabRow = create("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(0, 68),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabRow)

-- Content area: the dance grid, or the 같이 추기 list (same place).
local CONTENT_TOP = 102
local grid = create("ScrollingFrame", {
	Name = "DanceGrid",
	Position = UDim2.fromOffset(0, CONTENT_TOP),
	Size = UDim2.new(1, 0, 1, -CONTENT_TOP),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
local gridLayout = create("UIGridLayout", {
	CellSize = UDim2.new(0.5, -4, 0, 36),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

local joinList = create("ScrollingFrame", {
	Name = "JoinList",
	Position = UDim2.fromOffset(0, CONTENT_TOP),
	Size = UDim2.new(1, 0, 1, -CONTENT_TOP),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Visible = false,
}, panel)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, joinList)
local joinHint = label({
	Name = "Hint",
	LayoutOrder = 0,
	Size = UDim2.new(1, -6, 0, 34),
	Text = "근처 사람을 눌러 같이 추기 · 화면에서 사람을 직접 눌러도 돼요",
	TextColor3 = COLORS.join,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamMedium,
}, joinList)
local joinEmpty = label({
	Name = "Empty",
	LayoutOrder = 9999,
	Size = UDim2.new(1, 0, 0, 30),
	Text = "근처에 다른 사람이 없어요",
	TextColor3 = COLORS.sub,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
}, joinList)

-- Now playing banner (shown near the club)
local banner = label({
	Name = "NowPlaying",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(340, 30),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.35,
	Text = "",
	TextSize = 13,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Visible = false,
}, gui)
corner(banner, 15)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, banner)

-- 같이 추기 status pill (under the banner while synced)
local syncPill = create("Frame", {
	Name = "SyncPill",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(330, 34),
	BackgroundColor3 = Color3.fromRGB(10, 40, 60),
	BackgroundTransparency = 0.1,
	Active = true,
	Visible = false,
}, gui)
corner(syncPill, 17)
create("UIStroke", { Color = COLORS.join, Thickness = 1.5 }, syncPill)
local syncText = label({
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -84, 1, 0),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextSize = 13,
}, syncPill)
local syncLeave = button({
	Name = "LeaveSync",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -4, 0.5, 0),
	Size = UDim2.fromOffset(64, 26),
	BackgroundColor3 = COLORS.join,
	Text = "해제",
	TextSize = 14,
}, syncPill, 13)

-- Player card (tap/click a player in the club)
local playerCard = create("Frame", {
	Name = "PlayerCard",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(290, 124),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.06,
	Active = true,
	Visible = false,
	ZIndex = 5,
}, gui)
corner(playerCard, 14)
create("UIStroke", { Color = COLORS.join, Thickness = 1.5 }, playerCard)
local cardPhoto = create("ImageLabel", {
	Name = "Photo",
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(60, 60),
	BackgroundColor3 = COLORS.card,
	Image = "",
	ZIndex = 6,
}, playerCard)
corner(cardPhoto, 30)
local cardName = label({
	Position = UDim2.fromOffset(80, 10),
	Size = UDim2.new(1, -120, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextSize = 17,
	ZIndex = 6,
}, playerCard)
local cardUser = label({
	Position = UDim2.fromOffset(80, 32),
	Size = UDim2.new(1, -90, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = COLORS.sub,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
	ZIndex = 6,
}, playerCard)
local cardDance = label({
	Position = UDim2.fromOffset(80, 50),
	Size = UDim2.new(1, -90, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = COLORS.join,
	TextSize = 13,
	ZIndex = 6,
}, playerCard)
local cardClose = button({
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(28, 28),
	Text = "X",
	TextSize = 14,
	ZIndex = 6,
}, playerCard, 14)
local cardJoin = button({
	Name = "JoinButton",
	Position = UDim2.fromOffset(10, 78),
	Size = UDim2.new(1, -20, 0, 36),
	BackgroundColor3 = COLORS.join,
	Text = "💃 같이 추기",
	TextSize = 16,
	ZIndex = 6,
}, playerCard, 10)
-- Only the current DJ sees this: DJ zone guests (D-061).
local cardInvite = button({
	Name = "InviteButton",
	Position = UDim2.fromOffset(10, 120),
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundColor3 = Color3.fromRGB(0, 140, 120),
	Text = "🎧 DJ 존 초대",
	TextSize = 15,
	ZIndex = 6,
	Visible = false,
}, playerCard, 10)

-- Only a guard sees this (D-623): show the player out of the club for a minute.
local cardGuard = button({
	Name = "GuardOutButton",
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundColor3 = Color3.fromRGB(20, 20, 24),
	Text = "🛡 클럽 밖으로 안내",
	TextSize = 15,
	ZIndex = 6,
	Visible = false,
}, playerCard, 10)
create("UIStroke", { Color = Color3.fromRGB(220, 20, 35), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cardGuard)

local function topY(): number
	return require(script.Parent:WaitForChild("TopBar")).bottom() + 6
end

local function layoutPanel()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local top = topY()
	local width = math.clamp(math.floor(viewport.X * 0.36), 240, 330)
	-- On the left edge (user 2026-10-26: it sat oddly in the middle). With the
	-- move stick on screen the panel ends above it (bottom 40 % free) and its
	-- list scrolls, so players can still walk while it is open.
	local touchGui = player:WaitForChild("PlayerGui"):FindFirstChild("TouchGui")
	local stick = touchGui ~= nil and touchGui:IsA("ScreenGui") and touchGui.Enabled
	local height = if stick
		then math.clamp(viewport.Y * 0.6 - top, 160, 560)
		else math.clamp(viewport.Y - top - 10, 200, 560)
	local leftX = 10
	panel.Position = UDim2.fromOffset(leftX, top)
	panel.Size = UDim2.fromOffset(width, height)
	-- Short screens: slightly smaller dance buttons so more fit.
	gridLayout.CellSize = UDim2.new(0.5, -4, 0, if viewport.Y < 450 then 32 else 36)
	-- Banner, sync pill and player card sit between the open panel and the
	-- top-right buttons (🎵 💃 C); centred on screen when there is room.
	local leftEdge = if panel.Visible then leftX + width + 10 else 10
	local rightEdge = viewport.X - 180
	local function place(item: GuiObject, wanted: number, y: number)
		local w = math.max(math.min(wanted, rightEdge - leftEdge), 160)
		local centerX = viewport.X / 2
		if centerX - w / 2 < leftEdge or centerX + w / 2 > rightEdge then
			centerX = (leftEdge + rightEdge) / 2
		end
		item.Position = UDim2.fromOffset(centerX, y)
		item.Size = UDim2.fromOffset(w, item.Size.Y.Offset)
	end
	place(banner, 340, top - 2)
	place(syncPill, 330, top + 32)
	place(playerCard, 290, top + 70)
end
layoutPanel()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutPanel)
end

--------------------------------------------------
-- Dance state (local view)
--------------------------------------------------

local tempo = 1.0
local selectedTab = ClubConfig.Categories[1]
local danceButtons: {[string]: TextButton} = {}
local animations: {[string]: Animation} = {}
local current: { key: string?, track: AnimationTrack?, start: number?, speed: number? } = {}
local stopSent = false
local dragging = false

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

local function rootOf(character: Model?): BasePart?
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inClub(character: Model?): boolean
	local root = rootOf(character)
	return root ~= nil and ClubConfig.isInClub(root.Position)
end

local function joinedPlayer(): Player?
	local character = player.Character
	local joined = character and character:GetAttribute("DanceJoined")
	return if typeof(joined) == "number" then Players:GetPlayerByUserId(joined) else nil
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

local function refreshSync()
	local leader = joinedPlayer()
	syncPill.Visible = leader ~= nil
	if leader then
		local dance = current.key and ClubConfig.findDance(current.key)
		syncText.Text = if dance
			then string.format("🔗 %s님과 같이 추기 · %s %.1fx", leader.DisplayName, dance.name, tempo)
			else string.format("🔗 %s님과 같이 추기 · 상대가 쉬는 중", leader.DisplayName)
	end
end

local function refreshButtons()
	for key, danceBtn in pairs(danceButtons) do
		danceBtn.BackgroundColor3 = if current.key == key then COLORS.cardActive else COLORS.card
	end
	local dance = current.key and ClubConfig.findDance(current.key)
	local leader = joinedPlayer()
	if dance then
		nowLabel.Text = if leader
			then "♪ " .. dance.name .. " · " .. leader.DisplayName .. "님과"
			else "♪ " .. dance.name
		nowLabel.TextColor3 = COLORS.text
	elseif leader then
		nowLabel.Text = leader.DisplayName .. "님 기다리는 중"
		nowLabel.TextColor3 = COLORS.join
	else
		nowLabel.Text = "춤을 고르세요"
		nowLabel.TextColor3 = COLORS.sub
	end
	refreshSync()
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
				if current.track ~= track then return end
				-- A synced one-shot ends with the leader's Stop; keep the link.
				if joinedPlayer() then stopTrack() refreshButtons() else requestStop() end
			end)
		end
	end
	local track = current.track :: AnimationTrack
	current.start = start
	current.speed = speed
	-- DancePause: frozen at that clip time (인생네컷 ⏸).
	local paused = character:GetAttribute("DancePause")
	track:AdjustSpeed(if typeof(paused) == "number" then 0 else speed)
	-- The slider shows the tempo actually danced (a leader's while synced).
	if not dragging then setTempo(speed, false) end
	-- Align to the shared clock (needed for 같이 추기 and tempo changes).
	task.spawn(function()
		local waited = 0
		while track.Length == 0 and waited < 3 do
			task.wait(0.05)
			waited += 0.05
		end
		if current.track ~= track or track.Length == 0 then return end
		local elapsed = if typeof(paused) == "number" then paused else math.max(0, workspace:GetServerTimeNow() - start) * speed
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
	for _, name in ipairs({ "DanceKey", "DanceStart", "DanceSpeed", "DanceJoined", "DancePause" }) do
		table.insert(characterConnections, character:GetAttributeChangedSignal(name):Connect(function()
			-- Attributes arrive one by one; apply once after the batch.
			task.defer(applyDance)
		end))
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		table.insert(characterConnections, humanoid.Seated:Connect(function(active)
			if active and (current.track or joinedPlayer()) then requestStop() end
		end))
		table.insert(characterConnections, humanoid.Died:Connect(stopTrack))
	end
	refreshButtons()
end
if player.Character then task.spawn(watchCharacter, player.Character) end
player.CharacterAdded:Connect(watchCharacter)

--------------------------------------------------
-- Panel content
--------------------------------------------------

local function startDance(key: string)
	-- Tapping the dance you are doing on your own stops it; while synced it
	-- becomes your own dance instead.
	if current.key == key and not joinedPlayer() then
		requestStop()
		return
	end
	stopSent = false
	danceRemote:FireServer("Start", key, tempo)
end

local function joinPlayer(target: Player)
	stopSent = false
	danceRemote:FireServer("Join", target.UserId)
end

local function leaveSync()
	danceRemote:FireServer("Leave")
end

local function renderGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	table.clear(danceButtons)
	for index, dance in ipairs(ClubConfig.Dances) do
		if dance.category == selectedTab then
			local danceBtn = button({
				Name = dance.key,
				LayoutOrder = index,
				Text = dance.name,
				TextSize = 15,
				TextWrapped = true,
			}, grid)
			danceBtn.MouseButton1Click:Connect(function()
				startDance(dance.key)
			end)
			danceButtons[dance.key] = danceBtn
		end
	end
	refreshButtons()
end

-- 같이 추기 list: everyone nearby in the club (dancing or not); outside the
-- club, the people nearby who are dancing.
local function renderJoinList()
	for _, child in ipairs(joinList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local myRoot = rootOf(player.Character)
	local leader = joinedPlayer()
	local rows = {}
	if myRoot then
		for _, other in ipairs(Players:GetPlayers()) do
			local root = rootOf(other.Character)
			if other ~= player and root and (ClubConfig.isInClub(root.Position) or other.Character:GetAttribute("DanceKey") ~= nil) then
				local distance = (root.Position - myRoot.Position).Magnitude
				if distance <= ClubConfig.JoinRadius then
					table.insert(rows, { player = other, distance = distance })
				end
			end
		end
	end
	table.sort(rows, function(a, b) return a.distance < b.distance end)
	for index, entry in ipairs(rows) do
		local other = entry.player :: Player
		local dance = ClubConfig.findDance(other.Character and other.Character:GetAttribute("DanceKey"))
		local row = create("Frame", {
			Name = "Join_" .. other.Name,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 36),
			BackgroundColor3 = COLORS.card,
		}, joinList)
		corner(row, 8)
		label({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -96, 1, 0),
			Text = other.DisplayName .. " · " .. (if dance then dance.name else "쉬는 중"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, row)
		local together = leader == other
		local rowButton = button({
			Name = "JoinButton",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(84, 28),
			BackgroundColor3 = if together then COLORS.accent else COLORS.join,
			Text = if together then "해제" else "같이 추기",
			TextSize = 14,
		}, row, 14)
		rowButton.MouseButton1Click:Connect(function()
			if together then leaveSync() else joinPlayer(other) end
		end)
	end
	joinEmpty.Visible = #rows == 0
end

local tabButtons: {[string]: TextButton} = {}
local function selectTab(name: string)
	selectedTab = name
	for tabName, tab in pairs(tabButtons) do
		tab.BackgroundColor3 = if tabName == name
			then (if name == JOIN_TAB then COLORS.join else COLORS.accent)
			else COLORS.card
	end
	local joinTab = name == JOIN_TAB
	grid.Visible = not joinTab
	joinList.Visible = joinTab
	if joinTab then renderJoinList() else renderGrid() end
end

local tabNames = table.clone(ClubConfig.Categories)
table.insert(tabNames, JOIN_TAB)
for index, name in ipairs(tabNames) do
	local tab = button({
		Name = "Tab_" .. name,
		LayoutOrder = index,
		Size = UDim2.new(1 / #tabNames, -4, 1, 0),
		Text = name,
		TextSize = 14,
	}, tabRow, 14)
	tabButtons[name] = tab
	tab.MouseButton1Click:Connect(function() selectTab(name) end)
end
selectTab(selectedTab)

-- Tempo slider: drag on the bar or knob; −/+ for touch precision.
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
	if current.key or joinedPlayer() then requestStop() end
end)
syncLeave.MouseButton1Click:Connect(leaveSync)

local preloaded = false
local Popups = require(script.Parent:WaitForChild("Popups"))
local function setPanelOpen(open: boolean)
	panel.Visible = open
	danceButton.BackgroundColor3 = if open then COLORS.accent else Color3.fromRGB(0, 0, 0)
	layoutPanel()
	if not open then Popups.closed("Dance") end
	if open then
		Popups.opened("Dance", function() setPanelOpen(false) end)
		if selectedTab == JOIN_TAB then renderJoinList() end
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

--------------------------------------------------
-- Player card: tap/click another player in the club
--------------------------------------------------

local cardTarget: Player? = nil
local cardHighlight = create("Highlight", {
	Name = "DanceTargetHighlight",
	FillTransparency = 1,
	OutlineColor = COLORS.join,
	OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.Occluded,
})

local function closeCard()
	cardTarget = nil
	playerCard.Visible = false
	cardHighlight.Parent = nil
	Popups.closed("PlayerCard")
end

local function refreshCard()
	local target = cardTarget
	if not target then return end
	local character = target.Character
	if not target.Parent or not character or not inClub(character) or not inClub(player.Character) then
		closeCard()
		return
	end
	local dance = ClubConfig.findDance(character:GetAttribute("DanceKey"))
	local speed = character:GetAttribute("DanceSpeed")
	cardDance.Text = if dance
		then string.format("♪ %s · %.1fx", dance.name, if typeof(speed) == "number" then speed else 1)
		else "지금은 춤을 쉬는 중"
	local together = joinedPlayer() == target
	cardJoin.Text = if together then "같이 추기 해제" else "💃 같이 추기"
	cardJoin.BackgroundColor3 = if together then COLORS.accent else COLORS.join
	local amDJ = FashionGame:GetAttribute("ClubDJ") == player.UserId
	cardInvite.Visible = amDJ
	local amGuard = player:GetAttribute("Pass_Guard") == true and target:GetAttribute("Pass_Guard") ~= true
	cardGuard.Visible = amGuard
	cardGuard.Position = UDim2.fromOffset(10, if amDJ then 160 else 120)
	playerCard.Size = UDim2.fromOffset(playerCard.Size.X.Offset, 124 + (if amDJ then 40 else 0) + (if amGuard then 40 else 0))
	if amDJ then
		local invited = isGuest(target.UserId)
		cardInvite.Text = if invited then "DJ 존 초대 취소" else "🎧 DJ 존 초대"
		cardInvite.BackgroundColor3 = if invited then COLORS.card else Color3.fromRGB(0, 140, 120)
	end
	-- Local-only outline on the chosen player.
	if cardHighlight.Parent ~= character then cardHighlight.Parent = character end
end

local function openCard(target: Player)
	cardTarget = target
	cardName.Text = target.DisplayName
	cardUser.Text = "@" .. target.Name
	cardPhoto.Image = ""
	layoutPanel()
	playerCard.Visible = true
	Popups.opened("PlayerCard", closeCard)
	refreshCard()
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and cardTarget == target then cardPhoto.Image = image end
	end)
end

cardClose.MouseButton1Click:Connect(closeCard)
cardInvite.MouseButton1Click:Connect(function()
	local target = cardTarget
	if not target then return end
	local action = if isGuest(target.UserId) then "Uninvite" else "Invite"
	task.spawn(function()
		pcall(function() musicRemote:InvokeServer(action, target.UserId) end)
		refreshCard()
	end)
end)
cardGuard.MouseButton1Click:Connect(function()
	local target = cardTarget
	if not target then return end
	-- (the server tells both sides how it went, as a toast)
	task.spawn(function()
		local ok, okServer = pcall(function()
			return FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop"):InvokeServer("GuardOut", target.UserId)
		end)
		if ok and okServer then closeCard() end
	end)
end)
cardJoin.MouseButton1Click:Connect(function()
	local target = cardTarget
	if not target then return end
	if joinedPlayer() == target then
		leaveSync()
	else
		joinPlayer(target)
	end
	closeCard()
end)

-- Finds the other player under a screen point: exact raycast first, then the
-- nearest body on screen (thin avatars are hard to tap on phones).
local function playerAt(screen: Vector2): Player?
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if result then
		local node: Instance? = result.Instance
		while node and node ~= workspace do
			local owner = Players:GetPlayerFromCharacter(node)
			if owner then return if owner ~= player then owner else nil end
			node = node.Parent
		end
	end
	local best, bestDistance = nil, 36
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = rootOf(character)
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if other ~= player and root and head then
			local a, onA = camera:WorldToScreenPoint(root.Position - Vector3.new(0, 2, 0))
			local b, onB = camera:WorldToScreenPoint(head.Position)
			if (onA or onB) and a.Z < 200 then
				-- Distance from the tap to the body's screen segment.
				local pa, pb = Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y)
				local ab = pb - pa
				local t = if ab.Magnitude > 0 then math.clamp((screen - pa):Dot(ab) / ab:Dot(ab), 0, 1) else 0
				local distance = (screen - (pa + ab * t)).Magnitude
				if distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

-- A tap/click = press and release without dragging the camera.
local presses: {[InputObject]: { position: Vector2, time: number }} = {}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		presses[input] = { position = Vector2.new(input.Position.X, input.Position.Y), time = os.clock() }
	end
end)
UserInputService.InputEnded:Connect(function(input, processed)
	local press = presses[input]
	presses[input] = nil
	if not press or processed then return end
	local position = Vector2.new(input.Position.X, input.Position.Y)
	if (position - press.position).Magnitude > 12 or os.clock() - press.time > 0.45 then return end
	if not inClub(player.Character) then return end
	local target = playerAt(position)
	if target and inClub(target.Character) then
		openCard(target)
	elseif playerCard.Visible then
		closeCard()
	end
end)

--------------------------------------------------
-- Club presence: 💃 only inside the club
--------------------------------------------------

-- (user 2026-10-26: dancing works everywhere now, the 💃 button is always
-- there; player cards and inviting stay a club thing)
danceButton.Visible = true
local wasInClub = false
task.spawn(function()
	while true do
		task.wait(0.25)
		local here = inClub(player.Character)
		if here ~= wasInClub then
			wasInClub = here
			if not here then closeCard() end
		end
		if playerCard.Visible then refreshCard() end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible and selectedTab == JOIN_TAB then renderJoinList() end
		if syncPill.Visible then refreshSync() end
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
-- the DJ's pitch (ClubMusicPitch, user 2026-10-30): the speed (PlaybackSpeed)
-- moves the pitch too, so the shift is pitch / speed. One effect reaches
-- 0.5..2; pitch x2 at speed x0.25 needs x8, so three in a row (0.125..8)
do
	local shifts = {}
	for i = 1, 3 do
		shifts[i] = create("PitchShiftSoundEffect", { Name = "DJPitch" .. i, Octave = 1, Enabled = false, Priority = 4 - i }, music)
	end
	local function syncPitch()
		local pitch = FashionGame:GetAttribute("ClubMusicPitch")
		local speed = FashionGame:GetAttribute("ClubMusicSpeed")
		pitch = if typeof(pitch) == "number" then pitch else 1
		speed = if typeof(speed) == "number" then speed else 1
		-- (a track may carry its own PitchShift octave on top, Track.octave)
		local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
		local own = if track and track.octave then track.octave else 1
		local rest = math.clamp(pitch / speed * own, 0.125, 8)
		for _, shift in ipairs(shifts) do
			local part = math.clamp(rest, 0.5, 2)
			rest /= part
			shift.Octave = part
			shift.Enabled = math.abs(part - 1) > 0.001 -- (off at 1: the effect smears the sound a little)
		end
	end
	FashionGame:GetAttributeChangedSignal("ClubMusicPitch"):Connect(syncPitch)
	FashionGame:GetAttributeChangedSignal("ClubMusicSpeed"):Connect(syncPitch)
	FashionGame:GetAttributeChangedSignal("ClubTrack"):Connect(syncPitch)
	syncPitch()
end

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
	-- (the DJ's playback speed, ClubMusicSpeed: the place in the song runs that much faster)
	-- (times the track's own base speed: three songs play at x0.5, ClubConfig.trackRate)
	local speed = ClubConfig.trackRate(track, FashionGame:GetAttribute("ClubMusicSpeed"))
	music.PlaybackSpeed = speed
	-- the DJ's pause (ClubMusicPaused): stopped where the server says
	if FashionGame:GetAttribute("ClubMusicPaused") == true then
		local at = FashionGame:GetAttribute("ClubMusicPausedAt")
		music:Pause()
		if typeof(at) == "number" then music.TimePosition = math.clamp(at, 0, math.max(music.TimeLength - 0.5, 0)) end
		banner.Text = "⏸ PAUSED · " .. track.channel .. " · " .. track.title
		return
	end
	music.TimePosition = math.clamp((workspace:GetServerTimeNow() - start) * speed, 0, math.max(music.TimeLength - 0.5, 0))
	if not music.IsPlaying then music:Play() end
	banner.Text = "♪ NOW PLAYING · " .. track.channel .. " · " .. track.title
end
FashionGame:GetAttributeChangedSignal("ClubTrack"):Connect(function() task.spawn(syncMusic) end)
FashionGame:GetAttributeChangedSignal("ClubTrackStart"):Connect(function() task.spawn(syncMusic) end)
FashionGame:GetAttributeChangedSignal("ClubMusicSpeed"):Connect(function() task.spawn(syncMusic) end)
FashionGame:GetAttributeChangedSignal("ClubMusicPaused"):Connect(function() task.spawn(syncMusic) end)
task.spawn(syncMusic)

-- 0..1 music level at a position: inside a zone that zone's volume (the
-- quieter rooftop wins over the hall below it); outside, the loudest fade.
local function musicLevel(position: Vector3): number
	local inside: number? = nil
	local outside = 0
	for _, zone in ipairs(CollectionService:GetTagged("ClubZone")) do
		if zone:IsA("BasePart") then
			local zoneVolume = ClubConfig.ZoneVolumes[zone:GetAttribute("Zone") or "Hall"] or 1
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			local distance = Vector3.new(
				math.max(math.abs(p.X) - half.X, 0),
				math.max(math.abs(p.Y) - half.Y, 0),
				math.max(math.abs(p.Z) - half.Z, 0)
			).Magnitude
			if distance == 0 then
				inside = math.min(inside or math.huge, zoneVolume)
			else
				outside = math.max(outside, zoneVolume * math.clamp(1 - distance / ClubConfig.FadeDistance, 0, 1))
			end
		end
	end
	return inside or outside
end

local OUTSIDE_DANCE_LEVEL = 0.6

-- Beat lights: parts tagged "ClubBeat" brighten with the music loudness.
local beatBase: {[BasePart]: Color3} = {}
local accumulator = 0
-- (user 2026-10-28 (4): a pose in the photo booth still played the song) the
-- booth mutes at once, not only on the next 0.2 s update, and the level is
-- worked out on Heartbeat too (RenderStepped stops in a background window and
-- left the last volume playing)
local function boothMute()
	if player.Character and player.Character:GetAttribute("PhotoBooth") ~= nil then
		music.Volume = 0
		banner.Visible = false
	end
end
local function watchBooth(character: Model)
	character:GetAttributeChangedSignal("PhotoBooth"):Connect(boothMute)
	character:GetAttributeChangedSignal("DanceKey"):Connect(boothMute)
end
if player.Character then watchBooth(player.Character) end
player.CharacterAdded:Connect(watchBooth)
RunService.Heartbeat:Connect(boothMute)
RunService.RenderStepped:Connect(function(dt)
	accumulator += dt
	local camera = workspace.CurrentCamera
	if accumulator >= 0.2 and camera then
		accumulator = 0
		local focus = rootOf(player.Character)
		local position = if focus then focus.Position else camera.CFrame.Position
		local level = musicLevel(position)
		-- outside the club only the people dancing hear the music (their own
		-- client plays it; user 2026-10-26)
		if current.key ~= nil then level = math.max(level, OUTSIDE_DANCE_LEVEL) end
		-- poses in the photo booth are dances too, but silent there (user 2026-10-27)
		if player.Character and player.Character:GetAttribute("PhotoBooth") ~= nil then level = 0 end
		-- (a track may set its own volume, ClubConfig Track.volume)
		local playing = ClubConfig.Playlist[currentTrack]
		music.Volume = (if playing and playing.volume then playing.volume else ClubConfig.MusicVolume) * level
		banner.Visible = level > 0 and banner.Text ~= ""
	end
	if music.Volume > 0 then
		local pulse = math.clamp(music.PlaybackLoudness / 500, 0, 1)
		-- The DJ can switch the lights off (attribute ClubLights = false).
		local lightsOff = FashionGame:GetAttribute("ClubLights") == false
		-- DJ colour pick (ClubLightColor): beat lights take the colour
		local picked = ClubConfig.findLightColor(FashionGame:GetAttribute("ClubLightColor"))
		local tint: Color3? = picked and picked.color
		for _, part in ipairs(CollectionService:GetTagged("ClubBeat")) do
			if part:IsA("BasePart") then
				local base = beatBase[part]
				if not base then
					base = part.Color
					beatBase[part] = base
				end
				local lit = if tint then tint else base
				part.Color = if lightsOff then base:Lerp(Color3.new(0, 0, 0), 0.7) else lit:Lerp(Color3.new(1, 1, 1), pulse * 0.45)
			end
		end
	end
end)
