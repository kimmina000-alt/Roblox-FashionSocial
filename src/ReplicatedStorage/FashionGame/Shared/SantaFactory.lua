--!strict
-- (D-1878) The mini Santas of the Santa hunt, built from parts (no uploaded meshes, so the same code
-- makes the one hidden in the world, the album's pictures and the plush in the hand).
-- SantaFactory.build(look, scale?) → an unanchored-free Model ~2.6 studs tall at scale 1 (anchored,
-- no collision, no shadow), its pivot at the bottom middle, facing -Z.
-- Looks (SantaHuntConfig.Santas[n].look): classic, dj, barista, camera, store, gukbap, hanbok, guard,
-- teacup, surfer, baker, bus, subway, wheel, bumper, churros, vip, viking, rudolph, golden.

local SantaFactory = {}

local RED = Color3.fromRGB(214, 40, 48)
local WHITE = Color3.fromRGB(250, 250, 250)
local SKIN = Color3.fromRGB(255, 214, 186)
local BLACK = Color3.fromRGB(30, 30, 34)
local GOLD = Color3.fromRGB(240, 190, 60)
local PINK = Color3.fromRGB(255, 150, 160)

type Spec = { suit: Color3, trim: Color3, hat: string, material: Enum.Material?, extra: ((add: any) -> ())? }

local function newPart(model: Model, name: string, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- the looks: suit / trim colours, the hat ("santa", "gat", "chef", "cap", "viking", "jeonrip",
-- "none") and extra pieces
local LOOKS: {[string]: Spec} = {}

local function ball(add: any, name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?)
	return add(name, Enum.PartType.Ball, size, CFrame.new(pos), color, mat)
end
local function block(add: any, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
	return add(name, Enum.PartType.Block, size, cf, color, mat)
end
-- a cylinder standing up (Roblox cylinders lie along X)
local function can(add: any, name: string, height: number, diameter: number, pos: Vector3, color: Color3, mat: Enum.Material?)
	return add(name, Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat)
end

-- the right hand sits at (0.95, 0.95, -0.2); things held go there
local HAND = Vector3.new(0.98, 1.0, -0.35)

LOOKS.classic = { suit = RED, trim = WHITE, hat = "santa" }
LOOKS.golden = { suit = GOLD, trim = Color3.fromRGB(255, 244, 200), hat = "santa", material = Enum.Material.Metal,
	extra = function(add)
		ball(add, "Star", Vector3.new(0.35, 0.35, 0.12), Vector3.new(0, 3.05, 0), Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
	end }
LOOKS.dj = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	ball(add, "PhoneL", Vector3.new(0.22, 0.42, 0.42), Vector3.new(-0.6, 1.9, 0), BLACK)
	ball(add, "PhoneR", Vector3.new(0.22, 0.42, 0.42), Vector3.new(0.6, 1.9, 0), BLACK)
	block(add, "Band", Vector3.new(1.25, 0.1, 0.12), CFrame.new(0, 2.42, 0), BLACK)
	block(add, "Chain", Vector3.new(0.7, 0.08, 0.05), CFrame.new(0, 1.22, -0.68) * CFrame.Angles(0, 0, 0), GOLD, Enum.Material.Metal)
end }
LOOKS.barista = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	block(add, "Apron", Vector3.new(0.9, 0.9, 0.06), CFrame.new(0, 0.65, -0.68), Color3.fromRGB(110, 70, 45))
	can(add, "Cup", 0.4, 0.3, HAND + Vector3.new(0, 0.2, 0), WHITE)
	can(add, "Lid", 0.06, 0.32, HAND + Vector3.new(0, 0.42, 0), Color3.fromRGB(120, 80, 50))
end }
LOOKS.camera = { suit = RED, trim = WHITE, hat = "santa" } -- (its camera: extra below)
LOOKS.store = { suit = RED, trim = WHITE, hat = "cap", extra = function(add)
	block(add, "Snack", Vector3.new(0.45, 0.55, 0.15), CFrame.new(HAND + Vector3.new(0, 0.2, 0)), Color3.fromRGB(255, 210, 60))
end }
LOOKS.gukbap = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	can(add, "Bowl", 0.3, 0.6, Vector3.new(0, 1.05, -0.85), BLACK)
	can(add, "Soup", 0.05, 0.52, Vector3.new(0, 1.2, -0.85), Color3.fromRGB(240, 225, 200))
end }
LOOKS.hanbok = { suit = Color3.fromRGB(255, 160, 190), trim = Color3.fromRGB(120, 170, 255), hat = "gat" }
LOOKS.guard = { suit = Color3.fromRGB(200, 30, 40), trim = Color3.fromRGB(30, 60, 140), hat = "jeonrip" }
LOOKS.teacup = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	can(add, "Cup", 0.9, 2.2, Vector3.new(0, 0.45, 0), Color3.fromRGB(170, 220, 255))
	can(add, "CupRim", 0.08, 2.3, Vector3.new(0, 0.92, 0), WHITE)
end }
LOOKS.surfer = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	block(add, "Glasses", Vector3.new(0.7, 0.16, 0.05), CFrame.new(0, 2.0, -0.6), BLACK)
	block(add, "Board", Vector3.new(0.55, 2.4, 0.12), CFrame.new(1.25, 1.2, 0.2) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(80, 200, 220))
