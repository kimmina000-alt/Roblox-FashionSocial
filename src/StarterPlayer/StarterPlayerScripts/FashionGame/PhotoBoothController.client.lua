--!strict
-- 인생네컷 photo booth client (PHOTO_BOOTH.md §5, Kphoto reference video).
--
--   사진 찍기 prompt → 사진 유형 (1×4 / 2×2) + 인원 (혼자만 / 친구와 / 모두와)
--   → 들어가기 → waiting bar (friends join with "같이 찍기", host may start)
--   → shooting screen: black screen with the camera window in the middle,
--     포즈 panel left (club dances/poses), 소품 panel right, "촬영 n/8 · 초"
--     on top, flash on every shot → 사진을 골라주세요 (4 of 8, in order)
--   → 프레임을 선택하세요 → 저장 → result (캡처 저장 / 사진첩).
--   📷 button (top bar) opens the album (max 30).
--
-- The server owns booths, people, timing and the shot data
-- (PhotoBoothService). Photos are redrawn by PhotoRender.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local PhotoConfig = require(Shared:WaitForChild("PhotoConfig"))
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local boothRemote = Remotes:WaitForChild("PhotoBooth") :: RemoteFunction
local boothEvent = Remotes:WaitForChild("PhotoBoothEvent") :: RemoteEvent
local danceRemote = Remotes:WaitForChild("Dance") :: RemoteEvent
local clubShopRemote = Remotes:WaitForChild("ClubShop") :: RemoteFunction
local MarketplaceService = game:GetService("MarketplaceService")
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local PhotoRender = require(script.Parent:WaitForChild("PhotoRender"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local COLORS = {
	panel = Color3.fromRGB(24, 22, 30),
	card = Color3.fromRGB(44, 42, 54),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	pink = Color3.fromRGB(255, 110, 170),
	yellow = Color3.fromRGB(255, 214, 90),
	ok = Color3.fromRGB(80, 200, 140),
	danger = Color3.fromRGB(200, 70, 80),
}

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end
local function text(props: {[string]: any}, parent: Instance): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.Font = props.Font or Enum.Font.GothamBold
	return create("TextLabel", props, parent)
end
local function button(props: {[string]: any}, parent: Instance, radius: number?): TextButton
	props.BackgroundColor3 = props.BackgroundColor3 or COLORS.card
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.Font = props.Font or Enum.Font.GothamBold
	local instance = create("TextButton", props, parent)
	corner(instance, radius or 10)
	return instance
end

local gui = create("ScreenGui", {
	Name = "FashionPhotoGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 40,
	-- Children always draw above their parent (photo strips sit inside
	-- overlays with higher ZIndex).
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end
local function topY(): number
	return require(script.Parent:WaitForChild("TopBar")).bottom() + 6
end

-- Toast
local toastLabel = text({
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(440, 40),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.25,
	TextSize = 15,
	TextWrapped = true,
	Visible = false,
	ZIndex = 50,
}, gui)
corner(toastLabel, 12)
local toastToken = 0
local function toast(message: any, seconds: number?)
	if typeof(message) ~= "string" or message == "" then return end
	toastToken += 1
	local token = toastToken
	toastLabel.Size = UDim2.fromOffset(math.min(440, viewport().X - 30), 40)
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(seconds or 3.2, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

local function invoke(action: string, payload: any): (boolean, any)
	local ok, success, result = pcall(function()
		return boothRemote:InvokeServer(action, payload)
	end)
	if not ok then return false, "잠시 후 다시 시도하세요." end
	return success == true, result
end

--------------------------------------------------
-- State
--------------------------------------------------

type Shots = { session: string, layout: string, booth: any, people: {any}, shots: {any} }

local state = {
	stage = "none", -- none | setup | waiting | shooting | picking | frame | copies | result
	booth = nil :: Model?,
	shots = nil :: Shots?,
	picks = {} :: {number},
	frame = "white",
	cameraSaved = false,
	-- Only the picker (the host) chooses shots and frame; the others watch
	-- (user, 2026-10-22). Updated from the booth's "Picker" attribute.
	isPicker = false,
	pickerName = "",
}
local PhotoCopiesPanel = require(script.Parent:WaitForChild("PhotoCopiesPanel"))
local PhotoFlowUI = require(script.Parent:WaitForChild("PhotoFlowUI"))
-- (D-1267) the user's new look for every 오후네컷 window (colours, shapes, icons)
local Skin = require(script.Parent:WaitForChild("PhotoBoothSkin"))

-- Centred box for pick / frame / result / album (user, 2026-10-20: not full
-- screen; about the size of the minimized catalog, clear of the hotbar).
-- kind "album" = catalog compact size, "flow" = a little larger for 8 shots.
local function boxRect(kind: string): (number, number, number, number)
	local vp = viewport()
	local top = require(script.Parent:WaitForChild("TopBar")).bottom() + 6
	local bottomRoom = 84 -- hotbar / inventory
	local w, h
	if vp.Y < 500 then
		-- Phone (landscape, user mobile test 2026-10-22): no hotbar, little
		-- height, so use almost all of it and more of the width.
		bottomRoom = 8
		w = math.min(820, math.floor(vp.X * 0.66))
		h = vp.Y - top - bottomRoom
	elseif kind == "album" then
		w = math.min(760, math.max(280, math.floor(vp.X * 0.42)))
		h = math.min(math.max(260, math.floor(vp.Y * 0.58)), vp.Y - top - bottomRoom)
	else
		w = math.min(820, math.max(300, math.floor(vp.X * 0.52)))
		h = math.min(math.max(280, math.floor(vp.Y * 0.64)), vp.Y - top - bottomRoom)
	end
	w = math.min(w, vp.X - 16)
	local x = math.floor((vp.X - w) / 2)
	local y = math.floor(top + math.max(0, (vp.Y - top - bottomRoom - h) / 2))
	return w, h, x, y
end

local function boxify(frame: Frame)
	-- (D-1267: black 70 % with a white edge, was dark with a pink edge)
	Skin.window(frame, 12)
	frame.ClipsDescendants = true
end

local function placeBox(frame: Frame, kind: string): (number, number)
	local w, h, x, y = boxRect(kind)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	return w, h
end

-- Overlay frame used by setup / pick / frame / result / album.
local function overlay(name: string): Frame
	local frame = create("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 8, 14),
		BackgroundTransparency = 0.08,
		Active = true,
		Visible = false,
		ZIndex = 10,
	}, gui)
	return frame
end

--------------------------------------------------
-- Camera
--------------------------------------------------

local shootWindow = { x = 0, y = 0, w = 0, h = 0 }

local function boothCameraCFrame(): CFrame?
	local booth = state.booth
	local point = booth and booth:FindFirstChild("CameraPoint")
	return if point and point:IsA("BasePart") then point.CFrame else nil
end

-- The photo window shows exactly what PhotoRender draws: same camera and the
-- same vertical field of view inside the window.
local function applyShootCamera()
	local camera = workspace.CurrentCamera
	local cf = boothCameraCFrame()
	if not camera or not cf then return end
	if not state.cameraSaved then
		state.cameraSaved = true
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local vp = viewport()
	-- (D-1138, user 2026-11-10: "최종 사진 찍어서 프레임에 담기는 컷이랑 사진 찍을 때 저 네모 칸이랑
	-- 동일한지 비교해") the window's middle is not the screen's middle (top bar,
	-- buttons: on a phone it sits below it), so it did not show what the photo
	-- takes (measured, 801×413: window +20.4° / -34.7°, photo ±28°). The camera
	-- is now turned and zoomed so the window's edges are the photo's edges
	-- (measured after: ±28.00° / ±35.5°, photo ±28° / ±35.3°).
	-- The window's top and bottom edges, as rays from the camera: u = how far
	-- from the screen's middle (in half screen heights). The zoom (tan of half
	-- the vertical FOV) is found so the edges are the photo's full 56° apart,
	-- then the turn puts them at +28° / -28° (likewise left / right).
	local hy = vp.Y / 2
	local uT, uB = (hy - shootWindow.y) / hy, (hy - (shootWindow.y + shootWindow.h)) / hy
	local uL, uR = (shootWindow.x - vp.X / 2) / hy, (shootWindow.x + shootWindow.w - vp.X / 2) / hy
	local want = math.rad(PhotoRender.FieldOfView)
	local lo, hi = 0.05, 5
	for _ = 1, 40 do
		local t = (lo + hi) / 2
		if math.atan(uT * t) - math.atan(uB * t) < want then lo = t else hi = t end
	end
	local tanHalf = (lo + hi) / 2
	camera.FieldOfView = math.clamp(math.deg(2 * math.atan(tanHalf)), 20, 110)
	local pitch = -(math.atan(uT * tanHalf) + math.atan(uB * tanHalf)) / 2
	local yaw = (math.atan(uL * tanHalf) + math.atan(uR * tanHalf)) / 2
	camera.CFrame = cf * CFrame.Angles(pitch, yaw, 0)
end

local function restoreCamera()
	if not state.cameraSaved then return end
	state.cameraSaved = false
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
end

--------------------------------------------------
-- 1. Setup window (사진 유형 + 인원)
--------------------------------------------------

local setup = overlay("Setup")
local SETUP_PANEL, SETUP_CARD = Color3.fromRGB(32, 30, 42), Color3.fromRGB(50, 47, 62)
local MODE_ICONS = { solo = "👤 ", friends = "👥 ", all = "🎉 " }
setup.BackgroundTransparency = 0.4
local setupBox = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(420, 320),
	BackgroundColor3 = SETUP_PANEL, -- (dark with a pink edge, user mock-up 2026-10-28, D-456)
	ZIndex = 11,
}, setup)
corner(setupBox, 18)
create("UIStroke", { Color = COLORS.pink, Thickness = 2.5 }, setupBox)
create("UISizeConstraint", { MaxSize = Vector2.new(420, 320) }, setupBox)
do -- head: pink camera tile, title, one line
	local tile = text({
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(38, 38),
		BackgroundTransparency = 0,
		BackgroundColor3 = COLORS.pink,
		Text = "📷",
		TextSize = 20,
		ZIndex = 12,
	}, setupBox)
	corner(tile, 10)
	text({
		Position = UDim2.fromOffset(62, 10),
		Size = UDim2.new(1, -110, 0, 24),
		Text = "촬영 방식을 선택해주세요",
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, setupBox)
	text({
		Position = UDim2.fromOffset(62, 34),
		Size = UDim2.new(1, -110, 0, 16),
		Text = "원하는 사진 구성을 고르고, 함께 촬영할 대상을 선택할 수 있어요.",
		TextColor3 = COLORS.sub,
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, setupBox)
	text({
		Position = UDim2.fromOffset(18, 200),
		Size = UDim2.new(1, -36, 0, 18),
		Text = "함께 촬영하기",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	}, setupBox)
end
local setupClose = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = SETUP_CARD,
	Text = "X", -- (✕ is not in the Roblox font: an empty box, 2P phone test 2026-10-31)
	TextSize = 15,
	ZIndex = 12,
}, setupBox, 15)
local layoutRow = create("Frame", {
	Position = UDim2.fromOffset(16, 60),
	Size = UDim2.new(1, -32, 0, 132),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, setupBox)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, layoutRow)
local layoutCards: {[string]: TextButton} = {}
local chosenLayout = PhotoConfig.Layouts[1].key
local function paintLayouts()
	for key, other in pairs(layoutCards) do
		-- (D-1267) the chosen frame gets a white edge (no ✓ badge)
		Skin.edge(other, key == chosenLayout, 2.5)
		local check = other:FindFirstChild("Check")
		if check and check:IsA("GuiObject") then check.Visible = false end
	end
end
local chosenMode = "solo"
for index, layout in ipairs(PhotoConfig.Layouts) do
	local card = button({
		Name = "Layout_" .. layout.key,
		LayoutOrder = index,
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundColor3 = SETUP_CARD,
		Text = "",
		ZIndex = 12,
	}, layoutRow, 12)
	create("UIStroke", { Color = COLORS.pink, Thickness = 1, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	-- ✓ badge on the chosen one
	local check = text({
		Name = "Check",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = COLORS.pink,
		Text = "✓",
		TextSize = 14,
		Visible = false,
		ZIndex = 14,
	}, card)
	corner(check, 11)
	-- Little drawing of the layout.
	local sketch = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(if layout.cols == 1 then 40 else 70, 84),
		BackgroundColor3 = Color3.fromRGB(70, 70, 80),
		ZIndex = 13,
	}, card)
	for r = 0, layout.rows - 1 do
		for c = 0, layout.cols - 1 do
			create("Frame", {
				Position = UDim2.new(c / layout.cols, 3, r / layout.rows, 3),
				Size = UDim2.new(1 / layout.cols, -6, 1 / layout.rows, -6),
				BackgroundColor3 = Color3.fromRGB(235, 235, 240),
				BorderSizePixel = 0,
				ZIndex = 14,
			}, sketch)
		end
	end
	text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -8, 0, 22),
		Text = layout.name .. " · 무료",
		TextColor3 = COLORS.text,
		TextSize = 15,
		ZIndex = 13,
	}, card)
	layoutCards[layout.key] = card
	card.MouseButton1Click:Connect(function()
		chosenLayout = layout.key
		paintLayouts()
	end)
