--!strict
-- (D-1366, user 2026-11-13, a mock-up "한국의 오후 · OHU GRAND OPENING 출석 이벤트") The
-- attendance window in the mock-up's layout: the title, the period, 14 day cards in two rows of
-- seven (coins, the limited frame at 7, the title at 14), each 받기 완료 / 오늘 받았어요 / 받기
-- (today's, a button) / 기다려요, and the limited-title line (D-1397). It opens by itself while
-- today's 받기 waits (D-1401: the tap counts it; after the first-visit tour and any other window),
-- and from the 🎁 button in the top bar while an event runs. Data: player attributes from
-- OpeningEventService.
-- (D-1874) every attendance event of OpeningEventConfig.Events: the window is built for the event
-- running now (words and colours from its config: the opening's cherry pink and lilac, the
-- winter's icy blue) and built again when the next one starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Config = require(FashionGame:WaitForChild("Shared"):WaitForChild("OpeningEventConfig"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local Sfx = require(script.Parent:WaitForChild("Sfx")) -- (D-1695)
local RewardReveal = require(script.Parent:WaitForChild("RewardReveal")) -- (D-1870)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

type Card = { frame: Frame, head: TextLabel, icon: TextLabel, label: TextLabel, status: TextButton }
type Built = { ev: any, window: Frame, progress: TextLabel, period: TextLabel, close: TextButton, cards: {Card} }
local built: Built? = nil
local setOpen: (on: boolean) -> ()

local function build(ev: any): Built
	local window = create("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.94, 0, 0.86, 0), BackgroundColor3 = Color3.fromRGB(252, 240, 248),
	}, gui)
	corner(window, 22)
	create("UISizeConstraint", { MaxSize = Vector2.new(680, 420) }, window)
	create("UIStroke", { Color = WHITE, Thickness = 3 }, window)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(ev.bgTop, ev.bgBottom) }, window)
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, window)

	-- header
	create("TextLabel", {
		Name = "Small", Size = UDim2.new(1, -120, 0, 16), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 13,
		TextColor3 = ev.accent, TextXAlignment = Enum.TextXAlignment.Left, Text = ev.small,
	}, window)
	local title = create("TextLabel", {
		Name = "Title", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -120, 0, 34), BackgroundTransparency = 1,
		FontFace = BOLD, TextSize = 30, TextColor3 = ev.accent, TextXAlignment = Enum.TextXAlignment.Left, Text = ev.title,
	}, window)
	create("UIStroke", { Color = WHITE, Thickness = 2 }, title)
	create("TextLabel", {
		Name = "Sub", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, -120, 0, 18), BackgroundTransparency = 1,
		FontFace = BOLD, TextSize = 14, TextColor3 = ev.ink, TextXAlignment = Enum.TextXAlignment.Left, Text = ev.sub,
	}, window)
	local progress = create("TextLabel", {
		Name = "Progress", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 6), Size = UDim2.fromOffset(110, 52),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, FontFace = BOLD, TextSize = 15, TextColor3 = ev.ink, Text = "",
		RichText = true,
	}, window)
	corner(progress, 14)
	local close = create("TextButton", {
		Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = ev.second, Text = "X", TextColor3 = WHITE, FontFace = BOLD, TextSize = 18,
	}, window)
	corner(close, 18)
	create("UIStroke", { Color = WHITE, Thickness = 2 }, close)

	-- period row
	local period = create("TextLabel", {
		Name = "Period", Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25, FontFace = BOLD, TextSize = 14, TextColor3 = ev.ink, Text = "",
	}, window)
	corner(period, 13)

	-- the 14 cards (D-1397: room for the limited-title line under them)
	local grid = create("Frame", { Name = "Days", Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 1, -136), BackgroundTransparency = 1 }, window)
	create("UIGridLayout", { CellSize = UDim2.new(1 / 7, -6, 0.5, -4), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local cards: {Card} = {}
	for n = 1, ev.Goal do
		local reward = ev.Rewards[n]
		local special = reward.frame or reward.title
		local f = create("Frame", { Name = "Day" .. n, LayoutOrder = n, BackgroundColor3 = WHITE, BackgroundTransparency = 0.1 }, grid)
		corner(f, 12)
		create("UIStroke", { Color = if special then ev.special else ev.secondSoft, Thickness = 2 }, f)
		local head = create("TextLabel", {
			Size = UDim2.new(1, 0, 0.24, 0), BackgroundColor3 = if special then ev.special else ev.second, FontFace = BOLD, TextScaled = true,
			TextColor3 = WHITE, Text = n .. "일차",
		}, f)
		corner(head, 12)
		create("UITextSizeConstraint", { MaxTextSize = 14 }, head)
		local icon = create("TextLabel", {
			Position = UDim2.fromScale(0, 0.24), Size = UDim2.new(1, 0, 0.34, 0), BackgroundTransparency = 1, TextScaled = true,
			FontFace = BOLD, TextColor3 = Color3.fromRGB(246, 196, 80),
			Text = if reward.coins then "₩" else "", -- (the game's coin mark, as in the top bar)
		}, f)
		if reward.frame then
			-- (D-1695, user 2026-11-17: "한정 포토 프레임 그림 수정. 검은색 박스에 물음표 띄우기") the limited frame is
			-- a surprise: a black box with a white ?
			local box = create("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.41), Size = UDim2.fromScale(0.42, 0.28),
				BackgroundColor3 = Color3.new(0, 0, 0), FontFace = BOLD, TextScaled = true, TextColor3 = WHITE, Text = "?",
			}, f)
			create("UIAspectRatioConstraint", { AspectRatio = 1 }, box)
			corner(box, 6)
			create("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }, box)
		end
		create("UITextSizeConstraint", { MaxTextSize = 26 }, icon)
		if reward.title then
			-- (D-1397) the title as it shows over the name (NameTagService)
			local plate = create("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.41), Size = UDim2.new(0.92, 0, 0.17, 0),
				BackgroundColor3 = ev.plate, BackgroundTransparency = 0.05, TextScaled = true,
				FontFace = BOLD, TextColor3 = ev.plateText, Text = ev.TitleText,
			}, f)
			corner(plate, 3)
			create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = ev.plateEdge, Thickness = 1.5 }, plate)
			create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, plate)
		end
		local label = create("TextLabel", {
			Position = UDim2.fromScale(0.04, 0.58), Size = UDim2.new(0.92, 0, 0.2, 0), BackgroundTransparency = 1, TextScaled = true,
			FontFace = BOLD, TextColor3 = if reward.title then ev.accent else ev.ink,
			Text = if reward.title then "한정 칭호 증정!" else Config.rewardText(reward, ev),
		}, f)
		create("UITextSizeConstraint", { MaxTextSize = 12 }, label)
		-- (D-1401) a button: today's card says 받기, and the tap counts the attendance
		local status = create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0.86, 0, 0.17, 0),
			BackgroundColor3 = ev.secondSoft, FontFace = BOLD, TextScaled = true, TextColor3 = ev.ink, Text = "", AutoButtonColor = false,
		}, f)
		corner(status, 8)
		create("UITextSizeConstraint", { MaxTextSize = 11 }, status)
		cards[n] = { frame = f, head = head, icon = icon, label = label, status = status }
	end

	-- (D-1397) the limited title, at the bottom
	local limited = create("TextLabel", {
		Name = "Limited", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = ev.plate, BackgroundTransparency = 0.05, FontFace = BOLD, TextScaled = true,
		TextColor3 = ev.plateText, RichText = true, Text = ev.limited,
	}, window)
	corner(limited, 12)
	create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = ev.plateEdge, Thickness = 1.5 }, limited)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, limited)
	create("UITextSizeConstraint", { MaxTextSize = 14 }, limited)

	local b: Built = { ev = ev, window = window, progress = progress, period = period, close = close, cards = cards }
	close.Activated:Connect(function() setOpen(false) end)
	-- (D-1401) 받기 on today's card: the server counts the attendance and gives the reward
	local claiming = false
	for n, c in ipairs(cards) do
		c.status.Activated:Connect(function()
			local count = player:GetAttribute("OpeningCount")
			count = if typeof(count) == "number" then count else 0
			if claiming or n ~= count + 1 or player:GetAttribute("OpeningCanClaim") ~= true then return end
			local claimRemote = FashionGame:WaitForChild("Remotes"):FindFirstChild("OpeningEvent")
			if not claimRemote or not claimRemote:IsA("RemoteFunction") then return end
			claiming = true
			c.status.Text = "..."
			local ok, done = pcall(function() return (claimRemote :: RemoteFunction):InvokeServer("Claim") end)
			local reward = ev.Rewards[n]
			if ok and done and reward and (reward.frame or reward.title) then
				-- (D-1870) the limited frame / title come out of the shaking black box, 짜잔
				task.spawn(RewardReveal.show, if reward.frame then "frame" else "title", ev)
			elseif ok and done then
				pcall(function() Sfx.play("coin") end) -- (D-1695: the reward's coin sound)
			end
			claiming = false
			if built then
				local refreshNow = (built :: any).refresh
				if refreshNow then refreshNow() end
			end
		end)
	end
	return b
end

local function refresh()
	local b = built
	if not b then return end
	local ev = b.ev
	local count = player:GetAttribute("OpeningCount")
	count = if typeof(count) == "number" then count else 0
	local just = player:GetAttribute("OpeningJustClaimed")
	local canClaim = player:GetAttribute("OpeningCanClaim") == true
	local day = Config.dayNow(nil, ev)
	if player:GetAttribute("OpeningEventKey") ~= ev.key then -- (the server has not caught up with a new event yet)
		count, just, canClaim = 0, nil, false
	end
	b.progress.Text = string.format('출석<br/><font size="22" color="%s">%d</font> / %d', ev.titleHex, count, ev.Goal)
	b.period.Text = string.format("📅 %s · %d일 동안 %d번 출석하면 완료!%s", Config.periodText(ev), ev.Days, ev.Goal,
		if day then string.format("  (오늘은 %d일째)", day) else "  (이벤트가 끝났어요)")
	for n, c in ipairs(b.cards) do
		local reward = ev.Rewards[n]
		local special = reward.frame or reward.title
		if n <= count then
			c.frame.BackgroundColor3 = ev.accentSoft
			c.head.BackgroundColor3 = ev.accent
			c.status.BackgroundColor3 = ev.accent
			c.status.TextColor3 = WHITE
			c.status.Text = if n == just then "오늘 받았어요!" else "받기 완료!"
		elseif n == count + 1 and canClaim then
			-- (D-1401) today's: 받기 (the tap counts it)
			c.frame.BackgroundColor3 = WHITE
			c.head.BackgroundColor3 = ev.accent
			c.status.BackgroundColor3 = ev.accent
			c.status.TextColor3 = WHITE
			c.status.Text = "받기"
		else
			c.frame.BackgroundColor3 = WHITE
			c.head.BackgroundColor3 = if special then ev.special else ev.second
			c.status.BackgroundColor3 = ev.secondSoft
			c.status.TextColor3 = ev.ink
			c.status.Text = "기다려요"
		end
	end
end

-- the window for the event running now (built again when the next event starts; nil between events)
local function ensureBuilt(): boolean
	local ev = Config.current()
	if built and (not ev or built.ev.key ~= ev.key) then
		built.window:Destroy()
		built = nil
	end
	if ev and not built then
		built = build(ev);
		(built :: any).refresh = refresh
	end
	return built ~= nil
end

setOpen = function(on: boolean)
	if on and not ensureBuilt() then on = false end
	if on then refresh() end
	gui.Enabled = on
	if on then Popups.opened("OpeningEvent", function() setOpen(false) end) else Popups.closed("OpeningEvent") end
end
dim.Activated:Connect(function() setOpen(false) end)
for _, name in ipairs({ "OpeningCount", "OpeningJustClaimed", "OpeningCanClaim", "OpeningEventKey" }) do
	player:GetAttributeChangedSignal(name):Connect(function() if gui.Enabled then refresh() end end)
end

-- 🎁 in the top bar while an event runs
local button = create("TextButton", {
	Name = "OpeningEventButton", BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.35,
	Text = "🎁", TextScaled = true, TextColor3 = WHITE, Visible = Config.dayNow() ~= nil,
}, create("ScreenGui", { Name = "OpeningEventButtonGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, playerGui)) -- (inset ignored like the other top bar buttons: 2P test 2026-11-13)
corner(button, 999)
create("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0.18, 0), PaddingRight = UDim.new(0.18, 0) }, button)
TopBar.add(button, 6)
button.Activated:Connect(function() setOpen(not gui.Enabled) end)
-- (D-1873) the 🎁 goes away by itself when the event ends (also for someone who stays past 05:00)
task.spawn(function()
	while true do
		task.wait(30)
		local on = Config.dayNow() ~= nil
		if button.Visible ~= on then
			button.Visible = on
			if not on and gui.Enabled then setOpen(false) end
		end
		-- (D-1874) the next event started: its window next time (an open old one closes)
		if built and Config.current() ~= built.ev then
			if gui.Enabled then setOpen(false) end
			ensureBuilt()
		end
	end
end)

-- today's 받기 waiting: the window once, after the tour and other windows (D-1401)
task.spawn(function()
	local t0 = os.clock()
	-- (D-1690) Studio never counts attendance: with the first-visit test switch on (FirstGoalTest) the
	-- window shows after the tour anyway, to see the first visit in order
	local TEST = game:GetService("RunService"):IsStudio() and FashionGame:GetAttribute("FirstGoalTest") == true
	-- (D-1731) in Studio the window opens by itself only with FirstGoalTest on (Studio never writes the
	-- day it was shown, so it opened on every Play); the 🎁 button still opens it. Live is unchanged
	if game:GetService("RunService"):IsStudio() and not TEST then return end
	-- (D-1691 / D-1693) once each event day (the day turns at 05:00 KST): the server says when (OpeningShowWindow)
	while not TEST and player:GetAttribute("OpeningShowWindow") ~= true and os.clock() - t0 < 30 do task.wait(0.5) end
	if not TEST and player:GetAttribute("OpeningShowWindow") ~= true then return end
	while playerGui:FindFirstChild("OHULoading") do task.wait(1) end
	task.wait(4) -- (the first-visit tour starts 1.5 s after the loading screen: it goes first)
	-- (D-1981, 2026-11-21: fewer windows in the first minute) only after the player's first move (20 studs)
	-- or first interaction, both told by the server (Analytics: Moved / Interacted)
	while player:GetAttribute("Moved") ~= true and player:GetAttribute("Interacted") ~= true do task.wait(1) end
	task.wait(2)
	while player:GetAttribute("TourActive") or Popups.anyOpen() do task.wait(1) end
	task.wait(1)
	setOpen(true) -- (no sound as it opens: user 2026-11-17, "출석 창은 소리 넣지 말자")
end)
