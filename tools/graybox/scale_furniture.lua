-- Tables, chairs and shelves 1.5 times bigger (user 2026-10-27: with a tall
-- avatar the furniture looked like doll furniture). Run it LAST in the layout
-- chain (after build_beach_signs): the builders make everything at its first
-- size, this pass grows it. Parts it has grown carry the attribute FurnScaled,
-- so running it again does nothing to them.
--
-- Why 1.5: the furniture was drawn for a ~5.5-stud avatar (a 3.2 table is
-- 0.58 of that height, a 2 seat 0.36). Players here run from ~5.5 (default)
-- to ~10.5 (the tall test avatar); 1.5x fits an ~8-stud avatar, the middle of
-- that range, so neither end is more than ~35 % off.
--
-- How: the listed parts are grouped (parts touching within 0.6 = one table
-- with its chairs). A small group grows about the middle of its footprint on
-- the floor, so the chairs move out with the table. A long group (over 12,
-- e.g. a window bar with its stools, a gondola) only grows upward and in
-- thickness: its length and place stay, so nothing pokes through a wall.
local MODE = ... or "apply"
local S = 1.5
local TOL = 0.6
local LONG = 12

-- where, and which part names (BaseParts, Seats included)
local SETS = {
	{ path = { "Hongdae_Layout", "OH24Store" }, names = { "DeckTable", "DeckTableLeg", "DeckStool", "StoolLeg", "WindowBar", "BarLeg", "WindowStool",
		"GondolaSpine", "GondolaBase", "GondolaEnd", "GondolaShelf", "GondolaTop" } },
	{ path = { "Hongdae_Layout", "Gukbap" }, names = { "TableLeg", "TableTop", "TissueBox", "Stool", "StoolSeat", "StoolLeg", "Chair" } }, -- (Chair: wooden chairs since 2026-10-29)
	{ path = { "Hongdae_Layout", "OhuFourCuts" }, names = { "OvalTableTop", "OvalTableEnd", "OvalTableLeg" } }, -- (the round table + ring bench are built big)
	{ path = { "Graybox_MainSocial", "04_Beach_Aquarium", "BeachCafe" }, names = { "CafeTable", "TableLeg", "ChairCushion", "CafeChair", "Leg", "CafeStool", "CafeStoolCushion", "BarStool", "BarStoolCushion", "StoolLeg", "WindowBar" } },
}

local function find(path)
	local node: Instance? = workspace
	for _, n in ipairs(path) do
		node = node and node:FindFirstChild(n)
	end
	return node
end

-- world-space box of a part
local function aabb(p: BasePart)
	local c, s = p.CFrame, p.Size / 2
	local h = Vector3.new(
		math.abs(c.XVector.X) * s.X + math.abs(c.YVector.X) * s.Y + math.abs(c.ZVector.X) * s.Z,
		math.abs(c.XVector.Y) * s.X + math.abs(c.YVector.Y) * s.Y + math.abs(c.ZVector.Y) * s.Z,
		math.abs(c.XVector.Z) * s.X + math.abs(c.YVector.Z) * s.Y + math.abs(c.ZVector.Z) * s.Z)
	return p.Position - h, p.Position + h
end

local grown, groups, report = 0, 0, {}
for _, set in ipairs(SETS) do
	local root = find(set.path)
	if not root then continue end
	local wanted = {}
	for _, n in ipairs(set.names) do wanted[n] = true end
	local parts = {}
	for _, d in ipairs(root:GetDescendants()) do
		-- (not the club bar stool copies of polish_1029: they are made at their
		-- size, and their legs are also called "Leg", user 2026-10-30)
		if d:IsA("BasePart") and wanted[d.Name] and not d:GetAttribute("FurnScaled")
			and not d:FindFirstAncestor("ClubStool") and not d:FindFirstAncestor("BarStoolOHU") then
			local lo, hi = aabb(d)
			table.insert(parts, { p = d, lo = lo, hi = hi })
		end
	end
	-- groups: union-find over touching boxes
	local parent = {}
	for i = 1, #parts do parent[i] = i end
	local function rootOf(i) while parent[i] ~= i do parent[i] = parent[parent[i]] i = parent[i] end return i end
	for i = 1, #parts do
		local a = parts[i]
		for j = i + 1, #parts do
			local b = parts[j]
			if a.lo.X - TOL <= b.hi.X and b.lo.X - TOL <= a.hi.X and a.lo.Z - TOL <= b.hi.Z and b.lo.Z - TOL <= a.hi.Z and a.lo.Y - TOL <= b.hi.Y and b.lo.Y - TOL <= a.hi.Y then
				local ra, rb = rootOf(i), rootOf(j)
				if ra ~= rb then parent[ra] = rb end
			end
		end
	end
	local byRoot = {}
	for i, e in ipairs(parts) do
		local r = rootOf(i)
		local g = byRoot[r]
		if not g then g = { lo = e.lo, hi = e.hi, list = {} } byRoot[r] = g end
		g.lo = g.lo:Min(e.lo) g.hi = g.hi:Max(e.hi)
		table.insert(g.list, e.p)
	end
	for _, g in pairs(byRoot) do
		groups += 1
		local floorY = g.lo.Y
		local cx, cz = (g.lo.X + g.hi.X) / 2, (g.lo.Z + g.hi.Z) / 2
		local long = math.max(g.hi.X - g.lo.X, g.hi.Z - g.lo.Z) > LONG
		if MODE == "check" and long then
			table.insert(report, string.format("%s long %dp %.0f..%.0f x %.0f..%.0f", set.path[#set.path], #g.list, g.lo.X, g.hi.X, g.lo.Z, g.hi.Z))
		end
		for _, p in ipairs(g.list) do
			if MODE == "check" then continue end
			local pos = p.Position
			local nx = if long then pos.X else cx + (pos.X - cx) * S
			local nz = if long then pos.Z else cz + (pos.Z - cz) * S
			local ny = floorY + (pos.Y - floorY) * S
			-- size: every axis grows, except (in a long group) the ones longer than 6
			local sz = p.Size
			local function k(v) return if long and v > 6 then v else v * S end
			p.Size = Vector3.new(k(sz.X), k(sz.Y), k(sz.Z))
			p.CFrame = CFrame.new(nx, ny, nz) * p.CFrame.Rotation
			p:SetAttribute("FurnScaled", true)
			grown += 1
		end
	end
end
return string.format("furniture x%.1f: %d parts in %d groups (MODE=%s)\n", S, grown, groups, MODE) .. table.concat(report, "\n")
