-- (D-1418, user 2026-11-15, an aerial screenshot with a red line and two circles: "놀이공원 부지 너무
-- 넓혀서 해변 좁아진 것 같아서 수정. 빨간 선대로 놀이공원 벽 세우고 해변(노란색)이랑 도로(녹색) 이어서
-- 구현.") The park's south-west corner that D-1393 (park_expand_1113) took from the beach goes
-- back to the beach: the corner R = x -298.5..-182, z -335.8..-277 (the red line, read through
-- the user's Studio camera: along the south edge of the user's hedge "화단" at z -336.6 from the
-- sea to x -187, then south to the park's south wall; x -182 = the promenade's east edge).
--   1. ParkRaise.ParkPlatformWest no longer covers R (cut to z -335.8, plus a strip x -182..-148
--      down to z -277 east of R).
--   2. The beach pieces D-1393 cut at z -277 run on north to the new wall again: the beach sand,
--      the shore slope, the promenade (the walk along the beach, the green circle) and the steps
--      between them; sea water (terrain) fills R west of the sand again.
--   3. Walls: the park's west wall (x -297.45) now ends at the new corner (z -335.8); the south
--      wall (z -279.5) starts at x -182; new walls along z -335.8 (the sea to x -182) and along
--      x -182 (z -335.8 to the south wall), built from the same pieces, with pillars at the corners.
-- Idempotent: every size / place is set from the targets. Chain step: after park_expand_1113.

local H = workspace:WaitForChild("Hongdae_Layout")
local GB = workspace:WaitForChild("Graybox_MainSocial")
local gate = H:WaitForChild("AmusementParkGate")
local raise = H:WaitForChild("ParkRaise")

local WEST_X = -297.45 -- the park's west wall (centre)
local SOUTH_Z = -279.5 -- the park's south wall (centre)
local NEW_Z = -335.8 -- the new wall along the hedge
local NEW_X = -182 -- the new wall down to the south wall
local R_X0, R_X1, R_Z0, R_Z1 = -298.5, NEW_X, NEW_Z, -277

local function aabb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
-- a part turned by a multiple of 90° about Y: set its world extent along Z (north end a, south end b)
local function setZ(p: BasePart, a: number, b: number)
	local cf = p.CFrame
	local alongZ = math.abs(cf.LookVector.Z) > 0.7 -- (its own Z runs along the world's Z)
	local len = b - a
	if alongZ then p.Size = Vector3.new(p.Size.X, p.Size.Y, len) else p.Size = Vector3.new(len, p.Size.Y, p.Size.Z) end
	p.CFrame = (cf - cf.Position) + Vector3.new(cf.X, cf.Y, (a + b) / 2)
end
local function setX(p: BasePart, a: number, b: number)
	local cf = p.CFrame
	local alongX = math.abs(cf.RightVector.X) > 0.7
	local len = b - a
	if alongX then p.Size = Vector3.new(len, p.Size.Y, p.Size.Z) else p.Size = Vector3.new(p.Size.X, p.Size.Y, len) end
	p.CFrame = (cf - cf.Position) + Vector3.new((a + b) / 2, cf.Y, cf.Z)
end

------------------------------------------------------------------ 1. the park platform
local plat = raise:FindFirstChild("ParkPlatformWest") :: BasePart?
if plat then
	local lo, hi = aabb(plat)
	setZ(plat, lo.Z, NEW_Z) -- (north part: up to the new wall)
	local strip = raise:FindFirstChild("ParkPlatformWestStrip") :: BasePart?
	if not strip then
		strip = plat:Clone()
		strip.Name = "ParkPlatformWestStrip"
		strip.Parent = raise
	end
	setZ(strip :: BasePart, NEW_Z, R_Z1)
	setX(strip :: BasePart, NEW_X, hi.X)
end

------------------------------------------------------------------ 2. the beach back to the wall
local beachZone = GB:FindFirstChild("04_Beach_Aquarium")
local longOnes = {}
if beachZone then
	for _, n in ipairs({ "Beach", "ShoreSlope" }) do
		local p = beachZone:FindFirstChild(n)
		if p and p:IsA("BasePart") then table.insert(longOnes, p) end
	end
end
for _, c in ipairs(H:GetChildren()) do
	if c:IsA("BasePart") then
		local lo, hi = aabb(c)
		-- the promenade along the beach (x -198..-182) and the steps / edge between it and the sand
		if (c.Name == "Promenade" and lo.X > -199 and hi.X < -181 and hi.Z - lo.Z > 100)
			or ((c.Name == "BeachStep" or c.Name == "BeachStepEdge") and lo.X > -207 and hi.X < -197 and math.abs(lo.Z - R_Z1) < 0.6) then
			table.insert(longOnes, c)
		end
	end
end
for _, p in ipairs(longOnes) do
	local lo, hi = aabb(p)
	if lo.Z > NEW_Z + 0.1 and lo.Z < R_Z1 + 1 then setZ(p, NEW_Z, hi.Z) end
end
-- the sea water (terrain) west of the sand, as south of here
workspace.Terrain:FillBlock(CFrame.new((R_X0 - 0.5 + -266) / 2, -8, (R_Z0 + R_Z1) / 2), Vector3.new(-266 - (R_X0 - 0.5), 8, R_Z1 - R_Z0), Enum.Material.Water)

------------------------------------------------------------------ 3. the walls
local WALL = { ParkWall = true, ParkWallCap = true, ParkWallCornice = true, ParkWallPlinth = true, ParkWallTop = true }
local westPieces, southPieces = {}, {}
for _, c in ipairs(gate:GetChildren()) do
	if c:IsA("BasePart") and WALL[c.Name] then
		local lo, hi = aabb(c)
		if math.abs(c.Position.X - WEST_X) < 1.2 and hi.Z > NEW_Z - 1 then table.insert(westPieces, c) end
		if math.abs(c.Position.Z - SOUTH_Z) < 1.2 and lo.X < NEW_X + 1 then table.insert(southPieces, c) end
	end
end
local made = gate:FindFirstChild("CornerBeachWalls")
if made then made:Destroy() end
made = Instance.new("Model")
made.Name = "CornerBeachWalls"
made.Parent = gate
for _, p in ipairs(westPieces) do
	local lo = aabb(p)
	-- the new wall down x -182 (from the new corner to the south wall), same pieces
	local c = p:Clone()
	c.Parent = made
	c.CFrame = (p.CFrame - p.CFrame.Position) + Vector3.new(NEW_X + (p.Position.X - WEST_X), p.Position.Y, 0)
	setZ(c, NEW_Z, SOUTH_Z)
	setZ(p, lo.Z, NEW_Z) -- the west wall ends at the new corner
end
for _, p in ipairs(southPieces) do
	local _, hi = aabb(p)
	-- the new wall along z -335.8 (from the sea to x -182), same pieces
	local c = p:Clone()
	c.Parent = made
	c.CFrame = (p.CFrame - p.CFrame.Position) + Vector3.new(0, p.Position.Y, NEW_Z + (p.Position.Z - SOUTH_Z))
	setX(c, WEST_X, NEW_X)
	setX(p, NEW_X, hi.X) -- the south wall starts at x -182
end
-- pillars: the old south-west corner pillar (and its base) moves to the new west corner (z NEW_Z);
-- copies of it stand at the two corners on x -182
local cornerParts = {}
for _, c in ipairs(gate:GetChildren()) do
	if c:IsA("BasePart") and string.sub(c.Name, 1, 10) == "ParkPillar" and math.abs(c.Position.X + 294.7) < 1.5
		and (math.abs(c.Position.Z - SOUTH_Z) < 3.5 or math.abs(c.Position.Z - NEW_Z) < 3.5) then
		table.insert(cornerParts, c)
	end
end
for _, src in ipairs(cornerParts) do
	local dz = if math.abs(src.Position.Z - SOUTH_Z) < 3.5 then src.Position.Z - SOUTH_Z else src.Position.Z - NEW_Z
	local dx = src.Position.X - (-294.7)
	for _, at in ipairs({ { NEW_X + dx, NEW_Z + dz }, { NEW_X + dx, SOUTH_Z + dz } }) do
		local c = src:Clone()
		c.CFrame = (src.CFrame - src.CFrame.Position) + Vector3.new(at[1], src.Position.Y, at[2])
		c.Parent = made
	end
	src.CFrame = (src.CFrame - src.CFrame.Position) + Vector3.new(src.Position.X, src.Position.Y, NEW_Z + dz)
end
print(("[park_corner_beach_1115] walls: west %d, south %d; beach pieces %d"):format(#westPieces, #southPieces, #longOnes))
return #longOnes
