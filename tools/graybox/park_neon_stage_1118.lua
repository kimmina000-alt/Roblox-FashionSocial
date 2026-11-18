--!nocheck
-- 네온 무대 (D-1792, user 2026-11-18 + a photo of the round plaza in front of the amusement park: "여기 빈
-- 공터에서 네온 춤 출 수 있는 기능 구현하자 무대처럼 단상 만들고 올라가면 네온 노래 나오고 안무 추는 거"; picked:
-- a round neon stage). In the middle of the pocket park's sunken plaza (centre (-96, -128), floor y -1.98):
--   * a low step ring (radius 11.6, 0.6 high) and the stage top (radius 10, 1.2 high): two 0.6 steps,
--     walked up from any side (no 1.5-2 stud step);
--   * a neon band under each edge (pink round the step, violet round the top: Neon parts, no collision,
--     a hair below the walking faces so nothing flickers), "NEON STAGE" on the top, six small lights
--     round the edge;
--   * the numbers are NeonStageConfig's (Shared): the code that plays the song and the dance reads them.
-- Workspace["네온무대"] (outside Hongdae_Layout: a chain run cannot wipe it). Idempotent: built anew.
-- Run in Edit mode, at the end of the layout chain (after park_expand_1113 / the park_* steps).

local C = Vector3.new(-96, -1.98, -128) -- (the plaza's walked face, measured: ParkCollide / ParkLevel top)
local TOP_R, STEP_R = 10, 11.6
local STEP_TOP, TOP_TOP = C.Y + 0.6, C.Y + 1.2
local SINK = 0.1 -- (the solids start under the plaza floor: no shared face with it)
local BODY = Color3.fromRGB(28, 22, 46)
local PINK = Color3.fromRGB(255, 70, 200)
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

local step = disc("StageStep", STEP_R, C.Y - SINK, STEP_TOP, BODY, Enum.Material.SmoothPlastic, true)
step.Reflectance = 0.08
local top = disc("StageTop", TOP_R, C.Y - SINK, TOP_TOP, BODY, Enum.Material.SmoothPlastic, true)
top.Reflectance = 0.12
-- the neon bands: 0.15 out from each edge, their tops 0.05 under the walking face above them
disc("NeonStepBand", STEP_R + 0.15, STEP_TOP - 0.3, STEP_TOP - 0.05, PINK, Enum.Material.Neon, false)
disc("NeonTopBand", TOP_R + 0.15, TOP_TOP - 0.3, TOP_TOP - 0.05, VIOLET, Enum.Material.Neon, false)
-- a thin neon ring drawn on the top, 1.2 in from its edge
disc("NeonTopRing", TOP_R - 1.2, TOP_TOP - 0.05, TOP_TOP + 0.02, PINK, Enum.Material.Neon, false)
disc("TopInner", TOP_R - 1.4, TOP_TOP - 0.04, TOP_TOP + 0.03, BODY, Enum.Material.SmoothPlastic, false).Reflectance = 0.12

-- "NEON STAGE" on the top
do
	local board = Instance.new("Part")
	board.Name = "StageTitle"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.CastShadow = false
	board.Transparency = 1
	board.Size = Vector3.new(5, 0.05, 14)
	-- (turned so the words read the right way up from the south, the street side; checked in Play)
	board.CFrame = CFrame.new(C.X, TOP_TOP + 0.06, C.Z) * CFrame.Angles(0, -math.pi / 2, 0)
	board.Parent = model
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "NEON STAGE"
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 220)
	label.TextStrokeColor3 = Color3.fromRGB(120, 60, 255)
	label.TextStrokeTransparency = 0
	label.Parent = gui
end

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
