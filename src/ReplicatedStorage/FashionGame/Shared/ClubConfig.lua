--!strict
-- Club MVP data (Stage 4): dance list, tempo range, club music.
--
-- Dances are Roblox-made catalog emotes (creator "Roblox"), so any experience
-- may play them. Each animationId below is the clip inside the emote package,
-- resolved once with InsertService:LoadAsset in Studio (2026-10-20) and checked
-- to load on a character. Branded emotes (artists, films, TV) are left out.
--
-- Music: free Creator Store audio from the licensed distributors
-- (DistrokidOfficial, APMOfficial), checked to load in Studio (2026-10-20).
-- Lengths are rounded down from Sound.TimeLength; the server advances tracks
-- by these lengths.

export type Dance = {
	key: string,
	name: string,
	category: string,
	animationId: number,
	looped: boolean,
}

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
}

local ClubConfig = {}

-- (D-811, user: "미세하게 바들바들 떨리는 부분 보정 … 멀쩡한 안무까지 수정하지
-- 말고") the choreography animations are captured at 24 keyframes a second
-- with small back-and-forth zigzags in the joints. ChoreoSmooth eases only
-- the keyframes where a joint goes back and forth by less than `maxStep`
-- degrees (`passes` times); the rest of the dance stays exactly as made.
-- nil = off.
ClubConfig.ChoreoSmoothing = { maxStep = 8, passes = 4 } :: { maxStep: number, passes: number }?

-- (D-843) the choreography captures carry a spine, a chest and two
-- clavicles that an R15 body does not have; true folds their turns onto the
-- waist and the shoulders (ChoreoSmooth.retarget) so that motion shows.
-- The toes have nowhere to go on R15 and stay out. false = off.
ClubConfig.ChoreoRetarget = true

-- (D-817) a dancer following a choreography walks its dance path (D-813),
-- and is eased back toward where the dance began over about this many
-- seconds, so the drift the pieces add up to does not carry them off the
-- floor. nil = no easing back.
ClubConfig.ChoreoDriftReturn = 8 :: number?

-- (D-840, user) spot fixes for single choreography pieces, by animation id
-- (the same piece gets them in any song):
--   steady = { from, to, parts, passes? }: those parts' keyframes between
--     `from` and `to` seconds into the animation smoothed hard (a shaky arm),
--     easing in and out over 0.15 s at both ends (ChoreoSmooth); a list of
--     such stretches (D-884)
--   turn = seconds: the piece starts facing where the piece before it ended
--     and turns on the way that one was turning into its own facing over
--     that many seconds (ChoreoController.turnHips), instead of a cross-fade
--     that flips the body round; keep it within the piece's `blend`
--   pops = { at, sizes?, push, lift?, arch, out?, back?, sink? }: a chest pop at each of those seconds
--     into the animation: the chest goes `push` studs forward, `lift` up and
--     arches `arch` degrees back (the head stays level), out in `out` s
--     (0.07) and back in `back` s (0.3), at an even pace with `sink`
--     (ChoreoSmooth.pop)
--   calm = true: the slower wobble eased too (ClubConfig.ChoreoCalm, D-851)
--   hold = { from, to }: the pose at `from` kept until `to`, then the dance
--     goes on from `to`, easing out of the held pose in 0.25 s (D-852), or a
--     list of such stretches (D-884)
--   still = { from, to }: no travel of the dancer there (D-852), or a list of
--     such stretches (D-863)
--   turnEase = "out": the `turn` starts at full speed and slows down, for a
--     piece before that ends mid-spin (D-852)
--   spin = { from, to }: a spin in the capture that lurches turns evenly
--     between its facings at `from` and `to` (starts gently, ends at full
--     speed) (D-852); `turns` whole turns added on the way, `ease = "both"`
--     starts and ends gently (D-873)
--   pose ={ from, to, ease?, keys = {{ t, set = { [part] = { x, y, z } } }}, add? }:
--     a pose the capture lost: those joints set to the keys' turns (degrees,
--     eased between keys), `add` turns added on top, easing in and out over
--     `ease` s (D-855); a list of such poses for different stretches, and keys
--     with their own `add` turns (eased between keys), D-860
--   (steady without `parts` = the whole body, D-852)
ClubConfig.ChoreoFixes = {
	-- IVE-Looks Can Kill (D-871, from the practice video LvRTCcTPgsY): `still`
	-- where the member the piece was cut from stands in the video (hips and
	-- feet under 0.12 body heights a second for 0.6 s or more) but the piece
	-- carries the hips 0.3 studs or more; `calm` on the pieces with 7 or more
	-- short back-and-forth turns a second (other songs' pieces have 1-4)
	[104472985141273] = { still = { { from = 2.8, to = 4.8 } } }, -- 1
	[100762274305324] = { still = { { from = 0.8, to = 1.6 } }, calm = true }, -- 2
	[92352840963540] = { still = { { from = 1.8, to = 2.6 }, { from = 3.6, to = 4.2 }, { from = 5.6, to = 9 } } }, -- 3
	[77509133314202] = { still = { { from = 1.8, to = 2.8 } }, calm = true }, -- 5
	[109736190348459] = { still = { { from = 2.6, to = 4.2 } }, calm = true }, -- 6
	[111907232555806] = { still = { { from = 4.4, to = 5.4 }, { from = 5.8, to = 6.6 }, { from = 7.6, to = 8.8 } } }, -- 9
	[124059184095981] = { still = { { from = 2, to = 3 }, { from = 3.6, to = 4.4 }, { from = 4.6, to = 5.8 } } }, -- 10
	[87500016171854] = { still = { { from = 3, to = 3.8 }, { from = 5.6, to = 6.4 } } }, -- 11
	[73623563360624] = { still = { { from = 0.8, to = 1.6 }, { from = 2.4, to = 3.4 } } }, -- 12
	[105165734205045] = { still = { { from = 2.6, to = 4.2 }, { from = 4.4, to = 5.6 } }, calm = true }, -- 13
	[84050357538982] = { still = { { from = 0, to = 0.8 } } }, -- 14
	[80842274249808] = { still = { { from = 0.2, to = 0.8 }, { from = 1, to = 1.6 }, { from = 3, to = 4 } }, calm = true }, -- 15
	[112107210780715] = { still = { { from = 1.6, to = 2.6 }, { from = 2.8, to = 3.8 }, { from = 4, to = 5.4 } }, calm = true }, -- 16
	[123875931497308] = { still = { { from = 1.4, to = 2.6 } } }, -- 18
	[97254731498706] = { still = { { from = 0, to = 0.8 }, { from = 3.6, to = 5.4 } } }, -- 19
	[85566191636983] = { still = { { from = 4.6, to = 5.2 }, { from = 6.6, to = 7.2 } } }, -- 20
	[133964239076172] = { still = { { from = 2.6, to = 3.2 } }, calm = true }, -- 21
	[120575710088163] = { still = { { from = 0.4, to = 1 }, { from = 1.6, to = 3 } } }, -- 22
	-- 23 (D-882, user: 2:19-2:20 "버벅거리는데 … 해당 시간 안에서 매끄럽게 반바퀴 도는 걸로"):
	-- the capture turned about 50° and back; in the video she goes round through
	-- her back and faces the same way again by 2:20, so one even turn there
	-- (a spin only runs once the piece plays alone: its blend 0.76 → 0.3)
	[104957688493242] = { calm = true, spin = { from = 0.3, to = 1.49, turns = -1, ease = "both" } }, -- 23
	[132124420274015] = { calm = true }, -- 24
	-- 25 (song 2:20.5): the right arm shook at 2:24
	[134968782013343] = { steady = { from = 3.1, to = 4.1, parts = { "RightUpperArm", "RightLowerArm", "RightHand" } }, still = { { from = 3, to = 4 }, { from = 4.6, to = 5.2 } } },
	-- 26 + 27 (D-882, user: 2:33 "한바퀴 도는 거 매끄럽게"): 26 turned 137° and
	-- stopped for 0.4 s, then 27's `turn` started from a standstill for the
	-- other 195°: 26 turns evenly to its end at speed, 27 carries on at speed
	-- and slows down over 1.5 s (its blend too)
	[92922732552861] = { still = { { from = 0.2, to = 0.8 }, { from = 1.6, to = 2.8 }, { from = 3.6, to = 5.4 } }, spin = { from = 4.84, to = 6.76 } }, -- 26 (to 27's start, no stop between)
	-- 27 (song 2:32.9): 26 ends facing back
	[88317170211079] = { turn = 1.5, turnEase = "out", still = { { from = 0.4, to = 1.2 } }, calm = true },
	[76585975326316] = { still = { { from = 2.4, to = 3.2 }, { from = 4.2, to = 5.2 }, { from = 8, to = 8.8 } } }, -- 29
	[74039257328689] = { calm = true }, -- 31
	[79871898776208] = { still = { { from = 1, to = 5.77 } }, calm = true }, -- 32
	-- ATEEZ-BAD 10, 12, 17 (D-844): facing gaps of 118°, 141° and 161° at
	-- 0:58, 1:09 and 1:41 (10 flipped round in one frame with a cross-fade)
	[78517242404651] = { turn = 0.99, still = { { from = 5.8, to = 7.4 } } },
	[130559113363194] = { turn = 1 },
	[87606540400975] = { turn = 1 },
	-- ATEEZ-BAD (D-863, user: "가만히 서 있는데 이동하는 거 … 이런 동작 전부 확인한
	-- 후 삭제"): stretches of each piece where its dancer stands still in the
	-- practice video (hips and feet moving under 0.12 body heights a second
	-- for 0.6 s or more, ATEEZ_BAD_centercut/tracks.json), so the capture's
	-- travel there is dropped (piece seconds; 10 also through its last pose)
	[82278370960435] = { still = { { from = 0, to = 3.2 }, { from = 4.2, to = 6.6 } } },
	[120748822938478] = { still = { { from = 7.4, to = 8.2 } } },
	[110345323270713] = { still = { { from = 2.6, to = 4.6 } } },
	[122397631727855] = { still = { { from = 0.6, to = 1.4 } } },
	[96766863219484] = { still = { { from = 0.8, to = 1.6 }, { from = 2.0, to = 2.8 }, { from = 4.0, to = 5.2 } } },
	[116077835257285] = { still = { { from = 0.8, to = 1.8 }, { from = 4.4, to = 5.8 }, { from = 9.6, to = 10.4 } } },
	[135462564673113] = { still = { { from = 3.2, to = 4.0 } } },
	[94325256666159] = { still = { { from = 0, to = 0.8 } } },
	[111913125032810] = { still = { { from = 3.8, to = 4.6 } } },
	[129415986484255] = { still = { { from = 0.2, to = 1.0 }, { from = 2.4, to = 3.6 }, { from = 6.6, to = 7.8 } } },
	[121775933093308] = { still = { { from = 0.2, to = 1.0 }, { from = 2.2, to = 3.0 }, { from = 4.4, to = 5.2 }, { from = 5.6, to = 6.4 },
		{ from = 6.6, to = 7.6 }, { from = 8.4, to = 10.4 } } },
	[138549092776506] = { still = { { from = 9.6, to = 10.4 } } },
	[134748500609652] = { still = { { from = 1.0, to = 2.0 }, { from = 2.4, to = 5.8 } } },
	[70571634425422] = { still = { { from = 1.0, to = 7.4 } } },
	-- ATEEZ-BAD 21 (D-848, user: "가슴을 더 앞으로 크게 튕겼으면"): the capture
	-- kept under 3° of the four chest pops in the reference clip
	-- (D-851, user: "눈에 확 보이게") pushed further and held a little longer
	-- (D-853, user: "1초에 한 번씩 가슴 앞으로 위로 튀어나오게", in the arm-across pose,
	-- 1.25-4.75 s): forward and up, the chest arching up (the head stays level)
	-- (D-854, user: "영상 속 남자가 가슴 튕기는 순간 분석하여 적용") the dancer in the
	-- user's clip pops at 1.77 / 2.77 / 3.80 / 4.87 s, a frame up and then an even
	-- sink until the next one; his clip runs 0.22 s behind this piece (arms
	-- across, the lunge), so 1.55 / 2.55 / 3.58 / 4.63 here (the ATEEZ source
	-- of this piece lengthens its torso at 2.54 / 3.57 / 4.57 too)
	-- (D-856, user: "큰 가슴 튕김->작은 가슴 튕김 … 세 번은 반복", the small one "살짝 덜")
	-- the clip frame by frame: big 1.77 / 2.77 / 3.80 s, small 2.37 / 3.25 / 4.30 s
	-- (- 0.22 s here); the small ones 0.6 of the big
	[82346668311878] = { still = { { from = 1.4, to = 5.2 } }, pops = { at = { 1.55, 2.15, 2.55, 3.03, 3.58, 4.08 }, sizes = { 1, 0.6, 1, 0.6, 1, 0.6 },
		push = 0.5, lift = 0.2, arch = 8, out = 0.05, back = 0.85, sink = true },
		-- (D-855, user: "보정") the user's clip holds the forearm level across the
		-- chest (lower from about 3 s, at the waist by 4.3 s) and the head tipped back from the arms
		-- across to the hands on the hips; the capture lost both (here the arm
		-- across is the right one: the piece is the mirror of the clip); (D-856,
		-- user: "손 모양도 영상처럼 펴서") the hand straight along the forearm, turned
		-- so its broad side faces up
		-- (D-862, user: the practice video 3ZO5F5wUmBg, the dancer in the black
		-- tank top, mirrored; "움직임이 작은 건 영상처럼 확실한 액션으로") measured
		-- frame by frame at 60 fps (anim time = video time - 136.49 s): the
		-- forearm across goes from the chest at 1.35 s steadily down to the belt
		-- by 4.0 s (wrist 1.13 → 0.34 torso lengths above the hips) and the hands
		-- are on the hips by 4.3 s; the elbow is held out wide, at the shoulder at
		-- first and sinking with the hand; angles solved for elbow and hand
		pose = { { from = 1.15, to = 4.4, ease = 0.3,
			keys = {
				{ t = 1.35, set = { RightUpperArm = { -42, 18, 78 }, RightLowerArm = { 145, 0, 0 }, RightHand = { 0, -45, 0 } } },
				{ t = 2.0, set = { RightUpperArm = { -60, 24, 78 }, RightLowerArm = { 140, 0, 0 }, RightHand = { 0, -45, 0 } } },
				{ t = 2.5, set = { RightUpperArm = { -60, 36, 72 }, RightLowerArm = { 130, 0, 0 }, RightHand = { 0, -40, 0 } } },
				{ t = 3.0, set = { RightUpperArm = { -60, 48, 66 }, RightLowerArm = { 115, 0, 0 }, RightHand = { 0, -30, 0 } } },
				{ t = 3.5, set = { RightUpperArm = { -60, 60, 66 }, RightLowerArm = { 105, 0, 0 }, RightHand = { 0, -15, 0 } } },
				{ t = 4.0, set = { RightUpperArm = { -60, 72, 66 }, RightLowerArm = { 90, 0, 0 }, RightHand = { 0, -10, 0 } } },
			},
			add = { Head = { 14, 0, 0 } } },
			-- (D-862) hands on the hips (5-6.6 s): the video opens the feet to 1.5
			-- then 2.0-2.1 hip widths, knees out, and sinks the hips by about a third
			-- of a torso (ankle below hip 1.65 → 1.31 torsos) into a wide squat; the
			-- capture stood up with the feet 1.3-1.8 apart (D-860 had narrowed them,
			-- read wrongly from a low-resolution clip). The legs are set to that
			-- squat (angles solved for the ankle on the floor), the feet kept level,
			-- the hips lowered (`move`, feet on the floor) and the head comes back
			-- down; it hands over to the capture's lunge at 6.65-6.78 s
			{ from = 4.85, to = 6.78, ease = 0.2,
				keys = {
					{ t = 5.0, set = { LeftUpperLeg = { 15, -5, -3 }, LeftLowerLeg = { -33, 0, 0 }, LeftFoot = { 18, 0, 0 },
						RightUpperLeg = { 15, 5, 3 }, RightLowerLeg = { -33, 0, 0 }, RightFoot = { 18, 0, 0 } },
						move = { LowerTorso = { 0, -0.08, 0 } }, add = { Head = { 12, 0, 0 } } },
					{ t = 5.25, set = { LeftUpperLeg = { 21, -10, -3 }, LeftLowerLeg = { -48, 0, 0 }, LeftFoot = { 27, 0, 0 },
						RightUpperLeg = { 21, 10, 3 }, RightLowerLeg = { -48, 0, 0 }, RightFoot = { 27, 0, 0 } },
						move = { LowerTorso = { 0, -0.23, 0 } }, add = { Head = { 11, 0, 0 } } },
					{ t = 5.5, set = { LeftUpperLeg = { 24, -10, -6 }, LeftLowerLeg = { -57, 0, 0 }, LeftFoot = { 33, 0, 0 },
						RightUpperLeg = { 24, 10, 6 }, RightLowerLeg = { -57, 0, 0 }, RightFoot = { 33, 0, 0 } },
						move = { LowerTorso = { 0, -0.36, 0 } }, add = { Head = { 10, 0, 0 } } },
					{ t = 6.0, set = { LeftUpperLeg = { 27, -15, -6 }, LeftLowerLeg = { -66, 0, 0 }, LeftFoot = { 39, 0, 0 },
						RightUpperLeg = { 27, 15, 6 }, RightLowerLeg = { -66, 0, 0 }, RightFoot = { 39, 0, 0 } },
						move = { LowerTorso = { 0, -0.5, 0 } }, add = { Head = { 8, 0, 0 } } },
					{ t = 6.5, set = { LeftUpperLeg = { 30, -15, -6 }, LeftLowerLeg = { -75, 0, 0 }, LeftFoot = { 45, 0, 0 },
						RightUpperLeg = { 30, 15, 6 }, RightLowerLeg = { -75, 0, 0 }, RightFoot = { 45, 0, 0 } },
						move = { LowerTorso = { 0, -0.58, 0 } }, add = { Head = { 4, 0, 0 } } },
				} } } },
	-- A2O LITE-NEON 1, 2, 3 (D-851, user: "네온 초반에 바들바들 떠는 거"): a
	-- slower wobble (about 4-8 a second) than the usual clean-up catches
	-- NEON 1 (D-852, user: 5-6 s, the raised-arm pose twice "처음 나오는 자세에서
	-- 두 번째 나오는 같은 자세 끝날 때까지 고정")
	-- (D-873, user: "10초 돌려차기 하는 동작으로 수정") the member spins all the way
	-- round with a kick (video 12.4-13.4 s = song 10.4-11.4); the capture
	-- turned half way and back and squatted (hips 1.1 studs down) instead:
	-- one turn on, left leg chambered, kicked out at hip height and back, the
	-- standing leg straight and the hips held up (`move` = 0.8 x (-0.15 less
	-- the capture's hips height): the animator scales travel to the body)
	[118329772913374] = { calm = true, hold = { from = 4.83, to = 6.04 },
		spin = { from = 12.33, to = 13.42, turns = 1, ease = "both" },
		-- (D-875, user: "1초에 허리 숙이는 거 더 아래로 숙이게") the members fold
		-- right down at video 3.0 s (hair thrown forward); the capture leans
		-- only 24°: up to 40° more at the waist, easing back by 3.85;
		-- (the chest up 15° in the kick: the capture bent over into its squat)
		pose = { { from = 2.75, to = 3.9, ease = 0.05, keys = {
			{ t = 2.8, add = { UpperTorso = { 0, 0, 0 } } }, { t = 2.95, add = { UpperTorso = { -30, 0, 0 } } },
			{ t = 3.05, add = { UpperTorso = { -40, 0, 0 } } }, { t = 3.2, add = { UpperTorso = { -35, 0, 0 } } },
			{ t = 3.5, add = { UpperTorso = { -20, 0, 0 } } }, { t = 3.85, add = { UpperTorso = { 0, 0, 0 } } } } },
		{ from = 12.72, to = 13.42, ease = 0.1, add = { UpperTorso = { 15, 0, 0 } }, keys = {
			{ t = 12.8, set = { LeftUpperLeg = { 40, 0, -10 }, LeftLowerLeg = { -70, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0.06, 0 } } },
			{ t = 12.88, set = { LeftUpperLeg = { 62, 0, -18 }, LeftLowerLeg = { -90, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -8, 0, 0 } }, move = { LowerTorso = { 0, 0.12, 0 } } },
			{ t = 12.92, set = { LeftUpperLeg = { 75, 0, -25 }, LeftLowerLeg = { -95, 0, 0 }, RightUpperLeg = { 4, 0, 0 }, RightLowerLeg = { -6, 0, 0 } }, move = { LowerTorso = { 0, 0.3, 0 } } },
			{ t = 12.96, set = { LeftUpperLeg = { 82, 0, -30 }, LeftLowerLeg = { -60, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.56, 0 } } },
			{ t = 13.0, set = { LeftUpperLeg = { 85, 0, -35 }, LeftLowerLeg = { -20, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.78, 0 } } },
			{ t = 13.04, set = { LeftUpperLeg = { 86, 0, -35 }, LeftLowerLeg = { -10, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.9, 0 } } },
			{ t = 13.08, set = { LeftUpperLeg = { 85, 0, -35 }, LeftLowerLeg = { -12, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.86, 0 } } },
			{ t = 13.12, set = { LeftUpperLeg = { 80, 0, -28 }, LeftLowerLeg = { -50, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -6, 0, 0 } }, move = { LowerTorso = { 0, 0.69, 0 } } },
			{ t = 13.17, set = { LeftUpperLeg = { 70, 0, -20 }, LeftLowerLeg = { -80, 0, 0 }, RightUpperLeg = { 4, 0, 0 }, RightLowerLeg = { -8, 0, 0 } }, move = { LowerTorso = { 0, 0.43, 0 } } },
			{ t = 13.21, set = { LeftUpperLeg = { 45, 0, -10 }, LeftLowerLeg = { -60, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0.19, 0 } } },
			{ t = 13.25, set = { LeftUpperLeg = { 25, 0, -5 }, LeftLowerLeg = { -40, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0.03, 0 } } },
			{ t = 13.33, set = { LeftUpperLeg = { 10, 0, 0 }, LeftLowerLeg = { -15, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0, 0 } } },
		} } } },
	[95449015545787] = { calm = true },
	[84806571273074] = { calm = true },
	-- NEON (D-868, user: the stage fancam, "네온 안무 수정"): every piece with more
	-- of the slower wobble than other songs' pieces (over 5.5 short swings a
	-- second; ATEEZ pieces have about 3) gets it eased too
	[128256391320572] = { calm = true }, [100410498984971] = { calm = true }, [126736648781925] = { calm = true },
	[76437753036430] = { calm = true }, [136355327951443] = { calm = true }, [117451819045051] = { calm = true },
	[133401623277764] = { calm = true }, [106546379406531] = { calm = true }, [71570705300325] = { calm = true },
	[121393866689759] = { calm = true }, [114419952125075] = { calm = true },
	-- NEON 5 (D-852, user: 0:53 "이 자세로 잠시 머무는데 이때 떨림 삭제")
	-- (D-873, user: "50초 가만히 있기") the members hold that low pose from song
	-- 49.75 to 52.1 (video 51.75-54.1); the capture gets up from 51.6, so the
	-- pose is held to 52.0 (anim 9.95)
	[93933273398995] = { calm = true, steady = { from = 7.85, to = 9.45, passes = 8 }, hold = { from = 7.9, to = 9.95 } },
	-- NEON 8 (D-852, user: 1:22 "한 바퀴 도는 게 매끄럽지 않음"): 7 ends
	-- mid-spin (about 400°/s), so 8 carries on at that speed and slows down
	-- (its blend 1 → 0.85, the same as the turn, so nothing jumps when it ends)
	[114466589507598] = { calm = true, spin = { from = 8.47, to = 8.97 } },
	-- (D-875, user: "한바퀴 도는 동작은 제 시간 안에 매끄럽게 한 바퀴 … 1:25 전후")
	-- 8 spins once to the left at 3.2-3.9 s but stalls near -140° and then
	-- jumps 160° in one keyframe: one even turn instead, to 4.15 where the
	-- capture's own facing settles (no step when it lets go)
	[84027575690735] = { turn = 0.85, turnEase = "out", spin = { from = 3.2, to = 4.15, turns = -1, ease = "both" } },
	-- NEON 17 (D-852, user: 2:31 "다리가 진동함 … 저 자세로 뒤로 빠지는데 저
	-- 자리에 고정")
	-- (D-881, user: 2:33 "벌벌 떠는 움직임"): the hands and arms shook there too
	-- (2:30-2:31.5, 5-7 turn backs in 0.5 s): the whole body, not only the legs
	[96973609514230] = { calm = true, steady = { from = 0.4, to = 2.7, passes = 8 },
		still = { from = 0.4, to = 2.8 } },
	-- RIIZE-Get A Guitar 15 (D-882, user: 1:54 "한바퀴 도는 거 매끄럽게"): the turn at
	-- 16.4-16.6 s lurched 157° in one keyframe; one even turn instead
	[129447992418977] = { spin = { from = 16.07, to = 17.15, ease = "both" } },
	-- CORTIS-REDRED (D-879, the practice video u_vusNeo6xI): `still` where the
	-- clip's member stands in the video (hips and feet under 0.12 body heights
	-- a second for 0.6 s or more); `turn` at the seams that face 101°-173° apart
	-- (not 2 → 3, 90°: the way 2 was turning is the long way round, 270°)
	[74457262116826] = { still = { from = 0.4, to = 3.12 } }, -- 1 (from 0.12; the piece starts at 0.4)
	[133388702168878] = { turn = 0.84 }, -- 4 (101°)
	[76336157312311] = { still = { from = 6.07, to = 6.97 } }, -- 7
	-- 11 (D-884, user: "1:13 허리 숙이고 바들바들 떠는 거 수정"): the member bends
	-- over and stays still twice (clip 11: 6.6-7.8 s and 8.6-9.8 s); the capture
	-- trembles while it settles into each bend (Play: 21 small turn-backs in
	-- 0.5 s at 1:12.0-1:12.5, 9 at 1:14.0-1:14.5, under ChoreoShake's count),
	-- then is still by itself: the whole body smoothed while it settles only
	-- (reaching into the still part gave it a slow wobble of its own)
	[131666628776868] = { still = { { from = 6.57, to = 7.87 }, { from = 8.73, to = 9.83 } },
		steady = { { from = 6.5, to = 7.0, passes = 8 }, { from = 8.5, to = 9.6, passes = 8 } } },
	[131761907712654] = { still = { from = 10.32, to = 11.17 } }, -- 12
	[121234850587240] = { turn = 1 }, -- 20 (173°)
	[124489277659547] = { turn = 1 }, -- 21 (171°)
	[114253650075143] = { still = { from = 4.6, to = 8.92 } }, -- 24
} :: {[number]: { steady: { from: number, to: number, parts: {string}?, passes: number? }?, turn: number?,
	pops: { at: {number}, sizes: {number}?, push: number, lift: number?, arch: number, out: number?, back: number?, sink: boolean? }?, calm: boolean?,
	hold: { from: number, to: number }?, still: any?, turnEase: string?,
	spin: { from: number, to: number }?,
	pose: any? }}

-- (D-851) the slower wobble clean-up for pieces with `calm` in ChoreoFixes:
-- a turn back between two swings of at most maxLen keyframes and maxSwing
-- degrees is eased, passes times, never more than cap degrees off the
-- capture (NEON 1: 118 such swings → 51, about what other pieces have)
ClubConfig.ChoreoCalm = { maxSwing = 10, maxLen = 4, passes = 6, cap = 5 }

-- (D-881, user: NEON 2:33 "벌벌 떠는 움직임 … 다른 부분에도 이런 달달 떨림 발견해서
-- 떨림 수정") in every piece, the stretches where a joint still shakes after the
-- clean-up above (turn backs of minSwing..maxSwing degrees, at most maxGap s
-- apart, `count` or more within `window` s) are eased like a `steady` fix,
-- that joint only and never more than `cap` degrees (ChoreoSmooth.shaky).
-- Measured on the cleaned keyframes: 8 or more in 0.5 s was 481 stretches over
-- the six songs (NEON 2:30-2:31 hands 9); most of a dance has 3-6. nil = off.
ClubConfig.ChoreoShake = { minSwing = 2, maxSwing = 25, maxGap = 0.2, count = 8, window = 0.5, edge = 0.15, passes = 4, cap = 8 } :: {[string]: number}?

-- (D-880, user: NEON 2:51 "제자리에 서서 오른쪽팔을 뻗는 안무인데 위치가 왔다갔다 함 …
-- 다리에 움직임 없는데 위치 변동 있는 부분 … 전체적으로 스캔 후 모두 잡아내서 수정. 안무
-- 있는 곡 모두 해당") stretches (seconds into each piece) where the capture's feet,
-- worked out from its leg joints on an R15 body, keep their stance (left to
-- right foot within 0.25 studs), neither lifts (0.2), and yet both go 0.4 studs
-- or more in 0.5 s, or wander 0.5 back and forth: the body slides while the legs
-- stand. They become `still` stretches (no travel; added to ChoreoFixes below).
ClubConfig.ChoreoSlideStill = {
	-- A2O LITE-NEON
	[95449015545787] = { { 4.0, 4.6 } }, [93933273398995] = { { 4.0, 4.7 }, { 5.5, 6.1 } }, [128256391320572] = { { 12.0, 12.6 } },
	[114466589507598] = { { 3.5, 4.2 }, { 6.2, 6.8 } }, [124518142645731] = { { 0.5, 1.1 } }, [76437753036430] = { { 0.6, 1.3 } },
	[117451819045051] = { { 3.0, 3.6 }, { 5.5, 6.1 } }, [111932052760637] = { { 3.3, 4.0 } },
	[96973609514230] = { { 7.9, 8.5 }, { 10.7, 11.7 }, { 15.1, 15.8 } }, [106546379406531] = { { 5.7, 6.9 } }, [73851407273132] = { { 3.6, 4.3 } },
	[71570705300325] = { { 9.2, 9.8 }, { 12.2, 12.8 } }, [121393866689759] = { { 3.2, 4.2 }, { 4.6, 5.2 }, { 6.1, 6.9 } },
	[114419952125075] = { { 3.0, 3.5 } },
	-- 현아-Bubble Pop
	[100736920067826] = { { 7.8, 8.8 } }, [133384041896194] = { { 4.0, 4.8 }, { 9.7, 10.4 } },
	[83466816721074] = { { 10.0, 12.5 } }, [133279932519664] = { { 5.5, 6.3 }, { 6.5, 7.1 } },
	[80189218624271] = { { 5.5, 6.2 }, { 10.3, 10.9 } }, [74977996210534] = { { 1.3, 2.1 }, { 13.1, 13.8 } },
	[128213782788357] = { { 4.9, 5.5 }, { 6.0, 6.7 }, { 7.9, 8.6 }, { 10.5, 11.3 } }, [79851078896686] = { { 11.9, 12.5 } },
	-- CORTIS-REDRED
	[99354632184083] = { { 1.4, 2.0 } }, [76336157312311] = { { 2.7, 3.3 } }, [77329818010081] = { { 6.9, 7.5 } }, [116978800280311] = { { 6.8, 7.6 } },
	[131666628776868] = { { 5.5, 6.1 } }, [131761907712654] = { { 6.3, 7.5 }, { 9.1, 9.9 } }, [80284068432208] = { { 3.5, 4.1 } },
	[89337681817413] = { { 4.8, 5.5 } }, [81129454597965] = { { 6.9, 7.5 }, { 9.9, 11.2 } }, [122387053799826] = { { 5.7, 6.4 } },
	[121234850587240] = { { 1.1, 1.9 } }, [73438902388486] = { { 4.0, 4.8 } }, [103007904279324] = { { 0.1, 0.9 }, { 4.5, 5.3 }, { 11.3, 12.0 } },
	[114253650075143] = { { 3.9, 4.6 } },
	-- IVE-Looks Can Kill
	[104472985141273] = { { 2.7, 3.3 } }, [109736190348459] = { { 1.0, 1.6 } }, [120841071882545] = { { 2.8, 4.4 } },
	[128205693221038] = { { 0.8, 1.4 }, { 3.3, 3.9 } }, [111907232555806] = { { 0.2, 1.5 }, { 8.3, 9.1 } },
	[87500016171854] = { { 0.7, 1.3 }, { 6.5, 7.2 } }, [112107210780715] = { { 6.2, 6.8 } },
	[123875931497308] = { { 0.9, 1.6 }, { 2.9, 3.5 }, { 3.7, 4.3 } }, [97254731498706] = { { 6.3, 6.9 } },
	[133964239076172] = { { 0.7, 1.5 }, { 2.3, 3.0 } }, [120575710088163] = { { 4.9, 6.5 } }, [92922732552861] = { { 1.0, 1.6 }, { 5.2, 5.8 } },
	[88317170211079] = { { 0.2, 0.9 }, { 2.6, 4.2 } }, [76585975326316] = { { 0.6, 1.3 }, { 8.6, 9.5 } },
	[128909786311122] = { { 0.6, 1.3 }, { 1.5, 2.5 } }, [74039257328689] = { { 8.1, 8.7 } }, [79871898776208] = { { 0.2, 1.1 } },
	-- RIIZE-Get A Guitar
	[97097804325917] = { { 7.3, 8.0 } }, [119200924904137] = { { 0.9, 1.5 } }, [77403973851668] = { { 2.7, 3.3 } },
	[121969021575883] = { { 4.1, 4.8 }, { 9.0, 9.6 } }, [96742563282745] = { { 1.5, 2.4 } }, [88430566939812] = { { 4.1, 4.8 } },
	[108795638313983] = { { 1.4, 2.0 } }, [129447992418977] = { { 5.4, 6.0 }, { 8.1, 8.8 } }, [82252722293006] = { { 2.9, 3.6 }, { 5.4, 6.1 } },
	[117244778152210] = { { 1.6, 2.2 } }, [113505968174557] = { { 5.5, 6.1 } }, [112498417388469] = { { 5.0, 6.1 } },
	-- ATEEZ-BAD
	[120748822938478] = { { 8.4, 9.4 } }, [110345323270713] = { { 4.4, 5.0 } }, [122397631727855] = { { 3.5, 4.3 } },
	[96766863219484] = { { 4.7, 5.3 }, { 5.9, 6.5 } }, [116077835257285] = { { 9.4, 10.1 } }, [78517242404651] = { { 2.2, 3.0 } },
	[94325256666159] = { { 1.4, 2.4 } }, [111913125032810] = { { 0.5, 1.1 } }, [129415986484255] = { { 4.7, 5.4 } },
	[87606540400975] = { { 1.2, 1.9 }, { 3.2, 3.8 } }, [121775933093308] = { { 2.9, 3.8 }, { 8.0, 8.6 }, { 10.4, 11.1 } },
	[88428525489460] = { { 1.7, 2.3 }, { 2.7, 3.3 } }, [82346668311878] = { { 5.0, 5.6 } }, [70571634425422] = { { 0.4, 1.1 } },
} :: {[number]: {{number}}}
for id, stretches in pairs(ClubConfig.ChoreoSlideStill) do
	local fix = (ClubConfig.ChoreoFixes[id] or {}) :: any
	ClubConfig.ChoreoFixes[id] = fix
	local still = if fix.still == nil then {} elseif fix.still.from then { fix.still } else table.clone(fix.still)
	for _, s in ipairs(stretches) do table.insert(still, { from = s[1], to = s[2] }) end
	fix.still = still
end

-- Skip vote (user 2026-11-01, D-694): votes needed to skip the song while
-- there is no DJ = half the people in the club, rounded up, and at least 2
-- once two or more are there (alone: your own vote is enough)
function ClubConfig.skipVotesNeeded(peopleInClub: number): number
	if peopleInClub <= 1 then return 1 end
	return math.max(2, math.ceil(peopleInClub / 2))
end

-- 🧪 (user 2026-11-01) the "Bubble Pop 틀기" test button in the club, for
-- trying the choreography on a phone: shown in Studio and, on live servers,
-- to the experience owner's account only. Set to false before the launch.
ClubConfig.TestChoreoButton = false -- (off 2026-11-01, user: "아래 테스트 삭제")
function ClubConfig.canTestChoreo(player: Player): boolean
	if not ClubConfig.TestChoreoButton then return false end
	if game:GetService("RunService"):IsStudio() then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- (D-849, user) who may move the song with the play bar: the DJ playing now,
-- the game's owner, anyone in Studio tests
function ClubConfig.canSeek(player: Player, isDJ: boolean): boolean
	if isDJ or game:GetService("RunService"):IsStudio() then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- The lab's apply(): the PlaybackSpeed really sent (speed × tempo, Roblox
-- stops at 20) and the PitchShift octave (octave ÷ the tempo that got
-- through: tempo is speed with the pitch put back, 1/32..32)
function ClubConfig.labEffective(lab: Lab): (number, number)
	local playSpeed = math.min(lab.speed * lab.tempo, 20)
	local tempo = playSpeed / lab.speed
	return playSpeed, math.clamp(lab.octave / tempo, 1 / 32, 32)
end

-- One PitchShiftSoundEffect reaches 0.5..2: a bigger octave is split into n
-- equal parts, n = ceil(|log2 octave|), at most 5 (the lab's octaveParts)
function ClubConfig.octaveParts(t: number): {number}
	if t >= 0.5 and t <= 2 then return { t } end
	local n = math.clamp(math.ceil(math.abs(math.log(t, 2)) - 1e-6), 1, 5)
	local part = t ^ (1 / n)
	local list = {}
	for i = 1, n do list[i] = part end
	return list
end

-- the name shown for a track: a 🎵 when its choreography is danced
-- (autoChoreo; Bubble Pop's older one is kept but not danced) (D-731).
-- (D-756, user: in front of the title and smaller) Rich text: the label needs
-- RichText = true; textSize = the label's TextSize (the mark is 70 % of it).
local function escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
ClubConfig.escapeRich = escape
function ClubConfig.showTitle(track: Track, textSize: number?): string
	local title = escape(track.title)
	if not (track.choreo and track.autoChoreo) then return title end
	return string.format('<font size="%d">🎵</font> %s', math.floor((textSize or 14) * 0.7 + 0.5), title)
end

-- how fast a track's audio runs: its own base speed (or its lab
-- PlaybackSpeed) times the DJ's speed
function ClubConfig.trackRate(track: Track?, djSpeed: any): number
	local base = if track and track.lab then (ClubConfig.labEffective(track.lab))
		elseif track and track.baseSpeed then track.baseSpeed else 1
	return base * (if typeof(djSpeed) == "number" then djSpeed else 1)
end

-- (D-876, user: "왜 안무랑 음악 타이밍이 안 맞는 상황이 발생하는지 연구 후 … 보완")
-- the user's uploads are the song sped up exactly 3 times (IVE: 64.33 s x 3
-- = 193.0 s, the original) and played back slower by each song's lab tempo,
-- set by ear (0.332..0.34), so a tempo other than 1/3 runs the heard song a
-- little slower or faster than the original (NEON 0.332: 0.4 %, 0.9 s over
-- 3:42). Choreography is cut from videos on the original's clock, so it
-- follows this clock: the original song's seconds per real second, as heard
-- (`fileSpeed` on a track overrides the uploads' 3)
ClubConfig.UploadSpeed = 3
function ClubConfig.fileSpeed(track: Track?): number
	if track and typeof(track.fileSpeed) == "number" then return track.fileSpeed end
	return if track and track.lab then ClubConfig.UploadSpeed else 1
end
function ClubConfig.songRate(track: Track?, djSpeed: any): number
	return ClubConfig.trackRate(track, djSpeed) * ClubConfig.fileSpeed(track)
end

ClubConfig.Categories = { "댄스", "포즈·응원" }

ClubConfig.Dances = {
	{ key = "shuffle", name = "셔플", category = "댄스", animationId = 10714371274, looped = true },
	{ key = "line", name = "라인 댄스", category = "댄스", animationId = 10714383856, looped = true },
	{ key = "break", name = "브레이크", category = "댄스", animationId = 10714003221, looped = true },
	{ key = "floss", name = "플로스", category = "댄스", animationId = 10714340543, looped = true },
	{ key = "dorky", name = "코믹 댄스", category = "댄스", animationId = 10714069471, looped = true },
	{ key = "dolphin", name = "돌고래", category = "댄스", animationId = 10714068222, looped = true },
	{ key = "air", name = "에어 댄스", category = "댄스", animationId = 10713957138, looped = true },
	{ key = "swan", name = "스완", category = "댄스", animationId = 10714352930, looped = true },
	{ key = "baby", name = "베이비", category = "댄스", animationId = 10713983178, looped = true },
	{ key = "sandwich", name = "샌드위치", category = "댄스", animationId = 10714384494, looped = true },
	{ key = "samba", name = "삼바", category = "댄스", animationId = 10714386947, looped = true },
	{ key = "chacha", name = "차차", category = "댄스", animationId = 6862001787, looped = true },
	{ key = "toprock", name = "톱록", category = "댄스", animationId = 10714336041, looped = true },
	{ key = "sidetoside", name = "사이드 투 사이드", category = "댄스", animationId = 10714366910, looped = true },
	{ key = "aroundtown", name = "흔들흔들", category = "댄스", animationId = 10713981723, looped = true },
	{ key = "robot", name = "로봇", category = "댄스", animationId = 10714392151, looped = true },
	{ key = "rockon", name = "락 온", category = "댄스", animationId = 10714403700, looped = true },
	{ key = "idol", name = "아이돌", category = "댄스", animationId = 10714372526, looped = true },
	{ key = "hyper5g", name = "초고속 무브", category = "댄스", animationId = 10714371264, looped = true },
	{ key = "blockparty", name = "블록 파티", category = "댄스", animationId = 10713988674, looped = true },
	{ key = "twirl", name = "빙그르르", category = "댄스", animationId = 10714293450, looped = true },
	{ key = "fashionable", name = "패셔니스타", category = "포즈·응원", animationId = 10714091938, looped = true },
	{ key = "iceskate", name = "패션 스핀", category = "포즈·응원", animationId = 131669256082047, looped = true },
	{ key = "greatest", name = "내가 제일 잘 나가", category = "포즈·응원", animationId = 10714349037, looped = false },
	{ key = "heisman", name = "하이즈먼 포즈", category = "포즈·응원", animationId = 10714357129, looped = false },
	{ key = "jumpcheer", name = "환호 점프", category = "포즈·응원", animationId = 5895324424, looped = true },
	{ key = "applaud", name = "박수", category = "포즈·응원", animationId = 10713966026, looped = true },
	{ key = "hello", name = "안녕", category = "포즈·응원", animationId = 10714359093, looped = false },
	{ key = "highwave", name = "크게 손 흔들기", category = "포즈·응원", animationId = 10714362852, looped = true },
	{ key = "curtsy", name = "인사", category = "포즈·응원", animationId = 10714061912, looped = false },
	{ key = "celebrate", name = "축하", category = "포즈·응원", animationId = 10714016223, looped = true },
} :: {Dance}

ClubConfig.TempoMin = 0.5
ClubConfig.TempoMax = 2.0
ClubConfig.TempoStep = 0.1

-- How far away another player can be to show up under 같이 추기 (the panel
-- list). Clicking a player works anywhere inside the club.
ClubConfig.JoinRadius = 90

-- (D-745, user: "숨겨 놔, 나중에 쓸 거임") the lab values the user tuned by ear
-- for their own sped-up uploads (docs/04_ART/OLD_CLUB_PLAYLIST.md). Used again
-- by the user's K-POP uploads since D-755.
-- (D-765, user 2026-11-03: boost 3, no EQ; was boost 6, low -6 / mid 0.5 / high -7)
ClubConfig.SavedLabs = {
	userUpload = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" },
} :: {[string]: Lab}
local UP = ClubConfig.SavedLabs.userUpload

-- Shared club music. One track plays for everyone; the channel name is shown.
-- (user 2026-11-02, D-739: only Roblox's own licensed music — DistroKid on the
-- Creator Store, offered by Roblox — every K-POP upload before taken out; the
-- Bubble Pop / Get A Guitar choreographies went with them; D-755: the user's
-- K-POP uploads back after them, with the saved lab values.)
-- (D-745, user: default sound, no lab values: they play as uploaded at
-- ClubConfig.MusicVolume, the DJ's 🔊 slider on top)
ClubConfig.Playlist = {
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
	{ channel = "K-POP", title = "ATEEZ-BAD", soundId = 134942349436280, length = 51, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 2.5, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, choreo = {
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
	{ channel = "K-POP", title = "소녀시대-소원을 말해봐(Genie)", soundId = 128270208751659, length = 76, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 2.5, octave = 0.5, low = -5, mid = 2, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "현아-Bubble Pop", soundId = 76388700698178, length = 71, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 2.5, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" }, choreo = { 100736920067826, 133384041896194, 83466816721074, 133279932519664, 106558407160210, 80189218624271, 74977996210534, 128213782788357, 133713883432071, 79851078896686, 85867632664929 } },
	{ channel = "K-POP", title = "RIIZE-Get A Guitar", soundId = 91762270038050, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" }, choreo = {
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
	{ channel = "K-POP", title = "RIIZE-Love 119", soundId = 119473981131981, length = 58, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" } },
	{ channel = "K-POP", title = "YENA-Catch Catch", soundId = 80583279340768, length = 61, lab = { speed = 1, tempo = 0.34, volume = 10, boost = 3, octave = 0.5, low = -13, mid = 2.5, high = 4, engine = "sound" } },
	{ channel = "K-POP", title = "Hearts2Hearts-Lemon Tang", soundId = 97032815457241, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "aespa-Lemonade", soundId = 132067415333401, length = 62, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = -2.5, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Mirror", soundId = 139326796173276, length = 67, lab = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -10.5, mid = 5, high = 4.5, engine = "sound" } },
	-- (D-779, user 2026-11-03: new uploads "다섯시…분1102"; tempo = x1 length ÷ heard length, boost 3, -3/2/0)
	{ channel = "K-POP", title = "A2O LITE-NEON", soundId = 97511700575810, length = 74, lab = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" }, choreo = {
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
	{ channel = "K-POP", title = "SOYEON-퇴사할게여", soundId = 96358497474432, length = 71, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "ILLIT-체포하겠어", soundId = 139044453511745, length = 61, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = -1.5, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "RESCENE-LOVE-ATTACK", soundId = 71873496902418, length = 61, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "MY:RAKL-오색 낙원", soundId = 108027306922001, length = 61, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "Darla Jean-Dam Da Dee", soundId = 78077595750886, length = 73, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "머무르-꿈꾸던 어른이 되었나요", soundId = 120160897793669, length = 69, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Looks Can Kill", soundId = 135553051649506, length = 64, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, choreo = {
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
	{ channel = "K-POP", title = "IOI-갑자기", soundId = 73546697163709, length = 65, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 2.4, octave = 0.5, low = -9.5, mid = 6, high = 0, engine = "sound" } },
	-- (D-768, user 2026-11-03: new uploads; tempo = x1 length ÷ heard length 3:20 / 3:05)
	{ channel = "K-POP", title = "NMIXX-긴 소원(Birthday Wish)", soundId = 107782871991364, length = 67, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "NCT WISH-I SPY", soundId = 90694654380166, length = 62, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	-- (D-782, user 2026-11-03: new uploads "여섯시…분1102", the same way as D-779; 여섯시이분 TAEYEON-만찬가 103785084548518 does not load yet;
	-- D-794: IU-이 별로부터 96396723842714 removed, user)
	{ channel = "K-POP", title = "CORTIS-REDRED", soundId = 125703446596781, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, choreo = {
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
	{ channel = "K-POP", title = "BIG Naughty-노스탈지아", soundId = 116539470869444, length = 65, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "BIGBANG-BiiiG", soundId = 113809029583519, length = 55, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "BOYNEXTDOOR-ANIMAL", soundId = 130804487358433, length = 48, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
} :: {Track}

-- Music volume inside the club; it fades out over FadeDistance studs outside
-- the club zone (parts tagged "ClubZone").
ClubConfig.MusicVolume = 0.55
-- Short fade: outside the club building it is silent (user, 2026-10-20:
-- music starts in the narrow corridor, quiet on the stairs, full in the hall).
ClubConfig.FadeDistance = 6
-- Volume per club zone (ClubZone part attribute "Zone"). Inside a zone that
-- zone's level is used (the quietest when zones overlap); outside, the loudest
-- fade wins. The rooftop is quieter, like music coming up from below.
ClubConfig.ZoneVolumes = { Hall = 1, Corridor = 0.45, Stairs = 0.12, Rooftop = 0.3, Locker = 0.5 }
-- (D-834, user) more music zones as world boxes, beside the tagged ClubZone
-- parts: the locker room and its passage (tools/graybox/club_locker_1103.lua,
-- under the 국밥집 lot, x 131.6..231, z -365..-289.9, floor -24, ceiling -3)
ClubConfig.ExtraZones = {
	{ zone = "Locker", min = Vector3.new(130, -24, -366.6), max = Vector3.new(232.6, -3, -289.9) },
}
-- (D-834, user) silent boxes: no club music inside them, even a fade from a
-- zone next door (the 국밥집 stands right over the locker room and by the club's
-- north wall). From y -2: the locker room's ceiling is at -3.
ClubConfig.QuietBoxes = {
	{ min = Vector3.new(39, -2, -377), max = Vector3.new(159, 46, -291) }, -- 국밥집 (Hongdae_Layout.Gukbap)
}

--------------------------------------------------
-- Drinks (non-alcoholic only, D-043). Test list from the user (2026-10-20):
-- free drinks first, paid drinks below. `product` = MonetizationConfig key.
-- NOTE: 사이다/콜라/환타 are placeholder names for testing; before release
-- replace brand names (환타) with generic ones (e.g. 오렌지 소다).
--------------------------------------------------

export type DrinkVariant = {
	key: string,
	name: string,
	color: Color3,
}

-- tier 1 = free or a few coins, 2 = coins or Robux, 3 = Robux only
-- (docs/01_SYSTEMS/CLUB_SHOP_PRICING.md §4, D-270..D-274).
--   coins       coin price (VIP pays ClubConfig.VipCoinRate of it)
--   product     MonetizationConfig.Products key (Robux)
--   vipProduct  the same drink at the VIP price (a product of its own)
--   vipOnly     only VIP pass owners can buy it
--   variants    flavours / can colours picked before buying
--   look        what the bottle or can looks like (shown in the menu)
export type Drink = {
	key: string,
	name: string,
	color: Color3,
	tier: number,
	product: string?,
	vipProduct: string?,
	vipOnly: boolean?,
	coins: number?,
	variants: {DrinkVariant}?,
	look: string?,
}

-- Club light colours the DJ can pick (user, 2026-10-22: "보통 클럽에서 쓰는
-- 조명 색"). Lasers and beat lights use the colour; "rainbow" = colour cycle.
ClubConfig.LightColors = {
	{ key = "rainbow", name = "무지개", color = nil :: Color3? },
	{ key = "magenta", name = "마젠타", color = Color3.fromRGB(255, 40, 200) },
	{ key = "uv", name = "UV 보라", color = Color3.fromRGB(140, 60, 255) },
	{ key = "blue", name = "딥 블루", color = Color3.fromRGB(40, 80, 255) },
	{ key = "cyan", name = "시안", color = Color3.fromRGB(40, 230, 255) },
	{ key = "red", name = "레드", color = Color3.fromRGB(255, 40, 60) },
	{ key = "green", name = "그린 레이저", color = Color3.fromRGB(60, 255, 90) },
	{ key = "white", name = "화이트 스트로브", color = Color3.fromRGB(255, 255, 255) },
}
function ClubConfig.findLightColor(key: any)
	for _, entry in ipairs(ClubConfig.LightColors) do
		if entry.key == key then return entry end
	end
	return nil
end

-- Names and looks follow real drinks without using their brand names
-- (user list 2026-10-25; reference brand in the comment). Bottle shapes:
-- BottleShapes (user sheet 2026-10-27).
ClubConfig.Drinks = {
	-- tier 1
	{ key = "water", name = "물", tier = 1, color = Color3.fromRGB(190, 230, 255), look = "생수 페트병 · 파란 라벨" },
	{ key = "cider", name = "사이다", tier = 1, coins = 1, color = Color3.fromRGB(200, 255, 200), look = "초록 사이다 페트병" },
	{ key = "cola", name = "콜라", tier = 1, coins = 1, color = Color3.fromRGB(70, 35, 20), look = "사이다 페트병 · 빨간 라벨" },
	{ key = "orange", name = "오렌지 소다", tier = 1, coins = 5, color = Color3.fromRGB(255, 140, 0), look = "사이다 페트병 · 주황" },
	{ key = "lemonade", name = "레몬에이드", tier = 1, coins = 5, color = Color3.fromRGB(255, 232, 110), look = "사이다 페트병 · 노랑" },
	{ key = "blueade", name = "블루에이드", tier = 1, coins = 5, color = Color3.fromRGB(70, 160, 255), look = "사이다 페트병 · 파랑" },
	-- tier 2: 💰100 or 10 R$
	{ key = "ginger_brew", name = "진저 브루", tier = 2, coins = 100, product = "Drink_GingerBrew", -- Bundaberg
		color = Color3.fromRGB(240, 135, 75), look = "피치 오렌지 병 · 흰 글씨" }, -- (D-458: colours from the user's bottle photos)
	{ key = "monte", name = "몬테 스파클링", tier = 2, coins = 100, product = "Drink_Monte", -- San Pellegrino
		color = Color3.fromRGB(105, 165, 40), look = "라임 초록 병 · 연두 글씨" },
	{ key = "french_lemonade", name = "프렌치 레모네이드", tier = 2, coins = 100, product = "Drink_FrenchLemonade", -- Lorina
		color = Color3.fromRGB(242, 214, 70), look = "시트론 노랑 병 · 흰 글씨" },
	{ key = "golden_apple", name = "골든 애플 스파클링", tier = 2, coins = 100, product = "Drink_GoldenApple", -- Martinelli's
		color = Color3.fromRGB(238, 160, 40), look = "만다린 황금 병 · 흰 글씨" },
	{ key = "zzang_pop", name = "쨍팝", tier = 2, coins = 100, product = "Drink_ZzangPop", -- Poppi
		color = Color3.fromRGB(255, 90, 170), look = "가늘고 긴 반투명 병",
		variants = {
			{ key = "pink", name = "딸기", color = Color3.fromRGB(200, 30, 95) },
			{ key = "lime", name = "라임", color = Color3.fromRGB(170, 240, 60) },
			{ key = "orange", name = "오렌지", color = Color3.fromRGB(255, 150, 40) },
		} },
	-- tier 2: 💰150 or 15 R$ (energy drinks)
	{ key = "hot_boost", name = "핫부스트", tier = 2, coins = 150, product = "Drink_HotBoost", -- Hot6
		color = Color3.fromRGB(225, 45, 60), look = "워터멜론 빨강 병 · 노랑 글씨" },
	{ key = "green_claw", name = "그린 클로", tier = 2, coins = 150, product = "Drink_GreenClaw", -- Monster
		color = Color3.fromRGB(120, 175, 55), look = "페어 초록 병 · 연두 글씨" },
	{ key = "blue_wing", name = "블루 윙", tier = 2, coins = 150, product = "Drink_BlueWing", -- Red Bull
		color = Color3.fromRGB(120, 185, 245), look = "투명 병 · 연한 파랑 · 파란 글씨" },
	-- tier 3: Robux only (VIP price products: 20% off)
	{ key = "stack_hydro", name = "스택 하이드로", tier = 3, product = "Drink_StackHydro", vipProduct = "Drink_StackHydro_VIP", -- Cadence
		color = Color3.fromRGB(196, 120, 40), look = "호박색 병 · 크림 라벨 · 꿀벌" },
	{ key = "pastel_splash", name = "파스텔 스플래시", tier = 3, product = "Drink_PastelSplash", vipProduct = "Drink_PastelSplash_VIP", -- La Croix
		color = Color3.fromRGB(245, 125, 60), look = "반투명 오렌지 병 · 흰 P · 은은한 빛" },
	{ key = "skull_water", name = "스컬 캔 워터", tier = 3, product = "Drink_SkullWater", vipProduct = "Drink_SkullWater_VIP", -- Liquid Death
		color = Color3.fromRGB(18, 18, 20), look = "검정 스윙탑 병 · 은박 · 금색 해골 라벨" },
	-- VIP only (D-274)
	-- (user 2026-10-30: renamed in the spirit of the metallic champagne it was
	-- drawn from, a name of our own; non-alcoholic sparkling)
	{ key = "golmok", name = "메종 드 루미에르", tier = 3, vipOnly = true, product = "Drink_Golmok",
		-- (user photo 2026-10-27: the metallic champagne set's colours)
		color = Color3.fromRGB(212, 168, 70), look = "메탈 병 · 스페이드 엠블럼",
		variants = {
			{ key = "lavender", name = "레몬 라벤더", color = Color3.fromRGB(212, 168, 70) }, -- gold
			{ key = "rose", name = "생강 장미", color = Color3.fromRGB(232, 150, 185) }, -- pink
			{ key = "omija", name = "오미자 히비스커스", color = Color3.fromRGB(165, 35, 85) }, -- rose red
			{ key = "mulberry", name = "오디", color = Color3.fromRGB(95, 100, 112) }, -- dark silver
		} },
} :: {Drink}

-- VIP pays this share of a coin price (20% off, D-270).
ClubConfig.VipCoinRate = 0.8
ClubConfig.TierNames = { "1단계 · 무료 / 코인", "2단계 · 코인 또는 Robux", "3단계 · 프리미엄 (Robux)" }

function ClubConfig.findVariant(drink: Drink, key: any): DrinkVariant?
	if not drink.variants then return nil end
	for _, variant in ipairs(drink.variants) do
		if variant.key == key then return variant end
	end
	return drink.variants[1]
end

-- Coin price for this player (VIP discount when vip is true).
function ClubConfig.coinPrice(drink: Drink, vip: boolean): number?
	if not drink.coins then return nil end
	if vip and drink.coins >= 10 then
		return math.floor(drink.coins * ClubConfig.VipCoinRate + 0.5)
	end
	return drink.coins
end

-- Bottles: carried as a tool, placed on a table, poured into cups.
-- (no real carry limit for guests, user 2026-10-27, D-430: extra items wait
-- in the backpack; only cafe staff on shift keep a two-in-hand limit)
ClubConfig.MaxBottlesCarried = 99
ClubConfig.BottleServings = 6        -- cups per bottle
ClubConfig.BottleLifetime = 600      -- seconds on a table before it is cleared (tier 1)
-- (user 2026-10-30) the dearer the drink, the longer it stays: tier 1 10 min,
-- tier 2 20, tier 3 30, VIP drinks 1 hour (still gone when the owner leaves)
function ClubConfig.bottleLifetime(drink: any): number
	if drink and drink.vipOnly then return 60 * 60 end
	local tier = drink and drink.tier or 1
	return if tier >= 3 then 30 * 60 elseif tier == 2 then 20 * 60 else ClubConfig.BottleLifetime
end
ClubConfig.MaxCupsCarried = 99
ClubConfig.DrinkSeconds = 2.6
ClubConfig.GulpSoundId = 9114172296   -- "Drinking Cu Gulping 9 (SFX)", Pro Sound Effects (Roblox licensed)

-- DJ sound controls (user 2026-10-30): the playback speed, cycled by a
-- button like the laser speed, and the pitch, up / down in the same steps
-- (user 2026-10-30, in place of the treble / bass boosts). The pitch is the
-- one heard: a PitchShiftSoundEffect makes up for what the speed does to it
-- (its octave = pitch / speed, 0.25..4 with two effects in a row).
-- (user 2026-10-30, later) finer steps: speed x0.25..x2 by 0.05, pitch
-- x0.5..x2 by 0.1, both with − / + buttons.
local function steps(from: number, to: number, step: number): {number}
	local list = {}
	for i = 0, math.floor((to - from) / step + 0.5) do
		table.insert(list, math.floor((from + i * step) * 100 + 0.5) / 100)
	end
	return list
end
-- (user 2026-11-01, later: all three up to x5)
ClubConfig.MusicSpeeds = steps(0.25, 5, 0.05)
ClubConfig.MusicPitches = steps(0.5, 5, 0.1)
-- (user 2026-11-01) the DJ's mixer on the turntable: speed, volume and the
-- PitchShift octave, each with − / +. The volume is a multiplier on the
-- track's own volume (0 = silent .. x2); the pitch is now the octave itself
-- (times the track's own octave), no longer made up for the speed.
ClubConfig.MusicVolumes = steps(0, 5, 0.1)

-- the place in a list nearest to a value (an old setting between two steps)
function ClubConfig.nearestStep(list: {number}, value: any): number
	local v = if typeof(value) == "number" then value else 1
	local best, bestDiff = 1, math.huge
	for i, x in ipairs(list) do
		if math.abs(x - v) < bestDiff then best, bestDiff = i, math.abs(x - v) end
	end
	return best
end

-- Who may pour from a placed bottle.
ClubConfig.Visibility = {
	{ key = "all", name = "모든 사람" },
	{ key = "friends", name = "친구만" },
	{ key = "me", name = "나만" },
}

function ClubConfig.findDrink(key: any): Drink?
	if typeof(key) ~= "string" then return nil end
	for _, drink in ipairs(ClubConfig.Drinks) do
		if drink.key == key then return drink end
	end
	return nil
end

function ClubConfig.findDance(key: any): Dance?
	if typeof(key) ~= "string" then return nil end
	for _, dance in ipairs(ClubConfig.Dances) do
		if dance.key == key then return dance end
	end
	return nil
end

function ClubConfig.clampTempo(speed: any): number
	if typeof(speed) ~= "number" or speed ~= speed then return 1 end
	local stepped = math.floor(speed / ClubConfig.TempoStep + 0.5) * ClubConfig.TempoStep
	return math.clamp(stepped, ClubConfig.TempoMin, ClubConfig.TempoMax)
end

local function insideTagged(tag: string, position: Vector3): boolean
	for _, box in ipairs(game:GetService("CollectionService"):GetTagged(tag)) do
		if box:IsA("BasePart") then
			local p = box.CFrame:PointToObjectSpace(position)
			local half = box.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Inside the club (hall or rooftop): boxes tagged "ClubInterior" by the
-- graybox script. The 💃 button and tapping players only work in here.
-- Club entry only at night (CLUB.md §20, D-264 / D-267, code D-320). It is on
-- by itself once the game clock flows (DayNightConfig.FixedClockTime = nil);
-- while the clock is pinned for building, the club stays open.
ClubConfig.NightEntry = {
	-- (on again, user 2026-10-30: the club opens only at night; was off for testing since 2026-10-27)
	Enabled = true,
	OpenHour = 18, -- 18:00 .. 06:00
	CloseHour = 6,
	-- where someone who walks in by day is put back: the sidewalk in front of the door
	-- (layout v8, 2026-10-27: the club moved 24 north, door z -186 → -210)
	ExitPosition = Vector3.new(41, 3.6, -210),
	DoorPosition = Vector3.new(46.5, 8, -210), -- the "opens in n min" sign
}

function ClubConfig.isNightOpen(clock: number): boolean
	local n = ClubConfig.NightEntry
	return clock >= n.OpenHour or clock < n.CloseHour
end

-- (D-846, user: "락커룸에서도 … 클럽 안에서 하는 기능 다 가능하게 해") the
-- locker room counts as inside the club too: the song banner, dances, song
-- list, skip vote, choreography (its ExtraZones box)
local function inLocker(position: Vector3): boolean
	for _, extra in ipairs(ClubConfig.ExtraZones) do
		local lo, hi = extra.min, extra.max
		if extra.zone == "Locker" and position.X >= lo.X and position.X <= hi.X and position.Y >= lo.Y and position.Y <= hi.Y
			and position.Z >= lo.Z and position.Z <= hi.Z then
			return true
		end
	end
	return false
end

function ClubConfig.isInClub(position: Vector3): boolean
	return insideTagged("ClubInterior", position) or inLocker(position)
end

-- Dancing is allowed in the club and on photo booth stages ("PhotoStage"
-- boxes), where the 인생네컷 pose panel uses the same dances.
function ClubConfig.canDance(position: Vector3): boolean
	return ClubConfig.isInClub(position) or insideTagged("PhotoStage", position)
end

-- How long a player must stay outside before their dance stops (doorways,
-- the rooftop elevator ride).
ClubConfig.OutsideGrace = 1.5

-- Where the 불꽃 판매원 stands, from the BartenderSpot (its +X runs along the
-- bar, its look faces the room). D-750, user's live screenshot: by the north
-- wall, just east of the hall doorway to the VIP stairs (world about 128,
-- -270), facing into the room. Before: 8 along the bar (76, -170).
ClubConfig.ItemSellerOffset = CFrame.new(-92, 0, -52) * CFrame.Angles(0, -math.pi / 2, 0)

-- A table (bottles, sparkler bucket) stays this long after its owner leaves the
-- game, so a quick rejoin finds it still theirs (D-770, user: 2-3 min, not
-- cleared at once). DrinkService / SparkleService.
ClubConfig.TableKeepSeconds = 180

return ClubConfig
