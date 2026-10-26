--!strict
-- Club purchases and drinks (client).
--   * Paid areas: the server says "Gate" when a player without access walks
--     into the VIP balcony or DJ booth → Roblox purchase window.
--   * Bartender "음료 주문" → drink menu (free drinks first, paid below).
--   * Item seller "불꽃 · 아이템" → sparklers, sparkler bucket set, cold spark
--     (tables themselves work by touch: TableTapController).
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
-- toasts from other club scripts (TableTapController)
local localToast = Instance.new("BindableEvent")
localToast.Name = "ClubLocalToast"
localToast.Event:Connect(function(message: any)
	if typeof(message) == "string" then toast(message) end
end)
localToast.Parent = script.Parent

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
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, modalButtons)

type ModalButton = { name: string, text: string, color: Color3?, onClick: () -> () }
local Popups = require(script.Parent:WaitForChild("Popups"))
-- closeFar: a window opened by walking into a gate closes again when the
-- player walks away from that spot (user 2026-10-24: the VIP pass window
-- stayed open after leaving the gate)
local modalOpenedAt: Vector3? = nil
local function rootPosition(): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end
local function showModal(title: string, body: string, buttons: {ModalButton}, closeFar: boolean?)
	Popups.opened("ClubShop", function() modal.Visible = false end)
	modalOpenedAt = if closeFar then rootPosition() else nil
	modal.Size = UDim2.fromOffset(360, 200)
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
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			ZIndex = 22,
		}, modalButtons)
		corner(button, 10)
		-- long names (e.g. 오미자 히비스커스) shrink to fit the button
		create("UITextSizeConstraint", { MaxTextSize = 16 }, button)
		create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, button)
		button.MouseButton1Click:Connect(function()
			modal.Visible = false
			Popups.closed("ClubShop")
			spec.onClick()
		end)
	end
	modal.Visible = true
end
local function closeModal() modal.Visible = false; Popups.closed("ClubShop") end
task.spawn(function()
	while true do
		task.wait(0.5)
		local at = modalOpenedAt
		if modal.Visible and at then
			local now = rootPosition()
			if not now or (now - at).Magnitude > 14 then
				modalOpenedAt = nil
				closeModal()
			end
		end
	end
end)

--------------------------------------------------
-- Purchases
--------------------------------------------------

local function studioTest(kind: string, key: string, name: string, price: number, closeFar: boolean?)
	showModal("[Studio 테스트] " .. name,
		string.format("상품 ID가 아직 없어 실제 결제창 대신 테스트 구매를 합니다.\n실제 가격(예정): %d R$ · 결제는 일어나지 않습니다.", price),
		{
			{ name = "Cancel", text = "취소", onClick = function() end },
			{ name = "Buy", text = "테스트 구매", color = COLORS.robux, onClick = function()
				local ok, message = ClubShop:InvokeServer("StudioTestBuy", { kind = kind, key = key })
				if not ok then toast(tostring(message or "테스트 구매 실패")) end
			end },
		}, closeFar)
end

local function buyPass(key: string, closeFar: boolean?)
	local pass = MonetizationConfig.GamePasses[key]
	if not pass then return end
	if pass.id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif RunService:IsStudio() then
		studioTest("pass", key, pass.name, pass.price, closeFar)
	else
		toast("준비 중인 상품입니다.")
	end
end

local function buyProduct(key: string, closeFar: boolean?)
	local product = MonetizationConfig.Products[key]
	if not product then return end
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		studioTest("product", key, product.name, product.price, closeFar)
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
			buyPass("VIP", true)
		elseif value == "DJ" then
			toast(djStatusLine())
			buyProduct("DJ", true)
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
	Size = UDim2.fromOffset(380, 420),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
}, gui)
corner(menu, 16)
-- Up to 380 x 420, below the top-bar buttons; on a phone in landscape it
-- keeps its width and gets shorter (the list scrolls) (2P phone test 2026-10-25)
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local function layoutMenu()
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 700)
	local top = TopBar.bottom() + 8
	menu.AnchorPoint = Vector2.new(0.5, 0)
	menu.Position = UDim2.new(0.5, 0, 0, top)
	menu.Size = UDim2.fromOffset(math.min(380, vp.X - 24), math.clamp(vp.Y - top - 12, 180, 420))
end
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

local MessagePrompt = require(script.Parent:WaitForChild("MessagePrompt"))
local COIN = Color3.fromRGB(230, 170, 40)
local VIP_GOLD = Color3.fromRGB(255, 200, 70)

