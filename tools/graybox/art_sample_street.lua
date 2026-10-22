-- Art comparison sample (D-102, user 2026-10-22): one street block in a
-- realistic look from the user's references (docs/04_ART/REFERENCES.md):
--   강남 사거리 + the east high-rise street + club front + construction site.
-- Run in the Studio command bar / MCP in Edit mode. MODE:
--   "day"    realistic materials, daytime (강남 road-view references)
--   "night"  same materials, night lighting (광안리 night, club neon)
--   "revert" back to the current blockout (every change is undone)
-- Nothing is deleted: changed parts keep their old look in attributes
-- (ArtOrig*), new detail parts go into Workspace.ArtSample_Street, the old
-- Lighting values are kept as Lighting attributes.

local MODE = ... or "day"

local BOX_MIN = Vector3.new(-40, -5, -170)
local BOX_MAX = Vector3.new(300, 220, 75)
local SAMPLE = "ArtSample_Street"
local Lighting = game:GetService("Lighting")

local function inBox(p: Vector3): boolean
	return p.X >= BOX_MIN.X and p.X <= BOX_MAX.X and p.Y >= BOX_MIN.Y and p.Y <= BOX_MAX.Y and p.Z >= BOX_MIN.Z and p.Z <= BOX_MAX.Z
end

---------------------------------------------------------------- revert
local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }

local function revert()
	for _, p in ipairs(workspace:GetDescendants()) do
		if (p.Name == "ArtSampleLight" or p.Name == "ArtSampleArt") and p.Parent then
			p:Destroy()
		elseif p:IsA("BasePart") and p:GetAttribute("ArtOrigMaterial") then
			p.Color = p:GetAttribute("ArtOrigColor")
			p.Material = Enum.Material[p:GetAttribute("ArtOrigMaterial")]
			p.Reflectance = p:GetAttribute("ArtOrigReflectance")
			p.Transparency = p:GetAttribute("ArtOrigTransparency")
			for _, k in ipairs({ "ArtOrigColor", "ArtOrigMaterial", "ArtOrigReflectance", "ArtOrigTransparency" }) do p:SetAttribute(k, nil) end
		end
	end
	local old = workspace:FindFirstChild(SAMPLE)
	if old then old:Destroy() end
	if Lighting:GetAttribute("ArtOrigSaved") then
		for _, k in ipairs(LIGHT_PROPS) do
			local v = Lighting:GetAttribute("ArtOrig_" .. k)
			if v ~= nil then (Lighting :: any)[k] = v end
			Lighting:SetAttribute("ArtOrig_" .. k, nil)
		end
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			for _, k in ipairs({ "Density", "Haze", "Glare", "Offset" }) do
				local v = Lighting:GetAttribute("ArtOrigAtm_" .. k)
				if v ~= nil then (atm :: any)[k] = v end
				Lighting:SetAttribute("ArtOrigAtm_" .. k, nil)
			end
			local c = Lighting:GetAttribute("ArtOrigAtm_Color")
			if c then atm.Color = c end
			local d = Lighting:GetAttribute("ArtOrigAtm_Decay")
			if d then atm.Decay = d end
			Lighting:SetAttribute("ArtOrigAtm_Color", nil)
			Lighting:SetAttribute("ArtOrigAtm_Decay", nil)
		end
		Lighting:SetAttribute("ArtOrigSaved", nil)
	end
	Lighting:SetAttribute("HoldClockTime", nil) -- day/night cycle runs again
end

revert()
if MODE == "revert" then
	return "reverted: the block is back to the current blockout"
end

---------------------------------------------------------------- helpers
local sample = Instance.new("Model")
sample.Name = SAMPLE

local function restyle(p: BasePart, color: Color3, material: Enum.Material, reflectance: number?, transparency: number?)
	if not p:GetAttribute("ArtOrigMaterial") then
		p:SetAttribute("ArtOrigColor", p.Color)
		p:SetAttribute("ArtOrigMaterial", p.Material.Name)
		p:SetAttribute("ArtOrigReflectance", p.Reflectance)
		p:SetAttribute("ArtOrigTransparency", p.Transparency)
	end
	p.Color = color
	p.Material = material
	p.Reflectance = reflectance or 0
	if transparency then p.Transparency = transparency end
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or sample
	return p
end

