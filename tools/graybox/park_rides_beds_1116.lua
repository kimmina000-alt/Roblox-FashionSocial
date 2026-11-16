--!nocheck
-- 관람차 · 슈퍼바이킹 화단, 미니바이킹 북쪽 화단 삭제, 범퍼카장 북쪽 화단 · 나무 정리, 점핑스타 모서리 풀숲
-- (D-1513, user 2026-11-16: "미니바이킹 옆에 화단 10 스터드 옆으로 이동" (asked: delete it, the Ferris
-- wheel's bed takes its place), "관람차 10 스터드 간격 두고 화단 설치", "슈퍼바이킹도 화단 설치", "범퍼카보다
-- 북쪽에 위치한 화단과 나무 삭제", "잔디밭 … 지금 선택된 풀을 여러개 설치해서 풀숲처럼").
--   * the long bed on the mini viking's north fence (놀이공원길 Beds / Green, x -262..-215, z -525..-513) is
--     deleted;
--   * straight beds in the park style (brick curb BED_W wide, grass top, a bush every 5.2) PATH from the
--     Ferris wheel's base (north, east and south; the west wall bed is its west side) and the super viking's
--     base (north, west, and a short one between its entry and exit gates on the south; the east wall bed is
--     its east side), each run a Model in Workspace.관람차화단 / Workspace.슈퍼바이킹화단, with an opening in
--     the middle of the wheel's east and south runs; things of 놀이공원길 on the new paths and beds are set
--     aside in ServerStorage.ParkMoveRemoved_1116 (lamps and benches move out past the bed);
--   * north of the bumper hall (z < NORTH_Z) the beds' bushes, short beds and the trees of 놀이공원길 are set
--     aside; the two long wall beds end at NORTH_Z;
--   * the jumping star's south-west corner (between the west and south walls and the star's beds): bushes
--     like the beds' one (ArtAssets.Shrub at the beds' scale), close together, in Workspace.점핑스타풀숲.
-- Run after park_bumper_big_1116. Idempotent (the models are rebuilt; deleted pieces are not found again).

