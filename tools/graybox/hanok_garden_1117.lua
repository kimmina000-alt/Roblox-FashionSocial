-- 한옥 연못 정원 (D-1741, D-1742): 한옥 마을 남동쪽 필지(담 x 227..353, z 454..648)의 블록 집을
-- 유리 미닫이 한옥 + 연못 정원 + 차 마시는 정자로 (사용자 사진 docs/04_ART/references/hanok_garden_01.webp).
-- Studio Edit 모드, hanok_wall_kit.lua 를 먼저 실행(_G.HanokWallKit). 여러 번 돌려도 결과가 같다.
-- 체인 스크립트가 건드리지 않는 Workspace 최상위(HanokGarden), 지형(필지 안 연못 물)과 사용자 부품(블록 · 북쪽 담)만 바꾼다: 장소 저장 필요.
--   블록 Part(315, 504) → ServerStorage.ParkedHanokBlocks 로(지붕 HanokRoof_4 는 그대로).
--   북쪽 담(z 454)에 대문 자리(x 238..250)를 냄: 원래 담은 ServerStorage.ParkedHanokBlocks.NorthWall_1117 에 보관.
-- 에셋(AI generate_mesh, place 전용): ServerStorage.ArtAssets.HanokGardenAssets.{Persimmon, RockB, RockC, Fern, Flagstone, LotusFlat, LotusTall, TeaKyusu, TeaPitcher, TeaCup}
--   LotusFlat / LotusTall 은 SurfaceAppearance(ColorMap = 메시 텍스처, Color 176,200,160)로 사진처럼 차분한 초록.
-- 마당 높이 GY 1.0: 포장(CSG, 연못 구멍) + 투명 걷는 바닥(연못 안쪽만 비움), 수면 약 0.9 = Terrain Water(지형 칸에 직접 씀).
local K = _G.HanokWallKit
assert(K, "run tools/graybox/hanok_wall_kit.lua first")
local box = K.box
local SS = game:GetService("ServerStorage")
local park = SS:FindFirstChild("ParkedHanokBlocks") or Instance.new("Folder")
park.Name = "ParkedHanokBlocks"
park.Parent = SS
local block = park:FindFirstChild("Part_315_504")
if not block then
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Part" and (p.Position - Vector3.new(315, 16.1, 503.8)).Magnitude < 2 then block = p end
	end
	assert(block, "house block (315, 504) not found")
	block.Name = "Part_315_504"
	block.Parent = park
end
local bcf, bs = block.CFrame, block.Size
local hx = math.abs(bcf.RightVector.X) > 0.5
local SX, SZ = hx and bs.X or bs.Z, hx and bs.Z or bs.X
local X0, X1 = bcf.X - SX / 2, bcf.X + SX / 2
local Z0, Z1 = bcf.Z - SZ / 2, bcf.Z + SZ / 2
local TOP = bcf.Y + bs.Y / 2
local GY = 1.0 -- 마당 포장 윗면 (연못은 이 아래로 파임)
local WY = 0.85 -- 연잎을 띄우는 수면 높이
local P1 = { { 266, 473, 11 }, { 280, 479, 9 }, { 271, 486, 7.5 } }
local P2 = { { 266, 567, 12 }, { 284, 571, 11 }, { 302, 566, 10 }, { 318, 572, 8.5 } }
local DISCS = {}
for _, c in ipairs(P1) do table.insert(DISCS, c) end
for _, c in ipairs(P2) do table.insert(DISCS, c) end
local function inPond(x, z, pad)
	for _, c in ipairs(DISCS) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < (c[3] + pad) ^ 2 then return true end
	end
	return false
end
local old = workspace:FindFirstChild("HanokGarden")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "HanokGarden"
local function folder(name)
	local f = Instance.new("Model") f.Name = name f.Parent = root return f
end
local function mat(p, material, color) p.Material = material p.Color = color return p end
local STONE = Color3.fromRGB(222, 218, 210) -- 벽 아래 돌 사진(OHU_HanokPlinth) 위에 곱하는 색 (D-1744)
local function stone(m, name, x0, x1, y0, y1, z0, z1)
	local p = box(m, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), "stone")
	p.Color = STONE
	return p
end
local function wood(m, name, x0, x1, y0, y1, z0, z1, h)
	return box(m, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), h and "woodH" or "woodV")
end
-- 사람이 오르는 투명 경사로 (계단 위)
local function ramp(m, cx, cz, width, len, height, upDir)
	local w = Instance.new("WedgePart")
	w.Name = "Ramp" w.Anchored = true w.Transparency = 1 w.CastShadow = false
	w.Size = Vector3.new(width, height, len)
	local pos = Vector3.new(cx, height / 2, cz)
	w.CFrame = CFrame.lookAt(pos, pos - upDir)
	w.Parent = m
	return w
end

-- 기단 (높이 3) + 계단
local FY = 3
local base = folder("Platform")
stone(base, "Gidan", X0 - 4, X1 + 4, 0, FY, Z0 - 4, Z1 + 4)
local zc = (Z0 + Z1) / 2
stone(base, "StepW1", X0 - 7.4, X0 - 4, 0, 1.67, zc - 15, zc + 15)
stone(base, "StepW2", X0 - 5.7, X0 - 4, 0, 2.33, zc - 15, zc + 15)
ramp(base, X0 - 5.7, zc, 30, 3.4, FY, Vector3.new(1, 0, 0))
local sx = X0 + 8
stone(base, "StepS1", sx - 9, sx + 9, 0, 1.67, Z1 + 4, Z1 + 7.4)
stone(base, "StepS2", sx - 9, sx + 9, 0, 2.33, Z1 + 4, Z1 + 5.7)
ramp(base, sx, Z1 + 5.7, 18, 3.4, FY, Vector3.new(0, 0, -1))

