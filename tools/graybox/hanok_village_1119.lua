-- 한옥 마을 1단계 (D-1910): 골목 판석 · 청사초롱 · 필지 대문(일각문)
-- 사용자 사진 11장(docs/04_ART/references/hanok_village_ref_01..11.webp): 북촌 골목(판석 · 돌담 · 초롱), 일각문, 꽃담.
-- Studio Edit 모드, hanok_wall_kit.lua 를 먼저 실행(_G.HanokWallKit). 여러 번 돌려도 결과가 같다.
-- Workspace.HanokVillage (체인 밖, place 전용). 담을 자른 원본은 ServerStorage.ParkedHanokBlocks.<이름>_1119 에 보관.
-- 에셋: ServerStorage.ArtAssets.HanokVillageAssets.Lantern (AI 청사초롱).
local K = _G.HanokWallKit
assert(K, "run tools/graybox/hanok_wall_kit.lua first")
local box = K.box
local SS = game:GetService("ServerStorage")
local park = SS:FindFirstChild("ParkedHanokBlocks") or Instance.new("Folder")
park.Name = "ParkedHanokBlocks"
park.Parent = SS
local VA = SS.ArtAssets:FindFirstChild("HanokVillageAssets")

local SLABS = "rbxassetid://125458671038389"

local old = workspace:FindFirstChild("HanokVillage")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "HanokVillage"
local function folder(name, parent)
	local f = Instance.new("Model") f.Name = name f.Parent = parent or root return f
end
local function bx(m, name, x0, x1, y0, y1, z0, z1, kind, opts)
	return box(m, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), kind, opts)
end

-- 1 골목 판석 (북촌 골목 사진 8) ------------------------------------------------------------
local alleys = folder("Alleys")
local ALLEYS = {
	{ 208, 225, 336, 433 }, -- 북서 필지 · 북동 필지 사이
	{ 81, 205, 435, 453 }, -- 북서 · 남서 사이
	{ 227, 352, 434, 453 }, -- 북동 · 연못 정원 사이
	{ 207, 225, 455, 647 }, -- 남서 · 연못 정원 사이
	{ 354, 371, 183, 474 }, -- 카페 서쪽
	{ 206, 227, 433, 455 }, -- 네거리
}
for i, a in ipairs(ALLEYS) do
	-- 골목을 덮은 지형 잔디(높이 2)를 비움 (담 밑까지 2씩 넉넉히)
	workspace.Terrain:FillBlock(CFrame.new((a[1] + a[2]) / 2, 1, (a[3] + a[4]) / 2), Vector3.new(a[2] - a[1] + 4, 10, a[4] - a[3] + 4), Enum.Material.Air)
	local p = bx(alleys, "Slabs" .. i, a[1], a[2], 0, 0.16, a[3], a[4], nil, { shadow = false })
	p.Material = Enum.Material.Slate
	p.Color = Color3.fromRGB(255, 255, 255)
	local t = Instance.new("Texture") t.Texture = SLABS t.Face = Enum.NormalId.Top t.StudsPerTileU = 16 t.StudsPerTileV = 16 t.Parent = p
end

-- 2 담 자르기 + 일각문 ------------------------------------------------------------------------
-- 담 Part 를 길이 방향(RightVector)으로 [a0, a1] 만큼 비우고 두 조각으로. 그 위 기와(HanokStoneWalls) 는 2.6 올림.
local function cutWall(wall, a0, a1, tag)
	local axis = wall.CFrame.RightVector
	local c = wall.Position
	local half = wall.Size.X / 2
	local function at(s) return c + axis * s end
	local s0, s1 = math.min(a0, a1), math.max(a0, a1)
	for _, seg in ipairs({ { -half, s0 }, { s1, half } }) do
		local p = wall:Clone()
		p.Size = Vector3.new(seg[2] - seg[1], wall.Size.Y, wall.Size.Z)
		p.CFrame = CFrame.fromMatrix(at((seg[1] + seg[2]) / 2), wall.CFrame.RightVector, wall.CFrame.UpVector)
		p:SetAttribute("SplitBy", "hanok_village_1119")
		p.Parent = workspace
	end
	wall.Name = tag
	wall.Parent = park
	local g0, g1 = at(s0), at(s1)
	for _, g in ipairs(workspace.HanokStoneWalls:GetChildren()) do
		local cf = g:IsA("Model") and g:GetPivot() or g.CFrame
		local rel = cf.Position - c
		local along = rel:Dot(axis)
		local across = (rel - axis * along)
		if Vector3.new(across.X, 0, across.Z).Magnitude < 2 and along > s0 - 2 and along < s1 + 2 and not g:GetAttribute("GateRaised") then
			if g:IsA("Model") then g:PivotTo(g:GetPivot() + Vector3.new(0, 2.6, 0)) else g.CFrame += Vector3.new(0, 2.6, 0) end
			g:SetAttribute("GateRaised", true)
		end
	end
	return g0, g1
