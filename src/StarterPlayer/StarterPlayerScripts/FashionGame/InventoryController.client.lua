--!strict
-- 🎒 bag button in the top bar (user 2026-10-30): opens a window with every
-- item in the backpack and the one in hand. Tap an item to hold it, tap the
-- held one to put it away. (Roblox's own full inventory has no button on
-- phones, and no script can open it.)
-- (user 2026-10-30, later) 내 앨범 is gone: the bag has two tabs, 소지품 and
-- 사진 (the saved photos; tap one to see it big, hold it or delete it — the
-- viewer is PhotoBoothController's, through BagSignals).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local BagSignals = require(script.Parent:WaitForChild("BagSignals"))
local PhotoFlowUI = require(script.Parent:WaitForChild("PhotoFlowUI"))
local PhotoRender = require(script.Parent:WaitForChild("PhotoRender"))
local Hotbar = require(script.Parent:WaitForChild("Hotbar")) -- (D-1130: the bar at the bottom, drag in / out)
local PhotoConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("PhotoConfig"))
local boothRemote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("PhotoBooth") :: RemoteFunction

local PINK = Color3.fromRGB(255, 110, 180)

local gui = Instance.new("ScreenGui")
gui.Name = "FashionInventoryGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 31
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local panel = Instance.new("Frame")
panel.Name = "Bag"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
panel.Visible = false
panel.Parent = gui
corner(panel, 16)
do
	local s = Instance.new("UIStroke")
	s.Color = PINK
	s.Thickness = 2
	s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -60, 0, 28)
title.BackgroundTransparency = 1
title.Text = "🎒 내 가방"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(30, 30)
close.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 15
close.Parent = panel
corner(close, 15)

-- tabs: 소지품 | 사진
local tab = "items"
local function tabButton(label: string, x: number): TextButton
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 44)
	b.Size = UDim2.fromOffset(92, 28)
	b.Text = label
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 14
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = true
	b.Parent = panel
	corner(b, 14)
	return b
end
local itemsTab = tabButton("소지품", 16)
local photosTab = tabButton("사진", 114)

local hint = Instance.new("TextLabel")
hint.Position = UDim2.fromOffset(16, 76)
hint.Size = UDim2.new(1, -32, 0, 18)
hint.BackgroundTransparency = 1
hint.Text = "누르면 손에 들어요 · 아래 칸으로 끌어 꺼내고, 아래 칸에서 끌어 넣어요"
hint.TextColor3 = Color3.fromRGB(190, 190, 205)
hint.TextSize = 13
hint.Font = Enum.Font.GothamMedium
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextTruncate = Enum.TextTruncate.AtEnd
hint.Parent = panel

local deleteAll = Instance.new("TextButton")
deleteAll.AnchorPoint = Vector2.new(1, 0)
deleteAll.Position = UDim2.new(1, -16, 0, 44)
deleteAll.Size = UDim2.fromOffset(96, 28)
deleteAll.BackgroundColor3 = Color3.fromRGB(44, 42, 54)
deleteAll.Text = "🗑 전체 삭제"
deleteAll.TextColor3 = Color3.new(1, 1, 1)
deleteAll.TextSize = 13
deleteAll.Font = Enum.Font.GothamBold
deleteAll.Visible = false
deleteAll.Parent = panel
corner(deleteAll, 10)

local function scroller(cell: Vector2): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 100)
	list.Size = UDim2.new(1, -24, 1, -112)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = PINK
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	-- (D-1122, user 2026-11-09: "가방도 선 씹힘 깔끔하게 수정") the cards' edge (2 when
	-- held) is drawn just outside them: room on every side so the list does not
	-- cut it off (top row, left column), and the scroll bar's width on the right
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = list
	return list
