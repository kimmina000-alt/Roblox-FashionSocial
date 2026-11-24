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
-- (D-1972, user 2026-11-21: "손목과 발목 고개 움직임은 유지하고 그 외 움직임만 … 중간 중간 프레임 삭제해서
-- 부드럽게 연결", "미세한 움직임이나 … 튀는 프레임, 떨림 없애기") key reduction for every joint but
-- `keep` (ChoreoSmooth.reduce): spikes over `spike` degrees put back on their neighbours' line,
-- then only the poses that hold the shape (within `tol` degrees, at least one every `maxGap` s)
-- stay and the rest are rebuilt on a smooth curve through them. A piece's ChoreoFixes `sharp`
-- skips it. Studio: FashionGame attribute ChoreoReduceOff = the old clean-ups. nil = off.
-- (D-1972, 2nd pass) post = true: the shake / average clean-ups still run on the reduced curve (reduction alone made
-- more fast moments in the real playback: NEON +21 %, Lemonade +23 %, measured by 안무 (3) 편집)
-- (D-1956) hit = degrees/s: a move this fast that stops dead (or starts) keeps that pose as a still key (the beat's hit)
-- (D-1956, 2nd review) post = false again: the shake / average clean-ups on top rubbed out small hits (BANG 0-60 s against the
-- video: hits gone 76 -> 67, reduction off 62; pairs 162 -> 171, off 179); arms shake 5.85 -> 6.28 degrees RMS, legs 4.23 -> 4.34
-- (before the edits 5.81 / 5.30)
M.ChoreoReduce = { spike = 4, tol = 8, maxGap = 0.6, post = false, hit = 150, keep = { "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot" } } :: any
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
--   jump = { from, to, height }: the body in the air from `from` to `to` on an
--     arc `height` studs high (D-1771; filled from M.ChoreoJumps below), or a list
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
--     a key's `curve` = "linear" | "in" | "out" shapes the stretch to the next key (nil: eased at both ends,
--     so the joints stop at every key), D-1400
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
	-- (D-1964) aespa-Lemonade 2:14-2:15 "다리 버벅": v3 piece 15 (practice white-cap member) loses her behind the group from its
	-- 8.0 s (song 133.5) while it fades out into the floor piece: it keeps its 8.0 s pose instead
	[126596392429323] = { warp = { { from = 8.0, to = 9.6, play = { 8.0, 8.0 } } } },
	-- (D-1962) aespa-Lemonade v3 piece 16 (SBS clip 15, the floor part): its first 2.0 s follow another dancer bending over
	-- Winter (every source hides her at song 133.5-135.6), so those seconds show her first floor pose (2.1 s) and the piece
	-- before fades into it over 1.5 s (ClubPlaylist blend): she goes down to the floor instead of the body jumping 0.5 stud
	[106681280470448] = { warp = { { from = 0, to = 2.1, play = { 2.1, 2.1 } } } },
	-- (D-1670) Boogie Woogie-NCT DREAM, Play scan > 600°/s: 3 turns at 0:13.5 (631°/s), 16 turns a lap at 2:11.2 (621°/s) → spread
	[98798684410312] = { spin = { from = 1.7, to = 2.6, ease = "both" } }, -- BW 3
	[92147677701072] = { spin = { from = 0, to = 1.6, fromPrev = true, dir = 1, ease = "both" } }, -- BW 16 (D-1851, user "2:10 회전 매끄럽게": 732°/s at 2:11.2, spread over 1.35 s)
	[70911274448112] = { spin = { from = 7.0, to = 8.6, ease = "both" } }, -- BW 9 (D-1671: one lap -2 → 365° with 855°/s in the capture)
	-- (D-1603) 내 이름을 불러줘-TWS: fast turns spread evenly (choreo_motion_scan + Play scan > 600°/s); 5 / 11 start against the piece
	-- before (the capture turns back 150 / 84° at the seam, then on the same way) → fromPrev; 18 picks up 17's turn → fromPrev;
	-- 9 starts with a lap after the default dance (fromPrev has no piece before) → blend 0.08 + its own spin
	[88993457159273] = { spin = { from = 4.3, to = 5.55, ease = "both", add = -52 } }, -- TWS 2 (one lap with a -165° keyframe; D-1850: done by 0:17.3, ending to the front)
	[83828094822862] = { spin = { { from = 0, to = 1.1, fromPrev = true, dir = -1, ease = "both" }, { from = 4.4, to = 5.9, ease = "both" } } }, -- TWS 5
	-- TWS 6: (D-1855) no spin: the 0:48 bend stands on planted legs (the capture's lap there is held by a freeze)
	[73429358232249] = { spin = { from = 0, to = 1.1, fromPrev = true, dir = 1, ease = "both" } }, -- TWS 9 (D-1658: after 8 again, which ends turned 130° away: one +159° turn back to the front, as in the video)
	[133275108218481] = { spin = { { from = 0, to = 2.7, fromPrev = true, dir = -1, turns = -1, ease = "both" }, { from = 2.7, to = 3.93, ease = "linear" } } }, -- TWS 11 (D-1850: one whole turn to 1:16.5, the capture turned half way and back; D-1855: then on at one speed into 12)
	[107243018629607] = { spin = { from = 0, to = 1.85, fromPrev = true, dir = -1, ease = "linear" } }, -- TWS 12 (627°/s at the seam, 2nd Play scan; D-1855, user "1:18 회전할 때 프레임 끊김": it stood still at the seam 77.8-77.9 and at 78.9, now one even turn to 79.6; blend 1 -> 0.4: the slow hand-over held the turn)
	[137670042338904] = { spin = { from = 6.5, to = 8.0, ease = "both" } }, -- TWS 14
	[107246799142521] = { spin = { from = 6.8, to = 7.97, ease = "linear" } }, -- TWS 17 (carried on by 18)
	[100667532281425] = { spin = { { from = 0, to = 1.0, fromPrev = true, dir = 1 }, { from = 2.6, to = 4.6, ease = "both" } } }, -- TWS 18
	[122207092339520] = { spin = { from = 8.8, to = 12.0, ease = "both" } }, -- TWS 19
	[96319765244846] = { spin = { from = 0.5, to = 2.2, ease = "both" } }, -- TWS 20
	-- (D-1400, user 2026-11-14, BANG-After School: "1:20 가슴 튕기는 안무처럼 가슴 더 크게 튕기기.쿵.쿵.쿵 박자에 / 1:38 안무 확인
	-- (9번 안무인데 동작 다름) / 2:14 안무 두 번씩 함 한 번으로 깔끔하게 정리 / 2:23 오른쪽팔 움찔"). BANG's song rate is 1.000, so
	-- the play-bar times are song seconds; beats (practice video, 119.5 bpm) at song 1.161 + k x 0.5021.
	-- 7 (at 78.68): the capture's chest only dips 0.1-0.2 at 80.7 / 81.1 / 81.4; three big pops on the beats, (D-1400 2nd, user:
	-- "가슴 튕기는 안무 1.5초 늦게 시작") 81.99 / 82.50 / 83.00 (0.09 s early, the animation clock lags)
	[117412778868520] = { sharp = true, pops = { at = { 3.22, 3.72, 4.23 }, sizes = { 1.6, 1.6, 1.6 }, push = 0.5, lift = 0.2, arch = 9, out = 0.05, back = 0.35 } },
	-- 8 (at 89.86) end and 9 (at 99.60) start: in the video the centre stands with both hands on the hips from song 96.3 to 102.8
	-- (others pass close behind her, so the capture lost it: hands in front of the chest, one inside the body, then up at the
	-- face at 98.0-98.6 and 99.4-100.2); both arms set to hands on the hips (angles solved on the avatar's own joints: hand at
	-- the waist side, elbow out wide)
	-- (D-1933, 2nd review: before the hands go to the hips the video brings a hand to the mouth (96.7) and both hands up by the
	-- face (97.1), on the hips at 97.5) the face hands 96.4-97.2, the hips from 97.45 (was 96.36)
	[91956738526101] = { pose = { from = 6.3, to = 9.7, ease = 0.3, keys = {
		{ t = 6.7, set = { LeftUpperArm = { 25, 0, -10 }, LeftLowerArm = { 115, 0, 0 } } },
		{ t = 7.05, set = { LeftUpperArm = { 25, 0, -10 }, LeftLowerArm = { 115, 0, 0 }, RightUpperArm = { 25, 0, 10 }, RightLowerArm = { 115, 0, 0 } } },
		{ t = 7.25, set = { LeftUpperArm = { 25, 0, -10 }, LeftLowerArm = { 115, 0, 0 }, RightUpperArm = { 25, 0, 10 }, RightLowerArm = { 115, 0, 0 } } },
		{ t = 7.6, set = { RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { -90, -40, -60 }, LeftLowerArm = { 90, 0, 0 } } } } } },
	-- (D-1400 2nd, user + clip 9: "왼쪽팔 들고 흔드는 안무가 안 들어감") at song 104.0-105.4 (clip 4.4-5.8) the right hand stays on
	-- the hip and the left arm goes up beside the head and waves (the capture holds it in front of the face): left arm keys
	-- solved like the hips (beside the head / out a little), the wrist flicking with each
	-- (D-1933, 2nd review: at 1:41.3-1:41.9 the video's left hand goes up beside the head and back to the hip)
	[71518245203286] = { pose = { { from = 0, to = 3.3, ease = 0.3, keys = {
		{ t = 0, set = { RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { -90, -40, -60 }, LeftLowerArm = { 90, 0, 0 } } },
		{ t = 1.6, set = { RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { -90, -40, -60 }, LeftLowerArm = { 90, 0, 0 } } }, { t = 1.9, set = { RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { 55, -35, -70 }, LeftLowerArm = { 105, 0, 0 } } }, { t = 2.05, set = { RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { 55, -35, -70 }, LeftLowerArm = { 105, 0, 0 } } },
		{ t = 2.35, set = { RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, LeftUpperArm = { -90, -40, -60 }, LeftLowerArm = { 90, 0, 0 } } } } },
		{ from = 4.0, to = 5.95, ease = 0.45, keys = {
			{ t = 4.45, set = { LeftUpperArm = { 75, -35, -70 }, LeftLowerArm = { 80, 0, 0 } } },
			{ t = 4.7, set = { LeftUpperArm = { 75, -25, -65 }, LeftLowerArm = { 80, 0, 0 } } },
			{ t = 4.95, set = { LeftUpperArm = { 75, -35, -70 }, LeftLowerArm = { 80, 0, 0 } } },
			{ t = 5.2, set = { LeftUpperArm = { 75, -25, -65 }, LeftLowerArm = { 80, 0, 0 } } },
			{ t = 5.45, set = { LeftUpperArm = { 75, -35, -70 }, LeftLowerArm = { 80, 0, 0 } } } } } },
		bend = { { part = "LeftHand", keys = { { 4.45, 0, 0, 0 }, { 4.7, 0, 0, -35 }, { 4.95, 0, 0, 20 }, { 5.2, 0, 0, -35 }, { 5.45, 0, 0, 20 }, { 5.7, 0, 0, 0 } } } } },
	-- 12 (at 134.23): the formation walk at 2:14 lowers the hands down and back twice (song 134.6-135.8 and again 136.6-137.6,
	-- the video's centre changes in between): (first a hold, replaced below); at 2:23 (song 142.7-144.1)
	-- the video folds the arms across the chest, the capture put the right hand inside the body, so BodyGuard swung the arm
	-- out 43° in 0.2 s: both arms set folded in front (solved like above; the clip follows the member on the left, who folds
	-- her arms; the capture puts the hands back inside the body after 144.2, so the fold lets go slowly, over 0.8 s)
	-- (D-1400 2nd, user + a screen recording of the video: "2:14 안무 첨부한 영상 보고 수정. 양쪽 팔 한번씩 들었다가 내리는 안무. 팔
	-- 부드럽게 웨이브 들어감"): the right arm up and down is the capture's own (134.0-135.0); the hold is gone; the left arm goes up
	-- curved over the head and waves (135.0-136.2), then both arms wave out at the sides (136.5-137.4, the right arm comes up over 0.4 s: 0.3 s whipped) and come down into the walk:
	-- one pose window (two that meet let the capture show between), keys solved like the hips
	-- (D-1400 3rd, user: "2:13 처음 오른팔만 올린 자세에서 양팔 다 내렸다가 2:15에 왼팔만 올리는 자세로 스무스하게 이어지게 수정 / 지금
	-- 올렸다 내렸다 들썩거림"): the right arm came down at 133.8 (11), up again at 134.1 (12 starts with it up) and down at 135.0;
	-- now both arms go down at the end of 11 and stay down (the window starts before 0 so 12 opens at full weight) until the
	-- left arm rises at 135.0
	[114991184702089] = { pose = { { from = -0.5, to = 3.6, ease = 0.45, keys = {
			-- (D-1400 4th) the arms cross: the right comes down round the side while the left goes up round the side, without
			-- stopping at the keys (`curve`: in at 11's raised arm, linear through the cross, out at the top)
			{ t = 0, curve = "linear", set = { RightUpperArm = { 40, 0, 60 }, RightLowerArm = { 60, 0, 0 }, LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 } } },
			{ t = 0.3, curve = "linear", set = { RightUpperArm = { 20, 0, 35 }, RightLowerArm = { 35, 0, 0 }, LeftUpperArm = { 20, 0, -35 }, LeftLowerArm = { 35, 0, 0 } } },
			{ t = 0.6, curve = "out", set = { RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 40, 0, -60 }, LeftLowerArm = { 60, 0, 0 } } },
			{ t = 0.95, set = { RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 60, -60, -90 }, LeftLowerArm = { 60, 0, 0 } } },
			{ t = 1.3, set = { LeftUpperArm = { 75, -35, -70 }, LeftLowerArm = { 80, 0, 0 }, RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 } } },
			{ t = 1.6, set = { LeftUpperArm = { 60, -60, -90 }, LeftLowerArm = { 60, 0, 0 }, RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 } } },
			{ t = 1.9, set = { LeftUpperArm = { 75, -25, -65 }, LeftLowerArm = { 80, 0, 0 }, RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 } } },
			-- (D-1935, user 2026-11-20 via the 2nd review: "원본처럼 내려") 2:16.4-2:17.6 both arms down at the sides, walking (was the
			-- D-1400 wave out at the sides)
			{ t = 2.2, set = { LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 } } },
			{ t = 3.3, set = { LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 }, RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 } } } } },
		{ from = 8.3, to = 11.0, ease = 0.8, keys = {
			{ t = 8.5, set = { RightUpperArm = { -10, 90, 40 }, RightLowerArm = { 80, 0, 0 }, LeftUpperArm = { 80, -90, 50 }, LeftLowerArm = { 70, 0, 0 } } } } } },
		bend = { { part = "LeftHand", keys = { { 1.0, 0, 0, 0 }, { 1.3, 0, 0, -25 }, { 1.6, 0, 0, 15 }, { 1.9, 0, 0, -25 }, { 2.3, 0, 0, 0 } } },
		} },
	-- (D-1394) BANG-After School, Play scan: 5 turns a full lap at 1:04.6-1:06.0 with one frame of 1033°/s → spread evenly;
	-- 13 swings back 86° in one keyframe at 3:00.7 (663°/s) → eased
	[102971667388731] = { spin = { from = 4.2, to = 5.6, ease = "both" } }, -- BANG 5
	[73991603786553] = { spin = { from = 5.3, to = 6.0, ease = "both" } }, -- BANG 13
	-- (D-1399) BANG 11: the capture turns to the front at 4.5-4.9, jumps back 150° in one keyframe at 5.0 (another dancer passes in
	-- front) and turns again at 5.4-6.2 → one even turn 4.4-6.3
	[122763589970816] = { spin = { from = 4.4, to = 6.3, ease = "both" }, -- BANG 11
		-- (D-1400 3rd) both arms down from song 133.66 into 12 (the window runs past the end, so it holds at full weight)
		-- (D-1400 4th, user: "2:14 오른팔 들썩거리는 거 잡아 / 오른쪽 들고 왼팔 들 때 오른팔 내리는 중간부터 왼팔 들기 시작해서 서로
		-- 교차되는 느낌으로. 둥글게.") the right arm held up (solved overhead) to 133.56, then down round the side: at 12's start
		-- (the seam, 134.21) it is out at the side, where 12's keys take it on
		pose = { from = 9.7, to = 11.5, ease = 0.35, keys = { { t = 10.05, curve = "in", set = { RightUpperArm = { 110, 70, 40 }, RightLowerArm = { 40, 0, 0 }, LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 } } },
			{ t = 10.7, set = { RightUpperArm = { 40, 0, 60 }, RightLowerArm = { 60, 0, 0 }, LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 } } } } } },
	-- (D-1387, user 2026-11-13 + 2 photos: "클럽 댄스 3 처음에 왼팔 들고 있을 때 왼쪽 손목 천천히 돌리기 / 양쪽 팔 둘 다 내릴 때
	-- 손목 손등쪽으로 꺾기 / 오른쪽팔만 들 때 손목 안쪽으로 세 번 꺾기") the menu dance club3 (ClubDances, 15.43 s loop; menu
	-- dances take only `bend`, ChoreoController menuBends). Left arm up at the start 0-1.5: one slow circle; both arms
	-- down in front 2.45-4.85 and 5.95-7.1: the backs of the hands bent back (out: left z -, right z +; the capture is
	-- already out 20-44°, so +25 keeps the total ≤ 70°); the right arm alone up 9.75-10.95: three bends in (right z -75: the capture holds it out ~50°, so -50 only reached 0)
	[110198854438295] = { bend = { { part = "LeftHand", keys = wristCircles(0.05, 1.45, 1.4, 30) },
		{ part = "LeftHand", keys = { { 2.45, 0, 0, 0 }, { 2.7, 0, 0, -25 }, { 4.6, 0, 0, -25 }, { 4.85, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 2.45, 0, 0, 0 }, { 2.7, 0, 0, 25 }, { 4.6, 0, 0, 25 }, { 4.85, 0, 0, 0 } } },
		{ part = "LeftHand", keys = { { 5.95, 0, 0, 0 }, { 6.2, 0, 0, -25 }, { 6.85, 0, 0, -25 }, { 7.1, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 5.95, 0, 0, 0 }, { 6.2, 0, 0, 25 }, { 6.85, 0, 0, 25 }, { 7.1, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 9.75, 0, 0, 0 }, { 9.92, 0, 0, -75 }, { 10.1, 0, 0, 0 }, { 10.27, 0, 0, -75 }, { 10.45, 0, 0, 0 },
			{ 10.62, 0, 0, -75 }, { 10.8, 0, 0, 0 }, { 10.95, 0, 0, 0 } } } } },
	-- (D-1306, Play re-scan) With 16 turns 606°/s at 1:48.6 (a real fast turn, about 310° in 1.3 s) → spread evenly
	[78971722650566] = { spin = { from = 4.8, to = 6.2, ease = "both" } },
	-- (D-1306, tools/choreo/guard_scan.lua at 1x, D-1303 rule) BodyGuard flicks the right arm (shoulder step 6.3 / 9.1 / 11.8° a frame with the
	-- guard, 5.3 / 7.5 / 8.1° without): With 6 at 0:31.8, 백화요란 2 at 1:03.2 and 12 at 2:17.0 → guardOff; With 20 head shakes at 2:36.2 → steady 24
	[131580629784808] = { guardOff = { from = 7.8, to = 8.6, side = "Right" } },
	[74180602033079] = { guardOff = { from = 2.9, to = 3.7, side = "Right" } },
	[72320524127017] = { guardOff = { from = 7.2, to = 8.1, side = "Right" } },
	[97670698889704] = { steady = { from = 5.2, to = 5.8, passes = 24 } },
	-- With-RESCENE (D-1306, choreo_motion_scan): 3, 5 and 21 start 126-152° the other way while the piece before turns on (SEAM);
	-- 9 at 0:50.1 jumps 94° in one keyframe in a full turn (LURCH)
	[77578453879056] = { spin = { from = 0, to = 1.2, fromPrev = true, dir = 1 } },
	[113905277691263] = { spin = { from = 0, to = 1.2, fromPrev = true, dir = -1 } },
	[103780560163454] = { spin = { from = 0, to = 1.2, fromPrev = true, dir = 1 } },
	[87649722430222] = { spin = { from = 2.4, to = 4.4, ease = "both" } },
	-- SHOCK-TREASURE (D-1298, choreo_motion_scan): 14 at 2:00.1 jumps 152° in one keyframe in a half turn (LURCH); 15 starts 110° the
	-- other way while 14 turns on (SEAM)
	[121912364930816] = { spin = { from = 7.3, to = 9.2, ease = "both" } },
	[139616314090616] = { spin = { from = 0, to = 1.12, fromPrev = true, dir = -1 } },
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
	[108870214091189] = { freeze = { from = 0.3, to = 2.2, ease = 0.25, except = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Head", "UpperTorso", "LowerTorso" } } }, -- 19 (capture wraps back 150° at 1.0-1.2: one even lap, carried on from the blend)
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
					-- (D-1967, "2:22 엉덩이 들고 자세 고칠 때 위로 튕기는 거": straightening the folded right leg swept the shin down through
					-- the floor and the floor lift popped the hips 2.2 studs; the thigh lifted on the way: 0.6)
					{ t = 4.25, set = with(kneelL, { RightUpperLeg = { 150, 0, 0 }, RightLowerLeg = { -30, 0, 0 }, RightFoot = { 20, 0, 0 } }), move = { LowerTorso = { 0, -3.3, 0 } } },
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
	-- AND2BLE-Potion (D-2070, the practice video AND2BLE_Potion_pFx8c8C6PxU.mp4): `still` where the clip's member stands in the
	-- video (still_from_video.py); 2 / 5 start where 1 / 4 left the hips (the seams were 178° / 123° off): one even turn on from there
	[133318654819881] = { still = { { from = 0.1, to = 1.07 }, { from = 2.1, to = 6.04 } }, spin = { from = 1.9, to = 2.7, ease = "both" } }, -- 1 (0:02.4: the capture flips round at 2.1-2.3 and back: a 52° turn)
	[103367592212025] = { still = { from = 0.8, to = 2.07 } }, -- 9
	[130711084322752] = { spin = { { from = 0, to = 1.0, fromPrev = true, ease = "both" }, { from = 8.1, to = 9.9, ease = "both" } } }, -- 2 (0:06.3; 0:14.7 a turn and a quarter)
	[95673249740111] = { spin = { from = 0, to = 1.8, fromPrev = true, ease = "both" } }, -- 5 (0:28.6)
	-- (Play flagSong SPIN 607-1174°/s: each one even turn over the capture's own turn) 4 (0:24.9), 7 (0:48.8), 8 (1:01.0 out and back),
	-- 10 (1:17.4), 14 (1:43.1), 21 (2:44.8); TELEPORT 0:38.9 / 1:18.0 / 1:41.7 / 1:48.9 -> `still`
	[103390008118494] = { spin = { from = 1.8, to = 3.3, ease = "both" } }, -- 4
	[120104884356350] = { spin = { from = 1.6, to = 3.2, ease = "both" } }, -- 7
	[81060374021567] = { spin = { { from = 5.0, to = 5.7, ease = "both" }, { from = 5.7, to = 6.6, ease = "both" } } }, -- 8
	[87481181692394] = { spin = { from = 8.3, to = 9.9, ease = "both" }, still = { from = 9.0, to = 9.6 } }, -- 10
	[90931443555959] = { spin = { from = 1.4, to = 2.7, ease = "both" }, still = { { from = 0.4, to = 1.0 }, { from = 7.5, to = 8.2 } } }, -- 14
	[140702968960287] = { spin = { from = 2.4, to = 3.8, ease = "both" } }, -- 21
	[101462515949658] = { still = { from = 0.5, to = 1.3 } }, -- 6
	-- ILLIT-It's Me (D-2071, the stage cross-edit ILLIT_ItsMe_SI22DIl-Pow.mp4): `still` where the clip's member stands in the
	-- video (still_from_video.py; clip 1 plays from 1.95)
	[114536010136920] = { still = { { from = 1.95, to = 2.47 }, { from = 4.55, to = 5.92 } } }, -- 1
	[81568891729334] = { still = { { from = 0.12, to = 0.87 }, { from = 2.2, to = 2.88 } } }, -- 10
	[73159033431986] = { still = { from = 3.97, to = 8.93 }, spin = { from = 3.7, to = 4.4, ease = "both" } }, -- 18 (2:06.4 SPIN 669°/s: a quick look round and back)
	-- (Play flagSong) 9: 1:01.3 SPIN 625°/s, out and back (+130° then -170°): two even turns; 12: 1:23.3 the body guard flicked the left
	-- arm out 0.30 rad and let it go
	[117993086220024] = { spin = { { from = 6.2, to = 6.9, ease = "both" }, { from = 6.9, to = 7.6, ease = "both" } } }, -- 9
	[134070700021165] = { guardOff = { from = 4.8, to = 5.6, side = "Left" } }, -- 12
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
	-- AND2BLE-Potion (D-2070, choreo_slide_check + motion scan DRIFT)
	[133318654819881] = { { 1.2, 2.1 } }, [130711084322752] = { { 2.0, 3.0 }, { 6.0, 6.9 } }, [103390008118494] = { { 0.1, 0.8 } }, [95673249740111] = { { 1.5, 2.2 }, { 8.1, 8.9 } },
	[120104884356350] = { { 6.8, 7.6 } }, [81060374021567] = { { 4.0, 4.7 } }, [109105261149494] = { { 1.3, 2.1 } }, [82954950901794] = { { 0.7, 1.3 }, { 3.9, 4.5 } },
	[79447997870020] = { { 7.0, 7.9 } }, [90109383769163] = { { 0.2, 1.1 }, { 4.4, 5.7 }, { 6.1, 6.9 } }, [126059736361594] = { { 0.0, 0.7 }, { 2.2, 4.1 }, { 6.6, 7.4 } },
	[129776441704888] = { { 0.9, 1.6 }, { 7.6, 8.3 }, { 9.1, 9.9 }, { 10.3, 11.1 } }, [140702968960287] = { { 0.5, 1.3 } },
	-- ILLIT-It's Me (D-2071, choreo_slide_check + motion scan DRIFT)
	[114536010136920] = { { 6.4, 7.0 } }, [137400923288167] = { { 1.3, 2.4 }, { 5.3, 6.1 } }, [92512766209766] = { { 1.2, 3.1 }, { 5.1, 5.9 } }, [97821283727781] = { { 0.0, 0.7 } },
	[84767858976240] = { { 0.5, 1.0 }, { 3.2, 3.8 } }, [117993086220024] = { { 0.0, 0.7 }, { 7.7, 8.4 } }, [81568891729334] = { { 3.9, 4.6 } }, [134070700021165] = { { 0.5, 1.3 } },
	[74249351083442] = { { 1.4, 2.2 }, { 3.6, 4.5 } }, [95973678135715] = { { 3.0, 3.8 }, { 4.4, 5.2 } }, [127876941649874] = { { 0.6, 2.0 } }, [73159033431986] = { { 0.5, 1.3 }, { 5.5, 6.3 } },
	-- Unbelievable-H1 KEY (D-1672, choreo_slide_check + choreo_motion_scan DRIFT)
	[127086942159592] = { { 2.6, 4.6 }, { 4.8, 5.8 } }, [110146513928585] = { { 1.1, 1.7 }, { 6.1, 7.0 }, { 7.4, 8.1 } }, [98575698595382] = { { 0.0, 0.5 }, { 1.0, 1.8 }, { 3.0, 3.9 } },
	[97422868495252] = { { 1.2, 1.8 } }, [77667909738269] = { { 0.7, 1.3 } }, [106947840145982] = { { 0.5, 1.2 }, { 1.4, 2.0 }, { 4.7, 5.3 }, { 7.6, 8.3 }, { 10.2, 11.1 } },
	[121716323345976] = { { 8.7, 9.4 } }, [85861969329409] = { { 4.5, 5.5 } }, [98632778351786] = { { 3.7, 4.4 } }, [82151831370082] = { { 1.5, 3.2 }, { 5.7, 6.7 } }, -- (+ Play TELEPORT 0:11.7, 0:57.2, 1:25.8, 1:56.6, 1:57.7, 2:00.8, 2:01.3) [132406634119258] = { { 3.1, 6.0 } }, [82476096356644] = { { 6.8, 7.5 } },
	-- Boogie Woogie-NCT DREAM (D-1670, choreo_slide_check + choreo_motion_scan DRIFT + Play TELEPORT 0:10.2, 0:15.3, 1:37.2, 2:14.6, 2:26.9, 3:02.9-3:05.1)
	[72899900258037] = { { 3.8, 4.5 }, { 5.5, 7.0 } }, [98798684410312] = {}, [97814419171643] = { { 0.0, 1.5 }, { 4.3, 4.9 }, { 7.1, 8.0 } },
	[93564912800713] = { { 0.4, 1.0 }, { 5.4, 7.0 } }, [118999861690635] = { { 4.2, 5.4 }, { 5.9, 7.6 } }, [72126724441612] = { { 0.2, 1.6 }, { 2.3, 3.1 } },
	[103506023234554] = { { 5.7, 6.6 }, { 8.4, 9.03 } }, [77759369454741] = { { 6.7, 7.3 }, { 8.4, 9.1 } }, [92147677701072] = { { 1.6, 2.2 } }, [90031774217033] = { { 0.0, 1.8 } },
	[82489608576953] = { { 0.9, 2.1 }, { 2.9, 3.7 }, { 6.3, 6.9 }, { 7.7, 9.4 } }, [140605792599503] = {}, [130987200839765] = { { 0.2, 1.0 }, { 4.5, 5.3 } },
	[138159952468756] = { { 1.6, 2.2 }, { 7.9, 8.6 } }, [79114246750826] = { { 2.5, 3.1 } }, [81117884846850] = { { 1.1, 2.7 }, { 6.0, 6.6 }, { 7.8, 10.8 } }, [123702153844970] = { { 0.2, 0.8 } }, [136974262670764] = { { 1.6, 3.2 }, { 7.9, 9.3 } }, [70911274448112] = { { 2.9, 4.1 }, { 5.9, 6.7 } }, -- 4 / 9 (D-1671, + Play TELEPORT 0:19.5, 0:20.0)
	-- (D-1850, user: "원본 안무가 동선 움직이는 거면 제자리에서 걸음하지 말고 진짜 걸어갈 것") stretches where the practice video's
	-- centre walks 2-8 studs a second (its hips across the frame, tracks.json) and the capture travels too are no longer held:
	-- 1 2.2-6.0 (0:01-0:04), 5 0.6-2.2 / 3.0-3.9 (0:34-0:37), 8 7.4-8.1 (1:05), 19 3.7-4.6 / 12.3-13.0 (2:19 / 2:27), 20 3.0-3.9 / 4.6-6.9 (2:31-2:35)
	-- 내 이름을 불러줘-TWS (D-1603, choreo_slide_check + choreo_motion_scan DRIFT + Play TELEPORT 0:02.3, 0:03.0, 0:03.7, 0:04.2, 0:21.7, 0:28.1, 0:34.5, 0:35.4, 1:16.4, 1:31.4, 2:27.6)
	[84847937406843] = { { 7.5, 8.4 }, { 11.8, 12.7 } }, [74885576782093] = { { 0.0, 1.3 }, { 5.4, 6.9 }, { 7.1, 8.3 } }, [83828094822862] = { { 5.7, 6.3 } },
	[107391937407645] = { { 1.9, 2.5 }, { 8.1, 9.0 } }, [88595092254451] = { { 0.6, 1.5 } }, [107243018629607] = { { 0.2, 0.9 }, { 2.7, 4.0 } },
	[137670042338904] = { { 3.5, 4.1 }, { 9.5, 10.2 }, { 12.2, 12.8 } }, [81624243507898] = { { 0.4, 1.0 }, { 5.7, 6.6 } }, [107246799142521] = { { 1.5, 2.4 }, { 5.6, 6.5 } },
	[122207092339520] = {}, [133275108218481] = { { 2.4, 3.0 } }, [96319765244846] = {}, [90921923486342] = { { 3.0, 4.1 } }, -- TWS 8 (D-1658, + Play TELEPORT 1:05.4)
	-- BANG-After School (D-1394, choreo_slide_check + choreo_motion_scan DRIFT + Play scan)
	[137056236927761] = { { 4.0, 4.6 }, { 7.2, 8.0 } }, [105204020323017] = { { 4.0, 4.7 }, { 11.4, 12.2 }, { 12.7, 13.3 } }, [120933576855785] = { { 1.8, 2.6 }, { 5.5, 6.3 }, { 6.9, 8.2 } },
	[102971667388731] = { { 0.2, 1.0 }, { 5.3, 6.1 } }, [103181529138741] = { { 6.0, 6.6 }, { 7.5, 8.3 }, { 9.0, 9.9 } }, [91956738526101] = { { 1.4, 2.2 }, { 2.9, 4.2 }, { 5.3, 6.0 }, { 8.4, 9.5 } },
	[71518245203286] = { { 5.4, 6.2 } }, [88337047994676] = { { 6.0, 8.4 } }, [114991184702089] = { { 1.6, 2.3 }, { 6.2, 6.8 } }, [133693971779949] = { { 1.1, 1.7 }, { 9.6, 10.4 } },
	[129925869461594] = { { 11.7, 12.4 } }, [73991603786553] = { { 5.9, 7.0 }, { 11.2, 11.83 } },
	[117412778868520] = { { 0.3, 1.1 }, { 1.7, 2.7 }, { 3.6, 4.4 }, { 5.8, 6.6 }, { 6.9, 7.7 } }, [122763589970816] = { { 4.3, 5.1 }, { 6.0, 6.8 }, { 8.0, 8.8 }, { 9.8, 10.6 } },
	[73314859778019] = { { 3.1, 3.8 }, { 4.0, 4.8 }, { 7.4, 8.1 } }, -- 7 / 11 / 16 (D-1399, choreo_slide_check + DRIFT + Play TELEPORT 1:19.4, 3:06.4, 3:14.5) -- (+ Play scan TELEPORT 0:25.9, 0:54.9, 1:13.9, 1:35.4, 2:29.1, 3:01.0, SLIDE 2:20.5)
	-- With-RESCENE (D-1306, choreo_slide_check + choreo_motion_scan DRIFT); also 백화요란 20 (D-1300) and SHOCK 9 (D-1301)
	[81069311107336] = { { 3.0, 3.8 } }, [102977375863633] = { { 1.2, 2.0 }, { 2.5, 3.5 }, { 7.6, 8.2 } }, [113905277691263] = { { 2.5, 3.1 }, { 3.7, 4.4 } },
	[131580629784808] = { { 5.5, 6.1 }, { 9.9, 10.7 } }, [134804041385196] = { { 1.5, 2.3 } }, [135964930726670] = { { 1.6, 2.3 }, { 3.0, 3.7 } },
	[119026591853452] = { { 5.5, 6.2 } }, [75224598365049] = { { 7.4, 8.5 } }, [78971722650566] = { { 0.1, 0.8 } }, [102753426349246] = { { 0.0, 1.0 }, { 2.4, 3.2 } },
	[123058513001948] = { { 1.5, 2.6 }, { 4.5, 5.5 }, { 8.0, 9.4 } }, [98289786237934] = { { 1.9, 3.5 }, { 4.1, 5.3 } }, [97670698889704] = { { 1.0, 1.8 } },
	[103780560163454] = { { 1.6, 2.3 } }, [119066931308311] = { { 1.2, 2.0 }, { 4.2, 4.9 } }, [128822554881165] = { { 3.1, 3.9 } },
	[75577288501140] = { { 2.9, 3.8 }, { 4.1, 4.8 }, { 5.6, 6.1 } }, [132556616885642] = { { 0.5, 1.3 } }, [103924587030311] = { { 1.3, 1.8 } }, -- (+ Play re-scan TELEPORT 1:20.4, 3:02.0)
	[101271170738014] = { { 0.8, 1.4 }, { 3.3, 4.0 }, { 9.9, 10.7 } }, [87672486893566] = { { 2.2, 2.8 }, { 4.4, 5.2 } },
	-- SHOCK-TREASURE (D-1298, choreo_slide_check + choreo_motion_scan DRIFT; fancam captures slide a lot)
	[133830025852955] = { { 6.8, 7.5 }, { 8.3, 9.5 }, { 10.1, 10.9 } }, [117322908574417] = { { 1.6, 2.4 } }, [81779912905543] = { { 2.6, 3.4 }, { 4.2, 5.0 }, { 5.8, 6.6 }, { 11.4, 12.0 } },
	[75987043149726] = { { 0.1, 0.9 }, { 4.0, 4.9 } }, [126059214767439] = { { 0.5, 1.4 }, { 5.6, 6.5 }, { 6.7, 7.2 } }, [131829068826954] = { { 4.9, 5.5 } },
	[121802134861592] = { { 0.9, 1.4 }, { 3.1, 3.6 }, { 6.2, 6.7 }, { 8.1, 9.6 }, { 10.4, 11.0 } }, [130135206628110] = { { 0.8, 1.6 } }, [130317916502145] = { { 2.3, 3.3 }, { 3.6, 4.8 } },
	[112228957264348] = { { 0.0, 2.4 } }, [107109971489791] = { { 0.8, 1.8 } }, [90553036874786] = { { 0.2, 0.8 }, { 1.9, 3.7 }, { 3.8, 4.5 }, { 6.3, 7.1 }, { 8.1, 8.8 } },
	[121912364930816] = { { 3.5, 5.0 }, { 7.1, 8.1 }, { 8.9, 9.4 } }, [73160805709614] = { { 2.0, 3.3 }, { 7.7, 8.7 } }, [79170731093199] = { { 5.6, 6.2 } }, [94923487573207] = { { 1.9, 2.7 } },
	[112291434709741] = { { 0.7, 1.7 }, { 2.0, 2.5 }, { 7.0, 8.4 }, { 9.0, 10.8 }, { 11.2, 12.2 } },
	-- (Play scan: TELEPORT 0:29.9, 0:43.1, 0:51.7-0:58.9 (4), 1:56.4-2:00.8 (4), 2:42.5: the body slides 1-2.4 studs in 0.3 s while the feet step a third)
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
	-- (D-1961) aespa-Lemonade v3 (D-1960): choreo_slide_check stretches (piece time)
	[77152170951340] = { { 6.0, 6.7 }, { 9.7, 10.4 }, { 10.7, 11.3 }, { 12.6, 13.2 }, { 13.6, 14.3 } }, -- Lemonade v3 piece 3
	[98395241216132] = { { 1.2, 1.9 }, { 10.1, 10.7 }, { 11.4, 12.0 } }, -- Lemonade v3 piece 4
	[105689578186345] = { { 4.3, 4.9 }, { 7.4, 8.0 }, { 8.3, 9.1 } }, -- Lemonade v3 piece 5
	[103313535582707] = { { 1.5, 2.1 } }, -- Lemonade v3 piece 6
	[136573199349283] = { { 1.7, 2.3 }, { 5.1, 5.7 }, { 5.8, 6.5 }, { 6.7, 7.5 }, { 11.5, 12.3 } }, -- Lemonade v3 piece 7
	[121733212551700] = { { 3.1, 3.8 } }, -- Lemonade v3 piece 9
	[135684881711516] = { { 2.9, 3.5 } }, -- Lemonade v3 piece 10
	[119706515996739] = { { 2.5, 3.2 } }, -- Lemonade v3 piece 11
	[102178089107461] = { { 0.9, 1.6 }, { 9.2, 10.1 } }, -- Lemonade v3 piece 12
	[112521190266317] = { { 6.6, 7.2 } }, -- Lemonade v3 piece 14
	[108871293297197] = { { 2.5, 3.3 }, { 7.7, 8.4 } }, -- Lemonade v3 piece 18
} :: {[number]: {{number}}}
for id, stretches in pairs(M.ChoreoSlideStill) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	local still = if fix.still == nil then {} elseif fix.still.from then { fix.still } else table.clone(fix.still)
	for _, s in ipairs(stretches) do table.insert(still, { from = s[1], to = s[2] }) end
	fix.still = still
end

-- (D-1771, user 2026-11-18: "안무 원본 영상 보고 점프하는 구간은 오류로 잡지 말고 점프 오히려
-- 살려서 깔끔하게 동작 확정할 것. call my name에 점프 구간 있는데 점프 더 높게") jumps in
-- the video: the capture keeps the feet on the floor, so its hips DROP as the knees
-- tuck (a squat in the game). { from, to, height } = take-off and landing (seconds
-- into the piece, from the video's frames) and the arc's top in studs, added to the
-- capture's own hip height (ChoreoController). The scans must not "fix" these
-- stretches: no `still` / slide fix inside them (tools/choreo/jump_scan.py lists a
-- song's jumps from its centercut tracks). Become ChoreoFixes `jump`.
M.ChoreoJumps = {
	-- 내 이름을 불러줘-TWS: clip 8 0:58.4 tuck jump (capture hips -0.09 → -1.45 → -0.13),
	-- 14 1:32.0 knee-up hop, 16 1:58.2 tuck jump (lands as the clip ends, 1.93 s), 19 2:16.9 tuck jump (lowest -1.74)
	[90921923486342] = { { 0.63, 1.15, 3.0 } }, [137670042338904] = { { 4.22, 4.62, 1.2 } },
	[128327230683798] = { { 1.45, 1.88, 3.6 } }, [122207092339520] = { { 1.82, 2.33, 3.2 } },
	-- (D-1781, user: "모든 안무 점프 구간 확인한 후 수정해") every song's videos scanned
	-- (jump_scan.py over 19 centercut folders + a capture scan of all 576 pieces for
	-- hips that drop 0.6+ and come back within 0.35 s, each candidate checked on frames):
	-- RESCENE-Pretty Girl 20 at 2:27.8 (video 3.95-4.35 in the air, capture hips -0.07 →
	-- -0.74 tuck) and 키키-Pop Off 7 at 0:43.3 (video 7.6-7.85, capture -0.09 → -1.14)
	[90231422396171] = { { 3.95, 4.40, 2.7 } }, [82593368218356] = { { 7.50, 7.92, 3.0 } },
} :: {[number]: {{number}}}
for id, jumps in pairs(M.ChoreoJumps) do
	local fix = (M.ChoreoFixes[id] or {}) :: any
	M.ChoreoFixes[id] = fix
	local list = if fix.jump == nil then {} elseif fix.jump.from then { fix.jump } else table.clone(fix.jump)
	for _, j in ipairs(jumps) do table.insert(list, { from = j[1], to = j[2], height = j[3] }) end
	fix.jump = list
end

-- (D-1794, user 2026-11-18: "체포하겠어 처음에 한쪽 다리로 리듬 타는 거 정확하고 깔끔한 동작으로
-- 구현") 체포하겠어 piece 1, song 2.5-6.0: in the video (XXW_3Bzjd40, mirrored, video = song
-- + 0.52 s by its sound against the stage video) every member stands wide, hands on the
-- hips, and pumps ONE knee on each beat for 8 counts (145.75 bpm, beats at song 2.71 +
-- k x 0.4117; YOLO knee tracks: the screen-right knee goes out 0.1 and up 0.07 torso a
-- beat, the other leg still), heel up. The capture had both knees wobbling 20-37°
-- every keyframe. Now: the legs are set for that stretch: the left leg (screen right
-- on a front-facing avatar, as in the mirrored video) bends forward and out with the
-- heel up 0.03 s after each beat (the animation clock is ~0.09 s late, D-1058) and
-- back 0.24 s later; the right leg stands still; the hips dip 0.06 on each pump.
do
	local ARREST1 = 110040253056586
	local P = 2.38 -- piece seconds = song seconds + 2.38 (its `from`)
	local REST = { LeftUpperLeg = { -3, 2, -12 }, LeftLowerLeg = { -20, -3, -3 }, LeftFoot = { 13, -1, 12 },
		RightUpperLeg = { 0, -6, 17 }, RightLowerLeg = { -20, -1, 2 }, RightFoot = { 8, -1, -15 } }
	local PUMP = { LeftUpperLeg = { 20, 2, -18 }, LeftLowerLeg = { -45, -3, -3 }, LeftFoot = { -6, -1, 12 },
		RightUpperLeg = { 0, -6, 17 }, RightLowerLeg = { -22, -1, 2 }, RightFoot = { 8, -1, -15 } }
	local up, down = { LowerTorso = { 0, -0.06, 0 } }, { LowerTorso = { 0, 0, 0 } }
	local keys = { { t = 2.71 + P - 0.30, set = REST, move = down } }
	for k = 0, 7 do
		local b = 2.71 + k * 0.4117 + P
		table.insert(keys, { t = b + 0.03, set = PUMP, move = up })
		table.insert(keys, { t = b + 0.27, set = REST, move = down })
	end
	local fix = (M.ChoreoFixes[ARREST1] or {}) :: any
	M.ChoreoFixes[ARREST1] = fix
	local list = if fix.pose == nil then {} elseif fix.pose.from then { fix.pose } else table.clone(fix.pose)
	table.insert(list, { from = 2.71 + P - 0.45, to = keys[#keys].t + 0.3, ease = 0.3, keys = keys })
	fix.pose = list
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
	-- (D-2070) AND2BLE-Potion (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames)
	[126577662119324] = -8, [101462515949658] = 8, [120104884356350] = 14, [81060374021567] = 11, [103367592212025] = -18, [87481181692394] = 19,
	[131065498394717] = 17, [72318461434570] = -6, [129776441704888] = -7, -- 3 / 6 / 7 / 8 / 9 / 10 / 16 / 17 / 20
	-- (D-2071) ILLIT-It's Me (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames)
	[92512766209766] = 20, [97821283727781] = -15, [84767858976240] = 29, [81568891729334] = 13, [115153572280504] = -18, [134070700021165] = -13,
	[74249351083442] = 12, [95973678135715] = 12, [127876941649874] = 16, [85806895345522] = -25, [92379882661394] = -8, -- 4 / 6 / 8 / 10 / 11 / 12 / 13 / 14 / 16 / 17 / 19
	-- (D-1672) Unbelievable-H1 KEY (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 11 / 16 checked on frames: front)
	[98575698595382] = 8, [97422868495252] = 10, [77667909738269] = -15, [106947840145982] = 11, [121716323345976] = 11, [85861969329409] = -38, [132406634119258] = 12, -- 2
	-- (D-1670) Boogie Woogie-NCT DREAM (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 16 checked on frames: the capture's
	-- lap stops 40° short; 20 left out: another member covers the centre at 2.3-8.6 s)
	[93564912800713] = 6, [118999861690635] = -9, [137817236071281] = 10, [92147677701072] = 39, [140605792599503] = 7, [138159952468756] = 10,
	-- (D-1603) 내 이름을 불러줘-TWS (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 2 / 3 / 9 / 18 / 19 checked on frames: front)
	[88993457159273] = 24, [74885576782093] = 25, [107391937407645] = -11, [120616516576434] = 8, [73429358232249] = -21,
	[107243018629607] = -8, [100667532281425] = -31, [122207092339520] = -21, [90921923486342] = -11, -- 8 (D-1658, MAD 16)
	-- (D-1394) BANG-After School (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 5, 6 and 10 checked on frames: front)
	[137056236927761] = -10, [105204020323017] = -11, [120933576855785] = 6, [102971667388731] = -21, [103181529138741] = -29,
	[91956738526101] = 10, [71518245203286] = -8, [88337047994676] = -22, [114991184702089] = 11,
	[117412778868520] = 9, [73314859778019] = 6, -- BANG 7 / 16 (D-1399; 11 median 3: none)
	-- (D-1306) With-RESCENE (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 5 and 13 checked on frames: front)
	[102977375863633] = -7, [113905277691263] = -19, [134804041385196] = 8, [135964930726670] = -16, [103924587030311] = -23,
	[119026591853452] = 24, [78971722650566] = 18, [103780560163454] = -8, [119066931308311] = -13, [132556616885642] = 16,
	-- (D-1298) SHOCK-TREASURE (tools/choreo/faceoffset; |median| ≥ 6, MAD ≤ 20, 12+ front frames; 3 checked on frames: front)
	[81779912905543] = -39, [126059214767439] = 11, [112228957264348] = 21, [90553036874786] = -14, [121912364930816] = 12, [112291434709741] = -12,
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
	-- (D-1961) aespa-Lemonade v3 (D-1960): faceoffset per clip (clipfront.py + capyaw, |median| >= 6, MAD <= 20)
	[112046163419694] = -18, -- v3 clip 1
	[121733212551700] = -13, -- v3 clip 8
	[135684881711516] = -12, -- v3 clip 9
	[119706515996739] = -15, -- v3 clip 10
	[112521190266317] = 8, -- v3 clip 13
	[126596392429323] = 10, -- v3 clip 14
	[108871293297197] = 11, -- v3 clip 17
	[102548402613420] = -6, -- v3 clip 19
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
	-- (D-2070) AND2BLE-Potion: head_video.py → headMisses, keys 0.09 s early
	[126577662119324] = { { part = "Head", keys = { { 0.11, 0, 0, 0 }, { 0.31, 0, 0, 13 }, { 0.51, 0, 0, 19 }, { 0.71, 0, 0, 13 }, { 0.91, 0, 0, 0 } } } }, -- PT 3
	[103390008118494] = { { part = "Head", keys = { { 3.71, 0, 0, 0 }, { 3.91, 0, 0, 18 }, { 4.11, 0, 0, 17 }, { 4.31, 0, 0, 0 } } } }, -- PT 4
	[95673249740111] = { { part = "Head", keys = { { 2.51, 0, 0, 0 }, { 2.71, 0, 0, 17 }, { 2.91, 0, 0, 17 }, { 3.11, 0, 0, 14 }, { 3.31, 0, 0, 0 } } } }, -- PT 5
	[81060374021567] = { { part = "Head", keys = { { 4.31, 0, 0, 0 }, { 4.51, 0, 0, 11 }, { 4.71, 0, 0, 12 }, { 4.91, 0, 0, 12 }, { 5.11, 0, 0, 0 } } } }, -- PT 8
	[103367592212025] = { { part = "Head", keys = { { 6.31, 0, 0, 0 }, { 6.51, 0, 0, 10 }, { 6.71, 0, 0, 10 }, { 6.80, 0, 0, 0 } } } }, -- PT 9
	[109105261149494] = { { part = "Head", keys = { { 3.71, 0, 0, 0 }, { 3.91, 0, 0, -16 }, { 4.11, 0, 0, -13 }, { 4.31, 0, 0, 0 } } } }, -- PT 11
	[79447997870020] = { { part = "Head", keys = { { 7.11, 0, 0, 0 }, { 7.31, 0, 0, 11 }, { 7.51, 0, 0, 11 }, { 7.71, 0, 0, 12 }, { 7.91, 0, 0, 0 } } } }, -- PT 13
	[90931443555959] = { { part = "Head", keys = { { 3.31, 0, 0, 0 }, { 3.51, 0, 0, 17 }, { 3.71, 0, 0, 11 }, { 3.91, 0, 0, 0 } } }, { part = "Head", keys = { { 4.51, 0, 0, 0 }, { 4.71, 0, 0, 13 }, { 4.91, 0, 0, 20 }, { 5.11, 0, 0, 0 } } } }, -- PT 14
	[72318461434570] = { { part = "Head", keys = { { 5.51, 0, 0, 0 }, { 5.71, 0, 0, -14 }, { 5.91, 0, 0, -14 }, { 6.11, 0, 0, 0 } } }, { part = "Head", keys = { { 6.51, 0, 0, 0 }, { 6.71, 0, 0, -15 }, { 6.91, 0, 0, -21 }, { 7.11, 0, 0, 0 } } } }, -- PT 17
	[90109383769163] = { { part = "Head", keys = { { 3.91, 0, 0, 0 }, { 4.11, 0, 0, 8 }, { 4.31, 0, 0, 8 }, { 4.51, 0, 0, 0 } } }, { part = "Head", keys = { { 5.11, 0, 0, 0 }, { 5.31, 0, 0, 18 }, { 5.51, 0, 0, 17 }, { 5.71, 0, 0, 20 }, { 5.91, 0, 0, 0 } } } }, -- PT 18
	-- (D-2071) ILLIT-It's Me: head_video.py → headMisses, keys 0.09 s early
	[84810215427749] = { { part = "Head", keys = { { 1.51, 0, 0, 0 }, { 1.71, 0, 0, -10 }, { 1.91, 0, 0, -20 }, { 2.11, 0, 0, 0 } } }, { part = "Head", keys = { { 2.91, 0, 0, 0 }, { 3.11, 0, 0, -14 }, { 3.31, 0, 0, -15 }, { 3.51, 0, 0, 0 } } } }, -- IM 2
	[137374435124337] = { { part = "Head", keys = { { 2.11, 0, 0, 0 }, { 2.31, 0, 0, -18 }, { 2.51, 0, 0, -16 }, { 2.71, 0, 0, 0 } } } }, -- IM 5
	[97821283727781] = { { part = "Head", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, -16 }, { 3.91, 0, 0, -16 }, { 4.11, 0, 0, -17 }, { 4.31, 0, 0, 0 } } } }, -- IM 6
	[104624038900168] = { { part = "Head", keys = { { 4.51, 0, 0, 0 }, { 4.71, 0, 0, 12 }, { 4.91, 0, 0, 12 }, { 5.11, 0, 0, 17 }, { 5.31, 0, 0, 0 } } } }, -- IM 7
	[84767858976240] = { { part = "Head", keys = { { 0.00, 0, 0, 0 }, { 0.11, 0, 0, -19 }, { 0.31, 0, 0, -13 }, { 0.51, 0, 0, 0 } } }, { part = "Head", keys = { { 0.91, 0, 0, 0 }, { 1.11, 0, 0, -19 }, { 1.31, 0, 0, -20 }, { 1.51, 0, 0, 0 } } }, { part = "Head", keys = { { 4.71, 0, 0, 0 }, { 4.91, 0, 0, -23 }, { 5.11, 0, 0, -10 }, { 5.31, 0, 0, -20 }, { 5.51, 0, 0, 0 } } } }, -- IM 8
	[81568891729334] = { { part = "Head", keys = { { 0.11, 0, 0, 0 }, { 0.31, 0, 0, -12 }, { 0.51, 0, 0, -10 }, { 0.71, 0, 0, 0 } } } }, -- IM 10
	[115153572280504] = { { part = "Head", keys = { { 2.91, 0, 0, 0 }, { 3.11, 0, 0, 15 }, { 3.31, 0, 0, 17 }, { 3.51, 0, 0, 0 } } } }, -- IM 11
	[134070700021165] = { { part = "Head", keys = { { 0.31, 0, 0, 0 }, { 0.51, 0, 0, 18 }, { 0.71, 0, 0, 17 }, { 0.91, 0, 0, 0 } } }, { part = "Head", keys = { { 4.11, 0, 0, 0 }, { 4.31, 0, 0, 16 }, { 4.51, 0, 0, 12 }, { 4.71, 0, 0, 0 } } } }, -- IM 12
	[91164599224585] = { { part = "Head", keys = { { 5.71, 0, 0, 0 }, { 5.91, 0, 0, 18 }, { 6.11, 0, 0, 24 }, { 6.31, 0, 0, 0 } } } }, -- IM 15
	[127876941649874] = { { part = "Head", keys = { { 0.00, 0, 0, 25 }, { 0.11, 0, 0, 19 }, { 0.31, 0, 0, 0 } } }, { part = "Head", keys = { { 0.51, 0, 0, 0 }, { 0.71, 0, 0, -13 }, { 0.91, 0, 0, -13 }, { 1.11, 0, 0, -17 }, { 1.31, 0, 0, -12 }, { 1.51, 0, 0, 0 } } }, { part = "Head", keys = { { 5.71, 0, 0, 0 }, { 5.91, 0, 0, -22 }, { 6.11, 0, 0, -16 }, { 6.31, 0, 0, -17 }, { 6.51, 0, 0, 0 } } } }, -- IM 16
	-- (D-1672) Unbelievable-H1 KEY: head_video.py → headMisses, keys 0.09 s early
	[91684619142886] = { { part = "Head", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, -15 }, { 3.91, 0, 0, -16 }, { 4.11, 0, 0, 0 } } } }, -- UB 3
	[110146513928585] = { { part = "Head", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, 20 }, { 3.91, 0, 0, 23 }, { 4.11, 0, 0, 0 } } } }, -- UB 8
	[77667909738269] = { { part = "Head", keys = { { 6.51, 0, 0, 0 }, { 6.71, 0, 0, -14 }, { 6.91, 0, 0, -19 }, { 7.11, 0, 0, 0 } } }, { part = "Head", keys = { { 7.51, 0, 0, 0 }, { 7.71, 0, 0, 29 }, { 7.91, 0, 0, 14 }, { 8.11, 0, 0, 0 } } } }, -- UB 11
	[106947840145982] = { { part = "Head", keys = { { 8.71, 0, 0, 0 }, { 8.91, 0, 0, -16 }, { 9.11, 0, 0, -17 }, { 9.31, 0, 0, -13 }, { 9.51, 0, 0, -13 }, { 9.71, 0, 0, -11 }, { 9.91, 0, 0, 0 } } } }, -- UB 13
	[121716323345976] = { { part = "Head", keys = { { 0.71, 0, 0, 0 }, { 0.91, 0, 0, 10 }, { 1.11, 0, 0, 27 }, { 1.31, 0, 0, 0 } } } }, -- UB 14
	[82151831370082] = { { part = "Head", keys = { { 0.31, 0, 0, 0 }, { 0.51, 0, 0, -15 }, { 0.71, 0, 0, -14 }, { 0.91, 0, 0, -19 }, { 1.11, 0, 0, 0 } } } }, -- UB 15
	[82476096356644] = { { part = "Head", keys = { { 4.51, 0, 0, 0 }, { 4.71, 0, 0, -16 }, { 4.91, 0, 0, -21 }, { 5.11, 0, 0, 0 } } }, { part = "Head", keys = { { 5.51, 0, 0, 0 }, { 5.71, 0, 0, 18 }, { 5.91, 0, 0, 18 }, { 6.11, 0, 0, 0 } } } }, -- UB 5
	-- (D-1671) Boogie Woogie-NCT DREAM 4: head_video.py → headMisses (video 24 / 27°, capture 8 / 3°), keys 0.09 s early
	[136974262670764] = { { part = "Head", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, 12 }, { 3.91, 0, 0, 19 }, { 4.11, 0, 0, 0 } } } }, -- BW 4
	-- (D-1603) 내 이름을 불러줘-TWS: head_video.py → headMisses, keys 0.09 s early
	[88993457159273] = { { part = "Head", keys = { { 0.91, 0, 0, 0 }, { 1.11, 0, 0, -13 }, { 1.31, 0, 0, -16 }, { 1.51, 0, 0, 0 } } } }, -- TWS 2
	[76545761433830] = { { part = "Head", keys = { { 2.31, 0, 0, 0 }, { 2.51, 0, 0, 10 }, { 2.71, 0, 0, 10 }, { 2.91, 0, 0, 0 } } } }, -- TWS 13
	[137670042338904] = { { part = "Head", keys = { { 5.31, 0, 0, 0 }, { 5.51, 0, 0, -15 }, { 5.71, 0, 0, -13 }, { 5.91, 0, 0, -15 }, { 6.11, 0, 0, 0 } } } }, -- TWS 14
	[107246799142521] = { { part = "Head", keys = { { 2.31, 0, 0, 0 }, { 2.51, 0, 0, -17 }, { 2.71, 0, 0, -22 }, { 2.91, 0, 0, 0 } } } }, -- TWS 17
	[100667532281425] = { { part = "Head", keys = { { 1.91, 0, 0, 0 }, { 2.11, 0, 0, -8 }, { 2.31, 0, 0, -14 }, { 2.51, 0, 0, 0 } } } }, -- TWS 18
	-- (D-1394) BANG-After School: head_video.py → headMisses, keys 0.09 s early (13 pieces; 7 / 11 / 16 not uploaded yet)
	[84153374890352] = { { part = "Head", keys = { { 8.51, 0, 0, 0 }, { 8.71, 0, 0, 21 }, { 8.91, 0, 0, 15 }, { 9.11, 0, 0, 0 } } } }, -- BANG 1
	[102971667388731] = { { part = "Head", keys = { { 6.31, 0, 0, 0 }, { 6.51, 0, 0, 19 }, { 6.71, 0, 0, 22 }, { 6.83, 0, 0, 21 } } } }, -- BANG 5 (ends tilted: 6 starts at 21)
	[103181529138741] = { { part = "Head", keys = { { 0.00, 0, 0, 21 }, { 0.11, 0, 0, 19 }, { 0.31, 0, 0, 0 } } }, { part = "Head", keys = { { 5.31, 0, 0, 0 }, { 5.51, 0, 0, 17 }, { 5.71, 0, 0, 17 }, { 5.91, 0, 0, 0 } } } }, -- BANG 6
	[114991184702089] = { { part = "Head", keys = { { 0.71, 0, 0, 0 }, { 0.91, 0, 0, 16 }, { 1.11, 0, 0, 17 }, { 1.31, 0, 0, 19 }, { 1.51, 0, 0, 16 }, { 1.71, 0, 0, 0 } } }, { part = "Head", keys = { { 7.71, 0, 0, 0 }, { 7.91, 0, 0, 13 }, { 8.11, 0, 0, 10 }, { 8.31, 0, 0, 0 } } } }, -- BANG 12
	[129925869461594] = { { part = "Head", keys = { { 8.71, 0, 0, 0 }, { 8.91, 0, 0, 14 }, { 9.11, 0, 0, 13 }, { 9.31, 0, 0, 0 } } } }, -- BANG 14
	-- (D-1306) With-RESCENE + 백화요란 20: head_video.py → headMisses, keys 0.09 s early; left out where the centre is hidden (With 20 at 3 s, 백화요란 20 at 5 s)
	[98274724905693] = { { part = "Head", keys = { { 1.51, 0, 0, 0 }, { 1.71, 0, 0, 18 }, { 1.91, 0, 0, 19 }, { 2.11, 0, 0, 0 } } } }, -- With 2
	[102977375863633] = { { part = "Head", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, 15 }, { 3.91, 0, 0, 11 }, { 4.11, 0, 0, 13 }, { 4.31, 0, 0, 0 } } } }, -- With 4
	[113905277691263] = { { part = "Head", keys = { { 2.51, 0, 0, 0 }, { 2.71, 0, 0, 13 }, { 2.91, 0, 0, 18 }, { 3.11, 0, 0, 21 }, { 3.31, 0, 0, 9 }, { 3.51, 0, 0, 16 }, { 3.71, 0, 0, 18 }, { 3.91, 0, 0, 0 } } } }, -- With 5
	[131580629784808] = { { part = "Head", keys = { { 4.31, 0, 0, 0 }, { 4.51, 0, 0, 18 }, { 4.71, 0, 0, 20 }, { 4.91, 0, 0, 0 } } },
		{ part = "Head", keys = { { 8.11, 0, 0, 0 }, { 8.31, 0, 0, 13 }, { 8.51, 0, 0, 15 }, { 8.71, 0, 0, 30 }, { 8.91, 0, 0, 0 } } } }, -- With 6
	[134804041385196] = { { part = "Head", keys = { { 2.31, 0, 0, 0 }, { 2.51, 0, 0, 12 }, { 2.71, 0, 0, 14 }, { 2.91, 0, 0, 0 } } } }, -- With 8
	[139525834845370] = { { part = "Head", keys = { { 3.31, 0, 0, 0 }, { 3.51, 0, 0, 13 }, { 3.71, 0, 0, 14 }, { 3.91, 0, 0, 11 }, { 4.11, 0, 0, 10 }, { 4.31, 0, 0, 16 }, { 4.51, 0, 0, 0 } } },
		{ part = "Head", keys = { { 8.91, 0, 0, 0 }, { 9.11, 0, 0, 15 }, { 9.31, 0, 0, 16 }, { 9.51, 0, 0, 0 } } } }, -- With 10
	[135964930726670] = { { part = "Head", keys = { { 0.00, 0, 0, 14 }, { 0.11, 0, 0, 11 }, { 0.31, 0, 0, 23 }, { 0.51, 0, 0, 17 }, { 0.71, 0, 0, 0 } } } }, -- With 11
	[75224598365049] = { { part = "Head", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, -13 }, { 3.91, 0, 0, -10 }, { 4.11, 0, 0, 0 } } } }, -- With 15
	[78971722650566] = { { part = "Head", keys = { { 3.71, 0, 0, 0 }, { 3.91, 0, 0, 23 }, { 4.11, 0, 0, 18 }, { 4.31, 0, 0, 0 } } } }, -- With 16
	[123058513001948] = { { part = "Head", keys = { { 0.00, 0, 0, 19 }, { 0.11, 0, 0, 15 }, { 0.31, 0, 0, 0 } } },
		{ part = "Head", keys = { { 0.51, 0, 0, 0 }, { 0.71, 0, 0, 20 }, { 0.91, 0, 0, 21 }, { 1.11, 0, 0, 0 } } },
		{ part = "Head", keys = { { 2.51, 0, 0, 0 }, { 2.71, 0, 0, -15 }, { 2.91, 0, 0, -17 }, { 3.11, 0, 0, -28 }, { 3.31, 0, 0, -20 }, { 3.51, 0, 0, 0 } } },
		{ part = "Head", keys = { { 8.91, 0, 0, 0 }, { 9.11, 0, 0, -19 }, { 9.31, 0, 0, -15 }, { 9.51, 0, 0, -11 }, { 9.71, 0, 0, 0 } } } }, -- With 18
	[75577288501140] = { { part = "Head", keys = { { 2.11, 0, 0, 0 }, { 2.31, 0, 0, 22 }, { 2.51, 0, 0, 18 }, { 2.71, 0, 0, 23 }, { 2.91, 0, 0, 0 } } } }, -- With 24
	[101271170738014] = { { part = "Head", keys = { { 2.31, 0, 0, 0 }, { 2.51, 0, 0, -11 }, { 2.71, 0, 0, -13 }, { 2.91, 0, 0, 0 } } } }, -- 백화요란 20
	-- (D-1298) SHOCK-TREASURE: head_video.py → headMisses, keys 0.09 s early; clip 11 left out (next to a hidden stretch). Wrists: the fancam's hands are too small for the hand model (one 2-sample run, arms crossed), so no wrist bends
	[117322908574417] = { { part = "Head", keys = { { 2.71, 0, 0, 0 }, { 2.91, 0, 0, 13 }, { 3.11, 0, 0, 9 }, { 3.31, 0, 0, 0 } } } }, -- SHOCK 2
	[73160805709614] = { { part = "Head", keys = { { 2.71, 0, 0, 0 }, { 2.91, 0, 0, -19 }, { 3.11, 0, 0, -24 }, { 3.31, 0, 0, 0 } } } }, -- SHOCK 17
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
	-- (D-1961) aespa-Lemonade v3 (D-1960): head_video.py + _G.headMisses (not mirrored)
	[77152170951340] = { { part = "Head", keys = { { 0.00, 0, 0, -13 }, { 0.20, 0, 0, -13 }, { 0.40, 0, 0, 0 } } } }, -- Lemonade v3 2.mp4
	[98395241216132] = { { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 11 }, { 5.00, 0, 0, 9 }, { 5.20, 0, 0, 0 } } }, { part = "Head", keys = { { 5.20, 0, 0, 0 }, { 5.40, 0, 0, 10 }, { 5.60, 0, 0, 14 }, { 5.80, 0, 0, 0 } } }, { part = "Head", keys = { { 6.20, 0, 0, 0 }, { 6.40, 0, 0, 15 }, { 6.60, 0, 0, 22 }, { 6.80, 0, 0, 0 } } } }, -- Lemonade v3 3.mp4
	[105689578186345] = { { part = "Head", keys = { { 5.80, 0, 0, 0 }, { 6.00, 0, 0, 11 }, { 6.20, 0, 0, 9 }, { 6.40, 0, 0, 0 } } } }, -- Lemonade v3 4.mp4
	[103313535582707] = { { part = "Head", keys = { { 10.00, 0, 0, 0 }, { 10.20, 0, 0, 18 }, { 10.40, 0, 0, 19 }, { 10.60, 0, 0, 0 } } }, { part = "Head", keys = { { 13.60, 0, 0, 0 }, { 13.80, 0, 0, 22 }, { 14.00, 0, 0, 27 }, { 14.20, 0, 0, 12 }, { 14.40, 0, 0, 0 } } } }, -- Lemonade v3 5.mp4
	[136573199349283] = { { part = "Head", keys = { { 7.60, 0, 0, 0 }, { 7.80, 0, 0, 15 }, { 8.00, 0, 0, 13 }, { 8.20, 0, 0, 13 }, { 8.40, 0, 0, 11 }, { 8.60, 0, 0, 11 }, { 8.80, 0, 0, 0 } } }, { part = "Head", keys = { { 9.60, 0, 0, 0 }, { 9.80, 0, 0, 20 }, { 10.00, 0, 0, 18 }, { 10.20, 0, 0, 12 }, { 10.40, 0, 0, 0 } } } }, -- Lemonade v3 6.mp4
	[135684881711516] = { { part = "Head", keys = { { 2.20, 0, 0, 0 }, { 2.40, 0, 0, 25 }, { 2.60, 0, 0, 30 }, { 2.80, 0, 0, 19 }, { 3.00, 0, 0, 12 }, { 3.20, 0, 0, 0 } } }, { part = "Head", keys = { { 4.60, 0, 0, 0 }, { 4.80, 0, 0, 18 }, { 5.00, 0, 0, 13 }, { 5.20, 0, 0, 0 } } }, { part = "Head", keys = { { 5.80, 0, 0, 0 }, { 6.00, 0, 0, 20 }, { 6.20, 0, 0, 26 }, { 6.40, 0, 0, 28 }, { 6.60, 0, 0, 0 } } } }, -- Lemonade v3 9.mp4
	[119706515996739] = { { part = "Head", keys = { { 8.00, 0, 0, 0 }, { 8.20, 0, 0, 21 }, { 8.40, 0, 0, 23 }, { 8.60, 0, 0, 23 }, { 8.80, 0, 0, 10 }, { 9.00, 0, 0, 0 } } } }, -- Lemonade v3 10.mp4
	[102178089107461] = { { part = "Head", keys = { { 10.20, 0, 0, 0 }, { 10.40, 0, 0, 13 }, { 10.60, 0, 0, 10 }, { 10.80, 0, 0, 0 } } } }, -- Lemonade v3 11.mp4
	[126596392429323] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, 24 }, { 1.40, 0, 0, 24 }, { 1.60, 0, 0, 18 }, { 1.80, 0, 0, 0 } } } }, -- Lemonade v3 14.mp4
	[106681280470448] = { { part = "Head", keys = { { 7.80, 0, 0, 0 }, { 8.00, 0, 0, -30 }, { 8.20, 0, 0, -28 }, { 8.40, 0, 0, 0 } } } }, -- Lemonade v3 15.mp4
	[79654105377858] = { { part = "Head", keys = { { 1.00, 0, 0, 0 }, { 1.20, 0, 0, 10 }, { 1.40, 0, 0, 12 }, { 1.60, 0, 0, 15 }, { 1.80, 0, 0, 17 }, { 2.00, 0, 0, 19 }, { 2.20, 0, 0, 20 }, { 2.40, 0, 0, 20 }, { 2.60, 0, 0, 17 }, { 2.80, 0, 0, 18 }, { 3.00, 0, 0, 15 }, { 3.20, 0, 0, 0 } } } }, -- Lemonade v3 16.mp4
	[80738708971610] = { { part = "Head", keys = { { 4.00, 0, 0, 0 }, { 4.20, 0, 0, 22 }, { 4.40, 0, 0, 20 }, { 4.60, 0, 0, 13 }, { 4.80, 0, 0, 0 } } }, { part = "Head", keys = { { 5.80, 0, 0, 0 }, { 6.00, 0, 0, 21 }, { 6.20, 0, 0, 21 }, { 6.40, 0, 0, 10 }, { 6.60, 0, 0, 0 } } } }, -- Lemonade v3 18.mp4
	[102548402613420] = { { part = "Head", keys = { { 3.40, 0, 0, 0 }, { 3.60, 0, 0, 26 }, { 3.80, 0, 0, 19 }, { 4.00, 0, 0, 0 } } } }, -- Lemonade v3 19.mp4
} :: {[number]: any}
-- (D-1056, user: "손목도 하고 고개도 해 둘 다 했어야지 다시 해") wrist bends the capture made
-- too small, the same way: the hand (MediaPipe hand landmarker) against the forearm in the
-- practice video (tools/choreo/wrist/hand_video.py: the hand 15+ px and 0.3+ of the forearm,
-- 2+ frames agreeing) against the capture's (head_misses.lua _G.wristMisses). Where the
-- video bends 25+ deg and the capture 20+ deg less the same way, 2+ samples (0.2 s) in a row,
-- the hand turns about whichever of its own x / z axes moves the picture bend most, 0.8 of
-- the gap (at most 40 deg), easing in and out over 0.2 s. Catch Catch: the other hand, z negated
M.ChoreoWristBend = {
	-- (D-2070) AND2BLE-Potion: hand_video.py → wristMisses, keys 0.09 s early
	[130711084322752] = { { part = "RightHand", keys = { { 2.51, 0, 0, 0 }, { 2.71, 0, 0, -40 }, { 2.91, 0, 0, -40 }, { 3.11, 0, 0, 0 } } } }, -- PT 2
	[101462515949658] = { { part = "LeftHand", keys = { { 1.51, 0, 0, 0 }, { 1.71, 9, 0, 0 }, { 1.91, 13, 0, 0 }, { 2.11, 0, 0, 0 } } }, { part = "LeftHand", keys = { { 2.31, 0, 0, 0 }, { 2.51, 13, 0, 0 }, { 2.71, 18, 0, 0 }, { 2.91, 17, 0, 0 }, { 3.11, 0, 0, 0 } } }, { part = "RightHand", keys = { { 4.71, 0, 0, 0 }, { 4.91, 0, 0, -24 }, { 5.11, 0, 0, -32 }, { 5.31, 0, 0, 0 } } } }, -- PT 6
	[120104884356350] = { { part = "LeftHand", keys = { { 3.71, 0, 0, 0 }, { 3.91, 0, 0, 29 }, { 4.11, 0, 0, 40 }, { 4.31, 0, 0, 0 } } } }, -- PT 7
	[103367592212025] = { { part = "LeftHand", keys = { { 1.91, 0, 0, 0 }, { 2.11, 0, 0, 28 }, { 2.31, 0, 0, 24 }, { 2.51, 0, 0, 28 }, { 2.71, 0, 0, 0 } } }, { part = "RightHand", keys = { { 1.91, 0, 0, 0 }, { 2.11, 0, 0, -24 }, { 2.31, 0, 0, -27 }, { 2.51, 0, 0, 0 } } } }, -- PT 9
	[125912203000946] = { { part = "RightHand", keys = { { 0.91, 0, 0, 0 }, { 1.11, 13, 0, 0 }, { 1.31, 20, 0, 0 }, { 1.51, 0, 0, 0 } } } }, -- PT 15
	[131065498394717] = { { part = "LeftHand", keys = { { 2.11, 0, 0, 0 }, { 2.31, 0, 0, 40 }, { 2.51, 0, 0, 40 }, { 2.71, 0, 0, 0 } } } }, -- PT 16
	[72318461434570] = { { part = "LeftHand", keys = { { 4.11, 0, 0, 0 }, { 4.31, 40, 0, 0 }, { 4.51, 19, 0, 0 }, { 4.71, 0, 0, 0 } } } }, -- PT 17
	[90109383769163] = { { part = "LeftHand", keys = { { 1.71, 0, 0, 0 }, { 1.91, -17, 0, 0 }, { 2.11, -28, 0, 0 }, { 2.31, 0, 0, 0 } } }, { part = "LeftHand", keys = { { 4.31, 0, 0, 0 }, { 4.51, 40, 0, 0 }, { 4.71, 39, 0, 0 }, { 4.91, 40, 0, 0 }, { 5.11, 0, 0, 0 } } }, { part = "RightHand", keys = { { 4.91, 0, 0, 0 }, { 5.11, -16, 0, 0 }, { 5.31, -16, 0, 0 }, { 5.51, 0, 0, 0 } } } }, -- PT 18
	-- (D-1672, user: "언벌리버블 안무 추가") Unbelievable-H1 KEY: hand_moves.py → wristMisses, keys 0.09 s early; checked in Play (D-1263)
	[126709034309523] = { { part = "LeftHand", keys = { { 6.11, 0, 0, 0 }, { 6.31, 38, 0, 0 }, { 6.51, 37, 0, 0 }, { 6.71, 0, 0, 0 } } } }, -- UB 7
	[106947840145982] = { { part = "LeftHand", keys = { { 6.51, 0, 0, 0 }, { 6.71, 40, 0, 0 }, { 6.91, 38, 0, 0 }, { 7.11, 40, 0, 0 }, { 7.31, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 12.11, 0, 0, 0 }, { 12.31, 29, 0, 0 }, { 12.51, 20, 0, 0 }, { 12.71, 0, 0, 0 } } } }, -- UB 13
	[121716323345976] = { { part = "LeftHand", keys = { { 9.11, 0, 0, 0 }, { 9.31, 0, 0, -25 }, { 9.51, 0, 0, -27 }, { 9.71, 0, 0, -30 }, { 9.91, 0, 0, -40 }, { 10.11, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 9.11, 0, 0, 0 }, { 9.31, -40, 0, 0 }, { 9.51, -34, 0, 0 }, { 9.71, -35, 0, 0 }, { 9.91, -40, 0, 0 }, { 10.11, 0, 0, 0 } } } }, -- UB 14
	[85861969329409] = { { part = "RightHand", keys = { { 8.11, 0, 0, 0 }, { 8.31, 0, 0, 33 }, { 8.51, 0, 0, 38 }, { 8.71, 0, 0, 23 }, { 8.91, 0, 0, 30 }, { 9.11, 0, 0, 32 }, { 9.31, 0, 0, 33 }, { 9.51, 0, 0, 32 }, { 9.71, 0, 0, 32 }, { 9.91, 0, 0, 0 } } } }, -- UB 16 (sign flipped: in Play the computed -z bend went the wrong way, D-1263)
	[132406634119258] = { { part = "LeftHand", keys = { { 7.11, 0, 0, 0 }, { 7.31, 0, 0, -30 }, { 7.51, 0, 0, -24 }, { 7.71, 0, 0, -31 }, { 7.91, 0, 0, -40 }, { 8.11, 0, 0, 0 } } } }, -- UB 2
	-- (D-1670, user: "boogiewoogie") Boogie Woogie-NCT DREAM: hand_moves.py → wristMisses, keys 0.09 s early; 20 left out (another member covers the
	-- centre), 24's run is after the song end; checked in Play (D-1263)
	[98798684410312] = { { part = "LeftHand", keys = { { 2.71, 0, 0, 0 }, { 2.91, -28, 0, 0 }, { 3.11, -33, 0, 0 }, { 3.31, -36, 0, 0 }, { 3.51, -36, 0, 0 }, { 3.71, -37, 0, 0 }, { 3.91, 0, 0, 0 } } } }, -- BW 3
	[138159952468756] = { { part = "RightHand", keys = { { 4.71, 0, 0, 0 }, { 4.91, 0, 0, 40 }, { 5.11, 0, 0, 35 }, { 5.31, 0, 0, 0 } } } }, -- BW 21
	[70911274448112] = { { part = "LeftHand", keys = { { 0.31, 0, 0, 0 }, { 0.51, 22, 0, 0 }, { 0.71, 35, 0, 0 }, { 0.91, 39, 0, 0 }, { 1.11, 0, 0, 0 } } } }, -- BW 9 (D-1671; video 61-78, capture 16-24)
	-- (D-1603, user: "내 이름을 불러 줘 안무 추가") 내 이름을 불러줘-TWS: hand_moves.py on 19 clips → wristMisses, keys 0.09 s early; checked in Play (D-1263)
	[73429358232249] = { { part = "LeftHand", keys = { { 2.11, 0, 0, 0 }, { 2.31, 0, 0, -19 }, { 2.51, 0, 0, -20 }, { 2.71, 0, 0, -26 }, { 2.91, 0, 0, 0 } } } }, -- TWS 9
	[107243018629607] = { { part = "LeftHand", keys = { { 1.11, 0, 0, 0 }, { 1.31, 27, 0, 0 }, { 1.51, 40, 0, 0 }, { 1.71, 25, 0, 0 }, { 1.91, 24, 0, 0 }, { 2.11, 0, 0, 0 } } } }, -- TWS 12
	[122207092339520] = { { part = "LeftHand", keys = { { 11.71, 0, 0, 0 }, { 11.91, 0, 0, -20 }, { 12.11, 0, 0, -33 }, { 12.31, 0, 0, 0 } } } }, -- TWS 19
	-- (D-1394, user: "애프터스쿨 BANG 안무 추가") BANG-After School: hand_moves.py on all 16 clips → wristMisses, keys 0.09 s early;
	-- clip 12 0-3.3 s left out (another dancer next to the centre); checked in Play (D-1263)
	[102971667388731] = { { part = "RightHand", keys = { { 2.31, 0, 0, 0 }, { 2.51, 0, 0, -23 }, { 2.71, 0, 0, -22 }, { 2.91, 0, 0, -17 }, { 3.11, 0, 0, -40 }, { 3.31, 0, 0, 0 } } } }, -- BANG 5
	[91956738526101] = { { part = "LeftHand", keys = { { 7.71, 0, 0, 0 }, { 7.91, 0, 0, -28 }, { 8.11, 0, 0, -27 }, { 8.31, 0, 0, -29 }, { 8.51, 0, 0, 0 } } } }, -- BANG 8
	[71518245203286] = { { part = "LeftHand", keys = { { 0.11, 0, 0, 0 }, { 0.31, 0, 0, -35 }, { 0.51, 0, 0, -40 }, { 0.71, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 2.11, 0, 0, 0 }, { 2.31, 23, 0, 0 }, { 2.51, 19, 0, 0 }, { 2.71, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 3.71, 0, 0, 0 }, { 3.91, 37, 0, 0 }, { 4.11, 24, 0, 0 }, { 4.31, 0, 0, 0 } } } }, -- BANG 9
	[88337047994676] = { { part = "RightHand", keys = { { 1.11, 0, 0, 0 }, { 1.31, -20, 0, 0 }, { 1.51, -18, 0, 0 }, { 1.71, -19, 0, 0 }, { 1.91, -22, 0, 0 }, { 2.11, 0, 0, 0 } } } }, -- BANG 10
	[114991184702089] = { { part = "LeftHand", keys = { { 3.71, 0, 0, 0 }, { 3.91, -21, 0, 0 }, { 4.11, -22, 0, 0 }, { 4.31, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 10.51, 0, 0, 0 }, { 10.71, 0, 0, -37 }, { 10.91, 0, 0, -12 }, { 11.11, 0, 0, -28 }, { 11.31, 0, 0, -40 }, { 11.51, 0, 0, -40 }, { 11.71, 0, 0, 0 } } } }, -- BANG 12
	[73314859778019] = { { part = "RightHand", keys = { { 1.31, 0, 0, 0 }, { 1.51, 0, 0, -28 }, { 1.71, 0, 0, -29 }, { 1.91, 0, 0, 0 } } } }, -- BANG 16 (D-1399; 7 / 11: no 2-sample runs, 11's are where the centre is hidden)
	-- (D-1306, user: "원본 동영상과 비교하면서 고개와 손목 움직임 세세한 부분까지") With-RESCENE: hand_moves.py on 25 clips → wristMisses, keys 0.09 s early,
	-- capture wrist + bend ≤ 72°; left out where the centre is hidden (7 at 4.8 s, 14 at 0.5 s, 24) and 25 (after the song ends). Play
	-- (D-1263): all 8 turn the hand toward the video (capture → game, video: 4 −26 → −42/−55 (−60/−67), 13 −18 → 0 (+30), 16 +14 → −20 (−50),
	-- 17 −34 → +9 (+82), 21 −30 → −61 (−70..−94))
	[102977375863633] = { { part = "LeftHand", keys = { { 5.11, 0, 0, 0 }, { 5.31, 22, 0, 0 }, { 5.51, 31, 0, 0 }, { 5.71, 0, 0, 0 } } },
		{ part = "LeftHand", keys = { { 6.91, 0, 0, 0 }, { 7.11, 0, 0, 40 }, { 7.31, 0, 0, 40 }, { 7.51, 0, 0, 40 }, { 7.71, 0, 0, 40 }, { 7.91, 0, 0, 0 } } } }, -- With 4
	[113905277691263] = { { part = "RightHand", keys = { { 3.51, 0, 0, 0 }, { 3.71, -28, 0, 0 }, { 3.91, -33, 0, 0 }, { 4.11, 0, 0, 0 } } } }, -- With 5
	[119026591853452] = { { part = "RightHand", keys = { { 4.31, 0, 0, 0 }, { 4.51, 40, 0, 0 }, { 4.71, 40, 0, 0 }, { 4.91, 40, 0, 0 }, { 5.11, 0, 0, 0 } } } }, -- With 13
	[78971722650566] = { { part = "RightHand", keys = { { 10.71, 0, 0, 0 }, { 10.91, -40, 0, 0 }, { 11.11, -40, 0, 0 }, { 11.31, -34, 0, 0 }, { 11.51, 0, 0, 0 } } } }, -- With 16
	[102753426349246] = { { part = "RightHand", keys = { { 3.31, 0, 0, 0 }, { 3.51, 0, 0, -40 }, { 3.71, 0, 0, -40 }, { 3.91, 0, 0, 0 } } },
		{ part = "RightHand", keys = { { 4.71, 0, 0, 0 }, { 4.91, 0, 0, -40 }, { 5.11, 0, 0, -40 }, { 5.31, 0, 0, 0 } } } }, -- With 17
	[123058513001948] = { { part = "RightHand", keys = { { 3.51, 0, 0, 0 }, { 3.71, 0, 0, -40 }, { 3.91, 0, 0, -40 }, { 4.11, 0, 0, 0 } } } }, -- With 18
	[103780560163454] = { { part = "RightHand", keys = { { 4.31, 0, 0, 0 }, { 4.51, 36, 0, 0 }, { 4.71, 40, 0, 0 }, { 4.91, 34, 0, 0 }, { 5.11, 34, 0, 0 }, { 5.31, 36, 0, 0 }, { 5.51, 0, 0, 0 } } } }, -- With 21
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
	-- (D-1961) aespa-Lemonade v3 (D-1960): hand_video.py + _G.wristMisses (not mirrored)
	[104433202165131] = { { part = "RightHand", keys = { { 3.20, 0, 0, 0 }, { 3.40, 18, 0, 0 }, { 3.60, 25, 0, 0 }, { 3.80, 0, 0, 0 } } } }, -- Lemonade v3 7.mp4
	[79654105377858] = { { part = "LeftHand", keys = { { 1.40, 0, 0, 0 }, { 1.60, -31, 0, 0 }, { 1.80, -33, 0, 0 }, { 2.00, -37, 0, 0 }, { 2.20, 0, 0, 0 } } } }, -- Lemonade v3 16.mp4
} :: {[number]: any}
for _, tbl in ipairs({ M.ChoreoHeadTilt, M.ChoreoWristBend }) do
	for id, list in pairs(tbl) do
		local fix = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = fix
		fix.bend = fix.bend or {}
		for _, b in ipairs(list) do table.insert(fix.bend, b) end
	end
end

-- (D-1850, user 2026-11-19 list for 내 이름을 불러줘-TWS, play-bar times = song seconds: the track's rate is
-- 1.0001) wrists, hops, the turns at 0:16 and 1:16, the front at 0:17-0:19 and the kneel at 2:00. Times are put
-- where Play shows the arm in question up (song second ± the arm); wrist sets are absolute (in = palm toward
-- the forearm: left z +45 / right z -45; out = left -55 / right +55; straight = 0), so the capture's own bend
-- does not add up. Piece seconds = song - `at` (piece 1: song + 1.25).
do
	local function fx(id: number): any
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		return f
	end
	local function addPose(id: number, window: any)
		local f = fx(id)
		local list = if f.pose == nil then {} elseif f.pose.from then { f.pose } else table.clone(f.pose)
		table.insert(list, window)
		f.pose = list
	end
	local function addBend(id: number, part: string, keys: any)
		local f = fx(id)
		f.bend = f.bend or {}
		table.insert(f.bend, { part = part, keys = keys })
	end
	local function addList(id: number, key: string, item: any)
		local f = fx(id)
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	local IN = { LeftHand = { 0, 0, 45 }, RightHand = { 0, 0, -45 } }
	local OUT = { LeftHand = { 0, 0, -55 }, RightHand = { 0, 0, 55 } }
	-- one hand (or both) held at a set from t0 to t1, eased in / out over 0.15 s
	local function wrist(id: number, t0: number, t1: number, set: any)
		addPose(id, { from = t0 - 0.15, to = t1 + 0.15, ease = 0.15, keys = { { t = t0, set = set }, { t = t1, set = set } } })
	end
	local BEAT = 0.3614 -- (83 bpm counted in halves: the practice video's beats)
	local P2, P7, P8, P9, P13, P14, P15 = 88993457159273, 120616516576434, 90921923486342, 73429358232249, 76545761433830, 137670042338904, 81624243507898
	local P16, P17, P18, P20 = 128327230683798, 107246799142521, 100667532281425, 96319765244846
	-- 0:53 왼손 안쪽 / 0:54 오른손 안쪽 / 0:55 손목 일자로 / 0:56 왼손 밖으로 (P7 at 50.74: the left hand up at 52.8-53.0,
	-- the right at 53.8-54.1, both out front 55.1-55.9, the left up at 56.1)
	wrist(P7, 2.06, 2.66, { LeftHand = IN.LeftHand })
	wrist(P7, 3.01, 3.51, { RightHand = IN.RightHand })
	wrist(P7, 4.31, 5.0, { LeftHand = { 0, 0, 0 }, RightHand = { 0, 0, 0 } })
	wrist(P7, 5.42, 5.7, { LeftHand = OUT.LeftHand })
	-- 0:58 오른손 / 1:01 왼손 반바퀴씩 좌우로 (P8 at 57.74: the right hand out 57.9-59.0, the left up 60.8-61.9)
	addBend(P8, "RightHand", wristTwinkle(0.21, 1.31, BEAT, 80))
	addBend(P8, "LeftHand", wristTwinkle(3.06, 4.16, BEAT, 80))
	-- 1:05 왼손 안쪽 (the left hand comes up at 65.6-66.4)
	wrist(P8, 7.86, 8.6, { LeftHand = IN.LeftHand })
	-- 1:27 오른손 두 바퀴 (P13 at 81.77: the right arm up 87.5-88.3)
	addBend(P13, "RightHand", wristCircles(5.63, 6.63, 0.5, 35))
	-- 1:39 왼손 / 1:40 오른손 안쪽 (P14 at 87.74 to its end at 100.44, P15 at 100.52)
	wrist(P14, 11.21, 11.86, { LeftHand = IN.LeftHand })
	wrist(P14, 12.46, 12.75, { RightHand = IN.RightHand })
	wrist(P15, -0.1, 0.35, { RightHand = IN.RightHand })
	-- 1:52 왼손 / 1:53 오른손 안쪽 (P15: the left hand in front 111.9-112.6, the right 113.0-113.6)
	wrist(P15, 11.38, 12.08, { LeftHand = IN.LeftHand })
	wrist(P15, 12.48, 13.08, { RightHand = IN.RightHand })
	-- 1:59 손목 안으로 꺾었다가 밖으로 (P17 at 116.73: the right arm up 118.5-119.4)
	addPose(P17, { from = 1.67, to = 2.82, ease = 0.15, keys = { { t = 1.82, set = { RightHand = IN.RightHand } }, { t = 2.12, set = { RightHand = IN.RightHand } },
		{ t = 2.32, set = { RightHand = OUT.RightHand } }, { t = 2.67, set = { RightHand = OUT.RightHand } } } })
	-- 2:00 무릎 꿇고 앉아 있을 때 움직임 잡기 (the kneel 120.3-121.5: hips -2.5 under the root, wobbling 0.3)
	fx(P17).steady = { from = 3.5, to = 4.85, passes = 8 }
	addList(P17, "still", { from = 3.5, to = 4.85 })
	-- 2:06 양쪽 손목 안으로 (P18 at 124.74: both hands up at the face 125.8-126.3)
	wrist(P18, 1.01, 1.56, { LeftHand = IN.LeftHand, RightHand = IN.RightHand })
	-- 2:32 오른손 / 2:33 왼손 반바퀴씩 좌우로 (P20 at 148.5: the right arm up 151.8-153.0, the left 153.3-154.3)
	addBend(P20, "RightHand", wristTwinkle(3.3, 4.5, BEAT, 80))
	addBend(P20, "LeftHand", wristTwinkle(4.8, 5.8, BEAT, 80))
	-- 0:14-0:15 다리 한쪽씩 점프, 바꿀 때 둘 다 떠 있게 (P2 at 11.76: a small hop on each beat 14.48 / 14.84 / 15.20 / 15.56)
	-- and the jump kick at 0:18.5 (the video is in the air 18.45-18.7)
	local hops = {}
	for k = 0, 3 do table.insert(hops, { 2.72 + k * BEAT - 0.12, 2.72 + k * BEAT + 0.12, 0.7 }) end
	table.insert(hops, { 6.62, 6.98, 1.4 })
	M.ChoreoJumps[P2] = hops -- (listed for jump_scan / docs; the loop above has run, so added here too)
	for _, j in ipairs(hops) do addList(P2, "jump", { from = j[1], to = j[2], height = j[3] }) end
	-- 0:17-0:19 앞만 보기: after the turn (done at 17.31 to the front) the hips face the front to 19.3; the piece's
	-- faceOffset (+24) turns them after, so the set is -24
	addPose(P2, { from = 5.55, to = 7.6, ease = 0.25, keys = { { t = 5.55, set = { LowerTorso = { 0, -24, 0 } } }, { t = 7.55, set = { LowerTorso = { 0, -24, 0 } } } } })

	-- (D-1850) poses the capture missed, arm angles solved on the avatar's own joints in Play (hand centre to a point
	-- in UpperTorso space, then the hand turned to the finger / palm direction): the video frames at each time
	local P1, P6 = 84847937406843, 107391937407645
	local function arm(side: string, a: any): any
		return { [side .. "UpperArm"] = a[1], [side .. "LowerArm"] = a[2], [side .. "Hand"] = a[3] }
	end
	local function both(l: any, r: any): any
		local t = table.clone(l)
		for k, v in pairs(r) do t[k] = v end
		return t
	end
	local HANG_R, HANG_L = { { 0, 0, 8 }, { 10, 0, 0 }, { 0, 0, 0 } }, { { 0, 0, -8 }, { 10, 0, 0 }, { 0, 0, 0 } }
	-- 0:07 손바닥끼리 맞대는데 손목 부분 맞대고 손끝은 서로 반대로 (video 7.35-7.85: the heels of the hands together in
	-- front of the chest, the right fingers up, the left down; P1 piece time = song + 1.25)
	local palms = both(arm("Right", { { -45, 2, 150 }, { 91, 0, 0 }, { 40, 30, 90 } }), arm("Left", { { -46, -61, -75 }, { 106, 0, 0 }, { -90, 80, 10 } }))
	addPose(P1, { from = 8.25, to = 9.45, ease = 0.35, keys = { { t = 8.6, set = palms }, { t = 9.1, set = palms } } })
	addList(P1, "guardOff", { from = 8.25, to = 9.45 })
	-- 0:08-0:09 오른손 오른쪽 어깨 위 → 내리면서 왼손 왼쪽 어깨 위 (video 8.7-9.0 right, 9.1-9.6 left)
	local shR = arm("Right", { { -6, 42, 0 }, { 158, 0, 0 }, { 20, 0, -90 } })
	local shL = arm("Left", { { -7, -44, 0 }, { 159, 0, 0 }, { 20, 0, 90 } })
	addPose(P1, { from = 9.5, to = 11.15, ease = 0.3, keys = { { t = 9.8, set = shR }, { t = 10.15, set = shR },
		{ t = 10.45, set = both(shL, arm("Right", HANG_R)) }, { t = 10.85, set = both(shL, arm("Right", HANG_R)) } } })
	addList(P1, "guardOff", { from = 9.5, to = 11.15 })
	-- 0:12 오른팔 쭉 뻗고 왼손에 오른 손바닥 (video 12.7-13.3: the right arm straight out front-right, palm down on the
	-- left hand under it; P2 at 11.76)
	local onHand = both(arm("Right", { { -105, -78, 150 }, { 0, 0, 0 }, { 0, -90, -20 } }), arm("Left", { { -89, 3, 165 }, { 0, 0, 0 }, { 0, -90, 0 } }))
	addPose(P2, { from = 0.55, to = 1.85, ease = 0.3, keys = { { t = 0.9, set = onHand }, { t = 1.5, set = onHand } } })
	addList(P2, "guardOff", { from = 0.55, to = 1.85 })
	-- 0:47 / 1:45 오른손 바닥 짚기: bent at the waist, knees bent, the right arm hanging straight down to the floor (the floor
	-- lift keeps the hand on it) and back up (0:47 = video 48.2-48.6, P6 at 41.26; 1:45 = the game's reach down 104.5-105.0,
	-- P15 at 100.52)
	local down = { UpperTorso = { -50, 0, 0 }, LowerTorso = { -25, 0, 0 } }
	local crouch = both(both(arm("Right", { { 75, 0, 5 }, { 10, 0, 0 }, { 0, 0, 0 } }), {
		LeftUpperLeg = { 50, 0, -8 }, LeftLowerLeg = { -75, 0, 0 }, LeftFoot = { 25, 0, 0 },
		RightUpperLeg = { 50, 0, 8 }, RightLowerLeg = { -75, 0, 0 }, RightFoot = { 25, 0, 0 } }), {})
	local function floorTouch(id: number, t0: number, drop: number)
		addPose(id, { from = t0 - 0.1, to = t0 + 1.35, ease = 0.3, keys = {
			{ t = t0, add = { UpperTorso = { 0, 0, 0 }, LowerTorso = { 0, 0, 0 } }, move = { LowerTorso = { 0, 0, 0 } } },
			{ t = t0 + 0.4, set = crouch, add = down, move = { LowerTorso = { 0, -drop, 0 } } },
			{ t = t0 + 0.8, set = crouch, add = down, move = { LowerTorso = { 0, -drop, 0 } } },
			{ t = t0 + 1.2, add = { UpperTorso = { 0, 0, 0 }, LowerTorso = { 0, 0, 0 } }, move = { LowerTorso = { 0, 0, 0 } } } } })
	end
	-- (the drop is deeper than needed: the floor lift brings the lowest part, the hand, back onto the floor, so it
	-- lands on any body; 1.1 left a default test avatar's hand 1.1 over the floor)
	-- (D-1855: 0:48 is now a bend on planted legs, plantBend below)
	-- (D-1864: no reach down at 1:45 any more: the practice video stands there and raises both arms over the head at
	-- 105.2-105.6; its one floor touch is at 106.0-106.4, which the capture already has. pose_text compare + sheets)
	-- 1:07 왼손 꽃받침처럼 대고 볼 터치, 1:08 손목 밖으로 (video 68.2-69.2: crouched, the left hand cupping the cheek;
	-- P9 at 66.75)
	local cheek = { { 3, -58, -74 }, { 129, 0, 0 }, { 90, -30, -90 } }
	local cheekOut = { { 3, -58, -74 }, { 129, 0, 0 }, { 90, -30, -120 } }
	addList(P9, "guardOff", { from = 0.6, to = 2.9 })
	addPose(P9, { from = 0.6, to = 2.9, ease = 0.3, keys = { { t = 0.95, set = arm("Left", cheek) }, { t = 1.8, set = arm("Left", cheek) },
		{ t = 2.1, set = arm("Left", cheekOut) }, { t = 2.55, set = arm("Left", cheekOut) } } })
	-- 1:29 양손 손등 맞대기 (in front of the belly, fingers down; P14 at 87.74: song 89.0-89.9)
	local backs = both(arm("Right", { { -29, 60, 42 }, { 89, 0, 0 }, { -90, 90, 0 } }), arm("Left", { { -29, -60, -42 }, { 89, 0, 0 }, { -90, -90, 0 } }))
	addPose(P14, { from = 0.95, to = 2.5, ease = 0.3, keys = { { t = 1.3, set = backs }, { t = 2.15, set = backs } } })
	addList(P14, "guardOff", { from = 0.95, to = 2.5 })
	-- 2:09 오른팔 돌리면서 올리기 (a circle on the shoulder while the capture raises it, song 129.0-129.6), 2:10 쭉 뻗기
	-- (the elbow straight, 129.6-130.3), then 손끝끼리 맞닿게 (130.4-131.8: the hands in front of the chest, fingertips
	-- together; P18 at 124.74)
	addBend(P18, "RightUpperArm", wristCircles(4.26, 4.86, 0.6, 30))
	addPose(P18, { from = 4.75, to = 5.55, ease = 0.15, keys = { { t = 4.9, set = { RightLowerArm = { 0, 0, 0 } } }, { t = 5.4, set = { RightLowerArm = { 0, 0, 0 } } } } })
	local tips = both(arm("Right", { { -27, 35, 75 }, { 88, 0, 0 }, { 40, -50, -20 } }), arm("Left", { { -26, -35, -75 }, { 87, 0, 0 }, { 40, 50, 20 } }))
	addPose(P18, { from = 5.6, to = 7.3, ease = 0.3, keys = { { t = 5.9, set = tips }, { t = 6.95, set = tips } } })
	addList(P18, "guardOff", { from = 5.6, to = 7.3 })
	-- 2:14 허리 제대로 숙이기, 왼팔은 등 뒤로, 오른팔 앞으로 아래로 축 떨어뜨리고 천천히 올라옴 (video 134.4-135.2 bent,
	-- up by 135.9)
	local bentArms = both(arm("Left", { { -73, -47, -3 }, { 71, 0, 0 }, { 80, -40, 70 } }), arm("Right", { { 80, 0, 5 }, { 5, 0, 0 }, { 0, 0, 0 } }))
	addList(P18, "guardOff", { from = 9.45, to = 11.55, side = "Left" })
	addPose(P18, { from = 9.45, to = 11.55, ease = 0.25, keys = {
		{ t = 9.6, add = { UpperTorso = { 0, 0, 0 } } },
		-- (D-1855: the hips and legs are held where they stand, so the whole bend is the waist's, set)
		{ t = 9.9, set = both(bentArms, { UpperTorso = { -65, 0, 0 }, RightUpperArm = { 60, 0, -20 } }) },
		{ t = 10.45, set = both(bentArms, { UpperTorso = { -65, 0, 0 }, RightUpperArm = { 60, 0, -20 } }) },
		{ t = 11.3, set = both(arm("Left", { { -73, -47, -3 }, { 71, 0, 0 }, { 80, -40, 70 } }), arm("Right", { { 15, 0, 5 }, { 10, 0, 0 }, { 0, 0, 0 } })),
			add = { UpperTorso = { 0, 0, 0 }, LowerTorso = { 0, 0, 0 } } } } })
	-- 2:37 오른 무릎 꿇고 왼 무릎 세운 채 고정, 고개 숙였다가 천천히 들면서 끝: the capture already kneels that way (right
	-- shin on the floor, left foot planted) from song 156.2; held from 157.8 (freeze, the head free) to the song's end
	-- (ClubPlaylist slowOut stretches the last 0.3 s over 4.8 s), the head down and slowly up
	fx(P20).freeze = { from = 9.3, to = 99, ease = 0.4, except = { "Head" } }
	addList(P20, "still", { from = 9.3, to = 99 })
	addPose(P20, { from = 9.2, to = 99, ease = 0.3, keys = { { t = 9.4, set = { Head = { -35, 10, 0 } } }, { t = 10.6, set = { Head = { -30, 10, 0 } } },
		{ t = 11.95, set = { Head = { 35, 10, 0 } } } } })
end

-- (D-1851, user 2026-11-19 list for Boogie Woogie-NCT DREAM, play-bar = song seconds: the rate is 0.9999) first batch,
-- 0:00-0:30, from the fancam (video = song + 3.85) and Play: piece seconds = song - `at` (piece 1: song + 3.85)
do
	local function fx(id: number): any
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		return f
	end
	local function addPose(id: number, window: any)
		local f = fx(id)
		local list = if f.pose == nil then {} elseif f.pose.from then { f.pose } else table.clone(f.pose)
		table.insert(list, window)
		f.pose = list
	end
	local function addBend(id: number, part: string, keys: any)
		local f = fx(id)
		f.bend = f.bend or {}
		table.insert(f.bend, { part = part, keys = keys })
	end
	local function arm(side: string, a: any): any
		return { [side .. "UpperArm"] = a[1], [side .. "LowerArm"] = a[2], [side .. "Hand"] = a[3] }
	end
	local function both(l: any, r: any): any
		local t = table.clone(l)
		for k, v in pairs(r) do t[k] = v end
		return t
	end
	-- a wrist flicking z between +amp and -amp every `half` s (in / out, 털기)
	local function flick(t0: number, t1: number, half: number, amp: number): any
		local keys, t, sign = { { t0, 0, 0, 0 } }, t0 + half * 0.5, 1
		while t <= t1 - half * 0.5 do
			table.insert(keys, { t, 0, 0, sign * amp })
			t += half
			sign = -sign
		end
		table.insert(keys, { t, 0, 0, 0 })
		return keys
	end
	-- both shoulders up and down on each `half` s (어깨 들썩)
	local function shrug(t0: number, t1: number, half: number, up: number): any
		local keys, t, hi = {}, t0, true
		while t <= t1 + 1e-6 do
			local y = if hi then up else 0
			table.insert(keys, { t = t, move = { LeftUpperArm = { 0, y, 0 }, RightUpperArm = { 0, y, 0 } } })
			t += half
			hi = not hi
		end
		return { from = t0 - 0.1, to = t + 0.05, ease = 0.1, keys = keys }
	end
	local BEAT = 0.5173 -- (115.98 bpm, the fancam's beats)
	local P1, P2, P3, P4, P5 = 74991796424913, 72899900258037, 98798684410312, 136974262670764, 97814419171643
	-- 시작할 때 허리 앞으로 제대로 숙이기 (video 0.2-1.6: bent deep, hands on the knees; the capture only ~50°)
	addPose(P1, { from = 3.55, to = 5.85, ease = 0.3, keys = { { t = 3.95, add = { UpperTorso = { -25, 0, 0 } } }, { t = 5.35, add = { UpperTorso = { -25, 0, 0 } } } } })
	-- 0:01 오른손 뻗으면 오른 손목 안팎으로 (the right arm out 2.0-3.0)
	addBend(P1, "RightHand", flick(5.85, 6.85, BEAT / 2, 40))
	-- 0:04 고개 우로 한 번 좌로 한 번 (P2 at 3.62)
	addBend(P2, "Head", { { 0.4, 0, 0, 0 }, { 0.65, 0, 0, -25 }, { 0.9, 0, 0, 0 }, { 1.15, 0, 0, 25 }, { 1.4, 0, 0, 0 } })
	-- 0:08 팔꿈치 더 접기 (video 7.6-9.0: fists at the hips, elbows bent)
	addPose(P2, { from = 4.25, to = 5.45, ease = 0.2, keys = { { t = 4.5, add = { LeftLowerArm = { 45, 0, 0 }, RightLowerArm = { 45, 0, 0 } } },
		{ t = 5.2, add = { LeftLowerArm = { 45, 0, 0 }, RightLowerArm = { 45, 0, 0 } } } } })
	-- 0:10 걸어갈 때 어깨 위아래로 (song 10.0-11.4)
	addPose(P2, shrug(6.4, 7.8, BEAT / 2, 0.22))
	-- 0:14 왼손 안쪽 (P3 at 11.33: the left hand up 14.0-14.8)
	addPose(P3, { from = 2.6, to = 3.6, ease = 0.15, keys = { { t = 2.75, set = { LeftHand = { 0, 0, 45 } } }, { t = 3.45, set = { LeftHand = { 0, 0, 45 } } } } })
	-- 0:15-0:16 진짜 앞으로 걸어가기: the slide holds on P3 (3.7-4.4, 5.0-5.9) lifted above
	-- 0:17-0:18 어깨 위아래로 (P3 to its end at 17.64, then P4)
	addPose(P3, shrug(5.5, 6.25, BEAT / 2, 0.22))
	addPose(P4, shrug(0.05, 0.65, BEAT / 2, 0.22))
	-- 0:24 손바닥끼리 비비기 (video 24.4-24.8: palms together in front of the chest, rubbing up and down; P4 at 17.64)
	local rubA = both(arm("Right", { { 31, 64, 16 }, { 88, 0, 0 }, { 20, 20, 60 } }), arm("Left", { { -60, -65, -120 }, { 85, 0, 0 }, { 30, -10, -90 } }))
	local rubB = both(arm("Right", { { -60, 65, 120 }, { 85, 0, 0 }, { 30, 10, 90 } }), arm("Left", { { 31, -64, -16 }, { 88, 0, 0 }, { 20, -20, -60 } }))
	local rub = {}
	for k = 0, 5 do table.insert(rub, { t = 6.6 + k * 0.13, set = if k % 2 == 0 then rubA else rubB }) end
	addPose(P4, { from = 6.3, to = 7.6, ease = 0.3, keys = rub })
	fx(P4).guardOff = { { from = 6.3, to = 7.6 }, { from = 9.1, to = 9.95 } }
	-- (Play: the capture swings 72° out and back at 24.1-24.7, 655°/s; the video faces the front) one even facing
	fx(P4).spin = { from = 6.2, to = 7.1, ease = "both" }
	-- 0:25 양손 좌우로 반바퀴씩 (video 25.0-25.8: both hands up at the sides)
	addBend(P4, "LeftHand", wristTwinkle(7.4, 8.3, BEAT / 2, 80))
	addBend(P4, "RightHand", wristTwinkle(7.4, 8.3, BEAT / 2, 80))
	-- 0:27 손바닥끼리 부딪히기 (video 27.0-27.3: one clap low in front)
	local clap = both(arm("Right", { { 15, 77, 15 }, { 58, 0, 0 }, { 50, -20, 90 } }), arm("Left", { { 15, -77, -15 }, { 58, 0, 0 }, { 50, 20, -90 } }))
	addPose(P4, { from = 9.1, to = 9.95, ease = 0.2, keys = { { t = 9.4, set = clap }, { t = 9.6, set = clap } } })
	-- 0:30 왼손 좌우로 털기 (P5 at 27.51: the left hand out 30.0-30.9)
	addBend(P5, "LeftHand", flick(2.49, 3.39, 0.13, 35))
	-- (D-1851) second batch, 0:42-1:28
	local P6, P7, P8, P9, P10 = 92946970770352, 93564912800713, 118999861690635, 70911274448112, 72126724441612
	local function addList(id: number, key: string, item: any)
		local f = fx(id)
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	-- the upper body turned left / right on every beat (팔 좌우로 크게 흔들기)
	local function sway(t0: number, t1: number, deg: number): any
		local keys, t, s = { { t = t0, add = { UpperTorso = { 0, 0, 0 } } } }, t0 + BEAT / 2, 1
		while t <= t1 do
			table.insert(keys, { t = t, add = { UpperTorso = { 0, s * deg, 0 } } })
			t += BEAT
			s = -s
		end
		return { from = t0 - 0.1, to = t + 0.1, ease = 0.2, keys = keys }
	end
	-- 0:42 왼손 오른팔 위로, 다리 그 자리에 고정, 어깨만 왼쪽으로 (P6 at 40.96, song 41.6-43.9: bent over)
	local onArm = arm("Left", { { 16, -61, -15 }, { 69, 0, 0 }, { 30, -60, 10 } })
	addPose(P6, { from = 0.5, to = 3.1, ease = 0.3, keys = { { t = 0.9, set = onArm, add = { UpperTorso = { 0, 0, 0 } } },
		{ t = 2.6, set = onArm, add = { UpperTorso = { 0, 0, 18 } } } } })
	fx(P6).freeze = { from = 0.6, to = 3.0, ease = 0.3, except = { "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } }
	addList(P6, "still", { from = 0.6, to = 3.0 })
	addList(P6, "guardOff", { from = 0.5, to = 3.1, side = "Left" })
	-- 0:46 ㄴ 팔 좌우로 크게 / 0:47 어깨 들썩들썩 / 0:49 ㄴ 팔 좌우로 / 0:50 오른 손목 한 바퀴
	addPose(P6, sway(5.1, 6.2, 30))
	addPose(P6, shrug(6.3, 7.4, BEAT / 2, 0.22))
	addPose(P6, sway(7.85, 9.0, 25))
	addBend(P6, "RightHand", wristCircles(9.24, 10.14, 0.9, 35))
	-- 0:54 양팔 ㄴ (P7 at 51.37) / 0:55 X자 / 0:56 오른팔 ㄴ + 왼팔 배 앞 ㄴ
	local posts = both(arm("Right", { { 58, 1, 72 }, { 106, 0, 0 }, { -10, 10, 30 } }), arm("Left", { { 58, -1, -72 }, { 106, 0, 0 }, { -10, -10, -30 } }))
	local cross = both(arm("Right", { { 71, 77, -13 }, { 76, 0, 0 }, { -60, 40, 90 } }), arm("Left", { { 94, -78, 30 }, { 61, 0, 0 }, { -50, -40, -90 } }))
	local postBelly = both(arm("Right", { { 58, 1, 72 }, { 106, 0, 0 }, { -10, 10, 30 } }), arm("Left", { { -74, -76, -104 }, { 78, 0, 0 }, { 20, 30, 0 } }))
	addPose(P7, { from = 2.45, to = 3.45, ease = 0.2, keys = { { t = 2.65, set = posts }, { t = 3.2, set = posts } } })
	addPose(P7, { from = 3.75, to = 4.55, ease = 0.2, keys = { { t = 4.0, set = cross }, { t = 4.35, set = cross } } })
	addPose(P7, { from = 4.6, to = 5.4, ease = 0.2, keys = { { t = 4.75, set = postBelly }, { t = 5.2, set = postBelly } } })
	addList(P7, "guardOff", { from = 3.75, to = 5.4 })
	-- 0:57 점프 (song 57.0-57.35)
	addList(P7, "jump", { from = 5.63, to = 5.98, height = 1.2 })
	-- 1:01 걸어가는 스텝: the slide hold 9.3-10.4 on P7 lifted (ChoreoSlideStill)
	-- 1:02 왼팔 쭉 뻗어서 회전 (the elbow straight 62.0-63.2, over the P7 / P8 seam)
	addPose(P7, { from = 10.5, to = 11.5, ease = 0.2, keys = { { t = 10.7, set = { LeftLowerArm = { 0, 0, 0 } } }, { t = 11.4, set = { LeftLowerArm = { 0, 0, 0 } } } } })
	addPose(P8, { from = -0.3, to = 0.7, ease = 0.2, keys = { { t = 0, set = { LeftLowerArm = { 0, 0, 0 } } }, { t = 0.5, set = { LeftLowerArm = { 0, 0, 0 } } } } })
	-- 1:04 팔 두 바퀴 돌리기, 팔을 더 옆으로 (P8 at 62.68: song 63.6-65.4)
	addPose(P8, { from = 0.8, to = 2.85, ease = 0.3, keys = { { t = 1.1, add = { LeftUpperArm = { 0, 0, -25 }, RightUpperArm = { 0, 0, 25 } } },
		{ t = 2.55, add = { LeftUpperArm = { 0, 0, -25 }, RightUpperArm = { 0, 0, 25 } } } } })
	-- 1:10 허벅지는 거의 그대로, 종아리만 앞으로 걸어감 + 오른손 탈탈 (song 69.8-71.4: P8 to 70.42, then P9)
	addList(P8, "amp", { from = 7.1, to = 7.8, ease = 0.2, parts = { LeftUpperLeg = 0.5, RightUpperLeg = 0.5 } })
	addList(P9, "amp", { from = 0, to = 1.0, ease = 0.2, parts = { LeftUpperLeg = 0.5, RightUpperLeg = 0.5 } })
	addBend(P8, "RightHand", flick(7.1, 7.75, 0.13, 35))
	addBend(P9, "RightHand", flick(0.0, 1.0, 0.13, 35))
	-- 1:13 점프 (song 73.0-73.4, P9 at 70.42)
	-- (D-1858, user: "1:13 점프 원본에 있는 건지 확인": yes, a small hop with a right-leg kick, in the air at 72.85-73.15) 0.15 s earlier, lower
	addList(P9, "jump", { from = 2.43, to = 2.78, height = 0.9 })
	-- 1:16-1:18 양팔 ㄴ에서 좌우로 빨리 두 번씩 털기, 박자마다 (song 75.9-78.0)
	local shake = {}
	-- (D-1855, user: "1:15쯤 상체 좌우로 흔드는 거 한박자 빠름. 앞에 좌우로 흔드는 것만 없애기") the shakes start a beat later (76.44)
	local tb = 5.5 + BEAT
	-- (D-1858, user: "스프링마냥 너무 빨리 흔들어. 슬로우 걸어서 춤추는 것처럼") was 3 flicks in 0.24 s a beat; now one sway a
	-- half beat (left on the beat, right on the and), eased, through 76.44-78.0
	table.insert(shake, { tb - BEAT / 4, 0, 0, 0 })
	local side = 1
	while tb < 7.45 do
		table.insert(shake, { tb, 0, 0, 13 * side })
		side = -side
		tb += BEAT / 2
	end
	table.insert(shake, { tb, 0, 0, 0 })
	addBend(P9, "UpperTorso", shake)
	-- 1:21 양손 반바퀴씩 (P10 at 79.67) / 1:25 양쪽 손목 밖으로 / 1:26 가슴 튕기기 / 1:26-1:28 개다리 춤
	addBend(P10, "LeftHand", wristTwinkle(1.23, 2.23, BEAT / 2, 80))
	addBend(P10, "RightHand", wristTwinkle(1.23, 2.23, BEAT / 2, 80))
	addPose(P10, { from = 4.98, to = 5.98, ease = 0.15, keys = { { t = 5.13, set = { LeftHand = { 0, 0, -55 }, RightHand = { 0, 0, 55 } } }, { t = 5.83, set = { LeftHand = { 0, 0, -55 }, RightHand = { 0, 0, 55 } } } } })
	fx(P10).pops = { at = { 6.35, 6.87 }, sizes = { 1.4, 1.4 }, push = 0.5, lift = 0.2, arch = 9, out = 0.05, back = 0.35 }
	local kneesOut = { LeftUpperLeg = { 30, 30, -12 }, LeftLowerLeg = { -50, 0, 0 }, LeftFoot = { 20, 0, 0 }, RightUpperLeg = { 30, -30, 12 }, RightLowerLeg = { -50, 0, 0 }, RightFoot = { 20, 0, 0 } }
	local kneesIn = { LeftUpperLeg = { 30, -25, 6 }, LeftLowerLeg = { -50, 0, 0 }, LeftFoot = { 20, 0, 0 }, RightUpperLeg = { 30, 25, -6 }, RightLowerLeg = { -50, 0, 0 }, RightFoot = { 20, 0, 0 } }
	local gd = {}
	for k = 0, 8 do table.insert(gd, { t = 6.6 + k * BEAT / 2, set = if k % 2 == 0 then kneesOut else kneesIn, move = { LowerTorso = { 0, -0.4, 0 } } }) end
	addPose(P10, { from = 6.4, to = 8.9, ease = 0.2, keys = gd })
	-- (D-1851) third batch, 1:32-2:20
	local P11, P12, P13, P14, P15, P18 = 103506023234554, 137817236071281, 138409186362070, 98549161772624, 77759369454741, 82489608576953
	local DOWN_R, DOWN_L = { { 0, 0, 8 }, { 10, 0, 0 }, { 0, 0, 0 } }, { { 0, 0, -8 }, { 10, 0, 0 }, { 0, 0, 0 } }
	local UP_R, UP_L = { { 0, 0, 165 }, { 10, 0, 0 }, { 0, 0, 0 } }, { { 0, 0, -165 }, { 10, 0, 0 }, { 0, 0, 0 } }
	-- 1:32 양팔 번갈아 머리 위까지 (P11 at 88.54: song 91.6-93.6, one arm a beat)
	local alt = {}
	for k = 0, 3 do
		local rightUp = k % 2 == 0
		table.insert(alt, { t = 3.1 + k * BEAT, set = both(arm("Right", if rightUp then UP_R else DOWN_R), arm("Left", if rightUp then DOWN_L else UP_L)) })
	end
	addPose(P11, { from = 2.85, to = 5.0, ease = 0.25, keys = alt })
	-- 1:43-1:44 오른손으로 정수리 콕 → 코 콕 → 가슴팍 콕, 내리기 (P12 at 97.65: song 103.0-104.4; fingertip on each)
	local crown = arm("Right", { { 142, -2, -31 }, { 112, 0, 0 }, { -90, 40, -50 } })
	local nose = arm("Right", { { 86, 62, 2 }, { 79, 0, 0 }, { 90, 0, 0 } })
	local chest = arm("Right", { { 28, 61, 34 }, { 92, 0, 0 }, { 90, 0, -20 } })
	addPose(P12, { from = 5.15, to = 6.8, ease = 0.25, keys = { { t = 5.45, set = crown }, { t = 5.6, set = crown }, { t = 5.9, set = nose }, { t = 6.05, set = nose },
		{ t = 6.3, set = chest }, { t = 6.45, set = chest } } })
	addList(P12, "guardOff", { from = 5.15, to = 6.8, side = "Right" })
	-- 1:48 손가락으로 화면 삿대질 (P13 at 105.09: the right hand forward, song 107.8-108.3): the wrist jabs
	addBend(P13, "RightHand", { { 2.7, 0, 0, 0 }, { 2.8, -30, 0, 0 }, { 2.93, 0, 0, 0 }, { 3.06, -30, 0, 0 }, { 3.2, 0, 0, 0 } })
	-- 1:49-1:50 오른손 손목으로 머리 통통 (song 108.7-110.0)
	addPose(P13, { from = 3.45, to = 5.05, ease = 0.25, keys = { { t = 3.7, set = arm("Right", { { 105, 60, 48 }, { 77, 0, 0 }, { 10, -70, -30 } }) },
		{ t = 4.8, set = arm("Right", { { 105, 60, 48 }, { 77, 0, 0 }, { 10, -70, -30 } }) } } })
	addBend(P13, "RightHand", { { 3.75, 0, 0, 0 }, { 3.9, 30, 0, 0 }, { 4.05, 0, 0, 0 }, { 4.2, 30, 0, 0 }, { 4.35, 0, 0, 0 }, { 4.5, 30, 0, 0 }, { 4.65, 0, 0, 0 } })
	addList(P13, "guardOff", { from = 3.45, to = 5.05, side = "Right" })
	-- 1:51-1:52 손목 안으로 살짝 + 팔 머리 위로 돌리기 (song 110.6-112.0)
	addPose(P13, { from = 5.4, to = 7.0, ease = 0.2, keys = { { t = 5.55, set = { RightHand = { 0, 0, -25 } } }, { t = 6.85, set = { RightHand = { 0, 0, -25 } } } } })
	addBend(P13, "RightUpperArm", wristCircles(5.55, 6.85, 0.65, 25))
	-- 1:52-1:53 버벅거림 (the facing swings 24 → -31 → 16 and the arms flail at 112.0-113.3): one even facing, calmed
	fx(P13).spin = { from = 6.5, to = 7.7, ease = "both" }
	fx(P13).steady = { from = 6.9, to = 7.75, passes = 8 }
	-- 1:55 오른손은 왼팔 위팔에, 왼손은 오른팔 위팔에 (교차; P14 at 112.83, song 114.9-115.6)
	local fold = both(arm("Right", { { -151, 59, -131 }, { 75, 0, 0 }, { 30, -70, 40 } }), arm("Left", { { 149, -62, 90 }, { 63, 0, 0 }, { 0, 60, 0 } }))
	addPose(P14, { from = 1.9, to = 2.95, ease = 0.3, keys = { { t = 2.2, set = fold }, { t = 2.65, set = fold } } })
	addList(P14, "guardOff", { from = 1.9, to = 2.95 })
	-- 1:58 팔꿈치 몸에 붙이고 주먹 위아래 크게 + 몸도 위아래 (song 117.6-118.8)
	local fUp = both(arm("Right", { { -2, 15, 0 }, { 129, 0, 0 }, { 0, 0, 0 } }), arm("Left", { { -2, -15, 0 }, { 129, 0, 0 }, { 0, 0, 0 } }))
	local fDn = both(arm("Right", { { -26, 19, 12 }, { 87, 0, 0 }, { 0, 0, 0 } }), arm("Left", { { -26, -19, -12 }, { 87, 0, 0 }, { 0, 0, 0 } }))
	local fists = {}
	for k = 0, 4 do table.insert(fists, { t = 4.85 + k * BEAT / 2, set = if k % 2 == 0 then fUp else fDn, move = { LowerTorso = { 0, if k % 2 == 0 then 0 else -0.3, 0 } } }) end
	addPose(P14, { from = 4.65, to = 6.05, ease = 0.2, keys = fists })
	-- 2:00 양팔 양옆으로 벌릴 때 한 번에 깔끔하게 (song 119.6-120.6: the arms calmed) / 2:01 팔 쭉 뻗고 크게 휘두르기
	fx(P14).steady = { from = 6.6, to = 7.9, passes = 8, parts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } }
	addList(P14, "amp", { from = 7.9, to = 8.4, ease = 0.15, parts = { LeftUpperArm = 1.5, RightUpperArm = 1.5 } })
	addList(P15, "amp", { from = 0, to = 0.75, ease = 0.2, parts = { LeftUpperArm = 1.5, RightUpperArm = 1.5 } })
	addPose(P15, { from = -0.2, to = 0.8, ease = 0.2, keys = { { t = 0.05, set = { LeftLowerArm = { 5, 0, 0 }, RightLowerArm = { 5, 0, 0 } } }, { t = 0.6, set = { LeftLowerArm = { 5, 0, 0 }, RightLowerArm = { 5, 0, 0 } } } } })
	-- 2:04 양쪽 팔 좌우로 더 크게 (P15 at 121.14: song 123.6-124.6)
	addList(P15, "amp", { from = 2.45, to = 3.45, ease = 0.2, parts = { LeftUpperArm = 1.5, RightUpperArm = 1.5 } })
	-- 2:05 오른팔 ㄱ, 왼팔 ㄴ, 이어서 반대로 (song 124.6-125.6)
	local gR, nR = { { -99, -18, 82 }, { 105, 0, 0 }, { 0, 0, 0 } }, { { 73, -16, 72 }, { 105, 0, 0 }, { 0, 0, 0 } }
	local gL, nL = { { -99, 18, -82 }, { 105, 0, 0 }, { 0, 0, 0 } }, { { 73, 16, -72 }, { 105, 0, 0 }, { 0, 0, 0 } }
	addPose(P15, { from = 3.35, to = 4.55, ease = 0.15, keys = { { t = 3.5, set = arm("Right", gR) }, { t = 3.75, set = both(arm("Right", gR), arm("Left", nL)) },
		{ t = 4.05, set = both(arm("Right", nR), arm("Left", gL)) }, { t = 4.35, set = both(arm("Right", gR), arm("Left", nL)) } } })
	-- 2:06 개다리 + 양손 손바닥으로 가슴 치기 (song 125.6-126.8)
	local patIn = both(arm("Right", { { -32, 51, 53 }, { 140, 0, 0 }, { 0, 0, 0 } }), arm("Left", { { -32, -51, -53 }, { 140, 0, 0 }, { 0, 0, 0 } }))
	local patOut = both(arm("Right", { { -32, 51, 53 }, { 110, 0, 0 }, { 0, 0, 0 } }), arm("Left", { { -32, -51, -53 }, { 110, 0, 0 }, { 0, 0, 0 } }))
	local gd2 = {}
	for k = 0, 4 do table.insert(gd2, { t = 4.6 + k * BEAT / 2, set = both(if k % 2 == 0 then kneesOut else kneesIn, if k % 2 == 0 then patIn else patOut), move = { LowerTorso = { 0, -0.4, 0 } } }) end
	addPose(P15, { from = 4.6, to = 5.8, ease = 0.2, keys = gd2 })
	addList(P15, "guardOff", { from = 4.6, to = 5.8 })
	-- 2:19 오른쪽 발꿈치 들었다 놨다 크게, 박자 (P18 at 137.69: song 138.8-139.8)
	local heel = {}
	for k = 0, 4 do
		local up = k % 2 == 1
		table.insert(heel, { t = 1.1 + k * BEAT / 2, add = { RightFoot = { if up then -30 else 0, 0, 0 }, RightLowerLeg = { if up then -20 else 0, 0, 0 }, RightUpperLeg = { if up then 10 else 0, 0, 0 } } })
	end
	addPose(P18, { from = 1.0, to = 2.3, ease = 0.15, keys = heel })
	-- 2:20 오른손 좌우로 흔들기 (song 139.8-140.8)
	addBend(P18, "RightHand", flick(2.1, 3.1, BEAT / 2, 35))
	-- (D-1851) fourth batch, 2:15-3:05
	local P17, P19, P20, P21, P22, P23, P24 = 90031774217033, 140605792599503, 130987200839765, 138159952468756, 79114246750826, 81117884846850, 123702153844970
	-- 2:15 왼팔 옆으로 뻗고 오른팔 접어 당기며 왼발 벌림 → 오른팔 내리며 왼발꿈치 내밀고 그 각도로 회전, 반복
	-- (P17 at 133.52: song 134.9-137.6, a beat each)
	local stepA = { LeftUpperArm = { 0, 0, -90 }, LeftLowerArm = { 0, 0, 0 }, RightUpperArm = { 20, 60, 40 }, RightLowerArm = { 130, 0, 0 },
		LeftUpperLeg = { 0, 0, -25 }, LeftLowerLeg = { -5, 0, 0 }, LeftFoot = { 0, 0, 0 } }
	local stepB = { LeftUpperArm = { 0, 0, -90 }, LeftLowerArm = { 0, 0, 0 }, RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 },
		LeftUpperLeg = { 25, 0, -10 }, LeftLowerLeg = { -5, 0, 0 }, LeftFoot = { 30, 0, 0 } }
	local steps = {}
	for k = 0, 4 do
		local a = k % 2 == 0
		table.insert(steps, { t = 1.38 + k * BEAT, set = if a then stepA else stepB, add = { UpperTorso = { 0, if a then 0 else -25, 0 } } })
	end
	addPose(P17, { from = 1.15, to = 3.95, ease = 0.25, keys = steps })
	-- 2:27 정면으로 바뀔 때: 한 바퀴 돌고 걸어나오기 (P19 at 147.13; its slide holds lifted)
	fx(P19).spin = { from = 0, to = 1.5, fromPrev = true, dir = -1, ease = "both" }
	-- 2:32 벌벌 떪 (the right arm out 151.3-152.9)
	addList(P19, "steady", { from = 4.15, to = 5.85, passes = 8 })
	-- 2:34 오른 손목 한 바퀴 (P20 at 153.71)
	addBend(P20, "RightHand", wristCircles(0.2, 1.0, 0.8, 35))
	-- 2:40-2:43 오른손 귀에, 어깨 좌우 크게 흔들며 허리 숙였다 폄; 팔꿈치 몸에 붙인 왼팔 아래팔 좌우로; 고개 뒤 봤다가 앞
	-- (song 160.0-163.0 = P20 6.3-9.3; the fancam is covered here, so as the user wrote it)
	local ear = arm("Right", { { 41, 66, 75 }, { 156, 0, 0 }, { -20, -30, 90 } })
	local ek = {}
	for k = 0, 10 do
		local s = if k % 2 == 0 then 1 else -1
		local bend = if k >= 3 and k <= 6 then -30 else 0
		local look = if k >= 7 and k <= 8 then 70 else 0
		table.insert(ek, { t = 6.4 + k * BEAT / 2, set = both(ear, { LeftUpperArm = { -10, 0, -12 }, LeftLowerArm = { 90, s * 35, 0 } }),
			add = { UpperTorso = { bend, 0, s * 15 }, Head = { 0, look, 0 } } })
	end
	addPose(P20, { from = 6.2, to = 9.3, ease = 0.3, keys = ek })
	addList(P20, "guardOff", { from = 6.2, to = 9.3, side = "Right" })
	-- 2:43 점프하면서 양쪽 팔꿈치 찍기 (P21 at 162.65: video in the air 163.3-163.6)
	addList(P21, "jump", { from = 0.6, to = 1.0, height = 1.4 })
	addPose(P21, { from = 0.85, to = 1.6, ease = 0.15, keys = { { t = 1.0, set = fUp }, { t = 1.35, set = fUp } } })
	-- 2:45 양손으로 얼굴 가리며 허리 숙이기 (song 165.4-166.2)
	local face = both(arm("Right", { { 27, 77, 61 }, { 126, 0, 0 }, { 60, -10, 90 } }), arm("Left", { { 27, -77, -61 }, { 126, 0, 0 }, { 60, 10, -90 } }))
	addPose(P21, { from = 2.6, to = 3.75, ease = 0.25, keys = { { t = 2.85, set = face, add = { UpperTorso = { -20, 0, 0 } } }, { t = 3.5, set = face, add = { UpperTorso = { -20, 0, 0 } } } } })
	addList(P21, "guardOff", { from = 2.6, to = 3.75 })
	-- 2:48 양손 모으고 상체 좌우로 크게 (song 168.2-169.0) / 2:49 양손 털기 (169.0-169.8)
	local clasp = both(arm("Right", { { -31, 75, 60 }, { 107, 0, 0 }, { 10, 0, 80 } }), arm("Left", { { -31, -75, -60 }, { 107, 0, 0 }, { 10, 0, -80 } }))
	local cs = {}
	for k = 0, 3 do table.insert(cs, { t = 5.6 + k * BEAT / 2, set = clasp, add = { UpperTorso = { 0, 0, if k % 2 == 0 then 20 else -20 } } }) end
	addPose(P21, { from = 5.4, to = 6.4, ease = 0.2, keys = cs })
	addList(P21, "guardOff", { from = 5.4, to = 6.4 })
	addBend(P21, "LeftHand", flick(6.4, 7.15, 0.13, 35))
	addBend(P21, "RightHand", flick(6.4, 7.15, 0.13, 35))
	-- 2:51 팔 ㄱ 직각으로 팔꿈치 확실히 벌림, 허리 더 숙임, 발끝 바깥으로 (P22 at 171.26: song 171.0-172.2)
	local wide = both(both(arm("Right", gR), arm("Left", gL)), { LeftUpperLeg = { 0, 25, -8 }, RightUpperLeg = { 0, -25, 8 }, LeftFoot = { 0, 20, 0 }, RightFoot = { 0, -20, 0 } })
	-- (D-1855, user "2:51 발 땅에 붙이고 다리 고정하고 상체만 숙이기") to 1.75 (the capture bends to 172.9) with the waist set
	-- on the held legs (freeze below)
	addPose(P22, { from = -0.35, to = 1.75, ease = 0.2, keys = { { t = -0.15, set = wide, add = { UpperTorso = { -25, 0, 0 } } }, { t = 0.25, set = wide, add = { UpperTorso = { -25, 0, 0 } } },
		{ t = 0.6, set = both(wide, { UpperTorso = { -60, 0, 0 } }), add = { UpperTorso = { 0, 0, 0 } } }, { t = 1.45, set = both(wide, { UpperTorso = { -60, 0, 0 } }), add = { UpperTorso = { 0, 0, 0 } } } } })
	-- 3:00 다리 일자로 쭉 뻗으며 성큼성큼 원 그리며 걷기 (P23 at 174.93: song 179.8-182.4; the capture walks the circle)
	addList(P23, "amp", { from = 4.8, to = 7.5, ease = 0.3, parts = { LeftLowerLeg = 0.3, RightLowerLeg = 0.3, LeftUpperLeg = 1.3, RightUpperLeg = 1.3 } })
	-- 3:05 양팔 들고 손목 안으로 두세 번 (P24 at 185.81: the arms up 185.7-186.6)
	addBend(P24, "LeftHand", { { 0.0, 0, 0, 0 }, { 0.15, 0, 0, 45 }, { 0.3, 0, 0, 0 }, { 0.45, 0, 0, 45 }, { 0.6, 0, 0, 0 }, { 0.75, 0, 0, 45 }, { 0.9, 0, 0, 0 } })
	addBend(P24, "RightHand", { { 0.0, 0, 0, 0 }, { 0.15, 0, 0, -45 }, { 0.3, 0, 0, 0 }, { 0.45, 0, 0, -45 }, { 0.6, 0, 0, 0 }, { 0.75, 0, 0, -45 }, { 0.9, 0, 0, 0 } })
end

-- (D-1852, user 2026-11-19: "언빌리버블 떨림 많음 … 소원을 말해봐 3:20 같은 동작 팔 반만 … 3:32 무릎 꿇고 벌벌 … 갑자기 0:10 엄청
-- 떨어 … 1:16 무릎 꿇고 많이 떰 … 2:49 팔 버벅 … 2:57 오른팔 튀어나감 … with 0:10 떨림, 2:55 누워 버리네") what Play shows on
-- this game's own dancer (joint turn-backs > 1.2° a frame, 5+ in 0.5 s; hips up / down 7 times in 0.5 s; single-frame
-- jumps), steadied / held / made bigger where it shows; piece seconds from the playing track in Play
do
	local function fx(id: number): any
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		return f
	end
	local function addList(id: number, key: string, item: any)
		local f = fx(id)
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	local ARM_R = { "RightUpperArm", "RightLowerArm", "RightHand" }
	local ARM_L = { "LeftUpperArm", "LeftLowerArm", "LeftHand" }
	local ARMS = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
	-- Unbelievable: the hands that still shake (Play, 0:00-2:15: 1:40 right, 1:50 left, 1:56 left, 2:00-2:01 right, 2:12 left)
	addList(106947840145982, "steady", { from = 9.6, to = 10.4, passes = 8, parts = ARM_R })
	addList(121716323345976, "steady", { from = 4.8, to = 5.8, passes = 8, parts = ARM_L })
	addList(82151831370082, "steady", { from = 0.2, to = 1.0, passes = 8, parts = ARM_L })
	addList(82151831370082, "steady", { from = 4.9, to = 6.4, passes = 8, parts = ARM_R })
	addList(85861969329409, "steady", { from = 10.1, to = 10.9, passes = 8, parts = ARM_L })
	-- 소원을 말해봐 3:20: the move at 3:21 is done again at 3:22 with the arms half as far (right hand to 0.5 against 0.8):
	-- that second one 1.8x (piece 115574620758490 at 201.47)
	addList(115574620758490, "amp", { from = 0.25, to = 1.05, ease = 0.2, parts = { LeftUpperArm = 1.8, RightUpperArm = 1.8, LeftLowerArm = 1.4, RightLowerArm = 1.4 } })
	-- 소원을 말해봐 3:32 무릎 꿇고 고정: the last piece (127828014236660 at 210.31) held from its kneel to the song's end, head free
	fx(127828014236660).freeze = { from = 1.8, to = 99, ease = 0.4, except = { "Head" } }
	-- 갑자기 1:16 무릎 꿇고 앉았을 때 고정 (piece 104001486192661 at 74.7: the hips drop to -1.6 at 76.8-78.4 and bob 7 times in 0.5 s
	-- at 78.0): legs and hips held, the upper body calmed
	fx(104001486192661).freeze = { from = 2.2, to = 3.75, ease = 0.3, except = { "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } }
	addList(104001486192661, "still", { from = 2.2, to = 3.75 })
	addList(104001486192661, "steady", { from = 2.2, to = 3.75, passes = 8, parts = { "UpperTorso", "Head" } })
	-- 갑자기 2:49 팔 버벅 → 한 동작 (piece 92331354114542 at 166.7: the arms flail 168.3-169.6)
	addList(92331354114542, "steady", { from = 1.4, to = 3.1, passes = 8, parts = ARMS })
	-- 갑자기 2:57 오른팔 튀어나감 (piece 82782712192367 at 172.7: hands 42 studs/s in one frame at 178.3, the right 32 at 179.05)
	addList(82782712192367, "steady", { from = 5.3, to = 6.6, passes = 6, parts = ARMS })
	-- With 0:10 떨림 (piece 77578453879056 at 8.2, 0.4-2.1) and the right hand dropping 0.63 in one frame at 13.67 (piece 102977375863633)
	addList(77578453879056, "steady", { from = 0.4, to = 2.1, passes = 8 })
	addList(102977375863633, "steady", { from = 2.85, to = 3.6, passes = 8, parts = ARM_R })
	-- (D-1854, user + screenshot: "With 2:36 누워 버림") piece 97670698889704 (at 151.0) rolls on the floor at song 156.0-157.0
	-- (the torso upside down, up -0.2): in the original the centre (white dress) kneels upright there while the dancers behind
	-- go down; the upright kneel at its 4.75 is held to its end
	fx(97670698889704).freeze = { from = 4.75, to = 7, ease = 0.3 }
	addList(97670698889704, "still", { from = 4.75, to = 7 })
	-- (D-1855, user: "가만히만 있어서 어색함. 뒤에 이어지는 안무로 슬로우 걸어서 연결") the next piece (103780560163454 at 156.95)
	-- starts 2.0 s early (20 stops at 154.95) and plays its first 0.5 s (the rise with the arm out) over 2.5 s: ClubPlaylist slowIn; the rise is then at 155.9-157.1 as in the video
	-- (D-1854, user's screen recording: 갑자기 0:08-0:12 the hand at the chin shivers) piece 140529283375287 (at 8.5): the
	-- hands at the face / chest touch the head and body bounds, so the body guard stays off there and the arms are calmed
	addList(140529283375287, "guardOff", { from = 0, to = 4.0 })
	addList(140529283375287, "steady", { from = 0, to = 4.0, passes = 8, parts = ARMS })
	-- (D-1855, user: "갑자기 0:11~0:12 몸이 가만히 있지 않는데") the original: arms crossed, one hand at the chin, standing
	-- still 11.0-12.4 (piece 2.5-3.9): the whole body held
	fx(140529283375287).freeze = { from = 2.55, to = 3.9, ease = 0.3 }
	-- (D-1855, user: "내이름을불러줘 0:48 다리 발 바닥에 붙은 상태로 고정하고 상체만 숙여. 오른팔은 땅과 직각으로 / 2:14 여기도 /
	-- boogie woogie 2:51 발 땅에 붙이고 다리 고정하고 상체만 숙이기") the hips and legs are held from where the bend begins
	-- (feet and knees where they stand), the waist bends forward (UpperTorso set, R15: x - = forward) and the right arm
	-- hangs straight down to the floor (shoulder forward by the bend, elbow straight)
	local UPPER = { "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
	-- (poseTo: the bend lets go then instead of at t1, while the legs stay held to t1)
	local function plantBend(id: number, t0: number, down: number, up: number, t1: number, deg: number?, extra: any?, poseTo: number?)
		addList(id, "freeze", { from = t0, to = t1, ease = 0.3, except = UPPER })
		if deg then
			local set = { UpperTorso = { -deg, 0, 0 }, RightUpperArm = { deg - 12, 0, -32 }, RightLowerArm = { 0, 0, 0 } }
			for k, v in pairs(extra or {}) do set[k] = v end
			addList(id, "pose", { from = t0, to = poseTo or t1, ease = down - t0, keys = { { t = down, set = set }, { t = up, set = set } } })
		end
		addList(id, "guardOff", { from = t0, to = t1 })
		addList(id, "still", { from = t0, to = t1 })
	end
	-- 내 이름을 불러줘 0:48 (6 at 41.26: the video bends 48.1-49.3, the right hand down to the floor)
	-- (D-1864: the video is lowest at 48.6 and upright again by 48.8 with the arms up; the bend held to 49.2 and rose at
	-- 49.4. Now down 48.31, up from 48.56, gone by 48.86; the legs stay held to 49.56 as before, over the capture's lap)
	plantBend(107391937407645, 6.75, 7.05, 7.3, 8.3, 70, nil, 7.6)
	-- 2:14 (18 at 124.74 to 135.05, then 19: the video bends 134.3-135.7 and is up by 135.9): 18 keeps its D-1850 window
	-- (left arm behind the back, right arm hanging, waist set -65) on the held legs; 19 carries the same bend on
	plantBend(100667532281425, 9.5, 9.8, 10.4, 10.6, nil)
	-- (D-1858, user: "2:14-2:15 움찔하는 거 정리") 19 taking the bend over at 135.05 shifted the hands 0.2 and the feet 0.08 twice
	-- (135.1-135.4: two captures of the same bend): 18 now holds its bend to 135.60 and 19 comes in rising, from its 0.55 s
	-- (ClubPlaylist: at 135.60, from 0.55)
	-- Boogie Woogie 2:51 (22 at 171.26: the capture bends 171.6-172.9; its earlier pose keeps the arms in an L)
	addList(79114246750826, "freeze", { from = 0.25, to = 1.75, ease = 0.3, except = UPPER })
	addList(79114246750826, "still", { from = 0.25, to = 1.75 })
	-- (D-1855, user: "2:37부터 왼손 작은 프레임 안에서는 그냥 고정") the left hand on the hip 157.0-159.9 (20 at 153.71) held still
	addList(130987200839765, "freeze", { from = 3.3, to = 6.2, ease = 0.3, except = { "LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } })
	-- (D-1856, user 2026-11-19, Unbelievable 0:00-0:17 written out move by move) what the practice video cannot give: the
	-- title covers the dancers to song 0.9 and the centre (white crop top) is hidden 7.0-8.3. Piece 1 time = song + 1.15,
	-- piece 2 = song - 6.02; beats at song -0.96 + k x 0.4545 (132 bpm)
	do
		local U1, U2 = 107202755656926, 132406634119258
		local function merge(a: any, b: any): any
			local t = table.clone(a)
			for k, v in pairs(b) do t[k] = v end
			return t
		end
		-- 0:00-0:02 "고개 앞에 보고 몸은 측면, 오른쪽 발뒤꿈치 들고 무릎 살짝 굽힘, 오른손 옆구리 -> 고개 뒤로 꺾었다가 돌아옴 ->
		-- 오른손으로 옆구리 쓸고 내려가면서 무릎 굽히고 앉음"
		local stand = { LowerTorso = { 0, -70, 0 }, UpperTorso = { 0, 0, 0 }, Head = { 0, 65, 0 },
			RightUpperLeg = { 25, 0, 0 }, RightLowerLeg = { -45, 0, 0 }, RightFoot = { -10, 0, 0 },
			LeftUpperLeg = { 0, 0, 0 }, LeftLowerLeg = { 0, 0, 0 }, LeftFoot = { 0, 0, 0 },
			RightUpperArm = { -90, 40, 60 }, RightLowerArm = { 90, 0, 0 }, RightHand = { 0, 0, 0 },
			LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 }, LeftHand = { 0, 0, 0 } }
		local nod0, nod = { Head = { 0, 0, 0 } }, { Head = { 38, 0, 0 } } -- (the head back about its own axis, after its turn to the front)
		local sit = merge(stand, { LowerTorso = { 0, -35, 0 }, Head = { 0, 30, 0 },
			RightUpperLeg = { 85, 0, 15 }, RightLowerLeg = { -115, 0, 0 }, RightFoot = { 30, 0, 0 },
			LeftUpperLeg = { 85, 0, -15 }, LeftLowerLeg = { -115, 0, 0 }, LeftFoot = { 30, 0, 0 },
			RightUpperArm = { 10, 0, 8 }, RightLowerArm = { 10, 0, 0 } })
		local up0, down = { LowerTorso = { 0, 0, 0 } }, { LowerTorso = { 0, -2.3, 0 } }
		addList(U1, "pose", { from = 0.5, to = 3.05, ease = 0.3, keys = {
			{ t = 1.15, set = stand, move = up0, add = nod0 }, { t = 1.4, set = stand, move = up0, add = nod0 }, { t = 1.62, set = stand, move = up0, add = nod },
			{ t = 1.9, set = stand, move = up0, add = nod0 }, { t = 2.05, set = stand, move = up0 }, { t = 2.75, set = sit, move = down } } })
		addList(U1, "guardOff", { from = 0.5, to = 3.05 })
		addList(U1, "still", { from = 0.5, to = 3.05 })
		-- 0:02 "오른쪽팔 위로 쭉 뻗음" (the capture has it up but bent)
		addList(U1, "pose", { from = 3.05, to = 3.8, ease = 0.2, keys = { { t = 3.25, set = { RightUpperArm = { 175, 0, 0 }, RightLowerArm = { 0, 0, 0 } } },
			{ t = 3.6, set = { RightUpperArm = { 175, 0, 0 }, RightLowerArm = { 0, 0, 0 } } } } })
		-- 0:05 "온몸 웨이브 처음에는 느리게 하고 뒤에 빠르게 두 번 더" (hands behind the head 4.3-6.7): the chest rolls
		-- forward and back, once slowly (4.7-5.6) and twice fast (5.7-6.0, 6.05-6.4)
		local function addBend(id: number, part: string, keys: any)
			local f = fx(id)
			f.bend = if f.bend then table.clone(f.bend) else {}
			table.insert(f.bend, { part = part, keys = keys })
		end
		-- (D-1858, user: "0:04-0:06 웨이브가 아님. 웨이브 연구해서 구현") a body wave is a push forward that travels down the
		-- body, each part following the one above: head (chin out) -> chest out while the head comes back -> hips out while the
		-- chest pulls back in -> knees give and straighten. Each push is a raised-cosine bump half a wave long, 0.2 of a wave
		-- after the one above. Chest out = the hips lean forward 30° + the waist arched back 22° (measured in Play: the breastbone
		-- goes forward, the seat back; an arch alone only leans back; the hips cannot be moved forward, their sideways place goes
		-- to the root), thighs turned so the feet stay; hips out = pelvis tucked back + chest curled in; knees =
		-- thighs / shins / feet fold and the hips sink. One slow wave over two beats (4.49-5.40), two fast ones a beat each
		-- (5.40-5.86, 5.86-6.31, the last over the seam into piece 2)
		local function bump(x: number): number
			return if x <= 0 or x >= 0.5 then 0 else 0.5 - 0.5 * math.cos(x * 4 * math.pi)
		end
		local function waveKey(t: number, ph: number, amp: number): any
			local h, c, p, k = bump(ph) * amp, bump(ph - 0.17) * amp, bump(ph - 0.34) * amp, bump(ph - 0.5) * amp
			local thigh = 30 * c - 12 * p + 24 * k
			return { t = t, curve = "linear",
				add = { Head = { -12 * h + 14 * c - 8 * p, 0, 0 }, UpperTorso = { 22 * c - 22 * p, 0, 0 }, LowerTorso = { -30 * c + 12 * p, 0, 0 },
					LeftUpperLeg = { thigh, 0, 0 }, RightUpperLeg = { thigh, 0, 0 }, LeftLowerLeg = { -46 * k, 0, 0 }, RightLowerLeg = { -46 * k, 0, 0 },
					LeftFoot = { 22 * k, 0, 0 }, RightFoot = { 22 * k, 0, 0 } },
				move = { LowerTorso = { 0, -0.3 * k, 0 } } }
		end
		local waves = { { 4.49, 5.40, 1 }, { 5.40, 5.86, 0.8 }, { 5.86, 6.31, 0.8 } }
		for _, piece in ipairs({ { U1, 1.15, 5.5, 7.3 }, { U2, -6.02, -0.6, 0.45 } }) do
			local keys = {}
			local t = piece[3]
			while t <= piece[4] + 0.001 do
				local song, key = t - piece[2], nil
				for _, w in ipairs(waves) do
					if song >= w[1] and song < w[2] then key = waveKey(t, (song - w[1]) / (w[2] - w[1]), w[3]) end
				end
				table.insert(keys, key or waveKey(t, 0, 0))
				t += 0.05
			end
			addList(piece[1], "pose", { from = piece[3], to = piece[4], ease = 0.05, keys = keys })
		end
		-- 0:07 "허허: 고개 왼쪽으로 갔다가 오른쪽으로 까딱하면서 양팔 앞으로 쭉 뻗음" / 0:09 "양팔 아래로 내리면서 걸어나옴"
		local fwd = { RightUpperArm = { 90, 0, 0 }, RightLowerArm = { 0, 0, 0 }, LeftUpperArm = { 90, 0, 0 }, LeftLowerArm = { 0, 0, 0 } }
		local half = { RightUpperArm = { 45, 0, 5 }, RightLowerArm = { 5, 0, 0 }, LeftUpperArm = { 45, 0, -5 }, LeftLowerArm = { 5, 0, 0 } }
		local hang = { RightUpperArm = { 0, 0, 8 }, RightLowerArm = { 10, 0, 0 }, LeftUpperArm = { 0, 0, -8 }, LeftLowerArm = { 10, 0, 0 } }
		addList(U2, "pose", { from = 0.85, to = 3.1, ease = 0.25, keys = {
			{ t = 1.1, set = fwd, add = { Head = { 0, 0, 22 } } }, { t = 1.4, set = fwd, add = { Head = { 0, 0, -22 } } }, { t = 1.7, set = fwd, add = { Head = { 0, 0, 0 } } },
			{ t = 2.15, set = fwd }, { t = 2.6, set = half }, { t = 3.05, set = hang } } })
		addList(U2, "guardOff", { from = 0.85, to = 3.35 })
		-- 0:12 "왼발로 땅 쿵쿵 밟으면서 몸 회전": the left knee comes up before each beat and the foot lands on it (12.22-14.50)
		local thigh, shin = {}, {}
		for k = 29, 34 do
			local t = -0.96 + k * 0.45455 - 6.02
			-- (in Play the foot peaked on the beat with the landing at t: 0.1 s earlier)
			table.insert(thigh, { t - 0.38, 0, 0, 0 }) table.insert(thigh, { t - 0.21, 38, 0, 0 }) table.insert(thigh, { t - 0.09, 0, 0, 0 })
			table.insert(shin, { t - 0.38, 0, 0, 0 }) table.insert(shin, { t - 0.21, -55, 0, 0 }) table.insert(shin, { t - 0.09, 0, 0, 0 })
		end
		addBend(U2, "LeftUpperLeg", thigh)
		addBend(U2, "LeftLowerLeg", shin)
	end
	-- (D-1900, 안무 포즈 설명 자동화 session's Play recording) Unbelievable slides with both feet on the floor: 0:09.8-0:10.05
	-- (2 at 6.02: the hips and feet go 1.3 studs together) and 1:58.55-1:58.85 (15 at 114.87: 1.9 studs; the step after is a
	-- real walk): the body held in place there
	addList(82151831370082, "still", { from = 3.5, to = 4.1 })
	-- (D-1901, user via the main session: "원본처럼") 0:09.8 the centre really walks forward there (about 1.2 torso lengths,
	-- stepping): instead of the still, the capture's travel is spread evenly over 9.07-10.37 (`glide`) and the legs step,
	-- a knee lifting between the beats and the foot landing on the beat (9.49 / 9.95 / 10.40; right, left, right)
	addList(132406634119258, "glide", { from = 3.05, to = 4.35 })
	-- (Play: 1.5 studs with the glide alone; the video's 1.2 torso lengths are about 2.5) one more stud forward
	-- (D-1902, 2nd review: the walk was 0.70 torso lengths against the video's 1.15 straight / 1.45 path; steps at 9.65 / 9.9 / 10.2)
	-- (D-1903, 2nd review of D-1902: the walk pushed forward (along the hips) and undid the capture's leftward travel. Video
	-- 9.07-10.37: left 0.93 + back 0.72 torso lengths; the capture alone: left 0.72, back 0.32 -> the rest, left 0.21 + back
	-- 0.40 = 0.95 stud, 152° from the hips' facing toward the left)
	addList(132406634119258, "walk", { from = 3.05, to = 4.35, dist = 0.95, dir = 152 })
	do
		-- (D-1904, 2nd review of D-1903: the planted foot slid 0.55-0.62 torso lengths while the body travelled; the video steps
		-- both feet in turn every 0.2 s) six steps, right / left in turn (landing 9.36 / 9.58 / 9.80 / 10.02 / 10.24 / 10.42),
		-- each foot lifted for 0.16 s before it lands. A planted foot stays where it is: its thigh turns as the body goes on
		-- (the body moves left 2.07 / back 0.94 studs over 9.07-10.37, eased in and out like the glide and walk), and a
		-- lifted foot swings ahead to land half a stance in the direction of travel. Leg length 4.2 studs (hip to foot, Play; 2 moved the
		-- planted foot twice as far the other way); thigh x + = foot
		-- forward, z + = foot to the dancer's right
		local A0, A1, L = 9.07, 10.37, 4.2
		local DX, DZ = -2.07, 0.94 -- body travel (x right, z back)
		local function e(t: number): number
			local u = math.clamp((t - A0) / (A1 - A0), 0, 1)
			return u * u * (3 - 2 * u)
		end
		local lands = { { 9.36, "Right" }, { 9.58, "Left" }, { 9.80, "Right" }, { 10.02, "Left" }, { 10.24, "Right" }, { 10.42, "Left" }, { 10.64, "Right" } }
		local SWING = 0.16
		-- (the capture's own legs swing a lot here, so the legs are set, not added: thighs spread 8° like the capture's stance)
		local track = {}
		for _, side in ipairs({ "Right", "Left" }) do
			local mine = {}
			for _, l in ipairs(lands) do if l[2] == side then table.insert(mine, l[1]) end end
			local samples = {} -- { t, x, z, lift }
			local t, rx, rz, lastE = A0, 0, 0, e(A0)
			for k, tl in ipairs(mine) do
				local tu = tl - SWING
				while t < tu do
					local de = e(t) - lastE
					rx, rz, lastE = rx - de * DX, rz - de * DZ, e(t)
					table.insert(samples, { t, rx, rz, 0 })
					t += 0.04
				end
				local de = e(tu) - lastE
				rx, rz, lastE = rx - de * DX, rz - de * DZ, e(tu)
				table.insert(samples, { tu, rx, rz, 0 })
				local nextUp = if mine[k + 1] then mine[k + 1] - SWING else A1 + 0.1
				local d = e(nextUp) - e(tl)
				local nx, nz = d * DX / 2, d * DZ / 2
				for q = 1, 4 do
					local u = q / 4
					table.insert(samples, { tu + SWING * u, rx + (nx - rx) * u, rz + (nz - rz) * u, math.sin(u * math.pi) })
				end
				rx, rz, lastE, t = nx, nz, e(tl), tl + 0.04
			end
			while t <= A1 + 0.3 do
				local de = e(t) - lastE
				rx, rz, lastE = rx - de * DX, rz - de * DZ, e(t)
				table.insert(samples, { t, rx, rz, 0 })
				t += 0.04
			end
			track[side] = samples
		end
		local function at(samples: any, t: number): (number, number, number)
			if t <= samples[1][1] then return samples[1][2], samples[1][3], samples[1][4] end
			for q = 1, #samples - 1 do
				local a, b = samples[q], samples[q + 1]
				if t <= b[1] then
					local u = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 0
					return a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u
				end
			end
			local z = samples[#samples]
			return z[2], z[3], z[4]
		end
		local keys = {}
		local t = A0 + 0.05
		while t <= A1 + 0.3 do
			local set = {}
			for _, side in ipairs({ "Right", "Left" }) do
				local x, z, lift = at(track[side], t)
				local spread = if side == "Right" then 8 else -8
				set[side .. "UpperLeg"] = { math.deg(math.atan(-z / L)) + 30 * lift, 0, math.deg(math.atan(x / L)) + spread }
				set[side .. "LowerLeg"] = { -50 * lift, 0, 0 }
				set[side .. "Foot"] = { 20 * lift, 0, 0 }
			end
			table.insert(keys, { t = t - 6.02, curve = "linear", set = set })
			t += 0.04
		end
		addList(132406634119258, "pose", { from = A0 + 0.05 - 6.02, to = A1 + 0.45 - 6.02, ease = 0.12, keys = keys })
		-- (D-1905, user: "발 고정(IK) 기능 만들기") what the leg turns above leave (0.17-0.35 torso lengths, Play; before the
		-- walk the capture's own slide 8.6-9.2) is held by ChoreoFeet: the planted foot keeps its floor spot 8.6-10.8
		-- (D-1908, 2nd review of D-1907: 10.4-12.0 the video walks back toward the camera lifting a foot 6 times; the game came back
		-- as far but lifted once, so the held feet were dragged) the window to 12.0 and those six steps (left, right in turn)
		addList(132406634119258, "plant", { from = 2.58, to = 5.98 })
		do
			local f = fx(132406634119258)
			f.bend = if f.bend then table.clone(f.bend) else {}
			for i, t in ipairs({ 10.75, 10.95, 11.2, 11.4, 11.55, 11.65 }) do
				local side = if i % 2 == 1 then "Left" else "Right"
				local h = if t > 11.5 then 0.06 else 0.09
				table.insert(f.bend, { part = side .. "UpperLeg", keys = { { t - h - 6.02, 0, 0, 0 }, { t - 6.02, 30, 0, 0 }, { t + h - 6.02, 0, 0, 0 } } })
				table.insert(f.bend, { part = side .. "LowerLeg", keys = { { t - h - 6.02, 0, 0, 0 }, { t - 6.02, -50, 0, 0 }, { t + h - 6.02, 0, 0, 0 } } })
			end
		-- (D-1909, user 2026-11-19: "내 이름을 불러 줘 난리 남. 안무 원본 영상에서 안무 동선 중 하나로 움직이는 거 아니면 최대한 자기 자리에서
		-- 추도록") 내 이름을 불러줘: the body stays where it is except in the video's formation moves. Formation moves = the followed
		-- centre (tracks.json) going 0.6+ body heights in 1.5 s: 0:01-0:04, 0:12-0:17, 0:30-0:32, 0:34-0:37, 0:49-0:52, 0:57-1:00,
		-- 1:05-1:06, 1:23-1:27, 1:30-1:31, 1:55-1:56, 2:16-2:19, 2:20-2:25, 2:27-2:29, 2:31-2:37 (each 0.2 s wider); everything
		-- else of each piece is `still` (piece seconds)
		for id, wins in {
			[84847937406843] = { { 1.25, 2.30 }, { 5.70, 13.30 } },
			[88993457159273] = { { 5.69, 9.98 } },
			[74885576782093] = { { 0.00, 9.56 } },
			[132355350514600] = { { 0.00, 0.55 }, { 2.95, 3.80 } },
			[83828094822862] = { { 3.20, 8.51 } },
			[107391937407645] = { { 0.00, 7.79 } },
			[120616516576434] = { { 1.46, 6.31 } },
			[90921923486342] = { { 2.71, 7.06 }, { 8.96, 10.01 } },
			[73429358232249] = { { 0.00, 5.01 } },
			[88595092254451] = { { 0.00, 4.00 } },
			[133275108218481] = { { 0.00, 5.00 } },
			[107243018629607] = { { 0.00, 5.01 } },
			[76545761433830] = { { 0.00, 1.28 }, { 5.18, 6.97 } },
			[137670042338904] = { { 0.00, 2.06 }, { 3.96, 13.78 } },
			[81624243507898] = { { 0.00, 14.28 } },
			[128327230683798] = { { 1.93, 2.96 } },
			[107246799142521] = { { 0.00, 9.01 } },
			[100667532281425] = { { 0.00, 11.06 } },
			[122207092339520] = { { 3.90, 5.25 }, { 9.90, 11.75 } },
			[96319765244846] = { { 0.95, 2.55 }, { 8.45, 21.00 } },
		} do
			for _, w in ipairs(wins) do addList(id, "still", { from = w[1], to = w[2] }) end
		end
		-- (D-1909, user: "부기우기도 적용해. 허리만 숙이고 있는 동작인데 발이 미끄러지는 부분 있어") Boogie Woogie, Play recording (feet on the
		-- floor, bent 25-70°): 0:37.1-0:40.6 the left foot slid 1.7 torso lengths (bent over, hands on the knees: the video stays
		-- put), 1:18.4-1:19.1 the right 1.1, 2:52.8-2:53.3 the left 2.2: body held (still) at 0:37-0:41 and the feet planted in all three
		addList(97814419171643, "still", { from = 9.39, to = 13.45 })
		addList(92946970770352, "still", { from = 0, to = 0.64 })
		-- (Play: with the body held the capture's left foot still spread 1.5 torso lengths 0:37-0:41, hovering 0.3-0.4 studs up,
		-- so the plant did not take it: the legs are held at the pose the bend starts with, and the feet count as down up to 0.45)
		addList(97814419171643, "freeze", { from = 9.55, to = 13.45, ease = 0.3, except = UPPER })
		addList(97814419171643, "plant", { from = 9.39, to = 13.45, contact = 0.45 })
		addList(92946970770352, "plant", { from = 0, to = 0.64, contact = 0.45 })
		addList(70911274448112, "plant", { from = 7.3, to = 9.1, contact = 0.45 })
		addList(79114246750826, "plant", { from = 1.25, to = 2.4, contact = 0.45 })
		end
		-- (Play with the plant: the right foot never lifted 8.5-9.3 in the capture, so it was held until it was 1.2 studs
		-- behind and jumped: one right step at 8.95 before the walk, one more at 10.64 after it)
		do
			local f = fx(132406634119258)
			f.bend = if f.bend then table.clone(f.bend) else {}
			table.insert(f.bend, { part = "RightUpperLeg", keys = { { 8.79 - 6.02, 0, 0, 0 }, { 8.95 - 6.02, 30, 0, 0 }, { 9.11 - 6.02, 0, 0, 0 } } })
			table.insert(f.bend, { part = "RightLowerLeg", keys = { { 8.79 - 6.02, 0, 0, 0 }, { 8.95 - 6.02, -50, 0, 0 }, { 9.11 - 6.02, 0, 0, 0 } } })
		end
	end
	-- (D-1901, user via the main session: "원본처럼 고개 젖힘, 상체 움직임도 원본만큼") 갑자기 0:09.2-0:10.1 the head goes back
	-- (chin up about 40°) and the upper body leans back with it (the capture: head 6-8°, chest 5-7°, 15 % of it); at 10.2-10.5
	-- the head swings forward and the body is upright by 10.7. Piece 140529283375287 at 8.5
	addList(140529283375287, "pose", { from = 0.5, to = 2.3, ease = 0.05, keys = {
		{ t = 0.55, add = { Head = { 0, 0, 0 }, UpperTorso = { 0, 0, 0 }, LowerTorso = { 0, 0, 0 } } },
		{ t = 0.8, add = { Head = { 20, 0, 0 }, UpperTorso = { 12, 0, -8 }, LowerTorso = { 6, 0, 0 } } },
		{ t = 1.6, add = { Head = { 20, 0, 0 }, UpperTorso = { 12, 0, -8 }, LowerTorso = { 6, 0, 0 } } },
		{ t = 1.85, curve = "out", add = { Head = { -12, 0, 0 }, UpperTorso = { 2, 0, 0 }, LowerTorso = { 0, 0, 0 } } },
		{ t = 2.2, add = { Head = { 0, 0, 0 }, UpperTorso = { 0, 0, 0 }, LowerTorso = { 0, 0, 0 } } } } })
end

-- (D-1853, user 2026-11-19: "언빌리버블 손만 떠는 게 아니고 전체를 다 떨어 사시나무처럼 … 안무 동작 정확하고 크게 보정해") Play:
-- 25.7 small turn-backs (> 0.4° a frame) a second over the body against 17.2 in 내 이름을 불러줘, the hands and feet twice
-- as many: every Unbelievable piece is averaged harder in time (`dejitter` 0.07 s against 0.03) and its slower wobble eased
-- (`calm`), so the 6-15 per-second shiver goes and the beat-sized moves keep their size
do
	for _, id in ipairs({ 107202755656926, 132406634119258, 140321069508247, 91684619142886, 127086942159592, 82476096356644, 105450147611432, 126709034309523,
		110146513928585, 98575698595382, 97422868495252, 77667909738269, 98632778351786, 106947840145982, 121716323345976, 82151831370082, 85861969329409 }) do
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		f.dejitter = 0.07
		f.calm = true
		f.smoothDetail = true -- (the hands and feet shook most: 70-80 turn-backs in 20 s, and D-998 kept them out of the clean-ups)
	end
end

-- (D-1931, user 2026-11-20: "레모네이드 안무 잠궈 놓은 거 풀고 지금까지 만든 프로그램이랑 규칙으로 보정해 봐"; rule "동선 아니면 최대한 자기 자리에서",
-- "디딘 발 미끄러지면 안 됨", memory choreo-stay-in-place) Lemonade-aespa: Play recording of the unlocked dance: travel outside the
-- video's formation moves 50.6 torso lengths (inside 7.3), 171 planted-foot slides. Formation moves (the followed centre going
-- 0.6+ body heights in 1.5 s): 0:29.5-0:31.8, 0:32.5-0:34, 1:32.5-1:34.3, 1:38.8-1:40.8, 2:12-2:17.8; everything else `still`
-- (piece seconds, 0.2 s margins), and every piece keeps its planted feet (`plant`, contact 0.45: at 0.3, 24 slides of 0.2-1.5 torso
-- lengths were left, the feet gliding just over the floor)
do
	local function addList(id: number, key: string, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	for id, wins in {
			[107871857436267] = { { 0.45, 9.37 } },
			[85687535459003] = { { 0.00, 10.00 } },
			[74096523961866] = { { 0.00, 7.92 } },
			[123559029471758] = { { 0.00, 6.46 }, { 9.11, 9.46 } },
			[139260290712979] = { { 0.03, 0.38 }, { 2.28, 8.28 } },
			[131526768823490] = { { 0.00, 9.29 } },
			[99422937735141] = { { 0.00, 10.33 } },
			[99169381541568] = { { 0.00, 12.13 } },
			[100397079318559] = { { 0.00, 10.30 } },
			[135759185323713] = { { 0.00, 10.57 } },
			[83846438884132] = { { 0.00, 6.38 }, { 8.53, 9.47 } },
			[138502286160157] = { { 0.06, 4.16 }, { 6.56, 7.53 } },
			[107439323698577] = { { 0.03, 11.47 } },
			[138612452549442] = { { 0.00, 4.53 } },
			[118124487485279] = { { 0.00, 13.73 } },
			[82680550952125] = { { 0.00, 4.15 }, { 10.30, 11.27 } },
			[132337331292488] = { { 0.03, 9.00 } },
			[76195346888656] = { { 0.00, 6.00 } },
			[116980798181063] = { { 0.00, 11.00 } },
			[118071176218932] = { { 0.00, 8.50 } },
			[76826604804095] = { { 0.00, 10.07 } },
			[89070118321317] = { { 0.00, 21.00 } },
	} do
		for _, w in ipairs(wins) do addList(id, "still", { from = w[1], to = w[2] }) end
		-- (D-1932, 2nd review: in the video the foot stays put at 0:16.4-0:16.8, 0:20.7-0:20.9, 0:26.2-0:26.4, 0:31.0-0:31.2,
		-- 1:49.4-1:50.0; elsewhere a foot the dance carries off is stepped (ChoreoFeet STEP). The first window that matches counts)
		for _, w in ipairs(({
			[74096523961866] = { { 0.38, 0.98 }, { 4.68, 5.08 } },
			[123559029471758] = { { 3.26, 3.66 }, { 8.06, 8.46 } },
			[107439323698577] = { { 8.38, 9.18 } },
		} :: any)[id] or {}) do
			-- (D-1967: covered by the noStep plant below)
		end
		-- (D-1943, 2nd review of D-1942: 2:29.7 / 2:35.4 / 1:49.2 a step set the foot down while the dance still carried it,
		-- 0.55-0.70 studs along the floor) here a step picks its landing spot at 85 % and puts the foot down there (`landHold`);
		-- the capture sinks the foot 0.2-0.27 under the floor there, so the step may bend the knee to lift it 0.3 (`kneeLift`)
		for _, w in ipairs(({
			[76195346888656] = { { 3.30, 6.10 } },
			[107439323698577] = { { 7.80, 8.38 } },
		} :: any)[id] or {}) do
			-- (D-1967: no landing steps: they hopped the legs)
		end
		-- (not on 17, 2:18-2:26: the floor routine, lying with the legs stretched out; the video sweeps the legs on the floor)
		-- (D-1965, user after the 2P run: "2:10 극초반 다리 튐", "2:31 다리 버벅", "2:35 다리 걸어가는 모션 깔끔하게",
		-- "2:36 오른쪽 다리 들썩") the steps hopped the legs (2:10 0.14-0.17 stud, 26 hops in 2:30-2:37)
		-- (D-1967, user's 3rd list) feet held without steps (noStep) on every piece: without any plant the feet slid 2 studs
		-- (0:38) and a `freeze` was undone by the steps; where the dance itself moves a foot to a new spot (song 8.2-8.5, 15.3:
		-- the hold let go in one frame, 0.8-1.4 stud) the foot follows the dance; not under 1:23-1:26's frozen legs (the IK
		-- flicked the knees for single frames)
		if id == 85687535459003 then
			addList(id, "plant", { from = 0, to = 1.0, contact = 0.45, noStep = true })
			addList(id, "plant", { from = 1.8, to = 8.1, contact = 0.45, noStep = true })
			addList(id, "plant", { from = 8.7, to = 99, contact = 0.45, noStep = true })
		elseif id == 123559029471758 then
			-- (D-1969, "0:24 오른쪽 다리 안쪽으로 꺾임": the hold let the right foot go and took it again, 1.0-1.8 stud in one frame)
			addList(id, "plant", { from = 0, to = 1.0, contact = 0.45, noStep = true })
			addList(id, "plant", { from = 3.4, to = 99, contact = 0.45, noStep = true })
		elseif id == 76195346888656 then
			addList(id, "plant", { from = 1.5, to = 99, contact = 0.45, noStep = true }) -- (D-1969) not while she stands up (2:25)
		elseif id == 135759185323713 then
			addList(id, "plant", { from = 0, to = 6.9, contact = 0.45, noStep = true })
		elseif id ~= 132337331292488 then
			addList(id, "plant", { from = 0, to = 99, contact = 0.45, noStep = true })
		end
	end
end

-- (D-1933, BANG 2nd review: 2:02.0-2:04.2 in the lunge the video throws the head back on 2:02.4 / 2:03.0 / 2:03.8, the game's
-- head hardly moved (17 %)) 12 at 112.85 / 13 at 123.51: head back 28° and down again on each
do
	local function toss(t: number): any
		return { { t - 0.18, 0, 0, 0 }, { t, 28, 0, 0 }, { t + 0.28, 0, 0, 0 } }
	end
	for _, b in ipairs({ { 88337047994676, 122.4 - 112.85 }, { 88337047994676, 123.0 - 112.85 }, { 122763589970816, 123.8 - 123.51 } }) do
		local f = (M.ChoreoFixes[b[1]] or {}) :: any
		M.ChoreoFixes[b[1]] = f
		f.bend = if f.bend then table.clone(f.bend) else {}
		table.insert(f.bend, { part = "Head", keys = toss(b[2]) })
	end
	-- (2nd review of D-1933: the head turned left 52-65° from the chest there against the video's 15-38°; a turn added on each
	-- toss only grew with the tilt) the head turned back YAW° through the lunge 122.0-124.1
	local YAW = -25
	for _, w in ipairs({ { 88337047994676, 112.85, 122.0, 123.51 }, { 122763589970816, 123.51, 123.51, 124.1 } }) do
		local f = M.ChoreoFixes[w[1]] :: any
		local a, b = w[3] - w[2], w[4] - w[2]
		table.insert(f.bend, { part = "Head", keys = { { a - 0.2, 0, 0, 0 }, { a, 0, YAW, 0 }, { b, 0, YAW, 0 }, { b + 0.2, 0, 0, 0 } } })
	end
end

-- (D-1936, 2nd review of D-1935: BANG feet slid 1.4-1.5 studs at 2:14-2:17, the video steps there; rule "동선 아니면 자기 자리,
-- 디딘 발 미끄러지면 안 됨" for the whole song) formation moves (the followed centre 0.6+ body heights in 1.5 s): 0:06.5-0:09.3,
-- 0:30.5-0:33.3, 0:35-0:37.5, 0:50.8-0:52.3, 1:18-1:19.8, 2:07.3-2:12.5, 2:14-2:16.5, 2:40-2:41.5, 2:46-2:47.5, 2:50.3-2:52.5,
-- 2:58.8-3:00.8; everything else `still`, every piece `plant` (contact 0.45; a foot the dance carries off is stepped)
do
	local function addList(id: number, key: string, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	for id, wins in {
		[84153374890352] = { { 1.81, 15.00 } },
		[137056236927761] = { { 0.00, 8.66 }, { 11.81, 13.16 } },
		[105204020323017] = { { 0.00, 0.75 }, { 3.65, 14.80 } },
		[120933576855785] = { { 0.00, 2.70 }, { 4.60, 13.99 } },
		[102971667388731] = { { 0.00, 7.88 } },
		[103181529138741] = { { 0.00, 10.08 } },
		[117412778868520] = { { 1.27, 12.18 } },
		[91956738526101] = { { 0.00, 10.74 } },
		[71518245203286] = { { 0.00, 14.25 } },
		[88337047994676] = { { 0.00, 11.66 } },
		[122763589970816] = { { 0.00, 3.54 }, { 9.19, 10.29 } },
		[114991184702089] = { { 2.47, 14.62 } },
		[133693971779949] = { { 0.00, 11.95 }, { 13.85, 14.99 } },
		[129925869461594] = { { 0.00, 3.96 }, { 5.86, 8.21 }, { 10.86, 14.13 } },
		[73991603786553] = { { 0.00, 3.58 }, { 5.98, 12.88 } },
		[73314859778019] = { { 0.00, 21.00 } },
	} do
		for _, w in ipairs(wins) do addList(id, "still", { from = w[1], to = w[2] }) end
		addList(id, "plant", { from = 0, to = 99, contact = 0.45 })
	end
end

-- (D-1944, 2nd review 2026-11-20 of Lemon Tang / I SPY / Looks Can Kill: planted feet slid 0.15+ torso at 154 / 134 / 143 places,
-- 2-3 studs at the largest; the user's top rule: "동선 아니면 자기 자리, 디딘 발 미끄러지면 안 됨") same as Lemonade / BANG
-- (D-1931 / D-1936): formation moves = Lemon Tang the followed centre 0.6+ body heights in 1.5 s (tracks.json) together with the
-- review's list (the original's body 0.7 torso/s and 1 torso+); I SPY / Looks Can Kill (no centercut tracks) the review's list.
-- Everywhere else `still` (piece seconds, 0.2 s margins; a piece used twice stays only where both uses are outside the moves),
-- every piece `plant` (contact 0.45; a foot the dance carries off is stepped)
do
	local function addList(id: number, key: string, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	for id, wins in {
		-- Lemon Tang
		[122848199967536] = { { 0.00, 6.05 } },
		[100331751999626] = { { 1.30, 3.90 } },
		[131067900968920] = {  },
		[79127181604364] = { { 0.80, 4.05 } },
		[101333518191621] = { { 0.00, 2.60 } },
		[70997868814427] = { { 0.00, 1.10 }, { 4.75, 7.85 }, { 12.15, 13.20 } },
		[94645609133900] = { { 0.00, 9.65 } },
		[124676885767926] = { { 0.00, 2.20 }, { 4.95, 6.25 } },
		[72328693870219] = { { 0.00, 0.80 } },
		[115675906513114] = {  },
		[74892270940916] = {  },
		[119643676032061] = { { 0.05, 0.80 } },
		[110925421163686] = { { 2.85, 7.95 } },
		[88699205496882] = { { 0.00, 1.05 }, { 6.00, 11.00 } },
		[98655639854740] = { { 0.00, 4.25 } },
		[118088106367753] = { { 0.00, 5.80 } },
		[112515342357817] = { { 0.00, 2.95 } },
		[125963510042067] = { { 0.00, 3.00 } },
		[128761870790634] = { { 0.00, 4.00 } },
		[108870214091189] = {  },
		[93178194866716] = { { 2.75, 4.00 } },
		[92757942038731] = { { 0.00, 9.45 } },
		[110433660488854] = { { 0.00, 7.55 } },
		[87039448079710] = { { 0.00, 0.40 }, { 2.80, 4.75 } },
		[99840608563579] = { { 1.90, 5.10 } },
		[134866535240552] = { { 0.95, 3.35 }, { 5.95, 7.20 } },
		[98315614070332] = { { 0.00, 9.35 } },
		-- I SPY
		[83299308409543] = { { 0.00, 3.40 } },
		[107073213896668] = { { 0.00, 3.20 } },
		[88558817308286] = { { 1.10, 1.45 } },
		[98909637894188] = {  },
		[97906912240537] = { { 0.20, 5.45 } },
		[114940315235555] = { { 0.00, 7.25 } },
		[130779565006070] = { { 0.00, 3.75 }, { 5.90, 6.95 } },
		[98654918637507] = { { 0.00, 9.35 } },
		[122217205660431] = { { 0.00, 2.95 } },
		[140084544726244] = { { 0.00, 0.55 } },
		[100757574150030] = { { 0.45, 4.75 } },
		[71548910990490] = { { 0.00, 7.15 } },
		[74401251779168] = { { 0.00, 3.85 }, { 5.55, 11.05 } },
		[137433206050479] = { { 0.00, 5.30 } },
		[135074521559748] = { { 0.00, 2.45 } },
		[119352807886781] = { { 0.05, 6.10 } },
		[80718941616155] = { { 0.00, 8.35 } },
		[129241685079019] = {  },
		[76871177818406] = { { 1.15, 3.30 } },
		[96659789313572] = { { 0.00, 3.80 } },
		[133446362959561] = { { 0.00, 4.95 } },
		[84123931984762] = { { 0.00, 2.35 } },
		[74058508632786] = { { 0.10, 8.10 } },
		[127691136882789] = { { 0.00, 8.70 } },
		[103256787571476] = {  },
		[114665222364433] = { { 0.00, 7.55 } },
		[73998534307708] = { { 0.00, 9.05 } },
		[117524452063760] = { { 0.00, 11.50 } },
		[80845800354299] = { { 0.00, 8.45 }, { 10.25, 11.65 } },
		[112388068192596] = { { 0.00, 6.35 } },
		-- Looks Can Kill
		[104472985141273] = { { 0.00, 1.80 } },
		[100762274305324] = { { 1.15, 1.90 } },
		[92352840963540] = { { 0.00, 4.05 }, { 5.75, 9.25 } },
		[73035150280152] = { { 3.70, 7.10 } },
		[77509133314202] = {  },
		[109736190348459] = { { 0.00, 1.30 }, { 3.95, 4.35 } },
		[120841071882545] = { { 0.00, 2.90 } },
		[128205693221038] = { { 0.00, 3.80 } },
		[111907232555806] = { { 0.00, 1.45 }, { 4.30, 10.70 } },
		[124059184095981] = { { 0.00, 6.30 } },
		[87500016171854] = { { 0.00, 7.15 } },
		[73623563360624] = { { 0.00, 3.05 } },
		[105165734205045] = { { 0.70, 5.30 } },
		[84050357538982] = {  },
		[80842274249808] = { { 4.30, 7.30 } },
		[112107210780715] = { { 1.00, 6.90 } },
		[92250246039046] = {  },
		[123875931497308] = { { 0.60, 5.00 }, { 6.80, 7.60 } },
		[97254731498706] = { { 0.00, 7.80 } },
		[85566191636983] = { { 0.00, 8.05 } },
		[133964239076172] = { { 0.00, 0.35 }, { 2.15, 5.85 } },
		[120575710088163] = { { 0.00, 3.35 }, { 6.45, 7.25 } },
		[104957688493242] = { { 0.00, 1.55 } },
		[132124420274015] = { { 0.00, 0.55 } },
		[134968782013343] = { { 0.00, 5.70 } },
		[92922732552861] = { { 0.00, 3.95 } },
		[88317170211079] = { { 0.00, 7.15 } },
		[130014890140037] = { { 0.00, 1.65 } },
		[76585975326316] = { { 1.55, 6.45 }, { 8.35, 10.15 } },
		[128909786311122] = { { 0.00, 6.50 } },
		[74039257328689] = { { 2.25, 3.10 }, { 4.60, 9.35 } },
		[79871898776208] = { { 0.00, 5.80 } },
	} do
		for _, w in ipairs(wins) do addList(id, "still", { from = w[1], to = w[2] }) end
		addList(id, "plant", { from = 0, to = 99, contact = 0.45 })
	end
end

-- (D-1945, 2nd review 2026-11-20, pictures describe_out\<song>\2차검토\그림) arms the capture lost:
-- Looks Can Kill 0:38.6-0:39.2 (lck_0m38): the video lifts both arms over the head, hands together; the game kept them at the
-- chest → both arms up over the head (piece 6 at 36, piece seconds 2.3-3.6)
-- I SPY 1:32.7-1:33.1 (is_1m32): the video's right arm goes straight up, the game raised the left (151° off) → the two arms
-- swap there: the right takes the game's raised left arm mirrored (Play, 92.8-93.0: shoulder 46,-53,-87 / elbow 21,-6,-12),
-- the left the hanging right arm mirrored (-35,31,14 / 5,3,10) (piece 17 at 87.78, piece seconds 4.7-5.5)
do
	local function addPose(id: number, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f.pose == nil then {} elseif f.pose.from then { f.pose } else table.clone(f.pose)
		table.insert(list, item)
		f.pose = list
	end
	local up = { LeftUpperArm = { 0, 0, -185 }, LeftLowerArm = { 20, 0, 0 }, RightUpperArm = { 0, 0, 185 }, RightLowerArm = { 20, 0, 0 } }
	addPose(120841071882545, { from = 2.3, to = 3.6, ease = 0.3, keys = { { t = 2.6, set = up }, { t = 3.2, set = up } } })
	local swap = { RightUpperArm = { 46, 53, 87 }, RightLowerArm = { 21, 6, 12 }, LeftUpperArm = { -35, -31, -14 }, LeftLowerArm = { 5, -3, -10 } }
	addPose(80718941616155, { from = 4.7, to = 5.5, ease = 0.2, keys = { { t = 4.95, set = swap }, { t = 5.3, set = swap } } })
end

-- (D-1946, 2nd review of D-1944: feet still dragged 0.6-1.2 studs at Lemon Tang 0:19.0 / 0:25.7 / 1:35.5 and I SPY 0:43.4 /
-- 0:49.5 / 3:03.6) as Lemonade D-1943: a step there picks its landing spot at 85 % and may bend the knee to clear the floor
-- (`landHold`, `kneeLift`); put before each piece's whole-piece window (the first window that matches counts)
do
	local function plantFirst(id: number, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f.plant == nil then {} elseif f.plant.from then { f.plant } else table.clone(f.plant)
		table.insert(list, 1, item)
		f.plant = list
	end
	for id, w in {
		[79127181604364] = { 1.80, 2.90 }, -- Lemon Tang 0:19.0 (at 16.65)
		[101333518191621] = { 0.80, 1.90 }, -- Lemon Tang 0:25.7 (at 24.37)
		[98655639854740] = { 3.00, 4.10 }, -- Lemon Tang 1:35.5 (at 92.0)
		[98654918637507] = { 7.85, 8.90 }, -- I SPY 0:43.4 (at 35.03)
		[140084544726244] = { 1.30, 1.90 }, -- I SPY 0:49.5 (at 47.37, into the next piece)
		[100757574150030] = { 0.00, 0.90 }, -- I SPY 0:49.5 (at 49.27)
		[112388068192596] = { 2.50, 3.60 }, -- I SPY 3:03.6 (at 180.55)
	} do
		plantFirst(id, { from = w[1], to = w[2], contact = 0.45, landHold = true, kneeLift = 90 })
	end
end

-- (D-1947, user 2026-11-20 "다른 안무들도 검토해": the 19 songs the stay-in-place rule had not reached; Play recordings with the
-- current code had 185-325 planted-foot drags a song, up to 10-25 studs) same as Lemonade / BANG / D-1944: formation moves =
-- the comparison session's windows from the original videos (the hips 0.7 torso/s for 0.5 s+, 1 torso+ of travel) together
-- with the centercut tracks.json ones where the clip offset is sure (Suddenly, With, Boogie Woogie, BAD, Love 119, Pretty Girl,
-- Pop Off, CRASH, SHOCK); Get A Guitar has no reliable windows (no centercut, the review's read covers most of the song), so it
-- only gets planted feet. Everywhere else `still` (piece seconds, 0.2 s margins), every piece `plant` (contact 0.45; a foot the
-- dance carries off is stepped). Pieces with their own `plant` windows (Unbelievable / Boogie Woogie, D-1905..1909) keep them
-- first.
do
	local function addList(id: number, key: string, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	for id, wins in {
		-- Suddenly-IOI
		[72001429900652] = { { 0.30, 7.60 } },
		[84372825286978] = { { 0.00, 1.15 } },
		[140529283375287] = { { 0.00, 1.00 }, { 7.75, 8.20 } },
		[81367674902881] = { { 5.65, 6.30 } },
		[121160569929367] = { { 1.10, 9.80 } },
		[109571265510769] = { { 0.60, 9.70 } },
		[84783409830169] = { { 0.00, 9.00 } },
		[76645919052139] = { { 2.75, 3.60 } },
		[72886571801726] = { { 1.75, 9.90 } },
		[104001486192661] = { { 0.75, 1.50 }, { 6.25, 8.35 } },
		[71879139866517] = { { 0.00, 0.55 }, { 4.65, 9.60 } },
		[72291044078776] = { { 0.00, 2.30 } },
		[112457407974304] = {  },
		[128759413181742] = { { 0.95, 1.90 }, { 3.75, 8.50 } },
		[121913954340036] = { { 0.25, 7.55 } },
		[139341321382250] = { { 1.65, 6.55 } },
		[84100214173726] = { { 0.00, 4.05 } },
		[118835663786601] = {  },
		[136490889932903] = {  },
		[78855026719716] = {  },
		[123714434236489] = { { 1.65, 5.90 }, { 8.15, 14.00 } },
		[111512315445927] = { { 0.00, 3.00 } },
		[92331354114542] = { { 0.00, 6.00 } },
		[82782712192367] = { { 0.00, 3.95 }, { 6.25, 7.30 } },
		[129257680770934] = { { 9.15, 13.00 } },
		-- With-RESCENE
		[81069311107336] = { { 1.65, 4.00 } },
		[98274724905693] = { { 0.00, 0.60 } },
		[77578453879056] = {  },
		[102977375863633] = {  },
		[113905277691263] = {  },
		[131580629784808] = { { 1.50, 7.25 }, { 9.90, 11.35 } },
		[82123725906788] = { { 3.50, 6.60 } },
		[134804041385196] = { { 0.00, 2.30 } },
		[87649722430222] = { { 3.05, 12.35 } },
		[139525834845370] = { { 0.00, 12.05 } },
		[135964930726670] = { { 5.50, 7.55 } },
		[103924587030311] = { { 0.00, 2.25 } },
		[119026591853452] = { { 6.65, 7.30 } },
		[107316277730722] = { { 0.00, 1.95 } },
		[75224598365049] = { { 1.80, 2.90 } },
		[78971722650566] = {  },
		[102753426349246] = { { 0.80, 12.05 } },
		[123058513001948] = { { 1.55, 4.15 } },
		[98289786237934] = { { 0.00, 1.80 } },
		[97670698889704] = {  },
		[103780560163454] = { { 0.00, 6.80 } },
		[119066931308311] = {  },
		[128822554881165] = { { 1.10, 4.90 } },
		[75577288501140] = { { 0.00, 1.90 } },
		[132556616885642] = { { 4.45, 7.65 } },
		-- Unbelievable-H1KEY
		[107202755656926] = { { 1.15, 7.10 } },
		[132406634119258] = { { 0.00, 2.60 } },
		[140321069508247] = {  },
		[91684619142886] = { { 3.10, 9.00 } },
		[127086942159592] = { { 0.00, 4.80 } },
		[82476096356644] = { { 2.65, 3.55 }, { 5.95, 7.75 } },
		[105450147611432] = {  },
		[126709034309523] = { { 0.00, 0.55 }, { 3.35, 6.90 } },
		[110146513928585] = {  },
		[98575698595382] = {  },
		[97422868495252] = { { 0.00, 0.45 } },
		[77667909738269] = { { 4.85, 10.00 } },
		[98632778351786] = { { 0.00, 1.45 } },
		[106947840145982] = { { 1.90, 7.30 } },
		[121716323345976] = { { 4.45, 10.35 } },
		[82151831370082] = { { 4.85, 5.45 } },
		[85861969329409] = { { 1.40, 10.55 } },
		-- Boogie Woogie-NCT DREAM
		[74991796424913] = { { 3.85, 7.45 } },
		[72899900258037] = { { 0.00, 5.70 } },
		[98798684410312] = { { 0.20, 2.40 } },
		[136974262670764] = { { 5.50, 9.85 } },
		[97814419171643] = { { 0.00, 0.90 }, { 7.90, 13.45 } },
		[92946970770352] = { { 0.00, 10.40 } },
		[93564912800713] = { { 0.00, 9.95 } },
		[118999861690635] = { { 0.05, 3.95 }, { 6.35, 7.70 } },
		[70911274448112] = { { 4.60, 7.40 } },
		[72126724441612] = { { 2.85, 8.80 } },
		[103506023234554] = { { 0.00, 1.50 }, { 6.70, 7.30 } },
		[137817236071281] = { { 1.00, 7.45 } },
		[138409186362070] = { { 0.00, 7.75 } },
		[98549161772624] = { { 0.00, 8.25 } },
		[77759369454741] = { { 0.00, 7.00 } },
		[92147677701072] = { { 2.15, 3.10 } },
		[90031774217033] = { { 0.00, 0.55 }, { 2.70, 4.10 } },
		[82489608576953] = { { 0.00, 7.65 } },
		[140605792599503] = { { 2.80, 6.55 } },
		[130987200839765] = { { 0.00, 8.95 } },
		[138159952468756] = {  },
		[79114246750826] = {  },
		[81117884846850] = { { 0.00, 0.65 } },
		[123702153844970] = { { 0.15, 0.75 }, { 4.15, 12.90 } },
		-- Genie-SNSD
		[122991710923104] = { { 0.00, 5.10 } },
		[118462778307290] = { { 0.20, 6.15 } },
		[127323208506008] = { { 0.00, 4.60 }, { 6.50, 7.25 } },
		[121572726416294] = { { 0.00, 10.15 } },
		[101676644495491] = { { 3.70, 13.05 } },
		[105545108302127] = { { 0.00, 4.95 } },
		[107809363798601] = { { 0.80, 13.65 } },
		[97769840770691] = { { 0.00, 10.95 } },
		[108803469428764] = { { 7.30, 8.80 } },
		[76060752564499] = { { 1.75, 10.70 } },
		[136331779515321] = { { 0.00, 1.45 }, { 5.25, 6.75 } },
		[94271336995595] = { { 0.00, 3.90 }, { 8.00, 8.60 } },
		[76687116604339] = { { 6.20, 8.30 } },
		[94143895222958] = {  },
		[137553505478362] = { { 2.00, 10.95 } },
		[120592352351697] = { { 0.00, 2.05 } },
		[110416135198674] = { { 0.00, 1.00 } },
		[124091598492660] = { { 2.75, 3.15 } },
		[98754942494305] = { { 1.90, 6.75 } },
		[105066453794976] = {  },
		[130670560182985] = { { 1.55, 7.95 } },
		[125902811896005] = { { 0.00, 8.70 } },
		[105428606733839] = { { 1.85, 11.05 } },
		[127287424998997] = {  },
		[115574620758490] = { { 0.75, 4.75 } },
		[127828014236660] = { { 0.90, 6.05 } },
		-- BAD-ATEEZ
		[99917032910194] = { { 0.00, 4.00 } },
		[101690327843945] = { { 0.00, 0.80 }, { 7.90, 10.90 } },
		[106954590912232] = { { 0.15, 5.80 } },
		[86769053357907] = {  },
		[85294537563206] = { { 3.25, 3.85 } },
		[73352408497618] = { { 0.00, 1.25 } },
		[140073525951941] = { { 4.65, 7.65 } },
		[91647545899849] = { { 0.00, 7.25 } },
		[86108317246080] = { { 0.00, 4.90 } },
		[92410075296555] = { { 0.00, 10.10 } },
		[112518247434645] = { { 0.00, 3.80 }, { 5.75, 8.55 } },
		[99913080692802] = { { 0.00, 6.75 }, { 8.65, 10.25 } },
		[130897128636432] = { { 0.10, 5.80 } },
		[114907255207310] = { { 0.00, 6.65 } },
		[79044145915210] = { { 0.10, 6.10 } },
		[138182761294826] = { { 0.00, 7.30 } },
		[90945372575300] = {  },
		[127427471547985] = { { 9.35, 11.95 } },
		[82346668311878] = { { 0.75, 4.80 } },
		[95469533767642] = { { 4.00, 11.10 } },
		[138812417192850] = { { 0.00, 1.85 }, { 4.95, 6.95 } },
		-- Get A Guitar-RIIZE (no reliable windows: plant only)
		[119819611123433] = {  },
		[97097804325917] = {  },
		[119200924904137] = {  },
		[77403973851668] = {  },
		[73939357849033] = {  },
		[137390866303201] = {  },
		[121969021575883] = {  },
		[92148657532352] = {  },
		[96742563282745] = {  },
		[88430566939812] = {  },
		[108795638313983] = {  },
		[95813030011960] = {  },
		[135272998171625] = {  },
		[129447992418977] = {  },
		[82252722293006] = {  },
		[108611133102309] = {  },
		[117244778152210] = {  },
		[113505968174557] = {  },
		[112498417388469] = {  },
		[80874196383963] = {  },
		-- Love 119-RIIZE
		[116659270658163] = { { 0.00, 3.45 } },
		[84899474236257] = {  },
		[77269060609340] = {  },
		[84913058689124] = { { 0.00, 9.50 } },
		[101539030624816] = { { 0.00, 1.55 } },
		[75370013537988] = {  },
		[107740496143451] = {  },
		[140553219106220] = { { 0.00, 0.35 } },
		[96534907636929] = {  },
		[133820711201781] = {  },
		[79064359810628] = {  },
		[103495705227564] = { { 0.05, 1.10 } },
		[119064865727357] = {  },
		[127521799015186] = {  },
		[131229132989104] = {  },
		[103134109095683] = {  },
		[83720687579594] = { { 1.40, 3.30 } },
		[107611961518863] = {  },
		[79402676603023] = {  },
		[112123988214223] = { { 0.25, 2.60 } },
		[128563000052459] = { { 3.55, 5.80 } },
		[109633407896106] = {  },
		[103715482617737] = {  },
		[128397106319046] = {  },
		[123213110930819] = { { 0.35, 2.00 } },
		[84387354167133] = {  },
		[81083928741520] = {  },
		[132463155617727] = {  },
		[136973102149586] = {  },
		[98464771574081] = { { 0.45, 1.50 } },
		[76049029842393] = { { 7.75, 9.95 } },
		[117350090855113] = { { 0.00, 5.55 } },
		[95981548117869] = { { 11.30, 11.95 } },
		-- Catch Catch-YENA
		[75443608985712] = { { 0.00, 1.30 } },
		[75353020147525] = {  },
		[98063579481098] = { { 1.20, 11.20 } },
		[98686361929027] = { { 0.00, 6.65 } },
		[112551530516434] = { { 3.35, 4.90 } },
		[98514844125325] = { { 2.05, 11.75 } },
		[74567972410299] = { { 0.00, 14.50 } },
		[110540650870002] = { { 0.00, 11.05 } },
		[130984178299080] = { { 1.05, 5.35 } },
		[128412578867487] = { { 0.80, 1.70 } },
		[74369407507020] = { { 1.70, 2.30 }, { 4.90, 7.35 } },
		[132719886087176] = { { 0.00, 3.25 } },
		[79075546317269] = { { 0.00, 1.00 }, { 5.00, 9.30 } },
		[88923183102495] = { { 0.95, 13.20 } },
		[73949956743570] = { { 0.00, 2.20 }, { 4.65, 7.60 } },
		[89344916640647] = { { 0.00, 1.40 } },
		[110910446284849] = { { 0.00, 1.20 } },
		[114010461044470] = { { 0.00, 11.70 } },
		[115248452065042] = { { 0.00, 0.80 }, { 5.85, 8.45 } },
		[124345431625014] = { { 4.40, 7.30 } },
		[108680095506820] = { { 0.00, 7.10 } },
		[127455820218376] = { { 4.60, 11.85 } },
		-- NEON-A2O LITE
		[118329772913374] = { { 2.00, 5.80 }, { 7.45, 16.55 } },
		[95449015545787] = { { 0.00, 6.65 } },
		[84806571273074] = { { 0.00, 14.25 } },
		[99868719395147] = { { 0.00, 6.10 } },
		[93933273398995] = { { 1.55, 12.60 } },
		[128256391320572] = { { 0.00, 16.95 } },
		[114466589507598] = { { 0.00, 3.25 }, { 4.95, 9.00 } },
		[84027575690735] = { { 0.00, 6.30 } },
		[100410498984971] = { { 0.00, 4.95 } },
		[124518142645731] = { { 1.15, 12.20 } },
		[126736648781925] = { { 0.00, 4.35 } },
		[76437753036430] = { { 0.00, 2.30 } },
		[136355327951443] = { { 0.00, 7.30 } },
		[117451819045051] = { { 0.00, 6.30 } },
		[111932052760637] = { { 0.00, 8.50 } },
		[133401623277764] = { { 0.00, 14.55 } },
		[96973609514230] = { { 0.00, 6.15 }, { 8.20, 16.00 } },
		[106546379406531] = { { 0.00, 7.35 } },
		[73851407273132] = { { 0.00, 8.55 } },
		[71570705300325] = { { 0.00, 21.70 } },
		[121393866689759] = { { 0.00, 7.60 } },
		[114419952125075] = { { 0.00, 9.35 } },
		-- Arrest-ILLIT
		[110040253056586] = { { 2.40, 13.50 } },
		[116782676046427] = { { 0.00, 7.50 } },
		[91788521477193] = {  },
		[130744405360835] = { { 1.75, 5.25 } },
		[75102459386899] = { { 1.10, 4.95 } },
		[128174978668663] = { { 1.65, 7.15 } },
		[100385332540044] = { { 1.10, 2.90 } },
		[76359264534217] = { { 0.00, 11.15 } },
		[99715197125931] = { { 0.00, 12.15 } },
		[92743762405771] = { { 1.85, 5.25 } },
		[108969470552658] = { { 0.00, 3.05 } },
		[87742291719868] = {  },
		[99241032937972] = {  },
		[90778610748932] = { { 3.10, 4.20 } },
		[119318712525281] = { { 0.50, 7.05 } },
		[113529281081668] = { { 0.00, 6.90 } },
		[138780635090818] = { { 0.00, 11.65 } },
		[134859541553614] = { { 0.20, 11.20 } },
		[127453915676688] = { { 0.00, 6.95 } },
		[98926631193332] = { { 1.20, 5.45 } },
		[113936517496560] = { { 0.00, 11.40 } },
		-- LOVE ATTACK-RESCENE
		[109011245162387] = { { 0.45, 1.45 } },
		[77108502823118] = {  },
		[86687841705348] = { { 0.60, 3.80 } },
		[131382757802821] = { { 0.00, 1.20 } },
		[137275968003632] = { { 0.00, 4.60 } },
		[110961201759433] = { { 0.00, 2.30 } },
		[107032969312689] = { { 0.00, 2.60 } },
		[118832898913501] = { { 0.75, 4.95 } },
		[90182725361176] = {  },
		[70453746052130] = { { 0.75, 5.40 } },
		[108475995123642] = { { 0.00, 2.40 } },
		[108964771979987] = {  },
		[88670191702155] = { { 2.55, 12.75 } },
		[115864358490692] = { { 0.00, 3.15 } },
		[111343039783743] = {  },
		[93973196577178] = {  },
		[105227322276080] = { { 8.60, 9.95 } },
		[132442605548936] = {  },
		[97954457634320] = { { 3.35, 7.75 } },
		[76304830605030] = { { 2.40, 7.40 }, { 9.00, 11.60 } },
		[115786464203055] = { { 0.00, 5.10 } },
		[73284838254272] = { { 0.40, 1.25 } },
		[80227668256511] = {  },
		[72915658378938] = { { 0.05, 6.65 } },
		[104212164342204] = { { 6.50, 13.05 } },
		[83427493012714] = {  },
		[78989896538167] = { { 4.40, 7.80 }, { 10.70, 12.45 } },
		-- REDRED-CORTIS
		[74457262116826] = { { 0.40, 2.60 }, { 5.15, 6.90 } },
		[78451293274859] = {  },
		[99354632184083] = {  },
		[133388702168878] = {  },
		[89905442825152] = {  },
		[101510288461879] = { { 2.50, 7.80 } },
		[76336157312311] = { { 0.85, 3.40 } },
		[77329818010081] = { { 1.40, 8.40 } },
		[139026140322649] = { { 0.00, 5.30 } },
		[116978800280311] = { { 1.85, 2.90 } },
		[131666628776868] = { { 0.15, 7.35 }, { 8.65, 10.05 } },
		[131761907712654] = { { 0.90, 11.25 } },
		[80284068432208] = { { 0.00, 4.75 } },
		[89337681817413] = { { 4.25, 8.05 } },
		[81129454597965] = { { 0.00, 4.30 }, { 6.00, 10.50 } },
		[122387053799826] = {  },
		[140062402474513] = {  },
		[116086929837354] = { { 1.40, 3.15 } },
		[71984111187045] = { { 0.00, 1.10 } },
		[121234850587240] = {  },
		[124489277659547] = {  },
		[73438902388486] = { { 3.50, 7.25 } },
		[103007904279324] = { { 8.40, 11.95 } },
		[114253650075143] = { { 0.00, 0.35 }, { 6.05, 9.00 } },
		-- ANIMAL-BOYNEXTDOOR
		[129402890751712] = { { 0.00, 1.80 } },
		[80772039533772] = { { 0.00, 0.65 } },
		[112166541341442] = { { 0.00, 1.85 } },
		[80410028707124] = { { 3.45, 4.45 } },
		[105018508412110] = {  },
		[130036196270388] = { { 1.50, 5.50 } },
		[106354393645678] = { { 0.00, 8.95 } },
		[78895444151768] = { { 0.00, 1.15 } },
		[97744184558515] = { { 0.00, 10.80 } },
		[136955392986245] = { { 0.00, 3.25 } },
		[100329215645751] = { { 4.85, 6.45 } },
		[78840320722064] = { { 6.20, 8.00 } },
		[82639576960460] = {  },
		[104678910693394] = { { 4.00, 7.60 } },
		[82506858822635] = { { 0.30, 5.05 }, { 9.00, 12.05 } },
		[91831034598236] = {  },
		[123997379474433] = { { 0.50, 1.90 } },
		[99593989311395] = {  },
		[132625911221975] = {  },
		[79329885109157] = { { 7.95, 9.55 } },
		[136007113687275] = { { 0.00, 0.85 } },
		[123310558991493] = { { 1.75, 3.05 } },
		[89056804683617] = { { 1.00, 4.75 } },
		[116387739582454] = { { 1.30, 3.35 } },
		[72908007597304] = { { 0.00, 1.25 } },
		-- Pretty Girl-RESCENE
		[100082879569115] = { { 0.15, 5.60 } },
		[104009711978824] = { { 0.00, 5.25 } },
		[108961429650022] = { { 0.20, 2.80 }, { 4.80, 7.10 }, { 9.85, 11.15 } },
		[97208831163609] = { { 0.00, 0.45 } },
		[123817870898356] = { { 0.20, 1.50 } },
		[112928130718608] = { { 0.10, 3.70 } },
		[71674700089963] = {  },
		[78155856168233] = { { 1.40, 6.75 } },
		[119100545362264] = { { 0.00, 4.00 }, { 6.60, 11.55 } },
		[108885997292893] = { { 0.00, 7.10 } },
		[118658921583531] = { { 3.95, 10.25 } },
		[74902277201730] = { { 0.40, 8.10 } },
		[110044834729128] = { { 1.90, 4.80 } },
		[126827294531161] = { { 2.15, 4.15 }, { 6.05, 6.95 } },
		[86500685186308] = { { 0.00, 13.85 } },
		[111523452675311] = { { 0.00, 0.60 } },
		[92430457423477] = { { 0.20, 1.85 } },
		[93265378210483] = { { 0.00, 2.15 } },
		[114627519168898] = { { 1.75, 2.40 } },
		[90231422396171] = { { 5.85, 9.85 } },
		[121645451915137] = { { 0.00, 7.40 } },
		[79626676434376] = { { 8.30, 13.95 } },
		[81645905885514] = { { 0.00, 3.70 }, { 6.60, 10.05 } },
		[100595958841043] = { { 0.00, 1.35 } },
		[84166534427168] = { { 1.65, 5.65 } },
		[117439090388503] = { { 8.65, 13.05 } },
		-- Pop Off-KiiiKiii
		[138378577601803] = {  },
		[79453984815360] = { { 0.25, 5.85 } },
		[133580607498914] = { { 3.35, 5.25 } },
		[137960851963972] = { { 0.00, 3.65 } },
		[74191504239507] = {  },
		[114899602408190] = { { 0.00, 7.60 }, { 13.00, 14.05 } },
		[82593368218356] = { { 0.00, 6.05 }, { 8.00, 9.55 } },
		[89349893602236] = { { 0.00, 4.60 }, { 7.15, 8.90 } },
		[89756644797564] = { { 4.95, 5.75 } },
		[93822640757068] = { { 0.00, 1.55 }, { 7.35, 10.75 } },
		[82985939493186] = {  },
		[89496459962506] = { { 0.00, 4.75 }, { 6.85, 10.65 } },
		[106148688158261] = { { 0.00, 2.60 }, { 5.00, 6.80 } },
		[129561476080724] = { { 0.00, 4.05 } },
		[126423548513152] = { { 0.00, 3.00 } },
		[77783806123063] = { { 2.20, 3.55 } },
		[81082889837351] = { { 2.55, 5.75 } },
		[105511127677230] = { { 1.50, 6.40 } },
		[87535109402600] = {  },
		[114431038976349] = { { 0.10, 4.55 } },
		[77209641618863] = { { 0.00, 4.55 } },
		-- CRASH-ALLDAY PROJECT
		[92063442221105] = { { 0.00, 1.10 } },
		[103881583439894] = { { 0.00, 5.60 } },
		[110262357944188] = { { 0.00, 3.85 } },
		[85184392148752] = { { 0.15, 6.85 } },
		[86200130207984] = { { 2.45, 4.25 }, { 6.45, 7.80 } },
		[109096810120786] = { { 0.00, 12.20 } },
		[108547801175160] = { { 0.00, 5.20 }, { 7.40, 9.35 } },
		[119507357461993] = { { 0.00, 7.70 } },
		[86220019327088] = {  },
		[103539561583468] = { { 0.70, 3.30 } },
		[116383725353409] = {  },
		[124516959620423] = {  },
		[124646840847010] = { { 0.45, 5.00 } },
		[109278338620404] = { { 3.30, 5.50 }, { 7.00, 10.20 } },
		[92004530682011] = { { 3.45, 14.25 } },
		[84989603326490] = { { 0.00, 3.00 } },
		[130905271100211] = { { 0.05, 1.75 } },
		[83612611749583] = { { 0.00, 10.60 } },
		[128860681514235] = { { 0.25, 10.85 } },
		[140259213928051] = { { 0.00, 7.20 } },
		-- SHOCK-TREASURE
		[133830025852955] = { { 2.10, 6.90 } },
		[117322908574417] = { { 3.05, 4.75 } },
		[81779912905543] = { { 1.55, 3.85 } },
		[75987043149726] = {  },
		[126059214767439] = { { 6.50, 7.40 } },
		[131829068826954] = {  },
		[121802134861592] = {  },
		[130135206628110] = {  },
		[87672486893566] = { { 5.15, 10.25 } },
		[130317916502145] = { { 3.65, 5.95 }, { 10.95, 12.10 } },
		[94643800566754] = { { 0.00, 4.85 } },
		[112228957264348] = { { 0.00, 3.05 } },
		[107109971489791] = { { 0.00, 1.10 } },
		[90553036874786] = { { 0.95, 6.80 } },
		[121912364930816] = { { 12.30, 13.20 } },
		[139616314090616] = {  },
		[73160805709614] = { { 1.60, 8.30 } },
		[79170731093199] = {  },
		[94923487573207] = {  },
		[107469099088447] = { { 5.65, 10.20 } },
		[112291434709741] = { { 0.00, 12.10 } },
		-- Baekhwayoran-RESCENE
		[109161757598338] = { { 0.00, 4.80 } },
		[118163879610034] = { { 0.00, 10.05 } },
		[104244800567694] = { { 0.00, 3.75 } },
		[71730365125654] = { { 0.00, 10.55 } },
		[133453398801454] = { { 0.00, 8.15 } },
		[83394388681438] = { { 0.00, 11.00 } },
		[129031824166857] = { { 3.70, 10.85 } },
		[74180602033079] = { { 0.00, 9.10 } },
		[100400560200750] = {  },
		[70716391841768] = {  },
		[105306563598355] = {  },
		[123368765880247] = { { 2.45, 10.00 } },
		[76096143466808] = { { 0.00, 3.15 } },
		[126526542148646] = {  },
		[108852044755937] = {  },
		[82595297491524] = { { 1.85, 5.60 } },
		[100292773355070] = { { 0.00, 4.35 } },
		[72320524127017] = { { 0.00, 4.05 }, { 7.95, 9.05 } },
		[131622951291839] = {  },
		[82878605609824] = {  },
		[118315209448422] = { { 0.75, 4.40 } },
		[116718508120035] = { { 0.00, 0.95 }, { 2.45, 6.65 } },
		[98439541459421] = { { 0.00, 2.65 } },
		[126812347548541] = { { 0.00, 1.05 } },
		[138514282006084] = { { 0.00, 7.10 } },
		[101271170738014] = { { 9.35, 10.35 } },
		[87258411271471] = { { 1.40, 5.45 } },
		[106836976565207] = { { 0.00, 9.35 } },
		[129589571291554] = { { 0.00, 5.95 } },
	} do
		for _, w in ipairs(wins) do addList(id, "still", { from = w[1], to = w[2] }) end
		addList(id, "plant", { from = 0, to = 99, contact = 0.45 })
	end
end

-- (D-2070, AND2BLE-Potion) every piece `plant` (contact 0.45; a foot the dance carries off is stepped), as Magic-Secret (D-2060)
do
	for _, id in ipairs({
		133318654819881, 130711084322752, 126577662119324, 103390008118494,
		95673249740111, 101462515949658, 120104884356350, 81060374021567,
		103367592212025, 87481181692394, 109105261149494, 82954950901794,
		79447997870020, 90931443555959, 125912203000946, 131065498394717,
		72318461434570, 90109383769163, 126059736361594, 129776441704888,
		140702968960287,
-- (D-2071, ILLIT-It's Me) every piece `plant` (contact 0.45; a foot the dance carries off is stepped), as Magic-Secret (D-2060)
do
	for _, id in ipairs({
		114536010136920, 84810215427749, 137400923288167, 92512766209766,
		137374435124337, 97821283727781, 104624038900168, 84767858976240,
		117993086220024, 81568891729334, 115153572280504, 134070700021165,
		74249351083442, 95973678135715, 91164599224585, 127876941649874,
		85806895345522, 73159033431986, 92379882661394,
	}) do
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f.plant == nil then {} elseif f.plant.from then { f.plant } else table.clone(f.plant)
		table.insert(list, { from = 0, to = 99, contact = 0.45 })
		f.plant = list
	end
end

-- (D-1967, user's 3rd 2P list for aespa-Lemonade): legs held where a leg flicked, v3 1:40-2:12 kept in place, 2:13 one even turn
-- (D-1949, 2nd review of Lemonade D-1969 (v2 77 % + v3 23 %): the six v3 pieces had no stay-in-place / planted feet, so
-- 0:59.75-1:10.1 slid 14.9 studs in 9 places and 1:26-1:56.6 51.1 studs in 31 (1:38.7 left foot 6.1); the v3 fancams follow
-- the dancer with the camera, so their travel cannot be trusted) as the v2 pieces (D-1931): `still` outside Lemonade's
-- formation moves (1:32.5-1:34.3, 1:38.8-1:40.8, 0.2 s margins), `plant` on every v3 piece (contact 0.45, steps)
do
	local function addList(id: number, key: string, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f[key] == nil then {} elseif f[key].from then { f[key] } else table.clone(f[key])
		table.insert(list, item)
		f[key] = list
	end
	local ALL = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
	local function allBut(keep: {string}): {string}
		local out = {}
		for _, n in ipairs(ALL) do if not table.find(keep, n) then table.insert(out, n) end end
		return out
	end
	local RIGHT = allBut({ "RightUpperLeg", "RightLowerLeg", "RightFoot" })
	local LEGS = allBut({ "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }) -- hips held too: the feet stay put
	-- "0:01 오른쪽 다리 들썩": the right foot hopped 0.25 stud at song 0.2-0.4 (intro piece 1.65-1.85 s)
	addList(107871857436267, "freeze", { from = 1.5, to = 2.0, ease = 0.12, except = RIGHT })
	-- "0:11 오른쪽 다리 꺾이는 거": the right knee 63 -> 27 -> 37 -> 22 degrees at song 11.4-11.8: held, then one ease
	addList(85687535459003, "freeze", { from = 4.5, to = 4.9, ease = 0.2, except = RIGHT })
	-- "0:38 발바닥 고정": the right foot tapped off the floor 0-0.5 stud through song 38.0-39.3: hips and legs held from 38.0
	addList(139260290712979, "freeze", { from = 6.08, to = 7.4, ease = 0.25, except = LEGS })
	-- "1:23-1:26 왼다리 계속 꺾이는 거 … 가만히 서 있는 걸로 다리 고정": the left foot flicked up 4 times (0.4-0.6 stud)
	addList(135759185323713, "freeze", { from = 6.95, to = 30, ease = 0.3, except = LEGS })
	-- "2:01 / 2:03 오른쪽 다리 순간 꺾이는 거": the right foot shot up 1.9 / 0.85 stud for 0.3 s (v3 piece 14)
	addList(112521190266317, "freeze", { from = 1.75, to = 2.25, ease = 0.15, except = RIGHT })
	addList(112521190266317, "freeze", { from = 4.1, to = 4.5, ease = 0.15, except = RIGHT })
	-- "1:40- (제자리 고정)": v3 from song 100 to the switch at 132.45 stays on its spot
	addList(119706515996739, "still", { from = 6.5, to = 30 })
	for _, id in ipairs({ 102178089107461, 116451294316978, 112521190266317, 126596392429323 }) do addList(id, "still", { from = 0, to = 30 }) end
	-- "2:22 엉덩이 들고 자세 고칠 때 위로 튕기는 거" (with the leg key in 17's pose): the hips' height follows its slow average
	addList(132337331292488, "level", { from = 3.9, to = 4.9, ease = 0.2 })
	-- "2:13 버벅 (회전 쪼끔 반복)": the hips went 101 -> 121 -> 101 degrees as the held facing let go (song 134.1-134.3): one
	-- even turn from where the piece comes in (song 132.45) to 135.35
	-- (D-1968) "1:07-1:10 player 1 제자리에": v3 kept on its spot up to the switch at 70.1
	addList(136573199349283, "still", { from = 9.5, to = 30 })
	addList(104433202165131, "still", { from = 0, to = 30 })
	-- (D-1969) "2:19~ 앉는 거 스무스하게": the hips went up 1.1 and down with a bump at 138.7: one even way down from 138.2
	addList(132337331292488, "level", { from = 0, to = 1.6, ease = 0.2 })
	-- (D-1969) "2:25 일어날 때 위로 튕기는 거" (with 18's blend 2 in ClubPlaylist, which took the 2.3 stud one-frame pop away):
	-- the hips follow their slow average while 17 hands over to 18
	addList(132337331292488, "level", { from = 7.7, to = 9.6, ease = 0.2 })
	addList(76195346888656, "level", { from = 0, to = 1.4, ease = 0.3 })
	local f16 = M.ChoreoFixes[82680550952125] :: any
	f16.spin = { from = 4.8, to = 7.7, ease = "both" }
	for id, wins in {
		[136573199349283] = { { 0.00, 99 } }, -- at 59.75
		[104433202165131] = { { 0.00, 99 } }, -- at 67.5
		[135684881711516] = { { 0.00, 6.30 }, { 8.50, 99 } }, -- at 86
		[119706515996739] = { { 0.00, 3.80 }, { 6.20, 99 } }, -- at 94.8
		[102178089107461] = { { 0.00, 99 } }, -- at 102.9
		[116451294316978] = { { 0.00, 99 } }, -- at 113.5
	} do
		for _, w in ipairs(wins) do addList(id, "still", { from = w[1], to = w[2] }) end
		addList(id, "plant", { from = 0, to = 99, contact = 0.45 })
	end
end

-- (D-1924, was D-1950 on fix/feet-scale-1120; 2nd review of Lemonade v3final2: 0:24.3-0:26.5 the planted feet slid again, 0:25.1 left foot 3.2 studs; D-1969
-- took this piece's hold away for 1.0-3.4 because the noStep hold let the right foot go and took it again in one frame) the
-- video steps from side to side in place here (lifts the foot and puts it down), so this gap gets a hold that steps: the foot
-- is lifted and set down where the step aimed (`landHold`) instead of being held still or left to slide. Put first: the
-- first window that matches counts.
do
	local f = (M.ChoreoFixes[123559029471758] or {}) :: any
	M.ChoreoFixes[123559029471758] = f
	local list = if f.plant == nil then {} elseif f.plant.from then { f.plant } else table.clone(f.plant)
	table.insert(list, 1, { from = 1.0, to = 3.4, contact = 0.45, landHold = true })
	f.plant = list
end

-- (D-1953, 2nd review of Lemonade final3: 2:36.2-2:37.0 the right foot slid 1.7 studs; the capture lifts it a little over
-- the 0.45 contact height there, so the noStep hold (D-1967) let it go and it slid near the floor) a higher contact height
-- for that stretch keeps it held (no steps: D-1967, the user found steps hopping in 2:30-2:37). Put first.
do
	local f = (M.ChoreoFixes[116980798181063] or {}) :: any
	M.ChoreoFixes[116980798181063] = f
	local list = if f.plant == nil then {} elseif f.plant.from then { f.plant } else table.clone(f.plant)
	table.insert(list, 1, { from = 5.0, to = 6.3, contact = 0.75, noStep = true })
	f.plant = list
end

-- (D-1954, 2nd review "잔걸음" Pretty Girl 2:05-2:13 / With 0:27-0:33: standing, a knee bent 25-45 degrees for 0.2-0.4 s
-- every 0.3 s — the capture rocks a standing foot 0.4 studs back and forth, and each time it was 0.35 off its spot the
-- hold made a step of it, lifted) where the video stands with both feet down (Pretty Girl 2:07-2:11, With 0:26.9-0:29.3 /
-- 0:29.7-0:30.8) the hold takes no steps there (noStep, D-1932). Put first.
do
	local function plantFirst(id: number, item: any)
		local f = (M.ChoreoFixes[id] or {}) :: any
		M.ChoreoFixes[id] = f
		local list = if f.plant == nil then {} elseif f.plant.from then { f.plant } else table.clone(f.plant)
		table.insert(list, 1, item)
		f.plant = list
	end
	-- (2nd review of D-1954: from 2:07 the feet stayed 0.8 torso apart; the video brings them together at 2:09.5, so the window starts there)
	plantFirst(86500685186308, { from = 10.4, to = 11.85, contact = 0.45, noStep = true }) -- Pretty Girl 2:09.5-2:11.0 (at 119.11)
	plantFirst(131580629784808, { from = 3.05, to = 5.45, contact = 0.45, noStep = true }) -- With 0:26.9-0:29.3 (at 23.85)
	plantFirst(131580629784808, { from = 5.85, to = 6.95, contact = 0.45, noStep = true }) -- With 0:29.7-0:30.8
end

-- (D-1957, 2nd review of D-1956: BANG 0:34.45-0:34.55 the right hand on the hip flew 0.8 studs out and back; the video keeps it
-- on the waist) the capture straightens the right elbow 124 -> 8 -> 96 degrees in 0.4 s at piece 0.25-0.55 s; the old
-- clean-ups rubbed it out, the key reduction keeps it (a big shape): the right elbow is held through it
do
	local f = (M.ChoreoFixes[105204020323017] or {}) :: any
	M.ChoreoFixes[105204020323017] = f
	local list = if f.freeze == nil then {} elseif f.freeze.from then { f.freeze } else table.clone(f.freeze)
	local others = {}
	for _, n in ipairs({ "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }) do table.insert(others, n) end
	table.insert(list, { from = 0.18, to = 0.66, ease = 0.1, except = others })
	f.freeze = list
end

return M
