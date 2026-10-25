--!strict
-- Bus stop ad boards (D-279). Each panel (tag "BusAd") shows the ad of whoever
-- bought it: their avatar in their outfit and pose (drawn like a photo booth
-- shot, PhotoRender) and "@username". An empty panel keeps its default poster
-- with a small "광고 자리" band. The "광고판" prompt (G) opens a window to buy
-- the panel (24시간 49 R$ / 3일 99 R$) or, for the owner, to retake the photo:
-- pick a pose, step through it, "📸 이걸로".

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction
local ClubNotify = Remotes:WaitForChild("ClubNotify") :: RemoteEvent
local PhotoRender = require(script.Parent:WaitForChild("PhotoRender"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local GOLD = Color3.fromRGB(255, 214, 110)
local BACK = { 246, 236, 248 } -- pastel set behind the avatar
-- close enough that the avatar fills the poster (2026-10-25 check)
local CAMERA = { CFrame.lookAt(Vector3.new(0, -1.9, -8), Vector3.new(0, -2.6, 0)):GetComponents() }

local ads: any = {}
local panels: {[BasePart]: any} = {}

local function readAds()
	local raw = FashionGame:GetAttribute("BusAds")
	if typeof(raw) ~= "string" then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and typeof(data) == "table" then ads = data end
end

local function adKey(ad: any): string
	if not ad or not ad.u then return "" end
	return string.format("%s|%s|%s|%s", tostring(ad.u), tostring(ad.k), tostring(ad.t), HttpService:JSONEncode(ad.o or {}))
end

local function shotFor(ad: any): any
	return { people = { { u = ad.u, x = 0, y = -2.9, z = 0, r = 0, k = ad.k, t = ad.t or 0 } } }
end

--------------------------------------------------
-- Panels
--------------------------------------------------

local function buildPanel(panel: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BusAdGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Adornee = panel
	gui.Parent = playerGui
	-- the ad (hidden while the panel is free)
	local adFrame = Instance.new("Frame")
	adFrame.Size = UDim2.fromScale(1, 1)
	adFrame.BackgroundColor3 = Color3.fromRGB(BACK[1], BACK[2], BACK[3])
	adFrame.Visible = false
	adFrame.Parent = gui
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 0.86)
	viewport.BackgroundTransparency = 1
	viewport.Parent = adFrame
	local band = Instance.new("TextLabel")
	band.Position = UDim2.fromScale(0, 0.86)
	band.Size = UDim2.fromScale(1, 0.14)
	band.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	band.TextColor3 = GOLD
	band.TextScaled = true
	band.Font = Enum.Font.GothamBold
	band.Parent = adFrame
	local tag = Instance.new("TextLabel")
	tag.Position = UDim2.fromScale(0.04, 0.02)
	tag.Size = UDim2.fromScale(0.42, 0.06)
	tag.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	tag.BackgroundTransparency = 0.2
	tag.Text = "OHU 광고"
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.TextScaled = true
	tag.Font = Enum.Font.GothamBold
	tag.Parent = adFrame
	-- free: a small band over the default poster
	local free = Instance.new("TextLabel")
	free.Position = UDim2.fromScale(0, 0.86)
	free.Size = UDim2.fromScale(1, 0.14)
	free.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	free.BackgroundTransparency = 0.15
	free.Text = "광고 자리 · G로 구매"
	free.TextColor3 = Color3.new(1, 1, 1)
	free.TextScaled = true
	free.Font = Enum.Font.GothamMedium
	free.Parent = gui
	local shown = ""
	return {
		gui = gui,
		update = function()
			local ad = ads[panel:GetAttribute("Slot")]
			local active = ad ~= nil and ad.u ~= nil
			adFrame.Visible = active
			free.Visible = not active
			if not active then
				shown = ""
				return
			end
			band.Text = "@" .. tostring(ad.n)
			local key = adKey(ad)
			if key == shown then return end
			shown = key
			task.spawn(function()
				PhotoRender.renderShot(viewport, shotFor(ad), { [ad.u] = { o = ad.o } }, { back = BACK, cam = CAMERA })
			end)
		end,
	}
end

local function addPanel(panel: Instance)
	if not panel:IsA("BasePart") or panels[panel] or not panel:IsDescendantOf(workspace) then return end
	local entry = buildPanel(panel)
	panels[panel] = entry
	entry.update()
	panel.AncestryChanged:Connect(function()
		if not panel:IsDescendantOf(workspace) and panels[panel] then
			panels[panel].gui:Destroy()
			panels[panel] = nil
		end
	end)
end

--------------------------------------------------
-- Window (buy / retake)
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "FashionBusAdGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 32
gui.Parent = playerGui

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0)
window.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
window.Visible = false
window.Parent = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 16)

