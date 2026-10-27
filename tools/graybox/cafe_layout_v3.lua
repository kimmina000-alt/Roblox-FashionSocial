-- Beach cafe interior v3 (user mark-up 2026-10-27, D-437): run in the Studio
-- command bar / MCP in Edit mode AFTER the layout chain (… → scale_furniture).
-- It edits Workspace.Graybox_MainSocial.04_Beach_Aquarium.BeachCafe in place,
-- in world coordinates (the cafe is built small, stretched by
-- build_hongdae_layout and its furniture scaled by scale_furniture), so it
-- must run on that finished state. Runs once (attribute CafeLayoutV3).
--
-- Changes, measured on the user's before/after plan (grid 10 studs):
--   1  window bar longer and deeper, 11 bigger stools, plants 2x
--   2  the round tables by the 물멍 channel 6.6 east, 1.3x, chairs further out
--   3  piano stage, piano, bench and planter 1.3x from the NW glass corner;
--      the two sofa sets beside the planter removed
--   4  lounge starts at z 306.6; 5 even rows of sets on all 4 tiers, tables
--      1.25x and set apart from the sofas (1.15x)
--   5  bakery tables 205.3..262 with new trays
--   6  order counter and barista bench out to x -240.8 (the case at the west end)
--   7  staff door 6.5 wide, 11 high
--   8  main entrance 14.6 wide
--   9  2F rail bar 4.8 deep with 17 bigger stools; the three long tables
--      10 x 31 with 4 bigger stools each on the wall side
--  10  the stair side towards the lounge is a full wall (no slanted glass)

local cafe = workspace.Graybox_MainSocial["04_Beach_Aquarium"].BeachCafe
if cafe:GetAttribute("CafeLayoutV3") then return "already done" end
local CS = game:GetService("CollectionService")
local log = {}
local FLOOR, MEZZ = 0.6, 28.6

local function kids(name, f)
	local r = {}
	for _, p in ipairs(cafe:GetChildren()) do
		if p.Name == name and (not f or f(p)) then table.insert(r, p) end
	end
	return r
end
local function near(p, x, z, d) local q = p:IsA("Model") and p:GetPivot().Position or p.Position return math.abs(q.X - x) <= d and math.abs(q.Z - z) <= d end
-- a world box (axis aligned) for a plain part
local function setBox(p, x0, y0, z0, x1, y1, z1)
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
end
local function bounds(p)
	local c, s = p.CFrame, p.Size
	local ex = math.abs(c.RightVector.X) * s.X / 2 + math.abs(c.UpVector.X) * s.Y / 2 + math.abs(c.LookVector.X) * s.Z / 2
	local ey = math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2
	local ez = math.abs(c.RightVector.Z) * s.X / 2 + math.abs(c.UpVector.Z) * s.Y / 2 + math.abs(c.LookVector.Z) * s.Z / 2
	return p.Position.X - ex, p.Position.Y - ey, p.Position.Z - ez, p.Position.X + ex, p.Position.Y + ey, p.Position.Z + ez
end
-- scale a set of parts by k about a floor point (sizes and offsets, all axes)
local function scaleGroup(parts, origin, k)
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			p.Size = p.Size * k
			p.CFrame = CFrame.new(origin + (p.Position - origin) * k) * p.CFrame.Rotation
		elseif p:IsA("Model") then
			p:ScaleTo(p:GetScale() * k)
			local pv = p:GetPivot()
			p:PivotTo(CFrame.new(origin + (pv.Position - origin) * k) * pv.Rotation)
		end
	end
end
local function move(parts, d)
	for _, p in ipairs(parts) do
		if p:IsA("Model") then p:PivotTo(p:GetPivot() + d) else p.CFrame = p.CFrame + d end
	end
end
-- the parts of one seat/stool/table set round (x, z) within r, between y0..y1
local function setAt(names, x, z, r, y0, y1)
	local out = {}
	for _, p in ipairs(cafe:GetChildren()) do
		if names[p.Name] and p:IsA("BasePart") and near(p, x, z, r) and p.Position.Y >= y0 and p.Position.Y <= y1 then table.insert(out, p) end
	end
	return out
end
local function cloneAll(parts)
	local r = {}
	for _, p in ipairs(parts) do local c = p:Clone() c.Parent = cafe table.insert(r, c) end
	return r
