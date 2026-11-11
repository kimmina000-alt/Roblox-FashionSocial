--!strict
-- 한옥 마을 안쪽 = 경복궁 블록아웃 (D-1305, user 2026-11-11: "첨부하는 사진 보고 한옥 마을
-- 내부 블록아웃으로 건축해", 사진 docs/04_ART/references/gyeongbokgung_map.webp,
-- 경복궁 관람코스 안내도).
--
-- Run in Studio Edit mode (command bar / MCP). It only rebuilds its own model
-- Workspace.Hongdae_Layout.PalaceBlockout, so it may run on its own (it does
-- not touch the zones or the rest of the layout chain); run it again after
-- build_hongdae_layout if that one cleared the layout.
--
-- The village is the walled square x 52..700, z 49..700 with 광화문 at its
-- north-west corner, the gate facing out to the north-west. The map's axis
-- (광화문 at the bottom, the halls one behind the other towards the top) is
-- laid along the diagonal into the square: u = metres from just inside the
-- gate towards the south-east, v = to the right when walking in (the map's
-- east side: 동궁, 소주방, 자경전, 민속박물관; the west side: 경회루, 수정전,
-- 고궁박물관). About 1 stud a metre, squeezed where the square narrows.
-- Simple boxes only (a blockout): stone platforms, hall bodies, roof slabs,
-- cloisters (행각) round the courtyards, ponds, trees, and a label over each
-- numbered place of the map.

local ROOT = workspace:WaitForChild("Hongdae_Layout")
local old = ROOT:FindFirstChild("PalaceBlockout")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "PalaceBlockout"

local O = Vector3.new(165, 0, 215) -- just inside 광화문
local F = Vector3.new(0.70710678, 0, 0.70710678) -- into the palace (u)
local R = Vector3.new(-0.70710678, 0, 0.70710678) -- the right hand walking in (v)

local function at(u: number, v: number, y: number): CFrame
	return CFrame.fromMatrix(O + F * u + R * v + Vector3.new(0, y, 0), R, Vector3.yAxis)
end

local COL = {
	lawn = Color3.fromRGB(118, 152, 86),
	pave = Color3.fromRGB(214, 206, 186), -- courtyards (박석)
	path = Color3.fromRGB(196, 186, 160),
	stone = Color3.fromRGB(184, 180, 170), -- platforms (월대, 기단)
	body = Color3.fromRGB(150, 62, 48), -- columns / walls of the halls (단청 red)
	roof = Color3.fromRGB(62, 64, 70), -- 기와
	wall = Color3.fromRGB(196, 150, 120), -- 궁궐 담장 (brick-ish)
	water = Color3.fromRGB(86, 146, 186),
	tree = Color3.fromRGB(70, 118, 64),
	trunk = Color3.fromRGB(96, 74, 56),
	modern = Color3.fromRGB(205, 205, 210),
}

local count = 0
local outside = 0
local function part(name: string, cf: CFrame, size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	count += 1
	local x, z = cf.X, cf.Z
	if x < 54 or x > 698 or z < 51 or z > 698 then outside += 1 end
	return p
end
-- a box in palace coordinates: v0..v1 across, u0..u1 along the axis, y0 + h up
local function box(name: string, u0: number, u1: number, v0: number, v1: number, y0: number, h: number, color: Color3, parent: Instance): Part
	return part(name, at((u0 + u1) / 2, (v0 + v1) / 2, y0 + h / 2), Vector3.new(math.abs(v1 - v0), h, math.abs(u1 - u0)), color, parent)
end
local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = model
	return m
end
local function label(parent: BasePart, text: string)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Size = UDim2.fromOffset(170, 34)
	g.StudsOffsetWorldSpace = Vector3.new(0, parent.Size.Y / 2 + 8, 0)
	g.MaxDistance = 600
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	t.BackgroundTransparency = 0.25
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Text = text
	t.Parent = g
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 8)
	g.Parent = parent
end

