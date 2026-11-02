--!nocheck
-- Club annex (user plan 2026-11-03, D-821), run in Edit mode LAST in the
-- layout chain (after park_raise). Everything in world coordinates; running it
-- again gives the same result (the annex is rebuilt, the cuts and moves are
-- absolute).
--   1. the VIP stair leaves the entrance corridor: a stair hall of its own
--      outside the club's east wall (x 190..248, z -292..-255), built like the
--      inside (dark walls, graffiti, red VIP steps): the VIP glass gate stands
--      in the corridor's end wall, the flight climbs east, a landing turns
--      back west to a door onto the north VIP lounge (2F). The old stairwell
--      over the corridor becomes VIP floor; the corridor gets its ceiling.
--   2. a bright locker room (dressing room) under the lot north of the club
--      (x 136..249, z -382..-292, at the corridor's level -24), its door in the
--      corridor's north wall (x 138..158) where the VIP stair began: lockers,
--      full-length live mirrors (tag "Mirror"), Hollywood vanity mirrors,
--      benches, light panels. One open room (no small closed rooms: content rules).
--   3. the ground and the play-area walls make room for both (the boundary
--      walls over the locker room start at street level: nobody walks there).
-- The wider street door (16 → 32), the lift at the corridor's end and the
-- boundary round the stair hall are in build_main_social_graybox /
-- build_hongdae_layout (D-821).
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
end

---------------------------------------------------------------- 2. holes
-- (the gate stands in the lower one: its neon is not cut)
local function notGate(p) return p.Name ~= "VIP_GateNeon" end
local function groundOnly(p) return p.Name == "Ground" or p.Name == "Sidewalk" end
hole("stair hall door (corridor end)", 187.8, F + 0.01, -290, 190.4, F + 21, -275, notGate)
hole("stair hall door (2F lounge)", 187.8, V + 0.01, -273, 190.4, V + 14, -259)
hole("locker room door", 138, F + 0.01, -292.4, 158, F + 18, -289.9)
hole("ground: stair hall", 188.5, -16, -292.5, 249, 0.6, -254.5, groundOnly)
hole("ground: locker room", 136, -16, -382.5, 249.5, 0, -292, groundOnly)

---------------------------------------------------------------- 3. VIP stair hall
do
	local H = Instance.new("Model")
	H.Name = "VipStairHall"
	H.Parent = A
	local X0, X1, Z0, Z1 = 190, 246, -290, -257 -- inside
	local TOPY = 36
	local W = { mat = Enum.Material.SmoothPlastic }
	-- shell: floor, three walls, roof (the club's east wall is the fourth)
	local fl = box("Floor", 189, F - 1, Z0, X1, F, Z1, MARBLE_C, H, { mat = Enum.Material.Marble })
	fl.Reflectance = 0.15
	box("Wall_Nth", 189, F, -292, 248, TOPY + 1, Z0, WALL_C, H, W)
	box("Wall_Sth", 189, F, Z1, 248, TOPY + 1, -255, WALL_C, H, W)
	box("Wall_End", X1, F, Z0, 248, TOPY + 1, Z1, WALL_C, H, W)
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
	local SX1 = SX0 + (V - F) -- 235: the top step's east edge
	-- the slope people actually walk on (a wedge rising east)
	do
		local c = Vector3.new((SX0 + SX1) / 2, (F + V) / 2, (AZ0 + AZ1) / 2)
		local w = Instance.new("WedgePart")
		w.Name = "VIP_StairRamp" w.Anchored = true w.Transparency = 1 w.CastShadow = false
		w.Size = Vector3.new(AZ1 - AZ0, V - F, SX1 - SX0)
		w.CFrame = CFrame.lookAt(c, c + Vector3.new(-1, 0, 0))
		w.Parent = H
	end
	-- landing at the top, all across, and lane B back west at the 2F level
	local land = box("VIP_Landing", SX1, V - 1, Z0, X1, V, Z1, MARBLE_C, H, { mat = Enum.Material.Marble })
	land.Reflectance = 0.15
	box("VIP_Walk", 189, V - 1, -275.5, SX1, V, Z1, MARBLE_C, H, { mat = Enum.Material.Marble })
	box("WalkFill", 189, F, -275.5, SX1, V - 1, Z1, WALL_C, H, W) -- (solid under the walkway)
	-- glass rail along the walkway over the flight, with the invisible block above it
	box("VIP_Rail", 190, V, -276, SX1, V + 6, -275.5, Color3.fromRGB(200, 230, 255), H, { t = 0.6 })
	box("VIP_RailBlock", 190, V, -276, SX1, V + 12, -275.5, Color3.new(1, 1, 1), H, { t = 1 }).CastShadow = false
	box("VIP_RailNeon", 190, V - 0.65, -275.6, SX1, V - 0.35, -275.45, Color3.fromRGB(255, 250, 175), H, NEON())
	-- red LED lines where the floors meet the walls, and the landing's edge
	box("VIP_FloorLine", SX1, V, Z0, SX1 + 0.3, V + 0.08, AZ1, VIP_RED, H, NEON())
	box("FloorLED", 190, F, Z0, 191, F + 0.25, Z0 + 0.12, Color3.fromRGB(255, 250, 175), H, NEON())
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
			local pl = Instance.new("PointLight") pl.Range = 18 pl.Brightness = 0.8 pl.Color = Color3.fromRGB(255, 225, 200) pl.Shadows = false pl.Parent = at
		end
	end
	-- "VIP" in red neon on the end wall over the landing, an arrow back west
	do
		local s = box("VIP_WaySign", X1 - 0.12, V + 6, -284, X1 - 0.06, V + 11, -268, Color3.new(0, 0, 0), H, { t = 1, ghost = true })
		text(s, Enum.NormalId.Left, "VIP  ←", Color3.fromRGB(255, 60, 80))
		local pl = Instance.new("SurfaceLight") pl.Face = Enum.NormalId.Left pl.Color = VIP_RED pl.Range = 10 pl.Brightness = 1.5 pl.Parent = s
	end
	-- outside: black cladding like the club front above the ground
	local BLACK = Color3.fromRGB(26, 27, 30)
	box("Cladding", 189, 0, -292.2, 248.2, TOPY + 1, -292, BLACK, H, { mat = Enum.Material.Metal })
	box("Cladding", 189, 0, -255, 248.2, TOPY + 1, -254.8, BLACK, H, { mat = Enum.Material.Metal })
	box("Cladding", 248, 0, -292.2, 248.2, TOPY + 1, -254.8, BLACK, H, { mat = Enum.Material.Metal })
	box("CapBand", 189, TOPY + 0.6, -292.4, 248.4, TOPY + 1.4, -254.6, Color3.fromRGB(40, 42, 46), H, { mat = Enum.Material.Metal })
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
	table.insert(log, "stair hall parts " .. #H:GetDescendants())
end

---------------------------------------------------------------- 4. locker room
do
	local R = Instance.new("Model")
	R.Name = "LockerRoom"
	R.Parent = A
	local X0, X1, Z0, Z1 = 137.6, 247, -380, -292.4 -- inside
	local TOP = -3
	local WHITE = Color3.fromRGB(246, 244, 240)
	local PLASTER = { mat = Enum.Material.Plaster }
	local wood = box("Floor", 136, F - 1, -382, 249, F, -292, Color3.fromRGB(214, 190, 156), R, { mat = Enum.Material.WoodPlanks })
	wood.Reflectance = 0.05
	box("Ceiling", 136, TOP, -382, 249, 0, -292, WHITE, R)
	box("Wall_W", 136, F, -382, X0, TOP, -292, WHITE, R, PLASTER)
	box("Wall_E", X1, F, -382, 249, TOP, -292, WHITE, R, PLASTER)
	box("Wall_N", 136, F, -382, 249, TOP, Z0, WHITE, R, PLASTER)
	-- the south side is the club's wall and the stair hall's: a white lining with the door
	box("Lining", X0, F, Z1, 138, TOP, -292, WHITE, R, PLASTER)
	box("Lining", 158, F, Z1, X1, TOP, -292, WHITE, R, PLASTER)
	box("Lining", 138, F + 18, Z1, 158, TOP, -292, WHITE, R, PLASTER)
	-- skirting and a soft pink line along the floor
	for _, w in ipairs({ { X0, Z0, X1, Z0 + 0.12 }, { X0, Z0, X0 + 0.12, Z1 }, { X1 - 0.12, Z0, X1, Z1 } }) do
		box("FloorLine", w[1], F, w[2], w[3], F + 0.2, w[4], Color3.fromRGB(255, 190, 215), R, NEON())
	end
	-- light panels: a 4 × 3 grid, bright
	for i = 0, 3 do
		for k = 0, 2 do
			local cx = X0 + (X1 - X0) * (i + 0.5) / 4
			local cz = Z0 + (Z1 - Z0) * (k + 0.5) / 3
			local p = box("LightPanel", cx - 5, TOP - 0.15, cz - 5, cx + 5, TOP, cz + 5, Color3.fromRGB(255, 252, 245), R, NEON())
			local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Bottom sl.Range = 24 sl.Brightness = 2.2 sl.Angle = 120
			sl.Color = Color3.fromRGB(255, 248, 238) sl.Shadows = false sl.Parent = p
		end
	end
	-- LOCKERS along the north and east walls: one block per run with the doors
	-- drawn on it (SurfaceGui grid: pastel doors, a dark gap, a little handle)
	local function lockers(x0, z0, x1, z1, face, cols)
		local b = box("Lockers", x0, F, z0, x1, F + 11, z1, Color3.fromRGB(232, 232, 236), R, { mat = Enum.Material.Metal })
		local g = Instance.new("SurfaceGui") g.Face = face g.LightInfluence = 1 g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 20 g.Parent = b
		local grid = Instance.new("UIGridLayout")
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.CellSize = UDim2.new(1 / cols, -6, 0.5, -6)
		grid.Parent = g
		local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 4) pad.PaddingTop = UDim.new(0, 4) pad.Parent = g
		local tints = { Color3.fromRGB(255, 214, 228), Color3.fromRGB(250, 250, 252), Color3.fromRGB(205, 228, 255), Color3.fromRGB(250, 250, 252) }
		for n = 1, cols * 2 do
			local d = Instance.new("Frame")
			d.BackgroundColor3 = tints[(n - 1) % #tints + 1]
			d.BorderSizePixel = 0
			d.Parent = g
			local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = d
			local h = Instance.new("Frame") h.BackgroundColor3 = Color3.fromRGB(150, 150, 160) h.BorderSizePixel = 0
			h.AnchorPoint = Vector2.new(1, 0.5) h.Position = UDim2.fromScale(0.86, 0.5) h.Size = UDim2.new(0, 6, 0.16, 0) h.Parent = d
			for v = 0, 2 do
				local s = Instance.new("Frame") s.BackgroundColor3 = Color3.fromRGB(190, 190, 198) s.BorderSizePixel = 0
				s.Position = UDim2.new(0.2, 0, 0.08 + v * 0.05, 0) s.Size = UDim2.new(0.5, 0, 0, 3) s.Parent = d
			end
			local num = Instance.new("TextLabel") num.BackgroundTransparency = 1 num.Position = UDim2.fromScale(0.2, 0.25) num.Size = UDim2.fromScale(0.5, 0.12)
			num.TextScaled = true num.Font = Enum.Font.GothamBold num.TextColor3 = Color3.fromRGB(120, 120, 132) num.Text = tostring(n) num.Parent = d
		end
		return b
	end
	lockers(142, Z0, X1 - 6, Z0 + 1.6, Enum.NormalId.Back, 28)
	lockers(X1 - 1.6, Z0 + 6, X1, -300, Enum.NormalId.Left, 20)
	-- FULL-LENGTH MIRRORS (live, MirrorController) on the west wall, gold frames
	local GOLD = Color3.fromRGB(214, 172, 92)
	for _, cz in ipairs({ -366, -346, -326, -306 }) do
		local pos = Vector3.new(X0 + 0.12, F + 7.5, cz)
		local m = Instance.new("Part")
		m.Name = "Mirror" m.Anchored = true m.CanCollide = false m.CastShadow = false
		m.Size = Vector3.new(9, 14, 0.1)
		m.CFrame = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
		m.Color = Color3.fromRGB(200, 210, 220) m.Material = Enum.Material.Glass m.Reflectance = 0.2
		m.Parent = R
		CS:AddTag(m, "Mirror")
		box("MirrorFrame", X0, F + 0.3, cz - 4.8, X0 + 0.3, F + 0.5, cz + 4.8, GOLD, R, { mat = Enum.Material.Foil, nocol = true })
		box("MirrorFrame", X0, F + 14.5, cz - 4.8, X0 + 0.3, F + 14.7, cz + 4.8, GOLD, R, { mat = Enum.Material.Foil, nocol = true })
		box("MirrorFrame", X0, F + 0.3, cz - 4.8, X0 + 0.3, F + 14.7, cz - 4.6, GOLD, R, { mat = Enum.Material.Foil, nocol = true })
		box("MirrorFrame", X0, F + 0.3, cz + 4.6, X0 + 0.3, F + 14.7, cz + 4.8, GOLD, R, { mat = Enum.Material.Foil, nocol = true })
		-- a warm light over each mirror
		local l = box("MirrorLight", X0, F + 15.2, cz - 3, X0 + 0.5, F + 15.6, cz + 3, Color3.fromRGB(255, 240, 215), R, NEON())
		local sl = Instance.new("SurfaceLight") sl.Face = Enum.NormalId.Right sl.Range = 14 sl.Brightness = 1.4 sl.Angle = 100 sl.Parent = l
	end
	-- HOLLYWOOD VANITY along the east part of the south lining: a long counter,
	-- three mirrors with round bulbs, stools
	local VZ = Z1 - 0.12
	box("VanityTop", 170, F + 4.8, VZ - 3, 240, F + 5.3, VZ, WHITE, R, { mat = Enum.Material.Marble })
	box("VanityBody", 170, F, VZ - 2.6, 240, F + 4.8, VZ, Color3.fromRGB(236, 230, 224), R)
	for i, cx in ipairs({ 182, 205, 228 }) do
		local mp = box("VanityMirror", cx - 7, F + 6.5, VZ - 0.08, cx + 7, F + 14.5, VZ, Color3.fromRGB(215, 222, 230), R, { mat = Enum.Material.Glass })
		mp.Reflectance = 0.35
		for _, by in ipairs({ F + 6.4, F + 14.6 }) do
			for bx = cx - 6.5, cx + 6.6, 1.625 do
				local bulb = Instance.new("Part") bulb.Name = "VanityBulb" bulb.Shape = Enum.PartType.Ball bulb.Anchored = true bulb.CanCollide = false bulb.CastShadow = false
				bulb.Size = Vector3.new(0.6, 0.6, 0.6) bulb.Material = Enum.Material.Neon bulb.Color = Color3.fromRGB(255, 244, 220)
				bulb.CFrame = CFrame.new(bx, by, VZ - 0.35) bulb.Parent = R
			end
		end
		local glow = box("VanityGlow", cx - 6, F + 10, VZ - 0.5, cx + 6, F + 10.2, VZ - 0.4, Color3.new(1, 1, 1), R, { t = 1, ghost = true })
		local pl = Instance.new("PointLight") pl.Range = 12 pl.Brightness = 1 pl.Color = Color3.fromRGB(255, 236, 210) pl.Shadows = false pl.Parent = glow
		for _, sx in ipairs({ -4, 4 }) do
			local s = Instance.new("Seat") s.Name = "VanityStool" s.Anchored = true s.Size = Vector3.new(2.4, 0.6, 2.4)
			s.CFrame = CFrame.lookAt(Vector3.new(cx + sx, F + 2.6, VZ - 5), Vector3.new(cx + sx, F + 2.6, VZ)) s.Color = Color3.fromRGB(255, 205, 222) s.Material = Enum.Material.Fabric
			s.Parent = R CS:AddTag(s, "PromptSeat")
			box("StoolLeg", cx + sx - 0.25, F, VZ - 5.25, cx + sx + 0.25, F + 2.3, VZ - 4.75, Color3.fromRGB(200, 200, 206), R, { mat = Enum.Material.Metal })
		end
	end
	-- BENCHES down the middle, upholstered, in pairs back to back
	for _, cx in ipairs({ 168, 196, 224 }) do
		for _, cz in ipairs({ -360, -330 }) do
			box("BenchBase", cx - 8, F, cz - 1.3, cx + 8, F + 1.6, cz + 1.3, Color3.fromRGB(226, 226, 230), R, { mat = Enum.Material.Metal })
			for _, side in ipairs({ -1, 1 }) do
				local s = Instance.new("Seat") s.Name = "Bench" s.Anchored = true s.Size = Vector3.new(16, 0.6, 1.3)
				local c = Vector3.new(cx, F + 1.9, cz + side * 0.65)
				s.CFrame = CFrame.lookAt(c, c + Vector3.new(0, 0, side)) s.Color = Color3.fromRGB(250, 220, 230) s.Material = Enum.Material.Fabric
				s.Parent = R CS:AddTag(s, "PromptSeat")
			end
		end
	end
	-- a round rug in the middle and a few plants
	local rug = Instance.new("Part") rug.Name = "Rug" rug.Shape = Enum.PartType.Cylinder rug.Anchored = true rug.CanCollide = false
	rug.Size = Vector3.new(0.1, 26, 26) rug.CFrame = CFrame.new(196, F + 0.05, -345) * CFrame.Angles(0, 0, math.rad(90))
	rug.Color = Color3.fromRGB(255, 226, 236) rug.Material = Enum.Material.Fabric rug.Parent = R
	local plant = game:GetService("ServerStorage"):FindFirstChild("ArtAssets") and game:GetService("ServerStorage").ArtAssets:FindFirstChild("CafePotPlant")
	if plant then
		for _, at in ipairs({ Vector3.new(141, F, -377), Vector3.new(244, F, -377), Vector3.new(141, F, -296), Vector3.new(244, F, -296) }) do
			local m = plant:Clone()
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
			end
			local cf, size = m:GetBoundingBox()
			m:PivotTo(CFrame.new(at.X, at.Y + size.Y / 2, at.Z) * cf:ToObjectSpace(m:GetPivot()))
			m.Parent = R
		end
	end
	-- the name on the north wall over the lockers, pink neon
	do
		local s = box("LockerSign", 175, F + 12.5, Z0 + 0.06, 215, F + 16.5, Z0 + 0.12, Color3.new(0, 0, 0), R, { t = 1, ghost = true })
		text(s, Enum.NormalId.Back, "LOCKER ROOM · 락커룸", Color3.fromRGB(255, 92, 160))
		local pl = Instance.new("SurfaceLight") pl.Face = Enum.NormalId.Back pl.Color = Color3.fromRGB(255, 120, 180) pl.Range = 8 pl.Brightness = 1 pl.Parent = s
	end
	-- the doorway: a white light frame on both sides, the name over it in the corridor
	for _, zf in ipairs({ -289.85, -292.55 }) do
		box("DoorFrameLight", 137.7, F, zf - 0.15, 138, F + 18, zf + 0.15, Color3.fromRGB(255, 250, 235), R, NEON())
		box("DoorFrameLight", 158, F, zf - 0.15, 158.3, F + 18, zf + 0.15, Color3.fromRGB(255, 250, 235), R, NEON())
		box("DoorFrameLight", 137.7, F + 17.7, zf - 0.15, 158.3, F + 18, zf + 0.15, Color3.fromRGB(255, 250, 235), R, NEON())
	end
	do
		local s = box("LockerDoorSign", 139, F + 18.2, -289.86, 157, F + 21.6, -289.8, Color3.new(0, 0, 0), R, { t = 1, ghost = true })
		text(s, Enum.NormalId.Back, "LOCKER ROOM", Color3.fromRGB(255, 255, 255)) -- (the corridor is on +z)
		local pl = Instance.new("SurfaceLight") pl.Face = Enum.NormalId.Back pl.Range = 8 pl.Brightness = 1 pl.Parent = s
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
			if b.X > 136 and a.X < 249.5 and b.Z > -382.5 and a.Z < -290 and a.Y < 0 then
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
