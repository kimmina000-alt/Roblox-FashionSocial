--!strict
-- The DJ's EDM button, server side (D-733 → D-735; Shared/EdmConfig). The
-- DJ's "Edm" action (Music remote → DjService.Actions, DJ only):
--   { k = "edm", v = 1..3 / false }   that EDM track on (EdmConfig.Tracks, D-759) / off
--                                     (v = true: track 1, as before D-759)
--   { k = "speed", v = 0.5..2 }       the EDM track's speed
--   { k = "volume", v = 0..3 }        the EDM track's own volume (D-764; the
--                                     song volume slider still sets both)
-- The state is the FashionGame attribute ClubEdm (JSON) for every client:
--   on, track, speed, and where the EDM track is: `pos` seconds (at speed 1) at
--   the server time `at`; it runs on at `speed` from there.
-- A new DJ (or none) turns it off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local EdmConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EdmConfig"))
local DjService = require(script.Parent.DjService)

local EdmService = {}

type State = { on: boolean, track: number, speed: number, volume: number, pos: number, at: number }

local function fresh(): State
	return { on = false, track = 1, speed = 1, volume = 1, pos = 0, at = workspace:GetServerTimeNow() }
end
local state: State = fresh()

local function publish()
	FashionGame:SetAttribute("ClubEdm", HttpService:JSONEncode(state))
end

-- the place in the EDM track now (seconds at speed 1)
local function position(now: number): number
	return if state.on then state.pos + (now - state.at) * state.speed else state.pos
end

DjService.Actions.Edm = function(_dj: Player, payload: any): (boolean, any)
	if typeof(payload) ~= "table" or typeof(payload.k) ~= "string" then return false, "잘못된 요청입니다." end
	local k, v = payload.k, payload.v
	local now = workspace:GetServerTimeNow()
	if k == "edm" then
		local track = if v == true then 1 elseif typeof(v) == "number" and EdmConfig.Tracks[v] then v else nil
		local on = track ~= nil
		-- (from the top each time it goes on, or another track is picked)
		if on and (not state.on or state.track ~= track) then state.pos = 0 end
		state.on = on
		if track then state.track = track end
		state.at = now
	elseif k == "speed" then
		if typeof(v) ~= "number" or v ~= v then return false, nil end
		local range = EdmConfig.EdmSpeed
		state.pos = position(now)
		state.at = now
		state.speed = math.clamp(math.floor(v / range.step + 0.5) * range.step, range.min, range.max)
	elseif k == "volume" then
		if typeof(v) ~= "number" or v ~= v then return false, nil end
		local range = EdmConfig.EdmVolume
		state.volume = math.clamp(math.floor(v / range.step + 0.5) * range.step, range.min, range.max)
	else
		return false, "잘못된 요청입니다."
	end
	publish()
	return true, nil
end

function EdmService.Start()
	publish()
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
