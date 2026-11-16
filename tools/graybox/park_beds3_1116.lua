--!nocheck
-- 관람차 서쪽 화단, 세모 풀숲 두 곳, 회전목마–소방차 사이 풀숲 밑 블록 (D-1521, user 2026-11-16 + two
-- pictures of the Ferris wheel: "빨간선으로 화단 설치. 세모 그린 곳 안에 풀숲 조성", and a picture of the bush
-- island between the carousel and the fire truck: "회전목마랑 소방차 사이에 있는 화단 밑 블록 생성").
--   * a straight bed (the park style, 6.5 wide) along the west wall from the wheel's south-west corner to
--     the 화단3칸 north of the mini viking (x -257.6, z -551.5..-505.5): 관람차화단.WheelBedWest;
--   * two triangles of bushes on a raised grass base with a brick curb round it: between the wheel's south
--     side and its south bed (WheelThicketSouth), and in the corner of the wheel's east side and its north
--     bed (WheelThicketEast): 관람차화단;
--   * the garden's small island (놀이공원정원.Island2) gets the same base (its bushes' outline, rounded out
--     by 3.2) and its bushes stand on it; a bench under its bushes is taken away.
-- Run after park_garden_1116. Idempotent.

local SS = game:GetService("ServerStorage")
local G = 16.11
local GRASS = Color3.fromRGB(88, 146, 64)
local BRICK = Color3.fromRGB(156, 84, 64)
local BASE_H = 0.9
local o = {}

local leafT
for _, d in ipairs(SS.ArtAssets.Shrub:GetDescendants()) do
	if d:IsA("MeshPart") and (not leafT or d.Size.Magnitude > leafT.Size.Magnitude) then leafT = d end
end
local rng = Random.new(1521)
local wheelBeds = workspace:FindFirstChild("관람차화단") or Instance.new("Folder")
wheelBeds.Name = "관람차화단"
wheelBeds.Parent = workspace

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, collide, false, collide, collide
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- a flat triangle a, b, c (y ignored) as two wedges, from G up to G + BASE_H
local function tri(parent: Instance, a: Vector3, b: Vector3, c: Vector3)
	local y = G + BASE_H / 2
	a, b, c = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z), Vector3.new(c.X, y, c.Z)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Cross(ac).Magnitude < 1e-3 then return end
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
	for _, w in ipairs({
		{ Vector3.new(BASE_H, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back) },
		{ Vector3.new(BASE_H, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back) },
	}) do
		local p = Instance.new("WedgePart")
		p.Name = "BaseGrass"
		p.Size, p.CFrame = w[1], w[2]
		p.Color, p.Material = GRASS, Enum.Material.Grass
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, true, false, true, false
		p.Parent = parent
	end
end
-- a raised base on the polygon pts (a fan from its middle) with a brick curb on its edges
local function base(parent: Instance, pts: {Vector3})
	local mid = Vector3.zero
	for _, p in ipairs(pts) do mid += p end
	mid /= #pts
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]
		tri(parent, mid, a, b)
		local u = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local m = Vector3.new((a.X + b.X) / 2, G + (BASE_H + 0.3) / 2, (a.Z + b.Z) / 2)
		part(parent, "BaseCurb", Vector3.new(0.7, BASE_H + 0.3, u.Magnitude + 0.7), CFrame.lookAt(m, m + u), BRICK, Enum.Material.Brick, true)
	end
