--!strict
-- Loading screen (user 2026-10-30). Three places take turns with a slow
-- dissolve, each with a short line about the place and a tip:
--   1  해변 카페   warm, bright lights swaying slowly (cafe mood)
--   2  OHU CLUB    neon beams sweeping fast in pink / cyan / violet
--   3  오후네컷     pastel beams and twinkling sparkles (cute)
-- Backgrounds are shots of our own map (docs/04_ART/loading/). Every scene
-- sits in its own Frame and its picture, beams and colour wash fade
-- together. The screen closes when the game is loaded and it has been up
-- at least MIN_SECONDS (a 건너뛰기 button shows once loading is done).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local SCENE_SECONDS = 7 -- each place stays this long
local FADE = 2.2 -- the dissolve
local MIN_SECONDS = 8
local MAX_SECONDS = 40 -- never keep a player out longer than this
local BEAM = "rbxassetid://109650761162030"

type Scene = {
	image: string,
	title: string,
	sub: string,
	about: string,
	tip: string,
	wash: Color3,
	washAlpha: number,
	beams: {Color3},
	sway: number, -- degrees
	speed: number,
	beamAlpha: number,
	sparkles: boolean,
}

local SCENES: {Scene} = {
	{
		image = "rbxassetid://100654769747963",
		title = "오후의 거리",
		sub = "BEACH CAFE",
		about = "바다가 보이는 통창 카페에서 커피 한 잔, 피아노 한 곡.",
		tip = "카페 안쪽 작업대에서 알바를 시작하면 코인을 모을 수 있어요.",
		wash = Color3.fromRGB(255, 170, 90),
		washAlpha = 0.84,
		beams = { Color3.fromRGB(255, 226, 170), Color3.fromRGB(255, 205, 140), Color3.fromRGB(255, 240, 205), Color3.fromRGB(255, 214, 160) },
		sway = 9,
		speed = 0.35,
		beamAlpha = 0.55,
		sparkles = false,
	},
	{
		image = "rbxassetid://98281600315142",
		title = "OHU CLUB",
		sub = "OPEN 18:00 – 06:00",
		about = "밤에만 문을 여는 클럽. DJ가 되어 직접 음악을 틀어 보세요.",
		tip = "테이블을 터치하면 음료를 놓고 친구들과 함께 즐길 수 있어요.",
		wash = Color3.fromRGB(120, 40, 200),
		washAlpha = 0.86,
		beams = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 235, 255), Color3.fromRGB(160, 90, 255), Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 235, 255), Color3.fromRGB(160, 90, 255), Color3.fromRGB(120, 255, 170) },
		sway = 34,
		speed = 1.6,
		beamAlpha = 0.35,
		sparkles = false,
	},
	{
		image = "rbxassetid://97375697970209",
		title = "오후네컷",
		sub = "PINK · WHITE · SKY ROOM",
		about = "세 개의 부스에서 친구와 함께 네컷 사진을 찍어요.",
		tip = "찍은 사진은 가방에 차곡차곡 저장돼요.",
		wash = Color3.fromRGB(255, 160, 205),
		washAlpha = 0.86,
		beams = { Color3.fromRGB(255, 182, 218), Color3.fromRGB(180, 222, 255), Color3.fromRGB(222, 196, 255), Color3.fromRGB(255, 236, 170), Color3.fromRGB(255, 182, 218) },
		sway = 16,
		speed = 0.6,
		beamAlpha = 0.5,
		sparkles = true,
	},
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "OHULoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ScreenInsets = Enum.ScreenInsets.None

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(12, 10, 16)
root.BorderSizePixel = 0
root.Parent = gui

local function new(class: string, props: {[string]: any}, parent: Instance): any
	local o = Instance.new(class)
	for k, v in pairs(props) do (o :: any)[k] = v end
	o.Parent = parent
	return o
end

