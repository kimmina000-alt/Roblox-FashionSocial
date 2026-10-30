--!strict
-- Ranking boards (D-277): parts tagged "RankBoard" (attribute Board, Face)
-- show the rankings the server sends as the FashionGame attribute
-- "Rankings" (RankingService).
--   clubStrip  the strip above the club LED wall: the supporter ranking
--              scrolls by; a new gift shows "○○님 후원 감사합니다!" for a while
--   todayBand  the corner screen on the tower over OH24: the latest supporters (avatar, amount, message) run along it (D-294)
--   support / level   the two boards in the park (user 2026-10-30): 기부 순위표
--              and 레벨 순위표, top 50 each, on a see-through LED pane with a
--              neon edge; the list scrolls by itself (and by hand)

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubNotify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent

local TITLES = {
	support = { "💝", "기부 순위표", "상위 50 플레이어" },
	level = { "⭐", "레벨 순위표", "상위 50 플레이어" },
}
local GOLD = Color3.fromRGB(255, 214, 110)
local PINK = Color3.fromRGB(255, 110, 180)

local rankings: any = {}
local boards: {[BasePart]: any} = {}
local stripMessage: string? = nil
local stripMessageUntil = 0

local function readRankings()
	local raw = FashionGame:GetAttribute("Rankings")
	if typeof(raw) ~= "string" then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and typeof(data) == "table" then rankings = data end
end

local function valueText(board: string, value: any): string
	if typeof(value) ~= "number" then return "" end
	-- 1234567 → "1,234,567"
	local digits = tostring(math.floor(value))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then grouped = string.sub(grouped, 2) end
	if board == "support" then
		return "R$ " .. grouped
	elseif board == "level" then
		return grouped .. " XP"
	end
	return ""
end

