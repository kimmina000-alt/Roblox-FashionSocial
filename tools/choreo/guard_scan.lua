--[[ (D-1303) guard_scan: run in Studio Play (MCP execute_luau, Client datamodel) to find, over whole songs, the three
faults fixed in D-1296 / D-1297 (NEON 2:31 / 3:32, ILLIT 0:36 / 0:38, Suddenly 2:23 / 2:35):

  GUARD  ChoreoBodyGuard pushes an arm out and lets it go within 0.7 s (a hand passing close in front of the body or
         resting on a shoulder): the arm flicks / turns back. Fix: ChoreoFixes `guardOff = { from, to, side }`.
  STALL  the whole body nearly stops for one 0.15 s step between moving steps (a seam between pieces). Fix: `slowIn`
         on the next piece (D-1296: { 0.4, 0.4 } + blend 0.5), not a later `at`.
  SHAKE  the head's path over 0.3 s is 2.5x the way it went (shaking while it moves). Fix: `steady` 24 on the torso / head.

Usage (Server first: FashionGame:SetAttribute("ClockOverride", 22), the character pivoted into the club):
  1. paste this file's text into execute_luau (Client): it defines _G.guardScan and starts it
       _G.guardScan({ "aespa-Lemonade", ... } or nil = every unlocked song with a choreography, speed = 1)
  2. poll: `return _G.scanStatus()` (each call < 60 s), the report is in _G.scanReport when done
Song times in the report are the original song's seconds (the play bar's x songRate). Check each hit at 1x with the
guard on / off (FashionGame attribute ChoreoBodyGuardOff) before fixing: some pushes are real (an arm through the body).
]]
local FG = game.ReplicatedStorage.FashionGame
local CC = require(FG.Shared.ClubConfig)
local music = FG.Remotes.Music
local player = game.Players.LocalPlayer

local function song()
	local tr = CC.Playlist[FG:GetAttribute("ClubTrack")]
	return (workspace:GetServerTimeNow() - FG:GetAttribute("ClubTrackStart")) * CC.songRate(tr, FG:GetAttribute("ClubMusicSpeed") or 1), tr
end

local function play(index, at)
	for _ = 1, 10 do
		if FG:GetAttribute("ClubTrack") == index then break end
		music:InvokeServer("Play", index)
		task.wait(1)
	end
	local tr = CC.Playlist[index]
	local fs = if CC.fileSpeed then CC.fileSpeed(tr) else (tr.fileSpeed or 1)
	music:InvokeServer("Seek", math.max(at / fs, 0) / tr.length)
end

_G.scanLog = {}
_G.scanState = { song = "", t = 0, n = 0, total = 0, done = false }

_G.scanStop = false
local function scanOne(index)
	local tr = CC.Playlist[index]
	local log = _G.scanLog
	play(index, 0)
	task.wait(1.5)
	local ch = player.Character
	local pulse = { Left = nil, Right = nil }
	local lastT, stuck = -1, 0
	local stepMove, stepT, steps = 0, nil, {}
	local headPath, headFrom, headT, headRev = 0, nil, nil, 0
	local lastP = {}
	local finished = false
	local t0 = os.clock()
	while not finished and not _G.scanStop do
		task.wait()
		if FG:GetAttribute("ClubTrack") ~= index then break end
		local s = song()
		_G.scanState.t = s
		if s <= lastT + 1e-3 then stuck += 1 if stuck > 120 then break end else stuck = 0 end
		lastT = s
		if os.clock() - t0 > 400 then break end
		if not (ch and ch.Parent) then ch = player.Character end
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if root and s > 2 then
			-- GUARD
			for side, attr in pairs({ Left = "GuardL", Right = "GuardR" }) do
				local v = ch:GetAttribute(attr) or 0
				local p = pulse[side]
				if not p and v > 0.12 then pulse[side] = { from = s, peak = v }
				elseif p then
					if v > p.peak then p.peak = v end
					if v < 0.03 then
						if p.from ~= math.huge and s - p.from < 0.7 then table.insert(log, string.format("GUARD %s %s %.2f (peak %.2f rad)", tr.title, side, p.from, p.peak)) end
						pulse[side] = nil
					elseif s - p.from > 0.7 then p.from = math.huge end -- a long, real push: not a flick
				end
			end
			-- STALL (steps of 0.15 s)
			local hrp = root.CFrame
			for _, n in ipairs({ "LeftHand", "RightHand", "Head", "LeftFoot", "RightFoot" }) do
				local part = ch:FindFirstChild(n)
				if part then
					local q = hrp:PointToObjectSpace(part.Position)
					if lastP[n] then stepMove += (q - lastP[n]).Magnitude end
					lastP[n] = q
				end
			end
			stepT = stepT or s
			if s - stepT >= 0.15 then
				table.insert(steps, { stepT, stepMove })
				local k = #steps
				if k >= 3 then
					local a, b, c = steps[k - 2][2], steps[k - 1][2], steps[k][2]
					if b < 0.5 and a > 1.5 and c > 1.5 then table.insert(log, string.format("STALL %s %.2f (%.2f between %.1f / %.1f)", tr.title, steps[k - 1][1], b, a, c)) end
				end
				stepMove, stepT = 0, s
			end
			-- SHAKE (0.3 s windows of the head)
			local head = ch:FindFirstChild("Head")
			if head then
				local q = hrp:PointToObjectSpace(head.Position)
				headFrom = headFrom or q
				headT = headT or s
				if lastP.HeadS then
					local v = q - lastP.HeadS
					headPath += v.Magnitude
					-- (a shake turns back again and again; a nod turns back once)
					if lastP.HeadV and v.Magnitude > 0.01 and lastP.HeadV.Magnitude > 0.01 and v.Unit:Dot(lastP.HeadV.Unit) < -0.3 then headRev += 1 end
					lastP.HeadV = v
				end
				lastP.HeadS = q
				if s - headT >= 0.3 then
					local way = (q - headFrom).Magnitude
					if headRev >= 3 and headPath > 0.6 and headPath > 2.5 * math.max(way, 0.05) then table.insert(log, string.format("SHAKE %s %.2f (path %.2f, way %.2f, %d turn-backs)", tr.title, headT, headPath, way, headRev)) end
					headPath, headFrom, headT, headRev = 0, q, s, 0
				end
			end
		end
	end
end

_G.guardScan = function(titles, speed)
	FG:SetAttribute("GuardLog", true)
	local list = {}
	for i, tr in ipairs(CC.Playlist) do
		local want = titles == nil and tr.choreo ~= nil and not tr.locked
		if titles then for _, t in ipairs(titles) do if t == tr.title then want = true end end end
		if want then table.insert(list, i) end
	end
	_G.scanState.total = #list
	task.spawn(function()
		for k, index in ipairs(list) do
			_G.scanState.n, _G.scanState.song = k, CC.Playlist[index].title
			local ok, err = pcall(scanOne, index)
			if not ok then table.insert(_G.scanLog, "ERROR " .. CC.Playlist[index].title .. " " .. tostring(err)) end
		end
		_G.scanState.done = true
		_G.scanReport = table.concat(_G.scanLog, "\n")
	end)
end

_G.scanStatus = function()
	local t0 = os.clock()
	while not _G.scanState.done and os.clock() - t0 < 50 do task.wait(1) end
	local st = _G.scanState
	return string.format("%d/%d %s %.0f s, %d hits%s", st.n, st.total, st.song, st.t, #_G.scanLog, st.done and " DONE" or "")
end

return "guard_scan ready"
