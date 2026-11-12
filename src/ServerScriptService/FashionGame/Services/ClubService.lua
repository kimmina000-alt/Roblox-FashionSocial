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

local function characterOf(player: Player): Model?
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character
end

local function notify(player: Player, message: string)
	local remote = FashionGame:WaitForChild("Remotes"):FindFirstChild("ClubNotify") :: RemoteEvent?
	if remote then remote:FireClient(player, "Toast", message) end
end

-- DancePause (number, optional): clip time the dance is frozen at (인생네컷
-- ⏸ button, user 2026-10-20). nil = playing.
local function setDance(character: Model, key: string?, start: number?, speed: number?, pause: number?)
	-- (D-1124) a dance started (anywhere; in the club also the ClubVisit funnel's step 2)
	if key and character:GetAttribute("DanceKey") == nil then
		local who = Players:GetPlayerFromCharacter(character)
		if who then require(script.Parent:WaitForChild("Analytics")).interact(who, "Dance") end
	end
	character:SetAttribute("DanceKey", key)
	character:SetAttribute("DanceStart", start)
	character:SetAttribute("DanceSpeed", speed)
	character:SetAttribute("DancePause", if key then pause else nil)
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
					leaderCharacter:GetAttribute("DanceSpeed"),
				leaderCharacter:GetAttribute("DancePause"))
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
		-- (dancing anywhere, user 2026-10-26: no club check)
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
		local paused = character:GetAttribute("DancePause")
		local elapsed = if typeof(paused) == "number" then paused else (serverNow - start) * oldSpeed
		character:SetAttribute("DanceStart", serverNow - elapsed / newSpeed)
		character:SetAttribute("DanceSpeed", newSpeed)
		-- Touching the tempo makes it the player's own dance (user, 2026-10-20).
		character:SetAttribute("DanceJoined", nil)
		syncFollowers(player)
	elseif action == "Pause" or action == "Resume" then
		-- Freeze / continue the current clip (photo poses). Resume rebases
		-- DanceStart so the clip continues from the frozen frame.
		local key = character:GetAttribute("DanceKey")
		local start = character:GetAttribute("DanceStart")
		local speed = character:GetAttribute("DanceSpeed")
		if typeof(key) ~= "string" or typeof(start) ~= "number" or typeof(speed) ~= "number" then return end
		local serverNow = workspace:GetServerTimeNow()
		local paused = character:GetAttribute("DancePause")
		if action == "Pause" and typeof(paused) ~= "number" then
			character:SetAttribute("DancePause", math.max(0, serverNow - start) * speed)
		elseif action == "Resume" and typeof(paused) == "number" then
			character:SetAttribute("DanceStart", serverNow - paused / math.max(speed, 0.01))
			character:SetAttribute("DancePause", nil)
		end
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
		-- anywhere, but near each other (user 2026-10-26)
		local a0 = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local b0 = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not a0 or not b0 or (a0.Position - b0.Position).Magnitude > ClubConfig.JoinRadius then
			notify(player, "같이 추려면 가까이 가 주세요.")
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
			targetCharacter:GetAttribute("DanceSpeed"),
			targetCharacter:GetAttribute("DancePause"))
		syncFollowers(player)
	end
end

-- (dances and links no longer end outside the club: dancing anywhere, user 2026-10-26)

--------------------------------------------------
-- Shared music clock + song requests + DJ control (D-050, D-053)
-- ReplicatedStorage.FashionGame attributes:
--   ClubTrack (index into ClubConfig.Playlist), ClubTrackStart (server time),
--   ClubTrackBy (userId who chose it, 0 = automatic),
--   ClubRequests (JSON list of {i = track index, u = userId}),
--   ClubMusicSpeed (DJ playback speed), ClubMusicPitch (DJ pitch; user 2026-10-30),
--   ClubMusicVolume (DJ volume multiplier; user 2026-11-01).
-- Without a DJ anyone may queue one song at a time. With a DJ, only the DJ
-- picks: "Play" (now), "Queue" (next), "Skip"; requests are closed.
--------------------------------------------------

local HttpService = game:GetService("HttpService")
local DjService = require(script.Parent.DjService)

