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
			place(machine, cafe, Vector3.new(x, y, zb - 1.9), math.pi / 2, 1.45).Name = "CoffeeMachine" -- (this turn showed the side to the staff: step 13 sets them straight)
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

---------------------------------------------------------------- 7..9 (user 2026-10-30, 2nd)
-- (these live in Hongdae_Layout, rebuilt by build_hongdae_layout on every
-- chain run, so they are made fresh each time)
local L = workspace:FindFirstChild("Hongdae_Layout")
local CS = game:GetService("CollectionService")
local function gui(p: BasePart, face, ppStud)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppStud or 40
	g.LightInfluence = 0.6
	g.Parent = p
	return g
end
local function text(g, t, color, font, rich)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBlack
	l.TextColor3 = color
	l.RichText = rich or false
	l.Text = t
	l.Parent = g
	return l
end

-- 7. OH24 closed for now: the doors stay shut and carry a paper note
local store = L and L:FindFirstChild("OH24Store")
if store then
	local scf = store:GetBoundingBox()
	local n = 0
	for _, door in ipairs(store:GetChildren()) do
		if door:IsA("Model") and door.Name == "AutoDoor" then
			CS:RemoveTag(door, "AutoDoor")
			door:SetAttribute("ClosedTemp", true)
			local panels = {}
			for _, p in ipairs(door:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "DoorPanel" then p.CanCollide = true table.insert(panels, p) end
			end
			-- the note on the first leaf, on its street side
			local leaf = panels[1]
			if leaf then
				local d = leaf.Position - scf.Position
				local out = if math.abs(d.X) > math.abs(d.Z) then Vector3.new(math.sign(d.X), 0, 0) else Vector3.new(0, 0, math.sign(d.Z))
				local thin = math.min(leaf.Size.X, leaf.Size.Z)
				local c = leaf.Position + out * (thin / 2 + 0.03) + Vector3.new(0, 0.6, 0)
				local paper = part("ClosedNote", Vector3.new(2.2, 1.6, 0.02), CFrame.lookAt(c, c + out), Color3.fromRGB(246, 244, 236), store, { noshadow = true })
				local g = gui(paper, Enum.NormalId.Front, 120)
				local l = text(g, '죄송합니다.\n잠시\n<font color="#D8262E">"외출중"</font>입니다.', Color3.fromRGB(30, 30, 30), Enum.Font.GothamMedium, true)
				l.Size = UDim2.fromScale(0.86, 0.86)
				l.Position = UDim2.fromScale(0.07, 0.07)
				n += 1
			end
		end
	end
	table.insert(log, "OH24 closed, notes " .. n)
end

-- 8. an A-frame stand on the promenade in front of the beach cafe door
-- (where the street light stood): wood, O / H / U in white down the board
-- (user 2026-10-30, 3rd: on the deck by the wall, left of the door as seen
-- from the road; the black CafeSign box over the door is gone, the 3D letters
-- replace it)
do
	local old = cafe and cafe:FindFirstChild("CafeSign")
	if old then old:Destroy() end
end
if L then
	local x, z, y = -203.4, 288, 0.6
	local WOOD = Color3.fromRGB(196, 110, 50)
	local lean = math.rad(11)
	local W, H = 2.6, 4.4
	local dz = H / 2 * math.sin(lean)
	for k, s in ipairs({ -1, 1 }) do
		-- the boards face along x (the road and the cafe door)
		local b = part("CafeStandBoard", Vector3.new(0.14, H, W), CFrame.new(x + s * dz, y + H / 2 * math.cos(lean), z) * CFrame.Angles(0, 0, s * lean), WOOD, L, { material = Enum.Material.WoodPlanks, collide = true })
		local g = gui(b, if s < 0 then Enum.NormalId.Left else Enum.NormalId.Right, 60)
		local l = text(g, "O\nH\nU", Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		l.Size = UDim2.fromScale(0.6, 0.8)
		l.Position = UDim2.fromScale(0.2, 0.1)
		l.TextYAlignment = Enum.TextYAlignment.Center
		local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(120, 60, 25) st.Thickness = 1 st.Parent = l
		_ = k
	end
	part("CafeStandHinge", Vector3.new(2 * dz + 0.3, 0.2, W), CFrame.new(x, y + H * math.cos(lean), z), Color3.fromRGB(150, 85, 40), L, { material = Enum.Material.Wood })
	table.insert(log, "cafe stand")
end

-- 9. a pizza shop front on OH24's plain west wall (the beach road side),
-- from the user's beach-front photo but our own shop: OHU PIZZA. Only the
-- outside: a stepped entrance with a dark glass door and a TAKE OUT banner, a
-- red awning over a glass front, a white sign band, and a tiled base with big
-- red PIZZA letters.
if store then
	local X = -135.02 -- the wall's outer face (it faces -x)
	local Z0, Z1 = 84, 200
	local RED, WHITE, DARK = Color3.fromRGB(222, 40, 50), Color3.fromRGB(246, 246, 244), Color3.fromRGB(32, 34, 38)
	local F = Instance.new("Model")
	F.Name = "PizzaFront"
	F.Parent = store
	local function slab(name, x0, y0, z0, x1, y1, z1, color, opt)
		local lo, hi = Vector3.new(math.min(x0, x1), y0, math.min(z0, z1)), Vector3.new(math.max(x0, x1), y1, math.max(z0, z1))
		return part(name, hi - lo, CFrame.new((lo + hi) / 2), color, F, opt)
	end
	local ENT = Z0 + 16 -- the entrance bay z Z0..ENT, the shop front ENT..Z1
	-- upper white band across all of it, the shop name in red
	local band = slab("PizzaBand", X - 0.5, 14.6, Z0, X, 20.6, Z1, WHITE)
	local g = gui(band, Enum.NormalId.Left, 20)
	local frame = Instance.new("Frame") frame.Size = UDim2.fromScale(1, 1) frame.BackgroundTransparency = 1 frame.Parent = g
	local name = text(frame, "OHU PIZZA", RED, Enum.Font.GothamBlack)
	name.Size = UDim2.fromScale(0.26, 0.62) name.Position = UDim2.fromScale(0.04, 0.19)
	local slogan = text(frame, "SLICE BY THE SEA.", RED, Enum.Font.GothamBold)
	slogan.Size = UDim2.fromScale(0.5, 0.36) slogan.Position = UDim2.fromScale(0.42, 0.32)
	-- entrance bay: dark recess, glass doors, three steps
	slab("PizzaEntryBack", X - 0.3, 0.6, Z0, X, 14.6, ENT, DARK, { material = Enum.Material.Slate })
	slab("PizzaDoorGlass", X - 0.45, 3.0, Z0 + 4, X - 0.35, 12.4, Z0 + 12, Color3.fromRGB(40, 60, 70), { material = Enum.Material.Glass, t = 0.25 })
	slab("PizzaDoorFrame", X - 0.5, 12.4, Z0 + 3.8, X - 0.3, 12.8, Z0 + 12.2, Color3.fromRGB(190, 160, 80), { material = Enum.Material.Metal })
	slab("PizzaDoorFrame", X - 0.5, 3.0, Z0 + 7.9, X - 0.3, 12.4, Z0 + 8.1, Color3.fromRGB(190, 160, 80), { material = Enum.Material.Metal })
	for k = 0, 2 do
		slab("PizzaStep", X - 1.2 - (2 - k) * 1.1, 0.6, Z0 + 1, X, 0.6 + (k + 1) * 0.8, ENT - 1, Color3.fromRGB(70, 72, 76), { material = Enum.Material.Granite, collide = true })
	end
	local take = slab("PizzaTakeOut", X - 0.7, 4, ENT - 2.6, X - 0.5, 13, ENT - 0.6, WHITE)
	local tg = gui(take, Enum.NormalId.Left, 30)
	local tl = text(tg, "T\nA\nK\nE\n\nO\nU\nT", RED, Enum.Font.GothamBlack)
	tl.Size = UDim2.fromScale(0.7, 0.9) tl.Position = UDim2.fromScale(0.15, 0.05)
	-- shop front: tiled base with the big letters, glass above, the awning
	local base = slab("PizzaBase", X - 0.4, 0.6, ENT, X, 6.4, Z1, Color3.fromRGB(226, 226, 222), { material = Enum.Material.Marble })
	local bg = gui(base, Enum.NormalId.Left, 16)
	local big = text(bg, "PIZZA", RED, Enum.Font.GothamBlack)
	big.Size = UDim2.fromScale(0.5, 0.92) big.Position = UDim2.fromScale(0.48, 0.04)
	local line = text(bg, "TAKE A SLICE. FEEL THE BEACH.", RED, Enum.Font.GothamBold)
	line.Size = UDim2.fromScale(0.4, 0.3) line.Position = UDim2.fromScale(0.04, 0.35)
	slab("PizzaGlass", X - 0.3, 6.4, ENT, X - 0.2, 12.6, Z1, Color3.fromRGB(70, 100, 120), { material = Enum.Material.Glass, t = 0.3 })
	for zz = ENT, Z1, 8 do
		slab("PizzaMullion", X - 0.45, 6.4, zz - 0.15, X - 0.25, 12.6, zz + 0.15, Color3.fromRGB(200, 200, 204), { material = Enum.Material.Metal })
	end
	slab("PizzaSill", X - 0.6, 6.3, ENT, X, 6.5, Z1, Color3.fromRGB(200, 200, 204), { material = Enum.Material.Metal })
	-- the red awning, sloping out and down from the band
	local AW = 3
	local aw = part("PizzaAwning", Vector3.new(0.15, AW, Z1 - ENT), CFrame.new(X - AW / 2 * math.sin(math.rad(55)) - 0.1, 13.4, (ENT + Z1) / 2) * CFrame.Angles(0, 0, math.rad(-55)), RED, F, { material = Enum.Material.Fabric })
	local ag = gui(aw, Enum.NormalId.Left, 24)
	local al = text(ag, "OHU PIZZA  ·  SLICES & SODA", WHITE, Enum.Font.GothamBold)
	al.Size = UDim2.fromScale(0.5, 0.5) al.Position = UDim2.fromScale(0.25, 0.25)
	-- a pot of flowers on a post, like the photo's
	local pz = ENT + 2
	part("PizzaFlowerPost", Vector3.new(0.3, 9, 0.3), CFrame.new(X - 7, 0.6 + 4.5, pz), Color3.fromRGB(110, 90, 70), F, { material = Enum.Material.Wood })
	part("PizzaFlowers", Vector3.new(2.2, 1.6, 2.2), CFrame.new(X - 7, 0.6 + 9, pz), Color3.fromRGB(235, 120, 200), F, { shape = Enum.PartType.Ball, material = Enum.Material.Grass })
	table.insert(log, "pizza front")
end

-- 10. OH24 made smaller (user plan 2026-10-30, docs/02_WORLDS/images/
-- oh24_plan_user_1030.webp): the building stays, the store is only its
-- north-east part, x -104.7..-56, z 66..145.7, closed off by two inner walls;
-- the rest is unused (its outside will carry pictures). Inside, from the plan:
-- the wall fridges along the new west wall, three gondolas, the counter as an
-- L south of the east door, the window bar / deck in the north-east corner as
-- before. The north door is gone (glass), the east door is the store's door.
if store then
	-- (user 2026-10-30, 2nd) a black pier like the corner one on the store's west
	-- end of the north front (x -106.4..-104.5, on the old door mullion line);
	-- the inner wall sits inside it
	local WX, SZ = -105.5, 145.7 -- the store's new west and south inner faces
	local WHITE_IN = Color3.fromRGB(246, 246, 244)
	local function inStore(p: Vector3): boolean return p.X > WX and p.Z < SZ end
	-- inner walls (to the ceiling)
	part("InnerWall", Vector3.new(0.6, 20.1, SZ - 66 + 0.6), CFrame.new(WX - 0.3, 0.6 + 10.05, (66 + SZ + 0.6) / 2), WHITE_IN, store, { collide = true })
	part("InnerWall", Vector3.new(-56.2 - (WX - 0.6), 20.1, 0.6), CFrame.new((WX - 0.6 - 56.2) / 2, 0.6 + 10.05, SZ + 0.3), WHITE_IN, store, { collide = true })
	-- wall fridges: the west wall's run moved onto the new wall, z 80..128 only
	local CDX = WX - (-134.4)
	local CZ1 = 128
	for _, d in ipairs(store:GetChildren()) do
		if d:IsA("BasePart") and (d.Name:match("^Cold") or (d.Name == "ShelfRow" and d.Position.X < -130)) then
			local long = d.Size.Z > 50
			if long then
				local z0 = d.Position.Z - d.Size.Z / 2
				d.Size = Vector3.new(d.Size.X, d.Size.Y, CZ1 - z0 - (if d.Name == "ColdInner" then 0.3 else 0))
				d.CFrame = d.CFrame.Rotation + Vector3.new(d.Position.X + CDX, d.Position.Y, z0 + d.Size.Z / 2)
			elseif d.Position.Z > CZ1 - 0.5 then
				d:Destroy()
			else
				d.CFrame = d.CFrame + Vector3.new(CDX, 0, 0)
			end
		end
	end
	-- gondolas: three moved in (with the goods standing on them), the fourth gone
	local GO = { Gondola1 = Vector3.new(-93.6, 0, 89), Gondola2 = Vector3.new(-93.6, 0, 111.5), Gondola3 = Vector3.new(-76.5, 0, 112) }
	for i = 1, 4 do
		local g = store:FindFirstChild("Gondola" .. i)
		if g then
			local c, s = g:GetBoundingBox()
			local goods = {}
			for _, d in ipairs(store:GetChildren()) do
				if d:IsA("BasePart") and d.Name == "ShelfRow" and math.abs(d.Position.X - c.X) < s.X / 2 + 0.6 and math.abs(d.Position.Z - c.Z) < s.Z / 2 + 0.6 then table.insert(goods, d) end
			end
			local to = GO[g.Name]
			if to then
				local delta = Vector3.new(to.X - c.X, 0, to.Z - c.Z)
				g:PivotTo(g:GetPivot() + delta)
				for _, d in ipairs(goods) do d.CFrame = d.CFrame + delta end
			else
				g:Destroy()
				for _, d in ipairs(goods) do d:Destroy() end
			end
		end
	end
	-- the counter: its L moved to just south of the east door, the bar cut at
	-- the new west wall (east end -76 → -64.8, front z 190 → 131)
	local CD = Vector3.new(11.2, 0, -59)
	local reg = store:FindFirstChild("Register37")
	if reg then reg:PivotTo(reg:GetPivot() + CD) end
	for _, d in ipairs(store:GetChildren()) do
		if d:IsA("BasePart") and (d.Name:match("^Counter") or d.Name == "PosBase" or d.Name == "Scanner" or d.Name == "CardTerminal" or d.Name == "CustomerScreen") and d.Position.Z > 185 then
			d.CFrame = d.CFrame + CD
			local x0, x1 = d.Position.X - d.Size.X / 2, d.Position.X + d.Size.X / 2
			if x0 < WX then
				d.Size = Vector3.new(x1 - WX, d.Size.Y, d.Size.Z)
				d.CFrame = d.CFrame.Rotation + Vector3.new((WX + x1) / 2, d.Position.Y, d.Position.Z)
			end
		end
	end
	-- the north door: closed off with glass like the rest of the front
	for _, d in ipairs(store:GetChildren()) do
		local p = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
		if p and p.Z < 70 and (d.Name == "AutoDoor" or d.Name == "DoorHead" or d.Name == "ClosedNote") then d:Destroy() end
	end
	part("FrontGlass", Vector3.new(8.8, 18.6, 0.2), CFrame.new(-102, 10.5, 65.9), Color3.fromRGB(200, 225, 230), store, { material = Enum.Material.Glass, t = 0.6, collide = true })
	part("Kickplate", Vector3.new(8.8, 0.6, 0.25), CFrame.new(-102, 0.9, 65.875), Color3.fromRGB(150, 150, 155), store, { material = Enum.Material.Metal, collide = true })
	-- everything else left in the unused part goes (it is behind the walls)
	local n = 0
	for _, d in ipairs(store:GetChildren()) do
		local p = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
		local keep = { StoreFloor = true, Ceiling = true, Roof = true, WallW = true, WallBack = true, InnerWall = true, PizzaFront = true, OH24FrontStack = true, CeilingGrid = true, LEDStrip = true,
			FrontGlass = true, Kickplate = true, Mullion = true, GlassHead = true, FacadePier = true, OuterBack = true, LightBar = true, LightBarBase = true, Fascia = true, Awning = true,
			AwningEdge = true, Logo = true, FrontStep = true, GlassMark = true, GlassLettering = true, GlassPoster = true, GlassSticker = true, GlassBanner = true, StoreLabelAnchor = true, DoorHead = true, AutoDoor = true, ClosedNote = true }
		if p and not keep[d.Name] and not inStore(p) and p.Y < 21 then d:Destroy() n += 1 end
	end
	-- the second pier, the same as the corner one
	local corner
	for _, d in ipairs(store:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "FacadePier" and d.Position.Z < 66.2 and d.Position.X > -60 then corner = d end
	end
	if corner then
		local p = corner:Clone()
		p.CFrame = corner.CFrame + Vector3.new(-105.45 - corner.Position.X, 0, 0)
		p.Parent = store
	end
	-- the sign over the store front, laid out again between the two piers and
	-- centred (x -104.5..-57.6): logo in the middle, a light bar each side;
	-- the bar over the unused part goes; 홍대점 → 오후점
	local A, B = -104.5, -57.6
	local mid = (A + B) / 2
	local logo
	local bars = {}
	for _, d in ipairs(store:GetChildren()) do
		if d:IsA("BasePart") and d.Position.Z < 66 and d.Position.Y > 21 and d.Position.Y < 26 then
			if d.Name == "Logo" then logo = d
			elseif d.Name == "LightBar" or d.Name == "LightBarBase" then table.insert(bars, d) end
		end
	end
	if logo then
		logo.CFrame = logo.CFrame + Vector3.new(mid - logo.Position.X, 0, 0)
		local lx0, lx1 = mid - logo.Size.X / 2 - 0.3, mid + logo.Size.X / 2 + 0.3
		for _, b in ipairs(bars) do
			local west = b.Position.X < -100
			local x0, x1 = if west then A else lx1, if west then lx0 else B
			b.Size = Vector3.new(x1 - x0, b.Size.Y, b.Size.Z)
			b.CFrame = b.CFrame.Rotation + Vector3.new((x0 + x1) / 2, b.Position.Y, b.Position.Z)
			for _, l in ipairs(b:GetDescendants()) do
				if l:IsA("TextLabel") and l.Text:find("홍대점") then l.Text = string.gsub(l.Text, "홍대점", "오후점") end
			end
		end
	end
	-- (user 2026-10-30, 3rd) the awnings end at the new piers; the east face
	-- gets the same: a pier at the store's south end (z 146, the inner wall's
	-- line), its sign laid out between that pier and the north corner and
	-- centred, 남부대로점 → 오후점. East-face parts are turned 90°: their size X
	-- runs along world z.
	local EA, EB = 66.85, 145.05 -- east face: north corner .. new pier
	local emid = (EA + EB) / 2
	for _, d in ipairs(store:GetChildren()) do
		if d:IsA("BasePart") and (d.Name == "Awning" or d.Name == "AwningEdge") then
			if d.Position.Z < 66 then -- north: keep x -104.5 ..
				local x1 = d.Position.X + d.Size.X / 2
				d.Size = Vector3.new(x1 - A, d.Size.Y, d.Size.Z)
				d.CFrame = d.CFrame.Rotation + Vector3.new((A + x1) / 2, d.Position.Y, d.Position.Z)
			else -- east (turned): keep z .. EB
				local z0 = d.Position.Z - d.Size.X / 2
				d.Size = Vector3.new(EB - z0, d.Size.Y, d.Size.Z)
				d.CFrame = d.CFrame.Rotation + Vector3.new(d.Position.X, d.Position.Y, (z0 + EB) / 2)
			end
		end
	end
	if corner then
		local p = corner:Clone()
		p.Size = Vector3.new(0.4, corner.Size.Y, corner.Size.X)
		p.CFrame = CFrame.new(-55.8, corner.Position.Y, (EB + EB + 1.9) / 2)
		p.Parent = store
	end
	local elogo
	local ebars = {}
	for _, d in ipairs(store:GetChildren()) do
		if d:IsA("BasePart") and d.Position.Z > 66.5 and d.Position.Y > 21 and d.Position.Y < 26 and math.abs(d.CFrame.RightVector.Z) > 0.9 then
			if d.Name == "Logo" then elogo = d
			elseif d.Name == "LightBar" or d.Name == "LightBarBase" then table.insert(ebars, d) end
		end
	end
	if elogo then
		elogo.CFrame = elogo.CFrame + Vector3.new(0, 0, emid - elogo.Position.Z)
		local lz0, lz1 = emid - elogo.Size.X / 2 - 0.3, emid + elogo.Size.X / 2 + 0.3
		for _, b in ipairs(ebars) do
			local north = b.Position.Z < 138
			local z0, z1 = if north then EA else lz1, if north then lz0 else EB
			b.Size = Vector3.new(z1 - z0, b.Size.Y, b.Size.Z)
			b.CFrame = b.CFrame.Rotation + Vector3.new(b.Position.X, b.Position.Y, (z0 + z1) / 2)
			for _, l in ipairs(b:GetDescendants()) do
				if l:IsA("TextLabel") and l.Text:find("남부대로점") then l.Text = string.gsub(l.Text, "남부대로점", "오후점") end
			end
		end
	end
	table.insert(log, "OH24 smaller, removed " .. n)
end

-- 11. (user 2026-10-30) the back alley opened again (the invisible stop goes)
-- and cleared of the clutter on the ground: drain strip, puddles, bins, bags,
-- crates, planters, cone, the two ACs standing on the ground. The wall ACs,
-- lamps, gas pipe, meters, signs and wires stay.
local alley = L and L:FindFirstChild("BackAlley")
if alley then
	local GONE = { AlleyStop = true, AlleyDrain = true, AlleyPuddle = true, RecycleBin = true, TrashBag = true, PlasticCrate = true, FoamPlanter = true, PlanterGreens = true, TrafficCone = true }
	local AC = { ACUnit = true, ACFan = true, ACBracket = true, ACPipeCover = true }
	local n = 0
	for _, d in ipairs(alley:GetChildren()) do
		if d:IsA("BasePart") and (GONE[d.Name] or (AC[d.Name] and d.Position.Y < 7)) then d:Destroy() n += 1 end
	end
	table.insert(log, "alley cleared " .. n)
end

-- 12. 오후네컷 (user 2026-10-30): east of x 115 on the south face the ground
-- floor takes the 2F brick, with a door like a big 2F window; the deck and the
-- white sign band end at x 115. Its alley wall (east face) is brick too.
local ohu = L and L:FindFirstChild("OhuFourCuts")
if ohu then
	local LINE = 115
	local upper = ohu:FindFirstChild("UpperS")
	local brickColor = if upper then upper.Color else Color3.new(1, 1, 1)
	for _, d in ipairs(ohu:GetChildren()) do
		if d:IsA("BasePart") and ((d.Name == "Deck" and d.Position.Z > -47.6 and d.Size.X > 50) or (d.Name == "Fascia" and d.Position.Z > -48.6 and d.Position.Z < -46 and d.Size.X > 50)) then
			local x0 = d.Position.X - d.Size.X / 2
			d.Size = Vector3.new(LINE - x0, d.Size.Y, d.Size.Z)
			d.CFrame = d.CFrame.Rotation + Vector3.new((x0 + LINE) / 2, d.Position.Y, d.Position.Z)
		end
		if d:IsA("BasePart") and d.Name == "WallE" then
			d.Material = Enum.Material.Brick
			d.Color = brickColor
		end
	end
	-- the brick skin over the ground floor east of the line (just proud of the tiles)
	local skin = part("GroundBrick", Vector3.new(180.03 - LINE, 19.2 - 1.6, 0.1), CFrame.new((LINE + 180.03) / 2, (1.6 + 19.2) / 2, -47.5), brickColor, ohu, { material = Enum.Material.Brick })
	skin.CastShadow = false
	-- the door: a 2F window made big (dark frame, glass, a mullion)
	local FRAME, GLASS = Color3.fromRGB(58, 46, 42), Color3.fromRGB(205, 220, 232)
	local dx, dw, dh = 147.5, 7, 12
	part("BrickDoorFrame", Vector3.new(dw + 0.6, dh + 0.3, 0.3), CFrame.new(dx, 1.6 + (dh + 0.3) / 2, -47.3), FRAME, ohu, { collide = true })
	part("BrickDoorGlass", Vector3.new(dw, dh, 0.2), CFrame.new(dx, 1.6 + dh / 2, -47.15), GLASS, ohu, { material = Enum.Material.Glass, t = 0.1 })
	part("BrickDoorMullion", Vector3.new(0.24, dh, 0.3), CFrame.new(dx, 1.6 + dh / 2, -47.05), FRAME, ohu)
	part("BrickDoorHandle", Vector3.new(0.15, 1.6, 0.15), CFrame.new(dx - 0.6, 1.6 + 5, -46.9), Color3.fromRGB(200, 200, 205), ohu, { material = Enum.Material.Metal })
	part("BrickDoorHandle", Vector3.new(0.15, 1.6, 0.15), CFrame.new(dx + 0.6, 1.6 + 5, -46.9), Color3.fromRGB(200, 200, 205), ohu, { material = Enum.Material.Metal })
	-- (user 2026-10-30) the corner at x 180 flickered: the tiled wall's end, its
	-- collider and the alley wall met in one plane there. A thin brick strip
	-- wraps the corner, just proud of both faces.
	part("CornerBrick", Vector3.new(0.09, 48, 1.18), CFrame.new(180.015, 0.6 + 24, -48.01), brickColor, ohu, { material = Enum.Material.Brick })
	-- where the wooden deck was (x 115..180): the same step, in the sidewalk's
	-- paving (street_dress paveLook: this colour + the paver tile 7 x 7)
	local step = part("PavedStep", Vector3.new(180.06 - LINE, 1.6, 2.6), CFrame.new((LINE + 180.06) / 2, 0.8, -47.5 + 1.3), Color3.fromRGB(176, 172, 166), ohu, { collide = true })
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Back, Enum.NormalId.Right }) do
		local t = Instance.new("Texture")
		t.Texture = "rbxassetid://133933193561069"
		t.Face = face
		t.StudsPerTileU, t.StudsPerTileV = 7, 7
		t.Parent = step
	end
	-- (user 2026-10-30, 2nd) the step goes on round the corner along the alley
	-- wall (x 180.06..182.66) and ends at the alley's inner end (the building's
	-- north-east corner, z -115); the meter cabinet stands on it
	local side = part("PavedStep", Vector3.new(2.6, 1.6, 115 - 44.9), CFrame.new(180.06 + 1.3, 0.8, (-115 - 44.9) / 2), Color3.fromRGB(176, 172, 166), ohu, { collide = true })
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Right, Enum.NormalId.Back, Enum.NormalId.Front }) do
		local t = Instance.new("Texture")
		t.Texture = "rbxassetid://133933193561069"
		t.Face = face
		t.StudsPerTileU, t.StudsPerTileV = 7, 7
		t.Parent = side
	end
	local cab = L:FindFirstChild("BackAlley") and L.BackAlley:FindFirstChild("MeterCabinet")
	if cab then cab.CFrame = cab.CFrame + Vector3.new(0, 1.6 - (cab.Position.Y - cab.Size.Y / 2), 0) end
	-- the north-east corner flickered too (the plaster north wall's end and the
	-- alley wall in one plane): the same thin brick strip round it
	part("CornerBrick", Vector3.new(0.09, 48, 1.32), CFrame.new(180.015, 0.6 + 24, -115.0), brickColor, ohu, { material = Enum.Material.Brick })
	table.insert(log, "ohu south brick + door + paved step")
