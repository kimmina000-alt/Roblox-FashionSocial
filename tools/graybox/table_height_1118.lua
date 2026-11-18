-- table_height_1118.lua (D-1795, user 2026-11-18: "테이블 너무 높음 클럽 바에 있는 의자랑
-- 테이블 높이로 모든 테이블 높이 수정"; the user picked ①~③ of the list)
-- The club bar is the measure: stool top 3.0 and counter top 5.0 above the floor,
-- so a table top = its seat's height × 5/3. Lowers (never raises) these tables:
--   ① OH24 window bar + the hot-water side bar (SnackTable "WindowBar"), stools 3.0 → 5.0
--   ② beach cafe round tables with benches (CafeTable, bench 2.38 → 4.0)
--   ③ beach cafe tables with chairs (CafeTable, chair 3.43 → 5.7)
--   (measured with the turned round tops counted right, ② is 3.94 and ③ 5.51 already:
--   only ① changes today; ② / ③ stay checked in case a rebuild raises them)
-- Seats stay. Legs get shorter (their foot stays), the top and everything standing
-- on it (hot-water machines, microwaves, trays, edges, lights) go down with it.
-- Food set on a table later follows the top by itself (SnackConfig.onTable).
-- Run in Edit mode after the whole layout chain (also after user_map_snapshot_1113,
-- which brings OH24Store back from the snapshot). Running it again changes nothing.

local CollectionService = game:GetService("CollectionService")

local RATIO = 5 / 3 -- club bar: 5.0 / 3.0
local DRY = _G.TABLE_HEIGHT_DRY == true -- (set it to only list what would move)
local names: {string} = {}
local MIN_DROP = 0.1 -- closer than this: leave it

local function isSeat(p: Instance): boolean
	return p:IsA("Seat") or CollectionService:HasTag(p, "TouchSeat")
end

-- vertical half extent of a (maybe turned) part
local function halfY(p: BasePart): number
	local cf, s = p.CFrame, p.Size
	return (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
end

-- world X and Z widths of a (maybe turned) part (a round top lies as a turned cylinder)
local function flat(p: BasePart): (number, number)
	local cf, s = p.CFrame, p.Size
	return math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
		math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
end

-- the first wide, upward floor below a point (small parts such as legs are passed)
local function floorUnder(pos: Vector3): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local origin = pos
	for _ = 1, 30 do
		rp.FilterDescendantsInstances = ignore
		local r = workspace:Raycast(origin, Vector3.new(0, -30, 0), rp)
		if not r then return nil end
		local i = r.Instance
		if i == workspace.Terrain or (i:IsA("BasePart") and i.CanCollide and i.Size.X >= 5 and i.Size.Z >= 5 and r.Normal.Y > 0.9) then
			return r.Position.Y
		end
		table.insert(ignore, i)
	end
	return nil
end

local allSeats = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and isSeat(d) then table.insert(allSeats, d) end
end

local function nearestSeat(t: BasePart, top: number): BasePart?
	local best, bd = nil, math.huge
	local fx, fz = flat(t)
	local reach = math.max(fx, fz) / 2
	for _, s in ipairs(allSeats) do
		local st = s.Position.Y + halfY(s)
		local dv = ((s.Position - t.Position) * Vector3.new(1, 0, 1)).Magnitude - reach
		if dv < 4 and st < top and top - st < 8 and dv < bd then bd = dv best = s end
	end
	return best
end

local function lower(t: BasePart): string?
	local top = t.Position.Y + halfY(t)
	local bottom = t.Position.Y - halfY(t)
	local floor = floorUnder(Vector3.new(t.Position.X, bottom - 0.05, t.Position.Z))
	local seat = nearestSeat(t, top)
	if not floor or not seat then return nil end
	local seatFloor = floorUnder(seat.Position - Vector3.new(0, halfY(seat) + 0.05, 0)) or floor
	local seatH = seat.Position.Y + halfY(seat) - seatFloor
	local want = seatH * RATIO
	local delta = (floor + want) - top
	if delta > -MIN_DROP then return nil end -- already low enough (never raised)
	-- everything inside the table's footprint, from its floor up to well above the top
	local tx, tz = flat(t)
	local box = CFrame.new(t.Position.X, (floor + top + 8) / 2, t.Position.Z)
	local size = Vector3.new(tx + 0.6, (top + 8) - floor, tz + 0.6)
	local params = OverlapParams.new()
	local moved, legs = 0, 0
	for _, p in ipairs(workspace:GetPartBoundsInBox(box, size, params)) do
		if p:IsA("BasePart") and not isSeat(p) and not p:IsA("Terrain") then
			local hy = halfY(p)
			local pb, pt = p.Position.Y - hy, p.Position.Y + hy
			-- inside the footprint (walls, glass and floors are wider than the table)
			local ex, ez = flat(p)
			local fits = math.abs(p.Position.X - t.Position.X) + ex / 2 <= tx / 2 + 0.3
				and math.abs(p.Position.Z - t.Position.Z) + ez / 2 <= tz / 2 + 0.3
			if p == t or (fits and pb >= floor - 0.15) then
				-- (stools stand under a bar's overhang: only what touches the top counts)
				if p ~= t and math.abs(pb - floor) < 0.15 and math.abs(pt - bottom) < 0.25 then
					-- a leg: shorter, foot stays
					local cf = p.CFrame
					local axis = if math.abs(cf.UpVector.Y) > 0.9 then "Y" elseif math.abs(cf.RightVector.Y) > 0.9 then "X" else "Z"
					local s = p.Size
					if not DRY then
						p.Size = if axis == "Y" then Vector3.new(s.X, s.Y + delta, s.Z) elseif axis == "X" then Vector3.new(s.X + delta, s.Y, s.Z) else Vector3.new(s.X, s.Y, s.Z + delta)
						p.CFrame = cf + Vector3.new(0, delta / 2, 0)
					end
					legs += 1
					table.insert(names, "leg " .. p.Name)
				elseif p == t or (pb >= floor + 0.5 and pt >= bottom - 0.25) then
					if not DRY then p.CFrame = p.CFrame + Vector3.new(0, delta, 0) end
					moved += 1
					table.insert(names, "move " .. p.Name)
				end
			end
		end
	end
	return string.format("%s %.2f → %.2f (seat %.2f, %d moved, %d legs)", t:GetFullName(), top - floor, want, seatH, moved, legs)
end

local log = {}
local targets: {BasePart} = {}
for _, t in ipairs(CollectionService:GetTagged("SnackTable")) do
	if t:IsA("BasePart") and t:IsDescendantOf(workspace) and t.Name == "WindowBar" and t:FindFirstAncestor("OH24Store") then table.insert(targets, t) end
end
for _, t in ipairs(CollectionService:GetTagged("CafeTable")) do
	if t:IsA("BasePart") and t:IsDescendantOf(workspace) and t:FindFirstAncestor("BeachCafe") then table.insert(targets, t) end
end
for _, t in ipairs(targets) do
	local line = lower(t)
	if line then table.insert(log, line) end
end
print(("[table_height_1118] %d of %d tables lowered"):format(#log, #targets))
for _, l in ipairs(log) do print("  " .. l) end
return table.concat(log, "\n") .. (if DRY then "\n" .. table.concat(names, ", ") else "")
