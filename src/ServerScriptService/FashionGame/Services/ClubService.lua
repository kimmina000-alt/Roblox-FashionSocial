--!strict
-- Club MVP server (Stage 4): dance state, shared music clock, seat prompts.
--
-- Dance state lives on the character as attributes the server sets, so every
-- client sees the same values:
--   DanceKey   (string)  ClubConfig dance key
--   DanceStart (number)  workspace:GetServerTimeNow() when the dance began
--   DanceSpeed (number)  tempo multiplier
--   DanceJoined (number) userId this player follows (같이 추기), kept while
--                        the leader rests, so the follower picks up the
--                        leader's next dance
-- The dancing player's own client plays the animation on its character
-- (Animator replication shows it to everyone).
--
-- 같이 추기 is a live link: whenever the leader starts, changes, re-tempos or
-- stops a dance, every follower copies the leader's key, start time and speed
-- (and their own followers after them), so all play the same frame. The link
-- ends when the follower picks their own dance or touches the tempo (→ own
-- dance), presses 멈추기 / 해제 (→ stops and waits), sits, leaves the club, or
-- the leader leaves the game.
-- Moving and jumping do NOT stop a dance (user, 2026-10-20). Dancing works
-- inside the club and on photo booth stages (ClubConfig.canDance).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))

local ClubService = {}

local MIN_INTERVAL = 0.15
local MAX_CHAIN = 16
local lastRequest: {[Player]: number} = {}
local outsideSince: {[Player]: number} = {}

local function characterOf(player: Player): Model?
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character
end