end
paintLayouts()

local modeRow = create("Frame", {
	Position = UDim2.fromOffset(16, 222),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, setupBox)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, modeRow)
local modeButtons: {[string]: TextButton} = {}
for index, mode in ipairs(PhotoConfig.Modes) do
	local modeButton = button({
		Name = "Mode_" .. mode.key,
		LayoutOrder = index,
		Size = UDim2.new(1 / 3, -6, 1, 0),
		BackgroundColor3 = SETUP_CARD,
		TextColor3 = COLORS.text,
		Text = (MODE_ICONS[mode.key] or "") .. mode.name,
		TextSize = 15,
		ZIndex = 12,
	}, modeRow, 17)
	modeButtons[mode.key] = modeButton
	modeButton.MouseButton1Click:Connect(function()
		chosenMode = mode.key
		Skin.paintModes(modeButtons, chosenMode) -- (D-1267: the chosen one dark with a white edge)
	end)
end
modeButtons.solo.BackgroundColor3 = COLORS.pink
modeButtons.solo.TextColor3 = COLORS.text
local enterButton = button({
	Name = "EnterButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(1, -32, 0, 44),
	BackgroundColor3 = COLORS.yellow,
	TextColor3 = Color3.fromRGB(60, 40, 10),
	Text = "다음으로",
	TextSize = 18,
	ZIndex = 12,
}, setupBox, 14)
do -- (D-1267, the user's design) "프레임을 선택해 주세요." with an X, two grey frame
	-- cards, and one row: 혼자만 · 친구와 · 모두와 · 다음으로 ▶
	Skin.window(setupBox, 12)
	setupBox.Size = UDim2.fromOffset(420, 252)
	local fit = setupBox:FindFirstChildOfClass("UISizeConstraint")
	if fit then fit.MaxSize = Vector2.new(420, 252) end
	for _, child in ipairs(setupBox:GetChildren()) do
		if child:IsA("TextLabel") then
			if child.Text == "촬영 방식을 선택해주세요" then
				child.Text = "프레임을 선택해 주세요."
				child.Font = Skin.FONT
				child.TextSize = 16
				child.Position = UDim2.fromOffset(16, 12)
				child.Size = UDim2.new(1, -60, 0, 22)
			else
				child.Visible = false -- (the pink tile, the subtitle, "함께 촬영하기")
			end
		end
	end
	setupClose.BackgroundTransparency = 1
	setupClose.Font = Skin.FONT
	setupClose.TextSize = 14
	setupClose.Position = UDim2.new(1, -6, 0, 6)
	setupClose.Size = UDim2.fromOffset(26, 26)
	layoutRow.Position = UDim2.fromOffset(16, 44)
	layoutRow.Size = UDim2.new(1, -32, 0, 150)
	for _, layout in ipairs(PhotoConfig.Layouts) do
		local card = layoutCards[layout.key]
		card.BackgroundColor3 = Skin.C.card
		Skin.corner(card, 12)
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("TextLabel") then child.Visible = false end
			if child:IsA("Frame") then -- the drawing: black strip, white cells
				child.BackgroundColor3 = Skin.C.dark
				child.Position = UDim2.new(0.5, 0, 0, 14)
				child.Size = if layout.cols == 1 then UDim2.fromOffset(38, 120) else UDim2.fromOffset(134, 108)
				for _, cell in ipairs(child:GetChildren()) do
					if cell:IsA("Frame") then cell.BackgroundColor3 = Skin.C.white end
				end
			end
		end
	end
	paintLayouts()
	modeRow.Position = UDim2.new(0, 16, 1, -44)
	modeRow.Size = UDim2.new(1, -32, 0, 30)
	for index, mode in ipairs(PhotoConfig.Modes) do
		local b = modeButtons[mode.key]
		b.Size = UDim2.new(0.25, -6, 1, 0)
		b.Text = mode.name
		b.TextSize = 13
		b.LayoutOrder = index
	end
	Skin.paintModes(modeButtons, chosenMode)
	enterButton.Parent = modeRow
	enterButton.LayoutOrder = 99
	enterButton.AnchorPoint = Vector2.new(0, 0)
	enterButton.Position = UDim2.new()
	enterButton.Size = UDim2.new(0.25, -6, 1, 0)
	enterButton.Text = "다음으로 ▶"
	enterButton.TextSize = 13
	Skin.pill(enterButton, "accent", true)
end

local function layoutSetup()
	local vp = viewport()
	local scale = math.min(1, (vp.X - 20) / 420, (vp.Y - 20) / 252)
	local uiScale = setupBox:FindFirstChildOfClass("UIScale") or create("UIScale", {}, setupBox)
	uiScale.Scale = scale
end

-- one popup at a time: the setup window, the album and the result screen
-- close when another window opens (the shooting session itself stays)
local Popups = require(script.Parent:WaitForChild("Popups"))
local setupBooth: Model? = nil
local function closeSetup()
	setup.Visible = false
	if state.stage == "setup" then state.stage = "none" end
	Popups.closed("PhotoSetup")
end
local function openSetup(booth: Model)
	if state.stage ~= "none" then return end
	setupBooth = booth
	layoutSetup()
	setup.Visible = true
	state.stage = "setup"
	Popups.opened("PhotoSetup", closeSetup)
end
setupClose.MouseButton1Click:Connect(closeSetup)
enterButton.MouseButton1Click:Connect(function()
	local booth = setupBooth
	if not booth then return end
	enterButton.Text = "..."
	local ok, message = invoke("Open", { booth = booth, layout = chosenLayout, mode = chosenMode })
	enterButton.Text = "다음으로 ▶"
	closeSetup()
	if not ok then toast(message) end
end)

--------------------------------------------------
-- 2. Waiting bar
--------------------------------------------------

local waitBar = create("Frame", {
	Name = "WaitBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(380, 84),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.05,
	Active = true,
	Visible = false,
}, gui)
corner(waitBar, 14)
create("UIStroke", { Color = COLORS.pink, Thickness = 2 }, waitBar)
local waitText = text({
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 34),
	Text = "",
	TextSize = 16,
	TextWrapped = true,
}, waitBar)
local waitStart = button({
	Position = UDim2.new(0, 12, 1, -38),
	Size = UDim2.new(0.5, -18, 0, 30),
	BackgroundColor3 = COLORS.pink,
	Text = "바로 시작",
	TextSize = 14,
}, waitBar, 15)
local waitLeave = button({
	Position = UDim2.new(0.5, 6, 1, -38),
	Size = UDim2.new(0.5, -18, 0, 30),
	Text = "나가기",
	TextSize = 14,
}, waitBar, 15)
waitStart.MouseButton1Click:Connect(function() invoke("Start", nil) end)
-- (D-1267) one row: 바로 시작 | "10 초 후 촬영 시작·1/4명·혼자만" over a count bar | 나가기,
-- at the top of the screen; the bar runs down with the seconds left
Skin.window(waitBar, 12)
waitText.Font = Skin.FONT
waitText.TextSize = 13
waitText.TextWrapped = false
waitText.TextXAlignment = Enum.TextXAlignment.Left
waitText.Position = UDim2.fromOffset(98, 7)
waitText.Size = UDim2.new(1, -196, 0, 20)
Skin.pill(waitStart, "accent", true)
waitStart.TextSize = 12
waitStart.AnchorPoint = Vector2.new(0, 0.5)
waitStart.Position = UDim2.new(0, 10, 0.5, 0)
waitStart.Size = UDim2.fromOffset(78, 26)
Skin.pill(waitLeave, "card")
waitLeave.TextSize = 12
local waitCount = Skin.countBar(waitBar)
do
	local track = waitBar:FindFirstChild("CountTrack") :: Frame
	track.Position = UDim2.fromOffset(98, 32)
	track.Size = UDim2.new(1, -196, 0, 7)
end

--------------------------------------------------
-- 3. Shooting screen
--------------------------------------------------