local function gradient(parent: Instance, rotation: number, keys: {{number}})
	local list = {}
	for _, k in ipairs(keys) do table.insert(list, NumberSequenceKeypoint.new(k[1], k[2])) end
	new("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(list) }, parent)
end

-- one scene: picture, colour wash, light fixtures with beams, sparkles
-- (plain Frames faded piece by piece: three full-screen CanvasGroups did not
-- all draw on a phone-sized budget, the club kept showing the booth picture)
type Built = { group: Frame, beams: {Frame}, sparkles: {TextLabel}, fixed: {{ obj: GuiObject, prop: string, base: number }}, opacity: number }
local built: {Built} = {}
for i, scene in ipairs(SCENES) do
	local group = new("Frame", {
		Name = "Scene" .. i, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = i,
	}, root)
	new("ImageLabel", {
		Name = "Picture", Size = UDim2.fromScale(1.06, 1.06), Position = UDim2.fromScale(-0.03, -0.03),
		BackgroundTransparency = 1, Image = scene.image, ScaleType = Enum.ScaleType.Crop,
	}, group)
	new("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = scene.wash, BackgroundTransparency = scene.washAlpha, BorderSizePixel = 0 }, group)
	-- beams hang from fixtures along the top
	local beams = {}
	local n = #scene.beams
	for b, colour in ipairs(scene.beams) do
		local x = (b - 0.5) / n
		local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, -0.02), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 }, group)
		-- a soft cone of light fading downwards (docs/04_ART/loading/beam.png);
		-- its size follows the screen height every frame
		new("ImageLabel", {
			Name = "Strip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(200, 600), BackgroundTransparency = 1, Image = BEAM,
			ImageColor3 = colour, ImageTransparency = scene.beamAlpha,
		}, holder)
		-- the fixture
		local fixture = new("Frame", { Name = "Fixture", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = colour, BorderSizePixel = 0 }, holder)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, fixture)
		table.insert(beams, holder)
	end
	local sparkles = {}
	if scene.sparkles then
		for s = 1, 14 do
			-- hearts and round glints (Gotham has no star glyph)
			local star = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.random(), math.random() * 0.75),
				Size = if s % 2 == 0 then UDim2.fromOffset(26, 26) else UDim2.fromOffset(9, 9),
				BackgroundTransparency = if s % 2 == 0 then 1 else 0, BackgroundColor3 = Color3.new(1, 1, 1),
				Text = if s % 2 == 0 then "♥" else "",
				TextColor3 = if s % 4 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 160, 210),
				TextScaled = true, Font = Enum.Font.GothamBold,
			}, group)
			if s % 2 == 1 then new("UICorner", { CornerRadius = UDim.new(1, 0) }, star) end
			star:SetAttribute("Phase", math.random() * 6.28)
			table.insert(sparkles, star)
		end
	end
	-- the parts that keep their own transparency (beams and sparkles change every frame)
	local fixed = {}
	table.insert(fixed, { obj = group.Picture, prop = "ImageTransparency", base = 0 })
	table.insert(fixed, { obj = group.Wash, prop = "BackgroundTransparency", base = scene.washAlpha })
	for _, holder in ipairs(beams) do
		table.insert(fixed, { obj = holder.Fixture, prop = "BackgroundTransparency", base = 0 })
	end
	table.insert(built, { group = group, beams = beams, sparkles = sparkles, fixed = fixed, opacity = if i == 1 then 1 else 0 })
end

-- dark band at the bottom for the text (over every scene)
local shade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.55), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 15 }, root)
gradient(shade, 90, { { 0, 1 }, { 0.6, 0.55 }, { 1, 0.3 } })

-- 0 = clear, 1 = fully shown
local function seen(base: number, opacity: number): number
	return 1 - (1 - base) * opacity
end

-- text (above every scene)
local textLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, root)
new("UIPadding", { PaddingLeft = UDim.new(0.05, 0), PaddingRight = UDim.new(0.05, 0), PaddingBottom = UDim.new(0.07, 0), PaddingTop = UDim.new(0.05, 0) }, textLayer)
local logo = new("TextLabel", {
	Size = UDim2.new(0.4, 0, 0.09, 0), BackgroundTransparency = 1, Text = "OHU  오후",
	TextColor3 = Color3.new(1, 1, 1), TextScaled = true, Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
}, textLayer)
new("UIStroke", { Thickness = 1, Transparency = 0.6 }, logo)
local info = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(0.75, 0, 0.36, 0), BackgroundTransparency = 1, ZIndex = 21 }, textLayer)
local sub = new("TextLabel", { Size = UDim2.new(1, 0, 0.16, 0), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 220, 240), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, info)
local title = new("TextLabel", { Position = UDim2.fromScale(0, 0.17), Size = UDim2.new(1, 0, 0.36, 0), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, info)
local about = new("TextLabel", { Position = UDim2.fromScale(0, 0.56), Size = UDim2.new(1, 0, 0.18, 0), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamMedium, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, info)
local tip = new("TextLabel", { Position = UDim2.fromScale(0, 0.8), Size = UDim2.new(1, 0, 0.16, 0), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(255, 230, 160), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, info)
for _, t in ipairs({ sub, title, about, tip }) do
	new("UITextSizeConstraint", { MaxTextSize = if t == title then 46 elseif t == sub then 16 else 18, MinTextSize = 10 }, t)
end

-- progress bar along the bottom
local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0.6, 0, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 21 }, textLayer)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 22 }, bar)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
local status = new("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -12), Size = UDim2.new(0.6, 0, 0, 16), BackgroundTransparency = 1, Text = "불러오는 중… 0%", TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(230, 230, 235), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, textLayer)
local skip = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(96, 34), BackgroundColor3 = Color3.fromRGB(18, 18, 21), BackgroundTransparency = 0.4, Text = "건너뛰기", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 22 }, textLayer)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, skip)

