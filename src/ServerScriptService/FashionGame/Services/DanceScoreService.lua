--!strict
-- 안무 따라 하기 점수 "오늘의 곡 도전" (D-1816 / D-1817, DanceScoreConfig, docs/01_SYSTEMS/DANCE_SCORE.md).
-- Remote "DanceScore" (RemoteFunction):
--   "Start"  → only on the neon stage: the challenge starts CountIn seconds from now; character
--              attributes DanceChallenge = that server time, DanceChallengeTrack = the song's soundId,
--              so every screen keeps this dancer on their own song clock (RemoteChoreoSync).
--              Returns (true, start, soundId).
--   "Stop"   → the challenge ends (quit, walked off, the song ended).
--   "Finish" { perfect, great, miss, combo } → checked against the chart and the time played; returns
--              (true, { score, grade, best, rank, coins }).
-- The client judges the taps on its own clock (phones lag); the server only throws out what cannot be.
--
-- (D-1817, step 2) today's ranking: OrderedDataStore "DanceScore1_<day>_<soundId>" (day = KST, turning at
-- 05:00), key = userId, value = the day's best; in Studio a table in memory (no live DataStore).
-- Read every BoardRefresh seconds and after a new best: FashionGame attributes DanceTop (JSON list of
-- { n = name, s = score } for the top 10), DanceTopDay, DanceTopSong. Players in the server get
-- DanceBest / DancePlayedDay (their best today) and Title_Dance = their rank in the top 3 (the
-- name-tag badge). Coins once a day for a finished run (EconomyService.Earn, daily cap "DanceScore").
-- The notice clock: RemoteEvent "DanceScoreNotice" fires "Announce" to everyone every AnnounceEvery
-- seconds; each screen decides whether to show it (DanceScoreController).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local DanceScoreConfig = require(Shared:WaitForChild("DanceScoreConfig"))
local NeonStageConfig = require(Shared:WaitForChild("NeonStageConfig"))

local DanceScoreService = {}

type Run = { start: number, soundId: number, total: number }
local runs: {[Player]: Run} = {}
local STUDIO = RunService:IsStudio()
local memory: {[string]: {[string]: number}} = {} -- (Studio: day store name → userId → best)
local names: {[number]: string} = {}
local top: { { id: number, s: number } } = {}

local function storeName(day: string, soundId: number): string
	return string.format("DanceScore1_%s_%d", day, soundId)
end
local function store(day: string, soundId: number): OrderedDataStore?
	if STUDIO then return nil end
	local ok, s = pcall(function() return DataStoreService:GetOrderedDataStore(storeName(day, soundId)) end)
	return if ok then s else nil
end

-- a player's best today (0 = none)
local function bestOf(userId: number, day: string, soundId: number): number
	if STUDIO then
		local t = memory[storeName(day, soundId)]
		return t and t[tostring(userId)] or 0
	end
	local s = store(day, soundId)
	if not s then return 0 end
	local ok, v = pcall(function() return (s :: OrderedDataStore):GetAsync(tostring(userId)) end)
	return if ok and typeof(v) == "number" then v else 0
end
-- (D-1818d) values are DanceScoreConfig.pack(score, combo)

-- keeps the higher score; returns the day's best
local function saveBest(userId: number, day: string, soundId: number, score: number): number
	if STUDIO then
		local name = storeName(day, soundId)
		memory[name] = memory[name] or {}
		local t = memory[name]
		local key = tostring(userId)
		t[key] = math.max(t[key] or 0, score)
		return t[key]
	end
	local s = store(day, soundId)
	if not s then return score end
	local best = score
	pcall(function()
		(s :: OrderedDataStore):UpdateAsync(tostring(userId), function(old)
			local o = if typeof(old) == "number" then old else 0
			best = math.max(o, score)
			if score <= o then return nil end
			return score
		end)
	end)
	return best
end

