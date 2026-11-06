-- Choreography Play recorder (D-964, docs/01_SYSTEMS/CHOREOGRAPHY.md §16).
-- Paste into Studio's MCP execute_luau in the CLIENT datamodel while Play
-- runs (the player in the club: server attribute ClockOverride 22, character
-- at CFrame(118, -19, -205)). It defines _G helpers, then
--   _G.flagSong(playlistIndex, fromSong, toSong)
-- seeks there, follows the song frame by frame (60 Hz Heartbeat, also when
-- the window is in the background) and returns only what looks wrong, in
-- song seconds (the play bar):
--   SPIN    the hips turn 600°/s+ (10° a frame; an even turn is 2-7°)
--   JUMP    the body moves 12 stud/s+ (a jump, or a capture's hips dashing
--           off at a piece's end: Love 119 0:46, 2 studs in 0.25 s)
--   SLIDE   the body travels 0.5 stud+ in 0.5 s while both feet stay where they
--           were on the body (no step: the user's "다리 가만히 있는데 이동")
--   SHAKE   10+ small turn-backs in 0.5 s while the body stands still
--           (the user's "달달 떠는 거")
-- Keep each call under ~40 s of song (MCP stops a call at about 60 s): call
-- it again for the next stretch. _G.go / _G.rec / _G.yawLine / _G.feet /
-- _G.shake are the pieces, for a closer look at one spot (D-962 used them).

local FG = game.ReplicatedStorage.FashionGame
local CC = require(FG.Shared.ClubConfig)
local music = FG.Remotes.Music

_G.song = function()
	local tr = CC.Playlist[FG:GetAttribute("ClubTrack")]
	return (workspace:GetServerTimeNow() - FG:GetAttribute("ClubTrackStart")) * CC.songRate(tr, FG:GetAttribute("ClubMusicSpeed") or 1), tr
end

-- play the song (Studio is the DJ) and move to `songSec` (play-bar seconds)
_G.go = function(index, songSec)
	if FG:GetAttribute("ClubTrack") ~= index then music:InvokeServer("Play", index) task.wait(1) end
	local tr = CC.Playlist[index]
	return music:InvokeServer("Seek", (songSec / (tr.fileSpeed or 1)) / tr.length)
end

-- record every frame from s0 to s1: song, root x z, hips yaw, chest yaw, feet
-- (on the body), hips height (on the body)
_G.rec = function(s0, s1)
	_G.rows = {}
	local done = false
	task.spawn(function()
		local hb = game:GetService("RunService").Heartbeat
		local t0 = os.clock()
		while os.clock() - t0 < 50 do
			hb:Wait()
			local s = _G.song()
			if s > s1 then break end
			if s >= s0 then
				local ch = game.Players.LocalPlayer.Character
				local root, lt, ut = ch.HumanoidRootPart, ch.LowerTorso, ch.UpperTorso
				local function yaw(cf) local l = cf.LookVector return math.deg(math.atan2(-l.X, -l.Z)) end
				local rel = root.CFrame:Inverse()
				local lf, rf = rel * ch.LeftFoot.Position, rel * ch.RightFoot.Position
				table.insert(_G.rows, { s, root.Position.X, root.Position.Z, yaw(lt.CFrame), yaw(ut.CFrame), lf.Y, rf.Y, lf.X, lf.Z, rf.X, rf.Z, (rel * lt.Position).Y })
			end
		end
		done = true
	end)
	return function() return done end
end

_G.yawLine = function(step)
	local o, last = {}, -1
	for i, r in ipairs(_G.rows) do
		local p = _G.rows[i - 1]
		local d = p and ((r[4] - p[4] + 180) % 360 - 180) or 0
		if r[1] - last >= step or math.abs(d) > 10 then last = r[1] table.insert(o, string.format("%.2f:%d(%+d)", r[1], r[4], d)) end
	end
	return table.concat(o, " ")
end

_G.feet = function(step)
	local o, last = {}, -1
	for _, r in ipairs(_G.rows) do
		if r[1] - last >= step then last = r[1]
			table.insert(o, string.format("%.2f hip %.2f L %.2f %.2f %.2f R %.2f %.2f %.2f", r[1], r[12], r[8], r[9], r[6], r[10], r[11], r[7]))
		end
	end
	return table.concat(o, "\n")
end

-- per 0.5 s: body travel / turn-backs (hips height, feet height, chest yaw, feet x)
_G.shake = function()
	local buckets, prevD = {}, {}
	for i = 2, #_G.rows do
		local r, p = _G.rows[i], _G.rows[i - 1]
		local k = math.floor(r[1] * 2) / 2
		local b = buckets[k] or { travel = 0, back = 0 }
		buckets[k] = b
		b.travel += math.sqrt((r[2] - p[2]) ^ 2 + (r[3] - p[3]) ^ 2)
		for _, j in ipairs({ 12, 6, 7, 5, 8, 10 }) do
			local d = r[j] - p[j]
			if j == 5 then d = ((d + 180) % 360 - 180) / 100 end
			if math.abs(d) > 0.004 then
				if prevD[j] and prevD[j] * d < 0 then b.back += 1 end
				prevD[j] = d
			end
		end
	end
	local ks = {}
	for k in pairs(buckets) do table.insert(ks, k) end
	table.sort(ks)
	local o = {}
	for _, k in ipairs(ks) do table.insert(o, string.format("%.1f:%.2f/%d", k, buckets[k].travel, buckets[k].back)) end
	return table.concat(o, " "), buckets
end

_G.flagSong = function(index, fromSong, toSong)
	_G.go(index, math.max(fromSong - 1.5, 0))
	local done = _G.rec(fromSong, toSong)
	while not done() do task.wait(0.2) end
	local rows, out = _G.rows, {}
	local lastSay = {}
	local function say(kind, s, text)
		if lastSay[kind] and s - lastSay[kind] < 0.4 then return end
		lastSay[kind] = s
		table.insert(out, string.format("%d:%05.2f %s %s", math.floor(s / 60), s % 60, kind, text))
	end
	-- (per second, so a Studio hitch of several frames is not a lurch)
	for i = 2, #rows do
		local r, p = rows[i], rows[i - 1]
		local dt = math.max(r[1] - p[1], 1 / 60)
		local d = math.abs((r[4] - p[4] + 180) % 360 - 180) / dt
		if d > 600 then say("SPIN", r[1], string.format("%d°/s (%d° a frame)", math.floor(d), math.floor(d / 60))) end
		local move = math.sqrt((r[2] - p[2]) ^ 2 + (r[3] - p[3]) ^ 2) / dt
		if move > 12 then say("JUMP", r[1], string.format("%.1f stud/s", move)) end
	end
	-- SLIDE / SHAKE by half seconds
	local _, buckets = _G.shake()
	for k, b in pairs(buckets) do
		local first, last
		for _, r in ipairs(rows) do
			if r[1] >= k and r[1] < k + 0.5 then first = first or r last = r end
		end
		if first and last then
			local feet = math.max(math.abs(last[8] - first[8]) + math.abs(last[9] - first[9]), math.abs(last[10] - first[10]) + math.abs(last[11] - first[11]))
			if b.travel > 0.5 and feet < 0.15 then say("SLIDE", k, string.format("%.2f stud, feet still on the body", b.travel)) end
			-- a shake is many small turn-backs in a pose that otherwise holds:
			-- hips / feet heights within 0.15 stud and the chest within 8°
			-- (dancing in place turns back as often, but moves more)
			local lo, hi = { math.huge, math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge, -math.huge }
			for _, r in ipairs(rows) do
				if r[1] >= k and r[1] < k + 0.5 then
					for q, v in ipairs({ r[12], r[6], r[7], r[5] }) do lo[q] = math.min(lo[q], v) hi[q] = math.max(hi[q], v) end
				end
			end
			local still = hi[1] - lo[1] < 0.15 and hi[2] - lo[2] < 0.15 and hi[3] - lo[3] < 0.15 and (hi[4] - lo[4]) % 360 < 8
			if b.back >= 10 and b.travel < 0.05 and still then say("SHAKE", k, string.format("%d turn-backs in a held pose", b.back)) end
		end
	end
	table.sort(out)
	return if #out == 0 then "ok" else table.concat(out, "\n")
end

return "play_record ready"
