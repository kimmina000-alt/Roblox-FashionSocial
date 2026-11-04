-- JoinedSongPlayer (user 2026-11-03): plays one song that was uploaded as
-- several clips, as one song. The clips come from
-- tools/audio/split_for_crossfade.ps1: clip n = `segLen` seconds from
-- (n − 1) × segLen plus the next clip's first `tail` seconds. Two Sounds
-- take turns: at each joint the next clip starts `tail − overlap` in (plus a
-- small lead, a Sound sits still about 0.06 s after Play) and the two cross
-- over `overlap` seconds on straight lines, so the shared sound lines up.
-- Measured in the turntable lab: the 8-clip test song played 225.16 s for
-- 225.05 s, each joint within 0.07 s.
--
-- Song (one entry of a song list):
--   { title = "…", joined = { parts = { id1, id2, … }, segLen = 30, tail = 4, total = 225.05, lead = 0.05 },
--     lab = { speed, tempo, volume, boost, octave, low, mid, high } }  -- lab optional
-- `lead` (optional, default 0.05) is the length match: play the whole song,
-- and if it ran longer than `total` by d seconds, add d ÷ (clips − 1) to it
-- (shorter: take it off), so the heard length equals the original.
-- `lab` works as in the turntable lab: real speed = speed × tempo, the pitch
-- brought back by PitchShift (octave ÷ tempo), Sound.Volume = volume, a
-- SoundGroup × boost, EQ in dB. Without `lab`: x1 and volume 10.
--
-- Use:
--   local player = JoinedSongPlayer.new(parent)   -- parent of its Sounds (default SoundService)
--   player:Load(song)
--   player:Play(atSeconds)        -- song seconds (x1 time), default 0; also to jump
--   player:Pause() / player:Resume() / player:Stop()
--   player:GetTime(), player:GetLength(), player:IsPlaying(), player:GetPart()
--   player:SetLab(lab)            -- change the sound while it plays
--   player:SetLevel(0..1)         -- an extra volume factor (zone fade, DJ volume)
--   player.Ended = function() end -- called after the last clip
--   player:Destroy()
-- To keep players in step (a club), Play(elapsedRealSeconds × realSpeed).
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local JoinedSongPlayer = {}
JoinedSongPlayer.__index = JoinedSongPlayer

local DEFAULT_LAB = { speed = 1, tempo = 1, volume = 10, boost = 1, octave = 1, low = 0, mid = 0, high = 0 }
local OVERLAP = 2 -- seconds of real time the two clips play together
local LEAD = 0.05 -- seconds the next clip starts further in

local function octaveParts(t: number): {number}
	if t >= 0.5 and t <= 2 then return { t } end
	local n = math.clamp(math.ceil(math.abs(math.log(t, 2)) - 1e-6), 1, 5)
	local part = t ^ (1 / n)
	local list = {}
	for i = 1, n do list[i] = part end
	return list
end

-- real playback speed and the octave left after making up for the tempo
local function effective(v: any): (number, number)
	local playSpeed = math.min(v.speed * v.tempo, 20)
	return playSpeed, math.clamp(v.octave / (playSpeed / v.speed), 1 / 32, 32)
end

local function makeDeck(parent: Instance, name: string): any
	local group = Instance.new("SoundGroup")
	group.Name = name .. "Boost"
	group.Parent = parent
	local s = Instance.new("Sound")
	s.Name = name
	s.Looped = false
	s.SoundGroup = group
	s.Parent = parent
	local fxs = {}
	for i = 1, 5 do
		local fx = Instance.new("PitchShiftSoundEffect")
		fx.Priority = i
		fx.Enabled = false
		fx.Parent = s
		fxs[i] = fx
	end
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Priority = 10
	eq.Enabled = false
	eq.Parent = s
	return { snd = s, group = group, shifters = fxs, eq = eq, gain = 1, part = 0 }
end

function JoinedSongPlayer.new(parent: Instance?): any
	local folder = Instance.new("Folder")
	folder.Name = "JoinedSong"
	folder.Parent = parent or SoundService
	local self = setmetatable({
		folder = folder,
		decks = { makeDeck(folder, "ClipA"), makeDeck(folder, "ClipB") },
		cur = 1, -- index of the deck that plays
		song = nil :: any,
		lab = DEFAULT_LAB,
		level = 1,
		playing = false,
		fading = nil :: any,
		token = 0,
		Ended = nil :: (() -> ())?,
	}, JoinedSongPlayer)
	self.decks[2].gain = 0
	self.conn = RunService.Heartbeat:Connect(function(dt) self:_step(dt) end)
	return self
end

function JoinedSongPlayer:_apply(d: any)
	local v = self.lab
	local playSpeed, octave = effective(v)
	d.snd.PlaybackSpeed = playSpeed
	d.snd.Volume = math.min(v.volume * d.gain * self.level, 10)
	d.group.Volume = v.boost
	local parts = if math.abs(octave - 1) < 1e-4 then {} else octaveParts(octave)
	for i, fx in ipairs(d.shifters) do
		fx.Octave = parts[i] or 1
		fx.Enabled = parts[i] ~= nil
	end
	d.eq.LowGain, d.eq.MidGain, d.eq.HighGain = v.low, v.mid, v.high
	d.eq.Enabled = v.low ~= 0 or v.mid ~= 0 or v.high ~= 0