end

---------------------------------------------------------------- 13. phone test fixes (user 2026-10-30, 3rd)
-- Each sets the final pose outright, so running it again changes nothing.
if cafe then
	-- the till 1.5x (its bottom stays on the counter)
	for _, r in ipairs(cafe:GetChildren()) do
		if r:IsA("Model") and r.Name == "Register37" then
			local cf, size = r:GetBoundingBox()
			if size.Y < 1.6 then
				local bottom = Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)
				r:ScaleTo(r:GetScale() * 1.5)
				local cf2, size2 = r:GetBoundingBox()
				r:PivotTo(CFrame.new(bottom + Vector3.new(0, size2.Y / 2, 0)) * cf2.Rotation * cf2:ToObjectSpace(r:GetPivot()))
			end
		end
	end
	-- the coffee machines face the staff (−z): their front (handles, cups) is
	-- the model's −z, so no turn; set back toward the wall so they stay on the bench
	local benchTop = cafe:FindFirstChild("BackCounterTop")
	if benchTop then
		local y = benchTop.Position.Y + benchTop.Size.Y / 2
		local zb = benchTop.Position.Z + benchTop.Size.Z / 2
		for _, m in ipairs(cafe:GetChildren()) do
			if m:IsA("Model") and m.Name == "CoffeeMachine" then
				local cf, size = m:GetBoundingBox()
				m:PivotTo(CFrame.new(cf.X, y + size.Y / 2, zb - size.Z / 2 - 0.1) * cf:ToObjectSpace(m:GetPivot()))
			end
		end
	end
	-- the window bar stools higher: seat top 1.2 under the bar top (it was 2.6),
	-- legs longer, the foot ring up with them, the sit seat too
	local bar = cafe:FindFirstChild("WindowBar")
	if bar then
		local target = bar.Position.Y + bar.Size.Y / 2 - 1.2
		local seats = {}
		for _, d in ipairs(cafe:GetChildren()) do if d:IsA("Seat") and d.Name == "BarStool" then table.insert(seats, d) end end
		local raised = 0
		for _, m in ipairs(cafe:GetChildren()) do
			local pad = m:IsA("Model") and m.Name == "ClubStool" and m:FindFirstChild("SeatPad")
			if not pad or math.abs(pad.Position.X - bar.Position.X) > 8 then continue end
			-- (the pad is turned: its thin side is x, so take its world height)
			local c, s = pad.CFrame, pad.Size / 2
			local halfY = math.abs(c.XVector.Y) * s.X + math.abs(c.YVector.Y) * s.Y + math.abs(c.ZVector.Y) * s.Z
			local D = target - (pad.Position.Y + halfY)
			if math.abs(D) < 0.05 then continue end
			local floor = math.huge
			for _, d in ipairs(m:GetChildren()) do
				if d:IsA("BasePart") and d.Name == "Leg" then floor = math.min(floor, d.Position.Y - d.Size.X / 2) end
			end
			for _, d in ipairs(m:GetChildren()) do
				if not d:IsA("BasePart") then continue end
				if d.Name == "SeatPad" or d.Name == "SeatShell" then
					d.CFrame = d.CFrame + Vector3.new(0, D, 0)
				elseif d.Name == "Leg" then -- (upright, their length along x)
					local len = d.Size.X
					d.Size = Vector3.new(len + D, d.Size.Y, d.Size.Z)
					d.CFrame = d.CFrame + Vector3.new(0, D / 2, 0)
				elseif d.Name == "FootRing" then
					local legLen = target - D - floor
					d.CFrame = d.CFrame + Vector3.new(0, (d.Position.Y - floor) / legLen * D, 0)
				end
			end
			for _, s in ipairs(seats) do
				if Vector2.new(s.Position.X - pad.Position.X, s.Position.Z - pad.Position.Z).Magnitude < 1 then
					s.CFrame = s.CFrame + Vector3.new(0, D, 0)
				end
			end
			raised += 1
		end
		table.insert(log, "till 1.5x, machines face staff, window stools " .. raised)
	end
