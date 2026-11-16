--!nocheck
-- 범퍼카 대기줄 · 출구 (D-1525, user 2026-11-16 + a top view with red fence lines in front of the hall:
-- "범퍼카 앞에 펜스 빨간선 모양으로 세워 줘. 왼쪽 화살표는 출구 입장 안 되게 막고, 오른쪽 노란 화살표 따라서
-- 대기줄 서는 거임. 입장만 할 수 있음").
--   * an exit in the hall's south rail at x -155.3..-141.7 (a ramp like the entrance's) with a fenced lane
--     running south from it (EXIT_W / EXIT_E);
--   * the queue: in from the south between x -141.7 and -126.9, up and right along the bottom row, up and
--     left along the middle row, up and right along the top row to the entrance at x -95;
--   * the fences: the park's yellow panel (점핑스타.FencePanel) end to end on each line, each with its
--     invisible FenceWall;
--   * one way: two RideGate models in 범퍼.Gates, Mode "Exit" with no leaf (RideGateController): the exit
--     (Inward north, into the hall) stops people coming in from outside; the entrance (Inward south) stops
--     people inside the hall going back out through it (so it only lets people in);
--   * the hall's south rail panels and rubber band laid again round both gaps.
-- Model: Workspace.범퍼.Queue (rebuilt each run). Run after park_bumper_big_1116 / park_fixes2_1116.