end

function JoinedSongPlayer:_load(d: any, part: number)
	local parts = self.song.joined.parts
	d.part = part
	d.snd:Stop()
	if parts[part] then
		d.snd.SoundId = "rbxassetid://" .. tostring(parts[part])
	end
end

function JoinedSongPlayer:Load(song: any)
	self:Stop()
	self.song = song
	self.lab = song.lab or DEFAULT_LAB
	local a, b = self.decks[self.cur], self.decks[3 - self.cur]
	self:_load(a, 1)
	self:_load(b, 2)
	a.gain, b.gain = 1, 0
	self:_apply(a)
	self:_apply(b)
end

function JoinedSongPlayer:SetLab(lab: any)
	self.lab = lab or DEFAULT_LAB
	for _, d in ipairs(self.decks) do self:_apply(d) end
end

function JoinedSongPlayer:SetLevel(level: number)
	self.level = level
	for _, d in ipairs(self.decks) do self:_apply(d) end
end

function JoinedSongPlayer:GetLength(): number
	return if self.song then self.song.joined.total else 0
end

function JoinedSongPlayer:GetPart(): number
	return self.decks[self.cur].part
end

-- song seconds (x1 time): the clip's start plus where the playing deck is
function JoinedSongPlayer:GetTime(): number
	if not self.song then return 0 end
	local d = self.decks[self.cur]
	return (d.part - 1) * self.song.joined.segLen + d.snd.TimePosition
end

function JoinedSongPlayer:IsPlaying(): boolean
	return self.playing
end

-- start (or jump) at song second `at`
function JoinedSongPlayer:Play(at: number?)
	local song = self.song
	if not song then return end
	self:_cancelFade()
	local j = song.joined
	at = math.clamp(at or 0, 0, math.max(j.total - 0.05, 0))
	local part = math.min(math.floor(at / j.segLen) + 1, #j.parts)
	local d = self.decks[self.cur]
	if d.part ~= part then self:_load(d, part) end
	local other = self.decks[3 - self.cur]
	if other.part ~= part + 1 then self:_load(other, part + 1) end
	d.gain, other.gain = 1, 0
	self:_apply(d)
	self:_apply(other)
	self.token += 1
	local my = self.token
	self.playing = true
	self.started = false -- true once the clip really plays (for the end check)
	task.spawn(function()
		local t0 = os.clock()
		while not d.snd.IsLoaded and os.clock() - t0 < 8 do task.wait(0.05) end
		if my ~= self.token then return end
		d.snd.TimePosition = at - (part - 1) * j.segLen
		d.snd:Play()
		self.started = true
	end)
end

function JoinedSongPlayer:Pause()
	self:_cancelFade()
	self.token += 1
	self.playing = false
	self.decks[self.cur].snd:Pause()
end

function JoinedSongPlayer:Resume()
	if not self.song then return end
	self.playing = true
	self.decks[self.cur].snd:Resume()
end

function JoinedSongPlayer:Stop()
	self:_cancelFade()
	self.token += 1
	self.playing = false
	for _, d in ipairs(self.decks) do d.snd:Stop() end
end

function JoinedSongPlayer:_cancelFade()
	local f = self.fading
	if not f then return end
	self.fading = nil
	f.to.snd:Stop()
	f.to.gain, f.from.gain = 0, 1
	self:_apply(f.from)
	self:_apply(f.to)
end

-- one Heartbeat: start a joint when the clip nears its end, run the fade,
-- swap the decks when it is over, and notice the end of the song
function JoinedSongPlayer:_step(dt: number)
	if not self.playing or not self.song then return end
	local j = self.song.joined
	local f = self.fading
	if f then
		local x = math.clamp((os.clock() - f.t0) / f.len, 0, 1)
		f.from.gain, f.to.gain = 1 - x, x
		self:_apply(f.from)
		self:_apply(f.to)
		if x >= 1 then
			self.fading = nil
			f.from.snd:Stop()
			self.cur = 3 - self.cur
			self:_load(f.from, f.to.part + 1) -- the free deck takes the clip after
			self:_apply(f.from)
		end
		return
	end
	local d = self.decks[self.cur]
	if not d.snd.IsPlaying then
		if self.started and d.part >= #j.parts then
			-- the last clip ran out
			self.playing = false
			if self.Ended then task.spawn(self.Ended) end
		end
		return
	end
	if d.part >= #j.parts or d.snd.TimeLength <= 0 then return end
	local playSpeed = effective(self.lab)
	local overlap = math.min(OVERLAP, j.tail / playSpeed)
	local left = (d.snd.TimeLength - d.snd.TimePosition) / playSpeed
	local nextDeck = self.decks[3 - self.cur]
	if left <= overlap + dt and nextDeck.snd.IsLoaded then
		nextDeck.gain = 0
		self:_apply(nextDeck)
		nextDeck.snd.TimePosition = math.max(0, j.tail - overlap * playSpeed) + (j.lead or LEAD) * playSpeed
		nextDeck.snd:Play()
		self.fading = { t0 = os.clock(), len = overlap, from = d, to = nextDeck }
	end
end

function JoinedSongPlayer:Destroy()
	self:Stop()
	if self.conn then self.conn:Disconnect() end
	self.folder:Destroy()
end

return JoinedSongPlayer
