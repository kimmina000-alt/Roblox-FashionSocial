--!strict
-- Item details + cart (user 2026-11-03, D-799): tapping an item in 착용 중
-- opens a window with the full name, a big picture, the price, and buttons to
-- buy it (Roblox purchase prompt) or put it in the cart. The cart (this
-- session only) lists the items and buys them together (PromptBulkPurchase,
-- one item at a time if that is not available).
--
--   local detail = ItemDetail.new(showToast)
--   detail:open(item)   -- item = an item-details table (Id, ItemType "Asset"/"Bundle", Name, Price, ...)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ItemDetail = {}
ItemDetail.__index = ItemDetail

local BULK_MAX = 20 -- (Roblox: at most 20 items in one bulk purchase)

local COLORS = {
	shade = Color3.fromRGB(0, 0, 0),
	panel = Color3.fromRGB(30, 30, 38),
	image = Color3.fromRGB(22, 22, 28),
	text = Color3.fromRGB(245, 245, 245),
	sub = Color3.fromRGB(160, 160, 175),
	buy = Color3.fromRGB(0, 150, 95),
	cart = Color3.fromRGB(105, 85, 160),
	plain = Color3.fromRGB(70, 70, 85),
	off = Color3.fromRGB(55, 55, 65),
}

local function create(className: string, props: {[string]: any}): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function key(item: any): string
	return tostring(item.ItemType) .. ":" .. tostring(item.Id)
end

local function isBundle(item: any): boolean
	return item.ItemType == "Bundle"
end

local function thumb(item: any, size: number): string
	return string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d",
		if isBundle(item) then "BundleThumbnail" else "Asset", item.Id, size, size)
end

-- the price, or nil when it cannot be bought (off sale / limited without a price)
local function priceOf(item: any): number?
	local price = item.Price
	if typeof(price) == "number" and price >= 0 then
		if item.IsPurchasable == false then return nil end
		return price
	end
	return nil
end

local function priceText(item: any): string
	local price = priceOf(item)
	if price == nil then return "판매하지 않는 아이템" end
	if price == 0 then return "무료" end
	return "R$ " .. tostring(price)
end

local function typeText(item: any): string
	if isBundle(item) then return tostring(item.BundleType or "Bundle") end
	local assetType = item.AssetType
	if typeof(assetType) == "EnumItem" then return assetType.Name end
	return tostring(assetType or "")
end

local function button(parent: Instance, text: string, color: Color3, props: {[string]: any}): TextButton
	local b = create("TextButton", {
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
		Parent = parent,
	})
	for k, v in pairs(props) do (b :: any)[k] = v end
	corner(b, 8)
	return b
end

