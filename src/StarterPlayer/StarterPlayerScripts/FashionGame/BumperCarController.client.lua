--!strict
-- (D-1413) Bumper cars on the client (BumperCarConfig; the server side: BumperCarService).
--   * Driving: while this player sits in a bumper car's seat, the car is simulated here and
--     moved every frame (this client owns it): pedal = the on-screen pedal / W (D-1826; until then
--     seat.ThrottleFloat, W / S, the stick),
--     wheel = seat.SteerFloat (A / D). The drive wheel pushes the car along the wheel's
--     direction from a point ahead of the centre, so a turned wheel curves the car and a wheel
--     turned all the way spins it on the spot, like a real one.
--   * The rubber ring: every other car (driven or parked) and the hall's rails push back with a
--     damped spring where the rings overlap; off-centre hits spin the car. A parked car does
--     not move (it counts as a wall); a driven car is moved by its own driver's client the same
--     way, so both cars bounce apart.
--   * "퉁": every car's body rocks and hops on its weld after a hit, with a thud (all cars, on
--     every client, from the cars' replicated positions).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BumperCarConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("BumperCarConfig"))
local C = BumperCarConfig

local player = Players.LocalPlayer
local K, DAMP = C.spring()

---------------------------------------------------------------- geometry
type Car = { root: BasePart, half: number, r: number } -- capsule: a segment ±half along the car, radius r

local function carShape(root: BasePart): Car
	local L = (root:GetAttribute("Length") :: number?) or root.Size.X
	local W = (root:GetAttribute("Width") :: number?) or root.Size.Z
	return { root = root, half = math.max(0, L / 2 - W / 2), r = W / 2 }
end

local function segEnds(p: Vector3, fwd: Vector3, half: number): (Vector3, Vector3)
	return p + fwd * half, p - fwd * half
end

