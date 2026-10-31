--!strict
-- Picture order window for the cafes and the 국밥집 (user 2026-10-31, from
-- the user's cafe menu mock-up): a header band with the shop's picture and
-- name, category tabs on the left, a grid of picture cards, and on the right
-- the picked item large with its line, price, a − n + count and the buy
-- button; the player's coins bottom left. Looks: SnackMenuArt.Themes.
-- SnackController opens it for the shops in SnackMenuArt.ShopTheme and does
-- the buying (handlers), as before.
-- Drawn at 680 x 380 and scaled to the screen (UIScale), so phones get the
-- same layout smaller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local SnackConfig = require(Shared:WaitForChild("SnackConfig"))
local SnackMenuArt = require(Shared:WaitForChild("SnackMenuArt"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local W, H = 680, 380
-- (prices draw the gold ₩ coin themselves: CoinIcons' 💰 swap lands off its
-- gap inside a UIScale, so these texts never hold the 💰 mark)
local COIN_IMAGE = require(script.Parent:WaitForChild("Icons")).coin
local _ = EconomyConfig

local ShopMenuUI = {}
ShopMenuUI.__index = ShopMenuUI

export type Handlers = {
	buyCoins: (item: any) -> (boolean, string?),
	buyRobux: (item: any) -> (),
	onClose: () -> (),
}

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end
local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number)
	make("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation }, parent)
end
local function grouped(n: number): string
	local s = string.reverse((string.gsub(string.reverse(tostring(math.floor(n))), "(%d%d%d)", "%1,")))
	return if string.sub(s, 1, 1) == "," then string.sub(s, 2) else s
end

-- the price of an item: text after the coin (if any), coins?, Robux?
local function priceOf(item: any): (string, boolean, boolean, boolean)
	local product = item.product and MonetizationConfig.Products[item.product]
	if product and item.coins then
		return string.format("%d · R$ %d", item.coins, product.price), true, true, true
	elseif product then
		return string.format("R$ %d", product.price), false, true, false
	elseif item.coins then
		return tostring(item.coins), true, false, true
	end
	return "무료", true, false, false
end

-- a centred row: [gold coin] text, height h (px)
local function coinRow(parent: Instance, h: number, font: Enum.Font, color: Color3): (Frame, ImageLabel, TextLabel)
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h) }, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local icon = make("ImageLabel", { LayoutOrder = 1, Size = UDim2.fromOffset(h - 2, h - 2), BackgroundTransparency = 1, Image = COIN_IMAGE }, row)
	local text = make("TextLabel", { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), BackgroundTransparency = 1, Font = font, TextSize = h - 4, TextColor3 = color, Text = "" }, row)
	return row, icon, text
end
local function setPrice(icon: ImageLabel, text: TextLabel, item: any)
	local s, _, _, coin = priceOf(item)
	icon.Visible = coin
	text.Text = s
end

