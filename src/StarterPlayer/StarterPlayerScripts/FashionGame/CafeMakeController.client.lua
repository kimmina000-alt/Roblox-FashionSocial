--!strict
-- (D-1352, user 2026-11-13: "카페에서 알바할 때 음료 만들 때 만드는 모션 추가") While a cafe
-- part-timer makes a drink (CafeJobService sets the character attribute CafeMaking for
-- CafeJobConfig.MakeSeconds), every client shows it: the left hand holds a cup in front of
-- the chest, the right hand stirs it in small circles, a straw in the cup. No animation
-- asset: the four arm joints' Transform is set after the animations each frame
-- (PreSimulation, like EatMotionController), eased in and out. The cup is a local prop.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EASE = 0.25 -- seconds in / out

type Rig = { joints: {[string]: any}, w: number, on: boolean, cup: Model?, t: number }
local rigs: {[Model]: Rig} = {}

local function joint(character: Model, part: string, name: string): any
	local p = character:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	return if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m else nil
end

local function makeCup(character: Model): Model?
	local hand = character:FindFirstChild("LeftHand")
	if not (hand and hand:IsA("BasePart")) then return nil end
	local model = Instance.new("Model")
	model.Name = "CafeMakeCup"
	local function piece(size: Vector3, offset: CFrame, color: Color3, transparency: number?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.CFrame = hand.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = hand, p
		w.Parent = p
		p.Parent = model
		return p
	end
	-- the cup stands up in the palm (hand's -Y is down the fingers)
	local base = CFrame.new(0, -0.35, -0.15) * CFrame.Angles(0, 0, math.rad(90))
	piece(Vector3.new(0.55, 0.42, 0.42), base, Color3.fromRGB(245, 245, 245), 0.15, Enum.PartType.Cylinder)
	piece(Vector3.new(0.12, 0.4, 0.4), base * CFrame.new(0.2, 0, 0), Color3.fromRGB(120, 75, 45), 0, Enum.PartType.Cylinder) -- the drink
	piece(Vector3.new(0.05, 0.75, 0.05), CFrame.new(0, -0.05, -0.15) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(255, 120, 160)) -- straw
	model.Parent = character
	return model
end

local function rigOf(character: Model): Rig?
	local rig = rigs[character]
	if rig then return rig end
	local joints = {
		rs = joint(character, "RightUpperArm", "RightShoulder"),
		re = joint(character, "RightLowerArm", "RightElbow"),
		ls = joint(character, "LeftUpperArm", "LeftShoulder"),
		le = joint(character, "LeftLowerArm", "LeftElbow"),
	}
	if not (joints.rs and joints.re and joints.ls and joints.le) then return nil end -- (R15 only)
	rig = { joints = joints, w = 0, on = false, cup = nil, t = 0 }
	rigs[character] = rig
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			local r = rigs[character]
			if r and r.cup then r.cup:Destroy() end
			rigs[character] = nil
		end
	end)
	return rig
end

RunService.PreSimulation:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local making = character:GetAttribute("CafeMaking") == true
			local rig = if making or rigs[character] then rigOf(character) else nil
			if rig then
				rig.on = making
				rig.w = math.clamp(rig.w + (if making then dt else -dt) / EASE, 0, 1)
				if making and not rig.cup then rig.cup = makeCup(character) end
				if not making and rig.cup and rig.w <= 0 then rig.cup:Destroy() rig.cup = nil end
				if rig.w > 0 then
					rig.t += dt
					local w = rig.w * rig.w * (3 - 2 * rig.w) -- smooth
					local a = rig.t * math.pi * 2 * 1.6 -- stirring circles, 1.6 a second
					-- left: cup held in front of the chest
					local lsPose = CFrame.Angles(math.rad(28), math.rad(-25), 0)
					local lePose = CFrame.Angles(math.rad(58), 0, 0)
					-- right: over the cup, the hand circling a little
					local rsPose = CFrame.Angles(math.rad(36 + 6 * math.sin(a)), math.rad(30 + 8 * math.cos(a)), 0)
					local rePose = CFrame.Angles(math.rad(55 + 8 * math.cos(a)), 0, 0)
					local j = rig.joints
					j.ls.Transform = j.ls.Transform:Lerp(lsPose, w)
					j.le.Transform = j.le.Transform:Lerp(lePose, w)
					j.rs.Transform = j.rs.Transform:Lerp(rsPose, w)
					j.re.Transform = j.re.Transform:Lerp(rePose, w)
				else
					rig.t = 0
				end
			end
		end
	end
end)
