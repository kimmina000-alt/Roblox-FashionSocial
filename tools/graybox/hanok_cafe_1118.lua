-- 한옥 카페 (D-1746): 한옥 마을 가장 동쪽 큰 담장 필지(담 x 372..548, z 182..475)
-- 사용자 사진 5장(docs/04_ART/references/hanok_cafe_ref_1..5.jpg): 나무 판벽 커피 바 · 펜던트 등 · 러그 ·
-- 창가 바 좌석 북카페 · 나뭇가지 지붕 퍼걸러 아래 자갈 마당 라운지.
-- Studio Edit 모드, hanok_wall_kit.lua 를 먼저 실행(_G.HanokWallKit). 여러 번 돌려도 결과가 같다.
-- Workspace.HanokCafe (체인 밖, place 전용) + 사용자 블록 3채를 ServerStorage.ParkedHanokBlocks 로(지붕 그대로),
-- 서쪽 담에 대문(원래 담은 ParkedHanokBlocks.EastLotWestWall_1118).
--   A (509,231) 라운지 · B (507,330) 커피 바 · C (507,411) 북카페 · D (442,451) 블록은 그대로 두고 벽 키트로 겉만 입힘.
-- 에셋(AI generate_mesh, place 전용): ServerStorage.ArtAssets.HanokCafeAssets.{Espresso, LoungeChair, LoungeSofa,
--   PlyChair, RattanStool, PotTree, Monstera, RecordCrate}; 정원 에셋 HanokGardenAssets(Persimmon, Fern, Flagstone).
local K = _G.HanokWallKit
assert(K, "run tools/graybox/hanok_wall_kit.lua first")
local box = K.box
local SS = game:GetService("ServerStorage")
local park = SS:FindFirstChild("ParkedHanokBlocks") or Instance.new("Folder")
park.Name = "ParkedHanokBlocks"
park.Parent = SS
local CA = SS.ArtAssets:FindFirstChild("HanokCafeAssets")
local GA = SS.ArtAssets:FindFirstChild("HanokGardenAssets")

local TEX = {
	rugRed = "rbxassetid://72075903136240",
	rugKilim = "rbxassetid://78836512140697",
	art = { "rbxassetid://138787184369531", "rbxassetid://133247947455997", "rbxassetid://122049543004523" },
	records = "rbxassetid://120885446579681",
	books = "rbxassetid://73840800237202",
	sticks = "rbxassetid://138284036895420",
}

local LX0, LX1, LZ0, LZ1 = 373, 547, 183, 474
local GY = 0.12

-- 블록 찾기 (치운 것은 ParkedHanokBlocks 에서)
local function findBlock(x, z, parkIt)
	local name = ("Part_%d_%d"):format(x, z)
	local b = park:FindFirstChild(name)
	if not b then
		for _, p in ipairs(workspace:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Part" and (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(x, 0, z)).Magnitude < 3 then
				b = p
			end
		end
		assert(b, "block " .. name .. " not found")
		if parkIt then
			b.Name = name
			b.Parent = park
		end
	end
	local cf, s = b.CFrame, b.Size
	local hx = math.abs(cf.RightVector.X) > 0.5
	local SX, SZ = hx and s.X or s.Z, hx and s.Z or s.X
	return { X0 = cf.X - SX / 2, X1 = cf.X + SX / 2, Z0 = cf.Z - SZ / 2, Z1 = cf.Z + SZ / 2, TOP = cf.Y + s.Y / 2, cx = cf.X, cz = cf.Z }
end
local A = findBlock(509, 231, true)
local B = findBlock(507, 330, true)
local C = findBlock(507, 411, true)
local D = findBlock(442, 451, false)

local old = workspace:FindFirstChild("HanokCafe")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "HanokCafe"
local function folder(name, parent)
	local f = Instance.new("Model") f.Name = name f.Parent = parent or root return f
end
local function mat(p, material, color) p.Material = material p.Color = color return p end
local function bx(m, name, x0, x1, y0, y1, z0, z1, kind, opts)
	return box(m, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), kind, opts)
end
local function dark(p, horizontal)
	p.Material = Enum.Material.Wood
	p.MaterialVariant = horizontal and "OHU_HanokDarkH" or "OHU_HanokDarkV"
	p.Color = Color3.fromRGB(255, 255, 255)
	return p
end
local function ramp(m, cx, cz, width, len, height, upDir)
	local w = Instance.new("WedgePart")
	w.Name = "Ramp" w.Anchored = true w.Transparency = 1 w.CastShadow = false
	w.Size = Vector3.new(width, height, len)
	local pos = Vector3.new(cx, height / 2, cz)
	w.CFrame = CFrame.lookAt(pos, pos - upDir)
	w.Parent = m
	return w
end
-- 에셋 놓기: 바닥 가운데 = pos, yaw = 앞(-Z 기준) 회전
local function asset(src, parent, pos, scale, yaw, collide)
	if not src then return nil end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw, 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (pos + Vector3.new(0, s.Y / 2, 0) - cf.Position))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide == true
		end
	end
	m.Parent = parent
	return m, s
