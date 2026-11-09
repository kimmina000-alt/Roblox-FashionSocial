--!strict
-- Eating and drinking motion. SnackService / DrinkService set the character
-- attribute "Eating" while a bite or a spoonful is at the mouth; every client
-- then moves that character's right arm up to the mouth and down again.
-- (D-1076, user 2026-11-09, with a screen recording: "음식 먹을 때 팔 모션
-- 지저분해 다른 게임은 보통 어떻게 표현하는지 조사해서 그대로 구현해 고개
-- 움직임도 지우고") The IK version (D-949 / D-1037 / D-1038) turned the hand every
-- frame so the item's far end met the lips and nodded the head: the wrist
-- twisted, the bowl swung across the face and the head bobbed. Games usually
-- play one eating animation instead: the item stays as it is in the hand, the
-- shoulder brings the arm forward and in, the elbow folds so the hand comes up
-- in front of the mouth, held still there, then back down; the head stays still.
-- The same here: one pose of the three right-arm joints per bite (no animation
-- asset needed), their Motor6D.Transform set after the animations each frame
-- (PreSimulation), blended from the animated pose (the tool hold) to that pose
-- and back. The pose is found once when the bite starts, from the avatar's own
-- joints (so it fits every size) and what the hand holds:
--   * a big held dish (a 국밥 bowl, a cup of ramen; 1.2 studs or more across):
--     its middle just under the chin in front of the mouth, its top tipped a
--     little toward the face, the hand under it
--   * anything smaller (bread, a spoon, chopsticks, a cup): its far end (or the
--     tool's EatPart, the 수육 slice) just in front of the lips
-- with the elbow low and out, the wrist bent as little as it can.
-- R15 only (R6 has no elbow; SnackService still moves the item itself there).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UP_TIME = 0.28 -- seconds up (and down)
local BIG = 1.2 -- studs: a dish held under the chin

type Pose = { shoulder: CFrame, elbow: CFrame, wrist: CFrame }
type Rig = {
	shoulder: any, elbow: any, wrist: any?, pose: Pose,
	want: number, up: number,
	base: {[any]: CFrame}, last: {[any]: CFrame},
}
local rigs: {[Model]: Rig} = {}

-- (current avatars join their limbs with an AnimationConstraint, older ones with
-- a Motor6D; both have a Transform the animations write)
type Joint = any
local function joint(character: Model, part: string, name: string): Joint?
	local p = character:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	return if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m else nil
end
-- the joint's two frames: Part1 = Part0 * c0 * Transform * c1⁻¹
local function frames(m: Joint): (CFrame, CFrame)
	if m:IsA("Motor6D") then return m.C0, m.C1 end
	local a0, a1 = m.Attachment0, m.Attachment1
	return if a0 then a0.CFrame else CFrame.identity, if a1 then a1.CFrame else CFrame.identity
end

-- What the hand holds, in handle space: the point that goes to the mouth and
-- whether it is a big dish. The parts are taken where they sit against the
-- handle (the spoon is put in the hand just before the bite, so on this client
-- it may not be welded to the hand yet).
local function heldPoint(tool: Tool, handle: BasePart, grip: CFrame): (Vector3, boolean, Vector3)
	local named = tool:GetAttribute("EatPart")
	local eatPart = if typeof(named) == "string" then tool:FindFirstChild(named, true) else nil
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local far, farD = nil :: Vector3?, 0.25
	local handleInHand = grip * tool.Grip:Inverse()
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			local rel = handle.CFrame:ToObjectSpace(p.CFrame)
			local h = p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local v = rel * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
						lo, hi = lo:Min(v), hi:Max(v)
						local d = (handleInHand * v).Magnitude -- (from the hand)
						if d > farD and d < 3 then far, farD = v, d end
					end
				end
			end
		end
	end
	local size = hi - lo
	if eatPart and eatPart:IsA("BasePart") then
		-- (D-956) the end of that part on the line from the hand through it
		local rel = handle.CFrame:ToObjectSpace(eatPart.CFrame)
		local centreInHand = handleInHand * rel.Position
		if centreInHand.Magnitude > 0.05 then
			local along = handleInHand:VectorToObjectSpace(centreInHand.Unit)
			local h = eatPart.Size / 2
			local reach = math.abs(rel.XVector:Dot(along)) * h.X + math.abs(rel.YVector:Dot(along)) * h.Y + math.abs(rel.ZVector:Dot(along)) * h.Z
			return rel.Position + along * reach * 0.8, false, size
		end
	end
	if math.max(size.X, size.Z) >= BIG then return (lo + hi) / 2, true, size end
	return far or (lo + hi) / 2, false, size
end

-- the pose for this bite (UpperTorso space)
local function solve(character: Model): Pose?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local sh = joint(character, "RightUpperArm", "RightShoulder")
	local el = joint(character, "RightLowerArm", "RightElbow")
	local wr = joint(character, "RightHand", "RightWrist")
	if not torso or not head or not hand or not sh or not el or not wr then return nil end
	local s = head.Size.Y
	local mouth = torso.CFrame:PointToObjectSpace((head.CFrame * CFrame.new(0, -0.25 * s, -head.Size.Z / 2)).Position)
	local headAt = torso.CFrame:PointToObjectSpace(head.Position)
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local gripAtt = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local grip = if gripAtt then gripAtt.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0)
	local point, big, size = Vector3.zero, false, Vector3.zero
	local handleInHand = CFrame.identity
	if tool and handle and handle:IsA("BasePart") then
		point, big, size = heldPoint(tool, handle, grip)
		handleInHand = grip * tool.Grip:Inverse()
	else
		handleInHand = grip
	end
	local target, wantUp
	if big then
		target = mouth + Vector3.new(0.3 * s, -0.55 * s, -(size.Z / 2 + 0.1 * s))
		wantUp = Vector3.new(0, 0.9, 0.44).Unit
	else
		target = mouth + Vector3.new(0.05 * s, 0, -0.15 * s)
	end
	local C0s, C1s = frames(sh)
	local C0e, C1e = frames(el)
	local C0w, C1w = frames(wr)
	C1s, C1e, C1w = C1s:Inverse(), C1e:Inverse(), C1w:Inverse()
	local R = math.rad
	local function fk(sp: number, sy: number, sz: number, e: number, w: number)
		local s1 = CFrame.Angles(0, R(sy), 0) * CFrame.Angles(R(sp), 0, R(sz))
		local e1 = CFrame.Angles(R(e), 0, 0)
		local w1 = CFrame.Angles(R(w), 0, 0)
		local upper = C0s * s1 * C1s
		local lower = upper * C0e * e1 * C1e
		local h = lower * C0w * w1 * C1w
		local held = h * handleInHand
		return held * point, held.UpVector, lower.Position, h.Position, s1, e1, w1
	end
	local function cost(sp: number, sy: number, sz: number, e: number, w: number): number
		local p, up, elbow, h = fk(sp, sy, sz, e, w)
		local c = (p - target).Magnitude / s
		if wantUp then c += (1 - up:Dot(wantUp)) * 1.5 end
		-- the elbow out and below the hand; the hand out of the head
		c += math.max(0, h.X + 0.2 * s - elbow.X) * 0.5 / s + math.max(0, elbow.Y - h.Y) * 0.5 / s
		c += math.max(0, 0.75 * s - (h - headAt).Magnitude) * 2 / s
		c += math.abs(w) / 300 + math.abs(sy) / 400
		return c
	end
	-- coarse, then finer around the best
	local best, b = math.huge, { 60, 20, 0, 100, 0 }
	for sp = 20, 120, 10 do
		for sy = 0, 40, 10 do
			for sz = -20, 40, 15 do
				for e = 40, 150, 10 do
					for w = -60, 40, 20 do
						local c = cost(sp, sy, sz, e, w)
						if c < best then best, b = c, { sp, sy, sz, e, w } end
					end
				end
			end
		end
	end
	for _, step in ipairs({ 5, 2.5 }) do
		local c0 = table.clone(b)
		for dsp = -1, 1 do
			for dsy = -1, 1 do
				for dsz = -1, 1 do
					for de = -1, 1 do
						for dw = -1, 1 do
							local q = { c0[1] + dsp * step, math.clamp(c0[2] + dsy * step, 0, 45), c0[3] + dsz * step * 2, c0[4] + de * step, c0[5] + dw * step * 2 }
							local c = cost(q[1], q[2], q[3], q[4], q[5])
							if c < best then best, b = c, q end
						end
					end
				end
			end
		end
	end
	local _, _, _, _, s1, e1, w1 = fk(b[1], b[2], b[3], b[4], b[5])
	return { shoulder = s1, elbow = e1, wrist = w1 }
end

local function start(character: Model)
	local rig = rigs[character]
	if rig then
		rig.want = 1 -- (a new bite while the arm was still going down)
		return
	end
	local shoulder = joint(character, "RightUpperArm", "RightShoulder")
	local elbow = joint(character, "RightLowerArm", "RightElbow")
	if not shoulder or not elbow then return end
	local pose = solve(character)
	if not pose then return end
	rigs[character] = {
		shoulder = shoulder, elbow = elbow, wrist = joint(character, "RightHand", "RightWrist"), pose = pose,
		want = 1, up = 0, base = {}, last = {},
	}
end

local function watch(character: Model)
	local function update()
		if character:GetAttribute("Eating") then
			start(character)
		else
			local rig = rigs[character]
			if rig then rig.want = 0 end -- (lowered, then let go)
		end
	end
	character:GetAttributeChangedSignal("Eating"):Connect(update)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then rigs[character] = nil end
	end)
	update()
