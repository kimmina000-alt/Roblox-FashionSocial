--!strict
-- (D-1878) The mini Santa hunt on this screen (Shared/SantaHuntConfig, SantaHuntService):
-- * 🎅 in the top bar (TopBar order 6, the opening event's 🎁 place: it ends when the hunt starts)
--   while the hunt runs; afterwards the album opens from ☰ (UiBus.OpenSantaAlbum).
-- * The 산타 도감 (D-2044: redesigned from the user's mock-up, built with SantaUi): the "OHU CHRISTMAS"
--   ribbon and "미니 산타 찾기" title with the Santa's head, the count, today's hint, 20 cards (green date
--   tag, the Santa's picture or its black silhouette, its name or ???; today's card pink-edged with a
--   red tag and "오늘!"; later days a green ?), a tip pill, trees / gifts / snowflakes, a candy-cane
--   border and a snow cap. A tap on a found Santa holds it as a plush (remote SantaHunt "Hold").
--   After the event the same window is the "2026 미니 산타 앨범". One design size, scaled to the screen.
-- * Today's Santa vanishes on this screen once found; a find (attribute SantaJustFound) plays the
--   shaking black box, then the found-a-Santa popup (SantaUi.reveal).
-- * On joining while the hunt runs, today's hint once as a line at the top (BottomNotice).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SantaHuntConfig"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local BottomNotice = require(script.Parent:WaitForChild("BottomNotice"))
local Ui = require(script.Parent:WaitForChild("SantaUi"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local create, corner = Ui.create, Ui.corner
local WHITE = Ui.WHITE

local function mask(): number
	local m = player:GetAttribute("SantaFound")
	return if typeof(m) == "number" then m else 0
end

---------------------------------------------------------------------------- the album (design 720 x 470)
local DW, DH = 720, 470
local gui = create("ScreenGui", { Name = "SantaAlbumGui", ResetOnSpawn = false, DisplayOrder = 42, IgnoreGuiInset = true, Enabled = false }, playerGui)
local dim = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false }, gui)
local stage = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(DW, DH), BackgroundTransparency = 1 }, gui)
local scale = create("UIScale", {}, stage)
local function place()
	local s, cy = Ui.fit(DW, DH + 30)
	scale.Scale = s
	stage.Position = UDim2.new(0.5, 0, 0, cy + 12 * s)
end
place()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place) end

local panel = Ui.card(stage, UDim2.fromOffset(DW, DH), UDim2.fromScale(0.5, 0.5))
local cardRoot = panel.Parent :: Frame

-- header: ribbon, title, the Santa's head
Ui.pill(cardRoot, {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(66, 22), Size = UDim2.fromOffset(196, 34), Rotation = -7,
	TextSize = 17, Text = "OHU CHRISTMAS", ZIndex = 8,
}, Ui.RED, WHITE)
Ui.deco(cardRoot, "🎄", UDim2.fromOffset(46, 34), 42, -8).ZIndex = 9
local title, titleShadow = Ui.chunky(panel, {
	Position = UDim2.fromOffset(30, 26), Size = UDim2.fromOffset(330, 52), TextSize = 46, RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3,
}, 5)
create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(392, 14), Size = UDim2.fromOffset(120, 120),
	BackgroundTransparency = 1, Image = Ui.HEAD, ScaleType = Enum.ScaleType.Fit, ZIndex = 9, Rotation = 8,
}, cardRoot)
Ui.deco(cardRoot, "✨", UDim2.fromOffset(456, -6), 30, 0).ZIndex = 9
Ui.deco(panel, "❄️", UDim2.fromOffset(500, 40), 30, 10, 0.35)
Ui.deco(panel, "❄️", UDim2.fromOffset(24, 86), 22, -12, 0.35)

-- the count
local countBox = create("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 14), Size = UDim2.fromOffset(150, 64), BackgroundColor3 = WHITE, ZIndex = 3,
}, panel)
corner(countBox, 18)
create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(255, 190, 210), Thickness = 3 }, countBox)
create("TextLabel", {
	Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, FontFace = Ui.BOLD,
	TextSize = 15, TextColor3 = Ui.INK, Text = "찾은 산타", ZIndex = 4,
}, countBox)
local countText = create("TextLabel", {
	Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, FontFace = Ui.BOLD,
	TextSize = 20, TextColor3 = Ui.INK, RichText = true, Text = "", ZIndex = 4,
}, countBox)
local close = Ui.pill(cardRoot, {
	Class = "TextButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -14, 0, 18), Size = UDim2.fromOffset(44, 44),
	TextSize = 24, Text = "X", ZIndex = 9, AutoButtonColor = true,
}, Ui.RED, WHITE) :: any

