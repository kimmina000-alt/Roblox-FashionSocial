--!strict
-- 첫 화면 카드 (D-1980, 2026-11-21: first-visit drop-off. The last 7 days: 91 % skipped the long
-- tour, 58 % of new players left within 3 minutes, from the street or the pocket park.)
-- On a player's first visit, once the loading screen is gone, one card at the bottom (the user picked
-- mock-up B: big square tiles where the thumb is): "어디부터 가 볼까?" with
--   🎧 클럽 가기          (only at night: the club is open 18:00..06:00, ClubConfig.isNightOpen)
--   📸 사진 찍으러 가기    (오후네컷)
--   🎢 놀이공원 가기       (OHU LAND)
-- (D-1982, user 2026-11-21: players now start at the beach / park / club too, away from the guide) a small
-- line under the tiles, "🐰 안내원에게 가기", draws the way to the guide rabbit (UiBus.ShowWay "guide").
-- A tile closes the card and draws the way on the ground (FirstGoalController's dashed way,
-- UiBus.ShowWay with the place key; white by day, neon pink by night). ✕ just closes it.
-- The long tour (TourController) no longer starts by itself: the guide rabbit's question starts it.
-- Seen once: the tip "card1" (and "tour2", so the old tour never starts either) on the server
-- (GuideService "TipSeen"). Analytics: AnalyticsStep "FirstCard" with the choice (Analytics.lua).
-- Studio: shows only with ReplicatedStorage.FashionGame attribute FirstGoalTest = true (as the tour did).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local remote = Remotes:WaitForChild("Guide") :: RemoteFunction
local Popups = require(script.Parent:WaitForChild("Popups"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local KEY = "card1"
local TEST = RunService:IsStudio() and FashionGame:GetAttribute("FirstGoalTest") == true
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for k, v in pairs(props) do (instance :: any)[k] = v end
	if parent then instance.Parent = parent end
	return instance
end

local function seenKeys(): {string}
	local ok, keys = pcall(function() return HttpService:JSONDecode(player:GetAttribute("TipsSeen") or "[]") end)
	return if ok and typeof(keys) == "table" then keys else {}
end

---------------------------------------------------------------- the card
local TILE, GAP = 104, 10
local GUIDE_H = 34
local gui = create("ScreenGui", { Name = "FirstCardGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false }, playerGui)
-- (above the hotbar at the bottom)
local holder = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(TILE, TILE + 34 + GUIDE_H),
	BackgroundTransparency = 1,
}, gui)
local head = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 19,
	TextColor3 = WHITE, Text = "어디부터 가 볼까?",
}, holder)
create("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.2 }, head)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, -2), Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, Text = "X", Font = Enum.Font.GothamBlack, TextSize = 15, -- ("✕" is a box in Gotham)
	TextColor3 = WHITE, AutoButtonColor = false,
}, holder)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, close)
local row = create("Frame", {
	Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, TILE), BackgroundTransparency = 1,
}, holder)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder,
}, row)

type Choice = { key: string, icon: string, text: string, name: string, nightOnly: boolean?, dayOnly: boolean? }
local CHOICES: {Choice} = {
	-- (D-1817, user 2026-11-21 via the progress session: by day the club's place is 오늘의 곡 도전, the
	-- way to the neon stage; at night the club as before)
	{ key = "club", icon = "🎧", text = "클럽 가기", name = "클럽", nightOnly = true },
	{ key = "neon", icon = "🎵", text = "오늘의 곡 도전", name = "오늘의 곡", dayOnly = true },
	{ key = "photo", icon = "📸", text = "사진 찍으러 가기", name = "사진" },
	{ key = "park", icon = "🎢", text = "놀이공원 가기", name = "놀이공원" },
}
local tiles: {[string]: TextButton} = {}

local shownAt = 0
local open = false
local night = false
local function report(choice: string)
	local gate = Remotes:FindFirstChild("AnalyticsStep")
	if gate and gate:IsA("RemoteEvent") then
		gate:FireServer("FirstCard", { choice = choice, night = night, secs = os.clock() - shownAt })
	end
