--!strict
-- (D-1366, user 2026-11-13, a mock-up "한국의 오후 · OHU GRAND OPENING 출석 이벤트") The opening
-- attendance window in the mock-up's colours (cherry pink and lilac): the title, the period,
-- 14 day cards in two rows of seven (coins, the limited frame at 7, the FOUNDING MEMBER title
-- at 14), each 받기 완료 / 오늘 받았어요 / 기다려요, and the note that every reward is once per
-- account. It opens by itself when today's attendance was counted on this visit (after the
-- first-visit tour and any other window), and from the 🎁 button in the top bar while the
-- event runs. Data: player attributes from OpeningEventService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Config = require(FashionGame:WaitForChild("Shared"):WaitForChild("OpeningEventConfig"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PINK = Color3.fromRGB(255, 92, 168)
local PINK_SOFT = Color3.fromRGB(255, 224, 238)
local LILAC = Color3.fromRGB(176, 140, 235)
local LILAC_SOFT = Color3.fromRGB(236, 226, 252)
local GOLD = Color3.fromRGB(246, 196, 80)
local INK = Color3.fromRGB(88, 50, 120)
local WHITE = Color3.new(1, 1, 1)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local gui = create("ScreenGui", { Name = "OpeningEventGui", ResetOnSpawn = false, DisplayOrder = 42, IgnoreGuiInset = true, Enabled = false }, playerGui)
local dim = create("TextButton", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false }, gui)
local window = create("Frame", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0.94, 0, 0.86, 0), BackgroundColor3 = Color3.fromRGB(252, 240, 248),
}, gui)
corner(window, 22)
create("UISizeConstraint", { MaxSize = Vector2.new(680, 420) }, window)
create("UIStroke", { Color = WHITE, Thickness = 3 }, window)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 226, 240), Color3.fromRGB(236, 226, 252)) }, window)
local pad = create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, window)
local _ = pad

-- header
create("TextLabel", {
	Name = "Small", Size = UDim2.new(1, -120, 0, 16), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 13,
	TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Left, Text = "한국의 오후 · OHU GRAND OPENING",
}, window)
local title = create("TextLabel", {
	Name = "Title", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -120, 0, 34), BackgroundTransparency = 1,
	FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy), TextSize = 30,
	TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Left, Text = "출석 이벤트 💖",
}, window)
create("UIStroke", { Color = WHITE, Thickness = 2 }, title)
create("TextLabel", {
	Name = "Sub", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, -120, 0, 18), BackgroundTransparency = 1,
	FontFace = BOLD, TextSize = 14, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "매일 오후에 놀러 오고, 특별한 선물 받아 가세요!",
}, window)
local progress = create("TextLabel", {
	Name = "Progress", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 6), Size = UDim2.fromOffset(110, 52),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, FontFace = BOLD, TextSize = 15, TextColor3 = INK, Text = "",
	RichText = true,
}, window)
corner(progress, 14)
local close = create("TextButton", {
	Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = LILAC, Text = "X", TextColor3 = WHITE, FontFace = BOLD, TextSize = 18,
}, window)
corner(close, 18)
create("UIStroke", { Color = WHITE, Thickness = 2 }, close)

-- period row
local period = create("TextLabel", {
	Name = "Period", Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.25, FontFace = BOLD, TextSize = 14, TextColor3 = INK, Text = "",
}, window)
corner(period, 13)

-- the 14 cards
local grid = create("Frame", { Name = "Days", Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 1, -146), BackgroundTransparency = 1 }, window)
create("UIGridLayout", { CellSize = UDim2.new(1 / 7, -6, 0.5, -4), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
type Card = { frame: Frame, head: TextLabel, icon: TextLabel, label: TextLabel, status: TextLabel }
local cards: {Card} = {}
for n = 1, Config.Goal do
	local reward = Config.Rewards[n]
	local special = reward.frame or reward.title
	local f = create("Frame", { Name = "Day" .. n, LayoutOrder = n, BackgroundColor3 = WHITE, BackgroundTransparency = 0.1 }, grid)
	corner(f, 12)
	create("UIStroke", { Color = if special then GOLD else LILAC_SOFT, Thickness = 2 }, f)
	local head = create("TextLabel", {
		Size = UDim2.new(1, 0, 0.24, 0), BackgroundColor3 = if special then GOLD else LILAC, FontFace = BOLD, TextScaled = true,
		TextColor3 = WHITE, Text = n .. "일차",
	}, f)
	corner(head, 12)
	create("UITextSizeConstraint", { MaxTextSize = 14 }, head)
	local icon = create("TextLabel", {
		Position = UDim2.fromScale(0, 0.24), Size = UDim2.new(1, 0, 0.34, 0), BackgroundTransparency = 1, TextScaled = true,
		FontFace = BOLD, TextColor3 = GOLD,
		Text = if reward.coins then "₩" elseif reward.frame then "🖼️" else "👑", -- (the game's coin mark, as in the top bar)
	}, f)
	create("UITextSizeConstraint", { MaxTextSize = 26 }, icon)
	local label = create("TextLabel", {
		Position = UDim2.fromScale(0.04, 0.58), Size = UDim2.new(0.92, 0, 0.2, 0), BackgroundTransparency = 1, TextScaled = true,
		FontFace = BOLD, TextColor3 = INK,
		Text = if reward.title then "FOUNDING MEMBER" else Config.rewardText(reward),
	}, f)
	create("UITextSizeConstraint", { MaxTextSize = 12 }, label)
	local status = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0.86, 0, 0.17, 0),
		BackgroundColor3 = LILAC_SOFT, FontFace = BOLD, TextScaled = true, TextColor3 = INK, Text = "",
	}, f)
	corner(status, 8)
	create("UITextSizeConstraint", { MaxTextSize = 11 }, status)
	cards[n] = { frame = f, head = head, icon = icon, label = label, status = status }
