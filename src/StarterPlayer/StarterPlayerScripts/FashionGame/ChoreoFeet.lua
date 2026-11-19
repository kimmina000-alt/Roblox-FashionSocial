-- (D-1905, user 2026-11-19: "발 고정(IK) 기능 만들기") A planted foot stays where it touched the floor.
-- The dance moves the body (the capture's travel, `glide` / `walk`, the drift back home) while the
-- animation keeps the legs as they were, so a foot on the floor slid along with the body ("디딘 발
-- 미끄러짐", Unbelievable 0:09.8 0.4-0.9 studs). Inside a ChoreoFixes `plant = { from, to }` window
-- (piece seconds, or a list of them), each foot whose sole is on the floor keeps the floor spot
-- (x, z) it touched: the leg is bent to it with a two-bone IK (hip -> knee -> ankle, the knee kept
-- on the side it points to), the foot keeps its own turn. A foot that lifts lets go over 0.12 s;
-- a foot pulled more than 1.2 studs from its spot (a real slide in the dance, a long stride)
-- lets go over 0.3 s, and at the window's end over 0.5 s (D-1907). Runs last in ChoreoController's PreSimulation, on the joints the frame ends with.
local ChoreoFeet = {}

local CONTACT = 0.18 -- sole within this of the floor = on the floor
local LET_GO = 0.12 -- seconds to ease back to the animation after the foot lifts
local STRETCH = 1.2 -- studs from its spot: let go
-- (D-1932) a held foot the dance moves this far along the floor steps there instead (lifted, not slid)
local STEP = 0.35
local STEP_TIME = 0.2
-- (D-1937: was 0.6 on top of the dance's own foot height, which folded the knee 30-60 degrees; D-1938: the sole clears
-- the floor by this much at the top of a step, nothing added where the dance already lifts it that high)
local STEP_LIFT = 0.3
local KNEE_MORE = 20 -- (D-1937) degrees the hold may bend the knee past the dance's own

type Joint = Motor6D | AnimationConstraint
type FootState = { spot: Vector3?, w: number, letGo: number?, lifted: boolean?, stepFrom: Vector3?, stepT: number?, stepLift: number?, arc: number? }
local states: {[Model]: {[string]: FootState}} = setmetatable({}, { __mode = "k" }) :: any

-- the child part's frame from its parent's frame and the joint
local function childOf(j: Joint, parentCF: CFrame): CFrame
	if j:IsA("Motor6D") then
		return parentCF * j.C0 * j.Transform * j.C1:Inverse()
	end
	local a = j :: AnimationConstraint
	return parentCF * (a.Attachment0 :: Attachment).CFrame * a.Transform * (a.Attachment1 :: Attachment).CFrame:Inverse()
end

-- the joint's pivot in the world (on the parent side)
local function pivotOf(j: Joint, parentCF: CFrame): Vector3
	if j:IsA("Motor6D") then return (parentCF * j.C0).Position end
	return (parentCF * ((j :: AnimationConstraint).Attachment0 :: Attachment).CFrame).Position
end

-- the Transform that puts the child at childCF under parentCF
local function transformFor(j: Joint, parentCF: CFrame, childCF: CFrame): CFrame
	if j:IsA("Motor6D") then
		return j.C0:Inverse() * parentCF:Inverse() * childCF * j.C1
	end
	local a = j :: AnimationConstraint
	return (a.Attachment0 :: Attachment).CFrame:Inverse() * parentCF:Inverse() * childCF * (a.Attachment1 :: Attachment).CFrame
end

-- the smallest turn taking direction a to direction b
local function turnBetween(a: Vector3, b: Vector3): CFrame
	a, b = a.Unit, b.Unit
	local axis = a:Cross(b)
	local s = axis.Magnitude
	if s < 1e-6 then return CFrame.identity end
	return CFrame.fromAxisAngle(axis / s, math.atan2(s, a:Dot(b)))
end

-- a world turn `r` about point `p`, applied to frame `cf`
local function turnAbout(cf: CFrame, r: CFrame, p: Vector3): CFrame
	return CFrame.new(p) * r * CFrame.new(-p) * cf
end

-- the window at t (nil outside)
local function inWindow(windows: any, t: number): any
	for _, w in ipairs(if windows.from then { windows } else windows) do
		if t >= w.from and t < w.to then return w end
	end
	return nil
end

-- is any playing piece inside its `plant` window (weight over half)? and that window's `contact`
-- (D-1909: studs above the floor that still count as on it; a bent-over capture hovers its feet 0.3-0.4 up)
function ChoreoFeet.active(choreo: {AnimationTrack}, fixesOf: (string) -> any): (boolean, number?, boolean?)
	for _, t in ipairs(choreo) do
		if t.WeightCurrent > 0.5 and t.Animation then
			local fx = fixesOf(t.Animation.AnimationId)
			local w = fx and fx.plant and inWindow(fx.plant, t.TimePosition)
			if w then return true, w.contact, w.noStep end
		end
	end
	return false, nil, nil
end

-- `noStep` (D-1932): the video keeps the foot where it is, so a held foot is never stepped, only let go when pulled 2 studs
function ChoreoFeet.apply(character: Model, joints: {[string]: Joint}, active: boolean, floorY: number?, dt: number, contact: number?, noStep: boolean?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hips = joints.LowerTorso
	if not root or not hips or not floorY or floorY == -math.huge then states[character] = nil return end
	local mine = states[character]
	if not active and not mine then return end
	if not mine then mine = {} states[character] = mine end
	local lowerCF = childOf(hips, root.CFrame)
	local anyHeld = false
	for _, side in ipairs({ "Left", "Right" }) do
		local hip, knee, ankle = joints[side .. "UpperLeg"], joints[side .. "LowerLeg"], joints[side .. "Foot"]
		local footPart = character:FindFirstChild(side .. "Foot") :: BasePart?
		if not (hip and knee and ankle and footPart) then continue end
		local upperCF = childOf(hip, lowerCF)
		local shinCF = childOf(knee, upperCF)
		local footCF = childOf(ankle, shinCF)
		local H = pivotOf(hip, lowerCF)
		local K = pivotOf(knee, upperCF)
		local A = pivotOf(ankle, shinCF)
		-- the sole: the lowest corner of the foot box
		local size = footPart.Size
		local half = math.abs(footCF.RightVector.Y) * size.X / 2 + math.abs(footCF.UpVector.Y) * size.Y / 2 + math.abs(footCF.LookVector.Y) * size.Z / 2
		local sole = footCF.Position.Y - half - floorY -- (D-1937) how high the dance has the foot
		local onFloor = sole < (contact or CONTACT)
		local st = mine[side]
		if not st then st = { spot = nil, w = 0, letGo = nil } mine[side] = st end
		-- a foot that lifted and is down again is held at once where it landed (only a pulled foot waits to be let go)
		if active and onFloor and st.letGo and st.lifted then st.spot, st.w, st.letGo, st.lifted, st.arc = A, 1, nil, nil, nil end
		if active and onFloor and not st.letGo then
			if not st.spot or st.w < 1 then st.spot, st.w = A, 1 end
			-- (D-1932, 2nd review of Lemonade D-1931: 27 places where the video lifts the foot and puts it down elsewhere slid
			-- along the floor in the game) the dance carrying a held foot STEP studs off its spot = a step: the foot is lifted
			-- and carried to the new spot over STEP_TIME (planted again there), instead of sliding or being dragged
			local away = Vector2.new(st.spot.X - A.X, st.spot.Z - A.Z).Magnitude
			if not noStep and not st.stepFrom and away > STEP then st.stepFrom, st.stepT, st.stepLift = st.spot, 0, nil end
			-- (D-1907) pulled too far: eased off over 0.3 s, then held again where it is (it jumped 1.2 studs in a frame)
			if not st.stepFrom and away > (if noStep then 2 else STRETCH) then st.letGo = 0.3 end
		elseif st.spot and not st.letGo then
			-- lifted: LET_GO; the window over: 0.5 s (the body has gone on, the foot catches up slowly)
			st.letGo = if active then LET_GO else 0.5
			st.lifted = active
		end
		if st.spot and st.letGo then
			st.w -= dt / st.letGo
			if st.w <= 0 then st.spot, st.w, st.letGo, st.lifted, st.stepFrom, st.stepT, st.stepLift, st.arc = nil, 0, nil, nil, nil, nil, nil, nil end
		end
		if not st.spot then continue end
		anyHeld = true
		local e = st.w * st.w * (3 - 2 * st.w)
		-- only the floor position is held; the height follows the dance
		local T = Vector3.new(A.X + (st.spot.X - A.X) * e, A.Y, A.Z + (st.spot.Z - A.Z) * e)
		-- (D-1933, Lemonade 0:31.4: a foot the dance only just lifted slid 0.86 studs back to it, under 0.2 high) a lifted foot
		-- being let go is carried over in the air, 0.4 up at the middle
		-- (D-1937) only as far up as the dance does not already have it: 0.25 above the floor at most
		if st.letGo and st.lifted then
			st.arc = st.arc or math.max(0, 0.25 - sole)
			T += Vector3.new(0, math.sin((1 - st.w) * math.pi) * (st.arc :: number), 0)
		end
		if st.stepFrom then
			-- (D-1932) a step: from the old spot to where the dance has the foot now, lifted on the way
			st.stepT = (st.stepT or 0) + dt / STEP_TIME
			local u = math.min(st.stepT :: number, 1)
			local k = u * u * (3 - 2 * u)
			local from = st.stepFrom :: Vector3
			-- (D-1938, 2nd review of D-1937: half the step's length less the dance's own lift barely lifted it, 26 steps
			-- dragged along the floor) the sole goes STEP_LIFT above the floor at the top, less what the dance already lifts it
			st.stepLift = st.stepLift or math.max(0, STEP_LIFT - math.max(sole, 0))
			T = Vector3.new(from.X + (A.X - from.X) * k, A.Y + math.sin(u * math.pi) * (st.stepLift :: number), from.Z + (A.Z - from.Z) * k)
			if u >= 1 then st.spot, st.stepFrom, st.stepT, st.stepLift = A, nil, nil, nil end
		end
		local l1, l2 = (K - H).Magnitude, (A - K).Magnitude
		-- (D-1937, 2nd review of BANG D-1936: knees 20-45 degrees more bent than the video in 12 places; holding the
		-- foot while the hips go down or the body moves on folded the leg) the knee angle the hold needs against the
		-- dance's own: KNEE_MORE degrees more bent and the held foot steps to where the dance has it (or, noStep, lets go)
		if not st.stepFrom and not st.letGo then
			local function knee(d: number): number
				return math.deg(math.acos(math.clamp((l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2), -1, 1)))
			end
			if knee((A - H).Magnitude) - knee((T - H).Magnitude) > KNEE_MORE then
				if noStep then st.letGo, st.lifted = 0.3, nil else st.stepFrom, st.stepT = st.spot, 0 end
				continue
			end
		end
		if (T - A).Magnitude < 0.005 then continue end
		local d = math.clamp((T - H).Magnitude, math.abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
		local u = (T - H).Unit
		T = H + u * d
		-- the knee stays on the side it points to now
		local toKnee = K - H
		local pole = toKnee - u * toKnee:Dot(u)
		if pole.Magnitude < 1e-4 then pole = lowerCF.LookVector - u * lowerCF.LookVector:Dot(u) end
		pole = pole.Unit
		local along = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
		local K2 = H + u * along + pole * math.sqrt(math.max(l1 * l1 - along * along, 0))
		-- thigh: turned about the hip so the knee goes to K2
		local r1 = turnBetween(K - H, K2 - H)
		local upper2 = turnAbout(upperCF, r1, H)
		local shin1 = turnAbout(shinCF, r1, H)
		local A1 = r1 * (A - H) + H
		-- shin: turned about the knee so the ankle goes to T
		local r2 = turnBetween(A1 - K2, T - K2)
		local shin2 = turnAbout(shin1, r2, K2)
		-- the foot keeps its own turn in the world, at the new ankle
		local ankle2 = pivotOf(ankle, shin2)
		local foot2 = CFrame.new(ankle2 - A) * footCF
		hip.Transform = transformFor(hip, lowerCF, upper2)
		knee.Transform = transformFor(knee, upper2, shin2)
		ankle.Transform = transformFor(ankle, shin2, foot2)
	end
	if not active and not anyHeld then states[character] = nil end
end

return ChoreoFeet