-- closest points between segments a0-a1 and b0-b1 (on the floor plane)
local function closest(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3): (Vector3, Vector3)
	local d1, d2, r = a1 - a0, b1 - b0, a0 - b0
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a < 1e-6 and e < 1e-6 then return a0, b0 end
	if a < 1e-6 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e < 1e-6 then
			t, s = 0, math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local den = a * e - b * b
			s = if den > 1e-6 then math.clamp((b * f - c * e) / den, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then t, s = 0, math.clamp(-c / a, 0, 1)
			elseif t > 1 then t, s = 1, math.clamp((b - c) / a, 0, 1) end
		end
	end
	return a0 + d1 * s, b0 + d2 * t
end

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

---------------------------------------------------------------- the body's rock and hop (all cars)
type Wobble = { pitch: number, roll: number, hop: number, vp: number, vr: number, vh: number, weld: Weld?, base: CFrame?, lastHit: number }
local wobbles: {[BasePart]: Wobble} = {}

local function wobbleOf(root: BasePart): Wobble
	local w = wobbles[root]
	if not w then
		w = { pitch = 0, roll = 0, hop = 0, vp = 0, vr = 0, vh = 0, weld = nil, base = nil, lastHit = 0 }
		wobbles[root] = w
	end
	return w
end

local function playThud(at: BasePart, speed: number)
	local s = Instance.new("Sound")
	s.SoundId = C.BumpSoundId
	s.Volume = math.clamp(0.25 + speed / 14, 0.3, 1.1)
	s.PlaybackSpeed = 0.85 + math.random() * 0.2
	s.RollOffMaxDistance = 90
	s.Parent = at
	s:Play()
	game:GetService("Debris"):AddItem(s, 3)
end

-- (D-1829, a bumper car review the user sent: "충돌 시 시각 효과") a hard hit flashes at the contact point: a
-- burst of sparks and stars and a quick light, bigger with the speed (each screen draws its own)
local SPARK_MIN = 6 -- closing speed (studs/s) for the burst
local function burst(at: Vector3, speed: number)
	if speed < SPARK_MIN then return end
	local p = Instance.new("Part")
	p.Name = "BumpBurst"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
	p.Parent = workspace
	local k = math.clamp(speed / 30, 0.3, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(Color3.fromRGB(255, 245, 170), Color3.fromRGB(255, 150, 60))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55 + k * 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.18, 0.4)
	e.Speed = NumberRange.new(8 + k * 8, 14 + k * 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-360, 360)
	e.Parent = p
	e:Emit(math.floor(10 + 18 * k))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 10 + 8 * k
	light.Brightness = 3
	light.Parent = p
	task.delay(0.12, function() light.Enabled = false end)
	game:GetService("Debris"):AddItem(p, 1)
end

-- a hit at world point `at` with the push direction `n` (into this car) and closing speed
local function kick(root: BasePart, at: Vector3, n: Vector3, speed: number, noBurst: boolean?)
	local w = wobbleOf(root)
	local now = os.clock()
	if now - w.lastHit < 0.25 then return end
	w.lastHit = now
	-- the body leans away from the hit (the ring compresses on that side) and hops a little
	local nl = root.CFrame:VectorToObjectSpace(n)
	local k = math.min(speed, 14) * C.WobbleKick
	w.vp += nl.X * k * C.WobbleFreq -- a push towards -X (from the front) tips the nose up
	w.vr += -nl.Z * k * C.WobbleFreq
	w.vh += math.min(speed, 14) * C.WobbleHop * C.WobbleFreq
	playThud(root, speed)
	if not noBurst then burst(at, speed) end
end

local function stepWobble(w: Wobble, dt: number)
	local f2, d = C.WobbleFreq * C.WobbleFreq, C.WobbleDamp
	w.vp += (-f2 * w.pitch - d * w.vp) * dt
	w.vr += (-f2 * w.roll - d * w.vr) * dt
	w.vh += (-f2 * w.hop - d * w.vh) * dt
	w.pitch += w.vp * dt
	w.roll += w.vr * dt
	w.hop = math.max(0, w.hop + w.vh * dt)
end

---------------------------------------------------------------- driving (this player's car)
type Drive = { root: BasePart, seat: VehicleSeat, pos: Vector3, vel: Vector3, yaw: number, spin: number, wheel: number, reversing: boolean? }
local drive: Drive? = nil
local contacts: {[BasePart]: boolean} = {} -- (rings touching last frame: sound once per hit)
local coneHit: {[Instance]: number} = {} -- (D-1827: when this car last knocked each cone)
local ConeRemote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("BumperCone") :: RemoteEvent

-- the car's heading from its +X (Euler angles of a turn near 180° can come back as 0 with flips)
local function yawOf(cf: CFrame): number
	local r = cf.RightVector
	return math.atan2(-r.Z, r.X)
end

local function startDrive(seat: VehicleSeat)
	local model = seat.Parent
	local root = model and model:FindFirstChild("BumperRoot") :: BasePart?
	if not root then return end
	drive = { root = root, seat = seat, pos = root.Position, vel = Vector3.zero, yaw = yawOf(root.CFrame), spin = 0, wheel = 0 }
	contacts = {}
end

---------------------------------------------------------------- the pedal
-- (D-1826, user 2026-11-19: "범퍼카 가운데 하단에 페달 넣자. 이거 눌러야 앞으로 가는 걸로") like a real bumper car the
-- car goes only while the pedal is down: a pedal at the bottom middle of the screen (held with a finger or
-- the mouse; on a keyboard W / ↑ press it too). The stick (A / D, or the camera way) only turns the wheel;
-- the pedal alone drives straight on. Only the driver sees it.
local playerGui = player:WaitForChild("PlayerGui")
local pedalGui = Instance.new("ScreenGui")
pedalGui.Name = "BumperPedal"
pedalGui.ResetOnSpawn = false
pedalGui.DisplayOrder = 31
pedalGui.Enabled = false
pedalGui.Parent = playerGui
local pedal = Instance.new("TextButton")
pedal.Name = "Pedal"
pedal.Text = ""
pedal.AutoButtonColor = false
pedal.AnchorPoint = Vector2.new(0.5, 1)
pedal.Size = UDim2.fromOffset(74, 100)
pedal.BackgroundColor3 = Color3.fromRGB(36, 38, 44)
pedal.Parent = pedalGui
Instance.new("UICorner", pedal).CornerRadius = UDim.new(0, 16)
do
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(150, 154, 166)
	edge.Thickness = 2
	edge.Parent = pedal
end
-- the metal plate with its grip ridges (pressed: down and darker)
local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(0.5, 0.5)
plate.Position = UDim2.fromScale(0.5, 0.46)
plate.Size = UDim2.new(1, -18, 1, -26)
plate.BackgroundColor3 = Color3.fromRGB(176, 180, 190)
plate.BorderSizePixel = 0
plate.Parent = pedal
Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 10)
do
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.fromRGB(235, 238, 245), Color3.fromRGB(130, 134, 146))
	shade.Rotation = 90
	shade.Parent = plate
	for k = 1, 6 do
		local ridge = Instance.new("Frame")
		ridge.AnchorPoint = Vector2.new(0.5, 0.5)
		ridge.Position = UDim2.fromScale(0.5, k / 7)
		ridge.Size = UDim2.new(1, -14, 0, 3)
		ridge.BackgroundColor3 = Color3.fromRGB(60, 62, 70)
		ridge.BorderSizePixel = 0
		ridge.Parent = plate
		Instance.new("UICorner", ridge).CornerRadius = UDim.new(1, 0)
	end