end
local list = scroller(Vector2.new(88, 100))
-- (D-1130, user 2026-11-10: "한 화면에 아이템 4열?로 보이도록 모바일에서 폰 기종에 따라
-- 사이즈 달라져도 4개가 균일하게 정렬돼서 보이도록 퍼센트로 사이즈 결정. pc에서는 8개로")
-- the item cards: 4 a row on phones, 8 on PC, each a share of the width (the
-- height follows by a fixed ratio); no limit on how many, the list scrolls
local PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local COLS = if PHONE then 4 else 8
do
	local grid = list:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.new(1 / COLS, -8, 0, 100)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 88 / 100
	ratio.Parent = grid
end
local photoList = scroller(Vector2.new(88, 190))

local empty = Instance.new("TextLabel")
empty.Position = UDim2.fromOffset(16, 124)
empty.Size = UDim2.new(1, -32, 0, 48)
empty.BackgroundTransparency = 1
empty.Text = "가방이 비어 있어요"
empty.TextColor3 = Color3.fromRGB(160, 160, 180)
empty.TextSize = 15
empty.TextWrapped = true
empty.Font = Enum.Font.GothamMedium
empty.Visible = false
empty.Parent = panel

-- the leading emoji of a tool name ("🎇 스파클러") as its picture (Hotbar.split since D-1130)
local split = Hotbar.split

-- (D-1371, user 2026-11-13: "홈화면 아래 인벤토리 4 칸에 꺼내져있는 아이템은 가방에서 빼.
-- 아이템은 가방 홈화면인벤 두 군데 중 한 군데에만 있기") a tool in a slot of the bar at the
-- bottom is not listed in the bag: each item is in one of the two places
local function tools(): {Tool}
	local out = {}
	local character = player.Character
	local held = character and character:FindFirstChildOfClass("Tool")
	if held and not Hotbar.indexOf(held) then table.insert(out, held) end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and not Hotbar.indexOf(t) then table.insert(out, t) end
		end
	end
	return Hotbar.bagSort(out) -- (D-1164: the order the player dragged them into)
end
local cardTools: {[GuiObject]: Tool} = {}

local function refreshItems()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	table.clear(cardTools)
	local items = tools()
	empty.Text = "가방이 비어 있어요"
	empty.Visible = #items == 0
	for i, tool in ipairs(items) do
		local held = tool.Parent == player.Character
		local cell = Instance.new("TextButton")
		cell.Name = "Item"
		cell.LayoutOrder = i
		cell.Text = ""
		cell.AutoButtonColor = true
		cell.BackgroundColor3 = if held then Color3.fromRGB(60, 24, 52) else Color3.fromRGB(30, 30, 42)
		cell.Parent = list
		cardTools[cell] = tool
		corner(cell, 12)
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = if held then PINK else Color3.fromRGB(70, 70, 95)
		s.Thickness = if held then 2 else 1
		s.Parent = cell
		local icon, name = split(tool.Name)
		Hotbar.look(tool, cell, icon, UDim2.fromScale(0.66, 0.6), UDim2.fromScale(0.5, 0.04)) -- (D-1130: in scale)
		local count = tool:GetAttribute("Count")
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(0.05, 0.64)
		l.Size = UDim2.fromScale(0.9, 0.3)
		l.BackgroundTransparency = 1
		l.Text = name .. (if typeof(count) == "number" and count > 1 then (" ×" .. count) else "")
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextScaled = true
		l.TextWrapped = true
		l.Font = Enum.Font.GothamMedium
		l.Parent = cell
		Instance.new("UITextSizeConstraint", l).MaxTextSize = 13
		-- (the bar's slot number on the card went with D-1371: bar items are not in the bag)
		-- tap = hold it / put it away; drag onto the bar at the bottom = into that slot
		Hotbar.pressable(cell, function() return tool end, function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			if tool.Parent == player.Character then
				humanoid:UnequipTools()
			elseif tool.Parent then
				humanoid:EquipTool(tool)
			end
			task.defer(function() if tab == "items" then refreshItems() end end)
		end)
	end
end

-- the saved photos (they were 내 앨범): a card each with the date and a trash
-- button; tapping a card shows it big
local photoGeneration = 0
local function invoke(action: string, payload: any): (boolean, any)
	local ok, success, result = pcall(function() return boothRemote:InvokeServer(action, payload) end)
	if not ok then return false, "잠시 후 다시 시도하세요." end
	return success, result
end
local function refreshPhotos()
	photoGeneration += 1
	local generation = photoGeneration
	for _, c in ipairs(photoList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	hint.Text = "불러오는 중..."
	empty.Visible = false
	local ok, data = invoke("GetAlbum", nil)
	if generation ~= photoGeneration or tab ~= "photos" then return end
	if not ok or typeof(data) ~= "table" then
		hint.Text = if typeof(data) == "string" then data else "사진을 불러오지 못했어요."
		return
	end
	local photos = data.photos or {}
	hint.Text = string.format("%d/%d장 · 누르면 크게 보고 손에 들 수 있어요", #photos, data.max or PhotoConfig.MaxPhotos)
	empty.Text = "아직 사진이 없어요. 오후네컷(클럽과 공원 사이)에서 찍어 보세요!"
	empty.Visible = #photos == 0
	deleteAll.Visible = #photos > 0
	for index, photo in ipairs(photos) do
		local cell, holder, trash = PhotoFlowUI.albumCard(photoList, index, photo.createdAt, 2)
		PhotoRender.drawPhoto(holder, photo)
		trash.MouseButton1Click:Connect(function()
			PhotoFlowUI.confirm(gui, "사진을 삭제할까요?", "삭제한 사진은 복구할 수 없어요.", "삭제", function()
				local deleted, message = invoke("DeletePhoto", photo.id)
				if not deleted and typeof(message) == "string" then hint.Text = message end
				if deleted then task.spawn(refreshPhotos) end
			end)
		end)
		cell.MouseButton1Click:Connect(function() BagSignals.viewPhoto:Fire(photo) end)
	end
end

local function showTab(which: string)
	tab = which
	local photosOn = which == "photos"
	itemsTab.BackgroundColor3 = if photosOn then Color3.fromRGB(38, 38, 50) else PINK
	photosTab.BackgroundColor3 = if photosOn then PINK else Color3.fromRGB(38, 38, 50)
	list.Visible = not photosOn
	photoList.Visible = photosOn
	deleteAll.Visible = false
	if photosOn then
		task.spawn(refreshPhotos)
		-- (D-1125) the album opened: "사진을 다시 확인" for the analytics
		local gate = boothRemote.Parent and boothRemote.Parent:FindFirstChild("AnalyticsStep")
		if gate and gate:IsA("RemoteEvent") then gate:FireServer("AlbumOpen") end
	else
		hint.Text = "누르면 손에 들어요 · 아래 칸으로 끌어 꺼내고, 아래 칸에서 끌어 넣어요"
		refreshItems()
	end
end

local function refresh()
	if panel.Visible and tab == "items" then refreshItems() end
end
-- (D-1130) a slot of the bar dropped on the open bag: into the bag, out of the bar
-- (D-1164) dropped on a card: it takes that card's place in the bag; a bag card
-- dropped in the bag only moves (it keeps its slot in the bar)
Hotbar.addZone(panel, function(tool: Tool, at: Vector2): boolean
	if not panel.Visible then return false end
	local target: Tool? = nil
	if tab == "items" then
		-- (what is under the pointer, in the pointer's own space: adding the top
		-- bar's inset by hand missed the cards in a Studio test)
		for _, o in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(at.X, at.Y)) do
			local node: Instance? = o
			while node and node ~= list do
				local t = cardTools[node :: any]
				if t then target = t break end
				node = node.Parent
			end
			if target then break end
		end
	end
	if Hotbar.dragSource == "bag" then
		if target then Hotbar.moveInBag(tool, target) end
		return true
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and tool.Parent == player.Character then humanoid:UnequipTools() end
	Hotbar.stow(tool)
	if target then Hotbar.moveInBag(tool, target) end
	return true
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function() Hotbar.setBagOpen(panel.Visible) end) -- (D-1165)
Hotbar.changed.Event:Connect(function() task.defer(refresh) end)

local function setOpen(open: boolean, which: string?)
	panel.Visible = open
	if open then
		local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
		panel.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
		-- (D-1130: wider on PC for its 8 a row; room left below for the bar)
		panel.Size = UDim2.fromOffset(math.min(if PHONE then 408 else 760, vp.X - 24), math.min(400, vp.Y - TopBar.bottom() - 20 - (if PHONE then 70 else 76)))
		Popups.opened("Bag", function() panel.Visible = false end)
		showTab(which or tab)
	else
		Popups.closed("Bag")
	end
end
close.MouseButton1Click:Connect(function() setOpen(false) end)
itemsTab.MouseButton1Click:Connect(function() showTab("items") end)
photosTab.MouseButton1Click:Connect(function() showTab("photos") end)
deleteAll.MouseButton1Click:Connect(function()
	PhotoFlowUI.confirm(gui, "모든 사진을 삭제할까요?", "가방의 사진이 모두 지워지고 복구할 수 없어요.", "전체 삭제", function()
		local ok, message = invoke("DeleteAllPhotos", nil)
		if not ok and typeof(message) == "string" then hint.Text = message end
		if ok then task.spawn(refreshPhotos) end
	end)
end)
BagSignals.openBag.Event:Connect(function(which: any)
	setOpen(true, if which == "photos" then "photos" else "items")
end)
BagSignals.photosChanged.Event:Connect(function()
	if panel.Visible and tab == "photos" then task.spawn(refreshPhotos) end
end)

-- keep the window current while it is open
local function watch(container: Instance?)
	if not container then return end
	container.ChildAdded:Connect(function(c) if c:IsA("Tool") then task.defer(refresh) end end)
	container.ChildRemoved:Connect(function(c) if c:IsA("Tool") then task.defer(refresh) end end)
end
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) task.defer(refresh) end end)
watch(player:FindFirstChildOfClass("Backpack"))
player.CharacterAdded:Connect(watch)
watch(player.Character)

local button = Instance.new("TextButton")
button.Name = "BagButton"
button.BackgroundColor3 = Color3.new(0, 0, 0)
button.BackgroundTransparency = 0.2
button.Text = "🎒"
button.TextSize = 22
button.Font = Enum.Font.GothamBold
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = gui
corner(button, 22)
TopBar.icon(button, require(script.Parent:WaitForChild("Icons")).bag) -- (user mock-up 2026-10-30: a white shopping bag)
TopBar.add(button, 3)
button.MouseButton1Click:Connect(function() setOpen(not panel.Visible) end)