local function deco(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local C = {
	asphalt = Color3.fromRGB(56, 58, 62),
	paint = Color3.fromRGB(232, 232, 226),
	yellow = Color3.fromRGB(236, 186, 40),
	sidewalk = Color3.fromRGB(172, 165, 156),
	paving = Color3.fromRGB(150, 146, 140),
	granite = Color3.fromRGB(196, 194, 188),
	tactile = Color3.fromRGB(240, 196, 30),
	metal = Color3.fromRGB(78, 81, 86),
	metalLight = Color3.fromRGB(128, 131, 136),
	black = Color3.fromRGB(24, 24, 26),
	glass = Color3.fromRGB(92, 118, 138),
	concrete = Color3.fromRGB(168, 164, 156),
	hedge = Color3.fromRGB(58, 104, 52),
	craneYellow = Color3.fromRGB(240, 178, 30),
	hoarding = Color3.fromRGB(242, 242, 240),
	lineBlue = Color3.fromRGB(70, 90, 170),
}

---------------------------------------------------------------- 1. materials on what exists
local roots = { workspace:FindFirstChild("Hongdae_Layout"), workspace:FindFirstChild("Graybox_MainSocial") }
local changed = 0
for _, r in ipairs(roots) do
	if r then
		for _, p in ipairs(r:GetDescendants()) do
			if p:IsA("BasePart") and inBox(p.Position) and p.Size.Magnitude < 900 then
				local n = p.Name
				local model = p:FindFirstAncestorWhichIsA("Model")
				local mname = model and model.Name or ""
				local done = true
				if n == "Road" then restyle(p, C.asphalt, Enum.Material.Asphalt)
				elseif n == "LaneDash" or n == "Crosswalk" or n == "StopLine" or n == "JunctionLine" or n == "EdgeLine"
					or n == "Arrow" or n == "ArrowHead" or n == "ArrowTurn" then restyle(p, C.paint, Enum.Material.SmoothPlastic, 0, 0.08)
				elseif n == "CenterLine" or n == "SafetyStripe" or n == "SafetyEdge" then restyle(p, C.yellow, Enum.Material.SmoothPlastic, 0, 0.05)
				elseif n == "Sidewalk" then restyle(p, C.sidewalk, Enum.Material.Pavement)
				elseif n == "Planter" or n == "PlanterRing" then restyle(p, C.concrete, Enum.Material.Concrete)
				elseif n == "Hedge" then restyle(p, C.hedge, Enum.Material.LeafyGrass)
				elseif n == "LampPole" or n == "LampArm" or n == "SignalArm" then restyle(p, C.metal, Enum.Material.Metal)
				elseif n == "SignalPole" then restyle(p, C.metalLight, Enum.Material.Metal)
				elseif n == "SignalHead" then restyle(p, C.black, Enum.Material.Metal)
				elseif n == "LampHead" then restyle(p, Color3.fromRGB(250, 246, 236), Enum.Material.Glass, 0, 0.1)
				elseif n == "Bollard" then restyle(p, C.metal, Enum.Material.Metal)
				elseif n == "ShelterPost" then restyle(p, C.metalLight, Enum.Material.Metal)
				elseif n == "ShelterGlass" or n == "ShelterGlassTop" or n == "ShelterRoof" then restyle(p, Color3.fromRGB(200, 220, 228), Enum.Material.Glass, 0.1, 0.55)
				elseif n == "Step" and mname:find("SubwayExit") then restyle(p, C.granite, Enum.Material.Granite)
				elseif mname:find("BG_Tower") then
					if n == "Body" then restyle(p, C.glass, Enum.Material.Glass, 0.28, 0)
					elseif n == "FloorBand" or n == "WindowBand" then restyle(p, Color3.fromRGB(58, 63, 70), Enum.Material.Metal)
					elseif n == "Roof" then restyle(p, C.concrete, Enum.Material.Concrete)
					elseif n == "ShopGlass" then restyle(p, Color3.fromRGB(150, 170, 180), Enum.Material.Glass, 0.15, 0.35)
					else done = false end
				elseif mname == "02_Club" and n:find("^Wall") then
					-- KING CLUB / MUSE CLUB references: matte black facade
					restyle(p, C.black, Enum.Material.Slate)
				elseif mname:find("ConstructionSite") and n == "Hoarding" then restyle(p, C.hoarding, Enum.Material.SmoothPlastic)
				elseif mname:find("ConstructionSite") and n:find("^Crane") then
					restyle(p, p.Color, p.Material, 0, 1) -- the blockout crane; a lattice crane replaces it (step 5)
				else done = false end
				if done then changed += 1 end
			end
		end
	end
end

---------------------------------------------------------------- 2. ground paving (the bare grey ground between roads and buildings)
-- road corridors are |x| < 24 (north/south road) and |z| < 24 (east road)
-- leaves the ground holes open (club, subway stair pits: hongdae_v1_temp HOLES)
local HOLES = {
	{ 49, -252, 169, -92 },
	{ 26, -59, 32, -41 }, { -32, -59, -26, -41 },
	{ 26, 41, 32, 59 }, { -32, 41, -26, 59 },
}
local function paving(x0: number, z0: number, x1: number, z1: number)
	if x1 - x0 < 0.5 or z1 - z0 < 0.5 then return end
	for _, h in ipairs(HOLES) do
		if h[1] < x1 and h[3] > x0 and h[2] < z1 and h[4] > z0 then
			-- split around the hole: left, right, then the middle strip above / below
			paving(x0, z0, h[1], z1)
			paving(h[3], z0, x1, z1)
			local mx0, mx1 = math.max(x0, h[1]), math.min(x1, h[3])
			paving(mx0, z0, mx1, h[2])
			paving(mx0, h[4], mx1, z1)
			return
		end
	end
	part("Paving", Vector3.new(x1 - x0, 0.04, z1 - z0), CFrame.new((x0 + x1) / 2, 0.02, (z0 + z1) / 2), C.paving, Enum.Material.Pavement)
end
paving(24, -170, 300, -24) -- NE (club, towers)
paving(24, 24, 300, 75) -- SE (construction site)
paving(-40, -170, -24, -24) -- NW
paving(-40, 24, -24, 75) -- SW

---------------------------------------------------------------- 3. granite curbs + tactile blocks on the road side of long sidewalks
local temp = workspace:FindFirstChild("Hongdae_Layout")
if temp then
	for _, s in ipairs(temp:GetChildren()) do
		if s:IsA("BasePart") and s.Name == "Sidewalk" and inBox(s.Position) then
			local long = math.max(s.Size.X, s.Size.Z)
			if long >= 18 then
				local alongX = s.Size.X >= s.Size.Z
				local top = s.Position.Y + s.Size.Y / 2
				if alongX then
					local side = if s.Position.Z > 0 then -1 else 1 -- towards z = 0 (the road)
					local edge = s.Position.Z + side * s.Size.Z / 2
					part("Curb", Vector3.new(s.Size.X, s.Size.Y + 0.15, 0.7), CFrame.new(s.Position.X, s.Position.Y + 0.075, edge - side * 0.35), C.granite, Enum.Material.Granite)
					deco(part("TactileLine", Vector3.new(s.Size.X, 0.05, 0.9), CFrame.new(s.Position.X, top + 0.03, edge - side * 2.6), C.tactile, Enum.Material.DiamondPlate))
				else
					local side = if s.Position.X > 0 then -1 else 1
					local edge = s.Position.X + side * s.Size.X / 2
					part("Curb", Vector3.new(0.7, s.Size.Y + 0.15, s.Size.Z), CFrame.new(edge - side * 0.35, s.Position.Y + 0.075, s.Position.Z), C.granite, Enum.Material.Granite)
				end
			end
		end
	end
end
-- warning blocks at the four crossroads corners
for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
	deco(part("TactileWarning", Vector3.new(4, 0.05, 1.4), CFrame.new(29 * q[1], 0.64, 24.9 * q[2] + 0.8 * q[2]), C.tactile, Enum.Material.DiamondPlate))
	deco(part("TactileWarning", Vector3.new(1.4, 0.05, 4), CFrame.new(24.9 * q[1] + 0.8 * q[1], 0.64, 29 * q[2]), C.tactile, Enum.Material.DiamondPlate))
end

---------------------------------------------------------------- 4. road details: manholes, worn patches
for _, m in ipairs({ Vector3.new(-6, 0, -70), Vector3.new(10, 0, 18), Vector3.new(60, 0, -6), Vector3.new(120, 0, 12), Vector3.new(180, 0, -10) }) do
	local d = deco(part("Manhole", Vector3.new(0.06, 2.4, 2.4), CFrame.new(m + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 42), Enum.Material.DiamondPlate))
	d.Shape = Enum.PartType.Cylinder
end
for _, w in ipairs({ { Vector3.new(4, 0, -12), 9, 5 }, { Vector3.new(80, 0, 8), 14, 6 }, { Vector3.new(150, 0, -14), 10, 4 } }) do
	deco(part("AsphaltPatch", Vector3.new(w[2], 0.02, w[3]), CFrame.new(w[1] + Vector3.new(0, 0.13, 0)), Color3.fromRGB(44, 45, 48), Enum.Material.Asphalt))
end

---------------------------------------------------------------- 5. tower crane over the construction site (강남대로61길 reference)
local site = temp and temp:FindFirstChild("ConstructionSite(소품샵 예정)")
local oldMast = site and site:FindFirstChild("CraneMast", true)
local base = if oldMast and oldMast:IsA("BasePart") then Vector3.new(oldMast.Position.X, 0, oldMast.Position.Z) else Vector3.new(70, 0, 62)
local crane = Instance.new("Model")
crane.Name = "TowerCrane"
crane.Parent = sample
local H = 92
for _, c in ipairs({ { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } }) do
	deco(part("MastPost", Vector3.new(0.35, H, 0.35), CFrame.new(base + Vector3.new(c[1], H / 2, c[2])), C.craneYellow, Enum.Material.Metal, crane))
end
for y = 3, H, 4 do
	for _, f in ipairs({ { 0, -1.4, 3.1, 0.25 }, { 0, 1.4, 3.1, 0.25 }, { -1.4, 0, 0.25, 3.1 }, { 1.4, 0, 0.25, 3.1 } }) do
		deco(part("MastRing", Vector3.new(f[3], 0.25, f[4]), CFrame.new(base + Vector3.new(f[1], y, f[2])), C.craneYellow, Enum.Material.Metal, crane))
	end
	-- diagonal braces on two faces
	deco(part("MastBrace", Vector3.new(0.2, 4.5, 0.2), CFrame.new(base + Vector3.new(0, y + 2, -1.4)) * CFrame.Angles(0, 0, math.rad(35)), C.craneYellow, Enum.Material.Metal, crane))
	deco(part("MastBrace", Vector3.new(0.2, 4.5, 0.2), CFrame.new(base + Vector3.new(-1.4, y + 2, 0)) * CFrame.Angles(math.rad(35), 0, 0), C.craneYellow, Enum.Material.Metal, crane))
end
local top = base + Vector3.new(0, H, 0)
local jibDir = CFrame.new(top) * CFrame.Angles(0, math.rad(-120), 0) -- jib over the street
deco(part("Cab", Vector3.new(3.2, 3, 3.2), jibDir * CFrame.new(0, 1.5, 0), Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic, crane))
deco(part("Jib", Vector3.new(1.6, 1.8, 54), jibDir * CFrame.new(0, 3.6, -27), C.craneYellow, Enum.Material.DiamondPlate, crane))
deco(part("CounterJib", Vector3.new(1.6, 1.4, 16), jibDir * CFrame.new(0, 3.6, 8), C.craneYellow, Enum.Material.DiamondPlate, crane))
deco(part("CounterWeight", Vector3.new(3, 3, 4), jibDir * CFrame.new(0, 2.4, 14), C.concrete, Enum.Material.Concrete, crane))
deco(part("Apex", Vector3.new(1, 9, 1), jibDir * CFrame.new(0, 8, 0), C.craneYellow, Enum.Material.Metal, crane))
deco(part("TieFront", Vector3.new(0.15, 0.15, 30), jibDir * CFrame.new(0, 8, -14) * CFrame.Angles(math.rad(-9), 0, 0), C.black, Enum.Material.Metal, crane))
deco(part("TieBack", Vector3.new(0.15, 0.15, 14), jibDir * CFrame.new(0, 8, 7) * CFrame.Angles(math.rad(18), 0, 0), C.black, Enum.Material.Metal, crane))
deco(part("HookCable", Vector3.new(0.12, 40, 0.12), jibDir * CFrame.new(0, 3.6 - 20, -38), C.black, Enum.Material.Metal, crane))
deco(part("Hook", Vector3.new(1, 1.2, 1), jibDir * CFrame.new(0, 3.6 - 40.5, -38), C.craneYellow, Enum.Material.Metal, crane))

-- line art on the hoarding (the white wall with a blue drawing in the reference)
if site then
	for _, h in ipairs(site:GetDescendants()) do
		if h:IsA("BasePart") and h.Name == "Hoarding" then
			local face = if math.abs(h.Size.X) >= math.abs(h.Size.Z) then Enum.NormalId.Front else Enum.NormalId.Right
			for _, f in ipairs({ face, if face == Enum.NormalId.Front then Enum.NormalId.Back else Enum.NormalId.Left }) do
				local g = Instance.new("SurfaceGui")
				g.Name = "ArtSampleArt"
				g.Face = f
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 20
				g.LightInfluence = 1
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 0.32)
				t.Position = UDim2.fromScale(0, 0.06)
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.GothamBold
				t.TextScaled = true
				t.TextColor3 = C.lineBlue
				t.Text = "OHU 신축공사 · 안전제일"
				t.Parent = g
				for i = 0, 5 do
					local wave = Instance.new("Frame")
					wave.BackgroundColor3 = C.lineBlue
					wave.BorderSizePixel = 0
					wave.AnchorPoint = Vector2.new(0.5, 0.5)
					wave.Position = UDim2.fromScale(0.1 + i * 0.16, 0.66 + (i % 2) * 0.08)
					wave.Size = UDim2.new(0.12, 0, 0, 6)
					wave.Rotation = if i % 2 == 0 then 18 else -18
					wave.Parent = g
				end
				g.Parent = h
			end
		end
	end
