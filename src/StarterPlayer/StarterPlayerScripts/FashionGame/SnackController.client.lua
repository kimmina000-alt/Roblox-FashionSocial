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
		-- (D-1063) a cut-out picture of the item when there is one (the OH24 cup
		-- ramen), else its colour square
		local icon = SnackMenuArt.Icons[item.key]
		if icon then
			make("ImageLabel", {
				Position = UDim2.fromOffset(4, 2),
				Size = UDim2.fromOffset(36, 36),
				BackgroundTransparency = 1,
				Image = icon,
				ScaleType = Enum.ScaleType.Fit,
			}, button).Name = "Swatch"
		else
			make("Frame", {
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = item.color,
			}, button).Name = "Swatch"
		end
		make("TextLabel", {
			Position = UDim2.fromOffset(if icon then 46 else 40, 0),
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

-- Food and tables by touch (D-950, user 2026-11-07, with a screen recording of
-- another game: "테이블에 놓기 E버튼 삭제. 테이블에 놓는 기능 유지. 음식 들고
-- 테이블 위로 드래그하면 음식 실루엣으로 테이블 위에 배치할 수 있으면 녹색 배치할
-- 수 없는 곳이면 빨간색으로 보이게 해 줘. 탭해서 놓으세요 글씨는 넣지 말고. 꾹
-- 누르면 먹던 거면 먹던 그 상태로 인벤토리로 다시 들어오게 해."). No buttons:
--   * food in hand, the pointer (mouse, or a finger on the screen) over a food
--     table → a flat round silhouette of it on the top there: green where it
--     can go, red where not (off the edge, on another food, too far). A click /
--     a finger let go there puts it down on that spot.
--   * a click / tap anywhere else → a bite (the food tools only bite when
--     this script calls tool:Activate(): ManualActivationOnly, SnackService)
--   * my food on a table: a short tap = a spoonful (국밥 / 공깃밥 / 컵라면), a
--     long press (0.6 s) = back into the backpack as it is
do
	local CollectionService = game:GetService("CollectionService")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local FOOD_TABLES = { "CafeTable", "GukbapTable", "SnackTable" }
	local REACH = 9 -- (the server's check too)
	local OVERLAP = 0.85 -- (SnackService: another food closer than this part of the two reaches)
	local HOLD = 0.6 -- seconds for a long press
	local GREEN, RED = Color3.fromRGB(60, 235, 90), Color3.fromRGB(240, 50, 50)

	-- (D-952) a whole cake / 수육 plate ("Plate") is put down the same way; a
	-- piece taken from a plate ("Piece") is only eaten, never put down
	local function heldAny(): Tool?
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		return if tool and (tool:GetAttribute("Snack") or tool:GetAttribute("Plate")) and not tool:GetAttribute("CafeOrder") then tool else nil
	end
	local function heldFood(): Tool?
		local tool = heldAny()
		return if tool and not tool:GetAttribute("Piece") then tool else nil
	end
	local function sharedPlateOf(part: Instance?): Model?
		local node = part
		while node and node ~= workspace do
			if node:IsA("Model") and node.Name == "SharedPlate" then return node end
			node = node.Parent
		end
		return nil
	end
	local function foodTableOf(part: Instance?): BasePart?
		local node = part
		while node and node ~= workspace do
			if node:IsA("BasePart") then
				for _, tag in ipairs(FOOD_TABLES) do
					if CollectionService:HasTag(node, tag) then return node end
				end
			end
			node = node.Parent
		end
		return nil
	end
	local function placedOf(part: Instance?): Model?
		local node = part
		while node and node ~= workspace do
			if node:IsA("Model") and node.Name == "PlacedFood" then return node end
			node = node.Parent
		end
		return nil
	end

	-- the silhouette: a flat disc on the table top (this screen only)
	local ghost = Instance.new("Part")
	ghost.Name = "FoodPlaceGhost"
	ghost.Shape = Enum.PartType.Cylinder
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Material = Enum.Material.Neon
	ghost.Transparency = 0.35
	ghost.Size = Vector3.new(0.06, 1.6, 1.6)

	local function radiusOf(tool: Tool): number
		local r = tool:GetAttribute("PlaceRadius")
		return if typeof(r) == "number" then r else 0.8
	end
	local function rayAt(screen: Vector2): RaycastResult?
		local camera = workspace.CurrentCamera
		if not camera then return nil end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance, ghost }
		-- (touch positions come with or without the top bar inset, as at the club
		-- tables: try both, keep the one that lands on a food table)
		local best: RaycastResult? = nil
		for _, ray in ipairs({ camera:ViewportPointToRay(screen.X, screen.Y), camera:ScreenPointToRay(screen.X, screen.Y) }) do
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 150, params)
			if hit and (foodTableOf(hit.Instance) or placedOf(hit.Instance) or sharedPlateOf(hit.Instance)) then return hit end
			best = best or hit
		end
		return best
	end
	-- where the held food would go for a pointer at `screen`: table, spot, ok
	local function spotFor(screen: Vector2, tool: Tool): (BasePart?, Vector3?, boolean)
		local hit = rayAt(screen)
		if not hit then return nil, nil, false end
		local tablePart = foodTableOf(hit.Instance)
		if not tablePart then return nil, nil, false end
		local radius = radiusOf(tool)
		-- (D-1141) the top whichever side faces up (round tables are standing cylinders)
		local fits, spot = SnackConfig.onTable(tablePart, hit.Position, radius)
		local ok = placedOf(hit.Instance) == nil and sharedPlateOf(hit.Instance) == nil and fits
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if ok and root and root:IsA("BasePart") then
			ok = Vector3.new(spot.X - root.Position.X, 0, spot.Z - root.Position.Z).Magnitude <= REACH
		end
		if ok then
			for _, other in ipairs(tablePart:GetChildren()) do
				if other:IsA("Model") and (other.Name == "PlacedFood" or other.Name == "SharedPlate") then
					local r2 = other:GetAttribute("Radius")
					local c = other:GetBoundingBox().Position
					if Vector3.new(c.X - spot.X, 0, c.Z - spot.Z).Magnitude < (radius + (if typeof(r2) == "number" then r2 else 0.8)) * OVERLAP then
						ok = false
						break
					end
				end
			end
		end
		return tablePart, spot, ok
	end
	local function showGhost(screen: Vector2?): (BasePart?, Vector3?, boolean)
		local tool = heldFood()
		if not tool or not screen then
			ghost.Parent = nil
			return nil, nil, false
		end
		local tablePart, spot, ok = spotFor(screen, tool)
		if not tablePart or not spot then
			ghost.Parent = nil
			return nil, nil, false
		end
		local d = radiusOf(tool) * 2
		ghost.Size = Vector3.new(0.06, d, d)
		ghost.CFrame = CFrame.new(spot + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ghost.Color = if ok then GREEN else RED
		ghost.Parent = workspace
		return tablePart, spot, ok
	end

	local busy = false
	local function ask(action: string, a: any, b: any)
		if busy then return end
		busy = true
		task.spawn(function()
			local ok, okServer, message = pcall(function() return remote:InvokeServer(action, a, b) end)
			if ok and not okServer and typeof(message) == "string" then
				StarterGui:SetCore("SendNotification", { Title = "🍽", Text = message, Duration = 3 })
			end
			busy = false
		end)
	end

	-- (D-1035, user 2026-11-09: "그릇 위에 있는 바이트 중에 마우스 올려서 선택되는
	-- 바이트를 먹게 해") a piece of a model plate (수육 Bite1..Bite14) under the
	-- pointer: that one is taken; on a PC it lights up while the mouse is over it
	local function pieceOf(part: Instance?): BasePart?
		if part and part:IsA("BasePart") and part.Name:match("^Bite%d+$") and sharedPlateOf(part) then return part end
		-- (D-1037) a piece of my 국밥 on the table (its parts carry Bite = n)
		if part and part:IsA("BasePart") and typeof(part:GetAttribute("Bite")) == "number" and part.Transparency < 1 then
			local placed = placedOf(part)
			if placed and placed:GetAttribute("Owner") == player.UserId then return part end
		end
		return nil
	end
	local hover = Instance.new("Highlight")
	hover.Name = "PieceHover"
	hover.FillColor = Color3.fromRGB(255, 236, 170)
	hover.FillTransparency = 0.55
	hover.OutlineColor = Color3.new(1, 1, 1)
	hover.OutlineTransparency = 0
	hover.DepthMode = Enum.HighlightDepthMode.Occluded

	-- PC: the silhouette follows the mouse while food is in hand
	RunService.RenderStepped:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return end
		if heldFood() then
			showGhost(UserInputService:GetMouseLocation())
			hover.Parent = nil
		else
			if ghost.Parent then ghost.Parent = nil end
			local hit = rayAt(UserInputService:GetMouseLocation())
			local piece = hit and pieceOf(hit.Instance)
			if piece then
				hover.Adornee = piece
				hover.Parent = piece
			elseif hover.Parent then
				hover.Parent = nil
			end
		end
	end)

	-- one press (mouse button or finger): what it lands on decides
	type Press = { input: InputObject, start: Vector2, at: number, placed: Model?, plate: Model?, piece: BasePart?, moved: boolean, done: boolean }
	local press: Press? = nil
	local function pointOf(input: InputObject): Vector2
		-- (mouse: GetMouseLocation counts the inset like the viewport rays)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then return UserInputService:GetMouseLocation() end
		return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local screen = pointOf(input)
		local hit = rayAt(screen)
		local placed = hit and placedOf(hit.Instance)
		if placed and placed:GetAttribute("Owner") ~= player.UserId then placed = nil end
		local p: Press = { input = input, start = screen, at = os.clock(), placed = placed, plate = hit and sharedPlateOf(hit.Instance), piece = hit and pieceOf(hit.Instance), moved = false, done = false }
		press = p
		if heldFood() then showGhost(screen) end
		-- a long press on my food on the table takes it back
		if placed then
			task.delay(HOLD, function()
				if press == p and not p.done and not p.moved and placed.Parent then
					p.done = true
					ask("PickUp", placed)
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local p = press
		if not p or (input ~= p.input and input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
		local screen = if input.UserInputType == Enum.UserInputType.MouseMovement then UserInputService:GetMouseLocation() else pointOf(input)
		if (screen - p.start).Magnitude > 14 then p.moved = true end
		-- a finger dragged over a table: the silhouette under it
		if input.UserInputType == Enum.UserInputType.Touch and heldFood() then showGhost(screen) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local p = press
		if not p or input ~= p.input then return end
		press = nil
		if p.done then return end
		p.done = true
		local screen = pointOf(input)
		local tool = heldFood()
		local short = os.clock() - p.at < HOLD
		-- (D-1104) the OH24 microwave: a tap on it with a 삼각김밥 in the hand
		-- warms it; a tap on the 삼각김밥 inside (door open) takes it back
		if short and not p.moved then
			-- (D-1113) both rays (with and without the top bar inset): the first one
			-- often landed on the microwave's frame, not the small 삼각김밥 inside
			local hit: RaycastResult? = nil
			local camera = workspace.CurrentCamera
			if camera then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { player.Character :: Instance, ghost }
				for _, ray in ipairs({ camera:ScreenPointToRay(screen.X, screen.Y), camera:ViewportPointToRay(screen.X, screen.Y) }) do
					local h = workspace:Raycast(ray.Origin, ray.Direction * 150, params)
					if h and (CollectionService:HasTag(h.Instance, "MicrowaveFood") or CollectionService:HasTag(h.Instance, "Microwave")) then
						if not hit or CollectionService:HasTag(h.Instance, "MicrowaveFood") then hit = h end
					end
				end
			end
			if hit then
				local held = heldAny()
				local key = held and held:GetAttribute("Snack")
				if input.UserInputType == Enum.UserInputType.Touch then ghost.Parent = nil end
				if typeof(key) == "string" and string.sub(key, 1, 6) == "samgak" then
					ask("Microwave", hit.Instance) -- (the server takes one out first when it is done)
				else
					ask("MicrowaveTake", hit.Instance) -- (a tap on the open microwave or on it)
				end
				return
			end
		end
		if tool then
			local tablePart, spot, ok = spotFor(screen, tool)
			if input.UserInputType == Enum.UserInputType.Touch then ghost.Parent = nil end
			if tablePart and spot then
				-- over a food table: put it down there (green), or nothing (red)
				if ok then ask("PutDown", tablePart, spot) end
				return
			end
		end
		-- (D-952) a short tap on a shared plate (cake / 수육): a piece of it
		if p.plate and short and not p.moved and p.plate.Parent then
			ask("TakePiece", p.plate, p.piece) -- (D-1035: the piece tapped, if any)
			return
		end
		local eat = heldAny()
		-- (D-1053) the cup ramen: a tap on the OH24 hot water dispenser pours, any
		-- other tap is its next step (lid off, wait, eat: SnackService / RamenCup)
		if eat and eat:GetAttribute("Ramen") then
			if short and not p.moved then
				local hit = rayAt(screen)
				if hit and CollectionService:HasTag(hit.Instance, "HotWater") then
					ask("HotWater", hit.Instance)
				else
					ask("Ramen", eat)
				end
			end
			return
		end
		if eat and eat:GetAttribute("Snack") then
			-- anywhere else: a bite (a short tap or click, not a camera drag)
			if short and not p.moved then eat:Activate() end
			return
		end
		if eat then return end -- (a plate in hand: nothing off the tables)
		-- empty hands: a short tap on my 국밥 on the table is a spoonful (of the
		-- piece tapped, D-1037); on my drink or snack there: back in the hand
		-- and a sip / bite (D-1037, user: "물 테이블에 설치하면 못 먹음")
		if p.placed and short and not p.moved then
			ask("Spoon", p.placed, p.piece)
		end
	end)
	local function watch(character: Model)
		character.ChildRemoved:Connect(function()
			if not heldFood() then ghost.Parent = nil end
		end)
	end
	if player.Character then watch(player.Character) end
	player.CharacterAdded:Connect(watch)
end

-- (D-1129) the other half of my 친구바 in my left hand: its "반쪽 받기" is for
-- the others, not for me (FriendBar)
do
	local function hideOwn(d: Instance)
		if d:IsA("ProximityPrompt") and d.Name == "FriendBarTake" then d.Enabled = false end
	end
	local function watchHalf(character: Model)
		for _, d in ipairs(character:GetDescendants()) do hideOwn(d) end
		character.DescendantAdded:Connect(hideOwn)
	end
	if player.Character then watchHalf(player.Character) end
	player.CharacterAdded:Connect(watchHalf)
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