local function label(parent: Instance, props: {[string]: any}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end

local function surface(part: BasePart, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RankBoardGui"
	gui.Face = (Enum.NormalId :: any)[part:GetAttribute("Face") or "Front"]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Adornee = part
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

--------------------------------------------------
-- Board kinds
--------------------------------------------------

-- The park boards (user 2026-10-30, after another game's boards): a dark
-- see-through LED pane with a neon pink edge, icon + title + "상위 50
-- 플레이어", then the rows (rank, avatar, name, value; 1-3 gold / silver /
-- bronze). The list scrolls slowly by itself and stops a while when someone
-- drags it. The 기부 board has the 기부하기 buttons on its right.
local NEON = Color3.fromRGB(255, 70, 110)
local MEDALS = { Color3.fromRGB(255, 214, 90), Color3.fromRGB(225, 225, 235), Color3.fromRGB(240, 140, 70) }
local ROW_H = 46
local SCROLL_SPEED = 22 -- px a second
local MessagePromptLazy: any = nil
local thumbs: {[number]: string} = {}

local function headshot(userId: number, image: ImageLabel)
	if thumbs[userId] then image.Image = thumbs[userId] return end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and typeof(url) == "string" then
			thumbs[userId] = url
			image.Image = url
		end
	end)
end

local function buildList(part: BasePart, board: string)
	local gui = surface(part, 40)
	gui.Brightness = 1.4
	local donate = board == "support"
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	-- (user 2026-10-30, 2nd) a plain square, more see-through, no inner rounded
	-- line (the neon edge is the pane's own), titles as text only
	bg.BackgroundColor3 = Color3.fromRGB(10, 6, 16)
	bg.BackgroundTransparency = 0.68 -- (more see-through again, user 2026-10-30)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local title = TITLES[board] or { "", board, "" }
	label(bg, { Position = UDim2.fromOffset(30, 20), Size = UDim2.new(0.6, -30, 0, 34), Text = title[2], TextXAlignment = Enum.TextXAlignment.Left })
	label(bg, { Position = UDim2.fromOffset(30, 54), Size = UDim2.new(0.6, -30, 0, 20), Text = title[3], Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 190, 215), TextXAlignment = Enum.TextXAlignment.Left })
	local listWidth = if donate then 0.66 else 1
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(28, 88)
	scroll.Size = UDim2.new(listWidth, -48, 1, -112)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = NEON
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = bg
	local rows = {}
	for i = 1, 50 do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(0, (i - 1) * ROW_H)
		row.Size = UDim2.new(1, -14, 0, ROW_H - 4)
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.BackgroundTransparency = if i % 2 == 1 then 0.94 else 1
		row.Visible = false
		row.Parent = scroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local medal = MEDALS[i]
		local rank = label(row, { Position = UDim2.fromOffset(4, 6), Size = UDim2.fromOffset(40, 30), Text = tostring(i),
			TextColor3 = medal or Color3.fromRGB(190, 190, 210) })
		local face = Instance.new("ImageLabel")
		face.Position = UDim2.fromOffset(50, 3)
		face.Size = UDim2.fromOffset(36, 36)
		face.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
		face.Parent = row
		Instance.new("UICorner", face).CornerRadius = UDim.new(1, 0)
		if medal then
			local s = Instance.new("UIStroke") s.Color = medal s.Thickness = 2 s.Parent = face
		end
		local name = label(row, { Position = UDim2.fromOffset(96, 6), Size = UDim2.new(0.58, -96, 0, 30), Text = "",
			Font = Enum.Font.GothamMedium, TextColor3 = medal or Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left })
		local value = label(row, { Position = UDim2.new(0.58, 0, 0, 6), Size = UDim2.new(0.42, -10, 0, 30), Text = "",
			TextColor3 = medal or Color3.fromRGB(235, 235, 245), TextXAlignment = Enum.TextXAlignment.Right })
		rows[i] = { frame = row, rank = rank, face = face, name = name, value = value, user = 0 }
	end
	local empty = label(bg, { Position = UDim2.new(0, 28, 0.5, -16), Size = UDim2.new(listWidth, -48, 0, 32), Text = "",
		Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(190, 180, 205) })
	if donate then
		-- 기부하기: the same products as the top bar 💝 window
		local side = Instance.new("Frame")
		side.Position = UDim2.new(0.66, 0, 0, 22)
		side.Size = UDim2.new(0.34, -30, 1, -46)
		side.BackgroundTransparency = 1
		side.Parent = bg
		label(side, { Size = UDim2.new(1, 0, 0, 34), Text = "기부하기" })
		label(side, { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 20), Text = "어떤 금액이든 감사드립니다",
			Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(200, 190, 215) })
		local keys = { "Support_10", "Support_50", "Support_100", "Support_500", "Support_1000", "Support_5000" }
		local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
		for i, key in ipairs(keys) do
			local product = MonetizationConfig.Products[key]
			local b = Instance.new("TextButton")
			-- (44 apart, 36 tall: the last one ended under the note at the bottom, user 2026-10-30)
			b.Position = UDim2.new(0.06, 0, 0, 64 + (i - 1) * 44)
			b.Size = UDim2.new(0.88, 0, 0, 36)
			-- (black and white, user 2026-10-30: was pink)
			b.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
			b.Text = "R$ " .. valueText("level", product.price):gsub(" XP", "")
			b.TextColor3 = Color3.new(1, 1, 1)
			local edge = Instance.new("UIStroke")
			edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			edge.Color = Color3.new(1, 1, 1)
			edge.Thickness = 2
			edge.Parent = b
			b.TextScaled = true
			b.Font = Enum.Font.GothamBlack
			b.Parent = side
			Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
			Instance.new("UIPadding", b).PaddingTop = UDim.new(0, 6)
			b.MouseButton1Click:Connect(function()
				MessagePromptLazy = MessagePromptLazy or require(script.Parent:WaitForChild("MessagePrompt"))
				MessagePromptLazy.buy(key, string.format("💝 %d R$ 기부", product.price))
			end)
		end
		label(side, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 36), TextWrapped = true,
			Text = "기부금은 새로운 공간과 기능을 만드는 데 쓰여요!", Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(200, 190, 215) })
	end
	-- scrolling by itself; a touch / drag pauses it for 6 s
	local holdUntil = 0
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if not scroll:GetAttribute("Auto") then holdUntil = os.clock() + 6 end
	end)
	local pos, last, pauseUntil = 0, os.clock(), os.clock() + 3
	return {
		gui = gui,
		update = function()
			local list = rankings[board] or {}
			for i, row in ipairs(rows) do
				local entry = list[i]
				row.frame.Visible = entry ~= nil
				if entry then
					row.name.Text = tostring(entry.name)
					row.value.Text = valueText(board, entry.value)
					local u = tonumber(entry.u) or 0
					if u ~= row.user then
						row.user = u
						row.face.Image = ""
						if u > 0 then headshot(u, row.face) end
					end
				end
			end
			scroll.CanvasSize = UDim2.fromOffset(0, #list * ROW_H)
			empty.Text = if #list == 0 then "아직 순위가 없어요" else ""
		end,
		tick = function()
			local now = os.clock()
			local dt = math.min(now - last, 0.5)
			last = now
			if now < holdUntil then pos = scroll.CanvasPosition.Y return end
			local room = scroll.CanvasSize.Y.Offset - scroll.AbsoluteWindowSize.Y
			if room <= 0 or now < pauseUntil then return end
			pos += dt * SCROLL_SPEED
			if pos >= room then
				pos = room
				pauseUntil = now + 3
				task.delay(3, function() pos = 0 pauseUntil = os.clock() + 3 end)
			end
			scroll:SetAttribute("Auto", true)
			scroll.CanvasPosition = Vector2.new(0, pos)
			scroll:SetAttribute("Auto", nil)
		end,
	}
end

-- "오늘의 큰손" block on the OH24 roof (D-280): its four sides are one band
-- running round the block; the cards (title + today's top 3 avatars) move
-- along it without end, like the club LED pillars. Each side shows its piece
-- of the band; a card crossing a corner is split over two sides.
local PhotoRender = require(script.Parent:WaitForChild("PhotoRender"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local ClubShop = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction

-- Vote window for the "오늘의 큰손" cards: one row per card, 👍 / 👎 toggles.
local voteGui = Instance.new("ScreenGui")
voteGui.Name = "FashionTodayVoteGui"
voteGui.ResetOnSpawn = false
voteGui.IgnoreGuiInset = true
voteGui.DisplayOrder = 32
voteGui.Parent = player:WaitForChild("PlayerGui")
local voteWindow = Instance.new("Frame")
voteWindow.AnchorPoint = Vector2.new(0.5, 0)
voteWindow.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
voteWindow.Visible = false
voteWindow.Parent = voteGui
Instance.new("UICorner", voteWindow).CornerRadius = UDim.new(0, 16)

local function voteButton(parent: Instance, props: {[string]: any}, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
	for k, v in pairs(props) do (b :: any)[k] = v end
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	Instance.new("UITextSizeConstraint", b).MaxTextSize = 15
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function StarterGuiNotify(text: string)
	game:GetService("StarterGui"):SetCore("SendNotification", { Title = "실시간 후원", Text = text, Duration = 3 })
end

local function openVoteWindow()
	for _, child in ipairs(voteWindow:GetChildren()) do
		if not child:IsA("UICorner") then child:Destroy() end
	end
	local list = rankings.recent or {}
	local rows = math.min(4, #list)
	local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1000, 700)
	voteWindow.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
	voteWindow.Size = UDim2.fromOffset(math.min(340, vp.X - 24), 96 + math.max(rows, 1) * 46)
	voteWindow.Visible = true
	Popups.opened("TodayVote", function() voteWindow.Visible = false end)
	label(voteWindow, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -60, 0, 24), Text = "💝 실시간 후원",
		TextXAlignment = Enum.TextXAlignment.Left })
	label(voteWindow, { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 32), TextWrapped = true,
		Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(190, 190, 205), TextXAlignment = Enum.TextXAlignment.Left,
		Text = "싫어요가 5개 이상이고 좋아요보다 많으면 아바타 대신 이름만 보여요." })
	voteButton(voteWindow, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(30, 30), Text = "X" },
		function() voteWindow.Visible = false Popups.closed("TodayVote") end)
	if rows == 0 then
		label(voteWindow, { Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 24), Font = Enum.Font.GothamMedium,
			Text = "아직 후원이 없어요 · 상단 💝 버튼" })
		return
	end
	for i = 1, rows do
		local entry = list[i]
		local y = 76 + (i - 1) * 46
		label(voteWindow, { Position = UDim2.fromOffset(16, y + 6), Size = UDim2.new(0.5, -16, 0, 26), Text = string.format("%s · R$ %s", tostring(entry.name), tostring(entry.amount)),
			TextXAlignment = Enum.TextXAlignment.Left })
		local mine: string? = nil
		local like, dislike
		local function paint(likes: number, dislikes: number)
			like.Text = string.format("👍 %d", likes)
			dislike.Text = string.format("👎 %d", dislikes)
			like.BackgroundColor3 = if mine == "like" then Color3.fromRGB(0, 150, 255) else Color3.fromRGB(38, 38, 50)
			dislike.BackgroundColor3 = if mine == "dislike" then Color3.fromRGB(220, 60, 60) else Color3.fromRGB(38, 38, 50)
		end
		local function vote(value: string)
			local ok, result = ClubShop:InvokeServer("Vote", { kind = "supporter", id = tostring(entry.u), value = if mine == value then nil else value })
			if ok and typeof(result) == "table" then
				mine = result.mine
				paint(result.likes, result.dislikes)
			elseif typeof(result) == "string" then
				StarterGuiNotify(result)
			end
		end
		like = voteButton(voteWindow, { Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.new(0.25, -8, 0, 36) }, function() vote("like") end)
		dislike = voteButton(voteWindow, { Position = UDim2.new(0.75, -4, 0, y), Size = UDim2.new(0.25, -12, 0, 36) }, function() vote("dislike") end)
		paint(entry.likes or 0, entry.dislikes or 0)
		task.spawn(function()
			local ok, current = ClubShop:InvokeServer("VoteMine", { kind = "supporter", user = entry.u })
			if ok then mine = current paint(entry.likes or 0, entry.dislikes or 0) end
		end)
	end
