--!nocheck
-- 한옥 마을 닫기 (D-1916, user 2026-11-21: "한옥마을은 그냥 광화문만 둬야겠다. 한옥마을 만든 거 따로 묶어서 백업해 놓고 삭제.").
-- The village (HanokVillage / HanokGarden / HanokCafe / HanokRoofs / HanokStoneWalls / lot walls and blocks /
-- cherry trees, ServerStorage.ParkedHanokBlocks / HanokDevSrc) was moved by hand into
-- ServerStorage.Backup_HanokVillage_1121 (tags kept in the BackupTags attribute, then removed) and the terrain
-- ponds emptied. This puts the invisible map boundary back behind the 광화문 palace walls: it takes away the
-- D-1733 walls round the village (hanok_open_1118) and adds the line along the palace walls, the same line
-- build_hongdae_layout makes on a rebuild. Only fixes the place as it is (no chain run needed). Idempotent.

local L = workspace:FindFirstChild("Hongdae_Layout")
local B = L and L:FindFirstChild("MapBoundary")
assert(B, "Hongdae_Layout.MapBoundary missing")

local function seg(w)
	local half = w.CFrame.LookVector * (w.Size.Z / 2 - 1)
	return w.Position - half, w.Position + half
end
local function near(a, x, z)
	return math.abs(a.X - x) < 3 and math.abs(a.Z - z) < 3
end
local function isSeg(w, x0, z0, x1, z1)
	local a, b = seg(w)
	return (near(a, x0, z0) and near(b, x1, z1)) or (near(a, x1, z1) and near(b, x0, z0))
end

-- D-1733 line (and the old pre-D-1733 x 277 / z 387 pair, in case it is still there)
local OLD = {
	{ 277, -50, 277, 52 }, { 277, 52, 560, 52 }, { 560, 52, 560, 665 }, { 560, 665, 52, 665 }, { 52, 665, 52, 387 },
	{ 277, -50, 277, 387 }, { 277, 387, -415, 387 },
}
local removed = 0
for _, w in ipairs(B:GetChildren()) do
	if w:IsA("BasePart") and w.Name == "BoundaryWall" then
		for _, o in ipairs(OLD) do
			if isSeg(w, o[1], o[2], o[3], o[4]) then
				w:Destroy()
				removed += 1
				break
			end
		end
	end
end

local NEW = {
	{ 277, -50 }, { 290, 50 }, { 263, 74 }, { 244, 109 }, { 223, 141 }, { 138, 227 }, { 107, 254 },
	{ 82, 279 }, { 62, 306 }, { 52, 335 }, { 52, 387 }, { -415, 387 },
}
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
local msg = string.format("[hanok_close_1121] boundary walls removed %d, added %d", removed, added)
print(msg)
return msg
