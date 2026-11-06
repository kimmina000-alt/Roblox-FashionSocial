-- Choreography Play recorder (D-965 / D-966, docs/01_SYSTEMS/CHOREOGRAPHY.md §16-§17).
-- Paste into Studio's MCP execute_luau in the CLIENT datamodel while Play
-- runs (the player in the club: server attribute ClockOverride 22, character
-- at CFrame(118, -19, -205)). It defines _G helpers, then
--   _G.flagSong(playlistIndex, fromSong, toSong)
-- seeks there, follows the song frame by frame (60 Hz Heartbeat, also when
-- the window is in the background) and returns counts and only what looks
-- wrong, in song seconds (the play bar):
--   SNAP      a joint turns 12°+ in one frame and 3x more than the frames
--             around it: a frame jump ("프레임 뚝뚝 끊기는 부분"). A fast swing
--             speeds up over several frames and is not one.
--   TELEPORT  the body goes 1 stud+ in 0.3 s while neither foot steps along
--             (each foot moves on the body less than half of it): "캐릭터
--             위치 갑자기 이동" (the user: "1 스터드도 티 날 것 같아")
--   JUMP      the body moves 12 stud/s+ in a frame
--   SPIN      the hips turn 600°/s+ (10° a frame; an even turn is 2-7°)
--   SLIDE     the body travels 0.5 stud+ in 0.5 s while both feet stay where
--             they were on the body ("다리 가만히 있는데 이동")
--   SHAKE     10+ small turn-backs in 0.5 s in a held pose ("달달 떠는 거")
--   JITTER    a hand / foot / head turning back on its own path 8+ times in
--             0.5 s, even while dancing ("바들바들")
-- Keep each call under ~35 s of song (MCP stops a call at about 60 s and may
-- drop the connection): call it again for the next stretch. Studio attribute
-- ChoreoSnapOff (FashionGame, set on the server) turns the snap limiter off
-- to compare.

