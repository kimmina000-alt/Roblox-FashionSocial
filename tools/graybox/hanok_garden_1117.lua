-- 한옥 연못 정원 (D-1741): 한옥 마을 남동쪽 필지(담 x 227..353, z 454..648)의 블록 집을
-- 유리 미닫이 한옥 + 연못 정원 + 차 마시는 정자로 (사용자 사진 docs/04_ART/references/hanok_garden_01.webp).
-- Studio Edit 모드, hanok_wall_kit.lua 를 먼저 실행(_G.HanokWallKit). 여러 번 돌려도 결과가 같다.
-- 체인 스크립트가 건드리지 않는 Workspace 최상위(HanokGarden)와 사용자 부품(블록 · 북쪽 담)만 바꾼다: 장소 저장 필요.
--   블록 Part(315, 504) → ServerStorage.ParkedHanokBlocks 로(지붕 HanokRoof_4 는 그대로).
--   북쪽 담(z 454)에 대문 자리(x 238..250)를 냄: 원래 담은 ServerStorage.ParkedHanokBlocks.NorthWall_1117 에 보관.
-- 에셋(있으면 씀, AI generate_mesh, place 전용): ServerStorage.ArtAssets.HanokGardenAssets.{Persimmon, RockA, RockB, RockC, Fern}
local K = _G.HanokWallKit
assert(K, "run tools/graybox/hanok_wall_kit.lua first")
local box = K.box

local SS = game:GetService("ServerStorage")
local park = SS:FindFirstChild("ParkedHanokBlocks") or Instance.new("Folder")
park.Name = "ParkedHanokBlocks"
park.Parent = SS

-- 1 블록 집 치우기 (지붕 기준 정보는 블록에서 읽음)
local block = park:FindFirstChild("Part_315_504")
if not block then
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Part" and (p.Position - Vector3.new(315, 16.1, 503.8)).Magnitude < 2 then
			block = p
		end
	end
	assert(block, "house block (315, 504) not found")
	block.Name = "Part_315_504"
	block.Parent = park
end
local bcf, bs = block.CFrame, block.Size
local hx = math.abs(bcf.RightVector.X) > 0.5
local SX, SZ = hx and bs.X or bs.Z, hx and bs.Z or bs.X
local X0, X1 = bcf.X - SX / 2, bcf.X + SX / 2 -- 299.2 .. 330.8
local Z0, Z1 = bcf.Z - SZ / 2, bcf.Z + SZ / 2 -- 468.6 .. 539
local TOP = bcf.Y + bs.Y / 2 -- 32.2
local GY = 0.12 -- 마당 포장 윗면

local old = workspace:FindFirstChild("HanokGarden")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "HanokGarden"
local function folder(name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = root
	return f
end
local function mat(p, material, color)
	p.Material = material
	p.Color = color
	return p
end
local STONE = Color3.fromRGB(206, 200, 188)
local function stone(m, name, x0, x1, y0, y1, z0, z1)
	local p = box(m, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), "stone")
	p.Color = STONE
	return p
end
local function wood(m, name, x0, x1, y0, y1, z0, z1, h)
	return box(m, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), h and "woodH" or "woodV")
end
-- 사람이 오르는 투명 경사로 (계단 위, 1.5 넘는 단 대신)
local function ramp(m, cx, cz, width, len, height, upDir)
	local w = Instance.new("WedgePart")
	w.Name = "Ramp"
	w.Anchored = true
	w.Transparency = 1
	w.CastShadow = false
	w.Size = Vector3.new(width, height, len)
	local pos = Vector3.new(cx, height / 2, cz)
	w.CFrame = CFrame.lookAt(pos, pos - upDir)
	w.Parent = m
	return w
end

