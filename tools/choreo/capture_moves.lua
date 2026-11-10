--[[ CHOREO_REVIEW.md 3-2 / 3-3 / 3-4 / 3-5 / 3-6 / 3-7 / 3-8 / 3-9 (D-1186): the capture against the video.
Run in Play, Server datamodel (KeyframeSequenceProvider + the player's own joints for the bones), paste this
file with execute_luau, then call (one song a call; long songs: a few clips a call):

  _G.captureMoves({
    song = "YENA-Catch Catch", mirror = true,
    clips = { ["13.mp4"] = { id = 73949956743570, at = 121, from = 0 }, ... },   -- clip -> piece (piece time = clip time + from)
    -- mirror = false when the pieces were captured from this same (mirror) video: compare a capture with its own source
    video = [[<the lines of tools/choreo/video_moves.py>]],
    beats = "beats 138.00 0.417 0.4348",                                        -- the video_moves --beats line (video seconds)
    videoOffset = -0.70,                                                         -- video = song + videoOffset
    clipStart = { ["13.mp4"] = 120.3, ... },                                    -- clip start in the video (clips.json span[1])
  })

Prints per clip the stretches (song seconds) where:
  STALL   the video moves (0.8+) but the capture hardly does (under a third of its own median)      3-2
  ARM     a wrist is 0.5+ torso lengths higher / lower than in the video, 2 samples (0.4 s) running   3-3
  BEND    an elbow / knee is 60°+ straighter or more bent than in the video, 3 samples (0.6 s) running  3-3
  LEAN    the video stands straight (|lean| < 8°) but the capture tilts 15°+ to the side               3-4
  FLOOR   the video is on the floor and the capture is not, or the other way round                    3-5
  FACE    the video's hand is at the face and the capture's is 0.6+ torso lengths away               3-7
  BEAT    the capture's accents (speed peaks) against the beat grid: median offset, how many 0.12 s+ off  3-6
And _G.uploadCheck(ids, clipLengths) (3-9): length against the clip, copies (same keyframes as another id).
And _G.repeatScan(pieces) (3-8): 1.6 s stretches of different pieces that are the same move (10° or closer). ]]

local KSP = game:GetService("KeyframeSequenceProvider")
local cache = {}
local function keyframes(id: number)
	if cache[id] then return cache[id] end
	local seq = KSP:GetKeyframeSequenceAsync("rbxassetid://" .. tostring(id))
	local kfs = seq:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local K = {}
	for _, kf in ipairs(kfs) do
		local p = {}
		for _, pose in ipairs(kf:GetDescendants()) do if pose:IsA("Pose") then p[pose.Name] = pose.CFrame end end
		table.insert(K, { t = kf.Time, p = p })
	end
	cache[id] = K -- (never Destroy a sequence: KSP then hands out empty ones, D-965)
	return K
end
local function poseAt(K, t: number)
	local i = 1
	while i < #K and K[i + 1].t <= t do i += 1 end
	local a, b = K[i], K[math.min(i + 1, #K)]
	local f = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 0
	local p = {}
	for n, x in pairs(a.p) do local y = b.p[n] p[n] = if y then x:Lerp(y, f) else x end
	return p
end

-- the bones of the player's own avatar: joint offsets by Part1 name
local rig
local function getRig()
	if rig then return rig end
	local plr = game.Players:GetPlayers()[1]
	local ch = plr and plr.Character
	assert(ch, "no character")
	rig = {}
	for _, d in ipairs(ch:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and not d:FindFirstAncestorOfClass("Accessory") then
			rig[d.Part1.Name] = { parent = d.Part0.Name, c0 = d.C0, c1 = d.C1 }
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			rig[d.Attachment1.Parent.Name] = { parent = d.Attachment0.Parent.Name, c0 = d.Attachment0.CFrame, c1 = d.Attachment1.CFrame }
		end
	end
	return rig
end
local function solve(p)
	local r = getRig()
	local cf = { HumanoidRootPart = CFrame.identity }
	local function get(n)
		if cf[n] then return cf[n] end
		local j = r[n]
		if not j then return nil end
		local parent = get(j.parent)
		if not parent then return nil end
		local v = parent * j.c0 * (p[n] or CFrame.identity) * j.c1:Inverse()
		cf[n] = v
		return v
	end
	for n in pairs(r) do get(n) end
	return cf
end

local function ang2(a: Vector3, b: Vector3, c: Vector3)
	local v1, v2 = Vector2.new(a.X - b.X, a.Y - b.Y), Vector2.new(c.X - b.X, c.Y - b.Y)
	if v1.Magnitude < 1e-4 or v2.Magnitude < 1e-4 then return nil end
	return math.deg(math.acos(math.clamp(v1.Unit:Dot(v2.Unit), -1, 1)))
end
-- the same numbers as video_moves.py, from the capture (front view: screen x = -X)
local function measure(cf, mirror: boolean)
	local function pt(n) local c = cf[n] return c and c.Position end
	local function side(s) if mirror then return if s == "Left" then "Right" else "Left" end return s end
	local hipL, hipR = pt(side("Left") .. "UpperLeg"), pt(side("Right") .. "UpperLeg")
	local shoL, shoR = pt(side("Left") .. "UpperArm"), pt(side("Right") .. "UpperArm")
	if not (hipL and hipR and shoL and shoR) then return nil end
	local hip, sho = (hipL + hipR) / 2, (shoL + shoR) / 2
	local torso = math.max((sho - hip).Magnitude, 0.1)
	local m = {}
	for _, s in ipairs({ "L", "R" }) do
		local S = side(if s == "L" then "Left" else "Right")
		local sh, el, wr = pt(S .. "UpperArm"), pt(S .. "LowerArm"), pt(S .. "Hand")
		local hp, kn, an = pt(S .. "UpperLeg"), pt(S .. "LowerLeg"), pt(S .. "Foot")
		m[s .. "w"] = wr and (wr.Y - hip.Y) / torso
		m[s .. "e"] = sh and el and wr and ang2(sh, el, wr)
		m[s .. "k"] = hp and kn and an and ang2(hp, kn, an)
		local head = pt("Head")
		m["C" .. s:lower()] = wr and head and (wr - head).Magnitude / torso
	end
	local function tilt(a, b) return math.deg(math.atan2(a.Y - b.Y, -(a.X - b.X))) end
	m.lean = (tilt(shoL, shoR) - tilt(hipL, hipR) + 180) % 360 - 180
	local low, xs, ys = math.huge, {}, {}
	for n, c in pairs(cf) do if n ~= "HumanoidRootPart" then low = math.min(low, c.Position.Y) table.insert(xs, c.Position.X) table.insert(ys, c.Position.Y) end end
	table.sort(xs) table.sort(ys)
	m.lying = (xs[#xs] - xs[1]) > (ys[#ys] - ys[1]) * 1.05 or (hip.Y - low) < 0.35 * torso
	m.pts = {}
	for _, n in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }) do
		local q = pt(n) if q then table.insert(m.pts, Vector2.new(-(q.X - hip.X), q.Y - hip.Y) / torso) end
	end
	return m
end

local function parseVideo(text: string)
	local out = {}
	for line in text:gmatch("[^\n]+") do
		local name, rest = line:match("^(%S+%.mp4) (.+)$")
		if name and not rest:find("skipped") then
			local rows = {}
			for item in rest:gmatch("[^;]+") do
				local t, v = item:match("^([%d%.]+):(.*)$")
				if t and v ~= "-" then
					local f = {}
					for x in (v .. ","):gmatch("([^,]*),") do table.insert(f, x) end
					local function num(i) return tonumber(f[i]) end
					rows[#rows + 1] = { t = tonumber(t), Lw = num(1), Rw = num(2), Le = num(3), Re = num(4), Lk = num(5), Rk = num(6), lean = num(7), mot = num(8),
						lying = (f[9] or ""):sub(1, 1) == "L", Cl = (f[9] or ""):find("Cl") ~= nil, Cr = (f[9] or ""):find("Cr") ~= nil }
				end
			end
			out[name] = rows
		end
	end
	return out
end

local function runs(list, songAt, minRun)
	local out, cur = {}, nil
	for _, r in ipairs(list) do
		if cur and math.abs(r.t - cur.b - 0.2) < 0.05 then cur.b = r.t cur.n += 1 cur.v = math.max(cur.v, r.v)
		else if cur and cur.n >= minRun then table.insert(out, cur) end cur = { a = r.t, b = r.t, n = 1, v = r.v } end
	end
	if cur and cur.n >= minRun then table.insert(out, cur) end
	local s = {}
	for _, c in ipairs(out) do table.insert(s, string.format("%.1f-%.1f(%.0f)", songAt + c.a, songAt + c.b + 0.2, c.v)) end
	return table.concat(s, " ")
end

_G.captureMoves = function(cfg)
	local video = parseVideo(cfg.video)
	local report = {}
	local beat
	if cfg.beats then
		local bpm, first, period = cfg.beats:match("beats ([%d%.]+) ([%d%.]+) ([%d%.]+)")
		if bpm then beat = { first = tonumber(first) - (cfg.videoOffset or 0), period = tonumber(period) } end
	end
	local accents = {}
	for name, c in pairs(cfg.clips) do
		local rows = video[name]
		if rows then
			local K = keyframes(c.id)
			local caps, mots = {}, {}
			local prev
			for _, r in ipairs(rows) do
				local m = measure(solve(poseAt(K, r.t + (c.from or 0))), cfg.mirror == true)
				if m and prev then
					local s = 0
					for i = 1, math.min(#m.pts, #prev) do s += (m.pts[i] - prev[i]).Magnitude end
					m.mot = s / math.max(#m.pts, 1) / 0.2
					table.insert(mots, m.mot)
				end
				prev = m and m.pts
				caps[r] = m
			end
			table.sort(mots)
			local med = mots[math.max(1, #mots // 2)] or 1
			local flags = { STALL = {}, ARM = {}, BEND = {}, LEAN = {}, FLOOR = {}, FACE = {} }
			for _, r in ipairs(rows) do
				local m = caps[r]
				if m then
					if r.mot and m.mot and r.mot > 0.8 and m.mot < med / 3 then table.insert(flags.STALL, { t = r.t, v = r.mot * 10 }) end
					for _, s in ipairs({ "L", "R" }) do
						local vw, cw = r[s .. "w"], m[s .. "w"]
						if vw and cw and math.abs(vw - cw) > 0.5 then table.insert(flags.ARM, { t = r.t, v = (cw - vw) * 100 }) end
						for _, j in ipairs({ "e", "k" }) do
							local va, ca = r[s .. j], m[s .. j]
							if va and ca and math.abs(va - ca) > 60 then table.insert(flags.BEND, { t = r.t, v = ca - va }) end
						end
						if r["C" .. s:lower()] and m["C" .. s:lower()] and m["C" .. s:lower()] > 0.6 then table.insert(flags.FACE, { t = r.t, v = m["C" .. s:lower()] * 100 }) end
					end
					if r.lean and math.abs(r.lean) < 8 and math.abs(m.lean) > 15 and math.abs(m.lean) < 60 then table.insert(flags.LEAN, { t = r.t, v = m.lean }) end
					if r.lying ~= m.lying then table.insert(flags.FLOOR, { t = r.t, v = if r.lying then 1 else -1 }) end
					-- accents: the capture's speed peaks
					if m.mot and m.mot > med * 1.8 then table.insert(accents, c.at + r.t) end
				end
			end
			local line = { name .. " (song " .. string.format("%.1f", c.at) .. ")" }
			for _, k in ipairs({ "STALL", "ARM", "BEND", "LEAN", "FLOOR", "FACE" }) do
				local r = runs(flags[k], c.at, if k == "FLOOR" or k == "FACE" then 1 elseif k == "BEND" then 3 else 2)
				if r ~= "" then table.insert(line, k .. " " .. r) end
			end
			table.insert(report, table.concat(line, " | "))
		end
	end
	table.sort(report)
	if beat and #accents > 0 then
		local offs, off = {}, 0
		for _, a in ipairs(accents) do
			local k = math.floor((a - beat.first) / beat.period + 0.5)
			local d = a - (beat.first + k * beat.period)
			table.insert(offs, d)
			if math.abs(d) > 0.12 then off += 1 end
		end
		table.sort(offs)
		table.insert(report, string.format("BEAT accents %d, median %.2f s off the beat, %d of them 0.12 s+ off", #offs, offs[math.max(1, #offs // 2)], off))
	end
	return table.concat(report, "\n")
end

-- 3-9: length against the clip, copies
_G.uploadCheck = function(ids: {number}, clipLengths: {number}?)
	local out, sig = {}, {}
	for i, id in ipairs(ids) do
		local K = keyframes(id)
		local len = K[#K] and K[#K].t or 0
		local sum = 0
		for _, k in ipairs(K) do for _, c in pairs(k.p) do local x, y, z = c:ToEulerAnglesXYZ() sum += x + 2 * y + 3 * z end end
		local key = string.format("%d:%.4f", #K, sum)
		local copy = sig[key]
		sig[key] = sig[key] or i
		local want = clipLengths and clipLengths[i]
		table.insert(out, string.format("%d %d len %.2f%s%s", i, id, len, if want and math.abs(want - len) > 0.15 then string.format(" !! clip %.2f", want) else "", if copy then " !! copy of " .. copy else ""))
	end
	return table.concat(out, "\n")
end

-- 3-8: the same move in two places (pose of every limb, 1.6 s stretches)
_G.repeatScan = function(pieces: {{ id: number, at: number }}, mirror: boolean?)
	local samples = {}
	for _, pc in ipairs(pieces) do
		local K = keyframes(pc.id)
		local len = K[#K] and K[#K].t or 0
		local t = 0
		while t <= len do
			local cf = solve(poseAt(K, t))
			local v = {}
			for _, n in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do
				v[n] = cf[n] and cf[n].UpVector
			end
			table.insert(samples, { song = pc.at + t, id = pc.id, v = v })
			t += 0.2
		end
	end
	local function d(a, b)
		local s, c = 0, 0
		for n, x in pairs(a.v) do local y = b.v[n] if y then s += math.deg(math.acos(math.clamp(x:Dot(y), -1, 1))) c += 1 end end
		return if c > 0 then s / c else 999
	end
	local found = {}
	local W = 8 -- 1.6 s
	for i = 1, #samples - W do
		for j = i + W * 2, #samples - W do
			if samples[i].id ~= samples[j].id or math.abs(samples[i].song - samples[j].song) > 3 then
				local s = 0
				for k = 0, W - 1 do s += d(samples[i + k], samples[j + k]) end
				s /= W
				if s < 10 then
					local last = found[#found]
					if not (last and math.abs(last.a - samples[i].song) < 1 and math.abs(last.b - samples[j].song) < 1) then
						table.insert(found, { a = samples[i].song, b = samples[j].song, d = s })
					end
				end
			end
		end
	end
	local out = {}
	for _, f in ipairs(found) do table.insert(out, string.format("%.1f ~ %.1f (%.0f°)", f.a, f.b, f.d)) end
	return #found .. " pairs: " .. table.concat(out, ", ")
end

return "capture_moves loaded"