end
-- (user 2026-10-30) the corner screen before anyone has given: OHU ads
local PROMOS: {any} = {
	{ promo = true, icon = "🧡", big = "OHU", sub = "오후 · 홍대 패션 소셜", color = Color3.fromRGB(255, 140, 60) },
	{ promo = true, icon = "🎧", big = "OHU CLUB", sub = "오늘 밤 라이브 DJ", color = Color3.fromRGB(200, 80, 255) },
	{ promo = true, icon = "📸", big = "오후네컷", sub = "친구와 네 컷 찍기", color = Color3.fromRGB(255, 90, 170) },
	{ promo = true, icon = "🏖", big = "BEACH CAFE", sub = "바다 보며 쉬어 가요", color = Color3.fromRGB(60, 200, 255) },
	{ promo = true, icon = "👗", big = "TODAY'S LOOK", sub = "C 카탈로그로 코디 바꾸기", color = Color3.fromRGB(255, 220, 90) },
	{ promo = true, icon = "💝", big = "실시간 후원", sub = "상단 💝 버튼", color = Color3.fromRGB(255, 70, 110) },
}
-- a stage cold spark showing on the corner screen (ClubNotify "Banner")
local spark: any = nil
local SPARK_SHOW = 30 -- (as long as the show, SparkleService COLD_SPARK_SECONDS)

