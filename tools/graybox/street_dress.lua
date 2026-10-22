-- Street dressing with real Creator Store assets (user 2026-10-22, D-103):
-- "창문이 있는 건물 외벽, 도로, 한국식 신호등, 가로등, 버스 정류장 ... 현실적인
-- 에셋 찾아서 적용 / 인도 블록이랑 차도 디자인 다름 / 인도 꺾이는 부분 라운드 /
-- 전봇대도 넣어".
-- Run in Edit mode AFTER tools/graybox/hongdae_v1_temp.lua (it dresses
-- Workspace.Hongdae_v1_Temp). MODE: "apply" (default) / "revert".
-- Assets live in ServerStorage.ArtAssets (inserted 2026-10-22, every script
-- removed; ids in docs/04_ART/REFERENCES.md). Nothing is deleted: replaced
-- blockout parts are made invisible (attributes DressOrig*), new things go into
-- Workspace.StreetDress.

local MODE = ... or "apply"

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local A = SS:WaitForChild("ArtAssets")
local temp = workspace:FindFirstChild("Hongdae_v1_Temp")
local DRESS = "StreetDress"

local IMG = {
	sidewalk = "rbxassetid://133933193561069", -- grey rectangular pavers in a grid (user photo 2026-10-22, not herringbone)
	glassTeal = "rbxassetid://13654404035", -- curtain wall (강남 towers)
	glassBlue = "rbxassetid://11361294440",
	concreteGrid = "rbxassetid://17593427084",
	officeBand = "rbxassetid://14844635151",
	officeBlue = "rbxassetid://36951684",
}

---------------------------------------------------------------- revert
local function revert()
	for _, p in ipairs(workspace:GetDescendants()) do
		if p.Name == "DressTex" and p:IsA("Texture") then
			p:Destroy()
		elseif p:GetAttribute("DressOrigOn") ~= nil and not p:IsA("BasePart") then
			local v = p:GetAttribute("DressOrigOn")
			if p:IsA("Decal") then (p :: any).Transparency = v else (p :: any).Enabled = v end
			p:SetAttribute("DressOrigOn", nil)
		elseif p:IsA("BasePart") and p:GetAttribute("DressOrigT") ~= nil then
			p.Transparency = p:GetAttribute("DressOrigT")
			p.CanCollide = p:GetAttribute("DressOrigC")
			p.CanQuery = p:GetAttribute("DressOrigQ")
			if p:GetAttribute("DressOrigMat") then
				p.Material = Enum.Material[p:GetAttribute("DressOrigMat")]
				p.MaterialVariant = p:GetAttribute("DressOrigMV") or ""
				p.Color = p:GetAttribute("DressOrigColor")
			end
			for _, k in ipairs({ "DressOrigT", "DressOrigC", "DressOrigQ", "DressOrigMat", "DressOrigMV", "DressOrigColor" }) do p:SetAttribute(k, nil) end
		end
	end
	local old = workspace:FindFirstChild(DRESS)
	if old then old:Destroy() end
end

revert()
if MODE == "revert" then return "street dressing removed" end
assert(temp, "run hongdae_v1_temp.lua first")

---------------------------------------------------------------- helpers
-- Folders, not Models: one click in Studio selects one light / pole (D-105)
local root = Instance.new("Folder")
root.Name = DRESS
local function folder(name: string): Folder
	local m = Instance.new("Folder")
	m.Name = name
	m.Parent = root
	return m
end

-- hand edits that survive a re-run (same scheme as hongdae_v1_temp.lua, D-105)
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
for id, owner in pairs(REGISTRY) do if owner == "dress" then REGISTRY[id] = nil end end
local usedIds: {[string]: boolean} = {}
local function prop(inst: Model, kind: string): boolean
	local cf = inst:GetPivot()
	local id = string.format("%s@%d,%d", kind, math.floor(cf.X + 0.5), math.floor(cf.Z + 0.5))
	while usedIds[id] do id ..= "+" end
	usedIds[id] = true
	REGISTRY[id] = "dress"
	inst:SetAttribute("PropId", id)
	inst:SetAttribute("PropBase", cf)
	local o = OVERRIDES[id]
	if o == "delete" then
		inst:Destroy()
		return false
	elseif typeof(o) == "table" and #o == 12 then
		inst:PivotTo(CFrame.new(table.unpack(o)))
	end
	return true
