--!strict
-- (D-1365, user 2026-11-13: "처음 튜토리얼 만들었을 때 카메라 움직이면서 장소 확대해서 보여 주던 거
-- 다시 만들자. 오후네컷, 클럽, 국밥집, 편의점, 카페, 해변, 공사 중인 놀이공원이랑 한옥마을. 동선
-- 깔끔한 순서대로 계산해서 보여 줘. 그리고 홈 화면 상단에 있는 버튼도 간단하게 소개해 줘. 특히
-- 카탈로그 설명에서 무료로 마음껏 내가 원하는대로 예쁜 캐릭터를 꾸미고 자랑할 수 있다는 식의 문구
-- 넣고 음표 버튼은 누르면 밖에서도 언제든 노래 들을 수 있다고 소개하고. 스킵 버튼 넣고.")
-- The first-visit tour again (the old one went in D-845): a card at the bottom, the camera
-- flying to each place in one loop from the spawn (nearest next: 오후네컷 → 클럽 → 국밥집 →
-- 놀이공원 → 해변 → 카페 → 편의점 → 한옥 마을), then back to the player while each top bar
-- button is shown with a pulsing ring. 건너뛰기 ends it at any step. Seen once: the "tour2"
-- key of the tips the server remembers (GuideService "TipSeen"; TipsSeen attribute), so the
-- players who saw the old tour get this one once too. TourController.start() is not needed
-- elsewhere: the guide NPC's last question can start it again (UiBus.StartTour).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local NearButton = require(script.Parent:WaitForChild("NearButton")) -- (D-1539)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TOUR_KEY = "tour2"

-- (D-1367, user 2026-11-13) `path`: more camera stops after the first one, each glided to in
-- t seconds (오후네컷 from the street in through the door, the cafe toward its glass wall);
-- `fov`: a longer lens for this view (the beach: parasols and tubes in one frame)
type Key = { eye: Vector3, look: Vector3, t: number }
-- (D-1694, user 2026-11-17) the guide rabbit tells the tour in its own words (반말, one text size, no
-- big title); `yes` / `no`: the two answer buttons side by side at the bottom right for this card ("no"
-- ends the tour), `quiet`: the rabbit is not shown (the top bar button cards), `done`: the last button
type Step = { title: string, text: string, eye: Vector3?, look: Vector3?, button: number?, path: {Key}?, fov: number?,
	yes: string?, no: string?, quiet: boolean?, done: string? }
local STEPS: {Step} = {
	{ title = "", text = "오후에 온 걸 환영해! 내가 사는 동네 구경시켜 줄까?", yes = "응!", no = "아니, 괜찮아!" },
	{ title = "📸 오후네컷", text = "여기는 친구랑 네 컷 사진을 찍는 오후네컷이야. 예쁜 촬영 부스 세 곳과 볼풀이 있어. 찍은 사진은 벽에 붙여서 모두한테 자랑할 수도 있어!",
		eye = Vector3.new(14, 22, -20), look = Vector3.new(52, 12, -56),
		path = { -- (D-1367: from the street up to the corner door, then inside)
			{ eye = Vector3.new(44, 9, -48), look = Vector3.new(64, 8, -66), t = 2.4 },
			{ eye = Vector3.new(60, 10, -62), look = Vector3.new(130, 7, -84), t = 2.8 },
		} },
	{ title = "🎧 OHU CLUB", text = "오후 클럽은 밤(18:00~6:00)에만 문을 열어. 함께 춤추고 놀 수 있는 핫플레이스야. 각종 케이팝 안무를 따라 추고, DJ가 되면 플레이리스트와 조명을 내 마음대로 운영할 수 있어.",
		eye = Vector3.new(-30, 38, -185), look = Vector3.new(60, 6, -205) },
	{ title = "🍲 오후 돼지국밥", text = "열심히 춤추고 놀아서 출출해지면 오는 국밥집이야. 맛있는 국밥과 수육을 팔아. 음식을 먹으면 경험치(XP)도 올라! 국밥 좋아하니?",
		eye = Vector3.new(10, 42, -295), look = Vector3.new(88, 14, -334) },
	-- (D-1547) the park is open
	{ title = "🎡 OHU LAND", text = "짜잔! 놀이공원이 문을 열었어! 바이킹, 회전컵, 관람차, 범퍼카를 타면서 놀자. 개장 기념으로 무료 풍선을 주고 있대.",
		eye = Vector3.new(-97, 48, -200), look = Vector3.new(-97, 28, -290) },
	{ title = "🏖 해변", text = "파도 소리 듣고 싶을 때 오는 해변이야. 날이 좋을 때는 튜브 타면서 물놀이도 하고 비치볼도 던지면서 놀아.",
		eye = Vector3.new(-350, 13, -14), look = Vector3.new(-250, -5, -36), fov = 32 }, -- (D-1367: from the sea, tubes and parasols together)
	{ title = "☕ OHU CAFE · Sunset", text = "옆에는 바다가 한눈에 보이는 카페가 있어. 달달한 디저트와 카페인 수혈이 필요할 때마다 오는 곳이야. 카페에서 일하면 코인도 벌 수 있어. 사 먹은 음식과 음료는 경험치(XP)도 올려 줘!",
		eye = Vector3.new(-284, 12, 338), look = Vector3.new(-330, 9, 300),
		path = { { eye = Vector3.new(-292, 17, 318), look = Vector3.new(-440, 4, 280), t = 3.2 } } }, -- (D-1367: inside, out to the sea through the glass wall)
	{ title = "🏪 OH24 편의점", text = "물놀이 후에는 역시 컵라면이지. 편의점에서는 과자, 아이스크림, 컵라면, 삼각김밥을 팔고 있어. 친구바는 친구랑 반씩 나눠 먹을 수도 있어~ 먹을수록 경험치(XP)도 쑥쑥!",
		eye = Vector3.new(-5, 40, 95), look = Vector3.new(-70, 10, 140) },
	{ title = "🏯 광화문", text = "이곳은 야경이 예쁜 광화문이야. 개장을 기다리고 있지. 두근두근.",
		-- (D-1367) from the plaza in front, a little low: the inside (still being built) is not seen
		eye = Vector3.new(89, 7, 93), look = Vector3.new(144.5, 16, 147.3) },
	{ title = "", text = "내가 사는 동네 소개는 여기까지! 화면 버튼에 대한 설명도 들을래?", yes = "응!", no = "아니, 괜찮아!" },
	{ title = "🕐 시계", text = "지금이 몇 시인지 알 수 있는 동네 시계야. 클럽에 가고 싶으면 시간을 꼭 확인해야 해.", button = 11, quiet = true },
	{ title = "₩ 코인", text = "내 지갑이야. 접속만 하고 있어도 1분마다 1코인이 쌓여. 카페 알바를 하면 더 벌 수 있어.", button = 10, quiet = true },
	{ title = "♥ 후원", text = "동네 발전을 위해 응원하는 후원 창이야. 후원하면 모두의 화면에 내 이름과 메시지가 떠.", button = 5, quiet = true },
	-- (D-1367, user: many players stay in the default look) the free part first and plainly
	{ title = "👗 카탈로그", text = "무료로 캐릭터를 꾸밀 수 있는 카탈로그야. 내 마음대로 예쁘게 꾸미고 자랑해 봐. 마음에 드는 착장은 옷장에 저장해 놓고 바꿔 입을 수 있어.", button = 4, quiet = true },
	{ title = "🎒 가방", text = "what's in my bag~! 내 가방이야. 내가 산 아이템들과 찍은 사진을 다시 보고 싶을 때는 여기를 누르면 돼.", button = 3, quiet = true },
	{ title = "♪ 음악 · 춤", text = "클럽에 들어가지 않아도 클럽에서 재생 중인 노래를 들을 수 있어. 예쁜 야외 배경을 무대 삼아 아이돌처럼 춤출 수 있어.", button = 1, quiet = true },
	{ title = "💬 의견 보내기", text = "불편한 점이나 바라는 점을 개발자에게 보낼 수 있어.", button = 2, quiet = true },
	-- (D-1722, user 2026-11-18: "메뉴 버튼에 대한 설명도 넣어야겠다") the ☰ menu (TopBar order 20)
	{ title = "☰ 메뉴", text = "닉네임과 칭호를 보이거나 숨기고, 놀이공원 환호성과 폭죽 소리를 끄거나 화면 버튼을 잠깐 숨길 수 있어.", button = 20, quiet = true },
	{ title = "", text = "그럼 오후에서 즐거운 시간 보내!", done = "놀러가기" },
}

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

-- (D-1699, user 2026-11-17: "투어 창에 빈 여백 너무 많아 좀 줄여") the card's height: 118 → 92 (two or three
-- lines and the 다음 button), and 150 → 104 under a top bar button
local CARD_H = 92
local gui = create("ScreenGui", { Name = "FashionTourGui", ResetOnSpawn = false, DisplayOrder = 45, IgnoreGuiInset = true, Enabled = false }, playerGui)
local card = create("Frame", {
	Name = "TourCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), -- (above the hotbar)
	Size = UDim2.new(1, -40, 0, CARD_H), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
local cardLimit = create("UISizeConstraint", { MaxSize = Vector2.new(560 + 96, CARD_H) }, card)
create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.2 }, card)
-- (D-1692, user 2026-11-17: "안내원 토끼가 인사하는 모션으로 상반신만 보이게 텍스트 왼쪽에 넣어서 안내원 토끼가
-- 말하는 것처럼") the guide rabbit waving at the card's left (GuideSpeaker); the text starts after it
local SPEAKER = 96
local speaker = require(script.Parent:WaitForChild("GuideSpeaker")).attach(card, SPEAKER)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(SPEAKER + 10, 10), Size = UDim2.new(1, -100 - SPEAKER, 0, 30), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
	TextScaled = false, Text = "",
}, card)
local count = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(70, 22),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 200),
	TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, card)