end
local function evenly(a, b, n) local r = {} for i = 0, n - 1 do r[i + 1] = a + (b - a) * (i + 0.5) / n end return r end

----------------------------------------------------------------------------
-- 1. window bar, stools, plants
local STOOL = { BarStool = true, BarStoolCushion = true, StoolLeg = true }
do
	local bar = kids("WindowBar", function(p) return p.Position.Y < 10 end)[1]
	setBox(bar, -372.1, FLOOR + 3.2 * 1.4, 208.7, -367.4, FLOOR + 3.6 * 1.4, 293.8)
	local stools = {}
	for _, p in ipairs(kids("BarStool", function(p) return p.Position.Y < 10 end)) do table.insert(stools, p) end
	local template = setAt(STOOL, stools[1].Position.X, stools[1].Position.Z, 1.2, 0, 10)
	local proto = cloneAll(template)
	for _, s in ipairs(stools) do for _, p in ipairs(setAt(STOOL, s.Position.X, s.Position.Z, 1.2, 0, 10)) do p:Destroy() end end
	local o = proto[1].Position
	scaleGroup(proto, Vector3.new(o.X, FLOOR, o.Z), 1.4)
	for _, z in ipairs(evenly(208.7, 293.8, 11)) do
		local c = cloneAll(proto)
		move(c, Vector3.new(-364.2 - o.X, 0, z - o.Z))
	end
	for _, p in ipairs(proto) do p:Destroy() end
	table.insert(log, "1 window bar + 11 stools")
end
do -- plants 2x (1F: the two at the window bar, 2F: the one by the rail bar)
	local spots = { { -370.3, 196.9, -368, 200.0 }, { -370.5, 282.3, -368, 302.3 }, { -252.4, 334.8, -251, 333.9 } }
	for _, s in ipairs(spots) do
		for _, m in ipairs(cafe:GetChildren()) do
			if (m.Name == "CafePotPlant" and m:IsA("Model") and near(m, s[1], s[2], 2)) or (m.Name == "PlantCollider" and near(m, s[1], s[2], 2)) then
				local base = Vector3.new(s[1], 0, s[2])
				if m:IsA("Model") then
					local _, size = m:GetBoundingBox()
					local cf = m:GetBoundingBox()
					local floorY = cf.Position.Y - size.Y / 2
					m:ScaleTo(m:GetScale() * 2)
					local cf2, size2 = m:GetBoundingBox()
					m:PivotTo(m:GetPivot() + Vector3.new(s[3] - cf2.Position.X, floorY + size2.Y / 2 - cf2.Position.Y, s[4] - cf2.Position.Z))
				else
					local y0 = m.Position.Y - m.Size.Y / 2
					m.Size = m.Size * 2
					m.CFrame = CFrame.new(s[3], y0 + m.Size.Y / 2, s[4]) * m.CFrame.Rotation
				end
				_ = base
			end
		end
	end
	table.insert(log, "plants 2x")
end

----------------------------------------------------------------------------
-- 2. round tables by the channel
local ROUND = { CafeTable = true, TableLeg = true, CafeChair = true, ChairCushion = true }
for i, s in ipairs({ { 217.8, 219.4 }, { 244.4, 241.3 }, { 272.0, 265.0 } }) do
	local set = setAt(ROUND, -307.9, s[1], 3.6, 0, 10)
	scaleGroup(set, Vector3.new(-307.9, FLOOR, s[1]), 1.3)
	move(set, Vector3.new(6.6, 0, s[2] - s[1]))
	_ = i
end
table.insert(log, "2 round tables")

