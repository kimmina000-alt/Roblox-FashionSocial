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

local coins = Instance.new("TextLabel")
coins.Name = "CoinPill"
coins.BackgroundColor3 = Color3.new(0, 0, 0)
coins.BackgroundTransparency = 0.2
coins.TextColor3 = Color3.fromRGB(255, 220, 110)
coins.TextSize = 16
coins.Font = Enum.Font.GothamBold
coins.Text = "💰 0"
coins:SetAttribute("Width", 92)
coins.Parent = gui
corner(coins, UDim.new(1, 0))
TopBar.add(coins, 10)

local shown = -1
local function refreshCoins()
	local value = player:GetAttribute("Coins")
	local amount = if typeof(value) == "number" then value else 0
	coins.Text = "💰 " .. tostring(amount)
	if shown >= 0 and amount > shown then
		coins.TextColor3 = Color3.fromRGB(140, 255, 160)
		TweenService:Create(coins, TweenInfo.new(0.8), { TextColor3 = Color3.fromRGB(255, 220, 110) }):Play()
	end
	shown = amount
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
refreshCoins()
