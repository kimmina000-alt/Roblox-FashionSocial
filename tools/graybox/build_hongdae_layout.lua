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
local CLUB_DZ = -6
local MOVES = {
	["02_Club"] = CFrame.new(0, 0, CLUB_DZ) * CFrame.new(109, 0, -172) * R(-90) * CFrame.new(0, 0, 210), -- entrance faces west (club street)
	["03_Rooftop_Backstage"] = CFrame.new(0, 0, CLUB_DZ) * CFrame.new(109, 0, -366) * R(180) * CFrame.new(-125, 0, 160), -- runway behind the club
	["07_Hanok_Village"] = CFrame.new(0, 0, 12) * CFrame.new(161, 0, 126) * R(-90) * CFrame.new(-175, 0, -230), -- main gate east, back gate west (광화문)
	["08_PhotoBooth"] = CFrame.new(0, 0, -12) * CFrame.new(-126, 0, 51), -- 인생네컷 below the club
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
local function planter(pos: Vector3, along: Vector3, len: number?)
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
	local tree = foliage("StreetTree", 0.85, cf * CFrame.new(0, soilTop, 0) * CFrame.Angles(0, plantN * 1.7, 0))
	if tree then
		for _, p in ipairs(tree:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Part" and p.Size.Y < 1.5 then p:Destroy() end
		end
		prop(tree, "Tree")
	end
	-- only this shrub (user 2026-10-22), larger, two on each side of the tree in
	-- a row, each turned a little differently
	for k, z in ipairs({ -5.4, -2.8, 2.8, 5.4 }) do
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

local CAR_COLORS = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(25, 25, 30), Color3.fromRGB(150, 155, 160), Color3.fromRGB(40, 60, 110), Color3.fromRGB(160, 30, 35) }
local carCount = 0
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
local function bigRoad(dir: Vector3, len: number, pits, cars, outer)
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
	local STOP = 43 -- stop line 6 behind the crosswalk (2–5 m rule)
	local function solid(name, v, u0, u1, col, w)
		uv(name, u0, v - (w or 0.4) / 2, u1, v + (w or 0.4) / 2, 0.12, 0.16, col, { nocol = true })
	end
	local function dashed(name, v, u0, u1, col)
		for u = u0, u1 - 6, 12 do solid(name, v, u, u + 6, col) end
	end
	-- double yellow centre line, starting after the safety zone taper
	solid("CenterLine", -0.45, 66, len, YELLOW) solid("CenterLine", 0.45, 66, len, YELLOW)
	-- blue bus lane lines (median bus lanes)
	solid("BusLane", -8, STOP, len, BLUE) solid("BusLane", 8, CW1 + 1, len, BLUE)
	-- lane line: solid 진로변경제한선 for 40 studs (≈ 14 m, rule: within 50 m)
	-- before the stop line on the incoming side, dashed further out
	solid("LaneSolid", -16, STOP, STOP + 40, WHITE)
	dashed("LaneDash", -16, STOP + 46, len, WHITE)
	dashed("LaneDash", 16, CW1 + 3, len, WHITE)
	-- zebra crosswalk across the whole road
	for v = -22.5, 22.5, 3 do uv("Crosswalk", CW0, v - 0.75, CW1, v + 0.75, 0.12, 0.16, WHITE, { nocol = true }) end
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
	for u = STOP + 2, 58, 2.2 do
		local a = at(u, 0) + Vector3.new(0, 0.15, 0)
		part("SafetyStripe", Vector3.new(0.35, 0.04, 3.9), CFrame.lookAt(a, a + dir + across), YELLOW, { nocol = true })
	end
	uv("SafetyEdge", STOP + 1.2, -1.8, 60, -1.4, 0.12, 0.16, YELLOW, { nocol = true }) uv("SafetyEdge", STOP + 1.2, 1.4, 60, 1.8, 0.12, 0.16, YELLOW, { nocol = true })
	uv("SafetyEdge", STOP + 1.2, -1.8, STOP + 1.6, 1.8, 0.12, 0.16, YELLOW, { nocol = true })
	for _, s in ipairs({ -1, 1 }) do
		local a, b = at(60, s * 1.6) + Vector3.new(0, 0.14, 0), at(66, s * 0.45) + Vector3.new(0, 0.14, 0)
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
	-- trees 4–8 m apart (here 17.3 ≈ 5.9 m), trunk ≥ 1 m from the curb (v 27),
	-- first tree 4 m past the crosswalk paint (u 49), ≥ 3 m from street lights
	-- and signals, none at bus stops (KEEP_CLEAR) or subway exits.
	local TREE_V, TREE_U0, TREE_STEP = 27, 49, 121 / 7
	for u = TREE_U0, len - 10, TREE_STEP do -- beds 15 long → a nearly continuous strip
		local free = true
		for _, p in ipairs(pits) do if u > p[1] - 9 and u < p[2] + 9 then free = false end end
		if free then for _, v in ipairs({ -TREE_V, TREE_V }) do if clear(at(u, v)) then planter(at(u, v), dir, 15) end end end
	end
	-- every other lamp (user: too many), in a gap between planting beds, so
	-- 8.6 (≈ 3 m) from the nearest trees
	for u = TREE_U0 + TREE_STEP / 2, len - 6, TREE_STEP * 4 do
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
				-- right against the planting beds (user 2026-10-22: no gap)
				local a, b = at(u0, side * 29.2), at(u1, side * 33.2)
				box("BikeLane", a.X, CURB, a.Z, b.X, CURB + 0.03, b.Z, Color3.fromRGB(62, 63, 66), { material = Enum.Material.Asphalt, nocol = true })
				for _, ev in ipairs({ 29.35, 33.05 }) do
					local c, d = at(u0, side * (ev - 0.15)), at(u1, side * (ev + 0.15))
					box("BikeLaneEdge", c.X, CURB + 0.03, c.Z, d.X, CURB + 0.05, d.Z, WHITE, { nocol = true })
				end
				for u = u0 + 8, u1 - 6, 32 do
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
			if runStart then lane(runStart, len - 4) end
		end
	end
	trafficLight(at(38, 30) + Vector3.new(0, CURB, 0), -across, 26)
	-- right-hand traffic: -v side drives toward the junction (-dir)
	for _, c in ipairs(cars) do car(at(c[1], c[2]), if c[2] < 0 then -dir else dir) end
end
-- north road: west side stays narrow along the park's red box; east side
-- reaches the club / photo booth fronts (49)
bigRoad(Vector3.new(0, 0, -1), 470, { { 50, 68, 26, 32 }, { 50, 68, -32, -26 } }, { { 48, 12 }, { 66, 20 } }, { [-1] = 34, [1] = 49 }) -- north
bigRoad(Vector3.new(0, 0, 1), 640, { { 50, 68, 26, 32 }, { 50, 68, -32, -26 } }, { { 48, 20 }, { 120, -12 } }) -- south (past the boundary at 299: the street goes on, D-110)
bigRoad(Vector3.new(1, 0, 0), 260, {}, { { 46, 12 }, { 64, 12 }, { 90, -20 } }) -- east
bigRoad(Vector3.new(-1, 0, 0), 158, {}, { { 48, 20 }, { 80, -12 } }) -- west, to the seafront road

local function smallRoad(a: Vector2, b: Vector2)
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
	for u = 4, len - 6, 10 do bx("LaneDash", u, -0.15, u + 5, 0.15, 0.12, 0.16, WHITE, { nocol = true }) end
end
smallRoad(Vector2.new(181, -34), Vector2.new(181, -470)) -- east of the club
smallRoad(Vector2.new(-34, 98), Vector2.new(-150, 98)) -- south-west, to the seafront
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
		for zs = z0, z1 - 1, 20 do
			local ze = math.min(zs + 20, z1)
			local free = true
			local probe = CFrame.new(-201, (sandTop + CURB) / 2 + 0.2, (zs + ze) / 2)
			for _, p in ipairs(workspace:GetPartBoundsInBox(probe, Vector3.new(6, CURB - sandTop - 0.6, ze - zs - 1), params)) do
				if p.Name ~= "Beach" and p.Name ~= "Ground" and p.Transparency < 1 then free = false break end
			end
			if free then
				box("BeachStepEdge", -198.7, sandTop, zs, -198, CURB + 0.1, ze, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
				-- three wooden steps (user 2026-10-22)
				box("BeachStep", -201.2, sandTop, zs, -198.7, CURB - 0.6, ze, wood, { material = Enum.Material.WoodPlanks })
				box("BeachStep", -203.7, sandTop, zs, -201.2, CURB - 1.2, ze, wood, { material = Enum.Material.WoodPlanks })
				box("BeachStep", -206.2, sandTop, zs, -203.7, CURB - 1.8, ze, wood, { material = Enum.Material.WoodPlanks })
			end
		end
	end
	box("SeaRoad", -182, 0, z0, -158, 0.12, z1, ASPHALT, { material = Enum.Material.Asphalt })
	for _, seg in ipairs({ { z0, -24 }, { 24, z1 } }) do -- lane paint stops at the junction with the west road
		paint("RedLane", -182, seg[1], -174, seg[2], Color3.fromRGB(190, 85, 75))
		paint("EdgeLine", -174.2, seg[1], -173.8, seg[2], WHITE)
		paint("CenterLine", -166.5, seg[1], -166.1, seg[2], YELLOW) paint("CenterLine", -165.9, seg[1], -165.5, seg[2], YELLOW)
	end
	walk(-158, z0, -150, -34) walk(-158, 34, -150, z1)
	for _, cz in ipairs({ -400, -250, -100, 60, 180, 260 }) do
		for x = -181, -159, 3 do paint("Crosswalk", x, cz - 4, x + 1.5, cz + 4, WHITE) end
	end
	for zz = z0 + 6, z1 - 6, 18 do -- drains along both curbs
		for _, x in ipairs({ -181.4, -158.6 }) do
			box("Drain", x - 0.6, 0.12, zz, x + 0.6, 0.15, zz + 2.4, Color3.fromRGB(35, 35, 38), { nocol = true })
			for k = 0, 3 do box("DrainBar", x - 0.6, 0.15, zz + 0.3 + k * 0.6, x + 0.6, 0.17, zz + 0.45 + k * 0.6, Color3.fromRGB(90, 90, 95), { nocol = true }) end
		end
	end
	-- each bollard can be moved / deleted by hand (user 2026-10-22, D-105)
	for zz = z0 + 4, z1 - 2, 7 do prop(vcyl("Bollard", Vector3.new(-183.5, CURB, zz), 1.1, 1.6, Color3.fromRGB(150, 145, 140), { material = Enum.Material.Slate }), "Bollard") end
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
				local p = foliage("PalmTreeReal", 0.5 + (math.floor(foot.Z) % 3) * 0.05, CFrame.new(foot) * CFrame.Angles(0, math.rad((math.floor(foot.X * 7 + foot.Z) % 360)), 0))
				if p then prop(p, "Palm") end
			end
		end
	end
	-- realistic fan palms (광안리 photo, user 2026-10-22) instead of the round
	-- pines; each one can be moved / deleted by hand
	for zz = z0 + 14, z1 - 10, 30 do
		if math.abs(zz - 61) > 8 then
			local base = Vector3.new(-190, CURB, zz)
			box("PalmBed", base.X - 2.2, CURB, zz - 2.2, base.X + 2.2, CURB + 0.25, zz + 2.2, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
			local p = foliage("PalmTreeReal", 0.55 + (zz % 3) * 0.04, CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad((zz * 37) % 360), 0))
			if p then prop(p, "Palm") end
		end
	end
	for zz = z0 + 10, z1, 80 do streetLamp(Vector3.new(-196.5, CURB, zz), Vector3.new(1, 0, 0)) end
	for zz = z0 + 28, z1, 60 do
		box("BenchBase", -197.5, CURB, zz, -195.5, CURB + 1.6, zz + 6, Color3.fromRGB(110, 110, 115))
		seat("PromenadeBench", CFrame.lookAt(Vector3.new(-196.5, CURB + 1.8, zz + 3), Vector3.new(-260, CURB + 1.8, zz + 3)), Vector3.new(2, 0.4, 6), Color3.fromRGB(160, 110, 70))
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
	-- main gate: a row of 5 arches with a blue mansard roof and towers
	local gz0, gz1 = z1 - 2, z1 + 6
	local n = 5
	local w = (gateX1 - gateX0) / n
	for i = 0, n do box("GatePier", gateX0 + i * w - 1.5, 0, gz0, gateX0 + i * w + 1.5, 16, gz1, cream, { parent = E }) end
	for i = 0, n - 1 do
		local ax = gateX0 + i * w
		box("ArchTop", ax + 1.5, 10, gz0, ax + w - 1.5, 16, gz1, cream, { parent = E })
		box("ArchTrim", ax + 1.5, 9.4, gz1, ax + w - 1.5, 10, gz1 + 0.3, blue, { parent = E })
		box("ArchWindow", ax + w / 2 - 1.5, 11.5, gz1, ax + w / 2 + 1.5, 14.5, gz1 + 0.2, Color3.fromRGB(120, 150, 190), { parent = E })
	end
	part("GateRoof", Vector3.new(gateX1 - gateX0 + 4, 4, 5), CFrame.new((gateX0 + gateX1) / 2, 18, gz0 + 2) * CFrame.Angles(0, math.rad(180), 0), roofBlue, { parent = E, class = "WedgePart" })
	box("GateCornice", gateX0 - 2, 16, gz0 - 0.5, gateX1 + 2, 16.6, gz1 + 0.5, Color3.fromRGB(230, 220, 195), { parent = E })
	turret(gateX0 - 4, (gz0 + gz1) / 2, 7, 22) turret(gateX1 + 4, (gz0 + gz1) / 2, 7, 22)
	turret((gateX0 + gateX1) / 2, (gz0 + gz1) / 2, 7, 24, 16) -- centre tower on the gate roof (middle arch stays open)
	local sign = box("GateSign", -107, 17, gz1 + 0.6, -79, 21, gz1 + 1, Color3.fromRGB(255, 250, 235), { parent = E })
	surfaceText(sign, Enum.NormalId.Back, "OHU LAND", Color3.fromRGB(60, 90, 140), Enum.Font.FredokaOne)
	label(sign, "놀이공원 정문", Color3.fromRGB(60, 90, 140), 8, 0.9)
	local function booth(bx0, bz0, bx1, bz1, title, windows)
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
	-- (the purple club street is sidewalk now, v7c)
	box("FacadePanel", 48.2, 13, -205 + CLUB_DZ, 48.9, 34, -139 + CLUB_DZ, Color3.fromRGB(28, 28, 34), { parent = K, material = Enum.Material.DiamondPlate })
	local sign = box("ClubSign", 47.6, 20, -196 + CLUB_DZ, 48.2, 30, -148 + CLUB_DZ, Color3.fromRGB(15, 15, 25), { parent = K })
	surfaceText(sign, Enum.NormalId.Left, "OHU CLUB", Color3.fromRGB(90, 160, 255), Enum.Font.Michroma)
	local glow = Instance.new("SurfaceLight") glow.Face = Enum.NormalId.Left glow.Color = Color3.fromRGB(80, 140, 255) glow.Range = 20 glow.Brightness = 2 glow.Parent = sign
	for _, zz in ipairs({ -205 + CLUB_DZ, -139 + CLUB_DZ }) do box("NeonEdge", 47.8, 0.2, zz - 0.3, 48.4, 34, zz + 0.3, Color3.fromRGB(40, 80, 255), { parent = K, material = Enum.Material.Neon }) end
	for _, zz in ipairs({ -182 + CLUB_DZ, -162 + CLUB_DZ }) do box("DoorFrameGold", 47.8, 0.2, zz - 0.4, 48.6, 12, zz + 0.4, Color3.fromRGB(230, 180, 80), { parent = K, material = Enum.Material.Neon }) end
	box("DoorLintelGold", 47.8, 12, -182.4 + CLUB_DZ, 48.6, 12.8, -161.6 + CLUB_DZ, Color3.fromRGB(230, 180, 80), { parent = K, material = Enum.Material.Neon })
	for _, x in ipairs({ 39, 45 }) do
		local last: Vector3? = nil
		for zz = -150 + CLUB_DZ, -112 + CLUB_DZ, 6 do
			local top = Vector3.new(x, CURB + 3.1, zz)
			vcyl("Stanchion", Vector3.new(x, CURB, zz), 0.4, 3, Color3.fromRGB(200, 170, 80), { parent = K })
			if last then part("Rope", Vector3.new(0.25, 0.25, (top - last).Magnitude), CFrame.lookAt((top + last) / 2 - Vector3.new(0, 0.3, 0), top - Vector3.new(0, 0.3, 0)), Color3.fromRGB(180, 20, 30), { parent = K, nocol = true }) end
			last = top
		end
	end
	for _, c in ipairs({ { 37.5, -110 }, { 47.5, -110 }, { 37.5, -100 }, { 47.5, -100 } }) do vcyl("TentLeg", Vector3.new(c[1], CURB, c[2]), 0.3, 8, Color3.fromRGB(230, 230, 235), { parent = K }) end
	box("TentRoof", 37, 8.5, -111, 48, 8.9, -99, Color3.fromRGB(245, 245, 250), { parent = K, nocol = true })
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
tower(-146, 48, -126, 92, 60, "concrete", "N", "노래방")

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
	local x0, z0, x1, z1, title = 48, 48, 86, 78, "소품샵 예정"
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

do -- convenience store with automatic sliding doors (front = north, to the west road)
	local x0, z0, x1, z1, H = -120, 48, -80, 80, 14
	local S = Instance.new("Model")
	S.Name = "ConvenienceStore"
	S.Parent = T
	local wallC = Color3.fromRGB(240, 240, 238)
	walk(x0, WIDE, x1, z0)
	box("StoreFloor", x0, 0, z0, x1, CURB, z1, Color3.fromRGB(235, 235, 235), { parent = S, material = Enum.Material.Marble })
	box("WallBack", x0, CURB, z1 - 0.6, x1, H, z1, wallC, { parent = S })
	box("WallW", x0, CURB, z0, x0 + 0.6, H, z1, wallC, { parent = S })
	box("WallE", x1 - 0.6, CURB, z0, x1, H, z1, wallC, { parent = S })
	box("Roof", x0 - 0.5, H, z0 - 1, x1 + 0.5, H + 1, z1 + 0.5, Color3.fromRGB(70, 70, 75), { parent = S })
	local mid = (x0 + x1) / 2
	box("FrontGlass", x0, CURB, z0, mid - 4, H - 3, z0 + 0.4, Color3.fromRGB(200, 230, 240), { parent = S, material = Enum.Material.Glass, transparency = 0.5 })
	box("FrontGlass", mid + 4, CURB, z0, x1, H - 3, z0 + 0.4, Color3.fromRGB(200, 230, 240), { parent = S, material = Enum.Material.Glass, transparency = 0.5 })
	box("DoorHeader", x0, H - 3, z0, x1, H, z0 + 0.4, Color3.fromRGB(70, 70, 75), { parent = S })
	local sign = box("StoreSign", x0, H - 2.6, z0 - 0.6, x1, H - 0.4, z0, Color3.fromRGB(30, 110, 205), { parent = S, material = Enum.Material.Neon })
	surfaceText(sign, Enum.NormalId.Front, "OHU 24 편의점", Color3.new(1, 1, 1))
	box("StoreSignStripe", x0, H - 3.2, z0 - 0.7, x1, H - 2.6, z0, Color3.fromRGB(255, 255, 255), { parent = S, material = Enum.Material.Neon })
	for k = 0, 5 do box("Shutter", x0 + 0.6, H - 3.2 - k * 0.8, z0 - 0.35, mid - 5, H - 2.5 - k * 0.8, z0 - 0.05, Color3.fromRGB(150 + (k % 2) * 20, 152 + (k % 2) * 20, 158 + (k % 2) * 20), { parent = S }) end
	for _, px in ipairs({ x0 + 6, x1 - 10 }) do
		box("PicnicTable", px, CURB + 2.8, 37, px + 6, CURB + 3.1, 41, Color3.fromRGB(70, 50, 40), { parent = S })
		box("PicnicLeg", px + 2.8, CURB, 38, px + 3.2, CURB + 2.8, 40, Color3.fromRGB(40, 40, 40), { parent = S })
		for _, bz in ipairs({ 35.6, 42.4 }) do seat("PicnicBench", CFrame.lookAt(Vector3.new(px + 3, CURB + 1.7, bz), Vector3.new(px + 3, CURB + 1.7, 39)), Vector3.new(6, 0.4, 1.4), Color3.fromRGB(70, 50, 40), S) end
	end
	local door = Instance.new("Model")
	door.Name = "AutoDoor"
	door:SetAttribute("Range", 9)
	for _, s in ipairs({ -1, 1 }) do
		local panel = box("DoorPanel", mid + s * 4, CURB, z0 + 0.05, mid, H - 3, z0 + 0.35, Color3.fromRGB(190, 225, 240), { parent = door, material = Enum.Material.Glass, transparency = 0.45 })
		panel:SetAttribute("Slide", Vector3.new(s * 3.8, 0, 0))
		box("DoorFrame", mid + s * 4 - 0.15, CURB, z0, mid + s * 4 + 0.15, H - 3, z0 + 0.4, Color3.fromRGB(150, 150, 155), { parent = S })
	end
	door.WorldPivot = CFrame.new(mid, CURB + 4, z0)
	door.Parent = S
	CS:AddTag(door, "AutoDoor")
	box("Counter", x1 - 12, CURB, z0 + 3, x1 - 2, CURB + 3.6, z0 + 6, Color3.fromRGB(250, 250, 250), { parent = S })
	box("CounterTop", x1 - 12.3, CURB + 3.6, z0 + 2.7, x1 - 1.7, CURB + 3.9, z0 + 6.3, Color3.fromRGB(30, 110, 205), { parent = S })
	box("Register", x1 - 6, CURB + 3.9, z0 + 4, x1 - 4, CURB + 5.3, z0 + 5.5, Color3.fromRGB(40, 40, 45), { parent = S })
	box("CardKeypad", x1 - 9, CURB + 3.9, z0 + 3.2, x1 - 7.6, CURB + 4.2, z0 + 4.4, Color3.fromRGB(225, 225, 230), { parent = S })
	box("CigaretteShelfBack", x1 - 12, CURB, z0 + 9, x1 - 2, CURB + 8, z0 + 10, Color3.fromRGB(220, 220, 225), { parent = S })
	for i = 0, 2 do
		local sx = x0 + 6 + i * 8
		box("Shelf", sx, CURB, z0 + 10, sx + 2.5, CURB + 5.5, z1 - 8, Color3.fromRGB(230, 230, 232), { parent = S })
		for k = 1, 3 do box("Goods", sx - 0.3, CURB + k * 1.6, z0 + 10.5, sx + 2.8, CURB + k * 1.6 + 1, z1 - 8.5, SIGNS[((i + k) % #SIGNS) + 1], { parent = S }) end
	end
	box("Fridge", x0 + 2, CURB, z1 - 3.5, x1 - 2, CURB + 9, z1 - 0.6, Color3.fromRGB(170, 215, 235), { parent = S, material = Enum.Material.Glass, transparency = 0.25 })
	for fx = x0 + 2, x1 - 2, 4 do box("FridgeFrame", fx - 0.2, CURB, z1 - 3.7, fx + 0.2, CURB + 9, z1 - 3.4, Color3.fromRGB(120, 125, 135), { parent = S }) end
	local fl = box("FridgeLight", x0 + 2, CURB + 9, z1 - 3.6, x1 - 2, CURB + 9.4, z1 - 0.6, Color3.fromRGB(240, 250, 255), { parent = S, material = Enum.Material.Neon })
	local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 10 sl.Brightness = 1.2 sl.Parent = fl
	local ceil = box("CeilingLight", x0 + 4, H - 0.4, z0 + 4, x1 - 4, H - 0.2, z1 - 4, Color3.fromRGB(250, 252, 255), { parent = S, material = Enum.Material.Neon })
	local cl = Instance.new("SurfaceLight") cl.Face = Enum.NormalId.Bottom cl.Range = 16 cl.Brightness = 1 cl.Parent = ceil
	label(sign, "편의점", Color3.fromRGB(30, 110, 205), 4, 0.7)
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
	-- next to the club, along the north road (hides the future runway lot)
	for i, zz in ipairs({ -285, -320, -355, -410, -446 }) do
		fakeBuilding(Vector3.new(67, 0, zz), 34, 16, hgt[(i + 3) % #hgt + 1], Vector3.new(-1, 0, 0))
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
		for zz = seg[1] + 15, seg[2] - 10, 30 do
			foliage("PalmTreeReal", 0.55, CFrame.new(-190, CURB + 0.2, zz) * CFrame.Angles(0, math.rad((zz * 37) % 360), 0))
		end
	end
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
