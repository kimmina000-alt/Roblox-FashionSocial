-- Choreography motion scan (D-964, docs/01_SYSTEMS/CHOREOGRAPHY.md §16).
-- Run in Studio (Edit) after adding or changing a choreography, with TITLE
-- set to the song (or nil for every song with a choreography). It reads the
-- captures' keyframes on a plain R15 body and lists, in SONG seconds (the
-- play bar), the spots that the user picked out by eye on 2026-11-07 (NEON /
-- Get A Guitar / Love 119, D-962), each with the fix that worked there:
--   LURCH  a turn that jumps 45°+ in one keyframe, or stalls        → spin
--   BACK   a capture that turns half way and back where the dancer
--          turns all the way round                                  → spin + turns
--   SEAM   the next piece faces 60°+ away and the blend would turn
--          back the short way against the turn before               → spin fromPrev
--   DRIFT  hips and both feet travel together 0.6 stud+ in 0.6 s
--          (a slide with small steps: choreo_slide_check misses it)  → still
--   KNEES  a held pose that stands on bent knees (hips 0.25+ low)    → pose set (legs) + move
--   FAST   a foot / knee coming up 0.8 stud+ in 0.2 s or less        → warp (slower, the
--          stretch before a little faster so the timing stays)
--   TAP    a foot coming down twice within 0.5 s                     → warp to one tap
--   HOLD   a `hold` letting go into a pose 30°+ round                → warp + hold ease
-- Stretches already covered by a fix (spin / still / warp / hold) are left
-- out. Then check every spot in Play with tools/choreo/play_record.lua.

local TITLES: {[string]: boolean}? = nil -- e.g. { ["A2O LITE-NEON"] = true }; nil = every song
local IGNORE_FIXES = false -- true: list everything, as if no ChoreoFixes were set

-- (D-964) the whole Shared folder is cloned: since D-888 ClubConfig requires
-- its siblings, and a clone of it alone waits for them forever; a fresh clone
-- also reads the current values (the command bar caches modules)
local ClubConfig = require(game:GetService("ReplicatedStorage").FashionGame.Shared:Clone().ClubConfig)
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

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

local function partAt(poses: {[string]: CFrame}, part: string): CFrame
	local chain, name = {}, part
	while name ~= "HumanoidRootPart" do
		table.insert(chain, 1, name)
		name = joints[name].parent
	end
	local cf = CFrame.new()
	for _, p in ipairs(chain) do
		local j = joints[p]
		cf = cf * j.c0 * (poses[p] or CFrame.new()) * j.c1:Inverse()
	end
	return cf
end
local restHip = partAt({}, "LowerTorso").Y

-- one frame per keyframe: time, unwrapped facing (degrees), hips, feet
local function frames(id: number)
	local ok, seq = pcall(function() return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)
	if not ok then return nil end
	local kfs = seq:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local out, prev, acc = {}, nil, 0
	for _, kf in ipairs(kfs) do
		local poses = {}
		for _, d in ipairs(kf:GetDescendants()) do
			if d:IsA("Pose") then poses[d.Name] = d.CFrame end
		end
		if poses.LowerTorso then
			local hips = partAt(poses, "LowerTorso")
			local look = hips.LookVector
			local yaw = math.deg(math.atan2(-look.X, -look.Z))
			acc = if prev then acc + ((yaw - prev + 180) % 360 - 180) else yaw
			prev = yaw
			table.insert(out, { t = kf.Time, yaw = acc, hip = hips.Position, L = partAt(poses, "LeftFoot").Position, R = partAt(poses, "RightFoot").Position })
		end
	end
	-- (never Destroy the sequence: KeyframeSequenceProvider hands back the same
	-- cached one, and once destroyed it reads empty until Studio is restarted)
	return out
end

local function list(v) if v == nil then return {} elseif v.from then return { v } else return v end end
local function covered(fixes, t: number, kinds: {string}): boolean
	if not fixes then return false end
	for _, k in ipairs(kinds) do
		for _, s in ipairs(list(fixes[k])) do
			if t >= s.from - 0.15 and t <= s.to + 0.15 then return true end
		end
	end
	return false
end
local function flat(v: Vector3): Vector2 return Vector2.new(v.X, v.Z) end