-- 2 기단 + 계단 (높이 3)
local FY = 3
local base = folder("Platform")
stone(base, "Gidan", X0 - 4, X1 + 4, 0, FY, Z0 - 4, Z1 + 4)
local zc = (Z0 + Z1) / 2
stone(base, "StepW1", X0 - 7.4, X0 - 4, 0, 1, zc - 15, zc + 15)
stone(base, "StepW2", X0 - 5.7, X0 - 4, 1, 2, zc - 15, zc + 15)
ramp(base, X0 - 5.7, zc, 30, 3.4, FY, Vector3.new(1, 0, 0))
local sx = X0 + 8
stone(base, "StepS1", sx - 9, sx + 9, 0, 1, Z1 + 4, Z1 + 7.4)
stone(base, "StepS2", sx - 9, sx + 9, 1, 2, Z1 + 4, Z1 + 5.7)
ramp(base, sx, Z1 + 5.7, 18, 3.4, FY, Vector3.new(0, 0, -1))

-- 3 집 벽 (벽 키트, 기단 위 H = 블록 윗면까지)
local house = folder("House")
local H = TOP - FY
local function v(x, z)
	return Vector3.new(x, FY, z)
end
local G, GO = "GlassSlide", { "GlassSlide", open = true }
K.face(house, v(X0, Z0), v(X1, Z0), Vector3.new(0, 0, -1), { "WallWindow", "Wall" }, H) -- 북 (담 쪽)
K.face(house, v(X1, Z0), v(X1, Z1), Vector3.new(1, 0, 0), { "Wall", "WallWindow", "WallWindow", "Wall" }, H) -- 동
K.face(house, v(X1, Z1), v(X0, Z1), Vector3.new(0, 0, 1), { G, GO }, H) -- 남 (정자 쪽)
K.face(house, v(X0, Z1), v(X0, Z0), Vector3.new(-1, 0, 0), { G, GO, GO, G }, H) -- 서 (연못 쪽)

-- 4 실내 (사진: 나무 바닥, 책장 벽, 식탁, 흰 소파, 천장 보 + 매단 등)
local inn = folder("Interior")
local fl = wood(inn, "Floor", X0, X1, FY, FY + 0.2, Z0, Z1, true)
fl.Material = Enum.Material.Wood
fl.Color = Color3.fromRGB(250, 222, 180)
wood(inn, "Ceiling", X0, X1, TOP - 0.6, TOP, Z0, Z1, true)
for _, z in ipairs({ Z0 + SZ / 3, Z0 + SZ * 2 / 3 }) do
	wood(inn, "Daedulbo", X0, X1, TOP - 2.6, TOP - 0.6, z - 0.9, z + 0.9, true)
end
local function lamp(x, z)
	local l = box(inn, "PaperLamp", Vector3.new(7, 0.6, 11), Vector3.new(x, TOP - 7, z), "paper", { collide = false, shadow = false })
	l.Material = Enum.Material.Neon
	l.Color = Color3.fromRGB(255, 238, 205)
	l.Transparency = 0.15
	local fr = wood(inn, "LampFrame", x - 3.7, x + 3.7, TOP - 6.6, TOP - 6.2, z - 5.7, z + 5.7, true)
	fr.CanCollide = false
	for _, d in ipairs({ { -3, -5 }, { 3, -5 }, { -3, 5 }, { 3, 5 } }) do
		local r = box(inn, "LampRod", Vector3.new(0.08, 6.4, 0.08), Vector3.new(x + d[1], TOP - 3.4, z + d[2]), "iron", { collide = false, shadow = false })
		r.CanQuery = false
	end
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 214, 160)
	pl.Range = 26
	pl.Brightness = 1.2
	pl.Shadows = true
	pl.Parent = l