-- a hall: stone base tiers, the body, a hipped roof as two slabs and a ridge
local function hall(m: Instance, name: string, u: number, v: number, w: number, d: number, opts: {[string]: any}?): Part
	local o = opts or {}
	local tiers = o.tiers or 1
	local y = 0
	for i = 1, tiers do
		local grow = (tiers - i) * 6 + 4
		box(name .. "_Base" .. i, u - d / 2 - grow, u + d / 2 + grow, v - w / 2 - grow, v + w / 2 + grow, y, 2.2, COL.stone, m)
		y += 2.2
	end
	local bodyH = o.h or 9
	local body = box(name, u - d / 2, u + d / 2, v - w / 2, v + w / 2, y, bodyH, COL.body, m)
	y += bodyH
	local storeys = o.storeys or 1
	for s = 1, storeys do
		box(name .. "_Roof" .. s, u - d / 2 - 4, u + d / 2 + 4, v - w / 2 - 4, v + w / 2 + 4, y, 1.4, COL.roof, m)
		y += 1.4
		if s < storeys then
			box(name .. "_Upper" .. s, u - d / 2 + 3, u + d / 2 - 3, v - w / 2 + 3, v + w / 2 - 3, y, 6, COL.body, m)
			y += 6
		end
	end
	box(name .. "_RoofTop", u - d / 4, u + d / 4, v - w / 2 + 4, v + w / 2 - 4, y, math.max(2.5, d / 6), COL.roof, m)
	if o.label then label(body, o.label) end
	return body
end

-- a courtyard with 행각 (roofed corridors) on its four sides and a gate gap
-- in the front side (and the back side if `back`)
local function compound(name: string, u0: number, u1: number, v0: number, v1: number, opts: {[string]: any}?): Model
	local o = opts or {}
	local m = group(name)
	box("Court", u0, u1, v0, v1, 0, 0.12, COL.pave, m)
	local T, H = o.depth or 7, o.h or 7
	local gap = o.gap or 14
	local vm = (v0 + v1) / 2
	local function wing(nm: string, a0: number, a1: number, b0: number, b1: number)
		box(nm, a0, a1, b0, b1, 0, H, COL.body, m)
		box(nm .. "Roof", a0 - 1, a1 + 1, b0 - 1, b1 + 1, H, 1.2, COL.roof, m)
	end
	-- front (u0) and back (u1) sides along v, with the gate gap in the middle
	wing("FrontL", u0, u0 + T, v0, vm - gap / 2)
	wing("FrontR", u0, u0 + T, vm + gap / 2, v1)
	if o.back then
		wing("BackL", u1 - T, u1, v0, vm - gap / 2)
		wing("BackR", u1 - T, u1, vm + gap / 2, v1)
	else
		wing("Back", u1 - T, u1, v0, v1)
	end
	wing("SideL", u0 + T, u1 - T, v0, v0 + T)
	wing("SideR", u0 + T, u1 - T, v1 - T, v1)
	if o.gate then
		hall(m, name .. "Gate", u0 + T / 2, vm, gap + 10, T + 4, { h = 8, label = o.gate })
	end
	return m
end

local function pond(name: string, u0: number, u1: number, v0: number, v1: number): Model
	local m = group(name)
	local water = box("Water", u0, u1, v0, v1, 0, 0.3, COL.water, m)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	local e = 2
	box("Edge", u0 - e, u0, v0 - e, v1 + e, 0, 1.2, COL.stone, m)
	box("Edge", u1, u1 + e, v0 - e, v1 + e, 0, 1.2, COL.stone, m)
	box("Edge", u0, u1, v0 - e, v0, 0, 1.2, COL.stone, m)
	box("Edge", u0, u1, v1, v1 + e, 0, 1.2, COL.stone, m)
	return m
end

local trees = group("Trees")
local function tree(u: number, v: number, s: number)
	part("Trunk", at(u, v, 2), Vector3.new(1.4, 4, 1.4), COL.trunk, trees)
	part("Crown", at(u, v, 4 + s / 2), Vector3.new(s, s, s), COL.tree, trees, Enum.PartType.Ball)
end

