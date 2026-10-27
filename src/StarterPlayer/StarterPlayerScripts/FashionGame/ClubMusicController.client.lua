--!strict
-- Club music panel (client). Opened with the "디제잉하기" prompt (E) at the DJ
-- turntable (user, 2026-10-22: the 🎵 top-bar button is gone). The DJ starts
-- DJing there (DjService.Actions.Djing: DJ spot + hand motion); others see the
-- same window with DJ time to buy / song requests.
-- Phones (short screens): two popups, "디제잉" (controls) on the left edge and
-- "음악" (song list) on the right edge, so the DJ's character in the middle
-- stays visible (user, 2026-10-22).
--   * DJ: 지금 틀기 / 다음 곡 / 건너뛰기, remaining time, 시간 연장, and the DJ
--     console placeholders for future abilities (DJ_SYSTEM.md).
--   * The no-DJ request list below is kept for when requests get their own
--     entry point again (server still accepts "Request").
-- State comes from ReplicatedStorage.FashionGame attributes set by the server
-- (ClubTrack, ClubTrackBy, ClubRequests, ClubDJ, ClubDJUntil, ClubDJQueue).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local Music = Remotes:WaitForChild("Music") :: RemoteFunction
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction

local COLORS = {
	panel = Color3.fromRGB(18, 18, 24),
	card = Color3.fromRGB(38, 38, 50),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	accent = Color3.fromRGB(255, 80, 200),
	dj = Color3.fromRGB(80, 200, 255),
	robux = Color3.fromRGB(0, 176, 111),
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

local gui = create("ScreenGui", {
	Name = "FashionMusicGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 19,
}, playerGui)


local panel = create("Frame", {
	Name = "MusicPanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Visible = false,
}, gui)
corner(panel, 15)
create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, panel)

create("TextLabel", {
	Name = "Header",
	Size = UDim2.new(1, -40, 0, 26),
	BackgroundTransparency = 1,
	Text = "음악",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	TextSize = 22,
	Font = Enum.Font.GothamBold,
}, panel)
local closeButton = create("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = COLORS.card,
	Text = "X",
	TextColor3 = COLORS.text,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
}, panel)
corner(closeButton, 14)

local nowLabel = create("TextLabel", {
	Name = "NowLabel",
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = COLORS.text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
}, panel)

-- DJ status row
local djRow = create("Frame", {
	Name = "DJRow",
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = COLORS.card,
}, panel)
corner(djRow, 10)
local djLabel = create("TextLabel", {
	Name = "DJLabel",
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	TextColor3 = COLORS.dj,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, djRow)
local djButton = create("TextButton", {
	Name = "BecomeDJ",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(104, 30),
	BackgroundColor3 = COLORS.robux,
	Text = string.format("DJ %d분 · R$%d", MonetizationConfig.DJMinutes, MonetizationConfig.Products.DJ.price),
	TextColor3 = COLORS.text,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
}, djRow)
corner(djButton, 15)

-- DJ tools (only for the DJ)
local djTools = create("Frame", {
	Name = "DJTools",
	Position = UDim2.fromOffset(0, 104),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Visible = false,
}, panel)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, djTools)
local djToolCount = 0
local function djToolButton(name: string, text: string, enabled: boolean): TextButton
	djToolCount += 1
	local button = create("TextButton", {
		Name = name,
		LayoutOrder = djToolCount,
		Size = UDim2.new(0.21, -5, 1, 0), -- (the laser group is wider)
		BackgroundColor3 = if enabled then COLORS.dj else COLORS.card,
		Text = text,
		TextColor3 = if enabled then COLORS.text else COLORS.sub,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = enabled,
	}, djTools)
	corner(button, 8)
	create("UITextSizeConstraint", { MaxTextSize = 13 }, button)
	create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, button)
	return button
