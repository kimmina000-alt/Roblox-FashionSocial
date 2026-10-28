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
function DrinkBucket.iceBucket(m: Instance, at: CFrame, bottles: {{ key: string, color: Color3 }}, glow: string?, glass: boolean?): number
	glow = glow or DrinkBucket.Glow
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local mesh = art and art:FindFirstChild("IceBucket")
	if mesh and mesh:IsA("BasePart") then
		-- (the plain store cup 3478283525 stretched into a pail: smooth, wide at the top)
		local p = mesh:Clone()
		p.Size = Vector3.new(D_TOP, H_PAIL, D_TOP)
		p.CFrame = at * CFrame.new(0, H_PAIL / 2, 0) * mesh.CFrame.Rotation
		p.Name = "Pail"
		-- brushed aluminium (user 2026-10-28 (6)); tier 2 the same pail in clear glass (2026-10-29)
		if glass then
			-- (like the clear bottles, 2026-10-29 (2)): a very clear outer shell and
			-- a slightly smaller inner shell whose rim sits lower and whose floor is
			-- raised, so the wall and the thick base read as glass
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(225, 240, 252)
			p.Transparency = 0.62
			p.Reflectance = 0.3
			-- a bright lip round the rim (small segments: a ring cannot be hollow)
			for i = 0, 15 do
				local a = i * math.pi * 2 / 16
				part(m :: Model, "PailRim", Vector3.new(0.5, 0.06, 0.08), at * CFrame.new(math.cos(a) * D_TOP * 0.49, H_PAIL - 0.03, math.sin(a) * D_TOP * 0.49) * CFrame.Angles(0, -a + math.pi / 2, 0),
					Color3.fromRGB(240, 250, 255), Enum.Material.Glass, nil, 0.15)
			end
			local inner = mesh:Clone()
			inner.Name = "PailInner"
			inner.Size = Vector3.new(D_TOP * 0.9, H_PAIL * 0.86, D_TOP * 0.9)
			inner.CFrame = at * CFrame.new(0, H_PAIL * 0.12 + H_PAIL * 0.43, 0) * mesh.CFrame.Rotation
			inner.Material = Enum.Material.Glass
			inner.Color = Color3.fromRGB(205, 228, 248)
			inner.Transparency = 0.55
			inner.Reflectance = 0.2
			inner.Anchored, inner.CanCollide, inner.CanTouch, inner.CanQuery, inner.CastShadow = true, false, false, false, false
			inner.Parent = m
		else
			p.Material = Enum.Material.Metal
			p.Color = Color3.fromRGB(150, 155, 163)
			p.Reflectance = 0.6
		end
		p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, false
		p.Parent = m
	else
		for i, ring in ipairs({ { 0, 0.45, 1.25 }, { 0.43, 0.8, 1.42 }, { 0.78, 1.1, 1.56 }, { 1.08, H_PAIL, D_TOP } }) do
			local p = cyl(m :: Model, "Pail" .. i, ring[3], ring[2] - ring[1], at * CFrame.new(0, (ring[1] + ring[2]) / 2, 0), Color3.fromRGB(205, 205, 212), Enum.Material.Metal)
			p.Reflectance = 0.25
		end
	end
	-- one big glowing ice block filling the pail up near the rim (user 2026-10-28 (10))
	local glowIce = glow == "ice"
	local fill = H_PAIL * 0.8
	-- (a round block that fits the round pail: a square one stood out through its sides)
	local block = cyl(m :: Model, "IceBlock", D_TOP * 0.66, fill - 0.15, at * CFrame.new(0, 0.15 + (fill - 0.15) / 2, 0),
		if glowIce then Color3.fromRGB(220, 240, 255) else ICE, if glowIce then Enum.Material.Neon else Enum.Material.Glass, if glowIce then 0.45 else 0.35)
	if glowIce then light(block, Color3.fromRGB(200, 230, 255), 7, 1.6) end
	-- clear square ice cubes on top, in the gaps between the drinks (user 2026-10-28 (13))
	for i = 1, 3 do
		local a = (i - 0.5) * math.pi * 2 / 3
		local s = 0.41 -- (2/3, user 2026-10-28 (15))
		part(m :: Model, "IceCube", Vector3.new(s, s, s), at * CFrame.new(math.cos(a) * 0.5, fill + s * 0.45, math.sin(a) * 0.5) * CFrame.Angles(0.25, a, 0.15),
			Color3.fromRGB(205, 232, 255), Enum.Material.SmoothPlastic, nil, 0.5) -- (see-through square cubes; the transparency had gone into the shape argument and made balls, user 2026-10-28 (14))
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

