-- 한옥 벽 키트 (D-1740): 한 칸(한 면)씩 만든 벽 모듈. 이어 붙여 한옥 벽을 조립한다.
-- Studio 명령 바 / MCP (Edit 모드). 여러 번 돌려도 결과가 같다.
--   MODE (첫 인자, 기본 "kit"): "kit" ServerStorage.ArtAssets.HanokWallKit 에 모듈(기본 W 14, H 32.2)을 만든다.
--   MODE "preview" : 위 + Workspace.HanokWallKitPreview (맵 밖 x 1800) 에 견본 벽 한 줄(번호표).
--   MODE "clear"   : 견본만 지운다.
-- 모듈 규칙 (조립용)
--   피벗 = 벽 "뒷면" 아래 가운데. 앞(LookVector, -Z) 쪽으로 두께 T 만큼 나온다.
--   → 건물 블록 면 위 한 점에 앞을 바깥으로 놓으면 블록에 딱 붙는다.
--   칸 너비 W 는 기둥 제외. 기둥(Post)은 따로: 칸 - 기둥 - 칸 ... 순서로 놓는다(기둥 폭 P).
--   _G.HanokWallKit.make(kind, W, H) 로 아무 크기나 새로 만들 수 있다(맵 배치 스크립트가 씀).
local MODE = ... or "kit" -- loadstring(src)("preview")

local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local TEX = {
	pineV = "rbxassetid://115576550363672", -- 세로 결 (기둥, 문울거미 세로)
	pineH = "rbxassetid://110895737913533", -- 가로 결 (인방, 창방, 머름)
	plaster = "rbxassetid://73293187055221",
	ttisal = "rbxassetid://96464883424808", -- 띠살
	jeongja = "rbxassetid://114067470834518", -- 정자살 (4칸 한 장, 반복)
	bitsal = "rbxassetid://134430880683745", -- 빗살 (반복)
}

local function variant(name, base, map, studs)
	local v = MaterialService:FindFirstChild(name)
	if not v then
		v = Instance.new("MaterialVariant")
		v.Name = name
		v.Parent = MaterialService
	end
	v.BaseMaterial = base
	v.ColorMap = map
	v.StudsPerTile = studs
	return v
end
variant("OHU_HanokPineV", Enum.Material.Wood, TEX.pineV, 7)
variant("OHU_HanokPineH", Enum.Material.Wood, TEX.pineH, 7)
variant("OHU_HanokPlaster", Enum.Material.Plaster, TEX.plaster, 18)

local T = 1.2 -- 벽 두께
local P = 2.6 -- 기둥 폭
local WOOD = Color3.fromRGB(240, 205, 155) -- 소나무 결 위에 곱해지는 색

local K = {}
_G.HanokWallKit = K
K.T, K.P = T, P

local function box(model, name, size, pos, kind, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "woodV" or kind == "woodH" then
		p.Material = Enum.Material.Wood
		p.MaterialVariant = kind == "woodV" and "OHU_HanokPineV" or "OHU_HanokPineH"
		p.Color = WOOD
	elseif kind == "plaster" then
		p.Material = Enum.Material.Plaster
		p.MaterialVariant = "OHU_HanokPlaster"
		p.Color = Color3.fromRGB(255, 255, 255)
	elseif kind == "stone" then
		p.Material = Enum.Material.Granite
		p.Color = Color3.fromRGB(196, 192, 182)
	elseif kind == "iron" then
		p.Material = Enum.Material.Metal
		p.Color = Color3.fromRGB(38, 36, 34)
	elseif kind == "glass" then
		p.Material = Enum.Material.Glass
		p.Color = Color3.fromRGB(196, 214, 216)
		p.Transparency = 0.72
		p.Reflectance = 0.08
	elseif kind == "paper" then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(238, 230, 208)
	end
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow ~= false
	p.Parent = model
	return p
end

-- 띠살은 한 짝에 한 장(판 크기), 정자살 · 빗살은 TILE 스터드마다 반복
local TILE = { [TEX.jeongja] = 5.2, [TEX.bitsal] = 5 }
local function lattice(part, tex)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local t = Instance.new("Texture")
		t.Texture = tex
		t.Face = face
		t.StudsPerTileU = TILE[tex] or part.Size.X
		t.StudsPerTileV = TILE[tex] or part.Size.Y
		t.Parent = part
	end
end

-- z: 벽 가운데 면 = -T/2. 뒷면 0, 앞면 -T.
local ZC = -T / 2

-- 가로 부재 (인방 등): 벽보다 조금 두껍게(양쪽 0.15 튀어나옴)
local function beam(m, name, W, y0, y1)
	return box(m, name, Vector3.new(W, y1 - y0, T + 0.3), Vector3.new(0, (y0 + y1) / 2, ZC), "woodH")
end
-- 회벽 면: 양쪽 0.2 들어감
local function plaster(m, name, x0, x1, y0, y1)
	if y1 - y0 < 0.05 or x1 - x0 < 0.05 then
		return
	end
	return box(m, name, Vector3.new(x1 - x0, y1 - y0, T - 0.4), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, ZC), "plaster", { shadow = false })
