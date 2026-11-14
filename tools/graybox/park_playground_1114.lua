-- (D-1408, user 2026-11-14, a photo of an apartment playground (colourful rubber floor in
-- red / yellow / teal patches, a yellow tube slide, low wooden posts with a teal rail, planters
-- round it) and a sketch: "놀이터 디자인 정리. 바닥이랑 주변에 화단 설치 / 놀이터 자체를 오른쪽으로
-- 이동하고 입구 복도로 사용") The playground (06_Park_Playground: Slide, "그 네 " swing set,
-- SpringRider1..3) moves as one piece north of the bumper car hall's exit (SpringRider1 at
-- TARGET), so its old place becomes the bumper car queue's entrance corridor
-- (park_bumper_queue_1114). Around it, Workspace.Hongdae_Layout.ParkPlayground (rebuilt each
-- run): a rubber floor pad with colour patches, low wooden posts with a teal rail (gaps on the
-- south and east), planters (granite edge, soil, bushes copied from the user's own planter
-- "화단") along the west and north and both sides of the east gap.
-- The slide's path (attributes P0 / P1 / P2, world positions) is set again from its bed.
-- Idempotent (moves to TARGET, not by an offset). Chain step: before park_bumper_queue_1114.

local layout = workspace:WaitForChild("Hongdae_Layout")
local pg = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("06_Park_Playground")
local TARGET = Vector3.new(-157.08, 17.035, -405.74) -- SpringRider1's pivot (was -131.08, -299.74)

local ref = pg:FindFirstChild("SpringRider1") :: Model
local delta = TARGET - ref:GetPivot().Position
local function shift(inst: Instance)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + delta)
	elseif inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame + delta
	else
		for _, c in ipairs(inst:GetChildren()) do shift(c) end
	end
end
if delta.Magnitude > 0.05 then
	for _, name in ipairs({ "Slide", "그 네 ", "SpringRider1", "SpringRider2", "SpringRider3" }) do
		local m = pg:FindFirstChild(name)
		if m then shift(m) end
	end
end

