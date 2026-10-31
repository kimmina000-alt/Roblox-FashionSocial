--!strict
-- Cafe / snack stand menu (SnackConfig, SnackService). Opens when the
-- server says so (the counter's "주문하기" prompt), closes on ✕ or when the
-- player walks away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local SnackConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("SnackConfig"))
local EconomyConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local remote = Remotes:WaitForChild("Snack") :: RemoteFunction
local notify = Remotes:WaitForChild("SnackNotify") :: RemoteEvent
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction

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

-- (IgnoreGuiInset like the club shop: the order window is placed under
-- TopBar.bottom(), which is measured from the screen top; on phones it sat
-- an inset too low, 2P phone test 2026-10-31)
local gui = make("ScreenGui", { Name = "SnackGui", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
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
-- (scrolls when the menu is longer than the screen: the cafe has 17 items)
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 50),
	Size = UDim2.new(1, -24, 1, -92),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Color3.fromRGB(220, 150, 180),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
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

local Popups = require(script.Parent:WaitForChild("Popups"))
local function hide()
	panel.Visible = false
	openShop = nil
	Popups.closed("Snack")
end
close.MouseButton1Click:Connect(hide)

-- the cafes' and the 국밥집's window in the club shop's look with the real
-- items (user 2026-10-31, ShopMenuUI); the other shops keep the list below
local SnackMenuArt = require(FashionGame:WaitForChild("Shared"):WaitForChild("SnackMenuArt"))
local pictureMenu = require(script.Parent:WaitForChild("ShopMenuUI")).new(gui)
local function hideAll()
	pictureMenu:hide()
	hide()
end

local function showPictures(shopKey: string, shop: any, statusText: string)
	panel.Visible = false
	pictureMenu:open(shopKey, shop, {
		buyCoins = function(item: any): (boolean, string?)
			pictureMenu:setStatus("준비 중…")
			local ok, message = remote:InvokeServer("Buy", shopKey, item.key)
			return ok == true, if typeof(message) == "string" then message else (if ok then "나왔어요!" else "주문하지 못했어요.")
		end,
		buyRobux = function(item: any)
			local product = item.product and MonetizationConfig.Products[item.product]
			if not product then return end
			if product.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.id)
			elseif RunService:IsStudio() then
				local ok, message = ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = item.product })
				pictureMenu:setStatus(if ok then "[Studio 테스트] 구매했어요." else tostring(message or "구매하지 못했어요."))
				return
			else
				pictureMenu:setStatus("준비 중인 상품이에요.")
				return
			end
			hideAll()
		end,
		onClose = function()
			openShop = nil
			Popups.closed("Snack")
		end,
	}, statusText)
end

