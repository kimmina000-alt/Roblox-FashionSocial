--!strict
-- Cafe part-time job, client side (CafeJobService, CAFE.md §9, D-099).
--   * "알바 시작" / "알바 끝내기" prompt (F) on each job cafe's counter.
--   * On duty: a "☕ 알바 중" pill (left) opens the order list (one popup at a
--     time, Popups). Each order: [만들기] at the counter → carry the cup →
--     a "서빙하기" prompt appears on that customer (outlined) → hand it over.
--   * Empty cups on tables: their "테이블 정리" prompt is turned on here for
--     staff of that cafe only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local Shared = FashionGame:WaitForChild("Shared")
local CafeJobConfig = require(Shared:WaitForChild("CafeJobConfig"))
local SnackConfig = require(Shared:WaitForChild("SnackConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local remote = Remotes:WaitForChild("CafeJob") :: RemoteFunction
local Popups = require(script.Parent:WaitForChild("Popups"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local player = Players.LocalPlayer

local COLORS = {
	bg = Color3.fromRGB(255, 250, 245),
	text = Color3.fromRGB(60, 40, 35),
	sub = Color3.fromRGB(120, 100, 90),
	accent = Color3.fromRGB(35, 120, 90),
	card = Color3.fromRGB(240, 232, 225),
	busy = Color3.fromRGB(200, 190, 180),
	serve = Color3.fromRGB(240, 130, 60),
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

local gui = make("ScreenGui", { Name = "CafeJobGui", ResetOnSpawn = false, DisplayOrder = 38, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

local pill = make("TextButton", {
	Name = "JobPill",
	Position = UDim2.fromOffset(12, 70),
	Size = UDim2.fromOffset(170, 34),
	BackgroundColor3 = COLORS.accent,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Text = "☕ 알바 중",
	Visible = false,
}, gui)
round(pill, 17)

local panel = make("Frame", {
	Name = "Orders",
	Position = UDim2.fromOffset(12, 110),
	Size = UDim2.fromOffset(250, 260),
	BackgroundColor3 = COLORS.bg,
	Visible = false,
}, gui)
round(panel, 14)
make("UIStroke", { Color = COLORS.accent, Thickness = 2 }, panel)
local title = make("TextLabel", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -52, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	Text = "☕ 주문 목록",
}, panel)
local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 6),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = COLORS.card,
	Text = "X",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = COLORS.text,
}, panel)
round(closeButton, 13)
local earnedLabel = make("TextLabel", {
	Position = UDim2.fromOffset(12, 30),
	Size = UDim2.new(1, -24, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.sub,
	Text = "",
}, panel)
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 52),
	Size = UDim2.new(1, -16, 1, -96),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local quitButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(1, -16, 0, 30),
	BackgroundColor3 = COLORS.card,
	Text = "알바 끝내기",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = COLORS.text,
}, panel)
round(quitButton, 10)

local toastLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.fromOffset(420, 36),
	BackgroundColor3 = Color3.fromRGB(30, 30, 35),
	BackgroundTransparency = 0.15,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextWrapped = true,
	Visible = false,
}, gui)
round(toastLabel, 10)
local toastToken = 0
local function toast(message: any)
	if typeof(message) ~= "string" or message == "" then return end
	toastToken += 1
	local token = toastToken
	local camera = workspace.CurrentCamera
	local width = if camera then math.min(420, camera.ViewportSize.X - 24) else 420
	toastLabel.Size = UDim2.fromOffset(width, 40)
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3.5, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

--------------------------------------------------

type OrderInfo = { id: number, shop: string, name: string, kind: string, user: number, who: string, maker: number, ready: boolean }

local function myShop(): string?
	local character = player.Character
	local shop = character and character:GetAttribute("CafeJob")
	return if typeof(shop) == "string" then shop else nil
end

local function readOrders(): {OrderInfo}
	local raw = FashionGame:GetAttribute("CafeOrders")
	if typeof(raw) ~= "string" then return {} end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(data) == "table" then data else {}
end

local function customerModel(order: OrderInfo): Model?
	if order.kind == "player" then
		local customer = Players:GetPlayerByUserId(order.user)
		return customer and customer.Character
	end
	local npcs = workspace:FindFirstChild("CafeNPCs")
	local npc = npcs and npcs:FindFirstChild("CafeNPC_" .. order.id)
	return if npc and npc:IsA("Model") then npc else nil
