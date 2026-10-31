--!strict
-- Order windows for the cafes and the 국밥집, in the club shop's look
-- (user 2026-10-31: "음료 주문 / 클럽 아이템 상점 틀로"): NeonShopUI's dark
-- navy window with a glowing edge, the icon in a square tile, title and
-- line, pill tabs on top, and two cards a row with the real item turning in
-- a little 3D window (FashionGame.FoodPreviews, built by SnackService), its
-- name, price and the buy button(s). A note line at the bottom says how the
-- shop works (or that a 알바생 is on duty) and what just happened.
-- SnackController opens it for the shops in SnackMenuArt.ShopTheme and does
-- the buying (handlers). One window per shop, made the first time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local SnackMenuArt = require(Shared:WaitForChild("SnackMenuArt"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local NeonShopUI = require(script.Parent:WaitForChild("NeonShopUI"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local ShopMenuUI = {}
ShopMenuUI.__index = ShopMenuUI

export type Handlers = {
	buyCoins: (item: any) -> (boolean, string?),
	buyRobux: (item: any) -> (),
	onClose: () -> (),
}

function ShopMenuUI.new(gui: ScreenGui)
	local self = setmetatable({}, ShopMenuUI) :: any
	self.gui = gui
	self.windows = {}
	return self
end

-- (user 2026-10-31, after comparing both) the cafes and the 국밥집 are bright
-- daytime places: the same frame repainted warm beige, cream cards, dark
-- brown letters, prices in deep gold; the accent edge, tabs and buttons stay
local CREAM = Color3.fromRGB(255, 255, 252)
local BROWN = Color3.fromRGB(78, 52, 40)
local SOFT = Color3.fromRGB(150, 120, 100)
local EDGE = Color3.fromRGB(226, 204, 176)
local GOLD = Color3.fromRGB(196, 132, 20)
local DARK_TEXT = Color3.fromRGB(8, 16, 34) -- (NeonShopUI's text on a picked tab / button)
local function paintLight(root: Instance)
	local g = root:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(Color3.fromRGB(252, 244, 230), Color3.fromRGB(240, 226, 204)) end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			if d.Name == "Title" or d.Name == "Name" then d.TextColor3 = BROWN
			elseif d.Name == "Subtitle" then d.TextColor3 = SOFT
			elseif d.Name == "Price" then d.TextColor3 = GOLD
			elseif d.Name == "CloseButton" then d.BackgroundColor3, d.TextColor3 = CREAM, BROWN
			elseif d.Name == "Icon" or d.Name == "Note" then d.BackgroundColor3 = CREAM
			elseif d.Name:match("^Tab%d") and d.TextColor3 ~= DARK_TEXT then d.BackgroundColor3, d.TextColor3 = CREAM, SOFT
			end
		elseif d:IsA("Frame") and d.Name:match("^Card_") then
			d.BackgroundColor3 = CREAM
			local s = d:FindFirstChildOfClass("UIStroke")
			if s then s.Color, s.Transparency = EDGE, 0 end
		elseif d:IsA("Frame") and d.Name == "Drink" then
			local gg = d:FindFirstChildOfClass("UIGradient")
			if gg then gg.Color = ColorSequence.new(Color3.fromRGB(250, 238, 224), Color3.fromRGB(238, 224, 206)) end
		end
	end
end

-- up to 420 x 460 under the top-bar buttons, shorter on a phone (as the club's)
local function layout(frame: Frame)
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 700)
	local top = TopBar.bottom() + 8
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, top)
	frame.Size = UDim2.fromOffset(math.min(420, vp.X - 24), math.clamp(vp.Y - top - 12, 220, 460))
end

function ShopMenuUI:window(shopKey: string, shop: any)
	local w = self.windows[shopKey]
	if w then return w end
	local t = SnackMenuArt.Themes[SnackMenuArt.ShopTheme[shopKey]]
	local names = {}
	for _, tab in ipairs(t.tabs) do table.insert(names, tab.icon .. " " .. tab.name) end
	w = NeonShopUI.window(self.gui, "Menu_" .. shopKey, t.accent, t.icon, shop.title, t.subtitle, names)
	w.setGrid(2, 118)
	-- the note line at the bottom (how it works / what just happened)
	local note = NeonShopUI.create("TextLabel", {
		Name = "Note", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, 30), BackgroundColor3 = Color3.fromRGB(20, 27, 56),
		TextColor3 = t.accent, TextScaled = true, Font = Enum.Font.GothamBold, ZIndex = 13, Text = "",
	}, w.frame)
	NeonShopUI.create("UICorner", { CornerRadius = UDim.new(0, 10) }, note)
	NeonShopUI.create("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, note)
	w.content.Size = UDim2.new(1, -28, 1, -164)
	w.note = note
	w.theme = t
	w.onTab(function(i) self:fill(i) end)
	-- (the tab colours are painted again on every switch: repaint after it)
	for _, tab in ipairs(w.tabs) do
		tab.MouseButton1Click:Connect(function() task.defer(paintLight, w.frame) end)
	end
	w.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		-- (its X button hides it: tell SnackController)
		if not w.frame.Visible and self.current == w and self.handlers then
			self.current = nil
			self.handlers.onClose()
		end
	end)
	self.windows[shopKey] = w
	return w
end

function ShopMenuUI:isOpen(): boolean
	return self.current ~= nil
end

function ShopMenuUI:setStatus(text: string)
	if self.current then self.current.note.Text = text end
end

function ShopMenuUI:hide()
	local w = self.current
	self.current = nil
	if w then w.frame.Visible = false end
end

-- the price line and buttons of one item
local function priceOf(item: any, accent: Color3): (string, Color3)
	local product = item.product and MonetizationConfig.Products[item.product]
	if product and item.coins then
		return string.format("💰 %d 코인 · R$ %d", item.coins, product.price), NeonShopUI.COIN
	elseif product then
		return string.format("R$ %d", product.price), accent
	elseif item.coins then
		return string.format("💰 %d 코인", item.coins), NeonShopUI.COIN
	end
	return "💰 무료", NeonShopUI.COIN
end

function ShopMenuUI:buy(item: any, robux: boolean)
	if robux then
		self.handlers.buyRobux(item)
		return
	end
	if self.busy then return end
	self.busy = true
	task.spawn(function()
		local _, message = self.handlers.buyCoins(item)
		if message then self:setStatus(message) end
		self.busy = false
	end)
end

function ShopMenuUI:fill(tabIndex: number)
	local w = self.current
	if not w then return end
	local t = w.theme
	w.clear()
	w.setGrid(2, 118)
	local previews = FashionGame:FindFirstChild("FoodPreviews")
	local kinds = t.tabs[tabIndex].kinds
	local index = 0
	for _, item in ipairs(self.shop.items) do
		if table.find(kinds, item.kind) then
			index += 1
			local price, priceColor = priceOf(item, t.accent)
			local product = item.product and MonetizationConfig.Products[item.product]
			local buttons
			if product and item.coins then
				buttons = {
					{ "💰" .. item.coins, NeonShopUI.COIN, function() self:buy(item, false) end },
					{ "R$" .. product.price, t.accent, function() self:buy(item, true) end },
				}
			elseif product then
				buttons = { { "🛒 R$" .. product.price, t.accent, function() self:buy(item, true) end } }
			else
				buttons = { { "🛒 주문", t.accent, function() self:buy(item, false) end } }
			end
			local preview = previews and previews:FindFirstChild(item.key)
			local name = (string.gsub(item.name, " %(.-%)$", ""))
			NeonShopUI.drinkCard(w.content, index, name, item.color, price, priceColor, buttons, nil,
				if preview and preview:IsA("Model") then preview else nil)
		end
	end
	w.content.CanvasPosition = Vector2.zero
	paintLight(w.frame)
end

function ShopMenuUI:open(shopKey: string, shop: any, handlers: Handlers, status: string)
	if self.current then self.current.frame.Visible = false end
	local w = self:window(shopKey, shop)
	self.shop, self.handlers, self.busy = shop, handlers, false
	self.current = w
	layout(w.frame)
	w.note.Text = status
	-- the first tab that has something
	local first = 1
	for i, tab in ipairs(w.theme.tabs) do
		local has = false
		for _, item in ipairs(shop.items) do
			if table.find(tab.kinds, item.kind) then has = true break end
		end
		w.tabs[i].Visible = has
		if has and first == 1 and i ~= 1 and not w.tabs[1].Visible then first = i end
	end
	w.setTab(first)
	w.frame.Visible = true
	self:fill(first)
end

return ShopMenuUI