----------------------------------------------------------------------------
-- 3. piano corner 1.3x from the NW glass corner (x -372.1, z 356.6)
do
	local C = Vector3.new(-372.1, 0, 356.6)
	local K = 1.3
	local function xz(v) return Vector3.new(C.X + (v.X - C.X) * K, v.Y, C.Z + (v.Z - C.Z) * K) end
	-- the two sofa sets beside the planter go
	for _, p in ipairs(cafe:GetChildren()) do
		if p:IsA("BasePart") and p.Position.X > -346 and p.Position.X < -336 and p.Position.Z > 339 and p.Position.Z < 357
			and (p.Name:find("^Sofa") or p.Name == "Bench" or p.Name == "CafeTable" or p.Name == "TableLeg") then p:Destroy() end
	end
	-- stage boxes and the planter: stretched in x and z
	for _, p in ipairs(cafe:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "PianoStage" or p.Name == "Planter" or p.Name == "PlanterSoil") then
			local x0, y0, z0, x1, y1, z1 = bounds(p)
			local a, b = xz(Vector3.new(x0, y0, z0)), xz(Vector3.new(x1, y1, z1))
			setBox(p, a.X, y0, a.Z, b.X, y1, b.Z)
		end
	end
	-- the shrubs in the planter keep their size, moved with it
	for _, m in ipairs(cafe:GetChildren()) do
		if m:IsA("Model") and m.Name ~= "GrandPiano" and m.Name ~= "CafePotPlant" then
			local pv = m:GetPivot().Position
			if pv.X > -351 and pv.X < -344 and pv.Z > 336 and pv.Z < 358 and pv.Y < 8 then m:PivotTo(m:GetPivot() + (xz(pv) - pv)) end
		end
	end
	-- piano and bench: 1.3x, standing on the stage top
	local piano = cafe:FindFirstChild("GrandPiano")
	local stageTop = 0
	for _, p in ipairs(kids("PianoStage")) do local _, _, _, _, y1 = bounds(p) stageTop = math.max(stageTop, y1) end
	local bench = {}
	for _, p in ipairs(cafe:GetChildren()) do if p:IsA("BasePart") and (p.Name == "PianoBench" or p.Name == "PianoBenchLeg") then table.insert(bench, p) end end
	local group = { piano }
	for _, p in ipairs(bench) do table.insert(group, p) end
	local pc = piano:GetPivot().Position
	local origin = Vector3.new(pc.X, stageTop, pc.Z)
	scaleGroup(group, origin, K)
	move(group, xz(origin) - origin)
	table.insert(log, "3 piano corner")
end

----------------------------------------------------------------------------
-- 4. lounge
do
	local LZ0, LZ1 = 306.6, 356.2
	local tiers = kids("LoungeStep")
	table.sort(tiers, function(a, b) return a.Position.X < b.Position.X end)
	local SET = { CafeTable = true, TableLeg = true, SofaBase = true, SofaCushion = true, SofaBack = true, SofaBackRoll = true, SofaArm = true, SofaArmRoll = true, Bench = true }
	local ROWS = { 316.6, 325.4, 334.0, 342.7, 351.3 }
	for _, p in ipairs(kids("LoungeHalfStep")) do p:Destroy() end
	for k, tier in ipairs(tiers) do
		local x0, y0, _, x1, y1 = bounds(tier)
		-- this tier's sets: keep one as the template, drop the rest
		local template
		for _, p in ipairs(kids("CafeTable", function(p) return p.Position.X > x0 and p.Position.X < x1 and p.Position.Y > y1 end)) do
			if not template or math.abs(p.Position.Z - 298.5) < math.abs(template.Position.Z - 298.5) then template = p end
		end
		local tz = template.Position.Z
		local tx = template.Position.X
		local proto = cloneAll(setAt(SET, tx + 2.5, tz, 3.2, y1 - 0.5, y1 + 6))
		for _, p in ipairs(cafe:GetChildren()) do
			-- (z > 286: only the lounge; the round tables by the channel stand in the
			-- same x range and height, and went with the first run)
			if SET[p.Name] and p:IsA("BasePart") and p.Position.X > x0 and p.Position.X < x1 and p.Position.Z > 286 and p.Position.Y > y1 - 0.5 and p.Position.Y < y1 + 6 and not table.find(proto, p) then p:Destroy() end
		end
		-- table 1.25x, 1.6 west; sofa 1.15x, 1 east
		local tableParts, sofaParts = {}, {}
		for _, p in ipairs(proto) do if p.Name == "CafeTable" or p.Name == "TableLeg" then table.insert(tableParts, p) else table.insert(sofaParts, p) end end
		for _, p in ipairs(tableParts) do
			if p.Name == "CafeTable" then p.Size = Vector3.new(p.Size.X, p.Size.Y * 1.25, p.Size.Z * 1.25) end
			p.CFrame = p.CFrame + Vector3.new(-1.6, 0, 0)
		end
		local sx0, _, sz0, sx1, _, sz1 = math.huge, 0, math.huge, -math.huge, 0, -math.huge
		for _, p in ipairs(sofaParts) do local a, _, b, c, _, d = bounds(p) sx0 = math.min(sx0, a) sz0 = math.min(sz0, b) sx1 = math.max(sx1, c) sz1 = math.max(sz1, d) end
		scaleGroup(sofaParts, Vector3.new((sx0 + sx1) / 2, y1, (sz0 + sz1) / 2), 1.15)
		move(sofaParts, Vector3.new(1, 0, 0))
		-- the tier shortened, half steps in the new aisles, five rows of sets
		setBox(tier, x0, y0, LZ0, x1, y1, LZ1)
		local aisles = { { LZ0, 310.6 }, { 319.2, 322.8 }, { 328.0, 331.4 }, { 336.6, 340.1 }, { 345.3, 348.7 }, { 353.9, LZ1 } }
		for _, a in ipairs(aisles) do
			local h = Instance.new("Part")
			h.Name = "LoungeHalfStep" h.Anchored = true h.Material = tier.Material h.Color = tier.Color
			setBox(h, x0 - 2.3, y1 - 2, a[1], x0, y1 - 1, a[2])
			h.Parent = cafe
		end
		for _, rz in ipairs(ROWS) do
			local c = cloneAll(proto)
			move(c, Vector3.new(0, 0, rz - tz))
			for _, p in ipairs(c) do if p.Name == "CafeTable" then CS:AddTag(p, "CafeTable") end end
		end
		for _, p in ipairs(proto) do p:Destroy() end
		_ = k
	end
	table.insert(log, "4 lounge")
