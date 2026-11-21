--!strict
-- 건너뛴 사람에게 토끼 알려 주기 (D-1983, user 2026-11-21: "처음에 튜토리얼 건너뛰기하는 사람들한테 마지막 문구만
-- 추가로 띄우기 "궁금한 게 있으면 나한테 찾아와!" <- 이러면서 토끼 npc 외곽선 넣어서 위치 강조해서 보여 줘").
-- UiBus.GuideHint fires when a player closes the first-visit card with X (FirstCardController) or skips the
-- tour (건너뛰기 / 아니, 괜찮아!, TourController). Then:
--   · the rabbit card at the bottom (GuideSpeaker waving) says "궁금한 게 있으면 나한테 찾아와!" with
--     📍 길 안내 (the dashed way to the guide, UiBus.ShowWay "guide") and X;
--   · the guide NPC (Workspace.GuideNPC, GuideService) gets a white outline seen through walls (Highlight,
--     AlwaysOnTop) and "🐰 안내원" over its head, so the player sees where it stands from anywhere.
-- The card goes after CARD_SECONDS, the outline after OUTLINE_SECONDS (or both on X / 길 안내).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local GuideConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("GuideConfig"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CARD_SECONDS = 10
local OUTLINE_SECONDS = 20
local SPEAKER = 62

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for k, v in pairs(props) do (instance :: any)[k] = v end
	if parent then instance.Parent = parent end
	return instance
end

---------------------------------------------------------------- the card
local gui = create("ScreenGui", { Name = "GuideHintGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false }, playerGui)
local card = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(SPEAKER + 290, 92),
	BackgroundColor3 = BLACK, BackgroundTransparency = 0.25,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
create("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.2 }, card)
require(script.Parent:WaitForChild("GuideSpeaker")).attach(card, SPEAKER)
create("TextLabel", {
	Position = UDim2.fromOffset(SPEAKER + 8, 8), Size = UDim2.new(1, -SPEAKER - 44, 0, 40), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = WHITE, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "궁금한 게 있으면 나한테 찾아와!",
}, card)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 1, Text = "X", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = WHITE, AutoButtonColor = false,
}, card)
local way = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(120, 32),
	BackgroundColor3 = WHITE, Text = "📍 길 안내", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = BLACK,
	AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, way)

---------------------------------------------------------------- the outline on the guide
local highlight: Highlight? = nil
local tag: BillboardGui? = nil
local serial = 0
local function clearOutline()
	if highlight then highlight:Destroy() end
	if tag then tag:Destroy() end
	highlight, tag = nil, nil
end
local function outline()
	clearOutline()
	-- (StreamingEnabled: the guide may be far away; load around it first)
	pcall(function() player:RequestStreamAroundAsync(GuideConfig.Npc.position, 3) end)
	local npc = workspace:FindFirstChild("GuideNPC") or workspace:WaitForChild("GuideNPC", 5)
	if not npc or not npc:IsA("Model") then return end
	highlight = create("Highlight", {
		Name = "GuideHintOutline", Adornee = npc, FillColor = WHITE, FillTransparency = 0.85, OutlineColor = WHITE,
		OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, npc)
	local head = npc:FindFirstChild("Head") or npc.PrimaryPart
	if head then
		local b = create("BillboardGui", {
			Name = "GuideHintTag", Adornee = head, Size = UDim2.fromOffset(110, 34), StudsOffset = Vector3.new(0, 3, 0),
			AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 2000,
		}, npc)
		local l = create("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2,
			Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = WHITE, Text = "🐰 안내원",
		}, b)
		create("UICorner", { CornerRadius = UDim.new(0, 12) }, l)
		tag = b
	end
	-- (a slow pulse of the outline so the eye finds it)
	local h = highlight :: Highlight
	TweenService:Create(h, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.6 }):Play()
end

local open = false
local function hide()
	if not open then return end
	open = false
	gui.Enabled = false
	Popups.closed("GuideHint")
end
close.Activated:Connect(function() hide() clearOutline() end)
way.Activated:Connect(function()
	Sfx.play("click", 0.5)
	hide()
	clearOutline()
	UiBus.ShowWay:Fire("guide")
end)

UiBus.GuideHint.Event:Connect(function()
	serial += 1
	local mine = serial
	open = true
	gui.Enabled = true
	Popups.opened("GuideHint", hide)
	card.Position = UDim2.new(0.5, 0, 1, 60)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -96) }):Play()
	task.spawn(outline)
	task.delay(CARD_SECONDS, function() if serial == mine then hide() end end)
	task.delay(OUTLINE_SECONDS, function() if serial == mine then clearOutline() end end)
end)