end
local skipButton = djToolButton("Skip", "⏭ 건너뛰기", true)
-- DJ zone guests (D-061): switches the list below between songs and people.
local guestsButton = djToolButton("Guests", "👥 초대", true)
-- Club lights on-off (DjService.Actions.Lights, attribute ClubLights): the
-- moving heads and beat lights.
local lightsButton = djToolButton("Lights", "💡 조명 ON", true)
-- Lasers on-off with their speed right next to it (user 2026-10-25: lights and
-- lasers switch apart; the speed only changes the lasers, so it sits here).
local laserGroup = create("Frame", {
	Name = "LaserGroup",
	LayoutOrder = djToolCount + 1,
	Size = UDim2.new(0.37, -5, 1, 0),
	BackgroundTransparency = 1,
}, djTools)
djToolCount += 1
local laserButton = create("TextButton", {
	Name = "Lasers",
	Size = UDim2.new(0.62, -2, 1, 0),
	BackgroundColor3 = COLORS.dj,
	Text = "✳ 레이저 ON",
	TextColor3 = COLORS.text,
	TextScaled = true,
	Font = Enum.Font.GothamBold,
}, laserGroup)
corner(laserButton, 8)
create("UITextSizeConstraint", { MaxTextSize = 13 }, laserButton)
create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, laserButton)
-- laser speed (DJ only, DjService.Actions.LightSpeed): tap to cycle x0.5 → … → x5
local LIGHT_SPEEDS = { 0.5, 1, 1.5, 2, 3, 4, 5 } -- (up to x5, user 2026-10-25)
local speedButton = create("TextButton", {
	Name = "LaserSpeed",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.38, -2, 1, 0),
	BackgroundColor3 = Color3.fromRGB(90, 60, 160),
	Text = "⚡x1",
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.text,
}, laserGroup)
corner(speedButton, 8)
create("UITextSizeConstraint", { MaxTextSize = 13 }, speedButton)
-- DJ shown on the big LED screen (DjService.Actions.Screen, attribute
-- ClubDJScreen): next to 시간 연장 in the DJ row (user 2026-10-25)
local screenButton = create("TextButton", {
	Name = "Screen",
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = COLORS.dj,
	Text = "📺 전광판 ON",
	TextColor3 = COLORS.text,
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, djRow)
corner(screenButton, 15)
create("UITextSizeConstraint", { MaxTextSize = 13 }, screenButton)
create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, screenButton)

-- light colours (DJ only): ClubConfig.LightColors swatches
local colorRow = create("Frame", {
	Name = "LightColors",
	BackgroundTransparency = 1,
	Visible = false,
}, panel)
local colorGrid = create("UIGridLayout", { CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }, colorRow)
local colorButtons: {[string]: TextButton} = {}
for index, entry in ipairs(ClubConfig.LightColors) do
	local swatch = entry.color or Color3.fromRGB(60, 60, 75)
	local button = create("TextButton", {
		Name = "Color_" .. entry.key,
		LayoutOrder = index,
		BackgroundColor3 = swatch,
		Text = if entry.color then "" else "🌈",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.text,
	}, colorRow)
	corner(button, 6)
	create("UIStroke", { Name = "Picked", Color = Color3.new(1, 1, 1), Thickness = 2, Enabled = false }, button)
	colorButtons[entry.key] = button
end
-- 🎆 the stage fireworks, free for the DJ (user 2026-10-27; SparkleService
-- "DJColdSpark", once every 90 s), the last cell of the colour row
local djSparkButton = create("TextButton", {
	Name = "DJSpark",
	LayoutOrder = #ClubConfig.LightColors + 1,
	BackgroundColor3 = Color3.fromRGB(255, 150, 40),
	Text = "🎆",
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.text,
}, colorRow)
corner(djSparkButton, 6)

