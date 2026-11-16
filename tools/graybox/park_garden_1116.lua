--!nocheck
-- 놀이공원 빈 땅 정원 (D-1518, user 2026-11-16 + an amusement park photo: lawns between curving paths,
-- round shrubs, trees: "사진 참고하여 풀숲(잔디 대용) 적절히 사용하여 배치 디자인해. 벤치랑 가로등, 나무도 설치").
-- The open paving of the park (x -259..-62, z -640..-283) is mapped on a 4-stud grid: a cell is taken
-- when anything standing (a ride, its fence, a bed, a shop, a lamp, a bench, a tree) is within CLEAR
-- studs of it, so every island keeps a CLEAR-wide walk round it; the gate's entry plaza and the corner
-- outside the park stay open. Each free patch of at least MIN_CELLS cells, shrunk by one cell, becomes
-- an island of the beds' bush (ArtAssets.Shrub, like the jumping star's corner thicket) as a lawn: bushes
-- on a jittered grid, cherry trees (ServerStorage.FallingBlossomCherryTree) where the island is
-- widest, benches (ParkBenchV2, facing the walk) along its edges and lamps (ParkLampV2) at its ends.
-- Model: Workspace.놀이공원정원 (Folder; one Model per island), rebuilt each run. Run last in the park
-- steps (it reads what stands there).

local SS = game:GetService("ServerStorage")
local G = 16.11
local X0, X1, Z0, Z1 = -259, -62, -640, -283
local CELL = 4
local CLEAR = 9
local MIN_CELLS = 24

local old = workspace:FindFirstChild("놀이공원정원")
if old then old:Destroy() end

local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end

local nx, nz = math.floor((X1 - X0) / CELL), math.floor((Z1 - Z0) / CELL)
local function key(i: number, j: number): number return i * 1000 + j end
local function cx(i: number): number return X0 + (i + 0.5) * CELL end
local function cz(j: number): number return Z0 + (j + 0.5) * CELL end
local taken = {}
local FLOOR = { Paving = true, Ground = true, ParkPlatform = true, ParkPlatformWestStrip = true, ParkPlatformNorth = true }
local params = OverlapParams.new()
for _, q in ipairs(workspace:GetPartBoundsInBox(CFrame.new((X0 + X1) / 2, G + 6, (Z0 + Z1) / 2), Vector3.new(X1 - X0 + 30, 11.5, Z1 - Z0 + 30), params)) do
	if q.Transparency < 1 and not FLOOR[q.Name] then
		local lo, hi = ext(q)
		if lo.Y < G + 10 and hi.Y > G + 0.3 and hi.X - lo.X < 150 then
			for i = math.max(0, math.floor((lo.X - CLEAR - X0) / CELL)), math.min(nx - 1, math.floor((hi.X + CLEAR - X0) / CELL)) do
				for j = math.max(0, math.floor((lo.Z - CLEAR - Z0) / CELL)), math.min(nz - 1, math.floor((hi.Z + CLEAR - Z0) / CELL)) do
					taken[key(i, j)] = true
				end
			end
		end
	end
end
for i = 0, nx - 1 do
	for j = 0, nz - 1 do
		local x, z = cx(i), cz(j)
		if (x > -140 and x < -80 and z > -350) or (x < -178 and z > -340) then taken[key(i, j)] = true end
	end
end
local function free(i: number, j: number): boolean
	return i >= 0 and i < nx and j >= 0 and j < nz and not taken[key(i, j)]
end

-- the patches (4-connected), then shrunk by one cell
local seen, patches = {}, {}
for i = 0, nx - 1 do
	for j = 0, nz - 1 do
		if free(i, j) and not seen[key(i, j)] then
			local list, stack = {}, { { i, j } }
			seen[key(i, j)] = true
			while #stack > 0 do
				local c = table.remove(stack)
				table.insert(list, c)
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local a, b = c[1] + d[1], c[2] + d[2]
					if free(a, b) and not seen[key(a, b)] then
						seen[key(a, b)] = true
						table.insert(stack, { a, b })
					end
				end
			end
			table.insert(patches, list)
		end
	end
end

local leafT
for _, d in ipairs(SS.ArtAssets.Shrub:GetDescendants()) do
	if d:IsA("MeshPart") and (not leafT or d.Size.Magnitude > leafT.Size.Magnitude) then leafT = d end
