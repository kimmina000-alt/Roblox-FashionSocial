--!strict
-- Small HUD pieces in the top bar (user, 2026-10-20):
--   🏠  back to the first spawn point of the main map (next to the catalog C)
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

--------------------------------------------------
-- 🏠 spawn
--------------------------------------------------

local home = Instance.new("TextButton")
home.Name = "SpawnButton"
home.BackgroundColor3 = Color3.new(0, 0, 0)
home.BackgroundTransparency = 0.2
home.Text = "🏠"
home.TextSize = 22
home.Font = Enum.Font.GothamBold
home.TextColor3 = Color3.new(1, 1, 1)
home.Parent = gui
corner(home, UDim.new(1, 0))
TopBar.add(home, 0)

local function spawnCFrame(): CFrame?
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame * CFrame.new(math.random(-3, 3), spawn.Size.Y / 2 + 3, math.random(-3, 3))
	end
	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("SpawnLocation") then return item.CFrame + Vector3.new(0, 4, 0) end
	end
	return nil
end

local lastHome = 0
home.MouseButton1Click:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end
	if character:GetAttribute("PhotoBooth") then
		toast("촬영 중에는 이동할 수 없어요. 부스의 나가기를 눌러 주세요.")
		return
	end
	if os.clock() - lastHome < 2 then return end
	lastHome = os.clock()
	local target = spawnCFrame()
	if not target then return end
	if humanoid.SeatPart then humanoid.Sit = false task.wait(0.1) end
	-- Off any park ride / tube first (allowed anywhere, even on the wheel).
	local parkRide = game:GetService("ReplicatedStorage").FashionGame.Remotes:FindFirstChild("ParkRide")
	if parkRide and parkRide:IsA("RemoteFunction") then
		pcall(function() parkRide:InvokeServer("Leave", "home") end)
		task.wait(0.15)
		humanoid.Sit = false
	end
	character:PivotTo(target)
	toast("처음 장소로 돌아왔어요.")
end)

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
