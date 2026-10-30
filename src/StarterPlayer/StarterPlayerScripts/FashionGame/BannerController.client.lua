--!strict
-- Banners for everyone (D-271): a stage cold spark or a supporter gift shows
-- the buyer's name and their (server-filtered) message at the top of every
-- player's screen, one at a time. Also the 💝 후원 button and its shop
-- (10 / 50 / 100 / 500 / 1,000 / 5,000 R$, CLUB_SHOP_PRICING.md §11, §13).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local ClubNotify = Remotes:WaitForChild("ClubNotify") :: RemoteEvent
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local MessagePrompt = require(script.Parent:WaitForChild("MessagePrompt"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

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

-- (user 2026-10-30, 2nd, from their mock-ups) a strip across the screen: black
-- at 40 % see-through, a thin red LED line above and below, the text in white
-- with a red outer glow. The text flows from right to left for the whole
-- show (a cold spark: 30 s) and stays on screen all that time: its speed is
-- worked out from the screen width, the text width and the time.
--   cold spark   “message” / @id   (no message: "○○님의 콜드 스파크!")
--   gift         ○○님이 N R$ 기부하셨습니다. / “message”
local SPARK_SECONDS, GIFT_SECONDS = 30, 15
local RED = Color3.fromRGB(255, 40, 60)
local STRIP_H = 96

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.Size = UDim2.new(1, 0, 0, STRIP_H)
banner.BackgroundColor3 = Color3.new(0, 0, 0)
banner.BackgroundTransparency = 0.4
banner.BorderSizePixel = 0
banner.ClipsDescendants = true
banner.Visible = false
banner.ZIndex = 5 -- over the 💝 window when both are open (2P test 2026-10-26)
banner.Parent = gui
-- the LED lines: a bright core with a soft glow round it
for _, at in ipairs({ 0, 1 }) do
	local glowLine = Instance.new("Frame")
	glowLine.AnchorPoint = Vector2.new(0, at)
	glowLine.Position = UDim2.fromScale(0, at)
	glowLine.Size = UDim2.new(1, 0, 0, 6)
	glowLine.BackgroundColor3 = RED
	glowLine.BackgroundTransparency = 0.65
	glowLine.BorderSizePixel = 0
	glowLine.ZIndex = 6
	glowLine.Parent = banner
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0, 0.5)
	core.Position = UDim2.fromScale(0, 0.5)
	core.Size = UDim2.new(1, 0, 0, 2)
	core.BackgroundColor3 = Color3.fromRGB(255, 120, 130)
	core.BorderSizePixel = 0
	core.ZIndex = 7
	core.Parent = glowLine
end

-- the moving block: two lines, centred on each other
local block = Instance.new("Frame")
block.Name = "Block"
block.BackgroundTransparency = 1
block.Size = UDim2.new(0, 10, 1, 0)
block.ZIndex = 6
block.Parent = banner

-- white text with a red outer glow: a wide soft red copy behind a white one
-- with a thin red edge
local function glowText(y: number, height: number, size: number, font: Enum.Font): (TextLabel, TextLabel)
	local function one(z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, 0, 0, height)
		l.TextSize = size
		l.Font = font
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = z
		l.Parent = block
		return l
	end
	local back = one(7)
	back.TextTransparency = 0.45
	back.TextColor3 = Color3.fromRGB(255, 150, 160)
	local bs = Instance.new("UIStroke") bs.Color = RED bs.Thickness = 5 bs.Transparency = 0.55 bs.Parent = back
	local front = one(8)
	local fs = Instance.new("UIStroke") fs.Color = RED fs.Thickness = 1.4 fs.Transparency = 0.15 fs.Parent = front
	return front, back
end
local mainText, mainGlow = glowText(14, 40, 32, Enum.Font.GothamBlack)
local subText, subGlow = glowText(58, 26, 20, Enum.Font.GothamBold)

local queue: {any} = {}
local showing = false

local function showNext()
	if showing then return end
	local data = table.remove(queue, 1)
	if not data then return end
	showing = true
	local message = if typeof(data.message) == "string" then data.message else ""
	local main, sub
	if data.kind == "support" then
		main = string.format("%s님이 %s R$ 기부하셨습니다.", tostring(data.name), tostring(data.amount))
		sub = if message ~= "" then ("“" .. message .. "”") else ("@" .. tostring(data.user))
	elseif message ~= "" then
		main, sub = "“" .. message .. "”", "@" .. tostring(data.user)
	elseif data.kind == "djspark" then
		main, sub = string.format("DJ %s님의 불꽃 쇼!", tostring(data.name)), "@" .. tostring(data.user)
	else
		main, sub = string.format("%s님의 콜드 스파크!", tostring(data.name)), "@" .. tostring(data.user)
	end
	mainText.Text, mainGlow.Text = main, main
	subText.Text, subGlow.Text = sub, sub
	local seconds = if data.kind == "support" then GIFT_SECONDS else SPARK_SECONDS
	banner.Position = UDim2.fromOffset(0, TopBar.bottom() + 8)
	banner.Visible = true
	Sfx.play("success")
	task.wait() -- (TextBounds are measured once the labels are on screen)
	local textW = math.max(mainText.TextBounds.X, subText.TextBounds.X) + 40
	block.Size = UDim2.new(0, textW, 1, 0)
	-- from just inside the right edge to just inside the left edge, all the
	-- time on screen (a text wider than the screen runs its own length)
	local screenW = banner.AbsoluteSize.X
	local x0 = math.max(screenW - textW, 0)
	local x1 = math.min(0, screenW - textW)
	if x0 == 0 and x1 == 0 then x0 = screenW - textW end
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		local k = (os.clock() - t0) / seconds
		block.Position = UDim2.fromOffset(math.floor(x0 + (x1 - x0) * k), 0)
		task.wait()
	end
	banner.Visible = false
	showing = false
	showNext()
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
		task.spawn(showNext)
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
		else "☐ 순위(기부·레벨)에 내 이름 숨기기"
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
TopBar.icon(openButton, require(script.Parent:WaitForChild("Icons")).give, 0.66) -- (hands holding a heart, user mock-up 2026-10-30)
TopBar.add(openButton, 5)
openButton.MouseButton1Click:Connect(function() setPanel(not panel.Visible) end)
