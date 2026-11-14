-- (D-1410, user 2026-11-14, photos of a mini viking (yellow crowd barriers round it, the ride up
-- on a stage with its own railing and a stair) and of a tea cup ride (a fence all round, one
-- way in): "범퍼카 옆에 있는 미니바이킹 사진 속처럼 노란색 펜스 두르고 안에 단상 위에 바이킹 올리기.
-- 단상에도 펜스 있음. 올라가는 계단 있음. 티컵도 주변에 펜스 두르고 출입구만 뚫어 놓기.")
--   Mini viking (ParkBlockout["09_MiniViking"], base 22.8 x 35.5 at -252, -444): a blue stage
--   STAGE_H high under it (the viking is lifted onto it), a silver railing round the stage's
--   edge with a gap at the stair, a stair on the east side, yellow crowd barriers round it all
--   with the way in at the stair ("미니바이킹 / 타는곳" sign).
--   Tea cups (ParkBlockout["07_TeaCups"], deck centre -102.2, -495, radius 35.2): a picket fence
--   (white, red and blue panels) on a circle round the deck, one opening facing south.
-- Model: Workspace.Hongdae_Layout.RideFences (rebuilt each run); the viking is lifted to the
-- stage top (idempotent). Chain step: after park_bumper_queue_1114 (last).

local layout = workspace:WaitForChild("Hongdae_Layout")
local blockout = layout:WaitForChild("ParkBlockout")
local old = layout:FindFirstChild("RideFences")
if old then old:Destroy() end
local M = Instance.new("Model")
M.Name = "RideFences"
local G = 16.2

-- (D-1411, user: "놀이공원 안에 펜스 저걸로 통일") every park fence is the user's crowd barrier
-- mesh (fence.glb, place-only template ServerStorage.ArtAssets.ParkFence, yellow metal):
-- panels of about 5 studs along a line, no collision; one invisible 7-stud wall per line.
local FENCE_SRC = game:GetService("ServerStorage"):WaitForChild("ArtAssets"):WaitForChild("ParkFence") :: MeshPart
local FENCE_COLOR = Color3.fromRGB(250, 205, 30)
local FENCE_H = 3.6
local function panels(parent: Instance, a: Vector3, b: Vector3, step: number?)
	-- a, b: the line's ends; their Y is the ground under the fence
	local d = b - a
	local len = d.Magnitude
	if len < 0.5 then return end
	local n = math.max(1, math.floor(len / (step or 5) + 0.5))
	for i = 0, n - 1 do
		local p0, p1 = a + d * (i / n), a + d * ((i + 1) / n)
		local mid = (p0 + p1) / 2 + Vector3.new(0, FENCE_H / 2, 0)
		local m = FENCE_SRC:Clone()
		m.Name = "FencePanel"
		m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
		m.Size = Vector3.new(0.25, FENCE_H, (p1 - p0).Magnitude - 0.15)
		m.CFrame = CFrame.lookAt(mid, mid + (p1 - p0))
		m.Color, m.Material = FENCE_COLOR, Enum.Material.Metal
		m.Parent = parent
	end
	local w = Instance.new("Part")
	w.Name = "FenceBlocker"
	w.Anchored, w.Transparency, w.CastShadow, w.CanTouch = true, 1, false, false
	w.Size = Vector3.new(0.4, 7, len)
	local mid = (a + b) / 2 + Vector3.new(0, 3.5, 0)
	w.CFrame = CFrame.lookAt(mid, mid + d)
	w.Parent = parent
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow == true
	if opts.t then p.Transparency = opts.t end
	if opts.shape then (p :: Part).Shape = opts.shape end
	p.Parent = parent
	return p
end

------------------------------------------------------------------ mini viking
local V = Instance.new("Model")
V.Name = "VikingStage"
V.Parent = M
local STAGE_H = 4
local SX0, SX1, SZ0, SZ1 = -266, -238, -466, -422 -- the stage
local TOP = G + STAGE_H
local viking = blockout:FindFirstChild("09_MiniViking")
if viking then
	local base = viking:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		local lift = TOP - (base.Position.Y - base.Size.Y / 2)
		if math.abs(lift) > 0.01 then viking:PivotTo(viking:GetPivot() + Vector3.new(0, lift, 0)) end
	end
end
-- the stage: blue sides, a light deck
part(V, "Stage", Vector3.new(SX1 - SX0, STAGE_H, SZ1 - SZ0), CFrame.new((SX0 + SX1) / 2, G + STAGE_H / 2, (SZ0 + SZ1) / 2), Color3.fromRGB(56, 140, 210), { shadow = true })
part(V, "StageDeck", Vector3.new(SX1 - SX0, 0.1, SZ1 - SZ0), CFrame.new((SX0 + SX1) / 2, TOP + 0.05, (SZ0 + SZ1) / 2), Color3.fromRGB(200, 205, 210), { mat = Enum.Material.DiamondPlate })
part(V, "StageTrim", Vector3.new(SX1 - SX0 + 0.4, 0.5, SZ1 - SZ0 + 0.4), CFrame.new((SX0 + SX1) / 2, TOP - 0.25, (SZ0 + SZ1) / 2), Color3.fromRGB(250, 200, 50), { collide = false })
-- the stair on the east side: z -432..-426, from the ground up to the stage
local STZ0, STZ1 = -432, -426
local STEPS = 8
for i = 1, STEPS do
	local h = STAGE_H * i / STEPS
	local x = SX1 + (STEPS - i + 0.5) -- one stud per step, rising towards the stage
	part(V, "StairStep", Vector3.new(1, h, STZ1 - STZ0), CFrame.new(x, G + h / 2, (STZ0 + STZ1) / 2), Color3.fromRGB(56, 140, 210))
end
local ramp = Instance.new("WedgePart")
ramp.Name = "StairRamp"
ramp.Anchored, ramp.Transparency = true, 1
ramp.Size = Vector3.new(STZ1 - STZ0, STAGE_H, STEPS)
ramp.CFrame = CFrame.new(SX1 + STEPS / 2, G + STAGE_H / 2, (STZ0 + STZ1) / 2) * CFrame.Angles(0, math.rad(-90), 0)
ramp.Parent = V

-- the stage's railing: the same fence panels on the stage edge, a gap at the stair
local SILVER = Color3.fromRGB(205, 208, 212)
local e = 0.3
panels(V, Vector3.new(SX0 + e, TOP, SZ0 + e), Vector3.new(SX1 - e, TOP, SZ0 + e)) -- north
panels(V, Vector3.new(SX0 + e, TOP, SZ1 - e), Vector3.new(SX1 - e, TOP, SZ1 - e)) -- south
panels(V, Vector3.new(SX0 + e, TOP, SZ0 + e), Vector3.new(SX0 + e, TOP, SZ1 - e)) -- west
panels(V, Vector3.new(SX1 - e, TOP, SZ0 + e), Vector3.new(SX1 - e, TOP, STZ0)) -- east, north of the stair
panels(V, Vector3.new(SX1 - e, TOP, STZ1), Vector3.new(SX1 - e, TOP, SZ1 - e)) -- east, south of the stair
-- handrails up the stair
for _, z in ipairs({ STZ0 + 0.2, STZ1 - 0.2 }) do
	local a, b = Vector3.new(SX1 + STEPS, G, z), Vector3.new(SX1, TOP, z)
	local d = b - a
	part(V, "StairRail", Vector3.new(0.25, 0.25, d.Magnitude), CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 3, 0), SILVER, { mat = Enum.Material.Metal })
	for _, k in ipairs({ 0, 0.5, 1 }) do
		local p = a + d * k
		part(V, "StairRailPost", Vector3.new(0.3, 3, 0.3), CFrame.new(p.X, p.Y + 1.5, p.Z), SILVER, { mat = Enum.Material.Metal })
	end
