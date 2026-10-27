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
-- -38 (layout v8, user map 2026-10-27): 24 more north, the 오후네컷 building grew north
local CLUB_DZ = -38
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
-- the beach cafe (graybox 04, layout v8 2026-10-27: twice as big, moved south):
-- its street front z CAFE_Z0..CAFE_Z1, its corner decks and steps CAFE_ZS..CAFE_ZN
local CAFE_Z0, CAFE_Z1, CAFE_ZS, CAFE_ZN = 195, 357, 174.8, 377.2
-- ground holes: club + the four subway stair pits (x0, z0, x1, z1)
local HOLES = {
	{ 49, -253 + CLUB_DZ, 189, -92 + CLUB_DZ }, -- (19 longer east, user 2026-10-25) the club: edges in the middle of its walls (at the inner faces the ground flickered on the corridor and back walls, user 2026-10-24)
	{ 26, -68, 32, -50 }, { -53, -54.2, -35, -48.2 }, -- exit 1 comes up northwards, 3 westwards in the corner square (toward the beach)
	{ 26, 50, 32, 68 }, { -53, 41, -35, 47 }, -- exit 2 comes up southwards, 4 westwards in the corner square (toward the beach, user 2026-10-25)

	{ -141, -197, -51, -83 }, -- the pocket park's sunken round plaza (user 2026-10-24)
	{ -110, -92, -68, -53 }, -- its south walk + stair
}
-- 광화문 lawns planted as terrain grass (blades), x0, z0, x1, z1 (user 2026-10-23)
-- the lawns are sunken beds: terrain heights snap to 4 studs, so terrain
-- grass can only stand at about -1.6 (or 2.4, which bulged, user 2026-10-23);
-- the ground and the yard paving are cut there and a stone kerb rims the bed
-- 광화문 (user map 2026-10-27, after v8): three times as big, turned 30° so it
-- faces the 강남 crossing diagonally at the village's north-west corner; the
-- stone walls leave its two ends in gentle curves (cubic Béziers) to the north
-- wall line (z 49) and the 돌담길 along the south road. Gate frame: ALONG runs
-- to its north-east end, OUT is its front (to the street)
local GATE_C = Vector3.new(158, 0, 195)
local GATE_ROT = math.rad(-30)
local GATE_HL, GATE_HD = 56, 14 -- half its length and depth (2 × 56 / 2, 2 × 14 / 2; 3× → 2×, user 2026-10-27)
local GATE_ALONG = CFrame.Angles(0, GATE_ROT, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
local GATE_OUT = CFrame.Angles(0, GATE_ROT, 0):VectorToWorldSpace(Vector3.new(-1, 0, 0))
local GATE_E1, GATE_E2 = GATE_C + GATE_ALONG * GATE_HL, GATE_C - GATE_ALONG * GATE_HL -- north-east / south-west end
local function bezier(c: { Vector3 }, t: number): Vector3
	local u = 1 - t
	return c[1] * (u * u * u) + c[2] * (3 * u * u * t) + c[3] * (3 * u * t * t) + c[4] * (t * t * t)
end
local DOLDAM_B, DOLDAM_C = Vector3.new(97, 0, 330), Vector3.new(185, 0, 700) -- the 돌담길's straight run
local DOLDAM_U = (DOLDAM_C - DOLDAM_B).Unit
local DOLDAM_J = DOLDAM_B + DOLDAM_U * 92.5 -- where the curve joins it (z 420)
local WALL_N = { GATE_E1, GATE_E1 + GATE_ALONG * 40, Vector3.new(260, 0, 49), Vector3.new(300, 0, 49) }
-- (user map 2026-10-27) south of the gate the wall bends back east in one gentle
-- arc to the play area's south edge (the straight 돌담길 run is gone)
-- (user 2026-10-27, red line) from the gate's south end a gentle bend to the
-- south road's sidewalk, then straight along it (x 52) to the end
local WALL_S = { GATE_E2, GATE_E2 - GATE_ALONG * 40, Vector3.new(52, 0, 292), Vector3.new(52, 0, 340) }
local WALL_S_END = Vector3.new(52, 0, 700)
-- the lawns sit outside the two balustrades (beds stay axis-aligned: terrain grass)
-- (no square lawn beds since the user map 2026-10-27: a lawn band follows the wall curve)
local LAWN_TERRAIN = {}
local OLD_LAWNS = { { 110, 50, 170, 68 }, { 48, 262, 90, 292 }, { 47, 47, 82, 139.4 }, { 47, 196.6, 82, 289 } } -- (their terrain grass is cleared on revert)
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
		if x:GetAttribute("LayoutAdded") then x:Destroy() continue end
		local sz = x:GetAttribute("OrigSize")
		if typeof(sz) == "Vector3" and x:IsA("BasePart") then x.Size = sz x:SetAttribute("OrigSize", nil) end
		local tr, col = x:GetAttribute("OrigTransparency"), x:GetAttribute("OrigColor")
		if typeof(tr) == "number" and x:IsA("BasePart") then x.Transparency = tr x:SetAttribute("OrigTransparency", nil) end
		if typeof(col) == "Color3" and x:IsA("BasePart") then x.Color = col x:SetAttribute("OrigColor", nil) end
		local t, cf = x:GetAttribute("OrigText"), x:GetAttribute("OrigCFrame")
		if typeof(t) == "string" and x:IsA("TextLabel") then x.Text = t x:SetAttribute("OrigText", nil) end
		if typeof(cf) == "CFrame" and x:IsA("BasePart") then x.CFrame = cf x:SetAttribute("OrigCFrame", nil) end
	end
	-- the ferris wheel back to its built size first (the pivot stays, so the
	-- move back below lands it where it was)
	do
		local park = root:FindFirstChild("06_Park_Playground")
		local W = park and park:FindFirstChild("FerrisWheel")
		if W and W:GetScale() ~= 1 then
			W:ScaleTo(1)
			W:SetAttribute("Radius", 26)
		end
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
		if old:GetAttribute("LawnTerrain") then
			-- (with the beds before layout v8, so their grass goes too)
			for _, l in ipairs(OLD_LAWNS) do
				workspace.Terrain:FillBlock(CFrame.new((l[1] + l[3]) / 2, -2, (l[2] + l[4]) / 2), Vector3.new(l[3] - l[1] + 8, 12, l[4] - l[2] + 8), Enum.Material.Air)
			end
		end
		if old:GetAttribute("YardLawn") then -- the 광화문 yard lawn (terrain, 0..4)
			workspace.Terrain:FillBlock(CFrame.new((47 + 277) / 2, 2, (47 + 387) / 2), Vector3.new(232, 4, 342), Enum.Material.Air)
		end
		if old:GetAttribute("Mountains") then
			for _, m in ipairs(MOUNTAINS) do workspace.Terrain:FillBall(m[1], m[2] + 1, Enum.Material.Air) end
		end
		if old:GetAttribute("SeaLowered") then -- sea back up to y 0 (dome kept dry, as the graybox builds it)
			workspace.Terrain:FillBlock(CFrame.new((-1024 - 268) / 2, -SEA_DROP / 2, 0), Vector3.new(1024 - 268, SEA_DROP, 2048), Enum.Material.Water)
			workspace.Terrain:FillBall(Vector3.new(-368, 0, -150), 44, Enum.Material.Air)
		end
		old:Destroy()
	end
	workspace.Terrain:FillBlock(CFrame.new(-274, 1.02, 62), Vector3.new(24, 1.6, 28), Enum.Material.Air) -- the cafe pool's water
	workspace.Terrain:FillBlock(CFrame.new(-277.5, 1.02, 47), Vector3.new(13.4, 2, 48), Enum.Material.Air) -- (the channel since 2026-10-25)
	workspace.Terrain:FillBlock(CFrame.new(-278, -2, 46), Vector3.new(20, 4, 52), Enum.Material.Air) -- (its basin under the floor)
	workspace.Terrain:FillBlock(CFrame.new(-272, -2, 42), Vector3.new(16, 4, 44), Enum.Material.Air) -- (the moved basin)
	-- (layout v8) the cafe left that place: the sea there back to its lowered level (y -3)
	workspace.Terrain:FillBlock(CFrame.new(-282, -3.5, 44), Vector3.new(28, 1, 60), Enum.Material.Water)
	-- ride name signs switched off while the park was closed
	for _, g in ipairs(root:GetDescendants()) do
		if g:IsA("BillboardGui") and g:GetAttribute("ParkClosedHidden") then
			g.Enabled = true
			g:SetAttribute("ParkClosedHidden", nil)
		end
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
-- layout v8 (user map 2026-10-27): the runway / backstage behind the club is
-- gone under the big 국밥집 and the long shop block, the Glasshouse cafe under
-- the bigger OH24 store and the south shop block; parked like the rest
for _, zn in ipairs({ "03_Rooftop_Backstage", "05_Cafe" }) do
	local z3 = root:FindFirstChild(zn)
	if z3 then
		local undo = MOVES[zn]:Inverse()
		for _, c in ipairs(z3:GetChildren()) do
			if c:IsA("BasePart") or c:IsA("Model") then
				if c:IsA("Model") then c:PivotTo(undo * c:GetPivot()) else c.CFrame = undo * c.CFrame end
				c:SetAttribute("HomeZone", z3.Name)
				c.Parent = hidden
			end
		end
	end
end
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
		-- (user map 2026-10-27: spread over the whole park block, not bunched at the gate)
		{ { -125, -145, -85, -105 }, Vector3.new(-13, 0, -150) }, -- carousel → (-118, -275)
		{ { -215, -145, -160, -90 }, Vector3.new(113, 0, -213) }, -- playground → (-76, -332)
		{ { -120, -262, -90, -190 }, Vector3.new(5, 0, -188) }, -- ferris wheel → (-100, -414) (2×: rim z -466..-362)
		{ { -220, -245, -200, -178 }, Vector3.new(146, 0, -153) }, -- flower tunnel → (-64, -365)
		{ { -155, -176, -145, -166 }, Vector3.new(57, 0, -84) }, -- park name label → (-93, -255)
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
						-- the slide's run-out pointed east through the moved-in east wall: 5 more west
						local d = CFrame.new(g[2] + (if c.Name == "Slide" then Vector3.new(-5, 0, 0) else Vector3.zero))
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
			-- (user 2026-10-27) the ferris wheel twice as big, standing on the
			-- same ground spot; its turning radius goes with it (revert scales it back)
			local W = park:FindFirstChild("FerrisWheel")
			local hub = W and W:FindFirstChild("Hub")
			if W and hub and W:GetScale() == 1 then
				local cf0, s0 = W:GetBoundingBox()
				local groundY = cf0.Y - s0.Y / 2
				local hx, hz = hub.Position.X, hub.Position.Z
				W:ScaleTo(2)
				local cf1, s1 = W:GetBoundingBox()
				W:PivotTo(W:GetPivot() + Vector3.new(hx - hub.Position.X, groundY - (cf1.Y - s1.Y / 2), hz - hub.Position.Z))
				W:SetAttribute("Radius", 52)
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
-- a flat or sloped triangle from two wedges (any three points); th = slab
-- thickness, centred on the triangle's plane
local function wedgeTri(name, a: Vector3, b: Vector3, c: Vector3, th, color, opt)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	if ac:Cross(ab).Magnitude < 0.01 then return end
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local h = math.abs(ab:Dot(up))
	local o = {}
	for k, v in pairs(opt or {}) do o[k] = v end
	o.class = "WedgePart"
	local d1, d2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if d1 > 0.01 then part(name, Vector3.new(th, h, d1), CFrame.fromMatrix((a + b) / 2, right, up, back), color, o) end
	if d2 > 0.01 then part(name, Vector3.new(th, h, d2), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, o) end
end
-- Floating place / function labels are off (user 2026-10-26: "현재 장소들나 기능
-- 표시해 놓은 텍스트들 다 지워"); SHOW_LABELS brings them back.
local SHOW_LABELS = false
local function label(adornee: BasePart, text, color, offsetY, scale): BillboardGui?
	if not SHOW_LABELS then return nil end
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
	if true then return end -- no traffic signals at all, poles included (user 2026-10-23)
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
	-- (user 2026-10-24, performance) trunks and branches lose their own colour
	-- and normal images (Overlay SurfaceAppearance, two per mesh) and wear the
	-- built-in wood in the bark brown; the leaves (one shared image) stay
	for _, sa in ipairs(m:GetDescendants()) do
		if sa:IsA("SurfaceAppearance") and sa.AlphaMode == Enum.AlphaMode.Overlay then
			local mp = sa.Parent
			sa:Destroy()
			if mp and mp:IsA("MeshPart") then
				mp.Color = Color3.fromRGB(112, 84, 60)
				mp.Material = Enum.Material.Wood
			end
		end
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
local NO_CARS = true -- (user 2026-10-27: no cars on the roads)
local function car(pos: Vector3, along: Vector3)
	if NO_CARS then return end
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
for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, -1 } }) do walk(s[1] * 24, s[2] * 24, s[1] * WIDE, s[2] * WIDE) end
-- south-west: subway exit 4's pit at its back edge (x -47..-35, z 41..47)
walk(-24, 24, -47, 41) walk(-24, 41, -35, WIDE)
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
-- bus stops (number, name, centre, toward the road, along the street). The
-- shelters are twice their old size since layout v8 (user 2026-10-27): about
-- 30 along the street; nothing is planted there and the bike lane breaks
local BUS_STOPS = {
	{ 1, "OHU CLUB 앞", Vector3.new(-31, 0, -183 - 24), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1) }, -- (24 north with the club, v8)
	{ 2, "고층 빌딩가", Vector3.new(130, 0, 31), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) },
	{ 3, "한옥 마을 · 광화문", Vector3.new(31, 0, 217.5), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1) },
	{ 4, "해변", Vector3.new(-153, 0, 84), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1) },
}
local BUS_HALF = 17 -- half the shelter + sign length along the street
local function busFootprint(s): (number, number, number, number)
	local c, along, road = s[3], s[5], s[4]
	local a, b = c - along * BUS_HALF - road * 5, c + along * (BUS_HALF + 3) + road * 9
	return math.min(a.X, b.X), math.min(a.Z, b.Z), math.max(a.X, b.X), math.max(a.Z, b.Z)
end
local KEEP_CLEAR = {
	{ -196, -40, -104, -20 }, -- park gate
}
-- bus stops: no planting bed between the shelter / sign and the curb
for _, s in ipairs(BUS_STOPS) do
	local x0, z0, x1, z1 = busFootprint(s)
	table.insert(KEEP_CLEAR, { x0, z0, x1, z1 })