------------------------------------------------------------------------------
-- ground: the lawn inside the square (the corner outside the diagonal wall
-- in front of 광화문 is left as it is), the walls that close the square
do
	local m = group("Ground")
	local function world(name: string, x0: number, x1: number, z0: number, z1: number, color: Color3)
		part(name, CFrame.new((x0 + x1) / 2, 0.06, (z0 + z1) / 2), Vector3.new(x1 - x0, 0.1, z1 - z0), color, m).Material = Enum.Material.Grass
	end
	world("Lawn", 300, 696, 53, 696, COL.lawn)
	world("Lawn", 56, 300, 300, 696, COL.lawn)
	-- the triangle between them, inside the diagonal wall
	local w = Instance.new("WedgePart")
	w.Name = "Lawn"
	w.Anchored = true
	w.Color = COL.lawn
	w.Material = Enum.Material.Grass
	w.Size = Vector3.new(0.1, 236, 236)
	-- (the right-angle corner at x 300, z 300; the slope faces the gate)
	w.CFrame = CFrame.new(300 - 118, 0.06, 300 - 118) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(0, 0, math.rad(90))
	w.Parent = m
	count += 1
	-- the square's east and south walls (the north z 49 and west x 52 walls are there)
	local function wall(x0: number, x1: number, z0: number, z1: number)
		part("PalaceWall", CFrame.new((x0 + x1) / 2, 5, (z0 + z1) / 2), Vector3.new(math.max(3, x1 - x0), 10, math.max(3, z1 - z0)), COL.wall, m)
		part("PalaceWallCap", CFrame.new((x0 + x1) / 2, 10.6, (z0 + z1) / 2), Vector3.new(math.max(3, x1 - x0) + 2, 1.2, math.max(3, z1 - z0) + 2), COL.roof, m)
	end
	wall(698, 701, 49, 702)
	wall(52, 701, 698, 701)
end

------------------------------------------------------------------------------
-- 1 광화문 → 흥례문: the front court, the second gate
do
	local m = group("01_FrontCourt")
	box("Court", 6, 96, -80, 80, 0, 0.12, COL.pave, m)
	box("RoyalPath", 6, 330, -5, 5, 0.12, 0.2, COL.path, m) -- (어도, all the way to 근정전)
	-- the wall across the axis with 흥례문 in it
	box("Wall", 96, 100, -150, -16, 0, 9, COL.wall, m)
	box("Wall", 96, 100, 16, 150, 0, 9, COL.wall, m)
	hall(m, "Heungnyemun", 98, 0, 40, 14, { h = 8, storeys = 2, label = "흥례문" })
end

-- 흥례문 courtyard with the 영제교 stream and bridge
do
	local m = compound("02a_HeungnyemunCourt", 100, 196, -90, 90, { gate = nil, back = true, gap = 20 })
	local water = box("Stream", 142, 150, -83, 83, 0, 0.3, COL.water, m)
	water.Material = Enum.Material.Glass
	box("Yeongjegyo", 138, 154, -9, 9, 0, 1.6, COL.stone, m)
	hall(m, "Geunjeongmun", 192, 0, 34, 12, { h = 8, label = "근정문" })
end

-- 2 근정전 in its cloister, on the two-tier 월대
do
	local m = compound("02_Geunjeongjeon", 196, 336, -78, 78, { back = false })
	hall(m, "Geunjeongjeon", 286, 0, 44, 26, { tiers = 2, h = 13, storeys = 2, label = "② 근정전" })
	-- the rank stones (품계석) along the path: two rows of small posts
	for i = 0, 5 do
		box("RankStone", 214 + i * 9, 215.5 + i * 9, -9, -7.5, 0, 1.6, COL.stone, m)
		box("RankStone", 214 + i * 9, 215.5 + i * 9, 7.5, 9, 0, 1.6, COL.stone, m)
	end
end

-- 3 사정전 (with 만춘전 / 천추전 at the sides)
do
	local m = compound("03_Sajeongjeon", 340, 392, -50, 50, { gate = "사정문" })
	hall(m, "Sajeongjeon", 370, 0, 30, 15, { tiers = 1, h = 9, label = "③ 사정전" })
	hall(m, "Manchunjeon", 370, 33, 14, 10, { h = 7 })
	hall(m, "Cheonchujeon", 370, -33, 14, 10, { h = 7 })
end