end
lamp((X0 + X1) / 2, Z0 + SZ * 0.3)
lamp((X0 + X1) / 2, Z0 + SZ * 0.72)
-- 책장 (동쪽 벽 안)
local shelf = Instance.new("Model")
shelf.Name = "Bookshelf"
shelf.Parent = inn
local bz0, bz1, by1 = Z0 + 8, Z0 + 38, FY + 21
wood(shelf, "Back", X1 - 0.5, X1, FY, by1, bz0, bz1, true)
wood(shelf, "SideA", X1 - 3.2, X1, FY, by1, bz0, bz0 + 0.5)
wood(shelf, "SideB", X1 - 3.2, X1, FY, by1, bz1 - 0.5, bz1)
local rows = 5
local rh = (by1 - FY - 0.5) / rows
for i = 0, rows do
	local y = FY + i * rh
	wood(shelf, "Board" .. i, X1 - 3.2, X1 - 0.5, y, y + 0.5, bz0 + 0.5, bz1 - 0.5, true)
	if i < rows then
		local b = box(shelf, "Books" .. i, Vector3.new(2.2, rh - 0.9, bz1 - bz0 - 1.2), Vector3.new(X1 - 1.7, y + 0.5 + (rh - 0.9) / 2, (bz0 + bz1) / 2), "paper", { collide = false, shadow = false })
		b.Color = Color3.fromRGB(60, 44, 30)
		local t = Instance.new("Texture")
		t.Texture = "rbxassetid://73840800237202"
		t.Face = Enum.NormalId.Left -- -X (방 쪽)
		t.StudsPerTileU = 16
		t.StudsPerTileV = rh - 0.9
		t.OffsetStudsU = i * 5.3
		t.Parent = b
	end
end
-- 흰 소파 + 낮은 탁자 + 러그 (유리문을 보고)
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
-- 식탁 + 의자 4
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

-- 5 마당 바닥: 납작 돌 포장 + 화단 (사진의 크레이지 페이빙)
local gd = folder("Ground")
local LX0, LX1, LZ0, LZ1 = 228, 352, 455, 647
local pave = box(gd, "Paving", Vector3.new(LX1 - LX0, GY, LZ1 - LZ0), Vector3.new((LX0 + LX1) / 2, GY / 2, (LZ0 + LZ1) / 2), nil, { shadow = false })
mat(pave, Enum.Material.Slate, Color3.fromRGB(196, 190, 176))
local ptx = Instance.new("Texture")
ptx.Texture = "rbxassetid://111631043205596"
ptx.Face = Enum.NormalId.Top
ptx.StudsPerTileU = 13
ptx.StudsPerTileV = 13
ptx.Color3 = Color3.fromRGB(236, 228, 214)
ptx.Parent = pave
local GRASS = Color3.fromRGB(86, 112, 58)
local function bed(name, x0, x1, z0, z1)
	local e = box(gd, name .. "Edge", Vector3.new(x1 - x0 + 0.8, 0.55, z1 - z0 + 0.8), Vector3.new((x0 + x1) / 2, 0.275, (z0 + z1) / 2), nil, { shadow = false })
	mat(e, Enum.Material.Granite, Color3.fromRGB(176, 170, 158))
	local b = box(gd, name, Vector3.new(x1 - x0, 0.62, z1 - z0), Vector3.new((x0 + x1) / 2, 0.31, (z0 + z1) / 2), nil, { shadow = false })
	return mat(b, Enum.Material.Grass, GRASS)
end
bed("BedWest", LX0, 236, 470, 598)
bed("BedEast", 337, LX1, LZ0, 548)
bed("BedSouthEast", 326, LX1, 560, LZ1)
bed("BedBack", LX0, 326, 630, LZ1)

-- 6 연못 두 개 (원판을 겹쳐 둥근 모양), 수련, 돌 다리
local pond = folder("Ponds")
local WATER = Color3.fromRGB(54, 76, 62)
local function water(cx, cz, r)
	local rim = box(pond, "PondRim", Vector3.new(0.3, 2 * r + 1.4, 2 * r + 1.4), Vector3.new(cx, GY, cz), nil, { collide = false, shadow = false })
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame = CFrame.new(cx, GY, cz) * CFrame.Angles(0, 0, math.pi / 2)
	mat(rim, Enum.Material.Slate, Color3.fromRGB(150, 146, 134))
	local w = box(pond, "Water", Vector3.new(0.3, 2 * r, 2 * r), Vector3.new(cx, GY + 0.1, cz), nil, { collide = false, shadow = false })
	w.Shape = Enum.PartType.Cylinder
	w.CFrame = CFrame.new(cx, GY + 0.08, cz) * CFrame.Angles(0, 0, math.pi / 2)
	mat(w, Enum.Material.SmoothPlastic, WATER)
	w.Reflectance = 0.12
