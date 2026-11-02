--!strict
-- Song choreography (user 2026-11-01, D-689): while a club track with a
-- `choreo` list plays (ClubConfig.Track.choreo), players inside the club see
-- a "💃 안무 따라하기" button. Tapping it plays the track's animations one
-- after another, lined up with the song: the place in the dance is the time
-- since the song started (FashionGame ClubTrackStart) times the DJ's speed,
-- since the dance was made to the song as heard in the club. It stops on a
-- second tap, when the song changes, when the player leaves the club, walks
-- or starts one of the dance menu's dances. Played on the player's own
-- Animator, so everyone sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local danceRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Dance") :: RemoteEvent
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ChoreoGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "Follow"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -16)
button.Size = UDim2.fromOffset(210, 40)
button.BackgroundColor3 = Color3.fromRGB(255, 70, 170)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 15
button.Text = "💃 안무 따라하기"
button.AutoButtonColor = true
button.Visible = false
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
do
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 2
	edge.Parent = button
end

-- 🧪 tests (user 2026-11-01): start Bubble Pop from inside the club without
-- being the DJ. Studio, or the owner's account on a phone / live server
-- (ClubConfig.canTestChoreo; the server checks the same)
local CAN_TEST = ClubConfig.canTestChoreo(player)
local testButton = button:Clone()
testButton.Name = "TestSong"
testButton.Position = UDim2.new(0.5, 0, 1, -64)
testButton.Size = UDim2.fromOffset(210, 32)
testButton.TextSize = 13
testButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
testButton.Text = "🧪 테스트: Bubble Pop 틀기"
testButton.Parent = gui
testButton.Activated:Connect(function()
	local musicRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Music") :: RemoteFunction
	local ok, message = musicRemote:InvokeServer("TestChoreoSong", nil)
	if not ok and message then warn("[ChoreoController]", message) end
end)

local function attr(name: string, default: number): number
	local v = FashionGame:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function playingTrack(): ClubConfig.Track?
	return ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
end

