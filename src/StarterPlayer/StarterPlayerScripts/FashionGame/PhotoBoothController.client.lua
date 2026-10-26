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
local function toast(message: any)
	if typeof(message) ~= "string" or message == "" then return end
	toastToken += 1
	local token = toastToken
	toastLabel.Size = UDim2.fromOffset(math.min(440, viewport().X - 30), 40)
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3.2, function()
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
	frame.BackgroundColor3 = Color3.fromRGB(24, 20, 32)
	frame.BackgroundTransparency = 0.03
	frame.ClipsDescendants = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 110, 170)
	stroke.Thickness = 2
	stroke.Parent = frame
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
	camera.CFrame = cf
	local vp = viewport()
	local half = math.tan(math.rad(PhotoRender.FieldOfView / 2)) * vp.Y / math.max(shootWindow.h, 1)
	camera.FieldOfView = math.clamp(math.deg(2 * math.atan(half)), 20, 110)
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
setup.BackgroundTransparency = 0.4
local setupBox = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(420, 290),
	BackgroundColor3 = Color3.fromRGB(255, 240, 246),
	ZIndex = 11,
}, setup)
corner(setupBox, 18)
create("UIStroke", { Color = COLORS.pink, Thickness = 3 }, setupBox)
create("UISizeConstraint", { MaxSize = Vector2.new(420, 290) }, setupBox)
text({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -60, 0, 30),
	Text = "사진 유형을 선택하세요",
	TextColor3 = Color3.fromRGB(60, 30, 50),
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 12,
}, setupBox)
local setupClose = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = COLORS.pink,
	Text = "X",
	TextSize = 15,
	ZIndex = 12,
}, setupBox, 15)
local layoutRow = create("Frame", {
	Position = UDim2.fromOffset(16, 48),
	Size = UDim2.new(1, -32, 0, 130),
	BackgroundTransparency = 1,
	ZIndex = 12,
}, setupBox)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, layoutRow)
local layoutCards: {[string]: TextButton} = {}
local chosenLayout = PhotoConfig.Layouts[1].key
local chosenMode = "solo"
for index, layout in ipairs(PhotoConfig.Layouts) do
	local card = button({
		Name = "Layout_" .. layout.key,
		LayoutOrder = index,
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
		ZIndex = 12,
	}, layoutRow, 12)
	create("UIStroke", { Color = COLORS.pink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
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
		TextColor3 = Color3.fromRGB(60, 30, 50),
		TextSize = 15,
		ZIndex = 13,
	}, card)
	layoutCards[layout.key] = card
	card.MouseButton1Click:Connect(function()
		chosenLayout = layout.key
		for key, other in pairs(layoutCards) do
			other.BackgroundColor3 = if key == chosenLayout then Color3.fromRGB(255, 220, 235) else Color3.fromRGB(255, 255, 255)
		end
	end)
end
layoutCards[chosenLayout].BackgroundColor3 = Color3.fromRGB(255, 220, 235)

local modeRow = create("Frame", {
	Position = UDim2.fromOffset(16, 188),
	Size = UDim2.new(1, -32, 0, 34),
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
		BackgroundColor3 = Color3.fromRGB(230, 220, 228),
		TextColor3 = Color3.fromRGB(60, 30, 50),
		Text = mode.name,
		TextSize = 15,
		ZIndex = 12,
	}, modeRow, 17)
	modeButtons[mode.key] = modeButton
	modeButton.MouseButton1Click:Connect(function()
		chosenMode = mode.key
		for key, other in pairs(modeButtons) do
			other.BackgroundColor3 = if key == chosenMode then COLORS.pink else Color3.fromRGB(230, 220, 228)
			other.TextColor3 = if key == chosenMode then COLORS.text else Color3.fromRGB(60, 30, 50)
		end
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
	Text = "들어가기",
	TextSize = 18,
	ZIndex = 12,
}, setupBox, 14)

local function layoutSetup()
	local vp = viewport()
	local scale = math.min(1, (vp.X - 20) / 420, (vp.Y - 20) / 290)
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
	enterButton.Text = "들어가기"
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
task.spawn(function()
	while true do
		task.wait(0.6)
		recLabel.TextTransparency = if recLabel.TextTransparency == 0 then 0.5 else 0
	end
end)
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
	BackgroundColor3 = Color3.fromRGB(255, 240, 246),
	BackgroundTransparency = 0,
	TextColor3 = Color3.fromRGB(60, 30, 50),
	Text = "",
	TextSize = 16,
	ZIndex = 3,
}, shoot)
corner(infoBar, 17)
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
	Text = "🙂 정면 보기",
	TextSize = 13,
	ZIndex = 3,
}, shoot, 15)

