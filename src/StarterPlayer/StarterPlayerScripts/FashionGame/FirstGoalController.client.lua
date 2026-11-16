--!strict
-- 첫 목표 (D-1523, user 2026-11-16: "첫 목표(예: 옷 갈아입고 클럽 가 보기)를 알려 주는 장치 추가 / 혼자 온
-- 사람의 첫 목표 하나: 처음 들어오면 오후네컷이 바로 보이게 하고, 표지와 안내로 사진 한 장 찍기까지";
-- asked: on the first visit only the goal, the 18-card tour stays on the guide NPC; by day "옷 갈아입고 사진
-- 찍어서 벽에 붙여 보기", by night "클럽에서 춤추기"; a celebration only, no coins).
-- On a player's first visit (neither the tip "goal1" nor the old first-visit tour "tour2" seen) one goal
-- is chosen by the game clock when they arrive:
--   day   ① 👗 change clothes in the catalog  (the 👗 button pulses; done when the body's look changes)
--         ② 📸 take a photo at 오후네컷       (a line to the studio; done when the server marks PhotoSavedAt)
--         ③ 📌 stick it on the photo wall    (a line to the nearest wall; done at WallPostedAt)
--   night ① 🎧 go into OHU CLUB              (a line to the door; done when InClubLocal)
--         ② 💃 dance                         (the ♪ button pulses; done when the body has a DanceKey)
-- One step shows at a time, in a small card under the top bar (✕ hides the goal for good). The
-- character and camera turn to the first place on arrival. At the end: confetti and "첫 목표 완료!".
-- Seen: the tips the server remembers (GuideService "TipSeen" "goal1" and "tour2", so the tour does not
-- start by itself either). Leaving midway keeps it for the next visit.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local GuideConfig = require(Shared:WaitForChild("GuideConfig"))
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local NearButton = require(script.Parent:WaitForChild("NearButton")) -- (D-1539)
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local KEY = "goal1"
local ORANGE = Color3.fromRGB(255, 170, 60)
local PINK = Color3.fromRGB(255, 110, 170)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for k, v in pairs(props) do (instance :: any)[k] = v end
	if parent then instance.Parent = parent end
	return instance
end

local function seenKeys(): {string}
	local ok, keys = pcall(function() return HttpService:JSONDecode(player:GetAttribute("TipsSeen") or "[]") end)
	return if ok and typeof(keys) == "table" then keys else {}
end
-- (Studio only: ReplicatedStorage.FashionGame attribute FirstGoalTest = true shows the goal to an
-- account that has seen it, and nothing is written to the player's saved tips)
local TEST = RunService:IsStudio() and FashionGame:GetAttribute("FirstGoalTest") == true
local function markSeen()
	if TEST then return end
	task.spawn(function()
		pcall(function() remote:InvokeServer("TipSeen", KEY) end)
		pcall(function() remote:InvokeServer("TipSeen", "tour2") end)
	end)
end

---------------------------------------------------------------- what counts as done
local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
-- the body's look as one string: accessories, clothes, face, body meshes, skin colours
local function lookOf(character: Model?): string
	if not character then return "" end
	local bits = {}
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Accessory") then
			local h = c:FindFirstChild("Handle")
			local id = if h and h:IsA("MeshPart") then h.MeshId .. h.TextureID else c.Name
			table.insert(bits, "A" .. id)
		elseif c:IsA("Shirt") then
			table.insert(bits, "S" .. c.ShirtTemplate)
		elseif c:IsA("Pants") then
			table.insert(bits, "P" .. c.PantsTemplate)
		elseif c:IsA("ShirtGraphic") then
			table.insert(bits, "T" .. c.Graphic)
		elseif c:IsA("BodyColors") then
			table.insert(bits, "C" .. tostring(c.TorsoColor3) .. tostring(c.HeadColor3))
		elseif c:IsA("MeshPart") then
			table.insert(bits, "M" .. c.Name .. c.MeshId)
		end
	end
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChild("face")
	if face and face:IsA("Decal") then table.insert(bits, "F" .. face.Texture) end
	table.sort(bits)
	return table.concat(bits, "|")
end
local function nearestWall(): Vector3?
	local r = root()
	local best, bestD = nil, math.huge
	for _, w in ipairs(CollectionService:GetTagged("PhotoWall")) do
		if w:IsA("BasePart") and w:IsDescendantOf(workspace) then
			local d = if r then (w.Position - r.Position).Magnitude else 0
			if d < bestD then best, bestD = w.Position, d end
		end
	end
	return best
end

type Step = { icon: string, title: string, text: string, place: (() -> Vector3?)?, placeName: string?, button: number?, done: () -> boolean }
local baseLook = ""
local photoAt = player:GetAttribute("PhotoSavedAt")
local wallAt = player:GetAttribute("WallPostedAt")
local DAY: {Step} = {
	{ icon = "👗", title = "옷 갈아입기", text = "위의 👗 카탈로그를 눌러 무료 옷으로 갈아입어 보세요!", button = 4,
		done = function() return baseLook ~= "" and lookOf(player.Character) ~= baseLook end },
	{ icon = "📸", title = "오후네컷에서 사진 찍기", text = "빛나는 길을 따라 오후네컷에 가서 사진 한 장 찍어 보세요!",
		place = function() return GuideConfig.Places.photo.at end, placeName = "오후네컷",
		done = function() return player:GetAttribute("PhotoSavedAt") ~= photoAt end },
	{ icon = "📌", title = "사진 벽에 붙이기", text = "사진을 손에 들고(아래 칸 · 🎒 가방) 오후네컷 벽을 눌러 붙여 보세요!",
		place = nearestWall, placeName = "포토월",
		done = function() return player:GetAttribute("WallPostedAt") ~= wallAt end },
}
local NIGHT: {Step} = {
	{ icon = "🎧", title = "클럽 들어가기", text = "밤에만 여는 OHU CLUB! 빛나는 길을 따라 들어가 보세요.",
		place = function() return GuideConfig.Places.club.at end, placeName = "OHU CLUB",
		done = function() return player:GetAttribute("InClubLocal") == true end },
	{ icon = "💃", title = "춤추기", text = "위의 ♪ 버튼에서 춤을 골라 다 같이 춰 보세요!", button = 1,
		done = function()
			local c = player.Character
			return c ~= nil and c:GetAttribute("DanceKey") ~= nil
		end },
}

---------------------------------------------------------------- the card, the line, the ring
local gui = create("ScreenGui", { Name = "FirstGoalGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false }, playerGui)
local card = create("Frame", {
	Position = UDim2.fromOffset(12, 80), Size = UDim2.fromOffset(280, 92), BackgroundColor3 = Color3.fromRGB(255, 248, 238),
	BackgroundTransparency = 0.04,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
local stroke = create("UIStroke", { Color = ORANGE, Thickness = 3 }, card)
local head = create("TextLabel", {
	Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -50, 0, 22), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = Color3.fromRGB(220, 110, 20), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🎯 첫 목표",
}, card)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 24), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.fromRGB(60, 40, 40), TextXAlignment = Enum.TextXAlignment.Left,
	TextScaled = false, Text = "",
}, card)
local body = create("TextLabel", {
	Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -28, 0, 34), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(90, 70, 70), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = Color3.fromRGB(240, 225, 215), Text = "X", Font = Enum.Font.GothamBlack, TextSize = 14,
	TextColor3 = Color3.fromRGB(120, 90, 80), AutoButtonColor = true,
}, card)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, close)
-- (D-1539) a goal that asks to press a top bar button (👗, ♪): the card right under that button
-- with a pointer up to it (Heartbeat below); other goals: at the left under the bar as before
local pointer = NearButton.pointer(card)
local function placeCard()
	card.AnchorPoint = Vector2.zero
	card.Position = UDim2.fromOffset(12, TopBar.bottom() + 8)
	pointer.Visible = false
end
placeCard()
TopBar.BottomChanged:Connect(placeCard)

local ring = create("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 50 }, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
local ringStroke = create("UIStroke", { Color = Color3.fromRGB(255, 220, 60), Thickness = 4 }, ring)

local marker: BasePart? = nil
local from: Attachment? = nil
local sign: BillboardGui? = nil
local signLabel: TextLabel? = nil
local function clearLine()
	if marker then marker:Destroy() end -- (the sign goes with it)
	if from then from:Destroy() end
	marker, from, sign, signLabel = nil, nil, nil, nil
end
local function lineTo(at: Vector3, name: string)
	clearLine()
	local r = root()
	if not r then return end
	local part = create("Part", {
		Name = "FirstGoalMarker", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.one, Position = at + Vector3.new(0, 2, 0),
	}, workspace)
	local to = create("Attachment", {}, part)
	local a = create("Attachment", { Name = "FirstGoalFrom", Position = Vector3.new(0, -2, 0) }, r)
	create("Beam", {
		Attachment0 = a, Attachment1 = to, FaceCamera = true, Width0 = 1.1, Width1 = 1.1,
		Color = ColorSequence.new(ORANGE), LightEmission = 1, Transparency = NumberSequence.new(0.15), Segments = 24,
	}, part)
	local b = create("BillboardGui", {
		Name = "FirstGoalSign", Adornee = part, Size = UDim2.fromOffset(170, 44), StudsOffset = Vector3.new(0, 5, 0),
		AlwaysOnTop = true, LightInfluence = 0,
	}, part) -- (no taps needed: on the marker itself, D-1523)
	local l = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = ORANGE, BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(0, 0, 0), Text = name,
	}, b)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, l)
	marker, from, sign, signLabel = part, a, b, l
