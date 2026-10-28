--!strict
-- Club drink bottles (user's reference sheet 2026-10-27,
-- docs/04_ART/references/club_bottles_*.webp): each drink copies the
-- silhouette of a real bottle: cylinders, and ellipsoids for the curves. No brand
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

-- a smooth ellipsoid (a block with a sphere mesh stretched to its size):
-- centre at height y, d wide, h tall. Shoulders are the top half of one sat
-- on the body, so the outline curves instead of stepping (user 2026-10-27:
-- the stacked slices looked like stairs).
local function ell(c: Ctx, name: string, y: number, d: number, h: number, look: Look): Part
	local s = c.s
	local p = make(c, name, Vector3.new(d * s, h * s, d * s), c.base * CFrame.new(0, y * s, 0), look.color, look.material, nil, look.transparency, look.reflectance)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
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
	ell(c, "BottleShoulder", 1.34, 0.62, 0.84, body)
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
	ell(c, "BottleShoulder", 1.25, 0.76, 0.5, body)
	cyl(c, "BottleNeck", 1.4, 1.7, 0.24, body) -- (a short neck like the reference)
	cyl(c, "BottleLip", 1.7, 1.75, 0.3, body)
	cyl(c, "BottleCap", 1.75, 1.9, 0.28, { color = cap, material = Enum.Material.Metal })
	-- the printed band (no paper label on this bottle)
	cyl(c, "BottlePrint", 0.55, 0.85, 0.775, { color = band })
end

-- 쿠엘보 모히또: tall and slim, frosted, a long gentle shoulder
local function slim(c: Ctx, color: Color3)
	local body = { color = color:Lerp(WHITE, 0.25), material = Enum.Material.SmoothPlastic, transparency = 0 }
	cyl(c, "BottleBody", 0, 1.42, 0.5, body)
	ell(c, "BottleShoulder", 1.42, 0.5, 0.64, body)
	cyl(c, "BottleNeck", 1.62, 2.08, 0.22, body)
	cyl(c, "BottleCap", 2.08, 2.24, 0.25, { color = SILVER, material = Enum.Material.Metal })
	cyl(c, "BottleLabel", 0.62, 1.02, 0.51, { color = color:Lerp(WHITE, 0.65) })
	front(c, "Leaf", 0.82, 0.255, 0.12, 0.22, color:Lerp(BLACK, 0.3), nil, 35)
	front(c, "Leaf", 0.82, 0.255, 0.12, 0.22, color:Lerp(BLACK, 0.3), nil, -35)
end

-- 잭다니엘 허니: a square body, a rounded shoulder, a long neck, a tall black cap
local function square(c: Ctx, color: Color3, label: Color3, labelEdge: Color3)
	local s = c.s
	local body = glass(color, 0.15)
	make(c, "BottleBody", Vector3.new(0.66 * s, 1.1 * s, 0.66 * s), c.base * CFrame.new(0, 0.55 * s, 0), body.color, body.material, nil, body.transparency, body.reflectance)
	ell(c, "BottleShoulder", 1.1, 0.66, 0.44, body)
	cyl(c, "BottleNeck", 1.25, 1.72, 0.22, body)
	cyl(c, "BottleCap", 1.72, 1.98, 0.27, { color = BLACK })
	-- the label on the front face (and a small one on the neck)
	front(c, "LabelEdge", 0.55, 0.33, 0.54, 0.5, labelEdge)
	front(c, "Label", 0.55, 0.345, 0.46, 0.42, label)
	front(c, "NeckLabel", 1.48, 0.11, 0.18, 0.14, label)
end

