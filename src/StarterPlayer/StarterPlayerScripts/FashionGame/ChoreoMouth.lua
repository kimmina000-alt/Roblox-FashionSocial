--!strict
-- (D-1186, user 2026-11-10: "안무 출 때 입 모양 움직이게 해. 벙긋벙긋 노래 부르는 것처럼. 노래 안 나올 때는 움직이면 안 됨.
-- 계속 움직이지 말고 간헐적으로 움직이게 해")
-- While a choreography plays, a dancer with a dynamic head (FaceControls) moves the jaw like singing along:
-- only inside the song's sung stretches (ClubPlaylist track `vocals = { { from, to }, ... }`, song seconds),
-- and not all the time: 1.3 s slots, about 6 in 10 of them sung, about 5 syllables a second. The slots
-- come from the song clock, so every screen shows the same mouth. Songs without `vocals` (not measured
-- yet) and classic heads: no movement. Studio test: FashionGame attribute MouthTest = true sings always.

local RunService = game:GetService("RunService")
local Mouth = {}

local jaw: {[Model]: number} = setmetatable({}, { __mode = "k" }) :: any

local function sungAt(track: any, t: number): boolean
	local v = track and track.vocals
	if not v then return false end
	for _, s in ipairs(v) do
		if t >= s[1] and t < s[2] then return true end
	end
	return false
end

local function hash(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

function Mouth.apply(character: Model, track: any, songTime: number?, dt: number)
	local head = character:FindFirstChild("Head")
	local fc = head and head:FindFirstChildOfClass("FaceControls")
	if not fc then return end
	local target = 0
	local fg = game.ReplicatedStorage:FindFirstChild("FashionGame")
	local test = RunService:IsStudio() and fg ~= nil and fg:GetAttribute("MouthTest") == true
	if songTime and (test or sungAt(track, songTime)) then
		local slot = math.floor(songTime / 1.3)
		local seed = (track and tonumber(track.soundId) or 0) % 997
		if hash(slot + seed) < 0.6 then
			-- syllables: open and close about 5 times a second, a little uneven
			local ph = songTime * 2 * math.pi * (4.4 + hash(slot * 3 + seed) * 1.4) + slot
			local o = math.max(0, math.sin(ph))
			target = 0.08 + 0.42 * o * (0.6 + 0.4 * hash(math.floor(songTime * 5) + seed))
		end
	end
	local cur = jaw[character] or 0
	cur += (target - cur) * math.min(dt * 18, 1)
	jaw[character] = cur
	-- (written after the animator: the mood animation's own jaw is left alone while the mouth rests)
	if cur > 0.01 or target > 0 then
		fc.JawDrop = math.max(fc.JawDrop, cur)
		fc.LipsTogether = 0
	end
end

function Mouth.stop(character: Model)
	jaw[character] = nil
end

return Mouth
