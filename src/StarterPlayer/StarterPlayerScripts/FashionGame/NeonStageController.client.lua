--!strict
-- 네온 무대 (D-1792, NeonStageConfig). On this screen:
--   * the stage song plays on the server's shared clock (FashionGame attributes NeonStageTrack = its
--     soundId, NeonStageStart = when it began; D-1820: a random club song with a choreography each
--     time) with the club's sound for it (its lab: tempo, pitch, boosts, EQ), as loud as
--     NeonStageConfig.level says where this player is (full on the stage, fading out past the plaza);
--     LocalPlayer attribute NeonHeard = that level, so DanceController ducks the club music;
--   * standing on the stage, the song's choreography is danced on that clock (UiBus.ChoreoStage →
--     ChoreoController), so everyone up there is on the same beat. Walking stops it (as everywhere);
--     standing still starts it again. 춤 멈추기 (or a dance from the menu) is respected until this
--     player steps off the stage;
--   * (D-1820) on the stage a
--     🎥 button (like the rides' 👁 1인칭) switches the club's stage camera, which then
--     films this player on the stage song's clock (StageCameraController), for songs that have shots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local ClubCamera = require(Shared:WaitForChild("ClubCamera"))
local NeonStageConfig = require(Shared:WaitForChild("NeonStageConfig"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- the sound, set up like the club's (DanceController): lab boost groups (heard = volume × boost ×
-- boost2 × boost3 × boost4), the lab's pitch split over PitchShift effects and its EQ; set per song
local function group(name: string, parent: Instance): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = parent
	return g
end
local g4 = group("NeonStageBoost4", SoundService)
local g3 = group("NeonStageBoost3", g4)
local g2 = group("NeonStageBoost2", g3)
local g1 = group("NeonStageBoost", g2)
local music = Instance.new("Sound")
music.Name = "NeonStageMusic" -- (ChoreoController / RemoteChoreoSync / StageCameraController read where it is)
music.Looped = false
music.Volume = 0
music.SoundGroup = g1
music.Parent = script

local loadedId: number? = nil
local playSpeed = 1
local fullVolume = 0
local function boostOf(v: any): number
	return if typeof(v) == "number" then math.clamp(v, 0, 10) else 1
end
local function setTrack(track: ClubConfig.Track)
	if loadedId == track.soundId then return end
	loadedId = track.soundId
	music:Stop()
	music.SoundId = "rbxassetid://" .. tostring(track.soundId)
	playSpeed = NeonStageConfig.playSpeed(track)
	music.PlaybackSpeed = playSpeed
	for _, d in ipairs(music:GetChildren()) do
		if d:IsA("SoundEffect") then d:Destroy() end
	end
	local lab = (track :: any).lab
	g1.Volume, g2.Volume, g3.Volume, g4.Volume = boostOf(lab and lab.boost), boostOf(lab and lab.boost2), boostOf(lab and lab.boost3), boostOf(lab and lab.boost4)
	local octave = if lab then select(2, ClubConfig.labEffective(lab)) else ((track :: any).octave or 1)
	local parts = if math.abs(octave - 1) < 1e-4 then {} else ClubConfig.octaveParts(octave)
	for i, part in ipairs(parts) do
		local shift = Instance.new("PitchShiftSoundEffect")
		shift.Name = "NeonPitch" .. i
		shift.Octave = part
		shift.Priority = 10 - i
		shift.Parent = music
	end
	if lab and ((lab.low or 0) ~= 0 or (lab.mid or 0) ~= 0 or (lab.high or 0) ~= 0) then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "NeonEQ"
		eq.LowGain, eq.MidGain, eq.HighGain = lab.low or 0, lab.mid or 0, lab.high or 0
		eq.Priority = 20
		eq.Parent = music
	end
	fullVolume = math.min(if lab and typeof(lab.volume) == "number" then lab.volume
		elseif typeof((track :: any).volume) == "number" then (track :: any).volume else ClubConfig.MusicVolume, 10)
end

local function rootAndHumanoid(): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") then root else nil, humanoid
end

-- the 🎥 무대 카메라 button, where the rides' 👁 1인칭 sits (bottom middle, over the item hotbar)
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local camGui = Instance.new("ScreenGui")
camGui.Name = "NeonStageCamera"
camGui.ResetOnSpawn = false
camGui.DisplayOrder = 30
camGui.Parent = playerGui
local camButton = Instance.new("TextButton")
camButton.Name = "StageCam"
-- (D-1823, user 2026-11-19: "무대카메라 글씨 지우고 아이콘만 두기") a round button with the 🎥 only
camButton.AnchorPoint = Vector2.new(0.5, 1)
camButton.Size = UDim2.fromOffset(40, 40)
camButton.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
camButton.Text = ""
camButton.Visible = false
camButton.Parent = camGui
do
	(Instance.new("UICorner", camButton) :: UICorner).CornerRadius = UDim.new(1, 0)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(24, 24)
	icon.Text = "🎥"
	icon.TextScaled = true
	icon.Parent = camButton
end
camButton.Activated:Connect(function()
	UiBus.StageCamTap:Fire() -- (StageCameraController: LocalPlayer attribute StageCamera on / off)
end)
local BASE_LOW = if TOUCH then 24 else 110
local function placeButton()
	local low = BASE_LOW
	local hot = playerGui:FindFirstChild("FashionHotbar")
	if hot and hot:IsA("ScreenGui") and hot.Enabled then
		local screenH = hot.AbsoluteSize.Y
		local top = math.huge
		for _, name in ipairs({ "Bar", "FoldTab" }) do
			local o = hot:FindFirstChild(name)
			if o and o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.Y > 0 and o.AbsolutePosition.Y < screenH then
				top = math.min(top, o.AbsolutePosition.Y)
			end
		end
		if top < math.huge then low = math.max(low, math.ceil(screenH - top) + 10) end
	end
	camButton.Position = UDim2.new(0.5, 0, 1, -low)
	camButton.BackgroundColor3 = if player:GetAttribute("StageCamera") == true then Color3.fromRGB(255, 110, 170) else Color3.fromRGB(60, 120, 220)
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
	local track = NeonStageConfig.track()
	local root, humanoid = rootAndHumanoid()
	local now = workspace:GetServerTimeNow()
	-- (D-1816) 오늘의 곡 도전: this player hears today's song from its own start (character attributes
	-- DanceChallenge = server time of the start, DanceChallengeTrack = its soundId, DanceScoreService)
	-- and dances it on that clock; the stage song goes on for everyone else
	local character = player.Character
	local challenge = character and character:GetAttribute("DanceChallenge")
	local challengeTrack = character and NeonStageConfig.trackById(character:GetAttribute("DanceChallengeTrack"))
	local challenging = typeof(challenge) == "number" and challengeTrack ~= nil
	if challenging then
		start, track = challenge, challengeTrack
	end
	local running = track ~= nil and typeof(start) == "number" and now >= (start :: number) - 0.05
		and now - (start :: number) < NeonStageConfig.realLength(track :: ClubConfig.Track)
	if running and track then setTrack(track) end
	-- the music on the shared clock
	local level = if running and root then NeonStageConfig.level(root.Position) else 0
	if running then
		local want = (now - (start :: number)) * playSpeed
		if not music.IsPlaying then
			music.TimePosition = math.max(0, want)
			music:Play()
		elseif math.abs(music.TimePosition - want) > 0.6 then
			music.TimePosition = math.max(0, want) -- (a new song, a restart, or this screen fell behind)
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
	if onStage and humanoid and track then
		local character = player.Character
		local still = humanoid.MoveDirection.Magnitude <= 0.1 and not humanoid.Sit and not humanoid.PlatformStand
		local menuDance = character ~= nil and character:GetAttribute("DanceKey") ~= nil
		if dancing ~= start and still and not menuDance and (not optedOut or challenging) and track.choreo then
			UiBus.ChoreoStage:Fire(track.soundId, start)
		end
	elseif dancing ~= nil then
		UiBus.ChoreoStage:Fire(nil, nil)
	end
	-- the camera button: on the stage, for a song the stage camera has shots for
	camButton.Visible = onStage and track ~= nil and ClubCamera.forTrack(track :: ClubConfig.Track) ~= nil
	if camButton.Visible then placeButton() end
end)

player.CharacterAdded:Connect(function()
	optedOut = false
	wasOnStage = false
end)
