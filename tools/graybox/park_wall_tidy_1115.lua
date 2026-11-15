--!nocheck
-- 놀이공원 남서쪽 벽면 정리 (D-1450, user 2026-11-15, a screenshot of the park's south wall west of
-- the gate, over the sea road's tunnel: "벽면 깔끔하게 정리").
--   * ParkRaise.ParkPlatformWestStrip (park_corner_beach_1115, D-1418) reached z -277, 1.74 past
--     the brick wall's plinth (its face z -278.74): a concrete ledge ran along under the wall. Its
--     south face now stops flush with the plinth, so the stone below and the brick above are one face.
--   * The plaza's west parapet (ParkRaise.ParkPlazaParapet at x -152.5) stopped at z -272.8, a notch
--     short of the wall's corner pillar: it now runs on to the plinth's face.
-- Faces are read from the wall pieces themselves (AmusementParkGate.ParkWallPlinth on the south wall,
-- z ≈ -279.5). LAST chain step (after park_corner_beach_1115, which sets the strip each run).
-- Idempotent.

local H = workspace:WaitForChild("Hongdae_Layout")
local raise = H:WaitForChild("ParkRaise")
local gate = H:WaitForChild("AmusementParkGate")

local function aabb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
-- set a part's world extent along Z (a part turned by a multiple of 90° about Y)
local function setZ(p: BasePart, a: number, b: number)
	local cf = p.CFrame
	local alongZ = math.abs(cf.LookVector.Z) > 0.7
	local len = b - a
	if alongZ then p.Size = Vector3.new(p.Size.X, p.Size.Y, len) else p.Size = Vector3.new(len, p.Size.Y, p.Size.Z) end
	p.CFrame = (cf - cf.Position) + Vector3.new(cf.X, cf.Y, (a + b) / 2)
end

-- the south wall's plinth face (the wall west of the gate)
local face
for _, c in ipairs(gate:GetChildren()) do
	if c:IsA("BasePart") and c.Name == "ParkWallPlinth" and math.abs(c.Position.Z + 279.5) < 1.5 and c.Position.X < -140 then
		local _, hi = aabb(c)
		face = if face then math.max(face, hi.Z) else hi.Z
	end
end
assert(face, "no south wall plinth west of the gate")

local log = {}
local strip = raise:FindFirstChild("ParkPlatformWestStrip") :: BasePart?
if strip then
	local lo, hi = aabb(strip)
	if math.abs(hi.Z - face) > 0.02 then
		setZ(strip, lo.Z, face)
		table.insert(log, ("strip z %.2f → %.2f"):format(hi.Z, face))
	end
end
for _, p in ipairs(raise:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "ParkPlazaParapet" then
		local lo, hi = aabb(p)
		-- the west side parapet (long along Z, at the plaza's west edge)
		if hi.Z - lo.Z > 20 and math.abs(lo.X + 152.5) < 0.6 and lo.Z > face + 0.02 then
			setZ(p, face, hi.Z)
			table.insert(log, ("west parapet z %.2f → %.2f"):format(lo.Z, face))
		end
	end
end
print("[park_wall_tidy_1115] " .. (if #log > 0 then table.concat(log, "; ") else "nothing to do"))
return #log
