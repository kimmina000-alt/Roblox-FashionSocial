--!strict
-- DJ EDM effects, server side (D-733, Shared/EdmConfig). The DJ's "Edm" action
-- (Music remote → DjService.Actions, DJ only) changes one control; the state
-- is the FashionGame attribute ClubEdm (JSON) for every client.
-- A new song keeps the switches but forgets the tapped beat and a drop; a
-- new DJ (or none) starts from nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local EdmConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EdmConfig"))
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local DjService = require(script.Parent.DjService)

local EdmService = {}

type State = { filter: number, bass: number, kick: boolean, pump: boolean, flange: boolean, echo: boolean,
	bpm: number?, phase: number?, dropAt: number? }

local function fresh(): State
	return { filter = 1, bass = 0, kick = false, pump = false, flange = false, echo = false }
end
local state: State = fresh()

local function publish()
	FashionGame:SetAttribute("ClubEdm", HttpService:JSONEncode(state))
end

-- beat length in server seconds and the server time of a beat (as EdmController)
local function beat(): (number, number)
	if state.bpm and state.phase then return 60 / state.bpm, state.phase end
	local index = FashionGame:GetAttribute("ClubTrack")
	local track = if typeof(index) == "number" then ClubConfig.Playlist[index] else nil
	local bpm = (track and EdmConfig.Bpm[track.soundId]) or EdmConfig.Default
	local speed = FashionGame:GetAttribute("ClubMusicSpeed")
	local start = FashionGame:GetAttribute("ClubTrackStart")
	return 60 / (bpm * (if typeof(speed) == "number" then speed else 1)), if typeof(start) == "number" then start else 0
end

DjService.Actions.Edm = function(_dj: Player, payload: any): (boolean, any)
	if typeof(payload) ~= "table" or typeof(payload.k) ~= "string" then return false, "잘못된 요청입니다." end
	local k, v = payload.k, payload.v
	if k == "filter" or k == "bass" then
		if typeof(v) ~= "number" or v ~= v then return false, nil end
		(state :: any)[k] = math.clamp(v, 0, 1)
	elseif k == "kick" or k == "pump" or k == "flange" or k == "echo" then
		(state :: any)[k] = v == true
	elseif k == "drop" then
		local now = workspace:GetServerTimeNow()
		local period, anchor = beat()
		if state.dropAt and state.dropAt > now - period * EdmConfig.DropBeats then
			return false, "드롭이 끝난 뒤에 다시 할 수 있어요."
		end
		-- on a beat, BuildBeats or a little more from now (the next whole beat after that)
		state.dropAt = anchor + math.ceil((now - anchor) / period + EdmConfig.BuildBeats) * period
	elseif k == "tap" then
		if typeof(v) ~= "table" or typeof(v.bpm) ~= "number" or typeof(v.phase) ~= "number" then return false, nil end
		if v.bpm ~= v.bpm or v.phase ~= v.phase then return false, nil end
		state.bpm = math.clamp(math.floor(v.bpm * 10 + 0.5) / 10, EdmConfig.MinBpm, EdmConfig.MaxBpm)
		state.phase = v.phase
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
		state.bpm, state.phase, state.dropAt = nil, nil, nil
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
