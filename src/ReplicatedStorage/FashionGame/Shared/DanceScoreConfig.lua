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
DanceScoreConfig.TodaySong = 140713297574648 -- (the fallback; todaySong picks one a day from Songs)

-- (D-1817, step 2) the day: a KST day turning at 05:00 like the attendance event (D-1693)
function DanceScoreConfig.dayKey(serverTime: number?): string
	local t = math.floor(serverTime or workspace:GetServerTimeNow()) + 9 * 3600 - 5 * 3600
	return os.date("!%Y%m%d", t) :: string
end

-- today's song: one of Songs a day, in turn (only songs with measured beats can be picked)
function DanceScoreConfig.todaySong(serverTime: number?): number
	local ids = {}
	for id in pairs(DanceScoreConfig.Songs) do table.insert(ids, id) end
	table.sort(ids)
	if #ids == 0 then return DanceScoreConfig.TodaySong end
	local t = math.floor(serverTime or workspace:GetServerTimeNow()) + 4 * 3600
	return ids[math.floor(t / 86400) % #ids + 1]
end

-- (D-1817) rewards: coins once a day for finishing a run (EconomyService.Earn, its daily cap),
-- a title for today's top 3 (player attribute Title_Dance = the rank, NameTagService)
DanceScoreConfig.ParticipationCoins = 10
DanceScoreConfig.TitleTop = 3
DanceScoreConfig.BoardRefresh = 60 -- seconds between reads of today's ranking

-- (D-1817, user 2026-11-21 via the progress session: "오늘의 곡 새로운 무대 시작 전에 '오늘의 곡에 도전하세요'
-- 화면 상단에 글씨 띄우자", then "너무 잦나") the notice at the top: once every AnnounceEvery seconds
-- (aligned to the server clock) for AnnounceSeconds, tap = the dashed way to the neon stage. Not shown
-- to anyone online under AnnounceMinOnline, who has finished a run today, in the club, on a ride / seat,
-- shooting in a photo booth, within AnnounceNear of the stage, or in a run.
DanceScoreConfig.AnnounceEvery = 15 * 60
DanceScoreConfig.AnnounceSeconds = 4
DanceScoreConfig.AnnounceMinOnline = 60
DanceScoreConfig.AnnounceNear = 48

-- (D-1818c, user 2026-11-21: "누를 때 드럼 소리 내서 흥나게", "전체 콤보 몇인지 계산해서 적당한 수 이상 콤보 찍으면 오로라
-- 추가") a kick on every hit, a snare over it on PERFECT (Creator Store: "Kick Drum" 137721550021975,
-- "INSTRUMENT Snare Drum" 127450250691379; swap the ids here); the aurora from this combo on, until a miss
-- (D-1818f, user 2026-11-21: "드럼 소리 말고 영상 속처럼 음악에 맞는 edm 느낌의 효과음") rhythm-game hit sounds instead
-- of the drums: a short crisp tick on every hit ("Note Hit Sound (Crisp)" 8537782950, 0.06 s) and a bright ping
-- over it on PERFECT ("Note Hit Sound (Ping)" 8537544526, 0.08 s); the drums were kick 137721550021975 /
-- snare 127450250691379
DanceScoreConfig.HitSound = 8537782950
DanceScoreConfig.PerfectSound = 8537544526
-- (D-1818g, user 2026-11-21: "사이버펑크 edm 같은 소리면 좋겠는데") our own cyberpunk stabs: tools/art/dance_sfx.py makes
-- docs/04_ART/sfx/dance_hit.wav / dance_perfect.wav / dance_hold.wav; once uploaded (Vantablack_Dev) their ids go
-- here and replace the two above (0 = not uploaded yet: the end of a hold uses PerfectSound)
DanceScoreConfig.HoldSound = 0
-- (D-1818g, user 2026-11-21: "버튼 타이밍 맞춰서 눌렀을 때만 음량 잠깐 키우는 건") a hit swells the song for a moment
-- (dB on every band of an EqualizerSoundEffect on the stage Sound, back to 0 over HitSwellTime seconds)
DanceScoreConfig.HitSwellPerfect = 4
DanceScoreConfig.HitSwellGreat = 2.5
DanceScoreConfig.HitSwellTime = 0.22
function DanceScoreConfig.auroraCombo(total: number): number
	-- 15 % of the song's notes, in tens, at least 30 (NEON: 409 notes → 60)
	return math.max(30, math.floor(total * 0.15 / 10 + 0.5) * 10)
end

-- (D-1818d, user 2026-11-21: "콤보 단계별 오로라 차별화 점점 화려하게 남들에게도 보이게") the aurora in steps: level 1
-- from auroraCombo, 2 from twice it, 3 from three times it (NEON: 60 / 120 / 180)
function DanceScoreConfig.auroraLevel(combo: number, total: number): number
	local step = DanceScoreConfig.auroraCombo(total)
	return math.clamp(math.floor(combo / step), 0, 3)
end

-- (D-1818d, user 2026-11-21: "시작하기 전 카운트 셀 때 띠 띠 띠 하는 대표적인 카운트 효과음") 3 · 2 · 1 and a higher
-- one at the start (Creator Store "Countdown beep" 117751546358455)
DanceScoreConfig.CountBeep = 117751546358455

-- (D-1818d, user 2026-11-21: "순위표에 최대 콤보 수 표시") the ranking keeps the best combo with the score:
-- stored as score * 1000 + combo (combo up to 999), so the order is by score and then combo
function DanceScoreConfig.pack(score: number, combo: number): number
	return math.floor(score) * 1000 + math.clamp(math.floor(combo), 0, 999)
end
function DanceScoreConfig.unpack(value: number): (number, number)
	return math.floor(value / 1000), value % 1000
end

DanceScoreConfig.CountIn = 3 -- seconds of 3 · 2 · 1 before the song starts
DanceScoreConfig.FallTime = 1.35 -- seconds a note takes from the top of its lane to the hit line
-- judging windows (real seconds from the note's time)
DanceScoreConfig.Perfect = 0.07
DanceScoreConfig.Great = 0.13
DanceScoreConfig.Late = 0.18 -- (later than this: a miss)
DanceScoreConfig.MaxScore = 100000
DanceScoreConfig.GreatShare = 0.6 -- (a Great is worth this much of a Perfect)
DanceScoreConfig.Grades = { { grade = "S", from = 0.9 }, { grade = "A", from = 0.75 }, { grade = "B", from = 0 } }

export type Note = { t: number, lane: number, hold: number? } -- t = song seconds; lane 1..4; hold = song second
-- a held note ends (press at t, keep pressing until hold)

-- the notes of a song: on its beats from where the choreography starts to the song's end, a rest
-- every 8th beat, lanes from a fixed walk (never the same lane three times running).
-- (D-1818g, user 2026-11-21: "난이도도 조금만 더 올리자 꾹 누르는 부분도 만들고") a little harder: in about 4 bars of 10
-- one more note on a half beat (an 8th, on the other thumb's side), and every 4th bar a held note from
-- beat 2 for two beats; while it is held the other notes go to the other thumb's two lanes (1-2 = left
-- thumb, 3-4 = right thumb, on phones held flat and upright alike)
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
	local function otherSide(lane: number): number
		return (if lane <= 2 then 3 else 1) + math.floor(rand() * 2)
	end
	local prev, prev2 = 0, 0
	local holdUntil, holdLane = -math.huge, 0
	local eighthAt = -1
	local k = math.ceil((first - info.firstBeat) / beat)
	while true do
		local t = info.firstBeat + k * beat
		if t > last then break end
		local pos = k % 8
		local bar = k // 8
		if pos == 0 or eighthAt == -1 then
			eighthAt = if rand() < 0.4 then (if rand() < 0.5 then 2 else 5) else -2
		end
		if pos ~= 7 then
			local lane = 1 + math.floor(rand() * 4)
			if lane == prev and lane == prev2 then lane = lane % 4 + 1 end
			if t < holdUntil then lane = otherSide(holdLane) end
			local note: Note = { t = t, lane = lane }
			if bar % 4 == 2 and pos == 1 and t + 2 * beat <= last then
				note.hold = t + 2 * beat
				holdUntil, holdLane = t + 2 * beat + 0.05, lane
			end
			table.insert(notes, note)
			prev2, prev = prev, lane
			local half = t + beat / 2
			if pos == eighthAt and half <= last and half >= holdUntil then
				local extra = otherSide(lane)
				table.insert(notes, { t = half, lane = extra })
				prev2, prev = prev, extra
			end
		end
		k += 1
	end
	return notes
end

-- judged notes in a chart: one per note, two per held note (pressed in time, kept to the end)
function DanceScoreConfig.noteCount(notes: {Note}): number
	local n = #notes
	for _, note in ipairs(notes) do
		if note.hold then n += 1 end
	end
	return n
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
