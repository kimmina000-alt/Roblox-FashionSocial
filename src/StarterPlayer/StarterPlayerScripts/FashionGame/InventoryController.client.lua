--!strict
-- 🎒 bag button in the top bar (user 2026-10-30): opens a window with every
-- item in the backpack and the one in hand. Tap an item to hold it, tap the
-- held one to put it away. (Roblox's own full inventory has no button on
-- phones, and no script can open it.)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))

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

local hint = Instance.new("TextLabel")
hint.Position = UDim2.fromOffset(16, 38)
hint.Size = UDim2.new(1, -32, 0, 18)
hint.BackgroundTransparency = 1
hint.Text = "누르면 손에 들어요 · 든 것을 다시 누르면 넣어요"
hint.TextColor3 = Color3.fromRGB(190, 190, 205)
hint.TextSize = 13
hint.Font = Enum.Font.GothamMedium
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = panel

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

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 64)
list.Size = UDim2.new(1, -24, 1, -76)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = PINK
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(88, 100)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

local empty = Instance.new("TextLabel")
empty.Position = UDim2.fromOffset(16, 90)
empty.Size = UDim2.new(1, -32, 0, 24)
empty.BackgroundTransparency = 1
empty.Text = "가방이 비어 있어요"
empty.TextColor3 = Color3.fromRGB(160, 160, 180)
empty.TextSize = 15
empty.Font = Enum.Font.GothamMedium
empty.Visible = false
empty.Parent = panel

-- the leading emoji of a tool name ("🎇 스파클러") as its picture
local function split(name: string): (string, string)
	local first, rest = string.match(name, "^(%S+)%s+(.+)$")
	-- (emoji start with byte F0 (🎇) or E2 (✨); Hangul is EA..ED)
	local b = first and string.byte(first, 1) or 0
	if first and (b >= 0xF0 or b == 0xE2) and utf8.len(first) and (utf8.len(first) :: number) <= 3 then
		return first, rest :: string
	end
	return "🎁", name
end

local function tools(): {Tool}
	local out = {}
	local character = player.Character
	local held = character and character:FindFirstChildOfClass("Tool")
	if held then table.insert(out, held) end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") then table.insert(out, t) end
		end
	end
	return out
end

local function refresh()
	if not panel.Visible then return end
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local items = tools()
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
		corner(cell, 12)
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = if held then PINK else Color3.fromRGB(70, 70, 95)
		s.Thickness = if held then 2 else 1
		s.Parent = cell
		local icon, name = split(tool.Name)
		-- the item itself in a little 3D window (its parts, nothing that runs)
		local look = Instance.new("Model")
		for _, d in ipairs(tool:GetChildren()) do
			if d:IsA("BasePart") or d:IsA("Model") then
				local c = d:Clone()
				for _, x in ipairs(c:GetDescendants()) do
					if x:IsA("LuaSourceContainer") or x:IsA("Sound") or x:IsA("ParticleEmitter") or x:IsA("Light")
						or x:IsA("JointInstance") or x:IsA("WeldConstraint") or x:IsA("GuiBase") then x:Destroy() end
				end
				c.Parent = look
			end
		end
		local visible = false
		for _, p in ipairs(look:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.95 then visible = true end
		end
		if tool.TextureId == "" and visible then
			local vp = Instance.new("ViewportFrame")
			vp.Position = UDim2.fromOffset(14, 4)
			vp.Size = UDim2.fromOffset(60, 60)
			vp.BackgroundTransparency = 1
			vp.Ambient = Color3.fromRGB(190, 190, 205)
			vp.LightDirection = Vector3.new(-0.4, -0.6, -1)
			vp.Parent = cell
			local world = Instance.new("WorldModel")
			world.Parent = vp
			look.Parent = world
			local cf, sz = look:GetBoundingBox()
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			local dist = math.max(sz.X, sz.Y, sz.Z) / 2 / math.tan(math.rad(15)) * 1.15
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.3, dist * 0.25, -dist), cf.Position)
			cam.Parent = vp
			vp.CurrentCamera = cam
		elseif tool.TextureId ~= "" then
			local img = Instance.new("ImageLabel")
			img.Position = UDim2.fromOffset(16, 6)
			img.Size = UDim2.fromOffset(56, 56)
			img.BackgroundTransparency = 1
			img.Image = tool.TextureId
			img.ScaleType = Enum.ScaleType.Fit
			img.Parent = cell
		else
			local e = Instance.new("TextLabel")
			e.Position = UDim2.fromOffset(16, 8)
			e.Size = UDim2.fromOffset(56, 50)
			e.BackgroundTransparency = 1
			e.Text = icon
			e.TextScaled = true
			e.Font = Enum.Font.GothamBold
			e.Parent = cell
		end
		local count = tool:GetAttribute("Count")
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromOffset(4, 64)
		l.Size = UDim2.new(1, -8, 0, 30)
		l.BackgroundTransparency = 1
		l.Text = name .. (if typeof(count) == "number" and count > 1 then (" ×" .. count) else "")
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextScaled = true
		l.TextWrapped = true
		l.Font = Enum.Font.GothamMedium
		l.Parent = cell
		Instance.new("UITextSizeConstraint", l).MaxTextSize = 13
		cell.MouseButton1Click:Connect(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			if tool.Parent == player.Character then
				humanoid:UnequipTools()
			elseif tool.Parent then
				humanoid:EquipTool(tool)
			end
			task.defer(refresh)
		end)
	end
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
		panel.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
		panel.Size = UDim2.fromOffset(math.min(408, vp.X - 24), math.min(340, vp.Y - TopBar.bottom() - 20))
		Popups.opened("Bag", function() panel.Visible = false end)
		refresh()
	else
		Popups.closed("Bag")
	end
end
close.MouseButton1Click:Connect(function() setOpen(false) end)

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
TopBar.add(button, 3)
button.MouseButton1Click:Connect(function() setOpen(not panel.Visible) end)
