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
--     height, 16, and the stair drawn out from the red line, D-697; then flat
--     ground before the gate instead of the banks, handrails higher than the
--     stair, and the park's far walls along the roads raised too, D-698; then no
--     railings: taller stone walls instead, and the main road's sidewalk carried on, D-699)
--   MODE "undo": every moved part goes back down (attribute ParkRaised) and the
--     new pieces (folder Hongdae_Layout.ParkRaise) are removed.
-- Running "raise" twice does nothing the second time (attribute on Hongdae_Layout).
local MODE = ...
MODE = MODE or "raise"
local RAISE = 16
-- (user 2026-11-01, D-700) the whole park moves this far north (-Z) too, so a
-- wide plaza lies between the stair's top and the gate
local SHIFT = 50 -- (25, then 25 more: user 2026-11-01, D-701)
local X0, X1 = -152.5, -46.5 -- the plot, outside edge of the wall pillars
local Z_NORTH, Z_SOUTH = -482, -224 -- the plot (part centres)
local GATE_FRONT = -215 -- the gate's booths, letters and towers reach to z -216
local LANDING_Z = -216 -- the landing in front of the gate: z -229 … -216
local STAIR_Z, STAIR_Y = -172, -2 -- the stair's foot: the round plaza's walk, on the red line
local BANK_Z = -201 -- the front of the flat ground before the gate (the wooden decks reach z -200)
local WALL_H = 3.5 -- the stair's side walls and the forecourt's parapet stand this high over the walking level
local STAIR_X0, STAIR_X1 = -114.5, -79.5
local L = workspace:FindFirstChild("Hongdae_Layout")
assert(L, "Hongdae_Layout missing")

local STONE = Color3.fromRGB(196, 190, 178)
local PAVE = Color3.fromRGB(222, 216, 204)
local GRASS = Color3.fromRGB(96, 150, 74)
local SKIP = { Ground = true, BoundaryWall = true, Terrain = true }

-- the park's walls run on north along both roads to the map's end (x -211..-46.5,
-- z -1400..-470): seen from the street, never reached; they go up too (D-698)
local NX0, NX1, NZ0, NZ1 = -211, -46.5, -1400, -470
local function inPlot(p: BasePart): boolean
	local q = p.Position
	local gate = L:FindFirstChild("AmusementParkGate")
	if gate and p:IsDescendantOf(gate) and q.X > NX0 and q.X < NX1 and q.Z < NZ1 then return true end
	if q.X <= X0 or q.X >= X1 then return false end
	if q.Z > Z_NORTH and q.Z < Z_SOUTH then return true end
	-- the gate's front pieces (booths, letters) stand a little south of the wall
	return q.Z >= Z_SOUTH and q.Z < GATE_FRONT and p:IsDescendantOf(L:FindFirstChild("AmusementParkGate") or L)
end

if MODE == "undo" then
	local n = 0
	for _, p in ipairs(workspace:GetDescendants()) do
		if p:IsA("BasePart") and typeof(p:GetAttribute("ParkRaised")) == "number" then
			local back = p:GetAttribute("ParkShift")
			p.CFrame = p.CFrame - Vector3.new(0, p:GetAttribute("ParkRaised"), -(if typeof(back) == "number" then back else 0))
			p:SetAttribute("ParkRaised", nil)
			p:SetAttribute("ParkShift", nil)
			n += 1
		elseif p:IsA("Model") and typeof(p:GetAttribute("ParkPivotRaised")) == "number" then
			p.WorldPivot = p.WorldPivot - Vector3.new(0, p:GetAttribute("ParkPivotRaised"), -(p:GetAttribute("ParkPivotShift") or 0))
			p:SetAttribute("ParkPivotRaised", nil)
			p:SetAttribute("ParkPivotShift", nil)
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