-- 집 벽 (벽 키트): 서쪽 연못 · 남쪽 정자 쪽은 유리 미닫이(일부 반 열림), 북 · 동은 회벽 + 창
local house = folder("House")
local H = TOP - FY
local function v(x, z) return Vector3.new(x, FY, z) end
local G, GO = "GlassSlide", { "GlassSlide", open = true }
K.face(house, v(X0, Z0), v(X1, Z0), Vector3.new(0, 0, -1), { "WallWindow", "Wall" }, H)
K.face(house, v(X1, Z0), v(X1, Z1), Vector3.new(1, 0, 0), { "Wall", "WallWindow", "WallWindow", "Wall" }, H)
K.face(house, v(X1, Z1), v(X0, Z1), Vector3.new(0, 0, 1), { G, GO }, H)
K.face(house, v(X0, Z1), v(X0, Z0), Vector3.new(-1, 0, 0), { G, GO, GO, G }, H)

-- 실내: 나무 바닥 · 천장 · 대들보, 한지 등, 책장, 소파, 식탁
local inn = folder("Interior")
local fl = wood(inn, "Floor", X0, X1, FY, FY + 0.2, Z0, Z1, true)
fl.Color = Color3.fromRGB(250, 222, 180)
wood(inn, "Ceiling", X0, X1, TOP - 0.6, TOP, Z0, Z1, true)
for _, z in ipairs({ Z0 + SZ / 3, Z0 + SZ * 2 / 3 }) do
	wood(inn, "Daedulbo", X0, X1, TOP - 2.6, TOP - 0.6, z - 0.9, z + 0.9, true)
end
local function lamp(x, z)
	local l = box(inn, "PaperLamp", Vector3.new(7, 0.6, 11), Vector3.new(x, TOP - 7, z), "paper", { collide = false, shadow = false })
	l.Material = Enum.Material.Neon l.Color = Color3.fromRGB(255, 238, 205) l.Transparency = 0.15
	local fr = wood(inn, "LampFrame", x - 3.7, x + 3.7, TOP - 6.6, TOP - 6.2, z - 5.7, z + 5.7, true)
	fr.CanCollide = false
	for _, d in ipairs({ { -3, -5 }, { 3, -5 }, { -3, 5 }, { 3, 5 } }) do
		local r = box(inn, "LampRod", Vector3.new(0.08, 6.4, 0.08), Vector3.new(x + d[1], TOP - 3.4, z + d[2]), "iron", { collide = false, shadow = false })
		r.CanQuery = false
	end
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 214, 160) pl.Range = 26 pl.Brightness = 1.2 pl.Shadows = true pl.Parent = l
end
lamp((X0 + X1) / 2, Z0 + SZ * 0.3)
lamp((X0 + X1) / 2, Z0 + SZ * 0.72)
local shelf = Instance.new("Model") shelf.Name = "Bookshelf" shelf.Parent = inn
local bz0, bz1, by1 = Z0 + 8, Z0 + 38, FY + 21
wood(shelf, "Back", X1 - 0.5, X1, FY, by1, bz0, bz1, true)
wood(shelf, "SideA", X1 - 3.2, X1, FY, by1, bz0, bz0 + 0.5)
wood(shelf, "SideB", X1 - 3.2, X1, FY, by1, bz1 - 0.5, bz1)
local shelfRows = 5
local rh = (by1 - FY - 0.5) / shelfRows
for i = 0, shelfRows do
	local y = FY + i * rh
	wood(shelf, "Board" .. i, X1 - 3.2, X1 - 0.5, y, y + 0.5, bz0 + 0.5, bz1 - 0.5, true)
	if i < shelfRows then
		local b = box(shelf, "Books" .. i, Vector3.new(2.2, rh - 0.9, bz1 - bz0 - 1.2), Vector3.new(X1 - 1.7, y + 0.5 + (rh - 0.9) / 2, (bz0 + bz1) / 2), "paper", { collide = false, shadow = false })
		b.Color = Color3.fromRGB(60, 44, 30)
		local t = Instance.new("Texture")
		t.Texture = "rbxassetid://73840800237202" t.Face = Enum.NormalId.Left
		t.StudsPerTileU = 16 t.StudsPerTileV = rh - 0.9 t.OffsetStudsU = i * 5.3 t.Parent = b
	end
end
local sofaX, sofaZ = X0 + 15, Z0 + 14
local FAB = Color3.fromRGB(236, 232, 224)
local function fabric(name, x0, x1, y0, y1, z0, z1)
	local p = box(inn, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), nil)
	return mat(p, Enum.Material.Fabric, FAB)