function ShopMenuUI.new(gui: ScreenGui)
	local self = setmetatable({}, ShopMenuUI) :: any
	local panel = make("Frame", {
		Name = "PictureMenu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false,
	}, gui)
	round(panel, 22)
	self.bodyGradient = make("UIGradient", { Rotation = 90 }, panel)
	self.edge = make("UIStroke", { Thickness = 3 }, panel)
	self.scale = make("UIScale", {}, panel)
	self.panel = panel

	-- header band (its bottom corners squared by a strip under it)
	local header = make("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
	round(header, 22)
	local square = make("Frame", { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, header)
	self.headerGradients = { make("UIGradient", {}, header), make("UIGradient", {}, square) }
	self.headerIcon = make("ImageLabel", {
		Position = UDim2.fromOffset(14, -18), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, ZIndex = 3,
	}, header)
	self.title = make("TextLabel", {
		Position = UDim2.fromOffset(104, 6), Size = UDim2.new(1, -170, 0, 34), BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
		TextSize = 27, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), ZIndex = 3,
	}, header)
	self.subtitle = make("TextLabel", {
		Position = UDim2.fromOffset(106, 38), Size = UDim2.new(1, -170, 0, 20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 240, 248), ZIndex = 3,
	}, header)
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 33), Size = UDim2.fromOffset(40, 40),
		Text = "X", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4,
	}, header)
	round(close, 20)
	make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)
	self.close = close
	close.MouseButton1Click:Connect(function() self:close_() end)

	-- left: tabs + coins
	self.tabHolder = make("Frame", { Position = UDim2.fromOffset(14, 80), Size = UDim2.fromOffset(124, 200), BackgroundTransparency = 1 }, panel)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, self.tabHolder)
	local coinsPill = make("Frame", {
		Position = UDim2.fromOffset(14, H - 50), Size = UDim2.fromOffset(124, 36),
		BackgroundColor3 = Color3.fromRGB(70, 50, 72), BackgroundTransparency = 0.15,
	}, panel)
	round(coinsPill, 18)
	local coinRowFrame, _, coins = coinRow(coinsPill, 22, Enum.Font.GothamBold, Color3.new(1, 1, 1))
	coinRowFrame.Position = UDim2.fromOffset(0, 7)

	-- middle: the cards
	local grid = make("ScrollingFrame", {
		Position = UDim2.fromOffset(148, 78), Size = UDim2.fromOffset(332, H - 112),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(102, 122), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }, grid)
	self.grid = grid
	self.status = make("TextLabel", {
		Position = UDim2.fromOffset(148, H - 32), Size = UDim2.fromOffset(332, 22), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextWrapped = true, Text = "",
	}, panel)

	-- right: the picked item
	local detail = make("Frame", { Position = UDim2.fromOffset(490, 78), Size = UDim2.fromOffset(176, H - 92), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25 }, panel)
	round(detail, 18)
	self.detailEdge = make("UIStroke", { Thickness = 2 }, detail)
	self.bigImage = make("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(104, 104), BackgroundTransparency = 1 }, detail)
	self.dName = make("TextLabel", { Position = UDim2.fromOffset(8, 112), Size = UDim2.new(1, -16, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 17, TextScaled = false, TextWrapped = true }, detail)
	make("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11 }, self.dName)
	self.dName.TextScaled = true
	self.dDesc = make("TextLabel", { Position = UDim2.fromOffset(10, 136), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextWrapped = true }, detail)
	local priceRow, priceIcon, priceText = coinRow(detail, 22, Enum.Font.GothamBlack, Color3.new())
	priceRow.Position = UDim2.fromOffset(0, 172)
	self.dPriceIcon, self.dPrice = priceIcon, priceText
	-- − n +
	local qty = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 198), Size = UDim2.fromOffset(132, 30), BackgroundTransparency = 1 }, detail)
	self.qty = qty
	self.minus = make("TextButton", { Size = UDim2.fromOffset(30, 30), Text = "-", Font = Enum.Font.GothamBlack, TextSize = 18 }, qty)
	self.plus = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(30, 30), Text = "+", Font = Enum.Font.GothamBlack, TextSize = 18 }, qty)
	round(self.minus, 15)
	round(self.plus, 15)
	self.count = make("TextLabel", { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 17, Text = "1" }, qty)
	-- buy buttons (two for an item sold for coins or Robux)
	self.buy = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 40), Font = Enum.Font.GothamBlack, TextSize = 16, Text = "" }, detail)
	round(self.buy, 20)
	self.buy2 = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -56), Size = UDim2.new(1, -20, 0, 34), Font = Enum.Font.GothamBold, TextSize = 14, Text = "", Visible = false }, detail)
	round(self.buy2, 17)

	self.n = 1
	self.minus.MouseButton1Click:Connect(function() self:setCount(self.n - 1) end)
	self.plus.MouseButton1Click:Connect(function() self:setCount(self.n + 1) end)
	self.buy.MouseButton1Click:Connect(function() self:press(false) end)
	self.buy2.MouseButton1Click:Connect(function() self:press(true) end)

	local player = Players.LocalPlayer
	local function refreshCoins()
		local v = player:GetAttribute("Coins")
		coins.Text = grouped(if typeof(v) == "number" then v else 0)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	refreshCoins()
	return self
end

function ShopMenuUI:isOpen(): boolean
	return self.panel.Visible
end

function ShopMenuUI:setStatus(text: string)
	self.status.Text = text
end

function ShopMenuUI:close_()
	if not self.panel.Visible then return end
	self.panel.Visible = false
	if self.handlers then self.handlers.onClose() end
end

function ShopMenuUI:hide()
	self.panel.Visible = false
end

function ShopMenuUI:setCount(n: number)
	self.n = math.clamp(n, 1, SnackConfig.MaxCarried)
	self.count.Text = tostring(self.n)
end

-- the buy button(s): robux = the second (R$) button of a coins-or-Robux item
function ShopMenuUI:press(second: boolean)
	local item = self.picked
	if not item or self.busy then return end
	local _, coinsOk, robuxOk = priceOf(item)
	if robuxOk and (second or not coinsOk) then
		self.handlers.buyRobux(item)
		return
	end
	self.busy = true
	task.spawn(function()
		for i = 1, self.n do
			local ok, message = self.handlers.buyCoins(item)
			if message then self:setStatus(message) end
			if not ok then break end
			if i < self.n then task.wait(0.3) end
		end
		self.busy = false
	end)
end