-- VIP trays (user concepts 2026-10-29, docs/04_ART/references/vip_bucket_concepts.png):
-- "A" a round tray with an RGB ring, a lit top, neon wing guards and a light
-- window; "B" a horseshoe tray with rows of light bricks. Both: five bottles
-- standing in an arc and four green lasers shooting up from the sides.
-- Returns the model's height.
local LASER = Color3.fromRGB(60, 255, 90)
-- (the club's DJ laser look, user 2026-10-29 (3): a Beam with the soft-edge
-- texture, thin at the dot, fading out along its length; ClubLightsController)
local SOFT_BEAM = "rbxassetid://129498465489506"
local function laser(m: Model, at: CFrame, x: number, z: number, lean: number)
	-- (an invisible holder: the dot itself was taken away, user 2026-10-29 (5))
	local dot = part(m, "LaserDot", Vector3.new(0.16, 0.16, 0.16), at * CFrame.new(x, 0.62, z), LASER, Enum.Material.Neon, Enum.PartType.Ball, 1)
	local len = 16
	local a0 = Instance.new("Attachment")
	a0.Parent = dot
	local a1 = Instance.new("Attachment")
	a1.Position = (CFrame.Angles(0, 0, math.rad(lean)) * CFrame.new(0, len, 0)).Position
	a1.Parent = dot
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.08 -- (thinner and a little fainter than the club's, user 2026-10-29 (4))
	beam.Width1 = 0.22
	beam.Texture = SOFT_BEAM
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureLength = 1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Color = ColorSequence.new(LASER)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0.95) })
	beam.Parent = dot