end

local function layout()
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 700)
	local top = TopBar.bottom() + 8
	pill.Position = UDim2.fromOffset(12, top)
	-- on phones the panel ends above the move stick in the bottom-left corner
	-- (user phone test 2026-10-26)
	local UserInputService = game:GetService("UserInputService")
	local bottom = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then vp.Y * 0.6 else vp.Y - 50
	local height = math.min(300, bottom - top - 40)
	panel.Position = UDim2.fromOffset(12, top + 40)
	panel.Size = UDim2.fromOffset(math.min(250, vp.X * 0.4), math.max(130, height))
end

local function setPanel(open: boolean)
	panel.Visible = open
	if open then
		layout()
		Popups.opened("CafeOrders", function() setPanel(false) end)
	else
		Popups.closed("CafeOrders")
	end
end

local busy: {[number]: boolean} = {}
local render: () -> ()

-- Make the oldest order nobody is making yet (counter prompt and list button).
local makePrompts: {[BasePart]: ProximityPrompt} = {}
local function waitingOrders(shop: string): ({OrderInfo}, number)
	local waiting, carried = {}, 0
	for _, order in ipairs(readOrders()) do
		if order.shop == shop then
			if order.maker == 0 and not busy[order.id] then table.insert(waiting, order) end
			if order.maker == player.UserId then carried += 1 end
		end
	end
	return waiting, carried
end
local function makeOrder(id: number)
	if busy[id] then return end
	busy[id] = true
	render()
	local ok, message = remote:InvokeServer("Make", id)
	busy[id] = nil
	toast(message)
	render()
	-- the cup is ready: close the list so the way to the customer is clear
	if ok and panel.Visible then setPanel(false) end
end
local function updateMakePrompts()
	local shop = myShop()
	local making = next(busy) ~= nil
	for counter, prompt in pairs(makePrompts) do
		local key = counter:GetAttribute("Shop")
		if shop ~= key then
			prompt.Enabled = false
		else
			local waiting, carried = waitingOrders(shop :: string)
			prompt.Enabled = #waiting > 0 and carried < 2 and not making
			prompt.ObjectText = string.format("주문 %d잔 · %s", #waiting, if #waiting > 0 then waiting[1].name else "")
		end
	end
end

render = function()
	local shop = myShop()
	pill.Visible = shop ~= nil
	updateMakePrompts()
	if not shop then
		if panel.Visible then setPanel(false) end
		return
	end
	local orders = {}
	for _, order in ipairs(readOrders()) do
		if order.shop == shop then table.insert(orders, order) end
	end
	local earned = player:GetAttribute("CafeJobEarned")
	earned = if typeof(earned) == "number" then earned else 0
	pill.Text = string.format("☕ 알바 중 · 주문 %d", #orders)
	local shopInfo = SnackConfig.Shops[shop]
	title.Text = "☕ " .. (if shopInfo then shopInfo.title else "주문 목록")
	local xp = player:GetAttribute("JobXP_" .. CafeJobConfig.JobKey)
	earnedLabel.Text = string.format("오늘 %s %d / %d · 알바 XP %d", EconomyConfig.Icon, earned, CafeJobConfig.DailyCap, if typeof(xp) == "number" then xp else 0)
	if not panel.Visible then return end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	if #orders == 0 then
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = COLORS.sub,
			Text = "주문을 기다리는 중… 손님이 곧 와요!",
		}, list)
	end
	for index, order in ipairs(orders) do
		local row = make("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -4, 0, 44),
			BackgroundColor3 = COLORS.card,
		}, list)
		round(row, 10)
		make("TextLabel", {
			Position = UDim2.fromOffset(8, 3),
			Size = UDim2.new(1, -100, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = COLORS.text,
			Text = order.name,
		}, row)
		make("TextLabel", {
			Position = UDim2.fromOffset(8, 22),
			Size = UDim2.new(1, -100, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = COLORS.sub,
			Text = (if order.kind == "npc" then "🙂 " else "👤 ") .. order.who,
		}, row)
		local mine = order.maker == player.UserId
		local text, color, active = "만들기", COLORS.accent, true
		if busy[order.id] or (mine and not order.ready) then
			text, color, active = "만드는 중…", COLORS.busy, false
		elseif mine and order.ready then
			text, color, active = "서빙하러 가기", COLORS.serve, false
		elseif order.maker ~= 0 then
			text, color, active = "다른 알바생", COLORS.busy, false
		end
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(86, 32),
			BackgroundColor3 = color,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = active,
		}, row)
		round(button, 8)
		if active then
			button.MouseButton1Click:Connect(function() makeOrder(order.id) end)
		end
	end
