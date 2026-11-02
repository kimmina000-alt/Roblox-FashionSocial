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
local ChoreoSmooth = require(script.Parent:WaitForChild("ChoreoSmooth"))
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
-- froms[i] = its `from` (D-810, seconds into the animation) or 0;
-- home = where the root was when the dance began (D-817)
local following: { soundId: number, tracks: {AnimationTrack}, starts: {number?}, stops: {number?}, blends: {number?}, froms: {number}, playing: AnimationTrack?, speed: number?, home: Vector3? }? = nil

-- (D-802, user: "앵글 움직이는 부분 다 고쳐") the segments carry the dancer's
-- travel in the hips (Get A Guitar 2 ends 11 studs forward, then 3 starts
-- over the root again: the snap back of D-798). Moving the root along with
-- it at the seams (D-798) jerked the camera and turned the dancer round.
-- While a choreography animation plays, the hips' sideways / forward travel
-- is taken out every frame, on every dancer this client sees (other
-- players' animations play here too); since D-813 the dancer's own client
-- moves the root along that travel instead (moveAlong), so the dance path
-- shows and each piece starts where the one before ended. Turns stay.
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

-- (D-811) every dancer's body joints by the part they move (the name the
-- keyframe poses use), for ChoreoSmooth
local jointsOf: {[Model]: {[string]: Motor6D | AnimationConstraint}} = setmetatable({}, { __mode = "k" }) :: any
local function bodyJoints(character: Model): {[string]: Motor6D | AnimationConstraint}
	local cached = jointsOf[character]
	if cached then return cached end
	local out = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and not d:FindFirstAncestorOfClass("Accessory") then
			out[d.Part1.Name] = d
		elseif d:IsA("AnimationConstraint") and d.Attachment1 and d.Attachment1.Parent then
			out[(d.Attachment1.Parent :: Instance).Name] = d
		end
	end
	jointsOf[character] = out
	return out
end

-- (D-811) the zigzag keyframes eased: each choreography animation playing
-- adds its correction at its own time, as much as it shows (its weight)
local function smoothJoints(character: Model, tracks: {AnimationTrack})
	if not ClubConfig.ChoreoSmoothing then return end
	-- (Studio only: FashionGame attribute ChoreoSmoothingOff compares without it)
	if RunService:IsStudio() and FashionGame:GetAttribute("ChoreoSmoothingOff") then return end
	local joints = bodyJoints(character)
	for _, t in ipairs(tracks) do
		local id = t.Animation and t.Animation.AnimationId
		local weight = t.WeightCurrent
		if id and weight > 0.01 then
			ChoreoSmooth.load(id)
			for part, joint in pairs(joints) do
				local fix = ChoreoSmooth.correction(id, part, t.TimePosition)
				if fix then
					joint.Transform = joint.Transform * CFrame.identity:Lerp(fix, math.min(weight, 1))
				end
			end
		end
	end
end

