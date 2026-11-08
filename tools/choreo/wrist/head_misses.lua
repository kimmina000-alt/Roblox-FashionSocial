-- Head tilts the capture made too small (D-1054, docs/01_SYSTEMS/CHOREOGRAPHY.md §20).
-- Paste into Studio's MCP execute_luau (Edit mode). It defines
--   _G.capHead(id, step)        the capture's head roll against the chest in the
--                               practice video's picture (x = -X, y = -Y of the
--                               animation: the forearm check fitted that, median 17 deg),
--                               "len|r r r ..." ("-" while the chest or head faces away)
--   _G.capBend(id, step)        the same for the forearms and hands: "len|L R|..." with each
--                               side "forearm angle/hand bend" (tools/choreo/wrist/overlay_sheet.py)
--   _G.headMisses(text, ids, mirror, label)
--                               text = head_video.py's lines for one song, ids = { ["5.mp4"] = id },
--                               mirror = the track is danced mirrored. Returns ClubChoreo
--                               ChoreoHeadTilt lines: where the video tilts the head 15+ deg and
--                               the capture 12+ deg less the same way, 2+ samples 0.2 s apart,
--                               Head roll keys of 0.8 of the gap (at most 30 deg), easing in and
--                               out over 0.2 s (none before a run that starts at the piece start)
local KSP = game:GetService("KeyframeSequenceProvider")
local NAMES = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
local cache = {}
local function load(id)
	if cache[id] then return cache[id] end
	local ks = KSP:GetKeyframeSequenceAsync("rbxassetid://" .. id)
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local series = {}
	for _, kf in ipairs(kfs) do
		for _, n in ipairs(NAMES) do
			local p = kf:FindFirstChild(n, true)
			if p and p:IsA("Pose") then series[n] = series[n] or {} table.insert(series[n], { kf.Time, p.CFrame.Rotation }) end
		end
	end
	series.len = kfs[#kfs].Time
	cache[id] = series
	return series
end
local function at(series, n, t)
	local s = series[n]
	if not s or #s == 0 then return CFrame.identity end
	if t <= s[1][1] then return s[1][2] end
	for i = 1, #s - 1 do
		if t <= s[i + 1][1] then return s[i][2]:Lerp(s[i + 1][2], (t - s[i][1]) / math.max(s[i + 1][1] - s[i][1], 1e-6)) end
	end
	return s[#s][2]
end
local function roll(series, t, add)
	local ut = at(series, "LowerTorso", t) * at(series, "UpperTorso", t)
	local hd = ut * at(series, "Head", t) * CFrame.Angles(0, 0, math.rad(add or 0))
	local s, e = -ut.RightVector, -hd.RightVector
	local s2, e2 = Vector2.new(-s.X, -s.Y), Vector2.new(-e.X, -e.Y)
	if s2.Magnitude < 0.6 or e2.Magnitude < 0.6 then return nil end
	return (math.deg(math.atan2(e2.Y, e2.X)) - math.deg(math.atan2(s2.Y, s2.X)) + 180) % 360 - 180
end

_G.capHead = function(id, step)
	local series = load(id)
	local out = {}
	for t = 0, series.len + 1e-6, step do
		local r = roll(series, t)
		table.insert(out, if r then tostring(math.floor(r + 0.5)) else "-")
	end
	return string.format("%.2f|", series.len) .. table.concat(out, " ")
end

_G.capBend = function(id, step)
	local series = load(id)
	local chains = { { "LowerTorso", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand" }, { "LowerTorso", "UpperTorso", "RightUpperArm", "RightLowerArm", "RightHand" } }
	local out = {}
	for t = 0, series.len + 1e-6, step do
		local row = {}
		for _, ch in ipairs(chains) do
			local r, fa, hd = CFrame.identity, nil, nil
			for i, n in ipairs(ch) do
				r = r * at(series, n, t)
				local v = r:VectorToWorldSpace(Vector3.new(0, -1, 0))
				if i == 4 then fa = v elseif i == 5 then hd = v end
			end
			local f2, h2 = Vector2.new(-fa.X, -fa.Y), Vector2.new(-hd.X, -hd.Y)
			if f2.Magnitude < 0.35 or h2.Magnitude < 0.35 then table.insert(row, "-")
			else
				local af = math.deg(math.atan2(f2.Y, f2.X))
				table.insert(row, string.format("%d/%d", af, (math.deg(math.atan2(h2.Y, h2.X)) - af + 180) % 360 - 180))
			end
		end
		table.insert(out, table.concat(row, " "))
	end
	return string.format("%.2f|", series.len) .. table.concat(out, "|")
end

_G.headMisses = function(text, ids, mirror, label)
	local out = {}
	for line in text:gmatch("[^\n]+") do
		local name, rest = line:match("^(%S+)%s*(.*)$")
		local id = name and ids[name]
		if id and rest ~= "" then
			local series = load(id)
			local pts = {}
			for t, v in rest:gmatch("([%d%.]+)=(%-?%d+)") do
				t, v = tonumber(t), tonumber(v)
				if t <= series.len then
					local c = roll(series, t)
					if c and math.abs(v - c) >= 12 and (v - c) * v > 0 then
						-- how far the picture roll moves for 10 deg about the head's front axis
						local c2 = roll(series, t, 10)
						local slope = c2 and ((c2 - c + 180) % 360 - 180) / 10 or 0
						if math.abs(slope) > 0.3 then table.insert(pts, { t, math.clamp((v - c) * 0.8 / slope, -30, 30) }) end
					end
				end
			end
			local runs, run = {}, {}
			for _, p in ipairs(pts) do
				if #run > 0 and math.abs(p[1] - run[#run][1] - 0.2) < 0.05 and p[2] * run[#run][2] > 0 then table.insert(run, p)
				else if #run >= 2 then table.insert(runs, run) end run = { p } end
			end
			if #run >= 2 then table.insert(runs, run) end
			if #runs > 0 then
				local entries = {}
				for _, r in ipairs(runs) do
					local keys = {}
					if r[1][1] >= 0.2 then table.insert(keys, string.format("{ %.2f, 0, 0, 0 }", r[1][1] - 0.2)) end
					for _, p in ipairs(r) do table.insert(keys, string.format("{ %.2f, 0, 0, %d }", p[1], math.floor((if mirror then -p[2] else p[2]) + 0.5))) end
					table.insert(keys, string.format("{ %.2f, 0, 0, 0 }", math.min(r[#r][1] + 0.2, series.len)))
					table.insert(entries, "{ part = \"Head\", keys = { " .. table.concat(keys, ", ") .. " } }")
				end
				table.insert(out, string.format("\t[%d] = { %s }, -- %s %s", id, table.concat(entries, ", "), label or "", name))
			end
		end
	end
	return table.concat(out, "\n")
end

return "head_misses ready"
