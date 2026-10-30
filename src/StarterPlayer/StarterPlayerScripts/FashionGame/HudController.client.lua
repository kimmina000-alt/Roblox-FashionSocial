--!strict
-- Small HUD pieces in the top bar (user, 2026-10-20):
--   (🏠 back to the first spawn point: removed 2026-10-30)
--   🪙  coin balance (EconomyService, player attribute "Coins")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local gui = Instance.new("ScreenGui")
gui.Name = "FashionHudGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = playerGui

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

-- Toast (own, small)
local toastLabel = Instance.new("TextLabel")
toastLabel.AnchorPoint = Vector2.new(0.5, 1)
toastLabel.Position = UDim2.new(0.5, 0, 1, -110)
toastLabel.Size = UDim2.fromOffset(360, 36)
toastLabel.BackgroundColor3 = Color3.new(0, 0, 0)
toastLabel.BackgroundTransparency = 0.25
toastLabel.TextColor3 = Color3.new(1, 1, 1)
toastLabel.TextSize = 15
toastLabel.Font = Enum.Font.GothamBold
toastLabel.Visible = false
toastLabel.Parent = gui
corner(toastLabel, UDim.new(0, 12))
local toastToken = 0
local function toast(message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(2.5, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

-- (the 🏠 back-to-spawn button is gone, user 2026-10-30)

--------------------------------------------------
-- 🪙 coins
--------------------------------------------------

-- (user mock-up 2026-10-30) the gold ₩ coin just left of a dark pill with
-- the amount in white, 100,000 style
local COIN_TEXT = Color3.new(1, 1, 1)
local coins = Instance.new("TextLabel")
coins.Name = "CoinPill"
coins.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
coins.BackgroundTransparency = 0.15
coins.TextColor3 = COIN_TEXT
coins.TextSize = 17
coins.Font = Enum.Font.GothamBold
coins.Text = "0"
coins:SetAttribute("Width", 120)
coins.Parent = gui
corner(coins, UDim.new(1, 0))
do
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.fromRGB(205, 30, 45)
	edge.Thickness = 1.5
	edge.Parent = coins
	-- (the red edge only for VIP, user 2026-10-30)
	local function vipEdge() edge.Enabled = player:GetAttribute("Pass_VIP") == true end
	player:GetAttributeChangedSignal("Pass_VIP"):Connect(vipEdge)
	vipEdge()
	local icon = Instance.new("ImageLabel")
	icon.Name = "CoinIcon"
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.new(0, -6, 0.5, 0)
	icon.Size = UDim2.fromScale(0.78, 0.78)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.BackgroundTransparency = 1
	icon.Image = require(script.Parent:WaitForChild("Icons")).coin
	icon.Parent = coins
end
TopBar.add(coins, 10)

local shown = -1
local function refreshCoins()
	local value = player:GetAttribute("Coins")
	local amount = if typeof(value) == "number" then math.floor(value) else 0
	-- 1234567 → "1,234,567"
	local grouped = string.reverse((string.gsub(string.reverse(tostring(amount)), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then grouped = string.sub(grouped, 2) end
	coins.Text = grouped
	if shown >= 0 and amount > shown then
		coins.TextColor3 = Color3.fromRGB(140, 255, 160)
		TweenService:Create(coins, TweenInfo.new(0.8), { TextColor3 = COIN_TEXT }):Play()
	end
	shown = amount
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
refreshCoins()
