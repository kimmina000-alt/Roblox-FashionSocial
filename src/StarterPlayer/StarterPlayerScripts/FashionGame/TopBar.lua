--!strict
-- Round buttons in the top bar, left of the catalog "C" button. Each script
-- adds its button with an order (1 = right next to C); hidden buttons leave
-- no gap. Order: 🏠 0 (spawn), 💃 1, 🎵 2, 📷 3, 🪙 coins 10.
-- A button with attribute Width (number, px at full size) is that wide.

local GuiService = game:GetService("GuiService")

local TopBar = {}

local entries: {{ button: GuiObject, order: number }} = {}

local function layout()
	local inset = GuiService.TopbarInset
	local centerY, rightX, size = 34, -16, 44
	if inset.Height > 0 then
		centerY = inset.Min.Y + inset.Height / 2
		size = math.clamp(inset.Height - 12, 32, 44)
		local camera = workspace.CurrentCamera
		if camera and inset.Width > 0 then
			rightX = -(camera.ViewportSize.X - inset.Max.X) - 8
		end
	end
	table.sort(entries, function(a, b) return a.order < b.order end)
	local x = rightX - size - 8
	for _, entry in ipairs(entries) do
		if entry.button.Visible then
			local wide = entry.button:GetAttribute("Width")
			local width = if typeof(wide) == "number" then math.floor(wide * size / 44) else size
			entry.button.Size = UDim2.fromOffset(width, size)
			entry.button.Position = UDim2.new(1, x, 0, centerY)
			x -= width + 8
		end
	end
end

function TopBar.add(button: GuiObject, order: number)
	button.AnchorPoint = Vector2.new(1, 0.5)
	table.insert(entries, { button = button, order = order })
	button:GetPropertyChangedSignal("Visible"):Connect(layout)
	layout()
end

GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

return TopBar
