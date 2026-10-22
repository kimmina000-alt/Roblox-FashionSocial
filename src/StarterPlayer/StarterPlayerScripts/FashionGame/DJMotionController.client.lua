--!strict
-- DJ motion while DJing (user, 2026-10-22: one hand on the turntable doing
-- the controls, the other hand at the ear like holding headphones).
-- The server sets the character attribute "Djing" (DjService.Actions.Djing);
-- every client poses that character with IKControls, so everyone sees it and
-- no animation asset is needed:
--   * right hand on the nearest platter: scratching back and forth, now and
--     then reaching over to the mixer
--   * left hand held at the left ear
--   * head nods to the beat
-- R15 characters only (IK needs the R15 arm chain).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type Rig = {
	character: Model,
	holder: Part,
	hand: Attachment,
	ear: Attachment,
	look: Attachment,
	controls: {IKControl},
	platter: BasePart?,
	mixer: BasePart?,
}
local rigs: {[Model]: Rig} = {}

local function consoleParts(near: Vector3): (BasePart?, BasePart?)
	local platter, mixer = nil, nil
	local best = math.huge
	for _, console in ipairs(CollectionService:GetTagged("DJConsole")) do
		if console:IsDescendantOf(workspace) then
			for _, p in ipairs(console:GetDescendants()) do
				if p:IsA("BasePart") then
					if p.Name == "Platter" then
						local d = (p.Position - near).Magnitude
						if d < best then best, platter = d, p end
					elseif p.Name == "Mixer" then
						mixer = p
					end
				end
			end
		end
	end
	return platter, mixer
end

local function stop(character: Model)
	local rig = rigs[character]
	if not rig then return end
	rigs[character] = nil
	for _, control in ipairs(rig.controls) do control:Destroy() end
	rig.holder:Destroy()
end

local function start(character: Model)
	if rigs[character] then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local upperR, handR = character:FindFirstChild("RightUpperArm"), character:FindFirstChild("RightHand")
	local upperL, handL = character:FindFirstChild("LeftUpperArm"), character:FindFirstChild("LeftHand")
	local head, torso = character:FindFirstChild("Head"), character:FindFirstChild("UpperTorso")
	if not humanoid or not root or not upperR or not handR or not upperL or not handL or not head or not torso then return end
	local holder = Instance.new("Part")
	holder.Name = "DJMotionTargets"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new()
	holder.Parent = workspace
	local function target(name: string): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = holder
		return a
	end
	local hand, ear, look = target("Hand"), target("Ear"), target("Look")
	local function control(name: string, kind: Enum.IKControlType, chainRoot: Instance, endEffector: Instance, goal: Attachment, smooth: number): IKControl
		local ik = Instance.new("IKControl")
		ik.Name = name
		ik.Type = kind
		ik.ChainRoot = chainRoot
		ik.EndEffector = endEffector
		ik.Target = goal
		ik.SmoothTime = smooth
		ik.Weight = 1
		ik.Parent = humanoid
		return ik
	end
	local platter, mixer = consoleParts(root.Position)
	rigs[character] = {
		character = character,
		holder = holder,
		hand = hand,
		ear = ear,
		look = look,
		controls = {
			control("DJ_RightHand", Enum.IKControlType.Position, upperR, handR, hand, 0.06),
			control("DJ_LeftHand", Enum.IKControlType.Position, upperL, handL, ear, 0.15),
			control("DJ_Head", Enum.IKControlType.LookAt, torso, head, look, 0.08),
		},
		platter = platter,
		mixer = mixer,
	}
end

local function watch(character: Model)
	local function update()
		if character:GetAttribute("Djing") then start(character) else stop(character) end
	end
	character:GetAttributeChangedSignal("Djing"):Connect(update)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then stop(character) end
	end)
	update()
end

local function watchPlayer(other: Player)
	if other.Character then watch(other.Character) end
	other.CharacterAdded:Connect(watch)
end
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for character, rig in pairs(rigs) do
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = character:FindFirstChild("Head") :: BasePart?
		if not root or not head then continue end
		-- right hand: scratch on the platter, every 4 s reach over to the mixer for 1 s
		local platter = rig.platter
		if platter then
			local top = platter.Position + Vector3.new(0, 0.35, 0)
			local goal = top + root.CFrame.RightVector * 0.5 * math.sin(t * 9) + root.CFrame.LookVector * 0.25 * math.cos(t * 4.5)
			if rig.mixer and (t % 4) > 3 then
				goal = rig.mixer.Position + Vector3.new(0, 0.6, 0) + root.CFrame.RightVector * 0.4 * math.sin(t * 6)
			end
			rig.hand.WorldPosition = goal
		else
			rig.hand.WorldPosition = (root.CFrame * CFrame.new(1, -0.2, -1.6)).Position
		end
		-- left hand cupped at the left ear (headphones)
		rig.ear.WorldPosition = (head.CFrame * CFrame.new(-0.85, 0.05, 0.15)).Position
		-- head nods to the beat (about 2 beats per second)
		local nod = 0.5 * math.abs(math.sin(t * math.pi * 2))
		rig.look.WorldPosition = (root.CFrame * CFrame.new(0, 1.2 - nod * 2, -8)).Position
	end
end)
