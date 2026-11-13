--!strict
-- (D-1373) The catalog's ✨ 추천 window: one card per look of Shared/RecommendedLooks
-- (the Marketplace looks the user picked). A card shows its items' pictures, the name and
-- the Marketplace total; 입어 보기 puts the whole look on (TryOnItem "WearLook", free like
-- every try-on), 🛒 사기 opens Roblox's one-purchase window for the items not owned yet
-- (TryOnItem "Owned" then "BuyMany", as the catalog cart, D-799 / D-829).
-- Its own ScreenGui above the catalog (not a Popups entry: that would close the catalog).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Looks = require(FashionGame:WaitForChild("Shared"):WaitForChild("RecommendedLooks"))
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("TryOnItem") :: RemoteFunction

local player = Players.LocalPlayer
local View = {}

local PINK = Color3.fromRGB(255, 110, 170)
local CARD = Color3.fromRGB(34, 34, 44)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number) create("UICorner", { CornerRadius = UDim.new(0, r) }, parent) end

local gui: ScreenGui? = nil
local toastLabel: TextLabel? = nil
local toastId = 0
local function toast(text: string)
	local label = toastLabel
	if not label then return end
	toastId += 1
	local id = toastId
	label.Text = text
	label.Visible = true
	task.delay(2.5, function() if toastId == id then label.Visible = false end end)
end

local busy = false
local function wear(look: any)
	if busy then return end
	busy = true
	toast("입는 중…")
	local ok, success, result = pcall(function() return remote:InvokeServer("WearLook", look.key) end)
	busy = false
	if ok and success then
		toast("✨ " .. look.name .. " 입었어요!")
	else
		toast(if ok and typeof(result) == "string" then result else "지금은 입을 수 없어요.")
	end
end

local function buy(look: any)
	if busy then return end
	busy = true
	local list = {}
	for _, item in ipairs(look.items) do table.insert(list, { id = item.id, itemType = item.kind }) end
	local okOwned, success, owned = pcall(function() return remote:InvokeServer("Owned", list) end)
	local rest = {}
	for _, entry in ipairs(list) do
		local key = entry.itemType .. ":" .. entry.id
		if not (okOwned and success and typeof(owned) == "table" and owned[key]) then table.insert(rest, entry) end
	end
	if #rest == 0 then
		busy = false
		toast("이미 전부 가지고 있어요!")
		return
	end
	local ok, bought, message = pcall(function() return remote:InvokeServer("BuyMany", rest) end)
	busy = false
	if not (ok and bought) then toast(if ok and typeof(message) == "string" then message else "구매 창을 열지 못했어요.") end
end

local function thumb(item: any): string
	if item.kind == "Bundle" then
		return string.format("rbxthumb://type=BundleThumbnail&id=%d&w=150&h=150", item.id)
	end
	return string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", item.id)
end

local function build(): ScreenGui
	local screen = create("ScreenGui", { Name = "RecommendedLooksGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 26, Enabled = false },
		player:WaitForChild("PlayerGui"))
	local dim = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false }, screen)
	dim.Activated:Connect(function() View.close() end)
	local window = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.new(1, -24, 1, -132), -- (under the top bar, above the hotbar)
		BackgroundColor3 = Color3.fromRGB(16, 16, 22),
	}, screen)
	create("UISizeConstraint", { MaxSize = Vector2.new(620, 430) }, window)
	corner(window, 18)
	create("UIStroke", { Color = PINK, Thickness = 2 }, window)
	create("TextLabel", {
		Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 30), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
		Text = "✨ 추천 조합",
	}, window)
	create("TextLabel", {
		Position = UDim2.fromOffset(18, 38), Size = UDim2.new(1, -80, 0, 18), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(190, 190, 205), TextXAlignment = Enum.TextXAlignment.Left,
		Text = "입어 보기는 무료! 한 번에 통째로 입어 봐요.",
	}, window)
	local close = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50), Text = "X", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 16,
	}, window)
	corner(close, 18)
	close.Activated:Connect(function() View.close() end)
	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, window)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(176, 226), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
	for index, look in ipairs(Looks.list) do
		local card = create("Frame", { BackgroundColor3 = CARD, LayoutOrder = index }, scroll)
		corner(card, 14)
		-- the items' pictures, 3 x 2 (body / head sets first, as listed)
		local pics = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 90), BackgroundColor3 = Color3.fromRGB(245, 240, 248) }, card)
		corner(pics, 10)
		create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -2, 0.5, -2), CellPadding = UDim2.fromOffset(2, 2) }, pics)
		for i = 1, math.min(6, #look.items) do
			create("ImageLabel", { BackgroundTransparency = 1, Image = thumb(look.items[i]), ScaleType = Enum.ScaleType.Fit }, pics)
		end
		create("TextLabel", {
			Position = UDim2.fromOffset(10, 104), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = look.name,
		}, card)
		create("TextLabel", {
			Position = UDim2.fromOffset(10, 134), Size = UDim2.new(1, -20, 0, 16), BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(180, 180, 195),
			TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("아이템 %d개 · 전부 사면 R$ %d", #look.items, look.price),
		}, card)
		local wearButton = create("TextButton", {
			Position = UDim2.fromOffset(8, 154), Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = PINK,
			Text = "입어 보기", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14,
		}, card)
		corner(wearButton, 10)
		wearButton.Activated:Connect(function() wear(look) end)
		local buyButton = create("TextButton", {
			Position = UDim2.fromOffset(8, 190), Size = UDim2.new(1, -16, 0, 28), BackgroundColor3 = Color3.fromRGB(60, 60, 74),
			Text = "한 번에 사기", -- (🛒 is a box in this font) TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13,
		}, card)
		corner(buyButton, 10)
		buyButton.Activated:Connect(function() buy(look) end)
	end
	toastLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.2, Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 5, Text = "",
	}, window)
	corner(toastLabel :: any, 12)
	return screen
end

function View.open()
	if not gui then gui = build() end
	(gui :: ScreenGui).Enabled = true
end

function View.close()
	if gui then gui.Enabled = false end
end

function View.toggle()
	if gui and gui.Enabled then View.close() else View.open() end
end

return View
