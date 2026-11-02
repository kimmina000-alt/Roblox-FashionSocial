--!nocheck
-- Club annex (user plan 2026-11-03, D-821), run in Edit mode LAST in the
-- layout chain (after park_raise). Everything in world coordinates; running it
-- again gives the same result (the annex is rebuilt, the cuts and moves are
-- absolute).
--   1. the VIP stair leaves the entrance corridor: a stair hall of its own
--      outside the club's east wall (x 190..257, z -292..-255, roof 60),
--      built like the inside (dark walls, graffiti, red VIP steps): the VIP
--      glass gate stands in the corridor's end wall, the flight climbs east to
--      a 20-deep landing, a walkway turns back west to a door onto the north
--      VIP lounge (2F); red portals the size of the doors at the flight's top
--      and the lounge door. The old stairwell over the corridor becomes VIP
--      floor (all VIP floors 30 % see-through, D-824), the corridor gets its
--      ceiling, a light line along the wall where the stair stood.
--   2. a bright locker room (dressing room) under the lot north of the club
--      (x 131.6..231, z -365..-313, at the corridor's level -24), reached by a
--      short dark passage north from the corridor (x 132.5..146.5) with the
--      door at its end (D-824; dark glass auto door, D-827): lockers drawn with the user's locker photo
--      up to the ceiling, light panels and plants only. One open room.
--   3. the ground and the play-area walls make room for both (the boundary
--      walls over the locker room start at street level: nobody walks there).
-- The lift at the corridor's end, the wider hall door (D-824) and the boundary
-- round the stair hall are in build_main_social_graybox / build_hongdae_layout.
local CS = game:GetService("CollectionService")
local log = {}
local G = workspace:FindFirstChild("Graybox_MainSocial")
local club = G and G:FindFirstChild("02_Club")
local L = workspace:FindFirstChild("Hongdae_Layout")
assert(club and L, "run the layout chain first")

local F, V = -24, 20 -- hall floor, VIP floor
local WALL_C = Color3.fromRGB(26, 26, 29)
local MARBLE_C = Color3.fromRGB(20, 20, 24)
local STEP_C = Color3.fromRGB(28, 26, 34)
local VIP_RED = Color3.fromRGB(255, 40, 70)
local DARK = Color3.fromRGB(25, 22, 35)
local GRAFFITI = "rbxassetid://93792464281347"

local old = L:FindFirstChild("ClubAnnex")
if old then old:Destroy() end
local A = Instance.new("Model")
A.Name = "ClubAnnex"

local function box(name, x0, y0, z0, x1, y1, z1, color, parent, opt)
	local p = Instance.new((opt and opt.class) or "Part")
	p.Name = name
	p.Anchored = true
	local lx, hx = math.min(x0, x1), math.max(x0, x1)
	local ly, hy = math.min(y0, y1), math.max(y0, y1)
	local lz, hz = math.min(z0, z1), math.max(z0, z1)
	p.Size = Vector3.new(hx - lx, hy - ly, hz - lz)
	p.CFrame = CFrame.new((lx + hx) / 2, (ly + hy) / 2, (lz + hz) / 2)
	p.Color = color
	p.Material = (opt and opt.mat) or Enum.Material.SmoothPlastic
	p.Transparency = (opt and opt.t) or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt and opt.ghost then p.CanCollide = false p.CanTouch = false p.CanQuery = false p.CastShadow = false end
	if opt and opt.nocol then p.CanCollide = false p.CanTouch = false end
	p.Parent = parent
	return p
end
local NEON = function(extra) local o = { mat = Enum.Material.Neon, ghost = true } for k, v in pairs(extra or {}) do o[k] = v end return o end
local function graffiti(parent, x0, y0, z0, x1, y1, z1, face)
	local p = box("GraffitiWall", x0, y0, z0, x1, y1, z1, Color3.new(0, 0, 0), parent, { t = 1, ghost = true })
	local tx = Instance.new("Texture")
	tx.Texture = GRAFFITI tx.Face = face tx.StudsPerTileU = 34 tx.StudsPerTileV = 17 tx.Transparency = 0.15
	tx.Parent = p
	return p
end
local function text(part, face, str, color, font, ppsOrNil)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.Brightness = 2
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppsOrNil or 40
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBlack
	l.TextColor3 = color
	l.Text = str
	l.Parent = g
	return l
end

-- world AABB of a part
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local ex = Vector3.new(
		math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
		math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
		math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z) / 2
	return cf.Position - ex, cf.Position + ex
end

-- Cuts the box (world min/max) out of a block part, in the part's own axes
-- (so textures and faces keep their sides): up to 6 pieces stay. Parts inside
-- the box go. Meshes and unions are left alone (listed).
local skipped = {}
local function carve(p: BasePart, hmin: Vector3, hmax: Vector3): boolean
	if p:IsDescendantOf(A) or p.Name == "BoundaryWall" or p:FindFirstAncestorWhichIsA("Model") and game:GetService("Players"):GetPlayerFromCharacter(p:FindFirstAncestorWhichIsA("Model")) then return false end
	-- (zone and region boxes are areas, not walls: never cut)
	if p.Name:match("^ClubZone") or CS:HasTag(p, "ClubInterior") or CS:HasTag(p, "ClubRegion") or CS:HasTag(p, "ClubGate") then return false end
	if not (p.ClassName == "Part") or p.Shape ~= Enum.PartType.Block then
		table.insert(skipped, p:GetFullName())
		return false
	end
	local inv = p.CFrame:Inverse()
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, cx in ipairs({ hmin.X, hmax.X }) do for _, cy in ipairs({ hmin.Y, hmax.Y }) do for _, cz in ipairs({ hmin.Z, hmax.Z }) do
		local q = inv * Vector3.new(cx, cy, cz)
		lo = Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z))
		hi = Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z))
	end end end
	local h = p.Size / 2
	lo = Vector3.new(math.max(lo.X, -h.X), math.max(lo.Y, -h.Y), math.max(lo.Z, -h.Z))
	hi = Vector3.new(math.min(hi.X, h.X), math.min(hi.Y, h.Y), math.min(hi.Z, h.Z))
	if hi.X - lo.X < 0.01 or hi.Y - lo.Y < 0.01 or hi.Z - lo.Z < 0.01 then return false end
	local pieces = {
		{ Vector3.new(-h.X, -h.Y, -h.Z), Vector3.new(lo.X, h.Y, h.Z) },
		{ Vector3.new(hi.X, -h.Y, -h.Z), Vector3.new(h.X, h.Y, h.Z) },
		{ Vector3.new(lo.X, -h.Y, -h.Z), Vector3.new(hi.X, lo.Y, h.Z) },
		{ Vector3.new(lo.X, hi.Y, -h.Z), Vector3.new(hi.X, h.Y, h.Z) },
		{ Vector3.new(lo.X, lo.Y, -h.Z), Vector3.new(hi.X, hi.Y, lo.Z) },
		{ Vector3.new(lo.X, lo.Y, hi.Z), Vector3.new(hi.X, hi.Y, h.Z) },
	}
	for _, pc in ipairs(pieces) do
		local size = pc[2] - pc[1]
		if size.X > 0.02 and size.Y > 0.02 and size.Z > 0.02 then
			local c = p:Clone()
			c.Size = size
			c.CFrame = p.CFrame * CFrame.new((pc[1] + pc[2]) / 2)
			c:SetAttribute("Annex1103Cut", true)
			c.Parent = p.Parent
		end
	end
	p:Destroy()
	return true
