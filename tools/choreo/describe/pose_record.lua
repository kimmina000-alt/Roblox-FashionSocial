--[[ Game side of the pose text tool (D-1863, tools/choreo/describe/README.md).
This file is the body of a LocalScript. In Play, MCP execute_luau in the CLIENT datamodel (the player in the
club, night: FashionGame ClockOverride 22) runs:

  local ls = Instance.new("LocalScript")
  ls.Name = "PoseRec"
  ls.Source = [==[ <this whole file> ]==]
  ls:SetAttribute("Song", "내 이름을")  -- playlist index or part of the title
  ls:SetAttribute("From", 5)  ls:SetAttribute("To", 160)  ls:SetAttribute("Tag", "tws")
  ls.Parent = game.Players.LocalPlayer.PlayerScripts

(a LocalScript keeps running after the MCP call ends; a task.spawn inside execute_luau is stopped).
It plays the song from From - 1 (Studio is the DJ), turns the 🎵 choreography on, and every Step (0.05)
seconds of song time prints "POSEREC|tag|t|..." (the body points); then it removes itself.
Python reads the lines from Studio's log file:   python tools/choreo/describe/pose_log.py tws --out game.json
Other attributes: Step, Front (yaw in degrees of "front"; default: the way the character faces at the start),
Seek = false (record what is playing). Set the attribute Stop = true (or destroy the script) to end early.
Song time = the play bar (ClubConfig.songRate), as in play_record.lua. ]]

local FG = game.ReplicatedStorage.FashionGame
local CC = require(FG.Shared.ClubConfig)
local music = FG.Remotes.Music
local RS = game:GetService("RunService")

local function songNow()
	local tr = CC.Playlist[FG:GetAttribute("ClubTrack")]
	return (workspace:GetServerTimeNow() - FG:GetAttribute("ClubTrackStart")) * CC.songRate(tr, FG:GetAttribute("ClubMusicSpeed") or 1), tr
end

local function goTo(index, songSec)
	for _ = 1, 10 do
		if FG:GetAttribute("ClubTrack") == index then break end
		music:InvokeServer("Play", index)
		task.wait(1)
	end
	if FG:GetAttribute("ClubTrack") ~= index then error("could not play song " .. index) end
	local tr = CC.Playlist[index]
	local fs = if CC.fileSpeed then CC.fileSpeed(tr) else (tr.fileSpeed or 1)
	return music:InvokeServer("Seek", math.max(0, songSec / fs) / tr.length)
end

local function findSong(q)
	if type(q) == "number" then return q end
	for i, tr in ipairs(CC.Playlist) do
		if tr.title and string.find(tr.title, q, 1, true) then return i end
	end
	error("no song like " .. tostring(q))
end

local NAMES = { "nose", "lear", "rear", "lsho", "rsho", "lelb", "relb", "lwri", "rwri", "lhand", "rhand",
	"lhip", "rhip", "lkne", "rkne", "lank", "rank", "ltoe", "rtoe" }

local function points(ch)
	local function att(part, name)
		local p = ch:FindFirstChild(part)
		local a = p and p:FindFirstChild(name)
		return a and a.WorldPosition
	end
	local function at(part, x, y, z)
		local p = ch:FindFirstChild(part)
		if not p then return nil end
		local s = p.Size
		return (p.CFrame * CFrame.new(x * s.X, y * s.Y, z * s.Z)).Position
	end
	local P = {
		nose = at("Head", 0, -0.05, -0.5), lear = at("Head", -0.5, 0, 0), rear = at("Head", 0.5, 0, 0),
		-- (the arm's own shoulder point: a shrug moves the upper arms, not the torso's attachment, D-1921)
		lsho = att("LeftUpperArm", "LeftShoulderRigAttachment") or att("UpperTorso", "LeftShoulderRigAttachment"),
		rsho = att("RightUpperArm", "RightShoulderRigAttachment") or att("UpperTorso", "RightShoulderRigAttachment"),
		lelb = att("LeftUpperArm", "LeftElbowRigAttachment"), relb = att("RightUpperArm", "RightElbowRigAttachment"),
		lwri = att("LeftLowerArm", "LeftWristRigAttachment"), rwri = att("RightLowerArm", "RightWristRigAttachment"),
		lhand = at("LeftHand", 0, -0.25, 0), rhand = at("RightHand", 0, -0.25, 0),
		lhip = att("LowerTorso", "LeftHipRigAttachment"), rhip = att("LowerTorso", "RightHipRigAttachment"),
		lkne = att("LeftUpperLeg", "LeftKneeRigAttachment"), rkne = att("RightUpperLeg", "RightKneeRigAttachment"),
		lank = att("LeftLowerLeg", "LeftAnkleRigAttachment"), rank = att("RightLowerLeg", "RightAnkleRigAttachment"),
		ltoe = at("LeftFoot", 0, -0.5, -0.5), rtoe = at("RightFoot", 0, -0.5, -0.5),
	}
	local lh, rh = ch:FindFirstChild("LeftHand"), ch:FindFirstChild("RightHand")
	local V = {
		lhd = lh and -lh.CFrame.UpVector, rhd = rh and -rh.CFrame.UpVector,
		lpn = lh and lh.CFrame.RightVector, rpn = rh and -rh.CFrame.RightVector, -- out of the palm (palms face the thighs at rest)
	}
	local function low(part)
		local p = ch:FindFirstChild(part)
		if not p then return nil end
		local s, m = p.Size / 2, math.huge
		for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
			m = math.min(m, (p.CFrame * Vector3.new(x * s.X, y * s.Y, z * s.Z)).Y)
		end end end
		return m
	end
	return P, V, low("LeftFoot"), low("RightFoot")
