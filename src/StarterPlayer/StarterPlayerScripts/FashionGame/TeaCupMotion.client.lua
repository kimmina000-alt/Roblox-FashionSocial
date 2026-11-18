--!strict
-- 회전컵 타는 모션 (D-1797, user 2026-11-18 + a picture of a rider in a cup: "회전컵 탈 때 핸들 돌리는 모션이랑
-- 클릭 안 하는 사람은 회전 방향에 따라 몸 기울어지는 모션 추가"). Like the viking cheer (VikingCheerMotion) every
-- client moves every tea cup rider, so everyone sees the same thing and no animation asset is needed:
--   * a rider tapping to spin their cup (the server stamps the character's TeaSpinAt on each counted tap,
--     ParkRideService "Spin") holds the wheel in the middle of the cup with both hands (IKControls on
--     the arms) and turns it: the hands go round the rim and back, quicker the faster the cup spins;
--   * everyone else in a running cup is pushed outward by the ride: the body leans the way the seat is
--     thrown (against its acceleration: the cup's own spin and the table's turn), up to LEAN_MAX, eased.
--     The lean turns the whole body about the hips (the legs are hidden in the cup). Not on this
--     player's own body in first person (the view would roll).
-- R15 for the hands (IK needs the arm chain); the lean works on any rig.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParkConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ParkConfig"))
local player = Players.LocalPlayer

local NEAR = 200
local TURN_HOLD = 1.2 -- seconds after a tap the hands stay on the wheel
local RATE_ON, RATE_OFF = 1 / 0.25, 1 / 0.5 -- hands on in 0.25 s, off in 0.5 s
local LEAN_MAX = math.rad(22)
local LEAN_SCALE = 14 -- studs/s² of the seat's acceleration for about 2/3 of LEAN_MAX
local LEAN_EASE = 5 -- 1/s: how quickly the lean follows
local DIFF = 0.06 -- seconds between the seat samples the acceleration is read from

type Arm = { ik: IKControl, goal: Attachment, side: number }
type Rig = { holder: Part, arms: {Arm}, weight: number }
type Rider = { lean: Vector3, rig: Rig? }
local riders: {[Model]: Rider} = {}

local function makeRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local holder = Instance.new("Part")
	holder.Name = "TeaCupWheelTargets"
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
		ik.Name = "TeaCupWheel" .. side
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = upper
		ik.EndEffector = hand
		ik.Target = goal
		ik.SmoothTime = 0.04
		ik.Weight = 0
		ik.Parent = humanoid
		table.insert(arms, { ik = ik, goal = goal, side = if side == "Right" then 1 else -1 })
	end
	return { holder = holder, arms = arms, weight = 0 }
end

local function dropRig(rider: Rider)
	local rig = rider.rig
	if not rig then return end
	rider.rig = nil
	for _, arm in ipairs(rig.arms) do arm.ik:Destroy() end
	rig.holder:Destroy()
end

-- the seat's acceleration (studs/s², level) at time t
local function seatAccel(ride: Model, index: number, t: number): Vector3?
	local a = ParkConfig.teacupSeatCFrame(ride, index, t - DIFF)
	local b = ParkConfig.teacupSeatCFrame(ride, index, t)
	local c = ParkConfig.teacupSeatCFrame(ride, index, t + DIFF)
	if not a or not b or not c then return nil end
	local acc = (c.Position - 2 * b.Position + a.Position) / (DIFF * DIFF)
	return Vector3.new(acc.X, 0, acc.Z)
end

-- (after ParkRidesController has put the riders on their seats this frame, RenderPriority.Camera - 1)
RunService:BindToRenderStep("TeaCupMotion", Enum.RenderPriority.Camera.Value, function(dt)
	local t = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local present: {[Model]: boolean} = {}
	for _, ride in ipairs(CollectionService:GetTagged("ParkTeaCups")) do
		if not ride:IsA("Model") or not ride:IsDescendantOf(workspace) then continue end
		if camera and (camera.CFrame.Position - ride:GetPivot().Position).Magnitude > NEAR then continue end
		local _, _, still = ParkConfig.teacupState(ride, t)
		local per = (ride:GetAttribute("SeatsPerCup") :: number?) or 4
		for index = 1, ParkConfig.rideSeatCount(ride) do
			local id = ride:GetAttribute("Rider" .. index)
			if typeof(id) ~= "number" then continue end
			local who = Players:GetPlayerByUserId(id)
			local character = who and who.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local head = character and character:FindFirstChild("Head")
			if not character or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then continue end
			present[character] = true
			local rider = riders[character]
			if not rider then
				rider = { lean = Vector3.zero, rig = nil }
				riders[character] = rider
			end
			local stamp = character:GetAttribute("TeaSpinAt")
			local turning = not still and typeof(stamp) == "number" and t - stamp < TURN_HOLD
			-- the hands on the wheel
			local cup = ride:FindFirstChild("Cup" .. math.ceil(index / per))
			local wheel = cup and cup:FindFirstChild("Wheel")
			if turning and not rider.rig then rider.rig = makeRig(character) end
			local rig = rider.rig
			if rig then
				local want = if turning then 1 else 0
				rig.weight = if want > rig.weight then math.min(want, rig.weight + dt * RATE_ON) else math.max(want, rig.weight - dt * RATE_OFF)
				if rig.weight <= 0 and not turning then
					dropRig(rider)
				elseif wheel and wheel:IsA("BasePart") then
					-- two points on the rim, on the rider's side, ±55° from the nearest one, going round
					-- and back like a steering wheel turned hand over hand
					local centre = wheel.Position
					local up = Vector3.yAxis
					local toRider = root.Position - centre
					toRider = Vector3.new(toRider.X, 0, toRider.Z)
					local base = math.atan2(toRider.Z, toRider.X)
					local _, extraSpeed = ParkConfig.teacupExtra(ride, math.ceil(index / per), t)
					local swing = math.sin(os.clock() * (6 + math.min(extraSpeed, 8))) * math.rad(35)
					local radius = math.max(wheel.Size.Y, wheel.Size.Z) / 2 -- (a cylinder: its round faces on Y/Z)
					for _, arm in ipairs(rig.arms) do
						local a = base + arm.side * math.rad(-55) + swing
						local at = centre + Vector3.new(math.cos(a), 0, math.sin(a)) * radius + up * 0.25
						arm.goal.WorldCFrame = CFrame.new(at)
						arm.ik.Weight = rig.weight
					end
				end
			end
			-- the lean (not for the one turning the wheel, and not in this player's own first-person view)
			local target = Vector3.zero
			if not still and not turning then
				local acc = seatAccel(ride, index, t)
				if acc and acc.Magnitude > 1e-3 then
					local amount = LEAN_MAX * (1 - math.exp(-acc.Magnitude / LEAN_SCALE))
					target = -acc.Unit * amount -- (thrown against the acceleration: outward)
				end
			end
			rider.lean = rider.lean:Lerp(target, 1 - math.exp(-dt * LEAN_EASE))
			local own = who == player
			if rider.lean.Magnitude > 1e-3 and not (own and player.CameraMode == Enum.CameraMode.LockFirstPerson) then
				-- turn the body about the hips (the seat point under the root) toward the lean
				local dir = rider.lean.Unit
				local axis = Vector3.yAxis:Cross(dir) -- (tipping toward dir)
				local hips = root.Position - Vector3.new(0, root.Size.Y / 2 + 0.35, 0)
				local tilt = CFrame.fromAxisAngle(axis, rider.lean.Magnitude)
				root.CFrame = CFrame.new(hips) * tilt * CFrame.new(-hips) * root.CFrame
			end
		end
	end
	-- riders who got off (or left, or went out of sight)
	for character, rider in pairs(riders) do
		if not present[character] or not character:IsDescendantOf(workspace) then
			dropRig(rider)
			riders[character] = nil
		end
	end
end)