end

-- 창호 짝 n개: 울거미(세로 n+1, 위/아래 가로) + 살 판(텍스처)
local function leaves(m, prefix, x0, x1, y0, y1, n, tex)
	local s, r = 0.42, 0.48
	local w = x1 - x0
	box(m, prefix .. "RailTop", Vector3.new(w, r, 0.9), Vector3.new((x0 + x1) / 2, y1 - r / 2, ZC), "woodH")
	box(m, prefix .. "RailBot", Vector3.new(w, r, 0.9), Vector3.new((x0 + x1) / 2, y0 + r / 2, ZC), "woodH")
	local leafW = (w - s * (n + 1)) / n
	for i = 0, n do
		local x = x0 + s / 2 + i * (leafW + s)
		box(m, prefix .. "Stile" .. i, Vector3.new(s, y1 - y0 - 2 * r, 0.9), Vector3.new(x, (y0 + y1) / 2, ZC), "woodV", { shadow = false })
	end
	for i = 1, n do
		local x = x0 + s + (i - 1) * (leafW + s) + leafW / 2
		local pane = box(m, prefix .. "Pane" .. i, Vector3.new(leafW, y1 - y0 - 2 * r, 0.3), Vector3.new(x, (y0 + y1) / 2, ZC), "paper", { shadow = false })
		lattice(pane, tex)
	end
	return leafW
end

-- 창틀(문선) 네 변
local function frame(m, prefix, x0, x1, y0, y1)
	local f = 0.5
	box(m, prefix .. "FrameL", Vector3.new(f, y1 - y0, T + 0.2), Vector3.new(x0 - f / 2, (y0 + y1) / 2, ZC), "woodV", { shadow = false })
	box(m, prefix .. "FrameR", Vector3.new(f, y1 - y0, T + 0.2), Vector3.new(x1 + f / 2, (y0 + y1) / 2, ZC), "woodV", { shadow = false })
	box(m, prefix .. "FrameT", Vector3.new(x1 - x0 + 2 * f, f, T + 0.2), Vector3.new((x0 + x1) / 2, y1 + f / 2, ZC), "woodH", { shadow = false })
	box(m, prefix .. "FrameB", Vector3.new(x1 - x0 + 2 * f, f, T + 0.2), Vector3.new((x0 + x1) / 2, y0 - f / 2, ZC), "woodH", { shadow = false })
end

local function ring(m, x, y)
	for _, z in ipairs({ -T / 2 - 0.5, -T / 2 + 0.5 }) do
		local p = box(m, "Ring", Vector3.new(0.12, 0.7, 0.7), Vector3.new(x, y, z), "iron", { collide = false, shadow = false })
		p.Shape = Enum.PartType.Cylinder
	end
end

-- 높이 비율 (블록 높이 32.2 기준, 사진 1 · 3 · 5)
local function levels(H)
	local L = {}
	L.sill = 0.05 * H -- 하방
	L.midY, L.midH = 0.36 * H, 0.05 * H -- 중인방
	L.headY, L.headH = 0.70 * H, 0.05 * H -- 상인방
	L.top0 = 0.91 * H -- 창방 아래
	return L
end

-- 위쪽 공통: 상인방 + 소벽(회벽) + 창방
local function upper(m, W, H, L)
	beam(m, "Sanginbang", W, L.headY - L.headH / 2, L.headY + L.headH / 2)
	plaster(m, "Sobyeok", -W / 2, W / 2, L.headY + L.headH / 2, L.top0)
	beam(m, "Changbang", W, L.top0, H)
end

local BUILD = {}

-- 1 회벽: 하방 · 중인방 · 상인방 · 창방 사이 흰 회벽 (사진 1, 3)
function BUILD.Wall(m, W, H, L)
	beam(m, "Haban", W, 0, L.sill)
	plaster(m, "PlasterLow", -W / 2, W / 2, L.sill, L.midY - L.midH / 2)
	beam(m, "Junginbang", W, L.midY - L.midH / 2, L.midY + L.midH / 2)
	plaster(m, "PlasterMid", -W / 2, W / 2, L.midY + L.midH / 2, L.headY - L.headH / 2)
	upper(m, W, H, L)