end

---------------------------------------------------------------- 6. club front: neon sign + lit entrance (MUSE / THE SEOUL references)
local club = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("02_Club")
local facade = temp and temp:FindFirstChild("ClubFacade")
local signBase: CFrame? = nil
if facade and facade:IsA("Model") then
	local cf, size = facade:GetBoundingBox()
	signBase = cf
end
if club then
	-- vertical blue LED band on the street corner of the club (south-west
	-- corner of the club's ground hole; the entrance faces west)
	local corner = Vector3.new(49, 0, -92)
	if inBox(corner) then
		local band = deco(part("ClubCornerLED", Vector3.new(0.6, 30, 0.6), CFrame.new(corner + Vector3.new(-0.4, 15, 0.4)), Color3.fromRGB(60, 120, 255), Enum.Material.Neon))
		band:SetAttribute("NightOnly", true)
		local sign = deco(part("ClubSign", Vector3.new(0.4, 5, 22), CFrame.new(corner + Vector3.new(-0.6, 24, -14)), C.black, Enum.Material.Metal))
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Left
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 24
		g.LightInfluence = 0
		g.Brightness = 2
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Michroma
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(120, 170, 255)
		t.TextStrokeColor3 = Color3.fromRGB(40, 80, 255)
		t.TextStrokeTransparency = 0.2
		t.Text = "OHU CLUB"
		t.Parent = g
		g.Parent = sign
	end
end

---------------------------------------------------------------- 7. lighting
if not Lighting:GetAttribute("ArtOrigSaved") then
	for _, k in ipairs(LIGHT_PROPS) do Lighting:SetAttribute("ArtOrig_" .. k, (Lighting :: any)[k]) end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		for _, k in ipairs({ "Density", "Haze", "Glare", "Offset" }) do Lighting:SetAttribute("ArtOrigAtm_" .. k, (atm :: any)[k]) end
		Lighting:SetAttribute("ArtOrigAtm_Color", atm.Color)
		Lighting:SetAttribute("ArtOrigAtm_Decay", atm.Decay)
	end
	Lighting:SetAttribute("ArtOrigSaved", true)
end
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local night = MODE == "night"
for _, d in ipairs(sample:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("NightOnly") then d.Transparency = if night then 0 else 1 end
end
if night then
	Lighting.ClockTime = 21.2
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(40, 42, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(55, 60, 80)
	Lighting.ExposureCompensation = 0.3
	Lighting.EnvironmentSpecularScale = 1
	if atm then
		atm.Density = 0.34; atm.Haze = 1.6; atm.Glare = 0.4; atm.Offset = 0.1
		atm.Color = Color3.fromRGB(120, 120, 150); atm.Decay = Color3.fromRGB(60, 60, 90)
	end
	-- street lamps and shop fronts light up
	for _, r in ipairs(roots) do
		for _, p in ipairs(r:GetDescendants()) do
			if p:IsA("BasePart") and inBox(p.Position) then
				if p.Name == "LampHead" then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromRGB(255, 226, 170)
					local l = Instance.new("SpotLight")
					l.Name = "ArtSampleLight"
					l.Face = Enum.NormalId.Bottom
					l.Angle = 120
					l.Range = 40
					l.Brightness = 3
					l.Color = Color3.fromRGB(255, 220, 170)
					l.Shadows = true
					l.Parent = p
				elseif p.Name == "ShopGlass" then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromRGB(255, 236, 200)
					p.Transparency = 0.4
				elseif p.Name == "FloorBand" then
					p.Color = Color3.fromRGB(70, 74, 82)
				end
			end
		end
	end
else
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(90, 92, 98)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 138, 145)
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentSpecularScale = 1
	Lighting.EnvironmentDiffuseScale = 1
	if atm then
		atm.Density = 0.28; atm.Haze = 1.2; atm.Glare = 0.2; atm.Offset = 0.15
		atm.Color = Color3.fromRGB(200, 205, 215); atm.Decay = Color3.fromRGB(110, 120, 140)
	end
end

-- keep this hour in play tests too (DayNightController reads it)
Lighting:SetAttribute("HoldClockTime", Lighting.ClockTime)

sample.Parent = workspace
return string.format("%s: %d parts restyled, %d detail parts added (MODE=revert to undo)", MODE, changed, #sample:GetDescendants())
