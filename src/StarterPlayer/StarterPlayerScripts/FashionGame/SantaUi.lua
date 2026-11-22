--!strict
-- (D-2044, user 2026-11-22, with a mock-up: "UI 디자인 수정 … 도감 UI와 발견 팝업을 별도 컴포넌트로 제작 … PC와
-- 모바일에서 동일한 디자인 시스템을 사용하면서 크기만 반응형으로") The mini Santa hunt's design system and its two
-- components:
--   the 산타 도감 → SantaHuntController (built from these pieces: card / chunky / pill / deco / fit)
--   SantaUi.reveal(santa)  → the found-a-Santa popup (after the shaking black box)
-- Look: Christmas red + gift green + pastel pink, a candy-cane border (tiled stripe image), a snow cap
-- on the top edge, round raised cards, emoji trees / gifts / snowflakes. Everything is laid out at a
-- fixed design size and scaled to the screen (UIScale), so PC and phones look the same.
-- Images (docs/04_ART/ui/santa): candy_stripe 107049811553805, sunburst 129144505336063,
-- snow_cap 88417161374446; the Santa pictures are SantaHuntConfig.Santas[n].image.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SantaUi = {}

SantaUi.RED = Color3.fromRGB(226, 52, 66)
SantaUi.DEEP_RED = Color3.fromRGB(186, 28, 48)
SantaUi.GREEN = Color3.fromRGB(34, 150, 90)
SantaUi.DEEP_GREEN = Color3.fromRGB(22, 112, 66)
SantaUi.PINK = Color3.fromRGB(255, 120, 160)
SantaUi.PINK_TOP = Color3.fromRGB(255, 240, 244)
SantaUi.PINK_BOTTOM = Color3.fromRGB(252, 222, 232)
SantaUi.INK = Color3.fromRGB(88, 40, 52)
SantaUi.WHITE = Color3.new(1, 1, 1)
SantaUi.GOLD = Color3.fromRGB(255, 205, 70)
local IMG_STRIPE = "rbxassetid://107049811553805"

local IMG_SNOW = "rbxassetid://88417161374446"
SantaUi.HEAD = "rbxassetid://70959554400964" -- (the classic Santa's picture, on the album's title)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
SantaUi.BOLD = BOLD

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
SantaUi.create = create
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
SantaUi.corner = corner
local function tween(obj: Instance, t: number, props: {[string]: any}, style: Enum.EasingStyle?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- chunky text: heavy letters, a thick white outline and a soft dark drop under it
function SantaUi.chunky(parent: Instance, props: {[string]: any}, stroke: number?): (TextLabel, TextLabel)
	local shadow = create("TextLabel", {
		BackgroundTransparency = 1, FontFace = BOLD, TextColor3 = Color3.fromRGB(120, 30, 50), TextTransparency = 0.65,
		RichText = false, ZIndex = (props.ZIndex or 1),
	}, parent)
	local label = create("TextLabel", { BackgroundTransparency = 1, FontFace = BOLD, ZIndex = (props.ZIndex or 1) + 1 }, parent)
	for k, v in pairs(props) do (label :: any)[k] = v end
	label.ZIndex = (props.ZIndex or 1) + 1
	create("UIStroke", { Color = SantaUi.WHITE, Thickness = stroke or 4, LineJoinMode = Enum.LineJoinMode.Round }, label)
	shadow.Size = label.Size
	shadow.Position = label.Position + UDim2.fromOffset(0, 3)
	shadow.AnchorPoint = label.AnchorPoint
	shadow.TextSize = label.TextSize
	shadow.TextXAlignment = label.TextXAlignment
	shadow.Text = (label.Text:gsub("<[^>]+>", ""))
	create("UIStroke", { Color = Color3.fromRGB(120, 30, 50), Thickness = stroke or 4, Transparency = 0.65 }, shadow)
	return label, shadow
end

-- a pill (date tags, the 오늘! badge, buttons)
function SantaUi.pill(parent: Instance, props: {[string]: any}, bg: Color3, edge: Color3?): TextLabel
	local p = create(props.Class or "TextLabel", { BackgroundColor3 = bg, FontFace = BOLD, TextColor3 = SantaUi.WHITE, Text = "" }, parent)
	props.Class = nil
	for k, v in pairs(props) do (p :: any)[k] = v end
	corner(p, 999)
	if edge then create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = edge, Thickness = 2 }, p) end
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(SantaUi.WHITE, Color3.fromRGB(222, 222, 222)), -- (a shade only: BackgroundColor3 may change later)
	}, p)
	return p