end
local P1 = { { 266, 473, 11 }, { 280, 479, 9 }, { 271, 486, 7.5 } }
local P2 = { { 266, 567, 12 }, { 284, 571, 11 }, { 302, 566, 10 }, { 318, 572, 8.5 } }
for _, c in ipairs(P1) do
	water(c[1], c[2], c[3])
end
for _, c in ipairs(P2) do
	water(c[1], c[2], c[3])
end
local rng = Random.new(1741)
local function lilies(list, n)
	for _ = 1, n do
		local c = list[rng:NextInteger(1, #list)]
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, c[3] - 1.6)
		local x, z = c[1] + math.cos(a) * d, c[2] + math.sin(a) * d
		local r = rng:NextNumber(0.7, 1.4)
		local pad = box(pond, "LilyPad", Vector3.new(0.06, 2 * r, 2 * r), Vector3.new(x, 0, z), nil, { collide = false, shadow = false })
		pad.Shape = Enum.PartType.Cylinder
		pad.CFrame = CFrame.new(x, GY + 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 6), math.pi / 2)
		mat(pad, Enum.Material.SmoothPlastic, Color3.fromRGB(96 + rng:NextInteger(0, 30), 140, 70))
		if rng:NextNumber() < 0.25 then
			local f = box(pond, "LotusFlower", Vector3.new(0.7, 0.5, 0.7), Vector3.new(x + 0.3, GY + 0.55, z), nil, { collide = false, shadow = false })
			f.Shape = Enum.PartType.Ball
			f.Size = Vector3.new(0.7, 0.7, 0.7)
			mat(f, Enum.Material.SmoothPlastic, Color3.fromRGB(250, 196, 214))
		end
	end
end
lilies(P1, 14)
lilies(P2, 20)
-- 연못 위 넓은 돌판 다리 (남쪽 계단 → 정자)
local bx = sx
stone(pond, "SlabBridge", bx - 5, bx + 5, 0, 0.9, 553, 590)
stone(pond, "SlabBridgeShadow", bx - 5.6, bx + 5.6, 0, 0.35, 553.5, 589.5).Color = Color3.fromRGB(120, 116, 106)

-- 7 바위 · 나무 · 관목
local deco = folder("Plants")
local assets = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("HanokGardenAssets")
local function place(name, pos, scale, yaw)
	local src = assets and assets:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw, 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (pos + Vector3.new(0, s.Y / 2, 0) - cf.Position))
	m.Parent = deco
	return m
end
-- 연못 가장자리 바위 (사진: 크고 둥근 회색 바위)
local ROCKS = { -- RockC 매끈한 둥근 바위, RockB 세운 괴석
	{ "RockC", 254, 467, 1.3 }, { "RockC", 257, 482, 0.9 }, { "RockC", 289, 471, 0.8 }, { "RockC", 262, 460, 0.7 },
	{ "RockC", 280, 490, 0.7 }, { "RockC", 252, 559, 1.4 }, { "RockC", 255, 576, 1.0 }, { "RockC", 274, 582, 0.8 },
	{ "RockC", 293, 558, 0.9 }, { "RockC", 326, 565, 1.2 }, { "RockC", 327, 580, 0.9 }, { "RockB", 232, 520, 1.4 },
	{ "RockC", 234, 548, 1.2 }, { "RockB", 344, 472, 1.0 }, { "RockC", 333, 640, 1.3 }, { "RockB", 240, 640, 1.0 },
	{ "RockC", 268, 495, 0.6 }, { "RockC", 297, 579, 0.7 }, { "RockC", 247, 470, 0.9 }, { "RockC", 238, 600, 1.1 },
}
for i, r in ipairs(ROCKS) do
	place(r[1], Vector3.new(r[2], GY, r[3]), r[4], i * 1.7)
