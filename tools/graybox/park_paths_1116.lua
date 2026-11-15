--!nocheck
-- 놀이공원 길 디자인 (D-1471, user 2026-11-16: "놀이공원 길 디자인 구현", photos: Everland from the air (a
-- round carousel plaza, paths looping round lawns with cherry trees and strings of light), Lotte World's
-- patterned stone floor (cream tiles with terracotta bands), Everland's Global Fair street (grey paving,
-- brick flower beds with tulips, lamp posts with white globes, tall poles with hanging flower baskets
-- and banners), Coney Island / Navy Pier (benches, bins, planters along the paths)).
--   * a paved network on the park's flat floor (all of it was one light grey slab, now a mid grey): a gate plaza with a
--     rosette, a diagonal path to a round plaza round the carousel (radial terracotta stripes), the
--     main promenade north up the park's middle (narrow between the ferris wheel and the bumper
--     cars until D-1476), plazas where it bends and a round north plaza, short branch paths to each ride's entrance
--   * paving: warm sandstone setts (Cobblestone), terracotta brick edges and cross bands, diamond medallions; every
--     layer at its own height (no shared faces: branch 0.05 / 0.08, path 0.11 / 0.14 / 0.17, plaza
--     0.20 / 0.23 / 0.26 above the floor), each slab 0.3 thick so nothing floats
--   * lawn islands with a low brick curb, cherry trees (ServerStorage.FallingBlossomCherryTree,
--     scripts stripped) and bushes (ServerStorage.ArtAssets.Shrub, scaled down) in the big empty parts
--   * along the paths: lamp posts with three white globes (a PointLight in the top one), benches
--     (the bus stop's Park Bench), bins, brick tulip beds; flower-basket banner poles round the plazas.
--     Furniture is only placed where nothing else stands (GetPartBoundsInBox) and off the paving.
-- Workspace["놀이공원길"], built anew each run. Edit mode, after every park_* ride script; before
-- zfight_fix_1115.

local SS = game:GetService("ServerStorage")
local G = 16.06 -- (the park floor's highest top; every layer is measured from here)

local old = workspace:FindFirstChild("놀이공원길")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "놀이공원길"
local fPave = Instance.new("Folder") fPave.Name = "Paving" fPave.Parent = root
local fGreen = Instance.new("Folder") fGreen.Name = "Green" fGreen.Parent = root
local fFurn = Instance.new("Folder") fFurn.Name = "Furniture" fFurn.Parent = root
root.Parent = workspace

-- the park floor a mid grey (it was a light grey slab: the paths did not show against it); the old
-- colour is kept in the attribute OrigColor
local raise = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ParkRaise")
for _, p in ipairs(raise and raise:GetChildren() or {}) do
	if p:IsA("BasePart") and string.match(p.Name, "^ParkPlatform") then
		if p:GetAttribute("OrigColor") == nil then p:SetAttribute("OrigColor", p.Color) end
		p.Color = Color3.fromRGB(150, 148, 144)
	end
end

local PAVE = Color3.fromRGB(206, 172, 132) -- (the paths' and plazas' field: warm sandstone setts)
local CREAM2 = Color3.fromRGB(236, 228, 210)
local TERRA = Color3.fromRGB(170, 86, 62)
local SAND = Color3.fromRGB(214, 176, 112)
local IRON = Color3.fromRGB(34, 36, 40)
local GLOBE = Color3.fromRGB(255, 244, 222)
local GRASS = Color3.fromRGB(96, 150, 70)
local SOIL = Color3.fromRGB(92, 64, 44)
local BRICK = Color3.fromRGB(156, 84, 64)
local TULIPS = { Color3.fromRGB(230, 40, 60), Color3.fromRGB(250, 200, 40), Color3.fromRGB(246, 120, 170), Color3.fromRGB(250, 130, 40), Color3.fromRGB(200, 90, 210) }

-- levels above G (each its own height: no two faces share a plane)
local LV = { brField = 0.05, brEdge = 0.08, field = 0.11, edge = 0.14, inlay = 0.17, plaza = 0.20, ring = 0.23, star = 0.26, star2 = 0.29 }
local TH = 0.3

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.CanQuery = collide ~= false
	p.CastShadow = collide ~= false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a flat slab, its top at G + lv, centred on (x, z), turned to face dir (its Z along dir)
local function slab(name: string, x: number, z: number, dir: Vector3, w: number, l: number, lv: number, color: Color3, mat: Enum.Material?): Part
	local c = Vector3.new(x, G + lv - TH / 2, z)
	return part(fPave, name, Vector3.new(w, TH, l), CFrame.lookAt(c, c + dir), color, mat)
end
-- a flat disc (Roblox cylinders run along X)
local function disc(name: string, x: number, z: number, r: number, lv: number, color: Color3, mat: Enum.Material?): Part
	return part(fPave, name, Vector3.new(TH, 2 * r, 2 * r), CFrame.new(x, G + lv - TH / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

-- where the paving is (furniture keeps off it): segments {a, b, half width} and circles / boxes
local paved = {}
local function onPaving(p: Vector3, margin: number): boolean
	for _, s in ipairs(paved) do
		if s.kind == "seg" then
			local ab = s.b - s.a
			local t = math.clamp((p - s.a):Dot(ab) / ab:Dot(ab), 0, 1)
			if (s.a + ab * t - p).Magnitude < s.hw + margin then return true end
		elseif s.kind == "circle" then
			if (p - s.c).Magnitude < s.r + margin then return true end
		else
			if math.abs(p.X - s.c.X) < s.hx + margin and math.abs(p.Z - s.c.Z) < s.hz + margin then return true end
		end
	end
	return false
end
local function V(x: number, z: number): Vector3 return Vector3.new(x, 0, z) end

---------------------------------------------------------------- paving
-- a path a → b (flat points), width w: cream field, terracotta brick edges, cross bands and diamond
-- medallions on the middle line; a branch (opts.branch) sits lower so it slips under the path or
-- plaza it starts from, its edges starting opts.edgeFrom studs along
local function path(a: Vector3, b: Vector3, w: number, opts)
	opts = opts or {}
	local d = b - a
	local L = d.Magnitude
	local u = d.Unit
	local side = Vector3.new(-u.Z, 0, u.X)
	local fl = if opts.branch then LV.brField else LV.field
	local ed = if opts.branch then LV.brEdge else LV.edge
	local m = (a + b) / 2
	slab("PathField", m.X, m.Z, u, w, L, fl, PAVE, Enum.Material.Cobblestone)
	local e0, e1 = opts.edgeFrom or 0, opts.edgeTo or 0
	local el = L - e0 - e1
	if el > 0.5 then
		local em = a + u * (e0 + el / 2)
		for _, s in ipairs({ -1, 1 }) do
			local q = em + side * s * (w / 2 - 0.7)
			slab("PathEdge", q.X, q.Z, u, 1.4, el, ed, TERRA, Enum.Material.Brick)
		end
	end
	-- cross bands and medallions (main paths only), kept clear of the ends
	if not opts.branch then
		local step = opts.step or 24
		local n = math.floor((L - 16) / step)
		for k = 0, n do
			local t = (L - n * step) / 2 + k * step
			local q = a + u * t
			if k % 2 == 0 then
				local dq = CFrame.lookAt(Vector3.new(q.X, 0, q.Z), Vector3.new(q.X, 0, q.Z) + u) * CFrame.Angles(0, math.pi / 4, 0)
				local s1 = math.min(5, w * 0.3)
				slab("PathDiamond", q.X, q.Z, dq.LookVector, s1, s1, LV.edge, TERRA, Enum.Material.Slate)
				slab("PathDiamondIn", q.X, q.Z, dq.LookVector, s1 * 0.55, s1 * 0.55, LV.inlay, CREAM2, Enum.Material.Marble)
			else
				slab("PathBand", q.X, q.Z, u, w - 2.8, 0.9, LV.edge, TERRA, Enum.Material.Slate)
			end
		end
	end
	table.insert(paved, { kind = "seg", a = a, b = b, hw = w / 2 })
end

-- a square-cornered plaza (x0..x1, z0..z1) with a brick edge
local function plazaBox(name: string, x0: number, x1: number, z0: number, z1: number)
	local cx, cz, w, l = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	slab(name .. "Edge", cx, cz, Vector3.zAxis, w, l, LV.plaza, TERRA, Enum.Material.Brick)
	slab(name, cx, cz, Vector3.zAxis, w - 2.4, l - 2.4, LV.ring, PAVE, Enum.Material.Cobblestone)
	table.insert(paved, { kind = "box", c = V(cx, cz), hx = w / 2, hz = l / 2 })
end
-- a round plaza: brick ring, cream field, radial stripes from rIn out (n of them)
local function plazaRound(name: string, x: number, z: number, r: number, rIn: number, n: number)
	disc(name .. "Edge", x, z, r, LV.plaza, TERRA, Enum.Material.Brick)
	disc(name, x, z, r - 1.4, LV.ring, PAVE, Enum.Material.Cobblestone)
	for k = 0, n - 1 do
		local a = k / n * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = r - 2.6 - rIn
		local q = V(x, z) + dir * (rIn + len / 2)
		slab(name .. "Stripe", q.X, q.Z, dir, if k % 2 == 0 then 1.6 else 0.8, len, LV.star, if k % 2 == 0 then TERRA else SAND, Enum.Material.Slate)
	end
	table.insert(paved, { kind = "circle", c = V(x, z), r = r })
end
-- a rosette in a plaza's middle
local function rosette(x: number, z: number, r: number)
	disc("RosetteRing", x, z, r, LV.star, TERRA, Enum.Material.Slate)
	disc("Rosette", x, z, r - 1.2, LV.star2, CREAM2, Enum.Material.Marble)
	for k = 0, 7 do
		local a = k / 8 * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = r - 1.4 - 1.4 -- (from 1.4 out, where the rays no longer cross; the hub covers the middle)
		local q = V(x, z) + dir * (1.4 + len / 2)
		slab("RosetteRay", q.X, q.Z, dir, if k % 2 == 0 then 1.1 else 0.6, len, LV.star2 + 0.03, if k % 2 == 0 then TERRA else SAND, Enum.Material.Slate)
	end
	disc("RosetteHub", x, z, 1.6, LV.star2 + 0.06, SAND, Enum.Material.Slate)
end

-- the gate plaza (inside the gate, x -97) and the diagonal path to the carousel plaza
plazaBox("GatePlaza", -128, -74, -366, -288)
rosette(-101, -327, 10)
local HUB = V(-176.5, -448.6)
local HUB_R = 40
do
	local a = V(-114, -360)
	local u = (HUB - a).Unit
	local b = HUB - u * (HUB_R - 3)
	path(a, b, 14, { step = 22 })
end
-- the carousel plaza (round, the carousel's yellow fence inside it)
plazaRound("CarouselPlaza", HUB.X, HUB.Z, HUB_R, 27.5, 32)
-- the promenade north (20 wide all the way since D-1476)
path(V(-176, -482), V(-176, -730), 20)
plazaBox("BumperPlaza", -198, -156, -752, -724)
-- (D-1476: the bumper cars and the wheel swapped; the bumper hall's east rail is at x -187.3, so this
-- stretch is as wide as the rest, was 10 wide at x -184 between the wheel and the hall)
path(V(-176, -746), V(-176, -902), 20)
plazaBox("WheelPlaza", -198, -160, -918, -899)
path(V(-176, -912), V(-176, -1016), 20)
local NORTH = V(-176, -1042)
plazaRound("NorthPlaza", NORTH.X, NORTH.Z, 30, 12, 24)
rosette(NORTH.X, NORTH.Z, 9)
path(V(-176, -1068), V(-176, -1180), 20)
plazaRound("EndPlaza", -176, -1198, 20, 9, 16)

-- branches (lower: they start under the path / plaza they leave)
local function branch(a: Vector3, b: Vector3, w: number, edgeFrom: number)
	path(a, b, w, { branch = true, edgeFrom = edgeFrom })
end
branch(V(-196, -428), V(-239, -371), 12, 16) -- 점핑스타 (its opening faces +x)
branch(V(-210, -452), V(-259, -452), 10, 4) -- the snack stands
branch(V(-176, -523), V(-218, -523), 12, 10) -- 미니바이킹
slab("VikingApronEdge", -214.2, -524, Vector3.zAxis, 19.2, 52, LV.edge, TERRA, Enum.Material.Brick)
slab("VikingApron", -214.2, -524, Vector3.zAxis, 16.8, 49.6, LV.inlay, PAVE, Enum.Material.Cobblestone)
table.insert(paved, { kind = "box", c = V(-214.2, -524), hx = 9.6, hz = 26 })
branch(V(-176, -536), V(-152, -536), 12, 10) -- 회전컵
branch(V(-176, -591), V(-62, -591), 16, 10) -- 슈퍼바이킹 (its two gates face +z at z -600.8)
branch(V(-176, -646), V(-227, -646), 12, 10) -- 평화열차 / 점퍼보트
branch(V(-160, -1056), V(-114, -1092), 12, 4) -- 유레카
branch(V(-176, -1132), V(-155, -1132), 10, 10) -- 번개 코스터
branch(V(-176, -790), V(-96, -790), 12, 10) -- 관람차 (D-1476: its station's stairs face +z at x -110, z -800)
branch(V(-193, -1058), V(-236, -1100), 12, 4) -- 스카이 사이클

---------------------------------------------------------------- free space test
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.FilterDescendantsInstances = { root }
local function blocker(cf: CFrame, size: Vector3): BasePart?
	for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
		if p.Transparency < 0.98 or p.CanCollide then
			local e = (p.CFrame.RightVector * p.Size.X):Abs() + (p.CFrame.UpVector * p.Size.Y):Abs() + (p.CFrame.LookVector * p.Size.Z):Abs()
			if p.Position.Y + e.Y / 2 > G + 0.35 then return p end
		end
	end
	return nil
end
local function freeAt(x: number, z: number, sx: number, sz: number, h: number?): boolean
	return blocker(CFrame.new(x, G + 0.4 + (h or 6) / 2, z), Vector3.new(sx, h or 6, sz)) == nil
end

---------------------------------------------------------------- lawns, trees, bushes
local function cleanModel(m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then d:Destroy() end
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
		end
	end
end
local treeT = SS:FindFirstChild("FallingBlossomCherryTree")
local bushT = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("Shrub")
local rng = Random.new(1116)
local nTrees, nBush = 0, 0
local function tree(x: number, z: number, emit: boolean)
	if not treeT or not freeAt(x, z, 4, 4, 10) then return end
	local t = treeT:Clone()
	cleanModel(t)
	for _, d in ipairs(t:GetDescendants()) do
		if d:IsA("ParticleEmitter") then d.Enabled = emit end
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	local _, s = t:GetBoundingBox()
	t:PivotTo(CFrame.new(x, G + 0.45 + s.Y / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
	-- the trunk alone collides: an invisible post
	local post = part(t, "TrunkCollide", Vector3.new(1.6, 8, 1.6), CFrame.new(x, G + 4, z), GRASS, nil, nil, true)
	post.Transparency = 1
	post.CanQuery = false
	t.Parent = fGreen
	nTrees += 1
end
local function bush(x: number, z: number, scale: number)
	if not bushT then return end
	local b = bushT:Clone()
	cleanModel(b)
	b:ScaleTo(scale)
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false d.CanQuery = false end
	end
	local _, s = b:GetBoundingBox()
	b:PivotTo(CFrame.new(x, G + 0.45 + s.Y / 2 - 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
	b.Parent = fGreen
	nBush += 1
end
-- a lawn (x0..x1, z0..z1): brick curb and grass, trees on a loose grid, bushes along the edges that
-- face a path
local function lawn(name: string, x0: number, x1: number, z0: number, z1: number, trees: number, emitEvery: number)
	local cx, cz, w, l = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	if not freeAt(cx, cz, w - 2, l - 2, 3) then
		local p = blocker(CFrame.new(cx, G + 1.9, cz), Vector3.new(w - 2, 3, l - 2))
		warn("[park_paths] lawn " .. name .. " not clear: " .. (p and p:GetFullName() or "?"))
	end
	part(fGreen, name .. "Curb", Vector3.new(w, 0.75, l), CFrame.new(cx, G + 0.45 - 0.375, cz), BRICK, Enum.Material.Brick)
	part(fGreen, name, Vector3.new(w - 1.6, 0.3, l - 1.6), CFrame.new(cx, G + 0.52 - 0.15, cz), GRASS, Enum.Material.Grass)
	-- trees: a jittered grid
	local cols = math.max(1, math.floor(w / 26 + 0.5))
	local rows = math.max(1, math.ceil(trees / cols))
	local k = 0
	for i = 1, cols do
		for j = 1, rows do
			if k < trees then
				local x = x0 + w * (i - 0.5) / cols + rng:NextNumber(-3, 3)
				local z = z0 + l * (j - 0.5) / rows + rng:NextNumber(-3, 3)
				tree(x, z, k % emitEvery == 0)
				k += 1
			end
		end
	end
	-- bushes along the long edges, 1.6 in from the curb
	local n = math.floor(l / 13)
	for j = 0, n do
		local z = z0 + 3 + (l - 6) * j / math.max(1, n)
		for _, x in ipairs({ x0 + 2.6, x1 - 2.6 }) do
			if freeAt(x, z, 2.5, 2.5, 4) then bush(x, z, 0.32 + rng:NextNumber(0, 0.1)) end
		end
	end
	table.insert(paved, { kind = "box", c = V(cx, cz), hx = w / 2, hz = l / 2 })
end
-- (D-1476: the bumper hall now fills x -297..-187, z -754..-897, and the user's queue fence north of it
-- reaches z -990)
lawn("LawnWestA", -286, -202, -748, -700, 3, 2)
lawn("LawnWestB", -286, -202, -1030, -996, 3, 2)
lawn("LawnEastC", -152, -60, -893, -848, 3, 2)
lawn("LawnEastA", -152, -86, -744, -702, 3, 2)
lawn("LawnEastB", -144, -60, -1050, -1000, 3, 2)
lawn("LawnNorthW", -290, -200, -1360, -1222, 6, 3)
lawn("LawnNorthE", -152, -58, -1360, -1222, 5, 3)

---------------------------------------------------------------- furniture
local nLamp, nBench, nBin, nBed, nPole = 0, 0, 0, 0, 0
local function lamp(x: number, z: number)
	if onPaving(V(x, z), 0.6) or not freeAt(x, z, 2.2, 2.2, 10) then return end
	local m = Instance.new("Model")
	m.Name = "ParkLamp"
	part(m, "LampBase", Vector3.new(1.3, 1.7, 1.7), CFrame.new(x, G + 0.65, z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "LampPole", Vector3.new(9.4, 0.45, 0.45), CFrame.new(x, G + 1.3 + 4.7, z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "LampArm", Vector3.new(4.2, 0.25, 0.25), CFrame.new(x, G + 10.2, z), IRON, Enum.Material.Metal, nil, false)
	local top = part(m, "LampGlobe", Vector3.one * 1.5, CFrame.new(x, G + 11.4, z), GLOBE, Enum.Material.Neon, Enum.PartType.Ball, false)
	for _, s in ipairs({ -1, 1 }) do
		part(m, "LampGlobe", Vector3.one * 1.25, CFrame.new(x + s * 2.0, G + 10.9, z), GLOBE, Enum.Material.Neon, Enum.PartType.Ball, false)
	end
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 226, 180)
	light.Shadows = false
	light.Parent = top
	m.Parent = fFurn
	nLamp += 1
end
local benchT = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("BusShelter") and SS.ArtAssets.BusShelter:FindFirstChild("Park Bench|공원 벤치", true)
local function bench(x: number, z: number, faceTo: Vector3)
	if not benchT or onPaving(V(x, z), 0.4) or not freeAt(x, z, 9, 3, 3) then return false end
	local b = benchT:Clone()
	cleanModel(b)
	local _, s = b:GetBoundingBox()
	-- the bench runs along its X; turn it so it runs across faceTo
	local look = Vector3.new(faceTo.X, 0, faceTo.Z).Unit
	local c = Vector3.new(x, G + s.Y / 2, z)
	b:PivotTo(CFrame.lookAt(c, c + look))
	b.Parent = fFurn
	nBench += 1
	return true
end
local function bin(x: number, z: number)
	if onPaving(V(x, z), 0.3) or not freeAt(x, z, 1.8, 1.8, 3) then return end
	local m = Instance.new("Model")
	m.Name = "ParkBin"
	part(m, "BinBody", Vector3.new(2.6, 1.6, 1.6), CFrame.new(x, G + 1.3, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(44, 110, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "BinLid", Vector3.new(0.35, 1.85, 1.85), CFrame.new(x, G + 2.75, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(30, 80, 50), Enum.Material.Metal, Enum.PartType.Cylinder, false)
	m.Parent = fFurn
	nBin += 1
end
-- a brick tulip bed (l along dir)
local function bed(x: number, z: number, dir: Vector3, l: number, w: number)
	if onPaving(V(x, z), 0.3) or not freeAt(x, z, math.max(l, w) + 0.5, math.max(l, w) + 0.5, 2) then return end
	local m = Instance.new("Model")
	m.Name = "TulipBed"
	local c = Vector3.new(x, G, z)
	local cf = CFrame.lookAt(c, c + Vector3.new(dir.X, 0, dir.Z))
	part(m, "BedBrick", Vector3.new(w, 1.1, l), cf * CFrame.new(0, 0.55, 0), BRICK, Enum.Material.Brick)
	part(m, "BedSoil", Vector3.new(w - 0.8, 0.3, l - 0.8), cf * CFrame.new(0, 1.05 + 0.05, 0), SOIL, Enum.Material.Ground, nil, false)
	part(m, "BedLeaves", Vector3.new(w - 1.2, 0.7, l - 1.2), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(70, 130, 60), Enum.Material.Grass, nil, false)
	local n = math.floor(l / 1.4)
	for k = 0, n - 1 do
		for _, sx in ipairs({ -0.5, 0.5 }) do
			local col = TULIPS[(k + (if sx > 0 then 2 else 0)) % #TULIPS + 1]
			part(m, "Tulip", Vector3.new(0.75, 0.95, 0.75), cf * CFrame.new(sx * (w - 1.8), 2.15 + rng:NextNumber(-0.15, 0.15), -l / 2 + 0.9 + k * (l - 1.8) / math.max(1, n - 1)), col, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
		end
	end
	m.Parent = fFurn
	nBed += 1
end
-- a flower-basket banner pole
local function pole(x: number, z: number, banner: Color3, onPlaza: boolean?)
	if not onPlaza and onPaving(V(x, z), 0.3) then return end
	if not freeAt(x, z, 3, 3, 12) then return end
	local m = Instance.new("Model")
	m.Name = "BasketPole"
	local GREEN = Color3.fromRGB(32, 70, 52)
	local GOLD = Color3.fromRGB(214, 176, 92)
	part(m, "PoleBase", Vector3.new(1.0, 1.4, 1.4), CFrame.new(x, G + 0.5, z) * CFrame.Angles(0, 0, math.pi / 2), GREEN, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "Pole", Vector3.new(14, 0.5, 0.5), CFrame.new(x, G + 7, z) * CFrame.Angles(0, 0, math.pi / 2), GREEN, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "PoleCrown", Vector3.one * 1.1, CFrame.new(x, G + 14.4, z), GOLD, Enum.Material.Metal, Enum.PartType.Ball, false)
	part(m, "Banner", Vector3.new(0.1, 4.4, 2.2), CFrame.new(x, G + 9.2, z + 1.35), banner, Enum.Material.Fabric, nil, false)
	for _, s in ipairs({ -1, 1 }) do
		local bx = x + s * 1.6
		part(m, "BasketArm", Vector3.new(1.6, 0.18, 0.18), CFrame.new(x + s * 0.8, G + 12.2, z), GOLD, Enum.Material.Metal, nil, false)
		part(m, "Basket", Vector3.new(0.9, 1.5, 1.5), CFrame.new(bx, G + 11.4, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 82, 50), Enum.Material.WoodPlanks, Enum.PartType.Cylinder, false)
		part(m, "BasketFlowers", Vector3.new(2.0, 1.4, 2.0), CFrame.new(bx, G + 12.0, z), TULIPS[(s + 3) % #TULIPS + 1], Enum.Material.Grass, Enum.PartType.Ball, false)
	end
	m.Parent = fFurn
	nPole += 1
end

-- along a north-south path at x = cx (half width hw), z from za down to zb: lamps both sides every
-- `step`, a bench + bin between them on alternate sides, a tulip bed now and then outside the lamps
local function dressPath(cx: number, hw: number, za: number, zb: number, step: number)
	local i = 0
	for z = za, zb, -step do
		lamp(cx - hw - 1.4, z)
		lamp(cx + hw + 1.4, z)
		local zm = z - step / 2
		if zm > zb then
			local s = if i % 2 == 0 then -1 else 1
			if bench(cx + s * (hw + 2.4), zm, Vector3.new(-s, 0, 0)) then
				bin(cx + s * (hw + 2.0), zm - 5.6)
			end
			if i % 2 == 1 then bed(cx - s * (hw + 3.2), zm, Vector3.zAxis, 9, 3.2) end
		end
		i += 1
	end
end
dressPath(-176, 10, -500, -722, 26)
dressPath(-176, 10, -760, -890, 26)
dressPath(-176, 10, -926, -1008, 26)
dressPath(-176, 10, -1078, -1172, 24)
-- round the carousel plaza and the north plaza: lamps on the ring (off the paths that come in)
local function ring(c: Vector3, r: number, n: number, poles: boolean)
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * 2 * math.pi
		local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * r
		if poles and k % 2 == 1 then
			pole(p.X, p.Z, TULIPS[k % #TULIPS + 1])
		else
			lamp(p.X, p.Z)
		end
	end
end
ring(HUB, HUB_R + 1.6, 16, true)
ring(NORTH, 31.6, 12, true)
ring(V(-176, -1198), 21.6, 10, false)
-- the gate plaza: banner poles round the rosette, lamps and benches on its sides
for _, q in ipairs({ { -114, -314 }, { -88, -314 }, { -114, -340 }, { -88, -340 } }) do
	pole(q[1], q[2], TULIPS[(q[1] + q[2]) % #TULIPS + 1], true)
end
for z = -296, -360, -16 do
	lamp(-129.6, z)
end
for _, z in ipairs({ -304, -350 }) do
	bench(-131.6, z, Vector3.new(1, 0, 0))
	bed(-132.2, z - 8, Vector3.zAxis, 8, 3)
end

print(("[park_paths_1116] paving %d, trees %d, bushes %d, lamps %d, benches %d, bins %d, beds %d, poles %d"):format(
	#fPave:GetChildren(), nTrees, nBush, nLamp, nBench, nBin, nBed, nPole))
local n = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
print("[park_paths_1116] parts " .. n)
return n
