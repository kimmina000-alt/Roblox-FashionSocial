--!strict
-- (D-1878) The mini Santa hunt on this screen (Shared/SantaHuntConfig, SantaHuntService):
-- * 🎅 in the top bar (TopBar order 6, the opening event's 🎁 place: it ends when the hunt starts)
--   while the hunt runs; afterwards the album opens from ☰ (UiBus.OpenSantaAlbum).
-- * The 산타 도감 window: today's hint, then 20 cards (date, the Santa in a viewport, its name):
--   found = the Santa in colour (a tap holds it as a plush, remote SantaHunt "Hold"), a past day
--   not found = a black silhouette, today not found = a silhouette with "오늘!", a later day = 🎁 ?.
--   After the event the same window is the "2026 미니 산타 앨범".
-- * Today's Santa vanishes on this screen once found; a find (attribute SantaJustFound) plays the
--   shaking black box reveal (RewardReveal "santa").
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
local RewardReveal = require(script.Parent:WaitForChild("RewardReveal"))
local BottomNotice = require(script.Parent:WaitForChild("BottomNotice"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local T = Config.Theme
local WHITE = Color3.new(1, 1, 1)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function mask(): number
	local m = player:GetAttribute("SantaFound")
	return if typeof(m) == "number" then m else 0
end

-- the window
local gui = create("ScreenGui", { Name = "SantaAlbumGui", ResetOnSpawn = false, DisplayOrder = 42, IgnoreGuiInset = true, Enabled = false }, playerGui)
local dim = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false }, gui)
local window = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = WHITE }, gui)
corner(window, 22)
create("UIStroke", { Color = WHITE, Thickness = 3 }, window)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.bgTop, T.bgBottom) }, window)
create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, window)
-- (like the attendance window, D-1877: between Roblox's top buttons and the screen's bottom)
local function place()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local vp = camera.ViewportSize
	local inset = GuiService.TopbarInset
	local top = (if inset.Height > 0 then inset.Max.Y else 0) + 6
	local room = math.max(200, vp.Y - top - 6)
	local h = math.min(420, room)
	window.Size = UDim2.fromOffset(math.min(680, vp.X * 0.94), h)
	window.Position = UDim2.new(0.5, 0, 0, top + math.max(0, (room - h) / 2))
end
place()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place) end

create("TextLabel", {
	Size = UDim2.new(1, -120, 0, 16), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 13, TextColor3 = T.second,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "OHU CHRISTMAS · 매일 한 명씩 숨어 있어요",
}, window)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -120, 0, 34), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 30,
	TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, window)
