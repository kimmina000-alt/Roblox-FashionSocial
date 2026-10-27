-- Store assets in place of drawn furniture (user picks 2026-10-27, D-443):
-- run in Edit mode after stool_swap (last in the chain). Runs once per
-- target (attribute FurnitureSwapV1). Models: ServerStorage.ArtAssets
-- (place only): Sofa9 = "[⭐] Couch Mesh Sofa Modern Chair" (137820014436987,
-- one mesh, front -Z), Microwave32 = "Sleek Kitchen Microwave" (9587284235,
-- 2 parts), Register37 = "Cash Register Mesh" (132242420463750, 1 mesh).
-- The Seat parts stay (invisible), so sitting works as before.
--   1  beach cafe lounge: every plush sofa set → Sofa9 (its own grey)
--   2  club VIP booths: back sofa and side wings → Sofa9, dark
--   3  OH24: microwave → Microwave32, the till → Register37

local art = game:GetService("ServerStorage").ArtAssets
local log = {}

local function bounds(p)
	local c, s = p.CFrame, p.Size
	local ex = math.abs(c.RightVector.X) * s.X / 2 + math.abs(c.UpVector.X) * s.Y / 2 + math.abs(c.LookVector.X) * s.Z / 2
	local ey = math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2
	local ez = math.abs(c.RightVector.Z) * s.X / 2 + math.abs(c.UpVector.Z) * s.Y / 2 + math.abs(c.LookVector.Z) * s.Z / 2
	return p.Position.X - ex, p.Position.Y - ey, p.Position.Z - ez, p.Position.X + ex, p.Position.Y + ey, p.Position.Z + ez
end

-- a sofa filling the box (x0..x1, y0..y1, z0..z1), front towards `facing`
-- (a horizontal unit axis), stretched to fit
local function sofa(parent, x0, y0, z0, x1, y1, z1, facing: Vector3, color: Color3?)
	local src = art.Sofa9:FindFirstChildWhichIsA("MeshPart")
	local p = src:Clone()
	p.Name = "Sofa"
	local long = if math.abs(facing.X) > 0.5 then z1 - z0 else x1 - x0
	local deep = if math.abs(facing.X) > 0.5 then x1 - x0 else z1 - z0
	p.Size = Vector3.new(long, y1 - y0, deep)
	local c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.CFrame = CFrame.lookAt(c, c + facing)
	p.Anchored = true p.CanCollide = false p.CanQuery = false
	if color then p.Color = color end
	p.Parent = parent
	return p
end

----------------------------------------------------------------------------
-- 1. cafe lounge
do
	local cafe = workspace.Graybox_MainSocial["04_Beach_Aquarium"].BeachCafe
	if not cafe:GetAttribute("FurnitureSwapV1") then
		local SOFA = { SofaBase = true, SofaCushion = true, SofaBack = true, SofaBackRoll = true, SofaArm = true, SofaArmRoll = true }
		local bases = {}
		for _, p in ipairs(cafe:GetChildren()) do if p.Name == "SofaBase" then table.insert(bases, p) end end
		local n = 0
		for _, b in ipairs(bases) do
			local bx0, by0, bz0, bx1, _, bz1 = bounds(b)
			local x0, y0, z0, x1, y1, z1 = bx0, by0, bz0, bx1, by0, bz1
			local set = {}
			for _, p in ipairs(cafe:GetChildren()) do
				if SOFA[p.Name] and p:IsA("BasePart") and p.Position.X > bx0 - 0.6 and p.Position.X < bx1 + 0.6 and p.Position.Z > bz0 - 0.6 and p.Position.Z < bz1 + 0.6 and p.Position.Y > by0 - 0.1 and p.Position.Y < by0 + 5 then
					local a, b2, c, d, e, f = bounds(p)
					x0 = math.min(x0, a) z0 = math.min(z0, c) x1 = math.max(x1, d) z1 = math.max(z1, f) y1 = math.max(y1, e)
					table.insert(set, p)
					_ = b2
				end
			end
			for _, p in ipairs(set) do p:Destroy() end
			sofa(cafe, x0, y0, z0, x1, y1, z1, Vector3.new(-1, 0, 0)) -- (they face the sea, west)
			n += 1
		end
		cafe:SetAttribute("FurnitureSwapV1", true)
		table.insert(log, "cafe sofas " .. n)
	end
end

