--!strict
-- Club purchases and drinks (client).
--   * Paid areas: the server says "Gate" when a player without access walks
--     into the VIP balcony or DJ booth → Roblox purchase window.
--   * Bartender "음료 주문" → drink menu (free drinks first, paid below).
--   * Table "병 놓기" → 공개 범위 (모든 사람 / 친구만 / 나만) → place.
--   * Toasts from the server ("Toast").
-- Purchases use Roblox's own windows (MarketplaceService). Items whose ID is
-- still 0 show a labelled [Studio 테스트] window in Studio only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction
local ClubNotify = Remotes:WaitForChild("ClubNotify") :: RemoteEvent

local COLORS = {
	panel = Color3.fromRGB(18, 18, 24),
	card = Color3.fromRGB(38, 38, 50),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	accent = Color3.fromRGB(255, 80, 200),
	robux = Color3.fromRGB(0, 176, 111),
}

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then instance.Parent = parent end
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local gui = create("ScreenGui", {
	Name = "FashionClubShopGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 30,
}, playerGui)

--------------------------------------------------
-- Toasts
--------------------------------------------------

local toastLabel = create("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(460, 44),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.25,
	TextColor3 = COLORS.text,
	TextSize = 17,
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
corner(toastLabel, 12)
local toastToken = 0
local function toast(message: string)
	if message == "" then return end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3.2, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

--------------------------------------------------
-- Generic modal (title, body, buttons)
--------------------------------------------------

local modal = create("Frame", {
	Name = "Modal",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(360, 200),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
}, gui)
corner(modal, 16)
local modalTitle = create("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -32, 0, 28),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
}, modal)
local modalBody = create("TextLabel", {
	Name = "Body",
	Position = UDim2.fromOffset(16, 46),
	Size = UDim2.new(1, -32, 1, -110),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.sub,
	TextSize = 16,
	TextWrapped = true,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 21,
}, modal)
local modalButtons = create("Frame", {
	Name = "Buttons",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -32, 0, 40),
	BackgroundTransparency = 1,
	ZIndex = 21,
}, modal)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
}, modalButtons)