end
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
		-- (pieces of no width are skipped: a pit can sit on the sidewalk's edge)
		local function sw(a0, b0, a1, b1) if math.abs(a1 - a0) > 0.01 and math.abs(b1 - b0) > 0.01 then uv("Sidewalk", a0, b0, a1, b1, 0, CURB, WALK, { material = Enum.Material.Brick }) end end
		for _, p in ipairs(cuts) do
			sw(u, v0, p[1], v1)
			sw(p[1], v0, p[2], p[3])
			sw(p[1], p[4], p[2], v1)
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
	for _, v in ipairs({ 0 }) do -- one symbol per bike crossing (user 2026-10-24)
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
		-- no bed right in front of a subway exit either (user 2026-10-23)
		for _, p in ipairs(pits) do if u > p[1] - 9 and u < p[2] + 20 then free = false end end
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
				-- the lane stops only under a bus shelter (user 2026-10-26), not over
				-- the whole keep-clear stretch round it
				local p = at(u, side * 31.2)
				for _, s in ipairs(BUS_STOPS) do
					local c, along = s[3], s[5]
					local d = p - c
					if math.abs(d:Dot(s[4])) < 4 and math.abs(d:Dot(along)) < 16 then return false end
				end
				for i, k in ipairs(KEEP_CLEAR) do
					if i > 1 and p.X > k[1] and p.X < k[3] and p.Z > k[2] and p.Z < k[4] then return true end -- (a bus stop box: only the shelter counts)
				end
				return clear(p)
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
bigRoad(Vector3.new(0, 0, -1), 1000, { { 50, 68, 26, 32 } }, { { 92, -1 }, { 150, 1 }, { 205, -1 } }, { [-1] = 34, [1] = 49 }, nil, 480) -- north
-- along the pocket park and the amusement park the west sidewalk is as wide as
-- the others (to x -47, the corner squares' line; user 2026-10-24)
walk(-47, -478.6, -34, -54.2) -- (from the amusement park's north-east pillar, now off the sidewalk, to subway exit 3's pit)
walk(-150, -478.6, -148.25, -228.75) -- the same on the west, from the beach road's sidewalk to the wall's plinth (bare ground showed there, user 2026-10-24)
walk(-51.05, -478.6, -47, -228.75) -- (to the wall line, where the pocket park's paving begins) the same paving up to the amusement park's east wall (its plinth face; no bare ground strip at the wall's foot)
bigRoad(Vector3.new(0, 0, 1), 1000, { { 50, 68, -32, -26 } }, { { 100, 1 }, { 160, -1 }, { 235, 1 } }, nil, nil, 300) -- south (past the boundary at 299: the street goes on, D-110)
bigRoad(Vector3.new(1, 0, 0), 1000, {}, { { 100, 1 }, { 165, -1 } }, nil, nil, 180) -- east
bigRoad(Vector3.new(-1, 0, 0), 158, { { 47, 53, -47, -41 } }, { { 100, -1 } }, nil, true) -- west, to the seafront road (bike lanes run on to the bike crossings)

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
-- (user 2026-10-25: the club grows east over it) no side street east of the
-- club any more: paved over from the club to the background towers
box("Sidewalk", 171, 0, -470, 192.5, CURB, -375, WALK, { material = Enum.Material.Brick }) -- (layout v8: up to the big 국밥집, z -375; was -268.2 + CDZ)
box("Sidewalk", 171, 0, -95.8 + CDZ, 192.5, CURB, -47, WALK, { material = Enum.Material.Brick })
box("Sidewalk", 190.2, 0, -268.2 + CDZ, 192.5, CURB, -95.8 + CDZ, WALK, { material = Enum.Material.Brick })
local _ = smallRoad
-- (no south-west lane to the seafront at z 98: the OH24 store stands on it, user 2026-10-25)
-- lane from the east road to the hanok main gate (east side, gate at x 225, z 126)
local LANE = Color3.fromRGB(185, 160, 122)
-- (gone with the emptied village, user map 2026-10-27: the yard paving covers it)
local _ = LANE

------------------------------------------------------- subway exits (stairs)
-- stairs come up in the arrow direction under a glass canopy that slopes
-- down toward the back; the pad is the landing at the bottom of the stairs
-- (like going down to the platform): step on it → exit picker; arrivals
-- appear at the foot of the stairs and walk up (user 2026-10-22)
local EXITS = {
	-- pits 18 long at 50..68 from the junction: clear of the wide corner squares (v7c)
	{ 1, "클럽", Color3.fromRGB(255, 122, 214), 29, -59, Vector3.new(0, 0, -1) },
	{ 2, "한옥 마을", Color3.fromRGB(185, 135, 74), 29, 59, Vector3.new(0, 0, 1) },
	{ 3, "놀이공원", Color3.fromRGB(76, 175, 80), -44, -51.2, Vector3.new(-1, 0, 0) }, -- back corner of its base on the square's inner corner (-34.4, -47) (user) -- in the corner square, away from the road, facing the beach (user 2026-10-23); at sidewalk level like the others (user 2026-10-24: it stood 0.6 below)
	{ 4, "해변", Color3.fromRGB(42, 143, 179), -44, 44, Vector3.new(-1, 0, 0), nil, -1 }, -- like exit 3: in the corner square, coming up westwards toward the beach (user 2026-10-25); its sign post on the road side (8th = side)
}
local exitPads, exitMouths = {}, {}
for _, e in ipairs(EXITS) do
	local m = Instance.new("Model")
	m.Name = "SubwayExit" .. e[1]
	m.Parent = T
	local out = e[6]
	local TOPY = e[7] or CURB -- ground level around this exit
	local c = Vector3.new(e[4], 0, e[5]) -- pit centre: 6 wide, 18 long (u -9..9 along out)
	local side = Vector3.new(math.abs(out.Z), 0, math.abs(out.X)) -- across the pit
	local function at(u) return c + out * u end
	-- (user 2026-10-27: tall avatars could not get down) a shallower pit, 6
	-- deep instead of 8.6: ten 0.6 steps over the same 12, about 27° instead
	-- of 36°, with an invisible ramp over the steps
	local DEPTH = 6
	local bottom = TOPY - DEPTH
	for k = 1, 10 do -- stairs from the mouth (u 9) down to u -3
		local a, b = at(9 - (k - 1) * 1.2) - side * 3, at(9 - k * 1.2) + side * 3
		box("Step", a.X, -9, a.Z, b.X, TOPY - k * DEPTH / 10, b.Z, Color3.fromRGB(150, 150, 155), { parent = m, material = Enum.Material.Concrete })
	end
	do
		local rc = at(3) + Vector3.new(0, TOPY - DEPTH / 2, 0)
		part("StairRamp", Vector3.new(6, DEPTH, 12), CFrame.lookAt(rc, rc - out), Color3.new(1, 1, 1), { parent = m, transparency = 1, class = "WedgePart" })
	end
	local l0, l1 = at(-3) - side * 3, at(-9) + side * 3
	box("Landing", l0.X, -9, l0.Z, l1.X, bottom, l1.Z, Color3.fromRGB(120, 120, 128), { parent = m, material = Enum.Material.Concrete })
	do
		-- inner faces 0.03 into the pit: at exactly 3 they shared a plane with the
		-- cut edges of the ground / sidewalk round the hole and flickered (user video);
		-- tops a hair under the ground (their tops sat in the pavement plane and flickered)
		local a, b = at(-9) - side * 3.4, at(9) - side * 2.97
		box("PitWallL", a.X, -9, a.Z, b.X, TOPY - 0.03, b.Z, Color3.fromRGB(200, 200, 205), { parent = m })
		a, b = at(-9) + side * 2.97, at(9) + side * 3.4
		box("PitWallR", a.X, -9, a.Z, b.X, TOPY - 0.03, b.Z, Color3.fromRGB(200, 200, 205), { parent = m })
	end
	local ba, bb = at(-9.2) - side * 3, at(-8.8) + side * 3
	local bw = box("PitBack", ba.X, -9, ba.Z, bb.X, TOPY + 2.6, bb.Z, Color3.fromRGB(40, 40, 45), { parent = m })
	surfaceText(bw, if out.Z < -0.5 then Enum.NormalId.Front elseif out.Z > 0.5 then Enum.NormalId.Back elseif out.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left, "🚇 승강장\n발판을 밟으면 출구 선택", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	-- entrance building (user photo 2026-10-22): granite base, glass sides with
	-- dark frames, a grey roof high at the open end that sweeps down in a curve
	-- to the base at the back
	local granite = Color3.fromRGB(176, 176, 172)
	local dark = Color3.fromRGB(38, 40, 44)
	local roofC = Color3.fromRGB(150, 153, 157)
	local BASE = TOPY + 2.6 -- top of the granite base
	local U0, U1 = -9.6, 9.4 -- back, mouth
	local RAISE = 4 -- (the canopy 4 higher, about half again over the stairs: tall avatars, user 2026-10-27)
	local function roofY(u: number): number
		if u >= -3 then return TOPY + 6.2 + RAISE + (u + 3) / (U1 + 3) * 1.4 end -- straight, rising to the mouth
		local t = math.clamp((u + 3) / (U0 + 3), 0, 1) -- 0 at -3, 1 at the back
		return BASE + (3.6 + RAISE) * math.sqrt(math.max(0, 1 - t * t)) -- elliptic curve down to the base
	end
	for _, sx in ipairs({ -1, 1 }) do
		-- the side bases stop where the back block and the front frame begin (they overlapped it face to face)
		local a, b = at(U0 + 0.6) + side * (sx * 3.4), at(U1 - 0.8) + side * (sx * 4.2)
		box("EntranceBase", math.min(a.X, b.X), TOPY, math.min(a.Z, b.Z), math.max(a.X, b.X), BASE, math.max(a.Z, b.Z), granite, { parent = m, material = Enum.Material.Granite })
	end
	do
		local a, b = at(U0) + side * -4.2, at(U0 + 0.6) + side * 4.2
		box("EntranceBase", math.min(a.X, b.X), TOPY, math.min(a.Z, b.Z), math.max(a.X, b.X), BASE, math.max(a.Z, b.Z), granite, { parent = m, material = Enum.Material.Granite })
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
		-- neighbouring slabs overlap: alternate their width / thickness a hair so no faces coincide
		local w = if i % 2 == 0 then 8.6 else 8.64
		local h = if i % 2 == 0 then 0.9 else 0.92
		part("EntranceRoof", Vector3.new(w, h, len), look * CFrame.new(0, h / 2, 0), roofC, { parent = m, material = Enum.Material.Metal })
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
		box("EntranceFrame", math.min(a.X, b.X), TOPY, math.min(a.Z, b.Z), math.max(a.X, b.X), roofY(U1) + 0.9, math.max(a.Z, b.Z), dark, { parent = m, material = Enum.Material.Metal })
	end
	-- exit sign pillar (user photo of a Seoul exit sign, 2026-10-23): a tall
	-- dark slab; on both faces, top to bottom: subway icon, exit number,
	-- 출입구 / Entrance, the station name in Korean, English, Hanja, Japanese
	local mouth = at(9)
	-- on the road side of the mouth (user 2026-10-23), just past the opening
	local polePos = mouth + out * 7.2 + side * 3.8 * (e[8] or -math.sign(e[4])) -- two steps clear of the entrance frame (user)
	-- a square post (photo: slim, the same on all four faces), the Korean name
	-- written top to bottom, the small print really small
	local PW, PD, PH = 1.15, 1.15, 10
	local pillar = part("ExitPole", Vector3.new(PW, PH, PD), CFrame.fromMatrix(polePos + Vector3.new(0, TOPY + PH / 2, 0), side, Vector3.yAxis), dark, { parent = m, material = Enum.Material.Metal })
	-- each exit names where it leads (user 2026-10-23): Korean, English, Hanja, Japanese
	local STATIONS = {
		{ "클럽", "Club", "俱樂部", "クラブ" },
		{ "한옥마을", "Hanok Village", "韓屋村", "ハノク村" },
		{ "놀이공원", "Amusement Park", "遊樂公園", "遊園地" },
		{ "해변", "Beach", "海邊", "ビーチ" },
	}
	local STATION = STATIONS[e[1]]
	local YELLOW = Color3.fromRGB(252, 196, 30)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 100 -- 115 px wide
		g.LightInfluence = 0.4
		g.Parent = pillar
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = g
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.Parent = g
		local order = 0
		local function line(text, h, color, font)
			order += 1
			local l = Instance.new("TextLabel")
			l.LayoutOrder = order
			l.Size = UDim2.new(0.84, 0, 0, h)
			l.BackgroundTransparency = 1
			l.Font = font or Enum.Font.GothamBold
			l.TextScaled = true
			l.TextColor3 = color
			l.Text = text
			l.Parent = g
			return l
		end
		local function gap(h)
			order += 1
			local s = Instance.new("Frame") s.LayoutOrder = order s.Size = UDim2.new(0, 1, 0, h) s.BackgroundTransparency = 1 s.Parent = g
		end
		-- one-colour subway pictogram (Creator Store decal 994265483, background removed: docs/04_ART/references/subway_icon_mono.png)
		order += 1
		local tile = Instance.new("Frame")
		tile.LayoutOrder = order
		tile.Size = UDim2.new(0, 84, 0, 84)
		tile.BackgroundColor3 = YELLOW
		tile.BorderSizePixel = 0
		tile.Parent = g
		local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 8) c1.Parent = tile
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.78, 0.78)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://134705833671914"
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = tile
		gap(6)
		line(tostring(e[1]), 92, YELLOW, Enum.Font.GothamBlack)
		line("출입구", 12, YELLOW, Enum.Font.GothamMedium)
		line("Entrance", 9, YELLOW, Enum.Font.Gotham)
		gap(22)
		-- the Korean name top to bottom, one syllable per line
		for _, ch in utf8.codes(STATION[1]) do
			line(utf8.char(ch), 64, Color3.new(1, 1, 1), Enum.Font.GothamBold)
		end
		gap(8)
		line(STATION[2], 9, Color3.fromRGB(215, 215, 215), Enum.Font.Gotham)
		line(STATION[3], 10, Color3.fromRGB(215, 215, 215), Enum.Font.Gotham)
		line(STATION[4], 9, Color3.fromRGB(215, 215, 215), Enum.Font.Gotham)
	end	local sign = pillar
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
		-- players can buy this ad space (BusAdService, user 2026-10-25: 4 stops × 2)
		ad:SetAttribute("Slot", "BusStop" .. n .. "_" .. i)
		ad:SetAttribute("StopName", name)
		CS:AddTag(ad, "BusAd")
	end
	local map = part("RouteMap", Vector3.new(4.6, 3.4, 0.15), cf * CFrame.new(0, 6, 1.8), Color3.fromRGB(240, 242, 240), { parent = m })
	surfaceText(map, Enum.NormalId.Front, "OHU 01 ─●─●─●─\nOHU 02 ─●─●─●─\nOHU 03 ─●─●─●─", Color3.fromRGB(40, 120, 60), Enum.Font.GothamBold)
	part("BackGlass", Vector3.new(4.6, 3.4, 0.1), cf * CFrame.new(0, 2.6, 1.8), Color3.fromRGB(200, 220, 228), { parent = m, material = Enum.Material.Glass, transparency = 0.6 })
	local plate = part("StopNumber", Vector3.new(1.2, 0.8, 0.1), cf * CFrame.new(W / 2 - 1, H - 1.5, 1.55), Color3.fromRGB(40, 90, 200), { parent = m })
	surfaceText(plate, Enum.NormalId.Front, string.format("%02d-%03d", 13, 100 + n), Color3.new(1, 1, 1), Enum.Font.GothamBold)
	-- (layout v8, user 2026-10-27) the shelter twice as big; the benches stay
	-- human sized, two of them under the bigger roof
	m.WorldPivot = cf
	m:ScaleTo(2)
	for _, bx in ipairs({ -4.5, 4.5 }) do
		for _, x in ipairs({ -1.9, 1.9 }) do part("BenchLeg", Vector3.new(0.3, 1.6, 1), cf * CFrame.new(bx + x, 0.8, 2.2), steel, { parent = m, material = Enum.Material.Metal }) end
		seat("BusBench", cf * CFrame.new(bx, 1.75, 2.2), Vector3.new(4.4, 0.3, 1.2), Color3.fromRGB(150, 175, 180), m)
	end
	-- bus stop sign pole at the curb (user photo, 노원구청): green bus disc on
	-- top, black name panel + white route board, small 금연 plate. Clicking the
	-- sign opens the stop picker (SubwayService, tag BusStop)
	local signBase = base + roadDir * 5.4 + along * 18 -- at the curb, road side (user), past the bigger shelter
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
	do -- (user 2026-10-27) the sign pole twice as big too, like the shelter
		local S = Instance.new("Model")
		for _, p in ipairs({ m:FindFirstChild("BusSignPole"), disc, sign }) do if p then p.Parent = S end end
		S.WorldPivot = CFrame.new(signBase)
		S:ScaleTo(2)
		for _, p in ipairs(S:GetChildren()) do p.Parent = m end
	end
	label(sign, "🚌 " .. name .. " 정류장", Color3.fromRGB(60, 140, 230), 4, 0.7)
end
-- (1: moved north to where the ranking boards stood, 3: moved north to the
-- street light, user phone test 2026-10-26)
for _, s in ipairs(BUS_STOPS) do busStop(s[1], s[2], s[3], s[4], s[5]) end

------------------------------------------------------- 광안리 seafront
do
	-- full length of the west side (user: the whole west is beach and sea)
	local z0, z1 = -474, 300 -- north end: the park wall's cross leg (user 2026-10-24)
	-- the road ends in a U-turn bulb (user 2026-10-24, red line): no turnaround
	-- size is given in the road rules found (도로의 구조·시설 기준에 관한 규칙
	-- has none for a dead end), so the bulb is the usual 12 m turning circle
	-- for a car: diameter 24 here, the full road width
	local ROAD_N = -392 -- bulb centre; the asphalt ends 12 further north
	local STEP_N = -400 -- straight wooden steps from here south; north of it they curve and taper
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
				-- taps on the riser below each tread, every 3.5 (none on the
				-- lowest riser, user 2026-10-26)
				local riserX = xs[k][1]
				local y = tops[k] - 0.3
				for z = zs + 2, if k < 3 then ze - 1.5 else zs, 3.5 do
					local base = Vector3.new(riserX - 0.05, y, z)
					part("TapBody", Vector3.new(0.3, 0.25, 0.25), CFrame.new(base + Vector3.new(-0.15, 0, 0)), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
					part("TapSpout", Vector3.new(0.12, 0.3, 0.12), CFrame.new(base + Vector3.new(-0.3, -0.12, 0)), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
					part("TapHandle", Vector3.new(0.08, 0.08, 0.35), CFrame.new(base + Vector3.new(-0.18, 0.18, 0)), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
					part("WetStain", Vector3.new(0.9, 0.02, 0.7), CFrame.new(riserX - 0.45, (if k < 3 then tops[k + 1] else sandTop) + 0.01, z), Color3.fromRGB(110, 106, 100), { material = Enum.Material.Slate, nocol = true })
				end
			end
			-- walking on the steps plays a foot-washing swish (PoolSplashController)
			local wash = box("FootWashZone", -206.2, sandTop, zs, -198.7, CURB + 4, ze, Color3.new(1, 1, 1), { nocol = true })
			wash.Transparency = 1
			wash.CanTouch = false
			CS:AddTag(wash, "FootWashZone")
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
			-- (taller, the sign higher above the tap with room over it: user 2026-10-26)
			box("FountainBase", dx - 1.1, sandTop, dz - 0.9, dx + 1.1, sandTop + 4.6, dz + 0.9, Color3.fromRGB(196, 160, 140), { material = Enum.Material.Granite })
			box("FountainTop", dx - 1.3, sandTop + 4.6, dz - 1.1, dx + 1.3, sandTop + 4.9, dz + 1.1, Color3.fromRGB(196, 160, 140), { material = Enum.Material.Granite })
			box("FountainBasin", dx - 1.6, sandTop + 1.6, dz - 0.7, dx - 1.1, sandTop + 2, dz + 0.7, Color3.fromRGB(180, 145, 125), { material = Enum.Material.Granite })
			-- the tap: press it and water runs into the basin (FountainService)
			local tap = part("FountainTap", Vector3.new(0.4, 0.15, 0.15), CFrame.new(dx - 1.3, sandTop + 2.8, dz), Color3.fromRGB(200, 202, 206), { material = Enum.Material.Metal, nocol = true })
			do
				local stream = part("WaterStream", Vector3.new(0.09, 0.8, 0.09), CFrame.new(dx - 1.45, sandTop + 2.35, dz), Color3.fromRGB(170, 215, 255), { material = Enum.Material.Glass, nocol = true })
				stream.Transparency = 1
				stream.CastShadow = false
				stream.Parent = tap
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "물 틀기"
				prompt.ObjectText = "음수대"
				prompt.MaxActivationDistance = 7
				prompt.RequiresLineOfSight = false
				prompt.Parent = tap
				local sound = Instance.new("Sound")
				sound.SoundId = "rbxassetid://9119158299" -- "Sink Sprayer Spray Into Kitchen Sink 13" (Pro Sound Effects)
				sound.Volume = 0.6
				sound.RollOffMaxDistance = 40
				sound.Parent = tap
				CS:AddTag(tap, "FountainTap")
			end
			local plate = part("FountainSign", Vector3.new(0.05, 0.9, 1.4), CFrame.new(dx - 1.13, sandTop + 3.6, dz), Color3.fromRGB(120, 190, 240), { nocol = true })
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
		for zs = STEP_N, z1 - 1, 20 do
			local ze = math.min(zs + 20, z1)
			-- (layout v8, 2026-10-27: the cafe moved south, its decks z 174.8..377.2)
			if zs < CAFE_ZS and ze > CAFE_ZS then ze = CAFE_ZS end -- the beach cafe's corner steps take over from here (graybox 04)
			if zs < CAFE_ZN and ze > CAFE_ZN then zs = CAFE_ZN end -- and hand back after its south corner
			local free = true
			local probe = CFrame.new(-201, (sandTop + CURB) / 2 + 0.2, (zs + ze) / 2)
			for _, p in ipairs(workspace:GetPartBoundsInBox(probe, Vector3.new(6, CURB - sandTop - 0.6, ze - zs - 1), params)) do
				if p.Name ~= "Beach" and p.Name ~= "Ground" and p.Name ~= "BeachStep" and p.Name ~= "BeachStepEdge" and p.Transparency < 1 then free = false break end -- (the cafe's own steps join these)
			end
			if free and zs == -200 then -- open beach, clear of the truck and the cafes, next to the beach signs
				footWash(zs, ze, sandTop)
			elseif free then
				box("BeachStepEdge", -198.7, sandTop, zs, -198, CURB + 0.1, ze, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
				-- three wooden steps (user 2026-10-22)
				box("BeachStep", -201.2, sandTop, zs, -198.7, CURB - 0.6, ze, wood, { material = Enum.Material.WoodPlanks })
				box("BeachStep", -203.7, sandTop, zs, -201.2, CURB - 1.2, ze, wood, { material = Enum.Material.WoodPlanks })
				box("BeachStep", -206.2, sandTop, zs, -203.7, CURB - 1.8, ze, wood, { material = Enum.Material.WoodPlanks })
			else
				-- the granite edge along the promenade runs on past the beach cafe too (user 2026-10-24);
				-- by the cafe only along its front: the corners have the cafe's own edge
				local ea, eb = zs, ze
				if ze > CAFE_ZS and zs < CAFE_ZN then ea, eb = math.max(zs, CAFE_Z0), math.min(ze, CAFE_Z1) end
				if eb > ea then box("BeachStepEdge", -198.7, sandTop, ea, -198, CURB + 0.1, eb, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite }) end
			end
		end
	end
	box("SeaRoad", -182, 0, ROAD_N, -158, 0.12, z1, ASPHALT, { material = Enum.Material.Asphalt })
	do -- the U-turn bulb, the paved end beyond it, U-turn marking and sign
		local BR = 12
		local bc = Vector3.new(-170, 0, ROAD_N)
		-- the half circle past the straight road: a flat fan (a cylinder's round
		-- face draws the asphalt lighter than the road)
		for k = 0, 11 do
			local a0, a1 = math.pi * k / 12, math.pi * (k + 1) / 12
			local function ap(a) return Vector3.new(bc.X + BR * math.cos(a), 0.06, bc.Z - BR * math.sin(a)) end
			wedgeTri("SeaRoadEnd", Vector3.new(bc.X, 0.06, bc.Z), ap(a0), ap(a1), 0.12, ASPHALT, { material = Enum.Material.Asphalt })
		end
		-- the same surface street_dress gives the roads (concrete + OHU_Asphalt variant)
		for _, p in ipairs(T:GetChildren()) do
			if p.Name == "SeaRoadEnd" and p:IsA("BasePart") then
				p.Material = Enum.Material.Concrete
				p.MaterialVariant = "OHU_Asphalt"
				p.Color = Color3.fromRGB(78, 79, 83)
			end
		end
		local PAVE = Color3.fromRGB(175, 135, 120)
		local po = { material = Enum.Material.Brick }
		-- paving over the old road north of the bulb, at the promenade's height
		box("Promenade", -182, 0, z0, -158, CURB, ROAD_N - BR, PAVE, po)
		-- the two corners between the bulb and the square end: fans of triangles
		local function arcP(a) return Vector3.new(bc.X + BR * math.cos(a), CURB / 2, bc.Z - BR * math.sin(a)) end
		for _, cn in ipairs({ { Vector3.new(-158, CURB / 2, ROAD_N - BR), 0, 90 }, { Vector3.new(-182, CURB / 2, ROAD_N - BR), 90, 180 } }) do
			local N = 6
			for k = 0, N - 1 do
				local a0 = math.rad(cn[2] + (cn[3] - cn[2]) * k / N)
				local a1 = math.rad(cn[2] + (cn[3] - cn[2]) * (k + 1) / N)
				wedgeTri("Promenade", cn[1], arcP(a0), arcP(a1), CURB, PAVE, po)
			end
		end
		-- 유턴 노면표시 on the northbound lane (it drives toward -z): up the right,
		-- round to the left, the head pointing back south
		local function uArrow(frame: CFrame, s, color, opt)
			local w = 0.32 * s
			local function P(x, y) return (frame * CFrame.new(x * s, y * s, 0)).Position end
			local function stroke(a: Vector3, b: Vector3)
				local d = (b - a)
				part("UTurnArrow", Vector3.new(d.Magnitude + w * 0.8, 0.04, w), CFrame.fromMatrix((a + b) / 2, d.Unit, frame.ZVector), color, opt)
			end
			stroke(P(1, -2.2), P(1, 1))
			local prev = P(1, 1)
			for k = 1, 8 do
				local a = math.pi * k / 8
				local p = P(math.cos(a), 1 + math.sin(a))
				stroke(prev, p)
				prev = p
			end
			stroke(P(-1, 1), P(-1, -0.4))
			local o = {}
			for k2, v in pairs(opt) do o[k2] = v end
			wedgeTri("UTurnArrow", P(-1.75, -0.4), P(-0.25, -0.4), P(-1, -1.6), 0.04, color, o)
		end
		-- on the road: x right = +x, "up" along the lane = -z, normal = up
		uArrow(CFrame.fromMatrix(Vector3.new(-162, 0.15, ROAD_N + 22), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1)), 1.6, WHITE, { nocol = true })
		-- 유턴 지시표지 (blue round sign, white U arrow) on the east sidewalk, facing the northbound traffic
		local sp = Vector3.new(-154, CURB, ROAD_N + 14)
		vcyl("UTurnSignPost", sp, 0.25, 7.2, Color3.fromRGB(150, 152, 156), { material = Enum.Material.Metal })
		part("UTurnSign", Vector3.new(0.12, 2.6, 2.6), CFrame.new(sp + Vector3.new(0, 6.6, 0.1)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(20, 80, 170), { shape = Enum.PartType.Cylinder })
		uArrow(CFrame.fromMatrix(sp + Vector3.new(0, 6.6, 0.18), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)), 0.45, Color3.new(1, 1, 1), { nocol = true })
	end
	do -- the wooden steps go on north of STEP_N to the wall, curving west and
		-- getting narrower (user 2026-10-24, brown line); the paving fills in behind
		local sandTop = CURB - BEACH_DROP
		local wood = Color3.fromRGB(120, 88, 62)
		local M = 8
		local function outerX(s) return -206.2 - 22 * s * s end
		local function depth(s) return 7.5 * (1 - 0.66 * s) end
		local function zAt(s) return STEP_N + (z0 - STEP_N) * s end
		for i = 0, M - 1 do
			local s0, s1 = i / M, (i + 1) / M
			local za, zb = zAt(s0), zAt(s1)
			local function quad(name, xa0, xa1, xb0, xb1, top, color, mat)
				local y = (top + sandTop) / 2
				local th = top - sandTop
				local o = { material = mat }
				wedgeTri(name, Vector3.new(xa0, y, za), Vector3.new(xa1, y, za), Vector3.new(xb1, y, zb), th, color, o)
				wedgeTri(name, Vector3.new(xa0, y, za), Vector3.new(xb1, y, zb), Vector3.new(xb0, y, zb), th, color, o)
			end
			local oa, ob = outerX(s0), outerX(s1)
			local da, db = depth(s0), depth(s1)
			local ia, ib = oa + da, ob + db -- inner edge (the top of the steps)
			-- paving from the promenade's edge out to the top of the steps
			if ia < -198.05 or ib < -198.05 then quad("Promenade", ia, -198, ib, -198, CURB, Color3.fromRGB(175, 135, 120), Enum.Material.Brick) end
			quad("BeachStepEdge", ia - 0.7, ia, ib - 0.7, ib, CURB + 0.1, Color3.fromRGB(196, 194, 188), Enum.Material.Granite)
			for k = 1, 3 do
				local fa0, fa1 = ia - 0.7 - (da - 0.7) * k / 3, ia - 0.7 - (da - 0.7) * (k - 1) / 3
				local fb0, fb1 = ib - 0.7 - (db - 0.7) * k / 3, ib - 0.7 - (db - 0.7) * (k - 1) / 3
				quad("BeachStep", fa0, fa1, fb0, fb1, CURB - 0.6 * k, wood, Enum.Material.WoodPlanks)
			end
		end
		-- past the wall corner the red paving and the narrow steps go on north
		-- along the park wall (user 2026-10-24: it stopped dead at the corner)
		local ox, d = outerX(1), depth(1)
		local ix = ox + d
		local zN = -1400
		box("Promenade", ix, 0, zN, -207.25, CURB, z0, Color3.fromRGB(175, 135, 120), { material = Enum.Material.Brick })
		box("BeachStepEdge", ix - 0.7, sandTop, zN, ix, CURB + 0.1, z0, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
		for k = 1, 3 do
			local x0s, x1s = ix - 0.7 - (d - 0.7) * k / 3, ix - 0.7 - (d - 0.7) * (k - 1) / 3
			box("BeachStep", x0s, sandTop, zN, x1s, CURB - 0.6 * k, z0, wood, { material = Enum.Material.WoodPlanks })
		end
	end
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
	local CROSS = { -40.7, 40.7 } -- the T junction pair (the -400 crossing went with the road's end, 2026-10-24)
	local BIKE_X = { { -34.7, -27.7 }, { 27.7, 34.7 } } -- bike crossings in line with the sidewalk bike lanes (z ±29.2..33.2)
	for _, seg in ipairs({ { ROAD_N, -24 }, { 24, z1 } }) do -- lane paint stops at the junction with the west road
		paint("EdgeLine", -174.2, seg[1], -173.8, seg[2], WHITE)
		paint("CenterLine", -166.2, math.max(seg[1], ROAD_N + 12), -165.8, seg[2], YELLOW) -- ends where the bulb opens
		for zz = seg[1] + 10, seg[2] - 6, 80 do -- every other symbol of the old 40 (user 2026-10-24)
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
	-- (no red band through the T junction: user 2026-10-24)
	-- 도로교통법 시행규칙 별표 6: no centre line inside the junction (it stops at
	-- the crossings, as here); 좌회전 유도선 (white dashes inside the junction)
	-- for the two left turns of the T: from the west road (westbound, z < 0)
	-- into the southbound lane (x -170), and from the southbound lane into the
	-- west road's eastbound side (z > 0). No 정차금지지대: that is for junctions
	-- that queue up, this one is quiet. (user 2026-10-24: check the centre by law)
	local function guide(p0: Vector3, d0: Vector3, p2: Vector3, d2: Vector3)
		local c1, c2 = p0 + d0 * 11, p2 - d2 * 11 -- long handles: a smooth quarter curve
		local function bez(tt)
			local s = 1 - tt
			return p0 * s ^ 3 + c1 * 3 * s * s * tt + c2 * 3 * s * tt * tt + p2 * tt ^ 3
		end
		local steps, last, dist, on = 60, bez(0), 0, true
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
	guide(Vector3.new(-158, 0, -4), Vector3.new(-1, 0, 0), Vector3.new(-170, 0, 24), Vector3.new(0, 0, 1))
	guide(Vector3.new(-170, 0, -24), Vector3.new(0, 0, 1), Vector3.new(-158, 0, 4), Vector3.new(1, 0, 0))
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
		for _, x in ipairs({ -170 }) do -- one symbol per bike crossing (user 2026-10-24)
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
		-- the Dream Aquarium (dome, floor, pier, photo spot and labels) is gone
		-- (user 2026-10-24); the sea comes back where the dome kept it dry
		for _, c in ipairs(beachZone:GetChildren()) do
			if c:IsA("BasePart") then
				local p = c.Position
				local nearDome = math.abs(p.X + 368) < 50 and math.abs(p.Z + 150) < 50
				if c.Name == "DreamAquarium_Dome" or c.Name == "DomeFloor" or c.Name == "DomePier" or (nearDome and (c.Name == "PhotoSpot" or c.Name == "Label")) then
					c.CFrame = undo * c.CFrame
					c:SetAttribute("HomeZone", beachZone.Name)
					c.Parent = hidden
				end
			end
		end
		workspace.Terrain:FillBlock(CFrame.new(-368, -9.5, -150), Vector3.new(92, 13, 92), Enum.Material.Water)
		-- the beach cafe's 물멍 pool holds the same terrain water as the sea (user 2026-10-24)
		-- one whole 4-stud cell layer, y -4..0, in the closed basin under the cafe
		-- floor: surface at y 0, below the floor top (0.6). Since layout v8 the
		-- cafe moved, so the water goes where its channel (SplashZone) is now,
		-- in whole cells round the opening
		local cafe = beachZone:FindFirstChild("BeachCafe")
		local splash = cafe and cafe:FindFirstChild("SplashZone")
		if splash then
			local lo, hi = splash.Position - splash.Size / 2, splash.Position + splash.Size / 2
			local ax0, ax1 = math.floor(lo.X / 4) * 4, math.ceil(hi.X / 4) * 4
			local az0, az1 = math.floor(lo.Z / 4) * 4, math.ceil(hi.Z / 4) * 4
			workspace.Terrain:FillBlock(CFrame.new((ax0 + ax1) / 2, -2, (az0 + az1) / 2), Vector3.new(ax1 - ax0, 4, az1 - az0), Enum.Material.Water)
		end
		for _, old in ipairs(beachZone:GetChildren()) do
			if old:IsA("Model") and old.Name == "PalmTree" then
				local cf, size = old:GetBoundingBox()
				local foot = Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)
				-- north of z -400 the steps curve west: palms there go out onto the sand (user 2026-10-24)
				if foot.Z < -400 and foot.X > -236 then foot = Vector3.new(-236, foot.Y, foot.Z) end
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
		local atCafe = zz > CAFE_ZS - 8 and zz < CAFE_ZN + 8 -- the beach cafe front (user 2026-10-24: no lamp or bench there)
		if not near and not onBench and not atCafe then streetLamp(Vector3.new(-196.5, CURB, zz), Vector3.new(1, 0, 0)) end
	end
	for zz = z0 + 28, z1, 60 do
		if zz + 6 > CAFE_ZS - 8 and zz < CAFE_ZN + 8 then continue end -- not along the beach cafe (user 2026-10-24)
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

------------------------------------------------------- palace stone wall (궁궐 담장)
-- The wall around the hanok village (user photos 2026-10-23): a granite
-- plinth, dressed beige stone blocks above, a small tiled roof on top (eave,
-- two tile slopes, dark ridge). `out` = the side facing the street: a strip
-- at its foot lights the wall at night (NightGlow, photo of the lit wall).
local PALACE_H = 8.4 -- top of the stone, the roof sits on it
-- warm light washing up a wall at night (a gradient on a thin sheet in front
-- of it, NightWash: NightGlowController shows it after dark). cf = centre of
-- the sheet, looking out of the wall
local function nightWash(cf: CFrame, w: number, h: number, parent: Instance)
	local p = part("NightWash", Vector3.new(w, h, 0.05), cf, Color3.new(1, 1, 1), { parent = parent, nocol = true, transparency = 1 })
	p.CanQuery = false
	p.CastShadow = false
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 4
	g.LightInfluence = 0
	g.Enabled = false
	g.Parent = p
	local fr = Instance.new("Frame")
	fr.Size = UDim2.fromScale(1, 1)
	fr.BorderSizePixel = 0
	fr.BackgroundColor3 = Color3.fromRGB(255, 196, 130)
	fr.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90 -- 0 at the top, 1 at the foot
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.78), NumberSequenceKeypoint.new(1, 0.4) })
	grad.Parent = fr
	CS:AddTag(p, "NightWash")
	return p
end
-- 기와 roof module for the wall tops (user pick: candidate 2, made regular,
-- 2026-10-23): one 8-stud piece built from exact parts and merged (CSG) into
-- a single part, then cloned along the walls (identical copies are cheap to
-- draw). Per side: 8 round cover tiles down the slope, a round end cap on
-- each (수막새), a hanging drip tile between them (암막새); a stacked flat
-- ridge on top. Local frame: X along the wall, Y up, origin = wall top centre.
local GIWA_LEN = 8
local GIWA_OFFSET = Vector3.zero
local giwaTemplate: BasePart? = nil
local function giwaModule(): BasePart
	if giwaTemplate then return giwaTemplate end
	local TILE = Color3.fromRGB(64, 68, 72)
	local O = Vector3.new(0, 3000, 0) -- built away from the map
	local tmp = Instance.new("Model")
	tmp.Name = "GiwaBuild"
	tmp.Parent = workspace
	local parts = {}
	local function add(size, cf, shape, class)
		local p = part("Giwa", size, CFrame.new(O) * cf, TILE, { parent = tmp, shape = shape, class = class, material = Enum.Material.Slate })
		table.insert(parts, p)
		return p
	end
	local BASE, RISE, RUN = 0.25, 0.8, 1.75
	add(Vector3.new(GIWA_LEN, BASE, 2 * RUN), CFrame.new(0, BASE / 2, 0)) -- bed on the wall
	local L = math.sqrt(RUN * RUN + RISE * RISE)
	for _, s in ipairs({ -1, 1 }) do
		local sv = Vector3.new(0, 0, s)
		-- the tile field (concave tiles read as the slope between the covers)
		add(Vector3.new(GIWA_LEN, RISE, RUN), CFrame.fromMatrix(Vector3.new(0, BASE + RISE / 2, s * RUN / 2), Vector3.yAxis:Cross(-sv), Vector3.yAxis, -sv), nil, "WedgePart")
		local d = Vector3.new(0, -RISE, s * RUN).Unit -- down the slope, outward
		local nrm = Vector3.new(0, RUN, s * RISE).Unit -- out of the slope
		local midS = Vector3.new(0, BASE + RISE / 2, s * RUN / 2)
		-- photo: tight rows, a concave tile trough between every two covers
		local PITCH = GIWA_LEN / 10
		for i = 0, 9 do
			local x = -GIWA_LEN / 2 + PITCH * (i + 0.5)
			local c = midS + Vector3.new(x, 0, 0) + nrm * 0.12 + d * 0.1
			add(Vector3.new(L + 0.2, 0.34, 0.34), CFrame.fromMatrix(c, d, nrm), Enum.PartType.Cylinder) -- cover tile
			local e = c + d * ((L + 0.2) / 2 + 0.04)
			add(Vector3.new(0.08, 0.46, 0.46), CFrame.fromMatrix(e, d, nrm), Enum.PartType.Cylinder) -- end cap (수막새)
			add(Vector3.new(0.05, 0.3, 0.3), CFrame.fromMatrix(e + d * 0.06, d, nrm), Enum.PartType.Cylinder) -- its raised centre
			-- concave tile edge peeking out between covers at the eave
			local xm = x + PITCH / 2
			if xm < GIWA_LEN / 2 - 0.01 then
				add(Vector3.new(0.5, 0.06, 0.22), CFrame.fromMatrix(midS + Vector3.new(xm, 0, 0) + d * (L / 2 - 0.05) + nrm * 0.02, Vector3.xAxis, nrm))
			end
		end
		-- drip tiles (암막새): a curved hanging plate under the eave between
		-- the caps, the scalloped edge of the photo
		local eave = Vector3.new(0, BASE - 0.12, s * (RUN + 0.02))
		for i = 0, 10 do
			local x = -GIWA_LEN / 2 + PITCH * i
			local w = if i == 0 or i == 10 then PITCH / 2 - 0.04 else PITCH - 0.08
			local xc = if i == 0 then x + w / 2 elseif i == 10 then x - w / 2 else x
			add(Vector3.new(w, 0.42, 0.07), CFrame.fromMatrix(eave + Vector3.new(xc, 0, 0), Vector3.xAxis, Vector3.new(0, 1, -s * 0.5).Unit))
			add(Vector3.new(0.07, w * 0.72, w * 0.72), CFrame.fromMatrix(eave + Vector3.new(xc, -0.13, s * 0.07), Vector3.new(0, 0, s), Vector3.yAxis), Enum.PartType.Cylinder) -- round lower edge
		end
	end	-- stacked flat ridge (용마루)
	local top = BASE + RISE
	add(Vector3.new(GIWA_LEN, 0.24, 1.2), CFrame.new(0, top + 0.06, 0))
	add(Vector3.new(GIWA_LEN, 0.2, 0.86), CFrame.new(0, top + 0.26, 0))
	add(Vector3.new(GIWA_LEN, 0.2, 0.64), CFrame.new(0, top + 0.46, 0))
	add(Vector3.new(GIWA_LEN, 0.16, 0.42), CFrame.new(0, top + 0.64, 0))
	local first = table.remove(parts, 1)
	local ok, u = pcall(function() return first:UnionAsync(parts) end)
	local result: BasePart
	if ok and u then
		u.Name = "GiwaRoof"
		u.UsePartColor = true
		u.Color = TILE
		u.Material = Enum.Material.Slate
		pcall(function() u.CollisionFidelity = Enum.CollisionFidelity.Box end)
		u.Parent = nil
		result = u
	else
		warn("giwa union failed", u)
		first.Size = Vector3.new(GIWA_LEN, 1.6, 3.6)
		first.Parent = nil
		result = first
	end
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CastShadow = false
	GIWA_OFFSET = result.Position - O -- its centre from the module origin
	result.CFrame = CFrame.new(result.Position)
	tmp:Destroy()
	giwaTemplate = result
	return result
end
local function palaceWall(a: Vector3, b: Vector3, parent: Instance, out: Vector3?)
	local len = (b - a).Magnitude
	if len < 0.5 then return end
	local along = (b - a).Unit
	local mid = (a + b) / 2
	local side = Vector3.yAxis:Cross(along) -- horizontal, square to the wall
	local cf = CFrame.fromMatrix(Vector3.new(mid.X, 0, mid.Z), side, Vector3.yAxis) -- local Z along the wall
	local GRANITE = Color3.fromRGB(196, 190, 178)
	local STONE = Color3.fromRGB(205, 192, 168) -- beige stone (Cobblestone: Brick read as red brick)
	local TILE = Color3.fromRGB(64, 66, 72)
	-- the stone pattern runs down to the ground (user 2026-10-23: no plain base)
	part("PalaceWallStone", Vector3.new(2.2, PALACE_H, len), cf * CFrame.new(0, PALACE_H / 2, 0), STONE, { parent = parent, material = Enum.Material.Cobblestone })
	-- tiled roof: the 8-stud giwa module repeated, stretched a little so a
	-- whole number of modules fills the run
	local n = math.max(1, math.floor(len / GIWA_LEN + 0.5))
	local seg = len / n
	for k = 0, n - 1 do
		local m = giwaModule():Clone()
		m.Size = Vector3.new(m.Size.X * seg / GIWA_LEN, m.Size.Y, m.Size.Z)
		local c = a + along * (seg * (k + 0.5))
		m.CFrame = CFrame.fromMatrix(Vector3.new(c.X, PALACE_H, c.Z), along, Vector3.yAxis) * CFrame.new(GIWA_OFFSET)
		m.Parent = parent
	end
	if out then
		local o = Vector3.new(out.X, 0, out.Z).Unit
		local p = Vector3.new(mid.X, 0.312, mid.Z) + o * 1.45 -- snapped onto the ground at the end of the build
		-- long side along the wall, its front face (the light) toward the wall
		local x = if Vector3.yAxis:Cross(along):Dot(o) > 0 then -along else along -- (x × up = o, so -Z looks at -o)
		local glow = part("WallUplight", Vector3.new(len - 0.4, 0.02, 0.06), CFrame.fromMatrix(p, x, Vector3.yAxis), Color3.fromRGB(255, 205, 150), { parent = parent, nocol = true })
		glow.CastShadow = false
		glow:SetAttribute("NightRange", 14)
		glow:SetAttribute("NightBrightness", 3)
		glow:SetAttribute("NightAngle", 120)
		-- the wash on the wall face above the strip (its front looks out, +o)
		local wx = if Vector3.yAxis:Cross(along):Dot(o) > 0 then along else -along
		local wp = Vector3.new(mid.X, PALACE_H / 2 + 0.1, mid.Z) + o * 1.13
		nightWash(CFrame.fromMatrix(wp, wx, Vector3.yAxis), len, PALACE_H - 0.2, parent)
		CS:AddTag(glow, "NightGlow")
	end
end

------------------------------------------------------- 광화문 + plaza + 해태 + hills
-- User plan + photos 2026-10-23: the hanok village west entrance is 광화문
-- (stone base with three round arches and red doors, a band of loopholes,
-- a two-storey pavilion with red columns, dancheong and two tiled roofs,
-- the plaque 門化光); in front, from the sidewalk to the gate: a stone path
-- between two stone balustrades (월대 난간), a lawn on each side, and two
-- 해태 on plinths at the street end of the lawns, beside the path. The
-- village wall is the palace stone wall above, lit from its foot at night.
do
	local G = Instance.new("Model")
	G.Name = "Gwanghwamun"
	G.Parent = T
	local stone = Color3.fromRGB(214, 208, 194)
	local granite = Color3.fromRGB(200, 196, 188)
	local wood = Color3.fromRGB(160, 50, 38)
	local roofC = Color3.fromRGB(60, 62, 66)
	local DANCHEONG = Color3.fromRGB(50, 120, 95)
	-- the gate sits on the village wall line: the wall meets the middle of its
	-- sides (user 2026-10-23); x 90..104, the wall at x 97
	local gx0, gx1, gz0, gz1 = 90, 104, 140, 196
	local H = 12
	local TOP = H + 4.6 -- the stone base and its band reach the green box (user 2026-10-23)
	local LIFT = 1.6 -- everything above the lower green box goes up so the box shows under the eave
	-- stone base with 3 round arches (centre 10 wide, sides 6): one block, CSG
	local ARCHES = { { 168, 10, 9.5 }, { 152, 6, 7.5 }, { 184, 6, 7.5 } } -- centre z, width, height
	do
		local base = box("GateStone", gx0, 0, gz0, gx1, TOP - 2.4, gz1, stone, { parent = G, material = Enum.Material.Slate })
		local holes = {}
		for _, a in ipairs(ARCHES) do
			local r = a[2] / 2
			table.insert(holes, part("ArchCut", Vector3.new(gx1 - gx0 + 2, a[3] - r + 0.1, a[2]), CFrame.new((gx0 + gx1) / 2, (a[3] - r) / 2 - 0.05, a[1]), stone, { parent = G }))
			table.insert(holes, part("ArchCut", Vector3.new(gx1 - gx0 + 2, a[2], a[2]), CFrame.new((gx0 + gx1) / 2, a[3] - r, a[1]), stone, { parent = G, shape = Enum.PartType.Cylinder }))
		end
		local was = G.Parent
		G.Parent = workspace -- CSG only works in the Workspace
		local ok, res = pcall(function() return base:SubtractAsync(holes) end)
		for _, h in ipairs(holes) do h:Destroy() end
		if ok and res then
			res.Name = "GateStone"
			res.UsePartColor = true
			res.Material = Enum.Material.Slate
			res.Anchored = true
			res.Parent = G
			base:Destroy()
		end
		G.Parent = was
		-- red doors standing open against the sides of each arch
		for _, a in ipairs(ARCHES) do
			local r = a[2] / 2
			for _, s in ipairs({ -1, 1 }) do
				part("GateDoorLeaf", Vector3.new(r, a[3] - r, 0.3), CFrame.new((gx0 + gx1) / 2 + r / 2, (a[3] - r) / 2, a[1] + s * (r - 0.15)), wood, { parent = G })
			end
		end
	end
	-- 광화문 details (user photos 2026-10-23): dressed granite blocks with
	-- joints on the stone base, a voussoir ring around each arch with a carved
	-- head at the top, a white cornice and a dark brick band with white key-
	-- pattern panels and grilles, small stone spouts; a dancheong pavilion
	-- (green walls, red posts, painted bracket bands, rows of green rafters
	-- with painted ends), tiled roofs (the cover-tile module of the stone
	-- walls, D-143), white ridges with dark end blocks and 잡상 figures on the
	-- gable ridges; the dark plaque 門化光 on the upper storey.
	local JOINT = Color3.fromRGB(176, 170, 158)
	local LIGHT = Color3.fromRGB(228, 222, 208)
	local RED = Color3.fromRGB(176, 44, 36)
	local GREEN = Color3.fromRGB(40, 116, 88)
	local nopt = { parent = G, nocol = true }
	local function deco(p: BasePart)
		p.CastShadow = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end
	-- one template made of parts, merged once and cloned (cheap to draw)
	local function unionTemplate(name: string, keepColors: boolean, build: (add: (Vector3, CFrame, Color3, Enum.PartType?) -> ()) -> ()): (BasePart, Vector3)
		local O = Vector3.new(0, 3200, 0)
		local tmp = Instance.new("Model")
		tmp.Parent = workspace
		local list = {}
		build(function(size, cf, color, shape)
			table.insert(list, part(name, size, CFrame.new(O) * cf, color, { parent = tmp, shape = shape, material = Enum.Material.SmoothPlastic }))
		end)
		local first = table.remove(list, 1)
		local ok, u = pcall(function() return first:UnionAsync(list) end)
		local res: BasePart = first
		if ok and u then
			u.UsePartColor = not keepColors
			res = u
		end
		res.Name = name
		res.Anchored = true
		res.CanCollide = false
		res.CanTouch = false
		res.CanQuery = false
		res.CastShadow = false
		pcall(function() (res :: any).CollisionFidelity = Enum.CollisionFidelity.Box end)
		res.Parent = nil
		local off = res.Position - O
		tmp:Destroy()
		return res, off
	end
	local function placeTemplate(t: BasePart, off: Vector3, frame: CFrame, sx: number, sz: number)
		local c = t:Clone()
		c.Size = Vector3.new(t.Size.X * sx, t.Size.Y, t.Size.Z * sz)
		c.CFrame = frame * CFrame.new(off.X * sx, off.Y, off.Z * sz)
		c.Parent = G
		return c
	end
	-- dancheong band painted on a face (SurfaceGui cells: red / blue stripes,
	-- an orange flower in the middle)
	local function dancheongGui(p: BasePart, face: Enum.NormalId)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 12
		g.LightInfluence = 0.7
		g.Parent = p
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = GREEN
		bg.BorderSizePixel = 0
		bg.Parent = g
		local w = if face == Enum.NormalId.Left or face == Enum.NormalId.Right then p.Size.Z else p.Size.X
		local n = math.max(1, math.floor(w / 2))
		for i = 0, n - 1 do
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromScale(1 / n, 1)
			cell.Position = UDim2.fromScale(i / n, 0)
			cell.Parent = bg
			for _, s in ipairs({ { 0, Color3.fromRGB(190, 50, 40) }, { 0.82, Color3.fromRGB(46, 84, 164) } }) do
				local st = Instance.new("Frame")
				st.BorderSizePixel = 0
				st.BackgroundColor3 = s[2]
				st.Size = UDim2.fromScale(1, 0.18)
				st.Position = UDim2.fromScale(0, s[1])
				st.Parent = cell
			end
			local fl = Instance.new("Frame")
			fl.AnchorPoint = Vector2.new(0.5, 0.5)
			fl.Position = UDim2.fromScale(0.5, 0.5)
			fl.Size = UDim2.fromScale(0.5, 0.5)
			fl.BackgroundColor3 = Color3.fromRGB(236, 150, 52)
			fl.BorderSizePixel = 0
			local ar = Instance.new("UIAspectRatioConstraint")
			ar.Parent = fl
			local cr = Instance.new("UICorner")
			cr.CornerRadius = UDim.new(0.5, 0)
			cr.Parent = fl
			local dot = fl:Clone()
			dot.Size = UDim2.fromScale(0.45, 0.45)
			dot.BackgroundColor3 = Color3.fromRGB(250, 246, 236)
			dot.Parent = fl
			fl.Parent = cell
		end
	end

	-- stone base: joints, arch rings, carved heads (both long faces)
	local step = (TOP - 2.6) / 9
	local function blocked(y: number): { { number } }
		local list = {}
		for _, a in ipairs(ARCHES) do
			local r = a[2] / 2
			local spring = a[3] - r
			local half: number? = nil
			if y <= spring then
				half = r + 0.15
			else
				local R = r + 0.95
				local dy = y - spring
				if dy < R then half = math.sqrt(R * R - dy * dy) end
			end
			if half then table.insert(list, { a[1] - half, a[1] + half }) end
		end
		return list
	end
	local function free(y: number, z: number): boolean
		for _, b in ipairs(blocked(y)) do
			if z > b[1] and z < b[2] then return false end
		end
		return true
	end
	for _, fc in ipairs({ { gx0, -1 }, { gx1, 1 } }) do
		local fx, s = fc[1], fc[2]
		local out = Vector3.new(s, 0, 0)
		-- horizontal joints, split around the arches
		for k = 1, 8 do
			local y = k * step
			local z = gz0 + 0.05
			local cuts = blocked(y)
			table.sort(cuts, function(p, q) return p[1] < q[1] end)
			local spans = {}
			for _, c in ipairs(cuts) do
				if c[1] > z then table.insert(spans, { z, c[1] }) end
				z = math.max(z, c[2])
			end
			if z < gz1 - 0.05 then table.insert(spans, { z, gz1 - 0.05 }) end
			for _, sp in ipairs(spans) do
				deco(part("StoneJoint", Vector3.new(0.06, 0.07, sp[2] - sp[1]), CFrame.new(fx + s * 0.02, y, (sp[1] + sp[2]) / 2), JOINT, nopt))
			end
		end
		-- vertical joints, staggered course by course
		for k = 0, 8 do
			local y0, y1 = k * step, (k + 1) * step
			local z = gz0 + 1.5 + (k % 2) * 1.5
			while z < gz1 - 0.5 do
				if free(y0 + 0.05, z) and free(y1 - 0.05, z) then
					deco(part("StoneJoint", Vector3.new(0.06, y1 - y0, 0.07), CFrame.new(fx + s * 0.02, (y0 + y1) / 2, z), JOINT, nopt))
				end
				z += 3
			end
		end
		-- arch rings (voussoirs) and the carved head on top of each arch
		for _, a in ipairs(ARCHES) do
			local r = a[2] / 2
			local spring = a[3] - r
			local N = if a[2] > 8 then 11 else 7
			for i = 0, N - 1 do
				local a0, a1 = math.pi * i / N, math.pi * (i + 1) / N
				local am = (a0 + a1) / 2
				local rr = r + 0.45
				local p = Vector3.new(fx + s * 0.06, spring + math.sin(am) * rr, a[1] + math.cos(am) * rr)
				local tangent = Vector3.new(0, math.cos(am), -math.sin(am))
				local radial = Vector3.new(0, math.sin(am), math.cos(am))
				local len = 2 * rr * math.sin((a1 - a0) / 2) - 0.08
				deco(part("ArchStone", Vector3.new(len, 0.9, 0.12), CFrame.fromMatrix(p, tangent, radial), LIGHT, { parent = G, nocol = true, material = Enum.Material.Slate }))
			end
			for _, e in ipairs({ -1, 1 }) do -- impost blocks at the spring line
				deco(part("ArchImpost", Vector3.new(0.25, 0.35, 1.1), CFrame.new(fx + s * 0.12, spring - 0.1, a[1] + e * (r + 0.45)), LIGHT, { parent = G, nocol = true, material = Enum.Material.Slate }))
			end
			local hy = a[3] + 0.5
			deco(part("ArchHead", Vector3.new(0.5, 0.9, 0.9), CFrame.new(fx + s * 0.25, hy, a[1]), LIGHT, { parent = G, nocol = true, material = Enum.Material.Slate }))
			deco(part("ArchHeadFace", Vector3.new(0.5, 0.55, 0.55), CFrame.new(fx + s * 0.5, hy + 0.05, a[1]), LIGHT, { parent = G, nocol = true, material = Enum.Material.Slate, shape = Enum.PartType.Ball }))
		end
		-- small stone spouts under the cornice
		for z = gz0 + 5, gz1 - 4, 9.2 do
			deco(part("StoneSpout", Vector3.new(0.7, 0.45, 0.45), CFrame.new(fx + s * 0.35, TOP - 3.1, z), LIGHT, { parent = G, nocol = true, material = Enum.Material.Slate }))
			-- a round hole in the block end (user: no ball)
			deco(part("StoneSpoutHole", Vector3.new(0.04, 0.26, 0.26), CFrame.new(fx + s * 0.71, TOP - 3.1, z), Color3.fromRGB(40, 38, 36), { parent = G, nocol = true, shape = Enum.PartType.Cylinder }))
		end
	end
	-- white cornice, then the dark brick band with key-pattern panels and grilles
	box("GateCornice", gx0 - 0.35, TOP - 2.6, gz0 - 0.35, gx1 + 0.35, TOP - 2.4, gz1 + 0.35, LIGHT, { parent = G, material = Enum.Material.Slate })
	box("GateBrickBand", gx0 - 0.15, TOP - 2.4, gz0 - 0.15, gx1 + 0.15, TOP, gz1 + 0.15, Color3.fromRGB(72, 74, 80), { parent = G, material = Enum.Material.Brick })
	local function panel(p: Vector3, out: Vector3, grille: boolean)
		local pp = deco(part("BandPanel", Vector3.new(1.8, 1.8, 0.05), CFrame.lookAt(p, p + out), Color3.fromRGB(246, 244, 238), nopt))
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.8
		g.Parent = pp
		local function frame(size: number, color: Color3?, stroke: Color3?, thick: number?)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(size, size)
			f.BorderSizePixel = 0
			f.BackgroundTransparency = if color then 0 else 1
			if color then f.BackgroundColor3 = color end
			if stroke then
				local st = Instance.new("UIStroke")
				st.Color = stroke
				st.Thickness = thick or 3
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Parent = f
			end
			f.Parent = g
			return f
		end
		if grille then
			for i = 1, 5 do
				local slat = Instance.new("Frame")
				slat.BorderSizePixel = 0
				slat.BackgroundColor3 = Color3.fromRGB(90, 92, 98)
				slat.Size = UDim2.fromScale(0.07, 0.8)
				slat.Position = UDim2.fromScale(0.08 + (i - 1) * 0.19, 0.1)
				slat.Parent = g
			end
		else
			local KEY = Color3.fromRGB(196, 58, 46)
			frame(0.88, nil, KEY, 4)
			frame(0.66, nil, KEY, 3)
			frame(0.42, nil, KEY, 2)
			frame(0.16, KEY)
		end
	end
	for _, fz in ipairs({ { gz0 - 0.18, -1 }, { gz1 + 0.18, 1 } }) do -- the short sides (photo: the band runs round)
		for i = 0, 2 do
			panel(Vector3.new(gx0 + 2.5 + (gx1 - gx0 - 5) * i / 2, TOP - 1.2, fz[1]), Vector3.new(0, 0, fz[2]), i == 1)
		end
		for k = 1, 8 do
			deco(part("StoneJoint", Vector3.new(gx1 - gx0 - 0.1, 0.07, 0.06), CFrame.new((gx0 + gx1) / 2, k * step, fz[1] + fz[2] * -0.16), JOINT, nopt))
		end
		for k = 0, 8 do
			for xx = gx0 + 1.5 + (k % 2) * 1.5, gx1 - 0.5, 3 do
				deco(part("StoneJoint", Vector3.new(0.07, step, 0.06), CFrame.new(xx, (k + 0.5) * step, fz[1] + fz[2] * -0.16), JOINT, nopt))
			end
		end
	end
	local nP = 14
	for i = 0, nP - 1 do
		local z = gz0 + 2 + (gz1 - gz0 - 4) * i / (nP - 1)
		for _, fc in ipairs({ { gx0 - 0.18, -1 }, { gx1 + 0.18, 1 } }) do
			panel(Vector3.new(fc[1], TOP - 1.2, z), Vector3.new(fc[2], 0, 0), i % 4 == 2)
		end
	end

	-- storeys: plain green boxes (no columns, user 2026-10-23) wearing the
	-- bracket / dancheong pattern cut from the user's 광화문 photo
	-- (user 2026-10-27) the long faces (front to the street and the back, ±X)
	-- show the picture twice side by side, the short end faces once
	local function patterned(p: BasePart, image: string, _tileW: number)
		for _, fce in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }) do
			local tx = Instance.new("Texture")
			tx.Texture = image
			tx.Face = fce
			tx.StudsPerTileV = p.Size.Y
			local long = fce == Enum.NormalId.Left or fce == Enum.NormalId.Right
			tx.StudsPerTileU = if long then p.Size.Z / 2 else p.Size.X
			tx.Parent = p
		end
	end
	local box1 = box("PavilionBox", gx0 + 2.5, TOP, gz0 + 5, gx1 - 2.5, H + 7.6 + LIFT, gz1 - 5, GREEN, { parent = G })
	patterned(box1, "rbxassetid://88257154059913", (box1.Size.Y) * 272 / 31) -- brighter band (user 2026-10-24)
	-- roof pieces: cover tiles down each long slope (same idea as the wall
	-- giwa), rows of rafters under the eaves, white ridges, 잡상
	local TILE_C = Color3.fromRGB(70, 74, 80)
	-- the wall giwa, made bigger (user 2026-10-23): rows of cover tiles running
	-- straight from the ridge down to the eave (square to the 용마루), a joint
	-- ring at every tile, a 수막새 end cap at the eave and 암막새 drips
	-- between. The flat base goes first: a union takes the rotation of its
	-- first part, and a rotated first part turned the rows along the ridge.
	local tileT, tileOff = unionTemplate("RoofTiles", false, function(add)
		local L = 10
		add(Vector3.new(4, 0.06, L), CFrame.new(0, -0.03, 0), TILE_C) -- base, axis-aligned
		for i = 0, 3 do
			local x = -1.5 + i
			add(Vector3.new(L, 0.56, 0.56), CFrame.new(x, 0.2, 0) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
			for j = 1, 6 do
				add(Vector3.new(0.12, 0.64, 0.64), CFrame.new(x, 0.2, -L / 2 + j * L / 7) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
			end
			add(Vector3.new(0.1, 0.72, 0.72), CFrame.new(x, 0.2, L / 2 + 0.03) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
			add(Vector3.new(0.06, 0.38, 0.38), CFrame.new(x, 0.2, L / 2 + 0.1) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
			add(Vector3.new(0.8, 0.42, 0.08), CFrame.new(x + 0.5, -0.12, L / 2 + 0.02) * CFrame.Angles(math.rad(-25), 0, 0), TILE_C) -- 암막새
		end
	end)	local rafterT, rafterOff = unionTemplate("RoofRafters", true, function(add)
		add(Vector3.new(4, 0.42, 0.42), CFrame.new(0, -0.32, -0.2), GREEN)
		for i = 0, 4 do
			local x = -2 + 0.4 + i * 0.8
			add(Vector3.new(1.8, 0.3, 0.3), CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0), GREEN, Enum.PartType.Cylinder)
			add(Vector3.new(0.06, 0.32, 0.32), CFrame.new(x, 0, 0.92) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(240, 172, 60), Enum.PartType.Cylinder)
			add(Vector3.new(0.04, 0.14, 0.14), CFrame.new(x, 0, 0.96) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(40, 70, 150), Enum.PartType.Cylinder)
			add(Vector3.new(0.24, 0.24, 1.0), CFrame.new(x + 0.4, 0.3, 1.2), GREEN)
			add(Vector3.new(0.26, 0.26, 0.05), CFrame.new(x + 0.4, 0.3, 1.72), Color3.fromRGB(190, 50, 40))
		end
	end)
	-- one row of cover tiles (the wall giwa made bigger), 10 long along +Z,
	-- end cap and drip at +Z; cloned per row and stretched to the row length
	local rowT, rowOff = unionTemplate("RoofTileRow", false, function(add)
		local L = 10
		add(Vector3.new(1, 0.06, L), CFrame.new(0, -0.03, 0), TILE_C) -- axis-aligned base first
		add(Vector3.new(L, 0.56, 0.56), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
		for j = 1, 6 do
			add(Vector3.new(0.12, 0.64, 0.64), CFrame.new(0, 0.2, -L / 2 + j * L / 7) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
		end
		add(Vector3.new(0.1, 0.72, 0.72), CFrame.new(0, 0.2, L / 2 + 0.03) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
		add(Vector3.new(0.06, 0.38, 0.38), CFrame.new(0, 0.2, L / 2 + 0.1) * CFrame.Angles(0, math.rad(90), 0), TILE_C, Enum.PartType.Cylinder)
		add(Vector3.new(0.8, 0.42, 0.08), CFrame.new(0.5, -0.12, L / 2 + 0.02) * CFrame.Angles(math.rad(-25), 0, 0), TILE_C) -- 암막새
	end)
	-- 우진각 (hipped) roof like the real 광화문 (user side photos 2026-10-23):
	-- slopes on all four sides, a short 용마루, white hip ridges down to the
	-- corners with 잡상, eaves and rafters all round
	local function palaceRoof(y, x0, x1, z0, z1, rise)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local w, d = x1 - x0, z1 - z0
		local run = w / 2
		local Ls = math.sqrt(run * run + rise * rise)
		local WHITE_R = Color3.fromRGB(236, 234, 228)
		-- body: (gable along z) ∩ (gable along x with the same pitch) = hip roof
		do
			local was = G.Parent
			G.Parent = workspace -- CSG only works in the Workspace
			local a1 = part("RoofSlope", Vector3.new(d, rise, run), CFrame.new(cx - run / 2, y + rise / 2, cz) * CFrame.Angles(0, math.rad(90), 0), roofC, { parent = G, class = "WedgePart", material = Enum.Material.Slate })
			local a2 = part("RoofSlope", Vector3.new(d, rise, run), CFrame.new(cx + run / 2, y + rise / 2, cz) * CFrame.Angles(0, math.rad(-90), 0), roofC, { parent = G, class = "WedgePart", material = Enum.Material.Slate })
			local riseB = rise * (d / 2) / run
			local b1 = part("RoofHip", Vector3.new(w, riseB, d / 2), CFrame.new(cx, y + riseB / 2, cz - d / 4), roofC, { parent = G, class = "WedgePart" })
			local b2 = part("RoofHip", Vector3.new(w, riseB, d / 2), CFrame.new(cx, y + riseB / 2, cz + d / 4) * CFrame.Angles(0, math.rad(180), 0), roofC, { parent = G, class = "WedgePart" })
			local ok, res = pcall(function()
				local ua = a1:UnionAsync({ a2 })
				ua.Parent = G
				local ub = b1:UnionAsync({ b2 })
				ub.Parent = G
				local r = ua:IntersectAsync({ ub })
				ua:Destroy()
				ub:Destroy()
				return r
			end)
			if ok and res then
				res.Name = "RoofBody"
				res.UsePartColor = true
				res.Color = roofC
				res.Material = Enum.Material.Slate
				res.Anchored = true
				res.Parent = G
				a1:Destroy() a2:Destroy() b1:Destroy() b2:Destroy()
			else
				warn("hip roof CSG failed", res)
				b1:Destroy() b2:Destroy()
			end
			G.Parent = was
		end
		local eave = box("Eave", x0, y - 0.4, z0, x1, y, z1, GREEN, { parent = G })
		dancheongGui(eave, Enum.NormalId.Bottom)
		-- tile rows: long sides (square to the 용마루), then the hipped ends
		local function row(pos: Vector3, xAxis: Vector3, nrm: Vector3, rowRun: number)
			if rowRun < 0.4 then return end
			placeTemplate(rowT, rowOff, CFrame.fromMatrix(pos, xAxis, nrm), 1, rowRun * Ls / run / 10)
		end
		for _, s in ipairs({ -1, 1 }) do
			local nrm = Vector3.new(s * rise, run, 0).Unit
			for z = z0 + 0.5, z1 - 0.49, 1 do
				local rr = math.min(math.min(z - z0, z1 - z), run)
				local lat = run - rr / 2
				row(Vector3.new(cx + s * lat, y + rise * (rr / 2) / run, z), Vector3.new(0, 0, -s), nrm, rr)
			end
		end
		for _, e in ipairs({ -1, 1 }) do
			local nrm = Vector3.new(0, run, e * rise).Unit
			local endZ = if e < 0 then z0 else z1
			for u = -run + 0.5, run - 0.49, 1 do
				local rr = run - math.abs(u)
				row(Vector3.new(cx + u, y + rise * (rr / 2) / run, endZ - e * rr / 2), Vector3.new(e, 0, 0), nrm, rr)
			end
		end
		-- rafters under the eaves on all four sides
		local n = math.max(1, math.floor(d / 4 + 0.5))
		local seg = d / n
		for _, s in ipairs({ -1, 1 }) do
			local edge = if s < 0 then x0 else x1
			for k = 0, n - 1 do
				placeTemplate(rafterT, rafterOff, CFrame.fromMatrix(Vector3.new(edge - s * 1.72, y - 0.85, z0 + seg * (k + 0.5)), Vector3.new(0, 0, -s), Vector3.yAxis), seg / 4, 1)
			end
		end
		local n2 = math.max(1, math.floor(w / 4 + 0.5))
		local seg2 = w / n2
		for _, e in ipairs({ -1, 1 }) do
			local endZ = if e < 0 then z0 else z1
			for k = 0, n2 - 1 do
				placeTemplate(rafterT, rafterOff, CFrame.fromMatrix(Vector3.new(x0 + seg2 * (k + 0.5), y - 0.85, endZ - e * 1.72), Vector3.new(e, 0, 0), Vector3.yAxis), seg2 / 4, 1)
			end
		end
		-- 용마루: white sides, stacked dark ridge tiles, 취두 at both ends
		local r0, r1 = z0 + run, z1 - run
		box("RoofRidge", cx - 0.6, y + rise, r0, cx + 0.6, y + rise + 0.9, r1, WHITE_R, { parent = G })
		for i, wdt in ipairs({ 1.5, 1.2, 0.95, 0.7 }) do
			local yb = y + rise + 0.9 + (i - 1) * 0.3
			box("RidgeTiles", cx - wdt / 2, yb, r0, cx + wdt / 2, yb + 0.3, r1, Color3.fromRGB(62, 66, 72), { parent = G, material = Enum.Material.Slate })
		end
		for _, ze in ipairs({ r0, r1 }) do
			part("RidgeEnd", Vector3.new(1.3, 2.2, 1.1), CFrame.new(cx, y + rise + 1.6, ze), Color3.fromRGB(58, 60, 66), { parent = G, material = Enum.Material.Slate })
		end
		-- hip ridges (white) from the ridge ends down to the four corners, 잡상 on the lower half
		for _, e in ipairs({ -1, 1 }) do
			local rz = if e < 0 then r0 else r1
			local endZ = if e < 0 then z0 else z1
			for _, xe in ipairs({ x0, x1 }) do
				local top = Vector3.new(cx, y + rise + 0.45, rz)
				local bot = Vector3.new(xe, y + 0.35, endZ)
				local len = (bot - top).Magnitude
				part("HipRidge", Vector3.new(0.8, 0.6, len), CFrame.lookAt((top + bot) / 2, bot), WHITE_R, { parent = G })
				for j = 0, 4 do
					local p = top:Lerp(bot, 0.55 + j * 0.08) + Vector3.new(0, 0.6, 0)
					deco(part("Japsang", Vector3.new(0.34, 0.48, 0.34), CFrame.new(p), Color3.fromRGB(64, 66, 72), nopt))
					deco(part("JapsangHead", Vector3.new(0.3, 0.3, 0.3), CFrame.new(p + Vector3.new(0, 0.34, 0)), Color3.fromRGB(64, 66, 72), { parent = G, nocol = true, shape = Enum.PartType.Ball }))
				end
			end
		end
	end
	palaceRoof(H + 8 + LIFT, gx0 - 3, gx1 + 3, gz0 + 1, gz1 - 1, 4)
	-- upper storey: a green box with the pattern, the plaque on its face
	-- a plain green body under it reaches down into the lower roof, so nothing floats over the hip (user)
	box("UpperBody", gx0 + 2.05, H + 8 + LIFT, gz0 + 10.05, gx1 - 2.05, H + 12 + LIFT, gz1 - 10.05, GREEN, { parent = G })
	local box2 = box("UpperFloor", gx0 + 2, H + 12 + LIFT, gz0 + 10, gx1 - 2, H + 15 + LIFT, gz1 - 10, GREEN, { parent = G })
	patterned(box2, "rbxassetid://88257154059913", (box2.Size.Y) * 272 / 31)	palaceRoof(H + 15 + LIFT, gx0 - 1, gx1 + 1, gz0 + 6, gz1 - 6, 5)
	box("PlaqueFrame", gx0 + 1.55, H + 12.2 + LIFT, 163.6, gx0 + 1.75, H + 14.6 + LIFT, 172.4, Color3.fromRGB(188, 64, 52), { parent = G, nocol = true })
	local plaque = box("NamePlaque", gx0 + 1.4, H + 12.4 + LIFT, 164, gx0 + 1.6, H + 14.4 + LIFT, 172, Color3.fromRGB(28, 28, 32), { parent = G, nocol = true })
	do -- 門化光 (read right to left, like the real plaque), big gold letters
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Left
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.3
		g.Parent = plaque
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(0.86, 0.8)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Antique
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(232, 196, 110)
		l.Text = "門 化 光"
		l.Parent = g
	end
	label(plaque, "광화문 (한옥 마을 서쪽 입구)", Color3.fromRGB(150, 60, 40), 8, 0.9)
	do -- night: the stone base lit from the ground on the street side
		local p = Vector3.new(gx0 - 0.1, 0.312, (gz0 + gz1) / 2) -- right at the foot of the gate, flush with the yard (user)
		local glow = part("WallUplight", Vector3.new(gz1 - gz0, 0.02, 0.06), CFrame.fromMatrix(p, Vector3.new(0, 0, 1), Vector3.yAxis), Color3.fromRGB(255, 205, 150), { parent = G, nocol = true }) -- front faces +x, the gate
		glow.CastShadow = false
		glow:SetAttribute("NightRange", 16)
		glow:SetAttribute("NightBrightness", 3)
		glow:SetAttribute("NightAngle", 120)
		CS:AddTag(glow, "NightGlow")
		nightWash(CFrame.fromMatrix(Vector3.new(gx0 - 0.35, (TOP - 2.6) / 2, (gz0 + gz1) / 2), Vector3.new(0, 0, -1), Vector3.yAxis), gz1 - gz0, TOP - 2.6, G)
		-- and the pavilion (columns, brackets) lit from the top of the base
		local q = Vector3.new(gx0 + 2.2, TOP + 0.15, (gz0 + gz1) / 2)
		local top = part("WallUplight", Vector3.new(gz1 - gz0 - 10, 0.2, 0.25), CFrame.fromMatrix(q, Vector3.new(0, 0, 1), Vector3.yAxis) * CFrame.Angles(math.rad(40), 0, 0), Color3.fromRGB(255, 210, 160), { parent = G, nocol = true })
		top.CastShadow = false
		top:SetAttribute("NightRange", 12)
		top:SetAttribute("NightBrightness", 2.5)
		top:SetAttribute("NightAngle", 120)
		CS:AddTag(top, "NightGlow")
	end
	-- (layout v8, user 2026-10-27: "광화문 크기 3배로 키우기") the whole gate three
	-- times as big about the middle of its foot (still on the wall line x 97);
	-- the yard, lawns, balustrades and 해태 in front follow its new size below
	do
		local GS = 2 -- (3 → 2: two thirds of the 3× gate, user 2026-10-27)
		local S = Instance.new("Model")
		for _, c in ipairs(G:GetChildren()) do c.Parent = S end
		local cx, cz = (gx0 + gx1) / 2, (gz0 + gz1) / 2
		S.WorldPivot = CFrame.new(cx, 0, cz)
		S:ScaleTo(GS)
		-- turned to face the crossing at the village's north-west corner (GATE_*)
		S:PivotTo(CFrame.new(GATE_C) * CFrame.Angles(0, GATE_ROT, 0))
		for _, c in ipairs(S:GetChildren()) do c.Parent = G end
	end

	-- in front, from the sidewalks to the gate (layout v8, the gate turned):
	-- stone paving, a path as wide as the gate between two stone balustrades
	-- running out from its front corners along OUT to the sidewalk, a lawn
	-- outside each balustrade, the 해태 pair at the street end (build_haetae
	-- reads the GuardianSpot parts). The village inside the walls is empty for now
	local PAVE = Color3.fromRGB(226, 216, 190)
	-- paving everywhere from the sidewalks to x 240 / z 299, round the lawn beds
	do
		local X0, Z0, X1, Z1 = WIDE, WIDE, 277, 387 -- (out to the play area's edges, user map 2026-10-27)
		local xs = { X0, X1 }
		for _, l in ipairs(LAWN_TERRAIN) do table.insert(xs, l[1]) table.insert(xs, l[3]) end
		table.sort(xs)
		for i = 1, #xs - 1 do
			local xa, xb = xs[i], xs[i + 1]
			if xb - xa > 0.01 then
				local zs = { Z0, Z1 }
				local cut = {}
				for _, l in ipairs(LAWN_TERRAIN) do
					if l[1] < xb - 0.01 and l[3] > xa + 0.01 then table.insert(cut, l) table.insert(zs, l[2]) table.insert(zs, l[4]) end
				end
				table.sort(zs)
				for j = 1, #zs - 1 do
					local za, zb = zs[j], zs[j + 1]
					local inLawn = false
					for _, l in ipairs(cut) do if za >= l[2] - 0.01 and zb <= l[4] + 0.01 then inLawn = true end end
					if zb - za > 0.01 and not inLawn then box("PlazaStone", xa, 0, za, xb, 0.3, zb, PAVE, { parent = G, material = Enum.Material.Slate }) end
				end
			end
		end
	end
	-- stone kerb round each bed, reaching down to the grass so no hole shows
	for _, l in ipairs(LAWN_TERRAIN) do
		local K, KC = 0.6, Color3.fromRGB(200, 196, 186)
		local ko = { parent = G, material = Enum.Material.Granite }
		box("LawnKerb", l[1], -2.4, l[2], l[3], 0.4, l[2] + K, KC, ko)
		box("LawnKerb", l[1], -2.4, l[4] - K, l[3], 0.4, l[4], KC, ko)
		box("LawnKerb", l[1], -2.4, l[2] + K, l[1] + K, 0.4, l[4] - K, KC, ko)
		box("LawnKerb", l[3] - K, -2.4, l[2] + K, l[3], 0.4, l[4] - K, KC, ko)
	end
	-- real grass on the lawns: terrain grass (its blades wave), the lawn part stays under it
	for _, l in ipairs(LAWN_TERRAIN) do
		workspace.Terrain:FillBlock(CFrame.new((l[1] + l[3]) / 2, -2, (l[2] + l[4]) / 2), Vector3.new(l[3] - l[1], 4, l[4] - l[2]), Enum.Material.Grass) -- one voxel layer -4..0: grass surface about -1.6
	end
	pcall(function() workspace.Terrain.Decoration = true end)
	T:SetAttribute("LawnTerrain", true)
	-- 돌난간 (user photo): a low kerb, square posts with a stacked cap and a
	-- round knob, a thick round top rail held by two vase-shaped balusters
	-- per bay. One 5-stud bay is one merged part, cloned along the line (the
	-- lighter way: a toolbox asset would bring its own meshes and scripts).
	local RAIL = Color3.fromRGB(214, 206, 188)
	local BAY = 5
	local railT, railOff = unionTemplate("StoneRailBay", false, function(add)
		add(Vector3.new(BAY, 0.5, 1.1), CFrame.new(0, 0.25, 0), RAIL) -- kerb
		add(Vector3.new(0.8, 2.1, 0.8), CFrame.new(-BAY / 2 + 0.4, 1.55, 0), RAIL) -- post
		add(Vector3.new(1.0, 0.25, 1.0), CFrame.new(-BAY / 2 + 0.4, 2.7, 0), RAIL)
		add(Vector3.new(0.7, 0.35, 0.7), CFrame.new(-BAY / 2 + 0.4, 2.98, 0), RAIL)
		add(Vector3.new(0.75, 0.75, 0.75), CFrame.new(-BAY / 2 + 0.4, 3.45, 0), RAIL, Enum.PartType.Ball)
		add(Vector3.new(BAY - 0.8, 0.42, 0.42), CFrame.new(0.4, 1.95, 0), RAIL, Enum.PartType.Cylinder) -- top rail
		for _, bx in ipairs({ -0.55, 1.35 }) do
			add(Vector3.new(0.5, 0.55, 0.5), CFrame.new(bx, 1.45, 0), RAIL, Enum.PartType.Ball) -- vase body
			add(Vector3.new(0.3, 0.75, 0.3), CFrame.new(bx, 0.95, 0), RAIL) -- foot
			add(Vector3.new(0.42, 0.2, 0.42), CFrame.new(bx, 1.75, 0), RAIL) -- neck under the rail
		end
	end)
	-- (user 2026-10-27, marked on a screenshot) in front of the gate: a path
	-- as wide as the gate between two balustrades running from its front
	-- corners toward the streets (yellow lines), a lawn outside each
	-- balustrade up to the wall (red areas), the 해태 beside the street end
	-- of each balustrade (yellow box)
	do
		local LIME = Color3.fromRGB(150, 200, 92)
		local function streetEnd(p: Vector3): number
			local t = math.huge
			if GATE_OUT.X < 0 then t = math.min(t, (p.X - (WIDE + 1)) / -GATE_OUT.X) end
			if GATE_OUT.Z < 0 then t = math.min(t, (p.Z - (WIDE + 1)) / -GATE_OUT.Z) end
			return t
		end
		local RAIL_MAX = 60 -- the balustrades stop 60 out, or at the sidewalk
		for k, e in ipairs({ GATE_E1, GATE_E2 }) do
			local away = if k == 1 then GATE_ALONG else -GATE_ALONG
			local a = e + GATE_OUT * GATE_HD -- the gate's front corner
			local len = math.min(RAIL_MAX, streetEnd(a) - 1)
			local n = math.max(1, math.floor(len / BAY + 0.5))
			local seg = len / n
			for i = 0, n - 1 do
				local c = a + GATE_OUT * (seg * (i + 0.5))
				local bay = placeTemplate(railT, railOff, CFrame.fromMatrix(Vector3.new(c.X, 0.3, c.Z), -GATE_OUT, Vector3.yAxis), seg / BAY, 1)
				bay.CanCollide = true
				bay.Material = Enum.Material.Granite
			end
			for _, endP in ipairs({ a, a + GATE_OUT * len }) do
				part("RailPost", Vector3.new(0.8, 2.3, 0.8), CFrame.new(endP.X, 1.45, endP.Z) * CFrame.Angles(0, GATE_ROT, 0), RAIL, { parent = G, material = Enum.Material.Granite })
				part("RailPostCap", Vector3.new(0.75, 0.75, 0.75), CFrame.new(endP.X, 3.15, endP.Z), RAIL, { parent = G, shape = Enum.PartType.Ball })
			end
			-- the 해태 beside the balustrade's street end, outside it
			local s = a + GATE_OUT * (len - 4) + away * 5
			local spot = part("GuardianSpot", Vector3.new(1, 0.2, 1), CFrame.lookAt(Vector3.new(s.X, 0.45, s.Z), Vector3.new(s.X, 0.45, s.Z) - away), RAIL, { parent = G, nocol = true })
			spot.Transparency = 1
			spot.CanQuery = false
			spot:SetAttribute("Facing", GATE_OUT)
		end
	end
	-- (user 2026-10-27, green hatching) the whole yard on the street side of
	-- the wall is lawn, except the path in front of the gate, the sidewalks'
	-- edge and the 해태 pedestals: terrain grass (no parts, waving blades),
	-- a thin layer on the paving so it stands 0.7 proud like a lawn bed. The
	-- yard is the polygon sidewalk corner → along the east road → the north
	-- wall curve back to the gate → the south wall curve → along the south road
	do
		local poly = { Vector3.new(47, 0, 47), Vector3.new(320, 0, 47) }
		for i = 40, 0, -1 do table.insert(poly, bezier(WALL_N, i / 40)) end
		for i = 0, 40 do table.insert(poly, bezier(WALL_S, i / 40)) end
		table.insert(poly, Vector3.new(52, 0, 420)) table.insert(poly, Vector3.new(47, 0, 420))
		local function inside(x, z)
			local c = false
			local j = #poly
			for i = 1, #poly do
				local a, b = poly[i], poly[j]
				if (a.Z > z) ~= (b.Z > z) and x < (b.X - a.X) * (z - a.Z) / (b.Z - a.Z) + a.X then c = not c end
				j = i
			end
			return c
		end
		local spots = {}
		for _, s in ipairs(G:GetChildren()) do if s.Name == "GuardianSpot" then table.insert(spots, s.Position) end end
		local T2 = workspace.Terrain
		local CELL = 2
		for x = 48.5 + CELL / 2, 277 - CELL / 2, CELL do
			for z = 48.5 + CELL / 2, 387 - CELL / 2, CELL do
				if inside(x, z) then
					local rel = Vector3.new(x, 0, z) - GATE_C
					local al, ou = rel:Dot(GATE_ALONG), rel:Dot(GATE_OUT)
					local inPath = math.abs(al) < GATE_HL + 1.5 and ou > -GATE_HD - 1
					local nearSpot = false
					for _, sp in ipairs(spots) do if (Vector3.new(sp.X, 0, sp.Z) - Vector3.new(x, 0, z)).Magnitude < 7 then nearSpot = true end end
					if not inPath and not nearSpot then
						T2:FillBlock(CFrame.new(x, 0.5, z), Vector3.new(CELL, 1, CELL), Enum.Material.Grass)
					end
				end
			end
			if (x // CELL) % 20 == 0 then task.wait() end
		end
		pcall(function() T2.Decoration = true end)
		T:SetAttribute("YardLawn", true)
	end
	-- the village (graybox 07) is emptied for now (user 2026-10-27, after v8):
	-- every piece parked; its stone walls are drawn again along the user's red
	-- line in the boundary block below (curves from the gate's two ends)
	local zone = root:FindFirstChild("07_Hanok_Village")
	if zone then
		local undo = MOVES["07_Hanok_Village"]:Inverse()
		for _, c in ipairs(zone:GetChildren()) do
			if c:IsA("BasePart") or c:IsA("Model") then
				if c:IsA("Model") then c:PivotTo(undo * c:GetPivot()) else c.CFrame = undo * c.CFrame end
				c:SetAttribute("HomeZone", zone.Name)
				c.Parent = hidden
			end
		end
	end
	-- (user 2026-10-24, performance) the stone joint lines and the roof tile
	-- rows are merged into a few solids each (neighbours together, so far ones
	-- still drop out of view): 368 + 268 parts → about 15
	do
		local function mergeByName(model: Instance, name: string, chunk: number)
			local groups = {}
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == name then
					groups[d.Parent] = groups[d.Parent] or {}
					table.insert(groups[d.Parent], d)
				end
			end
			for par, list in pairs(groups) do
				table.sort(list, function(a, b)
					local pa, pb = a.Position, b.Position
					if math.abs(pa.X - pb.X) > 4 then return pa.X < pb.X end
					if math.abs(pa.Z - pb.Z) > 0.5 then return pa.Z < pb.Z end
					return pa.Y < pb.Y
				end)
				for i = 1, #list, chunk do
					local slice = {}
					for j = i, math.min(i + chunk - 1, #list) do table.insert(slice, list[j]) end
					if #slice > 1 then
						local first = table.remove(slice, 1)
						local ok, u = pcall(function() return first:UnionAsync(slice) end)
						if ok and u then
							u.Name = name
							u.UsePartColor = true
							u.Color = first.Color
							u.Material = first.Material
							u.Anchored = true
							u.CanCollide = first.CanCollide
							u.CanQuery = false
							u.CanTouch = false
							u.CastShadow = first.CastShadow
							-- (Automatic thins the merged lines out at a distance: they showed pale)
							pcall(function() u.RenderFidelity = Enum.RenderFidelity.Precise end)
							u.Parent = par
							first:Destroy()
							for _, p in ipairs(slice) do p:Destroy() end
						end
					end
				end
			end
		end
		local was = G.Parent
		G.Parent = workspace -- (CSG only works in the Workspace)
		mergeByName(G, "StoneJoint", 60)
		mergeByName(G, "RoofTileRow", 30)
		G.Parent = was
	end
	-- (no hills behind the village any more, user 2026-10-23; revert still clears old ones)
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
	-- (user 2026-10-24: the east wall stood on the sidewalk) the east wall's outer
	-- face is now x -51, the corner pillars inside the sidewalk line (-47): the gate and the info booth moved
	-- west by shortening the plain wall pieces either side of the gate
	local x0, x1, z0, z1 = -148, -51.3, -475, -229 -- (the corner pillar caps end at x -47.6)
	local gateX0, gateX1 = -127, -67
	box("ParkGround", x0 + 1, 0, z0 + 1, x1 - 1, 0.25, z1 - 1, Color3.fromRGB(110, 175, 95), { parent = E, material = Enum.Material.Grass })
	-- perimeter wall in the gate's style (user photo 2026-10-24: the gate
	-- tower up to its capital, no dome, no relief): a darker sandstone plinth,
	-- sandstone blocks (a joint texture, docs/04_ART/references/park_gate_tower_wall.jpg),
	-- a moulded cornice and a stepped cap; corner pillars the same, taller
	local STONE, CARVE = Color3.fromRGB(214, 194, 156), Color3.fromRGB(176, 152, 112)
	local BLOCKS = "rbxassetid://105570894168490"
	local sopt = { parent = E, material = Enum.Material.Sandstone }
	local function blocks(p: BasePart)
		for _, fce in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local tx = Instance.new("Texture")
			tx.Texture = BLOCKS
			tx.Face = fce
			tx.StudsPerTileU = 3.2
			tx.StudsPerTileV = 1.6
			tx.Parent = p
		end
	end
	local function course(name, ax, az, bx, bz, y0, y1, grow, color, tex)
		local p = box(name, ax - grow, y0, az - grow, bx + grow, y1, bz + grow, color, sopt)
		if tex then blocks(p) end
		return p
	end
	local function wallSeg(ax, az, bx, bz)
		course("ParkWallPlinth", ax, az, bx, bz, 0, 2.4, 0.25, CARVE)
		course("ParkWall", ax, az, bx, bz, 2.4, 11, 0, STONE, true)
		course("ParkWallCornice", ax, az, bx, bz, 11, 11.6, 0.35, CARVE)
		course("ParkWallTop", ax, az, bx, bz, 11.6, 12.4, 0.15, STONE)
		course("ParkWallCap", ax, az, bx, bz, 12.4, 12.8, 0.4, CARVE)
	end
	wallSeg(x0, z0, x0 + 1, z1) wallSeg(x1 - 1, z0, x1, z1) wallSeg(x0, z0, x1, z0 + 1)
	wallSeg(x0, z1 - 1, gateX0, z1) wallSeg(gateX1, z1 - 1, x1, z1)
	local function pillar(cx, cz, s, h)
		local a, b2 = s / 2, s / 2
		course("ParkPillarBase", cx - a, cz - a, cx + b2, cz + b2, 0, 3, 0.6, CARVE)
		course("ParkPillar", cx - a, cz - a, cx + b2, cz + b2, 3, h, 0, STONE, true)
		course("ParkPillarCornice", cx - a, cz - a, cx + b2, cz + b2, h, h + 0.8, 0.5, CARVE)
		course("ParkPillarCap", cx - a, cz - a, cx + b2, cz + b2, h + 0.8, h + 1.8, 0.2, STONE)
		course("ParkPillarCap", cx - a, cz - a, cx + b2, cz + b2, h + 1.8, h + 2.3, 0.7, CARVE)
		-- the gate towers' navy dome and gold spire on top (user 2026-10-24)
		local top = h + 2.3
		vcyl("ParkPillarDrum", Vector3.new(cx, top, cz), s * 0.8, 1.6, STONE, sopt)
		part("ParkPillarDome", Vector3.new(s * 0.85, s * 0.85, s * 0.85), CFrame.new(cx, top + 1.6, cz), Color3.fromRGB(120, 128, 140), { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Metal })
		vcyl("ParkPillarSpire", Vector3.new(cx, top + 1.6 + s * 0.4, cz), 0.4, 2.6, Color3.fromRGB(214, 172, 80), { parent = E, material = Enum.Material.Foil })
	end
	for _, c in ipairs({ { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } }) do pillar(c[1], c[2], 6, 15) end
	-- the wall goes on west across the closed north road to the beach, then
	-- north along the sand (user sketch 2026-10-24, white line): the road and
	-- promenade behind it become park land for later
	local BW, BZ_END = -207, -1400
	wallSeg(BW, z0, x0, z0 + 1)
	wallSeg(BW, BZ_END, BW + 1, z0 + 1)
	pillar(BW + 0.5, z0 + 0.5, 6, 15)
	for zz = z0 - 105, BZ_END + 50, -105 do pillar(BW + 0.5, zz, 6, 15) end
	box("ParkGround", BW + 1, -2.6, BZ_END, x0, 0.25, z0, Color3.fromRGB(110, 175, 95), { parent = E, material = Enum.Material.Grass })
	-- (layout v8, user map 2026-10-27: "북쪽 도로 따라서 놀이공원 담벼락 이어지게")
	-- the east wall runs on north along the north road's west sidewalk to the
	-- end of the map, where the shop buildings stood; park land behind it
	wallSeg(x1 - 1, BZ_END, x1, z0)
	for zz = z0 - 105, BZ_END + 50, -105 do pillar(x1 - 0.5, zz, 6, 15) end
	box("ParkGround", x0, 0, BZ_END, x1 - 1, 0.25, z0, Color3.fromRGB(110, 175, 95), { parent = E, material = Enum.Material.Grass })
	-- main gate (user photo 2026-10-23, an ADVENTURELAND-style arch): two tall
	-- sandstone towers with carved panels, domes and spires carry a big
	-- arched sign band "OHU LAND"; lower outer towers with half arches on
	-- each side, black iron fences between the gate and the park walls.
	local DOME, GOLD = Color3.fromRGB(120, 128, 140), Color3.fromRGB(214, 172, 80)
	local gz0, gz1 = z1 - 3, z1 + 5 -- gate depth (south face at gz1)
	local gzc = (gz0 + gz1) / 2
	local CX = (gateX0 + gateX1) / 2
	local function gtower(cx, s, h)
		box("GateTowerBase", cx - s / 2 - 0.6, 0, gzc - s / 2 - 0.6, cx + s / 2 + 0.6, 3, gzc + s / 2 + 0.6, CARVE, { parent = E, material = Enum.Material.Sandstone })
		blocks(box("GateTower", cx - s / 2, 3, gzc - s / 2, cx + s / 2, h, gzc + s / 2, STONE, { parent = E, material = Enum.Material.Sandstone }))
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
	local function archBand(xa, xb, y0, rise, thick, name, color, mat, depth)
		-- (user 2026-10-24: gaps showed where the band met the towers) the ends
		-- run 0.8 into the towers and the band is no deeper than the thinner tower
		xa, xb = xa - 0.8, xb + 0.8
		local N = 14
		local prev
		for k = 0, N do
			local tt = k / N
			local x = xa + (xb - xa) * tt
			local y = y0 + rise * math.sin(math.pi * tt)
			local pnt = Vector3.new(x, y, gzc)
			if prev then
				local d = pnt - prev
				part(name, Vector3.new(d.Magnitude + 0.3, thick, depth or (gz1 - gz0 - 1)), CFrame.fromMatrix((prev + pnt) / 2, d.Unit, Vector3.zAxis:Cross(d.Unit)), color, { parent = E, material = mat })
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
	archBand(ax0, ax1, 19, 5, 1.4, "GateArch", CARVE, Enum.Material.Sandstone, MAIN_S - 0.4)
	archBand(ax0, ax1, 23.2, 5, 1.2, "GateArchTop", STONE, Enum.Material.Sandstone, MAIN_S - 0.6)
	-- sign: dark band in the middle of the arch, gold letters
	-- the sign bends with the arch behind it (user 2026-10-24): its centre line
	-- runs 3.6 under the arch-top band's curve, in segments; each letter sits on
	-- its own small plate turned to the curve
	local sign
	do
		local xa, xb = ax0 - 0.8, ax1 + 0.8 -- the arch-top band's span (archBand adds 0.8)
		-- (a bigger one, tower to tower, was tried and taken back: user 2026-10-24)
		local function sy(x) return 23.2 + 5 * math.sin(math.pi * (x - xa) / (xb - xa)) - 3.6 end
		local half = (ax1 - ax0 - 2.6) / 2
		local K = 14
		for k = 0, K - 1 do
			local x0s, x1s = CX - half + 2 * half * k / K, CX - half + 2 * half * (k + 1) / K
			local pa, pb = Vector3.new(x0s, sy(x0s), 0), Vector3.new(x1s, sy(x1s), 0)
			local d = (pb - pa).Unit
			local up = Vector3.zAxis:Cross(d)
			local mid = (pa + pb) / 2
			local len = (pb - pa).Magnitude + 0.25
			part("GateSignFrame", Vector3.new(len, 4.6, 0.5), CFrame.fromMatrix(Vector3.new(mid.X, mid.Y, gz1 - 0.4), d, up), GOLD, { parent = E, material = Enum.Material.Foil })
			local seg = part("GateSign", Vector3.new(len, 3.8, 0.4), CFrame.fromMatrix(Vector3.new(mid.X, mid.Y, gz1 - 0.1), d, up), Color3.fromRGB(62, 54, 44), { parent = E })
			if k == K // 2 then sign = seg end
		end
		local text = { "O", "H", "U", "", "L", "A", "N", "D" }
		local step = 1.65
		for i, ch in ipairs(text) do
			if ch ~= "" then
				local x = CX + (i - (#text + 1) / 2) * step
				local p0, p1 = Vector3.new(x - 0.1, sy(x - 0.1), 0), Vector3.new(x + 0.1, sy(x + 0.1), 0)
				local d = (p1 - p0).Unit
				local plate = part("GateSignLetter", Vector3.new(2, 3.3, 0.05), CFrame.fromMatrix(Vector3.new(x, sy(x), gz1 + 0.13), d, Vector3.zAxis:Cross(d)), GOLD, { parent = E, transparency = 1, nocol = true })
				local g = Instance.new("SurfaceGui")
				g.Face = Enum.NormalId.Back -- the street side (+z)
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 50
				g.LightInfluence = 0.4
				g.Parent = plate
				local l = Instance.new("TextLabel")
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundTransparency = 1
				l.TextScaled = true
				l.Font = Enum.Font.Fondamento
				l.TextColor3 = GOLD
				l.TextStrokeColor3 = Color3.fromRGB(40, 30, 15)
				l.TextStrokeTransparency = 0.3
				l.Text = ch
				l.Parent = g
			end
		end
	end
	part("GateCrest", Vector3.new(6, 3, 0.6), CFrame.new(CX, 29.8, gzc), CARVE, { parent = E, material = Enum.Material.Sandstone })
	part("GateCrestBall", Vector3.new(1.4, 1.4, 1.4), CFrame.new(CX, 31.6, gzc), GOLD, { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Foil })
	-- side half arches from the outer towers to the main towers
	archBand(outL + OUT_S / 2, mainL - MAIN_S / 2, 13, 3, 1.4, "GateSideArch", CARVE, Enum.Material.Sandstone, OUT_S - 0.4)
	archBand(mainR + MAIN_S / 2, outR - OUT_S / 2, 13, 3, 1.4, "GateSideArch", CARVE, Enum.Material.Sandstone, OUT_S - 0.4)
	-- black iron fences + open iron gates under the side arches, fences out to the walls
	local IRON = Color3.fromRGB(28, 28, 32)
	local function fence(xa, xb, h)
		box("FenceRail", xa, h - 0.6, gzc - 0.15, xb, h - 0.3, gzc + 0.15, IRON, { parent = E })
		box("FenceRail", xa, 1, gzc - 0.15, xb, 1.3, gzc + 0.15, IRON, { parent = E })
		for x = xa, xb, 0.8 do box("FenceBar", x - 0.07, 0, gzc - 0.07, x + 0.07, h, gzc + 0.07, IRON, { parent = E, nocol = true }) end
	end
	fence(gateX0, outL - OUT_S / 2, 9) fence(outR + OUT_S / 2, gateX1, 9)
	-- the park is closed until its inside is built (user 2026-10-24): every
	-- passage has a closed pair of iron gates, chained and padlocked in the middle
	local function closedGates(xa, xb, h)
		local mid = (xa + xb) / 2
		for _, side in ipairs({ { xa, mid - 0.05 }, { mid + 0.05, xb } }) do
			local a, b2 = side[1], side[2]
			box("GateLeafFrame", a, 0.4, gzc - 0.12, b2, 0.8, gzc + 0.12, IRON, { parent = E })
			box("GateLeafFrame", a, h * 0.45, gzc - 0.12, b2, h * 0.45 + 0.35, gzc + 0.12, IRON, { parent = E })
			box("GateLeafFrame", a, h - 0.4, gzc - 0.12, b2, h, gzc + 0.12, IRON, { parent = E })
			box("GateLeafStile", a, 0.4, gzc - 0.14, a + 0.3, h, gzc + 0.14, IRON, { parent = E })
			box("GateLeafStile", b2 - 0.3, 0.4, gzc - 0.14, b2, h, gzc + 0.14, IRON, { parent = E })
			local n = math.max(2, math.floor((b2 - a) / 0.6))
			for k = 1, n - 1 do
				local x = a + (b2 - a) * k / n
				box("GateLeafBar", x - 0.06, 0.4, gzc - 0.06, x + 0.06, h + 0.6, gzc + 0.06, IRON, { parent = E, nocol = true })
				part("GateLeafSpear", Vector3.new(0.3, 0.3, 0.3), CFrame.new(x, h + 0.7, gzc), GOLD, { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Foil, nocol = true })
			end
		end
		-- chain wrapped round the two middle stiles + a padlock (street side)
		for k = 0, 3 do
			part("GateChain", Vector3.new(0.9, 0.12, 0.35), CFrame.new(mid, h * 0.45 - 0.6 - k * 0.22, gzc + 0.25) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 20 else -20)), Color3.fromRGB(150, 150, 155), { parent = E, material = Enum.Material.Metal, nocol = true })
		end
		box("GatePadlock", mid - 0.25, h * 0.45 - 1.9, gzc + 0.28, mid + 0.25, h * 0.45 - 1.3, gzc + 0.48, Color3.fromRGB(196, 160, 70), { parent = E, material = Enum.Material.Metal, nocol = true })
	end
	closedGates(ax0, ax1, 12)
	closedGates(outL + OUT_S / 2, mainL - MAIN_S / 2, 9)
	closedGates(mainR + MAIN_S / 2, outR - OUT_S / 2, 9)
	-- the bars let you see in but nobody walks through: one invisible wall over the whole gate
	box("ParkClosedBlocker", gateX0, 0, gzc - 0.5, gateX1, 32, gzc + 0.5, IRON, { parent = E, transparency = 1 })
	label(sign, "놀이공원 정문", Color3.fromRGB(60, 90, 140), 8, 0.9)
	-- ticket office / information in the gate's style (user 2026-10-24):
	-- sandstone plinth and block walls, arched windows in dark iron frames,
	-- a cornice and stepped cap, a dark sign band with gold letters, and a
	-- small grey dome with a gold spire like the gate towers
	-- a printed sign: rows of { text, colour, font, share of the height }, with
	-- an optional border line (closed-park signs, user 2026-10-24)
	local function notice(p: BasePart, face, rows, bg, border, ppsOverride)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = ppsOverride or 40
		g.LightInfluence = 0.6
		g.Parent = p
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = bg
		fr.BorderSizePixel = 0
		fr.Parent = g
		if border then
			local inner = Instance.new("Frame")
			inner.Size = UDim2.new(1, -16, 1, -16)
			inner.Position = UDim2.fromOffset(8, 8)
			inner.BackgroundTransparency = 1
			inner.Parent = fr
			local st = Instance.new("UIStroke")
			st.Color = border
			st.Thickness = 4
			st.Parent = inner
		end
		local y = 0.06
		local total = 0
		for _, r in ipairs(rows) do total += r[4] end
		local scale = 0.88 / total
		for _, r in ipairs(rows) do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(0.86, r[4] * scale)
			l.Position = UDim2.fromScale(0.07, y)
			l.TextScaled = true
			l.Text = r[1]
			l.TextColor3 = r[2]
			l.Font = r[3]
			l.Parent = fr
			y += r[4] * scale
		end
		return g
	end
	-- 3D channel letters (user photo 2026-10-24, docs/04_ART/references/ticket_booth_3d_sign.png):
	-- each stroke is a white-faced bar 0.7 deep with a soft pink neon halo behind it.
	-- Glyphs in a unit box (x right, y up): s = straight stroke, e = elliptical arc
	local function S(x0, y0, x1, y1) return { "s", x0, y0, x1, y1 } end
	local function Ell(cx, cy, rx, ry) return { "e", cx, cy, rx, ry } end
	local HANGUL = {
		["매"] = { S(0.04, 0.82, 0.5, 0.82), S(0.04, 0.18, 0.5, 0.18), S(0.04, 0.82, 0.04, 0.18), S(0.5, 0.82, 0.5, 0.18), S(0.68, 0.96, 0.68, 0.04), S(0.68, 0.52, 0.92, 0.52), S(0.92, 1, 0.92, 0) },
		["표"] = { S(0.12, 0.94, 0.88, 0.94), S(0.33, 0.94, 0.33, 0.6), S(0.67, 0.94, 0.67, 0.6), S(0.08, 0.6, 0.92, 0.6), S(0.35, 0.44, 0.35, 0.22), S(0.65, 0.44, 0.65, 0.22), S(0.02, 0.2, 0.98, 0.2) },
		["소"] = { S(0.5, 0.97, 0.14, 0.5), S(0.5, 0.82, 0.86, 0.5), S(0.5, 0.42, 0.5, 0.22), S(0.02, 0.2, 0.98, 0.2) },
		["안"] = { Ell(0.32, 0.73, 0.22, 0.2), S(0.76, 1, 0.76, 0.4), S(0.76, 0.72, 0.96, 0.72), S(0.16, 0.38, 0.16, 0.04), S(0.16, 0.04, 0.92, 0.04) },
		["내"] = { S(0.06, 0.86, 0.06, 0.16), S(0.06, 0.16, 0.5, 0.16), S(0.68, 0.96, 0.68, 0.04), S(0.68, 0.52, 0.92, 0.52), S(0.92, 1, 0.92, 0) },
	}
	local function letters3d(text: { string }, origin: Vector3, right: Vector3, out: Vector3, H: number)
		local SW, DEPTH, GAP = 0.16 * H, 0.47, 0.22 -- 2/3 of the first depth (user 2026-10-24)
		local m = Instance.new("Model")
		m.Name = "BoothLetters"
		m.Parent = E
		local function stroke(a: Vector3, b: Vector3)
			local len = (b - a).Magnitude
			if len < 0.01 then return end
			local cf = CFrame.fromMatrix((a + b) / 2, (b - a).Unit, out)
			part("Letter", Vector3.new(len + SW * 0.9, DEPTH - 0.06, SW), cf * CFrame.new(0, -0.03, 0), Color3.fromRGB(235, 225, 230), { parent = m, nocol = true })
			-- plain white by day; NightGlowController lights the faces after dark
			local face = part("LetterFace", Vector3.new(len + SW * 0.9, 0.06, SW), cf * CFrame.new(0, DEPTH / 2 - 0.03, 0), Color3.fromRGB(255, 252, 250), { parent = m, nocol = true })
			face:SetAttribute("NightRange", 4)
			face:SetAttribute("NightBrightness", 0.6)
			CS:AddTag(face, "NightGlow")
			-- (no pink halo behind the letters: user 2026-10-24)
		end
		local total = #text + (#text - 1) * GAP
		local x = -total / 2
		for _, ch in ipairs(text) do
			local function at(px, py) return origin + out * (DEPTH / 2) + right * ((x + px) * H) + Vector3.yAxis * ((py - 0.5) * H) end
			for _, s in ipairs(HANGUL[ch]) do
				if s[1] == "s" then
					stroke(at(s[2], s[3]), at(s[4], s[5]))
				else
					local n = 18
					local prev = at(s[2] + s[4], s[3])
					for k = 1, n do
						local a = k / n * 2 * math.pi
						local p = at(s[2] + s[4] * math.cos(a), s[3] + s[5] * math.sin(a))
						stroke(prev, p)
						prev = p
					end
				end
			end
			x += 1 + GAP
		end
	end
	local function booth(center: Vector3, facing: Vector3, W: number, D: number, title: string, sign3d: { string })
		-- local frame: X across the front, Y up, Z out of the front (facing)
		local fr = CFrame.fromMatrix(Vector3.new(center.X, 0, center.Z), Vector3.yAxis:Cross(facing), Vector3.yAxis, facing)
		local function lb(name, x0, y0, z0, x1, y1, z1, color, opt, tex)
			local p = part(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), fr * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, opt)
			if tex then blocks(p) end
			return p
		end
		local hw, hd = W / 2, D / 2
		local function course2(name, y0, y1, grow, color, tex)
			return lb(name, -hw - grow, y0, -hd - grow, hw + grow, y1, hd + grow, color, sopt, tex)
		end
		local H2 = 11.5 -- room for the arched window under the sign
		course2("BoothBase", 0, 1.5, 0.3, CARVE)
		course2("BoothBody", 1.5, H2, 0, STONE, true)
		course2("BoothCornice", H2, H2 + 0.6, 0.4, CARVE)
		course2("BoothCap", H2 + 0.6, H2 + 1.3, 0.15, STONE)
		course2("BoothCap", H2 + 1.3, H2 + 1.7, 0.5, CARVE)
		-- drum and dome fill the roof like the corner pillars' (user 2026-10-24)
		local s = math.min(W, D)
		local c = Vector3.new(center.X, 0, center.Z)
		vcyl("BoothDrum", c + Vector3.new(0, H2 + 1.7, 0), s * 0.8, 1.6, STONE, sopt)
		part("BoothDome", Vector3.new(s * 0.85, s * 0.85, s * 0.85), CFrame.new(c + Vector3.new(0, H2 + 3.3, 0)), DOME, { parent = E, shape = Enum.PartType.Ball, material = Enum.Material.Metal })
		vcyl("BoothSpire", c + Vector3.new(0, H2 + 3.3 + s * 0.4, 0), 0.4, 2.6, GOLD, { parent = E, material = Enum.Material.Foil })
		-- one arched window in the middle of the front, at most 6 wide so the
		-- round top's circle never shows below the sill (user 2026-10-24)
		local w = math.min(6, W - 1.8)
		local spring = H2 - 1.9 - w / 2 - 0.3 -- the arch top stays under the sign band
		local GL = Color3.fromRGB(110, 140, 165)
		-- the window is set into the wall (user 2026-10-24): the opening is cut
		-- 0.6 deep, the glass sits at its back; only the iron frame stands out
		local REC, SILL_Y = 0.6, 2.9
		local function opening(name, grow, z0w, z1w, color)
			local pieces = {
				lb(name, -w / 2 - grow, SILL_Y - (if grow > 0 then 0.1 else 0), z0w, w / 2 + grow, spring, z1w, color, { parent = workspace }),
				part(name, Vector3.new(z1w - z0w, w + grow * 2, w + grow * 2), fr * CFrame.new(0, spring, (z0w + z1w) / 2) * CFrame.Angles(0, math.rad(90), 0), color, { parent = workspace, shape = Enum.PartType.Cylinder }),
			}
			return pieces
		end
		do
			local body = nil
			for _, p in ipairs(E:GetChildren()) do
				if p.Name == "BoothBody" and (p.Position - Vector3.new(center.X, p.Position.Y, center.Z)).Magnitude < 0.1 then body = p end
			end
			if body then
				local hole = opening("BoothCut", 0, hd - REC - 0.2, hd + 0.5, STONE) -- 0.2 deeper than the glass: room for its round top
				body.Parent = workspace
				local ok, cut = pcall(function() return body:SubtractAsync(hole) end)
				for _, h in ipairs(hole) do h:Destroy() end
				if ok and cut then
					cut.Name = "BoothBody"
					cut.UsePartColor = true
					cut.Anchored = true
					cut.Parent = E
					blocks(cut)
					body:Destroy()
				else
					body.Parent = E
				end
			end
			-- iron frame: a ring round the opening, lining it and standing 0.25 proud
			local outer = opening("BoothFrameO", 0.25, hd - REC - 0.2, hd + 0.25, IRON) -- lines the whole cut, to the back
			local inner = opening("BoothFrameI", -0.1, hd - REC - 0.3, hd + 0.35, IRON) -- 0.1 inside the cut, so the lining hides the cut stone
			local ok1, ou = pcall(function() return outer[1]:UnionAsync({ outer[2] }) end)
			if ok1 and ou then
				ou.Parent = workspace
				local ok2, ring = pcall(function() return ou:SubtractAsync(inner) end)
				if ok2 and ring then
					ring.Name = "BoothWindowFrame"
					ring.UsePartColor = true
					ring.Anchored = true
					ring.Parent = E
				end
				ou:Destroy()
			end
			for _, p in ipairs(outer) do p:Destroy() end
			for _, p in ipairs(inner) do p:Destroy() end
		end
		-- glass at the back of the opening (one opaque pane + its round top a hair behind)
		lb("BoothWindow", -w / 2, SILL_Y, hd - REC, w / 2, spring, hd - REC + 0.08, GL, { parent = E })
		part("BoothWindowTop", Vector3.new(0.08, w, w), fr * CFrame.new(0, spring, hd - REC - 0.06) * CFrame.Angles(0, math.rad(90), 0), GL, { parent = E, shape = Enum.PartType.Cylinder }) -- plain: Glass on the round top drew a reflection patch
		-- the counter under the window: a thin stone plate that sticks out a little more (user 2026-10-24)
		lb("BoothSill", -w / 2 - 0.5, 2.72, hd - REC, w / 2 + 0.5, 2.96, hd + 1.3, CARVE, sopt) -- top 0.06 over the cut floor and the frame (they flickered, user 2026-10-24)
		-- closed for now (user 2026-10-24): a printed card taped inside the glass
		local card = lb("BoothClosedCard", -w / 2 + 0.6, 3.5, hd - REC + 0.09, w / 2 - 0.6, 5.7, hd - REC + 0.12, Color3.fromRGB(250, 248, 240), { parent = E, nocol = true })
		notice(card, Enum.NormalId.Back, {
			{ "CLOSED", Color3.fromRGB(200, 30, 40), Enum.Font.GothamBlack, 0.5 },
			{ "운영 준비 중", Color3.fromRGB(40, 40, 45), Enum.Font.GothamBold, 0.27 },
			{ "OPENING SOON", Color3.fromRGB(110, 110, 115), Enum.Font.Gotham, 0.18 },
		}, Color3.fromRGB(250, 248, 240), Color3.fromRGB(200, 30, 40))
		-- 3D letters across the cornice and cap (user sketch 2026-10-24); the old
		-- flat sign band is gone (its small text broke up at a distance)
		-- small enough to stay inside the booth's outline (top H2 + 1.7, sides)
		local LH = math.min(1.8, (W - 2.4) / (#sign3d + (#sign3d - 1) * 0.22))
		letters3d(sign3d, (fr * CFrame.new(0, H2 + 0.5, hd + 0.5)).Position, fr.RightVector, fr.LookVector * -1, LH)
		local anchor = lb("BoothLabelAnchor", -0.5, H2 + 2, -0.5, 0.5, H2 + 2.2, 0.5, IRON, { parent = E, transparency = 1, nocol = true })
		label(anchor, title, Color3.fromRGB(150, 110, 50), 6, 0.6)
	end
	-- against the park wall either side of the gate, windows facing south
	-- (user 2026-10-24, white boxes on the screenshot)
	booth(Vector3.new(-136, 0, -223.4), Vector3.new(0, 0, 1), 14, 10, "매표소 TICKETS", { "매", "표", "소" })
	booth(Vector3.new(-61, 0, -223.4), Vector3.new(0, 0, 1), 12, 10, "i 안내", { "안", "내", "소" })
	-- closed while the inside is being built (user 2026-10-24, photos
	-- docs/04_ART/references/park_closed_*.webp): printed hoarding just inside the
	-- gate, seen through the closed bars
	do
		local NAVY, NAVY2 = Color3.fromRGB(28, 42, 78), Color3.fromRGB(36, 54, 98)
		local hz = gz0 - 2.5 -- hoarding face (street side), inside the park
		local HH = 17 -- above the site fence and the side gates, under the main arch
		-- panel joints: one wide printed panel right behind the main arch, the
		-- rest in 10-stud panels out to the side towers
		local cuts = { gateX0 }
		local cL, cR = ax0 - 1, ax1 + 1
		local x = gateX0
		while x + 10 < cL - 0.1 do x += 10 table.insert(cuts, x) end
		table.insert(cuts, cL) table.insert(cuts, cR)
		x = cR
		while x + 10 < gateX1 - 0.1 do x += 10 table.insert(cuts, x) end
		table.insert(cuts, gateX1)
		for k = 1, #cuts - 1 do
			local px, pw = cuts[k], cuts[k + 1] - cuts[k]
			local col = if k % 2 == 0 then NAVY2 else NAVY
			local panel = box("HoardingPanel", px, 0, hz - 0.3, px + pw, if px == cL then 21 else HH, hz, col, { parent = E }) -- the centre one fills the arch above the closed gates
			if px == cL then
				-- the big "coming soon" print; its lower third stays plain (the site fence covers it)
				notice(panel, Enum.NormalId.Back, {
					{ "OHU LAND", GOLD, Enum.Font.Fondamento, 0.1 },
					{ "COMING SOON", Color3.new(1, 1, 1), Enum.Font.GothamBlack, 0.13 },
					{ "더 신나는 놀이공원으로 곧 찾아올게요!", Color3.fromRGB(235, 220, 180), Enum.Font.GothamBold, 0.055 },
					{ "Something new is coming", Color3.fromRGB(200, 190, 160), Enum.Font.Gotham, 0.04 },
					{ "", col, Enum.Font.Gotham, 0.675 }, -- text stays above the gate's top rail
				}, col, GOLD, 20)
			else
				notice(panel, Enum.NormalId.Back, {
					{ "★", GOLD, Enum.Font.GothamBlack, 0.25 },
					{ "OHU LAND", GOLD, Enum.Font.Fondamento, 0.15 },
					{ "공사 중 · UNDER CONSTRUCTION", Color3.fromRGB(220, 210, 185), Enum.Font.GothamBold, 0.08 },
					{ "", col, Enum.Font.Gotham, 0.3 },
				}, col, GOLD, 20)
			end
			-- steel posts and a back brace behind every panel joint
			box("HoardingPost", px - 0.15, 0, hz - 0.6, px + 0.15, HH, hz - 0.3, Color3.fromRGB(90, 90, 95), { parent = E, material = Enum.Material.DiamondPlate })
			part("HoardingBrace", Vector3.new(0.2, 9, 0.2), CFrame.new(px, 4, hz - 3) * CFrame.Angles(math.rad(-36), 0, 0), Color3.fromRGB(90, 90, 95), { parent = E, material = Enum.Material.DiamondPlate })
		end
		-- (the black mesh site fence and its signs in front of the arch: removed, user 2026-10-24)
		-- the ride name signs inside would float over the hoarding: off while closed
		local pz = root:FindFirstChild("06_Park_Playground")
		if pz then
			for _, g in ipairs(pz:GetDescendants()) do
				if g:IsA("BillboardGui") and g.Enabled then
					g.Enabled = false
					g:SetAttribute("ParkClosedHidden", true)
				end
			end
		end
	end
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
	local _ = ped -- (its "상징물 자리" label is off while the park is closed)
	-- (no gate plaza: the pocket park's paving runs up to the wall at sidewalk height, user 2026-10-24)
end
------------------------------------------------------- pocket park in front of the park gate (user 2026-10-24, v2)
-- From the user's landscape sketch (docs/04_ART/references/pocket_park_sketch.webp):
-- one paved plaza with a round stepped seating mound and a sculpture in the
-- middle, curved wooden decks wrapped round it (a long sofa deck on the north
-- west, tiered wooden seats on the east, an S-shaped deck walk to the south
-- east corner), wicker chairs, white parasols with tables, wide steps, and
-- planting beds of round shrubs and trees along the edges. The corner by
-- subway exit 3 (x > -64, z > -64) stays open paving.
do
	local P = Instance.new("Model")
	P.Name = "PocketPark"
	P.Parent = T
	local X0, X1, Z0, Z1 = -150, -47, -210, -47
	local C = Vector3.new(-96, 0, -128) -- centre of the round mound
	local PAVE, PAVE2 = Color3.fromRGB(222, 216, 204), Color3.fromRGB(206, 200, 188)
	local STONE = Color3.fromRGB(232, 228, 220)
	local WOOD = Color3.fromRGB(120, 88, 62) -- (one deck wood for the whole map, user 2026-10-27: was 150, 98, 60)
	local CUSH = Color3.fromRGB(240, 236, 226)
	local function o(mat, extra)
		local r = { parent = P, material = mat }
		for k, v in pairs(extra or {}) do r[k] = v end
		return r
	end
	-- SOUTH WALK + STAIRS (user sketch 2026-10-24): the upper level (-2.5) runs
	-- on south from the circle as a walk (x -102..-75) with rounded corners
	-- (fillet r 6) where it leaves the circle, and ends in a stair up to the
	-- paving at z -54; a second stair comes down from the east at the circle's
	-- edge (z -122.4..-114) just past the east tiers
	local WALK_X0, WALK_X1, FIL = -102, -75, 6
	local corridorPoly: { Vector2 } = {}
	local Fl, Fr
	do
		local Rr = 44 + FIL
		local dzl = math.sqrt(Rr ^ 2 - (WALK_X0 - FIL - C.X) ^ 2)
		Fl = Vector2.new(WALK_X0 - FIL, C.Z + dzl)
		local dzr = math.sqrt(Rr ^ 2 - (WALK_X1 + FIL - C.X) ^ 2)
		Fr = Vector2.new(WALK_X1 + FIL, C.Z + dzr)
		local c2 = Vector2.new(C.X, C.Z)
		local function circlePt(fc) return c2 + (fc - c2).Unit * 44 end
		local Lc, Rc = circlePt(Fl), circlePt(Fr)
		local function angOf(p, c) return math.atan2(p.Y - c.Y, p.X - c.X) end
		local function add(p) table.insert(corridorPoly, p) end
		-- (no west fillet: the raised ground beside the west tiers meets the walk there)
		add(Vector2.new(WALK_X0, C.Z + math.sqrt(44 * 44 - (WALK_X0 - C.X) ^ 2)))
		add(Vector2.new(WALK_X0, -63)) add(Vector2.new(WALK_X1, -63))
		-- (no east fillet either)
		add(Vector2.new(WALK_X1, C.Z + math.sqrt(44 * 44 - (WALK_X1 - C.X) ^ 2)))
		-- the circle back from the right point to the left one (through its south)
		local c0, c1 = angOf(Rc, c2), angOf(Lc, c2)
		for i = 1, 11 do local a = c0 + (c1 - c0) * i / 12 add(c2 + Vector2.new(math.cos(a), math.sin(a)) * 44) end
	end
	local function inCorridor(x, z)
		local inside = false
		local n = #corridorPoly
		for i = 1, n do
			local a, b = corridorPoly[i], corridorPoly[i % n + 1]
			if (a.Y > z) ~= (b.Y > z) and x < a.X + (z - a.Y) / (b.Y - a.Y) * (b.X - a.X) then inside = not inside end
		end
		return inside
	end
	local EAST_Z0, EAST_Z1, EAST_X0, EAST_X1 = -122.4, -114, -55, -44
	-- the walk's rounded corners as solid pieces (boxes and cylinders, no thin
	-- triangles: CSG left slivers of those standing in the walk)
	local function fillPiece(fc: Vector2, xa, xb)
		-- the corner between the walk's edge and its fillet circle
		local b = box("Cut", xa, -9, fc.Y - FIL, xb, 2, fc.Y, PAVE, { parent = workspace })
		local cyl = part("Cut", Vector3.new(30, FIL * 2, FIL * 2), CFrame.new(fc.X, 0, fc.Y) * CFrame.Angles(0, 0, math.rad(90)), PAVE, { parent = workspace, shape = Enum.PartType.Cylinder })
		local ok, r = pcall(function() return b:SubtractAsync({ cyl }) end)
		cyl:Destroy()
		if ok and r then r.Name = "Cut" r.Parent = workspace b:Destroy() return r end
		return b
	end	-- paving over the whole lot
	-- the lot's paving, with the sunken plaza and the entrance stair cut out
	-- (the ground has a hole under it, HOLES)
	-- (user 2026-10-24) the paving runs north up to the amusement park wall's
	-- plinth (the gate plaza is gone), and exit 3's pit is cut out of it (the
	-- paving covered the stair's top steps)
	local PZ0 = -228.75
	local PIT = { -53, -54.2, -47, -48.2 } -- exit 3's opening on the park side (x0, z0, x1, z1)
	local paving = box("ParkPaving", X0, -8, PZ0, X1, 0.08, Z1, PAVE, { parent = workspace, material = Enum.Material.Slate })
	local cuts = {
		part("Cut", Vector3.new(30, 88.2, 88.2), CFrame.new(-96, 0, -128) * CFrame.Angles(0, 0, math.rad(90)), PAVE, { parent = workspace, shape = Enum.PartType.Cylinder }),
		box("Cut", -114.5, -9, -196, -79.5, 2, -165, PAVE, { parent = workspace }), -- into the ring, so no paving is left between the walk and the circle
		box("Cut", WALK_X0, -9, -63.2, WALK_X1, 2, -54, PAVE, { parent = workspace }), -- the south stair
		box("Cut", PIT[1], -9, PIT[2], PIT[3] + 1, 2, PIT[4], PAVE, { parent = workspace }), -- subway exit 3
	}
	table.insert(cuts, box("Cut", WALK_X0, -9, C.Z, WALK_X1, 2, -63, PAVE, { parent = workspace })) -- the walk (its north end is inside the circle)
	local okP, cutP = pcall(function() return paving:SubtractAsync(cuts) end)
	for _, c in ipairs(cuts) do c:Destroy() end
	if okP and cutP then
		cutP.Name = "ParkPaving"
		cutP.CanCollide = false -- (its hull filled the cut-outs with an invisible floor; collision below)
		cutP.CanQuery = false -- (raycasts would hit the same hull)
		cutP.UsePartColor = true
		cutP.Anchored = true
		cutP.Parent = P
		paving:Destroy()
	else
		paving.Parent = P
	end
	-- a ring of darker pavers round the mound
	-- the round plaza is sunk in three levels (user 2026-10-24): one step down at
	-- each ring (r 44, 34, 20), 0.8 each, reached by a straight stair coming down
	-- from the park gate on the axis
	-- (user 2026-10-24) two levels: the upper ring now reaches in to r 20 (the
	-- middle level is gone), the inner circle one 0.8 step below it
	-- (user 2026-10-24) no step ring: the inner circle round the mound drops
	-- deep (a pit for a fountain, water to fall into it later); the mound stays
	-- at its height (MOUND_H) on a stone plinth rising from the pit floor
	local LEVELS = { { 44, -2.5 }, { 20, -7 } }
	local MOUND_H = -3.8
	local function domeH(x, z) -- (the name stays: everything below sits at the level under it)
		local d = math.sqrt((x - C.X) ^ 2 + (z - C.Z) ^ 2)
		local h = 0
		for _, l in ipairs(LEVELS) do if d < l[1] then h = l[2] end end
		if h == 0 and inCorridor(x, z) then h = LEVELS[1][2] end
		return h
	end
	for i, l in ipairs(LEVELS) do
		local outer = part("ParkLevel", Vector3.new(l[2] + 8, l[1] * 2, l[1] * 2), CFrame.new(C.X, (l[2] - 8) / 2, C.Z) * CFrame.Angles(0, 0, math.rad(90)), if i % 2 == 0 then PAVE2 else PAVE, { parent = workspace, shape = Enum.PartType.Cylinder, material = Enum.Material.Slate })
		local nxt = LEVELS[i + 1]
		if nxt then
			local hole = part("Cut", Vector3.new(30, nxt[1] * 2, nxt[1] * 2), CFrame.new(C.X, 0, C.Z) * CFrame.Angles(0, 0, math.rad(90)), PAVE, { parent = workspace, shape = Enum.PartType.Cylinder })
			local okR, ring = pcall(function() return outer:SubtractAsync({ hole }) end)
			hole:Destroy()
			if okR and ring then
				ring.Name = "ParkLevel"
				ring.CanCollide = false -- (collision below)
				ring.CanQuery = false
				ring.UsePartColor = true
				ring.Anchored = true
				ring.Parent = P
				outer:Destroy()
			else
				outer.Parent = P
			end
		else
			outer.Parent = P
		end
	end
	-- the south walk's floor: the outline's triangles at the upper level (top
	-- -2.5, 6 thick), meeting the ring along the circle without overlapping it
	do -- the walk's floor at the upper level: one box less the circle (the ring
		-- is there) and less the paving on either side outside the rounded corners
		local floor = box("ParkLevel", Fl.X, LEVELS[1][2] - 6, C.Z, Fr.X, LEVELS[1][2], -63, PAVE, { parent = workspace, material = Enum.Material.Slate })
		local neg = { part("Cut", Vector3.new(30, 88, 88), CFrame.new(C.X, 0, C.Z) * CFrame.Angles(0, 0, math.rad(90)), PAVE, { parent = workspace, shape = Enum.PartType.Cylinder }) }
		table.insert(neg, box("Cut", Fl.X - 1, -20, C.Z - 1, WALK_X0, 5, -62, PAVE, { parent = workspace })) -- west of the walk (no fillet there)
		table.insert(neg, box("Cut", WALK_X1, -20, C.Z - 1, Fr.X + 1, 5, -62, PAVE, { parent = workspace })) -- east of the walk (no fillet there either)
		for _, side in ipairs({}) do
			local keep = box("Cut", side[2], -20, C.Z - 1, side[3], 5, -62, PAVE, { parent = workspace })
			local corner = fillPiece(side[1], math.max(side[2], Fl.X), math.min(side[3], Fr.X))
			local ok, k = pcall(function() return keep:SubtractAsync({ corner }) end)
			corner:Destroy()
			if ok and k then k.Parent = workspace keep:Destroy() table.insert(neg, k) else table.insert(neg, keep) end
		end
		local ok, fl = pcall(function() return floor:SubtractAsync(neg) end)
		for _, n in ipairs(neg) do n:Destroy() end
		if ok and fl then
			fl.Name = "ParkLevel"
			fl.UsePartColor = true
			fl.Anchored = true
			fl.Parent = P
			floor:Destroy()
		else
			floor.Parent = P
		end
	end
	-- COLLISION for the cut shapes (user 2026-10-24: players floated on an
	-- invisible floor). A CSG part collides as a hull that fills its holes and a
	-- script cannot change that, so the paving and the rings collide through
	-- invisible boxes in 1.5-wide rows that leave out the circle, the rings'
	-- inner circles and the entrance stair / walk
	do
		local function collideRows(name, za, zb, top, keepOut)
			for z = za, zb - 0.01, 1.5 do
				local z1 = math.min(z + 1.5, zb)
				local zm = (z + z1) / 2
				local spans = { { X0, X1 } }
				for _, f in ipairs(keepOut) do
					local a, b = f(zm)
					if a then
						local nxt = {}
						for _, s in ipairs(spans) do
							if b <= s[1] or a >= s[2] then table.insert(nxt, s)
							else
								if a > s[1] then table.insert(nxt, { s[1], a }) end
								if b < s[2] then table.insert(nxt, { b, s[2] }) end
							end
						end
						spans = nxt
					end
				end
				for _, s in ipairs(spans) do
					if s[2] - s[1] > 0.05 then
						local p = box(name, s[1], top - 1, z, s[2], top, z1, PAVE, { parent = P, transparency = 1 })
						p.CastShadow = false
					end
				end
			end
		end
		local function circleOut(r) -- the x span a circle of radius r covers at z (nil outside it)
			return function(z)
				local dz = z - C.Z
				if math.abs(dz) >= r then return nil end
				local w = math.sqrt(r * r - dz * dz)
				return C.X - w, C.X + w
			end
		end
		local function corridor(z) if z > -196 and z < -165 then return -114.5, -79.5 end return nil end
		local function pit(z) if z > PIT[2] and z < PIT[4] then return PIT[1], PIT[3] + 1 end return nil end
		local function southWalk(z) -- the walk between its fillets and the south stair
			if z > -54 then return nil end
			local dz = z - C.Z
			local cw = math.sqrt(math.max(0, 44 * 44 - dz * dz)) -- the circle's half width here
			local a, b = WALK_X0, WALK_X1
			if z < Fr.Y - FIL and z < Fl.Y - FIL then return nil end -- (above both fillets: the circle covers it)
			return a, b
		end
		-- the paving (top 0.08)
		collideRows("ParkCollide", PZ0, Z1, 0.08, { circleOut(44), corridor, southWalk, pit })
		-- ring 1 (r 34..44) and ring 2 (r 20..34)
		for i = 1, #LEVELS - 1 do
			local ro, ri, top = LEVELS[i][1], LEVELS[i + 1][1], LEVELS[i][2]
			for z = C.Z - ro, C.Z + ro - 0.01, 1.5 do
				local z1 = math.min(z + 1.5, C.Z + ro)
				local zm = (z + z1) / 2
				local dz = zm - C.Z
				local wo = math.sqrt(math.max(0, ro * ro - dz * dz))
				local spans
				-- the inner edge from the row's outer side (not its middle): the
				-- inner ring's own rows sit on another grid, and a middle-based
				-- edge left slivers open where they did not meet (a 6 × 1.5 hole
				-- at the south rim, mobile 2P test 2026-10-27)
				local dzFar = math.max(math.abs(z - C.Z), math.abs(z1 - C.Z))
				if dzFar < ri then
					local wi = math.sqrt(ri * ri - dzFar * dzFar)
					spans = { { C.X - wo, C.X - wi }, { C.X + wi, C.X + wo } }
				else
					spans = { { C.X - wo, C.X + wo } }
				end
				for _, s in ipairs(spans) do
					if s[2] - s[1] > 0.05 then
						local p = box("ParkCollide", s[1], top - 1, z, s[2], top, z1, PAVE, { parent = P, transparency = 1 })
						p.CastShadow = false
					end
				end
			end
		end
	end
	-- the stair from the gate side down to the first level: real steps (user
	-- 2026-10-24: half the tread, higher risers), 5 steps of 0.5 on 2.25 treads
	-- between the outer faces of the gate's two main towers (x -114.5..-79.5,
	-- the user's orange lines 2026-10-24):
	-- the stair right after the gate, then a level walk to the ring (user 2026-10-24)
	-- the south stair: up from the walk to the paving at z -54, the same steps
	for k = 1, 4 do
		box("ParkStair", WALK_X0, -8, -54 - 2.25 * k, WALK_X1, -0.5 * k, -54 - 2.25 * (k - 1), STONE, o(Enum.Material.Limestone))
	end
	-- (no east stair: the east tiers are the way down there, user 2026-10-24)
	for k = 1, 5 do
		local za = -196 + (k - 1) * 2.25
		local zb = if k == 5 then -165 else za + 2.25
		box("ParkStair", -114.5, -8, za, -79.5, if k == 5 then -2.48 else -0.5 * k, zb, STONE, o(Enum.Material.Limestone)) -- (the last one runs on as the walk, 0.02 over the ring it meets)
	end
	-- an arc of boxes (r0..r1 from c, angles a0..a1 in degrees, 0 = +x, 90 = +z)
	local function arc(name, c: Vector3, r0, r1, a0, a1, y0, y1, color, mat, n)
		n = n or math.max(6, math.floor(math.abs(a1 - a0) / 8))
		local rm, w = (r0 + r1) / 2, r1 - r0
		for i = 0, n - 1 do
			local t0, t1 = math.rad(a0 + (a1 - a0) * i / n), math.rad(a0 + (a1 - a0) * (i + 1) / n)
			local tm = (t0 + t1) / 2
			local len = 2 * r1 * math.sin(math.abs(t1 - t0) / 2) + 0.15
			local p = Vector3.new(c.X + rm * math.cos(tm), (y0 + y1) / 2, c.Z + rm * math.sin(tm))
			local out = Vector3.new(math.cos(tm), 0, math.sin(tm))
			part(name, Vector3.new(w, y1 - y0, len), CFrame.lookAt(p, p + Vector3.yAxis:Cross(out)), color, o(mat))
		end
	end
	-- the round stepped mound: three stone rings stepping up, a seat ledge, a sculpture
	vcyl("MoundPlinth", C + Vector3.new(0, LEVELS[2][2] - MOUND_H, 0), 30, MOUND_H - LEVELS[2][2], STONE, o(Enum.Material.Limestone)) -- (from the pit floor up to the mound)
	vcyl("MoundStep", C, 30, 0.6, STONE, o(Enum.Material.Limestone))
	vcyl("MoundStep", C, 22, 1.2, STONE, o(Enum.Material.Limestone))
	vcyl("MoundStep", C, 14, 1.8, STONE, o(Enum.Material.Limestone))
	vcyl("MoundTop", C + Vector3.new(0, 1.8, 0), 12, 0.1, PAVE2, o(Enum.Material.Slate))
	arc("MoundSeat", C, 9.6, 11, 200, 340, 1.2, 2.6, STONE, Enum.Material.Limestone)
	arc("MoundCushion", C, 9.7, 10.9, 200, 340, 2.6, 2.8, CUSH, Enum.Material.Fabric)
	vcyl("SculptureBase", C + Vector3.new(0, 1.9, 0), 3, 1, Color3.fromRGB(70, 70, 74), o(Enum.Material.Granite))
	part("Sculpture", Vector3.new(1.6, 5, 1.6), CFrame.new(C + Vector3.new(0, 5.4, 0)) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(160, 120, 80), o(Enum.Material.Metal))
	part("Sculpture", Vector3.new(1.2, 3.4, 1.2), CFrame.new(C + Vector3.new(0.9, 4.6, 0.6)) * CFrame.Angles(0, 0, math.rad(-14)), Color3.fromRGB(160, 120, 80), o(Enum.Material.Metal))
	-- the curved wooden deck with the white sofa: out of the circle, on the
	-- paving by the west tree bed in the south-west (user 2026-10-24), curving
	-- round a centre to its east so the sofa faces into the park
	local SC = Vector3.new(-110, 0, -72)
	arc("ParkDeck", SC, 23, 30, 145, 215, 0.08, 0.98, WOOD, Enum.Material.WoodPlanks)
	arc("CurvedSofa", SC, 27.4, 29.4, 150, 210, 0.98, 2.38, CUSH, Enum.Material.Fabric)
	arc("CurvedSofaBack", SC, 29.4, 30, 150, 210, 0.98, 3.68, CUSH, Enum.Material.Fabric)
	for a = 154, 206, 7.5 do
		local r = math.rad(a)
		local p = Vector3.new(SC.X + 28.3 * math.cos(r), 2.68, SC.Z + 28.3 * math.sin(r))
		seat("ParkSofa", CFrame.lookAt(p, Vector3.new(SC.X, 2.68, SC.Z)), Vector3.new(2.2, 0.3, 1.8), CUSH, P)
	end
	-- tiered wooden seats in an arc facing the mound, east and west (user
	-- 2026-10-24: plain wood, no cushions and no E prompt; walking onto a seat
	-- still sits you down, so the seat parts are invisible and untagged).
	-- stop0 / stop1: { "x" | "z", value } makes that end of every tier flush on
	-- a straight line (the walk's edge, or the line the raised ground starts on)
	local function angAt(r, stop, near)
		local best
		local cands = {}
		if stop[1] == "x" then
			local a = math.deg(math.acos(math.clamp((stop[2] - C.X) / r, -1, 1)))
			cands = { a, -a }
		else
			local a = math.deg(math.asin(math.clamp((stop[2] - C.Z) / r, -1, 1)))
			cands = { a, 180 - a }
		end
		for _, c in ipairs(cands) do
			for k = -2, 2 do
				local v = c + 360 * k
				if not best or math.abs(v - near) < math.abs(best - near) then best = v end
			end
		end
		return best
	end
	local function tiers(a0, a1, r0, stop0, stop1, seatZones)
		local dir = if a1 > a0 then 1 else -1 -- the arc runs from a0 to a1
		for k = 0, 2 do
			local ri, ro = r0 + k * 2.6, r0 + 2.6 + k * 2.6
			-- the top tier runs out to the circle's edge (r 44), so no floor gap
			-- shows between it and the ground behind (user 2026-10-24)
			local nSeg = nil
			if (stop0 or stop1) and k == 2 then ro, nSeg = 44.3, 40 end
			local top = 0.9 + k * 0.9
			local y = LEVELS[1][2] + top / 2
			local wo2 = o(Enum.Material.WoodPlanks)
			local function on(r, a) return Vector3.new(C.X + r * math.cos(math.rad(a)), y, C.Z + r * math.sin(math.rad(a))) end
			-- a flush end: the boxes stop 3-4 degrees before the line (their square
			-- ends would poke past it); wedges fill from there: inner arc, the line,
			-- outer arc. Built at the level's height directly (not shifted below)
			local function flush(stop, near, inward)
				local ai, ao = angAt(ri, stop, near), angAt(ro, stop, near)
				local aS = (if inward > 0 then math.max(ai, ao) else math.min(ai, ao)) + 4 * inward
				local prev = on(ri, aS)
				for j = 1, 4 do
					local p = on(ri, aS + (ai - aS) * j / 4)
					wedgeTri("ParkTierEnd", on(ro, aS), prev, p, top, WOOD, wo2)
					prev = p
				end
				for j = 0, 7 do
					wedgeTri("ParkTierEnd", prev, on(ro, ao - (ao - aS) * j / 8), on(ro, ao - (ao - aS) * (j + 1) / 8), top, WOOD, wo2)
				end
				return aS, ai, ao
			end
			local b0, b1 = a0, a1
			local e0, e1 = a0, a1 -- the band's real ends (for the seats)
			if stop0 then b0, e0 = flush(stop0, a0, dir) end
			if stop1 then b1, e1 = flush(stop1, a1, -dir) end
			arc("ParkTier", C, ri, ro, b0, b1, 0, top, WOOD, Enum.Material.WoodPlanks, nSeg)
			-- invisible seats sunk into the tread near its front edge, so the sitter's
			-- hips rest on the wood and the legs hang over the step below (user 2026-10-24)
			local rs = ri + 0.9
			-- where people can sit: given zones (user's red boxes) or the whole arc;
			-- seats side by side every 2 studs so a group sits together, the rest
			-- of the tiers stays free to walk on (user 2026-10-24)
			local angles = {}
			for _, zone in ipairs(seatZones or { { e0 + dir, e1 - dir } }) do
				local step = math.deg(2 / rs)
				local lo, hi = math.min(zone[1], zone[2]), math.max(zone[1], zone[2])
				local za, zb = lo + math.deg(1 / rs), hi - math.deg(1 / rs)
				local n = math.max(0, math.floor((zb - za) / step + 1e-6))
				local pad = ((zb - za) - n * step) / 2
				for i = 0, n do table.insert(angles, za + pad + i * step) end
			end
			for _, ad in ipairs(angles) do
				local a = math.rad(ad)
				local p = Vector3.new(C.X + rs * math.cos(a), top - 0.3, C.Z + rs * math.sin(a)) -- seat top 0.2 under the tread: the hips touch the wood
				local s = Instance.new("Seat")
				s.Name = "ParkTierSeat"
				s.Anchored = true
				s.Size = Vector3.new(1.8, 0.2, 1.8)
				s.CFrame = CFrame.lookAt(p, Vector3.new(C.X, p.Y, C.Z))
				s.Transparency = 1
				s.CanCollide = false
				CS:AddTag(s, "TouchSeat") -- ClubService: walking over it sits you down (no prompt)
				s.Parent = P
			end
		end
	end
	-- east: in the outer ring from the gate walk's east edge (x -79.5) round to
	-- the east; its south end is flush on z -114 (user 2026-10-24: the tiers are
	-- the way down there, no separate stair); a walkway by the walk and one in the middle
	-- (the line ends stop 0.03 short of the walk's cut face: the two faces flickered)
	local EAST_ZL = -114
	tiers(380, 297, 34.6, { "z", EAST_ZL }, { "x", -79.47 }, { { 314, 335 }, { 342, 362 } })
	-- west: in the outer ring outside the curved sofa deck, where the four wicker
	-- chairs stood (user 2026-10-24, red box): seats only in the user's three
	-- red boxes, walkways between
	tiers(145, 245, 34.6, nil, { "x", -114.53 }, { { 151, 182 }, { 189.5, 208.5 }, { 218, 230.5 } })
	-- the raised ground beside the west tiers' south end (user 2026-10-24): the
	-- paving comes out from behind the tiers to their end, and its edge runs
	-- from the bottom tier's front corner in a smooth curve down to the walk's
	-- west edge (x -102), where it meets the circle. Built as one merged solid
	-- (no seams) at the paving's height, with collision rows in its real shape
	local c2i = Vector2.new(C.X, C.Z)
	local function onI(r, deg) return c2i + Vector2.new(math.cos(math.rad(deg)), math.sin(math.rad(deg))) * r end
	-- A: the bottom tier's front corner, B: behind the tiers on the paving's cut
	-- edge, J: the walk's edge on the circle
	local function infill(A: Vector2, B: Vector2, J: Vector2)
		local c2 = c2i
		local on = onI
		local L = (J - A).Magnitude
		local c1, cc2 = A + (J - A).Unit * (0.4 * L), J - Vector2.new(0, 1) * (0.4 * L)
		local poly = { A, B }
		local aB = math.deg(math.atan2(B.Y - C.Z, B.X - C.X))
		local aJ = math.deg(math.atan2(J.Y - C.Z, J.X - C.X))
		if math.abs(aJ - aB) > 180 then aJ += if aJ < aB then 360 else -360 end
		for i = 1, 11 do table.insert(poly, on(44.1, aB + (aJ - aB) * i / 12)) end
		table.insert(poly, J)
		for i = 11, 1, -1 do -- the curve back from J to A
			local s = i / 12
			local q = 1 - s
			table.insert(poly, A * q ^ 3 + c1 * 3 * q * q * s + cc2 * 3 * q * s * s + J * s ^ 3)
		end
		-- ear clipping into triangles
		local pts = {}
		for i, p in ipairs(poly) do pts[i] = p end
		local area = 0
		for i = 1, #pts do local a, b = pts[i], pts[i % #pts + 1] area += a.X * b.Y - b.X * a.Y end
		if area < 0 then local r = {} for i = #pts, 1, -1 do table.insert(r, pts[i]) end pts = r end
		local function cr(o2, a, b) return (a.X - o2.X) * (b.Y - o2.Y) - (a.Y - o2.Y) * (b.X - o2.X) end
		local tris = {}
		local idx = {}
		for i = 1, #pts do idx[i] = i end
		local guard = 0
		while #idx > 3 and guard < 2000 do
			guard += 1
			local found = false
			for k = 1, #idx do
				local ia, ib, ic = idx[(k - 2) % #idx + 1], idx[k], idx[k % #idx + 1]
				local a, b, c = pts[ia], pts[ib], pts[ic]
				if cr(a, b, c) > 1e-6 then
					local ear = true
					for _, j in ipairs(idx) do
						if j ~= ia and j ~= ib and j ~= ic then
							local p = pts[j]
							if cr(a, b, p) >= 0 and cr(b, c, p) >= 0 and cr(c, a, p) >= 0 then ear = false break end
						end
					end
					if ear then table.insert(tris, { a, b, c }) table.remove(idx, k) found = true break end
				end
			end
			if not found then break end
		end
		if #idx == 3 then table.insert(tris, { pts[idx[1]], pts[idx[2]], pts[idx[3]] }) end
		local holder = Instance.new("Folder")
		holder.Parent = workspace
		local bottom = LEVELS[1][2] - 0.1 -- (a hair into the ring below: no shared face)
		for _, tr in ipairs(tris) do
			local function v(p) return Vector3.new(p.X, (bottom + 0.08) / 2, p.Y) end
			wedgeTri("ParkInfill", v(tr[1]), v(tr[2]), v(tr[3]), 0.08 - bottom, PAVE, { parent = holder, material = Enum.Material.Slate })
		end
		local pieces = holder:GetChildren()
		local first = table.remove(pieces, 1)
		local ok, u = pcall(function() return first:UnionAsync(pieces) end)
		if ok and u then
			u.Name = "ParkInfill"
			u.UsePartColor = true
			u.Color = PAVE
			u.Material = Enum.Material.Slate
			u.Anchored = true
			u.CanCollide = false -- (collision rows below: a hull would cover the sunken side)
			u.CanQuery = false
			u.Parent = P
		else
			for _, w in ipairs(holder:GetChildren()) do w.Parent = P end
		end
		holder:Destroy()
		-- collision rows: scan the outline row by row
		local zMin, zMax = math.huge, -math.huge
		for _, p in ipairs(poly) do zMin = math.min(zMin, p.Y) zMax = math.max(zMax, p.Y) end
		for z = zMin, zMax - 0.01, 1 do
			local zm = math.min(z + 0.5, zMax)
			local xs = {}
			for i = 1, #poly do
				local a, b = poly[i], poly[i % #poly + 1]
				if (a.Y > zm) ~= (b.Y > zm) then table.insert(xs, a.X + (zm - a.Y) / (b.Y - a.Y) * (b.X - a.X)) end
			end
			table.sort(xs)
			for i = 1, #xs - 1, 2 do
				if xs[i + 1] - xs[i] > 0.05 then
					local p = box("ParkCollide", xs[i], -0.92, z, xs[i + 1], 0.08, math.min(z + 1, zMax), PAVE, { parent = P, transparency = 1 })
					p.CastShadow = false
				end
			end
		end
	end

	infill(onI(34.6, 145), onI(44.1, 145), Vector2.new(WALK_X0, C.Z + math.sqrt(44.1 ^ 2 - (WALK_X0 - C.X) ^ 2)))
	-- the same on the east (user 2026-10-24): from the east tiers' flush south
	-- end (z -114) down to the walk's east edge
	do
		local dz = EAST_ZL - C.Z
		infill(Vector2.new(C.X + math.sqrt(34.6 ^ 2 - dz * dz), EAST_ZL), Vector2.new(C.X + math.sqrt(44.1 ^ 2 - dz * dz), EAST_ZL),
			Vector2.new(WALK_X1, C.Z + math.sqrt(44.1 ^ 2 - (WALK_X1 - C.X) ^ 2)))
	end	arc("ParkDeckWalk", C, 22, 27, 52, 110, 0, 0.6, WOOD, Enum.Material.WoodPlanks)
	-- (no wicker chairs: tiered seats there instead, user 2026-10-24)
	-- a raised wooden deck (one step, the tiers' wood) between the west tree bed,
	-- the gate walk and the sunken circle (user 2026-10-24, red outline + sketch):
	-- x -141..-114.5 from z -198 down to the circle (r 44), its curved edge
	-- following the circle; built from wedge triangles fanned from its NW corner
	local DECK_TOP = 0.08 + 0.9
	local function onDeck(x, z)
		if x < -141 or x > -114.5 or z < -198 then return false end
		return (x - C.X) ^ 2 + (z - C.Z) ^ 2 > 44 * 44
	end
	do
		local y = DECK_TOP / 2
		local wo = o(Enum.Material.WoodPlanks)
		local corner = Vector3.new(-141, y, -198)
		local function v(x, z) return Vector3.new(x, y, z) end
		wedgeTri("ParkUpperDeck", corner, v(-114.5, -198), v(-114.5, -128 - math.sqrt(44 ^ 2 - 18.5 ^ 2)), DECK_TOP, WOOD, wo)
		local aS = math.deg(math.atan2(-math.sqrt(44 ^ 2 - 18.5 ^ 2), -18.5)) % 360 -- where the circle meets x -114.5
		local N = 18
		local prev = v(-114.5, -128 - math.sqrt(44 ^ 2 - 18.5 ^ 2))
		for i = 1, N do
			local a = math.rad(aS + (180 - aS) * i / N)
			local p = v(C.X + 44 * math.cos(a), C.Z + 44 * math.sin(a))
			wedgeTri("ParkUpperDeck", corner, prev, p, DECK_TOP, WOOD, wo)
			prev = p
		end
		wedgeTri("ParkUpperDeck", corner, prev, v(-141, C.Z), DECK_TOP, WOOD, wo)
	end
	-- the walk's west wall under the deck in the deck's wood (user 2026-10-24),
	-- from the walk level up to the deck top, a hair inside the walk
	box("ParkWalkWall", -114.5, LEVELS[1][2], -196, -114.38, DECK_TOP, -128 - math.sqrt(44 ^ 2 - 18.5 ^ 2), WOOD, o(Enum.Material.WoodPlanks))
	-- past the deck corner a strip of the same wood up to the top tier's top: the
	-- paving's corner showed grey between the tiers' end and this wall (user 2026-10-24)
	do -- the same at the east tiers' end on the gate walk's east edge
		local zc = -128 - math.sqrt(44 ^ 2 - 16.53 ^ 2)
		box("ParkWalkWall", -79.62, LEVELS[1][2], zc - 0.5, -79.47, LEVELS[1][2] + 2.68, zc + 0.5, WOOD, o(Enum.Material.WoodPlanks))
	end
	box("ParkWalkWall", -114.53, LEVELS[1][2], -128 - math.sqrt(44 ^ 2 - 18.5 ^ 2) - 0.02, -114.38, LEVELS[1][2] + 2.68, -128 - math.sqrt(44 ^ 2 - 18.5 ^ 2) + 0.6, WOOD, o(Enum.Material.WoodPlanks))
	-- white parasols with a round table and two chairs
	local function parasolSet(at: Vector3)
		vcyl("ParasolPole", at, 0.25, 9, Color3.fromRGB(200, 200, 204), o(Enum.Material.Metal, { nocol = true }))
		for k = 0, 9 do
			local a = k / 10 * 2 * math.pi
			local tip = at + Vector3.new(math.cos(a) * 5, 7.4, math.sin(a) * 5)
			local top = at + Vector3.new(0, 9, 0)
			part("ParasolRib", Vector3.new(3.2, 0.12, (tip - top).Magnitude), CFrame.lookAt((tip + top) / 2, tip), Color3.fromRGB(246, 244, 238), o(Enum.Material.Fabric, { nocol = true }))
		end
		vcyl("ParkTable", at + Vector3.new(0, 2.4, 0), 3.4, 0.25, Color3.fromRGB(70, 70, 74), o(Enum.Material.Metal))
		vcyl("ParkTableLeg", at, 0.4, 2.4, Color3.fromRGB(70, 70, 74), o(Enum.Material.Metal))
		for _, d in ipairs({ -2.4, 2.4 }) do
			local p = at + Vector3.new(d, 1.3, 0)
			seat("ParkChair", CFrame.lookAt(p, at + Vector3.new(0, 1.3, 0)), Vector3.new(1.8, 0.3, 1.8), Color3.fromRGB(90, 90, 96), P)
		end
	end
	-- (the parasol table by the south walk is gone, user 2026-10-24)
	-- (no parasol set on the raised deck either, user 2026-10-24)
	-- planting beds along the north and east edges and the south-west corner:
	-- curbed soil with round shrubs (balls) of several greens, trees behind
	local GREENS = { Color3.fromRGB(86, 128, 70), Color3.fromRGB(110, 146, 82), Color3.fromRGB(70, 110, 62), Color3.fromRGB(140, 160, 96), Color3.fromRGB(96, 120, 84) }
	local rng = Random.new(2410)
	local function bed(ax, az, bx, bz, nShrubs, trees)
		box("ParkBedCurb", ax, 0, az, bx, 0.7, bz, Color3.fromRGB(196, 194, 188), o(Enum.Material.Granite))
		box("ParkBedSoil", ax + 0.4, 0, az + 0.4, bx - 0.4, 0.75, bz - 0.4, Color3.fromRGB(96, 76, 56), o(Enum.Material.Ground))
		for _ = 1, nShrubs do
			local s = rng:NextNumber(2, 4.2)
			local p = Vector3.new(rng:NextNumber(ax + 1.5, bx - 1.5), 0.75 + s * 0.35, rng:NextNumber(az + 1.5, bz - 1.5))
			part("ParkShrub", Vector3.new(s, s * 0.85, s), CFrame.new(p), GREENS[rng:NextInteger(1, #GREENS)], o(Enum.Material.Grass, { shape = Enum.PartType.Ball, nocol = true }))
		end
		local BIRCH_SCALE = { 1.3, 1.15, 0.95, 0.85, 0.9, 0.7 }
		for i, tp in ipairs(trees) do
			local pick = ((i * 5) % 6) + 1
			local tree = foliage("Birch" .. pick, BIRCH_SCALE[pick] * 0.9, CFrame.new(tp[1], 0.75, tp[2]) * CFrame.Angles(0, i * 1.7, 0))
			if tree then
				tree.Parent = P
				for _, sa in ipairs(tree:GetDescendants()) do
					if sa:IsA("SurfaceAppearance") and sa.AlphaMode == Enum.AlphaMode.Overlay then
						pcall(function() sa.Color = Color3.fromRGB(150, 112, 82) end)
					end
				end
			end
		end
	end
	-- (user 2026-10-24, first pass) no beds by the gate; along the east street a
	-- single row of trees in square pits; along the west (beach road) side one
	-- long bed packed with trees and round shrubs
	-- (the row of tree pits along the east sidewalk is gone, user 2026-10-24)

	-- (the long bed along the west edge is gone too, user 2026-10-24)	-- low park lamps along the edges; they glow at night
	for _, lp in ipairs({ { -118, -186 }, { -76, -186 }, { -60, -162 }, { -70, -110 }, { -112, -66 }, { -138, -150 }, { -138, -100 } }) do
		local b = Vector3.new(lp[1], if onDeck(lp[1], lp[2]) then DECK_TOP - 0.08 else 0, lp[2])
		vcyl("ParkLampPost", b, 0.35, 8, Color3.fromRGB(40, 42, 46), o(Enum.Material.Metal))
		local g = part("ParkLampGlobe", Vector3.new(1.4, 1.4, 1.4), CFrame.new(b + Vector3.new(0, 8.6, 0)), Color3.fromRGB(255, 244, 220), o(Enum.Material.SmoothPlastic, { shape = Enum.PartType.Ball, nocol = true }))
		g:SetAttribute("NightRange", 14)
		g:SetAttribute("NightBrightness", 1.2)
		CS:AddTag(g, "NightGlow")
	end
	-- everything on the plaza sits on the dome (beds, their plants and the dome itself stay put)
	for _, c in ipairs(P:GetChildren()) do
		if c:IsA("BasePart") and not (c.Name:match("^ParkBed") or c.Name == "ParkShrub" or c.Name == "ParkPaving" or c.Name == "ParkLevel" or c.Name == "ParkStair" or c.Name == "ParkCollide" or c.Name == "ParkUpperDeck" or c.Name == "ParkTierEnd" or c.Name == "ParkWalkWall" or c.Name == "ParkInfill") then -- (built at their own heights)
			local h = if c.Name:match("^Mound") or c.Name:match("^Sculpture") then MOUND_H else domeH(c.Position.X, c.Position.Z)
			if h ~= 0 then c.CFrame = c.CFrame + Vector3.new(0, h, 0) end
		end
	end
	local anchor = part("ParkLabelAnchor", Vector3.new(1, 1, 1), CFrame.new(C + Vector3.new(0, 13, 0)), PAVE, o(Enum.Material.SmoothPlastic, { transparency = 1, nocol = true }))
	label(anchor, "도시 공원", Color3.fromRGB(60, 140, 90), 2, 0.7)
	-- (user 2026-10-24, performance) the invisible collision rows are merged:
	-- rows of the same height that follow each other with edges no more than
	-- 0.25 apart become one box (the box keeps the inner edges, so it never
	-- reaches over a hole by more than nothing and falls short by 0.25 at most)
	do
		local TOL = 0.25
		local groups = {}
		for _, c in ipairs(P:GetChildren()) do
			if c:IsA("BasePart") and c.Name == "ParkCollide" then
				local key = string.format("%.2f|%.2f", c.Position.Y, c.Size.Y)
				groups[key] = groups[key] or {}
				table.insert(groups[key], { p = c, x0 = c.Position.X - c.Size.X / 2, x1 = c.Position.X + c.Size.X / 2, z0 = c.Position.Z - c.Size.Z / 2, z1 = c.Position.Z + c.Size.Z / 2 })
			end
		end
		for _, list in pairs(groups) do
			table.sort(list, function(a, b)
				if math.abs(a.z0 - b.z0) > 1e-3 then return a.z0 < b.z0 end
				return a.x0 < b.x0
			end)
			local runs = {}
			for _, r in ipairs(list) do
				local hit
				for _, o in ipairs(runs) do
					if math.abs(o.z1 - r.z0) < 1e-3
						and math.max(o.x0hi, r.x0) - math.min(o.x0lo, r.x0) <= TOL
						and math.max(o.x1hi, r.x1) - math.min(o.x1lo, r.x1) <= TOL then
						hit = o
						break
					end
				end
				if hit then
					hit.x0lo, hit.x0hi = math.min(hit.x0lo, r.x0), math.max(hit.x0hi, r.x0)
					hit.x1lo, hit.x1hi = math.min(hit.x1lo, r.x1), math.max(hit.x1hi, r.x1)
					hit.z1 = r.z1
					r.p:Destroy()
				else
					table.insert(runs, { p = r.p, x0lo = r.x0, x0hi = r.x0, x1lo = r.x1, x1hi = r.x1, z0 = r.z0, z1 = r.z1 })
				end
			end
			for _, o in ipairs(runs) do
				local y = o.p.Position.Y
				o.p.Size = Vector3.new(o.x1lo - o.x0hi, o.p.Size.Y, o.z1 - o.z0)
				o.p.CFrame = CFrame.new((o.x0hi + o.x1lo) / 2, y, (o.z0 + o.z1) / 2)
			end
		end
	end
	-- (user 2026-10-24) no step at the sidewalks: the whole park goes up so its
	-- top paving is level with them (0.6; the sunken levels, stairs and decks
	-- keep their heights relative to it), and that paving gets the sidewalks'
	-- pavers (street_dress's look: colour, the paver texture 7 x 7 on top)
	local RAISE = CURB - 0.08
	for _, c in ipairs(P:GetChildren()) do
		if c:IsA("BasePart") then c.CFrame += Vector3.new(0, RAISE, 0)
		elseif c:IsA("Model") then c:PivotTo(c:GetPivot() + Vector3.new(0, RAISE, 0)) end
	end
	for _, c in ipairs(P:GetChildren()) do
		-- (user 2026-10-24) the stairs and the sunken floors below them: plain
		-- near-white grey, no pavers
		if c:IsA("BasePart") and (c.Name == "ParkLevel" or c.Name == "ParkStair") then
			c.Color = Color3.fromRGB(224, 224, 220)
			c.Material = Enum.Material.Concrete
		end
		if c:IsA("BasePart") and (c.Name == "ParkPaving" or c.Name == "ParkInfill") then
			c.Color = Color3.fromRGB(176, 172, 166)
			c.Material = Enum.Material.SmoothPlastic
			-- the face that points up in the world (the infill is a union of wedges:
			-- its own axes are turned); pavers on it and on the side faces (the cut
			-- walls showed plain, user 2026-10-24), none on the bottom
			local up = c.CFrame:VectorToObjectSpace(Vector3.yAxis)
			local ax, ay, az = math.abs(up.X), math.abs(up.Y), math.abs(up.Z)
			local upF = if ay >= ax and ay >= az then (if up.Y > 0 then Enum.NormalId.Top else Enum.NormalId.Bottom)
				elseif ax >= az then (if up.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left)
				else (if up.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front)
			for _, fc in ipairs(Enum.NormalId:GetEnumItems()) do
				if Vector3.FromNormalId(fc):Dot(Vector3.FromNormalId(upF)) > -0.5 then
					local tx = Instance.new("Texture")
					tx.Texture = "rbxassetid://133933193561069" -- (street_dress IMG.sidewalk)
					tx.Face = fc
					tx.StudsPerTileU = 7
					tx.StudsPerTileV = 7
					tx.Parent = c
				end
			end
		end
	end
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
	-- (user 2026-10-27) three storeys outside, taller than 오후네컷: the walls
	-- run up to the roof (65); the street door 18 high (graybox EDH)
	local Z0, Z1, TOPY = -260.2 + CDZ, -95.8 + CDZ, 65 -- to the outer faces of the lilac side walls
	local FL = TOPY / 3 -- one storey on the front
	local EDH = 18
	local function gold(name, x0, y0, z0, x1, y1, z1)
		local p = box(name, x0, y0, z0, x1, y1, z1, GOLD, { parent = K, material = Enum.Material.Foil })
		p.Reflectance = 0.25
		return p
	end
	-- backing (hides the lilac) on the west face and the other outside faces
	box("Cladding", 47.8, 0, Z0, 48, TOPY, DZ0, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 47.8, 0, DZ1, 48, TOPY, Z1, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 47.8, EDH, DZ0, 48, TOPY, DZ1, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 48, 0, -260.2 + CDZ, 190.2, TOPY, -260 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal }) -- (the club 19 longer east, user 2026-10-25)
	box("Cladding", 190, 0, -260.2 + CDZ, 190.2, TOPY, -95.8 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal })
	box("Cladding", 48, 0, -96 + CDZ, 190.2, TOPY, -95.8 + CDZ, BLACK, { parent = K, material = Enum.Material.Metal })
	box("CapBand", 47.3, TOPY - 0.8, Z0, 48, TOPY + 0.4, Z1 + 1, BLACK2, { parent = K, material = Enum.Material.Metal })
	-- floor bands between the storeys, so the front reads as three floors
	for f = 1, 2 do box("FloorBand", 47.3, FL * f - 0.5, Z0, 47.8, FL * f + 0.5, Z1 + 0.5, BLACK2, { parent = K, material = Enum.Material.Metal }) end
	-- a clean black end column where the front meets the shop building to the
	-- north: it covers the ends of the sign band, louvres and windows (user 2026-10-24)
	box("ClubEndColumn", 46.2, 0, Z0, 48, TOPY + 0.4, Z0 + 0.9, BLACK, { parent = K, material = Enum.Material.Metal })
	-- ground floor: gold portal round the (taller) door
	gold("GoldJamb", 45.8, 0, DZ0 - 3, 47.8, EDH + 3, DZ0)
	gold("GoldJamb", 45.8, 0, DZ1, 47.8, EDH + 3, DZ1 + 3)
	gold("GoldLintel", 45.8, EDH, DZ0, 47.8, EDH + 3, DZ1)
	for _, zz in ipairs({ DZ0 + 0.2, DZ1 - 0.2 }) do gold("GoldDoorFrame", 46.6, 0.1, zz - 0.2, 47.8, EDH, zz + 0.2) end
	-- sign band with spaced white letters and the crown, up above the taller door
	local SB0, SB1 = EDH + 3.6, EDH + 3.6 + 6.8
	local band = box("ClubSign", 46.4, SB0, Z0, 47.8, SB1, Z1, BLACK, { parent = K, material = Enum.Material.Metal }) -- end to end of the front (user 2026-10-24)
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
		local cz, cy = (DZ0 + DZ1) / 2, SB0 + 0.8
		gold("CrownBase", 45.4, cy, cz - 2.6, 45.9, cy + 0.9, cz + 2.6)
		for k = -2, 2 do
			local h = if k == 0 then 2.6 elseif math.abs(k) == 1 then 1.8 else 2.2
			gold("CrownSpike", 45.4, cy + 0.9, cz + k * 1.2 - 0.3, 45.9, cy + 0.9 + h, cz + k * 1.2 + 0.3)
			local b = part("CrownJewel", Vector3.new(0.6, 0.6, 0.6), CFrame.new(45.65, cy + 1.2 + h, cz + k * 1.2), GOLD, { parent = K, shape = Enum.PartType.Ball, material = Enum.Material.Foil })
			b.Reflectance = 0.25
		end
	end
	-- (user 2026-10-24) the louvres on the ground floor beside the portal, as
	-- real slats: each one 0.9 deep, tilted down 30 degrees, on black fins; they
	-- run to the end of the front and round the corner by the photo booth
	-- building. The two upper floors are runs of tall black-framed windows.
	local LY0, LY1 = 9, EDH + 2.6
	local function slats(z0s, z1s)
		for y = LY0 + 0.4, LY1 - 0.6, 0.85 do
			part("Louvre", Vector3.new(0.9, 0.16, z1s - z0s), CFrame.new(47.35, y, (z0s + z1s) / 2) * CFrame.Angles(0, 0, math.rad(30)), BLACK2, { parent = K, material = Enum.Material.Metal, nocol = true })
		end
		for zz = z0s, z1s, 8 do box("LouvreFin", 46.8, LY0, zz - 0.12, 47.8, LY1, zz + 0.12, BLACK, { parent = K, material = Enum.Material.Metal }) end
		box("LouvreFin", 46.8, LY0, z1s - 0.24, 47.8, LY1, z1s, BLACK, { parent = K, material = Enum.Material.Metal })
	end
	slats(Z0, DZ0 - 3)
	slats(DZ1 + 3, Z1)
	-- round the corner: the club's south face in the gap to the photo booth building
	for y = LY0 + 0.4, LY1 - 0.6, 0.85 do
		part("Louvre", Vector3.new(10, 0.16, 0.9), CFrame.new(53, y, Z1 + 0.45) * CFrame.Angles(math.rad(30), 0, 0), BLACK2, { parent = K, material = Enum.Material.Metal, nocol = true })
	end
	local WZ0, WZ1 = Z0 + 1, Z1 - 1
	for f = 1, 2 do -- 2F and 3F windows
		local y0, y1 = FL * f + (if f == 1 then SB1 - FL + 1 else 3), FL * (f + 1) - 3
		box("WindowGlass", 47.6, y0, WZ0, 47.8, y1, WZ1, Color3.fromRGB(38, 46, 54), { parent = K, material = Enum.Material.Glass })
		box("WindowFrame", 47.2, y0 - 0.6, WZ0, 47.8, y0, WZ1, BLACK, { parent = K })
		box("WindowFrame", 47.2, y1, WZ0, 47.8, y1 + 0.6, WZ1, BLACK, { parent = K })
		local nW = math.floor((WZ1 - WZ0) / 5.5 + 0.5)
		for i = 0, nW do
			local zz = WZ0 + (WZ1 - WZ0) * i / nW
			box("WindowMullion", 47.2, y0, zz - 0.25, 47.8, y1, zz + 0.25, BLACK, { parent = K })
		end
	end
	-- QUEUE (user sketch 2026-10-27, photos of 홍대 club lines): black stanchions
	-- with a red rope from the middle of the door out to the sidewalk and along
	-- it to the north, the waiting line between the rope and the wall under a
	-- row of white pop-up tents against the wall (the old iron fences are gone)
	do
		local QX = 40 -- the rope line (x 34 → 41 → 40, user 2026-10-27)
		local QZ0, QZ1 = DZ0 - 37, (DZ0 + DZ1) / 2 -- north end of the line, the door's middle
		local RED = Color3.fromRGB(196, 24, 36)
		local function post(x, zz)
			vcyl("StanchionBase", Vector3.new(x, CURB, zz), 1.3, 0.2, BLACK, { parent = K, material = Enum.Material.Metal })
			vcyl("StanchionPole", Vector3.new(x, CURB, zz), 0.3, 3.2, BLACK, { parent = K, material = Enum.Material.Metal })
			part("StanchionCap", Vector3.new(0.45, 0.45, 0.45), CFrame.new(x, CURB + 3.3, zz), BLACK, { parent = K, shape = Enum.PartType.Ball, material = Enum.Material.Metal })
		end
		local function rope(a: Vector3, b: Vector3)
			local mid = (a + b) / 2
			part("QueueRope", Vector3.new(0.3, 0.3, (b - a).Magnitude), CFrame.lookAt(mid, b), RED, { parent = K, material = Enum.Material.Fabric, nocol = true }) -- (tall avatars stood on it: the invisible block does the holding)
		end
		local Y = CURB + 2.9
		-- out from the door's middle to the rope line
		local corner = Vector3.new(QX, Y, QZ1)
		post(47, QZ1) post(QX, QZ1)
		rope(Vector3.new(47, Y, QZ1), corner)
		-- along the sidewalk to the north end (posts every ~5)
		local n = math.max(1, math.floor((QZ1 - QZ0) / 5 + 0.5))
		for i = 1, n do
			local zz = QZ1 - (QZ1 - QZ0) * i / n
			post(QX, zz)
			rope(Vector3.new(QX, Y, QZ1 - (QZ1 - QZ0) * (i - 1) / n), Vector3.new(QX, Y, zz))
		end
		-- invisible wall along the rope so the line holds (7 high: a lower one was stepped over)
		box("QueueBlock", QX - 0.2, CURB, QZ0, QX + 0.2, CURB + 7, QZ1, BLACK, { parent = K, transparency = 1 })
		box("QueueBlock", QX, CURB, QZ1 - 0.2, 47, CURB + 7, QZ1 + 0.2, BLACK, { parent = K, transparency = 1 })
		-- (the white tents over the line are gone, user 2026-10-27)
	end	-- the pink graybox marquee would cover the band: hidden while the layout is on
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
		-- (user 2026-10-27) the lift and its corridor as high as the raised entrance:
		-- ceiling 12 → 18 (LH), door 9 → 14 (LDH), 7 → 10 wide (tall avatars are 8 across)
		local LH, LDH = 18, 14
		-- corridor: floor, ceiling, black walls
		-- (plain, the same colour as the foyer floor: user 2026-10-25)
		box("LiftCorridorFloor", CX0, -0.5, FOYER_END - 0.5, CX1, 0, CAR0, Color3.fromRGB(26, 26, 29), { parent = E, material = Enum.Material.SmoothPlastic })
		-- the foyer's floor LED lines run on along both walls up to the lift (user 2026-10-25)
		for _, x in ipairs({ { CX0, CX0 + 0.12 }, { CX1 - 0.12, CX1 } }) do -- (thin like every floor line, user 2026-10-27)
			box("LiftCorridorLED", x[1], 0, FOYER_END - 0.5, x[2], 0.25, CAR0 - 0.7, Color3.fromRGB(255, 250, 175), { parent = E, material = Enum.Material.Neon, nocol = true })
		end
		box("LiftCorridorCeiling", CX0, LH, FOYER_END - 0.5, CX1, LH + 1, CAR1 + 0.6, DARK, { parent = E })
		-- the rest of the old fill behind the car stays solid
		box("EntryFillRest", CX0 - 0.1, -24, CAR1 + 0.6, CX1 + 0.1, 64, FILL_END, Color3.fromRGB(40, 42, 46), { parent = E }) -- (up to the raised ceiling, 2026-10-27)
		-- strip lights along the corridor ceiling
		for z = FOYER_END + 2, CAR0 - 2, 4 do
			local l = box("LiftCorridorLight", 56.6, LH - 0.2, z - 0.8, 58.9, LH, z + 0.8, Color3.fromRGB(255, 240, 220), { parent = E, nocol = true })
			local pl = Instance.new("PointLight") pl.Range = 10 pl.Brightness = 0.7 pl.Color = Color3.fromRGB(255, 225, 200) pl.Parent = l
		end
		-- lift car: brushed steel walls, gold frame, floor pad
		local STEEL = Color3.fromRGB(150, 152, 158)
		box("LiftCarFloor", CX0, -0.5, CAR0, CX1, 0, CAR1, Color3.fromRGB(60, 60, 66), { parent = E, material = Enum.Material.Metal })
		box("LiftCarBack", CX0, 0, CAR1, CX1, LH, CAR1 + 0.6, STEEL, { parent = E, material = Enum.Material.Metal })
		box("LiftCarCeiling", CX0, LH - 0.6, CAR0, CX1, LH, CAR1, STEEL, { parent = E, material = Enum.Material.Metal })
		local cl = box("LiftCarLight", 55, LH - 0.7, CAR0 + 2, 60.5, LH - 0.6, CAR1 - 2, Color3.fromRGB(255, 250, 240), { parent = E, nocol = true })
		local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 12 sl.Brightness = 1 sl.Parent = cl
		-- (user 2026-10-24) the car's sides showed the club's marble walls: plain
		-- brushed-steel lining (built-in Metal, no images), a handrail, the
		-- inside of the front wall in steel and a small button panel by the door
		local mopt = { parent = E, material = Enum.Material.Metal, nocol = true }
		local mid, DOOR = (CX0 + CX1) / 2, 10 -- (the door below: 7 wide in the middle)
		box("LiftCarSide", CX0 + 0.02, 0, CAR0, CX0 + 0.2, LH - 0.6, CAR1, STEEL, mopt)
		box("LiftCarSide", CX1 - 0.2, 0, CAR0, CX1 - 0.02, LH - 0.6, CAR1, STEEL, mopt)
		box("LiftCarInner", CX0 + 0.2, 0, CAR0, mid - DOOR / 2 - 0.6, LH - 0.6, CAR0 + 0.15, STEEL, mopt)
		box("LiftCarInner", mid + DOOR / 2 + 0.6, 0, CAR0, CX1 - 0.2, LH - 0.6, CAR0 + 0.15, STEEL, mopt)
		box("LiftCarInner", mid - DOOR / 2 - 0.6, LDH + 0.4, CAR0, mid + DOOR / 2 + 0.6, LH - 0.6, CAR0 + 0.15, STEEL, mopt)
		box("LiftHandrail", CX0 + 1, 3.2, CAR1 - 0.45, CX1 - 1, 3.4, CAR1 - 0.25, Color3.fromRGB(200, 202, 206), mopt)
		local px = mid + DOOR / 2 + 1.6 -- button panel beside the door, inside
		box("LiftButtonPanel", px - 0.6, 3.6, CAR0 + 0.15, px + 0.6, 6.4, CAR0 + 0.25, Color3.fromRGB(40, 42, 46), mopt)
		for k, y in ipairs({ 5.7, 5.0, 4.3 }) do
			local b = part("LiftButton", Vector3.new(0.12, 0.42, 0.42), CFrame.new(px, y, CAR0 + 0.3) * CFrame.Angles(0, math.rad(90), 0), if k == 1 then Color3.fromRGB(255, 190, 90) else Color3.fromRGB(220, 222, 226), { parent = E, shape = Enum.PartType.Cylinder, material = if k == 1 then Enum.Material.Neon else Enum.Material.Metal, nocol = true })
			b.CastShadow = false
		end
		-- front wall with the door opening (door 7 wide in the middle)
		local mid, DOOR = (CX0 + CX1) / 2, 10
		box("LiftFront", CX0, 0, CAR0 - 0.5, mid - DOOR / 2, LH, CAR0, DARK, { parent = E })
		box("LiftFront", mid + DOOR / 2, 0, CAR0 - 0.5, CX1, LH, CAR0, DARK, { parent = E })
		box("LiftFront", mid - DOOR / 2, LDH, CAR0 - 0.5, mid + DOOR / 2, LH, CAR0, DARK, { parent = E })
		for _, s in ipairs({ -1, 1 }) do
			box("LiftFrameGold", mid + s * (DOOR / 2 + 0.3) - 0.3, 0, CAR0 - 0.7, mid + s * (DOOR / 2 + 0.3) + 0.3, LDH + 0.3, CAR0 - 0.4, Color3.fromRGB(214, 172, 92), { parent = E, material = Enum.Material.Foil, nocol = true })
		end
		box("LiftFrameGold", mid - DOOR / 2 - 0.6, LDH, CAR0 - 0.7, mid + DOOR / 2 + 0.6, LDH + 0.4, CAR0 - 0.4, Color3.fromRGB(214, 172, 92), { parent = E, material = Enum.Material.Foil, nocol = true })
		local door = Instance.new("Model")
		door.Name = "AutoDoor"
		door:SetAttribute("Range", 8)
		for _, s in ipairs({ -1, 1 }) do
			local panel = box("LiftDoorPanel", mid + s * DOOR / 2, 0, CAR0 - 0.35, mid, LDH, CAR0 - 0.15, Color3.fromRGB(175, 178, 184), { parent = door, material = Enum.Material.Metal })
			panel:SetAttribute("Slide", Vector3.new(s * (DOOR / 2 - 0.1), 0, 0))
		end
		door.WorldPivot = CFrame.new(mid, 4, CAR0)
		door.Parent = E
		CS:AddTag(door, "AutoDoor")
		-- (no "▲ ROOFTOP" sign over the door: a call button panel on the wall to
		-- the right of the door instead, ▲ lit and ▼, plain parts, user 2026-10-25)
		do
			local px = mid - DOOR / 2 - 1.6 -- seen from the corridor (looking +z) the right is -x
			local zf = CAR0 - 0.5 -- the corridor face of the front wall
			box("LiftCallPanel", px - 0.45, 3.4, zf - 0.08, px + 0.45, 5.4, zf, Color3.fromRGB(150, 152, 158), { parent = E, material = Enum.Material.Metal, nocol = true })
			for k, y in ipairs({ 4.85, 3.95 }) do
				local up = k == 1
				part("LiftCallButton", Vector3.new(0.08, 0.6, 0.6), CFrame.new(px, y, zf - 0.12) * CFrame.Angles(0, math.rad(90), 0), if up then Color3.fromRGB(255, 190, 90) else Color3.fromRGB(215, 217, 222), { parent = E, shape = Enum.PartType.Cylinder, material = if up then Enum.Material.Neon else Enum.Material.Metal, nocol = true }).CastShadow = false
				-- a chevron on the button: two short bars (▲ / ▼)
				for _, s in ipairs({ -1, 1 }) do
					local tilt = math.rad(40) * -s * (if up then 1 else -1) -- (the apex in the middle: up for ▲)
					part("LiftCallArrow", Vector3.new(0.26, 0.05, 0.03), CFrame.new(px + s * 0.08, y, zf - 0.17) * CFrame.Angles(0, 0, tilt), Color3.fromRGB(40, 40, 44), { parent = E, nocol = true }).CastShadow = false
				end
			end
		end
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
-- (layout v8, user map 2026-10-27: the towers east of the club and 오후네컷, the two
-- beside the old Glasshouse cafe and the 노래방 tower by OH24 are gone: long
-- shop blocks with sign images instead, see SHOP_BLOCKS below)
do -- "오늘의 큰손" tower over the OH24 store (user mock-ups + reference photos
	-- 2026-10-25): a tall tower of dark granite with narrow vertical window
	-- slits covering the whole store roof (x -130..-56, z 66..104, roof y 14),
	-- and a tall LED screen wrapping three sides in a ㄷ shape with rounded
	-- corners: east (road) → north (crossing) → west (beach road). The cards
	-- of today's big spenders run along it (RankBoard "todayBand", attribute
	-- BandStart; RankingBoards client).
	local L = Instance.new("Model")
	L.Name = "BigSpenderLED"
	L.Parent = T
	local GRANITE = Color3.fromRGB(74, 70, 68)
	local SLIT = Color3.fromRGB(28, 32, 38)
	local FR = Color3.fromRGB(16, 16, 20)
	-- (user 2026-10-27: the tower covers the whole store roof, x -135..-56, z 66..210)
	local X0, X1, Z0, Z1, Y0, Y1 = -135, -56, 66, 210, 21, 115 -- (top 103 → 115 with the screen, user 2026-10-27) -- (on the raised store roof, H 21: user 2026-10-27)
	box("TowerBody", X0, Y0, Z0, X1, Y1, Z1, GRANITE, { parent = L, material = Enum.Material.Slate })
	box("TowerCrown", X0 - 0.4, Y1, Z0 - 0.4, X1 + 0.4, Y1 + 2, Z1 + 0.4, Color3.fromRGB(60, 58, 58), { parent = L, material = Enum.Material.Slate })
	box("TowerTopGlass", X0 + 0.2, Y1 - 8, Z0 - 0.15, X1 - 0.2, Y1 - 1, Z0 + 0.1, Color3.fromRGB(70, 90, 110), { parent = L, material = Enum.Material.Glass })
	-- screen zone (y 46..86, user 2026-10-25: up at the top of the tower, well
	-- clear of the store): the slits run below it
	local SY0, SY1 = 42, 98 -- (12 higher, a gap of 21 above the store roof, user 2026-10-27) -- (down to half of the wall below, user 2026-10-25)
	local function slits(axis, fixed, a0, a1, outward, spans)
		for a = a0 + 3, a1 - 3, 3.5 do
			for _, span in ipairs(spans) do
				if axis == "x" then
					box("TowerSlit", a - 0.4, span[1], fixed - outward * 0.05, a + 0.4, span[2], fixed + outward * 0.1, SLIT, { parent = L, material = Enum.Material.Glass, nocol = true })
				else
					box("TowerSlit", fixed - outward * 0.05, span[1], a - 0.4, fixed + outward * 0.1, span[2], a + 0.4, SLIT, { parent = L, material = Enum.Material.Glass, nocol = true })
				end
			end
		end
	end
	local AROUND = { { Y0 + 2, SY0 - 1.5 } } -- the screen sides: below the screen
	slits("x", Z0, X0, X1, -1, AROUND) -- north
	slits("x", Z1, X0, X1, 1, { { Y0 + 2, Y1 - 10 } }) -- south (no screen)
	slits("z", X0, Z0, Z1, -1, AROUND) -- west
	slits("z", X1, Z0, Z1, 1, AROUND) -- east
	-- the screen: panels in the order the cards run
	local R = 6 -- radius of the rounded corners
	local OUT = 0.9 -- how far the screen stands off the wall
	local BACK = Z1 - 2 -- the side screens end 2 studs before the back
	local h = SY1 - SY0
	local yc = (SY0 + SY1) / 2
	local start = 0
	local function panel(center: Vector3, outward: Vector3, width: number)
		local p = part("LEDPanel", Vector3.new(width + 0.02, h, 0.3), CFrame.lookAt(center, center + outward), Color3.fromRGB(8, 8, 14), { parent = L, material = Enum.Material.SmoothPlastic })
		p:SetAttribute("Board", "todayBand")
		p:SetAttribute("BandStart", start)
		CS:AddTag(p, "RankBoard")
		-- black frame lines along the top and bottom edge
		for _, dy in ipairs({ h / 2 + 0.3, -(h / 2 + 0.3) }) do
			local c = center + Vector3.new(0, dy, 0)
			part("LEDFrame", Vector3.new(width + 0.02, 0.6, 0.6), CFrame.lookAt(c, c + outward), FR, { parent = L })
		end
		start += width
	end
	-- a rounded corner from angle a0 to a1 (degrees; outward = (cos a, 0, -sin a): 0 east, 90 north, 180 west)
	local function corner(cx, cz, a0, a1)
		local N = 3
		local step = (a1 - a0) / N
		for i = 0, N - 1 do
			local a = math.rad(a0 + step * (i + 0.5))
			local outward = Vector3.new(math.cos(a), 0, -math.sin(a))
			local width = 2 * R * math.sin(math.rad(math.abs(step) / 2))
			panel(Vector3.new(cx, yc, cz) + outward * R * math.cos(math.rad(math.abs(step) / 2)), outward, width)
		end
		vcyl("LEDBackCorner", Vector3.new(cx, SY0 - 0.6, cz), 2 * R - 0.3, h + 1.2, FR, { parent = L })
	end
	-- east side, from the back toward the crossing
	panel(Vector3.new(X1 + OUT, yc, (BACK + Z0 + R) / 2), Vector3.new(1, 0, 0), BACK - (Z0 + R))
	corner(X1 + OUT - R, Z0 - OUT + R, 0, 90)
	-- north side, east → west
	panel(Vector3.new((X1 - R + X0 + R) / 2, yc, Z0 - OUT), Vector3.new(0, 0, -1), (X1 - R) - (X0 + R))
	corner(X0 - OUT + R, Z0 - OUT + R, 90, 180)
	-- west side (beach road), toward the back
	panel(Vector3.new(X0 - OUT, yc, (Z0 + R + BACK) / 2), Vector3.new(-1, 0, 0), BACK - (Z0 + R))
	-- the screen's back boxes filling the gap to the wall
	box("LEDBack", X0 + R, SY0 - 0.6, Z0 - OUT + 0.15, X1 - R, SY1 + 0.6, Z0, FR, { parent = L })
	box("LEDBack", X1, SY0 - 0.6, Z0 + R, X1 + OUT - 0.15, SY1 + 0.6, BACK, FR, { parent = L })
	box("LEDBack", X0 - OUT + 0.15, SY0 - 0.6, Z0 + R, X0, SY1 + 0.6, BACK, FR, { parent = L })
end
do -- three ranking boards in the pocket park in front of the park gate (user
	-- 2026-10-25): 후원 / 큰손 / 플레이 시간, on the open paving on the east side,
	-- facing the plaza
	local B = Instance.new("Model")
	B.Name = "RankingBoards"
	B.Parent = T
	local POST = Color3.fromRGB(120, 88, 62) -- (the deck wood of the park steps, user 2026-10-27)
	-- (moved in a row up from subway exit 3 toward the park, readable from both
	-- sides, user 2026-10-26; the club bus stop took their old place)
	local X = -68 -- (on the paving by the sunken plaza's rim, user 2026-10-27)
	for _, spec in ipairs({ { "support", -97 }, { "spend", -83.5 }, { "playtime", -70 } }) do
		local z = spec[2]
		box("BoardPost", X - 0.4, 0, z - 5.6, X + 0.4, 12.4, z - 4.8, POST, { parent = B, material = Enum.Material.WoodPlanks })
		box("BoardPost", X - 0.4, 0, z + 4.8, X + 0.4, 12.4, z + 5.6, POST, { parent = B, material = Enum.Material.WoodPlanks })
		box("BoardFrame", X - 0.6, 2.6, z - 5.8, X + 0.6, 12.6, z + 5.8, POST, { parent = B, material = Enum.Material.WoodPlanks })
		for _, side in ipairs({ { -1, "Left" }, { 1, "Right" } }) do
			local x0 = X + side[1] * 0.6
			local s = box("BoardScreen", math.min(x0, x0 + side[1] * 0.15), 2.9, z - 5.5, math.max(x0, x0 + side[1] * 0.15), 12.3, z + 5.5, Color3.fromRGB(14, 16, 24), { parent = B, material = Enum.Material.SmoothPlastic })
			s:SetAttribute("Board", spec[1]) s:SetAttribute("Face", side[2]) CS:AddTag(s, "RankBoard")
		end
	end
end

-- (layout v8: the alley between the east towers and the construction site east of
-- 오후네컷 are gone, the bigger 오후네컷 building stands there)

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
	-- (layout v8, user map 2026-10-27: "옆에 노래방 건물 삭제하고 거기까지 사이즈 확장한
	-- 후 남쪽으로도 확장") x0 -126 → -144 over the 노래방 tower's place, z1 86 → 192
	-- over the old Glasshouse cafe: world x -148..-56, z 66..210
	-- (user 2026-10-27, after v8: the beach-road sidewalk got narrow) x0 -144 →
	-- -131 (world -135): the sidewalk from the road edge (-158) is 23 wide like
	-- the big roads' (24 → 47); the store is that much narrower, as high as before
	local x0, z0, x1, z1, H = -131, 48, -52, 192, 21 -- (14 → 21: as high as the club 1F, user 2026-10-27)
	local RISE = H - 14 -- the front, signs and stripes were drawn for H 14; they move up with the ceiling
	local OH24_SHIFT = Vector3.new(-4, 0, 18) -- (applied to the finished model below)
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
			-- the tile repeats along the row (D-322), so rows of any length keep the pack shapes
			local d = Instance.new("Texture")
			d.Name = "RowImage"
			d.Texture = img
			d.Face = Enum.NormalId.Front
			d.StudsPerTileU = catalog.ROW_TILE_STUDS or 8
			d.StudsPerTileV = face.Size.Y
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
	-- (the sidewalk strip in front of it is laid after the move, at the end of this block)
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
		l.Range, l.Brightness, l.Angle = 16 + RISE, 0.9, 120
		l.Parent = led
	end
	-- teal stripe band on the back wall with the slogan
	box("StripeTeal", x0, 11.6 + RISE, z1 - 0.65, x1, 12.4 + RISE, z1 - 0.6, TEAL, opt({ nocol = true }))
	box("StripeLight", x0, 11.1 + RISE, z1 - 0.65, x1, 11.5 + RISE, z1 - 0.6, TEAL2, opt({ nocol = true }))
	do
		local slogan = box("Slogan", -110, 11.65 + RISE, z1 - 0.7, -88, 12.35 + RISE, z1 - 0.66, TEAL, opt({ nocol = true }))
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
		fp("Fascia", -0.3, L + 0.3, 13 + RISE, H + 6, 0, 0.6, Color3.fromRGB(26, 26, 30), opt({ material = Enum.Material.Slate }))
		-- logo plaque in the middle, light bars either side
		local logo = fp("Logo", L / 2 - 7, L / 2 + 7, 14.6 + RISE, 18.8 + RISE, 0.6, 0.75, Color3.fromRGB(26, 26, 30), opt({ nocol = true }))
		local g = gui(logo, Enum.NormalId.Front, 30, 400)
		g.LightInfluence = 0
		g.Brightness = 1.4
		text(g, '<font color="#FFFFFF">OH</font><font color="#1EC8F0">24</font>', Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		local barW = math.min(14, L / 2 - 9)
		for _, b in ipairs({ { L - 1.6 - barW, L - 1.6, "Lifestyle Platform", true }, { 1.6, 1.6 + barW, branch, false } }) do
			-- each bar runs on to the logo (user 2026-10-23); the text stays where it was
			local u0, u1 = b[1], b[2]
			if b[4] then u0 = L / 2 + 7.3 else u1 = L / 2 - 7.3 end
			local k = barW / (u1 - u0)
			local bar = fp("LightBar", u0, u1, 16 + RISE, 17.6 + RISE, 0.6, 0.8, CYAN, opt({ nocol = true }))
			local bg = gui(bar, Enum.NormalId.Front, 30, 200)
			bg.LightInfluence = 0
			local bgf = Instance.new("Frame") bgf.Size = UDim2.fromScale(1, 1) bgf.BackgroundColor3 = CYAN bgf.BorderSizePixel = 0 bgf.Parent = bg
			local l = text(bg, b[3], Color3.fromRGB(10, 40, 60), Enum.Font.GothamMedium)
			l.TextXAlignment = if b[4] then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
			l.Size = UDim2.fromScale(0.94 * k, 0.7)
			l.Position = UDim2.fromScale(if b[4] then 0.03 * k else 1 - 0.97 * k, 0.15)
			fp("LightBarBase", u0, u1, 15.4 + RISE, 15.8 + RISE, 0.6, 0.8, Color3.fromRGB(245, 245, 245), opt({ nocol = true }))
		end
		-- awning sloping out, small text on its edge
		local a = p0 + along * (L / 2) + out * 0.6 + Vector3.new(0, 13.4 + RISE, 0)
		local bpt = p0 + along * (L / 2) + out * 3.4 + Vector3.new(0, 12.4 + RISE, 0)
		local slope = (bpt - a).Unit
		local nrm = along:Cross(slope)
		if nrm.Y < 0 then nrm = -nrm end
		part("Awning", Vector3.new(L - 2, 0.2, (bpt - a).Magnitude), CFrame.fromMatrix((a + bpt) / 2, along, nrm), Color3.fromRGB(58, 40, 36), opt({ material = Enum.Material.Fabric, nocol = true }))
		local valance = fp("AwningEdge", 1, L - 1, 11.8 + RISE, 12.5 + RISE, 3.3, 3.5, Color3.fromRGB(58, 40, 36), opt({ material = Enum.Material.Fabric, nocol = true }))
		local vl = text(gui(valance, Enum.NormalId.Front, 30, 120), "Lifestyle Platform   OH24", Color3.fromRGB(230, 230, 230), Enum.Font.GothamMedium)
		vl.TextXAlignment = Enum.TextXAlignment.Left
		vl.Size = UDim2.fromScale(0.97, 0.6)
		vl.Position = UDim2.fromScale(0.02, 0.2)
		-- glass with slim mullions (a gap for the door)
		local DOOR = 8 local DOOR_H = 11.4 * H / 14 -- (doors grow with the ceiling, 11.4 → 17.1: tall avatars, user 2026-10-27)
		local runs = if doorU then { { 1.6, doorU - DOOR / 2 - 0.4 }, { doorU + DOOR / 2 + 0.4, L - 1.6 } } else { { 1.6, L - 1.6 } }
		for _, r in ipairs(runs) do
			fp("FrontGlass", r[1], r[2], CURB + 0.6, 12.8 + RISE, 0, 0.2, Color3.fromRGB(215, 230, 235), opt({ material = Enum.Material.Glass, transparency = 0.6 }))
			fp("Kickplate", r[1], r[2], CURB, CURB + 0.6, 0, 0.25, Color3.fromRGB(150, 150, 155), opt({ material = Enum.Material.Metal }))
			local n = math.max(1, math.floor((r[2] - r[1]) / 7))
			for k = 0, n do
				local u = r[1] + (r[2] - r[1]) * k / n
				fp("Mullion", u - 0.12, u + 0.12, CURB, 12.8 + RISE, 0, 0.3, Color3.fromRGB(70, 70, 75), opt({ material = Enum.Material.Metal }))
			end
			local mu = (r[1] + r[2]) / 2
			local mark = fp("GlassMark", mu - 1.2, mu + 1.2, 10.4 + RISE, 11 + RISE, 0.21, 0.22, Color3.new(1, 1, 1), opt({ nocol = true, transparency = 1 }))
			text(gui(mark, Enum.NormalId.Front, 40, 80), '<font color="#FFFFFF">OH</font><font color="#1EC8F0">24</font>', Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		end
		fp("GlassHead", 1.6, L - 1.6, 12.8 + RISE, 13 + RISE, 0, 0.3, Color3.fromRGB(70, 70, 75), opt({ material = Enum.Material.Metal }))
		if doorU then
			fp("DoorHead", doorU - DOOR / 2 - 0.4, doorU + DOOR / 2 + 0.4, DOOR_H, 12.8 + RISE, 0, 0.3, Color3.fromRGB(70, 70, 75), opt({ material = Enum.Material.Metal }))
			local door = Instance.new("Model")
			door.Name = "AutoDoor"
			door:SetAttribute("Range", 9)
			for _, s2 in ipairs({ -1, 1 }) do
				local panel = fp("DoorPanel", doorU, doorU + s2 * DOOR / 2, CURB, DOOR_H, 0.05, 0.2, Color3.fromRGB(215, 230, 235), { parent = door, material = Enum.Material.Glass, transparency = 0.55 })
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
	-- (user 2026-10-27) a second door in the middle of the long east front, between the two window bars
	storeFront(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), Vector3.new(1, 0, 0), 119 - z0, "남부대로점") -- east (south road)

	---------------------------------------------------------------- window bars inside the glass
	local function windowBar(a: Vector3, b: Vector3, inward: Vector3)
		local d = (b - a)
		local len = d.Magnitude
		local dir = d.Unit
		local c = (a + b) / 2 + inward * 0.9
		local bar = part("WindowBar", Vector3.new(len, 0.2, 1.6), CFrame.fromMatrix(Vector3.new(c.X, CURB + 3.5, c.Z), dir, Vector3.yAxis), Color3.fromRGB(245, 245, 245), o)
		CS:AddTag(bar, "SnackTable") -- (a table for shared plates, SnackService)
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
	windowBar(Vector3.new(x1 - 0.3, 0, 70), Vector3.new(x1 - 0.3, 0, 112), Vector3.new(-1, 0, 0)) -- east, by the shelves
	windowBar(Vector3.new(x1 - 0.3, 0, 126), Vector3.new(x1 - 0.3, 0, z1 - 6), Vector3.new(-1, 0, 0)) -- east, along the eating corner

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
	-- (layout v8, the bigger store) two rows of five, 14 apart: the north row by
	-- the doors (z 60..76), the second behind it (z 92..108)
	local gi = 0
	for _, zb in ipairs({ 60, 92 }) do
		for _, gx in ipairs({ -112, -100, -88, -76, -64 }) do
			gi += 1
			local c = GCATS[(gi - 1) % #GCATS + 1]
			shelfUnit("Gondola" .. gi .. "W", CFrame.lookAt(Vector3.new(gx - 1.4, CURB, zb + 16), Vector3.new(gx - 10, CURB, zb + 16)), 16, 4, 6.2, 1.4, c[1], c[3])
			shelfUnit("Gondola" .. gi .. "E", CFrame.lookAt(Vector3.new(gx + 1.4, CURB, zb), Vector3.new(gx + 10, CURB, zb)), 16, 4, 6.2, 1.4, c[2], c[4])
			shelfUnit("EndCap" .. gi, CFrame.lookAt(Vector3.new(gx - 1.4, CURB, zb - 1.2), Vector3.new(gx - 1.4, CURB, zb - 10)), 2.8, 5, 6.6, 1.2, { "snack_bag" }, nil)
		end
	end
	-- EATING CORNER in the south part (z 122..180): white tables for four
	-- (tagged SnackTable, so bought snacks and 라면 can be shared on them) with
	-- round stools, a few tall plants; the drinks and chilled cases on the back wall
	do
		local TOPC, LEG = Color3.fromRGB(248, 248, 246), Color3.fromRGB(190, 190, 195)
		for _, tz in ipairs({ 128, 144, 160, 176 }) do
			for _, tx in ipairs({ -120, -106, -92, -78 }) do
				local t = box("EatTable", tx - 2.2, CURB + 3, tz - 1.6, tx + 2.2, CURB + 3.2, tz + 1.6, TOPC, o)
				CS:AddTag(t, "SnackTable")
				box("EatTableLeg", tx - 0.2, CURB, tz - 0.2, tx + 0.2, CURB + 3, tz + 0.2, LEG, opt({ material = Enum.Material.Metal }))
				for _, d in ipairs({ { -3.4, 0 }, { 3.4, 0 } }) do
					for _, dz in ipairs({ -0.9, 0.9 }) do
						local p = Vector3.new(tx + d[1], CURB, tz + dz)
						vcyl("StoolLeg", p, 0.3, 1.9, LEG, opt({ material = Enum.Material.Metal }))
						seat("EatStool", CFrame.lookAt(Vector3.new(p.X, CURB + 2.05, p.Z), Vector3.new(tx, CURB + 2.05, p.Z)), Vector3.new(1.4, 0.3, 1.4), Color3.fromRGB(0, 160, 160), S)
					end
				end
			end
		end
		local sign = box("EatSign", -112, 12 + RISE, 118.9, -96, 14 + RISE, 119.1, TEAL, opt({ nocol = true }))
		text(gui(sign, Enum.NormalId.Back, 30, 120), "취식 공간 · Eat-in", Color3.new(1, 1, 1), Enum.Font.GothamBold)
		local hang = box("EatSignHanger", -104.1, 14 + RISE, 118.95, -103.9, H - 0.3, 119.05, LEG, opt({ nocol = true }))
		local _ = hang
	end

	---------------------------------------------------------------- counter on the west wall (user 2026-10-23); staff between it and the wall
	do
		local cx0, cx1, cz0, cz1 = x0 + 7, x0 + 10.5, 51, 64 -- cx0 = staff side (west), cx1 = customer side (east)
		local TEALTOP = Color3.fromRGB(0, 150, 150)
		box("CounterBody", cx0, CURB, cz0, cx1, CURB + 3.4, cz1, Color3.fromRGB(245, 245, 245), o)
		local counterTop = box("CounterTop", cx0 - 0.2, CURB + 3.4, cz0 - 0.2, cx1 + 0.3, CURB + 3.7, cz1 + 0.2, TEALTOP, o)
		-- the till: "계산하기" opens the snack menu (SnackService, D-317)
		counterTop:SetAttribute("Shop", "OH24")
		CS:AddTag(counterTop, "SnackShop")
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
	-- (user 2026-10-25) the whole store moves 4 west, close to the 노래방 tower
	-- (1.5 apart), and 18 south over the old lane to the seafront, up to the
	-- Glasshouse cafe's terrace (z 104 / 105): the sidewalks in front of it and
	-- on its east side are wider, subway exit 4 stands in front; the ground
	-- round it is paved (the lane's place west and south of it too)
	S:PivotTo(S:GetPivot() + OH24_SHIFT)
	local sx0, sz0, sx1, sz1 = x0 + OH24_SHIFT.X, z0 + OH24_SHIFT.Z, x1 + OH24_SHIFT.X, z1 + OH24_SHIFT.Z
	walk(sx0, WIDE, sx1, sz0) -- in front
	walk(sx1, WIDE, -47, sz1) -- east side, up to the south road's sidewalk
	walk(-150, WIDE, sx0, sz1 + 4) -- west: with the beach road's sidewalk (-158..-150) 23 wide up to the store
	walk(-150, sz1, -47, 214) -- south, up to the shop block (the old Glasshouse cafe's place)
end

-- (the sunset photo frame went with the pier, user 2026-10-24)

------------------------------------------------------- play area boundary + backdrop (D-109)
-- The user drew the walkable area on the v7c map (2026-10-23, red line):
-- invisible walls along it keep players inside. Outside, only what can be
-- seen is built: a tiled stone wall (기와 돌담) around the hanok village,
-- fake shop buildings with stacked signs elsewhere, the beach going on.
do
	local B = Instance.new("Folder")
	B.Name = "MapBoundary"
	B.Parent = T
	-- where the 광화문 south-west wall curve crosses z 299 (the boundary's south edge)
	local swX = GATE_E2.X
	for k = 1, 200 do
		local p = bezier(WALL_S, k / 200)
		if p.Z >= 299 then swX = p.X break end
	end
	-- polygon (x, z), clockwise from the north-west corner in the sea
	local P = {
		-- 2026-10-23 (2): the beach road is closed further south (z -300)
		-- (layout v8, user map 2026-10-27): north edge on the big 국밥집's back
		-- (z -380), east edge past the bigger 오후네컷 (x 194), south-west round
		-- the bigger OH24 store (z 214) and down past the moved beach cafe (z 380),
		-- west out in the sea beyond it (x -380)
		-- (user map 2026-10-27, red line "플레이어가 돌아다닐 수 있는 공간"): the sea
		-- out to x -415, the beach up to z -385, round the amusement park's walls,
		-- the north road up to z -455 by the shop block N, round the smaller 국밥집,
		-- the east edge at x 194 to the east road, then out to x 277 over the
		-- 광화문 yard and the (empty) village, the south edge at z 387
		{ -415, -385 }, { -148, -385 }, { -148, -229 }, { -51.3, -229 }, { -51.3, -455 }, { 47, -455 }, { 47, -385 },
		{ 160, -385 }, { 160, -316 }, { 194, -316 }, { 194, -50 }, { 277, -50 }, { 277, 387 }, { -415, 387 },	}
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
	local function hanokWall(a: Vector3, b: Vector3, out: Vector3)
		local W = Instance.new("Model")
		W.Name = "HanokWallExtension"
		W.Parent = T
		palaceWall(a, b, W, out) -- the same palace wall as the village (user photos)
	end
	-- (user 2026-10-27, red line) from the 광화문's ends the wall leaves in
	-- gentle curves: north-east to the north wall line (z 49) at x 300, then
	-- straight on east; south-west down to the 돌담길's straight run toward
	-- (185, 700). A curve is short straight pieces of the same wall, each a
	-- hair longer so the joints close; `outSign` picks the street side
	local function curveWall(c: { Vector3 }, outPick: (Vector3) -> boolean, pathSide: boolean)
		local N = 14
		local PAVE = Color3.fromRGB(226, 216, 190)
		local prev = bezier(c, 0)
		for k = 1, N do
			local p = bezier(c, k / N)
			local d = (p - prev).Unit
			local out = Vector3.yAxis:Cross(d)
			if not outPick(out) then out = -out end
			hanokWall(prev - d * 0.6, p + d * 0.6, out)
			if pathSide then -- the stone path along its street side
				local mid = (prev + p) / 2 + out * 4.8
				part("DoldamPath", Vector3.new(8, 0.3, (p - prev).Magnitude + 1.2), CFrame.lookAt(Vector3.new(mid.X, 0.15, mid.Z), Vector3.new(mid.X, 0.15, mid.Z) + d), PAVE, { material = Enum.Material.Slate })
			end
			prev = p
		end
	end
	curveWall(WALL_N, function(o) return o.Z < 0 end, false)
	hanokWall(WALL_N[4], Vector3.new(700, 0, 49), Vector3.new(0, 0, -1))
	-- the strip between the sidewalk edge and the wall foot was empty (user): paved
	box("Sidewalk", 96.4, 0, WIDE - 0.05, 700, CURB - 0.01, 48.2, WALK, { parent = T, material = Enum.Material.Brick })
	-- south-west: the 돌담길 (user photo) along the south road, a stone path on its street side
	curveWall(WALL_S, function(o) return o.X < 0 end, false) -- (no path: the yard paving reaches it)
	hanokWall(WALL_S[4], WALL_S_END, Vector3.new(-1, 0, 0))
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
	-- (user 2026-10-24, performance) all the signs of one building are drawn on
	-- one invisible board in front of its face (one part + one SurfaceGui per
	-- building instead of one per sign: 1,010 → about 100). board = { part,
	-- width, top } in the building's local frame; sx, y = the sign's centre
	local SIGN_PPS = 20
	local function signBoard(parent, cf, width, y0, y1, z)
		local p = part("ShopSignBoard", Vector3.new(width, y1 - y0, 0.05), cf * CFrame.new(0, (y0 + y1) / 2, z), Color3.new(1, 1, 1), { parent = parent, nocol = true, transparency = 1 })
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = SIGN_PPS
		g.LightInfluence = 0.4
		g.Parent = p
		return { gui = g, width = width, top = y1 }
	end
	local function sign(board, sx, y, w, h, text, bg)
		-- the Front face is seen from local -Z: the viewer's right is local -X
		local f = Instance.new("Frame")
		f.Name = "ShopSign"
		f.Position = UDim2.fromOffset((board.width / 2 - (sx + w / 2)) * SIGN_PPS, (board.top - (y + h / 2)) * SIGN_PPS)
		f.Size = UDim2.fromOffset(w * SIGN_PPS, h * SIGN_PPS)
		f.BackgroundColor3 = bg
		f.BorderSizePixel = 0
		f.Parent = board.gui
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		local dark = bg.R + bg.G + bg.B < 1.5
		t.TextColor3 = if dark then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(30, 40, 110)
		t.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8) pad.PaddingRight = UDim.new(0, 8) pad.PaddingTop = UDim.new(0, 3) pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = t
		t.Parent = f
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
		local board = signBoard(M, cf, width, 8.6, height - 4, -depth / 2 - 0.8)
		for k = 0, 1 do
			local sx = (k - 0.5) * width / 2
			local s = SHOPS[((shopN * 3 + k) % #SHOPS) + 1]
			sign(board, sx, 9.6, width / 2 - 2.5, 1.8, s[1], s[2])
			part("Awning", Vector3.new(width / 2 - 3, 0.3, 2.2), cf * CFrame.new(sx, 8.2, -depth / 2 - 1.3) * CFrame.Angles(math.rad(-12), 0, 0), if k == 0 then Color3.fromRGB(200, 40, 50) else Color3.fromRGB(60, 60, 66), { parent = M, nocol = true })
		end
		-- upper floors: a sign band per floor, two signs side by side
		local floor = 1
		for y = 13, height - 6, 7 do
			for k = 0, 1 do
				local s = SHOPS[((shopN * 5 + floor * 2 + k) % #SHOPS) + 1]
				local sx = (k - 0.5) * (width / 2 - 1)
				sign(board, sx, y, width / 2 - 4, 2.4, s[1] .. (if k == 0 then string.format(" %dF", floor + 1) else ""), s[2])
			end
			floor += 1
		end
		part("Roof", Vector3.new(width + 1, 1, depth + 1), cf * CFrame.new(0, height + 0.5, 0), Color3.fromRGB(90, 90, 95), { parent = M })
	end
	local hgt = { 44, 58, 38, 66, 50, 42, 60, 48 }
	local i2 = 0
	-- LONG SHOP BLOCKS (layout v8, user map 2026-10-27: "가짜 건물 블록 하나로 길게
	-- 배치 ... 이미지 간판으로 처리"): one long block each, its street faces
	-- covered with building-front images (tools/art/shop_facades.ps1: stacked
	-- shop signs on every floor, a lit shop front below), one image every ~40.
	-- They replace the separate fake buildings along the club side, the north
	-- road's west side, both sides of the south lot and the towers east of 오후네컷.
	-- (user 2026-10-27: their own pictures for slots 4 and 7, docs/04_ART/facades/facade_4_user.png / facade_7_user.png)
	local FACADES = { 119555605786938, 100153499316339, 131791880332218, 72400340486961, 76461462810783, 86941239410625, 133905773347734, 134862143501130 }
	local facadeN = 0
	local function shopBlock(name, x0, z0, x1, z1, h, faces)
		local M = Instance.new("Model")
		M.Name = "BG_ShopBlock_" .. name .. "(진입불가)"
		M.Parent = T
		box("Body", x0, 0, z0, x1, h, z1, Color3.fromRGB(150, 148, 146), { parent = M, material = Enum.Material.Concrete })
		box("Roof", x0 - 0.5, h, z0 - 0.5, x1 + 0.5, h + 1.5, z1 + 0.5, Color3.fromRGB(90, 90, 95), { parent = M })
		for _, f in ipairs(faces) do
			-- the face runs from a to b (the viewer's left to right), out = its normal
			local a, b, out
			if f == "W" then a, b, out = Vector3.new(x0, 0, z1), Vector3.new(x0, 0, z0), Vector3.new(-1, 0, 0)
			elseif f == "E" then a, b, out = Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), Vector3.new(1, 0, 0)
			elseif f == "N" then a, b, out = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), Vector3.new(0, 0, -1)
			else a, b, out = Vector3.new(x1, 0, z1), Vector3.new(x0, 0, z1), Vector3.new(0, 0, 1) end
			local len = (b - a).Magnitude
			local n = math.max(1, math.floor(len / 40 + 0.5))
			local w = len / n
			local dir = (b - a).Unit
			for k = 0, n - 1 do
				facadeN += 1
				local c = a + dir * (w * (k + 0.5)) + out * 0.08 + Vector3.new(0, h / 2, 0)
				local p = part("FacadePanel", Vector3.new(w - 0.1, h, 0.05), CFrame.lookAt(c, c + out), Color3.fromRGB(150, 148, 146), { parent = M, nocol = true })
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Transparency = 1
				local d = Instance.new("Decal")
				d.Face = Enum.NormalId.Front
				d.Texture = "rbxassetid://" .. FACADES[((facadeN * 3) % #FACADES) + 1]
				d.Parent = p
			end
		end
	end
	shopBlock("N", 48, -1000, 130, -385, 60, { "W", "S" }) -- north of the 국밥집, on the club line
	shopBlock("E", 195, -100, 310, -48, 50, { "S", "W" }) -- east of 오후네컷, along the east road
	shopBlock("S", -150, 215, -56, 985, 60, { "E", "W", "N" }) -- south of OH24, between the south road and the beach road
	for xx = 330, 985, 35 do -- east road, north side (front +z at z -47)
		i2 += 1
		fakeBuilding(Vector3.new(xx, 0, -58), 34, 22, hgt[(i2 + 2) % #hgt + 1], Vector3.new(0, 0, 1))
	end
	-- the empty land south of the hanok village, seen over its wall from the
	-- street (user 2026-10-26): a row facing the village (front -z at z 265)
	-- (gone 2026-10-27: the turned 광화문 reaches there and the village is emptied)

	-- the beach goes on north and south past the boundary
	local sandY = -BEACH_DROP + 0.6
	box("BeachSand", -268, sandY - 1.2, -1400, -198, sandY, -480, Color3.fromRGB(232, 214, 165), { material = Enum.Material.Sand })
	box("BeachSand", -268, sandY - 1.2, 250, -198, sandY, 800, Color3.fromRGB(232, 214, 165), { material = Enum.Material.Sand })
	-- (north of the park the road is closed: the park wall runs across it, user 2026-10-24)
	for _, seg in ipairs({ { 300, 800 } }) do
		box("Promenade", -198, 0, seg[1], -182, CURB, seg[2], Color3.fromRGB(175, 135, 120), { material = Enum.Material.Brick })
		-- the steps down to the sand go on to the end (user 2026-10-23); by the
		-- beach cafe (layout v8) only the granite edge along its front
		local wood = Color3.fromRGB(120, 88, 62)
		local ea, eb = seg[1], math.min(seg[2], CAFE_Z1)
		if eb > ea then box("BeachStepEdge", -198.7, sandY, ea, -198, CURB + 0.1, eb, Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite }) end
		local sa = math.max(seg[1], CAFE_ZN)
		box("BeachStepEdge", -198.7, sandY, sa, -198, CURB + 0.1, seg[2], Color3.fromRGB(196, 194, 188), { material = Enum.Material.Granite })
		box("BeachStep", -201.2, sandY, sa, -198.7, CURB - 0.6, seg[2], wood, { material = Enum.Material.WoodPlanks })
		box("BeachStep", -203.7, sandY, sa, -201.2, CURB - 1.2, seg[2], wood, { material = Enum.Material.WoodPlanks })
		box("BeachStep", -206.2, sandY, sa, -203.7, CURB - 1.8, seg[2], wood, { material = Enum.Material.WoodPlanks })
		box("SeaRoad", -182, 0, seg[1], -158, 0.12, seg[2], ASPHALT, { material = Enum.Material.Asphalt })
		-- (no red bike lane here: the lane inside is road coloured, user 2026-10-26)
		box("Sidewalk", -158, 0, seg[1], -150, CURB, seg[2], WALK, { material = Enum.Material.Brick })
		paint("EdgeLine", -174.2, seg[1], -173.8, seg[2], WHITE)
		paint("CenterLine", -166.2, seg[1], -165.8, seg[2], YELLOW)

	end
end

------------------------------------------------------- open sea + curved bay (user 2026-10-24)
-- The sea looked like it stopped: the terrain water only streams in near the
-- player, and past it the sand sea floor showed. A wide sea surface (a
-- persistent model, always on every client) runs out to the horizon, lighter
-- by the shore and deeper blue further out. In the north the beach curves round
-- the bay and runs out to a sandy point (user sketches + photos,
-- docs/04_ART/references/beach_curve_ref_*.webp, beach_user_sketch_curve_wall.webp).
do
	local SEA = Instance.new("Model")
	SEA.Name = "OpenSea"
	SEA.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	SEA.Parent = T
	local function flat(name, xa, xb, za, zb, y, color, mat)
		-- parts are at most 2048 long: split big rectangles
		local nx, nz = math.ceil((xb - xa) / 2000), math.ceil((zb - za) / 2000)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local a0, a1 = xa + (xb - xa) * i / nx, xa + (xb - xa) * (i + 1) / nx
				local b0, b1 = za + (zb - za) * j / nz, za + (zb - za) * (j + 1) / nz
				local p = box(name, a0, y - 0.2, b0, a1, y, b1, color, { parent = SEA, nocol = true, material = mat })
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
			end
		end
	end
	-- sea surface just under the terrain water top (-3): bands from the shore out
	local SEA_Y = -7
	-- many narrow bands, so no colour step shows as a line on the water
	-- (user 2026-10-24: the waves were gone) the colour parts sit 4 under the
	-- water top, so near the player the terrain water (and its waves) lies over
	-- them; where the terrain water has not streamed in they carry the sea on
	local EDGES = { -270 }
	for k = 1, 26 do table.insert(EDGES, -270 - 4130 * (k / 26) ^ 1.8) end
	local NEAR, FAR = Color3.fromRGB(70, 184, 198), Color3.fromRGB(24, 86, 142)
	local DOME = nil -- (the Dream Aquarium dome is gone, user 2026-10-24: no hole in the sea any more)
	for i = 1, #EDGES - 1 do
		local xa, xb = EDGES[i + 1], EDGES[i]
		local col = NEAR:Lerp(FAR, ((i - 1) / (#EDGES - 2)) ^ 0.8)
		if DOME and xb > DOME[1] and xa < DOME[3] then
			flat("SeaSurface", xa, xb, -4400, DOME[2], SEA_Y, col)
			flat("SeaSurface", xa, xb, DOME[4], 4400, SEA_Y, col)
			if xa < DOME[1] then flat("SeaSurface", xa, DOME[1], DOME[2], DOME[4], SEA_Y, col) end
			if xb > DOME[3] then flat("SeaSurface", DOME[3], xb, DOME[2], DOME[4], SEA_Y, col) end
		else
			flat("SeaSurface", xa, xb, -4400, 4400, SEA_Y, col)
		end
	end

	-- triangles from two wedges (any 3 points); th = thickness across the face
	local function tri(name, a: Vector3, b: Vector3, c: Vector3, th, color, mat)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		if ac:Cross(ab).Magnitude < 0.01 then return end
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local h = math.abs(ab:Dot(up))
		local o = { parent = SEA, class = "WedgePart", material = mat, nocol = true }
		local d1, d2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
		if d1 > 0.01 then part(name, Vector3.new(th, h, d1), CFrame.fromMatrix((a + b) / 2, right, up, back), color, o) end
		if d2 > 0.01 then part(name, Vector3.new(th, h, d2), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, o) end
	end
	-- the square round the dome, less an octagon just outside the dome (r 44)
	if DOME then
		local cx, cz, half, r = (DOME[1] + DOME[3]) / 2, (DOME[2] + DOME[4]) / 2, (DOME[3] - DOME[1]) / 2, 47.5
		local function sq(a) -- the square's edge along direction a (a multiple of 45 degrees)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local k = half / math.max(math.abs(d.X), math.abs(d.Z))
			return Vector3.new(cx + d.X * k, SEA_Y - 0.1, cz + d.Z * k)
		end
		local colHole = NEAR:Lerp(FAR, 0.02)
		for k = 0, 7 do
			local a0, a1 = math.rad(k * 45), math.rad((k + 1) * 45)
			local v0 = Vector3.new(cx + r * math.cos(a0), SEA_Y - 0.1, cz + r * math.sin(a0))
			local v1 = Vector3.new(cx + r * math.cos(a1), SEA_Y - 0.1, cz + r * math.sin(a1))
			tri("SeaSurface", v0, v1, sq(a1), 0.2, colHole, Enum.Material.SmoothPlastic)
			tri("SeaSurface", v0, sq(a1), sq(a0), 0.2, colHole, Enum.Material.SmoothPlastic)
		end
	end
	local SAND, WET = Color3.fromRGB(232, 214, 165), Color3.fromRGB(205, 186, 140)
	for _, p in ipairs(SEA:GetChildren()) do
		if p.Name == "SeaSurface" then
			p.Reflectance = 0.08
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	-- The north end of the beach: sand only (user 2026-10-24: no trees, lighter),
	-- shaped like the user's white lines. The shore leaves the straight beach on
	-- a circle (C, R) round the bay, runs on west to a sandy point, and the
	-- spit's north shore comes back east to the straight beach far up north.
	local SAND_TOP = -BEACH_DROP + 0.6 -- the beach's sand level
	local C, R = Vector3.new(-560, 0, -330), 292
	local outline: { Vector2 } = {}
	for i = 0, 24 do -- round the bay: 0..90 degrees
		local th = math.rad(90) * i / 24
		table.insert(outline, Vector2.new(C.X + R * math.cos(th), C.Z - R * math.sin(th)))
	end
	local function bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n, skipFirst)
		for i = (if skipFirst then 1 else 0), n do
			local s = i / n
			local q = 1 - s
			table.insert(outline, p0 * q ^ 3 + p1 * 3 * q * q * s + p2 * 3 * q * s * s + p3 * s ^ 3)
		end
	end
	local TIP = Vector2.new(-1080, -700)
	-- south shore on to the point (leaves the circle heading west)
	bez(Vector2.new(-560, -622), Vector2.new(-760, -622), Vector2.new(-960, -660), TIP, 12, true)
	-- round the point and back along the north shore to the sand strip by the wall
	-- (the outline then closes down x -268 to its start)
	bez(TIP, Vector2.new(-1000, -760), Vector2.new(-520, -820), Vector2.new(-268, -1400), 16, true)
	-- ear clipping wants the outline counter-clockwise in (x, z)
	local function area(p)
		local s = 0
		for i = 1, #p do
			local a, b = p[i], p[i % #p + 1]
			s += a.X * b.Y - b.X * a.Y
		end
		return s / 2
	end
	if area(outline) < 0 then
		local r = {}
		for i = #outline, 1, -1 do table.insert(r, outline[i]) end
		outline = r
	end
	local function cross(o: Vector2, a: Vector2, b: Vector2) return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X) end
	local function inTri(p, a, b, c)
		return cross(a, b, p) >= 0 and cross(b, c, p) >= 0 and cross(c, a, p) >= 0
	end
	local function v3(p: Vector2, y) return Vector3.new(p.X, y, p.Y) end
	local so = { parent = SEA, nocol = true, material = Enum.Material.Sand }
	do -- ear clipping
		local idx = {}
		for i = 1, #outline do idx[i] = i end
		local guard = 0
		while #idx > 3 and guard < 5000 do
			guard += 1
			local found = false
			for k = 1, #idx do
				local ia, ib, ic = idx[(k - 2) % #idx + 1], idx[k], idx[k % #idx + 1]
				local a, b, c = outline[ia], outline[ib], outline[ic]
				if cross(a, b, c) > 0 then
					local ear = true
					for _, j in ipairs(idx) do
						if j ~= ia and j ~= ib and j ~= ic and inTri(outline[j], a, b, c) then
							ear = false
							break
						end
					end
					if ear then
						wedgeTri("BaySand", v3(a, SAND_TOP - 0.8), v3(b, SAND_TOP - 0.8), v3(c, SAND_TOP - 0.8), 1.6, SAND, so)
						table.remove(idx, k)
						found = true
						break
					end
				end
			end
			if not found then break end
		end
		if #idx == 3 then
			wedgeTri("BaySand", v3(outline[idx[1]], SAND_TOP - 0.8), v3(outline[idx[2]], SAND_TOP - 0.8), v3(outline[idx[3]], SAND_TOP - 0.8), 1.6, SAND, so)
		end
	end
	-- wet sand sloping under the water (42 out, down to -16) along every shore
	-- edge (not the edge on x -268, which meets the beach sand)
	local SL = 42
	local n = #outline
	local normals = {}
	for i = 1, n do
		local a, b = outline[i], outline[i % n + 1]
		local d = (b - a).Unit
		normals[i] = Vector2.new(d.Y, -d.X) -- right of a counter-clockwise edge = outward
	end
	local function shoreEdge(i)
		local a, b = outline[i], outline[i % n + 1]
		return not (math.abs(a.X + 268) < 0.5 and math.abs(b.X + 268) < 0.5)
	end
	for i = 1, n do
		if shoreEdge(i) then
			local a, b, nn = outline[i], outline[i % n + 1], normals[i]
			wedgeTri("BayShore", v3(a, SAND_TOP - 0.5), v3(b, SAND_TOP - 0.5), v3(b + nn * SL, -16.5), 1, WET, so)
			wedgeTri("BayShore", v3(a, SAND_TOP - 0.5), v3(b + nn * SL, -16.5), v3(a + nn * SL, -16.5), 1, WET, so)
			-- fill the gap at an outside corner with the next edge
			local j = i % n + 1
			if shoreEdge(j) then
				local n2 = normals[j]
				if nn.X * n2.Y - nn.Y * n2.X < 0 then
					wedgeTri("BayShore", v3(b, SAND_TOP - 0.5), v3(b + nn * SL, -16.5), v3(b + n2 * SL, -16.5), 1, WET, so)
				end
			end
		end
	end
end
------------------------------------------------------- beach furniture (광안리 photos, user 2026-10-23)
do
	local SAND_Y = CURB - BEACH_DROP
	local beachZone = root:FindFirstChild("04_Beach_Aquarium")
	-- (straw parasol spots tried and removed: the user keeps the original
	-- striped parasol / chair groups, 2026-10-23)
	-- beach signs (광안리 photos): built by tools/graybox/build_beach_signs.lua
	-- (guide map board + surfboard rules board with drawn faces, D-321; LAYOUT.md step 3-3)
	local _ = SAND_Y
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
	local GF = F + 21 -- top of the ground floor / underside of the fascia (high ceiling, user; 19 → 21 like the club 1F, user 2026-10-27)
	local SC = (GF - F) / 19 -- the entrance frame, door and glass bays were drawn for a 19 floor: they grow with it (user 2026-10-27)
	-- (east face 109.5 → 115.5, user 2026-10-26: wider booths so the wider photo
	-- view shows no side walls; the 소품샵 site moved east to make room)
	-- (layout v8, user map 2026-10-27: "옆에 공사 중이었던 곳 삭제하고 거기까지 건물
	-- 확장하고 기존 건물 비율에 맞춰 북쪽으로도 커져도 됨") east face 115.5 → 180 over
	-- the construction site, north face -98.5 → -115 (the club moved 24 north).
	-- The three booths keep their size and place (x FX..BW1, z BNIN..S0); a
	-- partition at BW1 closes them off from the new east hall (its own door on
	-- the east road), the lobby reaches north to the new north wall
	local W0, W1, N0, S0 = 48.5, 180, -115, -47.5 -- outer faces: west, east, north, south
	local BW1, BNIN = 115.5, -95.8 -- the booths' east wall (the old east face) and their north end
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
	local FLOOR_COL = Color3.fromRGB(246, 246, 244) -- white tiles (a grey diagonal grid is drawn on top)
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
	local WOOD = Color3.fromRGB(120, 88, 62) -- (one deck wood for the whole map, user 2026-10-27: was 150, 112, 78)
	local DECK = 2.6
	local woodOpt = opt({ material = Enum.Material.WoodPlanks })
	box("Deck", W0 - DECK, 0, N0, W0, F, S0 - CH + 1.1, WOOD, woodOpt) -- ends on the building line (user)
	box("Deck", W0 + CH - 1.1, 0, S0, W1 - 1, F, S0 + DECK, WOOD, woodOpt)
	cutPart("Deck", CH * math.sqrt(2) + 2.2, 0, F + 0.02, DECK + 0.5, (DECK - 0.5) / 2, WOOD, woodOpt) -- up to the door glass, none inside (user)
	-- pavement in the rest of the corner (named Sidewalk: street_dress gives it
	-- the paver texture), a hair lower than the sidewalks it overlaps
	cutPart("Sidewalk", CH * math.sqrt(2) + 12, 0, CURB - 0.02, 7.4, DECK + 3.6, WALK, { parent = T, material = Enum.Material.Brick }) -- from the deck edge out (no gap)
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
	-- glass bays either side of the entrance (user 2026-10-23): west z WBAY..the
	-- cut corner, south x the cut corner..SBAY; white frames like the entrance
	local WBAY, SBAY = -67, 68
	box("WallW", W0, F, N0, W0 + 1, GF, WBAY, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	box("WallW", W0, F + 11.4 * SC, WBAY, W0 + 1, GF, S0 - CH, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	local wallS = box("WallS", W0 + CH, F, S0 - 1, W1, GF, S0, WHITE_WALL, opt({ material = Enum.Material.CeramicTiles }))
	box("WallN", W0, F, N0, W1, GF + 26, N0 + 1, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	box("WallE", W1 - 1, F, N0, W1, GF + 26, S0, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	box("Ceiling", W0, GF - 0.4, N0, W1, GF, S0 - CH, Color3.fromRGB(252, 238, 238), o)
	box("Ceiling", W0 + CH, GF - 0.4, S0 - CH, W1, GF, S0, Color3.fromRGB(252, 238, 238), o)
	-- and over the cut corner (the brick showed through the gap above the door)
	cutPart("Ceiling", CH * math.sqrt(2), GF - 0.4, GF, depthIn, -depthIn / 2, Color3.fromRGB(252, 238, 238), o)
	local LAMPS = { { 58, -88 }, { 58, -70 }, { 72, -88 }, { 72, -70 }, { 72, -56 }, { 84, -88 }, { 84, -70 }, { 84, -56 }, { 98, -85 }, { 98, -61 }, { 58, -104 }, { 72, -104 }, { 84, -104 } }
	for _, hx in ipairs({ 126, 140, 154, 168 }) do for _, hz in ipairs({ -104, -88, -72, -58 }) do table.insert(LAMPS, { hx, hz }) end end -- (the east hall, layout v8)
	for _, p in ipairs(LAMPS) do
		-- plain white panels (Neon panels made the bloom wash the room out)
		local lamp = box("CeilingLight", p[1] - 1.5, GF - 0.55, p[2] - 1.5, p[1] + 1.5, GF - 0.4, p[2] + 1.5, Color3.fromRGB(255, 252, 246), opt({ nocol = true }))
		local l = Instance.new("PointLight")
		-- low: ten lights at 1.2 blew the white room out (user: too bright)
		l.Range, l.Brightness, l.Color = 22, 0.3, Color3.fromRGB(255, 230, 220)
		l.Parent = lamp
	end

	-- front: the cut corner, pink frame around glass sidelights and sliding doors
	local cutLen = CH * math.sqrt(2)
	local DOOR = 7
	local ENTRY = Color3.fromRGB(248, 248, 246) -- the entrance frame is white (user 2026-10-23, was pink)
	cutPart("CornerHead", cutLen, F + 11.4 * SC, GF, 1, -0.5, WHITE_WALL, opt({ material = Enum.Material.Plaster })) -- above the frame head (they overlapped and flickered)
	for _, s in ipairs({ -1, 1 }) do
		-- the outer posts stand on the corners where the glass bays meet (user)
		cutAt("PinkPost", s * (cutLen / 2), Vector3.new(1.2, 11.4 * SC, 1.4), F + 5.7 * SC, -0.3, ENTRY) -- up to the sign band (user)
		-- light panel inside the outer post: lights up at night (NightGlow)
		local gp = cutAt("FrameGlow", s * (cutLen / 2), Vector3.new(0.5, 10 * SC, 0.1), F + 5.3 * SC, 0.45, Color3.fromRGB(255, 252, 246), opt({ nocol = true }))
		CS:AddTag(gp, "NightGlow")
	end
	cutAt("PinkHead", 0, Vector3.new(cutLen, 1.2, 1.4), F + 10.8 * SC, -0.3, ENTRY)
	do
		local gh = cutAt("FrameGlow", 0, Vector3.new(cutLen - 1, 0.5, 0.1), F + 10.8 * SC, 0.45, Color3.fromRGB(255, 252, 246), opt({ nocol = true }))
		CS:AddTag(gh, "NightGlow")
	end
	-- one sliding door (user sketch 2026-10-23): the doorway is on the left
	-- (west) between the corner post and one thin white post; right of that
	-- post is fixed glass, and the door leaf slides right behind it. The
	-- glass reaches the frame head (F + 10.2). A PUSH button on the left post
	-- (looks only).
	local GLASS = Color3.fromRGB(205, 220, 232)
	local DH = 10.2 * SC -- (the door grows with the floor, user 2026-10-27: tall avatars)
	local L0, L1 = -cutLen / 2 + 0.6, -1.45 -- doorway (s along the cut corner)
	local P = -1.25 -- the white post between door and fixed glass
	cutAt("DoorPost", P, Vector3.new(0.4, DH, 1), F + DH / 2, -0.3, ENTRY)
	local f0, f1 = P + 0.2, cutLen / 2 - 0.6
	cutAt("FixedGlass", (f0 + f1) / 2, Vector3.new(f1 - f0, DH, 0.3), F + DH / 2, -0.3, GLASS, opt({ material = Enum.Material.Glass, transparency = 0.45 }))
	local door = Instance.new("Model")
	door.Name = "AutoDoor"
	door:SetAttribute("Range", 9)
	local leafW = L1 - L0 + 0.2
	local slide = tC * (leafW - 0.1)
	local leafC = (L0 + L1 + 0.2) / 2
	cutAt("DoorPanel", leafC, Vector3.new(leafW, DH, 0.3), F + DH / 2, -0.65, GLASS, opt({ parent = door, material = Enum.Material.Glass, transparency = 0.4 })):SetAttribute("Slide", slide)
	for _, e in ipairs({ -1, 1 }) do
		cutAt("DoorFrame", leafC + e * (leafW / 2 - 0.12), Vector3.new(0.25, DH, 0.4), F + DH / 2, -0.65, ENTRY, opt({ parent = door, nocol = true })):SetAttribute("Slide", slide)
	end
	local dc = MC + tC * ((L0 + L1) / 2) - nC * 0.5
	door.WorldPivot = CFrame.new(dc.X, F + 4, dc.Z)
	door:SetAttribute("Panels", 3)
	door.Parent = B
	CS:AddTag(door, "AutoDoor")
	do -- PUSH / 눌러주세요 button on the left post, beside the doorway
		local btn = cutAt("PushButton", -cutLen / 2 + 0.42, Vector3.new(0.36, 1.5, 0.1), F + 4.3, 0.45, Color3.fromRGB(236, 238, 240), opt({ nocol = true, material = Enum.Material.Metal }))
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 160
		g.LightInfluence = 0.6
		g.Parent = btn
		local top = Instance.new("Frame")
		top.Size = UDim2.fromScale(1, 0.24)
		top.BackgroundColor3 = Color3.fromRGB(22, 22, 24)
		top.BorderSizePixel = 0
		top.Parent = g
		local push = Instance.new("TextLabel")
		push.Size = UDim2.fromScale(0.9, 0.5)
		push.Position = UDim2.fromScale(0.05, 0.4)
		push.BackgroundTransparency = 1
		push.Font = Enum.Font.Merriweather
		push.TextScaled = true
		push.TextColor3 = Color3.new(1, 1, 1)
		push.Text = "PUSH"
		push.Parent = top
		local ko = Instance.new("TextLabel")
		ko.Size = UDim2.fromScale(0.7, 0.68)
		ko.Position = UDim2.fromScale(0.15, 0.28)
		ko.BackgroundTransparency = 1
		ko.Font = Enum.Font.GothamMedium
		ko.TextScaled = true
		ko.TextColor3 = Color3.fromRGB(30, 30, 32)
		ko.Text = "눌\n러\n주\n세\n요"
		ko.Parent = g
	end	-- the glass bays: a post at the far end, a thin mullion, the head, glass
	local function glassBay(p0: Vector3, p1: Vector3, name: string)
		local along = (p1 - p0).Unit
		local len = (p1 - p0).Magnitude
		local function at(s, y) return CFrame.fromMatrix(p0 + along * s + Vector3.new(0, y, 0), along, Vector3.yAxis) end
		-- one pane: no middle post; thin white frames top and bottom (user)
		local FR = 0.45
		part(name .. "Post", Vector3.new(1, 11.4 * SC, 1.2), at(0.5, 5.7 * SC), ENTRY, o)
		part(name .. "Head", Vector3.new(len, FR, 1), at(len / 2, 11.4 * SC - FR / 2), ENTRY, o)
		part(name .. "Sill", Vector3.new(len, FR, 1), at(len / 2, FR / 2), ENTRY, o)
		part(name .. "Glass", Vector3.new(len - 1, 11.4 * SC - 2 * FR, 0.3), at((len + 1) / 2, 5.7 * SC), Color3.fromRGB(200, 215, 225), opt({ material = Enum.Material.Glass, transparency = 0.45 }))
	end
	-- the wooden step runs in under the bays up to the glass, like at the doors (user)
	box("Deck", W0, F - 0.3, WBAY, W0 + 0.5, F + 0.02, S0 - CH, WOOD, woodOpt) -- to the glass, none inside (user)
	box("Deck", W0 + CH, F - 0.3, S0 - 0.5, SBAY, F + 0.02, S0, WOOD, woodOpt)
	glassBay(Vector3.new(W0 + 0.5, F, WBAY), Vector3.new(W0 + 0.5, F, S0 - CH), "WestBay")
	glassBay(Vector3.new(SBAY, F, S0 - 0.5), Vector3.new(W0 + CH, F, S0 - 0.5), "SouthBay")

	-- left (west, north road): pink-framed poster window
	local function westPanel(name, z0, z1, y0, y1, out, color, op)
		return box(name, W0 - out, y0, z0, W0, y1, z1, color, op)
	end
	-- the poster fills the west face up to the sign band (user 2026-10-23)
	westPanel("PosterFrame", N0 + 2.5, WBAY - 1.5, F + 0.6, F + 11.2, 0.5, PINK, o) -- shorter by the glass bay (user)
	local poster = westPanel("Poster", N0 + 3.3, WBAY - 2.3, F + 1.4, F + 10.4, 0.6, Color3.fromRGB(196, 190, 236), o)
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
	-- inside, the south wall runs from the cut corner (x W0 + CH) to the booth
	-- wall (x 91.9): window, vanity, window, vanity, window with equal gaps
	-- (user 2026-10-23); the window by the sky booth is gone
	local PILL_W, PILL_H, PILL_Y = 4, 8.8, F + 6
	local VW, VH = 5.6, 11.5 -- make-up vanity arches
	-- the south glass bay took the first window and vanity (user); the window,
	-- vanity, window left are spaced with equal gaps from the slanted wall end
	-- by the bay (x SBAY + 1.6) to the booth wall (x 91.9)
	local PILL_X, VANITY_X = {}, {}
	do
		local x0, x1 = 68 + 1.6, 91.9
		local gap = (x1 - x0 - 2 * PILL_W - VW) / 4
		local x = x0 + gap
		for k = 1, 3 do
			local w = if k % 2 == 1 then PILL_W else VW
			table.insert(if k % 2 == 1 then PILL_X else VANITY_X, x + w / 2)
			x += w + gap
		end
	end
	local function pill(name, x, w, h, z, depth, color, op) -- box + two half discs
		local ps = { part(name, Vector3.new(w, h - w, depth), CFrame.new(x, PILL_Y, z), color, op) }
		for _, dy in ipairs({ -1, 1 }) do
			table.insert(ps, part(name, Vector3.new(depth, w, w), CFrame.new(x, PILL_Y + dy * (h - w) / 2, z) * CFrame.Angles(0, math.rad(90), 0), color, (function() local r = table.clone(op) r.shape = Enum.PartType.Cylinder return r end)()))
		end
		return ps
	end
	-- (layout v8) the east hall: two more pill windows and its own doorway
	-- (HALL_X0..HALL_X1) facing the east road
	table.insert(PILL_X, 126) table.insert(PILL_X, 172)
	local HALL_X0, HALL_X1 = 145, 153
	local holes = { part("BayHole", Vector3.new(SBAY - (W0 + CH) + 0.2, 11.4 * SC + 0.1, 3), CFrame.new((SBAY + W0 + CH) / 2, F + (11.4 * SC - 0.1) / 2, S0 - 0.5), WHITE_WALL, o),
		part("HallDoorHole", Vector3.new(HALL_X1 - HALL_X0, 11.4 * SC + 0.1, 3), CFrame.new((HALL_X0 + HALL_X1) / 2, F + (11.4 * SC - 0.1) / 2, S0 - 0.5), WHITE_WALL, o) }
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
		-- (layout v8) a cut union collides as a hull that fills the top of the
		-- hall doorway (tall avatars stuck): the wall itself does not collide,
		-- invisible boxes in its real shape do (the bay and pill windows have
		-- their own glass)
		cutWall.CanCollide = false
		local HH = 11.4 * SC
		for _, r in ipairs({ { W0 + CH, F, HALL_X0 }, { HALL_X1, F, W1 } }) do
			box("WallSCollider", r[1], r[2], S0 - 1, r[3], GF, S0, WHITE_WALL, opt({ transparency = 1 }))
		end
		box("WallSCollider", HALL_X0, F + HH, S0 - 1, HALL_X1, GF, S0, WHITE_WALL, opt({ transparency = 1 }))
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
	do -- (layout v8, user map 2026-10-27) the EAST HALL over the old construction
		-- site: a partition on the booths' east wall, a sliding glass door on the
		-- east road like the main one, and a photo lounge: a gallery wall of
		-- four-cut strips, sofas along the north wall, round tables with stools
		local DHH = 11.4 * SC
		box("WallMid", BW1 - 1, F, N0 + 1, BW1, GF - 0.4, S0 - 1, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
		for _, px in ipairs({ HALL_X0 - 0.6, HALL_X1 + 0.6 }) do
			box("HallDoorPost", px - 0.6, F, S0 - 1.2, px + 0.6, F + DHH, S0 + 0.2, ENTRY, o)
		end
		box("HallDoorHead", HALL_X0 - 1.2, F + DHH - 1, S0 - 1.2, HALL_X1 + 1.2, F + DHH, S0 + 0.2, ENTRY, o)
		local door = Instance.new("Model")
		door.Name = "AutoDoor"
		door:SetAttribute("Range", 9)
		local half = (HALL_X1 - HALL_X0) / 2
		for _, s2 in ipairs({ -1, 1 }) do
			local cx = (HALL_X0 + HALL_X1) / 2 + s2 * half / 2
			local p = box("DoorPanel", cx - half / 2, F, S0 - 0.75, cx + half / 2, F + DHH - 1, S0 - 0.45, GLASS, { parent = door, material = Enum.Material.Glass, transparency = 0.45 })
			p:SetAttribute("Slide", Vector3.new(s2 * (half - 0.2), 0, 0))
		end
		door.WorldPivot = CFrame.new((HALL_X0 + HALL_X1) / 2, F + 4, S0 - 0.6)
		door:SetAttribute("Panels", 2)
		door.Parent = B
		CS:AddTag(door, "AutoDoor")
		do -- invisible ramp from the sidewalk up the deck at the door
			local ramp = Instance.new("WedgePart")
			ramp.Name = "StepRamp"
			ramp.Anchored = true
			ramp.Transparency = 1
			ramp.Size = Vector3.new(HALL_X1 - HALL_X0 + 2, F - CURB, 2.4)
			local rc = Vector3.new((HALL_X0 + HALL_X1) / 2, (F + CURB) / 2, S0 + DECK + 1.2)
			ramp.CFrame = CFrame.lookAt(rc, rc + Vector3.new(0, 0, 1))
			ramp.Parent = B
		end
		local HP = Color3.fromRGB(255, 214, 228)
		box("HallLiner", BW1, F, N0 + 1, BW1 + 0.1, GF - 0.4, S0 - 1, HP, opt({ material = Enum.Material.SmoothPlastic }))
		box("HallLiner", BW1, F, N0 + 1, W1 - 1, GF - 0.4, N0 + 1.1, HP, opt({ material = Enum.Material.SmoothPlastic }))
		box("HallLiner", W1 - 1.1, F, N0 + 1, W1 - 1, GF - 0.4, S0 - 1, HP, opt({ material = Enum.Material.SmoothPlastic }))
		-- gallery wall on the partition: rows of four-cut strips in white frames
		local STRIPS = { Color3.fromRGB(255, 190, 210), Color3.fromRGB(190, 220, 255), Color3.fromRGB(255, 240, 190), Color3.fromRGB(210, 200, 255), Color3.fromRGB(200, 240, 220) }
		local k = 0
		for _, gz in ipairs({ -104, -96, -88, -80, -72, -64, -56 }) do
			for _, gy in ipairs({ F + 4, F + 11 }) do
				k += 1
				box("GalleryFrame", BW1 + 0.1, gy, gz - 1.6, BW1 + 0.3, gy + 5.6, gz + 1.6, Color3.fromRGB(250, 250, 250), opt({ nocol = true }))
				for c = 0, 3 do
					box("GalleryCut", BW1 + 0.3, gy + 0.3 + c * 1.3, gz - 1.3, BW1 + 0.35, gy + 1.4 + c * 1.3, gz + 1.3, STRIPS[(k + c) % #STRIPS + 1], opt({ nocol = true }))
				end
			end
		end
		local gs = box("GallerySign", BW1 + 0.1, F + 17.4, -96, BW1 + 0.3, F + 19.4, -64, Color3.fromRGB(250, 250, 250), opt({ nocol = true }))
		surfaceText(gs, Enum.NormalId.Right, "OHU 4cuts GALLERY · 오늘의 네컷", Color3.fromRGB(230, 110, 150), Enum.Font.FredokaOne)
		-- sofas along the north wall, facing the room
		local SOFA = Color3.fromRGB(250, 236, 240)
		for _, sx in ipairs({ 128, 146, 164 }) do
			box("HallSofaBase", sx - 6, F, N0 + 1.2, sx + 6, F + 1.4, N0 + 4.4, SOFA, opt({ material = Enum.Material.Fabric }))
			box("HallSofaBack", sx - 6, F + 1.4, N0 + 1.2, sx + 6, F + 4, N0 + 2.2, SOFA, opt({ material = Enum.Material.Fabric }))
			for _, dx in ipairs({ -4, 0, 4 }) do
				local p = Vector3.new(sx + dx, F + 1.6, N0 + 3.2)
				seat("HallSofaSeat", CFrame.lookAt(p, p + Vector3.new(0, 0, 1)), Vector3.new(2.4, 0.3, 2), SOFA, B).Transparency = 1
			end
		end
		-- round tables with four stools, clear of the aisle from the door (x 145..153)
		for _, tx in ipairs({ 125, 137, 161, 173 }) do
			for _, tz in ipairs({ -88, -68 }) do
				vcyl("HallTableLeg", Vector3.new(tx, F, tz), 0.5, 3, Color3.fromRGB(214, 172, 92), opt({ material = Enum.Material.Metal }))
				vcyl("HallTable", Vector3.new(tx, F + 3, tz), 4.4, 0.25, Color3.fromRGB(252, 252, 250), o)
				for a = 0, 3 do
					local ang = a * math.pi / 2 + math.pi / 4
					local p = Vector3.new(tx + math.cos(ang) * 3.4, F, tz + math.sin(ang) * 3.4)
					vcyl("HallStool", p, 1.6, 1.9, Color3.fromRGB(246, 150, 186), opt({ material = Enum.Material.Fabric }))
					seat("HallStoolSeat", CFrame.lookAt(Vector3.new(p.X, F + 2, p.Z), Vector3.new(tx, F + 2, tz)), Vector3.new(1.4, 0.2, 1.4), Color3.fromRGB(246, 150, 186), B).Transparency = 1
				end
			end
		end
	end

	-- fascia band over the ground floor with the signs (인생네컷-style: white
	-- raised letters with a lavender edge, aperture logo)
	-- the sign band sits just above the doors (user 2026-10-23: lower the box
	-- with the letters, so it shows on screen); a thin cornice marks the floor
	-- line under the upper floors
	local FAS0, FAS1 = F + 11.4 * SC, F + 17.6 -- taller white band (user 2026-10-23)

	local FASCIA = Color3.fromRGB(232, 231, 228) -- a touch darker than the white letters
	box("Fascia", W0 - 1.2, FAS0, N0, W0 + 1, FAS1, S0 - CH, FASCIA, o) -- to the building's north edge (user)
	box("Fascia", W0 + CH, FAS0, S0 - 1, W1 - 2, FAS1, S0 + 1.2, FASCIA, o)
	cutPart("Fascia", cutLen, FAS0 - 0.03, FAS1 + 0.03, 2.2, 0.1, FASCIA) -- a hair past the side bands (no flicker where they overlap)
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
		-- (user 2026-10-24, performance) the strokes become two solids: the letters
		-- (grey sides + white faces, colours kept) and the lavender halo; a sign
		-- was about 1,500 parts. CSG needs the parts in Workspace for a moment
		local home = m.Parent
		m.Parent = workspace
		local function merge(name, names, transparency)
			local list = {}
			for _, c in ipairs(m:GetChildren()) do
				if c:IsA("BasePart") and names[c.Name] then table.insert(list, c) end
			end
			if #list < 2 then return end
			local first = table.remove(list, 1)
			local ok, u = pcall(function() return first:UnionAsync(list) end)
			if not ok or not u then return end
			u.Name = name
			u.UsePartColor = false
			u.Anchored = true
			u.CanCollide = false
			u.CanQuery = false
			u.CanTouch = false
			u.Transparency = transparency
			if name == "LetterHalo" then u.CastShadow = false end
			u.Parent = m
			first:Destroy()
			for _, p in ipairs(list) do p:Destroy() end
		end
		merge("Letters", { Letter = true, LetterFace = true }, 0)
		merge("LetterHalo", { LetterHalo = true }, 0.25)
		m.Parent = home
	end
	-- the shop name sits one band lower, on the wall between the door frame and
	-- the fascia, so players see it from the street (user 2026-10-23)
	local fasMid = (FAS0 + FAS1) / 2
	sign3d("Sign_OhuNeCut", { "◎", "오", "후", "네", "컷" }, Vector3.new(MC.X, fasMid, MC.Z) + nC * 1.2, tC, nC, 1.33) -- 2/3 size
	-- (left-aligned with the poster frame's left edge, user 2026-10-26)
	sign3d("Sign_OHU4cuts", { "◎", "O", "H", "U", "4", "c", "u", "t", "s" }, Vector3.new(W0 - 1.2, fasMid, -90.2), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), 1.33)
	-- and on the south band over the capsule windows (user 2026-10-23)
	sign3d("Sign_OHU4cuts", { "◎", "O", "H", "U", "4", "c", "u", "t", "s" }, Vector3.new((W0 + CH + W1 - 2) / 2, fasMid, S0 + 1.2), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), 1.33)

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
		for _, z in ipairs({ -102, -90, -78, -66 }) do window(CFrame.lookAt(Vector3.new(W0, y, z), Vector3.new(W0 - 1, y, z)), 5, 6) end
		for _, x in ipairs({ 68, 81, 94, 107, 122, 136, 150, 164 }) do window(CFrame.lookAt(Vector3.new(x, y, S0), Vector3.new(x, y, S0 + 1)), 5, 6) end
		local c = MC + nC * 0
		window(CFrame.lookAt(Vector3.new(c.X, y, c.Z), Vector3.new(c.X, y, c.Z) + nC), 4.5, 6)
		if f == 1 then -- band between 2F and 3F
			box("FloorBand", W0 - 0.4, U0 + FLOOR - 0.3, N0, W0, U0 + FLOOR + 0.3, S0 - CH, WHITE_WALL, o)
			box("FloorBand", W0 + CH, U0 + FLOOR - 0.3, S0, W1, U0 + FLOOR + 0.3, S0 + 0.4, WHITE_WALL, o)
			cutPart("FloorBand", cutLen, U0 + FLOOR - 0.3, U0 + FLOOR + 0.3, 0.4, 0.2, WHITE_WALL)
		end
	end
	-- roof: slab, parapet on the street faces, steel railing, stair house
	-- (the roof slab stops 0.05 inside the parapets' outer faces: they flickered, user 2026-10-24)
	box("Roof", W0 + 0.05, U1, N0 + 0.05, W1, U1 + 0.5, S0 - CH, Color3.fromRGB(150, 150, 150), opt({ material = Enum.Material.Concrete }))
	box("Roof", W0 + CH, U1, S0 - CH, W1, U1 + 0.5, S0 - 0.05, Color3.fromRGB(150, 150, 150), opt({ material = Enum.Material.Concrete }))
	cutPart("Roof", cutLen, U1, U1 + 0.5, CH / math.sqrt(2) * 2, -CH / math.sqrt(2) - 0.05, Color3.fromRGB(150, 150, 150), opt({ material = Enum.Material.Concrete }))
	box("Parapet", W0, U1, N0, W0 + 0.8, U1 + 2.6, S0 - CH, WHITE_WALL, o)
	-- the north side (the gap to the club) gets the same white brick, a parapet and the railing (user 2026-10-24)
	box("UpperN", W0 - 0.05, 0, N0 - 0.6, W1, U1, N0, BRICK, opt({ material = Enum.Material.Brick }))
	box("Parapet", W0 + 0.8, U1, N0, W1, U1 + 2.6, N0 + 0.8, WHITE_WALL, o)
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
	rail(Vector3.new(W1 - 0.5, 0, N0 + 0.4), Vector3.new(W0 + 0.4, 0, N0 + 0.4))
	rail(Vector3.new(W0 + 0.4, 0, N0 + 0.5), P1 + Vector3.new(0.4, 0, 0))
	rail(P1 + Vector3.new(0.4, 0, 0), P2 + Vector3.new(0, 0, -0.4))
	rail(P2 + Vector3.new(0, 0, -0.4), Vector3.new(W1 - 0.5, 0, S0 - 0.4))
	box("StairHouse", W1 - 16, U1 + 0.5, N0 + 2, W1 - 3, U1 + 9, N0 + 12, WHITE_WALL, opt({ material = Enum.Material.Plaster }))
	------------------------------------------------- interior (user plan + photos 2026-10-23, v2)
	-- Pink plaster walls (not white: the white room glared), a white tile floor
	-- with a grey diagonal grid, softer ceiling lights. West wall: two arched
	-- niches cut into the pink wall, sky-blue inside, with glass shelves of
	-- hats and plush, and a pill-shaped mirror between them. Booth wall: a
	-- smaller arch per booth near its north end (no curtains), the photo
	-- machine on each booth's north wall looking south at the backdrop (the
	-- booth's CameraPoint / Stand / Backdrop are moved to match). South wall:
	-- two arched make-up vanities between the capsule windows. A white oval
	-- table in the middle of the hall.
	local PINK_WALL = Color3.fromRGB(255, 204, 222) -- bright pastel pink (user photo 2026-10-23: was dull)
	local SKY = Color3.fromRGB(150, 212, 228) -- 인디스카이
	local GOLDT = Color3.fromRGB(214, 172, 92)
	local PLASTER = opt({ material = Enum.Material.SmoothPlastic }) -- clean painted walls like the photo
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
	local function archRim(c: Vector3, along: Vector3, out: Vector3, w, h, th, depth, color, parent, mat)
		local r = w / 2
		local postH = h - r
		for _, s in ipairs({ -1, 1 }) do
			local p = c + along * (s * (r - th / 2)) + Vector3.new(0, postH / 2, 0)
			part("ArchRim", Vector3.new(th, postH, depth), CFrame.fromMatrix(p, along, Vector3.yAxis), color, { parent = parent, material = mat })
		end
		local top = c + Vector3.new(0, postH, 0)
		local N = 10
		for k = 0, N - 1 do
			local a0, a1 = math.pi * k / N, math.pi * (k + 1) / N
			local p0 = top + along * (math.cos(a0) * (r - th / 2)) + Vector3.new(0, math.sin(a0) * (r - th / 2), 0)
			local p1 = top + along * (math.cos(a1) * (r - th / 2)) + Vector3.new(0, math.sin(a1) * (r - th / 2), 0)
			local d = p1 - p0
			part("ArchRim", Vector3.new(d.Magnitude + th * 0.6, th, depth), CFrame.fromMatrix((p0 + p1) / 2, d.Unit, out:Cross(d.Unit)), color, { parent = parent, material = mat })
		end
	end
	-- a flat arch-shaped panel (box + half disc)
	local function archPanel(c: Vector3, along: Vector3, out: Vector3, w, h, depth, color, parent, mat)
		local r = w / 2
		local body = part("ArchPanel", Vector3.new(w, h - r, depth), CFrame.fromMatrix(c + Vector3.new(0, (h - r) / 2, 0), along, Vector3.yAxis), color, { parent = parent, material = mat })
		part("ArchPanel", Vector3.new(depth, w, w), CFrame.fromMatrix(c + Vector3.new(0, h - r, 0), out, Vector3.yAxis), color, { parent = parent, material = mat, shape = Enum.PartType.Cylinder })
		return body
	end
	-- arch-shaped hole parts (for CSG) in a wall whose normal is `out`
	local function archHole(c: Vector3, along: Vector3, out: Vector3, w, h, depth)
		local r = w / 2
		local a = part("ArchHole", Vector3.new(w, h - r, depth), CFrame.fromMatrix(c + Vector3.new(0, (h - r) / 2, 0), along, Vector3.yAxis), WHITE_WALL, o)
		local b = part("ArchHole", Vector3.new(depth, w, w), CFrame.fromMatrix(c + Vector3.new(0, h - r, 0), out, Vector3.yAxis), WHITE_WALL, opt({ shape = Enum.PartType.Cylinder }))
		return { a, b }
	end
	local function subtract(wall: BasePart, holes: {BasePart}, name: string, mat)
		wall.Parent = workspace
		for _, p in ipairs(holes) do p.Parent = workspace end
		local ok, res = pcall(function() return wall:SubtractAsync(holes) end)
		for _, p in ipairs(holes) do p:Destroy() end
		wall.Parent = B
		if ok and res then
			res.Name = name
			res.UsePartColor = true
			res.Material = mat
			res.Anchored = true
			res.Parent = B
			wall:Destroy()
			return res
		end
		return wall
	end

	-- the club south wall reaches z -96 (inside this shop since the shop moved
	-- north, D-104): the north liner stands in front of it, the photo wall too
	-- (layout v8) the lobby's north liner moved up to the new north wall; the
	-- booths keep their north end (BNIN), closed there by its own liner
	local NIN = N0 + 2.7
	box("WallPink", W0 + 1, F, NIN - 0.1, 91.9, GF - 0.4, NIN, PINK_WALL, PLASTER)
	box("WallPink", 91.9, F, BNIN - 0.1, BW1 - 1, GF - 0.4, BNIN, PINK_WALL, PLASTER)
	local zoneP = root:FindFirstChild("08_PhotoBooth")
	do
		local p = zoneP and zoneP:FindFirstChild("PhotoWall")
		if p and p:IsA("BasePart") then
			p:SetAttribute("OrigCFrame", p.CFrame)
			-- centred on the wall as seen inside: pink west wall face (W0 + 2.6) to the booth wall (91.9)
			p.CFrame = p.CFrame.Rotation + Vector3.new((W0 + 2.6 + 91.9) / 2, p.Position.Y, NIN + p.Size.Z / 2 + 0.05)
			-- the shop name over the photo wall (user)
			sign3d("Sign_PhotoWall", { "◎", "오", "후", "네", "컷" }, Vector3.new(p.Position.X, p.Position.Y + p.Size.Y / 2 + 2.2, NIN), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), 2)
		end
	end
	-- the entrance (cut corner) wall is pink above the doors too
	cutPart("WallPink", CH * math.sqrt(2), F + 11.4 * SC, GF - 0.4, 0.1, -1.05, PINK_WALL, PLASTER)
	-- south wall: a thick pink wall like the west one (user 2026-10-23), cut
	-- through in the shape of each capsule window and with an arched recess
	-- for each make-up vanity; it ends at the booth wall
	local SZ0, SZ1 = S0 - 2.6, S0 - 1 -- inner face / against the outer wall
	do
		-- where the thick walls meet the glass bays the wall end is slanted (user)
		local function wedgeTri(name, A: Vector3, Bv: Vector3, C: Vector3) -- right angle at Bv, A on the glass side
			local w = Instance.new("WedgePart")
			w.Name = name
			w.Anchored = true
			w.Color = PINK_WALL
			w.Material = Enum.Material.SmoothPlastic
			local ly, lz = (C - Bv).Unit, (Bv - A).Unit
			w.Size = Vector3.new(GF - 0.4 - F, (C - Bv).Magnitude, (Bv - A).Magnitude)
			local mid = (A + C) / 2
			w.CFrame = CFrame.fromMatrix(Vector3.new(mid.X, (F + GF - 0.4) / 2, mid.Z), ly:Cross(lz), ly, lz)
			w.Parent = B
		end
		wedgeTri("PinkWallEnd", Vector3.new(SBAY, 0, SZ1), Vector3.new(SBAY + 1.6, 0, SZ1), Vector3.new(SBAY + 1.6, 0, SZ0))
		wedgeTri("PinkWallEnd", Vector3.new(W0 + 1, 0, WBAY), Vector3.new(W0 + 1, 0, WBAY - 1.6), Vector3.new(W0 + 2.6, 0, WBAY - 1.6))
		local wall = box("PinkWallS", SBAY + 1.6, F, SZ0, 91.9, GF - 0.4, SZ1, PINK_WALL, PLASTER)
		-- pink above the glass bays inside
		box("WallPink", W0 + CH, F + 11.4 * SC, S0 - 1.1, SBAY, GF - 0.4, S0 - 1, PINK_WALL, PLASTER)
		box("WallPink", W0 + 1, F + 11.4 * SC, WBAY, W0 + 1.1, GF - 0.4, S0 - CH, PINK_WALL, PLASTER)
		local holes = {}
		for _, cx in ipairs(PILL_X) do
			local w, h, cy = PILL_W, PILL_H, PILL_Y
			table.insert(holes, part("PillCut", Vector3.new(w, h - w, 3), CFrame.new(cx, cy, (SZ0 + SZ1) / 2), WHITE_WALL, o))
			for _, s in ipairs({ -1, 1 }) do
				table.insert(holes, part("PillCut", Vector3.new(3, w, w), CFrame.new(cx, cy + s * (h - w) / 2, (SZ0 + SZ1) / 2) * CFrame.Angles(0, math.rad(90), 0), WHITE_WALL, opt({ shape = Enum.PartType.Cylinder })))
			end
		end
		for _, vx in ipairs(VANITY_X) do
			for _, h in ipairs(archHole(Vector3.new(vx, F - 0.1, (SZ0 + SZ1) / 2), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), VW, VH + 0.1, SZ1 - SZ0 + 0.6)) do table.insert(holes, h) end
		end
		subtract(wall, holes, "PinkWallS", Enum.Material.SmoothPlastic)
	end
	-- (no grid lines on the floor: user 2026-10-23; the tiles alone)
	---------------------------------------------------------------- booths
	local booths = {}
	local shopZone = root:FindFirstChild("08_PhotoBooth")
	if shopZone then
		for _, m in ipairs(shopZone:GetChildren()) do
			if m:IsA("Model") and CS:HasTag(m, "PhotoBooth") and m:FindFirstChild("StudioFloor") then table.insert(booths, m) end
		end
	end
	table.sort(booths, function(a, b) return a.StudioFloor.Position.Z < b.StudioFloor.Position.Z end)
	-- three booths of the same size (user 2026-10-23): the space from the north
	-- wall to the south wall split in three. A booth is its floor, ceiling and
	-- its own north / south walls (1 thick): PINK, WHITE, then SKY (a copy of
	-- WHITE) in the south, where the third capsule window was
	local FX = 91.9 -- the booth wall, right against the booths (their west side is x 93)
	local AW, AH = 7 * 2 / 3, 10 -- the arches 2/3 as wide (user)
	local function remember(p: Instance?)
		if p and p:IsA("BasePart") and p:GetAttribute("OrigCFrame") == nil then
			p:SetAttribute("OrigCFrame", p.CFrame)
			p:SetAttribute("OrigSize", p.Size)
		end
	end
	local SPAN0, SPAN1 = BNIN, S0 - 1
	local DEPTH = (SPAN1 - SPAN0) / 3
	local function fitBooth(m: Model, zc: number)
		local dz = zc - m.StudioFloor.Position.Z
		if math.abs(dz) > 0.01 then
			local d = CFrame.new(0, 0, dz)
			m:SetAttribute("TempOrig", m:GetPivot())
			m:SetAttribute("TempDelta", d)
			for _, x in ipairs(m:GetDescendants()) do
				for k, v in pairs(x:GetAttributes()) do if typeof(v) == "Vector3" then x:SetAttribute(k, d * v) end end
			end
			m:PivotTo(d * m:GetPivot())
		end
		local function set(p: Instance?, sizeZ: number?, pos: Vector3)
			if not (p and p:IsA("BasePart")) then return end
			remember(p)
			if sizeZ then p.Size = Vector3.new(p.Size.X, p.Size.Y, sizeZ) end
			p.CFrame = p.CFrame.Rotation + pos
		end
		local fl = m.StudioFloor
		-- the booth fills the width from the booth wall to the east wall (2026-10-26)
		local bx0, bx1 = FX + 1, BW1 - 1.1
		local bcx, bw = (bx0 + bx1) / 2, bx1 - bx0
		local function widen(p: BasePart, _: boolean)
			-- the part's local axis that runs along world X (the zone is turned)
			local cf = p.CFrame
			if math.abs(cf.XVector.X) > 0.9 then p.Size = Vector3.new(bw, p.Size.Y, p.Size.Z)
			elseif math.abs(cf.ZVector.X) > 0.9 then p.Size = Vector3.new(p.Size.X, p.Size.Y, bw)
			elseif math.abs(cf.YVector.X) > 0.9 then p.Size = Vector3.new(p.Size.X, bw, p.Size.Z) end
		end
		-- the booth floor is flush with the lobby floor (it stood proud, user)
		set(fl, DEPTH - 2, Vector3.new(bcx, F - fl.Size.Y / 2 + 0.005, zc))
		widen(fl, false)
		local ce = m:FindFirstChild("Ceiling") :: BasePart?
		if ce then set(ce, DEPTH - 1, Vector3.new(bcx, ce.Position.Y, zc)) widen(ce, false) end
		for _, w in ipairs({ { "Wall_N", -1 }, { "Wall_S", 1 } }) do
			local p = m:FindFirstChild(w[1]) :: BasePart?
			if p then set(p, nil, Vector3.new(bcx, p.Position.Y, zc + w[2] * (DEPTH / 2 - 0.5))) widen(p, true) end
		end
	end
	for i, m in ipairs(booths) do fitBooth(m, SPAN0 + DEPTH * (i - 0.5)) end
	if #booths == 2 and shopZone then
		local src = booths[2]
		local SKYB = Color3.fromRGB(150, 212, 228)
		local SKYF = Color3.fromRGB(196, 232, 242)
		local m = src:Clone()
		m.Name = "PhotoBooth_SKY"
		m:SetAttribute("BoothKey", "SKY")
		m:SetAttribute("BoothName", "SKY 부스")
		m:SetAttribute("TempOrig", nil)
		m:SetAttribute("TempDelta", nil)
		m:SetAttribute("LayoutAdded", true)
		for _, x in ipairs(m:GetDescendants()) do
			for k in pairs(x:GetAttributes()) do
				if k:sub(1, 4) == "Orig" then x:SetAttribute(k, nil) end
			end
			if x:IsA("TextLabel") then x.Text = (x.Text:gsub("WHITE", "SKY")) end
			if x:IsA("BasePart") then x.CFrame = x.CFrame + Vector3.new(0, 0, DEPTH) end
		end
		for _, nm in ipairs({ "Wall_N", "Wall_S", "Ceiling", "Backdrop" }) do
			local p = m:FindFirstChild(nm)
			if p and p:IsA("BasePart") then p.Color = SKYB end
		end
		m.StudioFloor.Color = SKYF
		m.Parent = shopZone
		table.insert(booths, m)
	end
	local archZ = {}
	for _, m in ipairs(booths) do
		local floorP = m.StudioFloor
		local bx, bz = floorP.Position.X, floorP.Position.Z
		local half = floorP.Size.Z / 2 -- inside, wall to wall
		local camP, stand, back = m:FindFirstChild("CameraPoint"), m:FindFirstChild("Stand"), m:FindFirstChild("Backdrop")
		remember(camP) remember(stand) remember(back)
		-- the camera on the north wall looking south (+z)
		-- (0.8 higher with the wider view, so tall avatars keep their heads: 2026-10-26)
		local camPos = Vector3.new(bx, F + 4.6, bz - half + 0.6)
		camP.CFrame = CFrame.lookAt(camPos, camPos + Vector3.new(0, 0, 1))
		-- people stand south of it, facing it (Stand -Z = toward the camera)
		local sp = Vector3.new(bx, stand.Position.Y, bz + half - 3.6)
		local boothW = floorP.Size.X
		stand.Size = Vector3.new(boothW - 3, stand.Size.Y, 7)
		stand.CFrame = CFrame.lookAt(sp, sp + Vector3.new(0, 0, -1))
		-- backdrop on the south wall of the booth, as wide as the booth
		back.CFrame = CFrame.new(bx, back.Position.Y, bz + half + 0.1) * CFrame.Angles(0, math.rad(90), 0)
		back.Size = Vector3.new(back.Size.X, back.Size.Y, boothW)
		-- the old camera prop stays hidden
		local camProp = m:FindFirstChild("CameraProp")
		if camProp and camProp:IsA("BasePart") then
			camProp:SetAttribute("OrigTransparency", camProp.Transparency)
			camProp.Transparency = 1
		end
		local az = bz - half + 3.5
		-- the shop's east wall is each booth's east side: painted in the booth colour (user)
		local wn = m:FindFirstChild("Wall_N")
		local boothColor = if wn and wn:IsA("BasePart") then wn.Color else WHITE_WALL
		-- every face of a booth in its one colour (user 2026-10-26), the floor too
		floorP:SetAttribute("OrigColor", floorP:GetAttribute("OrigColor") or floorP.Color)
		floorP.Color = boothColor
		for _, nm in ipairs({ "Ceiling", "Backdrop", "Wall_S" }) do
			local p = m:FindFirstChild(nm)
			if p and p:IsA("BasePart") then p.Color = boothColor end
		end
		local lining = part("BoothLining", Vector3.new(0.1, 12, half * 2), CFrame.new(BW1 - 1.05, F + 6, bz), boothColor, { parent = m, material = Enum.Material.SmoothPlastic })
		lining:SetAttribute("LayoutAdded", true)
		-- the west side inside is the pink booth wall: lined in the booth colour
		-- too, with the arch cut out (user 2026-10-26: one colour all round)
		do
			-- (no collision: a cut union collides as its hull, the booth wall behind is solid)
			local west = part("BoothLiningW", Vector3.new(0.1, 12, half * 2), CFrame.new(FX + 1.05, F + 6, bz), boothColor, { parent = m, material = Enum.Material.SmoothPlastic, nocol = true })
			local holes = archHole(Vector3.new(FX + 1.05, F - 0.1, az), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), AW, AH + 0.1, 1)
			west.Parent = workspace
			for _, h in ipairs(holes) do h.Parent = workspace end
			local ok, res = pcall(function() return west:SubtractAsync(holes) end)
			for _, h in ipairs(holes) do h:Destroy() end
			if ok and res then
				res.Name = "BoothLiningW"
				res.UsePartColor = true
				res.Anchored = true
				res.CanCollide = false
				res.Parent = m
				west:Destroy()
				west = res
			else
				west.Parent = m
			end
			west:SetAttribute("LayoutAdded", true)
		end
		table.insert(archZ, az)
		-- leaving the booth: out through its arch (PhotoBoothService uses ExitPoint)
		local ex = Vector3.new(FX - 3, F + 3, az)
		local exitP = part("ExitPoint", Vector3.new(1, 1, 1), CFrame.lookAt(ex, ex + Vector3.new(-1, 0, 0)), WHITE_WALL, { parent = m, nocol = true, transparency = 1 })
		exitP.CanQuery = false
		exitP.CanTouch = false
		exitP:SetAttribute("LayoutAdded", true)
		-- a soft light under each booth ceiling (the hall lights are above it)
		local ceil = m:FindFirstChild("Ceiling")
		if ceil and ceil:IsA("BasePart") then
			local l = Instance.new("SurfaceLight")
			l.Name = "BoothLight"
			l.Face = Enum.NormalId.Bottom
			l.Range, l.Brightness, l.Angle, l.Color = 12, 0.6, 120, Color3.fromRGB(255, 244, 236)
			l:SetAttribute("LayoutAdded", true)
			l.Parent = ceil
		end
	end
	-- pink booth wall at x 87 with a small arch per booth
	do
		-- on to the south wall: the space beside the capsule windows behind the
		-- booths is closed off (user 2026-10-23)
		local wall = box("BoothWall", FX, F, NIN, FX + 1, GF - 0.4, S0 - 1.1, PINK_WALL, PLASTER)
		local holes = {}
		for _, z in ipairs(archZ) do
			for _, h in ipairs(archHole(Vector3.new(FX + 0.5, F - 0.1, z), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), AW, AH + 0.1, 4)) do table.insert(holes, h) end
		end
		local cut = subtract(wall, holes, "BoothWall", Enum.Material.SmoothPlastic)
		-- (2026-10-27, mobile 2P test: all three booth arches were shut) a cut
		-- union collides as one block with its holes filled: the wall itself
		-- does not collide, invisible boxes in its real shape do (an arch is
		-- AW wide, open up to the top of its round head)
		if cut:IsA("UnionOperation") then
			cut.CanCollide = false
			local edges = { NIN }
			for _, z in ipairs(archZ) do table.insert(edges, z - AW / 2) table.insert(edges, z + AW / 2) end
			table.insert(edges, S0 - 1.1)
			table.sort(edges)
			for i = 1, #edges - 1, 2 do
				box("BoothWallCollider", FX, F, edges[i], FX + 1, GF - 0.4, edges[i + 1], PINK_WALL, opt({ transparency = 1 }))
			end
			for _, z in ipairs(archZ) do
				box("BoothWallCollider", FX, F + AH, z - AW / 2, FX + 1, GF - 0.4, z + AW / 2, PINK_WALL, opt({ transparency = 1 }))
			end
		end
	end
	-- LED light box (user photo): a white rounded sign lit from inside, black
	-- letters, a faint glow on the wall around it. c = centre of the face,
	-- out = the way it faces
	local function ledSign(name: string, c: Vector3, out: Vector3, w: number, h: number, text: string)
		local cf = CFrame.lookAt(c, c + out) -- local +Z points back into the wall
		part(name .. "Box", Vector3.new(w - 0.2, h - 0.2, 0.3), cf * CFrame.new(0, 0, 0.17), Color3.fromRGB(236, 236, 236), opt({ nocol = true }))
		local function layer(partName, size, back, color, alpha, brightness)
			local p = part(partName, Vector3.new(size.X, size.Y, 0.02), cf * CFrame.new(0, 0, back), Color3.new(1, 1, 1), opt({ nocol = true, transparency = 1 }))
			p.CastShadow = false
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 80
			g.LightInfluence = 0
			g.Brightness = brightness
			g.Parent = p
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = color
			bg.BackgroundTransparency = alpha
			bg.BorderSizePixel = 0
			bg.Parent = g
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, math.floor(math.min(size.X, size.Y) * 80 * 0.3))
			corner.Parent = bg
			return p, bg
		end
		-- soft halo on the wall (two faint rounded layers), then the face
		layer(name .. "Halo", Vector2.new(w + 0.5, h + 0.5), 0.33, Color3.fromRGB(255, 252, 240), 0.82, 1)
		layer(name .. "Halo", Vector2.new(w + 0.22, h + 0.22), 0.32, Color3.fromRGB(255, 252, 240), 0.6, 1)
		local face, bg = layer(name, Vector2.new(w, h), 0, Color3.fromRGB(255, 255, 253), 0, 1.25)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(0.84, 0.56)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamMedium
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(28, 28, 30)
		l.Text = text
		l.Parent = bg
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Front
		glow.Range, glow.Brightness, glow.Angle, glow.Color = 5, 0.45, 150, Color3.fromRGB(255, 250, 240)
		glow.Parent = face
	end
	local ROOMS = { PINK = "PINK ROOM", WHITE = "WHITE ROOM", SKY = "SKY ROOM" }
	for i, z in ipairs(archZ) do
		-- the lining inside the arch opening takes the booth's colour (user)
		local wn = booths[i]:FindFirstChild("Wall_N")
		local lining = if wn and wn:IsA("BasePart") then wn.Color else SKY
		archRim(Vector3.new(FX + 0.5, F, z), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), AW, AH, 0.15, 1.02, lining, B, Enum.Material.SmoothPlastic)
		local name = ROOMS[booths[i]:GetAttribute("BoothKey") or ""] or string.format("PHOTO %02d", i)
		ledSign("RoomSign", Vector3.new(FX - 0.35, F + AH + 1.6, z), Vector3.new(-1, 0, 0), 4.85, 1.35, name)
	end

	-- photo machine (user photo "Pick") on each booth's north wall; its front
	-- face is just behind CameraPoint so it never shows in the photos
	for _, m in ipairs(booths) do
		local camP = m.CameraPoint
		local look = camP.CFrame.LookVector
		local front = camP.Position - look * 0.1
		local base = CFrame.lookAt(Vector3.new(front.X, F, front.Z), Vector3.new(front.X, F, front.Z) + Vector3.new(look.X, 0, look.Z))
		local K = Instance.new("Model")
		K.Name = "PhotoMachine"
		K.Parent = B
		local D = 1.4
		local lensY = camP.Position.Y - F
		-- the "사진 찍기" / "같이 찍기" prompts sit on this machine's body (user
		-- 2026-10-26: on the Stand they reached into the next booth): the machine
		-- belongs to its booth and PhotoBoothService puts the prompts on MachineBody
		do
			local old = m:FindFirstChild("PromptPoint")
			if old then old:Destroy() end
			local oldK = m:FindFirstChild("PhotoMachine")
			if oldK then oldK:Destroy() end
			K.Parent = m
			K:SetAttribute("LayoutAdded", true)
		end
		local RED, KWHITE = Color3.fromRGB(196, 54, 58), Color3.fromRGB(242, 242, 244)
		local function kbox(name, y0, y1, w, color, depth)
			local dd = depth or D
			return part(name, Vector3.new(w, y1 - y0, dd), base * CFrame.new(0, (y0 + y1) / 2, dd / 2), color, { parent = K })
		end
		local function face(name, y, w, h, color, mat) -- a thin panel on the front face
			return part(name, Vector3.new(w, h, 0.05), base * CFrame.new(0, y, -0.03), color, { parent = K, nocol = true, material = mat })
		end
		local baseTop = lensY - 2.2
		kbox("MachineBase", 0, baseTop, 4.6, RED)
		kbox("MachineLedge", baseTop, baseTop + 0.25, 4.8, KWHITE, D + 0.2)
		kbox("MachineBody", baseTop + 0.25, lensY + 1.3, 4.6, KWHITE)
		kbox("MachineHood", lensY + 1.3, lensY + 2.4, 4.6, Color3.fromRGB(230, 230, 232))
		local band = kbox("MachineBand", lensY + 2.4, lensY + 3, 4.8, RED, D + 0.1)
		txt(band, Enum.NormalId.Front, "OHU", Color3.fromRGB(255, 225, 200), Enum.Font.FredokaOne, nil, 50)
		face("MachineLight", lensY + 1.85, 4, 0.9, Color3.fromRGB(225, 238, 255), Enum.Material.Neon)
		for _, s in ipairs({ -1, 1 }) do
			part("MachineBar", Vector3.new(0.45, 2.4, 0.05), base * CFrame.new(s * 1.95, lensY - 0.4, -0.03), Color3.fromRGB(225, 238, 255), { parent = K, nocol = true, material = Enum.Material.Neon })
		end
		local screen = face("MachineScreen", lensY - 1.1, 2.6, 1.1, Color3.fromRGB(250, 240, 245))
		txt(screen, Enum.NormalId.Front, "OHU4cuts  ×  FRAME", Color3.fromRGB(200, 70, 110), Enum.Font.GothamBold, Color3.fromRGB(255, 236, 244), 60)
		part("MachineLens", Vector3.new(0.05, 0.75, 0.75), base * CFrame.new(0, lensY, -0.04) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(15, 15, 18), { parent = K, nocol = true, shape = Enum.PartType.Cylinder })
		local lk = face("MachineLook", lensY, 3.4, 0.4, KWHITE)
		lk.Transparency = 1
		txt(lk, Enum.NormalId.Front, "LOOK       HERE", Color3.fromRGB(200, 50, 50), Enum.Font.GothamBold, nil, 60)
		part("PhotoOutlet", Vector3.new(1.1, 0.6, 0.05), base * CFrame.new(1.1, baseTop - 1.3, -0.03), Color3.fromRGB(205, 225, 255), { parent = K, nocol = true, material = Enum.Material.Neon })
	end

	-- between the arches: blue light boxes with neon tubes + pink notices
	if #booths >= 2 then
		local zMid = (booths[1].StudioFloor.Position.Z + booths[2].StudioFloor.Position.Z) / 2
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
			local zc, yc = archZ[2] + 5.2 + col * 2.6, F + 10 - row * 3.4
			local poster = part("NoticePoster", Vector3.new(0.1, 3, 2.3), CFrame.new(FX - 0.06, yc, zc), Color3.fromRGB(255, 240, 242), opt({ nocol = true }))
			txt(poster, Enum.NormalId.Left, s, Color3.fromRGB(200, 70, 90), Enum.Font.GothamBold, nil, 50)
		end
	end

	---------------------------------------------------------------- west wall (left photo)
	local HAT = { Color3.fromRGB(30, 30, 34), Color3.fromRGB(240, 120, 150), Color3.fromRGB(250, 210, 80), Color3.fromRGB(120, 190, 120), Color3.fromRGB(220, 60, 60), Color3.fromRGB(160, 120, 90), Color3.fromRGB(250, 250, 250), Color3.fromRGB(120, 160, 230) }
	do
		local WX0, WX1 = W0 + 1, W0 + 2.6 -- the pink wall is 1.6 thick so the niches are recessed
		local wAlong, wOut = Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)
		local NICHES = { -91, -74.5 } -- north a little: the glass bay starts at z -67, its slanted wall end at -68.6
		local NW, NH = 9, 13.5
		local wall = box("PinkWallW", WX0, F, NIN, WX1, GF - 0.4, WBAY - 1.6, PINK_WALL, PLASTER)
		local holes = {}
		for _, zc in ipairs(NICHES) do
			for _, h in ipairs(archHole(Vector3.new((WX0 + WX1) / 2, F - 0.1, zc), wAlong, wOut, NW, NH + 0.1, 2.2)) do table.insert(holes, h) end
		end
		-- the pill mirror sits in a pill-shaped recess too (user 2026-10-23)
		local mz = (NICHES[1] + NICHES[2]) / 2
		do
			local w, h, xc, cy = 4.4, 8.4, (WX0 + WX1) / 2, F + 7.2 -- F + 3 .. F + 11.4 (user sketch)
			table.insert(holes, part("PillCut", Vector3.new(2.2, h - w, w), CFrame.new(xc, cy, mz), WHITE_WALL, o))
			for _, s in ipairs({ -1, 1 }) do
				table.insert(holes, part("PillCut", Vector3.new(2.2, w, w), CFrame.new(xc, cy + s * (h - w) / 2, mz), WHITE_WALL, opt({ shape = Enum.PartType.Cylinder })))
			end
		end
		subtract(wall, holes, "PinkWallW", Enum.Material.SmoothPlastic)
		local hatN = 0
		for _, zc in ipairs(NICHES) do
			-- sky-blue back + lit edge
			local back = archPanel(Vector3.new(WX0 + 0.15, F, zc), wAlong, wOut, NW, NH, 0.2, SKY, B, Enum.Material.SmoothPlastic)
			local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Back sl.Range = 6 sl.Brightness = 0.5 sl.Color = Color3.fromRGB(220, 245, 255) sl.Parent = back
			archRim(Vector3.new(WX1 - 0.05, F, zc), wAlong, wOut, NW + 0.3, NH + 0.15, 0.18, 0.3, Color3.fromRGB(255, 250, 240), B, Enum.Material.Neon)
			local sign = part("NicheSign", Vector3.new(0.05, 0.9, 3.4), CFrame.new(WX0 + 0.3, F + NH - 2.4, zc), SKY, opt({ nocol = true, transparency = 1 }))
			txt(sign, Enum.NormalId.Right, "OHU 4 CUT\nPLAYGROUND", Color3.fromRGB(40, 60, 80), Enum.Font.GothamMedium, nil, 60)
			-- glass shelves on chrome posts, hats and plush on them
			local sx0, sx1 = WX0 + 0.3, WX1 + 1.2
			for _, s in ipairs({ -1, 1 }) do
				for _, xx in ipairs({ sx0 + 0.1, sx1 - 0.1 }) do
					part("ShelfPost", Vector3.new(0.12, 8.6, 0.12), CFrame.new(xx, F + 4.3, zc + s * 3.6), Color3.fromRGB(215, 215, 220), opt({ material = Enum.Material.Metal }))
				end
			end
			for lv = 0, 3 do
				local y = F + 1.4 + lv * 2.2
				box("GlassShelf", sx0, y, zc - 3.8, sx1, y + 0.1, zc + 3.8, Color3.fromRGB(220, 240, 245), opt({ material = Enum.Material.Glass, transparency = 0.5 }))
				for k = 0, 3 do
					hatN += 1
					local c = HAT[(hatN % #HAT) + 1]
					local p = Vector3.new((sx0 + sx1) / 2, y + 0.1, zc - 2.7 + k * 1.8)
					if (k + lv) % 3 ~= 2 then
						-- cap: dome + brim
						part("HatDome", Vector3.new(1.3, 1.3, 1.3), CFrame.new(p + Vector3.new(0, 0.1, 0)), c, opt({ shape = Enum.PartType.Ball, material = Enum.Material.Fabric, nocol = true }))
						part("HatBrim", Vector3.new(0.12, 1.6, 1.6), CFrame.new(p + Vector3.new(0.35, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), c, opt({ shape = Enum.PartType.Cylinder, material = Enum.Material.Fabric, nocol = true }))
					else
						-- plush
						part("Plush", Vector3.new(1.2, 1.1, 1.1), CFrame.new(p + Vector3.new(0, 0.55, 0)), c, opt({ shape = Enum.PartType.Ball, material = Enum.Material.Fabric, nocol = true }))
						part("PlushEar", Vector3.new(0.45, 0.45, 0.45), CFrame.new(p + Vector3.new(0, 1.15, 0.35)), c, opt({ shape = Enum.PartType.Ball, material = Enum.Material.Fabric, nocol = true }))
					end
				end
			end
		end
		-- pill mirror between the niches (white rim, warm light)
		local function pill(name, w, h, x, depth, color, mat)
			part(name, Vector3.new(depth, h - w, w), CFrame.new(x, F + 7.2, mz), color, opt({ material = mat, nocol = true }))
			for _, s in ipairs({ -1, 1 }) do
				part(name, Vector3.new(depth, w, w), CFrame.new(x, F + 7.2 + s * (h - w) / 2, mz), color, opt({ material = mat, nocol = true, shape = Enum.PartType.Cylinder }))
			end
		end
		-- the mirror fills the whole recess (4.4 x 10.4) and stands inside the
		-- pink wall, between the outer (white) wall and the pink face, a bit
		-- larger than the hole so its edges hide in the wall (user 2026-10-23)
		local MX = WX0 + 0.8
		pill("Mirror", 4.7, 8.7, MX - 0.06, 0.06, Color3.fromRGB(205, 215, 222), Enum.Material.Glass)
		do -- the live reflection (MirrorController); the wall clips it to the pill
			local c = Vector3.new(MX, F + 7.2, mz)
			local view = part("MirrorView", Vector3.new(4.7, 8.7, 0.05), CFrame.lookAt(c, c + Vector3.new(1, 0, 0)), Color3.new(1, 1, 1), opt({ nocol = true, transparency = 1 }))
			view.CanQuery = false
			CS:AddTag(view, "Mirror")
		end
		-- the glowing frame sits on the pink face around the recess, like the niches
		do
			local w, h, th, depth = 4.4 + 0.3, 8.4 + 0.3, 0.18, 0.3
			local r, straight = w / 2, h - w
			local c = Vector3.new(WX1 - 0.05, F + 7.2, mz)
			local along, out = Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)
			local NEON = Color3.fromRGB(255, 250, 240)
			for _, s in ipairs({ -1, 1 }) do
				part("MirrorGlow", Vector3.new(th, straight, depth), CFrame.fromMatrix(c + along * (s * (r - th / 2)), along, Vector3.yAxis), NEON, opt({ material = Enum.Material.Neon, nocol = true }))
			end
			for _, e in ipairs({ 1, -1 }) do
				local ce = c + Vector3.yAxis * (e * straight / 2)
				local N = 10
				for k = 0, N - 1 do
					local a0, a1 = math.pi * k / N, math.pi * (k + 1) / N
					local function at(a) return ce + along * (math.cos(a) * (r - th / 2)) + Vector3.yAxis * (e * math.sin(a) * (r - th / 2)) end
					local p0, p1 = at(a0), at(a1)
					local d = p1 - p0
					part("MirrorGlow", Vector3.new(d.Magnitude + th * 0.6, th, depth), CFrame.fromMatrix((p0 + p1) / 2, d.Unit, out:Cross(d.Unit)), NEON, opt({ material = Enum.Material.Neon, nocol = true }))
				end
			end
		end
		for _, d in ipairs(B:GetChildren()) do if d.Name == "Mirror" and d:IsA("BasePart") then d.Reflectance = 0.45 end end
	end

	---------------------------------------------------------------- south wall: arched make-up vanities between the capsule windows
	for _, vx in ipairs(VANITY_X) do
		-- each vanity stands in its arched recess in the thick pink wall
		local zi = SZ1 - 0.06 -- back of the recess
		local along, out = Vector3.new(1, 0, 0), Vector3.new(0, 0, -1)
		local c0 = Vector3.new(vx, F, zi)
		-- white tile arch backing with a gold rim and a warm glow
		local back = archPanel(c0, along, out, VW, VH, 0.12, Color3.fromRGB(250, 250, 248), B, Enum.Material.CeramicTiles)
		local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Back sl.Range = 7 sl.Brightness = 0.6 sl.Color = Color3.fromRGB(255, 225, 180) sl.Parent = back
		-- (no gold rim: user 2026-10-23)
		-- bulb mirror
		-- tall and low enough that short avatars see themselves (user: real mirror)
		local my, MH = F + 5.75, 3.7 -- bottom bulbs sit on the counter
		part("VanityMirrorFrame", Vector3.new(4.4, MH + 0.6, 0.15), CFrame.new(vx, my, zi - 0.2), Color3.new(1, 1, 1), opt({ nocol = true }))
		local mirror = part("VanityMirror", Vector3.new(3.8, MH, 0.06), CFrame.new(vx, my, zi - 0.3), Color3.fromRGB(205, 215, 222), opt({ nocol = true, material = Enum.Material.Glass }))
		mirror.Reflectance = 0.45
		-- the live reflection (MirrorController draws on its front face)
		local view = part("MirrorView", Vector3.new(3.8, MH, 0.05), CFrame.lookAt(Vector3.new(vx, my, zi - 0.36), Vector3.new(vx, my, zi - 1.36)), Color3.new(1, 1, 1), opt({ nocol = true, transparency = 1 }))
		view.CanQuery = false
		CS:AddTag(view, "Mirror")
		-- bulbs on the glass, inside its edge (user sketch: 4 top, 4 bottom,
		-- 2 down each side, none in the corners)
		local function bulb(x, y)
			part("VanityBulb", Vector3.new(0.34, 0.34, 0.34), CFrame.new(vx + x, my + y, zi - 0.6), Color3.fromRGB(255, 244, 214), opt({ shape = Enum.PartType.Ball, material = Enum.Material.Neon, nocol = true }))
		end
		for k = 0, 3 do
			for _, sy in ipairs({ -1, 1 }) do bulb(-1.35 + k * 0.9, sy * (MH / 2 - 0.35)) end
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, y in ipairs({ -0.5, 0.5 }) do bulb(sx * 1.55, y) end
		end
		ledSign("MakeupSign", Vector3.new(vx, my + MH / 2 + 1.3, zi - 0.42), Vector3.new(0, 0, -1), 2.8, 0.8, "MAKE UP")
		-- floating white counter with a drawer line
		box("VanityCounter", vx - 2.6, F + 3.1, zi - 1.6, vx + 2.6, F + 3.5, zi, Color3.fromRGB(252, 252, 250), o)
		box("VanityDrawer", vx - 2.5, F + 2.5, zi - 1.5, vx + 2.5, F + 3.1, zi, Color3.fromRGB(245, 245, 243), o)
		part("Hairdryer", Vector3.new(0.4, 0.5, 1), CFrame.new(vx + 1.6, F + 3.75, zi - 0.8), Color3.fromRGB(60, 60, 64), opt({ nocol = true }))
		part("Brush", Vector3.new(0.2, 0.2, 0.9), CFrame.new(vx - 1.4, F + 3.6, zi - 0.8), Color3.fromRGB(240, 160, 180), opt({ nocol = true }))
	end

	---------------------------------------------------------------- white oval table in the middle (user plan)
	do
		local tx, tz, len, w = 72.5, -75.5, 16, 6
		local y = F + 2.6
		box("OvalTableTop", tx - w / 2, y, tz - (len - w) / 2, tx + w / 2, y + 0.3, tz + (len - w) / 2, Color3.fromRGB(252, 252, 250), o)
		for _, s in ipairs({ -1, 1 }) do
			vcyl("OvalTableEnd", Vector3.new(tx, y, tz + s * (len - w) / 2), w, 0.3, Color3.fromRGB(252, 252, 250), o)
			vcyl("OvalTableLeg", Vector3.new(tx, F, tz + s * (len - w) / 2), 0.5, 2.6, GOLDT, opt({ material = Enum.Material.Foil }))
		end
	end

	label(box("ShopLabel", 78, U1 + 10, -74, 80, U1 + 11, -72, WHITE, opt({ transparency = 1, nocol = true })), "📸 오후네컷 포토 부스", Color3.fromRGB(255, 160, 200), 3)
end

-- first spawn: in front of exit 1 (players come up facing north)
if spawn then
	if not spawn:GetAttribute("OldPosition") then spawn:SetAttribute("OldPosition", spawn.Position) end
	-- the north-west corner square, looking across the junction (user 2026-10-23:
	-- pick a strategic spot): 오후네컷 and the club ahead-left, OH24 ahead-right,
	-- 광화문 far ahead, the beach behind; subway exit 3 right beside
	local p = Vector3.new(-62, 0, -70) -- (moved off the pocket park's new south walk, 2026-10-24)
	local sy = CURB - spawn.Size.Y / 2 -- its top level with the raised park paving (it stuck up as an invisible bump)
	local look = Vector3.new(0, sy, 0)
	-- TEMPORARY (user 2026-10-25): while the beach cafe interior is being
	-- built, spawn just inside its street door facing the room. Set
	-- CAFE_WORK_SPAWN = false when the cafe is done.
	local CAFE_WORK_SPAWN = false
	if CAFE_WORK_SPAWN then
		p = Vector3.new(-212, 0, 61)
		sy = 0.6 - spawn.Size.Y / 2 -- the cafe floor top
		look = Vector3.new(-260, sy, 61)
	else
		-- (user 2026-10-26) start on the sidewalk in front of 오후네컷, facing its
		-- poster window (west face at x 48.5; was the club door at z -186)
		p = Vector3.new(38, 0, -82)
		look = Vector3.new(48, sy, -82)
	end
	spawn.CFrame = CFrame.lookAt(Vector3.new(p.X, sy, p.Z), look)
	-- hidden in the paving (user 2026-10-23): no pad or logo showing
	spawn.Transparency = 1
	for _, d in ipairs(spawn:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end end
end
-- (user 2026-10-24, performance: docs/05_TECH/PERFORMANCE.md §9) small or flat
-- decoration casts no shadow (signs, letters, markings, pavers, props), and
-- nothing static here needs touch events except tagged parts and seats
do
	for _, d in ipairs(T:GetDescendants()) do
		if d:IsA("BasePart") then
			local s = d.Size
			local big = math.max(s.X, s.Y, s.Z)
			local flatOnGround = s.Y <= 0.35 and math.abs(d.CFrame.UpVector.Y) > 0.99 and d.Position.Y < 1.5
			if d.CastShadow and (big <= 4 or flatOnGround or d.Transparency >= 1) then d.CastShadow = false end
			if d.CanTouch and d.Anchored and not d:IsA("Seat") and not d:IsA("VehicleSeat") and #CS:GetTags(d) == 0 then d.CanTouch = false end
		end
	end
end
saveRegistry()
T.Parent = workspace
-- wall uplight strips sit on whatever ground is under them, only a hair
-- above it (user 2026-10-23: hidden by day, still glowing at night)
do
	local strips = {}
	for _, d in ipairs(T:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "WallUplight" and d.Position.Y < 3 then table.insert(strips, d) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = strips
	for _, s in ipairs(strips) do
		local hit = workspace:Raycast(Vector3.new(s.Position.X, 1.6, s.Position.Z), Vector3.new(0, -6, 0), params)
		if hit then s.CFrame = s.CFrame + Vector3.new(0, hit.Position.Y + s.Size.Y / 2 + 0.002 - s.Position.Y, 0) end
	end
end
return "applied v7 (강남 사거리, 광안리, 광화문, 놀이공원 정문), MODE=revert to undo"
