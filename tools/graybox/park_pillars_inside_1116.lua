--!nocheck
-- 놀이공원 모서리 벽 + 기둥을 회색 블록 안쪽으로 (D-1487 / D-1489, user 2026-11-16 + beach-side
-- screenshots: "아래 회색 블록보다 튀어나온 놀이공원 벽 안쪽으로 넣어", "이만큼 나온 것도 안으로 넣어").
-- park_corner_beach_1115 (D-1418) built CornerBeachWalls over the park platform's edge: measured by
-- rays, the platform ends at z -335.85 under the south run (z -335.8) and at x -182.00 east of the
-- x -182 run, so their plinths stood 0.8 past the grey block, and three corner pillars 2.5–3.
--   * the south run (z ≈ -335.8, x -297..-182) moves 0.85 north, the x -182 run 0.8 east: plinth faces
--     on the block's edge;
--   * the pillar groups (ParkPillar + base, drum, cornice, caps, dome, spire: ParkPillar* within 4.5)
--     at (-294.65, -335.8) and (-181.95, -335.8) move 3.1 north, the one at (-181.95, -279.5) 3.05 east
--     and 2.3 north: whole feet on the platform. The other pillars and walls stand on it already.
-- Run after park_corner_beach_1115. Idempotent: pieces not found at their old places are left alone.

local gate = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("AmusementParkGate")
assert(gate, "no AmusementParkGate")
local done = {}

local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end

-- 1. the two wall runs
local cw = gate:FindFirstChild("CornerBeachWalls")
if cw then
	local ns, nx = 0, 0
	for _, p in ipairs(cw:GetChildren()) do
		if p:IsA("BasePart") and p.Name:sub(1, 8) == "ParkWall" then
			local lo, hi = ext(p)
			if math.abs((lo.Z + hi.Z) / 2 + 335.8) < 0.3 and hi.X - lo.X > 50 then
				p.CFrame += Vector3.new(0, 0, -0.85)
				ns += 1
			elseif math.abs((lo.X + hi.X) / 2 + 182) < 0.3 and hi.Z - lo.Z > 50 then
				p.CFrame += Vector3.new(0.8, 0, 0)
				nx += 1
			end
		end
	end
	table.insert(done, ("walls south %d, x -182 %d"):format(ns, nx))
end

-- 2. the three corner pillars
local MOVES = {
	{ Vector3.new(-294.65, 0, -335.8), Vector3.new(0, 0, -3.1) },
	{ Vector3.new(-181.95, 0, -335.8), Vector3.new(0, 0, -3.1) },
	{ Vector3.new(-181.95, 0, -279.5), Vector3.new(3.05, 0, -2.3) },
}
for _, m in ipairs(MOVES) do
	local pillar
	for _, q in ipairs(gate:GetDescendants()) do
		if q:IsA("BasePart") and q.Name == "ParkPillar" and Vector2.new(q.Position.X - m[1].X, q.Position.Z - m[1].Z).Magnitude < 0.6 then
			pillar = q
		end
	end
	if pillar then
		local at = pillar.Position
		for _, q in ipairs(pillar.Parent:GetChildren()) do
			if q:IsA("BasePart") and q.Name:sub(1, 10) == "ParkPillar"
				and Vector2.new(q.Position.X - at.X, q.Position.Z - at.Z).Magnitude < 4.5 then
				q.CFrame += m[2]
			end
		end
		table.insert(done, ("pillar (%.0f, %.0f)"):format(m[1].X, m[1].Z))
	end
end
-- 3. (D-1508, user: "밑에 어데 갓노") the corner pillars park_corner_beach_1115 copied had no
-- ParkPillarBase and stood 3 over the ground: each pillar without one gets a copy of another pillar's
-- base, at the same offset under it
local tmplBase, tmplPillar
for _, d in ipairs(gate:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "ParkPillarBase" then tmplBase = d break end
end
if tmplBase then
	for _, d in ipairs(gate:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "ParkPillar" and Vector2.new(d.Position.X - tmplBase.Position.X, d.Position.Z - tmplBase.Position.Z).Magnitude < 1 then tmplPillar = d end
	end
end
if tmplBase and tmplPillar then
	local rel = tmplPillar.CFrame:ToObjectSpace(tmplBase.CFrame)
	local bases = {}
	for _, d in ipairs(gate:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "ParkPillarBase" then table.insert(bases, d) end
	end
	for _, p in ipairs(gate:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "ParkPillar" then
			local has = false
			for _, b in ipairs(bases) do
				if Vector2.new(b.Position.X - p.Position.X, b.Position.Z - p.Position.Z).Magnitude < 1 then has = true end
			end
			if not has then
				local b = tmplBase:Clone()
				b.CFrame = p.CFrame * rel
				b.Parent = p.Parent
				table.insert(done, ("base under (%.0f, %.0f)"):format(p.Position.X, p.Position.Z))
			end
		end
	end
end
print("[park_pillars_inside_1116] " .. table.concat(done, "; "))
return #done
