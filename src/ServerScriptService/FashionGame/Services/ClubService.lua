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
-- Shared music clock: ReplicatedStorage.FashionGame attributes
--   ClubTrack (index into ClubConfig.Playlist), ClubTrackStart (server time)
--------------------------------------------------

local function runPlaylist()
	local count = #ClubConfig.Playlist
	if count == 0 then return end
	local index = math.random(1, count)
	while true do
		local track = ClubConfig.Playlist[index]
		FashionGame:SetAttribute("ClubTrackStart", workspace:GetServerTimeNow())
		FashionGame:SetAttribute("ClubTrack", index)
		task.wait(track.length + 1)
		index = index % count + 1
	end
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
	task.spawn(runPlaylist)
end

return ClubService
