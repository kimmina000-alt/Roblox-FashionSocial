--!strict
-- Round buttons in the top bar. Each script adds its button with an order
-- number; this file decides the side and the place (hidden buttons leave no
-- gap).
-- (user 2026-10-30, later) left group, right after Roblox's own buttons and
-- moving with them (the voice chat button comes and goes): 🏠 home 0,
-- catalog (hanger) 4, 🎒 3, 🖼 album 2, then 💃 1 (not in the user's list:
-- kept at the end of the left group). Right group, ending at the right edge:
-- 💰 coins 10, 💝 5.
-- A button with attribute Width (number, px at full size) is that wide.

local GuiService = game:GetService("GuiService")

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

local function layout()
	local inset = GuiService.TopbarInset
	-- (fallbacks when Roblox gives no inset: its row, the left group past the
	-- Roblox logo + menu / chat pill)
	local centerY, leftX, rightX, size = 34, 170, -16, 44
	if inset.Height > 0 then
		centerY = inset.Min.Y + inset.Height / 2
		size = math.clamp(inset.Height - 12, 32, 44)
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
	for _, entry in ipairs(entries) do
		if entry.button.Visible then
			local wide = entry.button:GetAttribute("Width")
			local width = if typeof(wide) == "number" then math.floor(wide * size / 44) else size
			entry.button.Size = UDim2.fromOffset(width, size)
			if slot(entry).side == "left" then
				entry.button.AnchorPoint = Vector2.new(0, 0.5)
				entry.button.Position = UDim2.new(0, leftX, 0, centerY)
				leftX += width + 8
			else
				entry.button.AnchorPoint = Vector2.new(1, 0.5)
				entry.button.Position = UDim2.new(1, rightX, 0, centerY)
				rightX -= width + 8
			end
		end
	end
end

-- Bottom edge (px, IgnoreGuiInset space) of the button row. Popups start
-- below it (user, 2026-10-22: popups covered the buttons on phones, where the
-- Roblox top-bar inset can be 0 and the buttons use the fallback row).
function TopBar.bottom(): number
	local inset = GuiService.TopbarInset
	if inset.Height > 0 then
		local size = math.clamp(inset.Height - 12, 32, 44)
		return math.max(inset.Min.Y + inset.Height / 2 + size / 2, inset.Max.Y)
	end
	return 34 + 44 / 2
end

function TopBar.add(button: GuiObject, order: number)
	table.insert(entries, { button = button, order = order })
	button:GetPropertyChangedSignal("Visible"):Connect(layout)
	layout()
end

GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

return TopBar
