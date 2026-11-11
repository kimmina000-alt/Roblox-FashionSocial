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
-- (D-1001, user: "아래 사항 모든 안무에 적용. 앞으로 추가하는 안무에도 필수 적용") for every
-- choreography song (a track's own `home` / `frontLock` replaces these, false turns it off):
-- the dance eases back toward where it began (`settle` s) and glides home when it ends
-- (`back` s); facings within `snap`° of the front go to the front, eased up to `keep`°,
-- side / back facings and turns stay as danced
M.ChoreoHome = { settle = 2.5, back = 1.5 } :: any
-- (D-1002, user: "30도로 정의하면 안 됨. 안무 자체가 30도 틀어진 안무면 안무 유지 … 옆을 보고
-- 추는 안무면 옆 모습 … 안무 영상 보면서 일일이 비교해서 적용"): no fixed snap to the front;
-- each piece gets its own facing correction measured against its video (`faceOffset`)
M.ChoreoFrontLock = nil :: any
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
-- (D-1068) Lemonade 2:16 side sit (the user's photo mirrored): set by 16 and held into 17's start
M.LemonadeSideSit = {
	LeftUpperLeg = { 0, -50, -90 }, LeftLowerLeg = { -120, 0, 0 }, LeftFoot = { 20, 0, 0 },
	RightUpperLeg = { 30, -80, -60 }, RightLowerLeg = { -90, 0, 0 }, RightFoot = { 20, 0, 0 },
	UpperTorso = { 5, 0, -20 }, Head = { 0, 0, 12 },
	RightUpperArm = { -20, 0, 20 }, RightLowerArm = { 0, 0, 0 },
	LeftUpperArm = { 30, 0, -10 }, LeftLowerArm = { 30, 0, 0 },
}
-- (D-1168) wrist keys for `bend`: circles (x → z → −x → −z, `period` a circle), twinkle (반짝반짝: the hand
-- turned about its own long axis, +amp / −amp every `half` s), flip (앞으로 반짝반짝: half a turn and back);
-- every list starts and ends at 0
local function wristCircles(t0: number, t1: number, period: number, amp: number)
	local keys, q, i = { { t0, 0, 0, 0 } }, period / 4, 0
	local turn = { { amp, 0, 0 }, { 0, 0, amp }, { -amp, 0, 0 }, { 0, 0, -amp } }
	local t = t0 + q
	while t <= t1 - q * 0.5 do
		local s = turn[i % 4 + 1]
		table.insert(keys, { t, s[1], s[2], s[3] })
		t += q
		i += 1
	end
	table.insert(keys, { t, 0, 0, 0 })
	return keys
end
local function wristTwinkle(t0: number, t1: number, half: number, amp: number, from0: number?)
	local keys, t, sign = { { t0, 0, 0, 0 } }, t0 + half * 0.5, 1
	while t <= t1 - half * 0.5 do
		table.insert(keys, { t, 0, sign * amp + (from0 or 0), 0 })
		t += half
		sign = -sign
	end
	table.insert(keys, { t, 0, 0, 0 })
	return keys
end
local function wristFlip(t0: number, t1: number, half: number, amp: number)
	local keys, t, up = { { t0, 0, 0, 0 } }, t0 + half, true
	while t <= t1 do
		table.insert(keys, { t, 0, if up then amp else 0, 0 })
		t += half
		up = not up
	end
	if keys[#keys][3] ~= 0 then table.insert(keys, { t, 0, 0, 0 }) end
	return keys
end
-- (D-1168) a bent-knee walk on the spot, one step a `step` s, the head bobbing like a duck's and turned
-- to the front (`turn` degrees about the neck, part of it in the chest)
local function duckWalk(t0: number, t1: number, step: number, turn: number)
	local keys, t, left = {}, t0, true
	local function leg(up)
		return if up then { { 70, 0, 0 }, { -100, 0, 0 }, { 30, 0, 0 } } else { { 40, 0, 0 }, { -65, 0, 0 }, { 25, 0, 0 } }
	end
	while t <= t1 + 1e-6 do
		local l, r = leg(left), leg(not left)
		table.insert(keys, { t = t, set = { LeftUpperLeg = l[1], LeftLowerLeg = l[2], LeftFoot = l[3], RightUpperLeg = r[1], RightLowerLeg = r[2], RightFoot = r[3] },
			add = { Head = { if left then -14 else 4, turn * 0.6, 0 }, UpperTorso = { 0, turn * 0.4, 0 } }, move = { LowerTorso = { 0, -0.75, 0 } } })
		t += step / 2
		table.insert(keys, { t = t, set = { LeftUpperLeg = { 45, 0, 0 }, LeftLowerLeg = { -72, 0, 0 }, LeftFoot = { 27, 0, 0 }, RightUpperLeg = { 45, 0, 0 }, RightLowerLeg = { -72, 0, 0 }, RightFoot = { 27, 0, 0 } },
			add = { Head = { 2, turn * 0.6, 0 }, UpperTorso = { 0, turn * 0.4, 0 } }, move = { LowerTorso = { 0, -0.85, 0 } } })
		t += step / 2
		left = not left
	end
	return keys
end
M.ChoreoFixes = {
	-- 백화요란-RESCENE (D-1293, choreo_motion_scan): 6 at 1:35.6 and 13 at 2:27.2 jump 65-89° in one keyframe in a full turn
	-- (LURCH); 18 starts 77° the other way while 17 turns on (+35°/s, SEAM)
	[123368765880247] = { spin = { from = 4.8, to = 6.8, ease = "both" } },
	[131622951291839] = { spin = { from = 6.7, to = 8.7, ease = "both" } },
	[126812347548541] = { spin = { from = 0, to = 0.84, fromPrev = true, dir = 1 } },
	-- Hearts2Hearts-Lemon Tang (D-1040): Play scan SPIN 617-777°/s, each turn made one even turn
	-- (song times; yaw read every 0.08 s in Play). 9 (1:00.7): over its 1 s blend the hips went
	-- 72° one way and 240° back: one turn from where 8 ended. 17 (1:48.9): a full turn with a
	-- stop half way. 21 (2:07.6): 20 turns into it, 323° over the seam; 21 again at 2:20.5
	-- (139.6-140.85). 23 (2:28.1): 400° in 1.5 s with a lurch
	-- (D-1188, user: "1:00~1:01 팔 들면서 한바퀴 도는데 몸 덜썩거림 수정") the hips went 4.26-4.89 up and down through the
	-- turn (song 59.2-62.2): their height follows a slow average there (`level`, 8's end and 9)
	-- (D-1192, user: 레몬탱 "1:01 오른팔 돌면서 회전하는 동작 깔끔하게 정돈. 움찔거림", "1:04에도 프레임 살짝 튀는 듯"): the capture turned on
	-- +271° after the spin and swung 50° back (song 62.6-63.3), the right hand dropped 2 studs in 0.2 s (61.9) and jumped
	-- up again (63.5): one even turn from 5's facing to 3.3 s (63.3, no swing back) and the right arm smoothed hard
	-- (D-1202) Lemon Tang 6 (the 0:27 dance, also played at 1:22-1:27): its first second blended with 13 at 82.0 flicked the right
	-- hand and the left foot (82.6-82.76): smoothed there
	[70997868814427] = { steady = { from = 0.3, to = 1.1, passes = 16 } },
	[115675906513114] = { spin = { from = 0, to = 3.3, fromPrev = true, dir = 1, ease = "both" }, level = { from = -1, to = 2.3, ease = 0.3 },
		steady = { from = 1.6, to = 3.8, passes = 24, parts = { "RightUpperArm", "RightLowerArm", "RightHand" } } }, -- 9
	[72328693870219] = { level = { from = 3.0, to = 4.5, ease = 0.3 } }, -- 8
	-- (D-1188) 7 (song 40.17): "0:44 손목 밖으로 꺾고 반바퀴 반짝반짝": both hands up in front of the face at song
	-- 43.8-45.3: the wrists bend out 40° and turn half way and back (앞으로 반짝반짝), 0.44 s a turn
	[94645609133900] = { bend = { { part = "LeftHand", keys = { { 3.5, 0, 0, 0 }, { 3.8, 0, 0, -40 }, { 4.95, 0, 0, -40 }, { 5.2, 0, 0, 0 } } },
		{ part = "LeftHand", keys = wristFlip(3.8, 4.95, 0.22, 150) },
		{ part = "RightHand", keys = { { 3.5, 0, 0, 0 }, { 3.8, 0, 0, 40 }, { 4.95, 0, 0, 40 }, { 5.2, 0, 0, 0 } } },
		{ part = "RightHand", keys = wristFlip(3.8, 4.95, 0.22, -150) } } },
	-- (D-1188) 17 (song 105): "1:45 팔 움직일 때마다 손목 안쪽으로 꺾기 팔 살짝 뻗을 때는 손목 바깥으로 꺾기": the hands up over
	-- the head; the left arm stretches at song 105.6 / 106.5 / 107.4 (elbow 23-48°) and bends between (95-116°),
	-- the right stays bent but at 105.6: the wrists bend out on each stretch and in on each bend
	[125963510042067] = { bend = {
		{ part = "LeftHand", keys = { { -0.2, 0, 0, 0 }, { 0.0, 0, 0, 35 }, { 0.6, 0, 0, -35 }, { 0.9, 0, 0, 35 }, { 1.5, 0, 0, -35 }, { 2.1, 0, 0, 35 }, { 2.4, 0, 0, -35 }, { 3.0, 0, 0, 35 }, { 3.3, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { -0.2, 0, 0, 0 }, { 0.0, 0, 0, -35 }, { 0.6, 0, 0, 35 }, { 0.9, 0, 0, -35 }, { 3.0, 0, 0, -35 }, { 3.3, 0, 0, 0 } } } } },
	-- (D-1188) 21 (song 115): "1:56 몸 30도 정도 왼쪽으로 돌면서 왼쪽 팔 팔꿈치 접고 호선 그리면서 회전 방향으로 움직이기": the body
	-- turns 30° left over song 115.5-116.1 and holds to 116.9; the left arm, elbow bent 90°, sweeps from out to
	-- the side round to the front, the way the body turns
	[93178194866716] = { bend = { { part = "LowerTorso", keys = { { 0.4, 0, 0, 0 }, { 1.1, 0, 30, 0 }, { 1.9, 0, 30, 0 }, { 2.5, 0, 0, 0 } } } },
		pose = { from = 0.35, to = 2.0, ease = 0.3, keys = {
			{ t = 0.5, set = { LeftUpperArm = { 40, -30, -60 }, LeftLowerArm = { 90, 0, 0 } } },
			{ t = 1.2, set = { LeftUpperArm = { 70, 0, -45 }, LeftLowerArm = { 90, 0, 0 } } },
			{ t = 1.8, set = { LeftUpperArm = { 80, 30, -15 }, LeftLowerArm = { 85, 0, 0 } } } } } },
	[86206068065508] = { spin = { from = 0, to = 1.4, fromPrev = true, dir = 1, turns = 1, ease = "both" } }, -- 17
	-- (D-1058, user: "2:07 회전") 20 was still turning at ~210°/s when 21 took over, and 21's turn
	-- started gently (ease both): it stalled at song 127.0-127.3 and whipped on (169° in 0.5 s).
	-- 20 now plays its last 0.4 s over 0.52 s up to 21 (the 0.1 s hold before 21 started gone) and 21
	-- turns on at one speed, ~220°/s as 20 came in (linear, 0-1.1 s)
	[115787352538480] = { spin = { { from = 0, to = 1.1, fromPrev = true, dir = 1, ease = "linear" }, { from = 12.55, to = 13.8, ease = "both" } } }, -- 21
	-- (D-1188, user: "2:25 손목 인사하는 것처럼 흔들기") the right hand up at the side (song 144.3-145.1): it waves side to side
	[99840608563579] = { spin = { from = 2.7, to = 4.25, ease = "both" }, bend = { { part = "RightHand", keys = { { 0, 0, 0, 0 },
		{ 0.12, 45, 0, 0 }, { 0.28, -45, 0, 0 }, { 0.44, 45, 0, 0 }, { 0.6, -45, 0, 0 }, { 0.76, 0, 0, 0 } } } } }, -- 23
	-- (D-1060) the new uploads 1 and 15: Play scan SPIN at 7.85 (1: the centre cut switches to
	-- another member at 7.6-8.0 s and the capture spun 330° the wrong way; she turns 30°: one even
	-- turn the short way, `turns = 1` undoing the wrong-way lap) and 92.48 (15: a 140° turn in
	-- 0.3 s at the start, inside its blend: one even turn from where 13 left the hips; then 95.54, the
	-- member hidden by a passer-by at 3.5 s: the turn there and back each made even)
	[122848199967536] = { spin = { from = 7.5, to = 8.2, turns = 1, ease = "both" } }, -- 1
	[98655639854740] = { spin = { { from = 0, to = 0.9, fromPrev = true, dir = -1, ease = "both" }, { from = 3.2, to = 3.6, ease = "both" }, { from = 3.6, to = 4.2, ease = "both" } } }, -- 15
	-- (D-1064) 19 cut again: side → back → front, one full turn the same way (0.8-1.6 s, the member blurred
	-- at 0.9-1.5 in the clip); the capture turned to her back and whipped back 150° (796°/s at 108.76)
	-- (D-1188, user: "1:48 몸 이동": the body slid 0.9 stud during the lap at song 108.9-109.8: in place)
	-- (D-1192, user: "1:48 부드럽게 회전하게 수정"): "out" started at 390°/s (song 108.2-108.6) and slowed: gently in and out now
	[128761870790634] = { spin = { from = 0, to = 1.9, fromPrev = true, dir = 1, turns = 1, ease = "both" }, still = { from = 0.7, to = 2.3 },
		-- (D-1196, user: "1:49 프레임 튐. 삭제하고 자연스럽게 돌게 더 수정"): the upper body leaned out in the lap and the head swung a
		-- stud in 0.1 s (song 109.1-109.2): straight up through the turn
		upright = { from = 0.2, to = 2.0, ease = 0.3 }, torsoUp = { from = 0.2, to = 2.0, ease = 0.3 } }, -- (from 18's facing: it started 53° off; turns = 1, or fromPrev takes the short way)
	-- (D-1192, user: "1:55 오른쪽 팔 두 번 움직임 수정") 20 (song 112): the capture lifts the right arm at 112.7-113.0 and 113.9; in the
	-- video it stays down until the one lift at 114.8-115.6: held down from 0.3 to 2.2 s (from 0.55 it froze the arm already rising)
	[108870214091189] = { freeze = { from = 0.3, to = 2.2, ease = 0.25, except = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Head", "UpperTorso", "LowerTorso" } } },
	-- (D-1058, user: "1:22 버벅 / 이후로 덜덜 떨림 깔끔하게 큰 모션 위주로 정돈") 13 = clip 14, where the
	-- centre cut lost the member for whole stretches (the picture all blurred at 1.0, 3.5-5.0, 6.0,
	-- 7.5-8.0 s): its capture trembles throughout. Smoothed hard (24 passes, about 0.2 s), the
	-- slower wobble eased too (calm): the big moves stay
	-- (D-1188, user: "1:22 오른쪽 팔로 팔꿈치 접어서 들고 손목 꺾어서 꽃받침 > 왼쪽 똑같이 꽃받침 > 고개 갸웃 > 손목 안쪽으로 살짝
	-- 꺾이면서 팔 부드럽게 바깥으로 호선 그리면서 내림 > 왼쪽 팔꿈치 접힌 상태로 팔 앞으로 … 우아하게 뻗으면서 손목 안쪽으로 꺾임 >
	-- 오른쪽 팔 같은 동작으로 왼쪽보다 위로 > 왼쪽 팔 더 올라가서 뻗음 (팔 뻗을 때마다 손목 안쪽으로 꺾였다가 돌아오는 동작 반복)",
	-- "1:30 손목 밖으로 꺾고 반짝반짝"): the capture has only the right hand at the chin (song 81.6-83.0, its wrist
	-- already bent out 49°) and the left down; in the video (a wide group shot) the members hold the 1:23 hand
	-- shapes. Set in order (piece time = song - 81): 1.0 right 꽃받침 (the capture's own pose), 2.0 the left the
	-- same (the right arm's angles mirrored), 3.0-3.6 the head tilts, 4.2-5.0 both arms arc out and down with the
	-- wrists a little in, 5.0 the left reaches forward (elbow bent), 5.8 the right the same and higher, 6.8 the
	-- left higher, straight; each reach bends the wrist in and back; let go by 8.4 into the capture's hands at the
	-- face (song 89.6), where (8.8-10.0) both wrists bend out and twinkle
	[88699205496882] = { steady = { from = 0, to = 11.2, passes = 24 }, calm = true,
		-- (D-1202, user: "1:22 중간에 혼자 튀는 동작 있음 삭제하고 자연스럽게 연결"): 13 fades out at 82.0 under 6 (the 0:27 dance), and its
		-- own arm keys from 1.7 pulled the arms the other way during the fade (the right hand and left foot flicked at 82.6-82.75):
		-- the window starts at 5.9 now, after 13 comes back at 87.0
		pose = { from = 5.9, to = 8.9, ease = 0.4, keys = (function()
			local rK = { RightUpperArm = { 13, 14, -1 }, RightLowerArm = { 116, 26, -18 }, RightHand = { -8, -10, 49 } }
			local lK = { LeftUpperArm = { 13, -14, 1 }, LeftLowerArm = { 116, -26, 18 }, LeftHand = { -8, 10, -49 } }
			local function both(a, b) local s = {} for k, v in pairs(a) do s[k] = v end for k, v in pairs(b) do s[k] = v end return s end
			local lDown = { LeftUpperArm = { 10, 0, -60 }, LeftLowerArm = { 20, 0, 0 }, LeftHand = { 0, 0, 20 } }
			local rDown = { RightUpperArm = { 10, 0, 60 }, RightLowerArm = { 20, 0, 0 }, RightHand = { 0, 0, -20 } }
			-- (D-1196, user + drawing: "냥냥펀치 레몬탱이야", "1:22 왼팔 오른팔 고양이 냥냥펀치 모양으로 계단 오르는 것처럼 번갈아가면서 더 위로
			-- 올라가기"): the reaches are paws (elbow bent, the forearm up in front = 150° - the upper arm, the wrist curled in) a step
			-- higher each time, left / right / left; then from the front both arms up bent, fists by the head (8.2-8.5)
			local lFwd = { LeftUpperArm = { 70, 0, -15 }, LeftLowerArm = { 80, 0, 0 }, LeftHand = { 0, 0, 0 } }
			local rFwd = { RightUpperArm = { 100, 0, 15 }, RightLowerArm = { 50, 0, 0 }, RightHand = { 0, 0, 0 } }
			local lHigh = { LeftUpperArm = { 130, 0, -15 }, LeftLowerArm = { 25, 0, 0 }, LeftHand = { 0, 0, 0 } }
			local flexB = { LeftUpperArm = { 0, 0, -95 }, LeftLowerArm = { 0, 0, -90 }, LeftHand = { 0, 0, 0 }, RightUpperArm = { 0, 0, 95 }, RightLowerArm = { 0, 0, 90 }, RightHand = { 0, 0, 0 } }
			-- (D-1192, the user's photos: both arms up over the head, the wrists a little in, before the arcs down; video 84.8-85.8)
			local upB = { LeftUpperArm = { 165, 0, -15 }, LeftLowerArm = { 20, 0, 0 }, RightUpperArm = { 165, 0, 15 }, RightLowerArm = { 20, 0, 0 } }
			local lRest = { LeftUpperArm = { 5, 0, -8 }, LeftLowerArm = { 15, 0, 0 }, LeftHand = { 0, 0, 0 } }
			local rRest = { RightUpperArm = { 5, 0, 8 }, RightLowerArm = { 15, 0, 0 }, RightHand = { 0, 0, 0 } }
			local spread = { LeftUpperArm = { 0, 0, -90 }, LeftLowerArm = { 0, 0, 0 }, LeftHand = { 0, 0, 0 }, RightUpperArm = { 0, 0, 90 }, RightLowerArm = { 0, 0, 0 }, RightHand = { 0, 0, 0 } }
			local function wrist(t, side, deg) return { LeftHand = { 0, 0, if side == "L" then deg else 0 }, RightHand = { 0, 0, if side == "R" then -deg else 0 } } end
			return {
				-- (D-1198, user: "1:22~1:27 왼팔 얼굴까지 들기 > 오른팔 얼굴까지 들기 > 왼팔 얼굴까지 들기 > 양팔 양쪽으로 펼치기 > 팔 아래로
				-- 내리기"): one hand at a time up to the face (the other down), then both out to the sides, then down
				{ t = 2.0, set = both(lK, rRest) }, { t = 3.0, set = both(rK, lRest) }, { t = 4.0, set = both(lK, rRest) },
				{ t = 4.8, set = spread }, { t = 5.6, set = both(lDown, rDown) },
				{ t = 6.2, set = both(lFwd, rDown) },
				{ t = 7.0, set = both(lFwd, rFwd) },
				{ t = 7.8, set = both(lHigh, rFwd) },
				{ t = 8.25, set = flexB }, { t = 8.5, set = flexB },
			}
		end)() },
		-- (D-1198: the head tilt and the raise's wrists are out with the new 1:22-1:27 order)
		bend = {
			-- each reach: the wrist in and back (left at 6.6 / 7.6, right at 7.2)
			{ part = "LeftHand", keys = { { 6.2, 0, 0, 0 }, { 6.6, 0, 0, 40 }, { 6.95, 0, 0, 0 }, { 7.3, 0, 0, 0 }, { 7.6, 0, 0, 40 }, { 7.95, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 6.9, 0, 0, 0 }, { 7.2, 0, 0, -40 }, { 7.55, 0, 0, 0 } } },
			-- 1:30 both hands at the face (D-1192, user: "1:30 반짝반짝 말고 손 밖으로 살짝 꺾고 좌우로 움직이기"): bent out a little, waving
			{ part = "LeftHand", keys = { { 8.6, 0, 0, 0 }, { 8.85, 0, 0, -25 }, { 9.95, 0, 0, -25 }, { 10.2, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 8.6, 0, 0, 0 }, { 8.85, 0, 0, 25 }, { 9.95, 0, 0, 25 }, { 10.2, 0, 0, 0 } } },
			{ part = "LeftHand", keys = { { 8.85, 0, 0, 0 }, { 9.05, 30, 0, 0 }, { 9.3, -30, 0, 0 }, { 9.55, 30, 0, 0 }, { 9.8, -30, 0, 0 }, { 9.95, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 8.85, 0, 0, 0 }, { 9.05, 30, 0, 0 }, { 9.3, -30, 0, 0 }, { 9.55, 30, 0, 0 }, { 9.8, -30, 0, 0 }, { 9.95, 0, 0, 0 } } } } }, -- 13 (1:21-1:32)
	-- (D-1058, user: "2:41 무릎 꿇으면서 손목 앞으로 꺽고 고개 옆으로 갸웃") 25 (from 159.1): kneeling, both
	-- hands at the cheeks; in the video (clip 27) from 1.6 s the wrists bend forward and the head tilts
	-- to her right, held to the end of the song (161.87) (x -35 = the fingers forward, checked in Play)
	[98315614070332] = { bend = {
		{ part = "Head", keys = { { 1.45, 0, 0, 0 }, { 1.85, 0, 0, -18 }, { 2.77, 0, 0, -18 } } },
		-- (D-1188, user: "마지막 포즈에 손목 밖으로 꺽어서 꽃받침") the hands at the chin bend out (palms up, fingers out)
		{ part = "LeftHand", keys = { { 1.45, 0, 0, 0 }, { 1.85, 0, 0, -60 }, { 30, 0, 0, -60 } } },
		{ part = "RightHand", keys = { { 1.45, 0, 0, 0 }, { 1.85, 0, 0, 60 }, { 30, 0, 0, 60 } } },
	} }, -- 25 (2:40.5-)
	-- ALLDAY PROJECT-CRASH 14 (D-1041, Play scan 1:49.4 SPIN 636°/s): the hips whip 100° back
	-- (song 109.2-109.6) and settle: one even turn
	[109278338620404] = { spin = { from = 5.55, to = 6.0, ease = "both" } },
	-- ATEEZ-BAD 2 (D-994): Play scan SPIN 642°/s at 1:43, a 270° turn (song 102.8-103.9) spread evenly
	[114907255207310] = { spin = { from = 8.15, to = 9.25, ease = "both" } }, -- 14
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
		-- (D-1194, user: NEON "0:10 왼쪽 다리 들면서 회전할 때 회전 더 매끄럽게 다리 더 높게"): the turn started on a 15° swing back
		-- (song 10.1-10.3) and overshot 18° after: one even lap over 1.6 s (10.0-11.6), the kick higher (thigh up to 128°; 25% more only lifted the foot 2.8 studs)
		still = { { from = 8.6, to = 13.8 } },
		spin = { from = 12.0, to = 13.6, turns = 1, ease = "both" },
		-- (D-1196, user: "0:10 … 마지막에 다리 내리고 자세 바꿀 때 끊김 있음 부드럽게 연결"): the kick, the spin and `still` let go at
		-- 11.4 / 11.6 / 11.8 and the hips dropped 0.9 stud in 0.3 s: smoothed over a second, the hips' height eased
		steady = { from = 13.3, to = 14.4, passes = 24 }, level = { from = 13.35, to = 14.5, ease = 0.3 },
		-- (D-875, user: "1초에 허리 숙이는 거 더 아래로 숙이게") the members fold
		-- right down at video 3.0 s (hair thrown forward); the capture leans
		-- only 24°: up to 40° more at the waist, easing back by 3.85;
		-- (the chest up 15° in the kick: the capture bent over into its squat)
		pose = { { from = 2.75, to = 3.9, ease = 0.05, keys = {
			{ t = 2.8, add = { UpperTorso = { 0, 0, 0 } } }, { t = 2.95, add = { UpperTorso = { -30, 0, 0 } } },
			{ t = 3.05, add = { UpperTorso = { -40, 0, 0 } } }, { t = 3.2, add = { UpperTorso = { -35, 0, 0 } } },
			{ t = 3.5, add = { UpperTorso = { -20, 0, 0 } } }, { t = 3.85, add = { UpperTorso = { 0, 0, 0 } } } } },
		{ from = 12.72, to = 13.42, ease = 0.1, add = { UpperTorso = { 15, 0, 0 } }, keys = {
			{ t = 12.8, set = { LeftUpperLeg = { 50, 0, -10 }, LeftLowerLeg = { -70, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0.06, 0 } } },
			{ t = 12.88, set = { LeftUpperLeg = { 78, 0, -18 }, LeftLowerLeg = { -90, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -8, 0, 0 } }, move = { LowerTorso = { 0, 0.12, 0 } } },
			{ t = 12.92, set = { LeftUpperLeg = { 100, 0, -25 }, LeftLowerLeg = { -95, 0, 0 }, RightUpperLeg = { 4, 0, 0 }, RightLowerLeg = { -6, 0, 0 } }, move = { LowerTorso = { 0, 0.3, 0 } } },
			{ t = 12.96, set = { LeftUpperLeg = { 115, 0, -30 }, LeftLowerLeg = { -60, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.56, 0 } } },
			{ t = 13.0, set = { LeftUpperLeg = { 125, 0, -35 }, LeftLowerLeg = { -20, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.78, 0 } } },
			{ t = 13.04, set = { LeftUpperLeg = { 128, 0, -35 }, LeftLowerLeg = { -10, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.9, 0 } } },
			{ t = 13.08, set = { LeftUpperLeg = { 125, 0, -35 }, LeftLowerLeg = { -12, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -5, 0, 0 } }, move = { LowerTorso = { 0, 0.86, 0 } } },
			{ t = 13.12, set = { LeftUpperLeg = { 112, 0, -28 }, LeftLowerLeg = { -50, 0, 0 }, RightUpperLeg = { 3, 0, 0 }, RightLowerLeg = { -6, 0, 0 } }, move = { LowerTorso = { 0, 0.69, 0 } } },
			{ t = 13.17, set = { LeftUpperLeg = { 95, 0, -20 }, LeftLowerLeg = { -80, 0, 0 }, RightUpperLeg = { 4, 0, 0 }, RightLowerLeg = { -8, 0, 0 } }, move = { LowerTorso = { 0, 0.43, 0 } } },
			{ t = 13.21, set = { LeftUpperLeg = { 56, 0, -10 }, LeftLowerLeg = { -60, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0.19, 0 } } },
			{ t = 13.25, set = { LeftUpperLeg = { 25, 0, -5 }, LeftLowerLeg = { -40, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0.03, 0 } } },
			{ t = 13.33, set = { LeftUpperLeg = { 10, 0, 0 }, LeftLowerLeg = { -15, 0, 0 }, RightUpperLeg = { 5, 0, 0 }, RightLowerLeg = { -10, 0, 0 } }, move = { LowerTorso = { 0, 0, 0 } } },
		} } } },
	[95449015545787] = { calm = true },
	[84806571273074] = { calm = true },
	-- NEON (D-868, user: the stage fancam, "네온 안무 수정"): every piece with more
	-- of the slower wobble than other songs' pieces (over 5.5 short swings a
	-- second; ATEEZ pieces have about 3) gets it eased too
	[128256391320572] = { calm = true }, [100410498984971] = { calm = true }, -- (126736648781925 below)
	[76437753036430] = { calm = true }, [136355327951443] = { calm = true, guardOff = { from = 4.2, to = 5.4, side = "Right" } } --[[ D-1303: NEON 1:56 guard turn-back ]], [117451819045051] = { calm = true },
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
	-- (D-1296, user: NEON "2:30~2:31 팔 버벅거림": the left arm turned back 3 times in 0.3 s at song 151.37-151.68: the arms smoothed hard there)
	[96973609514230] = { calm = true, steady = { { from = 0.4, to = 6.3, passes = 8 },
		{ from = 2.2, to = 3.1, passes = 24, parts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } } },
		-- (the flick out and back was ChoreoBodyGuard: the left hand passes close in front of the chest and the guard pushed the arm out
		-- 0.9 stud and let it back (with the guard off the hand moves evenly): the guard lets the left arm go there)
		guardOff = { from = 2.0, to = 5.0, side = "Left" }, -- (to 2.9 it flicked once more at 151.87: the hand stays low in front)
		still = { from = 0.4, to = 6.4 } },
	-- NEON 22 (D-962, user: 3:31 "뒤로 감. 제자리에", 3:38 "마지막 포즈 달달 떠는
	-- 거") the last piece walks 5 studs back with the feet; in place, and the
	-- end pose smoothed
	-- (D-1296, user: NEON "3:32 왼쪽팔 위로 움찔거림": the left arm turned back 4 times and flicked up 0.6 stud at song 212.3-213.4)
	[114419952125075] = { calm = true, still = { { from = 0.3, to = 9.4 } }, steady = { { from = 5.5, to = 9.4, passes = 8 },
		{ from = 1.9, to = 3.5, passes = 24, parts = { "LeftUpperArm", "LeftLowerArm", "LeftHand" } } },
		-- (the lift and the turn-backs were ChoreoBodyGuard pushing the arm out of the chest and back (none with the guard off))
		guardOff = { from = 1.6, to = 3.8, side = "Left" } },
	-- (D-1296, user: 체포하겠어 "0:36 상체 올라올 때 떨림"): 7 (song 32.95) comes up from the bend at song 37.2-38.3 with the head and
	-- chest shaking (their path 3x the way they went): smoothed hard there
	[75102459386899] = { steady = { from = 4.1, to = 5.5, passes = 24, parts = { "LowerTorso", "UpperTorso", "Head" } } },
	-- (D-1303) the whole-song guard scan (tools/choreo/guard_scan.lua) with the steadier guard left three spots where the guard
	-- still turned the right hand back once (checked at 1x, none with the guard off): I SPY 0:42, CRASH 1:09 (and NEON 1:56 above)
	[98654918637507] = { guardOff = { from = 6.7, to = 7.9, side = "Right" } },
	[119507357461993] = { guardOff = { from = 8.0, to = 9.2, side = "Right" } },
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
		-- (D-1058, user: "0:21 왼쪽 팔 ㄱ 모양으로 굽힌 안무에서 손목 돌리기 추가") the left arm is bent in
		-- an ㄱ (upper arm 70-76° up, elbow 88-90°, read in Play) at song 21.8-22.6: the left hand
		-- circles twice, one circle a beat (127.7 bpm, beats at song 21.80 / 22.27 / 22.74)
		bend = { { part = "LeftHand", keys = { { 5.71, 0, 0, 0 }, { 5.79, 30, 0, 0 }, { 5.91, 0, 0, 30 }, { 6.02, -30, 0, 0 },
			{ 6.14, 0, 0, -30 }, { 6.26, 30, 0, 0 }, { 6.38, 0, 0, 30 }, { 6.49, -30, 0, 0 }, { 6.61, 0, 0, -30 }, { 6.73, 0, 0, 0 } } } },
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
	-- (D-1192, user (listed under 레몬탱, confirmed = Lemonade): "1:42에 너무 번쩍 들어 앞에 안무랑 이어지게 스무스하게 팔 들게 하고
	-- 손목 안으로 꺾기 > 그리고 회전 없음. 회전 대신 앞으로 걸어가는 모션. "<ㅇ>" 이거 팔 더 굽혀 > 1:46 왼쪽 팔 뻗은 거 옆으로
	-- 뻗었는데 앞으로 변경. 각도 변경. 손목 안으로 꺾기 > 1:47에 양쪽 팔 사진 첨부한 화살표쪽으로 90도씩 회전된 위치가 맞는
	-- 위치임. 앞에 안무에서 여기로 연결. 이 상태에서 왼쪽 손목 돌리기"): the arms come up over 1 s (from the dance before)
	-- with the wrists bent in; no turn (D-976's spin and D-988's still are out): she walks forward instead (1.5 studs: with the capture's own steps the body went 5);
	-- <ㅇ> with the elbows bent more; at 1:46 the left arm straight forward, the wrist in; at 1:47 both arms turned 90°
	-- to the front (upper arms forward, forearms up, the photo's arrows), the left wrist circling
	[107439323698577] = { walk = { from = 1.2, to = 4.3, dist = 1.5 }, upright = { from = 1.0, to = 4.5, ease = 0.3 },
		torsoUp = { from = 1.0, to = 4.5, ease = 0.3 },
		bend = { { part = "LeftHand", keys = { { 0.3, 0, 0, 0 }, { 0.9, 0, 0, 40 }, { 2.1, 0, 0, 40 }, { 2.5, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 0.3, 0, 0, 0 }, { 0.9, 0, 0, -40 }, { 2.1, 0, 0, -40 }, { 2.5, 0, 0, 0 } } },
			{ part = "LeftHand", keys = { { 4.0, 0, 0, 0 }, { 4.3, 0, 0, 45 }, { 5.2, 0, 0, 45 }, { 5.45, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 6.4, 0, 0, 0 }, { 6.7, 0, 0, -45 }, { 8.0, 0, 0, -45 }, { 8.3, 0, 0, 0 } } },
			{ part = "LeftHand", keys = wristCircles(7.0, 8.2, 0.47, 35) } },
		pose = { { from = 0, to = 5.5, ease = 1.0, keys = (function()
			local legs = { LeftUpperLeg = { 17, 16, 2 }, LeftLowerLeg = { -36, 7, 6 }, LeftFoot = { 17, 12, -13 },
				RightUpperLeg = { -13, -11, -10 }, RightLowerLeg = { -17, 6, 4 }, RightFoot = { 15, 8, 5 }, Head = { 0, 0, 0 } }
			local up = { LeftUpperArm = { 172, 0, -6 }, LeftLowerArm = { 0, 90, 0 }, LeftHand = { 0, 90, 0 },
				RightUpperArm = { 172, 0, 6 }, RightLowerArm = { 0, 90, 0 }, RightHand = { 0, 90, 0 } }
			-- (a midway key so the arms rise over 1.4 s; <ㅇ>: at -168 / -80 the hands crossed over the head, at -165 / -68 by 0.4, at -160 / -55 they met above it)
			local mid = { LeftUpperArm = { 95, 0, -10 }, LeftLowerArm = { 0, 45, 0 }, RightUpperArm = { 95, 0, 10 }, RightLowerArm = { 0, 45, 0 } }
			local head = { LeftUpperArm = { 0, 0, -165 }, LeftLowerArm = { 0, 0, -62 }, LeftHand = { 0, 0, 0 },
				RightUpperArm = { 0, 0, 165 }, RightLowerArm = { 0, 0, 62 }, RightHand = { 0, 0, 0 } }
			local leftFwd = { LeftUpperArm = { 90, 0, -10 }, LeftLowerArm = { 0, 0, 0 }, LeftHand = { 0, 0, 0 },
				RightUpperArm = { 0, 0, 165 }, RightLowerArm = { 0, 0, 62 }, RightHand = { 0, 0, 0 } }
			local function with(a, b) local s = {} for k, v in pairs(a) do s[k] = v end if b then for k, v in pairs(b) do s[k] = v end end return s end
			return {
				{ t = 0.5, set = mid }, { t = 1.4, set = up }, { t = 2.0, set = up },
				{ t = 2.6, set = head }, { t = 3.5, set = head },
				{ t = 4.0, set = leftFwd }, { t = 5.3, set = leftFwd },
			}
		end)() },
		{ from = 5.9, to = 8.6, ease = 0.6, keys = (function()
			local front = { RightUpperArm = { 90, 0, 20 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { 90, 0, -20 }, LeftLowerArm = { 90, 0, 0 } }
			return { { t = 6.75, set = front }, { t = 8.2, set = front } }
		end)() } } },
	-- (D-988, user: "1:23~24 가만히 서 있는 장면 떨림 수정. 천천히 고개만 까딱이는 걸로"):
	-- 9 (from 76.35) stands still at song 82.8-84.1: held calm, the head nodding
	-- slowly on the beats (0.67 s)
	[135759185323713] = { still = { from = 6.3, to = 7.85 }, steady = { from = 6.3, to = 7.85, passes = 8 },
		pose = { from = 6.3, to = 7.85, ease = 0.3, keys = {
			{ t = 6.4, add = { Head = { 0, 0, 0 } } }, { t = 6.6, add = { Head = { -9, 0, 0 } } }, { t = 6.93, add = { Head = { 2, 0, 0 } } },
			{ t = 7.27, add = { Head = { -9, 0, 0 } } }, { t = 7.6, add = { Head = { 2, 0, 0 } } },
		} },
		-- (D-1190, user: "1:20 손목 안으로 꺾" + photo: the forearms crossed in front of the chest, the wrists bent down)
		-- song 80.6-81.5 both wrists in; "1:25 팔 쭉 뻗은 왼쪽 손목 바깥으로 꺾고 손가락 방향 오른쪽으로 머리통쪽으로 > 팔
		-- 내리면서 손가락 방향 왼쪽 바깥으로 향함. 손목 밖으로 꺾인 상태" + photos: the left arm up at 84.6-85.1, then
		-- coming down to 86.1: the wrist bent out all along, the fingers turned toward the head, then out to the left
		bend = { { part = "LeftHand", keys = { { 4.2, 0, 0, 0 }, { 4.45, 0, 0, 45 }, { 5.0, 0, 0, 45 }, { 5.2, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 4.2, 0, 0, 0 }, { 4.45, 0, 0, -45 }, { 5.0, 0, 0, -45 }, { 5.2, 0, 0, 0 } } },
			{ part = "LeftHand", keys = { { 8.1, 0, 0, 0 }, { 8.35, 0, 45, -55 }, { 8.8, 0, 45, -55 }, { 9.3, 0, -45, -55 }, { 9.75, 0, -45, -55 }, { 10.0, 0, 0, 0 } } } } },
	-- 16 / 17 / 18 (from 127.65): "2:10~ 버벅거리고 떠. 프레임 튀듯이", "~2:26까지 계속
	-- 떨어": 10-27 joint turn-backs in 0.5 s all through; smoothed (the moves kept)
	-- (D-1062, user: "2:14~2:16 서 있다가 무릎 굽히고 앉는 자세로 수정" + a photo of a deep squat: knees
	-- forward, heels down, the hips back and low, the upper body leaning forward, the head forward):
	-- 16 stood from song 134 to 17's drop at 138.3; from 134.0 the knees bend into the squat, full
	-- at 136.0 and held until 17 lies down (17 starts in the same squat). `to` far past the end:
	-- the piece waits on its last frame (10.2 s) until 17 starts (hips 2.35 down: the feet on the floor, checked in Play)
	-- (D-1068, user 2026-11-10: "2:12 회전 멈추기 더 돌아가지 마. 이 상태에서 내려가면서 앉는 자세로 이어지게",
	-- "2:16 … 정면 아니고 측면으로 보여야 함. 앉은 다음 몸 전체가 흔들리는 거 잡아 주기 -> 엉덩이 땅에 붙이고
	-- 첨부한 사진(좌우 반전)처럼 앉아 있는 자세로 연결" + a photo of a side sit): the turn stops where it is
	-- at song 132.0 (4.35 s, side on) and the facing is kept; the knees bend (half squat by 7.3 s) into a
	-- side sit by 8.3 s (song 135.95): the hips on the floor, both legs folded to the left (the left
	-- thigh out to the left-front, its shin back; the right knee forward, its shin across to the left),
	-- the upper body leaning right onto the right hand on the floor, the left hand on the lap (leg angles
	-- found by forward kinematics on the R15 joints). From 8.45 s the whole pose is kept and the body
	-- does not travel (`freeze`, `still`) until 17 lies down
	-- (D-1190, user: "2:16~17 앉은 다음 인어공주 포즈까지 슬로우 걸면서 엉덩이 위치 고정한 상태로 정면 보도록 회전 천천히.
	-- 인어공주 포즈 상태에서 멈춰 있는 시간이 김"): the sit comes slower (half squat by 8.0, the side sit by 9.6 =
	-- song 137.25) and, from 8.3, the body turns slowly from side on (100°) to the front on its spot (the hips
	-- set level, turned by `bend`, so the kept pose afterwards is short: 9.7 to 17's drop at 138.3)
	-- (D-1198, user: "2:16 멈칫하는 거 삭제", "2:15에서 회전할 때 2:18에 캐릭터 방향까지 회전한 다음 앉기 (그럼 2:17에 앉아서
	-- 회전하는 거 사라짐)", "앉은 다음 첨부한 사진 자세로 바로 이어지게 해. 중간에 다리 꼬이는 거 삭제"): the turn to the front
	-- now happens standing at 2:15 (7.3-8.1 = song 134.95-135.75), then she sits straight down (no half-squat hold, seated
	-- by 10.0 = 137.65, just before 17 lies down at 138.3: seated by 136.65 left 1.7 s sitting still) with the knees together and the shins folded back (the photo's legs: no mermaid cross)
	[82680550952125] = { steady = { from = 0, to = 10.3, passes = 8 },
		-- (D-1200, user: "2:14 멈칫 끊김": the facing was held 134.0-135.0 before the turn: it turns from 6.4 now)
		spin = { from = 4.35, to = 4.45, till = 6.4 },
		-- (D-1202, user: "2:14 버벅": `still` starting at 6.4 shifted the body 0.45 stud in one frame (song 134.13): from 4.45 on)
		still = { from = 4.45, to = 30 },
		freeze = { from = 10.2, to = 30, ease = 0.15 },
		bend = { { part = "LowerTorso", keys = { { 6.39, 0, 100, 0 }, { 6.4, 0, 100, 0 }, { 7.9, 0, 0, 0 }, { 7.95, 0, 0, 0 } } } },
		pose = { from = 8.4, to = 30, ease = 1.2, keys = {
			{ t = 10.0, set = (function() local s = { LowerTorso = { 0, 0, 0 } } for k, v in pairs(M.LemonadeSideSit) do s[k] = v end
				s.LeftUpperLeg, s.LeftLowerLeg, s.RightUpperLeg, s.RightLowerLeg = { 0, 0, 0 }, { -95, 0, 0 }, { 0, 0, 0 }, { -95, 0, 0 }
				return s end)(),
				move = { LowerTorso = { 0, -3.44, 0 } } } } } },
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
	-- 17 = the user's hand-keyed clip 17 (D-1019, at 137.92 = practice video 139.0-147.0) (user: "17번 원본
	-- 영상 보면서 프레임 단위로 노래랑 맞추고 그동안 안무 편집하면서 적용했던 보정값들 똑같이 적용해").
	-- `warp`: its keys put on the video's frames (60 fps pose track of clip 17): the centre switches to the
	-- lying member at 0.47 (the drop, 0.29-0.90 of the keys, now ends at 0.65), she lies still until the left
	-- leg kicks up at 1.63-1.70 and stays up to 2.33, comes down by 2.75; the rest runs at its own pace, but it
	-- ends seated (its own quick stand-up at 7.5-7.97 is left out): 18 stands her up over its 1 s blend.
	-- The red-box clip's fixes (above, D-992) moved by its song time (-1.70 s): the lying pose kept but the left
	-- leg (from where she is down), the body on its spot, the upper body straight up at 142.42-144.12, the
	-- sitting pose kept until 18 stands her up. Its `pose` adds (waist, head, right arm on the forearm) too;
	-- its left-leg `set` keys not: the user's own leg keys are on the video's frames
	[123236589131931] = {
		warp = { { from = 0, to = 0.30, play = { 0, 0.29 } }, { from = 0.30, to = 0.65, play = { 0.29, 0.90 } },
			{ from = 0.65, to = 1.52, play = { 0.90, 0.97 } }, { from = 1.52, to = 1.70, play = { 0.97, 1.933 } },
			{ from = 1.70, to = 2.33, play = { 1.933, 2.267 } }, { from = 2.33, to = 2.75, play = { 2.267, 2.70 } },
			{ from = 2.75, to = 7.55, play = { 2.70, 7.50 } }, { from = 7.55, to = 8.0, play = { 7.50, 7.508 } } },
		-- (the times below are the animation's own, after the warp: song 138.58-140.90, 142.42-144.12, 143.92 to the end)
		freeze = { { from = 0.9, to = 2.93, ease = 0.3, except = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } },
			{ from = 5.96, to = 8.5, ease = 0.4 } },
		still = { { from = 0.29, to = 3.05 }, { from = 5.76, to = 8.5 } },
		torsoUp = { from = 4.46, to = 6.16, ease = 0.4 },
		pose = { from = 0.9, to = 2.85, ease = 0.4, keys = {
			{ t = 0.9, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } } },
			{ t = 2.8, add = { UpperTorso = { -25, 0, 0 }, Head = { 15, 0, 0 }, RightUpperArm = { -20, 0, -25 } } },
		} } },
	-- 12 (from 94.39) (D-992, user: "1:38~1:40 앞으로 걸어가는 안무할 때 상체가 너무 뒤로 기울어져
	-- 있음. 상체 일자로 세워. 수직으로"): the upper body straight up through the walk
	[138502286160157] = { torsoUp = { from = 3.4, to = 6.6, ease = 0.4 } },
	-- 17 (from 137.92, the original practice clip since D-1044) (D-1058, user: "2:19 고질 부분.. 엉덩이랑
	-- 하체 땅 아래로 들어가지 않게 하고 팔도 땅 아래로 들어가지 말고 땅 위까지 고정 상체 벌벌 떠는 거
	-- 잡기. 상체 눕힌 상태 고정", "2:22는 좋은데 다리 뻗고 돌리는 범위 좀 더 넓히기 0.5초 더 길게"):
	-- lying at song 138.6-140.9 the hips crept up 0.7 → 1.5 and the chest wobbled: the lying pose of
	-- 138.67 is kept to 140.92 but the legs (the kick goes on), smoothed harder there; the floor
	-- check keeps every part but the feet above the floor (ChoreoController). The leg stretched
	-- and swung at song 141.3-142.7 (3.3-4.8 s) plays 0.5 s longer (2.0 s; the seated pause after
	-- it makes the time up) and the upper legs swing 1.4x as far
	-- (D-1190, user: "2:18 무릎 잠깐 벌어지는 거 수정", "2:20 왼쪽 다리 들 때 오른쪽 다리 고정. 몸체 정면 보고 있는 걸로 고정",
	-- "2:22 몸 살짝 들고 다리 움직이는 거 삭제하고 무릎 꿇는 자세로 자연스럽게 연결 > 무릎 꿇은 자세에서 엉덩이 살짝 들어서
	-- 오른쪽 다리 빼고 쭉 뻗을 것 > 다음은 회전 동일"): the lying pose keeps the right leg too (only the left kicks),
	-- the knees stay together on the way down; the D-1058 / D-1062 stretched leg swing (warp, second freeze,
	-- amp) is gone: from 3.0 (song 140.9) she comes up into a kneel (sitting on the heels, upper body straight)
	-- by 3.9, holds it, lifts the hips a little and slides the right leg out straight to the side (5.4-6.4),
	-- and 18's turn comes as before (song 145.9)
	[132337331292488] = { steady = { { from = 0, to = 8.0, passes = 8 }, { from = 0.6, to = 3.2, passes = 16 } },
		-- (let go over 0.9 s while the kneel comes in: a 0.3 s let-go swung the hips 35° and the right foot 2.7 studs)
		freeze = { { from = 1.4, to = 3.6, ease = 0.3, easeOut = 0.9, except = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } } },
		still = { from = 2.8, to = 8.2 },
		torsoUp = { from = 3.2, to = 8.2, ease = 0.4 },
		-- (D-1062, user: "2:19에 천장 보고 있는데 정면 보도록 회전. 다리 허벅지는 쭉 뻗고 종아리 뒤로", "2:20 다리 더
		-- 쭉 직선으로 뻗기", with the 2:14 squat): 17 starts in 16's squat (0-0.6 s, fading into the drop);
		-- lying, the body turns 55° about its spine so the chest faces the front, not the ceiling (found in
		-- Play: chest 0.75 up → 0.89 to the front); the thighs straight in line with the body and the calves
		-- folded back; the left leg's kick (1.5-2.5 s, song 139.4-140.4) goes up with the knee straight
		-- (D-1068, user: "2:20에 상체 너무 누워 있는데 빨간 선 표시한 위치로 세워") lying on her right side, the
		-- upper body is raised from the waist (bent toward her left = up) onto the right arm; 17 starts in
		-- 16's side sit (D-1068) and turns from 16's kept facing to its own while it lies down (0-0.8 s)
		-- (D-1190: 16 now ends facing the front, so 17 no longer turns from side on: its `spin fromPrev` is gone)
		-- (D-1200, user: "2:19에 있는 상체 모션을 앞에 자세에서 회전하지 말고 상체만 각도 눕히기"): no 55° turn of the hips, the upper
		-- body only leans down to her side (60°)
		-- (the capture lies down flat on its back there (the old 55° turn made the chest face the front): she stays in the side
		-- sit instead, the hips set upright, and only the upper body leans down to her right, 45° (the poses below))
		pose = {
			-- (D-1200, user: "2:17 이 상태에서 무릎 위치 고정하고 무릎 접은 상태에서 옆으로 앉기"): from 16's kneel the hips go down to the
			-- side of the heels (the knees stay, the shins folded: the side sit) by 0.7, and stay so while she lies (no legs together)
			{ from = 0, to = 3.0, ease = 0.25, keys = (function() local k, s = {}, {} for a, v in pairs(M.LemonadeSideSit) do s[a] = v k[a] = v end
				k.LeftUpperLeg, k.LeftLowerLeg, k.RightUpperLeg, k.RightLowerLeg = { 0, 0, 0 }, { -95, 0, 0 }, { 0, 0, 0 }, { -95, 0, 0 }
				k.LowerTorso, s.LowerTorso, s.UpperTorso = { 0, 0, 0 }, { 0, 0, 0 }, { 5, 0, -45 }
				-- (D-1200, user: "2:20 다리 아까보다 앞으로 더 뻗음. 반대 각도로 수정해서 일자로 세우기"): the left leg straight up along her side
				-- (one window with the sit: two windows meeting at 1.5 let the foot drop through the floor for a moment)
				local kick = {} for a, v in pairs(s) do kick[a] = v end
				kick.LeftUpperLeg, kick.LeftLowerLeg = { 0, -50, -155 }, { 0, 0, 0 }
				-- (D-1202, user: "2:17에서 2:19 포즈로 자연스럽게 연결되게 … 갑자기 포즈 바꿈": the side sit and the lean come over 1.3 s, not 0.7)
				return { { t = 0, set = k, move = { LowerTorso = { 0, -3.44, 0 } } }, { t = 1.3, set = s, move = { LowerTorso = { 0, -4.0, 0 } } },
					{ t = 1.5, set = s, move = { LowerTorso = { 0, -4.0, 0 } } }, { t = 1.7, set = kick, move = { LowerTorso = { 0, -4.0, 0 } } },
					{ t = 2.4, set = kick, move = { LowerTorso = { 0, -4.0, 0 } } }, { t = 2.65, set = s, move = { LowerTorso = { 0, -4.0, 0 } } } } end)() },
			-- (D-1200, user: "2:21 왼쪽 다리 고정. 오른쪽 다리 앞으로 뻗으면서 엉덩이 바닥에 붙이기 / 쭉 뻗은 오른쪽 다리 오른쪽으로 벌리면서
			-- 회전"): the kneel by 3.9, then the left leg stays folded, the right leg goes straight forward with the hips down on the
			-- floor (4.6-6.0), then the straight right leg opens out to the right into 18's turn (7.6)
			{ from = 2.7, to = 9.0, ease = 0.9, keys = (function()
				local kneelL = { LeftUpperLeg = { 80, 0, 0 }, LeftLowerLeg = { -150, 0, 0 }, LeftFoot = { 70, 0, 0 } }
				local function with(a, b) local s = {} for k, v in pairs(a) do s[k] = v end for k, v in pairs(b) do s[k] = v end return s end
				return {
					{ t = 3.9, set = with(kneelL, { RightUpperLeg = { 80, 0, 0 }, RightLowerLeg = { -150, 0, 0 }, RightFoot = { 70, 0, 0 } }), move = { LowerTorso = { 0, -3.0, 0 } } },
					{ t = 4.6, set = with(kneelL, { RightUpperLeg = { 85, 0, 0 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 } }), move = { LowerTorso = { 0, -3.6, 0 } } },
					{ t = 6.0, set = with(kneelL, { RightUpperLeg = { 85, 0, 0 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 } }), move = { LowerTorso = { 0, -3.6, 0 } } },
					{ t = 7.6, set = with(kneelL, { RightUpperLeg = { 20, 0, 75 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 } }), move = { LowerTorso = { 0, -3.4, 0 } } },
				}
			end)() },
		} },
	-- (2:26 "일어나면서 몸 돌리는데 두 번 돌림. 한 번으로 깔끔하게": the capture turns 55°
	-- one way, then 141° back in 0.16 s, inside its 1 s blend: one even turn
	-- the short way round from where 17 ended, 0-1.3 s, during the blend too)
	[76195346888656] = { steady = { from = 0, to = 5.0, passes = 8 }, spin = { from = 0, to = 1.3, fromPrev = true, dir = 1, ease = "both" },
		-- (D-1190, user: "2:27 손목 밖으로 꺾") both wrists out at song 146.8-147.6
		bend = { { part = "LeftHand", keys = { { 0.75, 0, 0, 0 }, { 0.95, 0, 0, -50 }, { 1.55, 0, 0, -50 }, { 1.75, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 0.75, 0, 0, 0 }, { 0.95, 0, 0, 50 }, { 1.55, 0, 0, 50 }, { 1.75, 0, 0, 0 } } } } },
	-- (D-1190) 6 (song 39.2): "0:45 뻗은 오른쪽팔 손목 안으로 꺾어서 좌우로 흔들기": the right arm out to the side at song
	-- 45.6-46.5: the wrist bent in and waving side to side
	[131526768823490] = { bend = { { part = "RightHand", keys = { { 6.2, 0, 0, 0 }, { 6.4, 0, 0, -45 }, { 7.2, 0, 0, -45 }, { 7.4, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 6.4, 0, 0, 0 }, { 6.55, 35, 0, 0 }, { 6.7, -35, 0, 0 }, { 6.85, 35, 0, 0 }, { 7.0, -35, 0, 0 }, { 7.15, 0, 0, 0 } } } } },
	-- (D-1190) 7 (song 47.49): "0:50-52 손목 돌리기" the left forearm up in front at song 50.5-52.0: wrist circles;
	-- "0:53 팔 양쪽으로 벌릴 때 손목 밖으로 꺾기" (53.35-53.85, 25°: the capture is already bent out ~60°); "0:56 손목 안으로 꺾고 털기": the arms down and back at
	-- 55.1-55.85: the wrists bent in, flicking
	[99422937735141] = { bend = { { part = "LeftHand", keys = wristCircles(3.0, 4.5, 0.47, 35) },
		{ part = "LeftHand", keys = { { 5.75, 0, 0, 0 }, { 5.9, 0, 0, -25 }, { 6.3, 0, 0, -25 }, { 6.45, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 5.75, 0, 0, 0 }, { 5.9, 0, 0, 25 }, { 6.3, 0, 0, 25 }, { 6.45, 0, 0, 0 } } },
		{ part = "LeftHand", keys = { { 7.5, 0, 0, 0 }, { 7.65, 0, 0, 45 }, { 7.75, 0, 0, 25 }, { 7.85, 0, 0, 45 }, { 7.95, 0, 0, 25 }, { 8.05, 0, 0, 45 }, { 8.15, 0, 0, 25 }, { 8.25, 0, 0, 45 }, { 8.36, 0, 0, 40 } } },
		{ part = "RightHand", keys = { { 7.5, 0, 0, 0 }, { 7.65, 0, 0, -45 }, { 7.75, 0, 0, -25 }, { 7.85, 0, 0, -45 }, { 7.95, 0, 0, -25 }, { 8.05, 0, 0, -45 }, { 8.15, 0, 0, -25 }, { 8.25, 0, 0, -45 }, { 8.36, 0, 0, -40 } } } } },
	-- (D-1190) 19 (song 150.92): "2:38 팔 휘젓는 거에 맞춰서 안밖으로 꺾기": both wrists in and out on the beats, song 157.4-159.5
	[116980798181063] = { bend = (function()
		local L, R, t, s = { { 6.4, 0, 0, 0 } }, { { 6.4, 0, 0, 0 } }, 6.6, 1
		while t < 8.5 do table.insert(L, { t, 0, 0, 40 * s }) table.insert(R, { t, 0, 0, -40 * s }) t += 0.47 s = -s end
		table.insert(L, { 8.7, 0, 0, 0 }) table.insert(R, { 8.7, 0, 0, 0 })
		return { { part = "LeftHand", keys = L }, { part = "RightHand", keys = R } }
	end)() },
	-- (D-1190) 20 (song 160.92): "2:43 왼쪽 팔 뻗고 있는 손 좌우로 인사하듯이 흔들기" (song 162.5-163.7)
	[118071176218932] = { bend = { { part = "LeftHand", keys = { { 1.55, 0, 0, 0 }, { 1.7, 40, 0, 0 }, { 1.9, -40, 0, 0 }, { 2.1, 40, 0, 0 }, { 2.3, -40, 0, 0 }, { 2.5, 40, 0, 0 }, { 2.7, -40, 0, 0 }, { 2.85, 0, 0, 0 } } } } },
	-- (D-1058, user's Lemonade list of 2026-11-09; beats from the practice video's sound: 127.7 bpm,
	-- song beats at 68.31 + 0.4698 k; arm angles read in Play; every beat key is 0.09 s before the beat:
	-- in Play the turns came 0.09-0.12 s late, the animation's clock running that much behind the song)
	-- 7 (from 47.49): "0:55 팔 뻗고 상체 옆으로 숙일 때 끊김 없애기 부드럽게 이어지도록": the capture
	-- stands nearly still at song 55.0-55.75 (its last 0.8 s) before 8 blends in: its last moving
	-- part (6.6-7.5 s) was played slower to the end of the piece (55.92) (undone in D-1062, below)
	-- (D-1062, user: "0:55 앞에 동작을 느리게 한 거 취소하고 뒤에 훅 내려가는 걸 없애. 앞에 동작을 뒤에 훅
	-- 내려가는 부분 삭제한 곳까지 이어지게 해"): the slowing taken out; 8's deep bow at its start
	-- (0.1-0.85 s, song 56.0-56.8) is skipped (ClubPlaylist: 8 from 0.9 at 56.82), 7 keeps its pose until then
	-- 8 (from 55.92): "1:01 0:21이랑 같은 자세인 것 확인 후 손목 돌리기 추가": the left arm is in the
	-- same ㄱ (upper arm 86-91° up, elbow ~94°) at song 61.0-61.9: two circles, one a beat (60.79-61.73)
	[99169381541568] = { bend = { { part = "LeftHand", keys = { { 4.70, 0, 0, 0 }, { 4.78, 30, 0, 0 }, { 4.90, 0, 0, 30 }, { 5.01, -30, 0, 0 },
		{ 5.13, 0, 0, -30 }, { 5.25, 30, 0, 0 }, { 5.37, 0, 0, 30 }, { 5.48, -30, 0, 0 }, { 5.60, 0, 0, -30 }, { 5.72, 0, 0, 0 } } },
		-- (D-1190, user: "1:00 뻗은 팔 손목 한바퀴") the left arm reaching forward at song 59.7-60.3: one wrist circle
		{ part = "LeftHand", keys = wristCircles(3.8, 4.4, 0.6, 40) } } },
	-- 9 (from 67.05): "1:10 팔 몸 앞에 들고 흔드는 안무에서 손목 90도 돌렸다가 돌아오는 반복 빠르게 박자에
	-- 맞춰서": the left forearm is up in front (elbow ~90°) at song 69.6-72.0: on each beat (69.72 ...
	-- 71.60) the hand turns 80° about the forearm and back by the half beat
	[100397079318559] = { bend = { { part = "LeftHand", keys = { { 2.58, 0, 0, 0 }, { 2.71, 0, 80, 0 }, { 2.90, 0, 0, 0 }, { 3.05, 0, 0, 0 },
		{ 3.18, 0, 80, 0 }, { 3.37, 0, 0, 0 }, { 3.52, 0, 0, 0 }, { 3.65, 0, 80, 0 }, { 3.84, 0, 0, 0 }, { 3.99, 0, 0, 0 }, { 4.12, 0, 80, 0 },
		{ 4.31, 0, 0, 0 }, { 4.46, 0, 0, 0 }, { 4.59, 0, 80, 0 }, { 4.78, 0, 0, 0 } } } } },
	-- 11 (from 85.92): "1:25 처음에 팔 크게 내리고 두 번째 엄청 미세하게 내리는데 두 번째 내리는 것도 아예
	-- 아래로 크게 내리기": the second time (song 86.2-86.9) the left arm came down with the elbow still
	-- bent 55-65° (the hand at the waist): the elbow straightens, the arm all the way down
	[83846438884132] = { pose = { from = 0.25, to = 1.0, ease = 0.2, keys = { { t = 0.4, set = { LeftLowerArm = { 0, 0, 0 } } } } },
		-- (D-1190, user: "1:30 손목 밖으로 꺾" + photo: the hand by the head, palm out) the left hand up at song 90.0-91.0
		bend = { { part = "LeftHand", keys = { { 3.9, 0, 0, 0 }, { 4.15, 0, 0, -60 }, { 4.9, 0, 0, -60 }, { 5.15, 0, 0, 0 } } } } },
	-- 15 (from 114.92): "1:57 1:10과 동일": the same forearm-up shake at song 116.4-119.1: the same
	-- hand turns on the beats 116.70 ... 118.58
	[118124487485279] = { bend = { { part = "LeftHand", keys = { { 1.69, 0, 0, 0 }, { 1.82, 0, 80, 0 }, { 2.01, 0, 0, 0 }, { 2.16, 0, 0, 0 },
		{ 2.29, 0, 80, 0 }, { 2.48, 0, 0, 0 }, { 2.63, 0, 0, 0 }, { 2.76, 0, 80, 0 }, { 2.95, 0, 0, 0 }, { 3.10, 0, 0, 0 }, { 3.23, 0, 80, 0 },
		{ 3.42, 0, 0, 0 }, { 3.57, 0, 0, 0 }, { 3.70, 0, 80, 0 }, { 3.89, 0, 0, 0 } } },
		-- (D-1190, user: "1:55 왼쪽 손 반짝반짝" song 115.1-116.0; "2:07 손목 안으로 꺾기" song 126.8-127.5, both)
		{ part = "LeftHand", keys = wristTwinkle(0.2, 1.1, 0.2, 60) },
		{ part = "LeftHand", keys = { { 11.8, 0, 0, 0 }, { 12.0, 0, 0, 45 }, { 12.5, 0, 0, 45 }, { 12.7, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 11.8, 0, 0, 0 }, { 12.0, 0, 0, -45 }, { 12.5, 0, 0, -45 }, { 12.7, 0, 0, 0 } } } } },
	-- 21 (from 168.42): "2:49 손목 90도로 돌리기 반복": both forearms up in front at song 169.0-170.8:
	-- both hands turn on the beats 169.32 / 169.79 / 170.26 (the right one the mirror way)
	-- (D-1190, user: "2:49 현재 손목 흔드는데 더 크게 더 빠르게 돌릴 것", "2:57 2:49에서의 손목 동작처럼 더 크게 더 빠르게 회전"):
	-- 120° instead of 80°, on every half beat (0.235 s) instead of every beat; the same at song 176.6-177.5
	[76826604804095] = { bend = (function()
		local function turns(t0, t1)
			local L, R, t = { { t0, 0, 0, 0 } }, { { t0, 0, 0, 0 } }, t0
			while t + 0.235 <= t1 + 1e-6 do
				table.insert(L, { t + 0.1, 0, 120, 0 }) table.insert(R, { t + 0.1, 0, -120, 0 })
				table.insert(L, { t + 0.235, 0, 0, 0 }) table.insert(R, { t + 0.235, 0, 0, 0 })
				t += 0.235
			end
			return L, R
		end
		local L1, R1 = turns(0.81, 2.07)
		local L2, R2 = turns(8.2, 9.05)
		return { { part = "LeftHand", keys = L1 }, { part = "RightHand", keys = R1 }, { part = "LeftHand", keys = L2 }, { part = "RightHand", keys = R2 } }
	end)() },
	-- 22 (from 177.49): "3:5에 고개 숙였다가 턱 들고 다시 원위치. 박자에 맞춰서": the head drops on the
	-- beat 184.82, the chin comes up on 185.29 and the head is back on 185.76
	[89070118321317] = { bend = { { part = "Head", keys = { { 7.04, 0, 0, 0 }, { 7.24, -25, 0, 0 }, { 7.71, 18, 0, 0 }, { 8.18, 0, 0, 0 } } } } },
	-- Catch Catch v2 centre pieces (D-981, the user's list of 2026-11-08 on the pieces
	-- choreo-add cut again, D-980). v2 12 (song 107.77): 1:50 "팔 드는 거 조금 더 올리게 해 줘
	-- 부드럽게 웨이브하듯이": she opens both arms out and up at song 111.6-112.3, the capture
	-- only to the waist; the upper arms turn 1.5x as far there
	[88923183102495] = { amp = { from = 3.7, to = 5.2, ease = 0.4, parts = { LeftUpperArm = 1.5, RightUpperArm = 1.5 } } },
	-- (D-1070, user 2026-11-10: "캐치캐치 2:06부터 버벅거림. 바로 전 동작이랑 같은 안무일 거임. 원본 확인 후 동작
	-- 반복으로 매끄럽게"): v2 13 (song 121) dances one move twice, 2.4 s apart (hand by the face at clip
	-- 4.05 / 6.45, the bent-knee sway at 4.8 / 7.2), and the member in front hides her each time (3.75-3.9,
	-- 6.15-6.3): the second time the capture shook (23°/frame, 7 turn-backs at song 127.3-127.7). From
	-- 5.95 s (song 126.95, where the two times are closest, 15° apart) it plays the first time again
	-- (3.6-5.42 s), smoothed over the seam
	[73949956743570] = { warp = { { from = 0, to = 5.95, play = { 0, 5.95 } }, { from = 5.95, to = 7.77, play = { 3.6, 5.42 } } },
		steady = { from = 5.75, to = 6.35, passes = 8 } },
	-- (D-1070, user: "마지막 자세 잡을 때 손목 안쪽으로 꺾기 손등에 얼굴 올리는 것처럼") v2 20 (song 169.73): in the
	-- end pose (song 179.0 on) the hand under the chin had its fingers up; the wrist bends in 70° so the
	-- fingers lie across under the chin and the back of the hand is up under the face (`bend` turns the
	-- joint the game shows: her left hand, mirrored or not)
	-- (D-1188, user: "2:56?57? 마지막에 손목 안으로 꺾은 거 밖으로 꺾어서 꽃받침처럼") the other way: bent out, palm up
	-- under the chin, the fingers out to the side
	-- (D-1192, user: "2:55 오른쪽 팔 프레임 튐") song 178.5: the right hand zigzagged 2 studs a frame-step at 178.1-178.6: smoothed hard
	-- (D-1194, user: "2:55~56에 오른쪽 팔 몸통쪽으로 한 번 접힘. 삭제하고 고정"): the right arm held as it is at 8.2 to the end (at 9.8 it folded in at 2:56 instead)
	[127455820218376] = { freeze = { from = 8.2, to = 30, ease = 0.25, except = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Head", "UpperTorso", "LowerTorso" } },
		bend = { { part = "LeftHand", keys = { { 8.9, 0, 0, 0 }, { 9.3, 0, 0, -70 }, { 30, 0, 0, -70 } } } } },
	-- (D-1188, user 2026-11-10, Catch Catch) 7 (song 48.27): "0:48 양쪽팔 벌리는 안무 더 높게 들어올리는 걸로 이어지게
	-- 연결(1:48~1:50구간 동작 참고)": the arms open at song 49.2 with the hands at -1.8 (below the shoulders); 1:50
	-- (v2 12) sweeps them up to +0.7 with the shoulders 1.5x (D-981): the same here
	-- (1.5x only lifted the left hand to +0.2: 2x and the arms lifted 30° more out to the sides at the top)
	[74567972410299] = { amp = { from = 0.55, to = 1.75, ease = 0.3, parts = { LeftUpperArm = 2, RightUpperArm = 2 } },
		bend = { { part = "LeftUpperArm", keys = { { 0.9, 0, 0, 0 }, { 1.25, 0, 0, -30 }, { 1.5, 0, 0, -30 }, { 1.8, 0, 0, 0 } } },
			{ part = "RightUpperArm", keys = { { 0.9, 0, 0, 0 }, { 1.25, 0, 0, 30 }, { 1.5, 0, 0, 30 }, { 1.8, 0, 0, 0 } } } } },
	-- (D-1192, user: BAD "2:24 끊기면서 버벅거림 정리") 19 (from 4.0 at song 141.25) nearly stands at its 4.6-5.9 s (song
	-- 142.0-143.3), then flings the arms up and down in 1.1 s: the stand plays in 0.3 s and the move after it slower
	[95469533767642] = { warp = { { from = 4.6, to = 4.9, play = { 4.6, 5.9 } }, { from = 4.9, to = 7.9, play = { 5.9, 7.9 } } } }, -- (4.6-5.4 left 0.6 s standing)
	-- (D-1168, user 2026-11-10, ATEEZ-BAD) 9 (song 53): "55 측면으로 무릎 굽히고 앞으로 걸어가는 모션. (오리처럼 고개도
	-- 움직이면 좋음) 얼굴은 정면 화면 봐야 함": the capture stands side on (hips -60°) from song 55.3; from
	-- 55.0 to 57.9 a bent-knee walk, a step a beat (0.5 s), the head bobbing forward on each step and turned
	-- 60° to the front (chest 24°, neck 36°)
	-- (user: "몸이 보는 옆쪽으로 이동") and the body walks 2.5 studs the way the hips face (`walk`)
	[86108317246080] = { pose = { from = 2.0, to = 4.95, ease = 0.35, keys = duckWalk(2.1, 4.85, 0.5, 60) }, walk = { from = 2.1, to = 4.85, dist = 2.5 } },
	-- (D-1168 / D-1192) 8 (song 81.85) stands still from 6.95 s (song 88.8, back turned, hand on the hip, as in the video)
	-- to its end. D-1168 swayed the hips by turning them, and the legs turned with them (the feet slid). D-1192, user:
	-- "1:30 가만히 서서 골반 흔드는 걸로 바꿨던 거 발은 제자리에 붙이고 엉덩이만 빼는 거 안 돼?"
	-- (user times: the earlier list was read on a phone, its times x 0.948 = song: 1:35 → 1:30)
	-- (the hips' side shift does not show: the controller keeps the hips over the root, so `move` only slid the feet;
	-- instead the hips tilt and turn on the beat and the thighs and the chest turn back the same amount: the feet stay)
	[97769840770691] = { bend = (function()
		local H, L, Rl, U, t, s = { { 6.95, 0, 0, 0 } }, { { 6.95, 0, 0, 0 } }, { { 6.95, 0, 0, 0 } }, { { 6.95, 0, 0, 0 } }, 7.2, 1
		while t < 11.3 do
			table.insert(H, { t, 0, -6 * s, 9 * s }) table.insert(L, { t, 0, 6 * s, -9 * s }) table.insert(Rl, { t, 0, 6 * s, -9 * s })
			table.insert(U, { t, 0, 5 * s, -7 * s })
			t += 0.508 s = -s
		end
		for _, k in ipairs({ H, L, Rl, U }) do table.insert(k, { 11.45, 0, 0, 0 }) end
		return { { part = "LowerTorso", keys = H }, { part = "LeftUpperLeg", keys = L }, { part = "RightUpperLeg", keys = Rl }, { part = "UpperTorso", keys = U } }
	end)() },
	-- 18 (song 125.3): "2:5 팔 움찔": both hands flick out 1 stud and back in 0.15 s at song 125.8-126.0 (the
	-- video opens the arms slowly): the arms smoothed hard there
	[127427471547985] = { steady = { from = 0.1, to = 1.1, passes = 8, parts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } } },
	-- 21 (song 148.37): "2:29 왼쪽팔 위아래로 움직이는 동작인데 더 위로 올렸다가 더 아래로 내리기": the left arm
	-- swings up at song 149.4 (hand 2.15 over the chest) and 151.9 (only 1.13): the shoulder turns 1.35x /
	-- 1.5x as far, and before and after each lift the arm swings back down past the hip
	[138812417192850] = { amp = { { from = 0.55, to = 1.55, ease = 0.25, parts = { LeftUpperArm = 1.35 } }, { from = 3.05, to = 4.0, ease = 0.25, parts = { LeftUpperArm = 1.5 } } },
		bend = { { part = "LeftUpperArm", keys = { { 0.4, 0, 0, 0 }, { 0.58, -22, 0, 0 }, { 0.72, 0, 0, 0 }, { 1.3, 0, 0, 0 }, { 1.48, -22, 0, 0 }, { 1.68, 0, 0, 0 },
			{ 2.9, 0, 0, 0 }, { 3.08, -22, 0, 0 }, { 3.22, 0, 0, 0 }, { 3.8, 0, 0, 0 }, { 3.98, -22, 0, 0 }, { 4.18, 0, 0, 0 } } } } },
	-- (D-1192, user: "앞에 지시했던 게 모바일로 본 거라 시간 차이가 있는 듯 … 엉뚱한 곳에서 손목 반짝이고 있음": the phone times
	-- x 0.948 = song (1:11 → 1:08, 1:35 → 1:30, 2:54 → 2:45, 3:18 → 3:08); D-1168 put these 3 s late) "1:8 오른쪽 손목 돌리기
	-- 반복", "1:9~10 양쪽 손목 돌리기 반복", "1:11 왼쪽 손목 돌리기 반복", at the arms measured in Play: the right arm out at
	-- song 67.5-68.9 (6's end and 7's start), both up 69.8-71.0, the left out 71.3-72.5 (D-1168's twinkle at 1:13 was
	-- this both-arms move: circles now)
	-- (D-1194, user: "1:8 손목 한번만 돌리는데 팔 뻗는 동안 슬로우 걸어서 돌리기", "1:9 너무 빨라 천천히 돌리기", "1:11 … 한번만 … 슬로우"):
	-- one slow circle over the arm out (1:08 in 6: song 67.34-68.34; 1:11 in 7: 71.3-72.5), 1:09 two slow circles (0.58 s each)
	[105545108302127] = { bend = { { part = "RightHand", keys = wristCircles(8.95, 9.95, 1.0, 35) } } },
	[107809363798601] = { bend = { { part = "RightHand", keys = wristCircles(1.7, 2.85, 0.575, 35) }, { part = "LeftHand", keys = wristCircles(1.7, 2.85, 0.575, 35) },
		{ part = "LeftHand", keys = wristCircles(3.15, 4.35, 1.2, 35) } } },
	-- (D-1192) D-1168's "2:50 반짝반짝" / "2:54 상체" (21, song 173) and "3:18~3:25 반짝반짝" (22-25, song 198.8-205.8) were the
	-- phone times: moved to 2:43 / 2:45 (19) and 3:08-3:12 (23).
	-- 19 (song 161.5): "2:43 손목 안밖으로 꺾이게": both arms straight down at song 163.2-164.8, the wrists in and out on
	-- the half beats; "2:45 오른쪽 팔 움찔거리는 거 수정하고 몸 앞으로 숙이면서 회전하는 거 반경 더 크게": the right hand
	-- jumped 1.5-2 studs in 0.2 s at 165.9-167.1 (smoothed hard); the upper body went only 30° forward at 166.5-167.1:
	-- a bigger circle, 25° more forward, to the side, 20° back, to the other side (166.0-168.4)
	[98754942494305] = { steady = { from = 4.2, to = 6.0, passes = 8, parts = { "RightUpperArm", "RightLowerArm", "RightHand" } },
		-- (D-1194, user: "2:43 손목 움직임 삭제": the in / out bends are out, the circle of the upper body stays)
		bend = { { part = "UpperTorso", keys = { { 4.5, 0, 0, 0 }, { 5.15, -25, 0, 0 }, { 5.6, -15, 0, 14 }, { 6.0, 0, 0, 16 }, { 6.4, 20, 0, 0 }, { 6.75, 8, 0, -14 }, { 7.0, 0, 0, 0 } } } } },
	-- 23 (song 188.56): "3:08 오른 손 반짝반짝", "3:10 양손 반짝반짝", "3:12 왼손 반짝반짝": the right arm out at song
	-- 189.0-190.0, both up 190.5-191.6, the left out 192.3-193.8 (Play)
	-- (D-1194, user: "3:8 / 3:12 손목 한번만 돌리는데 팔 뻗는 동안 슬로우 걸어서 돌리기": one slow circle each, 3:10 twinkle kept)
	[105428606733839] = { bend = { { part = "RightHand", keys = wristCircles(0.44, 1.44, 1.0, 35) },
		{ part = "LeftHand", keys = wristTwinkle(1.94, 3.04, 0.2, 60) }, { part = "RightHand", keys = wristTwinkle(1.94, 3.04, 0.2, 60) },
		{ part = "LeftHand", keys = wristCircles(3.74, 5.24, 1.5, 35) } } },
	-- 15 (song 142.41): "2:22 한바퀴 도는 거 매끄럽게": the turn stalled at the seam (12° in 0.3 s at
	-- 142.4-142.7): 15 carries it on from 14's facing in one even turn
	[137553505478362] = { spin = { from = 0, to = 0.8, fromPrev = true, dir = -1, ease = "linear" } }, -- ("both" started slow: still a stall at the seam)
	-- 26 (song 210.11): "3:44? 45?에 무릎 꿇고 있을 때 한번 위로 들썩거림": the last piece ends at song 216.2 while the song
	-- runs on, and she stood up from the kneel in 0.3 s; now the kneel is kept (ClubPlaylist slowOut) and calm
	[127828014236660] = { steady = { from = 1.6, to = 6.1, passes = 8 }, still = { from = 1.6, to = 6.1 } },
	-- v2 17 (song 143.2): 2:26 the walk into the circle turned 31° back, flicked
	-- round at 720°/s, stopped, then turned on: one even turn (piece 2.45-3.6 s);
	-- the pops stand still and calm (still + steady) so they show
	-- 2:28 "팔 들다가 맘. 팔 들지 말고 배드에 가슴 튕기는 안무 참고해서 상체 튕기는 안무로 …
	-- 이후에 한박자 쉬고 두 번 더 튕김": the arms stay down (the capture raised the
	-- right arm at song 148.0 and the left at 149.1) and the chest pops on the
	-- music's hits: song 148.13, (148.56 rest), 149.0, 149.44 (beats 0.434 s)
	-- (D-1188, user: "2:25에 가슴 튕기는 안무 한박자 빠름") the pops, their arm swings and the 2:28 pose all one beat
	-- (0.435 s, 138 bpm) later: 5.80 / 6.68 / 7.11
	-- (D-1192, user: "가슴 튕기는 안무 2:26? 부터 시작해야 함 지금 시작이 빠름": play bar x 1.02 = song, 2:26 = 148.9 = the first pop;
	-- the chest already bumped 0.2 at song 148.2-148.4 (the capture): the body above the hips is held from 4.9 to the first pop)
	-- (D-1194, user: "가슴 튕기는 안무 0.5초 늦게 시작하고 끝나고 한 번 더 하기"): the pops at 6.30 / 7.18 / 7.61 and one more
	-- a beat later (8.05, song 151.25); the chest held to the first, the 2:28 pose after the last
	[115248452065042] = { spin = { from = 2.45, to = 3.6, ease = "both" }, still = { from = 4.9, to = 8.4 }, steady = { from = 4.9, to = 8.4, passes = 8 },
		freeze = { from = 4.85, to = 6.22, ease = 0.15, except = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Head" } },
		-- (D-987, user: "2:25~ 에 가슴 튕기는 거 원본 영상 보고 박자 잘 맞출 것. 팔 안무 추가할 것",
		-- "2:28 안무 영상 보고 구현 수정"): in the video she arches with her head back at
		-- video 147.6-147.8 = song 148.4, on the music's hit 148.56 (D-981 had the pops
		-- one beat early): pops on the hits 148.56, (149.0 rest), 149.44, 149.87, the
		-- arms swinging out a little with each pop; then at 2:28 (song 150.1-151.3) she
		-- stands with the chest out and the chin up
		pops = { at = { 6.30, 7.18, 7.61, 8.05 }, sizes = { 1.8, 1, 1.2, 1.2 }, push = 0.5, lift = 0.2, arch = 8, out = 0.05, back = 0.35 },
		pose = { { from = 4.5, to = 8.4, ease = 0.3, keys = (function()
			local down = { LeftUpperArm = { 0, 0, -6 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 0, 0, 6 }, RightLowerArm = { 10, 0, 0 } }
			local out = { LeftUpperArm = { -12, 0, -22 }, LeftLowerArm = { 28, 0, 0 }, RightUpperArm = { -12, 0, 22 }, RightLowerArm = { 28, 0, 0 } }
			local keys = { { t = 4.5, set = down } }
			for _, at in ipairs({ 6.30, 7.18, 7.61, 8.05 }) do
				table.insert(keys, { t = at - 0.06, set = down })
				table.insert(keys, { t = at + 0.02, set = out })
				table.insert(keys, { t = at + 0.3, set = down })
			end
			return keys
		end)() },
		{ from = 8.4, to = 9.0, ease = 0.3, keys = { { t = 8.4, add = { Head = { 10, 0, 0 }, UpperTorso = { 6, 0, 0 }, LeftUpperArm = { -8, 0, -4 }, RightUpperArm = { -8, 0, 4 } } } } },
		-- (D-983) play bar 2:20 the left hand still across the body from v2 16: arm out of the body
		{ from = -1, to = 0.7, ease = 0.3, keys = { { t = 0, add = { LeftUpperArm = { 10, 25, -8 } } } } } } },
	-- RIIZE-Love 119 1 (D-962, user: "시작 부분에 처음 포즈로 가만히 서 있고 … 그
	-- 자세에서 다음 걷는 안무로 자연스럽게 이어지도록") the first pose is held still
	-- (the capture sways 20° and shifts) until the walk (2) blends in over 0.9 s
	-- (D-1168, user 2026-11-10: "시작할 때 가만히 서 있는데 캐릭터 전체가 사선으로 서 있어 똑바로 일자로 서 있게 해"): in
	-- that pose the upper body leaned 7° to the side and the feet stood 18° askew (one ahead): both legs
	-- straight down (feet side by side), the hips level and the upper body straight up, then held
	[116659270658163] = { hold = { from = 0, to = 3.6 }, upright = { from = -1, to = 3.75, ease = 0.4 }, torsoUp = { from = -1, to = 3.75, ease = 0.4 },
		pose = { from = -1, to = 3.75, ease = 0.4, keys = { { t = 0, set = { LeftUpperLeg = { 0, 0, 0 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { 0, 0, 0 },
			RightUpperLeg = { 0, 0, 0 }, RightLowerLeg = { 0, 0, 0 }, RightFoot = { 0, 0, 0 } } } } } },
	-- (D-1168, user: "1:01 왼쪽 다리 드는 안무일 때 상체가 왼쪽으로 잠깐 기울어짐 상체 고정"): the left leg is up at song
	-- 61.0-62.0 and the upper body tipped 16-18° left at 61.7-61.9 as 13 blended in: straight up there
	-- (`torsoUp` on 11 and 12 below)
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
	-- (D-1020, user: "2:22 앞으로 삐걱거림. 매끄럽게 수정"): its hips went forward in three dashes
	-- (0.63-0.92, 1.04-1.34, 1.67-1.92; up to 7 stud/s in Play, then a stop): one even glide 141.2-143.67
	[118835663786601] = { spin = { from = 0.3, to = 2.95, ease = "both" }, steady = { from = 0.3, to = 3.0, parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }, passes = 8 },
		glide = { from = 0.5, to = 2.97 },
		-- (D-1297, user: 갑자기 "2:23 왼쪽팔 튐"): ChoreoBodyGuard pushed the left arm out of the chest and back (3 turn-backs at song
		-- 142.57-142.79, none with the guard off): the guard lets the left arm go there
		guardOff = { from = 1.5, to = 2.5, side = "Left" } },
	[136490889932903] = { spin = { from = 0, to = 0.6, fromPrev = true, dir = -1, ease = "both" } },
	-- 21 (from 149.7) "2:42 팔 들면서 바들바들 떨어": the arms smoothed 159-163.6
	-- (D-1297, user: 갑자기 "2:35 왼쪽 어깨에 올린 오른손 튐"): the right hand on the left shoulder is inside the guard's reach: it pushed
	-- the arm off and back (4 turn-backs at song 155.25-155.61, none with the guard off): the guard lets the right arm go there
	[123714434236489] = { steady = { from = 9.3, to = 13.9, parts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }, passes = 8 },
		guardOff = { from = 5.0, to = 6.6, side = "Right" } },
	-- 25 (from 180.7) "3:02 걸어갈 때 상체 뒤로 눕는 거 수정": straight up through the walk
	[129257680770934] = { torsoUp = { from = 0.3, to = 6.0, ease = 0.4 } },
	-- 6 (D-962, user: 0:32 "회전 한 바퀴 자연스럽게"): 5 ends turning (-92° → -176°
	-- in its last 0.9 s) and 6 starts at +15°, blending over 1 s (the blend
	-- turned the short way back, 178° in a frame): one even turn on the same
	-- way round, from where 5 ended to 6's facing at 1.2 s
	[75370013537988] = { spin = { from = 0, to = 1.2, fromPrev = true, dir = -1, ease = "both" } },
	-- 11, 12 (D-962, user: "1:00-1:01 캐릭터 갑자기 앞으로 이동"): the feet slide
	-- 0.6-2 studs at 4.6-5.9 and in 12 (1.2 s): in place
	[79064359810628] = { still = { { from = 4.6, to = 5.9 } }, torsoUp = { from = 5.45, to = 7.0, ease = 0.3 } }, -- (torsoUp: D-1168 1:01)
	-- 8 (D-965, found by tools/choreo/play_record.lua): the capture's hips dash
	-- 2 studs off in its last 0.3 s (0:46.1-46.35): in place
	[140553219106220] = { still = { { from = 2.9, to = 3.4 } } },
	-- (D-1192, user: LOVE119 "1:01 다리 한쪽 올리고 내릴 때 프레임 흔들리는 듯. 깔끔하게 한 번에 내리는 걸로"): the left foot came down
	-- over 1 s in small steps (song 61.1-62.1) while 13 blended in over 0.98 s: blend 0.4 (ClubPlaylist) and the leg smoothed
	[103495705227564] = { still = { { from = 0, to = 1.2 } }, torsoUp = { from = -1, to = 0.95, ease = 0.3 },
		steady = { from = 0, to = 1.0, passes = 8, parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } } }, -- (torsoUp: D-1168 1:01)
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
	-- (D-1030, user: "ISPY 1:20 이 부근에 휙 도는 거") piece 15 starts in the middle of a
	-- turn (hips 152° → 326° over its first 0.67 s, piece 14 ended at 74° still turning
	-- the same way); the cross-fade went the short way once the gap passed 180° and
	-- whipped back 170° in 0.25 s (841°/s) at song 77.95-78.15. One even turn the
	-- same way instead, from where piece 14 left the hips
	[135074521559748] = { spin = { from = 0, to = 0.8, ease = "both", fromPrev = true, dir = 1 } }, -- 15 (1:18)
	-- YENA-Catch Catch v2 centre clips (D-980): Play scan SPIN 641-723°/s, spread evenly
	[79075546317269] = { spin = { from = 9.2, to = 9.55, ease = "both" } }, -- v2 11 (1:44)
	[108680095506820] = { spin = { from = 0.65, to = 2.4, ease = "both" } }, -- v2 19 (bar 2:40-2:42; user "2:40초까지 다리 벌벌 떨어": one even turn, the two short ones whipped the legs and hands)
	[114010461044470] = { spin = { from = 9.3, to = 9.85, ease = "both" }, -- v2 16 (2:21, +140° turn)
		-- (D-983, user: play bar 2:19 "팔 몸통 통과") the arms folded across the chest at song
		-- 141.5-142.3 sank into the body: upper arms turned 25° out, 8° open, 10° forward
		pose = { from = 9.75, to = 12, ease = 0.3, keys = { { t = 9.75, add = { LeftUpperArm = { 10, 25, -8 }, RightUpperArm = { 10, -25, 8 } } } } },
		-- (D-1188, user: "2:19 손목 안쪽으로 꺾기") with the arms folded (song 141.4-142.5) both wrists bend in 45°
		bend = { { part = "LeftHand", keys = { { 9.8, 0, 0, 0 }, { 10.1, 0, 0, 45 }, { 10.9, 0, 0, 45 }, { 11.2, 0, 0, 0 } } },
			{ part = "RightHand", keys = { { 9.8, 0, 0, 0 }, { 10.1, 0, 0, -45 }, { 10.9, 0, 0, -45 }, { 11.2, 0, 0, 0 } } } } },
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
	-- 백화요란-RESCENE (D-1293, choreo_slide_check)
	[129031824166857] = { { 7.8, 8.5 }, { 9.5, 10.2 } }, [74180602033079] = { { 2.7, 3.3 }, { 6.8, 7.4 } }, [100400560200750] = { { 0.0, 0.8 } },
	[123368765880247] = { { 1.8, 2.4 }, { 8.0, 8.6 }, { 8.9, 10.0 } }, [76096143466808] = { { 6.8, 8.2 }, { 8.8, 9.6 } }, [108852044755937] = { { 3.7, 4.7 }, { 7.3, 8.0 } },
	[100292773355070] = { { 2.9, 4.2 } }, [72320524127017] = { { 0.6, 1.5 } }, [118315209448422] = { { 1.7, 2.3 } },
	[138514282006084] = { { 0.8, 1.4 }, { 2.4, 4.0 }, { 5.4, 6.0 }, { 7.9, 8.7 } }, [87258411271471] = { { 4.6, 5.5 } }, [106836976565207] = { { 6.7, 7.5 }, { 8.4, 8.9 } },
	-- (choreo_motion_scan DRIFT: hips and both feet slide together)
	-- (Play scan: SLIDE 1:03.0, 2:52.5; TELEPORT 1:20.1, 1:47.6 (centre hidden at 7.6 s), 3:24.4: the body slides 1.1-2.1 studs in 0.3 s with small steps)
	[70716391841768] = { { 0.9, 1.7 }, { 2.2, 2.7 } }, [105306563598355] = { { 3.4, 4.2 } }, [126812347548541] = { { 0.1, 0.9 } },
	-- Hearts2Hearts-Lemon Tang (D-1040)
	[100331751999626] = { { 1.9, 2.6 }, { 2.7, 3.4 } }, [70997868814427] = { { 4.7, 5.5 }, { 6.7, 7.3 } }, [94645609133900] = { { 0.5, 1.1 }, { 3.7, 4.4 } },
	[124676885767926] = { { 0.9, 1.5 } }, [119643676032061] = { { 3.0, 3.8 } }, [88699205496882] = { { 8.0, 8.6 } }, [125963510042067] = { { 0.0, 0.5 } },
	[81450928736064] = { { 0.7, 1.4 } }, [77958598718744] = { { 0.3, 1.3 } }, [83504291197334] = { { 0.1, 0.7 } }, [115787352538480] = { { 9.3, 10.0 } },
	[99840608563579] = { { 1.4, 2.2 }, { 5.1, 5.8 } }, [134866535240552] = { { 0.2, 0.8 } },
	-- ATEEZ-BAD 2 (D-994)
	[101690327843945] = { { 0.4, 1.0 } }, [106954590912232] = { { 5.1, 5.8 } }, [73352408497618] = { { 6.7, 7.4 } },
	[91647545899849] = { { 2.9, 3.6 }, { 5.5, 6.6 } }, [86108317246080] = { { 2.0, 3.3 }, { 4.2, 4.9 } },
	[79044145915210] = { { 3.9, 4.5 } }, [90945372575300] = { { 2.8, 3.6 } }, [127427471547985] = { { 6.3, 6.9 } },
	[138812417192850] = { { 2.0, 2.6 } },
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
	-- (18's 0.7-1.4 taken out, D-1020: it stopped the walk there and the rest came as a dash; its `glide` evens it)
	[136490889932903] = { { 1.9, 2.5 } }, [92331354114542] = { { 1.7, 2.5 } },
	[123714434236489] = { { 0.7, 1.6 }, { 9.1, 9.8 }, { 10.8, 11.5 }, { 13.0, 14.1 } }, [82782712192367] = { { 2.7, 3.8 }, { 4.3, 5.0 } },
	[129257680770934] = { { 5.8, 6.8 }, { 10.2, 10.8 } },
	[81367674902881] = { { 0.4, 1.2 }, { 1.9, 2.5 }, { 2.9, 3.6 } }, [84783409830169] = { { 1.3, 1.9 }, { 3.3, 3.9 } },
	-- YENA-Catch Catch (D-968)
	[112551530516434] = { { 6.5, 7.1 } }, [74567972410299] = { { 10.3, 10.9 } }, [110540650870002] = { { 2.0, 2.6 }, { 3.2, 3.8 } },
	[107833429874111] = { { 3.9, 4.5 }, { 5.0, 5.6 } }, [138852020855643] = { { 0.4, 1.0 } }, [111787124658928] = { { 2.1, 2.8 } },
	[113094829637212] = { { 0.4, 1.0 }, { 2.1, 2.8 }, { 2.9, 3.5 } }, [104636507093618] = { { 1.8, 2.4 } },
	[116715438780373] = { { 0.0, 1.4 }, { 1.6, 2.2 }, { 5.9, 6.9 } },
	[98063579481098] = { { 3.3, 3.9 }, { 8.0, 8.6 } },
	-- YENA-Catch Catch v2 centre clips (D-980)
	[79075546317269] = { { 5.1, 5.7 }, { 6.0, 6.9 }, { 8.0, 8.6 }, { 10.0, 10.9 }, { 10.9, 11.5 } }, [73949956743570] = { { 5.7, 6.4 }, { 6.4, 7.0 } },
	[89344916640647] = { { 0.2, 0.8 } }, [124345431625014] = { { 7.4, 8.1 } }, [108680095506820] = { { 5.2, 6.1 } },
	[127455820218376] = { { 1.2, 1.8 }, { 2.4, 3.4 }, { 4.1, 4.8 } },
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
	-- Hearts2Hearts-Lemon Tang (D-1040, Play scan 1:20.0 SLIDE 0.5 stud, feet still)
	[110925421163686] = { { 6.9, 7.5 } },
	-- ALLDAY PROJECT-CRASH (D-1041, Play scan on the new upload: 1:16.7, 1:21.8, 2:18.3, 2:31.1, the body
	-- going 1-2 studs while the feet step a fifth of it or less)
	[103539561583468] = { { 1.0, 1.6 } }, [116383725353409] = { { 2.8, 3.4 } }, [130905271100211] = { { 1.3, 1.8 } }, [83612611749583] = { { 12.3, 12.9 } },
	-- ATEEZ-BAD 2 (D-994, Play scan 0:13.45 glide 1.0 stud with feet 0.1, 0:54.61 1.0 with 0.2)
	[101690327843945] = { { 9.4, 10.0 } }, [86108317246080] = { { 1.5, 2.1 } },
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
	[79075546317269] = { { 5.6, 6.2 } }, -- v2 11 (1:40.4 glide, D-980)
} :: {[number]: {{number}}}
M.ChoreoAutoSteady = {
	[100400560200750] = { { 0.1, 0.7 } }, -- 백화요란 3 (D-1293, Play scan SHAKE 1:09.5)
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

-- (D-1002, user: "안무 영상 보면서 일일이 비교해서 적용") per piece: degrees the whole piece is
-- turned (ChoreoFixes `faceOffset`), measured with tools/choreo/faceoffset: in the piece's
-- clip, the frames where the member faces the camera (shoulders at their widest, nose
-- centred) against the capture's hips facing at the same moments; set where the
-- capture was off by a steady amount (median off 6°+, spread under 20°), left alone
-- where it only wobbles. Their own angled, side and back facings and turns stay.
M.ChoreoFaceOffset = {
	-- (D-1293) 백화요란 (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 15 and 23 checked on frames: front)
	[129031824166857] = 7, [74180602033079] = 9, [100400560200750] = -7, [72320524127017] = 9, [131622951291839] = 7,
	[118315209448422] = -34, [116718508120035] = 13, [126812347548541] = 10, [138514282006084] = 9, [129589571291554] = 19,
	-- (D-1064) Lemon Tang clips 19 and 23 cut again (tools/choreo/faceoffset: front frames 22 / 68, capture +12°, MAD 4 / 14)
	[128761870790634] = -12, -- Lemon Tang 19
	[110433660488854] = -12, -- Lemon Tang 23
	-- Hearts2Hearts-Lemon Tang (D-1040; practice video 9nZuuZRsDfo, clips 2..27). Not set: 4 / 16
	-- (spread 22-26°), 9 / 20 / 27 (under 12 front frames), 6 / 10 / 13 / 22 (under 6°)
	[100331751999626] = -7, -- clip 2 (52 front frames, capture +7°, spread 4°)
	[131067900968920] = -25, -- 3 (40, +25°, 11°; same member, front at 0.3-3.0 s by eye)
	[70997868814427] = 6, -- 5 (21, -6°, 16°)
	[124676885767926] = -12, -- 7 (48, +12°, 7°)
	[72328693870219] = -10, -- 8 (59, +10°, 10°)
	[74892270940916] = -16, -- 11 (17, +16°, 8°)
	[119643676032061] = -8, -- 12 (63, +8°, 8°)
	[88699205496882] = -16, -- 14 (44, +16°, 7°)
	[112515342357817] = -10, -- 17 (30, +10°, 6°)
	[125963510042067] = 11, -- 18 (17, -11°, 2°)
	[86206068065508] = 9, -- 19 (35, -9°, 6°)
	[77958598718744] = -8, -- 21 (28, +8°, 5°)
	[115787352538480] = -11, -- 23 (100, +11°, 12°)
	[97075080696819] = -8, -- 24 (20, +8°, 13°)
	[99840608563579] = -12, -- 25 (28, +12°, 12°)
	[134866535240552] = -8, -- 26 (66, +8°, 5°)
	-- aespa-Lemonade (practice video NJx2IGeS8CQ, clips 2..22; clip 1 / 17b other videos)
	[74096523961866] = -11, -- 3 (40 front frames, capture +11°, spread 15°; re-measured with the member followed)
	[123559029471758] = 13, -- 4 (39 front frames, capture -13°, spread 6°)
	[99422937735141] = -25, -- 7 (88, +25°, 18°)
	[99169381541568] = -12, -- 8 (65, +12°, 7°)
	[107439323698577] = -10, -- 13 (43, +10°, 6°)
	[118124487485279] = 6, -- 15 (107, -6°, 10°)
	[76195346888656] = -15, -- 18 (23, +15°, 9°)
	[76826604804095] = -6, -- 21 (83, +6°, 4°)
	[89070118321317] = -31, -- 22 (93, +31°, 3°)
	-- ALLDAY PROJECT-CRASH (D-1003: front moments in the video vs the capture, offset = -median)
	[103881583439894] = 11, -- 2: n17 mad11
	[108547801175160] = -15, -- 7: n35 mad11
	[119507357461993] = -9, -- 8: n35 mad17
	[124646840847010] = -8, -- 13: n37 mad12
	[109278338620404] = -12, -- 14: n19 mad6
	[83612611749583] = -12, -- 18: n12 mad6
	[128860681514235] = -22, -- 19: n29 mad16
	[140259213928051] = -17, -- 20: n36 mad1
	-- IOI-갑자기 (D-1003: front moments in the video vs the capture, offset = -median)
	[121160569929367] = -21, -- 5: n35 mad8
	[109571265510769] = -7, -- 6: n49 mad11
	[76645919052139] = 9, -- 8: n48 mad10
	[72886571801726] = -14, -- 9: n17 mad16
	[112457407974304] = 16, -- 13: n31 mad17
	[128759413181742] = -9, -- 14: n36 mad11
	[136490889932903] = -16, -- 19: n17 mad7
	[78855026719716] = -13, -- 20: n19 mad19
	[123714434236489] = -11, -- 21: n52 mad10
	-- KiiiKiii-Pop Off (D-1003: front moments in the video vs the capture, offset = -median)
	[138378577601803] = -10, -- 1: n19 mad5
	[89349893602236] = 16, -- 8: n88 mad8
	[89756644797564] = 7, -- 9: n56 mad7
	[82985939493186] = -33, -- 11: n20 mad7
	[89496459962506] = 7, -- 12: n92 mad10
	[129561476080724] = 21, -- 14: n52 mad4
	[77783806123063] = 10, -- 16: n55 mad20
	[81082889837351] = 37, -- 17: n35 mad19
	[87535109402600] = 34, -- 19: n74 mad12
	[114431038976349] = 21, -- 20: n12 mad9
	-- RESCENE-Pretty Girl (D-1003: front moments in the video vs the capture, offset = -median)
	[100082879569115] = -12, -- 1: n29 mad1
	[104009711978824] = -9, -- 2: n37 mad10
	[112928130718608] = -12, -- 6: n40 mad7
	[110044834729128] = -14, -- 13: n29 mad7
	[90231422396171] = -11, -- 20: n35 mad9
	[121645451915137] = -11, -- 21: n33 mad7
	[79626676434376] = -9, -- 22: n21 mad8
	-- RIIZE-Love 119 (D-1003: front moments in the video vs the capture, offset = -median)
	[116659270658163] = -29, -- 1: n31 mad4 (median 21, but `hold` keeps the first frame, which faces 29°: measured 8° in Play with -21)
	[101539030624816] = -12, -- 5: n22 mad10
	[140553219106220] = -6, -- 8: n16 mad6
	[119064865727357] = 15, -- 13: n16 mad12
	[131229132989104] = 8, -- 15: n22 mad15
	[128563000052459] = -7, -- 21: n21 mad6
	[128397106319046] = 8, -- 24: n17 mad8
	[132463155617727] = -19, -- 28: n36 mad12
	[98464771574081] = -11, -- 30: n26 mad2
	[117350090855113] = -18, -- 32: n25 mad8
	-- YENA-Catch Catch (D-1003: front moments in the video vs the capture, offset = -median)
	[98686361929027] = -24, -- 4: n30 mad13
	[79075546317269] = -34, -- v2 11: n38 mad17
	[73949956743570] = 14, -- v2 13: n25 mad8
	[115248452065042] = -6, -- v2 17: n23 mad5
	[124345431625014] = -13, -- v2 18: n20 mad5
	[108680095506820] = -7, -- v2 19: n40 mad3
	[127455820218376] = -20, -- v2 20: n21 mad12
	-- ATEEZ-BAD 2 (D-994; mirrored practice video, clips 1..20). Not set (measured again, 8e0a93b tool):
	-- 9 / 13 (under 12 front frames; 13 faces the camera where the capture is -16° and +26°), 6 (no front), 19 / 20 (spread 21-26°)
	[86769053357907] = -10, -- 4 (28, +10°, 12°)
	[85294537563206] = 24, -- 5 (32, -24°, 10°)
	[140073525951941] = 40, -- 7 (19, -40°, 2°)
	[92410075296555] = -9, -- 10 (21, +9°, 3°)
	[99913080692802] = 12, -- 12 (44, -12°, 7°)
	[79044145915210] = 12, -- 15 (61, -12°, 9°)
	[138182761294826] = -15, -- 16 (27, +15°, 8°)
} :: {[number]: number}
for id, degrees in pairs(M.ChoreoFaceOffset) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	fix.faceOffset = degrees
end

-- (D-1054, user: "고개 꺾임 확인해") head tilts the capture made too small: the
-- practice video's eye line against the shoulder line (tools/choreo/wrist/head_video.py,
-- only while the dancer faces the camera) against the capture's (Studio _G.headMisses,
-- the same picture angles from the animation's own poses). Where the video tilts the
-- head 15+ deg and the capture 12+ deg less the same way, two samples (0.2 s) in a row
-- or more, the head turns 0.8 of the gap more (at most 30 deg) about its own front axis,
-- easing in and out over 0.2 s. Keys are { piece seconds, x, y, z } in degrees (ChoreoFixes `bend`)
M.ChoreoHeadTilt = {
	-- (D-1293) 백화요란: head_video.py → headMisses, keys 0.09 s early; 7 left out (the centre is hidden at 1.7-3.6 s)
	[105306563598355] = { { part = "Head", keys = { { 3.71, 0, 0, 0 }, { 3.91, 0, 0, 17 }, { 4.11, 0, 0, 21 }, { 4.31, 0, 0, 16 }, { 4.51, 0, 0, 22 }, { 4.71, 0, 0, 11 }, { 4.91, 0, 0, 12 }, { 5.04, 0, 0, 0 } } } }, -- 백화요란 5
	[123368765880247] = { { part = "Head", keys = { { 0.31, 0, 0, 0 }, { 0.51, 0, 0, 10 }, { 0.71, 0, 0, 17 }, { 0.91, 0, 0, 0 } } } }, -- 백화요란 6
	[82595297491524] = { { part = "Head", keys = { { 2.71, 0, 0, 0 }, { 2.91, 0, 0, 14 }, { 3.11, 0, 0, 17 }, { 3.31, 0, 0, 27 }, { 3.51, 0, 0, 29 }, { 3.71, 0, 0, 0 } } },
		{ part = "Head", keys = { { 4.11, 0, 0, 0 }, { 4.31, 0, 0, 17 }, { 4.51, 0, 0, 21 }, { 4.71, 0, 0, 20 }, { 4.91, 0, 0, 18 }, { 5.11, 0, 0, 0 } } } }, -- 백화요란 10
	[100292773355070] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.11, 0, 0, 20 }, { 0.31, 0, 0, 14 }, { 0.51, 0, 0, 12 }, { 0.71, 0, 0, 16 }, { 0.91, 0, 0, 14 }, { 1.11, 0, 0, 13 }, { 1.31, 0, 0, 0 } } } }, -- 백화요란 11
	[98439541459421] = { { part = "Head", keys = { { 0.51, 0, 0, 0 }, { 0.71, 0, 0, 24 }, { 0.91, 0, 0, 30 }, { 1.11, 0, 0, 24 }, { 1.31, 0, 0, 0 } } } }, -- 백화요란 17
	[106836976565207] = { { part = "Head", keys = { { 4.31, 0, 0, 0 }, { 4.51, 0, 0, -11 }, { 4.71, 0, 0, -27 }, { 4.91, 0, 0, -26 }, { 5.11, 0, 0, 0 } } } }, -- 백화요란 22
	[129589571291554] = { { part = "Head", keys = { { 5.11, 0, 0, 0 }, { 5.31, 0, 0, 23 }, { 5.51, 0, 0, 22 }, { 5.71, 0, 0, 0 } } } }, -- 백화요란 23
	[123559029471758] = { { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 10 }, { 4.40, 0, 0, 12 }, { 4.60, 0, 0, 12 }, { 4.80, 0, 0, 0 } } } }, -- Lemonade 4
	[139260290712979] = { { part = "Head", keys = { { 1.60, 0, 0, 0 }, { 1.80, 0, 0, 13 }, { 2.00, 0, 0, 15 }, { 2.20, 0, 0, 0 } } } }, -- Lemonade 5
	[131526768823490] = { { part = "Head", keys = { { 0.40, 0, 0, 0 }, { 0.60, 0, 0, 30 }, { 0.80, 0, 0, 30 }, { 1.00, 0, 0, 0 } } }, { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, 13 }, { 2.80, 0, 0, 9 }, { 3.00, 0, 0, 0 } } }, { part = "Head", keys = { { 6.40, 0, 0, 0 }, { 6.60, 0, 0, -23 }, { 6.80, 0, 0, -23 }, { 7.00, 0, 0, 0 } } } }, -- Lemonade 6
	[135759185323713] = { { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, 21 }, { 2.80, 0, 0, 29 }, { 3.00, 0, 0, 0 } } }, { part = "Head", keys = { { 3.20, 0, 0, 0 }, { 3.40, 0, 0, 24 }, { 3.60, 0, 0, 25 }, { 3.80, 0, 0, 29 }, { 4.00, 0, 0, 26 }, { 4.20, 0, 0, 0 } } }, { part = "Head", keys = { { 8.00, 0, 0, 0 }, { 8.20, 0, 0, 20 }, { 8.40, 0, 0, 19 }, { 8.60, 0, 0, 24 }, { 8.80, 0, 0, 0 } } } }, -- Lemonade 10
	[83846438884132] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, 19 }, { 1.20, 0, 0, 30 }, { 1.40, 0, 0, 18 }, { 1.60, 0, 0, 11 }, { 1.80, 0, 0, 0 } } }, { part = "Head", keys = { { 4.40, 0, 0, 0 }, { 4.60, 0, 0, 29 }, { 4.80, 0, 0, 24 }, { 5.00, 0, 0, 30 }, { 5.20, 0, 0, 0 } } } }, -- Lemonade 11
	[107439323698577] = { { part = "Head", keys = { { 8.00, 0, 0, 0 }, { 8.20, 0, 0, 10 }, { 8.40, 0, 0, 10 }, { 8.60, 0, 0, 10 }, { 8.80, 0, 0, 18 }, { 9.00, 0, 0, 0 } } }, { part = "Head", keys = { { 9.20, 0, 0, 0 }, { 9.40, 0, 0, 13 }, { 9.60, 0, 0, 11 }, { 9.80, 0, 0, 16 }, { 10.00, 0, 0, 0 } } } }, -- Lemonade 13
	[138612452549442] = { { part = "Head", keys = { { 0.20, 0, 0, 0 }, { 0.40, 0, 0, 22 }, { 0.60, 0, 0, 19 }, { 0.80, 0, 0, 13 }, { 1.00, 0, 0, 14 }, { 1.20, 0, 0, 0 } } }, { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 13 }, { 2.20, 0, 0, 21 }, { 2.40, 0, 0, 15 }, { 2.60, 0, 0, 0 } } } }, -- Lemonade 14
	[118124487485279] = { { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 18 }, { 5.00, 0, 0, 13 }, { 5.20, 0, 0, 0 } } }, { part = "Head", keys = { { 11.60, 0, 0, 0 }, { 11.80, 0, 0, 25 }, { 12.00, 0, 0, 23 }, { 12.20, 0, 0, 20 }, { 12.40, 0, 0, 0 } } } }, -- Lemonade 15
	[82680550952125] = { { part = "Head", keys = { { 7.60, 0, 0, 0 }, { 7.80, 0, 0, -11 }, { 8.00, 0, 0, -16 }, { 8.20, 0, 0, 0 } } } }, -- Lemonade 16
	[132337331292488] = { { part = "Head", keys = { { 3.60, 0, 0, 0 }, { 3.80, 0, 0, -30 }, { 4.00, 0, 0, -30 }, { 4.20, 0, 0, -30 }, { 4.40, 0, 0, -13 }, { 4.60, 0, 0, 0 } } }, { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 15 }, { 5.00, 0, 0, 12 }, { 5.20, 0, 0, 0 } } } }, -- Lemonade 17
	[116980798181063] = { { part = "Head", keys = { { 6.80, 0, 0, 0 }, { 7.00, 0, 0, 14 }, { 7.20, 0, 0, 16 }, { 7.40, 0, 0, 11 }, { 7.60, 0, 0, 16 }, { 7.80, 0, 0, 10 }, { 8.00, 0, 0, 0 } } } }, -- Lemonade 19
	[89070118321317] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, -19 }, { 1.00, 0, 0, -18 }, { 1.20, 0, 0, 0 } } }, { part = "Head", keys = { { 2.00, 0, 0, 0 }, { 2.20, 0, 0, -9 }, { 2.40, 0, 0, -16 }, { 2.60, 0, 0, 0 } } } }, -- Lemonade 22
	-- (D-1263) CRASH 1 = the re-upload 92063442221105 (D-1041), measured 2026-11-10; keys 0.09 s early (animation clock lag)
	[92063442221105] = { { part = "Head", keys = { { 2.91, 0, 0, 0 }, { 3.11, 0, 0, -9 }, { 3.31, 0, 0, -11 }, { 3.51, 0, 0, -17 }, { 3.71, 0, 0, -21 }, { 3.91, 0, 0, 0 } } } }, -- CRASH 1
	[103881583439894] = { { part = "Head", keys = { { 2.20, 0, 0, 0 }, { 2.40, 0, 0, -17 }, { 2.60, 0, 0, -20 }, { 2.80, 0, 0, 0 } } } }, -- CRASH 2
	[110262357944188] = { { part = "Head", keys = { { 2.60, 0, 0, 0 }, { 2.80, 0, 0, -19 }, { 3.00, 0, 0, -20 }, { 3.20, 0, 0, -18 }, { 3.40, 0, 0, 0 } } } }, -- CRASH 3
	[108547801175160] = { { part = "Head", keys = { { 1.20, 0, 0, 0 }, { 1.40, 0, 0, -11 }, { 1.60, 0, 0, -15 }, { 1.80, 0, 0, 0 } } } }, -- CRASH 7
	[119507357461993] = { { part = "Head", keys = { { 0.00, 0, 0, -16 }, { 0.20, 0, 0, -25 }, { 0.40, 0, 0, 0 } } }, { part = "Head", keys = { { 0.40, 0, 0, 0 }, { 0.60, 0, 0, -15 }, { 0.80, 0, 0, -11 }, { 1.00, 0, 0, 0 } } }, { part = "Head", keys = { { 3.40, 0, 0, 0 }, { 3.60, 0, 0, -17 }, { 3.80, 0, 0, -19 }, { 4.00, 0, 0, -26 }, { 4.20, 0, 0, -16 }, { 4.40, 0, 0, 0 } } } }, -- CRASH 8
	[116383725353409] = { { part = "Head", keys = { { 5.20, 0, 0, 0 }, { 5.40, 0, 0, -20 }, { 5.60, 0, 0, -9 }, { 5.80, 0, 0, 0 } } } }, -- CRASH 11
	[124516959620423] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, -17 }, { 1.80, 0, 0, -17 }, { 2.00, 0, 0, 0 } } } }, -- CRASH 12
	[124646840847010] = { { part = "Head", keys = { { 0.40, 0, 0, 0 }, { 0.60, 0, 0, 12 }, { 0.80, 0, 0, 26 }, { 1.00, 0, 0, 18 }, { 1.20, 0, 0, 0 } } } }, -- CRASH 13
	[109278338620404] = { { part = "Head", keys = { { 1.20, 0, 0, 0 }, { 1.40, 0, 0, 16 }, { 1.60, 0, 0, 15 }, { 1.80, 0, 0, 0 } } } }, -- CRASH 14
	[92004530682011] = { { part = "Head", keys = { { 5.00, 0, 0, 0 }, { 5.20, 0, 0, -22 }, { 5.40, 0, 0, -30 }, { 5.60, 0, 0, 0 } } }, { part = "Head", keys = { { 8.60, 0, 0, 0 }, { 8.80, 0, 0, -18 }, { 9.00, 0, 0, -24 }, { 9.20, 0, 0, -30 }, { 9.40, 0, 0, 0 } } } }, -- CRASH 15
	[84989603326490] = { { part = "Head", keys = { { 0.00, 0, 0, -20 }, { 0.20, 0, 0, -27 }, { 0.40, 0, 0, -24 }, { 0.60, 0, 0, -22 }, { 0.80, 0, 0, -26 }, { 1.00, 0, 0, -27 }, { 1.20, 0, 0, -28 }, { 1.40, 0, 0, -27 }, { 1.60, 0, 0, -27 }, { 1.80, 0, 0, -29 }, { 2.00, 0, 0, 0 } } } }, -- CRASH 16
	[140259213928051] = { { part = "Head", keys = { { 1.60, 0, 0, 0 }, { 1.80, 0, 0, -30 }, { 2.00, 0, 0, -30 }, { 2.20, 0, 0, -26 }, { 2.40, 0, 0, -23 }, { 2.60, 0, 0, 0 } } } }, -- CRASH 20
	[91647545899849] = { { part = "Head", keys = { { 2.80, 0, 0, 0 }, { 3.00, 0, 0, 12 }, { 3.20, 0, 0, 14 }, { 3.40, 0, 0, 18 }, { 3.60, 0, 0, 30 }, { 3.80, 0, 0, 29 }, { 4.00, 0, 0, 25 }, { 4.20, 0, 0, 24 }, { 4.40, 0, 0, 0 } } }, { part = "Head", keys = { { 5.40, 0, 0, 0 }, { 5.60, 0, 0, -17 }, { 5.80, 0, 0, -18 }, { 6.00, 0, 0, -16 }, { 6.20, 0, 0, 0 } } } }, -- BAD 2 8
	[70997868814427] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, -13 }, { 1.40, 0, 0, -11 }, { 1.60, 0, 0, 0 } } }, { part = "Head", keys = { { 1.60, 0, 0, 0 }, { 1.80, 0, 0, 27 }, { 2.00, 0, 0, 15 }, { 2.20, 0, 0, 0 } } }, { part = "Head", keys = { { 4.20, 0, 0, 0 }, { 4.40, 0, 0, 23 }, { 4.60, 0, 0, 26 }, { 4.80, 0, 0, 21 }, { 5.00, 0, 0, 0 } } }, { part = "Head", keys = { { 11.40, 0, 0, 0 }, { 11.60, 0, 0, 30 }, { 11.80, 0, 0, 20 }, { 12.00, 0, 0, 0 } } } }, -- Lemon Tang 6
	[124676885767926] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, 30 }, { 1.20, 0, 0, 19 }, { 1.40, 0, 0, 0 } } } }, -- Lemon Tang 8
	[115675906513114] = { { part = "Head", keys = { { 2.80, 0, 0, 0 }, { 3.00, 0, 0, 12 }, { 3.20, 0, 0, 23 }, { 3.40, 0, 0, 0 } } } }, -- Lemon Tang 10
	[74892270940916] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.20, 0, 0, 11 }, { 0.40, 0, 0, 13 }, { 0.60, 0, 0, 0 } } } }, -- Lemon Tang 11
	[119643676032061] = { { part = "Head", keys = { { 0.20, 0, 0, 0 }, { 0.40, 0, 0, 16 }, { 0.60, 0, 0, 12 }, { 0.80, 0, 0, 24 }, { 1.00, 0, 0, 20 }, { 1.20, 0, 0, 0 } } } }, -- Lemon Tang 12
	[110925421163686] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, 25 }, { 1.40, 0, 0, 30 }, { 1.60, 0, 0, 0 } } }, { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, 30 }, { 2.80, 0, 0, 15 }, { 3.00, 0, 0, 0 } } }, { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 23 }, { 5.00, 0, 0, 17 }, { 5.20, 0, 0, 10 }, { 5.40, 0, 0, 0 } } } }, -- Lemon Tang 13
	[88699205496882] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.20, 0, 0, -15 }, { 0.40, 0, 0, -14 }, { 0.60, 0, 0, 0 } } } }, -- Lemon Tang 14
	[125963510042067] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 24 }, { 1.00, 0, 0, 29 }, { 1.20, 0, 0, 16 }, { 1.40, 0, 0, 11 }, { 1.60, 0, 0, 17 }, { 1.80, 0, 0, 26 }, { 2.00, 0, 0, 24 }, { 2.20, 0, 0, 12 }, { 2.40, 0, 0, 0 } } }, { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, 12 }, { 2.80, 0, 0, 20 }, { 2.97, 0, 0, 0 } } } }, -- Lemon Tang 18
	[86206068065508] = { { part = "Head", keys = { { 2.80, 0, 0, 0 }, { 3.00, 0, 0, 29 }, { 3.20, 0, 0, 15 }, { 3.40, 0, 0, 0 } } } }, -- Lemon Tang 19
	[83504291197334] = { { part = "Head", keys = { { 1.20, 0, 0, 0 }, { 1.40, 0, 0, 30 }, { 1.60, 0, 0, 21 }, { 1.80, 0, 0, 0 } } }, { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 19 }, { 2.20, 0, 0, 21 }, { 2.40, 0, 0, 0 } } } }, -- Lemon Tang 22
	[115787352538480] = { { part = "Head", keys = { { 9.40, 0, 0, 0 }, { 9.60, 0, 0, 10 }, { 9.80, 0, 0, 11 }, { 10.00, 0, 0, 0 } } } }, -- Lemon Tang 23
	[122848199967536] = { { part = "Head", keys = { { 7.00, 0, 0, 0 }, { 7.20, 0, 0, -8 }, { 7.40, 0, 0, -12 }, { 7.60, 0, 0, 0 } } } }, -- Lemon Tang 1 (D-1060)
	-- (D-1064) Lemon Tang clips 19-24 cut again: the same head check
	[128761870790634] = { { part = "Head", keys = { { 2.80, 0, 0, 0 }, { 3.00, 0, 0, 25 }, { 3.20, 0, 0, 14 }, { 3.40, 0, 0, 0 } } } }, -- Lemon Tang 19
	[92757942038731] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, 23 }, { 1.80, 0, 0, 30 }, { 2.00, 0, 0, 20 }, { 2.20, 0, 0, 15 }, { 2.40, 0, 0, 0 } } } }, -- Lemon Tang 22
	[110433660488854] = { { part = "Head", keys = { { 2.60, 0, 0, 0 }, { 2.80, 0, 0, 16 }, { 3.00, 0, 0, 28 }, { 3.20, 0, 0, 14 }, { 3.40, 0, 0, 0 } } }, { part = "Head", keys = { { 5.40, 0, 0, 0 }, { 5.60, 0, 0, 10 }, { 5.80, 0, 0, 11 }, { 6.00, 0, 0, 0 } } } }, -- Lemon Tang 23
	[87039448079710] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, 20 }, { 1.20, 0, 0, 20 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 6.80, 0, 0, 0 }, { 7.00, 0, 0, -9 }, { 7.20, 0, 0, -11 }, { 7.40, 0, 0, 0 } } }, { part = "Head", keys = { { 7.80, 0, 0, 0 }, { 8.00, 0, 0, -15 }, { 8.20, 0, 0, -14 }, { 8.30, 0, 0, 0 } } } }, -- Lemon Tang 24
	[109571265510769] = { { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, 24 }, { 2.80, 0, 0, 30 }, { 3.00, 0, 0, 29 }, { 3.20, 0, 0, 30 }, { 3.40, 0, 0, 24 }, { 3.60, 0, 0, 0 } } }, { part = "Head", keys = { { 6.40, 0, 0, 0 }, { 6.60, 0, 0, 15 }, { 6.80, 0, 0, 18 }, { 7.00, 0, 0, 0 } } } }, -- 갑자기 6
	[72886571801726] = { { part = "Head", keys = { { 0.00, 0, 0, 19 }, { 0.20, 0, 0, 18 }, { 0.40, 0, 0, 0 } } }, { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 19 }, { 5.00, 0, 0, 29 }, { 5.20, 0, 0, 21 }, { 5.40, 0, 0, 13 }, { 5.60, 0, 0, 0 } } } }, -- 갑자기 9
	[104001486192661] = { { part = "Head", keys = { { 7.00, 0, 0, 0 }, { 7.20, 0, 0, -13 }, { 7.40, 0, 0, -12 }, { 7.60, 0, 0, 0 } } } }, -- 갑자기 10
	[128759413181742] = { { part = "Head", keys = { { 0.40, 0, 0, 0 }, { 0.60, 0, 0, 13 }, { 0.80, 0, 0, 16 }, { 1.00, 0, 0, 25 }, { 1.20, 0, 0, 18 }, { 1.40, 0, 0, 23 }, { 1.60, 0, 0, 0 } } }, { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 8 }, { 4.40, 0, 0, 14 }, { 4.60, 0, 0, 11 }, { 4.80, 0, 0, 11 }, { 5.00, 0, 0, 9 }, { 5.20, 0, 0, 13 }, { 5.40, 0, 0, 0 } } } }, -- 갑자기 14
	[121913954340036] = { { part = "Head", keys = { { 4.40, 0, 0, 0 }, { 4.60, 0, 0, -28 }, { 4.80, 0, 0, -19 }, { 5.00, 0, 0, 0 } } } }, -- 갑자기 15
	[139341321382250] = { { part = "Head", keys = { { 5.80, 0, 0, 0 }, { 6.00, 0, 0, 29 }, { 6.20, 0, 0, 18 }, { 6.40, 0, 0, 0 } } } }, -- 갑자기 16
	[111512315445927] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, 22 }, { 1.40, 0, 0, 30 }, { 1.60, 0, 0, 0 } } } }, -- 갑자기 22
	[129257680770934] = { { part = "Head", keys = { { 7.80, 0, 0, 0 }, { 8.00, 0, 0, -22 }, { 8.20, 0, 0, -25 }, { 8.40, 0, 0, 0 } } } }, -- 갑자기 25
	[79453984815360] = { { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 26 }, { 2.20, 0, 0, 19 }, { 2.40, 0, 0, 17 }, { 2.60, 0, 0, 0 } } } }, -- Pop Off 2
	[133580607498914] = { { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 17 }, { 2.20, 0, 0, 18 }, { 2.40, 0, 0, 0 } } }, { part = "Head", keys = { { 3.60, 0, 0, 0 }, { 3.80, 0, 0, -18 }, { 4.00, 0, 0, -22 }, { 4.20, 0, 0, -21 }, { 4.40, 0, 0, 0 } } } }, -- Pop Off 3
	[137960851963972] = { { part = "Head", keys = { { 2.20, 0, 0, 0 }, { 2.40, 0, 0, 10 }, { 2.60, 0, 0, 13 }, { 2.80, 0, 0, 12 }, { 3.00, 0, 0, 10 }, { 3.20, 0, 0, 0 } } } }, -- Pop Off 4
	[82593368218356] = { { part = "Head", keys = { { 8.60, 0, 0, 0 }, { 8.80, 0, 0, 12 }, { 9.00, 0, 0, 19 }, { 9.20, 0, 0, 0 } } } }, -- Pop Off 7
	[89756644797564] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, -26 }, { 1.80, 0, 0, -20 }, { 2.00, 0, 0, 0 } } }, { part = "Head", keys = { { 4.80, 0, 0, 0 }, { 5.00, 0, 0, 15 }, { 5.20, 0, 0, 20 }, { 5.40, 0, 0, 20 }, { 5.60, 0, 0, 24 }, { 5.73, 0, 0, 0 } } } }, -- Pop Off 9
	[93822640757068] = { { part = "Head", keys = { { 0.00, 0, 0, 16 }, { 0.20, 0, 0, 16 }, { 0.40, 0, 0, 21 }, { 0.60, 0, 0, 0 } } } }, -- Pop Off 10
	[89496459962506] = { { part = "Head", keys = { { 0.00, 0, 0, 12 }, { 0.20, 0, 0, 16 }, { 0.40, 0, 0, 13 }, { 0.60, 0, 0, 14 }, { 0.80, 0, 0, 0 } } }, { part = "Head", keys = { { 3.40, 0, 0, 0 }, { 3.60, 0, 0, 12 }, { 3.80, 0, 0, 11 }, { 4.00, 0, 0, 0 } } } }, -- Pop Off 12
	[106148688158261] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 13 }, { 1.00, 0, 0, 23 }, { 1.20, 0, 0, 28 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 12 }, { 5.00, 0, 0, 20 }, { 5.20, 0, 0, 0 } } } }, -- Pop Off 13
	[129561476080724] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.20, 0, 0, 16 }, { 0.40, 0, 0, 23 }, { 0.60, 0, 0, 0 } } } }, -- Pop Off 14
	[126423548513152] = { { part = "Head", keys = { { 3.60, 0, 0, 0 }, { 3.80, 0, 0, 16 }, { 4.00, 0, 0, 21 }, { 4.20, 0, 0, 0 } } } }, -- Pop Off 15
	[77783806123063] = { { part = "Head", keys = { { 2.60, 0, 0, 0 }, { 2.80, 0, 0, -19 }, { 3.00, 0, 0, -13 }, { 3.20, 0, 0, 0 } } }, { part = "Head", keys = { { 3.00, 0, 0, 0 }, { 3.20, 0, 0, 22 }, { 3.40, 0, 0, 28 }, { 3.60, 0, 0, 23 }, { 3.80, 0, 0, 18 }, { 4.00, 0, 0, 0 } } } }, -- Pop Off 16
	[105511127677230] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 13 }, { 1.00, 0, 0, 12 }, { 1.20, 0, 0, 21 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 1.60, 0, 0, 0 }, { 1.80, 0, 0, 13 }, { 2.00, 0, 0, 18 }, { 2.20, 0, 0, 0 } } }, { part = "Head", keys = { { 5.60, 0, 0, 0 }, { 5.80, 0, 0, -18 }, { 6.00, 0, 0, -19 }, { 6.20, 0, 0, -14 }, { 6.40, 0, 0, 0 } } } }, -- Pop Off 18
	[87535109402600] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, -12 }, { 1.20, 0, 0, -17 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 8.20, 0, 0, 0 }, { 8.40, 0, 0, -21 }, { 8.60, 0, 0, -16 }, { 8.80, 0, 0, 0 } } } }, -- Pop Off 19
	[77209641618863] = { { part = "Head", keys = { { 0.40, 0, 0, 0 }, { 0.60, 0, 0, 15 }, { 0.80, 0, 0, 22 }, { 1.00, 0, 0, 18 }, { 1.20, 0, 0, 0 } } } }, -- Pop Off 21
	[119100545362264] = { { part = "Head", keys = { { 4.40, 0, 0, 0 }, { 4.60, 0, 0, 15 }, { 4.80, 0, 0, 17 }, { 5.00, 0, 0, 16 }, { 5.20, 0, 0, 0 } } }, { part = "Head", keys = { { 5.00, 0, 0, 0 }, { 5.20, 0, 0, -10 }, { 5.40, 0, 0, -15 }, { 5.60, 0, 0, 0 } } } }, -- Pretty Girl 9
	[74902277201730] = { { part = "Head", keys = { { 3.20, 0, 0, 0 }, { 3.40, 0, 0, 10 }, { 3.60, 0, 0, 10 }, { 3.80, 0, 0, 0 } } } }, -- Pretty Girl 12
	[126827294531161] = { { part = "Head", keys = { { 1.20, 0, 0, 0 }, { 1.40, 0, 0, 12 }, { 1.60, 0, 0, 12 }, { 1.80, 0, 0, 10 }, { 2.00, 0, 0, 0 } } }, { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 15 }, { 4.40, 0, 0, 15 }, { 4.60, 0, 0, 17 }, { 4.80, 0, 0, 0 } } } }, -- Pretty Girl 14
	[81645905885514] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, -10 }, { 1.80, 0, 0, -12 }, { 2.00, 0, 0, 0 } } } }, -- Pretty Girl 23
	[84166534427168] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 15 }, { 1.00, 0, 0, 18 }, { 1.20, 0, 0, 0 } } } }, -- Pretty Girl 25
	[117439090388503] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 17 }, { 1.00, 0, 0, 14 }, { 1.20, 0, 0, 0 } } }, { part = "Head", keys = { { 9.40, 0, 0, 0 }, { 9.60, 0, 0, 17 }, { 9.80, 0, 0, 26 }, { 10.00, 0, 0, 24 }, { 10.20, 0, 0, 0 } } } }, -- Pretty Girl 26
	[84913058689124] = { { part = "Head", keys = { { 8.60, 0, 0, 0 }, { 8.80, 0, 0, 17 }, { 9.00, 0, 0, 22 }, { 9.20, 0, 0, 0 } } } }, -- Love 119 4
	[101539030624816] = { { part = "Head", keys = { { 6.40, 0, 0, 0 }, { 6.60, 0, 0, 16 }, { 6.80, 0, 0, 10 }, { 7.00, 0, 0, 0 } } } }, -- Love 119 5
	[107740496143451] = { { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, -22 }, { 2.20, 0, 0, -15 }, { 2.40, 0, 0, -10 }, { 2.60, 0, 0, -19 }, { 2.80, 0, 0, 0 } } } }, -- Love 119 7
	[79064359810628] = { { part = "Head", keys = { { 3.40, 0, 0, 0 }, { 3.60, 0, 0, -15 }, { 3.80, 0, 0, -13 }, { 4.00, 0, 0, 0 } } } }, -- Love 119 11
	[103134109095683] = { { part = "Head", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 16 }, { 1.00, 0, 0, 26 }, { 1.20, 0, 0, 0 } } } }, -- Love 119 16
	[112123988214223] = { { part = "Head", keys = { { 0.20, 0, 0, 0 }, { 0.40, 0, 0, 9 }, { 0.60, 0, 0, 13 }, { 0.80, 0, 0, 0 } } } }, -- Love 119 20
	[132463155617727] = { { part = "Head", keys = { { 3.60, 0, 0, 0 }, { 3.80, 0, 0, 12 }, { 4.00, 0, 0, 11 }, { 4.20, 0, 0, 0 } } } }, -- Love 119 28
	-- Catch Catch is danced mirrored: the turn is the other way round (z negated)
	[74567972410299] = { { part = "Head", keys = { { 3.00, 0, 0, 0 }, { 3.20, 0, 0, 11 }, { 3.40, 0, 0, 13 }, { 3.60, 0, 0, 16 }, { 3.80, 0, 0, 22 }, { 4.00, 0, 0, 0 } } } }, -- Catch Catch 7
	[79075546317269] = { { part = "Head", keys = { { 10.20, 0, 0, 0 }, { 10.40, 0, 0, -18 }, { 10.60, 0, 0, -12 }, { 10.80, 0, 0, 0 } } } }, -- Catch Catch v2 11
	-- (D-1056) ANIMAL, 체포하겠어, Genie, LOVE ATTACK, I SPY, REDRED: the mirrored practice clips in D:\Roblox\오후\영상
	[136955392986245] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, 30 }, { 1.20, 0, 0, 26 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 1.60, 0, 0, 0 }, { 1.80, 0, 0, -23 }, { 2.00, 0, 0, -14 }, { 2.20, 0, 0, 0 } } } }, -- ANIMAL 10
	[100329215645751] = { { part = "Head", keys = { { 3.20, 0, 0, 0 }, { 3.40, 0, 0, 16 }, { 3.60, 0, 0, 15 }, { 3.80, 0, 0, 0 } } } }, -- ANIMAL 11
	[104678910693394] = { { part = "Head", keys = { { 8.20, 0, 0, 0 }, { 8.40, 0, 0, 17 }, { 8.60, 0, 0, 21 }, { 8.80, 0, 0, 30 }, { 9.00, 0, 0, 10 }, { 9.20, 0, 0, 0 } } } }, -- ANIMAL 14
	[82506858822635] = { { part = "Head", keys = { { 9.00, 0, 0, 0 }, { 9.20, 0, 0, 19 }, { 9.40, 0, 0, 15 }, { 9.60, 0, 0, 17 }, { 9.80, 0, 0, 21 }, { 10.00, 0, 0, 14 }, { 10.20, 0, 0, 0 } } }, { part = "Head", keys = { { 12.20, 0, 0, 0 }, { 12.40, 0, 0, 19 }, { 12.60, 0, 0, 19 }, { 12.80, 0, 0, 16 }, { 13.00, 0, 0, 20 }, { 13.20, 0, 0, 20 }, { 13.40, 0, 0, 0 } } } }, -- ANIMAL 15
	[91831034598236] = { { part = "Head", keys = { { 0.00, 0, 0, -21 }, { 0.20, 0, 0, -14 }, { 0.40, 0, 0, -20 }, { 0.60, 0, 0, -24 }, { 0.80, 0, 0, 0 } } } }, -- ANIMAL 16
	[123997379474433] = { { part = "Head", keys = { { 3.60, 0, 0, 0 }, { 3.80, 0, 0, 19 }, { 4.00, 0, 0, 16 }, { 4.20, 0, 0, 0 } } } }, -- ANIMAL 17
	[72908007597304] = { { part = "Head", keys = { { 0.20, 0, 0, 0 }, { 0.40, 0, 0, 16 }, { 0.60, 0, 0, 20 }, { 0.80, 0, 0, 18 }, { 1.00, 0, 0, 17 }, { 1.20, 0, 0, 0 } } } }, -- ANIMAL 25
	[110040253056586] = { { part = "Head", keys = { { 4.80, 0, 0, 0 }, { 5.00, 0, 0, 12 }, { 5.20, 0, 0, 14 }, { 5.40, 0, 0, 14 }, { 5.60, 0, 0, 12 }, { 5.80, 0, 0, 13 }, { 6.00, 0, 0, 11 }, { 6.20, 0, 0, 10 }, { 6.40, 0, 0, 12 }, { 6.60, 0, 0, 11 }, { 6.80, 0, 0, 0 } } }, { part = "Head", keys = { { 10.80, 0, 0, 0 }, { 11.00, 0, 0, -11 }, { 11.20, 0, 0, -20 }, { 11.40, 0, 0, -12 }, { 11.60, 0, 0, -10 }, { 11.80, 0, 0, 0 } } } }, -- 체포하겠어 1
	[116782676046427] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, -10 }, { 1.20, 0, 0, -10 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 5.00, 0, 0, 0 }, { 5.20, 0, 0, 15 }, { 5.40, 0, 0, 12 }, { 5.60, 0, 0, 0 } } }, { part = "Head", keys = { { 6.20, 0, 0, 0 }, { 6.40, 0, 0, 14 }, { 6.60, 0, 0, 11 }, { 6.80, 0, 0, 0 } } } }, -- 체포하겠어 2
	[91788521477193] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, 23 }, { 1.40, 0, 0, 15 }, { 1.60, 0, 0, 0 } } }, { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, -14 }, { 1.80, 0, 0, -12 }, { 2.00, 0, 0, 0 } } }, { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 15 }, { 2.20, 0, 0, 13 }, { 2.40, 0, 0, 0 } } }, { part = "Head", keys = { { 2.20, 0, 0, 0 }, { 2.40, 0, 0, -14 }, { 2.60, 0, 0, -14 }, { 2.80, 0, 0, 0 } } } }, -- 체포하겠어 3
	[130744405360835] = { { part = "Head", keys = { { 2.00, 0, 0, 0 }, { 2.20, 0, 0, 27 }, { 2.40, 0, 0, 20 }, { 2.60, 0, 0, 13 }, { 2.80, 0, 0, 0 } } }, { part = "Head", keys = { { 3.20, 0, 0, 0 }, { 3.40, 0, 0, 12 }, { 3.60, 0, 0, 8 }, { 3.80, 0, 0, 0 } } } }, -- 체포하겠어 4
	[128174978668663] = { { part = "Head", keys = { { 4.80, 0, 0, 0 }, { 5.00, 0, 0, -17 }, { 5.20, 0, 0, -20 }, { 5.40, 0, 0, -16 }, { 5.60, 0, 0, 0 } } } }, -- 체포하겠어 6
	[76359264534217] = { { part = "Head", keys = { { 6.60, 0, 0, 0 }, { 6.80, 0, 0, 14 }, { 7.00, 0, 0, 10 }, { 7.20, 0, 0, 16 }, { 7.40, 0, 0, 0 } } }, { part = "Head", keys = { { 7.40, 0, 0, 0 }, { 7.60, 0, 0, 21 }, { 7.80, 0, 0, 14 }, { 8.00, 0, 0, 17 }, { 8.20, 0, 0, 0 } } } }, -- 체포하겠어 8
	[99715197125931] = { { part = "Head", keys = { { 1.20, 0, 0, 0 }, { 1.40, 0, 0, 11 }, { 1.60, 0, 0, 19 }, { 1.80, 0, 0, 0 } } }, { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 13 }, { 4.40, 0, 0, 11 }, { 4.60, 0, 0, 0 } } }, { part = "Head", keys = { { 8.60, 0, 0, 0 }, { 8.80, 0, 0, -14 }, { 9.00, 0, 0, -17 }, { 9.20, 0, 0, -19 }, { 9.40, 0, 0, -19 }, { 9.60, 0, 0, -13 }, { 9.80, 0, 0, 0 } } }, { part = "Head", keys = { { 12.20, 0, 0, 0 }, { 12.40, 0, 0, 20 }, { 12.60, 0, 0, 15 }, { 12.80, 0, 0, 18 }, { 13.00, 0, 0, 15 }, { 13.20, 0, 0, 0 } } } }, -- 체포하겠어 9
	[92743762405771] = { { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 12 }, { 4.40, 0, 0, 12 }, { 4.60, 0, 0, 13 }, { 4.80, 0, 0, 15 }, { 5.00, 0, 0, 16 }, { 5.20, 0, 0, 0 } } } }, -- 체포하겠어 10
	[108969470552658] = { { part = "Head", keys = { { 3.80, 0, 0, 0 }, { 4.00, 0, 0, 13 }, { 4.20, 0, 0, 8 }, { 4.40, 0, 0, 0 } } } }, -- 체포하겠어 11
	[119318712525281] = { { part = "Head", keys = { { 3.40, 0, 0, 0 }, { 3.60, 0, 0, 12 }, { 3.80, 0, 0, 16 }, { 4.00, 0, 0, 0 } } } }, -- 체포하겠어 15
	[113529281081668] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, 19 }, { 1.80, 0, 0, 22 }, { 2.00, 0, 0, 0 } } } }, -- 체포하겠어 16
	[138780635090818] = { { part = "Head", keys = { { 9.60, 0, 0, 0 }, { 9.80, 0, 0, 12 }, { 10.00, 0, 0, 12 }, { 10.20, 0, 0, 0 } } } }, -- 체포하겠어 17
	[134859541553614] = { { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 15 }, { 2.20, 0, 0, 17 }, { 2.40, 0, 0, 17 }, { 2.60, 0, 0, 15 }, { 2.80, 0, 0, 20 }, { 3.00, 0, 0, 15 }, { 3.20, 0, 0, 19 }, { 3.40, 0, 0, 0 } } }, { part = "Head", keys = { { 7.40, 0, 0, 0 }, { 7.60, 0, 0, 24 }, { 7.80, 0, 0, 19 }, { 8.00, 0, 0, 0 } } }, { part = "Head", keys = { { 8.40, 0, 0, 0 }, { 8.60, 0, 0, 17 }, { 8.80, 0, 0, 14 }, { 9.00, 0, 0, 0 } } }, { part = "Head", keys = { { 9.20, 0, 0, 0 }, { 9.40, 0, 0, 16 }, { 9.60, 0, 0, 15 }, { 9.80, 0, 0, 0 } } } }, -- 체포하겠어 18
	[127453915676688] = { { part = "Head", keys = { { 6.80, 0, 0, 0 }, { 7.00, 0, 0, 18 }, { 7.20, 0, 0, 19 }, { 7.40, 0, 0, 19 }, { 7.60, 0, 0, 18 }, { 7.80, 0, 0, 18 }, { 8.00, 0, 0, 21 }, { 8.20, 0, 0, 0 } } }, { part = "Head", keys = { { 8.40, 0, 0, 0 }, { 8.60, 0, 0, 13 }, { 8.80, 0, 0, 20 }, { 9.00, 0, 0, 30 }, { 9.20, 0, 0, 30 }, { 9.40, 0, 0, 0 } } } }, -- 체포하겠어 19
	[127323208506008] = { { part = "Head", keys = { { 5.20, 0, 0, 0 }, { 5.40, 0, 0, 10 }, { 5.60, 0, 0, 16 }, { 5.80, 0, 0, 0 } } } }, -- Genie 3
	[121572726416294] = { { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, -16 }, { 2.80, 0, 0, -12 }, { 3.00, 0, 0, 0 } } } }, -- Genie 4
	[101676644495491] = { { part = "Head", keys = { { 10.40, 0, 0, 0 }, { 10.60, 0, 0, 25 }, { 10.80, 0, 0, 14 }, { 11.00, 0, 0, 0 } } }, { part = "Head", keys = { { 11.20, 0, 0, 0 }, { 11.40, 0, 0, -21 }, { 11.60, 0, 0, -20 }, { 11.80, 0, 0, 0 } } } }, -- Genie 5
	[105545108302127] = { { part = "Head", keys = { { 3.00, 0, 0, 0 }, { 3.20, 0, 0, 14 }, { 3.40, 0, 0, 16 }, { 3.60, 0, 0, 0 } } } }, -- Genie 6
	[107809363798601] = { { part = "Head", keys = { { 5.40, 0, 0, 0 }, { 5.60, 0, 0, 10 }, { 5.80, 0, 0, 11 }, { 6.00, 0, 0, 0 } } } }, -- Genie 7
	[108803469428764] = { { part = "Head", keys = { { 4.40, 0, 0, 0 }, { 4.60, 0, 0, 28 }, { 4.80, 0, 0, 26 }, { 5.00, 0, 0, 17 }, { 5.20, 0, 0, 0 } } }, { part = "Head", keys = { { 5.20, 0, 0, 0 }, { 5.40, 0, 0, 26 }, { 5.60, 0, 0, 28 }, { 5.80, 0, 0, 0 } } } }, -- Genie 9
	[76060752564499] = { { part = "Head", keys = { { 7.60, 0, 0, 0 }, { 7.80, 0, 0, 16 }, { 8.00, 0, 0, 23 }, { 8.20, 0, 0, 19 }, { 8.40, 0, 0, 0 } } } }, -- Genie 10
	[136331779515321] = { { part = "Head", keys = { { 3.80, 0, 0, 0 }, { 4.00, 0, 0, 20 }, { 4.20, 0, 0, 17 }, { 4.40, 0, 0, 0 } } } }, -- Genie 11
	[94271336995595] = { { part = "Head", keys = { { 2.60, 0, 0, 0 }, { 2.80, 0, 0, 14 }, { 3.00, 0, 0, 19 }, { 3.20, 0, 0, 17 }, { 3.40, 0, 0, 22 }, { 3.60, 0, 0, 0 } } } }, -- Genie 12
	[137553505478362] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, 17 }, { 1.80, 0, 0, 18 }, { 2.00, 0, 0, 0 } } } }, -- Genie 15
	[124091598492660] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.20, 0, 0, 9 }, { 0.40, 0, 0, 14 }, { 0.60, 0, 0, 0 } } } }, -- Genie 18
	[98754942494305] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.20, 0, 0, 12 }, { 0.40, 0, 0, 12 }, { 0.60, 0, 0, 0 } } } }, -- Genie 19
	[125902811896005] = { { part = "Head", keys = { { 2.60, 0, 0, 0 }, { 2.80, 0, 0, 12 }, { 3.00, 0, 0, 20 }, { 3.20, 0, 0, 21 }, { 3.40, 0, 0, 18 }, { 3.60, 0, 0, 0 } } }, { part = "Head", keys = { { 7.40, 0, 0, 0 }, { 7.60, 0, 0, 30 }, { 7.80, 0, 0, 30 }, { 8.00, 0, 0, 29 }, { 8.20, 0, 0, 0 } } } }, -- Genie 22
	[118832898913501] = { { part = "Head", keys = { { 1.20, 0, 0, 0 }, { 1.40, 0, 0, 9 }, { 1.60, 0, 0, 12 }, { 1.80, 0, 0, 0 } } } }, -- LOVE ATTACK 8
	[90182725361176] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, -19 }, { 1.80, 0, 0, -19 }, { 2.00, 0, 0, -11 }, { 2.13, 0, 0, 0 } } } }, -- LOVE ATTACK 9
	[108475995123642] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, -13 }, { 1.40, 0, 0, -10 }, { 1.60, 0, 0, 0 } } } }, -- LOVE ATTACK 11
	[88670191702155] = { { part = "Head", keys = { { 6.00, 0, 0, 0 }, { 6.20, 0, 0, 25 }, { 6.40, 0, 0, 15 }, { 6.60, 0, 0, 22 }, { 6.80, 0, 0, 0 } } } }, -- LOVE ATTACK 13
	[76304830605030] = { { part = "Head", keys = { { 6.60, 0, 0, 0 }, { 6.80, 0, 0, 18 }, { 7.00, 0, 0, 30 }, { 7.20, 0, 0, 30 }, { 7.40, 0, 0, 0 } } } }, -- LOVE ATTACK 20
	[115786464203055] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, -11 }, { 1.20, 0, 0, -10 }, { 1.40, 0, 0, 0 } } }, { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 19 }, { 5.00, 0, 0, 13 }, { 5.20, 0, 0, 0 } } } }, -- LOVE ATTACK 21
	[72915658378938] = { { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, 22 }, { 2.20, 0, 0, 20 }, { 2.40, 0, 0, 0 } } }, { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 17 }, { 4.40, 0, 0, 27 }, { 4.60, 0, 0, 26 }, { 4.80, 0, 0, 17 }, { 5.00, 0, 0, 0 } } } }, -- LOVE ATTACK 24
	[83427493012714] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, -16 }, { 1.20, 0, 0, -17 }, { 1.40, 0, 0, 0 } } } }, -- LOVE ATTACK 26
	[78989896538167] = { { part = "Head", keys = { { 5.60, 0, 0, 0 }, { 5.80, 0, 0, 11 }, { 6.00, 0, 0, 11 }, { 6.20, 0, 0, 0 } } } }, -- LOVE ATTACK 27
	[107073213896668] = { { part = "Head", keys = { { 1.40, 0, 0, 0 }, { 1.60, 0, 0, 30 }, { 1.80, 0, 0, 25 }, { 2.00, 0, 0, 0 } } } }, -- I SPY 2
	[114940315235555] = { { part = "Head", keys = { { 2.40, 0, 0, 0 }, { 2.60, 0, 0, -12 }, { 2.80, 0, 0, -15 }, { 3.00, 0, 0, -19 }, { 3.20, 0, 0, -17 }, { 3.40, 0, 0, 0 } } } }, -- I SPY 6
	[130779565006070] = { { part = "Head", keys = { { 0.20, 0, 0, 0 }, { 0.40, 0, 0, 14 }, { 0.60, 0, 0, 17 }, { 0.80, 0, 0, 0 } } }, { part = "Head", keys = { { 6.20, 0, 0, 0 }, { 6.40, 0, 0, 16 }, { 6.60, 0, 0, 16 }, { 6.80, 0, 0, 18 }, { 6.93, 0, 0, 0 } } } }, -- I SPY 7
	[98654918637507] = { { part = "Head", keys = { { 0.00, 0, 0, 17 }, { 0.20, 0, 0, 15 }, { 0.40, 0, 0, 16 }, { 0.60, 0, 0, 0 } } } }, -- I SPY 8
	[71548910990490] = { { part = "Head", keys = { { 2.20, 0, 0, 0 }, { 2.40, 0, 0, -19 }, { 2.60, 0, 0, -22 }, { 2.80, 0, 0, -15 }, { 3.00, 0, 0, 0 } } } }, -- I SPY 12
	[80718941616155] = { { part = "Head", keys = { { 1.80, 0, 0, 0 }, { 2.00, 0, 0, -16 }, { 2.20, 0, 0, -13 }, { 2.40, 0, 0, -10 }, { 2.60, 0, 0, -14 }, { 2.80, 0, 0, 0 } } } }, -- I SPY 17
	[133446362959561] = { { part = "Head", keys = { { 2.60, 0, 0, 0 }, { 2.80, 0, 0, -30 }, { 3.00, 0, 0, -25 }, { 3.20, 0, 0, -20 }, { 3.40, 0, 0, 0 } } } }, -- I SPY 21
	[84123931984762] = { { part = "Head", keys = { { 3.80, 0, 0, 0 }, { 4.00, 0, 0, 13 }, { 4.20, 0, 0, 13 }, { 4.40, 0, 0, 17 }, { 4.60, 0, 0, 11 }, { 4.80, 0, 0, 0 } } } }, -- I SPY 22
	[74058508632786] = { { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 13 }, { 4.40, 0, 0, 19 }, { 4.60, 0, 0, 19 }, { 4.80, 0, 0, 21 }, { 5.00, 0, 0, 0 } } } }, -- I SPY 23
	[80845800354299] = { { part = "Head", keys = { { 4.20, 0, 0, 0 }, { 4.40, 0, 0, 14 }, { 4.60, 0, 0, 19 }, { 4.80, 0, 0, 0 } } }, { part = "Head", keys = { { 7.00, 0, 0, 0 }, { 7.20, 0, 0, 30 }, { 7.40, 0, 0, 12 }, { 7.60, 0, 0, 0 } } } }, -- I SPY 29
	[101510288461879] = { { part = "Head", keys = { { 4.40, 0, 0, 0 }, { 4.60, 0, 0, 20 }, { 4.80, 0, 0, 17 }, { 5.00, 0, 0, 17 }, { 5.20, 0, 0, 0 } } } }, -- REDRED 6
	[76336157312311] = { { part = "Head", keys = { { 2.80, 0, 0, 0 }, { 3.00, 0, 0, 13 }, { 3.20, 0, 0, 14 }, { 3.40, 0, 0, 11 }, { 3.60, 0, 0, 16 }, { 3.80, 0, 0, 0 } } } }, -- REDRED 7
	[116978800280311] = { { part = "Head", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, 9 }, { 1.20, 0, 0, 13 }, { 1.40, 0, 0, 17 }, { 1.60, 0, 0, 0 } } } }, -- REDRED 10
	[89337681817413] = { { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 10 }, { 4.40, 0, 0, 13 }, { 4.60, 0, 0, 12 }, { 4.80, 0, 0, 10 }, { 5.00, 0, 0, 10 }, { 5.20, 0, 0, 0 } } } }, -- REDRED 14
	[114253650075143] = { { part = "Head", keys = { { 4.80, 0, 0, 0 }, { 5.00, 0, 0, 11 }, { 5.20, 0, 0, 14 }, { 5.40, 0, 0, 13 }, { 5.60, 0, 0, 11 }, { 5.80, 0, 0, 11 }, { 6.00, 0, 0, 10 }, { 6.20, 0, 0, 10 }, { 6.40, 0, 0, 0 } } } }, -- REDRED 24
} :: {[number]: any}
-- (D-1056, user: "손목도 하고 고개도 해 둘 다 했어야지 다시 해") wrist bends the capture made
-- too small, the same way: the hand (MediaPipe hand landmarker) against the forearm in the
-- practice video (tools/choreo/wrist/hand_video.py: the hand 15+ px and 0.3+ of the forearm,
-- 2+ frames agreeing) against the capture's (head_misses.lua _G.wristMisses). Where the
-- video bends 25+ deg and the capture 20+ deg less the same way, 2+ samples (0.2 s) in a row,
-- the hand turns about whichever of its own x / z axes moves the picture bend most, 0.8 of
-- the gap (at most 40 deg), easing in and out over 0.2 s. Catch Catch: the other hand, z negated
M.ChoreoWristBend = {
	-- (D-1293, user 2026-11-11: "원본 동영상과 비교하면서 고개와 손목 움직임 세세한 부분까지 적용할 것") 백화요란: hand_moves.py on
	-- all 22 clips (MediaPipe hands, 0.05 s) → wristMisses; keys 0.09 s early; capture wrist + bend kept ≤ 72° (6 left hand
	-- dropped: the capture already bends 69-76°; 14 left hand at 2.8 s cut to 20); left out where the centre is hidden (6 at 9 s,
	-- 7 at 3 s) or where the bend adds nothing (13 left hand, 23); Play check (hand vs forearm on screen, D-1263): 2 left hand,
	-- 13 right hand at 0 s, 14 left hand at 0.2 s and 14 right hand went the wrong way or could not be read, so they are out
	[100400560200750] = { { part = "LeftHand", keys = { { 7.71, 0, 0, 0 }, { 7.91, 0, 0, 40 }, { 8.11, 0, 0, 0 } } } }, -- 백화요란 3
	[123368765880247] = { { part = "RightHand", keys = { { 6.31, 0, 0, 0 }, { 6.51, 33, 0, 0 }, { 6.71, 31, 0, 0 }, { 6.91, 37, 0, 0 }, { 7.11, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 7.31, 0, 0, 0 }, { 7.51, -32, 0, 0 }, { 7.71, -32, 0, 0 }, { 7.91, -32, 0, 0 }, { 8.11, -32, 0, 0 }, { 8.31, -32, 0, 0 }, { 8.51, 0, 0, 0 } } } }, -- 백화요란 6
	[126526542148646] = { { part = "RightHand", keys = { { 0.71, 0, 0, 0 }, { 0.91, 20, 0, 0 }, { 1.11, 0, 0, 0 } } } }, -- 백화요란 8
	[82595297491524] = { { part = "LeftHand", keys = { { 4.11, 0, 0, 0 }, { 4.31, 0, 0, 39 }, { 4.51, 0, 0, 34 }, { 4.71, 0, 0, 0 } } } }, -- 백화요란 10
	[72320524127017] = { { part = "LeftHand", keys = { { 7.71, 0, 0, 0 }, { 7.91, 29, 0, 0 }, { 8.11, 13, 0, 0 }, { 8.31, 23, 0, 0 }, { 8.51, 26, 0, 0 }, { 8.71, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 7.51, 0, 0, 0 }, { 7.71, 23, 0, 0 }, { 7.91, 27, 0, 0 }, { 8.11, 30, 0, 0 }, { 8.31, 33, 0, 0 }, { 8.51, 38, 0, 0 }, { 8.71, 28, 0, 0 }, { 8.91, 0, 0, 0 } } } }, -- 백화요란 12
	[131622951291839] = { { part = "RightHand", keys = { { 1.31, 0, 0, 0 }, { 1.51, 0, 0, 22 }, { 1.71, 0, 0, 24 }, { 1.91, 0, 0, 0 } } } }, -- 백화요란 13
	[82878605609824] = { { part = "LeftHand", keys = { { 0.91, 0, 0, 0 }, { 1.11, 0, 0, 37 }, { 1.31, 0, 0, 40 }, { 1.51, 0, 0, 40 }, { 1.71, 0, 0, 0 } } },
		{ part = "LeftHand", keys = { { 2.51, 0, 0, 0 }, { 2.71, 20, 0, 0 }, { 2.91, 16, 0, 0 }, { 3.11, 0, 0, 0 } } } }, -- 백화요란 14
	[116718508120035] = { { part = "RightHand", keys = { { 0.51, 0, 0, 0 }, { 0.71, -40, 0, 0 }, { 0.91, -40, 0, 0 }, { 1.11, -40, 0, 0 }, { 1.31, 0, 0, 0 } } } }, -- 백화요란 16
	[98439541459421] = { { part = "LeftHand", keys = { { 1.91, 0, 0, 0 }, { 2.11, 0, 0, 35 }, { 2.31, 0, 0, 40 }, { 2.51, 0, 0, 0 } } } }, -- 백화요란 17
	[138514282006084] = { { part = "LeftHand", keys = { { 5.31, 0, 0, 0 }, { 5.51, -26, 0, 0 }, { 5.71, -40, 0, 0 }, { 5.91, 0, 0, 0 } } },
		{ part = "LeftHand", keys = { { 7.51, 0, 0, 0 }, { 7.71, 0, 0, 40 }, { 7.91, 0, 0, 32 }, { 8.11, 0, 0, 0 } } } }, -- 백화요란 19
	[106836976565207] = { { part = "RightHand", keys = { { 5.31, 0, 0, 0 }, { 5.51, -39, 0, 0 }, { 5.71, -34, 0, 0 }, { 5.91, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 6.71, 0, 0, 0 }, { 6.91, -20, 0, 0 }, { 7.11, -40, 0, 0 }, { 7.31, 0, 0, 0 } } } }, -- 백화요란 22
	[123559029471758] = { { part = "RightHand", keys = { { 4.80, 0, 0, 0 }, { 5.00, 24, 0, 0 }, { 5.20, 25, 0, 0 }, { 5.40, 0, 0, 0 } } } }, -- Lemonade 4
	[135759185323713] = { { part = "LeftHand", keys = { { 1.20, 0, 0, 0 }, { 1.40, 29, 0, 0 }, { 1.60, 40, 0, 0 }, { 1.80, 37, 0, 0 }, { 2.00, 0, 0, 0 } } } }, -- Lemonade 10
	[138612452549442] = { { part = "RightHand", keys = { { 2.20, 0, 0, 0 }, { 2.40, 32, 0, 0 }, { 2.60, 34, 0, 0 }, { 2.80, 0, 0, 0 } } } }, -- Lemonade 14
	[118124487485279] = { { part = "RightHand", keys = { { 3.20, 0, 0, 0 }, { 3.40, 11, 0, 0 }, { 3.60, 9, 0, 0 }, { 3.80, 0, 0, 0 } } } }, -- Lemonade 15
	[101690327843945] = { { part = "LeftHand", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, 18 }, { 1.40, 0, 0, 18 }, { 1.60, 0, 0, 0 } } }, { part = "LeftHand", keys = { { 9.80, 0, 0, 0 }, { 10.00, 0, 0, 28 }, { 10.20, 0, 0, 32 }, { 10.40, 0, 0, 0 } } }, { part = "RightHand", keys = { { 9.80, 0, 0, 0 }, { 10.00, 0, 0, -40 }, { 10.20, 0, 0, -37 }, { 10.40, 0, 0, 0 } } } }, -- BAD 2 2
	[106954590912232] = { { part = "LeftHand", keys = { { 5.00, 0, 0, 0 }, { 5.20, 34, 0, 0 }, { 5.40, 40, 0, 0 }, { 5.60, 0, 0, 0 } } }, { part = "RightHand", keys = { { 5.40, 0, 0, 0 }, { 5.60, 0, 0, -40 }, { 5.80, 0, 0, 0 } } } }, -- BAD 2 3
	[92410075296555] = { { part = "LeftHand", keys = { { 8.20, 0, 0, 0 }, { 8.40, 40, 0, 0 }, { 8.60, 40, 0, 0 }, { 8.80, 0, 0, 0 } } }, { part = "RightHand", keys = { { 1.20, 0, 0, 0 }, { 1.40, -16, 0, 0 }, { 1.60, -27, 0, 0 }, { 1.80, -40, 0, 0 }, { 2.00, 0, 0, 0 } } }, { part = "RightHand", keys = { { 3.00, 0, 0, 0 }, { 3.20, -25, 0, 0 }, { 3.40, -18, 0, 0 }, { 3.60, 0, 0, 0 } } }, { part = "RightHand", keys = { { 4.20, 0, 0, 0 }, { 4.40, 40, 0, 0 }, { 4.60, 40, 0, 0 }, { 4.80, 33, 0, 0 }, { 5.00, 0, 0, 0 } } } }, -- BAD 2 10
	[114907255207310] = { { part = "LeftHand", keys = { { 4.80, 0, 0, 0 }, { 5.00, 40, 0, 0 }, { 5.20, 35, 0, 0 }, { 5.40, 40, 0, 0 }, { 5.60, 0, 0, 0 } } } }, -- BAD 2 14
	[95469533767642] = { { part = "LeftHand", keys = { { 5.60, 0, 0, 0 }, { 5.80, 0, 0, -18 }, { 6.00, 0, 0, -40 }, { 6.20, 0, 0, 0 } } } }, -- BAD 2 19
	[100331751999626] = { { part = "RightHand", keys = { { 2.00, 0, 0, 0 }, { 2.20, 0, 0, -38 }, { 2.40, 0, 0, -37 }, { 2.60, 0, 0, -40 }, { 2.80, 0, 0, 0 } } } }, -- Lemon Tang 2
	[124676885767926] = { { part = "RightHand", keys = { { 5.20, 0, 0, 0 }, { 5.40, 40, 0, 0 }, { 5.60, 31, 0, 0 }, { 5.80, 29, 0, 0 }, { 6.00, 0, 0, 0 } } } }, -- Lemon Tang 8
	[72328693870219] = { { part = "LeftHand", keys = { { 3.00, 0, 0, 0 }, { 3.20, -40, 0, 0 }, { 3.40, -40, 0, 0 }, { 3.60, 0, 0, 0 } } } }, -- Lemon Tang 9
	[125963510042067] = { { part = "RightHand", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, -40 }, { 1.00, 0, 0, -40 }, { 1.20, 0, 0, 0 } } } }, -- Lemon Tang 18
	[83504291197334] = { { part = "LeftHand", keys = { { 3.20, 0, 0, 0 }, { 3.40, 24, 0, 0 }, { 3.60, 40, 0, 0 }, { 3.80, 0, 0, 0 } } }, { part = "RightHand", keys = { { 4.20, 0, 0, 0 }, { 4.40, 24, 0, 0 }, { 4.60, 40, 0, 0 }, { 4.80, 0, 0, 0 } } } }, -- Lemon Tang 22
	[115787352538480] = { { part = "LeftHand", keys = { { 0.60, 0, 0, 0 }, { 0.80, 0, 0, 38 }, { 1.00, 0, 0, 40 }, { 1.20, 0, 0, 0 } } }, { part = "RightHand", keys = { { 4.20, 0, 0, 0 }, { 4.40, -28, 0, 0 }, { 4.60, -40, 0, 0 }, { 4.80, 0, 0, 0 } } } }, -- Lemon Tang 23
	[99840608563579] = { { part = "LeftHand", keys = { { 5.40, 0, 0, 0 }, { 5.60, 40, 0, 0 }, { 5.80, 40, 0, 0 }, { 6.00, 0, 0, 0 } } } }, -- Lemon Tang 25
	[98315614070332] = { { part = "LeftHand", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 39 }, { 5.00, 0, 0, 40 }, { 5.20, 0, 0, 37 }, { 5.40, 0, 0, 0 } } } }, -- Lemon Tang 27
	[92757942038731] = { { part = "LeftHand", keys = { { 3.60, 0, 0, 0 }, { 3.80, 35, 0, 0 }, { 4.00, 22, 0, 0 }, { 4.20, 30, 0, 0 }, { 4.40, 0, 0, 0 } } }, { part = "LeftHand", keys = { { 5.60, 0, 0, 0 }, { 5.80, 40, 0, 0 }, { 6.00, 40, 0, 0 }, { 6.20, 0, 0, 0 } } } }, -- Lemon Tang 22 (D-1064)
	[140529283375287] = { { part = "LeftHand", keys = { { 3.00, 0, 0, 0 }, { 3.20, 0, 0, 40 }, { 3.40, 0, 0, 40 }, { 3.60, 0, 0, 40 }, { 3.80, 0, 0, 0 } } } }, -- 갑자기 3
	[127323208506008] = { { part = "RightHand", keys = { { 0.60, 0, 0, 0 }, { 0.80, 40, 0, 0 }, { 1.00, 38, 0, 0 }, { 1.20, 0, 0, 0 } } }, { part = "RightHand", keys = { { 2.20, 0, 0, 0 }, { 2.40, 22, 0, 0 }, { 2.60, 27, 0, 0 }, { 2.80, 30, 0, 0 }, { 3.00, 19, 0, 0 }, { 3.20, 33, 0, 0 }, { 3.40, 0, 0, 0 } } } }, -- Genie 3
	[105545108302127] = { { part = "RightHand", keys = { { 6.60, 0, 0, 0 }, { 6.80, 0, 0, 36 }, { 7.00, 0, 0, 37 }, { 7.20, 0, 0, 0 } } } }, -- Genie 6
	[76060752564499] = { { part = "LeftHand", keys = { { 5.00, 0, 0, 0 }, { 5.20, 0, 0, 40 }, { 5.40, 0, 0, 39 }, { 5.60, 0, 0, 0 } } }, { part = "RightHand", keys = { { 5.60, 0, 0, 0 }, { 5.80, 40, 0, 0 }, { 6.00, 40, 0, 0 }, { 6.20, 40, 0, 0 }, { 6.40, 0, 0, 0 } } } }, -- Genie 10
	[125902811896005] = { { part = "LeftHand", keys = { { 5.20, 0, 0, 0 }, { 5.40, 29, 0, 0 }, { 5.60, 23, 0, 0 }, { 5.80, 0, 0, 0 } } } }, -- Genie 22
	[137275968003632] = { { part = "LeftHand", keys = { { 0.20, 0, 0, 0 }, { 0.40, 0, 0, 40 }, { 0.60, 0, 0, 27 }, { 0.80, 0, 0, 0 } } }, { part = "RightHand", keys = { { 2.80, 0, 0, 0 }, { 3.00, 0, 0, 31 }, { 3.20, 0, 0, 16 }, { 3.40, 0, 0, 0 } } } }, -- LOVE ATTACK 5
	[110961201759433] = { { part = "LeftHand", keys = { { 1.60, 0, 0, 0 }, { 1.80, -40, 0, 0 }, { 2.00, -40, 0, 0 }, { 2.20, 0, 0, 0 } } } }, -- LOVE ATTACK 6
	[97954457634320] = { { part = "LeftHand", keys = { { 4.20, 0, 0, 0 }, { 4.40, 33, 0, 0 }, { 4.60, 32, 0, 0 }, { 4.80, 0, 0, 0 } } } }, -- LOVE ATTACK 19
	[80718941616155] = { { part = "RightHand", keys = { { 8.60, 0, 0, 0 }, { 8.80, 0, 0, -40 }, { 9.00, 0, 0, -34 }, { 9.20, 0, 0, 0 } } } }, -- I SPY 17
	[114665222364433] = { { part = "LeftHand", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 40 }, { 5.00, 0, 0, 40 }, { 5.20, 0, 0, 0 } } }, { part = "RightHand", keys = { { 5.60, 0, 0, 0 }, { 5.80, 0, 0, -14 }, { 6.00, 0, 0, -19 }, { 6.20, 0, 0, 0 } } } }, -- I SPY 26
	[80845800354299] = { { part = "RightHand", keys = { { 6.80, 0, 0, 0 }, { 7.00, 0, 0, -40 }, { 7.20, 0, 0, -40 }, { 7.40, 0, 0, 0 } } } }, -- I SPY 29
	[76336157312311] = { { part = "LeftHand", keys = { { 0.00, 0, 0, 0 }, { 0.20, 40, 0, 0 }, { 0.40, 29, 0, 0 }, { 0.60, 0, 0, 0 } } } }, -- REDRED 7
	[80284068432208] = { { part = "LeftHand", keys = { { 1.60, 0, 0, 0 }, { 1.80, 37, 0, 0 }, { 2.00, 36, 0, 0 }, { 2.20, 29, 0, 0 }, { 2.40, 0, 0, 0 } } } }, -- REDRED 13
	[137960851963972] = { { part = "LeftHand", keys = { { 0.80, 0, 0, 0 }, { 1.00, 0, 0, 35 }, { 1.20, 0, 0, 37 }, { 1.40, 0, 0, 0 } } }, { part = "RightHand", keys = { { 0.40, 0, 0, 0 }, { 0.60, 0, 0, -40 }, { 0.80, 0, 0, -40 }, { 1.00, 0, 0, -40 }, { 1.20, 0, 0, -40 }, { 1.40, 0, 0, 0 } } } }, -- Pop Off 4
	[89349893602236] = { { part = "RightHand", keys = { { 7.60, 0, 0, 0 }, { 7.80, 40, 0, 0 }, { 8.00, 40, 0, 0 }, { 8.20, 40, 0, 0 }, { 8.40, 0, 0, 0 } } }, { part = "RightHand", keys = { { 8.40, 0, 0, 0 }, { 8.60, 40, 0, 0 }, { 8.80, 0, 0, 0 } } } }, -- Pop Off 8
	[89756644797564] = { { part = "LeftHand", keys = { { 5.20, 0, 0, 0 }, { 5.40, -36, 0, 0 }, { 5.60, 0, 0, 0 } } } }, -- Pop Off 9
	[106148688158261] = { { part = "RightHand", keys = { { 2.40, 0, 0, 0 }, { 2.60, 25, 0, 0 }, { 2.80, 17, 0, 0 }, { 3.00, 0, 0, 0 } } } }, -- Pop Off 13
	[87535109402600] = { { part = "RightHand", keys = { { 7.60, 0, 0, 0 }, { 7.80, 0, 0, -28 }, { 8.00, 0, 0, -26 }, { 8.20, 0, 0, 0 } } } }, -- Pop Off 19
	[97208831163609] = { { part = "LeftHand", keys = { { 3.80, 0, 0, 0 }, { 4.00, 16, 0, 0 }, { 4.20, 24, 0, 0 }, { 4.40, 22, 0, 0 }, { 4.60, 0, 0, 0 } } }, { part = "RightHand", keys = { { 2.60, 0, 0, 0 }, { 2.80, 31, 0, 0 }, { 3.00, 35, 0, 0 }, { 3.20, 0, 0, 0 } } } }, -- Pretty Girl 4
	[123817870898356] = { { part = "RightHand", keys = { { 0.00, 0, 0, -40 }, { 0.20, 0, 0, -40 }, { 0.40, 0, 0, -40 }, { 0.60, 0, 0, 0 } } } }, -- Pretty Girl 5
	[110044834729128] = { { part = "RightHand", keys = { { 2.00, 0, 0, 0 }, { 2.20, 0, 0, -40 }, { 2.40, 0, 0, -40 }, { 2.60, 0, 0, 0 } } } }, -- Pretty Girl 13
	[126827294531161] = { { part = "LeftHand", keys = { { 3.20, 0, 0, 0 }, { 3.40, 40, 0, 0 }, { 3.60, 40, 0, 0 }, { 3.80, 40, 0, 0 }, { 4.00, 0, 0, 0 } } } }, -- Pretty Girl 14
	[90231422396171] = { { part = "RightHand", keys = { { 7.00, 0, 0, 0 }, { 7.20, 40, 0, 0 }, { 7.40, 40, 0, 0 }, { 7.60, 40, 0, 0 }, { 7.80, 0, 0, 0 } } } }, -- Pretty Girl 20
	[109633407896106] = { { part = "RightHand", keys = { { 3.80, 0, 0, 0 }, { 4.00, 0, 0, -40 }, { 4.20, 0, 0, -40 }, { 4.40, 0, 0, -40 }, { 4.60, 0, 0, 0 } } } }, -- Love 119 22
	[136973102149586] = { { part = "RightHand", keys = { { 0.00, -17, 0, 0 }, { 0.20, -24, 0, 0 }, { 0.40, 0, 0, 0 } } } }, -- Love 119 29
	-- (D-1263, user 2026-11-10: "CRASH 고개 손목 확인해") hand_moves.py (MediaPipe hands, every 0.05 s) on all 20 clips → wristMisses,
	-- checked by eye on frame sheets (left out: clip 3 left hand in the pocket, clip 19 hands clasped and hidden); keys 0.09 s early;
	-- capture wrist + bend kept ≤ 73° (clip 12 / 13 cut to 25 / 22: the capture already bends 56-57°)
	[110262357944188] = { { part = "RightHand", keys = { { 5.11, 0, 0, 0 }, { 5.31, 20, 0, 0 }, { 5.51, 18, 0, 0 }, { 5.71, 0, 0, 0 } } } }, -- CRASH 3 (22.3 s, palm up by the face)
	-- (CRASH 4 at 30.6-31.2 s, the pointing hand bent down +40..+60 in the video, was tried with LeftHand x -40: in Play the hand
	-- read -20 against the forearm, the wrong way, so it is left out)
	[86200130207984] = { { part = "RightHand", keys = { { 3.31, 0, 0, 0 }, { 3.51, 0, 0, 29 }, { 3.71, 0, 0, 29 }, { 3.91, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 5.71, 0, 0, 0 }, { 5.91, -40, 0, 0 }, { 6.11, -40, 0, 0 }, { 6.31, -40, 0, 0 }, { 6.51, -40, 0, 0 }, { 6.71, -40, 0, 0 }, { 6.91, 0, 0, 0 } } } }, -- CRASH 5 (35.1 s X arms, 37.5-38.5 s palm bent back by the head)
	[124516959620423] = { { part = "RightHand", keys = { { 4.91, 0, 0, 0 }, { 5.11, 25, 0, 0 }, { 5.30, 25, 0, 0 }, { 5.50, 0, 0, 0 } } } }, -- CRASH 12 (93.9 s raised claw hand bent back)
	[124646840847010] = { { part = "RightHand", keys = { { 0.00, 22, 0, 0 }, { 0.11, 22, 0, 0 }, { 0.31, 0, 0, 0 } } } }, -- CRASH 13 (the same claw to 94.8 s)
	[92004530682011] = { { part = "LeftHand", keys = { { 3.11, 0, 0, 0 }, { 3.31, 31, 0, 0 }, { 3.51, 40, 0, 0 }, { 3.71, 0, 0, 0 } } },
		{ part = "LeftHand", keys = { { 3.71, 0, 0, 0 }, { 3.91, 0, 0, 35 }, { 4.11, 0, 0, 27 }, { 4.31, 0, 0, 0 } } } }, -- CRASH 15 (117.4-118.3 s arm across the face, hand bent)
} :: {[number]: any}
for _, tbl in ipairs({ M.ChoreoHeadTilt, M.ChoreoWristBend }) do
	for id, list in pairs(tbl) do
		local fix = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = fix
		fix.bend = fix.bend or {}
		for _, b in ipairs(list) do table.insert(fix.bend, b) end
	end
end

return M