end
local treeT = SS:FindFirstChild("FallingBlossomCherryTree")
local furn = workspace:FindFirstChild("놀이공원길") and workspace["놀이공원길"]:FindFirstChild("Furniture")
local benchT = furn and furn:FindFirstChild("ParkBenchV2")
local lampT = furn and furn:FindFirstChild("ParkLampV2")
local rng = Random.new(1518)
local root = Instance.new("Folder")
root.Name = "놀이공원정원"
local out = {}
for n, list in ipairs(patches) do
	if #list >= MIN_CELLS then
		local inner = {}
		local set = {}
		for _, c in ipairs(list) do
			local ok = true
			for di = -1, 1 do
				for dj = -1, 1 do
					if not free(c[1] + di, c[2] + dj) then ok = false end
				end
			end
			if ok then
				table.insert(inner, c)
				set[key(c[1], c[2])] = true
			end
		end
		if #inner >= 8 then
			local m = Instance.new("Model")
			m.Name = "Island" .. n
			-- the island's middle and its long axis
			local sx, sz = 0, 0
			local lo, hi = Vector2.new(1e9, 1e9), Vector2.new(-1e9, -1e9)
			for _, c in ipairs(inner) do
				sx += cx(c[1])
				sz += cz(c[2])
				lo = lo:Min(Vector2.new(cx(c[1]), cz(c[2])))
				hi = hi:Max(Vector2.new(cx(c[1]), cz(c[2])))
			end
			local mid = Vector3.new(sx / #inner, 0, sz / #inner)
			local function inside(x: number, z: number): boolean
				return set[key(math.floor((x - X0) / CELL), math.floor((z - Z0) / CELL))] == true
			end
			-- round off the corners: a point counts only if a circle of CELL round it is inside
			local function deep(x: number, z: number, r: number): boolean
				for a = 0, 7 do
					local t = a * math.pi / 4
					if not inside(x + math.cos(t) * r, z + math.sin(t) * r) then return false end
				end
				return inside(x, z)
			end
			-- bushes
			local STEP = 4.4
			local bushes = 0
			for x = lo.X - 2, hi.X + 2, STEP do
				for z = lo.Y - 2, hi.Y + 2, STEP do
					local px, pz = x + rng:NextNumber(-1, 1), z + rng:NextNumber(-1, 1)
					if deep(px, pz, 1.2) then
						local h = leafT:Clone()
						h.Name = "Bush"
						h.Size = leafT.Size * 0.7 * rng:NextNumber(0.85, 1.15)
						h.CFrame = CFrame.new(px, G + h.Size.Y / 2 - 0.9, pz) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
						h.Anchored, h.CanCollide, h.CanTouch, h.CanQuery = true, false, false, false
						h.Parent = m
						bushes += 1
					end
				end
			end
			-- cherry trees where the island is widest, 24 apart
			local trees = {}
			if treeT then
				local cand = {}
				for _, c in ipairs(inner) do
					local x, z = cx(c[1]), cz(c[2])
					local r = 0
					while r < 30 and deep(x, z, r + 2) do r += 2 end
					if r >= 8 then table.insert(cand, { x, z, r }) end
				end
				table.sort(cand, function(a, b) return a[3] > b[3] end)
				for _, c in ipairs(cand) do
					local ok = true
					for _, t in ipairs(trees) do
						if (Vector2.new(c[1], c[2]) - t).Magnitude < 24 then ok = false end
					end
					if ok and #trees < math.max(1, math.floor(#inner / 45)) then
						table.insert(trees, Vector2.new(c[1], c[2]))
						local t = treeT:Clone()
						for _, d in ipairs(t:GetDescendants()) do
							if d:IsA("LuaSourceContainer") then d:Destroy() end
						end
						local cf, s = t:GetBoundingBox()
						local up = t:GetPivot().Y - (cf.Y - s.Y / 2) -- (the pivot over the tree's foot)
						t:PivotTo(CFrame.new(c[1], G + up - 0.3, c[2]) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0) * t:GetPivot().Rotation)
						t.Parent = m
					end
				end
			end
			-- benches facing the walk, and lamps, round the edge
			local edge = {}
			for _, c in ipairs(inner) do
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					if not set[key(c[1] + d[1], c[2] + d[2])] then
						table.insert(edge, { cx(c[1]) + d[1] * (CELL / 2 + 2.2), cz(c[2]) + d[2] * (CELL / 2 + 2.2), d })
					end
				end
			end
			local placed = {}
			local function far(x: number, z: number, gap: number): boolean
				for _, p in ipairs(placed) do
					if (Vector2.new(x, z) - p).Magnitude < gap then return false end
				end
				return true
			end
			local benches, lamps = 0, 0
			table.sort(edge, function(a, b) return (a[1] - mid.X) ^ 2 + (a[2] - mid.Z) ^ 2 < (b[1] - mid.X) ^ 2 + (b[2] - mid.Z) ^ 2 end)
			for _, e in ipairs(edge) do -- (benches first, at the long sides' middles: closest to the middle)
				if benchT and benches < math.max(2, math.floor(#inner / 40)) and far(e[1], e[2], 20) then
					local dir = Vector3.new(e[3][1], 0, e[3][2])
					local b = benchT:Clone()
					b:PivotTo(CFrame.fromMatrix(Vector3.new(e[1], G, e[2]), dir, Vector3.yAxis))
					b.Parent = m
					table.insert(placed, Vector2.new(e[1], e[2]))
					benches += 1
				end
			end
			for k = #edge, 1, -1 do -- (lamps at the ends: furthest from the middle)
				local e = edge[k]
				if lampT and lamps < math.max(2, math.floor(#inner / 50)) and far(e[1], e[2], 26) then
					local l = lampT:Clone()
					l:PivotTo(CFrame.new(e[1] - e[3][1] * 1.2, G, e[2] - e[3][2] * 1.2))
					l.Parent = m
					table.insert(placed, Vector2.new(e[1], e[2]))
					lamps += 1
				end
			end
			m.Parent = root
			table.insert(out, ("island %d: %d cells, %d bushes, %d trees, %d benches, %d lamps, middle (%.0f, %.0f)"):format(n, #inner, bushes, #trees, benches, lamps, mid.X, mid.Z))
		end
	end
end
root.Parent = workspace
print("[park_garden_1116] " .. table.concat(out, "; "))
return table.concat(out, "\n")
