--!strict
-- Club drink bottles (user's reference sheet 2026-10-27,
-- docs/04_ART/references/club_bottles_*.webp): each drink copies the
-- silhouette of a real bottle, built from stacked cylinder slices. No brand
-- names, logos or text: our own emblems (star, leaf, crown, skull, X). The
-- drinks stay sodas (D-043); the user asked for these shapes on 2026-10-27.
--
--   PET (삼다수 / 칠성 사이다)  물, 사이다, 콜라, 오렌지 소다, 레몬에이드, 블루에이드
--   round shoulder (앱솔루트)   진저 브루, 몬테 스파클링, 프렌치 레모네이드, 골든 애플
--   slim frosted (쿠엘보 모히또) 쨍팝 (3 flavours)
--   square (잭다니엘 허니)       핫부스트, 그린 클로, 블루 윙
--   barrel, long neck (아그와)   스택 하이드로
--   frosted cylinder (X레이티드) 파스텔 스플래시
--   teardrop (타이쿠)            스컬 캔 워터
--   metallic champagne (아르망 드 브리냑) 골목 공방 소다 (4 flavours)
--
-- BottleShapes.add(parent, base, key, color, scale, weldTo?) builds one bottle
-- with its bottom centre at `base` (front = base.LookVector). At scale 1 they
-- are 2 to 2.5 studs tall. Parts are anchored, or welded to `weldTo` (tools).

local BottleShapes = {}

local WHITE = Color3.fromRGB(250, 250, 248)
local BLACK = Color3.fromRGB(20, 20, 22)
local GOLD = Color3.fromRGB(214, 172, 70)
local SILVER = Color3.fromRGB(200, 204, 210)

type Ctx = { parent: Instance, base: CFrame, s: number, weld: BasePart?, parts: {BasePart} }

