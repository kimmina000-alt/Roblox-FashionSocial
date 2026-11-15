--!nocheck
-- 놀이공원 벽 모서리 기둥을 회색 블록 안쪽으로 (D-1487, user 2026-11-16 + a beach-side screenshot with
-- the corner pillars boxed: "아래 회색 블록보다 튀어나온 놀이공원 벽 안쪽으로 넣어").
-- park_corner_beach_1115 (D-1418) put three corner pillars of Hongdae_Layout.AmusementParkGate half
-- over the beach: (-294.7, -335.8), (-182, -335.8) and (-182, -279.5) stuck 2.5–3 past the park
-- platform's edge. Each pillar (ParkPillar + base, drum, cornice, caps, dome, spire: the ParkPillar*
-- parts within 4.5 of it) moves in by MOVES, the shortest shift that puts its whole foot on the
-- platform (measured by rays). The other pillars stand on the platform already.
-- Run after park_corner_beach_1115. Idempotent: a pillar not found at its old place is left alone.

local MOVES = {
	{ Vector3.new(-294.7, 0, -335.8), Vector3.new(0, 0, -3) },
	{ Vector3.new(-182, 0, -335.8), Vector3.new(0, 0, -3) },
	{ Vector3.new(-182, 0, -279.5), Vector3.new(3, 0, -3) },
}
local gate = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("AmusementParkGate")
assert(gate, "no AmusementParkGate")

local done = {}
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
		table.insert(done, ("(%.0f, %.0f)"):format(m[1].X, m[1].Z))
	end
end
print("[park_pillars_inside_1116] moved " .. (if #done > 0 then table.concat(done, ", ") else "nothing (already inside)"))
return #done