end

local function watchPlayer(other: Player)
	if other.Character then watch(other.Character) end
	other.CharacterAdded:Connect(watch)
end
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)

-- after the Animator has written this frame's pose
RunService.PreSimulation:Connect(function(dt)
	for character, rig in pairs(rigs) do
		if rig.up < rig.want then
			rig.up = math.min(rig.want, rig.up + dt / UP_TIME)
		elseif rig.up > rig.want then
			rig.up = math.max(rig.want, rig.up - dt / UP_TIME)
		end
		local a = rig.up * rig.up * (3 - 2 * rig.up)
		if not rig.shoulder.Parent or not rig.elbow.Parent then
			rigs[character] = nil
			continue
		end
		local done = rig.want <= 0 and rig.up <= 0
		local function pose(m: Joint, target: CFrame)
			-- (a joint no animation writes keeps what was set last frame: then
			-- the pose from before is the base, or the arm would stay up)
			local now = m.Transform
			local last = rig.last[m]
			if not last or not now:FuzzyEq(last, 1e-4) then rig.base[m] = now end
			local out = if done then rig.base[m] or now else (rig.base[m] or now):Lerp(target, a)
			m.Transform = out
			rig.last[m] = out
		end
		pose(rig.shoulder, rig.pose.shoulder)
		pose(rig.elbow, rig.pose.elbow)
		if rig.wrist then pose(rig.wrist, rig.pose.wrist) end
		if done then rigs[character] = nil end
	end
end)
