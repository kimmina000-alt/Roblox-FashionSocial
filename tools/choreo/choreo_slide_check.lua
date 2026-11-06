-- Choreography slide check (D-880, docs/01_SYSTEMS/CHOREOGRAPHY.md §9.3).
-- Run in Studio (Edit) after adding or changing a choreography. For every
-- piece it works out the feet from the leg keyframes on a plain R15 body
-- (HumanoidRootPart fixed, as ChoreoController plays it) and lists the
-- stretches where the body slides while the legs stand: the stance (left to
-- right foot) stays within STANCE studs, neither foot lifts more than LIFT,
-- and yet the feet go NET studs or more in 0.5 s, or wander PATH back and
-- forth. Stretches already inside a `still` are left out. Copy the printed
-- table into ClubConfig.ChoreoSlideStill (it becomes `still` stretches).

local STANCE, LIFT, NET, PATH = 0.25, 0.2, 0.4, 0.5

-- (D-964) the whole Shared folder is cloned: since D-888 ClubConfig requires
-- its siblings, and a clone of it alone waits for them forever; a fresh clone
-- also reads the current values (the command bar caches modules)
local ClubConfig = require(game:GetService("ReplicatedStorage").FashionGame.Shared:Clone().ClubConfig)
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- the joints of a plain R15 body: part = { parent part, joint offsets }
local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
local joints = {}
for _, c in ipairs(rig:GetDescendants()) do
	if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
		joints[c.Attachment1.Parent.Name] = { parent = c.Attachment0.Parent.Name, c0 = c.Attachment0.CFrame, c1 = c.Attachment1.CFrame }
	elseif c:IsA("Motor6D") and c.Part0 and c.Part1 then
		joints[c.Part1.Name] = { parent = c.Part0.Name, c0 = c.C0, c1 = c.C1 }
	end
end
rig:Destroy()

local function footAt(poses: {[string]: CFrame}, part: string): Vector3
	local chain = {}
	local name = part
	while name ~= "HumanoidRootPart" do
		table.insert(chain, 1, name)
		name = joints[name].parent
	end
	local cf = CFrame.new()
	for _, p in ipairs(chain) do
		local j = joints[p]
		cf = cf * j.c0 * (poses[p] or CFrame.new()) * j.c1:Inverse()
	end
	return cf.Position
end

local function flat(v: Vector3): Vector2 return Vector2.new(v.X, v.Z) end

local out = {}
for _, track in ipairs(ClubConfig.Playlist) do
	if not track.choreo then continue end
	table.insert(out, "\t-- " .. track.title)
	for _, entry in ipairs(track.choreo) do
		local id = if typeof(entry) == "table" then entry.id else entry
		local from = if typeof(entry) == "table" and entry.from then entry.from else 0
		local ok, seq = pcall(function() return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)
		if not ok then continue end
		local keyframes = seq:GetKeyframes()
		table.sort(keyframes, function(a, b) return a.Time < b.Time end)
		local feet = {}
		for _, kf in ipairs(keyframes) do
			local poses = {}
			for _, d in ipairs(kf:GetDescendants()) do
				if d:IsA("Pose") then poses[d.Name] = d.CFrame end
			end
			if poses.LowerTorso then
				table.insert(feet, { t = kf.Time, L = footAt(poses, "LeftFoot"), R = footAt(poses, "RightFoot") })
			end
		end
		local fixes = ClubConfig.ChoreoFixes[id]
		local still = fixes and fixes.still
		local stills = if still == nil then {} elseif still.from then { still } else still
		local function covered(t0: number, t1: number): boolean
			for _, s in ipairs(stills) do
				if t0 >= s.from - 0.05 and t1 <= s.to + 0.05 then return true end
			end
			return false
		end
		local flags = {}
		for s = 1, #feet do
			local t0 = feet[s].t
			if t0 < from then continue end
			local e = s
			while e < #feet and feet[e + 1].t <= t0 + 0.5 do e += 1 end
			if feet[e].t - t0 < 0.45 then break end
			local stance0 = flat(feet[s].L - feet[s].R)
			local stance, lo, hi, path = 0, { L = math.huge, R = math.huge }, { L = -math.huge, R = -math.huge }, 0
			for k = s, e do
				stance = math.max(stance, (flat(feet[k].L - feet[k].R) - stance0).Magnitude)
				for _, side in ipairs({ "L", "R" }) do
					lo[side] = math.min(lo[side], feet[k][side].Y)
					hi[side] = math.max(hi[side], feet[k][side].Y)
				end
				if k > s then path += flat((feet[k].L + feet[k].R) / 2 - (feet[k - 1].L + feet[k - 1].R) / 2).Magnitude end
			end
			local net = flat((feet[e].L + feet[e].R) / 2 - (feet[s].L + feet[s].R) / 2).Magnitude
			if stance < STANCE and hi.L - lo.L < LIFT and hi.R - lo.R < LIFT and (path > PATH or net > NET) and not covered(t0, t0 + 0.5) then
				table.insert(flags, t0)
			end
		end
		local stretches = {}
		local k = 1
		while k <= #flags do
			local a, b = flags[k], flags[k] + 0.5
			while k < #flags and flags[k + 1] <= b do
				k += 1
				b = flags[k] + 0.5
			end
			table.insert(stretches, string.format("{ %.1f, %.1f }", math.floor(a * 10) / 10, math.ceil(b * 10) / 10))
			k += 1
		end
		if #stretches > 0 then
			table.insert(out, string.format("\t[%d] = { %s },", id, table.concat(stretches, ", ")))
		end
		task.wait()
	end
end
local text = table.concat(out, "\n")
print(text)
return text