end
local function bush(parent: Instance, x: number, z: number, top: number)
	local h = leafT:Clone()
	h.Name = "Bush"
	h.Size = leafT.Size * 0.7 * rng:NextNumber(0.85, 1.15)
	h.CFrame = CFrame.new(x, top + h.Size.Y / 2 - 0.7, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	h.Anchored, h.CanCollide, h.CanTouch, h.CanQuery = true, false, false, false
	h.Parent = parent
end
local function inTri(p: Vector3, a: Vector3, b: Vector3, c: Vector3, margin: number): boolean
	local function side(p1: Vector3, p2: Vector3): number
		local e = Vector3.new(p2.X - p1.X, 0, p2.Z - p1.Z)
		local n = Vector3.new(-e.Z, 0, e.X).Unit
		return (Vector3.new(p.X - p1.X, 0, p.Z - p1.Z)):Dot(n)
	end
	local s1, s2, s3 = side(a, b), side(b, c), side(c, a)
	if s1 < 0 and s2 < 0 and s3 < 0 then s1, s2, s3 = -s1, -s2, -s3 end
	return s1 > margin and s2 > margin and s3 > margin
end

-- the west bed
do
	local old = wheelBeds:FindFirstChild("WheelBedWest")
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = "WheelBedWest"
	local a, b = Vector3.new(-257.6, 0, -551.5), Vector3.new(-257.6, 0, -505.5)
	local L = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	local curb = part(m, "BedCurb", Vector3.new(6.5, 1.2, L), cf + Vector3.new(0, G + 0.9 - 0.6, 0), BRICK, Enum.Material.Brick, true)
	part(m, "BedGrass", Vector3.new(5.8, 0.3, L - 0.7), cf + Vector3.new(0, G + 0.9 + 0.12 - 0.15, 0), GRASS, Enum.Material.Grass, false)
	for s = 2.6, L, 5.2 do
		bush(m, a.X + rng:NextNumber(-0.4, 0.4), a.Z + s, G + 1.02)
	end
	m.PrimaryPart = curb
	m.Parent = wheelBeds
	table.insert(o, "west bed")
end

-- the two triangles
for _, t in ipairs({
	{ "WheelThicketSouth", Vector3.new(-251, 0, -552), Vector3.new(-243.5, 0, -536.4), Vector3.new(-214, 0, -536.4) },
	{ "WheelThicketEast", Vector3.new(-185.5, 0, -629.8), Vector3.new(-162.7, 0, -629.8), Vector3.new(-185.5, 0, -598) },
}) do
	local old = wheelBeds:FindFirstChild(t[1])
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = t[1]
	base(m, { t[2], t[3], t[4] })
	local n = 0
	local lo = t[2]:Min(t[3]):Min(t[4])
	local hi = t[2]:Max(t[3]):Max(t[4])
	for x = lo.X, hi.X, 4.2 do
		for z = lo.Z, hi.Z, 4.2 do
			local px, pz = x + rng:NextNumber(-0.8, 0.8), z + rng:NextNumber(-0.8, 0.8)
			if inTri(Vector3.new(px, 0, pz), t[2], t[3], t[4], 1.6) then
				bush(m, px, pz, G + BASE_H)
				n += 1
			end
		end
	end
	m.Parent = wheelBeds
	table.insert(o, ("%s %d bushes"):format(t[1], n))
end

-- the garden's small island on a base
do
	local isl = workspace:FindFirstChild("놀이공원정원") and workspace["놀이공원정원"]:FindFirstChild("Island2")
	if isl and not isl:FindFirstChild("BaseCurb") then
		local pts = {}
		for _, b in ipairs(isl:GetChildren()) do
			if b.Name == "Bush" then table.insert(pts, Vector3.new(b.Position.X, 0, b.Position.Z)) end
		end
		-- benches under the bushes go
		for _, c in ipairs(isl:GetChildren()) do
			if c:IsA("Model") and c.Name == "ParkBenchV2" then
				local at = c:GetPivot().Position
				for _, p in ipairs(pts) do
					if (Vector3.new(at.X, 0, at.Z) - p).Magnitude < 4.5 then
						c:Destroy()
						table.insert(o, "bench under bushes removed")
						break
					end
				end
			end
		end
		-- convex hull (monotone chain), rounded out from the middle by 3.2
		table.sort(pts, function(a, b) return a.X < b.X or (a.X == b.X and a.Z < b.Z) end)
		local function cross(o2: Vector3, a: Vector3, b: Vector3): number
			return (a.X - o2.X) * (b.Z - o2.Z) - (a.Z - o2.Z) * (b.X - o2.X)
		end
		local lower, upper = {}, {}
		for _, p in ipairs(pts) do
			while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do table.remove(lower) end
			table.insert(lower, p)
		end
		for i = #pts, 1, -1 do
			local p = pts[i]
			while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do table.remove(upper) end
			table.insert(upper, p)
		end
		table.remove(lower)
		table.remove(upper)
		local hull = {}
		for _, p in ipairs(lower) do table.insert(hull, p) end
		for _, p in ipairs(upper) do table.insert(hull, p) end
		local mid = Vector3.zero
		for _, p in ipairs(hull) do mid += p end
		mid /= #hull
		for i, p in ipairs(hull) do hull[i] = p + (p - mid).Unit * 3.2 end
		base(isl, hull)
		for _, b in ipairs(isl:GetChildren()) do
			if b.Name == "Bush" then b.CFrame += Vector3.new(0, BASE_H, 0) end
		end
		table.insert(o, ("island 2 base, %d corners"):format(#hull))
	end
end

-- (D-1522, user: "해당 묶음 가운데 벚꽃나무만 두고 삭제.. 가로등 위치 재배치") the garden's big island keeps its
-- cherry trees (and benches): its bushes go, and its four lamps by the rides' south end stand on the trees'
-- line instead, between and past them (x -165..-168, z -458 / -498 / -536 / -590)
do
	local isl = workspace:FindFirstChild("놀이공원정원") and workspace["놀이공원정원"]:FindFirstChild("Island1")
	if isl then
		local n = 0
		for _, c in ipairs(isl:GetChildren()) do
			if c.Name == "Bush" then
				c:Destroy()
				n += 1
			end
		end
		local spots = { Vector3.new(-165, 0, -458), Vector3.new(-165, 0, -498), Vector3.new(-163, 0, -536), Vector3.new(-168, 0, -590) }
		local strip = {}
		for _, c in ipairs(isl:GetChildren()) do
			if c.Name == "ParkLampV2" and c:GetPivot().Z > -500 then table.insert(strip, c) end
		end
		table.sort(strip, function(a, b) return a:GetPivot().Z > b:GetPivot().Z end)
		for i, l in ipairs(strip) do
			local at = spots[i]
			if at then
				local p = l:GetPivot()
				l:PivotTo(CFrame.new(at.X, p.Y, at.Z) * p.Rotation)
			end
		end
		table.insert(o, ("island 1: %d bushes off, %d lamps moved"):format(n, math.min(#strip, #spots)))
	end
end

print("[park_beds3_1116] " .. table.concat(o, "; "))
return table.concat(o, "; ")