end

--------------------------------------------------
-- Serve prompts and outlines on the customers of the cups I carry
--------------------------------------------------

local servePrompts: {[number]: ProximityPrompt} = {}
local highlights: {[number]: Highlight} = {}

local function updateServing()
	local shop = myShop()
	local wanted: {[number]: OrderInfo} = {}
	if shop then
		for _, order in ipairs(readOrders()) do
			if order.shop == shop and order.maker == player.UserId and order.ready then wanted[order.id] = order end
		end
	end
	for id, prompt in pairs(servePrompts) do
		local order = wanted[id]
		local model = order and customerModel(order)
		if not order or not model or not prompt.Parent or not prompt.Parent:IsDescendantOf(model) then
			prompt:Destroy()
			servePrompts[id] = nil
			if highlights[id] then highlights[id]:Destroy() highlights[id] = nil end
		end
	end
	for id, order in pairs(wanted) do
		if not servePrompts[id] then
			local model = customerModel(order)
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if model and root then
				local prompt = make("ProximityPrompt", {
					Name = "ServePrompt",
					ActionText = "서빙하기",
					ObjectText = order.name,
					KeyboardKeyCode = Enum.KeyCode.E,
					HoldDuration = 0,
					MaxActivationDistance = CafeJobConfig.ServeDistance - 1,
					RequiresLineOfSight = false,
				}, root)
				prompt.Triggered:Connect(function()
					local _, message = remote:InvokeServer("Serve", id)
					toast(message)
				end)
				servePrompts[id] = prompt
				highlights[id] = make("Highlight", {
					FillTransparency = 1,
					OutlineColor = COLORS.serve,
					OutlineTransparency = 0,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				}, model)
			end
		end
	end
end

