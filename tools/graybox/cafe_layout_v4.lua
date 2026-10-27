-- Beach cafe interior v4 (user notes 2026-10-27, D-439): run in Edit mode
-- after cafe_layout_v3 (same chain). Runs once (attribute CafeLayoutV4).
--   1  light lines on the floor: between the piano stage and the planter, and
--      between the lounge and a new planter along the lounge front
--   2  lounge: tiers 15 wide (x -329.9 .. -269.9), the protruding half steps
--      gone (invisible ramps in the aisles keep the tiers walkable), two-seat
--      sofas 1.3x longer, five rows spaced evenly, tables set apart
--   3  cake slices (the cake slice mesh, the cake pictures) in the pastry case
--   4  every chair but the lounge sofas half as wide (same seat height)
--   5  the stair wall: glass above the mezzanine floor

local cafe = workspace.Graybox_MainSocial["04_Beach_Aquarium"].BeachCafe
if cafe:GetAttribute("CafeLayoutV4") then return "already done" end
if not cafe:GetAttribute("CafeLayoutV3") then return "run cafe_layout_v3 first" end
local CS = game:GetService("CollectionService")
local FLOOR, MEZZ = 0.6, 28.6
local log = {}

local function bounds(p)
	local c, s = p.CFrame, p.Size
	local ex = math.abs(c.RightVector.X) * s.X / 2 + math.abs(c.UpVector.X) * s.Y / 2 + math.abs(c.LookVector.X) * s.Z / 2
	local ey = math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2
	local ez = math.abs(c.RightVector.Z) * s.X / 2 + math.abs(c.UpVector.Z) * s.Y / 2 + math.abs(c.LookVector.Z) * s.Z / 2
	return p.Position.X - ex, p.Position.Y - ey, p.Position.Z - ez, p.Position.X + ex, p.Position.Y + ey, p.Position.Z + ez
end
local function setBox(p, x0, y0, z0, x1, y1, z1)
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
end
local function newPart(name, color, material)
	local p = Instance.new("Part")
	p.Name = name p.Anchored = true p.Color = color p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = cafe
	return p
end
-- scale the world-horizontal extent of a part by k (the vertical stays)
local function shrinkFlat(p, k)
	local c, s = p.CFrame, p.Size
	local function f(axis, v) return if math.abs(axis.Y) > 0.9 then v else v * k end
	p.Size = Vector3.new(f(c.RightVector, s.X), f(c.UpVector, s.Y), f(c.LookVector, s.Z))
end