end

-- the note
create("TextLabel", {
	Name = "Note", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, FontFace = BOLD, TextScaled = true, TextColor3 = INK,
	Text = "❗ 하루 한 번 출석 · 연속이 아니어도 돼요 · 보상은 계정당 1번 · 기간이 지나면 받을 수 없어요",
}, window)
create("UITextSizeConstraint", { MaxTextSize = 13 }, window:FindFirstChild("Note"))

local function refresh()
	local count = player:GetAttribute("OpeningCount")
	count = if typeof(count) == "number" then count else 0
	local just = player:GetAttribute("OpeningJustClaimed")
	local day = Config.dayNow()
	progress.Text = string.format('출석<br/><font size="22" color="#FF5CA8">%d</font> / %d', count, Config.Goal)
	period.Text = string.format("📅 %s · %d일 동안 %d번 출석하면 완료!%s", Config.periodText(), Config.Days, Config.Goal,
		if day then string.format("  (오늘은 %d일째)", day) else "  (이벤트가 끝났어요)")
	for n, c in ipairs(cards) do
		local reward = Config.Rewards[n]
		local special = reward.frame or reward.title
		if n <= count then
			c.frame.BackgroundColor3 = PINK_SOFT
			c.head.BackgroundColor3 = PINK
			c.status.BackgroundColor3 = PINK
			c.status.TextColor3 = WHITE
			c.status.Text = if n == just then "오늘 받았어요!" else "받기 완료!"
		else
			c.frame.BackgroundColor3 = WHITE
			c.head.BackgroundColor3 = if special then GOLD else LILAC
			c.status.BackgroundColor3 = LILAC_SOFT
			c.status.TextColor3 = INK
			c.status.Text = "기다려요"
		end
	end
end

local function setOpen(on: boolean)
	if on then refresh() end
	gui.Enabled = on
	if on then Popups.opened("OpeningEvent", function() setOpen(false) end) else Popups.closed("OpeningEvent") end
end
close.Activated:Connect(function() setOpen(false) end)
dim.Activated:Connect(function() setOpen(false) end)
for _, name in ipairs({ "OpeningCount", "OpeningJustClaimed" }) do
	player:GetAttributeChangedSignal(name):Connect(function() if gui.Enabled then refresh() end end)
end

-- 🎁 in the top bar while the event runs
local button = create("TextButton", {
	Name = "OpeningEventButton", BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.35,
	Text = "🎁", TextScaled = true, TextColor3 = WHITE, Visible = Config.dayNow() ~= nil,
}, create("ScreenGui", { Name = "OpeningEventButtonGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, playerGui)) -- (inset ignored like the other top bar buttons: 2P test 2026-11-13)
corner(button, 999)
create("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0.18, 0), PaddingRight = UDim.new(0.18, 0) }, button)
TopBar.add(button, 6)
button.Activated:Connect(function() setOpen(not gui.Enabled) end)

-- today's attendance counted on this visit: the window once, after the tour and other windows
task.spawn(function()
	local t0 = os.clock()
	while player:GetAttribute("OpeningJustClaimed") == nil and os.clock() - t0 < 30 do task.wait(0.5) end
	if player:GetAttribute("OpeningJustClaimed") == nil then return end
	while playerGui:FindFirstChild("OHULoading") do task.wait(1) end
	task.wait(4) -- (the first-visit tour starts 1.5 s after the loading screen: it goes first)
	while player:GetAttribute("TourActive") or Popups.anyOpen() do task.wait(1) end
	task.wait(1)
	setOpen(true)
end)