-- 아그와: a slightly barrel body, a long tapered shoulder, a long neck with a band
local function barrel(c: Ctx, color: Color3)
	local body = glass(color, 0.12)
	cyl(c, "BottleFoot", 0, 0.12, 0.56, body)
	cyl(c, "BottleBody", 0.12, 1.07, 0.6, body)
	ell(c, "BottleShoulder", 1.07, 0.6, 0.9, body)
	cyl(c, "BottleNeck", 1.4, 2, 0.2, body)
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
	ell(c, "BottleShoulder", 1.45, 0.62, 0.42, body)
	cyl(c, "BottleNeck", 1.58, 1.84, 0.26, body)
	cyl(c, "BottleCap", 1.84, 1.98, 0.3, { color = SILVER, material = Enum.Material.Metal })
	local x = color:Lerp(WHITE, 0.55)
	front(c, "X", 0.85, 0.31, 0.07, 0.75, x, nil, 28)
	front(c, "X", 0.85, 0.31, 0.07, 0.75, x, nil, -28)
end

-- 타이쿠: a glossy teardrop, widest low down, narrowing all the way up
local function teardrop(c: Ctx, color: Color3)
	local body = { color = color, material = Enum.Material.SmoothPlastic, transparency = 0, reflectance = 0.03 } -- (0.1 mirrored the whole sky on black)
	-- a round low bulge and a long narrow ellipsoid: the outline is the larger of the two
	cyl(c, "BottleFoot", 0, 0.06, 0.48, body)
	ell(c, "BottleBody", 0.55, 0.62, 1.1, body)
	ell(c, "BottleBody", 1, 0.56, 2, body)
	cyl(c, "BottleNeck", 1.72, 1.98, 0.26, body)
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
	ell(c, "BottleShoulder", 1.2, 0.64, 1.1, body)
	ell(c, "NeckFlare", 1.68, 0.34, 0.44, body)
	cyl(c, "BottleNeck", 1.6, 1.96, 0.25, body)
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

