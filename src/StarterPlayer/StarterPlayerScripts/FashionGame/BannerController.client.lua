--!strict
-- Banners for everyone (D-271): a stage cold spark or a supporter gift shows
-- the buyer's name and their (server-filtered) message at the top of every
-- player's screen, one at a time. Also the 💝 후원 button and its shop
-- (10 / 50 / 100 / 500 / 1,000 / 5,000 R$, CLUB_SHOP_PRICING.md §11, §13).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local ClubNotify = Remotes:WaitForChild("ClubNotify") :: RemoteEvent
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local MessagePrompt = require(script.Parent:WaitForChild("MessagePrompt"))

local BANNER_SECONDS = 7
local SUPPORT_KEYS = { "Support_10", "Support_50", "Support_100", "Support_500", "Support_1000", "Support_5000" }

local gui = Instance.new("ScreenGui")
gui.Name = "FashionBannerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 35
gui.Parent = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- Banner
--------------------------------------------------

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
-- (user 2026-10-27: it was hard to see) bigger, solid, a thick gold frame
banner.Size = UDim2.fromOffset(560, 100)
banner.BackgroundColor3 = Color3.fromRGB(20, 8, 30)
banner.BackgroundTransparency = 0
banner.Visible = false
banner.ZIndex = 5 -- over the 💝 window when both are open (2P test 2026-10-26)
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Parent = banner
local headline = Instance.new("TextLabel")
headline.Name = "Headline"
headline.Position = UDim2.fromOffset(14, 8)
headline.Size = UDim2.new(1, -28, 0, 44)
headline.BackgroundTransparency = 1
headline.TextColor3 = Color3.new(1, 1, 1)
headline.TextScaled = true
headline.Font = Enum.Font.GothamBlack
headline.Parent = banner
Instance.new("UITextSizeConstraint", headline).MaxTextSize = 34
local headStroke = Instance.new("UIStroke")
headStroke.Thickness = 2.5
headStroke.Color = Color3.fromRGB(255, 120, 40)
headStroke.Parent = headline
local line = Instance.new("TextLabel")
line.Name = "Message"
line.Position = UDim2.fromOffset(14, 56)
line.Size = UDim2.new(1, -28, 0, 34)
line.BackgroundTransparency = 1
line.TextColor3 = Color3.new(1, 1, 1)
line.TextScaled = true
line.Font = Enum.Font.GothamMedium
line.Parent = banner
Instance.new("UITextSizeConstraint", line).MaxTextSize = 26

local queue: {any} = {}
local showing = false

local function showNext()
	if showing then return end
	local data = table.remove(queue, 1)
	if not data then return end
	showing = true
	local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
	banner.Size = UDim2.fromOffset(math.min(560, vp.X - 24), 100)
	local top = TopBar.bottom() + 8
	if data.kind == "support" then
		headline.Text = string.format("💝 %s님 후원 감사합니다! (%s R$)", tostring(data.name), tostring(data.amount))
		stroke.Color = Color3.fromRGB(255, 110, 170)
		headStroke.Color = Color3.fromRGB(230, 60, 130)
	elseif data.kind == "djspark" then
		headline.Text = string.format("🎧🎆 DJ %s님의 불꽃 쇼!", tostring(data.name))
		stroke.Color = Color3.fromRGB(110, 210, 255)
		headStroke.Color = Color3.fromRGB(40, 140, 230)
	else
		headline.Text = string.format("🎆 %s님이 콜드 스파크를 쏘아 올렸어요!", tostring(data.name))
		stroke.Color = Color3.fromRGB(255, 210, 110)
		headStroke.Color = Color3.fromRGB(255, 120, 40)
	end
	local message = if typeof(data.message) == "string" then data.message else ""
	line.Text = if message ~= "" then ("“" .. message .. "”") else ("@" .. tostring(data.user))
	banner.Position = UDim2.new(0.5, 0, 0, top - 120)
	banner.Visible = true
	-- the frame pulses while it shows
	task.spawn(function()
		local t0 = os.clock()
		while banner.Visible and os.clock() - t0 < BANNER_SECONDS do
			stroke.Thickness = 4 + 2 * math.abs(math.sin((os.clock() - t0) * 5))
			task.wait(0.03)
		end
	end)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, top) }):Play()
	task.delay(BANNER_SECONDS, function()
		local out = TweenService:Create(banner, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, top - 120) })
		out:Play()
		out.Completed:Wait()
		banner.Visible = false
		showing = false
		showNext()
	end)
end

-- A cold spark bought while another show is on (user 2026-10-27): a big white
-- countdown in the middle of the buyer's screen until theirs goes off
local wait = Instance.new("TextLabel")
wait.Name = "ColdSparkWait"
wait.AnchorPoint = Vector2.new(0.5, 0.5)
wait.Position = UDim2.fromScale(0.5, 0.36)
wait.Size = UDim2.fromOffset(520, 70)
wait.BackgroundTransparency = 1
wait.TextColor3 = Color3.new(1, 1, 1)
wait.TextScaled = true
wait.Font = Enum.Font.GothamBlack
wait.Visible = false
wait.Parent = gui
do local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(255, 120, 40) s.Parent = wait end
local waitUntil = 0

