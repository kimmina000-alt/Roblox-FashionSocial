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

-- songs that can be today's song: beats (bpm, the first beat in song seconds) for the chart.
-- (D-1818x, user 2026-11-22: "내가 설정 안 해도 리듬 게임 알아서 안무 있는 곡으로 랜덤으로 달라지게") every
-- choreographed stage song, its beats measured by tools/choreo/dance_beats.py from the original mp3
-- (Shared/DanceScoreSongs, generated; NEON there: 130.007 bpm, the same grid as the stage video within
-- 0.02 s). Was only NEON by hand (129.99, -0.913, D-1816). A new choreographed song: add its mp3 to the
-- tool's SONGS and run it again.
DanceScoreConfig.MinBeatScore = 0.09 -- (a song whose onsets sit loosely on the grid is left out)
DanceScoreConfig.BeatOffset = 0 -- (seconds added to every first beat: + if hits feel early, - if late)
DanceScoreConfig.HalfTimeFrom = 150 -- (from this bpm the notes go on every other beat: 150+ is too fast)
DanceScoreConfig.Songs = {} :: {[number]: { title: string, artist: string, bpm: number, firstBeat: number }}
for id, song in pairs(require(script.Parent:WaitForChild("DanceScoreSongs")) :: any) do
	if song.score >= DanceScoreConfig.MinBeatScore then
		DanceScoreConfig.Songs[id] = { title = song.title, artist = song.artist, bpm = song.bpm,
			firstBeat = song.firstBeat + DanceScoreConfig.BeatOffset }
	end
end
DanceScoreConfig.TodaySong = 140713297574648 -- (the fallback: NEON)

-- (D-1817, step 2) the day: a KST day turning at 05:00 like the attendance event (D-1693)
function DanceScoreConfig.dayKey(serverTime: number?): string
	local t = math.floor(serverTime or workspace:GetServerTimeNow()) + 9 * 3600 - 5 * 3600
	return os.date("!%Y%m%d", t) :: string
end

