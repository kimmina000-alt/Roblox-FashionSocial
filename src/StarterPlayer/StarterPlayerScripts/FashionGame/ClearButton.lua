--!strict
-- A small ✕ inside a TextBox that empties it at once (D-1049, user 2026-11-09:
-- "검색 필터에 엑스 넣어 줘. 검색어 바로 지울 수 있게."). It shows only while
-- the box has text, sits at the right end of the box (a child of it, so it
-- follows every layout change of the catalog), and the text keeps clear of it.
-- onClear runs after the box is emptied (the catalog search runs again).

local ClearButton = {}

function ClearButton.attach(box: TextBox, onClear: (() -> ())?): TextButton
	local pad = box:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 26)
	pad.Parent = box
	local x = Instance.new("TextButton")
	x.Name = "ClearText"
	x.AnchorPoint = Vector2.new(1, 0.5)
	-- (the padding moves children too: put it back out into the padded strip)
	x.Position = UDim2.new(1, 24, 0.5, 0)
	x.Size = UDim2.fromOffset(20, 20)
	x.BackgroundColor3 = Color3.fromRGB(90, 90, 104)
	x.BackgroundTransparency = 0.2
	x.AutoButtonColor = true
	-- (Gotham has no ✕: it showed as an empty box; × like the catalog's close button)
	x.Text = "×"
	x.TextColor3 = Color3.new(1, 1, 1)
	x.TextSize = 18
	x.Font = Enum.Font.GothamBold
	x.ZIndex = box.ZIndex + 1
	x.Visible = box.Text ~= ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = x
	x.Parent = box
	box:GetPropertyChangedSignal("Text"):Connect(function()
		x.Visible = box.Text ~= ""
	end)
	box:GetPropertyChangedSignal("ZIndex"):Connect(function()
		x.ZIndex = box.ZIndex + 1
	end)
	x.Activated:Connect(function()
		box.Text = ""
		if onClear then onClear() end
	end)
	return x
end

return ClearButton