ClubNotify.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "Banner" and typeof(value) == "table" then
		table.insert(queue, value)
		showNext()
	elseif kind == "ColdSparkWait" and typeof(value) == "number" then
		waitUntil = value
		if wait.Visible then return end
		wait.Visible = true
		task.spawn(function()
			while true do
				local left = math.ceil(waitUntil - workspace:GetServerTimeNow())
				if left <= 0 then break end
				wait.Text = string.format("🎆 %d초 뒤에 내 불꽃이 터져요!", left)
				task.wait(0.2)
			end
			wait.Visible = false
		end)
	end
end)

--------------------------------------------------
-- 💝 후원 shop
--------------------------------------------------

local panel = Instance.new("Frame")
panel.Name = "SupportShop"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Size = UDim2.fromOffset(340, 266)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -60, 0, 28)
title.BackgroundTransparency = 1
title.Text = "💝 게임 후원"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel
local sub = Instance.new("TextLabel")
sub.Position = UDim2.fromOffset(16, 38)
sub.Size = UDim2.new(1, -32, 0, 34)
sub.BackgroundTransparency = 1
sub.Text = "후원하면 모두의 화면에 이름과 한마디가 떠요. 받는 아이템은 없어요."
sub.TextColor3 = Color3.fromRGB(190, 190, 205)
sub.TextSize = 13
sub.TextWrapped = true
sub.Font = Enum.Font.GothamMedium
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = panel
local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(30, 30)
close.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 15
close.Parent = panel
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)
local grid = Instance.new("Frame")
grid.Position = UDim2.fromOffset(16, 80)
grid.Size = UDim2.new(1, -32, 1, -128)
-- "순위에 내 이름 숨기기" (rankings are public; D-277)
local hideButton = Instance.new("TextButton")
hideButton.Name = "HideRank"
hideButton.AnchorPoint = Vector2.new(0, 1)
hideButton.Position = UDim2.new(0, 16, 1, -10)
hideButton.Size = UDim2.new(1, -32, 0, 28)
hideButton.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
hideButton.TextColor3 = Color3.fromRGB(210, 210, 225)
hideButton.TextScaled = true
hideButton.Font = Enum.Font.GothamMedium
hideButton.Parent = panel
Instance.new("UICorner", hideButton).CornerRadius = UDim.new(0, 8)
Instance.new("UITextSizeConstraint", hideButton).MaxTextSize = 14
local function hideText()
	hideButton.Text = if player:GetAttribute("RankHidden") == true
		then "☑ 순위에 내 이름 숨기는 중 (누르면 다시 보이기)"
		else "☐ 순위(후원·큰손·플레이 시간)에 내 이름 숨기기"
end
hideText()
player:GetAttributeChangedSignal("RankHidden"):Connect(hideText)
hideButton.MouseButton1Click:Connect(function()
	local remotes = FashionGame:WaitForChild("Remotes")
	;(remotes:WaitForChild("ClubShop") :: RemoteFunction):InvokeServer("RankHidden", player:GetAttribute("RankHidden") ~= true)
end)
grid.BackgroundTransparency = 1
grid.Parent = panel
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(1 / 3, -6, 0.5, -4)
layout.CellPadding = UDim2.fromOffset(6, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid
local tierColors = {
	Color3.fromRGB(90, 200, 120), Color3.fromRGB(80, 160, 255), Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 200, 60),
}
local function setPanel(open: boolean)
	panel.Visible = open
	if open then
		local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
		panel.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
		panel.Size = UDim2.fromOffset(math.min(340, vp.X - 24), math.min(266, vp.Y - TopBar.bottom() - 20))
		Popups.opened("SupportShop", function() panel.Visible = false end)
	else
		Popups.closed("SupportShop")
	end
end
close.MouseButton1Click:Connect(function() setPanel(false) end)
for index, key in ipairs(SUPPORT_KEYS) do
	local product = MonetizationConfig.Products[key]
	local button = Instance.new("TextButton")
	button.Name = key
	button.LayoutOrder = index
	button.BackgroundColor3 = tierColors[index]
	button.Text = "R$ " .. tostring(product.price)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = grid
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	Instance.new("UITextSizeConstraint", button).MaxTextSize = 20
	button.MouseButton1Click:Connect(function()
		setPanel(false)
		MessagePrompt.buy(key, string.format("💝 %d R$ 후원", product.price))
	end)
end

local openButton = Instance.new("TextButton")
openButton.Name = "SupportButton"
openButton.BackgroundColor3 = Color3.new(0, 0, 0)
openButton.BackgroundTransparency = 0.2
openButton.Text = "💝"
openButton.TextSize = 22
openButton.Font = Enum.Font.GothamBold
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.Parent = gui
Instance.new("UICorner", openButton).CornerRadius = UDim.new(1, 0)
TopBar.add(openButton, 6)
openButton.MouseButton1Click:Connect(function() setPanel(not panel.Visible) end)
