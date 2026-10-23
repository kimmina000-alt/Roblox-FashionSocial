-- OFFICIAL map layout v7c (docs/02_WORLDS/HONGDAE_LAYOUT.md, user approved 2026-10-23).
-- Build order (tools/graybox/LAYOUT.md): 1) build_main_social_graybox.lua
-- (the zones), 2) this script (street layout, zone positions, boundary,
-- backdrop), 3) street_dress.lua (real assets). Hand edits of props are kept
-- by prop_save.lua (D-105). Earlier name: hongdae_v1_temp.lua (D-086..D-110).
--   * 강남역 사거리 instead of the roundabout (videos): wide roads with central
--     bus lanes, lane lines / arrows, crosswalks, yellow safety zones, planters
--   * subway exits 1-4 = real stair entrances coming up in the arrow direction
--     (pads keep the exit picker), spawn in front of exit 1
--   * 4 bus stops that teleport between each other (BusStop pads)
--   * 광안리 seafront: 2-lane road + red lane, promenade with round pine
--     planters, bollards, drains, crosswalks, 광안대교 in the sea
--   * 광화문 at the hanok village west entrance, stone plaza + lawn + 해태,
--     mountains behind the village
--   * 에버랜드-style amusement park gate, ticket booth, info booth, perimeter
--     wall, round symbol plaza inside
-- Run in the Studio command bar (Edit mode). MODE: "apply" / "revert".
-- Orientation = the Studio top view: screen up = -Z (north), right = +X (east).
-- The sun rises at +X and sets at -X (over the sea).
local MODE = ... or "apply"

local root = workspace:WaitForChild("Graybox_MainSocial")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local HIDE = "Hongdae_v1_HiddenParts"
local function R(deg) return CFrame.Angles(0, math.rad(deg), 0) end

-- crossroads centre C = (0,0). Big roads: asphalt 48 (bus 8+8 in the middle,
-- 2 car lanes of 8 each side), sidewalks 10 → buildings start 36 from the axes.
-- v7c (user 2026-10-22, Hongdae photo): sidewalks are a furniture strip (10:
-- exits, planters, lamps) + a walkway of about the same width, so the
-- sidewalks reach 47 from the road axis and the buildings stand behind that.
-- The club moves 6 north and the photo booth 12 north (its side face clears
-- the east-road sidewalk), the hanok village 12 south. The beach goes 2.4
-- down (and the sea 3) so the promenade steps down to the sand (광안리 photo).
-- -14 (was -6): an alley between the club and the 오후네컷 building (user 2026-10-23)
local CLUB_DZ = -14
local CDZ = CLUB_DZ + 6 -- shift for positions measured when CLUB_DZ was -6
local MOVES = {
	["02_Club"] = CFrame.new(0, 0, CLUB_DZ) * CFrame.new(109, 0, -172) * R(-90) * CFrame.new(0, 0, 210), -- entrance faces west (club street)
	["03_Rooftop_Backstage"] = CFrame.new(0, 0, CLUB_DZ) * CFrame.new(109, 0, -366) * R(180) * CFrame.new(-125, 0, 160), -- runway behind the club
	["07_Hanok_Village"] = CFrame.new(0, 0, 12) * CFrame.new(161, 0, 126) * R(-90) * CFrame.new(-175, 0, -230), -- main gate east, back gate west (광화문)
	-- 오후네컷 below the club; 1.2 up so the shop stands on a granite plinth
	-- with steps (user photo 2026-10-23, docs/04_ART/PHOTO_BOOTH_BUILDING.md)
	["08_PhotoBooth"] = CFrame.new(0, 1.2, -12) * CFrame.new(-126, 0, 51),
	["06_Park_Playground"] = CFrame.new(-455, 0, -171), -- amusement park north-west
	["05_Cafe"] = CFrame.new(-123.5, 0, 175) * R(-90) * CFrame.new(130, 0, -185), -- Glasshouse south-west
	["04_Beach_Aquarium"] = CFrame.new(0, -2.4, 0), -- sand below the promenade
}
local BEACH_DROP, SEA_DROP = 2.4, 3
-- ground holes: club + the four subway stair pits (x0, z0, x1, z1)
local HOLES = {
	{ 49, -252 + CLUB_DZ, 169, -92 + CLUB_DZ },
	{ 26, -68, 32, -50 }, { -32, -68, -26, -50 }, -- exits 1, 3 (come up northwards)
	{ 26, 50, 32, 68 }, { -32, 50, -26, 68 }, -- exits 2, 4 (come up southwards)
}
local MOUNTAINS = { -- terrain hills behind the hanok village (centre, radius)
	{ Vector3.new(400, -55, 60), 95 }, { Vector3.new(470, -60, 175), 110 }, { Vector3.new(420, -55, 295), 95 },
	{ Vector3.new(290, -70, 370), 90 }, { Vector3.new(150, -75, 390), 90 },
}

local function shouldHide(zn, p)
	if zn == "09_Paths" or zn == "01_Plaza_Street" then return true end
	if zn == "00_Ground" then return p.Name == "Ground_N" or p.Name == "Ground_S" or p.Name == "Ground_W" or p.Name == "Ground_E" end
	return false
end

local function moveTo(m: Model, target: CFrame)
	local d = target * m:GetPivot():Inverse()
	m:PivotTo(target)
	local list = m:GetDescendants()
	table.insert(list, m)
	for _, x in ipairs(list) do
		for k, v in pairs(x:GetAttributes()) do
			if typeof(v) == "Vector3" then x:SetAttribute(k, d * v) end
		end
	end
end

local spawn = workspace:FindFirstChild("SpawnLocation") :: SpawnLocation?

local function revert()
	-- graybox labels this script re-texted / moved (photo booth): back first,
	-- while their zone still stands where they were changed
	for _, x in ipairs(root:GetDescendants()) do
		local tr, col = x:GetAttribute("OrigTransparency"), x:GetAttribute("OrigColor")
		if typeof(tr) == "number" and x:IsA("BasePart") then x.Transparency = tr x:SetAttribute("OrigTransparency", nil) end
		if typeof(col) == "Color3" and x:IsA("BasePart") then x.Color = col x:SetAttribute("OrigColor", nil) end
		local t, cf = x:GetAttribute("OrigText"), x:GetAttribute("OrigCFrame")
		if typeof(t) == "string" and x:IsA("TextLabel") then x.Text = t x:SetAttribute("OrigText", nil) end
		if typeof(cf) == "CFrame" and x:IsA("BasePart") then x.CFrame = cf x:SetAttribute("OrigCFrame", nil) end
	end
	-- groups moved inside a zone (park rides): back to where they were
	for _, z in ipairs(root:GetChildren()) do
		for _, c in ipairs(z:GetChildren()) do
			local orig, d = c:GetAttribute("TempOrig"), c:GetAttribute("TempDelta")
			if typeof(orig) == "CFrame" and typeof(d) == "CFrame" then
				local list = c:GetDescendants()
				table.insert(list, c)
				for _, x in ipairs(list) do
					for k, v in pairs(x:GetAttributes()) do
						if typeof(v) == "Vector3" then x:SetAttribute(k, d:Inverse() * v) end
					end
				end
				if c:IsA("Model") then c:PivotTo(orig) elseif c:IsA("BasePart") then c.CFrame = orig end
				c:SetAttribute("TempOrig", nil)
				c:SetAttribute("TempDelta", nil)
			end
		end
	end
	for _, z in ipairs(root:GetChildren()) do
		local b = z:GetAttribute("BuiltPivot")
		if z:IsA("Model") and typeof(b) == "CFrame" and z:GetPivot() ~= b then moveTo(z, b) end
	end
	local hidden = SS:FindFirstChild(HIDE)
	if hidden then
		for _, p in ipairs(hidden:GetChildren()) do
			local home = root:FindFirstChild(p:GetAttribute("HomeZone"))
			if home then p.Parent = home end
		end
		hidden:Destroy()
	end
	-- (also the folder of the earlier temporary version)
	local old = workspace:FindFirstChild("Hongdae_Layout") or workspace:FindFirstChild("Hongdae_v1_Temp")
	if old then
		if old:GetAttribute("Mountains") then
			for _, m in ipairs(MOUNTAINS) do workspace.Terrain:FillBall(m[1], m[2] + 1, Enum.Material.Air) end
		end
		if old:GetAttribute("SeaLowered") then -- sea back up to y 0 (dome kept dry, as the graybox builds it)
			workspace.Terrain:FillBlock(CFrame.new((-1024 - 268) / 2, -SEA_DROP / 2, 0), Vector3.new(1024 - 268, SEA_DROP, 2048), Enum.Material.Water)
			workspace.Terrain:FillBall(Vector3.new(-368, 0, -150), 44, Enum.Material.Air)
		end
		old:Destroy()
	end
	if spawn and spawn:GetAttribute("OldPosition") then
		spawn.CFrame = CFrame.new(spawn:GetAttribute("OldPosition"))
		spawn:SetAttribute("OldPosition", nil)
	end
end

if MODE == "revert" then
	revert()
	return "reverted (zones back to BuiltPivot, hidden parts restored, temp model + hills removed)"
end

-- apply (always from the built layout, so it can be re-run) -----------------
revert()
for name, d in pairs(MOVES) do
	local z = root:FindFirstChild(name)
	local b = z and z:GetAttribute("BuiltPivot")
	if typeof(b) == "CFrame" then moveTo(z, d * b) end
end

local hidden = Instance.new("Folder")
hidden.Name = HIDE
hidden.Parent = SS
local groundTemplate: BasePart? = nil
for _, zn in ipairs({ "00_Ground", "01_Plaza_Street", "09_Paths" }) do
	for _, p in ipairs(root[zn]:GetChildren()) do
		if (p:IsA("BasePart") or p:IsA("Model")) and shouldHide(zn, p) then
			if p.Name == "Ground_N" then groundTemplate = p end
			p:SetAttribute("HomeZone", zn)
			p.Parent = hidden
		end
	end
end

-- park rides rearranged to fit the user's red box (x -148..-38, z -475..-229):
-- every child of 06 whose centre lies in a source box gets the same move
do
	local park = root:FindFirstChild("06_Park_Playground")
	local GROUPS = { -- source box (x0, z0, x1, z1) → move
		{ { -125, -145, -85, -105 }, Vector3.new(-10, 0, -184) }, -- carousel → (-115, -310)
		{ { -215, -145, -160, -90 }, Vector3.new(123, 0, -193) }, -- playground → (-66, -312)
		{ { -120, -262, -90, -190 }, Vector3.new(5, 0, -173) }, -- ferris wheel → (-100, -400)
		{ { -220, -245, -200, -178 }, Vector3.new(148, 0, -188) }, -- flower tunnel → (-62, -400)
		{ { -155, -176, -145, -166 }, Vector3.new(57, 0, -129) }, -- park name label → (-93, -300)
	}
	if park then
		for _, c in ipairs(park:GetChildren()) do
			if c.Name == "ParkGrass" then
				c:SetAttribute("HomeZone", park.Name)
				c.Parent = hidden
			elseif c:IsA("Model") or c:IsA("BasePart") then
				local pos = c:GetPivot().Position
				for _, g in ipairs(GROUPS) do
					local b = g[1]
					if pos.X > b[1] and pos.X < b[3] and pos.Z > b[2] and pos.Z < b[4] then
						local d = CFrame.new(g[2])
						c:SetAttribute("TempOrig", c:GetPivot())
						c:SetAttribute("TempDelta", d)
						local list = c:GetDescendants()
						table.insert(list, c)
						for _, x in ipairs(list) do
							for k, v in pairs(x:GetAttributes()) do
								if typeof(v) == "Vector3" then x:SetAttribute(k, d * v) end
							end
						end
						if c:IsA("Model") then c:PivotTo(d * c:GetPivot()) else c.CFrame = d * c.CFrame end
						break
					end
				end
			end
		end
	end
end

-- a Folder, not a Model: in Studio one click selects one tree / car / bed
-- instead of the whole street (user 2026-10-22)
local T = Instance.new("Folder")
T.Name = "Hongdae_Layout"

-- Hand edits that survive a rebuild (D-105): every prop gets a PropId made
-- from its kind and generated position. tools/graybox/prop_save.lua records
-- props the user moved or deleted in ServerStorage.PropOverrides (JSON); here
-- those overrides are applied again when the prop is generated.
local HS = game:GetService("HttpService")
local function jsonValue(name: string): {[string]: any}
	local v = SS:FindFirstChild(name)
	if v and v:IsA("StringValue") and v.Value ~= "" then
		local ok, t = pcall(function() return HS:JSONDecode(v.Value) end)
		if ok and typeof(t) == "table" then return t end
	end
	return {}
end
local OVERRIDES = jsonValue("PropOverrides")
local REGISTRY = jsonValue("PropRegistry")
-- this run regenerates every prop of this script: forget the old ids, so ids
-- of props that no longer exist are not mistaken for hand deletions
for id, owner in pairs(REGISTRY) do if owner == "temp" then REGISTRY[id] = nil end end
local usedIds: {[string]: boolean} = {}
-- returns false when the user deleted this prop
local function prop(inst: Instance, kind: string): boolean
	local cf = if inst:IsA("Model") then inst:GetPivot() else (inst :: BasePart).CFrame
	local id = string.format("%s@%d,%d", kind, math.floor(cf.X + 0.5), math.floor(cf.Z + 0.5))
	while usedIds[id] do id ..= "+" end
	usedIds[id] = true
	REGISTRY[id] = "temp"
	inst:SetAttribute("PropId", id)
	inst:SetAttribute("PropBase", cf)
	local o = OVERRIDES[id]
	if o == "delete" then
		inst:Destroy()
		return false
	elseif typeof(o) == "table" and #o == 12 then
		local moved = CFrame.new(table.unpack(o))
		if inst:IsA("Model") then inst:PivotTo(moved) else (inst :: BasePart).CFrame = moved end
	end
	return true
end
local function saveRegistry()
	local v = SS:FindFirstChild("PropRegistry") or Instance.new("StringValue")
	v.Name = "PropRegistry"
	v.Value = HS:JSONEncode(REGISTRY)
	v.Parent = SS
end