----------------------------------------------------------------------------
-- 2. club VIP booths
do
	local club = workspace.Graybox_MainSocial["02_Club"]
	if not club:GetAttribute("FurnitureSwapV1") then
		local DARK = Color3.fromRGB(42, 40, 46)
		local DEPTH = 4.8
		local tables = {}
		for _, p in ipairs(club:GetDescendants()) do if p.Name == "VIP_Table" then table.insert(tables, p) end end
		local n = 0
		for _, s in ipairs(club:GetDescendants()) do
			if s:IsA("BasePart") and s.Name == "VIP_BoothSeat" then
				local x0, y0, z0, x1, _, z1 = bounds(s)
				local c = s.Position
				local best, bd = nil, math.huge
				for _, t in ipairs(tables) do local d = (t.Position - c).Magnitude if d < bd then best, bd = t, d end end
				local toT = best.Position - c
				local alongX = (x1 - x0) > (z1 - z0) -- the seat's long side
				local facing = if alongX then Vector3.new(0, 0, math.sign(toT.Z)) else Vector3.new(math.sign(toT.X), 0, 0)
				-- front edge = the seat's edge towards the table, the sofa runs DEPTH back from it
				if alongX then
					local front = if facing.Z > 0 then z1 else z0
					z0, z1 = math.min(front, front - facing.Z * DEPTH), math.max(front, front - facing.Z * DEPTH)
				else
					local front = if facing.X > 0 then x1 else x0
					x0, x1 = math.min(front, front - facing.X * DEPTH), math.max(front, front - facing.X * DEPTH)
				end
				local long = if alongX then x1 - x0 else z1 - z0
				local parts = math.max(1, math.floor(long / 11 + 0.5))
				for k = 0, parts - 1 do
					if alongX then
						local a = x0 + (x1 - x0) * k / parts
						sofa(s.Parent, a, y0, z0, a + (x1 - x0) / parts, y0 + 5.2, z1, facing, DARK)
					else
						local a = z0 + (z1 - z0) * k / parts
						sofa(s.Parent, x0, y0, a, x1, y0 + 5.2, a + (z1 - z0) / parts, facing, DARK)
					end
				end
				n += parts
			end
		end
		for _, p in ipairs(club:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "VIP_BoothSeat" or p.Name == "VIP_BoothBack" or p.Name == "VIP_BoothArm" or p.Name == "VIP_BoothTuft") then p:Destroy() end
		end
		club:SetAttribute("FurnitureSwapV1", true)
		table.insert(log, "VIP sofas " .. n)
	end
end

----------------------------------------------------------------------------
-- 3. OH24 microwave and till
do
	local S = workspace.Hongdae_Layout:FindFirstChild("OH24Store", true)
	if not S:GetAttribute("FurnitureSwapV1") then
		local mw, door
		for _, p in ipairs(S:GetDescendants()) do
			if p.Name == "Microwave" then mw = p elseif p.Name == "MicrowaveDoor" then door = p end
		end
		if mw then
			local x0, y0, z0, x1, _, z1 = bounds(mw)
			local m = art.Microwave32:Clone()
			-- (its door faces -Z: turned to face the room, +Z)
			local cf, size = m:GetBoundingBox()
			local k = (x1 - x0) / size.X
			m:ScaleTo(k)
			cf, size = m:GetBoundingBox()
			local target = CFrame.new((x0 + x1) / 2, y0 + size.Y / 2, (z0 + z1) / 2) * CFrame.Angles(0, math.pi, 0)
			m:PivotTo(target * cf:ToObjectSpace(m:GetPivot()))
			m.Name = "Microwave32"
			m.Parent = S
			mw:Destroy()
			if door then door:Destroy() end
		end
		local base
		for _, p in ipairs(S:GetDescendants()) do if p.Name == "PosBase" then base = p end end
		if base then
			local _, _, _, _, top = bounds(base)
			local r = art.Register37:Clone()
			local cf, size = r:GetBoundingBox()
			r:PivotTo(CFrame.new(base.Position.X, top + size.Y / 2, base.Position.Z) * cf:ToObjectSpace(r:GetPivot())) -- (keys to the staff side, as modelled)
			r.Name = "Register37"
			r.Parent = S
			for _, p in ipairs(S:GetDescendants()) do if p.Name == "PosMonitor" or p.Name == "PosDisplay" then p:Destroy() end end
		end
		S:SetAttribute("FurnitureSwapV1", true)
		table.insert(log, "OH24 microwave + till")
	end
end

return table.concat(log, " | ")
