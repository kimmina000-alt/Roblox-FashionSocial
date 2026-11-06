--!nocheck
-- Club: the north VIP balcony shorter, buckets on the bar shelves (D-954,
-- user 2026-11-07), run in Edit mode LAST in the layout chain (after
-- club_locker_1103). World coordinates; running it again gives the same result.
--   (2026-11-07 (3): dividers, 2 × tier 2 / 2 × tier 3 on the bottom row,
--   bottles back on the second row, tier 3 at 1.5×, no VIP letters: see 2.)
--   (2026-11-07 (2): the south balcony too, the wall edge lights cut, the
--   buckets face the room, no bottles on the bucket rows.)
--   1. "vip zone 원통형 전광판쪽에 있는 공간 삭제. 빨간선까지만 구현하고 오른쪽에
--      있는 것들 삭제. 빈 공간으로 두기." The north VIP balcony (x 158..191, the
--      side of the LED pillar at x 171) ended at z -152 right in front of the
--      pillar; it ends at z -181.5 now (the user's red line, between the VIP
--      booths at z -197.4 and -165.7): the booth at -165.7 (sofas, table, sign,
--      crown) and the end of the balcony go, the floor, rails, neon and the VIP
--      region box stop at -181.5, the end rail moves there. Open air to the pillar.
--   2. "클럽 속 바 선반 아래 두 칸은 버켓 진열해 놓기. 중간에 VIP 버켓 위치. vip
--      버켓 사이즈 크니까 중앙 선반 지워서 한 칸으로 만들어. 양쪽에 3단계 버켓, 2단계
--      버켓, 1단계 버켓 진열." The bar's back shelves (x 69.5..72.5, z -200..-158):
--      the two lowest rows (on the shelves at y -15.7 and -9.7) lose their
--      bottles and are cut in three bays of 14; the middle bay loses the y -9.7
--      shelf (one tall bay) and holds the VIP ice box; the side bays hold the
--      tier 3, tier 2 and tier 1 buckets in both rows, tier 3 next to the VIP
--      bay. The buckets are built by the game's DrinkBucket (as on the tables),
--      kept still (anchored, no collisions), fronts to the room (+X).
local G = workspace:FindFirstChild("Graybox_MainSocial")
local club = G and G:FindFirstChild("02_Club")
assert(club, "run the layout chain first")
local log = {}

