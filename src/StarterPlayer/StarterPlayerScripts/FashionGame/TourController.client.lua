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

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TOUR_KEY = "tour2"

type Step = { title: string, text: string, eye: Vector3?, look: Vector3?, button: number? }
local STEPS: {Step} = {
	{ title = "👋 오후에 오신 걸 환영해요!", text = "동네를 한 바퀴 둘러볼게요. 언제든 오른쪽 위 '건너뛰기'로 끝낼 수 있어요." },
	{ title = "📸 오후네컷", text = "친구랑 네 컷 사진을 찍는 사진관이에요. 찍은 사진은 사진첩에 남고, 포토월에 붙여 자랑할 수도 있어요.",
		eye = Vector3.new(20, 34, -40), look = Vector3.new(100, 4, -84) },
	{ title = "🎧 OHU CLUB", text = "밤(18:00~06:00)에 문을 여는 클럽이에요. 노래를 신청하고, 안무를 따라 추고, DJ도 될 수 있어요.",
		eye = Vector3.new(-30, 38, -185), look = Vector3.new(60, 6, -205) },
	{ title = "🍲 오후 돼지국밥", text = "국밥을 사서 자리에서 먹어요. 수육 한 접시는 테이블에 놓고 다 같이 나눠 먹어요.",
		eye = Vector3.new(10, 42, -295), look = Vector3.new(88, 14, -334) },
	{ title = "🎡 OHU LAND (공사 중)", text = "놀이공원은 지금 공사 중이에요. 곧 문을 열어요! 계단 위 정문 앞까지는 올라가 볼 수 있어요.",
		eye = Vector3.new(-97, 48, -200), look = Vector3.new(-97, 28, -290) },
	{ title = "🏖 해변", text = "튜브를 타고 바다에서 물놀이를 하고, 비치볼도 던지며 놀아요.",
		eye = Vector3.new(-170, 46, -20), look = Vector3.new(-300, 2, -60) },
	{ title = "☕ OHU CAFE · Sunset", text = "바다가 보이는 카페예요. 음료와 빵을 먹고, 카운터 안쪽에서 알바를 하면 코인을 벌 수 있어요.",
		eye = Vector3.new(-160, 42, 205), look = Vector3.new(-245, 10, 272) },
	{ title = "🏪 OH24 편의점", text = "과자·아이스크림·컵라면을 사는 편의점이에요. 친구바는 친구를 눌러 반씩 나눠 먹어요.",
		eye = Vector3.new(-5, 40, 95), look = Vector3.new(-70, 10, 140) },
	{ title = "🏯 광화문 · 한옥 마을", text = "광화문을 지나 돌담길을 따라가면 한옥 마을이에요. 사진 찍기 좋은 곳이에요.",
		eye = Vector3.new(55, 75, 60), look = Vector3.new(220, 20, 260) },
	{ title = "📱 화면 버튼", text = "동네 소개는 여기까지예요! 이제 화면 위쪽 버튼들을 하나씩 알려 드릴게요." },
	{ title = "🕐 시계", text = "게임 속 시간이에요. 하루는 30분이고, 클럽은 밤에 열려요.", button = 11 },
	{ title = "₩ 코인", text = "가진 코인이에요. 게임에 있으면 1분마다 쌓이고, 카페 알바를 하면 더 벌어요.", button = 10 },
	{ title = "♥ 후원", text = "게임을 응원하는 후원이에요. 후원하면 모두의 화면 위에 내 이름과 메시지가 떠요.", button = 5 },
	{ title = "👗 카탈로그", text = "무료 아이템으로 마음껏, 내가 원하는 대로 예쁜 캐릭터를 꾸미고 자랑해 보세요! 입어 보고 마음에 들면 그대로 저장돼요.", button = 4 },
	{ title = "🎒 가방", text = "산 음식과 음료, 찍은 사진첩이 들어 있어요.", button = 3 },
	{ title = "♪ 음악 · 춤", text = "누르면 클럽 밖에서도 언제든 클럽 노래를 들을 수 있어요. 아래 목록에서 춤을 골라 출 수도 있어요.", button = 1 },
	{ title = "💬 의견 보내기", text = "불편한 점이나 바라는 점을 개발자에게 바로 보낼 수 있어요.", button = 2 },
	{ title = "✨ 준비 끝!", text = "즐거운 시간 보내세요!" },
}

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