end
fabric("SofaSeat", sofaX, sofaX + 4.5, FY + 0.2, FY + 2.3, sofaZ - 7, sofaZ + 7)
fabric("SofaBack", sofaX + 4.5, sofaX + 6, FY + 0.2, FY + 5, sofaZ - 7, sofaZ + 7)
fabric("SofaArmA", sofaX, sofaX + 6, FY + 0.2, FY + 3.4, sofaZ - 8.2, sofaZ - 7)
fabric("SofaArmB", sofaX, sofaX + 6, FY + 0.2, FY + 3.4, sofaZ + 7, sofaZ + 8.2)
local rug = box(inn, "Rug", Vector3.new(14, 0.08, 18), Vector3.new(sofaX - 3, FY + 0.24, sofaZ), nil, { collide = false, shadow = false })
mat(rug, Enum.Material.Fabric, Color3.fromRGB(214, 204, 186))
wood(inn, "LowTableTop", sofaX - 7, sofaX - 2.5, FY + 1.6, FY + 2, sofaZ - 4, sofaZ + 4, true)
wood(inn, "LowTableBase", sofaX - 6.4, sofaX - 3.1, FY + 0.2, FY + 1.6, sofaZ - 3.2, sofaZ + 3.2)
local tx, tz = (X0 + X1) / 2 + 1, Z1 - 15
wood(inn, "TableTop", tx - 6, tx + 6, FY + 3.9, FY + 4.3, tz - 3, tz + 3, true)
for _, d in ipairs({ { -5.4, -2.4 }, { 5.4, -2.4 }, { -5.4, 2.4 }, { 5.4, 2.4 } }) do
	wood(inn, "TableLeg", tx + d[1] - 0.25, tx + d[1] + 0.25, FY + 0.2, FY + 3.9, tz + d[2] - 0.25, tz + d[2] + 0.25)
end
local DARK = Color3.fromRGB(150, 100, 64)
for _, c in ipairs({ { -3, -1 }, { 3, -1 }, { -3, 1 }, { 3, 1 } }) do
	local cx, side = tx + c[1], c[2]
	local cz = tz + side * 4.6
	wood(inn, "ChairSeat", cx - 1.3, cx + 1.3, FY + 2.3, FY + 2.6, cz - 1.3, cz + 1.3, true).Color = DARK
	wood(inn, "ChairBack", cx - 1.3, cx + 1.3, FY + 2.6, FY + 5.4, cz + side * 1.1 - 0.15, cz + side * 1.1 + 0.15, true).Color = DARK
	for _, dx in ipairs({ -0.95, 0.95 }) do
		wood(inn, "ChairLegs", cx + dx - 0.18, cx + dx + 0.18, FY + 0.2, FY + 2.3, cz - 1.1, cz + 1.1).Color = DARK
	end
end

-- 마당 바닥: 납작 돌 포장(높이 GY, 연못 자리는 CSG로 뚫음) + 투명 걷는 바닥 + 화단
local gd = folder("Ground")
local LX0, LX1, LZ0, LZ1 = 228, 352, 455, 647
local pave0 = box(gd, "Paving", Vector3.new(LX1 - LX0, GY, LZ1 - LZ0), Vector3.new((LX0 + LX1) / 2, GY / 2, (LZ0 + LZ1) / 2), nil, { shadow = false })
local holes = {}
for _, c in ipairs(DISCS) do
	local h = Instance.new("Part")
	h.Shape = Enum.PartType.Cylinder
	h.Size = Vector3.new(3, 2 * c[3], 2 * c[3])
	h.CFrame = CFrame.new(c[1], GY / 2, c[2]) * CFrame.Angles(0, 0, math.pi / 2)
	h.Anchored = true
	h.Parent = workspace
	table.insert(holes, h)
end
pave0.Parent = workspace -- CSG 는 DataModel 안에서만
local pave = pave0:SubtractAsync(holes)
for _, h in ipairs(holes) do h:Destroy() end
pave.Name = "Paving"
pave.UsePartColor = true
pave.Anchored = true
pave.CanCollide = false -- CSG 충돌은 구멍까지 메움: 아래 WalkFloor 로 대신
pave.CastShadow = false
pave.Parent = gd
pave0:Destroy()
mat(pave, Enum.Material.Slate, Color3.fromRGB(200, 200, 200))
pave.MaterialVariant = "OHU_HanokYard" -- 사용자 바닥 돌 사진 (D-1744; D-1743 의 아스팔트 대신)
-- 걷는 바닥(투명): 2스터드 칸, 연못 안쪽(가장자리 1 안)만 비움, 같은 모양 줄끼리 합침
local rows = {}
for z = LZ0, LZ1 - 2, 2 do
	local runs, x0 = {}, nil
	for x = LX0, LX1, 2 do
		local solid = x < LX1 and not inPond(x + 1, z + 1, -1)
		if solid and not x0 then x0 = x elseif not solid and x0 then table.insert(runs, { x0, x }) x0 = nil end
	end
	local keys = {}
	for _, r in ipairs(runs) do table.insert(keys, r[1] .. ":" .. r[2]) end
	table.insert(rows, { z = z, key = table.concat(keys, ","), runs = runs })
end
local ri = 1
while ri <= #rows do
	local rj = ri
	while rj + 1 <= #rows and rows[rj + 1].key == rows[ri].key do rj += 1 end
	for _, r in ipairs(rows[ri].runs) do
		local c = box(gd, "WalkFloor", Vector3.new(r[2] - r[1], GY, (rj - ri + 1) * 2), Vector3.new((r[1] + r[2]) / 2, GY / 2, rows[ri].z + (rj - ri + 1)), nil, { shadow = false })
		c.Transparency = 1
	end
	ri = rj + 1
