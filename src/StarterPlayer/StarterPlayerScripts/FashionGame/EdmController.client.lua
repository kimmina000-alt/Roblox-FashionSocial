--!strict
-- The DJ's EDM button on every client (D-733 → D-735; Shared/EdmConfig,
-- server EdmService). Reads the FashionGame attribute ClubEdm:
--   on   the EDM track plays together with the club song (D-736; instead of it
--        in D-735), looped, as loud as the song is here
-- A SoundGroup of ours above the song's own group carries the DJ's volume for
-- lab tracks (a group stops at 10 and their boost is 6).
--   speed / pos / at   where the EDM track is and how fast it runs
-- The EDM track's own sound (speed × tempo, octave, EQ, boost) works like a
-- lab track in the playlist (ClubConfig.labEffective / octaveParts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local EdmConfig = require(Shared:WaitForChild("EdmConfig"))
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))

local music = player:WaitForChild("PlayerScripts"):WaitForChild("FashionGame"):WaitForChild("DanceController"):WaitForChild("ClubMusic") :: Sound

local function make(className: string, props: {[string]: any}, parent: Instance): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

-- our group above the song's own (nested SoundGroups multiply): the DJ's volume
local songMute = make("SoundGroup", { Name = "EdmSongMute", Volume = 1 }, SoundService)
local function hookGroup()
	-- (D-892) the top of the song's own chain of groups (DanceController:
	-- ClubMusicBoost under ClubMusicBoost2, under ClubMusicBoost3 and
	-- ClubMusicBoost4 since D-933 / D-934), so the chain stays whole: the loop
	-- climbs to the top group, whatever its name
	local group = music.SoundGroup
	while group and group.Parent and group.Parent:IsA("SoundGroup") and group.Parent ~= songMute do
		group = group.Parent :: SoundGroup
	end
	if group and group ~= songMute and group.Parent ~= songMute then group.Parent = songMute end
end
music:GetPropertyChangedSignal("SoundGroup"):Connect(hookGroup)
hookGroup()

-- the EDM tracks (EdmConfig.Tracks, D-759: three, one plays at a time), each
-- its own Sound in its own group (its boost)
-- (the DJ's volume on a group of its own above the boost: one group stops at 10)
local edmVolume = make("SoundGroup", { Name = "EdmVolume", Volume = 1 }, SoundService)
type Edm = { sound: Sound, playSpeed: number }
local edms: {Edm} = {}
for i, spec in ipairs(EdmConfig.Tracks) do
	local lab = spec.lab
	local playSpeed, octave = ClubConfig.labEffective(lab)
	local group = make("SoundGroup", { Name = "EdmTrack" .. i, Volume = lab.boost }, edmVolume)
	local sound = make("Sound", {
		Name = "EdmMusic" .. i, SoundId = "rbxassetid://" .. spec.soundId, Looped = true, Volume = 0, SoundGroup = group,
	}, group) :: Sound
	local parts = if math.abs(octave - 1) < 1e-4 then {} else ClubConfig.octaveParts(octave)
	for n, part in ipairs(parts) do
		make("PitchShiftSoundEffect", { Name = "EdmPitch" .. n, Octave = part, Priority = 10 - n }, sound)
	end
	if lab.low ~= 0 or lab.mid ~= 0 or lab.high ~= 0 then
		make("EqualizerSoundEffect", { Name = "EdmEQ", LowGain = lab.low, MidGain = lab.mid, HighGain = lab.high, Priority = 20 }, sound)
	end
	edms[i] = { sound = sound, playSpeed = playSpeed }
end

task.spawn(function()
	local list = {}
	for _, e in ipairs(edms) do table.insert(list, e.sound) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)

type State = { on: boolean, track: number?, speed: number, pos: number, at: number }
local state: State = { on = false, track = 1, speed = 1, pos = 0, at = 0 }
FashionGame:GetAttributeChangedSignal("ClubEdm"):Connect(function()
	local raw = FashionGame:GetAttribute("ClubEdm")
	if typeof(raw) ~= "string" then return end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and typeof(decoded) == "table" then state = decoded :: any end
end)
do
	local raw = FashionGame:GetAttribute("ClubEdm")
	if typeof(raw) == "string" then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and typeof(decoded) == "table" then state = decoded :: any end
	end
end

RunService.Heartbeat:Connect(function()
	local pick = edms[if typeof(state.track) == "number" then state.track else 1] or edms[1]
	-- (only the picked track plays)
	for _, e in ipairs(edms) do
		if e ~= pick and e.sound.IsPlaying then e.sound:Stop() end
	end
	if not pick then return end
	local edm, playSpeed = pick.sound, pick.playSpeed
	local on = state.on == true and edm.IsLoaded and edm.TimeLength > 0
	-- the DJ's volume (ClubMusicVolume): here for lab tracks and the EDM track,
	-- DanceController does the other songs (their Sound is below 10)
	local djVolume = FashionGame:GetAttribute("ClubMusicVolume")
	djVolume = if typeof(djVolume) == "number" then djVolume else 1
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	-- (D-736, user: the EDM track plays together with the song, not instead)
	songMute.Volume = if track and track.lab then djVolume else 1
	if not on then
		if edm.IsPlaying then edm:Stop() end
		return
	end
	-- (D-764) the EDM track's own volume on top of the DJ's song volume
	edmVolume.Volume = djVolume * (if typeof(state.volume) == "number" then state.volume else EdmConfig.EdmVolumeDefault or 1)
	edm.Volume = music.Volume -- (the song's level here: zones, the photo booth's mute)
	local speed = if typeof(state.speed) == "number" then state.speed else 1
	edm.PlaybackSpeed = playSpeed * speed
	local heard = (state.pos or 0) + (workspace:GetServerTimeNow() - (state.at or 0)) * speed
	local want = (heard * playSpeed) % edm.TimeLength
	if not edm.IsPlaying then
		edm.TimePosition = want
		edm:Play()
	elseif math.abs(edm.TimePosition - want) > 0.35 and math.abs(edm.TimePosition - want) < edm.TimeLength - 0.35 then
		edm.TimePosition = want
	end
end)