-- 4 강녕전 and 교태전 (and the 아미산 garden behind)
do
	local m = compound("04a_Gangnyeongjeon", 396, 452, -50, 50, { gate = "향오문" })
	hall(m, "Gangnyeongjeon", 428, 0, 40, 16, { tiers = 1, h = 8, label = "④ 강녕전" })
	hall(m, "Yeonsaengjeon", 428, 36, 12, 10, { h = 6 })
	hall(m, "Gyeongseongjeon", 428, -36, 12, 10, { h = 6 })
	local m2 = compound("04b_Gyotaejeon", 456, 512, -50, 50, { gate = "양의문" })
	hall(m2, "Gyotaejeon", 488, 0, 36, 16, { tiers = 1, h = 8, label = "④ 교태전" })
	-- 아미산: three green terraces with four chimneys
	local g = group("04c_Amisan")
	for i = 0, 2 do
		local t = box("Terrace" .. i, 514 + i * 5, 530, -24 + i * 3, 24 - i * 3, 0, 1.5 + i * 1.5, COL.lawn, g)
		t.Material = Enum.Material.Grass
	end
	for i = 0, 3 do box("Chimney", 520, 523, -12 + i * 8, -9 + i * 8, 4.5, 6, COL.body, g) end
end

-- 5 흠경각 and 함원전 (west of 교태전)
do
	local m = compound("05_Heumgyeonggak", 458, 510, -112, -56, {})
	hall(m, "Hamwonjeon", 484, -84, 24, 12, { h = 7, label = "⑤ 흠경각·함원전" })
end

-- 6 자경전 (east)
do
	local m = compound("06_Jagyeongjeon", 430, 486, 66, 132, { gate = "만세문" })
	hall(m, "Jagyeongjeon", 462, 99, 34, 14, { tiers = 1, h = 8, label = "⑥ 자경전" })
end

-- 7 동궁 (the crown prince's halls, east of 근정전)
do
	local m = compound("07a_Jaseondang", 214, 274, 92, 168, { gate = nil })
	hall(m, "Jaseondang", 246, 130, 30, 14, { tiers = 1, h = 8, label = "⑦ 동궁 (자선당)" })
	local m2 = compound("07b_Bihyeongak", 280, 330, 100, 160, {})
	hall(m2, "Bihyeongak", 307, 130, 26, 12, { h = 7, label = "⑦ 비현각" })
end

-- 14 소주방 (the royal kitchens, east of 강녕전): three halls in a row
do
	local m = compound("14_Sojubang", 352, 410, 68, 146, {})
	for i = 0, 2 do
		hall(m, "Sojubang" .. i, 382, 82 + i * 25, 16, 22, { h = 6, label = if i == 1 then "⑭ 소주방" else nil })
	end
end

-- 13 수정전 (west of 근정전, on a high base, no cloister)
do
	local m = group("13_Sujeongjeon")
	box("Yard", 286, 334, -168, -96, 0, 0.12, COL.pave, m)
	hall(m, "Sujeongjeon", 312, -132, 44, 18, { tiers = 1, h = 8, label = "⑬ 수정전" })
end

-- 12 경회루: the big pond, the island, the pavilion on 48 stone pillars (24 here)
do
	local m = pond("12_GyeonghoeruPond", 340, 450, -262, -142)
	local isl = box("Island", 362, 428, -232, -162, 0, 3, COL.stone, m)
	local pillars = group("12_GyeonghoeruPillars")
	for iu = 0, 3 do
		for iv = 0, 5 do
			box("Pillar", 372 + iu * 15, 374.5 + iu * 15, -224 + iv * 11.5, -221.5 + iv * 11.5, 3, 9, COL.stone, pillars)
		end
	end
	local floor = box("Gyeonghoeru", 368, 422, -228, -166, 12, 7, COL.body, m)
	box("Gyeonghoeru_Roof", 364, 426, -232, -162, 19, 1.6, COL.roof, m)
	box("Gyeonghoeru_RoofTop", 382, 408, -222, -172, 20.6, 4, COL.roof, m)
	label(floor, "⑫ 경회루")
	-- the three bridges from the east bank
	for i = 0, 2 do box("Bridge", 378 + i * 16, 386 + i * 16, -162, -142, 0, 1.4, COL.stone, m) end
	-- small islands with pines
	box("Islet", 436, 446, -256, -246, 0, 1.6, COL.lawn, m)
	tree(441, -251, 7)
	box("Islet", 436, 446, -158, -148, 0, 1.6, COL.lawn, m)
	tree(441, -153, 7)
	local _ = isl
end

-- 8 함화당 · 집경당
do
	local m = compound("08_Hamhwadang", 532, 584, -24, 54, {})
	hall(m, "Hamhwadang", 558, 0, 22, 12, { h = 7, label = "⑧ 함화당·집경당" })
	hall(m, "Jipgyeongdang", 558, 32, 18, 12, { h = 7 })
end

-- 9 향원정 (the pond, the hexagonal pavilion on its island, the bridge north)
-- and 건청궁 behind it
do
	local m = pond("09a_HyangwonjeongPond", 592, 640, -14, 36)
	box("Island", 609, 623, 6, 20, 0, 2, COL.lawn, m).Material = Enum.Material.Grass
	local pav = part("Hyangwonjeong", at(616, 13, 2 + 5), Vector3.new(10, 6, 6), COL.body, m, Enum.PartType.Cylinder)
	pav.CFrame = at(616, 13, 2 + 3) * CFrame.Angles(0, 0, math.rad(90))
	pav.Size = Vector3.new(6, 7, 7)
	part("Hyangwonjeong_Roof", at(616, 13, 2 + 6.8) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.6, 10, 10), COL.roof, m, Enum.PartType.Cylinder)
	part("Hyangwonjeong_Top", at(616, 13, 2 + 9.5) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(3, 5, 5), COL.body, m, Enum.PartType.Cylinder)
	label(pav, "⑨ 향원정")
	box("Chwihyanggyo", 623, 642, 11, 15, 0, 1.4, COL.stone, m) -- (the bridge north)
	local g = compound("09b_Geoncheonggung", 644, 676, -64, 6, {})
	hall(g, "Geoncheonggung", 662, -29, 30, 12, { h = 7, label = "⑨ 건청궁" })
