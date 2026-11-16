--!nocheck
-- 범퍼카장 디자인 (D-1462, user 2026-11-15: "범퍼카 장소 디자인 구현" + four photos: a red / yellow
-- striped tent roof on a grey steel truss, warm bulb rows along the edges and coloured string
-- lights across, a glossy dark floor, a blue padded curb with a black rubber band, LED poles, a
-- purple marquee "BUMPER" sign with bulb letters and stars, colourful wall panels behind).
-- The arena itself (Workspace["범퍼"]["04_BumperCars"]: Floor, Rail walls, Posts, Roof; the cars,
-- tag BumperCar, and their scripts) is the bumper-car session's work (feat/bumper-park-1114) and
-- keeps its shape: this step only recolours it, hides the old flat roof and its four thin posts,
-- and builds the dress around it in Workspace["범퍼"].ArenaDress (rebuilt each run):
--   * a gabled tent roof, eaves EAVE over the floor, ridge RIDGE (along z), red / yellow stripes;
--     a grey truss under it (purlins along z, rafters across every second stripe); posts with a
--     blue LED strip round the edge
--   * warm bulbs along all four eaves, five coloured string lights draped across the ceiling, a few
--     soft lights under the roof
--   * the floor dark and a little glossy; the rail walls blue with a yellow cap and a black rubber
--     band on their inner face at car height
--   * the marquee sign over the front (+z, the queue side): purple board, a bulb border, "BUMPER
--     CARS" in big bulb-yellow letters, a big yellow star and a small blue one
--   * the back wall (-z) above the rail: purple / blue / pink panels with neon bands and stars
-- Run in Edit mode after the bumper-car chain steps. Idempotent.

local area = workspace:WaitForChild("범퍼"):WaitForChild("04_BumperCars")
local floor = area:WaitForChild("Floor") :: BasePart

local RED = Color3.fromRGB(214, 36, 44)
local YELLOW = Color3.fromRGB(250, 190, 40)
local STEEL = Color3.fromRGB(150, 156, 166)
local BLUE = Color3.fromRGB(40, 78, 186)
local PURPLE = Color3.fromRGB(86, 40, 150)
local WARM = Color3.fromRGB(255, 214, 140)
local BULBS = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 200, 60), Color3.fromRGB(80, 220, 120), Color3.fromRGB(70, 150, 255), Color3.fromRGB(230, 90, 230) }