end
-- 앉는 자리(투명 Seat): 사람이 바라볼 방향 look
local function seat(parent, pos, look)
	local s = Instance.new("Seat")
	s.Name = "CafeSeat" s.Anchored = true s.Transparency = 1 s.CanCollide = false
	s.Size = Vector3.new(2, 0.3, 2)
	s.CFrame = CFrame.lookAt(pos, pos + look)
	s.Parent = parent
	return s
end
local function yawOf(look) return math.atan2(-look.X, -look.Z) end
-- 가구 + 자리: look = 앉은 사람이 보는 방향, seatH = 높이 비율
local function sitter(name, parent, pos, scale, look, seatH, seats)
	local m, s = asset(CA and CA:FindFirstChild(name), parent, pos, scale, yawOf(look), true)
	if not m then return end
	seats = seats or { 0 }
	local right = Vector3.new(-look.Z, 0, look.X)
	for _, off in ipairs(seats) do
		seat(parent, pos + Vector3.new(0, s.Y * seatH, 0) + right * off, look)
	end
	return m
end

-- 1 마당 바닥 + 화단 + 대문 ---------------------------------------------------------------
local gd = folder("Ground")
local pave = bx(gd, "Paving", LX0, LX1, 0, GY, LZ0, LZ1, nil, { shadow = false })
pave.Material = Enum.Material.Slate
pave.MaterialVariant = "OHU_HanokYard"
pave.Color = Color3.fromRGB(200, 200, 200)
local GRASS = Color3.fromRGB(86, 112, 58)
local function bed(name, x0, x1, z0, z1)
	mat(bx(gd, name .. "Edge", x0 - 0.4, x1 + 0.4, 0, 0.55, z0 - 0.4, z1 + 0.4, "stone", { shadow = false }), Enum.Material.Slate, Color3.fromRGB(222, 218, 210))
	return mat(bx(gd, name, x0, x1, 0, 0.62, z0, z1, nil, { shadow = false }), Enum.Material.Grass, GRASS)
end
bed("BedNorth", LX0, 486, LZ0, 192)
bed("BedWestN", LX0, 382, 192, 318)
bed("BedWestS", LX0, 382, 344, 425)
bed("BedEastGap", 530, LX1, 200, 460)

local GX0, GX1 = 318, 344 -- 대문 z 범위는 아래 split 에서 (서쪽 담 x 372)
GX0, GX1 = 320, 334
local ww = park:FindFirstChild("EastLotWestWall_1118")
if not ww then
	for _, w in ipairs(workspace:GetChildren()) do
		if w.Name == "HanokStoneWall" and math.abs(w.Position.X - 372) < 1.5 and w.Size.X > 200 then ww = w end
	end
	assert(ww, "west wall not found")
	local axis = ww.CFrame.RightVector -- 담 길이 방향 (z)
	local c = ww.Position
	local half = ww.Size.X / 2
	local zA, zB = c.Z - axis.Z * half, c.Z + axis.Z * half
	local z0, z1 = math.min(zA, zB), math.max(zA, zB)
	local function piece(za, zb)
		local p = ww:Clone()
		p.Size = Vector3.new(zb - za, ww.Size.Y, ww.Size.Z)
		p.CFrame = CFrame.fromMatrix(Vector3.new(c.X, c.Y, (za + zb) / 2), ww.CFrame.RightVector, ww.CFrame.UpVector)
		p:SetAttribute("SplitBy", "hanok_cafe_1118")
		p.Parent = workspace
	end
	piece(z0, GX0)
	piece(GX1, z1)
	ww.Name = "EastLotWestWall_1118"
	ww.Parent = park
	for _, g in ipairs(workspace.HanokStoneWalls:GetChildren()) do
		local cf = g:IsA("Model") and g:GetPivot() or g.CFrame
		if math.abs(cf.X - 372) < 2 and cf.Z > GX0 - 2 and cf.Z < GX1 + 2 and not g:GetAttribute("GateRaised") then
			if g:IsA("Model") then g:PivotTo(g:GetPivot() + Vector3.new(0, 2.6, 0)) else g.CFrame += Vector3.new(0, 2.6, 0) end
			g:SetAttribute("GateRaised", true)
		end
	end
end
do
	local gate = folder("Gate")
	local WX = 372
	bx(gate, "PostN", WX - 1.2, WX + 1.2, 0, 16.4, GX0, GX0 + 1.4, "woodV")
	bx(gate, "PostS", WX - 1.2, WX + 1.2, 0, 16.4, GX1 - 1.4, GX1, "woodV")
	bx(gate, "Lintel", WX - 1.3, WX + 1.3, 13.8, 16.4, GX0 - 0.6, GX1 + 0.6, "woodH")
	bx(gate, "Threshold", WX - 1.4, WX + 1.4, 0, 0.45, GX0, GX1, "stone")
	for _, z in ipairs({ GX0 + 1.7, GX1 - 1.7 }) do
		local p = bx(gate, "DoorLeaf", WX + 1.4, WX + 6, 0.5, 13.3, z - 0.25, z + 0.25, "woodH")
		p.Color = Color3.fromRGB(230, 200, 160)
	end