end

----------------------------------------------------------------------------
-- 5. bakery tables
do
	for _, p in ipairs(kids("Bread")) do p:Destroy() end
	local trays = kids("BreadTray")
	local trayTemplate = trays[1]:Clone()
	for _, t in ipairs(trays) do t:Destroy() end
	for _, tbl in ipairs(kids("BakeryTable")) do
		local x0, y0, _, x1, y1 = bounds(tbl)
		setBox(tbl, x0, y0, 205.3, x1, y1, 262.0)
		local n = math.floor((262.0 - 205.3 - 0.5) / 2.6)
		for i = 0, n - 1 do
			local t = trayTemplate:Clone()
			local tz = 205.8 + i * 2.6
			setBox(t, x0 + 0.5, y1, tz, x1 - 0.5, y1 + trayTemplate.Size.Y, tz + 2.2)
			t.Parent = cafe
		end
	end
	trayTemplate:Destroy()
	table.insert(log, "5 bakery")
end

----------------------------------------------------------------------------
-- 6. order counter and barista bench out to x -240.8
do
	local W = -240.8
	for _, name in ipairs({ "Counter", "CounterKick", "CounterTop", "BackCounter", "BackCounterTop" }) do
		for _, p in ipairs(kids(name)) do local _, y0, z0, x1, y1, z1 = bounds(p) setBox(p, W, y0, z0, x1, y1, z1) end
	end
	local shift = Vector3.new(W - (-227.0), 0, 0)
	for _, name in ipairs({ "CaseBase", "CaseGlass", "CaseFrame", "CaseTop", "CaseShelf", "Pastry" }) do
		for _, p in ipairs(kids(name)) do p.CFrame = p.CFrame + shift end
	end
	table.insert(log, "6 counters")
end