local function updateCups()
	local shop = myShop()
	local cups = workspace:FindFirstChild("CafeCups")
	if not cups then return end
	for _, cup in ipairs(cups:GetChildren()) do
		local prompt = cup:FindFirstChild("CleanPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			-- empty cups always; a drink with some left only once its owner left the cafe
			local clearable = cup:GetAttribute("Owner") == nil or cup:GetAttribute("Clearable") == true
			prompt.Enabled = shop ~= nil and cup:GetAttribute("Shop") == shop and clearable
		end
		-- my own drink on the table: pick it up again
		local pick = cup:FindFirstChild("PickPrompt")
		if pick and pick:IsA("ProximityPrompt") then
			pick.Enabled = cup:GetAttribute("Owner") == player.UserId
		end
	end
end

--------------------------------------------------
-- Start / stop prompt on the counters
--------------------------------------------------

local jobPrompts: {[BasePart]: ProximityPrompt} = {}
-- the prompts sit on the work counter behind the bar ("BackCounter", user
-- 2026-10-22), on an attachment that follows the nearest point to the player
local anchors: {[Attachment]: BasePart} = {}

local function refreshJobPrompts()
	local shop = myShop()
	for counter, prompt in pairs(jobPrompts) do
		local key = counter:GetAttribute("Shop")
		prompt.ActionText = if shop == key then "알바 끝내기" else "알바 시작"
		-- staff do not order at their own cafe (user, 2026-10-22): hide "음료 주문하기"
		local order = counter:FindFirstChild("SnackPrompt")
		if order and order:IsA("ProximityPrompt") then order.Enabled = shop ~= key end
	end
	updateMakePrompts()
end

local function watchCounter(part: Instance)
	if not part:IsA("BasePart") or jobPrompts[part] then return end
	local key = part:GetAttribute("Shop")
	if typeof(key) ~= "string" or not table.find(CafeJobConfig.Shops, key) or not part:IsDescendantOf(workspace) then return end
	local shopInfo = SnackConfig.Shops[key]
	local prompt = make("ProximityPrompt", {
		Name = "JobPrompt",
		ActionText = "알바 시작",
		ObjectText = (if shopInfo then shopInfo.title else "카페") .. " 알바",
		KeyboardKeyCode = Enum.KeyCode.F,
		HoldDuration = 0.3,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
	})
	local station = part.Parent and part.Parent:FindFirstChild("BackCounter")
	local stationPart: BasePart = if station and station:IsA("BasePart") then station else part
	local anchor = make("Attachment", { Name = "CafeJobAnchor" }, stationPart)
	anchors[anchor] = stationPart
	prompt.Parent = anchor
	prompt.Triggered:Connect(function()
		if myShop() == key then
			local _, message = remote:InvokeServer("Stop", nil)
			toast(message)
		else
			local ok, message = remote:InvokeServer("Start", key)
			toast(message)
			if ok then
				task.wait(0.2)
				render()
				setPanel(true)
				render()
			end
		end
	end)
	jobPrompts[part] = prompt
	-- "음료 만들기" right at the counter (user, 2026-10-22: the list button was
	-- not found): makes the oldest waiting order
	local makePrompt = make("ProximityPrompt", {
		Name = "MakePrompt",
		ActionText = "음료 만들기",
		ObjectText = "",
		KeyboardKeyCode = Enum.KeyCode.E,
		HoldDuration = 0,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
		Enabled = false,
	}, anchor)
	makePrompt.Triggered:Connect(function()
		local shop = myShop()
		if shop ~= key then return end
		local waiting = waitingOrders(shop :: string)
		if waiting[1] then makeOrder(waiting[1].id) end
	end)
	makePrompts[part] = makePrompt
	-- the order prompt is made by the server; it may arrive after this
	part.ChildAdded:Connect(function(child)
		if child.Name == "SnackPrompt" then refreshJobPrompts() end
	end)
	refreshJobPrompts()
end

for _, part in ipairs(CollectionService:GetTagged("SnackShop")) do watchCounter(part) end
CollectionService:GetInstanceAddedSignal("SnackShop"):Connect(watchCounter)

pill.MouseButton1Click:Connect(function()
	setPanel(not panel.Visible)
	render()
end)
closeButton.MouseButton1Click:Connect(function() setPanel(false) end)
quitButton.MouseButton1Click:Connect(function()
	local _, message = remote:InvokeServer("Stop", nil)
	toast(message)
end)

local function onCharacter(character: Model)
	character:GetAttributeChangedSignal("CafeJob"):Connect(function()
		refreshJobPrompts()
		render()
	end)
	refreshJobPrompts()
	render()
end
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

FashionGame:GetAttributeChangedSignal("CafeOrders"):Connect(render)
player:GetAttributeChangedSignal("CafeJobEarned"):Connect(render)
player:GetAttributeChangedSignal("JobXP_" .. CafeJobConfig.JobKey):Connect(render)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end
layout()

-- prompt anchors: nearest point on the top of the work counter
local function updateAnchors()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	for anchor, part in pairs(anchors) do
		if anchor.Parent then
			local here = part.CFrame:PointToObjectSpace(root.Position)
			local half = part.Size / 2
			anchor.Position = Vector3.new(math.clamp(here.X, -half.X + 0.5, half.X - 0.5), half.Y + 0.5, math.clamp(here.Z, -half.Z + 0.5, half.Z - 0.5))
		end
	end
end

-- no sitting during a shift (user, 2026-10-22: the sit prompt hid "서빙하기")
local sittingBlocked = false
local function updateSeats()
	local onDuty = myShop() ~= nil
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and onDuty ~= sittingBlocked then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, not onDuty)
	end
	if onDuty or sittingBlocked then
		for _, seat in ipairs(CollectionService:GetTagged("PromptSeat")) do
			local prompt = seat:FindFirstChild("SitPrompt")
			if prompt and prompt:IsA("ProximityPrompt") and seat:IsA("Seat") then
				prompt.Enabled = not onDuty and seat.Occupant == nil
			end
		end
	end
	sittingBlocked = onDuty
end

