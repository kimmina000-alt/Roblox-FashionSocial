--!strict
-- The rides' wind (D-1459, user 2026-11-15: "바이킹 움직일 때 들리는 바람 소리 : 101252896391536" and
-- "훅 내려갈 때 위에 바람 소리 추가"). SoundConfig.RideWind (a 2 s gust, looped) plays from the moving
-- part itself, so riders hear it loudest and people nearby hear it fade with distance:
--   * each viking (tag ParkViking): from its boat, louder and a little higher the faster it swings
--     (from ParkConfig.vikingState, the same clock the boat moves by)
--   * the jumping star (tag ParkJumpStar): from its car, only while it falls faster than
--     ParkConfig.JumpWindSpeed (its big drop), louder the faster
-- Every screen works it out by itself; no network.
-- (D-1708) and a cheer (ParkConfig.DropCheerSoundId) from the same parts: a viking's each time it turns at a
-- high peak and starts down, the jumping star's when its big drop starts.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local ParkConfig = require(Shared:WaitForChild("ParkConfig"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))

local WIND = "rbxassetid://" .. tostring((SoundConfig :: any).RideWind)
local VIKING_MAX = 1.1 -- (volume at the fastest swing)
local DROP_MAX = 1.3 -- (volume at JUMP_FULL studs/s down)
local JUMP_FULL = 30
local NEAR = 220 -- (camera further away: silent, nothing worked out)

local sounds: {[Instance]: Sound} = {}

local CHEER = "rbxassetid://" .. tostring(ParkConfig.DropCheerSoundId)
local function cheer(part: BasePart?)
	if not part then return end
	local snd = Instance.new("Sound")
	snd.Name = "DropCheer"
	snd.SoundId = CHEER
	snd.Volume = 0.9
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = 14
	snd.RollOffMaxDistance = 140
	snd.Parent = part
	snd:Play()
	game:GetService("Debris"):AddItem(snd, 4)
end
local lastSwing: {[Instance]: number} = {} -- (a viking's last angle change: its sign flips at a peak)
local inBigDrop: {[Instance]: boolean} = {}

local function soundOn(part: BasePart): Sound
	local s = sounds[part]
	if s and s.Parent == part then return s end
	local snd = Instance.new("Sound")
	snd.Name = "RideWind"
	snd.SoundId = WIND
	snd.Looped = true
	snd.Volume = 0
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = 14
	snd.RollOffMaxDistance = 140
	snd.Parent = part
	sounds[part] = snd
	return snd
end

local function set(part: BasePart?, volume: number, speed: number)
	if not part then return end
	local s = soundOn(part)
	s.Volume += (volume - s.Volume) * 0.35 -- (eased: no clicks)
	s.PlaybackSpeed = speed
	if s.Volume > 0.01 and not s.IsPlaying then
		s:Play()
	elseif s.Volume <= 0.01 and s.IsPlaying then
		s:Stop()
	end
end

-- the boat: the biggest part of the viking's swing
local boatCache: {[Instance]: BasePart} = {}
local function boatOf(ride: Instance): BasePart?
	local b = boatCache[ride]
	if b and b.Parent then return b end
	local swing = ride:FindFirstChild("Swing")
	if not swing then return nil end
	local best, size = nil, 0
	for _, d in ipairs(swing:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > size then best, size = d, v end
		end
	end
	if best then boatCache[ride] = best end
	return best
end

RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local cam = camera.CFrame.Position
	local t = workspace:GetServerTimeNow()
	for _, ride in ipairs(CollectionService:GetTagged("ParkViking")) do
		if not ride:IsA("Model") or not ride:IsDescendantOf(workspace) then continue end
		local boat = boatOf(ride)
		if (ride:GetPivot().Position - cam).Magnitude > NEAR then
			if boat and sounds[boat] then set(boat, 0, 1) end
			continue
		end
		local a0 = ParkConfig.vikingState(ride, t)
		local a1 = ParkConfig.vikingState(ride, t + 0.05)
		local w = math.abs(a1 - a0) / 0.05
		local maxAngle = math.rad((ride:GetAttribute("MaxAngle") :: number?) or 45)
		local period = (ride:GetAttribute("Period") :: number?) or 4
		local wMax = maxAngle * 2 * math.pi / period
		local k = math.clamp(w / wMax, 0, 1)
		set(boat, VIKING_MAX * k ^ 1.4, 0.85 + 0.35 * k)
		-- (D-1708) at a high peak the swing turns: it starts down now
		local d = a1 - a0
		local before = lastSwing[ride]
		lastSwing[ride] = d
		if before and d ~= 0 and math.sign(d) ~= math.sign(before) and math.abs(a0) >= maxAngle * ParkConfig.DropCheerHigh then
			cheer(boat)
		end
	end
	for _, ride in ipairs(CollectionService:GetTagged("ParkJumpStar")) do
		if not ride:IsA("Model") or not ride:IsDescendantOf(workspace) then continue end
		local car = ride:FindFirstChild("Car")
		local part = car and car:FindFirstChild("CarFloor") :: BasePart?
		if (ride:GetPivot().Position - cam).Magnitude > NEAR then
			if part and sounds[part] then set(part, 0, 1) end
			continue
		end
		local h0 = ParkConfig.jumpStarState(ride, t)
		local h1 = ParkConfig.jumpStarState(ride, t + 0.05)
		local down = (h0 - h1) / 0.05
		local k = if down > ParkConfig.JumpWindSpeed then math.clamp((down - ParkConfig.JumpWindSpeed) / (JUMP_FULL - ParkConfig.JumpWindSpeed), 0.25, 1) else 0
		local big = ParkConfig.jumpStarBigDrop(ride, t)
		if not big then k = 0 end -- (D-1481: the hops fall fast too; the wind is for the last drop)
		if big and not inBigDrop[ride] then cheer(part) end -- (D-1708)
		inBigDrop[ride] = big
		set(part, DROP_MAX * k, 0.95 + 0.3 * k)
	end
end)
