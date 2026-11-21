--!strict
-- 안무 따라 하기 점수 "오늘의 곡 도전" (D-1816, docs/01_SYSTEMS/DANCE_SCORE.md; user 2026-11-21:
-- A 시안, 네온 무대에서). Step 1: one song (NEON), the play screen, judging and the result.
-- The daily ranking, the TOP 10 board (beach-side bus stop's back wall) and rewards come in step 2.
--
-- Notes sit on the song's beats (measured from the stage video's sound: tools/choreo, D-1816) in
-- song seconds, the clock the choreography's `at` is on (NeonStageConfig.songTime). The chart is
-- built the same way on every screen (a fixed seed per song), so the server can count the notes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

local DanceScoreConfig = {}

-- songs that can be today's song: beats (bpm, the first beat in song seconds) for the chart
-- (NEON-A2O LITE: 129.99 bpm, first beat at song -0.913; the stage video's onsets, video = song + 1.00
-- (D-898); each third of the song lands on the grid within 5 ms)
DanceScoreConfig.Songs = {
	[140713297574648] = { title = "NEON", artist = "A2O LITE", bpm = 129.99, firstBeat = -0.913 },
}
DanceScoreConfig.TodaySong = 140713297574648 -- (step 1: fixed; step 2 picks one a day at 05:00 KST)

DanceScoreConfig.CountIn = 3 -- seconds of 3 · 2 · 1 before the song starts
DanceScoreConfig.FallTime = 1.35 -- seconds a note takes from the top of its lane to the hit line
-- judging windows (real seconds from the note's time)
DanceScoreConfig.Perfect = 0.07
DanceScoreConfig.Great = 0.13
DanceScoreConfig.Late = 0.18 -- (later than this: a miss)
DanceScoreConfig.MaxScore = 100000
DanceScoreConfig.GreatShare = 0.6 -- (a Great is worth this much of a Perfect)
DanceScoreConfig.Grades = { { grade = "S", from = 0.9 }, { grade = "A", from = 0.75 }, { grade = "B", from = 0 } }

export type Note = { t: number, lane: number } -- t = song seconds; lane 1..4

-- the notes of a song: on its beats from where the choreography starts to the song's end, a rest
-- every 8th beat, lanes from a fixed walk (never the same lane three times running)
function DanceScoreConfig.chart(track: ClubConfig.Track): {Note}
	local info = DanceScoreConfig.Songs[track.soundId]
	if not info then return {} end
	local beat = 60 / info.bpm
	local first = math.huge
	for _, piece in ipairs(track.choreo or {}) do
		if typeof(piece.at) == "number" then first = math.min(first, piece.at) end
	end
	if first == math.huge then first = 0 end
	-- (notes from 4 s at the latest: NEON's choreography starts at 14.4 s, too long a wait)
	first = math.clamp(first, 1, 4)
	local length = (if typeof((track :: any).length) == "number" then (track :: any).length else 210) * ClubConfig.fileSpeed(track)
	local last = length - 2
	local notes: {Note} = {}
	local seed = track.soundId % 2147483647
	local function rand(): number
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local prev, prev2 = 0, 0
	local k = math.ceil((first - info.firstBeat) / beat)
	while true do
		local t = info.firstBeat + k * beat
		if t > last then break end
		if k % 8 ~= 7 then
			local lane = 1 + math.floor(rand() * 4)
			if lane == prev and lane == prev2 then lane = lane % 4 + 1 end
			table.insert(notes, { t = t, lane = lane })
			prev2, prev = prev, lane
		end
		k += 1
	end
	return notes
end

-- seconds a run lasts: the song's real length (Studio test: FashionGame attribute DanceScoreTestEnd =
-- seconds, to see the result screen without playing the whole song; never on live servers)
function DanceScoreConfig.runLength(track: ClubConfig.Track): number
	local NeonStageConfig = require(script.Parent:WaitForChild("NeonStageConfig")) :: any
	local length = NeonStageConfig.realLength(track)
	if game:GetService("RunService"):IsStudio() then
		local test = ReplicatedStorage:WaitForChild("FashionGame"):GetAttribute("DanceScoreTestEnd")
		if typeof(test) == "number" and test > 0 then return math.min(length, test) end
	end
	return length
end

-- score from the counts (Perfect = full share, Great = GreatShare of it)
function DanceScoreConfig.score(total: number, perfect: number, great: number): number
	if total <= 0 then return 0 end
	return math.floor(DanceScoreConfig.MaxScore * (perfect + great * DanceScoreConfig.GreatShare) / total + 0.5)
end

function DanceScoreConfig.grade(score: number): string
	local share = score / DanceScoreConfig.MaxScore
	for _, g in ipairs(DanceScoreConfig.Grades) do
		if share >= g.from then return g.grade end
	end
	return "B"
end

return DanceScoreConfig
