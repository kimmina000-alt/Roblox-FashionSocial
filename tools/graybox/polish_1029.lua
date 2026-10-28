--!nocheck
-- Polish pass, user 2026-10-29 (18). Run in Edit mode LAST in the layout chain
-- (after polish_1028). Every step marks what it changed (attribute Polish1029)
-- so running it again does nothing twice; a rebuilt zone gets it again.
--   1. beach cafe lounge: a warm LED line at the foot of every step riser,
--      the tables 1.5 nearer their sofas, all cafe table tops marble
--   2. cafe window bar + mezzanine rail bar marble; their stools become the
--      club bar stool (ArtAssets-free: copied from the club), 0.8 lower
--   3. the tables by the pool (물멍존): their round seats become the same
--      stool in white, at the old seat height
--   4. club DJ: the laptop turned 45° toward the desk, its screen 50 % clear;
--      the DJ stage and steps get the steel diamond-plate pattern
--   5. OH24: the standing sign to the other side of the door, the stickers of
--      the right window onto the left one, the stacked chairs turned round,
--      the hot water dispenser 2x, the window stools -> white club stools
local log = {}
local MARK = "Polish1029"
local function once(inst: Instance): boolean
	if inst:GetAttribute(MARK) then return false end
	inst:SetAttribute(MARK, true)
	return true
end

local G = workspace:FindFirstChild("Graybox_MainSocial")
local L = workspace:FindFirstChild("Hongdae_Layout")
local club = G and G:FindFirstChild("02_Club")
local beach = G and G:FindFirstChild("04_Beach_Aquarium")
local cafe = beach and beach:FindFirstChild("BeachCafe")
local oh24 = L and L:FindFirstChild("OH24Store")
local stoolSrc = club and club:FindFirstChild("BarStoolOHU")

local MARBLE = Color3.fromRGB(236, 233, 228)
local WHITE = Color3.fromRGB(242, 242, 240)

local function marble(p: BasePart)
	p.Material = Enum.Material.Marble
	p.Color = MARBLE
end

-- world AABB of a part
local function bounds(p: BasePart): (Vector3, Vector3)
	local c, s = p.CFrame, p.Size / 2
	local h = Vector3.new(
		math.abs(c.XVector.X) * s.X + math.abs(c.YVector.X) * s.Y + math.abs(c.ZVector.X) * s.Z,
		math.abs(c.XVector.Y) * s.X + math.abs(c.YVector.Y) * s.Y + math.abs(c.ZVector.Y) * s.Z,
		math.abs(c.XVector.Z) * s.X + math.abs(c.YVector.Z) * s.Y + math.abs(c.ZVector.Z) * s.Z)
	return p.Position - h, p.Position + h
end
local function modelTop(m: Instance): number
	local top = -math.huge
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then local _, hi = bounds(d) top = math.max(top, hi.Y) end
	end
	return top
end

-- a copy of the club bar stool with its seat top at (x, topY, z); white = recoloured
local function clubStool(parent: Instance, x: number, topY: number, z: number, white: boolean): Model?
	if not stoolSrc then return nil end
	local m = stoolSrc:Clone()
	m.Name = "ClubStool"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			if white then d.Color = if d.Name == "SeatPad" then WHITE else Color3.fromRGB(225, 225, 222) end
		end
	end
	local p = m:GetPivot()
	m:PivotTo(CFrame.new(x, p.Y + (topY - modelTop(m)), z) * p.Rotation)
	m:SetAttribute(MARK, true)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- 1. cafe lounge
