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

-- the user's ice picture on every face of a square ice cube (2026-10-29 (9),
-- all buckets since (10); docs/04_ART/textures/drinks/ice_texture.png)
local ICE_TEXTURE = "rbxassetid://123768039122634"
local function iceSkin(cube: BasePart, transparency: number)
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local d = Instance.new("Decal")
		d.Face = face
		d.Texture = ICE_TEXTURE
		d.Transparency = transparency
		d.Parent = cube
	end
end

-- One square ice cube, the same in every bucket (the VIP tray cube, user
-- 2026-10-29 (13)): 0.21–0.28 wide, pale, 20 % see-through, the ice picture
-- on every face. cf = its centre (it is turned at random here).
local ICE_RND = Random.new()
local function iceCube(model: Instance, cf: CFrame, scale: number?): (BasePart, number)
	local s = ICE_RND:NextNumber(0.21, 0.28) * (scale or 1)
	local cube = part(model :: Model, "IceCube", Vector3.new(s, s, s),
		cf * CFrame.Angles(ICE_RND:NextNumber(-0.5, 0.5), ICE_RND:NextNumber(0, 1.5), ICE_RND:NextNumber(-0.5, 0.5)),
		Color3.fromRGB(225, 238, 255), Enum.Material.SmoothPlastic, nil, 0.2)
	iceSkin(cube, 0.2)
	return cube, s
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
			-- (see-through plastic, not Glass: Glass showed the wall behind but hid
			-- the neon ice, the cubes and the bottles inside, user 2026-10-29 (12))
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(225, 240, 252)
			p.Transparency = 0.7
			p.Reflectance = 0.3
			-- a bright lip round the rim (small segments: a ring cannot be hollow)
			for i = 0, 15 do
				local a = i * math.pi * 2 / 16
				part(m :: Model, "PailRim", Vector3.new(0.5, 0.06, 0.08), at * CFrame.new(math.cos(a) * D_TOP * 0.49, H_PAIL - 0.03, math.sin(a) * D_TOP * 0.49) * CFrame.Angles(0, -a + math.pi / 2, 0),
					Color3.fromRGB(240, 250, 255), Enum.Material.SmoothPlastic, nil, 0.15)
			end
			local inner = mesh:Clone()
			inner.Name = "PailInner"
			inner.Size = Vector3.new(D_TOP * 0.9, H_PAIL * 0.86, D_TOP * 0.9)
			inner.CFrame = at * CFrame.new(0, H_PAIL * 0.12 + H_PAIL * 0.43, 0) * mesh.CFrame.Rotation
			inner.Material = Enum.Material.SmoothPlastic
			inner.Color = Color3.fromRGB(205, 228, 248)
			inner.Transparency = 0.75
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
	-- (the shared VIP-size cube since 2026-10-29 (13): six of them, two in each gap)
	for i = 1, 6 do
		local a = (math.floor((i - 1) / 2) + 0.5) * math.pi * 2 / 3 + (if i % 2 == 0 then 0.35 else -0.35)
		local r = if i % 2 == 0 then 0.62 else 0.42
		iceCube(m, at * CFrame.new(math.cos(a) * r, fill + 0.12, math.sin(a) * r))
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
-- A round neon line of four curved beams (a beam bends between two attachments
-- along their X axes; 0.5523 r makes each quarter a circle arc). centre's Y
-- axis is the ring's axis.
local function beamRing(holder: BasePart, centre: CFrame, r: number, color: Color3, width: number, transparency: number?)
	local atts = {}
	for i = 0, 3 do
		local a = i * math.pi / 2
		local att = Instance.new("Attachment")
		att.Name = "RingPoint"
		att.Parent = holder
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		att.WorldCFrame = centre * CFrame.fromMatrix(pos, tangent, Vector3.yAxis)
		atts[i] = att
	end
	for i = 0, 3 do
		local b = Instance.new("Beam")
		b.Name = "LEDRing"
		b.Attachment0 = atts[i]
		b.Attachment1 = atts[(i + 1) % 4]
		b.CurveSize0 = 0.5523 * r
		b.CurveSize1 = 0.5523 * r
		b.Width0 = width
		b.Width1 = width
		b.Segments = 12
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color)
		b.Transparency = NumberSequence.new(transparency or 0)
		b.Parent = holder
	end
end