end
-- the hinge at the foot
local hinge = Instance.new("Frame")
hinge.AnchorPoint = Vector2.new(0.5, 1)
hinge.Position = UDim2.new(0.5, 0, 1, -5)
hinge.Size = UDim2.new(1, -30, 0, 6)
hinge.BackgroundColor3 = Color3.fromRGB(90, 94, 104)
hinge.BorderSizePixel = 0
hinge.Parent = pedal
Instance.new("UICorner", hinge).CornerRadius = UDim.new(1, 0)

local pedalPlacedAt = 0
local pedalInput: InputObject? = nil -- (the touch / mouse holding it)
local pedalDown = false
local function showPedal()
	local down = pedalDown or (pedalInput ~= nil)
	plate.Position = UDim2.new(0.5, 0, 0.46, if down then 5 else 0)
	plate.Size = if down then UDim2.new(1, -24, 1, -32) else UDim2.new(1, -18, 1, -26)
	plate.BackgroundColor3 = if down then Color3.fromRGB(120, 210, 140) else Color3.fromRGB(176, 180, 190)
end
pedal.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		pedalInput = input
		showPedal()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if pedalInput and (input == pedalInput or (input.UserInputType == Enum.UserInputType.MouseButton1 and pedalInput.UserInputType == Enum.UserInputType.MouseButton1)) then
		pedalInput = nil
		showPedal()
	end
end)
local function keyPedal(): boolean
	if UserInputService:GetFocusedTextBox() then return false end
	-- (D-1828: S / ↓ too, for backing up on a keyboard)
	return UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
		or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
end
-- over the item bar (and the ride bar's buttons) at the bottom middle
local function placePedal()
	local low = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 24 else 110
	for _, name in ipairs({ "FashionHotbar", "ParkRideGui" }) do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			local screenH = g.AbsoluteSize.Y
			for _, o in ipairs(g:GetDescendants()) do
				if o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.Y > 0 and o.AbsoluteSize.Y < screenH * 0.4
					and o.AbsolutePosition.Y > screenH * 0.6 and o.AbsolutePosition.Y < screenH
					and math.abs(o.AbsolutePosition.X + o.AbsoluteSize.X / 2 - g.AbsoluteSize.X / 2) < o.AbsoluteSize.X / 2 + 40 then
					local top = o.AbsolutePosition.Y
					local p = o.Parent
					local shown = true
					while p and p ~= g do
						if p:IsA("GuiObject") and not p.Visible then shown = false break end
						p = p.Parent
					end
					if shown then low = math.max(low, math.ceil(screenH - top) + 10) end
				end
			end
		end
	end
	pedal.Position = UDim2.new(0.5, 0, 1, -low)
end

local function forwardOf(yaw: number): Vector3
	return Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) -- the car's +X at this yaw
end

---------------------------------------------------------------- steering
-- (D-1666, user 2026-11-17: "범퍼카 회전은 원래 오른쪽 드래그하면 회전됐던 기능 사용 < > 버튼 삭제 기능 삭제")
-- the ◀ ▶ phone buttons of D-1564 are gone: the wheel follows the stick / A D again (seat.SteerFloat),
-- on phones too (push the stick right to turn right)

