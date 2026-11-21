--!strict
-- 안무 따라 하기 점수 "오늘의 곡 도전" (D-1816, DanceScoreConfig, docs/01_SYSTEMS/DANCE_SCORE.md; user
-- 2026-11-21: A 시안 (네온 클럽), 네온 무대에서). Step 1 (one song, NEON):
--   * on the neon stage a "🎵 오늘의 곡 도전" button opens the start window;
--   * 도전 시작 → DanceScoreService "Start": 3 · 2 · 1, then this player hears today's song from its start
--     and dances its choreography (NeonStageController, character attribute DanceChallenge);
--   * notes fall to four buttons: landscape two lanes at each side (one thumb each), portrait four
--     across the bottom; keys D F J K or the arrows. Judged on the song as heard (the stage Sound's
--     TimePosition): Perfect / Great / Miss, combo;
--   * the result: grade S / A / B, score, counts, best combo ("Finish": the server checks it).
-- While playing: no walking (WalkSpeed 0), the phone's stick / jump button and the item hotbar hidden.
-- (D-1817, step 2) today's song by the day (DanceScoreConfig.todaySong), my best / rank today in the windows,
-- the top notice "🎵 오늘의 곡에 도전하세요!" (DanceScoreNotice "Announce", every 15 min, only to who
-- can go now; a tap draws the way to the stage, UiBus.ShowWay "neon"), and the TOP 10 board on the
-- bus stop's back wall (Workspace part tagged DanceTopBoard; FashionGame attribute DanceTop).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local NeonStageConfig = require(Shared:WaitForChild("NeonStageConfig"))
local DanceScoreConfig = require(Shared:WaitForChild("DanceScoreConfig"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("DanceScore", 60) :: RemoteFunction?

-- A 네온 클럽 colours
local BG = Color3.fromRGB(16, 10, 30)
local CARD = Color3.fromRGB(34, 20, 56)
local PINK = Color3.fromRGB(255, 79, 180)
local CYAN = Color3.fromRGB(124, 243, 255)
local YELLOW = Color3.fromRGB(255, 228, 92)
local VIOLET = Color3.fromRGB(167, 139, 250)
local SOFT = Color3.fromRGB(200, 184, 232)
local LANE_COLORS = { PINK, CYAN, YELLOW, VIOLET }
local LANE_ARROWS = { "◀", "▼", "▲", "▶" }
local BIG = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold

local gui = Instance.new("ScreenGui")
gui.Name = "DanceScoreGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 36
gui.Parent = playerGui

local function make(class: string, props: {[string]: any}, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function round(o: Instance, r: number) make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o: Instance, color: Color3, thickness: number)
	make("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?, props: {[string]: any}?): TextLabel
	local l = make("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = font or BODY, Size = UDim2.new(1, 0, 0, size + 6) }, parent)
	for k, v in pairs(props or {}) do (l :: any)[k] = v end
	return l
end
local function button(parent: Instance, text: string, fill: Color3?, textColor: Color3, font: Enum.Font?, size: number?): TextButton
	local b = make("TextButton", { Text = text, TextSize = size or 16, Font = font or BODY, TextColor3 = textColor,
		BackgroundColor3 = fill or BG, BackgroundTransparency = if fill then 0 else 1, AutoButtonColor = true,
		Size = UDim2.new(1, 0, 0, 48) }, parent)
	round(b, 12)
	if not fill then stroke(b, Color3.fromRGB(74, 58, 106), 2) end
	return b
end

local function track(): ClubConfig.Track?
	return NeonStageConfig.trackById(DanceScoreConfig.todaySong())
end
local function onStage(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and NeonStageConfig.onStage(root.Position)
end
local function toast(text: string)
	-- (a plain line over the buttons)
	local l = label(gui, text, 15, Color3.new(1, 1, 1), BODY, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.new(1, -40, 0, 22), TextStrokeTransparency = 0.3, ZIndex = 50 })
	task.delay(2.5, function() l:Destroy() end)
end

--------------------------------------------------------------------------
-- entry button (on the stage, when no window is open)
local entry = button(gui, "🎵 오늘의 곡 도전", PINK, Color3.fromRGB(26, 11, 34), BIG, 18)
entry.Name = "Entry"
entry.AnchorPoint = Vector2.new(1, 0.5)
entry.Position = UDim2.new(1, -16, 0.6, 0)
entry.Size = UDim2.fromOffset(176, 48)
entry.Visible = false

--------------------------------------------------------------------------
-- start window
local startPanel = make("Frame", { Name = "Start", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(420, 300), BackgroundColor3 = BG, BackgroundTransparency = 0.04, Visible = false }, gui)
round(startPanel, 18)
stroke(startPanel, PINK, 2)
make("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18) }, startPanel)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, startPanel)
label(startPanel, "오늘의 곡 도전 · 광장 네온 무대", 13, CYAN, BODY, { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
local startTitle = label(startPanel, "NEON", 34, Color3.new(1, 1, 1), BIG, { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 38) })
local startInfo = label(startPanel, "", 14, Color3.fromRGB(230, 221, 247), BODY, { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left })
local startBest = label(startPanel, "", 13, SOFT, BODY, { LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left })
label(startPanel, "표시가 아래 선에 닿을 때 같은 버튼을 눌러요 (PC: D F J K)", 13, SOFT, BODY,
	{ LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36) })
local startRow = make("Frame", { LayoutOrder = 6, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, startPanel)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, startRow)
local startClose = button(startRow, "닫기", nil, Color3.fromRGB(230, 221, 247))
startClose.Size = UDim2.new(1 / 3, -5, 1, 0)
local startGo = button(startRow, "도전 시작", PINK, Color3.fromRGB(26, 11, 34), BIG, 20)
startGo.Size = UDim2.new(2 / 3, -5, 1, 0)

--------------------------------------------------------------------------
-- play screen
local play = make("Frame", { Name = "Play", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
local songBox = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(230, 40) }, play)
local songLabel = label(songBox, "", 12, CYAN, BODY, { TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5 })
local barBack = make("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(46, 28, 74) }, songBox)
round(barBack, 3)
local barFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN }, barBack)
round(barFill, 3)
local quit = button(play, "✕ 그만하기", BG, SOFT, BODY, 12)
quit.BackgroundTransparency = 0.2
quit.Size = UDim2.fromOffset(96, 30)
local scoreLabel = label(play, "0", 26, Color3.new(1, 1, 1), BIG, { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(200, 30),
	TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.4 })
local judgeLabel = label(play, "", 40, YELLOW, BIG, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(360, 46),
	TextStrokeColor3 = Color3.fromRGB(60, 0, 40), TextStrokeTransparency = 0 })
local judgeScale = make("UIScale", { Scale = 1 }, judgeLabel)
local comboLabel = label(play, "", 24, Color3.new(1, 1, 1), BIG, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(240, 30),
	TextStrokeTransparency = 0.3 })
local countLabel = label(play, "", 90, Color3.new(1, 1, 1), BIG, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(200, 100), TextStrokeColor3 = PINK, TextStrokeTransparency = 0 })

type Lane = { frame: Frame, button: TextButton, flash: Frame }
local lanes: {Lane} = {}
for i = 1, 4 do
	local color = LANE_COLORS[i]
	local frame = make("Frame", { Name = "Lane" .. i, BackgroundColor3 = color, BackgroundTransparency = 0.86, ClipsDescendants = true }, play)
	round(frame, 10)
	stroke(frame, color, 1)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, frame)
	local b = make("TextButton", { Name = "Button" .. i, Text = LANE_ARROWS[i], TextSize = 26, Font = BIG, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color, BackgroundTransparency = 0.7, AutoButtonColor = false }, play)
	round(b, 16)
	stroke(b, color, 3)
	local flash = make("Frame", { BackgroundColor3 = color, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, b)
	round(flash, 16)
	lanes[i] = { frame = frame, button = b, flash = flash }
end

--------------------------------------------------------------------------
-- result window
local result = make("Frame", { Name = "Result", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(440, 330), BackgroundColor3 = BG, BackgroundTransparency = 0.04, Visible = false }, gui)
round(result, 18)
stroke(result, PINK, 2)
make("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16) }, result)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, result)
label(result, "NEON · A2O LITE", 13, CYAN, BODY, { LayoutOrder = 1 })
local gradeLabel = label(result, "S", 76, YELLOW, BIG, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 76), TextStrokeColor3 = PINK, TextStrokeTransparency = 0.2 })
local resultScore = label(result, "0", 28, Color3.new(1, 1, 1), BIG, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 32) })
local resultNote = label(result, "", 13, Color3.fromRGB(255, 138, 208), BODY, { LayoutOrder = 4 })
local counts = make("Frame", { LayoutOrder = 5, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52) }, result)
make("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0) }, counts)
local countValues: {TextLabel} = {}
for i, info in ipairs({ { "PERFECT", YELLOW }, { "GREAT", CYAN }, { "MISS", Color3.new(1, 1, 1) }, { "최대 콤보", Color3.fromRGB(255, 138, 208) } }) do
	local cell = make("Frame", { BackgroundColor3 = CARD, LayoutOrder = i }, counts)
	round(cell, 10)
	label(cell, info[1], 11, SOFT, BODY, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14) })
	countValues[i] = label(cell, "0", 20, info[2], BIG, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 26) })