local function clear()
	for _, child in ipairs(window:GetChildren()) do
		if not child:IsA("UICorner") then child:Destroy() end
	end
end

local function label(props: {[string]: any}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = window
	return l
end

local function button(props: {[string]: any}, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	for k, v in pairs(props) do (b :: any)[k] = v end
	b.Parent = window
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	Instance.new("UITextSizeConstraint", b).MaxTextSize = 16
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function closeWindow()
	window.Visible = false
	Popups.closed("BusAd")
end

local function openWindow(width: number, height: number)
	local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
	local top = TopBar.bottom() + 8
	window.Position = UDim2.new(0.5, 0, 0, top)
	window.Size = UDim2.fromOffset(math.min(width, vp.X - 24), math.min(height, vp.Y - top - 12))
	window.Visible = true
	Popups.opened("BusAd", function() window.Visible = false end)
end

local function buy(key: string, slotId: string)
	local product = MonetizationConfig.Products[key]
	ClubShop:InvokeServer("BusAdSelect", slotId)
	closeWindow()
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = key })
	end
end

local function timeLeft(untilTime: number): string
	local left = math.max(0, untilTime - os.time())
	local hours = left // 3600
	if hours >= 24 then return string.format("%d일 %d시간", hours // 24, hours % 24) end
	return string.format("%d시간 %d분", hours, (left % 3600) // 60)
end

local showPoseWindow: (slotId: string) -> ()

local function showSlotWindow(panel: BasePart)
	local slotId = panel:GetAttribute("Slot") :: string
	local ad = ads[slotId]
	clear()
	openWindow(330, 250)
	label({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 26),
		Text = "📰 " .. tostring(panel:GetAttribute("StopName") or "") .. " 광고판" })
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(38, 38, 50), Text = "X" }, closeWindow)
	local mine = ad and ad.u == player.UserId
	local status = if not ad or not ad.u then "비어 있어요! 내 아바타와 아이디를 걸 수 있어요."
		elseif mine then string.format("내 광고 · 남은 시간 %s", timeLeft(ad.untilTime))
		else string.format("@%s님 광고 · %s 남음%s", tostring(ad.n), timeLeft(ad.untilTime),
			if (ad.queue or 0) > 0 then string.format(" · 대기 %d명", ad.queue) else "")
	label({ Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 40), TextWrapped = true, Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 200, 215), Text = status .. (if ad and ad.u and not mine then "\n사면 대기열에 들어가요 (끝나면 바로 내 차례)." else "") })
	local y = 92
	if mine then
		button({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 40), BackgroundColor3 = Color3.fromRGB(255, 80, 160),
			Text = "📸 포즈 다시 찍기 (지금 코디로)" }, function() showPoseWindow(slotId) end)
		y += 48
	end
	local studio = MonetizationConfig.Products.BusAd1D.id == 0 and RunService:IsStudio()
	button({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(0.5, -20, 0, 44), BackgroundColor3 = Color3.fromRGB(0, 176, 111),
		Text = string.format("24시간 R$ %d", MonetizationConfig.Products.BusAd1D.price) }, function() buy("BusAd1D", slotId) end)
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, y), Size = UDim2.new(0.5, -20, 0, 44),
		BackgroundColor3 = Color3.fromRGB(230, 170, 40),
		Text = string.format("3일 R$ %d", MonetizationConfig.Products.BusAd3D.price) }, function() buy("BusAd3D", slotId) end)
	if studio then
		label({ Position = UDim2.fromOffset(16, y + 50), Size = UDim2.new(1, -32, 0, 16), Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(150, 150, 165), Text = "[Studio 테스트] 결제 없이 시험해요" })
	end
	if RunService:IsStudio() or player.UserId == game.CreatorId then
		if ad and ad.u then
			button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -10), Size = UDim2.new(1, -32, 0, 26),
				BackgroundColor3 = Color3.fromRGB(80, 30, 30), Text = "관리자: 이 광고 내리기" }, function()
				ClubShop:InvokeServer("BusAdRemove", slotId)
				closeWindow()
			end)
		end
	end
