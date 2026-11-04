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

-- A2O LITE-NEON: MBC Show! Music Core 2026-10-24 stage (youtube pKvx_bN74j4,
-- its first half; the second half is a fixed full-stage camera), video =
-- song + 1.00 s (loudness matched over the whole song, no drift, D-898).
-- Mostly long steadicam takes moving round the members (take: keyframes read
-- from 0.5 s strips), beat cuts in the intro, crane / audience wides between.
local take = ClubCamera.take
ClubCamera.Songs[97511700575810] = {
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
		take({ { 48.3, "full", yaw = 20 }, { 49.0, "knee", yaw = 10 }, { 50.5, "knee" } }),
		take({ { 51.0, "wide", pitch = 15 }, { 51.6, "wide", pitch = 15 }, { 52.0, "close", roll = -15 }, { 52.6, "bust" }, { 53.0, "xwide", pitch = 4 },
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
		take({ { 145.93, "waist" }, { 146.5, "knee" }, { 147.0, "wide", pitch = 6 }, { 148.6, "wide", yaw = 10, pitch = 6 }, { 149.0, "knee" }, { 149.5, "waist" } }),
		-- bridge
		take({ { 149.7, "knee" }, { 152.6, "knee", yaw = 10 } }),
		take({ { 152.93, "knee", roll = -6 }, { 153.5, "wide", pitch = 6 }, { 154.0, "full" }, { 155.0, "full", yaw = -10 }, { 155.5, "knee" }, { 156.5, "knee" } }),
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
ClubCamera.Songs[91762270038050] = {
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
ClubCamera.Songs[125703446596781] = {
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

return ClubCamera
