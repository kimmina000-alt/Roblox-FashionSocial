--!strict
-- DJ EDM effects on every client (D-733, Shared/EdmConfig, server EdmService).
-- Reads the FashionGame attribute ClubEdm and works on the club music Sound
-- (DanceController's "ClubMusic"):
--   - an EQ of its own for the bass: cut away during a build-up, a little extra
--     on the drop (the DJ's filter / bass / flanger sliders are gone, D-734)
--   - echo (half a beat)
--   - pump: the song's SoundGroup sits in a group of ours whose volume dips on
--     every beat
--   - kick and hi-hats: one-shot sounds on the beat, as loud as the music is here
-- The beat: the DJ's kick tempo, else EdmConfig.Bpm[soundId] (the DJ's speed
-- carries over), counted from the song's start (ClubTrackStart).

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

-- effects on the song (after DanceController's own: higher Priority runs first)
local bassEq = make("EqualizerSoundEffect", { Name = "EdmBass", LowGain = 0, MidGain = 0, HighGain = 0, Enabled = false, Priority = 29 }, music)
local echo = make("EchoSoundEffect", { Name = "EdmEcho", Delay = 0.25, Feedback = 0.35, WetLevel = -6, DryLevel = 0, Enabled = false, Priority = 27 }, music)

-- pump: our group above the song's own group (nested SoundGroups multiply)
local pumpGroup = make("SoundGroup", { Name = "EdmPump", Volume = 1 }, SoundService)
local function hookGroup()
	local group = music.SoundGroup
	if group and group ~= pumpGroup and group.Parent ~= pumpGroup then group.Parent = pumpGroup end
end
music:GetPropertyChangedSignal("SoundGroup"):Connect(hookGroup)
hookGroup()

-- drums (not ducked by the pump)
local drumGroup = make("SoundGroup", { Name = "EdmDrums", Volume = 1 }, SoundService)
local function oneShot(id: number, name: string): Sound
	return make("Sound", { Name = name, SoundId = "rbxassetid://" .. id, SoundGroup = drumGroup, Volume = 0 }, drumGroup)
end
local kicks = { oneShot(EdmConfig.Sounds.kick, "Kick1"), oneShot(EdmConfig.Sounds.kick, "Kick2") }
local hats = { oneShot(EdmConfig.Sounds.hat, "Hat1"), oneShot(EdmConfig.Sounds.hat, "Hat2") }
local riser = oneShot(EdmConfig.Sounds.riser, "Riser")
local kickTurn, hatTurn = 1, 1
local function hit(list: {Sound}, turn: number, volume: number): number
	local s = list[turn]
	s.Volume = volume
	s.TimePosition = 0
	s:Play()
	return turn % #list + 1
end

type State = { kick: boolean, pump: boolean, echo: boolean, bpm: number?, dropAt: number? }
local state: State = { kick = false, pump = false, echo = false }
local function read()
	local raw = FashionGame:GetAttribute("ClubEdm")
	if typeof(raw) ~= "string" then return end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and typeof(decoded) == "table" then state = decoded :: any end
end
FashionGame:GetAttributeChangedSignal("ClubEdm"):Connect(read)
read()

local function num(name: string, default: number): number
	local v = FashionGame:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- beat length in server seconds and the server time of a beat
local function beat(): (number, number)
	local anchor = num("ClubTrackStart", 0)
	if state.bpm then return 60 / state.bpm, anchor end -- (the DJ's kick tempo, as heard)
	local track = ClubConfig.Playlist[num("ClubTrack", 0)]
	local bpm = (track and EdmConfig.Bpm[track.soundId]) or EdmConfig.Default
	return 60 / (bpm * num("ClubMusicSpeed", 1)), anchor
end

local lastBeat, lastHalf, lastRoll = -1, -1, -1
local riserFor = 0 -- the dropAt the riser was started for
local dropHitFor = 0

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local playing = music.IsPlaying and music.Volume > 0 and FashionGame:GetAttribute("ClubMusicPaused") ~= true
	local level = math.clamp(music.Volume / 10, 0, 1)
	local period, anchor = beat()
	local t = (now - anchor) / period
	local index = math.floor(t)
	local frac = t - index

	-- build-up and drop
	local dropAt = state.dropAt
	local building, dropped = false, false
	local buildProgress = 0
	if typeof(dropAt) == "number" then
		local buildStart = dropAt - period * EdmConfig.BuildBeats
		if now >= buildStart and now < dropAt then
			building = true
			buildProgress = (now - buildStart) / (dropAt - buildStart)
			if riserFor ~= dropAt and playing then
				riserFor = dropAt
				riser.Volume = EdmConfig.Volumes.riser * level
				riser.PlaybackSpeed = math.clamp((riser.TimeLength > 0 and riser.TimeLength or 6) / (dropAt - now), 0.5, 2)
				riser.TimePosition = 0
				riser:Play()
			end
		elseif now >= dropAt and now < dropAt + period * EdmConfig.DropBeats then
			dropped = true
			if dropHitFor ~= dropAt then
				dropHitFor = dropAt
				riser:Stop()
				if playing then kickTurn = hit(kicks, kickTurn, EdmConfig.Volumes.kick * 1.6 * level) end
			end
		end
	end

	-- (a drop switched off part way: the riser stops too)
	if not building and riser.IsPlaying then riser:Stop() end
	-- bass: cut away while building, a little extra on the drop
	local low = if building then -40 * buildProgress elseif dropped then 4 else 0
	bassEq.LowGain = low
	bassEq.Enabled = math.abs(low) > 0.1
	echo.Enabled = state.echo == true
	echo.Delay = math.clamp(period / 2, 0.05, 1)

	-- pump
	local pumping = (state.pump == true or dropped) and playing
	pumpGroup.Volume = if pumping then 1 - EdmConfig.PumpDepth * math.exp(-frac * 6) else 1

	-- drums
	local kickOn = (state.kick == true or dropped) and playing and not building
	if index ~= lastBeat then
		lastBeat = index
		-- (the drop's own big kick is this beat's kick)
		local dropBeat = dropped and typeof(dropAt) == "number" and now - dropAt < period * 0.5
		if kickOn and not dropBeat then kickTurn = hit(kicks, kickTurn, EdmConfig.Volumes.kick * level) end
	end
	local half = math.floor(t * 2)
	if half ~= lastHalf then
		lastHalf = half
		if kickOn and half % 2 == 1 then hatTurn = hit(hats, hatTurn, EdmConfig.Volumes.hat * level) end
	end
	-- the build-up's hi-hat roll: quarter, eighth, then sixteenth notes
	if building and playing then
		local step = if buildProgress < 0.5 then 1 elseif buildProgress < 0.75 then 2 else 4
		local roll = math.floor(t * step)
		if roll ~= lastRoll then
			lastRoll = roll
			hatTurn = hit(hats, hatTurn, EdmConfig.Volumes.hat * (0.6 + buildProgress) * level)
		end
	end
end)