function ItemDetail.new(showToast: (string) -> ())
	local self = setmetatable({}, ItemDetail)
	self.toast = showToast
	self.cart = {} :: {any}
	self.item = nil :: any

	local gui = create("ScreenGui", {
		Name = "ItemDetailGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30, -- (over the catalog, 20/21)
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui
	local shade = create("TextButton", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.shade,
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	shade.Activated:Connect(function() self:close() end)

	-- the details window: the picture on the left, the text and buttons on the right
	local panel = create("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.84),
		BackgroundColor3 = COLORS.panel,
		Parent = gui,
	})
	corner(panel, 14)
	create("UISizeConstraint", { MaxSize = Vector2.new(620, 380), Parent = panel })
	self.panel = panel
	local image = create("ImageLabel", {
		Name = "Picture",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = COLORS.image,
		ScaleType = Enum.ScaleType.Fit,
		Parent = panel,
	})
	corner(image, 10)
	self.image = image
	local info = create("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		Parent = panel,
	})
	self.info = info
	local function placeInfo()
		local side = image.AbsoluteSize.X
		info.Position = UDim2.fromOffset(side + 24, 12)
		info.Size = UDim2.new(1, -(side + 36), 1, -24)
	end
	image:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeInfo)
	placeInfo()
	local close = button(panel, "✕", COLORS.plain, {
		Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(30, 30), ZIndex = 3,
	})
	close.Activated:Connect(function() self:close() end)
	-- full name, wrapped (the cards cut it off)
	self.nameLabel = create("TextLabel", {
		Name = "FullName",
		Size = UDim2.new(1, -36, 0.36, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = info,
	})
	create("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 11, Parent = self.nameLabel })
	self.subLabel = create("TextLabel", {
		Name = "Kind",
		Position = UDim2.fromScale(0, 0.38),
		Size = UDim2.new(1, 0, 0.12, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.sub,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	create("UITextSizeConstraint", { MaxTextSize = 14, Parent = self.subLabel })
	self.priceLabel = create("TextLabel", {
		Name = "Price",
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0.13, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	create("UITextSizeConstraint", { MaxTextSize = 20, Parent = self.priceLabel })
	self.buyButton = button(info, "구매", COLORS.buy, {
		Name = "Buy", Position = UDim2.fromScale(0, 0.66), Size = UDim2.new(0.5, -4, 0.15, 0),
	})
	self.cartButton = button(info, "🛒 담기", COLORS.cart, {
		Name = "AddToCart", Position = UDim2.new(0.5, 4, 0.66, 0), Size = UDim2.new(0.5, -4, 0.15, 0),
	})
	self.openCartButton = button(info, "장바구니 보기", COLORS.plain, {
		Name = "OpenCart", Position = UDim2.fromScale(0, 0.85), Size = UDim2.new(1, 0, 0.15, 0),
	})
	self.buyButton.Activated:Connect(function() if self.item then self:buyOne(self.item) end end)
	self.cartButton.Activated:Connect(function() if self.item then self:toggleCart(self.item) end end)
	self.openCartButton.Activated:Connect(function() self:showCart() end)

	-- the cart window
	local cartPanel = create("Frame", {
		Name = "Cart",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.84),
		BackgroundColor3 = COLORS.panel,
		Visible = false,
		Parent = gui,
	})
	corner(cartPanel, 14)
	create("UISizeConstraint", { MaxSize = Vector2.new(520, 380), Parent = cartPanel })
	self.cartPanel = cartPanel
	self.cartTitle = create("TextLabel", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -60, 0, 26),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cartPanel,
	})
	local cartClose = button(cartPanel, "✕", COLORS.plain, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(30, 30),
	})
	cartClose.Activated:Connect(function() self:close() end)
	local list = create("ScrollingFrame", {
		Name = "Items",
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 1, -98),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = cartPanel,
	})
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	self.cartList = list
	self.buyAllButton = button(cartPanel, "모두 구매", COLORS.buy, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(0.62, -14, 0, 40),
	})
	local clearButton = button(cartPanel, "비우기", COLORS.plain, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.new(0.38, -6, 0, 40),
	})
	self.buyAllButton.Activated:Connect(function() self:buyCart() end)
	clearButton.Activated:Connect(function()
		table.clear(self.cart)
		self:renderCart()
	end)

	-- bought items leave the cart
	MarketplaceService.PromptPurchaseFinished:Connect(function(who, assetId, purchased)
		if who == player and purchased then self:removeFromCart("Asset", assetId) end
	end)
	MarketplaceService.PromptBundlePurchaseFinished:Connect(function(who, bundleId, purchased)
		if who == player and purchased then self:removeFromCart("Bundle", bundleId) end
	end)
	pcall(function()
		(MarketplaceService :: any).PromptBulkPurchaseFinished:Connect(function(who, status, results)
			if who ~= player or typeof(results) ~= "table" or typeof(results.Items) ~= "table" then return end
			for _, row in ipairs(results.Items) do
				local done = typeof(row) == "table" and row.status == Enum.MarketplaceItemPurchaseStatus.Success
				if done and typeof(row.id) == "string" and tonumber(row.id) then
					local itemType = if row.type == Enum.MarketplaceProductType.AvatarBundle then "Bundle" else "Asset"
					self:removeFromCart(itemType, tonumber(row.id) :: number)
				end
			end
		end)
	end)
	return self
end

function ItemDetail:inCart(item: any): boolean
	for _, entry in ipairs(self.cart) do
		if key(entry) == key(item) then return true end
	end
	return false
end

function ItemDetail:removeFromCart(itemType: string, id: number)
	for i = #self.cart, 1, -1 do
		if self.cart[i].ItemType == itemType and self.cart[i].Id == id then table.remove(self.cart, i) end
	end
	if self.gui.Enabled then
		if self.cartPanel.Visible then self:renderCart() else self:renderDetail() end
	end
end

