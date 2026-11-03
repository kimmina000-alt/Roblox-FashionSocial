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
			-- (D-840) a spot the user picked (a shaky arm): these parts smoothed
			-- hard between `from` and `to`, easing in and out at both ends
			if steady and table.find(steady.parts, part) then
				local out = cleaned or table.clone(s.raw)
				local edge = 0.15
				for _ = 1, steady.passes or 4 do
					local nextOut = table.clone(out)
					for k = 2, #out - 1 do
						local t = s.times[k]
						local w = math.clamp(math.min(t - steady.from, steady.to - t) / edge + 1, 0, 1)
						if w > 0 then
							local mid = out[k - 1]:Lerp(out[k + 1], 0.5)
							nextOut[k] = out[k]:Lerp(out[k]:Lerp(mid, 0.5), w)
						end
					end
					out = nextOut
				end
				cleaned = out
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
