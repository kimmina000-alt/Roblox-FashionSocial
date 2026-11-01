--!strict
-- DJ EDM effects, server side (D-733, D-734; Shared/EdmConfig). The DJ's
-- "Edm" action (Music remote → DjService.Actions, DJ only) changes one
-- control; the state is the FashionGame attribute ClubEdm (JSON) for every
-- client.
--   kick  on/off      bpm   the kick's tempo (the slider beside 킥)
--   pump  on/off      echo  on/off
--   drop  a build-up and the drop; pressed again while it runs: off
-- A new song keeps the switches but forgets the kick tempo and a drop; a new
-- DJ (or none) starts from nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local EdmConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EdmConfig"))
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local DjService = require(script.Parent.DjService)

local EdmService = {}

type State = { kick: boolean, pump: boolean, echo: boolean, bpm: number?, dropAt: number? }

local function fresh(): State
	return { kick = false, pump = false, echo = false }
end
local state: State = fresh()

local function publish()
	FashionGame:SetAttribute("ClubEdm", HttpService:JSONEncode(state))
end

-- beat length in server seconds and the server time of a beat (as EdmController)
local function beat(): (number, number)
	local start = FashionGame:GetAttribute("ClubTrackStart")
	local anchor = if typeof(start) == "number" then start else 0
	if state.bpm then return 60 / state.bpm, anchor end
	local index = FashionGame:GetAttribute("ClubTrack")
	local track = if typeof(index) == "number" then ClubConfig.Playlist[index] else nil
	local bpm = (track and EdmConfig.Bpm[track.soundId]) or EdmConfig.Default
	local speed = FashionGame:GetAttribute("ClubMusicSpeed")
	return 60 / (bpm * (if typeof(speed) == "number" then speed else 1)), anchor
end

DjService.Actions.Edm = function(_dj: Player, payload: any): (boolean, any)
	if typeof(payload) ~= "table" or typeof(payload.k) ~= "string" then return false, "잘못된 요청입니다." end
	local k, v = payload.k, payload.v
	if k == "kick" or k == "pump" or k == "echo" then
		(state :: any)[k] = v == true
	elseif k == "bpm" then
		if typeof(v) ~= "number" or v ~= v then return false, nil end
		state.bpm = math.clamp(math.floor(v + 0.5), EdmConfig.MinBpm, EdmConfig.MaxBpm)
	elseif k == "drop" then
		local now = workspace:GetServerTimeNow()
		local period, anchor = beat()
		if state.dropAt and now < state.dropAt + period * EdmConfig.DropBeats then
			-- (D-734, user: pressed again while it runs = off)
			state.dropAt = nil
		else
			-- on a beat, BuildBeats or a little more from now (the next whole beat after that)
			state.dropAt = anchor + math.ceil((now - anchor) / period + EdmConfig.BuildBeats) * period
		end
	elseif k == "reset" then
		state = fresh()
	else
		return false, "잘못된 요청입니다."
	end
	publish()
	return true, nil
end

function EdmService.Start()
	publish()
	FashionGame:GetAttributeChangedSignal("ClubTrack"):Connect(function()
		state.bpm, state.dropAt = nil, nil
		publish()
	end)
	local lastDJ = FashionGame:GetAttribute("ClubDJ")
	FashionGame:GetAttributeChangedSignal("ClubDJ"):Connect(function()
		local dj = FashionGame:GetAttribute("ClubDJ")
		if dj ~= lastDJ then
			lastDJ = dj
			state = fresh()
			publish()
		end
	end)
end

return EdmService