end
-- every part touching the hole (world box) is cut
-- (only: cut just the parts it accepts)
local function hole(label, x0, y0, z0, x1, y1, z1, only)
	local hmin, hmax = Vector3.new(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1)), Vector3.new(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1))
	local n = 0
	-- (every part, also the CanQuery-off graffiti panels and light lines that
	-- GetPartBoundsInBox never returns)
	local e = 0.01
	local parts = {}
	for _, root in ipairs({ club, L }) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") then
				local a, b = aabb(p)
				if b.X > hmin.X + e and a.X < hmax.X - e and b.Y > hmin.Y + e and a.Y < hmax.Y - e and b.Z > hmin.Z + e and a.Z < hmax.Z - e then
					table.insert(parts, p)
				end
			end
		end
	end
	for _, p in ipairs(parts) do
		if p.Parent and (not only or only(p)) and carve(p, hmin, hmax) then n += 1 end
	end
	table.insert(log, label .. ": cut " .. n)
end

---------------------------------------------------------------- 1. old VIP stair out
do
	local n = 0
	for _, p in ipairs(club:GetDescendants()) do
		if not p:IsA("BasePart") then continue end
		local a, b = aabb(p)
		local inStairwell = a.X >= 134.5 and b.X <= 188.5 and a.Z >= -290.5 and b.Z <= -273.5
		if p.Name == "VIP_Stair" or p.Name == "VIP_StairNeon" or p.Name == "VIP_StairRamp" or p.Name == "VIP_LandingNeon"
			or p.Name == "VIP_Rail_StairE" or p.Name == "VIP_Rail_StairS" or p.Name == "VIP_GateWall"
			or (p.Name == "StairRiser" and a.X > 130 and inStairwell)
			or (p.Name == "VIP_RailBlock" and inStairwell and a.Y >= 19.5)
			or (p.Name == "GraffitiWall" and math.abs((a.X + b.X) / 2 - 135.2) < 1.2 and a.Z >= -290.5 and b.Z <= -273.5) then
			p:Destroy()
			n += 1
		end
	end
	table.insert(log, "old VIP stair parts removed " .. n)
	-- the corridor gets its ceiling and the 2F its floor over the old stairwell
	if not club:FindFirstChild("Corridor_CeilingEast") then
		local ceil = club:FindFirstChild("Corridor_Ceiling")
		local floor = club:FindFirstChild("VIP_Floor_W2")
		if ceil and floor then
			local c = ceil:Clone()
			c.Name = "Corridor_CeilingEast"
			c.Size = Vector3.new(179.5 - 135, 0.4, 16)
			c.CFrame = CFrame.new((135 + 179.5) / 2, 19.2, -282)
			c.Parent = club
			local f = floor:Clone()
			f.Name = "VIP_Floor_Stairwell"
			f.Size = Vector3.new(179.5 - 135, 0.6, 16)
			f.CFrame = CFrame.new((135 + 179.5) / 2, 19.7, -282)
			f.Parent = club
		end
	end
	-- the VIP gate into the corridor's end wall (x 189), the stair region to the new hall
	local gate = club:FindFirstChild("VIP_Gate")
	if gate then
		local dx = 189 - gate.Position.X
		gate.CFrame = gate.CFrame + Vector3.new(dx, 0, -282.5 - gate.Position.Z)
		for _, nn in ipairs(club:GetChildren()) do
			if nn:IsA("BasePart") and nn.Name == "VIP_GateNeon" and nn.Position.X < 186 then
				nn.CFrame = nn.CFrame + Vector3.new(dx - 0.7, 0, 0) -- (on the corridor face of the wall)
			end
		end
	end
	local region = club:FindFirstChild("VIP_StairRegion")
	if region then
		region.Size = Vector3.new(56, 59, 33)
		region.CFrame = CFrame.new(218, -23 + 59 / 2, -273.5)
		region:SetAttribute("Exit", Vector3.new(180, F + 3, -282.5))
	end
	for _, lb in ipairs(club:GetChildren()) do
		local bb = lb:FindFirstChildWhichIsA("BillboardGui")
		local tl = bb and bb:FindFirstChildWhichIsA("TextLabel")
		if lb:IsA("BasePart") and tl and string.find(tl.Text, "VIP 2층", 1, true) then lb.CFrame = CFrame.new(184, F + 17, -282.5) end
	end
	-- (D-824, user) the old "VIP →" neon sign on the 2F landing goes
	for _, p in ipairs(club:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "VIP_WaySign" or p.Name == "VIP_WayArrow") then p:Destroy() end
	end
	-- (D-824, user: a light line where the old stair stood) the 2F floor's
	-- wall-base line along the corridor's north wall, like the other walls'
	local edge = club:FindFirstChild("VIP_FloorEdgeLight")
	if edge and not club:FindFirstChild("VIP_FloorEdgeLight_Old") then
		local e = edge:Clone()
		e.Name = "VIP_FloorEdgeLight_Old"
		e.Size = Vector3.new(179.6 - 67, 0.2, 0.2)
		e.CFrame = CFrame.new((67 + 179.6) / 2, V + 0.1, -289.7)
		e.Parent = club
	end
	-- (D-824 30 %, D-827 80 %, user) the VIP floors see-through
	for _, p in ipairs(club:GetChildren()) do
		if p:IsA("BasePart") and p.Name:match("^VIP_Floor_") then p.Transparency = 0.8 end
	end
	-- (D-827, user) a light frame round the street door, seen from inside the club
	do
		local LC = Color3.fromRGB(255, 250, 235)
		box("StreetDoorLight", 50.02, 0, -218.3, 50.22, 18.2, -218, LC, A, NEON())
		box("StreetDoorLight", 50.02, 0, -202, 50.22, 18.2, -201.7, LC, A, NEON())
		box("StreetDoorLight", 50.02, 18, -218.3, 50.22, 18.2, -201.7, LC, A, NEON())
	end
