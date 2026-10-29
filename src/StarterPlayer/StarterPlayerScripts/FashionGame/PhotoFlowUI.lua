--!strict
-- 인생네컷 flow look (user mock-up 2026-10-30,
-- docs/04_ART/references/photo_ui_redesign_2026-10-30.png): the window header
-- (a pink icon square, a left-aligned title and subtitle), the divider
-- between the shots and the strip, the "사진이 저장되었어요!" panel, the
-- confirm dialog and the 내 앨범 cards. Kept out of PhotoBoothController
-- (local register limit).

local PhotoFlowUI = {}

PhotoFlowUI.COLORS = {
	card = Color3.fromRGB(44, 42, 54),
	cardDark = Color3.fromRGB(34, 32, 44),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	pink = Color3.fromRGB(255, 110, 170),
	yellow = Color3.fromRGB(255, 214, 90),
	danger = Color3.fromRGB(220, 80, 95),
}
local C = PhotoFlowUI.COLORS

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- The pink icon square at a window's top-left (34 × 34 at 12, 10).
function PhotoFlowUI.icon(parent: GuiObject, glyph: string, zIndex: number): TextLabel
	local old = parent:FindFirstChild("HeaderIcon")
	if old then old:Destroy() end
	local box = make("TextLabel", {
		Name = "HeaderIcon",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.pink,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = C.text,
		Text = glyph,
		ZIndex = zIndex,
	}, parent)
	round(box, 9)
	return box
end

-- A title + subtitle pair placed right of the icon, left-aligned.
function PhotoFlowUI.placeHeader(title: TextLabel, sub: TextLabel, width: number)
	title.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(56, 8)
	title.Size = UDim2.fromOffset(width - 56 - 12, 22)
	title.TextSize = 18
	sub.Position = UDim2.fromOffset(56, 30)
	sub.Size = UDim2.fromOffset(width - 56 - 12, 16)
	sub.TextSize = 12
end

-- A thin vertical divider line.
function PhotoFlowUI.divider(parent: GuiObject, zIndex: number): Frame
	local line = parent:FindFirstChild("Divider") :: Frame?
	if line then return line end
	return make("Frame", {
		Name = "Divider",
		BackgroundColor3 = Color3.fromRGB(80, 76, 96),
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, parent)
end

-- "사진이 저장되었어요!": a soft card with sparkles, a pink check, the title
-- and subtitle; the three buttons go in `buttons` (a row) below it.
function PhotoFlowUI.savedPanel(parent: GuiObject, zIndex: number): (Frame, TextLabel, TextLabel)
	for _, child in ipairs(parent:GetChildren()) do child:Destroy() end
	local card = make("Frame", {
		Name = "SavedCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.62, 0, 0, 150),
		BackgroundColor3 = C.cardDark,
		ZIndex = zIndex,
	}, parent)
	round(card, 14)
	-- sparkles: two crossed rounded bars each (the fonts lack ✦)
	for _, s in ipairs({ { 0.16, 0.24, 16 }, { 0.8, 0.16, 20 }, { 0.88, 0.62, 12 }, { 0.1, 0.7, 10 } }) do
		for _, horizontal in ipairs({ false, true }) do
			local bar = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(s[1], s[2]),
				Size = if horizontal then UDim2.fromOffset(s[3], math.max(2, s[3] // 5)) else UDim2.fromOffset(math.max(2, s[3] // 5), s[3]),
				BackgroundColor3 = Color3.fromRGB(255, 240, 250),
				BorderSizePixel = 0,
				ZIndex = zIndex + 1,
			}, card)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
		end
	end
	local check = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.pink,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = C.text,
		Text = "✓",
		ZIndex = zIndex + 1,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, check)
	local title = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.new(1, -20, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = C.text,
		Text = "사진이 저장되었어요!",
		ZIndex = zIndex + 1,
	}, card)
	local sub = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = C.sub,
		Text = "내 앨범에서 확인할 수 있어요",
		ZIndex = zIndex + 1,
	}, card)
	return card, title, sub
end

-- A confirm dialog over everything: title, body, 취소 / ok. onOk runs on ok.
function PhotoFlowUI.confirm(gui: Instance, titleText: string, bodyText: string, okText: string, onOk: () -> ())
	local old = gui:FindFirstChild("ConfirmDialog")
	if old then old:Destroy() end
	local shade = make("TextButton", {
		Name = "ConfirmDialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 60,
	}, gui)
	local box = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 170),
		BackgroundColor3 = Color3.fromRGB(24, 20, 32),
		ZIndex = 61,
	}, shade)
	round(box, 16)
	make("UIStroke", { Color = C.pink, Thickness = 2 }, box)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 18),
		Size = UDim2.new(1, -32, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = C.text,
		Text = titleText,
		ZIndex = 62,
	}, box)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = C.sub,
		Text = bodyText,
		ZIndex = 62,
	}, box)
	local function btn(label: string, color: Color3, x: number): TextButton
		local b = make("TextButton", {
			Position = UDim2.new(x, if x == 0 then 16 else 6, 1, -54),
			Size = UDim2.new(0.5, -22, 0, 40),
			BackgroundColor3 = color,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = C.text,
			Text = label,
			ZIndex = 62,
		}, box)
		round(b, 12)
		return b
	end
	local cancel = btn("취소", C.card, 0)
	local ok = btn(okText, C.danger, 0.5)
	cancel.MouseButton1Click:Connect(function() shade:Destroy() end)
	ok.MouseButton1Click:Connect(function()
		shade:Destroy()
		onOk()
	end)
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 700)
	local scale = make("UIScale", {}, box)
	scale.Scale = math.clamp(math.min(vp.X / 340, vp.Y / 210), 0.6, 1)
end

-- "2026.10.30" and "오후 3:12" (the player's local time).
function PhotoFlowUI.dateLines(t: any): (string, string)
	if typeof(t) ~= "number" then return "", "" end
	local d = DateTime.fromUnixTimestamp(t):ToLocalTime()
	local h = d.Hour
	local ampm = if h < 12 then "오전" else "오후"
	local h12 = h % 12
	if h12 == 0 then h12 = 12 end
	return string.format("%04d.%02d.%02d", d.Year, d.Month, d.Day), string.format("%s %d:%02d", ampm, h12, d.Minute)
end

-- One 내 앨범 card: the photo (drawn by the caller into the returned holder),
-- the date and time under it, a trash button at the bottom.
function PhotoFlowUI.albumCard(parent: Instance, index: number, createdAt: any, zIndex: number): (TextButton, Frame, TextButton)
	local card = make("TextButton", {
		Name = "Photo" .. index,
		LayoutOrder = index,
		BackgroundColor3 = C.card,
		AutoButtonColor = false,
		Text = "",
		ZIndex = zIndex,
	}, parent)
	round(card, 10)
	local holder = make("Frame", {
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 1, -74),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, card)
	local day, time = PhotoFlowUI.dateLines(createdAt)
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.new(1, -8, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = C.sub,
		Text = day .. "\n" .. time,
		ZIndex = zIndex + 1,
	}, card)
	local trash = make("TextButton", {
		Name = "Delete",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(28, 26),
		BackgroundColor3 = C.cardDark,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.text,
		Text = "🗑",
		ZIndex = zIndex + 2,
	}, card)
	round(trash, 8)
	return card, holder, trash
end

return PhotoFlowUI