-- A neon arc of curved beams round the axis of centre (Y), from angle a0 to
-- a1 in degrees (x = cos, z = sin), cut into pieces of at most 90 degrees.
local function arcBeam(holder: BasePart, centre: CFrame, r: number, a0: number, a1: number, color: Color3, width: number)
	local n = math.ceil((a1 - a0) / 90)
	local step = math.rad((a1 - a0) / n)
	local atts = {}
	for i = 0, n do
		local a = math.rad(a0) + i * step
		local att = Instance.new("Attachment")
		att.Name = "ArcPoint"
		att.Parent = holder
		att.WorldCFrame = centre * CFrame.fromMatrix(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), Vector3.new(-math.sin(a), 0, math.cos(a)), Vector3.yAxis)
		atts[i] = att
	end
	local handle = 4 / 3 * math.tan(step / 4) * r
	for i = 0, n - 1 do
		local b = Instance.new("Beam")
		b.Name = "LEDArc"
		b.Attachment0, b.Attachment1 = atts[i], atts[i + 1]
		b.CurveSize0, b.CurveSize1 = handle, handle
		b.Width0, b.Width1 = width, width
		b.Segments = 12
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 6
		b.Color = ColorSequence.new(color)
		b.Parent = holder
	end
end

-- VIP tray C v2 (user 2026-10-29 (8)): a two-step lit podium with a full yellow
-- LED line round each step, the bottles standing loosely (not in a row) in a
-- clear round glass case with a few square ice cubes, cyan LED rings all the
-- way round the case (the two side "wings" joined up), no lasers.
local function vipTrayC(m: Model, at: CFrame, key: string, colors: {Color3}): number
	local DARK = Color3.fromRGB(18, 18, 24)
	local YELLOW = Color3.fromRGB(255, 200, 70)
	local CYAN = Color3.fromRGB(110, 200, 255)
	local S1D, S2D, SH = 3.3, 2.85, 0.55 -- step diameters, step height
	cyl(m, "TrayBase", S1D, SH, at * CFrame.new(0, SH / 2, 0), DARK, Enum.Material.SmoothPlastic)
	-- the top step is sunk in the middle: a lower body, a rim ring round the
	-- edge, and the lit disc in the dip (user 2026-10-29 (9))
	local DIP = 0.08
	cyl(m, "TrayStep", S2D, SH - DIP, at * CFrame.new(0, SH + (SH - DIP) / 2, 0), DARK, Enum.Material.SmoothPlastic)
	local RIM_W = 0.16
	for i = 0, 17 do
		local a = i * math.pi * 2 / 18
		local r = S2D / 2 - RIM_W / 2
		part(m, "TrayRim", Vector3.new(2 * math.pi * r / 18 + 0.04, DIP, RIM_W), at * CFrame.new(math.cos(a) * r, SH * 2 - DIP / 2, math.sin(a) * r) * CFrame.Angles(0, -a + math.pi / 2, 0), DARK)
	end
	-- one LED line per step: a thin neon disc a hair wider than the step shows only as a ring
	cyl(m, "LEDLine", S1D + 0.04, 0.035, at * CFrame.new(0, SH * 0.6, 0), YELLOW, Enum.Material.Neon)
	cyl(m, "LEDLine", S2D + 0.04, 0.035, at * CFrame.new(0, SH * 1.6, 0), YELLOW, Enum.Material.Neon)
	local floorY = SH * 2 - DIP
	local top = cyl(m, "LitTop", S2D - 2 * RIM_W, 0.04, at * CFrame.new(0, floorY + 0.02, 0), Color3.fromRGB(225, 238, 255), Enum.Material.Neon)
	light(top, Color3.fromRGB(200, 225, 255), 7, 1.2)
	-- the glass case round the whole podium, from the table up: two shells like
	-- the clear tier-2 bottles (an outer one and an inner one a little smaller
	-- and lower), so the wall reads as thick glass (user 2026-10-29 (10)).
	-- See-through plastic: Glass hides the see-through ice behind it.
	local GR, GTOP, WALL = S1D / 2 + 0.12, SH * 2 + 2.1, 0.08
	local glass = cyl(m, "GlassCase", GR * 2, GTOP, at * CFrame.new(0, GTOP / 2, 0), Color3.fromRGB(215, 235, 255), Enum.Material.SmoothPlastic, 0.8)
	glass.Reflectance = 0.3
	local inner = cyl(m, "GlassInner", (GR - WALL) * 2, GTOP - 0.16, at * CFrame.new(0, 0.04 + (GTOP - 0.16) / 2, 0), Color3.fromRGB(200, 226, 250), Enum.Material.SmoothPlastic, 0.84)
	inner.Reflectance = 0.2
	beamRing(glass, at * CFrame.new(0, GTOP, 0), GR - WALL / 2, Color3.fromRGB(235, 245, 255), 0.06, 0.15) -- the rim
	-- cyan halo behind the bottles: three arches standing upright (legs from
	-- the podium top, a round top), each a little bigger and further back
	-- (user sketch 2026-10-29 (10); the rings round the glass are gone)
	local function arch(R: number, y0: number, yTop: number, z: number)
		local yL = yTop - R
		local pts = {
			{ Vector3.new(-R, y0, z), Vector3.yAxis }, { Vector3.new(-R, yL, z), Vector3.yAxis },
			{ Vector3.new(0, yTop, z), Vector3.xAxis },
			{ Vector3.new(R, yL, z), -Vector3.yAxis }, { Vector3.new(R, y0, z), -Vector3.yAxis },
		}
		local atts = {}
		for i, pt in ipairs(pts) do
			local att = Instance.new("Attachment")
			att.Name = "HaloPoint"
			att.Parent = glass
			att.WorldCFrame = at * CFrame.fromMatrix(pt[1], pt[2], Vector3.zAxis:Cross(pt[2]).Unit)
			atts[i] = att
		end
		for i = 1, 4 do
			local bm = Instance.new("Beam")
			bm.Name = "Halo"
			bm.Attachment0 = atts[i]
			bm.Attachment1 = atts[i + 1]
			local curved = i == 2 or i == 3
			bm.CurveSize0 = if curved then 0.5523 * R else 0
			bm.CurveSize1 = if curved then 0.5523 * R else 0
			bm.Width0, bm.Width1 = 0.08, 0.08
			bm.Brightness = 4
			bm.Segments = if curved then 12 else 1
			bm.FaceCamera = true
			bm.LightEmission = 1
			bm.LightInfluence = 0
			bm.Color = ColorSequence.new(CYAN)
			bm.Parent = glass
		end
	end
	for k = 0, 2 do
		arch(1.95 + k * 0.25, SH * 2, 4.2 + k * 0.4, 0.6 + k * 0.18)
	end	-- bottles stood loosely: one near the middle, four round it, each turned and leaning a little
	local rnd = Random.new()
	for i = 1, 5 do
		local pos
		if i == 3 then
			pos = Vector3.new(rnd:NextNumber(-0.15, 0.15), 0, rnd:NextNumber(-0.1, 0.2))
		else
			local k = if i < 3 then i - 1 else i - 2 -- 0..3
			local a = math.rad(45 + k * 90 + rnd:NextNumber(-20, 20))
			local r = rnd:NextNumber(0.62, 0.78)
			pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		local outward = if pos.Magnitude > 0.01 then pos.Unit else Vector3.zAxis
		local lean = CFrame.fromAxisAngle(Vector3.yAxis:Cross(outward).Unit, math.rad(rnd:NextNumber(3, 9)))
		local base = at * CFrame.new(pos + Vector3.new(0, floorY, 0)) * lean * CFrame.Angles(0, rnd:NextNumber(-0.6, 0.6), 0)
		BottleShapes.add(m, base, key, colors[(i - 1) % #colors + 1], if i == 3 then 0.66 else 0.6)
	end
	-- a few square ice cubes, barely see-through, with the user's ice picture
	-- on every face (2026-10-29 (9), docs/04_ART/textures/drinks/ice_texture.png)
	-- (in the gaps between the outer bottles, near the edge, so they show)
	for i = 1, 8 do
		local s = rnd:NextNumber(0.45, 0.6)
		local a, r = math.rad((i - 1) * 45 + rnd:NextNumber(-12, 12)), rnd:NextNumber(0.85, 1.0)
		local cube = part(m, "IceCube", Vector3.new(s, s, s),
			at * CFrame.new(math.cos(a) * r, floorY + s / 2 + rnd:NextNumber(0, 0.25), math.sin(a) * r) * CFrame.Angles(rnd:NextNumber(0, 1.5), rnd:NextNumber(0, 1.5), rnd:NextNumber(0, 1.5)),
			Color3.fromRGB(225, 238, 255), Enum.Material.SmoothPlastic, nil, 0.12)
		iceSkin(cube, 0.12)
	end
	-- the white neon "VIP" over the case (bars, read from the front = -Z)
	local WHITE_NEON = Color3.fromRGB(255, 255, 255)
	local cy, h, w = 5.0, 0.9, 0.11
	local function bar(x0: number, y0: number, x1: number, y1: number)
		local a, b = Vector3.new(-x0, cy + y0, -0.2), Vector3.new(-x1, cy + y1, -0.2)
		local mid, dir = (a + b) / 2, b - a
		part(m, "VIPLetter", Vector3.new(w, dir.Magnitude + w, w), at * CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), dir.Unit), WHITE_NEON, Enum.Material.Neon)
	end
	local hh = h / 2
	bar(-0.95, hh, -0.65, -hh) bar(-0.35, hh, -0.65, -hh) -- V
	bar(0, hh, 0, -hh) -- I
	bar(0.4, hh, 0.4, -hh) bar(0.4, hh, 0.85, hh) bar(0.85, hh, 0.85, 0) bar(0.4, 0, 0.85, 0) -- P
	light(part(m, "VIPSignLight", Vector3.new(0.2, 0.2, 0.2), at * CFrame.new(0, cy, 0), WHITE_NEON, nil, nil, 1), Color3.fromRGB(230, 240, 255), 6, 1.2)
	return cy + hh
