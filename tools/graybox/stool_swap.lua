-- OHU backless bar stool (user photo 2026-10-27, D-442) at the club bar and
-- the beach cafe's window bar: run in Edit mode after the layout chain
-- (… → oh24_tweaks). The sitting Seat of each stool stays (invisible); its
-- old cushion / legs go and the stool is built under it. Also refreshes the
-- template ServerStorage.ArtAssets.BarStoolOHU. Runs once per place
-- (attribute StoolSwapV1 on each zone model).
--   top: a thin fabric pad on a thinner shell, a small gap between them;
--   four thin metal legs splayed out to the floor; a ring for the feet.

local BLACK, SHELL = Color3.fromRGB(28, 28, 30), Color3.fromRGB(22, 22, 24)
local PAD_H, GAP, SHELL_H = 0.16, 0.06, 0.12

-- the stool with its seat top at `top` (world), floor at `floorY`, seat d wide
local function build(parent: Instance, x: number, z: number, floorY: number, top: number, d: number): Model
	local m = Instance.new("Model")
	m.Name = "BarStoolOHU"
	local function cyl(name, dia, h, cf, col, mat)
		local p = Instance.new("Part")
		p.Name = name p.Shape = Enum.PartType.Cylinder p.Anchored = true p.CanCollide = false p.CanQuery = false
		p.Size = Vector3.new(h, dia, dia) p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90)) p.Color = col
		p.Material = mat p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
	end
	local function rod(name, a: Vector3, b: Vector3, dia)
		local p = Instance.new("Part")
		p.Name = name p.Shape = Enum.PartType.Cylinder p.Anchored = true p.CanCollide = false p.CanQuery = false
		p.Size = Vector3.new((b - a).Magnitude, dia, dia) p.Color = BLACK p.Material = Enum.Material.Metal
		p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		p.Parent = m
	end
	cyl("SeatPad", d, PAD_H, CFrame.new(x, top - PAD_H / 2, z), BLACK, Enum.Material.Fabric)
	local shellTop = top - PAD_H - GAP
	cyl("SeatShell", d * 0.86, SHELL_H, CFrame.new(x, shellTop - SHELL_H / 2, z), SHELL, Enum.Material.SmoothPlastic)
	local legTop = shellTop - SHELL_H
	local H = legTop - floorY
	local r0, r1 = d * 0.28, d * 0.49
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		rod("Leg", Vector3.new(x + math.cos(a) * r0, legTop, z + math.sin(a) * r0), Vector3.new(x + math.cos(a) * r1, floorY, z + math.sin(a) * r1), 0.09)
	end
	local ry = floorY + H * 0.32
	local rr = r1 + (r0 - r1) * ((ry - floorY) / H)
	local n = 16
	for i = 0, n - 1 do
		local a0, a1 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
		local p0 = Vector3.new(x + math.cos(a0) * rr, ry, z + math.sin(a0) * rr)
		local p1 = Vector3.new(x + math.cos(a1) * rr, ry, z + math.sin(a1) * rr)
		rod("FootRing", p0, p1 + (p1 - p0).Unit * 0.04, 0.08)
	end
	m.WorldPivot = CFrame.new(x, floorY, z)
	m.Parent = parent
	return m
end

local log = {}

-- the template (floor centre at the origin, seat top 3)
do
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local old = art:FindFirstChild("BarStoolOHU") if old then old:Destroy() end
	build(art, 0, 0, 0, 3, 1.6)
end

-- the club bar: BarStool is the visible seat itself (2.2 wide), a leg under it
do
	local club = workspace.Graybox_MainSocial["02_Club"]
	if not club:GetAttribute("StoolSwapV1") then
		local n = 0
		for _, s in ipairs(club:GetDescendants()) do
			if s:IsA("Seat") and s.Name == "BarStool" then
				local leg
				for _, l in ipairs(s.Parent:GetChildren()) do
					if l.Name == "BarStoolLeg" and math.abs(l.Position.X - s.Position.X) < 0.3 and math.abs(l.Position.Z - s.Position.Z) < 0.3 then leg = l end
				end
				local floorY = if leg then leg.Position.Y - leg.Size.Y / 2 else s.Position.Y - 2.6
				local top = s.Position.Y + s.Size.Y / 2
				if leg then leg:Destroy() end
				s.Transparency = 1
				build(s.Parent, s.Position.X, s.Position.Z, floorY, top, 2.0)
				n += 1
			end
		end
		club:SetAttribute("StoolSwapV1", true)
		table.insert(log, "club " .. n)
	end
end

-- the beach cafe's window bar (1F, along the sea glass): invisible seats with
-- a round cushion and a leg under each
do
	local cafe = workspace.Graybox_MainSocial["04_Beach_Aquarium"].BeachCafe
	if not cafe:GetAttribute("StoolSwapV1") then
		local n = 0
		for _, s in ipairs(cafe:GetChildren()) do
			if s:IsA("Seat") and s.Name == "BarStool" and s.Position.Y < 10 and s.Position.X < -360 then
				local d = 1.8
				for _, p in ipairs(cafe:GetChildren()) do
					if (p.Name == "BarStoolCushion" or p.Name == "StoolLeg") and p.Position.Y < 10
						and math.abs(p.Position.X - s.Position.X) < 0.4 and math.abs(p.Position.Z - s.Position.Z) < 0.4 then
						if p.Name == "BarStoolCushion" then d = math.max(p.Size.Y, p.Size.Z) end
						p:Destroy()
					end
				end
				build(cafe, s.Position.X, s.Position.Z, 0.6, s.Position.Y + s.Size.Y / 2, d)
				n += 1
			end
		end
		cafe:SetAttribute("StoolSwapV1", true)
		table.insert(log, "cafe " .. n)
	end
end

for _, p in ipairs(workspace:GetChildren()) do if p.Name == "BarStoolPreview" then p:Destroy() end end
return table.concat(log, " | ")