end

-- the card: candy-cane border (a tiled stripe image) around a pastel pink panel, with a snow cap on top;
-- returns the panel (content goes in it)
function SantaUi.card(parent: Instance, size: UDim2, position: UDim2): Frame
	local holder = create("Frame", { Size = size, Position = position, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, parent)
	local border = create("ImageLabel", {
		Name = "Candy", Size = UDim2.fromScale(1, 1), BackgroundColor3 = SantaUi.WHITE, Image = IMG_STRIPE,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(34, 34),
	}, holder)
	corner(border, 28)
	create("UIStroke", { Color = SantaUi.WHITE, Thickness = 3 }, border)
	local panel = create("Frame", {
		Name = "Panel", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = SantaUi.WHITE,
	}, holder)
	corner(panel, 22)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(SantaUi.PINK_TOP, SantaUi.PINK_BOTTOM) }, panel)
	create("ImageLabel", {
		Name = "Snow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -12), Size = UDim2.new(1, -36, 0, 30),
		BackgroundTransparency = 1, Image = IMG_SNOW, ScaleType = Enum.ScaleType.Stretch, ZIndex = 5,
	}, holder)
	return panel
end

-- an emoji decoration
function SantaUi.deco(parent: Instance, text: string, pos: UDim2, size: number, rot: number?, alpha: number?)
	return create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
		Text = text, TextScaled = true, Rotation = rot or 0, TextTransparency = alpha or 0, ZIndex = 6,
	}, parent)
end

-- the scale that fits a design of w x h between Roblox's top buttons and the screen's bottom
function SantaUi.fit(w: number, h: number): (number, number)
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local inset = GuiService.TopbarInset
	local top = (if inset.Height > 0 then inset.Max.Y else 0) + 14
	local room = math.max(220, vp.Y - top - 10)
	local s = math.min((vp.X * 0.96) / w, room / h, 1.25)
	return s, top + room / 2
end

---------------------------------------------------------------------------- the mock-up's own pictures (D-2045)
-- The user's mock-up (docs/04_ART/ui/santa/mockup.jpg) cut out by tools/art/santa_ui (matte.py, build.py):
-- the frames are the mock-up itself; only the changing parts (cards, count, hint, the Santa, its name) are
-- drawn by the game at the mock-up's own pixel spots. Sizes below are the pictures' pixels (design units).
SantaUi.IMG_ALBUM = "rbxassetid://81903005894610"   -- 1052 x 920, the card area see-through
SantaUi.IMG_POPUP = "rbxassetid://120424630359533"  -- 466 x 710, the Santa and its name wiped (D-2046: whole snow cap)
SantaUi.IMG_CARD = "rbxassetid://140016866546848"   -- 83 x 222, body at (2, 2)..(80, 219)
SantaUi.IMG_TODAY = "rbxassetid://94855431064391"   -- 118 x 250, body at (3, 29)..(104, 247), ! marks top right
SantaUi.FRED = Font.new("rbxasset://fonts/families/FredokaOne.json")
SantaUi.PURPLE = Color3.fromRGB(78, 56, 92)
SantaUi.TAG_RED = Color3.fromRGB(226, 44, 88)