end
local function findWall(p0, p1)
	-- 두 끝점이 가까운 HanokStoneWall (손으로 자른 조각 포함) 중 [p0,p1] 구간을 품는 것
	local mid = (p0 + p1) / 2
	local best
	for _, w in ipairs(workspace:GetChildren()) do
		if w.Name == "HanokStoneWall" and w:IsA("BasePart") then
			local axis = w.CFrame.RightVector
			local rel = Vector3.new(mid.X - w.Position.X, 0, mid.Z - w.Position.Z)
			local along = rel:Dot(axis)
			local across = (rel - axis * along).Magnitude
			if across < 1.5 and math.abs(along) < w.Size.X / 2 - 6 then best = w end
		end
	end
	return best
end
-- 일각문: 기둥 2 + 인방 + 문지방 + 안쪽으로 열린 문 두 짝 + 기둥 위 기와 지붕(담 기와 1개를 키워서)
local function gate(name, p0, p1, inward)
	local tag = name .. "_1119"
	if not park:FindFirstChild(tag) then
		local w = findWall(p0, p1)
		assert(w, "wall for gate " .. name .. " not found")
		local axis = w.CFrame.RightVector
		local a0 = (p0 - w.Position):Dot(axis)
		local a1 = (p1 - w.Position):Dot(axis)
		cutWall(w, a0, a1, tag)
	end
	local m = folder(name, root)
	local dir = (p1 - p0).Unit
	local width = (p1 - p0).Magnitude
	local mid = (p0 + p1) / 2
	local cf = CFrame.lookAt(mid, mid + inward) -- 앞 = 마당 안쪽
	local function part(nm, size, off, kind)
		local p = box(m, nm, size, Vector3.zero, kind)
		p.CFrame = cf * CFrame.new(off)
		return p
	end
	local H = 16.4
	part("PostL", Vector3.new(1.5, H, 1.5), Vector3.new(-width / 2 + 0.75, H / 2, 0), "woodV")
	part("PostR", Vector3.new(1.5, H, 1.5), Vector3.new(width / 2 - 0.75, H / 2, 0), "woodV")
	part("Lintel", Vector3.new(width + 1.2, 1.6, 1.8), Vector3.new(0, H - 2.4, 0), "woodH")
	part("Beam", Vector3.new(width + 3, 1.2, 2.4), Vector3.new(0, H - 0.6, 0), "woodH")
	local th = part("Threshold", Vector3.new(width, 0.45, 2.2), Vector3.new(0, 0.22, 0), "stone")
	th.Color = Color3.fromRGB(222, 218, 210)
	for _, sgn in ipairs({ -1, 1 }) do
		local leafW = width / 2 - 1
		local p = part("DoorLeaf", Vector3.new(0.45, H - 4.2, leafW), Vector3.zero, "woodH")
		p.CFrame = cf * CFrame.new(sgn * (width / 2 - 1.75), (H - 4.2) / 2 + 0.5, -(leafW / 2 + 0.9))
		p.Color = Color3.fromRGB(230, 196, 150)
		local ring = box(m, "Ring", Vector3.new(0.1, 0.5, 0.5), Vector3.zero, "iron", { collide = false, shadow = false })
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = p.CFrame * CFrame.new(0.3, 0, -leafW / 2 + 1)
	end
	-- 작은 기와 지붕: 담 기와 모듈(GiwaCoping) 하나를 문 폭만큼 늘려 기둥 위에
	local src
	for _, g in ipairs(workspace.HanokStoneWalls:GetChildren()) do
		if g.Name == "GiwaCoping" then src = g break end
	end
	if src then
		local r = src:Clone()
		local s = (width + 6) / math.max(r.Size.X, 1)
		if r:IsA("BasePart") then
			r.Size = Vector3.new(r.Size.X * s, r.Size.Y * 1.6, r.Size.Z * 1.5)
			r.CFrame = CFrame.fromMatrix(mid + Vector3.new(0, H + r.Size.Y / 2 - 0.2, 0), dir, Vector3.yAxis)
			r.Anchored = true
			r.CanCollide = false
		end
		r.Name = "GateRoof"
		r.Parent = m
	end
	return m
