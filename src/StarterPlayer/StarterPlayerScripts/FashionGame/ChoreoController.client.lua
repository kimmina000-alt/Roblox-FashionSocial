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
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

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
-- lastHips = the hips' place (LowerTorso Root joint) in the last frame of the
-- segment playing
local following: { soundId: number, tracks: {AnimationTrack}, ids: {number}, starts: {number?}, playing: AnimationTrack?, playingIndex: number?, lastHips: CFrame?, speed: number? }? = nil

-- (D-798, user: "앞에 서 있는 상태로 이어서 춰야") every segment starts with the
-- hips over the root and ends where the dance took them (Get A Guitar 2 ends
-- 11 studs forward), so the next one used to snap back. When a segment ends,
-- the root moves to where the hips are, less where the next one starts.
-- Start poses come from the keyframes; the end is measured on the character
-- (the animator scales the travel to the avatar's size).
local startPoses: {[number]: CFrame} = {}
local function loadStartPose(id: number)
	if startPoses[id] then return end
	startPoses[id] = CFrame.identity
	task.spawn(function()
		local ok, sequence = pcall(function()
			return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://" .. tostring(id))
		end)
		if not ok or not sequence then return end
		local first: Keyframe? = nil
		for _, kf in ipairs((sequence :: KeyframeSequence):GetKeyframes()) do
			if kf:IsA("Keyframe") and (not first or kf.Time < first.Time) then first = kf end
		end
		local pose = first and first:FindFirstChild("LowerTorso", true)
		if pose and pose:IsA("Pose") then startPoses[id] = pose.CFrame end
	end)
end

local function flat(c: CFrame): CFrame
	local _, yaw = c:ToEulerAnglesYXZ()
	return CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, yaw, 0)
end

-- the hips' animated offset from the root (a Motor6D, or an AnimationConstraint
-- on newer avatars)
local function hipsTransform(): CFrame?
	local character = player.Character
	local lower = character and character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root")
	if joint and joint:IsA("Motor6D") then return joint.Transform end
	if joint and joint:IsA("AnimationConstraint") then return joint.Transform end
	return nil
end

-- moves the root under the hips of the segment that is ending; false when it
-- would leave the club or go through a wall (then the dancer steps back)
local function carry(nextStart: CFrame?): boolean
	local f = following
	local hips = f and f.lastHips
	if not f or not hips then return false end
	f.lastHips = nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return false end
	local target = root.CFrame * flat(hips) * flat(nextStart or CFrame.identity):Inverse()
	if not ClubConfig.isInClub(target.Position) then return false end
	local skip = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(skip, p.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	if workspace:Raycast(root.Position, target.Position - root.Position, params) then return false end
	root.CFrame = target
	return true
end

local function stopFollowing()
	if not following then return end
	-- (D-798) stay where the dance got to
	local fade = if following.playing and carry(nil) then 0 else 0.25
	for _, t in ipairs(following.tracks) do
		t:Stop(fade)
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
	local tracks, ids, starts = {}, {}, {}
	for _, entry in ipairs(track.choreo) do
		local id = if typeof(entry) == "table" then entry.id else entry
		local at = if typeof(entry) == "table" and typeof(entry.at) == "number" then entry.at else nil
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(id)
		local ok, loaded = pcall(function() return anim:LoadAnimation(animation) end)
		if ok and loaded then
			loaded.Priority = Enum.AnimationPriority.Action2
			loaded.Looped = false
			table.insert(tracks, loaded)
			ids[#tracks] = id
			starts[#tracks] = at
			loadStartPose(id)
		else
			warn("[ChoreoController] Could not load", id, loaded)
		end
	end
	if #tracks == 0 then return end
	following = { soundId = track.soundId, tracks = tracks, ids = ids, starts = starts, playing = nil, playingIndex = nil, lastHips = nil, speed = nil }
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
-- steps (D-798: a carried root and the next segment's first pose show in the
-- same frame)
RunService.PreAnimation:Connect(function()
	if not following then return end
	local track = playingTrack()
	if not track or track.soundId ~= following.soundId then return end
	-- (D-798) where the hips got to in the frame just drawn
	local hips = hipsTransform()
	if hips and following.playing and following.playing.IsPlaying then following.lastHips = hips end
	-- where the song is, in the club's seconds (the DJ's speed carries over)
	local djSpeed = attr("ClubMusicSpeed", 1)
	local paused = FashionGame:GetAttribute("ClubMusicPaused") == true
	local start = attr("ClubTrackStart", workspace:GetServerTimeNow())
	local songTime = if paused
		then attr("ClubMusicPausedAt", 0) / math.max(ClubConfig.trackRate(track, 1), 1e-3)
		else (workspace:GetServerTimeNow() - start) * djSpeed
	-- which segment that is (lengths known once each one has loaded); a gap
	-- between segments (an `at` later than the one before ends) stands still
	local t, index = 0, nil :: number?
	local segStart = 0
	for i, seg in ipairs(following.tracks) do
		if seg.Length <= 0 then return end -- (still loading)
		segStart = following.starts[i] or segStart
		if songTime >= segStart and songTime < segStart + seg.Length then index = i t = songTime - segStart break end
		segStart += seg.Length
	end
	if not index then
		-- before, between or after the segments: no dance right now
		if following.playing then
			following.playing:Stop(if carry(nil) then 0 else 0.3)
			following.playing = nil
			following.playingIndex = nil
		end
		return
	end
	local seg = following.tracks[index]
	if following.playing ~= seg then
		-- (D-798) the next segment in line goes on from where this one ended
		local fade = 0.15
		if following.playing and following.playingIndex == index - 1 and carry(startPoses[following.ids[index]]) then fade = 0 end
		if following.playing then following.playing:Stop(fade) end
		seg:Play(fade)
		following.playing = seg
		following.playingIndex = index
		following.lastHips = nil
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
