-- polish_1028.lua: Edit-mode post-pass (user 2026-10-28, D-445..D-452).
-- Run after furniture_swap in the layout chain (LAYOUT.md). Idempotent: every
-- block checks a marker first.
--   1. cake case 1.2 studs higher on a riser
--   2. park hoarding along the park walls (only the Ferris wheel shows)
--   3. hanok hoarding just inside the stone walls and behind the gate
--   4. OH24 microwave and hot water dispenser: one box + one front picture each
--   5. beach cafe sea skirt: closes the gap between the floor and the water
--   6. club VIP: side sofas removed, smoked glass partitions up to the ceiling
--   7. 오후네컷: small drum table, shorter ring benches

local W = workspace
local G = W:WaitForChild("Graybox_MainSocial")
local L = W:WaitForChild("Hongdae_Layout")
local report = {}
local function note(s) table.insert(report, s) end

local function part(name, size, cf, color, parent, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Anchored = true
	p.CanCollide = o.collide ~= false
	p.CastShadow = o.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function texture(p, face, id, u, v)
	local t = Instance.new("Texture")
	t.Texture = id
	t.Face = face
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	t.Parent = p
	return t
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then f:Destroy() end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

---------------------------------------------------------------- 1. cake case
do
	local cafe = G["04_Beach_Aquarium"]:FindFirstChild("BeachCafe")
	if cafe and not cafe:GetAttribute("CakeCaseRaised") then
		local RISE = 1.2
		local base
		for _, d in ipairs(cafe:GetChildren()) do
			if d:IsA("BasePart") and (d.Name:match("^Case") or d.Name == "CakeDisplay") then
				d.CFrame += Vector3.new(0, RISE, 0)
				if d.Name == "CaseBase" then base = d end
			end
		end
		if base then
			local frame = cafe:FindFirstChild("CaseFrame")
			local bottom = base.Position.Y - base.Size.Y / 2
			part("CaseRiser", Vector3.new(base.Size.X, RISE, base.Size.Z), CFrame.new(base.Position.X, bottom - RISE / 2, base.Position.Z),
				frame and frame.Color or Color3.fromRGB(240, 236, 228), cafe, { material = frame and frame.Material })
		end
		cafe:SetAttribute("CakeCaseRaised", true)
		note("cake case +" .. RISE)
	end
end

---------------------------------------------------------------- 2. park netting
-- Construction netting like the user's photo (2026-10-28, D-453, replaces the
-- picture boards of D-447/D-448): an opaque teal mesh sheet on scaffold pipes
-- (drawn in the tile) and a blue sheet above and behind it. One straight run:
-- `mid` on the line, `along` its direction, `offset` toward `inside`.
local NET_TEAL, NET_BLUE = "rbxassetid://70770114906607", "rbxassetid://97449992010330" -- net_teal.png / net_blue.png, 8 x 8 studs
local function netting(f, mid, along, len, inside, offset, y0, tealH, top)
	local normal = Vector3.new(-along.Z, 0, along.X)
	if (inside - mid):Dot(normal) < 0 then normal = -normal end
	local function sheet(name, color, id, yA, yB, back)
		local c = Vector3.new(mid.X, (yA + yB) / 2, mid.Z) + normal * (offset + back)
		local p = part(name, Vector3.new(len, yB - yA, 0.3), CFrame.lookAt(c, c + normal), color, f, { material = Enum.Material.Fabric, shadow = false })
		local ts = { texture(p, Enum.NormalId.Back, id, 8, 8), texture(p, Enum.NormalId.Front, id, 8, 8) }
		return p, ts
	end
	local teal, ts = sheet("NetTeal", Color3.fromRGB(40, 150, 142), NET_TEAL, y0, y0 + tealH, 0)
	sheet("NetBlue", Color3.fromRGB(36, 86, 196), NET_BLUE, y0 + tealH - 2, top, 1.6)
	return teal, ts
end