end
local gates = folder("Gates")
gate("GateA", Vector3.new(150, 0, 434), Vector3.new(162, 0, 434), Vector3.new(0, 0, -1)).Parent = gates -- 북서 필지 남쪽 담
gate("GateB", Vector3.new(227, 0, 378), Vector3.new(227, 0, 390), Vector3.new(1, 0, 0)).Parent = gates -- 북동 필지 서쪽 담
gate("GateC", Vector3.new(120, 0, 454), Vector3.new(132, 0, 454), Vector3.new(0, 0, 1)).Parent = gates -- 남서 필지 북쪽 담

-- 3 청사초롱: 담 위 나무 팔에 매달기, 골목 따라 양쪽 번갈아 ---------------------------------------
local lanterns = folder("Lanterns")
local LSRC = VA and VA:FindFirstChild("Lantern")
local nLight = 0
local function lantern(wallPos, out)
	-- wallPos: 담 윗면 가운데(y 13.8), out: 골목 쪽 방향
	local arm = box(lanterns, "LanternArm", Vector3.new(0.35, 0.35, 3.2), Vector3.zero, "woodH", { collide = false, shadow = false })
	local base = wallPos + Vector3.new(0, 0.6, 0)
	arm.CFrame = CFrame.lookAt(base + out * 1.4, base + out * 3)
	local hang = base + out * 2.8
	local cord = box(lanterns, "LanternCord", Vector3.new(0.06, 1.2, 0.06), hang - Vector3.new(0, 0.6, 0), "iron", { collide = false, shadow = false })
	cord.CanQuery = false
	if LSRC then
		local m = LSRC:Clone()
		m:ScaleTo(m:GetScale() * 1.4)
		local cf, s = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + (hang - Vector3.new(0, 1.2 + s.Y / 2, 0) - cf.Position))
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CastShadow = false end
		end
		m.Parent = lanterns
		nLight += 1
		if nLight % 2 == 0 then
			local mp = m:FindFirstChildWhichIsA("BasePart", true)
			local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 190, 150) l.Range = 12 l.Brightness = 0.7 l.Parent = mp
		end
	end
end
-- 골목마다 (담 선, 방향, 시작, 끝)
local RUNS = {
	{ "x", 207, 1, 340, 430 }, { "x", 227, -1, 348, 428 },
	{ "z", 434, 1, 86, 200 }, { "z", 454, -1, 92, 200 },
	{ "z", 433, 1, 232, 348 }, { "z", 454, -1, 256, 348 },
	{ "x", 206, 1, 460, 642 }, { "x", 226, -1, 466, 642 },
	{ "x", 353, 1, 190, 470 }, { "x", 372, -1, 196, 316 }, { "x", 372, -1, 340, 470 },
}
for _, r in ipairs(RUNS) do
	local axis, line, sgn, a0, a1 = r[1], r[2], r[3], r[4], r[5]
	for a = a0, a1, 22 do
		local pos = axis == "x" and Vector3.new(line, 13.8, a) or Vector3.new(a, 13.8, line)
		local out = axis == "x" and Vector3.new(sgn, 0, 0) or Vector3.new(0, 0, sgn)
		lantern(pos, out)
	end
end

-- 4 공통 도구 (2단계~) -------------------------------------------------------------------
local function place(src, parent, pos, scale, yaw)
	if not src then return nil end
	local m = src:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw or 0, 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (pos + Vector3.new(0, s.Y / 2, 0) - cf.Position))
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
	m.Parent = parent
	return m, s