end
local function markSeen()
	if TEST then return end
	task.spawn(function()
		pcall(function() remote:InvokeServer("TipSeen", KEY) end)
		pcall(function() remote:InvokeServer("TipSeen", "tour2") end)
	end)
end
local function shut(choice: string)
	if not open then return end
	open = false
	report(choice)
	markSeen()
	Popups.closed("FirstCard")
	gui.Enabled = false
end

for i, c in ipairs(CHOICES) do
	local tile = create("TextButton", {
		LayoutOrder = i, Size = UDim2.fromOffset(TILE, TILE), BackgroundColor3 = BLACK, BackgroundTransparency = 0.28,
		Text = "", AutoButtonColor = false,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, tile)
	create("UIStroke", { Color = WHITE, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tile)
	create("TextLabel", {
		Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 38, TextColor3 = WHITE, Text = c.icon,
	}, tile)
	create("TextLabel", {
		Position = UDim2.new(0, 6, 1, -44), Size = UDim2.new(1, -12, 0, 38), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = WHITE, TextWrapped = true, Text = c.text,
	}, tile)
	tile.Activated:Connect(function()
		if not open then return end
		Sfx.play("click", 0.5)
		shut(c.name)
		UiBus.ShowWay:Fire(c.key)
	end)
	tiles[c.key] = tile
end
close.Activated:Connect(function()
	shut("닫기")
	UiBus.GuideHint:Fire() -- (D-1983: where the guide is, for later)
end)
local guide = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34 + TILE + 6), Size = UDim2.fromOffset(170, 28),
	BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, Text = "🐰 안내원에게 가기", Font = Enum.Font.GothamBold,
	TextSize = 14, TextColor3 = WHITE, AutoButtonColor = false,
}, holder)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, guide)
guide.Activated:Connect(function()
	if not open then return end
	Sfx.play("click", 0.5)
	shut("안내원")
	UiBus.ShowWay:Fire("guide")
end)

local function show()
	if open then return end
	night = ClubConfig.isNightOpen(DayNightConfig.clockNow())
	local count = 0
	for _, c in ipairs(CHOICES) do
		local on = (not c.nightOnly or night) and (not c.dayOnly or not night)
		tiles[c.key].Visible = on
		if on then count += 1 end
	end
	holder.Size = UDim2.fromOffset(count * TILE + (count - 1) * GAP, TILE + 34 + GUIDE_H)
	open = true
	shownAt = os.clock()
	gui.Enabled = true
	-- (one window at a time: another window opening over it closes the card, counted as "다른 창")
	Popups.opened("FirstCard", function() shut("다른 창") end)
	player:SetAttribute("NewPlayer", true) -- (D-1697: the guide's "뭘 해야 할지 모르겠어." shows this visit)
	holder.Position = UDim2.new(0.5, 0, 1, 60)
	TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -96) }):Play()
end

-- (D-1982) the server moves the first character to a spawn spot (SpawnService, attribute SpawnSpot) after
-- the camera has already settled behind the default spawn: turn the camera to look where the character
-- faces, so the place is in front of the player (every join, not only the first visit)
local function cameraBehind()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera or camera.CameraType ~= Enum.CameraType.Custom then return end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then return end
	look = look.Unit
	camera.CFrame = CFrame.lookAt(root.Position - look * 14 + Vector3.new(0, 6, 0), root.Position + look * 30 + Vector3.new(0, 2, 0))
end
player:GetAttributeChangedSignal("SpawnSpot"):Connect(function() task.defer(cameraBehind) end)
if player:GetAttribute("SpawnSpot") then task.defer(cameraBehind) end

-- first visit: after the server has told the tips seen and the loading screen is gone
task.spawn(function()
	if RunService:IsStudio() and not TEST then return end
	local waited = 0
	while player:GetAttribute("TipsSeen") == nil and waited < 20 do
		task.wait(0.5)
		waited += 0.5
	end
	local seen = seenKeys()
	if not TEST and (table.find(seen, KEY) or table.find(seen, "tour2") or table.find(seen, "goal1")) then return end
	if not player.Character then player.CharacterAdded:Wait() end
	local t0 = os.clock()
	while playerGui:FindFirstChild("OHULoading") and os.clock() - t0 < 90 do task.wait(0.5) end
	task.wait(1)
	show()
end)
