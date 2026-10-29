--!nocheck
-- Polish pass, user 2026-10-30. Run in Edit mode LAST in the layout chain
-- (after polish_1029). Each step marks what it changed (attribute Polish1030)
-- so running it again does nothing twice; a rebuilt zone gets it again.
-- Assets are copied from ServerStorage.NewAssets1030 (scripts stripped):
--   BeachMatM1        "Blanket Sand Beach Mat ..." (109208469498541), 1 mesh
--   IceBinB1          "Ice Storage Bin ..." (102987011191032), 17 parts
--   CoolerLootBox     "Rec Royale Loot Box" (9461294854, SonicEnderZ), 1 mesh
--   CoffeeMachineAsh  "Coffee Machine" (12520208389, Ashbashthesmash), 47 parts
--   1. beach: the mats become the blanket mesh in many colours; the ice boxes
--      take turns between the bin and the green cooler
--   2. beach cafe counter: the pastry case down on the counter (no riser), its
--      three tiers taller with room over the cakes
--   3. the header over the counter down to just over the menu boards, ORDER &
--      PICK UP in one line on it over the boards; the menu boards bigger
--   4. the till → Register37 (the 국밥집 / OH24 one)
--   5. the work bench: two coffee machines, cup stacks, lids, a pitcher rack
--   6. two acrylic menu stands on the counter facing the customers
local log = {}
local MARK = "Polish1030"
local function once(inst: Instance): boolean
	if inst:GetAttribute(MARK) then return false end
	inst:SetAttribute(MARK, true)
	return true
end

local SS = game:GetService("ServerStorage")
local NEW = SS:FindFirstChild("NewAssets1030")
local ART = SS:FindFirstChild("ArtAssets")
local G = workspace:FindFirstChild("Graybox_MainSocial")
local beach = G and G:FindFirstChild("04_Beach_Aquarium")
local cafe = beach and beach:FindFirstChild("BeachCafe")

local function part(name, size, cf, color, parent, opt)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opt and opt.t) or 0
	p.CanCollide = opt and opt.collide or false
	p.CanTouch = false
	p.CastShadow = not (opt and opt.noshadow)
	if opt and opt.shape then p.Shape = opt.shape end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
-- a copy of a model, its bounding box bottom centre at `at`, turned `yaw`
local function place(src: Model, parent: Instance, at: Vector3, yaw: number, scale: number?): Model
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("Camera") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanTouch = false d.CanQuery = false end
	end
	if scale and scale ~= 1 then m:ScaleTo(m:GetScale() * scale) end
	local cf, size = m:GetBoundingBox()
	m:PivotTo(CFrame.new(at.X, at.Y + size.Y / 2, at.Z) * CFrame.Angles(0, yaw, 0) * cf:ToObjectSpace(m:GetPivot()))
	m:SetAttribute(MARK, true)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- 1. beach mats + boxes
