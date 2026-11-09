--!strict
-- (D-1130) the hotbar at the bottom of the screen, in place of Roblox's own
-- (that one is turned off: it could not drop into the 🎒 bag). State and drag
-- in Hotbar.lua. Tap a slot = hold it / put it away; PC keys 1..9 the same;
-- drag a slot onto another = swap; drag it into the open bag = it goes into
-- the bag (out of the bar); a bag card dragged onto a slot comes into the bar.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Hotbar = require(script.Parent:WaitForChild("Hotbar"))

local PINK = Color3.fromRGB(255, 110, 180)

-- Roblox's hotbar off (it can fail while the core scripts are still loading)
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		if ok then break end
		task.wait(0.5)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FashionHotbar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -6)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

local cards: {[number]: TextButton} = {}

local function toggle(tool: Tool?)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not tool then return end
	if tool.Parent == player.Character then
		humanoid:UnequipTools()
	elseif tool.Parent then
		humanoid:EquipTool(tool)
	end
end

local function draw()
	local n = Hotbar.count()
	local size = if n <= 4 then 58 else 60
	bar.Size = UDim2.fromOffset(n * size + (n - 1) * 6, size)
	-- the bar shows while there is any item at all (in it or in the bag), with
	-- its empty slots faint, so a bag card always has somewhere to go
	local any = player.Character ~= nil and player.Character:FindFirstChildOfClass("Tool") ~= nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not any and backpack then any = backpack:FindFirstChildOfClass("Tool") ~= nil end
	bar.Visible = any
	for i = 1, math.max(n, #cards) do
		local card = cards[i]
		if i > n then
			if card then card:Destroy() cards[i] = nil end
			continue
		end
		if not card then
			local c = Instance.new("TextButton")
			c.Name = "Slot" .. i
			c.LayoutOrder = i
			c.Text = ""
			c.AutoButtonColor = true
			c.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
			c.BackgroundTransparency = 0.15
			c.Parent = bar
			Instance.new("UICorner", c).CornerRadius = UDim.new(0, 10)
			local s = Instance.new("UIStroke")
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Parent = c
			local index = i
			Hotbar.pressable(c, function() return Hotbar.get(index) end, function() toggle(Hotbar.get(index)) end, true)
			cards[i] = c
			card = c
		end
		local slot = card :: TextButton
		slot.Size = UDim2.fromOffset(size, size)
		for _, ch in ipairs(slot:GetChildren()) do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		local tool = Hotbar.get(i)
		slot.BackgroundTransparency = if tool then 0.15 else 0.6
		local stroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
		local held = tool ~= nil and tool.Parent == player.Character
		stroke.Color = if held then PINK else Color3.fromRGB(80, 80, 105)
		stroke.Thickness = if held then 2 else 1
		if tool then
			local emoji, name = Hotbar.split(tool.Name)
			Hotbar.look(tool, slot, emoji, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.5, 0.04))
			local l = Instance.new("TextLabel")
			l.Position = UDim2.fromScale(0.04, 0.64)
			l.Size = UDim2.fromScale(0.92, 0.33)
			l.BackgroundTransparency = 1
			l.Text = name
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextScaled = true
			l.TextTruncate = Enum.TextTruncate.AtEnd
			l.Font = Enum.Font.GothamMedium
			l.Parent = slot
			Instance.new("UITextSizeConstraint", l).MaxTextSize = 11
			if n > 4 then
				local k = Instance.new("TextLabel")
				k.Position = UDim2.fromOffset(4, 2)
				k.Size = UDim2.fromOffset(12, 12)
				k.BackgroundTransparency = 1
				k.Text = tostring(i)
				k.TextColor3 = Color3.fromRGB(200, 200, 215)
				k.TextSize = 11
				k.Font = Enum.Font.GothamBold
				k.Parent = slot
			end
		end
	end
end

-- a drop on a slot: into the bar there (a swap when it came from another slot)
Hotbar.addZone(bar, function(tool: Tool, at: Vector2): boolean
	for i, c in pairs(cards) do
		local a, s = c.AbsolutePosition, c.AbsoluteSize
		if at.X >= a.X - 3 and at.X <= a.X + s.X + 3 and at.Y >= a.Y - 10 and at.Y <= a.Y + s.Y + 10 then
			Hotbar.place(tool, i)
			return true
		end
	end
	return false
end)

Hotbar.changed.Event:Connect(draw)

local function watch(container: Instance?)
	if not container then return end
	for _, t in ipairs(container:GetChildren()) do
		if t:IsA("Tool") then Hotbar.adopt(t) end
	end
	container.ChildAdded:Connect(function(t)
		if t:IsA("Tool") then Hotbar.adopt(t) task.defer(draw) end
	end)
	container.ChildRemoved:Connect(function(t)
		if t:IsA("Tool") then
			task.defer(function()
				local backpack = player:FindFirstChildOfClass("Backpack")
				if t.Parent ~= backpack and t.Parent ~= player.Character then Hotbar.forget(t) end
				draw()
			end)
		end
	end)
end
watch(player:FindFirstChildOfClass("Backpack"))
watch(player.Character)
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) draw() end end)
player.CharacterAdded:Connect(function(c) watch(c) draw() end)

-- PC: number keys 1..9
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local n = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
	if n >= 1 and n <= 9 and n <= Hotbar.count() then toggle(Hotbar.get(n)) end
end)

draw()
