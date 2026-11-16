--!nocheck
-- 놀이공원 부지를 해변 모래 선까지 좁히기 (D-1494, user 2026-11-16 + a red line down the beach sand's
-- west edge: "해변 모래 있는 선에 맞춰서 놀이공원 부지 좁히자 / 해당 땅 위에 잇는 기구들도 동쪽으로 이동";
-- rides: "벽에 닿는 만큼만").
-- The park's west edge goes from x -298.5 (park_expand_1113) to EDGE = -268 (the beach sand's and the
-- land's west edge), DX = 30.5:
--   1. ParkRaise platforms start at EDGE; the strip becomes sea (terrain water up to y -4, as the sea);
--   2. the west wall run, its pillars (and ParkPillarWestMiddle) move DX east; the south wall run of
--      CornerBeachWalls starts at EDGE;
--   3. 놀이공원길: Paving / lawns start inside the new wall; the wall bed, hedges, trees, lamps, benches
--      and bins in the strip move DX east (they line the wall);
--   4. rides in the strip move east only until their west side is CLEAR (3) inside the new wall:
--      점핑스타, both snack bars, 미니바이킹 (+ its loose side fence), 범퍼 (+ its loose fence folder),
--      03_JumperBoat; a ride they would then touch moves on east too (the carousel next to the mini
--      viking). World-space attributes (Exit, Site, …) move with them.
-- Idempotent: nothing west of EDGE + 1 is left to move on a second run.

