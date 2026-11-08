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

-- (the neon club shop palette, user 2026-10-28 (4), D-459: NeonShopUI)
local COLORS = {
	panel = Color3.fromRGB(10, 14, 32),
	card = Color3.fromRGB(20, 27, 56),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(170, 182, 214),
	accent = Color3.fromRGB(255, 70, 210),
	dj = Color3.fromRGB(0, 190, 230),
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
-- buttons and cards: the shop's thin edge (D-459)
gui.DescendantAdded:Connect(function(d)
	if (d:IsA("TextButton") or (d:IsA("Frame") and d.BackgroundTransparency < 0.5 and d.Name ~= "MusicPanel")) and not d:FindFirstChildOfClass("UIStroke") then
		task.defer(function()
			if d.Parent and not d:FindFirstChildOfClass("UIStroke") then
				create("UIStroke", { Color = Color3.fromRGB(90, 120, 200), Thickness = 1, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, d)
			end
		end)
	end
end)


local panel = create("Frame", {
	Name = "MusicPanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Visible = false,
}, gui)
corner(panel, 15)
create("UIStroke", { Color = Color3.fromRGB(40, 225, 255), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, panel)

create("TextLabel", {
	Name = "Header",
	Size = UDim2.new(1, -40, 0, 26),
	BackgroundTransparency = 1,
	Text = "🎧 음악 · DJ",
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
-- ? beside X: what every button does (DjHelp, D-734)
local helpButton = create("TextButton", {
	Name = "HelpButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -34, 0, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = COLORS.card,
	Text = "?",
	TextColor3 = COLORS.text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
}, panel)
corner(helpButton, 14)
helpButton.MouseButton1Click:Connect(function()
	require(script.Parent:WaitForChild("DjHelp")).toggle(gui)
end)

local nowLabel = create("TextLabel", {
	Name = "NowLabel",
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = COLORS.text,
	TextSize = 16,
	RichText = true, -- (the smaller 🎵, D-756)
	Font = Enum.Font.GothamBold,
}, panel)
-- (D-910, user 2026-11-05: "왼쪽 팝업에 안무 버튼 카메라 버튼 추가 바로 아래에
-- 재생바 추가") the banner's 🎵 / 🎥 sit at the right end of the song line and
-- its play bar just under it while this window is open (ClubQuickBar moves
-- them into these two slots; the banner itself hides behind the window)
local iconSlot = create("Frame", { Name = "IconSlot", BackgroundTransparency = 1 }, panel)
local barSlot = create("Frame", { Name = "PlayBarSlot", BackgroundTransparency = 1 }, panel)
local ICON_W, BAR_H = 44, 18

-- (D-940, user 2026-11-06: "디제잉 창에서 삐져나옴") everything under the song
-- line scrolls inside the window when it is taller than the window
local body = create("ScrollingFrame", {
	Name = "Body",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(),
}, panel)

-- DJ status row
local djRow = create("Frame", {
	Name = "DJRow",
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = COLORS.card,
}, body)
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
}, body)
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
-- (user 2026-11-01, later) one DJ row: 📺 전광판 on/off, ⏸ 일시정지 and 🎆
-- 무대 스파클러. The speed / volume / pitch mixer (D-675) is gone from the
-- turntable; the songs carry their own speed and pitch (ClubConfig).
local djSound = create("Frame", {
	Name = "DJSound",
	BackgroundTransparency = 1,
	Visible = false,
}, body)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, djSound)
local function djRowButton(name: string, text: string, order: number, color: Color3): TextButton
	local b = create("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = COLORS.text,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
	}, djSound)
	corner(b, 8)
	create("UITextSizeConstraint", { MaxTextSize = 13 }, b)
	create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, b)
	return b
end
-- DJ shown on the big LED screen (DjService.Actions.Screen, attribute ClubDJScreen)
-- (D-724, user 2026-11-01: ⏸ first, then 📺)
local screenButton = djRowButton("Screen", "📺 전광판 ON", 2, COLORS.dj)
local pauseButton = djRowButton("Pause", "⏸ 일시정지", 1, COLORS.card)
-- 🎆 the stage fireworks, free for the DJ (user 2026-10-27; SparkleService
-- "DJColdSpark", once every 90 s)
local djSparkButton = djRowButton("DJSpark", "🎆 무대 스파클러", 3, Color3.fromRGB(255, 150, 40))

-- (D-737, user's before / after picture) the two rows sorted by what they do,
-- a thin line between them and another one over the EDM controls:
--   [⏸ 일시정지] [⏭ 건너뛰기] [📺 전광판 ON] [👥 초대]      (music, DJ)
--   ─────────────────────────────────────────────
--   [💡 조명 ON] [✳ 레이저 ON ⚡x1] [🎆 무대 스파클러]      (lights, stage)
for order, item in ipairs({ pauseButton, skipButton, screenButton, guestsButton } :: {GuiObject}) do
	item.Parent = djTools
	item.LayoutOrder = order
	item.Size = UDim2.new(0.25, -5, 1, 0)
end
for order, entry in ipairs({ { lightsButton, 0.23 }, { laserGroup, 0.42 }, { djSparkButton, 0.35 } }) do
	local item = entry[1] :: GuiObject
	item.Parent = djSound
	item.LayoutOrder = order
	item.Size = UDim2.new(entry[2] :: number, -4, 1, 0)
end
laserButton.Size = UDim2.new(0.66, -2, 1, 0) -- (one line for "레이저 ON")
speedButton.Size = UDim2.new(0.34, -2, 1, 0)
local function divider(name: string): Frame
	-- (BackgroundTransparency 0.5: the window's thin-edge rule above leaves it alone)
	return create("Frame", {
		Name = name, BackgroundColor3 = Color3.fromRGB(120, 150, 230), BackgroundTransparency = 0.5,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Visible = false,
	}, body)
end
local dividerTop = divider("DividerTools")
local dividerEdm = divider("DividerEdm")

-- light colours (DJ only): ClubConfig.LightColors swatches
local colorRow = create("Frame", {
	Name = "LightColors",
	BackgroundTransparency = 1,
	Visible = false,
}, body)
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

-- 🎛 EDM effects (DJ only, D-733): EdmPanel lays itself out under the colours
local edmPanel = require(script.Parent:WaitForChild("EdmPanel")).new(body)

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
-- 🔍 song search (user 2026-11-01, D-717): rows whose title / channel hold the text
local searchBox = create("TextBox", {
	Name = "SongSearch",
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = COLORS.card,
	PlaceholderText = "🔍 노래 검색",
	PlaceholderColor3 = COLORS.sub,
	Text = "",
	ClearTextOnFocus = false,
	TextColor3 = COLORS.text,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
corner(searchBox, 8)
create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, searchBox)
-- (D-940, user 2026-11-06: "음악 리스트 창 하단에 다음곡 뜨는 거 음악 팝업창 2:1로
-- 나눠서 아래 칸 자리 줘서 기기 사이즈에 맞춰서 비율로") the next songs get the
-- bottom third of the song window (the list the top two thirds), on every
-- screen; it scrolls when the list is long
local queueBox = create("ScrollingFrame", {
	Name = "QueueBox",
	BackgroundColor3 = COLORS.card,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
corner(queueBox, 8)
create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, queueBox)
local queueLabel = create("TextLabel", {
	Name = "QueueLabel",
	Size = UDim2.new(1, -4, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	TextColor3 = COLORS.sub,
	TextSize = 13,
	RichText = true, -- (the smaller 🎵, D-756)
	Font = Enum.Font.GothamMedium,
}, queueBox)

-- right-hand popup for the song list (phones, and PC since D-757; the list moves in here)
local listPanel = create("Frame", {
	Name = "MusicListPanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Visible = false,
	-- (D-940: made after the 디제잉 window, so it is drawn on top of it when both
	-- share one place; no ZIndex: this ScreenGui is Global, a higher one covered
	-- its own contents)
	Active = true, -- (taps on it do not reach the window under it)
}, gui)
panel.Active = true
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
-- (D-762, user: the playing song in the song window too, under its header)
local listNow = create("TextLabel", {
	Name = "ListNowLabel",
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = COLORS.text,
	TextSize = 13,
	RichText = true,
	Font = Enum.Font.GothamBold,
}, listPanel)
local compactNow = false

-- (D-940, user 2026-11-06: "화면 좁아지니까 겹침 / 좁아지면 팝업 하나에 디제잉, 음악
-- 카테고리 나누기. 카탈로그에서 버튼 누르면 아래 해당하는 창 떴던 것처럼") when the
-- two windows do not fit side by side, they share one place and two tabs at
-- the top of each switch between them: [🎧 디제잉] [🎵 음악]
local activeTab = "dj" -- "dj" | "music"
local tabbedNow = false
local layout: () -> ()
local tabButtons: {{ key: string, button: TextButton }} = {}
local function makeTabs(parent: Instance): Frame
	local row = create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Visible = false }, parent)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	for order, entry in ipairs({ { "dj", "🎧 디제잉" }, { "music", "🎵 음악" } }) do
		local key = entry[1]
		local button = create("TextButton", {
			Name = "Tab_" .. key,
			LayoutOrder = order,
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = COLORS.card,
			Text = entry[2],
			TextColor3 = COLORS.text,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}, row)
		corner(button, 12)
		create("UITextSizeConstraint", { MaxTextSize = 15 }, button)
		create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, button)
		button.MouseButton1Click:Connect(function()
			activeTab = key
			layout()
		end)
		table.insert(tabButtons, { key = key, button = button })
	end
	return row
end
local djTabs = makeTabs(panel)
local listTabs = makeTabs(listPanel)

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

layout = function()
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
	-- (D-940) the two windows side by side need 12 + width + 12 + width + 12;
	-- narrower screens (phones held upright, small windows) get one window
	-- with the two tabs
	local tabbed = viewport.X < 2 * width + 36
	tabbedNow = tabbed
	if tabbed then width = math.max(math.min(viewport.X - 24, 420), 200) end
	local height = math.min(viewport.Y - top - 8, 560)
	-- (D-757, user: on PC too, as on phones) two windows: 디제잉 at the left
	-- edge, the song list (🎵 음악) at the right edge. (Before, the PC window
	-- held both, at the right edge.)
	panel.AnchorPoint = Vector2.zero
	panel.Position = UDim2.new(0, 12, 0, top)
	-- (D-763, user: the DJ tip's grow ran off the right edge) the list window at
	-- the right edge hangs from its right corner, so Spotlight's UIScale grows it
	-- leftwards (as D-737 did for the old one-window PC layout)
	if tabbed then
		listPanel.AnchorPoint = Vector2.zero
		listPanel.Position = UDim2.new(0, 12, 0, top)
	else
		listPanel.AnchorPoint = Vector2.new(1, 0)
		listPanel.Position = UDim2.new(1, -12, 0, top)
	end
	listPanel.Size = UDim2.fromOffset(width, height)
	panel.Size = UDim2.fromOffset(width, height)
	local W, H = width - 20, height - 20
	local leftW = W
	for _, item in ipairs({ listTitle, searchBox, trackList, queueBox } :: {GuiObject}) do
		if item.Parent ~= listPanel then item.Parent = listPanel end
	end
	-- (D-940) tabbed: the song window lies over the 디제잉 window while 🎵 음악
	-- is picked (the 디제잉 window stays open under it: the banner and the
	-- quick bar go by its Visible)
	listPanel.Visible = panel.Visible and (not tabbed or activeTab == "music")
	local nowLabel = panel:FindFirstChild("NowLabel") :: TextLabel
	local header = panel:FindFirstChild("Header") :: TextLabel
	local listHeader = listPanel:FindFirstChild("Header") :: TextLabel
	header.Size = UDim2.new(0, leftW - 68, 0, 24) -- (room for ? and X)
	header.Text = "🎧 디제잉"
	header.Visible = not tabbed
	listHeader.Visible = not tabbed
	djTabs.Visible = tabbed
	listTabs.Visible = tabbed
	djTabs.Position = UDim2.fromOffset(0, 0)
	djTabs.Size = UDim2.fromOffset(leftW - 68, 26)
	listTabs.Position = UDim2.fromOffset(0, 0)
	listTabs.Size = UDim2.fromOffset(W - 34, 26)
	for _, entry in ipairs(tabButtons) do
		local on = entry.key == activeTab
		entry.button.BackgroundColor3 = if on then COLORS.dj else COLORS.card
		entry.button.TextColor3 = if on then COLORS.text else COLORS.sub
	end
	local nowY, nowH = (if compact then 26 else 32), (if compact then 18 else 22)
	if tabbed then nowY = math.max(nowY, 30) end
	nowLabel.Position = UDim2.fromOffset(0, nowY)
	nowLabel.Size = UDim2.fromOffset(leftW - ICON_W, nowH)
	nowLabel.TextSize = if compact then 13 else 16
	-- (D-910) 🎵 🎥 after the title, the play bar under it
	iconSlot.Position = UDim2.fromOffset(leftW - ICON_W, nowY)
	iconSlot.Size = UDim2.fromOffset(ICON_W, nowH)
	barSlot.Position = UDim2.fromOffset(0, nowY + nowH + 2)
	barSlot.Size = UDim2.fromOffset(leftW, BAR_H - 4)
	-- (D-940) the rest scrolls in `body`: positions from its top
	local bodyTop = nowY + nowH + BAR_H + 4
	local function placeBody(w: number): number
		local y = 0
		djRow.Position = UDim2.fromOffset(0, y)
		djRow.Size = UDim2.fromOffset(w, if compact then 58 else 40)
		if compact then
			djLabel.Position = UDim2.fromOffset(6, 2)
			djLabel.Size = UDim2.new(1, -12, 0, 26)
			djButton.AnchorPoint = Vector2.new(1, 1)
			djButton.Position = UDim2.new(1, -4, 1, -4)
			-- (the 📺 button moved to the DJ row below, user 2026-11-01)
			djButton.Size = UDim2.fromOffset(math.min(150, w - 8), 24)
		else
			djLabel.Position = UDim2.fromOffset(10, 0)
			djLabel.Size = UDim2.new(1, -120, 1, 0)
			djButton.AnchorPoint = Vector2.new(1, 0.5)
			djButton.Position = UDim2.new(1, -6, 0.5, 0)
			djButton.Size = UDim2.fromOffset(104, 30)
		end
		y += (if compact then 58 else 40) + 6
		if dj then
			djTools.Position = UDim2.fromOffset(0, y)
			djTools.Size = UDim2.fromOffset(w, if compact then 26 else 30)
			y += (if compact then 26 else 30) + 5
			dividerTop.Position = UDim2.fromOffset(0, y)
			dividerTop.Size = UDim2.fromOffset(w, 1)
			y += 1 + 5
			djSound.Position = UDim2.fromOffset(0, y)
			djSound.Size = UDim2.fromOffset(w, if compact then 26 else 30)
			y += (if compact then 26 else 30) + 6
			local perRow = 8 -- (one row on phones too since D-733: room for the EDM controls)
			local rows = math.ceil(#ClubConfig.LightColors / perRow)
			local cellH = if compact then 22 else 24
			colorGrid.CellSize = UDim2.fromOffset(math.floor((w - (perRow - 1) * 4) / perRow), cellH)
			colorRow.Position = UDim2.fromOffset(0, y)
			colorRow.Size = UDim2.fromOffset(w, rows * (cellH + 4))
			y += rows * (cellH + 4) + 2
			dividerEdm.Position = UDim2.fromOffset(0, y)
			dividerEdm.Size = UDim2.fromOffset(w, 1)
			y += 1 + 6
			y += edmPanel.place(y, w, compact) + 6
		end
		return y
	end
	local bodyRoom = H - bodyTop
	local contentH = placeBody(leftW)
	-- (taller than the window: room for the scroll bar at the right)
	if contentH > bodyRoom then contentH = placeBody(leftW - 8) end
	body.Position = UDim2.fromOffset(0, bodyTop)
	body.CanvasSize = UDim2.fromOffset(0, contentH)
	if not compact and not tabbed then
		-- (PC side by side: the 디제잉 window only as tall as what it holds)
		local used = math.min(H, bodyTop + contentH)
		panel.Size = UDim2.fromOffset(width, used + 20)
		body.Size = UDim2.fromOffset(leftW, used - bodyTop)
	else
		body.Size = UDim2.fromOffset(leftW, math.max(bodyRoom, 0))
	end
	-- song window: header (or tabs), the playing song at 26 (D-762), the list
	-- title, 🔍, then the list on top (2 / 3) and the next songs below (1 / 3)
	local listTop = if tabbed then 4 else 0
	listNow.Position = UDim2.fromOffset(0, 26 + listTop)
	listTitle.Position = UDim2.fromOffset(0, 46 + listTop)
	listTitle.Size = UDim2.new(1, 0, 0, 18)
	searchBox.Position = UDim2.fromOffset(0, 66 + listTop)
	local listY = 96 + listTop
	local room = math.max(H - listY, 60)
	local queueH = math.floor(room / 3)
	trackList.Position = UDim2.fromOffset(0, listY)
	trackList.Size = UDim2.new(1, 0, 0, room - queueH - 6)
	queueBox.Position = UDim2.fromOffset(0, listY + room - queueH)
	queueBox.Size = UDim2.new(1, 0, 0, queueH)
	queueBox.Visible = true
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
	local query = string.lower(searchBox.Text)
	for index, track in ipairs(ClubConfig.Playlist) do
		if query ~= "" and not string.find(string.lower(track.title .. " " .. track.channel), query, 1, true) then continue end
		local row = create("Frame", {
			Name = "Track_" .. index,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 40),
			BackgroundColor3 = if index == current then COLORS.accent else COLORS.card,
		}, trackList)
		corner(row, 8)
		-- (D-940) the DJ's three buttons: 지금 / 우선예약 / 예약
		-- (D-941, user 2026-11-06: "글씨 빼고 그냥 작은 원 버튼으로 변경해서 노래 제목
		-- 보이게") small round icon buttons: ▶ 지금, ⏫ 우선예약, ➕ 예약 (the list
		-- title says which is which)
		local buttonW = 28
		create("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, if dj then -(3 * buttonW + 26) else (if compactNow then -62 else -86), 1, 0),
			BackgroundTransparency = 1,
			-- (D-1010) a locked song: 🔒 in front, greyed, no buttons
			Text = (if track.locked then "🔒 " else "") .. ClubConfig.showTitle(track, 14) .. "  ·  " .. track.channel, -- (🎵 = a choreography, D-731)
			TextTransparency = if track.locked then 0.45 else 0,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			-- (D-905, user 2026-11-05: a long title is just cut at the edge, no "…":
			-- with rich text AtEnd left only "🎵…" on the playing row)
			TextTruncate = Enum.TextTruncate.None,
			ClipsDescendants = true,
			TextColor3 = COLORS.text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, row)
		local function rowButton(name: string, text: string, x: number, w: number, color: Color3, onClick: () -> ())
			local round = w <= 30
			local button = create("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, x, 0.5, 0),
				Size = UDim2.fromOffset(w, if round then w else 28),
				BackgroundColor3 = color,
				Text = text,
				TextColor3 = COLORS.text,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			}, row)
			corner(button, 14)
			create("UITextSizeConstraint", { MaxTextSize = if round then 18 else 13 }, button)
			create("UIPadding", { PaddingLeft = UDim.new(0, if round then 4 else 3), PaddingRight = UDim.new(0, if round then 4 else 3),
				PaddingTop = UDim.new(0, if round then 4 else 0), PaddingBottom = UDim.new(0, if round then 4 else 0) }, button)
			button.MouseButton1Click:Connect(onClick)
		end
		if track.locked then
			-- (D-1010, user 2026-11-08: "음원 잠금") nothing to press
		elseif dj then
			-- (D-940, user 2026-11-06: "디제이 음악창 지금/우선예약/예약으로 버튼 추가")
			--   지금: plays now; 우선예약: first in the list of next songs ("Queue");
			--   예약: at the end of it, in the order they were pressed ("Request")
			rowButton("Play", "▶", -(2 * buttonW + 16), buttonW, COLORS.dj, function() call("Play", index) end)
			rowButton("Queue", "⏫", -(buttonW + 10), buttonW, COLORS.accent, function() call("Queue", index) end)
			rowButton("Reserve", "➕", -4, buttonW, COLORS.robux, function() call("Request", index) end)
		elseif not otherDJ then
			rowButton("Request", "신청", -4, if compactNow then 48 else 64, COLORS.accent, function() call("Request", index) end)
		end
	end
end

local function refresh()
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	local by = nameOf(FashionGame:GetAttribute("ClubTrackBy"))
	nowLabel.Text = if track
		then "♪ " .. ClubConfig.showTitle(track, nowLabel.TextSize) .. (if by ~= "" then "  ·  " .. ClubConfig.escapeRich(by) .. "님 선곡" else "")
		else "♪ -"
	listNow.Text = if track then "♪ 지금: " .. ClubConfig.showTitle(track, listNow.TextSize) else "♪ 지금: -"
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
	djSound.Visible = dj
	colorRow.Visible = dj
	edmPanel.frame.Visible = dj
	dividerTop.Visible = dj
	dividerEdm.Visible = dj
	local paused = FashionGame:GetAttribute("ClubMusicPaused") == true
	pauseButton.Text = if paused then "▶ 다시 재생" else "⏸ 일시정지"
	pauseButton.BackgroundColor3 = if paused then COLORS.dj else COLORS.card
	local pickedColor = FashionGame:GetAttribute("ClubLightColor") or "rainbow"
	for key, button in pairs(colorButtons) do
		(button:FindFirstChild("Picked") :: UIStroke).Enabled = key == pickedColor
	end
	layout()
	listTitle.Text = if dj and showGuests then "DJ 존 초대 (초대한 사람만 올라올 수 있어요)"
		elseif dj then "▶ 지금 · ⏫ 우선예약 · ➕ 예약" elseif djId ~= 0 then "DJ가 곡을 고르는 중 (DJ만 곡을 골라요)" else "곡 신청 (한 번에 한 곡)"
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
		if queued then -- (D-940: all of them; the box scrolls)
			table.insert(lines, string.format("%d. %s · %s", position, ClubConfig.showTitle(queued, 13), ClubConfig.escapeRich(nameOf(entry.u))))
		end
	end
	queueLabel.Text = if #lines > 0 then "다음 곡\n" .. table.concat(lines, "\n") else "다음 곡: 자동 재생"
end

local openedAt: Vector3? = nil
local openedClock = 0
local Popups = require(script.Parent:WaitForChild("Popups"))
local function setPanelOpen(open: boolean)
	panel.Visible = open
	listPanel.Visible = open -- (PC too since D-757)
	if not open then Popups.closed("ClubMusic") end
	if open then
		-- (D-940) one window with tabs: the DJ starts on 🎧 디제잉, others on 🎵 음악
		activeTab = if isDJ() then "dj" else "music"
		openedClock = os.clock()
		Popups.opened("ClubMusic", function() setPanelOpen(false) end)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		openedAt = if root and root:IsA("BasePart") then root.Position else nil
		layout()
		refresh()
		renderTracks()
	end
end

-- (the club's 🎵 노래 신청 button, ClubQuickBar, D-694: the same window as at
-- the turntable, so anyone in the club can queue a song)
require(script.Parent:WaitForChild("UiBus")).OpenMusic.Event:Connect(function() setPanelOpen(not panel.Visible) end)

-- (D-911, user 2026-11-05: "엑스 말고 팝업 외 다른 공간 누르면 팝업 꺼지게") a
-- click or tap anywhere outside the two windows (and the ? help) closes them.
-- Taps on other buttons (the top row, the joystick) are left alone: they are
-- the game's own and open their own windows.
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or not panel.Visible or os.clock() - openedClock < 0.4 then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	-- (GetGuiObjectsAtPosition wants the inset-free position the input has)
	for _, hit in ipairs(playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)) do
		if hit:IsDescendantOf(gui) then return end
	end
	setPanelOpen(false)
	require(script.Parent:WaitForChild("DjHelp")).close()
end)

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
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if panel.Visible then renderTracks() end
end)

for _, name in ipairs({ "ClubTrack", "ClubTrackBy", "ClubRequests", "ClubDJ", "ClubDJUntil", "ClubDJQueue", "ClubDJGuests", "ClubLights", "ClubLasers", "ClubLightColor", "ClubLightSpeed", "ClubDJScreen", "ClubMusicSpeed", "ClubMusicPitch", "ClubMusicPaused", "ClubMusicVolume" }) do
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
	require(script.Parent:WaitForChild("DjHelp")).close()
end)
skipButton.MouseButton1Click:Connect(function() call("Skip", nil) end)
pauseButton.MouseButton1Click:Connect(function()
	call("Pause", FashionGame:GetAttribute("ClubMusicPaused") ~= true)
end)
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
	if showGuests and tabbedNow then activeTab = "music" end -- (D-940: the list is in the 🎵 tab)
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