do
	local gate = L:FindFirstChild("AmusementParkGate")
	if gate then
		local f = folder(gate, "ParkHoarding")
		local Y0 = 2.4 -- wall foot
		local inside = Vector3.new(-100, Y0, -350)
		local runs = { -- {x0, z0, x1, z1} 1.2 studs inside the walls
			{ -146.3, -473.3, -146.3, -230.7 }, -- west
			{ -53.0, -473.3, -53.0, -230.7 }, -- east
			{ -146.3, -473.3, -53.0, -473.3 }, -- south
			{ -146.3, -230.7, -127.0, -230.7 }, -- north, west of the gate
			{ -67.0, -230.7, -53.0, -230.7 }, -- north, east of the gate
			{ -127.0, -235.6, -67.0, -235.6 }, -- behind the low entrance boards
		}
		for _, r in ipairs(runs) do
			local a, b = Vector3.new(r[1], 0, r[2]), Vector3.new(r[3], 0, r[4])
			netting(f, (a + b) / 2, (b - a).Unit, (b - a).Magnitude + 0.4, inside, 0, Y0, 16, 30.4)
		end
		note("park netting " .. #runs)
	end
end

---------------------------------------------------------------- 3. hanok hoarding
do
	local f = folder(L, "HanokHoarding")
	local inside = Vector3.new(300, 0, 300)
	local n = 0
	local TILE = 8
	local function board(mid, along, len, offset)
		n += 1
		local p, ts = netting(f, mid, along, len, inside, offset, 0, 18, 26)
		return p, ts[1]
	end
	-- the walls run out from the gate in two bent lines of short stones: build
	-- each line in order and carry the pipes on, so they do not restart on
	-- every stone
	local gw = L:FindFirstChild("Gwanghwamun")
	local gs = gw and gw:FindFirstChild("GateStone", true)
	local gate = gs and Vector3.new(gs.Position.X, 0, gs.Position.Z) or Vector3.new(158, 0, 195)
	local lines = { {}, {} }
	for _, ext in ipairs(L:GetChildren()) do
		local stone = ext.Name == "HanokWallExtension" and ext:FindFirstChild("PalaceWallStone", true)
		if stone then
			table.insert(if stone.Position.X > gate.X and stone.Position.Z < gate.Z then lines[1] else lines[2], stone)
		end
	end
	for _, line in ipairs(lines) do
		local function d(s) return (Vector3.new(s.Position.X, 0, s.Position.Z) - gate).Magnitude end
		table.sort(line, function(a, b) return d(a) < d(b) end)
		local s, prev = 0, nil
		for _, stone in ipairs(line) do
			-- length runs along the LookVector, thickness along the RightVector
			local p, t = board(stone.Position, stone.CFrame.LookVector, stone.Size.Z + 0.4, stone.Size.X / 2 + 1.5)
			local c = Vector3.new(p.Position.X, 0, p.Position.Z)
			s = if prev then s + (c - prev).Magnitude else p.Size.X / 2
			prev = c
			-- U runs along the board's RightVector: carry the line distance of its left edge
			local away = p.CFrame.RightVector:Dot(c - gate) > 0
			local left = if away then s - p.Size.X / 2 else s + p.Size.X / 2
			t.OffsetStudsU = (if away then left else -left) % TILE
		end
	end
	if gs then
		board(gs.Position, gs.CFrame.LookVector, gs.Size.Z + 2, gs.Size.X / 2 + 3)
	end
	note("hanok netting " .. n)
end

---------------------------------------------------------------- 4. OH24 appliances
do
	local store = L:FindFirstChild("OH24Store")
	if store then
		local old = store:FindFirstChild("Microwave32")
		local spot = old and old:GetPivot().Position or (store:FindFirstChild("OhuMicrowave") and store.OhuMicrowave.Position)
		if old then old:Destroy() end
		if store:FindFirstChild("OhuMicrowave") then store.OhuMicrowave:Destroy() end
		local bar = store:FindFirstChild("WindowBar")
		local top = bar and bar.Position.Y + bar.Size.Y / 2 or 7.05
		if spot then
			local s = Vector3.new(2.6, 1.52, 1.8)
			local mw = part("OhuMicrowave", s, CFrame.new(spot.X, top + s.Y / 2, spot.Z), Color3.fromRGB(246, 246, 244), store)
			local d = Instance.new("Decal") -- the picture faces +Z, into the store
			d.Texture = "rbxassetid://126360038963034"
			d.Face = Enum.NormalId.Back
			d.Parent = mw
		end
		local hw = store:FindFirstChild("HotWater")
		if hw and hw:IsA("BasePart") then
			for _, c in ipairs(hw:GetChildren()) do c:Destroy() end
			local s = Vector3.new(1, 2.5, 1.3) -- (under the station sign)
			hw.Size = s
			hw.CFrame = CFrame.new(hw.Position.X, top + s.Y / 2, hw.Position.Z)
			hw.Color = Color3.fromRGB(196, 199, 204)
			hw.Material = Enum.Material.SmoothPlastic
			local d = Instance.new("Decal")
			d.Texture = "rbxassetid://114931690219355"
			d.Face = Enum.NormalId.Back
			d.Parent = hw
			local tap = store:FindFirstChild("HotWaterTap")
			if tap then
				tap.Size = Vector3.new(0.3, 0.35, 0.35)
				tap.CFrame = CFrame.new(hw.Position.X, top + 1.05, hw.Position.Z + s.Z / 2 + 0.17)
				tap.Color = Color3.fromRGB(60, 60, 64)
			end
			if store:FindFirstChild("HotWaterTray") then store.HotWaterTray:Destroy() end
			do
				part("HotWaterTray", Vector3.new(0.9, 0.12, 0.5), CFrame.new(hw.Position.X, top + 0.06, hw.Position.Z + s.Z / 2 + 0.25), Color3.fromRGB(40, 40, 44), store, { collide = false })
			end
		end
		note("OH24 microwave + hot water")
	end
end

---------------------------------------------------------------- 5. cafe sea skirt
do
	local cafe = G["04_Beach_Aquarium"]:FindFirstChild("BeachCafe")
	if cafe then
		for _, d in ipairs(cafe:GetChildren()) do if d.Name == "CafeSeaSkirt" then d:Destroy() end end
		local ref
		for _, d in ipairs(cafe:GetChildren()) do
			if d.Name == "CafePlinth" and d.Size.Y >= 2.9 then ref = d break end
		end
		local color = ref and ref.Color or Color3.fromRGB(236, 232, 224)
		local mat = ref and ref.Material or Enum.Material.Marble
		local BOTTOM = -5 -- under the water line (-4)
		-- west (sea) side: the floor stops at -0.4, the water starts at -4
		local x0, x1, z0, z1 = -372.8, -205.8, 194.7, 357.3
		part("CafeSeaSkirt", Vector3.new(0.6, -0.4 - BOTTOM, z1 - z0), CFrame.new(x0 + 0.3, (BOTTOM - 0.4) / 2, (z0 + z1) / 2), color, cafe, { material = mat })
		-- north and south: the plinth ends at -2.4
		for _, z in ipairs({ z0 + 0.3, z1 - 0.3 }) do
			part("CafeSeaSkirt", Vector3.new(x1 - x0, -2.4 - BOTTOM, 0.6), CFrame.new((x0 + x1) / 2, (BOTTOM - 2.4) / 2, z), color, cafe, { material = mat })
		end
		note("cafe sea skirt")
	end
end

---------------------------------------------------------------- 6. club VIP
do
	local club = G:FindFirstChild("02_Club")
	if club then
		local wings, seats = 0, 0
		local wingBoxes = {}
		for _, d in ipairs(club:GetDescendants()) do
			if d:IsA("MeshPart") and d.Name == "Sofa" and math.abs(d.Size.X - 7.2) < 0.3 and d.Position.Y > 15 then
				table.insert(wingBoxes, d.Position)
				d:Destroy()
				wings += 1
			end
		end
		for _, d in ipairs(club:GetDescendants()) do
			if d:IsA("Seat") and d.Name == "VIP_Sofa" and math.abs(d.Size.X - 2.9) < 0.2 then
				for _, w in ipairs(wingBoxes) do
					if math.abs(d.Position.X - w.X) < 4 and math.abs(d.Position.Z - w.Z) < 3 then
						if d.Occupant then d:Sit(nil) end
						d:Destroy()
						seats += 1
						break
					end
				end
			end
		end
		-- smoked glass between the booths, wall to aisle, floor to ceiling
		local f = folder(club, "VIP_Partitions")
		local FLOOR, CEIL = 20, 64
		local GLASS = Color3.fromRGB(60, 52, 78)
		local function wall(xWall, xOpen, z)
			local x0, x1 = math.min(xWall, xOpen), math.max(xWall, xOpen)
			local cx = (x0 + x1) / 2
			part("VIP_Partition", Vector3.new(x1 - x0, CEIL - FLOOR, 0.3), CFrame.new(cx, (FLOOR + CEIL) / 2, z), GLASS, f,
				{ material = Enum.Material.Glass, transparency = 0.55, shadow = false })
			-- a light strip on the open edge (user 2026-10-28 (3), D-457)
			part("VIP_PartitionLight", Vector3.new(0.2, CEIL - FLOOR, 0.4), CFrame.new(xOpen, (FLOOR + CEIL) / 2, z), Color3.fromRGB(255, 240, 250), f,
				{ material = Enum.Material.Neon, shadow = false, collide = false })
		end
		local tables = {}
		for _, d in ipairs(club:GetDescendants()) do
			if d.Name == "VIP_Table" and d:IsA("BasePart") then table.insert(tables, d.Position) end
		end
		local n = 0
		-- (wall to the table line only, user 2026-10-28 (2), D-453)
		for _, side in ipairs({ { xTable = 75.2, xWall = 66.6, xOpen = 75.2 }, { xTable = 179.3, xWall = 187.9, xOpen = 179.3 } }) do
			local zs = {}
			for _, p in ipairs(tables) do if math.abs(p.X - side.xTable) < 1 then table.insert(zs, p.Z) end end
			table.sort(zs)
			for i = 1, #zs - 1 do
				wall(side.xWall, side.xOpen, (zs[i] + zs[i + 1]) / 2)
				n += 1
			end
			-- the east row also gets one before its first booth (the user's
			-- "leftmost" zone, 2026-10-28 (3))
			if side.xWall > 100 and #zs >= 2 then
				wall(side.xWall, side.xOpen, zs[1] - (zs[2] - zs[1]) / 2)
				n += 1
			end
			-- light along the floor edge at the wall (z over the booths)
			if #zs > 0 then
				local span = if #zs >= 2 then zs[2] - zs[1] else 31.6
				local z0, z1 = zs[1] - span / 2, zs[#zs] + span / 2
				local x = side.xWall + (if side.xWall < side.xTable then 0.3 else -0.3)
				part("VIP_FloorEdgeLight", Vector3.new(0.25, 0.2, z1 - z0), CFrame.new(x, FLOOR + 0.1, (z0 + z1) / 2), Color3.fromRGB(255, 240, 250), f,
					{ material = Enum.Material.Neon, shadow = false, collide = false })
			end
		end
		-- the landing at the top of the VIP stairs (x 179.6..188, z -290..-274):
		-- light along both wall feet and up the corner you face (user 2026-10-28 (4))
		local LIGHT = Color3.fromRGB(255, 240, 250)
		part("VIP_LandingEdgeLight", Vector3.new(0.25, 0.2, 16), CFrame.new(187.7, FLOOR + 0.1, -282), LIGHT, f, { material = Enum.Material.Neon, shadow = false, collide = false })
		part("VIP_LandingEdgeLight", Vector3.new(8.4, 0.2, 0.25), CFrame.new(183.8, FLOOR + 0.1, -289.7), LIGHT, f, { material = Enum.Material.Neon, shadow = false, collide = false })
		part("VIP_LandingCornerLight", Vector3.new(0.25, CEIL - FLOOR, 0.25), CFrame.new(187.7, (FLOOR + CEIL) / 2, -289.7), LIGHT, f, { material = Enum.Material.Neon, shadow = false, collide = false })
		-- (user 2026-10-31) the wall foot from the landing to the first glass wall had
		-- no light (z -274..-244.8): the same strip, so the line runs on unbroken
		part("VIP_FloorEdgeLight", Vector3.new(0.25, 0.2, 29.2), CFrame.new(187.6, FLOOR + 0.1, -259.4), LIGHT, f, { material = Enum.Material.Neon, shadow = false, collide = false })
		note(("VIP: %d side sofas, %d seats removed, %d partitions"):format(wings, seats, n))
	end
end

---------------------------------------------------------------- 7. 오후네컷 table + benches
do
	local shop = L:FindFirstChild("OhuFourCuts")
	if shop then
		local c = Vector3.new(100, 0, -80)
		local tbl = shop:FindFirstChild("RoundTable")
		if tbl then
			-- (the layout sets the table's size since 2026-10-30: TableRadius)
			local TR = shop:GetAttribute("TableRadius") or 1.1
			tbl.Size = Vector3.new(tbl.Size.X, TR * 2, TR * 2)
			c = Vector3.new(tbl.Position.X, 0, tbl.Position.Z)
		end
		-- keep -60..60 and 120..240 degrees (was -75..75 / 105..255), measured
		-- from the bench's turn (BenchTurn, user 2026-10-30: turned 30°)
		local turn = shop:GetAttribute("BenchTurn") or 0
		local function keep(p)
			local a = math.deg(math.atan2(p.Z - c.Z, p.X - c.X)) - turn
			if a < -180 then a += 360 end
			if a < -90 then a += 360 end
			return (a > -60 and a < 60) or (a > 120 and a < 240)
		end
		local cut = 0
		for _, d in ipairs(shop:GetChildren()) do
			if (d.Name == "RingBench" or d.Name == "RingBenchSeat") and not keep(d.Position) then
				d:Destroy()
				cut += 1
			end
		end
		note("오후네컷 table r1.1, bench parts cut " .. cut)
	end
end

---------------------------------------------------------------- 8. cafe lounge sofas 1.2x, tables closer
do
	local cafe = G["04_Beach_Aquarium"]:FindFirstChild("BeachCafe")
	if cafe and not cafe:GetAttribute("LoungeSofa12") then
		local S, MOVE = 1.2, 1.2 -- sofa scale; tables move this far toward their sofa (+x)
		local sofas, tables = {}, {}
		for _, d in ipairs(cafe:GetChildren()) do
			if d:IsA("MeshPart") and d.Name == "Sofa" and d.Position.Z > 300 then table.insert(sofas, d) end
			if d:IsA("BasePart") and d.Name == "CafeTable" and d.Position.Z > 300 and d.Position.X > -332 and d.Position.Y < 14 then table.insert(tables, d) end
		end
		for _, sofa in ipairs(sofas) do
			-- the back (east) edge and the bottom stay; seats follow
			local old = sofa.Size
			local bottom = sofa.Position.Y - old.Y / 2
			local east = sofa.Position.X + old.Z / 2 -- turned 90°: depth runs along x
			-- (height and depth only: 1.2x longer sofas close the 2-stud aisles
			-- with the tier ramps between them)
			local new = Vector3.new(old.X, old.Y * S, old.Z * S)
			local c = Vector3.new(east - new.Z / 2, bottom + new.Y / 2, sofa.Position.Z)
			local oldC = sofa.Position
			sofa.Size = new
			sofa.CFrame = CFrame.new(c) * sofa.CFrame.Rotation
			for _, seat in ipairs(cafe:GetChildren()) do
				if seat:IsA("Seat") and seat.Name == "Bench" and math.abs(seat.Position.X - oldC.X) < 2 and math.abs(seat.Position.Z - oldC.Z) < 4 then
					local rel = seat.Position - oldC
					local h = seat.Position.Y - bottom
					seat.CFrame = CFrame.new(c.X + rel.X * S, bottom + h * S, c.Z + rel.Z) * seat.CFrame.Rotation
				end
			end
		end
		for _, top in ipairs(tables) do
			local t = top.Position
			for _, d in ipairs(cafe:GetChildren()) do
				if d:IsA("BasePart") and not d:IsA("Seat") and d.Name ~= "Sofa" and not d.Name:match("^Lounge")
					and math.abs(d.Position.X - t.X) < 2.6 and math.abs(d.Position.Z - t.Z) < 2.6 and d.Position.Y < t.Y + 1 and d.Position.Y > t.Y - 4.5 then
					d.CFrame += Vector3.new(MOVE, 0, 0)
				end
			end
		end
		cafe:SetAttribute("LoungeSofa12", true)
		note(("lounge: %d sofas x%.1f, %d tables +%.1f"):format(#sofas, S, #tables, MOVE))
	end
end

---------------------------------------------------------------- 9. club entrance: graffiti by the stairs, HERE on the east wall
-- (user 2026-10-28 (3)/(5), D-457/D-460) the stair corridor's east wall (x 65.5,
-- z -290..-234) gets a turned copy of the west wall's big graffiti; the foyer's
-- east wall keeps only its "HERE ←" sign (GraffitiSign), no graffiti behind it
do
	local club = G:FindFirstChild("02_Club")
	if club then
		for _, n in ipairs({ "GraffitiWallEast", "GraffitiStairEast", "HereSign" }) do
			local old = club:FindFirstChild(n)
			if old then old:Destroy() end
		end
		local big
		for _, d in ipairs(club:GetChildren()) do
			if d:IsA("BasePart") and d.Name == "GraffitiWall" and math.abs(d.Position.X - 50) < 1 and math.abs(d.Position.Z + 262) < 1 then big = d break end
		end
		if big then
			local copy = big:Clone()
			copy.Name = "GraffitiStairEast"
			local p = big.Position
			-- (only where there is wall behind it: z -274..-234; the corridor south of it is open, user 2026-10-28 (7))
			copy.Size = Vector3.new(40, big.Size.Y, big.Size.Z)
			copy.CFrame = CFrame.new(65.35, p.Y, -254) * CFrame.Angles(0, math.pi, 0) * big.CFrame.Rotation
			copy.Parent = club
		end
		-- (the HERE sign is the existing GraffitiSign decal at z -216.8)

		note("graffiti stair wall + HERE")
	end
end
return table.concat(report, "\n")