end

local function remember(p: BasePart)
	if p:GetAttribute("DressOrigT") == nil then
		p:SetAttribute("DressOrigT", p.Transparency)
		p:SetAttribute("DressOrigC", p.CanCollide)
		p:SetAttribute("DressOrigQ", p.CanQuery)
	end
end
local function hide(p: BasePart)
	remember(p)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	-- signs and lights on a hidden part go dark too
	for _, d in ipairs(p:GetDescendants()) do
		if d:GetAttribute("DressOrigOn") == nil then
			if d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") then
				d:SetAttribute("DressOrigOn", d.Enabled)
				d.Enabled = false
			elseif d:IsA("Decal") then
				d:SetAttribute("DressOrigOn", d.Transparency)
				d.Transparency = 1
			end
		end
	end
end
local function restyle(p: BasePart, color: Color3, material: Enum.Material, variant: string?)
	remember(p)
	if p:GetAttribute("DressOrigMat") == nil then
		p:SetAttribute("DressOrigMat", p.Material.Name)
		p:SetAttribute("DressOrigMV", p.MaterialVariant)
		p:SetAttribute("DressOrigColor", p.Color)
	end
	p.Color = color
	p.Material = material
	p.MaterialVariant = variant or ""
end
local function texture(p: BasePart, id: string, faces: {Enum.NormalId}, u: number, v: number, color: Color3?)
	for _, f in ipairs(faces) do
		local t = Instance.new("Texture")
		t.Name = "DressTex"
		t.Texture = id
		t.Face = f
		t.StudsPerTileU = u
		t.StudsPerTileV = v
		if color then t.Color3 = color end
		t.Parent = p
	end
end
local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end
-- vertical extent of a (possibly rotated) part
local function vertical(p: BasePart): number
	local c = p.CFrame
	return math.abs(c.RightVector.Y) * p.Size.X + math.abs(c.UpVector.Y) * p.Size.Y + math.abs(c.LookVector.Y) * p.Size.Z
end
local function tallest(m: Instance): BasePart?
	local best, h = nil, -1
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and vertical(p) > h then best, h = p, vertical(p) end
	end
	return best
end
-- place a copy so that (refBase, refDir) of the source lands on (base, dir)
local function placeCopy(src: Model, refBase: Vector3, refDir: Vector3, base: Vector3, dir: Vector3, parent: Instance): Model
	local m = src:Clone()
	local from = CFrame.lookAt(refBase, refBase + flat(refDir))
	local to = CFrame.lookAt(base, base + flat(dir))
	m:PivotTo(to * from:Inverse() * m:GetPivot())
	m.Parent = parent
	return m
end

-- is a point (XZ) on a road?
local roads = {}
for _, p in ipairs(temp:GetChildren()) do
	if p:IsA("BasePart") and (p.Name == "Road" or p.Name == "IntersectionRoad") then table.insert(roads, p) end
end
local function onRoad(pt: Vector3): boolean
	for _, r in ipairs(roads) do
		local l = r.CFrame:PointToObjectSpace(Vector3.new(pt.X, r.Position.Y, pt.Z))
		if math.abs(l.X) <= r.Size.X / 2 and math.abs(l.Z) <= r.Size.Z / 2 then return true end
	end
	return false
end

---------------------------------------------------------------- 1. road: real asphalt (MaterialVariant)
local function variant(srcName: string, newName: string): string
	if not MS:FindFirstChild(newName) then
		local v = A.AsphaltVariant[srcName]:Clone()
		v.Name = newName
		v.Parent = MS
	end
	return newName
