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
	held: boolean?, heldPose: {[Instance]: CFrame}?, unheldAt: number?, homeCfg: any?, glided: boolean? }? = nil

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
				local set, add, amount, fade = ChoreoSmooth.pose(id, t.TimePosition)
				if set and add and amount > 0 then
					for part, target in pairs(set) do
						local j = joints[part]
						if j then j.Transform = j.Transform:Lerp(target, amount * weight * (if fade and fade[part] then fade[part] else 1)) end
					end
					for part, turn in pairs(add) do
						local j = joints[part]
						if j then j.Transform = j.Transform * CFrame.identity:Lerp(turn, amount * weight) end
					end
				end
				-- (D-976, user: Lemonade 0:22 "왼쪽 팔 돌리는 거 더 크게 돌리기")
				-- ChoreoFixes `amp = { { from, to, ease, parts = { Name = factor } } }`:
				-- those joints turn `factor` times as far as the capture has them
				-- (easing in and out), so a small move shows bigger
				local fx = ChoreoSmooth.fixes(id)
				local amps = fx and fx.amp
				if amps then
					for _, a in ipairs(if amps.from then { amps } else amps) do
						local tt = t.TimePosition
						if tt > a.from and tt < a.to then
							local e = math.clamp(math.min(tt - a.from, a.to - tt) / (a.ease or 0.3), 0, 1)
							e = e * e * (3 - 2 * e) * weight
							for part, factor in pairs(a.parts) do
								local j = joints[part]
								if j then
									local axis, angle = j.Transform:ToAxisAngle()
									j.Transform = CFrame.new(j.Transform.Position) * CFrame.fromAxisAngle(axis, angle * (1 + (factor - 1) * e))
								end
							end
						end
					end
				end
				do
					-- (D-986, user: Catch Catch 0:35 "다리는 수직 유지하고 상체만 숙이기")
					-- ChoreoFixes `upright = { from, to, ease? }`: the hips stay level
					-- there (their turn round kept) and their lean goes to the waist,
					-- so the legs stand straight and only the upper body bends
					local ups = fx and fx.upright
					local lt, ut = joints.LowerTorso, joints.UpperTorso
					if ups and lt and ut then
						for _, u in ipairs(if ups.from then { ups } else ups) do
							local tt = t.TimePosition
							if tt > u.from and tt < u.to then
								local e = math.clamp(math.min(tt - u.from, u.to - tt) / (u.ease or 0.3), 0, 1)
								e = e * e * (3 - 2 * e) * weight
								local hips = lt.Transform
								local r = hips.RightVector
								local level = CFrame.new(hips.Position) * CFrame.Angles(0, math.atan2(-r.Z, r.X), 0)
								local shown = hips:Lerp(level, e)
								lt.Transform = shown
								ut.Transform = (shown.Rotation:Inverse() * hips.Rotation) * ut.Transform
							end
						end
					end
					-- (the upright / torsoUp blocks sat inside `if amps then` until D-992: they only
					-- ran on pieces that also had `amp`)
					-- (D-992, user: Lemonade 1:38 "상체 일자로 세워. 수직으로", 2:23 "앉아 있는
					-- 자세에서 상체 수직으로") ChoreoFixes `torsoUp = { from, to, ease? }`: the
					-- upper body stands straight up there whatever the hips do (it keeps
					-- facing the way the hips face)
					local tups = fx and fx.torsoUp
					if tups and lt and ut then
						for _, u in ipairs(if tups.from then { tups } else tups) do
							local tt = t.TimePosition
							if tt > u.from and tt < u.to then
								local e = math.clamp(math.min(tt - u.from, u.to - tt) / (u.ease or 0.3), 0, 1)
								e = e * e * (3 - 2 * e) * weight
								local hips = lt.Transform
								local r = hips.RightVector
								local want = hips.Rotation:Inverse() * CFrame.Angles(0, math.atan2(-r.Z, r.X), 0)
								ut.Transform = ut.Transform:Lerp(CFrame.new(ut.Transform.Position) * want, e)
							end
						end
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
			-- (D-962) a `warp` or a `hold` letting go jumped the piece to another
			-- moment: no travel for that jump
			if following.seeked then before = nil end
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
	following.seeked = nil
	local worldMove = root.CFrame:VectorToWorldSpace(move * travelScale)
	-- (D-817, user: "쏠림만 빼기 … 이걸로 한번 보자") the pieces add up to a
	-- drift one way (Get A Guitar: about 30 studs over the song), so the dancer
	-- is eased back toward where the dance began, slowly (ChoreoDriftReturn
	-- seconds): a few seconds of travel inside a piece still shows, the
	-- build-up over the song does not
	-- (D-992, user: "안무 추면서 이동해도 결국 처음 서 있던 위치를 중심으로 두고 끝나면
	-- 돌아오게") a song with `home = { settle, back }` eases back faster (`settle` s)
	local settle = (following.homeCfg and following.homeCfg.settle) or ClubConfig.ChoreoDriftReturn
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
	-- (D-966, user: "캐릭터 위치 갑자기 이동하면 이상해 보임 … 1 스터드도 티 날 것
	-- 같아") a capture's hips that dash (13 stud/s in a frame, NEON 0:49 / 0:55)
	-- move the body at most 8 stud/s; the rest follows over the next frames
	following.moveDebt = (following.moveDebt or Vector3.zero) + worldMove
	local most = 8 * dt
	worldMove = if following.moveDebt.Magnitude > most then following.moveDebt.Unit * most else following.moveDebt
	following.moveDebt -= worldMove
	if following.moveDebt.Magnitude > 3 then following.moveDebt = Vector3.zero end -- (not a backlog)
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
local prevPiece: {[string]: string} = {} -- (D-962, spin `fromPrev`)
for _, t in ipairs(ClubConfig.Playlist) do
	local before: string? = nil
	for _, entry in ipairs(t.choreo or {}) do
		local id = "rbxassetid://" .. tostring(if typeof(entry) == "table" then entry.id else entry)
		local fixes = ClubConfig.ChoreoFixes and ClubConfig.ChoreoFixes[tonumber(id:match("%d+")) or 0]
		if fixes and fixes.turn and before then turnFixes[id] = { prev = before, seconds = fixes.turn, easeOut = fixes.turnEase == "out" } end
		if before and before ~= id then prevPiece[id] = before end
		before = id
	end
end

local spinWait: {[AnimationTrack]: number} = setmetatable({}, { __mode = "k" }) :: any
local spinFrom: {[AnimationTrack]: number} = setmetatable({}, { __mode = "k" }) :: any -- (D-973)
local spinMemory: {[any]: { yaw: number, id: string, at: number }} = setmetatable({}, { __mode = "k" }) :: any
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
		local spins = id and t.WeightCurrent > 0.01 and ChoreoSmooth.fixes(id)
		spins = spins and spins.spin
		-- (a piece waits on its last pose until the next one starts, D-798: the
		-- spin keeps going with the clock meanwhile, so it does not stall)
		local at = t.TimePosition
		if spins and at >= t.Length - 0.06 and FashionGame:GetAttribute("ClubMusicPaused") ~= true then
			spinWait[t] = spinWait[t] or os.clock()
			at += os.clock() - spinWait[t]
		else
			spinWait[t] = nil
		end
		-- (D-962) a list of spins; `fromPrev` starts from where the piece before
		-- ended (a spin over the seam), even while the two still blend
		local spin = nil
		if spins then
			for _, s in ipairs(if spins.from then { spins } else spins) do
				-- (D-973) `till`: keep the end facing until then (the next piece
				-- takes the turn on a moment later: heard-song lag, Pretty Girl
				-- 0:36 turned 24° back in the 0.15 s between)
				if at >= s.from and at <= (s.till or s.to + 0.1) and (t.WeightCurrent > 0.99 or s.fromPrev) then spin = s break end
			end
		end
		if spin then
			local a, b = ChoreoSmooth.facing(id, spin.from), ChoreoSmooth.facing(id, spin.to)
			if spin.fromPrev and prevPiece[id] then
				-- (D-973) from where the spin of the piece before left the hips,
				-- when it was one (that facing is its own plus `add`), else from
				-- that piece's last facing; read once when this spin begins
				local from = spinFrom[t]
				if not from then
					local memory = spinMemory[joint]
					if memory and memory.id == prevPiece[id] and os.clock() - memory.at < 0.5 then
						from = memory.yaw
					else
						ChoreoSmooth.load(prevPiece[id])
						from = ChoreoSmooth.endFacing(prevPiece[id])
					end
					spinFrom[t] = from
				end
				a = from
				-- (the two pieces count their turns apart: the way round is
				-- `dir`, +1 or -1, plus `turns`)
				if a and b then
					local d = (b - a) % (2 * math.pi)
					if spin.dir and spin.dir < 0 then d -= 2 * math.pi end
					b = a + d
				end
			end
			if a and b then
				-- (D-873) `turns`: whole turns to add, for a capture that turned
				-- half way and back where the dancer spins all the way round;
				-- (D-973) `add` degrees more, for a piece whose turn the next
				-- piece's capture finishes (Pretty Girl 0:36);
				-- ease = "both" starts and ends gently, "linear" keeps one speed,
				-- "out" starts at full speed and slows (to carry a turn on), the
				-- default starts gently and ends at full speed
				b += (spin.turns or 0) * 2 * math.pi + math.rad(spin.add or 0)
				local f = math.min((at - spin.from) / (spin.to - spin.from), 1)
				local e = if spin.ease == "both" then f * f * (3 - 2 * f)
					elseif spin.ease == "linear" then f
					elseif spin.ease == "out" then f * (2 - f)
					else f * f * (2 - f)
				local yaw = a + (b - a) * e
				local tilt, _, roll = joint.Transform:ToEulerAnglesYXZ()
				joint.Transform = CFrame.new(joint.Transform.Position) * CFrame.fromEulerAnglesYXZ(tilt, yaw, roll)
				spinMemory[joint] = { yaw = yaw, id = id, at = os.clock() }
			end
			return
		end
		spinFrom[t] = nil
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

-- (D-966, user: "모든 안무에서 프레임 뚝뚝 끊기는 부분들 부드럽게 … 액션 크고
-- 확실하게") a joint that jumps in one frame (a capture keyframe gap, a seam,
-- a fix stepping in) far faster than it has been moving is carried over a
-- few frames instead: each frame a joint may turn at most max(360°/s, 1.6x
-- its speed of the last ~0.1 s) and move max(6, 1.6x) stud/s, and what is
-- left over comes in the next frames. A move that speeds up over a few
-- frames passes as it is (the limit rises with it) and every move still
-- reaches its full pose, so actions keep their size. ChoreoFixes `sharp`
-- turns it off for a piece (BAD 21's chest pops are meant to snap).
-- (NEON 0:48: an upper arm 34° in one frame among 11° ones passed at 2.5x)
local SNAP_TURN, SNAP_MOVE, SNAP_FACTOR = math.rad(360), 6, 1.6
local snapState: {[Model]: {[any]: { cf: CFrame, turn: number, move: number }}} = setmetatable({}, { __mode = "k" }) :: any
local function limitSnaps(character: Model, choreo: {AnimationTrack}, dt: number)
	if RunService:IsStudio() and FashionGame:GetAttribute("ChoreoSnapOff") then snapState[character] = nil return end
	for _, t in ipairs(choreo) do
		local fixes = t.WeightCurrent > 0.5 and t.Animation and ChoreoSmooth.fixes(t.Animation.AnimationId)
		if fixes and fixes.sharp then snapState[character] = nil return end
	end
	dt = math.max(dt, 1 / 240)
	local state = snapState[character]
	if not state then state = {} snapState[character] = state end
	for _, j in pairs(bodyJoints(character)) do
		local target = j.Transform
		local s = state[j]
		if not s then
			state[j] = { cf = target, turn = 0, move = 0 }
		else
			local _, angle = (s.cf:Inverse() * target):ToAxisAngle()
			local turn = math.abs(angle) / dt
			local move = (target.Position - s.cf.Position).Magnitude / dt
			local turnLimit = math.max(SNAP_TURN, s.turn * SNAP_FACTOR)
			local moveLimit = math.max(SNAP_MOVE, s.move * SNAP_FACTOR)
			local f = 1
			if turn > turnLimit then f = turnLimit / turn end
			if move > moveLimit then f = math.min(f, moveLimit / move) end
			local shown = if f < 1 then s.cf:Lerp(target, f) else target
			j.Transform = shown
			-- (the speed shown, over about 0.1 s)
			local k = math.min(dt * 10, 1)
			s.turn += (math.min(turn, turnLimit) - s.turn) * k
			s.move += (math.min(move, moveLimit) - s.move) * k
			s.cf = shown
		end
	end
end

-- (D-992) per character, per `freeze` stretch: the pose kept
local frozenPoses: {[Model]: {[any]: {[string]: CFrame}}} = setmetatable({}, { __mode = "k" }) :: any

-- (D-995, user: 갑자기 2:05 "땅 밑으로 내려감 / 모든 안무 땅 뚫고 내려가면 안 됨") after each
-- frame the lowest point of a dancing body is compared with the floor under it;
-- whatever went below it lifts the hips by that much from the next frame on
-- (at once going up, easing back down when there is room again)
local floorLift: {[Model]: number} = setmetatable({}, { __mode = "k" }) :: any
local floorCache: {[Model]: { y: number, at: number }} = setmetatable({}, { __mode = "k" }) :: any
local LOW_PARTS = { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg",
	"LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LowerTorso", "UpperTorso", "Head" }
local dancingNow: {[Model]: boolean} = setmetatable({}, { __mode = "k" }) :: any
RunService.Heartbeat:Connect(function()
	for character in pairs(dancingNow) do
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not character.Parent then dancingNow[character] = nil continue end
		local cached = floorCache[character]
		if not cached or os.clock() - cached.at > 0.25 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local skip = {}
			for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
			params.FilterDescendantsInstances = skip
			params.RespectCanCollide = true
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params)
			cached = { y = if hit then hit.Position.Y else -math.huge, at = os.clock() }
			floorCache[character] = cached
		end
		local low = math.huge
		for _, name in ipairs(LOW_PARTS) do
			local part = character:FindFirstChild(name) :: BasePart?
			if part then
				local cf, size = part.CFrame, part.Size
				local half = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
				low = math.min(low, part.Position.Y - half)
			end
		end
		local lift = floorLift[character] or 0
		local target = math.max(0, lift + (cached.y - 0.05) - low)
		if target > lift then lift = target else lift += (target - lift) * 0.12 end
		floorLift[character] = if lift < 0.005 then nil else lift
	end
end)

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
				-- (D-985, user: Catch Catch "전체적으로 좌우 반전") a `mirror` song: the
				-- animator's pose seen in a mirror (each joint takes the other side's
				-- turn, mirrored); ChoreoSmooth reads its keyframes mirrored too
				local first = choreo[1].Animation
				if first and ChoreoSmooth.isMirrored(first.AnimationId) then
					local joints = bodyJoints(character)
					local poses = {}
					for part, j in pairs(joints) do poses[part] = j.Transform end
					for part, j in pairs(joints) do
						local other = poses[ChoreoSmooth.otherSide(part)]
						if other then j.Transform = ChoreoSmooth.mirrorPose(other) end
					end
				end
				if p == player and following then moveAlong(character, joint, choreo, dt) end
				smoothJoints(character, choreo)
				turnHips(joint, choreo)
				local hips = joint.Transform
				-- (D-995) lifted off the floor if the body went into it last frame
				dancingNow[character] = true
				joint.Transform = CFrame.new(0, hips.Y + (floorLift[character] or 0), 0) * hips.Rotation
				-- (D-992, user: Lemonade 2:17 "자세를 기본으로 누운 다음, 다른 곳 움직이지
				-- 말고 왼쪽 다리만 쭉 뻗는 걸로") ChoreoFixes `freeze = { from, to, ease?,
				-- except = { parts } }`: the pose at `from` is kept for every joint but
				-- `except` (which go on, with their `pose` keys) until `to`
				do
					local joints = bodyJoints(character)
					local store = frozenPoses[character]
					if not store then store = {} frozenPoses[character] = store end
					for _, t in ipairs(choreo) do
						local fx = t.Animation and ChoreoSmooth.fixes(t.Animation.AnimationId)
						local fz = fx and fx.freeze
						if fz and t.WeightCurrent > 0.5 then
							for _, f in ipairs(if fz.from then { fz } else fz) do
								local tt = t.TimePosition
								if tt >= f.from and tt < f.to then
									local pose = store[f]
									if not pose then
										pose = {}
										for part, j in pairs(joints) do pose[part] = j.Transform end
										store[f] = pose
									end
									local e = math.clamp(math.min(tt - f.from, f.to - tt) / (f.ease or 0.3), 0, 1)
									e = e * e * (3 - 2 * e)
									for part, j in pairs(joints) do
										if pose[part] and not (f.except and table.find(f.except, part)) then
											j.Transform = j.Transform:Lerp(pose[part], e)
										end
									end
								else
									store[f] = nil
								end
							end
						end
					end
				end
				-- (D-852) a `hold` keeps one pose; when it lets go the body eases
				-- from that pose into the dance again over 0.25 s instead of snapping
				if p == player and following then
					local joints = bodyJoints(character)
					if following.held then
						local pose = {}
						for _, j in pairs(joints) do pose[j] = j.Transform end
						following.heldPose = pose
					elseif following.unheldAt and following.heldPose then
						-- (D-962) `hold.ease` / `warp.ease` seconds, 0.25 if not given
						local f = (os.clock() - following.unheldAt) / (following.easeSeconds or 0.25)
						if f >= 1 then
							following.unheldAt, following.heldPose, following.easeSeconds = nil, nil, nil
						else
							f = f * f * (3 - 2 * f)
							for _, j in pairs(joints) do
								local from = following.heldPose[j]
								if from then j.Transform = from:Lerp(j.Transform, f) end
							end
						end
					end
					-- (D-962) the pose drawn this frame, to ease from when a `warp`
					-- makes the piece jump to another moment
					local last = {}
					for _, j in pairs(joints) do last[j] = j.Transform end
					following.lastPose = last
				end
				limitSnaps(character, choreo, dt)
			else
				snapState[character] = nil
				dancingNow[character] = nil
				floorLift[character] = nil
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

-- (D-992) a `home` song: when its dance ends, the dancer glides back to where
-- it began over `back` seconds (stops if the player walks)
local function glideHome()
	local cfg = following and following.homeCfg
	local home = following and following.home
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not cfg or not home or not root or not humanoid or following.glided then return end
	following.glided = true
	local from = root.Position
	local away = Vector3.new(home.X - from.X, 0, home.Z - from.Z)
	if away.Magnitude < 0.2 or away.Magnitude > 20 then return end
	task.spawn(function()
		local seconds = cfg.back or 1.5
		local t0, done = os.clock(), 0
		while os.clock() - t0 < seconds do
			RunService.Heartbeat:Wait()
			if humanoid.MoveDirection.Magnitude > 0.1 or not root.Parent then return end
			local f = math.clamp((os.clock() - t0) / seconds, 0, 1)
			f = f * f * (3 - 2 * f)
			root.CFrame += away * (f - done)
			done = f
		end
	end)
end

local function stopFollowing()
	if not following then return end
	glideHome()
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
		-- (D-962) read every piece's path now: a spin or turn over a seam needs
		-- the next piece's facing the moment it starts (it took about 0.4 s)
		ChoreoSmooth.load(animation.AnimationId)
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
		slowIns = slowIns, slowOuts = slowOuts, playing = nil, speed = nil, homeCfg = (track :: any).home }
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
			-- (D-992) past the last piece: back to where the dance began
			local lastAt = following.starts[#following.tracks]
			if lastAt and songTime > lastAt then glideHome() end
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
			if t >= hold.from and t < hold.to then held = true t = hold.from following.holdEase = hold.ease break end
		end
	end
	-- (D-962, user: NEON 0:04 "팔 내리면서 뒤도는 거 슬로우 걸어서 자연스럽게
	-- 이어지게", Get A Guitar 1:38 / 1:52 slower knee and leg moves without the
	-- dance falling behind) ChoreoFixes `warp = { { from, to, play = { a, b } } }`:
	-- the stretch from..to of the piece's own clock plays the animation's a..b
	-- instead (slower or faster); a stretch that starts somewhere else eases
	-- in from the last pose over `ease` seconds
	local warps = not held and fixes and fixes.warp
	local warpedBy = nil
	if warps then
		for _, w in ipairs(if warps.from then { warps } else warps) do
			if t >= w.from and t < w.to then
				local k = (w.play[2] - w.play[1]) / (w.to - w.from)
				t = w.play[1] + (t - w.from) * k
				rate *= k
				warpedBy = w
				break
			end
		end
	end
	local forceSeek = false
	if following.warpedBy ~= warpedBy then
		-- (a jump to another moment of the animation eases from the pose drawn)
		local jump = following.playing == seg and math.abs(seg.TimePosition - t) > 0.1
		forceSeek = following.playing == seg
		if jump then following.seeked = true end
		if jump and following.lastPose then
			following.heldPose = following.lastPose
			following.unheldAt = os.clock()
			following.easeSeconds = (warpedBy and warpedBy.ease) or (following.warpedBy and following.warpedBy.ease) or 0.25
		end
		following.warpedBy = warpedBy
	end
	if following.held and not held then
		following.unheldAt = os.clock()
		following.easeSeconds = following.holdEase
		following.seeked = true
	end
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
	elseif forceSeek or math.abs(seg.TimePosition - t) > (if held then 0.01 else 0.3) then
		seg.TimePosition = t
	end
	-- (D-798) a segment a moment ahead of the song holds its last pose
	-- instead of ending (and fading back to the root) before the next one
	local speed = if paused or held or seg.TimePosition >= seg.Length - 0.05 then 0 else songRate * rate
	-- (D-992, user: Lemonade 1:25 / Catch Catch 2:06 "잠깐 멈추는 구간") a piece drifted up
	-- to 0.3 s ahead of the song before it was put back, so it ran out early and
	-- stood still until the next one: its speed now leans toward the song clock
	if speed > 0 then speed *= 1 + math.clamp((t - seg.TimePosition) * 2, -0.3, 0.3) end
	if following.speed == nil or math.abs(following.speed - speed) > 0.01 or (speed == 0) ~= (following.speed == 0) then
		seg:AdjustSpeed(speed)
		following.speed = speed
	end
end)

player.CharacterAdded:Connect(function()
	following = nil
	button.Text = "💃 안무 따라하기"
	if cameraAnchor then cameraAnchor:Destroy() cameraAnchor = nil end
end)
