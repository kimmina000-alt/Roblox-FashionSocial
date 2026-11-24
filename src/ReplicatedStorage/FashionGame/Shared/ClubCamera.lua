--!strict
-- Stage camera shot lists per club song (D-896, user 2026-11-05: "무대 영상
-- 보내주면 분석해서 카메라 무빙 구현"). StageCameraController films the player
-- with them while the song plays (🎥 in the song banner).
--
-- A song = { video = where the shots come from, shots = { ... } } keyed by the
-- track's soundId. Each shot starts at `at` (ORIGINAL song seconds, the clock
-- of choreography `at`, D-876) and lasts until the next one: a cut.
--   size   framing: how much of the dancer fills the frame top to bottom,
--          a name from SIZES (or studs)
--   yaw    degrees round the dancer from the front (0 = straight in front,
--          + = towards the viewer's right / the dancer's left)
--   pitch  degrees up (+ = from above, looking down; - = from below)
--   roll   degrees of tilt (a dutch angle)
--   pan    sideways shift of the frame (fraction of the frame width)
--   to     the same fields at the end of the shot: the move (zoom = size,
--          orbit / truck = yaw, crane = pitch); `move = { a, b }` = when in the
--          shot (fractions) the move runs, `ease` = "inout" (default), "in",
--          "out" or "linear"
--   fov    lens (degrees), default by size: long lenses on close shots,
--          wide on the crane / audience shots
-- How a list is made (CHOREOGRAPHY.md §13): the video's time = song time +
-- offset (sound matched, tools/choreo/stagecam/align_wide.py over the
-- tools/choreo/sync loudness record), cuts and moves from the video
-- (tools/choreo/stagecam/), then each shot's first / middle / last frame and
-- 0.25 s strips read by eye.

local ClubCamera = {}

export type Pose = { size: (string | number)?, yaw: number?, pitch: number?, roll: number?, pan: number? }
export type Shot = { at: number, size: string | number, yaw: number?, pitch: number?, roll: number?, pan: number?,
	to: Pose?, move: {number}?, ease: string?, fov: number?, cont: boolean? }
export type Song = { video: string, offset: number, shots: {Shot} }
export type View = { height: number, aim: number, yaw: number, pitch: number, roll: number, panX: number, panY: number, fov: number }

-- studs of the dancer's height the frame shows, for an avatar BODY studs tall
-- from feet to the top of the head (StageCameraController scales them, and
-- the aim heights, to the real avatar)
ClubCamera.BODY = 5.5
-- the frame's centre is raised by this much of the frame height: the song
-- banner and the top row of buttons cover the top of a phone screen
ClubCamera.UI_LIFT = 0.15
ClubCamera.SIZES = {
	close = 1.6, -- the face
	bust = 2.6, -- head and chest
	waist = 3.8,
	knee = 5,
	full = 8, -- the whole body and a little floor
	wide = 16, -- the dancer among the others
	xwide = 28, -- the whole stage (crane, from the back of the audience)
}

local function heightOf(size: (string | number)?, default: number): number
	if typeof(size) == "number" then return size end
	if typeof(size) == "string" then return ClubCamera.SIZES[size] or default end
	return default
end