end
local GRASS = Color3.fromRGB(86, 112, 58)
local function bed(name, x0, x1, z0, z1)
	local e = box(gd, name .. "Edge", Vector3.new(x1 - x0 + 0.8, GY + 0.35, z1 - z0 + 0.8), Vector3.new((x0 + x1) / 2, (GY + 0.35) / 2, (z0 + z1) / 2), nil, { shadow = false })
	mat(e, Enum.Material.Granite, Color3.fromRGB(176, 170, 158))
	local b = box(gd, name, Vector3.new(x1 - x0, GY + 0.42, z1 - z0), Vector3.new((x0 + x1) / 2, (GY + 0.42) / 2, (z0 + z1) / 2), nil, { shadow = false })
	return mat(b, Enum.Material.Grass, GRASS)
end
bed("BedWest", LX0, 236, 470, 598)
bed("BedEast", 337, LX1, LZ0, 548)
bed("BedSouthEast", 326, LX1, 560, LZ1)
bed("BedBack", LX0, 326, 630, LZ1)

-- 연못: 실제 물(Terrain Water) + 어두운 바닥, 연잎(AI 메시), 돌판 다리
local pond = folder("Ponds")
local T = workspace.Terrain
T:FillBlock(CFrame.new((LX0 + LX1) / 2, 0, (LZ0 + LZ1) / 2), Vector3.new(LX1 - LX0, 8, LZ1 - LZ0), Enum.Material.Air)
for _, c in ipairs(DISCS) do
	local bedp = box(pond, "PondBed", Vector3.new(0.1, 2 * c[3] + 0.4, 2 * c[3] + 0.4), Vector3.new(c[1], 0.05, c[2]), nil, { collide = false, shadow = false })
	bedp.Shape = Enum.PartType.Cylinder
	bedp.CFrame = CFrame.new(c[1], 0.05, c[2]) * CFrame.Angles(0, 0, math.pi / 2)
	mat(bedp, Enum.Material.SmoothPlastic, Color3.fromRGB(8, 12, 8))
end
-- 지형 칸(4스터드)에 직접 씀: 아래 칸(-4..0) 물 가득, 위 칸(0..4) 채움 0.24 = 수면 약 0.9 (포장 1.0 아래).
-- (FillCylinder 로 얇게 채우면 칸보다 얇아서 물이 안 생김.) 포장 밑으로 1.5 더 넓게: 구멍 가장자리까지 물.
do
	local reg = Region3.new(Vector3.new(LX0, -4, LZ0 - 3), Vector3.new(LX1 + 4, 4, LZ1)):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(reg, 4)
	local s = mats.Size
	local ox, oz = reg.CFrame.X - reg.Size.X / 2, reg.CFrame.Z - reg.Size.Z / 2
	for i = 1, s.X do
		for k = 1, s.Z do
			if inPond(ox + (i - 0.5) * 4, oz + (k - 0.5) * 4, 1.5) then
				mats[i][1][k], occ[i][1][k] = Enum.Material.Water, 1
				mats[i][2][k], occ[i][2][k] = Enum.Material.Water, 0.24
			end
		end
	end
	T:WriteVoxels(reg, 4, mats, occ)
end
local rng = Random.new(1741)
local assets = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("HanokGardenAssets")
-- 연잎: 물 위에 뜬 잎(LotusFlat) + 줄기로 솟은 잎(LotusTall, 약 1/5)
local function lotus(list, n)
	for _ = 1, n do
		local c = list[rng:NextInteger(1, #list)]
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, c[3] - 1.6)
		local x, z = c[1] + math.cos(a) * d, c[2] + math.sin(a) * d
		local tall = rng:NextNumber() < 0.22
		local src = assets and assets:FindFirstChild(tall and "LotusTall" or "LotusFlat")
		if src then
			local m = src:Clone()
			m:ScaleTo(m:GetScale() * (tall and rng:NextNumber(0.75, 1.15) or rng:NextNumber(0.55, 1.15)))
			m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(0, 6.28), rng:NextNumber(-0.05, 0.05)))
			local cf, s = m:GetBoundingBox()
			local y = tall and (0.1 + s.Y / 2) or (WY + 0.06)
			m:PivotTo(m:GetPivot() + (Vector3.new(x, y, z) - cf.Position))
			m.Parent = pond
		end
	end
end
lotus(P1, 22)
lotus(P2, 34)
local bx = sx
stone(pond, "SlabBridge", bx - 5, bx + 5, 0, GY + 0.5, 553, 590)
stone(pond, "SlabBridgeShadow", bx - 5.6, bx + 5.6, 0, WY - 0.1, 553.5, 589.5).Color = Color3.fromRGB(120, 116, 106)

-- 바위 · 풀숲 · 감나무 · 관목
local deco = folder("Plants")
local function place(name, pos, scale, yaw)
	local src = assets and assets:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw, 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (pos + Vector3.new(0, s.Y / 2, 0) - cf.Position))
	if name:sub(1, 4) == "Rock" then -- 바위도 화강암 사진 텍스처 (D-1744)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("MeshPart") then
				for _, x in ipairs(d:GetChildren()) do if x:IsA("SurfaceAppearance") then x:Destroy() end end
				d.TextureID = ""
				d.Material = Enum.Material.Granite
				d.MaterialVariant = "OHU_HanokGranite"
				d.Color = Color3.fromRGB(255, 255, 255)
			end
		end
	end
	m.Parent = deco
	return m