--------------------------------------------------------------------------------
-- The user's bottle sheet, second pass (2026-10-27): one shape per tier, every
-- drink its own colour and printed label (docs/04_ART/textures/drinks/*.png).
--   물 = the 삼다수 model, tier 1 = the can (store 435241125, its body label
--   is our picture), tier 2 = the flat flask (#11), tier 3 = the tall bottle
--   (#6, a label band round it), VIP 골목 공방 = #13's silhouette rebuilt with a
--   slightly narrower bottom (a store mesh cannot be reshaped).
-- Store models live in ServerStorage.ArtAssets.Bottles (scripts stripped),
-- so this runs on the server; the drawn shapes above stay as the fallback.
local ASSET_SHAPE = {
	water = "Samdasu", cider = "Can", cola = "Can", orange = "Can", lemonade = "Can", blueade = "Can",
}
local DRAWN = { ginger_brew = "flask", monte = "flask", french_lemonade = "flask", golden_apple = "flask", zzang_pop = "flask",
	hot_boost = "flask", green_claw = "flask", blue_wing = "flask", stack_hydro = "tall", pastel_splash = "tall", skull_water = "tall" }
local LABEL = {
	-- (cans: no printed design for now, plain metal in the drink colour; the user
	-- will send new pictures, 2026-10-28 (11), D-466)
	-- the user's generic pictures (no brand marks), D-467:
	lemonade = "rbxassetid://140148508020865", blueade = "rbxassetid://98521454520397", cider = "rbxassetid://107514929048340", orange = "rbxassetid://101148624831861", cola = "rbxassetid://72164413902397",
	ginger_brew = "rbxassetid://78161382486926", monte = "rbxassetid://111978227065988", french_lemonade = "rbxassetid://82834417286890",
	golden_apple = "rbxassetid://138757272545670", zzang_pop = "rbxassetid://113640294515835", hot_boost = "rbxassetid://89899401494100",
	green_claw = "rbxassetid://134976093090518", blue_wing = "rbxassetid://129850818133473",
	stack_hydro = "rbxassetid://81399516557820", pastel_splash = "rbxassetid://77895910978282", skull_water = "rbxassetid://97598937201249",
	golmok = "rbxassetid://104726293253378",
}
local ASSET_HEIGHT = { Samdasu = 2.1, Can = 1.3 }

local function template(shape: string): Instance?
	if not game:GetService("RunService"):IsServer() then return nil end
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local folder = art and art:FindFirstChild(if shape == "Samdasu" then "Foods" else "Bottles")
	return folder and folder:FindFirstChild(shape)
end

-- a band of flat panels round a (tapered) ring: plain colour, or a printed
-- label wrapped once round it
local function band(c: Ctx, name: string, y0: number, y1: number, r0: number, r1: number, n: number, look: Look, tex: string?)
	local s = c.s
	local h = y1 - y0
	local slant = math.sqrt(h * h + (r1 - r0) ^ 2)
	local rm = (r0 + r1) / 2
	local wn = 2 * rm * math.tan(math.pi / n)
	local grow = wn * 0.06
	local tilt = math.atan2(r1 - r0, h)
	for i = 0, n - 1 do
		local a = (i + 0.5) * 2 * math.pi / n
		local out = Vector3.new(math.sin(a), 0, math.cos(a))
		local p0 = (Vector3.new(0, (y0 + y1) / 2, 0) + out * rm) * s
		local p = make(c, name, Vector3.new((wn + 2 * grow) * s, slant * s, 0.02 * s), c.base * CFrame.lookAt(p0, p0 + out) * CFrame.Angles(-tilt, 0, 0), look.color, look.material, nil, look.transparency, look.reflectance)
		if tex then
			local t = Instance.new("Texture")
			t.Texture = tex
			t.Face = Enum.NormalId.Front
			t.StudsPerTileU = wn * n * s
			t.OffsetStudsU = (i * wn - grow) * s
			t.StudsPerTileV = slant * s
			t.Parent = p
		end
	end
end

-- (#11, #6 and #13 are re-uploads by a deleted account: their meshes no
-- longer load, so these three shapes are rebuilt from the user's pictures)

-- tier 2: #11's flat flask, rounded sides, a short neck with a cork, a paper label
local function flask(c: Ctx, color: Color3, key: string)
	local s = c.s
	local glass = { color = color, material = Enum.Material.SmoothPlastic, transparency = 0, reflectance = 0.12 }
	make(c, "BottleBody", Vector3.new(0.5 * s, 1.15 * s, 0.3 * s), c.base * CFrame.new(0, 0.575 * s, 0), color, glass.material, nil, 0, glass.reflectance)
	for _, x in ipairs({ -0.25, 0.25 }) do -- the round sides
		make(c, "BottleBody", Vector3.new(1.15 * s, 0.3 * s, 0.3 * s), c.base * CFrame.new(x * s, 0.575 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), color, glass.material, Enum.PartType.Cylinder, 0, glass.reflectance)
	end
	local sh = make(c, "BottleShoulder", Vector3.new(0.8 * s, 0.5 * s, 0.3 * s), c.base * CFrame.new(0, 1.15 * s, 0), color, glass.material, nil, 0, glass.reflectance)
	local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = sh
	cyl(c, "BottleNeck", 1.3, 1.6, 0.2, glass)
	cyl(c, "Cork", 1.58, 1.75, 0.18, { color = Color3.fromRGB(205, 175, 110), material = Enum.Material.Wood })
	local label = make(c, "Label", Vector3.new(0.46 * s, 0.56 * s, 0.01 * s), c.base * CFrame.new(0, 0.58 * s, -0.156 * s), WHITE)
	local d = Instance.new("Decal")
	d.Texture = LABEL[key] or ""
	d.Face = Enum.NormalId.Front
	d.Parent = label
end

-- tier 3: #6's tall bottle, a round shoulder, a long neck, a label band
local function tall(c: Ctx, color: Color3, key: string)
	local glass = { color = color, material = Enum.Material.SmoothPlastic, transparency = 0, reflectance = 0.12 }
	cyl(c, "BottleBody", 0, 1.2, 0.64, glass)
	ell(c, "BottleShoulder", 1.2, 0.64, 0.72, glass)
	cyl(c, "BottleNeck", 1.4, 2.1, 0.22, glass)
	cyl(c, "BottleLip", 2.06, 2.16, 0.26, glass)
	band(c, "Label", 0.35, 0.85, 0.326, 0.326, 12, { color = WHITE }, LABEL[key])
end

-- 골목 공방 (VIP): #13's long bottle, the body a touch narrower at the foot (user sketch)
local function vipBottle(c: Ctx, color: Color3)
	local glass = { color = color, material = Enum.Material.SmoothPlastic, transparency = 0, reflectance = 0.12 }
	-- (stepped cylinders, not panels: a boat holds six of these, phones)
	cyl(c, "BottleFoot", 0, 0.25, 0.565, glass)
	cyl(c, "BottleBody", 0.24, 0.55, 0.585, glass)
	cyl(c, "BottleBody", 0.54, 1.36, 0.62, glass)
	ell(c, "BottleShoulder", 1.35, 0.62, 1.3, glass)
	cyl(c, "BottleNeck", 1.85, 2.45, 0.2, glass)
	cyl(c, "BottleLip", 2.42, 2.5, 0.24, glass)
	cyl(c, "Foil", 2.2, 2.52, 0.215, { color = Color3.fromRGB(214, 172, 70), material = Enum.Material.Foil })
	band(c, "Label", 0.6, 1.05, 0.316, 0.316, 12, { color = WHITE }, LABEL.golmok)
end

local function fromTemplate(c: Ctx, key: string, color: Color3): boolean
	local shape = ASSET_SHAPE[key]
	local src = shape and template(shape)
	if not src then return false end
	local m = src:Clone()
	local holder = if m:IsA("Model") then m else Instance.new("Model")
	if holder ~= m then m.Parent = holder end
	if shape == "Can" then -- (the printed name to the front)
		local pv = holder:GetPivot()
		holder:PivotTo(CFrame.new(pv.Position) * CFrame.Angles(0, math.rad(-15), 0) * pv.Rotation)
	end
	local _, size = holder:GetBoundingBox()
	holder:ScaleTo(holder:GetScale() * ASSET_HEIGHT[shape] * c.s / size.Y)
	local box, size2 = holder:GetBoundingBox()
	-- stand it on `base`, upright as modelled
	local lift = c.base * CFrame.new(0, size2.Y / 2, 0)
	local move = lift * CFrame.new(box.Position):Inverse()
	local glassColor = color
	for _, p in ipairs(holder:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = move * p.CFrame -- (base's tilt too: bottles lean in the buckets)
			p.CanCollide, p.CanTouch, p.CastShadow = false, false, false
			for _, j in ipairs(p:GetChildren()) do if j:IsA("JointInstance") or j:IsA("WeldConstraint") then j:Destroy() end end
			if shape == "Can" and p:IsA("MeshPart") then
				-- (no design picture: the can's own print is cleared, plain metal in the drink colour)
				p.TextureID = LABEL[key] or ""
				if not LABEL[key] then p.Color = color end
				p.Reflectance = 0.35 -- (strong gloss on every drink, user 2026-10-28 (18))
			elseif shape == "Flask" and p:IsA("MeshPart") and p.Name:find("vile") and not p.Name:find("cork") then
				-- the outer glass takes the drink colour, the inner shape a darker one (the drink inside)
				p.Color = if p.Size.X > 0.2 * c.s then glassColor else glassColor:Lerp(Color3.new(0, 0, 0), 0.45)
			elseif shape == "Tall" and p:IsA("MeshPart") then
				p.Color = glassColor
			end
			for _, d in ipairs(p:GetChildren()) do
				if d:IsA("Decal") and shape == "Flask" then d.Texture = LABEL[key] or d.Texture end
			end
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
		end
	end
	if shape == "Tall" then
		-- a printed label band round the lower body
		local r = size2.X / 2 / c.s + 0.006
		band(c, "Label", 0.55, 1.05, r, r, 20, { color = WHITE }, LABEL[key])
	end
	holder:Destroy()
	return true
end

-- The user's own bottle models (STL files 2026-10-27, simplified to ~2,000
-- triangles: docs/04_ART/models/bottles/*.obj, imported into
-- ServerStorage.ArtAssets.Bottles). One mesh, 1 stud tall, upright.
-- [key] = { model, height in bottle units, label: "front" (a paper label) or "band" (wrapped), label y0, y1 (0..1 of the height) }
local USER_MESH = {
	ginger_brew = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	monte = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	french_lemonade = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	golden_apple = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	zzang_pop = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	hot_boost = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	green_claw = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	blue_wing = { "bottle_absolut_tier2", 2.63, "front", 0.25, 0.6 },
	stack_hydro = { "bottle_stack_hydro", 3.24, "band", 0.2, 0.42 },
	pastel_splash = { "bottle_pastel_splash", 3.24, "pastel", 0.13, 0.47 },
	skull_water = { "bottle_skull_water", 3.24, "swing", 0.12, 0.52 },
	-- (VIP 1.3x, D-419; the others 1.5x, D-426. BottleShapes.Height keeps the
	-- old heights, so the bottles in the hand grow by the same amount)
	golmok = { "bottle_vip_golmok", 3.28, "vip", 0, 0 },
}
-- The whole-bottle pictures (user 2026-10-27, D-423): labels, caps and foil
-- painted on the bottle mesh itself (the "_uv" imports carry cylindrical UVs,
-- front at the middle of the picture, flipped left-right). They are
-- SurfaceAppearances in ServerStorage.ArtAssets.BottleSkins (AlphaMode
-- Overlay: see-through pixels show the part colour, so one picture serves
-- every flavour; a plain TextureID drew them black). Scripts cannot set a
-- ColorMap, so they are made in Edit mode (place only). Pictures:
-- docs/04_ART/textures/drinks/skins/, made by the bottle_skins script.
local function skinOf(key: string): SurfaceAppearance?
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local skins = art and art:FindFirstChild("BottleSkins")
	local sa = skins and skins:FindFirstChild(key)
	return if sa and sa:IsA("SurfaceAppearance") then sa else nil
end
local VIP_SPADE, VIP_PLATE = "rbxassetid://100981037328421", "rbxassetid://75444167233842"

-- 골목 공방 (VIP), like the user's photo of the metallic champagne set: a
-- mirror-metal body in the flavour colour, a black foil over the neck, a
-- metal collar with a small spade, a raised spade emblem on the front with a
-- monogram (ours: O for OHU) and a bronze plate under it. No label band.
-- `painted`: the foil, the spade picture and the plate are in the bottle's
-- picture (D-423); only the raised spade is added.
local function vipDress(c: Ctx, body: BasePart, color: Color3, H: number, r: number, painted: boolean?)
	local s = c.s
	body.Material = Enum.Material.Metal
	body.Reflectance = 0.35
	if not painted then
		-- foil: black, from the top down over the shoulder start
		cyl(c, "Foil", 0.8 * H, 1.0 * H + 0.01, 0.105 * H, { color = Color3.fromRGB(18, 18, 20), material = Enum.Material.Fabric })
		cyl(c, "Foil", 0.765 * H, 0.81 * H, 0.125 * H, { color = Color3.fromRGB(18, 18, 20), material = Enum.Material.Fabric })
		-- metal collar under the foil, a small spade on its front
		cyl(c, "Collar", 0.735 * H, 0.77 * H, 0.13 * H, { color = color:Lerp(Color3.new(0, 0, 0), 0.15), material = Enum.Material.Metal, reflectance = 0.35 })
		local sm = make(c, "CollarSpade", Vector3.new(0.05 * H * s, 0.06 * H * s, 0.01 * s), c.base * CFrame.new(0, 0.752 * H * s, -(0.066 * H + 0.006) * s), color, nil, nil, 1)
		local d0 = Instance.new("Decal") d0.Texture = VIP_SPADE d0.Color3 = color:Lerp(Color3.new(0, 0, 0), 0.35) d0.Parent = sm
	end
	-- the raised spade: a thin metal plate in the spade's outline (two lobes,
	-- a pointed top, a stem) standing proud of the glass, the picture on it
	local ey, eh, ew = 0.36 * H, 0.2 * H, 0.17 * H
	local z = -(r + 0.012)
	local relief = color:Lerp(Color3.new(0, 0, 0), 0.12)
	local function rel(name, size: Vector3, cf: CFrame, shape)
		return make(c, name, size * s, c.base * CFrame.new(cf.X * s, cf.Y * s, cf.Z * s) * cf.Rotation, relief, Enum.Material.Metal, shape, 0, 0.3)
	end
	for _, side in ipairs({ -1, 1 }) do -- the two lobes
		local lobe = rel("Spade", Vector3.new(ew * 0.55, ew * 0.55, 0.025), CFrame.new(side * ew * 0.24, ey - eh * 0.05, z), nil)
		local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = lobe
	end
	rel("Spade", Vector3.new(ew * 0.5, ew * 0.5, 0.025), CFrame.new(0, ey + eh * 0.12, z) * CFrame.Angles(0, 0, math.rad(45)), nil) -- the point
	rel("Spade", Vector3.new(ew * 0.1, eh * 0.32, 0.025), CFrame.new(0, ey - eh * 0.32, z), nil) -- the stem
	rel("Spade", Vector3.new(ew * 0.34, eh * 0.05, 0.025), CFrame.new(0, ey - eh * 0.47, z), nil) -- the foot
	if painted then return end
	local face = make(c, "SpadeFace", Vector3.new(ew * s, eh * s, 0.005 * s), c.base * CFrame.new(0, ey * s, (z - 0.016) * s), color, nil, nil, 1)
	local d1 = Instance.new("Decal") d1.Texture = VIP_SPADE d1.Color3 = color:Lerp(Color3.new(1, 1, 1), 0.25) d1.Parent = face
	-- the bronze plate under it
	local plate = make(c, "Plate", Vector3.new(0.17 * H * s, 0.05 * H * s, 0.02 * s), c.base * CFrame.new(0, 0.2 * H * s, -(r + 0.006) * s), Color3.fromRGB(92, 62, 40), Enum.Material.Metal, nil, 0, 0.2)
	local d2 = Instance.new("Decal") d2.Texture = VIP_PLATE d2.Parent = plate
end
local function userMesh(c: Ctx, key: string, color: Color3): boolean
	local spec = USER_MESH[key]
	if not spec or not game:GetService("RunService"):IsServer() then return false end
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local folder = art and art:FindFirstChild("Bottles")
	-- ("_uv" imports carry UVs for the painted picture, "_smooth" vertex normals)
	local skin = skinOf(key)
	-- ("_fixed": faces turned outward and the front where Roblox puts it, D-425;
	-- the first "_uv" imports were inside out: the back showed through)
	local uv = folder and skin and (folder:FindFirstChild(spec[1] .. "_fixed") or folder:FindFirstChild(spec[1] .. "_uv"))
	local src = uv or (folder and (folder:FindFirstChild(spec[1] .. "_smooth") or folder:FindFirstChild(spec[1])))
	local mesh = src and (if src:IsA("MeshPart") then src else src:FindFirstChildWhichIsA("MeshPart", true))
	if not mesh then return false end
	local s, H = c.s, spec[2]
	local p = mesh:Clone()
	for _, d in ipairs(p:GetChildren()) do d:Destroy() end
	local k = H / mesh.Size.Y
	p.Size = mesh.Size * k * s
	p.Name = "BottleBody"
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.1
	p.CanCollide, p.CanTouch, p.CastShadow = false, false, false
	if c.weld then
		p.Anchored = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = c.weld
		w.Part1 = p
		p.CFrame = c.base * CFrame.new(0, H * s / 2, 0)
		w.Parent = p
	else
		p.Anchored = true
		p.CFrame = c.base * CFrame.new(0, H * s / 2, 0)
	end
	p.Parent = c.parent
	table.insert(c.parts, p)
	-- the label (body radius from the mesh's width)
	local r = mesh.Size.X * k / 2
	local y0, y1 = spec[4] * H, spec[5] * H
	if uv then
		-- painted: the picture on the mesh, no label parts (D-423)
		-- (the VIP spade, monogram and plate are painted in relief too: no parts)
		(skin :: SurfaceAppearance):Clone().Parent = p
		if spec[1] == "bottle_absolut_tier2" then
			-- tier 2 (user 2026-10-28 (17)): a very pale tint of the drink colour,
			-- 30 % see-through and a soft glow of its own
			p.Color = color:Lerp(Color3.new(1, 1, 1), 0.65)
			p.Transparency = 0.3
			p.Reflectance = 0
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = 0.8
			light.Range = 3 * s + 1
			light.Shadows = false
			light.Parent = p
		end		if key == "pastel_splash" then
			-- frosted and glowing (user 2026-10-28 (3)): a little see-through, a warm light inside
			p.Transparency = 0.18
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = 2
			light.Range = 5 * s + 2
			light.Parent = p
		end
	elseif spec[3] == "vip" then
		vipDress(c, p, color, H, r * 0.93)
	elseif spec[3] == "front" then
		local lw, lh = r * 1.2, (y1 - y0)
		local label = make(c, "Label", Vector3.new(lw * s, lh * s, 0.01 * s), c.base * CFrame.new(0, (y0 + y1) / 2 * s, -(r + 0.006) * s), WHITE)
		label.Transparency = 1
		local d = Instance.new("Decal")
		d.Texture = LABEL[key] or ""
		d.Face = Enum.NormalId.Front
		d.Parent = label
	else
		band(c, "Label", y0, y1, r + 0.006, r + 0.006, 12, { color = WHITE }, LABEL[key])
	end
	return true
end

-- tier-1 cans are drawn at a third of their old size (user 2026-10-28 (3)):
-- BottleShapes.Height keeps the old height, so holders and hands only see a
-- smaller can
local CAN_SCALE = 1 / 3
BottleShapes.CanScale = CAN_SCALE
-- (on a table they keep the old size: callers divide by CanScale, user 2026-10-28 (4))
function BottleShapes.isCan(key: string): boolean
	return ASSET_SHAPE[key] == "Can"
end

function BottleShapes.add(parent: Instance, base: CFrame, key: string, color: Color3, scale: number, weldTo: BasePart?): {BasePart}
	if ASSET_SHAPE[key] == "Can" then scale *= CAN_SCALE end
	local c: Ctx = { parent = parent, base = base, s = scale, weld = weldTo, parts = {} }
	if userMesh(c, key, color) then
		return c.parts
	elseif key == "golmok" then
		vipBottle(c, color)
	elseif DRAWN[key] == "flask" then
		flask(c, color, key)
	elseif DRAWN[key] == "tall" then
		tall(c, color, key)
	elseif not fromTemplate(c, key, color) then
		local builder = BUILDERS[key] or BUILDERS.cider
		builder(c, color)
	end
	return c.parts
end

-- bottle heights at scale 1 (to fit a holder or a tool)
BottleShapes.Height = { water = 2.1, cider = 1.3, cola = 1.3, orange = 1.3, lemonade = 1.3, blueade = 1.3,
	ginger_brew = 1.75, monte = 1.75, french_lemonade = 1.75, golden_apple = 1.75, zzang_pop = 1.75, hot_boost = 1.75,
	green_claw = 1.75, blue_wing = 1.75, stack_hydro = 2.16, pastel_splash = 2.16, skull_water = 2.16, golmok = 2.52 }
function BottleShapes.height(key: string): number
	return BottleShapes.Height[key] or 1.98
end

return BottleShapes