end
local ASPHALT = variant("MaterialVariant2", "OHU_Asphalt")
local CONCRETE = variant("MaterialVariant1", "OHU_Concrete")
for _, r in ipairs(roads) do
	restyle(r, Color3.fromRGB(105, 106, 110), Enum.Material.Concrete, ASPHALT)
end
-- the bare city ground between sidewalks and buildings: concrete plaza
for _, g in ipairs(temp:GetChildren()) do
	if g:IsA("BasePart") and g.Name == "Ground" and g.Material == Enum.Material.Plastic then
		restyle(g, Color3.fromRGB(158, 156, 150), Enum.Material.Concrete, CONCRETE)
	end
end

---------------------------------------------------------------- 2. sidewalks: pavers, granite curbs, tactile line, round corners
local walkF = folder("Sidewalk")
local GRANITE = Color3.fromRGB(190, 188, 182)
local TACTILE = Color3.fromRGB(238, 194, 36)
local function paveLook(p: BasePart)
	restyle(p, Color3.fromRGB(176, 172, 166), Enum.Material.SmoothPlastic)
	texture(p, IMG.sidewalk, { Enum.NormalId.Top }, 7, 7)
end

local function roundCorner(s: BasePart)
	local top = s.Position.Y + s.Size.Y / 2
	local half = s.Size / 2
	for _, sx in ipairs({ 1, -1 }) do
		for _, sz in ipairs({ 1, -1 }) do
			local c = Vector3.new(s.Position.X + sx * half.X, top, s.Position.Z + sz * half.Z)
			-- the corner pointing at the junction: road beyond it diagonally AND on both sides
			if onRoad(c + Vector3.new(sx * 1.5, 0, sz * 1.5)) and onRoad(c + Vector3.new(sx * 1.5, 0, -sz * 1)) and onRoad(c + Vector3.new(-sx * 1, 0, sz * 1.5)) then
				hide(s)
				local r = math.min(8, math.min(s.Size.X, s.Size.Z) - 1)
				local ix, iz = -sx, -sz
				local h = s.Size.Y
				local y = s.Position.Y
				-- two rectangles + a disc = a square with one round corner
				local ax0, ax1 = c.X + ix * r, c.X + ix * s.Size.X
				local a = part("SidewalkRound", Vector3.new(math.abs(ax1 - ax0), h, s.Size.Z), CFrame.new((ax0 + ax1) / 2, y, s.Position.Z), s.Color, Enum.Material.SmoothPlastic, walkF)
				local bz0, bz1 = c.Z + iz * r, c.Z + iz * s.Size.Z
				local b = part("SidewalkRound", Vector3.new(r, h, math.abs(bz1 - bz0)), CFrame.new(c.X + ix * r / 2, y, (bz0 + bz1) / 2), s.Color, Enum.Material.SmoothPlastic, walkF)
				local center = Vector3.new(c.X + ix * r, y, c.Z + iz * r)
				local d = part("SidewalkRound", Vector3.new(h, r * 2, r * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), s.Color, Enum.Material.SmoothPlastic, walkF)
				d.Shape = Enum.PartType.Cylinder
				paveLook(a); paveLook(b)
				texture(d, IMG.sidewalk, { Enum.NormalId.Right }, 6, 6)
				-- granite curb along the arc (towards the road)
				local a0 = math.atan2(0, sx) -- direction +sx on X
				local a1 = math.atan2(sz, 0) -- direction +sz on Z
				if math.abs(a1 - a0) > math.pi then a1 += if a1 < a0 then 2 * math.pi else -2 * math.pi end
				local steps = 8
				for i = 0, steps - 1 do
					local t0 = a0 + (a1 - a0) * i / steps
					local t1 = a0 + (a1 - a0) * (i + 1) / steps
					local p0 = center + Vector3.new(math.cos(t0), 0, math.sin(t0)) * (r + 0.35)
					local p1 = center + Vector3.new(math.cos(t1), 0, math.sin(t1)) * (r + 0.35)
					local mid = (p0 + p1) / 2
					part("Curb", Vector3.new(0.7, h + 0.15, (p1 - p0).Magnitude + 0.15), CFrame.lookAt(mid, mid + (p1 - p0)) + Vector3.new(0, 0.075, 0), GRANITE, Enum.Material.Granite, walkF)
				end
				return
			end
		end
	end