-- today's hint
local hint = create("TextLabel", {
	Position = UDim2.fromOffset(24, 86), Size = UDim2.new(1, -48, 0, 24), BackgroundTransparency = 1, FontFace = Ui.BOLD,
	TextSize = 16, TextColor3 = Ui.INK, RichText = true, TextScaled = true, Text = "", ZIndex = 3,
}, panel)
create("UITextSizeConstraint", { MaxTextSize = 17 }, hint)

-- the 20 cards
local grid = create("Frame", { Position = UDim2.fromOffset(18, 120), Size = UDim2.new(1, -36, 0, 268), BackgroundTransparency = 1, ZIndex = 3 }, panel)
create("UIGridLayout", { CellSize = UDim2.new(0.1, -6, 0.5, -6), CellPadding = UDim2.fromOffset(6, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
type Card = { button: TextButton, pic: ImageLabel, label: TextLabel, mark: TextLabel, date: TextLabel, today: TextLabel, stroke: UIStroke }
local cards: {Card} = {}
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("SantaHunt") :: RemoteFunction

for n, santa in ipairs(Config.Santas) do
	local b = create("TextButton", { Name = "Day" .. n, LayoutOrder = n, BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ZIndex = 3 }, grid)
	corner(b, 14)
	local stroke = create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(240, 214, 224), Thickness = 2 }, b)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(244, 240, 246)) }, b)
	local date = Ui.pill(b, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -8, 0, 24), TextSize = 14,
		Text = Config.dateText(n), ZIndex = 5,
	}, Ui.GREEN, nil)
	local pic = create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.new(1, -4, 0.62, -22),
		BackgroundTransparency = 1, Image = santa.image or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 4,
	}, b)
	local mark = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.new(1, -4, 0.62, -22),
		BackgroundTransparency = 1, FontFace = Ui.BOLD, TextSize = 40, TextColor3 = Ui.GREEN, Text = "", ZIndex = 5,
	}, b)
	create("UIStroke", { Color = WHITE, Thickness = 2 }, mark)
	local todayTag = Ui.pill(b, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 6), Size = UDim2.fromOffset(58, 30), TextSize = 16,
		Text = "오늘!", ZIndex = 7, Visible = false,
	}, Ui.RED, WHITE)
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -6, 0, 18), BackgroundTransparency = 1,
		FontFace = Ui.BOLD, TextScaled = true, TextColor3 = Ui.INK, Text = "", ZIndex = 5,
	}, b)
	create("UITextSizeConstraint", { MaxTextSize = 13 }, label)
	cards[n] = { button = b, pic = pic, label = label, mark = mark, date = date, today = todayTag, stroke = stroke }
	b.Activated:Connect(function()
		if not Config.has(mask(), n) then return end
		local ok, done = pcall(function() return remote:InvokeServer("Hold", n) end)
		if ok and done then BottomNotice.show(string.format("🧸 %s 인형을 들었어요!", santa.name), Ui.RED) end
	end)
end

-- the tip and the decorations at the bottom
local tip = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(400, 40), BackgroundColor3 = WHITE,
	FontFace = Ui.BOLD, TextSize = 16, TextColor3 = Ui.INK, Text = "❄️  찾은 산타를 누르면 인형으로 들 수 있어요!  🎁", ZIndex = 3,
}, panel)
corner(tip, 999)
create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(255, 200, 216), Thickness = 2 }, tip)
Ui.deco(cardRoot, "🎄", UDim2.new(0, 26, 1, -40), 62, -6)
Ui.deco(cardRoot, "🎁", UDim2.new(0, 92, 1, -28), 44, 4)
Ui.deco(cardRoot, "🎄", UDim2.new(1, -28, 1, -40), 62, 6)
Ui.deco(cardRoot, "🎁", UDim2.new(1, -92, 1, -28), 40, -6)