local shoot = create("Frame", {
	Name = "Shoot",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
-- While the shooting screen is up, other menus (catalog, dance panel, …)
-- are hidden so they do not cover the camera window; they come back after.
local hiddenGuis: {ScreenGui} = {}
shoot:GetPropertyChangedSignal("Visible"):Connect(function()
	if shoot.Visible then
		for _, other in ipairs(playerGui:GetChildren()) do
			-- (the phone move stick stays: players walk into place, user 2026-10-26)
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled and other.Name ~= "PhotoRenderHolder" and other.Name ~= "TouchGui" then
				other.Enabled = false
				table.insert(hiddenGuis, other)
			end
		end
	else
		for _, other in ipairs(hiddenGuis) do
			if other.Parent then other.Enabled = true end
		end
		table.clear(hiddenGuis)
	end
	-- Name tags (nickname + XP) over the heads would sit in the photo window
	-- (user mobile test 2026-10-22): hidden on this screen while shooting.
	for _, other in ipairs(Players:GetPlayers()) do
		local head = other.Character and other.Character:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("OHUNameTag")
		if tag and tag:IsA("BillboardGui") then tag.Enabled = not shoot.Visible end
	end
end)

local masks: {Frame} = {}
for i = 1, 4 do
	-- (no black background any more, user 2026-10-26: the booth shows around
	-- the window; the masks stay as empty layout frames that let touches through)
	masks[i] = create("Frame", { Name = "Mask" .. i, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false }, shoot)
end
local windowFrame = create("Frame", {
	Name = "Window",
	BackgroundTransparency = 1,
}, shoot)
-- camera viewfinder look (user reference 2026-10-26): rounded white corner
-- brackets (one image turned for each corner, tools/art/viewfinder_corner.ps1),
-- a small centre cross and a blinking ● REC
local VIEWFINDER_CORNER = "rbxassetid://115103629010894"
local corners: {ImageLabel} = {}
for i, spec in ipairs({ { 0, 0, 0 }, { 1, 0, 90 }, { 1, 1, 180 }, { 0, 1, 270 } }) do
	corners[i] = create("ImageLabel", {
		Name = "Corner" .. i,
		AnchorPoint = Vector2.new(spec[1], spec[2]),
		Position = UDim2.fromScale(spec[1], spec[2]),
		BackgroundTransparency = 1,
		Image = VIEWFINDER_CORNER,
		ImageTransparency = 0.05,
		Rotation = spec[3],
		ZIndex = 3,
	}, windowFrame)
end
for _, size in ipairs({ Vector2.new(18, 2), Vector2.new(2, 18) }) do
	create("Frame", {
		Name = "Cross",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, windowFrame)
end
local recLabel = create("TextLabel", {
	Name = "Rec",
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.fromOffset(70, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.6,
	RichText = true,
	Text = '<font color="#FF3B3B">●</font> REC',
	ZIndex = 3,
}, windowFrame)
-- (D-1267) only the red dot in front of REC blinks; white text and the white
-- corners with a dark shadow under them
Skin.rec(recLabel)
recLabel.Position = UDim2.fromOffset(18, 12)
for _, c in ipairs(corners) do Skin.shadow(c, 2) end
local flash = create("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, windowFrame)
local countdown = text({
	Name = "Countdown",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.4, 0.4),
	Text = "",
	TextScaled = true,
	TextTransparency = 0.15,
	Font = Enum.Font.GothamBlack,
	ZIndex = 4,
}, windowFrame)
create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 3, Transparency = 0.4 }, countdown)
local infoBar = text({
	Name = "Info",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(300, 34),
	-- (black with a pink edge like the other photo windows, user 2026-10-30)
	BackgroundColor3 = Color3.fromRGB(24, 20, 32),
	BackgroundTransparency = 0.03,
	TextColor3 = COLORS.text,
	Text = "",
	TextSize = 16,
	ZIndex = 3,
}, shoot)
corner(infoBar, 17)
-- (D-1267) no box: [frame icon] 촬영 1/8   [timer icon] 10 초, white with a shadow
;(Skin :: any).setShootInfo = Skin.shootInfo(infoBar)
-- the tip sits inside the bottom of the photo window (user mock-up 2026-10-26)
local tip = text({
	Name = "Tip",
	Size = UDim2.fromOffset(180, 20),
	Text = "팁: 캐릭터를 움직여 자리를 잡을 수 있어요",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	TextSize = 12,
	TextWrapped = true,
	ZIndex = 3,
}, shoot)
-- leaving is an X next to the shot counter at the top (user mock-up 2026-10-26)
-- (no background: a white X of two rounded strokes like the viewfinder corners)
local shootLeave = button({
	Name = "Leave",
	Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 3,
}, shoot, 17)
for _, angle in ipairs({ 45, -45 }) do
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 5),
		Rotation = angle,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, shootLeave)
	corner(bar, 3)
end
-- turns the character to face the camera where it stands (user 2026-10-26)
local faceFront = button({
	Name = "FaceFront",
	Size = UDim2.fromOffset(120, 30),
	BackgroundColor3 = COLORS.pink,
	Text = "정면 보기",
	TextSize = 13,
	ZIndex = 3,
}, shoot, 15)
-- (D-1267) light pills under the picture that go dark when pressed; no tip
-- line; the X is small, in the window's top-right corner
Skin.pressPill(faceFront)
tip.Visible = false
for i, bar in ipairs(shootLeave:GetChildren()) do
	if bar:IsA("Frame") then
		bar.Name = "XBar" .. i
		bar.Size = UDim2.fromOffset(16, 2)
		Skin.shadow(bar, 1.5)
	end
end