end

-- Pose picker: the avatar in the current outfit, a dance/pose list, ◀ ▶ to
-- step through the clip, "📸 이걸로" saves it to the ad.
showPoseWindow = function(slotId: string)
	clear()
	openWindow(420, 330)
	label({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 24), Text = "📸 광고 사진 찍기" })
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(38, 38, 50), Text = "X" }, closeWindow)
	local preview = Instance.new("ViewportFrame")
	preview.Position = UDim2.fromOffset(16, 42)
	preview.Size = UDim2.new(0.42, -16, 1, -100)
	preview.BackgroundColor3 = Color3.fromRGB(BACK[1], BACK[2], BACK[3])
	preview.Parent = window
	Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 10)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0.42, 8, 0, 42)
	list.Size = UDim2.new(0.58, -24, 1, -100)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -4, 0, 30)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	-- my current outfit (the server takes the same one when saving)
	local outfit: any = nil
	do
		local ok, snapshot = pcall(function()
			local OutfitSnapshot = require(Shared:WaitForChild("OutfitSnapshot"))
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			return humanoid and OutfitSnapshot.encode(humanoid:GetAppliedDescription())
		end)
		outfit = if ok then snapshot else nil
	end
	local pose: string? = nil
	local t = 0
	local token = 0
	local function redraw()
		token += 1
		local mine = token
		task.spawn(function()
			if mine ~= token then return end
			PhotoRender.renderShot(preview, { people = { { u = player.UserId, x = 0, y = -2.9, z = 0, r = 0, k = pose, t = t } } },
				{ [player.UserId] = { o = outfit } }, { back = BACK, cam = CAMERA })
		end)
	end
	local poses: {{ key: string?, name: string }} = { { key = nil, name = "기본 서기" } }
	for _, dance in ipairs(ClubConfig.Dances) do table.insert(poses, { key = dance.key, name = dance.name }) end
	for index, entry in ipairs(poses) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = index
		b.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
		b.Text = entry.name
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Font = Enum.Font.GothamMedium
		b.Parent = list
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		Instance.new("UITextSizeConstraint", b).MaxTextSize = 14
		b.MouseButton1Click:Connect(function()
			pose = entry.key
			t = 0.6
			redraw()
		end)
	end
	button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12), Size = UDim2.fromOffset(44, 40),
		BackgroundColor3 = Color3.fromRGB(38, 38, 50), Text = "◀" }, function() t = math.max(0, t - 0.3) redraw() end)
	button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 66, 1, -12), Size = UDim2.fromOffset(44, 40),
		BackgroundColor3 = Color3.fromRGB(38, 38, 50), Text = "▶" }, function() t += 0.3 redraw() end)
	button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -12), Size = UDim2.new(1, -140, 0, 40),
		BackgroundColor3 = Color3.fromRGB(255, 80, 160), Text = "📸 이걸로 광고 사진" }, function()
		local ok, message = ClubShop:InvokeServer("BusAdPose", { slot = slotId, k = pose, t = t })
		closeWindow()
		if not ok and message then warn(message) end
	end)
	redraw()
end

--------------------------------------------------

local function refresh()
	readAds()
	for _, entry in pairs(panels) do entry.update() end
end

readAds()
for _, panel in ipairs(CollectionService:GetTagged("BusAd")) do addPanel(panel) end
CollectionService:GetInstanceAddedSignal("BusAd"):Connect(addPanel)
FashionGame:GetAttributeChangedSignal("BusAds"):Connect(refresh)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BusAdPrompt" and prompt.Parent and prompt.Parent:IsA("BasePart") then
		showSlotWindow(prompt.Parent)
	end
end)

-- right after buying: take the photo
ClubNotify.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "BusAdBought" and typeof(value) == "string" then
		task.wait(0.3)
		showPoseWindow(value)
	end
end)
