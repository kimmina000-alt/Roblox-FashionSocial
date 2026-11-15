--!nocheck
-- 점핑스타 디자인 (D-1456, user 2026-11-15: "점핑스타 디자인" + a photo of a Jumping Star ride: a yellow
-- tower on a red A-frame foot, red / blue twisted light columns up both sides, a big yellow star
-- on top with "JUMPING STAR" in red bulb letters, small yellow stars on the tower, one blue car
-- across the tower's front with a row of yellow / red / orange seats, a lap bar and yellow stars
-- along its back, a red machine box behind, a grey queue fence round it with Enter / Exit).
-- Workspace["점핑스타"] (outside Hongdae_Layout, so a chain run cannot wipe it; park_layout_1111
-- no longer builds the 24_JumpingStar blockout when it is there). It stands where the blockout
-- stood (its Base's middle, read once and kept in the attribute Site), facing FACE.
-- (D-1457, user: "점핑스타 사람 타서 위아래로 뛰는 것까지 구현") the car and its seats are the Model
-- "Ride.Car"; "Ride" (tag ParkJumpStar, pivot = the tower's foot facing FACE) carries Seat1..6
-- (seat tops from the pivot, car at the bottom), Board, Exit and Reach; ParkConfig.jumpStarState
-- moves the car on every screen (ParkRidesController), riders picked and seated like the vikings.
-- Idempotent: everything is built anew.

local CENTER_DEFAULT = Vector3.new(-255.8, 16, -370.4)
local FACE = Vector3.new(1, 0, 0) -- (the car and the star face +x, the park's middle)

local YELLOW = Color3.fromRGB(250, 206, 30)
local RED = Color3.fromRGB(214, 36, 40)
local BLUE = Color3.fromRGB(38, 92, 196)
local ORANGE = Color3.fromRGB(244, 128, 40)
local GREY = Color3.fromRGB(176, 180, 186)
local DARK = Color3.fromRGB(46, 50, 58)

local owner = workspace:FindFirstChild("점핑스타")
local site = owner and owner:GetAttribute("Site")
local blockout = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ParkBlockout")
	and workspace.Hongdae_Layout.ParkBlockout:FindFirstChild("24_JumpingStar")
if typeof(site) ~= "Vector3" then
	local base = blockout and blockout:FindFirstChild("Base")
	site = if base then Vector3.new(base.Position.X, base.Position.Y - base.Size.X / 2, base.Position.Z) else CENTER_DEFAULT
end
if owner then owner:Destroy() end
if blockout then blockout:Destroy() end
owner = Instance.new("Model")
owner.Name = "점핑스타"
owner:SetAttribute("Site", site)

local O = CFrame.lookAt(site, site + FACE) -- (x right, y up, -z = FACE)
local function L(x: number, y: number, z: number): CFrame return O * CFrame.new(x, y, -z) end -- (z = towards FACE)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = owner
	return p
end
local function beam(name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?)
	return part(name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat or Enum.Material.Metal)
end
local function wedge(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	w.Anchored = true
	w.CanCollide, w.CanTouch, w.CanQuery = false, false, false
	w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	w.Parent = owner
	return w
end
-- a flat triangle a, b, c (thickness th) out of two wedges
local function tri(name: string, a: Vector3, b: Vector3, c: Vector3, th: number, color: Color3, mat: Enum.Material?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	wedge(name, Vector3.new(th, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, mat)
	wedge(name, Vector3.new(th, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, mat)
end
-- a five-point star facing FACE, centred on cf (in the star's plane), outer radius R
local function star(name: string, cf: CFrame, R: number, th: number, color: Color3, mat: Enum.Material?)
	local r = R * 0.45
	local pts = {}
	for k = 0, 9 do
		local a = math.pi / 2 + k * math.pi / 5
		local rad = if k % 2 == 0 then R else r
		pts[k + 1] = (cf * CFrame.new(rad * math.cos(a), rad * math.sin(a), 0)).Position
	end
	local c = cf.Position
	for k = 1, 10 do
		tri(name, c, pts[k], pts[k % 10 + 1], th, color, mat)
	end
end

---------------------------------------------------------------- the base
local GROUND = site.Y
local PLINTH = 1.4
local TOP = GROUND + PLINTH
part("Plinth", Vector3.new(PLINTH, 15, 15), L(0, PLINTH / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), GREY, Enum.Material.Concrete, Enum.PartType.Cylinder, true)
part("PlinthTrim", Vector3.new(0.4, 15.4, 15.4), L(0, PLINTH - 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), RED, Enum.Material.Metal, Enum.PartType.Cylinder)
-- the machine box behind the tower
part("MachineBox", Vector3.new(5, 4.5, 3.4), L(0, PLINTH + 2.25, -4.6), RED, Enum.Material.Metal, nil, true)
part("MachineVent", Vector3.new(3.6, 1.6, 0.1), L(0, PLINTH + 2.6, -6.35), DARK, Enum.Material.DiamondPlate)

---------------------------------------------------------------- the tower
local TW, TD = 4, 3.6 -- (across, deep)
local TH = 40 -- (tower height over the plinth)
part("Tower", Vector3.new(TW, TH, TD), L(0, PLINTH + TH / 2, 0), YELLOW, Enum.Material.Metal, nil, true)
part("TowerCap", Vector3.new(TW + 0.6, 0.6, TD + 0.6), L(0, PLINTH + TH + 0.3, 0), RED, Enum.Material.Metal)
part("TowerSlot", Vector3.new(1.6, 4, 0.1), L(0, PLINTH + TH - 4, TD / 2 + 0.05), DARK, Enum.Material.SmoothPlastic)
part("TowerSlotRim", Vector3.new(2.2, 4.6, 0.08), L(0, PLINTH + TH - 4, TD / 2 + 0.01), RED, Enum.Material.Metal)
-- the red A-frame foot (legs from the plinth up to the tower, both sides and the back)
for _, sx in ipairs({ -1, 1 }) do
	beam("FootLeg", (L(sx * 6, PLINTH, 0)).Position, (L(sx * TW / 2, PLINTH + 9, 0)).Position, 0.8, RED)
	beam("FootLeg", (L(sx * 3.5, PLINTH, -4)).Position, (L(sx * TW / 2, PLINTH + 7, -TD / 2)).Position, 0.6, RED)
end
beam("FootBar", (L(-6, PLINTH + 0.4, 0)).Position, (L(6, PLINTH + 0.4, 0)).Position, 0.6, RED)
-- the twisted red / blue light columns up both sides (two strands of bulbs round a pole)
local COL_X = TW / 2 + 1.1
local COL_H = TH - 6
for _, sx in ipairs({ -1, 1 }) do
	local cx = sx * COL_X
	part("LightPole", Vector3.new(COL_H, 0.5, 0.5), L(cx, PLINTH + 2 + COL_H / 2, -0.4) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	local n = math.floor(COL_H / 0.75)
	for k = 0, n do
		local y = PLINTH + 2 + k * 0.75
		for strand = 0, 1 do
			local a = k * 0.55 + strand * math.pi
			local col = if strand == 0 then RED else BLUE
			part("TwistBulb", Vector3.one * 0.62, L(cx + 0.55 * math.cos(a), y, -0.4 + 0.55 * math.sin(a)), col, Enum.Material.Neon, Enum.PartType.Ball)
		end
	end
	-- a bracket from the tower to the column, top and bottom
	for _, y in ipairs({ PLINTH + 3, PLINTH + 2 + COL_H - 1 }) do
		beam("LightBracket", (L(sx * TW / 2, y, -0.4)).Position, (L(cx, y, -0.4)).Position, 0.3, DARK)
	end
end
-- small stars on the tower's upper sides
for _, s in ipairs({ { -1, PLINTH + TH - 9 }, { 1, PLINTH + TH - 7 }, { -1, PLINTH + 16 }, { 1, PLINTH + 15 } }) do
	star("TowerStar", L(s[1] * (COL_X + 0.4), s[2], 0.6), 1.5, 0.35, YELLOW)
end

---------------------------------------------------------------- the big star and the sign
local SY = PLINTH + TH + 5.6
local starCF = L(0, SY, 0.4)
star("BigStarRim", starCF * CFrame.new(0, 0, 0.25), 8.6, 0.5, RED, Enum.Material.Neon)
star("BigStar", starCF, 8, 0.7, YELLOW, Enum.Material.SmoothPlastic)
for k = 0, 4 do -- bulbs on the tips
	local a = math.pi / 2 + k * 2 * math.pi / 5
	part("StarTipBulb", Vector3.one * 0.7, starCF * CFrame.new(7.4 * math.cos(a), 7.4 * math.sin(a), -0.45), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, Enum.PartType.Ball)
end
local sign = part("StarSign", Vector3.new(13, 6.6, 0.1), starCF * CFrame.new(0, 0.6, -0.42), YELLOW)
sign.Transparency = 1
do
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.CanvasSize = Vector2.new(660, 312)
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.Parent = sign
	for i, line in ipairs({ "JUMPING", "STAR" }) do
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 0.5)
		t.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = line
		t.TextColor3 = Color3.fromRGB(230, 24, 36)
		t.TextStrokeColor3 = Color3.fromRGB(255, 244, 210)
		t.TextStrokeTransparency = 0
		t.Parent = g
	end
end
-- the star's mast on the tower top
part("StarMast", Vector3.new(1.2, 3.2, 1.2), L(0, PLINTH + TH + 1.6, 0), RED, Enum.Material.Metal)

---------------------------------------------------------------- the car (across the tower's front)
local CY = PLINTH + 9 -- (seat top)
local CW = 15 -- (across)
local SEATS = 6
local front = TD / 2 -- (the tower's front face)
-- the car's body: a blue tub under the seats, a back panel against the tower, rounded ends
part("CarFloor", Vector3.new(CW, 1.2, 3.4), L(0, CY - 1.2, front + 1.9), BLUE, Enum.Material.Metal)
part("CarBack", Vector3.new(CW, 5.2, 0.8), L(0, CY + 1.6, front + 0.4), BLUE, Enum.Material.Metal)
part("CarBackTrim", Vector3.new(CW + 0.2, 0.4, 1.0), L(0, CY + 4.3, front + 0.4), YELLOW, Enum.Material.Metal)
part("CarSkirt", Vector3.new(CW, 1.6, 0.6), L(0, CY - 2.4, front + 3.3), BLUE, Enum.Material.Metal)
for _, sx in ipairs({ -1, 1 }) do
	-- (a cylinder's axis is its X: here the car's across)
	part("CarEnd", Vector3.new(1.0, 4.4, 4.4), L(sx * (CW / 2 + 0.3), CY - 0.3, front + 1.7), BLUE, Enum.Material.Metal, Enum.PartType.Cylinder)
	part("CarEndCap", Vector3.new(0.3, 3.6, 3.6), L(sx * (CW / 2 + 0.85), CY - 0.3, front + 1.7), YELLOW, Enum.Material.Metal, Enum.PartType.Cylinder)
end
-- the carriage behind the back panel, riding on the tower (sleeves round its sides)
for _, sx in ipairs({ -1, 1 }) do
	part("CarSleeve", Vector3.new(0.6, 4, TD + 1.2), L(sx * (TW / 2 + 0.3), CY + 0.8, 0), RED, Enum.Material.Metal)
end
-- the seats: cushion + backrest, colours round yellow / red / orange
local SEAT_COLORS = { YELLOW, RED, ORANGE }
local sw = (CW - 1.6) / SEATS
for k = 1, SEATS do
	local x = -CW / 2 + 0.8 + (k - 0.5) * sw
	local col = SEAT_COLORS[(k - 1) % 3 + 1]
	part("Seat", Vector3.new(sw - 0.3, 0.5, 2.2), L(x, CY - 0.35, front + 2.0), col, Enum.Material.Fabric)
	part("SeatBack", Vector3.new(sw - 0.3, 3.4, 0.45), L(x, CY + 1.5, front + 0.95), col, Enum.Material.Fabric)
	part("SeatDivider", Vector3.new(0.18, 1.6, 2.0), L(x + sw / 2, CY + 0.4, front + 2.0), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
end
-- the lap bar across the front, on two arms
beam("LapBar", (L(-CW / 2 + 0.6, CY + 1.4, front + 3.3)).Position, (L(CW / 2 - 0.6, CY + 1.4, front + 3.3)).Position, 0.35, Color3.fromRGB(210, 214, 220))
for _, sx in ipairs({ -1, 1 }) do
	beam("LapArm", (L(sx * (CW / 2 - 0.6), CY - 0.4, front + 3.3)).Position, (L(sx * (CW / 2 - 0.6), CY + 1.4, front + 3.3)).Position, 0.3, Color3.fromRGB(210, 214, 220))
end
-- a footrest under the seats' front
beam("FootRest", (L(-CW / 2 + 0.8, CY - 3.3, front + 3.5)).Position, (L(CW / 2 - 0.8, CY - 3.3, front + 3.5)).Position, 0.3, DARK)
-- yellow stars along the car's back
for k = 0, 5 do
	local x = -CW / 2 + 1.4 + k * (CW - 2.8) / 5
	star("CarStar", L(x, CY + 5.4, front + 0.4), 0.95, 0.3, YELLOW)
end

-- (D-1457) the car's parts into Ride.Car, the seats' places on Ride
do
	local CAR = { CarFloor = true, CarBack = true, CarBackTrim = true, CarSkirt = true, CarEnd = true, CarEndCap = true,
		CarSleeve = true, Seat = true, SeatBack = true, SeatDivider = true, LapBar = true, LapArm = true, FootRest = true, CarStar = true }
	local ride = Instance.new("Model")
	ride.Name = "Ride"
	local car = Instance.new("Model")
	car.Name = "Car"
	car.Parent = ride
	for _, c in ipairs(owner:GetChildren()) do
		if c:IsA("BasePart") and CAR[c.Name] then c.Parent = car end
	end
	for k = 1, SEATS do
		local x = -CW / 2 + 0.8 + (k - 0.5) * sw
		ride:SetAttribute("Seat" .. k, O:ToObjectSpace(L(x, CY - 0.1, front + 2.0)))
	end
	ride:SetAttribute("Board", 15)
	ride:SetAttribute("Reach", 14)
	ride:SetAttribute("Exit", (L(0, 3, 13.5)).Position)
	car.WorldPivot = O
	ride.WorldPivot = O
	game:GetService("CollectionService"):AddTag(ride, "ParkJumpStar")
	ride.Parent = owner
end

---------------------------------------------------------------- the queue fence (grey, open in front)
do
	local R = 11
	local N = 20
	for k = 0, N - 1 do
		local a0, a1 = k / N * 2 * math.pi, (k + 1) / N * 2 * math.pi
		local mid = (a0 + a1) / 2
		local open = math.abs(math.atan2(math.sin(mid), math.cos(mid))) < 0.45 -- (two bays face FACE)
		local p0 = (L(R * math.sin(a0), 0, R * math.cos(a0))).Position
		local p1 = (L(R * math.sin(a1), 0, R * math.cos(a1))).Position
		part("FencePost", Vector3.new(0.3, 3.4, 0.3), CFrame.new(p0 + Vector3.new(0, 1.7, 0)), GREY, Enum.Material.Metal, nil, true)
		if not open then
			for _, h in ipairs({ 1.0, 3.0 }) do
				beam("FenceRail", p0 + Vector3.new(0, h, 0), p1 + Vector3.new(0, h, 0), 0.18, GREY)
			end
			for f = 1, 5 do -- vertical bars between the rails
				local q = p0:Lerp(p1, f / 6)
				part("FenceBar", Vector3.new(0.1, 2.0, 0.1), CFrame.new(q + Vector3.new(0, 2.0, 0)), GREY, Enum.Material.Metal)
			end
		end
	end
	-- the Enter / Exit signs at the opening
	for _, s in ipairs({ { -1, "ENTER", Color3.fromRGB(230, 40, 40) }, { 1, "EXIT", Color3.fromRGB(40, 140, 80) } }) do
		local a = s[1] * 0.5
		local at = L(R * math.sin(a), 0, R * math.cos(a))
		part("SignPost", Vector3.new(0.2, 4.2, 0.2), at * CFrame.new(0, 2.1, 0), DARK, Enum.Material.Metal)
		local board = part("SignBoard", Vector3.new(2.6, 0.9, 0.12), at * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(250, 250, 250))
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.CanvasSize = Vector2.new(260, 90)
		g.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = s[2]
		t.TextColor3 = s[3]
		t.Parent = g
	end
end

owner.WorldPivot = O
owner.Parent = workspace
local n = 0
for _, d in ipairs(owner:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
print(("[park_jumpingstar_1115] parts %d at %s"):format(n, tostring(site)))
return n