end
local ROCKS = { -- RockC 매끈한 둥근 바위, RockB 세운 괴석
	{ "RockC", 254, 467, 1.3 }, { "RockC", 257, 482, 0.9 }, { "RockC", 289, 471, 0.8 }, { "RockC", 262, 460, 0.7 },
	{ "RockC", 280, 490, 0.7 }, { "RockC", 252, 559, 1.4 }, { "RockC", 255, 576, 1.0 }, { "RockC", 274, 582, 0.8 },
	{ "RockC", 293, 558, 0.9 }, { "RockC", 326, 565, 1.2 }, { "RockC", 327, 580, 0.9 }, { "RockB", 232, 520, 1.4 },
	{ "RockC", 234, 548, 1.2 }, { "RockB", 344, 472, 1.0 }, { "RockC", 333, 640, 1.3 }, { "RockB", 240, 640, 1.0 },
	{ "RockC", 268, 495, 0.6 }, { "RockC", 297, 579, 0.7 }, { "RockC", 247, 470, 0.9 }, { "RockC", 238, 600, 1.1 },
}
for i, r in ipairs(ROCKS) do place(r[1], Vector3.new(r[2], GY, r[3]), r[4], i * 1.7) end
local FERNS = { { 252, 473 }, { 258, 488 }, { 286, 466 }, { 291, 482 }, { 262, 493 }, { 276, 461 }, { 250, 566 }, { 260, 582 }, { 280, 586 }, { 296, 554 }, { 322, 559 }, { 330, 573 }, { 316, 584 }, { 290, 588 }, { 232, 470 }, { 233, 505 }, { 233, 560 }, { 233, 590 }, { 340, 490 }, { 346, 505 }, { 339, 530 }, { 330, 610 }, { 340, 630 }, { 262, 636 }, { 300, 636 }, { 276, 640 } }
for i, f in ipairs(FERNS) do place("Fern", Vector3.new(f[1], GY, f[2]), 0.8 + (i % 4) * 0.15, i * 2.3) end
place("Persimmon", Vector3.new(233, GY + 0.42, 534), 1, 0.4)
place("Persimmon", Vector3.new(342, GY + 0.42, 600), 0.85, 2.2)
-- 도드라진 납작 돌(AI 메시 Flagstone, 사용자 사진의 튀어나온 판석): 길과 연못 둘레에만, 크기 · 방향 제각각, 포장 색
local FS = assets and assets:FindFirstChild("Flagstone")
FS = FS and FS:FindFirstChildWhichIsA("MeshPart", true)
if FS then
	local stones = folder("Flagstones")
	local frs = Random.new(1117)
	local function blocked(x, z)
		if inPond(x, z, 0.6) then return true end
		if x > X0 - 5 and x < X1 + 5 and z > Z0 - 5 and z < Z1 + 8 then return true end
		if x > 264 and x < 316 and z > 597 and z < 627 then return true end
		if x > bx - 5.5 and x < bx + 5.5 and z > 552 and z < 591 then return true end
		if x < 237 and z > 469 and z < 599 then return true end
		return false
	end
	local function put(x, z)
		if blocked(x, z) then return end
		local p = FS:Clone()
		for _, d in ipairs(p:GetChildren()) do if d:IsA("SurfaceAppearance") then d:Destroy() end end
		p.TextureID = ""
		p.Material = Enum.Material.Granite
		p.MaterialVariant = "OHU_HanokGranite"
		p.Color = Color3.fromRGB(255, 255, 255)
		p.Size = Vector3.new(frs:NextNumber(2.6, 3.6), frs:NextNumber(0.2, 0.28), frs:NextNumber(2.2, 3.2))
		p.CFrame = CFrame.new(x, GY + 0.02, z) * CFrame.Angles(frs:NextNumber(-0.02, 0.02), frs:NextNumber(0, 6.28), frs:NextNumber(-0.02, 0.02))
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Parent = stones
	end
	local ZONES = { { 236, 258, 456, 600 }, { 236, 293, 494, 516 }, { 236, 326, 586, 600 }, { 296, 318, 543, 553 } }
	for _, zn in ipairs(ZONES) do
		for x = zn[1] + 1.8, zn[2] - 1, 3.7 do
			for z = zn[3] + 1.8, zn[4] - 1, 3.4 do
				put(x + frs:NextNumber(-0.6, 0.6), z + frs:NextNumber(-0.6, 0.6))
			end
		end
	end
	for _, c in ipairs(DISCS) do
		local n = math.floor(c[3] * 0.9)
		for k = 1, n do
			local a = k / n * math.pi * 2 + frs:NextNumber(-0.1, 0.1)
			put(c[1] + math.cos(a) * (c[3] + 1.4), c[2] + math.sin(a) * (c[3] + 1.4))
		end
	end
end
local shrub = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("Shrub")
if shrub then
	local SH = { { 231, 478 }, { 231, 498 }, { 232, 590 }, { 344, 462 }, { 346, 520 }, { 345, 540 }, { 332, 566 }, { 332, 625 }, { 250, 640 }, { 290, 640 }, { 315, 642 } }
	for i, s in ipairs(SH) do
		local m = shrub:Clone()
		m:ScaleTo(m:GetScale() * (0.45 + (i % 3) * 0.12))
		local cf, sz = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (Vector3.new(s[1], GY + 0.42 + sz.Y / 2, s[2]) - cf.Position))
		m.Parent = deco
	end
end

