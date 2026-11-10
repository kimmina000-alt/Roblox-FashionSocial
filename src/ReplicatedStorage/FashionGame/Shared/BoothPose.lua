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

-- (D-1183, user 2026-11-10: "오후네컷 표정 추가") faces for the photo: values for the
-- head's FaceControls (dynamic heads only; classic heads have none). The
-- character attribute BoothFace = a key; BoothPoseController sets it after the
-- animations every step (the mood animation would undo it), PhotoRender on the
-- saved photo (entry.f).
BoothPose.Faces = {
	{ key = "smile", label = "😊 미소", v = { LeftLipCornerPuller = 0.8, RightLipCornerPuller = 0.8, LeftCheekRaiser = 0.6, RightCheekRaiser = 0.6 } },
	{ key = "grin", label = "😁 활짝", v = { LeftLipCornerPuller = 1, RightLipCornerPuller = 1, LeftCheekRaiser = 0.8, RightCheekRaiser = 0.8, JawDrop = 0.35, LeftUpperLipRaiser = 0.4, RightUpperLipRaiser = 0.4 } },
	{ key = "wink", label = "😉 윙크", v = { LeftEyeClosed = 1, LeftCheekRaiser = 0.7, LeftLipCornerPuller = 0.7, RightLipCornerPuller = 0.5 } },
	{ key = "wow", label = "😮 놀람", v = { JawDrop = 0.6, Funneler = 0.4, LeftInnerBrowRaiser = 1, RightInnerBrowRaiser = 1, LeftOuterBrowRaiser = 1, RightOuterBrowRaiser = 1, LeftEyeUpperLidRaiser = 0.8, RightEyeUpperLidRaiser = 0.8 } },
	-- (메롱 was tried: many heads have no tongue, Studio check 2026-11-10 → 눈웃음)
	{ key = "squint", label = "😆 눈웃음", v = { LeftEyeClosed = 0.7, RightEyeClosed = 0.7, LeftCheekRaiser = 1, RightCheekRaiser = 1, LeftLipCornerPuller = 1, RightLipCornerPuller = 1, JawDrop = 0.1 } },
	{ key = "puff", label = "🐡 볼빵빵", v = { LeftCheekPuff = 1, RightCheekPuff = 1, LipsTogether = 1 } },
	{ key = "pout", label = "😤 뾰로통", v = { Pucker = 0.8, LeftBrowLowerer = 0.8, RightBrowLowerer = 0.8, ChinRaiser = 0.5 } },
	{ key = "calm", label = "😌 눈감기", v = { LeftEyeClosed = 1, RightEyeClosed = 1, LeftLipCornerPuller = 0.4, RightLipCornerPuller = 0.4 } },
}
local FACE_BY_KEY: {[string]: any} = {}
local FACE_PROPS: {[string]: boolean} = {}
for _, f in ipairs(BoothPose.Faces) do
	FACE_BY_KEY[f.key] = f
	for name in pairs(f.v) do FACE_PROPS[name] = true end
end
function BoothPose.isFace(key: any): boolean
	return typeof(key) == "string" and FACE_BY_KEY[key] ~= nil
end
function BoothPose.faceControls(model: Model): Instance?
	local head = model:FindFirstChild("Head")
	return head and head:FindFirstChildOfClass("FaceControls")
end
-- the face on (key) or every face value back to 0 (key nil); false: no FaceControls
function BoothPose.face(model: Model, key: string?): boolean
	local fc = BoothPose.faceControls(model)
	if not fc then return false end
	local f = key and FACE_BY_KEY[key]
	for name in pairs(FACE_PROPS) do
		local value = if f then (f.v[name] or 0) else 0
		pcall(function() (fc :: any)[name] = value end)
	end
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
