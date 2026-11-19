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
	workspace.Terrain:FillBlock(CFrame.new((a[1] + a[2]) / 2, 3, (a[3] + a[4]) / 2), Vector3.new(a[2] - a[1] + 4, 6, a[4] - a[3] + 4), Enum.Material.Air)
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

root.Parent = workspace
local n = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
return ("HanokVillage parts %d, lanterns lit %d"):format(n, math.floor(nLight / 2))
