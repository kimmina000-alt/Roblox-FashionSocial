--!strict
-- Arms paddling while a tube moves (user 2026-10-30: "튜브 타고 이동할 때 팔
-- 허우적거리면서 물 헤치는 모션"). Same way as the eating / DJ motion: every
-- client bends the rider's arms with IKControls, so everyone sees it and no
-- animation asset is needed. The two hands take turns in a crawl stroke round
-- the tube: reach forward, dip into the water, pull back along the side, lift
-- out; a small splash comes off the hand while it is in the water.
-- A tube moves when its rider steers it (own tube: the move stick) or, for
-- other riders, when its "Drive" attribute (sent ~10 times a second) changes.
-- R15 only (IK needs the arm chain).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PERIOD = 1.1 -- one stroke of one arm, seconds
local RATE = 1 / 0.25 -- weight per second: in or out in 0.25 s
local MOVED_FOR = 0.35 -- another rider still paddles this long after the tube last moved

type Arm = { ik: IKControl, goal: Attachment, splash: ParticleEmitter }
type Rig = { holder: Part, arms: {Arm}, weight: number, phase: number }
local rigs: {[Model]: Rig} = {}
local movedAt: {[Model]: number} = {} -- tube → when its Drive last changed

local function watchTube(tube: Instance)
	if not tube:IsA("Model") then return end
	tube:GetAttributeChangedSignal("Drive"):Connect(function()
		movedAt[tube] = os.clock()
	end)
end
for _, tube in ipairs(CollectionService:GetTagged("FloatTube")) do watchTube(tube) end
CollectionService:GetInstanceAddedSignal("FloatTube"):Connect(watchTube)

local function makeRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local holder = Instance.new("Part")
	holder.Name = "PaddleMotionTargets"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = workspace
	local arms = {}
	for _, side in ipairs({ "Right", "Left" }) do
		local upper, hand = character:FindFirstChild(side .. "UpperArm"), character:FindFirstChild(side .. "Hand")
		if not upper or not hand then
			holder:Destroy()
			return nil
		end
		local goal = Instance.new("Attachment")
		goal.Name = side
		goal.Parent = holder
		local ik = Instance.new("IKControl")
		ik.Name = "Paddle" .. side
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = upper
		ik.EndEffector = hand
		ik.Target = goal
		ik.SmoothTime = 0.04
		ik.Weight = 0
		ik.Parent = humanoid
		-- water thrown off the hand
		local splash = Instance.new("ParticleEmitter")
		splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		splash.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
		splash.LightEmission = 0.4
		splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
		splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		splash.Lifetime = NumberRange.new(0.35, 0.6)
		splash.Speed = NumberRange.new(5, 8)
		splash.SpreadAngle = Vector2.new(35, 35)
		splash.Acceleration = Vector3.new(0, -35, 0)
		splash.EmissionDirection = Enum.NormalId.Top
		splash.Rate = 0
		splash.Parent = goal
		table.insert(arms, { ik = ik, goal = goal, splash = splash })
	end
	return { holder = holder, arms = arms, weight = 0, phase = 0 }
end

local function removeRig(character: Model)
	local rig = rigs[character]
	if not rig then return end
	rigs[character] = nil
	for _, arm in ipairs(rig.arms) do arm.ik:Destroy() end
	rig.holder:Destroy()
end

-- where a hand is at stroke phase p (0..1), in the rider's root space (one
-- unit = the head's height, so big and small avatars stroke alike)
local function strokePoint(p: number, side: number, s: number): Vector3
	local a = p * 2 * math.pi
	-- a loop: forward and high (a = 0), down into the water, back along the side, up and out
	local z = -math.cos(a) * 1.5 * s - 0.4 * s
	local y = math.sin(a) * -1.15 * s - 0.2 * s -- (lowest just under the sea surface)
	local x = side * (1.25 + 0.25 * math.sin(a)) * s
	return Vector3.new(x, y, z)
end

local function riderOf(tube: Model): Model?
	local id = tube:GetAttribute("Rider")
	if typeof(id) ~= "number" then return nil end
	local player = Players:GetPlayerByUserId(id)
	return player and player.Character or nil
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local paddling: {[Model]: boolean} = {}
	for _, tube in ipairs(CollectionService:GetTagged("FloatTube")) do
		if tube:IsA("Model") and tube:IsDescendantOf(workspace) then
			local character = riderOf(tube)
			if character then
				local moving
				if character == Players.LocalPlayer.Character then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
				else
					moving = now - (movedAt[tube] or 0) < MOVED_FOR
				end
				paddling[character] = moving
			end
		end
	end
	for character, moving in pairs(paddling) do
		if moving and not rigs[character] then
			local rig = makeRig(character)
			if rig then rigs[character] = rig end
		end
	end
	for character, rig in pairs(rigs) do
		local want = if paddling[character] then 1 else 0
		if want > rig.weight then
			rig.weight = math.min(want, rig.weight + dt * RATE)
		else
			rig.weight = math.max(want, rig.weight - dt * RATE)
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = character:FindFirstChild("Head") :: BasePart?
		if rig.weight <= 0 or not root or not head or not character:IsDescendantOf(workspace) then
			removeRig(character)
			continue
		end
		rig.phase = (rig.phase + dt / PERIOD) % 1
		local s = head.Size.Y
		for i, arm in ipairs(rig.arms) do
			local side = if i == 1 then 1 else -1
			local p = (rig.phase + (i - 1) * 0.5) % 1 -- the arms take turns
			arm.goal.WorldPosition = root.CFrame:PointToWorldSpace(strokePoint(p, side, s))
			arm.ik.Weight = rig.weight
			-- in the water from a quarter to halfway through the stroke
			arm.splash.Rate = if rig.weight > 0.5 and p > 0.2 and p < 0.55 then 28 else 0
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then removeRig(player.Character) end
end)
