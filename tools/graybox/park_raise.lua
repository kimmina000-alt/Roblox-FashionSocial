--!nocheck
-- The amusement park on a raised plot (user 2026-11-01, D-696). Run in Edit
-- mode after the layout chain (… polish_1030 → park_raise).
--   MODE "raise" (default): everything on the park's plot (inside its walls,
--     x -152.5..-46.5, z -482..-224, plus the gate's front pieces down to
--     z -215) goes up RAISE studs (half the club's height above the street,
--     about 65); a stone platform fills under it, with a landing in front of
--     the gate (z -216..-229); from the pocket park's north edge (z -197, where
--     the stair down into the round plaza starts) a steep stair climbs in the
--     middle (x -114.5..-79.5, 1-stud steps) and grass banks on both sides.
--     The pocket park and the bus stops stay at street height.
--   MODE "undo": every moved part goes back down (attribute ParkRaised) and the
--     new pieces (folder Hongdae_Layout.ParkRaise) are removed.
-- Running "raise" twice does nothing the second time (attribute on Hongdae_Layout).
local MODE = ...
MODE = MODE or "raise"
local RAISE = 32
local X0, X1 = -152.5, -46.5 -- the plot, outside edge of the wall pillars
local Z_NORTH, Z_SOUTH = -482, -224 -- the plot (part centres)
local GATE_FRONT = -215 -- the gate's booths, letters and towers reach to z -216
local LANDING_Z = -216 -- the landing in front of the gate: z -229 … -216
local STAIR_Z = -197 -- the stair's foot (the pocket park's down-stair ends here)
local STAIR_X0, STAIR_X1 = -114.5, -79.5
local L = workspace:FindFirstChild("Hongdae_Layout")
assert(L, "Hongdae_Layout missing")

local STONE = Color3.fromRGB(196, 190, 178)
local PAVE = Color3.fromRGB(222, 216, 204)
local GRASS = Color3.fromRGB(96, 150, 74)
local SKIP = { Ground = true, BoundaryWall = true, Terrain = true }

local function inPlot(p: BasePart): boolean
	local q = p.Position
	if q.X <= X0 or q.X >= X1 then return false end
	if q.Z > Z_NORTH and q.Z < Z_SOUTH then return true end
	-- the gate's front pieces (booths, letters) stand a little south of the wall
	return q.Z >= Z_SOUTH and q.Z < GATE_FRONT and p:IsDescendantOf(L:FindFirstChild("AmusementParkGate") or L)
end

if MODE == "undo" then
	local n = 0
	for _, p in ipairs(workspace:GetDescendants()) do
		if p:IsA("BasePart") and typeof(p:GetAttribute("ParkRaised")) == "number" then
			p.CFrame = p.CFrame - Vector3.new(0, p:GetAttribute("ParkRaised"), 0)
			p:SetAttribute("ParkRaised", nil)
			n += 1
		end
	end
	local f = L:FindFirstChild("ParkRaise")
	if f then f:Destroy() end
	L:SetAttribute("ParkRaised", nil)
	print("[park_raise] undo: lowered " .. n .. " parts")
	return
end

if L:GetAttribute("ParkRaised") then
	print("[park_raise] already raised")
	return
end

-- 1. the plot goes up
local moved = 0
local list = {}
for _, p in ipairs(workspace:GetDescendants()) do
	if p:IsA("BasePart") and not SKIP[p.Name] and not p:IsA("Terrain")
		and not p:IsDescendantOf(L:FindFirstChild("PocketPark") or game)
		and inPlot(p) then
		table.insert(list, p)
	end
end
for i, p in ipairs(list) do
	p.CFrame = p.CFrame + Vector3.new(0, RAISE, 0)
	p:SetAttribute("ParkRaised", RAISE)
	moved += 1
	if i % 500 == 0 then task.wait() end
end

-- 2. the new pieces
local F = Instance.new("Folder")
F.Name = "ParkRaise"
local function block(name, x0, y0, z0, x1, y1, z1, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = F
	return p
end
-- the raised ground under the park and the landing in front of the gate
-- (a stone retaining block; its top is the park's new street level)
block("ParkPlatform", X0, 0, Z_NORTH, X1, RAISE, LANDING_Z, STONE, Enum.Material.Slate)
block("ParkLandingPaving", X0, RAISE, -229, X1, RAISE + 0.08, LANDING_Z, PAVE, Enum.Material.Slate)
-- the stair: 1-stud steps from the pocket park (y 0) to the landing (y RAISE)
local run = (STAIR_Z - LANDING_Z) / RAISE -- (each step's depth)
for k = 1, RAISE do
	local zFront = STAIR_Z - (k - 1) * run
	block("ParkRaiseStep", STAIR_X0, 0, zFront, STAIR_X1, k, LANDING_Z, if k % 2 == 0 then PAVE else STONE, Enum.Material.Slate)
end
-- stair cheeks (low stone walls along both sides of the stair)
for _, x in ipairs({ STAIR_X0, STAIR_X1 }) do
	local w = Instance.new("WedgePart")
	w.Name = "ParkStairCheek"
	w.Anchored = true
	w.Size = Vector3.new(1.2, RAISE + 1.5, STAIR_Z - LANDING_Z)
	-- rising toward -Z (the gate): a wedge rises toward its +Z face, so turn it round
	w.CFrame = CFrame.new(x, (RAISE + 1.5) / 2, (STAIR_Z + LANDING_Z) / 2) * CFrame.Angles(0, math.pi, 0)
	w.Color = STONE
	w.Material = Enum.Material.Slate
	w.Parent = F
end
-- grass banks either side of the stair (walkable, but the stair is the way up)
for _, span in ipairs({ { X0, STAIR_X0 - 0.6 }, { STAIR_X1 + 0.6, X1 } }) do
	local w = Instance.new("WedgePart")
	w.Name = "ParkBank"
	w.Anchored = true
	w.Size = Vector3.new(span[2] - span[1], RAISE, STAIR_Z - LANDING_Z)
	w.CFrame = CFrame.new((span[1] + span[2]) / 2, RAISE / 2, (STAIR_Z + LANDING_Z) / 2) * CFrame.Angles(0, math.pi, 0)
	w.Color = GRASS
	w.Material = Enum.Material.Grass
	w.Parent = F
end
F.Parent = L
L:SetAttribute("ParkRaised", RAISE)
print("[park_raise] raised " .. moved .. " parts by " .. RAISE)