local function sidePanel(name: string, title: string): (Frame, ScrollingFrame)
	-- (black with a pink edge like the other photo windows, user 2026-10-30;
	-- was light pink)
	local frame = create("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(24, 20, 32),
		BackgroundTransparency = 0.03,
		ZIndex = 3,
	}, shoot)
	corner(frame, 12)
	create("UIStroke", { Color = COLORS.pink, Thickness = 2 }, frame)
	text({
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 22),
		Text = title,
		TextColor3 = COLORS.yellow,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, frame)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 28),
		Size = UDim2.new(1, -12, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 4,
	}, frame)
	create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -3, 0, 34),
		CellPadding = UDim2.fromOffset(4, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	return frame, list
end

local posePanel, poseList = sidePanel("Poses", "포즈")
local propPanel, propList = sidePanel("Props", "소품")
-- (D-1182, user 2026-11-10: "포즈 지금 아래로 드래그인데 옆으로 드래그로 변경") the pose
-- list scrolls sideways: the buttons fill each column top to bottom, then the
-- next column to the right (rows / cell width set in layoutShoot)
poseList.ScrollingDirection = Enum.ScrollingDirection.X
poseList.AutomaticCanvasSize = Enum.AutomaticSize.X
;(poseList:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout).FillDirection = Enum.FillDirection.Vertical
-- (D-1267, user 2026-11-11: "소품이랑 포즈 위치 바꿈. 왼쪽이 소품, 오른쪽이 포즈. 포즈 칸에 표정
-- 카테고리 추가해서 포즈랑 표정 나누기") the pose window gets 포즈 / 표정 tabs (표정 has its
-- own list); the props become round buttons without a window
;(Skin :: any).faceList = Skin.poseTabs(posePanel, poseList)
Skin.propPanel(propPanel, propList)

-- dark card buttons with white text, like the other photo windows (user
-- 2026-10-30; were light sky blue); the chosen one is pink
-- (D-1267: grey pills, the chosen one with a white edge)
local SKY_BUTTON, SKY_TEXT = Skin.C.chip, Color3.fromRGB(255, 255, 255)
local pauseButton: TextButton
do -- pose buttons: ⏸ (freeze the pose), 기본 (stop) + club poses and dances
	local order = 0
	local function add(label: string, onClick: () -> ()): TextButton
		order += 1
		local b = button({
			LayoutOrder = order,
			BackgroundColor3 = SKY_BUTTON,
			TextColor3 = SKY_TEXT,
			Text = label,
			TextSize = 12,
			TextWrapped = true,
			ZIndex = 5,
		}, poseList, 8)
		Skin.corner(b) -- (D-1267: pill)
		b.Font = Skin.FONT
		b.MouseButton1Click:Connect(onClick)
		return b
	end
	-- ⏸ stops the pose animation at this frame so the photo catches it
	-- (user, 2026-10-20); ▶ continues. It sits beside 🙂 정면 보기 under the
	-- picture, not in the pose list (user 2026-10-30)
	pauseButton = button({
		Name = "PausePose",
		Size = UDim2.fromOffset(120, 30),
		BackgroundColor3 = COLORS.pink,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "⏸ 멈춤",
		TextSize = 13,
		ZIndex = 3,
	}, shoot, 15)
	-- (D-1267) dark while the pose is held
	Skin.pressPill(pauseButton, function()
		local character = player.Character
		return character ~= nil and typeof(character:GetAttribute("DancePause")) == "number"
	end)
	pauseButton.MouseButton1Click:Connect(function()
		local character = player.Character
		if not character or character:GetAttribute("DanceKey") == nil then
			toast("먼저 포즈를 고른 뒤 원하는 순간에 ⏸를 누르세요.")
			return
		end
		danceRemote:FireServer(if typeof(character:GetAttribute("DancePause")) == "number" then "Resume" else "Pause")
	end)
	add("■ 기본", function() danceRemote:FireServer("Stop") end)
	-- helpers for tall / short avatars (user 2026-10-28, D-452): pink while on
	-- (the server keeps the state on the character: BoothKneel / BoothStep)
	for _, helper in ipairs({ { "Kneel", "🧎 허리 숙이기" }, { "Step", "👟 키높이 발판" } }) do
		local attribute = "Booth" .. helper[1]
		local b = add(helper[2], function()
			local ok, message = invoke(helper[1])
			if not ok and typeof(message) == "string" then toast(message) end
		end)
		local function paint()
			local character = player.Character
			local on = character ~= nil and character:GetAttribute(attribute) == true
			Skin.select(b, on) -- (D-1267)
		end
		local function watch(character: Model)
			character:GetAttributeChangedSignal(attribute):Connect(paint)
			paint()
		end
		if player.Character then watch(player.Character) end
		player.CharacterAdded:Connect(watch)
	end
	-- (D-1136) 높이 맞추기 for tall avatars cut at the neck near the camera: ▼ / ▲
	-- one PhotoConfig.HeightStep a press, the height so far on the button; 🧍
	-- 일어서기 back to normal (and out of the kneel)
	do
		local down = add("▼ 내려가기", function()
			local ok, message = invoke("Down")
			if not ok and typeof(message) == "string" then toast(message) end
		end)
		local up = add("▲ 올라가기", function()
			local ok, message = invoke("Up")
			if not ok and typeof(message) == "string" then toast(message) end
		end)
		local stand = add("🧍 일어서기", function() invoke("StandUp") end)
		local function paint()
			local character = player.Character
			local h = character and character:GetAttribute("BoothHeight")
			local moved = typeof(h) == "number" and h ~= 0
			down.Text = if moved and (h :: number) < 0 then string.format("▼ 내려가기 (%s)", tostring(h)) else "▼ 내려가기"
			up.Text = if moved and (h :: number) > 0 then string.format("▲ 올라가기 (+%s)", tostring(h)) else "▲ 올라가기"
			local on = moved or (character ~= nil and character:GetAttribute("BoothKneel") == true)
			Skin.select(stand, on) -- (D-1267)
		end
		-- (D-1267, user: "아래 정면보기/내려가기/올라가기/멈춤 버튼") ▼ / ▲ go under the
		-- picture next to 정면 보기 and 멈춤 (placed by layoutShoot)
		for _, item in ipairs({ { down, "HeightDown" }, { up, "HeightUp" } }) do
			local b = item[1] :: TextButton
			b.Name = item[2]
			b.Parent = shoot
			b.ZIndex = 3
			b.TextWrapped = false
			Skin.pressPill(b)
		end
		local function watch(character: Model)
			character:GetAttributeChangedSignal("BoothHeight"):Connect(paint)
			character:GetAttributeChangedSignal("BoothKneel"):Connect(paint)
			paint()
		end
		if player.Character then watch(player.Character) end
		player.CharacterAdded:Connect(watch)
	end
	-- (D-1183, user 2026-11-10: "오후네컷 표정 추가") the faces (BoothPose.Faces), pink
	-- while on; the same again = off. Only dynamic heads move their face.
	do
		local BoothPose = require(Shared:WaitForChild("BoothPose"))
		local faceButtons: {[string]: TextButton} = {}
		for _, f in ipairs(BoothPose.Faces) do
			faceButtons[f.key] = add(f.label, function()
				local character = player.Character
				if character and not BoothPose.faceControls(character) then
					toast("움직이는 얼굴(다이내믹 헤드)에서만 표정이 바뀌어요.")
					return
				end
				local ok, message = invoke("Face", f.key)
				if not ok and typeof(message) == "string" then toast(message) end
			end)
			faceButtons[f.key].Parent = (Skin :: any).faceList -- (D-1267: the 표정 tab)
		end
		local function paint()
			local character = player.Character
			local on = character and character:GetAttribute("BoothFace")
			for key, b in pairs(faceButtons) do
				Skin.select(b, on == key) -- (D-1267)
			end
		end
		local function watch(character: Model)
			character:GetAttributeChangedSignal("BoothFace"):Connect(paint)
			paint()
		end
		if player.Character then watch(player.Character) end
		player.CharacterAdded:Connect(watch)
	end
	for _, category in ipairs(PhotoConfig.PoseCategoryOrder) do
		for _, dance in ipairs(ClubConfig.Dances) do
			if dance.category == category then
				add(dance.name, function() danceRemote:FireServer("Start", dance.key, 1) end):SetAttribute("PoseKey", dance.key)
			end
		end
	end
	Skin.watchPoses(poseList, player) -- (D-1267: the pose being danced has a white edge)
end

local propButtons: {[string]: TextButton} = {}
local function refreshProps()
	local character = player.Character
	for key, b in pairs(propButtons) do
		local worn = false
		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Accessory") and child:GetAttribute("PhotoProp") == key then worn = true end
			end
		end
		Skin.propButton(b, worn) -- (D-1267: round, a white edge while worn)
	end
end
for index, prop in ipairs(PhotoConfig.Props) do
	local b = button({
		LayoutOrder = index,
		BackgroundColor3 = SKY_BUTTON,
		TextColor3 = SKY_TEXT,
		Text = prop.name,
		TextSize = 12,
		TextWrapped = true,
		ZIndex = 5,
	}, propList, 8)
	propButtons[prop.key] = b
	Skin.propButton(b, false)
	b.MouseButton1Click:Connect(function()
		local ok, message = invoke("Prop", prop.key)
		if not ok then toast(message) end
		task.wait(0.2)
		refreshProps()
	end)
end

local function layoutShoot()
	local vp = viewport()
	local top = topY()
	local panelW = math.clamp(math.floor(vp.X * 0.17), 112, 190)
	local maxW = vp.X - 2 * (panelW + 20)
	local maxH = vp.Y - top - 50
	local h = math.min(maxH, maxW * 3 / 4)
	local w = h * 4 / 3
	local x = (vp.X - w) / 2
	local y = top + 38 + (maxH - h) / 2
	shootWindow = { x = x, y = y, w = w, h = h }
	masks[1].Position = UDim2.fromOffset(0, 0)
	masks[1].Size = UDim2.new(1, 0, 0, y)
	masks[2].Position = UDim2.fromOffset(0, y + h)
	masks[2].Size = UDim2.new(1, 0, 1, -(y + h))
	masks[3].Position = UDim2.fromOffset(0, y)
	masks[3].Size = UDim2.fromOffset(x, h)
	masks[4].Position = UDim2.fromOffset(x + w, y)
	masks[4].Size = UDim2.new(1, -(x + w), 0, h)
	windowFrame.Position = UDim2.fromOffset(x, y)
	windowFrame.Size = UDim2.fromOffset(w, h)
	infoBar.Position = UDim2.fromOffset(vp.X / 2, top)
	-- pose and prop panels are short separate popups at the top beside the
	-- window (they scroll), so the bottom corners stay free for the move stick
	-- and the jump button (user mock-up 2026-10-26)
	-- (on a PC, without the touch controls, they run the window's full height:
	-- user 2026-10-28 (3))
	local touch = game:GetService("UserInputService").TouchEnabled
	local panelH = if touch then math.min(h, 34 * 3 + 4 * 2 + 40) else h
	-- (D-1267) the poses (포즈 / 표정 tabs) on the right, the props on the left
	panelH = math.max(panelH, 140)
	posePanel.Position = UDim2.fromOffset(x + w + 10, y)
	posePanel.Size = UDim2.fromOffset(panelW, panelH)
	for _, list in ipairs({ poseList, (Skin :: any).faceList }) do -- (D-1182) as many rows as fit, two columns in view, the rest to the right
		local grid = list:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		grid.FillDirectionMaxCells = if list == poseList then math.max(1, math.floor((panelH - 44 + 4) / 32)) else 2
		grid.CellSize = UDim2.fromOffset(math.floor((panelW - 12) / 2 - 3), 28)
	end
	local propSize = math.floor(math.clamp(panelW * 0.4, 40, 58))
	Skin.layoutProps(propPanel, propList, x - (2 * propSize + 16) - 10, y, propSize)
	tip.Position = UDim2.fromOffset(x, y + h - 24)
	tip.Size = UDim2.fromOffset(w, 20)
	do -- 정면 보기 · ▼ 내려가기 · ▲ 올라가기 · ⏸ 멈춤 in a row at the bottom of the picture
		local row = { faceFront, shoot:FindFirstChild("HeightDown"), shoot:FindFirstChild("HeightUp"), pauseButton }
		local pw = math.floor(math.min(104, (w - 60) / 4))
		local x0 = x + (w - (4 * pw + 3 * 8)) / 2
		for i, b in ipairs(row) do
			if b then
				(b :: GuiObject).Position = UDim2.fromOffset(x0 + (i - 1) * (pw + 8), y + h - 40)
				;(b :: GuiObject).Size = UDim2.fromOffset(pw, 28)
			end
		end
	end
	infoBar.Position = UDim2.fromOffset(vp.X / 2, y + 6)
	shootLeave.Position = UDim2.fromOffset(x + w - 36, y + 6)
	shootLeave.Size = UDim2.fromOffset(30, 30)
	local bracket = math.floor(math.clamp(math.min(w, h) * 0.12, 22, 48))
	for _, c in ipairs(corners) do c.Size = UDim2.fromOffset(bracket, bracket) end
end

-- (user 2026-10-27) a shutter click with every shot, a short tick on 3 · 2 · 1
-- (docs/04_ART/SOUNDS.md B)
-- (one table, not four locals: this script is near the 200-local limit)
local boothSound = (function()
	local SoundService = game:GetService("SoundService")
	local function make(id: string, volume: number): Sound
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.Parent = SoundService
		return s
	end
	return {
		shutter = make("rbxassetid://17208312548", 0.9), -- "Roblox GUI - Camera Shutter" (Roblox)
		tick = make("rbxassetid://9118777239", 0.35), -- "Scanner Beeps 5" (Pro Sound Effects)
		lastTick = 0,
	}
end)()
local function flashShot()
	boothSound.shutter.TimePosition = 0
	boothSound.shutter:Play()
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
end

-- The move stick draws over the shoot screen while shooting on a phone (the
-- photo gui has DisplayOrder 40 and would cover it).
local touchGuiOrder: number? = nil
local function liftTouchGui(on: boolean)
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if not touchGui or not touchGui:IsA("ScreenGui") then return end
	if on and touchGuiOrder == nil then
		touchGuiOrder = touchGui.DisplayOrder
		touchGui.DisplayOrder = 41
	elseif not on and touchGuiOrder ~= nil then
		touchGui.DisplayOrder = touchGuiOrder
		touchGuiOrder = nil
	end
end

-- Each cut is also captured from the real scene the moment it is taken
-- (device captures draw ViewportFrame photos almost black, ISSUE-PHOTO-005):
-- for that frame every screen gui is off and the camera is the booth camera.
-- The last cut used to catch the pick screen that opens right after it (a
-- black capture, user phone test 2026-10-26): the whole photo gui is off now
-- too. The picked cuts are offered to the gallery by "📸 캡처 저장".
local cutCaptures: {[number]: string} = {}
local cutCount = 0
local function captureCut(index: number)
	local ok = pcall(function()
		local CaptureService = game:GetService("CaptureService")
		local hidden = {}
		for _, other in ipairs(playerGui:GetChildren()) do
			if other:IsA("ScreenGui") and other.Enabled then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end
		local restored = false
		local function restore()
			if restored then return end
			restored = true
			for _, item in ipairs(hidden) do item.Enabled = true end
			if state.stage ~= "shooting" then restoreCamera() end
		end
		applyShootCamera()
		RunService.RenderStepped:Wait()
		CaptureService:CaptureScreenshot(function(contentId)
			cutCaptures[index] = contentId
			restore()
		end)
		task.delay(1, restore)
	end)
	if not ok then cutCaptures[index] = nil end
end

--------------------------------------------------
-- 4. 사진을 골라주세요 / 5. 프레임 / 6. 결과
--------------------------------------------------

local pick = overlay("Pick")
local pickTitle = text({
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, 0, 0, 30),
	Text = "사진을 골라주세요!",
	TextColor3 = COLORS.yellow,
	TextSize = 22,
	ZIndex = 11,
}, pick)
local pickTimer = text({
	Size = UDim2.new(1, 0, 0, 18),
	Text = "",
	TextColor3 = COLORS.sub,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
	ZIndex = 11,
}, pick)
local pickGrid = create("Frame", { Name = "Grid", BackgroundTransparency = 1, ZIndex = 11 }, pick)
local pickPreview = create("Frame", { Name = "Preview", BackgroundTransparency = 1, ZIndex = 11 }, pick)
local pickDone = button({
	Name = "DoneButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(220, 40),
	BackgroundColor3 = COLORS.yellow,
	TextColor3 = Color3.fromRGB(60, 40, 10),
	Text = "선택 완료",
	TextSize = 17,
	ZIndex = 12,
}, pick, 14)
-- frame step reuses the same overlay with a swatch area instead of the grid
local frameArea = create("Frame", { Name = "Frames", BackgroundTransparency = 1, Visible = false, ZIndex = 11 }, pick)
local result = overlay("Result")
boxify(pick)
boxify(result)
PhotoFlowUI.icon(pick, "📷", 12)
-- (D-1267) white header text, grey 남은 시간, a grey / red 다음으로 ▶ pill
pickTitle.TextColor3 = Skin.C.white
pickTitle.Font = Skin.FONT
pickTimer.TextColor3 = Skin.C.sub
pickTimer.Font = Skin.FONT
Skin.pill(pickDone, "card")
pickDone.TextSize = 13