local WRAP_SPEED = 2.5 -- studs per second
local CARD = 30 -- studs per card (the screen is 56 tall)
local SPARK_CARD = 96 -- a cold spark card: wide, fireworks over the message (user 2026-10-30)
local FIREWORK = "rbxassetid://111289615885616" -- the user's pink firework on a clear ground (docs/04_ART/textures/firework_pink.png)
local AVATAR_BACK = { 40, 26, 70 }
local AVATAR_CAM = { CFrame.lookAt(Vector3.new(0, -1.9, -8), Vector3.new(0, -2.6, 0)):GetComponents() }

-- The corner screen on the tower over OH24 (D-282): its panels (tag RankBoard,
-- Board "todayBand", attribute BandStart) together make one band: east side →
-- round corner → north side. The cards (title + today's top 3 avatars) run
-- along it from left to right and start again; a card crossing a seam shows
-- on both panels. All panels follow the same clock, so they stay in step.
local function bandLength(): number
	local total = 0
	for _, p in ipairs(CollectionService:GetTagged("RankBoard")) do
		if p:IsA("BasePart") and p:GetAttribute("Board") == "todayBand" and p:IsDescendantOf(workspace) then
			total = math.max(total, (p:GetAttribute("BandStart") or 0) + p.Size.X)
		end
	end
	return math.max(total, 1)
end

local function buildBandPanel(part: BasePart)
	local pps = 12
	local width = part.Size.X
	local bandStart = part:GetAttribute("BandStart") or 0
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TodayBandGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.Adornee = part
	gui.Parent = player:WaitForChild("PlayerGui")
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.ClipsDescendants = true
	bg.Parent = gui
	-- a colour wave flowing along the whole band (continuous over the seams)
	local wave = Instance.new("UIGradient")
	wave.Parent = bg
	-- tap the screen: 좋아요 / 싫어요 for the supporter cards (D-281)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 400
	click.Parent = part
	click.MouseClick:Connect(function() openVoteWindow() end)

	local cards: {{ frame: Frame, entry: any, index: number, built: boolean }} = {}
	local dark = false
	local cardW = CARD
	local spacing = 1
	local shownKey = ""
	-- the card's content is built the first time it shows on this panel
	local function neonText(frame: Instance, props: {[string]: any}, glowColor: Color3)
		local glowLabel = label(frame, props)
		glowLabel.TextTransparency = 0.4
		local s = Instance.new("UIStroke") s.Color = glowColor s.Thickness = 5 s.Transparency = 0.5 s.Parent = glowLabel
		local core = label(frame, props)
		local c = Instance.new("UIStroke") c.Color = glowColor:Lerp(Color3.new(1, 1, 1), 0.4) c.Thickness = 1.5 c.Parent = core
		return core
	end
	local function fill(card: any)
		card.built = true
		local frame, entry, index = card.frame, card.entry, card.index
		if typeof(entry) == "table" and entry.promo then
			-- (user 2026-10-30) nobody has given yet: OHU ads on a dark screen
			label(frame, { Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.22), Text = entry.icon })
			neonText(frame, { Position = UDim2.fromScale(0.04, 0.45), Size = UDim2.fromScale(0.92, 0.16), Text = entry.big, Font = Enum.Font.GothamBlack }, entry.color)
			label(frame, { Position = UDim2.fromScale(0.06, 0.64), Size = UDim2.fromScale(0.88, 0.08), Text = entry.sub, Font = Enum.Font.GothamMedium,
				TextColor3 = Color3.fromRGB(225, 225, 235) })
			return
		end
		if typeof(entry) == "table" and entry.spark then
			-- a stage cold spark (user 2026-10-30, their mock-up): fireworks burst
			-- over the card, then the message rises into place in white with a
			-- red glow, the @id under it; again every few seconds
			local bursts = {}
			for k, spot in ipairs({ { 0.5, 0.3, 0.42 }, { 0.2, 0.22, 0.26 }, { 0.8, 0.24, 0.3 } }) do
				local img = Instance.new("ImageLabel")
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(spot[1], spot[2])
				img.Size = UDim2.fromScale(0, 0)
				img.SizeConstraint = Enum.SizeConstraint.RelativeYY
				img.BackgroundTransparency = 1
				img.Image = FIREWORK
				img.ImageColor3 = if k == 1 then Color3.new(1, 1, 1) elseif k == 2 then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(150, 220, 255)
				img.Parent = frame
				bursts[k] = { img = img, size = spot[3], delay = (k - 1) * 0.35 }
			end
			local main = if entry.message ~= "" then ("“" .. entry.message .. "”")
				else string.format(if entry.dj then "DJ %s님의 불꽃 쇼!" else "%s님의 콜드 스파크!", tostring(entry.name))
			local textBox = Instance.new("Frame")
			textBox.BackgroundTransparency = 1
			textBox.Size = UDim2.fromScale(1, 0.34)
			textBox.Position = UDim2.fromScale(0, 0.56)
			textBox.Parent = frame
			neonText(textBox, { Position = UDim2.fromScale(0.03, 0), Size = UDim2.fromScale(0.94, 0.55), Text = main, Font = Enum.Font.GothamBlack },
				Color3.fromRGB(255, 40, 60))
			label(textBox, { Position = UDim2.fromScale(0.1, 0.66), Size = UDim2.fromScale(0.8, 0.28), Text = "@" .. tostring(entry.user),
				Font = Enum.Font.GothamBold })
			task.spawn(function()
				while frame.Parent do
					local t0 = os.clock()
					while frame.Parent and os.clock() - t0 < 4.5 do
						local t = os.clock() - t0
						for _, b in ipairs(bursts) do
							local k = math.clamp((t - b.delay) / 0.7, 0, 1)
							local grow = 1 - (1 - k) ^ 3
							b.img.Size = UDim2.fromScale(b.size * 2 * grow, b.size * 2 * grow)
							b.img.ImageTransparency = math.clamp((t - b.delay - 0.9) / 1.4, 0, 1)
						end
						-- the text rises up as the first burst opens
						local r = math.clamp((t - 0.3) / 0.6, 0, 1)
						textBox.Position = UDim2.fromScale(0, 0.56 + 0.12 * (1 - r) ^ 2)
						task.wait(0.03)
					end
				end
			end)
			return
		end
		if entry == "title" then
			label(frame, { Position = UDim2.fromScale(0.05, 0.28), Size = UDim2.fromScale(0.9, 0.2), Text = "💝 실시간",
				Font = Enum.Font.GothamBlack, TextColor3 = GOLD })
			label(frame, { Position = UDim2.fromScale(0.05, 0.5), Size = UDim2.fromScale(0.9, 0.24), Text = "후원",
				Font = Enum.Font.GothamBlack, TextColor3 = GOLD })
			return
		end
		local viewport = Instance.new("ViewportFrame")
		viewport.Position = UDim2.fromScale(0.04, 0.04)
		viewport.Size = UDim2.fromScale(0.92, 0.74)
		viewport.BackgroundColor3 = Color3.fromRGB(AVATAR_BACK[1], AVATAR_BACK[2], AVATAR_BACK[3])
		viewport.BackgroundTransparency = 0.3
		viewport.Parent = frame
		label(frame, { Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.5, 0.09), Text = "💝 R$ " .. tostring(entry.amount),
			TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
		label(frame, { Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromScale(0.46, 0.08),
			Text = string.format("👍%d 👎%d", entry.likes or 0, entry.dislikes or 0), Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Right })
		label(frame, { Position = UDim2.fromScale(0.04, 0.79), Size = UDim2.fromScale(0.92, 0.11), Text = tostring(entry.name),
			Font = Enum.Font.GothamBlack })
		-- their message (filtered on the server)
		if typeof(entry.message) == "string" and entry.message ~= "" then
			label(frame, { Position = UDim2.fromScale(0.04, 0.9), Size = UDim2.fromScale(0.92, 0.08), Text = "“" .. entry.message .. "”",
				Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(255, 220, 235) })
		end
		if entry.hidden then
			-- hidden by 싫어요 (D-281): the name only
			viewport.Visible = false
			label(frame, { Position = UDim2.fromScale(0.04, 0.35), Size = UDim2.fromScale(0.92, 0.16), Text = tostring(entry.name),
				Font = Enum.Font.GothamBlack, TextColor3 = GOLD })
			return
		end
		if entry.u and entry.o then
			task.spawn(function()
				PhotoRender.renderShot(viewport, { people = { { u = entry.u, x = 0, y = -2.9, z = 0, r = 0, t = 0 } } },
					{ [entry.u] = { o = entry.o } }, { back = AVATAR_BACK, cam = AVATAR_CAM })
			end)
		end
	end
	return {
		gui = gui,
		update = function()
			local list = rankings.recent or {}
			local entries: {any} = { "title" }
			if spark and os.clock() < spark.untilAt then
				entries = { spark }
			elseif #list == 0 then
				entries = PROMOS
			else
				for i = 1, math.min(5, #list) do table.insert(entries, list[i]) end
			end
			dark = entries ~= nil and entries[1] ~= "title"
			-- (the ads and the spark hold colours / tables JSON cannot encode)
			local key = if entries == PROMOS then "promos"
				elseif entries[1] == spark then "spark" .. tostring(spark.untilAt)
				else HttpService:JSONEncode(entries)
			if key == shownKey then return end
			shownKey = key
			for _, card in ipairs(cards) do card.frame:Destroy() end
			cards = {}
			local total = bandLength()
			-- as many rounds of the cards as fit with a gap between them
			cardW = if dark and entries[1] == spark then SPARK_CARD else CARD
			local copies = math.max(1, math.floor(total / (#entries * cardW * 1.4)))
			spacing = total / (#entries * copies)
			for _ = 1, copies do
				for index, entry in ipairs(entries) do
					local frame = Instance.new("Frame")
					frame.Size = UDim2.new(0, cardW * pps, 1, 0)
					frame.BackgroundTransparency = 1
					frame.Visible = false
					frame.Parent = bg
					table.insert(cards, { frame = frame, entry = entry, index = index - 1, built = false })
				end
			end
		end,
		tick = function()
			local total = bandLength()
			local offset = (os.clock() * WRAP_SPEED) % total
			local function waveColor(x: number): Color3
				local s = 0.5 + 0.5 * math.sin(2 * math.pi * (x / total - os.clock() * 0.05))
				-- (ads and the cold spark on a nearly black screen, so the neon reads)
				return Color3.fromHSV(0.62 + 0.3 * s, 0.75, if dark then 0.06 + 0.05 * s else 0.42 + 0.12 * s)
			end
			wave.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, waveColor(bandStart)),
				ColorSequenceKeypoint.new(0.5, waveColor(bandStart + width / 2)),
				ColorSequenceKeypoint.new(1, waveColor(bandStart + width)),
			})
			for i, card in ipairs(cards) do
				local pos = ((i - 1) * spacing + offset - bandStart) % total
				if pos > total - cardW then pos -= total end
				local visible = pos < width and pos > -cardW
				card.frame.Visible = visible
				if visible then
					if not card.built then fill(card) end
					card.frame.Position = UDim2.fromOffset(math.floor(pos * pps), 0)
				end
			end
		end,
	}
end

local function buildStrip(part: BasePart)
	local gui = surface(part, 30)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	bg.ClipsDescendants = true
	bg.Parent = gui
	local text = label(bg, { AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = 84,
		Size = UDim2.fromScale(0, 1), Position = UDim2.fromScale(1, 0), Text = "", TextColor3 = GOLD })
	local x = 1.0
	local last = 0
	return {
		gui = gui,
		tick = function()
			local now = os.clock()
			local dt = now - last
			last = now
			if dt > 0.5 then return end
			local width = math.max(bg.AbsoluteSize.X, 1)
			x -= dt * 0.12
			if x * width < -text.AbsoluteSize.X then x = 1 end
			text.Position = UDim2.fromScale(x, 0)
			local thanking = stripMessage ~= nil and os.clock() < stripMessageUntil
			text.TextColor3 = if thanking then PINK else GOLD
		end,
		update = function()
			if stripMessage and os.clock() < stripMessageUntil then
				text.Text = stripMessage
				return
			end
			-- (user 2026-10-30) before anyone has given: the club's welcome lines
			local support = rankings.support or {}
			if #support == 0 then
				text.Text = table.concat({
					"✦ WELCOME TO OHU CLUB ✦", "OHU CLUB에 오신 것을 환영합니다", "🎧 TONIGHT · LIVE DJ",
					"MAKE SOME NOISE!", "음악에 몸을 맡기세요", "🎆 무대 콜드 스파크로 오늘 밤을 밝혀 주세요",
				}, "     ·     ")
				return
			end
			local parts = { "💝 기부 순위" }
			for i, entry in ipairs(support) do
				if i > 10 then break end
				table.insert(parts, string.format("%d위 %s %s", i, tostring(entry.name), valueText("support", entry.value)))
			end
			table.insert(parts, "✦ WELCOME TO OHU CLUB ✦")
			text.Text = table.concat(parts, "     ·     ")
		end,
	}
end

--------------------------------------------------

local function add(part: Instance)
	if not part:IsA("BasePart") or boards[part] or not part:IsDescendantOf(workspace) then return end
	local board = part:GetAttribute("Board")
	local entry
	if board == "clubStrip" then
		entry = buildStrip(part)
	elseif board == "todayBand" then
		entry = buildBandPanel(part)
	elseif typeof(board) == "string" then
		entry = buildList(part, board)
	else
		return
	end
	boards[part] = entry
	entry.update()
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) and boards[part] then
			boards[part].gui:Destroy()
			boards[part] = nil
		end
	end)
end

local function refresh()
	readRankings()
	for _, entry in pairs(boards) do entry.update() end
end

readRankings()
for _, part in ipairs(CollectionService:GetTagged("RankBoard")) do add(part) end
CollectionService:GetInstanceAddedSignal("RankBoard"):Connect(add)
FashionGame:GetAttributeChangedSignal("Rankings"):Connect(refresh)

-- a new gift: the club strip says thank you for 12 s
ClubNotify.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "Banner" and typeof(value) == "table" and (value.kind == "coldspark" or value.kind == "djspark") then
		-- the buyer's name and message on the corner screen of the tower (user 2026-10-30)
		local token = {}
		spark = { spark = true, dj = value.kind == "djspark", name = tostring(value.name), user = tostring(value.user),
			message = if typeof(value.message) == "string" then value.message else "", untilAt = os.clock() + SPARK_SHOW, token = token }
		refresh()
		task.delay(SPARK_SHOW + 0.2, function()
			if spark and spark.token == token then spark = nil end
			refresh()
		end)
	elseif kind == "Banner" and typeof(value) == "table" and value.kind == "support" then
		local message = if typeof(value.message) == "string" and value.message ~= "" then ("  “" .. value.message .. "”") else ""
		stripMessage = string.format("💝 %s님이 %s R$ 기부하셨습니다%s", tostring(value.name), tostring(value.amount), message)
		stripMessageUntil = os.clock() + 12
		refresh()
		task.delay(12.2, refresh)
	end
end)

RunService.RenderStepped:Connect(function()
	for _, entry in pairs(boards) do
		if entry.tick then entry.tick() end
	end
end)