end

---------------------------------------------------------------- 2. holes
-- (the gate stands in the lower one: its neon is not cut)
local function notGate(p) return p.Name ~= "VIP_GateNeon" end
local function groundOnly(p) return p.Name == "Ground" or p.Name == "Sidewalk" end
-- the locker room (D-824, user plan): a short passage north from the
-- corridor's wall, the room at its end
local LX0, LX1, LZ0, LZ1 = 131.6, 231, -365, -313 -- the room inside
local PX0, PX1 = 132.5, 146.5 -- the passage inside (z LZ1 .. -292)
local SX1 = 191 + (V - F) -- the top step's east edge (235)
local HX1 = 255 -- the stair hall's inside east end (the landing 20 deep, D-824)
local HTOP = 60 -- its roof (36 → 60, D-824: it felt low)
-- (D-827) the doors go right down to the floor (a 0.01 strip of wall stood on
-- it and looked like a crack), the floors are not cut
local function wallOnly(p) return p.Name ~= "VIP_GateNeon" and p.Name ~= "Floor" and not p.Name:match("^VIP_Floor_") end
local UDH = 20 -- the door to the lounge, 14 → 20 high (D-827)
hole("stair hall door (corridor end)", 187.8, F - 0.5, -290, 190.4, F + 21, -275, wallOnly)
-- (from x 187.4: the lounge's floor-edge light line is cut across the doorway too, D-827)
hole("stair hall door (2F lounge)", 187.4, V + 0.01, -273, 190.4, V + UDH, -259, wallOnly)
hole("locker passage (corridor wall)", PX0, F - 0.5, -292.4, PX1, F + 21, -289.9, wallOnly)
hole("ground: stair hall", 188.5, -16, -292.5, HX1 + 2.5, 0.6, -254.5, groundOnly)
hole("ground: locker room", LX0 - 2.5, -16, LZ0 - 2.5, LX1 + 2.5, 0, -289.9, groundOnly) -- (to -289.9: a strip of ground showed at the passage, D-827)

---------------------------------------------------------------- 3. VIP stair hall
do
	local H = Instance.new("Model")
	H.Name = "VipStairHall"
	H.Parent = A
	local Z0, Z1 = -290, -257 -- inside
	local X1, TOPY = HX1, HTOP
	local W = { mat = Enum.Material.SmoothPlastic }
	local LEMON = Color3.fromRGB(255, 250, 175)
	-- shell: floor, three walls, roof (the club's east wall is the fourth)
	local fl = box("Floor", 187.8, F - 1, Z0, X1, F, Z1, MARBLE_C, H, { mat = Enum.Material.Marble }) -- (from 187.8: under the gate in the wall too, D-827)
	fl.Reflectance = 0.15
	box("Wall_Nth", 189, F, -292, X1 + 2, TOPY + 1, Z0, WALL_C, H, W)
	box("Wall_Sth", 189, F, Z1, X1 + 2, TOPY + 1, -255, WALL_C, H, W)
	box("Wall_End", X1, F, Z0, X1 + 2, TOPY + 1, Z1, WALL_C, H, W)
	box("Roof", 189, TOPY, Z0, X1, TOPY + 1, Z1, DARK, H)
	-- lane A: the flight east along the corridor's line, 44 steps of 1
	local AZ0, AZ1 = Z0, -275.5
	local SX0 = 191
	for j = 1, V - F do
		local x0 = SX0 + (j - 1)
		box("VIP_Stair", x0, F, AZ0, x0 + 1, F + j, AZ1, STEP_C, H, { nocol = true })
		box("VIP_StairNeon", x0, F + j, AZ0 + 0.2, x0 + 0.3, F + j + 0.08, AZ1 - 0.2, VIP_RED, H, NEON())
		local r = box("StairRiser", x0 - 0.04, F + j - 1, AZ0 + 0.2, x0, F + j, AZ1 - 0.2, STEP_C, H, { ghost = true })
		local g = Instance.new("SurfaceGui") g.Face = Enum.NormalId.Left g.LightInfluence = 0 g.Brightness = 2
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 24 g.Parent = r
		local l = Instance.new("TextLabel") l.Size = UDim2.fromScale(1, 1) l.BackgroundTransparency = 1 l.TextScaled = true
		l.Font = Enum.Font.GothamBlack l.TextColor3 = VIP_RED l.Text = string.rep("▼", 12) l.Parent = g
	end
	-- the slope people actually walk on (a wedge rising east)
	do
		local c = Vector3.new((SX0 + SX1) / 2, (F + V) / 2, (AZ0 + AZ1) / 2)
		local w = Instance.new("WedgePart")
		w.Name = "VIP_StairRamp" w.Anchored = true w.Transparency = 1 w.CastShadow = false
		w.Size = Vector3.new(AZ1 - AZ0, V - F, SX1 - SX0)
		w.CFrame = CFrame.lookAt(c, c + Vector3.new(-1, 0, 0))
		w.Parent = H
	end
	-- landing at the top (20 deep, D-824), all across, and lane B back west at the 2F level
	local land = box("VIP_Landing", SX1, V - 1, Z0, X1, V, Z1, MARBLE_C, H, { mat = Enum.Material.Marble })
	land.Reflectance = 0.15
	box("VIP_Walk", 189, V - 1, -275.5, SX1, V, Z1, MARBLE_C, H, { mat = Enum.Material.Marble })
	box("WalkFill", 189, F, -275.5, SX1, V - 1, Z1, WALL_C, H, W) -- (solid under the walkway)
	-- glass rail along the walkway over the flight, with the invisible block above it
	box("VIP_Rail", 190, V, -276, SX1, V + 6, -275.5, Color3.fromRGB(200, 230, 255), H, { t = 0.6 })
	box("VIP_RailBlock", 190, V, -276, SX1, V + 12, -275.5, Color3.new(1, 1, 1), H, { t = 1 }).CastShadow = false
	box("VIP_RailNeon", 190, V - 0.65, -275.6, SX1, V - 0.35, -275.45, LEMON, H, NEON())
	-- light lines: the flight's top edge in red, round the landing and the walkway at the wall feet
	box("VIP_FloorLine", SX1, V, Z0, SX1 + 0.3, V + 0.08, AZ1, VIP_RED, H, NEON())
	box("FloorLED", SX1, V, Z0, X1, V + 0.25, Z0 + 0.12, LEMON, H, NEON())
	box("FloorLED", X1 - 0.12, V, Z0, X1, V + 0.25, Z1, LEMON, H, NEON())
	box("FloorLED", 189, V, Z1 - 0.12, X1, V + 0.25, Z1, LEMON, H, NEON())
	box("FloorLED", 190, F, Z0, 191, F + 0.25, Z0 + 0.12, LEMON, H, NEON())
	-- (D-824, user: red light lines the size of the stair door) a red portal
	-- where the flight reaches the landing, and round the door to the lounge
	local function portal(x, za, zb, y0, h)
		box("VIP_Portal", x - 0.15, y0, za, x + 0.15, y0 + h, za + 0.3, VIP_RED, H, NEON())
		box("VIP_Portal", x - 0.15, y0, zb - 0.3, x + 0.15, y0 + h, zb, VIP_RED, H, NEON())
		box("VIP_Portal", x - 0.15, y0 + h - 0.3, za, x + 0.15, y0 + h, zb, VIP_RED, H, NEON())
	end
	-- (the one at the flight's top went again, D-827, user)
	portal(190.6, -273, -259, V, UDH)
	-- graffiti on the inside walls (as in the corridor)
	graffiti(H, 189, F, Z0, X1, TOPY, Z0 + 0.05, Enum.NormalId.Back)
	graffiti(H, 189, F, Z1 - 0.05, X1, TOPY, Z1, Enum.NormalId.Front)
	graffiti(H, X1 - 0.05, F, Z0, X1, TOPY, Z1, Enum.NormalId.Left)
	graffiti(H, 189, F, -275.55, SX1, V - 1, -275.5, Enum.NormalId.Front) -- (the face under the walkway, seen from the flight)
	-- lights: a white strip along the roof over each lane, soft warm lights
	for _, lane in ipairs({ { (AZ0 + AZ1) / 2, 190, X1 }, { (-275.5 + Z1) / 2, 190, X1 } }) do
		local s = box("CeilingStrip", lane[2], TOPY - 0.2, lane[1] - 0.6, lane[3], TOPY, lane[1] + 0.6, Color3.fromRGB(255, 240, 220), H, NEON())
		for x = lane[2] + 6, lane[3] - 4, 12 do
			local at = Instance.new("Attachment") at.WorldPosition = Vector3.new(x, TOPY - 0.6, lane[1]) at.Parent = s
			local pl = Instance.new("PointLight") pl.Range = 26 pl.Brightness = 0.9 pl.Color = Color3.fromRGB(255, 225, 200) pl.Shadows = false pl.Parent = at
		end
	end
	-- outside: black cladding like the club front above the ground
	local BLACK = Color3.fromRGB(26, 27, 30)
	box("Cladding", 189, 0, -292.2, X1 + 2.2, TOPY + 1, -292, BLACK, H, { mat = Enum.Material.Metal })
	box("Cladding", 189, 0, -255, X1 + 2.2, TOPY + 1, -254.8, BLACK, H, { mat = Enum.Material.Metal })
	box("Cladding", X1 + 2, 0, -292.2, X1 + 2.2, TOPY + 1, -254.8, BLACK, H, { mat = Enum.Material.Metal })
	box("CapBand", 189, TOPY + 0.6, -292.4, X1 + 2.4, TOPY + 1.4, -254.6, Color3.fromRGB(40, 42, 46), H, { mat = Enum.Material.Metal })
	-- quiet music here, like the entrance stairs (a copy of that zone box)
	local zs = club:FindFirstChild("ClubZone_Stairs")
	if zs then
		local zc = zs:Clone()
		zc.Name = "ClubZone_VipStairs"
		zc.Size = Vector3.new(X1 - 189, TOPY - F, Z1 - Z0)
		zc.CFrame = CFrame.new((189 + X1) / 2, (F + TOPY) / 2, (Z0 + Z1) / 2)
		zc.Parent = H
	end
	-- the gate's red frame on the hall side too
	box("VIP_GateNeon", 190, F, -290, 190.4, F + 21, -289.6, VIP_RED, H, NEON())
	box("VIP_GateNeon", 190, F, -275.4, 190.4, F + 21, -275, VIP_RED, H, NEON())
	box("VIP_GateNeon", 190, F + 20.6, -290, 190.4, F + 21, -275, VIP_RED, H, NEON())
	-- the VIP region over the whole hall
	local region = club:FindFirstChild("VIP_StairRegion")
	if region then
		region.Size = Vector3.new(X1 - 190, TOPY - F + 1, Z1 - Z0)
		region.CFrame = CFrame.new((190 + X1) / 2, (F + 1 + TOPY + 2) / 2, (Z0 + Z1) / 2)
	end
	table.insert(log, "stair hall parts " .. #H:GetDescendants())
end

---------------------------------------------------------------- 4. locker room
do
	local R = Instance.new("Model")
	R.Name = "LockerRoom"
	R.Parent = A
	local X0, X1, Z0, Z1 = LX0, LX1, LZ0, LZ1
	local TOP = -3
	local WHITE = Color3.fromRGB(246, 244, 240)
	local PLASTER = { mat = Enum.Material.Plaster }
	local wood = box("Floor", X0 - 1.6, F - 1, Z0 - 1.6, X1 + 1.6, F, Z1, Color3.fromRGB(214, 190, 156), R, { mat = Enum.Material.WoodPlanks })
	wood.Reflectance = 0.05
	box("Ceiling", X0 - 1.6, TOP, Z0 - 1.6, X1 + 1.6, 0, Z1 + 1.6, WHITE, R)
	box("Wall_W", X0 - 1.6, F, Z0 - 1.6, X0, TOP, Z1 + 1.6, WHITE, R, PLASTER)
	box("Wall_E", X1, F, Z0 - 1.6, X1 + 1.6, TOP, Z1 + 1.6, WHITE, R, PLASTER)
	box("Wall_N", X0 - 1.6, F, Z0 - 1.6, X1 + 1.6, TOP, Z0, WHITE, R, PLASTER)
	-- the south wall with the doorway from the passage, open up to the ceiling (D-827)
	box("Wall_S", PX1, F, Z1, X1 + 1.6, TOP, Z1 + 1.6, WHITE, R, PLASTER)
	box("Wall_S", X0 - 1.6, F, Z1, PX0, TOP, Z1 + 1.6, WHITE, R, PLASTER)
	-- THE PASSAGE from the corridor (D-824, user plan): dark like the club,
	-- graffiti, the floor lines joining the corridor's (no ceiling light, D-827)
	do
		local P = Instance.new("Model")
		P.Name = "Passage"
		P.Parent = R
		local pz0, pz1 = Z1 + 1.6, -289.9 -- (on through the club wall's thickness: no gap in the floor, D-827)
		local f = box("Floor", PX0 - 1, F - 1, pz0, PX1 + 1, F, pz1, MARBLE_C, P, { mat = Enum.Material.Marble })
		f.Reflectance = 0.15
		box("Wall_W", PX0 - 1, F, pz0, PX0, TOP, -292, WALL_C, P)
		box("Wall_E", PX1, F, pz0, PX1 + 1, TOP, -292, WALL_C, P)
		box("Ceiling", PX0 - 1, TOP, pz0, PX1 + 1, 0, -292, DARK, P)
		graffiti(P, PX0, F, pz0, PX0 + 0.05, TOP, -292, Enum.NormalId.Right)
		graffiti(P, PX1 - 0.05, F, pz0, PX1, TOP, -292, Enum.NormalId.Left)
		for _, x in ipairs({ PX0 + 0.06, PX1 - 0.06 }) do
			box("FloorLED", x - 0.06, F, pz0, x + 0.06, F + 0.25, pz1 + 0.01, Color3.fromRGB(255, 250, 175), P, NEON())
		end
	end
	-- light panels: a 4 × 2 grid, bright
	for i = 0, 3 do
		for k = 0, 1 do
			local cx = X0 + (X1 - X0) * (i + 0.5) / 4
			local cz = Z0 + (Z1 - Z0) * (k + 0.5) / 2
			local p = box("LightPanel", cx - 5, TOP - 0.15, cz - 5, cx + 5, TOP, cz + 5, Color3.fromRGB(255, 252, 245), R, NEON())
			local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 24 sl.Brightness = 2.2 sl.Angle = 120
			sl.Color = Color3.fromRGB(255, 248, 238) sl.Shadows = false sl.Parent = p
		end
	end
	-- LOCKERS on the north and east walls, nearly to the ceiling (D-827): the
	-- user's locker photo (docs/04_ART/references/locker_ref_1103.png, 3 × 2
	-- doors) tiled along them, two photos high
	local LOCKER_IMG = "rbxassetid://117301508454056"
	local LH = TOP - 0.7 - F -- 20.3
	local function lockers(x0, z0, x1, z1, face)
		local b = box("Lockers", x0, F, z0, x1, F + LH, z1, Color3.fromRGB(238, 238, 240), R, { mat = Enum.Material.Metal })
		local tx = Instance.new("Texture")
		tx.Texture = LOCKER_IMG tx.Face = face
		tx.StudsPerTileV = LH / 2 tx.StudsPerTileU = LH / 2 * 259 / 548
		tx.Parent = b
		box("LockerTop", x0, F + LH, z0, x1, F + LH + 0.3, z1, Color3.fromRGB(220, 220, 224), R, { mat = Enum.Material.Metal })
		return b
	end
	lockers(X0 + 4, Z0, X1 - 4, Z0 + 1.8, Enum.NormalId.Back)
	lockers(X1 - 1.8, Z0 + 4, X1, Z1 - 4, Enum.NormalId.Left)
	-- (no mirrors, vanity, stools, rug, floor lines or name over the lockers:
	-- all taken out, D-827, user) a few plants
	local plant = game:GetService("ServerStorage"):FindFirstChild("ArtAssets") and game:GetService("ServerStorage").ArtAssets:FindFirstChild("CafePotPlant")
	if plant then
		for _, at in ipairs({ Vector3.new(X0 + 2, F, Z0 + 2), Vector3.new(X1 - 3, F, Z0 + 3), Vector3.new(X1 - 3, F, Z1 - 3) }) do
			local m = plant:Clone()
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
			end
			local cf, size = m:GetBoundingBox()
			m:PivotTo(CFrame.new(at.X, at.Y + size.Y / 2, at.Z) * cf:ToObjectSpace(m:GetPivot()))
			m.Parent = R
		end
	end
	-- the doorway: a white light frame on both faces, up to the ceiling
	for _, zf in ipairs({ Z1 - 0.05, Z1 + 1.65 }) do
		box("DoorFrameLight", PX0, F, zf - 0.15, PX0 + 0.3, TOP, zf + 0.15, Color3.fromRGB(255, 250, 235), R, NEON())
		box("DoorFrameLight", PX1 - 0.3, F, zf - 0.15, PX1, TOP, zf + 0.15, Color3.fromRGB(255, 250, 235), R, NEON())
		box("DoorFrameLight", PX0, TOP - 0.3, zf - 0.15, PX1, TOP, zf + 0.15, Color3.fromRGB(255, 250, 235), R, NEON())
	end
	-- (D-827, user) the door: two dark grey see-through glass leaves that
	-- slide apart into the walls (AutoDoorController), so the bright room
	-- shows only dimly from outside
	do
		local door = Instance.new("Model")
		door.Name = "AutoDoor"
		door:SetAttribute("Range", 9)
		local mid = (PX0 + PX1) / 2
		local half = (PX1 - PX0) / 2
		local zc = Z1 + 0.8
		for _, s in ipairs({ -1, 1 }) do
			local leaf = box("DoorPanel", mid + s * half, F, zc - 0.15, mid, TOP, zc + 0.15, Color3.fromRGB(48, 48, 54), door, { mat = Enum.Material.Glass, t = 0.35 })
			leaf.Reflectance = 0.1
			leaf:SetAttribute("Slide", Vector3.new(s * (half - 0.2), 0, 0))
		end
		door.WorldPivot = CFrame.new(mid, F + 4, zc)
		door.Parent = R
		CS:AddTag(door, "AutoDoor")
	end
	-- a sign in a box on the corridor wall left of the passage, with an arrow (D-827)
	do
		local x0, x1, y0, y1, zf = PX0 - 15, PX0 - 2, F + 9, F + 13, -289.9
		local plate = box("LockerWaySign", x0, y0, zf, x1, y1, zf + 0.12, Color3.fromRGB(20, 20, 24), R)
		local LC = Color3.fromRGB(255, 250, 235)
		box("LockerWayFrame", x0, y1 - 0.15, zf + 0.12, x1, y1, zf + 0.2, LC, R, NEON())
		box("LockerWayFrame", x0, y0, zf + 0.12, x1, y0 + 0.15, zf + 0.2, LC, R, NEON())
		box("LockerWayFrame", x0, y0, zf + 0.12, x0 + 0.15, y1, zf + 0.2, LC, R, NEON())
		box("LockerWayFrame", x1 - 0.15, y0, zf + 0.12, x1, y1, zf + 0.2, LC, R, NEON())
		local l = text(plate, Enum.NormalId.Back, "LOCKER ROOM  →", Color3.fromRGB(255, 255, 255))
		l.Size = UDim2.fromScale(0.86, 0.6)
		l.Position = UDim2.fromScale(0.07, 0.2)
	end
	table.insert(log, "locker room parts " .. #R:GetDescendants())
end

---------------------------------------------------------------- 5. boundary over the locker room
do
	local B = L:FindFirstChild("MapBoundary")
	local n = 0
	for _, w in ipairs(B and B:GetChildren() or {}) do
		if w:IsA("BasePart") and w.Name == "BoundaryWall" then
			local a, b = aabb(w)
			if b.X > LX0 - 3 and a.X < LX1 + 3 and b.Z > LZ0 - 3 and a.Z < -290 and a.Y < 0 then
				local top = b.Y
				w.Size = Vector3.new(w.Size.X, top, w.Size.Z)
				w.CFrame = w.CFrame + Vector3.new(0, (top / 2) - w.Position.Y, 0)
				n += 1
			end
		end
	end
	table.insert(log, "boundary walls lifted over the locker room " .. n)
end

A.Parent = L
if #skipped > 0 then table.insert(log, "not cut (mesh/union): " .. table.concat(skipped, ", ")) end
local msg = "[club_locker_1103] " .. table.concat(log, " | ")
print(msg)
return msg
