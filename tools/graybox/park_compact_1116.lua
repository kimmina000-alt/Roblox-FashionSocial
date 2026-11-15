--!nocheck
-- 놀이공원 서쪽 줄 좁히기 (D-1481, user 2026-11-16, an aerial shot with arrows: "점핑스타 북쪽 공간 줄이기, 상점 북쪽
-- 공간 줄이기, 미니 바이킹 북쪽 공간 줄이기 … 북쪽에 있는 기구들 위치 남쪽으로 이동 … 각 기구들 사이 거리는 10스터드",
-- and "위쪽에 03_JumperBoat 위치" circled under the bumper car hall).
-- The west column from the gate northwards, each 10 studs (a 5-wide flower bed in the middle, park_paths_1116)
-- from the one before it:
--   jumping star (fence north edge z -380.5, stays)
--   → the two snack bars (ParkBlockout.Snack_Bar south edge z -390.5, Workspace.Snack_Bar 3.4 behind it)
--   → 미니바이킹 (the user's model, its loose yellow FencePanels with it: south edge z -440.3, 52.3 south)
--   → the peace train track (park_peace_train_1116: z -511.7 .. -723.4)
--   → 03_JumperBoat (ParkBlockout, middle x -255, z -744.5: north edge 10 from the bumper hall's canopy posts)
-- World-space attributes in the moved models (the viking's Exit, the gate hinge, the diagonal panel's
-- OrigCFrame) move with them. park_vikings_1115 / park_ride_gates_1115 build at the new place
-- themselves (their MINI_DZ / DZ), so after a chain run this finds nothing to move.
-- Absolute targets: a second run moves nothing. Edit mode; after park_layout_1111 (it makes the
-- blockouts), the viking scripts and park_ride_gates_1115; before park_paths_1116.

local STAR_N = -380.5
local SNACK1_S = STAR_N - 10 -- (-390.5)
local SNACK_GAP = 3.4 -- (the two bars as they stood)
local MINI_S = -440.3 -- (10 north of the second bar's north edge, -430.3)
local JUMPER = Vector3.new(-255, 0, -744.5)

local moved = {}

local function aabb(inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	local list = if inst:IsA("BasePart") then { inst } else inst:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") then
			local cf, s = p.CFrame, p.Size
			local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
			lo = lo:Min(p.Position - e / 2)
			hi = hi:Max(p.Position + e / 2)
		end
	end
	return lo, hi
end

local function shiftAttrs(root: Instance, d: Vector3)
	for _, x in ipairs({ root, unpack(root:GetDescendants()) }) do
		for k, v in pairs(x:GetAttributes()) do
			-- (world places only: offsets such as Seat1 or Inward stay small)
			if typeof(v) == "Vector3" and v.Magnitude > 150 then x:SetAttribute(k, v + d)
			elseif typeof(v) == "CFrame" and v.Position.Magnitude > 150 then x:SetAttribute(k, v + d) end
		end
	end
end

local function shift(inst: Instance, d: Vector3, label: string)
	if d.Magnitude < 0.01 then return end
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + d)
	elseif inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame + d
	else
		for _, c in ipairs(inst:GetChildren()) do
			if c:IsA("Model") then c:PivotTo(c:GetPivot() + d) elseif c:IsA("BasePart") then c.CFrame = c.CFrame + d end
		end
	end
	shiftAttrs(inst, d)
	table.insert(moved, ("%s by %.1f"):format(label, d.Z))
end

local bo = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ParkBlockout")

-- the snack bars (south edge = the largest z)
local snack1 = bo and bo:FindFirstChild("Snack_Bar")
local snack2
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "Snack_Bar" and c:IsA("Model") and c:GetPivot().Position.X < -200 then snack2 = c end
end
local depth1 = 0
if snack1 then
	local lo, hi = aabb(snack1)
	depth1 = hi.Z - lo.Z
	shift(snack1, Vector3.new(0, 0, SNACK1_S - hi.Z), "snack bar 1")
end
if snack2 then
	local _, hi = aabb(snack2)
	shift(snack2, Vector3.new(0, 0, SNACK1_S - depth1 - SNACK_GAP - hi.Z), "snack bar 2")
end

-- 미니바이킹 and the user's loose yellow panels by it
local mini = workspace:FindFirstChild("미니바이킹")
if mini then
	local lo, hi = aabb(mini)
	local d = Vector3.new(0, 0, MINI_S - hi.Z)
	if d.Magnitude > 0.01 then
		for _, p in ipairs(workspace:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "FencePanel" and p.Position.X > lo.X - 3 and p.Position.X < hi.X + 3
				and p.Position.Z > lo.Z - 3 and p.Position.Z < hi.Z + 3 then
				p.CFrame = p.CFrame + d
			end
		end
		shift(mini, d, "미니바이킹")
	end
end

-- 03_JumperBoat
local jumper = bo and bo:FindFirstChild("03_JumperBoat")
if jumper then
	local lo, hi = aabb(jumper)
	local c = (lo + hi) / 2
	shift(jumper, Vector3.new(JUMPER.X - c.X, 0, JUMPER.Z - c.Z), "03_JumperBoat")
end

print("[park_compact_1116] " .. (if #moved > 0 then table.concat(moved, "; ") else "nothing to move"))
return #moved