end
function DrinkBucket.vipTray(m: Model, at: CFrame, style: string, key: string, colors: {Color3}): number
	local DARK = Color3.fromRGB(18, 18, 24)
	-- "C" (the user's mix, 2026-10-29 (3)): A's ring, lit top and wings on a dark
	-- round base dressed like B (yellow light bricks on the front corners, warm window)
	if style == "A" or style == "C" then
		cyl(m, "TrayBase", 3.2, 0.55, at * CFrame.new(0, 0.275, 0), DARK, Enum.Material.SmoothPlastic)
		-- RGB ring: coloured neon segments round the top edge (not on C, user 2026-10-29 (4))
		for i = 0, (if style == "C" then -1 else 11) do
			local a = i * math.pi * 2 / 12
			local seg = part(m, "RGBRing", Vector3.new(0.85, 0.1, 0.18), at * CFrame.new(math.cos(a) * 1.52, 0.6, math.sin(a) * 1.52) * CFrame.Angles(0, -a + math.pi / 2, 0),
				RAINBOW[i % #RAINBOW + 1], Enum.Material.Neon, nil, 0)
			if i % 3 == 0 then light(seg, RAINBOW[i % #RAINBOW + 1], 5, 1) end
		end
		cyl(m, "LitTop", 2.7, 0.05, at * CFrame.new(0, 0.58, 0), Color3.fromRGB(225, 238, 255), Enum.Material.Neon)
		if style == "C" then
			for row = 0, 3 do
				for _, range in ipairs({ { 206, 240 }, { 300, 334 } }) do
					for k = 0, 3 do
						local a = math.rad(range[1] + (k + (row % 2) * 0.5) * (range[2] - range[1]) / 4)
						part(m, "LightBrick", Vector3.new(0.3, 0.035, 0.03), -- (thinner, user 2026-10-29 (6))
							at * CFrame.new(math.cos(a) * 1.62, 0.1 + row * 0.11, math.sin(a) * 1.62) * CFrame.Angles(0, -a + math.pi / 2, 0),
							Color3.fromRGB(255, 200, 90), Enum.Material.Neon, nil, 0)
					end
				end
			end
			-- (no front window on C, user 2026-10-29 (4))
		else
			-- light slats round the side and a front window
			for i = 0, 17 do
				local a = i * math.pi * 2 / 18
				part(m, "Slat", Vector3.new(0.06, 0.32, 0.05), at * CFrame.new(math.cos(a) * 1.61, 0.27, math.sin(a) * 1.61) * CFrame.Angles(0, -a + math.pi / 2, 0),
					Color3.fromRGB(200, 225, 255), Enum.Material.Neon, nil, 0)
			end
			part(m, "FrontWindow", Vector3.new(0.9, 0.24, 0.05), at * CFrame.new(0, 0.27, -1.62), Color3.fromRGB(235, 245, 255), Enum.Material.Neon, nil, 0)
		end
		-- wing guards: three bent neon strips on each side
		-- (each wing: three ")"-shaped neon strips standing at the side, bowing outward)
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				local prev: Vector3? = nil
				for j = 0, 8 do
					local t = j / 8
					local pnt = Vector3.new(side * (1.55 + k * 0.16 + 0.4 * math.sin(math.pi * t)), 0.6 + 1.9 * t, -0.2 + k * 0.12)
					if prev then
						local mid, dir = (prev + pnt) / 2, pnt - prev
						part(m, "Wing", Vector3.new(0.035, dir.Magnitude + 0.02, 0.035), at * CFrame.lookAt(mid, mid + Vector3.new(0, 0, 1), dir.Unit), -- (thinner, user 2026-10-29 (6))
							Color3.fromRGB(110, 170, 255), Enum.Material.Neon, nil, 0)
					end
					prev = pnt
				end
			end
		end
		for _, p in ipairs({ { -1.2, 0.9 }, { 1.2, 0.9 }, { -1.3, -0.5 }, { 1.3, -0.5 } }) do laser(m, at, p[1], p[2], -p[1] * 2) end
	else
		-- horseshoe: a dark arc of blocks open at the back, a floor disc
		cyl(m, "TrayFloor", 2.6, 0.3, at * CFrame.new(0, 0.15, 0), Color3.fromRGB(34, 32, 40), Enum.Material.SmoothPlastic)
		for i = 0, 13 do
			local a = math.rad(200 + i * (140 / 13)) -- front half (screen front is -Z)
			local cf = at * CFrame.new(math.cos(a) * 1.55, 0.3, math.sin(a) * 1.55) * CFrame.Angles(0, -a + math.pi / 2, 0)
			part(m, "Horseshoe", Vector3.new(0.42, 0.6, 0.55), cf, DARK, Enum.Material.SmoothPlastic)
		end
		-- the two arms, and rows of light bricks on the curved front corners
		for _, side in ipairs({ -1, 1 }) do
			part(m, "Arm", Vector3.new(0.55, 0.6, 1.6), at * CFrame.new(side * 1.55, 0.3, 0.6), DARK, Enum.Material.SmoothPlastic)
		end
		for row = 0, 3 do
			for _, range in ipairs({ { 202, 238 }, { 302, 338 } }) do
				for k = 0, 3 do
					local a = math.rad(range[1] + (k + (row % 2) * 0.5) * (range[2] - range[1]) / 4)
					part(m, "LightBrick", Vector3.new(0.3, 0.08, 0.04),
						at * CFrame.new(math.cos(a) * 1.86, 0.12 + row * 0.13, math.sin(a) * 1.86) * CFrame.Angles(0, -a + math.pi / 2, 0),
						Color3.fromRGB(255, 200, 90), Enum.Material.Neon, nil, 0)
				end
			end
		end
		local win = part(m, "FrontWindow", Vector3.new(1.0, 0.26, 0.05), at * CFrame.new(0, 0.3, -1.84), Color3.fromRGB(255, 240, 210), Enum.Material.Neon, nil, 0)
		light(win, Color3.fromRGB(255, 190, 90), 7, 1.4)
		for _, p in ipairs({ { -1.55, 1.2 }, { 1.55, 1.2 }, { -1.55, 0.1 }, { 1.55, 0.1 } }) do laser(m, at, p[1], p[2], -p[1]) end
	end
	-- five bottles in an arc, the middle one tallest and furthest back
	for i = 1, 5 do
		local u = (i - 3) / 2
		local base = at * CFrame.new(u * 0.95, 0.6, 0.15 + math.abs(u) * -0.35) * CFrame.Angles(0, 0, math.rad(-u * 8))
		BottleShapes.add(m, base, key, colors[(i - 1) % #colors + 1], if i == 3 then 0.66 else 0.6)
	end
	if style == "C" then
		-- a white neon "VIP" floating over the bottles (user 2026-10-29 (4))
		-- (neon bars, no border, user 2026-10-29 (5)): letters 0.9 high in the
		-- plane facing the front (-Z), each stroke a thin white neon block
		local WHITE_NEON = Color3.fromRGB(255, 255, 255)
		local cy, h, w = 4.3, 0.9, 0.11
		local function bar(name: string, x0: number, y0: number, x1: number, y1: number)
			-- x is mirrored: the tray front faces -Z, so the viewer's right is -X
			local a, b = Vector3.new(-x0, cy + y0, -0.2), Vector3.new(-x1, cy + y1, -0.2)
			local mid, dir = (a + b) / 2, b - a
			part(m, name, Vector3.new(w, dir.Magnitude + w, w), at * CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), dir.Unit), WHITE_NEON, Enum.Material.Neon)
		end
		local hh = h / 2
		-- V (x -0.95 .. -0.35)
		bar("VIPLetter", -0.95, hh, -0.65, -hh)
		bar("VIPLetter", -0.35, hh, -0.65, -hh)
		-- I
		bar("VIPLetter", 0, hh, 0, -hh)
		-- P (stem, top, right, middle)
		bar("VIPLetter", 0.4, hh, 0.4, -hh)
		bar("VIPLetter", 0.4, hh, 0.85, hh)
		bar("VIPLetter", 0.85, hh, 0.85, 0)
		bar("VIPLetter", 0.4, 0, 0.85, 0)
		light(part(m, "VIPSignLight", Vector3.new(0.2, 0.2, 0.2), at * CFrame.new(0, cy, 0), WHITE_NEON, nil, nil, 1), Color3.fromRGB(230, 240, 255), 6, 1.2)
	end
	return 3.4
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
		-- tier 2 (user 2026-10-29): the tier-1 ice bucket in clear glass, three of the drink's bottles
		DrinkBucket.iceBucket(m, at, { { key = drinkKey, color = c }, { key = drinkKey, color = c }, { key = drinkKey, color = c } }, nil, true)
	elseif kind == "vip" or kind == "golmok" then
		-- VIP pass drinks and 골목 공방 (user 2026-10-29 (6)): tray C with five of the drink's bottles
		DrinkBucket.vipTray(m, at, "C", drinkKey, colors)
	else
		-- gold-framed LED boat: clear acrylic box on a U frame, rainbow ice
		-- (tier 3 "acrylic" since 2026-10-29: bigger, the rainbow blocks low,
		-- clear ice cubes heaped on them)
		local golmok = kind == "golmok"
		local tier3 = kind == "acrylic"
		local L = if golmok then 3.6 elseif tier3 then 3.4 else 2.6
		local W, H = if golmok or tier3 then 1.6 else 1.3, if golmok or tier3 then 1.4 else 1.2
		local lift = 0.45
		local mid = at * CFrame.new(0, lift + H / 2, 0)
		part(m, "Box", Vector3.new(L, H, W), mid, Color3.fromRGB(200, 215, 255), Enum.Material.SmoothPlastic, nil, 0.7)
		local floor = part(m, "LEDFloor", Vector3.new(L - 0.1, 0.08, W - 0.1), at * CFrame.new(0, lift + 0.05, 0), GOLD, Enum.Material.Neon, nil, 0)
		local n = if golmok then 6 else 3
		for i = 1, n do
			local x = -L / 2 + (i - 0.5) * L / n
			local gh = if tier3 then H * 0.28 else H * 0.55
			part(m, "IceGlow", Vector3.new(L / n - 0.02, gh, W - 0.15), at * CFrame.new(x, lift + 0.1 + gh / 2, 0), RAINBOW[(i - 1) % #RAINBOW + 1], Enum.Material.Neon, nil, 0)
		end
		if tier3 then
			-- clear ice cubes (80 % see-through) at any angle on the low glow
			local rnd = Random.new(31)
			for _ = 1, 14 do
				local s = rnd:NextNumber(0.32, 0.5)
				part(m, "IceCube", Vector3.new(s, s, s),
					at * CFrame.new(rnd:NextNumber(-L / 2 + 0.3, L / 2 - 0.3), lift + 0.1 + H * 0.28 + rnd:NextNumber(0.1, 0.55), rnd:NextNumber(-W / 2 + 0.3, W / 2 - 0.3))
						* CFrame.Angles(rnd:NextNumber(0, math.pi), rnd:NextNumber(0, math.pi), rnd:NextNumber(0, math.pi)),
					-- (faint neon: plain see-through cubes vanish behind the clear box)
					Color3.fromRGB(200, 230, 255), Enum.Material.Neon, nil, 0.8)
			end
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
