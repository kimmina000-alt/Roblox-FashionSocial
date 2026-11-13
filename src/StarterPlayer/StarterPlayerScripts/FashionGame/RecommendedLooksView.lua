--!strict
-- (D-1373 / D-1374) The catalog's ✨ 추천 browse mode: the looks of Shared/RecommendedLooks
-- as cards in the catalog's own item grid (like 인기 / 옷장; user 2026-11-13: "추천 누르면
-- 다른 인기 눌렀을 때처럼 아이템칸에 뜨게 해 주고 첨부한 사진 속 아바타 그림으로 띄워 줘").
-- A card: the look's whole-avatar picture (rbxthumb Outfit of its outfitId, the same picture
-- as on the Marketplace look page), the name, the Marketplace total, 입기 (TryOnItem
-- "WearLook": the server puts the look's outfit on, free like every try-on) and 사기
-- (TryOnItem "Owned" then "BuyMany": Roblox's one-purchase window for the items not owned).
-- CatalogController calls setup(ctx) once and render() whenever the mode is shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Looks = require(FashionGame:WaitForChild("Shared"):WaitForChild("RecommendedLooks"))

local View = {}

export type Context = {
	container: ScrollingFrame,
	TryOnItem: RemoteFunction,
	getCardScale: () -> number,
	registerScale: (UIScale) -> (),
	showToast: (string) -> (),
	setMessage: (string?) -> (),
	canChangeAvatar: () -> boolean,
	setBusy: (boolean) -> (),
	onWorn: () -> (),
}
local ctx: Context? = nil

-- the catalog item card colours (CatalogController.createItemCard; D-1379, user 2026-11-13:
-- "추천 아이템칸 배경 흰색 말고 다른 아이템들처럼 똑같이 해": the picture box was white)
local COLORS = {
	card = Color3.fromRGB(36, 36, 44),
	thumb = Color3.fromRGB(28, 28, 34),
	text = Color3.fromRGB(240, 240, 245),
	sub = Color3.fromRGB(175, 175, 190),
	wear = Color3.fromRGB(255, 110, 170),
	buy = Color3.fromRGB(62, 62, 76),
}

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in pairs(props) do (object :: any)[key] = value end
	if parent then object.Parent = parent end
	return object
end
local function corner(parent: Instance, radius: number) make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent) end

function View.setup(context: Context)
	ctx = context
end
function View.ready(): boolean
	return ctx ~= nil
end

local busy = false

local function wear(look: any, button: TextButton)
	local c = ctx :: Context
	if busy or not c.canChangeAvatar() then return end
	busy = true
	c.setBusy(true)
	button.Text = "입는 중..."
	local ok, success, result = pcall(function() return c.TryOnItem:InvokeServer("WearLook", look.key) end)
	c.setBusy(false)
	busy = false
	if button.Parent then button.Text = "입기" end
	if ok and success == true then
		c.showToast("✨ \"" .. look.name .. "\" 입었어요!")
	else
		c.showToast(if ok and typeof(result) == "string" then result else "지금은 입을 수 없어요.")
	end
	c.onWorn()
end

local function buy(look: any)
	local c = ctx :: Context
	if busy then return end
	busy = true
	local list = {}
	for _, item in ipairs(look.items) do table.insert(list, { id = item.id, itemType = item.kind }) end
	local okOwned, success, owned = pcall(function() return c.TryOnItem:InvokeServer("Owned", list) end)
	local rest = {}
	for _, entry in ipairs(list) do
		local key = entry.itemType .. ":" .. entry.id
		if not (okOwned and success and typeof(owned) == "table" and owned[key]) then table.insert(rest, entry) end
	end
	if #rest == 0 then
		busy = false
		c.showToast("이미 전부 가지고 있어요!")
		return
	end
	local ok, bought, message = pcall(function() return c.TryOnItem:InvokeServer("BuyMany", rest) end)
	busy = false
	if not (ok and bought) then c.showToast(if ok and typeof(message) == "string" then message else "구매 창을 열지 못했어요.") end
end

-- a card shell like the catalog's: a virtual content frame scaled by UIScale
local function card(index: number): Frame
	local c = ctx :: Context
	local scale = c.getCardScale()
	local shell = make("Frame", { Name = "Look_" .. index, BackgroundColor3 = COLORS.card, LayoutOrder = index }, c.container)
	corner(shell, 8)
	local content = make("Frame", { Name = "CardContent", Size = UDim2.fromScale(1 / scale, 1 / scale), BackgroundTransparency = 1 }, shell)
	c.registerScale(make("UIScale", { Scale = scale }, content))
	return content
end

function View.render()
	local c = ctx
	if not c then return end
	for _, child in ipairs(c.container:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	c.setMessage(if #Looks.list == 0 then "추천 조합이 아직 없어요." else nil)
	for index, look in ipairs(Looks.list) do
		local content = card(index)
		local thumb = make("ImageLabel", {
			Name = "Thumbnail", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -88),
			BackgroundColor3 = COLORS.thumb, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
			Image = string.format("rbxthumb://type=Outfit&id=%d&w=420&h=420", look.outfitId),
		}, content)
		corner(thumb, 6)
		make("TextLabel", {
			Name = "Name", Position = UDim2.new(0, 6, 1, -80), Size = UDim2.new(1, -12, 0, 22), BackgroundTransparency = 1,
			Text = look.name, TextColor3 = COLORS.text, TextSize = 18, Font = Enum.Font.GothamMedium,
			TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
		}, content)
		make("TextLabel", {
			Name = "Price", Position = UDim2.new(0, 6, 1, -56), Size = UDim2.new(1, -12, 0, 18), BackgroundTransparency = 1,
			Text = string.format("아이템 %d개 · R$ %d", #look.items, look.price), TextColor3 = COLORS.sub, TextSize = 14,
			Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
		}, content)
		local wearButton = make("TextButton", {
			Name = "ActionButton", Position = UDim2.new(0, 6, 1, -32), Size = UDim2.new(0.6, -9, 0, 26),
			BackgroundColor3 = COLORS.wear, Text = "입기", TextColor3 = COLORS.text, TextSize = 13, Font = Enum.Font.GothamBold,
		}, content)
		corner(wearButton, 7)
		wearButton.MouseButton1Click:Connect(function() wear(look, wearButton) end)
		local buyButton = make("TextButton", {
			Name = "BuyButton", Position = UDim2.new(0.6, 3, 1, -32), Size = UDim2.new(0.4, -9, 0, 26),
			BackgroundColor3 = COLORS.buy, Text = "사기", TextColor3 = COLORS.text, TextSize = 13, Font = Enum.Font.GothamBold,
		}, content)
		corner(buyButton, 7)
		buyButton.MouseButton1Click:Connect(function() buy(look) end)
	end
end

return View
