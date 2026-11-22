--!strict
-- (D-1870, user 2026-11-19: "7일차 14일차 선물 받으면 화면 중앙에 검은 상자에서 흔들리면서 프레임
-- 짜잔하고 등장시키면서 보여주고 오후네컷에 가서 확인해 보세요 안내") The surprise box of the
-- opening event's special rewards: in the middle of the screen the black ? box (the one on the
-- day-7 card) pops in, shakes harder and harder, bursts open with a flash and sparkles, and the
-- reward comes out ("짜잔!"): the limited frame (drawn with PhotoRender, as in the booth) and a
-- line to go and see it at 오후네컷, or the FOUNDING MEMBER plate and where it shows. 확인 closes.
-- RewardReveal.show("frame" | "title"); OpeningEventController calls it after a claim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("OpeningEventConfig"))
local PhotoRender = require(script.Parent:WaitForChild("PhotoRender"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local RewardReveal = {}

local WHITE = Color3.new(1, 1, 1)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local function tween(obj: Instance, t: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local showing: ScreenGui? = nil

function RewardReveal.show(kind: string, event: any?)
	-- (D-1874) the event the reward is from (colours, title, frame); the opening event by default
	local ev: any = event or Config.Opening
	if showing then showing:Destroy() end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", { Name = "RewardRevealGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60 }, playerGui)
	showing = gui
	-- phones: everything is drawn for a 400-high screen and scaled down below that
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local camera = Workspace.CurrentCamera
	local h = if camera then camera.ViewportSize.Y else 400
	local fit = math.clamp(h / 400, 0.6, 1.2)

	local dim = create("TextButton", {
		Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false,
	}, root)
	tween(dim, 0.25, { BackgroundTransparency = 0.35 })

	local stage = create("Frame", {
		Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 380), BackgroundTransparency = 1,
	}, root)
	create("UIScale", { Scale = fit }, stage)

	-- 1. the black ? box pops in and shakes, harder and harder
	local box = create("TextLabel", {
		Name = "Box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = Color3.new(0, 0, 0), FontFace = BOLD, TextSize = 80, TextColor3 = WHITE, Text = "?",
	}, stage)
	corner(box, 16)
	create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Thickness = 3 }, box)
	local boxScale = create("UIScale", { Scale = 0 }, box)
	tween(boxScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.45)
	if not gui.Parent then return end
	pcall(function() Sfx.play("whoosh", 0.35) end)
	local shakeTime = 1.6
	local t0 = os.clock()
	while os.clock() - t0 < shakeTime do
		if not gui.Parent then return end
		local t = (os.clock() - t0) / shakeTime
		local amp = 3 + 17 * t * t -- degrees
		box.Rotation = math.sin((os.clock() - t0) * (18 + 22 * t)) * amp
		box.Position = UDim2.new(0.5, math.sin((os.clock() - t0) * 47) * 4 * t, 0.5, math.cos((os.clock() - t0) * 39) * 3 * t)
		boxScale.Scale = 1 + 0.08 * t
		task.wait()
	end
	box.Rotation = 0

	-- 2. it bursts: the box swells and fades, a white flash, sparkles fly out
	tween(boxScale, 0.22, { Scale = 1.7 })
	tween(box, 0.22, { BackgroundTransparency = 1, TextTransparency = 1 })
	local stroke = box:FindFirstChildOfClass("UIStroke")
	if stroke then tween(stroke, 0.22, { Transparency = 1 }) end
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, ZIndex = 5 }, root)
	tween(flash, 0.5, { BackgroundTransparency = 1 })
	pcall(function() Sfx.play("success", 0.5) end)
	local marks = { "✨", "💖", "⭐", "💗", "🌟", "✨" }
	for i = 1, 16 do
		local a = (i / 16) * math.pi * 2 + math.random() * 0.3
		local s = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1, Text = marks[(i % #marks) + 1], TextSize = 22 + math.random(0, 10), ZIndex = 4,
		}, stage)
		local d = 150 + math.random(0, 70)
		tween(s, 0.9, { Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d), TextTransparency = 1, Rotation = math.random(-90, 90) })
		task.delay(1, function() s:Destroy() end)
	end

	-- 3. 짜잔: the card with the reward
	local card = create("Frame", {
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 360),
		BackgroundColor3 = Color3.fromRGB(252, 240, 248), ZIndex = 2,
	}, stage)
	corner(card, 22)
	create("UIStroke", { Color = WHITE, Thickness = 3 }, card)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(ev.bgTop, ev.bgBottom) }, card)
	local cardScale = create("UIScale", { Scale = 0.2 }, card)
	tween(cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local title = create("TextLabel", {
		Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 34,
		TextColor3 = ev.accent, Text = "짜잔! 🎉", ZIndex = 3,
	}, card)
	create("UIStroke", { Color = WHITE, Thickness = 2 }, title)

	-- the reward itself, gently bobbing
	local show = create("Frame", {
		Name = "Reward", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(230, 172),
		BackgroundTransparency = 1, ZIndex = 3,
	}, card)
	local name, guide
	if kind == "santa" then
		-- (D-1878) the mini Santa found today, turning slowly in a viewport (ev = SantaHuntConfig.Theme
		-- plus santaLook / santaName)
		local SantaFactory = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("SantaFactory"))
		local vp = create("ViewportFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(190, 172),
			BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1, -1), ZIndex = 4,
		}, show)
		local model = SantaFactory.build(ev.santaLook or "classic", 1)
		model.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.Parent = vp
		vp.CurrentCamera = cam
		task.spawn(function()
			local t0 = os.clock()
			while vp.Parent and gui.Parent do
				local a = (os.clock() - t0) * 0.9
				local focus = Vector3.new(0, 1.55, 0)
				cam.CFrame = CFrame.lookAt(focus + Vector3.new(math.sin(a) * 7.2, 1.2, -math.cos(a) * 7.2), focus)
				task.wait()
			end
		end)
		name = string.format("%s를 찾았어요!", ev.santaName or "산타")
		guide = "산타 도감에 쏙! 🎅 버튼에서 인형으로 들 수 있어요"
	elseif kind == "title" then
		local plate = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(280, 54),
			BackgroundColor3 = ev.plate, BackgroundTransparency = 0.05, FontFace = BOLD, TextSize = 27,
			TextColor3 = ev.plateText, Text = ev.TitleText, ZIndex = 4,
		}, show)
		corner(plate, 5)
		create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = ev.plateEdge, Thickness = 2 }, plate)
		name = ev.titleName
		guide = "모두에게 보이는 내 이름 위에 칭호가 생겼어요 👑"
	else
		-- the frame as the booth draws it (2x2), with soft pink cells for the photos
		local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, show)
		local ok, strip = pcall(PhotoRender.newStrip, holder, "2x2", ev.FrameKey, "OHU")
		if ok and strip then
			for _, cell in ipairs(strip.cells) do
				cell.BackgroundColor3 = ev.accentSoft
				cell.BackgroundTransparency = 0
			end
			for _, d in ipairs(strip.frame:GetDescendants()) do
				if d:IsA("GuiObject") then d.ZIndex += 3 end
			end
			strip.frame.ZIndex += 3
		end
		name = ev.frameName
		guide = "오후네컷에 가서 확인해 보세요 📸"
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(12, 246), Size = UDim2.new(1, -24, 0, 26), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 19,
		TextColor3 = ev.accent, Text = name, TextScaled = true, ZIndex = 3,
	}, card)
	create("TextLabel", {
		Position = UDim2.fromOffset(12, 274), Size = UDim2.new(1, -24, 0, 22), BackgroundTransparency = 1, FontFace = BOLD, TextSize = 15,
		TextColor3 = ev.ink, Text = guide, TextScaled = true, ZIndex = 3,
	}, card)
	local ok = create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = ev.accent, FontFace = BOLD, TextSize = 18, TextColor3 = WHITE, Text = "확인", ZIndex = 3,
	}, card)
	corner(ok, 20)
	create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Thickness = 2 }, ok)

	local closing = false
	local function close()
		if closing then return end
		closing = true
		pcall(function() Sfx.play("click") end)
		tween(cardScale, 0.18, { Scale = 0.6 })
		tween(dim, 0.18, { BackgroundTransparency = 1 })
		task.delay(0.2, function()
			gui:Destroy()
			if showing == gui then showing = nil end
		end)
	end
	ok.Activated:Connect(close)
	task.delay(0.8, function() -- (a tap on the dim closes too, once the card is up)
		if gui.Parent then dim.Activated:Connect(close) end
	end)
	task.spawn(function()
		local s0 = os.clock()
		while gui.Parent and not closing do
			show.Position = UDim2.new(0.5, 0, 0, 64 + math.sin((os.clock() - s0) * 2.4) * 4)
			task.wait()
		end
	end)
end

return RewardReveal
