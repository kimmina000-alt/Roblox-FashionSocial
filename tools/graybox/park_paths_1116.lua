--!nocheck
-- 놀이공원 바닥 + 화단 (D-1471 → D-1477).
-- D-1471 (user 2026-11-16: "놀이공원 길 디자인 구현") laid paved paths, plazas and lawns on the park's grey floor.
-- D-1477 (user 2026-11-16, the park's aerial with the paths painted white and flower beds green: "흰색=길
-- 연두색=화단 / 놀이기구 가장자리로 일정 거리 두고 화단 심어 줘 / 땅으로 곡선 만들기 어려우니까 현재 땅 텍스처 땅 하나로
-- 쭉 깔고 화단 배치할 때 위치 조절해서 위에서 봤을 때 곡선으로 보이도록 / 화단은 사람이 못 밟게 해"):
--   * the whole park floor is one paving: two slabs of the paths' sandstone setts (Cobblestone,
--     206/172/132), 0.05 over the old floor (the paths, plazas and their patterns are gone)
--   * the layout is made by raised flower beds (D-1478: planters like the user's own 화단 — granite edges,
--     soil, a close hedge of the Shrub's leafy mesh; some cherry trees and lamp posts in them): along the park's walls, round the rides at a distance, rows
--     between the ride blocks on the west side; curves (round the tea cups, the Jumping Star) are short
--     straight pieces turned along the arc, so from above they read as curves. Every bed has an
--     invisible wall 12 high over it: nobody steps or jumps onto it.
--   * benches and bins stand by the beds on the walking side; the north lawns stay, walled the same way
-- Workspace["놀이공원길"], built anew each run. Edit mode, after the ride scripts and park_swap_1116;
-- before park_playground_1116 and zfight_fix_1115.

local SS = game:GetService("ServerStorage")
local G = 16.06

local old = workspace:FindFirstChild("놀이공원길")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "놀이공원길"
local fGround = Instance.new("Folder") fGround.Name = "Ground" fGround.Parent = root
local fBeds = Instance.new("Folder") fBeds.Name = "Beds" fBeds.Parent = root
local fGreen = Instance.new("Folder") fGreen.Name = "Green" fGreen.Parent = root
local fFurn = Instance.new("Folder") fFurn.Name = "Furniture" fFurn.Parent = root
root.Parent = workspace

-- (D-1471) the old floor under it a mid grey (its sides show from the beach); its first colour is kept
-- in the attribute OrigColor
local raise = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ParkRaise")
for _, p in ipairs(raise and raise:GetChildren() or {}) do
	if p:IsA("BasePart") and string.match(p.Name, "^ParkPlatform") then
		if p:GetAttribute("OrigColor") == nil then p:SetAttribute("OrigColor", p.Color) end
		p.Color = Color3.fromRGB(150, 148, 144)
	end
end

local PAVE = Color3.fromRGB(206, 172, 132)
local IRON = Color3.fromRGB(34, 36, 40)
local GLOBE = Color3.fromRGB(255, 244, 222)
local GRASS = Color3.fromRGB(88, 146, 64)
local BRICK = Color3.fromRGB(156, 84, 64)

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
local function V(x: number, z: number): Vector3 return Vector3.new(x, 0, z) end

---------------------------------------------------------------- the ground: one paving
-- (inside the walls: the long part x -296.95..-52.5 from z -336 north to the north wall, and the
-- strip in front of the gate x -182..-52.5, z -336..-279.5)
local GROUND_TOP = G + 0.05
for _, r in ipairs({ { -296.95, -52.5, -1364.5, -336 }, { -182, -52.5, -336, -279.5 } }) do
	local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
	part(fGround, "Paving", Vector3.new(x1 - x0, 0.4, z1 - z0), CFrame.new((x0 + x1) / 2, GROUND_TOP - 0.2, (z0 + z1) / 2), PAVE, Enum.Material.Cobblestone)
end

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
local function cleanModel(m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then d:Destroy() end
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
		end
	end
end

---------------------------------------------------------------- flower beds
-- (D-1478, user 2026-11-16: "동그란 거 다 삭제하고 동그라미친 풀 사용해서 세 번째 사진처럼 만들어서 배치해 … 세 번째
-- 사진은 직선이고 저기에서 화단 풀을 살짝씩 옆으로 이동하면서 쭉 놓으면 곡선 되겠지", the third photo = the user's own
-- planter by the Jumping Star (Workspace.화단): low granite edges, dark soil, the Shrub's leafy mesh packed
-- close in one row. The flower balls and the brick / grass beds of D-1477 are gone; the beds are such
-- planters, their hedge a row of the leafy mesh every HEDGE_STEP, each pushed a little sideways; on
-- the curves the pieces turn along the arc and the hedge follows them.)
local BED_W = 6.5
local EDGE_W, EDGE_H, SOIL_H = 0.66, 1.3, 1.0
local WALL = 12 -- (the invisible wall over each bed)
local STONE = Color3.fromRGB(196, 194, 188)
local SOIL = Color3.fromRGB(98, 74, 52)
local beds = {} -- {a, b, w}: for what stands in and beside them
local nPiece = 0
-- one straight piece a → b (flat points), w wide, `ext` longer at both ends (joints overlap; every
-- other piece 0.04 higher, so no two tops share a plane)
local function piece(a: Vector3, b: Vector3, w: number, ext: number)
	local d = b - a
	if d.Magnitude < 0.2 then return end
	local u = d.Unit
	local a2, b2 = a - u * ext, b + u * ext
	local L = (b2 - a2).Magnitude
	local m = (a2 + b2) / 2
	nPiece += 1
	local lift = (nPiece % 2) * 0.04
	local cf = CFrame.lookAt(Vector3.new(m.X, 0, m.Z), Vector3.new(m.X, 0, m.Z) + u)
	for _, sx in ipairs({ -1, 1 }) do
		local h = EDGE_H + lift + 0.3
		part(fBeds, "PlanterEdge", Vector3.new(EDGE_W, h, L), cf * CFrame.new(sx * (w / 2 - EDGE_W / 2), G + EDGE_H + lift - h / 2, 0), STONE, Enum.Material.Granite)
	end
	local sh = SOIL_H + lift + 0.3
	part(fBeds, "PlanterSoil", Vector3.new(w - 2 * EDGE_W + 0.1, sh, L - 0.1), cf + Vector3.new(0, G + SOIL_H + lift - sh / 2, 0), SOIL, Enum.Material.Ground, nil, false)
	local wall = part(fBeds, "BedWall", Vector3.new(w, WALL, L), cf + Vector3.new(0, G + WALL / 2, 0), STONE, nil, nil, true)
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CastShadow = false
	table.insert(beds, { a = a, b = b, w = w })
end
-- a stone end on a bed's open end (p, the bed running along u)
local function cap(p: Vector3, u: Vector3, w: number)
	local cf = CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, 0, p.Z) + u)
	part(fBeds, "PlanterEdge", Vector3.new(w, EDGE_H + 0.32, EDGE_W), cf + Vector3.new(0, G + EDGE_H + 0.02 - (EDGE_H + 0.32) / 2, 0), STONE, Enum.Material.Granite)
