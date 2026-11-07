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
-- (D-984) every piece's keyframes, the hips' turn too, averaged with their neighbours
-- in time (Gaussian, seconds; ChoreoSmooth.dejitter): the wobble that made feet and legs
-- tremble goes, beat-sized moves keep about 93 % of their size (0 turns it off)
M.ChoreoDejitter = { sigma = 0.03 } :: { sigma: number }?
-- (D-998, user: "손목·발목은 다듬지 않기") parts the automatic tremble clean-ups leave as captured
M.ChoreoKeepDetail = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" } :: {string}?
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
	-- (D-966) `sharp`: the pops are meant to snap, so the snap limiter is off
	[82346668311878] = { sharp = true, still = { { from = 1.4, to = 5.2 } }, pops = { at = { 1.30, 1.90, 2.30, 2.78, 3.33, 3.83 }, sizes = { 1, 0.6, 1, 0.6, 1, 0.6 },
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
	-- (D-962, user: 0:04 "팔 들고 등 돌리고 있다가 뒤도는 거 끊겨서 보임 … 팔
	-- 내리면서 뒤도는 거 슬로우 걸어서 자연스럽게 이어지게") the held pose (back
	-- turned, arm up) let go at 6.04 straight into a pose 65° round, then
	-- turned to the front in 0.4 s: now it lets go at 6.0 easing over 0.5 s
	-- into the turn, which plays at half speed (anim 6.2-6.9 over 1.4 s, the
	-- arms coming down), and the still front pose after it makes the time up;
	-- (0:07-0:08 "뒤로 움직이는 게 보임") the feet slide 0.5-1.2 studs at
	-- 8.6-10.7, and the kick spin (0:11 "뚝뚝 끊김") travelled 2.5 studs out and
	-- back: in place from 8.6 to the end of the spin
	[118329772913374] = { calm = true, hold = { from = 4.83, to = 6.0, ease = 0.6 },
		warp = { { from = 6.0, to = 7.4, play = { 6.2, 6.9 }, ease = 0.6 }, { from = 7.4, to = 7.55, play = { 6.9, 7.55 } } },
		still = { { from = 8.6, to = 13.6 } },
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
	[128256391320572] = { calm = true }, [100410498984971] = { calm = true }, -- (126736648781925 below)
	[76437753036430] = { calm = true }, [136355327951443] = { calm = true }, [117451819045051] = { calm = true },
	[133401623277764] = { calm = true }, [106546379406531] = { calm = true }, [71570705300325] = { calm = true },
	[121393866689759] = { calm = true }, -- (114419952125075 below)
	-- NEON 5 (D-852, user: 0:53 "이 자세로 잠시 머무는데 이때 떨림 삭제")
	-- (D-873, user: "50초 가만히 있기") the members hold that low pose from song
	-- 49.75 to 52.1 (video 51.75-54.1); the capture gets up from 51.6, so the
	-- pose is held to 52.0 (anim 9.95)
	-- (D-962, user: 0:52 "너무 훽훽 돌아 끊기지 않게 자연스러운 회전. 시간 부족하면
	-- 회전 한 번만 해") the capture turns once at 11.0-12.3 with a 151° jump in
	-- one keyframe: one even turn over 1.4 s
	[93933273398995] = { calm = true, steady = { from = 7.85, to = 9.45, passes = 8 }, hold = { from = 7.9, to = 9.95 },
		spin = { from = 10.95, to = 12.35, ease = "both" } },
	-- NEON 8 (D-852, user: 1:22 "한 바퀴 도는 게 매끄럽지 않음"): 7 ends
	-- mid-spin (about 400°/s), so 8 carries on at that speed and slows down
	-- (its blend 1 → 0.85, the same as the turn, so nothing jumps when it ends)
	[114466589507598] = { calm = true, spin = { from = 8.47, to = 8.97 } },
	-- (D-875, user: "한바퀴 도는 동작은 제 시간 안에 매끄럽게 한 바퀴 … 1:25 전후")
	-- 8 spins once to the left at 3.2-3.9 s but stalls near -140° and then
	-- jumps 160° in one keyframe: one even turn instead, to 4.15 where the
	-- capture's own facing settles (no step when it lets go)
	-- (D-962, user: 1:26 "다리 가만히 있는데 캐릭터 전체가 앞으로 이동") both feet
	-- slide 1 stud at 5.6-6.2: kept in place
	[84027575690735] = { turn = 0.85, turnEase = "out", spin = { from = 3.2, to = 4.15, turns = -1, ease = "both" },
		still = { { from = 5.5, to = 6.3 } } },
	-- NEON 10 / 11 (D-962, user: 1:40, 1:48 "한바퀴 자연스럽게 도는 걸로") 10 turns
	-- half way and back at 7.7-8.1 (131° in a keyframe); 11 turns once at
	-- 2.3-3.4 with a 184° jump and a stall: one even turn each
	[124518142645731] = { spin = { from = 7.5, to = 8.6, turns = -1, ease = "both" } },
	[126736648781925] = { calm = true, spin = { from = 2.25, to = 3.5, ease = "both" } },
	-- NEON 15 (D-962, user: 2:09 "캐릭터 뒤로 살짝 이동. 다리 달달 떠는 거") the
	-- feet slide at 2.8-3.3 and 4.2-4.5; the low stance shakes before
	[111932052760637] = { steady = { from = 1.3, to = 4.6, passes = 8 }, still = { { from = 1.3, to = 5.0 } } },
	-- NEON 17 (D-852, user: 2:31 "다리가 진동함 … 저 자세로 뒤로 빠지는데 저
	-- 자리에 고정")
	-- (D-881, user: 2:33 "벌벌 떠는 움직임"): the hands and arms shook there too
	-- (2:30-2:31.5, 5-7 turn backs in 0.5 s): the whole body, not only the legs
	-- (D-962, user: 2:33 "허리 숙이고 가만히 있는데 캐릭터 천천히 뒤로 움직이는 거")
	-- the hips creep 0.5 stud back at 3.5-6.3: kept in place to 6.4, and the
	-- bent-over pose smoothed too (15 small turn-backs in 0.5 s at 2:32)
	[96973609514230] = { calm = true, steady = { from = 0.4, to = 6.3, passes = 8 },
		still = { from = 0.4, to = 6.4 } },
	-- NEON 22 (D-962, user: 3:31 "뒤로 감. 제자리에", 3:38 "마지막 포즈 달달 떠는
	-- 거") the last piece walks 5 studs back with the feet; in place, and the
	-- end pose smoothed
	[114419952125075] = { calm = true, still = { { from = 0.3, to = 9.4 } }, steady = { from = 5.5, to = 9.4, passes = 8 } },
	-- RIIZE-Get A Guitar 15 (D-882, user: 1:54 "한바퀴 도는 거 매끄럽게"): the turn at
	-- 16.4-16.6 s lurched 157° in one keyframe; one even turn instead
	-- (D-962, user: 1:38 "무릎 엄청 빠르게 찍고 내리는데 올릴 때 엄청 살짝 슬로우
	-- 줘서 부드럽게 … 안무 안 밀리게 앞뒤 안무 조금씩 조정") the left knee comes up
	-- in 0.2 s (1.30-1.50): the 0.75 s before it play a little faster (1.17x)
	-- so the knee starts rising at 1.14 and takes 0.36 s (0.7x), up at the
	-- same moment as before; (1:52 "왼쪽 다리 돌리면서 발로 땅 두 번 찍는데
	-- 슬로우 걸어서 부드럽게 한 번만 찍는 걸로. 뒤에 땅 밟는 안무의 발 위치
	-- 맞추기") the leg swings round and taps at 15.9, then taps again at 16.0-16.2:
	-- 15.3-15.9 plays over 15.3-16.25 (0.63x, one tap), and the feet ease 0.3 s
	-- into the step that follows (the left foot 0.4 stud on)
	-- (D-966, user: "수정한 모션 굉장히 부드럽고 자연스러움. 그러나 바로 다음 안무
	-- 버벅거림 … 깔끔하게 하나로 정리") the turn after the tap started at 16.07,
	-- inside the slowed tap (15.3-16.25), so the body jumped into it part way
	-- round while the tap's ease ran: one even turn from where the tap ends
	[129447992418977] = { spin = { from = 16.25, to = 17.25, ease = "both" },
		warp = { { from = 0.5, to = 1.14, play = { 0.5, 1.25 } }, { from = 1.14, to = 1.5, play = { 1.25, 1.5 } },
			{ from = 15.3, to = 16.25, play = { 15.3, 15.9 }, ease = 0.3 } } },
	-- RIIZE-Get A Guitar 1 (D-962, user: "처음에 무릎 숙이고 있는 거 펴"): the
	-- first pose stands on bent knees (hips 0.3-0.5 stud low) until about 3.5 s:
	-- legs straight (the turn-out kept) and the hips up by as much, easing back
	-- into the capture by 3.9
	[119819611123433] = { pose = { { from = 0, to = 3.9, ease = 0.4, keys = {
		{ t = 0.0, set = { LeftUpperLeg = { 0, 10, 3 }, LeftLowerLeg = { 0, 1, -3 }, LeftFoot = { 0, -1, -3 }, RightUpperLeg = { 0, -9, 2 }, RightLowerLeg = { 0, -3, -3 }, RightFoot = { 0, -14, 3 } },
			move = { LowerTorso = { 0, 0.33, 0 } } },
		{ t = 0.7, set = { LeftUpperLeg = { 0, 10, 3 }, LeftLowerLeg = { 0, 1, -3 }, LeftFoot = { 0, -1, -3 }, RightUpperLeg = { 0, -9, 2 }, RightLowerLeg = { 0, -3, -3 }, RightFoot = { 0, -14, 3 } },
			move = { LowerTorso = { 0, 0.43, 0 } } },
		{ t = 1.4, set = { LeftUpperLeg = { 0, 10, 3 }, LeftLowerLeg = { 0, 1, -3 }, LeftFoot = { 0, -1, -3 }, RightUpperLeg = { 0, -9, 2 }, RightLowerLeg = { 0, -3, -3 }, RightFoot = { 0, -14, 3 } },
			move = { LowerTorso = { 0, 0.35, 0 } } },
		{ t = 2.1, set = { LeftUpperLeg = { 0, 10, 3 }, LeftLowerLeg = { 0, 1, -3 }, LeftFoot = { 0, -1, -3 }, RightUpperLeg = { 0, -9, 2 }, RightLowerLeg = { 0, -3, -3 }, RightFoot = { 0, -14, 3 } },
			move = { LowerTorso = { 0, 0.41, 0 } } },
		{ t = 2.8, set = { LeftUpperLeg = { 0, 10, 3 }, LeftLowerLeg = { 0, 1, -3 }, LeftFoot = { 0, -1, -3 }, RightUpperLeg = { 0, -9, 2 }, RightLowerLeg = { 0, -3, -3 }, RightFoot = { 0, -14, 3 } },
			move = { LowerTorso = { 0, 0.49, 0 } } },
		{ t = 3.5, set = { LeftUpperLeg = { 0, 10, 3 }, LeftLowerLeg = { 0, 1, -3 }, LeftFoot = { 0, -1, -3 }, RightUpperLeg = { 0, -9, 2 }, RightLowerLeg = { 0, -3, -3 }, RightFoot = { 0, -14, 3 } },
			move = { LowerTorso = { 0, 0.28, 0 } } },
	} } } },
	-- 2 (D-962, user: "19~21초에 위치 이동하는 거 수정. 걷는 모션 없잖아") the body
	-- slides 3.5 studs while turning at 8.5-9.8 (song 18.7-20.0): in place
	[97097804325917] = { still = { { from = 8.4, to = 9.8 } } },
	-- 11 (D-962, user: 1:20 "오른쪽 다리는 고정하고 왼쪽다리 쭉 뻗었다가 끌고 오는
	-- 모션으로") the capture steps the left foot out and shifts the whole body
	-- 1.2 studs (8.7-9.47): in place, the right leg held as at 8.6, the left leg
	-- stretched straight out to the side by 9.05 and dragged back in by 9.45;
	-- the hips held as at 8.6 too (their turn set, their height by `move`:
	-- `set` takes the joint's own offset away), so the right foot stays put
	-- (D-966, user: "1:20 팔 움직임이 뚝 끊김 앞에 안무와 이어지도록") the hips turned
	-- 45° to the held angle and back in 0.12 s each way, throwing the arms
	-- round: it eases in over 0.35 s from 8.2 and does not ease out (to is
	-- past the end), so 12's blend (0.7 s) carries it on
	[88430566939812] = { still = { { from = 8.55, to = 9.47 } }, pose = { { from = 8.2, to = 9.9, ease = 0.35, keys = {
		{ t = 8.62, set = { LowerTorso = { 15, -16, -7 }, RightUpperLeg = { 12, -28, 35 }, RightLowerLeg = { -59, -2, -4 }, RightFoot = { 26, -27, -10 },
			LeftUpperLeg = { 30, 10, -8 }, LeftLowerLeg = { -50, 4, 0 }, LeftFoot = { 5, 0, -3 } }, move = { LowerTorso = { 0, -0.87, 0 } } },
		{ t = 8.8, set = { LowerTorso = { 15, -16, -7 }, RightUpperLeg = { 12, -28, 35 }, RightLowerLeg = { -59, -2, -4 }, RightFoot = { 26, -27, -10 },
			LeftUpperLeg = { 5, 0, -14 }, LeftLowerLeg = { -15, 0, 0 }, LeftFoot = { -15, 0, 0 } }, move = { LowerTorso = { 0, -0.87, 0 } } },
		{ t = 9.05, set = { LowerTorso = { 15, -16, -7 }, RightUpperLeg = { 12, -28, 35 }, RightLowerLeg = { -59, -2, -4 }, RightFoot = { 26, -27, -10 },
			LeftUpperLeg = { 0, 0, -22 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { -25, 0, 0 } }, move = { LowerTorso = { 0, -0.87, 0 } } },
		{ t = 9.15, set = { LowerTorso = { 15, -16, -7 }, RightUpperLeg = { 12, -28, 35 }, RightLowerLeg = { -59, -2, -4 }, RightFoot = { 26, -27, -10 },
			LeftUpperLeg = { 0, 0, -22 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { -25, 0, 0 } }, move = { LowerTorso = { 0, -0.87, 0 } } },
		{ t = 9.45, set = { LowerTorso = { 15, -16, -7 }, RightUpperLeg = { 12, -28, 35 }, RightLowerLeg = { -59, -2, -4 }, RightFoot = { 26, -27, -10 },
			LeftUpperLeg = { 5, 0, -6 }, LeftLowerLeg = { -20, 0, 0 }, LeftFoot = { 5, 0, 0 } }, move = { LowerTorso = { 0, -0.87, 0 } } },
	} } } },
	-- RESCENE-Pretty Girl (D-973, user: "36초 회전 매끄럽게 앞뒤 동작 빠르게 하든
	-- 조절해서 시간 안에 뒤에 안무 안 밀리게"): the piece at 26.25 turns half way
	-- (34.3-35.8), stalls 0.6 s on its last pose, and the next piece's 1 s blend
	-- whips the other half round (12.5° a frame): one turn at one speed
	-- instead, 34.25-36.33 linear with 125° more than the capture's own half,
	-- then the next piece carries on from there and slows to its own facing by
	-- 1.1 s (37.4), so its dance starts on time
	[97208831163609] = { spin = { from = 8.0, to = 10.2, till = 10.9, add = -125, ease = "linear" } },
	[123817870898356] = { spin = { from = 0, to = 1.1, fromPrev = true, dir = -1, ease = "out" } },
	-- 키키-Pop Off last piece (D-973, user: "pop off 마지막 부분 확인 후 수정"): the
	-- capture spins one and a half turns in 0.8 s (up to 40° a frame) and turns
	-- half back: one even turn over 1.7 s (2:18.2-2:19.9) to where it ends
	[77209641618863] = { spin = { from = 1.0, to = 2.7, ease = "both" } },
	-- YENA-Catch Catch 9 / 10 (D-974, user: "1:16~1:23 안무 앉아서 팔 움직임 적음": 1:16
	-- 기도하는 자세로 고개 숙이기, 1:18 고개 들기, 1:19 얼굴 양 옆으로 팔 90도로 들고
	-- 고개 까딱, 1:20 손으로 볼 감싸는 제스처 → 고개랑 팔 함께 옆 잠깐 봤다가 돌아오기,
	-- 1:22 팔 그대로 들고 손으로 볼 톡톡, 1:23 사선으로 팔과 고개 올려다봤다가 돌아오기;
	-- practice video P3j4RexyOBI, song = video + 0.74): the arms and head set
	-- to each pose (angles found on the avatar in Play, screen shots), the
	-- kneel left to the capture; piece 9 (from 76.97) runs on into 10's blend
		-- (D-989, user: 1:21 "볼 툭툭 치는 모션을 팔을 빨간선처럼 어깨 말고 팔꿈치만 살짝 폈다가 다시
	-- 굽히는 모션으로"): each tap opens the elbows 17° (the forearms out along the cheeks)
	-- and folds them back, the wrists and the upper body still (steady) so only the elbows move
	[130984178299080] = { steady = { { from = 3.6, to = 6.2, parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }, passes = 8 },
		{ from = 5.4, to = 6.6, parts = { "UpperTorso", "Head" }, passes = 8 } }, pose = { { from = 0, to = 6.5, ease = 0.3, keys = {
		{ t = 0.15, set = { LeftUpperArm = { 10, -43, -8 }, LeftLowerArm = { 103, -7, 21 }, LeftHand = { 13, -14, -23 },
			RightUpperArm = { 5, 38, 3 }, RightLowerArm = { 104, 16, -20 }, RightHand = { 16, 12, 29 }, Head = { -35, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 1.45, set = { LeftUpperArm = { 10, -43, -8 }, LeftLowerArm = { 103, -7, 21 }, LeftHand = { 13, -14, -23 },
			RightUpperArm = { 5, 38, 3 }, RightLowerArm = { 104, 16, -20 }, RightHand = { 16, 12, 29 }, Head = { -35, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 1.85, set = { LeftUpperArm = { 60, -15, -30 }, LeftLowerArm = { 125, 0, 25 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 60, 15, 30 }, RightLowerArm = { 125, 0, -25 }, RightHand = { 0, 0, 0 }, Head = { 5, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 2.45, set = { LeftUpperArm = { 60, -15, -30 }, LeftLowerArm = { 125, 0, 25 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 60, 15, 30 }, RightLowerArm = { 125, 0, -25 }, RightHand = { 0, 0, 0 }, Head = { 5, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 2.8, set = { LeftUpperArm = { 0, 0, -85 }, LeftLowerArm = { 0, 0, -105 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 0, 0, 85 }, RightLowerArm = { 0, 0, 105 }, RightHand = { 0, 0, 0 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 2.97, set = { LeftUpperArm = { 0, 0, -85 }, LeftLowerArm = { 0, 0, -105 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 0, 0, 85 }, RightLowerArm = { 0, 0, 105 }, RightHand = { 0, 0, 0 }, Head = { 0, 0, 16 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 3.17, set = { LeftUpperArm = { 0, 0, -85 }, LeftLowerArm = { 0, 0, -105 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 0, 0, 85 }, RightLowerArm = { 0, 0, 105 }, RightHand = { 0, 0, 0 }, Head = { 0, 0, -6 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 3.35, set = { LeftUpperArm = { 0, 0, -85 }, LeftLowerArm = { 0, 0, -105 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 0, 0, 85 }, RightLowerArm = { 0, 0, 105 }, RightHand = { 0, 0, 0 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 3.8, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 4.25, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 28, 0 } }, add = { UpperTorso = { 0, 18, 0 } } },
		{ t = 4.75, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 5.6, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 5.75, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 118, 0, 0 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 118, 0, 0 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 5.9, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 6.05, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 118, 0, 0 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 118, 0, 0 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } }, add = { UpperTorso = { 0, 0, 0 } } },
	} } } },
	[128412578867487] = { steady = { from = 0, to = 0.6, parts = { "UpperTorso", "Head" }, passes = 8 }, pose = { { from = 0, to = 1.85, ease = 0.2, keys = {
		{ t = 0.0, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 118, 0, 0 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 118, 0, 0 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } } },
		{ t = 0.15, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } } },
		{ t = 0.3, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 118, 0, 0 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 118, 0, 0 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } } },
		{ t = 0.45, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } } },
		{ t = 0.85, set = { LeftUpperArm = { 20, 0, -145 }, LeftLowerArm = { 20, 0, 0 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 22, 0, 12 } } },
		{ t = 1.2, set = { LeftUpperArm = { 20, 0, -145 }, LeftLowerArm = { 20, 0, 0 }, LeftHand = { 0, 0, 0 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 22, 0, 12 } } },
		{ t = 1.6, set = { LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 135, 0, 15 }, LeftHand = { -10, 0, 25 },
			RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 135, 0, -15 }, RightHand = { -10, 0, -25 }, Head = { 0, 0, 0 } } },
	} } } },
	-- YENA-Catch Catch 1 (D-974, user: "처음에 무릎 꿇고 있을 때 떨어"): every joint turned
	-- back 3-5 times in 0.5 s in the kneel and the body crept 0.2 stud
	-- 5 (D-986, user: 0:35 "다리는 수직 유지하고 상체만 숙이기"): the capture leans the hips up to
	-- 80° at song 35.0-36.4 and the legs lean with them: hips level, the lean at the waist
	[112551530516434] = { upright = { from = 6.2, to = 7.8, ease = 0.3 } },
	[75443608985712] = { still = { { from = 0, to = 4.85 } }, steady = { from = 0, to = 4.85, passes = 8 } },
	-- 3 / 8 (D-974, user: "0:13 팔 교차", "1:09 팔 교차 너무 교차되는데", "1:15 팔 교차"; "팔 교차과
	-- 몸통 통과는 신체에 따라 다른 듯"): the members hold the fists up in front of the
	-- shoulders; the capture's forearm crossed over to the other side (through
	-- a broad body): the upper arms twisted 25° and swung 8° outward there
	[98063579481098] = { pose = { { from = 6.1, to = 7.4, ease = 0.25, add = { LeftUpperArm = { 0, 25, -8 }, RightUpperArm = { 0, -25, 8 } }, keys = { { t = 6.1 } } } } },
	[110540650870002] = { pose = {
		{ from = 6.4, to = 7.5, ease = 0.25, add = { LeftUpperArm = { 0, 25, -8 }, RightUpperArm = { 0, -25, 8 } }, keys = { { t = 6.4 } } },
		{ from = 12.4, to = 13.5, ease = 0.25, add = { LeftUpperArm = { 0, 25, -8 }, RightUpperArm = { 0, -25, 8 } }, keys = { { t = 12.4 } } } } },
	-- 6 (D-974, user: "0:38 안무 약한 게 맞는지"): the members stand wide with the arms
	-- out to the sides; the capture kept them by the body: 25° further out
	[98514844125325] = { pose = { { from = 1.5, to = 3.1, ease = 0.35, add = { LeftUpperArm = { 0, 0, -25 }, RightUpperArm = { 0, 0, 25 } }, keys = { { t = 1.5 } } } } },
	-- aespa-Lemonade (D-976, user list; practice video NJx2IGeS8CQ, song = video - 1.08)
	-- 3 (from 15.92): "0:19 버벅거림" the piece starts with a wobble (38 → 25 → 45 → 20°)
	-- then turns 280° in 1 s: one even turn from 0.45 s; "0:22 팔 섞는 모션 섬세하게.
	-- 왼쪽 팔 돌리는 거 더 크게 돌리기" the left arm's rolls 1.35x as far (song 19.5-22.5)
	[74096523961866] = { spin = { from = 0.45, to = 2.0, ease = "both" },
		-- (D-1000, user: "0:22 안무에 팔 떨림 잡은 거 복구 (1:00 안무랑 비교해 봐 같은 안무지. 1:00처럼"):
		-- the D-976 left-arm amp (1.35x) taken out, so 0:22 dances as 1:00 does
		-- (D-988, user: "0:19 팔 내리는 안무 중간에 멈췄다가 두 번 내리는 것처럼 보이는데
		-- 스무스하게 한 번 내리는 걸로"): the arms came down from song 18.5, stopped at
		-- the chest 18.85-19.3, came down again and bounced (19.6-20.3): the arms go
		-- straight from the pose at 18.5 to the one at 19.62 (angles read in Play)
		-- (the capture flicked them up to the chest and down again at 20.55-20.8,
		-- which read as a second lowering)
		-- (D-992, user: "0:19~0:20 그냥 멈춰있음. 앞에 안무를 슬로우 걸어서 다음 안무까지 이어지게"):
		-- no hold; the arms come down slowly all the way from 18.5 to 20.85
		pose = { from = 2.4, to = 5.1, ease = 0.15, keys = {
			{ t = 2.58, set = { LeftUpperArm = { 60, -58, -61 }, LeftLowerArm = { 34, 2, 0 }, LeftHand = { 12, 29, -33 },
				RightUpperArm = { -34, 29, 26 }, RightLowerArm = { 76, 11, -15 }, RightHand = { 27, -2, 16 } } },
			{ t = 4.93, set = { LeftUpperArm = { -32, -24, -37 }, LeftLowerArm = { 31, -15, 9 }, LeftHand = { -3, -3, -25 },
				RightUpperArm = { -29, 9, 33 }, RightLowerArm = { 41, 12, -14 }, RightHand = { 1, 8, 13 } } },
		} } },
	-- 13 (from 100.92): "1:42~1:43 … 오른쪽은 머리 뒤로 들고 있고 왼쪽팔 앞으로 쭉 뻗은
	-- 상태로 앞으로 자연스럽게 걸어 나가기", "1:43~1:44 … 잠깐 그냥 서 있는데 이어지는
	-- 동작으로", "1:45 … 회전 짧게 두 번 돌면서 버벅거리는데 한 번으로": the arms held
	-- so (angles checked on the avatar) through the walk and the turn; the capture
	-- only twisted ±50° twice: one even turn the same way from 1.2 to 4.3 s
	-- (song 102.1-105.2), filling the stand-still
	-- (D-988, user: "1:41~ 팔 뻗고 한바퀴 돌 때 다리 움직이는 거 고정. 캐릭터도 발 위치
	-- 고정하고 제자리에서 회전하는 걸로"): during the turn (song 102.1-105.2) the legs
	-- stand straight and the body stays on its spot
	-- (D-992, user: "1:41 한바퀴 돌 때 몸 전체가 흔들리는 거 수정"): the upper body leaned 2-10° and
	-- the head circled 0.4-0.9 stud round the axis: torso straight up, head straight
	[107439323698577] = { spin = { from = 1.2, to = 4.3, turns = 1, ease = "both" }, still = { from = 1.0, to = 4.5 }, upright = { from = 1.0, to = 4.5, ease = 0.3 },
		torsoUp = { from = 1.0, to = 4.5, ease = 0.3 },
		pose = { { from = 0, to = 4.6, ease = 0.35, keys = {
			{ t = 0.3, set = { LeftUpperArm = { 90, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, LeftHand = { 0, 0, 0 },
				RightUpperArm = { 0, 0, 160 }, RightLowerArm = { 0, 0, 110 }, RightHand = { 0, 0, 0 } } },
			{ t = 0.9, set = { LeftUpperArm = { 90, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, LeftHand = { 0, 0, 0 },
				RightUpperArm = { 0, 0, 160 }, RightLowerArm = { 0, 0, 110 }, RightHand = { 0, 0, 0 } } },
			{ t = 1.2, set = { LeftUpperArm = { 90, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, LeftHand = { 0, 0, 0 },
				RightUpperArm = { 0, 0, 160 }, RightLowerArm = { 0, 0, 110 }, RightHand = { 0, 0, 0 },
				LeftUpperLeg = { 0, 0, 0 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { 0, 0, 0 },
				RightUpperLeg = { 0, 0, 0 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 }, Head = { 0, 0, 0 } } },
			{ t = 4.3, set = { LeftUpperArm = { 90, 0, 0 }, LeftLowerArm = { 0, 0, 0 }, LeftHand = { 0, 0, 0 },
				RightUpperArm = { 0, 0, 160 }, RightLowerArm = { 0, 0, 110 }, RightHand = { 0, 0, 0 },
				LeftUpperLeg = { 0, 0, 0 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { 0, 0, 0 },
				RightUpperLeg = { 0, 0, 0 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 }, Head = { 0, 0, 0 } } },
		} } } },
	-- (D-988, user: "1:23~24 가만히 서 있는 장면 떨림 수정. 천천히 고개만 까딱이는 걸로"):
	-- 9 (from 76.35) stands still at song 82.8-84.1: held calm, the head nodding
	-- slowly on the beats (0.67 s)
	[135759185323713] = { still = { from = 6.3, to = 7.85 }, steady = { from = 6.3, to = 7.85, passes = 8 },
		pose = { from = 6.3, to = 7.85, ease = 0.3, keys = {
			{ t = 6.4, add = { Head = { 0, 0, 0 } } }, { t = 6.6, add = { Head = { -9, 0, 0 } } }, { t = 6.93, add = { Head = { 2, 0, 0 } } },
			{ t = 7.27, add = { Head = { -9, 0, 0 } } }, { t = 7.6, add = { Head = { 2, 0, 0 } } },
		} } },
	-- 16 / 17 / 18 (from 127.65): "2:10~ 버벅거리고 떰. 프레임 튀듯이", "~2:26까지 계속
	-- 떨어": 10-27 joint turn-backs in 0.5 s all through; smoothed (the moves kept)
	[82680550952125] = { steady = { from = 0, to = 10.3, passes = 8 } },
	-- 17b red-box floor member (from 136.22) (D-991, user's screen recording of the
	-- KBS stage, "2:20 전후로 누워서 하는 안무 이 영상이 더 잘 보인다. 참고해서 수정"):
	-- on the stage she lies propped on her right forearm, the upper body raised and
	-- the head up; the capture lay nearly flat (chest 1.5 studs up, the forearm
	-- off the floor): the waist lifted 25°, the right upper arm down onto the
	-- forearm (on the floor in Play), the head up (song 136.8-140.8)
	-- (D-992, user: "2:17 초에 있는 자세를 기본으로 누운 다음, 다른 곳 움직이지 말고 왼쪽 다리만
	-- 쭉 뻗는 걸로 수정. 다음은 다리 천천히 내리면서 무릎 꿇는 자세로 연결"): the 2:17 pose
	-- (song 137.0) is kept (`freeze`) to 140.9 but the left leg, which goes from the
	-- capture's lying leg straight out to the capture's highest raise (knee
	-- straightened) by 138.1, stays up to 139.3 and comes down slowly to the
	-- capture's leg at 140.9 (angles read in Play), where the dance goes on into
	-- the kneel; "2:23 앉아 있는 자세에서 상체 수직으로" torsoUp at song 142.5-144.0;
	-- "2:24 다리 뻗고 움직일 때 캐릭터 몸 전체가 움직임 고정 … 스무스하게 일어서는 동작으로"
	-- the body kept on its spot and smoothed at 143.8-145.9 (it travelled 3.3 studs
	-- and bobbed 3 studs up and down)
	[113734305009959] = { freeze = { { from = 0.78, to = 4.68, ease = 0.3, except = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } },
		-- (the sitting pose kept from song 143.9 until 18 stands up and turns: it bobbed up 2.7 studs and back)
		{ from = 7.7, to = 9.75, ease = 0.4 } },
		still = { { from = 0.6, to = 4.8 }, { from = 7.5, to = 9.7 } },
		torsoUp = { from = 6.2, to = 7.9, ease = 0.4 },
		pose = { from = 0.3, to = 4.6, ease = 0.4, keys = {
			{ t = 0.3, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } } },
			{ t = 0.85, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } },
				set = { LeftUpperLeg = { 101, 11, -37 }, LeftLowerLeg = { -127, -3, 11 }, LeftFoot = { -10, -22, 4 } } },
			{ t = 1.9, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } },
				set = { LeftUpperLeg = { 50, -29, -54 }, LeftLowerLeg = { -8, 0, 0 }, LeftFoot = { -16, 16, 13 } } },
			{ t = 3.1, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } },
				set = { LeftUpperLeg = { 50, -29, -54 }, LeftLowerLeg = { -8, 0, 0 }, LeftFoot = { -16, 16, 13 } } },
			{ t = 4.55, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } },
				set = { LeftUpperLeg = { 39, -22, -12 }, LeftLowerLeg = { -142, -8, -3 }, LeftFoot = { 8, -28, 7 } } },
		} } },
	-- 12 (from 94.39) (D-992, user: "1:38~1:40 앞으로 걸어가는 안무할 때 상체가 너무 뒤로 기울어져
	-- 있음. 상체 일자로 세워. 수직으로"): the upper body straight up through the walk
	[138502286160157] = { torsoUp = { from = 3.4, to = 6.6, ease = 0.4 } },
	[132337331292488] = { steady = { from = 0, to = 8.0, passes = 8 } },
	-- (2:26 "일어나면서 몸 돌리는데 두 번 돌림. 한 번으로 깔끔하게": the capture turns 55°
	-- one way, then 141° back in 0.16 s, inside its 1 s blend: one even turn
	-- the short way round from where 17 ended, 0-1.3 s, during the blend too)
	[76195346888656] = { steady = { from = 0, to = 5.0, passes = 8 }, spin = { from = 0, to = 1.3, fromPrev = true, dir = 1, ease = "both" } },
	-- Catch Catch v2 centre pieces (D-981, the user's list of 2026-11-08 on the pieces
	-- choreo-add cut again, D-980). v2 12 (song 107.77): 1:50 "팔 드는 거 조금 더 올리게 해 줘
	-- 부드럽게 웨이브하듯이": she opens both arms out and up at song 111.6-112.3, the capture
	-- only to the waist; the upper arms turn 1.5x as far there
	[88923183102495] = { amp = { from = 3.7, to = 5.2, ease = 0.4, parts = { LeftUpperArm = 1.5, RightUpperArm = 1.5 } } },
	-- v2 17 (song 143.2): 2:26 the walk into the circle turned 31° back, flicked
	-- round at 720°/s, stopped, then turned on: one even turn (piece 2.45-3.6 s);
	-- the pops stand still and calm (still + steady) so they show
	-- 2:28 "팔 들다가 맘. 팔 들지 말고 배드에 가슴 튕기는 안무 참고해서 상체 튕기는 안무로 …
	-- 이후에 한박자 쉬고 두 번 더 튕김": the arms stay down (the capture raised the
	-- right arm at song 148.0 and the left at 149.1) and the chest pops on the
	-- music's hits: song 148.13, (148.56 rest), 149.0, 149.44 (beats 0.434 s)
	[115248452065042] = { spin = { from = 2.45, to = 3.6, ease = "both" }, still = { from = 4.9, to = 7.1 }, steady = { from = 4.9, to = 7.1, passes = 8 },
		-- (D-987, user: "2:25~ 에 가슴 튕기는 거 원본 영상 보고 박자 잘 맞출 것. 팔 안무 추가할 것",
		-- "2:28 안무 영상 보고 구현 수정"): in the video she arches with her head back at
		-- video 147.6-147.8 = song 148.4, on the music's hit 148.56 (D-981 had the pops
		-- one beat early): pops on the hits 148.56, (149.0 rest), 149.44, 149.87, the
		-- arms swinging out a little with each pop; then at 2:28 (song 150.1-151.3) she
		-- stands with the chest out and the chin up
		pops = { at = { 5.36, 6.24, 6.67 }, sizes = { 1.8, 1, 1.2 }, push = 0.5, lift = 0.2, arch = 8, out = 0.05, back = 0.35 },
		pose = { { from = 4.5, to = 7.0, ease = 0.3, keys = (function()
			local down = { LeftUpperArm = { 0, 0, -6 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 0, 0, 6 }, RightLowerArm = { 10, 0, 0 } }
			local out = { LeftUpperArm = { -12, 0, -22 }, LeftLowerArm = { 28, 0, 0 }, RightUpperArm = { -12, 0, 22 }, RightLowerArm = { 28, 0, 0 } }
			local keys = { { t = 4.5, set = down } }
			for _, at in ipairs({ 5.36, 6.24, 6.67 }) do
				table.insert(keys, { t = at - 0.06, set = down })
				table.insert(keys, { t = at + 0.02, set = out })
				table.insert(keys, { t = at + 0.3, set = down })
			end
			return keys
		end)() },
		{ from = 7.0, to = 8.2, ease = 0.3, keys = { { t = 7.0, add = { Head = { 10, 0, 0 }, UpperTorso = { 6, 0, 0 }, LeftUpperArm = { -8, 0, -4 }, RightUpperArm = { -8, 0, 4 } } } } },
		-- (D-983) play bar 2:20 the left hand still across the body from v2 16: arm out of the body
		{ from = -1, to = 0.7, ease = 0.3, keys = { { t = 0, add = { LeftUpperArm = { 10, 25, -8 } } } } } } },-- RIIZE-Love 119 1 (D-962, user: "시작 부분에 처음 포즈로 가만히 서 있고 … 그
	-- 자세에서 다음 걷는 안무로 자연스럽게 이어지도록") the first pose is held still
	-- (the capture sways 20° and shifts) until the walk (2) blends in over 0.9 s
	[116659270658163] = { hold = { from = 0, to = 3.6 } },
	-- IOI-갑자기 (D-996, the user's list of 2026-11-08, play-bar times = song seconds, rate 1.001)
	-- 3 (from 8.5) "0:10 떨어": the legs smoothed through 9.0-12.5
	[140529283375287] = { steady = { from = 0.5, to = 4.0, parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }, passes = 8 } },
	-- 10 (from 74.7) "1:20 부터 걷는 모션 상체가 뒤로 기울어서 이상함. 기본 걷는 모션으로": the
	-- upper body leaned back up to 42° at 75.9-78.9 and through the walk to 81.1: straight up
	[104001486192661] = { torsoUp = { from = 0.9, to = 6.6, ease = 0.4 } },
	-- 11 (from 83.07) "1:26 떨어": the left foot and the body shook at 85.9
	[71879139866517] = { steady = { { from = 2.3, to = 3.8, parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }, passes = 8 }, { from = 2.6, to = 3.3, passes = 8 } } },
	-- 18 / 19 (from 140.7 / 143.7) "2:21 다리 떨어", "2:23 회전 두 번으로 끊기면서 도는 것처럼 보임
	-- 한 번 도는 동작으로": 18 twisted 105° one way and back (141.0-142.8) and 19 flicked
	-- round 190° with a wobble in its blend: 18 keeps its facing (legs smoothed), 19
	-- turns once, the way the capture went, from where 18 ended
	[118835663786601] = { spin = { from = 0.3, to = 2.95, ease = "both" }, steady = { from = 0.3, to = 3.0, parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }, passes = 8 } },
	[136490889932903] = { spin = { from = 0, to = 0.6, fromPrev = true, dir = -1, ease = "both" } },
	-- 21 (from 149.7) "2:42 팔 들면서 바들바들 떨어": the arms smoothed 159-163.6
	[123714434236489] = { steady = { from = 9.3, to = 13.9, parts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }, passes = 8 } },
	-- 25 (from 180.7) "3:02 걸어갈 때 상체 뒤로 눕는 거 수정": straight up through the walk
	[129257680770934] = { torsoUp = { from = 0.3, to = 6.0, ease = 0.4 } },
	-- 6 (D-962, user: 0:32 "회전 한 바퀴 자연스럽게"): 5 ends turning (-92° → -176°
	-- in its last 0.9 s) and 6 starts at +15°, blending over 1 s (the blend
	-- turned the short way back, 178° in a frame): one even turn on the same
	-- way round, from where 5 ended to 6's facing at 1.2 s
	[75370013537988] = { spin = { from = 0, to = 1.2, fromPrev = true, dir = -1, ease = "both" } },
	-- 11, 12 (D-962, user: "1:00-1:01 캐릭터 갑자기 앞으로 이동"): the feet slide
	-- 0.6-2 studs at 4.6-5.9 and in 12 (1.2 s): in place
	[79064359810628] = { still = { { from = 4.6, to = 5.9 } } },
	-- 8 (D-965, found by tools/choreo/play_record.lua): the capture's hips dash
	-- 2 studs off in its last 0.3 s (0:46.1-46.35): in place
	[140553219106220] = { still = { { from = 2.9, to = 3.4 } } },
	[103495705227564] = { still = { { from = 0, to = 1.2 } } },
	-- 18 (D-962, user: "1:27 회전"): 17 ends facing -89°, 18 starts at +64° and
	-- spins once with a lurch (+50° a keyframe at 0.9-1.1 s): one even turn
	-- from where 17 ended, over the seam, to 18's facing at 2.1 s
	[107611961518863] = { spin = { from = 0, to = 2.1, fromPrev = true, dir = 1, turns = 1, ease = "both" } },
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
	-- YENA-Catch Catch (D-968): Play scan SPIN 626-666°/s = fast real turns (one way, 155-210°), spread evenly
	[98686361929027] = { spin = { from = 8.6, to = 9.5, ease = "both" } }, -- 4 (0:27)
	[122624428391289] = { spin = { from = 0.5, to = 1.15, ease = "both" } }, -- 11 (1:34)
	[126013496400815] = { spin = { from = 0.6, to = 1.27, ease = "both" } }, -- 12 (1:38, to the piece end)
	[107833429874111] = { spin = { from = 5.75, to = 6.17, ease = "both" } }, -- 13 (1:44, to the piece end)
} :: {[number]: { steady: { from: number, to: number, parts: {string}?, passes: number? }?, turn: number?,
	pops: { at: {number}, sizes: {number}?, push: number, lift: number?, arch: number, out: number?, back: number?, sink: boolean? }?, calm: boolean?,
	hold: { from: number, to: number }?, still: any?, turnEase: string?,
	spin: { from: number, to: number }?,
	pose: any? }}

-- (D-851) the slower wobble clean-up for pieces with `calm` in ChoreoFixes:
-- a turn back between two swings of at most maxLen keyframes and maxSwing
-- degrees is eased, passes times, never more than cap degrees off the
-- capture (NEON 1: 118 such swings → 51, about what other pieces have)
-- (D-977, user: ANIMAL "0:00~0:04 까지 한쪽 팔 살짝 굽히고 서 있는 상태에서 고개만
-- 박자 타면서 까딱거리기", the member in the white tee) pieces 1 and 2 stand still,
-- right arm a little bent, and the head nods on every beat (practice video beats at
-- 0.06 + 0.4105 k s, 146 bpm; piece 1 starts at video 0; piece 2 starts at video 1.65, song 1.88,
-- because piece 1's clip is only 1.77 s and the head stopped before 2.03)
do
	local stand = {
		LowerTorso = { 0, 0, 0 }, UpperTorso = { 0, 0, 0 },
		LeftUpperArm = { 0, 0, -4 }, LeftLowerArm = { 8, 0, 0 }, LeftHand = { 0, 0, 0 },
		RightUpperArm = { -15, 0, 14 }, RightLowerArm = { 55, 0, 0 }, RightHand = { 0, 0, 0 },
		LeftUpperLeg = { 0, 0, 0 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { 0, 0, 0 },
		RightUpperLeg = { 0, 0, 0 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 },
	}
	-- `first`: the piece takes over a little after its start (piece 1 holds its
	-- last frame down to song 2.06), so it starts with the head down there and
	-- its first rise is a little quicker
	local function nods(offset: number, length: number, first: number?)
		local keys = {}
		if first then
			local set = table.clone(stand)
			set.Head = { -12, 0, 0 }
			table.insert(keys, { t = first, set = set })
		end
		local beat = 0.06
		while beat - offset < length + 0.5 do
			for _, k in ipairs({ { beat, -12 }, { beat + 0.205, 3 } }) do
				local t = k[1] - offset
				if first and t < first + 0.13 then t = if k[2] > 0 and t > first then first + 0.13 else -1 end
				if t >= 0 and t <= length then
					local set = table.clone(stand)
					set.Head = { k[2], 0, 0 }
					table.insert(keys, { t = t, set = set })
				end
			end
			beat += 0.4105
		end
		return keys
	end
	M.ChoreoFixes[129402890751712] = { still = { from = 0, to = 10 }, pose = { from = -1, to = 10, ease = 0.3, keys = nods(0, 2.6) } }
	M.ChoreoFixes[80772039533772] = { still = { from = 0, to = 10 }, pose = { from = -1, to = 10, ease = 0.3, keys = nods(1.65, 2.5, 0.2) } }
end

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
	-- IOI-갑자기 (D-967)
	[72001429900652] = { { 6.0, 6.7 } }, [140529283375287] = { { 3.9, 4.9 } }, [121160569929367] = { { 10.5, 11.2 } },
	[76645919052139] = { { 2.6, 3.7 }, { 4.1, 4.9 } }, [72886571801726] = { { 3.4, 4.1 } }, [72291044078776] = { { 4.7, 5.4 } },
	[128759413181742] = { { 2.6, 3.3 }, { 7.8, 8.4 } }, [121913954340036] = { { 3.5, 4.1 } }, [84100214173726] = { { 0.6, 1.4 }, { 3.7, 4.4 } },
	[118835663786601] = { { 0.7, 1.4 } }, [136490889932903] = { { 1.9, 2.5 } }, [92331354114542] = { { 1.7, 2.5 } },
	[123714434236489] = { { 0.7, 1.6 }, { 9.1, 9.8 }, { 10.8, 11.5 }, { 13.0, 14.1 } }, [82782712192367] = { { 2.7, 3.8 }, { 4.3, 5.0 } },
	[129257680770934] = { { 5.8, 6.8 }, { 10.2, 10.8 } },
	[81367674902881] = { { 0.4, 1.2 }, { 1.9, 2.5 }, { 2.9, 3.6 } }, [84783409830169] = { { 1.3, 1.9 }, { 3.3, 3.9 } },
	-- YENA-Catch Catch (D-968)
	[112551530516434] = { { 6.5, 7.1 } }, [74567972410299] = { { 10.3, 10.9 } }, [110540650870002] = { { 2.0, 2.6 }, { 3.2, 3.8 } },
	[107833429874111] = { { 3.9, 4.5 }, { 5.0, 5.6 } }, [138852020855643] = { { 0.4, 1.0 } }, [111787124658928] = { { 2.1, 2.8 } },
	[113094829637212] = { { 0.4, 1.0 }, { 2.1, 2.8 }, { 2.9, 3.5 } }, [104636507093618] = { { 1.8, 2.4 } },
	[116715438780373] = { { 0.0, 1.4 }, { 1.6, 2.2 }, { 5.9, 6.9 } },
	[98063579481098] = { { 3.3, 3.9 }, { 8.0, 8.6 } },
	-- aespa-Lemonade (D-970)
	[74096523961866] = { { 3.0, 3.8 }, { 4.7, 5.4 } }, [123559029471758] = { { 5.2, 6.5 } }, [139260290712979] = { { 6.5, 7.2 } },
	[131526768823490] = { { 3.7, 4.4 }, { 6.2, 6.9 } }, [99422937735141] = { { 5.9, 6.8 } }, [100397079318559] = { { 6.3, 7.1 }, { 8.0, 9.3 } },
	[135759185323713] = { { 5.4, 6.0 } }, [138502286160157] = { { 1.6, 2.3 } }, [107439323698577] = { { 1.3, 2.1 }, { 9.0, 9.6 } },
	[138612452549442] = { { 1.6, 2.3 }, { 2.5, 3.0 } }, [118124487485279] = { { 1.4, 2.0 }, { 7.9, 8.9 } },
	[82680550952125] = { { 0.7, 1.4 }, { 2.9, 3.6 }, { 8.2, 9.7 } },
} :: {[number]: {{number}}}
for id, stretches in pairs(M.ChoreoSlideStill) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	local still = if fix.still == nil then {} elseif fix.still.from then { fix.still } else table.clone(fix.still)
	for _, s in ipairs(stretches) do table.insert(still, { from = s[1], to = s[2] }) end
	fix.still = still
end

-- (D-966, user: "캐릭터 위치 갑자기 이동하면 이상해 보임 … 1 스터드도 티 날 것
-- 같아", "바들바들 떠는 부분 … 이거 완전 중요") from tools/choreo/play_record.lua
-- run over whole songs in Play (BAD, Genie, Get A Guitar, Love 119, Catch
-- Catch, NEON, 체포하겠어, LOVE ATTACK, Looks Can Kill): ChoreoGlideStill =
-- the body glides 1-2.4 studs in 0.3 s while the feet step under a third of
-- it (or slides with both feet still) → `still`; ChoreoAutoSteady = a held
-- pose with 10-16 turn-backs in 0.5 s → `steady` (passes 8). Piece seconds.
M.ChoreoGlideStill = {
	[101676644495491] = { { 4.8, 5.4 } }, [104212164342204] = { { 4.4, 5.0 }, { 5.8, 6.4 }, { 11.0, 11.6 } },
	[111932052760637] = { { 5.5, 6.1 } }, [115574620758490] = { { 0.6, 1.2 } }, [119819611123433] = { { 3.9, 4.5 } },
	[128174978668663] = { { 9.1, 9.7 } }, [128412578867487] = { { 5.1, 5.7 }, { 8.9, 9.5 } }, [129447992418977] = { { 9.8, 10.4 } },
	[71570705300325] = { { 4.3, 4.9 } }, [72915658378938] = { { 6.6, 7.2 } }, [73284838254272] = { { 7.3, 7.9 } },
	[73939357849033] = { { 2.4, 3.0 } }, [83427493012714] = { { 8.4, 9.0 } }, [90778610748932] = { { 10.5, 11.1 } },
	[93973196577178] = { { 1.8, 2.4 } }, [97954457634320] = { { 7.7, 8.3 } }, [99868719395147] = { { 0.6, 1.2 } },
	-- (IOI-갑자기, I SPY, REDRED, ANIMAL, CRASH, Pretty Girl, Pop Off: these travel
	-- a lot with steps, so only clear glides, the feet stepping a fifth of it)
	[104678910693394] = { { 4.5, 5.1 } }, [118658921583531] = { { 3.4, 4.0 }, { 11.5, 12.1 } }, [127691136882789] = { { 7.9, 8.5 } },
	[71548910990490] = { { 2.0, 2.6 }, { 6.6, 7.2 } }, [72886571801726] = { { 5.2, 5.8 } }, [74401251779168] = { { 10.4, 11.0 } },
	[80284068432208] = { { 0.7, 1.3 } }, [82506858822635] = { { 4.7, 5.3 } }, [85184392148752] = { { 4.4, 5.0 } },
	[86500685186308] = { { 5.1, 6.3 } }, [89496459962506] = { { 6.0, 6.6 } }, [92331354114542] = { { 5.1, 5.7 } },
	[99354632184083] = { { 0.5, 1.1 } },
	-- YENA-Catch Catch (D-968, Play scan 0:39 SLIDE 1.1 stud)
	[98514844125325] = { { 2.4, 3.1 } },
	-- IOI-갑자기 7 / 8 (D-996, user: "0:56 캐릭터 이동"): the body slid at song 55.7-57.1
	[84783409830169] = { { 9.5, 10.5 } }, [76645919052139] = { { 0, 0.9 } },
	-- aespa-Lemonade 5 / 6 (D-988, user: "0:39에서 캐릭터 이동 보임"): the body slid 1 stud at song
	-- 37.6-38.2 and 40.4-40.6 with the feet still on the body
	[139260290712979] = { { 5.6, 6.4 } }, [131526768823490] = { { 1.1, 1.6 } },
} :: {[number]: {{number}}}
M.ChoreoAutoSteady = {
	[118832898913501] = { { 5.5, 6.4 } }, [122624428391289] = { { 2.3, 3.2 } }, [129415986484255] = { { 6.8, 7.7 } },
	[134748500609652] = { { 3.2, 4.1 } }, [76049029842393] = { { 3.2, 4.1 } }, [88317170211079] = { { 3.1, 4.0 } },
} :: {[number]: {{number}}}
for id, stretches in pairs(M.ChoreoGlideStill) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	local still = if fix.still == nil then {} elseif fix.still.from then { fix.still } else table.clone(fix.still)
	for _, s in ipairs(stretches) do table.insert(still, { from = s[1], to = s[2] }) end
	fix.still = still
end
for id, stretches in pairs(M.ChoreoAutoSteady) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	local steady = if fix.steady == nil then {} elseif fix.steady.from then { fix.steady } else table.clone(fix.steady)
	for _, s in ipairs(stretches) do table.insert(steady, { from = s[1], to = s[2], passes = 8 }) end
	fix.steady = steady
end

return M