local function make(c: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, transparency: number?, reflectance: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Reflectance = reflectance or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	if c.weld then
		p.Anchored = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = c.weld
		w.Part1 = p
		w.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = c.parent
	table.insert(c.parts, p)
	return p
end

type Look = { color: Color3, material: Enum.Material?, transparency: number?, reflectance: number? }

-- upright cylinder from y0 to y1 (bottle units), diameter d
local function cyl(c: Ctx, name: string, y0: number, y1: number, d: number, look: Look): Part
	local s = c.s
	return make(c, name, Vector3.new((y1 - y0) * s, d * s, d * s), c.base * CFrame.new(0, (y0 + y1) / 2 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), look.color, look.material, Enum.PartType.Cylinder, look.transparency, look.reflectance)
end

-- a smooth change of diameter: `ds` = the diameters of the slices, evenly
-- from y0 to y1 (one slice each)
local function slices(c: Ctx, name: string, y0: number, y1: number, ds: {number}, look: Look)
	local h = (y1 - y0) / #ds
	for i, d in ipairs(ds) do
		cyl(c, name, y0 + (i - 1) * h, y0 + i * h + 0.004, d, look)
	end
end

-- a flat piece on the bottle's front face at height y (bottle units), r = the
-- bottle radius there; size in bottle units (x across, y up)
local function front(c: Ctx, name: string, y: number, r: number, w: number, h: number, color: Color3, material: Enum.Material?, rot: number?): Part
	local s = c.s
	return make(c, name, Vector3.new(w * s, h * s, 0.03 * s), c.base * CFrame.new(0, y * s, -(r + 0.012) * s) * CFrame.Angles(0, 0, math.rad(rot or 0)), color, material)
end

local function frontBall(c: Ctx, name: string, x: number, y: number, r: number, d: number, color: Color3, material: Enum.Material?): Part
	local s = c.s
	return make(c, name, Vector3.new(d * s, d * s, d * s), c.base * CFrame.new(x * s, y * s, -r * s), color, material, Enum.PartType.Ball)
end

-- (opaque: see-through slices overlap and draw dark rings at every seam)
local function glass(color: Color3, _t: number?): Look
	return { color = color, material = Enum.Material.SmoothPlastic, transparency = 0, reflectance = 0.03 } -- (more washed the colours out under the club lights)
end

--------------------------------------------------------------------------------
-- shapes

-- 칠성 사이다 / 삼다수 PET: petal foot, a waist, a label band, sloped shoulder
local function pet(c: Ctx, color: Color3, label: Color3, cap: Color3, ridged: boolean)
	local body = glass(color, if ridged then 0.45 else 0.25)
	cyl(c, "BottleFoot", 0, 0.1, 0.55, body)
	cyl(c, "BottleBody", 0.1, 0.62, 0.62, body)
	cyl(c, "BottleWaist", 0.62, 0.78, 0.55, body)
	cyl(c, "BottleLabel", 0.78, 1.18, 0.64, { color = label })
	cyl(c, "BottleBody", 1.18, 1.34, 0.62, body)
	slices(c, "BottleShoulder", 1.34, 1.74, { 0.58, 0.48, 0.36 }, body)
	cyl(c, "BottleRing", 1.74, 1.78, 0.36, { color = cap })
	cyl(c, "BottleCap", 1.78, 1.98, 0.32, { color = cap })
	if ridged then -- 삼다수: rings in the plastic
		for _, y in ipairs({ 0.28, 0.44, 1.26 }) do cyl(c, "BottleRidge", y, y + 0.03, 0.65, { color = color:Lerp(WHITE, 0.5) }) end
	end
end

-- 앱솔루트: a straight wide body, a short round shoulder, a short neck
local function roundShoulder(c: Ctx, color: Color3, band: Color3, cap: Color3)
	local body = glass(color, 0.15)
	cyl(c, "BottleBody", 0, 1.25, 0.76, body)
	slices(c, "BottleShoulder", 1.25, 1.47, { 0.74, 0.66, 0.52, 0.34 }, body)
	cyl(c, "BottleNeck", 1.47, 1.7, 0.24, body) -- (a short neck like the reference)
	cyl(c, "BottleLip", 1.7, 1.75, 0.3, body)
	cyl(c, "BottleCap", 1.75, 1.9, 0.28, { color = cap, material = Enum.Material.Metal })
	-- the printed band (no paper label on this bottle)
	cyl(c, "BottlePrint", 0.55, 0.85, 0.775, { color = band })
end

-- 쿠엘보 모히또: tall and slim, frosted, a long gentle shoulder
local function slim(c: Ctx, color: Color3)
	local body = { color = color:Lerp(WHITE, 0.25), material = Enum.Material.SmoothPlastic, transparency = 0 }
	cyl(c, "BottleBody", 0, 1.42, 0.5, body)
	slices(c, "BottleShoulder", 1.42, 1.72, { 0.46, 0.36, 0.27 }, body)
	cyl(c, "BottleNeck", 1.72, 2.08, 0.22, body)
	cyl(c, "BottleCap", 2.08, 2.24, 0.25, { color = SILVER, material = Enum.Material.Metal })
	cyl(c, "BottleLabel", 0.62, 1.02, 0.51, { color = color:Lerp(WHITE, 0.65) })
	front(c, "Leaf", 0.82, 0.255, 0.12, 0.22, color:Lerp(BLACK, 0.3), nil, 35)
	front(c, "Leaf", 0.82, 0.255, 0.12, 0.22, color:Lerp(BLACK, 0.3), nil, -35)
end

-- 잭다니엘 허니: a square body, a stepped square shoulder, a long neck, a tall black cap
local function square(c: Ctx, color: Color3, label: Color3, labelEdge: Color3)
	local s = c.s
	local body = glass(color, 0.15)
	make(c, "BottleBody", Vector3.new(0.66 * s, 1.1 * s, 0.66 * s), c.base * CFrame.new(0, 0.55 * s, 0), body.color, body.material, nil, body.transparency, body.reflectance)
	make(c, "BottleShoulder", Vector3.new(0.56 * s, 0.1 * s, 0.56 * s), c.base * CFrame.new(0, 1.15 * s, 0), body.color, body.material, nil, body.transparency, body.reflectance)
	make(c, "BottleShoulder", Vector3.new(0.42 * s, 0.1 * s, 0.42 * s), c.base * CFrame.new(0, 1.25 * s, 0), body.color, body.material, nil, body.transparency, body.reflectance)
	cyl(c, "BottleNeck", 1.3, 1.72, 0.22, body)
	cyl(c, "BottleCap", 1.72, 1.98, 0.27, { color = BLACK })
	-- the label on the front face (and a small one on the neck)
	front(c, "LabelEdge", 0.55, 0.33, 0.54, 0.5, labelEdge)
	front(c, "Label", 0.55, 0.345, 0.46, 0.42, label)
	front(c, "NeckLabel", 1.48, 0.11, 0.18, 0.14, label)
end

-- 아그와: a slightly barrel body, a long tapered shoulder, a long neck with a band
local function barrel(c: Ctx, color: Color3)
	local body = glass(color, 0.12)
	slices(c, "BottleFoot", 0, 0.12, { 0.52, 0.58 }, body)
	cyl(c, "BottleBody", 0.12, 1.07, 0.6, body)
	slices(c, "BottleShoulder", 1.07, 1.5, { 0.56, 0.46, 0.34, 0.24 }, body)
	cyl(c, "BottleNeck", 1.5, 2, 0.2, body)
	cyl(c, "NeckBand", 1.6, 1.7, 0.23, { color = Color3.fromRGB(200, 30, 40) })
	cyl(c, "BottleCap", 2, 2.22, 0.22, { color = BLACK })
	cyl(c, "BottleLabel", 0.42, 0.74, 0.61, { color = BLACK })
	front(c, "Leaf", 0.58, 0.305, 0.1, 0.22, color:Lerp(WHITE, 0.3), nil, 30)
	front(c, "Leaf", 0.58, 0.305, 0.1, 0.22, color:Lerp(WHITE, 0.3), nil, -30)
	front(c, "Leaf", 0.6, 0.305, 0.1, 0.24, color:Lerp(WHITE, 0.3))
end

-- X레이티드: a frosted straight cylinder, a round shoulder, a big X on the front
local function frostedCylinder(c: Ctx, color: Color3)
	local body = { color = color, material = Enum.Material.SmoothPlastic, transparency = 0 }
	cyl(c, "BottleBody", 0, 1.45, 0.62, body)
	slices(c, "BottleShoulder", 1.45, 1.65, { 0.58, 0.48, 0.34 }, body)
	cyl(c, "BottleNeck", 1.65, 1.84, 0.26, body)
	cyl(c, "BottleCap", 1.84, 1.98, 0.3, { color = SILVER, material = Enum.Material.Metal })
	local x = color:Lerp(WHITE, 0.55)
	front(c, "X", 0.85, 0.31, 0.07, 0.75, x, nil, 28)
	front(c, "X", 0.85, 0.31, 0.07, 0.75, x, nil, -28)
end

-- 타이쿠: a glossy teardrop, widest low down, narrowing all the way up
local function teardrop(c: Ctx, color: Color3)
	local body = { color = color, material = Enum.Material.SmoothPlastic, transparency = 0, reflectance = 0.1 }
	slices(c, "BottleBody", 0, 1.95, { 0.5, 0.6, 0.62, 0.6, 0.56, 0.5, 0.44, 0.37, 0.31, 0.26 }, body)
	cyl(c, "BottleCap", 1.95, 2.28, 0.26, { color = SILVER, material = Enum.Material.Metal, reflectance = 0.2 })
	-- small white skull: head, jaw, two eyes
	frontBall(c, "Skull", 0, 0.78, 0.29, 0.2, WHITE)
	front(c, "SkullJaw", 0.66, 0.3, 0.12, 0.08, WHITE)
	frontBall(c, "SkullEye", -0.04, 0.79, 0.37, 0.05, BLACK)
	frontBall(c, "SkullEye", 0.04, 0.79, 0.37, 0.05, BLACK)
end

-- 아르망 드 브리냑: a metallic champagne-shaped bottle, a long sloping shoulder,
-- a black foil top, a crown on the front (our emblem instead of their spade)
local function champagne(c: Ctx, color: Color3)
	local body = { color = color, material = Enum.Material.Metal, transparency = 0, reflectance = 0.15 }
	cyl(c, "BottlePunt", 0, 0.06, 0.6, body)
	cyl(c, "BottleBody", 0.06, 1.2, 0.64, body)
	slices(c, "BottleShoulder", 1.2, 1.76, { 0.62, 0.56, 0.46, 0.36, 0.28 }, body)
	cyl(c, "BottleNeck", 1.76, 1.96, 0.25, body)
	cyl(c, "Foil", 1.94, 2.42, 0.28, { color = BLACK, material = Enum.Material.Fabric })
	make(c, "FoilTop", Vector3.new(0.28 * c.s, 0.28 * c.s, 0.28 * c.s), c.base * CFrame.new(0, 2.42 * c.s, 0), BLACK, Enum.Material.Fabric, Enum.PartType.Ball)
	cyl(c, "NeckCrest", 1.78, 1.86, 0.27, { color = GOLD, material = Enum.Material.Foil })
	-- crown: a band and three points, a plate under it
	front(c, "CrownBand", 0.78, 0.32, 0.26, 0.07, GOLD, Enum.Material.Foil)
	for _, x in ipairs({ -0.1, 0, 0.1 }) do
		frontBall(c, "CrownPoint", x, 0.86 + (if x == 0 then 0.03 else 0), 0.325, 0.07, GOLD, Enum.Material.Foil)
	end
	front(c, "Plate", 0.48, 0.32, 0.34, 0.1, GOLD:Lerp(BLACK, 0.35), Enum.Material.Foil)
end

--------------------------------------------------------------------------------

local BUILDERS: {[string]: (Ctx, Color3) -> ()} = {
	water = function(c, col) pet(c, col, Color3.fromRGB(40, 110, 210), Color3.fromRGB(40, 110, 210), true) end,
	cider = function(c, col) pet(c, col, Color3.fromRGB(30, 150, 70), Color3.fromRGB(30, 150, 70), false) end,
	cola = function(c, col) pet(c, col, Color3.fromRGB(215, 30, 40), Color3.fromRGB(215, 30, 40), false) end,
	orange = function(c, col) pet(c, col, WHITE, col, false) end,
	lemonade = function(c, col) pet(c, col, WHITE, col, false) end,
	blueade = function(c, col) pet(c, col, WHITE, col, false) end,
	ginger_brew = function(c, col) roundShoulder(c, col, Color3.fromRGB(250, 230, 190), GOLD) end,
	monte = function(c, col)
		roundShoulder(c, col, WHITE, SILVER)
		-- the red star: two crossed diamonds
		front(c, "Star", 0.7, 0.385, 0.16, 0.16, Color3.fromRGB(215, 30, 40), nil, 45)
		front(c, "Star", 0.7, 0.39, 0.16, 0.16, Color3.fromRGB(215, 30, 40), nil, 0)
	end,
	french_lemonade = function(c, col)
		roundShoulder(c, col, Color3.fromRGB(70, 110, 190), WHITE)
		-- swing top: a white stopper and the wire
		for _, x in ipairs({ -0.15, 0.15 }) do
			make(c, "Wire", Vector3.new(0.025 * c.s, 0.3 * c.s, 0.025 * c.s), c.base * CFrame.new(x * c.s, 1.78 * c.s, 0), SILVER, Enum.Material.Metal)
		end
	end,
	golden_apple = function(c, col) roundShoulder(c, col, Color3.fromRGB(150, 30, 30), GOLD) end,
	zzang_pop = slim,
	hot_boost = function(c, col) square(c, col, BLACK, Color3.fromRGB(255, 200, 60)) end,
	green_claw = function(c, col) square(c, col, Color3.fromRGB(60, 220, 80), BLACK) end,
	blue_wing = function(c, col) square(c, col, SILVER, Color3.fromRGB(230, 40, 50)) end,
	stack_hydro = barrel,
	pastel_splash = frostedCylinder,
	skull_water = teardrop,
	golmok = champagne,
}

function BottleShapes.add(parent: Instance, base: CFrame, key: string, color: Color3, scale: number, weldTo: BasePart?): {BasePart}
	local c: Ctx = { parent = parent, base = base, s = scale, weld = weldTo, parts = {} }
	local builder = BUILDERS[key] or BUILDERS.cider
	builder(c, color)
	return c.parts
end

-- bottle heights at scale 1 (to fit a holder or a tool)
BottleShapes.Height = { ginger_brew = 1.9, monte = 1.9, french_lemonade = 1.9, golden_apple = 1.9, zzang_pop = 2.24, hot_boost = 1.98,
	green_claw = 1.98, blue_wing = 1.98, stack_hydro = 2.22, pastel_splash = 1.98, skull_water = 2.28, golmok = 2.56 }
function BottleShapes.height(key: string): number
	return BottleShapes.Height[key] or 1.98
end

return BottleShapes
