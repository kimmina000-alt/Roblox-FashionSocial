--!strict
-- Neon club shop windows (user mock-up 2026-10-28, D-455): "클럽 아이템 상점"
-- (magenta) and "음료 주문" (cyan). Dark navy glass panel with a glowing edge,
-- an icon + title + subtitle head, pill tabs, and cards:
--   * drinkCard: a drawn drink (glass, liquid in the drink's colour, straw) +
--     name + price + 주문 button, two per row
--   * itemCard: a picture tile (big emoji on a glowing gradient) + name +
--     one line + R$ price (+ VIP price chip) + 구매하기 button
--   * wideRow: a slim row for passes (DJ, VIP) with a price and an arrow
-- ClubShopController fills them; this module only draws.

local NeonShopUI = {}

local NAVY = Color3.fromRGB(10, 14, 32)
local CARD = Color3.fromRGB(20, 27, 56)
local TEXT = Color3.fromRGB(255, 255, 255)
local SUB = Color3.fromRGB(170, 182, 214)
NeonShopUI.CYAN = Color3.fromRGB(40, 225, 255)
NeonShopUI.MAGENTA = Color3.fromRGB(255, 70, 210)
NeonShopUI.GOLD = Color3.fromRGB(255, 200, 70)
NeonShopUI.COIN = Color3.fromRGB(255, 196, 60)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then instance.Parent = parent end
	return instance
end
NeonShopUI.create = create

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent: Instance, props: {[string]: any}): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		ZIndex = 13,
	}
	for k, v in pairs(props) do base[k] = v end
	return create("TextLabel", base, parent)
end

local function button(parent: Instance, text: string, color: Color3, props: {[string]: any}): TextButton
	local base = {
		BackgroundColor3 = Color3.new(1, 1, 1), -- (the gradient gives the colour)
		Text = text,
		RichText = true,
		TextColor3 = Color3.fromRGB(8, 16, 34),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
		ZIndex = 14,
	}
	for k, v in pairs(props) do base[k] = v end
	local b = create("TextButton", base, parent)
	corner(b, 10)
	create("UITextSizeConstraint", { MaxTextSize = 16 }, b)
	create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
	create("UIGradient", {
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color),
		Rotation = 90,
	}, b)
	return b
end
NeonShopUI.button = button

export type Window = {
	frame: Frame,
	content: ScrollingFrame,
	tabs: {TextButton},
	setTab: (index: number) -> (),
	onTab: (callback: (index: number) -> ()) -> (),
	clear: () -> (),
	setGrid: (columns: number, cellHeight: number) -> (),
}

