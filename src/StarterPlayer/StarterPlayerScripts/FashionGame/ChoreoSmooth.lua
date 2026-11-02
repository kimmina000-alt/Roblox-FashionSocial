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

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

-- per animation id: per part name, the keyframe times and the correction
-- (raw:Inverse() * clean) at each keyframe; parts with no zigzag are left out
type Track = { times: {number}, fix: {CFrame} }
local cache: {[string]: {[string]: Track}} = {}
-- (D-813) per animation id: the hips' (LowerTorso) sideways / forward place
-- at each keyframe, as made (ChoreoController moves the dancer along it)
type Path = { times: {number}, at: {Vector3} }
local paths: {[string]: Path} = {}

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
			local at = {}
			for k, c in ipairs(hips.raw) do at[k] = Vector3.new(c.X, 0, c.Z) end
			paths[animationId] = { times = hips.times, at = at }
		end
		if not settings then return end
		local result = {}
		for part, s in pairs(series) do
			local cleaned = clean(s.raw, settings.maxStep, settings.passes)
			if cleaned then
				local fix = {}
				for k, c in ipairs(cleaned) do fix[k] = s.raw[k]:Inverse() * c end
				result[part] = { times = s.times, fix = fix }
			end
		end
		cache[animationId] = result
	end)
end

-- forget what was read (after ClubConfig.ChoreoSmoothing changes, e.g. when tuning in Studio)
function ChoreoSmooth.clear()
	table.clear(cache)
	table.clear(paths)
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

function ChoreoSmooth.correction(animationId: string, part: string, t: number): CFrame?
	local parts = cache[animationId]
	local track = parts and parts[part]
	if not track then return nil end
	local lo, hi, f = around(track.times, t)
	return track.fix[lo]:Lerp(track.fix[hi], f)
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