----------------------------------------------------------------------------
-- 7. staff door 6.5 wide (x -254.3 .. -247.8), 11 high
do
	local DX0, DX1, DH = -254.1, -247.8, 11
	for _, w in ipairs(kids("StaffWall", function(p) return math.abs(p.Position.Z - 319.3) < 0.5 end)) do
		local x0, y0, z0, x1, y1, z1 = bounds(w)
		if x0 > DX0 and x1 > -246 then setBox(w, DX1, y0, z0, x1, y1, z1) -- the long east part
		elseif y0 > FLOOR + 1 then setBox(w, DX0, FLOOR + DH, z0, DX1, y1, z1) end -- above the door
	end
	local post = cafe:FindFirstChild("DoorHingePost")
	local door = cafe:FindFirstChild("StaffDoor")
	local handle = cafe:FindFirstChild("StaffDoorHandle")
	local sign = cafe:FindFirstChild("StaffSign")
	local pz0, _, pz1 = select(3, bounds(post)), nil, select(6, bounds(post))
	setBox(post, DX1 - 0.1, FLOOR, pz0, DX1, FLOOR + DH, pz1)
	local _, _, dz0, _, _, dz1 = bounds(door)
	local rot = door.CFrame.Rotation
	door.Size = Vector3.new(DX1 - 0.12 - (DX0 + 0.1), DH - 0.2, door.Size.Z)
	door.CFrame = CFrame.new((DX0 + 0.1 + DX1 - 0.12) / 2, FLOOR + 0.1 + (DH - 0.2) / 2, (dz0 + dz1) / 2) * rot
	local a1 = door:FindFirstChild("Hinge")
	if a1 then a1.Position = door.CFrame:PointToObjectSpace(Vector3.new(post.Position.X, door.Position.Y, post.Position.Z)) end
	local a0 = post:FindFirstChild("Hinge")
	if a0 then a0.Position = Vector3.zero end
	if handle then handle.CFrame = CFrame.new(DX0 + 0.5, FLOOR + 4, handle.Position.Z) * handle.CFrame.Rotation end
	if sign then sign.CFrame = CFrame.new((DX0 + DX1) / 2, FLOOR + DH + 1, sign.Position.Z) * sign.CFrame.Rotation end
	table.insert(log, "7 staff door")
end