local pickCells: {ViewportFrame} = {}
local pickBadges: {TextLabel} = {}
local previewStrip: any = nil

-- (user mock-up 2026-10-30, docs/04_ART/references/photo_ui_redesign_2026-10-30.png)
-- picking: header top-left, the 8 shots left, a divider, the strip right with
-- 선택 완료 under it; frame: tabs and frame previews across, the button
-- centred below; copies: the finished strip left, the copies panel right
local function layoutPick()
	local bw, bh = placeBox(pick, "flow")
	PhotoFlowUI.placeHeader(pickTitle, pickTimer, bw)
	-- (D-1267) white icons: a camera while picking / choosing the frame, a picture when done
	Skin.headerIcon(pick, if state.stage == "copies" then Skin.Icons.picture else Skin.Icons.camera)
	local divider = PhotoFlowUI.divider(pick, 11)
	local areaTop = 44
	local stage = state.stage
	divider.Visible = false -- (D-1267: no line, the strip sits on a grey card)
	Skin.previewCard(pick, pickPreview, stage == "picking")
	if stage == "frame" then
		pickPreview.Visible = false
		frameArea.Position = UDim2.fromOffset(12, areaTop)
		frameArea.Size = UDim2.fromOffset(bw - 24, bh - areaTop - 12)
		-- (D-1267) 선택 완료 at the bottom right, on the frame box's edge
		pickDone.AnchorPoint = Vector2.new(1, 1)
		pickDone.Size = UDim2.fromOffset(96, 28)
		pickDone.Position = UDim2.new(1, -16, 1, -8)
		Skin.frameBox(frameArea, 28, 8)
		-- five frame previews to a row, one row in view (more rows scroll)
		local list = frameArea:FindFirstChild("Swatches")
		local grid = list and list:FindFirstChildOfClass("UIGridLayout")
		if grid then
			local w, h = bw - 24, bh - areaTop - 12 - 70 - 16 -- (the list's own height, the name under the strip in view)
			grid.CellSize = UDim2.fromOffset(math.floor((w - 6 - 8 - 4 * 12 - 16) / 5), math.max(60, h))
			grid.CellPadding = UDim2.fromOffset(12, 10)
		end
		if list then
			(list :: ScrollingFrame).Position = UDim2.fromOffset(10, 40)
			;(list :: ScrollingFrame).Size = UDim2.new(1, -20, 1, -40 - 30)
		end
		return
	end
	local areaH = bh - areaTop - 12
	local previewW = math.floor(math.min(bw * 0.3, (areaH - 50) * PhotoRender.stripAspect(state.shots and state.shots.layout or "1x4") * 1.02))
	pickPreview.Visible = true
	if stage == "copies" then
		divider.Visible = false
		local leftW = math.floor(bw * 0.36)
		pickPreview.Position = UDim2.fromOffset(12 + math.floor((leftW - previewW) / 2), areaTop)
		pickPreview.Size = UDim2.fromOffset(previewW, areaH)
		frameArea.Position = UDim2.fromOffset(12 + leftW + 12, areaTop)
		frameArea.Size = UDim2.fromOffset(bw - leftW - 36, areaH)
		return
	end
	-- (D-1267) the strip on a grey card at the right, 다음으로 ▶ under the card
	local cardW = previewW + 20
	pickGrid.Position = UDim2.fromOffset(16, areaTop + 4)
	pickGrid.Size = UDim2.fromOffset(bw - cardW - 16 - 16 - 16, areaH - 4)
	frameArea.Position = pickGrid.Position
	frameArea.Size = pickGrid.Size
	pickPreview.Position = UDim2.fromOffset(bw - cardW - 16 + 10, areaTop + 10)
	pickPreview.Size = UDim2.fromOffset(previewW, areaH - 46 - 20)
	Skin.previewCard(pick, pickPreview, true)
	pickDone.AnchorPoint = Vector2.new(0, 1)
	pickDone.Size = UDim2.fromOffset(cardW, 26)
	pickDone.Position = UDim2.new(0, bw - cardW - 16, 1, -12)
	-- (D-1267, user: "이미지는 9칸인데 8칸만 하고 마지막 칸에 네모 없이 오후 로고 넣기")
	-- a 3 × 3 grid of 4:3 cells, the 9th the OHU logo
	local gw = pickGrid.Size.X.Offset
	local cellW = math.min((gw - 2 * 10) / 3, (areaH - 4 - 2 * 10) / 3 * 4 / 3)
	local cellH = cellW * 3 / 4
	for index, cell in ipairs(pickCells) do
		local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
		cell.Position = UDim2.fromOffset(col * (cellW + 10), row * (cellH + 10))
		cell.Size = UDim2.fromOffset(cellW, cellH)
	end
	local logo = pickGrid:FindFirstChild("LogoCell") :: GuiObject?
	if logo then
		logo.Position = UDim2.fromOffset(2 * (cellW + 10), 2 * (cellH + 10))
		logo.Size = UDim2.fromOffset(cellW, cellH)
	end
end

local function peopleOf(shots: Shots): {[number]: any}
	return PhotoRender.peopleMap(shots.people)
end

local function refreshPreview()
	local shots = state.shots
	if not shots or not previewStrip then return end
	local chosen = {}
	for _, index in ipairs(state.picks) do table.insert(chosen, shots.shots[index]) end
	PhotoRender.fillStrip(previewStrip, chosen, peopleOf(shots), shots.booth)
end

local function refreshPickBadges()
	for index, badge in ipairs(pickBadges) do
		local order = table.find(state.picks, index)
		badge.Visible = false -- (D-1267: the picked cells show a white edge; the order shows in the strip)
		badge.Text = if order then tostring(order) else ""
		local stroke = pickCells[index]:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = if order then 0 else 1 end
	end
	if state.stage == "frame" then
		-- the frame step has its own title (openFrameStep)
		pickTitle.Text = if state.isPicker then "프레임을 선택하세요!" else state.pickerName .. "님이 프레임을 고르는 중…"
	elseif state.isPicker then
		pickTitle.Text = string.format("사진을 골라주세요! (%d/%d)", #state.picks, PhotoConfig.PickCount)
	else
		pickTitle.Text = string.format("%s님이 사진을 고르는 중… (%d/%d)", state.pickerName, #state.picks, PhotoConfig.PickCount)
	end
	pickDone.Visible = state.isPicker
	-- (D-1267, user: "사진 4개 선택하면 다음으로 버튼 붉은색으로 활성화 됨")
	if state.stage ~= "frame" then
		local ready = #state.picks == PhotoConfig.PickCount
		Skin.pill(pickDone, if ready then "accent" else "card", ready)
	end
end

-- The picker's every change goes to the others (they watch live).
local function sendPick()
	if not state.isPicker then return end
	local stage = if state.stage == "frame" then "frame" else "picking"
	task.spawn(invoke, "PickUpdate", { picks = state.picks, frame = state.frame, stage = stage })
end

local function newPreview()
	for _, child in ipairs(pickPreview:GetChildren()) do child:Destroy() end
	local shots = state.shots
	if not shots then return end
	previewStrip = PhotoRender.newStrip(pickPreview, shots.layout, state.frame, "OHU")
end

-- Who picks (booth attribute "Picker"). Returns true when my role changed.
local function refreshPickerRole(): boolean
	local booth = state.booth
	local id = booth and booth:GetAttribute("Picker")
	local was = state.isPicker
	state.isPicker = id == player.UserId
	local picker = if typeof(id) == "number" then Players:GetPlayerByUserId(id) else nil
	state.pickerName = if picker then picker.DisplayName else "호스트"
	return was ~= state.isPicker
end

local function openPick(shots: Shots)
	refreshPickerRole()
	state.shots = shots
	state.picks = {}
	state.frame = "white"
	state.stage = "picking"
	restoreCamera()
	shoot.Visible = false
	for _, child in ipairs(pickGrid:GetChildren()) do child:Destroy() end
	table.clear(pickCells)
	table.clear(pickBadges)
	local people = peopleOf(shots)
	for index, shot in ipairs(shots.shots) do
		local cell = create("ViewportFrame", {
			Name = "Shot" .. index,
			BackgroundColor3 = Skin.C.cell, -- (D-1267: light cells, a white edge when picked)
			BorderSizePixel = 0,
			ZIndex = 12,
		}, pickGrid)
		corner(cell, 6)
		create("UIStroke", { Color = Skin.C.white, Thickness = 3, Transparency = 1 }, cell)
		local badge = text({
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = COLORS.pink,
			BackgroundTransparency = 0,
			Text = "",
			TextSize = 15,
			Visible = false,
			ZIndex = 14,
		}, cell)
		corner(badge, 13)
		local hit = create("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 15,
		}, cell)
		hit.MouseButton1Click:Connect(function()
			if state.stage ~= "picking" then return end
			if not state.isPicker then
				toast(state.pickerName .. "님이 고르고 있어요. 함께 구경해요!")
				return
			end
			local at = table.find(state.picks, index)
			if at then
				table.remove(state.picks, at)
			elseif #state.picks < PhotoConfig.PickCount then
				table.insert(state.picks, index)
			else
				toast(string.format("%d장까지 고를 수 있어요. 고른 사진을 다시 누르면 빠져요.", PhotoConfig.PickCount))
				return
			end
			refreshPickBadges()
			refreshPreview()
			sendPick()
		end)
		table.insert(pickCells, cell)
		table.insert(pickBadges, badge)
		PhotoRender.queueShot(cell, shot, people, shots.booth)
	end
	Skin.logoCell(pickGrid, 12) -- (D-1267: the 9th cell)
	pickGrid.Visible = true
	frameArea.Visible = false
	pickDone.Text = "다음으로 ▶"
	newPreview()
	layoutPick()
	refreshPickBadges()
	refreshPreview()
	pick.Visible = true
end

-- Frame step
local frameTabRow = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 12 }, frameArea)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frameTabRow)
local swatches = create("ScrollingFrame", {
	Name = "Swatches",
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 1, -40),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 12,
}, frameArea)
create("UIGridLayout", { CellSize = UDim2.fromOffset(84, 70), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, swatches)
-- (room round the cards so the chosen one's pink edge clears the tabs, user 2026-10-30)
create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, swatches)
-- frame previews built for the open tab (key → its stroke), so picking one
-- only moves the highlight
local frameCards: {[string]: UIStroke} = {}
local frameTab = PhotoConfig.FrameTabs[1]
local tabButtons: {[string]: TextButton} = {}

-- Frame ownership (EconomyService mirrors it as player attributes).
local function ownsFrame(info: any): boolean
	if info.price == "free" then return true end
	if info.price == "pass" then return player:GetAttribute("Pass_FramePack") == true end
	local raw = player:GetAttribute("OwnedFrames")
	local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and typeof(list) == "table" and table.find(list, info.key) ~= nil
end

-- The 저장 button says what saving with the chosen frame needs.
local function refreshSaveButton()
	if state.stage ~= "frame" then return end
	local info = PhotoConfig.findFrame(state.frame)
	if info and not ownsFrame(info) then
		pickDone.Text = if info.price == "coins"
			then string.format("💰 %d 구매 후 저장", info.coins or 0)
			else string.format("프레임 팩 R$%d", MonetizationConfig.GamePasses.FramePack.price)
		Skin.pill(pickDone, "accent", true)
		pickDone.BackgroundColor3 = if info.price == "coins" then Color3.fromRGB(230, 170, 40) else Color3.fromRGB(0, 176, 111)
	else
		pickDone.Text = "선택 완료"
		Skin.pill(pickDone, "accent", true) -- (D-1267)
	end
end

-- Each frame of the open tab as a card with the picked shots already in it
-- (user 2026-10-30: see the photo in the frame), its name / price under it.
local function renderSwatches()
	for _, child in ipairs(swatches:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(frameCards)
	local shots = state.shots
	local chosen = {}
	if shots then for _, index in ipairs(state.picks) do table.insert(chosen, shots.shots[index]) end end
	for index, info in ipairs(PhotoConfig.Frames) do
		if info.tab == frameTab then
			local card = button({
				Name = "Frame_" .. info.key,
				LayoutOrder = index,
				BackgroundColor3 = Skin.C.cardLight, -- (D-1267: light grey card, a white edge when chosen)
				AutoButtonColor = false,
				Text = "",
				ZIndex = 13,
			}, swatches, 12)
			frameCards[info.key] = create("UIStroke", {
				Color = Skin.C.white,
				Thickness = 3,
				Transparency = if state.frame == info.key then 0 else 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, card)
			local holder = create("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -30), BackgroundTransparency = 1, ZIndex = 13 }, card)
			if shots then
				local strip = PhotoRender.newStrip(holder, shots.layout, info.key, "OHU")
				strip.frame.ZIndex = 14
				PhotoRender.fillStrip(strip, chosen, peopleOf(shots), shots.booth)
			end
			text({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -6, 0, 18),
				Text = (if ownsFrame(info) then "" else "🔒 ") .. info.name
					.. (if ownsFrame(info) then "" else " · " .. PhotoConfig.priceText(info)),
				TextColor3 = Skin.C.white,
				Font = Skin.FONT,
				TextSize = 11,
				TextScaled = false,
				ZIndex = 14,
			}, card)
			card.MouseButton1Click:Connect(function()
				if not state.isPicker then return end
				state.frame = info.key
				if previewStrip then previewStrip.setColor(info.key) end
				for key, stroke in pairs(frameCards) do stroke.Transparency = if key == info.key then 0 else 1 end
				refreshSaveButton()
				sendPick()
			end)
		end
	end
	Skin.paintTabs(tabButtons, frameTab) -- (D-1267: folder tabs, the open one with a white edge)
end
for index, name in ipairs(PhotoConfig.FrameTabs) do
	local tab = button({
		LayoutOrder = index,
		Size = UDim2.new(1 / #PhotoConfig.FrameTabs, -4, 1, 0),
		Text = name,
		TextSize = 13,
		ZIndex = 13,
	}, frameTabRow, 15)
	tabButtons[name] = tab
	tab.MouseButton1Click:Connect(function()
		frameTab = name
		renderSwatches()
	end)
end

local function openFrameStep()
	state.stage = "frame"
	pickGrid.Visible = false
	frameArea.Visible = true
	pickTitle.Text = if state.isPicker then "프레임을 선택하세요!" else state.pickerName .. "님이 프레임을 고르는 중…"
	pickDone.Visible = state.isPicker
	pickTimer.Text = "마음에 드는 프레임을 골라 보세요"
	layoutPick()
	renderSwatches()
	refreshSaveButton()
end
for _, name in ipairs({ "Coins", "OwnedFrames", "Pass_FramePack" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		if state.stage == "frame" then
			renderSwatches()
			refreshSaveButton()
		end
	end)
end

-- Result: big photo + 캡처 저장 / 사진첩 / 닫기
local resultHolder = create("Frame", { BackgroundTransparency = 1, ZIndex = 11 }, result)
local resultButtons = create("Frame", { BackgroundTransparency = 1, ZIndex = 11 }, result)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, resultButtons)
local resultTitle = text({
	Size = UDim2.new(1, 0, 0, 28),
	Text = "사진첩에 저장했어요!",
	TextColor3 = COLORS.yellow,
	TextSize = 20,
	ZIndex = 11,
}, result)

local openAlbum: (() -> ())? = nil

-- Roblox capture → "save to device" window. Buttons are hidden for the shot.
local function captureToGallery(hide: {GuiObject})
	local ok = pcall(function()
		local CaptureService = game:GetService("CaptureService")
		for _, item in ipairs(hide) do item.Visible = false end
		task.wait(0.15)
		CaptureService:CaptureScreenshot(function(contentId)
			for _, item in ipairs(hide) do item.Visible = true end
			pcall(function()
				CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
			end)
		end)
	end)
	if not ok then
		for _, item in ipairs(hide) do item.Visible = true end
		toast("이 기기에서는 캡처 저장을 할 수 없어요. (Studio에서는 동작하지 않을 수 있어요)")
	end
end

local function resultButton(label: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local b = button({
		LayoutOrder = order,
		Size = UDim2.new(1 / 4, -6, 1, 0), -- (four since D-1126)
		TextWrapped = true,
		BackgroundColor3 = color,
		Text = label,
		TextSize = 14,
		ZIndex = 12,
	}, resultButtons, 10)
	-- (D-1267) pills: red-brown for the saves, grey for the rest
	Skin.pill(b, if color == COLORS.pink then "accent" else "card")
	b.TextSize = 12
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function closeAllFlow()
	pick.Visible = false
	result.Visible = false
	shoot.Visible = false
	waitBar.Visible = false
	liftTouchGui(false)
	-- (D-1267, found in the test: after 닫기 the camera was still the booth camera,
	-- Scriptable, when the last cut's capture had turned it after the pick screen
	-- opened) the flow is over: the camera always goes back to the player
	if workspace.CurrentCamera and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then state.cameraSaved = true end
	restoreCamera()
	require(script.Parent:WaitForChild("PhotoMotionReel")).hideStools(nil, false) -- (D-1139)
	state.stage = "none"
	state.shots = nil
	previewStrip = nil
	Popups.closed("PhotoResult")
end

Skin.iconButton(resultButton("캡처 저장", COLORS.pink, 1, function()
	-- the picked cuts as captured from the real scene (falls back to a
	-- screenshot of this screen when the device made no captures)
	local list = {}
	for _, index in ipairs(state.picks or {}) do
		if cutCaptures[index] then table.insert(list, cutCaptures[index]) end
	end
	if #list == 0 then
		for i = 1, cutCount do if cutCaptures[i] then table.insert(list, cutCaptures[i]) end end
	end
	if #list > 0 then
		local ok = pcall(function()
			game:GetService("CaptureService"):PromptSaveCapturesToGallery(list, function() end)
		end)
		if ok then return end
	end
	captureToGallery({ resultButtons, resultTitle })
end), Skin.Icons.camera) -- (D-1267: white icons in the pills)
-- (D-1126, user 2026-11-10) the picked cuts as a video: the seconds before
-- each shot from the booth camera, then the shot held still (PhotoMotionReel),
-- recorded and offered to the device gallery to share
Skin.iconButton(resultButton("영상 저장", COLORS.pink, 2, function()
	if require(script.Parent:WaitForChild("PhotoMotionReel")).isPlaying() then return end
	require(script.Parent:WaitForChild("PhotoMotionReel")).play(state.picks or {}, function(message)
		if message then toast(message, 7) end -- (D-1266: long enough to read around the share screen)
	end)
end), Skin.Icons.clapper)
Skin.iconButton(resultButton("가방에서 보기", COLORS.card, 3, function()
	closeAllFlow()
	require(script.Parent:WaitForChild("BagSignals")).openBag:Fire("photos")
end), Skin.Icons.bag)
resultButton("닫기", COLORS.card, 4, closeAllFlow)

-- (user mock-up 2026-10-30) a soft card with a pink check in the middle,
-- "사진이 저장되었어요!", and the three buttons in a row under it
local function layoutResult()
	local bw, bh = placeBox(result, "flow")
	resultTitle.Visible = false
	local rowW = math.floor(math.min(bw - 48, 460))
	-- the card (150 high) and the button row as one block, centred
	local top = math.max(16, math.floor((bh - 150 - 20 - 40) / 2))
	resultHolder.Position = UDim2.fromOffset(24, top)
	resultHolder.Size = UDim2.fromOffset(bw - 48, 150)
	resultButtons.Position = UDim2.fromOffset(math.floor((bw - rowW) / 2), top + 170 + math.floor((bh - (top + 210)) / 2)) -- (half of the gap under them, user 2026-10-30)
	resultButtons.Size = UDim2.fromOffset(rowW, 40)
end

local function showResult(saved: any)
	state.stage = "result"
	pick.Visible = false
	if previewStrip then previewStrip.frame:Destroy() end
	previewStrip = nil
	layoutResult()
	local _, _, savedSub = PhotoFlowUI.savedPanel(resultHolder, 12)
	result.Visible = true
	Popups.opened("PhotoResult", closeAllFlow)
	local count = if typeof(saved) == "table" then saved.count else nil
	savedSub.Text = if count then string.format("가방의 사진 칸에서 볼 수 있어요 (%d/%d)", count, saved.max or PhotoConfig.MaxPhotos) else "가방의 사진 칸에서 볼 수 있어요"
	require(script.Parent:WaitForChild("BagSignals")).photosChanged:Fire()
	if typeof(saved) == "table" and not saved.persistent and saved.note then toast("사진첩: " .. tostring(saved.note)) end
end

pickDone.MouseButton1Click:Connect(function()
	if state.stage == "picking" then
		if #state.picks ~= PhotoConfig.PickCount then
			toast(string.format("사진을 %d장 골라 주세요.", PhotoConfig.PickCount))
			return
		end
		openFrameStep()
		sendPick()
	elseif state.stage == "frame" then
		local info = PhotoConfig.findFrame(state.frame)
		if info and not ownsFrame(info) then
			if info.price == "coins" then
				-- Buy with coins, then save in one go.
				local bought, message = invoke("BuyFrame", info.key)
				toast(message)
				if not bought then return end
			else
				local pass = MonetizationConfig.GamePasses.FramePack
				if pass.id ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				elseif RunService:IsStudio() then
					local ok, message = clubShopRemote:InvokeServer("StudioTestBuy", { kind = "pass", key = "FramePack" })
					toast(if ok then "[Studio 테스트] 프레임 팩을 받았어요." else message)
				else
					toast("준비 중인 상품입니다.")
				end
				return
			end
		end
		-- Done picking: everyone moves on to "몇 장 저장할까요?" ("Copies").
		pickDone.Text = "잠시만요..."
		pickDone:SetAttribute("Saving", true)
		local ok, message = invoke("Confirm", { picks = state.picks, frame = state.frame, stage = "frame" })
		pickDone:SetAttribute("Saving", nil)
		if not ok then
			pickDone.Text = "선택 완료"
			toast(message)
		end
	end
end)

-- "몇 장 저장할까요?" for everyone (the final shots and frame from the picker).
local function openCopies(info: any)
	state.stage = "copies"
	if typeof(info.picks) == "table" then state.picks = info.picks end
	if typeof(info.frame) == "string" then
		state.frame = info.frame
		if previewStrip then previewStrip.setColor(info.frame) end
	end
	refreshPreview()
	pickGrid.Visible = false
	frameArea.Visible = true
	pickDone.Visible = false
	pickTitle.Text = "사진 완성!"
	layoutPick() -- (the strip moves left, the copies panel goes right)
	for _, child in ipairs(frameArea:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "CopiesPanel" then child.Visible = false end
	end
	PhotoCopiesPanel.open(frameArea, { free = info.free or 1, price = info.price or 0, max = info.max or 1 }, 13, function(count)
		pickDone:SetAttribute("Saving", true)
		local ok, saved = invoke("SaveCopies", count)
		pickDone:SetAttribute("Saving", nil)
		if ok then
			local panel = frameArea:FindFirstChild("CopiesPanel")
			if panel then panel:Destroy() end
			for _, child in ipairs(frameArea:GetChildren()) do
				if child:IsA("GuiObject") then child.Visible = true end
			end
			showResult(saved)
		else
			toast(saved)
		end
	end)
end

--------------------------------------------------
-- Album (📷)
--------------------------------------------------

local albumButton = create("TextButton", {
	Name = "AlbumButton",
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	-- 🖼 album; 📸 is the Roblox capture button (CameraController).
	Text = "🖼",
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.text,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, albumButton)
-- (user 2026-10-30, later) no 내 앨범 button: the photos are in the 🎒 bag's
-- 사진 tab (InventoryController); the album window stays only for the code
-- that still opens it, and its viewer shows the bag's photos
albumButton.Parent = nil

local album = overlay("Album")
boxify(album)
-- 내 앨범 (user mock-up 2026-10-30): header with the pink icon, 전체 삭제 at
-- the top right, a card per photo with its date / time and a trash button
local albumTitle = text({
	Size = UDim2.new(1, -120, 0, 30),
	Text = "내 앨범",
	TextColor3 = COLORS.yellow,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, album)
local albumSub = text({
	Text = "",
	TextColor3 = COLORS.sub,
	Font = Enum.Font.GothamMedium,
	ZIndex = 11,
}, album)
PhotoFlowUI.icon(album, "🖼", 12)
local albumDeleteAll = button({
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(96, 32),
	BackgroundColor3 = Color3.fromRGB(44, 42, 54),
	Text = "🗑 전체 삭제",
	TextSize = 13,
	ZIndex = 12,
}, album, 10)
local albumClose = button({
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(32, 32),
	Text = "X",
	TextSize = 15,
	ZIndex = 12,
}, album, 16)
local albumList = create("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 11,
}, album)
local albumGrid = create("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, albumList)
local albumEmpty = text({
	Size = UDim2.new(1, 0, 0, 60),
	Text = "아직 사진이 없어요. 인생네컷 가게(클럽과 공원 사이)에서 찍어 보세요!",
	TextColor3 = COLORS.sub,
	TextSize = 15,
	TextWrapped = true,
	Visible = false,
	ZIndex = 11,
}, album)
-- Viewer for one photo
local viewer = overlay("Viewer")
viewer.ZIndex = 20
boxify(viewer)
local viewerHolder = create("Frame", { BackgroundTransparency = 1, ZIndex = 21 }, viewer)
local viewerButtons = create("Frame", { BackgroundTransparency = 1, ZIndex = 21 }, viewer)
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, viewerButtons)
local viewerPhoto: any = nil
local function viewerButton(label: string, color: Color3, order: number): TextButton
	return button({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = color,
		Text = label,
		TextSize = 15,
		ZIndex = 22,
	}, viewerButtons, 12)
end
local viewerCapture = viewerButton("📸 캡처 저장", COLORS.pink, 1)
local viewerDelete = viewerButton("삭제", COLORS.danger, 2)
local viewerClose = viewerButton("닫기", COLORS.card, 3)
-- 🤚 손에 들기: the photo as an item in the hand (it was taken out on every tap in 내 앨범)
viewerButton("🤚 손에 들기", COLORS.card, 0).MouseButton1Click:Connect(function()
	local photo = viewerPhoto
	if not photo then return end
	local ok, message = invoke("TakeOut", photo.id)
	toast(message)
	if not ok then return end
	task.wait(0.3)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if humanoid and backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("PhotoId") == photo.id then humanoid:EquipTool(tool) end
		end
	end
	viewer.Visible = false
end)

local function layoutAlbum()
	local bw, bh = placeBox(album, "album")
	placeBox(viewer, "album")
	PhotoFlowUI.placeHeader(albumTitle, albumSub, bw - 150)
	albumClose.Position = UDim2.new(1, -10, 0, 10)
	albumDeleteAll.Position = UDim2.new(1, -50, 0, 10)
	albumList.Position = UDim2.fromOffset(12, 56)
	albumList.Size = UDim2.fromOffset(bw - 24, bh - 66)
	albumEmpty.Position = UDim2.fromOffset(0, 80)
	-- four cards to a row; a card = the strip + date / time + trash
	local cellW = math.floor((bw - 24 - 6 - 3 * 10) / 4)
	local cellH = math.clamp(math.floor(bh - 76), 170, 320)
	albumGrid.CellSize = UDim2.fromOffset(cellW, cellH)
	local buttonsW = math.floor(math.min(160, bw * 0.34))
	viewerHolder.Position = UDim2.fromOffset(12, 12)
	viewerHolder.Size = UDim2.fromOffset(bw - buttonsW - 36, bh - 24)
	viewerButtons.Position = UDim2.fromOffset(bw - buttonsW - 12, 40)
	viewerButtons.Size = UDim2.fromOffset(buttonsW, 190)
end

local albumGeneration = 0
local function renderAlbum()
	albumGeneration += 1
	local generation = albumGeneration
	for _, child in ipairs(albumList:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	albumSub.Text = "불러오는 중..."
	-- (D-1125) the album opened: "사진을 다시 확인" for the analytics (AnalyticsStep)
	local gate = Remotes:FindFirstChild("AnalyticsStep")
	if gate and gate:IsA("RemoteEvent") then gate:FireServer("AlbumOpen") end
	local ok, data = invoke("GetAlbum", nil)
	if generation ~= albumGeneration then return end
	if not ok or typeof(data) ~= "table" then
		albumSub.Text = ""
		toast(if typeof(data) == "string" then data else "내 앨범을 불러오지 못했어요.")
		return
	end
	local photos = data.photos or {}
	albumSub.Text = string.format("%d/%d장 · 사진을 누르면 가방에 넣을 수 있어요", #photos, data.max or PhotoConfig.MaxPhotos)
	albumEmpty.Visible = #photos == 0
	albumDeleteAll.Visible = #photos > 0
	for index, photo in ipairs(photos) do
		local cell, holder, trash = PhotoFlowUI.albumCard(albumList, index, photo.createdAt, 12)
		PhotoRender.drawPhoto(holder, photo)
		trash.MouseButton1Click:Connect(function()
			PhotoFlowUI.confirm(gui, "사진을 삭제할까요?", "삭제한 사진은 복구할 수 없어요.", "삭제", function()
				local deleted, message = invoke("DeletePhoto", photo.id)
				toast(if deleted then "사진을 삭제했어요." else message)
				if deleted then task.spawn(renderAlbum) end
			end)
		end)
		cell.MouseButton1Click:Connect(function()
			viewerPhoto = photo
			for _, child in ipairs(viewerHolder:GetChildren()) do child:Destroy() end
			PhotoRender.drawPhoto(viewerHolder, photo)
			viewerDelete.Text = "삭제"
			viewer.Visible = true
			-- Tapping a photo also puts it in the inventory (user, 2026-10-20).
			task.spawn(function()
				local _, message = invoke("TakeOut", photo.id)
				toast(message)
			end)
		end)
	end
end

local closeAlbum: () -> ()
openAlbum = function()
	if state.stage ~= "none" then return end
	layoutAlbum()
	album.Visible = true
	albumButton.BackgroundColor3 = COLORS.pink
	task.spawn(renderAlbum)
	Popups.opened("Album", closeAlbum)
end
closeAlbum = function()
	Popups.closed("Album")
	album.Visible = false
	viewer.Visible = false
	albumButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	for _, child in ipairs(albumList:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end
albumButton.MouseButton1Click:Connect(function()
	if album.Visible then closeAlbum() elseif openAlbum then openAlbum() end
end)
-- no album while shooting (user 2026-10-26)
shoot:GetPropertyChangedSignal("Visible"):Connect(function()
	albumButton.Visible = not shoot.Visible
end)
albumClose.MouseButton1Click:Connect(closeAlbum)
viewerClose.MouseButton1Click:Connect(function() viewer.Visible = false end)
viewerCapture.MouseButton1Click:Connect(function()
	captureToGallery({ viewerButtons })
end)
viewerDelete.MouseButton1Click:Connect(function()
	local photo = viewerPhoto
	if not photo then return end
	PhotoFlowUI.confirm(gui, "사진을 삭제할까요?", "삭제한 사진은 복구할 수 없어요.", "삭제", function()
		local ok, message = invoke("DeletePhoto", photo.id)
		if ok then
			viewer.Visible = false
			toast("사진을 삭제했어요.")
			require(script.Parent:WaitForChild("BagSignals")).photosChanged:Fire()
			if album.Visible then task.spawn(renderAlbum) end
		else
			toast(message)
		end
	end)
end)
albumDeleteAll.MouseButton1Click:Connect(function()
	PhotoFlowUI.confirm(gui, "모든 사진을 삭제할까요?", "내 앨범의 사진이 모두 지워지고 복구할 수 없어요.", "전체 삭제", function()
		local ok, message = invoke("DeleteAllPhotos", nil)
		toast(if ok then "모든 사진을 삭제했어요." else message)
		if ok then task.spawn(renderAlbum) end
	end)
end)
-- the bag's 사진 tab shows a photo in the viewer (user 2026-10-30, later)
require(script.Parent:WaitForChild("BagSignals")).viewPhoto.Event:Connect(function(photo: any)
	if typeof(photo) ~= "table" then return end
	layoutAlbum()
	viewerPhoto = photo
	for _, child in ipairs(viewerHolder:GetChildren()) do child:Destroy() end
	PhotoRender.drawPhoto(viewerHolder, photo)
	viewer.Visible = true
end)

--------------------------------------------------
-- Booth state → screens
--------------------------------------------------

local function myBooth(): Model?
	for _, booth in ipairs(CollectionService:GetTagged("PhotoBooth")) do
		local raw = booth:GetAttribute("People")
		if typeof(raw) == "string" then
			local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and typeof(list) == "table" and table.find(list, player.UserId) then
				return booth :: Model
			end
		end
	end
	return nil
end

local function peopleCount(booth: Model): number
	local raw = booth:GetAttribute("People")
	local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(list) == "table" then #list else 0
end

local function modeName(key: any): string
	for _, mode in ipairs(PhotoConfig.Modes) do
		if mode.key == key then return mode.name end
	end
	return ""
end

local function update()
	local booth = myBooth()
	if booth then state.booth = booth end
	local phase = if booth then booth:GetAttribute("Phase") else nil
	if phase == "waiting" then
		if album.Visible then closeAlbum() end
		local fresh = state.stage ~= "waiting"
		state.stage = "waiting"
		local vp = viewport()
		-- (D-1267: at the top under the top bar, the user's design; was at the bottom)
		waitBar.Position = UDim2.fromOffset(vp.X / 2, topY())
		waitBar.Size = UDim2.fromOffset(math.min(420, vp.X - 30), 46)
		local exact = math.max(0, (booth :: Model):GetAttribute("WaitUntil") - workspace:GetServerTimeNow())
		local left = math.ceil(exact)
		local host = (booth :: Model):GetAttribute("Host") == player.UserId
		waitText.Text = string.format("%d 초 후 촬영 시작·%d/%d명·%s", left, peopleCount(booth :: Model), PhotoConfig.MaxPeople, modeName((booth :: Model):GetAttribute("Mode")))
		waitCount(exact, if fresh then 1 else 0)
		waitStart.Visible = host
		waitLeave.AnchorPoint = Vector2.new(1, 0.5)
		waitLeave.Position = UDim2.new(1, -10, 0.5, 0)
		waitLeave.Size = UDim2.fromOffset(78, 26)
		waitBar.Visible = true
	elseif phase == "shooting" then
		waitBar.Visible = false
		if state.stage ~= "shooting" then
			state.stage = "shooting"
			table.clear(cutCaptures)
			cutCount = 0
			require(script.Parent:WaitForChild("PhotoMotionReel")).begin((booth :: Model):GetPivot().Position) -- (D-1126: the moves before each shot)
			require(script.Parent:WaitForChild("PhotoMotionReel")).hideStools(booth, true) -- (D-1139: the booth's stools out of the shots)
			layoutShoot()
			shoot.Visible = true
			liftTouchGui(true)
			refreshProps()
		end
		applyShootCamera()
		local index = (booth :: Model):GetAttribute("ShotIndex") or 0
		local left = math.max(0, (booth :: Model):GetAttribute("NextShotAt") - workspace:GetServerTimeNow())
		;(Skin :: any).setShootInfo(index, PhotoConfig.ShotCount, math.ceil(left)) -- (D-1267)
		local character = player.Character
		local paused = character and typeof(character:GetAttribute("DancePause")) == "number"
		pauseButton.Text = if paused then "▶ 계속" else "⏸ 멈춤"
		countdown.Text = if left > 0 and left <= 3 then tostring(math.ceil(left)) else ""
		local sec = if left > 0 and left <= 3 then math.ceil(left) else 0
		if sec > 0 and sec ~= boothSound.lastTick then
			boothSound.tick.TimePosition = 0
			boothSound.tick:Play()
		end
		boothSound.lastTick = sec
	elseif phase == "picking" then
		waitBar.Visible = false
		-- (D-1139) shooting is over even when the pick screen opened first ("Shots"):
		-- the booth's stools back, the motion recording stopped
		require(script.Parent:WaitForChild("PhotoMotionReel")).hideStools(nil, false)
		require(script.Parent:WaitForChild("PhotoMotionReel")).stop()
		if state.stage == "shooting" then
			shoot.Visible = false
			liftTouchGui(false)
			restoreCamera()
			require(script.Parent:WaitForChild("PhotoMotionReel")).stop() -- (D-1126)
			require(script.Parent:WaitForChild("PhotoMotionReel")).hideStools(nil, false) -- (D-1139)
		end
		if state.stage == "picking" or state.stage == "frame" then
			local left = math.max(0, math.ceil((booth :: Model):GetAttribute("WaitUntil") - workspace:GetServerTimeNow()))
			pickTimer.Text = string.format("남은 시간 %d초", left)
			-- The host left: the next person takes over picking.
			if refreshPickerRole() then
				refreshPickBadges()
				if state.stage == "frame" then openFrameStep() end
			end
		end
	elseif phase == "copies" then
		waitBar.Visible = false
		if state.stage == "copies" then
			local left = math.max(0, math.ceil((booth :: Model):GetAttribute("WaitUntil") - workspace:GetServerTimeNow()))
			pickTimer.Text = string.format("남은 시간 %d초·시간이 지나면 1장만 저장돼요.", left) -- (D-1267)
		end
	else
		-- No session (or it just ended). A pick/frame screen whose session is
		-- gone (time ran out, or "Ended" was missed) closes too, unless a save
		-- is on its way.
		if state.stage == "waiting" or state.stage == "shooting"
			or ((state.stage == "picking" or state.stage == "frame" or state.stage == "copies") and not pickDone:GetAttribute("Saving")) then
			closeAllFlow()
		end
	end
end

RunService.Heartbeat:Connect(function()
	if state.stage == "waiting" or state.stage == "shooting" or state.stage == "picking" or state.stage == "frame" or state.stage == "copies" or myBooth() then
		update()
	end
end)

waitLeave.MouseButton1Click:Connect(function()
	invoke("Leave", nil)
	closeAllFlow()
end)
shootLeave.MouseButton1Click:Connect(function()
	invoke("Leave", nil)
	closeAllFlow()
end)
faceFront.MouseButton1Click:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cam = boothCameraCFrame()
	if not character or not root or not root:IsA("BasePart") or not cam then return end
	-- (the client owns its character, so turning it here reaches everyone)
	local at = root.Position
	character:PivotTo(CFrame.lookAt(at, Vector3.new(cam.Position.X, at.Y, cam.Position.Z)) * root.CFrame:ToObjectSpace(character:GetPivot()))
end)

boothEvent.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "Shot" then
		cutCount += 1
		if state.stage == "shooting" then
			require(script.Parent:WaitForChild("PhotoMotionReel")).shot(cutCount) -- (D-1126: before the flash and the capture)
			task.spawn(captureCut, cutCount)
		end
		flashShot()
	elseif kind == "Shots" and typeof(value) == "table" then
		openPick(value)
	elseif kind == "PickState" and typeof(value) == "table" and state.shots then
		-- Watching the picker live.
		refreshPickerRole()
		if state.isPicker then return end
		state.picks = if typeof(value.picks) == "table" then value.picks else {}
		if typeof(value.frame) == "string" then
			state.frame = value.frame
			if previewStrip then previewStrip.setColor(value.frame) end
		end
		if value.stage == "frame" and state.stage == "picking" then
			openFrameStep()
		elseif value.stage ~= "frame" and state.stage == "frame" then
			state.stage = "picking"
			pickGrid.Visible = true
			frameArea.Visible = false
			layoutPick()
		end
		if state.stage == "frame" then
			for key, stroke in pairs(frameCards) do stroke.Transparency = if key == state.frame then 0 else 1 end
		end
		refreshPickBadges()
		refreshPreview()
	elseif kind == "Copies" and typeof(value) == "table" then
		openCopies(value)
	elseif kind == "AutoSaved" then
		if state.stage ~= "result" then showResult(value) end
	elseif kind == "Ended" then
		-- A saved result stays on screen; anything else closes.
		if state.stage ~= "result" and state.stage ~= "none" then
			closeAllFlow()
			if typeof(value) == "string" then toast(value) end
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	-- (the prompts sit at the booth's door in the lobby, on its photo machine, or on its Stand)
	local booth: Instance? = prompt.Parent
	while booth and not (booth:IsA("Model") and CollectionService:HasTag(booth, "PhotoBooth")) do booth = booth.Parent end
	if not booth or not booth:IsA("Model") then return end
	if prompt.Name == "PhotoPrompt" then
		-- someone is in the booth: say who (user 2026-10-30)
		local phase = booth:GetAttribute("Phase")
		if phase ~= nil and phase ~= "idle" and not myBooth() then
			local host = Players:GetPlayerByUserId(booth:GetAttribute("Host") or 0)
			toast((if host then host.DisplayName else "다른 사람") .. " 님이 사진을 찍고 있어요. 기다려 주세요.")
			return
		end
		-- A finished result never blocks shooting again (user, 2026-10-20).
		if state.stage == "result" then closeAllFlow() end
		if album.Visible then closeAlbum() end
		openSetup(booth)
	elseif prompt.Name == "JoinPrompt" then
		local ok, message = invoke("Join", { booth = booth })
		if not ok then toast(message) end
	end
end)

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if setup.Visible then layoutSetup() end
		if shoot.Visible then layoutShoot() end
		if pick.Visible then layoutPick() end
		if result.Visible then layoutResult() end
		if album.Visible then layoutAlbum() end
	end)
end

player.CharacterAdded:Connect(function()
	if state.stage == "shooting" then
		invoke("Leave", nil)
		closeAllFlow()
	end
end)