-- 정자 (차 마시는 마루, 북쪽 = 연못 쪽으로 열림)
local pav = folder("Pavilion")
local PX0, PX1, PZ0, PZ1, PF = 268, 312, 601, 623, 2.5
stone(pav, "Base", PX0 - 2, PX1 + 2, 0, PF - 0.8, PZ0 - 2, PZ1 + 2)
wood(pav, "Maru", PX0 - 1.5, PX1 + 1.5, PF - 0.8, PF, PZ0 - 1.5, PZ1 + 1.5, true).Color = Color3.fromRGB(236, 196, 140)
stone(pav, "Step", bx - 9, bx + 9, 0, 1.75, PZ0 - 5.4, PZ0 - 2)
ramp(pav, bx, PZ0 - 3.7, 18, 3.4, PF, Vector3.new(0, 0, 1))
local PH = 19.5
local function pv(x, z) return Vector3.new(x, PF, z) end
K.face(pav, pv(PX0, PZ0), pv(PX1, PZ0), Vector3.new(0, 0, -1), { "Open", "Open", "Open" }, PH)
K.face(pav, pv(PX1, PZ0), pv(PX1, PZ1), Vector3.new(1, 0, 0), { "Open", "Open" }, PH)
K.face(pav, pv(PX1, PZ1), pv(PX0, PZ1), Vector3.new(0, 0, 1), { "WallWindow", "WallWindow", "WallWindow" }, PH)
K.face(pav, pv(PX0, PZ1), pv(PX0, PZ0), Vector3.new(-1, 0, 0), { "Open", "Open" }, PH)
wood(pav, "Ceiling", PX0, PX1, PF + PH - 0.5, PF + PH, PZ0, PZ1, true)
-- 지붕: 집 지붕(HanokRoof_4)을 0.66배로 복사 (집은 긴 쪽이 z, 정자는 x)
local roofSrc
for _, m in ipairs(workspace.HanokRoofs:GetChildren()) do
	local cf = m:GetBoundingBox()
	if (Vector3.new(cf.X, 0, cf.Z) - Vector3.new(bcf.X, 0, bcf.Z)).Magnitude < 5 then roofSrc = m end
end
if roofSrc then
	local s = 0.66
	local bTop = (bcf - bcf.Position) + Vector3.new(bcf.X, TOP, bcf.Z)
	local rel = bTop:ToObjectSpace(roofSrc:GetPivot())
	local pTop = CFrame.new((PX0 + PX1) / 2, PF + PH, (PZ0 + PZ1) / 2)
	local r = roofSrc:Clone()
	r.Name = "PavilionRoof"
	r:ScaleTo(r:GetScale() * s)
	r:PivotTo(pTop * CFrame.new(rel.Position * s) * (rel - rel.Position))
	r.Parent = pav
end
local tz2 = PZ0 + 5
wood(pav, "TeaTable", 276, 304, PF + 1.7, PF + 2.1, tz2 - 2.2, tz2 + 2.2, true).Color = Color3.fromRGB(176, 120, 72)
wood(pav, "TeaTableBase", 277, 303, PF, PF + 1.7, tz2 - 1.6, tz2 + 1.6).Color = Color3.fromRGB(150, 100, 60)

-- 다도세트 (사용자 사진): 흰 쟁반 안 대나무 차판, 크림색 점박이 도자기 옆손잡이 찻주전자 · 숙우 · 잔 3(둘은 겹쳐)
local tea = Instance.new("Model")
tea.Name = "TeaSet"
tea.Parent = pav
local TY = PF + 2.1 -- 찻상 윗면
local TX = 290
local CREAM = Color3.fromRGB(240, 234, 220)
local function ceramic(p)
	p.Material = Enum.Material.SmoothPlastic p.Color = CREAM p.CanCollide = false p.CastShadow = true
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local t = Instance.new("Texture") t.Texture = "rbxassetid://126869188514605" t.Face = face t.StudsPerTileU = 2.2 t.StudsPerTileV = 2.2 t.Transparency = 0.25 t.Parent = p
	end
	return p
end
-- 둥근 그릇(CSG): 공에서 윗부분 · 안쪽 · 바닥을 도려냄 + 굽. 잔 · 숙우
local function bowl(name, x, y, z, d, h)
	local ball = Instance.new("Part") ball.Shape = Enum.PartType.Ball ball.Size = Vector3.new(d, d, d)
	local cy = y + d / 2 - 0.06 -- 공 가운데 (바닥을 0.06 평평하게 자름)
	h = math.min(h, cy - y)
	ball.CFrame = CFrame.new(x, cy, z) ball.Anchored = true ball.Parent = workspace
	local cut = Instance.new("Part") cut.Size = Vector3.new(d + 1, d, d + 1) cut.CFrame = CFrame.new(x, y + h + d / 2, z) cut.Anchored = true cut.Parent = workspace
	local inner = Instance.new("Part") inner.Shape = Enum.PartType.Ball inner.Size = Vector3.new(d - 0.1, d - 0.1, d - 0.1)
	inner.CFrame = ball.CFrame + Vector3.new(0, 0.04, 0) inner.Anchored = true inner.Parent = workspace
	local floorCut = Instance.new("Part") floorCut.Size = Vector3.new(d + 1, d, d + 1) floorCut.CFrame = CFrame.new(x, y - d / 2, z) floorCut.Anchored = true floorCut.Parent = workspace
	local u = ball:SubtractAsync({ cut, inner, floorCut })
	for _, p in ipairs({ ball, cut, inner, floorCut }) do p:Destroy() end
	u.Name = name u.UsePartColor = true u.Anchored = true
	ceramic(u)
	u.Parent = tea
	local ft = ceramic(box(tea, name .. "Foot", Vector3.new(0.08, d * 0.45, d * 0.45), Vector3.new(x, y + 0.04, z), nil))
	ft.Shape = Enum.PartType.Cylinder
	ft.CFrame = CFrame.new(x, y + 0.04, z) * CFrame.Angles(0, 0, math.pi / 2)
	return u