end
local function blockAt(x, z)
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Part" and (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(x, 0, z)).Magnitude < 3 then
			local cf, s = p.CFrame, p.Size
			local hx = math.abs(cf.RightVector.X) > 0.5
			local SX, SZ = hx and s.X or s.Z, hx and s.Z or s.X
			return { X0 = cf.X - SX / 2, X1 = cf.X + SX / 2, Z0 = cf.Z - SZ / 2, Z1 = cf.Z + SZ / 2, TOP = cf.Y + s.Y / 2, cx = cf.X, cz = cf.Z }
		end
	end
end
local function mat(p, material, color) p.Material = material p.Color = color return p end
local STN = Color3.fromRGB(222, 218, 210)
-- 필지 마당: 지형 잔디(장식 풀까지)를 아래 칸부터 비우고 돌 바닥
local function yard(m, x0, x1, z0, z1)
	workspace.Terrain:FillBlock(CFrame.new((x0 + x1) / 2, 1, (z0 + z1) / 2), Vector3.new(x1 - x0 + 2, 10, z1 - z0 + 2), Enum.Material.Air)
	local p = bx(m, "Yard", x0, x1, 0, 0.14, z0, z1, nil, { shadow = false })
	p.Material = Enum.Material.Slate p.MaterialVariant = "OHU_HanokYard" p.Color = Color3.fromRGB(200, 200, 200)
	return p
end
-- 2층 한옥의 아래 처마: 네 면에 기와 경사판(hv_giwa) + 막새 줄 + 벽 쪽 띠
local GIWA = "rbxassetid://101329134095096"
local function skirt(m, b, y, out, slope, off)
	local sides = {
		{ Vector3.new((b.X0 + b.X1) / 2, y, b.Z0 - off), Vector3.new(0, 0, -1), b.X1 - b.X0 },
		{ Vector3.new((b.X0 + b.X1) / 2, y, b.Z1 + off), Vector3.new(0, 0, 1), b.X1 - b.X0 },
		{ Vector3.new(b.X0 - off, y, (b.Z0 + b.Z1) / 2), Vector3.new(-1, 0, 0), b.Z1 - b.Z0 },
		{ Vector3.new(b.X1 + off, y, (b.Z0 + b.Z1) / 2), Vector3.new(1, 0, 0), b.Z1 - b.Z0 },
	}
	for _, sd in ipairs(sides) do
		local edge, dir, len = sd[1], sd[2], sd[3] + 2 * (out + off)
		local frame = CFrame.lookAt(edge, edge + dir)
		local plane = box(m, "EaveTiles", Vector3.new(len, 0.6, out), Vector3.zero, nil, { collide = false })
		plane.CFrame = frame * CFrame.Angles(-math.rad(slope), 0, 0) * CFrame.new(0, 0, -out / 2)
		mat(plane, Enum.Material.Slate, Color3.fromRGB(110, 112, 118))
		local t = Instance.new("Texture") t.Texture = GIWA t.Face = Enum.NormalId.Top t.StudsPerTileU = 5 t.StudsPerTileV = out t.Parent = plane
		local under = box(m, "EaveUnder", Vector3.new(len, 0.3, out), Vector3.zero, "woodH", { collide = false, shadow = false })
		under.CFrame = plane.CFrame * CFrame.new(0, -0.45, 0)
		local cap = box(m, "EaveCaps", Vector3.new(len, 0.75, 0.75), Vector3.zero, nil, { collide = false, shadow = false })
		cap.Shape = Enum.PartType.Cylinder
		cap.CFrame = plane.CFrame * CFrame.new(0, 0.15, -out / 2)
		mat(cap, Enum.Material.Slate, Color3.fromRGB(196, 196, 194))
		local ridge = box(m, "EaveRidge", Vector3.new(len, 1, 1.4), Vector3.zero, nil, { collide = false })
		ridge.CFrame = frame * CFrame.new(0, 0.4, -0.5)
		mat(ridge, Enum.Material.Slate, Color3.fromRGB(70, 72, 78))
	end
end

