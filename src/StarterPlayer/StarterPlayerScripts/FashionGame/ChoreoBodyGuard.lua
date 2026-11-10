--!strict
-- (D-1168, user 2026-11-10: "팔이 몸통 통과하는 거 방지할 수 있나 캐릭터 체형마다 달라서 … 캐릭터 체형 여러개인 거에
-- 다 맞춰서 몸통 통과 못 하게 할 수 있으면 팔끼리 교차되는 것도 수정. 물리적으로 안 되는 거잖아. … 손바닥이랑 손바닥
-- 만나면 손바닥끼리 부딪혀서 멈춰 있지. 투명처럼 통과하지는 않음.")
-- Every frame of a choreography, after all the other fixes: the arm is followed down from the hips with
-- this avatar's own joints and part sizes (so every body type is measured as it is), and
--   * an elbow, forearm or hand inside the upper or lower torso (grown by the limb's thickness) is pushed
--     out the nearest way it can go (its own side, the front or the back) by turning the shoulder just
--     that far;
--   * two forearms / hands that would pass through each other are pushed apart, half each, so they
--     meet and stop instead of crossing.
-- The turn eases in and out (no pop), and nothing changes while the arms are clear.
-- Studio switch: FashionGame attribute ChoreoBodyGuardOff.

local BodyGuard = {}

type Joint = Motor6D | AnimationConstraint

local state: {[Model]: {[string]: Vector3}} = setmetatable({}, { __mode = "k" }) :: any
BodyGuard.stats = { frames = 0, pushed = 0, crossed = 0 }

-- the joint's frame in the world (pivot) and the world CFrame of its Part1, from Part0's CFrame
local function frames(j: Joint, part0: CFrame): (CFrame, CFrame)
	if j:IsA("Motor6D") then
		local m = j :: Motor6D
		local pivot = part0 * m.C0
		return pivot, pivot * m.Transform * m.C1:Inverse()
	else
		local a = j :: AnimationConstraint
		local a0, a1 = a.Attachment0, a.Attachment1
		local pivot = part0 * (if a0 then a0.CFrame else CFrame.identity)
		return pivot, pivot * a.Transform * (if a1 then a1.CFrame:Inverse() else CFrame.identity)
	end
end

-- the frame of the Part1 side of a joint, as an offset from Part1 (elbow / wrist pivots)
local function childOffset(j: Joint): CFrame
	if j:IsA("Motor6D") then return (j :: Motor6D).C1 end
	local a1 = (j :: AnimationConstraint).Attachment1
	return if a1 then a1.CFrame else CFrame.identity
end

local function closestOnSegments(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (Vector3, Vector3)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t = 0, 0
	if a > 1e-6 and e > 1e-6 then
		local c, b = d1:Dot(r), d1:Dot(d2)
		local den = a * e - b * b
		s = if den > 1e-6 then math.clamp((b * f - c * e) / den, 0, 1) else 0
		t = (b * s + f) / e
		if t < 0 then t, s = 0, math.clamp(-c / a, 0, 1) elseif t > 1 then t, s = 1, math.clamp((b - c) / a, 0, 1) end
	end
	return p1 + d1 * s, p2 + d2 * t
end

function BodyGuard.apply(character: Model, joints: {[string]: Joint})
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ut, lt = character:FindFirstChild("UpperTorso") :: BasePart?, character:FindFirstChild("LowerTorso") :: BasePart?
	local jRoot, jWaist = joints.LowerTorso, joints.UpperTorso
	if not (root and ut and lt and jRoot and jWaist) then return end
	BodyGuard.stats.frames += 1
	local _, ltCF = frames(jRoot, root.CFrame)
	local _, utCF = frames(jWaist, ltCF)
	local boxes = { { utCF, ut.Size }, { ltCF, lt.Size } }
	local s = state[character]
	if not s then s = {} state[character] = s end

	local arms = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local jS, jE, jW = joints[side .. "UpperArm"], joints[side .. "LowerArm"], joints[side .. "Hand"]
		local la, hand = character:FindFirstChild(side .. "LowerArm") :: BasePart?, character:FindFirstChild(side .. "Hand") :: BasePart?
		if jS and jE and jW and la and hand then
			local pivot, uaCF = frames(jS, utCF)
			local _, laCF = frames(jE, uaCF)
			local _, hCF = frames(jW, laCF)
			local elbow = (laCF * childOffset(jE)).Position
			local wrist = (hCF * childOffset(jW)).Position
			arms[side] = { joint = jS, pivot = pivot, elbow = elbow, wrist = wrist, hand = hCF.Position,
				r = math.min(la.Size.X, la.Size.Z) * 0.5, rh = math.min(hand.Size.X, hand.Size.Z) * 0.5, sign = if side == "Left" then -1 else 1,
				push = Vector3.zero, at = elbow }
		end
	end

	-- 1) out of the torso: the deepest of elbow / mid forearm / hand, the shortest way out on its own side
	for _, arm in pairs(arms) do
		local best, bestPoint = Vector3.zero, arm.elbow
		for _, pr in ipairs({ { arm.elbow, arm.r }, { (arm.elbow + arm.wrist) / 2, arm.r }, { arm.hand, arm.rh } }) do
			local p, r = pr[1], pr[2]
			for _, box in ipairs(boxes) do
				local cf, size = box[1], box[2]
				local q = cf:PointToObjectSpace(p)
				local h = size / 2 + Vector3.new(r, 0, r) * 0.8
				if math.abs(q.X) < h.X and math.abs(q.Y) < h.Y and math.abs(q.Z) < h.Z then
					-- ways out: its own side (x), the front (-z), the back (+z)
					local side = h.X - q.X * arm.sign
					local front, back = q.Z + h.Z, h.Z - q.Z
					local d
					if side <= front and side <= back then d = Vector3.new(arm.sign * side, 0, 0)
					elseif front <= back then d = Vector3.new(0, 0, -front)
					else d = Vector3.new(0, 0, back) end
					local w = cf:VectorToWorldSpace(d)
					if w.Magnitude > best.Magnitude then best, bestPoint = w, p end
				end
			end
		end
		arm.push, arm.at = best, bestPoint
	end

	-- 2) the two forearms / hands meet instead of passing through (half each)
	local L, R = arms.Left, arms.Right
	if L and R then
		local a, b = closestOnSegments(L.elbow, L.hand, R.elbow, R.hand)
		local gap = (b - a).Magnitude
		local need = (L.r + R.r) * 0.9
		if gap < need then
			local n = if gap > 1e-3 then (b - a) / gap else utCF.RightVector
			local o = (need - gap) / 2
			if L.push.Magnitude < o then L.push, L.at = -n * o, a end
			if R.push.Magnitude < o then R.push, R.at = n * o, b end
			BodyGuard.stats.crossed += 1
		end
	end

	-- 3) the shoulder turns so that point moves by its push (eased over a few frames, in the chest's frame)
	for side, arm in pairs(arms) do
		local target = Vector3.zero
		local v = arm.at - arm.pivot.Position
		if arm.push.Magnitude > 1e-3 and v.Magnitude > 0.2 then
			local axis = v:Cross(arm.push)
			if axis.Magnitude > 1e-4 then
				local angle = math.min(arm.push.Magnitude / v.Magnitude, 0.8)
				target = utCF:VectorToObjectSpace(axis.Unit * angle)
			end
			BodyGuard.stats.pushed += 1
		end
		local cur = s[side] or Vector3.zero
		-- (a push the other way round than the turn already on, e.g. two forearms that crossed over, keeps
		-- the turn's way: flipping it threw the hand 0.9 stud in a frame)
		if cur.Magnitude > 0.02 and target.Magnitude > 0 and target:Dot(cur) < 0 then target = cur.Unit * target.Magnitude end
		-- in faster than out, and at most 2.5° a frame either way (no pop)
		local step = (target - cur) * (if target.Magnitude > cur.Magnitude then 0.35 else 0.15)
		if step.Magnitude > 0.044 then step = step.Unit * 0.044 end
		cur += step
		if cur.Magnitude < 1e-3 then cur = Vector3.zero end
		s[side] = cur
		if cur.Magnitude > 0 then
			local w = utCF:VectorToWorldSpace(cur)
			local rot = CFrame.fromAxisAngle(w.Unit, w.Magnitude)
			local pivot = arm.pivot
			local frame = pivot.Rotation
			arm.joint.Transform = (frame:Inverse() * rot * frame) * arm.joint.Transform
		end
	end
end

return BodyGuard