end

-- 2 회벽 + 정자살 창 두 짝 (사진 1 왼쪽 안, 사진 3 오른쪽)
function BUILD.WallWindow(m, W, H, L)
	beam(m, "Haban", W, 0, L.sill)
	plaster(m, "PlasterLow", -W / 2, W / 2, L.sill, L.midY - L.midH / 2)
	beam(m, "Junginbang", W, L.midY - L.midH / 2, L.midY + L.midH / 2)
	local y0, y1 = L.midY + L.midH / 2, L.headY - L.headH / 2
	local ww = math.min(W * 0.5, (y1 - y0) * 1.1)
	local wy0 = y0 + (y1 - y0) * 0.18
	local wy1 = y1 - (y1 - y0) * 0.12
	plaster(m, "PlasterL", -W / 2, -ww / 2 - 0.5, y0, y1)
	plaster(m, "PlasterR", ww / 2 + 0.5, W / 2, y0, y1)
	plaster(m, "PlasterUnder", -ww / 2 - 0.5, ww / 2 + 0.5, y0, wy0 - 0.5)
	plaster(m, "PlasterOver", -ww / 2 - 0.5, ww / 2 + 0.5, wy1 + 0.5, y1)
	frame(m, "Win", -ww / 2, ww / 2, wy0, wy1)
	leaves(m, "Win", -ww / 2, ww / 2, wy0, wy1, 2, TEX.jeongja)
	upper(m, W, H, L)
end

-- 3 머름창: 아래 머름(널 + 동자) 위에 정자살 창 네 짝 (사진 2 왼쪽, 사진 5 안쪽)
function BUILD.MeoreumWindow(m, W, H, L)
	beam(m, "Haban", W, 0, L.sill)
	local my1 = 0.27 * H
	box(m, "MeoreumBoard", Vector3.new(W, my1 - L.sill, T - 0.2), Vector3.new(0, (L.sill + my1) / 2, ZC), "woodH", { shadow = false })
	local n = W >= 10 and 4 or 3
	for i = 0, n do
		local x = -W / 2 + W * i / n
		local wq = 0.7
		if i == 0 then
			x += wq / 2
		elseif i == n then
			x -= wq / 2
		end
		box(m, "Dongja" .. i, Vector3.new(wq, my1 - L.sill, T + 0.1), Vector3.new(x, (L.sill + my1) / 2, ZC), "woodV", { collide = false, shadow = false })
	end
	local rh = 0.03 * H
	beam(m, "Meoreumdae", W, my1, my1 + rh)
	leaves(m, "Win", -W / 2, W / 2, my1 + rh, L.headY - L.headH / 2, W >= 10 and 4 or 2, TEX.jeongja)
	upper(m, W, H, L)
end

-- 4 띠살문 두 짝 + 문고리 (사진 1 왼쪽 문, 사진 5)
function BUILD.DoorTtisal(m, W, H, L)
	beam(m, "Haban", W, 0, L.sill)
	local y1 = L.headY - L.headH / 2
	local leafW = leaves(m, "Door", -W / 2, W / 2, L.sill, y1, 2, TEX.ttisal)
	ring(m, -0.42 / 2 - 0.5, L.sill + (y1 - L.sill) * 0.45)
	ring(m, 0.42 / 2 + 0.5, L.sill + (y1 - L.sill) * 0.45)
	upper(m, W, H, L)
end

-- 5 분합문 네 짝, 정자살 (사진 2 오른쪽)
function BUILD.DoorBunhap(m, W, H, L)
	beam(m, "Haban", W, 0, L.sill)
	local y1 = L.headY - L.headH / 2
	leaves(m, "Door", -W / 2, W / 2, L.sill, y1, 4, TEX.jeongja)
	ring(m, -0.42 / 2 - 0.5, L.sill + (y1 - L.sill) * 0.45)
	ring(m, 0.42 / 2 + 0.5, L.sill + (y1 - L.sill) * 0.45)
	upper(m, W, H, L)
end

