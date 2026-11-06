-- 배드최산안무 (D-961 backup, 2026-11-07, user: "배드 가슴 튕기는 안무 따로 백업해 놔
-- … 그 부분은 지금 만들어 놓은 걸로 쓸 수 있게 / 이름 배드최산안무")
--
-- ATEEZ-BAD piece 21: chest pops in the arm-across pose, then hands on the
-- hips into the wide squat. Animation id 82346668311878, `at = 136.5`
-- (song seconds), `blend = 0.7`, copied from catalog-ui-redesign as of this
-- commit (D-848 .. D-862 work, pops half a beat earlier D-895).
--
-- To bring it back after other edits, put these three pieces back:
--   1. Shared/ClubPlaylist.lua, ATEEZ-BAD choreo list:
--        { id = 82346668311878, at = 136.5, blend = 0.7 }
--   2. Shared/ClubChoreo.lua, M.ChoreoFixes: the [82346668311878] entry below
--   3. Shared/ClubChoreo.lua, M.ChoreoSlideStill (ATEEZ-BAD):
--        [82346668311878] = { { 5.0, 5.6 } },
-- then run tools/choreo/choreo_timing_check.lua and the §9.4-6 motion tests.
-- This file is not loaded by the game.

return {
	name = "배드최산안무",
	song = "ATEEZ-BAD",
	piece = 21,
	id = 82346668311878,
	at = 136.5,
	blend = 0.7,
	slideStill = { { 5.0, 5.6 } },
	fixes = {
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
	},
}
