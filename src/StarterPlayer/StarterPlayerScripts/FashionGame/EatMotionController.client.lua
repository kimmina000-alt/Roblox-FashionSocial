--!strict
-- Eating and drinking motion (user 2026-10-27: the food and the 국밥 spoon
-- floated up to the mouth while the arm stayed straight). SnackService sets
-- the character attribute "Eating" while a bite or a spoonful is at the mouth;
-- every client then bends that character's right arm with an IKControl so the
-- hand (and what it holds) comes up in front of the mouth, and lowers it again
-- after. Same way as the DJ motion: no animation asset needed. R15 only (IK
-- needs the arm chain; SnackService still moves the item itself on R6).
-- Driven from Heartbeat with its own easing (RenderStepped and tweens stop
-- while a Studio test window is in the background).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type Rig = { ik: IKControl, holder: Part, goal: Attachment, want: number }
local rigs: {[Model]: Rig} = {}
local RATE = 1 / 0.3 -- weight per second: up or down in 0.3 s

local function start(character: Model)
	local rig = rigs[character]
	if rig then
		rig.want = 1 -- (a new bite while the arm was still going down)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upper, hand = character:FindFirstChild("RightUpperArm"), character:FindFirstChild("RightHand")
	if not humanoid or not upper or not hand then return end
	local holder = Instance.new("Part")
	holder.Name = "EatMotionTarget"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = workspace
	local goal = Instance.new("Attachment")
	goal.Parent = holder
	local ik = Instance.new("IKControl")
	ik.Name = "EatHand"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upper
	ik.EndEffector = hand
	ik.Target = goal
	ik.SmoothTime = 0.05
	ik.Weight = 0
	ik.Parent = humanoid
	rigs[character] = { ik = ik, holder = holder, goal = goal, want = 1 }
end

local function remove(character: Model)
	local rig = rigs[character]
	if not rig then return end
	rigs[character] = nil
	rig.ik:Destroy()
	rig.holder:Destroy()
end

local function watch(character: Model)
	local function update()
		if character:GetAttribute("Eating") then
			start(character)
		else
			local rig = rigs[character]
			if rig then rig.want = 0 end -- (lowered, then removed)
		end
	end
	character:GetAttributeChangedSignal("Eating"):Connect(update)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then remove(character) end
	end)
	update()
end

local function watchPlayer(other: Player)
	if other.Character then watch(other.Character) end
	other.CharacterAdded:Connect(watch)
end
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)

RunService.Heartbeat:Connect(function(dt)
	for character, rig in pairs(rigs) do
		local head = character:FindFirstChild("Head") :: BasePart?
		if not head then continue end
		-- just under the chin and a little forward, scaled with the head (big
		-- and small avatars); the held cup / bread / spoon reaches the mouth
		local s = head.Size.Y
		-- (x: the grip holds the item to the left of the hand; measured 2026-10-27
		-- so the bottle's middle comes to the middle of the mouth)
		rig.goal.WorldPosition = (head.CFrame * CFrame.new(0.5 * s, -0.75 * s, -0.75 * s)).Position
		local w = rig.ik.Weight
		if w < rig.want then
			rig.ik.Weight = math.min(rig.want, w + dt * RATE)
		elseif w > rig.want then
			w = math.max(rig.want, w - dt * RATE)
			rig.ik.Weight = w
			if w <= 0 then remove(character) end
		end
	end
end)
