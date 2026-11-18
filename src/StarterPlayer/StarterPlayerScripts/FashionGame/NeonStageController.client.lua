--!strict
-- 네온 무대 (D-1792, NeonStageConfig). On this screen:
--   * the stage song (A2O LITE-NEON) plays on the server's shared clock (FashionGame attribute
--     NeonStageStart) with the club's sound for it (its lab: tempo, pitch, boosts, EQ), as loud as
--     NeonStageConfig.level says where this player is (full on the stage, fading out past the plaza);
--     LocalPlayer attribute NeonHeard = that level, so DanceController ducks the club music;
--   * standing on the stage, the song's choreography is danced on that clock (UiBus.ChoreoStage →
--     ChoreoController), so everyone up there is on the same beat. Walking stops it (as everywhere);
--     standing still starts it again. 춤 멈추기 (or a dance from the menu) is respected until this
--     player steps off the stage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local NeonStageConfig = require(Shared:WaitForChild("NeonStageConfig"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local player = Players.LocalPlayer

local track = NeonStageConfig.track()
if not track then
	warn("[NeonStageController] NEON is not in the playlist:", NeonStageConfig.SoundId)
	return
end
local lab = track.lab :: any
local playSpeed = NeonStageConfig.playSpeed(track)

-- the sound, set up like the club's (DanceController): lab boost groups (heard = volume × boost ×
-- boost2 × boost3 × boost4), the lab's pitch split over PitchShift effects and its EQ
local function group(name: string, volume: any, parent: Instance): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = if typeof(volume) == "number" then math.clamp(volume, 0, 10) else 1
	g.Parent = parent
	return g
end
local g4 = group("NeonStageBoost4", lab and lab.boost4, SoundService)
local g3 = group("NeonStageBoost3", lab and lab.boost3, g4)
local g2 = group("NeonStageBoost2", lab and lab.boost2, g3)
local g1 = group("NeonStageBoost", lab and lab.boost, g2)
local music = Instance.new("Sound")
music.Name = "NeonStageMusic" -- (ChoreoController / RemoteChoreoSync read where it is)
music.SoundId = "rbxassetid://" .. tostring(track.soundId)
music.Looped = false
music.Volume = 0
music.PlaybackSpeed = playSpeed
music.SoundGroup = g1
music.Parent = script
if lab then
	local _, octave = ClubConfig.labEffective(lab)
	local parts = if math.abs(octave - 1) < 1e-4 then {} else ClubConfig.octaveParts(octave)
	for i, part in ipairs(parts) do
		local shift = Instance.new("PitchShiftSoundEffect")
		shift.Name = "NeonPitch" .. i
		shift.Octave = part
		shift.Priority = 10 - i
		shift.Parent = music
	end
	if (lab.low or 0) ~= 0 or (lab.mid or 0) ~= 0 or (lab.high or 0) ~= 0 then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "NeonEQ"
		eq.LowGain, eq.MidGain, eq.HighGain = lab.low or 0, lab.mid or 0, lab.high or 0
		eq.Priority = 20
		eq.Parent = music
	end
end
local fullVolume = math.min(if lab and typeof(lab.volume) == "number" then lab.volume else 10, 10)

local function rootAndHumanoid(): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") then root else nil, humanoid
end

local optedOut = false -- (stopped the stage dance by hand: not again until off the stage)
local wasOnStage = false
player:GetAttributeChangedSignal("ChoreoStage"):Connect(function()
	-- (a new run of the song stops and starts the dance at once: looked at a moment later)
	task.wait()
	if player:GetAttribute("ChoreoStage") ~= nil then return end
	-- the stage dance ended: by walking (it comes back when standing still) or by hand (춤 멈추기, a
	-- dance from the menu: it stays off while on the stage)
	local root, humanoid = rootAndHumanoid()
	local walking = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
	if wasOnStage and root and NeonStageConfig.onStage(root.Position) and not walking then optedOut = true end
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then return end
	accumulator = 0
	local start = FashionGame:GetAttribute("NeonStageStart")
	local root, humanoid = rootAndHumanoid()
	local now = workspace:GetServerTimeNow()
	local running = typeof(start) == "number" and now - (start :: number) < NeonStageConfig.realLength(track)
	-- the music on the shared clock
	local level = if running and root then NeonStageConfig.level(root.Position) else 0
	if running then
		local want = (now - (start :: number)) * playSpeed
		if not music.IsPlaying then
			music.TimePosition = math.max(0, want)
			music:Play()
		elseif math.abs(music.TimePosition - want) > 0.6 then
			music.TimePosition = math.max(0, want) -- (a restart, or this screen fell behind)
		end
		music.Volume = fullVolume * level
	elseif music.IsPlaying then
		music:Stop()
		music.Volume = 0
	end
	local heard = if level > 0 then level else nil
	if player:GetAttribute("NeonHeard") ~= heard then player:SetAttribute("NeonHeard", heard) end
	-- the stage dance
	local onStage = running and root ~= nil and NeonStageConfig.onStage(root.Position)
	if not onStage then optedOut = false end
	wasOnStage = onStage
	local dancing = player:GetAttribute("ChoreoStage")
	if onStage and humanoid then
		local character = player.Character
		local still = humanoid.MoveDirection.Magnitude <= 0.1 and not humanoid.Sit and not humanoid.PlatformStand
		local menuDance = character ~= nil and character:GetAttribute("DanceKey") ~= nil
		if dancing ~= start and still and not menuDance and not optedOut and track.choreo then
			UiBus.ChoreoStage:Fire(track.soundId, start)
		end
	elseif dancing ~= nil then
		UiBus.ChoreoStage:Fire(nil, nil)
	end
end)

player.CharacterAdded:Connect(function()
	optedOut = false
	wasOnStage = false
end)