end

-- 2 건물: 기단 + 벽(키트) + 계단 -------------------------------------------------------------
local FY = 3
local G, GO = "GlassSlide", { "GlassSlide", open = true }
local function building(name, b, kinds, steps, keepBlock)
	local m = folder(name)
	mat(bx(m, "Gidan", b.X0 - 4, b.X1 + 4, 0, FY, b.Z0 - 4, b.Z1 + 4, "stone"), Enum.Material.Slate, Color3.fromRGB(222, 218, 210))
	local H = b.TOP - FY
	local function v(x, z) return Vector3.new(x, FY, z) end
	K.face(m, v(b.X0, b.Z0), v(b.X1, b.Z0), Vector3.new(0, 0, -1), kinds.N, H)
	K.face(m, v(b.X1, b.Z0), v(b.X1, b.Z1), Vector3.new(1, 0, 0), kinds.E, H)
	K.face(m, v(b.X1, b.Z1), v(b.X0, b.Z1), Vector3.new(0, 0, 1), kinds.S, H)
	K.face(m, v(b.X0, b.Z1), v(b.X0, b.Z0), Vector3.new(-1, 0, 0), kinds.W, H)
	for _, st in ipairs(steps) do -- { side, center, width }
		local s, c, w = st[1], st[2], st[3]
		if s == "W" then
			bx(m, "Step1", b.X0 - 7.4, b.X0 - 4, 0, 1, c - w / 2, c + w / 2, "stone").Color = Color3.fromRGB(222, 218, 210)
			bx(m, "Step2", b.X0 - 5.7, b.X0 - 4, 0, 2, c - w / 2, c + w / 2, "stone").Color = Color3.fromRGB(222, 218, 210)
			ramp(m, b.X0 - 5.7, c, w, 3.4, FY, Vector3.new(1, 0, 0))
		elseif s == "N" then
			bx(m, "Step1", c - w / 2, c + w / 2, 0, 1, b.Z0 - 7.4, b.Z0 - 4, "stone").Color = Color3.fromRGB(222, 218, 210)
			bx(m, "Step2", c - w / 2, c + w / 2, 0, 2, b.Z0 - 5.7, b.Z0 - 4, "stone").Color = Color3.fromRGB(222, 218, 210)
			ramp(m, c, b.Z0 - 5.7, w, 3.4, FY, Vector3.new(0, 0, 1))
		elseif s == "S" then
			bx(m, "Step1", c - w / 2, c + w / 2, 0, 1, b.Z1 + 4, b.Z1 + 7.4, "stone").Color = Color3.fromRGB(222, 218, 210)
			bx(m, "Step2", c - w / 2, c + w / 2, 0, 2, b.Z1 + 4, b.Z1 + 5.7, "stone").Color = Color3.fromRGB(222, 218, 210)
			ramp(m, c, b.Z1 + 5.7, w, 3.4, FY, Vector3.new(0, 0, -1))
		end
	end
	if not keepBlock then
		local fl = bx(m, "Floor", b.X0, b.X1, FY, FY + 0.2, b.Z0, b.Z1, "woodH")
		fl.Color = Color3.fromRGB(236, 214, 186)
		bx(m, "Ceiling", b.X0, b.X1, b.TOP - 0.6, b.TOP, b.Z0, b.Z1, "woodH")
		for _, f in ipairs({ 1 / 3, 2 / 3 }) do
			local z = b.Z0 + (b.Z1 - b.Z0) * f
			bx(m, "Daedulbo", b.X0, b.X1, b.TOP - 2.6, b.TOP - 0.6, z - 0.9, z + 0.9, "woodH")
		end
	end
	return m
end
local mA = building("Lounge", A, { N = { "WallWindow", "Wall" }, E = { "Wall", "WallWindow", "WallWindow", "Wall" }, S = { G, GO }, W = { G, GO, GO, G } }, { { "W", (A.Z0 + A.Z1) / 2, 30 }, { "S", A.X0 + 8, 14 } })
local mB = building("CoffeeBar", B, { N = { GO, G }, E = { "Wall", "WallWindow", "WallWindow", "Wall" }, S = { "Wall", "Wall" }, W = { G, GO, GO, G } }, { { "W", (B.Z0 + B.Z1) / 2, 30 }, { "N", B.X0 + 8, 14 } })
local mC = building("BookCafe", C, { N = { "Wall", "Wall" }, E = { "Wall", "WallWindow", "WallWindow", "Wall" }, S = { "WallWindow", "Wall" }, W = { G, GO, G, G } }, { { "W", C.Z1 - 30, 16 } }) -- 열린 유리 칸 앞
building("Hanok", D, { N = { "WallWindow", "DoorTtisal", "DoorTtisal", "WallWindow" }, E = { "WallBitsal", "Wall" }, S = { "Wall", "WallWindow", "WallWindow", "Wall" }, W = { "Wall", "WallBitsal" } }, { { "N", D.cx, 20 } }, true)

