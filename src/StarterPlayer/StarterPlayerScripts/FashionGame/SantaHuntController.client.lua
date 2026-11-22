--!strict
-- (D-1878) The mini Santa hunt on this screen (Shared/SantaHuntConfig, SantaHuntService):
-- * 🎅 in the top bar (TopBar order 6, the opening event's 🎁 place: it ends when the hunt starts)
--   while the hunt runs; afterwards the album opens from ☰ (UiBus.OpenSantaAlbum).
-- * The 산타 도감 = the user's mock-up itself (D-2044 / D-2045): its frame cut out (SantaUi.IMG_ALBUM), the
--   20 cards from its card pictures (green date tag; today's red tag, pink edge and "오늘!"), the Santa's
--   picture or a grey silhouette, its name or ???, a green ? for later days, the count and today's hint.
--   A tap on a found Santa holds it as a plush (remote SantaHunt "Hold"). Kept after the event as an album.
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

---------------------------------------------------------------------------- the album (D-2045: the mock-up's own frame)
-- SantaUi.IMG_ALBUM is the user's mock-up cut out (1052 x 920 design units = its pixels). Its card area is
-- see-through: a pale panel under it, the 20 cards (mock-up card pictures) on the panel, the frame on top
-- (so the trees' tips stay in front of the cards, as in the mock-up). The count and the hint are drawn at
-- the mock-up's spots; the ✕ is the frame's own, with a clear button over it.
local DW, DH = 1052, 920
local HOLE = { x0 = 42, y0 = 329, x1 = 1011, y1 = 794 }
local gui = create("ScreenGui", { Name = "SantaAlbumGui", ResetOnSpawn = false, DisplayOrder = 42, IgnoreGuiInset = true, Enabled = false }, playerGui)
local dim = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false }, gui)
local stage = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(DW, DH), BackgroundTransparency = 1 }, gui)
local scale = create("UIScale", {}, stage)
local function place()
	local s, cy = Ui.fit(DW, DH)
	scale.Scale = s
	stage.Position = UDim2.new(0.5, 0, 0, cy)
end
place()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place) end

local under = create("Frame", {
	Position = UDim2.fromOffset(HOLE.x0 - 2, HOLE.y0 - 2), Size = UDim2.fromOffset(HOLE.x1 - HOLE.x0 + 4, HOLE.y1 - HOLE.y0 + 4),
	BackgroundColor3 = Color3.fromRGB(243, 241, 244), ZIndex = 1,
}, stage)
corner(under, 14)
local frame = create("ImageLabel", { Size = UDim2.fromOffset(DW, DH), BackgroundTransparency = 1, Image = Ui.IMG_ALBUM, ZIndex = 5 }, stage)

-- the count (in the frame's "찾은 산타" box) and the hint line
local countText = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(846, 264), Size = UDim2.fromOffset(150, 50), BackgroundTransparency = 1,
	FontFace = Ui.FRED, TextSize = 30, TextColor3 = Ui.PURPLE, RichText = true, Text = "", ZIndex = 6,
}, stage)
local hint = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(474, 302), Size = UDim2.fromOffset(640, 30), BackgroundTransparency = 1,
	FontFace = Ui.BOLD, TextSize = 21, TextScaled = true, TextColor3 = Ui.PURPLE, RichText = true, Text = "", ZIndex = 6,
}, stage)
create("UITextSizeConstraint", { MaxTextSize = 21 }, hint)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(986, 218), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Text = "", ZIndex = 7,
}, stage)

-- the 20 cards: 2 rows of 10 like the mock-up (row tops 348 / 577, 215 tall)
local LEFT, RIGHT, GAP, CH = 50, 1006, 6, 215
local CW = (RIGHT - LEFT - GAP * 9) / 10
local ROWS = { 348, 577 }
type Card = { cell: Frame, normal: ImageLabel, todayImg: ImageLabel, pic: ImageLabel, label: TextLabel, mark: TextLabel, date: TextLabel, badge: TextLabel }
local cards: {Card} = {}
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("SantaHunt") :: RemoteFunction