-- (D-751, live phone: invisible walls across the club street and inside
-- 오후네컷) the boundary along the park's east wall (x -51.3, z -279 … -455)
-- was found turned and lowered right across the map (centre 50.6, 15.5,
-- -149.3). Every boundary wall stands upright, along x or z, centred at y 55:
-- any other is put back here as that east line, on every run.
do
	local boundary = L:FindFirstChild("MapBoundary")
	if boundary then
		for _, w in ipairs(boundary:GetChildren()) do
			if w:IsA("BasePart") and w.Name == "BoundaryWall" then
				-- (it moved twice in a day, most likely dragged by a click in the 3D
				-- view: locked walls cannot be picked in Studio)
				w.Locked = true
				local look = w.CFrame.LookVector
				local square = math.abs(look.X) > 0.999 or math.abs(look.Z) > 0.999
				if not square or math.abs(w.Position.Y - 55) > 0.5 then
					local a, b = Vector3.new(-51.3, 55, -279), Vector3.new(-51.3, 55, -455)
					w.Size = Vector3.new(2, 150, (b - a).Magnitude + 2)
					w.CFrame = CFrame.lookAt((a + b) / 2, b)
					print("[park_raise] boundary wall put back on x -51.3")
				end
			end
		end
	end
end

if L:GetAttribute("ParkRaised") then
	print("[park_raise] already raised")
	return
end

-- 1. the plot goes up
local moved = 0
local list = {}
for _, p in ipairs(workspace:GetDescendants()) do
	-- (D-830) build_hongdae_layout's revert lowers the park first (the same
	-- steps as MODE "undo"), so here nothing carries a raise; a part that does
	-- is left alone rather than lifted twice
	if p:IsA("BasePart") and not SKIP[p.Name] and not p:IsA("Terrain")
		and p:GetAttribute("ParkRaised") == nil
		and not p:IsDescendantOf(L:FindFirstChild("PocketPark") or game)
		and inPlot(p) then
		table.insert(list, p)
	end
end
-- (D-701) the map's invisible boundary across the park's front (z -229) goes
-- north with the park, not up: else it cuts the plaza in two
local boundary = L:FindFirstChild("MapBoundary")
if boundary then
	for _, p in ipairs(boundary:GetDescendants()) do
		if p:IsA("BasePart") and math.abs(p.Position.Z - -229) < 2 and p.Position.X > X0 and p.Position.X < X1 then
			p.CFrame = p.CFrame + Vector3.new(0, 0, -SHIFT)
			p:SetAttribute("ParkRaised", 0)
			p:SetAttribute("ParkShift", SHIFT)
		end
	end
end
-- (D-702) the rides move whole: the Ferris wheel's top cabins and rim stood
-- north of z -482 and stayed behind (24 parts)
do
	local CS = game:GetService("CollectionService")
	local seen = {}
	for _, p in ipairs(list) do seen[p] = true end
	for _, tag in ipairs({ "ParkWheel", "ParkCarousel", "ParkSwing", "ParkSpring" }) do
		for _, m in ipairs(CS:GetTagged(tag)) do
			if m:IsA("Model") and m:IsDescendantOf(workspace) then
				local c = m:GetBoundingBox().Position
				if c.X > X0 and c.X < X1 and c.Z > Z_NORTH - 100 and c.Z < Z_SOUTH then
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") and not seen[d] and d:GetAttribute("ParkRaised") == nil then
							seen[d] = true
							table.insert(list, d)
						end
					end
				end
			end
		end
	end
