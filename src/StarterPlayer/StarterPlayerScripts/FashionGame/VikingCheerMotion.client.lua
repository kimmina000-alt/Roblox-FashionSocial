--!strict
-- Both arms up on the way down (D-1427, user 2026-11-15: "바이킹 올라갔다가 내려갈 때 양팔 드는
-- 모션"). Same way as the tube paddling / eating / DJ motions: every client lifts the viking riders'
-- arms with IKControls, so everyone sees it and no animation asset is needed. A rider's arms go up
-- while their seat drops (after the top of a swing) and come down again while it climbs; they
-- ease in and out. R15 only (IK needs the arm chain).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParkConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ParkConfig"))

local RATE_UP = 1 / 0.3 -- weight per second: arms up in 0.3 s
local RATE_DOWN = 1 / 0.45
local DROP = -1.2 -- studs per second: the seat falls at least this fast → arms up
local NEAR = 200

type Arm = { ik: IKControl, goal: Attachment, side: number }
type Rig = { holder: Part, arms: {Arm}, weight: number }
local rigs: {[Model]: Rig} = {}

local function makeRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local holder = Instance.new("Part")
	holder.Name = "VikingCheerTargets"
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
		ik.Name = "VikingCheer" .. side
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = upper
		ik.EndEffector = hand
		ik.Target = goal
		ik.SmoothTime = 0.05
		ik.Weight = 0
		ik.Parent = humanoid
		table.insert(arms, { ik = ik, goal = goal, side = if side == "Right" then 1 else -1 })
	end
	return { holder = holder, arms = arms, weight = 0 }
end

local function removeRig(character: Model)
	local rig = rigs[character]
	if not rig then return end
	rigs[character] = nil
	for _, arm in ipairs(rig.arms) do arm.ik:Destroy() end
	rig.holder:Destroy()
end

-- (right after ParkRidesController has put the riders on their seats this frame, before the camera)
RunService:BindToRenderStep("VikingCheer", Enum.RenderPriority.Camera.Value - 1, function(dt)
	local t = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local cheering: {[Model]: boolean} = {}
	-- (D-1457: the jumping star's riders too, on every drop)
	local rides = CollectionService:GetTagged("ParkViking")
	for _, r in ipairs(CollectionService:GetTagged("ParkJumpStar")) do table.insert(rides, r) end
	for _, ride in ipairs(rides) do
		if not ride:IsA("Model") or not ride:IsDescendantOf(workspace) then continue end
		if camera and (camera.CFrame.Position - ride:GetPivot().Position).Magnitude > NEAR then continue end
		local still = ParkConfig.rideState(ride, t)
		for index = 1, ParkConfig.vikingSeatCount(ride) do
			local id = ride:GetAttribute("Rider" .. index)
			if typeof(id) ~= "number" then continue end
			local rider = Players:GetPlayerByUserId(id)
			local character = rider and rider.Character
			if not character then continue end
			local down = false
			if not still then
				local a = ParkConfig.seatRideSeatCFrame(ride :: Model, index, t)
				local b = ParkConfig.seatRideSeatCFrame(ride :: Model, index, t + 0.05)
				down = a ~= nil and b ~= nil and (b.Y - a.Y) / 0.05 < DROP
			end
			cheering[character] = down
		end
	end
	for character, down in pairs(cheering) do
		if down and not rigs[character] then
			local rig = makeRig(character)
			if rig then rigs[character] = rig end
		end
	end
	for character, rig in pairs(rigs) do
		local want = if cheering[character] then 1 else 0
		if want > rig.weight then
			rig.weight = math.min(want, rig.weight + dt * RATE_UP)
		else
			rig.weight = math.max(want, rig.weight - dt * RATE_DOWN)
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = character:FindFirstChild("Head") :: BasePart?
		if (rig.weight <= 0 and cheering[character] == nil) or not root or not head or not character:IsDescendantOf(workspace) then
			removeRig(character)
			continue
		end
		-- hands high over the head, a little apart and forward (a "만세")
		local s = head.Size.Y
		local up = root.CFrame.UpVector
		for _, arm in ipairs(rig.arms) do
			local at = head.Position + up * (2.4 * s) + root.CFrame.RightVector * (arm.side * 0.95 * s) + root.CFrame.LookVector * (0.35 * s)
			arm.goal.WorldCFrame = CFrame.new(at)
			arm.ik.Weight = rig.weight
		end
	end
end)
