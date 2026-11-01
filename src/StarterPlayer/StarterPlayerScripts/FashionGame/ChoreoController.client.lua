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
-- starts[i] = its `at` (seconds into the song) or nil (after the one before)
local following: { soundId: number, tracks: {AnimationTrack}, starts: {number?}, playing: AnimationTrack? }? = nil

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
	local tracks, starts = {}, {}
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
			starts[#tracks] = at
		else
			warn("[ChoreoController] Could not load", id, loaded)
		end
	end
	if #tracks == 0 then return end
	following = { soundId = track.soundId, tracks = tracks, starts = starts, playing = nil }
	button.Text = "⏹ 그만 추기"
end

button.Activated:Connect(function()
	if following then stopFollowing() return end
	local track = playingTrack()
	if track and track.choreo and inClub() then startFollowing(track) end
end)

-- keep the dance on the song's clock
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
		if following.playing then following.playing:Stop(0.3) following.playing = nil end
		return
	end
	local seg = following.tracks[index]
	if following.playing ~= seg then
		if following.playing then following.playing:Stop(0.15) end
		seg:Play(0.15)
		following.playing = seg
		seg.TimePosition = t
	elseif math.abs(seg.TimePosition - t) > 0.3 then
		seg.TimePosition = t
	end
	seg:AdjustSpeed(if paused then 0 else djSpeed)
end)

player.CharacterAdded:Connect(function() following = nil button.Text = "💃 안무 따라하기" end)