-- ground with holes: split x / z at every hole edge, keep the cells outside
-- the holes, merge runs along x (old ground: x -268..1024, z -1024..1024;
-- west of the promenade, x -268..-198, the ground is lowered with the beach)
if groundTemplate then
	local y, h = groundTemplate.Position.Y, groundTemplate.Size.Y
	local low = groundTemplate:Clone()
	low.Name = "Ground"
	low.Size = Vector3.new(70, h, 2048)
	low.CFrame = CFrame.new(-233, y - BEACH_DROP, 0)
	low:SetAttribute("HomeZone", nil)
	low.Parent = T
	-- sea 3 lower so the sand stays above the water
	workspace.Terrain:FillBlock(CFrame.new((-1024 - 268) / 2, -SEA_DROP / 2, 0), Vector3.new(1024 - 268, SEA_DROP, 2048), Enum.Material.Air)
	T:SetAttribute("SeaLowered", true)
	local xs, zs = { -198, 1024 }, { -1024, 1024 }
	for _, o in ipairs(HOLES) do table.insert(xs, o[1]) table.insert(xs, o[3]) table.insert(zs, o[2]) table.insert(zs, o[4]) end
	table.sort(xs) table.sort(zs)
	local function inHole(x, z)
		for _, o in ipairs(HOLES) do if x > o[1] and x < o[3] and z > o[2] and z < o[4] then return true end end
		return false
	end
	local function slab(xa, xb, za, zb)
		local g = groundTemplate:Clone()
		g.Name = "Ground"
		g.Size = Vector3.new(xb - xa, h, zb - za)
		g.CFrame = CFrame.new((xa + xb) / 2, y, (za + zb) / 2)
		g:SetAttribute("HomeZone", nil)
		g.Parent = T
	end
	for j = 1, #zs - 1 do
		local z0, z1 = zs[j], zs[j + 1]
		if z1 > z0 then
			local runStart: number? = nil
			for i = 1, #xs - 1 do
				local xa, xb = xs[i], xs[i + 1]
				if xb > xa then
					local solid = not inHole((xa + xb) / 2, (z0 + z1) / 2)
					if solid and not runStart then runStart = xa end
					if not solid and runStart then slab(runStart, xa, z0, z1) runStart = nil end
				end
			end
			if runStart then slab(runStart, xs[#xs], z0, z1) end
		end
	end
end

------------------------------------------------------------------ helpers
local function part(name, size, cf, color, opt)
	local p = Instance.new((opt and opt.class) or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opt and opt.transparency) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt and opt.shape then p.Shape = opt.shape end
	if opt and opt.nocol then p.CanCollide = false end
	p.Parent = (opt and opt.parent) or T
	return p
end
local function box(name, x0, y0, z0, x1, y1, z1, color, opt)
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local ly, hy = math.min(y0, y1), math.max(y0, y1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	return part(name, Vector3.new(hx - lx, hy - ly, hz - lz), CFrame.new((lx + hx) / 2, (ly + hy) / 2, (lz + hz) / 2), color, opt)
end
local function vcyl(name, pos: Vector3, d, h, color, opt) -- pos = bottom centre
	local o = {}
	for k, v in pairs(opt or {}) do o[k] = v end
	o.shape = Enum.PartType.Cylinder
	return part(name, Vector3.new(h, d, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, o)
end
local function label(adornee: BasePart, text, color, offsetY, scale)
	local g = Instance.new("BillboardGui")
	g.Name = "Label"
	g.Size = UDim2.fromOffset(260 * (scale or 1), 60 * (scale or 1))
	g.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	g.AlwaysOnTop = true
	g.MaxDistance = 900
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Parent = g
	g.Parent = adornee
	return g
end
local function surfaceText(p: BasePart, face, text, color, font, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.Brightness = 1.5
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = if bg then 0 else 1
	if bg then l.BackgroundColor3 = bg end
	l.Font = font or Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = g
end
local function seat(name, cf, size, color, parent)
	local s = Instance.new("Seat")
	s.Name = name
	s.Anchored = true
	s.Size = size
	s.CFrame = cf
	s.Color = color
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = parent or T
	CS:AddTag(s, "PromptSeat")
	return s
end

local ASPHALT = Color3.fromRGB(70, 70, 74)
local WALK = Color3.fromRGB(165, 158, 152)
local CURB = 0.6
local WHITE = Color3.fromRGB(240, 240, 240)
local YELLOW = Color3.fromRGB(240, 190, 40)
local BLUE = Color3.fromRGB(40, 90, 200)
local SIGNS = { Color3.fromRGB(230, 60, 70), Color3.fromRGB(40, 120, 220), Color3.fromRGB(250, 200, 40), Color3.fromRGB(60, 180, 90), Color3.fromRGB(240, 120, 40) }
local function paint(name, x0, z0, x1, z1, color) return box(name, x0, 0.12, z0, x1, 0.16, z1, color, { nocol = true }) end
local function walk(x0, z0, x1, z1) return box("Sidewalk", x0, 0, z0, x1, CURB, z1, WALK, { material = Enum.Material.Brick }) end

local function streetLamp(base: Vector3, toward: Vector3)
	vcyl("LampPole", base, 0.6, 16, Color3.fromRGB(60, 62, 66))
	local tip = base + toward * 3 + Vector3.new(0, 16, 0)
	part("LampArm", Vector3.new(0.4, 0.4, 3), CFrame.lookAt(base + toward * 1.5 + Vector3.new(0, 16, 0), tip), Color3.fromRGB(60, 62, 66), { nocol = true })
	local head = part("LampHead", Vector3.new(1.6, 0.5, 1.6), CFrame.new(tip - Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 225, 160), { material = Enum.Material.Neon, nocol = true })
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 26
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 215, 160)
	light.Parent = head
end
local function trafficLight(base: Vector3, toward: Vector3, reach)
	vcyl("SignalPole", base, 1, 18, Color3.fromRGB(70, 75, 80))
	local tip = base + toward * reach + Vector3.new(0, 17, 0)
	part("SignalArm", Vector3.new(0.6, 0.6, reach), CFrame.lookAt(base + toward * reach / 2 + Vector3.new(0, 17, 0), tip), Color3.fromRGB(70, 75, 80), { nocol = true })
	local head = part("SignalHead", Vector3.new(4.2, 1.5, 1.2), CFrame.lookAt(tip - Vector3.new(0, 1.2, 0), tip - Vector3.new(0, 1.2, 0) + toward:Cross(Vector3.yAxis)), Color3.fromRGB(25, 25, 25), { nocol = true })
	for i, c in ipairs({ Color3.fromRGB(255, 60, 50), Color3.fromRGB(255, 190, 40), Color3.fromRGB(60, 230, 110) }) do
		part("SignalLamp", Vector3.new(0.9, 0.9, 0.3), head.CFrame * CFrame.new((i - 2) * 1.3, 0, -0.65), c, { material = Enum.Material.Neon, nocol = true })
	end
end
-- roadside planting bed (user 2026-10-22, Seoul photos): a soil bed framed by
-- low granite, shrubs and grass on the soil, a street tree in the middle.
-- Foliage comes from ServerStorage.ArtAssets (Creator Store, scripts removed).
local ART = SS:FindFirstChild("ArtAssets")
local plantN = 0
local function foliage(name: string, scale: number, at: CFrame): Model?
	local src = ART and ART:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	if scale ~= 1 then m:ScaleTo(scale) end
	-- sit the bottom of the model on the given point
	local cf, size = m:GetBoundingBox()
	m:PivotTo(at * CFrame.new(0, size.Y / 2, 0) * cf:ToObjectSpace(m:GetPivot()))
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false p.CanQuery = false p.Anchored = true end
	end
	m.Parent = T
	return m
end
local function planter(pos: Vector3, along: Vector3, len: number?, bare: boolean?)
	-- 4.4 wide: tree pits are at least 1.5 m wide (산림청 도시숲·가로수 기준)
	local L, W = len or 14, 4.4
	local cf = CFrame.lookAt(pos, pos + along) -- -Z = along the street
	local granite = Color3.fromRGB(196, 194, 188)
	local top = CURB + 0.35
	local bed = Instance.new("Model")
	bed.Name = "PlanterBed"
	for _, s in ipairs({ -1, 1 }) do
		part("PlanterEdge", Vector3.new(0.3, 0.6, L), cf * CFrame.new(s * (W / 2 - 0.15), top - 0.3, 0), granite, { material = Enum.Material.Granite, parent = bed })
		part("PlanterEdge", Vector3.new(W, 0.6, 0.3), cf * CFrame.new(0, top - 0.3, s * (L / 2 - 0.15)), granite, { material = Enum.Material.Granite, parent = bed })
	end
	part("PlanterSoil", Vector3.new(W - 0.6, 0.5, L - 0.6), cf * CFrame.new(0, top - 0.35, 0), Color3.fromRGB(98, 74, 52), { material = Enum.Material.Ground, parent = bed })
	bed.WorldPivot = cf * CFrame.new(0, top, 0)
	bed.Parent = T
	prop(bed, "Bed")
	local soilTop = top - 0.1
	plantN += 1
	-- street tree in the middle (its own tree grate is not used: the bed is the pit)
	-- realistic birches with light crowns (user pick D1, Creator Store 11351912067,
	-- 2026-10-23): the six models of the pack mixed, each turned and sized a
	-- little differently, about 26–34 tall (9–12 m)
	local BIRCH_SCALE = { 1.3, 1.15, 0.95, 0.85, 0.9, 0.7 }
	local pick = ((plantN * 5) % 6) + 1
	local tree = foliage("Birch" .. pick, BIRCH_SCALE[pick] * (0.92 + ((plantN * 7) % 5) * 0.04), cf * CFrame.new(0, soilTop, 0) * CFrame.Angles(0, plantN * 1.7, 0))
	if tree then
		-- brown bark instead of the white birch bark (user 2026-10-23): the
		-- trunk meshes are the ones with an Overlay SurfaceAppearance; their
		-- colour map is tinted (the leaves use Transparency and stay as they are)
		for _, sa in ipairs(tree:GetDescendants()) do
			if sa:IsA("SurfaceAppearance") and sa.AlphaMode == Enum.AlphaMode.Overlay then
				pcall(function() sa.Color = Color3.fromRGB(150, 112, 82) end)
			end
		end
		for _, p in ipairs(tree:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Part" and p.Size.Y < 1.5 then p:Destroy() end
		end
		prop(tree, "Tree")
	end
	-- only this shrub (user 2026-10-22), larger, two on each side of the tree in
	-- a row, each turned a little differently
	for k, z in ipairs(if bare then {} else { -5.4, -2.8, 2.8, 5.4 }) do
		local scale = 0.44 + ((k * 7 + plantN * 3) % 5) * 0.012 -- larger again (user)
		local yaw = math.rad(((k * 97 + plantN * 53) % 360))
		-- sunk so the brown stems go into the soil (user)
		local s = foliage("Shrub", scale, cf * CFrame.new(0, soilTop - 1.1, z) * CFrame.Angles(0, yaw, 0))
		if s then prop(s, "Shrub") end
	end
end
-- painted arrow on the road (pointing along dir)
local function arrow(pos: Vector3, dir: Vector3, turn)
	local cf = CFrame.lookAt(pos + Vector3.new(0, 0.14, 0), pos + Vector3.new(0, 0.14, 0) + dir)
	part("Arrow", Vector3.new(0.8, 0.04, 8), cf, WHITE, { nocol = true })
	local headCf = cf * CFrame.new(0, 0, -5)
	part("ArrowHead", Vector3.new(0.7, 0.04, 3), headCf * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, 1), WHITE, { nocol = true })
	part("ArrowHead", Vector3.new(0.7, 0.04, 3), headCf * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(0, 0, 1), WHITE, { nocol = true })
	if turn then
		-- 직진·좌회전 arrow (별표 6): a branch leaves the shaft and bends to
		-- the left with its own head
		local a, b = (cf * CFrame.new(0, 0, 0.6)).Position, (cf * CFrame.new(-3.4, 0, -1.8)).Position
		part("ArrowTurn", Vector3.new(0.8, 0.04, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), WHITE, { nocol = true })
		local tip = CFrame.lookAt(b, b + (b - a))
		for _, s in ipairs({ 1, -1 }) do
			part("ArrowHead", Vector3.new(0.7, 0.04, 2.6), tip * CFrame.Angles(0, math.rad(35 * s), 0) * CFrame.new(0, 0, 1), WHITE, { nocol = true })
		end
	end
end

local BIKE_RED = Color3.fromRGB(150, 52, 46) -- 암적색 (dark red) for bike crossings
local CAR_COLORS = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(25, 25, 30), Color3.fromRGB(150, 155, 160), Color3.fromRGB(40, 60, 110), Color3.fromRGB(160, 30, 35) }
local carCount = 0
local PARKED_COLORS = { Color3.fromRGB(20, 20, 23), Color3.fromRGB(96, 98, 103), Color3.fromRGB(38, 39, 42), Color3.fromRGB(150, 153, 158), Color3.fromRGB(62, 64, 68) }
-- only the models the user picked (2026-10-22 screenshots): Genesis G70, G80
local carDesigns = {}
for _, c in ipairs((SS:FindFirstChild("Cars") and SS.Cars:GetChildren()) or {}) do
	if c.Name == "Car_G70" or c.Name == "Car_G80" then table.insert(carDesigns, c) end
end
table.sort(carDesigns, function(a, b) return a.Name < b.Name end)
local function car(pos: Vector3, along: Vector3)
	carCount += 1
	if #carDesigns > 0 then -- Creator Store cars picked by the user (anchored, scripts removed, 15 long)
		local c = carDesigns[((carCount - 1) % #carDesigns) + 1]:Clone()
		-- paint: black and greys mixed (user 2026-10-23). G80: plain white body
		-- meshes; G70: textured body panels (texture off, then coloured)
		-- the G70 asset holds two copies of the car 7 apart (two cars drawn on
		-- top of each other, user screenshots): keep the one on the collider
		local collider = c:FindFirstChild("Collider")
		local copies = {}
		for _, k in ipairs(c:GetChildren()) do
			if k:IsA("Model") and k.Name == "2019 Hyundai Genesis G70" then table.insert(copies, k) end
			if k:IsA("Tool") then k:Destroy() end -- the G80's car key
		end
		if #copies > 1 and collider then
			table.sort(copies, function(a, b) return (a:GetBoundingBox().Position - collider.Position).Magnitude < (b:GetBoundingBox().Position - collider.Position).Magnitude end)
			for i = 2, #copies do copies[i]:Destroy() end
		end
		local paint = PARKED_COLORS[((carCount - 1) % #PARKED_COLORS) + 1]
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("MeshPart") then
				local n = p.Name
				local body = string.match(n, "^bodyshell") or string.match(n, "^door_") or n == "bonnet" or string.match(n, "^boot") or string.match(n, "^bumper")
				if body then
					p.TextureID = ""
					p.Color = paint
					p.Material = Enum.Material.SmoothPlastic
				elseif p.Material ~= Enum.Material.Neon and p.BrickColor == BrickColor.new("Institutional white") then
					p.Color = paint
				end
			end
		end
		c:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 0.12, 0), pos + Vector3.new(0, 0.12, 0) + along))
		c.Parent = T
		prop(c, "Car")
		return
	end
	local m = Instance.new("Model")
	m.Name = "Car"
	local cf = CFrame.lookAt(pos, pos + along)
	local col = CAR_COLORS[(carCount % #CAR_COLORS) + 1]
	part("Body", Vector3.new(6.4, 2.4, 14), cf * CFrame.new(0, 2.1, 0), col, { parent = m })
	part("Cabin", Vector3.new(5.8, 2.2, 7.5), cf * CFrame.new(0, 4.4, 0.6), Color3.fromRGB(35, 40, 50), { parent = m, material = Enum.Material.Glass })
	for _, w in ipairs({ { -3.1, -4.5 }, { 3.1, -4.5 }, { -3.1, 4.5 }, { 3.1, 4.5 } }) do
		part("Wheel", Vector3.new(1.2, 2.6, 2.6), cf * CFrame.new(w[1], 1.3, w[2]), Color3.fromRGB(20, 20, 20), { parent = m, shape = Enum.PartType.Cylinder })
	end
	m.Parent = T
end

------------------------------------------------------- 강남역 사거리 (crossroads)
box("IntersectionRoad", -24, 0, -24, 24, 0.12, 24, ASPHALT, { material = Enum.Material.Asphalt })
local WIDE = 47 -- sidewalk outer edge from the road axis (v7c)
for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do walk(s[1] * 24, s[2] * 24, s[1] * WIDE, s[2] * WIDE) end
-- 정차금지지대 (강남 video): a yellow box just inside the junction with short
-- slanted ticks pointing inward along every side
do
	local B, TH = 21.5, 0.4
	for _, o in ipairs({ -B, B }) do
		paint("JunctionLine", -B, o - TH / 2, B, o + TH / 2, YELLOW)
		paint("JunctionLine", o - TH / 2, -B, o + TH / 2, B, YELLOW)
	end
	for t = -B + 2, B - 2, 2.6 do
		for _, e in ipairs({ { Vector3.new(t, 0, -B), Vector3.new(0, 0, 1) }, { Vector3.new(t, 0, B), Vector3.new(0, 0, -1) }, { Vector3.new(-B, 0, t), Vector3.new(1, 0, 0) }, { Vector3.new(B, 0, t), Vector3.new(-1, 0, 0) } }) do
			local inward = e[2]
			local slant = (inward + Vector3.new(inward.Z, 0, -inward.X)).Unit -- 45° to the side
			local a = e[1] + inward * 0.2 + Vector3.new(0, 0.14, 0)
			local b = a + slant * 2.4
			part("JunctionTick", Vector3.new(TH, 0.04, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), YELLOW, { nocol = true })
		end
	end
end

-- a big road from the crossroads; dir = ±X/±Z; u along, v across (+v = right of dir)
-- pits = sidewalk cut-outs for stair pits {u0, u1, v0, v1}; cars = {u, v}
-- sidewalk areas kept free of lamps / planters (entrances)
local KEEP_CLEAR = {
	{ -196, -40, -104, -20 }, -- park gate
	-- bus stops: no planting bed between the shelter / sign and the curb
	{ -40, -148, -22, -112 }, { 112, 22, 150, 40 }, { 22, 212, 40, 250 }, { -162, 132, -144, 168 },
}
local function clear(p: Vector3)
	for _, k in ipairs(KEEP_CLEAR) do if p.X > k[1] and p.X < k[3] and p.Z > k[2] and p.Z < k[4] then return false end end
	return true
end
-- outer = sidewalk outer edge per side { [-1] = left of dir, [1] = right }
-- detail = how far from the junction the full street furniture goes; past it
-- (outside the play area, only seen from afar) the street runs on with
-- every other bed, bare beds (no shrubs) and no lamps or bike symbols
local function bigRoad(dir: Vector3, len: number, pits, cars, outer, endCrossing: boolean?, detail: number?)
	local DETAIL = detail or len
	outer = outer or { [-1] = WIDE, [1] = WIDE }
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local function at(u, v) return dir * u + across * v end
	local function uv(name, u0, v0, u1, v1, y0, y1, color, opt)
		local a, b = at(u0, v0), at(u1, v1)
		return box(name, a.X, y0, a.Z, b.X, y1, b.Z, color, opt)
	end
	uv("Road", 24, -24, len, 24, 0, 0.12, ASPHALT, { material = Enum.Material.Asphalt })
	for _, side in ipairs({ -1, 1 }) do
		local v0, v1 = if side < 0 then -outer[-1] else 24, if side < 0 then -24 else outer[1]
		local cuts = {}
		for _, p in ipairs(pits) do if p[3] >= v0 and p[4] <= v1 then table.insert(cuts, p) end end
		table.sort(cuts, function(a, b) return a[1] < b[1] end)
		local u = WIDE
		for _, p in ipairs(cuts) do
			uv("Sidewalk", u, v0, p[1], v1, 0, CURB, WALK, { material = Enum.Material.Brick })
			uv("Sidewalk", p[1], v0, p[2], p[3], 0, CURB, WALK, { material = Enum.Material.Brick })
			uv("Sidewalk", p[1], p[4], p[2], v1, 0, CURB, WALK, { material = Enum.Material.Brick })
			u = p[2]
		end
		uv("Sidewalk", u, v0, len, v1, 0, CURB, WALK, { material = Enum.Material.Brick })
	end
	-- Road markings per 도로교통법 시행규칙 별표 6 and the 경찰청 노면표시
	-- manual (docs/04_ART/ROAD_MARKINGS.md, 2026-10-23). Korea drives on the
	-- right: traffic coming into the junction (moving -dir) uses the -v side.
	-- 1 stud ≈ 0.34 m.
	local CW0, CW1 = 25, 37 -- crosswalk 12 wide (≥ 4 m)
	-- 자전거횡단도 (별표 6 534, 2.4 m ≈ 7 wide) right beside the crosswalk on its
	-- outer side, dark red (자전거 이용시설 설치 및 관리 지침: 암적색 where a bike
	-- path crosses a road), white side line only on the far side (the side
	-- touching the crosswalk may be left out)
	local BX0, BX1 = CW1, CW1 + 7
	local STOP = BX1 + 6 -- stop line 6 behind the bike crossing (2–5 m rule)
	local SZ = STOP + 16 -- end of the safety zone outline, taper to SZ + 6
	local function solid(name, v, u0, u1, col, w)
		uv(name, u0, v - (w or 0.4) / 2, u1, v + (w or 0.4) / 2, 0.12, 0.16, col, { nocol = true })
	end
	local function dashed(name, v, u0, u1, col)
		for u = u0, u1 - 6, 12 do solid(name, v, u, u + 6, col) end
	end
	-- double yellow centre line, starting after the safety zone taper
	solid("CenterLine", -0.45, SZ + 6, len, YELLOW) solid("CenterLine", 0.45, SZ + 6, len, YELLOW)
	-- blue bus lane lines (median bus lanes)
	solid("BusLane", -8, STOP, len, BLUE) solid("BusLane", 8, BX1 + 1, len, BLUE)
	-- lane line: solid 진로변경제한선 for 40 studs (≈ 14 m, rule: within 50 m)
	-- before the stop line on the incoming side, dashed further out
	solid("LaneSolid", -16, STOP, STOP + 40, WHITE)
	dashed("LaneDash", -16, STOP + 46, len, WHITE)
	dashed("LaneDash", 16, BX1 + 3, len, WHITE)
	-- zebra crosswalk across the whole road
	for v = -22.5, 22.5, 3 do uv("Crosswalk", CW0, v - 0.75, CW1, v + 0.75, 0.12, 0.16, WHITE, { nocol = true }) end
	uv("BikeCrossing", BX0, -24, BX1, 24, 0.12, 0.15, BIKE_RED, { nocol = true, material = Enum.Material.Asphalt })
	uv("BikeCrossingLine", BX1 - 0.4, -24, BX1, 24, 0.15, 0.17, WHITE, { nocol = true })
	for _, v in ipairs({ -12, 12 }) do
		local pos = at((BX0 + BX1) / 2, v) + Vector3.new(0, 0.18, 0)
		local mark = part("BikeSymbol", Vector3.new(3.7, 0.02, 3.7), CFrame.lookAt(pos, pos + across * (if v < 0 then 1 else -1)), WHITE, { nocol = true, transparency = 1 })
		local dcl = Instance.new("Decal")
		dcl.Texture = "rbxassetid://14547829073"
		dcl.Face = Enum.NormalId.Top
		dcl.Parent = mark
	end
	-- stop line: incoming half only, 1.2 wide (≈ 40 cm)
	uv("StopLine", STOP, -24, STOP + 1.2, 0, 0.12, 0.16, WHITE, { nocol = true })
	-- direction arrows 8 behind the stop line, lane centres; repeated 25 m on
	arrow(at(STOP + 9, -12), -dir, true) arrow(at(STOP + 9, -20), -dir, false)
	if len > 130 then arrow(at(STOP + 82, -12), -dir, true) arrow(at(STOP + 82, -20), -dir, false) end
	-- 횡단보도 예고 ◇ 50–60 m before the crosswalk, each lane
	if len > 220 then
		for _, v in ipairs({ -12, -20 }) do
			local c = at(CW1 + 165, v) + Vector3.new(0, 0.14, 0)
			for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
				local a = c + dir * (s[1] * 3)
				local b = c + across * (s[2] * 1.6)
				part("CrossingAhead", Vector3.new(0.35, 0.04, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), WHITE, { nocol = true })
			end
		end
	end
	-- yellow safety zone (안전지대) at the median start: outline + hatch,
	-- the far end tapers to a point into the centre line
	for u = STOP + 2, SZ - 2, 2.2 do
		local a = at(u, 0) + Vector3.new(0, 0.15, 0)
		part("SafetyStripe", Vector3.new(0.35, 0.04, 3.9), CFrame.lookAt(a, a + dir + across), YELLOW, { nocol = true })
	end
	uv("SafetyEdge", STOP + 1.2, -1.8, SZ, -1.4, 0.12, 0.16, YELLOW, { nocol = true }) uv("SafetyEdge", STOP + 1.2, 1.4, SZ, 1.8, 0.12, 0.16, YELLOW, { nocol = true })
	uv("SafetyEdge", STOP + 1.2, -1.8, STOP + 1.6, 1.8, 0.12, 0.16, YELLOW, { nocol = true })
	for _, s in ipairs({ -1, 1 }) do
		local a, b = at(SZ, s * 1.6) + Vector3.new(0, 0.14, 0), at(SZ + 6, s * 0.45) + Vector3.new(0, 0.14, 0)
		part("SafetyEdge", Vector3.new(0.4, 0.04, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), YELLOW, { nocol = true })
	end
	-- left-turn guide line (유도선, one per approach): white dashes (2 on, 2
	-- off) on a curve from the inner incoming car lane into the road on the left.
	-- 도로교통법 제25조: turn inside the junction centre, so the curve passes
	-- the centre on the near side and opposite left turns never cross.
	do
		local exitDir = across -- turning left from -dir ends up heading +across
		local exitAcross = Vector3.new(-exitDir.Z, 0, exitDir.X)
		local p0 = at(24, -10)
		local p2 = exitDir * 24 + exitAcross * 10
		local c1, c2 = p0 - dir * 15, p2 - exitDir * 15
		local function bez(t)
			local s = 1 - t
			return p0 * s ^ 3 + c1 * 3 * s * s * t + c2 * 3 * s * t * t + p2 * t ^ 3
		end
		local steps, last, dist, on = 80, bez(0), 0, true
		for i = 1, steps do
			local p = bez(i / steps)
			if on then
				local a, b = last + Vector3.new(0, 0.14, 0), p + Vector3.new(0, 0.14, 0)
				part("TurnGuide", Vector3.new(0.4, 0.04, (b - a).Magnitude + 0.05), CFrame.lookAt((a + b) / 2, b), WHITE, { nocol = true })
			end
			dist += (p - last).Magnitude
			if dist >= 2 then dist = 0 on = not on end
			last = p
		end
	end
	-- Street trees per 산림청 「도시숲·생활숲·가로수 조성·관리 기준」 and
	-- common Korean street-tree practice (docs/04_ART/STREET_TREES.md):
	-- trees 4–8 m apart (here 23.5 = 8 m, the widest allowed: fewer trees so
	-- the buildings show, user 2026-10-23), trunk ≥ 1 m from the curb (v 27),
	-- first tree 4 m past the crossing paint (u 56), ≥ 3 m from street lights
	-- and signals, none at bus stops (KEEP_CLEAR) or subway exits.
	local TREE_V, TREE_U0, TREE_STEP = 27, 56, 23.5
	local bedN = 0
	for u = TREE_U0, len - 10, TREE_STEP do -- beds 15 long → a nearly continuous strip
		bedN += 1
		local far = u > DETAIL
		local free = not far or bedN % 2 == 0
		for _, p in ipairs(pits) do if u > p[1] - 9 and u < p[2] + 9 then free = false end end
		if free then for _, v in ipairs({ -TREE_V, TREE_V }) do if clear(at(u, v)) then planter(at(u, v), dir, 15, far) end end end
	end
	-- a lamp every third gap between planting beds (about every 70, user: not
	-- too many), 11.75 (4 m) from the nearest trees
	for u = TREE_U0 + TREE_STEP / 2, math.min(len, DETAIL) - 6, TREE_STEP * 3 do
		local free = true
		for _, p in ipairs(pits) do if u > p[1] - 2 and u < p[2] + 2 then free = false end end
		if free and clear(at(u, -TREE_V)) then streetLamp(at(u, -TREE_V) + Vector3.new(0, CURB, 0), across) end
		if free and clear(at(u, TREE_V)) then streetLamp(at(u, TREE_V) + Vector3.new(0, CURB, 0), -across) end
	end
	-- bike lane between the planting strip and the walkway (user photo
	-- 2026-10-22, 다산동): dark asphalt band with white edges and bike symbols,
	-- broken at subway exits and bus stops
	for _, side in ipairs({ -1, 1 }) do
		if (outer[side] or WIDE) >= 40 then
			local blocked = {}
			for _, p in ipairs(pits) do
				if (side > 0 and p[3] > 0) or (side < 0 and p[4] < 0) then table.insert(blocked, { p[1] - 3, p[2] + 3 }) end
			end
			local function free(u) 
				for _, b in ipairs(blocked) do if u > b[1] and u < b[2] then return false end end
				return clear(at(u, side * 31.2))
			end
			local runStart: number? = nil
			local function lane(u0, u1)
				if u1 - u0 < 6 then return end
				-- right against the planting beds (user 2026-10-22: no gap). The
				-- pavement keeps its own colour (자전거 이용시설 구조·시설 기준 제15조);
				-- only the part that joins the bike crossing is dark red, with a
				-- red link over the curb strip to the crossing
				-- (no red on the sidewalk, user 2026-10-23: the red is only the
				-- crossing on the road)
				local a, b = at(u0, side * 29.2), at(u1, side * 33.2)
				box("BikeLane", a.X, CURB, a.Z, b.X, CURB + 0.03, b.Z, Color3.fromRGB(62, 63, 66), { material = Enum.Material.Asphalt, nocol = true })
				for _, ev in ipairs({ 29.35, 33.05 }) do
					local c, d = at(u0, side * (ev - 0.15)), at(u1, side * (ev + 0.15))
					box("BikeLaneEdge", c.X, CURB + 0.03, c.Z, d.X, CURB + 0.05, d.Z, WHITE, { nocol = true })
				end
				for u = u0 + 8, math.min(u1, DETAIL) - 6, 32 do
					local pos = at(u, side * 31.2) + Vector3.new(0, CURB + 0.06, 0)
					local mark = part("BikeSymbol", Vector3.new(3.7, 0.02, 3.7), CFrame.lookAt(pos, pos + across * side) , WHITE, { nocol = true, transparency = 1 })
					local dcl = Instance.new("Decal")
					dcl.Texture = "rbxassetid://14547829073"
					dcl.Face = Enum.NormalId.Top
					dcl.Parent = mark
				end
			end
			for u = WIDE + 3, len - 4, 1 do
				if free(u) then
					if not runStart then runStart = u end
				elseif runStart then
					lane(runStart, u - 1) runStart = nil
				end
			end
			if runStart then lane(runStart, if endCrossing then len else len - 4) end
		end
	end
	-- far-side signal pole, outside the bike path that turns to the crossing
	trafficLight(at(38, 36) + Vector3.new(0, CURB, 0), -across, 32)
	-- parked along the curb (user 2026-10-23), facing the traffic of their side
	-- (right-hand traffic: the -v side drives toward the junction, -dir); never
	-- at a bus stop
	for _, c in ipairs(cars) do
		local side = if c[2] < 0 then -1 else 1
		if clear(at(c[1], side * 30)) then car(at(c[1], side * 20.6), if side < 0 then -dir else dir) end
	end
end
-- north road: west side stays narrow along the park's red box; east side
-- reaches the club / photo booth fronts (49)
-- (north, south and east run on to the map edge, 1000 from the junction, so
-- no road end shows on screen; user 2026-10-23)
bigRoad(Vector3.new(0, 0, -1), 1000, { { 50, 68, 26, 32 }, { 50, 68, -32, -26 } }, { { 92, -1 }, { 150, 1 }, { 205, -1 } }, { [-1] = 34, [1] = 49 }, nil, 480) -- north
bigRoad(Vector3.new(0, 0, 1), 1000, { { 50, 68, 26, 32 }, { 50, 68, -32, -26 } }, { { 100, 1 }, { 160, -1 }, { 235, 1 } }, nil, nil, 300) -- south (past the boundary at 299: the street goes on, D-110)
bigRoad(Vector3.new(1, 0, 0), 1000, {}, { { 100, 1 }, { 165, -1 } }, nil, nil, 180) -- east
bigRoad(Vector3.new(-1, 0, 0), 158, {}, { { 100, -1 } }, nil, true) -- west, to the seafront road (bike lanes run on to the bike crossings)

local function smallRoad(a: Vector2, b: Vector2, stopEnds)
	local dir = Vector3.new(b.X - a.X, 0, b.Y - a.Y)
	local len = dir.Magnitude
	dir = dir.Unit
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local o = Vector3.new(a.X, 0, a.Y)
	local function bx(name, u0, v0, u1, v1, y0, y1, color, opt)
		local p, q = o + dir * u0 + across * v0, o + dir * u1 + across * v1
		return box(name, p.X, y0, p.Z, q.X, y1, q.Z, color, opt)
	end
	bx("Road", 0, -6, len, 6, 0, 0.12, ASPHALT, { material = Enum.Material.Asphalt })
	bx("Sidewalk", 0, -10, len, -6, 0, CURB, WALK, { material = Enum.Material.Brick })
	bx("Sidewalk", 0, 6, len, 10, 0, CURB, WALK, { material = Enum.Material.Brick })
	-- one lane each way: single yellow solid centre line (별표 6, 중앙선), and a
	-- 1.2 stop line where each lane meets the big road (stopEnds: 0 = start,
	-- 1 = far end), after the sidewalk that runs on across the side street
	bx("CenterLine", 14, -0.2, len, 0.2, 0.12, 0.16, YELLOW, { nocol = true })
	for _, e in ipairs(stopEnds) do
		if e == 0 then bx("StopLine", 14, -6, 15.2, 0, 0.12, 0.16, WHITE, { nocol = true })
		else bx("StopLine", len - 2.2, 0, len - 1, 6, 0.12, 0.16, WHITE, { nocol = true }) end
	end
	-- rounded corners where the side street meets the sidewalk running across
	-- it (user: every sidewalk corner round): a square of sidewalk minus a disc
	local FR = 4
	for _, e in ipairs({ { 13, 1 }, { len, -1 } }) do
		if e[1] == 13 or table.find(stopEnds, 1) then
			for _, side in ipairs({ -1, 1 }) do
				local corner = o + dir * e[1] + across * (side * 6)
				local into = dir * e[2] -- along the side street, away from the sidewalk edge
				local c0, c1 = corner, corner + into * FR - across * (side * FR)
				local sq = box("SidewalkFillet", c0.X, 0, c0.Z, c1.X, CURB, c1.Z, WALK, { material = Enum.Material.SmoothPlastic })
				local hub = corner + into * FR - across * (side * FR)
				local disc = part("FilletCut", Vector3.new(4, FR * 2, FR * 2), CFrame.new(hub.X, CURB / 2, hub.Z) * CFrame.Angles(0, 0, math.rad(90)), WALK, { shape = Enum.PartType.Cylinder })
				sq.Parent, disc.Parent = workspace, workspace -- CSG only works on parts in the Workspace
				local ok, u = pcall(function() return sq:SubtractAsync({ disc }) end)
				disc:Destroy()
				if ok and u then
					u.Name = "SidewalkFillet"
					u.Anchored = true
					u.UsePartColor = true
					u.Parent = T
					sq:Destroy()
				else
					sq:Destroy()
				end
			end
		end
	end
end
smallRoad(Vector2.new(181, -34), Vector2.new(181, -470), { 0 }) -- east of the club
smallRoad(Vector2.new(-34, 98), Vector2.new(-150, 98), { 0, 1 }) -- south-west, to the seafront
-- lane from the east road to the hanok main gate (east side, gate at x 225, z 126)
local LANE = Color3.fromRGB(185, 160, 122)
box("HanokLane", 232, 0, WIDE, 240, 0.3, 142, LANE, { material = Enum.Material.Slate })
box("HanokLane2", 225, 0, 134, 240, 0.3, 142, LANE, { material = Enum.Material.Slate })

------------------------------------------------------- subway exits (stairs)
-- stairs come up in the arrow direction under a glass canopy that slopes
-- down toward the back; the pad is the landing at the bottom of the stairs
-- (like going down to the platform): step on it → exit picker; arrivals
-- appear at the foot of the stairs and walk up (user 2026-10-22)
local EXITS = {
	-- pits 18 long at 50..68 from the junction: clear of the wide corner squares (v7c)
	{ 1, "클럽", Color3.fromRGB(255, 122, 214), 29, -59, Vector3.new(0, 0, -1) },
	{ 2, "한옥 마을", Color3.fromRGB(185, 135, 74), 29, 59, Vector3.new(0, 0, 1) },
	{ 3, "놀이공원", Color3.fromRGB(76, 175, 80), -29, -59, Vector3.new(0, 0, -1) },
	{ 4, "광안리 해변 · 카페", Color3.fromRGB(42, 143, 179), -29, 59, Vector3.new(0, 0, 1) },
}
local exitPads, exitMouths = {}, {}
for _, e in ipairs(EXITS) do
	local m = Instance.new("Model")
	m.Name = "SubwayExit" .. e[1]
	m.Parent = T
	local out = e[6]
	local c = Vector3.new(e[4], 0, e[5]) -- pit centre: 6 wide, 18 long (u -9..9 along out)
	local side = Vector3.new(1, 0, 0)
	local function at(u) return c + out * u end
	local bottom = CURB - 10 * 0.86
	for k = 1, 10 do -- stairs from the mouth (u 9) down to u -3
		local a, b = at(9 - (k - 1) * 1.2), at(9 - k * 1.2)
		box("Step", a.X - 3, -9, a.Z, b.X + 3, CURB - k * 0.86, b.Z, Color3.fromRGB(150, 150, 155), { parent = m, material = Enum.Material.Concrete })
	end
	local l0, l1 = at(-3), at(-9)
	box("Landing", l0.X - 3, -9, l0.Z, l1.X + 3, bottom, l1.Z, Color3.fromRGB(120, 120, 128), { parent = m, material = Enum.Material.Concrete })
	box("PitWallL", c.X - 3.4, -9, c.Z - 9, c.X - 3, CURB, c.Z + 9, Color3.fromRGB(200, 200, 205), { parent = m })
	box("PitWallR", c.X + 3, -9, c.Z - 9, c.X + 3.4, CURB, c.Z + 9, Color3.fromRGB(200, 200, 205), { parent = m })
	local back = at(-9)
	local bw = box("PitBack", back.X - 3, -9, back.Z - 0.2, back.X + 3, CURB + 2.6, back.Z + 0.2, Color3.fromRGB(40, 40, 45), { parent = m })
	surfaceText(bw, if out.Z < 0 then Enum.NormalId.Front else Enum.NormalId.Back, "🚇 승강장\n발판을 밟으면 출구 선택", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	-- entrance building (user photo 2026-10-22): granite base, glass sides with
	-- dark frames, a grey roof high at the open end that sweeps down in a curve
	-- to the base at the back
	local granite = Color3.fromRGB(176, 176, 172)
	local dark = Color3.fromRGB(38, 40, 44)
	local roofC = Color3.fromRGB(150, 153, 157)
	local BASE = CURB + 2.6 -- top of the granite base
	local U0, U1 = -9.6, 9.4 -- back, mouth
	local function roofY(u: number): number
		if u >= -3 then return CURB + 6.2 + (u + 3) / (U1 + 3) * 1.4 end -- straight, rising to the mouth
		local t = math.clamp((u + 3) / (U0 + 3), 0, 1) -- 0 at -3, 1 at the back
		return BASE + 3.6 * math.sqrt(math.max(0, 1 - t * t)) -- elliptic curve down to the base
	end
	for _, sx in ipairs({ -1, 1 }) do
		local a, b = at(U0) + side * (sx * 3.4), at(U1) + side * (sx * 4.2)
		box("EntranceBase", math.min(a.X, b.X), CURB, math.min(a.Z, b.Z), math.max(a.X, b.X), BASE, math.max(a.Z, b.Z), granite, { parent = m, material = Enum.Material.Granite })
	end
	do
		local a, b = at(U0) + side * -4.2, at(U0 + 0.6) + side * 4.2
		box("EntranceBase", math.min(a.X, b.X), CURB, math.min(a.Z, b.Z), math.max(a.X, b.X), BASE, math.max(a.Z, b.Z), granite, { parent = m, material = Enum.Material.Granite })
	end
	-- roof: one straight slab + a curved run of short slabs
	local pts = { U1 }
	for k = 0, 8 do table.insert(pts, -3 + (U0 + 3) * (k / 8)) end
	for i = 1, #pts - 1 do
		local p0 = at(pts[i]) + Vector3.new(0, roofY(pts[i]), 0)
		local p1 = at(pts[i + 1]) + Vector3.new(0, roofY(pts[i + 1]), 0)
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.25
		local look = CFrame.lookAt(mid, p1)
		part("EntranceRoof", Vector3.new(8.6, 0.9, len), look * CFrame.new(0, 0.45, 0), roofC, { parent = m, material = Enum.Material.Metal })
	end
	-- glass panels with dark mullions on both sides
	local cuts = { U1 - 0.6, 6, 2.5, -1, -3.8, -6.6, U0 + 0.6 }
	for _, sx in ipairs({ -1, 1 }) do
		for i = 1, #cuts - 1 do
			local ua, ub = cuts[i + 1], cuts[i]
			local top = math.min(roofY(ua), roofY(ub)) - 0.05
			if top - BASE > 0.4 then
				local a, b = at(ua) + side * (sx * 3.9), at(ub) + side * (sx * 3.9)
				box("EntranceGlass", math.min(a.X, b.X) - 0.07, BASE, math.min(a.Z, b.Z), math.max(a.X, b.X) + 0.07, top, math.max(a.Z, b.Z), Color3.fromRGB(70, 90, 100), { parent = m, material = Enum.Material.Glass, transparency = 0.45 })
			end
			local mpos = at(ub) + side * (sx * 3.9)
			box("EntranceMullion", mpos.X - 0.15, BASE, mpos.Z - 0.15, mpos.X + 0.15, roofY(ub), mpos.Z + 0.15, dark, { parent = m, material = Enum.Material.Metal })
		end
	end
	-- the dark frame of the open end
	for _, sx in ipairs({ -1, 1 }) do
		local a, b = at(U1 - 0.8) + side * (sx * 3.6), at(U1) + side * (sx * 4.4)
		box("EntranceFrame", math.min(a.X, b.X), CURB, math.min(a.Z, b.Z), math.max(a.X, b.X), roofY(U1) + 0.9, math.max(a.Z, b.Z), dark, { parent = m, material = Enum.Material.Metal })
	end
	-- exit number pole (Seoul style): dark pole, yellow number panel on top
	local mouth = at(9)
	local polePos = mouth + side * 5.6 * math.sign(e[4]) + out * 1
	box("ExitPole", polePos.X - 0.45, CURB, polePos.Z - 0.45, polePos.X + 0.45, CURB + 11, polePos.Z + 0.45, dark, { parent = m, material = Enum.Material.Metal })
	local sign = box("ExitNumberSign", polePos.X - 0.55, CURB + 9, polePos.Z - 0.55, polePos.X + 0.55, CURB + 10.8, polePos.Z + 0.55, Color3.fromRGB(250, 200, 30), { parent = m })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do surfaceText(sign, face, tostring(e[1]), Color3.fromRGB(20, 20, 20), Enum.Font.GothamBlack) end
	box("ExitPoleBand", polePos.X - 0.5, CURB + 5, polePos.Z - 0.5, polePos.X + 0.5, CURB + 7.5, polePos.Z + 0.5, Color3.fromRGB(200, 40, 60), { parent = m })
	label(sign, e[1] .. "번 출구 · " .. e[2], e[3], 4, 0.8)

	-- the landing pad (exit picker)
	local padPos = at(-6) + Vector3.new(0, bottom + 0.2, 0)
	local pad = part("SubwayExitPad", Vector3.new(6, 0.4, 6), CFrame.lookAt(padPos, padPos + out), e[3], { parent = m, material = Enum.Material.Neon })
	pad:SetAttribute("ExitNumber", e[1])
	pad:SetAttribute("ExitName", e[2])
	pad:SetAttribute("Out", out) -- arrivals step off toward the stairs (up)
	CS:AddTag(pad, "SubwayExit")
	exitPads[e[1]] = pad
	exitMouths[e[1]] = mouth
end
------------------------------------------------------- bus stops (4)
local function busStop(n, name, center: Vector3, roadDir: Vector3, along: Vector3)
	local m = Instance.new("Model")
	m.Name = "BusStop" .. n
	m.Parent = T
	-- Seoul bus shelter (user photo 2026-10-22, 화곡역): dark steel posts in the
	-- back plane, a louvered glass roof cantilevered toward the road, a dark
	-- station header under the roof, two lit ad panels and a route map in the
	-- back, a glass bench
	local base = center + Vector3.new(0, CURB, 0)
	local cf = CFrame.lookAt(base, base + roadDir) -- -Z local = toward the road
	local steel = Color3.fromRGB(46, 48, 52)
	local W, H = 15, 8.6
	for _, x in ipairs({ -W / 2, -2.5, 2.5, W / 2 }) do part("ShelterPost", Vector3.new(0.4, H, 0.4), cf * CFrame.new(x, H / 2, 1.8), steel, { parent = m, material = Enum.Material.Metal }) end
	part("ShelterRoofFrame", Vector3.new(W + 0.6, 0.35, 5.4), cf * CFrame.new(0, H + 0.2, -0.4) * CFrame.Angles(math.rad(-3), 0, 0), steel, { parent = m, material = Enum.Material.Metal })
	part("ShelterRoof", Vector3.new(W, 0.1, 5), cf * CFrame.new(0, H + 0.42, -0.4) * CFrame.Angles(math.rad(-3), 0, 0), Color3.fromRGB(180, 205, 215), { parent = m, material = Enum.Material.Glass, transparency = 0.4 })
	for z = -2.6, 1.8, 0.55 do
		part("RoofLouver", Vector3.new(W, 0.25, 0.12), cf * CFrame.new(0, H - 0.05, z) * CFrame.Angles(math.rad(-3), 0, 0), Color3.fromRGB(35, 37, 40), { parent = m, material = Enum.Material.Metal, nocol = true })
	end
	local header = part("StationHeader", Vector3.new(9, 1.1, 0.35), cf * CFrame.new(0, H - 1, -1.6), Color3.fromRGB(32, 33, 36), { parent = m, material = Enum.Material.Metal })
	surfaceText(header, Enum.NormalId.Front, "◀ 이전 정류장     " .. name .. "     다음 정류장 ▶", Color3.fromRGB(240, 240, 240), Enum.Font.GothamBold)
	-- back: ad panels (lit lightboxes) left and right, route map in the middle
	local ads = { { "OHU\nFASHION WEEK\n신상 런웨이", Color3.fromRGB(235, 60, 70) }, { "만나서\n반가워요\nOHU 오후!", Color3.fromRGB(245, 120, 40) } }
	for i, x in ipairs({ -5, 5 }) do
		part("AdFrame", Vector3.new(4.6, 7.4, 0.5), cf * CFrame.new(x, 4.6, 1.8), steel, { parent = m, material = Enum.Material.Metal })
		-- a lightbox, not a glow: plain colour + a soft light
		local ad = part("AdPanel", Vector3.new(4, 6.8, 0.1), cf * CFrame.new(x, 4.6, 1.5), ads[i][2], { parent = m, nocol = true })
		local glow = Instance.new("SurfaceLight") glow.Face = Enum.NormalId.Front glow.Range = 6 glow.Brightness = 0.6 glow.Parent = ad
		surfaceText(ad, Enum.NormalId.Front, ads[i][1], Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	end
	local map = part("RouteMap", Vector3.new(4.6, 3.4, 0.15), cf * CFrame.new(0, 6, 1.8), Color3.fromRGB(240, 242, 240), { parent = m })
	surfaceText(map, Enum.NormalId.Front, "OHU 01 ─●─●─●─\nOHU 02 ─●─●─●─\nOHU 03 ─●─●─●─", Color3.fromRGB(40, 120, 60), Enum.Font.GothamBold)
	part("BackGlass", Vector3.new(4.6, 3.4, 0.1), cf * CFrame.new(0, 2.6, 1.8), Color3.fromRGB(200, 220, 228), { parent = m, material = Enum.Material.Glass, transparency = 0.6 })
	for _, x in ipairs({ -1.9, 1.9 }) do part("BenchLeg", Vector3.new(0.3, 1.6, 1), cf * CFrame.new(x, 0.8, 1), steel, { parent = m, material = Enum.Material.Metal }) end
	seat("BusBench", cf * CFrame.new(0, 1.75, 1), Vector3.new(4.4, 0.3, 1.2), Color3.fromRGB(150, 175, 180), m)
	local plate = part("StopNumber", Vector3.new(1.2, 0.8, 0.1), cf * CFrame.new(W / 2 - 1, H - 1.5, 1.55), Color3.fromRGB(40, 90, 200), { parent = m })
	surfaceText(plate, Enum.NormalId.Front, string.format("%02d-%03d", 13, 100 + n), Color3.new(1, 1, 1), Enum.Font.GothamBold)
	-- bus stop sign pole at the curb (user photo, 노원구청): green bus disc on
	-- top, black name panel + white route board, small 금연 plate. Clicking the
	-- sign opens the stop picker (SubwayService, tag BusStop)
	local signBase = base + roadDir * 5.4 + along * 9 -- at the curb, road side (user)
	local scf = CFrame.lookAt(signBase, signBase + along) -- the sign faces along the street
	-- half the size it was (user 2026-10-22)
	-- thin pole that ends inside the sign (it must not show in front of the
	-- panels, user 2026-10-22); the disc sits on top of the sign
	vcyl("BusSignPole", signBase, 0.18, 7.4, Color3.fromRGB(110, 112, 116), { parent = m, material = Enum.Material.Metal })
	local disc = part("BusSignDisc", Vector3.new(0.4, 1.15, 1.15), scf * CFrame.new(0, 7.75, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 165, 75), { parent = m, shape = Enum.PartType.Cylinder })
	for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		-- white bus, a little smaller than the disc so the whole icon shows
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 120
		g.Parent = disc
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.62, 0.62)
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://10804592292"
		img.Parent = g
	end
	local sign = part("BusStopSign", Vector3.new(1.2, 2.3, 0.5), scf * CFrame.new(0, 5.4, 0), Color3.fromRGB(28, 28, 30), { parent = m })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 80
		g.LightInfluence = 0.3
		g.Parent = sign
		local function textLabel(text, y, h, color, bg, size)
			local t = Instance.new("TextLabel")
			t.Position = UDim2.fromScale(0, y)
			t.Size = UDim2.fromScale(1, h)
			t.BackgroundColor3 = bg
			t.BorderSizePixel = 0
			t.Font = Enum.Font.GothamBold
			t.TextScaled = true
			t.TextColor3 = color
			t.Text = text
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, size) pad.PaddingRight = UDim.new(0, size) pad.PaddingTop = UDim.new(0, size // 2) pad.PaddingBottom = UDim.new(0, size // 2)
			pad.Parent = t
			t.Parent = g
		end
		textLabel(name, 0, 0.2, Color3.new(1, 1, 1), Color3.fromRGB(28, 28, 30), 6)
		textLabel("OHU 01 · OHU 02", 0.2, 0.12, Color3.fromRGB(255, 220, 90), Color3.fromRGB(28, 28, 30), 6)
		textLabel("OHU 01  ●─●─●─●\nOHU 02  ●─●─●─●\nOHU 03  ●─●─●─●", 0.34, 0.5, Color3.fromRGB(40, 110, 60), Color3.fromRGB(245, 245, 242), 8)
		textLabel("탭해서 정류장 고르기", 0.84, 0.16, Color3.new(1, 1, 1), Color3.fromRGB(40, 120, 220), 6)
	end

	sign:SetAttribute("ExitNumber", n)
	sign:SetAttribute("ExitName", name)
	sign:SetAttribute("Out", along) -- arrivals stand next to the sign, along the street
	CS:AddTag(sign, "BusStop")
	label(sign, "🚌 " .. name .. " 정류장", Color3.fromRGB(60, 140, 230), 4, 0.7)
end
busStop(1, "OHU CLUB 앞", Vector3.new(-31, 0, -130), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1))
busStop(2, "고층 빌딩가", Vector3.new(130, 0, 31), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))
busStop(3, "한옥 마을 · 광화문", Vector3.new(31, 0, 230), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
busStop(4, "광안리 해변", Vector3.new(-153, 0, 150), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))

------------------------------------------------------- 광안리 seafront
do
	-- full length of the west side (user: the whole west is beach and sea)
	local z0, z1 = -480, 300
	box("Promenade", -198, 0, z0, -182, CURB, z1, Color3.fromRGB(175, 135, 120), { material = Enum.Material.Brick })
	-- steps down to the sand (광안리 photo): granite edge, then wooden tiers;
	-- skipped where the beach cafe / pier already meet the promenade
	do
		local sandTop = CURB - BEACH_DROP
		local wood = Color3.fromRGB(120, 88, 62)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { T }
		-- 세족장 (foot wash, user photos 2026-10-23, 광안리): the steps of this
		-- stretch are granite, with taps on the sea-side face of every step
		-- (the water runs down the steps), a "발 씻는 곳 / 빨래금지" sticker, a
		-- blue 세족장 banner on the sand and a granite drinking fountain (음수대)
		local function footWash(zs, ze, sandTop)
			local G = Color3.fromRGB(150, 146, 140)
			box("BeachStepEdge", -198.7, sandTop, zs, -198, CURB + 0.1, ze, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
			local tops = { CURB - 0.6, CURB - 1.2, CURB - 1.8 }
			local xs = { { -201.2, -198.7 }, { -203.7, -201.2 }, { -206.2, -203.7 } }
			for k = 1, 3 do
				box("FootWashStep", xs[k][1], sandTop, zs, xs[k][2], tops[k], ze, G, { material = Enum.Material.Granite })
				-- taps on the riser below each tread, every 3.5
				local riserX = xs[k][1]
				local y = tops[k] - 0.3
				for z = zs + 2, ze - 1.5, 3.5 do
					local base = Vector3.new(riserX - 0.05, y, z)
					part("TapBody", Vector3.new(0.3, 0.25, 0.25), CFrame.new(base + Vector3.new(-0.15, 0, 0)), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
					part("TapSpout", Vector3.new(0.12, 0.3, 0.12), CFrame.new(base + Vector3.new(-0.3, -0.12, 0)), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
					part("TapHandle", Vector3.new(0.08, 0.08, 0.35), CFrame.new(base + Vector3.new(-0.18, 0.18, 0)), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
					part("WetStain", Vector3.new(0.9, 0.02, 0.7), CFrame.new(riserX - 0.45, (if k < 3 then tops[k + 1] else sandTop) + 0.01, z), Color3.fromRGB(110, 106, 100), { material = Enum.Material.Slate, nocol = true })
				end
			end
			-- sticker on the top riser
			local st = part("FootWashSticker", Vector3.new(0.05, 0.45, 3.4), CFrame.new(-198.75, CURB - 0.1, (zs + ze) / 2), Color3.new(1, 1, 1), { nocol = true })
			do
				local g = Instance.new("SurfaceGui")
				g.Face = Enum.NormalId.Left
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 60
				g.Parent = st
				local l = Instance.new("TextLabel")
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundColor3 = Color3.fromRGB(235, 240, 255)
				l.TextScaled = true
				l.Font = Enum.Font.GothamBold
				l.RichText = true
				l.Text = '<font color="#1d4fd8">발 씻는 곳</font> <font color="#e02424">빨래금지</font>'
				l.Parent = g
			end
			-- 세족장 banner (blue feather flag) on the sand
			local fx, fz = -209, ze - 4
			vcyl("FlagPole", Vector3.new(fx, sandTop, fz), 0.18, 11, Color3.fromRGB(190, 190, 195), { material = Enum.Material.Metal, nocol = true })
			local flag = part("FootWashFlag", Vector3.new(0.08, 7.5, 2), CFrame.new(fx, sandTop + 7, fz + 1.05), Color3.fromRGB(32, 60, 160), { nocol = true, material = Enum.Material.Fabric })
			do
				for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
					local g = Instance.new("SurfaceGui")
					g.Face = face
					g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					g.PixelsPerStud = 40
					g.Parent = flag
					local l = Instance.new("TextLabel")
					l.Size = UDim2.fromScale(1, 0.75)
					l.BackgroundTransparency = 1
					l.TextScaled = true
					l.Font = Enum.Font.GothamBlack
					l.TextColor3 = Color3.fromRGB(255, 120, 60)
					l.Text = "세\n족\n장"
					l.Parent = g
					local s = Instance.new("TextLabel")
					s.Size = UDim2.fromScale(1, 0.12)
					s.Position = UDim2.fromScale(0, 0.78)
					s.BackgroundTransparency = 1
					s.TextScaled = true
					s.Font = Enum.Font.GothamBold
					s.TextColor3 = Color3.new(1, 1, 1)
					s.Text = "Foot Washing Place"
					s.Parent = g
				end
			end
			-- 음수대 (drinking fountain): granite block with a basin and a tap,
			-- standing on the sand beside the steps
			local dx, dz = -209, ze + 2.5
			box("FountainBase", dx - 1.1, sandTop, dz - 0.9, dx + 1.1, sandTop + 3.4, dz + 0.9, Color3.fromRGB(196, 160, 140), { material = Enum.Material.Granite })
			box("FountainTop", dx - 1.3, sandTop + 3.4, dz - 1.1, dx + 1.3, sandTop + 3.7, dz + 1.1, Color3.fromRGB(196, 160, 140), { material = Enum.Material.Granite })
			box("FountainBasin", dx - 1.6, sandTop + 1.6, dz - 0.7, dx - 1.1, sandTop + 2, dz + 0.7, Color3.fromRGB(180, 145, 125), { material = Enum.Material.Granite })
			part("FountainTap", Vector3.new(0.4, 0.15, 0.15), CFrame.new(dx - 1.3, sandTop + 2.8, dz), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
			local plate = part("FountainSign", Vector3.new(0.05, 0.9, 1.4), CFrame.new(dx - 1.13, sandTop + 3.05, dz), Color3.fromRGB(120, 190, 240), { nocol = true })
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Left
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 60
			g.Parent = plate
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.TextScaled = true
			l.Font = Enum.Font.GothamBold
			l.TextColor3 = Color3.fromRGB(20, 40, 90)
			l.Text = "음수대(수돗물)\nWater Fountain"
			l.Parent = g
		end
		for zs = z0, z1 - 1, 20 do
			local ze = math.min(zs + 20, z1)
			local free = true
			local probe = CFrame.new(-201, (sandTop + CURB) / 2 + 0.2, (zs + ze) / 2)
			for _, p in ipairs(workspace:GetPartBoundsInBox(probe, Vector3.new(6, CURB - sandTop - 0.6, ze - zs - 1), params)) do
				if p.Name ~= "Beach" and p.Name ~= "Ground" and p.Transparency < 1 then free = false break end
			end
			if free and zs == -200 then -- open beach, clear of the truck and the cafes, next to the beach signs
				footWash(zs, ze, sandTop)
			elseif free then
				box("BeachStepEdge", -198.7, sandTop, zs, -198, CURB + 0.1, ze, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
				-- three wooden steps (user 2026-10-22)
				box("BeachStep", -201.2, sandTop, zs, -198.7, CURB - 0.6, ze, wood, { material = Enum.Material.WoodPlanks })
				box("BeachStep", -203.7, sandTop, zs, -201.2, CURB - 1.2, ze, wood, { material = Enum.Material.WoodPlanks })
				box("BeachStep", -206.2, sandTop, zs, -203.7, CURB - 1.8, ze, wood, { material = Enum.Material.WoodPlanks })
			end
		end
	end
	box("SeaRoad", -182, 0, z0, -158, 0.12, z1, ASPHALT, { material = Enum.Material.Asphalt })
	-- one car lane each way (-174..-166 southbound, -166..-158 northbound) and
	-- the red bike lane along the promenade. Markings as on the crossroads
	-- (ROAD_MARKINGS.md): single yellow solid centre line (편도 1차로),
	-- crosswalks 12 wide, stop lines 1.2 wide 6 before each crosswalk on the
	-- side the traffic comes from, bike symbols on the bike lane
	-- Crossings at the T junction follow the user's 광안리 photo: a zebra
	-- crosswalk and, right beside it on the junction side, a dark red bike
	-- crossing (자전거횡단도) that carries the west road's sidewalk bike lanes
	-- over the road to the bike lane on the promenade side. The bike lane keeps
	-- the road surface colour and turns dark red only where it meets crossings
	-- and the junction (자전거 이용시설 구조·시설 기준 제15조, 설치·관리 지침).
	-- 도로교통법 시행규칙 제11조 4호: no crosswalk within 100 m (집산·국지도로;
	-- 200 m elsewhere) of another crosswalk → only the T junction pair and one
	-- mid-block crossing far beyond it (-400 is 120 m from the junction)
	local CROSS = { -400, -40.7, 40.7 } -- ±40.7: the T junction pair
	local BIKE_X = { { -34.7, -27.7 }, { 27.7, 34.7 } } -- bike crossings in line with the sidewalk bike lanes (z ±29.2..33.2)
	for _, seg in ipairs({ { z0, -24 }, { 24, z1 } }) do -- lane paint stops at the junction with the west road
		paint("EdgeLine", -174.2, seg[1], -173.8, seg[2], WHITE)
		paint("CenterLine", -166.2, seg[1], -165.8, seg[2], YELLOW)
		for zz = seg[1] + 10, seg[2] - 6, 40 do
			local near = false
			for _, cz in ipairs(CROSS) do if math.abs(zz - cz) < 14 then near = true end end
			if not near then
				local mark = part("BikeSymbol", Vector3.new(3.7, 0.02, 3.7), CFrame.lookAt(Vector3.new(-178, 0.17, zz), Vector3.new(-178, 0.17, zz + 1)), WHITE, { nocol = true, transparency = 1 })
				local dcl = Instance.new("Decal")
				dcl.Texture = "rbxassetid://14547829073"
				dcl.Face = Enum.NormalId.Top
				dcl.Parent = mark
			end
		end
	end
	-- dark red bike lane where it meets a crossing (4 either side of the paint)
	for _, cz in ipairs(CROSS) do
		if math.abs(cz) > 41 then paint("BikeLaneRed", -182, cz - 10, -174.2, cz + 10, BIKE_RED) end
	end
	paint("BikeLaneRed", -182, -50.7, -174.2, 50.7, BIKE_RED) -- through the T junction
	walk(-158, z0, -150, -34) walk(-158, 34, -150, z1)
	for _, cz in ipairs(CROSS) do
		for x = -181, -159, 3 do paint("Crosswalk", x, cz - 6, x + 1.5, cz + 6, WHITE) end
		-- stop lines 6 before the crossing, on the side the traffic comes from;
		-- not on the side that has just come through the junction
		if cz ~= -40.7 then paint("StopLine", -166, cz + 12, -158, cz + 13.2, WHITE) end -- northbound (moving -z)
		if cz ~= 40.7 then paint("StopLine", -182, cz - 13.2, -166, cz - 12, WHITE) end -- southbound (+z), over the bike lane too
	end
	for _, b in ipairs(BIKE_X) do
		box("BikeCrossing", -182, 0.12, b[1], -158, 0.15, b[2], BIKE_RED, { nocol = true, material = Enum.Material.Asphalt })
		local lineZ = if b[1] < 0 then b[2] else b[1] -- white side line on the junction side only
		paint("BikeCrossingLine", -182, lineZ - 0.2, -158, lineZ + 0.2, WHITE)
		for _, x in ipairs({ -176, -164 }) do
			local mark = part("BikeSymbol", Vector3.new(3.7, 0.02, 3.7), CFrame.lookAt(Vector3.new(x, 0.18, (b[1] + b[2]) / 2), Vector3.new(x + (if x < -170 then -1 else 1), 0.18, (b[1] + b[2]) / 2)), WHITE, { nocol = true, transparency = 1 })
			local dcl = Instance.new("Decal")
			dcl.Texture = "rbxassetid://14547829073"
			dcl.Face = Enum.NormalId.Top
			dcl.Parent = mark
		end
	end
	-- T junction with the west road: crosswalk across the west road's mouth,
	-- stop line on the lanes coming out of it (+v side of the west road = north)
	for z = -22.5, 22.5, 3 do paint("Crosswalk", -156, z - 0.75, -144, z + 0.75, WHITE) end
	paint("StopLine", -138, -24, -136.8, 0, WHITE)
	-- (curb drains removed, user 2026-10-23: 430 parts for little detail)
	-- Bollards (차량진입억제용 말뚝) only where a car could drive onto the
	-- promenade: the lowered curb at each crosswalk (user 2026-10-23: far too
	-- many). 교통약자의 이동편의 증진법 시행규칙 standard: height 80–100 cm
	-- (2.6), diameter 10–20 cm (0.5), about 1.5 m (4.4) apart, a shock-
	-- absorbing material (no stone), a reflective band. Each one can still be
	-- moved / deleted by hand (D-105).
	for _, cz in ipairs(CROSS) do
		for _, dz in ipairs({ -4.4, 0, 4.4 }) do
			local base = Vector3.new(-183.5, CURB, cz + dz)
			local b = Instance.new("Model")
			b.Name = "Bollard"
			vcyl("BollardPost", base, 0.5, 2.6, Color3.fromRGB(110, 112, 118), { material = Enum.Material.SmoothPlastic, parent = b })
			vcyl("BollardBand", base + Vector3.new(0, 2.05, 0), 0.52, 0.25, Color3.fromRGB(250, 210, 40), { material = Enum.Material.SmoothPlastic, nocol = true, parent = b })
			b.WorldPivot = CFrame.new(base)
			b.Parent = T
			prop(b, "Bollard")
		end
	end
	local function pine(pos: Vector3)
		vcyl("PlanterRing", pos + Vector3.new(0, CURB, 0), 8, 1.4, Color3.fromRGB(170, 160, 150), { material = Enum.Material.Slate })
		vcyl("PlanterSoil", pos + Vector3.new(0, CURB, 0), 6.6, 1.5, Color3.fromRGB(120, 95, 70), { material = Enum.Material.Ground })
		local base = pos + Vector3.new(0, CURB + 1.5, 0)
		local trunkTop = pos + Vector3.new(1.2, 13, 0.6)
		part("PineTrunk", Vector3.new(0.9, 0.9, (trunkTop - base).Magnitude), CFrame.lookAt((base + trunkTop) / 2, trunkTop), Color3.fromRGB(120, 85, 60), { material = Enum.Material.Wood })
		for k, o in ipairs({ { 0, 0, 0, 7 }, { 2, -1.5, 1, 5 }, { -1.6, -1, -1.4, 4.6 }, { 0.8, 1.6, -0.6, 4 } }) do
			part("PineCanopy", Vector3.new(o[4], o[4], o[4]), CFrame.new(trunkTop + Vector3.new(o[1], o[2], o[3])), Color3.fromRGB(40 + k * 6, 90 + k * 4, 50), { material = Enum.Material.Grass, nocol = true, shape = Enum.PartType.Ball })
		end
		for k = 0, 3 do
			local a = k * math.pi / 2
			local foot = pos + Vector3.new(math.cos(a) * 3, CURB + 1.4, math.sin(a) * 3)
			local tip = pos + Vector3.new(0, 7, 0)
			part("PineSupport", Vector3.new(0.25, 0.25, (tip - foot).Magnitude), CFrame.lookAt((foot + tip) / 2, tip), Color3.fromRGB(110, 80, 55), { nocol = true })
		end
	end
	-- beach palms of the graybox (blocky) → the same realistic palm, as props.
	-- The blocky ones are parked in the hidden folder, put back where the
	-- built (unmoved) zone has them so "revert" restores them correctly.
	local beachZone = root:FindFirstChild("04_Beach_Aquarium")
	if beachZone then
		local undo = CFrame.new(0, BEACH_DROP, 0) -- inverse of the zone move
		for _, old in ipairs(beachZone:GetChildren()) do
			if old:IsA("Model") and old.Name == "PalmTree" then
				local cf, size = old:GetBoundingBox()
				local foot = Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)
				old:PivotTo(undo * old:GetPivot())
				old:SetAttribute("HomeZone", beachZone.Name)
				old.Parent = hidden
				-- California fan palm (user pick P4, Creator Store 130498222865089,
				-- 6 meshes instead of 67, scripts stripped), planted on the sand:
				-- the trunk foot goes 0.6 into the ground found by a raycast
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { old }
				local hit = workspace:Raycast(foot + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), params)
				local ground = if hit then hit.Position - Vector3.new(0, 0.6, 0) else foot
				local p = foliage("PalmTreeP4", 0.42 + (math.floor(foot.Z) % 3) * 0.04, CFrame.new(ground) * CFrame.Angles(0, math.rad((math.floor(foot.X * 7 + foot.Z) % 360)), 0))
				if p then
					-- foliage() sits the bounding box bottom on the point; put the
					-- trunk foot (the pivot) there instead
					p:PivotTo(CFrame.new(ground) * p:GetPivot().Rotation)
					prop(p, "Palm")
				end
			end
		end
	end
	-- no trees on the promenade any more (user 2026-10-23: keep the palms on the
	-- sand, remove the ones on the walk); lamps about every 70, clear of the
	-- crossings and the benches
	for zz = z0 + 40, z1 - 10, 70 do
		local near = false
		for _, cz in ipairs(CROSS) do if math.abs(zz - cz) < 14 then near = true end end
		local onBench = (zz - (z0 + 28)) % 60 < 8 or (zz - (z0 + 28)) % 60 > 58
		if not near and not onBench then streetLamp(Vector3.new(-196.5, CURB, zz), Vector3.new(1, 0, 0)) end
	end
	for zz = z0 + 28, z1, 60 do
		box("BenchBase", -197.5, CURB, zz, -195.5, CURB + 1.6, zz + 6, Color3.fromRGB(110, 110, 115))
		-- wooden top along the bench, two seats side by side (user 2026-10-23)
		for _, dz in ipairs({ 1.5, 4.5 }) do
			seat("PromenadeBench", CFrame.lookAt(Vector3.new(-196.5, CURB + 1.8, zz + dz), Vector3.new(-260, CURB + 1.8, zz + dz)), Vector3.new(3, 0.4, 2), Color3.fromRGB(160, 110, 70))
		end
	end
	-- 광안대교 (suspension bridge) out in the sea, lit purple at night
	local bx, deckY = -820, 34
	local purple = Color3.fromRGB(190, 90, 255)
	box("BridgeDeck", bx - 10, deckY - 2, -760, bx + 10, deckY, 760, Color3.fromRGB(200, 200, 205))
	for _, s in ipairs({ -1, 1 }) do box("BridgeLight", bx + s * 10 - 0.3, deckY - 2.5, -760, bx + s * 10 + 0.3, deckY - 1.8, 760, purple, { material = Enum.Material.Neon, nocol = true }) end
	for _, tz in ipairs({ -260, 260 }) do
		for _, s in ipairs({ -1, 1 }) do box("BridgeTowerLeg", bx + s * 9 - 2, -24, tz - 2, bx + s * 9 + 2, 150, tz + 2, Color3.fromRGB(215, 215, 220)) end
		box("BridgeTowerBeam", bx - 11, 120, tz - 2, bx + 11, 126, tz + 2, Color3.fromRGB(215, 215, 220))
		box("BridgeTowerBeam", bx - 11, 70, tz - 2, bx + 11, 75, tz + 2, Color3.fromRGB(215, 215, 220))
	end
	for _, s in ipairs({ -1, 1 }) do
		local pts = {}
		for k = 0, 24 do
			local zz = -760 + k * (1520 / 24)
			local y
			if math.abs(zz) <= 260 then y = deckY + 12 + (150 - deckY - 12) * (zz / 260) ^ 2 else y = 150 - (150 - deckY - 4) * ((math.abs(zz) - 260) / 500) end
			table.insert(pts, Vector3.new(bx + s * 9, y, zz))
		end
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			part("BridgeCable", Vector3.new(0.8, 0.8, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), purple, { material = Enum.Material.Neon, nocol = true })
		end
	end
	label(box("BridgeLabel", bx - 1, 160, -1, bx + 1, 161, 1, purple, { transparency = 1, nocol = true }), "광안대교", purple, 0, 1)
end

------------------------------------------------------- 광화문 + plaza + 해태 + hills
do
	local G = Instance.new("Model")
	G.Name = "Gwanghwamun"
	G.Parent = T
	local stone = Color3.fromRGB(185, 178, 165)
	local granite = Color3.fromRGB(200, 196, 188)
	local wood = Color3.fromRGB(150, 55, 40)
	local roofC = Color3.fromRGB(60, 62, 66)
	local gx0, gx1, gz0, gz1 = 82, 96, 140, 196 -- in front of the village back wall (gate at z 168, v7c)
	local H = 12
	-- stone base with 3 arched openings (centre 10 wide, sides 6)
	local cuts = { gz0, 149, 155, 163, 173, 181, 187, gz1 }
	for i = 1, #cuts - 1, 2 do box("GateStone", gx0, 0, cuts[i], gx1, H, cuts[i + 1], stone, { parent = G, material = Enum.Material.Slate }) end
	for _, o in ipairs({ { 163, 173, 9 }, { 149, 155, 7 }, { 181, 187, 7 } }) do
		box("GateStoneTop", gx0, o[3], o[1], gx1, H, o[2], stone, { parent = G, material = Enum.Material.Slate })
		box("ArchTrim", gx0 - 0.2, o[3] - 0.6, o[1], gx0, o[3], o[2], Color3.fromRGB(120, 115, 105), { parent = G })
	end
	box("PavilionFloor", gx0 + 1, H, gz0 + 4, gx1 - 1, H + 1, gz1 - 4, granite, { parent = G })
	for zz = gz0 + 6, gz1 - 6, 8 do
		for _, xx in ipairs({ gx0 + 2.5, gx1 - 2.5 }) do vcyl("PavilionColumn", Vector3.new(xx, H + 1, zz), 1, 7, wood, { parent = G }) end
	end
	box("PavilionWall", gx0 + 3, H + 5, gz0 + 6, gx1 - 3, H + 8, gz1 - 6, Color3.fromRGB(60, 120, 90), { parent = G })
	local function hipRoof(y, x0, x1, z0, z1, rise)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local w, d = x1 - x0, z1 - z0
		part("RoofSlope", Vector3.new(d, rise, w / 2), CFrame.new(cx - w / 4, y + rise / 2, cz) * CFrame.Angles(0, math.rad(90), 0), roofC, { parent = G, class = "WedgePart", material = Enum.Material.Slate })
		part("RoofSlope", Vector3.new(d, rise, w / 2), CFrame.new(cx + w / 4, y + rise / 2, cz) * CFrame.Angles(0, math.rad(-90), 0), roofC, { parent = G, class = "WedgePart", material = Enum.Material.Slate })
		box("RoofRidge", cx - 0.5, y + rise, z0 + 2, cx + 0.5, y + rise + 0.8, z1 - 2, Color3.fromRGB(230, 230, 230), { parent = G })
		box("Eave", x0, y - 0.4, z0, x1, y, z1, roofC, { parent = G })
	end
	hipRoof(H + 8, gx0 - 3, gx1 + 3, gz0 + 1, gz1 - 1, 4)
	box("UpperFloor", gx0 + 2, H + 12, gz0 + 10, gx1 - 2, H + 15, gz1 - 10, wood, { parent = G })
	hipRoof(H + 15, gx0 - 1, gx1 + 1, gz0 + 6, gz1 - 6, 5)
	local plaque = box("NamePlaque", gx0 - 0.4, H + 12.4, 164, gx0 - 0.1, H + 14.6, 172, Color3.fromRGB(30, 30, 35), { parent = G })
	surfaceText(plaque, Enum.NormalId.Left, "光化門", Color3.fromRGB(230, 200, 120), Enum.Font.Antique)
	label(plaque, "광화문 (한옥 마을 서쪽 입구)", Color3.fromRGB(150, 60, 40), 8, 0.9)
	-- plaza in front: stone paving, central path, lawns on both sides
	box("PlazaStone", WIDE, 0, 118, 82, 0.3, 218, granite, { parent = G, material = Enum.Material.Slate })
	box("PlazaPath", WIDE, 0.3, 160, 82, 0.35, 176, Color3.fromRGB(215, 210, 200), { parent = G, material = Enum.Material.Slate })
	box("PlazaLawn", 51, 0.3, 122, 72, 0.45, 154, Color3.fromRGB(90, 165, 80), { parent = G, material = Enum.Material.Grass })
	box("PlazaLawn", 51, 0.3, 182, 72, 0.45, 214, Color3.fromRGB(90, 165, 80), { parent = G, material = Enum.Material.Grass })
	local function haetae(pos: Vector3, facing: Vector3)
		local cf = CFrame.lookAt(pos, pos + facing)
		local c1, c2 = Color3.fromRGB(170, 165, 155), Color3.fromRGB(160, 155, 145)
		part("HaetaePedestal", Vector3.new(4, 5, 5), cf * CFrame.new(0, 2.5, 0), stone, { parent = G, material = Enum.Material.Slate })
		part("HaetaeBody", Vector3.new(2.6, 2.6, 3.6), cf * CFrame.new(0, 6.3, 0.3), c1, { parent = G, material = Enum.Material.Slate })
		part("HaetaeChest", Vector3.new(2.4, 3, 1.6), cf * CFrame.new(0, 7.4, -1.2), c1, { parent = G, material = Enum.Material.Slate })
		part("HaetaeHead", Vector3.new(2.6, 2.6, 2.6), cf * CFrame.new(0, 9.6, -1.6), c1, { parent = G, material = Enum.Material.Slate, shape = Enum.PartType.Ball })
		part("HaetaeMane", Vector3.new(3, 2, 1.2), cf * CFrame.new(0, 9.2, -0.6), c2, { parent = G, material = Enum.Material.Slate })
		part("HaetaeHorn", Vector3.new(0.5, 1, 0.5), cf * CFrame.new(0, 11.2, -1.6), c2, { parent = G })
		for _, lx in ipairs({ -0.8, 0.8 }) do part("HaetaeLeg", Vector3.new(0.7, 2, 0.7), cf * CFrame.new(lx, 6, -1.6), c2, { parent = G, material = Enum.Material.Slate }) end
	end
	haetae(Vector3.new(76, 0.3, 152), Vector3.new(-1, 0, 0))
	haetae(Vector3.new(76, 0.3, 184), Vector3.new(-1, 0, 0))
	for _, mnt in ipairs(MOUNTAINS) do
		workspace.Terrain:FillBall(mnt[1], mnt[2], Enum.Material.Grass)
		workspace.Terrain:FillBall(mnt[1] + Vector3.new(0, mnt[2] * 0.55, 0), mnt[2] * 0.35, Enum.Material.Rock)
	end
	T:SetAttribute("Mountains", true)
end

------------------------------------------------------- 에버랜드-style park gate
-- the park fits the user's red box (x -148..-38, z -475..-229); the gate faces
-- south onto an empty lot (kept free for later)
do
	local E = Instance.new("Model")
	E.Name = "AmusementParkGate"
	E.Parent = T
	local cream = Color3.fromRGB(245, 235, 210)
	local blue = Color3.fromRGB(70, 110, 170)
	local roofBlue = Color3.fromRGB(60, 90, 140)
	local x0, x1, z0, z1 = -148, -38, -475, -229
	local gateX0, gateX1 = -123, -63
	box("ParkGround", x0 + 1, 0, z0 + 1, x1 - 1, 0.25, z1 - 1, Color3.fromRGB(110, 175, 95), { parent = E, material = Enum.Material.Grass })
	-- perimeter wall: parks are closed off by themed walls so the outside is
	-- hidden and everyone enters through the main gate
	local function wallSeg(ax, az, bx, bz)
		box("ParkWall", ax, 0, az, bx, 12, bz, cream, { parent = E })
		box("ParkWallTop", ax - 0.3, 12, az - 0.3, bx + 0.3, 13, bz + 0.3, roofBlue, { parent = E })
	end
	wallSeg(x0, z0, x0 + 1, z1) wallSeg(x1 - 1, z0, x1, z1) wallSeg(x0, z0, x1, z0 + 1)
	wallSeg(x0, z1 - 1, gateX0, z1) wallSeg(gateX1, z1 - 1, x1, z1)
	local function turret(cx, cz, s, h, base)
		box("Turret", cx - s / 2, base or 0, cz - s / 2, cx + s / 2, h, cz + s / 2, cream, { parent = E })
		box("TurretBand", cx - s / 2 - 0.2, h - 1, cz - s / 2 - 0.2, cx + s / 2 + 0.2, h, cz + s / 2 + 0.2, blue, { parent = E })
		for k = 0, 3 do
			part("TurretRoof", Vector3.new(s + 1, s * 0.8, (s + 1) / 2), CFrame.new(cx, h + s * 0.4, cz) * CFrame.Angles(0, math.rad(k * 90), 0) * CFrame.new(0, 0, (s + 1) / 4), roofBlue, { parent = E, class = "WedgePart" })
		end
		vcyl("Pinnacle", Vector3.new(cx, h + s * 0.8, cz), 0.4, 3, Color3.fromRGB(220, 190, 90), { parent = E })
	end
	for _, c in ipairs({ { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } }) do turret(c[1], c[2], 8, 16) end
	-- main gate (user photo 2026-10-23, an ADVENTURELAND-style arch): two tall
	-- sandstone towers with carved panels, domes and spires carry a big
	-- arched sign band "OHU LAND"; lower outer towers with half arches on
	-- each side, black iron fences between the gate and the park walls.
	local STONE, CARVE = Color3.fromRGB(214, 194, 156), Color3.fromRGB(176, 152, 112)
	local DOME, GOLD = Color3.fromRGB(120, 128, 140), Color3.fromRGB(214, 172, 80)
	local gz0, gz1 = z1 - 3, z1 + 5 -- gate depth (south face at gz1)
	local gzc = (gz0 + gz1) / 2
	local CX = (gateX0 + gateX1) / 2
	local function gtower(cx, s, h)
		box("GateTowerBase", cx - s / 2 - 0.6, 0, gzc - s / 2 - 0.6, cx + s / 2 + 0.6, 3, gzc + s / 2 + 0.6, CARVE, { parent = E, material = Enum.Material.Sandstone })
		box("GateTower", cx - s / 2, 3, gzc - s / 2, cx + s / 2, h, gzc + s / 2, STONE, { parent = E, material = Enum.Material.Sandstone })
		-- carved panel + relief figure on the street face
		box("GateCarving", cx - s / 2 + 0.8, h * 0.3, gzc + s / 2, cx + s / 2 - 0.8, h * 0.72, gzc + s / 2 + 0.3, CARVE, { parent = E, material = Enum.Material.Sandstone })
		vcyl("GateRelief", Vector3.new(cx, h * 0.36, gzc + s / 2 + 0.1), s * 0.35, h * 0.3, Color3.fromRGB(196, 176, 138), { parent = E, material = Enum.Material.Sandstone })
		-- capital, drum, dome, spire
		box("GateCapital", cx - s / 2 - 0.8, h, gzc - s / 2 - 0.8, cx + s / 2 + 0.8, h + 1.4, gzc + s / 2 + 0.8, CARVE, { parent = E, material = Enum.Material.Sandstone })
		vcyl("GateDrum", Vector3.new(cx, h + 1.4, gzc), s * 0.8, 2.2, STONE, { parent = E, material = Enum.Material.Sandstone })
		part("GateDome", Vector3.new(s * 0.85, s * 0.85, s * 0.85), CFrame.new(cx, h + 3.6, gzc), DOME, { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Metal })
		vcyl("GateSpire", Vector3.new(cx, h + 3.6 + s * 0.4, gzc), 0.45, 3.4, GOLD, { parent = E, material = Enum.Material.Foil })
		part("GateFinial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(cx, h + 7.4 + s * 0.4, gzc), GOLD, { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Foil })
	end
	-- an arch band between two x positions: base height y0, rise at the middle
	local function archBand(xa, xb, y0, rise, thick, name, color, mat)
		local N = 14
		local prev
		for k = 0, N do
			local tt = k / N
			local x = xa + (xb - xa) * tt
			local y = y0 + rise * math.sin(math.pi * tt)
			local pnt = Vector3.new(x, y, gzc)
			if prev then
				local d = pnt - prev
				part(name, Vector3.new(d.Magnitude + 0.3, thick, gz1 - gz0 - 1), CFrame.fromMatrix((prev + pnt) / 2, d.Unit, Vector3.zAxis:Cross(d.Unit)), color, { parent = E, material = mat })
			end
			prev = pnt
		end
	end
	local MAIN_S, MAIN_H, OUT_S, OUT_H = 7, 30, 5.5, 21
	local mainL, mainR = CX - 14, CX + 14
	local outL, outR = gateX0 + 4, gateX1 - 4
	gtower(mainL, MAIN_S, MAIN_H) gtower(mainR, MAIN_S, MAIN_H)
	gtower(outL, OUT_S, OUT_H) gtower(outR, OUT_S, OUT_H)
	-- big arch with the sign band
	local ax0, ax1 = mainL + MAIN_S / 2, mainR - MAIN_S / 2
	archBand(ax0, ax1, 19, 5, 1.4, "GateArch", CARVE, Enum.Material.Sandstone)
	archBand(ax0, ax1, 23.2, 5, 1.2, "GateArchTop", STONE, Enum.Material.Sandstone)
	-- sign: dark band in the middle of the arch, gold letters
	part("GateSignFrame", Vector3.new(ax1 - ax0 - 2.6, 4.6, 0.5), CFrame.new(CX, 24.6, gz1 - 0.4), GOLD, { parent = E, material = Enum.Material.Foil })
	local sign = part("GateSign", Vector3.new(ax1 - ax0 - 3.4, 3.8, 0.4), CFrame.new(CX, 24.6, gz1 - 0.1), Color3.fromRGB(62, 54, 44), { parent = E })
	do
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back -- the street side (+z)
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.4
		g.Parent = sign
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(0.92, 0.86)
		l.Position = UDim2.fromScale(0.04, 0.07)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.Fondamento
		l.TextColor3 = GOLD
		l.TextStrokeColor3 = Color3.fromRGB(40, 30, 15)
		l.TextStrokeTransparency = 0.3
		l.Text = "OHU  LAND"
		l.Parent = g
	end
	part("GateCrest", Vector3.new(6, 3, 0.6), CFrame.new(CX, 29.8, gzc), CARVE, { parent = E, material = Enum.Material.Sandstone })
	part("GateCrestBall", Vector3.new(1.4, 1.4, 1.4), CFrame.new(CX, 31.6, gzc), GOLD, { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Foil })
	-- side half arches from the outer towers to the main towers
	archBand(outL + OUT_S / 2, mainL - MAIN_S / 2, 13, 3, 1.4, "GateSideArch", CARVE, Enum.Material.Sandstone)
	archBand(mainR + MAIN_S / 2, outR - OUT_S / 2, 13, 3, 1.4, "GateSideArch", CARVE, Enum.Material.Sandstone)
	-- black iron fences + open iron gates under the side arches, fences out to the walls
	local IRON = Color3.fromRGB(28, 28, 32)
	local function fence(xa, xb, h)
		box("FenceRail", xa, h - 0.6, gzc - 0.15, xb, h - 0.3, gzc + 0.15, IRON, { parent = E })
		box("FenceRail", xa, 1, gzc - 0.15, xb, 1.3, gzc + 0.15, IRON, { parent = E })
		for x = xa, xb, 0.8 do box("FenceBar", x - 0.07, 0, gzc - 0.07, x + 0.07, h, gzc + 0.07, IRON, { parent = E, nocol = true }) end
	end
	fence(gateX0, outL - OUT_S / 2, 9) fence(outR + OUT_S / 2, gateX1, 9)
	-- side passages stay open (people walk through), gates folded back
	for _, x in ipairs({ outL + OUT_S / 2 + 0.6, mainL - MAIN_S / 2 - 0.6, mainR + MAIN_S / 2 + 0.6, outR - OUT_S / 2 - 0.6 }) do
		box("GateLeaf", x - 0.2, 0, gzc - 3, x + 0.2, 9, gzc + 0.2, IRON, { parent = E, nocol = true })
	end
	label(sign, "놀이공원 정문", Color3.fromRGB(60, 90, 140), 8, 0.9)	local function booth(bx0, bz0, bx1, bz1, title, windows)
		box("BoothBody", bx0, 0, bz0, bx1, 9, bz1, cream, { parent = E })
		box("BoothBase", bx0 - 0.3, 0, bz0 - 0.3, bx1 + 0.3, 1.5, bz1 + 0.3, blue, { parent = E })
		for k = 0, 3 do
			part("BoothRoof", Vector3.new(bx1 - bx0 + 2, 4, (bz1 - bz0 + 2) / 2), CFrame.new((bx0 + bx1) / 2, 11, (bz0 + bz1) / 2) * CFrame.Angles(0, math.rad(k * 90), 0) * CFrame.new(0, 0, (bz1 - bz0 + 2) / 4), roofBlue, { parent = E, class = "WedgePart" })
		end
		local ww = (bx1 - bx0) / windows
		for k = 0, windows - 1 do
			box("BoothWindow", bx0 + k * ww + 0.8, 3, bz1, bx0 + (k + 1) * ww - 0.8, 7, bz1 + 0.2, Color3.fromRGB(150, 190, 220), { parent = E, material = Enum.Material.Glass })
			box("BoothSill", bx0 + k * ww + 0.6, 2.8, bz1, bx0 + (k + 1) * ww - 0.6, 3.1, bz1 + 0.8, blue, { parent = E })
		end
		local b = box("BoothSign", bx0 + 1, 7.4, bz1 + 0.2, bx1 - 1, 8.8, bz1 + 0.4, blue, { parent = E })
		surfaceText(b, Enum.NormalId.Back, title, Color3.new(1, 1, 1), Enum.Font.GothamBold)
		label(b, title, Color3.fromRGB(60, 90, 140), 6, 0.6)
	end
	booth(-146, -226, -130, -216, "매표소 TICKETS", 2)
	booth(-56, -226, -46, -218, "i 안내", 1)
	-- inside: round symbol plaza (round flower bed + a pedestal for the park's
	-- landmark / character sculpture, to be designed)
	local pc = Vector3.new(-93, 0.25, -262)
	vcyl("SymbolPlaza", pc, 50, 0.35, Color3.fromRGB(215, 205, 190), { parent = E, material = Enum.Material.Slate })
	vcyl("FlowerBed", pc + Vector3.new(0, 0.35, 0), 24, 1.4, Color3.fromRGB(90, 160, 80), { parent = E, material = Enum.Material.Grass })
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		part("Flower", Vector3.new(1.6, 1.6, 1.6), CFrame.new(pc + Vector3.new(math.cos(a) * 10, 2.3, math.sin(a) * 10)), SIGNS[(k % #SIGNS) + 1], { parent = E, shape = Enum.PartType.Ball, nocol = true })
	end
	local ped = vcyl("SymbolPedestal", pc + Vector3.new(0, 1.75, 0), 8, 2, Color3.fromRGB(235, 230, 220), { parent = E })
	label(ped, "★ 상징물 자리 (캐릭터 조형물 예정)", Color3.fromRGB(200, 120, 40), 6, 0.8)
	box("GatePlaza", gateX0 - 8, 0, gz1, gateX1 + 8, 0.3, gz1 + 14, Color3.fromRGB(215, 205, 190), { parent = E, material = Enum.Material.Slate })
end
------------------------------------------------------- club facade (references)
do
	local K = Instance.new("Model")
	K.Name = "ClubFacade"
	K.Parent = T
	-- Black club front like the user's references (2026-10-23, 이태원 KING
	-- CLUB photos): black cladding, a black sign band with spaced white
	-- letters and a crown, black horizontal louvres and a row of tall
	-- black-framed windows above, a gold mirror-panel portal around the door,
	-- gold strips along the ground floor and a low black iron fence. The
	-- graybox walls are lilac; the cladding covers their outside faces.
	local BLACK, BLACK2 = Color3.fromRGB(26, 27, 30), Color3.fromRGB(40, 42, 46)
	local GOLD = Color3.fromRGB(214, 172, 92)
	local DZ0, DZ1 = -189 + CDZ, -167 + CDZ -- door gap (with its gold frame)
	local Z0, Z1, TOPY = -260.2 + CDZ, -95.8 + CDZ, 37 -- to the outer faces of the lilac side walls
	local function gold(name, x0, y0, z0, x1, y1, z1)
		local p = box(name, x0, y0, z0, x1, y1, z1, GOLD, { parent = K, material = Enum.Material.Foil })
		p.Reflectance = 0.25
		return p
	end
	-- backing (hides the lilac) on the west face and the other outside faces
	box("Cladding", 47.8, 0, Z0, 48, TOPY, DZ0, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 47.8, 0, DZ1, 48, TOPY, Z1, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 47.8, 12, DZ0, 48, TOPY, DZ1, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 48, 0, -260.2 + CDZ, 171.2, TOPY, -260 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 171, 0, -260.2 + CDZ, 171.2, TOPY, -95.8 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 48, 0, -96 + CDZ, 171.2, TOPY, -95.8 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal })
	box("CapBand", 47.3, TOPY - 0.8, Z0 - 2, 48, TOPY + 0.4, Z1 + 1, BLACK2, { parent = K, material = Enum.Material.Metal })
	-- ground floor: gold strips, gold portal around the door
	gold("GoldStrip", 47.5, 6.4, -242 + CDZ, 47.8, 7, -196 + CDZ)
	gold("GoldStrip", 47.5, 6.4, -160 + CDZ, 47.8, 7, -114 + CDZ)
	gold("GoldJamb", 45.8, 0, DZ0 - 3, 47.8, 15, DZ0)
	gold("GoldJamb", 45.8, 0, DZ1, 47.8, 15, DZ1 + 3)
	gold("GoldLintel", 45.8, 12, DZ0, 47.8, 15, DZ1)
	for _, zz in ipairs({ DZ0 + 0.2, DZ1 - 0.2 }) do gold("GoldDoorFrame", 46.6, 0.1, zz - 0.2, 47.8, 12, zz + 0.2) end
	-- sign band with spaced white letters and the crown
	local band = box("ClubSign", 46.4, 15, -250 + CDZ, 47.8, 20.6, -106 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal })
	do
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Left
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 20
		g.LightInfluence = 0.6
		g.Parent = band
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.52)
		l.Size = UDim2.fromScale(0.5, 0.7)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.Michroma
		l.TextColor3 = Color3.fromRGB(245, 245, 245)
		l.Text = "O H U                C L U B" -- the gold crown sits in the gap
		l.Parent = g
	end
	-- gold crown above the portal
	do
		local cz, cy = (DZ0 + DZ1) / 2, 15.6
		gold("CrownBase", 45.4, cy, cz - 2.6, 45.9, cy + 0.9, cz + 2.6)
		for k = -2, 2 do
			local h = if k == 0 then 2.6 elseif math.abs(k) == 1 then 1.8 else 2.2
			gold("CrownSpike", 45.4, cy + 0.9, cz + k * 1.2 - 0.3, 45.9, cy + 0.9 + h, cz + k * 1.2 + 0.3)
			local b = part("CrownJewel", Vector3.new(0.6, 0.6, 0.6), CFrame.new(45.65, cy + 1.2 + h, cz + k * 1.2), GOLD, { parent = K, shape = Enum.PartType.Ball, material = Enum.Material.Foil })
			b.Reflectance = 0.25
		end
	end
	-- upper floors: horizontal louvres + a run of tall black-framed windows
	local WZ0, WZ1 = -232 + CDZ, -150 + CDZ
	for y = 21.4, TOPY - 1.2, 1.1 do
		for _, r in ipairs({ { Z0, WZ0 }, { WZ1, Z1 } }) do
			box("Louvre", 47.3, y, r[1], 47.8, y + 0.35, r[2], BLACK2, { parent = K, material = Enum.Material.Metal })
		end
	end
	box("WindowGlass", 47.6, 22, WZ0, 47.8, 33.5, WZ1, Color3.fromRGB(38, 46, 54), { parent = K, material = Enum.Material.Glass })
	box("WindowFrame", 47.2, 21.4, WZ0, 47.8, 22, WZ1, BLACK, { parent = K })
	box("WindowFrame", 47.2, 33.5, WZ0, 47.8, 34.1, WZ1, BLACK, { parent = K })
	for zz = WZ0, WZ1, 5.5 do box("WindowMullion", 47.2, 22, zz - 0.25, 47.8, 33.5, zz + 0.25, BLACK, { parent = K }) end
	-- low black iron fence along the front (gaps at the door and the queue)
	for _, r in ipairs({ { -256 + CDZ, DZ0 - 4 }, { DZ1 + 4, -158 + CDZ } }) do
		box("FenceRail", 46.3, 3, r[1], 46.5, 3.2, r[2], BLACK, { parent = K })
		box("FenceRail", 46.3, 0.8, r[1], 46.5, 1, r[2], BLACK, { parent = K })
		for zz = r[1], r[2], 0.6 do box("FencePicket", 46.35, CURB, zz - 0.05, 46.45, 3.2, zz + 0.05, BLACK, { parent = K, nocol = true }) end
	end
	-- the pink graybox marquee would cover the band: hidden while the layout is on
	local clubZone = root:FindFirstChild("02_Club")
	local marquee = clubZone and clubZone:FindFirstChild("Marquee_Landmark")
	if marquee and marquee:IsA("BasePart") then
		marquee:SetAttribute("OrigTransparency", marquee.Transparency)
		marquee.Transparency = 1
	end
	-- pink neon rooftop rails → dark, to match the black front
	if clubZone then
		for _, p in ipairs(clubZone:GetChildren()) do
			if p:IsA("BasePart") and (p.Name == "RooftopRailing" or p.Name == "RooftopSign") then
				p:SetAttribute("OrigColor", p.Color)
				p.Color = Color3.fromRGB(34, 35, 38)
			end
		end
	end
	-- red carpet, rope posts and the queue ropes removed (user 2026-10-23);
	-- the graybox ones are parked in the hidden folder while the layout is on
	do
		local clubZ = root:FindFirstChild("02_Club")
		local undo = MOVES["02_Club"]:Inverse()
		if clubZ then
			for _, c in ipairs(clubZ:GetChildren()) do
				-- the name labels of the photo wall and the outdoor lift pad go too
				local bb = c:FindFirstChildWhichIsA("BillboardGui")
				local tl = bb and bb:FindFirstChildWhichIsA("TextLabel")
				local labelHere = c.Name == "Label" and tl ~= nil and (string.find(tl.Text, "포토월") ~= nil or (string.find(tl.Text, "엘리베이터") ~= nil and c.Position.Y < 20))
				if c:IsA("BasePart") and (c.Name == "RedCarpetYard" or c.Name == "RopePost" or c.Name == "Rope" or c.Name == "PhotoWall" or c.Name == "PhotoSpot" or c.Name == "DoormanNPC(placeholder)" or labelHere) then
					c.CFrame = undo * c.CFrame
					c:SetAttribute("HomeZone", clubZ.Name)
					c.Parent = hidden
				end
			end
		end
	end
	-- (white tent and the red-carpet photo wall removed, user 2026-10-23)

	-- Rooftop lift inside the club (user 2026-10-23): the corridor to the
	-- right of the entrance (south, +z) runs on into the solid entry fill and
	-- ends at a lift car with an automatic door; the graybox ElevatorPadUp
	-- (GrayboxElevator script) moves onto the car floor, so stepping in sends
	-- the player to the roof, and the way back lands in the corridor.
	do
		local clubZ = root:FindFirstChild("02_Club")
		local undo = MOVES["02_Club"]:Inverse()
		local CX0, CX1 = 50, 65.5 -- inside faces of the front wall and the hall wall
		local FOYER_END = -165.5 + CDZ -- the old foyer end wall
		local CAR0, CAR1 = -152 + CDZ, -143 + CDZ -- lift car (door at CAR0)
		local FILL_END = -98 + CDZ
		local DARK = Color3.fromRGB(28, 28, 32)
		local function park(c: BasePart)
			c.CFrame = undo * c.CFrame
			c:SetAttribute("HomeZone", clubZ.Name)
			c.Parent = hidden
		end
		if clubZ then
			for _, c in ipairs(clubZ:GetChildren()) do
				if c:IsA("BasePart") and (c.Name == "Foyer_E" or c.Name == "Entry_Fill") then park(c) end
			end
		end
		local E = Instance.new("Model")
		E.Name = "ClubLift"
		E.Parent = T
		-- corridor: floor, ceiling, black walls
		box("LiftCorridorFloor", CX0, -0.5, FOYER_END - 0.5, CX1, 0, CAR0, Color3.fromRGB(34, 34, 40), { parent = E, material = Enum.Material.Marble })
		box("LiftCorridorCeiling", CX0, 12, FOYER_END - 0.5, CX1, 13, CAR1 + 0.6, DARK, { parent = E })
		-- the rest of the old fill behind the car stays solid
		box("EntryFillRest", CX0 - 0.1, -24, CAR1 + 0.6, CX1 + 0.1, 36, FILL_END, Color3.fromRGB(40, 42, 46), { parent = E })
		-- strip lights along the corridor ceiling
		for z = FOYER_END + 2, CAR0 - 2, 4 do
			local l = box("LiftCorridorLight", 56.6, 11.8, z - 0.8, 58.9, 12, z + 0.8, Color3.fromRGB(255, 240, 220), { parent = E, nocol = true })
			local pl = Instance.new("PointLight") pl.Range = 10 pl.Brightness = 0.7 pl.Color = Color3.fromRGB(255, 225, 200) pl.Parent = l
		end
		-- lift car: brushed steel walls, gold frame, floor pad
		local STEEL = Color3.fromRGB(150, 152, 158)
		box("LiftCarFloor", CX0, -0.5, CAR0, CX1, 0, CAR1, Color3.fromRGB(60, 60, 66), { parent = E, material = Enum.Material.Metal })
		box("LiftCarBack", CX0, 0, CAR1, CX1, 12, CAR1 + 0.6, STEEL, { parent = E, material = Enum.Material.Metal })
		box("LiftCarCeiling", CX0, 11.4, CAR0, CX1, 12, CAR1, STEEL, { parent = E, material = Enum.Material.Metal })
		local cl = box("LiftCarLight", 55, 11.3, CAR0 + 2, 60.5, 11.4, CAR1 - 2, Color3.fromRGB(255, 250, 240), { parent = E, nocol = true })
		local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 12 sl.Brightness = 1 sl.Parent = cl
		-- front wall with the door opening (door 7 wide in the middle)
		local mid, DOOR = (CX0 + CX1) / 2, 7
		box("LiftFront", CX0, 0, CAR0 - 0.5, mid - DOOR / 2, 12, CAR0, DARK, { parent = E })
		box("LiftFront", mid + DOOR / 2, 0, CAR0 - 0.5, CX1, 12, CAR0, DARK, { parent = E })
		box("LiftFront", mid - DOOR / 2, 9, CAR0 - 0.5, mid + DOOR / 2, 12, CAR0, DARK, { parent = E })
		for _, s in ipairs({ -1, 1 }) do
			box("LiftFrameGold", mid + s * (DOOR / 2 + 0.3) - 0.3, 0, CAR0 - 0.7, mid + s * (DOOR / 2 + 0.3) + 0.3, 9.3, CAR0 - 0.4, Color3.fromRGB(214, 172, 92), { parent = E, material = Enum.Material.Foil, nocol = true })
		end
		box("LiftFrameGold", mid - DOOR / 2 - 0.6, 9, CAR0 - 0.7, mid + DOOR / 2 + 0.6, 9.4, CAR0 - 0.4, Color3.fromRGB(214, 172, 92), { parent = E, material = Enum.Material.Foil, nocol = true })
		local door = Instance.new("Model")
		door.Name = "AutoDoor"
		door:SetAttribute("Range", 8)
		for _, s in ipairs({ -1, 1 }) do
			local panel = box("LiftDoorPanel", mid + s * DOOR / 2, 0, CAR0 - 0.35, mid, 9, CAR0 - 0.15, Color3.fromRGB(175, 178, 184), { parent = door, material = Enum.Material.Metal })
			panel:SetAttribute("Slide", Vector3.new(s * (DOOR / 2 - 0.1), 0, 0))
		end
		door.WorldPivot = CFrame.new(mid, 4, CAR0)
		door.Parent = E
		CS:AddTag(door, "AutoDoor")
		local sign = box("LiftSign", mid - 3, 9.7, CAR0 - 0.75, mid + 3, 11, CAR0 - 0.7, Color3.fromRGB(15, 15, 18), { parent = E, nocol = true })
		surfaceText(sign, Enum.NormalId.Front, "▲ ROOFTOP", Color3.fromRGB(255, 120, 210), Enum.Font.Michroma)
		-- the graybox pad onto the car floor; its local +Z points back into the
		-- corridor (the script lands arrivals 10 studs along it)
		local pad = clubZ and clubZ:FindFirstChild("ElevatorPadUp")
		if pad and pad:IsA("BasePart") then
			pad:SetAttribute("OrigCFrame", pad.CFrame)
			local pc = Vector3.new(mid, 0.1, (CAR0 + CAR1) / 2 + 0.5)
			pad.CFrame = CFrame.lookAt(pc, pc + Vector3.new(0, 0, 1))
		end
	end
	local clock = box("ClockBoard", 48.2, 9, -134 + CLUB_DZ, 48.7, 13, -120 + CLUB_DZ, Color3.fromRGB(10, 10, 15), { parent = K })
	surfaceText(clock, Enum.NormalId.Left, "OPEN 22:00", Color3.fromRGB(80, 230, 255), Enum.Font.Michroma)
end

------------------------------------------------------- high-rises + shop fronts
local FACE = { W = Enum.NormalId.Left, E = Enum.NormalId.Right, N = Enum.NormalId.Front, S = Enum.NormalId.Back }
local function tower(x0, z0, x1, z1, h, kind, face, shop, screen)
	local m = Instance.new("Model")
	m.Name = "BG_Tower(진입불가)"
	local glass = kind == "glass"
	local body = box("Body", x0, 0, z0, x1, h, z1, if glass then Color3.fromRGB(105, 135, 160) else Color3.fromRGB(185, 180, 172), { parent = m, material = if glass then Enum.Material.Glass else Enum.Material.Concrete })
	if glass then body.Reflectance = 0.15 end
	local step = if glass then 6 else 7
	for y = step, h - 2, step do
		if glass then
			box("FloorBand", x0 - 0.2, y - 0.3, z0 - 0.2, x1 + 0.2, y + 0.3, z1 + 0.2, Color3.fromRGB(70, 80, 90), { parent = m })
		else
			box("WindowBand", x0 - 0.2, y - 3.6, z0 - 0.2, x1 + 0.2, y - 1, z1 + 0.2, Color3.fromRGB(45, 55, 65), { parent = m, material = Enum.Material.Glass })
		end
	end
	box("Roof", x0 - 0.5, h, z0 - 0.5, x1 + 0.5, h + 1.5, z1 + 0.5, Color3.fromRGB(90, 90, 95), { parent = m })
	if face then
		local a, b
		if face == "W" then a, b = Vector3.new(x0 - 0.4, 0, z0 + 2), Vector3.new(x0, 0, z1 - 2)
		elseif face == "E" then a, b = Vector3.new(x1, 0, z0 + 2), Vector3.new(x1 + 0.4, 0, z1 - 2)
		elseif face == "N" then a, b = Vector3.new(x0 + 2, 0, z0 - 0.4), Vector3.new(x1 - 2, 0, z0)
		else a, b = Vector3.new(x0 + 2, 0, z1), Vector3.new(x1 - 2, 0, z1 + 0.4) end
		box("ShopGlass", a.X, 0, a.Z, b.X, 10, b.Z, Color3.fromRGB(35, 45, 55), { parent = m, material = Enum.Material.Glass })
		local out = if face == "W" then Vector3.new(-0.6, 0, 0) elseif face == "E" then Vector3.new(0.6, 0, 0) elseif face == "N" then Vector3.new(0, 0, -0.6) else Vector3.new(0, 0, 0.6)
		local board = box("ShopBoard", a.X + out.X, 10.4, a.Z + out.Z, b.X + out.X, 13.4, b.Z + out.Z, Color3.fromRGB(25, 25, 30), { parent = m })
		surfaceText(board, FACE[face], shop, SIGNS[(#shop % #SIGNS) + 1])
		if screen then -- big LED billboard (강남 towers)
			local s = box("LEDScreen", a.X + out.X * 1.5, h * 0.45, a.Z + out.Z * 1.5, b.X + out.X * 1.5, h * 0.45 + 20, b.Z + out.Z * 1.5, Color3.fromRGB(20, 20, 30), { parent = m })
			surfaceText(s, FACE[face], screen, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack, Color3.fromRGB(40, 90, 200))
		end
	end
	m.Parent = T
end
tower(193, -470, 243, -380, 150, "glass", "W", "OHU 타워", "OHU FASHION WEEK")
tower(193, -370, 243, -262, 96, "concrete", "W", "PC방")
tower(193, -252, 243, -170, 128, "glass", "W", "HOMME", "NEW SEASON")
tower(193, -160, 243, -48, 70, "concrete", "W", "뷰티 & 샵")
tower(250, -142, 310, -48, 110, "glass", "S", "OHU 마트", "인생네컷 SALE")
tower(-76, 110, -48, 170, 120, "glass", "E", "카페")
tower(-76, 180, -48, 250, 80, "concrete", "E", "약국")
-- (6 narrower than before: a 6-stud gap to the OH24 store, user 2026-10-23)
tower(-146, 48, -132, 92, 60, "concrete", "N", "노래방")

do -- alley between two towers: dumpsters, bags, fire barrel, purple neon shutter
	local A = Instance.new("Model")
	A.Name = "Alley"
	A.Parent = T
	box("AlleyFloor", 193, 0, -380, 243, 0.1, -370, Color3.fromRGB(60, 58, 60), { parent = A, material = Enum.Material.Asphalt })
	for _, dx in ipairs({ 198, 206 }) do
		box("Dumpster", dx, 0, -379, dx + 6, 3.4, -375, Color3.fromRGB(40, 90, 55), { parent = A })
		box("DumpsterLid", dx - 0.1, 3.4, -379.2, dx + 6.1, 3.7, -374.8, Color3.fromRGB(30, 70, 45), { parent = A })
	end
	for k = 0, 4 do part("TrashBag", Vector3.new(1.8, 1.5, 1.8), CFrame.new(214 + k * 1.6, 0.75, -376 + (k % 2)), Color3.fromRGB(25, 25, 28), { parent = A, shape = Enum.PartType.Ball }) end
	vcyl("FireBarrel", Vector3.new(232, 0.1, -376), 2.4, 3.2, Color3.fromRGB(90, 60, 40), { parent = A })
	local fire = part("FireGlow", Vector3.new(1.6, 1.6, 1.6), CFrame.new(232, 3.9, -376), Color3.fromRGB(255, 140, 40), { parent = A, material = Enum.Material.Neon, shape = Enum.PartType.Ball, nocol = true })
	local fl = Instance.new("PointLight") fl.Color = Color3.fromRGB(255, 150, 60) fl.Range = 16 fl.Brightness = 1.5 fl.Parent = fire
	local sh = box("NeonShutter", 210, 0.1, -370.6, 228, 9, -370.1, Color3.fromRGB(150, 60, 230), { parent = A, material = Enum.Material.Neon, transparency = 0.15, nocol = true })
	local pl = Instance.new("PointLight") pl.Color = Color3.fromRGB(170, 80, 255) pl.Range = 18 pl.Brightness = 1.2 pl.Parent = sh
end

do -- construction site (future prop shop)
	-- the empty lot east of the 오후네컷 building, along the east road (user
	-- 2026-10-23), with an alley to the photo booth building
	local x0, z0, x1, z1, title = 116, -96, 156, -58, "소품샵 예정"
	local m = Instance.new("Model")
	m.Name = "ConstructionSite(" .. title .. ")"
	m.Parent = T
	box("Dirt", x0, 0, z0, x1, 0.2, z1, Color3.fromRGB(150, 120, 90), { parent = m, material = Enum.Material.Ground })
	local walls = {
		box("Hoarding", x0, 0, z0, x1, 9, z0 + 0.4, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x0, 0, z1 - 0.4, x1, 9, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x0, 0, z0, x0 + 0.4, 9, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
		box("Hoarding", x1 - 0.4, 0, z0, x1, 9, z1, Color3.fromRGB(245, 245, 245), { parent = m }),
	}
	for _, w in ipairs(walls) do
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			if (face == Enum.NormalId.Front or face == Enum.NormalId.Back) == (w.Size.X > w.Size.Z) then
				local g = Instance.new("SurfaceGui")
				g.Face = face
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 20
				g.Parent = w
				for k = 0, 5 do
					local line = Instance.new("Frame")
					line.BackgroundColor3 = Color3.fromRGB(70, 90, 190)
					line.BorderSizePixel = 0
					line.AnchorPoint = Vector2.new(0.5, 0.5)
					line.Position = UDim2.fromScale(0.12 + k * 0.16, 0.45 + ((k % 2) - 0.5) * 0.25)
					line.Size = UDim2.new(0.14, 0, 0, 6)
					line.Rotation = (k % 2) * 30 - 15
					line.Parent = g
				end
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 0.22)
				t.Position = UDim2.fromScale(0, 0.72)
				t.Font = Enum.Font.GothamBold
				t.TextScaled = true
				t.TextColor3 = Color3.fromRGB(70, 90, 190)
				t.Text = title .. " · 공사 중"
				t.Parent = g
			end
		end
	end
	label(walls[1], title .. " (공사 중)", Color3.fromRGB(70, 90, 190), 8, 0.7)
	local cx, cz = x1 - 4, z1 - 4
	box("CraneMast", cx - 1, 0, cz - 1, cx + 1, 46, cz + 1, Color3.fromRGB(240, 180, 30), { parent = m })
	part("CraneJib", Vector3.new(1.4, 1.4, 34), CFrame.new(cx, 46.7, cz) * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, -11), Color3.fromRGB(240, 180, 30), { parent = m, nocol = true })
	box("CraneCab", cx - 1.5, 43, cz - 1.5, cx + 1.5, 46, cz + 1.5, Color3.fromRGB(60, 60, 60), { parent = m })
	for x = x0 + 3, x1 - 3, 6 do part("Cone", Vector3.new(1.2, 2, 1.2), CFrame.new(x, 1, z0 - 2), Color3.fromRGB(255, 110, 30), { parent = m, nocol = true }) end
end

do -- OH24 convenience store (user references 2026-10-23, docs/02_WORLDS/OH24_STORE.md)
	-- Front = north (z 48, toward the west road). Outside like the GS25
	-- photos: black stone facade, white "OH" + cyan "24" logo with cyan light
	-- bars, dark awning, full glass front with a window bar inside, diamond
	-- plate step. Inside like the store photos: white-beige tiles, white
	-- ceiling with LED strips, a teal stripe band, glass-door drink fridges on
	-- the back wall, wall shelves, three double-sided gondolas with end caps,
	-- the counter by the door (candy racks on the front, goods wall behind),
	-- an open chilled case for 간편식, a hot drink warmer, an ice cream chest,
	-- an umbrella stand. Goods come from Shared/OH24Products (each has an
	-- image slot for its own artwork; placeholders until then). No tobacco /
	-- alcohol (the counter wall shows gift cards and daily goods instead).
	-- grown into the empty land around it (user 2026-10-23): x -126..-52, z 48..86
	-- (the 노래방 tower stands west of it); glass fronts with the OH24 sign on
	-- the north and east street sides, a solid wall on the tower side
	local x0, z0, x1, z1, H = -126, 48, -52, 86, 14
	local S = Instance.new("Model")
	S.Name = "OH24Store"
	S.Parent = T
	local TEAL, TEAL2 = Color3.fromRGB(0, 160, 160), Color3.fromRGB(110, 205, 200)
	local CYAN = Color3.fromRGB(30, 200, 240)
	local WHITE_IN = Color3.fromRGB(246, 246, 244)
	local SHELF = Color3.fromRGB(236, 236, 238)
	local o = { parent = S }
	local function opt(t2) local r = { parent = S } for k, v in pairs(t2) do r[k] = v end return r end
	local function gui(p: BasePart, face, ppStud, maxDist)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = ppStud or 40
		g.LightInfluence = 0.5
		pcall(function() (g :: any).MaxDistance = maxDist or 60 end)
		g.Parent = p
		return g
	end
	local function text(parent: Instance, s, color, font, bg)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = if bg then 0 else 1
		if bg then l.BackgroundColor3 = bg end
		l.BorderSizePixel = 0
		l.TextScaled = true
		l.RichText = true
		l.Font = font or Enum.Font.GothamBold
		l.TextColor3 = color
		l.Text = s
		l.Parent = parent
		return l
	end

	-- goods catalogue (read from the module source, so a fresh edit is used)
	local catalog = { CATEGORIES = {}, SHAPES = {} } :: any
	do
		local mod = game:GetService("ReplicatedStorage"):FindFirstChild("FashionGame")
		mod = mod and mod:FindFirstChild("Shared")
		mod = mod and mod:FindFirstChild("OH24Products")
		if mod and mod:IsA("ModuleScript") then
			local fn = loadstring(mod.Source)
			local ok, res = pcall(fn :: any)
			if ok and typeof(res) == "table" then catalog = res end
		end
	end
	local counters: {[string]: number} = {}
	local function nextProduct(cat: string)
		local list = catalog.CATEGORIES[cat]
		if not list or #list == 0 then return nil end
		counters[cat] = (counters[cat] or 0) % #list + 1
		return list[counters[cat]]
	end
	local function shapeSize(shape: string): Vector3
		local s = catalog.SHAPES[shape]
		return if s then s.size else Vector3.new(1, 1, 0.5)
	end
	-- one pack: cf = bottom centre, -Z facing out of the shelf
	local function pack(pr, cf: CFrame, parent: Instance, scale: number?)
		local sz = shapeSize(pr.shape) * (scale or 1)
		local front: BasePart
		if pr.shape == "tube" or pr.shape == "bottle" or pr.shape == "can" or pr.shape == "milk" then
			local body = part("Pack", Vector3.new(sz.Y, sz.X, sz.X), cf * CFrame.new(0, sz.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), pr.color, { parent = parent, nocol = true, shape = Enum.PartType.Cylinder, material = if pr.shape == "bottle" then Enum.Material.Glass else Enum.Material.SmoothPlastic, transparency = if pr.shape == "bottle" and pr.id == "water" then 0.3 else 0 })
			if pr.shape == "bottle" then
				part("Cap", Vector3.new(0.18, sz.X * 0.45, sz.X * 0.45), cf * CFrame.new(0, sz.Y + 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 245, 245), { parent = parent, nocol = true, shape = Enum.PartType.Cylinder })
			end
			-- flat label in front of the round body (artwork goes here)
			local lh = if pr.shape == "bottle" then sz.Y * 0.4 else sz.Y * 0.8
			local ly = if pr.shape == "bottle" then sz.Y * 0.45 else sz.Y / 2
			front = part("PackLabel", Vector3.new(sz.X * 0.92, lh, 0.02), cf * CFrame.new(0, ly, -sz.Z / 2 - 0.01), if pr.shape == "bottle" then Color3.new(1, 1, 1) else pr.color, { parent = parent, nocol = true })
		elseif pr.shape == "tri" then
			local w = part("Pack", Vector3.new(sz.Z, sz.Y, sz.X * 0.6), cf * CFrame.new(-sz.X * 0.25, sz.Y / 2, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(235, 235, 230), { parent = parent, nocol = true, class = "WedgePart" })
			local w2 = part("Pack", Vector3.new(sz.Z, sz.Y, sz.X * 0.6), cf * CFrame.new(sz.X * 0.25, sz.Y / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(235, 235, 230), { parent = parent, nocol = true, class = "WedgePart" })
			local _ = w and w2
			front = part("PackLabel", Vector3.new(sz.X * 0.45, sz.Y * 0.35, 0.02), cf * CFrame.new(0, sz.Y * 0.3, -sz.Z / 2 - 0.02), Color3.fromRGB(230, 40, 40), { parent = parent, nocol = true })
		else
			front = part("Pack", sz, cf * CFrame.new(0, sz.Y / 2, 0), pr.color, { parent = parent, nocol = true })
		end
		front:SetAttribute("ProductId", pr.id)
		if pr.image ~= "" then
			local d = Instance.new("Decal")
			d.Texture = pr.image
			d.Face = Enum.NormalId.Front
			d.Parent = front
		elseif pr.shape ~= "bottle" and pr.shape ~= "can" then
			local g = gui(front, Enum.NormalId.Front, 60, 34)
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = pr.color
			bg.BorderSizePixel = 0
			bg.Parent = g
			local band = Instance.new("Frame")
			band.Size = UDim2.fromScale(1, 0.16)
			band.BackgroundColor3 = Color3.new(1, 1, 1)
			band.BackgroundTransparency = 0.15
			band.BorderSizePixel = 0
			band.Parent = bg
			local l = text(bg, pr.name, if pr.color.R + pr.color.G + pr.color.B > 2.2 then Color3.fromRGB(40, 40, 50) else Color3.new(1, 1, 1), Enum.Font.GothamBlack)
			l.Size = UDim2.fromScale(0.92, 0.66)
			l.Position = UDim2.fromScale(0.04, 0.22)
			l.TextStrokeTransparency = 0.7
		end
		return front
	end
	-- One shelf row = ONE part with one picture (user 2026-10-23: merge a row
	-- into a single image like a shelf photo, far fewer parts). cf = left end
	-- of the shelf front edge on the shelf top, -Z out; len studs long; maxH =
	-- clear height above the shelf. The picture is the category's row image
	-- (OH24Products.ROW_IMAGES[cat], a Decal) once it is designed; until then a
	-- placeholder drawn in one SurfaceGui: product tiles + the price strip.
	local function row(cf: CFrame, len: number, cat: string, parent: Instance, tags: boolean?, maxH: number?)
		local h = math.min(maxH or 1.6, 1.9)
		local face = part("ShelfRow", Vector3.new(len, h + 0.3, 0.6), cf * CFrame.new(len / 2, h / 2 - 0.15, 0.4), Color3.fromRGB(240, 240, 242), { parent = parent, nocol = true })
		face.CastShadow = false
		local img = catalog.ROW_IMAGES and catalog.ROW_IMAGES[cat]
		if typeof(img) == "string" and img ~= "" then
			local d = Instance.new("Decal")
			d.Texture = img
			d.Face = Enum.NormalId.Front
			d.Parent = face
			return
		end
		local g = gui(face, Enum.NormalId.Front, 30, 90) -- one gui per row now, so it can draw from farther
		local stripH = if tags == false then 0 else 0.3 / (h + 0.3)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1 - stripH)
		holder.Parent = g
		local lay = Instance.new("UIListLayout")
		lay.FillDirection = Enum.FillDirection.Horizontal
		lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
		lay.Padding = UDim.new(0.035, 0)
		lay.Parent = holder
		local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0.02, 0) pad.Parent = holder
		-- product tiles with gaps, scaled to the row height
		local x = 0.1
		while true do
			local pr = nextProduct(cat)
			if not pr then break end
			local base = shapeSize(pr.shape)
			local scale = math.min(1, (h - 0.12) / base.Y)
			local w, ph = base.X * scale, base.Y * scale
			if x + w > len then break end
			local tile = Instance.new("Frame")
			tile.Size = UDim2.fromScale(w / len, ph / h)
			tile.BackgroundColor3 = pr.color
			tile.BorderSizePixel = 0
			tile.Parent = holder
			if pr.shape == "bottle" or pr.shape == "can" or pr.shape == "milk" or pr.shape == "tube" then
				local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0.25, 0) c.Parent = tile
			end
			local band = Instance.new("Frame")
			band.Size = UDim2.fromScale(1, 0.16)
			band.BackgroundColor3 = Color3.new(1, 1, 1)
			band.BackgroundTransparency = 0.2
			band.BorderSizePixel = 0
			band.Parent = tile
			local l = text(tile, pr.name, if pr.color.R + pr.color.G + pr.color.B > 2.2 then Color3.fromRGB(40, 40, 50) else Color3.new(1, 1, 1), Enum.Font.GothamBlack)
			l.Size = UDim2.fromScale(0.9, 0.62)
			l.Position = UDim2.fromScale(0.05, 0.24)
			x += w + math.max(0.45, w * 0.5)
		end
		if tags ~= false then
			local strip = Instance.new("Frame")
			strip.Position = UDim2.fromScale(0, 1 - stripH)
			strip.Size = UDim2.fromScale(1, stripH)
			strip.BackgroundColor3 = Color3.fromRGB(215, 215, 220)
			strip.BorderSizePixel = 0
			strip.Parent = g
			local sl = Instance.new("UIListLayout")
			sl.FillDirection = Enum.FillDirection.Horizontal
			sl.Padding = UDim.new(0, 18)
			sl.Parent = strip
			for k = 1, math.max(1, math.floor(len / 1.4)) do
				local tag = text(strip, (({ "1,500", "1,800", "2,200", "1,200", "2,500", "1+1", "2+1" })[(k % 7) + 1]), Color3.fromRGB(30, 30, 30), Enum.Font.GothamBold, if k % 5 == 0 then Color3.fromRGB(250, 220, 60) else Color3.new(1, 1, 1))
				tag.Size = UDim2.new(0, 36, 1, 0)
			end
		end
	end
	---------------------------------------------------------------- shell
	-- (user 2026-10-23: bigger, with the empty land around it; every street
	-- side is a glass front with the same OH24 sign)
	walk(x0, WIDE, x1, z0)
	box("StoreFloor", x0, 0, z0, x1, CURB, z1, Color3.fromRGB(232, 228, 220), opt({ material = Enum.Material.CeramicTiles })).Reflectance = 0.04
	local STONE = Color3.fromRGB(38, 38, 42)
	box("WallBack", x0, CURB, z1 - 0.6, x1, H, z1, WHITE_IN, o)
	box("WallW", x0, CURB, z0, x0 + 0.6, H, z1, WHITE_IN, o)
	box("OuterBack", x0 - 0.3, 0, z1, x1 + 0.3, H + 6, z1 + 0.3, STONE, opt({ material = Enum.Material.Slate }))
	box("Roof", x0 - 0.3, H, z0, x1 + 0.3, H + 0.6, z1, Color3.fromRGB(90, 90, 95), o)
	-- ceiling: white panels, grid lines, LED strips
	box("Ceiling", x0, H - 0.3, z0, x1, H, z1, Color3.fromRGB(244, 244, 242), o)
	for x = x0 + 4, x1 - 4, 4 do box("CeilingGrid", x - 0.05, H - 0.34, z0, x + 0.05, H - 0.3, z1, Color3.fromRGB(205, 205, 205), opt({ nocol = true })) end
	for z = z0 + 4, z1 - 4, 4 do box("CeilingGrid", x0, H - 0.34, z - 0.05, x1, H - 0.3, z + 0.05, Color3.fromRGB(205, 205, 205), opt({ nocol = true })) end
	for x = x0 + 8, x1 - 6, 12 do
		local led = box("LEDStrip", x - 0.35, H - 0.45, z0 + 3, x + 0.35, H - 0.34, z1 - 3, Color3.fromRGB(255, 255, 252), opt({ nocol = true }))
		local l = Instance.new("SurfaceLight")
		l.Face = Enum.NormalId.Bottom
		l.Range, l.Brightness, l.Angle = 16, 0.9, 120
		l.Parent = led
	end
	-- teal stripe band on the back wall with the slogan
	box("StripeTeal", x0, 11.6, z1 - 0.65, x1, 12.4, z1 - 0.6, TEAL, opt({ nocol = true }))
	box("StripeLight", x0, 11.1, z1 - 0.65, x1, 11.5, z1 - 0.6, TEAL2, opt({ nocol = true }))
	do
		local slogan = box("Slogan", -110, 11.65, z1 - 0.7, -88, 12.35, z1 - 0.66, TEAL, opt({ nocol = true }))
		text(gui(slogan, Enum.NormalId.Front, 30, 120), "OH24  Fresh &amp; Friendly", Color3.new(1, 1, 1), Enum.Font.GothamMedium)
	end

	---------------------------------------------------------------- glass fronts (GS25-like), one per street side
	-- p0 → p1 along the outside face (p0 = viewer's right), out = outward normal
	local function storeFront(p0: Vector3, p1: Vector3, out: Vector3, doorU: number?, branch: string)
		local along = out:Cross(Vector3.yAxis)
		local L = (p1 - p0).Magnitude
		local function fp(name, u0, u1, y0, y1, d0, d1, color, op)
			local c = p0 + along * ((u0 + u1) / 2) + out * ((d0 + d1) / 2) + Vector3.new(0, (y0 + y1) / 2, 0)
			return part(name, Vector3.new(math.abs(u1 - u0), y1 - y0, math.abs(d1 - d0)), CFrame.fromMatrix(c, along, Vector3.yAxis), color, op)
		end
		fp("FacadePier", -0.3, 1.6, 0, H + 6, 0, 0.4, STONE, opt({ material = Enum.Material.Slate }))
		fp("FacadePier", L - 1.6, L + 0.3, 0, H + 6, 0, 0.4, STONE, opt({ material = Enum.Material.Slate }))
		fp("Fascia", -0.3, L + 0.3, 13, H + 6, 0, 0.6, Color3.fromRGB(26, 26, 30), opt({ material = Enum.Material.Slate }))
		-- logo plaque in the middle, light bars either side
		local logo = fp("Logo", L / 2 - 7, L / 2 + 7, 14.6, 18.8, 0.6, 0.75, Color3.fromRGB(26, 26, 30), opt({ nocol = true }))
		local g = gui(logo, Enum.NormalId.Front, 30, 400)
		g.LightInfluence = 0
		g.Brightness = 1.4
		text(g, '<font color="#FFFFFF">OH</font><font color="#1EC8F0">24</font>', Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		local barW = math.min(14, L / 2 - 9)
		for _, b in ipairs({ { L - 1.6 - barW, L - 1.6, "Lifestyle Platform", true }, { 1.6, 1.6 + barW, branch, false } }) do
			local bar = fp("LightBar", b[1], b[2], 16, 17.6, 0.6, 0.8, CYAN, opt({ nocol = true }))
			local bg = gui(bar, Enum.NormalId.Front, 30, 200)
			bg.LightInfluence = 0
			local bgf = Instance.new("Frame") bgf.Size = UDim2.fromScale(1, 1) bgf.BackgroundColor3 = CYAN bgf.BorderSizePixel = 0 bgf.Parent = bg
			local l = text(bg, b[3], Color3.fromRGB(10, 40, 60), Enum.Font.GothamMedium)
			l.TextXAlignment = if b[4] then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
			l.Size = UDim2.fromScale(0.94, 0.7)
			l.Position = UDim2.fromScale(0.03, 0.15)
			fp("LightBarBase", b[1], b[2], 15.4, 15.8, 0.6, 0.8, Color3.fromRGB(245, 245, 245), opt({ nocol = true }))
		end
		-- awning sloping out, small text on its edge
		local a = p0 + along * (L / 2) + out * 0.6 + Vector3.new(0, 13.4, 0)
		local bpt = p0 + along * (L / 2) + out * 3.4 + Vector3.new(0, 12.4, 0)
		local slope = (bpt - a).Unit
		local nrm = along:Cross(slope)
		if nrm.Y < 0 then nrm = -nrm end
		part("Awning", Vector3.new(L - 2, 0.2, (bpt - a).Magnitude), CFrame.fromMatrix((a + bpt) / 2, along, nrm), Color3.fromRGB(58, 40, 36), opt({ material = Enum.Material.Fabric, nocol = true }))
		local valance = fp("AwningEdge", 1, L - 1, 11.8, 12.5, 3.3, 3.5, Color3.fromRGB(58, 40, 36), opt({ material = Enum.Material.Fabric, nocol = true }))
		local vl = text(gui(valance, Enum.NormalId.Front, 30, 120), "Lifestyle Platform   OH24", Color3.fromRGB(230, 230, 230), Enum.Font.GothamMedium)
		vl.TextXAlignment = Enum.TextXAlignment.Left
		vl.Size = UDim2.fromScale(0.97, 0.6)
		vl.Position = UDim2.fromScale(0.02, 0.2)
		-- glass with slim mullions (a gap for the door)
		local DOOR = 8
		local runs = if doorU then { { 1.6, doorU - DOOR / 2 - 0.4 }, { doorU + DOOR / 2 + 0.4, L - 1.6 } } else { { 1.6, L - 1.6 } }
		for _, r in ipairs(runs) do
			fp("FrontGlass", r[1], r[2], CURB + 0.6, 12.8, 0, 0.2, Color3.fromRGB(215, 230, 235), opt({ material = Enum.Material.Glass, transparency = 0.6 }))
			fp("Kickplate", r[1], r[2], CURB, CURB + 0.6, 0, 0.25, Color3.fromRGB(150, 150, 155), opt({ material = Enum.Material.Metal }))
			local n = math.max(1, math.floor((r[2] - r[1]) / 7))
			for k = 0, n do
				local u = r[1] + (r[2] - r[1]) * k / n
				fp("Mullion", u - 0.12, u + 0.12, CURB, 12.8, 0, 0.3, Color3.fromRGB(70, 70, 75), opt({ material = Enum.Material.Metal }))
			end
			local mu = (r[1] + r[2]) / 2
			local mark = fp("GlassMark", mu - 1.2, mu + 1.2, 10.4, 11, 0.21, 0.22, Color3.new(1, 1, 1), opt({ nocol = true, transparency = 1 }))
			text(gui(mark, Enum.NormalId.Front, 40, 80), '<font color="#FFFFFF">OH</font><font color="#1EC8F0">24</font>', Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		end
		fp("GlassHead", 1.6, L - 1.6, 12.8, 13, 0, 0.3, Color3.fromRGB(70, 70, 75), opt({ material = Enum.Material.Metal }))
		if doorU then
			fp("DoorHead", doorU - DOOR / 2 - 0.4, doorU + DOOR / 2 + 0.4, 11.4, 12.8, 0, 0.3, Color3.fromRGB(70, 70, 75), opt({ material = Enum.Material.Metal }))
			local door = Instance.new("Model")
			door.Name = "AutoDoor"
			door:SetAttribute("Range", 9)
			for _, s2 in ipairs({ -1, 1 }) do
				local panel = fp("DoorPanel", doorU, doorU + s2 * DOOR / 2, CURB, 11.4, 0.05, 0.2, Color3.fromRGB(215, 230, 235), { parent = door, material = Enum.Material.Glass, transparency = 0.55 })
				panel:SetAttribute("Slide", along * (s2 * (DOOR / 2 - 0.2)))
				local handle = fp("DoorHandle", doorU + s2 * 0.5 - 0.06, doorU + s2 * 0.5 + 0.06, 4, 7.5, 0.25, 0.35, Color3.fromRGB(200, 200, 205), { parent = door, material = Enum.Material.Metal, nocol = true })
				handle:SetAttribute("Slide", along * (s2 * (DOOR / 2 - 0.2)))
			end
			local dc = p0 + along * doorU
			door.WorldPivot = CFrame.new(dc.X, CURB + 4, dc.Z)
			door:SetAttribute("Panels", 4)
			door.Parent = S
			CS:AddTag(door, "AutoDoor")
		end
		-- diamond-plate step along the face
		fp("FrontStep", 0, L, CURB, CURB + 0.2, 0, 1.6, Color3.fromRGB(175, 178, 182), opt({ material = Enum.Material.DiamondPlate }))
	end
	local DOOR_X = -78
	storeFront(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), Vector3.new(0, 0, -1), DOOR_X - x0, "홍대점") -- north (west road)
	storeFront(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), Vector3.new(1, 0, 0), nil, "남부대로점") -- east (south road)

	---------------------------------------------------------------- window bars inside the glass
	local function windowBar(a: Vector3, b: Vector3, inward: Vector3)
		local d = (b - a)
		local len = d.Magnitude
		local dir = d.Unit
		local c = (a + b) / 2 + inward * 0.9
		part("WindowBar", Vector3.new(len, 0.2, 1.6), CFrame.fromMatrix(Vector3.new(c.X, CURB + 3.5, c.Z), dir, Vector3.yAxis), Color3.fromRGB(245, 245, 245), o)
		for s = 1, len - 1, 4 do
			local p = a + dir * s + inward * 1.5
			box("BarLeg", p.X - 0.1, CURB, p.Z - 0.1, p.X + 0.1, CURB + 3.4, p.Z + 0.1, Color3.fromRGB(190, 190, 195), opt({ material = Enum.Material.Metal }))
		end
		for s = 2, len - 1.5, 3.4 do
			local p = a + dir * s + inward * 3.2
			vcyl("StoolLeg", Vector3.new(p.X, CURB, p.Z), 0.3, 2.3, Color3.fromRGB(200, 200, 205), opt({ material = Enum.Material.Metal }))
			seat("WindowStool", CFrame.lookAt(Vector3.new(p.X, CURB + 2.45, p.Z), Vector3.new(p.X, CURB + 2.45, p.Z) - inward), Vector3.new(1.4, 0.3, 1.4), Color3.fromRGB(235, 235, 235), S)
		end
	end
	windowBar(Vector3.new(-110, 0, z0 + 0.3), Vector3.new(-86, 0, z0 + 0.3), Vector3.new(0, 0, 1)) -- north, between the counter and the door
	windowBar(Vector3.new(x1 - 0.3, 0, 70), Vector3.new(x1 - 0.3, 0, z1 - 3), Vector3.new(-1, 0, 0)) -- east, south part

	---------------------------------------------------------------- back wall: glass-door drink fridges (west part)
	do
		local fx0, fx1, fz = x0 + 0.6, -100, z1 - 0.6
		local depth, top = 2.6, CURB + 9
		local DARK = Color3.fromRGB(60, 62, 66)
		box("FridgeBackPanel", fx0, CURB, fz - 0.4, fx1, top, fz, DARK, opt({ material = Enum.Material.Metal }))
		box("FridgeBase", fx0, CURB, fz - depth, fx1, CURB + 0.5, fz, DARK, opt({ material = Enum.Material.Metal }))
		box("FridgeTop", fx0, top - 0.4, fz - depth, fx1, top, fz, DARK, opt({ material = Enum.Material.Metal }))
		box("FridgeEnd", fx1 - 0.2, CURB, fz - depth, fx1, top, fz, DARK, opt({ material = Enum.Material.Metal }))
		box("FridgeEnd", fx0, CURB, fz - depth, fx0 + 0.2, top, fz, DARK, opt({ material = Enum.Material.Metal }))
		local head = box("FridgeHeader", fx0, top, fz - depth - 0.1, fx1, top + 1, fz, Color3.fromRGB(250, 250, 250), o)
		local hg = gui(head, Enum.NormalId.Front, 30, 120)
		hg.LightInfluence = 0
		text(hg, "음료 · 생수 · 우유", Color3.fromRGB(0, 120, 120), Enum.Font.GothamBold)
		local inner = box("FridgeInner", fx0 + 0.3, CURB + 0.5, fz - 0.45, fx1 - 0.3, top - 0.4, fz - 0.4, Color3.fromRGB(235, 238, 242), opt({ nocol = true }))
		local il = Instance.new("SurfaceLight") il.Face = Enum.NormalId.Front il.Range = 4 il.Brightness = 0.6 il.Parent = inner
		local doors = 6
		local doorW = (fx1 - fx0) / doors
		for k = 0, doors - 1 do
			local dx0 = fx0 + k * doorW
			box("FridgeFrame", dx0, CURB, fz - depth - 0.15, dx0 + 0.2, top, fz - depth, Color3.fromRGB(45, 45, 50), opt({ material = Enum.Material.Metal }))
			box("FridgeDoor", dx0 + 0.2, CURB + 0.5, fz - depth - 0.12, dx0 + doorW, top - 0.3, fz - depth - 0.05, Color3.fromRGB(225, 235, 240), opt({ material = Enum.Material.Glass, transparency = 0.75 }))
			box("FridgeHandle", dx0 + doorW - 0.5, CURB + 3, fz - depth - 0.35, dx0 + doorW - 0.35, CURB + 6.5, fz - depth - 0.15, Color3.fromRGB(190, 190, 195), opt({ material = Enum.Material.Metal, nocol = true }))
			local cat = ({ "drink_bottle", "drink_bottle", "drink_can", "drink_can", "milk", "drink_bottle" })[k + 1]
			for lv = 0, 4 do
				local y = CURB + 0.8 + lv * 1.65
				box("FridgeShelf", dx0 + 0.25, y - 0.08, fz - depth + 0.1, dx0 + doorW - 0.05, y, fz - 0.5, Color3.fromRGB(205, 210, 215), opt({ nocol = true }))
				row(CFrame.lookAt(Vector3.new(dx0 + 0.3, y, fz - depth + 0.25), Vector3.new(dx0 + 0.3, y, fz - depth - 1)), doorW - 0.4, cat, S, false, 1.55)
			end
		end
	end

	---------------------------------------------------------------- back wall (east part): open chilled case + hot drink warmer
	do
		local wz = z1 - 0.6
		local cx0, cx1 = -97, -72
		box("ChilledBack", cx0, CURB, wz - 0.2, cx1, CURB + 8.4, wz, Color3.fromRGB(235, 240, 245), o)
		box("ChilledBase", cx0, CURB, wz - 2.6, cx1, CURB + 1.4, wz, Color3.fromRGB(70, 75, 85), opt({ material = Enum.Material.Metal }))
		local canopy = box("ChilledCanopy", cx0, CURB + 8.4, wz - 2.8, cx1, CURB + 9.4, wz, Color3.new(1, 1, 1), o)
		text(gui(canopy, Enum.NormalId.Front, 30, 120), "간편식품 · 냉장식품 · 유제품", TEAL, Enum.Font.GothamBold)
		local cats = { "lunch", "fresh", "fresh", "milk" }
		for lv = 0, 3 do
			local y = CURB + 1.4 + lv * 1.7
			local d = 2.4 - lv * 0.3
			box("ChilledShelf", cx0, y - 0.08, wz - d, cx1, y, wz - 0.2, Color3.fromRGB(230, 232, 236), opt({ nocol = true }))
			row(CFrame.lookAt(Vector3.new(cx0, y, wz - d), Vector3.new(cx0, y, wz - d - 10)), cx1 - cx0, cats[lv + 1], S, nil, 1.6)
		end
		local cl = box("ChilledLight", cx0, CURB + 8.3, wz - 2.7, cx1, CURB + 8.4, wz - 0.2, Color3.new(1, 1, 1), opt({ nocol = true }))
		local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 9 sl.Brightness = 0.8 sl.Parent = cl
		-- warmer next to it
		box("Warmer", -70, CURB, wz - 2.6, -64, CURB + 6.2, wz, Color3.fromRGB(240, 240, 240), o)
		for k = 0, 1 do
			local xx = -69.8 + k * 2.9
			box("WarmerDoor", xx, CURB + 1.6, wz - 2.7, xx + 2.7, CURB + 5.8, wz - 2.6, Color3.fromRGB(230, 180, 160), opt({ material = Enum.Material.Glass, transparency = 0.5 }))
			local sign = box("WarmerSign", xx + 0.1, CURB + 0.6, wz - 2.72, xx + 2.6, CURB + 1.4, wz - 2.62, Color3.fromRGB(200, 40, 50), opt({ nocol = true }))
			text(gui(sign, Enum.NormalId.Front, 40, 40), "따뜻한 음료", Color3.new(1, 1, 1), Enum.Font.GothamBold)
		end
		local poster = box("PromoPoster", -62, 5, wz - 0.04, -57.6, 9, wz, Color3.fromRGB(250, 220, 60), opt({ nocol = true }))
		text(gui(poster, Enum.NormalId.Front, 40, 60), "이달의 행사\n1+1 · 2+1", Color3.fromRGB(200, 40, 40), Enum.Font.GothamBlack)
	end

	---------------------------------------------------------------- shelving
	local function shelfUnit(name, cf: CFrame, len, levels, height, depth, cats, header)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = S
		part("ShelfBack", Vector3.new(len, height, 0.15), cf * CFrame.new(len / 2, height / 2, depth), SHELF, { parent = m })
		for _, e in ipairs({ 0, len }) do part("ShelfSide", Vector3.new(0.12, height, depth), cf * CFrame.new(e, height / 2, depth / 2), SHELF, { parent = m }) end
		part("ShelfBase", Vector3.new(len, 0.6, depth), cf * CFrame.new(len / 2, 0.3, depth / 2), Color3.fromRGB(200, 200, 205), { parent = m })
		local gap = (height - 1.2) / levels
		for lv = 0, levels - 1 do
			local y = 0.6 + lv * gap
			part("ShelfBoard", Vector3.new(len, 0.1, depth), cf * CFrame.new(len / 2, y, depth / 2), SHELF, { parent = m })
			local cat = cats[(lv % #cats) + 1]
			row(cf * CFrame.new(0, y + 0.05, 0), len, cat, m, nil, gap - 0.1)
		end
		if header then
			local h = part("ShelfHeader", Vector3.new(len, 0.8, 0.12), cf * CFrame.new(len / 2, height + 0.4, depth - 0.1), Color3.new(1, 1, 1), { parent = m })
			text(gui(h, Enum.NormalId.Front, 30, 70), header, TEAL, Enum.Font.GothamBold)
		end
		return m
	end
	-- wall shelf on the west wall, south of the counter (faces east)
	shelfUnit("WallShelf", CFrame.lookAt(Vector3.new(x0 + 2.2, CURB, 67), Vector3.new(x0 + 10, CURB, 67)), 14, 5, 7, 1.6, { "noodle", "snack_bag", "snack_bag", "sweets_box", "bread" }, "라면 · 과자 · 베이커리")
	-- four double-sided gondolas along z (60..76), wide aisles, end caps at the front
	local GCATS = {
		{ { "snack_bag", "snack_bag", "snack_tube", "snack_bag" }, { "sweets_box", "snack_tube", "sweets_box", "candy" }, "스낵", "과자 · 초콜릿" },
		{ { "noodle", "noodle", "bread", "noodle" }, { "snack_bag", "sweets_box", "snack_bag", "snack_tube" }, "라면 · 즉석", "스낵" },
		{ { "sweets_box", "candy", "sweets_box", "bread" }, { "bread", "snack_bag", "bread", "sweets_box" }, "과자 · 디저트", "베이커리" },
		{ { "goods", "goods", "candy", "goods" }, { "noodle", "snack_bag", "noodle", "sweets_box" }, "생활용품", "라면 · 과자" },
	}
	for i, gx in ipairs({ -104, -92, -80, -68 }) do
		local c = GCATS[i]
		shelfUnit("Gondola" .. i .. "W", CFrame.lookAt(Vector3.new(gx - 1.4, CURB, 76), Vector3.new(gx - 10, CURB, 76)), 16, 4, 6.2, 1.4, c[1], c[3])
		shelfUnit("Gondola" .. i .. "E", CFrame.lookAt(Vector3.new(gx + 1.4, CURB, 60), Vector3.new(gx + 10, CURB, 60)), 16, 4, 6.2, 1.4, c[2], c[4])
		shelfUnit("EndCap" .. i, CFrame.lookAt(Vector3.new(gx - 1.4, CURB, 58.8), Vector3.new(gx - 1.4, CURB, 50)), 2.8, 5, 6.6, 1.2, { "snack_bag" }, nil)
	end

	---------------------------------------------------------------- counter on the west wall (user 2026-10-23); staff between it and the wall
	do
		local cx0, cx1, cz0, cz1 = -119, -115.5, 51, 64 -- cx0 = staff side (west), cx1 = customer side (east)
		local TEALTOP = Color3.fromRGB(0, 150, 150)
		box("CounterBody", cx0, CURB, cz0, cx1, CURB + 3.4, cz1, Color3.fromRGB(245, 245, 245), o)
		box("CounterTop", cx0 - 0.2, CURB + 3.4, cz0 - 0.2, cx1 + 0.3, CURB + 3.7, cz1 + 0.2, TEALTOP, o)
		-- candy racks on the customer face (looks +x)
		for lv = 0, 2 do
			local y = CURB + 0.5 + lv * 0.95
			box("CandyRack", cx1, y - 0.08, cz0 + 0.4, cx1 + 1, y, cz1 - 0.4, Color3.fromRGB(200, 200, 205), opt({ material = Enum.Material.Metal }))
			row(CFrame.lookAt(Vector3.new(cx1 + 1, y, cz0 + 0.4), Vector3.new(cx1 + 10, y, cz0 + 0.4)), cz1 - cz0 - 0.8, "candy", S, nil, 0.9)
		end
		local top = CURB + 3.7
		-- POS monitor on the staff side, its screen turned to the cashier (-x)
		box("PosBase", cx0 + 0.3, top, 55.2, cx0 + 1.5, top + 0.35, 57.2, Color3.fromRGB(235, 235, 235), o)
		local mon = CFrame.new(cx0 + 1.1, top + 1.25, 56.2) * CFrame.Angles(0, 0, math.rad(-15))
		part("PosMonitor", Vector3.new(0.18, 1.3, 1.9), mon, Color3.fromRGB(30, 30, 34), o)
		local disp = part("PosDisplay", Vector3.new(0.02, 1.12, 1.72), mon * CFrame.new(-0.1, 0, 0), Color3.fromRGB(40, 90, 160), o)
		text(gui(disp, Enum.NormalId.Left, 60, 30), "OH24 POS", Color3.new(1, 1, 1), Enum.Font.GothamBold)
		box("Scanner", cx0 + 0.4, top, 58.2, cx0 + 0.9, top + 0.9, 58.6, Color3.fromRGB(70, 70, 75), o)
		-- customer side: display facing the customer, card terminal, tray mat
		local cust = part("CustomerScreen", Vector3.new(0.1, 1.2, 1.7), CFrame.new(cx1 - 0.3, top + 1.3, 60.2) * CFrame.Angles(0, 0, math.rad(10)), Color3.fromRGB(70, 180, 230), o)
		local cg = gui(cust, Enum.NormalId.Right, 40, 40)
		cg.LightInfluence = 0
		text(cg, "OH24\n포인트 적립", Color3.new(1, 1, 1), Enum.Font.GothamBold, Color3.fromRGB(70, 180, 230))
		box("CardTerminal", cx1 - 0.85, top, 53, cx1 - 0.15, top + 0.5, 53.8, Color3.fromRGB(40, 40, 45), o)
		box("CounterMat", cx1 - 1.4, top, 55.4, cx1 + 0.1, top + 0.02, 58.4, Color3.fromRGB(120, 200, 230), opt({ nocol = true }))
		-- goods wall behind the cashier, on the west wall (faces +x)
		shelfUnit("GoodsWall", CFrame.lookAt(Vector3.new(x0 + 2.2, CURB, cz0 + 0.5), Vector3.new(x0 + 10, CURB, cz0 + 0.5)), cz1 - cz0 - 1, 5, 9, 1.6, { "goods" }, "기프트카드 · 생활용품")
		label(box("CounterLabel", cx1 - 0.2, top + 3, 57, cx1, top + 3.2, 57.2, Color3.new(1, 1, 1), opt({ transparency = 1, nocol = true })), "계산대", Color3.fromRGB(0, 160, 160), 0, 0.5)
	end
	---------------------------------------------------------------- ice cream chest, umbrella stand, mirror
	do
		local ix0, ix1, iz0, iz1 = x1 - 9, x1 - 3, 54.5, 57.8 -- by the east glass, north of the window bar
		box("FreezerBody", ix0, CURB, iz0, ix1, CURB + 2.6, iz1, Color3.fromRGB(245, 245, 248), o)
		local side = box("FreezerPanel", ix0 + 0.5, CURB + 0.6, iz0 - 0.05, ix1 - 0.5, CURB + 2, iz0, Color3.fromRGB(60, 170, 90), opt({ nocol = true }))
		text(gui(side, Enum.NormalId.Front, 40, 40), "아이스크림", Color3.new(1, 1, 1), Enum.Font.GothamBold)
		box("FreezerInside", ix0 + 0.3, CURB + 1.6, iz0 + 0.3, ix1 - 0.3, CURB + 1.7, iz1 - 0.3, Color3.fromRGB(200, 225, 240), opt({ nocol = true }))
		for xx = ix0 + 0.8, ix1 - 0.8, 1.0 do
			for zz = iz0 + 0.8, iz1 - 0.8, 0.8 do
				local pr = nextProduct("icecream")
				if pr then
					local sz = shapeSize(pr.shape)
					-- lying flat, label up: local Y runs along world +Z after the turn
					pack(pr, CFrame.new(xx, CURB + 1.7 + sz.Z / 2, zz - sz.Y / 2) * CFrame.Angles(math.rad(90), 0, 0), S)
				end
			end
		end
		box("FreezerGlass", ix0 + 0.2, CURB + 2.6, iz0 + 0.2, ix1 - 0.2, CURB + 2.7, iz1 - 0.2, Color3.fromRGB(220, 235, 245), opt({ material = Enum.Material.Glass, transparency = 0.7 }))
		local ux, uz = DOOR_X + 6, z0 + 1.8
		vcyl("UmbrellaBin", Vector3.new(ux, CURB, uz), 1.6, 1.6, Color3.fromRGB(210, 210, 215), opt({ material = Enum.Material.Metal }))
		for k = 0, 9 do
			local a = k * 0.63
			local p0 = Vector3.new(ux + math.cos(a) * 0.45, CURB + 0.2, uz + math.sin(a) * 0.45)
			local p1 = p0 + Vector3.new(math.cos(a) * 0.25, 4.2, math.sin(a) * 0.25)
			part("Umbrella", Vector3.new(0.28, 0.28, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), if k % 3 == 0 then Color3.fromRGB(220, 225, 235) else Color3.fromRGB(40, 50, 90), opt({ nocol = true, material = Enum.Material.Fabric }))
		end
		local mc = Vector3.new(x1 - 1.4, 10, z1 - 1.4)
		local mirror = part("SecurityMirror", Vector3.new(0.3, 2.2, 2.2), CFrame.lookAt(mc, Vector3.new(-100, 6, 66)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 210, 220), opt({ shape = Enum.PartType.Cylinder, material = Enum.Material.Glass, nocol = true }))
		mirror.Reflectance = 0.6
	end
	label(box("StoreLabelAnchor", -100, H + 7, z0 - 1, -98, H + 7.2, z0 - 0.8, Color3.new(1, 1, 1), opt({ transparency = 1, nocol = true })), "OH24 편의점", Color3.fromRGB(30, 200, 240), 3, 0.7)
end

do -- sunset photo frame at the end of the pier, facing the sea (west)
	local frameCol = Color3.fromRGB(255, 150, 90)
	local px, pz = -344, 122
	part("SunsetFramePostN", Vector3.new(1, 10, 1), CFrame.new(px, 6 - BEACH_DROP, pz + 5), frameCol, { material = Enum.Material.Neon })
	part("SunsetFramePostS", Vector3.new(1, 10, 1), CFrame.new(px, 6 - BEACH_DROP, pz - 5), frameCol, { material = Enum.Material.Neon })
	local top = part("SunsetFrameTop", Vector3.new(1, 1, 11), CFrame.new(px, 11.5 - BEACH_DROP, pz), frameCol, { material = Enum.Material.Neon })
	label(top, "석양 포토 스팟 (서쪽 바다)", frameCol, 4, 0.8)
end

------------------------------------------------------- play area boundary + backdrop (D-109)
-- The user drew the walkable area on the v7c map (2026-10-23, red line):
-- invisible walls along it keep players inside. Outside, only what can be
-- seen is built: a tiled stone wall (기와 돌담) around the hanok village,
-- fake shop buildings with stacked signs elsewhere, the beach going on.
do
	local B = Instance.new("Folder")
	B.Name = "MapBoundary"
	B.Parent = T
	-- polygon (x, z), clockwise from the north-west corner in the sea
	local P = {
		-- 2026-10-23 (2): the beach road is closed further south (z -300)
		{ -305, -300 }, { -151, -300 }, { -151, -479 }, { -35, -479 }, { -35, -374 }, { 59, -374 }, { 59, -265 },
		-- the hanok village keeps its own walls; this keeps players next to it
		{ 177, -265 }, { 177, 47 }, { 232, 47 }, { 232, 234 }, { 97, 234 }, { 97, 299 }, { -50, 299 }, { -50, 109 },
		{ -89, 109 }, { -89, 218 }, { -151, 218 }, { -151, 237 }, { -305, 237 },
	}
	for i = 1, #P do
		local a, b = P[i], P[(i % #P) + 1]
		local pa, pb = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
		local mid = (pa + pb) / 2 + Vector3.new(0, 55, 0)
		local w = part("BoundaryWall", Vector3.new(2, 150, (pb - pa).Magnitude + 2), CFrame.lookAt(mid, mid + (pb - pa)), Color3.new(1, 1, 1), { parent = B, transparency = 1 })
		w.CanQuery = false -- the camera does not bump into it
		w.CanTouch = false
		w.CastShadow = false
	end

	-- the hanok village's own wall (granite base, red brick, slate coping)
	-- continued to the end of the map along its north and west lines
	-- (user 2026-10-23, the light-blue lines): north toward the east, and a
	-- 돌담길 along the south road side
	local function hanokWall(a: Vector3, b: Vector3)
		local W = Instance.new("Model")
		W.Name = "HanokWallExtension"
		W.Parent = T
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, mid + (b - a))
		part("WallGranite", Vector3.new(1.4, 2.6, len), cf * CFrame.new(0, 1.8, 0), Color3.fromRGB(205, 200, 188), { parent = W, material = Enum.Material.Slate })
		part("WallBrick", Vector3.new(1.4, 1.4, len), cf * CFrame.new(0, 3.8, 0), Color3.fromRGB(165, 75, 55), { parent = W, material = Enum.Material.Brick })
		part("WallCoping", Vector3.new(2.6, 0.5, len + 0.6), cf * CFrame.new(0, 4.8, 0), Color3.fromRGB(55, 58, 64), { parent = W, material = Enum.Material.Slate })
		part("WallCopingRidge", Vector3.new(0.7, 0.5, len + 0.6), cf * CFrame.new(0, 5.2, 0), Color3.fromRGB(45, 47, 52), { parent = W })
	end
	hanokWall(Vector3.new(225.7, 0, 49), Vector3.new(700, 0, 49))
	hanokWall(Vector3.new(97, 0, 227.7), Vector3.new(97, 0, 700))
	-- fake shop buildings (photos: stacked shop signs on every floor, glass
	-- and stone facade, ground-floor shops). Walls only, nobody goes in.
	local SHOPS = {
		{ "보드게임카페", Color3.fromRGB(200, 40, 50) }, { "코인노래연습장", Color3.fromRGB(30, 30, 35) }, { "비스듬히", Color3.fromRGB(40, 40, 45) },
		{ "하나투어", Color3.fromRGB(40, 50, 140) }, { "VELVET", Color3.fromRGB(35, 35, 40) }, { "ZERO 전자담배", Color3.fromRGB(240, 180, 20) },
		{ "PASTA BAR", Color3.fromRGB(60, 60, 64) }, { "로라 헤어", Color3.fromRGB(245, 245, 245) }, { "경희 한의원 4F", Color3.fromRGB(40, 50, 120) },
		{ "프라임에셋", Color3.fromRGB(245, 245, 250) }, { "GS25 편의점", Color3.fromRGB(30, 140, 220) }, { "한우 곱창 전골", Color3.fromRGB(150, 30, 30) },
		{ "세무사 사무소", Color3.fromRGB(250, 250, 250) }, { "필라테스 3F", Color3.fromRGB(230, 120, 160) }, { "OHU 치과", Color3.fromRGB(60, 160, 140) },
		{ "PC방 24시", Color3.fromRGB(20, 20, 25) }, { "파티룸 · 셀프 사진", Color3.fromRGB(245, 245, 245) }, { "내과 · 건강검진", Color3.fromRGB(250, 248, 240) },
	}
	local TEX = { "rbxassetid://13654404035", "rbxassetid://14844635151", "rbxassetid://11361294440", "rbxassetid://36951684", "rbxassetid://17593427084" }
	local shopN = 0
	local function sign(parent, cf, w, h, text, bg)
		local s = part("ShopSign", Vector3.new(w, h, 0.3), cf, bg, { parent = parent })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 24
		g.LightInfluence = 0.4
		g.Parent = s
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		local dark = bg.R + bg.G + bg.B < 1.5
		t.TextColor3 = if dark then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(30, 40, 110)
		t.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10) pad.PaddingTop = UDim.new(0, 4) pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = t
		t.Parent = g
	end
	-- a building whose front (local -Z) looks along `front`
	local function fakeBuilding(center: Vector3, width: number, depth: number, height: number, front: Vector3)
		shopN += 1
		local M = Instance.new("Model")
		M.Name = "BG_Facade(진입불가)"
		M.Parent = T
		local cf = CFrame.lookAt(center, center + front)
		local body = part("Body", Vector3.new(width, height, depth), cf * CFrame.new(0, height / 2, 0), Color3.fromRGB(255, 255, 255), { parent = M })
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local tx = Instance.new("Texture")
			tx.Texture = TEX[(shopN % #TEX) + 1]
			tx.Face = f
			tx.StudsPerTileU = 20 tx.StudsPerTileV = 18
			tx.Parent = body
		end
		-- stone pilasters on the front
		for _, x in ipairs({ -width / 2 + 1, 0, width / 2 - 1 }) do
			part("Pilaster", Vector3.new(2, height, 0.6), cf * CFrame.new(x, height / 2, -depth / 2 - 0.3), Color3.fromRGB(205, 185, 150), { parent = M, material = Enum.Material.Sandstone })
		end
		-- ground floor shops: dark glass + awnings
		part("ShopGlass", Vector3.new(width - 2, 8, 0.3), cf * CFrame.new(0, 4.6, -depth / 2 - 0.2), Color3.fromRGB(40, 50, 60), { parent = M, material = Enum.Material.Glass, transparency = 0.2 })
		for k = 0, 1 do
			local sx = (k - 0.5) * width / 2
			local s = SHOPS[((shopN * 3 + k) % #SHOPS) + 1]
			sign(M, cf * CFrame.new(sx, 9.6, -depth / 2 - 0.8), width / 2 - 2.5, 1.8, s[1], s[2])
			part("Awning", Vector3.new(width / 2 - 3, 0.3, 2.2), cf * CFrame.new(sx, 8.2, -depth / 2 - 1.3) * CFrame.Angles(math.rad(-12), 0, 0), if k == 0 then Color3.fromRGB(200, 40, 50) else Color3.fromRGB(60, 60, 66), { parent = M, nocol = true })
		end
		-- upper floors: a sign band per floor, two signs side by side
		local floor = 1
		for y = 13, height - 6, 7 do
			for k = 0, 1 do
				local s = SHOPS[((shopN * 5 + floor * 2 + k) % #SHOPS) + 1]
				local sx = (k - 0.5) * (width / 2 - 1)
				sign(M, cf * CFrame.new(sx, y, -depth / 2 - 0.65), width / 2 - 4, 2.4, s[1] .. (if k == 0 then string.format(" %dF", floor + 1) else ""), s[2])
			end
			floor += 1
		end
		part("Roof", Vector3.new(width + 1, 1, depth + 1), cf * CFrame.new(0, height + 0.5, 0), Color3.fromRGB(90, 90, 95), { parent = M })
	end
	-- south road (it runs on to z 640 with trees, sidewalks and bike lane,
	-- bigRoad): the beach side gets a row of shops set back from the
	-- sidewalk; the hanok side stays an empty lot up to the 돌담길
	local hgt = { 44, 58, 38, 66, 50, 42, 60, 48 }
	for i, zz in ipairs({ 316, 352, 388, 424, 460, 496, 532, 568 }) do
		fakeBuilding(Vector3.new(-72, 0, zz), 34, 22, hgt[i], Vector3.new(1, 0, 0))
	end
	-- beach road, south of the Glasshouse cafe: shops facing the sea
	for i, zz in ipairs({ 262, 298, 334, 370, 406, 442, 478, 514, 550, 586, 622 }) do
		fakeBuilding(Vector3.new(-134, 0, zz), 34, 22, hgt[(i % #hgt) + 1], Vector3.new(-1, 0, 0))
	end
	-- next to the club, along the north road: fronts on the club line (x 48)
	-- right against the sidewalk (user 2026-10-23), on to the map edge
	local i2 = 0
	for zz = -252 + CLUB_DZ - 17.5, -985, -35 do -- the club's north face is at -252 + CLUB_DZ
		i2 += 1
		fakeBuilding(Vector3.new(56, 0, zz), 34, 16, hgt[(i2 + 3) % #hgt + 1], Vector3.new(-1, 0, 0))
	end
	-- the rest of the extended roads: shops on both sides past the boundary
	i2 = 0
	for zz = -505, -985, -35 do -- north road, west side (front +x at x -34)
		i2 += 1
		fakeBuilding(Vector3.new(-45, 0, zz), 34, 22, hgt[(i2 + 1) % #hgt + 1], Vector3.new(1, 0, 0))
	end
	i2 = 0
	for zz = 604, 985, 36 do -- south road, west side (after the existing row)
		i2 += 1
		fakeBuilding(Vector3.new(-72, 0, zz), 34, 22, hgt[(i2 + 5) % #hgt + 1], Vector3.new(1, 0, 0))
	end
	i2 = 0
	for xx = 330, 985, 35 do -- east road, north side (front +z at z -47)
		i2 += 1
		fakeBuilding(Vector3.new(xx, 0, -58), 34, 22, hgt[(i2 + 2) % #hgt + 1], Vector3.new(0, 0, 1))
	end

	-- the beach goes on north and south past the boundary
	local sandY = -BEACH_DROP + 0.6
	box("BeachSand", -268, sandY - 1.2, -900, -198, sandY, -480, Color3.fromRGB(232, 214, 165), { material = Enum.Material.Sand })
	box("BeachSand", -268, sandY - 1.2, 250, -198, sandY, 800, Color3.fromRGB(232, 214, 165), { material = Enum.Material.Sand })
	for _, seg in ipairs({ { -900, -480 }, { 300, 800 } }) do
		box("Promenade", -198, 0, seg[1], -182, CURB, seg[2], Color3.fromRGB(175, 135, 120), { material = Enum.Material.Brick })
		-- the steps down to the sand go on to the end (user 2026-10-23)
		local wood = Color3.fromRGB(120, 88, 62)
		box("BeachStepEdge", -198.7, sandY, seg[1], -198, CURB + 0.1, seg[2], Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
		box("BeachStep", -201.2, sandY, seg[1], -198.7, CURB - 0.6, seg[2], wood, { material = Enum.Material.WoodPlanks })
		box("BeachStep", -203.7, sandY, seg[1], -201.2, CURB - 1.2, seg[2], wood, { material = Enum.Material.WoodPlanks })
		box("BeachStep", -206.2, sandY, seg[1], -203.7, CURB - 1.8, seg[2], wood, { material = Enum.Material.WoodPlanks })
		box("SeaRoad", -182, 0, seg[1], -158, 0.12, seg[2], ASPHALT, { material = Enum.Material.Asphalt })
		paint("RedLane", -182, seg[1], -174, seg[2], Color3.fromRGB(190, 85, 75))
		box("Sidewalk", -158, 0, seg[1], -150, CURB, seg[2], WALK, { material = Enum.Material.Brick })
		paint("EdgeLine", -174.2, seg[1], -173.8, seg[2], WHITE)
		paint("CenterLine", -166.2, seg[1], -165.8, seg[2], YELLOW)

	end
end

------------------------------------------------------- beach furniture (광안리 photos, user 2026-10-23)
do
	local SAND_Y = CURB - BEACH_DROP
	local beachZone = root:FindFirstChild("04_Beach_Aquarium")
	-- (straw parasol spots tried and removed: the user keeps the original
	-- striped parasol / chair groups, 2026-10-23)
	-- beach signs (second photo); the boards are blank for now, the user
	-- designs the content later (parts named SignContent)
	local BROWN, BROWN2 = Color3.fromRGB(92, 48, 36), Color3.fromRGB(122, 66, 48)
	do -- tall rounded "surfboard" rules board, facing the promenade (+X)
		local x, z = -212, -166
		local board = Instance.new("Model")
		board.Name = "BeachRulesSign"
		board.Parent = T
		local W, H, bottom = 3.2, 7.2, SAND_Y + 1.6
		part("SignBoard", Vector3.new(0.3, H, W), CFrame.new(x, bottom + W / 2 + H / 2, z), BROWN, { parent = board })
		for _, y in ipairs({ bottom + W / 2, bottom + W / 2 + H }) do
			part("SignBoardEnd", Vector3.new(0.3, W, W), CFrame.new(x, y, z), BROWN, { parent = board, shape = Enum.PartType.Cylinder })
		end
		part("SignContent", Vector3.new(0.05, H - 0.6, W - 0.6), CFrame.new(x + 0.18, bottom + W / 2 + H / 2, z), BROWN2, { parent = board, nocol = true })
		for _, dz in ipairs({ -0.8, 0.8 }) do
			part("SignLeg", Vector3.new(0.25, 1.9, 0.25), CFrame.new(x, SAND_Y + 0.95, z + dz), Color3.fromRGB(60, 34, 26), { parent = board })
		end
	end
	do -- map board on two posts
		local x, z = -212, -154
		local board = Instance.new("Model")
		board.Name = "BeachMapSign"
		board.Parent = T
		local W, H, y0 = 8.4, 5.4, SAND_Y + 1.8
		for _, dz in ipairs({ -W / 2 + 0.3, W / 2 - 0.3 }) do
			part("SignPost", Vector3.new(0.45, y0 + H - SAND_Y + 0.3, 0.45), CFrame.new(x - 0.2, (SAND_Y + y0 + H + 0.3) / 2, z + dz), Color3.fromRGB(70, 44, 32), { parent = board, material = Enum.Material.Wood })
		end
		part("SignFrame", Vector3.new(0.35, H, W), CFrame.new(x, y0 + H / 2, z), Color3.fromRGB(100, 62, 42), { parent = board, material = Enum.Material.Wood })
		part("SignContent", Vector3.new(0.05, H - 0.7, W - 0.7), CFrame.new(x + 0.2, y0 + H / 2, z), Color3.fromRGB(242, 238, 228), { parent = board, nocol = true })
	end
end

------------------------------------------------------- 오후네컷 building
-- From the user's 연남동 photo (2026-10-23, docs/04_ART/PHOTO_BOOTH_BUILDING.md):
-- a three-storey white brick corner building on a granite plinth; the ground
-- floor is the photo booth shop. Front = the cut corner toward the crossroads
-- (pink-framed glass doors, "오후네컷" sign), left = the north-road face
-- (pink-framed poster window, "OHU4cuts" sign), right = the east-road face
-- (white tiles, four pill-shaped windows, a low wooden deck). Upper floors are
-- facade only (not enterable); no signs on them (the photo's beer signs are
-- left out: no alcohol). The graybox walls / roof / sign are parked.
do
	local zoneName = "08_PhotoBooth"
	local shop = root:FindFirstChild(zoneName)
	local undo = MOVES[zoneName]:Inverse()
	if shop then
		for _, c in ipairs(shop:GetChildren()) do
			if c:IsA("BasePart") and (string.match(c.Name, "^Wall_") or string.match(c.Name, "^Roof") or string.match(c.Name, "^Sign_") or c.Name == "Label" or c.Name == "ShopFloor") then
				c.CFrame = undo * c.CFrame -- hidden parts are restored where the built zone has them
				c:SetAttribute("HomeZone", zoneName)
				c.Parent = hidden
			end
		end
		-- booth name labels: new shop name, below the new ceiling
		for _, m in ipairs(shop:GetChildren()) do
			if m:IsA("Model") and CS:HasTag(m, "PhotoBooth") then
				for _, l in ipairs(m:GetChildren()) do
					local t = l:FindFirstChildWhichIsA("BillboardGui") and l:FindFirstChildWhichIsA("BillboardGui"):FindFirstChildWhichIsA("TextLabel")
					if l:IsA("BasePart") and l.Name == "Label" and t then
						l:SetAttribute("OrigCFrame", l.CFrame)
						t:SetAttribute("OrigText", t.Text)
						t.Text = string.gsub(t.Text, "인생네컷", "오후네컷")
						l.CFrame = CFrame.new(l.Position.X, 14.4, l.Position.Z)
					end
				end
			end
		end
	end

	local B = Instance.new("Model")
	B.Name = "OhuFourCuts"
	B.Parent = T
	local F = 1.6 -- shop floor top (graybox 0.4 + 1.2 lift)
	local GF = F + 19 -- top of the ground floor / underside of the fascia (high ceiling, user)
	local W0, W1, N0, S0 = 48.5, 109.5, -98.5, -47.5 -- outer faces: west, east, north, south
	local CH = 11 -- cut corner
	local P1, P2 = Vector3.new(W0, 0, S0 - CH), Vector3.new(W0 + CH, 0, S0) -- ends of the cut corner
	local tC = (P2 - P1).Unit -- along the cut corner (north-west → south-east)
	local nC = Vector3.new(-1, 0, 1).Unit -- out of the cut corner
	local MC = (P1 + P2) / 2
	local WHITE_WALL = Color3.fromRGB(246, 245, 241)
	local BRICK = Color3.fromRGB(255, 255, 255) -- the Brick material darkens: pure white reads as painted white brick
	local PINK = Color3.fromRGB(246, 150, 186)
	local GRANITE = Color3.fromRGB(176, 172, 166)
	local FRAME = Color3.fromRGB(58, 46, 42)
	local GLASS = Color3.fromRGB(70, 86, 98)
	local o = { parent = B }
	local function opt(t) local r = { parent = B } for k, v in pairs(t) do r[k] = v end return r end
	-- a slab along the cut corner: centre offset `out` from the corner line
	local function cutPart(name, len, y0, y1, depth, out, color, op)
		local c = MC + nC * out
		return part(name, Vector3.new(len, y1 - y0, depth), CFrame.lookAt(Vector3.new(c.X, (y0 + y1) / 2, c.Z), Vector3.new(c.X, (y0 + y1) / 2, c.Z) + nC), color, op or o)
	end
	local function cutAt(name, s, size, y, out, color, op) -- s = offset along the corner from its middle
		local c = MC + tC * s + nC * out
		return part(name, size, CFrame.lookAt(Vector3.new(c.X, y, c.Z), Vector3.new(c.X, y, c.Z) + nC), color, op or o)
	end

	-- plinth + floor follow the cut corner (the graybox shop floor is parked):
	-- granite base, the shop floor on top, a ledge along the two street faces
	local FLOOR_COL = Color3.fromRGB(206, 202, 196) -- grey-beige tiles (user interior photos)
	local depthIn = CH / math.sqrt(2) * 2
	box("Plinth", W0, 0, N0, W1, F - 0.4, S0 - CH, GRANITE, opt({ material = Enum.Material.Granite }))
	box("Plinth", W0 + CH, 0, S0 - CH, W1, F - 0.4, S0, GRANITE, opt({ material = Enum.Material.Granite }))
	cutPart("Plinth", CH * math.sqrt(2), 0, F - 0.4, depthIn, -depthIn / 2, GRANITE, opt({ material = Enum.Material.Granite }))
	local tileOpt = opt({ material = Enum.Material.CeramicTiles })
	box("ShopFloor", W0, F - 0.4, N0, W1, F, S0 - CH, FLOOR_COL, tileOpt)
	box("ShopFloor", W0 + CH, F - 0.4, S0 - CH, W1, F, S0, FLOOR_COL, tileOpt)
	cutPart("ShopFloor", CH * math.sqrt(2), F - 0.4, F, depthIn, -depthIn / 2, FLOOR_COL, tileOpt)
	-- one wooden deck step at floor height along all three street faces
	-- (user 2026-10-23: the wood of the old right-hand deck everywhere, one step
	-- instead of two in front of the door), an invisible ramp at the door
	local WOOD = Color3.fromRGB(150, 112, 78)
	local DECK = 2.6
	local woodOpt = opt({ material = Enum.Material.WoodPlanks })
	box("Deck", W0 - DECK, 0, N0 + 1, W0, F, S0 - CH + 1.1, WOOD, woodOpt)
	box("Deck", W0 + CH - 1.1, 0, S0, W1 - 1, F, S0 + DECK, WOOD, woodOpt)
	cutPart("Deck", CH * math.sqrt(2) + 2.2, 0, F, DECK, DECK / 2, WOOD, woodOpt)
	-- pavement in the rest of the corner (named Sidewalk: street_dress gives it
	-- the paver texture), a hair lower than the sidewalks it overlaps
	cutPart("Sidewalk", CH * math.sqrt(2) + 12, 0, CURB - 0.02, 6, 3.8 + 3, WALK, { parent = T, material = Enum.Material.Brick })
	do
		local ramp = Instance.new("WedgePart")
		ramp.Name = "StepRamp"
		ramp.Anchored = true
		ramp.Transparency = 1
		ramp.Size = Vector3.new(CH * math.sqrt(2) + 2, F - CURB, 2.4)
		local rc = MC + nC * (DECK + 1.2)
		ramp.CFrame = CFrame.lookAt(Vector3.new(rc.X, (F + CURB) / 2, rc.Z), Vector3.new(rc.X, (F + CURB) / 2, rc.Z) + nC)
		ramp.Parent = B
	end

	-- ground floor walls (graybox wall lines, 1 thick)
	box("WallW", W0, F, N0, W0 + 1, GF, S0 - CH, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	local wallS = box("WallS", W0 + CH, F, S0 - 1, W1, GF, S0, WHITE_WALL, opt({ material = Enum.Material.CeramicTiles }))
	box("WallN", W0, F, N0, W1, GF + 26, N0 + 1, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	box("WallE", W1 - 1, F, N0, W1, GF + 26, S0, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	box("Ceiling", W0, GF - 0.4, N0, W1, GF, S0 - CH, Color3.fromRGB(250, 248, 250), o)
	box("Ceiling", W0 + CH, GF - 0.4, S0 - CH, W1, GF, S0, Color3.fromRGB(250, 248, 250), o)
	for _, p in ipairs({ { 58, -88 }, { 58, -70 }, { 72, -88 }, { 72, -70 }, { 72, -56 }, { 84, -88 }, { 84, -70 }, { 84, -56 }, { 98, -85 }, { 98, -61 } }) do
		-- plain white panels (Neon panels made the bloom wash the room out)
		local lamp = box("CeilingLight", p[1] - 1.5, GF - 0.55, p[2] - 1.5, p[1] + 1.5, GF - 0.4, p[2] + 1.5, Color3.fromRGB(255, 252, 246), opt({ nocol = true }))
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Color = 26, 1.2, Color3.fromRGB(255, 244, 232)
		l.Parent = lamp
	end

	-- front: the cut corner, pink frame around glass sidelights and sliding doors
	local cutLen = CH * math.sqrt(2)
	local DOOR = 7
	cutPart("CornerHead", cutLen, F + 10.6, GF, 1, -0.5, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	for _, s in ipairs({ -1, 1 }) do
		cutAt("PinkPost", s * (cutLen / 2 - 0.5), Vector3.new(1, 10.6, 1.4), F + 5.3, -0.3, PINK)
		cutAt("PinkMullion", s * (DOOR / 2 + 0.3), Vector3.new(0.35, 10.6, 1), F + 5.3, -0.3, PINK) -- thinner than the outer frame (user)
		-- light panel inside the outer post: lights up at night (NightGlow)
		local gp = cutAt("FrameGlow", s * (cutLen / 2 - 0.5), Vector3.new(0.5, 10, 0.1), F + 5.3, 0.45, Color3.fromRGB(255, 225, 240), opt({ nocol = true }))
		CS:AddTag(gp, "NightGlow")
		local w = cutLen / 2 - DOOR / 2 - 1.8
		cutAt("Sidelight", s * (DOOR / 2 + 0.8 + w / 2), Vector3.new(w, 9.4, 0.3), F + 5.3, -0.4, Color3.fromRGB(200, 215, 225), opt({ material = Enum.Material.Glass, transparency = 0.45 }))
	end
	cutAt("PinkHead", 0, Vector3.new(cutLen, 1.2, 1.4), F + 10.6, -0.3, PINK)
	do
		local gh = cutAt("FrameGlow", 0, Vector3.new(cutLen - 1, 0.5, 0.1), F + 10.6, 0.45, Color3.fromRGB(255, 225, 240), opt({ nocol = true }))
		CS:AddTag(gh, "NightGlow")
	end
	local door = Instance.new("Model")
	door.Name = "AutoDoor"
	door:SetAttribute("Range", 9)
	for _, s in ipairs({ -1, 1 }) do
		local panel = cutAt("DoorPanel", s * DOOR / 4, Vector3.new(DOOR / 2, 10, 0.3), F + 5, -0.5, Color3.fromRGB(205, 220, 232), opt({ parent = door, material = Enum.Material.Glass, transparency = 0.4 }))
		panel:SetAttribute("Slide", tC * (s * (DOOR / 2 - 0.2)))
		cutAt("DoorFrame", s * (DOOR / 2 - 0.1), Vector3.new(0.25, 10, 0.4), F + 5, -0.5, PINK, opt({ parent = door, nocol = true })):SetAttribute("Slide", tC * (s * (DOOR / 2 - 0.2)))
	end
	local dc = MC - nC * 0.5
	door.WorldPivot = CFrame.new(dc.X, F + 4, dc.Z)
	door:SetAttribute("Panels", 4)
	door.Parent = B
	CS:AddTag(door, "AutoDoor")

	-- left (west, north road): pink-framed poster window
	local function westPanel(name, z0, z1, y0, y1, out, color, op)
		return box(name, W0 - out, y0, z0, W0, y1, z1, color, op)
	end
	-- the poster fills the west face up to the sign band (user 2026-10-23)
	westPanel("PosterFrame", N0 + 2.5, S0 - CH - 1.5, F + 0.6, F + 11.2, 0.5, PINK, o)
	local poster = westPanel("Poster", N0 + 3.3, S0 - CH - 2.3, F + 1.4, F + 10.4, 0.6, Color3.fromRGB(196, 190, 236), o)
	do
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Left
		g.LightInfluence = 0.3
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.Parent = poster
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(70, 60, 120)
		l.Text = "✦ NEW FRAME ✦\nOHU4cuts\n친구랑 같이 찍어요"
		l.Parent = g
	end

	-- right (south, east road): four pill windows cut through the wall (user:
	-- see inside), clear glass to stop walking through, a white rim; one CSG
	-- union for the wall and one per rim keeps the part count low
	local PILL_X, PILL_W, PILL_H, PILL_Y = { 68, 79, 90, 101 }, 4, 8.8, F + 6
	local function pill(name, x, w, h, z, depth, color, op) -- box + two half discs
		local ps = { part(name, Vector3.new(w, h - w, depth), CFrame.new(x, PILL_Y, z), color, op) }
		for _, dy in ipairs({ -1, 1 }) do
			table.insert(ps, part(name, Vector3.new(depth, w, w), CFrame.new(x, PILL_Y + dy * (h - w) / 2, z) * CFrame.Angles(0, math.rad(90), 0), color, (function() local r = table.clone(op) r.shape = Enum.PartType.Cylinder return r end)()))
		end
		return ps
	end
	local holes = {}
	for _, x in ipairs(PILL_X) do
		for _, p in ipairs(pill("PillHole", x, PILL_W, PILL_H, S0 - 0.5, 3, WHITE_WALL, o)) do table.insert(holes, p) end
	end
	wallS.Parent = workspace -- CSG only works on parts in the Workspace
	for _, p in ipairs(holes) do p.Parent = workspace end
	local okWall, cutWall = pcall(function() return wallS:SubtractAsync(holes) end)
	for _, p in ipairs(holes) do p:Destroy() end
	wallS.Parent = B
	if okWall and cutWall then
		cutWall.Name = "WallS"
		cutWall.UsePartColor = true
		cutWall.Material = Enum.Material.CeramicTiles
		cutWall.Anchored = true
		cutWall.Parent = B
		wallS:Destroy()
	end
	for _, x in ipairs(PILL_X) do
		-- rim: a pill ring standing 0.3 proud of the tiles
		local outer = pill("PillRim", x, PILL_W + 0.9, PILL_H + 0.9, S0 + 0.15, 0.3, WHITE_WALL, o)
		local inner = pill("PillRimCut", x, PILL_W, PILL_H, S0 + 0.15, 1, WHITE_WALL, o)
		for _, p in ipairs(outer) do p.Parent = workspace end
		for _, p in ipairs(inner) do p.Parent = workspace end
		local okRim, rim = pcall(function() return outer[1]:UnionAsync({ outer[2], outer[3] }) end)
		if okRim and rim then rim.Parent = workspace end
		if okRim and rim then
			local okCut, ring = pcall(function() return rim:SubtractAsync(inner) end)
			if okCut and ring then
				ring.Name = "PillRim"
				ring.UsePartColor = true
				ring.Anchored = true
				ring.Parent = B
			end
			rim:Destroy()
		end
		for _, p in ipairs(outer) do p:Destroy() end
		for _, p in ipairs(inner) do p:Destroy() end
		-- clear glass in the middle of the wall: see in, can't walk through
		pill("PillGlass", x, PILL_W, PILL_H, S0 - 0.5, 0.1, Color3.fromRGB(225, 235, 240), opt({ material = Enum.Material.Glass, transparency = 0.75 }))
	end

	-- fascia band over the ground floor with the signs (인생네컷-style: white
	-- raised letters with a lavender edge, aperture logo)
	-- the sign band sits just above the doors (user 2026-10-23: lower the box
	-- with the letters, so it shows on screen); a thin cornice marks the floor
	-- line under the upper floors
	local FAS0, FAS1 = F + 11.4, F + 17.6 -- taller white band (user 2026-10-23)

	local FASCIA = Color3.fromRGB(232, 231, 228) -- a touch darker than the white letters
	box("Fascia", W0 - 1.2, FAS0, N0 + 2, W0 + 1, FAS1, S0 - CH, FASCIA, o)
	box("Fascia", W0 + CH, FAS0, S0 - 1, W1 - 2, FAS1, S0 + 1.2, FASCIA, o)
	cutPart("Fascia", cutLen, FAS0, FAS1, 2.2, 0.1, FASCIA)
	-- 3D sign letters (user 2026-10-23: white, thick, real shadows from the sun
	-- instead of the lavender shadow): every stroke is a white part 0.35 deep on
	-- the fascia. Glyphs are drawn in a unit box (x right, y up): seg = straight
	-- stroke, ell = elliptical arc (centre, radii, start / end angle in degrees).
	local SIGN_WHITE = Color3.fromRGB(250, 250, 250)
	local function seg(x0, y0, x1, y1) return { "s", x0, y0, x1, y1 } end
	local function ell(cx, cy, rx, ry, a0, a1) return { "e", cx, cy, rx, ry, a0 or 0, a1 or 360 } end
	local GLYPHS = {
		["오"] = { 1, { ell(0.5, 0.7, 0.2, 0.2), seg(0.5, 0.5, 0.5, 0.3), seg(0.06, 0.28, 0.94, 0.28) } },
		["후"] = { 1, { seg(0.5, 1, 0.5, 0.92), seg(0.24, 0.9, 0.76, 0.9), ell(0.5, 0.69, 0.15, 0.13), seg(0.06, 0.45, 0.94, 0.45), seg(0.5, 0.45, 0.5, 0) } },
		["네"] = { 1, { seg(0.08, 0.9, 0.08, 0.22), seg(0.08, 0.22, 0.5, 0.22), seg(0.5, 0.56, 0.66, 0.56), seg(0.66, 0.96, 0.66, 0.04), seg(0.9, 1, 0.9, 0) } },
		["컷"] = { 1, { seg(0.06, 0.96, 0.48, 0.96), seg(0.48, 0.96, 0.45, 0.54), seg(0.08, 0.76, 0.47, 0.76), seg(0.78, 1, 0.78, 0.42), seg(0.62, 0.72, 0.78, 0.72), seg(0.43, 0.38, 0.2, 0.02), seg(0.43, 0.38, 0.66, 0.02) } },
		["O"] = { 0.7, { ell(0.35, 0.5, 0.32, 0.48) } },
		["H"] = { 0.66, { seg(0.06, 0, 0.06, 1), seg(0.6, 0, 0.6, 1), seg(0.06, 0.5, 0.6, 0.5) } },
		["U"] = { 0.66, { seg(0.06, 1, 0.06, 0.3), seg(0.6, 1, 0.6, 0.3), ell(0.33, 0.3, 0.27, 0.3, 180, 360) } },
		["4"] = { 0.62, { seg(0.46, 0, 0.46, 1), seg(0.46, 1, 0.02, 0.3), seg(0.02, 0.3, 0.62, 0.3) } },
		["c"] = { 0.56, { ell(0.3, 0.34, 0.27, 0.34, 40, 320) } },
		["u"] = { 0.58, { seg(0.06, 0.68, 0.06, 0.24), ell(0.29, 0.24, 0.23, 0.24, 180, 360), seg(0.52, 0.68, 0.52, 0) } },
		["t"] = { 0.46, { seg(0.2, 0.92, 0.2, 0.16), ell(0.36, 0.16, 0.16, 0.16, 180, 290), seg(0.02, 0.66, 0.42, 0.66) } },
		["s"] = { 0.54, { ell(0.27, 0.51, 0.22, 0.17, 20, 270), ell(0.27, 0.17, 0.22, 0.17, 90, -160) } },
		["◎"] = { 1, { ell(0.5, 0.5, 0.48, 0.48) } },
	}
	-- aperture logo blades (inside the ◎ ring)
	for k = 0, 5 do
		local a = math.rad(k * 60)
		local cx, cy = 0.5 + 0.19 * math.cos(a), 0.5 + 0.19 * math.sin(a)
		local d = a + math.rad(115)
		table.insert(GLYPHS["◎"][2], seg(cx - 0.27 * math.cos(d), cy - 0.27 * math.sin(d), cx + 0.27 * math.cos(d), cy + 0.27 * math.sin(d)))
	end
	-- origin = centre of the sign on the fascia face, right / out = unit vectors
	local function sign3d(name, chars, origin: Vector3, right: Vector3, out: Vector3, H)
		local SW, DEPTH, GAP = 0.17 * H, 0.8, 0.16
		local up = Vector3.yAxis
		local total = 0
		for i, ch in ipairs(chars) do total += GLYPHS[ch][1] + (if i > 1 then GAP else 0) end
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = B
		local function stroke(a: Vector3, b: Vector3)
			local len = (b - a).Magnitude
			if len < 0.01 then return end
			-- channel letter: light grey sides, pure white face (reads on the
			-- white fascia even head-on)
			local cf = CFrame.fromMatrix((a + b) / 2, (b - a).Unit, out)
			part("Letter", Vector3.new(len + SW * 0.9, DEPTH - 0.06, SW), cf * CFrame.new(0, -0.03, 0), Color3.fromRGB(196, 196, 204), { parent = m, nocol = true })
			part("LetterFace", Vector3.new(len + SW * 0.9, 0.06, SW), cf * CFrame.new(0, DEPTH / 2 - 0.03, 0), SIGN_WHITE, { parent = m, nocol = true, material = Enum.Material.SmoothPlastic })
			-- halo: a soft lavender neon behind each stroke, on the band (user 2026-10-23)
			local halo = part("LetterHalo", Vector3.new(len + SW * 0.9 + 0.35, 0.04, SW + 0.35), cf * CFrame.new(0, -DEPTH / 2 - 0.01, 0), Color3.fromRGB(170, 125, 255), { parent = m, nocol = true, material = Enum.Material.Neon, transparency = 0.25 })
			halo.CastShadow = false
		end
		local x = -total / 2
		for i, ch in ipairs(chars) do
			if i > 1 then x += GAP end
			local g = GLYPHS[ch]
			local function at(px, py) return origin + out * (DEPTH / 2) + right * ((x + px) * H) + up * ((py - 0.5) * H) end
			for _, s in ipairs(g[2]) do
				if s[1] == "s" then
					stroke(at(s[2], s[3]), at(s[4], s[5]))
				else
					local cx, cy, rx, ry, a0, a1 = s[2], s[3], s[4], s[5], math.rad(s[6]), math.rad(s[7])
					local n = math.max(8, math.ceil(math.abs(a1 - a0) / math.rad(15)))
					local prev = at(cx + rx * math.cos(a0), cy + ry * math.sin(a0))
					for k = 1, n do
						local a = a0 + (a1 - a0) * k / n
						local p = at(cx + rx * math.cos(a), cy + ry * math.sin(a))
						stroke(prev, p)
						prev = p
					end
				end
			end
			x += g[1]
		end
	end
	-- the shop name sits one band lower, on the wall between the door frame and
	-- the fascia, so players see it from the street (user 2026-10-23)
	local fasMid = (FAS0 + FAS1) / 2
	sign3d("Sign_OhuNeCut", { "◎", "오", "후", "네", "컷" }, Vector3.new(MC.X, fasMid, MC.Z) + nC * 1.2, tC, nC, 1.33) -- 2/3 size
	sign3d("Sign_OHU4cuts", { "◎", "O", "H", "U", "4", "c", "u", "t", "s" }, Vector3.new(W0 - 1.2, fasMid, -74), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), 1.33)

	-- upper floors (2F, 3F): white brick mass with the cut corner, dark-framed
	-- windows, floor bands, then a parapet with a steel railing (roof terrace)
	-- the brick starts right on top of the sign band (user 2026-10-23: no white
	-- strip). The upper floors are a brick shell on the street faces only, so
	-- the high shop ceiling inside stays where it is.
	local U0, U1 = FAS1, GF + 22.8
	local FLOOR = (U1 - U0) / 2
	box("UpperW", W0 - 0.05, U0, N0, W0 + 1, U1, S0 - CH, BRICK, opt({ material = Enum.Material.Brick }))
	box("UpperS", W0 + CH, U0, S0 - 1, W1, U1, S0 + 0.05, BRICK, opt({ material = Enum.Material.Brick }))
	cutPart("UpperCut", cutLen, U0, U1, 1, -0.45, BRICK, opt({ material = Enum.Material.Brick }))
	local function window(cf: CFrame, w, h) -- cf at the window centre on the wall face, looking out
		part("WindowFrame", Vector3.new(w + 0.6, h + 0.6, 0.3), cf * CFrame.new(0, 0, -0.15), FRAME, o)
		part("WindowGlass", Vector3.new(w, h, 0.2), cf * CFrame.new(0, 0, -0.25), GLASS, opt({ material = Enum.Material.Glass, transparency = 0.15 }))
		part("WindowMullion", Vector3.new(0.25, h, 0.3), cf * CFrame.new(0, 0, -0.3), FRAME, o)
		part("WindowSill", Vector3.new(w + 1, 0.3, 0.7), cf * CFrame.new(0, -h / 2 - 0.45, -0.35), WHITE_WALL, o)
	end
	for f = 0, 1 do
		local y = U0 + f * FLOOR + FLOOR / 2
		for _, z in ipairs({ -90, -78, -66 }) do window(CFrame.lookAt(Vector3.new(W0, y, z), Vector3.new(W0 - 1, y, z)), 5, 6) end
		for _, x in ipairs({ 68, 81, 94 }) do window(CFrame.lookAt(Vector3.new(x, y, S0), Vector3.new(x, y, S0 + 1)), 5, 6) end
		local c = MC + nC * 0
		window(CFrame.lookAt(Vector3.new(c.X, y, c.Z), Vector3.new(c.X, y, c.Z) + nC), 4.5, 6)
		if f == 1 then -- band between 2F and 3F
			box("FloorBand", W0 - 0.4, U0 + FLOOR - 0.3, N0, W0, U0 + FLOOR + 0.3, S0 - CH, WHITE_WALL, o)
			box("FloorBand", W0 + CH, U0 + FLOOR - 0.3, S0, W1, U0 + FLOOR + 0.3, S0 + 0.4, WHITE_WALL, o)
			cutPart("FloorBand", cutLen, U0 + FLOOR - 0.3, U0 + FLOOR + 0.3, 0.4, 0.2, WHITE_WALL)
		end
	end
	-- roof: slab, parapet on the street faces, steel railing, stair house
	box("Roof", W0, U1, N0, W1, U1 + 0.5, S0 - CH, Color3.fromRGB(150, 150, 150), opt({ material = Enum.Material.Concrete }))
	box("Roof", W0 + CH, U1, S0 - CH, W1, U1 + 0.5, S0, Color3.fromRGB(150, 150, 150), opt({ material = Enum.Material.Concrete }))
	cutPart("Roof", cutLen, U1, U1 + 0.5, CH / math.sqrt(2) * 2, -CH / math.sqrt(2), Color3.fromRGB(150, 150, 150), opt({ material = Enum.Material.Concrete }))
	box("Parapet", W0, U1, N0, W0 + 0.8, U1 + 2.6, S0 - CH, WHITE_WALL, o)
	box("Parapet", W0 + CH, U1, S0 - 0.8, W1, U1 + 2.6, S0, WHITE_WALL, o)
	cutPart("Parapet", cutLen, U1, U1 + 2.6, 0.8, -0.4, WHITE_WALL)
	local function rail(a: Vector3, b: Vector3)
		local y = U1 + 2.6
		local len = (b - a).Magnitude
		local d = (b - a).Unit
		part("RailTop", Vector3.new(0.25, 0.25, len), CFrame.lookAt((a + b) / 2 + Vector3.new(0, y + 3, 0), b + Vector3.new(0, y + 3, 0)), Color3.fromRGB(70, 72, 76), opt({ material = Enum.Material.Metal }))
		for s = 0, len, 2.5 do
			local p = a + d * s
			part("RailPost", Vector3.new(0.15, 3, 0.15), CFrame.new(p.X, y + 1.5, p.Z), Color3.fromRGB(70, 72, 76), opt({ material = Enum.Material.Metal }))
		end
	end
	rail(Vector3.new(W0 + 0.4, 0, N0 + 0.5), P1 + Vector3.new(0.4, 0, 0))
	rail(P1 + Vector3.new(0.4, 0, 0), P2 + Vector3.new(0, 0, -0.4))
	rail(P2 + Vector3.new(0, 0, -0.4), Vector3.new(W1 - 0.5, 0, S0 - 0.4))
	box("StairHouse", W1 - 16, U1 + 0.5, N0 + 2, W1 - 3, U1 + 9, N0 + 12, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	------------------------------------------------- interior (user photos 2026-10-23)
	-- White grid-tile walls, a tiled front wall with a mint arch per booth
	-- (curtain pulled aside, "PHOTO 01 / 02" plates), the photo machine
	-- inside, mint arch niches with white wire shelves of hats and plush (OHU
	-- 4 CUT PLAYGROUND), an accessory arch with headbands, blue light boxes
	-- with neon tubes, pink notice posters and a bulb vanity mirror on a
	-- yellow acrylic table.
	local MINT, CURTAIN = Color3.fromRGB(128, 196, 186), Color3.fromRGB(196, 120, 120)
	local TILE = opt({ material = Enum.Material.CeramicTiles })
	local function txt(p: BasePart, face, text, color, font, bg, ppStud)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = ppStud or 40
		g.LightInfluence = 0.4
		g.Parent = p
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = if bg then 0 else 1
		if bg then l.BackgroundColor3 = bg end
		l.TextScaled = true
		l.Font = font or Enum.Font.GothamBold
		l.TextColor3 = color
		l.Text = text
		l.Parent = g
		return l
	end
	-- arch outline in a vertical plane: centre bottom c, along = unit along the
	-- wall, out = unit out of the wall; w wide, h tall (incl. the half circle)
	local function archRim(c: Vector3, along: Vector3, out: Vector3, w, h, th, depth, color, parent)
		local r = w / 2
		local postH = h - r
		for _, s in ipairs({ -1, 1 }) do
			local p = c + along * (s * (r - th / 2)) + Vector3.new(0, postH / 2, 0)
			part("ArchRim", Vector3.new(th, postH, depth), CFrame.fromMatrix(p, along, Vector3.yAxis), color, { parent = parent })
		end
		local top = c + Vector3.new(0, postH, 0)
		local N = 10
		for k = 0, N - 1 do
			local a0, a1 = math.pi * k / N, math.pi * (k + 1) / N
			local p0 = top + along * (math.cos(a0) * (r - th / 2)) + Vector3.new(0, math.sin(a0) * (r - th / 2), 0)
			local p1 = top + along * (math.cos(a1) * (r - th / 2)) + Vector3.new(0, math.sin(a1) * (r - th / 2), 0)
			local d = p1 - p0
			part("ArchRim", Vector3.new(d.Magnitude + th * 0.6, th, depth), CFrame.fromMatrix((p0 + p1) / 2, d.Unit, out:Cross(d.Unit)), color, { parent = parent })
		end
	end
	-- a flat arch-shaped panel (box + half disc)
	local function archPanel(c: Vector3, along: Vector3, out: Vector3, w, h, depth, color, parent, mat)
		local r = w / 2
		local body = part("ArchPanel", Vector3.new(w, h - r, depth), CFrame.fromMatrix(c + Vector3.new(0, (h - r) / 2, 0), along, Vector3.yAxis), color, { parent = parent, material = mat })
		part("ArchPanel", Vector3.new(depth, w, w), CFrame.fromMatrix(c + Vector3.new(0, h - r, 0), out, Vector3.yAxis), color, { parent = parent, material = mat, shape = Enum.PartType.Cylinder })
		return body
	end

	-- wall liners: white grid tiles on the inside faces. The club south wall
	-- reaches z -96 (inside this shop since the shop moved north, D-104), so
	-- the north liner stands in front of it and the photo wall moves out too.
	local NIN = -95.8
	box("WallTiles", W0 + 1, F, NIN - 0.1, W1 - 1, GF - 0.4, NIN, Color3.fromRGB(246, 246, 244), TILE)
	box("WallTiles", W0 + 1, F, NIN, W0 + 1.1, GF - 0.4, S0 - CH, Color3.fromRGB(246, 246, 244), TILE)
	local zoneP = root:FindFirstChild("08_PhotoBooth")
	for _, name in ipairs({ "PhotoWall" }) do
		local p = zoneP and zoneP:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p:SetAttribute("OrigCFrame", p.CFrame)
			p.CFrame = p.CFrame + Vector3.new(0, 0, NIN + p.Size.Z / 2 + 0.05 - p.Position.Z)
		end
	end

	-- booth front wall at x 87 with an arch per booth
	local FX = 87
	local booths = {}
	local shopZone = root:FindFirstChild("08_PhotoBooth")
	if shopZone then
		for _, m in ipairs(shopZone:GetChildren()) do
			if m:IsA("Model") and CS:HasTag(m, "PhotoBooth") and m:FindFirstChild("CameraPoint") then table.insert(booths, m) end
		end
	end
	table.sort(booths, function(a, b) return a.CameraPoint.Position.Z < b.CameraPoint.Position.Z end)
	local front = box("BoothWall", FX, F, NIN, FX + 1, GF - 0.4, -52, Color3.fromRGB(246, 246, 244), TILE)
	local cuts = {}
	local AW, AH = 12, 14
	for _, m in ipairs(booths) do
		local bz = m.CameraPoint.Position.Z
		local hole = part("ArchHole", Vector3.new(4, AH - AW / 2, AW), CFrame.new(FX + 0.5, F + (AH - AW / 2) / 2 - 0.5, bz), WHITE_WALL, o)
		local disc = part("ArchHole", Vector3.new(4, AW, AW), CFrame.new(FX + 0.5, F + AH - AW / 2, bz) * CFrame.Angles(0, 0, math.rad(90)), WHITE_WALL, opt({ shape = Enum.PartType.Cylinder }))
		table.insert(cuts, hole) table.insert(cuts, disc)
	end
	front.Parent = workspace
	for _, p in ipairs(cuts) do p.Parent = workspace end
	local okF, cutFront = pcall(function() return front:SubtractAsync(cuts) end)
	for _, p in ipairs(cuts) do p:Destroy() end
	front.Parent = B
	if okF and cutFront then
		cutFront.Name = "BoothWall"
		cutFront.UsePartColor = true
		cutFront.Material = Enum.Material.CeramicTiles
		cutFront.Anchored = true
		cutFront.Parent = B
		front:Destroy()
	end
	local along, out = Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0)
	for i, m in ipairs(booths) do
		local cam = m.CameraPoint
		local bz = cam.Position.Z
		archRim(Vector3.new(FX - 0.15, F, bz), along, out, AW + 1.2, AH + 0.6, 0.9, 1.6, MINT, B)
		-- curtain pulled to the north side of the arch (decor, walk-through)
		for k = 0, 3 do
			part("Curtain", Vector3.new(0.35, AH - AW / 2 - 0.5, 0.9), CFrame.new(FX + 0.9, F + (AH - AW / 2 - 0.5) / 2, bz - AW / 2 + 0.6 + k * 0.75) * CFrame.Angles(0, math.rad(if k % 2 == 0 then 20 else -20), 0), CURTAIN, opt({ material = Enum.Material.Fabric, nocol = true }))
		end
		local plate = part("PhotoPlate", Vector3.new(0.2, 1.3, 4.2), CFrame.new(FX - 0.25, F + AH + 1.6, bz), Color3.new(1, 1, 1), opt({ nocol = true }))
		txt(plate, Enum.NormalId.Left, string.format("PHOTO %02d", i), Color3.fromRGB(30, 30, 30), Enum.Font.GothamMedium, nil, 60)
		-- photo machine (user photo "Pick"): its front face stays just behind
		-- the photo camera point so it never shows in the shots
		local camProp = m:FindFirstChild("CameraProp")
		if camProp and camProp:IsA("BasePart") then
			camProp:SetAttribute("OrigTransparency", camProp.Transparency)
			camProp.Transparency = 1
		end
		local lensY = cam.Position.Y
		local fx = cam.Position.X - 0.1 -- front face
		local K = Instance.new("Model")
		K.Name = "PhotoMachine"
		K.Parent = B
		local D = 2
		local function kbox(name, y0, y1, w, color, depth, mat)
			return part(name, Vector3.new(depth or D, y1 - y0, w), CFrame.new(fx - (depth or D) / 2, (y0 + y1) / 2, bz), color, { parent = K, material = mat })
		end
		local RED, KWHITE = Color3.fromRGB(196, 54, 58), Color3.fromRGB(242, 242, 244)
		local baseTop = lensY - 2.2
		local base = kbox("MachineBase", F, baseTop, 4.6, RED)
		kbox("MachineLedge", baseTop, baseTop + 0.25, 4.8, KWHITE, D + 0.2)
		local body = kbox("MachineBody", baseTop + 0.25, lensY + 1.3, 4.6, KWHITE)
		kbox("MachineHood", lensY + 1.3, lensY + 2.4, 4.6, Color3.fromRGB(230, 230, 232))
		local band = kbox("MachineBand", lensY + 2.4, lensY + 3, 4.8, RED, D + 0.1)
		txt(band, Enum.NormalId.Right, "OHU", Color3.fromRGB(255, 225, 200), Enum.Font.FredokaOne, nil, 50)
		-- light panel under the band, two light bars, screen, lens
		part("MachineLight", Vector3.new(0.1, 0.9, 4), CFrame.new(fx + 0.02, lensY + 1.85, bz), Color3.fromRGB(225, 238, 255), { parent = K, material = Enum.Material.Neon, nocol = true })
		for _, s in ipairs({ -1, 1 }) do
			part("MachineBar", Vector3.new(0.1, 2.4, 0.45), CFrame.new(fx + 0.02, lensY - 0.4, bz + s * 1.95), Color3.fromRGB(225, 238, 255), { parent = K, material = Enum.Material.Neon, nocol = true })
		end
		local screen = part("MachineScreen", Vector3.new(0.05, 1.1, 2.6), CFrame.new(fx + 0.01, lensY - 1.1, bz), Color3.fromRGB(250, 240, 245), { parent = K, nocol = true })
		txt(screen, Enum.NormalId.Right, "OHU4cuts  ×  FRAME", Color3.fromRGB(200, 70, 110), Enum.Font.GothamBold, Color3.fromRGB(255, 236, 244), 60)
		part("MachineLens", Vector3.new(0.05, 0.75, 0.75), CFrame.new(fx + 0.01, lensY, bz), Color3.fromRGB(15, 15, 18), { parent = K, nocol = true, shape = Enum.PartType.Cylinder })
		local look = part("MachineLook", Vector3.new(0.05, 0.4, 3.4), CFrame.new(fx + 0.01, lensY, bz), KWHITE, { parent = K, nocol = true, transparency = 1 })
		txt(look, Enum.NormalId.Right, "LOOK       HERE", Color3.fromRGB(200, 50, 50), Enum.Font.GothamBold, nil, 60)
		local slot = part("CardSlot", Vector3.new(0.05, 0.5, 0.9), CFrame.new(fx + 0.01, baseTop - 0.7, bz - 0.6), Color3.fromRGB(20, 20, 22), { parent = K, nocol = true })
		part("PhotoOutlet", Vector3.new(0.05, 0.6, 1.1), CFrame.new(fx + 0.01, baseTop - 1.3, bz + 1.1), Color3.fromRGB(205, 225, 255), { parent = K, material = Enum.Material.Neon, nocol = true })
		local _ = slot
		local _b = base
		local _c = body
	end

	-- between the arches: blue light boxes with neon tubes + pink posters
	if #booths >= 2 then
		local zMid = (booths[1].CameraPoint.Position.Z + booths[2].CameraPoint.Position.Z) / 2
		for _, b in ipairs({ { F + 9, F + 13.2, zMid - 3.2 }, { F + 2.5, F + 8, zMid - 3.2 } }) do
			local box3 = box("LightBox", FX - 1.2, b[1], b[3] - 2.4, FX, b[2], b[3] + 2.4, Color3.fromRGB(28, 60, 200), opt({ material = Enum.Material.Glass, transparency = 0.15 }))
			for k = -1, 1 do
				part("NeonTube", Vector3.new(0.2, b[2] - b[1] - 1, 0.2), CFrame.new(FX - 0.6, (b[1] + b[2]) / 2, b[3] + k * 1.2), Color3.fromRGB(80, 170, 255), opt({ material = Enum.Material.Neon, nocol = true }))
			end
			txt(box3, Enum.NormalId.Left, "OHU 4 CUT", Color3.fromRGB(110, 150, 255), Enum.Font.GothamMedium, nil, 40)
		end
		local notes = { "파우더룸\n이용방법", "예방수칙", "이용 시\n유의사항", "안내" }
		for i, s in ipairs(notes) do
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local zc, yc = zMid + 1.2 + col * 2.6, F + 10 - row * 3.4
			local poster = part("NoticePoster", Vector3.new(0.1, 3, 2.3), CFrame.new(FX - 0.06, yc, zc), Color3.fromRGB(248, 205, 214), opt({ nocol = true }))
			txt(poster, Enum.NormalId.Left, s, Color3.fromRGB(200, 70, 90), Enum.Font.GothamBold, nil, 50)
		end
	end

	-- west wall: two mint arch niches with wire shelves ("OHU 4 CUT PLAYGROUND")
	local inX = W0 + 1.1
	local wAlong, wOut = Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)
	local HAT = { Color3.fromRGB(240, 120, 150), Color3.fromRGB(250, 210, 80), Color3.fromRGB(120, 190, 120), Color3.fromRGB(220, 60, 60), Color3.fromRGB(160, 120, 90), Color3.fromRGB(250, 250, 250), Color3.fromRGB(120, 160, 230) }
	for idx, zc in ipairs({ -91, -81 }) do
		local panel = archPanel(Vector3.new(inX + 0.1, F, zc), wAlong, wOut, 8.6, 15, 0.2, MINT, B)
		local glow = Instance.new("SurfaceLight") glow.Face = Enum.NormalId.Back glow.Range = 6 glow.Brightness = 0.6 glow.Color = Color3.fromRGB(190, 255, 235) glow.Parent = panel
		local title = part("PlaygroundTitle", Vector3.new(0.05, 1.6, 5.4), CFrame.new(inX + 0.25, F + 12.6, zc), MINT, opt({ nocol = true, transparency = 1 }))
		txt(title, Enum.NormalId.Right, "OHU 4 CUT\nPLAYGROUND", Color3.fromRGB(40, 50, 55), Enum.Font.GothamMedium, nil, 50)
		-- white wire shelf, 5 levels, filled with hats / plush
		local x0, x1 = inX + 0.3, inX + 2.4
		for _, s in ipairs({ -1, 1 }) do
			for _, xx in ipairs({ x0 + 0.1, x1 - 0.1 }) do
				part("ShelfPost", Vector3.new(0.15, 10.4, 0.15), CFrame.new(xx, F + 5.2, zc + s * 3.1), Color3.new(1, 1, 1), opt({ material = Enum.Material.Metal }))
			end
		end
		for lv = 0, 4 do
			local y = F + 0.4 + lv * 2.4
			box("ShelfBoard", x0, y, zc - 3.2, x1, y + 0.12, zc + 3.2, Color3.new(1, 1, 1), opt({ material = Enum.Material.Metal }))
			for k = 0, 3 do
				local c = HAT[((idx * 3 + lv * 2 + k) % #HAT) + 1]
				local p = Vector3.new((x0 + x1) / 2, y + 0.75, zc - 2.3 + k * 1.55)
				part("Plush", Vector3.new(1.5, 1.2, 1.3), CFrame.new(p) * CFrame.Angles(0, math.rad((k * 37 + lv * 11) % 60 - 30), 0), c, opt({ shape = Enum.PartType.Ball, material = Enum.Material.Fabric, nocol = true }))
				if (k + lv) % 2 == 0 then part("PlushEar", Vector3.new(0.5, 0.5, 0.5), CFrame.new(p + Vector3.new(0, 0.65, 0.4)), c, opt({ shape = Enum.PartType.Ball, material = Enum.Material.Fabric, nocol = true })) end
			end
		end
	end
	-- accessory arch: pale pink back, mint neon edge, rows of headbands
	do
		local zc = -71
		local panel = archPanel(Vector3.new(inX + 0.1, F, zc), wAlong, wOut, 7, 13, 0.2, Color3.fromRGB(252, 236, 236), B)
		archRim(Vector3.new(inX + 0.15, F, zc), wAlong, wOut, 7.4, 13.2, 0.25, 0.3, Color3.fromRGB(150, 245, 220), B)
		for _, r in ipairs(B:GetChildren()) do
			if r.Name == "ArchRim" and r:IsA("BasePart") and math.abs(r.Position.Z - zc) < 4 and r.Position.X < inX + 1 then r.Material = Enum.Material.Neon end
		end
		local title = part("AccessoryTitle", Vector3.new(0.05, 1, 4.4), CFrame.new(inX + 0.25, F + 10.8, zc), Color3.new(1, 1, 1), opt({ nocol = true, transparency = 1 }))
		txt(title, Enum.NormalId.Right, "Accessory", Color3.fromRGB(220, 60, 80), Enum.Font.IndieFlower, nil, 60)
		for row = 0, 3 do
			local y = F + 8.8 - row * 2.1
			box("HookBar", inX + 0.2, y, zc - 2.8, inX + 0.35, y + 0.12, zc + 2.8, Color3.fromRGB(200, 200, 205), opt({ material = Enum.Material.Metal }))
			for k = 0, 6 do
				local c = HAT[((row * 2 + k) % #HAT) + 1]
				local p = Vector3.new(inX + 0.6, y - 0.6, zc - 2.5 + k * 0.83)
				part("Headband", Vector3.new(0.3, 1, 0.7), CFrame.new(p) * CFrame.Angles(math.rad((k * 23) % 30 - 15), 0, 0), c, opt({ material = Enum.Material.Fabric, nocol = true }))
				part("Pompom", Vector3.new(0.55, 0.55, 0.55), CFrame.new(p + Vector3.new(0.15, 0.5, 0)), HAT[((row + k * 3) % #HAT) + 1], opt({ shape = Enum.PartType.Ball, material = Enum.Material.Fabric, nocol = true }))
			end
		end
		local _ = panel
	end

	-- vanity: round bulb mirror on a yellow acrylic table, by the south wall
	do
		local vx, vz = 84.5, -50.2
		box("VanityTable", vx - 2.6, F, vz - 1.3, vx + 2.6, F + 3, vz + 1.3, Color3.fromRGB(255, 205, 40), opt({ material = Enum.Material.Glass, transparency = 0.35 }))
		vcyl("MirrorStand", Vector3.new(vx, F + 3, vz + 0.6), 0.3, 2.2, Color3.fromRGB(240, 240, 240), opt({ material = Enum.Material.Metal }))
		local mc = Vector3.new(vx, F + 7.4, vz + 0.6)
		part("MirrorRim", Vector3.new(0.4, 4.8, 4.8), CFrame.new(mc) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(248, 248, 248), opt({ shape = Enum.PartType.Cylinder }))
		local glass = part("Mirror", Vector3.new(0.42, 4.1, 4.1), CFrame.new(mc + Vector3.new(0, 0, -0.02)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 215, 225), opt({ shape = Enum.PartType.Cylinder, material = Enum.Material.Glass }))
		glass.Reflectance = 0.5
		for k = 0, 9 do
			local a = k / 10 * 2 * math.pi
			part("MirrorBulb", Vector3.new(0.5, 0.5, 0.5), CFrame.new(mc + Vector3.new(math.cos(a) * 2.6, math.sin(a) * 2.6, -0.3)), Color3.fromRGB(255, 240, 200), opt({ shape = Enum.PartType.Ball, material = Enum.Material.Neon, nocol = true }))
		end
	end
	label(box("ShopLabel", 78, U1 + 10, -74, 80, U1 + 11, -72, WHITE, opt({ transparency = 1, nocol = true })), "📸 오후네컷 포토 부스", Color3.fromRGB(255, 160, 200), 3)
end

-- first spawn: in front of exit 1 (players come up facing north)
if spawn then
	if not spawn:GetAttribute("OldPosition") then spawn:SetAttribute("OldPosition", spawn.Position) end
	local p = exitMouths[1] + Vector3.new(0, 0, -7)
	spawn.CFrame = CFrame.lookAt(Vector3.new(p.X, CURB + 0.5, p.Z), Vector3.new(p.X, CURB + 0.5, p.Z - 10))
end
saveRegistry()
T.Parent = workspace
return "applied v7 (강남 사거리, 광안리, 광화문, 놀이공원 정문), MODE=revert to undo"
