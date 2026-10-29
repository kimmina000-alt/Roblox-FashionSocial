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
	BackgroundColor3 = Color3.new(1, 1, 1), -- (the gradient gives the colour)
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
}, gui)
corner(modal, 16)
-- (the same neon edge as the shop windows, D-455)
create("UIStroke", { Color = Color3.fromRGB(40, 225, 255), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, modal)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(26, 22, 58), Color3.fromRGB(10, 14, 32)), Rotation = 90 }, modal)
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
	Wraps = true, -- (more than four buttons go on a second row)
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
	-- (more than four buttons: rows of four, user 2026-10-27's item shop)
	local perRow = math.min(#buttons, 4)
	local rows = math.ceil(#buttons / perRow)
	modalButtons.Size = UDim2.new(1, -32, 0, rows * 40 + (rows - 1) * 8)
	modalBody.Size = UDim2.new(1, -32, 1, -(70 + rows * 48))
	modal.Size = UDim2.fromOffset(360, 200 + (rows - 1) * 48)
	local width = math.floor((328 - 8 * (perRow - 1)) / perRow)
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

-- Neon windows from the user's mock-up (2026-10-28, D-455): NeonShopUI draws,
-- this script fills. The drink menu has a tab per tier and two cards a row.
local NeonShopUI = require(script.Parent:WaitForChild("NeonShopUI"))
local drinkWindow = NeonShopUI.window(gui, "DrinkMenu", NeonShopUI.CYAN, "🥤", "음료 주문",
	"원하는 음료를 골라 테이블에 놓아 보세요", { "기본 음료", "⭐ 스페셜", "💎 프리미엄" })
drinkWindow.setGrid(2, 118)
local menu = drinkWindow.frame
local list = drinkWindow.content
local drinkNote = NeonShopUI.create("TextLabel", {
	Name = "VipNote",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -28, 0, 30),
	BackgroundColor3 = Color3.fromRGB(20, 27, 56),
	TextColor3 = NeonShopUI.MAGENTA,
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	ZIndex = 13,
}, menu)
corner(drinkNote, 10)
NeonShopUI.create("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, drinkNote)
list.Size = UDim2.new(1, -28, 1, -164)
local itemWindow = NeonShopUI.window(gui, "ItemShop", NeonShopUI.MAGENTA, "🛍️", "클럽 아이템 상점",
	"테이블 연출 · 무대 효과 · 이용권", { "✨ 불꽃 아이템", "🎫 VIP · DJ 패스권" })
itemWindow.setGrid(1, 0)
-- Up to 420 x 460, below the top-bar buttons; on a phone in landscape it
-- keeps its width and gets shorter (the list scrolls) (2P phone test 2026-10-25)
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local function layoutWindow(frame: Frame)
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 700)
	local top = TopBar.bottom() + 8
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, top)
	frame.Size = UDim2.fromOffset(math.min(420, vp.X - 24), math.clamp(vp.Y - top - 12, 220, 460))
end
local function layoutMenu() layoutWindow(menu) end

local MessagePrompt = require(script.Parent:WaitForChild("MessagePrompt"))
local COIN = Color3.fromRGB(230, 170, 40)

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

local function handsFull(): boolean
	if carried("Bottle") >= ClubConfig.MaxBottlesCarried then
		toast(string.format("병은 %d개까지 들 수 있어요. 테이블에 먼저 놓아 주세요.", ClubConfig.MaxBottlesCarried))
		return true
	end
	return false
end

-- (each flavour is its own card since 2026-10-28 (3), so the variant comes
-- with the purchase; the old flavour window is only a fallback)
local function withVariant(drink: any, chosen: string?, after: (variantKey: string?) -> ())
	if not drink.variants or chosen then
		after(chosen)
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
local function purchase(drink: any, method: string, chosen: string?)
	if handsFull() then return end
	menu.Visible = false
	if drink.vipOnly and not isVip() then
		toast("VIP 전용 음료예요. VIP 패스로 열 수 있어요.")
		buyPass("VIP")
		return
	end
	withVariant(drink, chosen, function(variantKey)
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

-- One price, the player's own (user 2026-10-28 (3): no separate VIP button):
-- everyone sees the normal price; a VIP sees it struck through and the 20%
-- off price next to it. 골목 공방 소다 (VIP only) always shows the normal price
-- struck through.
local function strike(before: number, after: number, unit: string): string
	return string.format("<s>%s%d</s> %s%d", unit, before, unit, after)
end
local function robuxText(drink: any, vip: boolean): string
	if drink.vipOnly then
		local now = productPrice(drink.product)
		return strike(math.floor(now / ClubConfig.VipCoinRate + 0.5), now, "R$")
	elseif vip and drink.vipProduct then
		return strike(productPrice(drink.product), productPrice(drink.vipProduct), "R$")
	end
	return "R$" .. productPrice(drink.product)
end
local function coinText(drink: any, vip: boolean): string
	local now = ClubConfig.coinPrice(drink, vip) or 0
	if vip and drink.coins and now ~= drink.coins then return strike(drink.coins, now, "💰") end
	return "💰" .. now
end

local drinkTab = 1
local function buildMenu()
	drinkWindow.clear()
	drinkWindow.setGrid(2, 118)
	local vip = isVip()
	local index = 0
	for _, drink in ipairs(ClubConfig.Drinks) do
		if drink.tier ~= drinkTab then continue end
		-- flavours listed one by one ("쨍팝 라임맛")
		local flavours: {any} = drink.variants or { false }
		for _, variant in ipairs(flavours) do
			index += 1
			local chosen = if variant then variant.key else nil
			local color = if variant then variant.color else drink.color
			local name = (if drink.vipOnly then "👑 " else "") .. drink.name .. (if variant then " " .. variant.name .. "맛" else "")
			-- the real bottle (server-built, FashionGame.DrinkPreviews, user 2026-10-28 (24))
			local previews = FashionGame:FindFirstChild("DrinkPreviews")
			local preview = previews and previews:FindFirstChild(if variant then drink.key .. "_" .. variant.key else drink.key)
			if drink.tier == 1 then
				local price = ClubConfig.coinPrice(drink, vip)
				NeonShopUI.drinkCard(list, index, name, color,
					if price then ("💰 " .. price .. " 코인") else "💰 무료", NeonShopUI.COIN,
					{ { "🛒 주문", NeonShopUI.CYAN, function() purchase(drink, "order", chosen) end } }, nil, preview)
			else
				local buttons = {}
				local parts = {}
				if drink.coins then
					table.insert(parts, coinText(drink, vip))
					-- (the struck-through price is on the line above; the button shows what is paid)
					table.insert(buttons, { "💰" .. (ClubConfig.coinPrice(drink, vip) or 0), NeonShopUI.COIN, function() purchase(drink, "coins", chosen) end })
				end
				if drink.product then
					local paid = if drink.vipOnly or not (vip and drink.vipProduct) then drink.product else drink.vipProduct
					local text = if drink.vipOnly and not vip then "🔒 VIP" else "R$" .. productPrice(paid)
					table.insert(parts, robuxText(drink, vip))
					table.insert(buttons, { text, if drink.vipOnly and not vip then NeonShopUI.GOLD else NeonShopUI.CYAN, function() purchase(drink, "robux", chosen) end })
				end
				NeonShopUI.drinkCard(list, index, name, color, table.concat(parts, " · "), if drink.vipOnly then NeonShopUI.GOLD else NeonShopUI.CYAN, buttons, drink.vipOnly, preview)
			end
		end
	end
	drinkNote.Text = if vip then "👑 VIP 할인가로 보여요 · 2단계 코인·3단계 Robux 20% 할인"
		else "✦ 👑 VIP는 2·3단계 음료 20% 할인 + VIP 전용 음료 ✦"
end
drinkWindow.onTab(function(i)
	drinkTab = i
	buildMenu()
end)

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
-- (neon item shop from the user's mock-up 2026-10-28, D-455: tabs 불꽃 아이템 /
-- VIP / DJ, picture cards with 구매하기, pass rows at the bottom)
local itemTab = 1
local function buildItemShop()
	itemWindow.clear()
	itemWindow.setGrid(1, 0)
	local vip = isVip()
	local list2 = itemWindow.content
	local M, C = NeonShopUI.MAGENTA, NeonShopUI.CYAN
	local function rs(key: string): string return "R$" .. productPrice(key) end
	local order = 0
	local function nextOrder() order += 1 return order end
	local function passRows()
		NeonShopUI.wideRow(list2, nextOrder(), "🎧", string.format("DJ %d분 이용권", MonetizationConfig.DJMinutes),
			string.format("클럽 DJ 부스를 %d분 동안 쓸 수 있어요.", MonetizationConfig.DJMinutes), "R$" .. productPrice("DJ"), C, function() buyProduct("DJ") end)
		local pass = MonetizationConfig.GamePasses.VIP
		NeonShopUI.wideRow(list2, nextOrder(), "👑", "VIP 패스", "클럽 2층 VIP 라운지에 언제든 들어갈 수 있어요.",
			if vip then "보유 중" else ("R$" .. pass.price), M, function()
				if not vip then buyPass("VIP") end
			end)
	end
	if itemTab == 1 then
		local bucketKey = if vip then "SparklerBucket_VIP" else "SparklerBucket"
		local sparkKey = if vip then "ColdSpark_VIP" else "ColdSpark"
		local cooldown = math.ceil((FashionGame:GetAttribute("ColdSparkReadyAt") or 0) - workspace:GetServerTimeNow())
		-- the real items in the pictures (user 2026-10-30, SparkleService buildItemPreviews)
		local previews = FashionGame:FindFirstChild("ItemPreviews")
		local function look(name: string): Model?
			local m = previews and previews:FindFirstChild(name)
			return if m and m:IsA("Model") then m else nil
		end
		NeonShopUI.itemCard(list2, nextOrder(), "🎇", Color3.fromRGB(120, 60, 200), "테이블 스파클러",
			"들고 테이블 위 병(버킷)을 누르면 30초 연출", rs("Sparkler1"), nil, "🛒 구매하기", C, function() buyProduct("Sparkler1") end, look("Sparkler1"))
		NeonShopUI.itemCard(list2, nextOrder(), "🎇", Color3.fromRGB(150, 50, 190), "스파클러 ×5",
			"한 버킷에 5개까지 꽂아요", rs("Sparkler5"), nil, "🛒 구매하기", C, function() buyProduct("Sparkler5") end, look("Sparkler1")) -- (the same picture as one, user 2026-10-30)
		NeonShopUI.itemCard(list2, nextOrder(), "🍾", Color3.fromRGB(40, 120, 200), "스파클러 버킷 세트",
			"얼음 버킷 + 음료 3개 + 스파클러 3개", rs("SparklerBucket"), if vip then nil else rs("SparklerBucket_VIP"), "🛒 구매하기", C, function() buyProduct(bucketKey) end, look("SparklerBucket"))
		NeonShopUI.itemCard(list2, nextOrder(), "✨", Color3.fromRGB(200, 140, 40), "손 스파클러",
			"손에 들고 60초 동안 춤춰요", rs("HandSparkler"), nil, "🛒 구매하기", C, function() buyProduct("HandSparkler") end, look("HandSparkler"))
		local hasGlow = player:GetAttribute("Pass_Glowstick") == true
		NeonShopUI.itemCard(list2, nextOrder(), "🌟", Color3.fromRGB(40, 170, 120), "야광봉",
			"영구 아이템 · 누르면 색이 바뀌어요", if hasGlow then "보유 중" else ("R$" .. MonetizationConfig.GamePasses.Glowstick.price), nil,
			if hasGlow then "✓ 보유" else "🛒 구매하기", C, function()
				if not hasGlow then buyPass("Glowstick") end
			end, look("Glowstick"))
		NeonShopUI.itemCard(list2, nextOrder(), "🎆", Color3.fromRGB(30, 90, 190), "무대 콜드 스파크",
			"무대 불꽃 30초 + 이름·한마디 배너·건물 전광판" .. (if cooldown > 0 then string.format(" · ⏳ %d초 뒤", cooldown) else ""),
			rs("ColdSpark"), if vip then nil else rs("ColdSpark_VIP"), "🛒 구매하기", C, function()
				MessagePrompt.buy(sparkKey, "🎆 무대 콜드 스파크")
			end)
	else
		-- (VIP and DJ in one tab, two rows: user 2026-10-28 (3))
		NeonShopUI.note(list2, nextOrder(), "👑 VIP: 2층 VIP 라운지 · 음료 20% 할인 · VIP 전용 음료 · 버킷/콜드 스파크 VIP가", NeonShopUI.GOLD)
		passRows()
	end
end
itemWindow.onTab(function(i)
	itemTab = i
	buildItemShop()
end)
local function openItemShop()
	layoutWindow(itemWindow.frame)
	buildItemShop()
	itemWindow.frame.Visible = true
end

-- 공개 범위 (모든 사람 / 친구만 / 나만) before a bottle goes on a table
-- (user 2026-10-26: kept with the touch tables; TableTapController asks)
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
	showModal("누가 마실 수 있게 할까요?", "고른 사람들이 테이블 위 병(버킷)을 눌러 마실 수 있어요.", buttons, true)
end
local visibilityAsk = Instance.new("BindableEvent")
visibilityAsk.Name = "ClubChooseVisibility"
visibilityAsk.Event:Connect(function(tablePart: any)
	if typeof(tablePart) == "Instance" then chooseVisibility(tablePart) end
end)
visibilityAsk.Parent = script.Parent

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BartenderPrompt" then
		closeModal()
		itemWindow.frame.Visible = false
		openMenu()
	elseif prompt.Name == "ItemShopPrompt" then
		closeModal()
		menu.Visible = false
		openItemShop()
	end
end)

-- Close the menu when walking away from the bartender.
task.spawn(function()
	while true do
		task.wait(0.5)
		if menu.Visible or itemWindow.frame.Visible then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local nearest = math.huge
			for _, spot in ipairs(game:GetService("CollectionService"):GetTagged("BartenderSpot")) do
				if spot:IsA("BasePart") and root then
					nearest = math.min(nearest, (spot.Position - root.Position).Magnitude)
				end
			end
			if nearest > 22 then
				menu.Visible = false
				itemWindow.frame.Visible = false
			end
		end
	end
end)

-- Small pop when a toast appears.
toastLabel:GetPropertyChangedSignal("Text"):Connect(function()
	toastLabel.Size = UDim2.fromOffset(440, 40)
	TweenService:Create(toastLabel, TweenInfo.new(0.15), { Size = UDim2.fromOffset(460, 44) }):Play()
end)
