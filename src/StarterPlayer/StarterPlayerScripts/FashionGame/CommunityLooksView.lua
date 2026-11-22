--!strict
-- (D-COMMUNITY, user 2026-11-22: "오후 카탈로그에 사람들이 캐릭터 꾸며서 올릴 수 있는 카테고리 추가하자")
-- The catalog's 코디 browse mode ("Community"): the looks players posted (CommunityLooksService),
-- as cards in the catalog's item grid like 추천. The first cell is the control card: [최신] [인기]
-- ([숨김] for the owner) and 📤 내 코디 올리기 (the look worn now, with a title filtered by Roblox).
-- A card: the look's rig (built by the server, sent to this player's PlayerGui.CommunityRigs) in a
-- ViewportFrame, the title, by <nickname>, 👍 (one per player, tap again to take it back), the
-- price of its items, 입기 (TryOnItem "WearPost", free like every try-on) and 사기 (Owned →
-- BuyMany, Roblox's one purchase window), 🚩 신고 (others' posts; 3 players hide it) or 🗑 (own
-- posts; every post for the owner). 🚩 / 🗑 ask once more before they act.
-- CatalogController calls setup(ctx) once and render() whenever the mode is shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remote = FashionGame:WaitForChild("Remotes"):WaitForChild("CommunityLooks") :: RemoteFunction

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
	collectWorn: () -> {any},
	isShown: () -> boolean,
}
local ctx: Context? = nil

local COLORS = {
	card = Color3.fromRGB(36, 36, 44),
	thumb = Color3.fromRGB(28, 28, 34),
	text = Color3.fromRGB(240, 240, 245),
	sub = Color3.fromRGB(175, 175, 190),
	wear = Color3.fromRGB(255, 110, 170),
	buy = Color3.fromRGB(62, 62, 76),
	on = Color3.fromRGB(78, 78, 94),
	off = Color3.fromRGB(28, 28, 34),
	liked = Color3.fromRGB(255, 205, 110),
	warn = Color3.fromRGB(220, 70, 80),
}

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in pairs(props) do (object :: any)[key] = value end
	if parent then object.Parent = parent end
	return object
end
local function corner(parent: Instance, radius: number) make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent) end
local function button(parent: Instance, props: {[string]: any}): TextButton
	local b = make("TextButton", {
		BackgroundColor3 = COLORS.buy, TextColor3 = COLORS.text, TextSize = 13, Font = Enum.Font.GothamBold, AutoButtonColor = true,
	}, parent)
	for key, value in pairs(props) do (b :: any)[key] = value end
	corner(b, 7)
	return b
end

function View.setup(context: Context)
	ctx = context
end

local sort = "New"
local page = 1
local generation = 0
local busy = false
local isOwner = false

-- "a question first" buttons (🚩 / 🗑): the first tap asks, the second acts
local function confirmTap(b: TextButton, ask: string, act: () -> ())
	local normal = b.Text
	local armed = false
	b.MouseButton1Click:Connect(function()
		if armed then
			armed = false
			b.Text = normal
			b.BackgroundColor3 = COLORS.buy
			act()
			return
		end
		armed = true
		b.Text = ask
		b.BackgroundColor3 = COLORS.warn
		task.delay(3, function()
			if armed and b.Parent then
				armed = false
				b.Text = normal
				b.BackgroundColor3 = COLORS.buy
			end
		end)
	end)
end

local function shell(index: number, name: string): Frame
	local c = ctx :: Context
	local scale = c.getCardScale()
	local s = make("Frame", { Name = name, BackgroundColor3 = COLORS.card, LayoutOrder = index }, c.container)
	corner(s, 8)
	local content = make("Frame", { Name = "CardContent", Size = UDim2.fromScale(1 / scale, 1 / scale), BackgroundTransparency = 1 }, s)
	c.registerScale(make("UIScale", { Scale = scale }, content))
	return content
end

