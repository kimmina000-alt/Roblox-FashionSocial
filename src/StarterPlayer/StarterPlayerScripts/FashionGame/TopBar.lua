--!strict
-- Round buttons in the top bar. Each script adds its button with an order
-- number; this file decides the side and the place (hidden buttons leave no
-- gap).
-- (user 2026-10-30, later) left group, right after Roblox's own buttons and
-- moving with them (the voice chat button comes and goes): catalog (hanger)
-- 4, 🎒 3 (photos inside), 🎵 dance 1. (🏠 0 and the 🖼 album 2 are gone.)
-- Right group, ending at the right edge: 💰 coins 10, 💝 5.
-- (user mock-up 2026-10-30) the left group sits in one dark pill like
-- Roblox's own, its buttons are white icons without their own circles.
-- A button with attribute Width (number, px at full size) is that wide;
-- attribute Scale shrinks it (width and height) on the same centre line.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local TopBar = {}

-- order → side and place (1 = nearest that side's edge)
local SLOTS: {[number]: { side: string, place: number }} = {
	[0] = { side = "left", place = 1 },
	[4] = { side = "left", place = 2 },
	[3] = { side = "left", place = 3 },
	[2] = { side = "left", place = 4 },
	[1] = { side = "left", place = 5 },
	[5] = { side = "right", place = 1 },
	[10] = { side = "right", place = 2 },
}

local entries: {{ button: GuiObject, order: number }} = {}

-- the pill behind the left group (its own ScreenGui, under every button's)
local pillGui = Instance.new("ScreenGui")
pillGui.Name = "FashionTopBarPill"
pillGui.ResetOnSpawn = false
pillGui.IgnoreGuiInset = true
pillGui.DisplayOrder = 5
pillGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local pill = Instance.new("Frame")
pill.Name = "LeftPill"
pill.AnchorPoint = Vector2.new(0, 0.5)
pill.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
pill.BackgroundTransparency = 0.5 -- (50 %, user 2026-10-30)
pill.Visible = false
pill.Parent = pillGui
Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

local function layout()
	local inset = GuiService.TopbarInset
	-- (fallbacks when Roblox gives no inset: its row, the left group past the
	-- Roblox logo + menu / chat pill)
	local centerY, leftX, rightX, size = 34, 170, -16, 44
	if inset.Height > 0 then
		-- Roblox's own buttons hang 12 px from the top of the bar (not in its
		-- middle): the same line (user 2026-10-30: ours sat higher)
		size = math.clamp(inset.Height - 12, 32, 44)
		centerY = inset.Min.Y + 12 + size / 2
		local camera = workspace.CurrentCamera
		if camera and inset.Width > 0 then
			leftX = inset.Min.X + 8
			rightX = -(camera.ViewportSize.X - inset.Max.X) - 8
		end
	end
	local function slot(entry): { side: string, place: number }
		return SLOTS[entry.order] or { side = "right", place = 100 + entry.order }
	end
	table.sort(entries, function(a, b) return slot(a).place < slot(b).place end)
	local pillStart, PAD, GAP = leftX, 6, 2
	leftX += PAD
	local anyLeft = false
	for _, entry in ipairs(entries) do
		if entry.button.Visible then
			local wide = entry.button:GetAttribute("Width")
			local width = if typeof(wide) == "number" then math.floor(wide * size / 44) else size
			-- attribute Scale: a smaller button on the same centre line (the coin pill, 2/3)
			local k = entry.button:GetAttribute("Scale")
			local height = size
			if typeof(k) == "number" then width, height = math.floor(width * k), math.floor(size * k) end
			entry.button.Size = UDim2.fromOffset(width, height)
			if slot(entry).side == "left" then
				entry.button.AnchorPoint = Vector2.new(0, 0.5)
				entry.button.Position = UDim2.new(0, leftX, 0, centerY)
				entry.button.BackgroundTransparency = 1
				leftX += width + GAP
				anyLeft = true
			else
				entry.button.AnchorPoint = Vector2.new(1, 0.5)
				entry.button.Position = UDim2.new(1, rightX, 0, centerY)
				rightX -= width + 8
			end
		end
	end
	pill.Visible = anyLeft
	pill.Position = UDim2.new(0, pillStart, 0, centerY)
	pill.Size = UDim2.fromOffset(leftX - GAP + PAD - pillStart, size)
end

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

GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

return TopBar
