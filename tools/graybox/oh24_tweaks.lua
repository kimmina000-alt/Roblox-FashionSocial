-- OH24 convenience store tweaks (user notes 2026-10-27, D-440): run in Edit
-- mode after the layout chain (… → scale_furniture → cafe_layout_v3/v4).
-- World coordinates of the finished store (x -135..-56, z 66..210, ceiling
-- 20.7, the north front glass at z 66, the east front glass at x -56).
-- Runs once (attribute OH24TweaksV1).
--   1  the 냉장 · 냉동 wall up to just under the ceiling; the other cases
--      (drinks fridge, gondolas, chilled case) 1/4 taller
--   2  the window bars as deep as the cafe's (4.7), stools and legs with them
--   3  microwave and hot water up on the bar top
--   4  the corner deck cut at z 100 (the south part gone), the east bar and its
--      stools only over the deck, the table set moved in with its stools set
--      apart, the cafe's pot plant on the deck
--   5  a second door in the east front (z 127..135)
--   6  posters / lettering on the north glass, stacked chairs, folded tables,
--      crates and a standing banner outside (like the user's photo, our names)

local S = workspace.Hongdae_Layout:FindFirstChild("OH24Store", true)
if S:GetAttribute("OH24TweaksV1") then return "already done" end
local CS = game:GetService("CollectionService")
local FLOOR, CEIL = 0.6, 20.7
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
local function all(f) local r = {} for _, p in ipairs(S:GetDescendants()) do if p:IsA("BasePart") and f(p) then table.insert(r, p) end end return r end
local function part(name, size, cf, color, opt)
	opt = opt or {}
	local p = Instance.new(opt.class or "Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color p.Anchored = true
	p.Material = opt.material or Enum.Material.SmoothPlastic
	p.Transparency = opt.t or 0
	p.CanCollide = opt.col == true
	p.CastShadow = opt.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	p.Parent = opt.parent or S
	return p
end
local function label(p, face, text, color, font, bg, ppStud)
	local g = Instance.new("SurfaceGui")
	g.Face = face g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = ppStud or 40 g.LightInfluence = 0.3
	pcall(function() (g :: any).MaxDistance = 120 end)
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1) l.BorderSizePixel = 0 l.TextScaled = true l.RichText = true
	l.BackgroundTransparency = if bg then 0 else 1
	if bg then l.BackgroundColor3 = bg end
	l.Font = font or Enum.Font.GothamBold l.TextColor3 = color l.Text = text
	l.Parent = g
	return l
end

----------------------------------------------------------------------------
-- 1. taller cases: every part inside a case's footprint (its goods too)
-- keeps its place in proportion; tall pieces stretch, small ones move
local function stretch(x0, z0, x1, z1, y0, y1, newTop)
	local k = (newTop - y0) / (y1 - y0)
	local n = 0
	for _, p in ipairs(all(function(p)
		local px, py, pz = p.Position.X, p.Position.Y, p.Position.Z
		return px >= x0 - 0.2 and px <= x1 + 0.2 and pz >= z0 - 0.4 and pz <= z1 + 0.4 and py >= y0 and py <= y1 + 0.05
	end)) do
		local a, b, c, d, e, f = bounds(p)
		local rot = p.CFrame.Rotation
		if e - b > (y1 - y0) * 0.4 then -- a tall piece: stretch it
			local nb, ne = y0 + (b - y0) * k, y0 + (e - y0) * k
			local c2 = Vector3.new(p.Position.X, (nb + ne) / 2, p.Position.Z)
			local up = rot.UpVector
			local s = p.Size
			if math.abs(up.Y) > 0.9 then p.Size = Vector3.new(s.X, ne - nb, s.Z)
			elseif math.abs(rot.RightVector.Y) > 0.9 then p.Size = Vector3.new(ne - nb, s.Y, s.Z)
			else p.Size = Vector3.new(s.X, s.Y, ne - nb) end
			p.CFrame = CFrame.new(c2) * rot
		else
			local ny = y0 + (p.Position.Y - y0) * k
			-- (goods sit on their shelf: keep the bottom's offset, not the centre's)
			ny = y0 + (b - y0) * k + (p.Position.Y - b)
			p.CFrame = CFrame.new(p.Position.X, ny, p.Position.Z) * rot
		end
		n += 1
		_ = a _ = c _ = d _ = f
	end
	return n
end
do
	local function caseBounds(prefix)
		local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for _, p in ipairs(all(function(p) return p.Name:sub(1, #prefix) == prefix end)) do
			local a, b, c, d, e, f = bounds(p)
			x0 = math.min(x0, a) y0 = math.min(y0, b) z0 = math.min(z0, c) x1 = math.max(x1, d) y1 = math.max(y1, e) z1 = math.max(z1, f)
		end
		return x0, y0, z0, x1, y1, z1
	end
	local x0, y0, z0, x1, y1, z1 = caseBounds("Cold")
	local n = stretch(x0, z0, x1, z1, y0, y1, CEIL - 0.5)
	for _, pre in ipairs({ "Fridge", "Chilled" }) do
		local a, b, c, d, e, f = caseBounds(pre)
		n += stretch(a, c, d, f, b, e, b + (e - b) * 1.25)
	end
	for _, m in ipairs(S:GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Gondola") then
			local cf, size = m:GetBoundingBox()
			local a, c, d, f = cf.Position.X - size.X / 2, cf.Position.Z - size.Z / 2, cf.Position.X + size.X / 2, cf.Position.Z + size.Z / 2
			n += stretch(a, c, d, f, FLOOR, cf.Position.Y + size.Y / 2, FLOOR + (cf.Position.Y + size.Y / 2 - FLOOR) * 1.25)
		end
	end
	table.insert(log, "1 cases " .. n)
end

----------------------------------------------------------------------------
-- 4 (before the bars: the cut decides where the east bar ends). Deck cut.
local CUT = 100
do
	for _, p in ipairs(all(function(p) return p.Name == "Deck" or p.Name == "DeckStep" end)) do
		local a, b, c, d, e, f = bounds(p)
		setBox(p, a, b, c, d, e, CUT + (if p.Name == "DeckStep" then 1.6 else 0))
		_ = f
	end
	table.insert(log, "4 deck cut")
end

----------------------------------------------------------------------------
-- 2. window bars 4.7 deep (inward), legs and stools with them; the east bar
-- only over the deck, the stools past it go
local BAR_END = 95
do
	local W = 4.7
	for _, p in ipairs(all(function(p) return p.Name == "WindowBar" end)) do
		local a, b, c, d, e, f = bounds(p)
		if d - a > f - c then -- the north bar (along x, glass at z 66)
			setBox(p, a, b, c, d, e, c + W)
		else -- the east bar (along z, glass at x -56)
			setBox(p, d - W, b, c, d, e, BAR_END)
		end
	end
	for _, p in ipairs(all(function(p) return p.Name == "BarLeg" end)) do
		if p.Position.X > -60 and p.Position.Z > 69 then -- east bar legs
			if p.Position.Z > BAR_END then p:Destroy() else p.CFrame = p.CFrame + Vector3.new(-2.3, 0, 0) end
		elseif p.Position.Z < 70 then
			p.CFrame = p.CFrame + Vector3.new(0, 0, 2.3)
		end
	end
	for _, p in ipairs(all(function(p) return (p.Name == "WindowStool" or p.Name == "StoolLeg") and p.Position.X > -62 end)) do
		if p.Position.Z > BAR_END - 1 then p:Destroy() else p.CFrame = p.CFrame + Vector3.new(-2.3, 0, 0) end
	end
	table.insert(log, "2 bars")
end

----------------------------------------------------------------------------
-- 3. microwave and hot water on the bar top
do
	local bar
	for _, p in ipairs(all(function(p) return p.Name == "WindowBar" end)) do local a, _, c, d, _, f = bounds(p) if d - a > f - c then bar = p end end
	local _, _, _, _, top = bounds(bar)
	local mw = all(function(p) return p.Name == "Microwave" end)[1]
	local _, mb = bounds(mw)
	local dy = top - mb
	for _, p in ipairs(all(function(p) return p.Name == "Microwave" or p.Name == "MicrowaveDoor" or p.Name == "HotWater" or p.Name == "HotWaterTap" or p.Name == "StationSign" end)) do
		p.CFrame = p.CFrame + Vector3.new(0, dy, 0)
	end
	table.insert(log, string.format("3 up %.1f", dy))
end

----------------------------------------------------------------------------
-- 4b. the table set onto the deck, stools 1.2 further out; the plant
do
	local tbl = all(function(p) return p.Name == "DeckTable" end)[1]
	local from = tbl.Position
	local to = Vector3.new(-76, from.Y, 86)
	for _, p in ipairs(all(function(p) return p.Name == "DeckTable" or p.Name == "DeckTableLeg" or p.Name == "DeckStool" end)) do
		local off = p.Position - from
		if p.Name == "DeckStool" then off = off + Vector3.new(math.sign(off.X) * 1.2, 0, 0) end
		p.CFrame = CFrame.new(to + Vector3.new(off.X, off.Y, off.Z)) * p.CFrame.Rotation
	end
	-- the stool legs of the deck stools (StoolLeg under each DeckStool before the move)
	for _, p in ipairs(all(function(p) return p.Name == "StoolLeg" and p.Position.X < -78 and p.Position.Z > 112 and p.Position.Z < 124 end)) do
		local off = p.Position - from
		off = off + Vector3.new(math.sign(off.X) * 1.2, 0, 0)
		p.CFrame = CFrame.new(to + off) * p.CFrame.Rotation
	end
	for _, p in ipairs(all(function(p) return p.Name == "PlantPot" or p.Name == "PlantLeaves" end)) do p:Destroy() end
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local src = art and art:FindFirstChild("CafePotPlant")
	if src then
		local m = src:Clone()
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
		local cf, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (Vector3.new(-58.8, 1.6 + size.Y / 2, 97.5) - cf.Position))
		m.Parent = S
	end
	table.insert(log, "4b table + plant")
end

----------------------------------------------------------------------------
-- 5. a second door in the east front, z 127..135 (centre 131)
do
	local ZC, DOOR = 131, 8
	local G0, G1 = ZC - DOOR / 2 - 0.4, ZC + DOOR / 2 + 0.4
	local function split(p)
		local a, b, c, d, e, f = bounds(p)
		if c < G0 and f > G1 then
			local q = p:Clone() q.Parent = p.Parent
			setBox(p, a, b, c, d, e, G0)
			setBox(q, a, b, G1, d, e, f)
		end
	end
	for _, p in ipairs(all(function(p) return (p.Name == "FrontGlass" or p.Name == "Kickplate") and p.Position.X > -57 end)) do split(p) end
	for _, p in ipairs(all(function(p) return p.Name == "Mullion" and p.Position.X > -57 and p.Position.Z > G0 and p.Position.Z < G1 end)) do p:Destroy() end
	local northDoor = S:FindFirstChild("AutoDoor")
	local oldC = northDoor:GetPivot().Position
	local T = CFrame.new(-56, oldC.Y, ZC) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(oldC):Inverse()
	local d2 = northDoor:Clone()
	for _, p in ipairs(d2:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = T * p.CFrame
			local s = p:GetAttribute("Slide")
			if typeof(s) == "Vector3" then p:SetAttribute("Slide", T.Rotation * s) end
		end
	end
	d2.WorldPivot = T * northDoor.WorldPivot
	d2.Name = "AutoDoor"
	d2.Parent = S
	CS:AddTag(d2, "AutoDoor")
	local head = all(function(p) return p.Name == "DoorHead" end)[1]
	local h2 = head:Clone()
	h2.CFrame = T * head.CFrame
	h2.Parent = S
	table.insert(log, "5 door")
end

----------------------------------------------------------------------------
-- 6. the north glass dressed like a real store front, things stacked outside
do
	local GZ = 65.74 -- just outside the glass
	local function onGlass(name, x0, x1, y0, y1, text, color, bg, font)
		local p = part(name, Vector3.new(x1 - x0, y1 - y0, 0.02), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, GZ), bg or Color3.new(1, 1, 1), { t = if bg then 0 else 1, shadow = false })
		p.CanQuery = false p.CanTouch = false
		label(p, Enum.NormalId.Front, text, color, font, bg)
		return p
	end
	-- the upper glass: our slogan in white letters, as on the photo's top band
	onGlass("GlassLettering", -132, -108, 14.2, 15.6, "Fresh · Friendly · OH24", Color3.new(1, 1, 1), nil, Enum.Font.GothamMedium)
	onGlass("GlassLettering", -96, -60, 14.2, 15.6, "24H  Everyday Fresh", Color3.new(1, 1, 1), nil, Enum.Font.GothamMedium)
	-- a red banner across the west glass
	onGlass("GlassBanner", -129, -111, 9.2, 11.2, "호빵 · 어묵 판매중", Color3.fromRGB(255, 240, 200), Color3.fromRGB(200, 40, 40), Enum.Font.GothamBlack)
	-- posters and stickers
	-- (on the glass west of the door, not in the doorway)
	onGlass("GlassPoster", -115.0, -112.0, 4.5, 9.0, "<b>이달의 행사</b>\n1+1 · 2+1\nOH24", Color3.fromRGB(20, 60, 80), Color3.fromRGB(235, 248, 250))
	onGlass("GlassPoster", -95.6, -92.4, 4.5, 8.5, "<b>신상품</b>\n도시락\n출시!", Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 160, 160))
	onGlass("GlassSticker", -110.8, -108.6, 3.0, 4.6, "택배\n접수", Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 90, 170))
	onGlass("GlassSticker", -108.2, -106.8, 3.0, 4.6, "ATM", Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 140, 30))
	onGlass("GlassSticker", -64.0, -61.6, 3.0, 4.6, "24시\n영업", Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 160, 160))
	-- outside on the pavement, east of the door: stacked chairs, folded tables, crates, a banner
	local OUT = Instance.new("Model") OUT.Name = "OH24FrontStack" OUT.Parent = S
	local TEALC = Color3.fromRGB(40, 175, 185)
	local Y0 = 0.6
	local function chairStack(x, z, n)
		for i = 0, n - 1 do
			local y = Y0 + 1.6 + i * 0.32
			part("StackChairSeat", Vector3.new(1.8, 0.14, 1.7), CFrame.new(x, y, z), TEALC, { parent = OUT })
			part("StackChairBack", Vector3.new(1.8, 1.7, 0.14), CFrame.new(x, y + 0.9, z + 0.85) * CFrame.Angles(math.rad(-12), 0, 0), TEALC, { parent = OUT })
		end
		for _, l in ipairs({ { -0.8, -0.75 }, { 0.8, -0.75 }, { -0.8, 0.75 }, { 0.8, 0.75 } }) do
			part("StackChairLeg", Vector3.new(0.14, 1.6, 0.14), CFrame.new(x + l[1], Y0 + 0.8, z + l[2]), TEALC, { parent = OUT })
		end
		local hit = part("StackCollide", Vector3.new(1.9, 1.6 + n * 0.32 + 1.7, 1.9), CFrame.new(x, Y0 + (1.6 + n * 0.32 + 1.7) / 2, z + 0.1), TEALC, { parent = OUT, t = 1, col = true })
		hit.CanQuery = false
	end
	chairStack(-95.2, 62.6, 5)
	chairStack(-92.8, 62.6, 4)
	-- two round tables folded and leaning on the glass
	for i, x in ipairs({ -98.4, -97.6 }) do
		part("FoldedTableTop", Vector3.new(0.12, 3.2, 3.2), CFrame.new(x, Y0 + 1.7, 64.3) * CFrame.Angles(0, math.rad(90), math.rad(-12)), if i == 1 then TEALC else Color3.fromRGB(230, 230, 232), { parent = OUT, shape = Enum.PartType.Cylinder })
	end
	-- crates: blue and green, stacked
	local function crate(x, y, z, col)
		part("Crate", Vector3.new(2.2, 1.1, 1.6), CFrame.new(x, y + 0.55, z), col, { parent = OUT, col = true, material = Enum.Material.Plastic })
		part("CrateRim", Vector3.new(2.24, 0.12, 1.64), CFrame.new(x, y + 1.04, z), col:Lerp(Color3.new(0, 0, 0), 0.2), { parent = OUT })
	end
	local BLUE, GREEN = Color3.fromRGB(40, 110, 210), Color3.fromRGB(40, 160, 80)
	for i = 0, 3 do crate(-89.4, Y0 + i * 1.1, 62.8, if i % 2 == 0 then GREEN else BLUE) end
	for i = 0, 2 do crate(-86.8, Y0 + i * 1.1, 62.8, BLUE) end
	for i = 0, 1 do crate(-88.1, Y0 + i * 1.1, 60.9, BLUE) end
	-- a standing flag banner: OH24 편의점 ←
	part("BannerPole", Vector3.new(0.12, 7, 0.12), CFrame.new(-82.5, Y0 + 3.5, 61.6), Color3.fromRGB(200, 200, 205), { parent = OUT, material = Enum.Material.Metal })
	part("BannerBase", Vector3.new(1.2, 0.3, 1.2), CFrame.new(-82.5, Y0 + 0.15, 61.6), Color3.fromRGB(40, 120, 200), { parent = OUT, col = true })
	local flag = part("BannerFlag", Vector3.new(2.2, 5.4, 0.05), CFrame.new(-81.3, Y0 + 3.9, 61.6), Color3.fromRGB(245, 248, 250), { parent = OUT })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		label(flag, face, '<font color="#1EC8F0">OH24</font>\n\n편\n의\n점\n\n←', Color3.fromRGB(30, 60, 90), Enum.Font.GothamBlack, nil, 30)
	end
	table.insert(log, "6 front dressing")
end

S:SetAttribute("OH24TweaksV1", true)
return table.concat(log, " | ")
