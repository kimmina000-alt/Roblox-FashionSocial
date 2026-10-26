--!strict
-- One button per club table (user 2026-10-26: 병 놓기 / 불꽃 / 컵에 따르기 /
-- 치우기 for every bottle piled up and nothing could be read). Every prompt on
-- a DrinkTable and on what stands on it (bottles, buckets) is drawn by nobody
-- here (Style Custom, set locally; it still works), and one local prompt
-- "🍾 테이블" opens a small menu of the actions that are in reach right now.
-- A button runs that prompt as if it was pressed.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Popups = require(script.Parent:WaitForChild("Popups"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local MENU_PROMPT = "TableMenuPrompt"

-- prompts of each table that are in reach (shown) at the moment
local shown: {[ProximityPrompt]: boolean} = {}
local tableOf: {[ProximityPrompt]: BasePart} = {}

local keyIndex = 0
local function hidePrompt(prompt: Instance, tablePart: BasePart)
	if not prompt:IsA("ProximityPrompt") or prompt.Name == MENU_PROMPT then return end
	prompt.Style = Enum.ProximityPromptStyle.Custom
	-- (a hidden prompt still answers its key: E poured a cup instead of opening
	-- the menu. Each one gets its own unused key: on a shared key, running one
	-- from the menu ran the others too)
	keyIndex = (keyIndex + 1) % 96
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)["World" .. keyIndex]
	prompt.GamepadKeyCode = Enum.KeyCode.Unknown
	-- (all on the same key, only one of them would count as shown)
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	tableOf[prompt] = tablePart
end

local function addTable(tablePart: Instance)
	if not tablePart:IsA("BasePart") or tablePart:FindFirstChild(MENU_PROMPT) then return end
	for _, d in ipairs(tablePart:GetDescendants()) do hidePrompt(d, tablePart) end
	tablePart.DescendantAdded:Connect(function(d) hidePrompt(d, tablePart) end)
	local menu = Instance.new("ProximityPrompt")
	menu.Name = MENU_PROMPT
	menu.ActionText = "🍾 테이블"
	menu.ObjectText = "병 놓기 · 따르기 · 불꽃"
	menu.MaxActivationDistance = 10
	menu.RequiresLineOfSight = false
	menu.Parent = tablePart
end

for _, t in ipairs(CollectionService:GetTagged("DrinkTable")) do addTable(t) end
CollectionService:GetInstanceAddedSignal("DrinkTable"):Connect(addTable)

ProximityPromptService.PromptShown:Connect(function(prompt)
	if tableOf[prompt] then shown[prompt] = true end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shown[prompt] = nil
end)

--------------------------------------------------
-- Menu
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TableMenuGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 41
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Menu"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(24, 20, 32)
panel.BackgroundTransparency = 0.05
panel.Size = UDim2.fromOffset(250, 60)
panel.Visible = false
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 110, 170)
stroke.Thickness = 2
stroke.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = panel

local openTable: BasePart? = nil

local function close()
	panel.Visible = false
	openTable = nil
	Popups.closed("TableMenu")
end

local function button(text: string, order: number, color: Color3, onClick: () -> ())
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 38)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Text = text
	b.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	b.MouseButton1Click:Connect(onClick)
end

local function run(prompt: ProximityPrompt)
	close()
	if not prompt.Parent or not prompt.Enabled then return end
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.05)
	prompt:InputHoldEnd()
end

local function open(tablePart: BasePart)
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	-- what can be done here now: the table's own prompts first, then the ones
	-- on the bottles / buckets standing on it
	local list = {}
	for prompt in pairs(shown) do
		if tableOf[prompt] == tablePart and prompt.Parent and prompt.Enabled then table.insert(list, prompt) end
	end
	table.sort(list, function(a, b)
		local aOwn, bOwn = a.Parent == tablePart, b.Parent == tablePart
		if aOwn ~= bOwn then return aOwn end
		return (a.ObjectText .. a.ActionText) < (b.ObjectText .. b.ActionText)
	end)
	for i, prompt in ipairs(list) do
		local label = if prompt.Parent == tablePart then prompt.ActionText else prompt.ObjectText .. " · " .. prompt.ActionText
		button(label, i, Color3.fromRGB(70, 60, 90), function() task.spawn(run, prompt) end)
	end
	if #list == 0 then
		button("지금 할 수 있는 게 없어요", 1, Color3.fromRGB(50, 46, 60), close)
	end
	button("닫기", 100, Color3.fromRGB(44, 42, 54), close)
	local count = #list + 1 + (if #list == 0 then 1 else 0)
	panel.Size = UDim2.fromOffset(250, 16 + count * 44)
	panel.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 10)
	panel.Visible = true
	openTable = tablePart
	Popups.opened("TableMenu", close)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= MENU_PROMPT then return end
	local tablePart = prompt.Parent
	if tablePart and tablePart:IsA("BasePart") then open(tablePart) end
end)

-- walking away closes it
RunService.Heartbeat:Connect(function()
	local t = openTable
	if not t then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not t.Parent or not root or not root:IsA("BasePart") or (root.Position - t.Position).Magnitude > 16 then close() end
end)