------------------------------------------------------------------
-- 1. both VIP balconies end at z -181.5 (the partitions' line)
------------------------------------------------------------------
-- (user 2026-11-07 (2): "반대쪽 vip 발코니도 똑같이 비워 / vip 발코니 없앤 부분은
-- 조명선 지워": the south balcony (x 66.5..89, LED pillar x 82.5) the same way, and
-- the floor edge light strips along the walls (VIP_Partitions.VIP_FloorEdgeLight)
-- stop at the cut too)
local CUT = -181.5
local SIDES = {
	{ name = "north", x0 = 158, x1 = 191, endRail = "VIP_Rail_NE", endX = 176.2 },
	{ name = "south", x0 = 66, x1 = 89.5, endRail = "VIP_Rail_SE", endX = 77.5 },
}
-- never: the pillar, the walls and the hall's own boxes (zones, interior)
local function protected(name: string): boolean
	return name == "LEDPillar" or name:find("^Wall") ~= nil or name:find("^ClubZone") ~= nil or name == "ClubInterior"
		or name == "Ceiling" or name:find("^Laser") ~= nil or name:find("^Moving") ~= nil or name:find("^Wash") ~= nil
		or name == "VIP_Partitions" or name == "BarBucketDisplay" or name == "BarShelfBottles"
end
local function zExtent(p: BasePart): (number, number)
	local c, h = p.CFrame, p.Size / 2
	local ez = math.abs(c.XVector.Z) * h.X + math.abs(c.YVector.Z) * h.Y + math.abs(c.ZVector.Z) * h.Z
	return p.Position.Z - ez, p.Position.Z + ez
end
-- a part that runs on past the cut stops at it (the local axis along world Z)
local function trimAt(d: BasePart): boolean
	local z0, z1 = zExtent(d)
	if not (z0 < CUT and z1 > CUT + 0.01) then return false end
	local c = d.CFrame
	local axes = { { v = c.XVector, i = 1 }, { v = c.YVector, i = 2 }, { v = c.ZVector, i = 3 } }
	table.sort(axes, function(a, b) return math.abs(a.v.Z) > math.abs(b.v.Z) end)
	local len, s = CUT - z0, d.Size
	d.Size = if axes[1].i == 1 then Vector3.new(len, s.Y, s.Z) elseif axes[1].i == 2 then Vector3.new(s.X, len, s.Z) else Vector3.new(s.X, s.Y, len)
	d.CFrame = c.Rotation + Vector3.new(c.X, c.Y, (z0 + CUT) / 2)
	return true
end
local TRIM = { VIP_Floor_N = true, VIP_Floor_S = true, VIP_Rail_N = true, VIP_Rail_S = true, VIP_RailBlock = true,
	VIP_RailNeon_N = true, VIP_RailNeon_S = true, VIP_RailNeonLow = true, VIP_Region_N = true, VIP_Region_S = true }
for _, side in ipairs(SIDES) do
	local function inSide(pos: Vector3): boolean
		return pos.X > side.x0 and pos.X < side.x1 and pos.Y > 17 and pos.Y < 50
	end
	-- the end rail (and its glass block) at z -152.2 move to the new end
	local endParts = {}
	for _, d in ipairs(club:GetChildren()) do
		if d:IsA("BasePart") and inSide(d.Position) and (d.Name == side.endRail or (d.Name == "VIP_RailBlock" and math.abs(d.Position.X - side.endX) < 1)) then
			local z0, z1 = zExtent(d)
			if z1 - z0 < 2 then table.insert(endParts, d) end -- (the end rails run along X: thin in Z)
		end
	end
	local removed = 0
	for _, d in ipairs(club:GetChildren()) do
		local pos = if d:IsA("BasePart") then d.Position elseif d:IsA("Model") then d:GetPivot().Position else nil
		if pos and not protected(d.Name) and not table.find(endParts, d) and inSide(pos) and pos.Z > CUT and pos.Z < -140 then
			d:Destroy()
			removed += 1
		end
	end
	for _, d in ipairs(endParts) do
		local z0, z1 = zExtent(d)
		d.Position = Vector3.new(d.Position.X, d.Position.Y, CUT - (z1 - z0) / 2)
	end
	local trimmed = 0
	for _, d in ipairs(club:GetChildren()) do
		if d:IsA("BasePart") and TRIM[d.Name] and not table.find(endParts, d) and inSide(d.Position) and trimAt(d) then trimmed += 1 end
	end
	-- the floor edge light strip along the wall
	local parts = club:FindFirstChild("VIP_Partitions")
	if parts then
		for _, d in ipairs(parts:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "VIP_FloorEdgeLight" and inSide(d.Position) and trimAt(d) then trimmed += 1 end
		end
	end
	table.insert(log, string.format("VIP %s balcony: %d removed, %d cut at z %.1f, end rail %d", side.name, removed, trimmed, CUT, #endParts))
end

------------------------------------------------------------------
-- 2. the bar's back shelves: VIP bay, bucket row, dividers
------------------------------------------------------------------
-- (user 2026-11-07 (3), photo with red lines: "빨간선 그려진 것처럼 선반 세로 칸도
-- 만들어 줘 / 제일 아래 칸, 왼쪽에는 2단계 버켓만 두 개 오른쪽에는 3단계 버켓만 두
-- 개 진열 / 아래에서 두 번째 칸은 음료수 병 진열. / 3단계 버켓 1.5배 키우기 /
-- VIP버켓 위에 VIP 글자 삭제") Seen from the bar counter (+X looking -X) the left
-- is +Z: bottom row left bay (z -172..-158) two tier-2 buckets, right bay
-- (z -200..-186) two tier-3 buckets at 1.5× their table size (0.9 × 1.5; on the
-- round tables, 4.4 across, they stay 0.9); the second row has the club bottles
-- again (BarShelfService); the middle bay stays one tall bay with the VIP ice
-- box, its VIP letters off. Vertical boards: at both ends from the bottom board
-- up to the light rail, between the bays from the bottom board to the y -3.7
-- board.
local Z0, Z1 = -200, -158 -- the shelves' run
local BAY = (Z1 - Z0) / 3 -- 14
local MID0, MID1 = Z0 + BAY, Z0 + 2 * BAY -- -186 .. -172
local LOW_TOP, MID_TOP = -15.4, -9.4 -- the tops of the y -15.7 and -9.7 boards
local ROW_H = 5.4 -- room above a board's top to the next board
local BOTTOM, UNDER_TOP, RAIL_TOP = -16.0, -4.0, 8.45 -- (the y -3.7 board's underside; BarShelfService's light rail at y 8.3)
-- the y -9.7 board: two pieces, the middle bay open
local midShelves = {}
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and d.Name == "BarShelf" and math.abs(d.Position.Y - (-9.7)) < 0.2 then table.insert(midShelves, d) end
end
assert(#midShelves > 0, "no bar shelf at y -9.7")
local proto = midShelves[1]:Clone() -- (a copy: the originals are destroyed below)
proto:ClearAllChildren()
-- the local axis of a board that runs along world Z gets `len`
local function alongZ(c: CFrame, s: Vector3, len: number): Vector3
	local axes = { { v = c.XVector, i = 1 }, { v = c.YVector, i = 2 }, { v = c.ZVector, i = 3 } }
	table.sort(axes, function(a, b) return math.abs(a.v.Z) > math.abs(b.v.Z) end)
	return if axes[1].i == 1 then Vector3.new(len, s.Y, s.Z) elseif axes[1].i == 2 then Vector3.new(s.X, len, s.Z) else Vector3.new(s.X, s.Y, len)
end
local function shelfPiece(z0: number, z1: number)
	local p = proto:Clone()
	p.Size = alongZ(proto.CFrame, proto.Size, z1 - z0)
	p.CFrame = proto.CFrame.Rotation + Vector3.new(proto.Position.X, proto.Position.Y, (z0 + z1) / 2)
	p.Parent = club
end
shelfPiece(Z0, MID0)
shelfPiece(MID1, Z1)
for _, d in ipairs(midShelves) do d:Destroy() end
-- only the bottom board carries buckets: BarShelfService (the club bottles and
-- their light pucks on every BarShelf at server start) skips boards marked
-- BarBuckets
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and d.Name == "BarShelf" then
		d:SetAttribute("BarBuckets", if d.Position.Y < -12 then true else nil)
	end
end
-- the old graybox stand-in bottles of the two lowest rows
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and d.Name == "BarBottle" and d.Position.Y > LOW_TOP and d.Position.Y < MID_TOP + ROW_H - 0.6
		and d.Position.Z > Z0 and d.Position.Z < Z1 then
		d:Destroy()
	end
end
-- the vertical boards (the shelf's own look, 0.3 thick)
local oldDiv = club:FindFirstChild("BarShelfDividers")
if oldDiv then oldDiv:Destroy() end
local dividers = Instance.new("Folder")
dividers.Name = "BarShelfDividers"
dividers.Parent = club
local THICK = 0.3
local depth = 3 -- (the boards' depth, x 69.5..72.5)
local function divider(z: number, y0: number, y1: number)
	local p = proto:Clone()
	p.Name = "BarShelfDivider"
	p:SetAttribute("BarBuckets", nil)
	p.Size = Vector3.new(depth, y1 - y0, THICK)
	p.CFrame = CFrame.new(proto.Position.X, (y0 + y1) / 2, z)
	p.Parent = dividers
end
divider(Z0 + THICK / 2, BOTTOM, RAIL_TOP)
divider(Z1 - THICK / 2, BOTTOM, RAIL_TOP)
divider(MID0, LOW_TOP, UNDER_TOP)
divider(MID1, LOW_TOP, UNDER_TOP)
-- the buckets
local DrinkBucket = require(game:GetService("ServerScriptService").FashionGame.Services.DrinkBucket)
local Drinks = require(game:GetService("ReplicatedStorage").FashionGame.Shared.ClubConfig).Drinks
local function drinkOf(test: (any) -> boolean): any
	for _, d in ipairs(Drinks) do if test(d) then return d end end
	return { key = "cider", color = Color3.fromRGB(200, 255, 200) }
end
-- (the table sizes of DrinkService: steel 0.9 × 1.5; acrylic 0.9, here × 1.5)
local TIER2 = { kind = "steel", scale = 0.9 * 1.5, name = "BarBucket_Tier2", drink = drinkOf(function(d) return d.tier == 2 and not d.vipOnly end) }
local TIER3 = { kind = "acrylic", scale = 0.9 * 1.5, name = "BarBucket_Tier3", drink = drinkOf(function(d) return d.tier == 3 and not d.vipOnly end) }
local VIP = { kind = "icebox", scale = 1.4, name = "BarBucket_VIP", drink = drinkOf(function(d) return d.vipOnly == true end) }
local old = club:FindFirstChild("BarBucketDisplay")
if old then old:Destroy() end
local display = Instance.new("Folder")
display.Name = "BarBucketDisplay"
display.Parent = club
local X = 71.0 -- the shelves' middle (x 69.5..72.5)
local function still(m: Model)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		elseif p:IsA("LuaSourceContainer") or p:IsA("ProximityPrompt") or p:IsA("ClickDetector") then p:Destroy() end
	end
end
-- the lowest and highest point of a model (world)
local function spanY(m: Model): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local c, h = p.CFrame, p.Size / 2
			local ey = math.abs(c.XVector.Y) * h.X + math.abs(c.YVector.Y) * h.Y + math.abs(c.ZVector.Y) * h.Z
			lo, hi = math.min(lo, p.Position.Y - ey), math.max(hi, p.Position.Y + ey)
		end
	end
	return lo, hi
end
-- its run along the shelf (world Z)
local function spanZ(m: Model): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local c, h = p.CFrame, p.Size / 2
			local ez = math.abs(c.XVector.Z) * h.X + math.abs(c.YVector.Z) * h.Y + math.abs(c.ZVector.Z) * h.Z
			lo, hi = math.min(lo, p.Position.Z - ez), math.max(hi, p.Position.Z + ez)
		end
	end
	return lo, hi
end
local function sit(m: Model, topY: number)
	local lo = spanY(m)
	m:PivotTo(m:GetPivot() + (topY + 0.01 - lo) * Vector3.yAxis)
end
-- one bucket standing on `topY` at z, its front to the room (+X), no taller than `room`
local function bucket(spec, z: number, topY: number, room: number): Model
	local at = CFrame.lookAt(Vector3.new(X, topY, z), Vector3.new(X + 1, topY, z))
	local m = DrinkBucket.build(spec.kind, { spec.drink.color }, at, spec.drink.key)
	m.Name = spec.name
	m.PrimaryPart = nil
	m.WorldPivot = at
	if spec.scale ~= 1 then m:ScaleTo(spec.scale) end
	local lo, hi = spanY(m)
	if hi - lo > room - 0.3 then m:ScaleTo(m:GetScale() * (room - 0.3) / (hi - lo)) end
	sit(m, topY)
	still(m)
	m.Parent = display
	return m
end
-- the VIP ice box in the tall middle bay, without its VIP letters
local vip = bucket(VIP, (MID0 + MID1) / 2, LOW_TOP, UNDER_TOP - LOW_TOP)
for _, d in ipairs(vip:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "VIPLetter" or d.Name == "VIPSignLight") then d:Destroy() end
end
-- two of a kind spread over a bay (inside its boards), shrunk only if they cannot fit
local function pair(spec, b0: number, b1: number): number
	local inner0, inner1 = b0 + THICK, b1 - THICK
	local width = inner1 - inner0
	local a = bucket(spec, (inner0 * 3 + inner1) / 4, LOW_TOP, ROW_H)
	local b = bucket(spec, (inner0 + inner1 * 3) / 4, LOW_TOP, ROW_H)
	local z0, z1 = spanZ(a)
	local len = z1 - z0
	local k = math.min(1, width / (2 * len + 3 * 0.4)) -- (at least 0.4 between and at the ends)
	for _, m in ipairs({ a, b }) do
		if k < 1 then m:ScaleTo(m:GetScale() * k) sit(m, LOW_TOP) end
	end
	local gap = (width - 2 * len * k) / 3
	for i, m in ipairs({ a, b }) do
		local lo, hi = spanZ(m)
		local want = inner0 + gap * i + len * k * (i - 0.5)
		m:PivotTo(m:GetPivot() + Vector3.new(0, 0, want - (lo + hi) / 2))
	end
	return k
end
local k2 = pair(TIER2, MID1, Z1) -- (left from the counter)
local k3 = pair(TIER3, Z0, MID0) -- (right)
table.insert(log, string.format("bar: dividers 4, VIP letters off, bottom row: 2 × tier 2 (%s, ×%.2f fit) left, 2 × tier 3 (%s, ×%.2f fit) right, bottles on the second row",
	TIER2.drink.key, k2, TIER3.drink.key, k3))
return table.concat(log, "\n")