-- 실내 공통: 펜던트 등, 러그, 액자
local function pendant(parent, x, z, top, drop)
	local y = top - drop
	local cord = box(parent, "Cord", Vector3.new(0.08, drop - 0.6, 0.08), Vector3.new(x, y + 0.3 + (drop - 0.6) / 2, z), "iron", { collide = false, shadow = false })
	cord.CanQuery = false
	local shade = box(parent, "Shade", Vector3.new(1.9, 1.9, 1.9), Vector3.new(x, y, z), nil, { collide = false, shadow = false })
	shade.Shape = Enum.PartType.Ball
	mat(shade, Enum.Material.Neon, Color3.fromRGB(255, 232, 196))
	shade.Transparency = 0.1
	local cap = box(parent, "Cap", Vector3.new(0.5, 0.9, 0.9), Vector3.new(x, y + 0.95, z), "iron", { collide = false, shadow = false })
	cap.Shape = Enum.PartType.Cylinder
	cap.CFrame = CFrame.new(x, y + 0.95, z) * CFrame.Angles(0, 0, math.pi / 2)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 210, 150) l.Range = 18 l.Brightness = 0.9 l.Parent = shade
end
local function rug(parent, x, z, w, l, tex, yaw)
	local r = box(parent, "Rug", Vector3.new(w, 0.06, l), Vector3.new(x, FY + 0.23, z), nil, { collide = false, shadow = false })
	r.CFrame = CFrame.new(x, FY + 0.23, z) * CFrame.Angles(0, yaw or 0, 0)
	mat(r, Enum.Material.Fabric, Color3.fromRGB(255, 255, 255))
	local t = Instance.new("Texture") t.Texture = tex t.Face = Enum.NormalId.Top t.StudsPerTileU = w t.StudsPerTileV = l t.Parent = r
end
local function frame(parent, x, y, z, w, h, faceDir, tex)
	local p = box(parent, "Art", Vector3.new(w, h, 0.2), Vector3.new(x, y, z), nil, { collide = false, shadow = false })
	p.CFrame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + faceDir)
	local d = Instance.new("Decal") d.Texture = tex d.Face = Enum.NormalId.Front d.Parent = p
end
local function table2(parent, x, z, w, l, h)
	dark(bx(parent, "TableTop", x - w / 2, x + w / 2, FY + h - 0.35, FY + h, z - l / 2, z + l / 2, nil), true)
	dark(bx(parent, "TableLeg", x - 0.35, x + 0.35, FY + 0.2, FY + h - 0.35, z - 0.35, z + 0.35, nil))
	dark(bx(parent, "TableFoot", x - w * 0.3, x + w * 0.3, FY + 0.2, FY + 0.4, z - l * 0.3, z + l * 0.3, nil), true)
end

-- 3 라운지 A (사진 1 · 4: 러그, 작은 나무 탁자 + 합판 의자, 벽 액자, 가죽 벤치) -------------------
do
	local m = folder("Interior", mA)
	local cx = (A.X0 + A.X1) / 2
	for i, z in ipairs({ A.Z0 + 13, A.Z0 + 35, A.Z0 + 57 }) do
		rug(m, cx - 2, z, 14, 18, i == 2 and TEX.rugKilim or TEX.rugRed, math.pi / 2)
		table2(m, cx - 2, z, 4.5, 4.5, 4.2)
		sitter("PlyChair", m, Vector3.new(cx - 2, FY + 0.2, z - 4.2), 1, Vector3.new(0, 0, 1), 0.48)
		sitter("PlyChair", m, Vector3.new(cx - 2, FY + 0.2, z + 4.2), 1, Vector3.new(0, 0, -1), 0.48)
		sitter("PlyChair", m, Vector3.new(cx - 6.3, FY + 0.2, z), 1, Vector3.new(1, 0, 0), 0.48)
	end
	-- 동쪽 벽 가죽 벤치 (사진 1)
	local bench = bx(m, "Bench", A.X1 - 3.4, A.X1, FY + 0.2, FY + 2.6, A.Z0 + 6, A.Z1 - 6, nil)
	dark(bench)
	local cush = bx(m, "BenchCushion", A.X1 - 3.3, A.X1 - 0.1, FY + 2.6, FY + 3.2, A.Z0 + 6.2, A.Z1 - 6.2, nil)
	mat(cush, Enum.Material.Leather, Color3.fromRGB(150, 86, 46))
	for z = A.Z0 + 9, A.Z1 - 9, 5 do seat(m, Vector3.new(A.X1 - 1.8, FY + 3.2, z), Vector3.new(-1, 0, 0)) end
	for i, z in ipairs({ A.Z0 + 14, A.Z0 + 35, A.Z0 + 56 }) do
		frame(m, A.X1 - 0.12, FY + 10, z, 5, 6.6, Vector3.new(-1, 0, 0), TEX.art[i])
	end
	for _, f in ipairs({ 0.3, 0.7 }) do pendant(m, cx, A.Z0 + (A.Z1 - A.Z0) * f, A.TOP - 2.6, 9) end
	asset(CA and CA:FindFirstChild("Monstera"), m, Vector3.new(A.X0 + 3, FY + 0.2, A.Z0 + 3), 1.1, 0.4)
	asset(CA and CA:FindFirstChild("Monstera"), m, Vector3.new(A.X0 + 3, FY + 0.2, A.Z1 - 3), 1.1, 2.1)