local listTitle = create("TextLabel", {
	Name = "ListTitle",
	Position = UDim2.fromOffset(0, 104),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.sub,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, panel)
local trackList = create("ScrollingFrame", {
	Name = "Tracks",
	Position = UDim2.fromOffset(0, 128),
	Size = UDim2.new(1, 0, 1, -128 - 74),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, trackList)
local queueLabel = create("TextLabel", {
	Name = "QueueLabel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	TextColor3 = COLORS.sub,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
}, panel)

-- right-hand popup for the song list on phones (the list moves in here)
local listPanel = create("Frame", {
	Name = "MusicListPanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Visible = false,
}, gui)
corner(listPanel, 15)
create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, listPanel)
create("TextLabel", {
	Name = "Header",
	Size = UDim2.new(1, -40, 0, 24),
	BackgroundTransparency = 1,
	Text = "🎵 음악",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
}, listPanel)
local listClose = create("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = COLORS.card,
	Text = "X",
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, listPanel)
corner(listClose, 13)
local compactNow = false

local toastLabel = create("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -160),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.25,
	TextColor3 = COLORS.text,
	TextSize = 16,
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
corner(toastLabel, 12)
local toastToken = 0
local function toast(message: any)
	if typeof(message) ~= "string" or message == "" then return end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end
djSparkButton.MouseButton1Click:Connect(function()
	local ok, okServer, message = pcall(function() return ClubShop:InvokeServer("DJColdSpark", nil) end)
	if ok and okServer then toast("🎆 불꽃 쇼 발사!") elseif ok then toast(message) end
end)

local function layout()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local top = require(script.Parent:WaitForChild("TopBar")).bottom() + 8
	local untilTime = FashionGame:GetAttribute("ClubDJUntil")
	local dj = FashionGame:GetAttribute("ClubDJ") == player.UserId
		and typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
	-- Phones in landscape are ~340 px tall: two popups at the left and right
	-- edges (디제잉 | 음악), the middle of the screen stays free.
	local compact = viewport.Y < 450
	compactNow = compact
	local width = if compact then math.clamp(math.floor(viewport.X * 0.3), 210, 300) else math.clamp(math.floor(viewport.X * 0.36), 260, 340)
	local height = math.min(viewport.Y - top - 8, 560)
	if compact then
		panel.Position = UDim2.new(0, 12, 0, top)
		listPanel.Position = UDim2.new(1, -width - 12, 0, top)
		listPanel.Size = UDim2.fromOffset(width, height)
	else
		panel.Position = UDim2.new(1, -width - 12, 0, top)
	end
	panel.Size = UDim2.fromOffset(width, height)
	local W, H = width - 20, height - 20
	local leftW = W
	local listParent = if compact then listPanel else panel
	for _, item in ipairs({ listTitle, trackList, queueLabel }) do
		if item.Parent ~= listParent then item.Parent = listParent end
	end
	listPanel.Visible = compact and panel.Visible
	local nowLabel = panel:FindFirstChild("NowLabel") :: TextLabel
	local header = panel:FindFirstChild("Header") :: TextLabel
	header.Size = UDim2.new(0, leftW - 34, 0, 24)
	header.Text = if compact then "🎧 디제잉" else "음악"
	nowLabel.Position = UDim2.fromOffset(0, if compact then 26 else 32)
	nowLabel.Size = UDim2.fromOffset(leftW, if compact then 18 else 22)
	nowLabel.TextSize = if compact then 13 else 16
	local y = if compact then 48 else 58
	djRow.Position = UDim2.fromOffset(0, y)
	djRow.Size = UDim2.fromOffset(leftW, if compact then 58 else 40)
	if compact then
		djLabel.Position = UDim2.fromOffset(6, 2)
		djLabel.Size = UDim2.new(1, -12, 0, 26)
		djButton.AnchorPoint = Vector2.new(1, 1)
		djButton.Position = UDim2.new(1, -4, 1, -4)
		-- as DJ the row holds both buttons side by side, half the width each
		-- (2P phone test 2026-10-26: 150 + 96 ran past the panel's left edge)
		local half = math.floor((leftW - 14) / 2)
		local djW = if dj then half else math.min(150, leftW - 8)
		djButton.Size = UDim2.fromOffset(djW, 24)
		screenButton.AnchorPoint = Vector2.new(1, 1)
		screenButton.Position = UDim2.new(1, -djW - 10, 1, -4)
		screenButton.Size = UDim2.fromOffset(half, 24)
	else
		djLabel.Position = UDim2.fromOffset(10, 0)
		djLabel.Size = UDim2.new(1, if dj then -226 else -120, 1, 0)
		djButton.AnchorPoint = Vector2.new(1, 0.5)
		djButton.Position = UDim2.new(1, -6, 0.5, 0)
		djButton.Size = UDim2.fromOffset(104, 30)
		screenButton.AnchorPoint = Vector2.new(1, 0.5)
		screenButton.Position = UDim2.new(1, -116, 0.5, 0)
		screenButton.Size = UDim2.fromOffset(100, 30)
	end
	screenButton.Visible = dj
	y += (if compact then 58 else 40) + 6
	if dj then
		djTools.Position = UDim2.fromOffset(0, y)
		djTools.Size = UDim2.fromOffset(leftW, if compact then 26 else 30)
		y += (if compact then 26 else 30) + 6
		local perRow = if compact then 4 else 8
		local rows = math.ceil(#ClubConfig.LightColors / perRow)
		local cellH = if compact then 22 else 24
		colorGrid.CellSize = UDim2.fromOffset(math.floor((leftW - (perRow - 1) * 4) / perRow), cellH)
		colorRow.Position = UDim2.fromOffset(0, y)
		colorRow.Size = UDim2.fromOffset(leftW, rows * (cellH + 4))
		y += rows * (cellH + 4) + 4
	end
	if compact then
		listTitle.Position = UDim2.fromOffset(0, 28)
		listTitle.Size = UDim2.new(1, 0, 0, 18)
		trackList.Position = UDim2.fromOffset(0, 48)
		trackList.Size = UDim2.new(1, 0, 1, -48)
		queueLabel.Visible = false
	else
		listTitle.Position = UDim2.fromOffset(0, y)
		listTitle.Size = UDim2.new(1, 0, 0, 22)
		trackList.Position = UDim2.fromOffset(0, y + 24)
		trackList.Size = UDim2.new(1, 0, 1, -(y + 24) - 74)
		queueLabel.Visible = true
	end
end
layout()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

--------------------------------------------------
-- State → UI
--------------------------------------------------

local function nameOf(userId: any): string
	if typeof(userId) ~= "number" or userId == 0 then return "" end
	local other = Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else "?"
end

local function isDJ(): boolean
	local untilTime = FashionGame:GetAttribute("ClubDJUntil")
	return FashionGame:GetAttribute("ClubDJ") == player.UserId
		and typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function requests(): {{i: number, u: number}}
	local raw = FashionGame:GetAttribute("ClubRequests")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function call(action: string, payload: any)
	local ok, result, message = pcall(function()
		return Music:InvokeServer(action, payload)
	end)
	if not ok then
		toast("잠시 후 다시 시도하세요.")
	elseif typeof(message) == "string" then
		toast(message)
	end
	return ok and result
end

local showGuests = false

local function guestIds(): {number}
	local raw = FashionGame:GetAttribute("ClubDJGuests")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- DJ zone guest list: everyone in the club, invited first.
local function renderGuests()
	for _, child in ipairs(trackList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local invited = guestIds()
	local rows = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other ~= player and root and ClubConfig.isInClub(root.Position) then
			table.insert(rows, { player = other, invited = table.find(invited, other.UserId) ~= nil })
		end
	end
	table.sort(rows, function(a, b)
		if a.invited ~= b.invited then return a.invited end
		return a.player.DisplayName < b.player.DisplayName
	end)
	for index, entry in ipairs(rows) do
		local other = entry.player :: Player
		local row = create("Frame", {
			Name = "Guest_" .. other.Name,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 40),
			BackgroundColor3 = COLORS.card,
		}, trackList)
		corner(row, 8)
		create("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -86, 1, 0),
			BackgroundTransparency = 1,
			Text = (if entry.invited then "🎧 " else "") .. other.DisplayName,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = COLORS.text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, row)
		local button = create("TextButton", {
			Name = "Invite",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(72, 28),
			BackgroundColor3 = if entry.invited then COLORS.card else COLORS.dj,
			Text = if entry.invited then "취소" else "초대",
			TextColor3 = COLORS.text,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
		}, row)
		corner(button, 14)
		button.MouseButton1Click:Connect(function()
			call(if entry.invited then "Uninvite" else "Invite", other.UserId)
		end)
	end
	if #rows == 0 then
		local empty = create("Frame", { Name = "Empty", Size = UDim2.new(1, -6, 0, 40), BackgroundTransparency = 1 }, trackList)
		create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "클럽 안에 초대할 사람이 없어요",
			TextColor3 = COLORS.sub,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, empty)
	end
end

local function renderTracks()
	if showGuests and isDJ() then
		renderGuests()
		return
	end
	for _, child in ipairs(trackList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local dj = isDJ()
	local otherDJ = (FashionGame:GetAttribute("ClubDJ") or 0) ~= 0 and not dj
	local current = FashionGame:GetAttribute("ClubTrack")
	for index, track in ipairs(ClubConfig.Playlist) do
		local row = create("Frame", {
			Name = "Track_" .. index,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 40),
			BackgroundColor3 = if index == current then COLORS.accent else COLORS.card,
		}, trackList)
		corner(row, 8)
		create("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, if dj then (if compactNow then -110 else -150) else (if compactNow then -62 else -86), 1, 0),
			BackgroundTransparency = 1,
			Text = track.title .. "  ·  " .. track.channel,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = COLORS.text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, row)
		local function rowButton(name: string, text: string, x: number, color: Color3, onClick: () -> ())
			local button = create("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, x, 0.5, 0),
				Size = UDim2.fromOffset(if compactNow then 48 else 64, 28),
				BackgroundColor3 = color,
				Text = text,
				TextColor3 = COLORS.text,
				TextSize = 13,
				Font = Enum.Font.GothamBold,
			}, row)
			corner(button, 14)
			button.MouseButton1Click:Connect(onClick)
		end
		if dj then
			rowButton("Play", "지금", if compactNow then -56 else -72, COLORS.dj, function() call("Play", index) end)
			rowButton("Queue", "다음", -4, COLORS.card, function() call("Queue", index) end)
		elseif not otherDJ then
			rowButton("Request", "신청", -4, COLORS.accent, function() call("Request", index) end)
		end
	end
end

local function refresh()
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	local by = nameOf(FashionGame:GetAttribute("ClubTrackBy"))
	nowLabel.Text = if track
		then "♪ " .. track.title .. (if by ~= "" then "  ·  " .. by .. "님 선곡" else "")
		else "♪ -"
	local djId = FashionGame:GetAttribute("ClubDJ") or 0
	local untilTime = FashionGame:GetAttribute("ClubDJUntil") or 0
	local waiting = FashionGame:GetAttribute("ClubDJQueue") or 0
	local dj = isDJ()
	if dj then
		local left = math.max(0, untilTime - workspace:GetServerTimeNow())
		djLabel.Text = string.format("🎧 내가 DJ! 남은 시간 %d:%02d", math.floor(left / 60), math.floor(left % 60))
		-- Extending is only possible while nobody waits (D-061).
		djButton.Text = if waiting > 0 then string.format("대기 %d명 · 연장 불가", waiting) else "시간 연장"
		djButton.BackgroundColor3 = if waiting > 0 then COLORS.card else COLORS.robux
	elseif djId ~= 0 then
		local left = math.max(0, untilTime - workspace:GetServerTimeNow())
		djLabel.Text = string.format("🎧 DJ %s · %d분 남음 · 대기 %d명", nameOf(djId), math.ceil(left / 60), waiting)
		djButton.Text = "DJ 대기 구매"
		djButton.BackgroundColor3 = COLORS.robux
	else
		djButton.BackgroundColor3 = COLORS.robux
		djLabel.Text = "DJ 없음 · 누구나 한 곡씩 신청"
		djButton.Text = string.format("DJ %d분 · R$%d", MonetizationConfig.DJMinutes, MonetizationConfig.Products.DJ.price)
	end
	djTools.Visible = dj
	colorRow.Visible = dj
	local pickedColor = FashionGame:GetAttribute("ClubLightColor") or "rainbow"
	for key, button in pairs(colorButtons) do
		(button:FindFirstChild("Picked") :: UIStroke).Enabled = key == pickedColor
	end
	layout()
	listTitle.Text = if dj and showGuests then "DJ 존 초대 (초대한 사람만 올라올 수 있어요)"
		elseif dj then "곡 고르기 (지금 / 다음)" elseif djId ~= 0 then "DJ가 곡을 고르는 중" else "곡 신청 (한 번에 한 곡)"
	guestsButton.Text = if showGuests then "🎵 곡 목록" else "👥 초대"
	local speed = FashionGame:GetAttribute("ClubLightSpeed")
	speedButton.Text = "⚡x" .. tostring(if typeof(speed) == "number" then speed else 1)
	local lightsOn = FashionGame:GetAttribute("ClubLights") ~= false
	lightsButton.Text = if lightsOn then "💡 조명 ON" else "🌑 조명 OFF"
	lightsButton.BackgroundColor3 = if lightsOn then COLORS.dj else COLORS.card
	local lasersOn = FashionGame:GetAttribute("ClubLasers") ~= false
	laserButton.Text = if lasersOn then "✳ 레이저 ON" else "✳ 레이저 OFF"
	laserButton.BackgroundColor3 = if lasersOn then COLORS.dj else COLORS.card
	local screenOn = FashionGame:GetAttribute("ClubDJScreen") ~= false
	screenButton.Text = if screenOn then "📺 전광판 ON" else "📺 전광판 OFF"
	screenButton.BackgroundColor3 = if screenOn then COLORS.dj else COLORS.card
	local lines = {}
	for position, entry in ipairs(requests()) do
		local queued = ClubConfig.Playlist[entry.i]
		if queued and position <= 4 then
			table.insert(lines, string.format("%d. %s · %s", position, queued.title, nameOf(entry.u)))
		end
	end
	queueLabel.Text = if #lines > 0 then "다음 곡\n" .. table.concat(lines, "\n") else "다음 곡: 자동 재생"
end

local openedAt: Vector3? = nil
local Popups = require(script.Parent:WaitForChild("Popups"))
local function setPanelOpen(open: boolean)
	panel.Visible = open
	listPanel.Visible = open and compactNow
	if not open then Popups.closed("ClubMusic") end
	if open then
		Popups.opened("ClubMusic", function() setPanelOpen(false) end)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		openedAt = if root and root:IsA("BasePart") then root.Position else nil
		layout()
		refresh()
		renderTracks()
	end
end

-- The panel closes when the player walks away from where they opened it.
local function updateVisibility()
	if panel.Visible and openedAt then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - openedAt).Magnitude > 24 then setPanelOpen(false) end
	end
end

local function refreshAll()
	updateVisibility()
	refresh()
	if panel.Visible then renderTracks() end
end

for _, name in ipairs({ "ClubTrack", "ClubTrackBy", "ClubRequests", "ClubDJ", "ClubDJUntil", "ClubDJQueue", "ClubDJGuests", "ClubLights", "ClubLasers", "ClubLightColor", "ClubLightSpeed", "ClubDJScreen" }) do
	FashionGame:GetAttributeChangedSignal(name):Connect(refreshAll)
end

for key, button in pairs(colorButtons) do
	button.MouseButton1Click:Connect(function() call("LightColor", key) end)
end
speedButton.MouseButton1Click:Connect(function()
	local speed = FashionGame:GetAttribute("ClubLightSpeed")
	local i = table.find(LIGHT_SPEEDS, if typeof(speed) == "number" then speed else 1) or 2
	call("LightSpeed", LIGHT_SPEEDS[i % #LIGHT_SPEEDS + 1])
end)
listClose.MouseButton1Click:Connect(function()
	setPanelOpen(false)
end)
closeButton.MouseButton1Click:Connect(function()
	setPanelOpen(false)
end)
skipButton.MouseButton1Click:Connect(function() call("Skip", nil) end)
screenButton.MouseButton1Click:Connect(function()
	call("Screen", FashionGame:GetAttribute("ClubDJScreen") == false)
end)
lightsButton.MouseButton1Click:Connect(function()
	call("Lights", FashionGame:GetAttribute("ClubLights") == false)
end)
laserButton.MouseButton1Click:Connect(function()
	call("Lasers", FashionGame:GetAttribute("ClubLasers") == false)
end)

-- The DJ table (models tagged "DJConsole"): a local "디제잉하기" prompt (E)
-- opens this window; the DJ also starts DJing (moved to the DJ spot, hand
-- motion). The old ClickDetector still opens it for the DJ on desktop.
local function startDjing()
	if isDJ() then
		pcall(function() Remotes:WaitForChild("Dance"):FireServer("Stop") end)
		call("Djing", true)
	end
	setPanelOpen(true)
end
local function watchConsole(console: Instance)
	local anchor = console:FindFirstChild("DeskTop", true) or console:FindFirstChildWhichIsA("BasePart", true)
	if anchor and not anchor:FindFirstChild("DjingPrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DjingPrompt"
		prompt.ActionText = "디제잉하기"
		prompt.ObjectText = "DJ 턴테이블"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(startDjing)
	end
	local detector = console:FindFirstChildWhichIsA("ClickDetector", true)
	if not detector then return end
	(detector :: ClickDetector).MouseClick:Connect(function(clicker)
		if clicker ~= player then return end
		if isDJ() then
			startDjing()
		else
			toast("DJ 테이블은 DJ만 쓸 수 있어요. DJ 시간을 사면 곡과 조명을 고를 수 있어요.")
		end
	end)
end
for _, console in ipairs(CollectionService:GetTagged("DJConsole")) do watchConsole(console) end
CollectionService:GetInstanceAddedSignal("DJConsole"):Connect(watchConsole)
guestsButton.MouseButton1Click:Connect(function()
	showGuests = not showGuests
	refresh()
	renderTracks()
end)
djButton.MouseButton1Click:Connect(function()
	if isDJ() and (FashionGame:GetAttribute("ClubDJQueue") or 0) > 0 then
		toast("기다리는 DJ가 있어서 연장할 수 없어요.")
		return
	end
	local product = MonetizationConfig.Products.DJ
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		local ok, message = ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = "DJ" })
		if not ok then toast(message) end
	else
		toast("준비 중인 상품입니다.")
	end
end)

-- Countdown text while the panel is open.
task.spawn(function()
	while true do
		task.wait(1)
		updateVisibility()
		if panel.Visible then
			refresh()
			if showGuests then renderTracks() end
		end
	end
end)
updateVisibility()
refresh()