end
-- (D-702) the Ferris wheel's rim (130 across, in the north-south plane) stuck
-- out over the park's north wall: the wheel, its platform, ramp and labels go
-- WHEEL_PULL less far north than the rest
local WHEEL_PULL = 34 -- (rim inside the brick wall's inner face, z -524)
local wheelSet = {}
do
	local wheel = workspace:FindFirstChild("FerrisWheel", true)
	if wheel and wheel:IsA("Model") then
		local hub = wheel:GetBoundingBox().Position
		wheelSet[wheel] = true
		for _, d in ipairs(wheel:GetDescendants()) do wheelSet[d] = true end
		for _, s in ipairs(wheel.Parent:GetChildren()) do
			if s:IsA("BasePart") and (s.Name:find("^Wheel") or s.Name == "Label")
				and math.abs(s.Position.X - hub.X) < 12 and math.abs(s.Position.Z - hub.Z) < 20 then
				wheelSet[s] = true
			end
		end
	end
end
local models = {}
for i, p in ipairs(list) do
	local shift = if wheelSet[p] then SHIFT - WHEEL_PULL else SHIFT
	p.CFrame = p.CFrame + Vector3.new(0, RAISE, -shift)
	p:SetAttribute("ParkRaised", RAISE)
	p:SetAttribute("ParkShift", shift)
	moved += 1
	local m = p.Parent
	while m and m ~= L and m ~= workspace do
		if m:IsA("Model") then models[m] = true end
		m = m.Parent
	end
	if i % 500 == 0 then task.wait() end
end
-- (D-702) models without a PrimaryPart keep their pivot where it was: the
-- rides (ParkRidesController) turn their rotors about it, so a carousel left
-- its pivot 50 south and 16 down and spun out through the park's wall
for m in pairs(models) do
	if not m.PrimaryPart and m:GetAttribute("ParkPivotRaised") == nil then
		local shift = if wheelSet[m] then SHIFT - WHEEL_PULL else SHIFT
		m.WorldPivot = m.WorldPivot + Vector3.new(0, RAISE, -shift)
		m:SetAttribute("ParkPivotRaised", RAISE)
		m:SetAttribute("ParkPivotShift", shift)
	end
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
block("ParkPlatform", X0, 0, Z_NORTH - SHIFT, X1, RAISE, LANDING_Z, STONE, Enum.Material.Slate)
block("ParkLandingPaving", X0, RAISE, -229 - SHIFT, X1, RAISE + 0.08, LANDING_Z, PAVE, Enum.Material.Slate)
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
-- (D-698 had flat ground beside the stair from z BANK_Z; user 2026-11-01, D-700:
-- the wall moves back to where the stair ends, both sides; the plaza is on top,
-- made wide by moving the park north; the ground left beside the stair is
-- filled with the pocket park's wooden deck)
local DECK = Color3.fromRGB(120, 88, 62)
local DECK_TOP = 1.5 -- the pocket park's upper deck
for _, span in ipairs({ { X0, STAIR_X0 - 0.6 }, { STAIR_X1 + 0.6, X1 } }) do
	-- a stone parapet along the plaza's front edge, WALL_H high
	block("ParkPlazaParapet", span[1], RAISE, LANDING_Z, span[2], RAISE + WALL_H, LANDING_Z - 1.2, STONE, Enum.Material.Slate)
end
-- and along its two sides, back to the park's wall (D-701: the east side was
-- open, its top level with the plaza; now the same height as the front)
-- (D-702: on along the park's whole side, so from the street the stone top is
-- one line under the brick wall)
local PLAZA_BACK = Z_NORTH - SHIFT
for _, x in ipairs({ X0, X1 - 1.2 }) do
	block("ParkPlazaParapet", x, RAISE, LANDING_Z, x + 1.2, RAISE + WALL_H, PLAZA_BACK, STONE, Enum.Material.Slate)
end
-- (D-701) the deck beside the stair only on the west, from the pocket park's
-- upper deck (its west edge x -141) to the stair; west of that line, and on
-- the east, the street's paving (a sidewalk copy at 0.6) instead of decks
local DECK_X0 = -141
-- (it starts under the upper deck's north edge, z -196, so no strip of paving
-- shows between the two; a hair lower so the tops don't flicker)
block("ParkDeckFill", DECK_X0, 0, -196, STAIR_X0 - 0.6, DECK_TOP - 0.02, LANDING_Z, DECK, Enum.Material.WoodPlanks)
do
	local src
	for _, p in ipairs(L:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Sidewalk" and math.abs(p.Position.X - -154) < 1 then src = p end
	end
	local function pave(x0, z0, x1, z1)
		local s = if src then src:Clone() else Instance.new("Part")
		s.Name = "ParkFillPaving"
		s.Anchored = true
		s.Size = Vector3.new(math.abs(x1 - x0), 0.6, math.abs(z1 - z0))
		s.CFrame = CFrame.new((x0 + x1) / 2, 0.3, (z0 + z1) / 2)
		s.Parent = F
	end
	-- (between the sidewalks, x -150 and -47, so no two tops overlap)
	pave(-150, STAIR_Z, DECK_X0, LANDING_Z)
	pave(STAIR_X1 + 0.6, BANK_Z + 1, -47, LANDING_Z)
end
-- invisible blockers over the stone walls: a jump (about 7 studs; phones jump
-- on their own when walking into a wall) clears WALL_H
local BLOCK_H = 10
local function blocker(x0, y0, z0, x1, y1, z1)
	local b = block("ParkWallBlocker", x0, y0, z0, x1, y1, z1, STONE)
	b.Transparency = 1
	b.CanQuery = false
	b.CastShadow = false
end
for _, span in ipairs({ { X0, STAIR_X0 - 0.6 }, { STAIR_X1 + 0.6, X1 } }) do
	blocker(span[1], RAISE + WALL_H, LANDING_Z, span[2], RAISE + WALL_H + BLOCK_H, LANDING_Z - 1.2)
end
for _, x in ipairs({ X0, X1 - 1.2 }) do
	blocker(x, RAISE + WALL_H, LANDING_Z, x + 1.2, RAISE + WALL_H + BLOCK_H, PLAZA_BACK)
end
for _, x in ipairs({ STAIR_X0, STAIR_X1 }) do
	blocker(x - 0.6, STAIR_Y + WALL_H, STAIR_Z, x + 0.6, RAISE + WALL_H + BLOCK_H, LANDING_Z)
end
-- the stair's side walls (D-699: taller, in place of the handrails): a stone
-- wall from the plaza up to WALL_H over the steps all along, a box for its
-- lower part and a wedge for the slope on top
for _, x in ipairs({ STAIR_X0, STAIR_X1 }) do
	block("ParkStairWall", x - 0.6, STAIR_Y - 1, STAIR_Z, x + 0.6, STAIR_Y + WALL_H, LANDING_Z, STONE, Enum.Material.Slate)
	-- (D-702) its top end runs on through the parapet's depth, so the corner
	-- where it meets the plaza's front parapet has no notch
	block("ParkStairWall", x - 0.6, RAISE, LANDING_Z, x + 0.6, RAISE + WALL_H, LANDING_Z - 1.2, STONE, Enum.Material.Slate)
	local w = Instance.new("WedgePart")
	w.Name = "ParkStairWall"
	w.Anchored = true
	w.Size = Vector3.new(1.2, steps, STAIR_Z - LANDING_Z)
	-- rising toward -Z (the gate): a wedge rises toward its +Z face, so turn it round
	w.CFrame = CFrame.new(x, STAIR_Y + WALL_H + steps / 2, (STAIR_Z + LANDING_Z) / 2) * CFrame.Angles(0, math.pi, 0)
	w.Color = STONE
	w.Material = Enum.Material.Slate
	w.Parent = F
end
-- (user 2026-11-01, D-699) the sidewalk along the main road stopped at z -479:
-- north of it bare ground lay between the park's stone base and the road's
-- sidewalk. The same sidewalk, carried on to the map's end.
do
	local src
	for _, p in ipairs(L:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Sidewalk" and math.abs(p.Position.X - -40.5) < 1 and p.Position.Z < -200 then src = p end
	end
	if src then
		local s = src:Clone()
		s.Name = "ParkSidewalkNorth"
		local z0, z1 = NZ0, src.Position.Z - src.Size.Z / 2
		local x0, x1 = X1, src.Position.X + src.Size.X / 2
		s.Size = Vector3.new(x1 - x0, src.Size.Y, z1 - z0)
		s.CFrame = CFrame.new((x0 + x1) / 2, src.Position.Y, (z0 + z1) / 2)
		s.Parent = F
	end
end-- the park's walls north along the roads: a stone base under them, so they
-- don't float (the ground there is out of reach)
-- (D-1327, user 2026-11-12: "놀이공원 부지 넓힘", resized by hand in Studio) west to
-- x -298.2 (was NX0 -211), south to z -455.5 (was -520), down to y -11.2 (was 0)
block("ParkPlatformNorth", -298.2, -11.2, NZ0 - SHIFT, NX1, RAISE, -455.5, STONE, Enum.Material.Slate)
F.Parent = L
L:SetAttribute("ParkRaised", RAISE)
print("[park_raise] raised " .. moved .. " parts by " .. RAISE)
