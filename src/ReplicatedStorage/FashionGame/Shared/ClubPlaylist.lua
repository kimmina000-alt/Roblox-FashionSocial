--!strict
-- (D-888, user 2026-11-05: ClubConfig split up, one file per kind) Club music: track types, the saved lab values and the playlist (the user's own uploads at the end).
-- ClubConfig re-exports every field below, so ClubConfig.Playlist keeps working.

export type Track = {
	channel: string,
	title: string,
	soundId: number,
	length: number, -- seconds of audio at x1
	baseSpeed: number?, -- its normal playback speed (default 1)
	volume: number?, -- its own music volume instead of MusicVolume (past 10: an equalizer boost)
	octave: number?, -- a PitchShiftSoundEffect octave on it (1 = none)
	-- the values the user tuned by ear in the turntable lab (test place
	-- 86558282086977, tools/test_places/turntable_lab, DataStore
	-- TurntableLabSettings "v1"; D-680). When set it replaces baseSpeed /
	-- volume / octave. humHz / hissHz / gate only work on the lab's "audio"
	-- engine and are kept for the record; the club plays a Sound.
	lab: Lab?,

	-- (joined songs) one song uploaded as several clips, played as one by
	-- Shared/JoinedSongPlayer; soundId = the first clip, length = joined.total
	joined: Joined?,

	fileSpeed: number?, -- how much faster than the original the uploaded file is (D-876; uploads 3)
	-- the song's choreography (D-689): animation ids played one after another
	-- from the start of the song, each danced to the song as heard in the club
	-- (so at x1; the DJ's speed carries over). Players in the club get a
	-- "안무 따라하기" button while it plays (ChoreoController). An entry is an
	-- animation id (it starts where the one before ends) or { id = .., at = .. }
	-- (it starts `at` seconds into the song, as heard in the club). `stop` (D-804)
	-- ends that one early, `stop` seconds into the song: the dancer stands still
	-- and the next one starts on time, as if this one had played to its end.
	-- `blend` (D-807) = seconds to ease into this one from the pose before
	-- (0.25 if not given; tools/choreo/choreo_check.lua suggests it).
	-- `from` (D-810) = seconds into the animation to start from (skips its
	-- start; with `stop` on the entry before, this cuts a stretch out).
	choreo: {any}?,
	-- (D-726) dance the choreography by itself: everyone in the club standing
	-- still (not seated, not in a menu dance) follows it while the song plays
	autoChoreo: boolean?,
}
export type Lab = {
	speed: number, tempo: number, volume: number, boost: number, octave: number,
	low: number, mid: number, high: number,
	humHz: number?, hissHz: number?, gate: number?, engine: string?,
	-- (D-892) a second SoundGroup above `boost`, 0..10 per song: heard =
	-- boost × boost2 (each group stops at 10). Left out: 1, or for a joined
	-- song with boost over 10, boost ÷ 10 (D-891)
	boost2: number?,
}

export type Joined = { parts: {number}, segLen: number, tail: number, total: number, lead: number? }

local M = {}

-- (D-745, user: "숨겨 놔, 나중에 쓸 거임") the lab values the user tuned by ear
-- for their own sped-up uploads (docs/04_ART/OLD_CLUB_PLAYLIST.md). Used again
-- by the user's K-POP uploads since D-755.
-- (D-765, user 2026-11-03: boost 3, no EQ; was boost 6, low -6 / mid 0.5 / high -7)
M.SavedLabs = {
	userUpload = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" },
} :: {[string]: Lab}
local UP = M.SavedLabs.userUpload

-- Shared club music. One track plays for everyone; the channel name is shown.
-- (user 2026-11-02, D-739: only Roblox's own licensed music — DistroKid on the
-- Creator Store, offered by Roblox — every K-POP upload before taken out; the
-- Bubble Pop / Get A Guitar choreographies went with them; D-755: the user's
-- K-POP uploads back after them, with the saved lab values.)
-- (D-745, user: default sound, no lab values: they play as uploaded at
-- ClubConfig.MusicVolume, the DJ's 🔊 slider on top)
M.Playlist = {
	{ channel = "K-POP", title = "K-Pop Party", soundId = 135361546383974, length = 145 },
	{ channel = "K-POP", title = "K-pop Cute Crush", soundId = 121416896999522, length = 108 },
	{ channel = "K-POP", title = "K-Pop Uprising", soundId = 72966738276299, length = 130 },
	{ channel = "K-POP", title = "Push & Pull (밀당의 고수)", soundId = 132502088493185, length = 140 },
	{ channel = "K-POP", title = "Secret Party", soundId = 75682100037866, length = 146 },
	{ channel = "K-POP", title = "Luminous Dance", soundId = 123336690588412, length = 163 },
	{ channel = "EDM", title = "LIGHT UP THE NIGHT", soundId = 102534983754242, length = 235 },
	{ channel = "EDM", title = "RUN THE NIGHT", soundId = 123336998544849, length = 218 },
	{ channel = "EDM", title = "ECHOES OF THE BASS", soundId = 134070050316863, length = 203 },
	{ channel = "DISCO", title = "Disco Inferno", soundId = 87243738678545, length = 135 },
	{ channel = "EDM", title = "Festival Fever", soundId = 136228548293465, length = 103 },
	{ channel = "EDM", title = "Euphoria Dance", soundId = 76814968175069, length = 99 },
	-- (D-755, user 2026-11-02: "음원도 추가해라", the saved lab values on all of
	-- them) the user's K-POP uploads: the 9 from before D-739 with their
	-- choreographies, and 20 new. length = seconds at x1 (heard: ÷ 0.335).
	-- (D-766: the user's per-track lab values on 10; D-767: 16 uploads taken out,
	-- 13 left)
	{ channel = "K-POP", title = "ATEEZ-BAD", soundId = 134942349436280, length = 51, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" }, choreo = {
		-- (D-844, user: 23 pieces, blends from tools/choreo/choreo_check.lua; a short
		-- piece's blend is at most half its length; 10, 12 and 17 turn (ChoreoFixes);
		-- 4, 5 and 6 captured again from the user's new clips (D-847); 21 pops its chest (ChoreoFixes);
		-- 11 skips its first 1.3 s, a spin of about 200° into place (user); the
		-- last piece runs past the song end, about 153 s heard)
		-- (D-861, user: "21번 안무가 영상보다 빠르게 나와서 노래랑 타이밍이 안 맞아 … 약
		-- 3초") each piece starts where its clip starts in the practice video
		-- (D:\Roblox\영상\ATEEZ_BAD_centercut\clips.json), less 0.16 s: the song
		-- runs 0.16 s ahead of that video (loudness envelopes matched, Studio
		-- PlaybackLoudness vs the video's audio). Run back to back, the captures
		-- (a little shorter than their clips) and 11's skipped 1.3 s had pulled
		-- 21 2.5 s and 23 2.6 s early; a short gap before the next `at` holds
		-- the last pose (ChoreoController)
		{ id = 82278370960435, from = 0.16 }, { id = 120748822938478, at = 6.6, blend = 0.9 }, { id = 110345323270713, at = 17.2, blend = 0.75 },
		{ id = 128919651219199, at = 23.44, blend = 0.9 }, { id = 82580725724862, at = 25.34, blend = 0.37 }, { id = 102168077584280, at = 32.08, blend = 0.59 },
		{ id = 122397631727855, at = 33.84, blend = 0.41 }, { id = 96766863219484, at = 39.24, blend = 0.47 }, { id = 116077835257285, at = 46.47, blend = 0.75 },
		{ id = 78517242404651, at = 58.47, blend = 0.99 }, { id = 135462564673113, at = 67.17, from = 1.3, blend = 0.45 }, { id = 130559113363194, at = 70.87, blend = 1 },
		{ id = 79303516060999, at = 72.94, blend = 0.61 }, { id = 94325256666159, at = 83.38 }, { id = 111913125032810, at = 88.24, blend = 1 },
		{ id = 129415986484255, at = 95.04, blend = 0.53 }, { id = 87606540400975, at = 103.38, blend = 1 }, { id = 121775933093308, at = 110.44, blend = 0.95 },
		{ id = 138549092776506, at = 121.91, blend = 0.73 }, { id = 88428525489460, at = 132.18 }, { id = 82346668311878, at = 136.5, blend = 0.7 },
		{ id = 134748500609652, at = 143.58 }, { id = 70571634425422, at = 151.51 } }, autoChoreo = true },
	{ channel = "K-POP", title = "소녀시대-소원을 말해봐(Genie)", soundId = 128270208751659, length = 76, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" },
		-- D-897: Genie1..26 (video = song - 13.55 s, the cover video cut the intro)
		choreo = { { id = 122991710923104, at = 13.82 }, { id = 118462778307290, at = 20.62, blend = 0.56 }, { id = 127323208506008, at = 26.83, blend = 0.53 },
		{ id = 121572726416294, at = 34.07, blend = 0.91 }, { id = 101676644495491, at = 45.32 }, { id = 105545108302127, at = 58.39 },
		{ id = 107809363798601, at = 68.14, blend = 0.52 }, { id = 97769840770691, at = 81.85, blend = 0.28 }, { id = 108803469428764, at = 93.43, blend = 0.76 },
		{ id = 76060752564499, at = 103.47, blend = 1 }, { id = 136331779515321, at = 114.18, blend = 1 }, { id = 94271336995595, at = 120.92, blend = 0.49 },
		{ id = 76687116604339, at = 132.64 }, { id = 94143895222958, at = 141.11 }, { id = 137553505478362, at = 142.41, blend = 0.58 },
		{ id = 120592352351697, at = 153.36, blend = 0.4 }, { id = 110416135198674, at = 155.43, blend = 0.52 }, { id = 124091598492660, at = 156.86, blend = 0.49 },
		{ id = 98754942494305, at = 161.5, blend = 0.6 }, { id = 105066453794976, at = 170.27, blend = 0.49 }, { id = 130670560182985, at = 171.27, blend = 0.6 },
		{ id = 125902811896005, at = 179.22, blend = 1 }, { id = 105428606733839, at = 188.56, blend = 0.84 }, { id = 127287424998997, at = 200.44, blend = 0.71 },
		{ id = 115574620758490, at = 201.47, blend = 0.48 }, { id = 127828014236660, at = 210.11, blend = 0.94 } }, autoChoreo = true },
	{ channel = "K-POP", title = "현아-Bubble Pop", soundId = 76388700698178, length = 71, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" }, choreo = { 100736920067826, 133384041896194, 83466816721074, 133279932519664, 106558407160210, 80189218624271, 74977996210534, 128213782788357, 133713883432071, 79851078896686, 85867632664929 } },
	-- (D-919, user 2026-11-06: new upload, tuned in the lab; was 91762270038050, a 3× file of 53.553 s)
	-- the new file is the same edit at 1.0908× (3 × 53.553 ÷ 147.285; loudness of both matched,
	-- same start, no drift), so `at` and the stage camera keep the old song clock
	{ channel = "K-POP", title = "RIIZE-Get A Guitar", soundId = 133586602463513, length = 147.285, fileSpeed = 1.0908, lab = { speed = 1, tempo = 0.921, volume = 10, boost = 10, boost2 = 5.05, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, choreo = {
		-- (D-807, user: "이음새도 맞춰") blend = seconds to ease from the last pose
		-- into this one, from tools/choreo/choreo_check.lua (0.25 if not given)
		-- (D-878, user: "겟어기타 안무 수정", practice video u_u21u8zIIs, mirrored
		-- to match the pieces) every piece at its start in the video - 0.08 s
		-- (the song runs 0.05-0.10 s ahead of the video, the same all through,
		-- tools/choreo/sync); run back to back they had come 0.3-1 s early, and
		-- 5's last 2.4 s repeat the start of 6, so 6-9 had come 2 s late (what
		-- the user's 1:10 cut, D-810, made up for by ear: that cut stays). 5
		-- stops where 6 starts; the 1.2 s the captures miss between 7 and 8 and
		-- the 0.9 s before 9's second part are danced slower, not stood still
		{ id = 119819611123433, at = 0.42 }, { id = 97097804325917, at = 10.19, blend = 0.7 }, { id = 119200924904137, at = 19.95, blend = 0.45 },
		{ id = 77403973851668, at = 27.49 }, { id = 73939357849033, at = 34.59, stop = 47.92, blend = 0.45 }, { id = 137390866303201, at = 47.92, blend = 0.7 },
		{ id = 121969021575883, at = 53.65, blend = 0.45, slowOut = { 1.5, 0.6 } }, { id = 92148657532352, at = 64.75, blend = 0.8, slowIn = { 1, 0.6 } },
		{ id = 96742563282745, at = 66.19, stop = 69.29, blend = 0.4 },
		{ id = 96742563282745, at = 70.18, from = 5.17, blend = 0.9, slowIn = { 1, 0.89 } }, { id = 88430566939812, at = 71.28, blend = 0.9 },
		{ id = 108795638313983, at = 80.78, blend = 0.7 }, { id = 95813030011960, at = 89.11, blend = 0.45 }, { id = 135272998171625, at = 93.08, blend = 0.4 },
		{ id = 129447992418977, at = 97.15 }, { id = 82252722293006, at = 116.21, blend = 0.55 }, { id = 108611133102309, at = 123.78 },
		{ id = 117244778152210, at = 130.88 }, { id = 113505968174557, at = 141.55 }, { id = 112498417388469, at = 149.48 },
		{ id = 80874196383963, at = 156.61, blend = 0.45 } }, autoChoreo = true }, -- (D-810, user: 2 s of 9 cut at 1:10)
	{ channel = "K-POP", title = "RIIZE-Love 119", soundId = 119473981131981, length = 58, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "YENA-Catch Catch", soundId = 80583279340768, length = 61, lab = { speed = 1, tempo = 0.34, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "Hearts2Hearts-Lemon Tang", soundId = 97032815457241, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "aespa-Lemonade", soundId = 132067415333401, length = 62, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Mirror", soundId = 139326796173276, length = 67, lab = { speed = 1, tempo = 0.332, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	-- (D-779, user 2026-11-03: new uploads "다섯시…분1102"; tempo = x1 length ÷ heard length, boost 3, -3/2/0)
	{ channel = "K-POP", title = "A2O LITE-NEON", soundId = 97511700575810, length = 74, lab = { speed = 1, tempo = 0.332, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" }, choreo = {
		-- (D-809, user: 22 pieces, blends from tools/choreo/choreo_check.lua)
		-- (D-868 → D-869, user: "서 있는 앞 3.3초 이거 안무임 다시 추가해서 수정해")
		-- the pieces were cut from the stage fancam n9HYtcN6W4w on its own clock
		-- from 0:00; the song/video offset could not be pinned down from the
		-- live audio (one bar, 1.85 s, apart candidates), so the user's own
		-- start (video 0 = song 0, piece 1 whole) stays and each piece only
		-- takes up the drift of captures shorter than their clips (0-0.53 s,
		-- found by matching limb angles to the dancers); (D-870, user: "3.3 아니었나
		-- 봐 앞에 2초 앞당기기") all 2 s earlier, 1 from its 2 s mark
		{ id = 118329772913374, from = 2 }, { id = 95449015545787, at = 14.44, blend = 0.64 }, { id = 84806571273074, at = 21.05, blend = 0.92 },
		-- (D-875, user: "1:11 그냥 멈추지 말고 앞뒤 프레임을 느리게 재생") the 1 s
		-- between 6 and 7 is filled by playing 6's last and 7's first 1.5 s at
		-- three quarters speed
		{ id = 99868719395147, at = 35.23, blend = 0.5 }, { id = 93933273398995, at = 41.89, blend = 0.96 }, { id = 128256391320572, at = 54.41, slowOut = { 1.5, 0.5 } },
		-- (D-873 → D-875, user: "1:15 0.5초 빠름", "0.5초 느리게 한 거 0.5초 더
		-- 느리게", "3:22초쯤은 2초 정도 안무가 먼저 나옴") the game's song runs
		-- 0.4 % slower than the fancam (tempo 0.332; loudness windows: video =
		-- game + 1.15 s at 1:00, 0.95 at 1:40, 0.8 at 2:25, 0.55 at 3:10), so
		-- with every piece at its video time - 2 s they came earlier and earlier:
		-- from 7 on each piece is at its video time - (1.40 - 0.0045 x video
		-- time), 7 and 8 1 s later as asked (3:22: 1.5 s later). (D-876) All `at`
		-- here are in the original song's seconds now (x 0.996, the song's
		-- clock, ClubConfig.songRate): from 7 on that is video time - 1.39 s
		-- throughout, 1-6 video time - 2 s (the user's start)
		{ id = 114466589507598, at = 72.27, blend = 0.79, slowIn = { 1.5, 0.5 } }, { id = 84027575690735, at = 81.2, blend = 0.85 }, { id = 100410498984971, at = 87.58, blend = 0.76 },
		{ id = 124518142645731, at = 93.29, blend = 0.59 }, { id = 126736648781925, at = 105.46, blend = 0.42 }, { id = 76437753036430, at = 109.92, blend = 0.56 },
		{ id = 136355327951443, at = 112.22, blend = 0.67 }, { id = 117451819045051, at = 119.49, blend = 0.47 }, { id = 111932052760637, at = 125.76, blend = 0.74 },
		{ id = 133401623277764, at = 134.3, blend = 0.7 }, { id = 96973609514230, at = 148.85, blend = 0.55 }, { id = 106546379406531, at = 164.88, blend = 1 },
		{ id = 73851407273132, at = 172.18, blend = 1 }, { id = 71570705300325, at = 180.79, blend = 1 }, { id = 121393866689759, at = 202.51, blend = 0.54 },
		{ id = 114419952125075, at = 210.11 } }, autoChoreo = true }, -- (D-795 / D-796 old single piece removed)
	{ channel = "K-POP", title = "SOYEON-퇴사할게여", soundId = 96358497474432, length = 71, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "ILLIT-체포하겠어", soundId = 139044453511745, length = 61, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" },
		-- D-914: Arrest1..21 (practice video 3nBkzv0TNDk, video = song + 2.38 s; piece 21 is the re-upload 113936517496560, the first Arrest21 upload was a copy of Arrest20)
		choreo = { { id = 110040253056586, from = 2.38 }, { id = 116782676046427, at = 11.12 }, { id = 91788521477193, at = 20.12, blend = 0.39 },
		{ id = 130744405360835, at = 26.09, blend = 0.46 }, { id = 75102459386899, at = 32.95, blend = 0.7 }, { id = 128174978668663, at = 38.69, blend = 0.61 },
		{ id = 100385332540044, at = 48.52, blend = 1 }, { id = 76359264534217, at = 51.42, blend = 0.45 }, { id = 99715197125931, at = 62.59, blend = 0.3 },
		{ id = 92743762405771, at = 76.19, blend = 0.94 }, { id = 108969470552658, at = 81.45 }, { id = 87742291719868, at = 92.75, blend = 0.87 },
		{ id = 99241032937972, at = 96.45, blend = 0.41 }, { id = 90778610748932, at = 103.62, blend = 0.94 }, { id = 119318712525281, at = 116.25, blend = 1 },
		{ id = 113529281081668, at = 123.32, blend = 0.52 }, { id = 138780635090818, at = 130.25 }, { id = 134859541553614, at = 143.45, blend = 0.52 },
		{ id = 127453915676688, at = 154.69 }, { id = 98926631193332, at = 164.52, blend = 1 }, { id = 113936517496560, at = 169.99 } }, autoChoreo = true },
	{ channel = "K-POP", title = "RESCENE-LOVE-ATTACK", soundId = 71873496902418, length = 61, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" },
		-- D-903: LoveAttack1..27 (practice video nXDQPm_HnFc, video = song + 0.45 s)
		choreo = { { id = 109011245162387, from = 0.45 }, { id = 77108502823118, at = 1.48, blend = 0.82 }, { id = 86687841705348, at = 5.12, blend = 1 },
		{ id = 131382757802821, at = 8.95, blend = 0.52 }, { id = 137275968003632, at = 10.18, blend = 0.53 }, { id = 110961201759433, at = 14.82, blend = 1 },
		{ id = 107032969312689, at = 17.12, blend = 0.68 }, { id = 118832898913501, at = 21.28, blend = 1 }, { id = 90182725361176, at = 27.42, blend = 0.65 },
		{ id = 70453746052130, at = 29.58, blend = 1 }, { id = 108475995123642, at = 35.02, blend = 0.82 }, { id = 108964771979987, at = 38.72, blend = 0.56 },
		{ id = 88670191702155, at = 46.68, blend = 0.68 }, { id = 115864358490692, at = 59.45 }, { id = 111343039783743, at = 73.42, blend = 0.62 },
		{ id = 93973196577178, at = 76.82, blend = 0.71 }, { id = 105227322276080, at = 78.85, blend = 0.65 }, { id = 132442605548936, at = 90.08, blend = 1 },
		{ id = 97954457634320, at = 93.88, blend = 0.34 }, { id = 76304830605030, at = 106.12, blend = 0.45 }, { id = 115786464203055, at = 117.72 },
		{ id = 73284838254272, at = 124.55, blend = 0.42 }, { id = 80227668256511, at = 133.15, blend = 0.6 }, { id = 72915658378938, at = 138.48, blend = 0.61 },
		{ id = 104212164342204, at = 145.55, blend = 0.53 }, { id = 83427493012714, at = 159.45, blend = 0.76 }, { id = 78989896538167, at = 168.32, blend = 1 } }, autoChoreo = true },
	{ channel = "K-POP", title = "MY:RAKL-오색 낙원", soundId = 108027306922001, length = 61, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "Darla Jean-Dam Da Dee", soundId = 78077595750886, length = 73, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "머무르-꿈꾸던 어른이 되었나요", soundId = 120160897793669, length = 69, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Looks Can Kill", soundId = 135553051649506, length = 64, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" }, choreo = {
		-- (D-826 the first 7 pieces, D-833 the other 25; blends from tools/choreo/choreo_check.lua)
		-- (D-871) each piece starts where it is danced in the practice video
		-- (D:\Roblox\영상\IVE_LooksCanKill_centercut\clips.json; 1-7, cut
		-- before those clips, placed by matching their arm and leg angles to
		-- the members'): the video's own time, in the original song's seconds
		-- (D-876: the song at tempo 0.333 runs 0.1 % slower, 0.15 s by 2:45,
		-- and ChoreoController follows that clock). Run back to back, the
		-- captures (shorter than their clips) had pulled 8 on 1.3 s and 32 2.0 s
		-- early
		104472985141273, { id = 100762274305324, at = 5.79, blend = 0.8 }, { id = 92352840963540, at = 7.59, blend = 0.83 }, { id = 73035150280152, at = 18.63, blend = 0.98 },
		{ id = 77509133314202, at = 26.52, blend = 0.31 }, { id = 109736190348459, at = 31.7, blend = 0.84 }, { id = 120841071882545, at = 36, blend = 1 },
		{ id = 128205693221038, at = 42.53, blend = 0.79 }, { id = 111907232555806, at = 46.35, blend = 0.4 }, { id = 124059184095981, at = 57.08 }, { id = 87500016171854, at = 63.4, blend = 1 },
		{ id = 73623563360624, at = 70.58 }, { id = 105165734205045, at = 75.23, blend = 0.41 }, { id = 84050357538982, at = 82.58, blend = 0.44 }, { id = 80842274249808, at = 85.82, blend = 0.98 },
		{ id = 112107210780715, at = 93.72, blend = 0.84 }, { id = 92250246039046, at = 100.85, blend = 0.36 }, { id = 123875931497308, at = 101.63, blend = 1 },
		{ id = 97254731498706, at = 109.23, blend = 0.66 }, { id = 85566191636983, at = 117.03, blend = 0.9 }, { id = 133964239076172, at = 125.08, blend = 0.41 }, { id = 120575710088163, at = 130.97 },
		{ id = 104957688493242, at = 138.25, blend = 0.3 }, { id = 132124420274015, at = 139.83, blend = 0.25 }, { id = 134968782013343, at = 140.35, blend = 0.74 },
		{ id = 92922732552861, at = 146.05, blend = 0.43 }, { id = 88317170211079, at = 152.7, blend = 1.5 }, { id = 130014890140037, at = 159.85, blend = 1 },
		{ id = 76585975326316, at = 162.05, blend = 0.67 }, { id = 128909786311122, at = 172.23 }, { id = 74039257328689, at = 178.8 }, { id = 79871898776208, at = 188.18, blend = 0.88 } }, autoChoreo = true },
	{ channel = "K-POP", title = "IOI-갑자기", soundId = 73546697163709, length = 65, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -20, high = -40, engine = "sound" } },
	-- (D-768, user 2026-11-03: new uploads; tempo = x1 length ÷ heard length 3:20 / 3:05)
	{ channel = "K-POP", title = "NMIXX-긴 소원(Birthday Wish)", soundId = 107782871991364, length = 67, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "NCT WISH-I SPY", soundId = 90694654380166, length = 62, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" },
		-- D-912: ISPY1..30 (practice video ILeBVk4x_XQ, video = song - 1.50 s; ISPY12 / ISPY15 were uploaded twice, the first id of each is used)
		choreo = { { id = 83299308409543, at = 1.5 }, { id = 107073213896668, at = 4.9, blend = 0.93 }, { id = 88558817308286, at = 8.82, blend = 0.92 },
		{ id = 98909637894188, at = 10.3, blend = 0.79 }, { id = 97906912240537, at = 15.32, blend = 0.46 }, { id = 114940315235555, at = 20.78, blend = 0.67 },
		{ id = 130779565006070, at = 28.05, blend = 1 }, { id = 98654918637507, at = 35.03 }, { id = 122217205660431, at = 44.38, blend = 0.42 },
		{ id = 140084544726244, at = 47.37 }, { id = 100757574150030, at = 49.27, blend = 0.49 }, { id = 71548910990490, at = 54.03, blend = 0.42 },
		{ id = 74401251779168, at = 61.18 }, { id = 137433206050479, at = 72.27, blend = 0.62 }, { id = 135074521559748, at = 77.58, blend = 0.64 },
		{ id = 119352807886781, at = 81.67, blend = 0.78 }, { id = 80718941616155, at = 87.78, blend = 0.85 }, { id = 129241685079019, at = 97.67, blend = 0.55 },
		{ id = 76871177818406, at = 100.58, blend = 0.82 }, { id = 96659789313572, at = 103.88, blend = 0.29 }, { id = 133446362959561, at = 107.7, blend = 0.51 },
		{ id = 84123931984762, at = 112.65, blend = 1 }, { id = 74058508632786, at = 119.82, blend = 0.66 }, { id = 127691136882789, at = 127.95, blend = 0.64 },
		{ id = 103256787571476, at = 137.28, blend = 0.78 }, { id = 114665222364433, at = 140.78, blend = 1 }, { id = 73998534307708, at = 148.35 },
		{ id = 117524452063760, at = 157.37, blend = 0.67 }, { id = 80845800354299, at = 168.87, blend = 1 }, { id = 112388068192596, at = 180.55 } }, autoChoreo = true },
	-- (D-782, user 2026-11-03: new uploads "여섯시…분1102", the same way as D-779; 여섯시이분 TAEYEON-만찬가 103785084548518 does not load yet;
	-- D-794: IU-이 별로부터 96396723842714 removed, user)
	{ channel = "K-POP", title = "CORTIS-REDRED", soundId = 125703446596781, length = 54.35, 
		lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" }, choreo = {
		-- (D-879, user: 24 pieces from the practice video u_vusNeo6xI, mirrored,
		-- clips 1-24 of D:\Roblox\영상\CORTIS_REDRED_centercut) each starts where its
		-- clip starts in the video, less 0.40 s: the video runs 0.40 s behind the
		-- song (tools/choreo/sync, the same in all 20 windows). Blends from
		-- tools/choreo/choreo_check.lua (a short piece's at most half its length)
		{ id = 74457262116826, from = 0.4 }, { id = 78451293274859, at = 6.67, blend = 0.72 }, { id = 99354632184083, at = 10.13, blend = 0.75 },
		{ id = 133388702168878, at = 18.5, blend = 0.84 }, { id = 89905442825152, at = 20.7, blend = 0.47 }, { id = 101510288461879, at = 23.13, blend = 0.44 },
		{ id = 76336157312311, at = 32.0, blend = 0.51 }, { id = 77329818010081, at = 40.02, blend = 0.54 }, { id = 139026140322649, at = 48.43 },
		{ id = 116978800280311, at = 57.6, blend = 1 }, { id = 131666628776868, at = 65.27 }, { id = 131761907712654, at = 79.33, blend = 1 },
		{ id = 80284068432208, at = 90.58, blend = 0.52 }, { id = 89337681817413, at = 95.48, blend = 0.66 }, { id = 81129454597965, at = 103.53 },
		{ id = 122387053799826, at = 114.88 }, { id = 140062402474513, at = 121.63, blend = 0.66 }, { id = 116086929837354, at = 124.62, blend = 1 },
		{ id = 71984111187045, at = 127.77, blend = 0.53 }, { id = 121234850587240, at = 128.87, blend = 1 }, { id = 124489277659547, at = 131.0, blend = 1 },
		{ id = 73438902388486, at = 134.05, blend = 0.62 }, { id = 103007904279324, at = 141.83, blend = 0.55 }, { id = 114253650075143, at = 153.78 } }, autoChoreo = true },
	{ channel = "K-POP", title = "BIG Naughty-노스탈지아", soundId = 116539470869444, length = 65, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "BIGBANG-BiiiG", soundId = 113809029583519, length = 55, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	{ channel = "K-POP", title = "BOYNEXTDOOR-ANIMAL", soundId = 130804487358433, length = 48, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" },
		-- D-916: ANIMAL1..25 (practice video Gl1VZ3UPeZU, video = song - 0.23 s, `at` = clip start + 0.23)
		choreo = { { id = 129402890751712, at = 0.23 }, { id = 80772039533772, at = 2.03, blend = 0.73 }, { id = 112166541341442, at = 4.51, blend = 0.74 },
		{ id = 80410028707124, at = 6.36, blend = 0.48 }, { id = 105018508412110, at = 11.01, blend = 1 }, { id = 130036196270388, at = 13.41, blend = 1 },
		{ id = 106354393645678, at = 18.91, blend = 1 }, { id = 78895444151768, at = 27.9, blend = 0.61 }, { id = 97744184558515, at = 29.03, blend = 0.95 },
		{ id = 136955392986245, at = 39.86, blend = 0.66 }, { id = 100329215645751, at = 43.98 }, { id = 78840320722064, at = 53.01, blend = 0.45 },
		{ id = 82639576960460, at = 63.36, blend = 0.66 }, { id = 104678910693394, at = 65.51, blend = 0.98 }, { id = 82506858822635, at = 77.35, blend = 0.39 },
		{ id = 91831034598236, at = 90.76, blend = 1 }, { id = 123997379474433, at = 92.43, blend = 0.46 }, { id = 99593989311395, at = 99.11, blend = 1 },
		{ id = 132625911221975, at = 102.7, blend = 0.69 }, { id = 79329885109157, at = 112.76, blend = 0.61 }, { id = 136007113687275, at = 122.28, blend = 0.42 },
		{ id = 123310558991493, at = 127.28, blend = 0.43 }, { id = 89056804683617, at = 132.25, blend = 0.5 }, { id = 116387739582454, at = 138.53 },
		{ id = 72908007597304, at = 141.9, blend = 0.77 } }, autoChoreo = true },

--★★★음원 추가★★★--
{ channel = "K-POP", title = "IU-이 별로부터(Unknown Planet)", soundId = 81568082292649, length = 225.05,
		joined = {  parts = { 81568082292649, 130739295576800, 136055998058951, 101406045735531, 115474783735573, 101362036297281, 107766734212525, 139626977220244}, segLen = 30, tail = 4, total = 225.05, lead = 0.09  },
		lab = { speed = 1, tempo = 1, volume = 10, boost = 1, octave = 1, low = 0, mid = 0, high = 0 } },
	-- (D-901, user 2026-11-05: new upload (uploaded as 새벽네시사십사분), tempo = 82.42 s file ÷ heard 4:07 = 0.334)
	{ channel = "K-POP", title = "이무진-그대 잠시 내게", soundId = 129938231085858, length = 82.42,
		lab = { speed = 1, tempo = 0.334, volume = 10, boost = 10, boost2 = 10, octave = 0.5, low = -40, mid = -25, high = -40, engine = "sound" } },
	-- (D-917, user 2026-11-05: "음원 테스트에서 설정값 받아서" 3 songs; values saved in the lab place, length = the file's seconds)
	{ channel = "K-POP", title = "ALLDAY PROJECT-CRASH", soundId = 104827635407586, length = 57.68,
		lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, boost2 = 1, octave = 0.5, low = -18.5, mid = -4, high = -12.5, engine = "sound" } },
	{ channel = "K-POP", title = "RESCENE-Pretty Girl", soundId = 89634330677538, length = 70.01,
		lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, boost2 = 1, octave = 0.5, low = -18.5, mid = -4, high = -12.5, engine = "sound" } },
	{ channel = "K-POP", title = "키키-Pop Off", soundId = 129996145931101, length = 47.11,
		lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, boost2 = 1, octave = 0.5, low = -18.5, mid = -4, high = -12.5, engine = "sound" } },

} :: {Track}

return M