local body = create("TextLabel", {
	Position = UDim2.fromOffset(SPEAKER + 10, 44), Size = UDim2.new(1, -130 - SPEAKER, 0, 64), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 12 }, body)
body.TextScaled = true
local skip = create("TextButton", {
	Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 0, -6), Size = UDim2.fromOffset(92, 28),
	BackgroundColor3 = Color3.new(0, 0, 0), Text = "건너뛰기 >", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, skip)
-- (D-1536, user 2026-11-16: "튜토리얼 블랙앤화이트로 수정") black and white only: the black card with
-- its white line, a black 건너뛰기 with a white line, a white 다음 with black words, a white ring
create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skip)
local nextButton = create("TextButton", {
	Name = "Next", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(96, 40),
	BackgroundColor3 = Color3.new(1, 1, 1), Text = "다음 ▶", TextColor3 = Color3.new(0, 0, 0),
	Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, nextButton)

-- (D-1539) a step about a top bar button: the card right under that button, a pointer up to it,
-- 건너뛰기 inside the card (above it would sit on the bar); other steps: at the bottom as before
local pointer = NearButton.pointer(card)
local answer = false -- (D-1694: this card asks yes / no: 아니, 괜찮아! beside 응!)
local NEAR_W, NEAR_H = 330 + 96, 104 -- (+96: the guide at the left, D-1692; 150 high until D-1699)
local function cardAt(nearButton: boolean)
	if nearButton then
		cardLimit.MaxSize = Vector2.new(560 + 96, NEAR_H)
		card.Size = UDim2.fromOffset(NEAR_W, NEAR_H)
		skip.AnchorPoint = Vector2.new(0, 1)
		skip.Position = UDim2.new(0, 12, 1, -12)
	else
		cardLimit.MaxSize = Vector2.new(560 + 96, CARD_H)
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, -96)
		card.Size = UDim2.new(1, -40, 0, CARD_H)
		skip.AnchorPoint = Vector2.new(1, 1)
		skip.Position = UDim2.new(1, -8, 0, -6)
		pointer.Visible = false
	end
	-- (D-1699) under a top bar button 건너뛰기 sits in the card's bottom left: the words stop above it
	body.Size = UDim2.new(body.Size.X.Scale, body.Size.X.Offset, 1, if nearButton then -54 else -24)
	if answer then
		skip.AnchorPoint = Vector2.new(1, 1)
		skip.Position = UDim2.new(1, -12 - 96 - 8, 1, -12)
		skip.Size = UDim2.fromOffset(120, 40)
		skip.TextSize = 15
	else
		skip.Size = UDim2.fromOffset(92, 28)
		skip.TextSize = 14
	end