-- today's song (D-1818x): a random one each day from Songs that the neon stage can play (a choreography,
-- one file), the same on every server and screen (picked from the day's key), never yesterday's again.
-- Studio test: FashionGame attribute DanceSongOverride = a soundId (Studio only).
local candidates: {number}? = nil
local function candidateIds(): {number}
	if candidates then return candidates end
	local NeonStageConfig = require(script.Parent:WaitForChild("NeonStageConfig")) :: any
	local ids = {}
	for _, track in ipairs(NeonStageConfig.tracks()) do
		if DanceScoreConfig.Songs[track.soundId] then table.insert(ids, track.soundId) end
	end
	table.sort(ids)
	candidates = ids
	return ids
end
local function dayPick(key: string, count: number): number
	-- (Random with the day as its seed: the same pick everywhere, no pattern from day to day)
	return Random.new(tonumber(key) or 0):NextInteger(1, count)
end
function DanceScoreConfig.todaySong(serverTime: number?): number
	if game:GetService("RunService"):IsStudio() then
		local test = ReplicatedStorage:WaitForChild("FashionGame"):GetAttribute("DanceSongOverride")
		if typeof(test) == "number" and DanceScoreConfig.Songs[test] then return test end
	end
	local ids = candidateIds()
	if #ids == 0 then return DanceScoreConfig.TodaySong end
	if #ids == 1 then return ids[1] end
	local t = serverTime or workspace:GetServerTimeNow()
	local i = dayPick(DanceScoreConfig.dayKey(t), #ids)
	if i == dayPick(DanceScoreConfig.dayKey(t - 86400), #ids) then i = i % #ids + 1 end
	return ids[i]
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
DanceScoreConfig.HitSound = 139362397261513 -- (D-1818h: dance_hit.wav, uploaded by the user 2026-11-21; was Crisp 8537782950)
DanceScoreConfig.PerfectSound = 8537544526
-- (D-1818g, user 2026-11-21: "사이버펑크 edm 같은 소리면 좋겠는데") our own cyberpunk stabs: tools/art/dance_sfx.py makes
-- docs/04_ART/sfx/dance_hit.wav / dance_perfect.wav / dance_hold.wav; once uploaded (Vantablack_Dev) their ids go
-- here and replace the two above (0 = not uploaded yet: the end of a hold uses PerfectSound).
-- (D-1818h) the user picked dance_hit.wav (1) as the hit sound: its id goes into HitSound once uploaded
DanceScoreConfig.HoldSound = 0
-- (D-1818g, user 2026-11-21: "버튼 타이밍 맞춰서 눌렀을 때만 음량 잠깐 키우는 건") a hit swells the song for a moment
-- (dB on every band of an EqualizerSoundEffect on the stage Sound)
-- (D-1818k, user 2026-11-21: "기계음 삭제하고 그 순간 1초씩 음량 2배 키우기로 변경") the hit sounds are gone (the ids
-- above are kept, unused); a hit makes the song twice as loud (+6 dB = 2 x amplitude) for 1 s from that hit
-- (D-1818q, user 2026-11-21: "효과음 빼고 성공하는 순간 딜레이 없이 바로 0.5초 볼륨 5배 키우기") 5 x = +13.98 dB for 0.5 s
-- (D-1818r, user 2026-11-21: "볼륨 5배 삭제") no swell any more (0 dB; set a number here to bring it back)
DanceScoreConfig.HitSwellPerfect = 0
DanceScoreConfig.HitSwellGreat = 0
DanceScoreConfig.HitSwellTime = 0.5
-- (D-1818m, user 2026-11-21: "6 빼고 3 5 7 8 차례대로 버튼 네 개에 하나씩 적용") a hit plays its button's own 0.5 s
-- EDM sound (tools/art/edm_half.py, docs/04_ART/sfx): 1 ◀/A = edm_3_wobble_half, 2 ▼/S = edm_5_stab,
-- 3 ▲/D = edm_7_808, 4 ▶/F = edm_8_pump. Upload them (Vantablack_Dev) and put the ids here (0 = silent)
-- (D-1818o, user 2026-11-21: "a d: 5 / s f: 7") A and D = edm_5_stab, S and F = edm_7_808 (the wobble
-- 125197725220519 and the pump 116720116970109 are uploaded but unused)
-- (D-1818p, user 2026-11-21: "7번으로 모두 통일") every button = edm_7_808
-- (D-1818q, user 2026-11-21: "효과음 빼고") no button sounds (808 140128383020491 kept here for later)
-- (D-1818r, user 2026-11-21: "edm 5를 볼륨 반으로 줄여서 4개 키에 넣어 봐") every button = edm_5_stab at half volume
-- (D-1818t, user 2026-11-21: "볼륨 그대로 7번으로 바꾸고") every button = edm_7_808, volume as it was
-- (D-1818u, user 2026-11-21: "5번으로 하고 소리 반으로 더 줄여 봐") back to edm_5_stab, volume 0.15 → 0.075
DanceScoreConfig.LaneSounds = { 76294360258700, 76294360258700, 76294360258700, 76294360258700 }
-- (D-1818v, user 2026-11-21: "줄인 거에서 반만 더 키우고") 0.075 x 1.5
DanceScoreConfig.LaneSoundVolume = 0.1125 -- (D-1818r: half of 0.6; D-1818s, user 2026-11-21: "지금 상태에서 절반으로 더")
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
-- (D-1818g, user 2026-11-21: "난이도도 조금만 더 올리자") a little harder: in about 4 bars of 10 one more note on a
-- half beat (an 8th, on the other thumb's side: 1-2 = left thumb, 3-4 = right thumb).
-- (D-1818k, user 2026-11-21: "꾹 눌러야 하는 버튼 삭제") no held notes any more (the controller still draws one if
-- a chart has `hold`)
function DanceScoreConfig.chart(track: ClubConfig.Track): {Note}
	local info = DanceScoreConfig.Songs[track.soundId]
	if not info then return {} end
	local beat = 60 / info.bpm
	if info.bpm >= DanceScoreConfig.HalfTimeFrom then beat *= 2 end -- (D-1818x: a note every other beat)
	local first = math.huge
	for _, piece in ipairs(track.choreo or {}) do
		-- (D-1818x: some songs list plain animation ids, with no `at`)
		if typeof(piece) == "table" and typeof(piece.at) == "number" then first = math.min(first, piece.at) end
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
	local eighthAt = -1
	local k = math.ceil((first - info.firstBeat) / beat)
	while true do
		local t = info.firstBeat + k * beat
		if t > last then break end
		local pos = k % 8
		if pos == 0 or eighthAt == -1 then
			eighthAt = if rand() < 0.4 then (if rand() < 0.5 then 2 else 5) else -2
		end
		if pos ~= 7 then
			local lane = 1 + math.floor(rand() * 4)
			if lane == prev and lane == prev2 then lane = lane % 4 + 1 end
			table.insert(notes, { t = t, lane = lane })
			prev2, prev = prev, lane
			local half = t + beat / 2
			if pos == eighthAt and half <= last then
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
