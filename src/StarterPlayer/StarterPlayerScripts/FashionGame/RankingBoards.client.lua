--!strict
-- Ranking boards (D-277): parts tagged "RankBoard" (attribute Board, Face)
-- show the rankings the server sends as the FashionGame attribute
-- "Rankings" (RankingService).
--   clubStrip  the strip above the club LED wall: the supporter ranking
--              scrolls by; a new gift shows "○○님 후원 감사합니다!" for a while
--   todayBand  the corner screen on the tower over OH24: the latest supporters (avatar, amount, message) run along it (D-294)
--   support / spend / playtime   the three boards in the pocket park: top 10

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubNotify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent

local TITLES = {
	support = "💝 후원 순위",
	spend = "👑 큰손 순위",
	playtime = "⏱ 플레이 시간 순위",
	today = "오늘의 큰손",
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
	if board == "support" then
		return string.format("R$ %d", value)
	elseif board == "playtime" then
		if value >= 60 then return string.format("%d시간 %d분", value // 60, value % 60) end
		return string.format("%d분", value)
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

local function buildList(part: BasePart, board: string)
	local gui = surface(part, 40)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(14, 16, 26)
	bg.Parent = gui
	label(bg, { Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.92, 0.15), Text = TITLES[board] or board, TextColor3 = GOLD })
	-- top 5, big enough to read from the plaza (2026-10-25)
	local rows = {}
	for i = 1, 5 do
		local y = 0.22 + (i - 1) * 0.15
		local rank = label(bg, { Position = UDim2.fromScale(0.04, y), Size = UDim2.fromScale(0.1, 0.12), Text = tostring(i),
			TextColor3 = if i <= 3 then GOLD else Color3.fromRGB(180, 180, 200), TextXAlignment = Enum.TextXAlignment.Left })
		local name = label(bg, { Position = UDim2.fromScale(0.15, y), Size = UDim2.fromScale(0.5, 0.12), Text = "",
			Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
		local value = label(bg, { Position = UDim2.fromScale(0.62, y), Size = UDim2.fromScale(0.34, 0.12), Text = "",
			Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(200, 220, 255), TextXAlignment = Enum.TextXAlignment.Right })
		rows[i] = { rank = rank, name = name, value = value }
	end
	local empty = label(bg, { Position = UDim2.fromScale(0.1, 0.45), Size = UDim2.fromScale(0.8, 0.1), Text = "",
		Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(160, 160, 180) })
	return {
		gui = gui,
		update = function()
			local list = rankings[board] or {}
			for i, row in ipairs(rows) do
				local entry = list[i]
				row.rank.Visible = entry ~= nil
				row.name.Text = if entry then tostring(entry.name) else ""
				row.value.Text = if entry then valueText(board, entry.value) else ""
			end
			empty.Text = if #list == 0 then "아직 순위가 없어요" else ""
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
local WRAP_SPEED = 2.5 -- studs per second
local CARD = 30 -- studs per card (the screen is 56 tall)
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
	local spacing = 1
	local shownKey = ""
	-- the card's content is built the first time it shows on this panel
	local function fill(card: any)
		card.built = true
		local frame, entry, index = card.frame, card.entry, card.index
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
			for i = 1, math.min(5, #list) do table.insert(entries, list[i]) end
			local key = HttpService:JSONEncode(entries)
			if key == shownKey then return end
			shownKey = key
			for _, card in ipairs(cards) do card.frame:Destroy() end
			cards = {}
			local total = bandLength()
			-- as many rounds of the cards as fit with a gap between them
			local copies = math.max(1, math.floor(total / (#entries * CARD * 1.4)))
			spacing = total / (#entries * copies)
			for _ = 1, copies do
				for index, entry in ipairs(entries) do
					local frame = Instance.new("Frame")
					frame.Size = UDim2.new(0, CARD * pps, 1, 0)
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
				return Color3.fromHSV(0.62 + 0.3 * s, 0.75, 0.42 + 0.12 * s)
			end
			wave.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, waveColor(bandStart)),
				ColorSequenceKeypoint.new(0.5, waveColor(bandStart + width / 2)),
				ColorSequenceKeypoint.new(1, waveColor(bandStart + width)),
			})
			for i, card in ipairs(cards) do
				local pos = ((i - 1) * spacing + offset - bandStart) % total
				if pos > total - CARD then pos -= total end
				local visible = pos < width and pos > -CARD
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
			local parts = { "💝 후원 순위" }
			for i, entry in ipairs(rankings.support or {}) do
				table.insert(parts, string.format("%d위 %s %s", i, tostring(entry.name), valueText("support", entry.value)))
			end
			if #parts == 1 then table.insert(parts, "첫 후원을 기다려요 · 상단 💝 버튼") end
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
	if kind == "Banner" and typeof(value) == "table" and value.kind == "support" then
		local message = if typeof(value.message) == "string" and value.message ~= "" then ("  “" .. value.message .. "”") else ""
		stripMessage = string.format("💝 %s님 후원 감사합니다! (R$ %s)%s", tostring(value.name), tostring(value.amount), message)
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
