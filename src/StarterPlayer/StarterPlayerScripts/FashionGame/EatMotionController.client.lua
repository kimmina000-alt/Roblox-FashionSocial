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
	-- (D-1037, user 2026-11-09: "뭐 먹을 때 팔 굽혔다 폈다 존나 반복하는 거 고쳐")
	-- an IKControl blends from the arm's rest pose, not from the tool-holding
	-- pose: at weight 0 the arm dropped straight down, then rose (measured: the
	-- hand 1.15 → 2.37 under the head, then up), every bite. Now the IK is at
	-- full weight from the start and its goal travels from where the hand was
	-- (rest, root space) to the mouth and back (up = 0..1, eased).
	rest: CFrame, up: number, fixFrames: number,
	-- (D-1038, user 2026-11-09: "먹을 때 고개를 약하게 숙였다 폈다 반복하는 모션
	-- 넣어") the head nods a little while the food is at the mouth: a LookAt IK
	-- on the neck (UpperTorso → Head) at a point ahead that dips and rises
	nod: IKControl?, nodGoal: Attachment?, nodT: number,
}
local NOD_PERIOD = 0.7 -- seconds, down and up once
-- how far the head bows, between (4° → 16° at weight 0.8 moved it only 7° in
-- Play: the LookAt does not turn the neck all the way; 6° → 28° at 0.9)
local NOD_MIN, NOD_MAX = math.rad(6), math.rad(28)
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

-- (D-956, user 2026-11-07: "수육 먹을 때 모션 확인하고 수정해": in the video the
-- far corner of the slice went to the lips, the slice standing in front of the
-- eyes) A tool can name the part that is eaten (attribute EatPart, the 수육
-- slice "Fill"): then the end of that part, on the line from the hand through
-- it, goes to the lips. Hand space.
local function eatPoint(character: Model, hand: BasePart): Vector3?
	local tool = character:FindFirstChildOfClass("Tool")
	local name = tool and tool:GetAttribute("EatPart")
	local handle = tool and tool:FindFirstChild("Handle")
	local p = tool and typeof(name) == "string" and tool:FindFirstChild(name, true)
	if not handle or not handle:IsA("BasePart") or not p or not p:IsA("BasePart") then return nil end
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripCF = if grip then grip.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0)
	local inHand = gripCF * tool.Grip:Inverse() * handle.CFrame:ToObjectSpace(p.CFrame)
	local centre = inHand.Position
	if centre.Magnitude < 0.05 then return nil end
	local along = centre.Unit
	-- (how far the part reaches on along that line from its centre)
	local h = p.Size / 2
	local reach = math.abs(inHand.XVector:Dot(along)) * h.X + math.abs(inHand.YVector:Dot(along)) * h.Y + math.abs(inHand.ZVector:Dot(along)) * h.Z
	return centre + along * reach * 0.8
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
		rig.fixFrames = 0
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
	local tip = eatPoint(character, hand) or farEnd(character, hand) or Vector3.new(0, -0.3, 0)
	local tipWorldDir = hand.CFrame:VectorToWorldSpace(tip)
	local turned = turnBetween(tipWorldDir, head.CFrame:VectorToWorldSpace(TOWARD_MOUTH)) * hand.CFrame.Rotation
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rest = if root then root.CFrame:ToObjectSpace(hand.CFrame) else CFrame.identity
	-- (the goal starts on the hand as it is: full weight, no drop)
	holder.CFrame = CFrame.identity
	goal.WorldCFrame = hand.CFrame
	pole.WorldPosition = (head.CFrame * CFrame.new(1.6 * head.Size.Y, -2.2 * head.Size.Y, 0.6 * head.Size.Y)).Position
	local ik = Instance.new("IKControl")
	ik.Name = "EatHand"
	ik.Type = Enum.IKControlType.Transform
	ik.ChainRoot = upper
	ik.EndEffector = hand
	ik.Target = goal
	ik.Pole = pole
	-- (D-1037: its own smoothing started from the straight arm too: 0, the goal is eased here)
	ik.SmoothTime = 0
	ik.Weight = 1
	ik.Parent = humanoid
	-- (D-1038) the nod: the neck only (UpperTorso → Head), weight follows the arm
	local torso = character:FindFirstChild("UpperTorso")
	local nod: IKControl? = nil
	local nodGoal: Attachment? = nil
	if torso and torso:IsA("BasePart") then
		nodGoal = Instance.new("Attachment")
		nodGoal.Name = "NodGoal"
		nodGoal.Parent = holder
		local n = Instance.new("IKControl")
		n.Name = "EatNod"
		n.Type = Enum.IKControlType.LookAt
		n.ChainRoot = torso
		n.EndEffector = head
		n.Target = nodGoal
		n.SmoothTime = 0
		n.Weight = 0
		n.Parent = humanoid
		nod = n
	end
	rigs[character] = {
		ik = ik, holder = holder, goal = goal, pole = pole, want = 1,
		tip = tip, turn = head.CFrame.Rotation:Inverse() * turned, fix = Vector3.zero,
		rest = rest, up = 0, fixFrames = 0,
		nod = nod, nodGoal = nodGoal, nodT = 0,
	}