end
local tw = box(tea, "TrayWhite", Vector3.new(4.2, 0.12, 1.9), Vector3.new(TX, TY + 0.06, tz2), nil, { collide = false })
mat(tw, Enum.Material.SmoothPlastic, Color3.fromRGB(244, 244, 242))
for _, d in ipairs({ { 0, -0.92, 4.2, 0.08 }, { 0, 0.92, 4.2, 0.08 }, { -2.06, 0, 0.08, 1.9 }, { 2.06, 0, 0.08, 1.9 } }) do
	mat(box(tea, "TrayRim", Vector3.new(d[3], 0.12, d[4]), Vector3.new(TX + d[1], TY + 0.18, tz2 + d[2]), nil, { collide = false, shadow = false }), Enum.Material.SmoothPlastic, Color3.fromRGB(244, 244, 242))
end
local bam = box(tea, "Bamboo", Vector3.new(3.85, 0.08, 1.55), Vector3.new(TX, TY + 0.16, tz2), "woodH", { collide = false, shadow = false })
bam.Color = Color3.fromRGB(255, 232, 190)
for k = -2, 2 do
	local g = box(tea, "Slot", Vector3.new(3.85, 0.01, 0.035), Vector3.new(TX, TY + 0.205, tz2 + k * 0.28), nil, { collide = false, shadow = false })
	mat(g, Enum.Material.SmoothPlastic, Color3.fromRGB(150, 110, 64))
end
local FY2 = TY + 0.2 -- 차판 윗면
-- AI 도자기 메시(TeaKyusu · TeaPitcher · TeaCup, D-1743 사용자 요청): 있으면 이것을 씀, 없으면 아래 부품 도자기
local function ware(name, x, y, z, scale, yaw)
	local src = assets and assets:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw, 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (Vector3.new(x, y + s.Y / 2, z) - cf.Position))
	m.Parent = tea
	return m
end
if ware("TeaKyusu", TX - 1.2, FY2, tz2 + 0.1, 1.05, math.rad(200)) then
	ware("TeaPitcher", TX - 0.3, TY, tz2 - 1.45, 1.35, math.rad(-20))
	ware("TeaCup", TX + 0.2, FY2, tz2 + 0.2, 1, math.rad(30))
	local c1 = ware("TeaCup", TX + 1.3, FY2, tz2 - 0.2, 1, math.rad(120))
	local _, s1 = c1:GetBoundingBox()
	ware("TeaCup", TX + 1.3, FY2 + s1.Y * 0.55, tz2 - 0.2, 1, math.rad(150))
else
-- 옆손잡이 찻주전자 (왼쪽)
local px, pz = TX - 1.2, tz2 + 0.1
local body = ceramic(box(tea, "PotBody", Vector3.new(0.9, 0.9, 0.9), Vector3.new(px, FY2 + 0.42, pz), nil))
body.Shape = Enum.PartType.Ball
local foot = ceramic(box(tea, "PotFoot", Vector3.new(0.12, 0.6, 0.6), Vector3.new(px, FY2 + 0.06, pz), nil))
foot.Shape = Enum.PartType.Cylinder
foot.CFrame = CFrame.new(px, FY2 + 0.06, pz) * CFrame.Angles(0, 0, math.pi / 2)
local lid = ceramic(box(tea, "PotLid", Vector3.new(0.1, 0.52, 0.52), Vector3.new(px, FY2 + 0.86, pz), nil))
lid.Shape = Enum.PartType.Cylinder
lid.CFrame = CFrame.new(px, FY2 + 0.86, pz) * CFrame.Angles(0, 0, math.pi / 2)
local knob = ceramic(box(tea, "PotKnob", Vector3.new(0.2, 0.2, 0.2), Vector3.new(px, FY2 + 0.97, pz), nil))
knob.Shape = Enum.PartType.Ball
local spout = ceramic(box(tea, "PotSpout", Vector3.new(0.5, 0.16, 0.16), Vector3.new(px + 0.55, FY2 + 0.5, pz), nil))
spout.Shape = Enum.PartType.Cylinder
spout.CFrame = CFrame.new(px + 0.55, FY2 + 0.52, pz) * CFrame.Angles(0, 0, math.rad(30))
local handle = ceramic(box(tea, "PotHandle", Vector3.new(0.5, 0.15, 0.15), Vector3.new(px, FY2 + 0.55, pz - 0.7), nil))
handle.Shape = Enum.PartType.Cylinder
handle.CFrame = CFrame.new(px - 0.6, FY2 + 0.6, pz + 0.1) * CFrame.Angles(0, math.rad(-20), math.rad(-28))
-- 숙우 (뒤쪽 가운데, 차판 밖 찻상 위) + 뾰족한 주둥이
bowl("Pitcher", TX - 0.3, TY, tz2 - 1.45, 1.05, 0.6)
local sp = ceramic(box(tea, "PitcherSpout", Vector3.new(0.18, 0.08, 0.28), Vector3.new(TX - 0.3 + 0.58, TY + 0.58, tz2 - 1.45), nil))
sp.CFrame = CFrame.new(TX - 0.3 + 0.58, TY + 0.58, tz2 - 1.45) * CFrame.Angles(0, 0, math.rad(12))
-- 잔: 가운데 하나, 오른쪽 둘 겹쳐
local function cup(x, y, z)
	bowl("Cup", x, y, z, 0.6, 0.38)