end
-- 연못가 풀숲 (AI 메시 Fern)
local FERNS = { { 252, 473 }, { 258, 488 }, { 286, 466 }, { 291, 482 }, { 262, 493 }, { 276, 461 }, { 250, 566 }, { 260, 582 }, { 280, 586 }, { 296, 554 }, { 322, 559 }, { 330, 573 }, { 316, 584 }, { 290, 588 }, { 232, 470 }, { 233, 505 }, { 233, 560 }, { 233, 590 }, { 340, 490 }, { 346, 505 }, { 339, 530 }, { 330, 610 }, { 340, 630 }, { 262, 636 }, { 300, 636 }, { 276, 640 } }
for i, f in ipairs(FERNS) do
	place("Fern", Vector3.new(f[1], GY, f[2]), 0.8 + (i % 4) * 0.15, i * 2.3)
end
place("Persimmon", Vector3.new(233, 0.6, 534), 1, 0.4)
place("Persimmon", Vector3.new(342, 0.6, 600), 0.85, 2.2)
local shrub = SS:FindFirstChild("ArtAssets") and SS.ArtAssets:FindFirstChild("Shrub")
if shrub then
	local SH = { { 231, 478 }, { 231, 498 }, { 232, 590 }, { 344, 462 }, { 346, 520 }, { 345, 540 }, { 332, 566 }, { 332, 625 }, { 250, 640 }, { 290, 640 }, { 315, 642 } }
	for i, s in ipairs(SH) do
		local m = shrub:Clone()
		m:ScaleTo(m:GetScale() * (0.45 + (i % 3) * 0.12))
		local cf, sz = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (Vector3.new(s[1], 0.6 + sz.Y / 2, s[2]) - cf.Position))
		m.Parent = deco
	end
end

-- 8 정자 (차 마시는 마루, 북쪽 = 연못 쪽으로 열림)
local pav = folder("Pavilion")
local PX0, PX1, PZ0, PZ1, PF = 268, 312, 601, 623, 2.5
stone(pav, "Base", PX0 - 2, PX1 + 2, 0, PF - 0.8, PZ0 - 2, PZ1 + 2)
local maru = wood(pav, "Maru", PX0 - 1.5, PX1 + 1.5, PF - 0.8, PF, PZ0 - 1.5, PZ1 + 1.5, true)
maru.Color = Color3.fromRGB(236, 196, 140)
stone(pav, "Step", bx - 9, bx + 9, 0, 1.3, PZ0 - 5.4, PZ0 - 2)
ramp(pav, bx, PZ0 - 3.7, 18, 3.4, PF, Vector3.new(0, 0, 1))
local PH = 19.5
local function pv(x, z)
	return Vector3.new(x, PF, z)
end
K.face(pav, pv(PX0, PZ0), pv(PX1, PZ0), Vector3.new(0, 0, -1), { "Open", "Open", "Open" }, PH)
K.face(pav, pv(PX1, PZ0), pv(PX1, PZ1), Vector3.new(1, 0, 0), { "Open", "Open" }, PH)
K.face(pav, pv(PX1, PZ1), pv(PX0, PZ1), Vector3.new(0, 0, 1), { "WallWindow", "WallWindow", "WallWindow" }, PH)
K.face(pav, pv(PX0, PZ1), pv(PX0, PZ0), Vector3.new(-1, 0, 0), { "Open", "Open" }, PH)
wood(pav, "Ceiling", PX0, PX1, PF + PH - 0.5, PF + PH, PZ0, PZ1, true)
-- 지붕: 집 지붕(HanokRoof_4)을 0.66배로 복사해 90도 돌림
local roofSrc
for _, m in ipairs(workspace.HanokRoofs:GetChildren()) do
	local cf = m:GetBoundingBox()
	if (Vector3.new(cf.X, 0, cf.Z) - Vector3.new(bcf.X, 0, bcf.Z)).Magnitude < 5 then
		roofSrc = m
	end
