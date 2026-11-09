--!strict
-- The guide NPC's 무엇이든 물어보세요 window (user 2026-11-01, D-712; places
-- and questions in Shared/GuideConfig). (The tour and tips are gone, D-845 / D-850.)
--   * Guide NPC (prompt "GuidePrompt"): a window of questions; an answer can
--     show its place (the camera flies there and back) or guide the way
--     there (a marker over the place and a line from the player to it, gone
--     on arrival).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local GuideConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("GuideConfig"))
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
local Popups = require(script.Parent:WaitForChild("Popups"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- (D-1088, user 2026-11-09: "안내원 디자인 블랙 앤 화이트로 수정. 순위표처럼.")
-- the ranking boards' look: a near-black window with a white edge, white
-- letters, dark grey rows (was peach / orange / brown)
local PEACH = Color3.fromRGB(14, 14, 18) -- (the window)
local ORANGE = Color3.fromRGB(255, 255, 255) -- (edges, the question, the main button)
local BROWN = Color3.fromRGB(240, 240, 245) -- (text)
local GREY = Color3.fromRGB(150, 150, 158)
local ROW = Color3.fromRGB(30, 30, 36)
local ROW_EDGE = Color3.fromRGB(70, 70, 80)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local function button(parent: Instance, text: string, color: Color3, textColor: Color3): TextButton
	local b = create("TextButton", {
		BackgroundColor3 = color, Text = text, TextColor3 = textColor, Font = Enum.Font.GothamBold,
		TextSize = 15, AutoButtonColor = true,
	}, parent)
	corner(b, 12)
	return b
end

local gui = create("ScreenGui", { Name = "FashionGuideGui", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true }, playerGui)

--------------------------------------------------
-- Camera flights
--------------------------------------------------

local camera = workspace.CurrentCamera
local function viewOf(place: GuideConfig.Place): CFrame
	local look, at = place.look, place.at
	if place.eye then return CFrame.lookAt(place.eye, look) end
	local flat = Vector3.new(at.X - look.X, 0, at.Z - look.Z)
	local back = if flat.Magnitude > 1 then flat.Unit else Vector3.new(1, 0, 1).Unit
	-- (from out beyond the place's front spot, not from the building's middle:
	-- that put the camera inside the club)
	-- (a step back to see the whole building; aimed a little low so it shows
	-- above the card at the bottom)
	return CFrame.lookAt(at + back * 62 + Vector3.new(0, 30, 0), look - Vector3.new(0, 8, 0))
end
local flight: Tween? = nil
local function flyTo(cf: CFrame, seconds: number)
	-- (the world is streamed in around the player: ask for the place first)
	task.spawn(function()
		pcall(function() player:RequestStreamAroundAsync(cf.Position + cf.LookVector * 40, 2) end)
	end)
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	Sfx.play("whoosh") -- (a whoosh as the camera flies, D-717)
	if flight then flight:Cancel() end
	flight = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = cf })
	;(flight :: Tween):Play()
end
local function cameraBack()
	if flight then flight:Cancel() flight = nil end
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
end

-- (D-845, user 2026-11-03: "튜토리얼 삭제해라 정신 사납다": the first-visit
-- place tour is gone; D-850, "튜토리얼 싹 다 없애": every first-time tip and
-- 예/아니오 question too, with their Coach / GuideTips / Spotlight /
-- GuideSpeaker modules)

--------------------------------------------------
-- 길 안내 (waypoint)
--------------------------------------------------

local waypoint: { part: BasePart, beam: Beam, from: Attachment, board: BillboardGui, label: TextButton, place: GuideConfig.Place, untilTime: number }? = nil
local function clearWaypoint()
	if waypoint then
		waypoint.part:Destroy()
		waypoint.from:Destroy()
		waypoint.board:Destroy()
		waypoint = nil
	end
end
local function guideTo(place: GuideConfig.Place)
	clearWaypoint()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local part = create("Part", {
		Name = "GuideWaypoint", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.new(1, 1, 1), Position = place.at + Vector3.new(0, 2, 0),
	}, workspace)
	local to = create("Attachment", {}, part)
	local from = create("Attachment", { Name = "GuideFrom", Position = Vector3.new(0, -2, 0) }, root)
	local beam = create("Beam", {
		Attachment0 = from, Attachment1 = to, FaceCamera = true, Width0 = 0.6, Width1 = 0.6,
		Color = ColorSequence.new(ORANGE), LightEmission = 1, Transparency = NumberSequence.new(0.25),
		Texture = "rbxasset://textures/particles/sparkles_main.dds", TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 3, TextureSpeed = 1.5, Segments = 20,
	}, part)
	-- (D-747, user: a mistaken 길 안내 can be cancelled by tapping this sign:
	-- a button, so the board lives in PlayerGui with the part as its Adornee —
	-- a BillboardGui in Workspace takes no taps)
	local board = create("BillboardGui", {
		Name = "GuideWaypointSign", Adornee = part, Size = UDim2.fromOffset(190, 54), StudsOffset = Vector3.new(0, 5, 0),
		AlwaysOnTop = true, Active = true, ResetOnSpawn = false,
		LightInfluence = 0, -- (1 by default: black at night)
	}, playerGui)
	local label = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = ORANGE, BackgroundTransparency = 0.1, AutoButtonColor = true,
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(0, 0, 0), Text = "",
	}, board)
	corner(label, 14)
	label.Activated:Connect(clearWaypoint)
	waypoint = { part = part, beam = beam, from = from, board = board, label = label, place = place, untilTime = os.clock() + GuideConfig.WaypointSeconds }
