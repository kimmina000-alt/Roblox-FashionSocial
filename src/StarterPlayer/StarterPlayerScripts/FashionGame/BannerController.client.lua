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
-- with a red outer glow. (2026-11-01, D-716: only the white text with a red
-- outline is left, both lines at 20.) The text flows from right to left for the whole
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
-- (user 2026-11-01, D-716: no dark strip, no red lines above and below)
banner.BackgroundTransparency = 1
banner.BorderSizePixel = 0
banner.ClipsDescendants = true
banner.Visible = false
banner.ZIndex = 5 -- over the 💝 window when both are open (2P test 2026-10-26)
banner.Parent = gui

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
	-- (D-716, user: no neon glow, only the red outline: the soft copy behind is
	-- kept but hidden, so the code that sets both texts stays)
	local back = one(7)
	back.Visible = false
	local front = one(8)
	local fs = Instance.new("UIStroke") fs.Color = RED fs.Thickness = 2 fs.Transparency = 0 fs.Parent = front
	return front, back
end
-- (D-716: the main line as small as the message line; was 32 / 20)
local mainText, mainGlow = glowText(20, 26, 20, Enum.Font.GothamBlack)
local subText, subGlow = glowText(50, 26, 20, Enum.Font.GothamBold)

local queue: {any} = {}

-- (D-1811, user 2026-11-19: "무대 스파클러 터트렸을 때 뜨는 문구나 후원 문구 모두 쓰레기통에서 뭐 주웠을 때 뜨는
-- 문구 위치와 텍스트 크기로 통일. 대신 빨간색.") the strip above is no longer shown: each banner is one red
-- line in the trash notice's stack at the bottom (BottomNotice, 13 px, black outline), for the show's time
local BottomNotice = require(script.Parent:WaitForChild("BottomNotice"))
local function showNext()
	local data = table.remove(queue, 1)
	if not data then return end
	local message = if typeof(data.message) == "string" then data.message else ""
	local line
	if data.kind == "support" then
		-- (D-797, user: nicknames, not @ids)
		line = string.format("%s님이 %s R$ 기부하셨습니다.", tostring(data.name), tostring(data.amount))
			.. (if message ~= "" then (" “" .. message .. "”") else " 💝 후원 감사합니다")
	elseif message ~= "" then
		line = "“" .. message .. "” - " .. tostring(data.name)
	elseif data.kind == "djspark" then
		line = string.format("🎆 DJ %s님의 불꽃 쇼!", tostring(data.name))
	else
		line = string.format("✨ %s님의 콜드 스파크!", tostring(data.name))
	end
	Sfx.play("success")
	if data.kind == "support" then
		BottomNotice.show(line, BottomNotice.RED, GIFT_SECONDS)
	else
		-- (D-1812, user 2026-11-19: "콜드 스파크는 상단에 띄우고 깜빡깜빡 거리게 하자 글자 1.5배 키우고") cold
		-- sparks (and the DJ's spark show) under the top bar, blinking, 20 px (13 x 1.5)
		BottomNotice.show(line, BottomNotice.RED, SPARK_SECONDS, { top = true, blink = true, size = 20 })
	end
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

-- (D-1386, user 2026-11-13: "홈화면 메뉴 버튼에 기부하기 넣었으니까 바깥에 있는 기부하기 버튼
-- 삭제") no ♥ button in the top bar any more: the window opens from ☰ → 💝 기부하기 only
-- (D-1377) the ☰ menu's 기부하기 opens the same window
require(script.Parent:WaitForChild("UiBus")).OpenSupport.Event:Connect(function() setPanel(true) end)
