-- Song loudness recorder for choreography timing (D-876, CHOREOGRAPHY.md §12).
-- Run in the CLIENT datamodel of a Play test (MCP execute_luau), once per
-- chunk: Studio MCP calls must stay under about 60 s, so set FROM / TO to
-- 0-45, 45-90, ... in turn (the bins add up in _G.cxBins between calls),
-- then set DUMP = true and run once more: it returns the envelope (the client
-- cannot send HTTP); save that text as <song>_loudness.txt.
-- Plays the club's own upload at its lab tempo (as heard in the club) and
-- bins PlaybackLoudness by the ORIGINAL song's seconds (TimePosition x file
-- speed), the clock choreography `at` values use since D-876. Compare with
-- the dance video's audio: tools/choreo/sync/align_song_video.py.

local SOUND_ID = 74988982712396
local FROM, TO = 0, 45 -- original song seconds for this call
local DUMP = false
local BIN = 0.05

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ClubConfig = require(game:GetService("ReplicatedStorage").FashionGame.Shared.ClubConfig)

local track
for _, t in ipairs(ClubConfig.Playlist) do if t.soundId == SOUND_ID then track = t end end
assert(track, "song not in ClubConfig.Playlist")
local fileSpeed = ClubConfig.fileSpeed(track)

if DUMP then
	local bins, counts = _G.cxBins or {}, _G.cxCnt or {}
	local last = 0
	for b in pairs(bins) do last = math.max(last, b) end
	local out = {}
	for b = 0, last do out[#out + 1] = if counts[b] then string.format("%.2f", bins[b] / counts[b]) else "" end
	-- the client cannot send HTTP: print it for the MCP result instead
	return string.format("bin %.2f\n", BIN) .. table.concat(out, ",")
end

_G.cxBins = _G.cxBins or {}
_G.cxCnt = _G.cxCnt or {}
local sound = _G.cxSound
if not sound or sound.SoundId ~= "rbxassetid://" .. SOUND_ID then
	sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. SOUND_ID
	sound.Volume = 0.3
	sound.Parent = game:GetService("SoundService")
	local t0 = os.clock()
	while not sound.IsLoaded and os.clock() - t0 < 10 do task.wait(0.1) end
	_G.cxSound = sound
end
sound.PlaybackSpeed = ClubConfig.trackRate(track, 1)
sound.TimePosition = FROM / fileSpeed
sound:Play()
while sound.IsPlaying and sound.TimePosition * fileSpeed < TO do
	RunService.RenderStepped:Wait()
	local b = math.floor(sound.TimePosition * fileSpeed / BIN)
	_G.cxBins[b] = (_G.cxBins[b] or 0) + sound.PlaybackLoudness
	_G.cxCnt[b] = (_G.cxCnt[b] or 0) + 1
end
sound:Stop()
return string.format("recorded %.0f-%.0f s (song seconds); next FROM = %.0f", FROM, TO, TO)
