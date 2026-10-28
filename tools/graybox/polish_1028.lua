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

---------------------------------------------------------------- 2. park hoarding
do
	local gate = L:FindFirstChild("AmusementParkGate")
	if gate then
		local f = folder(gate, "ParkHoarding")
		local ID = "rbxassetid://103972831630543" -- hoarding_park.png (1024 x 512)
		local NAVY = Color3.fromRGB(28, 42, 78)
		local Y0, H = 2.4, 28 -- wall foot, height (two picture rows of 14)
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
			local a, b = Vector3.new(r[1], Y0 + H / 2, r[2]), Vector3.new(r[3], Y0 + H / 2, r[4])
			local mid = (a + b) / 2
			local len = (b - a).Magnitude + 0.4
			local along = (b - a).Unit
			local normal = Vector3.new(-along.Z, 0, along.X)
			if (inside - mid):Dot(normal) < 0 then normal = -normal end
			-- LookVector = into the park: Back = the street side
			local p = part("ParkHoarding", Vector3.new(len, H, 0.4), CFrame.lookAt(mid, mid + normal), NAVY, f, { shadow = false })
			texture(p, Enum.NormalId.Back, ID, H, H / 2)
			texture(p, Enum.NormalId.Front, ID, H, H / 2)
		end
		note("park hoarding " .. #runs)
	end
end

---------------------------------------------------------------- 3. hanok hoarding
do
	local f = folder(L, "HanokHoarding")
	local ID = "rbxassetid://83802572583834" -- hoarding_hanok.png (2048 x 512)
	local WHITE = Color3.fromRGB(238, 240, 241)
	local H = 24
	local inside = Vector3.new(300, 0, 300)
	local n = 0
	local TILE = H * 2 -- two rows of 12: the top row is the part seen over the 12-stud wall
	local function board(mid, along, len, offset)
		local normal = Vector3.new(-along.Z, 0, along.X)
		if (inside - mid):Dot(normal) < 0 then normal = -normal end
		local c = Vector3.new(mid.X, H / 2, mid.Z) + normal * offset
		local p = part("HanokHoarding", Vector3.new(len, H, 0.4), CFrame.lookAt(c, c + normal), WHITE, f, { shadow = false })
		n += 1
		return p, texture(p, Enum.NormalId.Back, ID, TILE, H / 2)
	end
	-- the walls run out from the gate in two bent lines of short stones: build
	-- each line in order and carry the picture on, so the slogan does not
	-- restart on every stone
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
	note("hanok hoarding " .. n)
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
			-- a slim dark post on the open edge
			part("VIP_PartitionPost", Vector3.new(0.3, CEIL - FLOOR, 0.5), CFrame.new(xOpen, (FLOOR + CEIL) / 2, z), Color3.fromRGB(24, 22, 28), f,
				{ material = Enum.Material.Metal, shadow = false })
		end
		local tables = {}
		for _, d in ipairs(club:GetDescendants()) do
			if d.Name == "VIP_Table" and d:IsA("BasePart") then table.insert(tables, d.Position) end
		end
		local n = 0
		for _, side in ipairs({ { xTable = 75.2, xWall = 66.6, xOpen = 80.5 }, { xTable = 179.3, xWall = 187.9, xOpen = 174.0 } }) do
			local zs = {}
			for _, p in ipairs(tables) do if math.abs(p.X - side.xTable) < 1 then table.insert(zs, p.Z) end end
			table.sort(zs)
			for i = 1, #zs - 1 do
				wall(side.xWall, side.xOpen, (zs[i] + zs[i + 1]) / 2)
				n += 1
			end
		end
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
			local TR = 1.1 -- the pot is ~1 stud wide
			tbl.Size = Vector3.new(tbl.Size.X, TR * 2, TR * 2)
			c = Vector3.new(tbl.Position.X, 0, tbl.Position.Z)
		end
		-- keep -60..60 and 120..240 degrees (was -75..75 / 105..255)
		local function keep(p)
			local a = math.deg(math.atan2(p.Z - c.Z, p.X - c.X))
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

return table.concat(report, "\n")
