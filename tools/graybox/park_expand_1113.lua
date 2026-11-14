-- (D-1393, user 2026-11-13, an aerial screenshot with a red line: "놀이공원 부지 빨간 선만큼
-- 확장해 줘. 놀이공원 벽도 그만큼 옮겨서 수정해 주고. 해변은 삭제하고 해당 땅 위에 있는 나무랑
-- 파라솔 같은 아이템 삭제해. 튜브랑 고무 오리도. 도로도 유턴 도로 부분 부지 커지는만큼 줄어들어서
-- 이동되어야 함." Agreed on a top view: the box x -298.5..-148, z -456..-277 (west = the park's
-- north platform edge at the sea, south = the park's south wall), beach removed only inside it.)
--   1. Everything on the box that is not the park (beach sand, steps, promenade, lamps, palms,
--      parasols, beach mats, tubes, ducks, the sea road's north end) is removed; long pieces
--      that go on south of the box are cut at its south edge (z -277). Terrain water in the
--      box is cleared.
--   2. The sea road's U-turn end (SeaRoadEnd, its paving wedges, the U-turn arrow and sign) moves
--      south by UTURN_SHIFT; the road, its lines and the sidewalk start behind it.
--   3. A park platform (top 16, like ParkPlatform / ParkPlatformNorth) fills the box; the lawn
--      strip of the north part (ParkGround x -206..-148) runs on south over it.
--   4. Walls: the north part's west wall (x -276.1) runs on south to z -279.5; its south wall
--      (z -476.9) moves to z -279.5 (same x, same pillars); the old west wall of the inner park
--      (x -147.5) and its corner pillar at (-148, -477.4) go; that pillar becomes the new
--      south-west corner (-273.7, -279.5); the user's loose pillar (workspace.Folder at
--      -149.85, -460.2) becomes the middle pillar of the new west wall.
--      The inner park's construction fence (hoarding nets, ParkWallBlocker) stays as it is.
-- Chain step: after user_map_snapshot_1113 (the snapshot puts AmusementParkGate back), last.
-- Run once; a second run finds nothing left to do (it checks the pieces' positions first).
-- DRY = true only prints what it would do.

local DRY = false

local CS = game:GetService("CollectionService")
local H = workspace:WaitForChild("Hongdae_Layout")
local GB = workspace:WaitForChild("Graybox_MainSocial")
local gate = H:WaitForChild("AmusementParkGate")
local raise = H:WaitForChild("ParkRaise")

local X0, X1 = -298.5, -148 -- the box
local Z0, Z1 = -456, -277
local SOUTH_WALL_Z = -279.5
local OLD_SOUTH_Z = -476.9 -- the north part's south wall
local OLD_WEST_X = -147.5 -- the inner park's west wall
local WEST_X = -276.1 -- the north part's west wall
local UTURN_SHIFT = 129 -- the U-turn's north edge -404 → -275

local log = {}
local function say(s: string) table.insert(log, s) end

local function aabb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end

-- never touched by the clearing: the park, the map boundary, the far ground
local function protected(inst: Instance): boolean
	return inst:IsDescendantOf(gate) or inst:IsDescendantOf(raise) or inst:IsDescendantOf(H:FindFirstChild("ParkBlockout") or gate)
		or inst:IsDescendantOf(H:FindFirstChild("MapBoundary") or gate) or inst:IsDescendantOf(GB:FindFirstChild("00_Ground") or gate)
		or (inst:IsA("BasePart") and inst.Name == "Ground")
end

------------------------------------------------------------------ 2. the U-turn moves south
local uturn = {}
for _, c in ipairs(H:GetChildren()) do
	if c:IsA("BasePart") then
		local a, b = aabb(c)
		local isEnd = c.Name == "SeaRoadEnd" or c.Name == "UTurnArrow" or c.Name == "UTurnSign" or c.Name == "UTurnSignPost"
		-- the paving wedges round the road's end
		local isPave = c.Name == "Promenade" and c:IsA("WedgePart") and a.X > -183 and b.X < -157 and a.Z > -405 and b.Z < -391
		if (isEnd or isPave) and b.Z < -300 then table.insert(uturn, c) end
	end
end
say(("U-turn pieces to move: %d"):format(#uturn))
local moved: {[Instance]: boolean} = {}
for _, p in ipairs(uturn) do
	moved[p] = true
	if not DRY then p.CFrame = p.CFrame + Vector3.new(0, 0, UTURN_SHIFT) end
end
local ROAD_START = -392 + UTURN_SHIFT -- where the straight road meets the U-turn now

------------------------------------------------------------------ 1. clear the box
local function inBox(v: Vector3): boolean
	return v.X > X0 and v.X < X1 and v.Z > Z0 - 22 and v.Z < Z1 -- (to -478: the paving up to the old wall)
end
-- cut a part's north end back to zNorth (only for parts turned by a multiple of 90°)
local function cutNorth(p: BasePart, zNorth: number): boolean
	local a, b = aabb(p)
	if b.Z <= zNorth then return false end
	local yaw = math.deg(select(2, p.CFrame:ToOrientation())) % 90
	if math.abs(yaw) > 0.5 and math.abs(yaw - 90) > 0.5 then return false end
	local keep = b.Z - zNorth
	local rv, lv = p.CFrame.RightVector, p.CFrame.LookVector
	if not DRY then
		if math.abs(rv.Z) > 0.9 then p.Size = Vector3.new(keep, p.Size.Y, p.Size.Z)
		elseif math.abs(lv.Z) > 0.9 then p.Size = Vector3.new(p.Size.X, p.Size.Y, keep)
		else return false end
		p.CFrame = p.CFrame + Vector3.new(0, 0, (zNorth + b.Z) / 2 - p.Position.Z)
	end
	return true
end

local removed, cut = 0, 0
local roots = { H, GB:FindFirstChild("04_Beach_Aquarium"), workspace:FindFirstChild("StreetDress") }
for _, root in ipairs(roots) do
	if root then
		-- models (palms, parasols, lamps, beach spots, tubes, ducks...) by their middle
		for _, m in ipairs(root:GetDescendants()) do
			if m:IsA("Model") and m.Parent and not protected(m) and m ~= root then
				local ok, cf = pcall(function() return (m :: Model):GetBoundingBox() end)
				if ok and inBox(cf.Position) and cf.Position.Y < 40 then
					say("remove model " .. m:GetFullName())
					removed += 1
					if not DRY then m:Destroy() end
				end
			end
		end
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") and p.Parent and not protected(p) and not moved[p] then
				local a, b = aabb(p)
				local overlaps = b.X > X0 and a.X < X1 and b.Z > Z0 - 22 and a.Z < Z1
				if overlaps and b.Y > -3 and a.Y < 40 then
					local inside = a.X >= X0 - 0.5 and b.X <= X1 + 0.5 and a.Z >= Z0 - 30 and b.Z <= Z1 + 0.5
					if inside then
						say(("remove %s x %.0f..%.0f z %.0f..%.0f"):format(p:GetFullName(), a.X, b.X, a.Z, b.Z))
						removed += 1
						if not DRY then p:Destroy() end
					elseif b.Z > Z1 and a.Z < Z1 then
						-- runs on south of the box: cut at its south edge (the road at the U-turn)
						local road = p.Name == "SeaRoad" or p.Name == "EdgeLine" or p.Name == "CenterLine"
						local zNorth = if p.Name == "CenterLine" then ROAD_START + 12 elseif road then ROAD_START else Z1
						if cutNorth(p, zNorth) then
							say(("cut %s to z %.0f (was from %.0f)"):format(p:GetFullName(), zNorth, a.Z))
							cut += 1
						else
							say(("LEFT %s (turned, crosses the edge)"):format(p:GetFullName()))
						end
					elseif a.Z < Z1 and b.Z <= Z1 + 0.5 and (a.X < X0 or b.X > X1) then
						say(("LEFT %s x %.0f..%.0f (crosses the box side)"):format(p:GetFullName(), a.X, b.X))
					end
				end
			end
		end
	end
end
-- the road and its lines behind the moved U-turn (pieces between the box and the new end)
for _, p in ipairs(H:GetChildren()) do
	if p:IsA("BasePart") and not moved[p] and (p.Name == "SeaRoad" or p.Name == "EdgeLine" or p.Name == "CenterLine" or p.Name == "BikeSymbol") then
		local a, b = aabb(p)
		local zNorth = if p.Name == "CenterLine" then ROAD_START + 12 else ROAD_START
		if a.Z < zNorth and a.X > -185 and b.X < -150 then
			if b.Z <= zNorth + 1 then
				say("remove " .. p.Name .. (" z %.0f"):format(a.Z))
				removed += 1
				if not DRY then p:Destroy() end
			elseif cutNorth(p, zNorth) then
				say(("cut %s to z %.0f"):format(p.Name, zNorth))
				cut += 1
			end
		end
	end
end
say(("removed %d, cut %d"):format(removed, cut))
if not DRY then
	workspace.Terrain:FillBlock(CFrame.new((X0 + X1) / 2, -5, (Z0 + Z1) / 2), Vector3.new(X1 - X0, 50, Z1 - Z0), Enum.Material.Air)
end

------------------------------------------------------------------ 3. platform and lawn
local north = raise:FindFirstChild("ParkPlatformNorth") :: BasePart
if not DRY and not raise:FindFirstChild("ParkPlatformWest") then
	local p = north:Clone()
	p.Name = "ParkPlatformWest"
	p.Size = Vector3.new(X1 - X0, 28, Z1 - Z0)
	p.CFrame = CFrame.new((X0 + X1) / 2, 16 - 14, (Z0 + Z1) / 2)
	p.Parent = raise
end
for _, g in ipairs(gate:GetChildren()) do
	-- the north part's west lawn strip (x -206..-148) runs on south to the new wall
	if g:IsA("BasePart") and g.Name == "ParkGround" and math.abs(g.Position.X + 177) < 1 then
		local a, b = aabb(g)
		if b.Z < SOUTH_WALL_Z - 5 then
			say(("lawn strip z ..%.0f → ..%.0f"):format(b.Z, SOUTH_WALL_Z))
			if not DRY then
				local len = SOUTH_WALL_Z - a.Z
				g.Size = Vector3.new(g.Size.X, g.Size.Y, len)
				g.CFrame = CFrame.new(g.Position.X, g.Position.Y, a.Z + len / 2)
			end
		end
	end
end

------------------------------------------------------------------ 4. walls
local function near(a: number, b: number, d: number?): boolean return math.abs(a - b) < (d or 0.6) end
local WALL_NAMES = { ParkWall = true, ParkWallPlinth = true, ParkWallCap = true, ParkWallCornice = true, ParkWallTop = true }
local PILLAR_NAMES = { ParkPillar = true, ParkPillarBase = true, ParkPillarDrum = true, ParkPillarCornice = true, ParkPillarCap = true, ParkPillarDome = true, ParkPillarSpire = true }
for _, g in ipairs(gate:GetChildren()) do
	if g:IsA("BasePart") and WALL_NAMES[g.Name] then
		local a, b = aabb(g)
		local long = b.Z - a.Z > b.X - a.X
		if long and near(g.Position.X, OLD_WEST_X, 1) and b.Z < -270 and a.Z > -530 then
			say("remove old west wall piece " .. g.Name)
			if not DRY then g:Destroy() end
		elseif long and near(g.Position.X, WEST_X, 1) and near(b.Z, -480, 45) then
			-- the north part's west wall runs on to the new corner pillar (its south end
			-- inside the pillar, like the old ends were inside the old corner pillar)
			local southEnd = SOUTH_WALL_Z - 3
			say(("west wall %s z ..%.1f → ..%.1f"):format(g.Name, b.Z, southEnd))
			if not DRY then
				local len = southEnd - a.Z
				g.Size = Vector3.new(g.Size.X, g.Size.Y, len)
				g.CFrame = CFrame.new(g.Position.X, g.Position.Y, a.Z + len / 2)
			end
		elseif not long and near(g.Position.Z, OLD_SOUTH_Z, 1) and a.X < -200 then
			say("south wall " .. g.Name .. " z -476.9 → -279.5")
			if not DRY then g.CFrame = g.CFrame + Vector3.new(0, 0, SOUTH_WALL_Z - OLD_SOUTH_Z) end
		end
	end
end
-- pillars: the old corner (-148, -477.4) → the new south-west corner
for _, g in ipairs(gate:GetChildren()) do
	if g:IsA("BasePart") and PILLAR_NAMES[g.Name] and near(g.Position.X, -148, 1) and near(g.Position.Z, -477.4, 1) then
		if not DRY then g.CFrame = g.CFrame + Vector3.new(-273.7 - -148, 0, SOUTH_WALL_Z - -477.4) end
		say("corner pillar piece " .. g.Name .. " → (-273.7, -279.5)")
	end
end
-- the user's loose pillar → the middle of the new west wall
local loose: Instance? = nil
for _, f in ipairs(workspace:GetChildren()) do
	local base = f:IsA("Folder") and f:FindFirstChild("ParkPillarBase")
	if base and base:IsA("BasePart") and near(base.Position.X, -149.85, 1) and near(base.Position.Z, -460.2, 1) then loose = f end
end
if loose then
	say("loose pillar → (-273.7, -378.2)")
	if not DRY then
		local base = loose:FindFirstChild("ParkPillarBase") :: BasePart
		local d = Vector3.new(-273.7 - base.Position.X, 0, -378.2 - base.Position.Z)
		for _, p in ipairs(loose:GetDescendants()) do if p:IsA("BasePart") then p.CFrame = p.CFrame + d end end
		loose.Name = "ParkPillarWestMiddle"
		loose.Parent = gate
	end
end

------------------------------------------------------------------ 5. the west wall out to the ground's edge
-- (D-1406, user 2026-11-14, a screenshot: "놀이공원 벽을 회색땅 선 끝까지 맞춰서 이동") the west
-- wall (x -276.1) and its pillars (x -273.7) move out to the platform's sea edge (x -298.25):
-- wall plinth flush with the edge (centre -297.45), pillar bases flush (centre -294.65); the
-- south wall's west end follows the corner pillar. Pieces already out there are left alone.
local WALL_DX, PILLAR_DX = -21.35, -20.95
local shifted = 0
for _, d in ipairs(gate:GetDescendants()) do
	if d:IsA("BasePart") then
		local a, b = aabb(d)
		local long = b.Z - a.Z > b.X - a.X
		if WALL_NAMES[d.Name] and long and near(d.Position.X, WEST_X, 1) then
			if not DRY then d.CFrame = d.CFrame + Vector3.new(WALL_DX, 0, 0) end
			shifted += 1
		elseif string.match(d.Name, "^ParkPillar") and near(d.Position.X, -273.7, 1.5) then
			if not DRY then d.CFrame = d.CFrame + Vector3.new(PILLAR_DX, 0, 0) end
			shifted += 1
		elseif WALL_NAMES[d.Name] and not long and near(d.Position.Z, SOUTH_WALL_Z, 1) and a.X < -265 and a.X > -272 then
			if not DRY then
				local len = b.X - a.X - PILLAR_DX
				d.Size = Vector3.new(len, d.Size.Y, d.Size.Z)
				d.CFrame = CFrame.new(b.X - len / 2, d.Position.Y, d.Position.Z)
			end
			shifted += 1
		end
	end
end
say(("west wall out to the edge: %d pieces"):format(shifted))

print("[park_expand_1113]" .. (if DRY then " DRY" else "") .. "\n" .. table.concat(log, "\n"))
return table.concat(log, "\n")
