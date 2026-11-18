--!nocheck
-- 네온 무대 (D-1792, user 2026-11-18 + a photo of the round plaza in front of the amusement park: "여기 빈
-- 공터에서 네온 춤 출 수 있는 기능 구현하자 무대처럼 단상 만들고 올라가면 네온 노래 나오고 안무 추는 거"; picked:
-- a round neon stage). In the middle of the pocket park's sunken plaza (centre (-96, -128), floor y -1.98):
--   * a low step ring (radius 18, 0.6 high) and the stage top (radius 16, 1.2 high), silver
--     DiamondPlate like the club dance poles' base (D-1793): two 0.6 steps,
--     walked up from any side (no 1.5-2 stud step);
--   * a neon band under each edge (pink round the step, violet round the top: Neon parts, no collision,
--     a hair below the walking faces so nothing flickers), six small lights
--     round the edge;
--   * the numbers are NeonStageConfig's (Shared): the code that plays the song and the dance reads them.
-- Workspace["네온무대"] (outside Hongdae_Layout: a chain run cannot wipe it). Idempotent: built anew.
-- Run in Edit mode, at the end of the layout chain (after park_expand_1113 / the park_* steps).

local C = Vector3.new(-96, -1.98, -128) -- (the plaza's walked face, measured: ParkCollide / ParkLevel top)
-- (D-1793, user 2026-11-18: "무대 더 키워 바닥에 글씨 지우고 단상 재질은 댄스봉 단상 재질과 동일하게")
-- radius 10 / 11.6 -> 16 / 18 (nothing stands within 22 of the middle; the tiers start at 34.6)
-- (D-1820, user 2026-11-19: "단상 가장 넓은 원 크기에 가장 높은 높이로 한 층으로만", "네온 조명선 삭제", then "조명선
-- 하나만 얇고 연하게 넣자. 분홍색") one step of radius 18 at the old top's height (1.2), the neon bands,
-- ring and inner disc gone, one thin pale pink line under the top edge
-- (D-1822, user: "무대 단상 한 단 더 올리기") a second step on top: radius 15, 2.4 over the plaza
local TOP_R, STEP_R = 15, 18
local STEP_TOP, TOP_TOP = C.Y + 1.2, C.Y + 2.4
local SINK = 0.1 -- (the solids start under the plaza floor: no shared face with it)
-- the club dance poles' base (Graybox_MainSocial.02_Club.PoleBase): silver DiamondPlate
local BODY = Color3.fromRGB(190, 192, 198)
local BODY_MAT = Enum.Material.DiamondPlate
local PINK = Color3.fromRGB(255, 70, 200)
local PALE_PINK = Color3.fromRGB(255, 196, 228)
local VIOLET = Color3.fromRGB(150, 90, 255)

local old = workspace:FindFirstChild("네온무대")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "네온무대"

local function disc(name: string, radius: number, y0: number, y1: number, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(y1 - y0, radius * 2, radius * 2)
	p.CFrame = CFrame.new(C.X, (y0 + y1) / 2, C.Z) * CFrame.Angles(0, 0, math.pi / 2)
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

disc("StageStep", STEP_R, C.Y - SINK, STEP_TOP, BODY, BODY_MAT, true)
disc("StageTop", TOP_R, C.Y - SINK, TOP_TOP, BODY, BODY_MAT, true)
-- the one light line: 0.06 out from the edge, 0.1 high, its top 0.08 under the walking face
local line = disc("StageLine", STEP_R + 0.06, STEP_TOP - 0.18, STEP_TOP - 0.08, PALE_PINK, Enum.Material.Neon, false)
line.Transparency = 0.35

-- six small lights round the edge, pink and violet in turn
for k = 0, 5 do
	local a = k / 6 * 2 * math.pi
	local p = Instance.new("Part")
	p.Name = "StageLight" .. (k + 1)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(C.X + (STEP_R + 0.6) * math.cos(a), TOP_TOP + 0.4, C.Z + (STEP_R + 0.6) * math.sin(a))
	p.Parent = model
	local light = Instance.new("PointLight")
	light.Color = if k % 2 == 0 then PINK else VIOLET
	light.Brightness = 1.6
	light.Range = 12
	light.Shadows = false
	light.Parent = p
end

model.WorldPivot = CFrame.new(C.X, TOP_TOP, C.Z)
model.Parent = workspace
print(("[park_neon_stage_1118] stage at (%.1f, %.1f, %.1f), top y %.2f"):format(C.X, C.Y, C.Z, TOP_TOP))