-- (D-1703, user 2026-11-17: "범퍼카 탔을 때 모바일 예시로 왼쪽 하단에서 앞으로 직진 방향으로 누르면서 오른쪽 화면에서
-- 오른쪽으로 화면 회전하면 그 방향으로 직진하게 구현") the car drives like walking: the stick (W A S D) points
-- a way on the screen, seen from the camera; the car turns its wheel towards that way and drives there
-- (drag the screen to turn the camera and the car follows it). No stick: the pedal is up, the car rolls
-- to a stop. The stick is read from the seat (the default controls put its forward / right there as
-- ThrottleFloat / SteerFloat; this place has no PlayerModule to ask).
local function moveWish(seat: VehicleSeat): Vector3?
	local mv = Vector3.new(seat.SteerFloat, 0, -seat.ThrottleFloat)
	if mv.Magnitude < 0.12 then return nil end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
	if look.Magnitude < 1e-3 or right.Magnitude < 1e-3 then return nil end
	local wish = look.Unit * -mv.Z + right.Unit * mv.X
	if wish.Magnitude < 1e-3 then return nil end
	return wish.Unit * math.min(1, mv.Magnitude)
end

local function simulate(d: Drive, dt: number)
	local me = carShape(d.root)
	local L = (d.root:GetAttribute("Length") :: number?) or d.root.Size.X
	local W = me.r * 2
	local inertia = (L * L + W * W) / 12 -- per unit mass
	local hall = C.Hall

	-- the wheel follows A / D, and comes back by itself
	-- (D-1703) towards the stick's way on the screen: the wheel turns by how far the car still has
	-- to turn (positive wheel = to the right = the heading going down), the pedal by the stick
	local steer, pedal = 0, 0
	local wish = moveWish(d.seat)
	-- (D-1828, user 2026-11-19: "후진 넣을까" → picked the real bumper car way) the stick pulled back (the way
	-- it points is behind the car: more than 120° off its nose; it stays in reverse until within 60°) with the
	-- pedal down backs the car up, as a real one does with its drive wheel turned round: slower
	-- (ReverseFactor), and steering so the car's tail swings towards the stick's way
	local diff = 0
	if wish then
		local want = math.atan2(-wish.Z, wish.X)
		diff = (want - d.yaw + math.pi) % (2 * math.pi) - math.pi
		local off = math.abs(diff)
		if d.reversing then
			if off < math.rad(60) then d.reversing = false end
		elseif off > math.rad(120) then
			d.reversing = true
		end
	else
		d.reversing = false
	end
	if wish then
		if d.reversing then
			-- (the tail towards the way: the heading wants want + 180°; backing up turns the car the other way)
			local back = (diff + 2 * math.pi) % (2 * math.pi) - math.pi
			steer = math.clamp(back / (C.WheelMax * 0.6), -1, 1)
		else
			steer = math.clamp(-diff / (C.WheelMax * 0.6), -1, 1)
		end
	end
	-- (D-1826) only the pedal drives
	if pedalInput ~= nil or pedalDown then pedal = if d.reversing then -C.ReverseFactor else 1 end
	local target = math.clamp(steer, -1, 1) * C.WheelMax
	local step = C.WheelRate * dt
	d.wheel += math.clamp(target - d.wheel, -step, step)

	local fwd = forwardOf(d.yaw)
	local side = Vector3.new(-fwd.Z, 0, fwd.X) -- across the car
	local force = Vector3.zero
	local torque = 0

	-- the drive wheel: a push along the wheel's direction at the wheel (ahead of the centre)
	if pedal ~= 0 then
		local wheelDir = forwardOf(d.yaw - d.wheel) -- (A = SteerFloat -1: wheel to the left)
		local speedAlong = d.vel:Dot(wheelDir)
		local room = math.clamp(1 - speedAlong * math.sign(pedal) / C.MaxSpeed, 0, 1)
		local f = wheelDir * (C.Accel * pedal * room)
		force += f
		local arm = fwd * (L * C.DriveAhead)
		torque += arm:Cross(f).Y
	end
	-- floor: rolls along, grips across, spin dies down
	local vF, vS = d.vel:Dot(fwd), d.vel:Dot(side)
	force += -fwd * vF * C.RollDrag - side * vS * C.SideGrip
	torque += -d.spin * C.SpinDrag * inertia

	-- the rubber ring against the other cars
	local here = flat(d.pos) -- (all the ring maths on the floor plane)
	local a0, a1 = segEnds(here, fwd, me.half)
	local touching: {[BasePart]: boolean} = {}
	for _, other in ipairs(CollectionService:GetTagged(C.RootTag)) do
		if other ~= d.root and other:IsA("BasePart") and other:IsDescendantOf(workspace) then
			local o = carShape(other)
			local op = flat(other.Position)
			if (op - here).Magnitude < me.half + o.half + me.r + o.r + 1 then
				local ofwd = flat(other.CFrame.RightVector)
				local b0, b1 = segEnds(op, ofwd, o.half)
				local pa, pb = closest(a0, a1, b0, b1)
				local delta = pa - pb
				local dist = delta.Magnitude
				local overlap = me.r + o.r - dist
				if overlap > 0 and dist > 1e-4 then
					local n = delta / dist -- from the other car into this one
					local contact = pb + n * o.r
					local rA = contact - here
					local vA = d.vel + Vector3.new(0, d.spin, 0):Cross(rA) -- (the point's velocity: spin × arm)
					local vB = if other.Anchored then Vector3.zero else flat(other.AssemblyLinearVelocity)
					local vRel = vA - vB
					local vn = vRel:Dot(n)
					local fn = math.max(0, K * overlap - DAMP * vn)
					-- an empty car stands still (a wall: this car takes the whole push); a driven one is
					-- pushed back the same by its own driver's client, so each takes half (the pair
					-- then bounces with the contact time and restitution of BumperCarConfig)
					local share = if other.Anchored then 1 else 0.5
					local push = n * fn * share
					-- rubber friction along the ring: spins the cars on a glancing hit
					local vt = vRel - n * vn
					local tf = Vector3.zero
					if vt.Magnitude > 0.05 then tf = -vt.Unit * math.min(C.RingFriction * fn, vt.Magnitude / dt * 0.5) * share end
					force += push + tf
					torque += rA:Cross(push + tf).Y
					touching[other] = true
					if not contacts[other] and -vn > C.BumpSoundMin then
						kick(d.root, contact, n, -vn)
					end
				end
			end
		end
	end
	-- the rails (walls) of the hall
	for _, p in ipairs({ a0, a1 }) do
		for _, wall in ipairs({
			{ Vector3.new(1, 0, 0), p.X - me.r - hall.x0 },
			{ Vector3.new(-1, 0, 0), hall.x1 - (p.X + me.r) },
			{ Vector3.new(0, 0, 1), p.Z - me.r - hall.z0 },
			{ Vector3.new(0, 0, -1), hall.z1 - (p.Z + me.r) },
		}) do
			local n, gap = wall[1] :: Vector3, wall[2] :: number
			if gap < 0 then
				local rA = (p - n * me.r) - here
				local vA = d.vel + Vector3.new(0, d.spin, 0):Cross(rA)
				local vn = vA:Dot(n)
				local fn = math.max(0, K * -gap - DAMP * vn)
				local push = n * fn
				force += push
				torque += rA:Cross(push).Y
				if vn < -C.BumpSoundMin and not contacts[n :: any] then
					kick(d.root, p - n * me.r, n, -vn)
				end
				touching[n :: any] = true
			end
		end
	end
	-- (D-1826 / D-1827) the traffic cones (tag BumperCone, attribute Radius): a car that runs into one knocks
	-- it over (BumperConeService throws it, with a "퉁"); the car only loses a little speed
	for _, c in ipairs(CollectionService:GetTagged("BumperCone")) do
		if c:IsA("Model") and c:IsDescendantOf(workspace) then
			local cp = flat(c:GetPivot().Position)
			if (cp - here).Magnitude < me.half + me.r + 4 then
				local cr = (c:GetAttribute("Radius") :: number?) or 1.5
				local pa = closest(a0, a1, cp, cp)
				if (pa - cp).Magnitude < me.r + cr and os.clock() - (coneHit[c] or 0) > 0.4 and d.vel.Magnitude > 1.5 then
					coneHit[c] = os.clock()
					ConeRemote:FireServer(c, d.vel)
					d.vel *= 0.88
				end
			end
		end
	end
	contacts = touching

	-- integrate (per unit mass)
	d.vel += force * dt
	d.vel = flat(d.vel)
	d.spin += (torque / inertia) * dt
	d.pos += d.vel * dt
	d.yaw += d.spin * dt
	-- never out of the hall even after a lag spike
	d.pos = Vector3.new(math.clamp(d.pos.X, hall.x0 + 0.5, hall.x1 - 0.5), hall.floorY + 0.5, math.clamp(d.pos.Z, hall.z0 + 0.5, hall.z1 - 0.5))
end

local function driveStep(dt: number)
	local d = drive
	if not d then return end
	if not d.root.Parent or d.seat.Occupant == nil or d.root.Anchored then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.SeatPart ~= d.seat then drive = nil return end
		if d.root.Anchored then
			-- (the server has not handed the car over yet: start from where it stands)
			d.pos, d.yaw, d.vel, d.spin = d.root.Position, yawOf(d.root.CFrame), Vector3.zero, 0
			return
		end
	end
	local n = math.max(1, math.ceil(dt / (1 / 240)))
	for _ = 1, n do simulate(d, dt / n) end
	d.root.CFrame = CFrame.new(d.pos) * CFrame.Angles(0, d.yaw, 0)
	d.root.AssemblyLinearVelocity = d.vel
	d.root.AssemblyAngularVelocity = Vector3.new(0, d.spin, 0)
end

---------------------------------------------------------------- hits between other cars (sound + wobble only)
local seen: {[string]: boolean} = {}
local function watchOthers()
	local roots = CollectionService:GetTagged(C.RootTag)
	local now: {[string]: boolean} = {}
	for i = 1, #roots do
		local a = roots[i] :: BasePart
		for j = i + 1, #roots do
			local b = roots[j] :: BasePart
			local mine = drive and (drive.root == a or drive.root == b)
			if not mine and not (a.Anchored and b.Anchored) and a:IsDescendantOf(workspace) and b:IsDescendantOf(workspace) then
				local A, B = carShape(a), carShape(b)
				local pa, pb = flat(a.Position), flat(b.Position)
				if (pa - pb).Magnitude < A.half + B.half + A.r + B.r then
					local x, y = closest(pa + flat(a.CFrame.RightVector) * A.half, pa - flat(a.CFrame.RightVector) * A.half, pb + flat(b.CFrame.RightVector) * B.half, pb - flat(b.CFrame.RightVector) * B.half)
					local dv = x - y
					if dv.Magnitude < A.r + B.r and dv.Magnitude > 1e-4 then
						local key = a:GetFullName() .. "|" .. b:GetFullName()
						now[key] = true
						if not seen[key] then
							local n = dv.Unit
							local closing = -(flat(a.AssemblyLinearVelocity) - flat(b.AssemblyLinearVelocity)):Dot(n)
							if closing > C.BumpSoundMin then
								kick(a, y + n * B.r, n, closing)
								kick(b, y + n * B.r, -n, closing, true) -- (one burst for the pair)
							end
						end
					end
				end
			end
		end
	end
	seen = now
end

---------------------------------------------------------------- the driver's hands and the steering wheel (all cars)
-- (D-1415, user: "운전자는 운전하는 모션 보여 줘") both hands on the rim by IK, the steering wheel
-- turning with the drive wheel: this player's own wheel angle, other drivers' from their car's spin
type Grip = { humanoid: Humanoid, iks: {IKControl} }
local grips: {[BasePart]: Grip} = {}
local wheelBase: {[Weld]: CFrame} = {}

local function dropGrip(root: BasePart)
	local g = grips[root]
	if g then
		for _, ik in ipairs(g.iks) do ik:Destroy() end
		grips[root] = nil
	end
end

local function holdWheel(root: BasePart, humanoid: Humanoid, rim: BasePart)
	local g = grips[root]
	if g and g.humanoid == humanoid then return end
	dropGrip(root)
	local character = humanoid.Parent
	local iks = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local upper = character and character:FindFirstChild(side .. "UpperArm")
		local hand = character and character:FindFirstChild(side .. "Hand")
		local target = rim:FindFirstChild("Grip" .. string.sub(side, 1, 1))
		if upper and hand and target then
			local ik = Instance.new("IKControl")
			ik.Name = "BumperGrip" .. side
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = upper
			ik.EndEffector = hand
			ik.Target = target
			ik.SmoothTime = 0.04
			ik.Parent = humanoid
			table.insert(iks, ik)
		end
	end
	grips[root] = { humanoid = humanoid, iks = iks }
end

local function steerAll()
	for _, root in ipairs(CollectionService:GetTagged(C.RootTag)) do
		local model = root.Parent
		local seat = model and model:FindFirstChild("BumperSeat") :: VehicleSeat?
		local rim = model and model:FindFirstChild("SteeringWheel") :: BasePart?
		local ww = model and model:FindFirstChild("WheelWeld", true) :: Weld?
		if seat and rim and ww and root:IsA("BasePart") then
			local driver = seat.Occupant
			if driver then holdWheel(root, driver, rim) else dropGrip(root) end
			local angle = 0
			if drive and drive.root == root then
				angle = drive.wheel
			elseif driver and not root.Anchored then
				angle = math.clamp(-root.AssemblyAngularVelocity.Y / 2.5, -1, 1) * C.WheelMax -- (turning right = spinning clockwise = negative Y)
			end
			local base = wheelBase[ww] or ww.C0
			wheelBase[ww] = base
			ww.C0 = base * CFrame.Angles(-angle * C.WheelTurn, 0, 0)
		end
	end
	for root in pairs(grips) do
		if not root.Parent then dropGrip(root) end
	end
end

---------------------------------------------------------------- frame
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 1 / 15)
	-- am I in a bumper car seat?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "BumperSeat" then
		if not drive or drive.seat ~= seat then startDrive(seat) end
	elseif drive then
		drive = nil
	end
	-- (D-1826) the pedal: shown to the driver only
	pedalGui.Enabled = drive ~= nil
	if drive then
		local wasDown = pedalDown
		pedalDown = keyPedal()
		if wasDown ~= pedalDown then showPedal() end
		if os.clock() - pedalPlacedAt > 0.3 then
			pedalPlacedAt = os.clock()
			placePedal()
		end
	elseif pedalInput or pedalDown then
		pedalInput, pedalDown = nil, false
		showPedal()
	end
	driveStep(dt)
	watchOthers()
	steerAll()
	-- the bodies' rock / hop
	for root, w in pairs(wobbles) do
		if not root.Parent then
			wobbles[root] = nil
		else
			stepWobble(w, dt)
			local model = root.Parent
			local bw = w.weld or (model and model:FindFirstChild("BodyWeld", true)) :: Weld?
			if bw then
				w.weld = bw
				w.base = w.base or bw.C0
				bw.C0 = (w.base :: CFrame) * CFrame.new(0, w.hop, 0) * CFrame.Angles(w.roll, 0, w.pitch)
			end
			if math.abs(w.pitch) + math.abs(w.roll) + w.hop < 1e-3 and math.abs(w.vp) + math.abs(w.vr) + math.abs(w.vh) < 1e-3 then
				if bw and w.base then bw.C0 = w.base end
				wobbles[root] = nil
			end
		end
	end
end)

-- (D-1545, user 2026-11-16: "범퍼카 탑승 후에는 범퍼카 타기 안 뜨게 해") while this player sits in a bumper
-- car, no car's "범퍼카 타기" shows on their screen (the server keeps a car's prompt on while its other
-- seat is free, for the next person); off the car, they come back.
local RIDE_REACH = 11
task.spawn(function()
	local wasIn = false
	while true do
		task.wait(0.3)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local inCar = false
		if seat then
			local node: Instance? = seat
			while node and node ~= workspace do
				if CollectionService:HasTag(node, C.Tag) or CollectionService:HasTag(node, C.RootTag) then inCar = true break end
				node = node.Parent
			end
		end
		if inCar or wasIn then
			for _, root in ipairs(CollectionService:GetTagged(C.RootTag)) do
				local model = root.Parent
				for _, d in ipairs(if model then model:GetDescendants() else {}) do
					if d:IsA("ProximityPrompt") then -- (the car's one prompt; its text may be translated)
						d.MaxActivationDistance = if inCar then 0 else RIDE_REACH
					end
				end
			end
		end
		wasIn = inCar
	end
end)