end
local resultRow = make("Frame", { LayoutOrder = 6, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, result)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, resultRow)
local resultClose = button(resultRow, "닫기", nil, Color3.fromRGB(230, 221, 247))
resultClose.Size = UDim2.new(0.4, -5, 1, 0)
local resultAgain = button(resultRow, "다시 도전", PINK, Color3.fromRGB(26, 11, 34), BIG, 19)
resultAgain.Size = UDim2.new(0.6, -5, 1, 0)

--------------------------------------------------------------------------
-- layout for the screen's shape
local laneTop, laneBottom = 0, 0
local function layout()
	local vp = gui.AbsoluteSize
	local top = TopBar.bottom() + 8
	local wide = vp.X > vp.Y
	local panelW = math.min(420, vp.X - 32)
	startPanel.Size = UDim2.fromOffset(panelW, 300)
	result.Size = UDim2.fromOffset(math.min(440, vp.X - 32), 330)
	songBox.Position = UDim2.fromOffset(16, top)
	songBox.Size = UDim2.fromOffset(math.min(230, vp.X * 0.45), 26)
	quit.Position = UDim2.fromOffset(16, top + 32)
	scoreLabel.Position = UDim2.new(1, -16, 0, top)
	judgeLabel.Position = UDim2.new(0.5, 0, 0, if wide then top + 50 else vp.Y * 0.36)
	comboLabel.Position = UDim2.new(0.5, 0, 0, (if wide then top + 50 else vp.Y * 0.36) + 46)
	if wide then
		-- two lanes at each side, one thumb each
		local w, gap, btnH = 66, 10, 66
		laneTop, laneBottom = top + 70, vp.Y - 16 - btnH - 8 -- (under the song bar and 그만하기)
		for i, lane in ipairs(lanes) do
			local x = if i <= 2 then 16 + (i - 1) * (w + gap) else vp.X - 16 - (2 * w + gap) + (i - 3) * (w + gap)
			lane.frame.Position = UDim2.fromOffset(x, laneTop)
			lane.frame.Size = UDim2.fromOffset(w, laneBottom - laneTop)
			lane.button.Position = UDim2.fromOffset(x, vp.Y - 16 - btnH)
			lane.button.Size = UDim2.fromOffset(w, btnH)
		end
	else
		-- four across the bottom
		local gap, btnH = 8, 76
		local w = math.floor((vp.X - 32 - 3 * gap) / 4)
		laneTop, laneBottom = vp.Y * 0.47, vp.Y - 28 - btnH - 8
		for i, lane in ipairs(lanes) do
			local x = 16 + (i - 1) * (w + gap)
			lane.frame.Position = UDim2.fromOffset(x, laneTop)
			lane.frame.Size = UDim2.fromOffset(w, laneBottom - laneTop)
			lane.button.Position = UDim2.fromOffset(x, vp.Y - 28 - btnH)
			lane.button.Size = UDim2.fromOffset(w, btnH)
		end
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