local function animator(): Animator?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function inClub(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and ClubConfig.isInClub(root.Position)
end

-- the segments of the track being followed, loaded on this character;
-- starts[i] = its `at` (seconds into the song) or nil (after the one before);
-- stops[i] = its `stop` (D-804) or nil; blends[i] = its `blend` (D-807) or nil;
-- froms[i] = its `from` (D-810, seconds into the animation) or 0
local following: { soundId: number, tracks: {AnimationTrack}, starts: {number?}, stops: {number?}, blends: {number?}, froms: {number}, playing: AnimationTrack?, speed: number? }? = nil

-- (D-802, user: "앵글 움직이는 부분 다 고쳐") the segments carry the dancer's
-- travel in the hips (Get A Guitar 2 ends 11 studs forward, then 3 starts
-- over the root again: the snap back of D-798). Moving the root along with
-- it (D-798) moved the camera and turned the dancer round, so now the dance
-- stays in place instead: while a choreography animation plays, the hips'
-- sideways / forward travel is taken out every frame, on every dancer this
-- client sees (other players' animations play here too). Turns stay.
local choreoAnimations: {[string]: boolean} = {}
for _, t in ipairs(ClubConfig.Playlist) do
	for _, entry in ipairs(t.choreo or {}) do
		local id = if typeof(entry) == "table" then entry.id else entry
		choreoAnimations["rbxassetid://" .. tostring(id)] = true
	end
end

-- the hips joint (a Motor6D, or an AnimationConstraint on newer avatars)
local function hipsJoint(character: Model?): (Motor6D | AnimationConstraint)?
	local lower = character and character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root")
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return joint :: any end
	return nil
end

-- after the animator, before the frame is drawn
RunService.PreSimulation:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local anim = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local joint = hipsJoint(character)
		if anim and joint then
			for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
				if t.Animation and choreoAnimations[t.Animation.AnimationId] then
					local hips = joint.Transform
					joint.Transform = CFrame.new(0, hips.Y, 0) * hips.Rotation
					break
				end
			end
		end
	end
end)

local function stopFollowing()
	if not following then return end
	for _, t in ipairs(following.tracks) do
		t:Stop(0.25)
		t:Destroy()
	end
	following = nil
	button.Text = "💃 안무 따라하기"
end

local function startFollowing(track: ClubConfig.Track)
	local anim = animator()
	if not anim or not track.choreo then return end
	-- (the dance menu's dance stops first: one dance at a time)
	local character = player.Character
	if character and character:GetAttribute("DanceKey") ~= nil then danceRemote:FireServer("Stop") end
	local tracks, starts, stops, blends, froms = {}, {}, {}, {}, {}
	for _, entry in ipairs(track.choreo) do
		local id = if typeof(entry) == "table" then entry.id else entry
		local at = if typeof(entry) == "table" and typeof(entry.at) == "number" then entry.at else nil
		local stop = if typeof(entry) == "table" and typeof(entry.stop) == "number" then entry.stop else nil
		local blend = if typeof(entry) == "table" and typeof(entry.blend) == "number" then entry.blend else nil
		local from = if typeof(entry) == "table" and typeof(entry.from) == "number" then entry.from else 0
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(id)
		local ok, loaded = pcall(function() return anim:LoadAnimation(animation) end)
		if ok and loaded then
			loaded.Priority = Enum.AnimationPriority.Action2
			loaded.Looped = false
			table.insert(tracks, loaded)
			starts[#tracks] = at
			stops[#tracks] = stop
			blends[#tracks] = blend
			froms[#tracks] = from
		else
			warn("[ChoreoController] Could not load", id, loaded)
		end
	end
	if #tracks == 0 then return end
	following = { soundId = track.soundId, tracks = tracks, starts = starts, stops = stops, blends = blends, froms = froms, playing = nil, speed = nil }
	button.Text = "⏹ 그만 추기"
end

button.Activated:Connect(function()
	if following then stopFollowing() return end
	local track = playingTrack()
	if track and track.choreo and inClub() then startFollowing(track) end
end)

-- start and stop following (the dance itself keeps time below)
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then return end
	accumulator = 0
	local track = playingTrack()
	local here = inClub()
	-- (hidden since D-717, user: the dance menu is the way in; the following
	-- code stays for later)
	button.Visible = false and here and track ~= nil and track.choreo ~= nil
	testButton.Visible = CAN_TEST and here
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- (D-726) a song with autoChoreo: standing still in the club starts it
	if not following and track and track.autoChoreo and track.choreo and here and humanoid
		and humanoid.MoveDirection.Magnitude <= 0.1 and not humanoid.Sit and not humanoid.PlatformStand
		and (character :: Model):GetAttribute("DanceKey") == nil
		and not player:GetAttribute("Carrying") and not player:GetAttribute("CarriedBy") then -- (a guard's carry, D-738)
		startFollowing(track)
	end
	if not following then return end
	if not track or track.soundId ~= following.soundId or not here or not humanoid
		or humanoid.MoveDirection.Magnitude > 0.1 or (character :: Model):GetAttribute("DanceKey") ~= nil
		or player:GetAttribute("Carrying") or player:GetAttribute("CarriedBy") then
		stopFollowing()
		return
	end
end)

-- the segment for this moment of the song, every frame before the animator
-- steps (D-798)
RunService.PreAnimation:Connect(function()
	if not following then return end
	local track = playingTrack()
	if not track or track.soundId ~= following.soundId then return end
	-- where the song is, in the club's seconds (the DJ's speed carries over)
	local djSpeed = attr("ClubMusicSpeed", 1)
	local paused = FashionGame:GetAttribute("ClubMusicPaused") == true
	local start = attr("ClubTrackStart", workspace:GetServerTimeNow())
	local songTime = if paused
		then attr("ClubMusicPausedAt", 0) / math.max(ClubConfig.trackRate(track, 1), 1e-3)
		else (workspace:GetServerTimeNow() - start) * djSpeed
	-- which segment that is (lengths known once each one has loaded); a gap
	-- between segments (an `at` later than the one before ends) stands still;
	-- t = the time in the animation (a `from` skips its start, D-810)
	local t, index = 0, nil :: number?
	local segStart = 0
	for i, seg in ipairs(following.tracks) do
		if seg.Length <= 0 then return end -- (still loading)
		local from = following.froms[i]
		local span = math.max(seg.Length - from, 0)
		segStart = following.starts[i] or segStart
		local segEnd = math.min(segStart + span, following.stops[i] or math.huge)
		if songTime >= segStart and songTime < segEnd then index = i t = songTime - segStart + from break end
		segStart += span
	end
	if not index then
		-- before, between or after the segments: no dance right now
		if following.playing then
			following.playing:Stop(0.3)
			following.playing = nil
		end
		return
	end
	local seg = following.tracks[index]
	if following.playing ~= seg then
		-- (D-807) the last pose eases into the first one over the entry's
		-- `blend`, longer where they differ more (tools/choreo/choreo_check.lua)
		local blend = following.blends[index] or 0.25
		if following.playing then following.playing:Stop(blend) end
		seg:Play(blend)
		following.playing = seg
		following.speed = nil
		seg.TimePosition = t
	elseif math.abs(seg.TimePosition - t) > 0.3 then
		seg.TimePosition = t
	end
	-- (D-798) a segment a moment ahead of the song holds its last pose
	-- instead of ending (and fading back to the root) before the next one
	local speed = if paused or seg.TimePosition >= seg.Length - 0.05 then 0 else djSpeed
	if following.speed ~= speed then
		seg:AdjustSpeed(speed)
		following.speed = speed
	end
end)

player.CharacterAdded:Connect(function() following = nil button.Text = "💃 안무 따라하기" end)
