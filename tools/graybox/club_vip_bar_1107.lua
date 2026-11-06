--!nocheck
-- Club: the north VIP balcony shorter, buckets on the bar shelves (D-954,
-- user 2026-11-07), run in Edit mode LAST in the layout chain (after
-- club_locker_1103). World coordinates; running it again gives the same result.
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
-- 1. north VIP balcony ends at z -181.5
------------------------------------------------------------------
local CUT = -181.5
local function inBalconyEnd(pos: Vector3): boolean
	return pos.X > 158 and pos.X < 191 and pos.Y > 17 and pos.Y < 50 and pos.Z > CUT and pos.Z < -140
end
-- never: the pillar, the walls and the hall's own boxes (zones, interior)
local function protected(name: string): boolean
	return name == "LEDPillar" or name:find("^Wall") ~= nil or name:find("^ClubZone") ~= nil or name == "ClubInterior"
		or name == "Ceiling" or name:find("^Laser") ~= nil or name:find("^Moving") ~= nil or name:find("^Wash") ~= nil
end
local function zExtent(p: BasePart): (number, number)
	local c, h = p.CFrame, p.Size / 2
	local ez = math.abs(c.XVector.Z) * h.X + math.abs(c.YVector.Z) * h.Y + math.abs(c.ZVector.Z) * h.Z
	return p.Position.Z - ez, p.Position.Z + ez
end
-- the end rail (and its glass block) at z -152.2 move to the new end
local endParts = {}
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and (d.Name == "VIP_Rail_NE" or (d.Name == "VIP_RailBlock" and d.Position.X > 170 and d.Position.X < 182 and math.abs(d.Position.X - 176.2) < 1)) then
		local z0, z1 = zExtent(d)
		if z1 - z0 < 2 then table.insert(endParts, d) end -- (the end rails run along X: thin in Z)
	end
end
local removed = 0
for _, d in ipairs(club:GetChildren()) do
	local pos = if d:IsA("BasePart") then d.Position elseif d:IsA("Model") then d:GetPivot().Position else nil
	if pos and not protected(d.Name) and not table.find(endParts, d) and inBalconyEnd(pos) then
		d:Destroy()
		removed += 1
	end
end
for _, d in ipairs(endParts) do
	local z0, z1 = zExtent(d)
	d.Position = Vector3.new(d.Position.X, d.Position.Y, CUT - (z1 - z0) / 2)
end
-- the long pieces that ran on past the cut stop at it
local TRIM = { VIP_Floor_N = true, VIP_Rail_N = true, VIP_RailBlock = true, VIP_RailNeon_N = true, VIP_RailNeonLow = true, VIP_Region_N = true }
local trimmed = 0
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and TRIM[d.Name] and not table.find(endParts, d) and d.Position.X > 158 and d.Position.X < 191 and d.Position.Y > 17 and d.Position.Y < 50 then
		local z0, z1 = zExtent(d)
		if z0 < CUT and z1 > CUT + 0.01 then
			-- the local axis that runs along world Z
			local c = d.CFrame
			local axes = { { v = c.XVector, i = 1 }, { v = c.YVector, i = 2 }, { v = c.ZVector, i = 3 } }
			table.sort(axes, function(a, b) return math.abs(a.v.Z) > math.abs(b.v.Z) end)
			local len = CUT - z0
			local s = d.Size
			d.Size = if axes[1].i == 1 then Vector3.new(len, s.Y, s.Z) elseif axes[1].i == 2 then Vector3.new(s.X, len, s.Z) else Vector3.new(s.X, s.Y, len)
			d.CFrame = c.Rotation + Vector3.new(c.X, c.Y, (z0 + CUT) / 2)
			trimmed += 1
		end
	end