--------------------------------------------------------------------------
-- a run
type Run = { start: number, track: ClubConfig.Track, notes: {any}, nextSpawn: number, perfect: number, great: number,
	miss: number, combo: number, best: number, rate: number, active: boolean, offStage: number }
local run: Run? = nil
local hidden: {[string]: any} = {}

local function setPlayMode(on: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on then
		hidden.touch = GuiService.TouchControlsEnabled
		GuiService.TouchControlsEnabled = false
		if humanoid then hidden.walk = humanoid.WalkSpeed humanoid.WalkSpeed = 0 end
		for _, name in ipairs({ "FashionHotbar", "NeonStageCamera" }) do
			local g = playerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") and g.Enabled then hidden[name] = g g.Enabled = false end
		end
		ContextActionService:BindActionAtPriority("DanceScoreNoJump", function() return Enum.ContextActionResult.Sink end,
			false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)
	else
		if hidden.touch ~= nil then GuiService.TouchControlsEnabled = hidden.touch end
		if humanoid and hidden.walk then humanoid.WalkSpeed = hidden.walk end
		for _, name in ipairs({ "FashionHotbar", "NeonStageCamera" }) do
			local g = hidden[name]
			if g then g.Enabled = true end
		end
		table.clear(hidden)
		ContextActionService:UnbindAction("DanceScoreNoJump")
	end
end

-- the song time I hear: the stage Sound's position when it plays, else the server clock
local function heardSongTime(r: Run): number
	local stage = script.Parent:FindFirstChild("NeonStageController")
	local sound = stage and stage:FindFirstChild("NeonStageMusic")
	local clock = NeonStageConfig.songTime(r.track, r.start, workspace:GetServerTimeNow())
	if sound and sound:IsA("Sound") and sound.IsPlaying and sound.TimePosition > 0.05 then
		local heard = sound.TimePosition * ClubConfig.fileSpeed(r.track)
		if math.abs(heard - clock) < 1.5 then return heard end
	end
	return clock
end

local judgeTween: Tween? = nil
local function showJudge(kind: string)
	judgeLabel.Text = kind
	judgeLabel.TextColor3 = if kind == "PERFECT" then YELLOW elseif kind == "GREAT" then CYAN else Color3.fromRGB(170, 160, 190)
	judgeScale.Scale = 1.25
	if judgeTween then judgeTween:Cancel() end
	judgeTween = TweenService:Create(judgeScale, TweenInfo.new(0.15), { Scale = 1 })
	judgeTween:Play()
	local r = run
	comboLabel.Text = if r and r.combo >= 2 then string.format("%d 콤보", r.combo) else ""
	if r then scoreLabel.Text = string.format("%s", tostring(DanceScoreConfig.score(#r.notes, r.perfect, r.great))) end
end

local function judge(r: Run, note: any, kind: string)
	note.done = true
	if note.frame then note.frame:Destroy() note.frame = nil end
	if kind == "PERFECT" then r.perfect += 1 r.combo += 1
	elseif kind == "GREAT" then r.great += 1 r.combo += 1
	else r.miss += 1 r.combo = 0 end
	r.best = math.max(r.best, r.combo)
	showJudge(kind)
end

local function press(laneIndex: number)
	local lane = lanes[laneIndex]
	if lane then
		lane.flash.BackgroundTransparency = 0.3
		TweenService:Create(lane.flash, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	end
	local r = run
	if not r or not r.active then return end
	local songNow = heardSongTime(r)
	local best, bestGap = nil, math.huge
	for i = r.nextSpawn - 1, 1, -1 do
		local note = r.notes[i]
		if not note.done and note.lane == laneIndex then
			local gap = math.abs(note.t - songNow) / r.rate -- (real seconds)
			if gap < bestGap then best, bestGap = note, gap end
		end
		if songNow - note.t > 1 then break end
	end
	if best and bestGap <= DanceScoreConfig.Late then
		judge(r, best, if bestGap <= DanceScoreConfig.Perfect then "PERFECT" elseif bestGap <= DanceScoreConfig.Great then "GREAT" else "MISS")
	end
end

local function showResult(r: Run, serverResult: any)
	local score = DanceScoreConfig.score(#r.notes, r.perfect, r.great)
	local grade = DanceScoreConfig.grade(score)
	if typeof(serverResult) == "table" and typeof(serverResult.score) == "number" then
		score, grade = serverResult.score, serverResult.grade
	end
	gradeLabel.Text = grade
	resultScore.Text = tostring(score)
	if typeof(serverResult) == "table" then
		local parts = {}
		if serverResult.newBest then table.insert(parts, "🎉 내 최고 기록!") end
		if typeof(serverResult.rank) == "number" then table.insert(parts, string.format("오늘 %d위", serverResult.rank)) end
		if typeof(serverResult.best) == "number" then table.insert(parts, string.format("내 최고 %d점", serverResult.best)) end
		if typeof(serverResult.coins) == "number" and serverResult.coins > 0 then table.insert(parts, string.format("+%d 코인", serverResult.coins)) end
		resultNote.Text = table.concat(parts, " · ")
	else
		resultNote.Text = "점수를 서버에 남기지 못했어요"
	end
	countValues[1].Text = tostring(r.perfect)
	countValues[2].Text = tostring(r.great)
	countValues[3].Text = tostring(r.miss)
	countValues[4].Text = tostring(r.best)
	result.Visible = true
end

local endRun: (boolean) -> ()

local function begin()
	local t = track()
	if not t or not remote then toast("오늘의 곡을 찾을 수 없어요.") return end
	startPanel.Visible = false
	result.Visible = false
	local ok, startAt = (remote :: RemoteFunction):InvokeServer("Start")
	if not ok or typeof(startAt) ~= "number" then
		toast(if typeof(startAt) == "string" then startAt else "지금은 도전할 수 없어요.")
		return
	end
	local notes = {}
	for _, n in ipairs(DanceScoreConfig.chart(t)) do table.insert(notes, { t = n.t, lane = n.lane, done = false }) end
	run = { start = startAt, track = t, notes = notes, nextSpawn = 1, perfect = 0, great = 0, miss = 0, combo = 0, best = 0,
		rate = ClubConfig.songRate(t, 1), active = true, offStage = 0 }
	local info = DanceScoreConfig.Songs[t.soundId]
	songLabel.Text = if info then (info.title .. " · " .. info.artist) else t.title
	scoreLabel.Text = "0"
	judgeLabel.Text, comboLabel.Text = "", ""
	layout()
	setPlayMode(true)
	play.Visible = true
end

-- the run ends: finished = the song played to its end (the server checks it and the result shows)
endRun = function(finished: boolean)
	local r = run
	if not r then return end
	run = nil
	r.active = false
	for _, note in ipairs(r.notes) do
		if note.frame then note.frame:Destroy() note.frame = nil end
	end
	play.Visible = false
	countLabel.Text = ""
	setPlayMode(false)
	if finished and remote then
		local good, data = false, nil
		pcall(function()
			good, data = (remote :: RemoteFunction):InvokeServer("Finish", { perfect = r.perfect, great = r.great, miss = r.miss, combo = r.best })
		end)
		showResult(r, if good then data else nil)
	elseif remote then
		task.spawn(function() pcall(function() (remote :: RemoteFunction):InvokeServer("Stop") end) end)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local r = run
	-- the entry button: on the stage, nothing else open
	entry.Visible = r == nil and onStage() and not startPanel.Visible and not result.Visible and track() ~= nil
	if not r or not r.active then return end
	local now = workspace:GetServerTimeNow()
	-- count-in
	if now < r.start then
		countLabel.Text = tostring(math.ceil(r.start - now))
	else
		countLabel.Text = ""
	end
	-- off the stage for 2 s: the challenge ends
	if onStage() then r.offStage = 0 else r.offStage += dt end
	if r.offStage > 2 then
		toast("무대에서 내려가서 도전이 끝났어요.")
		task.spawn(endRun, false)
		return
	end
	local songNow = if now < r.start then NeonStageConfig.songTime(r.track, r.start, now) else heardSongTime(r)
	local length = DanceScoreConfig.runLength(r.track)
	barFill.Size = UDim2.fromScale(math.clamp((now - r.start) / length, 0, 1), 1)
	local fall = DanceScoreConfig.FallTime * r.rate -- (song seconds)
	-- new notes into their lanes
	while r.nextSpawn <= #r.notes and r.notes[r.nextSpawn].t - songNow <= fall do
		local note = r.notes[r.nextSpawn]
		local lane = lanes[note.lane]
		note.frame = make("Frame", { Name = "Note", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, -12, 0, 16),
			BackgroundColor3 = LANE_COLORS[note.lane], BorderSizePixel = 0 }, lane.frame)
		round(note.frame, 8)
		r.nextSpawn += 1
	end
	-- move them; a note past the late window is a miss
	local height = laneBottom - laneTop
	for i = math.max(1, r.nextSpawn - 40), r.nextSpawn - 1 do
		local note = r.notes[i]
		if not note.done then
			local ahead = (note.t - songNow) / fall -- 1 = top, 0 = hit line
			if note.frame then note.frame.Position = UDim2.new(0.5, 0, 0, height * (1 - ahead) - 8) end
			if (songNow - note.t) / r.rate > DanceScoreConfig.Late then judge(r, note, "MISS") end
		end
	end
	-- the end of the song
	if now - r.start > length + 0.4 then
		r.active = false
		task.spawn(endRun, true)
	end
end)

-- input: the four buttons, D F J K, the arrows
for i, lane in ipairs(lanes) do
	lane.button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then press(i) end
	end)
end
local KEYS = {
	[Enum.KeyCode.D] = 1, [Enum.KeyCode.F] = 2, [Enum.KeyCode.J] = 3, [Enum.KeyCode.K] = 4,
	[Enum.KeyCode.Left] = 1, [Enum.KeyCode.Down] = 2, [Enum.KeyCode.Up] = 3, [Enum.KeyCode.Right] = 4,
}
UserInputService.InputBegan:Connect(function(input, processed)
	if not run then return end
	local i = KEYS[input.KeyCode]
	if i and not (processed and UserInputService:GetFocusedTextBox()) then press(i) end
end)

-- windows
entry.Activated:Connect(function()
	local t = track()
	local info = t and DanceScoreConfig.Songs[t.soundId]
	if not t or not info then return end
	startTitle.Text = info.title
	startInfo.Text = string.format("%s · 약 %d분 · 표시 %d개", info.artist, math.floor(NeonStageConfig.realLength(t) / 60 + 0.5), #DanceScoreConfig.chart(t))
	local best = player:GetAttribute("DanceBest")
	startBest.Text = if typeof(best) == "number" and player:GetAttribute("DancePlayedDay") == DanceScoreConfig.dayKey()
		then string.format("오늘 내 최고 %d점 · 1~3위는 하루 칭호", best)
		else "오늘의 TOP 10 · 1~3위는 하루 칭호 · 첫 도전 +" .. DanceScoreConfig.ParticipationCoins .. " 코인"
	layout()
	startPanel.Visible = true
end)
startClose.Activated:Connect(function() startPanel.Visible = false end)
startGo.Activated:Connect(begin)
quit.Activated:Connect(function() endRun(false) end)
resultClose.Activated:Connect(function() result.Visible = false end)
resultAgain.Activated:Connect(function()
	result.Visible = false
	if onStage() then begin() else toast("네온 무대 위에서 도전할 수 있어요.") end
end)
player.CharacterAdded:Connect(function()
	if run then
		run = nil
		play.Visible = false
		setPlayMode(false)
	end
end)

--------------------------------------------------------------------------
-- (D-1817) the top notice: "🎵 오늘의 곡에 도전하세요!" like the cold spark lines (20 px, blinking), a tap
-- draws the dashed way to the neon stage
local joinedAt = os.clock()
local notice = button(gui, "🎵 오늘의 곡에 도전하세요!", nil, YELLOW, BODY, 20)
notice.Name = "Notice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Size = UDim2.fromOffset(340, 34)
notice.TextStrokeColor3 = Color3.new(0, 0, 0)
notice.TextStrokeTransparency = 0
notice.Visible = false
do local st = notice:FindFirstChildOfClass("UIStroke") if st then st:Destroy() end end
local noticeId = 0
local function canNotice(): boolean
	if run or startPanel.Visible or result.Visible then return false end
	if os.clock() - joinedAt < DanceScoreConfig.AnnounceMinOnline then return false end
	if player:GetAttribute("DancePlayedDay") == DanceScoreConfig.dayKey() then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then return false end
	if humanoid.SeatPart or humanoid.Sit then return false end -- (rides, seats)
	if character:GetAttribute("PhotoBooth") ~= nil then return false end -- (shooting in 오후네컷)
	if player:GetAttribute("InClubLocal") == true or ClubConfig.isInClub(root.Position) then return false end
	local c = NeonStageConfig.Center
	if Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z).Magnitude < DanceScoreConfig.AnnounceNear then return false end
	return true
end
local noticeRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("DanceScoreNotice", 60) :: RemoteEvent?
if noticeRemote then
	noticeRemote.OnClientEvent:Connect(function(kind: any)
		if kind ~= "Announce" or not canNotice() or not track() then return end
		noticeId += 1
		local id = noticeId
		notice.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
		notice.Visible = true
		local t0 = os.clock()
		while notice.Visible and noticeId == id and os.clock() - t0 < DanceScoreConfig.AnnounceSeconds do
			notice.TextTransparency = if (os.clock() - t0) % 0.75 < 0.45 then 0 else 0.7
			task.wait(0.05)
		end
		if noticeId == id then notice.Visible = false end
	end)
end
notice.Activated:Connect(function()
	notice.Visible = false
	noticeId += 1
	UiBus.ShowWay:Fire("neon")
end)

--------------------------------------------------------------------------
-- (D-1817) the TOP 10 board on the bus stop's back wall (A 네온 클럽): drawn on this screen
-- (SurfaceGui in PlayerGui, Adornee = the tagged part) from FashionGame attribute DanceTop
local boards: {[BasePart]: { rows: {TextLabel}, title: TextLabel, empty: TextLabel }} = {}
local function fillBoards()
	local ok, list = pcall(function() return HttpService:JSONDecode(FashionGame:GetAttribute("DanceTop") or "[]") end)
	if not ok or typeof(list) ~= "table" then list = {} end
	local info = DanceScoreConfig.Songs[FashionGame:GetAttribute("DanceTopSong") or DanceScoreConfig.todaySong()]
	for _, b in pairs(boards) do
		b.title.Text = if info then (info.title .. " · " .. info.artist) else ""
		b.empty.Visible = #list == 0
		for i, row in ipairs(b.rows) do
			local e = list[i]
			row.Text = if e then string.format("%2d  %s", i, tostring(e.n)) else ""
			row.Visible = e ~= nil
			local score = row:FindFirstChild("Score") :: TextLabel?
			if score then score.Text = if e then tostring(e.s) else "" end
			row.TextColor3 = if i == 1 then YELLOW elseif i <= 3 then Color3.fromRGB(255, 160, 210) else Color3.new(1, 1, 1)
		end
	end
end
local function addBoard(part: Instance)
	if not part:IsA("BasePart") or boards[part] or not part:IsDescendantOf(workspace) then return end
	local sg = make("SurfaceGui", { Name = "DanceTopBoardGui", Adornee = part, Face = Enum.NormalId.Right, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50, LightInfluence = 0, Brightness = 1.6, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(11, 7, 20) }, sg)
	make("UIPadding", { PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 24), PaddingTop = UDim.new(0, 22), PaddingBottom = UDim.new(0, 18) }, root)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, root)
	label(root, "오늘의 TOP 10", 48, Color3.new(1, 1, 1), BIG, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 54), TextStrokeColor3 = PINK, TextStrokeTransparency = 0.2 })
	local title = label(root, "", 24, CYAN, BODY, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30) })
	local empty = label(root, "아직 기록이 없어요. 첫 1위가 되어 보세요!", 22, SOFT, BODY, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 40), Visible = false, TextWrapped = true })
	local rows = {}
	for i = 1, 10 do
		local row = label(root, "", 26, Color3.new(1, 1, 1), BODY, { LayoutOrder = 3 + i, Size = UDim2.new(1, 0, 0, 44),
			TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = if i <= 3 then 0.75 else 0.9, BackgroundColor3 = if i <= 3 then PINK else CARD })
		round(row, 8)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, row)
		label(row, "", 26, YELLOW, BIG, { Name = "Score", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right })
		rows[i] = row
	end
	label(root, "네온 무대에서 🎵 오늘의 곡 도전", 20, SOFT, BODY, { LayoutOrder = 20, Size = UDim2.new(1, 0, 0, 30) })
	boards[part] = { rows = rows, title = title, empty = empty }
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			boards[part] = nil
			sg:Destroy()
		end
	end)
	fillBoards()
end
for _, part in ipairs(CollectionService:GetTagged("DanceTopBoard")) do addBoard(part) end
CollectionService:GetInstanceAddedSignal("DanceTopBoard"):Connect(addBoard)
FashionGame:GetAttributeChangedSignal("DanceTop"):Connect(fillBoards)
