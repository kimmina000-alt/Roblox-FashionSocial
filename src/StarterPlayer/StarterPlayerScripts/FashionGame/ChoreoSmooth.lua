--!strict
-- Choreography jitter clean-up (user 2026-11-03, D-811: "미세하게 바들바들
-- 떨리는 부분 보정 … 멀쩡한 안무까지 수정하지 말고"). The choreography
-- animations are captured at 24 keyframes a second, with small zigzags in
-- the joints. For each animation this reads the keyframes once and marks the
-- keyframes where a joint goes back and forth: a small turn back (both steps
-- under ClubConfig.ChoreoSmoothing.maxStep degrees) next to another one. Only
-- those are eased toward their neighbours (1/4, 1/2, 1/4), `passes` times.
-- Every other keyframe stays exactly as it was (a lone turn back is the top
-- of a real move), and nothing lags (the keyframes are known ahead).
-- Get A Guitar, 20 pieces: 2,818 zigzag keyframes → 0, largest change 3.5°.
--
--   ChoreoSmooth.load(animationId)                 -- starts reading (async)
--   ChoreoSmooth.correction(animationId, partName, t) -- CFrame? to multiply onto the joint's Transform at time t
--   ChoreoSmooth.clear()                           -- read again with new settings
--   ChoreoSmooth.hips(animationId, t)              -- Vector3? the hips' travel at time t (D-813)
--   ChoreoSmooth.retarget(animationId, t)          -- waist, left, right turns for joints R15 lacks (D-843)
--   ChoreoSmooth.pop(animationId, t)               -- waist, neck for a chest pop from ChoreoFixes (D-848)
--   ChoreoSmooth.fixes(animationId)                -- the ClubConfig.ChoreoFixes entry, or nil (D-852)
--   ChoreoSmooth.pose(animationId, t)              -- joint turns to set / add for a lost pose, and how much (D-855)

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

-- per animation id: per part name, the keyframe times and the correction
-- (raw:Inverse() * clean) at each keyframe; parts with no zigzag are left out
type Track = { times: {number}, fix: {CFrame} }
local cache: {[string]: {[string]: Track}} = {}
-- (D-813) per animation id: the hips' (LowerTorso) sideways / forward place
-- at each keyframe, as made (ChoreoController moves the dancer along it)
type Path = { times: {number}, at: {Vector3}, facing: {number} }
local paths: {[string]: Path} = {}
-- (D-843) per animation id: the turns of the captured joints a standard R15
-- body does not have, at each keyframe, folded onto joints it does have:
-- waist = Spine * Chest (after UpperTorso), left / right = the clavicle
-- (before the upper arm)
type Retarget = { times: {number}, waist: {CFrame}?, left: {CFrame}?, right: {CFrame}? }
local retargets: {[string]: Retarget} = {}

local ChoreoSmooth = {}

-- (D-985, user: Catch Catch "전체적으로 좌우 반전") a song with `mirror = true`
-- dances its pieces as their mirror image: the keyframes are read with left and
-- right swapped and turned across the body's own left / right plane, so the
-- clean-ups, the travel path and the facing are all of the mirrored dance, and
-- ChoreoController mirrors the animator's pose the same way each frame
local mirrored: {[number]: boolean} = {}
for _, track in ipairs(ClubConfig.Playlist or {}) do
	if track.mirror and track.choreo then
		for _, entry in ipairs(track.choreo) do
			local id = if typeof(entry) == "table" then entry.id else entry
			if typeof(id) == "number" then mirrored[id] = true end
		end
	end
end
function ChoreoSmooth.isMirrored(animationId: string): boolean
	return mirrored[tonumber(animationId:match("%d+")) or 0] == true
end
-- a joint pose seen in a mirror across the body's left / right plane (local x → −x)
function ChoreoSmooth.mirrorPose(t: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = t:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end
function ChoreoSmooth.otherSide(name: string): string
	if name:find("Left") then return (name:gsub("Left", "Right")) end
	if name:find("Right") then return (name:gsub("Right", "Left")) end
	return name
end

local function step(a: CFrame, b: CFrame): Vector3
	local axis, angle = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return axis * math.deg(angle)
end

-- the keyframes where the joint turns back by a small angle
local function turnsBack(poses: {CFrame}, maxStep: number): {boolean}
	local out = {}
	for k = 2, #poses - 1 do
		local d1, d2 = step(poses[k - 1], poses[k]), step(poses[k], poses[k + 1])
		local m1, m2 = d1.Magnitude, d2.Magnitude
		out[k] = m1 > 0.01 and m2 > 0.01 and m1 < maxStep and m2 < maxStep and d1:Dot(d2) < 0
	end
	return out
end

-- eases the zigzag keyframes of one joint: a small turn back right next to
-- another one (back and forth). A lone turn is the top of a real move (a
-- beat) and stays. Returns the cleaned list, or nil when nothing changed.
local function clean(raw: {CFrame}, maxStep: number, passes: number): {CFrame}?
	local out = table.clone(raw)
	local changed = false
	for _ = 1, passes do
		local back = turnsBack(out, maxStep)
		local nextOut = table.clone(out)
		for k = 2, #out - 1 do
			if back[k] and (back[k - 1] or back[k + 1]) then
				local mid = out[k - 1]:Lerp(out[k + 1], 0.5)
				nextOut[k] = out[k]:Lerp(mid, 0.5)
				changed = true
			end
		end
		out = nextOut
	end
	return if changed then out else nil
end

-- (D-851) the stretches where a joint keeps turning one way and back
-- (between two turn backs): from keyframe, to keyframe, degrees turned
local function runs(poses: {CFrame}): {{number}}
	local out, from, turned, dir = {}, 1, 0, nil :: Vector3?
	for k = 2, #poses do
		local d = step(poses[k - 1], poses[k])
		if d.Magnitude < 0.3 then continue end
		if dir and d:Dot(dir) < 0 then
			table.insert(out, { from, k - 1, turned })
			from, turned = k - 1, 0
		end
		dir = d
		turned += d.Magnitude
	end
	table.insert(out, { from, #poses, turned })
	return out
end

-- (D-851) a slower wobble than clean() catches: a turn back between two
-- short, small swings (at most maxLen keyframes and maxSwing degrees each)
-- is eased toward the line through its neighbours two keyframes away, never
-- further than `cap` degrees from the capture
local function calm(poses: {CFrame}, raw: {CFrame}, settings: {maxSwing: number, maxLen: number, passes: number, cap: number}): {CFrame}?
	local out = table.clone(poses)
	local changed = false
	local function small(r: {number}): boolean
		return r[2] - r[1] <= settings.maxLen and r[3] < settings.maxSwing
	end
	for _ = 1, settings.passes do
		local rs = runs(out)
		local nextOut = table.clone(out)
		for i = 1, #rs - 1 do
			if small(rs[i]) and small(rs[i + 1]) then
				local peak = rs[i][2]
				for k = math.max(2, peak - 1), math.min(#out - 1, peak + 1) do
					local lo, hi = math.max(1, k - 2), math.min(#out, k + 2)
					local line = out[lo]:Lerp(out[hi], (k - lo) / (hi - lo))
					local want = out[k]:Lerp(line, if k == peak then 0.5 else 0.25)
					local _, off = (raw[k].Rotation:Inverse() * want.Rotation):ToAxisAngle()
					off = math.deg(math.abs(off))
					if off > settings.cap then want = raw[k]:Lerp(want, settings.cap / off) end
					nextOut[k] = want
					changed = true
				end
			end
		end
		out = nextOut
	end
	return if changed then out else nil
end

-- (D-881, user: NEON 2:33 "벌벌 떠는 움직임 … 다른 부분에도 이런 달달 떨림 발견해서
-- 떨림 수정") the stretches where a joint still shakes after clean() and calm():
-- turn backs of `minSwing`..`maxSwing` degrees at most `maxGap` s apart, on any
-- axis, `count` or more within `window` s. Only there (easing in and out over
-- `edge` s) the joint is eased toward its neighbours `passes` times, like a
-- `steady` fix, at most `cap` degrees; bigger and slower moves are left alone.
local function shaky(poses: {CFrame}, times: {number}, settings: {[string]: number}): {CFrame}?
	local n = #poses
	if n < 5 then return nil end
	local backs = {}
	for axis = 1, 3 do
		local v = {}
		for k, c in ipairs(poses) do v[k] = math.deg((table.pack(c:ToEulerAnglesXYZ()))[axis]) end
		local last: number? = nil
		for k = 2, n - 1 do
			if (v[k] - v[k - 1]) * (v[k + 1] - v[k]) < 0 then
				if last then
					local swing, gap = math.abs(v[k] - v[last]), times[k] - times[last]
					if swing >= settings.minSwing and swing <= settings.maxSwing and gap <= settings.maxGap then
						table.insert(backs, times[k])
					end
				end
				last = k
			end
		end
	end
	if #backs < settings.count then return nil end
	table.sort(backs)
	-- the stretches where the turn backs crowd together
	local spans = {}
	for i = 1, #backs - settings.count + 1 do
		local j = i + settings.count - 1
		if backs[j] - backs[i] <= settings.window then table.insert(spans, { backs[i], backs[j] }) end
	end
	if #spans == 0 then return nil end
	local w = {}
	for k = 1, n do
		local t, best = times[k], 0
		for _, s in ipairs(spans) do
			best = math.max(best, math.clamp(math.min(t - s[1], s[2] - t) / settings.edge + 1, 0, 1))
		end
		w[k] = best
	end
	local out = table.clone(poses)
	for _ = 1, settings.passes do
		local nextOut = table.clone(out)
		for k = 2, n - 1 do
			if w[k] > 0 then
				local mid = out[k - 1]:Lerp(out[k + 1], 0.5)
				nextOut[k] = out[k]:Lerp(out[k]:Lerp(mid, 0.5), w[k])
			end
		end
		out = nextOut
	end
	-- never more than `cap` degrees off the pose it was given (a real flick of
	-- the hand inside a shaky stretch stays)
	for k = 1, n do
		local _, off = (poses[k].Rotation:Inverse() * out[k].Rotation):ToAxisAngle()
		off = math.deg(math.abs(off))
		if off > settings.cap then out[k] = poses[k]:Lerp(out[k], settings.cap / off) end
	end
	return out
end

-- (D-984) each pose averaged with the poses within 3 sigma seconds either side,
-- weighted exp(-d²/2σ²); `turnOnly` keeps each pose's own position (the hips' travel)
local function dejitter(poses: {CFrame}, times: {number}, sigma: number, turnOnly: boolean): {CFrame}
	local out = {}
	local reach = 3 * sigma
	for k = 1, #poses do
		local mean, total = poses[k], 1
		local function add(i: number)
			local d = times[i] - times[k]
			local w = math.exp(-(d * d) / (2 * sigma * sigma))
			total += w
			mean = mean:Lerp(poses[i], w / total)
		end
		local i = k - 1
		while i >= 1 and times[k] - times[i] <= reach do add(i) i -= 1 end
		i = k + 1
		while i <= #poses and times[i] - times[k] <= reach do add(i) i += 1 end
		out[k] = if turnOnly then CFrame.new(poses[k].Position) * mean.Rotation else mean
	end
	return out
end

function ChoreoSmooth.load(animationId: string)
	if cache[animationId] then return end
	cache[animationId] = {}
	local settings = ClubConfig.ChoreoSmoothing
	task.spawn(function()
		local ok, sequence = pcall(function()
			return KeyframeSequenceProvider:GetKeyframeSequenceAsync(animationId)
		end)
		if not ok or not sequence then return end
		local keyframes = (sequence :: KeyframeSequence):GetKeyframes()
		table.sort(keyframes, function(a, b) return (a :: Keyframe).Time < (b :: Keyframe).Time end)
		-- each part's poses in time order
		local series: {[string]: { times: {number}, raw: {CFrame} }} = {}
		for _, kf in ipairs(keyframes) do
			for _, pose in ipairs(kf:GetDescendants()) do
				if pose:IsA("Pose") and pose.Weight > 0 then
					local s = series[pose.Name]
					if not s then
						s = { times = {}, raw = {} }
						series[pose.Name] = s
					end
					table.insert(s.times, (kf :: Keyframe).Time)
					table.insert(s.raw, pose.CFrame)
				end
			end
		end
		-- (D-985) a mirrored song: each part's poses become the other side's, mirrored
		if ChoreoSmooth.isMirrored(animationId) then
			local swapped = {}
			for part, s in pairs(series) do
				local m = {}
				for k, c in ipairs(s.raw) do m[k] = ChoreoSmooth.mirrorPose(c) end
				swapped[ChoreoSmooth.otherSide(part)] = { times = s.times, raw = m }
			end
			series = swapped
		end
		local hips = series.LowerTorso
		if hips then
			local at, facing = {}, {}
			for k, c in ipairs(hips.raw) do
				at[k] = Vector3.new(c.X, 0, c.Z)
				-- (D-840) the facing, unwrapped so a turn past 180° keeps counting
				local _, yaw = c:ToEulerAnglesYXZ()
				if k > 1 then yaw = facing[k - 1] + ((yaw - facing[k - 1] + math.pi) % (2 * math.pi) - math.pi) end
				facing[k] = yaw
			end
			paths[animationId] = { times = hips.times, at = at, facing = facing }
		end
		local fixes = ClubConfig.ChoreoFixes and ClubConfig.ChoreoFixes[tonumber(animationId:match("%d+")) or 0]
		local steady = fixes and fixes.steady
		local result = {}
		local final: {[string]: {CFrame}} = {} -- (each part's poses after the clean-up, D-843)
		for part, s in pairs(series) do
			final[part] = s.raw
			local cleaned = if settings then clean(s.raw, settings.maxStep, settings.passes) else nil
			-- (D-851) pieces the user saw tremble: the slower wobble too
			if fixes and fixes.calm and ClubConfig.ChoreoCalm and part ~= "LowerTorso" then
				cleaned = calm(cleaned or s.raw, s.raw, ClubConfig.ChoreoCalm) or cleaned
			end
			-- (D-881) whatever still shakes, found by itself in every piece
			if ClubConfig.ChoreoShake and part ~= "LowerTorso" then
				cleaned = shaky(cleaned or s.raw, s.times, ClubConfig.ChoreoShake) or cleaned
			end
			-- (D-840) a spot the user picked (a shaky arm): these parts smoothed
			-- hard between `from` and `to`, easing in and out at both ends
			-- (D-852) no `parts`: the whole body
			-- (D-884) or a list of such stretches
			for _, st in ipairs(if steady and steady.from then { steady } else steady or {}) do
				if not st.parts or table.find(st.parts, part) then
					local out = cleaned or table.clone(s.raw)
					local edge = 0.15
					for _ = 1, st.passes or 4 do
						local nextOut = table.clone(out)
						for k = 2, #out - 1 do
							local t = s.times[k]
							local w = math.clamp(math.min(t - st.from, st.to - t) / edge + 1, 0, 1)
							if w > 0 then
								local mid = out[k - 1]:Lerp(out[k + 1], 0.5)
								nextOut[k] = out[k]:Lerp(out[k]:Lerp(mid, 0.5), w)
							end
						end
						out = nextOut
					end
					cleaned = out
				end
			end
			-- (D-984, user: Catch Catch 2:35 "벌벌 떨어. 떠는 이유가 뭐야. 프레임 끊기는 거임?
			-- 이런 부분 모두 찾아서 수정해") the tremble left was the hips: the clean-ups
			-- above all skip LowerTorso, and a few degrees of hip wobble swing the
			-- feet 0.1-0.3 studs out and back in 3-4 frames. Every part, the hips'
			-- turn too (not their travel), is averaged with its neighbours in time
			-- (Gaussian, ClubConfig.ChoreoDejitter.sigma s, centred so nothing lags);
			-- the beat-sized moves keep their size, the 6-10 per-second wobble goes
			local dj = ClubConfig.ChoreoDejitter
			if dj and dj.sigma > 0 and not (fixes and fixes.sharp) then
				cleaned = dejitter(cleaned or s.raw, s.times, dj.sigma, part == "LowerTorso")
			end
			if cleaned then
				final[part] = cleaned
				local fix = {}
				for k, c in ipairs(cleaned) do fix[k] = s.raw[k]:Inverse() * c end
				result[part] = { times = s.times, fix = fix }
			end
		end
		cache[animationId] = result
		-- (D-843) the joints R15 lacks, folded onto the ones it has (one pose
		-- per keyframe for every joint, so the lists line up)
		local timesOf = series.UpperTorso and series.UpperTorso.times
		if ClubConfig.ChoreoRetarget and timesOf then
			local n = #timesOf
			local function same(part: string): {CFrame}?
				local list = final[part]
				return if list and #list == n then list else nil
			end
			local spine, chest = same("Spine"), same("Chest")
			local waist: {CFrame}? = nil
			if spine or chest then
				waist = {}
				for k = 1, n do
					(waist :: {CFrame})[k] = (if spine then spine[k].Rotation else CFrame.identity) * (if chest then chest[k].Rotation else CFrame.identity)
				end
			end
			local function rotations(list: {CFrame}?): {CFrame}?
				if not list then return nil end
				local out = {}
				for k, c in ipairs(list) do out[k] = c.Rotation end
				return out
			end
			retargets[animationId] = { times = timesOf, waist = waist, left = rotations(same("LeftClavicle")), right = rotations(same("RightClavicle")) }
		end
	end)
end

-- forget what was read (after ClubConfig.ChoreoSmoothing changes, e.g. when tuning in Studio)
function ChoreoSmooth.clear()
	table.clear(cache)
	table.clear(paths)
	table.clear(retargets)
	table.clear(popCache)
end

-- the keyframes either side of t and how far between them
local function around(times: {number}, t: number): (number, number, number)
	local n = #times
	if t <= times[1] then return 1, 1, 0 end
	if t >= times[n] then return n, n, 0 end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then lo = mid else hi = mid end
	end
	return lo, hi, (t - times[lo]) / math.max(times[hi] - times[lo], 1e-6)
end

-- (D-843) at time t: the spine + chest turn to add after the waist joint,
-- and each clavicle's turn to add before that shoulder joint (nil where the
-- animation has none or has not been read yet)
function ChoreoSmooth.retarget(animationId: string, t: number): (CFrame?, CFrame?, CFrame?)
	local r = retargets[animationId]
	if not r then return nil, nil, nil end
	local lo, hi, f = around(r.times, t)
	local function at(list: {CFrame}?): CFrame?
		return if list then list[lo]:Lerp(list[hi], f) else nil
	end
	return at(r.waist), at(r.left), at(r.right)
end

-- (D-852) the spot fixes ClubConfig.ChoreoFixes gives this animation, or nil
function ChoreoSmooth.fixes(animationId: string): any
	return ClubConfig.ChoreoFixes and ClubConfig.ChoreoFixes[tonumber(animationId:match("%d+")) or 0]
end

-- (D-848) the chest pops a piece is given (ClubConfig.ChoreoFixes pops) at
-- time t: the waist turn to add after UpperTorso's own and the neck turn
-- that keeps the head level, or nil away from a pop
local popCache: {[string]: any} = {}
function ChoreoSmooth.pop(animationId: string, t: number): (CFrame?, CFrame?)
	local pops = popCache[animationId]
	if pops == nil then
		local fixes = ClubConfig.ChoreoFixes and ClubConfig.ChoreoFixes[tonumber(animationId:match("%d+")) or 0]
		pops = fixes and fixes.pops or false
		popCache[animationId] = pops
	end
	if not pops then return nil, nil end
	local k = 0
	local back = pops.back or 0.3
	local out = pops.out or 0.07
	for i, at in ipairs(pops.at) do
		local d = t - at
		-- (D-856) with `sink`, each pop settles by the time the next one starts
		local nextAt = pops.at[i + 1]
		local down = if pops.sink and nextAt then math.min(back, nextAt - out - at) else back
		if d > -out and d < down then
			-- out fast, back slower, both eased; (D-854) `sink`: back down at
			-- an even pace from the top, as the dancer in the user's clip does
			local f = if d < 0 then 1 + d / out else 1 - d / down
			f = if d >= 0 and pops.sink then f else f * f * (3 - 2 * f)
			-- (D-856, user: "큰 가슴 튕김 -> 작은 가슴 튕김 …") each pop's size
			k = math.max(k, f * (if pops.sizes then pops.sizes[i] or 1 else 1))
		end
	end
	if k <= 0 then return nil, nil end
	local arch = math.rad(pops.arch) * k
	-- (D-853, user: "가슴 앞으로 위로 튀어나오게") `lift` raises the chest too
	return CFrame.new(0, (pops.lift or 0) * k, -pops.push * k) * CFrame.Angles(arch, 0, 0), CFrame.Angles(-arch, 0, 0)
end

-- (D-855) a pose the capture lost, from ClubConfig.ChoreoFixes `pose`: at
-- time t, the joint turns to set (by part name), the turns to add on top,
-- and how much of them shows (easing in after `from`, out before `to`), or
-- nil outside it
local function angles(a: {number}): CFrame
	return CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3]))
end
function ChoreoSmooth.pose(animationId: string, t: number): ({[string]: CFrame}?, {[string]: CFrame}?, number, {[string]: number}?)
	local fixes = ChoreoSmooth.fixes(animationId)
	-- (D-860) `pose` may be a list of poses for different stretches
	local list = fixes and fixes.pose
	if not list then return nil, nil, 0 end
	if list.from then list = { list } end
	local pose
	for _, p in ipairs(list) do
		if t > p.from and t < p.to then pose = p break end
	end
	if not pose then return nil, nil, 0 end
	local ease = pose.ease or 0.3
	local f = math.clamp(math.min(t - pose.from, pose.to - t) / ease, 0, 1)
	local keys = pose.keys
	-- the two keys either side of t (held before the first, after the last)
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then a, b = keys[i], keys[i + 1] break end
	end
	if t < keys[1].t then b = a elseif t > keys[#keys].t then a = b end
	local k = if b.t > a.t then (t - a.t) / (b.t - a.t) else 0
	k = k * k * (3 - 2 * k)
	local set = {}
	for part, value in pairs(a.set or {}) do
		set[part] = angles(value):Lerp(angles((b.set or {})[part] or value), k)
	end
	-- (D-988) a part first set by the next key fades in from the dance on the way
	local fade = {}
	for part, value in pairs(b.set or {}) do
		if not set[part] and b.t > a.t then set[part] = angles(value) fade[part] = k end
	end
	local add = {}
	for part, value in pairs(pose.add or {}) do add[part] = angles(value) end
	-- (D-860) keys may carry their own `add` turns, eased between keys too
	for part, value in pairs(a.add or {}) do
		local turn = angles(value):Lerp(angles((b.add or {})[part] or value), k)
		add[part] = if add[part] then add[part] * turn else turn
	end
	-- (D-862) and `move` (studs), e.g. the hips lowered into a squat
	for part, value in pairs(a.move or {}) do
		local other = (b.move or {})[part] or value
		local shift = CFrame.new(Vector3.new(value[1], value[2], value[3]):Lerp(Vector3.new(other[1], other[2], other[3]), k))
		add[part] = if add[part] then add[part] * shift else shift
	end
	return set, add, f * f * (3 - 2 * f), fade
end

function ChoreoSmooth.correction(animationId: string, part: string, t: number): CFrame?
	local parts = cache[animationId]
	local track = parts and parts[part]
	if not track then return nil end
	local lo, hi, f = around(track.times, t)
	return track.fix[lo]:Lerp(track.fix[hi], f)
end

-- (D-840) which way the hips face at time t (radians, unwrapped), or nil
-- until the animation has been read
function ChoreoSmooth.facing(animationId: string, t: number): number?
	local path = paths[animationId]
	if not path then return nil end
	local lo, hi, f = around(path.times, t)
	return path.facing[lo] + (path.facing[hi] - path.facing[lo]) * f
end

-- (D-840) the facing an animation ends with and which way it was turning
-- then (+1 / -1, from its last 0.3 s), or nil until it has been read
function ChoreoSmooth.endFacing(animationId: string): (number?, number)
	local path = paths[animationId]
	if not path then return nil, 1 end
	local last = path.times[#path.times]
	local yaw = path.facing[#path.facing]
	local before = ChoreoSmooth.facing(animationId, last - 0.3) or yaw
	return yaw, if yaw >= before then 1 else -1
end

-- (D-813) where the animation has taken the hips at time t (sideways /
-- forward, in the animation's studs), or nil until it has been read
function ChoreoSmooth.hips(animationId: string, t: number): Vector3?
	local path = paths[animationId]
	if not path then return nil end
	local lo, hi, f = around(path.times, t)
	return path.at[lo]:Lerp(path.at[hi], f)
end

return ChoreoSmooth