local function isVip(): boolean
	return player:GetAttribute("Pass_VIP") == true
end

-- Robux price shown in the menu: the dashboard price once the product has an
-- id (so Roblox price tests show the price this player really pays), else
-- the planned price from MonetizationConfig.
local livePrices: {[string]: number} = {}
local function productPrice(key: string): number
	local product = MonetizationConfig.Products[key]
	if not product then return 0 end
	if product.id ~= 0 and livePrices[key] == nil then
		livePrices[key] = product.price
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
			end)
			if ok and info and typeof(info.PriceInRobux) == "number" then
				livePrices[key] = info.PriceInRobux
			end
		end)
	end
	return livePrices[key] or product.price
end

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

local function handsFull(): boolean
	if carried("Bottle") >= ClubConfig.MaxBottlesCarried then
		toast(string.format("병은 %d개까지 들 수 있어요. 테이블에 먼저 놓아 주세요.", ClubConfig.MaxBottlesCarried))
		return true
	end
	return false
end

-- Picks a flavour / can colour first when the drink has them.
local function withVariant(drink: any, after: (variantKey: string?) -> ())
	if not drink.variants then
		after(nil)
		return
	end
	local buttons: {ModalButton} = {}
	for _, variant in ipairs(drink.variants) do
		table.insert(buttons, { name = "Var_" .. variant.key, text = variant.name, color = variant.color, onClick = function()
			after(variant.key)
		end })
	end
	showModal(drink.name, "맛(색)을 골라 주세요.", buttons)
end

-- method: "order" (free / tier-1 coins), "coins" (tier 2), "robux"
local function purchase(drink: any, method: string)
	if handsFull() then return end
	menu.Visible = false
	if drink.vipOnly and not isVip() then
		toast("VIP 전용 음료예요. VIP 패스로 열 수 있어요.")
		buyPass("VIP")
		return
	end
	withVariant(drink, function(variantKey)
		local payload = { drink = drink.key, variant = variantKey }
		if method == "order" then
			local ok, message = ClubShop:InvokeServer("Order", payload)
			toast(tostring(message or (if ok then "" else "주문하지 못했어요.")))
		elseif method == "coins" then
			local price = ClubConfig.coinPrice(drink, isVip()) or 0
			showModal(drink.name .. " · 코인으로 사기",
				string.format("%d 코인을 써서 한 병(6잔)을 살까요?\n(지금 %d 코인)%s", price, player:GetAttribute("Coins") or 0,
					if isVip() then "\n👑 VIP 20% 할인가예요." else ""),
				{
					{ name = "Cancel", text = "취소", onClick = function() end },
					{ name = "Buy", text = "💰 " .. tostring(price), color = COIN, onClick = function()
						local ok, message = ClubShop:InvokeServer("OrderCoins", payload)
						toast(tostring(message or (if ok then "" else "살 수 없어요.")))
					end },
				})
		else
			if variantKey then ClubShop:InvokeServer("SetVariant", payload) end
			local key = if isVip() and drink.vipProduct then drink.vipProduct else drink.product
			if key then buyProduct(key) end
		end
	end)
end

local function pill(row: Instance, x: number, width: number, text: string, color: Color3, onClick: () -> ())
	local button = create("TextButton", {
		Name = "Price",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -x, 0.5, 0),
		Size = UDim2.fromOffset(width, 30),
		BackgroundColor3 = color,
		Text = text,
		RichText = true,
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		ZIndex = 14,
	}, row)
	corner(button, 15)
	button.MouseButton1Click:Connect(onClick)
	return button
end

