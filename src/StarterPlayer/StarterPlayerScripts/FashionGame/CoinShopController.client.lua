--!strict
-- Coin x2 (D-278, CLUB_SHOP_PRICING.md §10, §14): tapping the 💰 pill opens a
-- small window with the permanent "코인 x2 패스" (199 R$) and the "1시간 코인
-- x2 부스트" (25 R$, counted while online). The pill shows "x2" while it runs.
-- Items whose id is still 0 are bought as [Studio 테스트] in Studio only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local ClubShop = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))

local COIN = Color3.fromRGB(230, 170, 40)
local GREEN = Color3.fromRGB(0, 176, 111)

local gui = Instance.new("ScreenGui")
gui.Name = "FashionCoinShopGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 31
gui.Parent = playerGui

local function corner(parent: Instance, radius: number)
	Instance.new("UICorner", parent).CornerRadius = UDim.new(0, radius)
end

local function text(parent: Instance, props: {[string]: any}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end

local panel = Instance.new("Frame")
panel.Name = "CoinShop"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Size = UDim2.fromOffset(320, 236)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.Visible = false
panel.Parent = gui
corner(panel, 16)
local title = text(panel, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 26), Text = "💰 코인" })
local status = text(panel, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 20), Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(190, 190, 205), Text = "" })
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

local function row(y: number, name: string, sub: string, priceText: string, color: Color3, onClick: () -> ()): (TextLabel, TextButton)
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(12, y)
	frame.Size = UDim2.new(1, -24, 0, 70)
	frame.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
	frame.Parent = panel
	corner(frame, 12)
	text(frame, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -120, 0, 24), Text = name })
	local subLabel = text(frame, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -120, 0, 26), Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(190, 190, 205), TextWrapped = true, Text = sub })
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(92, 36)
	button.BackgroundColor3 = color
	button.Text = priceText
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = frame
	corner(button, 18)
	Instance.new("UITextSizeConstraint", button).MaxTextSize = 16
	button.MouseButton1Click:Connect(onClick)
	return subLabel, button
end

local function buy(kind: string, key: string)
	local entry = if kind == "pass" then MonetizationConfig.GamePasses[key] else MonetizationConfig.Products[key]
	if not entry then return end
	if entry.id ~= 0 then
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, entry.id)
		else
			MarketplaceService:PromptProductPurchase(player, entry.id)
		end
	elseif RunService:IsStudio() then
		-- (no id yet: a test purchase, nothing is charged)
		ClubShop:InvokeServer("StudioTestBuy", { kind = kind, key = key })
	else
		StarterGui:SetCore("SendNotification", { Title = entry.name, Text = "준비 중인 상품입니다.", Duration = 3 })
	end
end

local _passSub, passButton = row(70, "코인 x2 패스 (영구)", "접속·알바 코인을 영원히 2배",
	"R$ " .. MonetizationConfig.GamePasses.CoinX2.price, COIN, function()
		if player:GetAttribute("Pass_CoinX2") ~= true then buy("pass", "CoinX2") end
	end)
local boostSub, boostButton = row(148, "1시간 코인 x2 부스트", "접속해 있는 1시간 동안 2배 (여러 번 사면 시간이 더해져요)",
	"R$ " .. MonetizationConfig.Products.CoinBoost1h.price, GREEN, function() buy("product", "CoinBoost1h") end)

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refresh()
	local hasPass = player:GetAttribute("Pass_CoinX2") == true
	local boost = player:GetAttribute("CoinBoostSeconds")
	boost = if typeof(boost) == "number" then boost else 0
	local studio = RunService:IsStudio() and (MonetizationConfig.GamePasses.CoinX2.id == 0)
	title.Text = string.format("💰 코인 %s", tostring(player:GetAttribute("Coins") or 0))
	status.Text = if hasPass then "✅ 코인 x2 패스 적용 중 (영구)"
		elseif boost > 0 then ("⏱ x2 부스트 남은 시간 " .. clock(boost))
		else ("지금은 x1 · 1분에 1코인" .. (if studio then " · [Studio 테스트 구매]" else ""))
	passButton.Text = if hasPass then "보유 중" else ("R$ " .. MonetizationConfig.GamePasses.CoinX2.price)
	passButton.AutoButtonColor = not hasPass
	passButton.Active = not hasPass
	-- the boost cannot be bought with the pass (x2 at most)
	boostButton.Visible = not hasPass
	boostSub.Text = if hasPass then "패스가 있어서 필요 없어요" else "접속해 있는 1시간 동안 2배 (여러 번 사면 시간이 더해져요)"
end

local function setPanel(open: boolean)
	panel.Visible = open
	if open then
		local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
		panel.Position = UDim2.new(1, -12, 0, TopBar.bottom() + 8)
		panel.Size = UDim2.fromOffset(math.min(320, vp.X - 24), 236)
		refresh()
		Popups.opened("CoinShop", function() panel.Visible = false end)
	else
		Popups.closed("CoinShop")
	end
end
close.MouseButton1Click:Connect(function() setPanel(false) end)

-- the 💰 pill (HudController) opens the window; "x2" badge on it while it runs
task.spawn(function()
	local hud = playerGui:WaitForChild("FashionHudGui", 10)
	local pill = hud and hud:FindFirstChild("CoinPill", true)
	if not pill or not pill:IsA("GuiObject") then return end
	local hit = Instance.new("TextButton")
	hit.Name = "OpenCoinShop"
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Parent = pill
	hit.MouseButton1Click:Connect(function() setPanel(not panel.Visible) end)
	local badge = Instance.new("TextLabel")
	badge.Name = "X2Badge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 3, 0, -5)
	badge.Size = UDim2.fromOffset(17, 11) -- (small top bar, user mock-up 2026-10-30 rev 2)
	badge.BackgroundColor3 = Color3.fromRGB(255, 80, 120)
	badge.Text = "x2"
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.TextScaled = true
	badge.Font = Enum.Font.GothamBlack
	badge.Visible = false
	badge.Parent = pill
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	local function update()
		badge.Visible = player:GetAttribute("CoinMultiplier") == 2
		if panel.Visible then refresh() end
	end
	for _, name in ipairs({ "CoinMultiplier", "CoinBoostSeconds", "Pass_CoinX2", "Coins" }) do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
end)