----------------------------------------------------------------------------
-- 8. main entrance 14.6 wide (z 268.7 .. 283.3, centre 276)
do
	local ZC, Z0, Z1, K = 276, 268.7, 283.3, 14.6 / 10
	for _, p in ipairs(cafe:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Wall_E_S" or p.Name == "Wall_E_N" or p.Name == "Wall_E_Top" or p.Name == "WallLining") and p.Position.X > -208 then
			local x0, y0, z0, x1, y1, z1 = bounds(p)
			if math.abs(z1 - 271) < 0.3 then setBox(p, x0, y0, z0, x1, y1, Z0)
			elseif math.abs(z0 - 281) < 0.3 then setBox(p, x0, y0, Z1, x1, y1, z1)
			elseif math.abs(z0 - 271) < 0.3 and math.abs(z1 - 281) < 0.3 then setBox(p, x0, y0, Z0, x1, y1, Z1) end
		end
	end
	local door = cafe:FindFirstChild("AutoDoor")
	for _, p in ipairs(door:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "DoorCentre" then
			local x0, y0, z0, x1, y1, z1 = bounds(p)
			local nz0, nz1 = ZC + (z0 - ZC) * K, ZC + (z1 - ZC) * K
			if z1 - z0 < 0.5 then local mid = (nz0 + nz1) / 2 nz0, nz1 = mid - (z1 - z0) / 2, mid + (z1 - z0) / 2 end
			local rot = p.CFrame.Rotation
			local sz = p.Size
			-- the panels are thin in x: stretch whichever local axis runs along world z
			local lz = if math.abs(p.CFrame.LookVector.Z) > 0.9 then Vector3.new(sz.X, sz.Y, nz1 - nz0) else Vector3.new(nz1 - nz0, sz.Y, sz.Z)
			if z1 - z0 >= 0.5 then p.Size = lz end
			p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (nz0 + nz1) / 2) * rot
			local slide = p:GetAttribute("SlideZ")
			if slide then p:SetAttribute("SlideZ", slide * K) end
		end
	end
	for _, b in ipairs(kids("PushButton")) do b.CFrame = b.CFrame + Vector3.new(0, 0, Z0 - 1.6 - b.Position.Z) end
	table.insert(log, "8 entrance")
end

----------------------------------------------------------------------------
-- 9. 2F rail bar, stools, long tables
do
	local bar = kids("MezzBar")[1]
	local _, y0, _, _, y1 = bounds(bar)
	local ny0, ny1 = MEZZ + (y0 - MEZZ) * 1.4, MEZZ + (y1 - MEZZ) * 1.4
	setBox(bar, -254.5, ny0, 200.5, -249.7, ny1, 327.6)
	-- the things left on the bar go up with it
	for _, p in ipairs(cafe:GetChildren()) do
		if p:IsA("BasePart") and p.Position.Y > MEZZ and p.Position.X > -255 and p.Position.X < -251
			and ({ LaptopBase = 1, LaptopScreen = 1, LaptopDisplay = 1, CoffeeCup = 1, CoffeeTop = 1, Receipt = 1, Buzzer = 1, BuzzerLight = 1, Phone = 1 })[p.Name] then
			p.CFrame = p.CFrame + Vector3.new(0, ny1 - y1, 0)
		end
	end
	local stools = kids("BarStool", function(p) return p.Position.Y > MEZZ end)
	local proto = cloneAll(setAt(STOOL, stools[1].Position.X, stools[1].Position.Z, 1.2, MEZZ, MEZZ + 8))
	for _, s in ipairs(stools) do for _, p in ipairs(setAt(STOOL, s.Position.X, s.Position.Z, 1.2, MEZZ, MEZZ + 8)) do p:Destroy() end end
	local o = proto[1].Position
	scaleGroup(proto, Vector3.new(o.X, MEZZ, o.Z), 1.4)
	for _, z in ipairs(evenly(200.5, 327.6, 17)) do move(cloneAll(proto), Vector3.new(-246.3 - o.X, 0, z - o.Z)) end
	for _, p in ipairs(proto) do p:Destroy() end
	-- long tables
	local CSTOOL = { CafeStool = true, CafeStoolCushion = true }
	local tables = kids("CafeTable", function(p) return p.Position.Y > MEZZ end)
	table.sort(tables, function(a, b) return a.Position.Z < b.Position.Z end)
	local sp = kids("CafeStool", function(p) return p.Position.Y > MEZZ end)[1]
	local sproto = cloneAll(setAt(CSTOOL, sp.Position.X, sp.Position.Z, 1.2, MEZZ, MEZZ + 8))
	for _, p in ipairs(cafe:GetChildren()) do if CSTOOL[p.Name] and p:IsA("BasePart") and p.Position.Y > MEZZ and not table.find(sproto, p) then p:Destroy() end end
	local so = sproto[1].Position
	scaleGroup(sproto, Vector3.new(so.X, MEZZ, so.Z), 1.4)
	local legs = kids("TableLeg", function(p) return p.Position.Y > MEZZ end)
	local legTemplate = legs[1]:Clone()
	for _, l in ipairs(legs) do l:Destroy() end
	local spans = { { 200.5, 231.6 }, { 246.7, 277.8 }, { 293.0, 324.0 } }
	for i, t in ipairs(tables) do
		local s = spans[i]
		local _, y0t, _, _, y1t = bounds(t)
		setBox(t, -224.1, y0t, s[1], -214.1, y1t, s[2])
		local _, ly0, _, _, ly1 = bounds(legTemplate)
		for _, lz in ipairs({ s[1] + 2.3, s[2] - 2.3 }) do
			local l = legTemplate:Clone() setBox(l, -222.6, ly0, lz - 0.25, -215.6, ly1, lz + 0.25) l.Parent = cafe
		end
		for _, z in ipairs(evenly(s[1], s[2], 4)) do move(cloneAll(sproto), Vector3.new(-210.8 - so.X, 0, z - so.Z)) end
	end
	legTemplate:Destroy()
	for _, p in ipairs(sproto) do p:Destroy() end
	table.insert(log, "9 2F")
end

----------------------------------------------------------------------------
-- 10. the stair side: one full wall instead of the slanted glass
do
	for _, p in ipairs(cafe:GetChildren()) do if p.Name == "StairRail" or p.Name == "LandingRailGlass" then p:Destroy() end end
	local w = Instance.new("Part")
	w.Name = "StairSideWall" w.Anchored = true w.Material = Enum.Material.SmoothPlastic w.Color = Color3.fromRGB(244, 243, 240)
	setBox(w, -269.9, FLOOR, 288.6, -269.4, MEZZ + 5.2, 356.2)
	w.Parent = cafe
	table.insert(log, "10 stair wall")
end

cafe:SetAttribute("CafeLayoutV3", true)
return table.concat(log, " | ")
