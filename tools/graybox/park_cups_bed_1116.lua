--!nocheck
-- 회전컵 둘레 둥근 화단 (D-1504, user 2026-11-16 + a picture with an arc round the tea cups' east side:
-- "회전컵 펜스 10스터드 밖으로 화단 설치. 위에 화단 가지고 오든지 사이즈 안 맞으면 위에 기존 화단 삭제하고 새로
-- 만들어"). The old beds round here did not fit the new ring, so they are deleted and the ring is new:
-- fence radius 37.2 (D-1502) + 10 path + a 6.5 bed, north arc -130°..-28° and south arc 28°..130°: open
-- to the west (the carousel stands 3 from the fence there) and at the east, where the east wall bed
-- already runs (kept). Model: Workspace.놀이공원길.CupBeds (CupBedNorth / CupBedSouth).
-- Made from park_star_bed_1116 (D-1501):
-- 점핑스타 둘레 둥근 화단 (D-1501, user 2026-11-16 + a picture with two red arcs round the jumping star:
-- "점핀스타 펜스 밖으로 10스터드씩 길 두고 회전컵에 화단 두른 것처럼 화단 둥글게 배치").
-- Round the jumping star (its Ride pivot), a 10-stud path outside its fence (radius 9.8 + 10), then two
-- curved beds like the tea cups' ring (park_paths_1116: brick curb, grass top, a leafy bush every 5.2,
-- each a little sideways): the north arc and the south arc, open to the east (the ride's entrance)
-- and to the west (the park wall, the arcs stop 1 clear of it). Hedges of the old beds within the
-- new path and ring are set aside in ServerStorage.ParkMoveRemoved_1116; a lamp, bench or bin in them
-- moves out past the ring. Model: Workspace.놀이공원길.StarBeds (rebuilt each run).

local SS = game:GetService("ServerStorage")
local G = 16.06
local GRASS = Color3.fromRGB(88, 146, 64)
local BRICK = Color3.fromRGB(156, 84, 64)
local BED_W = 6.5
local CURB = 0.9
local SOIL_H = CURB + 0.12
local FENCE_R = 37.2
local PATH = 10
local R = FENCE_R + PATH + BED_W / 2 -- (the beds' middle line)
local ARCS = { { -130, -28 }, { 28, 130 } } -- (degrees, x = cos, z = sin: -90 north, 90 south)
local HEDGE_STEP = 5.2
local HEDGE_SCALE = 0.7

local paths = workspace:FindFirstChild("놀이공원길")
local star = workspace:FindFirstChild("회전컵")
assert(paths and star and star:FindFirstChild("Base"), "no 놀이공원길 / 회전컵")
local c3 = star.Base.Position
local C = Vector3.new(c3.X, 0, c3.Z)

-- (D-1507) a Folder at the top of Workspace: in Studio a click picks each arc's own model (inside the
-- 놀이공원길 model a click picked the whole park)
local old = workspace:FindFirstChild("회전컵화단")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "회전컵화단"

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, collide, false, collide, collide
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = root
	return p
end
local n = 0
local function piece(a: Vector3, b: Vector3)
	local u = (b - a).Unit
	local a2, b2 = a - u * 0.35, b + u * 0.35
	local L = (b2 - a2).Magnitude
	local m = (a2 + b2) / 2
	n += 1
	local lift = (n % 2) * 0.04
	local cf = CFrame.lookAt(m, m + u)
	local curbH = CURB + lift + 0.3
	part("BedCurb", Vector3.new(BED_W, curbH, L), cf + Vector3.new(0, G + CURB + lift - curbH / 2, 0), BRICK, Enum.Material.Brick, true)
	part("BedGrass", Vector3.new(BED_W - 0.7, 0.3, L - 0.2), cf + Vector3.new(0, G + CURB + lift + 0.12 - 0.15, 0), GRASS, Enum.Material.Grass, false)
end

-- clear the path and the ring first: old hedges set aside, furniture moved out
local keep = SS:FindFirstChild("ParkMoveRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkMoveRemoved_1116"
keep.Parent = SS
local function flatR(p: Vector3): number return (Vector3.new(p.X, 0, p.Z) - C).Magnitude end
for _, folder in ipairs(paths:GetChildren()) do
	if folder.Name == "Green" or folder.Name == "Beds" then
		-- (D-1504) the old beds here are deleted (the user: "기존 화단 삭제"): any piece reaching into the
		-- path or the ring, sampled every 2 studs along its length; the east wall bed (x > -62) stays
		for _, d in ipairs(folder:GetChildren()) do
			local hit = false
			if d:IsA("BasePart") then
				local L = math.max(d.Size.X, d.Size.Z)
				local axis = if d.Size.Z >= d.Size.X then d.CFrame.LookVector else d.CFrame.RightVector
				for s2 = -L / 2, L / 2, 2 do
					local q = d.Position + axis * s2
					local r = flatR(q)
					if r < R + BED_W / 2 + 1 and r > FENCE_R - 1 and q.X < -62 then hit = true break end
				end
			elseif d:IsA("Model") then
				local q = d:GetPivot().Position
				local r = flatR(q)
				hit = r < R + BED_W / 2 + 1 and r > FENCE_R - 1 and q.X < -62
			end
			if hit then d:Destroy() end
		end
	elseif folder.Name == "Furniture" then
		for _, f in ipairs(folder:GetChildren()) do
			if f:IsA("Model") then
				local pos = f:GetPivot().Position
				local r = flatR(pos)
				if r < R + BED_W / 2 + 1 and r > FENCE_R and pos.X < -62 then -- (the east wall bed's lamps stay)
					local out = C + (Vector3.new(pos.X, 0, pos.Z) - C).Unit * (R + BED_W / 2 + 2.5)
					local d = Vector3.new(out.X - pos.X, 0, out.Z - pos.Z)
					for _, p in ipairs(f:GetDescendants()) do if p:IsA("BasePart") then p.CFrame += d end end
					f.WorldPivot += d
				end
			end
		end
	end
end

-- the beds and their hedges
local leafT
do
	local shrub = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("Shrub")
	for _, d in ipairs(shrub and shrub:GetDescendants() or {}) do
		if d:IsA("MeshPart") and (not leafT or d.Size.Magnitude > leafT.Size.Magnitude) then leafT = d end
	end
end
local rng = Random.new(1504)
local bushes = 0
for _, a in ipairs(ARCS) do
	local a0, a1 = a[1], a[2]
	local steps = math.max(2, math.ceil(math.abs(math.rad(a1 - a0)) * R / 5))
	local pts = {}
	for i = 0, steps do
		local t = math.rad(a0 + (a1 - a0) * i / steps)
		table.insert(pts, C + Vector3.new(math.cos(t), 0, math.sin(t)) * R)
	end
	for i = 1, #pts - 1 do piece(pts[i], pts[i + 1]) end
	if leafT then
		local len = math.abs(math.rad(a1 - a0)) * R
		local s = HEDGE_STEP / 2
		while s < len do
			local t = math.rad(a0 + (a1 - a0) * s / len)
			local at = C + Vector3.new(math.cos(t), 0, math.sin(t)) * (R + rng:NextNumber(-0.5, 0.5))
			local b = leafT:Clone()
			b.Name = "Hedge"
			b.Size = leafT.Size * HEDGE_SCALE * rng:NextNumber(0.9, 1.08)
			b.CFrame = CFrame.new(at.X, G + SOIL_H + b.Size.Y / 2 - 0.7, at.Z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
			b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery = true, false, false, false
			b.Parent = root
			bushes += 1
			s += HEDGE_STEP
		end
	end
end
-- (D-1502, user: "화단 두 개 따로 묶어 줘") each arc its own model: StarBedNorth / StarBedSouth
local north, south = Instance.new("Model"), Instance.new("Model")
north.Name, south.Name = "CupBedNorth", "CupBedSouth"
for _, p in ipairs(root:GetChildren()) do
	if p:IsA("BasePart") then p.Parent = if p.Position.Z < C.Z then north else south end
end
north.Parent, south.Parent = root, root
root.Parent = workspace
print(("[park_cups_bed_1116] radius %.2f, %d pieces, %d bushes"):format(R, n, bushes))
return n