end

---------------------------------------------------------------- confetti
local function celebrate(goalText: string)
	Sfx.play("success", 0.6)
	local g = create("ScreenGui", { Name = "FirstGoalDone", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60 }, playerGui)
	local banner = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 248, 238), Font = Enum.Font.GothamBlack, TextSize = 26,
		TextColor3 = Color3.fromRGB(220, 90, 40), Text = "🎉 첫 목표 완료!\n" .. goalText, TextWrapped = true,
	}, g)
	create("UICorner", { CornerRadius = UDim.new(0, 22) }, banner)
	create("UIStroke", { Color = PINK, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, banner)
	TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(330, 120) }):Play()
	local colors = { PINK, ORANGE, Color3.fromRGB(80, 200, 255), Color3.fromRGB(140, 230, 120), Color3.fromRGB(255, 230, 80) }
	local rng = Random.new()
	for i = 1, 60 do
		local p = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.1, 0.9), -0.05),
			Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(12, 20)), Rotation = rng:NextNumber(0, 360),
			BackgroundColor3 = colors[(i % #colors) + 1], BorderSizePixel = 0,
		}, g)
		TweenService:Create(p, TweenInfo.new(rng:NextNumber(1.6, 2.8), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(p.Position.X.Scale + rng:NextNumber(-0.15, 0.15), 1.1), Rotation = p.Rotation + rng:NextNumber(-540, 540),
		}):Play()
	end
	task.delay(3.4, function() g:Destroy() end)