local MAX_REQUESTS = 20 -- (10 until D-940: the DJ's 예약 list)
local requests: {{i: number, u: number}} = {}
local trackIndex = 0
local trackEnds = 0

local function publishRequests()
	FashionGame:SetAttribute("ClubRequests", HttpService:JSONEncode(requests))
end

-- DJ playback speed (attribute ClubMusicSpeed, 1 = normal): the song plays
-- (now - ClubTrackStart) * speed seconds in, so a change moves the start to
-- keep the place in the song, and the song ends sooner or later
local function musicSpeed(): number
	local s = FashionGame:GetAttribute("ClubMusicSpeed")
	return if typeof(s) == "number" then s else 1
end
-- DJ pause (user 2026-10-30): attribute ClubMusicPaused, and ClubMusicPausedAt
-- = seconds into the song's audio where it stopped; the song clock stands
-- still (trackEnds far away) until it plays on from there
local pausedAt = 0
local function isPaused(): boolean
	return FashionGame:GetAttribute("ClubMusicPaused") == true
end
local function setPaused(on: boolean)
	if on == isPaused() then return end
	local track = ClubConfig.Playlist[trackIndex]
	local rate = ClubConfig.trackRate(track, musicSpeed())
	local now = workspace:GetServerTimeNow()
	if on then
		local start = FashionGame:GetAttribute("ClubTrackStart")
		pausedAt = if typeof(start) == "number" then (now - start) * rate else 0
		trackEnds = math.huge
		FashionGame:SetAttribute("ClubMusicPausedAt", pausedAt)
		FashionGame:SetAttribute("ClubMusicPaused", true)
	else
		FashionGame:SetAttribute("ClubMusicPaused", false)
		FashionGame:SetAttribute("ClubTrackStart", now - pausedAt / rate)
		if track then trackEnds = now + math.max(0, track.length - pausedAt) / rate + 1 end
	end
end

-- (D-849, user: "재생바에서 노래 부분 선택할 수 있게") move the song to
-- `fraction` of its length for everyone, playing or paused
local function seek(fraction: number)
	local track = ClubConfig.Playlist[trackIndex]
	if not track then return end
	local at = math.clamp(fraction, 0, 0.98) * track.length
	if isPaused() then
		pausedAt = at
		FashionGame:SetAttribute("ClubMusicPausedAt", at)
		return
	end
	local rate = ClubConfig.trackRate(track, musicSpeed())
	local now = workspace:GetServerTimeNow()
	FashionGame:SetAttribute("ClubTrackStart", now - at / rate)
	trackEnds = now + (track.length - at) / rate + 1
end

-- (a track's own baseSpeed multiplies in: ClubConfig.trackRate)
local function setMusicSpeed(new: number)
	local old = musicSpeed()
	if new == old then return end
	if isPaused() then
		-- (stopped: the new speed counts from where it plays on)
		FashionGame:SetAttribute("ClubMusicSpeed", new)
		return
	end
	local track = ClubConfig.Playlist[trackIndex]
	local oldRate, newRate = ClubConfig.trackRate(track, old), ClubConfig.trackRate(track, new)
	local now = workspace:GetServerTimeNow()
	local start = FashionGame:GetAttribute("ClubTrackStart")
	local elapsed = if typeof(start) == "number" then (now - start) * oldRate else 0
	FashionGame:SetAttribute("ClubMusicSpeed", new)
	FashionGame:SetAttribute("ClubTrackStart", now - elapsed / newRate)
	if track then trackEnds = now + math.max(0, track.length - elapsed) / newRate + 1 end
end

-- Skip vote (user 2026-11-01, D-694): without a DJ the people in the club can
-- vote the song away; it goes when ClubConfig.skipVotesNeeded(people in the
-- club) have voted. Attribute ClubSkipVotes = "votes/needed". New song → reset.
-- (D-1121, user 2026-11-09: "노래 스킵 누르면 사진처럼 재생중인 바 아래에 스킵 투표
-- 받는 창 띄우자") a tap on › starts a vote round of SKIP_ROUND seconds that
-- everyone in the club sees under the play bar with 예 / 아니요 (ClubQuickBar):
-- skipVotes[userId] = true (예) / false (아니요). The song goes as soon as the 예
-- reach ClubConfig.skipVotesNeeded; when the time is up without that, the
-- round ends and the votes are cleared. Attributes: ClubSkipVotes "yes/needed"
-- (as before), ClubSkipNo (아니요), ClubSkipEnds (server time, 0 = no round);
-- player attribute ClubSkipMine "yes" / "no" (their own answer).
local SKIP_ROUND = 30
local skipVotes: {[number]: boolean} = {}
local skipEnds = 0
local skipRound = 0
local function peopleInClub(): number
	local n = 0
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and ClubConfig.isInClub(root.Position) then n += 1 end
	end
	return n
end
local function publishSkipVotes()
	local votes, no = 0, 0
	for userId, yes in pairs(skipVotes) do
		local p = game:GetService("Players"):GetPlayerByUserId(userId)
		local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and ClubConfig.isInClub(root.Position) then
			if yes then votes += 1 else no += 1 end
		else
			skipVotes[userId] = nil
			if p then p:SetAttribute("ClubSkipMine", nil) end
		end
	end
	local needed = ClubConfig.skipVotesNeeded(peopleInClub())
	FashionGame:SetAttribute("ClubSkipVotes", string.format("%d/%d", votes, needed))
	FashionGame:SetAttribute("ClubSkipNo", no)
	FashionGame:SetAttribute("ClubSkipEnds", skipEnds)
	return votes, needed
end
local function clearSkipVotes()
	for userId in pairs(skipVotes) do
		local p = game:GetService("Players"):GetPlayerByUserId(userId)
		if p then p:SetAttribute("ClubSkipMine", nil) end
	end
	table.clear(skipVotes)
	skipEnds = 0
	skipRound += 1
end

local function playTrack(index: number, by: number)
	local track = ClubConfig.Playlist[index]
	if not track then return end
	clearSkipVotes()
	publishSkipVotes()
	trackIndex = index
	FashionGame:SetAttribute("ClubMusicPaused", false) -- (a new song always plays)
	trackEnds = workspace:GetServerTimeNow() + track.length / ClubConfig.trackRate(track, musicSpeed()) + 1
	FashionGame:SetAttribute("ClubTrackStart", workspace:GetServerTimeNow())
	FashionGame:SetAttribute("ClubTrackBy", by)
	FashionGame:SetAttribute("ClubTrack", index)
end

-- Can the track's audio play? (user 2026-10-30: a song Roblox had not approved
-- yet played as minutes of silence.) The server loads it once; a failure is
-- tried again after 10 minutes.
local playableAt: {[number]: number} = {} -- soundId → os.clock() when it last failed
local playableOk: {[number]: boolean} = {}
local function playable(index: number): boolean
	local track = ClubConfig.Playlist[index]
	if not track then return false end
	local id = track.soundId
	if playableOk[id] then return true end
	if playableAt[id] and os.clock() - playableAt[id] < 600 then return false end
	local probe = Instance.new("Sound")
	probe.SoundId = "rbxassetid://" .. tostring(id)
	probe.Volume = 0
	probe.Parent = game:GetService("SoundService")
	local t = os.clock()
	while not probe.IsLoaded and os.clock() - t < 4 do task.wait(0.1) end
	local ok = probe.IsLoaded and probe.TimeLength > 0
	probe:Destroy()
	if ok then playableOk[id] = true else playableAt[id] = os.clock() end
	return ok
end

local function playNext()
	local count = #ClubConfig.Playlist
	if count == 0 then return end
	local nextRequest = table.remove(requests, 1)
	publishRequests()
	if nextRequest and playable(nextRequest.i) then
		playTrack(nextRequest.i, nextRequest.u)
		return
	end
	-- (user 2026-10-30) a random song each time, not the one just played,
	-- skipping songs that cannot play
	local order = {}
	for i = 1, count do if i ~= trackIndex then table.insert(order, math.random(1, #order + 1), i) end end
	if #order == 0 then order = { trackIndex } end
	for _, i in ipairs(order) do
		if playable(i) then playTrack(i, 0) return end
	end
end

local function runPlaylist()
	publishRequests()
	playNext()
	local tick = 0
	while true do
		task.wait(0.5)
		if workspace:GetServerTimeNow() >= trackEnds then
			playNext()
		end
		-- (the skip count follows people coming in and leaving the club)
		tick += 1
		if tick % 4 == 0 then
			-- (D-823, user: two voted, one left without voting: it stood at 1/1)
			-- enough votes after someone left goes on to the next song too
			local votes, needed = publishSkipVotes()
			if votes > 0 and votes >= needed and DjService.CurrentDJ() == 0 then playNext() end
		end
	end
end

local function validTrack(index: any): (number?, string?)
	if typeof(index) ~= "number" or index % 1 ~= 0 or not ClubConfig.Playlist[index] then return nil, nil end
	return index, nil
end

local function onMusic(player: Player, action: any, payload: any): (boolean, any)
	local isDJ = DjService.IsDJ(player)
	-- (user 2026-11-01) tests: start Bubble Pop to try its choreography
	-- (ChoreoController's 🧪 button): Studio, or the owner's account on a
	-- live server, while ClubConfig.TestChoreoButton is on
	if action == "TestChoreoSong" then
		if not ClubConfig.canTestChoreo(player) then return false, "테스트 전용이에요." end
		for index, track in ipairs(ClubConfig.Playlist) do
			if track.choreo then -- (the first song with a choreography)
				playTrack(index, player.UserId)
				return true, nil
			end
		end
		return false, "곡이 없어요."
	end
	if action == "VoteSkip" then
		if DjService.CurrentDJ() ~= 0 then return false, "DJ가 곡을 고르는 중이에요." end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not ClubConfig.isInClub(root.Position) then return false, "클럽 안에서만 투표할 수 있어요." end
		-- (D-1121) payload "no" = 아니요; anything else (the › button, 예) = 예
		local yes = payload ~= "no"
		local now = workspace:GetServerTimeNow()
		if skipEnds <= now then
			-- a new round: from now, SKIP_ROUND seconds
			if not yes then return false, nil end -- (no round to say no to)
			clearSkipVotes()
			skipEnds = now + SKIP_ROUND
			local round = skipRound
			task.delay(SKIP_ROUND + 0.2, function()
				if skipRound == round then
					clearSkipVotes()
					publishSkipVotes()
				end
			end)
		end
		skipVotes[player.UserId] = yes
		player:SetAttribute("ClubSkipMine", if yes then "yes" else "no")
		require(script.Parent:WaitForChild("Analytics")).interact(player, "SkipVote") -- (D-1124)
		local votes, needed = publishSkipVotes()
		if votes >= needed then
			playNext()
			return true, "⏭ 투표로 다음 곡으로 넘어갔어요!"
		end
		return true, nil
	end
	if action == "Seek" then
		-- (D-849, user: the DJ and the game's owner only)
		if not ClubConfig.canSeek(player, isDJ) then return false, "DJ만 구간을 옮길 수 있어요." end
		if typeof(payload) ~= "number" or payload ~= payload then return false, nil end
		seek(payload)
		return true, nil
	end
	if action == "Request" then
		local index, why = validTrack(payload)
		if not index then return false, why or "없는 곡입니다." end
		-- (D-1359, user 2026-11-13: "클럽에서 DJ 있어도 노래 신청은 할 수 있게 해. DJ가 싫으면 그냥
		-- 건너뛰면 되니까") with a DJ on, guests still request (one each, like without a DJ);
		-- the DJ can skip a song or play another one now
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
		-- (D-940) the DJ's 예약: at the end of the next songs, in the order pressed
		if isDJ then return true, string.format("예약했어요. %d번째로 나와요.", #requests) end
		return true, string.format("신청 완료! %d번째로 나와요.", #requests)
	end
	-- (D-872, user: ⏸ / ▶ in front of the play bar) the same people as the play
	-- bar's seek: the DJ, the game's owner, Studio tests
	if action == "Pause" and not isDJ and ClubConfig.canSeek(player, false) then
		setPaused(payload == true)
		return true, if payload == true then "⏸ 일시정지" else "▶ 다시 재생"
	end
	if not isDJ then
		-- (speed / pitch were open to anyone until 2026-10-30)
		if action == "Play" or action == "Skip" or action == "Queue" or action == "Pause"
			or action == "MusicSpeed" or action == "MusicPitch" or action == "MusicVolume" then
			return false, "DJ만 할 수 있어요."
		end
	end
	if action == "Play" then
		local index, why = validTrack(payload)
		if not index then return false, why or "없는 곡입니다." end
		if not playable(index) then return false, "이 곡은 아직 재생할 수 없어요. (로블록스 승인 전)" end
		playTrack(index, player.UserId)
		return true, nil
	elseif action == "Queue" then
		local index, why = validTrack(payload)
		if not index then return false, why or "없는 곡입니다." end
		-- (D-940: the 우선예약 button) first in the next songs
		if #requests >= MAX_REQUESTS then return false, "예약이 가득 찼어요." end
		table.insert(requests, 1, { i = index, u = player.UserId })
		publishRequests()
		return true, "우선예약: 바로 다음에 나와요."
	elseif action == "Skip" then
		playNext()
		return true, nil
	elseif action == "Pause" then
		setPaused(payload == true)
		return true, if payload == true then "⏸ 일시정지" else "▶ 다시 재생"
	elseif action == "MusicSpeed" then
		if not table.find(ClubConfig.MusicSpeeds, payload) then return false, "없는 재생 속도예요." end
		setMusicSpeed(payload)
		return true, string.format("재생 속도 x%s", tostring(payload))
	elseif action == "MusicPitch" then
		if not table.find(ClubConfig.MusicPitches, payload) then return false, "없는 피치예요." end
		FashionGame:SetAttribute("ClubMusicPitch", payload)
		return true, string.format("피치 x%s", tostring(payload))
	elseif action == "MusicVolume" then
		-- (user 2026-11-01) the DJ's volume, a multiplier on the track's own
		if not table.find(ClubConfig.MusicVolumes, payload) then return false, "없는 볼륨이에요." end
		FashionGame:SetAttribute("ClubMusicVolume", payload)
		return true, string.format("볼륨 x%s", tostring(payload))
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
	-- each DJ starts with the song as it is; it goes back when the DJ ends
	if dj ~= lastDJ then
		setPaused(false) -- (a stopped song plays on when the DJ ends)
		setMusicSpeed(1)
		FashionGame:SetAttribute("ClubMusicPitch", 1)
		FashionGame:SetAttribute("ClubMusicVolume", 1)
	end
	lastDJ = dj
end

--------------------------------------------------
-- Seats tagged "PromptSeat": (user 2026-10-25) no "앉기" prompt any more;
-- walking into a seat sits you down (a plain Seat does that by itself).
-- Sitting stops a dance, and nobody stays seated during a cafe shift.
--------------------------------------------------

local function addSeatPrompt(seat: Instance)
	if not seat:IsA("Seat") or seat:GetAttribute("SeatWatched") then return end
	seat:SetAttribute("SeatWatched", true)
	local old = seat:FindFirstChild("SitPrompt")
	if old then old:Destroy() end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		local character = humanoid and humanoid.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end
		if character:GetAttribute("CafeJob") then
			humanoid.Sit = false
			return
		end
		stopDance(player)
	end)
end

-- Seats tagged "TouchSeat" have no prompt: walking onto them sits you down
-- (pocket park tiers, user 2026-10-24). The seat itself is sunk into the
-- tread so the hips rest on the wood, out of reach of the feet, so an
-- invisible zone over it does the touching. After standing up, the same
-- player is left alone for a moment so a jump off is not caught again.
local lastStood: { [Humanoid]: number } = {}
local function addTouchSeat(seat: Instance)
	if not seat:IsA("Seat") or seat:FindFirstChild("SitZone") then return end
	local zone = Instance.new("Part")
	zone.Name = "SitZone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.Transparency = 1
	zone.Size = Vector3.new(seat.Size.X, 1.6, seat.Size.Z)
	zone.CFrame = seat.CFrame * CFrame.new(0, seat.Size.Y / 2 + 0.8, 0)
	zone.Parent = seat
	zone.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.SeatPart or seat.Occupant or humanoid.Health <= 0 then return end
		if character:GetAttribute("CafeJob") then return end
		if os.clock() - (lastStood[humanoid] or 0) < 1.5 then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player then stopDance(player) end
		seat:Sit(humanoid)
	end)
end
local function watchStanding(humanoid: Humanoid)
	humanoid.Seated:Connect(function(active)
		if not active then lastStood[humanoid] = os.clock() end
	end)
	humanoid.AncestryChanged:Connect(function(_, parent)
		if parent == nil then lastStood[humanoid] = nil end
	end)
end

-- Used by PhotoBoothService: the pose stops when the shoot ends.
ClubService.StopDance = stopDance

function ClubService.Start()
	local remotes = FashionGame:WaitForChild("Remotes")
	local danceRemote = remotes:WaitForChild("Dance") :: RemoteEvent
	danceRemote.OnServerEvent:Connect(onDance)
	local function onPlayer(player: Player)
		-- A new character has no dance: followers rest until the leader dances again.
		player.CharacterAdded:Connect(function(character)
			task.defer(syncFollowers, player)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then watchStanding(humanoid) end
		end)
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then watchStanding(humanoid) end
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		-- Followers keep their current move as their own dance.
		for _, other in ipairs(Players:GetPlayers()) do
			local character = other.Character
			if character and character:GetAttribute("DanceJoined") == player.UserId then
				character:SetAttribute("DanceJoined", nil)
			end
		end
	end)
	for _, seat in ipairs(CollectionService:GetTagged("PromptSeat")) do
		addSeatPrompt(seat)
	end
	CollectionService:GetInstanceAddedSignal("PromptSeat"):Connect(addSeatPrompt)
	for _, seat in ipairs(CollectionService:GetTagged("TouchSeat")) do
		addTouchSeat(seat)
	end
	CollectionService:GetInstanceAddedSignal("TouchSeat"):Connect(addTouchSeat)
	local musicRemote = remotes:WaitForChild("Music") :: RemoteFunction
	musicRemote.OnServerInvoke = function(player, action, payload)
		return onMusic(player, action, payload)
	end
	DjService.Changed:Connect(onDJChanged)
	task.spawn(runPlaylist)
end

return ClubService