end
if roofSrc then
	local s = 0.66
	local bTop = (bcf - bcf.Position) + Vector3.new(bcf.X, TOP, bcf.Z)
	local rel = bTop:ToObjectSpace(roofSrc:GetPivot())
	local pTop = CFrame.new((PX0 + PX1) / 2, PF + PH, (PZ0 + PZ1) / 2) -- 긴 쪽이 x (집 블록은 긴 쪽이 z)
	local r = roofSrc:Clone()
	r.Name = "PavilionRoof"
	r:ScaleTo(r:GetScale() * s)
	r:PivotTo(pTop * CFrame.new(rel.Position * s) * (rel - rel.Position))
	r.Parent = pav
end
-- 긴 낮은 탁자 + 다기 + 방석(앉기)
local tz2 = PZ0 + 5
local tt = wood(pav, "TeaTable", 276, 304, PF + 1.7, PF + 2.1, tz2 - 2.2, tz2 + 2.2, true)
tt.Color = Color3.fromRGB(176, 120, 72)
wood(pav, "TeaTableBase", 277, 303, PF, PF + 1.7, tz2 - 1.6, tz2 + 1.6).Color = Color3.fromRGB(150, 100, 60)
local tray = box(pav, "Tray", Vector3.new(3.4, 0.14, 2.2), Vector3.new(290, PF + 2.17, tz2), "iron", { collide = false, shadow = false })
tray.Color = Color3.fromRGB(30, 28, 28)
local pot = box(pav, "Teapot", Vector3.new(1.1, 1.1, 1.1), Vector3.new(289.4, PF + 2.75, tz2), nil, { collide = false })
pot.Shape = Enum.PartType.Ball
mat(pot, Enum.Material.SmoothPlastic, Color3.fromRGB(120, 72, 44))
local lid = box(pav, "TeapotLid", Vector3.new(0.2, 0.55, 0.55), Vector3.new(289.4, PF + 3.32, tz2), nil, { collide = false, shadow = false })
lid.Shape = Enum.PartType.Cylinder
lid.CFrame = CFrame.new(289.4, PF + 3.32, tz2) * CFrame.Angles(0, 0, math.pi / 2)
mat(lid, Enum.Material.SmoothPlastic, Color3.fromRGB(100, 60, 36))
local spout = box(pav, "TeapotSpout", Vector3.new(0.7, 0.2, 0.2), Vector3.new(290.1, PF + 2.85, tz2), nil, { collide = false, shadow = false })
spout.CFrame = CFrame.new(290.1, PF + 2.9, tz2) * CFrame.Angles(0, 0, math.rad(35))
mat(spout, Enum.Material.SmoothPlastic, Color3.fromRGB(120, 72, 44))
for i, x in ipairs({ 290.6, 291.2 }) do
	local cup = box(pav, "Cup", Vector3.new(0.4, 0.55, 0.55), Vector3.new(x, PF + 2.44, tz2 + (i == 1 and -0.5 or 0.5)), nil, { collide = false, shadow = false })
	cup.Shape = Enum.PartType.Cylinder
	cup.CFrame = CFrame.new(x, PF + 2.44, tz2 + (i == 1 and -0.5 or 0.5)) * CFrame.Angles(0, 0, math.pi / 2)
	mat(cup, Enum.Material.SmoothPlastic, Color3.fromRGB(246, 244, 238))
end
for _, x in ipairs({ 280, 287, 294, 301 }) do
	local seat = Instance.new("Seat")
	seat.Name = "Cushion"
	seat.Anchored = true
	seat.Size = Vector3.new(3, 0.45, 3)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	local pos = Vector3.new(x, PF + 0.23, tz2 + 4)
	seat.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	mat(seat, Enum.Material.Fabric, Color3.fromRGB(150, 146, 140))
	seat.Parent = pav