local G = 16.11
local EXIT_W, EXIT_E = -155.3, -141.7
local RAIL_Z = -645
local LINES = {
	{ Vector3.new(EXIT_W, 0, -643.4), Vector3.new(EXIT_W, 0, -581.75) }, -- the exit lane's west side
	{ Vector3.new(EXIT_E, 0, -643.4), Vector3.new(EXIT_E, 0, -579.25) }, -- its east side = the queue's west side
	{ Vector3.new(-124.4, 0, -627.25), Vector3.new(-70.1, 0, -627.25) }, -- top row / middle row
	{ Vector3.new(-70.1, 0, -627.25), Vector3.new(-70.1, 0, -593) }, -- the east end of the middle and bottom rows
	{ Vector3.new(EXIT_E, 0, -611.25), Vector3.new(-87.4, 0, -611.25) }, -- middle row / bottom row
	{ Vector3.new(-126.9, 0, -593), Vector3.new(-70.1, 0, -593) }, -- the bottom row's south side
	{ Vector3.new(-126.9, 0, -593), Vector3.new(-126.9, 0, -578) }, -- the way in, east side (to the viking's bed)
}

local hall = workspace:FindFirstChild("범퍼")
local area = hall and hall:FindFirstChild("04_BumperCars")
local star = workspace:FindFirstChild("점핑스타")
assert(area and star, "no 범퍼 / 점핑스타")
local PANEL, WALL = star:FindFirstChild("FencePanel"), star:FindFirstChild("FenceWall")
local floor = area.Floor
local FY = floor.Position.Y + floor.Size.Y / 2
local X0, X1 = floor.Position.X - floor.Size.X / 2, floor.Position.X + floor.Size.X / 2
local o = {}

-- the queue fences
local old = hall:FindFirstChild("Queue")
if old then old:Destroy() end
local q = Instance.new("Model")
q.Name = "Queue"
local n = 0
for _, l in ipairs(LINES) do
	local a, b = l[1], l[2]
	local L = (b - a).Magnitude
	local u = (b - a).Unit
	local PL = PANEL.Size.Z
	local k = math.max(1, math.ceil(L / PL - 0.02))
	for i = 0, k - 1 do
		local t = if k == 1 then L / 2 else PL / 2 + (L - PL) * i / (k - 1)
		local m = a + u * t
		for _, tmpl in ipairs({ PANEL, WALL }) do
			local p = tmpl:Clone()
			local at = Vector3.new(m.X, G + p.Size.Y / 2, m.Z)
			p.CFrame = CFrame.lookAt(at, at + u)
			p.Anchored = true
			p.Parent = q
		end
		n += 1
	end
end
q.Parent = hall
table.insert(o, ("%d panels"):format(n))

-- the exit gap in the south rail (the piece west of the entrance split round it)
local west
for _, r in ipairs(area:GetChildren()) do
	if r.Name == "Rail" and math.abs(r.Position.Z - RAIL_Z) < 0.5 and r.Size.X > r.Size.Z
		and r.Position.X - r.Size.X / 2 < EXIT_W and r.Position.X + r.Size.X / 2 > EXIT_E then west = r end
end
if west then
	local x0, x1 = west.Position.X - west.Size.X / 2, west.Position.X + west.Size.X / 2
	local east = west:Clone()
	west.Size = Vector3.new(EXIT_W - x0, west.Size.Y, west.Size.Z)
	west.CFrame = CFrame.new((x0 + EXIT_W) / 2, west.Position.Y, west.Position.Z)
	east.Size = Vector3.new(x1 - EXIT_E, east.Size.Y, east.Size.Z)
	east.CFrame = CFrame.new((EXIT_E + x1) / 2, east.Position.Y, east.Position.Z)
	east.Parent = area
	table.insert(o, "exit gap cut")
end
-- its ramp, like the entrance's
local entrance = hall:FindFirstChild("SouthEntrance")
local entRamp = entrance and entrance:FindFirstChild("EntranceRamp")
local oldRamp = hall:FindFirstChild("ExitRamp")
if oldRamp then oldRamp:Destroy() end
if entRamp then
	local r = entRamp:Clone()
	r.Name = "ExitRamp"
	r.Size = Vector3.new(EXIT_E - EXIT_W, entRamp.Size.Y, entRamp.Size.Z)
	r.CFrame = entRamp.CFrame + Vector3.new((EXIT_W + EXIT_E) / 2 - entRamp.Position.X, 0, 0)
	r.Parent = hall
end

-- one way: the exit lets people out only, the entrance lets people in only
local gates = hall:FindFirstChild("Gates")
if gates then gates:Destroy() end
gates = Instance.new("Folder")
gates.Name = "Gates"
local function gate(name: string, x0: number, x1: number, inward: Vector3)
	local m = Instance.new("Model")
	m.Name = name
	local b = Instance.new("Part")
	b.Name = "Block"
	b.Size = Vector3.new(x1 - x0, 8, 1.2)
	b.CFrame = CFrame.new((x0 + x1) / 2, FY + 4, RAIL_Z)
	b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery, b.Transparency, b.CastShadow = true, false, false, false, 1, false
	b.Parent = m
	m.PrimaryPart = b
	m:SetAttribute("Mode", "Exit")
	m:SetAttribute("Inward", inward)
	m:SetAttribute("Width", x1 - x0)
	m.Parent = gates
	game:GetService("CollectionService"):AddTag(m, "RideGate")
end
local ENT_X = entRamp and entRamp.Position.X or -95
gate("Exit", EXIT_W, EXIT_E, Vector3.new(0, 0, -1))
gate("Entrance", ENT_X - 5.5, ENT_X + 5.5, Vector3.new(0, 0, 1))
gates.Parent = hall

-- the south rail's panels and rubber band again round both gaps
local dress = hall:FindFirstChild("ArenaDress")
local YP = game:GetService("ServerStorage").ArtAssets:FindFirstChild("YellowFencePanel")
if dress and YP then
	for _, p in ipairs(dress:GetChildren()) do
		if (p.Name == "FencePanel" or p.Name == "RubberBand") and math.abs(p.Position.Z - RAIL_Z) < 1.5 then
			local e = (p.CFrame.RightVector * p.Size.X):Abs() + (p.CFrame.LookVector * p.Size.Z):Abs()
			if e.X > e.Z then p:Destroy() end
		end
	end
	local k2 = 0
	for _, r in ipairs(area:GetChildren()) do
		if r.Name == "Rail" and math.abs(r.Position.Z - RAIL_Z) < 0.5 and r.Size.X > r.Size.Z then
			local lo, hi, c = r.Position - r.Size / 2, r.Position + r.Size / 2, r.Position
			local rb = Instance.new("Part")
			rb.Name = "RubberBand"
			rb.Size = Vector3.new(r.Size.X, 1.6, 0.5)
			rb.CFrame = CFrame.new(c.X, FY + 1.1, lo.Z - 0.25)
			rb.Color, rb.Material = Color3.fromRGB(24, 24, 28), Enum.Material.Rubber
			rb.Anchored, rb.CanCollide, rb.CanTouch, rb.CanQuery = true, false, false, false
			rb.Parent = dress
			local a, b = Vector3.new(lo.X, FY, c.Z), Vector3.new(hi.X, FY, c.Z)
			local L, u, PL = (b - a).Magnitude, (b - a).Unit, YP.Size.Z
			local k = math.max(1, math.ceil(L / PL - 0.02))
			for i = 0, k - 1 do
				local t = if k == 1 then L / 2 else PL / 2 + (L - PL) * i / (k - 1)
				local m = a + u * t
				local p = YP:Clone()
				p.Name = "FencePanel"
				p.CFrame = CFrame.lookAt(m, m + u) * CFrame.new(if k2 % 2 == 0 then 0.03 else -0.03, YP.Size.Y / 2, 0)
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
				p.Parent = dress
				k2 += 1
			end
		end
	end
	table.insert(o, ("rail panels %d"):format(k2))
end
-- (D-1526, user: "범퍼카 입구 출구 표시해 줘") signs: a gantry over the exit lane and the queue's way in
-- (posts on the fence lines; "출구 EXIT" green, "범퍼카 타는 곳 ENTRANCE" purple), and "출구 EXIT" over the
-- hall's exit gap for the riders inside. Model 범퍼.Signs.
do
	local old2 = hall:FindFirstChild("Signs")
	if old2 then old2:Destroy() end
	local m = Instance.new("Model")
	m.Name = "Signs"
	local STEEL = Color3.fromRGB(60, 62, 70)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.Metal
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local function board(name: string, x0: number, x1: number, z: number, y: number, h: number, bg: Color3, fg: Color3, text: string)
		local b = part(name, Vector3.new(x1 - x0, h, 0.4), CFrame.new((x0 + x1) / 2, y, z), bg, Enum.Material.SmoothPlastic)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local g = Instance.new("SurfaceGui")
			g.Face, g.CanvasSize, g.LightInfluence, g.Brightness = face, Vector2.new((x1 - x0) * 50, h * 50), 0, 1.4
			g.Parent = b
			local t = Instance.new("TextLabel")
			t.Size, t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3, t.Text = UDim2.fromScale(1, 1), 1, Enum.Font.GothamBlack, true, fg, text
			t.Parent = g
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0.04, 0), UDim.new(0.04, 0), UDim.new(0.12, 0), UDim.new(0.12, 0)
			pad.Parent = t
		end
		local tr = part(name .. "Trim", Vector3.new(x1 - x0 + 0.4, h + 0.4, 0.3), CFrame.new((x0 + x1) / 2, y, z), Color3.fromRGB(250, 190, 40), Enum.Material.Neon)
		tr.CastShadow = false
	end
	local Z, TOP = -581.2, G + 10
	for _, x in ipairs({ EXIT_W, EXIT_E, -126.9 }) do part("SignPost", Vector3.new(0.6, TOP - G + 0.6, 0.6), CFrame.new(x, (G + TOP) / 2, Z), STEEL) end
	part("SignBeam", Vector3.new(-126.9 - EXIT_W + 0.6, 0.5, 0.5), CFrame.new((EXIT_W - 126.9) / 2, TOP, Z), STEEL)
	board("ExitSign", EXIT_W + 0.3, EXIT_E - 0.3, Z, TOP - 1.6, 2.6, Color3.fromRGB(28, 140, 80), Color3.new(1, 1, 1), "출구 EXIT")
	board("QueueSign", EXIT_E + 0.3, -127.2, Z, TOP - 1.6, 2.6, Color3.fromRGB(86, 40, 150), Color3.fromRGB(255, 220, 110), "범퍼카 타는 곳 ENTRANCE")
	board("HallExitSign", EXIT_W + 0.5, EXIT_E - 0.5, RAIL_Z, G + 9.2, 2.2, Color3.fromRGB(28, 140, 80), Color3.new(1, 1, 1), "출구 EXIT")
	for _, x in ipairs({ EXIT_W, EXIT_E }) do part("SignPost", Vector3.new(0.5, 10.3, 0.5), CFrame.new(x, G + 5.15, RAIL_Z), STEEL) end
	m.Parent = hall
	table.insert(o, "signs")
end

print("[park_bumper_queue_1116] " .. table.concat(o, "; "))
return table.concat(o, "; ")