local function nameOf(userId: number): string
	if names[userId] then return names[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.DisplayName return p.DisplayName end
	return "?"
end

-- today's top (100 read, 10 shown) → attributes, titles
local function refresh()
	local day = DanceScoreConfig.dayKey()
	local soundId = DanceScoreConfig.todaySong()
	local list: { { id: number, s: number } } = {}
	if STUDIO then
		for key, v in pairs(memory[storeName(day, soundId)] or {}) do
			table.insert(list, { id = tonumber(key) :: number, s = v })
		end
		table.sort(list, function(a, b) return a.s > b.s end)
	else
		local s = store(day, soundId)
		if s then
			pcall(function()
				local page = (s :: OrderedDataStore):GetSortedAsync(false, 100):GetCurrentPage()
				for _, entry in ipairs(page) do
					local id = tonumber(entry.key)
					if id and typeof(entry.value) == "number" then table.insert(list, { id = id, s = entry.value }) end
				end
			end)
		end
	end
	top = list
	-- names of the top 10 who are not here (one call)
	local missing = {}
	for i = 1, math.min(10, #list) do
		local id = list[i].id
		if not names[id] and not Players:GetPlayerByUserId(id) and id > 0 then table.insert(missing, id) end
	end
	if #missing > 0 then
		pcall(function()
			for _, info in ipairs(UserService:GetUserInfosByUserIdsAsync(missing)) do names[info.Id] = info.DisplayName end
		end)
	end
	local shown = {}
	for i = 1, math.min(10, #list) do
		local score, combo = DanceScoreConfig.unpack(list[i].s)
		table.insert(shown, { n = nameOf(list[i].id), s = score, c = combo })
	end
	FashionGame:SetAttribute("DanceTop", HttpService:JSONEncode(shown))
	FashionGame:SetAttribute("DanceTopDay", day)
	FashionGame:SetAttribute("DanceTopSong", soundId)
	-- titles: today's top 3 who are here
	local rankOf: {[number]: number} = {}
	for i = 1, math.min(DanceScoreConfig.TitleTop, #list) do rankOf[list[i].id] = i end
	for _, p in ipairs(Players:GetPlayers()) do
		local rank = rankOf[p.UserId]
		if p:GetAttribute("Title_Dance") ~= rank then p:SetAttribute("Title_Dance", rank) end
		if p:GetAttribute("DancePlayedDay") ~= nil and p:GetAttribute("DancePlayedDay") ~= day then
			p:SetAttribute("DancePlayedDay", nil)
			p:SetAttribute("DanceBest", nil)
		end
	end
end

local function rankIn(userId: number): number?
	for i, e in ipairs(top) do
		if e.id == userId then return i end
	end
	return nil
end

local function setAttributes(player: Player, start: number?, soundId: number?)
	local character = player.Character
	if not character then return end
	character:SetAttribute("DanceChallenge", start)
	character:SetAttribute("DanceChallengeTrack", soundId)
end

-- (D-1818c) the aurora round a dancer on a long combo, seen by everyone: soft aurora-coloured light
-- rising round the body (a particle emitter on the root)
-- (D-1818d, user 2026-11-21: "콤보 단계별 오로라 차별화 점점 화려하게 남들에게도 보이게") level 1..3, richer each
-- step: 1 = the soft aurora; 2 = denser and bigger + rising sparkles; 3 = all of that + a glow light on the
-- dancer and a wide ring of colour at the feet
local function setAurora(player: Player, level: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local old = root:FindFirstChild("DanceAurora")
	if old and old:GetAttribute("Level") == level then return end
	if old then old:Destroy() end
	if level <= 0 then return end
	local a = Instance.new("Attachment")
	a.Name = "DanceAurora"
	a:SetAttribute("Level", level)
	a.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 170)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(70, 220, 255)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(170, 110, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 200)),
	})
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.4, 2)
	e.Rate = 22
	e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Rate = ({ 22, 40, 60 })[level]
	local grow = ({ 1, 1.4, 1.8 })[level]
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * grow), NumberSequenceKeypoint.new(1, 5 * grow) })
	e.Parent = a
	if level >= 2 then
		local sp = Instance.new("ParticleEmitter")
		sp.Name = "Sparkles"
		sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sp.Color = e.Color
		sp.LightEmission = 1
		sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		sp.Lifetime = NumberRange.new(1, 1.6)
		sp.Rate = if level >= 3 then 50 else 25
		sp.Speed = NumberRange.new(3, 6)
		sp.SpreadAngle = Vector2.new(180, 180)
		sp.Acceleration = Vector3.new(0, 4, 0)
		sp.Parent = a
	end
	if level >= 3 then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = Color3.fromRGB(140, 220, 255)
		light.Brightness = 3
		light.Range = 14
		light.Parent = a
		local ring = Instance.new("ParticleEmitter")
		ring.Name = "Ring"
		ring.Texture = "rbxasset://textures/particles/smoke_main.dds"
		ring.Color = e.Color
		ring.LightEmission = 1
		ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 9) })
		ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		ring.Lifetime = NumberRange.new(0.8)
		ring.Rate = 6
		ring.Speed = NumberRange.new(0)
		ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		ring.EmissionDirection = Enum.NormalId.Bottom
		ring.Parent = a
	end
end

local function stop(player: Player)
	runs[player] = nil
	setAttributes(player, nil, nil)
	if player.Character then player.Character:SetAttribute("DanceFrozen", nil) end
	setAurora(player, 0)
end

local function start(player: Player): (boolean, any, any)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not NeonStageConfig.onStage(root.Position) then
		return false, "네온 무대 위에서 도전할 수 있어요.", nil
	end
	local soundId = DanceScoreConfig.todaySong()
	local track = NeonStageConfig.trackById(soundId)
	if not track then return false, "오늘의 곡을 찾을 수 없어요.", nil end
	local at = workspace:GetServerTimeNow() + DanceScoreConfig.CountIn
	runs[player] = { start = at, soundId = soundId, total = DanceScoreConfig.noteCount(DanceScoreConfig.chart(track)) } -- (D-1818g: held notes count twice)
	setAttributes(player, at, soundId)
	return true, at, soundId