end

local function remove(character: Model)
	local rig = rigs[character]
	if not rig then return end
	rigs[character] = nil
	rig.ik:Destroy()
	if rig.nod then rig.nod:Destroy() end
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
		-- (D-1037) the correction is measured for a short while once the hand is up
		-- (10 frames), then held: measured every frame it chased the IK's own lag
		-- and the hand bobbed up and down at the mouth
		if hand and rig.up > 0.97 and rig.want > 0 and rig.fixFrames < 10 then
			rig.fixFrames += 1
			local miss = head.CFrame:VectorToObjectSpace(lips - hand.CFrame * rig.tip)
			local fix = rig.fix + miss * 0.33
			rig.fix = if fix.Magnitude > 1 then fix.Unit else fix
		end
		local handPos = lips - turn:VectorToWorldSpace(rig.tip) + head.CFrame:VectorToWorldSpace(rig.fix)
		local mouth = CFrame.new(handPos) * turn
		-- (D-1037) from where the hand was to the mouth, eased; back the same way
		if rig.up < rig.want then
			rig.up = math.min(rig.want, rig.up + dt * RATE)
		elseif rig.up > rig.want then
			rig.up = math.max(rig.want, rig.up - dt * RATE)
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local restWorld = if root then root.CFrame * rig.rest else mouth
		local a = rig.up * rig.up * (3 - 2 * rig.up)
		rig.goal.WorldCFrame = restWorld:Lerp(mouth, a)
		-- (D-1038) the nod: a point 4 studs ahead of the neck, bowed down by an
		-- angle going NOD_MIN → NOD_MAX → NOD_MIN, seen from the torso (not the
		-- head, which the IK turns); it fades in and out with the arm
		local torso = character:FindFirstChild("UpperTorso") :: BasePart?
		if rig.nod and rig.nodGoal and torso and root then
			rig.nodT += dt
			local k = 0.5 - 0.5 * math.cos((rig.nodT % NOD_PERIOD) / NOD_PERIOD * 2 * math.pi)
			local bow = NOD_MIN + (NOD_MAX - NOD_MIN) * k
			local neck = torso.CFrame * Vector3.new(0, torso.Size.Y / 2 + head.Size.Y / 2, 0)
			local ahead = root.CFrame.LookVector
			rig.nodGoal.WorldPosition = neck + (ahead * math.cos(bow) - Vector3.yAxis * math.sin(bow)) * 4
			rig.nod.Weight = a * 0.9
		end
		-- the elbow out to the right and down, a little behind the arm
		rig.pole.WorldPosition = (head.CFrame * CFrame.new(1.6 * s, -2.2 * s, 0.6 * s)).Position
		if rig.want <= 0 and rig.up <= 0 then remove(character) end
	end
end)
