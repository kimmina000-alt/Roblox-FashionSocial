--!strict
-- (D-1413) Bumper cars on the client (BumperCarConfig; the server side: BumperCarService).
--   * Driving: while this player sits in a bumper car's seat, the car is simulated here and
--     moved every frame (this client owns it): pedal = seat.ThrottleFloat (W / S, the stick),
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

-- a hit at world point `at` with the push direction `n` (into this car) and closing speed
local function kick(root: BasePart, at: Vector3, n: Vector3, speed: number)
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
type Drive = { root: BasePart, seat: VehicleSeat, pos: Vector3, vel: Vector3, yaw: number, spin: number, wheel: number }
local drive: Drive? = nil
local contacts: {[BasePart]: boolean} = {} -- (rings touching last frame: sound once per hit)

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

local function forwardOf(yaw: number): Vector3
	return Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) -- the car's +X at this yaw
end

local function simulate(d: Drive, dt: number)
	local me = carShape(d.root)
	local L = (d.root:GetAttribute("Length") :: number?) or d.root.Size.X
	local W = me.r * 2
	local inertia = (L * L + W * W) / 12 -- per unit mass
	local hall = C.Hall

	-- the wheel follows A / D, and comes back by itself
	local target = math.clamp(d.seat.SteerFloat, -1, 1) * C.WheelMax
	local step = C.WheelRate * dt
	d.wheel += math.clamp(target - d.wheel, -step, step)
	local pedal = math.clamp(d.seat.ThrottleFloat, -1, 1)
	if pedal < 0 then pedal *= C.ReverseFactor end

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
								kick(b, y + n * B.r, -n, closing)
							end
						end
					end
				end
			end
		end
	end
	seen = now
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
	driveStep(dt)
	watchOthers()
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