end

---------------------------------------------------------------- the run
local steps: {Step} = DAY
local goalText = "옷 갈아입고 사진 찍어 벽에 붙이기"
local index = 0
local running = false
local function finish(done: boolean)
	if not running then return end
	running = false
	gui.Enabled = false
	ring.Visible = false
	clearLine()
	markSeen()
	if done then celebrate(goalText) end
end
local function showStep()
	local s = steps[index]
	head.Text = string.format("🎯 첫 목표 · %d / %d", index, #steps)
	title.Text = s.icon .. " " .. s.title
	body.Text = s.text
	clearLine()
	if s.place then
		local at = s.place()
		if at then lineTo(at, s.icon .. " " .. (s.placeName or s.title)) end
	end
	card.Size = UDim2.fromOffset(280, 92)
	TweenService:Create(stroke, TweenInfo.new(0.25), { Thickness = 6 }):Play()
	task.delay(0.3, function() TweenService:Create(stroke, TweenInfo.new(0.4), { Thickness = 3 }):Play() end)
end
close.Activated:Connect(function() finish(false) end)

RunService.Heartbeat:Connect(function()
	if not running then return end
	local s = steps[index]
	if not s then return end
	-- the pulsing ring round a top bar button
	local b = if s.button then TopBar.button(s.button) else nil
	if b and b.Visible then
		NearButton.place(card, pointer, b, 280) -- (D-1539)
		ring.Visible = true
		local pad = 6
		-- (AbsolutePosition leaves out the top-bar inset even here, D-1138)
		local inset = game:GetService("GuiService"):GetGuiInset()
		ring.Position = UDim2.fromOffset(b.AbsolutePosition.X - pad, b.AbsolutePosition.Y + inset.Y - pad)
		ring.Size = UDim2.fromOffset(b.AbsoluteSize.X + pad * 2, b.AbsoluteSize.Y + pad * 2)
		ringStroke.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 6)
	else
		if ring.Visible then placeCard() end -- (D-1539: back to the left)
		ring.Visible = false
	end
	-- the line: from the new body after a respawn, the distance on the sign, hidden when there
	local r = root()
	if from and r and from.Parent ~= r then from.Parent = r end
	if marker and signLabel and r then
		local d = (Vector3.new(r.Position.X, marker.Position.Y, r.Position.Z) - marker.Position).Magnitude
		signLabel.Text = string.format("%s %s · %dm", s.icon, s.placeName or s.title, math.floor(d + 0.5))
		local near = d < 12
		local beam = marker:FindFirstChildOfClass("Beam")
		if beam then beam.Enabled = not near end
		if sign then sign.Enabled = not near end
	end
	if s.done() then
		Sfx.play("success", 0.4)
		if index >= #steps then
			finish(true)
		else
			index += 1
			showStep()
		end
	end
end)