local FG = game.ReplicatedStorage.FashionGame
local CC = require(FG.Shared.ClubConfig)
local music = FG.Remotes.Music
local JN = { "LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }

_G.song = function()
	local tr = CC.Playlist[FG:GetAttribute("ClubTrack")]
	return (workspace:GetServerTimeNow() - FG:GetAttribute("ClubTrackStart")) * CC.songRate(tr, FG:GetAttribute("ClubMusicSpeed") or 1), tr
end

-- play the song (Studio is the DJ) and move to `songSec` (play-bar seconds)
_G.go = function(index, songSec)
	if FG:GetAttribute("ClubTrack") ~= index then music:InvokeServer("Play", index) task.wait(1) end
	local tr = CC.Playlist[index]
	-- (a 3x upload's file seconds are a third of the song's: ClubConfig.fileSpeed)
	local fs = if CC.fileSpeed then CC.fileSpeed(tr) else (tr.fileSpeed or 1)
	return music:InvokeServer("Seek", (songSec / fs) / tr.length)
end

-- every frame from s0 to s1: { song, root x, root z, hips yaw, chest yaw,
-- left foot y, right foot y, left foot x, z, right foot x, z (on the body),
-- hips height (on the body), { hands, feet, head in the world }, { degrees
-- each joint turned since the last frame } }
_G.rec = function(s0, s1)
	_G.rows = {}
	local done = false
	task.spawn(function()
		local hb = game:GetService("RunService").Heartbeat
		local t0 = os.clock()
		local ch = game.Players.LocalPlayer.Character
		local joints = {}
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part1 and not d:FindFirstAncestorOfClass("Accessory") then joints[d.Part1.Name] = d
			elseif d:IsA("AnimationConstraint") and d.Attachment1 then joints[d.Attachment1.Parent.Name] = d end
		end
		local last = {}
		while os.clock() - t0 < 50 do
			hb:Wait()
			local s = _G.song()
			if s > s1 then break end
			local deltas = {}
			for q, n in ipairs(JN) do
				local cf = joints[n] and joints[n].Transform
				if cf and last[q] then
					local _, a = (last[q]:Inverse() * cf):ToAxisAngle()
					deltas[q] = math.deg(math.abs(a))
				else deltas[q] = 0 end
				last[q] = cf
			end
			if s >= s0 then
				local root, lt, ut = ch.HumanoidRootPart, ch.LowerTorso, ch.UpperTorso
				local function yaw(cf) local l = cf.LookVector return math.deg(math.atan2(-l.X, -l.Z)) end
				local rel = root.CFrame:Inverse()
				local lf, rf = rel * ch.LeftFoot.Position, rel * ch.RightFoot.Position
				local limbs = { ch.LeftHand.Position, ch.RightHand.Position, ch.LeftFoot.Position, ch.RightFoot.Position, ch.Head.Position }
				table.insert(_G.rows, { s, root.Position.X, root.Position.Z, yaw(lt.CFrame), yaw(ut.CFrame), lf.Y, rf.Y, lf.X, lf.Z, rf.X, rf.Z, (rel * lt.Position).Y, limbs, deltas })
			end
		end
		done = true
	end)
	return function() return done end
end

_G.analyze = function()
	local rows, out, counts, lastSay = _G.rows, {}, {}, {}
	local function say(kind, s, text)
		local key = kind .. (text:match("^%a+") or "")
		if lastSay[key] and s - lastSay[key] < 0.4 then return end
		lastSay[key] = s
		counts[kind] = (counts[kind] or 0) + 1
		table.insert(out, string.format("%d:%05.2f %s %s", math.floor(s / 60), s % 60, kind, text))
	end
	local function body(a, b) return math.sqrt((b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2) end
	-- (per second, so a Studio hitch of several frames is not a lurch)
	for i = 2, #rows do
		local r, p = rows[i], rows[i - 1]
		local dt = math.max(r[1] - p[1], 1 / 60)
		local d = math.abs((r[4] - p[4] + 180) % 360 - 180) / dt
		if d > 600 then say("SPIN", r[1], string.format("%d°/s", math.floor(d))) end
		if body(p, r) / dt > 12 then say("JUMP", r[1], string.format("%.1f stud/s", body(p, r) / dt)) end
	end
	for i = 5, #rows - 4 do
		local dt = math.max(rows[i][1] - rows[i - 1][1], 1 / 60)
		for q = 1, #JN do
			local v = rows[i][14][q] * (1 / 60) / dt
			if v > 12 then
				local around = 0
				for j = i - 4, i + 4 do if math.abs(j - i) > 1 then around = math.max(around, rows[j][14][q]) end end
				if v > 3 * math.max(around, 2) then say("SNAP", rows[i][1], string.format("%s %.0f° in a frame (around %.0f)", JN[q], v, around)) end
			end
		end
		local j = i
		while j < #rows and rows[j + 1][1] <= rows[i][1] + 0.3 do j += 1 end
		local travel = body(rows[i], rows[j])
		if travel > 1 then
			local a, b = rows[i], rows[j]
			local feet = math.max(math.sqrt((b[8] - a[8]) ^ 2 + (b[9] - a[9]) ^ 2), math.sqrt((b[10] - a[10]) ^ 2 + (b[11] - a[11]) ^ 2))
			-- (a walking step moves each foot on the body about half the travel)
			if feet < 0.35 * travel then say("TELEPORT", rows[i][1], string.format("body %.1f stud in %.2f s, feet step %.1f", travel, b[1] - a[1], feet)) end
		end
	end
	local names = { "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Head" }
	for q = 1, 5 do
		local count, startK = 0, nil
		for i = 3, #rows do
			local k = math.floor(rows[i][1] * 2) / 2
			if k ~= startK then
				if count >= 8 then say("JITTER", startK, string.format("%s turns back %d times in 0.5 s", names[q], count)) end
				startK, count = k, 0
			end
			local a = rows[i - 1][13][q] - rows[i - 2][13][q]
			local b = rows[i][13][q] - rows[i - 1][13][q]
			if a.Magnitude > 0.01 and b.Magnitude > 0.01 and a:Dot(b) < 0 then count += 1 end
		end
	end
	-- SLIDE / SHAKE by half seconds
	local buckets, prevD = {}, {}
	for i = 2, #rows do
		local r, p = rows[i], rows[i - 1]
		local k = math.floor(r[1] * 2) / 2
		local b = buckets[k] or { travel = 0, back = 0, lo = { math.huge, math.huge, math.huge, math.huge }, hi = { -math.huge, -math.huge, -math.huge, -math.huge } }
		buckets[k] = b
		b.travel += body(p, r)
		b.first = b.first or r
		b.last = r
		for q, v in ipairs({ r[12], r[6], r[7], r[5] }) do b.lo[q] = math.min(b.lo[q], v) b.hi[q] = math.max(b.hi[q], v) end
		for _, j in ipairs({ 12, 6, 7, 5, 8, 10 }) do
			local d = r[j] - p[j]
			if j == 5 then d = ((d + 180) % 360 - 180) / 100 end
			if math.abs(d) > 0.004 then
				if prevD[j] and prevD[j] * d < 0 then b.back += 1 end
				prevD[j] = d
			end
		end
	end
	for k, b in pairs(buckets) do
		local f, l = b.first, b.last
		local feet = math.max(math.abs(l[8] - f[8]) + math.abs(l[9] - f[9]), math.abs(l[10] - f[10]) + math.abs(l[11] - f[11]))
		if b.travel > 0.5 and feet < 0.15 then say("SLIDE", k, string.format("%.2f stud, feet still on the body", b.travel)) end
		local held = b.hi[1] - b.lo[1] < 0.15 and b.hi[2] - b.lo[2] < 0.15 and b.hi[3] - b.lo[3] < 0.15 and (b.hi[4] - b.lo[4]) % 360 < 8
		if b.back >= 10 and b.travel < 0.05 and held then say("SHAKE", k, string.format("%d turn-backs in a held pose", b.back)) end
	end
	table.sort(out)
	local c = {}
	for k, v in pairs(counts) do table.insert(c, k .. "=" .. v) end
	table.sort(c)
	return table.concat(c, " "), out
end

_G.flagSong = function(index, fromSong, toSong)
	_G.go(index, math.max(fromSong - 1.5, 0))
	local done = _G.rec(fromSong, toSong)
	while not done() do task.wait(0.2) end
	local c, out = _G.analyze()
	return (if c == "" then "ok" else c) .. (if #out > 0 then "\n" .. table.concat(out, "\n") else "")
end

-- whole songs in the background, 30 s at a time: _G.scanAll({ 13, 16, ... })
-- starts it and returns at once; read _G.scanOut[index] / _G.scanDone with
-- short calls (a long MCP call drops the connection)
_G.scanOut, _G.scanDone = {}, false
_G.scanAll = function(list)
	task.spawn(function()
		for _, index in ipairs(list) do
			local tr = CC.Playlist[index]
			local fs = if CC.fileSpeed then CC.fileSpeed(tr) else (tr.fileSpeed or 1)
			local total = tr.length * fs
			local s, lines = 0, {}
			while s < total - 1 do
				local e = math.min(s + 30, total - 0.5)
				_G.go(index, math.max(s - 1.5, 0))
				local done = _G.rec(s, e)
				while not done() do task.wait(0.2) end
				if #_G.rows < 30 then table.insert(lines, string.format("%d-%d no dance rows", s, e)) break end
				local _, out = _G.analyze()
				for _, l in ipairs(out) do table.insert(lines, l) end
				s = e
			end
			_G.scanOut[index] = tr.title .. "\n" .. table.concat(lines, "\n")
		end
		_G.scanDone = true
	end)
	return "started"
end

return "play_record ready"