end

for _, s in ipairs(temp:GetChildren()) do
	if s:IsA("BasePart") and s.Name == "Sidewalk" then
		local square = math.abs(s.Size.X - s.Size.Z) < 0.5 and s.Size.X <= 24 -- crossroads corners (23 wide since v7c)
		if square then
			paveLook(s)
			roundCorner(s)
		else
			paveLook(s)
			-- curb + tactile guide line on each long edge that touches a road
			local alongX = s.Size.X >= s.Size.Z
			local long = if alongX then s.Size.X else s.Size.Z
			local wide = if alongX then s.Size.Z else s.Size.X
			if long >= 8 then
				for _, side in ipairs({ 1, -1 }) do
					local edgeOff = side * wide / 2
					local probe = if alongX then s.Position + Vector3.new(0, 0, edgeOff + side * 1.5) else s.Position + Vector3.new(edgeOff + side * 1.5, 0, 0)
					if onRoad(probe) then
						local top = s.Position.Y + s.Size.Y / 2
						if alongX then
							part("Curb", Vector3.new(s.Size.X, s.Size.Y + 0.15, 0.7), CFrame.new(s.Position.X, s.Position.Y + 0.075, s.Position.Z + edgeOff - side * 0.35), GRANITE, Enum.Material.Granite, walkF)

						else
							part("Curb", Vector3.new(0.7, s.Size.Y + 0.15, s.Size.Z), CFrame.new(s.Position.X + edgeOff - side * 0.35, s.Position.Y + 0.075, s.Position.Z), GRANITE, Enum.Material.Granite, walkF)

						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- 3. street lights (asset 9553474820)
local lightF = folder("StreetLights")
-- a thinner pole than the asset (user 2026-10-22)
local lightSrc = A.StreetLight:Clone()
do
	local pole = tallest(lightSrc) :: BasePart
	local c = pole.CFrame
	local function thin(axisY: number) return if math.abs(axisY) > 0.7 then 1 else 0.55 end
	pole.Size = Vector3.new(pole.Size.X * thin(c.RightVector.Y), pole.Size.Y * thin(c.UpVector.Y), pole.Size.Z * thin(c.LookVector.Y))
	pole.CFrame = c
end
local lPole = tallest(lightSrc) :: BasePart
local lCf, lSize = lightSrc:GetBoundingBox()
local lBase = Vector3.new(lPole.Position.X, lCf.Y - lSize.Y / 2, lPole.Position.Z)
local lLens = lightSrc:FindFirstChild("Lense", true) :: BasePart
local lDir = flat(lLens.Position - lPole.Position)