end

-- 4 커피 바 B (사진 1 · 4: 스테인리스 상판 바, 에스프레소 머신, 메뉴 칠판, 펜던트 3, 레코드 상자) ---------
do
	local m = folder("Interior", mB)
	local cx0, cx1 = B.X1 - 11, B.X1 - 6.5 -- 바 몸통 (바리스타는 동쪽)
	local bz0, bz1 = B.Z0 + 10, B.Z1 - 12
	local body = bx(m, "BarBody", cx0, cx1, FY + 0.2, FY + 4.4, bz0, bz1, nil)
	dark(body)
	local top = bx(m, "BarTop", cx0 - 0.5, cx1 + 0.3, FY + 4.4, FY + 4.7, bz0 - 0.3, bz1 + 0.3, nil)
	mat(top, Enum.Material.Metal, Color3.fromRGB(196, 198, 200))
	local brass = bx(m, "BarKick", cx0 - 0.08, cx0, FY + 0.2, FY + 1.2, bz0, bz1, nil, { shadow = false })
	mat(brass, Enum.Material.Metal, Color3.fromRGB(176, 140, 76))
	asset(CA and CA:FindFirstChild("Espresso"), m, Vector3.new((cx0 + cx1) / 2 + 0.4, FY + 4.7, (bz0 + bz1) / 2 + 6), 1.15, math.rad(90))
	-- 뒷벽 선반 + 컵, 메뉴 칠판
	for i, y in ipairs({ FY + 7, FY + 10 }) do
		dark(bx(m, "Shelf" .. i, B.X1 - 1.6, B.X1, y, y + 0.35, bz0, bz1, nil), true)
		for z = bz0 + 1, bz1 - 1, 1.6 do
			local c = box(m, "Cup", Vector3.new(0.6, 0.7, 0.7), Vector3.new(B.X1 - 0.8, y + 0.65, z), nil, { collide = false, shadow = false })
			c.Shape = Enum.PartType.Cylinder
			c.CFrame = CFrame.new(B.X1 - 0.8, y + 0.65, z) * CFrame.Angles(0, 0, math.pi / 2)
			mat(c, Enum.Material.SmoothPlastic, (math.floor(z * 7) % 3 < 1) and Color3.fromRGB(150, 196, 200) or Color3.fromRGB(244, 240, 232))
		end
	end
	local board = bx(m, "MenuBoard", B.X1 - 0.35, B.X1, FY + 12, FY + 19, (bz0 + bz1) / 2 - 8, (bz0 + bz1) / 2 + 8, nil, { shadow = false })
	mat(board, Enum.Material.SmoothPlastic, Color3.fromRGB(28, 36, 32))
	local sg = Instance.new("SurfaceGui") sg.Face = Enum.NormalId.Left sg.PixelsPerStud = 40 sg.LightInfluence = 0.3 sg.Parent = board
	local function line(txt, y, h, font)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1 t.Size = UDim2.new(0.9, 0, h, 0) t.Position = UDim2.new(0.05, 0, y, 0)
		t.Text = txt t.TextScaled = true t.TextColor3 = Color3.fromRGB(240, 236, 226) t.Font = font or Enum.Font.GothamMedium
		t.Parent = sg
	end
	line("OHU HANOK CAFE", 0.08, 0.26, Enum.Font.GothamBlack)
	line("COFFEE  ·  TEA  ·  BOOKS  ·  RECORDS", 0.4, 0.12)
	line("SINCE 2026", 0.62, 0.1)
	for _, f in ipairs({ 0.25, 0.5, 0.75 }) do pendant(m, (cx0 + cx1) / 2, bz0 + (bz1 - bz0) * f, B.TOP - 2.6, 10) end
	-- 바 앞 높은 의자 4
	for i = 0, 3 do
		sitter("RattanStool", m, Vector3.new(cx0 - 2.2, FY + 0.2, bz0 + 5 + i * 6), 1, Vector3.new(1, 0, 0), 0.62)
	end
	-- 서쪽: 탁자 2 + 의자, 러그 (사진 1)
	rug(m, B.X0 + 9, (B.Z0 + B.Z1) / 2, 12, 26, TEX.rugRed, 0)
	for _, z in ipairs({ (B.Z0 + B.Z1) / 2 - 7, (B.Z0 + B.Z1) / 2 + 7 }) do
		table2(m, B.X0 + 9, z, 4.2, 4.2, 4.2)
		sitter("PlyChair", m, Vector3.new(B.X0 + 5, FY + 0.2, z), 1, Vector3.new(1, 0, 0), 0.48)
		sitter("PlyChair", m, Vector3.new(B.X0 + 13, FY + 0.2, z), 1, Vector3.new(-1, 0, 0), 0.48)
	end
	-- 북쪽 레코드 진열(사진 1 · 4): 낮은 장 + 레코드 상자 3
	local cab = bx(m, "RecordCabinet", B.X0 + 3, B.X0 + 15, FY + 0.2, FY + 2.4, B.Z0 + 0.3, B.Z0 + 3, nil)
	dark(cab, true)
	for i = 0, 2 do
		asset(CA and CA:FindFirstChild("RecordCrate"), m, Vector3.new(B.X0 + 5 + i * 4, FY + 2.4, B.Z0 + 1.65), 1, math.rad(180 + i * 4))
	end
	asset(CA and CA:FindFirstChild("PotTree"), m, Vector3.new(B.X0 + 3, FY + 0.2, B.Z1 - 3), 1, 0.7)