end
-- two planting beds by the club door (no trees: the user had taken out the
-- beds and trees there), copies of the bare bed north of them with its shrubs,
-- set either side of the door (gold frame z -220.8..-199.2), each touching
-- the next bed so the strip runs on
if L and not L:FindFirstChild("ClubBedFill") then
	local src
	for _, m in ipairs(L:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("PropId") == "Bed@27,-173" then src = m end
	end
	if src then
		local c = src:GetPivot().Position
		local group = { src }
		for _, m in ipairs(L:GetChildren()) do
			if m ~= src and m:IsA("Model") and m.Name == "Shrub" then
				local p = m:GetPivot().Position
				if math.abs(p.X - c.X) < 2.2 and math.abs(p.Z - c.Z) < 7.5 then table.insert(group, m) end
			end
		end
		local fill = Instance.new("Folder")
		fill.Name = "ClubBedFill"
		fill.Parent = L
		for _, z in ipairs({ -190, -229 }) do
			for _, m in ipairs(group) do
				local copy = m:Clone()
				copy:SetAttribute("PropId", nil) -- (not a prop of its own: prop_save skips it)
				copy:PivotTo(m:GetPivot() + Vector3.new(0, 0, z - c.Z))
				copy.Parent = fill
			end
		end
		table.insert(log, "club beds 2 (" .. #group .. " pieces each)")
	end
end

---------------------------------------------------------------- 14. beach (user 2026-10-30, phone shots)
-- rubber ducks 1.5x (still floating on their base line), the float tubes in
-- different colours, the mats → candidate M6 (below; M4, a 144-part checker,
-- was tried first: ServerStorage.NewAssets1030.BeachMatM4)
do
	local zone = beach
	local n = { ducks = 0, tubes = 0, mats = 0 }
	if zone then
		for _, m in ipairs(zone:GetChildren()) do
			local duck = m:IsA("Model") and m.Name:match("^RubberDuck") and m:FindFirstChild("Duck")
			if duck and not duck:GetAttribute("Big15") then
				local base = m:GetAttribute("Base")
				local rot = duck.CFrame.Rotation
				local at = duck.Position
				duck.Size = duck.Size * 1.5
				local y = if typeof(base) == "Vector3" then base.Y + duck.Size.Y * 0.35 else at.Y
				duck.CFrame = CFrame.new(at.X, y, at.Z) * rot
				duck:SetAttribute("Big15", true)
				n.ducks += 1
			end
		end
		local TUBE = { Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 230, 190), Color3.fromRGB(255, 160, 90),
			Color3.fromRGB(190, 160, 255), Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 120, 120) }
		for _, m in ipairs(zone:GetChildren()) do
			local i = m:IsA("Model") and tonumber(m.Name:match("^Tube(%d+)$"))
			local mesh = i and m:FindFirstChild("TubeMesh")
			if mesh then
				mesh.Color = TUBE[(i - 1) % #TUBE + 1]
				mesh.Material = Enum.Material.SmoothPlastic
				n.tubes += 1
			end
		end
	end
	-- (user 2026-10-30, later) M6 instead: the red gingham picnic blanket
	-- (Creator Store 123301850001093, one part; it hid a malicious script, all
	-- removed: ServerStorage.NewAssets1030.BeachMatM6 is the clean part). Its
	-- gingham picture rbxassetid://158549481 on the top of one thin part.
	for _, spot in ipairs(workspace:GetDescendants()) do
		if not (spot:IsA("Model") and spot.Name:match("^BeachSpot_")) or spot:FindFirstChild("BeachMatM6") then continue end
		local slab
		for _, d in ipairs(spot:GetChildren()) do if d.Name == "Mat" and d:IsA("BasePart") then slab = d end end
		if not slab then continue end
		for _, name in ipairs({ "BeachMat", "BeachMatM4" }) do
			local old = spot:FindFirstChild(name)
			if old then old:Destroy() end
		end
		for _, d in ipairs(spot:GetChildren()) do
			if d:IsA("BasePart") and (d.Name == "Mat" or d.Name == "MatStripe") then d.Transparency = 1 end
		end
		local mat = Instance.new("Part")
		mat.Name = "BeachMatM6"
		mat.Size = Vector3.new(slab.Size.X, 0.08, slab.Size.Z)
		mat.CFrame = slab.CFrame * CFrame.new(0, -slab.Size.Y / 2 + 0.06, 0)
		mat.Color = Color3.new(1, 1, 1)
		mat.Material = Enum.Material.SmoothPlastic
		mat.Anchored, mat.CanCollide, mat.CanTouch, mat.CanQuery, mat.CastShadow = true, false, false, false, false
		mat.Material = Enum.Material.Fabric
		local t = Instance.new("Decal")
		t.Texture = "rbxassetid://158549481"
		t.Face = Enum.NormalId.Top
		t.Parent = mat
		mat.Parent = spot
		n.mats += 1
	end
	table.insert(log, string.format("ducks %d, tubes %d, mats M6 %d", n.ducks, n.tubes, n.mats))
end

---------------------------------------------------------------- 15. OH24 corner (user 2026-10-30, screenshots)
-- (Hongdae_Layout is rebuilt on every chain run; the store carries a mark so a
-- second run on the same build does nothing)
--   a. the stacked chairs, crates, OH24 stand banner and the papers on the
--      north glass move to the east face, between the door and the south pier
--   b. "호빵 · 어묵 판매중" moves from the east glass to the north glass, east end
--   c. the empty shop west of the store (north face x -134..-106): lights off
--      (a dark lining inside); the empty room south of the store on the east
--      face: dark too, with 임대문의 papers on its glass, like the user's
--      photo (a news photo of a Seoul shop front)
--   d. the pizza shop: the flower post goes; the plain white wall between the
--      corner and the pizza entrance (z 66..84) gets the pizza front's look
local store15 = L and L:FindFirstChild("OH24Store")
if store15 and not store15:GetAttribute("Polish1030_15") then
	store15:SetAttribute("Polish1030_15", true)
	-- north face (outward -z, along x) → east face (outward +x, along z): a
	-- quarter turn; x - C on the north face becomes z - T on the east face
	local TURN = CFrame.Angles(0, -math.pi / 2, 0)
	local function toEast(p: BasePart, C: number, T: number)
		local w = 65.8 - p.Position.Z -- out from the north glass
		p.CFrame = CFrame.new(-55.8 + w, p.Position.Y, T + (p.Position.X - C)) * TURN * p.CFrame.Rotation
	end
	local stack = store15:FindFirstChild("OH24FrontStack")
	if stack then
		local collides = {}
		for _, p in ipairs(stack:GetChildren()) do
			if not p:IsA("BasePart") then continue end
			local x = p.Position.X
			if p.Name == "StackCollide" then table.insert(collides, p)
			elseif x > -100 then toEast(p, -94, 134) -- the two chair stacks
			elseif x > -113 then toEast(p, -110.1, 142) -- the crates
			else toEast(p, -120.4, 137.4) end -- the stand banner
		end
		-- the invisible stops: one on each new stack
		if collides[1] then collides[1].CFrame = CFrame.new(-52.6, collides[1].Position.Y, 142) end
		if collides[2] then collides[2].CFrame = CFrame.new(-52.6, collides[2].Position.Y, 134) end
	end
	for _, p in ipairs(store15:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "GlassPoster" or p.Name == "GlassSticker") and p.Position.Z < 66 and p.Position.X < -80 then
			toEast(p, -91, 136.5)
		end
	end
	-- b. east → north, at x -79..-61
	for _, p in ipairs(store15:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "GlassBanner" and p.Position.X > -56.5 then
			local w = p.Position.X + 55.8
			p.CFrame = CFrame.new(-70, p.Position.Y, 65.8 - w) * CFrame.Angles(0, math.pi / 2, 0) * p.CFrame.Rotation
		end
	end
	-- c. the empty shop: lights out, a dark lining, 임대문의 on the glass
	for _, l in ipairs(store15:GetDescendants()) do
		if l:IsA("Light") and l.Parent and l.Parent:IsA("BasePart") and (l.Parent :: BasePart).Position.X < -106 then l.Enabled = false end
	end
	local DIM = Color3.fromRGB(38, 38, 42)
	local X0, X1, Z0, Z1 = -134.3, -106.2, 66.1, 90
	part("VacantFloor", Vector3.new(X1 - X0, 0.04, Z1 - Z0), CFrame.new((X0 + X1) / 2, 0.62, (Z0 + Z1) / 2), Color3.fromRGB(70, 70, 74), store15, { noshadow = true, material = Enum.Material.Concrete })
	part("VacantCeiling", Vector3.new(X1 - X0, 0.1, Z1 - Z0), CFrame.new((X0 + X1) / 2, 20.6, (Z0 + Z1) / 2), DIM, store15, { noshadow = true })
	part("VacantBack", Vector3.new(X1 - X0, 20, 0.2), CFrame.new((X0 + X1) / 2, 10.6, Z1), DIM, store15, { noshadow = true })
	for _, x in ipairs({ X0 + 0.05, X1 - 0.05 }) do
		part("VacantSide", Vector3.new(0.1, 20, Z1 - Z0), CFrame.new(x, 10.6, (Z0 + Z1) / 2), DIM, store15, { noshadow = true })
	end
	-- the store's lettering on that glass goes
	for _, p in ipairs(store15:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "GlassLettering" or p.Name == "GlassMark") and p.Position.Z < 66 and p.Position.X < -106 then p:Destroy() end
	end
	-- (user 2026-10-30, later) the 임대문의 papers are on the east face's
	-- unused part instead (south of the store's pier, glass z 147..208, the
	-- beach side): that room dark as well; the north-west room keeps only its
	-- lights off
	local EX0, EX1, EZ0, EZ1 = -80, -56.2, 146.4, 208.6
	part("VacantFloor", Vector3.new(EX1 - EX0, 0.04, EZ1 - EZ0), CFrame.new((EX0 + EX1) / 2, 0.62, (EZ0 + EZ1) / 2), Color3.fromRGB(70, 70, 74), store15, { noshadow = true, material = Enum.Material.Concrete })
	part("VacantCeiling", Vector3.new(EX1 - EX0, 0.1, EZ1 - EZ0), CFrame.new((EX0 + EX1) / 2, 20.6, (EZ0 + EZ1) / 2), DIM, store15, { noshadow = true })
	part("VacantBack", Vector3.new(0.2, 20, EZ1 - EZ0), CFrame.new(EX0, 10.6, (EZ0 + EZ1) / 2), DIM, store15, { noshadow = true })
	for _, z in ipairs({ EZ0 + 0.05, EZ1 - 0.05 }) do
		part("VacantSide", Vector3.new(EX1 - EX0, 20, 0.1), CFrame.new((EX0 + EX1) / 2, 10.6, z), DIM, store15, { noshadow = true })
	end
	-- the papers: white sheets taped on the east glass, facing out (on its
	-- outer face: behind Glass the writing did not show); u = z along the glass
	local PAPER, RED = Color3.fromRGB(248, 247, 242), Color3.fromRGB(226, 36, 40)
	local function sheet(u: number, y: number, w: number, h: number, tilt: number, body: string, size: number?, color: Color3?)
		local c = Vector3.new(-55.77, y, u)
		local p = part("RentPaper", Vector3.new(w, h, 0.02), CFrame.lookAt(c, c + Vector3.new(1, 0, 0)) * CFrame.Angles(0, 0, math.rad(tilt)), PAPER, store15, { noshadow = true })
		local g = gui(p, Enum.NormalId.Front, 60)
		local l = text(g, body, color or RED, Enum.Font.GothamBlack)
		l.Size = UDim2.fromScale(size or 0.86, size or 0.86)
		l.Position = UDim2.fromScale((1 - (size or 0.86)) / 2, (1 - (size or 0.86)) / 2)
		-- tape at the top corners
		for _, s in ipairs({ -1, 1 }) do
			part("RentTape", Vector3.new(0.9, 0.3, 0.01), p.CFrame * CFrame.new(s * (w / 2 - 0.2), h / 2 - 0.05, -0.02) * CFrame.Angles(0, 0, math.rad(s * 35)), Color3.fromRGB(225, 225, 215), store15, { noshadow = true, t = 0.35 })
		end
		return l
	end
	-- 임 · 대 · 문 · 의, one big sheet in each pane (mullions every 7.04 from
	-- z 145.04); seen from the street south (+z) is on the left, so 임 is the
	-- south one
	sheet(176.72, 10.2, 3.6, 5.0, 2, "임", 0.96)
	sheet(169.68, 10.4, 3.6, 5.0, -1, "대", 0.96)
	sheet(162.64, 10.1, 3.6, 5.0, 1.5, "문", 0.96, Color3.fromRGB(30, 30, 30))
	sheet(155.60, 10.5, 3.8, 5.2, -2, "의", 0.96, Color3.fromRGB(30, 30, 30))
	-- the agent's notes, small, lower down (our own, made-up agency)
	for _, u in ipairs({ 169.68, 149.5 }) do
		local l = sheet(u, 5.6, 2.6, 1.9, 0, "임대문의\n오후부동산", 0.8, Color3.fromRGB(30, 30, 30))
		local edge = Instance.new("UIStroke") edge.Color = Color3.fromRGB(40, 90, 200) edge.Thickness = 3 edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = l
	end
	sheet(149.5, 10.4, 3.8, 5.2, -1.5, "임대\n문의", 0.8)
	-- d. the pizza shop
	local F = store15:FindFirstChild("PizzaFront")
	if F then
		for _, n in ipairs({ "PizzaFlowerPost", "PizzaFlowers" }) do
			local p = F:FindFirstChild(n)
			if p then p:Destroy() end
		end
		-- the corner wall (z 66.3..83.6) as a second window bay: tiled base,
		-- glass with mullions, a sill, the red awning, the white band with the name
		local X = -135.02
		local Z0, Z1 = 66.4, 83.6
		local WHITE = Color3.fromRGB(246, 246, 244)
		local function slab(name, x0, y0, z0, x1, y1, z1, color, opt)
			local lo, hi = Vector3.new(math.min(x0, x1), y0, math.min(z0, z1)), Vector3.new(math.max(x0, x1), y1, math.max(z0, z1))
			return part(name, hi - lo, CFrame.new((lo + hi) / 2), color, F, opt)
		end
		local band = slab("PizzaBand", X - 0.5, 14.6, Z0, X, 20.6, Z1, WHITE)
		local bl = text(gui(band, Enum.NormalId.Left, 20), "OHU PIZZA", RED, Enum.Font.GothamBlack)
		bl.Size = UDim2.fromScale(0.8, 0.62) bl.Position = UDim2.fromScale(0.1, 0.19)
		local base = slab("PizzaBase", X - 0.4, 0.6, Z0, X, 6.4, Z1, Color3.fromRGB(226, 226, 222), { material = Enum.Material.Marble })
		local tl = text(gui(base, Enum.NormalId.Left, 16), "FRESH · HOT · BY THE SLICE", RED, Enum.Font.GothamBold)
		tl.Size = UDim2.fromScale(0.86, 0.34) tl.Position = UDim2.fromScale(0.07, 0.33)
		slab("PizzaGlass", X - 0.3, 6.4, Z0, X - 0.2, 12.6, Z1, Color3.fromRGB(70, 100, 120), { material = Enum.Material.Glass, t = 0.3 })
		for _, zz in ipairs({ Z0 + 0.15, (Z0 + Z1) / 2, Z1 - 0.15 }) do
			slab("PizzaMullion", X - 0.45, 6.4, zz - 0.15, X - 0.25, 12.6, zz + 0.15, Color3.fromRGB(200, 200, 204), { material = Enum.Material.Metal })
		end
		slab("PizzaSill", X - 0.6, 6.3, Z0, X, 6.5, Z1, Color3.fromRGB(200, 200, 204), { material = Enum.Material.Metal })
		local AW = 3
		local aw = part("PizzaAwning", Vector3.new(0.15, AW, Z1 - Z0), CFrame.new(X - AW / 2 * math.sin(math.rad(55)) - 0.1, 13.4, (Z0 + Z1) / 2) * CFrame.Angles(0, 0, math.rad(-55)), RED, F, { material = Enum.Material.Fabric })
		local al = text(gui(aw, Enum.NormalId.Left, 24), "OHU PIZZA", WHITE, Enum.Font.GothamBold)
		al.Size = UDim2.fromScale(0.5, 0.5) al.Position = UDim2.fromScale(0.25, 0.25)
	end
	table.insert(log, "OH24 corner: stack + papers east, 호빵 north, vacant shop, pizza corner bay")
end

---------------------------------------------------------------- 16. pizza sign up (user 2026-10-30, screenshot)
-- The white band and the awnings up to the OH24 sign's height (its fascia is
-- y 20..27): band 14.6..20.6 → 20..27, awnings up 5.4; the windows and the
-- entrance recess grow up to 20 to fill the gap (a transom over the door).
-- The band and an awning carry on round the corner along the north face to
-- the store's pier (x -135.5..-106.4), in front of the black fascia there.
if store15 and not store15:GetAttribute("Polish1030_16") then
	store15:SetAttribute("Polish1030_16", true)
	local F = store15:FindFirstChild("PizzaFront")
	if F then
		local TOP = 20 -- the new underside of the band
		local function span(p: BasePart, y0: number, y1: number)
			p.Size = Vector3.new(p.Size.X, y1 - y0, p.Size.Z)
			p.CFrame = p.CFrame.Rotation + Vector3.new(p.Position.X, (y0 + y1) / 2, p.Position.Z)
		end
		for _, p in ipairs(F:GetChildren()) do
			if not p:IsA("BasePart") then continue end
			if p.Name == "PizzaBand" then span(p, TOP, 27)
			elseif p.Name == "PizzaAwning" then p.CFrame = p.CFrame + Vector3.new(0, 5.4, 0)
			elseif p.Name == "PizzaGlass" or p.Name == "PizzaMullion" then span(p, 6.4, TOP)
			elseif p.Name == "PizzaEntryBack" then span(p, 0.6, TOP) end
		end
		local X = -135.02
		local RED, WHITE = Color3.fromRGB(222, 40, 50), Color3.fromRGB(246, 246, 244)
		-- a dark glass transom over the door, its frame on the door's head
		part("PizzaTransom", Vector3.new(0.1, TOP - 0.4 - 12.8, 8), CFrame.new(X - 0.4, (12.8 + TOP - 0.4) / 2, 92), Color3.fromRGB(40, 60, 70), F, { material = Enum.Material.Glass, t = 0.25 })
		-- north face: the band (its face to -z) and the awning over the glass
		local NX0, NX1, NZ = -135.52, -106.4, 65.4
		local band = part("PizzaBandNorth", Vector3.new(NX1 - NX0, 27 - TOP, 0.5), CFrame.new((NX0 + NX1) / 2, (TOP + 27) / 2, NZ - 0.25), WHITE, F)
		local frame = Instance.new("Frame") frame.Size = UDim2.fromScale(1, 1) frame.BackgroundTransparency = 1 frame.Parent = gui(band, Enum.NormalId.Front, 20)
		local name = text(frame, "OHU PIZZA", RED, Enum.Font.GothamBlack)
		name.Size = UDim2.fromScale(0.42, 0.62) name.Position = UDim2.fromScale(0.05, 0.19)
		local slogan = text(frame, "SLICE BY THE SEA.", RED, Enum.Font.GothamBold)
		slogan.Size = UDim2.fromScale(0.42, 0.34) slogan.Position = UDim2.fromScale(0.53, 0.33)
		local AW = 3
		local aw = part("PizzaAwningNorth", Vector3.new(NX1 - NX0 - 1, AW, 0.15), CFrame.new((NX0 + NX1) / 2 + 0.5, TOP - 1.2, 65.8 - AW / 2 * math.sin(math.rad(55)) - 0.1) * CFrame.Angles(math.rad(55), 0, 0), RED, F, { material = Enum.Material.Fabric })
		local al = text(gui(aw, Enum.NormalId.Front, 24), "OHU PIZZA  ·  SLICES & SODA", WHITE, Enum.Font.GothamBold)
		al.Size = UDim2.fromScale(0.5, 0.5) al.Position = UDim2.fromScale(0.25, 0.25)
		table.insert(log, "pizza sign up to the OH24 sign, north band + awning")
	end
end

---------------------------------------------------------------- 17. pizza wall on the north face (user 2026-10-30)
-- Under the north band (x -135.4..-106.4) the store's black frame and glass go
-- (the corner pier, the mullions, the glass, the kickplate) and the pizza
-- shop's wall comes instead, as on its west front: marble base with red
-- letters, tall glass with light mullions about every 8.6, a sill. The
-- store's own pier at x -105.45 stays.
if store15 and not store15:GetAttribute("Polish1030_17") then
	store15:SetAttribute("Polish1030_17", true)
	local F = store15:FindFirstChild("PizzaFront")
	local NX0, NX1 = -135.42, -106.4
	for _, d in ipairs(store15:GetChildren()) do
		if d:IsA("BasePart") and d.Position.Z > 65 and d.Position.Z < 66.2 and d.Position.Y < 20
			and d.Position.X > NX0 - 1 and d.Position.X < NX1 + 0.1
			and (d.Name == "FacadePier" or d.Name == "Mullion" or d.Name == "FrontGlass" or d.Name == "Kickplate") then
			d:Destroy()
		end
	end
	if F then
		local RED = Color3.fromRGB(222, 40, 50)
		local base = part("PizzaBaseNorth", Vector3.new(NX1 - NX0, 5.8, 0.4), CFrame.new((NX0 + NX1) / 2, 0.6 + 2.9, 65.6), Color3.fromRGB(226, 226, 222), F, { material = Enum.Material.Marble, collide = true })
		local bg = gui(base, Enum.NormalId.Front, 16)
		local big = text(bg, "PIZZA", RED, Enum.Font.GothamBlack)
		big.Size = UDim2.fromScale(0.3, 0.92) big.Position = UDim2.fromScale(0.66, 0.04)
		local line = text(bg, "FRESH · HOT · BY THE SLICE", RED, Enum.Font.GothamBold)
		line.Size = UDim2.fromScale(0.56, 0.34) line.Position = UDim2.fromScale(0.05, 0.33)
		part("PizzaGlassNorth", Vector3.new(NX1 - NX0, 20 - 6.4, 0.1), CFrame.new((NX0 + NX1) / 2, (6.4 + 20) / 2, 65.75), Color3.fromRGB(70, 100, 120), F, { material = Enum.Material.Glass, t = 0.3, collide = true })
		local n = 4
		for i = 0, n do
			local x = NX0 + 0.15 + i * (NX1 - NX0 - 0.3) / n
			part("PizzaMullion", Vector3.new(0.3, 20 - 6.4, 0.2), CFrame.new(x, (6.4 + 20) / 2, 65.6), Color3.fromRGB(200, 200, 204), F, { material = Enum.Material.Metal })
		end
		part("PizzaSill", Vector3.new(NX1 - NX0, 0.2, 0.6), CFrame.new((NX0 + NX1) / 2, 6.4, 65.5), Color3.fromRGB(200, 200, 204), F, { material = Enum.Material.Metal })
	end
	table.insert(log, "pizza wall on the north face")
end

---------------------------------------------------------------- 18. pizza corner joined (user 2026-10-30)
-- The north wall and the west corner bay met with a visible split at the
-- corner (x -135.5, z 66): the west bay's band, base, glass and sill run on
-- north to the north wall's outer face, and the two awnings run past the
-- corner to each other's outer edge, so the corner reads as one piece.
if store15 and not store15:GetAttribute("Polish1030_18") then
	store15:SetAttribute("Polish1030_18", true)
	local F = store15:FindFirstChild("PizzaFront")
	if F then
		local function toZ(p: BasePart, z0: number)
			local z1 = p.Position.Z + p.Size.Z / 2
			p.Size = Vector3.new(p.Size.X, p.Size.Y, z1 - z0)
			p.CFrame = p.CFrame.Rotation + Vector3.new(p.Position.X, p.Position.Y, (z0 + z1) / 2)
		end
		local OUT = { PizzaBand = 64.9, PizzaBase = 65.4, PizzaGlass = 65.7, PizzaSill = 65.2 }
		for _, p in ipairs(F:GetChildren()) do
			-- (the corner bay's parts: on the west wall, starting at z 66.4)
			if p:IsA("BasePart") and p.Position.X < -135 and math.abs(p.Position.Z - p.Size.Z / 2 - 66.4) < 0.05 then
				if OUT[p.Name] then toZ(p, OUT[p.Name])
				elseif p.Name == "PizzaAwning" then
					-- (turned about z: its length is size z) out to the north awning's outer edge
					toZ(p, 63.2)
				end
			end
		end
		local aw = F:FindFirstChild("PizzaAwningNorth")
		if aw and aw:IsA("BasePart") then
			-- (its length is size x) west to the west awning's outer edge
			local x1 = aw.Position.X + aw.Size.X / 2
			local x0 = -137.6
			aw.Size = Vector3.new(x1 - x0, aw.Size.Y, aw.Size.Z)
			aw.CFrame = aw.CFrame.Rotation + Vector3.new((x0 + x1) / 2, aw.Position.Y, aw.Position.Z)
		end
	end
	table.insert(log, "pizza corner joined")
end

---------------------------------------------------------------- 19. cafe upstairs seats (user 2026-10-30, phone shots)
-- a. the stools at the rail bar (MezzBar) higher, as at the window bar:
--    seat top 1.2 under the bar top, legs longer, foot ring and sit seat up
-- b. the long tables (x -219) get the lounge's sofas instead of stools: two
--    per table, each a copy of a lounge Sofa with its two sit seats, facing
--    the table; the tables come down to the lounge tables' height (3.9 over
--    the floor) to go with the low seats
if cafe and not cafe:GetAttribute("Polish1030_19") then
	cafe:SetAttribute("Polish1030_19", true)
	local function halfY(p: BasePart): number
		local c, s = p.CFrame, p.Size / 2
		return math.abs(c.XVector.Y) * s.X + math.abs(c.YVector.Y) * s.Y + math.abs(c.ZVector.Y) * s.Z
	end
	-- a.
	local bar = cafe:FindFirstChild("MezzBar")
	if bar and bar:IsA("BasePart") then
		local target = bar.Position.Y + bar.Size.Y / 2 - 1.2
		local seats = {}
		for _, d in ipairs(cafe:GetChildren()) do if d:IsA("Seat") and d.Name == "BarStool" then table.insert(seats, d) end end
		for _, m in ipairs(cafe:GetChildren()) do
			local pad = m:IsA("Model") and m.Name == "ClubStool" and m:FindFirstChild("SeatPad")
			if not pad or math.abs(pad.Position.X - bar.Position.X) > 8 or pad.Position.Y < 28 then continue end
			local D = target - (pad.Position.Y + halfY(pad))
			if math.abs(D) < 0.05 then continue end
			local floor = math.huge
			for _, d in ipairs(m:GetChildren()) do
				if d:IsA("BasePart") and d.Name == "Leg" then floor = math.min(floor, d.Position.Y - d.Size.X / 2) end
			end
			local legLen = target - D - floor
			for _, d in ipairs(m:GetChildren()) do
				if not d:IsA("BasePart") then continue end
				if d.Name == "SeatPad" or d.Name == "SeatShell" then
					d.CFrame = d.CFrame + Vector3.new(0, D, 0)
				elseif d.Name == "Leg" then
					d.Size = Vector3.new(d.Size.X + D, d.Size.Y, d.Size.Z)
					d.CFrame = d.CFrame + Vector3.new(0, D / 2, 0)
				elseif d.Name == "FootRing" then
					d.CFrame = d.CFrame + Vector3.new(0, (d.Position.Y - floor) / legLen * D, 0)
				end
			end
			for _, s in ipairs(seats) do
				if Vector2.new(s.Position.X - pad.Position.X, s.Position.Z - pad.Position.Z).Magnitude < 1 then
					s.CFrame = s.CFrame + Vector3.new(0, D, 0)
				end
			end
		end
	end
	-- b.
	local FLOOR = 28.6
	local sofa, benches = nil, {}
	for _, d in ipairs(cafe:GetChildren()) do
		if d.Name == "Sofa" and d:IsA("BasePart") and d.Position.Y < 20 then sofa = d break end
	end
	if sofa then
		for _, d in ipairs(cafe:GetChildren()) do
			if d:IsA("Seat") and d.Name == "Bench" and (d.Position - sofa.Position).Magnitude < 4 then table.insert(benches, d) end
		end
	end
	local tables = {}
	for _, d in ipairs(cafe:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "CafeTable" and d.Position.Y > 28 and d.Size.Z > 20 then table.insert(tables, d) end
	end
	if sofa and #tables > 0 then
		-- the stools go
		for _, d in ipairs(cafe:GetChildren()) do
			local p = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
			if p and p.Y > 28 and math.abs(p.X + 211) < 1.5 and (d.Name == "ClubStool" or d.Name == "CafeStool" or d.Name == "CafeStoolCushion") then d:Destroy() end
		end
		local sofaFloor = sofa.Position.Y - halfY(sofa)
		for _, t in ipairs(tables) do
			-- the table down to 3.9 over the floor, its legs shorter
			local drop = (t.Position.Y + t.Size.Y / 2) - (FLOOR + 3.9)
			if drop > 0.05 then
				t.CFrame = t.CFrame - Vector3.new(0, drop, 0)
				for _, l in ipairs(cafe:GetChildren()) do
					if l:IsA("BasePart") and l.Name == "TableLeg" and l.Position.Y > 28 and math.abs(l.Position.X - t.Position.X) < t.Size.X / 2 and math.abs(l.Position.Z - t.Position.Z) < t.Size.Z / 2 then
						local h = halfY(l) * 2
						local nh = h - drop
						local axis = if math.abs(l.CFrame.XVector.Y) > 0.9 then "X" elseif math.abs(l.CFrame.ZVector.Y) > 0.9 then "Z" else "Y"
						l.Size = Vector3.new(if axis == "X" then nh else l.Size.X, if axis == "Y" then nh else l.Size.Y, if axis == "Z" then nh else l.Size.Z)
						l.CFrame = l.CFrame - Vector3.new(0, drop / 2, 0)
					end
				end
			end
			-- two sofas on the east side, facing the table (-x), like the lounge's
			local x = t.Position.X + t.Size.X / 2 + 1 + sofa.Size.Z / 2
			-- (three a table, user 2026-10-30, later: was two)
			for _, dz in ipairs({ -t.Size.Z / 3, 0, t.Size.Z / 3 }) do
				local at = CFrame.new(x, FLOOR + (sofa.Position.Y - sofaFloor), t.Position.Z + dz) * sofa.CFrame.Rotation
				local copy = sofa:Clone()
				copy.CFrame = at
				copy.Parent = cafe
				for _, b in ipairs(benches) do
					local rel = sofa.CFrame:ToObjectSpace(b.CFrame)
					local nb = b:Clone()
					nb.CFrame = at * rel
					nb.Parent = cafe
				end
			end
		end
	end
	table.insert(log, "cafe rail stools up, long tables: sofas")
end

---------------------------------------------------------------- 20. vintage cake in the case (user 2026-10-30)
-- the user's vintage lettering cake (ServerStorage.ArtAssets.Foods.
-- VintageLetteringCake, D-617) in the pastry case: the first column of
-- cakes (one per tier, nearest the till) becomes it, the same 1.25 across
local vintage = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
vintage = vintage and vintage:FindFirstChild("Foods") and vintage.Foods:FindFirstChild("VintageLetteringCake")
if cafe and vintage and not cafe:FindFirstChild("CaseVintageCake") then
	local col = {}
	local xMax = -math.huge
	for _, d in ipairs(cafe:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "CakeDisplay" then xMax = math.max(xMax, d.Position.X) end
	end
	for _, d in ipairs(cafe:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "CakeDisplay" and math.abs(d.Position.X - xMax) < 0.1 then table.insert(col, d) end
	end
	for _, d in ipairs(col) do
		local m = vintage:Clone()
		local _, s0 = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * d.Size.X / math.max(s0.X, s0.Z))
		local cf, s = m:GetBoundingBox()
		local bottom = d.Position.Y - d.Size.Y / 2
		m:PivotTo(m:GetPivot() + Vector3.new(d.Position.X - cf.X, bottom + s.Y / 2 - cf.Y, d.Position.Z - cf.Z))
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false end
		end
		m.Name = "CaseVintageCake"
		m.Parent = cafe
		d:Destroy()
	end
	table.insert(log, "case vintage cakes " .. #col)
end

---------------------------------------------------------------- 21. ducks bigger again (user 2026-10-30, later)
if beach then
	local n = 0
	for _, m in ipairs(beach:GetChildren()) do
		local duck = m:IsA("Model") and m.Name:match("^RubberDuck") and m:FindFirstChild("Duck")
		if duck and not duck:GetAttribute("Big2") then
			local base = m:GetAttribute("Base")
			local rot, at = duck.CFrame.Rotation, duck.Position
			duck.Size = duck.Size * 1.6
			local y = if typeof(base) == "Vector3" then base.Y + duck.Size.Y * 0.35 else at.Y
			duck.CFrame = CFrame.new(at.X, y, at.Z) * rot
			duck:SetAttribute("Big2", true)
			n += 1
		end
	end
	table.insert(log, "ducks x1.6 " .. n)
end

return table.concat(log, " | ")