-- 5 2단계 (D-1911): 북서 필지 2층 한옥 (사진 1, 은평한옥마을). 블록은 그대로, 1층 벽 · 아래 처마 · 2층 벽, 지붕은 그대로
do
	local m = folder("TwoStoryHanok")
	local b = blockAt(138, 374)
	if b then
		yard(m, 81, 206, 337, 433)
		local FY = 3
		mat(bx(m, "Gidan", b.X0 - 4, b.X1 + 4, 0, FY, b.Z0 - 4, b.Z1 + 4, "stone"), Enum.Material.Slate, STN).MaterialVariant = "OHU_HanokPlinth"
		bx(m, "Step1", b.cx - 7, b.cx + 7, 0, 1, b.Z1 + 4, b.Z1 + 7.4, "stone").Color = STN
		bx(m, "Step2", b.cx - 7, b.cx + 7, 0, 2, b.Z1 + 4, b.Z1 + 5.7, "stone").Color = STN
		local Y2 = 20.6
		local H1, H2 = Y2 - FY - 0.6, b.TOP - Y2
		local function v(x, y, z) return Vector3.new(x, y, z) end
		local W, D = "Wall", "WallWindow"
		K.face(m, v(b.X0, FY, b.Z0), v(b.X1, FY, b.Z0), Vector3.new(0, 0, -1), { W, D, D, W }, H1)
		K.face(m, v(b.X1, FY, b.Z0), v(b.X1, FY, b.Z1), Vector3.new(1, 0, 0), { D, W }, H1)
		K.face(m, v(b.X1, FY, b.Z1), v(b.X0, FY, b.Z1), Vector3.new(0, 0, 1), { D, "DoorTtisal", "DoorTtisal", D }, H1)
		K.face(m, v(b.X0, FY, b.Z1), v(b.X0, FY, b.Z0), Vector3.new(-1, 0, 0), { W, D }, H1)
		skirt(m, b, Y2 - 0.1, 7, 24, 2.6)
		K.face(m, v(b.X0, Y2, b.Z0), v(b.X1, Y2, b.Z0), Vector3.new(0, 0, -1), { D, D, D, D }, H2)
		K.face(m, v(b.X1, Y2, b.Z0), v(b.X1, Y2, b.Z1), Vector3.new(1, 0, 0), { D, D }, H2)
		K.face(m, v(b.X1, Y2, b.Z1), v(b.X0, Y2, b.Z1), Vector3.new(0, 0, 1), { D, D, D, D }, H2)
		K.face(m, v(b.X0, Y2, b.Z1), v(b.X0, Y2, b.Z0), Vector3.new(-1, 0, 0), { D, D }, H2)
		place(VA and VA:FindFirstChild("Topiary"), m, Vector3.new(146, 0.14, 430), 1.2, 0)
		place(VA and VA:FindFirstChild("Topiary"), m, Vector3.new(166, 0.14, 430), 1.2, 1)
		place(VA and VA:FindFirstChild("RoseBush"), m, Vector3.new(178, 9, 432), 1.1, 0)
	end
end
local function dark(p, horizontal)
	p.Material = Enum.Material.Wood p.MaterialVariant = horizontal and "OHU_HanokDarkH" or "OHU_HanokDarkV" p.Color = Color3.fromRGB(255, 255, 255)
	return p
end
local function seat(parent, pos, look)
	local s = Instance.new("Seat") s.Name = "VillageSeat" s.Anchored = true s.Transparency = 1 s.CanCollide = false
	s.Size = Vector3.new(2, 0.3, 2) s.CFrame = CFrame.lookAt(pos, pos + look) s.Parent = parent
	return s
end
local GA = SS.ArtAssets:FindFirstChild("HanokGardenAssets")

