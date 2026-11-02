-- Choreography boundary check (D-806, docs/01_SYSTEMS/CHOREOGRAPHY.md).
-- Run in Studio (Edit, or the Server datamodel of a Play test) before a new
-- choreography goes into ClubConfig. For each animation it reads the
-- keyframes and prints its length and timeline, and the hips (LowerTorso)
-- at the first and last keyframe: travel (sideways / forward, taken out by
-- ChoreoController), height and facing. For each pair it prints how well the
-- end of one fits the start of the next: facing gap, height gap and the
-- largest joint angle gap. Lines marked "!!" need a fix before use; they
-- suggest a `blend` (seconds) for the next entry (D-807).
-- Set IDS to the new list, or SOUND_ID to check a track already in ClubConfig.

local IDS: {any}? = nil -- e.g. { 119819611123433, 97097804325917, ... }
local SOUND_ID = 91762270038050

local YAW_LIMIT = 20 -- degrees
local HEIGHT_LIMIT = 0.3 -- studs
local JOINT_LIMIT = 35 -- degrees

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local list = IDS
if not list then
	local ClubConfig = require(game:GetService("ReplicatedStorage").FashionGame.Shared.ClubConfig)
	for _, t in ipairs(ClubConfig.Playlist) do
		if t.soundId == SOUND_ID then list = t.choreo end
	end
end
assert(list, "no choreography found")

local function poses(kf: Keyframe): {[string]: CFrame}
	local out = {}
	for _, d in ipairs(kf:GetDescendants()) do
		if d:IsA("Pose") and d.Weight > 0 then out[d.Name] = d.CFrame end
	end
	return out
end

local function yawOf(c: CFrame): number
	local _, y = c:ToEulerAnglesYXZ()
	return math.deg(y)
end

local function angleBetween(a: CFrame, b: CFrame): number
	local _, angle = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return math.deg(math.abs(angle))
end

local segs = {}
for i, entry in ipairs(list) do
	local id = if typeof(entry) == "table" then entry.id else entry
	local ok, sequence = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://" .. tostring(id))
	end)
	if not ok then
		segs[i] = { id = id, error = tostring(sequence) }
		continue
	end
	local kfs = sequence:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	-- (D-810) `from` starts the animation later: its first pose is the
	-- keyframe nearest that time
	local from = if typeof(entry) == "table" and entry.from then entry.from else 0
	local first, last = kfs[1], kfs[#kfs]
	for _, kf in ipairs(kfs) do
		if math.abs(kf.Time - from) < math.abs(first.Time - from) then first = kf end
	end
	segs[i] = {
		id = id,
		at = if typeof(entry) == "table" then entry.at else nil,
		stop = if typeof(entry) == "table" then entry.stop else nil,
		length = last.Time - from,
		startPoses = poses(first),
		endPoses = poses(last),
	}
end

local lines = {}
local clock = 0
for i, s in ipairs(segs) do
	if s.error then
		table.insert(lines, string.format("!! %d %s cannot load: %s", i, tostring(s.id), s.error))
		continue
	end
	clock = s.at or clock
	local a, b = s.startPoses.LowerTorso, s.endPoses.LowerTorso
	local hips = if a and b
		then string.format("hips start (%.1f, %.1f) h %.2f yaw %.0f | end (%.1f, %.1f) h %.2f yaw %.0f", a.X, a.Z, a.Y, yawOf(a), b.X, b.Z, b.Y, yawOf(b))
		else "no LowerTorso pose (not R15?)"
	local cut = if s.stop then string.format(", stop %.2f", s.stop) else ""
	table.insert(lines, string.format("%2d %s  %6.2f-%6.2f (%.2f s%s)  %s", i, tostring(s.id), clock, clock + s.length, s.length, cut, hips))
	clock += s.length
	local nxt = segs[i + 1]
	if nxt and not nxt.error and b and nxt.startPoses.LowerTorso then
		local c = nxt.startPoses.LowerTorso
		local yawGap = math.abs(((yawOf(c) - yawOf(b)) + 180) % 360 - 180)
		local heightGap = math.abs(c.Y - b.Y)
		local worst, worstName = 0, "-"
		for name, cf in pairs(s.endPoses) do
			local other = nxt.startPoses[name]
			if other and name ~= "LowerTorso" then
				local gap = angleBetween(cf, other)
				if gap > worst then worst, worstName = gap, name end
			end
		end
		local bad = yawGap > YAW_LIMIT or heightGap > HEIGHT_LIMIT or worst > JOINT_LIMIT
		-- (D-807) the blend that eases the gap: about 120°/s for facing, 90°/s
		-- for a joint, 1 stud/s for height; 0.25 s is the default
		local blend = math.clamp(math.max(0.25, yawGap / 120, worst / 90, heightGap), 0.25, 1)
		table.insert(lines, string.format("%s   %d->%d facing gap %.0f, height gap %.2f, joint gap %.0f (%s)%s",
			if bad then "!!" else "  ", i, i + 1, yawGap, heightGap, worst, worstName,
			if bad then string.format("  -> blend = %.2f on %d", blend, i + 1) else ""))
	end
end
local text = table.concat(lines, "\n")
print(text)
return text