-- A window: accent colour, icon (emoji), title, subtitle, tab names.
function NeonShopUI.window(gui: Instance, name: string, accent: Color3, icon: string, title: string, subtitle: string, tabNames: {string}): Window
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromOffset(420, 460),
		BackgroundColor3 = Color3.new(1, 1, 1), -- (the gradient gives the colour)
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 10,
	}, gui)
	corner(frame, 18)
	stroke(frame, accent, 2.5)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(26, 22, 58), NAVY),
		Rotation = 90,
	}, frame)
	-- head
	local iconTile = create("TextLabel", {
		Name = "Icon",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = CARD,
		Text = icon,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = accent,
		ZIndex = 12,
	}, frame)
	corner(iconTile, 12)
	stroke(iconTile, accent, 1.5, 0.3)
	create("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, iconTile)
	label(frame, { Name = "Title", Position = UDim2.fromOffset(70, 12), Size = UDim2.new(1, -130, 0, 28), Text = title })
	label(frame, { Name = "Subtitle", Position = UDim2.fromOffset(70, 40), Size = UDim2.new(1, -130, 0, 16), Text = subtitle, TextColor3 = SUB, Font = Enum.Font.GothamMedium })
	local close = create("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 16),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = CARD,
		Text = "X",
		TextColor3 = TEXT,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		ZIndex = 13,
	}, frame)
	corner(close, 17)
	stroke(close, SUB, 1, 0.6)
	close.MouseButton1Click:Connect(function() frame.Visible = false end)
	-- tabs
	local bar = create("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(14, 70),
		Size = UDim2.new(1, -28, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, frame)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	local tabs: {TextButton} = {}
	local listeners: {(number) -> ()} = {}
	local current = 1
	local function paint()
		for i, t in ipairs(tabs) do
			local on = i == current
			t.BackgroundColor3 = if on then accent else CARD
			t.TextColor3 = if on then Color3.fromRGB(8, 16, 34) else SUB
			local s = t:FindFirstChildOfClass("UIStroke")
			if s then s.Transparency = if on then 0 else 0.7 end
		end
	end
	for i, tabName in ipairs(tabNames) do
		local t = create("TextButton", {
			Name = "Tab" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1 / #tabNames, -6 * (#tabNames - 1) / #tabNames, 1, 0),
			Text = tabName,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			ZIndex = 13,
		}, bar)
		corner(t, 18)
		stroke(t, accent, 1.2)
		create("UITextSizeConstraint", { MaxTextSize = 15 }, t)
		create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, t)
		t.MouseButton1Click:Connect(function()
			current = i
			paint()
			for _, f in ipairs(listeners) do f(i) end
		end)
		table.insert(tabs, t)
	end
	paint()
	local content = create("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(14, 116),
		Size = UDim2.new(1, -28, 1, -128),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 12,
	}, frame)
	local window: Window
	window = {
		frame = frame,
		content = content,
		tabs = tabs,
		setTab = function(i: number)
			current = i
			paint()
		end,
		onTab = function(f) table.insert(listeners, f) end,
		clear = function()
			for _, c in ipairs(content:GetChildren()) do
				if not c:IsA("UIPadding") then c:Destroy() end
			end
		end,
		setGrid = function(columns: number, cellHeight: number)
			if columns > 1 then
				create("UIGridLayout", {
					CellSize = UDim2.new(1 / columns, -6, 0, cellHeight),
					CellPadding = UDim2.fromOffset(8, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, content)
			else
				create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
			end
		end,
	}
	return window
end

-- A drawn drink: a glass with the drink inside and a straw.
local function drinkIcon(parent: Instance, color: Color3, position: UDim2, size: UDim2)
	local holder = create("Frame", { Name = "Drink", Position = position, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, parent)
	corner(holder, 12)
	create("UIGradient", { Color = ColorSequence.new(color:Lerp(NAVY, 0.55), Color3.fromRGB(14, 20, 44)), Rotation = 90 }, holder)
	local glass = create("Frame", {
		Name = "Glass",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.42, 0.66),
		BackgroundColor3 = Color3.fromRGB(220, 240, 255),
		BackgroundTransparency = 0.72,
		ZIndex = 15,
	}, holder)
	corner(glass, 6)
	stroke(glass, Color3.fromRGB(230, 245, 255), 1.2, 0.35)
	local liquid = create("Frame", {
		Name = "Liquid",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.78),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 14,
	}, glass)
	corner(liquid, 6)
	create("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color), Rotation = 90 }, liquid)
	-- shine and ice
	create("Frame", { Name = "Shine", Position = UDim2.fromScale(0.12, 0.08), Size = UDim2.fromScale(0.12, 0.8), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 16 }, glass)
	for i, at in ipairs({ { 0.3, 0.22 }, { 0.58, 0.3 } }) do
		local ice = create("Frame", { Name = "Ice" .. i, Position = UDim2.fromScale(at[1], at[2]), Size = UDim2.fromScale(0.22, 0.14), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, Rotation = 15 * i, ZIndex = 16 }, glass)
		corner(ice, 3)
	end
	create("Frame", {
		Name = "Straw",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.6, 0.55),
		Size = UDim2.fromScale(0.05, 0.5),
		Rotation = 14,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 13,
	}, holder)
	return holder
end

-- One drink card (grid cell). buttons: {{text, color, onClick}}
-- The real bottle in a little 3D window (user 2026-10-28 (24)): `preview` is
-- a model the server built with the drink's own bottle (FashionGame.DrinkPreviews).
local function bottleView(parent: Instance, preview: Model, color: Color3, position: UDim2, size: UDim2)
	local holder = create("Frame", { Name = "Drink", Position = position, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, parent)
	corner(holder, 12)
	create("UIGradient", { Color = ColorSequence.new(color:Lerp(NAVY, 0.55), Color3.fromRGB(14, 20, 44)), Rotation = 90 }, holder)
	local vp = create("ViewportFrame", {
		Name = "Bottle",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -0.6, -1),
		ZIndex = 14,
	}, holder)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local m = preview:Clone()
	m.Parent = world
	local cf, sz = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	-- (fit the taller of the height and the width: the window is narrow, cans are wide)
	local dist = math.max(sz.Y, math.max(sz.X, sz.Z) * 1.5) / 2 / math.tan(math.rad(15)) * 1.15
	-- (bottles face -Z: the camera in front of the printed side)
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, sz.Y * 0.05, -dist), cf.Position)
	-- foods (user 2026-10-31): attribute PreviewAngle looks down on flat things
	-- (cakes, plates, bowls) from that many degrees
	local angle = preview:GetAttribute("PreviewAngle")
	if typeof(angle) == "number" then
		local a = math.rad(angle)
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, math.sin(a), -math.cos(a)) * dist, cf.Position)
	end
	cam.Parent = vp
	vp.CurrentCamera = cam
	return holder
