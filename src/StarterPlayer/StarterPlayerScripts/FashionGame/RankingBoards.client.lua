--!strict
-- Ranking boards (D-277): parts tagged "RankBoard" (attribute Board, Face)
-- show the rankings the server sends as the FashionGame attribute
-- "Rankings" (RankingService).
--   clubStrip  the strip above the club LED wall: the supporter ranking
--              scrolls by; a new gift shows "○○님 후원 감사합니다!" for a while
--   today      the corner LED by OH24: "오늘의 큰손" top 3 on a moving gradient
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

local function buildToday(part: BasePart)
	local gui = surface(part, 20)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.Parent = gui
	-- moving colour wave behind the names (the COEX screen look)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 20, 90)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(20, 90, 200)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(200, 40, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 20, 90)),
	})
	gradient.Rotation = 60
	gradient.Parent = bg
	local wide = part:GetAttribute("Wide") == true
	label(bg, { Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, if wide then 0.14 else 0.1),
		Text = "오늘의 큰손", Font = Enum.Font.GothamBlack, TextColor3 = GOLD })
	local crowns = { "👑", "🥈", "🥉" }
	local rows = {}
	for i = 1, 3 do
		local y = (if wide then 0.26 else 0.2) + (i - 1) * (if wide then 0.24 else 0.26)
		rows[i] = label(bg, { Position = UDim2.fromScale(0.06, y), Size = UDim2.fromScale(0.88, if i == 1 then 0.18 else 0.13),
			Text = "", Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamBold })
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = rows[i]
	end
	local t0 = os.clock()
	return {
		gui = gui,
		tick = function()
			local t = os.clock() - t0
			gradient.Offset = Vector2.new(math.sin(t * 0.35) * 0.45, math.cos(t * 0.25) * 0.2)
			gradient.Rotation = 60 + math.sin(t * 0.2) * 25
		end,
		update = function()
			local list = rankings.today or {}
			for i, row in ipairs(rows) do
				local entry = list[i]
				row.Text = if entry then (crowns[i] .. " " .. tostring(entry.name)) else (if i == 1 then "오늘의 첫 큰손은?" else "")
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
	elseif board == "today" then
		entry = buildToday(part)
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
