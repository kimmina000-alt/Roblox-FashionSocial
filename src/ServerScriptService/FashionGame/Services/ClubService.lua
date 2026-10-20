--!strict
-- Club MVP server (Stage 4): dance state, shared music clock, seat prompts.
--
-- Dance state lives on the character as attributes the server sets, so every
-- client sees the same values:
--   DanceKey   (string)  ClubConfig dance key
--   DanceStart (number)  workspace:GetServerTimeNow() when the dance began
--   DanceSpeed (number)  tempo multiplier
-- The dancing player's own client plays the animation on its character
-- (Animator replication shows it to everyone). Joining another dancer copies
-- their key, start time and speed, so both play the same frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))

local ClubService = {}

local MIN_INTERVAL = 0.15
local lastRequest: {[Player]: number} = {}

local function characterOf(player: Player): Model?
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character
end

local function clearDance(character: Model)
	character:SetAttribute("DanceKey", nil)
	character:SetAttribute("DanceStart", nil)
	character:SetAttribute("DanceSpeed", nil)
	character:SetAttribute("DanceJoined", nil)
end

local function onDance(player: Player, action: any, a: any, b: any)
	-- Stop is never throttled, so a dance always ends when the player moves.
	local now = os.clock()
	if action ~= "Stop" then
		if lastRequest[player] and now - lastRequest[player] < MIN_INTERVAL then return end
		lastRequest[player] = now
	end
	local character = characterOf(player)
	if not character then return end

	if action == "Start" then
		local dance = ClubConfig.findDance(a)
		if not dance then return end
		character:SetAttribute("DanceKey", dance.key)
		character:SetAttribute("DanceStart", workspace:GetServerTimeNow())
		character:SetAttribute("DanceSpeed", ClubConfig.clampTempo(b))
		character:SetAttribute("DanceJoined", nil)
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
	elseif action == "Stop" then
		clearDance(character)
	elseif action == "Join" then
		if typeof(a) ~= "number" then return end
		local target = Players:GetPlayerByUserId(a)
		if not target or target == player then return end
		local targetCharacter = characterOf(target)
		if not targetCharacter then return end
		local key = targetCharacter:GetAttribute("DanceKey")
		if not ClubConfig.findDance(key) then return end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not targetRoot then return end
		if (root.Position - targetRoot.Position).Magnitude > ClubConfig.JoinRadius + 10 then return end
		character:SetAttribute("DanceKey", key)
		character:SetAttribute("DanceStart", targetCharacter:GetAttribute("DanceStart"))
		character:SetAttribute("DanceSpeed", targetCharacter:GetAttribute("DanceSpeed"))
		character:SetAttribute("DanceJoined", target.UserId)
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
			if character then clearDance(character) end
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
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
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