local function show(shopKey: string)
	local shop = SnackConfig.Shops[shopKey]
	if not shop then return end
	openShop = shopKey
	Popups.opened("Snack", hideAll)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	openedAt = if root and root:IsA("BasePart") then root.Position else nil
	title.Text = shop.title
	status.Text = shop.hint or "메뉴를 고르면 손에 들려 줘요. 자리에 앉아서 드세요!"
	-- cafe job (D-099): with staff on duty the drink is brought to the customer
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character and other.Character:GetAttribute("CafeJob") == shopKey then
			status.Text = "☕ 알바생 근무 중! 주문하면 만들어서 자리로 가져다 줘요."
			break
		end
	end
	if SnackMenuArt.ShopTheme[shopKey] then
		showPictures(shopKey, shop, status.Text)
		return
	end
	pictureMenu:hide()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local order = 0
	local lastSection: string? = nil
	local rows = 0
	local headers = 0
	for _, item in ipairs(shop.items) do
		-- a small heading where the price tier changes
		if item.section and item.section ~= lastSection then
			lastSection = item.section
			order += 1
			headers += 1
			make("TextLabel", {
				Name = "Section",
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(170, 110, 140),
				Text = item.section,
			}, list)
		end
		order += 1
		rows += 1
		local product = item.product and MonetizationConfig.Products[item.product]
		local price = if product then string.format("R$ %d", product.price)
			elseif item.coins then string.format("%s %d", EconomyConfig.Icon, item.coins)
			else "무료"
		local button = make("TextButton", {
			Name = "Item_" .. item.key,
			LayoutOrder = order,
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
			Size = UDim2.new(1, if item.coins and item.product then -170 else -120, 1, 0),
			TextScaled = item.coins ~= nil and item.product ~= nil,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(60, 40, 50),
			Text = item.name,
		}, button)
		local both = product ~= nil and item.coins ~= nil
		local function buyRobux()
			if not (product and item.product) then return end
			-- Robux: the purchase window ([Studio 테스트] while the id is 0)
			if product.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.id)
			elseif RunService:IsStudio() then
				local ok, message = ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = item.product })
				status.Text = if ok then "[Studio 테스트] 구매했어요." else tostring(message or "구매하지 못했어요.")
			else
				status.Text = "준비 중인 상품이에요."
				return
			end
			hide()
		end
		local function buyCoins()
			status.Text = "준비 중…"
			local ok, message = remote:InvokeServer("Buy", shopKey, item.key)
			status.Text = if typeof(message) == "string" then message else (if ok then "나왔어요!" else "주문하지 못했어요.")
			if ok then task.delay(1.2, function() if openShop == shopKey then hide() end end) end
		end
		if both then
			-- coins or Robux (the strawberry cake): two small price buttons
			for k, spec in ipairs({ { string.format("%s %d", EconomyConfig.Icon, item.coins :: number), buyCoins }, { string.format("R$ %d", (product :: any).price), buyRobux } }) do
				local b = make("TextButton", {
					Name = if k == 1 then "PayCoins" else "PayRobux",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, if k == 1 then -66 else -6, 0.5, 0),
					Size = UDim2.fromOffset(56, 28),
					BackgroundColor3 = if k == 1 then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(120, 200, 120),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(50, 40, 40),
					Text = spec[1],
				}, button)
				round(b, 8)
				b.MouseButton1Click:Connect(spec[2])
			end
		else
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
		end
		button.MouseButton1Click:Connect(function()
			if both then
				status.Text = "💰 코인 또는 R$ 버튼을 눌러 주세요."
				return
			end
			if product and item.product then
				buyRobux()
				return
			end
			buyCoins()
		end)
	end
	local height = 100 + rows * 46 + headers * 26
	-- Phones (user mobile test 2026-10-22: the bottom was cut off): long menus
	-- scroll inside a panel no taller than the screen below the top bar
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 800)
	local maxHeight = math.max(220, vp.Y - 90)
	panel.Size = UDim2.fromOffset(320, math.min(height, maxHeight))
	local scale = panel:FindFirstChildOfClass("UIScale") or make("UIScale", {}, panel)
	scale.Scale = math.clamp((vp.X - 24) / 320, 0.6, 1)
	list.CanvasPosition = Vector2.zero
	panel.Visible = true
end

notify.OnClientEvent:Connect(function(kind: any, shopKey: any)
	if kind == "Open" and typeof(shopKey) == "string" then show(shopKey) end
	if kind == "Toast" and typeof(shopKey) == "string" then
		StarterGui:SetCore("SendNotification", { Title = "🍽", Text = shopKey, Duration = 4 })
	end
end)

-- "테이블에 놓기" on the food tables, only while food is in hand (user
-- 2026-10-26: 국밥 too). Local prompts: other players do not see them.
do
	local CollectionService = game:GetService("CollectionService")
	local prompts: {[BasePart]: ProximityPrompt} = {}
	local holding = false
	local function heldFood(): Tool?
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		return if tool and tool:GetAttribute("Snack") and not tool:GetAttribute("CafeOrder") then tool else nil
	end
	local function refresh()
		holding = heldFood() ~= nil
		for tablePart, prompt in pairs(prompts) do
			if tablePart.Parent then prompt.Enabled = holding else prompts[tablePart] = nil end
		end
	end
	local function add(tablePart: Instance)
		if not tablePart:IsA("BasePart") or prompts[tablePart] then return end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PutDownPrompt"
		prompt.ActionText = "테이블에 놓기"
		prompt.ObjectText = "들고 있는 음식"
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Enabled = holding
		prompt.Parent = tablePart
		prompt.Triggered:Connect(function()
			local ok, message = remote:InvokeServer("PutDown", tablePart)
			if not ok and typeof(message) == "string" then
				StarterGui:SetCore("SendNotification", { Title = "🍽", Text = message, Duration = 3 })
			end
		end)
		prompts[tablePart] = prompt
	end
	for _, tag in ipairs({ "CafeTable", "GukbapTable", "SnackTable" }) do
		for _, t in ipairs(CollectionService:GetTagged(tag)) do add(t) end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	end
	local function watch(character: Model)
		refresh()
		character.ChildAdded:Connect(refresh)
		character.ChildRemoved:Connect(refresh)
	end
	if player.Character then watch(player.Character) end
	player.CharacterAdded:Connect(watch)
end

-- Close when the player walks away from the counter.
task.spawn(function()
	while true do
		task.wait(0.5)
		if openShop and openedAt then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - openedAt).Magnitude > 14 then hideAll() end
		end
	end
end)