local function showText(i: number)
	local scene = SCENES[i]
	for _, t in ipairs({ sub, title, about, tip }) do
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end
	task.delay(0.55, function()
		sub.Text, title.Text, about.Text, tip.Text = scene.sub, scene.title, scene.about, "TIP  ·  " .. scene.tip
		for _, t in ipairs({ sub, title, about, tip }) do
			TweenService:Create(t, TweenInfo.new(0.9), { TextTransparency = 0 }):Play()
		end
	end)
end

gui.Parent = playerGui
-- the pictures first, so the first scene is not grey
task.spawn(function()
	local images = {}
	for _, g in ipairs(built) do table.insert(images, g.group:FindFirstChildOfClass("ImageLabel") :: Instance) end
	pcall(function() ContentProvider:PreloadAsync(images) end)
end)
showText(1)

local started = os.clock()
local current, previous = 1, 0
local fadeAt = -100 -- when the last dissolve began
local nextAt = started + SCENE_SECONDS
local shown = 0
local done = false
local closeAt: number? = nil

local function close()
	if closeAt then return end
	closeAt = os.clock()
	for _, d in ipairs(textLayer:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end
	for _, f in ipairs({ root, bar, fill, shade }) do
		TweenService:Create(f, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end
	task.delay(0.9, function()
		done = true
		gui:Destroy()
	end)
end
skip.Activated:Connect(close)

local startQueue = math.max(ContentProvider.RequestQueueSize, 1)
local connection: RBXScriptConnection
connection = RunService.RenderStepped:Connect(function()
	if done then connection:Disconnect() return end
	local now = os.clock()
	local t = now - started
	-- scenes: a slow dissolve from the previous place to the current one
	if now >= nextAt and not closeAt then
		previous, current = current, current % #SCENES + 1
		fadeAt, nextAt = now, now + SCENE_SECONDS
		built[current].group.ZIndex, built[previous].group.ZIndex = 10, 5
		showText(current)
	end
	local k = math.clamp((now - fadeAt) / FADE, 0, 1)
	k = k * k * (3 - 2 * k)
	local ending = if closeAt then 1 - math.clamp((now - closeAt) / 0.8, 0, 1) else 1
	for i, g in ipairs(built) do
		g.opacity = (if i == current then k elseif i == previous then 1 - k else 0) * ending
		if previous == 0 and i == current then g.opacity = ending end
	end
	-- lights
	local height = root.AbsoluteSize.Y
	for i, g in ipairs(built) do
		g.group.Visible = g.opacity > 0
		if g.opacity > 0 then
			local scene = SCENES[i]
			for _, part in ipairs(g.fixed) do
				(part.obj :: any)[part.prop] = seen(part.base, g.opacity)
			end
			for b, holder in ipairs(g.beams) do
				local phase = b * 1.7
				holder.Rotation = math.sin(t * scene.speed + phase) * scene.sway + (b - (#g.beams + 1) / 2) * 6
				local strip = holder:FindFirstChild("Strip") :: ImageLabel
				strip.Size = UDim2.fromOffset(height * 0.55, height * 1.25)
				local alpha = scene.beamAlpha
				if i == 2 then
					-- neon: colours flick between the three every beat, brighter on the beat
					local c = (math.floor(t * 2) + b) % #scene.beams + 1
					strip.ImageColor3 = scene.beams[c]
					alpha += 0.25 * ((t * 2) % 1)
				end
				strip.ImageTransparency = seen(alpha, g.opacity)
			end
			for s, star in ipairs(g.sparkles) do
				local p = (star:GetAttribute("Phase") :: number) + t * 1.8
				local fade = seen(0.25 + 0.75 * (0.5 + 0.5 * math.sin(p)), g.opacity)
				if star.Text == "" then star.BackgroundTransparency = fade else star.TextTransparency = fade end
				star.Rotation = math.sin(p * 0.5) * 20
				star.Position = UDim2.new(star.Position.X.Scale, 0, (s / #g.sparkles * 0.75 + t * 0.012) % 0.8, math.sin(p) * 6)
			end
		end
	end
	-- progress
	local loaded = game:IsLoaded()
	local target = if loaded then 1 else math.clamp(1 - ContentProvider.RequestQueueSize / startQueue, 0.05, 0.92)
	shown += (target - shown) * 0.06
	fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
	status.Text = if loaded and shown > 0.98 then "준비 완료!" else string.format("불러오는 중… %d%%", math.floor(shown * 100))
	skip.Visible = loaded
	-- (attribute HoldLoading on Workspace keeps it up, for checking the look in Studio)
	if workspace:GetAttribute("HoldLoading") then return end
	if (loaded and t >= MIN_SECONDS and shown > 0.98) or t >= MAX_SECONDS then
		close()
	end
end)
