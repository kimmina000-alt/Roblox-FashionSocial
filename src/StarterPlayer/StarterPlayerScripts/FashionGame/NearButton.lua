--!strict
-- (D-1539, user 2026-11-16: "튜토리얼에 특정 버튼 설명 혹은 눌러야 하는 경우 해당 버튼 근처에 설명창
-- 띄울 것") A card that explains a top bar button, or asks to press it, sits right under that
-- button with a little pointer up to it (TourController, FirstGoalController). The card's gui must
-- be IgnoreGuiInset (screen = AbsolutePosition + the top bar inset, D-1138).

local GuiService = game:GetService("GuiService")

local NearButton = {}

-- the pointer: a small square turned 45°, in the card's colour, on the card's top edge
function NearButton.pointer(card: Frame): Frame
	local p = Instance.new("Frame")
	p.Name = "NearPointer"
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Size = UDim2.fromOffset(16, 16)
	p.Rotation = 45
	p.BorderSizePixel = 0
	p.BackgroundColor3 = card.BackgroundColor3
	p.BackgroundTransparency = card.BackgroundTransparency
	p.ZIndex = card.ZIndex
	p.Visible = false
	p.Parent = card
	return p
end

-- puts `card` (AnchorPoint 0, 0) under `button`, `width` wide (narrower on a small screen), its
-- pointer under the button's middle. Call every frame while it shows (the bar can move).
function NearButton.place(card: Frame, pointer: Frame, button: GuiObject, width: number)
	local camera = workspace.CurrentCamera
	local screen = if camera then camera.ViewportSize else Vector2.new(800, 600)
	local inset = GuiService:GetGuiInset()
	local w = math.min(width, screen.X - 24)
	local middle = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	local x = math.clamp(middle - w / 2, 12, math.max(12, screen.X - 12 - w))
	local y = button.AbsolutePosition.Y + inset.Y + button.AbsoluteSize.Y + 14
	card.AnchorPoint = Vector2.zero
	card.Position = UDim2.fromOffset(x, y)
	card.Size = UDim2.fromOffset(w, card.Size.Y.Offset)
	pointer.Position = UDim2.fromOffset(math.clamp(middle - x, 18, w - 18), 0)
	pointer.Visible = true
end

return NearButton
