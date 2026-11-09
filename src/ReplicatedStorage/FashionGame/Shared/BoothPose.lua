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

-- (D-1139, user 2026-11-10: "키높이 발판 버튼 누르면 올라오는 블록을 저 동그라미 속 발판
-- 모양으로 수정") the step looks like the booth's own stools: a dark top
-- (StoolTop 0.25 thick), four white metal legs (0.15) set in from the corners,
-- a rail low on each side. Parts in `parent`, laid out round `cf` (the middle
-- of the whole stool), `w` × `h` × `d` studs; only the top collides.
function BoothPose.stool(parent: Instance, cf: CFrame, w: number, h: number, d: number): {BasePart}
	local made = {}
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, collide: boolean)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * CFrame.new(offset)
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = collide
		p.CanTouch = false
		p.CanQuery = collide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		table.insert(made, p)
	end
	local TOP = 0.25
	local DARK = Color3.fromRGB(28, 28, 30)
	local WHITE = Color3.fromRGB(245, 245, 245)
	piece("StoolTop", Vector3.new(w, TOP, d), Vector3.new(0, h / 2 - TOP / 2, 0), DARK, Enum.Material.SmoothPlastic, true)
	local legH = h - TOP
	local lx, lz = w / 2 - 0.35, d / 2 - 0.3
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			piece("StoolLeg", Vector3.new(0.15, legH, 0.15), Vector3.new(sx * lx, -h / 2 + legH / 2, sz * lz), WHITE, Enum.Material.Metal, false)
		end
		piece("StoolRail", Vector3.new(0.12, 0.12, lz * 2), Vector3.new(sx * lx, -h / 2 + legH * 0.3, 0), WHITE, Enum.Material.Metal, false)
	end
	return made
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
