-- (D-1407, user 2026-11-14, photos of an indoor bumper car hall: entrance and exit side by side
-- under a yellow checker header with red-white checker columns, a height board (125) and teal
-- benches by the wall, a black-and-white checker floor with stainless switchback rails: "범퍼카
-- 대기줄 구현해") The bumper car queue on the east side of the bumper car hall
-- (Hongdae_Layout.ParkBlockout["04_BumperCars"], floor x -277.5..-206.5, z -399..-292.4):
--   - a checker floor x -205..-181, z -392..-292 (one part, tiles drawn in a SurfaceGui)
--   - five switchback lanes 4 studs wide (x -203..-183, z -320..-388): ENTRANCE at the south
--     end of the east lane, the west lane ends at the boarding gap in the hall's east rail
--     (z -388..-384); stainless posts and two tube rails, an invisible 7-stud wall on every rail
--     line (so nobody hops the rails)
--   - EXIT: a gap in the hall's east rail at z -300..-296 into the exit lane beside the entrance
--   - header beam over entrance + exit (yellow / orange checker band, ENTRANCE 입구 / EXIT 출구 /
--     BUMPER CAR), red-white checker columns, a height board (키 125) and a teal bench
--   - the hall's east rail is split for the two gaps; small invisible ramps over the floor step
-- Model: Workspace.Hongdae_Layout.BumperCarQueue (rebuilt on every run). Chain step: after
-- park_expand_1113 (last).

local CS = game:GetService("CollectionService")
local layout = workspace:WaitForChild("Hongdae_Layout")
local old = layout:FindFirstChild("BumperCarQueue")
if old then old:Destroy() end
local M = Instance.new("Model")
M.Name = "BumperCarQueue"
M.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local G = 16.2 -- ground top here
local STEEL = Color3.fromRGB(200, 204, 210)
local YELLOW = Color3.fromRGB(250, 196, 40)
local ORANGE = Color3.fromRGB(245, 140, 30)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
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
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.collide == true
	p.CanTouch = false
	p.CastShadow = opts.shadow == true
	if opts.shape then (p :: Part).Shape = opts.shape end
	if opts.t then p.Transparency = opts.t end
	p.Parent = opts.parent or M
	return p
end

local function gui(p: BasePart, face: Enum.NormalId, ppu: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppu
	g.LightInfluence = 0.3
	g.Parent = p
	return g
end
local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, color: Color3, bg: Color3?, font: Enum.Font?)
	local l = Instance.new("TextLabel")
	l.Position, l.Size = pos, size
	l.BackgroundTransparency = if bg then 0 else 1
	if bg then l.BackgroundColor3 = bg end
	l.Text = text
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBlack
	l.TextColor3 = color
	l.Parent = parent
	return l
end

------------------------------------------------------------------ floor
local FX0, FX1, FZ0, FZ1 = -205, -181, -392, -292
local floor = part("CheckerFloor", Vector3.new(FX1 - FX0, 0.1, FZ1 - FZ0), CFrame.new((FX0 + FX1) / 2, G + 0.05, (FZ0 + FZ1) / 2), Color3.fromRGB(235, 235, 235))
do
	local g = gui(floor, Enum.NormalId.Top, 4)
	local grid = Instance.new("UIGridLayout")
	local TILE = 3
	local cols, rows = math.floor((FX1 - FX0) / TILE), math.floor((FZ1 - FZ0) / TILE)
	grid.CellSize = UDim2.fromScale(1 / rows, 1 / cols)
	grid.CellPadding = UDim2.new()
	grid.FillDirectionMaxCells = rows
	grid.Parent = g
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if (r + c) % 2 == 0 then Color3.fromRGB(20, 20, 22) else Color3.fromRGB(240, 240, 240)
			f.Parent = g
		end
	end
end

------------------------------------------------------------------ rails
-- a rail line from (x, za) to (x, zb) along Z or from (xa, z) to (xb, z) along X
local function railZ(x: number, za: number, zb: number)
	local len = math.abs(zb - za)
	local zc = (za + zb) / 2
	for _, h in ipairs({ 1.6, 3.3 }) do
		part("QueueRail", Vector3.new(len, 0.18, 0.18), CFrame.new(x, G + h, zc) * CFrame.Angles(0, math.rad(90), 0), STEEL, { mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	end
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		local z = za + (zb - za) * i / n
		part("QueuePost", Vector3.new(3.4, 0.24, 0.24), CFrame.new(x, G + 1.7, z) * CFrame.Angles(0, 0, math.rad(90)), STEEL, { mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	end
	part("QueueBlocker", Vector3.new(0.4, 7, len), CFrame.new(x, G + 3.5, zc), STEEL, { collide = true, t = 1 })
end
local function railX(xa: number, xb: number, z: number)
	local len = math.abs(xb - xa)
	local xc = (xa + xb) / 2
	for _, h in ipairs({ 1.6, 3.3 }) do
		part("QueueRail", Vector3.new(len, 0.18, 0.18), CFrame.new(xc, G + h, z), STEEL, { mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	end
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		local x = xa + (xb - xa) * i / n
		part("QueuePost", Vector3.new(3.4, 0.24, 0.24), CFrame.new(x, G + 1.7, z) * CFrame.Angles(0, 0, math.rad(90)), STEEL, { mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	end
	part("QueueBlocker", Vector3.new(len, 7, 0.4), CFrame.new(xc, G + 3.5, z), STEEL, { collide = true, t = 1 })
end

-- lanes (x): -203 | -199 | -195 | -191 | -187 | -183 ; south fence z -320, north fence z -388
railZ(-183, -320, -388) -- east outer
railZ(-187, -320, -384) -- gap north
railZ(-191, -324, -388) -- gap south
railZ(-195, -320, -384) -- gap north
railZ(-199, -324, -388) -- gap south
railZ(-203, -320, -384) -- west outer: gap north to the boarding gate
railX(-205, -183, -388) -- north fence (to the hall rail)
railX(-205, -187, -320) -- south fence (the east lane is the entrance)
railZ(-187, -296, -320) -- divider: exit (west) | entrance (east)
railZ(-181, -300, -320) -- entrance lane's east side

------------------------------------------------------------------ the hall's east rail: two gaps
local blockout = layout:FindFirstChild("ParkBlockout")
local hall = blockout and blockout:FindFirstChild("04_BumperCars")
if hall then
	for _, r in ipairs(hall:GetChildren()) do
		if r:IsA("BasePart") and r.Name == "Rail" and math.abs(r.Position.X + 206.5) < 0.6 then
			local thick, h, y, color = 2.7, r.Size.Y, r.Position.Y, r.Color
			local mat = r.Material
			r:Destroy()
			for _, seg in ipairs({ { -399, -388 }, { -384, -300 }, { -296, -292.4 } }) do
				local p = Instance.new("Part")
				p.Name = "Rail"
				p.Anchored = true
				p.Size = Vector3.new(thick, h, seg[2] - seg[1])
				p.CFrame = CFrame.new(-206.5, y, (seg[1] + seg[2]) / 2)
				p.Color, p.Material = color, mat
				p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				p.Parent = hall
			end
			break
		end
	end
end
-- ramps over the hall floor's step (floor top 18) at both gaps
for _, zc in ipairs({ -386, -298 }) do
	local w = Instance.new("WedgePart")
	w.Name = "GapRamp"
	w.Anchored, w.Transparency = true, 1
	-- from the ground at x -202.95 up to the hall floor's edge (x -206.45, top 18)
	w.Size = Vector3.new(4, 1.8, 3.5)
	w.CFrame = CFrame.new(-204.7, G + 0.9, zc) * CFrame.Angles(0, math.rad(90), 0)
	w.Parent = M
end

------------------------------------------------------------------ header, columns, signs
local HZ = -296
local beam = part("HeaderBeam", Vector3.new(26, 4, 1.2), CFrame.new(-193, G + 13, HZ), YELLOW, { collide = false, shadow = true })
do
	local g = gui(beam, Enum.NormalId.Back, 20)
	local band = Instance.new("Frame")
	band.Size = UDim2.fromScale(1, 1)
	band.BackgroundColor3 = YELLOW
	band.BorderSizePixel = 0
	band.Parent = g
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(1 / 26, 1 / 4)
	grid.CellPadding = UDim2.new()
	grid.Parent = band
	for i = 0, 26 * 4 - 1 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = if (i + math.floor(i / 26)) % 2 == 0 then YELLOW else ORANGE
		f.Parent = band
	end
	local over = Instance.new("Frame")
	over.Size = UDim2.fromScale(1, 1)
	over.BackgroundTransparency = 1
	over.ZIndex = 2
	over.Parent = g
	label(over, "EXIT  출구  ◀◀", UDim2.fromScale(0.03, 0.18), UDim2.fromScale(0.4, 0.64), Color3.fromRGB(220, 30, 40), Color3.new(1, 1, 1)).ZIndex = 3
	label(over, "▶▶  ENTRANCE  입구", UDim2.fromScale(0.57, 0.18), UDim2.fromScale(0.4, 0.64), Color3.fromRGB(20, 20, 22), Color3.new(1, 1, 1)).ZIndex = 3
end
-- the big BUMPER CAR sign over the beam
local sign = part("BumperSign", Vector3.new(14, 4.5, 0.6), CFrame.new(-193, G + 17.5, HZ), Color3.fromRGB(200, 30, 40), { shadow = true })
do
	local g = gui(sign, Enum.NormalId.Back, 24)
	label(g, "🏎 BUMPER CAR", UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.8), Color3.fromRGB(255, 230, 90))
end
-- red-white checker columns at both ends
for _, x in ipairs({ -205.5, -180.5 }) do
	local col = part("CheckerColumn", Vector3.new(1.6, 15, 1.6), CFrame.new(x, G + 7.5, HZ), Color3.new(1, 1, 1), { collide = true, shadow = true })
	for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local g = gui(col, face, 10)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromScale(1 / 2, 1 / 18)
		grid.CellPadding = UDim2.new()
		grid.Parent = g
		for i = 0, 35 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if (i + math.floor(i / 2)) % 2 == 0 then Color3.fromRGB(210, 30, 40) else Color3.new(1, 1, 1)
			f.Parent = g
		end
	end
end
-- height board (키 재기) by the entrance, facing the path
local board = part("HeightBoard", Vector3.new(3, 9, 0.3), CFrame.new(-178.5, G + 4.5, -306) * CFrame.Angles(0, math.rad(-90), 0), Color3.new(1, 1, 1), { collide = true })
do
	local g = gui(board, Enum.NormalId.Front, 30)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0.35, 1)
	bar.BackgroundColor3 = Color3.fromRGB(220, 40, 50)
	bar.BorderSizePixel = 0
	bar.Parent = g
	label(g, "키 재기\n125", UDim2.fromScale(0.38, 0.05), UDim2.fromScale(0.6, 0.25), Color3.fromRGB(30, 30, 40))
	local mark = Instance.new("Frame")
	mark.Position = UDim2.fromScale(0, 0.42)
	mark.Size = UDim2.new(1, 0, 0, 4)
	mark.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	mark.BorderSizePixel = 0
	mark.Parent = g
	label(g, "이 선보다 커야 탑승!", UDim2.fromScale(0.38, 0.46), UDim2.fromScale(0.6, 0.12), Color3.fromRGB(220, 40, 50), nil, Enum.Font.GothamBold)
end
-- a teal bench against the hall's south rail, out of the exit's way, facing the path
do
	local b = Instance.new("Model")
	b.Name = "QueueBench"
	b.Parent = M
	local TEAL = Color3.fromRGB(40, 200, 190)
	local bx, bz = -216, -289.5
	part("BenchSeat", Vector3.new(7, 0.4, 1.8), CFrame.new(bx, G + 1.6, bz), TEAL, { parent = b, collide = true, mat = Enum.Material.Metal })
	part("BenchBack", Vector3.new(7, 2.4, 0.3), CFrame.new(bx, G + 3, bz - 0.85), TEAL, { parent = b, mat = Enum.Material.Metal })
	for _, dx in ipairs({ -3.2, 3.2 }) do
		part("BenchLeg", Vector3.new(0.3, 1.6, 1.6), CFrame.new(bx + dx, G + 0.8, bz), TEAL, { parent = b, mat = Enum.Material.Metal })
	end
	local seat = Instance.new("Seat")
	seat.Name = "BenchSit"
	seat.Anchored, seat.Transparency = true, 1
	seat.Size = Vector3.new(6, 0.2, 1.4)
	seat.CFrame = CFrame.new(bx, G + 1.85, bz) * CFrame.Angles(0, math.rad(180), 0)
	seat.Parent = b
end

M.Parent = layout
local n = 0
for _, d in ipairs(M:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print("[park_bumper_queue_1114] parts:", n)
return n