end
local pl = Instance.new("PointLight")
pl.Color = Color3.fromRGB(255, 214, 160)
pl.Range = 22
pl.Brightness = 0.8
pl.Parent = pav:FindFirstChild("Ceiling")

-- 9 북쪽 담 대문 (x 238..250): 담을 둘로 자르고 기둥 · 인방 · 열린 문 두 짝, 그 위 기와는 올림
local gate = folder("Gate")
local GX0, GX1 = 238, 250
local nw = park:FindFirstChild("NorthWall_1117")
if not nw then
	for _, w in ipairs(workspace:GetChildren()) do
		if w.Name == "HanokStoneWall" and math.abs(w.Position.Z - 454.3) < 1 and math.abs(w.Position.X - 288.9) < 2 then
			nw = w
		end
	end
	assert(nw, "north wall not found")
	local a = nw:Clone()
	local b = nw:Clone()
	local wx0, wx1 = nw.Position.X - nw.Size.X / 2, nw.Position.X + nw.Size.X / 2
	a.Size = Vector3.new(GX0 - wx0, nw.Size.Y, nw.Size.Z)
	a.Position = Vector3.new((wx0 + GX0) / 2, nw.Position.Y, nw.Position.Z)
	b.Size = Vector3.new(wx1 - GX1, nw.Size.Y, nw.Size.Z)
	b.Position = Vector3.new((GX1 + wx1) / 2, nw.Position.Y, nw.Position.Z)
	a:SetAttribute("SplitBy", "hanok_garden_1117")
	b:SetAttribute("SplitBy", "hanok_garden_1117")
	a.Parent = workspace
	b.Parent = workspace
	nw.Name = "NorthWall_1117"
	nw.Parent = park
	-- 대문 위 기와: 담 기와 모듈을 문 위로 2.6 올림
	for _, g in ipairs(workspace.HanokStoneWalls:GetChildren()) do
		local cf = g:IsA("Model") and g:GetPivot() or g.CFrame
		if math.abs(cf.Z - 454.3) < 2 and cf.X > GX0 - 2 and cf.X < GX1 + 2 and not g:GetAttribute("GateRaised") then
			if g:IsA("Model") then
				g:PivotTo(g:GetPivot() + Vector3.new(0, 2.6, 0))
			else
				g.CFrame += Vector3.new(0, 2.6, 0)
			end
			g:SetAttribute("GateRaised", true)
		end
	end
end
local WZ, WT = 454.3, 2
wood(gate, "PostW", GX0, GX0 + 1.4, 0, 16.4, WZ - 1.2, WZ + 1.2)
wood(gate, "PostE", GX1 - 1.4, GX1, 0, 16.4, WZ - 1.2, WZ + 1.2)
wood(gate, "Lintel", GX0 - 0.6, GX1 + 0.6, 13.8, 16.4, WZ - 1.3, WZ + 1.3, true)
stone(gate, "Threshold", GX0, GX1, 0, 0.5, WZ - 1.4, WZ + 1.4)
-- 안쪽으로 활짝 열린 문짝 두 개 (담에 붙음)
local function leaf(x, dirSign)
	local p = wood(gate, "DoorLeaf", 0, 4.6, 0.6, 13.4, 0, 0.5, true)
	p.Size = Vector3.new(4.6, 12.8, 0.5)
	p.CFrame = CFrame.new(x, 7, WZ + 1.4 + 2.3) * CFrame.Angles(0, math.pi / 2, 0)
	p.Color = Color3.fromRGB(196, 150, 100)
	return p
end
leaf(GX0 + 1.7, 1)
leaf(GX1 - 1.7, -1)
stone(gate, "StepOut", GX0 - 1, GX1 + 1, 0, 0.35, WZ - 3.2, WZ - 1.4)

root.Parent = workspace
local n = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("HanokGarden parts %d, house W %.1f-%.1f x %.1f-%.1f"):format(n, X0, X1, Z0, Z1)