for n, santa in ipairs(Config.Santas) do
	local col, row = (n - 1) % 10, (n - 1) // 10
	local cell = create("TextButton", {
		Name = "Day" .. n, Position = UDim2.fromOffset(LEFT + col * (CW + GAP), ROWS[row + 1]), Size = UDim2.fromOffset(CW, CH),
		BackgroundTransparency = 1, Text = "", ZIndex = 2,
	}, stage)
	local normal = create("ImageLabel", {   -- body (2, 2)..(80, 219) of 83 x 222
		Position = UDim2.fromOffset(-2, -2), Size = UDim2.new(1, 5, 1, 5), BackgroundTransparency = 1, Image = Ui.IMG_CARD,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(26, 46, 57, 190), ZIndex = 2,
	}, cell)
	local todayImg = create("ImageLabel", {   -- body (3, 29)..(104, 247) of 118 x 250
		Position = UDim2.fromOffset(-3, -29), Size = UDim2.new(1, 17, 1, 32), BackgroundTransparency = 1, Image = Ui.IMG_TODAY,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(30, 76, 76, 216), ZIndex = 2, Visible = false,
	}, cell)
	local date = create("TextLabel", {
		Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, FontFace = Ui.FRED,
		TextSize = 20, TextColor3 = WHITE, Text = Config.dateText(n), ZIndex = 4,
	}, cell)
	local pic = create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.new(1, 2, 0, 120),
		BackgroundTransparency = 1, Image = santa.image or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
	}, cell)
	local mark = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1,
		FontFace = Ui.FRED, TextSize = 46, TextColor3 = Color3.fromRGB(36, 150, 104), Text = "?", ZIndex = 4, Visible = false,
	}, cell)
	local badge = Ui.pill(cell, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(84, 42), FontFace = Ui.BOLD,
		TextSize = 21, Text = "오늘!", ZIndex = 5, Visible = false,
	}, Ui.TAG_RED, WHITE)
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(1, -6, 0, 22), BackgroundTransparency = 1,
		FontFace = Ui.BOLD, TextScaled = true, TextColor3 = Ui.PURPLE, Text = "", ZIndex = 4,
	}, cell)
	create("UITextSizeConstraint", { MaxTextSize = 17 }, label)
	cards[n] = { cell = cell :: any, normal = normal, todayImg = todayImg, pic = pic, label = label, mark = mark, date = date, badge = badge }
	cell.Activated:Connect(function()
		if not Config.has(mask(), n) then return end
		local ok, done = pcall(function() return remote:InvokeServer("Hold", n) end)
		if ok and done then BottomNotice.show(string.format("🧸 %s 인형을 들었어요!", santa.name), Ui.RED) end
	end)
end

local function refresh()
	local m = mask()
	local today = Config.dayNow()
	local ended = Config.ended()
	countText.Text = string.format('<font size="44" color="#E2304E">%d</font> / %d', Config.count(m), Config.Days)
	if today then
		hint.Text = string.format('오늘의 산타 <font color="#E22C58">(%s)</font> : %s', Config.dateText(today), Config.Santas[today].hint)
	elseif ended then
		hint.Text = "이벤트가 끝났어요. 찾은 산타는 언제든 인형으로 들 수 있어요!"
	else
		hint.Text = string.format('<font color="#E22C58">%s</font>부터 매일 한 명씩 산타가 숨어요!', Config.dateText(1))
	end
	for n, c in ipairs(cards) do
		local found = Config.has(m, n)
		local future = (today == nil and not ended) or (today ~= nil and n > today)
		local isToday = n == today
		c.normal.Visible = not isToday
		c.todayImg.Visible = isToday
		c.pic.Visible = not future
		-- the mock-up's flat grey silhouette: black at 75 % over the white card
		c.pic.ImageColor3 = if found then WHITE else Color3.new(0, 0, 0)
		c.pic.ImageTransparency = if found then 0 else 0.25
		c.mark.Visible = future
		c.badge.Visible = isToday and not found
		c.label.Text = if found then Config.Santas[n].name elseif future then "" else "???"
		c.label.TextColor3 = if found then Ui.TAG_RED else Ui.PURPLE
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