end

-- 5 북카페 C (사진 2 · 3: 동쪽 벽 가득 책장, 서쪽 창가 긴 바 + 라탄 의자, 가운데 잡지 · 책 진열대) ---------
do
	local m = folder("Interior", mC)
	-- 책장
	local bz0, bz1, by1 = C.Z0 + 2, C.Z1 - 2, C.TOP - 4
	dark(bx(m, "ShelfBack", C.X1 - 0.5, C.X1, FY, by1, bz0, bz1, nil))
	local rows = 7
	local rh = (by1 - FY - 0.5) / rows
	for i = 0, rows do
		local y = FY + i * rh
		dark(bx(m, "ShelfBoard" .. i, C.X1 - 3.2, C.X1 - 0.5, y, y + 0.45, bz0, bz1, nil), true)
		if i < rows then
			local b = box(m, "Books" .. i, Vector3.new(2.2, rh - 0.8, bz1 - bz0 - 0.4), Vector3.new(C.X1 - 1.7, y + 0.45 + (rh - 0.8) / 2, (bz0 + bz1) / 2), "paper", { collide = false, shadow = false })
			b.Color = Color3.fromRGB(60, 44, 30)
			local t = Instance.new("Texture") t.Texture = (i % 3 == 2) and TEX.records or TEX.books t.Face = Enum.NormalId.Left
			t.StudsPerTileU = 16 t.StudsPerTileV = rh - 0.8 t.OffsetStudsU = i * 5.3 t.Parent = b
			local l = Instance.new("SurfaceLight") l.Face = Enum.NormalId.Left l.Range = 4 l.Brightness = 0.6 l.Color = Color3.fromRGB(255, 220, 170) l.Angle = 120
			if i % 2 == 0 then l.Parent = b else l:Destroy() end
		end
	end
	for k = 1, 5 do
		local z = bz0 + (bz1 - bz0) * k / 6
		dark(bx(m, "ShelfSide", C.X1 - 3.2, C.X1 - 0.5, FY, by1, z - 0.25, z + 0.25, nil))
	end
	-- 창가 긴 바 (서쪽 유리 앞) + 라탄 의자
	local wz0, wz1 = C.Z0 + 2, C.Z1 - 2
	local bar = bx(m, "WindowBar", C.X0 + 0.3, C.X0 + 3.3, FY + 4.3, FY + 4.75, wz0, wz1, nil)
	dark(bar, true)
	for _, z in ipairs({ wz0 + 1, wz1 - 1 }) do dark(bx(m, "WindowBarLeg", C.X0 + 0.5, C.X0 + 1.1, FY + 0.2, FY + 4.3, z - 0.3, z + 0.3, nil)) end
	for z = wz0 + 4, wz1 - 4, 6.5 do
		if math.abs(z - (C.Z1 - 30)) > 5 then -- 열린 문 칸은 비움
			sitter("RattanStool", m, Vector3.new(C.X0 + 5.6, FY + 0.2, z), 1, Vector3.new(-1, 0, 0), 0.62)
		end
	end
	for _, f in ipairs({ 0.2, 0.5, 0.8 }) do pendant(m, C.X0 + 2.5, C.Z0 + (C.Z1 - C.Z0) * f, C.TOP - 2.6, 13) end
	-- 가운데 책 진열대 (사진 2)
	local tx = (C.X0 + C.X1) / 2 + 1
	local tbl = bx(m, "BookTable", tx - 3.5, tx + 3.5, FY + 0.2, FY + 3.4, C.Z0 + 22, C.Z1 - 22, nil)
	dark(tbl, true)
	local r = Random.new(1118)
	for z = C.Z0 + 23.5, C.Z1 - 23.5, 3.2 do
		for _, x in ipairs({ tx - 1.8, tx + 1.8 }) do
			local h = r:NextNumber(0.4, 1.4)
			local b = box(m, "BookStack", Vector3.new(2.4, h, 2.8), Vector3.new(x, FY + 3.4 + h / 2, z), nil, { collide = false })
			b.CFrame = b.CFrame * CFrame.Angles(0, r:NextNumber(-0.15, 0.15), 0)
			mat(b, Enum.Material.SmoothPlastic, Color3.fromHSV(r:NextNumber(), r:NextNumber(0.2, 0.6), r:NextNumber(0.5, 0.9)))
		end
	end
	asset(CA and CA:FindFirstChild("Monstera"), m, Vector3.new(C.X0 + 8, FY + 0.2, C.Z1 - 3), 1.2, 1.3)