type ModalButton = { name: string, text: string, color: Color3?, onClick: () -> () }
local function showModal(title: string, body: string, buttons: {ModalButton})
	modalTitle.Text = title
	modalBody.Text = body
	for _, child in ipairs(modalButtons:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	local width = math.floor((328 - 8 * (#buttons - 1)) / #buttons)
	for index, spec in ipairs(buttons) do
		local button = create("TextButton", {
			Name = spec.name,
			LayoutOrder = index,
			Size = UDim2.fromOffset(width, 40),
			BackgroundColor3 = spec.color or COLORS.card,
			Text = spec.text,
			TextColor3 = COLORS.text,
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			ZIndex = 22,
		}, modalButtons)
		corner(button, 10)
		button.MouseButton1Click:Connect(function()
			modal.Visible = false
			spec.onClick()
		end)
	end
	modal.Visible = true
end
local function closeModal() modal.Visible = false end

--------------------------------------------------
-- Purchases
--------------------------------------------------

local function studioTest(kind: string, key: string, name: string, price: number)
	showModal("[Studio 테스트] " .. name,
		string.format("상품 ID가 아직 없어 실제 결제창 대신 테스트 구매를 합니다.\n실제 가격(예정): %d R$ · 결제는 일어나지 않습니다.", price),
		{
			{ name = "Cancel", text = "취소", onClick = function() end },
			{ name = "Buy", text = "테스트 구매", color = COLORS.robux, onClick = function()
				local ok, message = ClubShop:InvokeServer("StudioTestBuy", { kind = kind, key = key })
				if not ok then toast(tostring(message or "테스트 구매 실패")) end
			end },
		})
end

local function buyPass(key: string)
	local pass = MonetizationConfig.GamePasses[key]
	if not pass then return end
	if pass.id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif RunService:IsStudio() then
		studioTest("pass", key, pass.name, pass.price)
	else
		toast("준비 중인 상품입니다.")
	end
end

local function buyProduct(key: string)
	local product = MonetizationConfig.Products[key]
	if not product then return end
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		studioTest("product", key, product.name, product.price)
	else
		toast("준비 중인 상품입니다.")
	end
end

local function djStatusLine(): string
	local dj = FashionGame:GetAttribute("ClubDJ")
	local waiting = FashionGame:GetAttribute("ClubDJQueue") or 0
	if typeof(dj) == "number" and dj ~= 0 then
		local djPlayer = Players:GetPlayerByUserId(dj)
		return string.format("지금 DJ: %s · 대기 %d명 — 구매하면 대기열에 들어가요.",
			if djPlayer then djPlayer.DisplayName else "?", waiting)
	end
	return string.format("DJ 부스가 비어 있어요! 구매하면 바로 %d분 동안 DJ가 됩니다.", MonetizationConfig.DJMinutes)
end

ClubNotify.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "Toast" and typeof(value) == "string" then
		toast(value)
	elseif kind == "Gate" then
		if value == "VIP" then
			toast("VIP 전용 공간이에요. VIP 패스로 입장할 수 있어요.")
			buyPass("VIP")
		elseif value == "DJ" then
			toast(djStatusLine())
			buyProduct("DJ")
		end
	elseif kind == "DJTurn" then
		-- Never move people without asking (user, 2026-10-20).
		local queued = typeof(value) == "table" and value.queued == true
		if queued then
			showModal("🎧 DJ 차례가 됐어요!",
				"DJ 부스로 이동할까요?\nNO를 누르면 다음 순서로 넘어가며, 구매한 DJ 시간은 환불되지 않아요.",
				{
					{ name = "No", text = "NO", color = COLORS.card, onClick = function()
						local ok, message = ClubShop:InvokeServer("DJPass", nil)
						toast(tostring(message or (if ok then "" else "넘기지 못했어요.")))
					end },
					{ name = "Ok", text = "OK · 이동", color = COLORS.robux, onClick = function()
						ClubShop:InvokeServer("DJGo", nil)
					end },
				})
		else
			showModal("🎧 지금부터 DJ예요!",
				"DJ 부스로 이동할까요?\n직접 걸어가도 돼요. DJ 시간은 지금부터 흘러요.",
				{
					{ name = "No", text = "직접 갈게요", color = COLORS.card, onClick = function() end },
					{ name = "Ok", text = "OK · 이동", color = COLORS.robux, onClick = function()
						ClubShop:InvokeServer("DJGo", nil)
					end },
				})
		end
	elseif kind == "GateQueue" then
		-- Someone is DJing: only the DJ's invited guests go up (D-061).
		local dj = FashionGame:GetAttribute("ClubDJ")
		local djPlayer = typeof(dj) == "number" and Players:GetPlayerByUserId(dj)
		local product = MonetizationConfig.Products.DJ
		showModal("DJ 존",
			string.format("지금은 DJ %s님과 DJ가 초대한 사람만 올라갈 수 있어요.\n다음 DJ가 되려면 대기열에 들어가세요 (대기 %d명).",
				if djPlayer then djPlayer.DisplayName else "", FashionGame:GetAttribute("ClubDJQueue") or 0),
			{
				{ name = "Close", text = "닫기", onClick = function() end },
				{ name = "Queue", text = string.format("DJ 대기 · R$%d", product.price), color = COLORS.robux, onClick = function()
					buyProduct("DJ")
				end },
			})
	end
end)

--------------------------------------------------
-- Drink menu (bartender)
--------------------------------------------------

local function carried(attribute: string): number
	local count = 0
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute(attribute) ~= nil then count += 1 end
			end
		end
	end
	return count
end

local menu = create("Frame", {
	Name = "DrinkMenu",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(340, 300),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
}, gui)
corner(menu, 16)
create("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -60, 0, 30),
	BackgroundTransparency = 1,
	Text = "🍹 음료 주문",
	TextColor3 = COLORS.text,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, menu)
local menuClose = create("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = COLORS.card,
	Text = "X",
	TextColor3 = COLORS.text,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	ZIndex = 11,
}, menu)
corner(menuClose, 15)
menuClose.MouseButton1Click:Connect(function() menu.Visible = false end)
local list = create("ScrollingFrame", {
	Name = "List",
	Position = UDim2.fromOffset(12, 48),
	Size = UDim2.new(1, -24, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 11,
}, menu)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local function sectionHeader(text: string, order: number)
	create("TextLabel", {
		Name = "Header_" .. order,
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 24),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = COLORS.sub,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, list)
end

local function order(drink: any)
	if carried("Bottle") >= ClubConfig.MaxBottlesCarried then
		toast(string.format("병은 %d개까지 들 수 있어요. 테이블에 먼저 놓아 주세요.", ClubConfig.MaxBottlesCarried))
		return
	end
	menu.Visible = false
	if drink.product then
		buyProduct(drink.product)
		return
	end
	local ok, message = ClubShop:InvokeServer("Order", drink.key)
	toast(tostring(message or (if ok then "" else "주문하지 못했어요.")))
end

local function buildMenu()
	local index = 0
	sectionHeader("무료 음료", 0)
	local paidStarted = false
	for _, drink in ipairs(ClubConfig.Drinks) do
		index += 1
		if drink.product and not paidStarted then
			paidStarted = true
			sectionHeader("유료 음료", index)
			index += 1
		end
		local product = drink.product and MonetizationConfig.Products[drink.product]
		local row = create("TextButton", {
			Name = "Drink_" .. drink.key,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 48),
			BackgroundColor3 = COLORS.card,
			Text = "",
			AutoButtonColor = true,
			ZIndex = 12,
		}, list)
		corner(row, 10)
		local swatch = create("Frame", {
			Position = UDim2.fromOffset(10, 9),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = drink.color,
			ZIndex = 13,
		}, row)
		corner(swatch, 15)
		create("TextLabel", {
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -150, 1, 0),
			BackgroundTransparency = 1,
			Text = drink.name,
			TextColor3 = COLORS.text,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		}, row)
		local price = create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(84, 30),
			BackgroundColor3 = if product then COLORS.robux else COLORS.accent,
			Text = if product then ("R$ " .. tostring(product.price)) else "무료",
			TextColor3 = COLORS.text,
			TextSize = 15,
			Font = Enum.Font.GothamBold,
			ZIndex = 13,
		}, row)
		corner(price, 15)
		row.MouseButton1Click:Connect(function() order(drink) end)
		if drink.coins then
			-- Same drink for coins (deliberately expensive, ECONOMY.md §4).
			local coinButton = create("TextButton", {
				Name = "Coins",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -100, 0.5, 0),
				Size = UDim2.fromOffset(84, 30),
				BackgroundColor3 = Color3.fromRGB(230, 170, 40),
				Text = "💰 " .. tostring(drink.coins),
				TextColor3 = COLORS.text,
				TextSize = 15,
				Font = Enum.Font.GothamBold,
				ZIndex = 14,
			}, row)
			corner(coinButton, 15)
			coinButton.MouseButton1Click:Connect(function()
				menu.Visible = false
				showModal(drink.name .. " · 코인으로 사기",
					string.format("%d 코인을 써서 %s 한 병을 살까요?\n(지금 %d 코인)", drink.coins, drink.name, player:GetAttribute("Coins") or 0),
					{
						{ name = "Cancel", text = "취소", onClick = function() end },
						{ name = "Buy", text = "💰 " .. tostring(drink.coins), color = Color3.fromRGB(230, 170, 40), onClick = function()
							local ok, message = ClubShop:InvokeServer("OrderCoins", drink.key)
							toast(tostring(message or (if ok then "" else "살 수 없어요.")))
						end },
					})
			end)
		end
	end
