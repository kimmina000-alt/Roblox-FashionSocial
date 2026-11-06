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
-- (D-949, user 2026-11-07: "음식 먹을 때 모션 좀 더 섬세하게 구현해. 팔꿈치 관절
-- 꺾으면서 손에 숟가락 들고 있고 숟가락이 얼굴의 입 부분에 닿게. 지금 얼굴 뚫고
-- 손 들어감.") the hand went to a point under the chin, whatever it held, so
-- with a short item the hand itself went into the face. Now:
--   * the far end of what is held (the spoon's bowl, the cup's rim, the end of
--     the bread: the point of the tool farthest from the hand) is found once
--     when the bite starts
--   * the IK moves the hand as a whole (Transform): turned so the tool points
--     at the mouth from the front and below, placed so that far end rests just
--     in front of the lips, the hand itself a tool's length away
--   * a pole beside and below the shoulder bends the elbow out and down

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type Rig = {
	ik: IKControl, holder: Part, goal: Attachment, pole: Attachment, want: number,
	tip: Vector3, -- the far end of the held item, in the hand's space
	turn: CFrame, -- the hand's turn in the head's space
	fix: Vector3, -- head space: where the IK ends short of the goal, made up for
}
local rigs: {[Model]: Rig} = {}
local RATE = 1 / 0.3 -- weight per second: up or down in 0.3 s
-- the way the held item points, hand → its far end, in the head's space (the
-- face looks to -Z): back toward the face, up a little and in from the right
-- hand's side, so the hand stays in front of the chin and to the right
local TOWARD_MOUTH = Vector3.new(-0.25, 0.45, 1).Unit

-- The far end of what the hand holds: of every visible corner of the tool's
-- parts, the one farthest from the hand (hand space). nil: nothing held.
-- (The spoon is put in the hand just before the bite, so on this client it
-- may not be welded to the hand yet and stand anywhere, the arm then reached
-- up over the head in the first Play test. So the parts are taken where the
-- grip will hold them: the handle at the hand's grip attachment × Grip⁻¹,
-- every other part where it sits against the handle.)
local function farEnd(character: Model, hand: BasePart): Vector3?
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if not tool or not handle or not handle:IsA("BasePart") then return nil end
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripCF = if grip then grip.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0)
	local handleInHand = gripCF * tool.Grip:Inverse()
	local best: Vector3? = nil
	local bestD = 0.25 -- (smaller than this: the item is in the palm, use the hand)
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			local inHand = handleInHand * handle.CFrame:ToObjectSpace(p.CFrame)
			local h = p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local loc = inHand * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
						-- (a piece more than 3 studs off is not really in the hand)
						if loc.Magnitude > bestD and loc.Magnitude < 3 then best, bestD = loc, loc.Magnitude end
					end
				end
			end
		end
	end
	return best
end

-- the turn that takes direction a onto direction b (shortest way)
local function turnBetween(a: Vector3, b: Vector3): CFrame
	a, b = a.Unit, b.Unit
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-4 then
		if dot > 0 then return CFrame.identity end
		local other = if math.abs(a.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
		return CFrame.fromAxisAngle(a:Cross(other).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

local function start(character: Model)
	local rig = rigs[character]
	if rig then
		rig.want = 1 -- (a new bite while the arm was still going down)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upper, hand = character:FindFirstChild("RightUpperArm"), character:FindFirstChild("RightHand")
	local head = character:FindFirstChild("Head")
	if not humanoid or not upper or not hand or not hand:IsA("BasePart") or not head or not head:IsA("BasePart") then return end
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
	goal.Name = "Goal"
	goal.Parent = holder
	local pole = Instance.new("Attachment")
	pole.Name = "Pole"
	pole.Parent = holder
	-- what is held, and how the hand must turn so it points at the mouth
	local tip = farEnd(character, hand) or Vector3.new(0, -0.3, 0)
	local tipWorldDir = hand.CFrame:VectorToWorldSpace(tip)
	local turned = turnBetween(tipWorldDir, head.CFrame:VectorToWorldSpace(TOWARD_MOUTH)) * hand.CFrame.Rotation
	local ik = Instance.new("IKControl")
	ik.Name = "EatHand"
	ik.Type = Enum.IKControlType.Transform
	ik.ChainRoot = upper
	ik.EndEffector = hand
	ik.Target = goal
	ik.Pole = pole
	ik.SmoothTime = 0.08
	ik.Weight = 0
	ik.Parent = humanoid
	rigs[character] = {
		ik = ik, holder = holder, goal = goal, pole = pole, want = 1,
		tip = tip, turn = head.CFrame.Rotation:Inverse() * turned, fix = Vector3.zero,
	}
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
		local s = head.Size.Y
		-- the lips: the middle of the face's front, a little under the middle
		-- of the head, scaled with the head (big and small avatars); the far end
		-- of the item stops just in front of them
		local lips = head.CFrame * Vector3.new(0, -0.2 * s, -(head.Size.Z / 2 + 0.04 * s))
		local turn = head.CFrame.Rotation * rig.turn
		-- the hand so that hand * tip = lips
		-- (the arm cannot always turn the hand all the way, then the item's end
		-- stops off the lips, in the Play test above them by the eyes: once the
		-- arm is up, where the end really is is measured each frame and the
		-- goal moves by what is missing, a third per frame, at most a stud)
		local hand = character:FindFirstChild("RightHand") :: BasePart?
		if hand and rig.ik.Weight > 0.9 and rig.want > 0 then
			local miss = head.CFrame:VectorToObjectSpace(lips - hand.CFrame * rig.tip)
			local fix = rig.fix + miss * 0.33
			rig.fix = if fix.Magnitude > 1 then fix.Unit else fix
		end
		local handPos = lips - turn:VectorToWorldSpace(rig.tip) + head.CFrame:VectorToWorldSpace(rig.fix)
		rig.goal.WorldCFrame = CFrame.new(handPos) * turn
		-- the elbow out to the right and down, a little behind the arm
		rig.pole.WorldPosition = (head.CFrame * CFrame.new(1.6 * s, -2.2 * s, 0.6 * s)).Position
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