function ItemDetail:toggleCart(item: any)
	if self:inCart(item) then
		self:removeFromCart(item.ItemType, item.Id)
		self.toast("장바구니에서 뺐어요.")
		return
	end
	if priceOf(item) == nil then
		self.toast("판매하지 않는 아이템이에요.")
		return
	end
	table.insert(self.cart, item)
	self.toast("장바구니에 담았어요. (" .. #self.cart .. "개)")
	self:renderDetail()
end

function ItemDetail:buyOne(item: any)
	if priceOf(item) == nil then
		self.toast("판매하지 않는 아이템이에요.")
		return
	end
	local ok, err = pcall(function()
		if isBundle(item) then
			MarketplaceService:PromptBundlePurchase(player, item.Id)
		else
			MarketplaceService:PromptPurchase(player, item.Id)
		end
	end)
	if not ok then
		warn("[ItemDetail] purchase prompt failed:", err)
		self.toast("구매 창을 열지 못했어요.")
	end
end

function ItemDetail:buyCart()
	local items = {}
	for _, item in ipairs(self.cart) do
		if priceOf(item) ~= nil and #items < BULK_MAX then table.insert(items, item) end
	end
	if #items == 0 then
		self.toast("장바구니가 비어 있어요.")
		return
	end
	if #items == 1 then
		self:buyOne(items[1])
		return
	end
	local lineItems = {}
	for _, item in ipairs(items) do
		table.insert(lineItems, {
			Type = if isBundle(item) then Enum.MarketplaceProductType.AvatarBundle else Enum.MarketplaceProductType.AvatarAsset,
			Id = tostring(item.Id),
		})
	end
	local ok, err = pcall(function()
		(MarketplaceService :: any):PromptBulkPurchase(player, lineItems, {})
	end)
	if not ok then
		-- (no bulk purchase here: the first item; the rest stay in the cart)
		warn("[ItemDetail] bulk purchase failed:", err)
		self.toast("한 번에 사기를 못 해서 첫 아이템부터 열어요.")
		self:buyOne(items[1])
	end
end

function ItemDetail:renderDetail()
	local item = self.item
	if not item then return end
	self.image.Image = thumb(item, 420)
	self.nameLabel.Text = tostring(item.Name or "이름 없는 아이템")
	local creator = item.CreatorName
	self.subLabel.Text = typeText(item) .. (if typeof(creator) == "string" and creator ~= "" then " · " .. creator else "")
	self.priceLabel.Text = priceText(item)
	local forSale = priceOf(item) ~= nil
	self.buyButton.Text = if forSale then (if priceOf(item) == 0 then "무료로 받기" else "구매 " .. priceText(item)) else "구매 불가"
	self.buyButton.BackgroundColor3 = if forSale then COLORS.buy else COLORS.off
	self.buyButton.AutoButtonColor = forSale
	local inCart = self:inCart(item)
	self.cartButton.Text = if inCart then "🛒 빼기" else "🛒 담기"
	self.cartButton.BackgroundColor3 = if forSale or inCart then COLORS.cart else COLORS.off
	self.openCartButton.Text = string.format("장바구니 보기 (%d)", #self.cart)
end

function ItemDetail:renderCart()
	for _, child in ipairs(self.cartList:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local total = 0
	for index, item in ipairs(self.cart) do
		total += priceOf(item) or 0
		local row = create("Frame", {
			Size = UDim2.new(1, -8, 0, 52),
			BackgroundColor3 = COLORS.image,
			LayoutOrder = index,
			Parent = self.cartList,
		})
		corner(row, 8)
		local pic = create("ImageButton", {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(44, 44),
			BackgroundTransparency = 1,
			Image = thumb(item, 150),
			ScaleType = Enum.ScaleType.Fit,
			Parent = row,
		})
		pic.Activated:Connect(function() self:open(item) end)
		create("TextLabel", {
			Position = UDim2.fromOffset(56, 4),
			Size = UDim2.new(1, -150, 0, 26),
			BackgroundTransparency = 1,
			Text = tostring(item.Name or ""),
			TextColor3 = COLORS.text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		create("TextLabel", {
			Position = UDim2.fromOffset(56, 28),
			Size = UDim2.new(1, -150, 0, 18),
			BackgroundTransparency = 1,
			Text = priceText(item),
			TextColor3 = COLORS.sub,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local remove = button(row, "빼기", COLORS.plain, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(72, 34), TextSize = 12,
		})
		remove.Activated:Connect(function() self:removeFromCart(item.ItemType, item.Id) end)
	end
	self.cartTitle.Text = string.format("🛒 장바구니 %d개 · R$ %d", #self.cart, total)
	if #self.cart == 0 then
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Text = "담은 아이템이 없어요. 아이템을 눌러 🛒 담기를 해 보세요.",
			TextColor3 = COLORS.sub,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			Parent = self.cartList,
		})
	end
	self.buyAllButton.Text = if #self.cart > BULK_MAX then string.format("앞 %d개 구매", BULK_MAX) else "모두 구매"
end

function ItemDetail:open(item: any)
	if typeof(item) ~= "table" or typeof(item.Id) ~= "number" then return end
	self.item = item
	self.panel.Visible = true
	self.cartPanel.Visible = false
	self:renderDetail()
	self.gui.Enabled = true
end

function ItemDetail:showCart()
	self.panel.Visible = false
	self.cartPanel.Visible = true
	self:renderCart()
	self.gui.Enabled = true
end

function ItemDetail:close()
	self.gui.Enabled = false
	self.item = nil
end

function ItemDetail:isOpen(): boolean
	return self.gui.Enabled
end

return ItemDetail
