--!strict
-- 📸 capture button (user, 2026-10-21): Roblox's own screenshot and video
-- recording, from the top bar.
--
--   📸 → small menu: [📷 사진] [🎥 동영상]
--   사진   CaptureService:TakeScreenshotCaptureAsync (game view without our UI)
--          → Roblox "save to Captures" prompt.
--   동영상 CaptureService:StartVideoCaptureAsync → red REC pill with a timer
--          and [■ 정지]; Roblox stops by itself at 30 s. When it ends the
--          Roblox save prompt opens.
-- Saved captures go to the player's Roblox Captures gallery (in-experience
-- menu); from there the device can save or share them. Studio may refuse
-- captures, in which case a toast says so.

local Players = game:GetService("Players")
local CaptureService = game:GetService("CaptureService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local MAX_VIDEO_SECONDS = 30

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

local gui = create("ScreenGui", {
	Name = "FashionCaptureGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 45,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local captureButton = create("TextButton", {
	Name = "CaptureButton",
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	Text = "📸",
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1),
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, captureButton)
TopBar.add(captureButton, 4)

-- Menu under the button
local menu = create("Frame", {
	Name = "CaptureMenu",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(150, 96),
	BackgroundColor3 = Color3.fromRGB(24, 22, 30),
	BackgroundTransparency = 0.05,
	Visible = false,
	Active = true,
}, gui)
corner(menu, 12)
create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, menu)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, menu)
local function menuButton(name: string, text: string, order: number): TextButton
	local b = create("TextButton", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(44, 42, 54),
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
	}, menu)
	corner(b, 10)
	return b
end
local photoButton = menuButton("Photo", "📷 사진", 1)
local videoButton = menuButton("Video", "🎥 동영상 (30초)", 2)

-- Recording pill
local recPill = create("Frame", {
	Name = "RecPill",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(200, 38),
	BackgroundColor3 = Color3.fromRGB(30, 10, 14),
	BackgroundTransparency = 0.1,
	Visible = false,
	Active = true,
}, gui)
corner(recPill, 19)
create("UIStroke", { Color = Color3.fromRGB(255, 60, 70), Thickness = 2 }, recPill)
local recText = create("TextLabel", {
	Position = UDim2.fromOffset(14, 0),
	Size = UDim2.new(1, -96, 1, 0),
	BackgroundTransparency = 1,
	Text = "● REC 0:00",
	TextColor3 = Color3.fromRGB(255, 90, 100),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, recPill)
local stopButton = create("TextButton", {
	Name = "Stop",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -5, 0.5, 0),
	Size = UDim2.fromOffset(78, 28),
	BackgroundColor3 = Color3.fromRGB(255, 60, 70),
	Text = "■ 정지",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, recPill)
corner(stopButton, 14)

local toastLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -70),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.25,
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 15,
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
corner(toastLabel, 12)
local toastToken = 0
local function toast(message: string)
	toastToken += 1
	local token = toastToken
	local camera = workspace.CurrentCamera
	toastLabel.Size = UDim2.fromOffset(math.min(420, (if camera then camera.ViewportSize.X else 800) - 30), 40)
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3.2, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

local function placeMenu()
	local pos = captureButton.AbsolutePosition
	local size = captureButton.AbsoluteSize
	-- Below the top bar (AbsolutePosition.Y does not include the inset).
	local top = require(script.Parent:WaitForChild("TopBar")).bottom() + 8
	menu.Position = UDim2.fromOffset(pos.X + size.X, top)
	recPill.Position = UDim2.new(0.5, 0, 0, top)
end

local function setMenu(open: boolean)
	if open then placeMenu() end
	menu.Visible = open
	captureButton.BackgroundColor3 = if open then Color3.fromRGB(255, 110, 170) else Color3.fromRGB(0, 0, 0)
end

local function saveToGallery(capture: any)
	pcall(function()
		CaptureService:PromptSaveCapturesToGallery({ capture }, function(results)
			for _, saved in pairs(results) do
				if saved then toast("캡처를 저장했어요. 메뉴의 캡처(Captures)에서 볼 수 있어요.") end
			end
		end)
	end)
end

--------------------------------------------------
-- Photo
--------------------------------------------------

photoButton.MouseButton1Click:Connect(function()
	setMenu(false)
	local ok, err = pcall(function()
		CaptureService:TakeScreenshotCaptureAsync(function(result, capture)
			if result == Enum.ScreenshotCaptureResult.Success and capture then
				saveToGallery(capture)
			else
				toast("사진을 찍지 못했어요. (" .. tostring(result) .. ")")
			end
		end, { UICaptureMode = Enum.UICaptureMode.None })
	end)
	if not ok then
		toast("이 기기에서는 사진 캡처를 쓸 수 없어요." .. (if RunService:IsStudio() then " (Studio에서는 안 될 수 있어요)" else ""))
		warn("[Capture] screenshot:", err)
	end
end)

--------------------------------------------------
-- Video
--------------------------------------------------

local recording = false
local recordStart = 0

local function endRecordingUi()
	recording = false
	recPill.Visible = false
	captureButton.Visible = true
end

local function onVideoReady(result: any, videoCapture: any)
	endRecordingUi()
	if (result == Enum.VideoCaptureResult.Success or result == Enum.VideoCaptureResult.TimeLimitReached) and videoCapture then
		saveToGallery(videoCapture)
	else
		toast("동영상을 저장하지 못했어요. (" .. tostring(result) .. ")")
	end
end

videoButton.MouseButton1Click:Connect(function()
	setMenu(false)
	if recording then return end
	local ok, started = pcall(function()
		return CaptureService:StartVideoCaptureAsync(onVideoReady, {})
	end)
	if not ok or started ~= Enum.VideoCaptureStartedResult.Success then
		toast("동영상 녹화를 시작할 수 없어요." .. (if ok then " (" .. tostring(started) .. ")" else "")
			.. (if RunService:IsStudio() then " Studio에서는 안 될 수 있어요." else ""))
		if not ok then warn("[Capture] video:", started) end
		return
	end
	recording = true
	recordStart = os.clock()
	placeMenu()
	recPill.Visible = true
	captureButton.Visible = false
	task.spawn(function()
		while recording do
			local elapsed = math.floor(os.clock() - recordStart)
			recText.Text = string.format("● REC %d:%02d / 0:%02d", elapsed // 60, elapsed % 60, MAX_VIDEO_SECONDS)
			task.wait(0.25)
		end
	end)
end)

stopButton.MouseButton1Click:Connect(function()
	if not recording then return end
	pcall(function() CaptureService:StopVideoCapture() end)
	-- onVideoReady closes the pill when Roblox hands the video back.
	task.delay(3, function()
		if recording then endRecordingUi() end
	end)
end)

captureButton.MouseButton1Click:Connect(function()
	setMenu(not menu.Visible)
end)
