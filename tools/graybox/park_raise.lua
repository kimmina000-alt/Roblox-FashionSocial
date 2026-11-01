--!nocheck
-- The amusement park on a raised plot (user 2026-11-01, D-696). Run in Edit
-- mode after the layout chain (… polish_1030 → park_raise).
--   MODE "raise" (default): everything on the park's plot (inside its walls,
--     x -152.5..-46.5, z -482..-224, plus the gate's front pieces down to
--     z -215) goes up RAISE studs; a stone platform fills under it, with a
--     landing in front of the gate (z -216..-229). A long, gentle stair (1-stud
--     steps) climbs in the middle (x -114.5..-79.5) from the round plaza's
--     walk (y -2) at z -172 (the user's red line) to the landing: it takes in
--     the plaza's old north steps (moved aside into ParkRaise.HiddenOld). Grass
--     banks on both sides from z -201 (north of the wooden decks). The pocket
--     park's south part and the bus stops stay at street height.
--   (user 2026-11-01: first 32 high with a steep 19-stud stair; then half the
--     height, 16, and the stair drawn out from the red line, D-697)
--   MODE "undo": every moved part goes back down (attribute ParkRaised) and the
--     new pieces (folder Hongdae_Layout.ParkRaise) are removed.
-- Running "raise" twice does nothing the second time (attribute on Hongdae_Layout).
local MODE = ...
MODE = MODE or "raise"
local RAISE = 16
local X0, X1 = -152.5, -46.5 -- the plot, outside edge of the wall pillars
local Z_NORTH, Z_SOUTH = -482, -224 -- the plot (part centres)
local GATE_FRONT = -215 -- the gate's booths, letters and towers reach to z -216
local LANDING_Z = -216 -- the landing in front of the gate: z -229 … -216
local STAIR_Z, STAIR_Y = -172, -2 -- the stair's foot: the round plaza's walk, on the red line
local BANK_Z = -201 -- the banks' foot (the wooden decks reach z -200)
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
	if f then
		-- the plaza's old north steps go back
		local hidden = f:FindFirstChild("HiddenOld")
		local pp = L:FindFirstChild("PocketPark")
		if hidden and pp then for _, c in ipairs(hidden:GetChildren()) do c.Parent = pp end end
		f:Destroy()
	end
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
-- the plaza's old north steps (z -196..-165) go aside: the new stair covers them
local hidden = Instance.new("Folder")
hidden.Name = "HiddenOld"
hidden.Parent = F
local pp = L:FindFirstChild("PocketPark")
if pp then
	for _, c in ipairs(pp:GetChildren()) do
		if c:IsA("BasePart") and c.Name == "ParkStair" and c.Position.Z < -170 and c.Position.X > STAIR_X0 and c.Position.X < STAIR_X1 then
			c.Parent = hidden
		end
	end
end
-- the stair: 1-stud steps from the plaza walk (y STAIR_Y) to the landing (y RAISE)
local steps = RAISE - STAIR_Y
local run = (STAIR_Z - LANDING_Z) / steps -- (each step's depth)
for k = 1, steps do
	local zFront = STAIR_Z - (k - 1) * run
	block("ParkRaiseStep", STAIR_X0, STAIR_Y - 1, zFront, STAIR_X1, STAIR_Y + k, LANDING_Z, if k % 2 == 0 then PAVE else STONE, Enum.Material.Slate)
end
-- stair cheeks (low stone walls along both sides of the stair)
for _, x in ipairs({ STAIR_X0, STAIR_X1 }) do
	local w = Instance.new("WedgePart")
	w.Name = "ParkStairCheek"
	w.Anchored = true
	w.Size = Vector3.new(1.2, steps + 1.5, STAIR_Z - LANDING_Z)
	-- rising toward -Z (the gate): a wedge rises toward its +Z face, so turn it round
	w.CFrame = CFrame.new(x, STAIR_Y + (steps + 1.5) / 2, (STAIR_Z + LANDING_Z) / 2) * CFrame.Angles(0, math.pi, 0)
	w.Color = STONE
	w.Material = Enum.Material.Slate
	w.Parent = F
end
-- grass banks either side of the stair (walkable, but the stair is the way up)
for _, span in ipairs({ { X0, STAIR_X0 - 0.6 }, { STAIR_X1 + 0.6, X1 } }) do
	local w = Instance.new("WedgePart")
	w.Name = "ParkBank"
	w.Anchored = true
	w.Size = Vector3.new(span[2] - span[1], RAISE, BANK_Z - LANDING_Z)
	w.CFrame = CFrame.new((span[1] + span[2]) / 2, RAISE / 2, (BANK_Z + LANDING_Z) / 2) * CFrame.Angles(0, math.pi, 0)
	w.Color = GRASS
	w.Material = Enum.Material.Grass
	w.Parent = F
end
F.Parent = L
L:SetAttribute("ParkRaised", RAISE)
print("[park_raise] raised " .. moved .. " parts by " .. RAISE)
