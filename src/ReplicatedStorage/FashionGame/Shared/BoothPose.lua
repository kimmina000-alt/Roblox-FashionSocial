--!strict
-- Photo booth helper poses (user 2026-10-28, D-445).
--   Kneel ("허리 숙이기"): both knees on the floor, the upper body upright and
--   facing the camera, so a tall avatar's face comes down into the frame.
--   Set on the R15 joints' Transform each frame, after the animations, so it
--   shows live (BoothPoseController) and on the saved photo (PhotoRender).
--   The step ("키높이 발판") is a booth-coloured block under the feet
--   (PhotoBoothService); the photo draws it from the shot data.

local BoothPose = {}

BoothPose.StepHeight = 2.2 -- studs: a short avatar's face up to the camera line

-- Avatars use Motor6D or, after Roblox's joint upgrade, AnimationConstraint
-- joints (both have Transform).
local function motor(model: Model, partName: string, jointName: string): any
	local part = model:FindFirstChild(partName)
	local m = part and part:FindFirstChild(jointName)
	return if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m else nil
end

-- Returns false when the model is not R15 (R6 bodies are left standing).
function BoothPose.kneel(model: Model): boolean
	local lower = model:FindFirstChild("LeftLowerLeg")
	local foot = model:FindFirstChild("LeftFoot")
	local root = motor(model, "LowerTorso", "Root")
	if not (lower and lower:IsA("BasePart") and root) then return false end
	-- the hips come down by the shin and foot; the shins lie on the floor
	local drop = lower.Size.Y + (if foot and foot:IsA("BasePart") then foot.Size.Y else 0) - lower.Size.Z * 0.5
	root.Transform = CFrame.new(0, -drop, 0)
	for _, side in ipairs({ "Left", "Right" }) do
		local hip = motor(model, side .. "UpperLeg", side .. "Hip")
		if hip then hip.Transform = CFrame.identity end
		-- (the avatar faces -Z: -90° about X turns the shin backwards)
		local knee = motor(model, side .. "LowerLeg", side .. "Knee")
		if knee then knee.Transform = CFrame.Angles(math.rad(-90), 0, 0) end
		local ankle = motor(model, side .. "Foot", side .. "Ankle")
		if ankle then ankle.Transform = CFrame.Angles(math.rad(-30), 0, 0) end
	end
	-- the upper body straight up, the head to the front
	local waist = motor(model, "UpperTorso", "Waist")
	if waist then waist.Transform = CFrame.identity end
	local neck = motor(model, "Head", "Neck")
	if neck then neck.Transform = CFrame.identity end
	return true
end

-- Back to rest (the animations take over from there).
function BoothPose.stand(model: Model)
	for _, joint in ipairs({
		{ "LowerTorso", "Root" }, { "UpperTorso", "Waist" }, { "Head", "Neck" },
		{ "LeftUpperLeg", "LeftHip" }, { "RightUpperLeg", "RightHip" },
		{ "LeftLowerLeg", "LeftKnee" }, { "RightLowerLeg", "RightKnee" },
		{ "LeftFoot", "LeftAnkle" }, { "RightFoot", "RightAnkle" },
	}) do
		local m = motor(model, joint[1], joint[2])
		if m then m.Transform = CFrame.identity end
	end
end

return BoothPose