local function buildMenu()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local vip = isVip()
	local index = 0
	local lastTier = 0
	for _, drink in ipairs(ClubConfig.Drinks) do
		if drink.tier ~= lastTier then
			lastTier = drink.tier
			index += 1
			sectionHeader(ClubConfig.TierNames[drink.tier] or "", index)
		end
		index += 1
		local row = create("Frame", {
			Name = "Drink_" .. drink.key,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 52),
			BackgroundColor3 = if drink.vipOnly then Color3.fromRGB(48, 38, 20) else COLORS.card,
			ZIndex = 12,
		}, list)
		corner(row, 10)
		local swatch = create("Frame", {
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = drink.color,
			ZIndex = 13,
		}, row)
		corner(swatch, 15)
		create("TextLabel", {
			Position = UDim2.fromOffset(50, 5),
			Size = UDim2.new(1, -216, 0, 24),
			BackgroundTransparency = 1,
			Text = (if drink.vipOnly then "👑 " else "") .. drink.name,
			TextColor3 = if drink.vipOnly then VIP_GOLD else COLORS.text,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		}, row)
		create("TextLabel", {
			Position = UDim2.fromOffset(50, 29),
			Size = UDim2.new(1, -216, 0, 16),
			BackgroundTransparency = 1,
			Text = drink.look or "",
			TextColor3 = COLORS.sub,
			TextScaled = true,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		}, row)
		if drink.tier == 1 then
			local price = ClubConfig.coinPrice(drink, vip)
			pill(row, 10, 74, if price then ("💰 " .. price) else "무료", if price then COIN else COLORS.accent, function()
				purchase(drink, "order")
			end)
		else
			if drink.product then
				local text: string
				if drink.vipOnly then
					text = if vip then ("R$ " .. productPrice(drink.product)) else "🔒 VIP"
				elseif vip and drink.vipProduct then
					text = string.format("<s>%d</s> R$ %d", productPrice(drink.product), productPrice(drink.vipProduct))
				else
					text = "R$ " .. productPrice(drink.product)
				end
				pill(row, 10, if vip and drink.vipProduct then 96 else 74, text,
					if drink.vipOnly and not vip then VIP_GOLD else COLORS.robux, function()
						purchase(drink, "robux")
					end)
			end
			if drink.coins then
				local price = ClubConfig.coinPrice(drink, vip) or 0
				pill(row, 90, 74, (if vip then "👑" else "💰 ") .. price, COIN, function()
					purchase(drink, "coins")
				end)
			end
		end
	end
	-- (sparklers and the stage cold spark: the item seller next to the bartender)
	index += 1
	create("TextLabel", {
		Name = "VipNote",
		LayoutOrder = index,
		Size = UDim2.new(1, -6, 0, 34),
		BackgroundTransparency = 1,
		Text = if vip then "👑 VIP: 2단계 코인·3단계 Robux 20% 할인, 골목 공방 소다 구매 가능"
			else "👑 VIP 패스: 2단계 코인·3단계 Robux 20% 할인 + VIP 전용 음료",
		TextColor3 = VIP_GOLD,
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		ZIndex = 12,
	}, list)
end

local function openMenu()
	layoutMenu()
	buildMenu()
	menu.Visible = true
end
player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
	if menu.Visible then buildMenu() end
end)

--------------------------------------------------
-- Prompts: bartender, table, own-bottle "치우기"
--------------------------------------------------

-- 🎇 the item seller (user 2026-10-26): sparklers and sparkler bucket sets
-- come as items (hold one and tap a bottle / a table, TableTapController),
-- and the stage cold spark (99 R$, VIP 79, one per server every 2 minutes).
local function openItemShop()
	local vip = isVip()
	local bucketKey = if vip then "SparklerBucket_VIP" else "SparklerBucket"
	local sparkKey = if vip then "ColdSpark_VIP" else "ColdSpark"
	local cooldown = math.ceil((FashionGame:GetAttribute("ColdSparkReadyAt") or 0) - workspace:GetServerTimeNow())
	showModal("🎇 불꽃 · 아이템",
		"🎇 스파클러: 들고 테이블 위 병을 누르면 30초.\n🍾 버킷 세트: 들고 테이블을 누르면 얼음 버킷 + 캔 3개 + 불꽃 3개.\n🎆 콜드 스파크: DJ 무대 앞 10초 + 모두의 화면에 내 이름·한마디"
			.. (if cooldown > 0 then string.format(" (⏳ %d초 뒤)", cooldown) else "")
			.. (if vip then "\n👑 VIP 가격이에요." else ""),
		{
			{ name = "Close", text = "닫기", onClick = function() end },
			{ name = "Sparkler", text = "🎇 R$" .. productPrice("Sparkler1"), color = COLORS.robux, onClick = function() buyProduct("Sparkler1") end },
			{ name = "Bucket", text = "🍾 R$" .. productPrice(bucketKey), color = COLORS.accent, onClick = function() buyProduct(bucketKey) end },
			{ name = "ColdSpark", text = "🎆 R$" .. productPrice(sparkKey), color = VIP_GOLD, onClick = function()
				MessagePrompt.buy(sparkKey, "🎆 무대 콜드 스파크")
			end },
		})
	modal.Size = UDim2.fromOffset(360, 250)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BartenderPrompt" then
		closeModal()
		openMenu()
	elseif prompt.Name == "ItemShopPrompt" then
		menu.Visible = false
		openItemShop()
	end
end)

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
