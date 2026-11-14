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

-- a silver railing: posts and two rails with a see-through mesh panel
local SILVER = Color3.fromRGB(205, 208, 212)
local function railing(parent: Instance, a: Vector3, b: Vector3, h: number)
	local d = b - a
	local len = d.Magnitude
	if len < 0.5 then return end
	local mid = (a + b) / 2
	local along = CFrame.lookAt(mid, b)
	part(parent, "RailTop", Vector3.new(0.25, 0.25, len), along + Vector3.new(0, h, 0), SILVER, { mat = Enum.Material.Metal })
	part(parent, "RailMesh", Vector3.new(0.08, h - 0.4, len), along + Vector3.new(0, h / 2, 0), SILVER, { mat = Enum.Material.Metal, t = 0.55 })
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local p = a + d * (i / n)
		part(parent, "RailPost", Vector3.new(0.3, h, 0.3), CFrame.new(p.X, p.Y + h / 2, p.Z), SILVER, { mat = Enum.Material.Metal })
	end
end
local e = 0.3
railing(V, Vector3.new(SX0 + e, TOP, SZ0 + e), Vector3.new(SX1 - e, TOP, SZ0 + e), 3.5) -- north
railing(V, Vector3.new(SX0 + e, TOP, SZ1 - e), Vector3.new(SX1 - e, TOP, SZ1 - e), 3.5) -- south
railing(V, Vector3.new(SX0 + e, TOP, SZ0 + e), Vector3.new(SX0 + e, TOP, SZ1 - e), 3.5) -- west
railing(V, Vector3.new(SX1 - e, TOP, SZ0 + e), Vector3.new(SX1 - e, TOP, STZ0), 3.5) -- east, north of the stair
railing(V, Vector3.new(SX1 - e, TOP, STZ1), Vector3.new(SX1 - e, TOP, SZ1 - e), 3.5) -- east, south of the stair
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

-- yellow crowd barriers round it all (units of 5 studs: frame + bars), the way in at the stair
local YEL = Color3.fromRGB(250, 205, 30)
local BH = 3.6
local function barriers(a: Vector3, b: Vector3)
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 5 + 0.5))
	for i = 0, n - 1 do
		local p0, p1 = a + d * (i / n), a + d * ((i + 1) / n)
		local mid = (p0 + p1) / 2
		local ul = (p1 - p0).Magnitude - 0.3
		local cf = CFrame.lookAt(Vector3.new(mid.X, G, mid.Z), Vector3.new(p1.X, G, p1.Z))
		part(V, "BarrierTop", Vector3.new(0.25, 0.25, ul), cf + Vector3.new(0, BH, 0), YEL, { mat = Enum.Material.Metal })
		part(V, "BarrierBottom", Vector3.new(0.25, 0.25, ul), cf + Vector3.new(0, 0.6, 0), YEL, { mat = Enum.Material.Metal })
		for _, s in ipairs({ -1, 1 }) do
			part(V, "BarrierEnd", Vector3.new(0.3, BH, 0.3), cf * CFrame.new(0, BH / 2, s * ul / 2), YEL, { mat = Enum.Material.Metal })
			part(V, "BarrierFoot", Vector3.new(1.6, 0.15, 0.3), cf * CFrame.new(0, 0.08, s * ul / 2), YEL, { mat = Enum.Material.Metal, collide = false })
		end
		for k = 1, 5 do
			part(V, "BarrierBar", Vector3.new(0.12, BH - 0.6, 0.12), cf * CFrame.new(0, (BH + 0.6) / 2, -ul / 2 + ul * k / 6), YEL, { mat = Enum.Material.Metal, collide = false })
		end
		-- (one invisible wall per unit: nobody hops over)
		part(V, "BarrierBlocker", Vector3.new(0.4, 7, ul + 0.3), cf + Vector3.new(0, 3.5, 0), YEL, { t = 1 })
	end
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
local SEGS = 28
local GAP = { 7, 8 } -- the segments left open (round the south, +Z)
local COLORS = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(220, 60, 60), Color3.fromRGB(245, 245, 245), Color3.fromRGB(60, 130, 220) }
local FH = 3.2
for i = 0, SEGS - 1 do
	if not table.find(GAP, i) then
		local a0 = (i / SEGS) * math.pi * 2
		local a1 = ((i + 1) / SEGS) * math.pi * 2
		local p0 = Vector3.new(CX + math.cos(a0) * R, G, CZ + math.sin(a0) * R)
		local p1 = Vector3.new(CX + math.cos(a1) * R, G, CZ + math.sin(a1) * R)
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude
		local cf = CFrame.lookAt(mid, p1)
		local col = COLORS[i % #COLORS + 1]
		part(T, "FenceRail", Vector3.new(0.3, 0.3, len), cf + Vector3.new(0, FH - 0.4, 0), col)
		part(T, "FenceRail", Vector3.new(0.3, 0.3, len), cf + Vector3.new(0, 0.8, 0), col)
		for k = 0, 4 do
			local p = cf * CFrame.new(0, FH / 2, -len / 2 + len * k / 4)
			part(T, "FencePicket", Vector3.new(0.35, FH, 0.35), p, if k == 0 or k == 4 then Color3.fromRGB(60, 130, 220) else col)
		end
		part(T, "FenceBlocker", Vector3.new(0.4, 7, len), cf + Vector3.new(0, 3.5, 0), col, { t = 1 })
	end
end

M.Parent = layout
local n = 0
for _, d in ipairs(M:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print("[park_ride_fences_1114] parts:", n)
return n