end }
LOOKS.baker = { suit = RED, trim = WHITE, hat = "chef", extra = function(add)
	ball(add, "Bread", Vector3.new(0.6, 0.35, 0.35), HAND + Vector3.new(0, 0.15, 0), Color3.fromRGB(215, 160, 90))
end }
LOOKS.bus = { suit = Color3.fromRGB(60, 120, 220), trim = WHITE, hat = "cap", extra = function(add)
	block(add, "Sign", Vector3.new(0.5, 0.35, 0.06), CFrame.new(HAND + Vector3.new(0, 0.45, 0)), Color3.fromRGB(80, 200, 120))
	block(add, "Pole", Vector3.new(0.06, 0.5, 0.06), CFrame.new(HAND + Vector3.new(0, 0.05, 0)), Color3.fromRGB(180, 180, 190))
end }
LOOKS.subway = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	block(add, "Card", Vector3.new(0.4, 0.26, 0.04), CFrame.new(HAND + Vector3.new(0, 0.25, 0)), Color3.fromRGB(60, 180, 80))
	block(add, "Scarf", Vector3.new(1.0, 0.18, 0.9), CFrame.new(0, 1.42, 0), Color3.fromRGB(60, 180, 80))
end }
LOOKS.wheel = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	block(add, "String", Vector3.new(0.03, 1.4, 0.03), CFrame.new(HAND + Vector3.new(0, 0.8, 0)), WHITE)
	ball(add, "Balloon", Vector3.new(0.6, 0.7, 0.6), HAND + Vector3.new(0, 1.75, 0), Color3.fromRGB(255, 120, 170))
end }
LOOKS.bumper = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	block(add, "Car", Vector3.new(2.0, 0.6, 2.2), CFrame.new(0, 0.3, 0), Color3.fromRGB(255, 200, 40))
	block(add, "Bumper", Vector3.new(2.2, 0.3, 2.4), CFrame.new(0, 0.15, 0), BLACK)