end

function NeonShopUI.drinkCard(parent: Instance, order: number, name: string, color: Color3, priceText: string, priceColor: Color3, buttons: {{any}}, gold: boolean?, preview: Model?)
	local card = create("Frame", { Name = "Card_" .. order, LayoutOrder = order, BackgroundColor3 = CARD, ZIndex = 12 }, parent)
	corner(card, 14)
	if gold then
		-- VIP drinks (user 2026-10-28 (25)): a thick glowing edge in the flavour's
		-- own colour, running from bright to gold and back, slowly turning
		local edge = stroke(card, Color3.new(1, 1, 1), 3, 0)
		local bright = color:Lerp(Color3.new(1, 1, 1), 0.35)
		local grad = create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, bright),
				ColorSequenceKeypoint.new(0.35, NeonShopUI.GOLD),
				ColorSequenceKeypoint.new(0.65, color),
				ColorSequenceKeypoint.new(1, bright),
			}),
		}, edge)
		task.spawn(function()
			while card.Parent do
				grad.Rotation = (grad.Rotation + 3) % 360
				task.wait(0.03)
			end
		end)
	else
		stroke(card, Color3.fromRGB(70, 90, 150), 1.2, 0.4)
	end
	if preview then
		bottleView(card, preview, color, UDim2.fromOffset(8, 8), UDim2.new(0.42, -8, 1, -16))
	else
		drinkIcon(card, color, UDim2.fromOffset(8, 8), UDim2.new(0.42, -8, 1, -16))
	end
	label(card, { Name = "Name", Position = UDim2.new(0.42, 6, 0, 10), Size = UDim2.new(0.58, -14, 0, 20), Text = name, TextColor3 = if gold then NeonShopUI.GOLD else TEXT })
	label(card, { Name = "Price", Position = UDim2.new(0.42, 6, 0, 34), Size = UDim2.new(0.58, -14, 0, 16), Text = priceText, TextColor3 = priceColor, Font = Enum.Font.GothamMedium, RichText = true })
	local row = create("Frame", { Name = "Buttons", Position = UDim2.new(0.42, 6, 1, -42), Size = UDim2.new(0.58, -14, 0, 34), BackgroundTransparency = 1, ZIndex = 13 }, card)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	for i, spec in ipairs(buttons) do
		local b = button(row, spec[1], spec[2], { LayoutOrder = i, Size = UDim2.new(1 / #buttons, -4 * (#buttons - 1) / #buttons, 1, 0) })
		b.MouseButton1Click:Connect(spec[3])
	end
	return card
end

-- One item card (list): picture tile, name, one line, prices, 구매하기.
-- `preview` (user 2026-10-30): the real item (FashionGame.ItemPreviews) in a
-- 3D window instead of the emoji.
function NeonShopUI.itemCard(parent: Instance, order: number, emoji: string, tint: Color3, name: string, line: string, price: string, vipPrice: string?, buttonText: string, accent: Color3, onClick: () -> (), preview: Model?)
	local card = create("Frame", { Name = "Item_" .. order, LayoutOrder = order, Size = UDim2.new(1, -4, 0, 104), BackgroundColor3 = CARD, ZIndex = 12 }, parent)
	corner(card, 14)
	stroke(card, Color3.fromRGB(70, 90, 150), 1.2, 0.4)
	local tile = create("TextLabel", {
		Name = "Picture",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		ZIndex = 13,
	}, card)
	corner(tile, 12)
	stroke(tile, tint:Lerp(Color3.new(1, 1, 1), 0.3), 1.2, 0.2)
	create("UIGradient", { Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.25), tint:Lerp(NAVY, 0.6)), Rotation = 90 }, tile)
	create("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16) }, tile)
	if preview then
		tile.Text = ""
		local vp = create("ViewportFrame", {
			Name = "Item",
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(88, 88),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(190, 190, 205),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-0.4, -0.6, -1),
			ZIndex = 14,
		}, card)
		local world = Instance.new("WorldModel")
		world.Parent = vp
		local m = preview:Clone()
		m.Parent = world
		local cf, sz = m:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dist = math.max(sz.X, sz.Y, sz.Z) / 2 / math.tan(math.rad(15)) * 1.2
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.25, dist * 0.2, -dist), cf.Position)
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
	label(card, { Name = "Name", Position = UDim2.fromOffset(106, 10), Size = UDim2.new(1, -230, 0, 22), Text = name })
	label(card, { Name = "Line", Position = UDim2.fromOffset(106, 36), Size = UDim2.new(1, -230, 0, 30), Text = line, TextColor3 = SUB, Font = Enum.Font.GothamMedium, TextWrapped = true })
	label(card, { Name = "Price", Position = UDim2.fromOffset(106, 72), Size = UDim2.fromOffset(76, 22), Text = price, TextColor3 = accent })
	if vipPrice then
		local chip = create("TextLabel", {
			Name = "VipPrice",
			Position = UDim2.fromOffset(186, 72),
			Size = UDim2.fromOffset(86, 22),
			BackgroundColor3 = Color3.fromRGB(46, 20, 60),
			Text = "👑 VIP " .. vipPrice,
			TextColor3 = NeonShopUI.MAGENTA,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			ZIndex = 13,
		}, card)
		corner(chip, 11)
		stroke(chip, NeonShopUI.MAGENTA, 1, 0.3)
		create("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, chip)
	end
	local b = button(card, buttonText, accent, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(106, 40) })
	b.MouseButton1Click:Connect(onClick)
	return card