local gui = create("ScreenGui", { Name = "FashionTourGui", ResetOnSpawn = false, DisplayOrder = 45, IgnoreGuiInset = true, Enabled = false }, playerGui)
local card = create("Frame", {
	Name = "TourCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), -- (above the hotbar)
	Size = UDim2.new(1, -40, 0, 118), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
create("UISizeConstraint", { MaxSize = Vector2.new(560, 118) }, card)
create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.2 }, card)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -100, 0, 30), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
	TextScaled = false, Text = "",
}, card)
local count = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(70, 22),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 205),
	TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, card)
local body = create("TextLabel", {
	Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -130, 0, 64), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 12 }, body)
body.TextScaled = true
local skip = create("TextButton", {
	Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 0, -6), Size = UDim2.fromOffset(92, 28),
	BackgroundColor3 = Color3.fromRGB(40, 40, 46), Text = "건너뛰기 >", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, skip)
local nextButton = create("TextButton", {
	Name = "Next", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(96, 40),
	BackgroundColor3 = Color3.fromRGB(255, 140, 60), Text = "다음 ▶", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, nextButton)

-- the ring round the top bar button being explained (it pulses)
local ring = create("Frame", { Name = "Ring", BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
local ringStroke = create("UIStroke", { Color = Color3.fromRGB(255, 200, 60), Thickness = 4 }, ring)
local ringTarget: GuiObject? = nil
game:GetService("RunService").RenderStepped:Connect(function()
	local target = ringTarget
	if not target or not ring.Visible then return end
	-- (AbsolutePosition leaves out the top bar inset even here: add it, D-1138)
	local inset = game:GetService("GuiService"):GetGuiInset()
	local pad = 6 + 3 * math.sin(os.clock() * 6)
	ring.Position = UDim2.fromOffset(target.AbsolutePosition.X - pad, target.AbsolutePosition.Y + inset.Y - pad)
	ring.Size = UDim2.fromOffset(target.AbsoluteSize.X + pad * 2, target.AbsoluteSize.Y + pad * 2)
	ringStroke.Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 6))
end)

local camera = workspace.CurrentCamera
local flight: Tween? = nil
local function flyTo(eye: Vector3, look: Vector3)
	local cf = CFrame.lookAt(eye, look)
	task.spawn(function()
		pcall(function() player:RequestStreamAroundAsync(look, 2) end)
	end)
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	pcall(function() Sfx.play("whoosh") end)
	if flight then flight:Cancel() end
	flight = TweenService:Create(camera, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = cf })
	;(flight :: Tween):Play()
end
local function cameraBack()
	if flight then flight:Cancel() flight = nil end
	camera = workspace.CurrentCamera
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
local function show()
	local s = STEPS[step]
	title.Text = s.title
	body.Text = s.text
	count.Text = string.format("%d / %d", step, #STEPS)
	nextButton.Text = if step == #STEPS then "시작! ✨" else "다음 ▶"
	if s.eye and s.look then
		flyTo(s.eye, s.look)
	elseif camera.CameraType == Enum.CameraType.Scriptable then
		cameraBack()
	end
	ringTarget = if s.button then TopBar.button(s.button) else nil
	ring.Visible = ringTarget ~= nil and ringTarget.Visible
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

nextButton.Activated:Connect(function()
	if not touring then return end
	if step >= #STEPS then finish() return end
	step += 1
	show()
end)
skip.Activated:Connect(finish)
if UiBus.StartTour then UiBus.StartTour.Event:Connect(start) end

-- first visit: once the server has told which tips were seen
task.spawn(function()
	local waited = 0
	while player:GetAttribute("TipsSeen") == nil and waited < 20 do task.wait(0.5) waited += 0.5 end
	local ok, seen = pcall(function() return HttpService:JSONDecode(player:GetAttribute("TipsSeen") or "[]") end)
	if ok and typeof(seen) == "table" and table.find(seen, TOUR_KEY) then return end
	if not player.Character then player.CharacterAdded:Wait() end
	-- (after the loading screen, ReplicatedFirst OHULoading, and the world around the spawn)
	local t0 = os.clock()
	while playerGui:FindFirstChild("OHULoading") and os.clock() - t0 < 90 do task.wait(0.5) end
	task.wait(1.5)
	start()
end)