end
local function line(points: {Vector3}, w: number?)
	w = w or BED_W
	for i = 1, #points - 1 do piece(points[i], points[i + 1], w, w / 2) end
	local u0 = (points[2] - points[1]).Unit
	local u1 = (points[#points] - points[#points - 1]).Unit
	cap(points[1] - u0 * (w / 2 - EDGE_W / 2), u0, w)
	cap(points[#points] + u1 * (w / 2 - EDGE_W / 2), u1, w)
end
-- an arc round c, radius r, from angle a0 to a1 (degrees; x = cos, z = sin: 90 = south, 180 = west)
local function arc(c: Vector3, r: number, a0: number, a1: number, w: number?)
	w = w or BED_W
	local n = math.max(2, math.ceil(math.abs(math.rad(a1 - a0)) * r / 5))
	local pts = {}
	for i = 0, n do
		local a = math.rad(a0 + (a1 - a0) * i / n)
		table.insert(pts, c + Vector3.new(math.cos(a), 0, math.sin(a)) * r)
	end
	for i = 1, #pts - 1 do piece(pts[i], pts[i + 1], w, 0.35) end
	cap(pts[1] - (pts[2] - pts[1]).Unit * 0.35, (pts[2] - pts[1]).Unit, w)
	cap(pts[#pts] + (pts[#pts] - pts[#pts - 1]).Unit * 0.35, (pts[#pts] - pts[#pts - 1]).Unit, w)
end

local WX = -293.2 -- (the west wall bed's middle line: inside the wall, clear of the bumper hall's rail at -289.55)
local EX = -55.8 -- (the east wall bed's)
-- along the walls
line({ V(WX, -351), V(WX, -1218) })
line({ V(EX, -283.5), V(EX, -905) })
-- the north band (north of the bumper cars and the wheel), open for the promenade at x -190..-162
line({ V(WX, -905), V(-190, -905) })
line({ V(-162, -905), V(EX, -905) })
-- the west column: a row under the bumper cars, rows between the ride blocks, a divider along their
-- east side with openings
line({ V(WX, -759), V(-219, -759) }) -- (clear of the hall's canopy posts at z -766.3)
line({ V(WX, -578), V(-219, -578) })
line({ V(WX, -484.5), V(-219, -484.5) })
line({ V(WX, -414), V(-227, -414) })
line({ V(-219, -759), V(-219, -728) })
line({ V(-219, -712), V(-219, -650) })
line({ V(-219, -632), V(-219, -578) })
line({ V(-219, -578), V(-219, -560) })
-- round the Jumping Star (open to the north-east, its entrance faces +x)
arc(V(-255.8, -370.4), 17.5, 30, 225)
-- round the tea cups (open to the west, the way in), and a row from it down to the east wall
-- between the tea cups and the fire trucks
arc(V(-111, -535), 41, -150, 150)
line({ V(-146.5, -514.5), V(-130, -462), V(EX, -462) })
-- by the gate: north of the gate plaza (next to the fire trucks) and north of the playground
line({ V(-108, -365), V(EX, -365) }) -- (clear of the fire trucks' fence, z -370.4)
line({ V(-178, -376.5), V(-138, -376.5) })

---------------------------------------------------------------- what grows in the beds
local treeT = SS:FindFirstChild("FallingBlossomCherryTree")
local leafT -- (the Shrub's leafy mesh: the circled bush; its small trunk mesh is left out, as in the user's planter)
do
	local shrub = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("Shrub")
	for _, d in ipairs(shrub and shrub:GetDescendants() or {}) do
		if d:IsA("MeshPart") and (not leafT or d.Size.Magnitude > leafT.Size.Magnitude) then leafT = d end
	end
end
local rng = Random.new(1478)
local HEDGE_STEP = 5.2
local HEDGE_SCALE = 0.7 -- (the leafy mesh 10 across → 7: a little wider than the soil, like the user's)
local nTrees, nBush = 0, 0
local function tree(x: number, z: number, emit: boolean, top: number)
	if not treeT then return end
	local t = treeT:Clone()
	cleanModel(t)
	for _, d in ipairs(t:GetDescendants()) do
		if d:IsA("ParticleEmitter") then d.Enabled = emit end
		if d:IsA("BasePart") then d.CanCollide = false d.CanQuery = false end
	end
	local _, s = t:GetBoundingBox()
	t:PivotTo(CFrame.new(x, top + s.Y / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0))
	t.Parent = fGreen
	nTrees += 1
end
local function leaf(at: Vector3, scale: number, top: number)
	if not leafT then return end
	local b = leafT:Clone()
	b.Name = "Hedge"
	b.Size = leafT.Size * scale
	b.CFrame = CFrame.new(at.X, top + b.Size.Y / 2 - 0.7, at.Z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	b.Anchored = true
	b.CanCollide = false
	b.CanTouch = false
	b.CanQuery = false
	b.Parent = fGreen
	nBush += 1
end
local nLamp = 0
local function lamp(x: number, z: number, top: number)
	local m = Instance.new("Model")
	m.Name = "ParkLamp"
	part(m, "LampBase", Vector3.new(1.3, 1.7, 1.7), CFrame.new(x, top + 0.65, z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	part(m, "LampPole", Vector3.new(9.4, 0.45, 0.45), CFrame.new(x, top + 1.3 + 4.7, z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	part(m, "LampArm", Vector3.new(4.2, 0.25, 0.25), CFrame.new(x, top + 10.2, z), IRON, Enum.Material.Metal, nil, false)
	local glow = part(m, "LampGlobe", Vector3.one * 1.5, CFrame.new(x, top + 11.4, z), GLOBE, Enum.Material.Neon, Enum.PartType.Ball, false)
	for _, s in ipairs({ -1, 1 }) do
		part(m, "LampGlobe", Vector3.one * 1.25, CFrame.new(x + s * 2.0, top + 10.9, z), GLOBE, Enum.Material.Neon, Enum.PartType.Ball, false)
	end
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 226, 180)
	light.Shadows = false
	light.Parent = glow
	m.Parent = fFurn
	nLamp += 1
end
-- the hedge: one leafy bush every HEDGE_STEP along each bed, each pushed up to 0.5 sideways; a lamp
-- every 17th spot, a cherry tree every 25th on the long wall beds (parts: the park stays under 1,500)
local spot = 0
local carry = 0 -- (the distance left over from the last piece: the hedge runs on round the curves)
for _, b in ipairs(beds) do
	local d = b.b - b.a
	local L = d.Magnitude
	local u = d.Unit
	local side = Vector3.new(-u.Z, 0, u.X)
	local top = G + SOIL_H
	local long = L > 150
	local s = carry
	while s < L do
		local at = b.a + u * s
		spot += 1
		if spot % 17 == 0 then
			lamp(at.X, at.Z, top)
		elseif long and spot % 25 == 7 then
			tree(at.X, at.Z, spot % 50 == 7, top)
		else
			leaf(at + side * rng:NextNumber(-0.5, 0.5), HEDGE_SCALE * rng:NextNumber(0.9, 1.08), top)
		end
		s += HEDGE_STEP
	end
	carry = if L < 12 then s - L else 0
end

---------------------------------------------------------------- benches and bins by the beds
local benchT = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("BusShelter") and SS.ArtAssets.BusShelter:FindFirstChild("Park Bench|공원 벤치", true)
local nBench, nBin = 0, 0
local function inBed(p: Vector3, margin: number): boolean
	for _, b in ipairs(beds) do
		local ab = b.b - b.a
		local t = math.clamp((p - b.a):Dot(ab) / ab:Dot(ab), 0, 1)
		local q = b.a + ab * t
		if (Vector3.new(p.X - q.X, 0, p.Z - q.Z)).Magnitude < b.w / 2 + margin then return true end
	end
	return false
end
local function bench(at: Vector3, faceTo: Vector3): boolean
	local along = Vector3.new(faceTo.Z, 0, -faceTo.X)
	if not benchT or not freeAt(at.X, at.Z, 9, 9, 3) then return false end
	if inBed(at, 1) or inBed(at + along * 4.5, 1) or inBed(at - along * 4.5, 1) then return false end
	local b = benchT:Clone()
	cleanModel(b)
	local _, s = b:GetBoundingBox()
	local c = Vector3.new(at.X, GROUND_TOP + s.Y / 2, at.Z)
	b:PivotTo(CFrame.lookAt(c, c + faceTo))
	b.Parent = fFurn
	nBench += 1
	return true
end
local function bin(at: Vector3)
	if not freeAt(at.X, at.Z, 1.8, 1.8, 3) then return end
	local m = Instance.new("Model")
	m.Name = "ParkBin"
	part(m, "BinBody", Vector3.new(2.6, 1.6, 1.6), CFrame.new(at.X, GROUND_TOP + 1.3, at.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(44, 110, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "BinLid", Vector3.new(0.35, 1.85, 1.85), CFrame.new(at.X, GROUND_TOP + 2.75, at.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(30, 80, 50), Enum.Material.Metal, Enum.PartType.Cylinder, false)
	m.Parent = fFurn
	nBin += 1
end
-- a bench by every straight bed 30 or longer (two on the very long ones), on whichever side is
-- free, facing away from the bed
for _, b in ipairs(beds) do
	local d = b.b - b.a
	local L = d.Magnitude
	if L >= 30 then
		local u = d.Unit
		local side = Vector3.new(-u.Z, 0, u.X)
		local n = if L > 300 then 2 else 1
		for i = 1, n do
			local at = b.a + u * (L * i / (n + 1))
			for _, sgn in ipairs({ 1, -1 }) do
				local spotAt = at + side * sgn * (b.w / 2 + 1.8)
				local probe = at + side * sgn * (b.w / 2 + 6)
				if freeAt(probe.X, probe.Z, 6, 6, 4) and bench(spotAt, side * sgn) then
					bin(spotAt + u * 5.6)
					break
				end
			end
		end
	end
end

---------------------------------------------------------------- lawns in the north (walled like the beds)
local function lawn(name: string, x0: number, x1: number, z0: number, z1: number, trees: number, emitEvery: number)
	local cx, cz, w, l = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	part(fGreen, name .. "Curb", Vector3.new(w, 0.9, l), CFrame.new(cx, G, cz), BRICK, Enum.Material.Brick)
	part(fGreen, name, Vector3.new(w - 1.6, 0.3, l - 1.6), CFrame.new(cx, G + 0.52 - 0.15, cz), GRASS, Enum.Material.Grass)
	local wall = part(fGreen, name .. "Wall", Vector3.new(w, WALL, l), CFrame.new(cx, G + WALL / 2, cz), BRICK, nil, nil, true)
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CastShadow = false
	local cols = math.max(1, math.floor(w / 26 + 0.5))
	local rows = math.max(1, math.ceil(trees / cols))
	local k = 0
	for i = 1, cols do
		for j = 1, rows do
			if k < trees then
				tree(x0 + w * (i - 0.5) / cols + rng:NextNumber(-3, 3), z0 + l * (j - 0.5) / rows + rng:NextNumber(-3, 3), k % emitEvery == 0, G + 0.45)
				k += 1
			end
		end
	end
	local n = math.floor(l / 13)
	for j = 0, n do
		local z = z0 + 3 + (l - 6) * j / math.max(1, n)
		for _, x in ipairs({ x0 + 2.6, x1 - 2.6 }) do leaf(V(x, z), 0.4 + rng:NextNumber(0, 0.1), G + 0.52) end
	end
end
lawn("LawnWestB", -286, -202, -1030, -996, 3, 2)
lawn("LawnEastB", -144, -60, -1050, -1000, 3, 2)
lawn("LawnNorthW", -290, -200, -1360, -1222, 6, 3)
lawn("LawnNorthE", -152, -58, -1360, -1222, 5, 3)

local n = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
print(("[park_paths_1116] beds %d pieces, trees %d, hedge bushes %d, lamps %d, benches %d, bins %d; parts %d"):format(
	nPiece, nTrees, nBush, nLamp, nBench, nBin, n))
return n
