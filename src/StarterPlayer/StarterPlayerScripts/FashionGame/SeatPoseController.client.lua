--!strict
-- Sitting poses by the seat (D-1084, user 2026-11-09: "돗자리에 앉으면 양반다리로
-- 앉기. 비치 의자에 앉으면 상체 조금 더 뒤로 기울이기").
--   * MatSeat (the beach mats): cross-legged, the thighs out to the sides and
--     the shins folded in front, crossing (angles found in Play so the legs lie
--     on the mat)
--   * BeachChair (the deck chairs): the upper body leaned further back into the
--     chair, the head a little forward again so the eyes stay level
-- Every client does it for every sitting character: the joints' Transform
-- (AnimationConstraint on current avatars, Motor6D on older ones) is set after
-- the animations each frame (PreSimulation), blended in and out over 0.25 s.
-- R15 only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local R = math.rad
local BLEND = 0.25

type Pose = {[string]: (CFrame) -> CFrame} -- joint name → animated → wanted
local POSES: {[string]: Pose} = {
	MatSeat = {
		RightHip = function() return CFrame.Angles(0, R(-55), 0) * CFrame.Angles(R(90), 0, 0) * CFrame.Angles(0, R(-90), 0) end,
		LeftHip = function() return CFrame.Angles(0, R(55), 0) * CFrame.Angles(R(90), 0, 0) * CFrame.Angles(0, R(90), 0) end,
		RightKnee = function() return CFrame.Angles(R(-165), 0, 0) end,
		LeftKnee = function() return CFrame.Angles(R(-165), 0, 0) end,
	},
	BeachChair = {
		-- (+ leans back here; seen in Play: the back then lies on the canvas)
		-- (D-1277: 28° still looked upright on the 48° canvas; 46° lies back on it)
		Waist = function(anim) return anim * CFrame.Angles(R(46), 0, 0) end,
		Neck = function(anim) return anim * CFrame.Angles(R(-22), 0, 0) end,
	},
}
local PARTS = {
	RightHip = "RightUpperLeg", LeftHip = "LeftUpperLeg", RightKnee = "RightLowerLeg", LeftKnee = "LeftLowerLeg",
	Waist = "UpperTorso", Neck = "Head",
}

type Rig = { pose: Pose, joints: {[string]: any}, want: number, up: number, base: {[any]: CFrame}, last: {[any]: CFrame} }
local rigs: {[Model]: Rig} = {}

local function joint(character: Model, name: string): any?
	local part = character:FindFirstChild(PARTS[name])
	local m = part and part:FindFirstChild(name)
	return if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m else nil
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then return end
	local function update()
		local seat = humanoid.SeatPart
		local pose = seat and POSES[seat.Name]
		-- (D-1277, user 2026-11-11: "비치의자에 앉으면 의자에 기대앉는 것처럼 몸 뒤로
		-- 기울어지게") the store deck chair's own seat is named "Seat" inside a
		-- model named BeachChair, and that is the one people land on
		if not pose and seat and seat.Parent and seat.Parent.Name == "BeachChair" then
			pose = POSES.BeachChair
		end
		local rig = rigs[character]
		if pose then
			if rig and rig.pose == pose then rig.want = 1 return end
			local joints = {}
			for name in pairs(pose) do joints[name] = joint(character, name) end
			rigs[character] = { pose = pose, joints = joints, want = 1, up = if rig then rig.up else 0, base = {}, last = {} }
		elseif rig then
			rig.want = 0 -- (eased out, then let go)
		end
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(update)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then rigs[character] = nil end
	end)
	update()
end

local function watchPlayer(other: Player)
	if other.Character then task.spawn(watch, other.Character) end
	other.CharacterAdded:Connect(watch)
end
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)

-- after the Animator has written this frame's pose
RunService.PreSimulation:Connect(function(dt)
	for character, rig in pairs(rigs) do
		if rig.up < rig.want then
			rig.up = math.min(rig.want, rig.up + dt / BLEND)
		elseif rig.up > rig.want then
			rig.up = math.max(rig.want, rig.up - dt / BLEND)
		end
		local a = rig.up * rig.up * (3 - 2 * rig.up)
		local done = rig.want <= 0 and rig.up <= 0
		for name, m in pairs(rig.joints) do
			if not m.Parent then continue end
			-- (a joint no animation writes keeps what was set last frame: then the
			-- pose from before is the base)
			local now = m.Transform
			local last = rig.last[m]
			if not last or not now:FuzzyEq(last, 1e-4) then rig.base[m] = now end
			local base = rig.base[m] or now
			local out = if done then base else base:Lerp(rig.pose[name](base), a)
			m.Transform = out
			rig.last[m] = out
		end
		if done then rigs[character] = nil end
	end
end)