local function refresh()
	local m = mask()
	local today = Config.dayNow()
	local ended = Config.ended()
	title.Text = if ended
		then '<font color="#E23442">2026 산타</font> <font color="#22965A">앨범</font>'
		else '<font color="#E23442">미니 산타</font> <font color="#22965A">찾기</font>'
	titleShadow.Text = (title.Text:gsub("<[^>]+>", ""))
	countText.Text = string.format('<font size="30" color="#E23442">%d</font> / %d', Config.count(m), Config.Days)
	if today then
		hint.Text = string.format('오늘의 산타 (<font color="#E23442">%s</font>) : %s', Config.dateText(today), Config.Santas[today].hint)
	elseif ended then
		hint.Text = "이벤트가 끝났어요. 찾은 산타는 언제든 인형으로 들 수 있어요!"
	else
		hint.Text = string.format('<font color="#E23442">%s</font>부터 매일 한 명씩 산타가 숨어요!', Config.dateText(1))
	end
	for n, c in ipairs(cards) do
		local found = Config.has(m, n)
		local future = (today == nil and not ended) or (today ~= nil and n > today)
		local isToday = n == today
		c.pic.Visible = not future
		c.pic.ImageColor3 = if found then WHITE else Color3.fromRGB(40, 36, 44)
		c.mark.Text = if future then "?" else ""
		c.today.Visible = isToday and not found
		c.label.Text = if found then Config.Santas[n].name elseif future then "" else "???"
		c.label.TextColor3 = if found then Ui.RED else Ui.INK
		c.stroke.Color = if isToday then Ui.PINK else Color3.fromRGB(240, 214, 224)
		c.stroke.Thickness = if isToday then 4 else 2
		c.button.BackgroundColor3 = if isToday then Color3.fromRGB(255, 236, 242) else WHITE
		c.date.BackgroundColor3 = if isToday or found then Ui.RED else Ui.GREEN
	end
end

local function setOpen(on: boolean)
	if on then
		refresh()
		place()
	end
	gui.Enabled = on
	if on then Popups.opened("SantaAlbum", function() setOpen(false) end) else Popups.closed("SantaAlbum") end
end
close.Activated:Connect(function() setOpen(false) end)
dim.Activated:Connect(function() setOpen(false) end)
player:GetAttributeChangedSignal("SantaFound"):Connect(function() if gui.Enabled then refresh() end end)
UiBus.OpenSantaAlbum.Event:Connect(function() setOpen(true) end)

-- 🎅 in the top bar while the hunt runs
local button = create("TextButton", {
	Name = "SantaHuntButton", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "🎅", TextScaled = true,
	TextColor3 = WHITE, Visible = Config.dayNow() ~= nil,
}, create("ScreenGui", { Name = "SantaHuntButtonGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, playerGui))
corner(button, 999)
create("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0.18, 0), PaddingRight = UDim.new(0.18, 0) }, button)
TopBar.add(button, 6)
button.Activated:Connect(function() setOpen(not gui.Enabled) end)

-- today's Santa: gone on this screen once found
local function hideFound()
	local folder = Workspace:FindFirstChild("SantaHunt")
	local santa = folder and folder:FindFirstChild("MiniSanta")
	if not santa then return end
	local day = santa:GetAttribute("Day")
	local found = typeof(day) == "number" and Config.has(mask(), day)
	for _, d in ipairs(santa:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = if found then 1 else 0
		elseif d:IsA("ProximityPrompt") then d.Enabled = not found
		elseif d:IsA("ParticleEmitter") then d.Enabled = not found end
	end
end
task.spawn(function()
	local folder = Workspace:WaitForChild("SantaHunt", 60)
	if folder then
		folder.ChildAdded:Connect(function() task.wait(0.5) hideFound() end)
		folder.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then task.defer(hideFound) end end)
	end
	hideFound()
end)
player:GetAttributeChangedSignal("SantaFound"):Connect(hideFound)

-- a find: the shaking black box, then the found-a-Santa popup (D-2044)
player:GetAttributeChangedSignal("SantaJustFound"):Connect(function()
	local n = player:GetAttribute("SantaJustFound")
	local santa = typeof(n) == "number" and Config.Santas[n]
	if not santa then return end
	task.spawn(Ui.reveal, santa)
end)

-- the 🎅 button comes and goes with the days (also for someone online at 05:00)
task.spawn(function()
	local hinted = false
	while true do
		local today = Config.dayNow()
		button.Visible = today ~= nil
		if today and not hinted then
			hinted = true
			task.delay(12, function()
				if not Config.has(mask(), today) then
					BottomNotice.show(string.format("🎅 오늘의 산타: %s", Config.Santas[today].hint), Ui.RED, 10, { top = true })
				end
			end)
		end
		task.wait(30)
	end
end)