---------------------------------------------------------------------------- the found-a-Santa popup
local showing: ScreenGui? = nil
local PW, PH = 466, 710

-- santa = SantaHuntConfig.Santas[n]; the shaking black box first, then the popup
function SantaUi.reveal(santa: any)
	if showing then showing:Destroy() end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", { Name = "SantaRevealGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60 }, playerGui)
	showing = gui
	local dim = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, gui)
	tween(dim, 0.25, { BackgroundTransparency = 0.4 })
	local s, cy = SantaUi.fit(PW, PH)
	local stage = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, cy), Size = UDim2.fromOffset(PW, PH), BackgroundTransparency = 1 }, gui)
	create("UIScale", { Scale = s }, stage)

	-- 1. the black ? box pops in and shakes harder and harder (D-1870)
	local box = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Color3.new(0, 0, 0), FontFace = SantaUi.FRED, TextSize = 100, TextColor3 = SantaUi.WHITE, Text = "?",
	}, stage)
	corner(box, 22)
	local boxStroke = create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = SantaUi.WHITE, Thickness = 4 }, box)
	local boxScale = create("UIScale", { Scale = 0 }, box)
	tween(boxScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.45)
	local t0 = os.clock()
	while os.clock() - t0 < 1.6 do
		if not gui.Parent then return end
		local t = (os.clock() - t0) / 1.6
		box.Rotation = math.sin((os.clock() - t0) * (18 + 22 * t)) * (3 + 17 * t * t)
		boxScale.Scale = 1 + 0.08 * t
		task.wait()
	end
	tween(boxScale, 0.22, { Scale = 1.7 })
	tween(box, 0.22, { BackgroundTransparency = 1, TextTransparency = 1 })
	tween(boxStroke, 0.22, { Transparency = 1 })
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SantaUi.WHITE, BackgroundTransparency = 0.15, ZIndex = 20 }, gui)
	tween(flash, 0.5, { BackgroundTransparency = 1 })

	-- 2. the popup: the mock-up's frame, the Santa on its snow hill, its name
	local frame = create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(PW, PH),
		BackgroundTransparency = 1, Image = SantaUi.IMG_POPUP, ZIndex = 2,
	}, stage)
	local pop = create("UIScale", { Scale = 0.3 }, frame)
	tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local pic = create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(234, 470), Size = UDim2.fromOffset(350, 350),
		BackgroundTransparency = 1, Image = santa.image or SantaUi.HEAD, ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
	}, frame)
	local name = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(234, 500), Size = UDim2.fromOffset(380, 40), BackgroundTransparency = 1,
		FontFace = BOLD, TextSize = 30, TextScaled = true, TextColor3 = SantaUi.TAG_RED, Text = string.format("%s를 찾았어요!", santa.name or "산타"), ZIndex = 4,
	}, frame)
	create("UITextSizeConstraint", { MaxTextSize = 30 }, name)
	create("UIStroke", { Color = SantaUi.WHITE, Thickness = 2 }, name)
	local ok = create("TextButton", {   -- over the frame's own 확인 button
		Position = UDim2.fromOffset(108, 578), Size = UDim2.fromOffset(266, 80), BackgroundTransparency = 1, Text = "", ZIndex = 5,
	}, frame)
	local closing = false
	local function close()
		if closing then return end
		closing = true
		tween(pop, 0.18, { Scale = 0.6 })
		tween(dim, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.2, function()
			gui:Destroy()
			if showing == gui then showing = nil end
		end)
	end
	ok.Activated:Connect(close)
	task.delay(0.8, function() if gui.Parent then dim.Activated:Connect(close) end end)
	task.spawn(function()
		local s0 = os.clock()
		while gui.Parent and not closing do
			local t = os.clock() - s0
			pic.Rotation = math.sin(t * 3) * 4
			pic.Position = UDim2.fromOffset(234, 470 + math.sin(t * 2.4) * 4)
			task.wait()
		end
	end)
end

return SantaUi