do
	local mat = NEW and NEW:FindFirstChild("BeachMatM1")
	local bin = NEW and NEW:FindFirstChild("IceBinB1")
	local loot = NEW and NEW:FindFirstChild("CoolerLootBox")
	-- (pastels and brights, one after another)
	local TINTS = { Color3.fromRGB(255, 170, 200), Color3.fromRGB(150, 210, 255), Color3.fromRGB(160, 235, 190), Color3.fromRGB(255, 225, 120),
		Color3.fromRGB(210, 175, 255), Color3.fromRGB(255, 160, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 200, 200) }
	local nMat, nBox, k = 0, 0, 0
	for _, spot in ipairs(workspace:GetDescendants()) do
		if not (spot:IsA("Model") and spot.Name:match("^BeachSpot_")) then continue end
		-- the mat: the old slab and stripes hidden (the sit seats stay), the blanket on it
		local slab
		for _, d in ipairs(spot:GetChildren()) do if d.Name == "Mat" and d:IsA("BasePart") then slab = d end end
		if slab and mat and once(slab) then
			k += 1
			for _, d in ipairs(spot:GetChildren()) do
				if d:IsA("BasePart") and (d.Name == "Mat" or d.Name == "MatStripe") then d.Transparency = 1 end
			end
			local m = mat:Clone()
			local mp = m:FindFirstChildWhichIsA("MeshPart", true)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Camera") then d:Destroy() end
			end
			if mp then
				-- the blanket laid on the slab's footprint (4.6 x 7), thin
				mp.Size = Vector3.new(slab.Size.X, 0.35, slab.Size.Z)
				mp.CFrame = slab.CFrame * CFrame.new(0, -slab.Size.Y / 2 + 0.18, 0)
				mp.Anchored, mp.CanCollide, mp.CanTouch, mp.CanQuery, mp.CastShadow = true, false, false, false, false
				local tint = TINTS[(k - 1) % #TINTS + 1]
				mp.Color = tint
				for _, t in ipairs(mp:GetChildren()) do if t:IsA("Texture") or t:IsA("Decal") then t.Color3 = tint end end
			end
			m.Name = "BeachMat"
			m:SetAttribute(MARK, true)
			m.Parent = spot
			nMat += 1
		end
		-- the ice box: the bin and the green cooler in turn, the old box hidden
		local box
		for _, d in ipairs(spot:GetChildren()) do if d.Name == "IceBox" and d:IsA("BasePart") then box = d end end
		if box and once(box) then
			local src = if nBox % 2 == 0 then loot else bin
			if src then
				for _, d in ipairs(spot:GetChildren()) do
					if d:IsA("BasePart") and (d.Name == "IceBox" or d.Name == "IceBoxLid") then d.Transparency = 1 end
				end
				local _, s0 = src:GetBoundingBox()
				-- about as big as the old box (2.7 long, 2 tall)
				local scale = if src == loot then 3.6 / math.max(s0.X, s0.Z) else 2.6 / s0.Y
				local floor = box.Position.Y - box.Size.Y / 2
				local m = place(src, spot, Vector3.new(box.Position.X, floor, box.Position.Z), math.rad(90 + (nBox * 37) % 40 - 20), scale)
				m.Name = "IceBoxModel"
				nBox += 1
			end
		end
	end
	table.insert(log, string.format("beach mats %d, boxes %d", nMat, nBox))
end

---------------------------------------------------------------- 2. pastry case
-- (the sign text is set every run: cheap, and it fixes a copy made before)
do
	local sign = cafe and cafe:FindFirstChild("OrderPickupSign")
	local g = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
	local l = g and g:FindFirstChildWhichIsA("TextLabel")
	if l and cafe:GetAttribute(MARK) then
		l.TextWrapped, l.TextScaled, l.Text, l.TextColor3 = false, true, "ORDER  &  PICK  UP", Color3.fromRGB(96, 96, 100)
	end
end
if cafe and once(cafe) then
	local case = {}
	for _, d in ipairs(cafe:GetChildren()) do
		if d:IsA("BasePart") and (d.Name:match("^Case") or d.Name == "CakeDisplay" or d.Name == "Pastry") then table.insert(case, d) end
	end
	local base, riser
	local shelves = {}
	for _, d in ipairs(case) do
		if d.Name == "CaseBase" then base = d elseif d.Name == "CaseRiser" then riser = d elseif d.Name == "CaseShelf" then table.insert(shelves, d) end
	end
	if base and #shelves == 3 then
		table.sort(shelves, function(a, b) return a.Position.Y < b.Position.Y end)
		local counterTop = (if riser then riser.Position.Y - riser.Size.Y / 2 else base.Position.Y - base.Size.Y / 2)
		if riser then riser:Destroy() end
		local GAP = 1.75 -- tier to tier (was 1.0): about a cake's height of room over each
		local oldTop, newTop = {}, {}
		local baseTop = counterTop + base.Size.Y
		for i, s in ipairs(shelves) do
			oldTop[i] = s.Position.Y + s.Size.Y / 2
			local y0 = baseTop + (i - 1) * GAP
			s.CFrame = s.CFrame + Vector3.new(0, y0 + s.Size.Y / 2 - s.Position.Y, 0)
			newTop[i] = y0 + s.Size.Y
		end
		local caseTopY = baseTop + 3 * GAP + 0.1
		for _, d in ipairs(case) do
			if not d.Parent then continue end
			local c = d.Position
			if d == base then
				d.CFrame = d.CFrame + Vector3.new(0, counterTop + d.Size.Y / 2 - c.Y, 0)
			elseif d.Name == "CaseFrame" or d.Name == "CaseGlass" then
				d.Size = Vector3.new(d.Size.X, caseTopY - baseTop, d.Size.Z)
				d.CFrame = d.CFrame.Rotation + Vector3.new(c.X, (baseTop + caseTopY) / 2, c.Z)
			elseif d.Name == "CaseTop" then
				d.CFrame = d.CFrame + Vector3.new(0, caseTopY + d.Size.Y / 2 - c.Y, 0)
			elseif d.Name == "CakeDisplay" or d.Name == "Pastry" then
				-- the tier it stands on: the highest old shelf top under it
				local bottom = c.Y - d.Size.Y / 2
				local tier = 1
				for i = 1, 3 do if oldTop[i] <= bottom + 0.05 then tier = i end end
				d.CFrame = d.CFrame + Vector3.new(0, newTop[tier] - oldTop[tier], 0)
			end
		end
		table.insert(log, string.format("case on counter %.2f, tiers %.2f/%.2f/%.2f", counterTop, newTop[1], newTop[2], newTop[3]))
	end

	---------------------------------------------------------------- 3. header, sign, menus
	local header = cafe:FindFirstChild("StaffHeader")
	local HEADER_BOTTOM = 16.6
	if header then
		local top = header.Position.Y + header.Size.Y / 2
		header.Size = Vector3.new(header.Size.X, top - HEADER_BOTTOM, header.Size.Z)
		header.CFrame = header.CFrame.Rotation + Vector3.new(header.Position.X, (top + HEADER_BOTTOM) / 2, header.Position.Z)
	end
	-- the boards: five side by side, wider and taller (x -240..-209, y 10.2..15.4)
	local boards = {}
	for _, d in ipairs(cafe:GetChildren()) do if d.Name == "MenuBoard" and d:IsA("BasePart") then table.insert(boards, d) end end
	table.sort(boards, function(a, b) return a.Position.X < b.Position.X end)
	local MX0, MX1, MY0, MY1 = -240, -209, 10.2, 15.4
	local bw = (MX1 - MX0) / math.max(#boards, 1)
	for i, b in ipairs(boards) do
		b.Size = Vector3.new(bw - 0.3, MY1 - MY0, b.Size.Z)
		b.CFrame = b.CFrame.Rotation + Vector3.new(MX0 + (i - 0.5) * bw, (MY0 + MY1) / 2, b.Position.Z)
	end
	local sign = cafe:FindFirstChild("OrderPickupSign")
	if sign and header then
		local front = header.Position.Z - header.Size.Z / 2
		sign.Size = Vector3.new(15, 1.1, 0.12)
		sign.CFrame = CFrame.new((MX0 + MX1) / 2, HEADER_BOTTOM + 1.4, front - 0.06)
		local l = sign:FindFirstChildWhichIsA("SurfaceGui") and sign:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
		if l then
			l.TextWrapped = false
			l.TextScaled = true -- (a later pass had set a small fixed size)
			l.Text = "ORDER  &  PICK  UP"
			l.TextColor3 = Color3.fromRGB(96, 96, 100)
		end
	end
	table.insert(log, "header to " .. HEADER_BOTTOM .. ", boards " .. #boards)

	---------------------------------------------------------------- 4. till
	local reg = cafe:FindFirstChild("Register")
	local r37 = ART and ART:FindFirstChild("Register37")
	if reg and r37 then
		local floor = reg.Position.Y - reg.Size.Y / 2
		-- (as modelled, its keys to +z: the staff side here)
		place(r37, cafe, Vector3.new(reg.Position.X, floor, reg.Position.Z), 0).Name = "Register37"
		for _, d in ipairs(cafe:GetChildren()) do if d.Name == "Register" or d.Name == "RegisterScreen" then d:Destroy() end end
		table.insert(log, "till Register37")
	end

	---------------------------------------------------------------- 5. work bench
	local benchTop = cafe:FindFirstChild("BackCounterTop")
	local machine = NEW and NEW:FindFirstChild("CoffeeMachineAsh")
	if benchTop and machine then
		local y = benchTop.Position.Y + benchTop.Size.Y / 2
		local zb = benchTop.Position.Z + benchTop.Size.Z / 2 -- the wall side
		for _, d in ipairs(cafe:GetChildren()) do
			if d.Name == "EspressoMachine" or d.Name == "Grinder" then d:Destroy() end
		end
		-- two machines facing the staff (−z), where the boxes stood
		for _, x in ipairs({ -222, -214 }) do
			place(machine, cafe, Vector3.new(x, y, zb - 1.9), math.pi / 2, 1.45).Name = "CoffeeMachine" -- (its front to the staff, checked in Play)
		end
		-- cup towers and lids (like the photo's bar): white paper cups, black lids
		local WHITE, BLACK = Color3.fromRGB(246, 246, 242), Color3.fromRGB(28, 28, 30)
		for i, x in ipairs({ -237.5, -236.6, -235.7 }) do
			part("CupStack", Vector3.new(2.4, 0.75, 0.75), CFrame.new(x, y + 1.2, zb - 1.2) * CFrame.Angles(0, 0, math.rad(90)), WHITE, cafe, { shape = Enum.PartType.Cylinder })
			part("CupStackSleeve", Vector3.new(0.5, 0.8, 0.8), CFrame.new(x, y + 0.6, zb - 1.2) * CFrame.Angles(0, 0, math.rad(90)), if i == 2 then Color3.fromRGB(150, 110, 75) else WHITE, cafe, { shape = Enum.PartType.Cylinder })
		end
		for _, x in ipairs({ -233.8, -233.0 }) do
			part("LidStack", Vector3.new(1.6, 0.8, 0.8), CFrame.new(x, y + 0.8, zb - 1.2) * CFrame.Angles(0, 0, math.rad(90)), BLACK, cafe, { shape = Enum.PartType.Cylinder })
		end
		-- a black tray rack with pitchers
		part("TrayRack", Vector3.new(3.2, 0.12, 2), CFrame.new(-207.9 - 1.8, y + 0.06, zb - 1.4), BLACK, cafe)
		for _, dx in ipairs({ -0.9, 0, 0.9 }) do
			part("Pitcher", Vector3.new(0.9, 0.55, 0.55), CFrame.new(-209.7 + dx, y + 0.57, zb - 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 202, 206), cafe, { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal })
		end
		-- syrup bottles on the shelf over the bench (the shelf has its bottles; a tray of pumps by the machines)
		for i = 0, 3 do
			part("SyrupBottle", Vector3.new(1, 0.35, 0.35), CFrame.new(-226.6 + i * 0.5, y + 0.5, zb - 0.8) * CFrame.Angles(0, 0, math.rad(90)),
				({ Color3.fromRGB(150, 80, 40), Color3.fromRGB(230, 200, 140), Color3.fromRGB(110, 60, 30), Color3.fromRGB(240, 240, 235) })[i + 1], cafe, { shape = Enum.PartType.Cylinder, material = Enum.Material.Glass, t = 0.15 })
			part("SyrupPump", Vector3.new(0.12, 0.4, 0.12), CFrame.new(-226.6 + i * 0.5, y + 1.2, zb - 0.8), BLACK, cafe)
		end
		table.insert(log, "bench machines 2 + cups")
	end

	---------------------------------------------------------------- 6. menu stands
	local ctop = cafe:FindFirstChild("CounterTop")
	if ctop then
		local y = ctop.Position.Y + ctop.Size.Y / 2
		local zf = ctop.Position.Z - ctop.Size.Z / 2 + 0.6 -- near the customers' edge
		local function stand(x, w, h, title, body)
			local frame = part("MenuStand", Vector3.new(w + 0.16, h + 0.16, 0.08), CFrame.new(x, y + 0.25 + h / 2, zf) * CFrame.Angles(math.rad(-8), 0, 0),
				Color3.fromRGB(230, 236, 240), cafe, { material = Enum.Material.Glass, t = 0.35 })
			local card = part("MenuCard", Vector3.new(w, h, 0.03), frame.CFrame * CFrame.new(0, 0, -0.05), Color3.fromRGB(250, 248, 244), cafe)
			part("MenuStandFoot", Vector3.new(w * 0.7, 0.25, 0.6), CFrame.new(x, y + 0.125, zf + 0.15), Color3.fromRGB(230, 236, 240), cafe, { material = Enum.Material.Glass, t = 0.35 })
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 80
			g.LightInfluence = 0.3
			g.Parent = card
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(0.9, 0.14)
			t.Position = UDim2.fromScale(0.05, 0.04)
			t.BackgroundTransparency = 1
			t.TextScaled = true
			t.Font = Enum.Font.GothamBold
			t.TextColor3 = Color3.fromRGB(180, 80, 40)
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.Text = title
			t.Parent = g
			local b = Instance.new("TextLabel")
			b.Size = UDim2.fromScale(0.9, 0.74)
			b.Position = UDim2.fromScale(0.05, 0.2)
			b.BackgroundTransparency = 1
			b.TextScaled = true
			b.Font = Enum.Font.GothamMedium
			b.TextColor3 = Color3.fromRGB(50, 50, 52)
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextYAlignment = Enum.TextYAlignment.Top
			b.Text = body
			b.Parent = g
		end
		-- (the cafe's own menu, made for this game)
		stand(-224.6, 2.6, 2.0, "OHU CAFE MENU", "COFFEE\n아이스 아메리카노  무료\n카페라테 · 카푸치노  💰10\n카라멜 마끼아또  💰10\n\nNON COFFEE\n딸기 스무디 · 얼그레이  💰20\n블루 레몬에이드  💰20")
		stand(-221.4, 1.8, 2.0, "SIGNATURE", "자바칩 프라푸치노\n딸기 파르페\n\nBAKERY\n소금빵 · 베이글\n딸기 크림 크루아상")
		table.insert(log, "menu stands 2")
	end
end

return table.concat(log, " | ")