local function bb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local flo, fhi = bb(floor)
local X0, X1, Z0, Z1 = flo.X, fhi.X, flo.Z, fhi.Z
local FY = fhi.Y -- (the floor's top)
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2
-- (D-1465, user 2026-11-16: "아래 벽도 삭제하고 이미지로 채워. 이미지 높이에 맞춰서 천장도 높여.") the back
-- wall is the whole picture from the floor up, as wide as the floor; the eaves stand just over it
local IMG, IW, IH = "rbxassetid://74788882274531", 1584, 672
-- (D-1512, the hall as wide as the park: 188) the picture twice side by side, each half the floor's width
local IMG_N = if X1 - X0 > 150 then 2 else 1
local IMG_H = (X1 - X0) / IMG_N * IH / IW -- (the picture's height: about 45 for one, 40 for two)
local EAVE = FY + IMG_H + 1.8
local RIDGE = EAVE + 11
local OVER = 3 -- (the roof past the rail walls)

local old = workspace["범퍼"]:FindFirstChild("ArenaDress")
if old then old:Destroy() end
local dress = Instance.new("Model")
dress.Name = "ArenaDress"

local function quiet(p: BasePart, collide: boolean?)
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
end
local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	quiet(p, collide)
	p.Parent = dress
	return p
end
local function beam(name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?): Part
	return part(name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat or Enum.Material.Metal)
end
local function bulb(at: Vector3, color: Color3, d: number?)
	local b = part("Bulb", Vector3.one * (d or 0.45), CFrame.new(at), color, Enum.Material.Neon, Enum.PartType.Ball)
	b.CastShadow = false
end
local function wedge(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
	local w = Instance.new("WedgePart")
	w.Name = "StarPiece"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	quiet(w)
	w.Parent = dress
end
local function tri(a: Vector3, b: Vector3, c: Vector3, th: number, color: Color3, mat: Enum.Material?)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Cross(ac).Magnitude < 1e-3 then return end -- (D-1481: the gable's top triangle has two corners on one point: no NaN wedges at y -1e6)
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
	wedge(Vector3.new(th, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, mat)
	wedge(Vector3.new(th, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, mat)
end
local function star(cf: CFrame, R0: number, th: number, color: Color3, mat: Enum.Material?)
	local r = R0 * 0.45
	local c = cf.Position
	local pts = {}
	for k = 0, 9 do
		local a = math.pi / 2 + k * math.pi / 5
		local rad = if k % 2 == 0 then R0 else r
		pts[k + 1] = (cf * CFrame.new(rad * math.cos(a), rad * math.sin(a), 0)).Position
	end
	for k = 1, 10 do tri(c, pts[k], pts[k % 10 + 1], th, color, mat) end
end

---------------------------------------------------------------- the arena recoloured
floor.Color = Color3.fromRGB(30, 32, 40)
floor.Material = Enum.Material.SmoothPlastic
floor.Reflectance = 0.12
for _, p in ipairs(area:GetChildren()) do
	if p:IsA("BasePart") then
		if p.Name == "Rail" then
			p.Color = BLUE
			p.Material = Enum.Material.SmoothPlastic
		elseif p.Name == "Roof" or p.Name == "Post" then -- (the old flat roof 40 up and its thin posts)
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
		end
	end
end
-- a yellow cap on each rail wall, a black rubber band on its inner face at car height
local function isBackRail(p: BasePart): boolean
	local lo, hi = bb(p)
	return hi.X - lo.X > 50 and lo.Z < Z0
end
for _, p in ipairs(area:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "Rail" and isBackRail(p) then
		-- (D-1465) the back rail is hidden behind the picture: it still stops the cars
		p.Transparency = 1
		p.CastShadow = false
	end
end
-- (D-1481, user 2026-11-16: "범퍼카 파란벽 펜스로 바꿔서 밖에서도 보이게 해") the rails stay as invisible walls
-- (they stop the cars and people); on the floor along them stand the park's yellow panels
-- (ServerStorage.ArtAssets.YellowFencePanel, at their own size), so the hall can be seen into from
-- outside. The black rubber band at the floor stays.
local PANEL = game:GetService("ServerStorage"):WaitForChild("ArtAssets"):FindFirstChild("YellowFencePanel") :: BasePart?
local nPanel = 0
for _, p in ipairs(area:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "Rail" and not isBackRail(p) then
		local lo, hi = bb(p)
		local c = (lo + hi) / 2
		local sx, sz = hi.X - lo.X, hi.Z - lo.Z
		p.Transparency = 1
		p.CastShadow = false
		local inward = Vector3.new(CX - c.X, 0, CZ - c.Z)
		if sx > sz then
			local zf = if inward.Z > 0 then hi.Z else lo.Z
			part("RubberBand", Vector3.new(sx, 1.6, 0.5), CFrame.new(c.X, FY + 1.1, zf + math.sign(inward.Z) * 0.25), Color3.fromRGB(24, 24, 28), Enum.Material.Rubber)
		else
			local xf = if inward.X > 0 then hi.X else lo.X
			part("RubberBand", Vector3.new(0.5, 1.6, sz), CFrame.new(xf + math.sign(inward.X) * 0.25, FY + 1.1, c.Z), Color3.fromRGB(24, 24, 28), Enum.Material.Rubber)
		end
		if PANEL then
			-- panels end to end along the rail's middle line (the last ones overlap a little; every other one
			-- 0.03 off the line)
			local a = if sx > sz then Vector3.new(lo.X, FY, c.Z) else Vector3.new(c.X, FY, lo.Z)
			local b = if sx > sz then Vector3.new(hi.X, FY, c.Z) else Vector3.new(c.X, FY, hi.Z)
			local L = (b - a).Magnitude
			local u = (b - a).Unit
			local PL = PANEL.Size.Z
			local n = math.max(1, math.ceil(L / PL - 0.02))
			for k = 0, n - 1 do
				local t = if n == 1 then L / 2 else PL / 2 + (L - PL) * k / (n - 1)
				local m = a + u * t
				local q = PANEL:Clone()
				q.Name = "FencePanel"
				q.CFrame = CFrame.lookAt(m, m + u) * CFrame.new(if nPanel % 2 == 0 then 0.03 else -0.03, PANEL.Size.Y / 2, 0)
				q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery = true, false, false, false
				q.Parent = dress
				nPanel += 1
			end
		end
	end
end

---------------------------------------------------------------- the posts with LED strips
local RX0, RX1, RZ0, RZ1 = X0 - 2.2, X1 + 2.2, Z0 - 2.2, Z1 + 2.2 -- (the post line, just outside the rails)
local postsZ = {}
local nz = 4
for k = 0, nz do table.insert(postsZ, RZ0 + (RZ1 - RZ0) * k / nz) end
-- (D-1476) the entrance in the east rail (park_swap_1116): no post in front of it, the sign over it
local entrance = workspace["범퍼"]:FindFirstChild("EastEntrance")
local entRamp = entrance and entrance:FindFirstChild("EntranceRamp") :: BasePart?
local ENT_Z = entRamp and entRamp.Position.Z
-- (D-1516) the entrance in the south rail (park_bumper_big_1116, east of the middle): the marquee over it
local southEnt = workspace["범퍼"]:FindFirstChild("SouthEntrance")
local southRamp = southEnt and southEnt:FindFirstChild("EntranceRamp") :: BasePart?
local ENT_X = southRamp and southRamp.Position.X
for _, x in ipairs({ RX0, RX1 }) do
	for _, z in ipairs(postsZ) do
		if ENT_Z and x == RX1 and math.abs(z - ENT_Z) < 8 then continue end
		part("CanopyPost", Vector3.new(1.4, EAVE - FY + 2, 1.4), CFrame.new(x, (FY + EAVE) / 2 - 1, z), STEEL, Enum.Material.Metal, nil, true)
		local inX = if x < CX then 0.75 else -0.75
		local led = part("PostLED", Vector3.new(0.2, EAVE - FY - 4, 0.5), CFrame.new(x + inX, (FY + EAVE) / 2, z), Color3.fromRGB(70, 110, 255), Enum.Material.Neon)
		led.CastShadow = false
	end
end

---------------------------------------------------------------- the striped tent roof
local HALF = (RX1 - RX0) / 2 + OVER
local rise = RIDGE - EAVE
local slopeLen = math.sqrt(HALF * HALF + rise * rise)
local slope = math.atan2(rise, HALF)
local zA, zB = RZ0 - OVER, RZ1 + OVER
local STRIPE = 8
local nStripes = math.ceil((zB - zA) / STRIPE)
local sw = (zB - zA) / nStripes
for k = 0, nStripes - 1 do
	local z = zA + (k + 0.5) * sw
	local col = if k % 2 == 0 then RED else YELLOW
	for _, s in ipairs({ -1, 1 }) do
		-- one half: from the eave at x = CX + s·HALF up to the ridge at CX
		local mid = Vector3.new(CX + s * HALF / 2, (EAVE + RIDGE) / 2, z)
		local cf = CFrame.new(mid) * CFrame.Angles(0, 0, -s * slope) -- (falling towards its eave)
		part("RoofPanel", Vector3.new(slopeLen, 0.4, sw), cf, col, Enum.Material.Fabric)
	end
end
-- gable ends: two triangles of tent cloth at the front and back, striped red / yellow in bands
for _, z in ipairs({ zA, zB }) do
	local bands = 3
	for i = 0, bands - 1 do
		local f0, f1 = i / bands, (i + 1) / bands
		local yA, yB = EAVE + rise * f0, EAVE + rise * f1
		local wA, wB = HALF * (1 - f0), HALF * (1 - f1)
		local col = if i % 2 == 0 then YELLOW else RED
		tri(Vector3.new(CX - wA, yA, z), Vector3.new(CX + wA, yA, z), Vector3.new(CX - wB, yB, z), 0.3, col, Enum.Material.Fabric)
		tri(Vector3.new(CX + wA, yA, z), Vector3.new(CX + wB, yB, z), Vector3.new(CX - wB, yB, z), 0.3, col, Enum.Material.Fabric)
	end
end
-- the truss under the roof: purlins along z (eaves, half-slopes, ridge), rafters across every
-- second stripe, and a tie beam at the eaves
local function under(xOff: number): number -- (the roof's underside over x = CX + xOff)
	return RIDGE - math.abs(xOff) / HALF * rise - 0.6
end
for _, f in ipairs({ -1, -0.5, 0, 0.5, 1 }) do
	local x = CX + f * (HALF - OVER)
	beam("Purlin", Vector3.new(x, under(f * (HALF - OVER)), zA + 1), Vector3.new(x, under(f * (HALF - OVER)), zB - 1), 0.6, STEEL)
end
for k = 0, nStripes, 2 do
	local z = zA + k * sw
	if z > zA + 0.5 and z < zB - 0.5 then
		beam("Rafter", Vector3.new(RX0, under(-(HALF - OVER)), z), Vector3.new(CX, under(0), z), 0.6, STEEL)
		beam("Rafter", Vector3.new(CX, under(0), z), Vector3.new(RX1, under(HALF - OVER), z), 0.6, STEEL)
		beam("TieBeam", Vector3.new(RX0, EAVE - 0.6, z), Vector3.new(RX1, EAVE - 0.6, z), 0.45, STEEL)
		-- a king post and two struts (the triangle truss)
		beam("KingPost", Vector3.new(CX, EAVE - 0.6, z), Vector3.new(CX, under(0), z), 0.4, STEEL)
		for _, s in ipairs({ -1, 1 }) do
			beam("Strut", Vector3.new(CX + s * (HALF - OVER) * 0.5, EAVE - 0.6, z), Vector3.new(CX, under(0) - 1, z), 0.35, STEEL)
		end
	end
end
-- edge beams round the eaves
beam("EaveBeam", Vector3.new(RX0, EAVE - 0.4, zA + 1), Vector3.new(RX0, EAVE - 0.4, zB - 1), 0.9, STEEL)
beam("EaveBeam", Vector3.new(RX1, EAVE - 0.4, zA + 1), Vector3.new(RX1, EAVE - 0.4, zB - 1), 0.9, STEEL)
beam("EaveBeam", Vector3.new(RX0, EAVE - 0.4, RZ0), Vector3.new(RX1, EAVE - 0.4, RZ0), 0.9, STEEL)
beam("EaveBeam", Vector3.new(RX0, EAVE - 0.4, RZ1), Vector3.new(RX1, EAVE - 0.4, RZ1), 0.9, STEEL)

---------------------------------------------------------------- lights
-- warm bulbs along all four eave beams (every 2.5 studs)
local function bulbRow(a: Vector3, b: Vector3, step: number, colorAt: (number) -> Color3)
	local n = math.floor((b - a).Magnitude / step)
	for k = 0, n do bulb(a:Lerp(b, k / n), colorAt(k)) end
end
local warm = function(_) return WARM end
bulbRow(Vector3.new(RX0, EAVE - 1.1, RZ0), Vector3.new(RX0, EAVE - 1.1, RZ1), 2.5, warm)
bulbRow(Vector3.new(RX1, EAVE - 1.1, RZ0), Vector3.new(RX1, EAVE - 1.1, RZ1), 2.5, warm)
bulbRow(Vector3.new(RX0, EAVE - 1.1, RZ0), Vector3.new(RX1, EAVE - 1.1, RZ0), 2.5, warm)
bulbRow(Vector3.new(RX0, EAVE - 1.1, RZ1), Vector3.new(RX1, EAVE - 1.1, RZ1), 2.5, warm)
-- coloured string lights draped across the ceiling (five strings, sagging 2 in the middle)
for i = 1, 5 do
	local z = RZ0 + (RZ1 - RZ0) * i / 6
	local n = 34
	-- (D-1481, user: "전구 달린 줄 더 아래로 내려오게": they hang from 4 under the eaves and sag 9 in the middle,
	-- was 1.6 and 2)
	local TOPY, SAG = EAVE - 4, 9
	local prev
	for k = 0, n do
		local u = k / n
		local x = RX0 + (RX1 - RX0) * u
		local sag = SAG * (1 - (2 * u - 1) ^ 2)
		local p = Vector3.new(x, TOPY - sag, z)
		bulb(p, BULBS[(k + i) % #BULBS + 1], 0.5)
		local joint = k % 4 == 0 or k == n
		if prev and joint then beam("StringWire", prev, p, 0.06, Color3.fromRGB(30, 30, 30)) end
		if joint then prev = p end
	end
end
-- soft lights under the roof (they also light the glossy floor at night)
for _, fz in ipairs({ 0.25, 0.75 }) do
	for _, fx in ipairs({ 0.3, 0.7 }) do
		local holder = part("LightHolder", Vector3.new(1.2, 0.6, 1.2), CFrame.new(RX0 + (RX1 - RX0) * fx, EAVE - 4, RZ0 + (RZ1 - RZ0) * fz), STEEL, Enum.Material.Metal)
		local l = Instance.new("PointLight")
		l.Range = 60 -- (D-1465: hung under the tie beams, the high roof)
		l.Brightness = 1.2
		l.Color = Color3.fromRGB(255, 226, 190)
		l.Parent = holder
	end
end

---------------------------------------------------------------- the marquee sign over the front
do
	local SW, SH = 44, 9
	-- (its face is the frame's +Z: over the front (+z) at first; D-1476, the entrance on the east side:
	-- over the east eave, facing the promenade)
	local base = if ENT_Z
		then CFrame.fromMatrix(Vector3.new(RX1 + OVER + 0.6, EAVE + SH / 2 + 0.6, ENT_Z), -Vector3.zAxis, Vector3.yAxis)
		else CFrame.new(ENT_X or CX, EAVE + SH / 2 + 0.6, RZ1 + OVER + 0.6)
	part("SignBoard", Vector3.new(SW, SH, 0.8), base, PURPLE, Enum.Material.SmoothPlastic)
	part("SignTrim", Vector3.new(SW + 1, SH + 1, 0.5), base * CFrame.new(0, 0, -0.35), Color3.fromRGB(240, 140, 40), Enum.Material.Neon)
	for _, y in ipairs({ -SH / 2 + 0.6, SH / 2 - 0.6 }) do
		local n = 44
		for k = 0, n do
			bulb((base * CFrame.new(-SW / 2 + 0.6 + (SW - 1.2) * k / n, y, 0.5)).Position, WARM, 0.5)
		end
	end
	for _, x in ipairs({ -SW / 2 + 0.6, SW / 2 - 0.6 }) do
		for k = 1, 8 do
			bulb((base * CFrame.new(x, -SH / 2 + 0.6 + (SH - 1.2) * k / 9, 0.5)).Position, WARM, 0.5)
		end
	end
	-- the words, in a surface gui on a front plate
	local plate = part("SignText", Vector3.new(SW - 14, SH - 2.2, 0.1), base * CFrame.new(5, 0, 0.45), PURPLE) -- (the right half, seen from the queue: +x)
	plate.Transparency = 1
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back -- (the plate's back faces +z: this CFrame looks down -z)
	g.CanvasSize = Vector2.new(900, 230)
	g.LightInfluence = 0
	g.Brightness = 1.8
	g.Parent = plate
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "BUMPER CARS"
	t.TextColor3 = Color3.fromRGB(255, 220, 110)
	t.TextStrokeColor3 = Color3.fromRGB(240, 110, 30)
	t.TextStrokeTransparency = 0
	t.Parent = g
	-- the big yellow star and a small blue one at the left, facing +z
	local face = base * CFrame.Angles(0, math.pi, 0) -- (a star's points lie in its X/Y; this turns it to face +z)
	star(face * CFrame.new(SW / 2 - 5.5, 0.6, -0.7), 5.2, 0.5, YELLOW, Enum.Material.Neon) -- (the left, seen from the queue: -x; face's x is the world's -x)
	star(face * CFrame.new(SW / 2 - 12, -2.2, -0.7), 2, 0.4, Color3.fromRGB(70, 140, 255), Enum.Material.Neon)
	-- two legs holding it on the front eave beam
	local baseY = base.Position.Y
	for _, s in ipairs({ -1, 1 }) do
		local a = (base * CFrame.new(s * SW * 0.3, EAVE - 0.4 - baseY, -(OVER * 0.7 + 0.6))).Position
		local b = (base * CFrame.new(s * SW * 0.3, EAVE + 1.2 - baseY, 0)).Position
		beam("SignLeg", a, b, 0.6, STEEL)
	end
end

---------------------------------------------------------------- the back wall (-z)
-- (D-1464 / D-1465, user: "벽 하나만 두고 이미지 넣어", "아래 벽도 삭제하고 이미지로 채워. 이미지 높이에
-- 맞춰서 천장도 높여") the picture (docs/04_ART/park/bumper/bumper_wall.png) whole, from the floor up to
-- IMG_H, as wide as the floor, its face on the hidden back rail's inner face
do
	local face = Z0
	for _, p in ipairs(area:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Rail" and isBackRail(p) then face = select(2, bb(p)).Z end
	end
	local W = X1 - X0
	local wall = part("BackWall", Vector3.new(W, IMG_H, 0.4), CFrame.new((X0 + X1) / 2, FY + IMG_H / 2, face - 0.2), Color3.fromRGB(16, 18, 34), Enum.Material.SmoothPlastic)
	local g = Instance.new("SurfaceGui")
	g.Name = "Mural"
	g.Face = Enum.NormalId.Back -- (+z: towards the arena)
	g.CanvasSize = Vector2.new(IW, IH)
	g.LightInfluence = 0.15
	g.Brightness = 1.3
	g.Parent = wall
	g.CanvasSize = Vector2.new(IW * IMG_N, IH)
	for i = 0, IMG_N - 1 do
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1 / IMG_N, 1)
		img.Position = UDim2.fromScale(i / IMG_N, 0)
		img.BackgroundTransparency = 1
		img.Image = IMG
		img.ScaleType = Enum.ScaleType.Stretch
		img.Parent = g
	end
end

dress.Parent = workspace["범퍼"]
local count = 0
for _, d in ipairs(dress:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
print(("[park_bumper_dress_1115] %d parts; floor x %.1f..%.1f z %.1f..%.1f"):format(count, X0, X1, Z0, Z1))
return count