function ShopMenuUI:pick(item: any)
	self.picked = item
	local t = self.theme
	for card, it in pairs(self.cards) do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if it == item then t.pick else t.cardEdge
			stroke.Thickness = if it == item then 3 else 1.5
		end
	end
	self.bigImage.Image = SnackMenuArt.Icons[item.key] or ""
	self.dName.Text = item.name
	self.dDesc.Text = SnackMenuArt.Descriptions[item.key] or ""
	local _, coinsOk, robuxOk = priceOf(item)
	setPrice(self.dPriceIcon, self.dPrice, item)
	self:setCount(1)
	self.qty.Visible = coinsOk and not robuxOk
	local product = item.product and MonetizationConfig.Products[item.product]
	if coinsOk and robuxOk then
		-- coins or Robux: two buttons
		self.buy.Text = string.format("%d 코인으로 구매", item.coins)
		self.buy2.Text = string.format("R$ %d로 구매", product.price)
		self.buy2.Visible = true
	elseif robuxOk then
		self.buy.Text = string.format("R$ %d 구매하기", product.price)
		self.buy2.Visible = false
	else
		self.buy.Text = "🛒 구매하기"
		self.buy2.Visible = false
	end
end

function ShopMenuUI:showTab(index: number)
	local t = self.theme
	self.tabIndex = index
	for i, b in ipairs(self.tabButtons) do
		b.BackgroundColor3 = if i == index then t.pick else t.tab
		b.TextColor3 = if i == index then t.pickText else t.text
	end
	for _, c in ipairs(self.grid:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	self.cards = {}
	local kinds = t.tabs[index].kinds
	local first = nil
	for order, item in ipairs(self.shop.items) do
		if table.find(kinds, item.kind) then
			local card = make("TextButton", { LayoutOrder = order, BackgroundColor3 = t.card, Text = "", AutoButtonColor = true }, self.grid)
			round(card, 16)
			make("UIStroke", { Color = t.cardEdge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
			make("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, Image = SnackMenuArt.Icons[item.key] or "" }, card)
			local name = make("TextLabel", { Position = UDim2.fromOffset(4, 76), Size = UDim2.new(1, -8, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = t.text, Text = (string.gsub(item.name, " %(.-%)$", "")) }, card)
			make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, name)
			local priceRow, priceIcon, priceText = coinRow(card, 17, Enum.Font.GothamBlack, t.price)
			priceRow.Position = UDim2.fromOffset(0, 98)
			setPrice(priceIcon, priceText, item)
			if priceText.Text:len() > 9 then priceText.TextSize = 11 end -- (coins · R$)
			card.MouseButton1Click:Connect(function() self:pick(item) end)
			self.cards[card] = item
			first = first or item
		end
	end
	self.grid.CanvasPosition = Vector2.zero
	if first then self:pick(first) end
end

function ShopMenuUI:open(shop: any, themeKey: string, handlers: Handlers, status: string)
	local t = SnackMenuArt.Themes[themeKey]
	self.shop, self.theme, self.handlers = shop, t, handlers
	self.busy = false
	-- look
	self.bodyGradient.Color = ColorSequence.new(t.body[1], t.body[2])
	for _, g in ipairs(self.headerGradients) do g.Color = ColorSequence.new(t.header[1], t.header[2]) end
	self.edge.Color = t.edge
	self.detailEdge.Color = t.cardEdge
	self.headerIcon.Image = t.headerIcon
	self.title.Text = shop.title
	self.subtitle.Text = t.subtitle
	self.close.BackgroundColor3 = t.pick
	for _, b in ipairs({ self.minus, self.plus }) do
		b.BackgroundColor3 = t.tab
		b.TextColor3 = t.text
	end
	self.count.TextColor3 = t.text
	self.dName.TextColor3, self.dDesc.TextColor3, self.dPrice.TextColor3 = t.text, t.sub, t.price
	self.buy.BackgroundColor3, self.buy.TextColor3 = t.pick, t.pickText
	self.buy2.BackgroundColor3, self.buy2.TextColor3 = t.tab, t.text
	self.status.TextColor3 = t.sub
	self:setStatus(status)
	-- tabs that have items
	for _, c in ipairs(self.tabHolder:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	self.tabButtons = {}
	local firstTab = nil
	for i, tab in ipairs(t.tabs) do
		local has = false
		for _, item in ipairs(shop.items) do
			if table.find(tab.kinds, item.kind) then has = true break end
		end
		local b = make("TextButton", {
			LayoutOrder = i, Size = UDim2.fromOffset(124, 46), Font = Enum.Font.GothamBlack, TextSize = 17,
			Text = tab.icon .. "  " .. tab.name, Visible = has,
		}, self.tabHolder)
		round(b, 23)
		b.MouseButton1Click:Connect(function() self:showTab(i) end)
		self.tabButtons[i] = b
		if has and not firstTab then firstTab = i end
	end
	-- fit the screen (the top bar above)
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 700)
	self.scale.Scale = math.min(1.15, (vp.X - 24) / W, (vp.Y - 90) / (H + 20))
	self.panel.Visible = true
	self:showTab(firstTab or 1)
end

return ShopMenuUI
