--!strict
-- (D-1133) the trash can window (TrashConfig / TrashService): "열기" on a can
-- shows what is in that can (tap = take it out) and what you carry that may
-- go in (tap = throw it in). Black and white like the feedback window.
-- (D-1270, user 2026-11-11: "아이템 들고 쓰레기통 누르면 버리기 / 쓰레기통 안에 텍스트 지우고
-- 쓰레기통 안에 있는 아이템만 보이게 해. 버릴 수 있는 물건 보이는 거 삭제.") holding
-- something that may go in, the can's 열기 throws it straight in; the window
-- shows only the items in the can (no title, no lines, no "내 물건" list)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local TrashConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("TrashConfig"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local Hotbar = require(script.Parent:WaitForChild("Hotbar"))

local PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local COLS = if PHONE then 4 else 8

local gui = Instance.new("ScreenGui")
gui.Name = "TrashGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 32
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(o: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = o
end

local panel = Instance.new("Frame")
panel.Name = "Trash"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
panel.Visible = false
panel.Parent = gui
corner(panel, 16)
do
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Thickness = 2
	s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -60, 0, 28)
title.BackgroundTransparency = 1
title.Text = "🗑 쓰레기통"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(30, 30)
close.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 15
close.Parent = panel
corner(close, 15)

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 40)
status.Size = UDim2.new(1, -32, 0, 18)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = Color3.fromRGB(200, 200, 205)
status.TextSize = 13
status.Font = Enum.Font.GothamMedium
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = panel

local function section(text: string): (TextLabel, ScrollingFrame)
	local h = Instance.new("TextLabel")
	h.BackgroundTransparency = 1
	h.Text = text
	h.TextColor3 = Color3.new(1, 1, 1)
	h.TextSize = 14
	h.Font = Enum.Font.GothamBold
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Parent = panel
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / COLS, -8, 0, 100)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 88 / 100
	ratio.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = list
	return h, list
end
local inHead, inList = section("쓰레기통 안 · 누르면 가져가요")
local mineHead, mineList = section("내 물건 · 누르면 버려요")
-- (D-1270) only the items in the can
title.Visible = false
inHead.Visible = false
mineHead.Visible = false
mineList.Visible = false

local openCan: BasePart? = nil
local remote: RemoteFunction? = nil

local function card(list: ScrollingFrame, tool: Tool, order: number, sub: string?, onTap: () -> ())
	local c = Instance.new("TextButton")
	c.LayoutOrder = order
	c.Text = ""
	c.AutoButtonColor = true
	c.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
	c.Parent = list
	corner(c, 12)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = Color3.fromRGB(90, 90, 96)
	s.Parent = c
	local emoji, name = Hotbar.split(tool.Name)
	Hotbar.look(tool, c, emoji, UDim2.fromScale(0.62, 0.56), UDim2.fromScale(0.5, 0.03))
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromScale(0.05, if sub then 0.58 else 0.64)
	l.Size = UDim2.fromScale(0.9, if sub then 0.24 else 0.3)
	l.BackgroundTransparency = 1
	l.Text = name
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.TextWrapped = true
	l.Font = Enum.Font.GothamMedium
	l.Parent = c
	Instance.new("UITextSizeConstraint", l).MaxTextSize = 13
	if sub then
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale(0.05, 0.82)
		t.Size = UDim2.fromScale(0.9, 0.15)
		t.BackgroundTransparency = 1
		t.Text = sub
		t.TextColor3 = Color3.fromRGB(170, 170, 178)
		t.TextScaled = true
		t.Font = Enum.Font.Gotham
		t.Parent = c
		Instance.new("UITextSizeConstraint", t).MaxTextSize = 11
	end
	c.Activated:Connect(onTap)
end

local function layout()
	local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
	local w = math.min(if PHONE then 408 else 760, vp.X - 24)
	local h = math.min(430, vp.Y - TopBar.bottom() - 20)
	panel.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
	panel.Size = UDim2.fromOffset(w, h)
	local half = (h - 64 - 2 * 22) / 2
	inHead.Position = UDim2.fromOffset(16, 62)
	inHead.Size = UDim2.new(1, -32, 0, 20)
	-- (D-1270) the items fill the window under the X (and the status line)
	inList.Position = UDim2.fromOffset(12, 48)
	inList.Size = UDim2.new(1, -24, 1, -60)
	mineHead.Position = UDim2.fromOffset(16, 84 + half + 4)
	mineHead.Size = UDim2.new(1, -32, 0, 20)
	mineList.Position = UDim2.fromOffset(12, 84 + half + 26)
	mineList.Size = UDim2.new(1, -24, 0, half - 4)
