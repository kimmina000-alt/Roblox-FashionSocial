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
	to: Pose?, move: {number}?, ease: string?, fov: number? }
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
ClubCamera.Songs[134942349436280] = {
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

return ClubCamera