end

-- 6 퍼걸러 라운지 (사진 5: 기둥 · 보 · 서까래 위 나뭇가지 지붕, 자갈 바닥, 회색 쿠션 라운지, 화분 나무, 줄 전구) --------
do
	local m = folder("Pergola")
	local PX0, PX1, PZ0, PZ1, PH = 424, 482, 292, 430, 17
	local gr = bx(m, "Gravel", PX0 - 2, PX1 + 2, 0, 0.2, PZ0 - 2, PZ1 + 2, nil, { shadow = false })
	mat(gr, Enum.Material.Pebble, Color3.fromRGB(176, 164, 146))
	local xs = { PX0, (PX0 + PX1) / 2, PX1 }
	local zs = {}
	for i = 0, 6 do table.insert(zs, PZ0 + (PZ1 - PZ0) * i / 6) end
	for _, x in ipairs(xs) do
		for _, z in ipairs(zs) do
			dark(bx(m, "Post", x - 0.7, x + 0.7, 0.2, PH, z - 0.7, z + 0.7, nil))
		end
		dark(bx(m, "BeamZ", x - 0.8, x + 0.8, PH, PH + 1.4, PZ0 - 2, PZ1 + 2, nil))
	end
	for _, z in ipairs(zs) do dark(bx(m, "BeamX", PX0 - 2, PX1 + 2, PH + 1.4, PH + 2.4, z - 0.6, z + 0.6, nil), true) end
	for z = PZ0 - 1, PZ1 + 1, 3.5 do
		local r = dark(bx(m, "Rafter", PX0 - 3, PX1 + 3, PH + 2.4, PH + 2.8, z - 0.25, z + 0.25, nil, { shadow = false }), true)
		r.CanCollide = false
	end
	local roof = bx(m, "BranchRoof", PX0 - 3, PX1 + 3, PH + 2.85, PH + 2.95, PZ0 - 2, PZ1 + 2, nil, { collide = false })
	-- 나뭇가지 판 (투명 판 위 텍스처는 안 보여서 불투명 갈색 판 + 가지 텍스처)
	roof.Transparency = 0
	roof.CastShadow = true
	roof.Material = Enum.Material.Wood
	roof.Color = Color3.fromRGB(96, 70, 46)
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
		local t = Instance.new("Texture") t.Texture = TEX.sticks t.Face = face t.StudsPerTileU = 14 t.StudsPerTileV = 14 t.Parent = roof
	end
	-- 라운지 4곳: 소파(서) · 안락의자 2(동) · 낮은 탁자
	local cxm = (PX0 + PX1) / 2
	for i, z in ipairs({ PZ0 + 14, PZ0 + 49, PZ0 + 89, PZ0 + 124 }) do
		local x = (i % 2 == 1) and (PX0 + 14) or (PX1 - 14)
		sitter("LoungeSofa", m, Vector3.new(x - 6.2, 0.2, z), 1.35, Vector3.new(1, 0, 0), 0.42, { -2.8, 0, 2.8 })
		sitter("LoungeChair", m, Vector3.new(x + 6.2, 0.2, z - 3.4), 1.1, Vector3.new(-1, 0, 0), 0.42)
		sitter("LoungeChair", m, Vector3.new(x + 6.2, 0.2, z + 3.4), 1.1, Vector3.new(-1, 0, 0), 0.42)
		local t = dark(bx(m, "LowTable", x - 2.2, x + 2.2, 1.4, 1.9, z - 4, z + 4, nil), true)
		dark(bx(m, "LowTableBase", x - 1.8, x + 1.8, 0.2, 1.4, z - 3.4, z + 3.4, nil))
		for k = -1, 1, 2 do
			local cup = box(m, "Cup", Vector3.new(0.6, 0.7, 0.7), Vector3.new(x + 0.6 * k, 2.25, z + 1.4 * k), nil, { collide = false, shadow = false })
			cup.Shape = Enum.PartType.Cylinder
			cup.CFrame = CFrame.new(x + 0.6 * k, 2.25, z + 1.4 * k) * CFrame.Angles(0, 0, math.pi / 2)
			mat(cup, Enum.Material.SmoothPlastic, Color3.fromRGB(244, 240, 232))
		end
	end
	-- 화분 나무 · 몬스테라
	local T = { { PX0 + 2.5, PZ0 + 30 }, { PX1 - 2.5, PZ0 + 68 }, { PX0 + 2.5, PZ0 + 107 }, { cxm, PZ0 + 30 }, { cxm, PZ0 + 107 } }
	for i, p in ipairs(T) do asset(CA and CA:FindFirstChild("PotTree"), m, Vector3.new(p[1], 0.2, p[2]), 1.1 + (i % 2) * 0.2, i * 1.3) end
	local Mo = { { PX1 - 3, PZ0 + 3 }, { PX0 + 3, PZ1 - 3 }, { cxm + 4, PZ0 + 68 }, { PX1 - 3, PZ1 - 3 } }
	for i, p in ipairs(Mo) do asset(CA and CA:FindFirstChild("Monstera"), m, Vector3.new(p[1], 0.2, p[2]), 1.2, i * 1.7) end
	-- 줄 전구: 바깥 두 보를 따라 지그재그 (네온 점, 빛은 몇 개만)
	local n = 0
	for _, x in ipairs({ PX0, PX1 }) do
		for z = PZ0, PZ1, 4 do
			local sag = math.sin(((z - PZ0) % 23) / 23 * math.pi) * 1.4
			local b = box(m, "Bulb", Vector3.new(0.45, 0.45, 0.45), Vector3.new(x + (x == PX0 and 1.2 or -1.2), PH - 0.4 - sag, z), nil, { collide = false, shadow = false })
			b.Shape = Enum.PartType.Ball
			mat(b, Enum.Material.Neon, Color3.fromRGB(255, 214, 150))
			n += 1
			if n % 6 == 0 then
				local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 200, 140) l.Range = 14 l.Brightness = 0.6 l.Parent = b
			end
		end
	end