-- (D-813, user: "한 조각 안에서 3걸음 걸어나가서 끝났으면 다음 조각은 3걸음
-- 걸어나간 그 위치에서 시작하면 되잖아") the dance's own travel moves this
-- player's root, frame by frame, as far as the hips travel in each playing
-- piece (by its weight, so a blend between two pieces carries both moves
-- and nothing snaps back). The camera stays where the dance began (D-825,
-- holdCamera), the facing is
-- left alone (D-798 turned the dancer round), and it stops at walls and at
-- the club's edge. The hips' own travel is then taken out below as before.
local lastHips: {[AnimationTrack]: Vector3} = setmetatable({}, { __mode = "k" }) :: any
local travelScale = 0.85 -- (the animator shrinks travel to the avatar's size; measured below)
local function moveAlong(character: Model, joint: Motor6D | AnimationConstraint, tracks: {AnimationTrack}, dt: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not following then return end
	following.home = following.home or root.Position
	local move = Vector3.zero
	for _, t in ipairs(tracks) do
		local id = t.Animation and t.Animation.AnimationId
		local here = id and ChoreoSmooth.hips(id, t.TimePosition)
		if id and not here then ChoreoSmooth.load(id) end
		if here then
			local before = lastHips[t]
			lastHips[t] = here
			-- (a jump in the track's time, e.g. re-synced to the song: no move)
			if before and (here - before).Magnitude < 1.5 then
				move += (here - before) * math.min(t.WeightCurrent, 1)
			end
			-- the avatar's travel scale, from a piece playing alone
			if t.WeightCurrent > 0.99 and here.Magnitude > 1 then
				local actual = Vector3.new(joint.Transform.X, 0, joint.Transform.Z).Magnitude
				travelScale += 0.1 * (math.clamp(actual / here.Magnitude, 0.3, 2) - travelScale)
			end
		end
	end
	local worldMove = root.CFrame:VectorToWorldSpace(move * travelScale)
	-- (D-817, user: "쏠림만 빼기 … 이걸로 한번 보자") the pieces add up to a
	-- drift one way (Get A Guitar: about 30 studs over the song), so the dancer
	-- is eased back toward where the dance began, slowly (ChoreoDriftReturn
	-- seconds): a few seconds of travel inside a piece still shows, the
	-- build-up over the song does not
	local settle = ClubConfig.ChoreoDriftReturn
	local home = following.home
	if settle and home then
		local away = (root.Position - home) * Vector3.new(1, 0, 1)
		worldMove -= away * math.min(dt / settle, 1)
	end
	if worldMove.Magnitude < 1e-4 then return end
	local target = root.Position + worldMove
	if not ClubConfig.isInClub(target) then return end
	local skip = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(skip, p.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	-- (a step and a bit ahead, so the body does not end up in the wall)
	if workspace:Raycast(root.Position, worldMove.Unit * (worldMove.Magnitude + 1.5), params) then return end
	root.CFrame += worldMove
end

-- after the animator, before the frame is drawn
RunService.PreSimulation:Connect(function(dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local anim = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local joint = hipsJoint(character)
		if character and anim and joint then
			local choreo = {}
			for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
				if t.Animation and choreoAnimations[t.Animation.AnimationId] then table.insert(choreo, t) end
			end
			if #choreo > 0 then
				if p == player and following then moveAlong(character, joint, choreo, dt) end
				smoothJoints(character, choreo)
				local hips = joint.Transform
				joint.Transform = CFrame.new(0, hips.Y, 0) * hips.Rotation
			end
		end
	end
end)

-- (D-825, user: "춤 출 때 카메라 고정해 줘 … 플레이어가 회전하고 확대 축소해
-- 놓은 앵글로 고정되어 있어야 함") while following, the camera looks at a
-- still point where the dance began instead of at the dancer: it does not
-- move with the dance path, and the player can still turn and zoom it (the
-- angle and distance they set stay). When the dance stops, the point glides
-- to the character and the camera follows it again as usual.
local cameraAnchor: BasePart? = nil
-- where the camera looked above the root when the dance began (Camera.Focus),
-- so taking the camera and giving it back moves nothing
local focusOffset = Vector3.new(0, 1.5, 0)
local function cameraFocus(root: BasePart): Vector3
	return root.Position + focusOffset
end
local function holdCamera()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or cameraAnchor then return end
	local seen = workspace.CurrentCamera.Focus.Position - root.Position
	if seen.Magnitude < 6 then focusOffset = seen end
	local anchor = Instance.new("Part")
	anchor.Name = "ChoreoCameraAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(cameraFocus(root))
	anchor.Parent = workspace.CurrentCamera
	cameraAnchor = anchor
	workspace.CurrentCamera.CameraSubject = anchor
end
local function releaseCamera()
	local anchor = cameraAnchor
	if not anchor then return end
	cameraAnchor = nil
	task.spawn(function()
		local camera = workspace.CurrentCamera
		local from = anchor.Position
		local glide = 0.4
		local t0 = os.clock()
		while camera.CameraSubject == anchor and os.clock() - t0 < glide do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then break end
			local f = (os.clock() - t0) / glide
			anchor.CFrame = CFrame.new(from:Lerp(cameraFocus(root), f * f * (3 - 2 * f)))
			RunService.RenderStepped:Wait()
		end
		if camera.CameraSubject == anchor then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
		end
		anchor:Destroy()
	end)
end

local function stopFollowing()
	if not following then return end
	releaseCamera()
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
	holdCamera()
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

player.CharacterAdded:Connect(function()
	following = nil
	button.Text = "💃 안무 따라하기"
	if cameraAnchor then cameraAnchor:Destroy() cameraAnchor = nil end
end)