----------------------------------------------------------------------------
-- 2 (first: the planter goes along the new lounge front). Lounge.
local TX = { -329.9, -314.9, -299.9, -284.9, -269.9 }
local LZ0, LZ1 = 306.6, 356.2
local ROWS = { 311.6, 321.5, 331.4, 341.3, 351.2 }
do
	local tiers = {}
	for _, p in ipairs(cafe:GetChildren()) do if p.Name == "LoungeStep" then table.insert(tiers, p) end end
	table.sort(tiers, function(a, b) return a.Position.X < b.Position.X end)
	for _, p in ipairs(cafe:GetChildren()) do if p.Name == "LoungeHalfStep" then p:Destroy() end end
	local SET = { CafeTable = true, TableLeg = true, SofaBase = true, SofaCushion = true, SofaBack = true, SofaBackRoll = true, SofaArm = true, SofaArmRoll = true, Bench = true }
	for k, tier in ipairs(tiers) do
		local ox0, y0, _, ox1, y1 = bounds(tier)
		local nx0, nx1 = TX[k], TX[k + 1]
		-- this tier's sets now (all rows), and one of them as the template
		local mine = {}
		for _, p in ipairs(cafe:GetChildren()) do
			if SET[p.Name] and p:IsA("BasePart") and p.Position.X > ox0 and p.Position.X < ox1 and p.Position.Z > 300 and p.Position.Y > y1 - 0.5 and p.Position.Y < y1 + 6 then table.insert(mine, p) end
		end
		local rz = ROWS[1] -- template = the parts round the row nearest 316.6
		local best, bd = nil, math.huge
		for _, p in ipairs(mine) do if p.Name == "CafeTable" and math.abs(p.Position.Z - 316.6) < bd then best, bd = p, math.abs(p.Position.Z - 316.6) end end
		local tz = best.Position.Z
		local proto = {}
		for _, p in ipairs(mine) do if math.abs(p.Position.Z - tz) < 4 then local c = p:Clone() c.Parent = cafe table.insert(proto, c) end end
		for _, p in ipairs(mine) do p:Destroy() end
		local tableParts, sofaParts = {}, {}
		for _, p in ipairs(proto) do if p.Name == "CafeTable" or p.Name == "TableLeg" then table.insert(tableParts, p) else table.insert(sofaParts, p) end end
		-- sofa 1.3x longer (z): offsets and the long pieces, arms stay thin
		local sx0, sx1 = math.huge, -math.huge
		for _, p in ipairs(sofaParts) do local a, _, _, b = bounds(p) sx0 = math.min(sx0, a) sx1 = math.max(sx1, b) end
		for _, p in ipairs(sofaParts) do
			local _, _, z0, _, _, z1 = bounds(p)
			if z1 - z0 > 2.5 and p.Name ~= "Bench" then
				local c, s = p.CFrame, p.Size
				local function f(axis, v) return if math.abs(axis.Z) > 0.9 then v * 1.3 else v end
				p.Size = Vector3.new(f(c.RightVector, s.X), f(c.UpVector, s.Y), f(c.LookVector, s.Z))
			end
			p.CFrame = CFrame.new(p.Position.X, p.Position.Y, tz + (p.Position.Z - tz) * 1.3) * p.CFrame.Rotation
		end
		-- the sofa to the tier's east end (1 in), the table 4.2 in from the west
		local dS = (nx1 - 1.0) - sx1
		for _, p in ipairs(sofaParts) do p.CFrame = p.CFrame + Vector3.new(dS, 0, 0) end
		local tbl = nil
		for _, p in ipairs(tableParts) do if p.Name == "CafeTable" then tbl = p end end
		local dT = (nx0 + 4.2) - tbl.Position.X
		for _, p in ipairs(tableParts) do p.CFrame = p.CFrame + Vector3.new(dT, 0, 0) end
		setBox(tier, nx0, y0, LZ0, nx1, y1, LZ1)
		for _, z in ipairs(ROWS) do
			for _, p in ipairs(proto) do
				local c = p:Clone()
				c.CFrame = c.CFrame + Vector3.new(0, 0, z - tz)
				if c.Name == "CafeTable" then CS:AddTag(c, "CafeTable") end
				c.Parent = cafe
			end
		end
		for _, p in ipairs(proto) do p:Destroy() end
		-- invisible ramps up to this tier in each aisle (Humanoids do not climb 2)
		local aisles = { { LZ0, ROWS[1] - 4.3 } }
		for i = 1, #ROWS - 1 do table.insert(aisles, { ROWS[i] + 4.3, ROWS[i + 1] - 4.3 }) end
		for _, a in ipairs(aisles) do
			if a[2] - a[1] > 0.8 then
				local w = Instance.new("WedgePart")
				w.Name = "LoungeRamp" w.Anchored = true w.Transparency = 1 w.CanQuery = false
				local run = 3
				w.Size = Vector3.new(a[2] - a[1], 2, run)
				-- rises east (the wedge's tall end is its +Z), from the tier below to this one
				local c = Vector3.new(nx0 - run / 2, y1 - 1, (a[1] + a[2]) / 2)
				w.CFrame = CFrame.fromMatrix(c, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
				w.Parent = cafe
			end
		end
		_ = rz
	end
	table.insert(log, "2 lounge")
end

----------------------------------------------------------------------------
-- 1. a planter along the lounge front, light lines on the floor
do
	local vp = cafe:FindFirstChild("Planter")
	local vx0, vy0, vz0, vx1, vy1, vz1 = bounds(vp)
	local hp = vp:Clone() hp.Name = "Planter" hp.Parent = cafe
	local PZ0, PZ1 = LZ0 - 1.4 - (vx1 - vx0), LZ0 - 1.4
	setBox(hp, TX[1], vy0, PZ0, TX[5] - 0.6, vy1, PZ1)
	local soil = cafe:FindFirstChild("PlanterSoil")
	if soil then
		local s2 = soil:Clone() s2.Parent = cafe
		local _, sy0, _, _, sy1 = bounds(soil)
		setBox(s2, TX[1] + 0.3, sy0, PZ0 + 0.3, TX[5] - 0.9, sy1, PZ1 - 0.3)
	end
	-- the shrubs of the first planter, repeated along the new one
	local shrub
	for _, m in ipairs(cafe:GetChildren()) do
		if m:IsA("Model") and m.Name ~= "GrandPiano" and m.Name ~= "CafePotPlant" then
			local pv = m:GetPivot().Position
			if pv.X > vx0 - 0.5 and pv.X < vx1 + 0.5 and pv.Z > vz0 and pv.Z < vz1 and pv.Y < 8 then shrub = m break end
		end
	end
	if shrub then
		local pv = shrub:GetPivot()
		for x = TX[1] + 2, TX[5] - 2.5, 3.6 do
			local c = shrub:Clone()
			c:PivotTo(CFrame.new(x, pv.Y, (PZ0 + PZ1) / 2) * pv.Rotation * CFrame.Angles(0, x % 3, 0))
			c.Parent = cafe
		end
	end
	local LIGHT = Color3.fromRGB(255, 226, 185)
	local function line(x0, z0, x1, z1)
		local p = newPart("FloorLightLine", LIGHT, Enum.Material.Neon)
		p.CanCollide = false p.CanQuery = false p.CastShadow = false
		setBox(p, x0, FLOOR, z0, x1, FLOOR + 0.04, z1)
		local l = Instance.new("SurfaceLight") l.Face = Enum.NormalId.Top l.Brightness = 0.8 l.Range = 6 l.Angle = 120 l.Color = LIGHT l.Parent = p
	end
	-- between the piano stage (east edge) and the planter's west side
	local stageEast = -math.huge
	for _, p in ipairs(cafe:GetChildren()) do if p.Name == "PianoStage" then local _, _, _, x1 = bounds(p) stageEast = math.max(stageEast, x1) end end
	local mid = (stageEast + vx0) / 2
	line(mid - 0.2, vz0, mid + 0.2, vz1)
	-- between the new planter and the lounge front
	line(TX[1], PZ1 + 0.5, TX[5] - 0.6, PZ1 + 0.9)
	table.insert(log, "1 planter + light lines")
end

----------------------------------------------------------------------------
-- 3. cake slices in the pastry case
do
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local slice = art and art:FindFirstChild("CakeSlice")
	local TEX = { "rbxassetid://102516932569219", "rbxassetid://103870621394923", "rbxassetid://89350653220271",
		"rbxassetid://126836821332506", "rbxassetid://135652144647835", "rbxassetid://102152604244426" }
	local n = 0
	if slice then
		for _, p in ipairs(cafe:GetChildren()) do
			if p.Name == "Pastry" then
				n += 1
				local c = slice:Clone()
				c.Name = "CakeDisplay"
				c.Anchored = true c.CanCollide = false c.CanQuery = false
				c.Size = Vector3.new(1.25, 0.75, 1.25)
				c.TextureID = TEX[(n - 1) % #TEX + 1]
				local _, y0 = bounds(p)
				-- point to the staff side, the cut face to the customers (+z: the room)
				c.CFrame = CFrame.new(p.Position.X, y0 + c.Size.Y / 2, p.Position.Z) * CFrame.Angles(0, math.rad(90 + (n % 3 - 1) * 12), 0)
				c.Parent = cafe
				p:Destroy()
			end
		end
	end
	table.insert(log, "3 cakes " .. n)
end

----------------------------------------------------------------------------
-- 4. chairs half as wide (window bar and rail bar stools, tub chairs, the 2F stools)
do
	local CHAIR = { BarStool = true, BarStoolCushion = true, StoolLeg = true, CafeChair = true, ChairCushion = true, CafeStool = true, CafeStoolCushion = true }
	local n = 0
	for _, p in ipairs(cafe:GetChildren()) do
		if CHAIR[p.Name] and p:IsA("BasePart") then shrinkFlat(p, 0.5) n += 1 end
	end
	table.insert(log, "4 chairs " .. n)
end

----------------------------------------------------------------------------
-- 5. the stair wall: glass above the mezzanine floor
do
	local w = cafe:FindFirstChild("StairSideWall")
	if w then
		local x0, y0, z0, x1, y1, z1 = bounds(w)
		setBox(w, x0, y0, z0, x1, MEZZ, z1)
		local g = newPart("StairSideGlass", Color3.fromRGB(200, 228, 238), Enum.Material.Glass)
		g.Transparency = 0.7
		setBox(g, x0, MEZZ, z0, x1, y1, z1)
	end
	table.insert(log, "5 stair glass")
end

cafe:SetAttribute("CafeLayoutV4", true)
return table.concat(log, " | ")