-- Where dancing is allowed: the club and photo booth stages (poses for photos).
local function inClub(character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and ClubConfig.canDance(root.Position)
end

local function notify(player: Player, message: string)
	local remote = FashionGame:WaitForChild("Remotes"):FindFirstChild("ClubNotify") :: RemoteEvent?
	if remote then remote:FireClient(player, "Toast", message) end
end

local function setDance(character: Model, key: string?, start: number?, speed: number?)
	character:SetAttribute("DanceKey", key)
	character:SetAttribute("DanceStart", start)
	character:SetAttribute("DanceSpeed", speed)
end

-- Copies the leader's dance to everyone following them, down the chain.
local function syncFollowers(leader: Player, depth: number?)
	local level = depth or 0
	if level > MAX_CHAIN then return end
	local leaderCharacter = characterOf(leader)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other ~= leader and other.Character
		if character and character:GetAttribute("DanceJoined") == leader.UserId then
			if leaderCharacter then
				setDance(character,
					leaderCharacter:GetAttribute("DanceKey"),
					leaderCharacter:GetAttribute("DanceStart"),
					leaderCharacter:GetAttribute("DanceSpeed"))
			else
				setDance(character, nil, nil, nil)
			end
			syncFollowers(other, level + 1)
		end
	end
end

-- Ends the player's dance and link; their followers stop too (but stay linked).
local function stopDance(player: Player)
	local character = player.Character
	if not character then return end
	setDance(character, nil, nil, nil)
	character:SetAttribute("DanceJoined", nil)
	syncFollowers(player)
end

-- True when following `target` would make a loop back to `player`.
local function wouldLoop(player: Player, target: Player): boolean
	local current: Player? = target
	for _ = 1, MAX_CHAIN do
		if not current then return false end
		if current == player then return true end
		local character = current.Character
		local leaderId = character and character:GetAttribute("DanceJoined")
		current = if typeof(leaderId) == "number" then Players:GetPlayerByUserId(leaderId) else nil
	end
	return true
end

local function onDance(player: Player, action: any, a: any, b: any)
	-- Stop/Leave are never throttled, so a dance always ends when asked.
	local now = os.clock()
	if action ~= "Stop" and action ~= "Leave" then
		if lastRequest[player] and now - lastRequest[player] < MIN_INTERVAL then return end
		lastRequest[player] = now
	end
	local character = characterOf(player)
	if not character then return end

	if action == "Start" then
		local dance = ClubConfig.findDance(a)
		if not dance then return end
		if not inClub(character) then
			notify(player, "춤은 클럽 안에서 출 수 있어요.")
			return
		end
		setDance(character, dance.key, workspace:GetServerTimeNow(), ClubConfig.clampTempo(b))
		character:SetAttribute("DanceJoined", nil)
		syncFollowers(player)
	elseif action == "Speed" then
		if character:GetAttribute("DanceKey") == nil then return end
		-- Keep the current frame: rebase the start so (now - start) * speed is unchanged.
		local oldSpeed = character:GetAttribute("DanceSpeed") or 1
		local start = character:GetAttribute("DanceStart") or workspace:GetServerTimeNow()
		local newSpeed = ClubConfig.clampTempo(a)
		local serverNow = workspace:GetServerTimeNow()
		local elapsed = (serverNow - start) * oldSpeed
		character:SetAttribute("DanceStart", serverNow - elapsed / newSpeed)
		character:SetAttribute("DanceSpeed", newSpeed)
		-- Touching the tempo makes it the player's own dance (user, 2026-10-20).
		character:SetAttribute("DanceJoined", nil)
		syncFollowers(player)
	elseif action == "Stop" then
		stopDance(player)
	elseif action == "Leave" then
		-- 같이 추기 해제: the player stops and waits (user, 2026-10-20, D-062).
		stopDance(player)
	elseif action == "Join" then
		if typeof(a) ~= "number" then return end
		local target = Players:GetPlayerByUserId(a)
		if not target or target == player then return end
		local targetCharacter = characterOf(target)
		if not targetCharacter then return end
		if not inClub(character) or not inClub(targetCharacter) then
			notify(player, "같이 추기는 클럽 안에서만 할 수 있어요.")
			return
		end
		if wouldLoop(player, target) then
			notify(player, target.DisplayName .. "님이 이미 나를 따라 추고 있어요.")
			return
		end
		character:SetAttribute("DanceJoined", target.UserId)
		setDance(character,
			targetCharacter:GetAttribute("DanceKey"),
			targetCharacter:GetAttribute("DanceStart"),
			targetCharacter:GetAttribute("DanceSpeed"))
		syncFollowers(player)
	end
end

-- Dances and links end shortly after a player leaves the club.
local function sweepOutside()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local active = character ~= nil
			and (character:GetAttribute("DanceKey") ~= nil or character:GetAttribute("DanceJoined") ~= nil)
		if active and character and not inClub(character) then
			outsideSince[player] = outsideSince[player] or now
			if now - outsideSince[player] >= ClubConfig.OutsideGrace then
				outsideSince[player] = nil
				stopDance(player)
			end
		else
			outsideSince[player] = nil
		end
	end
end

--------------------------------------------------
-- Shared music clock + song requests + DJ control (D-050, D-053)
-- ReplicatedStorage.FashionGame attributes:
--   ClubTrack (index into ClubConfig.Playlist), ClubTrackStart (server time),
--   ClubTrackBy (userId who chose it, 0 = automatic),
--   ClubRequests (JSON list of {i = track index, u = userId}).
-- Without a DJ anyone may queue one song at a time. With a DJ, only the DJ
-- picks: "Play" (now), "Queue" (next), "Skip"; requests are closed.
--------------------------------------------------

local HttpService = game:GetService("HttpService")
local DjService = require(script.Parent.DjService)

local MAX_REQUESTS = 10
local requests: {{i: number, u: number}} = {}
local trackIndex = 0
local trackEnds = 0

local function publishRequests()
	FashionGame:SetAttribute("ClubRequests", HttpService:JSONEncode(requests))
end

local function playTrack(index: number, by: number)
	local track = ClubConfig.Playlist[index]
	if not track then return end
	trackIndex = index
	trackEnds = workspace:GetServerTimeNow() + track.length + 1
	FashionGame:SetAttribute("ClubTrackStart", workspace:GetServerTimeNow())
	FashionGame:SetAttribute("ClubTrackBy", by)
	FashionGame:SetAttribute("ClubTrack", index)
end

local function playNext()
	local count = #ClubConfig.Playlist
	if count == 0 then return end
	local nextRequest = table.remove(requests, 1)
	publishRequests()
	if nextRequest then
		playTrack(nextRequest.i, nextRequest.u)
	else
		playTrack(if trackIndex == 0 then math.random(1, count) else trackIndex % count + 1, 0)
	end
end

local function runPlaylist()
	publishRequests()
	playNext()
	while true do
		task.wait(0.5)
		if workspace:GetServerTimeNow() >= trackEnds then
			playNext()
		end
	end
end

local function validTrack(index: any): number?
	if typeof(index) ~= "number" or index % 1 ~= 0 or not ClubConfig.Playlist[index] then return nil end
	return index
end

local function onMusic(player: Player, action: any, payload: any): (boolean, any)
	local isDJ = DjService.IsDJ(player)
	if action == "Request" then
		local index = validTrack(payload)
		if not index then return false, "없는 곡입니다." end
		if DjService.CurrentDJ() ~= 0 and not isDJ then
			return false, "지금은 DJ가 곡을 고르고 있어요."
		end
		if not isDJ then
			for _, entry in ipairs(requests) do
				if entry.u == player.UserId then
					return false, "신청한 곡이 나온 뒤에 다시 신청할 수 있어요."
				end
			end
		end
		if #requests >= MAX_REQUESTS then return false, "신청곡이 가득 찼어요." end
		table.insert(requests, { i = index, u = player.UserId })
		publishRequests()
		return true, string.format("신청 완료! %d번째로 나와요.", #requests)
	end
	if not isDJ then
		if action == "Play" or action == "Skip" or action == "Queue" then
			return false, "DJ만 할 수 있어요."
		end
	end
	if action == "Play" then
		local index = validTrack(payload)
		if not index then return false, "없는 곡입니다." end
		playTrack(index, player.UserId)
		return true, nil
	elseif action == "Queue" then
		local index = validTrack(payload)
		if not index then return false, "없는 곡입니다." end
		table.insert(requests, 1, { i = index, u = player.UserId })
		publishRequests()
		return true, "다음 곡으로 넣었어요."
	elseif action == "Skip" then
		playNext()
		return true, nil
	end
	-- Future DJ abilities (lights, effects, announcements): DjService.Actions.
	local handler = typeof(action) == "string" and DjService.Actions[action]
	if handler then
		if not isDJ then return false, "DJ만 할 수 있어요." end
		return handler(player, payload)
	end
	return false, "잘못된 요청입니다."
end

-- A DJ starting clears the open request list (the DJ picks from now on).
local lastDJ = 0
local function onDJChanged()
	local dj = DjService.CurrentDJ()
	if dj ~= 0 and dj ~= lastDJ then
		table.clear(requests)
		publishRequests()
	end
	lastDJ = dj
end

--------------------------------------------------
-- Seats: anything tagged "PromptSeat" gets a "앉기" prompt (MASS reference:
-- players could not find how to sit).
--------------------------------------------------

local function addSeatPrompt(seat: Instance)
	if not seat:IsA("Seat") or seat:FindFirstChild("SitPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "앉기"
	prompt.ObjectText = ""
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	prompt.Triggered:Connect(function(player)
		local character = characterOf(player)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and not seat.Occupant then
			stopDance(player)
			seat:Sit(humanoid)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant == nil
	end)
end

function ClubService.Start()
	local remotes = FashionGame:WaitForChild("Remotes")
	local danceRemote = remotes:WaitForChild("Dance") :: RemoteEvent
	danceRemote.OnServerEvent:Connect(onDance)
	local function onPlayer(player: Player)
		-- A new character has no dance: followers rest until the leader dances again.
		player.CharacterAdded:Connect(function()
			task.defer(syncFollowers, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		outsideSince[player] = nil
		-- Followers keep their current move as their own dance.
		for _, other in ipairs(Players:GetPlayers()) do
			local character = other.Character
			if character and character:GetAttribute("DanceJoined") == player.UserId then
				character:SetAttribute("DanceJoined", nil)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			sweepOutside()
		end
	end)
	for _, seat in ipairs(CollectionService:GetTagged("PromptSeat")) do
		addSeatPrompt(seat)
	end
	CollectionService:GetInstanceAddedSignal("PromptSeat"):Connect(addSeatPrompt)
	local musicRemote = remotes:WaitForChild("Music") :: RemoteFunction
	musicRemote.OnServerInvoke = function(player, action, payload)
		return onMusic(player, action, payload)
	end
	DjService.Changed:Connect(onDJChanged)
	task.spawn(runPlaylist)
end

return ClubService