end

-- the ring round the top bar button being explained (it pulses)
local ring = create("Frame", { Name = "Ring", BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
local ringStroke = create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4 }, ring)
local ringTarget: GuiObject? = nil
game:GetService("RunService").RenderStepped:Connect(function()
	local target = ringTarget
	if not target or not ring.Visible then return end
	NearButton.place(card, pointer, target, NEAR_W) -- (D-1539)
	-- (AbsolutePosition leaves out the top bar inset even here: add it, D-1138)
	local inset = game:GetService("GuiService"):GetGuiInset()
	local pad = 6 + 3 * math.sin(os.clock() * 6)
	ring.Position = UDim2.fromOffset(target.AbsolutePosition.X - pad, target.AbsolutePosition.Y + inset.Y - pad)
	ring.Size = UDim2.fromOffset(target.AbsoluteSize.X + pad * 2, target.AbsoluteSize.Y + pad * 2)
	ringStroke.Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 6))
end)

local camera = workspace.CurrentCamera
local flight: Tween? = nil
local flightToken = 0
local savedFov: number? = nil -- (the player's field of view while a step uses its own)
local function flyTo(eye: Vector3, look: Vector3, path: {Key}?, fov: number?)
	local cf = CFrame.lookAt(eye, look)
	task.spawn(function()
		pcall(function() player:RequestStreamAroundAsync(look, 2) end)
		for _, key in ipairs(path or {}) do pcall(function() player:RequestStreamAroundAsync(key.look, 2) end) end
	end)
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if not savedFov then savedFov = camera.FieldOfView end
	pcall(function() Sfx.play("whoosh") end)
	if flight then flight:Cancel() end
	flightToken += 1
	local token = flightToken
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	flight = TweenService:Create(camera, info, { CFrame = cf, FieldOfView = fov or savedFov })
	;(flight :: Tween):Play()
	if path and #path > 0 then
		task.spawn(function()
			task.wait(1.6 + 0.5)
			for i, key in ipairs(path) do
				if token ~= flightToken then return end
				-- (one smooth glide: eased in at the first stop, out at the last)
				local style = if #path == 1 then Enum.EasingDirection.InOut elseif i == 1 then Enum.EasingDirection.In elseif i == #path then Enum.EasingDirection.Out else nil
				local tween = TweenService:Create(camera,
					TweenInfo.new(key.t, if style then Enum.EasingStyle.Sine else Enum.EasingStyle.Linear, style or Enum.EasingDirection.InOut),
					{ CFrame = CFrame.lookAt(key.eye, key.look) })
				flight = tween
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end
end
local function cameraBack()
	flightToken += 1
	if flight then flight:Cancel() flight = nil end
	camera = workspace.CurrentCamera
	if savedFov then camera.FieldOfView = savedFov savedFov = nil end
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	-- back behind the character (the game camera went on from the last place's view)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		local focus = root.Position + Vector3.new(0, 1.5, 0)
		camera.CFrame = CFrame.lookAt(focus - look * 12 + Vector3.new(0, 4, 0), focus)
		camera.Focus = CFrame.new(focus)
	end
end

local touring = false
local step = 0
-- (D-1694, user: "투어 위에 큰 글씨 삭제하고 아래 긴 텍스트 사이즈로 문구 모두 수정") no title line: the
-- rabbit's words fill the card at the body's size; the top bar button cards have no rabbit (quiet)
title.Visible = false
local function layoutText(withSpeaker: boolean)
	local left = if withSpeaker then SPEAKER + 10 else 18
	body.Position = UDim2.fromOffset(left, 12)
	body.Size = UDim2.new(1, -(left + 120), 1, -24)
	speaker.Visible = withSpeaker
end
local SKIP_TEXT = skip.Text
local function show()
	local s = STEPS[step]
	title.Text = s.title
	body.Text = s.text
	count.Text = string.format("%d / %d", step, #STEPS)
	nextButton.Text = s.yes or s.done or (if step == #STEPS then "놀러가기" else "다음 ▶")
	layoutText(not s.quiet)
	-- (D-1694, user: "처음에만 다음/건너뛰기 두 버튼 오른쪽 아래에 나란히") a yes / no card: 아니, 괜찮아! sits
	-- left of 응! at the bottom right, in the card (the usual 건너뛰기 rides above the card's corner)
	answer = s.no ~= nil
	skip.Text = s.no or SKIP_TEXT
	-- (D-1699, user 2026-11-17: "마지막에는 끝났으니까 건너뛰기 삭제") the last card has only 놀러가기
	skip.Visible = s.done == nil
	if s.eye and s.look then
		flyTo(s.eye, s.look, s.path, s.fov)
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		cameraBack()
	end
	ringTarget = if s.button then TopBar.button(s.button) else nil
	ring.Visible = ringTarget ~= nil and ringTarget.Visible
	cardAt(ring.Visible) -- (D-1539)
end

local function finish()
	if not touring then return end
	touring = false
	gui.Enabled = false
	ring.Visible = false
	ringTarget = nil
	cameraBack()
	player:SetAttribute("TourActive", nil)
	Popups.closed("Tour")
	task.spawn(function() pcall(function() remote:InvokeServer("TipSeen", TOUR_KEY) end) end)
end

local function start()
	if touring then return end
	touring = true
	step = 1
	gui.Enabled = true
	player:SetAttribute("TourActive", true)
	Popups.opened("Tour", finish)
	show()
end

-- (D-1524) analytics: TourEnd, the card reached and whether it was skipped
local function report(kind: string)
	local gate = FashionGame:WaitForChild("Remotes"):FindFirstChild("AnalyticsStep")
	if touring and gate and gate:IsA("RemoteEvent") then gate:FireServer(kind, step) end
end

nextButton.Activated:Connect(function()
	if not touring then return end
	if step >= #STEPS then report("TourDone") finish() return end
	step += 1
	show()
end)
skip.Activated:Connect(function()
	report("TourSkip")
	finish()
end)
if UiBus.StartTour then UiBus.StartTour.Event:Connect(start) end

-- (D-1523, user: "첫 접속엔 목표만") the first visit no longer started the tour by itself.
-- (D-1690, user 2026-11-17: "투어 추가해 투어 끝나고 출석 이벤트 보여 주고 목표 안내 순서") it does again:
-- the first visit is ① this tour → ② the opening attendance window (OpeningEventController waits
-- while TourActive) → ③ the first goal (FirstGoalController waits for both). Once: the "tour2" tip;
-- the guide NPC's question still starts it again. (Studio: FirstGoalTest = true shows it every Play.)
task.spawn(function()
	local TEST = game:GetService("RunService"):IsStudio() and FashionGame:GetAttribute("FirstGoalTest") == true
	-- (D-1731, user 2026-11-18: "스튜디오에 튜토리얼이랑 출석 체크 이벤트 띄우지 마 실제로 플레이어들한테는 사용해야 함")
	-- in Studio the tour starts by itself only with FirstGoalTest on (test players are new every Play);
	-- live servers are unchanged
	if game:GetService("RunService"):IsStudio() and not TEST then return end
	local waited = 0
	while player:GetAttribute("TipsSeen") == nil and waited < 20 do
		task.wait(0.5)
		waited += 0.5
	end
	local ok, keys = pcall(function() return HttpService:JSONDecode(player:GetAttribute("TipsSeen") or "[]") end)
	local seen = ok and typeof(keys) == "table" and table.find(keys, TOUR_KEY) ~= nil
	if seen and not TEST then return end
	if not player.Character then player.CharacterAdded:Wait() end
	local t0 = os.clock()
	while playerGui:FindFirstChild("OHULoading") and os.clock() - t0 < 90 do task.wait(0.5) end
	task.wait(1.5)
	start()
end)