end

local function finish(player: Player, result: any): (boolean, any)
	local run = runs[player]
	stop(player)
	if not run or typeof(result) ~= "table" then return false, nil end
	local perfect, great, miss, combo = result.perfect, result.great, result.miss, result.combo
	for _, v in ipairs({ perfect, great, miss, combo }) do
		if typeof(v) ~= "number" or v ~= v or v < 0 or v % 1 ~= 0 then return false, nil end
	end
	local track = NeonStageConfig.trackById(run.soundId)
	if not track then return false, nil end
	-- what cannot be: more judged notes than the chart has, a combo over the hits, or a finish before
	-- most of the song has played
	local played = workspace:GetServerTimeNow() - run.start
	if perfect + great + miss > run.total + 2 or combo > perfect + great
		or played < DanceScoreConfig.runLength(track) * 0.85 then
		return false, nil
	end
	local score = DanceScoreConfig.score(run.total, perfect, great)
	local day = DanceScoreConfig.dayKey(run.start)
	local before = tonumber(player:GetAttribute("DanceBest")) or 0
	local best = DanceScoreConfig.unpack(saveBest(player.UserId, day, run.soundId, DanceScoreConfig.pack(score, combo)))
	player:SetAttribute("DanceBest", best)
	player:SetAttribute("DancePlayedDay", day)
	-- coins once a day (the daily cap)
	local coins = 0
	pcall(function()
		local EconomyService = require(script.Parent:WaitForChild("EconomyService")) :: any
		coins = EconomyService.Earn(player, DanceScoreConfig.ParticipationCoins, "DanceScore", DanceScoreConfig.ParticipationCoins, "오늘의 곡 도전")
	end)
	if best > before then refresh() end
	return true, { score = score, grade = DanceScoreConfig.grade(score), best = best, rank = rankIn(player.UserId), coins = coins, newBest = score > before }
end

local function onJoin(player: Player)
	names[player.UserId] = player.DisplayName
	player.CharacterAdded:Connect(function() runs[player] = nil end)
	task.spawn(function()
		local day = DanceScoreConfig.dayKey()
		local best = DanceScoreConfig.unpack(bestOf(player.UserId, day, DanceScoreConfig.todaySong()))
		if best > 0 and player.Parent then
			player:SetAttribute("DanceBest", best)
			player:SetAttribute("DancePlayedDay", day)
		end
		local rank = rankIn(player.UserId)
		if rank and rank <= DanceScoreConfig.TitleTop and player.Parent then player:SetAttribute("Title_Dance", rank) end
	end)
end

function DanceScoreService.Start()
	local Remotes = FashionGame:WaitForChild("Remotes")
	local remote = Remotes:FindFirstChild("DanceScore") :: RemoteFunction?
	if not remote then
		local r = Instance.new("RemoteFunction")
		r.Name = "DanceScore"
		r.Parent = Remotes
		remote = r
	end
	local notice = Remotes:FindFirstChild("DanceScoreNotice") :: RemoteEvent?
	if not notice then
		local e = Instance.new("RemoteEvent")
		e.Name = "DanceScoreNotice"
		e.Parent = Remotes
		notice = e
	end
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, payload: any)
		if action == "Start" then
			return start(player)
		elseif action == "Stop" then
			stop(player)
			return true
		elseif action == "Finish" then
			return finish(player, payload)
		elseif action == "Freeze" or action == "Aurora" then
			-- (D-1818c) a miss holds the dance (character attribute DanceFrozen: other screens leave its pose
			-- alone), the long combo's aurora; only in a run
			if not runs[player] or not player.Character then return false end
			if action == "Freeze" then
				player.Character:SetAttribute("DanceFrozen", if payload == true then true else nil)
			else
				setAurora(player, if typeof(payload) == "number" then math.clamp(math.floor(payload), 0, 3) else 0)
			end
			return true
		end
		return false
	end
	Players.PlayerRemoving:Connect(function(player) runs[player] = nil end)
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do onJoin(player) end
	-- the ranking, now and every BoardRefresh seconds
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(DanceScoreConfig.BoardRefresh)
		end
	end)
	-- the notice clock (aligned to the server time, so every server announces at the same moments);
	-- Studio test: FashionGame attribute DanceNoticeEvery (seconds) for a shorter gap
	task.spawn(function()
		local last = -1
		while true do
			task.wait(1)
			local every = DanceScoreConfig.AnnounceEvery
			local test = FashionGame:GetAttribute("DanceNoticeEvery")
			if STUDIO and typeof(test) == "number" and test >= 10 then every = test end
			local slot = math.floor(workspace:GetServerTimeNow() / every)
			if last >= 0 and slot ~= last then
				(notice :: RemoteEvent):FireAllClients("Announce", DanceScoreConfig.todaySong())
			end
			last = slot
		end
	end)
end

return DanceScoreService
