--!strict
-- Our buttons in the top bar. Each script adds its button with an order
-- number; this file decides the place (hidden buttons leave no gap).
-- (user mock-up 2026-10-30, rev 2) everything sits at the top right, small:
--   [₩ coins 10] [♥ give 5] [⋯ more]
-- and ⋯ opens a narrow dark pill below itself with the menu buttons:
--   catalog (hanger) 4, 🎒 3 (photos inside), 🎵 dance 1.
-- Sizes measured on the user's mock-up against Roblox's own 44 px buttons:
-- round buttons 25 px (0.57), the coin pill 18 px high and 45 wide, the
-- menu pill 24 px wide with 24 px rows and 13 px icons; the row's top is
-- 4 px below the top of Roblox's buttons, 19 px from the right edge.
-- (user 2026-10-31) everything 1.5x (too small on phones), ⋯ became a ☰
-- of three bars, and a clock (HudController, order 11) left of the coins.
-- A button with attribute Width (number, px) is that wide; attribute Height
-- (px) makes it lower than the round buttons, on the same centre line;
-- attribute GapLeft (px) is the space left of it (the coin pill's ₩ hangs there).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local TopBar = {}

local SMALL = 38 -- round button (25 x 1.5)
local ROW_GAP = 9 -- between ♥ and ☰
local PILL_GAP = 18 -- between the coin pill and ♥
local MENU_W, MENU_ROW, MENU_PAD = 36, 36, 6 -- (54 for a moment on 2026-10-31, back: darker instead)
TopBar.Scale = 1.5 -- (for the pieces other scripts size: coin pill, clock)

-- order → right row place (1 = nearest the edge); menu orders → menu row
local RIGHT: {[number]: number} = { [20] = 1, [5] = 2, [10] = 3, [11] = 4 }
local MENU: {[number]: number} = { [4] = 1, [3] = 2, [1] = 3 }

local entries: {{ button: GuiObject, order: number }} = {}
local open = false

local gui = Instance.new("ScreenGui")
gui.Name = "FashionTopBarMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- the dark pill behind the menu buttons (under every button's own ScreenGui)
local pill = Instance.new("Frame")
pill.Name = "MenuPill"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
-- (50 % on 2026-10-30; 2026-10-31: darker, with a thin white edge, so the
-- white icons stand out on bright places like the pink 오후네컷 wall)
pill.BackgroundTransparency = 0.15
do
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Transparency = 0.7
	edge.Thickness = 1
	edge.Parent = pill
end
pill.Visible = false
pill.Parent = gui
Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

-- ⋯ more
local moreGui = Instance.new("ScreenGui")
moreGui.Name = "FashionTopBarMore"
moreGui.ResetOnSpawn = false
moreGui.IgnoreGuiInset = true
moreGui.DisplayOrder = 30
moreGui.Parent = gui.Parent
local more = Instance.new("TextButton")
more.Name = "MoreButton"
more.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
more.BackgroundTransparency = 0.5
more.Text = ""
more.AutoButtonColor = true
more.Parent = moreGui
Instance.new("UICorner", more).CornerRadius = UDim.new(1, 0)

local layout: () -> ()

local function row(): (number, number, number)
	-- centre line, right edge offset, Roblox button size
	local inset = GuiService.TopbarInset
	if inset.Height > 0 then
		local size = math.clamp(inset.Height - 12, 32, 44)
		local camera = workspace.CurrentCamera
		local right = -19
		if camera and inset.Width > 0 then
			right = math.min(-8, -(camera.ViewportSize.X - inset.Max.X) + 20)
		end
		-- Roblox's own buttons hang 12 px from the top of the bar: the same centre line
		return inset.Min.Y + 12 + size / 2, right, size
	end
	return 28, -16, 44
end

layout = function()
	local centerY, rightX = row()
	local function sorted(map: {[number]: number})
		local list = {}
		for _, entry in ipairs(entries) do
			if map[entry.order] and entry.button.Visible then table.insert(list, entry) end
		end
		table.sort(list, function(a, b) return map[a.order] < map[b.order] end)
		return list
	end
	-- right row
	local x = rightX
	local moreX = 0
	for i, entry in ipairs(sorted(RIGHT)) do
		local b = entry.button
		local wide = b:GetAttribute("Width")
		local high = b:GetAttribute("Height")
		local w = if typeof(wide) == "number" then wide else SMALL
		local h = if typeof(high) == "number" then high else SMALL
		b.Size = UDim2.fromOffset(w, h)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, x, 0, centerY)
		-- (the menu is wider than ☰ since 2026-10-31: its right edge lines up with ☰'s)
		if entry.order == 20 then moreX = x - MENU_W / 2 end
		local gap = b:GetAttribute("GapLeft")
		x -= w + (if typeof(gap) == "number" then gap elseif i == 1 then ROW_GAP else PILL_GAP)
	end
	-- menu below ⋯
	local items = sorted(MENU)
	local top = centerY + SMALL / 2 + 6
	pill.Visible = open and #items > 0
	pill.Position = UDim2.new(1, moreX, 0, top)
	pill.Size = UDim2.fromOffset(MENU_W, #items * MENU_ROW + MENU_PAD * 2)
	for i, entry in ipairs(items) do
		local b = entry.button
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(MENU_W, MENU_ROW)
		local icon = b:FindFirstChild("Icon")
		if icon and icon:IsA("GuiObject") then icon.Size = UDim2.fromScale(0.6, 0.6) end -- (22 px)
		b.Position = if open
			then UDim2.new(1, moreX, 0, top + MENU_PAD + (i - 0.5) * MENU_ROW)
			else UDim2.fromOffset(-1000, -1000) -- closed: out of sight
	end
end

function TopBar.setOpen(on: boolean)
	open = on
	layout()
end

more.MouseButton1Click:Connect(function() TopBar.setOpen(not open) end)

-- Bottom edge (px, IgnoreGuiInset space) of the button row. Popups start
-- below it (user, 2026-10-22: popups covered the buttons on phones, where the
-- Roblox top-bar inset can be 0 and the buttons use the fallback row).
function TopBar.bottom(): number
	local inset = GuiService.TopbarInset
	if inset.Height > 0 then
		local size = math.clamp(inset.Height - 12, 32, 44)
		return math.max(inset.Min.Y + 12 + size, inset.Max.Y)
	end
	return 34 + 44 / 2
end

function TopBar.add(button: GuiObject, order: number)
	table.insert(entries, { button = button, order = order })
	button:GetPropertyChangedSignal("Visible"):Connect(layout)
	-- a menu button closes the menu when it is used
	if MENU[order] and button:IsA("GuiButton") then
		(button :: GuiButton).Activated:Connect(function()
			task.defer(TopBar.setOpen, false)
		end)
	end
	layout()
end

-- a white icon in the middle of a top bar button (its text cleared)
function TopBar.icon(button: GuiObject, image: string, scale: number?)
	if button:IsA("TextButton") or button:IsA("TextLabel") then (button :: any).Text = "" end
	local old = button:FindFirstChild("Icon")
	if old then old:Destroy() end
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(scale or 0.6, scale or 0.6)
	icon.BackgroundTransparency = 1
	icon.Image = image
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = button
	return icon
end

-- ☰: three white bars, drawn (sharper than an image at this size; user 2026-10-31,
-- the ⋯ dots were hard to see)
for i = -1, 1 do
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5 + i * 0.17)
	bar.Size = UDim2.fromScale(0.48, 0.075)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = more
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end
TopBar.add(more, 20)

GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

return TopBar
