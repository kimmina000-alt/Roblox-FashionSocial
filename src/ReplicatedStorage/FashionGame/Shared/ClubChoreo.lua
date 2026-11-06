--!strict
-- (D-888, user 2026-11-05: ClubConfig split up, one file per kind) Choreography tuning: smoothing, retarget, per-animation fixes, shake / slide checks.
-- ClubConfig re-exports every field below, so ClubConfig.ChoreoFixes keeps working.


local M = {}

-- (D-811, user: "미세하게 바들바들 떨리는 부분 보정 … 멀쩡한 안무까지 수정하지
-- 말고") the choreography animations are captured at 24 keyframes a second
-- with small back-and-forth zigzags in the joints. ChoreoSmooth eases only
-- the keyframes where a joint goes back and forth by less than `maxStep`
-- degrees (`passes` times); the rest of the dance stays exactly as made.
-- nil = off.
M.ChoreoSmoothing = { maxStep = 8, passes = 4 } :: { maxStep: number, passes: number }?

-- (D-843) the choreography captures carry a spine, a chest and two
-- clavicles that an R15 body does not have; true folds their turns onto the
-- waist and the shoulders (ChoreoSmooth.retarget) so that motion shows.
-- The toes have nowhere to go on R15 and stay out. false = off.
M.ChoreoRetarget = true

-- (D-817) a dancer following a choreography walks its dance path (D-813),
-- and is eased back toward where the dance began over about this many
-- seconds, so the drift the pieces add up to does not carry them off the
-- floor. nil = no easing back.
M.ChoreoDriftReturn = 8 :: number?

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
M.ChoreoFixes = {
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
	-- (D-895, user: "가슴 튕기는 안무 반박자만 빠르게") every pop 0.25 s earlier
	-- (the pops come about every 0.5 s, one beat)
	[82346668311878] = { still = { { from = 1.4, to = 5.2 } }, pops = { at = { 1.30, 1.90, 2.30, 2.78, 3.33, 3.83 }, sizes = { 1, 0.6, 1, 0.6, 1, 0.6 },
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
	-- 소녀시대-Genie (D-897, the mirrored cover video HrWrWtWPMUU, SNSD_Genie_centercut):
	-- `still` where the clip's member stands in the video (still_from_video.py)
	[122991710923104] = { still = { from = 0.1, to = 5.44 } }, -- 1
	[118462778307290] = { still = { from = 4.04, to = 5.54 } }, -- 2
	[127323208506008] = { still = { { from = 0.83, to = 1.5 }, { from = 1.77, to = 3.17 } } }, -- 3
	[101676644495491] = { still = { from = 0.1, to = 4.97 } }, -- 5
	-- RESCENE-LOVE-ATTACK (D-903, the mirrored practice video nXDQPm_HnFc): `still`
	-- where the clip's member stands in the video (still_from_video.py)
	[109011245162387] = { still = { from = 0.13, to = 1.2 } }, -- 1
	[118832898913501] = { still = { from = 4.77, to = 5.6 } }, -- 8
	-- NCT WISH-I SPY (D-912, the mirrored practice video ILeBVk4x_XQ): `still` where
	-- the clip's member stands in the video (still_from_video.py)
	[97906912240537] = { still = { from = 1.07, to = 1.8 } }, -- 5
} :: {[number]: { steady: { from: number, to: number, parts: {string}?, passes: number? }?, turn: number?,
	pops: { at: {number}, sizes: {number}?, push: number, lift: number?, arch: number, out: number?, back: number?, sink: boolean? }?, calm: boolean?,
	hold: { from: number, to: number }?, still: any?, turnEase: string?,
	spin: { from: number, to: number }?,
	pose: any? }}

-- (D-851) the slower wobble clean-up for pieces with `calm` in ChoreoFixes:
-- a turn back between two swings of at most maxLen keyframes and maxSwing
-- degrees is eased, passes times, never more than cap degrees off the
-- capture (NEON 1: 118 such swings → 51, about what other pieces have)
M.ChoreoCalm = { maxSwing = 10, maxLen = 4, passes = 6, cap = 5 }

-- (D-881, user: NEON 2:33 "벌벌 떠는 움직임 … 다른 부분에도 이런 달달 떨림 발견해서
-- 떨림 수정") in every piece, the stretches where a joint still shakes after the
-- clean-up above (turn backs of minSwing..maxSwing degrees, at most maxGap s
-- apart, `count` or more within `window` s) are eased like a `steady` fix,
-- that joint only and never more than `cap` degrees (ChoreoSmooth.shaky).
-- Measured on the cleaned keyframes: 8 or more in 0.5 s was 481 stretches over
-- the six songs (NEON 2:30-2:31 hands 9); most of a dance has 3-6. nil = off.
M.ChoreoShake = { minSwing = 2, maxSwing = 25, maxGap = 0.2, count = 8, window = 0.5, edge = 0.15, passes = 4, cap = 8 } :: {[string]: number}?

-- (D-880, user: NEON 2:51 "제자리에 서서 오른쪽팔을 뻗는 안무인데 위치가 왔다갔다 함 …
-- 다리에 움직임 없는데 위치 변동 있는 부분 … 전체적으로 스캔 후 모두 잡아내서 수정. 안무
-- 있는 곡 모두 해당") stretches (seconds into each piece) where the capture's feet,
-- worked out from its leg joints on an R15 body, keep their stance (left to
-- right foot within 0.25 studs), neither lifts (0.2), and yet both go 0.4 studs
-- or more in 0.5 s, or wander 0.5 back and forth: the body slides while the legs
-- stand. They become `still` stretches (no travel; added to ChoreoFixes below).
M.ChoreoSlideStill = {
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
	-- 소녀시대-Genie (D-897)
	[122991710923104] = { { 6.0, 6.7 } }, [101676644495491] = { { 4.0, 4.8 }, { 9.3, 10.0 }, { 11.5, 12.4 } },
	[107809363798601] = { { 3.2, 3.9 }, { 5.6, 6.6 } }, [97769840770691] = { { 3.1, 3.8 } }, [108803469428764] = { { 7.2, 8.7 } },
	[76060752564499] = { { 0.7, 1.4 }, { 8.2, 9.0 } }, [136331779515321] = { { 2.9, 4.5 }, { 5.0, 5.9 } },
	[94271336995595] = { { 6.6, 7.2 }, { 9.9, 10.5 } }, [76687116604339] = { { 0.2, 0.9 }, { 1.0, 1.6 }, { 4.1, 4.7 } },
	[124091598492660] = { { 1.0, 1.8 } }, [98754942494305] = { { 0.9, 1.5 } }, [130670560182985] = { { 5.3, 6.0 } },
	[105428606733839] = { { 0.0, 0.5 }, { 0.6, 1.2 }, { 1.7, 2.3 } }, [127287424998997] = { { 0.5, 1.1 } }, [115574620758490] = { { 7.3, 7.9 } },
	-- RESCENE-LOVE-ATTACK (D-903)
	[77108502823118] = { { 0.9, 1.5 } }, [110961201759433] = { { 1.7, 2.4 } }, [70453746052130] = { { 0.3, 1.0 }, { 0.9, 2.3 }, { 2.5, 3.3 } },
	[108475995123642] = { { 0.4, 1.0 } }, [108964771979987] = { { 6.3, 6.9 } }, [88670191702155] = { { 8.1, 8.7 } },
	[115864358490692] = { { 2.0, 2.8 }, { 6.6, 7.2 }, { 10.3, 10.9 } }, [105227322276080] = { { 2.7, 3.4 } },
	[76304830605030] = { { 4.6, 5.2 }, { 7.6, 8.3 } }, [115786464203055] = { { 2.6, 3.3 } }, [73284838254272] = { { 6.5, 7.2 } },
	[80227668256511] = { { 3.3, 3.9 } }, [72915658378938] = { { 0.3, 0.9 } }, [104212164342204] = { { 6.7, 7.4 } },
	[83427493012714] = { { 5.6, 6.3 }, { 6.3, 7.0 } },
	-- NCT WISH-I SPY (D-912)
	[83299308409543] = { { 2.2, 2.9 } }, [122217205660431] = { { 0.7, 1.4 } }, [71548910990490] = { { 0.3, 1.1 }, { 4.0, 4.6 } },
	[137433206050479] = { { 3.3, 3.9 } }, [119352807886781] = { { 0.0, 0.5 }, { 0.6, 1.6 } }, [80718941616155] = { { 0.1, 0.7 }, { 4.8, 5.4 } },
	[76871177818406] = { { 1.0, 1.7 } }, [84123931984762] = { { 3.3, 4.1 } }, [74058508632786] = { { 0.2, 0.9 } },
	[127691136882789] = { { 0.3, 0.9 }, { 2.3, 2.9 } }, [73998534307708] = { { 8.0, 8.6 } }, [117524452063760] = { { 7.0, 7.7 } },
	-- ILLIT-체포하겠어 (D-914)
	[110040253056586] = { { 6.7, 7.6 } }, [116782676046427] = { { 1.2, 1.8 } }, [130744405360835] = { { 1.5, 2.5 } },
	[75102459386899] = { { 4.9, 5.5 } }, [128174978668663] = { { 1.7, 2.5 } }, [76359264534217] = { { 9.4, 10.3 } },
	[99715197125931] = { { 1.6, 2.8 } }, [108969470552658] = { { 4.9, 5.6 }, { 6.0, 6.7 }, { 6.8, 7.9 } }, [99241032937972] = { { 4.7, 5.4 } },
	[90778610748932] = { { 9.1, 9.7 } }, [119318712525281] = { { 5.7, 6.4 } }, [138780635090818] = { { 3.9, 4.9 }, { 5.4, 6.7 } },
	[134859541553614] = { { 5.9, 6.7 } }, [127453915676688] = { { 7.5, 8.4 } },
	-- BOYNEXTDOOR-ANIMAL (D-916)
	[130036196270388] = { { 2.5, 3.1 }, { 4.5, 5.1 } }, [106354393645678] = { { 3.0, 3.7 } }, [97744184558515] = { { 1.5, 2.1 }, { 7.2, 7.8 } },
	[100329215645751] = { { 7.7, 8.3 } }, [78840320722064] = { { 0.7, 1.4 }, { 1.5, 2.5 } }, [123997379474433] = { { 4.2, 5.4 } },
	[136007113687275] = { { 1.8, 2.4 }, { 4.1, 4.8 } }, [89056804683617] = { { 1.7, 2.4 }, { 3.4, 4.0 } }, [116387739582454] = { { 1.7, 3.0 } },
	-- ALLDAY PROJECT-CRASH (D-918)
	[85184392148752] = { { 3.5, 4.2 }, { 5.0, 5.6 } }, [86200130207984] = { { 4.0, 4.6 } }, [119507357461993] = { { 11.1, 12.1 } },
	[124516959620423] = { { 1.3, 1.9 } }, [124646840847010] = { { 5.6, 6.3 } }, [140259213928051] = { { 0.6, 1.4 } },
	-- 키키-Pop Off (D-936)
	[79453984815360] = { { 6.0, 6.6 } }, [137960851963972] = { { 4.4, 5.0 } }, [114899602408190] = { { 2.9, 3.5 }, { 5.7, 6.3 } },
	[82593368218356] = { { 6.9, 7.5 } }, [89349893602236] = { { 6.0, 6.9 }, { 7.0, 7.6 } }, [93822640757068] = { { 9.7, 10.4 }, { 10.6, 11.3 } },
	[89496459962506] = { { 0.2, 0.9 } }, [106148688158261] = { { 4.0, 4.6 } }, [126423548513152] = { { 5.6, 6.2 } },
	[87535109402600] = { { 5.2, 6.3 } }, [114431038976349] = { { 3.2, 3.8 } },
	-- RESCENE-Pretty Girl (D-937)
	[108961429650022] = { { 4.5, 5.1 } }, [123817870898356] = { { 1.7, 2.4 }, { 6.1, 6.8 } }, [112928130718608] = { { 4.1, 5.2 } },
	[78155856168233] = { { 4.6, 5.5 }, { 5.7, 6.8 } }, [108885997292893] = { { 0.9, 2.2 } }, [118658921583531] = { { 8.4, 9.1 } },
	[74902277201730] = { { 3.9, 4.7 }, { 5.9, 7.1 } }, [110044834729128] = { { 4.6, 5.7 } }, [86500685186308] = { { 8.2, 8.8 } },
	[93265378210483] = { { 0.1, 1.0 } }, [114627519168898] = { { 0.9, 1.5 } }, [90231422396171] = { { 7.1, 7.8 } },
	[121645451915137] = { { 2.7, 3.3 }, { 3.8, 4.6 }, { 5.0, 6.0 } }, [79626676434376] = { { 3.1, 4.1 }, { 4.5, 5.2 } },
	[81645905885514] = { { 1.5, 2.2 }, { 3.4, 4.0 } }, [84166534427168] = { { 6.5, 7.2 } }, [117439090388503] = { { 4.5, 5.4 } },
	-- RIIZE-Love 119 (D-938)
	[84899474236257] = { { 0.7, 1.9 }, { 2.0, 3.1 }, { 3.3, 4.5 }, { 4.7, 5.4 } }, [77269060609340] = { { 2.4, 3.0 } },
	[101539030624816] = { { 3.4, 4.3 }, { 4.4, 5.0 }, { 9.4, 10.0 } }, [75370013537988] = { { 0.2, 2.0 }, { 2.5, 3.5 } },
	[140553219106220] = { { 0.4, 1.0 } }, [103134109095683] = { { 1.5, 2.1 } }, [83720687579594] = { { 0.7, 1.3 }, { 2.5, 3.4 } },
	[112123988214223] = { { 0.7, 1.3 } }, [98464771574081] = { { 1.0, 1.7 } },
	[76049029842393] = { { 0.4, 1.0 }, { 3.0, 4.1 }, { 4.3, 5.2 }, { 7.0, 7.9 } }, [95981548117869] = { { 3.4, 4.1 } },
} :: {[number]: {{number}}}
for id, stretches in pairs(M.ChoreoSlideStill) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	local still = if fix.still == nil then {} elseif fix.still.from then { fix.still } else table.clone(fix.still)
	for _, s in ipairs(stretches) do table.insert(still, { from = s[1], to = s[2] }) end
	fix.still = still
end

return M