end

-- Ice-block box (user photo 2026-10-29 (25), sample only): a long box of
-- clear rippled ice on a black base with "OHU" in white neon on its front
-- (-Z), a white neon floor inside, ice cubes, and ten bottles standing in two
-- rows, their necks above the rim. Returns the height.
function DrinkBucket.iceBox(m: Model, at: CFrame, key: string, colors: {Color3}): number
	local L, W, H, BH = 4.8, 2.2, 1.8, 0.42 -- (bigger than the tier-3 boat, user 2026-10-29 (26); walls 1.3 -> 1.8, 2026-10-29 (30)) -- box length / depth / height, base height
	local BLACK = Color3.fromRGB(14, 14, 18)
	local WHITE = Color3.fromRGB(255, 255, 255)
	-- (a light set under the base so it glows out onto the table round it, user 2026-10-29 (29))
	local LIFT = 0.1
	local under = part(m, "IceBoxUnderGlow", Vector3.new(L + 0.24, LIFT, W + 0.24), at * CFrame.new(0, LIFT / 2, 0), Color3.fromRGB(255, 235, 250), Enum.Material.Neon, nil, 0.1)
	light(under, Color3.fromRGB(255, 225, 245), 7, 2)
	at = at * CFrame.new(0, LIFT, 0)
	local base = part(m, "IceBoxBase", Vector3.new(L + 0.3, BH, W + 0.3), at * CFrame.new(0, BH / 2, 0), BLACK, Enum.Material.Glass)
	base.Reflectance = 0.25
	-- "OHU" in white neon bars on the base front
	do
		local cy, h, w, z = BH / 2, 0.26, 0.045, -(W + 0.3) / 2 - 0.02
		local function bar(x0: number, y0: number, x1: number, y1: number)
			local a, b = Vector3.new(-x0, cy + y0, z), Vector3.new(-x1, cy + y1, z)
			local mid, dir = (a + b) / 2, b - a
			part(m, "OHULetter", Vector3.new(w, dir.Magnitude + w, 0.03), at * CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), dir.Unit), WHITE, Enum.Material.Neon)
		end
		local hh = h / 2
		-- O
		bar(-0.62, hh, -0.38, hh) bar(-0.62, -hh, -0.38, -hh) bar(-0.62, hh, -0.62, -hh) bar(-0.38, hh, -0.38, -hh)
		-- H
		bar(-0.13, hh, -0.13, -hh) bar(0.13, hh, 0.13, -hh) bar(-0.13, 0, 0.13, 0)
		-- U
		bar(0.38, hh, 0.38, -hh) bar(0.62, hh, 0.62, -hh) bar(0.38, -hh, 0.62, -hh)
		local glow = part(m, "OHUGlow", Vector3.new(0.2, 0.2, 0.2), at * CFrame.new(0, cy, z - 0.1), WHITE, nil, nil, 1)
		light(glow, Color3.fromRGB(235, 240, 255), 4, 0.8)
	end
	-- white neon floor inside, lighting the ice from below
	local floorY = BH
	-- (a white neon block at the bottom like the tier-3 boat's glow, user 2026-10-29 (27))
	local GH = H * 0.42 -- (a taller glow block, the ice and bottles on top of it, 2026-10-29 (30))
	local glowFloor = part(m, "IceBoxGlow", Vector3.new(L - 0.3, GH, W - 0.3), at * CFrame.new(0, floorY + GH / 2, 0), Color3.fromRGB(235, 242, 255), Enum.Material.Neon)
	light(glowFloor, Color3.fromRGB(255, 230, 245), 10, 2.6) -- (brighter: it lights the ice through the walls)
	-- the rippled ice walls: four clear slabs with the ice picture tiled on them
	local T = 0.16
	local function wall(size: Vector3, cf: CFrame)
		local p = part(m, "IceWall", size, at * cf, Color3.fromHSV(0.75, 0.04, 0.8), Enum.Material.SmoothPlastic, nil, 0.7) -- (lightness 80 %, 2026-10-29 (30))
		p.Reflectance = 0.15
		for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
			local t = Instance.new("Texture")
			t.Face = face
			t.Texture = ICE_TEXTURE
			t.StudsPerTileU, t.StudsPerTileV = 0.9, 0.9
			t.Transparency = 0.55
			t.Parent = p
		end
	end
	wall(Vector3.new(L, H, T), CFrame.new(0, floorY + H / 2, -W / 2 + T / 2))
	wall(Vector3.new(L, H, T), CFrame.new(0, floorY + H / 2, W / 2 - T / 2))
	wall(Vector3.new(T, H, W - 2 * T), CFrame.new(-L / 2 + T / 2, floorY + H / 2, 0))
	wall(Vector3.new(T, H, W - 2 * T), CFrame.new(L / 2 - T / 2, floorY + H / 2, 0))
	-- ice heaped on the glowing floor (more of it, two layers, user 2026-10-29 (26))
	local rnd = Random.new()
	-- (filled up to near the rim: three layers over the glow block)
	-- (half as many, 1.3x bigger, user 2026-10-29 (28))
	for i = 1, 55 do
		local layer = math.floor((i - 1) / 19) * 0.36
		iceCube(m, at * CFrame.new(rnd:NextNumber(-L / 2 + 0.32, L / 2 - 0.32), floorY + GH + 0.16 + layer + rnd:NextNumber(0, 0.15), rnd:NextNumber(-W / 2 + 0.3, W / 2 - 0.3)), 1.3)
	end
	-- five bottles stood loosely in the ice like the other buckets: spread
	-- along the box, each a little off the line, turned and leaning
	for i = 1, 5 do
		local x = -L / 2 + 0.75 + (i - 1) * (L - 1.5) / 4 + rnd:NextNumber(-0.15, 0.15)
		local z = rnd:NextNumber(-0.35, 0.35)
		local lean = CFrame.fromAxisAngle(Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)).Unit, math.rad(rnd:NextNumber(3, 9)))
		local base2 = at * CFrame.new(x, floorY + GH, z) * lean * CFrame.Angles(0, rnd:NextNumber(-0.7, 0.7), 0)
		-- (as big as the VIP tray's bottles, 1.5x, user 2026-10-29 (28))
		BottleShapes.add(m, base2, key, colors[(i - 1) % #colors + 1], (if i == 3 then 0.66 else 0.6) * 1.5)
	end
	-- a soft aura rising out of the box (like the VIP tray's)
	local src = part(m, "AuraSource", Vector3.new(L - 0.4, 0.1, W - 0.4), at * CFrame.new(0, floorY + 0.3, 0), Color3.new(1, 1, 1), nil, nil, 1)
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Texture = "rbxasset://textures/particles/smoke_main.dds"
	aura.Color = ColorSequence.new(Color3.fromRGB(255, 225, 245), Color3.fromRGB(235, 240, 255))
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
	aura.Lifetime = NumberRange.new(2.2, 3.2)
	aura.Rate = 12
	aura.Speed = NumberRange.new(0.5, 0.9)
	aura.SpreadAngle = Vector2.new(12, 12)
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-20, 20)
	aura.EmissionDirection = Enum.NormalId.Top
	aura.Parent = src	return floorY + H + LIFT
end

function DrinkBucket.vipTray(m: Model, at: CFrame, style: string, key: string, colors: {Color3}): number
	-- ("C2" = the glass case version, D-490..D-492; the user went back to C, 2026-10-29 (11))
	if style == "C2" then return vipTrayC(m, at, key, colors) end
	local DARK = Color3.fromRGB(18, 18, 24)
	-- (C: the podium 0.35 higher, user 2026-10-29 (11); everything on it moves up)
	local LIFT = if style == "C" then 0.35 else 0
	-- (C wider, the bottles further apart, user 2026-10-29 (12))
	local BD = if style == "C" then 3.9 else 3.2 -- base diameter
	local SPREAD = if style == "C" then 1.2 else 0.95
	-- "C" (the user's mix, 2026-10-29 (3)): A's ring, lit top and wings on a dark
	-- round base dressed like B (yellow light bricks on the front corners, warm window)
	if style == "A" or style == "C" then
		-- (C: the tier-3 boat's gold metal, user 2026-10-29 (14))
		local trayBase = cyl(m, "TrayBase", BD, 0.55 + LIFT, at * CFrame.new(0, (0.55 + LIFT) / 2, 0), if style == "C" then GOLD else DARK, if style == "C" then Enum.Material.Metal else Enum.Material.SmoothPlastic)
		-- RGB ring: coloured neon segments round the top edge (not on C, user 2026-10-29 (4))
		for i = 0, (if style == "C" then -1 else 11) do
			local a = i * math.pi * 2 / 12
			local seg = part(m, "RGBRing", Vector3.new(0.85, 0.1, 0.18), at * CFrame.new(math.cos(a) * 1.52, 0.6, math.sin(a) * 1.52) * CFrame.Angles(0, -a + math.pi / 2, 0),
				RAINBOW[i % #RAINBOW + 1], Enum.Material.Neon, nil, 0)
			if i % 3 == 0 then light(seg, RAINBOW[i % #RAINBOW + 1], 5, 1) end
		end
		cyl(m, "LitTop", BD - 0.5, 0.05, at * CFrame.new(0, 0.58 + LIFT, 0), Color3.fromRGB(225, 238, 255), Enum.Material.Neon)
		if style == "C" then
			-- yellow LED lines all the way round the back, open at the front; the
			-- open ends step back row by row so the cut reads as a slant from the
			-- front (user 2026-10-29 (12)). Front = -Z = 270 degrees.
			for row = 0, 3 do
				local gap = 46 - row * 8 -- the top row reaches furthest round to the front
				arcBeam(trayBase, at * CFrame.new(0, 0.15 + row * 0.22, 0), BD / 2 + 0.02, 270 + gap, 630 - gap, Color3.fromRGB(255, 225, 60), 0.05)
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
					-- (C: bigger, user 2026-10-29 (13): taller, bowing further out, wider apart, thicker)
					local WH, WB, WS = if style == "C" then 2.7 else 1.9, if style == "C" then 0.6 else 0.4, if style == "C" then 0.22 else 0.16
					local pnt = Vector3.new(side * (BD / 2 - 0.05 + k * WS + WB * math.sin(math.pi * t)), 0.6 + LIFT + WH * t, -0.2 + k * 0.12)
					if prev then
						local mid, dir = (prev + pnt) / 2, pnt - prev
						local WT = if style == "C" then 0.055 else 0.035
						part(m, "Wing", Vector3.new(WT, dir.Magnitude + 0.02, WT), at * CFrame.lookAt(mid, mid + Vector3.new(0, 0, 1), dir.Unit), -- (thinner, user 2026-10-29 (6))
							Color3.fromRGB(110, 170, 255), Enum.Material.Neon, nil, 0)
					end
					prev = pnt
				end
			end
		end
		-- (no lasers on C, user 2026-10-29 (11))
		if style ~= "C" then
			for _, p in ipairs({ { -1.2, 0.9 }, { 1.2, 0.9 }, { -1.3, -0.5 }, { 1.3, -0.5 } }) do laser(m, at, p[1], p[2], -p[1] * 2) end
		end
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
	-- (C: 1.5 times bigger, user 2026-10-29 (14); staggered front / back so the
	-- bigger bottles fit the podium: the middle at the back, its neighbours in
	-- front, the ends between)
	local BS = if style == "C" then 1.5 else 1
	for i = 1, 5 do
		local u = (i - 3) / 2
		local z = if style == "C" then (if i == 3 then 0.45 elseif i == 2 or i == 4 then -0.3 else 0.1) else 0.15 + math.abs(u) * -0.35
		local base = at * CFrame.new(u * (if style == "C" then 1.3 else SPREAD), 0.6 + LIFT, z) * CFrame.Angles(0, 0, math.rad(-u * 8))
		BottleShapes.add(m, base, key, colors[(i - 1) % #colors + 1], (if i == 3 then 0.66 else 0.6) * BS)
	end
	if style == "C" then
		-- textured ice cubes on the lit top: a row in front of the bottles, some
		-- behind (half size, 20 % see-through, user 2026-10-29 (12))
		-- (more ice, user 2026-10-29 (13)): two rows in front, a row behind, a few between the bottles
		local rnd = Random.new()
		local spots = {}
		-- (in front of the bigger bottles since 2026-10-29 (14); the lit top is 1.7 round)
		for i = 0, 6 do table.insert(spots, { -0.95 + i * 0.32, -1.38, 0 }) end
		for i = 0, 7 do table.insert(spots, { -1.2 + i * 0.34, -1.12, 0 }) end
		for i = 0, 6 do table.insert(spots, { -1.0 + i * 0.33, 1.25, 0 }) end
		for i = 0, 3 do table.insert(spots, { -0.9 + i * 0.6, -1.25, 0.24 }) end -- (a second layer on the front rows)
		for _, xz in ipairs(spots) do
			iceCube(m, at * CFrame.new(xz[1] + rnd:NextNumber(-0.08, 0.08), 0.6 + LIFT + 0.12 + xz[3], xz[2] + rnd:NextNumber(-0.06, 0.06)))
		end
		-- a soft aura rising from the podium (user 2026-10-29 (13)): faint glowing
		-- haze drifting up off the lit top, pale blue-white, never thick
		local src = part(m, "AuraSource", Vector3.new(BD - 0.4, 0.1, BD - 0.4), at * CFrame.new(0, 0.62 + LIFT, 0), Color3.new(1, 1, 1), nil, nil, 1)
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Texture = "rbxasset://textures/particles/smoke_main.dds"
		aura.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255), Color3.fromRGB(255, 235, 200))
		aura.LightEmission = 1
		aura.LightInfluence = 0
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		aura.Lifetime = NumberRange.new(2.2, 3.2)
		aura.Rate = 10
		aura.Speed = NumberRange.new(0.5, 0.9)
		aura.SpreadAngle = Vector2.new(12, 12)
		aura.Rotation = NumberRange.new(0, 360)
		aura.RotSpeed = NumberRange.new(-20, 20)
		aura.EmissionDirection = Enum.NormalId.Top
		aura.Parent = src
	end
	if style == "C" then
		-- a white neon "VIP" floating over the bottles (user 2026-10-29 (4))
		-- (neon bars, no border, user 2026-10-29 (5)): letters 0.9 high in the
		-- plane facing the front (-Z), each stroke a thin white neon block
		-- (gold like the podium, user 2026-10-29 (14); neon so it still glows; over
		-- the 1.5x bottles)
		local WHITE_NEON = GOLD
		local cy, h, w = 4.3 + LIFT + 1.6, 0.9, 0.11
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
			-- (tier 3: white neon only, no colours, user 2026-10-29 (12))
			part(m, "IceGlow", Vector3.new(L / n - 0.02, gh, W - 0.15), at * CFrame.new(x, lift + 0.1 + gh / 2, 0), if tier3 then Color3.fromRGB(235, 242, 255) else RAINBOW[(i - 1) % #RAINBOW + 1], Enum.Material.Neon, nil, 0)
		end
		if tier3 then
			-- clear ice cubes (80 % see-through) at any angle on the low glow
			local rnd = Random.new(31)
			-- (the shared VIP-size cube since 2026-10-29 (13), heaped two deep)
			for _ = 1, 30 do
				iceCube(m, at * CFrame.new(rnd:NextNumber(-L / 2 + 0.2, L / 2 - 0.2), lift + 0.1 + H * 0.28 + rnd:NextNumber(0.12, 0.45), rnd:NextNumber(-W / 2 + 0.2, W / 2 - 0.2)))
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
