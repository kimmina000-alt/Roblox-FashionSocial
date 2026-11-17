--!strict
-- 클럽 첫 안내 (D-1662, user 2026-11-17: "클럽 건물 입장할 때 말고 춤추는 곳 들어가면 처음 오는 사람들한테
-- 튜토리얼 띄우기 / 클럽 안무 버튼, 카메라 버튼, 노래 신청하는 법").
-- The first time a player steps onto the dance floor (the tiles in front of the DJ stage, ClubFloorFX's
-- box, not the club's door or stairs) three cards show one after another, each next to the button it is
-- about in the song banner (ClubQuickBar), with a pulsing ring round that button:
--   ① ♫ 안무 따라 추기      (ClubChoreo, in front of the song title)
--   ② 🎥 무대 카메라          (ClubStageCam, after the title)
--   ③ ≡ 노래 신청            (ClubList: the song list, 신청 on a song)
-- A button that is not shown for the song playing (no choreography / no stage camera) gets the card
-- under the banner without a ring. "다음" goes on, "알겠어요" ends, ✕ ends at once. Seen once: the tip
-- "club1" the server keeps (GuideService "TipSeen"). Black and white like the first goal and the tour.
-- (Studio only: ReplicatedStorage.FashionGame attribute FirstGoalTest = true shows it to an account that
-- has seen it, and nothing is saved, as for the first goal.)

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
local NearButton = require(script.Parent:WaitForChild("NearButton"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local KEY = "club1"
local TEST = RunService:IsStudio() and FashionGame:GetAttribute("FirstGoalTest") == true

-- the dance floor (ClubFloorFX: x 104..152, z -250..-158, floor top -24), a little wider
local X0, X1, Z0, Z1, Y0, Y1 = 100, 156, -254, -154, -32, -8

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function seen(): boolean
	if TEST then return false end
	local ok, keys = pcall(function() return HttpService:JSONDecode(player:GetAttribute("TipsSeen") or "[]") end)
	if not ok or typeof(keys) ~= "table" then return false end
	return table.find(keys, KEY) ~= nil
end

local function markSeen()
	if TEST then return end
	task.spawn(function() pcall(function() remote:InvokeServer("TipSeen", KEY) end) end)
end

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for k, v in pairs(props) do (instance :: any)[k] = v end
	if parent then instance.Parent = parent end
	return instance
end

-- (the buttons are made by ClubQuickBar and live in the song banner, FashionDanceGui.NowPlaying, or in
-- the DJ window's slots while that is open: looked up wherever they are)
local function bannerButton(name: string): GuiObject?
	local b = playerGui:FindFirstChild(name, true)
	return if b and b:IsA("GuiObject") then b else nil
end

type Step = { icon: string, title: string, text: string, button: string }
local STEPS: {Step} = {
	{ icon = "♫", title = "안무 따라 추기", button = "ClubChoreo",
		text = "노래 제목 앞 ♫를 누르면 이 노래 안무를 따라 춰요. 다시 누르면 멈춰요." },
	{ icon = "🎥", title = "무대 카메라", button = "ClubStageCam",
		text = "제목 뒤 카메라를 누르면 음악방송처럼 나를 찍어 줘요. 안무를 켜야 시작돼요." },
	{ icon = "≡", title = "노래 신청", button = "ClubList",
		text = "≡를 눌러 노래 목록을 열고 듣고 싶은 노래의 「신청」을 누르세요. 신청한 순서대로 나와요." },
}

---------------------------------------------------------------- the card and the ring
local gui = create("ScreenGui", { Name = "ClubTutorialGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 31, Enabled = false }, playerGui)
local card = create("Frame", { Size = UDim2.fromOffset(280, 132), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2 }, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
local stroke = create("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.2 }, card)
local head = create("TextLabel", {
	Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -50, 0, 20), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 200),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, card)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 22), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, card)
local body = create("TextLabel", {
	Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 44), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(230, 230, 230), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
local nextButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(84, 26),
	BackgroundColor3 = WHITE, Text = "다음", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = BLACK, AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, nextButton)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = BLACK, Text = "X", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = WHITE, AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, close)
create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)
local pointer = NearButton.pointer(card)

local ring = create("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 50 }, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
local ringStroke = create("UIStroke", { Color = WHITE, Thickness = 3 }, ring)

local running = false
local index = 0
-- (a newcomer who has not done the first goal yet: its card would sit on top of this one; it waits
-- hidden while these cards show and comes back after, unless it was finished meanwhile)
local goalWasOn = false
local function goalGui(): ScreenGui?
	local g = playerGui:FindFirstChild("FirstGoalGui")
	return if g and g:IsA("ScreenGui") then g else nil
end

local function finish()
	running = false
	gui.Enabled = false
	ring.Visible = false
	markSeen()
	local goal = goalGui()
	if goal and goalWasOn then
		local ok, keys = pcall(function() return HttpService:JSONDecode(player:GetAttribute("TipsSeen") or "[]") end)
		local done = ok and typeof(keys) == "table" and table.find(keys, "goal1") ~= nil and not TEST
		if not done then goal.Enabled = true end
	end
end

local function show(i: number)
	index = i
	local s = STEPS[i]
	head.Text = string.format("🎧 클럽 안내 · %d / %d", i, #STEPS)
	title.Text = s.icon .. "  " .. s.title
	body.Text = s.text
	nextButton.Text = if i == #STEPS then "알겠어요" else "다음"
	TweenService:Create(stroke, TweenInfo.new(0.25), { Thickness = 5 }):Play()
	task.delay(0.3, function() TweenService:Create(stroke, TweenInfo.new(0.4), { Thickness = 2 }):Play() end)
end

nextButton.Activated:Connect(function()
	if index >= #STEPS then finish() else show(index + 1) end
end)
close.Activated:Connect(finish)

-- the card next to the step's button (under it, a pointer up), or under the banner's list button
-- when the step's button is not shown for this song; the ring round the button
RunService.Heartbeat:Connect(function()
	if not running then return end
	local goal = goalGui()
	if goal and goal.Enabled then
		goalWasOn = true
		goal.Enabled = false
	end
	local s = STEPS[index]
	local b = s and bannerButton(s.button)
	local anchor = if b and b.Visible then b else bannerButton("ClubList")
	if anchor and anchor.Visible then
		NearButton.place(card, pointer, anchor, 280)
		pointer.Visible = anchor == b
	else
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.45)
		pointer.Visible = false
	end
	if b and b.Visible then
		local inset = GuiService:GetGuiInset()
		local pad = 6
		ring.Visible = true
		ring.Position = UDim2.fromOffset(b.AbsolutePosition.X - pad, b.AbsolutePosition.Y + inset.Y - pad)
		ring.Size = UDim2.fromOffset(b.AbsoluteSize.X + pad * 2, b.AbsoluteSize.Y + pad * 2)
		ringStroke.Transparency = 0.4 + 0.5 * math.sin(os.clock() * 6)
	else
		ring.Visible = false
	end
end)

local function onFloor(): boolean
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r or not r:IsA("BasePart") then return false end
	local p = r.Position
	return p.X > X0 and p.X < X1 and p.Z > Z0 and p.Z < Z1 and p.Y > Y0 and p.Y < Y1
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if seen() then return end
		if onFloor() then
			-- wait a moment for the song banner (it shows inside the club while a song plays)
			for _ = 1, 10 do
				if bannerButton("ClubList") and (bannerButton("ClubList") :: GuiObject).Visible then break end
				task.wait(0.3)
			end
			running = true
			gui.Enabled = true
			show(1)
			while running do task.wait(0.5) end
			return
		end
	end
end)