-- order bubbles: only the staff of that cafe and the customer see them
local function updateBubbles()
	local shop = myShop()
	local heads = {}
	local npcs = workspace:FindFirstChild("CafeNPCs")
	if npcs then
		for _, npc in ipairs(npcs:GetChildren()) do table.insert(heads, npc:FindFirstChild("Head")) end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		table.insert(heads, other.Character and other.Character:FindFirstChild("Head"))
	end
	for _, head in ipairs(heads) do
		local bubble = head and head:FindFirstChild("CafeOrderBubble")
		if bubble and bubble:IsA("BillboardGui") then
			bubble.Enabled = (shop ~= nil and bubble:GetAttribute("Shop") == shop) or bubble:GetAttribute("Customer") == player.UserId
		end
	end
end

-- put the drink in my hand on a cafe table (user, 2026-10-22)
local putPrompt: ProximityPrompt? = nil
local putTable: BasePart? = nil
local function isTable(part: Instance): boolean
	if not part:IsA("BasePart") then return false end
	local name = string.lower(part.Name)
	if string.find(name, "leg") or string.find(name, "stool") then return false end
	local surface = string.find(name, "table") ~= nil or string.sub(name, -3) == "bar"
	return surface and part.Size.Y <= 1.5 and math.min(part.Size.X, part.Size.Z) >= 1 and math.max(part.Size.X, part.Size.Z) >= 1.5
end
local tableCache: {BasePart}? = nil
local function cafeTables(): {BasePart}
	if tableCache then return tableCache end
	local list = {}
	for _, counter in ipairs(CollectionService:GetTagged("SnackShop")) do
		if counter:IsDescendantOf(workspace) and table.find(CafeJobConfig.Shops, counter:GetAttribute("Shop")) and counter.Parent then
			for _, part in ipairs(counter.Parent:GetDescendants()) do
				if isTable(part) then table.insert(list, part :: BasePart) end
			end
		end
	end
	if #list > 0 then tableCache = list end
	return list
end
local function updatePutDown()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local holding = tool ~= nil and tool:GetAttribute("Snack") ~= nil and tool:GetAttribute("CafeOrder") == nil
		and tool:FindFirstChild("Handle") ~= nil and (tool:FindFirstChild("Handle") :: Instance):FindFirstChild("Straw", true) ~= nil
	local best: BasePart? = nil
	if holding and root and root:IsA("BasePart") then
		local bestDistance = 7
		for _, part in ipairs(cafeTables()) do
			-- distance to the nearest point of the top (long bars)
			local here = part.CFrame:PointToObjectSpace(root.Position)
			local half = part.Size / 2
			local flat = Vector2.new(here.X - math.clamp(here.X, -half.X, half.X), here.Z - math.clamp(here.Z, -half.Z, half.Z)).Magnitude
			if flat < bestDistance and math.abs(part.Position.Y - root.Position.Y) < 6 then best, bestDistance = part, flat end
		end
	end
	if best ~= putTable then
		if putPrompt then (putPrompt.Parent :: Instance):Destroy() end
		putPrompt = nil
		putTable = best
		if best then
			-- on an attachment at the nearest point of the top (long bars)
			local anchor = make("Attachment", { Name = "PutDownAnchor" }, best)
			local prompt = make("ProximityPrompt", {
				Name = "PutDownPrompt",
				ActionText = "테이블에 놓기",
				ObjectText = "",
				KeyboardKeyCode = Enum.KeyCode.R,
				HoldDuration = 0,
				MaxActivationDistance = 8,
				RequiresLineOfSight = false,
			}, anchor)
			prompt.Triggered:Connect(function()
				local _, message = remote:InvokeServer("PutDown", best)
				toast(message)
			end)
			putPrompt = prompt
		end
	end
	if best and putPrompt and root and root:IsA("BasePart") then
		local here = best.CFrame:PointToObjectSpace(root.Position)
		local half = best.Size / 2;
		(putPrompt.Parent :: Attachment).Position = Vector3.new(math.clamp(here.X, -half.X, half.X), half.Y + 0.3, math.clamp(here.Z, -half.Z, half.Z))
	end
end

task.spawn(function()
	while true do
		task.wait(0.4)
		updateServing()
		updateCups()
		updateSeats()
		updateBubbles()
		updatePutDown()
	end
end)
game:GetService("RunService").Heartbeat:Connect(updateAnchors)