-- the slide's path from its bed (top piece to bottom piece, a rider's height above it)
local slide = pg:FindFirstChild("Slide")
if slide then
	local beds = {}
	for _, d in ipairs(slide:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "SlideBed" then table.insert(beds, d) end
	end
	table.sort(beds, function(a, b) return a.Position.Y > b.Position.Y end)
	if #beds >= 3 then
		local up = Vector3.new(0, 2.6, 0)
		local top, mid, bottom = beds[1].Position, beds[math.ceil(#beds / 2)].Position, beds[#beds].Position
		local run = (bottom - beds[#beds - 1].Position).Unit
		slide:SetAttribute("P0", top + up + Vector3.new(0, 0.4, 0))
		slide:SetAttribute("P1", mid + up)
		slide:SetAttribute("P2", bottom + up + run * 2)
	end
end

------------------------------------------------------------------ pad, fence, planters
local old = layout:FindFirstChild("ParkPlayground")
if old then old:Destroy() end
local M = Instance.new("Model")
M.Name = "ParkPlayground"
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
local X0, X1, Z0, Z1 = -198, -151, -468, -398 -- the pad

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	opts = opts or {}
	local p = Instance.new("Part")
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
	if opts.shape then (p :: Part).Shape = opts.shape end
	p.Parent = opts.parent or M
	return p
end

-- rubber floor: a cream base and colour patches (flat discs and strips), like the photo
local RUBBER = Enum.Material.Fabric
part("RubberFloor", Vector3.new(X1 - X0, 0.12, Z1 - Z0), CFrame.new((X0 + X1) / 2, G + 0.06, (Z0 + Z1) / 2), Color3.fromRGB(236, 222, 190), { mat = RUBBER })
local patches = {
	{ -186, -414, 13, Color3.fromRGB(226, 72, 74) }, { -164, -420, 11, Color3.fromRGB(250, 198, 60) },
	{ -184, -440, 12, Color3.fromRGB(70, 190, 180) }, { -162, -448, 13, Color3.fromRGB(226, 72, 74) },
	{ -178, -458, 9, Color3.fromRGB(240, 150, 190) }, { -160, -434, 7, Color3.fromRGB(110, 170, 230) },
	{ -192, -460, 6, Color3.fromRGB(250, 198, 60) }, { -170, -404, 6, Color3.fromRGB(110, 170, 230) },
}
for i, p in ipairs(patches) do
	local r = p[3]
	part("RubberPatch", Vector3.new(0.04, r * 2, r * 2), CFrame.new(p[1], G + 0.12 + i * 0.004, p[2]) * CFrame.Angles(0, 0, math.rad(90)), p[4], { mat = RUBBER, shape = Enum.PartType.Cylinder, collide = false })
end
-- the pad's edge strip
for _, e in ipairs({
	{ Vector3.new(X1 - X0 + 0.6, 0.3, 0.6), CFrame.new((X0 + X1) / 2, G + 0.15, Z0) },
	{ Vector3.new(X1 - X0 + 0.6, 0.3, 0.6), CFrame.new((X0 + X1) / 2, G + 0.15, Z1) },
	{ Vector3.new(0.6, 0.3, Z1 - Z0), CFrame.new(X0, G + 0.15, (Z0 + Z1) / 2) },
	{ Vector3.new(0.6, 0.3, Z1 - Z0), CFrame.new(X1, G + 0.15, (Z0 + Z1) / 2) },
}) do part("PadEdge", e[1], e[2], Color3.fromRGB(70, 160, 150), { mat = RUBBER, collide = false }) end

-- the fence (the park's fence panels, D-1411); gaps on the south (from the exit path) and east
local function fence(a: Vector3, b: Vector3)
	panels(M, a + Vector3.new(0, G, 0), b + Vector3.new(0, G, 0))
end
local FX0, FX1, FZ0, FZ1 = X0 + 0.8, X1 - 0.8, Z0 + 0.8, Z1 - 0.8
fence(Vector3.new(FX0, 0, FZ1), Vector3.new(-180, 0, FZ1)) -- south, west part
fence(Vector3.new(-168, 0, FZ1), Vector3.new(FX1, 0, FZ1)) -- south, east part (gap -180..-168)
fence(Vector3.new(FX0, 0, FZ0), Vector3.new(FX1, 0, FZ0)) -- north
fence(Vector3.new(FX0, 0, FZ0), Vector3.new(FX0, 0, FZ1)) -- west
fence(Vector3.new(FX1, 0, FZ0), Vector3.new(FX1, 0, -440)) -- east, north part
fence(Vector3.new(FX1, 0, -428), Vector3.new(FX1, 0, FZ1)) -- east, south part (gap -440..-428)

-- planters (the user's planter "화단": granite edge, earth soil, bush meshes)
local bushes = {}
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "화단" then
		for _, d in ipairs(c:GetDescendants()) do
			-- (green bushes only: the bare wooden one looked dead)
			if d:IsA("MeshPart") and d.Material ~= Enum.Material.Wood then table.insert(bushes, d) end
		end
		if #bushes > 0 then break end
	end
end
local function planter(a: Vector3, b: Vector3, width: number)
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, G, mid.Z), Vector3.new(b.X, G, b.Z))
	part("PlanterSoil", Vector3.new(width - 0.6, 1.1, len - 0.6), cf * CFrame.new(0, 0.55, 0), Color3.fromRGB(110, 72, 44), { mat = Enum.Material.Ground })
	for _, s in ipairs({ -1, 1 }) do
		part("PlanterEdge", Vector3.new(0.7, 1.3, len), cf * CFrame.new(s * (width / 2 - 0.35), 0.65, 0), Color3.fromRGB(190, 190, 186), { mat = Enum.Material.Granite })
	end
	for _, s in ipairs({ -1, 1 }) do
		part("PlanterEdge", Vector3.new(width, 1.3, 0.7), cf * CFrame.new(0, 0.65, s * (len / 2 - 0.35)), Color3.fromRGB(190, 190, 186), { mat = Enum.Material.Granite })
	end
	if #bushes > 0 then
		local n = math.max(1, math.floor(len / 7.5))
		for i = 1, n do
			local src = bushes[(i - 1) % #bushes + 1]
			local bush = src:Clone()
			local k = (width - 1.6) / math.max(src.Size.X, src.Size.Z)
			bush.Size = src.Size * math.min(1, k)
			local z = -len / 2 + len * (i - 0.5) / n
			bush.CFrame = cf * CFrame.new(0, 1.1 + bush.Size.Y / 2 - 0.4, z) * CFrame.Angles(0, math.rad((i * 67) % 360), 0)
			bush.Anchored, bush.CanCollide, bush.CastShadow = true, false, false
			bush.Parent = M
		end
	end
end
planter(Vector3.new(X0 - 3, 0, Z1), Vector3.new(X0 - 3, 0, Z0 - 6), 5) -- west
planter(Vector3.new(X0 - 0.5, 0, Z0 - 3), Vector3.new(X1 + 0.5, 0, Z0 - 3), 5) -- north
planter(Vector3.new(X1 + 3, 0, Z0 - 0.5), Vector3.new(X1 + 3, 0, -442), 4) -- east, north of the gap
planter(Vector3.new(X1 + 3, 0, -426), Vector3.new(X1 + 3, 0, Z1), 4) -- east, south of the gap

M.Parent = layout
print("[park_playground_1114] moved by", delta, "parts:", #M:GetDescendants())
return delta