end

-- 7 마당 나무 · 풀 · 판석 -----------------------------------------------------------------
do
	local m = folder("Plants")
	local function g(name, pos, scale, yaw) return asset(GA and GA:FindFirstChild(name), m, pos, scale, yaw) end
	g("Persimmon", Vector3.new(378, 0.62, 205), 1, 0.3)
	g("Persimmon", Vector3.new(378, 0.62, 395), 0.9, 1.9)
	g("Persimmon", Vector3.new(400, 0.62, 187), 0.8, 2.6)
	for i, p in ipairs({ { 377, 230 }, { 377, 260 }, { 377, 290 }, { 377, 360 }, { 377, 415 }, { 420, 187 }, { 450, 187 }, { 470, 187 }, { 536, 230 }, { 536, 300 }, { 536, 380 }, { 536, 440 } }) do
		g("Fern", Vector3.new(p[1], 0.62, p[2]), 0.9 + (i % 3) * 0.15, i * 2.1)
	end
	local fsm = GA and GA:FindFirstChild("Flagstone")
	fsm = fsm and fsm:FindFirstChildWhichIsA("MeshPart", true)
	if fsm then
		local r = Random.new(1119)
		local placed = {}
		local function free(x, z)
			if x < 384 or x > 528 or z < 194 or z > 470 then return false end
			if x > 422 and x < 484 and z > 288 and z < 434 then return false end -- 퍼걸러
			for _, b in ipairs({ A, B, C, D }) do
				if x > b.X0 - 9 and x < b.X1 + 9 and z > b.Z0 - 9 and z < b.Z1 + 9 then return false end
			end
			for _, q in ipairs(placed) do
				if (q[1] - x) ^ 2 + (q[2] - z) ^ 2 < 121 then return false end
			end
			return true
		end
		local tries = 0
		while #placed < 30 and tries < 3000 do
			tries += 1
			local x, z = r:NextNumber(LX0, LX1), r:NextNumber(LZ0, LZ1)
			if free(x, z) then
				table.insert(placed, { x, z })
				local p = fsm:Clone()
				for _, d in ipairs(p:GetChildren()) do if d:IsA("SurfaceAppearance") then d:Destroy() end end
				p.TextureID = ""
				p.Material = Enum.Material.Granite
				p.MaterialVariant = "OHU_HanokGranite"
				p.Color = Color3.fromRGB(255, 255, 255)
				local sz = r:NextNumber(3, 8.5)
				p.Size = Vector3.new(sz, r:NextNumber(0.22, 0.32), sz * r:NextNumber(0.6, 1))
				p.CFrame = CFrame.new(x, GY + 0.02, z) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0)
				p.Anchored = true p.CanCollide = false p.CastShadow = false
				p.Parent = m
			end
		end
	end
end

root.Parent = workspace
local n = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return ("HanokCafe parts %d"):format(n)