-- 6 빗살창 두 짝 (사진 5 양옆): 회벽 + 마름모 살창
function BUILD.WallBitsal(m, W, H, L)
	beam(m, "Haban", W, 0, L.sill)
	local my1 = 0.27 * H
	plaster(m, "PlasterLow", -W / 2, W / 2, L.sill, my1)
	local rh = 0.03 * H
	beam(m, "Meoreumdae", W, my1, my1 + rh)
	local ww = W * 0.62
	local y1 = L.headY - L.headH / 2
	plaster(m, "PlasterL", -W / 2, -ww / 2 - 0.5, my1 + rh, y1)
	plaster(m, "PlasterR", ww / 2 + 0.5, W / 2, my1 + rh, y1)
	frame(m, "Win", -ww / 2, ww / 2, my1 + rh + 0.5, y1 - 0.5)
	plaster(m, "PlasterOver", -ww / 2 - 0.5, ww / 2 + 0.5, y1 - 0.5, y1)
	leaves(m, "Win", -ww / 2, ww / 2, my1 + rh + 0.5, y1 - 0.5, 2, TEX.bitsal)
	upper(m, W, H, L)
end

-- 8 유리 미닫이 (연못 정원 사진, D-1741): 나무틀 통유리 두 짝 + 위 상인방 · 소벽 · 창방.
--   opt.open = true 이면 오른쪽 짝이 왼쪽 짝 뒤(안쪽)로 밀려 반이 열린다(사람이 지나감).
local function glassLeaf(m, name, x0, x1, y0, y1, z)
	local f = 0.55
	local w = x1 - x0
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	box(m, name .. "Top", Vector3.new(w, f, 0.5), Vector3.new(cx, y1 - f / 2, z), "woodH", { shadow = false })
	box(m, name .. "Bot", Vector3.new(w, f * 1.6, 0.5), Vector3.new(cx, y0 + f * 0.8, z), "woodH", { shadow = false })
	box(m, name .. "L", Vector3.new(f, y1 - y0 - f * 2.6, 0.5), Vector3.new(x0 + f / 2, cy + f * 0.3, z), "woodV", { shadow = false })
	box(m, name .. "R", Vector3.new(f, y1 - y0 - f * 2.6, 0.5), Vector3.new(x1 - f / 2, cy + f * 0.3, z), "woodV", { shadow = false })
	local g = box(m, name .. "Glass", Vector3.new(w - 2 * f, y1 - y0 - f * 2.6, 0.15), Vector3.new(cx, cy + f * 0.3, z), "glass", { shadow = false })
	return g
end

function BUILD.GlassSlide(m, W, H, L, opt)
	beam(m, "Haban", W, 0, L.sill)
	local gy = 0.82 * H
	local y1 = gy - L.headH / 2
	local half = W / 2
	if opt and opt.open then
		glassLeaf(m, "LeafA", -half, 0.3, L.sill, y1, ZC - 0.28)
		glassLeaf(m, "LeafB", -half + 0.6, 0.9, L.sill, y1, ZC + 0.28)
	else
		glassLeaf(m, "LeafA", -half, 0.3, L.sill, y1, ZC - 0.28)
		glassLeaf(m, "LeafB", -0.3, half, L.sill, y1, ZC + 0.28)
	end
	beam(m, "Sanginbang", W, gy - L.headH / 2, gy + L.headH / 2)
	plaster(m, "Sobyeok", -W / 2, W / 2, gy + L.headH / 2, L.top0)
	beam(m, "Changbang", W, L.top0, H)
end

-- 7 개방 칸 (대청 · 툇마루 앞, 사진 4): 위쪽 상인방 · 소벽 · 창방만
function BUILD.Open(m, W, H, L)
	upper(m, W, H, L)
end

-- 기둥 (주춧돌 포함). 폭 P, 앞으로 P 만큼.
local function buildPost(m, H)
	local sh = 1.1
	box(m, "Jucho", Vector3.new(P + 0.9, sh, P + 0.9), Vector3.new(0, sh / 2, -P / 2), "stone")
	box(m, "Post", Vector3.new(P, H - sh, P), Vector3.new(0, sh + (H - sh) / 2, -P / 2), "woodV")
end

K.KINDS = { "Wall", "WallWindow", "MeoreumWindow", "DoorTtisal", "DoorBunhap", "WallBitsal", "Open", "GlassSlide" }
K.NAMES = {
	Wall = "회벽",
	WallWindow = "회벽+창",
	MeoreumWindow = "머름창",
	DoorTtisal = "띠살문",
	DoorBunhap = "분합문",
	WallBitsal = "빗살창",
	Open = "개방",
	GlassSlide = "유리 미닫이",
	Post = "기둥",
}

function K.make(kind, W, H, opt)
	H = H or 32.2
	local m = Instance.new("Model")
	m.Name = kind == "Post" and "HanokPost" or ("HanokWall_" .. kind)
	if kind == "Post" then
		buildPost(m, H)
		W = P
	else
		BUILD[kind](m, W, H, levels(H), opt)
	end
	m.WorldPivot = CFrame.new()
	m:SetAttribute("Kind", kind)
	m:SetAttribute("W", W)
	m:SetAttribute("H", H)
	if opt and opt.open then
		m:SetAttribute("Open", true)
	end
	return m
