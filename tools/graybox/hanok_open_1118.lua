--!nocheck
-- 한옥 마을 안쪽 열기 (D-1733, user 2026-11-18: "한옥 마을 돌담벽을 선으로 한옥마을 안쪽에 못 가게 막아 놓은 부분
-- 풀어 줘. 바깥 도로는 더 못 가는 부분 유지."). The invisible map boundary (Hongdae_Layout.MapBoundary,
-- build_hongdae_layout) ran x 277 (z -50..387) and z 387 (x -415..277) right through the hanok village,
-- so its houses and the pond garden were out of bounds. This takes those two walls away and puts the
-- line round the village's outer stone walls instead: (277, -50) → (277, 52) → (560, 52) → (560, 665)
-- → (52, 665) → (52, 387) → (-415, 387). build_hongdae_layout makes the same line on a rebuild; this
-- only fixes the place as it is (no chain run needed). Idempotent.

local L = workspace:FindFirstChild("Hongdae_Layout")
local B = L and L:FindFirstChild("MapBoundary")
assert(B, "Hongdae_Layout.MapBoundary missing")

local function seg(w: BasePart): (Vector3, Vector3)
	local half = w.CFrame.LookVector * (w.Size.Z / 2 - 1)
	return w.Position - half, w.Position + half
end
local function near(a: Vector3, x: number, z: number): boolean
	return math.abs(a.X - x) < 3 and math.abs(a.Z - z) < 3
end
local function isSeg(w: BasePart, x0: number, z0: number, x1: number, z1: number): boolean
	local a, b = seg(w)
	return (near(a, x0, z0) and near(b, x1, z1)) or (near(a, x1, z1) and near(b, x0, z0))
end

local removed = 0
for _, w in ipairs(B:GetChildren()) do
	if w:IsA("BasePart") and w.Name == "BoundaryWall" and (isSeg(w, 277, -50, 277, 387) or isSeg(w, 277, 387, -415, 387)) then
		w:Destroy()
		removed += 1
	end
end

local NEW = { { 277, -50 }, { 277, 52 }, { 560, 52 }, { 560, 665 }, { 52, 665 }, { 52, 387 }, { -415, 387 } }
local added = 0
for i = 1, #NEW - 1 do
	local a, b = NEW[i], NEW[i + 1]
	local exists = false
	for _, w in ipairs(B:GetChildren()) do
		if w:IsA("BasePart") and w.Name == "BoundaryWall" and isSeg(w, a[1], a[2], b[1], b[2]) then exists = true end
	end
	if not exists then
		local pa, pb = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
		local mid = (pa + pb) / 2 + Vector3.new(0, 55, 0)
		local w = Instance.new("Part")
		w.Name = "BoundaryWall"
		w.Size = Vector3.new(2, 150, (pb - pa).Magnitude + 2)
		w.CFrame = CFrame.lookAt(mid, mid + (pb - pa))
		w.Anchored = true
		w.Transparency = 1
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Locked = true
		w.Parent = B
		added += 1
	end
end
local msg = string.format("[hanok_open_1118] boundary walls removed %d, added %d", removed, added)
print(msg)
return msg