-- where the frame's centre sits, as a fraction of the body from the feet (the
-- face for a close shot, the middle of the body for a full one): the frame's
-- top stays a little above the head
local AIMS = { { 1.6, 0.9 }, { 2.6, 0.84 }, { 3.8, 0.76 }, { 5, 0.66 }, { 8, 0.52 }, { 16, 0.5 } }
local function aimFor(height: number): number
	if height <= AIMS[1][1] then return AIMS[1][2] end
	for i = 2, #AIMS do
		local a, b = AIMS[i - 1], AIMS[i]
		if height <= b[1] then return a[2] + (height - a[1]) / (b[1] - a[1]) * (b[2] - a[2]) end
	end
	return AIMS[#AIMS][2]
end

local function fovFor(height: number): number
	if height <= 3 then return 30 end
	if height <= 8 then return 30 + (height - 3) / 5 * 12 end
	return 42 + math.min(height - 8, 20) / 20 * 18
end

local function ease(kind: string?, u: number): number
	u = math.clamp(u, 0, 1)
	if kind == "linear" then return u end
	if kind == "in" then return u * u * u end
	if kind == "out" then return 1 - (1 - u) ^ 3 end
	return u * u * (3 - 2 * u) -- (inout)
end

-- (D-898) a one-take run (a steadicam among the dancers, no cut): keyframes
-- { t, size, yaw =, pitch =, roll = } become shots that each move from one
-- keyframe to the next, marked `cont` (no cut: StageCameraController keeps
-- following softly instead of jumping). Missing yaw / pitch / roll are 0.
type Key = { [number]: any, yaw: number?, pitch: number?, roll: number?, ease: string? }
-- `ease` (D-899) for every move of the take: "linear" keeps a steady glide
-- through closely spaced keyframes (a one-take steadicam), where "inout"
-- (default) would stop at each
function ClubCamera.take(keys: {Key}, ease: string?): {Shot}
	local out = {}
	for i, k in ipairs(keys) do
		local n = keys[i + 1]
		table.insert(out, {
			at = k[1], size = k[2], yaw = k.yaw, pitch = k.pitch, roll = k.roll,
			to = if n then { size = n[2], yaw = n.yaw or 0, pitch = n.pitch or 0, roll = n.roll or 0 } else nil,
			ease = k.ease or ease, cont = i > 1,
		})
	end
	return out
end
-- a song's shots from plain shots and takes, in order
function ClubCamera.join(parts: {any}): {Shot}
	local out = {}
	for _, p in ipairs(parts) do
		if p.at then table.insert(out, p) else for _, s in ipairs(p) do table.insert(out, s) end end
	end
	-- (D-900) a take's last keyframe only says where its move ends: when the
	-- next shot cuts in at that moment, the cut wins (no zero-length shot)
	table.sort(out, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return (a.cont and 1 or 0) < (b.cont and 1 or 0)
	end)
	local kept = {}
	for _, s in ipairs(out) do
		local last = kept[#kept]
		if not (last and math.abs(last.at - s.at) < 1e-6) then table.insert(kept, s) end
	end
	return kept
end

-- the shot list of a track, or nil
ClubCamera.Songs = {} :: {[number]: Song}

function ClubCamera.forTrack(track: { soundId: number }): Song?
	return ClubCamera.Songs[track.soundId]
end

-- the shot at song time t (and its index): before the first `at` there is none
function ClubCamera.shotAt(song: Song, t: number): (number, Shot?)
	local shots = song.shots
	local lo, hi = 1, #shots
	if #shots == 0 or t < shots[1].at then return 0, nil end
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if shots[mid].at <= t then lo = mid else hi = mid - 1 end
	end
	return lo, shots[lo]
end

-- where shot i ends (the next cut; the last shot runs 4 s)
function ClubCamera.shotEnd(song: Song, i: number): number
	local nextShot = song.shots[i + 1]
	return if nextShot then nextShot.at else song.shots[i].at + 4
end

-- the camera for shot `shot` at song time t (it ends at `stop`)
function ClubCamera.view(shot: Shot, t: number, stop: number): View
	local span = math.max(stop - shot.at, 0.05)
	local u = (t - shot.at) / span
	local move = shot.move or { 0, 1 }
	local p = ease(shot.ease, (u - move[1]) / math.max(move[2] - move[1], 0.01))
	local to = shot.to or {}
	local h0 = heightOf(shot.size, 5)
	local h1 = heightOf(to.size, h0)
	-- a zoom moves evenly in the picture: in log size
	local height = h0 * (h1 / h0) ^ p
	local function lerp(a: number?, b: number?): number
		local x = a or 0
		local y = if b == nil then x else b
		return x + (y - x) * p
	end
	return {
		height = height,
		aim = aimFor(height),
		yaw = lerp(shot.yaw, to.yaw),
		pitch = lerp(shot.pitch, to.pitch),
		roll = lerp(shot.roll, to.roll),
		panX = lerp(shot.pan, to.pan),
		panY = 0,
		fov = shot.fov or fovFor(height),
	}
end

-- ATEEZ-BAD: SBS 인기가요 2026-06-28 stage (youtube R9hv2cLYK-w), video =
-- song + 12.15 s (loudness matched over the whole song, no drift, D-896).
-- 97 shots: cuts from the video (hard cuts, plus the soft ones of the
-- whips / flashes checked by eye), sizes and moves read from the frames.
-- (D-975) now 120615582016729 (fileSpeed 1.1): same song clock; was 134942349436280
ClubCamera.Songs[120615582016729] = {
	video = "SBS Inkigayo 2026-06-28, youtube R9hv2cLYK-w",
	offset = 12.15,
	shots = {
		-- intro: the dancers on the runway, the camera low in the aisle
		{ at = 0, size = "xwide", pitch = 3, to = { size = 20 } },
		{ at = 3.12, size = "wide", pitch = 6 },
		{ at = 3.38, size = 18, pitch = 4, to = { size = 22, pitch = 10 } },
		{ at = 4.35, size = "waist", pitch = -5, to = { pitch = 0 } },
		{ at = 5.48, size = "xwide", yaw = -20, pitch = 30, to = { yaw = -10 }, ease = "linear" },
		{ at = 6.32, size = "knee", yaw = 10, to = { size = "wide", yaw = 35, pitch = 15 }, move = { 0.45, 1 }, ease = "in" },
		{ at = 8.22, size = "waist", yaw = -10, pitch = 2, roll = -3, to = { roll = 2 } },
		{ at = 10.05, size = "xwide", pitch = 4, to = { size = "full" }, fov = 25 },
		-- verse 1: a steadicam circling the centre
		{ at = 12.05, size = "knee", yaw = 40, pitch = 3, to = { size = "waist", yaw = -30, pitch = 0 }, ease = "linear" },
		{ at = 21.92, size = "wide", pitch = 2, to = { size = "bust" }, move = { 0.3, 1 } },
		{ at = 23.35, size = "bust", yaw = 25 },
		{ at = 23.72, size = "full", pitch = 6, to = { size = 9.5 } },
		{ at = 25.32, size = "bust", yaw = -15, roll = -6, to = { roll = 4 } },
		{ at = 27.48, size = "full", yaw = 10, to = { size = "bust", yaw = 0 } },
		{ at = 31.28, size = "xwide", pitch = 8, to = { size = "knee", pitch = 2 } },
		{ at = 34.88, size = "knee", yaw = -30, pitch = -6, to = { yaw = -10 }, ease = "linear" },
		{ at = 39.22, size = "bust", to = { size = "xwide", pitch = 25 }, move = { 0.37, 0.8 }, ease = "in" },
		{ at = 41.32, size = "waist", yaw = 10, to = { size = 3.2 } },
		{ at = 44.85, size = "wide", pitch = 3 },
		{ at = 45.6, size = "waist", to = { size = "bust" } },
		-- chorus 1
		{ at = 46.95, size = "xwide", yaw = -35, pitch = 25, to = { size = "full", yaw = -15, pitch = 10 } },
		{ at = 49.25, size = "waist", yaw = 15, to = { size = "knee" } },
		{ at = 51.68, size = "bust", yaw = -10, roll = -10 },
		{ at = 52.78, size = "waist", yaw = 20, pitch = -8 },
		-- (the crane is down at the front by 56.0, then the shot creeps in)
		{ at = 54.72, size = "xwide", yaw = -40, pitch = 45, roll = -25, to = { size = "knee", yaw = 0, pitch = 5, roll = 0 }, move = { 0, 0.45 }, ease = "out" },
		{ at = 58.52, size = "full", yaw = -45, pitch = -2, to = { size = "bust", yaw = -20 } },
		{ at = 62.32, size = "wide", pitch = 3 },
		{ at = 63.22, size = "bust", yaw = 20, to = { size = "wide", yaw = 0, pitch = 6 }, move = { 0.6, 1 }, ease = "in" },
		{ at = 65.15, size = "bust", yaw = -15 },
		{ at = 66.15, size = "full", yaw = 15, to = { size = "knee", yaw = 0 } },
		-- verse 2
		{ at = 70.62, size = "xwide", pitch = 10, to = { size = "knee", pitch = 2 } },
		{ at = 73.72, size = "bust", roll = -12, to = { roll = 0 } },
		{ at = 74.52, size = "wide", yaw = -10, pitch = 8, to = { yaw = 10 }, ease = "linear" },
		{ at = 75.88, size = "knee", to = { size = "waist" } },
		{ at = 81.15, size = "bust", yaw = 30 },
		{ at = 82.15, size = "wide", yaw = -25, pitch = 20, to = { size = "full", pitch = 10 } },
		{ at = 84.68, size = "knee", to = { size = "bust" } },
		{ at = 87.62, size = "wide", yaw = -30, to = { size = "full" } },
		{ at = 89.08, size = "full", yaw = 15 },
		{ at = 89.55, size = "full", yaw = 10, to = { size = "bust", yaw = 0, roll = 8 } },
		{ at = 91.48, size = "wide", pitch = 18, to = { size = 19 } },
		{ at = 91.98, size = "bust", to = { size = "close" } },
		{ at = 95.5, size = "xwide", pitch = 4 },
		-- chorus 2
		{ at = 97.22, size = "waist", pitch = -8 },
		{ at = 98.25, size = "knee", yaw = -20, pitch = -4 },
		{ at = 99.08, size = "full", to = { size = "knee" } },
		{ at = 100.0, size = "bust", yaw = 10, to = { size = "close" } },
		{ at = 101.2, size = "xwide", yaw = 30, pitch = 25, to = { pitch = 15 } },
		{ at = 102.22, size = "bust", yaw = 15, to = { size = "close" }, move = { 0.4, 1 } },
		{ at = 103.15, size = "wide", pitch = -2, to = { size = "knee", pitch = 2 } },
		{ at = 108.75, size = "knee", yaw = -10, to = { size = "waist" } },
		{ at = 110.75, size = "wide", pitch = 10 },
		{ at = 111.25, size = "wide", yaw = 20, to = { size = "bust" } },
		{ at = 112.65, size = "xwide", yaw = -20, pitch = 35, to = { size = "wide", pitch = 25 } },
		{ at = 114.15, size = "full", pitch = 25, to = { size = "knee", pitch = 10 } },
		{ at = 115.22, size = "waist", yaw = 20, pitch = -5 },
		{ at = 116.22, size = "knee", pitch = 5, to = { size = "wide", pitch = 20 }, ease = "in" },
		-- bridge
		{ at = 117.28, size = "bust" },
		{ at = 118.75, size = "xwide", pitch = 5, to = { size = 24 }, ease = "linear" },
		{ at = 121.0, size = "bust", to = { size = "close" } },
		{ at = 122.42, size = "xwide", pitch = 6 },
		{ at = 122.85, size = "wide", pitch = 4, to = { size = 13 } },
		{ at = 123.32, size = "wide", to = { size = "knee" } },
		{ at = 124.28, size = "waist", to = { size = "bust", roll = 6 } },
		{ at = 125.72, size = "waist", to = { size = "close" } },
		{ at = 126.85, size = "wide", yaw = -45, roll = -15, to = { size = "full", roll = 0 } },
		{ at = 128.12, size = "full", yaw = 10, pitch = -3 },
		{ at = 128.62, size = "full", yaw = -10, to = { size = 10 } },
		{ at = 129.08, size = "wide", pitch = 8, to = { size = "xwide", pitch = 15 } },
		{ at = 129.68, size = "bust", roll = 10 },
		{ at = 130.68, size = "xwide", pitch = 22 },
		-- last chorus: quick cuts on the beat
		{ at = 131.68, size = "knee", to = { size = "waist" } },
		{ at = 132.85, size = "waist", to = { size = "full" } },
		{ at = 134.18, size = "wide", pitch = 10 },
		{ at = 134.85, size = "full", yaw = -15 },
		{ at = 135.32, size = "knee", yaw = 10 },
		{ at = 135.82, size = "knee", to = { size = "waist" } },
		{ at = 136.28, size = "waist", to = { size = "bust" } },
		{ at = 137.88, size = "waist", yaw = 15, to = { size = "full" } },
		{ at = 138.38, size = "full", to = { size = "wide" } },
		{ at = 138.85, size = "wide", pitch = 8 },
		{ at = 139.15, size = "waist" },
		{ at = 141.7, size = "bust" },
		{ at = 142.0, size = "knee", to = { size = "xwide", pitch = 6 }, ease = "in" },
		{ at = 143.88, size = "bust", roll = 10, to = { roll = -5 } },
		{ at = 145.08, size = "bust", yaw = -10 },
		{ at = 145.55, size = "bust" },
		{ at = 145.75, size = "xwide", pitch = 10 },
		{ at = 146.52, size = "wide", pitch = 8 },
		{ at = 146.98, size = "full", to = { size = "knee" } },
		{ at = 147.48, size = "knee" },
		{ at = 147.95, size = "knee", to = { size = "waist" } },
		{ at = 148.42, size = "waist", to = { size = "bust" } },
		{ at = 148.92, size = "bust" },
		{ at = 149.55, size = "wide", yaw = -15, pitch = 12, to = { yaw = 5 }, ease = "linear" },
		{ at = 150.95, size = "bust", to = { size = "knee" } },
		{ at = 153.02, size = "bust" },
	},
}

-- A2O LITE-NEON: MBC Show! Music Core 2026-10-24 stage (youtube pKvx_bN74j4,
-- its first half; the second half is a fixed full-stage camera), video =
-- song + 1.00 s (loudness matched over the whole song, no drift, D-898).
-- Mostly long steadicam takes moving round the members (take: keyframes read
-- from 0.5 s strips), beat cuts in the intro, crane / audience wides between.
-- (D-922) the new upload 74988982712396 (was 97511700575810): same song clock
local take = ClubCamera.take
-- (D-932) now 140713297574648 (fileSpeed 1.05): same song clock
ClubCamera.Songs[140713297574648] = {
	video = "MBC Show! Music Core 2026-10-24, youtube pKvx_bN74j4 (first half)",
	offset = 1.0,
	shots = ClubCamera.join({
		-- intro: one take from a bust, back to the two, in and out again
		take({ { 0, "bust" }, { 1.0, "bust" }, { 2.0, 9, pitch = 5 }, { 3.8, 9, yaw = 10, pitch = 4 }, { 4.4, "knee" },
			{ 5.2, "knee", yaw = -10 }, { 5.8, "full" }, { 6.6, "full", yaw = 8 }, { 7.2, "knee", pitch = -5 } }),
		-- beat cuts
		{ at = 7.47, size = "waist", pitch = -8, roll = -12 },
		{ at = 7.93, size = "wide", pitch = 3 },
		{ at = 8.37, size = "full", yaw = 15 },
		{ at = 8.87, size = "wide", yaw = -10, pitch = 3 },
		{ at = 9.3, size = "full", yaw = 5, to = { size = "knee" } },
		{ at = 9.77, size = "knee", to = { size = "waist" } },
		{ at = 10.23, size = "bust", to = { size = "waist" } },
		{ at = 11.13, size = "full", yaw = 10 },
		{ at = 12.07, size = "wide", pitch = 5 },
		{ at = 13.0, size = "full" },
		{ at = 13.47, size = "knee" },
		-- verse 1: a long steadicam take among the members
		take({ { 13.9, "knee" }, { 14.5, "waist", yaw = 10 }, { 15.0, "full" }, { 15.8, "full", yaw = -10 }, { 16.2, "wide", pitch = 4 },
			{ 16.6, "knee" }, { 17.0, "waist" }, { 17.5, "bust", yaw = 10 }, { 18.0, "waist" }, { 18.5, "knee", yaw = -25 },
			{ 19.0, "wide", pitch = 5 }, { 20.2, 14, pitch = 5 }, { 20.6, "knee" }, { 21.6, "waist", yaw = 10 }, { 22.4, "wide", pitch = 4 },
			{ 23.6, "wide", yaw = -8, pitch = 4 }, { 24.0, "knee" }, { 24.6, "waist" }, { 25.6, "bust", yaw = -8 }, { 26.6, "bust", yaw = 8 },
			{ 27.6, "waist" }, { 28.4, "bust" }, { 29.0, "close", yaw = 10 }, { 29.6, "bust" }, { 30.0, "knee" }, { 30.6, "wide", pitch = 10 },
			{ 32.0, "wide", yaw = 10, pitch = 8 }, { 32.5, "waist" }, { 34.0, "waist", yaw = -10 }, { 35.5, "waist" }, { 36.0, "bust" },
			{ 36.6, "bust", yaw = 10 }, { 37.0, "wide", pitch = 12 }, { 38.2, "wide", yaw = -10, pitch = 12 }, { 38.6, "bust" }, { 39.1, "bust" },
			{ 39.6, "knee" }, { 40.2, "wide", pitch = 6 }, { 41.2, "wide", pitch = 6 }, { 41.7, "knee" } }),
		-- pre-chorus
		take({ { 42.07, "knee" }, { 43.0, "knee", yaw = 10 } }),
		take({ { 43.53, "bust" }, { 44.4, "waist", yaw = -10 } }),
		take({ { 44.77, "bust", roll = -6 }, { 45.5, "knee" }, { 46.0, "wide", pitch = 6 }, { 46.6, "full" } }),
		{ at = 47.2, size = "waist", yaw = 15 },
		-- (D-963, user 2026-11-07: "0:50 무릎 꿇고 멈춰 있을 때 얼굴 위주로, 천천히 조금만
		-- 돌기") piece 5 kneels still from 49.8 to 52.0 (feat/choreo-fixes-1107): in to the face
		-- while kneeling down, then a slow small turn until it gets up
		take({ { 48.3, "full", yaw = 20 }, { 49.8, "close", yaw = -6 }, { 52.0, "close", yaw = 6 } }),
		take({ { 52.0, "close", roll = -15 }, { 52.6, "bust" }, { 53.0, "xwide", pitch = 4 },
			{ 55.6, "xwide", pitch = 4 }, { 56.0, "full" }, { 56.6, "full", yaw = 10 }, { 57.0, "waist" }, { 57.5, "bust" }, { 58.0, "waist" } }),
		{ at = 58.5, size = "xwide", pitch = 20 },
		-- chorus 1
		take({ { 59.13, "wide", pitch = 4 }, { 60.0, "full" }, { 61.5, "full", yaw = -10 }, { 62.0, "bust" }, { 62.6, "bust", yaw = 8 },
			{ 63.0, "wide", pitch = 6 }, { 63.6, "wide", pitch = 10 }, { 64.4, "wide", pitch = 10 } }),
		take({ { 64.53, "bust", roll = 8 }, { 65.6, "bust" } }),
		take({ { 66.0, "wide", yaw = -25, pitch = 15 }, { 67.0, "wide", pitch = 8 }, { 67.5, "knee", yaw = 20 }, { 68.2, "knee" } }),
		take({ { 68.73, "waist", yaw = 15 }, { 69.6, "waist" } }),
		take({ { 70.17, "bust" }, { 71.5, "bust", yaw = -10 }, { 72.0, "wide", pitch = 5 }, { 73.0, "knee" } }),
		take({ { 73.33, "xwide", pitch = 8 }, { 74.5, "wide", pitch = 6 }, { 75.0, "bust" }, { 75.5, "wide", pitch = 5 }, { 76.0, "knee" },
			{ 76.6, "waist" }, { 77.1, "waist", yaw = 10 }, { 77.5, "wide", pitch = 6 }, { 78.0, "full" }, { 79.0, "knee" } }),
		take({ { 79.4, "bust" }, { 80.2, "close" }, { 81.0, "bust" } }),
		take({ { 81.03, "xwide", pitch = 15 }, { 82.5, "wide", pitch = 8 }, { 83.5, "full" }, { 84.0, "knee" }, { 85.5, "waist" } }),
		take({ { 85.97, "bust" }, { 86.6, "bust", yaw = 8 }, { 87.0, "close" }, { 87.8, "close", yaw = -10 }, { 88.5, "full" }, { 89.0, "wide", pitch = 5 },
			{ 91.4, "wide", yaw = 10, pitch = 5 } }),
		-- verse 2
		take({ { 91.57, "bust" }, { 92.6, "bust", yaw = 10 }, { 93.0, "knee" }, { 94.5, "waist" } }),
		take({ { 95.17, "xwide", pitch = 6 }, { 96.0, "wide", pitch = 5 }, { 97.0, "full" }, { 98.0, "full", yaw = 10 }, { 98.5, "waist" },
			{ 99.6, "waist", yaw = -10 }, { 100.0, "knee" }, { 100.5, "wide", pitch = 6 }, { 102.0, "wide", yaw = -10, pitch = 6 } }),
		take({ { 102.5, "waist" }, { 103.2, "bust" }, { 104.2, "bust", yaw = 10 } }),
		take({ { 104.4, "bust", roll = -6 }, { 105.0, "waist" }, { 105.5, "knee" }, { 106.0, "wide", pitch = 6 }, { 107.6, "wide", yaw = 10, pitch = 6 } }),
		take({ { 108.0, "waist" }, { 108.6, "bust" }, { 110.0, "bust", yaw = -8 } }),
		take({ { 110.17, "bust" }, { 110.6, "waist" }, { 111.0, "knee" }, { 111.5, "full", pitch = 15 }, { 112.4, "full", pitch = 12 } }),
		take({ { 112.63, "bust", roll = 8 }, { 113.0, "wide", pitch = 6 }, { 113.6, "wide", pitch = 6 }, { 114.0, "knee" }, { 114.5, "waist" },
			{ 115.0, "wide", pitch = 6 }, { 116.2, "wide", pitch = 6 } }),
		take({ { 116.37, "bust" }, { 117.0, "bust", yaw = 10 }, { 117.5, "waist" }, { 118.0, "full" }, { 118.6, "wide", pitch = 5 }, { 119.0, "bust" } }),
		take({ { 119.57, "waist" }, { 120.0, "wide", pitch = 6 }, { 122.0, "wide", yaw = -10, pitch = 6 }, { 122.5, "waist" }, { 123.0, "waist", yaw = 10 },
			{ 123.5, "bust" }, { 124.2, "bust" }, { 124.6, "waist" }, { 125.2, "wide", pitch = 5 } }),
		take({ { 125.63, "wide", pitch = 5 }, { 126.0, "waist" }, { 126.6, "waist", yaw = 10 } }),
		-- chorus 2
		take({ { 126.97, "wide", pitch = 5 }, { 129.5, "wide", yaw = -10, pitch = 5 }, { 130.0, "bust" }, { 130.6, "bust" }, { 131.0, "wide", pitch = 6 },
			{ 133.0, "wide", yaw = 10, pitch = 6 }, { 133.5, "bust" }, { 134.3, "bust", yaw = 8 } }),
		take({ { 134.47, "wide", pitch = 5 }, { 135.0, "knee" }, { 135.5, "full" }, { 136.0, "knee" }, { 136.5, "full", pitch = 15 }, { 137.0, "waist" },
			{ 137.6, "waist", yaw = 10 }, { 138.0, "wide", pitch = 6 }, { 138.6, "wide", pitch = 6 }, { 139.0, "knee" }, { 139.5, "wide", pitch = 6 },
			{ 140.2, "wide", pitch = 6 }, { 140.6, "knee" }, { 141.0, "full" }, { 141.5, "knee" }, { 142.0, "waist" } }),
		take({ { 142.23, "wide", pitch = 6 }, { 143.0, "wide", pitch = 6 }, { 143.5, "knee" }, { 144.0, "waist" }, { 144.5, "wide", pitch = 5 },
			{ 145.0, "wide", pitch = 5 }, { 145.5, "waist" } }),
		-- bridge: (D-963, user 2026-11-07: "2:33 허리 숙이고 멈춰 있을 때 카메라가 천천히
		-- 멀어지게, 앞뒤와 자연스럽게") piece 17 stays bent over from 149.3 to 155.2
		-- (feat/choreo-fixes-1107): one take from the waist shot slowly back to a wide, then in to
		-- the knee shot the next take starts with (no cut on either side)
		take({ { 145.93, "waist" }, { 146.5, "knee" }, { 147.0, "wide", pitch = 6 }, { 148.6, "wide", yaw = 10, pitch = 6 }, { 149.3, "waist" },
			{ 155.2, "wide", pitch = 6 }, { 156.73, "knee" } }),
		take({ { 156.73, "knee" }, { 157.5, "full" }, { 158.0, "wide", pitch = 6 }, { 158.6, "wide", pitch = 6 }, { 159.0, "knee" }, { 159.6, "knee", yaw = 10 },
			{ 160.0, "waist" }, { 160.5, "waist", roll = -10 }, { 161.0, "knee" }, { 161.5, "wide", pitch = 6 }, { 164.0, "wide", yaw = 10, pitch = 6 } }),
		{ at = 164.4, size = "bust" },
		take({ { 165.1, "wide", pitch = 6 }, { 165.5, "xwide", pitch = 5 }, { 166.0, "wide", pitch = 5 }, { 166.5, "full" }, { 167.3, "waist" } }),
		take({ { 167.7, "bust" }, { 168.0, "xwide", pitch = 8 }, { 168.6, "xwide", pitch = 8 }, { 169.0, "wide", pitch = 5 }, { 169.5, "knee" }, { 170.0, "waist" },
			{ 170.6, "wide", pitch = 5 } }),
		{ at = 170.87, size = "wide", pitch = 6 },
		-- last chorus
		take({ { 171.73, "waist" }, { 172.5, "bust" }, { 173.0, "waist" }, { 173.6, "waist", yaw = 10 }, { 174.0, "bust" }, { 174.6, "bust", yaw = -8 },
			{ 175.2, "waist" } }),
		take({ { 175.5, "wide", pitch = 5 }, { 176.0, "xwide", pitch = 5 }, { 177.6, "xwide", yaw = 10, pitch = 5 } }),
		take({ { 177.83, "bust" }, { 178.2, "knee" }, { 179.0, "knee", yaw = 10 } }),
		take({ { 179.27, "knee" }, { 180.0, "bust" }, { 180.6, "close" } }),
		take({ { 180.97, "knee" }, { 182.0, "knee", yaw = -10 }, { 182.5, "waist" } }),
		take({ { 182.77, "xwide", pitch = 6 }, { 183.5, "wide", pitch = 5 }, { 185.0, "wide", yaw = 10, pitch = 5 }, { 185.6, "waist" } }),
		{ at = 186.13, size = "waist", yaw = -10 },
		take({ { 186.63, "knee" }, { 187.5, "waist" }, { 188.1, "waist", yaw = 10 } }),
		take({ { 188.33, "xwide", pitch = 15 }, { 189.5, "wide", pitch = 10 } }),
		take({ { 190.57, "wide", pitch = 6 }, { 191.0, "waist" }, { 191.6, "bust" }, { 192.5, "waist" }, { 193.0, "wide", pitch = 6 }, { 193.7, "wide", pitch = 6 } }),
		take({ { 193.93, "bust" }, { 194.5, "knee", yaw = 20 }, { 195.0, "waist" }, { 195.5, "waist" } }),
		take({ { 195.7, "xwide", pitch = 18 }, { 196.5, "wide", pitch = 8 }, { 197.0, "knee" }, { 197.5, "waist" }, { 198.6, "waist", yaw = 10 },
			{ 199.0, "wide", pitch = 6 }, { 199.6, "wide", pitch = 6 }, { 200.0, "full" }, { 200.5, "waist" }, { 201.0, "bust" }, { 201.5, "wide", pitch = 6 },
			{ 202.4, "wide", yaw = 10, pitch = 6 } }),
		take({ { 202.63, "wide", pitch = 6 }, { 203.0, "bust" }, { 203.5, "waist" }, { 204.0, "knee" }, { 204.6, "knee", yaw = 10 }, { 205.0, "waist" },
			{ 206.0, "waist", yaw = -10 }, { 206.6, "bust" } }),
		take({ { 206.97, "bust" }, { 207.5, "wide", pitch = 6 }, { 208.6, "wide", pitch = 6 }, { 209.0, "bust" }, { 210.0, "bust", yaw = 10 } }),
		take({ { 210.27, "xwide", pitch = 6 }, { 211.0, "wide", pitch = 6 }, { 211.6, "wide", pitch = 6 }, { 212.0, "waist" }, { 213.0, "waist", yaw = 10 },
			{ 213.5, "bust" }, { 214.0, "bust" }, { 214.5, "wide", pitch = 5 }, { 215.3, "wide", pitch = 5 } }),
		-- ending: the members close together, then the whole line
		take({ { 215.57, "bust" }, { 216.6, "bust", yaw = 8 }, { 217.0, "close" }, { 218.5, "bust" }, { 219.0, "knee" }, { 219.5, "wide", pitch = 4 },
			{ 222.4, "wide", pitch = 4 } }),
		{ at = 222.63, size = "bust" },
	}),
}

-- IVE-Looks Can Kill: KBS Music Bank 2026-10-23 one-take 4K bonus version
-- (youtube d7s-2eLvT8Q), video = song + 1.60 s (loudness matched, no drift,
-- D-899). No cut at all: one steadicam at chest height weaving among the
-- members, in and out on the beat; the "cuts" a frame difference finds are
-- light changes. One take, keyframes from 0.5 s strips, a steady glide.
ClubCamera.Songs[135553051649506] = {
	video = "KBS Music Bank 2026-10-23 one-take 4K bonus, youtube d7s-2eLvT8Q",
	offset = 1.6,
	shots = take({
		{ 0, "wide", pitch = 3 }, { 3.5, "wide", pitch = 3 }, { 4.0, "knee" }, { 5.0, "waist" }, { 6.0, "bust", yaw = 15 }, { 6.5, "waist", yaw = 8 },
		{ 7.5, "bust" }, { 8.0, "knee" }, { 8.5, "waist" }, { 9.0, "knee", yaw = -8 }, { 10.0, "waist" }, { 11.0, "knee" }, { 12.0, "wide", pitch = 3 },
		{ 13.5, "full" }, { 14.0, "knee" }, { 14.5, "waist" }, { 16.0, "waist", yaw = -10 }, { 16.6, "bust" }, { 17.5, "waist" }, { 18.0, "wide", pitch = 3 },
		{ 19.5, "wide", pitch = 3 }, { 20.3, "full" }, { 21.0, "waist" }, { 21.5, "bust", yaw = 8 }, { 22.0, "waist" }, { 23.5, "bust", yaw = -8 },
		{ 24.0, "waist" }, { 25.0, "bust" }, { 25.5, "knee" }, { 26.5, "waist" }, { 27.0, "knee" }, { 27.5, "bust", yaw = 25 }, { 28.0, "full", yaw = 25 },
		{ 28.5, "knee", yaw = 10 }, { 29.5, "bust" }, { 30.0, "knee" }, { 31.0, "full", yaw = -8 }, { 32.0, "waist" }, { 32.5, "knee" }, { 33.0, "waist" },
		{ 34.0, "bust" }, { 34.5, "waist" }, { 35.0, "knee", yaw = 8 }, { 36.0, "waist" }, { 36.5, "bust" }, { 37.5, "waist", yaw = -8 }, { 38.0, "knee" },
		{ 39.5, "waist" }, { 41.5, "knee", yaw = 8 }, { 42.5, "wide", pitch = 3 }, { 43.0, "knee" }, { 44.0, "waist" }, { 45.0, "bust" }, { 45.5, "waist" },
		{ 47.0, "bust", yaw = -8 }, { 47.5, "waist" }, { 48.5, "knee" }, { 49.0, "full" }, { 49.5, "knee", yaw = 8 }, { 51.0, "waist" }, { 52.0, "knee" },
		{ 53.5, "bust", yaw = -8 }, { 54.0, "knee" }, { 55.0, "waist" }, { 55.5, "bust", yaw = 10 }, { 56.0, "waist" }, { 56.5, "knee" }, { 58.5, "waist", yaw = -8 },
		{ 60.0, "knee" }, { 61.0, "bust" }, { 61.5, "knee" }, { 62.5, "waist", yaw = 8 }, { 63.5, "knee" }, { 64.0, "full" }, { 66.0, "knee", yaw = -8 },
		{ 66.5, "waist" }, { 67.0, "bust" }, { 67.5, "waist" }, { 68.0, "knee" }, { 68.5, "full" }, { 69.0, "wide", pitch = 3 }, { 70.0, "full" },
		{ 71.0, "knee", yaw = 8 }, { 72.0, "waist" }, { 73.0, "close" }, { 73.5, "knee" }, { 74.5, "waist", yaw = -8 }, { 75.0, "knee" }, { 76.0, "full" },
		{ 79.0, "wide", pitch = 3 }, { 79.5, "knee" }, { 80.0, "waist" }, { 81.0, "knee", yaw = 8 }, { 81.5, "waist" }, { 82.5, "bust" }, { 83.0, "waist" },
		{ 85.0, "full", yaw = -8 }, { 87.0, "knee" }, { 88.0, "waist" }, { 90.5, "full", yaw = 8 }, { 91.0, "knee" }, { 93.0, "waist" }, { 94.5, "knee", yaw = -8 },
		{ 96.5, "waist" }, { 97.5, "knee" }, { 98.5, "waist", yaw = 8 }, { 100.0, "knee" }, { 100.5, "full" }, { 102.5, "knee" }, { 104.0, "waist", yaw = -8 },
		{ 105.5, "knee" }, { 106.5, "waist" }, { 107.5, "full", yaw = 8 }, { 108.0, "knee" }, { 109.0, "waist" }, { 110.0, "knee" }, { 110.5, "full" },
		{ 112.5, "knee", yaw = -8 }, { 113.5, "waist" }, { 116.0, "knee" }, { 116.5, "full", yaw = 8 }, { 118.5, "knee" }, { 120.0, "waist" },
		{ 120.5, "knee" }, { 121.5, "waist", yaw = -8 }, { 122.0, "knee" }, { 124.5, "full" }, { 126.5, "knee", yaw = 8 }, { 127.0, "waist" }, { 128.0, "knee" },
		{ 128.5, "waist" }, { 130.0, "full", yaw = -8 }, { 133.0, "knee" }, { 134.0, "bust" }, { 134.5, "knee" }, { 135.5, "waist", yaw = 8 }, { 136.5, "knee" },
		{ 137.5, "waist" }, { 138.0, "knee" }, { 139.0, "full", yaw = -8 }, { 140.0, "knee" }, { 140.5, "waist" }, { 141.5, "knee" }, { 142.5, "waist", yaw = 8 },
		{ 146.0, "knee" }, { 147.0, "waist" }, { 148.0, "knee", yaw = -8 }, { 149.0, "full" }, { 149.5, "wide", pitch = 3 }, { 153.0, "wide", pitch = 3 },
		{ 153.5, "knee" }, { 154.0, "waist" }, { 154.5, "bust", yaw = 8 }, { 155.5, "waist" }, { 156.0, "knee" }, { 156.5, "full" }, { 158.5, "knee", yaw = -8 },
		{ 160.0, "waist" }, { 162.0, "knee", yaw = 8 }, { 165.0, "full" }, { 166.0, "wide", pitch = 3 }, { 168.3, "wide", pitch = 3 }, { 168.6, "full" },
		{ 169.0, "knee" }, { 170.5, "waist", yaw = -8 }, { 172.0, "knee" }, { 173.5, "waist", yaw = 8 }, { 174.5, "knee" }, { 175.0, "full" }, { 177.0, "knee" },
		{ 178.0, "waist", yaw = -8 }, { 180.0, "knee" }, { 180.5, "waist" }, { 182.0, "knee", yaw = 8 }, { 183.0, "full" }, { 185.5, "knee" },
		{ 187.0, "waist", yaw = -8 }, { 188.0, "bust" }, { 190.0, "knee" }, { 190.5, "full" }, { 193.0, "full" },
	}, "linear"),
}

-- RIIZE-Get A Guitar: KBS Music Bank 2023-09-08 stage (KBS WORLD TV, youtube
-- EXRHfIvmPIQ), video = song + 3.88 s (loudness matched, no drift, D-900).
-- 55 hard cuts: crane wides from high left, handheld close-ups with whips,
-- low front full shots; moving shots are takes from 0.5 s strips.
-- (D-919) the new upload 133586602463513 (was 91762270038050): same song clock
-- (D-925) now 70738014182544 (fileSpeed 1.05): same song clock
ClubCamera.Songs[70738014182544] = {
	video = "KBS Music Bank 2023-09-08, youtube EXRHfIvmPIQ",
	offset = 3.88,
	shots = ClubCamera.join({
		-- intro (the logo, then the crane)
		take({ { 0, "xwide", yaw = -30, pitch = 25 }, { 0.35, "xwide", yaw = -30, pitch = 25 }, { 2.75, "wide", yaw = -10, pitch = 10 } }),
		take({ { 2.75, "full", yaw = 20 }, { 3.95, "knee", yaw = 10 } }),
		take({ { 3.95, "wide", yaw = 15, pitch = 6 }, { 6.0, "full" }, { 7.45, "knee" } }),
		take({ { 7.45, "bust", pitch = -5 }, { 9.35, "close" } }),
		take({ { 9.35, "wide", pitch = 8 }, { 11.0, "full" }, { 13.5, "knee", yaw = 10 }, { 14.89, "waist" } }),
		take({ { 14.89, "wide", yaw = -25, pitch = 15 }, { 16.0, "full" }, { 17.6, "waist" }, { 19.52, "waist", yaw = 10 } }),
		take({ { 19.52, "wide", pitch = 6 }, { 21.67, "full", yaw = -10 }, { 22.5, "waist" }, { 24.15, "knee" } }),
		-- verse 1: the low front camera dollying in and out, a handheld at 26
		take({ { 24.15, "full", pitch = -4 }, { 26.0, "bust" }, { 27.5, "waist", yaw = 15 }, { 28.5, "full" }, { 30.0, "wide", pitch = 6 }, { 32.0, "full" },
			{ 33.5, "wide", pitch = 6 }, { 35.15, "full" } }),
		{ at = 35.15, size = "knee", yaw = -15 },
		{ at = 35.42, size = "full" },
		take({ { 35.99, "waist", yaw = 15 }, { 38.0, "bust" }, { 39.5, "waist" }, { 41.75, "full" } }),
		take({ { 41.75, "wide", pitch = 5 }, { 43.5, "full", yaw = 10 }, { 45.5, "waist" }, { 47.0, "bust", roll = -6 }, { 49.55, "bust" } }),
		{ at = 49.55, size = "wide", yaw = 15, pitch = 6 },
		take({ { 51.19, "bust", yaw = -15 }, { 54.59, "close" } }),
		take({ { 54.59, "xwide", yaw = -30, pitch = 20 }, { 55.7, "wide", pitch = -6 }, { 56.1, "waist" }, { 56.92, "waist", yaw = 15 } }),
		take({ { 56.92, "wide", yaw = -20, pitch = 15 }, { 59.02, "full" } }),
		take({ { 59.02, "bust" }, { 62.95, "waist", yaw = 10 } }),
		take({ { 62.95, "waist", yaw = -10 }, { 65.62, "bust" } }),
		take({ { 65.62, "wide", yaw = 15, pitch = 8 }, { 67.29, "full" } }),
		take({ { 67.29, "bust", roll = 6 }, { 69.0, "waist" }, { 70.72, "wide", pitch = 6 } }),
		take({ { 70.72, "full", yaw = 15 }, { 72.12, "knee" } }),
		take({ { 72.12, "waist", yaw = -10 }, { 74.0, "bust" }, { 76.29, "waist" } }),
		take({ { 76.29, "wide", pitch = 8 }, { 78.0, "full" }, { 80.35, "wide", pitch = 8 } }),
		-- chorus
		take({ { 80.35, "xwide", yaw = -30, pitch = 20 }, { 81.5, "wide", pitch = 8 }, { 84.32, "wide", yaw = 10, pitch = 6 } }),
		take({ { 84.32, "close", yaw = 15 }, { 86.0, "close" }, { 87.29, "bust" } }),
		{ at = 87.29, size = "xwide", yaw = -20, pitch = 15 },
		{ at = 87.92, size = "wide", pitch = 10 },
		{ at = 88.49, size = "wide", pitch = -4 },
		{ at = 89.59, size = "wide", pitch = 6 },
		take({ { 90.65, "full", yaw = -10 }, { 93.0, "knee" }, { 95.0, "waist", yaw = 10 }, { 96.0, "bust" }, { 98.49, "waist" } }),
		take({ { 98.49, "wide", pitch = 6 }, { 99.85, "full" } }),
		take({ { 99.85, "full", yaw = 15 }, { 102.0, "bust" }, { 104.0, "waist" }, { 105.5, "bust" }, { 107.39, "waist" } }),
		take({ { 107.39, "wide", pitch = 6 }, { 109.0, "full" }, { 110.5, "waist" }, { 111.32, "bust" } }),
		take({ { 111.32, "waist", yaw = -15 }, { 113.0, "bust" }, { 114.62, "close" } }),
		take({ { 114.62, "xwide", yaw = 20, pitch = 20 }, { 116.42, "wide", pitch = 10 } }),
		take({ { 116.42, "bust" }, { 118.0, "waist", yaw = 10 }, { 120.05, "bust" } }),
		take({ { 120.05, "xwide", yaw = -30, pitch = 25 }, { 122.22, "wide", yaw = -15, pitch = 12 } }),
		take({ { 122.22, "full", yaw = 15 }, { 123.69, "waist" } }),
		take({ { 123.69, "wide", pitch = 6 }, { 125.5, "full" }, { 127.72, "wide", pitch = 6 } }),
		-- bridge
		take({ { 127.72, "bust", yaw = -10 }, { 130.65, "waist", yaw = 10 } }),
		take({ { 130.65, "full", pitch = 4 }, { 133.12, "wide", pitch = 6 } }),
		{ at = 133.12, size = "waist", yaw = 15 },
		{ at = 133.39, size = "bust" },
		take({ { 133.85, "waist", yaw = -10 }, { 135.42, "bust" } }),
		take({ { 135.42, "wide", yaw = -20, pitch = 15 }, { 137.82, "full" } }),
		take({ { 137.82, "bust", yaw = 15 }, { 139.75, "close" } }),
		take({ { 139.75, "xwide", yaw = -25, pitch = 20 }, { 141.69, "wide", pitch = 10 } }),
		-- last chorus
		take({ { 141.69, "wide", pitch = 6 }, { 143.5, "full" }, { 146.19, "full" } }),
		take({ { 146.19, "bust" }, { 148.15, "waist", yaw = 10 } }),
		take({ { 148.15, "wide", pitch = 6 }, { 150.29, "full" } }),
		take({ { 150.29, "waist", yaw = 15 }, { 150.59, "waist" } }),
		take({ { 150.59, "wide", pitch = 6 }, { 152.5, "full" }, { 154.95, "full" } }),
		take({ { 154.95, "bust" }, { 157.0, "close" }, { 158.22, "close" } }),
		take({ { 158.22, "wide", yaw = -25, pitch = 18 }, { 161.0, "wide", yaw = -15, pitch = 12 } }),
	}),
}

-- CORTIS-REDRED: Mnet M COUNTDOWN 2026-04-23 first stage (youtube
-- rREZviPAdM8), video = song + 34.5 s (D-902: the even beat gives answers 2 s
-- apart, +32.5 / +34.5; the choreography decides: the song's quiet break at
-- 121.8 s is standing still in the game, and in the video at +34.5 (32.5
-- would be fast dancing)). Fast edit: many cuts on the beat (the video's
-- red / green colour washes are lighting, not cuts), read from 0.5 s strips.
local function cutList(list: {{any}}): {Shot}
	local out = {}
	for _, c in ipairs(list) do
		table.insert(out, { at = c[1], size = c[2], yaw = c[3], pitch = c[4], to = c[5] })
	end
	return out
end
-- (D-932) now 76034005809699 (fileSpeed 1.06): same song clock
ClubCamera.Songs[76034005809699] = {
	video = "Mnet M COUNTDOWN 2026-04-23, youtube rREZviPAdM8",
	offset = 34.5,
	shots = cutList({
		-- intro: the members one by one, then the crew
		{ 0, "wide", 0, 6 }, { 0.2, "bust", 15 }, { 1.5, "bust", -10 }, { 3.0, "bust", 10 }, { 4.0, "waist" },
		{ 4.5, "knee", -15, 0, { size = "wide" } }, { 5.0, "wide", 0, 10 }, { 7.0, "waist", 10, -5 }, { 7.5, "bust" },
		{ 8.5, "close", -10 }, { 9.0, "waist", 10 }, { 9.5, "knee", -15 },
		{ 10.0, "xwide", 0, 8 }, { 11.5, "xwide", 0, 50 }, { 12.0, "waist", 10 }, { 13.5, "bust" },
		{ 14.0, "xwide", 0, 10, { size = "wide" } }, { 16.0, "knee", -20 }, { 16.5, "waist", 15 }, { 17.0, "wide", 0, 6 },
		{ 19.0, "waist", 10 }, { 19.5, "knee" }, { 20.0, "wide", -15, 8 }, { 21.0, "waist", 10 }, { 21.5, "bust" },
		-- verse 1
		{ 22.0, "xwide", 0, 8 }, { 25.0, "knee", -10 }, { 25.5, "full" }, { 26.0, "waist", 15 }, { 27.0, "bust" },
		{ 28.0, "xwide", 0, 12, { size = "wide" } }, { 30.0, "bust", 10 }, { 31.0, "waist" }, { 31.5, "wide", 0, 6 },
		{ 35.0, "knee", -10 }, { 35.5, "xwide", 0, 8 }, { 37.0, "full", 10 }, { 37.5, "waist" },
		{ 38.0, "xwide", 0, 45 }, { 38.5, "wide", 0, 20 }, { 40.0, "xwide", 0, 10 }, { 42.0, "wide", 0, 6 },
		{ 44.0, "knee", 15 }, { 45.0, "waist" }, { 46.0, "wide", 0, 8 }, { 47.0, "waist", -10 }, { 48.0, "full" },
		{ 48.5, "wide", 0, 6 }, { 50.0, "waist", 10 }, { 52.0, "wide", 0, 8 }, { 54.0, "knee", -10 }, { 55.0, "waist", 15 },
		-- chorus 1
		{ 56.0, "xwide", 0, 10 }, { 57.0, "wide", 0, 6 }, { 58.0, "full" }, { 60.0, "waist", 10 }, { 61.0, "wide", 0, 6 },
		{ 63.0, "waist", -10 }, { 64.0, "xwide", 0, 10 }, { 65.0, "wide", 0, 6 }, { 68.0, "knee", 0, -10 }, { 68.5, "waist", 10 },
		{ 70.0, "wide", 0, 6 }, { 72.0, "bust", 15 }, { 73.5, "knee", -10 }, { 74.0, "wide", 0, 8 }, { 75.5, "knee", 0, -10 },
		{ 76.5, "waist", 10 }, { 77.5, "wide", 0, 6 }, { 78.0, "full", 10 }, { 78.5, "waist" }, { 79.5, "knee", -10 },
		-- verse 2
		{ 80.0, "wide", 0, 6 }, { 82.0, "waist", 10 }, { 84.0, "knee", -10 }, { 85.0, "waist" }, { 86.0, "wide", 0, 6 },
		{ 86.5, "knee", 10 }, { 87.5, "wide", 0, 8 }, { 90.5, "waist", -10 }, { 91.0, "bust" }, { 91.5, "waist" },
		{ 92.0, "wide", 0, 6 }, { 93.5, "knee", 10 }, { 94.0, "waist" }, { 95.0, "knee", -10 }, { 95.5, "wide", 0, 6 },
		{ 98.0, "waist", 10 }, { 99.5, "wide", 0, 8 }, { 101.0, "waist", -10 }, { 101.5, "xwide", 0, 45 }, { 102.0, "wide", 0, 20 },
		{ 103.5, "xwide", 0, 10 }, { 104.5, "wide", 0, 6 }, { 105.5, "waist", 10 }, { 107.5, "wide", 0, 8 },
		{ 108.5, "waist", -10 }, { 109.5, "wide", 0, 6 }, { 112.0, "knee", 10 }, { 112.5, "waist" },
		{ 113.0, "xwide", 0, 10 }, { 114.0, "wide", 0, 6 }, { 115.5, "waist", -10 }, { 117.5, "wide", 0, 6 },
		{ 118.5, "waist", 10 }, { 119.5, "wide", 0, 8 },
		-- the quiet break: a close-up of the singer
		{ 121.0, "bust" }, { 122.5, "wide", 0, 6 }, { 124.0, "full", 10 }, { 125.0, "waist" }, { 126.0, "wide", 0, 6 },
		{ 127.0, "xwide", 0, 10 }, { 129.5, "xwide", 0, 50 }, { 131.5, "waist", 10 }, { 133.5, "wide", 0, 6 },
		{ 135.5, "bust", -10 }, { 137.0, "waist" }, { 137.5, "wide", 0, 6 }, { 139.5, "waist", 10 }, { 141.5, "wide", 0, 6 },
		{ 142.5, "waist", -10 },
		-- last chorus
		{ 143.0, "xwide", 0, 10 }, { 144.5, "wide", 0, 6 }, { 146.0, "waist", 10 }, { 147.0, "wide", 0, 6 },
		{ 149.5, "waist", -10 }, { 151.0, "xwide", 0, 10 }, { 153.0, "wide", 0, 6 }, { 155.0, "bust", 10 }, { 155.5, "waist" },
		{ 156.0, "wide", 0, 6 }, { 157.0, "waist", -10 }, { 157.5, "bust" }, { 158.0, "waist", 10 }, { 159.5, "wide", 0, 6 },
		{ 162.0, "close", 10 },
	}),
}

-- 소녀시대-소원을 말해봐(Genie): MBC Show! Music Core 2009-07-18 rooftop
-- helipad stage (MBCkpop, youtube z3RTc-8J3CU), video = song - 14.8 s (D-904:
-- the video starts after the song's intro; 17 of 21 loudness windows -14.80).
-- Shots read from 0.5 s strips in VIDEO seconds (cuts on the beat; high crane
-- and helicopter shots of the helipad, low shots of the legs).
local function videoCuts(offset: number, list: {{any}}): {Shot}
	local out = {}
	for _, c in ipairs(list) do
		table.insert(out, { at = math.max(c[1] - offset, 0), size = c[2], yaw = c[3], pitch = c[4], to = c[5] })
	end
	return out
end
ClubCamera.Songs[128270208751659] = {
	video = "MBC Show! Music Core 2009-07-18, youtube z3RTc-8J3CU",
	offset = -14.8,
	shots = videoCuts(-14.8, {
		-- (the song's intro before the video: the whole rooftop from high up)
		{ -14.8, "xwide", 0, 25 }, { 4.5, "full", 0, -8, { size = "knee" } },
		{ 7.0, "bust" }, { 8.0, "waist", 10 }, { 8.5, "full" }, { 9.5, "bust" }, { 11.5, "close", -10 }, { 13.5, "waist" },
		{ 15.0, "wide", 0, 5 }, { 17.5, "close", 10 }, { 18.5, "bust" }, { 20.0, "xwide", -30, 10 }, { 21.5, "knee" },
		{ 23.5, "wide", 0, 5 }, { 26.0, "bust", 10 }, { 27.0, "bust" }, { 28.5, "xwide", -30, 10 }, { 29.5, "wide", 0, 5 },
		{ 32.5, "waist" }, { 36.5, "wide", 0, 5 }, { 38.0, "xwide", -30, 10 }, { 39.0, "bust" }, { 41.0, "xwide", 0, 35 },
		{ 43.0, "bust" }, { 44.0, "wide", 0, 5 }, { 46.0, "bust", 10 }, { 48.0, "wide", 0, 35 }, { 49.5, "bust" },
		{ 51.0, "xwide", 0, 80 }, { 53.0, "bust" }, { 55.0, "wide", 0, 8 }, { 57.0, "bust" }, { 59.0, "wide", 0, 8 },
		{ 61.5, "xwide", -30, 10 }, { 63.0, "knee", 0, -12 }, { 64.5, "waist" }, { 65.0, "xwide", 0, 30 }, { 67.5, "waist" },
		{ 69.0, "bust", -10 }, { 70.5, "wide", 0, 6 }, { 72.5, "bust", 15 }, { 74.0, "xwide", 0, 40 }, { 75.5, "bust" },
		{ 78.0, "wide", 0, 6 }, { 80.0, "waist" }, { 81.0, "xwide", 0, 35 }, { 82.0, "bust", -10 }, { 84.0, "wide", 0, 6 },
		{ 86.0, "waist" }, { 88.0, "xwide", 0, 35 }, { 89.5, "close" }, { 91.0, "knee" }, { 92.0, "wide", 0, 6 },
		{ 94.0, "waist" }, { 95.0, "knee" }, { 96.0, "waist" }, { 97.0, "wide", 0, 6 }, { 98.0, "knee" },
		{ 99.0, "xwide", -30, 8 }, { 100.5, "waist" }, { 103.5, "xwide", 0, 70 }, { 105.5, "knee" }, { 108.0, "wide", 0, 6 },
		{ 109.5, "knee", 0, -12 }, { 110.5, "bust" }, { 112.5, "wide", 0, 6 }, { 114.0, "bust" }, { 116.0, "xwide", -30, 8 },
		{ 117.5, "waist" }, { 121.5, "wide", 0, 6 }, { 124.0, "knee" }, { 125.0, "waist" }, { 127.5, "wide", 0, 35 },
		{ 129.0, "waist" }, { 131.5, "wide", 0, 6 }, { 133.0, "waist" }, { 134.5, "wide", 0, 6 }, { 137.0, "xwide", -30, 8 },
		{ 137.5, "wide", 0, 6 }, { 138.5, "close", 10 }, { 141.0, "wide", 0, 6 }, { 144.5, "xwide", 0, 55 }, { 146.0, "waist" },
		{ 148.5, "wide", 0, 6 }, { 150.0, "close" }, { 151.5, "waist" }, { 153.0, "wide", 0, 6 }, { 155.0, "wide", 20, 20 },
		{ 156.5, "wide", 0, 6 }, { 158.5, "knee" }, { 160.5, "xwide", -30, 8 }, { 162.0, "bust" }, { 164.5, "xwide", 0, 8 },
		{ 166.5, "wide", 0, 25 }, { 168.0, "wide", 0, 6 }, { 169.5, "knee", 0, -8 }, { 172.0, "xwide", -30, 8 }, { 174.5, "knee" },
		{ 176.0, "wide", 0, 30 }, { 177.5, "waist" }, { 180.5, "wide", 0, 30 }, { 183.5, "knee", 0, -12 }, { 186.0, "wide", 0, 35 },
		{ 187.5, "wide", 0, 6 }, { 192.0, "knee" }, { 194.0, "xwide", -30, 8 }, { 198.0, "knee" },
		-- ending: the crane rises off the helipad into the city
		{ 200.0, "wide", 0, 45, { size = "xwide", pitch = 80 } },
	}),
}

-- RESCENE-LOVE-ATTACK: SBS Inkigayo 2024-09-01 stage (youtube Hv1wQ6nlpNE),
-- video = song + 1.9 s (D-908: 17 of 17 loudness windows +1.90). Fast beat
-- cuts between the sailor-set wides, high crane shots and close-ups; read
-- from 0.5 s strips in video seconds.
-- (D-932) now 139330220515727 (fileSpeed 1.05): same song clock
ClubCamera.Songs[139330220515727] = {
	video = "SBS Inkigayo 2024-09-01, youtube Hv1wQ6nlpNE",
	offset = 1.9,
	shots = videoCuts(1.9, {
		{ 1.9, "waist" }, { 2.6, "knee" }, { 3.0, "full" }, { 4.0, "knee" }, { 4.5, "xwide", 0, 6 }, { 5.0, "bust", 10 },
		{ 6.3, "xwide", 0, 6 }, { 7.3, "wide", -15, 6 }, { 8.5, "bust", -10 }, { 8.8, "bust", 10 }, { 9.9, "bust" },
		{ 11.0, "wide", 0, 15 }, { 12.0, "knee" }, { 13.1, "waist", 10 }, { 14.0, "full" }, { 14.9, "bust" },
		{ 16.0, "xwide", 0, 10 }, { 17.5, "bust", -15 }, { 19.2, "xwide", 0, 8 }, { 20.0, "wide", 0, 6 }, { 21.5, "knee" },
		{ 22.0, "waist", 10 }, { 23.5, "xwide", 0, 8 }, { 24.0, "wide" }, { 24.5, "bust" }, { 25.5, "waist" },
		{ 26.0, "xwide", 0, 6 }, { 27.0, "waist", -10 }, { 28.0, "bust" }, { 30.0, "waist" }, { 31.0, "bust", 10 },
		{ 32.0, "bust", -10 }, { 33.0, "waist" }, { 35.0, "bust" }, { 35.5, "xwide", 0, 15 }, { 37.0, "xwide", 0, 6 },
		{ 37.5, "bust", 10 }, { 38.5, "xwide", 0, 6 }, { 40.0, "waist" }, { 40.5, "xwide", -20, 30 }, { 41.5, "wide", 0, 15 },
		{ 43.0, "knee" }, { 44.0, "waist" }, { 45.0, "xwide", 0, 10 }, { 48.0, "xwide", 20, 30 }, { 48.5, "bust" },
		{ 50.5, "knee" }, { 52.5, "xwide", 0, 6 }, { 53.0, "bust", -10 }, { 54.0, "waist" }, { 55.0, "xwide", 0, 10 },
		{ 56.0, "knee" }, { 57.0, "waist" }, { 59.0, "bust" }, { 60.5, "xwide", 0, 15 }, { 62.0, "wide", 0, 10 },
		{ 63.0, "knee" }, { 64.5, "waist", 10 }, { 65.5, "xwide", 0, 10 }, { 68.5, "bust", -10 }, { 70.0, "waist", 10 },
		{ 71.0, "wide" }, { 72.0, "xwide", 0, 6 }, { 73.5, "bust" }, { 75.0, "xwide", 0, 10 }, { 76.0, "wide", 0, 8 },
		{ 78.0, "waist", -10 }, { 79.0, "bust" }, { 79.5, "knee" }, { 80.0, "wide", 0, 6 }, { 81.5, "bust", 10 },
		{ 83.5, "xwide", 0, 6 }, { 86.0, "waist" }, { 87.5, "bust" }, { 88.0, "xwide", 0, 6 }, { 89.5, "waist" },
		{ 90.5, "bust", -10 }, { 92.0, "waist" }, { 94.0, "bust" }, { 94.5, "xwide", 0, 6 }, { 97.0, "knee" },
		{ 97.5, "bust", 10 }, { 98.5, "waist" }, { 100.5, "wide", 0, 10 }, { 101.0, "knee" }, { 103.0, "bust" },
		{ 104.0, "waist" }, { 104.5, "xwide", 0, 15 }, { 105.0, "bust", -10 }, { 108.0, "bust" }, { 108.5, "wide", 0, 8 },
		{ 110.0, "knee" }, { 111.0, "waist" }, { 113.0, "bust", 10 }, { 114.0, "waist" }, { 114.5, "bust" },
		{ 116.5, "xwide", 0, 8 }, { 118.0, "wide" }, { 120.0, "waist" }, { 122.5, "xwide", 0, 15 }, { 124.0, "wide", 0, 8 },
		{ 125.0, "knee" }, { 126.0, "wide", 0, 8 }, { 128.0, "bust", -10 }, { 129.0, "waist" }, { 130.5, "xwide", 0, 8 },
		{ 131.0, "bust", 10 }, { 132.5, "xwide", 0, 6 }, { 133.5, "bust" }, { 135.0, "xwide", 0, 6 }, { 136.5, "wide" },
		{ 138.0, "waist" }, { 138.5, "bust" }, { 139.0, "close" }, { 139.5, "waist" }, { 141.0, "knee" },
		{ 141.5, "xwide", 0, 6 }, { 143.0, "knee" }, { 144.5, "xwide", 0, 6 }, { 146.0, "bust", 10 }, { 148.0, "bust", -10 },
		{ 149.5, "close" }, { 150.0, "xwide", 0, 6 }, { 153.5, "bust" }, { 156.5, "knee", 0, -10 }, { 157.5, "waist" },
		{ 159.0, "wide", 0, 8 }, { 159.5, "bust" }, { 161.5, "xwide", 0, 15 }, { 162.5, "wide", 0, 8 }, { 163.0, "knee" },
		{ 164.0, "waist" }, { 165.0, "wide", 0, 8 }, { 166.0, "xwide", 0, 15 }, { 166.5, "bust", 10 }, { 168.0, "xwide", 0, 15 },
		{ 170.0, "bust" }, { 171.5, "xwide", 0, 6 }, { 175.5, "knee", 0, -10 }, { 176.5, "waist" }, { 177.0, "bust" },
		{ 178.5, "xwide", 0, 6 }, { 179.0, "wide", 0, 6 }, { 180.0, "xwide", 0, 6 },
	}),
}

-- NCT WISH-I SPY: MBC Show! Music Core 2026-10-31 stage (youtube
-- 9N0svN37emE), video = song - 0.6 s (D-913: 17 of 17 loudness windows
-- -0.60 / -0.65). Fast beat cuts between close-ups and the full stage, read
-- from 0.5 s strips in video seconds.
-- (D-929) now 98124521559769 (fileSpeed 1.05): same song clock
ClubCamera.Songs[98124521559769] = {
	video = "MBC Show! Music Core 2026-10-31, youtube 9N0svN37emE",
	offset = -0.6,
	shots = videoCuts(-0.6, {
		{ -0.6, "bust" }, { 2.3, "xwide", 0, 6 }, { 4.2, "waist" }, { 5.5, "knee" }, { 6.0, "bust", 10 }, { 6.6, "xwide", 0, 6 },
		{ 9.7, "wide", 0, 6 }, { 10.0, "bust", -10 }, { 11.5, "wide" }, { 12.0, "wide", 0, 6 }, { 14.5, "bust", 10 },
		{ 16.4, "knee", 15 }, { 17.0, "waist" }, { 18.9, "xwide", 0, 6 }, { 20.5, "wide", 0, 6 }, { 21.5, "knee" },
		{ 22.3, "bust", -10 }, { 22.5, "wide", 0, 6 }, { 24.0, "bust" }, { 25.8, "wide", 0, 6 }, { 27.0, "knee" },
		{ 27.8, "bust", 10 }, { 29.1, "wide", 0, 6 }, { 30.0, "waist" }, { 31.0, "wide" }, { 32.0, "waist" }, { 32.6, "bust" },
		{ 34.7, "bust", -10 }, { 35.8, "xwide", 0, 8 }, { 36.7, "wide", 0, 8 }, { 38.3, "bust" }, { 39.1, "wide" },
		{ 40.5, "wide", 0, 6 }, { 41.5, "knee" }, { 42.7, "bust", 10 }, { 43.1, "xwide", 0, 6 }, { 44.0, "wide", 0, 6 },
		{ 45.6, "bust" }, { 46.4, "bust", -10 }, { 47.5, "bust", 10 }, { 49.3, "wide", 0, 6 }, { 51.0, "waist" },
		{ 51.5, "bust" }, { 52.3, "xwide", 0, 6 }, { 53.2, "wide" }, { 54.1, "wide", 0, 6 }, { 55.0, "bust" },
		{ 55.7, "xwide", 0, 6 }, { 57.0, "wide", 0, 6 }, { 58.5, "bust", -10 }, { 60.0, "bust" }, { 61.1, "bust", 10 },
		{ 61.5, "waist" }, { 62.9, "xwide", 0, 10 }, { 63.5, "wide", 0, 8 }, { 64.5, "knee" }, { 65.0, "bust" },
		{ 66.9, "bust", -10 }, { 67.5, "waist" }, { 69.0, "bust" }, { 70.0, "wide" }, { 71.2, "waist" }, { 72.0, "bust", 10 },
		{ 72.5, "waist" }, { 74.0, "bust" }, { 74.5, "wide" }, { 75.5, "xwide", 0, 8 }, { 76.0, "bust" }, { 76.5, "knee" },
		{ 78.2, "bust", -10 }, { 78.5, "wide", 0, 6 }, { 79.0, "bust" }, { 80.0, "wide", -20 }, { 80.8, "bust" },
		{ 83.0, "wide", 0, 6 }, { 85.0, "waist" }, { 86.5, "wide", 0, 6 }, { 87.3, "bust" }, { 88.0, "close" },
		{ 90.0, "xwide", 0, 6 }, { 91.0, "wide", 0, 6 }, { 92.1, "waist" }, { 92.5, "bust", 10 }, { 94.0, "waist" },
		{ 94.6, "wide" }, { 95.5, "bust" }, { 97.2, "wide", 0, 6 }, { 98.5, "waist" }, { 99.0, "bust", -10 },
		{ 100.5, "wide", 0, 6 }, { 102.5, "bust" }, { 103.4, "xwide", 0, 10 }, { 104.0, "wide", 0, 6 }, { 105.5, "waist" },
		{ 106.5, "bust", 10 }, { 107.0, "wide" }, { 108.5, "bust" }, { 110.1, "wide", 0, 6 }, { 112.5, "bust", -10 },
		{ 114.0, "waist" }, { 115.2, "bust" }, { 117.0, "xwide", 0, 8 }, { 118.0, "wide", 0, 6 }, { 119.0, "waist" },
		{ 122.0, "wide", 0, 6 }, { 122.7, "bust", 10 }, { 125.5, "bust", -10 }, { 127.0, "xwide", 0, 8 }, { 127.6, "wide" },
		{ 128.0, "waist" }, { 129.7, "bust" }, { 130.0, "xwide", 0, 6 }, { 132.0, "wide" }, { 132.5, "waist" },
		{ 133.0, "bust", 10 }, { 134.4, "wide", 0, 6 }, { 136.0, "wide" }, { 136.5, "bust" }, { 138.0, "bust", -10 },
		{ 138.5, "wide" }, { 139.0, "wide", 0, 6 }, { 139.6, "bust" }, { 140.5, "waist" }, { 141.0, "knee" },
		{ 141.5, "wide", 0, 6 }, { 143.0, "waist" }, { 145.0, "bust" }, { 145.5, "xwide", 0, 6 }, { 148.5, "waist" },
		{ 149.0, "bust" }, { 149.5, "waist" }, { 150.8, "bust", 10 }, { 152.0, "wide" }, { 152.5, "waist" }, { 153.0, "bust" },
		{ 154.0, "waist" }, { 155.1, "bust", -10 }, { 157.0, "waist" }, { 158.0, "bust" }, { 158.5, "xwide", 0, 6 },
		{ 159.0, "wide" }, { 160.4, "waist" }, { 161.2, "bust", 10 }, { 162.0, "wide", 0, 6 }, { 163.2, "bust" },
		{ 164.6, "wide", 0, 6 }, { 166.0, "wide" }, { 166.4, "waist" }, { 167.2, "bust", -10 }, { 168.7, "wide", 0, 6 },
		{ 170.0, "waist" }, { 170.5, "bust", 10 }, { 172.0, "wide" }, { 173.0, "waist" }, { 174.0, "bust" },
		{ 175.0, "wide", 0, 6 }, { 175.5, "xwide", 0, 8 }, { 177.0, "bust" }, { 179.0, "wide" }, { 180.0, "waist" },
		{ 183.0, "bust" }, { 183.5, "waist" }, { 184.0, "xwide", 0, 6 },
	}),
}

-- ILLIT-체포하겠어 (You're Under Arrest): KBS Music Bank 2026-10-30 comeback
-- stage (KBS WORLD TV, youtube gcmQ8eZW_vI), video = song + 24.9 s (D-915:
-- 17 of 17 loudness windows +24.90; the first 25 s are the channel logo and
-- the comeback film). A big set with a crowd of dancers: mostly wides and
-- full shots, a few close-ups, read from 0.5 s strips in video seconds.
ClubCamera.Songs[139044453511745] = {
	video = "KBS Music Bank 2026-10-30, youtube gcmQ8eZW_vI",
	offset = 24.9,
	shots = videoCuts(24.9, {
		{ 24.9, "xwide", 0, 6 }, { 27.0, "bust" }, { 28.3, "xwide", 0, 8 }, { 33.0, "wide", -15 }, { 34.5, "xwide", 0, 6 },
		{ 37.0, "wide" }, { 38.8, "xwide", 0, 10 }, { 43.0, "waist" }, { 44.4, "wide", 0, 6 }, { 45.5, "bust" },
		{ 46.5, "xwide", 0, 6 }, { 47.8, "wide", 0, 10 }, { 49.0, "xwide", 0, 6 }, { 50.0, "waist" }, { 50.5, "xwide", 0, 8 },
		{ 53.0, "wide" }, { 54.0, "knee" }, { 55.0, "xwide", 0, 6 }, { 58.0, "waist" }, { 60.0, "wide", 0, 6 },
		{ 62.0, "waist", 15 }, { 64.0, "xwide", 0, 6 }, { 66.0, "wide" }, { 68.0, "knee" }, { 69.0, "wide" },
		{ 71.0, "waist" }, { 72.5, "bust" }, { 73.0, "wide" }, { 76.1, "xwide", 0, 10 }, { 78.0, "xwide", 0, 6 },
		{ 81.5, "xwide", 0, 8 }, { 85.0, "waist" }, { 86.0, "xwide", 0, 6 }, { 88.5, "waist", 10 }, { 89.5, "xwide", 0, 8 },
		{ 92.5, "waist" }, { 94.3, "xwide", 0, 8 }, { 96.5, "wide" }, { 97.0, "xwide", 0, 6 }, { 102.5, "wide" },
		{ 103.0, "knee" }, { 104.5, "xwide", 0, 6 }, { 108.5, "knee" }, { 109.0, "bust" }, { 110.5, "waist" },
		{ 111.0, "xwide", 0, 6 }, { 115.0, "wide" }, { 116.0, "xwide", 0, 6 }, { 122.0, "wide", 0, 6 }, { 129.0, "xwide", 0, 6 },
		{ 131.5, "wide" }, { 133.0, "knee" }, { 135.5, "bust" }, { 136.8, "xwide", 0, 6 }, { 140.1, "wide" },
		{ 141.5, "xwide", 0, 8 }, { 143.1, "xwide", 0, 6 }, { 146.0, "waist" }, { 147.0, "wide" }, { 148.0, "xwide", 0, 6 },
		{ 149.5, "waist" }, { 151.3, "xwide", 0, 6 }, { 153.0, "xwide", 0, 8 }, { 153.5, "waist" }, { 155.3, "wide", 0, 6 },
		{ 156.0, "waist" }, { 157.0, "wide", 0, 8 }, { 161.0, "bust" }, { 161.6, "wide", 0, 6 }, { 162.5, "xwide", 0, 6 },
		{ 166.5, "waist" }, { 168.3, "xwide", 0, 8 }, { 173.0, "waist" }, { 174.2, "xwide", 0, 6 }, { 175.5, "waist" },
		{ 176.5, "xwide", 0, 6 }, { 180.0, "waist" }, { 181.4, "xwide", 0, 6 }, { 183.5, "wide" }, { 184.5, "xwide", 0, 6 },
		{ 187.0, "wide" }, { 188.0, "waist" }, { 189.5, "wide" }, { 190.0, "bust" }, { 191.5, "xwide", 0, 6 },
		{ 197.0, "xwide", 0, 6 }, { 201.5, "wide" }, { 202.5, "xwide", 0, 6 }, { 203.0, "wide" }, { 207.0, "waist" },
	}),
}

-- (D-944) four stages at once, shot lists made by tools/choreo/stagecam/shots_to_lua.py
-- from shots.py (size from the biggest dancer's pose in each shot's sample frames)
-- and written in song seconds. The start point of each video: the original mp3's
-- loudness (mp3_loudness.py, checked against the practice-video offsets of the
-- choreography) lined up with the stage video (align_wide.py), and pose_pick.py
-- where the sound gave two answers.
-- ALLDAY PROJECT-CRASH: Mnet M COUNTDOWN 2026-10-01 (youtube XCZcd7BAup0),
-- video = song + 35.8 s (a ~34 s intro before the song).
ClubCamera.Songs[104827635407586] = {
	video = "Mnet M COUNTDOWN 2026-10-01, youtube XCZcd7BAup0",
	offset = 35.8,
	shots = cutList({
		{ 0, "wide", 0, 5 }, { 3.17, "bust" }, { 4.27, "xwide", 0, 8 }, { 5.13, "waist" }, { 6.54, "bust" },
		{ 9.23, "waist" }, { 10.63, "wide", 0, 5 }, { 11.7, "bust" }, { 12.6, "waist" }, { 14.31, "bust" },
		{ 16.63, "wide", 0, 5 }, { 17.87, "waist" }, { 19.23, "full" }, { 21.17, "bust" }, { 23.65, "full" },
		{ 24.77, "waist" }, { 26.57, "full" }, { 27.74, "bust" }, { 30.27, "wide", 0, 5, { size = "full" } },
		{ 32.57, "wide", 0, 5 }, { 33.95, "knee" }, { 35.73, "bust" }, { 37.5, "wide", 0, 5 }, { 39.08, "bust" },
		{ 41.33, "wide", 0, 5 }, { 42.48, "bust" }, { 44.97, "wide", 0, 5 }, { 46.17, "waist" },
		{ 49.98, "wide", 0, 5 }, { 51.53, "bust" }, { 53.67, "waist" }, { 55.47, "bust" },
		{ 57.13, "bust", 10, 0, { size = "waist" } }, { 59.53, "xwide", 0, 8 }, { 61.17, "bust" },
		{ 62.93, "xwide", 0, 8 }, { 63.71, "wide", 0, 5 }, { 64.81, "bust" },
		{ 66.6, "waist", 0, 0, { size = "knee" } }, { 68.4, "bust", -5 }, { 69.3, "xwide", 0, 8 },
		{ 69.73, "wide", 0, 5 }, { 70.66, "waist" }, { 72.1, "waist", 0, 0, { size = "bust" } }, { 72.9, "bust" },
		{ 73.63, "xwide", 0, 8 }, { 75.73, "waist" }, { 76.63, "bust" }, { 78.53, "wide", 0, 5 }, { 81.53, "full" },
		{ 82.48, "bust" }, { 84.63, "wide", 0, 5 }, { 86.47, "waist" }, { 88.47, "wide", 0, 5 }, { 90.13, "waist" },
		{ 91.17, "bust" }, { 91.73, "xwide", 0, 8 }, { 93.43, "bust" }, { 93.9, "bust", 0, 0, { size = "close" } },
		{ 95.13, "wide", 0, 5 }, { 96.37, "waist" }, { 99.2, "bust" }, { 100.67, "bust", 0, 0, { size = "close" } },
		{ 102.1, "bust", 0, 0, { size = "waist" } }, { 102.97, "bust" }, { 104.4, "xwide", 0, 8 },
		{ 106.33, "waist" }, { 109.23, "bust", 0, 0, { size = "waist" } }, { 110.7, "full" }, { 112.53, "bust" },
		{ 113.6, "waist" }, { 114.37, "bust" }, { 116.47, "bust", 0, 0, { size = "waist" } },
		{ 117.57, "wide", 0, 5 }, { 119.37, "bust" }, { 120.27, "xwide", 0, 8 }, { 121.23, "wide", 0, 5 },
		{ 122.2, "full" }, { 122.97, "bust" }, { 125.31, "wide", 0, 5 }, { 126.6, "bust" }, { 128.59, "wide", 0, 5 },
		{ 129.58, "full" }, { 130.23, "bust", 0, 0, { size = "close" } }, { 131.5, "bust" },
		{ 131.87, "wide", 0, 5 }, { 133.75, "waist" }, { 136.57, "wide", 0, 5 }, { 139.15, "bust" },
		{ 140.62, "wide", 0, 5 }, { 141.1, "bust" }, { 142.2, "bust", 0, 0, { size = "waist" } },
		{ 144.03, "waist" }, { 144.5, "bust" }, { 145.64, "waist" }, { 146.9, "xwide", 0, 8 }, { 148.07, "bust" },
		{ 148.57, "xwide", 0, 8 }, { 150.13, "bust" }, { 151.93, "xwide", 0, 8 }, { 152.56, "bust" },
		{ 153.77, "xwide", 0, 8, { size = "wide" } }, { 155.73, "bust" }, { 156.53, "wide", 0, 5 },
		{ 159.3, "waist" }, { 160.33, "bust" }, { 161.13, "waist" }, { 161.94, "wide", 0, 5 }, { 162.59, "waist" },
		{ 163.69, "bust" }, { 164.93, "xwide", 0, 8 }, { 168.29, "wide", 0, 5 }, { 171.17, "bust" },
	}),
}
-- RIIZE-Love 119: SBS Inkigayo 2024-01-14 (youtube w11AQwiT07g). The upload runs
-- 1.00496x the mp3 (orig = -0.375 + 1.00496 x song, choreography session), and
-- video = mp3 - 0.85 s, so song = (video + 1.225) / 1.00496.
ClubCamera.Songs[85204387077332] = {
	video = "SBS Inkigayo 2024-01-14, youtube w11AQwiT07g",
	offset = -1.225,
	shots = ClubCamera.join({
		-- (D-963, user 2026-11-07: start = the first pose held still, the camera
		-- on the face turning round it, then flowing into the walk) the game
		-- holds the first pose from 0.7 to 3.9 s and walks from 3.94 s (feat/choreo-fixes-1107):
		-- one take orbiting the face to 3.9 s, then easing out to the knee shot
		-- while the walk blends in, held until the stage's next cut at 8.73
		take({ { 0, "close", yaw = -40 }, { 3.9, "close", yaw = 25 }, { 5.6, "knee" } }),
		cutList({ { 8.73, "wide", 0, 5 }, { 10.6, "bust" }, { 11.9, "wide", 0, 5 },
		{ 12.47, "waist" }, { 13.53, "knee" }, { 15.62, "full" }, { 16.74, "waist" },
		{ 17.97, "xwide", 0, 8, { size = "wide" } }, { 19.63, "bust" }, { 21.52, "wide", 0, 5, { size = "full" } },
		{ 24.63, "waist" }, { 28.33, "wide", 0, 5 }, { 29.45, "waist" }, { 31.84, "xwide", 0, 8, { size = "wide" } },
		{ 32.43, "wide", 0, 5 }, { 33.03, "bust" }, { 34.12, "waist" }, { 34.79, "bust" }, { 35.48, "wide", 0, 5 },
		{ 36.19, "bust" }, { 37.51, "waist" }, { 38.38, "full" }, { 39.8, "waist" }, { 41.59, "wide", 0, 5 },
		{ 43.14, "full" }, { 43.84, "waist" }, { 47.74, "wide", 0, 5 }, { 49.01, "waist" }, { 50.67, "xwide", 0, 8 },
		{ 52.6, "wide", 0, 5 }, { 53.32, "waist" }, { 57.34, "wide", 0, 5 }, { 59.8, "bust" },
		{ 61.59, "xwide", 0, 8 }, { 63.8, "wide", 0, 5 }, { 64.91, "full" }, { 66.4, "bust" },
		{ 68.81, "wide", 0, 5 }, { 71.02, "waist" }, { 72.96, "bust" }, { 74.78, "bust", 0, 0, { size = "waist" } },
		{ 76.05, "xwide", 0, 8 }, { 76.83, "wide", 0, 5 }, { 77.5, "waist" }, { 79.24, "bust" },
		{ 80.16, "wide", 0, 5 }, { 82.34, "waist" }, { 84.7, "full" }, { 87.4, "wide", 0, 5 },
		{ 89.01, "waist", 0, 0, { size = "bust" } }, { 91.3, "bust", 0, 0, { size = "waist" } },
		{ 93.13, "wide", 0, 5 }, { 95.9, "bust" }, { 98.28, "wide", 0, 5 }, { 101.69, "waist" },
		{ 103.28, "xwide", 0, 8 }, { 105.44, "wide", 0, 5 }, { 108.82, "bust" }, { 110.15, "wide", 0, 5 },
		{ 110.95, "full" }, { 112.1, "waist", 0, 0, { size = "knee" } }, { 115.38, "bust" },
		{ 116.75, "wide", 0, 5 }, { 120.67, "waist" }, { 122.72, "wide", 0, 5 }, { 125.1, "bust" },
		{ 126.99, "waist" }, { 128.48, "bust" }, { 130.68, "wide", 0, 5 }, { 132.4, "waist" }, { 135.09, "bust" },
		{ 136.78, "wide", 0, 5, { size = "full" } }, { 137.94, "bust" }, { 141.77, "wide", 0, 5 },
		{ 143.88, "bust" }, { 145.77, "wide", 0, 5 }, { 146.53, "knee" },
		{ 148.99, "knee", 0, 0, { size = "full" } }, { 150.71, "bust" }, { 152.47, "xwide", 0, 8 },
		{ 153.94, "wide", 0, 5 }, { 155.26, "full" }, { 159.5, "wide", 0, 5 }, { 160.14, "bust" },
		{ 162.35, "bust", 5, 0, { size = "waist" } }, { 163.44, "waist" }, { 164.78, "full" }, { 165.8, "bust" },
		{ 167.69, "wide", 0, 5 }, { 170.29, "full" }, { 171.54, "bust" },
		}),
	}),
}
-- 키키-Pop Off: KBS Music Bank 2026-08-14 (youtube bpYdX73przc), video = song + 7.0 s
-- (the sound also allowed +5.2; the hands-on-head move at song 30 s picks +7.0).
ClubCamera.Songs[129996145931101] = {
	video = "KBS Music Bank 2026-08-14, youtube bpYdX73przc",
	offset = 7.0,
	shots = cutList({
		{ 0, "wide", 0, 5 }, { 2.08, "full" }, { 5.99, "waist" }, { 11.2, "xwide", 0, 8 }, { 12.65, "wide", 0, 5 },
		{ 13.55, "full" }, { 14.23, "bust", -10 }, { 16.27, "wide", 0, 5 }, { 18.25, "bust" },
		{ 19.9, "wide", 0, 5 }, { 21.05, "full" }, { 22.03, "bust" }, { 23.19, "waist" }, { 23.8, "wide", 0, 5 },
		{ 24.5, "waist" }, { 25.63, "wide", 0, 5 }, { 29.44, "waist" }, { 32.14, "wide", 0, 5 }, { 34.8, "bust" },
		{ 35.27, "bust", -15, 0, { size = "waist" } }, { 36.63, "wide", 0, 5 }, { 37.85, "bust" },
		{ 38.83, "wide", 0, 5 }, { 40.27, "bust" }, { 40.77, "full" }, { 42.03, "wide", 0, 5, { size = "full" } },
		{ 44.07, "bust", 5, 0, { size = "waist" } }, { 45.73, "bust" }, { 46.83, "waist" }, { 47.63, "full" },
		{ 48.22, "knee" }, { 49.53, "wide", 0, 5 }, { 53.13, "bust" }, { 54.87, "full" }, { 56.08, "waist" },
		{ 58.63, "bust", 0, 0, { size = "waist" } }, { 60.3, "wide", 0, 5 }, { 61.55, "full" }, { 62.17, "bust" },
		{ 63.93, "wide", 0, 5 }, { 64.81, "waist" }, { 65.97, "bust" }, { 66.69, "wide", 0, 5 }, { 67.63, "bust" },
		{ 68.51, "waist" }, { 69.39, "bust" }, { 69.87, "full" }, { 70.68, "bust" }, { 71.53, "wide", 0, 5 },
		{ 72.8, "knee" }, { 73.47, "full" }, { 74.8, "bust", 10 }, { 76.7, "bust" }, { 77.54, "wide", 0, 5 },
		{ 78.53, "bust", -5, 0, { size = "close" } }, { 81.37, "bust" }, { 83.83, "wide", 0, 5 }, { 84.77, "full" },
		{ 86.03, "waist" }, { 87.01, "xwide", 0, 8 }, { 87.93, "wide", 0, 5 }, { 89.2, "full" }, { 90.5, "waist" },
		{ 91.58, "wide", 0, 5 }, { 93.59, "knee" }, { 96.17, "knee", 5 }, { 97.03, "full" }, { 97.93, "waist" },
		{ 99.88, "full" }, { 100.57, "bust", 10, 0, { size = "waist" } }, { 102, "knee", 0, 0, { size = "full" } },
		{ 102.5, "waist" }, { 103.49, "wide", 0, 5 }, { 104.37, "bust" }, { 106.2, "wide", 0, 5 },
		{ 108.68, "bust" }, { 109.9, "waist" }, { 113.82, "full" }, { 115.23, "waist" }, { 117.95, "wide", 0, 5 },
		{ 120.71, "bust" }, { 124.6, "xwide", 0, 8 }, { 125.97, "full" }, { 127.13, "bust" }, { 129.13, "full" },
		{ 132.08, "bust" }, { 136.96, "waist" }, { 138.4, "knee", 0, 0, { size = "full" } }, { 141.63, "bust" },
	}),
}
-- RESCENE-Pretty Girl: MBC Show! Music Core 2026-07-11 (youtube j4LlqGxOr2E),
-- video = song + 7.6 s.
ClubCamera.Songs[89634330677538] = {
	video = "MBC Show! Music Core 2026-07-11, youtube j4LlqGxOr2E",
	offset = 7.6,
	shots = cutList({
		{ 0, "bust" }, { 1.41, "knee" }, { 2.76, "full" }, { 4.07, "bust" },
		{ 5.03, "bust", -15, 0, { size = "waist" } }, { 5.93, "bust", 0, 0, { size = "waist" } }, { 7.9, "bust" },
		{ 11.27, "xwide", 0, 8 }, { 12.11, "wide", 0, 5 }, { 12.9, "bust" }, { 14.83, "wide", 0, 5 },
		{ 15.83, "bust" }, { 16.84, "wide", 0, 5 }, { 18.23, "bust" }, { 19.35, "wide", 0, 5 }, { 20.62, "bust" },
		{ 21.97, "wide", 0, 5 }, { 23.81, "bust" }, { 27, "full" }, { 28.5, "bust" }, { 29.67, "xwide", 0, 8 },
		{ 30.07, "wide", 0, 5 }, { 32.28, "bust" }, { 39.09, "wide", 0, 5 }, { 43.43, "full" }, { 44, "bust" },
		{ 44.43, "waist" }, { 46.18, "bust" }, { 51.95, "waist" }, { 53.02, "full" },
		{ 55.9, "bust", 5, 0, { size = "waist" } }, { 58.5, "knee" }, { 61.33, "full" }, { 63.17, "bust", 5 },
		{ 65.03, "wide", 0, 5 }, { 66.59, "bust" }, { 67.63, "wide", 0, 5 }, { 69.37, "bust" },
		{ 72.13, "wide", 0, 5 }, { 72.97, "waist" }, { 74.27, "bust" }, { 76.18, "full" }, { 77.37, "bust" },
		{ 78.67, "wide", 0, 5, { size = "full" } }, { 82.07, "wide", 0, 5 }, { 82.87, "full" },
		{ 83.59, "wide", 0, 5 }, { 84.7, "waist" }, { 85.63, "bust" }, { 86.5, "wide", 0, 5 }, { 87.68, "bust" },
		{ 90.99, "wide", 0, 5 }, { 97.1, "waist" }, { 97.8, "bust" }, { 98.97, "wide", 0, 5, { size = "full" } },
		{ 102.77, "full" }, { 104.4, "waist" }, { 105.99, "wide", 0, 5 }, { 110.16, "bust" },
		{ 112.17, "wide", 0, 5 }, { 113.8, "bust" }, { 114.98, "waist" }, { 118.09, "bust" },
		{ 118.63, "wide", 0, 5, { size = "full" } }, { 119.23, "full" }, { 119.67, "bust" }, { 122.44, "waist" },
		{ 125.39, "bust" }, { 126.73, "wide", 0, 5 }, { 128.51, "bust" },
		{ 131.23, "bust", 0, 0, { size = "waist" } }, { 133.1, "waist" }, { 134.37, "bust" }, { 140.17, "full" },
		{ 141.8, "bust" }, { 143.6, "wide", 0, 5 }, { 144.93, "bust" }, { 145.93, "waist", 0, 0, { size = "knee" } },
		{ 146.77, "bust" }, { 149.14, "wide", 0, 5 }, { 149.93, "bust" }, { 151.91, "wide", 0, 5 },
		{ 153.22, "bust" }, { 154.6, "bust", 5 }, { 159.83, "waist" }, { 161.07, "wide", 0, 5 }, { 163.09, "bust" },
		{ 164.61, "wide", 0, 5 }, { 166.07, "waist" }, { 166.98, "full" }, { 168.18, "bust" },
		{ 169.7, "wide", 0, 5 }, { 171.52, "bust" }, { 174.13, "waist", -10, 0, { size = "bust" } },
		{ 175.97, "bust" }, { 176.99, "wide", 0, 5 }, { 180.13, "bust" }, { 182.3, "full" }, { 184.02, "bust" },
		{ 186.67, "waist" }, { 187.67, "bust" }, { 189.25, "wide", 0, 5 }, { 192.17, "waist" },
		{ 194.68, "wide", 0, 5 }, { 198.87, "waist" }, { 200.5, "waist", 0, 0, { size = "bust" } },
		{ 200.9, "xwide", 0, 8 }, { 201.88, "wide", 0, 5 }, { 205.84, "bust" },
	}),
}
-- (D-969) IOI-갑자기: MBC Show! Music Core 2026-05-23 (youtube 5olSAzpqZsQ), video =
-- song - 0.3 s: the original mp3's loudness (on the game clock: mp3 vs practice
-- video +0.30 = the choreography's offset) lined up with the stage; the sound
-- also allowed -1.3 (two beats), and the poses at song 25 / 33 / 155 s pick -0.3.
-- Shot list made by shots_to_lua.py (D-944).
ClubCamera.Songs[75344866720031] = {
	video = "MBC Show! Music Core 2026-05-23, youtube 5olSAzpqZsQ",
	offset = -0.3,
	shots = cutList({
		{ 0, "bust" }, { 2.25, "wide", 0, 5 }, { 4.16, "waist" }, { 10.63, "waist", 0, 0, { size = "bust" } },
		{ 12.1, "bust" }, { 12.5, "xwide", 0, 8, { size = "wide" } }, { 14.1, "knee" }, { 14.67, "waist" },
		{ 15.53, "bust" }, { 16.13, "bust", 0, 0, { size = "waist" } }, { 16.73, "wide", 0, 5 },
		{ 17.23, "bust", 0, 0, { size = "close" } }, { 18.2, "bust" }, { 19.2, "wide", 0, 5, { size = "full" } },
		{ 20.33, "bust", 0, 0, { size = "close" } }, { 20.9, "waist", 0, 0, { size = "bust" } },
		{ 22.37, "waist", 0, 0, { size = "knee" } }, { 22.93, "wide", 0, 5 }, { 24.4, "waist" },
		{ 24.93, "waist", 0, 0, { size = "knee" } }, { 29.03, "bust" }, { 31.63, "xwide", 0, 8, { size = "wide" } },
		{ 33.4, "wide", 10, 5 }, { 35.47, "knee" }, { 35.97, "waist" }, { 37, "bust" }, { 38.03, "wide", 0, 5 },
		{ 39.13, "bust" }, { 40.52, "waist" }, { 42.9, "bust" }, { 43.47, "wide", -5, 5, { size = "full" } },
		{ 44.93, "waist", 0, 0, { size = "bust" } }, { 45.97, "bust" }, { 48.04, "wide", 0, 5 }, { 48.9, "full" },
		{ 50.03, "waist", 0, 0, { size = "bust" } }, { 51.7, "wide", 0, 5 },
		{ 52.13, "wide", 0, 5, { size = "full" } }, { 53.13, "full", 0, 0, { size = "knee" } }, { 54.17, "bust" },
		{ 55.22, "wide", 0, 5 }, { 56.45, "bust" }, { 59.77, "wide", 0, 5, { size = "full" } },
		{ 61.37, "full", 0, 0, { size = "knee" } }, { 62.37, "waist", 0, 0, { size = "bust" } },
		{ 63.4, "bust", -10, 0, { size = "waist" } }, { 64.43, "knee", 0, 0, { size = "full" } }, { 65.37, "bust" },
		{ 67.93, "wide", 0, 5, { size = "full" } }, { 69.1, "waist", 0, 0, { size = "bust" } }, { 70.13, "waist" },
		{ 71.3, "full" }, { 71.93, "waist" }, { 73.19, "bust" }, { 73.87, "wide", -5, 5, { size = "full" } },
		{ 76.33, "full" }, { 79.62, "waist" }, { 83.2, "bust" }, { 84.5, "bust", 0, 0, { size = "close" } },
		{ 86.03, "knee" }, { 87.2, "bust" }, { 92.5, "knee" }, { 93.98, "wide", 0, 5 }, { 96.67, "bust" },
		{ 97.83, "waist" }, { 98.8, "full" }, { 99.9, "waist", -5 }, { 101.07, "bust" },
		{ 101.43, "waist", 0, 0, { size = "knee" } }, { 102.9, "bust" }, { 107.13, "xwide", 0, 8 },
		{ 107.99, "full" }, { 108.69, "waist" }, { 109.57, "bust" }, { 112.08, "wide", 0, 5 }, { 113.03, "bust" },
		{ 116.23, "xwide", 0, 8 }, { 116.7, "wide", 0, 5, { size = "full" } }, { 118.83, "waist" },
		{ 122.38, "wide", 0, 5 }, { 124.67, "bust" }, { 127.37, "waist" },
		{ 128.03, "wide", 0, 5, { size = "full" } }, { 129.03, "knee" }, { 129.85, "waist" },
		{ 131.17, "wide", 0, 5 }, { 132.13, "full" }, { 132.83, "bust", 0, 0, { size = "waist" } },
		{ 134.17, "knee" }, { 135.2, "full" }, { 137.1, "waist" }, { 138.27, "knee" }, { 139.3, "wide", 0, 5 },
		{ 139.77, "waist" }, { 141.32, "bust" }, { 141.97, "wide", 0, 5 }, { 144.09, "full" }, { 147.33, "knee" },
		{ 148.44, "bust" }, { 151.97, "wide", 0, 5 }, { 153.52, "waist" }, { 154.78, "wide", 0, 5 },
		{ 156.1, "full" }, { 157.05, "waist" }, { 158.33, "waist", 0, 0, { size = "knee" } }, { 160.27, "bust" },
		{ 162.37, "wide", 0, 5 }, { 165.37, "knee" }, { 166.63, "waist" },
		{ 167.13, "bust", 0, 0, { size = "waist" } }, { 167.63, "waist" },
		{ 169.2, "full", 0, 0, { size = "knee" } }, { 169.7, "waist", 0, 0, { size = "bust" } }, { 170.53, "knee" },
		{ 171.23, "bust" }, { 171.73, "waist" }, { 172.27, "full", 0, 0, { size = "wide" } }, { 173.43, "bust" },
		{ 174.53, "full", 0, 0, { size = "knee" } }, { 175.33, "knee" },
		{ 175.87, "waist", 0, 0, { size = "knee" } }, { 176.67, "waist" }, { 178.67, "wide", 0, 5 },
		{ 179.3, "wide", 0, 5, { size = "full" } }, { 179.8, "knee", 0, 0, { size = "waist" } },
		{ 181.33, "waist", 0, 0, { size = "knee" } }, { 181.87, "full", 0, 0, { size = "wide" } },
		{ 182.87, "bust", 10 }, { 183.4, "waist", 10, 0, { size = "knee" } }, { 184.97, "wide", 0, 5 },
		{ 186.5, "full" }, { 186.9, "bust" }, { 188.93, "full" }, { 192.43, "waist" }, { 194.44, "bust" },
	}),
}
-- (D-971) aespa-Lemonade: MBC Show! Music Core 2026-05-30 (youtube r2eoeCk171I),
-- video = song - 0.12 s (no mp3: the practice video's sound, = song + 1.08 by the
-- choreography, lined up with the stage: stage = practice - 1.20 in every window).
-- YENA-Catch Catch: MBC Show! Music Core 2026-03-21 (youtube erNe2L0beR0), video =
-- song - 0.70 s (practice video = song - 0.70, stage = practice + 0.00 throughout).
-- Shot lists made by shots_to_lua.py (D-944).
ClubCamera.Songs[132067415333401] = {
	video = "MBC Show! Music Core 2026-05-30, youtube r2eoeCk171I",
	offset = -0.12,
	shots = cutList({
		{ 0, "xwide", 0, 8 }, { 2.64, "wide", 0, 5 }, { 4.05, "bust" }, { 5.71, "waist" }, { 6.96, "bust" },
		{ 8.34, "waist" }, { 10.29, "waist", 0, 0, { size = "bust" } }, { 11.39, "xwide", 0, 8 }, { 12.75, "waist" },
		{ 16.12, "wide", 0, 5 }, { 20.89, "knee" }, { 22.13, "bust" }, { 24.62, "xwide", 0, 8 }, { 25.05, "knee" },
		{ 25.55, "wide", 0, 5 }, { 25.99, "knee" }, { 26.45, "bust" }, { 28.32, "waist" }, { 29.25, "bust" },
		{ 29.72, "full", 0, 0, { size = "wide" } }, { 30.22, "wide", 0, 5 }, { 30.65, "full" },
		{ 31.15, "waist", 5 }, { 31.59, "waist" }, { 32.09, "full" }, { 32.55, "knee" }, { 33.02, "waist" },
		{ 33.49, "bust" }, { 33.95, "waist" }, { 34.42, "knee" }, { 34.89, "waist" }, { 35.82, "wide", 0, 5 },
		{ 36.29, "full" }, { 36.75, "waist" }, { 37.22, "bust" }, { 38.65, "knee", 0, 0, { size = "full" } },
		{ 39.09, "wide", 0, 5, { size = "xwide" } }, { 39.65, "wide", 0, 5 }, { 41, "full" }, { 42.59, "bust" },
		{ 44.32, "waist" }, { 45.19, "wide", 0, 5 }, { 46.12, "full", 0, 0, { size = "knee" } }, { 46.59, "waist" },
		{ 47.52, "bust" }, { 48.45, "waist" }, { 48.92, "bust" }, { 49.42, "knee", 0, 0, { size = "full" } },
		{ 50.85, "waist" }, { 51.32, "bust" }, { 51.79, "waist", 0, 0, { size = "knee" } }, { 53.65, "bust" },
		{ 55.91, "waist" }, { 57.59, "bust" }, { 58.21, "knee" }, { 59.11, "wide", 0, 5 },
		{ 60.09, "waist", 0, 0, { size = "bust" } }, { 62.29, "wide", 0, 5 }, { 64.21, "bust" },
		{ 65.31, "wide", 0, 5 }, { 67.69, "knee" }, { 68.96, "bust" }, { 73.15, "wide", 0, 5 }, { 75.02, "waist" },
		{ 77.32, "wide", 0, 5 }, { 79.97, "knee" }, { 81.4, "waist" }, { 84.49, "wide", 0, 5 }, { 85.63, "bust" },
		{ 86.52, "wide", 0, 5 }, { 87.49, "full" }, { 88.42, "knee" }, { 88.85, "waist" }, { 89.79, "bust" },
		{ 90.29, "waist" }, { 90.72, "full", 0, 0, { size = "wide" } }, { 91.22, "wide", 0, 5 }, { 92.15, "waist" },
		{ 93.99, "wide", 0, 5, { size = "full" } }, { 94.49, "full" }, { 94.95, "knee" }, { 95.42, "waist" },
		{ 96.35, "bust" }, { 96.82, "bust", 0, 0, { size = "waist" } }, { 98.22, "waist" }, { 98.72, "full" },
		{ 99.65, "knee" }, { 100.09, "bust" }, { 101.45, "wide", 0, 5, { size = "full" } }, { 102.52, "waist" },
		{ 103.58, "bust" }, { 105.49, "full" }, { 106.54, "waist" }, { 108.09, "bust" }, { 112.03, "wide", 0, 5 },
		{ 114.45, "bust" }, { 116.25, "xwide", 0, 8 }, { 118.49, "bust" },
		{ 121.92, "bust", 0, 0, { size = "close" } }, { 123.79, "wide", 0, 5 }, { 124.75, "knee" },
		{ 127.85, "bust" }, { 129.17, "waist" }, { 131.42, "xwide", 0, 8 }, { 133.29, "bust" }, { 134.71, "knee" },
		{ 137.09, "bust" }, { 138.33, "full" }, { 141.59, "waist" }, { 144.72, "wide", 0, 5, { size = "full" } },
		{ 146.72, "bust" }, { 147.19, "full" }, { 148.12, "knee", 0, 0, { size = "waist" } },
		{ 148.59, "bust", 0, 0, { size = "close" } }, { 151.25, "waist", 0, 0, { size = "bust" } },
		{ 153.95, "waist" }, { 154.65, "wide", 0, 5 }, { 157.42, "bust" }, { 159.68, "wide", 0, 5 },
		{ 165.14, "bust" }, { 166.85, "waist" }, { 172.85, "wide", 0, 5 }, { 174.52, "bust" },
		{ 175.43, "wide", 0, 5 }, { 178.23, "knee" }, { 179.39, "wide", 0, 5 }, { 181.89, "bust" },
	}),
}
ClubCamera.Songs[80583279340768] = {
	video = "MBC Show! Music Core 2026-03-21, youtube erNe2L0beR0",
	offset = -0.7,
	shots = cutList({
		{ 0, "waist" }, { 2.13, "knee" }, { 3.11, "bust" }, { 3.87, "knee" }, { 7.85, "full" }, { 10.18, "bust" },
		{ 19.46, "waist" }, { 22.2, "wide", 0, 5 }, { 22.8, "wide", 0, 5, { size = "full" } }, { 24.1, "knee" },
		{ 25.52, "bust" }, { 26.89, "knee" }, { 28.84, "bust" }, { 29.9, "full" }, { 30.98, "bust" },
		{ 32.3, "wide", 0, 5 }, { 39.29, "bust" }, { 41.24, "xwide", 0, 8 },
		{ 43.7, "wide", 0, 5, { size = "full" } }, { 45.8, "waist", 0, 0, { size = "knee" } }, { 49.97, "bust" },
		{ 50.57, "bust", 0, 0, { size = "close" } }, { 53.97, "wide", 0, 5 }, { 55.26, "knee" }, { 56.97, "bust" },
		{ 57.73, "wide", 0, 5 }, { 58.83, "full" }, { 59.67, "waist" }, { 60.78, "knee" }, { 61.95, "wide", 0, 5 },
		{ 62.67, "bust" }, { 64.57, "wide", -5, 5, { size = "full" } }, { 65.97, "waist" }, { 66.96, "bust" },
		{ 68.14, "wide", 0, 5 }, { 69.63, "bust", 0, 0, { size = "close" } },
		{ 71.53, "waist", 5, 0, { size = "bust" } }, { 76.43, "waist" }, { 78.19, "wide", 0, 5 }, { 80.46, "bust" },
		{ 82.1, "full" }, { 82.96, "waist" }, { 84.53, "wide", 0, 5 }, { 87.37, "waist" }, { 89.37, "knee" },
		{ 91.22, "wide", 0, 5 }, { 92.37, "waist" }, { 93.63, "full" }, { 95.04, "bust" }, { 97.4, "xwide", 0, 8 },
		{ 99.57, "bust" }, { 102.7, "full" }, { 103.66, "waist" }, { 105.79, "wide", 0, 5 }, { 108.03, "bust" },
		{ 109.53, "waist" }, { 112.5, "xwide", 0, 8 }, { 113.3, "wide", 0, 5 }, { 114.12, "waist" },
		{ 115.5, "bust" }, { 117.63, "wide", 0, 5 }, { 119.2, "waist", 0, 0, { size = "knee" } },
		{ 120.1, "wide", 0, 5 }, { 120.58, "full" }, { 121.35, "knee" }, { 122.13, "full" },
		{ 122.67, "full", 0, 0, { size = "knee" } }, { 125.17, "full" }, { 127.23, "wide", 0, 5, { size = "full" } },
		{ 128.53, "full" }, { 129.26, "bust" }, { 130.06, "wide", 0, 5 }, { 132.27, "bust" },
		{ 134.07, "wide", 0, 5 }, { 139.03, "waist" }, { 140.72, "wide", 0, 5 }, { 144.3, "bust" },
		{ 144.8, "wide", 0, 5 }, { 146.68, "bust" }, { 147.79, "wide", 0, 5 }, { 149.17, "bust" },
		{ 154.29, "wide", 0, 5 }, { 160.44, "bust" }, { 163.7, "wide", 0, 5 }, { 165.1, "full" },
		{ 167.31, "wide", 0, 5 }, { 168.67, "bust" }, { 170.63, "full" }, { 172.31, "bust" },
		{ 177.53, "wide", 0, 5, { size = "full" } }, { 178.23, "full", 0, 0, { size = "knee" } },
	}),
}
-- (D-1014) ATEEZ-BAD is on the old 3× file again (ATEEZ-BAD 2 keeps 120615582016729):
-- both files run on the same song clock, so both get the same shots
ClubCamera.Songs[134942349436280] = ClubCamera.Songs[120615582016729]
-- (D-1023) 키키-Pop Off is on the x1 upload 131620527618857 now (old 3× file 129996145931101)
ClubCamera.Songs[131620527618857] = ClubCamera.Songs[129996145931101]
-- (D-1862) RESCENE-Pretty Girl is on the x1 upload 140273876429390 now (old 3× file 89634330677538, same song clock)
ClubCamera.Songs[140273876429390] = ClubCamera.Songs[89634330677538]
-- (D-1042) ALLDAY PROJECT-CRASH is on the new upload 86115718533153 (fileSpeed 1.0499,
-- the same song clock as the old 3× file 104827635407586, feat/crash-choreo-1109)
ClubCamera.Songs[86115718533153] = ClubCamera.Songs[104827635407586]
-- (D-1363) YENA-Catch Catch new upload 119002946047943 (fileSpeed 1.0702): same song clock
ClubCamera.Songs[119002946047943] = ClubCamera.Songs[80583279340768]
-- (D-1382) aespa-Lemonade new upload 101586065131501 (fileSpeed 1.0499): same song clock
ClubCamera.Songs[101586065131501] = ClubCamera.Songs[132067415333401]

-- (D-1046) Hearts2Hearts-Lemon Tang: MBC Show! Music Core 2026-06-27 (youtube a8tzYxhBjOg),
-- video = song + 10.0 s (no mp3: the practice video's sound, = song + 0.00 by the
-- choreography D-1040, lined up with the stage: +10.00 in every window).
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 161.9 s.
ClubCamera.Songs[97032815457241] = {
	video = "MBC Show! Music Core 2026-06-27, youtube a8tzYxhBjOg",
	offset = 10.0,
	shots = cutList({
		{ 0, "bust" }, { 1.9, "wide", 0, 5 }, { 4.33, "bust" }, { 5.26, "waist" }, { 10.13, "wide", 0, 5 },
		{ 11.57, "bust" }, { 13.42, "knee" }, { 14.52, "bust" }, { 15.83, "knee" }, { 17.61, "waist" },
		{ 19.07, "bust" }, { 22.07, "waist" }, { 23.13, "full" }, { 24.51, "bust" }, { 26.47, "xwide", 0, 8 },
		{ 28.29, "bust" }, { 32.48, "wide", 0, 5 }, { 33.49, "full" }, { 34.93, "bust" }, { 36.71, "wide", 0, 5 },
		{ 38.93, "knee", 0, 0, { size = "waist" } }, { 40.8, "bust" }, { 42.47, "wide", 0, 5 }, { 44.84, "knee" },
		{ 45.73, "bust" }, { 46.17, "wide", 5, 5, { size = "full" } }, { 48.07, "bust" }, { 48.88, "waist" },
		{ 50.11, "wide", 0, 5 }, { 50.6, "waist" }, { 55, "bust" }, { 56.07, "bust", 0, 0, { size = "close" } },
		{ 58, "bust" }, { 61.02, "full" }, { 62.69, "bust" }, { 66.62, "full" }, { 68.04, "bust" },
		{ 71.67, "wide", 0, 5 }, { 73.55, "knee" }, { 75.4, "wide", 0, 5 }, { 77.63, "knee" }, { 79.24, "waist" },
		{ 81.13, "wide", 0, 5 }, { 83.37, "bust" }, { 85.1, "knee" }, { 86.8, "bust" },
		{ 88.73, "wide", 0, 5, { size = "full" } }, { 91.23, "waist" }, { 91.77, "bust" },
		{ 92.23, "wide", 0, 5, { size = "full" } }, { 94.03, "bust" }, { 95.2, "bust", 0, 0, { size = "close" } },
		{ 100.53, "waist" }, { 101.65, "bust" }, { 102.3, "wide", 0, 5 }, { 103.37, "bust" }, { 105.07, "full" },
		{ 106.5, "bust" }, { 107.97, "wide", 0, 5 }, { 109.1, "waist" }, { 110.17, "bust" },
		{ 111.93, "wide", 0, 5 }, { 113, "bust" }, { 113.82, "wide", 0, 5 }, { 115.7, "bust" }, { 118.63, "waist" },
		{ 119.07, "wide", 0, 5 }, { 119.53, "wide", 0, 5, { size = "full" } }, { 123.37, "bust" },
		{ 125.2, "full", 0, 0, { size = "knee" } }, { 129.17, "bust" }, { 131.53, "knee" },
		{ 133.5, "wide", 0, 5, { size = "full" } }, { 134.93, "knee" }, { 135.57, "xwide", 0, 8, { size = "wide" } },
		{ 136.6, "wide", 0, 5 }, { 137.86, "waist" }, { 138.57, "wide", 0, 5 }, { 140.67, "waist" },
		{ 144.07, "wide", 0, 5, { size = "full" } }, { 148.27, "waist", 0, 0, { size = "bust" } },
		{ 149.83, "bust" }, { 151.07, "wide", 0, 5, { size = "full" } }, { 155.83, "waist" },
		{ 157.2, "wide", 0, 5, { size = "full" } }, { 159.37, "bust" },
	}),
}
-- (D-1295) RESCENE-백화요란: MBC Show! Music Core 2026-11-07 (youtube C7vNpNTv7fQ),
-- video = song + 11.25 s (original mp3 lined up with the stage sound, +11.20..+11.25 in
-- every 10 s window; the choreography D-1292 uses the same song clock).
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 211.0 s.
ClubCamera.Songs[74619423082896] = {
	video = "MBC Show! Music Core 2026-11-07, youtube C7vNpNTv7fQ",
	offset = 11.25,
	shots = cutList({
		{ 0, "wide", 0, 5 }, { 2.2, "knee" }, { 4, "waist" }, { 4.88, "knee" }, { 9.12, "bust" },
		{ 10.25, "wide", 0, 5, { size = "close" } }, { 12.59, "bust" }, { 15.28, "wide", 0, 5, { size = "full" } },
		{ 16.42, "wide", 0, 5 }, { 22.66, "knee" }, { 24.4, "full" }, { 26.98, "knee", 0, 0, { size = "full" } },
		{ 28.08, "waist" }, { 29.25, "bust" }, { 30.05, "xwide", 0, 8 }, { 31.58, "knee" }, { 32.97, "bust" },
		{ 36.42, "full" }, { 37.25, "bust", -15, 0, { size = "close" } }, { 39.78, "wide", 0, 5 },
		{ 41.84, "waist" }, { 43.33, "bust" }, { 44.08, "knee", 0, 0, { size = "full" } },
		{ 45.32, "waist", 0, 0, { size = "bust" } }, { 46.82, "bust" }, { 47.55, "wide", 0, 5 }, { 48.86, "waist" },
		{ 53.16, "wide", 0, 5 }, { 55.02, "bust", -5 }, { 58.55, "wide", 0, 5 }, { 62.31, "bust" },
		{ 67.05, "wide", 0, 5 }, { 69.38, "full", 0, 0, { size = "knee" } }, { 71.98, "waist" },
		{ 73.28, "full", 0, 0, { size = "knee" } }, { 73.92, "knee", 0, 0, { size = "waist" } }, { 74.52, "bust" },
		{ 75.25, "xwide", 0, 8 }, { 75.78, "wide", 0, 5 }, { 78.07, "full" }, { 78.92, "bust" },
		{ 80.12, "wide", 0, 5 }, { 84.48, "bust" }, { 86.12, "full" }, { 87.38, "bust" }, { 89.48, "full" },
		{ 91.99, "knee" }, { 93.82, "knee", 0, 0, { size = "waist" } }, { 94.45, "bust" }, { 94.88, "wide", 0, 5 },
		{ 97.33, "bust" }, { 99.98, "wide", 0, 5 }, { 100.68, "full" }, { 101.62, "knee" }, { 103.13, "wide", 0, 5 },
		{ 105.22, "bust" }, { 106.77, "waist" }, { 108.01, "bust" }, { 109.38, "wide", 0, 5 }, { 112.21, "waist" },
		{ 113.54, "wide", 0, 5 }, { 117.25, "bust" }, { 118.71, "wide", 0, 5 }, { 119.98, "bust" },
		{ 121.79, "wide", 0, 5 }, { 122.54, "bust" }, { 129.58, "xwide", 0, 8 }, { 131.51, "wide", 0, 5 },
		{ 135.18, "waist" }, { 137.37, "bust" }, { 139.62, "waist" }, { 143.12, "bust" }, { 144.57, "wide", 0, 5 },
		{ 145.08, "bust" }, { 146.38, "bust", 0, 0, { size = "close" } }, { 147.58, "bust", -5 }, { 149.55, "full" },
		{ 150.65, "waist" }, { 153.22, "bust" }, { 154.58, "xwide", 0, 8 }, { 156.31, "wide", 0, 5 },
		{ 157.99, "bust" }, { 159.75, "wide", 0, 5 }, { 160.68, "full" }, { 161.95, "waist" }, { 163.18, "bust" },
		{ 165.65, "full", 0, 0, { size = "knee" } }, { 167.68, "bust" },
		{ 168.22, "wide", -5, 5, { size = "full" } }, { 170.32, "waist" }, { 172.72, "xwide", 0, 8 },
		{ 174.45, "wide", 0, 5 }, { 175.22, "bust", 0, 0, { size = "close" } },
		{ 178.68, "waist", 0, 0, { size = "bust" } }, { 179.65, "wide", 0, 5 }, { 181.81, "bust" },
		{ 185.18, "waist" }, { 186.27, "bust" }, { 188.28, "bust", -5 }, { 190.25, "wide", 0, 5 },
		{ 192.38, "bust" }, { 195.25, "wide", 0, 5 }, { 196.59, "bust" }, { 197.65, "waist" },
		{ 200.15, "wide", 0, 5 }, { 202.34, "waist" }, { 203.92, "bust" }, { 204.68, "wide", 0, 5 },
		{ 207.25, "bust" }, { 209.4, "wide", 0, 5 },
	}),
}
-- (D-1302) SHOCK-TREASURE: MBC Show! Music Core 2026-11-07 (youtube BtqYIHuCriM),
-- video = song + 9.50 s (original mp3 lined up with the stage sound; fileSpeed 1.0499 of
-- the choreography D-1298). Shot list made by shots_to_lua.py (D-944), to 168.86 s.
ClubCamera.Songs[94024099429072] = {
	video = "MBC Show! Music Core 2026-11-07, youtube BtqYIHuCriM",
	offset = 9.5,
	shots = cutList({
		{ 0, "wide", 0, 5, { size = "full" } }, { 5.77, "bust" }, { 6.23, "full" }, { 7.22, "bust" },
		{ 12, "wide", 0, 5 }, { 13.93, "bust" }, { 15.49, "full" }, { 18.23, "bust" }, { 19.97, "wide", 0, 5 },
		{ 21.83, "bust" }, { 24.13, "wide", 0, 5 }, { 26.05, "bust" }, { 30.53, "wide", 0, 5 }, { 31.41, "full" },
		{ 32.2, "waist" }, { 33.67, "bust" }, { 34.83, "wide", 0, 5 }, { 36.53, "bust" }, { 39.97, "full" },
		{ 41.61, "bust" }, { 43.03, "wide", 0, 5 }, { 44.52, "bust" }, { 46.14, "xwide", 0, 8 }, { 47.93, "bust" },
		{ 50.23, "bust", 10, 0, { size = "close" } }, { 57.87, "waist" }, { 59.23, "wide", 0, 5 }, { 61.01, "bust" },
		{ 62.4, "waist" }, { 65.56, "bust" }, { 71.47, "wide", 0, 5 }, { 75.07, "bust" }, { 77.41, "wide", 0, 5 },
		{ 79.11, "bust" }, { 80.63, "wide", 0, 5 }, { 82.46, "waist" }, { 84.17, "wide", 0, 5 }, { 87.07, "bust" },
		{ 89.24, "wide", 0, 5 }, { 90.86, "bust" }, { 92.77, "wide", 0, 5 }, { 94.47, "bust" },
		{ 95.55, "wide", 0, 5 }, { 99.17, "bust" }, { 100.64, "full" }, { 102.57, "waist" }, { 105.3, "wide", 0, 5 },
		{ 108.43, "xwide", 0, 8 }, { 110.27, "waist" }, { 112.4, "full" }, { 113.79, "bust" },
		{ 120.9, "bust", -5, 0, { size = "waist" } }, { 123.03, "bust" }, { 124.7, "waist" },
		{ 127.6, "wide", 0, 5 }, { 129.13, "waist" }, { 129.96, "bust" }, { 130.8, "wide", 0, 5 },
		{ 132.82, "bust" }, { 134.36, "xwide", 0, 8 }, { 136.83, "bust" }, { 139.98, "waist" }, { 142.27, "knee" },
		{ 142.67, "full" }, { 144.32, "wide", 0, 5 }, { 148.9, "bust" }, { 150.6, "wide", 0, 5 },
		{ 151.55, "waist" }, { 154, "waist", 0, 0, { size = "knee" } }, { 154.97, "waist" }, { 155.9, "bust" },
		{ 157.79, "knee" }, { 159.02, "bust" }, { 162.67, "wide", 0, 5, { size = "full" } }, { 163.43, "full" },
		{ 164.24, "bust" }, { 167.2, "waist", 0, 0, { size = "knee" } },
	}),
}
-- (D-1395) BANG-After School: stage video youtube 9xtKN5zNxgA (2014-10-30 upload),
-- video = song - 8.00 s (original mp3 lined up with the stage sound, -8.00 in every 10 s
-- window): the stage starts at song 8 s, so the first wide shot also covers the intro.
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 199.0 s
-- (length 189.252 x fileSpeed 1.0515; choreography D-1394).
ClubCamera.Songs[136570075901439] = {
	video = "youtube 9xtKN5zNxgA (2014 stage)",
	offset = -8.0,
	shots = cutList({
		{ 0, "wide", 0, 5 }, { 9.9, "knee" }, { 11.17, "full" }, { 12.71, "wide", 0, 5 }, { 14.03, "bust" },
		{ 14.87, "full" }, { 16.42, "wide", 0, 5 }, { 22.07, "full" }, { 23.13, "wide", 0, 5 }, { 25.93, "knee", 5 },
		{ 28.53, "wide", 0, 5 }, { 29.97, "waist" }, { 32.17, "wide", 0, 5 }, { 34.2, "waist" }, { 35.64, "knee" },
		{ 38, "waist" }, { 41.34, "wide", 0, 5 }, { 44.14, "full" }, { 47.77, "wide", 0, 5 }, { 48.59, "waist" },
		{ 50.4, "wide", 0, 5 }, { 51.55, "xwide", 0, 8 }, { 53.87, "waist" },
		{ 58.17, "waist", 0, 0, { size = "knee" } }, { 59.77, "wide", 0, 5 }, { 61.62, "full" },
		{ 63.87, "full", -10, 0, { size = "wide" } }, { 65.97, "waist", -5, 0, { size = "bust" } },
		{ 68.27, "full" }, { 69.23, "wide", 0, 5 }, { 69.93, "waist", -15, 0, { size = "bust" } },
		{ 72.03, "wide", 0, 5 }, { 73.35, "knee" }, { 74.03, "full" }, { 75.38, "waist" }, { 78, "waist", 5 },
		{ 82.03, "xwide", 0, 8 }, { 84.31, "wide", 0, 5 }, { 86.1, "wide", 0, 5, { size = "full" } },
		{ 87.8, "waist", 20 }, { 90.13, "xwide", 0, 8 }, { 92.21, "wide", 0, 5 }, { 96.23, "bust" },
		{ 100.31, "full" }, { 102.17, "full", -5 }, { 103.37, "full", 0, 0, { size = "wide" } },
		{ 105.67, "wide", 0, 5 }, { 106.2, "xwide", 0, 8 }, { 112.74, "waist" }, { 116.81, "bust" },
		{ 117.83, "xwide", 0, 8 }, { 119.89, "wide", 0, 5 }, { 122, "waist" }, { 123.33, "full" },
		{ 124.4, "wide", 0, 5 }, { 126.1, "xwide", 0, 8 }, { 129.23, "bust" }, { 130.5, "full" },
		{ 132.12, "waist" }, { 133.73, "wide", 0, 5, { size = "full" } }, { 135.73, "full" },
		{ 137.7, "bust", 0, 0, { size = "close" } }, { 142.17, "xwide", 0, 8 }, { 148.33, "full" },
		{ 149.13, "wide", 0, 5, { size = "xwide" } }, { 152.07, "full" }, { 153.6, "waist" }, { 155.25, "knee" },
		{ 156.1, "full" }, { 156.73, "full", 0, 0, { size = "wide" } }, { 157.33, "full", 5, 0, { size = "wide" } },
		{ 159.87, "xwide", 0, 8 }, { 162.47, "full" }, { 165.93, "wide", 0, 5 },
		{ 167.13, "wide", 0, 5, { size = "xwide" } }, { 167.93, "xwide", 0, 8 }, { 170.05, "full" },
		{ 174.59, "wide", 0, 5 }, { 176, "xwide", 0, 8 }, { 178.84, "wide", 0, 5 },
		{ 180, "wide", 10, 5, { size = "xwide" } }, { 183.97, "waist" }, { 188.76, "wide", 0, 5 },
		{ 190, "xwide", 0, 8 }, { 192.07, "wide", 0, 5 }, { 193.07, "wide", 0, 5, { size = "full" } },
		{ 194.27, "full" },
	}),
}
-- (D-1770) RESCENE-With: MBC Show! Music Core 2026-11-07, youtube _XhBc88qS_E,
-- video = song + 4.70 s (original mp3 GnKDPfTd9UY lined up with the stage sound in every
-- 10 s window). Shot list made by shots_to_lua.py (D-944), to the song's end at 189.0 s (length 179.843 x fileSpeed 1.0509).
ClubCamera.Songs[112509101263761] = {
	video = "MBC Show! Music Core 2026-11-07, youtube _XhBc88qS_E",
	offset = 4.7,
	shots = cutList({
		{ 0, "bust" }, { 10.39, "waist" }, { 20.62, "bust" }, { 39.2, "waist" }, { 42.86, "bust" },
		{ 49.44, "knee" }, { 50.79, "wide", 0, 5 }, { 53.03, "bust", 0, 0, { size = "close" } }, { 57.37, "bust" },
		{ 58.57, "wide", 0, 5 }, { 60.21, "waist" }, { 61.81, "wide", 0, 5 }, { 64.87, "bust" },
		{ 65.48, "wide", 0, 5 }, { 71.68, "bust" }, { 74.89, "full" }, { 77.06, "bust" }, { 86.82, "knee" },
		{ 92.12, "full" }, { 98.2, "bust" }, { 99.65, "wide", 0, 5 }, { 100.96, "bust" }, { 102.17, "waist" },
		{ 103.42, "knee" }, { 104.33, "waist" }, { 108.89, "wide", 0, 5 }, { 111.6, "waist" },
		{ 113.44, "wide", 0, 5 }, { 115.1, "bust" }, { 117.43, "wide", 0, 5 }, { 119.05, "bust" },
		{ 120.88, "wide", 0, 5 }, { 123.33, "bust" }, { 125.32, "full" }, { 126.98, "bust" }, { 129.27, "full" },
		{ 132.05, "wide", 0, 5 }, { 134.67, "bust" }, { 137.46, "xwide", 0, 8 }, { 140.87, "bust" },
		{ 143.73, "wide", 0, 5 }, { 146.06, "bust" }, { 148.57, "wide", 0, 5 }, { 149.7, "waist" },
		{ 150.52, "bust" }, { 151.7, "xwide", 0, 8 }, { 156.63, "wide", 0, 5 }, { 157.9, "bust" },
		{ 158.8, "waist" }, { 161.08, "wide", 0, 5 }, { 163.04, "bust" }, { 164.57, "xwide", 0, 8 },
		{ 166.76, "bust" }, { 168.83, "waist" }, { 172.25, "bust" }, { 174.57, "xwide", 0, 8, { size = "wide" } },
		{ 176.23, "full" }, { 178.02, "bust" }, { 179.4, "full" }, { 180.49, "waist" }, { 181.21, "bust" },
		{ 182.03, "xwide", 0, 8 }, { 184.64, "wide", 0, 5 },
	}),
}
-- (D-1770) TWS-Call My Name: MBC Show! Music Core 2026-11-14, youtube DDNgdxLeNzE,
-- video = song - 0.30 s (original mp3 V8aLu69DTms lined up with the stage sound in every
-- 10 s window). Shot list made by shots_to_lua.py (D-944), to the song's end at 165.0 s (length 154.084 x fileSpeed 1.0708).
ClubCamera.Songs[129638210426239] = {
	video = "MBC Show! Music Core 2026-11-14, youtube DDNgdxLeNzE",
	offset = -0.3,
	shots = cutList({
		{ 0, "wide", 0, 5, { size = "xwide" } }, { 6.27, "bust" }, { 8.36, "waist" },
		{ 12.4, "bust", 0, 0, { size = "close" } }, { 13.83, "wide", 0, 5 }, { 15.24, "waist" },
		{ 16.2, "wide", 0, 5 }, { 20.21, "bust" }, { 21.67, "waist" }, { 23.4, "wide", 0, 5 }, { 24.23, "bust" },
		{ 25.25, "knee" }, { 26, "full" }, { 26.77, "knee" }, { 29.67, "waist" }, { 30.1, "knee" },
		{ 33.26, "waist" }, { 34.74, "wide", 0, 5 }, { 37.13, "waist" }, { 38.5, "full" }, { 40.63, "waist" },
		{ 47.83, "full" }, { 48.53, "wide", 0, 5 }, { 49.23, "knee" }, { 50, "bust" }, { 51.18, "xwide", 0, 8 },
		{ 51.93, "xwide", 0, 8, { size = "wide" } }, { 52.83, "wide", 0, 5 }, { 55.73, "knee" }, { 56.43, "waist" },
		{ 57.78, "wide", 0, 5 }, { 58.87, "bust" }, { 60.57, "knee" }, { 62.5, "waist" }, { 64.67, "wide", 0, 5 },
		{ 66.22, "bust" }, { 67.6, "bust", 0, 0, { size = "waist" } }, { 67.97, "wide", 0, 5 }, { 68.63, "knee" },
		{ 69.72, "bust" }, { 70.5, "waist" }, { 73.39, "wide", 0, 5 }, { 74.39, "bust" }, { 75.9, "wide", 0, 5 },
		{ 77.69, "bust" }, { 82.07, "full", 0, 0, { size = "wide" } }, { 85.37, "full" }, { 86.8, "bust" },
		{ 87.97, "knee" }, { 90.32, "bust" }, { 91.85, "knee" }, { 93.63, "full" }, { 97.02, "bust" },
		{ 98.4, "wide", 0, 5 }, { 101.2, "xwide", 0, 8, { size = "wide" } },
		{ 101.9, "full", 0, 0, { size = "knee" } }, { 102.97, "waist" },
		{ 103.37, "wide", 0, 5, { size = "xwide" } }, { 104.07, "waist" }, { 104.43, "bust" }, { 104.8, "waist" },
		{ 106.14, "bust" }, { 107.7, "wide", 0, 5 }, { 109.53, "waist" }, { 111.56, "wide", 0, 5 },
		{ 114.7, "waist" }, { 115.53, "full" }, { 116.21, "wide", 0, 5 }, { 116.67, "full" }, { 118.43, "waist" },
		{ 120.07, "wide", 0, 5 }, { 122.03, "waist" }, { 122.47, "xwide", 0, 8, { size = "wide" } },
		{ 124.43, "full", 0, 0, { size = "wide" } }, { 128.33, "bust" }, { 129.56, "wide", 0, 5 },
		{ 130.83, "knee" }, { 132.18, "bust" }, { 133.93, "wide", 0, 5, { size = "full" } }, { 137, "xwide", 0, 8 },
		{ 138.23, "waist" }, { 140.57, "wide", 0, 5 }, { 141.83, "full" }, { 142.33, "bust" },
		{ 145.27, "bust", 10 }, { 145.8, "waist", 0, 0, { size = "knee" } }, { 147.67, "wide", 0, 5 },
		{ 148.43, "bust" }, { 149.53, "bust", 5 }, { 150.7, "xwide", 0, 8 }, { 151.87, "wide", 0, 5 },
		{ 153.82, "waist" }, { 158.66, "full" }, { 160.03, "bust", -10 }, { 161.43, "bust", 5 },
	}),
}
-- (D-1770) NCT DREAM-Boogie Woogie: SBS Inkigayo 2026-11-15, youtube _PPPSs8FOmo,
-- video = song + 17.15 s (original mp3 2Qhc7UPX_5Y lined up with the stage sound in every
-- 10 s window). Shot list made by shots_to_lua.py (D-944), to the song's end at 196.0 s (length 186.622 x fileSpeed 1.0503).
ClubCamera.Songs[102947379971628] = {
	video = "SBS Inkigayo 2026-11-15, youtube _PPPSs8FOmo",
	offset = 17.15,
	shots = cutList({
		{ 0, "wide", 0, 5 }, { 1.11, "full" }, { 2.25, "bust", 10, 0, { size = "waist" } }, { 3.95, "wide", 0, 5 },
		{ 4.85, "knee" }, { 5.9, "bust" }, { 7.22, "full" }, { 8.58, "knee" }, { 13.25, "waist" }, { 19.45, "full" },
		{ 20.85, "waist", 15, 0, { size = "knee" } }, { 23.08, "full" }, { 24.05, "waist", 0, 0, { size = "bust" } },
		{ 24.92, "wide", 0, 5, { size = "full" } }, { 25.88, "waist" }, { 26.75, "bust" }, { 27.98, "waist" },
		{ 29.15, "full" }, { 30.43, "waist" }, { 31.61, "bust" }, { 33.02, "knee" }, { 33.95, "bust" },
		{ 37.55, "waist" }, { 40.74, "wide", 0, 5 }, { 43.75, "bust", -5 }, { 45.85, "knee" }, { 48.16, "bust" },
		{ 50.05, "wide", 0, 5 }, { 51.48, "bust" }, { 52.19, "waist" }, { 53.82, "bust", 10, 0, { size = "waist" } },
		{ 56.75, "knee" }, { 57.72, "wide", -5, 5 }, { 59.12, "waist", 0, 0, { size = "bust" } },
		{ 60.28, "wide", 0, 5 }, { 61.21, "bust" }, { 62.15, "full" }, { 64.52, "bust" }, { 71.54, "full" },
		{ 73.11, "waist" }, { 74.68, "xwide", 0, 8 }, { 75.68, "waist" }, { 76.64, "wide", 0, 5 },
		{ 77.65, "waist" }, { 78.83, "full" }, { 79.82, "waist", -5 }, { 80.95, "full" }, { 83.22, "bust" },
		{ 87.24, "waist" }, { 88.95, "wide", 0, 5 }, { 91.56, "waist" }, { 93.88, "full" }, { 95.08, "waist" },
		{ 99.53, "knee" }, { 101.11, "bust" }, { 103.25, "waist", -5, 0, { size = "knee" } }, { 104.88, "bust" },
		{ 107.46, "full" }, { 108.52, "bust", 0, 0, { size = "close" } }, { 110.65, "wide", 0, 5 },
		{ 112.38, "waist", -15, 0, { size = "bust" } }, { 114.02, "xwide", 0, 8 }, { 115.33, "full" },
		{ 116.27, "bust" }, { 117.65, "wide", 0, 5 }, { 119.08, "waist", -5, 0, { size = "knee" } },
		{ 121.38, "waist" }, { 122.76, "knee" }, { 123.73, "wide", 0, 5 },
		{ 124.42, "bust", 5, 0, { size = "close" } }, { 125.92, "wide", 0, 5, { size = "full" } },
		{ 128.52, "waist" }, { 129.78, "bust" }, { 130.55, "wide", 0, 5 }, { 132.31, "waist" },
		{ 133.46, "wide", 0, 5 }, { 135.52, "waist" }, { 137.4, "bust" }, { 138.74, "full" }, { 140.28, "bust" },
		{ 142.55, "xwide", 0, 8 }, { 143.4, "wide", 0, 5 }, { 144.75, "full" }, { 145.28, "knee" },
		{ 147.69, "wide", 0, 5 }, { 148.62, "bust" }, { 151.65, "full" }, { 152.29, "waist" }, { 153.32, "bust" },
		{ 156.52, "full" }, { 158.79, "bust" }, { 161.65, "full" }, { 162.48, "bust" },
		{ 163.72, "wide", 0, 5, { size = "full" } }, { 166.78, "bust" }, { 168.08, "wide", 0, 5 },
		{ 169.72, "bust" }, { 170.48, "waist" }, { 171.22, "bust" }, { 171.98, "wide", 0, 5, { size = "full" } },
		{ 173.98, "bust" }, { 176.02, "wide", 0, 5 }, { 177.25, "waist" }, { 180.25, "bust" },
		{ 181.85, "wide", 10, 5, { size = "xwide" } }, { 186.28, "waist" }, { 189.13, "wide", 0, 5 },
		{ 191.72, "bust" },
	}),
}
-- (D-1770) H1-KEY-Unbelievable: SBS Inkigayo 2026-11-15, youtube Rhhx_sDc3hc,
-- video = song + 0.10 s (original mp3 aj_2goO-n8A lined up with the stage sound in every
-- 10 s window). Shot list made by shots_to_lua.py (D-944), to the song's end at 135.3 s (length 128.882 x fileSpeed 1.0499).
ClubCamera.Songs[81736514719301] = {
	video = "SBS Inkigayo 2026-11-15, youtube Rhhx_sDc3hc",
	offset = 0.1,
	shots = cutList({
		{ 0, "wide", 0, 5, { size = "full" } }, { 4.17, "xwide", 0, 8 }, { 6.4, "waist" }, { 8.51, "xwide", 0, 8 },
		{ 9.53, "waist", -10 }, { 11.33, "waist" }, { 14.35, "wide", 0, 5 }, { 15.9, "bust" }, { 17.42, "waist" },
		{ 18.73, "wide", 0, 5 }, { 19.57, "bust" }, { 21.37, "xwide", 0, 8 }, { 21.86, "wide", 0, 5 },
		{ 23.13, "bust" }, { 26.63, "knee" }, { 27.77, "bust" }, { 29.1, "wide", 0, 5 }, { 30.04, "full" },
		{ 31.23, "bust" }, { 32.77, "knee" }, { 33.2, "full" }, { 35.07, "xwide", 0, 8 }, { 36.19, "full" },
		{ 37.05, "waist" }, { 38.67, "full" }, { 40.29, "bust" }, { 42.27, "wide", 0, 5 }, { 43.48, "knee" },
		{ 44.55, "waist" }, { 46, "waist", 0, 0, { size = "knee" } }, { 48.23, "waist" }, { 50.35, "bust" },
		{ 52.17, "waist" }, { 58.1, "bust" }, { 59.29, "full" }, { 60.47, "bust" }, { 62.05, "wide", 0, 5 },
		{ 62.74, "bust" }, { 64.1, "wide", 0, 5, { size = "full" } }, { 65.9, "bust" }, { 67.73, "wide", 0, 5 },
		{ 69.73, "bust" }, { 71.37, "xwide", 0, 8, { size = "wide" } }, { 72.27, "waist" },
		{ 72.9, "waist", -5, 0, { size = "bust" } }, { 74.97, "wide", 0, 5 }, { 76.72, "full" }, { 77.7, "bust" },
		{ 78.63, "wide", 0, 5 }, { 80.14, "bust" }, { 82.23, "xwide", 0, 8, { size = "wide" } }, { 83.17, "waist" },
		{ 84.89, "bust" }, { 86.43, "wide", 0, 5 }, { 87.7, "bust", 0, 0, { size = "waist" } }, { 89.63, "waist" },
		{ 93.27, "wide", 0, 5 }, { 95.5, "waist" }, { 96.66, "bust" }, { 98.63, "wide", 0, 5 }, { 99.89, "bust" },
		{ 100.5, "xwide", 0, 8 }, { 101.18, "wide", 0, 5 }, { 101.86, "waist" }, { 103.33, "bust" },
		{ 108.1, "wide", 0, 5 }, { 110.26, "waist" }, { 113.17, "wide", 0, 5 }, { 115.87, "waist" },
		{ 118.23, "xwide", 0, 8, { size = "wide" } }, { 119.53, "bust" }, { 120.4, "waist" },
		{ 121.77, "wide", 0, 5 }, { 124.6, "waist" }, { 126.54, "full" }, { 127.73, "bust" },
		{ 132.53, "wide", 0, 5 }, { 133.4, "bust" },
	}),
}
-- (D-1830) BOYNEXTDOOR-ANIMAL: SBS Inkigayo 2026-10-04, youtube jP0EJL44QGk,
-- video = song + 35.30 s (original mp3 g8gD2GVcg0M lined up with the stage sound in every
-- 10 s window). Shot list made by shots_to_lua.py (D-944), to the song's end at 142.9 s (length 136.107 x fileSpeed 1.05).
ClubCamera.Songs[94774089824958] = {
	video = "SBS Inkigayo 2026-10-04, youtube jP0EJL44QGk",
	offset = 35.3,
	shots = cutList({
		{ 0, "waist" }, { 2.63, "bust" }, { 10.41, "wide", 0, 5 }, { 17.03, "full" }, { 18.9, "bust" },
		{ 19.71, "waist" }, { 20.2, "knee" }, { 22.24, "waist" }, { 23.2, "wide", 0, 5 }, { 24.2, "bust" },
		{ 26.47, "wide", 0, 5 }, { 28.58, "bust" }, { 29.97, "wide", 0, 5 },
		{ 31.9, "bust", 0, 0, { size = "waist" } }, { 34.37, "full" }, { 36.03, "waist", 0, 0, { size = "bust" } },
		{ 36.67, "bust", 0, 0, { size = "close" } }, { 40.4, "wide", -5, 5, { size = "full" } }, { 41.47, "waist" },
		{ 43.31, "full" }, { 44.97, "waist" }, { 46.5, "wide", 0, 5, { size = "full" } },
		{ 48.03, "waist", -10, 0, { size = "bust" } }, { 49.7, "wide", 0, 5 }, { 51.23, "waist" },
		{ 52.33, "xwide", 0, 8 }, { 53.3, "bust" }, { 55.41, "full" }, { 58.2, "bust" }, { 60.03, "wide", -5, 5 },
		{ 61.67, "waist", 0, 0, { size = "bust" } }, { 63.33, "full" }, { 65.16, "waist" }, { 66.33, "knee" },
		{ 68.25, "waist" }, { 69.53, "full" }, { 70.34, "knee" }, { 71.17, "full" }, { 71.53, "wide", 0, 5 },
		{ 72.47, "bust" }, { 73.3, "waist" }, { 74.3, "bust" }, { 75.53, "wide", 0, 5 }, { 78.88, "knee" },
		{ 82.43, "waist" }, { 83.17, "wide", 0, 5 }, { 84.43, "full" }, { 85.71, "knee" }, { 87.07, "wide", 0, 5 },
		{ 87.55, "bust" }, { 91.17, "bust", 0, 0, { size = "waist" } }, { 93.1, "waist" }, { 95.09, "wide", 0, 5 },
		{ 96.47, "bust" }, { 97.8, "knee" }, { 98.27, "wide", 0, 5 }, { 98.83, "full" }, { 100.16, "waist" },
		{ 100.9, "bust" }, { 102.93, "bust", -15, 0, { size = "waist" } }, { 104.7, "waist" }, { 105.53, "knee" },
		{ 106.33, "full" }, { 107.4, "bust", 5 }, { 108.1, "full" }, { 109.47, "bust", 0, 0, { size = "waist" } },
		{ 111.47, "waist" }, { 113.33, "xwide", 0, 8, { size = "wide" } }, { 114.87, "full" },
		{ 116.28, "xwide", 0, 8 }, { 118.37, "bust", 0, 0, { size = "waist" } }, { 122.53, "bust" },
		{ 126.47, "waist", 5 }, { 129.57, "bust" }, { 131.19, "full" }, { 132.57, "bust" }, { 133.17, "wide", 0, 5 },
		{ 136.28, "bust" }, { 138.33, "wide", 0, 5 },
	}),
}
-- (D-1831) Magic-Secret: MBC Show! Music Core 2014-07 comeback stage, youtube wA_fxf056gk,
-- video = song - 1.10 s (original mp3 Q5HKuivlwEo lined up with the stage sound, -1.10 in every
-- 10 s window): the stage starts at song 1.1 s, so its first wide shot also covers 0..1.1.
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 204.0 s (length 194.251 x fileSpeed 1.0502;
-- choreography D-2060).
ClubCamera.Songs[124810692241835] = {
	video = "MBC Show! Music Core 2014 comeback stage, youtube wA_fxf056gk",
	offset = -1.1,
	shots = cutList({
		{ 0, "wide", 10, 5, { size = "xwide" } }, { 3.3, "bust" }, { 4.5, "full" }, { 5.67, "knee" },
		{ 6.13, "full" }, { 6.86, "wide", 0, 5 }, { 8.2, "wide", 0, 5, { size = "xwide" } }, { 9.1, "xwide", 0, 8 },
		{ 10.1, "bust", 15 }, { 12, "bust" }, { 12.37, "wide", 0, 5 }, { 13.46, "full" }, { 14.5, "bust" },
		{ 16.8, "full", 0, 0, { size = "wide" } }, { 18.63, "full" }, { 19.17, "xwide", 0, 8 },
		{ 21.27, "waist", -15 }, { 23.53, "wide", 0, 5 }, { 25.6, "knee", -5, 0, { size = "full" } },
		{ 27.5, "bust" }, { 30.27, "wide", 0, 5, { size = "full" } }, { 32.43, "bust", -15 }, { 34.27, "waist" },
		{ 35.37, "knee", 0, 0, { size = "full" } }, { 37.07, "xwide", 0, 8 }, { 38.22, "wide", 0, 5 },
		{ 39.23, "bust", -15, 0, { size = "close" } }, { 41.43, "full" }, { 43.43, "xwide", 0, 8 },
		{ 44.2, "wide", 0, 5 }, { 46.03, "waist" }, { 48.09, "full" }, { 49.05, "wide", 0, 5 }, { 50.37, "knee" },
		{ 51.57, "knee", 5, 0, { size = "full" } }, { 52.77, "wide", 0, 5 },
		{ 54.5, "waist", 0, 0, { size = "knee" } }, { 55.47, "wide", 0, 5 }, { 58.15, "xwide", 0, 8 },
		{ 59.47, "bust" }, { 62.17, "wide", 0, 5 }, { 63.93, "full" }, { 65.06, "wide", 0, 5 }, { 66, "knee" },
		{ 67.07, "wide", 0, 5 }, { 68.2, "wide", 0, 5, { size = "xwide" } }, { 69.13, "wide", 0, 5 },
		{ 70.13, "xwide", 0, 8 }, { 70.63, "waist" }, { 72.27, "knee" }, { 73.97, "xwide", 0, 8 },
		{ 74.6, "wide", 0, 5, { size = "xwide" } }, { 75.97, "wide", 0, 5 }, { 77.37, "bust", -20 },
		{ 79.57, "wide", 0, 5 }, { 81.83, "bust" }, { 84.1, "xwide", 0, 8 },
		{ 84.73, "xwide", 0, 8, { size = "wide" } }, { 86.4, "bust", 5 }, { 88.63, "wide", 0, 5 }, { 90.4, "bust" },
		{ 92.16, "full" }, { 93.13, "bust" }, { 95.33, "full", 10, 0, { size = "knee" } }, { 97.57, "wide", 0, 5 },
		{ 99.83, "bust" }, { 102, "full" }, { 102.67, "knee" }, { 103.77, "full", 0, 0, { size = "wide" } },
		{ 105, "full", 5, 0, { size = "wide" } }, { 106.6, "bust" }, { 107.77, "wide", 0, 5 }, { 109.27, "bust" },
		{ 111.07, "wide", 0, 5 }, { 113.48, "xwide", 0, 8 }, { 115.53, "bust" }, { 120.03, "waist" },
		{ 121.74, "full" }, { 123.18, "wide", 0, 5 }, { 124.53, "bust" }, { 127.87, "wide", 0, 5 },
		{ 128.6, "full" }, { 129.9, "wide", 0, 5 }, { 133.57, "bust" }, { 134.73, "wide", 0, 5 }, { 135.7, "waist" },
		{ 137.83, "knee" }, { 138.78, "full" }, { 139.42, "wide", 0, 5 }, { 140.2, "xwide", 0, 8 },
		{ 141.51, "wide", 0, 5 }, { 142.47, "bust" }, { 144.04, "knee" }, { 145.31, "bust" }, { 147, "full", 10 },
		{ 149.23, "full", 0, 0, { size = "wide" } }, { 153.03, "full" }, { 153.8, "bust" }, { 155.22, "knee" },
		{ 155.87, "bust" }, { 156.67, "full" }, { 158.76, "bust" }, { 159.63, "bust", 15 }, { 160.37, "bust" },
		{ 160.87, "xwide", 0, 8 }, { 162.29, "wide", 0, 5 }, { 164.87, "waist" }, { 165.97, "knee" },
		{ 168.8, "wide", 0, 5 }, { 169.37, "waist" }, { 170.1, "knee" }, { 171.65, "wide", 0, 5 },
		{ 173.87, "full" }, { 175.13, "wide", 0, 5 }, { 176.13, "bust" }, { 178.3, "wide", 0, 5 },
		{ 179.45, "bust" }, { 182.87, "full" }, { 183.99, "bust" }, { 185.16, "wide", 0, 5 }, { 188.12, "full" },
		{ 189.19, "wide", 0, 5 }, { 191.83, "knee" }, { 193.73, "bust" }, { 196.2, "wide", 0, 5 },
		{ 198.45, "bust" }, { 200.73, "wide", 0, 5 }, { 202.39, "full" }, { 203.23, "wide", 0, 5 },
	}),
}
-- (D-1832) ILLIT-It's Me: STUDIO CHOOM ORIGINAL 2026-05-02, youtube SToSz9n0TfI,
-- video = song + 3.00 s (original mp3 RwUKqYWyzNc lined up with the stage sound in the 10 s windows).
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 135.0 s (length 128.567 x fileSpeed 1.05; choreography D-2071).
ClubCamera.Songs[80492816031335] = {
	video = "STUDIO CHOOM ORIGINAL 2026-05-02, youtube SToSz9n0TfI",
	offset = 3.0,
	shots = cutList({
		{ 0, "full" }, { 2.03, "wide", 0, 5 }, { 3.37, "bust" }, { 4.17, "full", 0, 0, { size = "wide" } },
		{ 5.83, "bust" }, { 6.43, "wide", 0, 5, { size = "full" } }, { 6.83, "knee" }, { 8.27, "wide", 0, 5 },
		{ 8.83, "waist" }, { 9.77, "wide", 0, 5, { size = "full" } }, { 10.73, "knee" }, { 11.33, "wide", 0, 5 },
		{ 14.87, "waist" }, { 16.4, "full" }, { 17.87, "knee" }, { 18.87, "wide", 0, 5 },
		{ 19.93, "wide", 0, 5, { size = "full" } }, { 21.03, "bust" }, { 22.7, "full" }, { 23.77, "knee" },
		{ 25.57, "waist" }, { 26.47, "bust" }, { 27.79, "knee" }, { 28.76, "bust" }, { 30.13, "wide", 0, 5 },
		{ 31.87, "bust" }, { 32.37, "waist", 0, 0, { size = "bust" } }, { 33.3, "knee" },
		{ 34.5, "waist", -5, 0, { size = "knee" } }, { 36.33, "knee", 0, 0, { size = "full" } },
		{ 38.63, "waist", 0, 0, { size = "knee" } }, { 39.03, "full" }, { 41.1, "waist" }, { 42.62, "wide", 0, 5 },
		{ 44.43, "full" }, { 45.13, "bust" }, { 46.97, "wide", 0, 5 }, { 48.83, "waist" }, { 49.3, "wide", 0, 5 },
		{ 50.73, "waist" }, { 52.4, "full", 0, 0, { size = "wide" } }, { 53.27, "waist" }, { 54.1, "full" },
		{ 55.33, "bust" }, { 56.07, "wide", 0, 5 }, { 56.73, "waist" }, { 57.75, "full" }, { 58.23, "waist" },
		{ 59.03, "wide", 0, 5 }, { 60.57, "bust", -10 }, { 62.03, "full", 0, 0, { size = "knee" } },
		{ 63.03, "waist" }, { 64.05, "bust" }, { 65.47, "bust", 0, 0, { size = "waist" } }, { 67.27, "full" },
		{ 69.1, "waist" }, { 70.6, "waist", 0, 0, { size = "knee" } }, { 71.5, "waist" }, { 71.97, "wide", 0, 5 },
		{ 72.87, "full", 0, 0, { size = "knee" } }, { 73.57, "knee", 0, 0, { size = "waist" } }, { 74.23, "bust" },
		{ 75.5, "knee" }, { 77.17, "bust", 5 }, { 77.97, "full" }, { 78.73, "full", 0, 0, { size = "knee" } },
		{ 80, "wide", 0, 5 }, { 82.17, "knee" }, { 83.02, "waist" }, { 84.53, "bust" }, { 86.23, "wide", 0, 5 },
		{ 87, "full" }, { 87.42, "bust" }, { 88.5, "full" }, { 89.8, "wide", 0, 5 }, { 91.53, "full" },
		{ 93.13, "knee" }, { 93.57, "full" }, { 94.25, "knee" }, { 94.87, "full" },
		{ 95.47, "full", 0, 0, { size = "knee" } }, { 97.2, "waist", 0, 0, { size = "knee" } },
		{ 98.33, "wide", 0, 5, { size = "full" } }, { 99.53, "waist", 0, 0, { size = "knee" } },
		{ 100.2, "wide", 0, 5 }, { 100.6, "waist" }, { 101.67, "wide", 0, 5 },
		{ 103.37, "waist", 0, 0, { size = "bust" } }, { 104, "bust" }, { 105.27, "full" }, { 106.67, "bust" },
		{ 107.4, "xwide", 0, 8 }, { 108.17, "wide", 0, 5 }, { 109.43, "bust", 0, 0, { size = "waist" } },
		{ 110.53, "waist" }, { 111.33, "full" }, { 113.83, "bust" }, { 114.7, "wide", 0, 5 }, { 117.07, "bust" },
		{ 117.83, "wide", 0, 5 }, { 120.27, "bust" }, { 120.7, "waist", 0, 0, { size = "bust" } },
		{ 122.17, "full" }, { 122.63, "waist", 0, 0, { size = "bust" } }, { 124.23, "wide", 0, 5 },
		{ 125.26, "full" }, { 126.47, "knee" }, { 128.15, "wide", 0, 5 }, { 129.7, "bust", -5 },
		{ 130.73, "wide", 0, 5, { size = "full" } }, { 132.43, "wide", 0, 5 }, { 133.1, "bust" }, { 133.97, "knee" },
	}),
}
-- (D-1832) AND2BLE-Potion: SBS THE SHOW 2026-11-03, youtube WoHmLaL7HV4,
-- video = song + 8.20 s (original mp3 XqP5O4rzCvo lined up with the stage sound in the 10 s windows).
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 170.0 s (length 161.979 x fileSpeed 1.0495; choreography D-2070).
ClubCamera.Songs[88799517182805] = {
	video = "SBS THE SHOW 2026-11-03, youtube WoHmLaL7HV4",
	offset = 8.2,
	shots = cutList({
		{ 0, "bust", 0, 0, { size = "waist" } }, { 1.47, "bust" }, { 3.53, "wide", 0, 5, { size = "full" } },
		{ 4.6, "wide", 0, 5 }, { 6.37, "waist" }, { 8.43, "wide", 0, 5 }, { 9.27, "bust" }, { 9.85, "waist" },
		{ 11.13, "bust" }, { 12.03, "wide", 0, 5 }, { 13.2, "full" }, { 13.8, "waist" }, { 14.43, "bust" },
		{ 15.03, "full", -5, 0, { size = "knee" } }, { 16.17, "waist" }, { 17.13, "wide", 0, 5 }, { 17.73, "waist" },
		{ 18.73, "bust" }, { 19.43, "knee" }, { 20.73, "bust" }, { 23.4, "wide", 0, 5 }, { 24.66, "knee" },
		{ 27, "bust" }, { 28.35, "wide", 0, 5 }, { 29.33, "bust" }, { 29.81, "waist" },
		{ 31.47, "wide", 0, 5, { size = "full" } }, { 33.47, "waist" }, { 34.9, "full" }, { 35.83, "bust" },
		{ 39, "wide", 0, 5 }, { 40.39, "waist" }, { 41.17, "bust" }, { 41.9, "wide", 0, 5 },
		{ 42.3, "wide", 0, 5, { size = "full" } }, { 45.1, "waist" }, { 46.2, "bust" }, { 46.67, "wide", 0, 5 },
		{ 48.2, "knee" }, { 49.24, "waist" }, { 50.93, "wide", 0, 5 }, { 51.87, "full" }, { 53.1, "bust" },
		{ 54.47, "full" }, { 55.9, "full", 0, 0, { size = "wide" } }, { 56.87, "wide", 0, 5 }, { 57.37, "bust" },
		{ 58.8, "full" }, { 59.77, "bust" }, { 61.6, "wide", 0, 5 }, { 64.87, "waist" }, { 65.57, "bust" },
		{ 66.53, "full" }, { 67.3, "wide", 0, 5 }, { 67.96, "waist" }, { 69.47, "wide", 0, 5 }, { 70.37, "full" },
		{ 71.13, "knee" }, { 72.27, "bust" }, { 74.47, "knee" }, { 75.51, "wide", 0, 5 }, { 78.03, "bust" },
		{ 79.43, "waist" }, { 81.47, "bust" }, { 82.37, "waist" }, { 83.5, "wide", 0, 5, { size = "full" } },
		{ 85.07, "full" }, { 85.67, "bust" }, { 86.72, "waist" }, { 87.92, "wide", 0, 5 }, { 89.8, "bust" },
		{ 90.98, "waist" }, { 91.67, "wide", 0, 5 }, { 94.17, "bust" }, { 97.3, "xwide", 0, 8, { size = "wide" } },
		{ 98.47, "wide", 0, 5 }, { 99.37, "bust", 0, 0, { size = "close" } }, { 100.97, "xwide", 0, 8 },
		{ 101.33, "wide", 0, 5 }, { 104.13, "bust" }, { 105.73, "bust", 0, 0, { size = "close" } },
		{ 106.63, "wide", 0, 5 }, { 108.1, "full" }, { 109.01, "bust" }, { 110.37, "full" }, { 111.4, "waist" },
		{ 112.55, "wide", 0, 5 }, { 113.7, "bust" }, { 114.63, "waist" }, { 116.37, "knee" },
		{ 116.87, "wide", 0, 5 }, { 117.83, "knee" }, { 119.77, "bust" }, { 122.47, "full" },
		{ 124.6, "wide", 0, 5, { size = "xwide" } }, { 125.33, "waist" }, { 128.23, "full" }, { 130.24, "waist" },
		{ 131.37, "knee" }, { 132.57, "bust", -5 }, { 133.47, "bust", 0, 0, { size = "waist" } },
		{ 134.03, "wide", 0, 5, { size = "full" } }, { 136.97, "bust" }, { 138.33, "wide", 0, 5 },
		{ 139.73, "waist" }, { 140.63, "bust" }, { 141.67, "full" }, { 142.81, "wide", 0, 5 }, { 144.7, "bust" },
		{ 145.7, "wide", 0, 5, { size = "full" } }, { 147.63, "bust" }, { 149.53, "wide", 0, 5 }, { 150.86, "full" },
		{ 151.53, "bust" }, { 153.43, "full" }, { 155.63, "bust" }, { 156.33, "bust", -5, 0, { size = "waist" } },
		{ 163.8, "wide", 0, 5 },
	}),
}
-- (D-1833) Brown Eyed Girls-Abracadabra: MBC Music Core 2014-07 comeback stage, youtube gKZ2BsYK3VM,
-- video = song - 0.20 s (original mp3 dWsWbd7xauA lined up with the stage sound, -0.20 in every 10 s window).
-- Shot list made by shots_to_lua.py (D-944), to the song's end at 184.0 s (length 175.124 x fileSpeed 1.0507;
-- choreography D-2080).
ClubCamera.Songs[84753987256309] = {
	video = "MBC Music Core 2014 comeback stage, youtube gKZ2BsYK3VM",
	offset = -0.2,
	shots = cutList({
		{ 0, "waist" }, { 6.83, "full" }, { 8.1, "wide", 0, 5 }, { 10.83, "waist" }, { 11.73, "wide", 0, 5 },
		{ 12.57, "knee" }, { 13.57, "waist" }, { 13.97, "knee" }, { 14.77, "wide", 0, 5 }, { 15.63, "full" },
		{ 17.5, "bust" }, { 19, "waist" }, { 20.97, "full" }, { 21.83, "bust" }, { 24.83, "waist" },
		{ 26.13, "bust" }, { 27.13, "full" }, { 27.67, "knee" }, { 28.37, "bust" }, { 29.43, "full" },
		{ 30.07, "wide", 0, 5 }, { 33.13, "waist" }, { 35.93, "bust" }, { 37.13, "bust", -5 },
		{ 37.9, "wide", 0, 5 }, { 39.28, "full" }, { 43.3, "bust", -10 }, { 45.3, "wide", 0, 5 }, { 47.37, "waist" },
		{ 49.1, "knee", -15, 0, { size = "waist" } }, { 51.03, "bust" }, { 52.87, "wide", 0, 5 }, { 56.77, "bust" },
		{ 59.61, "wide", 0, 5 }, { 62.4, "full" }, { 63.6, "bust" }, { 64.43, "waist" }, { 65.4, "full" },
		{ 66.47, "knee" }, { 67.5, "bust" }, { 68.1, "waist" }, { 69.9, "bust", 0, 0, { size = "waist" } },
		{ 70.5, "waist", -10 }, { 71.43, "bust" }, { 72.1, "knee" }, { 73.47, "wide", 0, 5 }, { 75.13, "knee" },
		{ 77.2, "waist" }, { 79.1, "knee" }, { 81.07, "waist" }, { 82.9, "bust" }, { 84.67, "full" },
		{ 86.63, "bust" }, { 88.37, "wide", 0, 5 }, { 94.07, "waist" }, { 96.37, "bust" }, { 97.87, "full" },
		{ 99, "waist" }, { 99.93, "wide", 0, 5 }, { 100.53, "full" }, { 101.97, "bust" }, { 103.6, "waist" },
		{ 105, "wide", 0, 5 }, { 108.9, "bust" }, { 110.6, "waist", -15 }, { 112.9, "bust" }, { 114.7, "full" },
		{ 115.77, "waist" }, { 116.57, "full" }, { 118.47, "waist", -5 },
		{ 119.07, "bust", 0, 0, { size = "close" } }, { 120.4, "knee" }, { 124.07, "bust", -10 },
		{ 126.2, "wide", 0, 5 }, { 127.77, "knee" }, { 129.77, "wide", 0, 5 }, { 132.17, "wide", 10, 5 },
		{ 137.4, "wide", 0, 5 }, { 139.13, "bust" }, { 141.37, "wide", 0, 5 }, { 142.37, "knee" },
		{ 143.41, "bust" }, { 144.3, "bust", -5 }, { 146.47, "wide", 0, 5 }, { 148.47, "bust" }, { 150.24, "full" },
		{ 153.8, "waist" }, { 155.27, "bust" }, { 157.03, "waist", 0, 0, { size = "knee" } },
		{ 158.3, "wide", 0, 5 }, { 160.9, "knee" }, { 162.53, "bust", 5 }, { 163.67, "full" },
		{ 165.3, "wide", 0, 5 }, { 166.28, "full" }, { 167.1, "waist" }, { 169.3, "full" }, { 171.8, "bust", 5 },
		{ 173.33, "waist", -5, 0, { size = "knee" } }, { 174.73, "full" }, { 176.17, "bust" },
		{ 177.07, "wide", 0, 5 }, { 180.68, "knee" },
	}),
}
return ClubCamera
