--!strict
-- (D-1385, user 2026-11-13: "남들 춤이 한박자 느리게 보임. 남들 박자는 같음. 나랑만 다름.")
-- My own choreography is timed every frame to the music I hear (ChoreoController: the
-- song clock plus how late my audio runs). Other dancers' pieces reach me as replicated
-- animations, which arrive late by the network delay: everyone else looked the same but
-- behind me. Here, before the animator steps, each other dancer's playing choreography
-- piece is put at the moment it should be at by MY song clock (heard music), with the
-- same rules as ChoreoController (the entry's `at` / `from`, slowIn / slowOut, ChoreoFixes
-- `hold` / `warp`). Only pieces that are off by more than 0.08 s are moved, so a piece
-- keeps playing on its own between corrections; pieces without an `at` are left alone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local ChoreoSmooth = require(script.Parent:WaitForChild("ChoreoSmooth"))
local player = Players.LocalPlayer

local TOLERANCE = 0.08 -- seconds off before a piece is put back on my clock
local MAX_FIX = 2.5 -- further off than this is not lag (another dance, a phrase): left alone

local function attr(name: string, default: number): number
	local v = FashionGame:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function musicSound(): Sound?
	local dance = script.Parent:FindFirstChild("DanceController")
	local sound = dance and dance:FindFirstChild("ClubMusic")
	return if sound and sound:IsA("Sound") then sound else nil
end

local function idOf(animationId: string): string
	return string.match(animationId, "(%d+)%s*$") or animationId
end

-- the current song's pieces by animation id (an id may be used more than once)
local mapFor: number? = nil
local pieces: {[string]: {any}} = {}
local function piecesFor(track: any): {[string]: {any}}
	if mapFor == track.soundId then return pieces end
	mapFor = track.soundId
	pieces = {}
	for _, entry in ipairs(track.choreo or {}) do
		if typeof(entry) == "table" and typeof(entry.at) == "number" then
			local key = idOf(tostring(entry.id))
			pieces[key] = pieces[key] or {}
			table.insert(pieces[key], entry)
		end
	end
	return pieces
end

-- the song time I hear (song seconds), or nil when there is nothing to keep time with
local function mySongTime(track: any): number?
	if FashionGame:GetAttribute("ClubMusicPaused") == true then return nil end
	local songRate = ClubConfig.songRate(track, FashionGame:GetAttribute("ClubMusicSpeed"))
	local songTime = (workspace:GetServerTimeNow() - attr("ClubTrackStart", workspace:GetServerTimeNow())) * songRate
	local music = musicSound()
	local heardAt: number? = nil
	if music and music:GetAttribute("JoinedPlaying") == true and ClubConfig.isJoined(track) then
		local jt = music:GetAttribute("JoinedTime")
		if typeof(jt) == "number" and jt > 0.05 then heardAt = jt end
	elseif music and music.IsPlaying and music.TimePosition > 0.05 and music.SoundId == "rbxassetid://" .. tostring(track.soundId) then
		heardAt = music.TimePosition
	end
	if heardAt then
		local heard = heardAt * ClubConfig.fileSpeed(track)
		if math.abs(heard - songTime) < 3 then songTime = heard end
	end
	return songTime
end

-- where in the animation an entry should be at this song time (ChoreoController's rules),
-- or nil outside the entry's stretch
local function expected(entry: any, length: number, songTime: number): number?
	local from = if typeof(entry.from) == "number" then entry.from else 0
	local span = math.max(length - from, 0)
	local slowIn = if typeof(entry.slowIn) == "table" then entry.slowIn else nil
	local slowOut = if typeof(entry.slowOut) == "table" then entry.slowOut else nil
	local inLen, inExtra = if slowIn then math.min(slowIn[1], span) else 0, if slowIn then slowIn[2] else 0
	local outLen, outExtra = if slowOut then math.min(slowOut[1], span - inLen) else 0, if slowOut then slowOut[2] else 0
	local segStart = entry.at - inExtra
	local u = songTime - segStart
	if u < 0 or u > span + inExtra + outExtra + 1.5 then return nil end
	local t
	if u < inLen + inExtra then
		t = u * (if inLen + inExtra > 0 then inLen / (inLen + inExtra) else 1)
	else
		t = u - inExtra
		local outFrom = span - outLen
		if outLen > 0 and t > outFrom then t = outFrom + (t - outFrom) * (outLen / (outLen + outExtra)) end
	end
	t = math.min(t, span - 0.03) + from
	-- ChoreoFixes: a held pose and a warped stretch, as the dancer's own client plays them
	local fixes = ChoreoSmooth.fixes("rbxassetid://" .. idOf(tostring(entry.id)))
	local holds = fixes and fixes.hold
	if holds then
		for _, hold in ipairs(if holds.from then { holds } else holds) do
			if t >= hold.from and t < hold.to then return hold.from end
		end
	end
	local warps = fixes and fixes.warp
	if warps then
		for _, w in ipairs(if warps.from then { warps } else warps) do
			if t >= w.from and t < w.to then
				return w.play[1] + (t - w.from) * (w.play[2] - w.play[1]) / (w.to - w.from)
			end
		end
	end
	return t
end

RunService.PreAnimation:Connect(function()
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	if not track or not track.choreo then return end
	local songTime = mySongTime(track)
	if not songTime then return end
	local map = piecesFor(track)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
					local entries = map[idOf(t.Animation.AnimationId)]
					if entries and t.Length > 0 and t.IsPlaying then
						-- (the use of this piece whose stretch holds the song time)
						local want: number? = nil
						for _, entry in ipairs(entries) do
							want = expected(entry, t.Length, songTime)
							if want then break end
						end
						if want then
							local off = want - t.TimePosition
							if math.abs(off) > TOLERANCE and math.abs(off) < MAX_FIX then
								t.TimePosition = math.clamp(want, 0, t.Length - 0.03)
							end
						end
					end
				end
			end
		end
	end
end)
