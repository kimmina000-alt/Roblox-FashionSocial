--!strict
-- Cafe / snack stand menu (SnackConfig, SnackService). Opens when the
-- server says so (the counter's "주문하기" prompt), closes on ✕ or when the
-- player walks away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local SnackConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("SnackConfig"))
local EconomyConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local remote = Remotes:WaitForChild("Snack") :: RemoteFunction
local notify = Remotes:WaitForChild("SnackNotify") :: RemoteEvent

local player = Players.LocalPlayer

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local gui = make("ScreenGui", { Name = "SnackGui", ResetOnSpawn = false, DisplayOrder = 40 }, player:WaitForChild("PlayerGui"))
local panel = make("Frame", {
	Name = "Menu",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(320, 300),
	BackgroundColor3 = Color3.fromRGB(255, 250, 245),
	Visible = false,
}, gui)
round(panel, 16)
make("UIStroke", { Color = Color3.fromRGB(255, 150, 190), Thickness = 2 }, panel)
local title = make("TextLabel", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -60, 0, 32),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(60, 40, 50),
	Text = "",
}, panel)
local close = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = Color3.fromRGB(240, 230, 235),
	Text = "X", -- ✕ is not in the Roblox font
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(80, 60, 70),
}, panel)
round(close, 16)
local list = make("Frame", {
	Position = UDim2.fromOffset(12, 50),
	Size = UDim2.new(1, -24, 1, -92),
	BackgroundTransparency = 1,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local status = make("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -8),
	Size = UDim2.new(1, -28, 0, 30),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(110, 90, 100),
	Text = "",
}, panel)

local openShop: string? = nil
local openedAt: Vector3? = nil

local function hide()
	panel.Visible = false
	openShop = nil
end
close.MouseButton1Click:Connect(hide)

local function show(shopKey: string)
	local shop = SnackConfig.Shops[shopKey]
	if not shop then return end
	openShop = shopKey
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	openedAt = if root and root:IsA("BasePart") then root.Position else nil
	title.Text = shop.title
	status.Text = "메뉴를 고르면 손에 들려 줘요. 자리에 앉아서 드세요!"
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for index, item in ipairs(shop.items) do
		local price = if item.coins then string.format("%s %d", EconomyConfig.Icon, item.coins) else "무료"
		local button = make("TextButton", {
			Name = "Item_" .. item.key,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(255, 235, 242),
			AutoButtonColor = true,
			Text = "",
		}, list)
		round(button, 12)
		make("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = item.color,
		}, button).Name = "Swatch"
		make("TextLabel", {
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -120, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(60, 40, 50),
			Text = item.name,
		}, button)
		make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.fromOffset(80, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(200, 90, 130),
			Text = price,
		}, button)
		button.MouseButton1Click:Connect(function()
			status.Text = "준비 중…"
			local ok, message = remote:InvokeServer("Buy", shopKey, item.key)
			status.Text = if typeof(message) == "string" then message else (if ok then "나왔어요!" else "주문하지 못했어요.")
			if ok then task.delay(1.2, function() if openShop == shopKey then hide() end end) end
		end)
	end
	local height = 100 + #shop.items * 48
	panel.Size = UDim2.fromOffset(320, height)
	-- Phones: scale the whole menu down to fit the screen height (user mobile
	-- test 2026-10-22: the bottom was cut off).
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 800)
	local scale = panel:FindFirstChildOfClass("UIScale") or make("UIScale", {}, panel)
	scale.Scale = math.clamp(math.min((vp.Y - 24) / height, (vp.X - 24) / 320), 0.5, 1)
	panel.Visible = true
end

notify.OnClientEvent:Connect(function(kind: any, shopKey: any)
	if kind == "Open" and typeof(shopKey) == "string" then show(shopKey) end
end)

-- Close when the player walks away from the counter.
task.spawn(function()
	while true do
		task.wait(0.5)
		if openShop and openedAt then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - openedAt).Magnitude > 14 then hide() end
		end
	end
end)
