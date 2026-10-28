--!strict
-- Table buckets for club drinks, one look per tier (D-323, user's photos
-- 2026-10-26): tier 1 a bottle alone, tier 2 a steel ice bucket, tier 3 a
-- glowing acrylic tub in the drink colour, VIP (any drink a VIP pass owner
-- buys) a gold-framed LED boat, and 골목 공방 소다 (VIP only) a bigger boat
-- with six bottles, a gold arch and sparkles. Bottles: BottleShapes (the
-- drinks stay sodas, D-043; shapes from the user's sheet). Plain parts, about
-- 10–40 per bucket, one light each (phones).

local BottleShapes = require(game:GetService("ReplicatedStorage").FashionGame.Shared.BottleShapes)

local DrinkBucket = {}

export type Kind = "bottle" | "steel" | "acrylic" | "vip" | "golmok"

local GOLD = Color3.fromRGB(214, 172, 70)
local STEEL = Color3.fromRGB(196, 200, 206)
local ICE = Color3.fromRGB(235, 245, 255)
-- (deep colours: the club bloom turns light neon white)
local RAINBOW = {
	Color3.fromRGB(0, 70, 255), Color3.fromRGB(230, 0, 110), Color3.fromRGB(0, 190, 70),
	Color3.fromRGB(255, 120, 0), Color3.fromRGB(120, 0, 255), Color3.fromRGB(0, 170, 200),
}
local function deep(c: Color3): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.max(s, 0.85), math.min(v, 0.85))
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end

-- an upright cylinder: cf = centre, d = diameter, h = height
local function cyl(model: Model, name: string, d: number, h: number, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	return part(model, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder, transparency)
end

-- The drink's own bottle (BottleShapes: the silhouettes from the user's
-- reference sheet, 2026-10-27) standing at `base` (bottom centre).
local function bottle(model: Model, base: CFrame, key: string, color: Color3, scale: number)
	BottleShapes.add(model, base, key, color, scale * 0.95)
end