end
RunService.Heartbeat:Connect(function()
	local w = waypoint
	if not w then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or w.from.Parent ~= root then
		-- (respawned: the line starts from the new body)
		if root then w.from.Parent = root else return end
	end
	local distance = (Vector3.new(root.Position.X, w.place.at.Y, root.Position.Z) - w.place.at).Magnitude
	w.label.Text = string.format("%s %s · %dm", w.place.emoji, w.place.name, math.floor(distance + 0.5)) -- (a tap cancels; no words for it, user)
	if distance < GuideConfig.ArriveDistance or os.clock() > w.untilTime then clearWaypoint() end
end)

--------------------------------------------------
-- 무엇이든 물어보세요
--------------------------------------------------

local window = create("Frame", {
	Name = "GuideWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54),
	Size = UDim2.new(1, -40, 1, -110), BackgroundColor3 = PEACH, Visible = false,
}, gui)
corner(window, 18)
create("UISizeConstraint", { MaxSize = Vector2.new(520, 430) }, window)
create("UIStroke", { Color = ORANGE, Thickness = 2 }, window)
create("TextLabel", {
	Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -70, 0, 26), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 19, TextColor3 = BROWN, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🙋 " .. GuideConfig.Npc.name .. " · 무엇이든 물어보세요",
}, window)
local closeButton = button(window, "X", Color3.new(1, 1, 1), Color3.new(0, 0, 0))
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.fromOffset(34, 34)
corner(closeButton, 17)

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 1, -64), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ScrollBarImageColor3 = ORANGE,
}, window)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local answer = create("Frame", { Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 1, -64), BackgroundTransparency = 1, Visible = false }, window)
local answerQ = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 17,
	TextColor3 = ORANGE, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, answer)
local answerA = create("TextLabel", {
	Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -110), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = BROWN, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, answer)
local backButton = button(answer, "◀ 목록", ROW, BROWN)
backButton.AnchorPoint = Vector2.new(0, 1)
backButton.Position = UDim2.new(0, 0, 1, 0)
backButton.Size = UDim2.new(0.28, -6, 0, 42)
local showButton = button(answer, "👀 보여 주기", Color3.fromRGB(56, 56, 64), BROWN)
showButton.AnchorPoint = Vector2.new(0, 1)
showButton.Position = UDim2.new(0.28, 0, 1, 0)
showButton.Size = UDim2.new(0.34, -6, 0, 42)
local goButton = button(answer, "📍 길 안내", ORANGE, Color3.new(0, 0, 0))
goButton.AnchorPoint = Vector2.new(1, 1)
goButton.Position = UDim2.new(1, 0, 1, 0)
goButton.Size = UDim2.new(0.38, 0, 0, 42)

local shown: GuideConfig.Faq? = nil
local function closeWindow()
	window.Visible = false
	Popups.closed("Guide")
end
local function showList()
	answer.Visible = false
	list.Visible = true
end
local function showAnswer(faq: GuideConfig.Faq)
	shown = faq
	answerQ.Text = "Q. " .. faq.q
	answerA.Text = faq.a
	local place = faq.place and GuideConfig.Places[faq.place]
	showButton.Visible = place ~= nil
	goButton.Visible = place ~= nil or faq.action ~= nil
	goButton.Text = if faq.action == "feedback" then "✏️ 의견 쓰기" else "📍 길 안내"
	list.Visible = false
	answer.Visible = true
end
for i, faq in ipairs(GuideConfig.Faq) do
	local b = button(list, faq.q, ROW, BROWN)
	b.LayoutOrder = i
	b.Size = UDim2.new(1, -6, 0, 44)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextWrapped = true
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }, b)
	create("UIStroke", { Color = ROW_EDGE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	b.Activated:Connect(function() showAnswer(faq) end)
end

local function openWindow()
	showList()
	window.Visible = true
	Popups.opened("Guide", closeWindow)
end

closeButton.Activated:Connect(closeWindow)
backButton.Activated:Connect(showList)
showButton.Activated:Connect(function()
	local place = shown and shown.place and GuideConfig.Places[shown.place]
	if not place then return end
	window.Visible = false
	flyTo(viewOf(place), 1.4)
	task.delay(4, function()
		cameraBack()
		window.Visible = true
	end)
end)
goButton.Activated:Connect(function()
	if not shown then return end
	if shown.action == "feedback" then
		closeWindow()
		require(script.Parent:WaitForChild("Feedback")).open()
		return
	end
	local place = shown.place and GuideConfig.Places[shown.place]
	if not place then return end
	guideTo(place)
	closeWindow()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "GuidePrompt" then openWindow() end
end)