end
table.insert(log, string.format("VIP north balcony: %d parts removed, %d cut at z %.1f, end rail %d", removed, trimmed, CUT, #endParts))

------------------------------------------------------------------
-- 2. buckets on the bar's two lowest shelf rows
------------------------------------------------------------------
local Z0, Z1 = -200, -158 -- the shelves' run
local BAY = (Z1 - Z0) / 3 -- 14
local MID0, MID1 = Z0 + BAY, Z0 + 2 * BAY -- -186 .. -172
local LOW_TOP, MID_TOP = -15.4, -9.4 -- the tops of the y -15.7 and -9.7 shelves
local ROW_H = 5.4 -- room above a shelf top to the next shelf
-- the y -9.7 shelf: two pieces, the middle bay open
local midShelves = {}
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and d.Name == "BarShelf" and math.abs(d.Position.Y - (-9.7)) < 0.2 then table.insert(midShelves, d) end
end
assert(#midShelves > 0, "no bar shelf at y -9.7")
local proto = midShelves[1]
local function shelfPiece(z0: number, z1: number)
	local p = proto:Clone()
	-- (the shelf runs along world Z: size the local axis that points that way)
	local c = proto.CFrame
	local axes = { { v = c.XVector, i = 1 }, { v = c.YVector, i = 2 }, { v = c.ZVector, i = 3 } }
	table.sort(axes, function(a, b) return math.abs(a.v.Z) > math.abs(b.v.Z) end)
	local s, len = proto.Size, z1 - z0
	p.Size = if axes[1].i == 1 then Vector3.new(len, s.Y, s.Z) elseif axes[1].i == 2 then Vector3.new(s.X, len, s.Z) else Vector3.new(s.X, s.Y, len)
	p.CFrame = c.Rotation + Vector3.new(c.X, c.Y, (z0 + z1) / 2)
	p.Parent = club
end
shelfPiece(Z0, MID0)
shelfPiece(MID1, Z1)
for _, d in ipairs(midShelves) do d:Destroy() end
-- the bottles of the two lowest rows go
-- (BarBottle parts, lying on the shelves at y -13.6 / -7.6 / -1.6: the top row stays)
local gone = 0
for _, d in ipairs(club:GetChildren()) do
	if d:IsA("BasePart") and d.Name == "BarBottle" and d.Position.Y > LOW_TOP and d.Position.Y < MID_TOP + ROW_H - 0.6
		and d.Position.Z > Z0 and d.Position.Z < Z1 then
		d:Destroy()
		gone += 1
	end
end
-- the buckets
local DrinkBucket = require(game:GetService("ServerScriptService").FashionGame.Services.DrinkBucket)
local Drinks = require(game:GetService("ReplicatedStorage").FashionGame.Shared.ClubConfig).Drinks
local function drinkOf(test: (any) -> boolean): any
	for _, d in ipairs(Drinks) do if test(d) then return d end end
	return { key = "cider", color = Color3.fromRGB(200, 255, 200) }
end
local TIERS = {
	{ kind = "acrylic", scale = 0.9, drink = drinkOf(function(d) return d.tier == 3 and not d.vipOnly end) }, -- (stack_hydro)
	{ kind = "steel", scale = 0.9 * 1.5, drink = drinkOf(function(d) return d.tier == 2 and not d.vipOnly end) },
	{ kind = "bottle", scale = 0.8, drink = drinkOf(function(d) return d.tier == 1 and d.key ~= "water" end) },
}
local VIP = { kind = "icebox", scale = 1.4, drink = drinkOf(function(d) return d.vipOnly == true end) }
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
local function lowestY(m: Model): (number, number)
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
-- one bucket standing on `topY` at z, front to the room, no taller than `room`
local function bucket(spec, z: number, topY: number, room: number): Model
	-- (the boxes are long along their own Z: turned so the long side runs along the shelf)
	local long = spec.kind == "icebox" or spec.kind == "acrylic"
	local at = CFrame.lookAt(Vector3.new(X, topY, z), Vector3.new(X, topY, z) + (if long then Vector3.zAxis else Vector3.xAxis))
	local m = DrinkBucket.build(spec.kind, { spec.drink.color }, at, spec.drink.key)
	m.PrimaryPart = nil
	m.WorldPivot = at
	if spec.scale ~= 1 then m:ScaleTo(spec.scale) end
	local lo, hi = lowestY(m)
	if hi - lo > room - 0.3 then m:ScaleTo(m:GetScale() * (room - 0.3) / (hi - lo)) lo, hi = lowestY(m) end
	m:PivotTo(m:GetPivot() + (topY + 0.01 - lo) * Vector3.yAxis)
	still(m)
	m.Parent = display
	return m
end
-- its length along the shelf (world Z)
local function zLength(m: Model): number
	local _, size = m:GetBoundingBox()
	local cf = m:GetBoundingBox()
	return math.abs(cf.XVector.Z) * size.X + math.abs(cf.YVector.Z) * size.Y + math.abs(cf.ZVector.Z) * size.Z
end
-- the VIP ice box in the tall middle bay
local vip = bucket(VIP, (MID0 + MID1) / 2, LOW_TOP, (MID_TOP + ROW_H) - LOW_TOP)
vip.Name = "BarBucket_VIP"
-- the side bays: tier 3, 2, 1 from the VIP bay outward, in both rows
local built = 1
for _, topY in ipairs({ LOW_TOP, MID_TOP }) do
	for _, side in ipairs({ -1, 1 }) do
		-- (side -1: the bay z -200..-186, its inner edge -186, outward = -Z; side 1: -172..-158, inner edge -172, outward = +Z)
		local inner = if side < 0 then MID0 else MID1
		local models = {}
		local total = 0
		for i, spec in ipairs(TIERS) do
			local m = bucket(spec, inner, topY, ROW_H)
			m.Name = "BarBucket_Tier" .. (4 - i)
			models[i] = m
			total += zLength(m)
		end
		-- spread over the bay: equal gaps, tier 3 next to the VIP bay
		local gap = math.max((BAY - total) / 4, 0.2)
		local k = if total + gap * 4 > BAY then BAY / (total + gap * 4) else 1
		local z = inner + side * gap * k
		for _, m in ipairs(models) do
			if k < 1 then m:ScaleTo(m:GetScale() * k) local lo = lowestY(m) m:PivotTo(m:GetPivot() + (topY + 0.01 - lo) * Vector3.yAxis) end
			local len = zLength(m)
			local cf = m:GetBoundingBox()
			local centre = z + side * len / 2
			m:PivotTo(m:GetPivot() + Vector3.new(0, 0, centre - cf.Z))
			z = centre + side * (len / 2 + gap * k)
			built += 1
		end
	end
end
table.insert(log, string.format("bar: y -9.7 shelf open over z %.0f..%.0f, %d bottle parts removed, %d buckets (VIP %s, tiers %s / %s / %s)",
	MID0, MID1, gone, built, VIP.drink.key, TIERS[1].drink.key, TIERS[2].drink.key, TIERS[3].drink.key))
return table.concat(log, "\n")