-- bottles leaning out of the ice, spread along the bucket's X axis
local function bottlesInIce(model: Model, top: CFrame, key: string, colors: {Color3}, count: number, spread: number, scale: number)
	for i = 1, count do
		local u = if count == 1 then 0 else (i - 1) / (count - 1) * 2 - 1
		local lean = CFrame.Angles(math.rad(10 * ((i % 2) * 2 - 1)), 0, math.rad(-22 * u))
		bottle(model, top * CFrame.new(u * spread, -0.7 * scale, ((i % 2) - 0.5) * 0.25) * lean, key, colors[(i - 1) % #colors + 1], scale)
	end
end

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- The ice bucket (user 2026-10-28 (4)): a smooth pail that opens up toward the
-- top (the store mesh ServerStorage.ArtAssets.IceBucket when it is there, else
-- stepped rings), heaped with see-through ice cubes, three bottles leaning
-- out of the ice. Used by tier-1 drinks and the sparkler bucket set.
-- glow: "bottles" = the bottles glow in their colour, "ice" = the ice glows.
DrinkBucket.Glow = "ice" -- (the user's pick, 2026-10-28 (5))
-- (bigger pail, same cans: the cans stood out through the sides, user 2026-10-28 (5))
local H_PAIL, D_TOP = 1.9, 2.4
function DrinkBucket.iceBucket(m: Instance, at: CFrame, bottles: {{ key: string, color: Color3 }}, glow: string?): number
	glow = glow or DrinkBucket.Glow
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local mesh = art and art:FindFirstChild("IceBucket")
	if mesh and mesh:IsA("BasePart") then
		-- (the plain store cup 3478283525 stretched into a pail: smooth, wide at the top)
		local p = mesh:Clone()
		p.Size = Vector3.new(D_TOP, H_PAIL, D_TOP)
		p.CFrame = at * CFrame.new(0, H_PAIL / 2, 0) * mesh.CFrame.Rotation
		p.Name = "Pail"
		-- brushed aluminium (user 2026-10-28 (6))
		p.Material = Enum.Material.Metal
		p.Color = Color3.fromRGB(150, 155, 163)
		p.Reflectance = 0.6
		p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, false
		p.Parent = m
	else
		for i, ring in ipairs({ { 0, 0.45, 1.25 }, { 0.43, 0.8, 1.42 }, { 0.78, 1.1, 1.56 }, { 1.08, H_PAIL, D_TOP } }) do
			local p = cyl(m :: Model, "Pail" .. i, ring[3], ring[2] - ring[1], at * CFrame.new(0, (ring[1] + ring[2]) / 2, 0), Color3.fromRGB(205, 205, 212), Enum.Material.Metal)
			p.Reflectance = 0.25
		end
	end
	-- glowing ice heaped up near the rim, the cans standing well out of it (user 2026-10-28 (6)/(8))
	local rnd = Random.new(7)
	local glowIce = glow == "ice"
	for i = 1, 18 do
		local a = rnd:NextNumber(0, math.pi * 2)
		local r = rnd:NextNumber(0, 0.6)
		local s = rnd:NextNumber(0.24, 0.34)
		local cube = part(m :: Model, "IceCube", Vector3.new(s, s, s),
			at * CFrame.new(math.cos(a) * r, H_PAIL * 0.66 + rnd:NextNumber(0, H_PAIL * 0.22), math.sin(a) * r)
				* CFrame.Angles(rnd:NextNumber(0, 1), rnd:NextNumber(0, 3), rnd:NextNumber(0, 1)),
			if glowIce then Color3.fromRGB(220, 240, 255) else ICE, if glowIce then Enum.Material.Neon else Enum.Material.Glass, if glowIce then 0.45 else 0.35)
		if glowIce and i == 1 then light(cube, Color3.fromRGB(200, 230, 255), 7, 1.6) end
	end
	-- three bottles leaning out (cans at their full table size)
	for i, b in ipairs(bottles) do
		local angle = (i - 1) * math.pi * 2 / #bottles
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-out.Z, 0, out.X)
		local scale = if BottleShapes.isCan(b.key) then 0.85 / BottleShapes.CanScale else 0.7
		-- (in the ice, leaning out of the open top, not through the sides)
		local base = CFrame.new((at * CFrame.new(out * 0.3 + Vector3.new(0, H_PAIL * 0.75, 0))).Position)
			* CFrame.fromAxisAngle(tangent, math.rad(-18)) * CFrame.Angles(0, -angle - math.pi / 2, 0)
		local parts = BottleShapes.add(m, base, b.key, b.color, scale)
		if glow == "bottles" then
			for _, p in ipairs(parts) do
				if p.Name == "BottleBody" or p:IsA("MeshPart") then
					light(p, b.color, 5, 1.4)
					break
				end
			end
		end
	end
	return H_PAIL
end

-- Builds the bucket for `kind` with its bottom centre at `at` (on the table
-- top). colors = the drink colour(s); returns the model (not parented).
function DrinkBucket.build(kind: Kind, colors: {Color3}, at: CFrame, key: string?): Model
	local drinkKey = key or "cider"
	local m = Instance.new("Model")
	m.Name = "DrinkBucket_" .. kind
	m:SetAttribute("BucketKind", kind)
	local c = colors[1]
	if kind == "bottle" then
		-- (user 2026-10-27) tier 1 is the sparkler bucket's look: a shiny pale
		-- pail, ice on top, three cans in the drink colour standing in it
		-- (2026-10-28 (4)) the ice bucket with three of the drink's cans
		DrinkBucket.iceBucket(m, at, { { key = drinkKey, color = c }, { key = drinkKey, color = c }, { key = drinkKey, color = c } })
	elseif kind == "steel" then
		-- brushed steel pail, ice heaped to the rim, ring handles
		local h = 1.3
		cyl(m, "Pail", 1.6, h, at * CFrame.new(0, h / 2, 0), STEEL, Enum.Material.Metal)
		cyl(m, "Rim", 1.7, 0.1, at * CFrame.new(0, h, 0), Color3.fromRGB(220, 224, 230), Enum.Material.Metal)
		cyl(m, "Band", 1.64, 0.08, at * CFrame.new(0, 0.25, 0), Color3.fromRGB(170, 174, 180), Enum.Material.Metal)
		cyl(m, "Ice", 1.5, 0.22, at * CFrame.new(0, h + 0.02, 0), ICE, Enum.Material.Ice)
		for _, side in ipairs({ -1, 1 }) do
			part(m, "RingHandle", Vector3.new(0.08, 0.4, 0.4), at * CFrame.new(side * 0.86, h * 0.7, 0), Color3.fromRGB(200, 160, 80), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		bottlesInIce(m, at * CFrame.new(0, h, 0), drinkKey, colors, 2, 0.35, 0.85)
	elseif kind == "acrylic" then
		-- frosted acrylic tub lit from inside in the drink colour, black base
		local h = 1.25
		cyl(m, "Base", 1.5, 0.18, at * CFrame.new(0, 0.09, 0), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic)
		-- (Glass reads as almost nothing on phones: tinted plastic over a strong neon core)
		local glow = cyl(m, "Glow", 1.5, h - 0.15, at * CFrame.new(0, 0.18 + (h - 0.15) / 2, 0), deep(c), Enum.Material.Neon, 0)
		cyl(m, "Tub", 1.9, h, at * CFrame.new(0, 0.18 + h / 2, 0), c, Enum.Material.SmoothPlastic, 0.55)
		cyl(m, "TubRim", 1.95, 0.08, at * CFrame.new(0, 0.18 + h, 0), c:Lerp(Color3.new(1, 1, 1), 0.6), Enum.Material.Neon, 0.2)
		-- the raised back lip of the tub
		part(m, "BackLip", Vector3.new(1.4, 0.55, 0.1), at * CFrame.new(0, 0.18 + h + 0.2, 0.86) * CFrame.Angles(math.rad(-12), 0, 0), c, Enum.Material.SmoothPlastic, 0.5)
		cyl(m, "Ice", 1.75, 0.22, at * CFrame.new(0, 0.18 + h - 0.05, 0), c:Lerp(ICE, 0.5), Enum.Material.Ice, 0)
		light(glow, c, 7, 1.6)
		bottlesInIce(m, at * CFrame.new(0, 0.18 + h, 0), drinkKey, colors, 3, 0.45, 0.85)
	else
		-- gold-framed LED boat: clear acrylic box on a U frame, rainbow ice
		local golmok = kind == "golmok"
		local L = if golmok then 3.6 else 2.6
		local W, H = if golmok then 1.6 else 1.3, if golmok then 1.4 else 1.2
		local lift = 0.45
		local mid = at * CFrame.new(0, lift + H / 2, 0)
		part(m, "Box", Vector3.new(L, H, W), mid, Color3.fromRGB(200, 215, 255), Enum.Material.SmoothPlastic, nil, 0.7)
		local floor = part(m, "LEDFloor", Vector3.new(L - 0.1, 0.08, W - 0.1), at * CFrame.new(0, lift + 0.05, 0), GOLD, Enum.Material.Neon, nil, 0)
		local n = if golmok then 6 else 3
		for i = 1, n do
			local x = -L / 2 + (i - 0.5) * L / n
			part(m, "IceGlow", Vector3.new(L / n - 0.02, H * 0.55, W - 0.15), at * CFrame.new(x, lift + 0.1 + H * 0.275, 0), RAINBOW[(i - 1) % #RAINBOW + 1], Enum.Material.Neon, nil, 0)
		end
		-- U frame ends: two legs flaring out, a foot bar and a top rail
		for _, side in ipairs({ -1, 1 }) do
			local ex = side * (L / 2 + 0.12)
			for _, dz in ipairs({ -1, 1 }) do
				part(m, "FrameLeg", Vector3.new(0.14, H + lift + 0.15, 0.14), at * CFrame.new(ex + side * 0.12, (H + lift + 0.15) / 2, dz * (W / 2 + 0.05)) * CFrame.Angles(0, 0, math.rad(-8 * side)), GOLD, Enum.Material.Metal)
			end
			part(m, "FrameFoot", Vector3.new(0.5, 0.12, W + 0.5), at * CFrame.new(ex + side * 0.2, 0.06, 0), GOLD, Enum.Material.Metal)
			part(m, "FrameRail", Vector3.new(0.14, 0.14, W + 0.25), at * CFrame.new(ex + side * 0.26, lift + H + 0.05, 0), GOLD, Enum.Material.Metal)
		end
		part(m, "FrameBottom", Vector3.new(L + 0.3, 0.12, 0.14), at * CFrame.new(0, lift - 0.06, W / 2 + 0.05), GOLD, Enum.Material.Metal)
		part(m, "FrameBottom", Vector3.new(L + 0.3, 0.12, 0.14), at * CFrame.new(0, lift - 0.06, -W / 2 - 0.05), GOLD, Enum.Material.Metal)
		light(floor, if golmok then RAINBOW[2] else Color3.fromRGB(170, 140, 255), if golmok then 10 else 8, 1.8)
		-- (user 2026-10-27) the 골목 공방 boat's bottles in the flavour that was
		-- bought (레몬 라벤더 / 생강 장미 / 오미자 히비스커스 / 오디), on the rainbow ice
		local bottleColors = colors
		bottlesInIce(m, at * CFrame.new(0, lift + H, 0), drinkKey, bottleColors, if golmok then 6 else 4, L / 2 - 0.4, if golmok then 1 else 0.9)
		if golmok then
			-- gold arch over the boat with a glowing crest, and sparkles
			local archH = H + lift + 1.6
			for _, side in ipairs({ -1, 1 }) do
				part(m, "ArchPost", Vector3.new(0.14, archH, 0.14), at * CFrame.new(side * (L / 2 + 0.38), archH / 2, 0), GOLD, Enum.Material.Metal)
			end
			part(m, "ArchBar", Vector3.new(L + 0.9, 0.16, 0.16), at * CFrame.new(0, archH, 0), GOLD, Enum.Material.Metal)
			local crest = part(m, "Crest", Vector3.new(0.12, 0.7, 0.7), at * CFrame.new(0, archH + 0.4, 0), RAINBOW[2], Enum.Material.Neon, Enum.PartType.Cylinder)
			crest.CFrame = at * CFrame.new(0, archH + 0.4, 0) * CFrame.Angles(0, math.rad(90), 0)
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Rate = 6
			sparkle.Lifetime = NumberRange.new(0.8, 1.4)
			sparkle.Speed = NumberRange.new(0.5, 1.2)
			sparkle.SpreadAngle = Vector2.new(60, 60)
			sparkle.Size = NumberSequence.new(0.25, 0)
			sparkle.LightEmission = 1
			sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 160, 220))
			sparkle.Parent = crest
		end
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	return m
end

return DrinkBucket
