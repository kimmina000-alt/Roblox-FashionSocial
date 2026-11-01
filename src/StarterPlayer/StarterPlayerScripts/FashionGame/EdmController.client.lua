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
	local group = music.SoundGroup
	if group and group ~= songMute and group.Parent ~= songMute then group.Parent = songMute end
end
music:GetPropertyChangedSignal("SoundGroup"):Connect(hookGroup)
hookGroup()

-- the EDM track
local lab = EdmConfig.Track.lab
local playSpeed, octave = ClubConfig.labEffective(lab)
-- (the DJ's volume on a group of its own above the boost: one group stops at 10)
local edmVolume = make("SoundGroup", { Name = "EdmVolume", Volume = 1 }, SoundService)
local edmGroup = make("SoundGroup", { Name = "EdmTrack", Volume = lab.boost }, edmVolume)
local edm = make("Sound", {
	Name = "EdmMusic", SoundId = "rbxassetid://" .. EdmConfig.Track.soundId, Looped = true, Volume = 0, SoundGroup = edmGroup,
}, edmGroup) :: Sound
do
	local parts = if math.abs(octave - 1) < 1e-4 then {} else ClubConfig.octaveParts(octave)
	for i, part in ipairs(parts) do
		make("PitchShiftSoundEffect", { Name = "EdmPitch" .. i, Octave = part, Priority = 10 - i }, edm)
	end
	if lab.low ~= 0 or lab.mid ~= 0 or lab.high ~= 0 then
		make("EqualizerSoundEffect", { Name = "EdmEQ", LowGain = lab.low, MidGain = lab.mid, HighGain = lab.high, Priority = 20 }, edm)
	end
end

task.spawn(function()
	pcall(function() game:GetService("ContentProvider"):PreloadAsync({ edm }) end)
end)

type State = { on: boolean, speed: number, pos: number, at: number }
local state: State = { on = false, speed = 1, pos = 0, at = 0 }
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
	edmVolume.Volume = djVolume
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