if cafe then
	local steps = {}
	for _, d in ipairs(cafe:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "LoungeStep" then table.insert(steps, d) end
	end
	table.sort(steps, function(a, b) return a.Size.Y < b.Size.Y end)
	local prevTop = nil
	for _, s in ipairs(steps) do
		local lo, hi = bounds(s)
		local footY = prevTop or lo.Y
		if once(s) then
			local led = Instance.new("Part")
			led.Name = "StepLED"
			led.Anchored, led.CanCollide, led.CanQuery, led.CanTouch, led.CastShadow = true, false, false, false, false
			led.Material = Enum.Material.Neon
			led.Color = Color3.fromRGB(255, 214, 150)
			-- (thin and set into the riser like a recessed strip, user 2026-10-29 (21))
			led.Size = Vector3.new(0.06, 0.05, hi.Z - lo.Z - 0.2)
			led.CFrame = CFrame.new(lo.X + 0.02, footY + 0.06, (lo.Z + hi.Z) / 2)
			led.Parent = cafe
		end
		prevTop = hi.Y
	end
	-- lounge tables: 1.5 toward the sofa behind them (+x), legs too
	local legs = {}
	for _, d in ipairs(cafe:GetDescendants()) do if d:IsA("BasePart") and d.Name == "TableLeg" then table.insert(legs, d) end end
	local moved = 0
	for _, d in ipairs(cafe:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "CafeTable" then
			local p = d.Position
			local lounge = p.X > -330 and p.X < -270 and p.Z > 305 and p.Z < 358
			if lounge and once(d) then
				for _, leg in ipairs(legs) do
					if math.abs(leg.Position.X - p.X) < 0.6 and math.abs(leg.Position.Z - p.Z) < 0.6 then leg.CFrame += Vector3.new(1.5, 0, 0) end
				end
				d.CFrame += Vector3.new(1.5, 0, 0)
				moved += 1
			end
			marble(d)
		end
	end
	table.insert(log, "lounge LEDs " .. #steps .. ", tables moved " .. moved)
	-- the planters closer: the long one along the lounge's south side up to
	-- it, the short one between the piano stage and the lounge up to the stage
	-- (user 2026-10-29 (21)); their soil, bushes and shrubs go with them
	local plants = {}
	for _, d in ipairs(cafe:GetDescendants()) do
		if d.Name == "Bush" or d.Name == "Shrub" or d.Name == "PlanterSoil" or d.Name == "PlantCollider" then table.insert(plants, d) end
	end
	for _, pl in ipairs(cafe:GetDescendants()) do
		if pl:IsA("BasePart") and pl.Name == "Planter" and once(pl) then
			local lo, hi = bounds(pl)
			local shift = if pl.Size.X > pl.Size.Z then Vector3.new(0, 0, 1.2) else Vector3.new(-0.56, 0, 0)
			for _, d in ipairs(plants) do
				local pos = if d:IsA("Model") then d:GetPivot().Position else (d :: BasePart).Position
				if pos.X > lo.X - 0.5 and pos.X < hi.X + 0.5 and pos.Z > lo.Z - 0.5 and pos.Z < hi.Z + 0.5 then
					if d:IsA("Model") then d:PivotTo(d:GetPivot() + shift) else (d :: BasePart).CFrame += shift end
				end
			end
			pl.CFrame += shift
		end
	end

	------------------------------------------------------------ 2. bars + stools
	for _, n in ipairs({ "WindowBar", "MezzBar" }) do
		local b = cafe:FindFirstChild(n, true)
		if b and b:IsA("BasePart") then marble(b) end
	end
	local swapped = 0
	for _, m in ipairs(cafe:GetDescendants()) do
		if m:IsA("Model") and m.Name == "BarStoolOHU" and once(m) then
			local pos = m:GetPivot().Position
			local top = modelTop(m)
			-- the Seat that belongs to it (a "BarStool" right over it)
			for _, s in ipairs(cafe:GetDescendants()) do
				if s:IsA("Seat") and s.Name == "BarStool" and math.abs(s.Position.X - pos.X) < 0.5 and math.abs(s.Position.Z - pos.Z) < 0.5 then
					s.CFrame -= Vector3.new(0, 0.8, 0)
				end
			end
			clubStool(m.Parent, pos.X, top - 0.8, pos.Z, false)
			m:Destroy()
			swapped += 1
		end
	end
	table.insert(log, "cafe bar stools " .. swapped)

	------------------------------------------------------------ 3. pool tables
	local pool = cafe:FindFirstChild("PoolBasin", true)
	local poolSeats = 0
	if pool then
		for _, c in ipairs(cafe:GetDescendants()) do
			if c:IsA("BasePart") and c.Name == "CafeChair" and (c.Position - pool.Position).Magnitude < 60 and once(c) then
				local top = c.Position.Y + c.Size.Y / 2
				for _, k in ipairs(cafe:GetDescendants()) do
					if k:IsA("BasePart") and k.Name == "ChairCushion" and math.abs(k.Position.X - c.Position.X) < 0.5 and math.abs(k.Position.Z - c.Position.Z) < 0.5 then
						top = math.max(top, select(2, bounds(k)).Y)
						k.Transparency = 1
					end
				end
				c.Transparency = 1 -- (stays as the seat / collider)
				clubStool(c.Parent, c.Position.X, top, c.Position.Z, true)
				poolSeats += 1
			end
		end
	end
	table.insert(log, "pool seats " .. poolSeats)

	------------------------------------------------ 3b. (user 2026-10-29 (22))
	-- the mezzanine tables' round seats -> the same white stools
	local mezz = 0
	for _, s in ipairs(cafe:GetDescendants()) do
		if s:IsA("Seat") and s.Name == "CafeStool" and once(s) then
			local top = s.Position.Y + s.Size.Y / 2
			for _, k in ipairs(cafe:GetDescendants()) do
				if k:IsA("BasePart") and k.Name == "CafeStoolCushion" and math.abs(k.Position.X - s.Position.X) < 0.5 and math.abs(k.Position.Z - s.Position.Z) < 0.5 then
					top = math.max(top, select(2, bounds(k)).Y)
					k.Transparency = 1
				end
			end
			s.Transparency = 1
			clubStool(s.Parent, s.Position.X, top, s.Position.Z, true)
			mezz += 1
		end
	end
	-- the coffee bag shelf on the wall goes
	for _, d in ipairs(cafe:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "BagShelf" or d.Name == "CoffeeBag") then d:Destroy() end
	end
	-- the floor light lines by the planters go; a soft light set under every
	-- planter instead (a glowing strip just round its foot)
	for _, d in ipairs(cafe:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "FloorLightLine" then d:Destroy() end
	end
	for _, pl in ipairs(cafe:GetDescendants()) do
		if pl:IsA("BasePart") and pl.Name == "Planter" and not pl:GetAttribute("Polish1029Glow") then
			pl:SetAttribute("Polish1029Glow", true)
			local lo, hi = bounds(pl)
			local glow = Instance.new("Part")
			glow.Name = "PlanterUnderGlow"
			glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
			glow.Material = Enum.Material.Neon
			glow.Color = Color3.fromRGB(255, 220, 160)
			glow.Transparency = 0.35
			glow.Size = Vector3.new(hi.X - lo.X + 0.16, 0.03, hi.Z - lo.Z + 0.16)
			glow.CFrame = CFrame.new((lo.X + hi.X) / 2, lo.Y + 0.015, (lo.Z + hi.Z) / 2)
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Top
			l.Color = Color3.fromRGB(255, 210, 150)
			l.Range = 4
			l.Brightness = 1.2
			l.Angle = 160
			l.Parent = glow
			glow.Parent = pl.Parent
			-- lift the planter a hair so the glow shows under its edge
			pl.CFrame += Vector3.new(0, 0.06, 0)
		end
	end
	-- the stair: the tall side wall goes, a clear glass railing follows the
	-- steps and the landing instead
	local wall = cafe:FindFirstChild("StairSideWall", true)
	if wall and wall:IsA("BasePart") then
		local x = wall.Position.X
		local oldGlass = cafe:FindFirstChild("StairSideGlass", true)
		if oldGlass then oldGlass:Destroy() end
		wall:Destroy()
		local steps = {}
		for _, d in ipairs(cafe:GetDescendants()) do if d:IsA("BasePart") and d.Name == "Stair" then table.insert(steps, d) end end
		table.sort(steps, function(a, b) return a.Position.Y < b.Position.Y end)
		local first, last = steps[1], steps[#steps]
		local landing = cafe:FindFirstChild("StairLanding", true)
		local GLASS = Color3.fromRGB(220, 238, 255)
		local function pane(name, a: Vector3, b: Vector3, h: number)
			-- a sloped (or flat) glass panel from a to b on the railing line, h high
			local mid, dir = (a + b) / 2, b - a
			local flat = Vector3.new(0, 0, dir.Z).Unit
			local cf = CFrame.lookAt(mid + Vector3.new(0, h / 2, 0), mid + Vector3.new(0, h / 2, 0) + flat)
			local slope = math.atan2(dir.Y, math.abs(dir.Z))
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Material = Enum.Material.Glass
			p.Color = GLASS
			p.Transparency = 0.6
			p.CastShadow = false
			p.Size = Vector3.new(0.12, h, dir.Magnitude)
			p.CFrame = cf * CFrame.Angles(slope, 0, 0)
			p.Parent = cafe
			local rail = Instance.new("Part")
			rail.Name = name .. "Rail"
			rail.Anchored, rail.CanCollide, rail.CastShadow = true, false, false
			rail.Material = Enum.Material.Metal
			rail.Color = Color3.fromRGB(200, 202, 206)
			rail.Size = Vector3.new(0.18, 0.12, dir.Magnitude)
			rail.CFrame = p.CFrame * CFrame.new(0, h / 2 + 0.06, 0)
			rail.Parent = cafe
		end
		local function stepTop(s: BasePart) return s.Position.Y + s.Size.Y / 2 end
		local z0 = first.Position.Z - first.Size.Z / 2
		local z1 = last.Position.Z + last.Size.Z / 2
		pane("StairRailGlass", Vector3.new(x, stepTop(first) - 0.5, z0), Vector3.new(x, stepTop(last), z1), 3.6)
		if landing then
			local lz1 = landing.Position.Z + landing.Size.Z / 2
			pane("StairRailGlass", Vector3.new(x, stepTop(landing), z1), Vector3.new(x, stepTop(landing), lz1), 3.6)
		end
	end
	table.insert(log, "mezz stools " .. mezz)
end

---------------------------------------------------------------- 4. club DJ
if club then
	local dj = club:FindFirstChild("DJ_Console")
	local stand = dj and dj:FindFirstChild("LaptopStand")
	local screen = dj and dj:FindFirstChild("LaptopScreen")
	if stand and screen and once(stand) then
		local pivot = CFrame.new(stand.Position)
		local turn = pivot * CFrame.Angles(0, math.rad(45), 0) * pivot:Inverse()
		stand.CFrame = turn * stand.CFrame
		screen.CFrame = turn * screen.CFrame
		screen.Transparency = 0.5
		table.insert(log, "DJ laptop")
	end
	local n = 0
	for _, p in ipairs(club:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "DJ_Stage" or p.Name == "DJ_Step") then
			p.Material = Enum.Material.DiamondPlate
			n += 1
		end
	end
	table.insert(log, "DJ stage plate " .. n)
end

---------------------------------------------------------------- 5. OH24
if oh24 then
	-- the standing sign: right of the door as seen from the street (-x), so
	-- its arrow points at the door
	local stack = oh24:FindFirstChild("OH24FrontStack")
	if stack then
		local parts = {}
		for _, n in ipairs({ "BannerBase", "BannerPole", "BannerFlag" }) do
			local p = stack:FindFirstChild(n, true)
			if p then table.insert(parts, p) end
		end
		if #parts > 0 and once(parts[1]) then
			local dx = -121 - parts[1].Position.X -- (past the chairs and crates, which moved there too)
			for _, p in ipairs(parts) do p.CFrame += Vector3.new(dx, 0, 0) end
			table.insert(log, "OH24 sign moved")
		end
		-- (user 2026-10-29 (19)) the folded round tables go; the stacked chairs
		-- and the crates move 22 to the right of the door with the sign
		for _, d in ipairs(stack:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "FoldedTableTop" then d:Destroy() end
		end
		for _, d in ipairs(stack:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "StackChair" or d.Name == "StackCollide" or d.Name == "Crate" or d.Name == "CrateRim")
				and d.Position.X > -100 and not d:GetAttribute("Polish1029Moved") then
				d:SetAttribute("Polish1029Moved", true)
				d.CFrame += Vector3.new(-22, 0, 0)
			end
		end
		-- the stacked chairs face the street (turned round each column)
		for _, c in ipairs(stack:GetDescendants()) do
			if c:IsA("BasePart") and c.Name == "StackChair" and once(c) then
				c.CFrame = CFrame.new(c.Position) * CFrame.Angles(0, math.pi, 0) * c.CFrame.Rotation
			end
		end
	end
	-- the right window's stickers onto the left window (door at x -102)
	local spots = {}
	for _, d in ipairs(oh24:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "GlassBanner" and once(d) then
			-- 호빵 · 어묵: inside the east glass (the side facing 광화문), read
			-- from outside (user 2026-10-29 (21))
			-- (on the outer face of the glass: a SurfaceGui behind Glass does not draw)
			d.CFrame = CFrame.new(-55.75, 12.4, 99) * CFrame.Angles(0, -math.pi / 2, 0)
			local g = d:FindFirstChildOfClass("SurfaceGui")
			if g then g.Face = Enum.NormalId.Front end
		elseif d:IsA("BasePart") and d.Position.X < -105 and d.Position.Z < 66 and (d.Name == "GlassPoster" or d.Name == "GlassSticker") and once(d) then
			local to = spots[d.Name]
			if d.Name == "GlassPoster" then to = { -87.5, d.Position.Y }
			-- (ATM and 택배 side by side over the 신상품 도시락 poster, user 2026-10-29 (20))
			elseif d.Name == "GlassSticker" then to = { if d.Position.X > -108.5 then -93.0 else -95.2, 9.4 } end
			d.CFrame = CFrame.new(to[1], to[2], d.Position.Z) * d.CFrame.Rotation
		end
	end
	-- hot water dispenser twice the size, standing where it stood
	local hw = oh24:FindFirstChild("HotWater")
	if hw and once(hw) then
		local base = Vector3.new(hw.Position.X, hw.Position.Y - hw.Size.Y / 2, hw.Position.Z - hw.Size.Z / 2)
		for _, n in ipairs({ "HotWater", "HotWaterTap", "HotWaterTray" }) do
			local p = oh24:FindFirstChild(n)
			if p then
				p.Size *= 2
				p.CFrame = CFrame.new(base + (p.Position - base) * 2) * p.CFrame.Rotation
			end
		end
		-- the 전자레인지 · 온수 sign over it goes up clear of the bigger dispenser
		local sign = oh24:FindFirstChild("StationSign")
		if sign then sign.CFrame += Vector3.new(0, (hw.Position.Y + hw.Size.Y / 2 + 0.9) - sign.Position.Y, 0) end
		table.insert(log, "hot water 2x")
	end
	-- window stools: white club stools at the seat height, the old look hidden
	local n = 0
	for _, s in ipairs(oh24:GetDescendants()) do
		if s:IsA("Seat") and s.Name == "WindowStool" and once(s) then
			local top = s.Position.Y + s.Size.Y / 2
			s.Transparency = 1
			for _, leg in ipairs(oh24:GetDescendants()) do
				if leg:IsA("BasePart") and leg.Name == "StoolLeg" and math.abs(leg.Position.X - s.Position.X) < 1.2 and math.abs(leg.Position.Z - s.Position.Z) < 1.2 and leg.Position.Y < top then
					leg.Transparency = 1
					leg.CanCollide = false
				end
			end
			clubStool(oh24, s.Position.X, top, s.Position.Z, true)
			n += 1
		end
	end
	table.insert(log, "OH24 stools " .. n)
end

return table.concat(log, " | ")