create("UIStroke", { Color = WHITE, Thickness = 2 }, title)
local progress = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 6), Size = UDim2.fromOffset(110, 52), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.15, FontFace = BOLD, TextSize = 15, TextColor3 = T.ink, RichText = true, Text = "",
}, window)
corner(progress, 14)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = T.second,
	Text = "X", TextColor3 = WHITE, FontFace = BOLD, TextSize = 18,
}, window)
corner(close, 18)
create("UIStroke", { Color = WHITE, Thickness = 2 }, close)
local hint = create("TextLabel", {
	Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25,
	FontFace = BOLD, TextSize = 14, TextColor3 = T.ink, TextWrapped = true, Text = "",
}, window)
corner(hint, 13)
create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, hint)
local footer = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
	FontFace = BOLD, TextSize = 12, TextColor3 = T.ink, Text = "찾은 산타를 누르면 인형으로 들 수 있어요 🧸",
}, window)
local grid = create("Frame", { Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 1, -128), BackgroundTransparency = 1 }, window)
create("UIGridLayout", { CellSize = UDim2.new(0.1, -5, 0.5, -3), CellPadding = UDim2.fromOffset(5, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

type Card = { button: TextButton, vp: ImageLabel, label: TextLabel, mark: TextLabel, date: TextLabel }
local cards: {Card} = {}
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("SantaHunt") :: RemoteFunction

for n, santa in ipairs(Config.Santas) do
	local b = create("TextButton", { Name = "Day" .. n, LayoutOrder = n, BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false }, grid)
	corner(b, 10)
	local stroke = create("UIStroke", { Color = T.secondSoft, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local date = create("TextLabel", {
		Size = UDim2.new(1, 0, 0.16, 0), BackgroundColor3 = T.second, FontFace = BOLD, TextScaled = true, TextColor3 = WHITE,
		Text = Config.dateText(n),
	}, b)
	corner(date, 10)
	create("UITextSizeConstraint", { MaxTextSize = 12 }, date)
	-- (D-2043) the Santa's picture (rendered in Blender, SantaHuntConfig image): no 3D in the album; a
	-- black ImageColor3 makes the silhouette of a Santa not found
	local vp = create("ImageLabel", {
		Position = UDim2.fromScale(0, 0.17), Size = UDim2.fromScale(1, 0.6), BackgroundTransparency = 1,
		Image = santa.image or "", ScaleType = Enum.ScaleType.Fit,
	}, b)
	local mark = create("TextLabel", {
		Position = UDim2.fromScale(0, 0.17), Size = UDim2.fromScale(1, 0.6), BackgroundTransparency = 1, FontFace = BOLD,
		TextScaled = true, TextColor3 = T.accent, Text = "", ZIndex = 3,
	}, b)
	create("UITextSizeConstraint", { MaxTextSize = 30 }, mark)
	local label = create("TextLabel", {
		Position = UDim2.new(0.04, 0, 0.78, 0), Size = UDim2.new(0.92, 0, 0.2, 0), BackgroundTransparency = 1, FontFace = BOLD,
		TextScaled = true, TextWrapped = true, TextColor3 = T.ink, Text = "",
	}, b)
	create("UITextSizeConstraint", { MaxTextSize = 11 }, label)
	b:SetAttribute("Stroke", true)
	cards[n] = { button = b, vp = vp, label = label, mark = mark, date = date }
	b.Activated:Connect(function()
		if not Config.has(mask(), n) then return end
		local ok, done = pcall(function() return remote:InvokeServer("Hold", n) end)
		if ok and done then BottomNotice.show(string.format("🧸 %s 인형을 들었어요!", santa.name), T.accent) end
	end)
	local _ = stroke
end

local function refresh()
	local m = mask()
	local today = Config.dayNow()
	local ended = Config.ended()
	title.Text = if ended then "🎅 " .. Config.AlbumTitle else "🎅 " .. Config.Title
	progress.Text = string.format('찾은 산타<br/><font size="22" color="#D62C40">%d</font> / %d', Config.count(m), Config.Days)
	if today then
		hint.Text = string.format("오늘의 산타 (%s): %s", Config.dateText(today), Config.Santas[today].hint)
	elseif ended then
		hint.Text = "이벤트가 끝났어요. 찾은 산타는 언제든 인형으로 들 수 있어요!"
	else
		hint.Text = string.format("%s부터 매일 한 명씩 산타가 숨어요!", Config.dateText(1))
	end
	for n, c in ipairs(cards) do
		local found = Config.has(m, n)
		local future = today == nil and not ended or (today ~= nil and n > today)
		c.vp.Visible = not future
		c.vp.ImageColor3 = if found then WHITE else Color3.new(0, 0, 0)
		c.vp.ImageTransparency = if found then 0 else 0.15
		c.mark.Text = if future then "?" elseif (n == today and not found) then "오늘!" else ""
		c.mark.TextColor3 = if future then T.second else T.accent
		c.label.Text = if found then Config.Santas[n].name elseif future then "" else "???"
		c.button.BackgroundColor3 = if found then T.accentSoft else WHITE
		local stroke = c.button:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = if n == today then T.accent else T.secondSoft end
		c.date.BackgroundColor3 = if found then T.accent else T.second
	end
end

local function setOpen(on: boolean)
	if on then refresh() end
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

-- a find: the shaking black box, then the Santa
player:GetAttributeChangedSignal("SantaJustFound"):Connect(function()
	local n = player:GetAttribute("SantaJustFound")
	local santa = typeof(n) == "number" and Config.Santas[n]
	if not santa then return end
	local ev = table.clone(T) :: any
	ev.santaLook = santa.look
	ev.santaName = santa.name
	ev.santaImage = santa.image
	task.spawn(RewardReveal.show, "santa", ev)
end)

-- the 🎅 button comes and goes with the days (also for someone online at 05:00)
task.spawn(function()
	local hinted = false
	while true do
		local today = Config.dayNow()
		button.Visible = today ~= nil
		if not today and gui.Enabled and not Config.ended() and not Config.started() then setOpen(false) end
		if today and not hinted then
			hinted = true
			task.delay(12, function()
				if not Config.has(mask(), today) then
					BottomNotice.show(string.format("🎅 오늘의 산타: %s", Config.Santas[today].hint), T.accent, 10, { top = true })
				end
			end)
		end
		task.wait(30)
	end
end)