end

-- 10 집옥재
do
	local m = compound("10_Jibokjae", 566, 612, -110, -52, {})
	hall(m, "Jibokjae", 590, -81, 30, 14, { tiers = 1, h = 9, label = "⑩ 집옥재" })
end

-- 11 태원전
do
	local m = compound("11_Taewonjeon", 506, 566, -178, -122, { gate = nil })
	hall(m, "Taewonjeon", 536, -150, 30, 14, { tiers = 1, h = 8, label = "⑪ 태원전" })
end

-- 국립고궁박물관 (west of the front court) and 국립민속박물관 with its pagoda (east)
do
	local m = group("Museums")
	local a = box("PalaceMuseum", 24, 92, -230, -120, 0, 12, COL.modern, m)
	box("PalaceMuseum_Roof", 20, 96, -234, -116, 12, 1.4, COL.roof, m)
	label(a, "국립고궁박물관")
	local b = box("FolkMuseum", 368, 440, 184, 236, 0, 10, COL.modern, m)
	label(b, "국립민속박물관")
	local y = 0
	for i = 0, 4 do
		local s = 26 - i * 4
		box("Pagoda" .. i, 330 - s / 2, 330 + s / 2, 210 - s / 2, 210 + s / 2, y, 6, if i % 2 == 0 then COL.modern else COL.roof, m)
		y += 6
	end
end

-- paths between the places (sand strips) and the trees of the map's forests
do
	local m = group("Paths")
	box("WestPath", 100, 560, -104, -96, 0.1, 0.12, COL.path, m)
	box("EastPath", 196, 520, 54, 62, 0.1, 0.12, COL.path, m)
	box("NorthPath", 512, 650, -6, 2, 0.1, 0.12, COL.path, m)
	box("CrossPath", 520, 528, -180, 120, 0.1, 0.12, COL.path, m)
	-- the east forest (the map's right side) and the north-west woods
	-- (the square narrows towards the far corner: u + v ≤ 680 and u - v ≤ 750 stay inside)
	for i = 0, 13 do
		tree(420 + (i % 7) * 12, 140 + math.floor(i / 7) * 16 + (i % 2) * 6, 9)
	end
	for i = 0, 9 do
		tree(540 + (i % 5) * 12, 70 + math.floor(i / 5) * 14, 8)
	end
	for i = 0, 7 do
		tree(120 + i * 22, -150 - (i % 2) * 14, 8)
	end
	for i = 0, 5 do
		tree(580 + (i % 3) * 14, -120 + math.floor(i / 3) * 16, 8)
	end
end

model.Parent = ROOT
print(string.format("[PalaceBlockout] %d parts (%d outside the square)", count, outside))
return count, outside