end

-- crowd barriers round it all, the way in at the stair
local YEL = FENCE_COLOR
local function barriers(a: Vector3, b: Vector3)
	panels(V, a + Vector3.new(0, G, 0), b + Vector3.new(0, G, 0))
end
local BX0, BX1, BZ0, BZ1 = -272, -224, -472, -416
barriers(Vector3.new(BX0, 0, BZ0), Vector3.new(BX1, 0, BZ0)) -- north
barriers(Vector3.new(BX0, 0, BZ1), Vector3.new(BX1, 0, BZ1)) -- south
barriers(Vector3.new(BX0, 0, BZ0), Vector3.new(BX0, 0, BZ1)) -- west
barriers(Vector3.new(BX1, 0, BZ0), Vector3.new(BX1, 0, STZ0 - 1)) -- east, north of the way in
barriers(Vector3.new(BX1, 0, STZ1 + 1), Vector3.new(BX1, 0, BZ1)) -- east, south of the way in
-- the sign at the way in
local sign = part(V, "RideSign", Vector3.new(0.3, 3.4, 4), CFrame.new(BX1 + 0.4, G + 4.6, STZ1 + 3.6), Color3.fromRGB(240, 120, 30), { shadow = true })
part(V, "RideSignPost", Vector3.new(0.3, 3, 0.3), CFrame.new(BX1 + 0.4, G + 1.5, STZ1 + 3.6), YEL, { mat = Enum.Material.Metal })
do
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Right
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0.3
	g.Parent = sign
	local function t(text: string, y: number, h: number, c: Color3, bg: Color3?)
		local l = Instance.new("TextLabel")
		l.Position, l.Size = UDim2.fromScale(0.06, y), UDim2.fromScale(0.88, h)
		l.BackgroundTransparency = if bg then 0 else 1
		if bg then l.BackgroundColor3 = bg end
		l.Text, l.TextScaled, l.Font, l.TextColor3 = text, true, Enum.Font.GothamBlack, c
		l.Parent = g
	end
	t("미니바이킹", 0.08, 0.36, Color3.fromRGB(250, 60, 40), Color3.fromRGB(255, 240, 120))
	t("타는곳 ▶", 0.52, 0.22, Color3.new(1, 1, 1))
	t("ENTRANCE", 0.74, 0.16, Color3.new(1, 1, 1))
end

------------------------------------------------------------------ tea cups: a round fence, one way in
local T = Instance.new("Model")
T.Name = "TeaCupFence"
T.Parent = M
local CX, CZ, R = -102.2, -495, 38.5
local SEGS = 52
local GAP0, GAP1 = 13, 16 -- the segments left open (round the south, +Z, about 18 studs)
for i = 0, SEGS - 1 do
	if i < GAP0 or i > GAP1 then
		local a0 = (i / SEGS) * math.pi * 2
		local a1 = ((i + 1) / SEGS) * math.pi * 2
		panels(T, Vector3.new(CX + math.cos(a0) * R, G, CZ + math.sin(a0) * R), Vector3.new(CX + math.cos(a1) * R, G, CZ + math.sin(a1) * R), 6)
	end
end

M.Parent = layout
local n = 0
for _, d in ipairs(M:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print("[park_ride_fences_1114] parts:", n)
return n
