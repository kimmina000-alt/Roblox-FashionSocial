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
local HAND_FOOD = { croissant = true, saltbread = true, bagel = true } -- (D-1159: bitten from the end)

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
local function heldPoint(tool: Tool, handle: BasePart, grip: CFrame): (Vector3, boolean, Vector3, boolean?)
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
	-- (D-1152, user 2026-11-10, screenshots: the blue lemonade went to the ear on
	-- its side: its farthest corner was the glass bottom) a drink with a straw
	-- (tool attribute EatStraw): the straw's top end to the lips, the glass upright
	-- (D-1159: every glass with a Straw part, the built 한옥 drinks too, measured going to the cheek)
	local straw = tool:FindFirstChild("Straw", true)
	-- (D-1163, user 2026-11-10: "빨대 있는 딸기스무디, 자바칩프라푸치노, 블루 레몬에이드는 빨대가
	-- 입에 닿아야 함") the straw tip read from the mesh (an invisible StrawTip part in
	-- the model): the smoothie's and frappe's straws are part of the glass mesh, the
	-- lemonade's straw is tilted, so its box end was not the tip
	local tip = tool:FindFirstChild("StrawTip", true)
	if tip and tip:IsA("BasePart") then
		return handle.CFrame:PointToObjectSpace(tip.Position), false, size, true
	end
	if straw and straw:IsA("BasePart") then
		local rel = handle.CFrame:ToObjectSpace(straw.CFrame)
		local h = straw.Size / 2
		local best: Vector3? = nil
		for _, v in ipairs({ Vector3.new(h.X, 0, 0), Vector3.new(0, h.Y, 0), Vector3.new(0, 0, h.Z) }) do
			for _, sgn in ipairs({ -1, 1 }) do
				local p = rel * (v * sgn)
				if best == nil or p.Y > best.Y then best = p end
			end
		end
		return best :: Vector3, false, size, true
	end
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
	-- (D-1159) a dish is low and wide: a tall cup (한옥 찻잔, 1.4 wide but 1.7 high)
	-- and bread eaten from the hand go to the lips like the small things
	local wide = math.max(size.X, size.Z)
	if wide >= BIG and size.Y < wide * 0.8 and not HAND_FOOD[tool:GetAttribute("Snack")] then return (lo + hi) / 2, true, size end
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
	local point, big, size, upright = Vector3.zero, false, Vector3.zero, nil :: boolean?
	local handleInHand = CFrame.identity
	if tool and handle and handle:IsA("BasePart") then
		point, big, size, upright = heldPoint(tool, handle, grip)
		handleInHand = grip * tool.Grip:Inverse()
	else
		handleInHand = grip
	end
	local target, wantUp
	if upright then
		-- (D-1152) the straw just at the lips, the glass standing (a hair toward the face)
		-- (D-1163: measured 0.1-0.2 studs in front of the lips: the head's box front
		-- is ahead of the face; the face's own front, FaceFrontAttachment, a hair in)
		local ff = head:FindFirstChild("FaceFrontAttachment")
		local faceZ = if ff and ff:IsA("Attachment") then ff.Position.Z + 0.04 else -head.Size.Z / 2
		target = torso.CFrame:PointToObjectSpace((head.CFrame * CFrame.new(0, -0.27 * s, faceZ)).Position)
		wantUp = Vector3.new(0, 1, 0.12).Unit
	elseif big then
		-- (D-1159, user 2026-11-10: "뭐 먹을 때 위치 모두 체크해서 얼굴 하관 부근으로") measured
		-- in Play: cakes / breads / 한옥 cups / 국밥 bowls stopped at the neck (their
		-- top 0.55-0.9 head below the centre): 0.25 head higher and less to the side
		target = mouth + Vector3.new(0.08 * s, -0.35 * s, -(size.Z / 2 + 0.1 * s))
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
		local c = (p - target).Magnitude / s * (if upright then 3 else 1) -- (D-1163: the straw on the lips first)
		if wantUp then c += (1 - up:Dot(wantUp)) * (if big then 0.8 else 1.5) end -- (D-1159: a dish near the chin first)
		-- the elbow out and below the hand; the hand out of the head
		c += math.max(0, h.X + 0.2 * s - elbow.X) * 0.5 / s + math.max(0, elbow.Y - h.Y) * 0.5 / s
		c += math.max(0, (if big then 0.6 else 0.75) * s - (h - headAt).Magnitude) * 2 / s -- (D-1159: a dish's hand may come closer)
		c += math.abs(w) / 300 + math.abs(sy) / 400
		return c
	end
	-- coarse, then finer around the best
	local best, b = math.huge, { 60, 20, 0, 100, 0 }
	-- (D-1159, measured: a tall glass's straw top is 1.3 studs over the hand, so
	-- the hand comes in low and across to the middle) wider for straw drinks only
	local spLo, syHi = if upright then -20 else 20, if upright then 80 else 40
	for sp = spLo, 120, 10 do
		for sy = 0, syHi, 10 do
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
							local q = { c0[1] + dsp * step, math.clamp(c0[2] + dsy * step, 0, syHi + 5), c0[3] + dsz * step * 2, c0[4] + de * step, c0[5] + dw * step * 2 }
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
		-- (D-1163: another thing in the hand since: its own pose, measured off by
		-- 0.5 stud when a drink came right after another)
		local tool = character:FindFirstChildOfClass("Tool")
		if (rig :: any).tool ~= tool then
			local pose = solve(character)
			if pose then rig.pose = pose end
			(rig :: any).tool = tool
		end
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
	};
	(rigs[character] :: any).tool = character:FindFirstChildOfClass("Tool")
end

-- (D-1105, user 2026-11-09: "삼각김밥 처음에 포장 뜯을 때 양 손으로 뜯는 모션
-- 추가") the two-hand tear of a 삼각김밥 wrapper. SnackService counts up the
-- character attribute "Unwrap"; then both arms come up (the right hand holds
-- the 삼각김밥 in front of the chest, the left hand meets its top corner), the
-- left hand pulls off to the side and down with the wrapper (a copy of the
-- wrapper pieces welded to that hand, here only; the server hides the real one
-- at the same moment) and both arms go down. Poses found once per tear, like
-- the bite pose, with a coarser search (six joints, two poses).
type ArmJoints = { sh: Joint, el: Joint, wr: Joint }
local T_MEET, T_PULL, T_PULLED, T_DOWN, T_END = 0.3, 0.45, 0.85, 1.0, 1.3
type Tear = {
	t0: number, joints: {Joint}, a: {[Joint]: CFrame}, b: {[Joint]: CFrame},
	base: {[Joint]: CFrame}, last: {[Joint]: CFrame}, copied: boolean, copy: {BasePart},
}
local tears: {[Model]: Tear} = {}

local function arm(character: Model, side: string): ArmJoints?
	local sh = joint(character, side .. "UpperArm", side .. "Shoulder")
	local el = joint(character, side .. "LowerArm", side .. "Elbow")
	local wr = joint(character, side .. "Hand", side .. "Wrist")
	if not sh or not el or not wr then return nil end
	return { sh = sh, el = el, wr = wr }
end

-- the three joint rotations that bring `point` (in hand space) to `target`
-- (UpperTorso space); `out` = +1 for the right arm (its elbow out to +X), -1 left
local function reach(j: ArmJoints, point: CFrame, target: Vector3, out: number, s: number): (CFrame, CFrame, CFrame)
	local C0s, C1s = frames(j.sh)
	local C0e, C1e = frames(j.el)
	local C0w, C1w = frames(j.wr)
	C1s, C1e, C1w = C1s:Inverse(), C1e:Inverse(), C1w:Inverse()
	local R = math.rad
	local function fk(sp: number, sy: number, sz: number, e: number, w: number)
		local s1 = CFrame.Angles(0, R(sy), 0) * CFrame.Angles(R(sp), 0, R(sz))
		local e1 = CFrame.Angles(R(e), 0, 0)
		local w1 = CFrame.Angles(R(w), 0, 0)
		local upper = C0s * s1 * C1s
		local lower = upper * C0e * e1 * C1e
		local h = lower * C0w * w1 * C1w
		return (h * point).Position, lower.Position, h.Position, s1, e1, w1
	end
	local function cost(sp: number, sy: number, sz: number, e: number, w: number): number
		local p, elbow, h = fk(sp, sy, sz, e, w)
		local c = (p - target).Magnitude / s
		c += math.max(0, (h.X - elbow.X) * out + 0.15 * s) * 0.4 / s -- (elbow out)
		c += math.max(0, elbow.Y - h.Y) * 0.4 / s -- (elbow below the hand)
		c += math.abs(w) / 300 + math.abs(sy) / 400
		return c
	end
	local best, b = math.huge, { 50, 0, 0, 90, 0 }
	for sp = 0, 120, 20 do
		for sy = -40, 40, 20 do
			for sz = -40, 40, 20 do
				for e = 0, 140, 20 do
					local c = cost(sp, sy, sz, e, 0)
					if c < best then best, b = c, { sp, sy, sz, e, 0 } end
				end
			end
		end
	end
	for _, step in ipairs({ 10, 5, 2.5 }) do
		local c0 = table.clone(b)
		for dsp = -1, 1 do
			for dsy = -1, 1 do
				for dsz = -1, 1 do
					for de = -1, 1 do
						for dw = -1, 1 do
							local q = { c0[1] + dsp * step, c0[2] + dsy * step, c0[3] + dsz * step, c0[4] + de * step, c0[5] + dw * step * 2 }
							local c = cost(q[1], q[2], q[3], q[4], q[5])
							if c < best then best, b = c, q end
						end
					end
				end
			end
		end
	end
	local _, _, _, s1, e1, w1 = fk(b[1], b[2], b[3], b[4], b[5])
	return s1, e1, w1
end

local function startTear(character: Model)
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local rhand = character:FindFirstChild("RightHand") :: BasePart?
	local right, left = arm(character, "Right"), arm(character, "Left")
	if not torso or not head or not rhand or not right or not left then return end
	local s = head.Size.Y
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local gripAtt = rhand:FindFirstChild("RightGripAttachment") :: Attachment?
	local grip = if gripAtt then gripAtt.CFrame else CFrame.new(0, -rhand.Size.Y / 2, 0)
	-- the middle and the size of what the right hand holds (hand space)
	local centre, size = grip, Vector3.one * 0.6
	if tool and handle and handle:IsA("BasePart") then
		local _, _, sz = heldPoint(tool, handle, grip)
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, p in ipairs(tool:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 0.95 then
				local rel = handle.CFrame:ToObjectSpace(p.CFrame)
				lo, hi = lo:Min(rel.Position), hi:Max(rel.Position)
			end
		end
		centre = grip * tool.Grip:Inverse() * CFrame.new((lo + hi) / 2)
		size = sz
	end
	local front = -(torso.Size.Z / 2 + 0.75 * s)
	-- the 삼각김밥 in front of the chest (from the head down: torsos differ in length)
	local headAt = torso.CFrame:PointToObjectSpace(head.Position)
	local item = Vector3.new(0.12 * s, headAt.Y - 1.05 * s, front)
	local lift = math.max(size.Y, 0.5) / 2
	local lhand = character:FindFirstChild("LeftHand") :: BasePart?
	local lgrip = if lhand then CFrame.new(0, -lhand.Size.Y / 2, 0) else CFrame.identity
	local ra = { reach(right, centre, item, 1, s) }
	local la = { reach(left, lgrip, item + Vector3.new(-0.12 * s, lift + 0.05 * s, 0.05 * s), -1, s) }
	local rb = { reach(right, centre, item + Vector3.new(0.3 * s, -0.05 * s, 0), 1, s) }
	local lb = { reach(left, lgrip, item + Vector3.new(-0.85 * s, -0.15 * s, 0.15 * s), -1, s) }
	local joints = { right.sh, right.el, right.wr, left.sh, left.el, left.wr }
	local a, b = {}, {}
	for i, j in ipairs(joints) do
		a[j] = if i <= 3 then ra[i] else la[i - 3]
		b[j] = if i <= 3 then rb[i] else lb[i - 3]
	end
	local old = tears[character]
	if old then for _, c in ipairs(old.copy) do c:Destroy() end end
	tears[character] = { t0 = os.clock(), joints = joints, a = a, b = b, base = if old then old.base else {}, last = if old then old.last else {}, copied = false, copy = {} }
end

-- the wrapper pieces (attribute Bite = 1) copied into the left hand
local function wrapperToHand(character: Model, tear: Tear)
	tear.copied = true
	local tool = character:FindFirstChildOfClass("Tool")
	local lhand = character:FindFirstChild("LeftHand") :: BasePart?
	if not tool or not lhand then return end
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Bite") == 1 then
			local c = p:Clone()
			for _, ch in ipairs(c:GetChildren()) do
				if ch:IsA("Decal") or ch:IsA("Texture") then
					ch.Transparency = 0
				elseif not (ch:IsA("SpecialMesh") or ch:IsA("SurfaceAppearance")) then
					ch:Destroy()
				end
			end
			local t0 = p:GetAttribute("BiteT0")
			c.Transparency = if typeof(t0) == "number" then t0 else p.Transparency
			c.Anchored = false
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.Massless = true
			c.CFrame = p.CFrame
			c.Parent = workspace
			local w = Instance.new("WeldConstraint")
			w.Part0 = lhand
			w.Part1 = c
			w.Parent = c
			table.insert(tear.copy, c)
		end
	end
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

RunService.PreSimulation:Connect(function()
	for character, tear in pairs(tears) do
		local t = os.clock() - tear.t0
		if not character.Parent then
			for _, c in ipairs(tear.copy) do c:Destroy() end
			tears[character] = nil
			continue
		end
		if t >= T_PULL and not tear.copied then wrapperToHand(character, tear) end
		-- the wrapper copy fades once it is off
		if t > T_PULLED then
			local f = math.clamp((t - T_PULLED) / (T_END - T_PULLED), 0, 1)
			for _, c in ipairs(tear.copy) do
				c.LocalTransparencyModifier = f
				for _, ch in ipairs(c:GetChildren()) do
					if ch:IsA("Decal") or ch:IsA("Texture") then ch.Transparency = f end
				end
			end
		end
		local done = t >= T_END
		for _, j in ipairs(tear.joints) do
			if not j.Parent then done = true break end
			local now = j.Transform
			local last = tear.last[j]
			if not last or not now:FuzzyEq(last, 1e-4) then tear.base[j] = now end
			local base = tear.base[j] or now
			local out
			if done then
				out = base
			elseif t < T_MEET then
				out = base:Lerp(tear.a[j], smooth(t / T_MEET))
			elseif t < T_PULL then
				out = tear.a[j]
			elseif t < T_PULLED then
				out = tear.a[j]:Lerp(tear.b[j], smooth((t - T_PULL) / (T_PULLED - T_PULL)))
			elseif t < T_DOWN then
				out = tear.b[j]
			else
				out = tear.b[j]:Lerp(base, smooth((t - T_DOWN) / (T_END - T_DOWN)))
			end
			j.Transform = out
			tear.last[j] = out
		end
		if done then
			for _, c in ipairs(tear.copy) do c:Destroy() end
			tears[character] = nil
		end
	end
end)

local function watch(character: Model)
	character:GetAttributeChangedSignal("Unwrap"):Connect(function()
		if character:FindFirstChild("UpperTorso") then startTear(character) end
	end)
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
		-- (D-1159, user 2026-11-10: "뭐 먹을 때 입 움직이는 거 구현") a head that can move
		-- its face (FaceControls, dynamic heads): the jaw chews while the food is up
		-- at the mouth and closes as the arm goes down; classic heads have no jaw
		local head = character:FindFirstChild("Head")
		local face = head and head:FindFirstChildOfClass("FaceControls")
		if face then
			local chew = 0.5 + 0.5 * math.sin(os.clock() * 13)
			local jaw = if done then 0 else a * (0.12 + 0.38 * chew)
			pcall(function()
				(face :: any).JawDrop = jaw
				;(face :: any).Pucker = if done then 0 else a * 0.25 * (1 - chew)
			end)
		end
		if done then rigs[character] = nil end
	end
end)
