--!strict
-- Detailed hand-held models for the cafe foods and the OH24 goods (user
-- 2026-10-27: "레퍼런스 검색해서 보고 그대로 구현"), built from what the real
-- ones look like (references in docs/04_ART/FOOD_REFERENCES.md):
--
--   소금빵            a short plump roll in rolled ridges, a crisp flat bottom, coarse salt
--   베이글            a glossy ring with sesame
--   딸기 크림 크루아상  a crescent split open: cream and strawberry halves inside
--   허니카라멜브레드    a thick toast cube scored on top, whipped cream, caramel drizzle, almonds
--   딸기 파르페        a stemmed tall glass: granola, cream, strawberry layers, a cream swirl,
--                     strawberries, a wafer and mint
--   약과              a flower-shaped glazed honey cookie with a pine nut
--   인절미 토스트       toast with rice cake inside, bean powder, almond slices, honey
--   생수              a clear PET bottle, blue label and cap, water inside
--   바나나우유         the round "단지" jar, pale yellow, foil lid, a straw
--   탄산음료 캔        a red can with a white band, silver ends and a ring pull
--   아이스크림 바       a pink bar dipped in chocolate with crunch bits, on a stick
--   감자칩            a puffy opened bag with crimped seams and chips poking out
--   초코 과자          an opened box of chocolate-dipped biscuit sticks
--   삼각김밥           a triangle of rice in a laver wrap
--   컵라면            a red cup, the paper lid peeled back, broth, noodles, chopsticks
--
-- FoodShapes.build(item) returns the handle (its pieces welded on) and the
-- tool grip, or nil for items drawn the old way. Pieces named in
-- FoodShapes.NotEdible stay; every other piece is eaten (SnackService cuts
-- them top-down, or from the front along Z when EatAlong = "Z").

local FoodShapes = {}

-- containers and parts that stay in the hand
FoodShapes.NotEdible = { Bag = true, Box = true, Label = true, Seam = true, Plate = true, Lid = true, Wrap = true, Stick = true }
-- breads are bitten from the front end (user 2026-10-26); the rest top-down
FoodShapes.AlongZ = { bagel = true, croissant = true, yakgwa = true, injeolmi = true }

