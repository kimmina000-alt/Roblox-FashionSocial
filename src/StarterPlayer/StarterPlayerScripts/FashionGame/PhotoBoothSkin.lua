--!strict
-- 오후네컷 windows in the user's design (D-1267, user 2026-11-11, "오후네컷 UI.pdf":
-- "오후네컷 팝업 디자인 변경 ... 색상 그대로 구현할 것 ... 디자인만 바꾸는 것이니까 기존 기능
-- 건드리지 말 것"). Colours read from the PDF: the windows are black at 70 %
-- with a white edge, grey cards (#84817F), light photo cells (#DDDDDD), the
-- chosen thing gets a white edge, the dark pill (#231F20) is the chosen /
-- pressed one, the go buttons are #864E51 with a white edge. White icons from
-- the PDF's last page (docs/04_ART/icons/ohucuts_*.png).
-- Kept out of PhotoBoothController (local register limit): the controller
-- builds its windows as before and this module restyles them and adds the
-- new bits (count bar, pose / 표정 tabs, the logo cell, the shadows).

local Skin = {}

Skin.C = {
	panel = Color3.new(0, 0, 0),
	panelT = 0.3, -- (black at 70 %)
	card = Color3.fromRGB(132, 129, 127), -- #84817F
	cardLight = Color3.fromRGB(170, 167, 166), -- #AAA7A6 (frame cards)
	cell = Color3.fromRGB(221, 221, 221), -- #DDDDDD
	chip = Color3.fromRGB(117, 113, 112), -- #757170 (pose / 표정 buttons)
	tabOff = Color3.fromRGB(105, 102, 100),
	dark = Color3.fromRGB(35, 31, 32), -- #231F20
	accent = Color3.fromRGB(134, 78, 81), -- #864E51
	rec = Color3.fromRGB(239, 64, 42), -- #EF402A
	white = Color3.new(1, 1, 1),
	sub = Color3.fromRGB(190, 190, 190),
	light = Color3.fromRGB(221, 221, 221), -- the buttons under the picture
}
local C = Skin.C

Skin.Icons = {
	frame = "rbxassetid://139309751219723", -- camera in a frame (촬영 n/8)
	timer = "rbxassetid://127224575039086",
	camera = "rbxassetid://85214440838342",
	clapper = "rbxassetid://99287630714360",
	bag = "rbxassetid://98853481270424",
	picture = "rbxassetid://129959081088687",
	logo = "rbxassetid://115835243531131", -- OHU (white, 1477 × 490)
}

Skin.FONT = Enum.Font.GothamMedium
Skin.BOLD = Enum.Font.GothamBold

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
Skin.make = make

local function corner(o: Instance, r: number?)
	local c = o:FindFirstChildOfClass("UICorner") or make("UICorner", {}, o)
	c.CornerRadius = if r then UDim.new(0, r) else UDim.new(1, 0)
end
Skin.corner = corner

-- the white edge (made once, turned on / off)
function Skin.edge(o: GuiObject, on: boolean, thickness: number?): UIStroke
	local s = o:FindFirstChild("SkinEdge") :: UIStroke?
	if not s then
		-- other strokes (the old pink edges) go
		for _, child in ipairs(o:GetChildren()) do
			if child:IsA("UIStroke") then child:Destroy() end
		end
		s = make("UIStroke", { Name = "SkinEdge", Color = C.white, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
	local stroke = s :: UIStroke
	stroke.Thickness = thickness or 2
	stroke.Transparency = if on then 0 else 1
	return stroke
end

-- a window: black 70 %, white edge, round corners
function Skin.window(f: GuiObject, radius: number?)
	f.BackgroundColor3 = C.panel
	f.BackgroundTransparency = C.panelT
	corner(f, radius or 12)
	Skin.edge(f, true, 2)
end

-- a pill button: "card" (grey), "dark" (chosen), "accent" (go), "light" (under the picture)
function Skin.pill(b: GuiObject, kind: string, edge: boolean?)
	local bg = if kind == "dark" then C.dark elseif kind == "accent" then C.accent elseif kind == "light" then C.light
		elseif kind == "chip" then C.chip else C.card
	b.BackgroundColor3 = bg
	b.BackgroundTransparency = if kind == "light" then 0.1 else 0
	if b:IsA("TextButton") or b:IsA("TextLabel") then
		local t = b :: TextButton
		t.TextColor3 = if kind == "light" then C.dark else C.white
		t.Font = Skin.FONT
	end
	corner(b)
	Skin.edge(b, edge == true, 2)
end

-- chosen = white edge (the button keeps its colour)
function Skin.select(b: GuiObject, on: boolean)
	b.BackgroundColor3 = C.chip
	if b:IsA("TextButton") then (b :: TextButton).TextColor3 = C.white end
	Skin.edge(b, on, 2)
end

-- the 혼자만 / 친구와 / 모두와 pills: the chosen one dark with a white edge
function Skin.paintModes(buttons: {[string]: TextButton}, chosen: string)
	for key, b in pairs(buttons) do
		Skin.pill(b, if key == chosen then "dark" else "card", key == chosen)
	end
end

-- a dark shadow under white text / images (a sibling one step lower, moved
-- 1.5 px down-right, following the original's text, place and visibility)
function Skin.shadow(o: GuiObject, offset: number?)
	local parent = o.Parent
	if not parent or parent:FindFirstChild(o.Name .. "_Shadow") then return end
	local d = offset or 1.5
	local s: GuiObject
	if o:IsA("ImageLabel") then
		s = make("ImageLabel", {
			Image = (o :: ImageLabel).Image, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.45,
			BackgroundTransparency = 1, Rotation = o.Rotation, ScaleType = (o :: ImageLabel).ScaleType,
		}, nil)
	elseif not o:IsA("TextLabel") and not o:IsA("TextButton") then
		-- a plain bar (the X's strokes)
		s = make("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Rotation = o.Rotation,
		}, nil)
		local c = o:FindFirstChildOfClass("UICorner")
		if c then c:Clone().Parent = s end
	else
		local t = o :: TextLabel
		s = make("TextLabel", {
			Text = t.Text, Font = t.Font, TextSize = t.TextSize, TextScaled = t.TextScaled,
			TextXAlignment = t.TextXAlignment, TextYAlignment = t.TextYAlignment, RichText = t.RichText,
			TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.45, BackgroundTransparency = 1,
		}, nil)
		t:GetPropertyChangedSignal("Text"):Connect(function() (s :: TextLabel).Text = t.Text end)
		local pad = t:FindFirstChildOfClass("UIPadding")
		if pad then pad:Clone().Parent = s end -- (the same inset, or the shadow shifts: REC)
	end
	s.Name = o.Name .. "_Shadow"
	s.AnchorPoint = o.AnchorPoint
	s.ZIndex = math.max(1, o.ZIndex - 1)
	local function follow()
		s.Position = o.Position + UDim2.fromOffset(d, d)
		s.Size = o.Size
		s.Visible = o.Visible
	end
	for _, p in ipairs({ "Position", "Size", "Visible" }) do o:GetPropertyChangedSignal(p):Connect(follow) end
	follow()
	s.Parent = parent
end

-- a white icon at the left of a pill button, the text moved right of it
function Skin.iconButton(b: TextButton, image: string)
	local old = b:FindFirstChild("SkinIcon")
	if old then old:Destroy() end
	local icon = make("ImageLabel", {
		Name = "SkinIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Image = image, ZIndex = b.ZIndex + 1,
	}, b)
	local pad = b:FindFirstChildOfClass("UIPadding") or make("UIPadding", {}, b)
	pad.PaddingLeft = UDim.new(0, 26)
	-- icon + text centred as one: the icon (20) and a 6 px gap just left of the
	-- text (children sit in the padded box too, so 0.5 is the text's middle)
	local function place()
		icon.Position = UDim2.new(0.5, -b.TextBounds.X / 2 - 26, 0.5, 0)
	end
	b:GetPropertyChangedSignal("TextBounds"):Connect(place)
	place()
end

-- a window's header icon (white image, left of the title)
function Skin.headerIcon(window: GuiObject, image: string)
	local box = window:FindFirstChild("HeaderIcon") :: GuiObject?
	if box and box:IsA("TextLabel") then
		box.Text = ""
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(12, 10)
		box.Size = UDim2.fromOffset(24, 24)
		local img = (box:FindFirstChild("SkinIcon") :: ImageLabel?) or make("ImageLabel", {
			Name = "SkinIcon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = box.ZIndex + 1,
		}, box)
		;(img :: ImageLabel).Image = image
	end
end

----------------------------------------------------------------------
-- 2. the waiting bar's count bar (D-1267: "10초 카운트 바 만들어서 시간 흐르는 거 시각적으로 표현")
function Skin.countBar(parent: GuiObject): (number, number) -> ()
	local track = make("Frame", {
		Name = "CountTrack", BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = parent.ZIndex + 1,
	}, parent)
	corner(track)
	local fill = make("Frame", {
		Name = "CountFill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = parent.ZIndex + 2,
	}, track)
	corner(fill)
	local total = 0
	return function(left: number, reset: number)
		-- reset = 1 when the waiting starts (a friend joining adds time: the bar
		-- grows with it, PhotoConfig.JoinExtraSeconds)
		if reset == 1 or left > total then total = math.max(left, 0.01) end
		fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
	end
end

----------------------------------------------------------------------
-- 3. the shot counter at the top of the camera window: [frame] 촬영 1/8   [timer] 10 초
function Skin.shootInfo(info: TextLabel): (number, number, number) -> ()
	info.Text = ""
	info.BackgroundTransparency = 1
	for _, child in ipairs(info:GetChildren()) do
		if child:IsA("UIStroke") then child:Destroy() end
	end
	local row = make("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = info.ZIndex }, info)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local function piece(order: number, image: string, w: number): TextLabel
		local holder = make("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(w + 26, 26), BackgroundTransparency = 1, ZIndex = info.ZIndex }, row)
		local img = make("ImageLabel", {
			Name = "Icon", Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
			Image = image, ZIndex = info.ZIndex + 2,
		}, holder)
		local label = make("TextLabel", {
			Name = "Label", Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0), BackgroundTransparency = 1,
			Font = Skin.FONT, TextSize = 16, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "", ZIndex = info.ZIndex + 2,
		}, holder)
		Skin.shadow(img)
		Skin.shadow(label)
		return label
	end
	local shot = piece(1, Skin.Icons.frame, 70)
	make("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(18, 1), BackgroundTransparency = 1 }, row)
	local timer = piece(3, Skin.Icons.timer, 50)
	return function(index: number, count: number, seconds: number)
		shot.Text = string.format("촬영 %d/%d", index, count)
		timer.Text = string.format("%d 초", seconds)
	end
end

-- the ● REC: a red dot that blinks, white REC
function Skin.rec(label: TextLabel)
	label.RichText = false
	label.Text = "REC"
	label.Font = Skin.FONT
	label.TextSize = 13
	label.TextStrokeTransparency = 1
	label.TextColor3 = C.white
	local pad = make("UIPadding", { PaddingLeft = UDim.new(0, 15) }, label)
	local _ = pad
	local dot = make("Frame", {
		Name = "Dot", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -15, 0.5, 0), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.rec, BorderSizePixel = 0, ZIndex = label.ZIndex + 1,
	}, label)
	corner(dot)
	Skin.shadow(label)
	task.spawn(function()
		while label.Parent do
			task.wait(0.55)
			dot.BackgroundTransparency = if dot.BackgroundTransparency == 0 then 1 else 0
		end
	end)
end

-- a button under the picture: light, dark for a moment when pressed (or while `held()`)
function Skin.pressPill(b: TextButton, held: (() -> boolean)?)
	Skin.pill(b, "light")
	b.AutoButtonColor = false
	b.TextSize = 13
	local token = 0
	local function paint(down: boolean)
		local on = down or (held ~= nil and held())
		b.BackgroundColor3 = if on then C.dark else C.light
		b.BackgroundTransparency = if on then 0 else 0.1
		b.TextColor3 = if on then C.white else C.dark
	end
	b.MouseButton1Down:Connect(function() token += 1 paint(true) end)
	b.Activated:Connect(function()
		token += 1
		local my = token
		paint(true)
		task.delay(0.35, function() if token == my then paint(false) end end)
	end)
	return paint
end

-- 표정 list next to the 포즈 list (a copy of its empty scrolling frame) and the
-- two folder tabs over them
function Skin.poseTabs(panel: Frame, poseList: ScrollingFrame): ScrollingFrame
	poseList.Position = UDim2.fromOffset(6, 38)
	poseList.Size = UDim2.new(1, -12, 1, -44)
	local faceList = poseList:Clone()
	faceList.Name = "FaceList"
	for _, child in ipairs(faceList:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end
	faceList.Visible = false
	-- (few faces: two to a row, scrolling down like the user's design)
	faceList.ScrollingDirection = Enum.ScrollingDirection.Y
	faceList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	;(faceList:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout).FillDirection = Enum.FillDirection.Horizontal
	faceList.Parent = poseList.Parent
	-- the old title goes
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("TextLabel") then child.Visible = false end
	end
	Skin.window(panel, 12)
	panel.ClipsDescendants = false
	local tabs = {}
	local function choose(which: number)
		poseList.Visible = which == 1
		faceList.Visible = which == 2
		for i, t in ipairs(tabs) do
			local on = i == which
			t.BackgroundColor3 = if on then C.panel else C.dark
			t.BackgroundTransparency = if on then 0.2 else 0.4
			t.TextColor3 = if on then C.white else C.sub
			Skin.edge(t, on, 2)
		end
	end
	for i, name in ipairs({ "포즈", "표정" }) do
		local t = make("TextButton", {
			Name = "Tab" .. i, Position = UDim2.new((i - 1) / 2, if i == 1 then 5 else 2, 0, 5),
			Size = UDim2.new(0.5, -7, 0, 27), Font = Skin.FONT, TextSize = 14, Text = name, AutoButtonColor = false,
			ZIndex = panel.ZIndex + 1,
		}, panel)
		corner(t, 10)
		t.Activated:Connect(function() choose(i) end)
		tabs[i] = t
	end
	choose(1)
	return faceList
end

-- the pose buttons' white edge follows the character's DanceKey
function Skin.watchPoses(list: ScrollingFrame, player: Player)
	local function paint()
		local character = player.Character
		local key = character and character:GetAttribute("DanceKey")
		for _, b in ipairs(list:GetChildren()) do
			local k = b:GetAttribute("PoseKey")
			if k ~= nil then Skin.select(b :: GuiObject, k == key) end
		end
	end
	local function watch(character: Model)
		character:GetAttributeChangedSignal("DanceKey"):Connect(paint)
		paint()
	end
	if player.Character then watch(player.Character) end
	player.CharacterAdded:Connect(watch)
	return paint
end

-- the props: round dark buttons, two to a row, "소품" under them
function Skin.propPanel(panel: Frame, list: ScrollingFrame)
	panel.BackgroundTransparency = 1
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("UIStroke") then child:Destroy() end
		if child:IsA("TextLabel") then
			local t = child :: TextLabel
			t.Name = "PropTitle"
			t.Text = "소품"
			t.Font = Skin.FONT
			t.TextColor3 = C.white
			t.TextXAlignment = Enum.TextXAlignment.Center
			t.TextSize = 13
			Skin.shadow(t)
		end
	end
	list.ScrollBarThickness = 0
	local grid = list:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
end

function Skin.layoutProps(panel: Frame, list: ScrollingFrame, x: number, y: number, size: number)
	local count = 0
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiButton") then count += 1 end
	end
	local rows = math.max(1, math.ceil(count / 2))
	local grid = list:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset(size, size)
	local w, h = size * 2 + 8, rows * (size + 8)
	panel.Position = UDim2.fromOffset(x, y)
	panel.Size = UDim2.fromOffset(w + 8, h + 30)
	list.Position = UDim2.fromOffset(4, 0)
	list.Size = UDim2.fromOffset(w, h)
	local title = panel:FindFirstChild("PropTitle") :: TextLabel?
	if title then
		title.Position = UDim2.fromOffset(0, h + 2)
		title.Size = UDim2.new(1, 0, 0, 20)
	end
end

function Skin.propButton(b: TextButton, worn: boolean)
	b.BackgroundColor3 = C.dark
	b.BackgroundTransparency = 0.05
	b.TextColor3 = C.white
	b.Font = Skin.FONT
	b.TextSize = 10
	corner(b)
	Skin.edge(b, worn, 2)
end

----------------------------------------------------------------------
-- 4. the 9th cell of the pick grid: the OHU logo, no box
function Skin.logoCell(grid: Frame, zIndex: number): ImageLabel
	local old = grid:FindFirstChild("LogoCell")
	if old then old:Destroy() end
	local holder = make("ImageLabel", {
		Name = "LogoCell", BackgroundTransparency = 1, Image = Skin.Icons.logo, ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex,
	}, grid)
	make("UIPadding", {
		PaddingLeft = UDim.new(0.26, 0), PaddingRight = UDim.new(0.26, 0), PaddingTop = UDim.new(0.34, 0), PaddingBottom = UDim.new(0.34, 0),
	}, holder)
	return holder
end

-- the grey card behind the strip preview
function Skin.previewCard(window: Frame, preview: Frame, visible: boolean)
	local card = (window:FindFirstChild("PreviewCard") :: Frame?) or make("Frame", {
		Name = "PreviewCard", BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 10,
	}, window)
	corner(card :: Frame, 16)
	local pad = 10
	;(card :: Frame).Position = preview.Position - UDim2.fromOffset(pad, pad)
	;(card :: Frame).Size = preview.Size + UDim2.fromOffset(2 * pad, 2 * pad)
	;(card :: Frame).Visible = visible
end

----------------------------------------------------------------------
-- 5. the frame tabs: folder tabs over a grey box with a white edge
function Skin.frameBox(area: Frame, top: number, bottomRoom: number)
	local box = (area:FindFirstChild("FrameBox") :: Frame?) or make("Frame", {
		Name = "FrameBox", BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 11,
	}, area)
	corner(box :: Frame, 10)
	Skin.edge(box :: Frame, true, 2)
	;(box :: Frame).Position = UDim2.fromOffset(0, top)
	;(box :: Frame).Size = UDim2.new(1, 0, 1, -top - bottomRoom)
end

function Skin.paintTabs(tabs: {[string]: TextButton}, chosen: string)
	for name, t in pairs(tabs) do
		local on = name == chosen
		t.BackgroundColor3 = if on then C.card else C.tabOff
		t.BackgroundTransparency = 0
		t.TextColor3 = C.white
		t.Font = Skin.FONT
		t.ZIndex = 13
		corner(t, 10)
		Skin.edge(t, on, 2)
		local patch = (t:FindFirstChild("Patch") :: Frame?) or make("Frame", {
			Name = "Patch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -4, 0, 12),
			BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 14,
		}, t)
		;(patch :: Frame).Visible = on
	end
end

return Skin