local heads = {}
for _, p in ipairs(temp:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "LampHead" then table.insert(heads, p) end
end
local lights = 0
local lightSpots: {Vector3} = {}
for _, pole in ipairs(temp:GetChildren()) do
	if pole:IsA("BasePart") and pole.Name == "LampPole" then
		local h = vertical(pole)
		local base = Vector3.new(pole.Position.X, pole.Position.Y - h / 2, pole.Position.Z)
		local head, hd = nil, math.huge
		for _, x in ipairs(heads) do
			local d = (Vector3.new(x.Position.X, 0, x.Position.Z) - Vector3.new(base.X, 0, base.Z)).Magnitude
			if d < hd then head, hd = x, d end
		end
		local dir = if head and hd < 8 then flat(head.Position - pole.Position) else Vector3.new(1, 0, 0)
		local light = placeCopy(lightSrc, lBase, lDir, base, dir, lightF)
		if prop(light, "Light") then table.insert(lightSpots, light:GetPivot().Position) end
		hide(pole)
		for _, x in ipairs(temp:GetChildren()) do
			if x:IsA("BasePart") and (x.Name == "LampArm" or x.Name == "LampHead") and (Vector3.new(x.Position.X, 0, x.Position.Z) - Vector3.new(base.X, 0, base.Z)).Magnitude < 6 then hide(x) end
		end
		lights += 1
	end
end

---------------------------------------------------------------- 4. Korean traffic lights (asset 128805729882951)
local sigF = folder("TrafficLights")
local sigSrc = A.KoreanTrafficLight.Signal
local bmls = {}
for _, d in ipairs(sigSrc:GetDescendants()) do
	if d:IsA("Model") and d.Name == "BML" then table.insert(bmls, d) end
end
-- one unit = one pole (mast + arm) and the signal heads hanging on its arm
local units = {}
for _, pole in ipairs(sigSrc.Poles:GetChildren()) do
	if pole:IsA("Model") then
		local mast = tallest(pole) :: BasePart
		local cf, size = pole:GetBoundingBox()
		local base = Vector3.new(mast.Position.X, cf.Y - size.Y / 2, mast.Position.Z)
		local dir = flat(cf.Position - mast.Position)
		local unit = Instance.new("Model")
		unit.Name = "KoreanSignal"
		pole:Clone().Parent = unit
		for _, b in ipairs(bmls) do
			local bp = b:GetPivot().Position
			local rel = Vector3.new(bp.X - base.X, 0, bp.Z - base.Z)
			local along = rel:Dot(dir)
			local across = (rel - dir * along).Magnitude
			if along > 2 and along < 60 and across < 4 then b:Clone().Parent = unit end
		end
		table.insert(units, { model = unit, base = base, dir = dir })
	end
end
local signals = 0
for _, sp in ipairs(temp:GetChildren()) do
	if sp:IsA("BasePart") and sp.Name == "SignalPole" then
		local h = vertical(sp)
		local base = Vector3.new(sp.Position.X, sp.Position.Y - h / 2, sp.Position.Z)
		local arm, ad = nil, math.huge
		for _, x in ipairs(temp:GetChildren()) do
			if x:IsA("BasePart") and x.Name == "SignalArm" then
				local d = (x.Position - sp.Position).Magnitude
				if d < ad then arm, ad = x, d end
			end
		end
		local dir = if arm then flat(arm.Position - sp.Position) else flat(-base)
		signals += 1
		local u = units[((signals - 1) % #units) + 1]
		prop(placeCopy(u.model, u.base, u.dir, base, dir, sigF), "Signal")
	end
end
for _, x in ipairs(temp:GetChildren()) do
	if x:IsA("BasePart") and (x.Name == "SignalPole" or x.Name == "SignalArm" or x.Name == "SignalHead" or x.Name == "SignalLamp") then hide(x) end
end

---------------------------------------------------------------- 5. bus shelters (asset 10314993728); the tagged pad keeps working
local busF = folder("BusShelters")
local busSrc = A.BusShelter
local bCf, bSize = busSrc:GetBoundingBox()
local seat = busSrc:FindFirstChildWhichIsA("Seat", true)
local bBase = Vector3.new(bCf.X, bCf.Y - bSize.Y / 2, bCf.Z)
local bDir = if seat then flat(seat.CFrame.LookVector) else Vector3.new(0, 0, -1)
local shelters = 0
for _, m in ipairs(temp:GetChildren()) do
	if m:IsA("Model") and m.Name:match("^BusStop%d") then
		local back, bench, roof
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "ShelterBack" then back = p elseif p.Name == "BusBench" then bench = p elseif p.Name == "ShelterRoof" then roof = p end
			end
		end
		if back and bench and roof then
			local dir = flat(bench.Position - back.Position)
			local base = Vector3.new(roof.Position.X, 0.6, roof.Position.Z)
			local copy = placeCopy(busSrc, bBase, bDir, base, dir, busF)
			copy.Name = m.Name .. "_Shelter"
			prop(copy, "Shelter")
			for _, s in ipairs(copy:GetDescendants()) do
				if s:IsA("Seat") then CS:AddTag(s, "PromptSeat") end -- "앉기" prompt like other seats
			end
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and not CS:HasTag(p, "BusStop") and p.Name ~= "RouteBoard" then hide(p) end
			end
			shelters += 1
		end
	end
end

---------------------------------------------------------------- 6. utility poles (전봇대) + wires along the streets
local poleF = folder("UtilityPoles")
local packPoles = {}
for _, m in ipairs(A.UtilityPolePack:GetDescendants()) do
	if m:IsA("Model") and m.Name == "pole" then
		local c = m:Clone()
		-- thicker mast (user 2026-10-22): scale the tallest piece across, not up
		local mast = tallest(c) :: BasePart
		local mc = mast.CFrame
		local function thick(axisY: number) return if math.abs(axisY) > 0.7 then 1 else 1.8 end
		mast.Size = Vector3.new(mast.Size.X * thick(mc.RightVector.Y), mast.Size.Y * thick(mc.UpVector.Y), mast.Size.Z * thick(mc.LookVector.Y))
		mast.CFrame = mc
		-- Korean poles: grey concrete, steel crossarms
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("MeshPart") then
				p.TextureID = ""
				p.Color = Color3.fromRGB(150, 150, 146)
				p.Material = Enum.Material.Concrete
			elseif p:IsA("BasePart") then
				p.Color = Color3.fromRGB(120, 122, 125)
			end
		end
		table.insert(packPoles, c)
	end
end
table.sort(packPoles, function(a, b) return #a:GetDescendants() < #b:GetDescendants() end)
local function poleInfo(m: Model)
	local mast = tallest(m) :: BasePart
	local cf, size = m:GetBoundingBox()
	local base = Vector3.new(mast.Position.X, cf.Y - size.Y / 2, mast.Position.Z)
	-- crossarm = the widest horizontal part; wires hang from its ends
	local arm, w = nil, -1
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= mast then
			local horiz = math.max(math.abs(p.CFrame.RightVector.Y) < 0.5 and p.Size.X or 0, math.abs(p.CFrame.LookVector.Y) < 0.5 and p.Size.Z or 0)
			if horiz > w then arm, w = p, horiz end
		end
	end
	local armAxis = if arm and arm.Size.X >= arm.Size.Z then arm.CFrame.RightVector else (if arm then arm.CFrame.LookVector else Vector3.new(1, 0, 0))
	return { base = base, top = cf.Y + size.Y / 2, arm = arm, armAxis = flat(armAxis), armLen = w }
end

local function nearLight(p: Vector3): boolean
	for _, l in ipairs(lightSpots) do
		if (Vector3.new(l.X, 0, l.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 7 then return true end
	end
	return false
end
local function blocked(p: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	for _, x in ipairs(workspace:GetPartBoundsInRadius(p + Vector3.new(0, 4, 0), 2.5, params)) do
		if x.Transparency < 1 and x.Name ~= "Sidewalk" and x.Name ~= "Ground" and x.Name ~= "Road" and not x:IsA("Terrain") then return true end
	end
	return false
end

local poles = 0
local SPACING = 46
for _, s in ipairs(temp:GetChildren()) do
	if s:IsA("BasePart") and s.Name == "Sidewalk" and math.max(s.Size.X, s.Size.Z) >= 60 and math.min(s.Size.X, s.Size.Z) >= 4 then
		local alongX = s.Size.X >= s.Size.Z
		local long = if alongX then s.Size.X else s.Size.Z
		local wide = if alongX then s.Size.Z else s.Size.X
		-- the building side = the long edge that does NOT touch a road
		local outer = 1
		local probe = if alongX then s.Position + Vector3.new(0, 0, wide / 2 + 1.5) else s.Position + Vector3.new(wide / 2 + 1.5, 0, 0)
		if onRoad(probe) then outer = -1 end
		local axis = if alongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		local side = if alongX then Vector3.new(0, 0, outer) else Vector3.new(outer, 0, 0)
		local top = s.Position.Y + s.Size.Y / 2
		local placed = {}
		local n = math.floor((long - 20) / SPACING)
		for i = 0, n do
			local t = -long / 2 + 10 + i * SPACING
			local p = s.Position + axis * t + side * (wide / 2 - 1.2)
			p = Vector3.new(p.X, top, p.Z)
			local nearCross = math.abs(p.X) < 45 and math.abs(p.Z) < 45
			if not nearCross and not nearLight(p) and not blocked(p) then
				local src = packPoles[if (poles % 5 == 3) and #packPoles >= 3 then 3 else 1]
				local info = poleInfo(src)
				-- crossarm across the street: rotate so the arm axis is perpendicular to the street axis
				local c = placeCopy(src, info.base, info.armAxis, p, side, poleF)
				if prop(c, "Pole") then
					table.insert(placed, { model = c, src = src })
					poles += 1
				else
					table.insert(placed, false) -- deleted by hand: no wires to it
				end
			else
				table.insert(placed, false)
			end
		end
		-- wires between neighbours (3 lines from the crossarm ends and middle)
		for i = 1, #placed - 1 do
			local a, b = placed[i], placed[i + 1]
			if a and b then
				local ia, ib = poleInfo(a.model), poleInfo(b.model)
				for _, k in ipairs({ -0.42, 0, 0.42 }) do
					local pa = (if ia.arm then ia.arm.Position else ia.base + Vector3.new(0, ia.top - ia.base.Y - 1, 0)) + ia.armAxis * ia.armLen * k + Vector3.new(0, 0.3, 0)
					local pb = (if ib.arm then ib.arm.Position else ib.base + Vector3.new(0, ib.top - ib.base.Y - 1, 0)) + ib.armAxis * ib.armLen * k + Vector3.new(0, 0.3, 0)
					local mid = (pa + pb) / 2 - Vector3.new(0, 0.6, 0) -- a little sag
					for _, seg in ipairs({ { pa, mid }, { mid, pb } }) do
						local w = part("Wire", Vector3.new(0.08, 0.08, (seg[2] - seg[1]).Magnitude), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, poleF)
						w.CanCollide = false
						w.CanQuery = false
						w.CastShadow = false
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- 7. buildings: real window facades
local towers = 0
local looks = {
	{ IMG.glassTeal, 24, 24 }, { IMG.officeBand, 18, 14 }, { IMG.glassBlue, 20, 20 }, { IMG.concreteGrid, 22, 22 }, { IMG.officeBlue, 20, 16 },
}
for _, m in ipairs(temp:GetChildren()) do
	if m:IsA("Model") and m.Name:find("BG_Tower") then
		local body = m:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			towers += 1
			local tall = body.Size.Y > 100
			local look = if tall then looks[if towers % 2 == 0 then 3 else 1] else looks[({ 2, 4, 5 })[(towers % 3) + 1]]
			restyle(body, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
			body.Reflectance = 0
			texture(body, look[1], { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }, look[2], look[3])
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and (p.Name == "FloorBand" or p.Name == "WindowBand") then hide(p) end
			end
		end
	end
end

do
	local v = SS:FindFirstChild("PropRegistry") or Instance.new("StringValue")
	v.Name = "PropRegistry"
	v.Value = HS:JSONEncode(REGISTRY)
	v.Parent = SS
end
root.Parent = workspace
return string.format("dressed: roads %d, %d lights, %d traffic lights, %d bus shelters, %d utility poles, %d towers (MODE=revert to undo)",
	#roads, lights, signals, shelters, poles, towers)
