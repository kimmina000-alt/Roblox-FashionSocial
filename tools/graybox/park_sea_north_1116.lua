--!nocheck
-- 공원 북쪽을 바다로 (D-1526, user 2026-11-16: "범퍼카 뒤 공간 안 보이게" → method 1, "공원 부지 줄이기:
-- 범퍼카장 북쪽 벽을 공원의 북쪽 끝으로 삼고, 그 뒤 땅은 바다로"; the playground: "놀이공원 부지 땅 아래 빈 곳에 수납").
-- The park ends at z CUT behind the bumper hall:
--   * a new north wall (clones of the west wall's ParkWall / Cap / Cornice / Plinth / Top, turned east-west)
--     from the west wall to the east wall at z WALL_Z, a corner pillar group at each end;
--   * north of CUT: the park platform cut (a strip under the east wall stays: a sea wall by the road), the
--     west wall cut and its pillars there removed, the park paving cut; Hongdae_Layout Ground and the
--     hidden BeachSand under the park cut back to CUT (their tops are over the sea level);
--   * the sea: terrain water y -16..-4 (the west sea's level) over x -268..-55, z -1450..CUT, and on to the
--     west (x -1024..-268) for z -1450..-1024 where the old sea stopped; a sea floor part under it
--     (a clone of 00_Ground.SeaFloor);
--   * lawns, beds, lamps, benches and bins of 놀이공원길 north of CUT and Hongdae_Layout.ParkBlockout set
--     aside in ServerStorage.ParkSeaNorthRemoved_1116 (attribute FromPath);
--   * the playground (Workspace.놀이터) put away under the park's ground (centre (-160, -600), top y -20),
--     unseen; move it up again to use it.
-- Run once after the park steps (idempotent: it does nothing when the platform already ends at CUT).

local SS = game:GetService("ServerStorage")
local CUT = -770
local WALL_Z = -769.2
local SEA_TOP, SEA_BOT = -4, -16
local o = {}

local L = workspace:FindFirstChild("Hongdae_Layout")
local gate = L and L:FindFirstChild("AmusementParkGate")
local raise = L and L:FindFirstChild("ParkRaise")
local platform = raise and raise:FindFirstChild("ParkPlatformNorth")
assert(gate and platform, "no AmusementParkGate / ParkPlatformNorth")
local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local function box(p: BasePart, lo: Vector3, hi: Vector3)
	p.Size = hi - lo
	p.CFrame = CFrame.new((lo + hi) / 2)
end
local plo, phi = ext(platform)
if plo.Z > CUT - 1 then
	print("[park_sea_north_1116] already done")
	return "already done"
end
local keep = SS:FindFirstChild("ParkSeaNorthRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkSeaNorthRemoved_1116"
keep.Parent = SS
local function aside(x: Instance)
	x:SetAttribute("FromPath", x.Parent and x.Parent:GetFullName() or "")
	x.Parent = keep
end

---------------------------------------------------------------- the walls
local function pillarGroup(near: Vector3): {BasePart}
	local best, bestD
	for _, p in ipairs(gate:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "ParkPillar" then
			local d = (Vector3.new(p.Position.X, 0, p.Position.Z) - near).Magnitude
			if not bestD or d < bestD then best, bestD = p, d end
		end
	end
	local g = {}
	if best then
		for _, q in ipairs(best.Parent:GetChildren()) do
			if q:IsA("BasePart") and q.Name:sub(1, 10) == "ParkPillar"
				and Vector2.new(q.Position.X - best.Position.X, q.Position.Z - best.Position.Z).Magnitude < 4.5 then
				table.insert(g, q)
			end
		end
	end
	return g
end
-- corner pillars first (copies of the west and east walls' pillars nearest the cut)
for _, near in ipairs({ Vector3.new(-265, 0, -840), Vector3.new(-52, 0, -840) }) do
	local g = pillarGroup(near)
	local main
	for _, q in ipairs(g) do if q.Name == "ParkPillar" then main = q end end
	if main then
		local d = Vector3.new(0, 0, WALL_Z - main.Position.Z)
		for _, q in ipairs(g) do
			local c = q:Clone()
			c.CFrame += d
			c.Parent = q.Parent
		end
	end
end
-- the new north wall: each piece of the west wall turned east-west, from the west wall to the east wall
local west, east = {}, {}
for _, p in ipairs(gate:GetChildren()) do
	if p:IsA("BasePart") and p.Name:sub(1, 8) == "ParkWall" then
		local lo, hi = ext(p)
		if hi.Z - lo.Z > 50 and lo.Z < CUT then
			if (lo.X + hi.X) / 2 < -200 then west[p.Name] = p else east[p.Name] = p end
		end
	end
end
for name, w in pairs(west) do
	local e = east[name]
	if e then
		local wl, wh = ext(w)
		local el, eh = ext(e)
		local x0, x1 = wl.X, eh.X
		local c = w:Clone()
		local thick = wh.X - wl.X
		c.Size = Vector3.new(thick, w.Size.Y, x1 - x0)
		c.CFrame = CFrame.new((x0 + x1) / 2, w.Position.Y, WALL_Z) * CFrame.Angles(0, math.pi / 2, 0)
		c.Name = name
		c.Parent = w.Parent
	end
end
-- the west wall ends at the cut; its pillars north of it go
for _, w in pairs(west) do
	local lo, hi = ext(w)
	box(w, Vector3.new(lo.X, lo.Y, CUT), hi)
end
local gone = 0
for _, p in ipairs(gate:GetDescendants()) do
	if p:IsA("BasePart") and p.Name:sub(1, 10) == "ParkPillar" and p.Position.X < -200 and p.Position.Z < CUT - 3 then
		p:Destroy()
		gone += 1
	end
end
table.insert(o, ("north wall %d pieces, %d west pillar parts off"):format(#(function() local t = {} for k in pairs(west) do table.insert(t, k) end return t end)(), gone))

---------------------------------------------------------------- the ground
-- the platform: the park part up to the cut, a strip under the east wall to the old end
local strip = platform:Clone()
strip.Name = "ParkPierEast"
box(strip, Vector3.new(-55, plo.Y, plo.Z), Vector3.new(phi.X, phi.Y, CUT))
strip.Parent = platform.Parent
box(platform, Vector3.new(plo.X, plo.Y, CUT), phi)
-- the park paving
local paths = workspace:FindFirstChild("놀이공원길")
local paving = paths and paths:FindFirstChild("Ground") and paths.Ground:FindFirstChild("Paving")
if paving then
	local lo, hi = ext(paving)
	if lo.Z < CUT then box(paving, Vector3.new(lo.X, lo.Y, CUT), hi) end
end
-- Hongdae_Layout Ground / BeachSand under the park (tops over the sea level)
for _, p in ipairs(L:GetChildren()) do
	if p:IsA("BasePart") and (p.Name == "Ground" or p.Name == "BeachSand") then
		local lo, hi = ext(p)
		if lo.X < -55 and hi.X > -268 and lo.Z < CUT and hi.Z > CUT and hi.Y > SEA_BOT then
			if lo.X >= -268.5 and hi.X <= -55 then
				box(p, Vector3.new(lo.X, lo.Y, CUT), hi) -- (all inside the park's width: just shorter)
			else
				-- (wider than the park: the part east of -55 keeps its whole length)
				local e = p:Clone()
				box(e, Vector3.new(-55, lo.Y, lo.Z), Vector3.new(hi.X, hi.Y, CUT))
				e.Parent = p.Parent
				box(p, Vector3.new(lo.X, lo.Y, CUT), hi)
			end
		end
	end
end
-- the sea floor and the water
local floor0 = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("00_Ground")
floor0 = floor0 and floor0:FindFirstChild("SeaFloor")
if floor0 then
	local flo, fhi = ext(floor0)
	for _, r in ipairs({
		{ Vector3.new(-268, flo.Y, -1024), Vector3.new(-55, fhi.Y, CUT) },
		{ Vector3.new(-1024, flo.Y, -1450), Vector3.new(-55, fhi.Y, -1024) },
	}) do
		local f = floor0:Clone()
		f.Name = "SeaFloorNorth"
		box(f, r[1], r[2])
		f.Parent = floor0.Parent
	end
end
local T = workspace.Terrain
for _, r in ipairs({
	{ Vector3.new(-268, SEA_BOT, -1450), Vector3.new(-55, SEA_TOP, CUT) },
	{ Vector3.new(-1024, SEA_BOT, -1450), Vector3.new(-268, SEA_TOP, -1024) },
}) do
	local lo, hi = r[1], r[2]
	T:FillBlock(CFrame.new((lo + hi) / 2), hi - lo, Enum.Material.Water)
end
table.insert(o, "sea filled")

---------------------------------------------------------------- what stood there
local n = 0
for _, folder in ipairs(paths and paths:GetChildren() or {}) do
	if folder.Name ~= "Ground" then
		for _, c in ipairs(folder:GetChildren()) do
			local z
			if c:IsA("BasePart") then z = c.Position.Z elseif c:IsA("Model") then z = c:GetPivot().Position.Z end
			if z and z < CUT then
				aside(c)
				n += 1
			end
		end
	end
end
local blockout = L:FindFirstChild("ParkBlockout")
if blockout then
	aside(blockout)
	n += 1
end
table.insert(o, ("%d set aside"):format(n))
-- the playground under the ground
local play = workspace:FindFirstChild("놀이터")
if play then
	local cf, s = play:GetBoundingBox()
	play:PivotTo(play:GetPivot() + (Vector3.new(-160, -20 - s.Y / 2, -600) - cf.Position))
	table.insert(o, "playground put away under the park")
end
print("[park_sea_north_1116] " .. table.concat(o, "; "))
return table.concat(o, "; ")