local SS = game:GetService("ServerStorage")
local G = 16.06
local GRASS = Color3.fromRGB(88, 146, 64)
local BRICK = Color3.fromRGB(156, 84, 64)
local BED_W = 6.5
local CURB = 0.9
local SOIL_H = CURB + 0.12
local PATH = 10
local HEDGE_STEP = 5.2
local HEDGE_SCALE = 0.7
local NORTH_Z = -766 -- (the bumper hall's north eave, z -760 - 5.2)

local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local function bb(m: Instance, visible: boolean?): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	local list = if m:IsA("BasePart") then { m } else m:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") and (not visible or p.Transparency < 1) then
			local a, b = ext(p)
			lo, hi = lo:Min(a), hi:Max(b)
		end
	end
	return lo, hi
end

local paths = workspace:FindFirstChild("놀이공원길")
local wheel = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("06_Park_Playground")
wheel = wheel and wheel:FindFirstChild("관 람 차 ")
local viking = workspace:FindFirstChild("슈퍼바이킹")
assert(paths and wheel and viking, "no 놀이공원길 / 관람차 / 슈퍼바이킹")
local keep = SS:FindFirstChild("ParkMoveRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkMoveRemoved_1116"
keep.Parent = SS
local function aside(c: Instance)
	c:SetAttribute("FromPath", c.Parent:GetFullName())
	c.Parent = keep
end
local done = {}

---------------------------------------------------------------- 1. the bed on the mini viking's north fence
do
	local n = 0
	for _, f in ipairs({ paths:FindFirstChild("Beds"), paths:FindFirstChild("Green") }) do
		for _, c in ipairs(f and f:GetChildren() or {}) do
			if c:IsA("BasePart") and (c.Name:find("^Bed") or c.Name == "Hedge") then
				local l, h = ext(c)
				if l.X > -263 and h.X < -214 and l.Z > -525.5 and h.Z < -512.5 then
					c:Destroy()
					n += 1
				end
			end
		end
	end
	table.insert(done, ("mini viking bed %d pieces"):format(n))
end

---------------------------------------------------------------- the bushes' template
local leafT
for _, d in ipairs(SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("Shrub") and SS.ArtAssets.Shrub:GetDescendants() or {}) do
	if d:IsA("MeshPart") and (not leafT or d.Size.Magnitude > leafT.Size.Magnitude) then leafT = d end
end
assert(leafT, "no ArtAssets.Shrub")

---------------------------------------------------------------- 2. straight beds round the two rides
local rng = Random.new(1513)
local function clearZone(lo: Vector3, hi: Vector3, outward: Vector3)
	-- things of 놀이공원길 in the box set aside; lamps / benches / bins moved out along `outward`
	for _, folder in ipairs(paths:GetChildren()) do
		if folder.Name ~= "Ground" then
			for _, c in ipairs(folder:GetChildren()) do
				local l, h = bb(c)
				if h.X - l.X < 60 and h.Z - l.Z < 60 and l.X < hi.X and h.X > lo.X and l.Z < hi.Z and h.Z > lo.Z then
					if folder.Name == "Furniture" and c:IsA("Model") then
						local d = outward * (if outward.X ~= 0 then (if outward.X > 0 then hi.X - l.X else lo.X - h.X) else (if outward.Z > 0 then hi.Z - l.Z else lo.Z - h.Z))
						d = d + outward * 1.5
						c:PivotTo(c:GetPivot() + d)
					else
						aside(c)
					end
				end
			end
		end
	end
end
local function bed(parent: Instance, name: string, a: Vector3, b: Vector3)
	-- a straight bed from a to b (its middle line, y ignored)
	local m = Instance.new("Model")
	m.Name = name
	local u = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local L = u.Magnitude
	u = u.Unit
	local mid = Vector3.new((a.X + b.X) / 2, 0, (a.Z + b.Z) / 2)
	local cf = CFrame.lookAt(mid, mid + u)
	local function part(n: string, size: Vector3, c: CFrame, color: Color3, mat: Enum.Material, collide: boolean)
		local p = Instance.new("Part")
		p.Name = n
		p.Size, p.CFrame, p.Color, p.Material = size, c, color, mat
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, collide, false, collide, collide
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local curbH = CURB + 0.3
	local curb = part("BedCurb", Vector3.new(BED_W, curbH, L), cf + Vector3.new(0, G + CURB - curbH / 2, 0), BRICK, Enum.Material.Brick, true)
	part("BedGrass", Vector3.new(BED_W - 0.7, 0.3, L - 0.7), cf + Vector3.new(0, G + CURB + 0.12 - 0.15, 0), GRASS, Enum.Material.Grass, false)
	local s = HEDGE_STEP / 2
	while s < L do
		local at = a + u * s
		local h = leafT:Clone()
		h.Name = "Hedge"
		h.Size = leafT.Size * HEDGE_SCALE * rng:NextNumber(0.9, 1.08)
		h.CFrame = CFrame.new(at.X + rng:NextNumber(-0.4, 0.4), G + SOIL_H + h.Size.Y / 2 - 0.7, at.Z + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
		h.Anchored, h.CanCollide, h.CanTouch, h.CanQuery = true, false, false, false
		h.Parent = m
		s += HEDGE_STEP
	end
	m.PrimaryPart = curb
	m.Parent = parent
end
local function folder(name: string): Folder
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end
local OFF = PATH + BED_W / 2 -- (a bed's middle line from the ride's base)
local function base(r: Instance): (Vector3, Vector3)
	-- the ride's foot: its visible parts below 2 over the paving
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in ipairs(r:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local a, b = ext(p)
			if a.Y < G + 2 then lo, hi = lo:Min(a), hi:Max(b) end
		end
	end
	return lo, hi
end

-- the Ferris wheel: north, east (open in the middle), south (open in the middle)
do
	local lo, hi = base(wheel)
	local f = folder("관람차화단")
	local xW = -259 -- (the west wall bed's inner face)
	local zN, zS, xE = lo.Z - OFF, hi.Z + OFF, hi.X + OFF
	local cz, cx = (lo.Z + hi.Z) / 2, (lo.X + hi.X) / 2
	local OPEN = 14
	local runs = {
		{ "WheelBedNorth", Vector3.new(xW + 0.2, 0, zN), Vector3.new(xE + BED_W / 2, 0, zN), Vector3.new(0, 0, -1) },
		{ "WheelBedEastN", Vector3.new(xE, 0, zN + BED_W / 2), Vector3.new(xE, 0, cz - OPEN / 2), Vector3.new(1, 0, 0) },
		{ "WheelBedEastS", Vector3.new(xE, 0, cz + OPEN / 2), Vector3.new(xE, 0, zS - BED_W / 2), Vector3.new(1, 0, 0) },
		{ "WheelBedSouthW", Vector3.new(xW + 0.2, 0, zS), Vector3.new(cx - OPEN / 2, 0, zS), Vector3.new(0, 0, 1) },
		{ "WheelBedSouthE", Vector3.new(cx + OPEN / 2, 0, zS), Vector3.new(xE + BED_W / 2, 0, zS), Vector3.new(0, 0, 1) },
	}
	-- the path ring and the beds cleared first
	-- (from x -256.5: the west wall bed's bushes, reaching to -257.4, stay)
	clearZone(Vector3.new(-256.5, 0, zN - BED_W / 2), Vector3.new(xE + BED_W / 2, 0, lo.Z), Vector3.new(0, 0, -1))
	clearZone(Vector3.new(-256.5, 0, hi.Z), Vector3.new(xE + BED_W / 2, 0, zS + BED_W / 2), Vector3.new(0, 0, 1))
	clearZone(Vector3.new(hi.X, 0, lo.Z), Vector3.new(xE + BED_W / 2, 0, hi.Z), Vector3.new(1, 0, 0))
	for _, r in ipairs(runs) do bed(f, r[1], r[2], r[3]) end
	table.insert(done, ("wheel base x %.1f..%.1f z %.1f..%.1f, %d runs"):format(lo.X, hi.X, lo.Z, hi.Z, #runs))
end

-- the super viking: north, west, and between the gates on the south
do
	local lo, hi = base(viking)
	local f = folder("슈퍼바이킹화단")
	local xE = -60 -- (the east wall bed's inner face, -59, less a little)
	local zN, zS, xW = lo.Z - OFF, hi.Z + OFF, lo.X - OFF
	local gates = viking:FindFirstChild("Gates")
	local entX, exitX = -121.4, -73.8
	if gates and gates:FindFirstChild("Entrance") then entX = (select(1, bb(gates.Entrance)).X + select(2, bb(gates.Entrance)).X) / 2 end
	if gates and gates:FindFirstChild("Exit") then exitX = (select(1, bb(gates.Exit)).X + select(2, bb(gates.Exit)).X) / 2 end
	local runs = {
		{ "VikingBedNorth", Vector3.new(xW - BED_W / 2, 0, zN), Vector3.new(xE, 0, zN), Vector3.new(0, 0, -1) },
		{ "VikingBedWest", Vector3.new(xW, 0, zN + BED_W / 2), Vector3.new(xW, 0, zS + BED_W / 2), Vector3.new(-1, 0, 0) },
		{ "VikingBedSouth", Vector3.new(entX + 10, 0, zS), Vector3.new(exitX - 10, 0, zS), Vector3.new(0, 0, 1) },
	}
	-- (to x -62.5: the east wall bed's bushes, from -61.7, stay)
	clearZone(Vector3.new(xW - BED_W / 2, 0, zN - BED_W / 2), Vector3.new(-62.5, 0, lo.Z), Vector3.new(0, 0, -1))
	clearZone(Vector3.new(xW - BED_W / 2, 0, lo.Z), Vector3.new(lo.X, 0, zS + BED_W / 2), Vector3.new(-1, 0, 0))
	clearZone(Vector3.new(entX + 6, 0, hi.Z), Vector3.new(exitX - 6, 0, zS + BED_W / 2), Vector3.new(0, 0, 1))
	for _, r in ipairs(runs) do bed(f, r[1], r[2], r[3]) end
	table.insert(done, ("viking base x %.1f..%.1f z %.1f..%.1f"):format(lo.X, hi.X, lo.Z, hi.Z))
end

---------------------------------------------------------------- 3. north of the bumper hall
do
	local n, cut = 0, 0
	for _, fname in ipairs({ "Beds", "Green" }) do
		local f = paths:FindFirstChild(fname)
		for _, c in ipairs(f and f:GetChildren() or {}) do
			local l, h = bb(c)
			if h.Z - l.Z > 200 and l.Z < NORTH_Z and h.Z > NORTH_Z and c:IsA("BasePart") then
				-- a long wall bed: it ends at NORTH_Z
				c.Size = Vector3.new(c.Size.X, c.Size.Y, h.Z - NORTH_Z)
				c.CFrame = CFrame.new(c.Position.X, c.Position.Y, (NORTH_Z + h.Z) / 2)
				cut += 1
			elseif (l.Z + h.Z) / 2 < NORTH_Z and not c.Name:find("^Lawn") then
				aside(c)
				n += 1
			end
		end
	end
	table.insert(done, ("north: %d set aside, %d long beds cut"):format(n, cut))
end

---------------------------------------------------------------- 4. the jumping star's corner thicket
do
	local star = workspace:FindFirstChild("점핑스타")
	local f = folder("점핑스타풀숲")
	if star and star:FindFirstChild("Ride") then
		local c3 = star.Ride:GetPivot().Position
		local C = Vector3.new(c3.X, 0, c3.Z)
		local R_OUT = 9.8 + PATH + 5.5 + 1.2 -- (the star's beds' outer edge + a little)
		local X_W, Z_S, Z_N = -260.4, -339.6, -379.6 -- (the west wall's bed side, the south wall, the 화단3칸 row)
		local STEP = 3.6
		local count = 0
		for x = X_W + 1.5, C.X, STEP do
			for z = Z_N + 1.5, Z_S - 1.5, STEP do
				local px, pz = x + rng:NextNumber(-1.1, 1.1), z + rng:NextNumber(-1.1, 1.1)
				if (Vector3.new(px, 0, pz) - C).Magnitude > R_OUT and px > X_W + 1 and pz < Z_S - 1 then
					local h = leafT:Clone()
					h.Name = "Bush"
					h.Size = leafT.Size * HEDGE_SCALE * rng:NextNumber(0.85, 1.2)
					h.CFrame = CFrame.new(px, G + h.Size.Y / 2 - 0.9, pz) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
					h.Anchored, h.CanCollide, h.CanTouch, h.CanQuery = true, false, false, false
					h.Parent = f
					count += 1
				end
			end
		end
		table.insert(done, ("thicket %d bushes"):format(count))
	end
end

print("[park_rides_beds_1116] " .. table.concat(done, "; "))
return table.concat(done, "; ")