end }
LOOKS.churros = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	add("Churro", Enum.PartType.Cylinder, Vector3.new(1.0, 0.16, 0.16), CFrame.new(HAND + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(70)), Color3.fromRGB(190, 120, 60))
end }
LOOKS.vip = { suit = BLACK, trim = GOLD, hat = "santa", extra = function(add)
	block(add, "Glasses", Vector3.new(0.7, 0.16, 0.05), CFrame.new(0, 2.0, -0.6), BLACK)
	block(add, "Chain", Vector3.new(0.7, 0.08, 0.05), CFrame.new(0, 1.22, -0.68), GOLD, Enum.Material.Metal)
end }
LOOKS.viking = { suit = RED, trim = WHITE, hat = "viking" }
LOOKS.rudolph = { suit = RED, trim = WHITE, hat = "santa", extra = function(add)
	local o = Vector3.new(-1.5, 0, 0.2)
	ball(add, "DeerBody", Vector3.new(1.1, 1.0, 1.4), o + Vector3.new(0, 0.75, 0), Color3.fromRGB(150, 100, 60))
	ball(add, "DeerHead", Vector3.new(0.8, 0.8, 0.8), o + Vector3.new(0, 1.55, -0.45), Color3.fromRGB(160, 110, 70))
	ball(add, "DeerNose", Vector3.new(0.25, 0.25, 0.25), o + Vector3.new(0, 1.5, -0.88), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	for _, s in ipairs({ -1, 1 }) do
		block(add, "Antler", Vector3.new(0.08, 0.6, 0.08), CFrame.new(o + Vector3.new(0.2 * s, 2.1, -0.4)) * CFrame.Angles(0, 0, math.rad(-25 * s)), Color3.fromRGB(110, 70, 40))
		ball(add, "DeerEye", Vector3.new(0.1, 0.1, 0.1), o + Vector3.new(0.18 * s, 1.7, -0.8), BLACK)
		ball(add, "DeerLeg", Vector3.new(0.25, 0.4, 0.25), o + Vector3.new(0.3 * s, 0.15, -0.35), Color3.fromRGB(120, 80, 50))
		ball(add, "DeerLeg", Vector3.new(0.25, 0.4, 0.25), o + Vector3.new(0.3 * s, 0.15, 0.4), Color3.fromRGB(120, 80, 50))
	end
end }

-- the camera look's lens (a cylinder facing forward)
LOOKS.camera.extra = function(add)
	block(add, "Camera", Vector3.new(0.6, 0.4, 0.3), CFrame.new(HAND + Vector3.new(-0.25, 0.2, -0.1)), Color3.fromRGB(255, 170, 200))
	add("Lens", Enum.PartType.Cylinder, Vector3.new(0.2, 0.26, 0.26), CFrame.new(HAND + Vector3.new(-0.25, 0.2, -0.32)) * CFrame.Angles(0, math.rad(90), 0), BLACK)
end

function SantaFactory.looks(): {string}
	local list = {}
	for k in pairs(LOOKS) do table.insert(list, k) end
	table.sort(list)
	return list
end

function SantaFactory.build(look: string, scale: number?): Model
	local spec = LOOKS[look] or LOOKS.classic
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "MiniSanta_" .. look
	local function add(name: string, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		return newPart(model, name, shape, size, cf, color, mat or spec.material)
	end
	local skin = function(name, size, pos, color) return newPart(model, name, Enum.PartType.Ball, size, CFrame.new(pos), color) end

	-- body
	local body = ball(add, "Body", Vector3.new(1.6, 1.5, 1.4), Vector3.new(0, 0.85, 0), spec.suit)
	ball(add, "Fur", Vector3.new(1.66, 0.3, 1.46), Vector3.new(0, 0.22, 0), spec.trim)
	ball(add, "Belt", Vector3.new(1.63, 0.24, 1.43), Vector3.new(0, 0.78, 0), BLACK)
	block(add, "Buckle", Vector3.new(0.32, 0.26, 0.06), CFrame.new(0, 0.78, -0.71), GOLD, Enum.Material.Metal)
	block(add, "FrontFur", Vector3.new(0.2, 0.9, 0.06), CFrame.new(0, 1.15, -0.66), spec.trim)
	for _, side in ipairs({ -1, 1 }) do
		ball(add, "Boot", Vector3.new(0.48, 0.36, 0.6), Vector3.new(0.36 * side, 0.12, -0.15), BLACK)
		ball(add, "Arm", Vector3.new(0.46, 0.5, 0.46), Vector3.new(0.86 * side, 1.05, -0.12), spec.suit)
		ball(add, "Mitten", Vector3.new(0.32, 0.32, 0.32), Vector3.new(0.98 * side, 0.82, -0.3), if look == "golden" then GOLD else Color3.fromRGB(40, 120, 60))
	end
	-- head
	skin("Head", Vector3.new(1.15, 1.1, 1.1), Vector3.new(0, 1.95, 0), SKIN)
	newPart(model, "Beard", Enum.PartType.Ball, Vector3.new(1.05, 0.85, 0.7), CFrame.new(0, 1.62, -0.3), WHITE)
	newPart(model, "Mustache", Enum.PartType.Ball, Vector3.new(0.62, 0.2, 0.26), CFrame.new(0, 1.86, -0.52), WHITE)
	skin("Nose", Vector3.new(0.2, 0.18, 0.18), Vector3.new(0, 1.94, -0.58), PINK)
	for _, side in ipairs({ -1, 1 }) do
		skin("Eye", Vector3.new(0.13, 0.15, 0.08), Vector3.new(0.21 * side, 2.08, -0.52), BLACK)
		skin("Cheek", Vector3.new(0.2, 0.12, 0.06), Vector3.new(0.36 * side, 1.95, -0.46), PINK)
	end
	-- hat
	if spec.hat == "santa" then
		local hatColor = if look == "golden" then GOLD else RED
		can(add, "HatBrim", 0.26, 1.22, Vector3.new(0, 2.4, 0), spec.trim)
		can(add, "Hat1", 0.3, 1.0, Vector3.new(0, 2.65, 0.03), hatColor)
		can(add, "Hat2", 0.26, 0.72, Vector3.new(0, 2.9, 0.1), hatColor)
		can(add, "Hat3", 0.22, 0.44, Vector3.new(0, 3.1, 0.2), hatColor)
		ball(add, "Pompom", Vector3.new(0.32, 0.32, 0.32), Vector3.new(0, 3.22, 0.36), spec.trim)
	elseif spec.hat == "gat" then
		can(add, "GatBrim", 0.05, 1.9, Vector3.new(0, 2.45, 0), BLACK)
		can(add, "GatTop", 0.5, 0.6, Vector3.new(0, 2.72, 0), BLACK)
	elseif spec.hat == "jeonrip" then
		can(add, "Brim", 0.06, 1.6, Vector3.new(0, 2.45, 0), BLACK)
		can(add, "Top", 0.45, 0.8, Vector3.new(0, 2.7, 0), BLACK)
		ball(add, "Feather", Vector3.new(0.25, 0.6, 0.25), Vector3.new(0.3, 3.0, 0), Color3.fromRGB(230, 40, 40))
	elseif spec.hat == "chef" then
		can(add, "Band", 0.3, 1.05, Vector3.new(0, 2.5, 0), WHITE)
		ball(add, "Puff", Vector3.new(1.2, 0.8, 1.2), Vector3.new(0, 2.95, 0), WHITE)
	elseif spec.hat == "cap" then
		ball(add, "Cap", Vector3.new(1.15, 0.6, 1.15), Vector3.new(0, 2.4, 0), if look == "bus" then Color3.fromRGB(40, 80, 170) else Color3.fromRGB(40, 170, 90))
		block(add, "Visor", Vector3.new(0.8, 0.06, 0.45), CFrame.new(0, 2.3, -0.65), if look == "bus" then Color3.fromRGB(30, 60, 140) else Color3.fromRGB(30, 140, 70))
	elseif spec.hat == "viking" then
		ball(add, "Helmet", Vector3.new(1.2, 0.8, 1.2), Vector3.new(0, 2.4, 0), Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			block(add, "Horn", Vector3.new(0.16, 0.6, 0.16), CFrame.new(0.65 * side, 2.7, 0) * CFrame.Angles(0, 0, math.rad(-30 * side)), WHITE)
		end
	end
	if spec.extra then spec.extra(add) end

	-- pivot at the bottom middle, facing -Z; then the scale
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(0, 0, 0)
	if s ~= 1 then model:ScaleTo(s) end
	return model
end

return SantaFactory