end

local function run(o)
	local tag, step = o.tag or "rec", o.step or 0.05
	do
		local ok, err = pcall(function()
			if o.song and o.seek ~= false then
				goTo(findSong(o.song), (o.from or 0) - 1)
				task.wait(0.5)
			end
			-- the 🎵 choreography on (ChoreoController, the same tap as the banner button)
			local lp = game.Players.LocalPlayer
			for _ = 1, 3 do
				if lp:GetAttribute("ChoreoFollowing") then break end
				local ok, UiBus = pcall(require, lp.PlayerScripts:WaitForChild("FashionGame"):WaitForChild("UiBus"))
				if ok then UiBus.ChoreoTap:Fire() end
				task.wait(0.5)
			end
			if not lp:GetAttribute("ChoreoFollowing") then print("POSEREC|" .. (o.tag or "rec") .. "|NOTE|choreography is not on") end
			local ch = game.Players.LocalPlayer.Character
			local root = ch:WaitForChild("HumanoidRootPart")
			local fr
			if o.front then
				local a = math.rad(o.front)
				fr = Vector3.new(-math.sin(a), 0, -math.cos(a))
			else
				fr = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			end
			fr = fr.Unit
			local up = Vector3.yAxis
			local rv = (-fr):Cross(up).Unit -- the viewer's right
			local origin = root.Position
			local function v3(v, isPoint)
				if not v then return "," end
				local d = if isPoint then v - origin else v
				return string.format("%.2f,%.2f,%.2f", d:Dot(rv), d.Y, d:Dot(fr))
			end
			print(string.format("POSEREC|%s|BEGIN|%s|step=%.3f", tag, table.concat(NAMES, ","), step))
			local nextT, n, t0 = o.from or songNow(), 0, os.clock()
			local playing = FG:GetAttribute("ClubTrack")
			while script.Parent and not script:GetAttribute("Stop") do
				RS.Heartbeat:Wait()
				if FG:GetAttribute("ClubTrack") ~= playing then break end -- (the song ended or someone changed it)
				local s = songNow()
				if o.to and s > o.to then break end
				if os.clock() - t0 > 900 then break end
				if s >= nextT then
					ch = game.Players.LocalPlayer.Character
					if ch then
						local P, V, lf, rf = points(ch)
						local parts = {}
						for _, nm in ipairs(NAMES) do table.insert(parts, v3(P[nm], true)) end
						for _, nm in ipairs({ "lhd", "rhd", "lpn", "rpn" }) do table.insert(parts, v3(V[nm], false)) end
						table.insert(parts, string.format("%.2f,%.2f", (lf or 0) - origin.Y, (rf or 0) - origin.Y))
						print(string.format("POSEREC|%s|%.3f|%s", tag, s, table.concat(parts, ";")))
						n += 1
					end
					-- (a slow frame skips grid points instead of bunching them)
					nextT = math.max(nextT + step, s - (s - nextT) % step + step)
				end
			end
			print(string.format("POSEREC|%s|END|%d", tag, n))
		end)
		if not ok then print("POSEREC|" .. tag .. "|ERROR|" .. tostring(err)) end
	end
end

run({
	song = script:GetAttribute("Song"), from = script:GetAttribute("From"), to = script:GetAttribute("To"),
	tag = script:GetAttribute("Tag"), step = script:GetAttribute("Step"), front = script:GetAttribute("Front"),
	seek = script:GetAttribute("Seek"),
})
script:Destroy()
