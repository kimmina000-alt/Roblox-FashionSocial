--!strict
-- First-visit tutorial and the guide NPC's 무엇이든 물어보세요 window (user
-- 2026-11-01, D-712; places and questions in Shared/GuideConfig).
--   * Tutorial: a player who has not seen it (attribute TutorialDone = false,
--     GuideService) gets a short tour: the camera flies to each place while a
--     card at the bottom says what is there. 건너뛰기 ends it at any step;
--     either way the server remembers it.
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
local Spotlight = require(script.Parent:WaitForChild("Spotlight"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PEACH = Color3.fromRGB(255, 248, 240)
local ORANGE = Color3.fromRGB(255, 140, 70)
local BROWN = Color3.fromRGB(80, 50, 35)
local GREY = Color3.fromRGB(150, 135, 125)

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

--------------------------------------------------
-- Tutorial
--------------------------------------------------

local card = create("Frame", {
	Name = "TutorialCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 78, 1, -56), -- (room on the left for the bunny, under it for 다음)
	Size = UDim2.new(1, -188, 0, 122), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false,
	-- (D-717, user: black, see-through, white text; peach at 50 % in D-716)
	BackgroundTransparency = 0.35,
}, gui)
corner(card, 18)
create("UISizeConstraint", { MaxSize = Vector2.new(560, 122) }, card)
create("UIStroke", { Color = ORANGE, Thickness = 2 }, card)
-- (D-716) the guide bunny beside the card, as if it gives the tour
local GuideSpeaker = require(script.Parent:WaitForChild("GuideSpeaker"))
GuideSpeaker.attach(card)
local cardTitle = create("TextLabel", {
	Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -110, 0, 30), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, card)
local cardStep = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(80, 22),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(200, 200, 205),
	TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, card)
-- (D-717, user: the words stood out less than the buttons: 15 → 20)
local cardText = create("TextLabel", {
	Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 0, 66), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
-- (D-718, the user's mock-up) a small 건너뛰기 tag over the card's top right,
-- a small 다음 button under its bottom right, so the words come first
local skipButton = button(card, "건너뛰기 >", Color3.fromRGB(40, 40, 46), Color3.new(1, 1, 1))
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Position = UDim2.new(1, -10, 0, -4)
skipButton.Size = UDim2.fromOffset(84, 24)
skipButton.TextSize = 13
local nextButton = button(card, "다음 ▶", ORANGE, Color3.new(1, 1, 1))
nextButton.AnchorPoint = Vector2.new(1, 0)
nextButton.Position = UDim2.new(1, -6, 1, 6)
nextButton.Size = UDim2.fromOffset(76, 34)
nextButton.TextSize = 14

local touring = false
local step = 0
local function showStep()
	local total = #GuideConfig.Tutorial + 1
	cardStep.Text = string.format("%d / %d", step, total)
	if step <= #GuideConfig.Tutorial then
		local place = GuideConfig.Places[GuideConfig.Tutorial[step]]
		cardTitle.Text = place.emoji .. " " .. place.name
		cardText.Text = place.text
		nextButton.Text = "다음 ▶"
		if step == 1 then
			cameraBack() -- the start: the player's own view
		else
			flyTo(viewOf(place), 1.4)
		end
	else
		cardTitle.Text = GuideConfig.TutorialEnd.title
		cardText.Text = GuideConfig.TutorialEnd.text
		nextButton.Text = "다음 ▶"
		cameraBack()
		-- (D-714) the screen dark but for this card and the menu button, which pulses
		Spotlight.set(TopBar.button(20))
	end
end

local GuideTips = require(script.Parent:WaitForChild("GuideTips"))
GuideTips.start()

-- finished: the tour went to its end (then the screen's buttons are shown,
-- D-713); not when it was skipped
local function endTour(finished: boolean?)
	if not touring then return end
	touring = false
	require(script.Parent:WaitForChild("Coach")).hold(false)
	player:SetAttribute("GuideActive", nil) -- (the ambience back to normal, SfxController)
	card.Visible = false
	Spotlight.set(nil)
	cameraBack()
	Popups.closed("Tutorial")
	task.spawn(function() pcall(function() remote:InvokeServer("TutorialDone") end) end)
	if finished then GuideTips.hud() end
end

local function startTour()
	if touring then return end
	touring = true
	local Coach = require(script.Parent:WaitForChild("Coach"))
	if Coach.isRunning() then Coach.finishNow() end -- (D-719: the tour, not a tip, on screen)
	Coach.hold(true)
	player:SetAttribute("GuideActive", true)
	step = 1
	card.Visible = true
	Popups.opened("Tutorial", function() endTour(false) end)
	showStep()
end

nextButton.Activated:Connect(function()
	if not touring then return end
	step += 1
	if step > #GuideConfig.Tutorial + 1 then endTour(true) else showStep() end
end)
skipButton.Activated:Connect(function() endTour(false) end)

-- first visit: once the server says the tour was not seen yet
task.spawn(function()
	local waited = 0
	while player:GetAttribute("TutorialDone") == nil and waited < 20 do task.wait(0.5) waited += 0.5 end
	if player:GetAttribute("TutorialDone") ~= false then return end
	if not player.Character then player.CharacterAdded:Wait() end
	task.wait(2.5) -- (the world around the spawn streams in first)
	startTour()
end)

--------------------------------------------------
-- 길 안내 (waypoint)
--------------------------------------------------

local waypoint: { part: BasePart, beam: Beam, from: Attachment, label: TextLabel, place: GuideConfig.Place, untilTime: number }? = nil
local function clearWaypoint()
	if waypoint then
		waypoint.part:Destroy()
		waypoint.from:Destroy()
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
	local board = create("BillboardGui", { Size = UDim2.fromOffset(190, 54), StudsOffset = Vector3.new(0, 5, 0), AlwaysOnTop = true }, part)
	local label = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = ORANGE, BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Text = "",
	}, board)
	corner(label, 14)
	waypoint = { part = part, beam = beam, from = from, label = label, place = place, untilTime = os.clock() + GuideConfig.WaypointSeconds }
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
	w.label.Text = string.format("%s %s · %dm", w.place.emoji, w.place.name, math.floor(distance + 0.5))
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
local closeButton = button(window, "X", Color3.new(1, 1, 1), BROWN)
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
local backButton = button(answer, "◀ 목록", Color3.fromRGB(235, 225, 215), BROWN)
backButton.AnchorPoint = Vector2.new(0, 1)
backButton.Position = UDim2.new(0, 0, 1, 0)
backButton.Size = UDim2.new(0.28, -6, 0, 42)
local showButton = button(answer, "👀 보여 주기", Color3.fromRGB(255, 205, 160), BROWN)
showButton.AnchorPoint = Vector2.new(0, 1)
showButton.Position = UDim2.new(0.28, 0, 1, 0)
showButton.Size = UDim2.new(0.34, -6, 0, 42)
local goButton = button(answer, "📍 길 안내", ORANGE, Color3.new(1, 1, 1))
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
	goButton.Visible = place ~= nil or faq.action == "tutorial"
	goButton.Text = if faq.action == "tutorial" then "▶ 다시 보기" else "📍 길 안내"
	list.Visible = false
	answer.Visible = true
end
for i, faq in ipairs(GuideConfig.Faq) do
	local b = button(list, faq.q, Color3.new(1, 1, 1), BROWN)
	b.LayoutOrder = i
	b.Size = UDim2.new(1, -6, 0, 44)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextWrapped = true
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }, b)
	create("UIStroke", { Color = Color3.fromRGB(240, 210, 185), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	b.Activated:Connect(function() showAnswer(faq) end)
end

local function openWindow()
	if touring then return end
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
		if not touring then window.Visible = true end
	end)
end)
goButton.Activated:Connect(function()
	if not shown then return end
	if shown.action == "tutorial" then
		closeWindow()
		-- (every first-time tip comes back too, D-713)
		task.spawn(function()
			require(script.Parent:WaitForChild("Coach")).reset()
			startTour()
		end)
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