local function showRig(vp: ViewportFrame, key: string)
	task.spawn(function()
		local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local folder = gui:WaitForChild("CommunityRigs", 20)
		local rig = folder and folder:WaitForChild(key, 25)
		if not rig or not vp.Parent then return end
		local copy = (rig :: Model):Clone()
		rig:Destroy() -- (only here: the server's copy for this player, no longer needed)
		copy.Parent = vp
		local cf, size = copy:GetBoundingBox()
		local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
		local front = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		local dist = (size.Y * 0.55) / math.tan(math.rad(15))
		camera.CFrame = CFrame.lookAt(cf.Position + front * dist + Vector3.new(0, size.Y * 0.05, 0), cf.Position)
		camera.Parent = vp
		vp.CurrentCamera = camera
	end)
end

local function wear(look: any, b: TextButton)
	local c = ctx :: Context
	if busy or not c.canChangeAvatar() then return end
	busy = true
	c.setBusy(true)
	b.Text = "입는 중..."
	local ok, success, result = pcall(function() return c.TryOnItem:InvokeServer("WearPost", look.key) end)
	c.setBusy(false)
	busy = false
	if b.Parent then b.Text = "입기" end
	if ok and success == true then
		c.showToast("✨ \"" .. look.title .. "\" 입었어요!")
	else
		c.showToast(if ok and typeof(result) == "string" then result else "지금은 입을 수 없어요.")
	end
	c.onWorn()
end

local function buy(look: any)
	local c = ctx :: Context
	if busy then return end
	local list = {}
	for _, item in ipairs(look.items) do
		if (item.price or 0) > 0 and #list < 20 then table.insert(list, { id = item.id, itemType = item.kind }) end
	end
	if #list == 0 then
		c.showToast("살 수 있는 아이템이 없어요.")
		return
	end
	busy = true
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

local function likeText(look: any): string
	return "👍 " .. tostring(look.likes)
end

local function lookCard(index: number, look: any)
	local c = ctx :: Context
	local content = shell(index, "Post_" .. look.key)
	local vp = make("ViewportFrame", {
		Name = "Thumbnail", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -110),
		BackgroundColor3 = COLORS.thumb, BorderSizePixel = 0, Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.3, -1, -0.6),
	}, content) :: ViewportFrame
	corner(vp, 6)
	showRig(vp, look.key)
	if look.mine or isOwner then
		local del = button(content, { Name = "DeleteButton", Text = "🗑", TextSize = 14, Position = UDim2.new(1, -35, 0, 9), Size = UDim2.fromOffset(26, 24) })
		confirmTap(del, "지울까요?", function()
			local ok, done, message = pcall(function() return Remote:InvokeServer("Delete", look.key) end)
			if ok and done then
				c.showToast("코디를 지웠어요.")
				local card = content.Parent
				if card then (card :: Instance):Destroy() end
			else
				c.showToast(if ok and typeof(message) == "string" then message else "지우지 못했어요.")
			end
		end)
		del:GetPropertyChangedSignal("Text"):Connect(function()
			del.Size = if del.Text == "🗑" then UDim2.fromOffset(26, 24) else UDim2.fromOffset(70, 24)
			del.Position = UDim2.new(1, -9 - del.Size.X.Offset, 0, 9)
		end)
	end
	if not look.mine then
		local rep = button(content, { Name = "ReportButton", Text = "🚩", TextSize = 13, Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(26, 24) })
		rep.BackgroundTransparency = 0.3
		confirmTap(rep, "신고할까요?", function()
			local ok, done, result = pcall(function() return Remote:InvokeServer("Report", look.key) end)
			if ok and done then
				if typeof(result) == "table" and result.already then
					c.showToast("이미 신고했어요.")
				else
					c.showToast("신고했어요. 고마워요!")
				end
				if typeof(result) == "table" and result.hidden and not isOwner then
					local card = content.Parent
					if card then (card :: Instance):Destroy() end
				end
			else
				c.showToast(if ok and typeof(result) == "string" then result else "신고하지 못했어요.")
			end
		end)
		rep:GetPropertyChangedSignal("Text"):Connect(function()
			rep.Size = if rep.Text == "🚩" then UDim2.fromOffset(26, 24) else UDim2.fromOffset(84, 24)
		end)
	end
	if look.hidden and isOwner then
		local un = button(content, { Name = "UnhideButton", Text = "숨김 풀기", Position = UDim2.new(0, 9, 1, -140), Size = UDim2.new(1, -18, 0, 24) })
		un.MouseButton1Click:Connect(function()
			local ok, done = pcall(function() return Remote:InvokeServer("Unhide", look.key) end)
			c.showToast(if ok and done then "다시 보이게 했어요." else "지금은 할 수 없어요.")
			if ok and done then
				local card = content.Parent
				if card then (card :: Instance):Destroy() end
			end
		end)
	end
	make("TextLabel", {
		Name = "Name", Position = UDim2.new(0, 6, 1, -102), Size = UDim2.new(1, -12, 0, 22), BackgroundTransparency = 1,
		Text = look.title, TextColor3 = COLORS.text, TextSize = 17, Font = Enum.Font.GothamMedium,
		TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	make("TextLabel", {
		Name = "By", Position = UDim2.new(0, 6, 1, -80), Size = UDim2.new(1, -12, 0, 16), BackgroundTransparency = 1,
		Text = "by " .. tostring(look.name), TextColor3 = COLORS.sub, TextSize = 13, Font = Enum.Font.GothamMedium,
		TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	local likeButton = button(content, {
		Name = "LikeButton", Position = UDim2.new(0, 6, 1, -60), Size = UDim2.new(0.42, -6, 0, 24), Text = likeText(look),
		TextColor3 = if look.liked then COLORS.liked else COLORS.text,
	})
	likeButton.MouseButton1Click:Connect(function()
		if look.mine then c.showToast("내 코디에는 👍를 누를 수 없어요.") return end
		local ok, done, result = pcall(function() return Remote:InvokeServer("Like", look.key) end)
		if ok and done and typeof(result) == "table" then
			look.liked = result.liked
			look.likes = result.likes
			likeButton.Text = likeText(look)
			likeButton.TextColor3 = if look.liked then COLORS.liked else COLORS.text
		else
			c.showToast(if ok and typeof(result) == "string" then result else "지금은 할 수 없어요.")
		end
	end)
	make("TextLabel", {
		Name = "Price", Position = UDim2.new(0.42, 4, 1, -60), Size = UDim2.new(0.58, -10, 0, 24), BackgroundTransparency = 1,
		Text = "R$ " .. tostring(look.price), TextColor3 = COLORS.sub, TextSize = 13,
		Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
	}, content)
	local wearButton = button(content, {
		Name = "ActionButton", Position = UDim2.new(0, 6, 1, -32), Size = UDim2.new(0.6, -9, 0, 26),
		BackgroundColor3 = COLORS.wear, Text = "입기",
	})
	wearButton.MouseButton1Click:Connect(function() wear(look, wearButton) end)
	local buyButton = button(content, {
		Name = "BuyButton", Position = UDim2.new(0.6, 3, 1, -32), Size = UDim2.new(0.4, -9, 0, 26), Text = "사기",
	})
	buyButton.MouseButton1Click:Connect(function() buy(look) end)
end

--------------------------------------------------
-- 📤 올리기 window
--------------------------------------------------
local postGui: ScreenGui? = nil
local function closePost()
	if postGui then postGui:Destroy() postGui = nil end
end
local function openPost()
	local c = ctx :: Context
	closePost()
	local gui = make("ScreenGui", {
		Name = "CommunityPost", DisplayOrder = 100, IgnoreGuiInset = true, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	postGui = gui
	local dim = make("TextButton", {
		Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
		Text = "", AutoButtonColor = false,
	}, gui)
	dim.MouseButton1Click:Connect(closePost)
	local box = make("Frame", {
		Name = "Box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(310, 196),
		BackgroundColor3 = COLORS.card,
	}, gui)
	corner(box, 12)
	make("UISizeConstraint", { MaxSize = Vector2.new(310, 196) }, box)
	make("TextLabel", {
		Name = "Title", Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1,
		Text = "📤 내 코디 올리기", TextColor3 = COLORS.text, TextSize = 18, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, box)
	make("TextLabel", {
		Name = "Hint", Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 34), BackgroundTransparency = 1,
		Text = "지금 입은 코디가 올라가요. 모두가 보고 입어 볼 수 있어요.", TextColor3 = COLORS.sub, TextSize = 13,
		Font = Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, box)
	local input = make("TextBox", {
		Name = "TitleInput", Position = UDim2.fromOffset(14, 80), Size = UDim2.new(1, -28, 0, 36),
		BackgroundColor3 = COLORS.thumb, TextColor3 = COLORS.text, PlaceholderText = "제목 (20자까지)",
		PlaceholderColor3 = COLORS.sub, Text = "", TextSize = 15, Font = Enum.Font.GothamMedium, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, box) :: TextBox
	corner(input, 7)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, input)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		local n = utf8.len(input.Text)
		if n and n > 20 then input.Text = string.sub(input.Text, 1, (utf8.offset(input.Text, 21) or 1) - 1) end
	end)
	local send = button(box, {
		Name = "PostButton", Position = UDim2.new(0, 14, 1, -52), Size = UDim2.new(0.6, -18, 0, 38),
		BackgroundColor3 = COLORS.wear, Text = "올리기", TextSize = 16,
	})
	local cancel = button(box, {
		Name = "CancelButton", Position = UDim2.new(0.6, 4, 1, -52), Size = UDim2.new(0.4, -18, 0, 38), Text = "취소", TextSize = 15,
	})
	cancel.MouseButton1Click:Connect(closePost)
	local sending = false
	send.MouseButton1Click:Connect(function()
		if sending then return end
		sending = true
		send.Text = "올리는 중..."
		local entries = c.collectWorn()
		local ok, done, result = pcall(function()
			return c.TryOnItem:InvokeServer("PostLook", { title = input.Text, entries = entries })
		end)
		sending = false
		if send.Parent then send.Text = "올리기" end
		if ok and done then
			closePost()
			c.showToast("코디를 올렸어요!")
			sort = "New"
			if c.isShown() then View.render() end
		else
			c.showToast(if ok and typeof(result) == "string" then result else "올리지 못했어요.")
		end
	end)
end

--------------------------------------------------
-- the grid
--------------------------------------------------
local function controlCard()
	local content = shell(0, "CommunityControl")
	make("TextLabel", {
		Name = "Header", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 22), BackgroundTransparency = 1,
		Text = "유저 코디", TextColor3 = COLORS.text, TextSize = 17, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	local sorts = { { "New", "최신" }, { "Top", "인기" } }
	if isOwner then table.insert(sorts, { "Hidden", "숨김" }) end
	for i, entry in ipairs(sorts) do
		local w = 1 / #sorts
		local b = button(content, {
			Name = "Sort_" .. entry[1], Text = entry[2], Position = UDim2.new(w * (i - 1), if i == 1 then 8 else 3, 0, 36),
			Size = UDim2.new(w, if i == 1 or i == #sorts then -11 else -6, 0, 28),
			BackgroundColor3 = if sort == entry[1] then COLORS.on else COLORS.off,
		})
		b.MouseButton1Click:Connect(function()
			if sort == entry[1] then return end
			sort = entry[1]
			View.render()
		end)
	end
	local post = button(content, {
		Name = "PostButton", Position = UDim2.fromOffset(8, 74), Size = UDim2.new(1, -16, 1, -112),
		BackgroundColor3 = COLORS.wear, Text = "📤\n내 코디\n올리기", TextSize = 17, TextWrapped = true,
	})
	post.MouseButton1Click:Connect(openPost)
	make("TextLabel", {
		Name = "Hint", Position = UDim2.new(0, 8, 1, -34), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1,
		Text = "지금 입은 옷이 올라가요", TextColor3 = COLORS.sub, TextSize = 12, Font = Enum.Font.GothamMedium,
		TextWrapped = true,
	}, content)
end

-- a card with a line of text (loading, nothing yet, errors): the results message would cover the control card
local function infoCard(index: number, name: string, text: string)
	local content = shell(index, name)
	make("TextLabel", {
		Name = "Text", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1, Text = text,
		TextColor3 = COLORS.sub, TextSize = 15, Font = Enum.Font.GothamMedium, TextWrapped = true,
	}, content)
end

local function load(gen: number, startIndex: number)
	local c = ctx :: Context
	local ok, done, result = pcall(function() return Remote:InvokeServer("List", sort, page) end)
	if gen ~= generation or not c.isShown() then return end
	local loading = c.container:FindFirstChild("CommunityLoading")
	if loading then loading:Destroy() end
	if not (ok and done and typeof(result) == "table") then
		infoCard(startIndex + 1, "CommunityInfo", if ok and typeof(result) == "string" then result else "코디를 불러오지 못했어요.")
		return
	end
	if result.owner and not isOwner then
		isOwner = true
		View.render()
		return
	end
	if #result.cards == 0 and page == 1 then
		infoCard(1, "CommunityInfo", if sort == "Hidden" then "숨긴 코디가 없어요." else "아직 올라온 코디가 없어요. 첫 코디를 올려 보세요!")
	end
	for i, look in ipairs(result.cards) do lookCard(startIndex + i, look) end
	if result.more then
		local content = shell(startIndex + #result.cards + 1, "CommunityMore")
		local more = button(content, { Name = "MoreButton", Text = "더 보기", TextSize = 16, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16) })
		more.MouseButton1Click:Connect(function()
			local card = content.Parent
			if card then (card :: Instance):Destroy() end
			page += 1
			load(generation, startIndex + #result.cards)
		end)
	end
end

function View.render()
	local c = ctx
	if not c then return end
	generation += 1
	page = 1
	closePost()
	for _, child in ipairs(c.container:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	c.setMessage(nil)
	controlCard()
	infoCard(1, "CommunityLoading", "불러오는 중...")
	local gen = generation
	task.spawn(load, gen, 0)
end

return View