-- 6 3단계 (D-1912): 북동 필지 찻집 (사진 3 들어열개 다실 + 사진 5 장독대 + 사진 10 감나무 아래 의자)
do
	local m = folder("TeaHouse")
	local pk = park:FindFirstChild("Part_315_385")
	if not pk then
		for _, p in ipairs(workspace:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Part" and (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(315, 0, 385)).Magnitude < 3 then pk = p end
		end
		if pk then pk.Name = "Part_315_385" pk.Parent = park end
	end
	local cf, s = pk.CFrame, pk.Size
	local hx = math.abs(cf.RightVector.X) > 0.5
	local SX, SZ = hx and s.X or s.Z, hx and s.Z or s.X
	local b = { X0 = cf.X - SX / 2, X1 = cf.X + SX / 2, Z0 = cf.Z - SZ / 2, Z1 = cf.Z + SZ / 2, TOP = cf.Y + s.Y / 2, cx = cf.X, cz = cf.Z }
	yard(m, 228, 352, 336, 432)
	local FY = 3
	mat(bx(m, "Gidan", b.X0 - 4, b.X1 + 4, 0, FY, b.Z0 - 4, b.Z1 + 4, "stone"), Enum.Material.Slate, STN).MaterialVariant = "OHU_HanokPlinth"
	bx(m, "Step1", b.X0 - 7.4, b.X0 - 4, 0, 1, b.cz - 10, b.cz + 10, "stone").Color = STN
	bx(m, "Step2", b.X0 - 5.7, b.X0 - 4, 0, 2, b.cz - 10, b.cz + 10, "stone").Color = STN
	local w = Instance.new("WedgePart") w.Name = "Ramp" w.Anchored = true w.Transparency = 1 w.Size = Vector3.new(20, FY, 3.4)
	local rp = Vector3.new(b.X0 - 5.7, FY / 2, b.cz) w.CFrame = CFrame.lookAt(rp, rp - Vector3.new(1, 0, 0)) w.Parent = m
	local H = b.TOP - FY
	local function v(x, z) return Vector3.new(x, FY, z) end
	K.face(m, v(b.X0, b.Z0), v(b.X1, b.Z0), Vector3.new(0, 0, -1), { "WallWindow", "Wall" }, H)
	K.face(m, v(b.X1, b.Z0), v(b.X1, b.Z1), Vector3.new(1, 0, 0), { "Wall", "WallWindow", "WallWindow", "Wall" }, H)
	K.face(m, v(b.X1, b.Z1), v(b.X0, b.Z1), Vector3.new(0, 0, 1), { "Wall", "WallWindow" }, H)
	local Wb = K.face(m, v(b.X0, b.Z1), v(b.X0, b.Z0), Vector3.new(-1, 0, 0), { "WallBitsal", "Open", "Open", "WallBitsal" }, H)
	dark(bx(m, "Floor", b.X0, b.X1, FY, FY + 0.2, b.Z0, b.Z1, nil), true).Color = Color3.fromRGB(255, 236, 210)
	bx(m, "Ceiling", b.X0, b.X1, b.TOP - 0.6, b.TOP, b.Z0, b.Z1, "woodH")
	for z = b.Z0 + 3, b.Z1 - 3, 3.2 do bx(m, "Rafter", b.X0, b.X1, b.TOP - 1.4, b.TOP - 0.6, z - 0.45, z + 0.45, "woodH") end
	-- 들어열개: 열린 두 칸 위에 문짝을 들쇠로 걸어 올린 모습
	local L = H * 0.70 + FY
	for _, zc in ipairs({ b.Z1 - (Wb + 2.6) - Wb / 2, b.Z1 - 2 * (Wb + 2.6) - Wb / 2 }) do
		for _, side in ipairs({ -1, 1 }) do
			local panel = box(m, "LiftedDoor", Vector3.new(4.2, 0.35, Wb / 2 - 0.6), Vector3.zero, "paper", { collide = false })
			panel.CFrame = CFrame.new(b.X0 + 2.6, L + 0.8, zc + side * Wb / 4) * CFrame.Angles(0, 0, math.rad(-8))
			for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
				local t = Instance.new("Texture") t.Texture = "rbxassetid://114067470834518" t.Face = face t.StudsPerTileU = 5.2 t.StudsPerTileV = 5.2 t.Parent = panel
			end
			local fr = box(m, "LiftedDoorFrame", Vector3.new(4.4, 0.3, Wb / 2 - 0.4), Vector3.zero, "woodH", { collide = false, shadow = false })
			fr.CFrame = panel.CFrame * CFrame.new(0, 0.05, 0)
			for _, dz in ipairs({ -1, 1 }) do
				local hk = box(m, "Deulsoe", Vector3.new(0.12, b.TOP - 1.4 - (L + 0.8), 0.12), Vector3.new(b.X0 + 3.8, (b.TOP - 1.4 + L + 0.8) / 2, zc + side * Wb / 4 + dz * (Wb / 4 - 1)), "iron", { collide = false, shadow = false })
				hk.CanQuery = false
			end
		end
	end
	-- 좌식 찻상 + 다기(정원 다도세트 메시) + 방석 3 (앉기, 창밖을 보고)
	local tx = b.X0 + 8
	dark(bx(m, "TeaTableTop", tx - 2.6, tx + 2.6, FY + 1.6, FY + 2.2, b.cz - 11, b.cz + 11, nil), true)
	dark(bx(m, "TeaTableLegA", tx - 2.2, tx + 2.2, FY + 0.2, FY + 1.6, b.cz - 10, b.cz - 8.6, nil))
	dark(bx(m, "TeaTableLegB", tx - 2.2, tx + 2.2, FY + 0.2, FY + 1.6, b.cz + 8.6, b.cz + 10, nil))
	local function ware(name, pos, scale, yaw)
		return place(GA and GA:FindFirstChild(name), m, pos, scale, yaw)
	end
	ware("TeaKyusu", Vector3.new(tx, FY + 2.2, b.cz - 1.2), 1.3, 1)
	ware("TeaCup", Vector3.new(tx - 0.6, FY + 2.2, b.cz + 1.2), 1.2, 0.4)
	ware("TeaCup", Vector3.new(tx + 0.8, FY + 2.2, b.cz + 1.6), 1.2, 2)
	for _, z in ipairs({ b.cz - 7, b.cz, b.cz + 7 }) do
		local c = bx(m, "Cushion", tx + 4, tx + 7, FY + 0.2, FY + 0.65, z - 1.5, z + 1.5, nil)
		mat(c, Enum.Material.Fabric, Color3.fromRGB(226, 220, 206))
		seat(m, Vector3.new(tx + 5.5, FY + 0.7, z), Vector3.new(-1, 0, 0))
	end
	-- 장독대 (사진 5): 담 모퉁이 돌단 위 옹기 26 (큰 14 · 작은 12)
	local jx0, jx1, jz0, jz1 = 230, 262, 338, 356
	mat(bx(m, "JangdokDae", jx0, jx1, 0, 1.2, jz0, jz1, "stone"), Enum.Material.Slate, STN).MaterialVariant = "OHU_HanokPlinth"
	local r = Random.new(1911)
	local placed = {}
	for i = 1, 26 do
		local big = i <= 14
		for _ = 1, 20 do
			local x, z = r:NextNumber(jx0 + 2, jx1 - 2), r:NextNumber(jz0 + 2, jz1 - 2)
			local ok = true
			for _, q in ipairs(placed) do if (q[1] - x) ^ 2 + (q[2] - z) ^ 2 < (big and 9 or 5) then ok = false end end
			if ok then
				table.insert(placed, { x, z })
				place(VA and VA:FindFirstChild(big and "Onggi" or "OnggiSmall"), m, Vector3.new(x, 1.2, z), big and r:NextNumber(0.9, 1.3) or r:NextNumber(0.8, 1.2), r:NextNumber(0, 6.28))
				break
			end
		end
	end
	-- 감나무 + 의자 두 개 + 작은 탁자 (사진 10)
	place(VA and VA:FindFirstChild("PersimmonAutumn"), m, Vector3.new(252, 0.14, 408), 0.9, 0.6)
	local ch = SS.ArtAssets:FindFirstChild("HanokCafeAssets") and SS.ArtAssets.HanokCafeAssets:FindFirstChild("PlyChair")
	for _, c in ipairs({ { 262, 398, Vector3.new(0, 0, 1) }, { 270, 404, Vector3.new(-1, 0, 0) } }) do
		local cm, cs = place(ch, m, Vector3.new(c[1], 0.14, c[2]), 1, math.atan2(-c[3].X, -c[3].Z))
		if cm then seat(m, Vector3.new(c[1], 0.14 + cs.Y * 0.48, c[2]), c[3]) end
	end
	dark(bx(m, "SideTable", 262.5, 266.5, 2.6, 2.9, 402, 406, nil), true)
	dark(bx(m, "SideTableLeg", 264.2, 264.8, 0.14, 2.6, 403.7, 404.3, nil))
	place(VA and VA:FindFirstChild("OnggiSmall"), m, Vector3.new(264.5, 2.9, 404), 0.4, 0)
end

root.Parent = workspace
local n = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return ("HanokVillage parts %d, lanterns %d"):format(n, nLight)