local function sidePanel(name: string, title: string): (Frame, ScrollingFrame)
	-- (the same light pink as the shot counter, user 2026-10-26)
	local frame = create("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(255, 240, 246),
		ZIndex = 3,
	}, shoot)
	corner(frame, 12)
	text({
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 22),
		Text = title,
		TextColor3 = Color3.fromRGB(60, 30, 50),
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

-- light sky-blue buttons with dark text on the pink popups (user 2026-10-26);
-- the chosen one is pink with white text
local SKY_BUTTON, SKY_TEXT = Color3.fromRGB(205, 235, 250), Color3.fromRGB(30, 46, 66)
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
		b.MouseButton1Click:Connect(onClick)
		return b
	end
	-- ⏸ stops the pose animation at this frame so the photo catches it
	-- (user, 2026-10-20); ▶ continues.
	pauseButton = add("⏸ 멈춤", function()
		local character = player.Character
		if not character or character:GetAttribute("DanceKey") == nil then
			toast("먼저 포즈를 고른 뒤 원하는 순간에 ⏸를 누르세요.")
			return
		end
		danceRemote:FireServer(if typeof(character:GetAttribute("DancePause")) == "number" then "Resume" else "Pause")
	end)
	pauseButton.BackgroundColor3 = COLORS.pink
	pauseButton.TextColor3 = Color3.new(1, 1, 1)
	add("■ 기본", function() danceRemote:FireServer("Stop") end)
	for _, category in ipairs(PhotoConfig.PoseCategoryOrder) do
		for _, dance in ipairs(ClubConfig.Dances) do
			if dance.category == category then
				add(dance.name, function() danceRemote:FireServer("Start", dance.key, 1) end)
			end
		end
	end
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
		b.BackgroundColor3 = if worn then COLORS.pink else SKY_BUTTON
		b.TextColor3 = if worn then Color3.new(1, 1, 1) else SKY_TEXT
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
	local panelH = math.min(h, 34 * 3 + 4 * 2 + 40)
	posePanel.Position = UDim2.fromOffset(x - panelW - 10, y)
	posePanel.Size = UDim2.fromOffset(panelW, panelH)
	propPanel.Position = UDim2.fromOffset(x + w + 10, y)
	propPanel.Size = UDim2.fromOffset(panelW, panelH)
	tip.Position = UDim2.fromOffset(x, y + h - 24)
	tip.Size = UDim2.fromOffset(w, 20)
	faceFront.Position = UDim2.fromOffset(x + w / 2 - 60, y + h - 58)
	shootLeave.Position = UDim2.fromOffset(vp.X / 2 + infoBar.Size.X.Offset / 2 + 10, top)
	shootLeave.Size = UDim2.fromOffset(34, 34)
	local bracket = math.floor(math.clamp(math.min(w, h) * 0.12, 22, 48))
	for _, c in ipairs(corners) do c.Size = UDim2.fromOffset(bracket, bracket) end
end

local function flashShot()
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

local pickCells: {ViewportFrame} = {}
local pickBadges: {TextLabel} = {}
local previewStrip: any = nil

local function layoutPick()
	local bw, bh = placeBox(pick, "flow")
	pickTitle.Position = UDim2.fromOffset(0, 8)
	pickTimer.Position = UDim2.fromOffset(0, 36)
	local areaTop = 58
	local areaH = bh - areaTop - 56
	local previewW = math.floor(math.min(bw * 0.3, areaH * PhotoRender.stripAspect(state.shots and state.shots.layout or "1x4") * 1.02))
	pickGrid.Position = UDim2.fromOffset(12, areaTop)
	pickGrid.Size = UDim2.fromOffset(bw - previewW - 36, areaH)
	frameArea.Position = pickGrid.Position
	frameArea.Size = pickGrid.Size
	pickPreview.Position = UDim2.fromOffset(bw - previewW - 12, areaTop)
	pickPreview.Size = UDim2.fromOffset(previewW, areaH)
	pickDone.Position = UDim2.new(0.5, 0, 1, -10)
	-- 4 × 2 grid of 4:3 cells
	local gw = pickGrid.Size.X.Offset
	local cellW = math.min((gw - 3 * 8) / 4, (areaH - 8) / 2 * 4 / 3)
	local cellH = cellW * 3 / 4
	for index, cell in ipairs(pickCells) do
		local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
		cell.Position = UDim2.fromOffset(col * (cellW + 8), row * (cellH + 8))
		cell.Size = UDim2.fromOffset(cellW, cellH)
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
		badge.Visible = order ~= nil
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
	pickDone.BackgroundColor3 = if #state.picks == PhotoConfig.PickCount then COLORS.yellow else COLORS.card
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
	previewStrip = PhotoRender.newStrip(pickPreview, shots.layout, state.frame, "FASHION SOCIAL · " .. os.date("%Y.%m.%d"))
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
			BackgroundColor3 = Color3.fromRGB(60, 60, 66),
			BorderSizePixel = 0,
			ZIndex = 12,
		}, pickGrid)
		corner(cell, 6)
		create("UIStroke", { Color = COLORS.yellow, Thickness = 3, Transparency = 1 }, cell)
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
	pickGrid.Visible = true
	frameArea.Visible = false
	pickDone.Text = "선택 완료"
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
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 12,
}, frameArea)
create("UIGridLayout", { CellSize = UDim2.fromOffset(84, 70), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, swatches)
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
		pickDone.BackgroundColor3 = if info.price == "coins" then Color3.fromRGB(230, 170, 40) else Color3.fromRGB(0, 176, 111)
	else
		pickDone.Text = "선택 완료"
		pickDone.BackgroundColor3 = COLORS.yellow
	end
end

local function renderSwatches()
	for _, child in ipairs(swatches:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for index, info in ipairs(PhotoConfig.Frames) do
		if info.tab == frameTab then
			local swatch = button({
				LayoutOrder = index,
				BackgroundColor3 = info.color,
				Text = (if ownsFrame(info) then "" else "🔒 ") .. info.name .. "\n"
					.. (if ownsFrame(info) and info.price ~= "free" then "✓ 보유" else PhotoConfig.priceText(info)),
				TextColor3 = info.text,
				TextSize = 13,
				ZIndex = 13,
			}, swatches, 10)
			create("UIStroke", {
				Color = COLORS.yellow,
				Thickness = 3,
				Transparency = if state.frame == info.key then 0 else 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, swatch)
			swatch.MouseButton1Click:Connect(function()
				if not state.isPicker then return end
				state.frame = info.key
				if previewStrip then previewStrip.setColor(info.key) end
				renderSwatches()
				refreshSaveButton()
				sendPick()
			end)
		end
	end
	for name, tab in pairs(tabButtons) do
		tab.BackgroundColor3 = if name == frameTab then COLORS.pink else COLORS.card
	end
end
for index, name in ipairs(PhotoConfig.FrameTabs) do
	local tab = button({
		LayoutOrder = index,
		Size = UDim2.fromOffset(86, 30),
		Text = name .. " 프레임",
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
create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, resultButtons)
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
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = color,
		Text = label,
		TextSize = 15,
		ZIndex = 12,
	}, resultButtons, 12)
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function closeAllFlow()
	pick.Visible = false
	result.Visible = false
	shoot.Visible = false
	waitBar.Visible = false
	liftTouchGui(false)
	restoreCamera()
	state.stage = "none"
	state.shots = nil
	previewStrip = nil
	Popups.closed("PhotoResult")
end

resultButton("📸 캡처 저장", COLORS.pink, 1, function()
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
end)
resultButton("🖼 사진첩", COLORS.card, 2, function()
	closeAllFlow()
	if openAlbum then openAlbum() end
end)
resultButton("닫기", COLORS.card, 3, closeAllFlow)

local function layoutResult()
	local bw, bh = placeBox(result, "flow")
	resultTitle.Position = UDim2.fromOffset(0, 8)
	local buttonsW = math.floor(math.min(170, bw * 0.32))
	resultHolder.Position = UDim2.fromOffset(12, 42)
	resultHolder.Size = UDim2.fromOffset(bw - buttonsW - 36, bh - 54)
	resultButtons.Position = UDim2.fromOffset(bw - buttonsW - 12, 60)
	resultButtons.Size = UDim2.fromOffset(buttonsW, 140)
end

local function showResult(saved: any)
	state.stage = "result"
	pick.Visible = false
	for _, child in ipairs(resultHolder:GetChildren()) do child:Destroy() end
	-- The preview strip already shows the 4 shots: move it over.
	if previewStrip then
		previewStrip.frame.Parent = resultHolder
	end
	previewStrip = nil
	layoutResult()
	result.Visible = true
	Popups.opened("PhotoResult", closeAllFlow)
	local count = if typeof(saved) == "table" then saved.count else nil
	resultTitle.Text = if count then string.format("사진첩에 저장했어요! (%d/%d)", count, saved.max or PhotoConfig.MaxPhotos) else "사진첩에 저장했어요!"
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
TopBar.add(albumButton, 3)

local album = overlay("Album")
boxify(album)
local albumTitle = text({
	Size = UDim2.new(1, -120, 0, 30),
	Text = "사진첩",
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, album)
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

local function layoutAlbum()
	local bw, bh = placeBox(album, "album")
	placeBox(viewer, "album")
	albumTitle.Position = UDim2.fromOffset(14, 8)
	albumClose.Position = UDim2.new(1, -10, 0, 8)
	albumList.Position = UDim2.fromOffset(12, 46)
	albumList.Size = UDim2.fromOffset(bw - 24, bh - 56)
	albumEmpty.Position = UDim2.fromOffset(0, 70)
	local cellH = math.clamp(math.floor((bh - 66) / 1.6), 110, 240)
	albumGrid.CellSize = UDim2.fromOffset(math.floor(cellH * 0.55), cellH)
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
	albumTitle.Text = "사진첩 · 불러오는 중..."
	local ok, data = invoke("GetAlbum", nil)
	if generation ~= albumGeneration then return end
	if not ok or typeof(data) ~= "table" then
		albumTitle.Text = "사진첩"
		toast(if typeof(data) == "string" then data else "사진첩을 불러오지 못했어요.")
		return
	end
	local photos = data.photos or {}
	albumTitle.Text = string.format("사진첩 %d/%d", #photos, data.max or PhotoConfig.MaxPhotos)
	albumEmpty.Visible = #photos == 0
	for index, photo in ipairs(photos) do
		local cell = button({
			Name = "Photo" .. index,
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 12,
		}, albumList, 6)
		local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 }, cell)
		PhotoRender.drawPhoto(holder, photo)
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
local deleteArmed = 0
viewerDelete.MouseButton1Click:Connect(function()
	local photo = viewerPhoto
	if not photo then return end
	if os.clock() - deleteArmed > 3 then
		deleteArmed = os.clock()
		viewerDelete.Text = "한 번 더 누르면 삭제"
		return
	end
	deleteArmed = 0
	local ok, message = invoke("DeletePhoto", photo.id)
	if ok then
		viewer.Visible = false
		toast("사진을 지웠어요.")
		task.spawn(renderAlbum)
	else
		toast(message)
	end
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
		state.stage = "waiting"
		local vp = viewport()
		-- At the bottom, above the hotbar (user: 나가기 at the bottom).
		waitBar.Position = UDim2.fromOffset(vp.X / 2, vp.Y - 84 - 96)
		waitBar.Size = UDim2.fromOffset(math.min(380, vp.X - 30), 84)
		local left = math.max(0, math.ceil((booth :: Model):GetAttribute("WaitUntil") - workspace:GetServerTimeNow()))
		local host = (booth :: Model):GetAttribute("Host") == player.UserId
		waitText.Text = string.format("📸 %d초 후 촬영 시작 · %d/%d명 · %s", left, peopleCount(booth :: Model), PhotoConfig.MaxPeople, modeName((booth :: Model):GetAttribute("Mode")))
		waitStart.Visible = host
		waitLeave.Position = if host then UDim2.new(0.5, 6, 1, -38) else UDim2.new(0, 12, 1, -38)
		waitLeave.Size = if host then UDim2.new(0.5, -18, 0, 30) else UDim2.new(1, -24, 0, 30)
		waitBar.Visible = true
	elseif phase == "shooting" then
		waitBar.Visible = false
		if state.stage ~= "shooting" then
			state.stage = "shooting"
			table.clear(cutCaptures)
			cutCount = 0
			layoutShoot()
			shoot.Visible = true
			liftTouchGui(true)
			refreshProps()
		end
		applyShootCamera()
		local index = (booth :: Model):GetAttribute("ShotIndex") or 0
		local left = math.max(0, (booth :: Model):GetAttribute("NextShotAt") - workspace:GetServerTimeNow())
		infoBar.Text = string.format("📸 촬영 %d / %d   ⏱ %d초", index, PhotoConfig.ShotCount, math.ceil(left))
		local character = player.Character
		local paused = character and typeof(character:GetAttribute("DancePause")) == "number"
		pauseButton.Text = if paused then "▶ 계속" else "⏸ 멈춤"
		countdown.Text = if left > 0 and left <= 3 then tostring(math.ceil(left)) else ""
	elseif phase == "picking" then
		waitBar.Visible = false
		if state.stage == "shooting" then
			shoot.Visible = false
			liftTouchGui(false)
			restoreCamera()
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
			pickTimer.Text = string.format("남은 시간 %d초 · 시간이 지나면 1장(무료)만 저장돼요", left)
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
		if state.stage == "shooting" then task.spawn(captureCut, cutCount) end
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
		end
		if state.stage == "frame" then renderSwatches() end
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
	local booth = prompt.Parent and prompt.Parent.Parent
	if not booth or not booth:IsA("Model") or not CollectionService:HasTag(booth, "PhotoBooth") then return end
	if prompt.Name == "PhotoPrompt" then
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
