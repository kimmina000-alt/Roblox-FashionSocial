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

-- (D-876) the club music this player hears (DanceController's ClubMusic) and
-- how far it runs behind the server's clock, in song seconds
local audioLag = 0
local audioLagFor: string? = nil -- (the song and start it was measured for)
local function musicSound(): Sound?
	local dance = script.Parent:FindFirstChild("DanceController")
	local sound = dance and dance:FindFirstChild("ClubMusic")
	return if sound and sound:IsA("Sound") then sound else nil
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
local following: { soundId: number, tracks: {AnimationTrack}, starts: {number?}, stops: {number?}, blends: {number?}, froms: {number}, playing: AnimationTrack?, speed: number?, home: Vector3?,
	held: boolean?, heldPose: {[Instance]: CFrame}?, unheldAt: number? }? = nil

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
	-- (D-858) a new body (wardrobe, a saved look) builds new joints: read them
	-- again, or every fix would go to joints no longer in the character
	if cached then
		local stale = false
		for _, joint in pairs(cached) do
			if not joint:IsDescendantOf(character) then stale = true break end
		end
		if not stale then return cached end
	end
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
	-- (Studio only: FashionGame attributes ChoreoSmoothingOff / ChoreoRetargetOff compare without them)
	local smooth = ClubConfig.ChoreoSmoothing and not (RunService:IsStudio() and FashionGame:GetAttribute("ChoreoSmoothingOff"))
	local retarget = ClubConfig.ChoreoRetarget and not (RunService:IsStudio() and FashionGame:GetAttribute("ChoreoRetargetOff"))
	if not smooth and not retarget then return end
	local joints = bodyJoints(character)
	for _, t in ipairs(tracks) do
		local id = t.Animation and t.Animation.AnimationId
		local weight = math.min(t.WeightCurrent, 1)
		if id and weight > 0.01 then
			ChoreoSmooth.load(id)
			if smooth then
				for part, joint in pairs(joints) do
					local fix = ChoreoSmooth.correction(id, part, t.TimePosition)
					if fix then
						joint.Transform = joint.Transform * CFrame.identity:Lerp(fix, weight)
					end
				end
				-- (D-848, user: "가슴을 더 앞으로 크게 튕겼으면") chest pops the
				-- capture lost, from ClubConfig.ChoreoFixes
				local waistPop, neckPop = ChoreoSmooth.pop(id, t.TimePosition)
				local w, n = joints.UpperTorso, joints.Head
				if waistPop and w then w.Transform = w.Transform * CFrame.identity:Lerp(waistPop, weight) end
				if neckPop and n then n.Transform = n.Transform * CFrame.identity:Lerp(neckPop, weight) end
			end
			-- (D-843, user: "고개나 세세한 움직임 모두 읽고 넣어 … 덜덜 떨리는 모션
			-- 아니면") the captured spine, chest and clavicles have no joint on an
			-- R15 body, so their turns would be lost: spine + chest go onto the
			-- waist (the upper body, arms and head follow), each clavicle onto
			-- its shoulder ahead of the upper arm's own turn
			if retarget then
				local waist, left, right = ChoreoSmooth.retarget(id, t.TimePosition)
				local w, l, r = joints.UpperTorso, joints.LeftUpperArm, joints.RightUpperArm
				if waist and w then w.Transform = w.Transform * CFrame.identity:Lerp(waist, weight) end
				if left and l then l.Transform = CFrame.identity:Lerp(left, weight) * l.Transform end
				if right and r then r.Transform = CFrame.identity:Lerp(right, weight) * r.Transform end
			end
			-- (D-855, user: ATEEZ 21 "보정") a pose the capture lost (the forearm
			-- across the chest, the head back): those joints are set to it, or
			-- turned by it, easing in and out (after the clavicles, so the set
			-- turn is the whole shoulder)
			if smooth then
				local set, add, amount = ChoreoSmooth.pose(id, t.TimePosition)
				if set and add and amount > 0 then
					for part, target in pairs(set) do
						local j = joints[part]
						if j then j.Transform = j.Transform:Lerp(target, amount * weight) end
					end
					for part, turn in pairs(add) do
						local j = joints[part]
						if j then j.Transform = j.Transform * CFrame.identity:Lerp(turn, amount * weight) end
					end
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
	local stayingAny = false
	for _, t in ipairs(tracks) do
		local id = t.Animation and t.Animation.AnimationId
		local here = id and ChoreoSmooth.hips(id, t.TimePosition)
		if id and not here then ChoreoSmooth.load(id) end
		-- (D-852) ChoreoFixes `still = { from, to }`: the dancer stays put there;
		-- (D-863) or a list of such stretches
		local fixes = id and ChoreoSmooth.fixes(id)
		local still = fixes and fixes.still
		local staying = false
		if still then
			for _, s in ipairs(if still.from then { still } else still) do
				if t.TimePosition >= s.from and t.TimePosition < s.to then staying = true break end
			end
		end
		if staying and t.WeightCurrent > 0.5 then stayingAny = true end
		if here then
			local before = lastHips[t]
			lastHips[t] = here
			-- (a jump in the track's time, e.g. re-synced to the song: no move)
			if before and (here - before).Magnitude < 1.5 and not staying then
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
	-- (D-852: not while a `still` stretch keeps the dancer in place;
	-- D-863, user: "가만히 서 있는데 이동함": only while the dance itself is
	-- travelling, as much as it travels (full at 1 stud a second), so a dancer
	-- standing still never slides)
	local travelling = math.clamp(move.Magnitude * travelScale / math.max(dt, 1e-3), 0, 1)
	if settle and home and not stayingAny and travelling > 0 then
		local away = (root.Position - home) * Vector3.new(1, 0, 1)
		worldMove -= away * math.min(dt / settle, 1) * travelling
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

-- (D-840, user: IVE 2:29-2:30 "뒤도는 거 부드럽게 턴하는 애니메이션으로 수정 (전체
-- 길이랑 춤추는 타이밍은 변경되면 안 됨)") a piece with ClubConfig.ChoreoFixes
-- `turn = seconds` starts facing where the piece before it ended and turns on
-- the way that one was turning, easing into its own facing over that many
-- seconds. A cross-fade between two poses nearly back to back flips the body
-- round in a frame; this sets the hips' facing itself instead.
local turnFixes: {[string]: { prev: string, seconds: number, easeOut: boolean }} = {}
for _, t in ipairs(ClubConfig.Playlist) do
	local before: string? = nil
	for _, entry in ipairs(t.choreo or {}) do
		local id = "rbxassetid://" .. tostring(if typeof(entry) == "table" then entry.id else entry)
		local fixes = ClubConfig.ChoreoFixes and ClubConfig.ChoreoFixes[tonumber(id:match("%d+")) or 0]
		if fixes and fixes.turn and before then turnFixes[id] = { prev = before, seconds = fixes.turn, easeOut = fixes.turnEase == "out" } end
		before = id
	end
end

local spinWait: {[AnimationTrack]: number} = setmetatable({}, { __mode = "k" }) :: any
local function turnHips(joint: Motor6D | AnimationConstraint, tracks: {AnimationTrack})
	-- (Studio only: ChoreoSmoothingOff compares without the spot fixes too)
	if RunService:IsStudio() and FashionGame:GetAttribute("ChoreoSmoothingOff") then return end
	for _, t in ipairs(tracks) do
		local id = t.Animation and t.Animation.AnimationId
		-- (D-852, user: NEON 1:22 "한 바퀴 도는 게 매끄럽지 않음") ChoreoFixes
		-- `spin = { from, to }`: a spin in the capture that lurches (NEON 7 turns
		-- 94° in one keyframe, then slows) turns evenly instead, starting
		-- gently and ending at full speed, from its facing at `from` to `to`
		-- (only while that piece plays alone: the next one's `turn` takes over)
		local spin = id and t.WeightCurrent > 0.99 and ChoreoSmooth.fixes(id)
		spin = spin and spin.spin
		-- (a piece waits on its last pose until the next one starts, D-798: the
		-- spin keeps going with the clock meanwhile, so it does not stall)
		local at = t.TimePosition
		if spin and at >= t.Length - 0.06 and FashionGame:GetAttribute("ClubMusicPaused") ~= true then
			spinWait[t] = spinWait[t] or os.clock()
			at += os.clock() - spinWait[t]
		else
			spinWait[t] = nil
		end
		if spin and at >= spin.from and at <= spin.to + 0.1 then
			local a, b = ChoreoSmooth.facing(id, spin.from), ChoreoSmooth.facing(id, spin.to)
			if a and b then
				-- (D-873) `turns`: whole turns to add, for a capture that turned
				-- half way and back where the dancer spins all the way round;
				-- ease = "both" starts and ends gently
				b += (spin.turns or 0) * 2 * math.pi
				local f = math.min((at - spin.from) / (spin.to - spin.from), 1)
				local yaw = a + (b - a) * (if spin.ease == "both" then f * f * (3 - 2 * f) else f * f * (2 - f))
				local tilt, _, roll = joint.Transform:ToEulerAnglesYXZ()
				joint.Transform = CFrame.new(joint.Transform.Position) * CFrame.fromEulerAnglesYXZ(tilt, yaw, roll)
			end
			return
		end
		local fix = id and turnFixes[id]
		if id and fix and t.WeightCurrent > 0.01 and t.TimePosition < fix.seconds then
			ChoreoSmooth.load(fix.prev)
			local fromYaw, dir = ChoreoSmooth.endFacing(fix.prev)
			local startYaw = ChoreoSmooth.facing(id, 0)
			local nowYaw = ChoreoSmooth.facing(id, t.TimePosition)
			if fromYaw and startYaw and nowYaw then
				-- the turn still to make, the way the piece before was turning
				local gap = (startYaw - fromYaw) % (2 * math.pi)
				if dir < 0 then gap -= 2 * math.pi end
				local f = math.clamp(t.TimePosition / fix.seconds, 0, 1)
				-- (D-852) turnEase "out": the piece before was still spinning, so
				-- carry on at its speed and slow down (no stop at the seam)
				local eased = if fix.easeOut then f * (2 - f) else f * f * (3 - 2 * f)
				local yaw = fromYaw + gap * eased + (nowYaw - startYaw)
				local tilt, _, roll = joint.Transform:ToEulerAnglesYXZ()
				joint.Transform = CFrame.new(joint.Transform.Position) * CFrame.fromEulerAnglesYXZ(tilt, yaw, roll)
			end
			return
		end
	end
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
				turnHips(joint, choreo)
				local hips = joint.Transform
				joint.Transform = CFrame.new(0, hips.Y, 0) * hips.Rotation
				-- (D-852) a `hold` keeps one pose; when it lets go the body eases
				-- from that pose into the dance again over 0.25 s instead of snapping
				if p == player and following then
					local joints = bodyJoints(character)
					if following.held then
						local pose = {}
						for _, j in pairs(joints) do pose[j] = j.Transform end
						following.heldPose = pose
					elseif following.unheldAt and following.heldPose then
						local f = (os.clock() - following.unheldAt) / 0.25
						if f >= 1 then
							following.unheldAt, following.heldPose = nil, nil
						else
							f = f * f * (3 - 2 * f)
							for _, j in pairs(joints) do
								local from = following.heldPose[j]
								if from then j.Transform = from:Lerp(j.Transform, f) end
							end
						end
					end
				end
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
	player:SetAttribute("ChoreoFollowing", nil) -- (the banner's 🎵, ClubQuickBar)
end

-- (D-839, user) the menu dance the player was doing when the choreography
-- took over: the 🎵 in the banner gives it back (key, speed, or the player
-- they were dancing with)
local previousDance: { key: string?, speed: number?, joined: number? }? = nil
local menuStopAt = 0 -- (when the choreography stopped a menu dance)
local function rememberDance()
	local character = player.Character
	local key = character and character:GetAttribute("DanceKey")
	if not character or key == nil then previousDance = nil return end
	local joined = character:GetAttribute("DanceJoined")
	previousDance = {
		key = key,
		speed = character:GetAttribute("DanceSpeed"),
		joined = if typeof(joined) == "number" then joined else nil,
	}
end
local function restoreDance()
	local dance = previousDance
	previousDance = nil
	if not dance then return end
	if dance.joined and Players:GetPlayerByUserId(dance.joined) then
		danceRemote:FireServer("Join", dance.joined)
	elseif dance.key then
		danceRemote:FireServer("Start", dance.key, dance.speed or 1)
	end
end

local function startFollowing(track: ClubConfig.Track)
	local anim = animator()
	if not anim or not track.choreo then return end
	-- (the dance menu's dance stops first: one dance at a time)
	local character = player.Character
	if character and character:GetAttribute("DanceKey") ~= nil then
		danceRemote:FireServer("Stop")
		menuStopAt = os.clock() -- (D-839: its DanceKey stays a moment, until the server clears it)
	end
	local tracks, starts, stops, blends, froms, slowIns, slowOuts = {}, {}, {}, {}, {}, {}, {}
	for _, entry in ipairs(track.choreo) do
		local id = if typeof(entry) == "table" then entry.id else entry
		local at = if typeof(entry) == "table" and typeof(entry.at) == "number" then entry.at else nil
		local stop = if typeof(entry) == "table" and typeof(entry.stop) == "number" then entry.stop else nil
		local blend = if typeof(entry) == "table" and typeof(entry.blend) == "number" then entry.blend else nil
		local from = if typeof(entry) == "table" and typeof(entry.from) == "number" then entry.from else 0
		local slowIn = if typeof(entry) == "table" and typeof(entry.slowIn) == "table" then entry.slowIn else nil
		local slowOut = if typeof(entry) == "table" and typeof(entry.slowOut) == "table" then entry.slowOut else nil
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
			slowIns[#tracks] = slowIn
			slowOuts[#tracks] = slowOut
		else
			warn("[ChoreoController] Could not load", id, loaded)
		end
	end
	if #tracks == 0 then return end
	holdCamera()
	following = { soundId = track.soundId, tracks = tracks, starts = starts, stops = stops, blends = blends, froms = froms,
		slowIns = slowIns, slowOuts = slowOuts, playing = nil, speed = nil }
	button.Text = "⏹ 그만 추기"
	player:SetAttribute("ChoreoFollowing", true)
end

-- (D-839, user) per song: "auto" follows a choreography song from its start
-- when 안무 자동 따라하기 is on (LocalPlayer attribute ChoreoAuto, on unless
-- false; the dance window's switch), even over a menu dance (given back by the
-- 🎵); the 🎵 stops it for the rest of the song ("optOut") or starts it by
-- hand ("manual"); choosing a menu dance mid-song also opts out
local songKey: string? = nil
local songAuto = false -- (this song may still start by itself over a menu dance)
local optOut = false
local manual = false
local function autoOn(): boolean
	return player:GetAttribute("ChoreoAuto") ~= false
end

local function tap()
	local track = playingTrack()
	if following then
		stopFollowing()
		optOut, manual = true, false
		restoreDance()
		return
	end
	if track and track.choreo and inClub() then
		optOut, manual = false, true
		rememberDance()
		startFollowing(track)
	end
end
button.Activated:Connect(tap)
require(script.Parent:WaitForChild("UiBus")).ChoreoTap.Event:Connect(tap)
player:GetAttributeChangedSignal("ChoreoAuto"):Connect(function()
	-- switched off: a dance it started stops; switched on: this song may start again
	if not autoOn() and following and not manual then
		stopFollowing()
		restoreDance()
	elseif autoOn() then
		optOut = false
	end
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
	-- (D-839) a new song: its own choices
	local key = if track then tostring(track.soundId) .. ":" .. tostring(FashionGame:GetAttribute("ClubTrackStart")) else nil
	if key ~= songKey then
		songKey = key
		optOut, manual = false, false
		songAuto = true
		previousDance = nil
	end
	-- (D-726) standing still in the club starts the song's choreography;
	-- (D-839, user) for every song with one, by itself while 안무 자동 따라하기
	-- is on (from the song's start even over a menu dance, given back by the
	-- 🎵), or after the 🎵 was tapped for this song
	local wanted = not optOut and (manual or autoOn())
	local dancing = character ~= nil and (character :: Model):GetAttribute("DanceKey") ~= nil
	if not following and wanted and track and track.choreo and here and humanoid
		and humanoid.MoveDirection.Magnitude <= 0.1 and not humanoid.Sit and not humanoid.PlatformStand
		and (not dancing or (songAuto and autoOn()))
		and not player:GetAttribute("Carrying") and not player:GetAttribute("CarriedBy") then -- (a guard's carry, D-738)
		if dancing then rememberDance() end
		songAuto = false
		startFollowing(track)
	end
	if not following then return end
	if (character :: Model):GetAttribute("DanceKey") ~= nil and os.clock() - menuStopAt > 2 then
		-- a dance from the menu now: it wins for the rest of this song
		stopFollowing()
		optOut, previousDance = true, nil
		return
	end
	if not track or track.soundId ~= following.soundId or not here or not humanoid
		or humanoid.MoveDirection.Magnitude > 0.1
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
	-- (D-876) where the song is, in the original song's seconds (the clock
	-- the pieces were cut on): the audio's place times its file speed, so a
	-- lab tempo set by ear or the DJ's speed moves the dance with the music,
	-- and the dance plays at that same rate
	local songRate = ClubConfig.songRate(track, FashionGame:GetAttribute("ClubMusicSpeed"))
	local paused = FashionGame:GetAttribute("ClubMusicPaused") == true
	local start = attr("ClubTrackStart", workspace:GetServerTimeNow())
	local songTime = if paused
		then attr("ClubMusicPausedAt", 0) * ClubConfig.fileSpeed(track)
		else (workspace:GetServerTimeNow() - start) * songRate
	-- (D-876) and where this player's audio really is: it starts a moment
	-- late (about 0.1 s in Studio, more on a slow phone) and never re-seeks,
	-- so the dance follows the heard music (smoothed: TimePosition moves in
	-- steps), snapping only after a seek
	local music = musicSound()
	-- where this player's audio really is: ClubMusic's place, or for a joined
	-- song the place its clips report on ClubMusic (DanceController)
	local heardAt: number? = nil
	if music and music:GetAttribute("JoinedPlaying") == true and ClubConfig.isJoined(track) then
		local jt = music:GetAttribute("JoinedTime")
		if typeof(jt) == "number" and jt > 0.05 then heardAt = jt end
	elseif music and music.IsPlaying and music.TimePosition > 0.05 and music.SoundId == "rbxassetid://" .. tostring(track.soundId) then
		heardAt = music.TimePosition
	end
	if not paused and heardAt then
		local heard = heardAt * ClubConfig.fileSpeed(track) - songTime
		if math.abs(heard) < 3 then
			-- (D-878) a new song or seek starts from its first reading, not from 0
			local key = tostring(track.soundId) .. ":" .. tostring(start)
			if audioLagFor ~= key or math.abs(heard - audioLag) > 0.5 then audioLag = heard else audioLag += (heard - audioLag) * 0.05 end
			audioLagFor = key
		end
		songTime += audioLag
	end
	-- which segment that is (lengths known once each one has loaded); a gap
	-- between segments (an `at` later than the one before ends) stands still;
	-- t = the time in the animation (a `from` skips its start, D-810)
	local t, index, rate = 0, nil :: number?, 1
	local segStart = 0
	for i, seg in ipairs(following.tracks) do
		if seg.Length <= 0 then return end -- (still loading)
		local from = following.froms[i]
		local span = math.max(seg.Length - from, 0)
		-- (D-875, user: "1:11 그냥 멈추지 말고 앞뒤 프레임을 느리게 재생") an entry's
		-- `slowIn = { seconds, extra }` plays its first `seconds` over `extra`
		-- more, starting that much before its `at`; `slowOut` its last ones,
		-- ending that much later: a gap filled with slower dancing, not a stop
		local slowIn, slowOut = following.slowIns[i], following.slowOuts[i]
		local inLen, inExtra = if slowIn then math.min(slowIn[1], span) else 0, if slowIn then slowIn[2] else 0
		local outLen, outExtra = if slowOut then math.min(slowOut[1], span - inLen) else 0, if slowOut then slowOut[2] else 0
		segStart = (following.starts[i] or segStart) - inExtra
		local songSpan = span + inExtra + outExtra
		local segEnd = math.min(segStart + songSpan, following.stops[i] or math.huge)
		-- (D-861) a short gap before the next piece's `at` (captures run a
		-- little shorter than their clips) keeps this piece's last pose
		-- instead of dropping to the idle pose for a moment
		local nextAt = following.starts[i + 1]
		if nextAt and following.slowIns[i + 1] then nextAt -= following.slowIns[i + 1][2] end
		local holdEnd = if nextAt and nextAt > segEnd and nextAt - segEnd <= 1.5 and not following.stops[i] then nextAt else segEnd
		if songTime >= segStart and songTime < holdEnd then
			index = i
			local u = songTime - segStart
			if u < inLen + inExtra then
				rate = inLen / (inLen + inExtra)
				t = u * rate
			else
				t = u - inExtra
				local outFrom = span - outLen
				if outLen > 0 and t > outFrom then
					rate = outLen / (outLen + outExtra)
					t = outFrom + (t - outFrom) * rate
				end
			end
			t = math.min(t, span - 0.03) + from
			break
		end
		segStart += songSpan
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
	-- (D-852, user: NEON 5-6 s "처음 나오는 자세에서 두 번째 나오는 같은 자세
	-- 끝날 때까지 고정") ChoreoFixes `hold = { from, to }`: the pose at `from`
	-- stays until `to`, then the dance goes on from `to` (the song's timing
	-- is kept; PreSimulation eases out of the held pose)
	local fixes = ChoreoSmooth.fixes(seg.Animation.AnimationId)
	-- (D-884) or a list of such stretches
	local held = false
	local holds = fixes and fixes.hold
	if holds then
		for _, hold in ipairs(if holds.from then { holds } else holds) do
			if t >= hold.from and t < hold.to then held = true t = hold.from break end
		end
	end
	if following.held and not held then following.unheldAt = os.clock() end
	following.held = held
	if following.playing ~= seg then
		-- (D-807) the last pose eases into the first one over the entry's
		-- `blend`, longer where they differ more (tools/choreo/choreo_check.lua)
		local blend = following.blends[index] or 0.25
		if following.playing then following.playing:Stop(blend) end
		seg:Play(blend)
		following.playing = seg
		following.speed = nil
		seg.TimePosition = t
	elseif math.abs(seg.TimePosition - t) > (if held then 0.01 else 0.3) then
		seg.TimePosition = t
	end
	-- (D-798) a segment a moment ahead of the song holds its last pose
	-- instead of ending (and fading back to the root) before the next one
	local speed = if paused or held or seg.TimePosition >= seg.Length - 0.05 then 0 else songRate * rate
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