local UP = CFrame.Angles(0, 0, math.rad(90)) -- a Part cylinder runs along X: this stands it up

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function blob(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(name, size, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cyl(name: string, d: number, h: number, color: Color3, material: Enum.Material?): Part
	return part(name, Vector3.new(h, d, d), color, material, Enum.PartType.Cylinder)
end

local function attach(handle: BasePart, piece: BasePart, offset: CFrame): BasePart
	piece.CFrame = handle.CFrame * offset
	piece.Parent = handle
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
	return piece
end

-- A printed label wrapped round a (tapered) band: n thin panels on the cone
-- from (y0, radius r0) to (y1, r1), each showing its slice of `tex` (the
-- whole image goes once round). v0 / vTotal: when one picture spans several
-- bands, this band shows the slice of it starting v0 down (slant lengths).
-- A Part cylinder cannot take a wrapped image; Texture slices can.
local function wrap(h: BasePart, y0: number, y1: number, r0: number, r1: number, n: number, tex: string, v0: number?, vTotal: number?)
	local height = y1 - y0
	local slant = math.sqrt(height * height + (r1 - r0) ^ 2)
	local rm = (r0 + r1) / 2
	local wn = 2 * rm * math.tan(math.pi / n) -- the polygon side
	local grow = wn * 0.06 -- panels overlap a little: no light seams between them
	local tilt = math.atan2(r1 - r0, height)
	for i = 0, n - 1 do
		local a = (i + 0.5) * 2 * math.pi / n
		local out = Vector3.new(math.sin(a), 0, math.cos(a))
		local c = Vector3.new(0, (y0 + y1) / 2, 0) + out * rm
		local p = part("Wrap", Vector3.new(wn + 2 * grow, slant, 0.02), Color3.fromRGB(250, 250, 250))
		attach(h, p, CFrame.lookAt(c, c + out) * CFrame.Angles(-tilt, 0, 0))
		local t = Instance.new("Texture")
		t.Texture = tex
		t.Face = Enum.NormalId.Front
		t.StudsPerTileU = wn * n
		t.OffsetStudsU = i * wn - grow
		t.StudsPerTileV = vTotal or slant
		t.OffsetStudsV = v0 or 0
		t.Parent = p
	end
	return slant
end

local function newHandle(size: Vector3): Part
	local h = part("Handle", size, Color3.new(1, 1, 1))
	h.Transparency = 1
	return h
end

-- a little random scatter that is the same every time
local function scatter(n: number, seed: number): {Vector2}
	local r = Random.new(seed)
	local out = {}
	for i = 1, n do out[i] = Vector2.new(r:NextNumber(-1, 1), r:NextNumber(-1, 1)) end
	return out
end

local C = Color3.fromRGB
local WHITE, CREAM = C(252, 250, 246), C(250, 244, 230)
local STRAWBERRY, LEAF = C(215, 30, 50), C(70, 150, 60)

type Builder = (item: any) -> (Part, CFrame)

local B: {[string]: Builder} = {}

---------------------------------------------------------------- cafe

B.saltbread = function(item)
	local h = newHandle(Vector3.new(0.5, 0.3, 0.8))
	local crust = item.color :: Color3
	attach(h, blob("Fill", Vector3.new(0.62, 0.12, 0.92), C(185, 120, 55)), CFrame.new(0, -0.13, 0)) -- the buttery fried bottom
	attach(h, blob("Fill", Vector3.new(0.64, 0.4, 0.9), crust), CFrame.new(0, 0, 0))
	-- the rolled dough: ridges across the top, smaller toward the ends
	for i, z in ipairs({ -0.36, -0.12, 0.12, 0.36 }) do
		local s = if i == 1 or i == 4 then 0.8 else 1
		attach(h, blob("Fill", Vector3.new(0.6 * s, 0.36 * s, 0.26), crust:Lerp(C(150, 85, 30), 0.25)), CFrame.new(0, 0.05, z))
	end
	for _, v in ipairs(scatter(9, 11)) do -- coarse salt
		attach(h, part("Salt", Vector3.new(0.045, 0.03, 0.045), C(250, 250, 250)), CFrame.new(v.X * 0.18, 0.21, v.Y * 0.3))
	end
	return h, CFrame.new(0, 0, 0)
end

B.bagel = function(item)
	local h = newHandle(Vector3.new(0.5, 0.3, 0.5))
	local R, N = 0.3, 12
	for k = 0, N - 1 do
		local a = k * 2 * math.pi / N
		attach(h, blob("Fill", Vector3.new(0.3, 0.26, 0.3), item.color), CFrame.new(math.cos(a) * R, 0, math.sin(a) * R))
		attach(h, blob("Fill", Vector3.new(0.24, 0.1, 0.24), (item.color :: Color3):Lerp(C(150, 90, 35), 0.35)), CFrame.new(math.cos(a) * R, 0.09, math.sin(a) * R)) -- glossy dark top
	end
	for k = 0, 13 do -- sesame on top
		local a = k * 2 * math.pi / 14 + 0.2
		local rr = R + (if k % 2 == 0 then 0.06 else -0.06)
		attach(h, part("Sesame", Vector3.new(0.04, 0.02, 0.025), C(245, 235, 210)), CFrame.new(math.cos(a) * rr, 0.14, math.sin(a) * rr) * CFrame.Angles(0, a, 0))
	end
	return h, CFrame.new(0, 0, 0)
end

B.croissant = function(item)
	local h = newHandle(Vector3.new(0.5, 0.3, 0.8))
	local crust = item.color :: Color3
	local dark = crust:Lerp(C(150, 85, 30), 0.35)
	-- a crescent: segments along Z, bending to -X at the ends, split in two
	for i = -2, 2 do
		local s = ({ [0] = 1, [1] = 0.84, [2] = 0.64 })[math.abs(i)]
		local x = -0.06 * i * i
		local z = i * 0.21
		attach(h, blob("Fill", Vector3.new(0.5 * s, 0.2 * s, 0.3 * s), crust), CFrame.new(x, -0.1 * s, z))
		attach(h, blob("Fill", Vector3.new(0.5 * s, 0.24 * s, 0.3 * s), dark), CFrame.new(x, 0.12 * s, z))
	end
	-- cream and strawberry halves between the halves, showing at the side
	attach(h, blob("Cream", Vector3.new(0.46, 0.12, 0.78), WHITE), CFrame.new(0.03, 0.01, 0))
	for _, z in ipairs({ -0.2, 0, 0.2 }) do
		attach(h, blob("Berry", Vector3.new(0.16, 0.14, 0.14), STRAWBERRY), CFrame.new(0.2, 0.01, z))
		attach(h, blob("Berry", Vector3.new(0.08, 0.1, 0.08), C(255, 200, 205)), CFrame.new(0.27, 0.01, z)) -- the pale cut face
	end
	return h, CFrame.new(0, 0, 0)
end

B.honeybread = function(item)
	local h = part("Handle", Vector3.new(1, 0.05, 1), C(250, 250, 250)) -- the plate
	local toast, crumb = item.color :: Color3, C(245, 220, 165)
	attach(h, part("Fill", Vector3.new(0.72, 0.6, 0.72), toast), CFrame.new(0, 0.33, 0))
	attach(h, part("Fill", Vector3.new(0.64, 0.02, 0.64), crumb), CFrame.new(0, 0.635, 0))
	for _, d in ipairs({ -0.16, 0, 0.16 }) do -- scored in a grid
		attach(h, part("Score", Vector3.new(0.64, 0.025, 0.025), toast:Lerp(C(120, 70, 30), 0.4)), CFrame.new(0, 0.645, d))
		attach(h, part("Score", Vector3.new(0.025, 0.025, 0.64), toast:Lerp(C(120, 70, 30), 0.4)), CFrame.new(d, 0.645, 0))
	end
	attach(h, blob("Cream", Vector3.new(0.5, 0.34, 0.5), WHITE), CFrame.new(0.04, 0.78, -0.03))
	attach(h, blob("Cream", Vector3.new(0.3, 0.24, 0.3), WHITE), CFrame.new(0.06, 0.95, -0.04))
	local CARAMEL = C(175, 105, 40)
	-- drizzle: zigzag lines over the cream (short, they follow its dome) and
	-- longer ones across the toast top
	for k, a in ipairs({ 25, -25, 25, -25 }) do
		attach(h, part("Caramel", Vector3.new(0.34, 0.025, 0.035), CARAMEL), CFrame.new(0, 0.93, -0.12 + (k - 1) * 0.08) * CFrame.Angles(0, math.rad(a), 0))
	end
	for k, a in ipairs({ 35, -35 }) do
		attach(h, part("Caramel", Vector3.new(0.62, 0.02, 0.035), CARAMEL), CFrame.new(0, 0.66, (k - 1.5) * 0.36) * CFrame.Angles(0, math.rad(a), 0))
	end
	for _, x in ipairs({ -0.36, 0.36 }) do -- drips down the sides
		attach(h, part("Caramel", Vector3.new(0.03, 0.22, 0.04), CARAMEL), CFrame.new(x, 0.52, 0.1))
	end
	for _, v in ipairs(scatter(5, 7)) do -- sliced almonds
		attach(h, blob("Almond", Vector3.new(0.1, 0.025, 0.07), C(235, 210, 160)), CFrame.new(v.X * 0.2, 1.0 + v.Y * 0.03, v.Y * 0.18))
	end
	return h, CFrame.new(0, -0.05, 0)
end

B.parfait = function(item)
	local h = newHandle(Vector3.new(0.5, 0.6, 0.5))
	local glass = cyl("Glass", 0.6, 1.25, C(245, 250, 255), Enum.Material.Glass)
	glass.Transparency = 0.55
	attach(h, glass, UP)
	local stem = cyl("Glass", 0.16, 0.22, C(245, 250, 255), Enum.Material.Glass)
	stem.Transparency = 0.3
	attach(h, stem, CFrame.new(0, -0.73, 0) * UP)
	local foot = cyl("Glass", 0.46, 0.04, C(245, 250, 255), Enum.Material.Glass)
	foot.Transparency = 0.3
	attach(h, foot, CFrame.new(0, -0.85, 0) * UP)
	-- layers from the bottom: granola, cream, strawberry, cream
	for _, l in ipairs({ { -0.5, 0.2, C(175, 120, 60) }, { -0.3, 0.2, CREAM }, { -0.1, 0.2, item.color }, { 0.1, 0.2, CREAM }, { 0.3, 0.2, (item.color :: Color3):Lerp(STRAWBERRY, 0.5) } }) do
		attach(h, cyl("Fill", 0.53, l[2], l[3]), CFrame.new(0, l[1], 0) * UP)
	end
	-- whipped cream swirl, strawberry halves round it, a whole one on top
	attach(h, blob("Cream", Vector3.new(0.56, 0.24, 0.56), WHITE), CFrame.new(0, 0.66, 0))
	attach(h, blob("Cream", Vector3.new(0.4, 0.22, 0.4), WHITE), CFrame.new(0, 0.82, 0))
	attach(h, blob("Cream", Vector3.new(0.22, 0.18, 0.22), WHITE), CFrame.new(0, 0.96, 0))
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3
		attach(h, blob("Berry", Vector3.new(0.2, 0.24, 0.12), STRAWBERRY), CFrame.new(math.cos(a) * 0.24, 0.74, math.sin(a) * 0.24) * CFrame.Angles(0, -a, 0))
	end
	attach(h, blob("Berry", Vector3.new(0.22, 0.26, 0.22), STRAWBERRY), CFrame.new(0, 1.12, 0))
	attach(h, part("Hull", Vector3.new(0.16, 0.03, 0.16), LEAF), CFrame.new(0, 1.25, 0) * CFrame.Angles(0, math.rad(45), 0))
	attach(h, part("Wafer", Vector3.new(0.08, 0.5, 0.08), C(225, 180, 110)), CFrame.new(-0.15, 1.0, 0.08) * CFrame.Angles(0, 0, math.rad(18)))
	attach(h, part("Mint", Vector3.new(0.12, 0.02, 0.08), C(80, 170, 80)), CFrame.new(0.12, 0.95, -0.12) * CFrame.Angles(0, math.rad(30), 0))
	return h, CFrame.new(0, -0.2, 0)
end

B.yakgwa = function(item)
	local h = newHandle(Vector3.new(0.5, 0.2, 0.5))
	local glaze = item.color :: Color3
	local core = attach(h, cyl("Fill", 0.46, 0.16, glaze), UP) :: BasePart
	core.Reflectance = 0.12
	for k = 0, 7 do -- the flower petals
		local a = k * math.pi / 4
		local p = attach(h, blob("Fill", Vector3.new(0.2, 0.16, 0.2), glaze), CFrame.new(math.cos(a) * 0.24, 0, math.sin(a) * 0.24))
		p.Reflectance = 0.12
	end
	attach(h, cyl("Fill", 0.28, 0.02, glaze:Lerp(C(90, 45, 15), 0.4)), CFrame.new(0, 0.08, 0) * UP) -- the pressed ring
	attach(h, blob("PineNut", Vector3.new(0.07, 0.04, 0.11), C(240, 225, 190)), CFrame.new(0, 0.1, 0))
	return h, CFrame.new(0, 0, 0)
end

B.injeolmi = function(item)
	local h = newHandle(Vector3.new(0.6, 0.3, 0.8))
	local CRUST, CRUMB = C(185, 125, 60), C(240, 215, 160)
	attach(h, part("Fill", Vector3.new(0.78, 0.12, 0.78), CRUST), CFrame.new(0, -0.12, 0))
	attach(h, blob("Fill", Vector3.new(0.82, 0.1, 0.82), C(242, 232, 205)), CFrame.new(0, -0.02, 0)) -- the soft rice cake squeezing out
	attach(h, part("Fill", Vector3.new(0.78, 0.12, 0.78), CRUST), CFrame.new(0, 0.08, 0))
	attach(h, part("Fill", Vector3.new(0.7, 0.02, 0.7), CRUMB), CFrame.new(0, 0.145, 0))
	attach(h, part("Powder", Vector3.new(0.72, 0.03, 0.72), item.color), CFrame.new(0, 0.165, 0)) -- roasted bean powder
	for _, v in ipairs(scatter(7, 3)) do -- almond slices
		attach(h, blob("Almond", Vector3.new(0.12, 0.02, 0.08), C(240, 220, 175)), CFrame.new(v.X * 0.28, 0.19, v.Y * 0.28) * CFrame.Angles(0, v.X * 2, 0))
	end
	for k, a in ipairs({ 30, -30, 80 }) do -- honey
		attach(h, part("Honey", Vector3.new(0.7, 0.015, 0.03), C(245, 175, 40)), CFrame.new(0, 0.2, (k - 2) * 0.14) * CFrame.Angles(0, math.rad(a), 0))
	end
	return h, CFrame.new(0, 0, 0)
end

---------------------------------------------------------------- OH24

B.water = function(item)
	local h = newHandle(Vector3.new(0.4, 0.8, 0.4))
	local CLEAR, BLUE = C(240, 246, 252), C(40, 110, 210)
	local body = attach(h, cyl("Glass", 0.42, 0.78, CLEAR, Enum.Material.Glass), CFrame.new(0, -0.07, 0) * UP) :: BasePart
	body.Transparency = 0.45
	local shoulder = attach(h, blob("Glass", Vector3.new(0.42, 0.3, 0.42), CLEAR, Enum.Material.Glass), CFrame.new(0, 0.32, 0)) :: BasePart
	shoulder.Transparency = 0.45
	attach(h, cyl("Fill", 0.36, 0.72, item.color), CFrame.new(0, -0.08, 0) * UP)
	for _, y in ipairs({ -0.36, -0.26, 0.24 }) do attach(h, cyl("Band", 0.43, 0.025, C(225, 235, 245)), CFrame.new(0, y, 0) * UP) end -- ridges
	attach(h, cyl("Band", 0.435, 0.16, BLUE), CFrame.new(0, 0.02, 0) * UP)
	attach(h, cyl("Band", 0.44, 0.04, WHITE), CFrame.new(0, -0.08, 0) * UP)
	attach(h, cyl("Cap", 0.2, 0.08, CLEAR), CFrame.new(0, 0.48, 0) * UP)
	attach(h, cyl("Cap", 0.22, 0.1, BLUE), CFrame.new(0, 0.56, 0) * UP)
	return h, CFrame.new(0, -0.15, 0)
end

-- 바나나맛우유 (user photo 2026-10-27, docs/04_ART/textures/bananamilk_label.png):
-- a pale yellow cup-shaped lower half, a lip, the round printed shoulder
-- narrowing to the neck, a green cap
local MILK_LABEL = "rbxassetid://136037579727377"
B.bananamilk = function(item)
	local h = newHandle(Vector3.new(0.45, 0.7, 0.45))
	local jar = C(252, 236, 150)
	-- the lower cup, widening a little to the lip (short, user 2026-10-27)
	attach(h, cyl("Cup", 0.5, 0.03, jar:Lerp(C(230, 200, 100), 0.3)), CFrame.new(0, -0.215, 0) * UP)
	attach(h, cyl("Cup", 0.52, 0.11, jar), CFrame.new(0, -0.15, 0) * UP)
	attach(h, cyl("Cup", 0.55, 0.1, jar), CFrame.new(0, -0.05, 0) * UP)
	attach(h, cyl("Cup", 0.6, 0.04, jar:Lerp(WHITE, 0.35)), CFrame.new(0, 0, 0) * UP) -- the lip
	-- the printed shoulder in three bands, one picture across them
	-- (top band first: the picture's top row goes on the top band)
	local bands = { { 0.25, 0.32, 0.21, 0.15 }, { 0.14, 0.25, 0.27, 0.21 }, { 0.02, 0.14, 0.29, 0.27 } }
	local total = 0
	for _, b in ipairs(bands) do total += math.sqrt((b[2] - b[1]) ^ 2 + (b[4] - b[3]) ^ 2) end
	local v = 0
	for _, b in ipairs(bands) do
		v += wrap(h, b[1], b[2], b[3], b[4], 16, MILK_LABEL, v, total)
	end
	attach(h, cyl("Cap", 0.28, 0.06, jar), CFrame.new(0, 0.34, 0) * UP) -- the neck
	attach(h, cyl("Cap", 0.32, 0.06, C(30, 110, 55)), CFrame.new(0, 0.39, 0) * UP) -- green cap
	attach(h, cyl("Lid", 0.3, 0.01, C(45, 130, 70), Enum.Material.Foil), CFrame.new(0, 0.425, 0) * UP)
	attach(h, part("Straw", Vector3.new(0.05, 0.42, 0.05), C(250, 250, 250)), CFrame.new(0.06, 0.58, 0) * CFrame.Angles(0, 0, math.rad(-12)))
	return h, CFrame.new(0, -0.1, 0)
end
B.soda = function(item)
	local h = newHandle(Vector3.new(0.42, 0.8, 0.42))
	local SILVER = C(205, 208, 214)
	attach(h, cyl("Cup", 0.42, 0.7, item.color, Enum.Material.Metal), UP)
	attach(h, cyl("Cap", 0.37, 0.07, SILVER, Enum.Material.Metal), CFrame.new(0, 0.385, 0) * UP)
	attach(h, cyl("Cap", 0.36, 0.05, SILVER, Enum.Material.Metal), CFrame.new(0, -0.375, 0) * UP)
	attach(h, cyl("Band", 0.425, 0.06, WHITE), CFrame.new(0, -0.04, 0) * UP)
	attach(h, cyl("Band", 0.425, 0.025, WHITE), CFrame.new(0, 0.06, 0) * UP)
	attach(h, part("Cap", Vector3.new(0.12, 0.012, 0.07), SILVER, Enum.Material.Metal), CFrame.new(0, 0.425, -0.05)) -- ring pull
	return h, CFrame.new(0, -0.1, 0)
end

B.icebar = function(item)
	local h = part("Handle", Vector3.new(0.12, 0.6, 0.06), C(225, 195, 140), Enum.Material.Wood) -- the stick
	local pink, choco = item.color :: Color3, (item.topping or C(110, 70, 45)) :: Color3
	-- a flat bar with a round top (a cylinder lying front to back)
	attach(h, part("Fill", Vector3.new(0.42, 0.62, 0.22), pink), CFrame.new(0, 0.6, 0))
	attach(h, part("Fill", Vector3.new(0.22, 0.42, 0.42), pink, nil, Enum.PartType.Cylinder), CFrame.new(0, 0.91, 0) * CFrame.Angles(0, math.rad(90), 0))
	-- dipped in chocolate over the top two thirds, crunch bits stuck on
	attach(h, part("Dip", Vector3.new(0.445, 0.4, 0.245), choco), CFrame.new(0, 0.72, 0))
	local top = part("Dip", Vector3.new(0.245, 0.445, 0.445), choco, nil, Enum.PartType.Cylinder)
	attach(h, top, CFrame.new(0, 0.91, 0) * CFrame.Angles(0, math.rad(90), 0))
	for _, v in ipairs(scatter(14, 5)) do
		local side = if v.X > 0 then 1 else -1
		attach(h, part("Crunch", Vector3.new(0.05, 0.04, 0.04), C(200, 150, 90)), CFrame.new(v.Y * 0.18, 0.62 + math.abs(v.X) * 0.38, side * 0.125))
	end
	return h, CFrame.new(0, -0.15, 0)
end

B.chips = function(item)
	local h = newHandle(Vector3.new(0.7, 0.9, 0.25))
	local bag = item.color :: Color3
	attach(h, part("Bag", Vector3.new(0.72, 0.84, 0.16), bag), CFrame.new(0, -0.04, 0))
	attach(h, blob("Bag", Vector3.new(0.7, 0.8, 0.3), bag), CFrame.new(0, -0.04, 0)) -- puffed with air
	attach(h, part("Seam", Vector3.new(0.76, 0.08, 0.06), bag:Lerp(C(120, 90, 30), 0.3)), CFrame.new(0, -0.47, 0)) -- crimped bottom
	for _, s in ipairs({ -1, 1 }) do -- the torn-open top
		attach(h, part("Bag", Vector3.new(0.72, 0.14, 0.025), bag), CFrame.new(0, 0.42, s * 0.07) * CFrame.Angles(math.rad(s * 14), 0, 0))
	end
	attach(h, part("Label", Vector3.new(0.6, 0.15, 0.02), C(215, 40, 40)), CFrame.new(0, 0.14, -0.155))
	attach(h, blob("Label", Vector3.new(0.34, 0.2, 0.02), C(255, 235, 150)), CFrame.new(0, -0.15, -0.155))
	for k, v in ipairs(scatter(6, 9)) do -- chips poking out
		attach(h, blob("Fill", Vector3.new(0.22, 0.035, 0.18), C(240, 200, 95)), CFrame.new(v.X * 0.2, 0.42 + (k % 3) * 0.05, v.Y * 0.04) * CFrame.Angles(math.rad(v.Y * 15), 0, math.rad(v.X * 18)))
	end
	return h, CFrame.new(0, -0.2, 0)
end

B.chocosnack = function(item)
	local h = newHandle(Vector3.new(0.5, 0.85, 0.15))
	local box = item.color :: Color3
	attach(h, part("Box", Vector3.new(0.5, 0.7, 0.14), box), CFrame.new(0, -0.1, 0))
	attach(h, part("Box", Vector3.new(0.5, 0.18, 0.02), box), CFrame.new(0, 0.32, 0.08) * CFrame.Angles(math.rad(25), 0, 0)) -- the lid, open
	attach(h, part("Label", Vector3.new(0.4, 0.14, 0.02), WHITE), CFrame.new(0, 0.02, -0.075))
	attach(h, part("Label", Vector3.new(0.4, 0.04, 0.02), C(110, 60, 35)), CFrame.new(0, -0.08, -0.075))
	for i, x in ipairs({ -0.15, -0.05, 0.05, 0.15 }) do
		local tilt = CFrame.Angles(0, 0, math.rad(x * -40))
		attach(h, part("Stick", Vector3.new(0.07, 0.3, 0.07), C(225, 185, 120)), CFrame.new(x, 0.12, -0.01) * tilt) -- bare biscuit end
		attach(h, part("Fill", Vector3.new(0.075, 0.5 - (i % 2) * 0.06, 0.075), C(85, 48, 32)), CFrame.new(x - x * 0.12, 0.5 - (i % 2) * 0.03, -0.01) * tilt) -- chocolate
	end
	return h, CFrame.new(0, -0.2, 0)
end

B.samgak = function(item)
	local h = newHandle(Vector3.new(0.3, 0.8, 0.8))
	local w = Instance.new("WedgePart")
	w.Name = "Fill"
	w.Size = Vector3.new(0.3, 0.78, 0.42)
	w.Color = item.color
	w.Material = Enum.Material.Sand -- rice grains
	w.CanCollide, w.CanQuery, w.CanTouch, w.Massless, w.CastShadow = false, false, false, true, false
	attach(h, w, CFrame.new(0, 0, -0.21))
	attach(h, w:Clone(), CFrame.new(0, 0, 0.21) * CFrame.Angles(0, math.rad(180), 0))
	-- laver wrapped round the lower half: both faces and the bottom
	for _, s in ipairs({ -1, 1 }) do
		attach(h, part("Laver", Vector3.new(0.02, 0.36, 0.78), C(28, 40, 30), Enum.Material.Fabric), CFrame.new(s * 0.16, -0.21, 0))
	end
	attach(h, part("Laver", Vector3.new(0.34, 0.02, 0.84), C(28, 40, 30), Enum.Material.Fabric), CFrame.new(0, -0.4, 0))
	attach(h, blob("Filling", Vector3.new(0.12, 0.08, 0.12), C(230, 120, 70)), CFrame.new(0, 0.2, 0)) -- a peek of the filling
	return h, CFrame.new(0, -0.1, 0)
end

-- 육개장 큰사발 style cup (user photo 2026-10-27, docs/04_ART/textures/
-- cupnoodle_wrap.png / _lid.png): the printed wrap round a tapered cup, the
-- lid peeled back standing behind, broth, noodles, chopsticks
local CUP_WRAP, CUP_LID = "rbxassetid://78201129469644", "rbxassetid://81588830533447"
B.cupnoodle = function(item)
	local h = newHandle(Vector3.new(0.5, 0.5, 0.5))
	wrap(h, -0.3, 0.26, 0.3, 0.39, 16, CUP_WRAP)
	attach(h, cyl("Cup", 0.58, 0.54, C(240, 238, 232)), CFrame.new(0, -0.03, 0) * UP) -- inside / behind the panels
	attach(h, cyl("Cup", 0.6, 0.02, C(250, 250, 248)), CFrame.new(0, -0.3, 0) * UP)
	attach(h, cyl("Cup", 0.8, 0.035, C(250, 250, 248)), CFrame.new(0, 0.27, 0) * UP) -- the rim
	-- the lid, peeled back and standing up at the back, its print to the front
	local lid = part("Lid", Vector3.new(0.015, 0.74, 0.74), C(250, 250, 250), nil, Enum.PartType.Cylinder)
	attach(h, lid, CFrame.new(0, 0.6, 0.42) * CFrame.Angles(math.rad(-20), math.rad(90), 0))
	local d = Instance.new("Decal")
	d.Texture = CUP_LID
	d.Face = Enum.NormalId.Right -- (the print faces the cup)
	d.Parent = lid
	attach(h, cyl("Fill", 0.7, 0.03, C(215, 90, 35)), CFrame.new(0, 0.22, 0) * UP) -- the broth
	for _, v in ipairs(scatter(8, 21)) do -- noodles and green onion
		attach(h, blob("Noodle", Vector3.new(0.2, 0.035, 0.12), C(245, 215, 130)), CFrame.new(v.X * 0.22, 0.245, v.Y * 0.22) * CFrame.Angles(0, v.X * 3, 0))
	end
	for _, v in ipairs(scatter(5, 22)) do
		attach(h, part("Onion", Vector3.new(0.05, 0.02, 0.05), C(90, 170, 70)), CFrame.new(v.X * 0.24, 0.255, v.Y * 0.24))
	end
	for _, dz in ipairs({ -0.03, 0.03 }) do
		attach(h, part("Chopsticks", Vector3.new(0.035, 0.9, 0.035), C(205, 175, 125), Enum.Material.Wood), CFrame.new(0.12, 0.5, dz) * CFrame.Angles(0, 0, math.rad(-25)))
	end
	return h, CFrame.new(0, -0.15, 0)
end
-- Creator Store models the user picked (2026-10-27, candidate sheet
-- docs/04_ART/references/food_store_candidates_2026-10-27.png; scripts
-- stripped; kept in ServerStorage.ArtAssets.Foods, so save the place). Each is
-- scaled so its longest side is the given size. A mesh cannot be cut, so these
-- shrink a little with every bite (EatMode = "Scale").
local ASSET_FOODS: {[string]: {any}} = {
	-- 국밥 (user picks 2026-10-27: #1 / #3 / #4, one per kind; on a table the
	-- tray set #2, GukbapTray, see SnackService.putDown)
	pork = { "GukbapPork", 1.0 },
	sundae = { "GukbapSundae", 1.0 },
	beef = { "GukbapBeef", 1.0 },
	saltbread = { "SaltBread", 0.8 }, -- AI mesh from the user's photo (2026-10-27)
	water = { "Samdasu", 0.95 },      -- user's pick (삼다수 by thuxjibuy)
	bagel = { "Bagel", 0.75 },       -- #7
	croissant = { "Croissant", 1.0 }, -- #8
	injeolmi = { "Toast", 0.8, CFrame.Angles(0, 0, math.rad(90)) }, -- #17, laid flat in the hand
	yakgwa = { "Cookie", 0.7 },       -- #20
	samgak = { "Onigiri", 0.75 },     -- #23
	chips = { "Chips", 0.95 },        -- #32
	soda = { "Can", 0.8 },            -- #36
	icebar = { "IceBar", 1.1 },       -- #42
	chocosnack = { "Pepero", 0.9 },   -- #51
}
local function fromAsset(item: any): (Part?, CFrame?)
	local spec = ASSET_FOODS[item.key]
	local art = spec and game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local folder = art and art:FindFirstChild("Foods")
	local src = folder and folder:FindFirstChild(spec[1] :: string)
	if not src then return nil, nil end
	local m = src:Clone()
	local holder = Instance.new("Model")
	if m:IsA("Model") then holder = m else m.Parent = holder end
	if spec[3] then holder:PivotTo(holder:GetPivot() * spec[3]) end -- (turned to how it is held)
	local _, size = holder:GetBoundingBox()
	holder:ScaleTo(holder:GetScale() * (spec[2] :: number) / math.max(size.X, size.Y, size.Z))
	local cf = holder:GetBoundingBox()
	local h = newHandle(Vector3.new(0.3, 0.3, 0.3))
	h.CFrame = CFrame.new(cf.Position)
	for _, p in ipairs(holder:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
			for _, j in ipairs(p:GetChildren()) do if j:IsA("JointInstance") or j:IsA("WeldConstraint") then j:Destroy() end end
			local offset = h.CFrame:ToObjectSpace(p.CFrame)
			attach(h, p, offset)
			p:SetAttribute("EatSize0", p.Size)
			p:SetAttribute("EatC00", offset)
		end
	end
	holder:Destroy()
	h.CFrame = CFrame.new()
	return h, CFrame.new(0, 0, 0)
end

-- the builder for a menu item (item keys are unique across the shops except
-- "water": a cup in the cafes and the 국밥집, the bottle only at OH24)
local function builderFor(item: any): Builder?
	if item.key == "water" and item.kind ~= "bottle" then return nil end
	return B[item.key]
end

function FoodShapes.build(item: any): (Part?, CFrame?, string?)
	if not (item.key == "water" and item.kind ~= "bottle") and ASSET_FOODS[item.key] then -- (cafe water is a cup)
		local h, grip = fromAsset(item)
		if h then return h, grip, "Scale" end -- (falls back to the part model when the asset is missing)
	end
	local builder = builderFor(item)
	if not builder then return nil, nil, nil end
	local handle, grip = builder(item)
	return handle, grip, if FoodShapes.AlongZ[item.key] then "Z" else nil
end

return FoodShapes