end
buildMenu()

--------------------------------------------------
-- Prompts: bartender, table, own-bottle "치우기"
--------------------------------------------------

local function chooseVisibility(tablePart: Instance)
	local buttons: {ModalButton} = {}
	for _, entry in ipairs(ClubConfig.Visibility) do
		table.insert(buttons, { name = "Vis_" .. entry.key, text = entry.name, color = COLORS.accent, onClick = function()
			local ok, message = ClubShop:InvokeServer("Place", { table = tablePart, visibility = entry.key })
			if ok then
				toast(string.format("병을 놓았어요 · %s 마실 수 있어요", entry.name))
			else
				toast(tostring(message or "놓지 못했어요."))
			end
		end })
	end
	showModal("누가 마실 수 있게 할까요?", "병을 테이블에 놓으면 고른 사람들이 '컵에 따르기'로 마실 수 있어요.", buttons)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BartenderPrompt" then
		closeModal()
		menu.Visible = true
	elseif prompt.Name == "PlacePrompt" then
		if carried("Bottle") == 0 then
			toast("들고 있는 병이 없어요. 바텐더에게 음료를 주문하세요.")
			return
		end
		chooseVisibility(prompt.Parent :: Instance)
	end
end)

-- "치우기" is only for the bottle's owner.
local function watchClearPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == "ClearPrompt" then
		local bottle = instance.Parent
		instance.Enabled = bottle ~= nil and bottle:GetAttribute("Owner") == player.UserId
	end
end
for _, instance in ipairs(workspace:GetDescendants()) do watchClearPrompt(instance) end
workspace.DescendantAdded:Connect(watchClearPrompt)

-- Close the menu when walking away from the bartender.
task.spawn(function()
	while true do
		task.wait(0.5)
		if menu.Visible then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local nearest = math.huge
			for _, spot in ipairs(game:GetService("CollectionService"):GetTagged("BartenderSpot")) do
				if spot:IsA("BasePart") and root then
					nearest = math.min(nearest, (spot.Position - root.Position).Magnitude)
				end
			end
			if nearest > 22 then menu.Visible = false end
		end
	end
end)

-- Small pop when a toast appears.
toastLabel:GetPropertyChangedSignal("Text"):Connect(function()
	toastLabel.Size = UDim2.fromOffset(440, 40)
	TweenService:Create(toastLabel, TweenInfo.new(0.15), { Size = UDim2.fromOffset(460, 44) }):Play()
end)
