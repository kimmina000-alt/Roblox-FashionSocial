--!nocheck
-- 관람차 바로 세우기 + 틀·탑승장 (D-1460, user 2026-11-15: "관람차 지금 회전값이랑 위치값이 애매해서 땅에
-- 이상하게 서 있는 것처럼 보임 정방향으로 고치고 … 전체적인 틀과 밑에 보이는 주변 대기하는 공간이나 단상
-- 디자인 보고 구현" + a photo of a classic Ferris wheel: a white rim and lattice, a blue hub, blue
-- A-frame legs with a pink star band, a raised boarding deck with stairs, white railings, a blue
-- canopy over a booth and an arched sign at the entrance; the cabins come from the user later).
--   1. Upright: the wheel (tag ParkWheel) had been turned by hand (about 12° rolled, 6° pitched,
--      yawed 133°), so the cabins hung crooked and the legs stood in the ground at odd angles. It is
--      turned about its hub so the axle runs along Z (the wheel faces the park's gate, +z), the hub
--      standing HUB_UP over the ground under it; where it stands (x, z) is kept.
--   2. The look: spokes, chords and rim white, the hub blue with a window (park_wheel_dress_1115
--      builds the lattice; this sets the colours).
--   3. The legs: the four old Support beams go; two blue A-frames (one each side of the wheel,
--      outside its rings) from the axle ends down to the ground, a pink band with stars on each
--      leg's front, a cross bar near the ground, bearing blocks at the top.
--   4. The boarding deck (WheelStation, in the wheel's group): a raised deck under the bottom
--      cabin, its top just under the cabins' floor, a pink skirt with stars, white railings, stairs
--      down to the front with an invisible ramp, a blue canopy with a white scalloped edge over the
--      front half, a small ticket booth, and an arched sign "FERRIS WHEEL" over the stairs' foot.
--      The old WheelPlatform / WheelPlatformEdge / WheelRamp blocks go; BoardPoint moves onto the deck.
-- Run in Edit mode after the graybox zones and park_wheel_dress_1115 (chain step). Idempotent.

local CollectionService = game:GetService("CollectionService")

local WHITE = Color3.fromRGB(244, 244, 246)
local BLUE = Color3.fromRGB(46, 72, 168)
local PINK = Color3.fromRGB(236, 176, 206)
local LAVENDER = Color3.fromRGB(196, 186, 232)
local YELLOW = Color3.fromRGB(250, 206, 40)
local RED = Color3.fromRGB(206, 40, 48)
local GOLD = Color3.fromRGB(226, 182, 72)
local GREY = Color3.fromRGB(200, 204, 210)

local wheel
for _, m in ipairs(CollectionService:GetTagged("ParkWheel")) do
	if m:IsDescendantOf(workspace) then wheel = m end
end
assert(wheel, "no ParkWheel in Workspace")
local hub = wheel:FindFirstChild("Hub") :: BasePart
local R = wheel:GetAttribute("Radius") or 52
local TWIN_X = wheel:GetAttribute("TwinX") or 3.9
local group = wheel.Parent

-- the ground under the hub (the wheel, its group and riders left out)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { group }
local hit = workspace:Raycast(Vector3.new(hub.Position.X, hub.Position.Y + 50, hub.Position.Z), Vector3.new(0, -400, 0), params)
local GROUND = if hit then hit.Position.Y else 16.25
local DECK_H = 3.4 -- (the deck over the ground; the bottom cabin's floor just over it)
local CABIN_BELOW = 9.6 -- (the cabin's bottom under the rim's hang point: park_wheel_dress TOP 1.6 + 8)
local HUB_UP = R + CABIN_BELOW + DECK_H + 0.25

---------------------------------------------------------------- 1. upright
local target = CFrame.fromMatrix(Vector3.new(hub.Position.X, GROUND + HUB_UP, hub.Position.Z), Vector3.zAxis, Vector3.yAxis)
local delta = target * hub.CFrame:Inverse()
wheel:PivotTo(delta * wheel:GetPivot())
local H = hub.CFrame -- (X = the axle = world Z, Y = up)
local AX = H.RightVector
local IN = H.LookVector -- (in the wheel's plane, horizontal)

local function quiet(p: BasePart, collide: boolean?)
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
end
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	quiet(p, collide)
	p.Parent = parent
	return p
end
local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?, up: Vector3?): Part
	return part(parent, name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, up or Vector3.yAxis), color, mat or Enum.Material.Metal)
end
local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3)
	local w = Instance.new("WedgePart")
	w.Name = "StarPiece"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	quiet(w)
	w.Parent = parent
end
local function tri(parent: Instance, a: Vector3, b: Vector3, c: Vector3, th: number, color: Color3)
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
	wedge(parent, Vector3.new(th, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color)
	wedge(parent, Vector3.new(th, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color)
end
-- a small star: five points round a disc, in the plane of cf (facing its -Z)
local function star(parent: Instance, cf: CFrame, R0: number, color: Color3)
	local r = R0 * 0.42
	for k = 0, 4 do
		local a = math.pi / 2 + k * 2 * math.pi / 5
		local tip = (cf * CFrame.new(R0 * math.cos(a), R0 * math.sin(a), 0)).Position
		local l = (cf * CFrame.new(r * math.cos(a - math.pi / 5), r * math.sin(a - math.pi / 5), 0)).Position
		local rr = (cf * CFrame.new(r * math.cos(a + math.pi / 5), r * math.sin(a + math.pi / 5), 0)).Position
		tri(parent, tip, l, rr, 0.12, color)
	end
	part(parent, "StarMiddle", Vector3.new(0.12, r * 2.1, r * 2.1), cf * CFrame.Angles(0, math.pi / 2, 0), color, nil, Enum.PartType.Cylinder)
end

---------------------------------------------------------------- 2. the look
local rotor = wheel:FindFirstChild("Rotor")
if rotor then
	for _, p in ipairs(rotor:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name == "Spoke" or p.Name == "Chord" or p.Name == "Diagonal" or p.Name == "Rim" then
				p.Color = WHITE
			elseif p.Name == "HubPlate" then
				p.Color = BLUE
			end
		end
	end
end
hub.Color = BLUE
hub.Material = Enum.Material.Metal

---------------------------------------------------------------- 3. the legs
for _, c in ipairs(wheel:GetChildren()) do
	if (c:IsA("BasePart") and c.Name == "Support") or c.Name == "Legs" then c:Destroy() end
end
local legs = Instance.new("Model")
legs.Name = "Legs"
legs.Parent = wheel
local SPREAD = R * 0.62 -- (the feet's half spread in the wheel's plane)
local function W(ax: number, inPlane: number, y: number): Vector3
	return Vector3.new(H.Position.X, 0, H.Position.Z) + AX * ax + IN * inPlane + Vector3.new(0, y, 0)
end
for _, s in ipairs({ -1, 1 }) do
	local topAx = s * (TWIN_X + 2.6)
	local footAx = s * (TWIN_X + 9)
	local top = W(topAx, 0, H.Position.Y)
	for _, side in ipairs({ -1, 1 }) do
		local foot = W(footAx, side * SPREAD, GROUND)
		local leg = beam(legs, "Support", top, foot, 2.6, BLUE)
		leg.CanCollide, leg.CanQuery = true, true
		-- the pink band on the leg's outer face (the side away from the wheel), stars on it
		local along = (foot - top).Unit
		local out = AX * s
		local face = CFrame.lookAt((top + foot) / 2 + out * 1.36, (top + foot) / 2 + out * 2, along)
		part(legs, "LegBand", Vector3.new(1.8, (foot - top).Magnitude - 2, 0.12), face, PINK, Enum.Material.SmoothPlastic)
		local n = 6
		for k = 1, n do
			local p = top:Lerp(foot, (k - 0.3) / (n + 0.4)) + out * 1.45
			star(legs, CFrame.lookAt(p, p + out, along), 0.7, if k % 2 == 0 then YELLOW else BLUE)
		end
		part(legs, "LegFoot", Vector3.new(4.4, 0.8, 4.4), CFrame.new(foot + Vector3.new(0, 0.4, 0)), GREY, Enum.Material.Concrete, nil, true)
	end
	-- a cross bar between the two legs, high over the boarding deck's canopy, and a bearing block
	local f = 0.55
	beam(legs, "LegBar", top:Lerp(W(footAx, -SPREAD, GROUND), f), top:Lerp(W(footAx, SPREAD, GROUND), f), 1.2, BLUE)
	part(legs, "Bearing", Vector3.new(2.4, 4.2, 4.2), CFrame.fromMatrix(top, AX, Vector3.yAxis), BLUE, Enum.Material.Metal)
end
-- the axle between the bearings
part(legs, "Axle", Vector3.new(2 * (TWIN_X + 2.6), 1.6, 1.6), CFrame.fromMatrix(H.Position, AX, Vector3.yAxis), GREY, Enum.Material.Metal, Enum.PartType.Cylinder)
-- windows on the blue hub's two faces (the hub with a window in the photo)
for _, s in ipairs({ -1, 1 }) do
	part(legs, "HubWindow", Vector3.new(0.1, 3, 4.6), CFrame.fromMatrix(H.Position + AX * s * (hub.Size.X / 2 + 0.06), AX, Vector3.yAxis), Color3.fromRGB(150, 200, 240), Enum.Material.Glass).Transparency = 0.3
end

---------------------------------------------------------------- 4. the boarding deck
for _, n in ipairs({ "WheelPlatform", "WheelPlatformEdge", "WheelRamp", "WheelStation" }) do
	for _, c in ipairs(group:GetChildren()) do
		if c.Name == n then c:Destroy() end
	end
end
local st = Instance.new("Model")
st.Name = "WheelStation"
local TOP = GROUND + DECK_H
-- (D-1476, user 2026-11-16: "관람차 아래 대기하는 단상 크기 키우고": was 15 / 13 / -6, stairs 7 wide)
local HX, FRONT, BACK = 24, 22, -8 -- (deck: x ±HX in the wheel's plane, axle from BACK to FRONT; +axle = the front)
-- the frame for the deck: X across (in the wheel's plane), Z = -axle (so -Z faces the front)
local O = CFrame.fromMatrix(W(0, 0, GROUND), -IN, Vector3.yAxis) -- (its Z = -axle)
local function L(x: number, y: number, z: number): CFrame return O * CFrame.new(x, y, -z) end -- (z = towards the front)
part(st, "Deck", Vector3.new(HX * 2, DECK_H, FRONT - BACK), L(0, DECK_H / 2, (FRONT + BACK) / 2), LAVENDER, Enum.Material.SmoothPlastic, nil, true)
part(st, "DeckFloor", Vector3.new(HX * 2 - 0.4, 0.12, FRONT - BACK - 0.4), L(0, DECK_H + 0.06, (FRONT + BACK) / 2), Color3.fromRGB(176, 182, 196), Enum.Material.DiamondPlate)
part(st, "DeckTrim", Vector3.new(HX * 2 + 0.3, 0.35, FRONT - BACK + 0.3), L(0, DECK_H - 0.1, (FRONT + BACK) / 2), GOLD, Enum.Material.Metal)
-- stars on the skirt's front
for k = -3, 3 do
	local x = k * 4
	if math.abs(x) > 4.5 then
		star(st, L(x, DECK_H / 2, FRONT + 0.08) * CFrame.Angles(0, math.pi, 0), 0.9, if k % 2 == 0 then BLUE else YELLOW)
	end
end
-- stairs down the front middle, an invisible ramp to walk on
local SW, STEPS = 10, 7
local rise, run = DECK_H / STEPS, 1.1
for k = 1, STEPS do
	local top = DECK_H - (k - 1) * rise
	part(st, "Step", Vector3.new(SW, top, run), L(0, top / 2, FRONT + (k - 0.5) * run), Color3.fromRGB(176, 182, 196), Enum.Material.DiamondPlate, nil, false)
end
local ramp = Instance.new("WedgePart")
ramp.Name = "StairRamp"
ramp.Size = Vector3.new(SW, DECK_H, STEPS * run)
ramp.CFrame = L(0, DECK_H / 2, FRONT + STEPS * run / 2) * CFrame.Angles(0, math.pi, 0)
ramp.Transparency = 1
ramp.Anchored = true
ramp.CanTouch = false
ramp.Parent = st
-- white railings round the deck (open at the stairs and over the cabin's door side: the wheel side
-- is closed except where the cabin docks, x ±5)
local function rail(a: Vector3, b: Vector3)
	local d = (b - a)
	local n = math.max(1, math.floor(d.Magnitude / 2.4 + 0.5))
	for k = 0, n do
		local p = a:Lerp(b, k / n)
		part(st, "RailPost", Vector3.new(0.25, 3.2, 0.25), CFrame.new(p + Vector3.new(0, 1.6, 0)), WHITE, Enum.Material.Metal, nil, true)
	end
	for _, h in ipairs({ 1.4, 3.1 }) do
		beam(st, "Rail", a + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0), 0.22, WHITE).CanCollide = true
	end
	-- the diamond lattice between the rails
	for k = 0, n - 1 do
		local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
		beam(st, "RailX", p0 + Vector3.new(0, 1.5, 0), p1 + Vector3.new(0, 3.0, 0), 0.1, WHITE)
		beam(st, "RailX", p0 + Vector3.new(0, 3.0, 0), p1 + Vector3.new(0, 1.5, 0), 0.1, WHITE)
	end
end
local function P(x: number, z: number): Vector3 return L(x, DECK_H, z).Position end
rail(P(-HX, FRONT), P(-HX, BACK))
rail(P(HX, FRONT), P(HX, BACK))
rail(P(-HX, BACK), P(-5, BACK))
rail(P(5, BACK), P(HX, BACK))
rail(P(-HX, FRONT), P(-SW / 2, FRONT))
rail(P(SW / 2, FRONT), P(HX, FRONT))
-- the canopy over the front half (clear of the cabins: they pass at axle ±3)
local CZ0, CZ1 = 5, FRONT - 0.5
local CH = 7.6
for _, x in ipairs({ -HX + 0.6, HX - 0.6 }) do
	for _, z in ipairs({ CZ0 + 0.4, CZ1 - 0.4 }) do
		part(st, "CanopyPost", Vector3.new(0.45, CH, 0.45), L(x, DECK_H + CH / 2, z), WHITE, Enum.Material.Metal, nil, true)
	end
end
part(st, "CanopyRoof", Vector3.new(HX * 2 + 1.6, 0.5, CZ1 - CZ0 + 1.6), L(0, DECK_H + CH + 0.25, (CZ0 + CZ1) / 2), BLUE, Enum.Material.SmoothPlastic)
part(st, "CanopyRidge", Vector3.new(HX * 2 + 1.6, 1.0, 1.2), L(0, DECK_H + CH + 0.9, (CZ0 + CZ1) / 2), BLUE, Enum.Material.SmoothPlastic)
-- the white scalloped valance along its front and sides
local VAL = Vector3.new(0, DECK_H + CH - 0.35, 0)
for i = 0, math.floor((HX * 2 + 1.6) / 1.6) do
	local x = -HX - 0.8 + i * 1.6
	part(st, "Valance", Vector3.new(0.1, 1.5, 1.5), L(x, VAL.Y - 0.2, CZ1 + 0.8) * CFrame.Angles(0, math.pi / 2, 0), WHITE, nil, Enum.PartType.Cylinder)
end
part(st, "ValanceBand", Vector3.new(HX * 2 + 1.6, 0.5, 0.12), L(0, VAL.Y + 0.35, CZ1 + 0.82), WHITE)
-- a small ticket booth under the canopy
part(st, "Booth", Vector3.new(4, 4.4, 3.2), L(-HX + 3, DECK_H + 2.2, CZ1 - 2.2), Color3.fromRGB(246, 220, 232), Enum.Material.SmoothPlastic, nil, true)
part(st, "BoothWindow", Vector3.new(2.6, 1.6, 0.1), L(-HX + 3, DECK_H + 2.8, CZ1 - 0.55), Color3.fromRGB(150, 200, 240), Enum.Material.Glass)
part(st, "BoothRoof", Vector3.new(4.6, 0.4, 3.8), L(-HX + 3, DECK_H + 4.6, CZ1 - 2.2), RED, Enum.Material.SmoothPlastic)
-- the arched sign over the stairs' foot
local AZ = FRONT + STEPS * run + 1.2
for _, s in ipairs({ -1, 1 }) do
	part(st, "ArchPost", Vector3.new(0.9, 9, 0.9), L(s * (SW / 2 + 0.8), 4.5, AZ), BLUE, Enum.Material.Metal, nil, true)
	part(st, "ArchPostCap", Vector3.new(1.3, 0.5, 1.3), L(s * (SW / 2 + 0.8), 9.2, AZ), GOLD, Enum.Material.Metal)
end
local board = part(st, "ArchSign", Vector3.new(SW + 3.2, 2.4, 0.4), L(0, 9.9, AZ + 0.6), RED, Enum.Material.SmoothPlastic) -- (in front of the arch band)
-- the arch: a red band in a half circle from post to post, bulbs on it
do
	local ar = SW / 2 + 0.8
	local n = 10
	for k = 0, n - 1 do
		local a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
		local p0 = L(ar * math.cos(a0), 9.4 + ar * 0.55 * math.sin(a0), AZ).Position
		local p1 = L(ar * math.cos(a1), 9.4 + ar * 0.55 * math.sin(a1), AZ).Position
		beam(st, "ArchBand", p0, p1, 0.7, RED, Enum.Material.SmoothPlastic)
		part(st, "ArchBulb", Vector3.one * 0.35, CFrame.new(p0 + (L(0, 0, 0.4).Position - L(0, 0, 0).Position)), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, Enum.PartType.Ball)
	end
end
part(st, "ArchTrim", Vector3.new(SW + 3.6, 0.3, 0.5), L(0, 8.7, AZ + 0.6), GOLD, Enum.Material.Metal)
do
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.CanvasSize = Vector2.new(512, 120)
	g.LightInfluence = 0.2
	g.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "FERRIS WHEEL"
	t.TextColor3 = Color3.fromRGB(255, 236, 160)
	t.TextStrokeTransparency = 0.3
	t.Parent = g
end
st.WorldPivot = O
st.Parent = group

-- where boarding is checked: on the deck by the bottom cabin, in front of it
local bp = wheel:FindFirstChild("BoardPoint") :: BasePart?
if bp then
	bp.CFrame = L(0, DECK_H + 0.2, 4.5)
	bp.Transparency = 1
	bp.CanCollide = false
end
local n = 0
for _, d in ipairs(st:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
local m = 0
for _, d in ipairs(legs:GetDescendants()) do
	if d:IsA("BasePart") then m += 1 end
end
print(("[park_wheel_frame_1115] hub at %s, ground %.2f; legs %d parts, station %d parts"):format(tostring(H.Position), GROUND, m, n))
return n