end
cup(TX + 0.15, FY2, tz2 + 0.15)
cup(TX + 1.3, FY2, tz2 - 0.2)
cup(TX + 1.3, FY2 + 0.26, tz2 - 0.2)
end
-- 어두운 나무(사용자 사진): 찻상 · 식탁 · 의자 · 낮은 탁자
local DARKNAMES = { TeaTable = 1, TeaTableBase = 1, TableTop = 1, TableLeg = 1, ChairSeat = 1, ChairBack = 1, ChairLegs = 1, LowTableTop = 1, LowTableBase = 1 }
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") and DARKNAMES[d.Name] then
		d.MaterialVariant = d.MaterialVariant == "OHU_HanokPineH" and "OHU_HanokDarkH" or "OHU_HanokDarkV"
		d.Color = Color3.fromRGB(255, 255, 255)
	end
end
-- 방석 4 (앉기)
for _, x in ipairs({ 280, 287, 294, 301 }) do
	local seat = Instance.new("Seat")
	seat.Name = "Cushion" seat.Anchored = true seat.Size = Vector3.new(3, 0.45, 3)
	seat.TopSurface = Enum.SurfaceType.Smooth seat.BottomSurface = Enum.SurfaceType.Smooth
	local pos = Vector3.new(x, PF + 0.23, tz2 + 4)
	seat.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	mat(seat, Enum.Material.Fabric, Color3.fromRGB(150, 146, 140))
	seat.Parent = pav
end
local pl = Instance.new("PointLight")
pl.Color = Color3.fromRGB(255, 214, 160) pl.Range = 22 pl.Brightness = 0.8 pl.Parent = pav:FindFirstChild("Ceiling")

-- 북쪽 담 대문 (x 238..250): 담을 둘로 자르고 기둥 · 인방 · 안쪽으로 열린 문 두 짝, 그 위 기와는 2.6 올림
local gate = folder("Gate")
local GX0, GX1 = 238, 250
local nw = park:FindFirstChild("NorthWall_1117")
if not nw then
	for _, w in ipairs(workspace:GetChildren()) do
		if w.Name == "HanokStoneWall" and math.abs(w.Position.Z - 454.3) < 1 and math.abs(w.Position.X - 288.9) < 2 then nw = w end
	end
	assert(nw, "north wall not found")
	local a, b = nw:Clone(), nw:Clone()
	local wx0, wx1 = nw.Position.X - nw.Size.X / 2, nw.Position.X + nw.Size.X / 2
	a.Size = Vector3.new(GX0 - wx0, nw.Size.Y, nw.Size.Z)
	a.Position = Vector3.new((wx0 + GX0) / 2, nw.Position.Y, nw.Position.Z)
	b.Size = Vector3.new(wx1 - GX1, nw.Size.Y, nw.Size.Z)
	b.Position = Vector3.new((GX1 + wx1) / 2, nw.Position.Y, nw.Position.Z)
	a:SetAttribute("SplitBy", "hanok_garden_1117") b:SetAttribute("SplitBy", "hanok_garden_1117")
	a.Parent = workspace b.Parent = workspace
	nw.Name = "NorthWall_1117"
	nw.Parent = park
	for _, g in ipairs(workspace.HanokStoneWalls:GetChildren()) do
		local cf = g:IsA("Model") and g:GetPivot() or g.CFrame
		if math.abs(cf.Z - 454.3) < 2 and cf.X > GX0 - 2 and cf.X < GX1 + 2 and not g:GetAttribute("GateRaised") then
			if g:IsA("Model") then g:PivotTo(g:GetPivot() + Vector3.new(0, 2.6, 0)) else g.CFrame += Vector3.new(0, 2.6, 0) end
			g:SetAttribute("GateRaised", true)
		end
	end
end
local WZ = 454.3
wood(gate, "PostW", GX0, GX0 + 1.4, 0, 16.4, WZ - 1.2, WZ + 1.2)
wood(gate, "PostE", GX1 - 1.4, GX1, 0, 16.4, WZ - 1.2, WZ + 1.2)
wood(gate, "Lintel", GX0 - 0.6, GX1 + 0.6, 13.8, 16.4, WZ - 1.3, WZ + 1.3, true)
stone(gate, "Threshold", GX0, GX1, 0, GY + 0.2, WZ - 1.4, WZ + 1.4)
for _, x in ipairs({ GX0 + 1.7, GX1 - 1.7 }) do
	local p = wood(gate, "DoorLeaf", 0, 4.6, 0.6, 13.4, 0, 0.5, true)
	p.Size = Vector3.new(4.6, 12.8, 0.5)
	p.CFrame = CFrame.new(x, 7, WZ + 1.4 + 2.3) * CFrame.Angles(0, math.pi / 2, 0)
	p.Color = Color3.fromRGB(196, 150, 100)
end
stone(gate, "StepOut", GX0 - 1, GX1 + 1, 0, 0.6, WZ - 3.2, WZ - 1.4)
root.Parent = workspace
local n = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return ("HanokGarden parts %d, house %.1f-%.1f x %.1f-%.1f"):format(n, X0, X1, Z0, Z1)