local function scan(titles: {[string]: boolean}?, ignoreFixes: boolean): string
local IGNORE_FIXES = ignoreFixes
local out = {}
for _, track in ipairs(ClubConfig.Playlist) do
	if not track.choreo or (titles and not titles[track.title]) then continue end
	table.insert(out, "== " .. track.title)
	local at, prevEnd = 0, nil
	for i, entry in ipairs(track.choreo) do
		local id = if typeof(entry) == "table" then entry.id else entry
		local from = if typeof(entry) == "table" and entry.from then entry.from else 0
		local f = frames(id)
		if not f or #f < 2 then continue end
		local start = if typeof(entry) == "table" and entry.at then entry.at else at
		local function song(t: number): string return string.format("%d:%05.2f", math.floor((start + t - from) / 60), (start + t - from) % 60) end
		local fixes = if IGNORE_FIXES then nil else ClubConfig.ChoreoFixes[id]
		local function say(kind: string, t: number, text: string)
			table.insert(out, string.format("%s  #%d %d  t %.2f  %s  %s", song(t), i, id, t, kind, text))
		end
		-- SEAM: where this piece starts against where the last one ended
		if prevEnd then
			local here = f[1].yaw
			local gap = (here - prevEnd.yaw + 180) % 360 - 180
			if math.abs(gap) > 60 and prevEnd.dir ~= 0 and gap * prevEnd.dir < 0 and not covered(fixes, 0, { "spin" }) and not (fixes and fixes.turn) then
				say("SEAM", 0, string.format("starts %d° away, the blend turns back against the turn before (%+d°/s): spin = { from = 0, to = <blend + 0.2>, fromPrev = true, dir = %d }", math.floor(gap), prevEnd.dir * math.floor(prevEnd.speed), prevEnd.dir))
			end
		end
		for k = 2, #f do
			local a, b = f[k - 1], f[k]
			if b.t < from then continue end
			-- LURCH / BACK
			local step = b.yaw - a.yaw
			if math.abs(step) > 45 and b.t - a.t <= 0.15 and not covered(fixes, b.t, { "spin", "hold" }) then
				-- the turn around it: 1 s either side
				local lo, hi = k, k
				while lo > 1 and f[lo - 1].t > b.t - 1 do lo -= 1 end
				while hi < #f and f[hi + 1].t < b.t + 1 do hi += 1 end
				local net = f[hi].yaw - f[lo].yaw
				local most = 0
				for m = lo, hi do most = math.max(most, math.abs(f[m].yaw - f[lo].yaw)) end
				local kind = if most > 120 and math.abs(net) < most - 90 then "BACK" else "LURCH"
				say(kind, b.t, string.format("%+d° in one keyframe; %.1f-%.1f s turns %+d° (most %d°): spin = { from = %.2f, to = %.2f%s, ease = \"both\" }",
					math.floor(step), f[lo].t, f[hi].t, math.floor(net), math.floor(most), f[lo].t, f[hi].t, if kind == "BACK" then ", turns = " .. (if step > 0 then "1" else "-1") else ""))
			end
		end
		-- DRIFT: hips and both feet travel together
		local skipUntil = -1
		for k = 1, #f do
			if f[k].t < skipUntil then continue end
			local e = k
			while e < #f and f[e + 1].t <= f[k].t + 0.6 do e += 1 end
			if f[e].t - f[k].t < 0.5 or f[k].t < from then continue end
			local hipMove = (flat(f[e].hip) - flat(f[k].hip)).Magnitude
			local stance = (flat(f[e].L - f[e].R) - flat(f[k].L - f[k].R)).Magnitude
			local lift = 0
			for m = k, e do lift = math.max(lift, f[m].L.Y - math.min(f[k].L.Y, f[e].L.Y), f[m].R.Y - math.min(f[k].R.Y, f[e].R.Y)) end
			-- (both feet go along with the hips: a slide, not a step)
			local feetMove = math.min((flat(f[e].L) - flat(f[k].L)).Magnitude, (flat(f[e].R) - flat(f[k].R)).Magnitude)
			if hipMove > 0.6 and stance < 0.35 and lift < 0.3 and feetMove > 0.7 * hipMove and not covered(fixes, f[k].t + 0.3, { "still" }) then
				say("DRIFT", f[k].t, string.format("hips and feet slide %.1f stud in %.1f s (stance changes %.2f, feet lift %.2f): still = { from = %.1f, to = %.1f }",
					hipMove, f[e].t - f[k].t, stance, lift, f[k].t - 0.1, f[e].t + 0.1))
				skipUntil = f[e].t -- (past this stretch)
			end
		end
		-- KNEES: a still first second on bent knees
		if i == 1 or (fixes and fixes.hold) then
			local t0 = if fixes and fixes.hold then list(fixes.hold)[1].from else from
			local low, moving = 0, 0
			for _, fr in ipairs(f) do
				if fr.t >= t0 and fr.t <= t0 + 1 then
					low = math.max(low, restHip - fr.hip.Y)
					moving = math.max(moving, (flat(fr.hip) - flat(f[1].hip)).Magnitude)
				end
			end
			if low > 0.25 and moving < 0.3 and not (fixes and fixes.pose) then
				say("KNEES", t0, string.format("stands still on bent knees (hips %.2f low): pose set legs straight + move LowerTorso up as much", low))
			end
		end
		-- FAST / TAP: feet
		for _, side in ipairs({ "L", "R" }) do
			local downs, liftUntil = {}, -1
			for k = 2, #f do
				local a, b = f[k - 1], f[k]
				-- a snap: the foot 1 stud higher within 0.2 s and most of the way
				-- down again within 0.35 s more (a knee popped up and dropped)
				local m = k
				while m < #f and f[m + 1].t <= a.t + 0.2 do m += 1 end
				local up = f[m][side].Y - a[side].Y
				local down = 0
				for q = m, #f do
					if f[q].t > f[m].t + 0.35 then break end
					down = math.max(down, f[m][side].Y - f[q][side].Y)
				end
				if a.t >= liftUntil and a.t >= from and up > 1 and down > 0.7 * up and not covered(fixes, a.t, { "warp", "spin" }) then
					say("FAST", a.t, string.format("%s foot up %.1f stud in %.2f s: warp it slower (e.g. 0.7x) and the stretch before a little faster", side, f[m][side].Y - a[side].Y, f[m].t - a.t))
					liftUntil = f[m].t + 0.3
				end
				-- a landing: down 0.4 stud+ onto the lowest height
				if a[side].Y - b[side].Y > 0.4 and b[side].Y < math.min(f[1].L.Y, f[1].R.Y) + 0.25 then table.insert(downs, b.t) end
			end
			for d = 2, #downs do
				if downs[d] - downs[d - 1] < 0.5 and not covered(fixes, downs[d], { "warp" }) then
					say("TAP", downs[d - 1], string.format("%s foot comes down twice (%.2f, %.2f s): warp the stretch to play once, slower", side, downs[d - 1], downs[d]))
				end
			end
		end
		-- HOLD: letting go into a pose far round
		for _, h in ipairs(list(fixes and fixes.hold)) do
			local function yawAt(t) local best = f[1] for _, fr in ipairs(f) do if fr.t <= t then best = fr end end return best.yaw end
			local d = yawAt(h.to) - yawAt(h.from)
			if math.abs(d) > 30 and not (fixes.warp) then
				say("HOLD", h.to, string.format("the hold lets go into a pose %+d° round: hold ease + warp the move after it slower", math.floor(d)))
			end
		end
		local last = f[#f]
		local before = f[1]
		for _, fr in ipairs(f) do if fr.t <= last.t - 0.6 then before = fr end end
		local speed = (last.yaw - before.yaw) / math.max(last.t - before.t, 0.05)
		-- (Love 119 5 → 6, D-962: 5 slows to a stop as it ends, -37°/s in its
		-- last 0.3 s, and the blend still turned back)
		prevEnd = { yaw = last.yaw, dir = if math.abs(speed) > 25 then (if speed > 0 then 1 else -1) else 0, speed = speed }
		at = start + f[#f].t - from
		task.wait()
	end
end
return table.concat(out, "\n")
end

local text = scan(TITLES, IGNORE_FIXES)
print(text)
return text
