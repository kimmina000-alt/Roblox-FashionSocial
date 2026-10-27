--!strict
-- Table buckets for club drinks, one look per tier (D-323, user's photos
-- 2026-10-26): tier 1 a bottle alone, tier 2 a steel ice bucket, tier 3 a
-- glowing acrylic tub in the drink colour, VIP (any drink a VIP pass owner
-- buys) a gold-framed LED boat, and 골목 공방 소다 (VIP only) a bigger boat
-- with six bottles, a gold arch and sparkles. Bottles are soda bottles
-- (never wine / champagne shapes: no alcohol, D-043). Plain parts, about
-- 10–40 per bucket, one light each (phones).

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

-- A soda bottle standing at `base` (bottom centre, its up axis = the bottle
-- axis): glass body in the drink colour, white label band, neck, gold cap.
local function bottle(model: Model, base: CFrame, color: Color3, scale: number)
	local s = scale
	cyl(model, "BottleBody", 0.55 * s, 1.3 * s, base * CFrame.new(0, 0.65 * s, 0), color, Enum.Material.Glass, 0.15)
	cyl(model, "BottleLabel", 0.57 * s, 0.45 * s, base * CFrame.new(0, 0.6 * s, 0), Color3.fromRGB(250, 250, 248))
	cyl(model, "BottleShoulder", 0.42 * s, 0.25 * s, base * CFrame.new(0, 1.42 * s, 0), color, Enum.Material.Glass, 0.15)
	cyl(model, "BottleNeck", 0.26 * s, 0.45 * s, base * CFrame.new(0, 1.75 * s, 0), color, Enum.Material.Glass, 0.15)
	cyl(model, "BottleCap", 0.3 * s, 0.12 * s, base * CFrame.new(0, 2.02 * s, 0), GOLD, Enum.Material.Metal)
end

-- bottles leaning out of the ice, spread along the bucket's X axis
local function bottlesInIce(model: Model, top: CFrame, colors: {Color3}, count: number, spread: number, scale: number)
	for i = 1, count do
		local u = if count == 1 then 0 else (i - 1) / (count - 1) * 2 - 1
		local lean = CFrame.Angles(math.rad(10 * ((i % 2) * 2 - 1)), 0, math.rad(-22 * u))
		bottle(model, top * CFrame.new(u * spread, -0.7 * scale, ((i % 2) - 0.5) * 0.25) * lean, colors[(i - 1) % #colors + 1], scale)
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

-- Builds the bucket for `kind` with its bottom centre at `at` (on the table
-- top). colors = the drink colour(s); returns the model (not parented).
function DrinkBucket.build(kind: Kind, colors: {Color3}, at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "DrinkBucket_" .. kind
	m:SetAttribute("BucketKind", kind)
	local c = colors[1]
	if kind == "bottle" then
		-- (user 2026-10-27) tier 1 is the sparkler bucket's look: a shiny pale
		-- pail, ice on top, three cans in the drink colour standing in it
		local h = 1.2
		local pail = cyl(m, "Pail", 1.5, h, at * CFrame.new(0, h / 2, 0), Color3.fromRGB(200, 200, 208), Enum.Material.Metal)
		pail.Reflectance = 0.25
		cyl(m, "Ice", 1.35, 0.1, at * CFrame.new(0, h - 0.02, 0), Color3.fromRGB(225, 240, 250), Enum.Material.Glass, 0.2)
		local shades = { c, c:Lerp(Color3.new(1, 1, 1), 0.35), c:Lerp(Color3.new(0, 0, 0), 0.25) }
		for i = 1, 3 do
			local angle = (i - 1) * math.pi * 2 / 3
			part(m, "Can", Vector3.new(0.9, 0.36, 0.36), at * CFrame.new(math.cos(angle) * 0.38, h + 0.55 - 0.6, math.sin(angle) * 0.38) * CFrame.Angles(0, 0, math.rad(80)), shades[i], Enum.Material.Metal, Enum.PartType.Cylinder)
		end
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
		bottlesInIce(m, at * CFrame.new(0, h, 0), colors, 2, 0.35, 0.85)
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
		bottlesInIce(m, at * CFrame.new(0, 0.18 + h, 0), colors, 3, 0.45, 0.85)
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
		local bottleColors = if golmok then RAINBOW else colors
		bottlesInIce(m, at * CFrame.new(0, lift + H, 0), bottleColors, if golmok then 6 else 4, L / 2 - 0.4, if golmok then 1 else 0.9)
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