local function start()
	if running then return end
	local night = ClubConfig.isNightOpen(DayNightConfig.clockNow())
	steps = if night then NIGHT else DAY
	goalText = if night then "클럽에서 춤추기" else "옷 갈아입고 사진 찍어 벽에 붙이기"
	baseLook = lookOf(player.Character)
	photoAt = player:GetAttribute("PhotoSavedAt")
	wallAt = player:GetAttribute("WallPostedAt")
	index = 1
	running = true
	gui.Enabled = true
	showStep()
	-- the body and the camera turn to the first place (오후네컷 by day, the club by night)
	local r = root()
	local at = (if night then GuideConfig.Places.club.at else GuideConfig.Places.photo.at)
	if r then
		local flat = Vector3.new(at.X, r.Position.Y, at.Z)
		if (flat - r.Position).Magnitude > 1 then
			r.CFrame = CFrame.lookAt(r.Position, flat)
			local camera = workspace.CurrentCamera
			local dir = (flat - r.Position).Unit
			if camera and camera.CameraType == Enum.CameraType.Custom then
				camera.CFrame = CFrame.lookAt(r.Position - dir * 14 + Vector3.new(0, 6, 0), r.Position + dir * 30 + Vector3.new(0, 4, 0))
			end
		end
	end
end

-- first visit: after the server has told the tips seen and the loading screen is gone
task.spawn(function()
	local waited = 0
	while player:GetAttribute("TipsSeen") == nil and waited < 20 do
		task.wait(0.5)
		waited += 0.5
	end
	local seen = seenKeys()
	if not TEST and (table.find(seen, KEY) or table.find(seen, "tour2")) then return end
	if not player.Character then player.CharacterAdded:Wait() end
	local t0 = os.clock()
	while playerGui:FindFirstChild("OHULoading") and os.clock() - t0 < 90 do task.wait(0.5) end
	task.wait(1.5)
	start()
end)