end

local function ago(at: any): string
	if typeof(at) ~= "number" then return "" end
	local left = math.max(0, TrashConfig.KeepSeconds - (os.time() - at))
	return string.format("%d분 남음", math.ceil(left / 60))
end

local function call(action: string, thing: Instance)
	local can = openCan
	if not can or not remote then return end
	local ok, okay, message = pcall(function() return (remote :: RemoteFunction):InvokeServer(action, can, thing) end)
	if not ok then status.Text = "잠시 후 다시 시도하세요." return end
	status.Text = if typeof(message) == "string" then message elseif okay then "" else "할 수 없어요."
end

local function refresh()
	local can = openCan
	if not can then return end
	for _, l in ipairs({ inList, mineList }) do
		for _, c in ipairs(l:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	end
	local folder = FashionGame:FindFirstChild("Trash") and FashionGame.Trash:FindFirstChild(can:GetAttribute("TrashCan") :: string)
	local items = if folder then folder:GetChildren() else {}
	table.sort(items, function(a, b) return ((a:GetAttribute("TrashedAt") :: number?) or 0) > ((b:GetAttribute("TrashedAt") :: number?) or 0) end)
	inHead.Text = string.format("쓰레기통 안 %d개 · 누르면 가져가요 (1시간 뒤 사라져요)", #items)
	for i, item in ipairs(items) do
		if item:IsA("Tool") then
			card(inList, item, i, nil, function() call("Take", item) end)
		end
	end
	local mine = {}
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if held and TrashConfig.canThrow(held) then table.insert(mine, held) end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and TrashConfig.canThrow(t) then table.insert(mine, t) end
		end
	end
	mineHead.Text = if #mine > 0 then "내 물건 · 누르면 버려요" else "버릴 수 있는 물건이 없어요 (음식 · 음료 · 스파클러)"
	for i, t in ipairs(mine) do
		card(mineList, t, i, nil, function() call("Throw", t) end)
	end
end

local revConn: RBXScriptConnection? = nil
local function setOpen(can: BasePart?)
	if revConn then revConn:Disconnect() revConn = nil end
	openCan = can
	panel.Visible = can ~= nil
	if can then
		remote = remote or FashionGame:WaitForChild("Remotes"):WaitForChild("Trash", 5) :: RemoteFunction?
		status.Text = ""
		layout()
		Popups.opened("Trash", function()
			-- (another window opened: just hide)
			if revConn then revConn:Disconnect() revConn = nil end
			openCan = nil
			panel.Visible = false
		end)
		revConn = can:GetAttributeChangedSignal("TrashRev"):Connect(function() task.defer(refresh) end)
		refresh()
	else
		Popups.closed("Trash")
	end
end
close.Activated:Connect(function() setOpen(nil) end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "TrashPrompt" then return end
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then return end
	-- (D-1270) something in the hand that may go in: straight into the can
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if held and TrashConfig.canThrow(held) then
		remote = remote or FashionGame:WaitForChild("Remotes"):WaitForChild("Trash", 5) :: RemoteFunction?
		if remote then
			pcall(function() return (remote :: RemoteFunction):InvokeServer("Throw", part, held) end)
		end
		return
	end
	setOpen(part)
end)

-- my things changed: the list follows; walked away: closed
local function watch(container: Instance?)
	if not container then return end
	container.ChildAdded:Connect(function(c) if c:IsA("Tool") and openCan then task.defer(refresh) end end)
	container.ChildRemoved:Connect(function(c) if c:IsA("Tool") and openCan then task.defer(refresh) end end)
end
watch(player:FindFirstChildOfClass("Backpack"))
watch(player.Character)
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) end end)
player.CharacterAdded:Connect(watch)
task.spawn(function()
	while true do
		task.wait(0.5)
		local can = openCan
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if can and (not root or (root.Position - can.Position).Magnitude > TrashConfig.Distance + 6) then setOpen(nil) end
	end
end)