end

-- A slim pass row: icon, name, line, price, arrow.
function NeonShopUI.wideRow(parent: Instance, order: number, emoji: string, name: string, line: string, price: string, accent: Color3, onClick: () -> ())
	local row = create("TextButton", { Name = "Row_" .. order, LayoutOrder = order, Size = UDim2.new(1, -4, 0, 58), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = true, ZIndex = 12 }, parent)
	corner(row, 12)
	stroke(row, accent, 1.5, 0.15)
	create("UIGradient", { Color = ColorSequence.new(accent:Lerp(NAVY, 0.75), CARD), Rotation = 0 }, row)
	label(row, { Name = "Icon", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(38, 38), Text = emoji, TextXAlignment = Enum.TextXAlignment.Center })
	label(row, { Name = "Name", Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -170, 0, 20), Text = name })
	label(row, { Name = "Line", Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -170, 0, 15), Text = line, TextColor3 = SUB, Font = Enum.Font.GothamMedium })
	label(row, { Name = "Price", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0), Size = UDim2.fromOffset(84, 22), Text = price, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Right })
	label(row, { Name = "Arrow", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(16, 22), Text = "›", TextColor3 = SUB })
	row.MouseButton1Click:Connect(onClick)
	return row
end

-- A note line at the bottom of a list.
function NeonShopUI.note(parent: Instance, order: number, text: string, color: Color3)
	local n = create("TextLabel", {
		Name = "Note",
		LayoutOrder = order,
		Size = UDim2.new(1, -4, 0, 40),
		BackgroundColor3 = CARD,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		ZIndex = 12,
	}, parent)
	corner(n, 12)
	stroke(n, color, 1, 0.4)
	create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, n)
	return n
end

return NeonShopUI