local EDGE = -268
local DX = EDGE - (-298.5)
local WALL_IN = EDGE + 6.35 -- (the pillars' inner face: pillar centre 3.85 in, half width 3, + 0.5)
local CLEAR = 3
local GAP = 3
local TOP = workspace

local moved = {}
local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local function bb(inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	local list = if inst:IsA("BasePart") then { inst } else inst:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") then
			local a, b = ext(p)
			lo, hi = lo:Min(a), hi:Max(b)
		end
	end
	return lo, hi
end
local function shiftAttrs(root: Instance, d: Vector3)
	for _, x in ipairs({ root, unpack(root:GetDescendants()) }) do
		for k, v in pairs(x:GetAttributes()) do
			if typeof(v) == "Vector3" and v.Magnitude > 150 then x:SetAttribute(k, v + d)
			elseif typeof(v) == "CFrame" and v.Position.Magnitude > 150 then x:SetAttribute(k, v + d) end
		end
	end
end
local function shift(inst: Instance, d: Vector3)
	if d.Magnitude < 0.01 then return end
	if inst:IsA("BasePart") then
		inst.CFrame += d
	else
		for _, p in ipairs(inst:GetDescendants()) do
			if p:IsA("BasePart") then p.CFrame += d end
		end
		if inst:IsA("Model") then inst.WorldPivot += d end
		for _, m in ipairs(inst:GetDescendants()) do
			if m:IsA("Model") then m.WorldPivot += d end
		end
	end
	shiftAttrs(inst, d)
end
-- set a part's world x range to [x0, x1] (axis-aligned parts, any rotation about y by 90°)
local function setX(p: BasePart, x0: number, x1: number)
	local lo, hi = ext(p)
	local w = x1 - x0
	local axis = if math.abs(p.CFrame.RightVector.X) > 0.9 then "X" elseif math.abs(p.CFrame.LookVector.X) > 0.9 then "Z" else "Y"
	local s = p.Size
	p.Size = if axis == "X" then Vector3.new(w, s.Y, s.Z) elseif axis == "Z" then Vector3.new(s.X, s.Y, w) else Vector3.new(s.X, w, s.Z)
	p.CFrame += Vector3.new((x0 + x1) / 2 - (lo.X + hi.X) / 2, 0, 0)
end

local H = workspace:FindFirstChild("Hongdae_Layout")
local gate = H and H:FindFirstChild("AmusementParkGate")
local paths = workspace:FindFirstChild("놀이공원길")

------------------------------------------------------------------ 1. platforms + sea
local raise = H and H:FindFirstChild("ParkRaise")
if raise then
	for _, p in ipairs(raise:GetChildren()) do
		if p:IsA("BasePart") then
			local lo, hi = ext(p)
			if lo.X < EDGE - 1 and hi.X > EDGE then setX(p, EDGE, hi.X) table.insert(moved, "platform " .. p.Name) end
		end
	end
end
-- sea in the strip (the sea's water top is y -4 here)
workspace.Terrain:FillBlock(CFrame.new((-299 + EDGE) / 2, -14, (-1450 + -335.8) / 2),
	Vector3.new(EDGE - (-299), 20, 1450 - 335.8), Enum.Material.Water)

------------------------------------------------------------------ 2. walls and pillars
if gate then
	for _, p in ipairs(gate:GetDescendants()) do
		if p:IsA("BasePart") then
			local lo, hi = ext(p)
			local isPillar = p.Name:sub(1, 10) == "ParkPillar"
			local isWall = p.Name:sub(1, 8) == "ParkWall"
			if (isPillar or isWall) and lo.X < EDGE - 1 and hi.X < EDGE + 1 and hi.Z > -1460 and lo.Z < -330 then
				p.CFrame += Vector3.new(DX, 0, 0) -- (the west run and its pillars)
			elseif isWall and lo.X < EDGE - 1 and hi.X > EDGE + 10 then
				setX(p, EDGE + 0.5, hi.X) -- (the south run along the beach starts at the new corner)
			end
		end
	end
	table.insert(moved, "west wall + pillars")
end

------------------------------------------------------------------ 3. the paths' things along the wall
if paths then
	for _, d in ipairs(paths:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Paving" or d.Name:find("^Lawn")) then
			local lo, hi = ext(d)
			local x0 = if d.Name == "Paving" then EDGE else WALL_IN
			if lo.X < x0 - 0.5 and hi.X > x0 + 5 then setX(d, x0, hi.X) end
		end
	end
	for _, folder in ipairs(paths:GetChildren()) do
		for _, c in ipairs(folder:GetChildren()) do
			if c.Name ~= "Paving" and not c.Name:find("^Lawn") and (c:IsA("BasePart") or c:IsA("Model")) then
				local lo, hi = bb(c)
				if lo.X < WALL_IN - 0.5 and hi.Z > -1460 and lo.Z < -330 then
					if hi.X < WALL_IN + 40 then
						shift(c, Vector3.new(DX, 0, 0)) -- (along the wall: the whole thing moves)
					elseif c:IsA("BasePart") then
						setX(c, WALL_IN, hi.X) -- (a long bed across the park: its west end is cut back)
					end
				end
			end
		end
	end
	table.insert(moved, "wall bed, hedges, trees, lamps, benches")
end
for _, c in ipairs(workspace:GetChildren()) do
	-- loose hedges (placed by hand) and the birch next to the old wall: just inside the new wall
	if (c.Name == "Hedge" or c.Name == "Birch2") then
		local lo, hi = bb(c)
		if lo.X < WALL_IN - 0.5 and hi.Z > -1460 and lo.Z < -330 and lo.Z > -1460 then
			shift(c, Vector3.new(if c.Name == "Birch2" then DX else WALL_IN + 0.3 - lo.X, 0, 0))
		end
	end
end

------------------------------------------------------------------ 4. rides
local rides = {}
local function addRide(inst: Instance?, extra: {Instance}?)
	if inst then table.insert(rides, { inst = inst, extra = extra or {} }) end
end
addRide(workspace:FindFirstChild("점핑스타"))
addRide(workspace:FindFirstChild("SnackBar2"))
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "Scene" and c:FindFirstChild("SnackBar") then addRide(c) end
end
do
	local mini = workspace:FindFirstChild("미니바이킹")
	local loose = {}
	if mini then
		local lo, hi = bb(mini)
		for _, p in ipairs(workspace:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "FencePanel" and p.Position.X > lo.X - 3 and p.Position.X < hi.X + 3
				and p.Position.Z > lo.Z - 3 and p.Position.Z < hi.Z + 3 then table.insert(loose, p) end
		end
	end
	addRide(mini, loose)
end
do
	local bumper = workspace:FindFirstChild("범퍼")
	local loose = {}
	for _, f in ipairs(workspace:GetChildren()) do
		local pen = f:IsA("Folder") and f:FindFirstChild("범 퍼 펜 ")
		if pen then table.insert(loose, pen) end
	end
	addRide(bumper, loose)
end
addRide(H and H:FindFirstChild("ParkBlockout") and H.ParkBlockout:FindFirstChild("03_JumperBoat"))
local others = {}
local g6 = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("06_Park_Playground")
if g6 then for _, c in ipairs(g6:GetChildren()) do table.insert(others, c) end end
for _, n in ipairs({ "회전컵", "슈퍼바이킹", "놀이터", "소방차" }) do
	local c = workspace:FindFirstChild(n)
	if c then table.insert(others, c) end
end

local function overlap(alo, ahi, blo, bhi, gap)
	return alo.X < bhi.X + gap and blo.X < ahi.X + gap and alo.Z < bhi.Z + gap and blo.Z < ahi.Z + gap
end
for _, r in ipairs(rides) do
	local lo, hi = bb(r.inst)
	local target = WALL_IN + CLEAR
	-- a hedge (placed by hand) between the wall and the ride stays: the ride clears it too
	for _, h in ipairs(workspace:GetChildren()) do
		if h.Name == "Hedge" and h:IsA("BasePart") then
			local hlo, hhi = ext(h)
			if hlo.Z < hi.Z and hhi.Z > lo.Z and hlo.X < WALL_IN + 15 and hhi.X > lo.X - 1 then target = math.max(target, hhi.X + 1) end
		end
	end
	local dx = target - lo.X
	if dx > 0.01 then
		local d = Vector3.new(dx, 0, 0)
		shift(r.inst, d)
		for _, e in ipairs(r.extra) do shift(e, d) end
		table.insert(moved, ("%s +%.1f"):format(r.inst.Name, dx))
		-- a neighbour it now touches moves on east by as much
		local nlo, nhi = bb(r.inst)
		for _, o in ipairs(others) do
			local olo, ohi = bb(o)
			if olo.X < 1e8 and overlap(nlo, nhi, olo, ohi, GAP) and olo.X > nlo.X then
				local push = nhi.X + GAP - olo.X
				if push > 0.01 then
					shift(o, Vector3.new(push, 0, 0))
					table.insert(moved, ("%s +%.1f (next to %s)"):format(o.Name, push, r.inst.Name))
				end
			end
		end
	end
end
------------------------------------------------------------------ 5. what the moved rides now stand on
-- hedges (and tree trunks) inside a moved ride's footprint are set aside in
-- ServerStorage.ParkNarrowRemoved_1116 (attribute FromPath = where each was) for the user to place
-- again; furniture under the kiosk moves north of it
local boxes = {}
for _, r in ipairs(rides) do
	local lo, hi = bb(r.inst)
	table.insert(boxes, { lo, hi })
end
local keep = game.ServerStorage:FindFirstChild("ParkNarrowRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkNarrowRemoved_1116"
keep.Parent = game.ServerStorage
local cands = {}
local green = paths and paths:FindFirstChild("Green")
if green then
	for _, c in ipairs(green:GetChildren()) do
		if c.Name == "Hedge" or (c:IsA("Model") and not c.Name:find("^Lawn")) then table.insert(cands, c) end
	end
end
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "Hedge" and c:IsA("BasePart") then table.insert(cands, c) end
end
local aside = 0
for _, c in ipairs(cands) do
	local lo, hi = bb(c)
	if c:IsA("Model") then
		local m = (lo + hi) / 2
		lo, hi = Vector3.new(m.X - 2, lo.Y, m.Z - 2), Vector3.new(m.X + 2, hi.Y, m.Z + 2)
	end
	for _, b in ipairs(boxes) do
		if lo.X < b[2].X and hi.X > b[1].X and lo.Z < b[2].Z and hi.Z > b[1].Z then
			c:SetAttribute("FromPath", c.Parent:GetFullName())
			c.Parent = keep
			aside += 1
			break
		end
	end
end
table.insert(moved, ("set aside %d hedges"):format(aside))
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "Scene" and c:FindFirstChild("SnackBar") and paths and paths:FindFirstChild("Furniture") then
		local klo, khi = bb(c)
		for _, f in ipairs(paths.Furniture:GetChildren()) do
			local lo, hi = bb(f)
			if lo.X < khi.X and hi.X > klo.X and lo.Z < khi.Z and hi.Z > klo.Z then shift(f, Vector3.new(0, 0, (klo.Z - 2) - hi.Z)) end
		end
	end
end
print("[park_narrow_1116] " .. table.concat(moved, "; "))
return #moved