end
K.box, K.WOOD = box, WOOD

-- 한 면 조립: p0 → p1 (블록 면 위 두 모서리, y 는 벽 바닥), outward = 바깥 방향.
-- p0 모서리 바깥에 기둥 하나(옆 면과 만나는 모서리를 채움), 그 뒤 칸 n개 사이사이 기둥.
-- 건물 둘레를 한 방향으로 돌며 면마다 부르면 모서리마다 기둥이 하나씩 생긴다.
-- kinds = { "Wall", { "GlassSlide", open = true }, ... }
function K.face(parent, p0, p1, outward, kinds, H)
	local dir = (p1 - p0).Unit
	local Lf = (p1 - p0).Magnitude
	local n = #kinds
	local W = (Lf - (n - 1) * P) / n
	local function at(s)
		local pos = p0 + dir * s
		return CFrame.lookAt(pos, pos + outward)
	end
	local post = K.make("Post", nil, H)
	post:PivotTo(at(-P / 2))
	post.Parent = parent
	local s = 0
	for i, k in ipairs(kinds) do
		local kind = type(k) == "table" and k[1] or k
		local mdl = K.make(kind, W, H, type(k) == "table" and k or nil)
		mdl:PivotTo(at(s + W / 2))
		mdl.Parent = parent
		s += W
		if i < n then
			local pp = K.make("Post", nil, H)
			pp:PivotTo(at(s + P / 2))
			pp.Parent = parent
			s += P
		end
	end
	return W
end

-- 키트 (ServerStorage.ArtAssets.HanokWallKit)
local art = ServerStorage:FindFirstChild("ArtAssets") or Instance.new("Folder", ServerStorage)
art.Name = "ArtAssets"
local old = art:FindFirstChild("HanokWallKit")
if old then
	old:Destroy()
end
local kit = Instance.new("Folder")
kit.Name = "HanokWallKit"
for _, kind in ipairs(K.KINDS) do
	K.make(kind, 14, 32.2).Parent = kit
end
K.make("Post", nil, 32.2).Parent = kit
kit.Parent = art

local function clearPreview()
	local p = workspace:FindFirstChild("HanokWallKitPreview")
	if p then
		p:Destroy()
	end
end

if MODE == "clear" then
	clearPreview()
	return "preview cleared"
end

if MODE == "preview" then
	clearPreview()
	local root = Instance.new("Model")
	root.Name = "HanokWallKitPreview"
	local O = Vector3.new(1800, 0, 0)
	local floor = box(root, "Floor", Vector3.new(180, 2, 80), O + Vector3.new(0, -1, -20), "stone")
	floor.Color = Color3.fromRGB(170, 166, 156)
	-- 뒤에 붙일 블록(건물 블록 대신)
	local W = 14
	local n = #K.KINDS
	local len = n * W + (n + 1) * P
	local blk = box(root, "Block", Vector3.new(len, 32.2, 20), O + Vector3.new(0, 16.1, 10), nil)
	blk.Color = Color3.fromRGB(120, 120, 120)
	local x = -len / 2
	local function put(model, cx, label)
		model:PivotTo(CFrame.new(O + Vector3.new(cx, 0, 0)))
		model.Parent = root
		if label then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(150, 40)
			bb.StudsOffsetWorldSpace = Vector3.new(cx, 36, -2) + O
			bb.AlwaysOnTop = true
			local a = Instance.new("Attachment")
			a.Parent = floor
			a.WorldPosition = O + Vector3.new(cx, 36, -2)
			bb.StudsOffsetWorldSpace = Vector3.zero
			bb.Adornee = a
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundColor3 = Color3.new(0, 0, 0)
			t.BackgroundTransparency = 0.3
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextScaled = true
			t.Font = Enum.Font.GothamBold
			t.Text = label
			t.Parent = bb
			bb.Parent = a
		end
	end
	for i, kind in ipairs(K.KINDS) do
		put(K.make("Post", nil, 32.2), x + P / 2)
		x += P
		put(K.make(kind, W, 32.2), x + W / 2, i .. " " .. K.NAMES[kind])
		x += W
	end
	put(K.make("Post", nil, 32.2), x + P / 2)
	root.Parent = workspace
end

local parts = 0
for _, m in ipairs(kit:GetChildren()) do
	local c = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			c += 1
		end
	end
	parts += c
end
return "kit ok, modules " .. #kit:GetChildren() .. ", parts " .. parts
