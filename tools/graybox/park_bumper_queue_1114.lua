-- (D-1407, user 2026-11-14, photos of an indoor bumper car hall: "범퍼카 대기줄 구현해"; D-1408, the
-- user's sketch: "범퍼카 입구랑 출구 위치 변경. 놀이터 자체를 오른쪽으로 이동하고 입구 복도로 사용.
-- 바닥에 체크 무늬 삭제. 펜스만 유지. 웨이팅줄 5칸인 거 2칸으로 수정.") The bumper car queue on the
-- east side of the bumper car hall (Hongdae_Layout.ParkBlockout["04_BumperCars"], hall floor
-- x -277.5..-206.5, z -399..-292.4, its east rail at x -206.5), stainless fences only:
--   - ENTRANCE: a corridor from the park's front (x -128, between the gate and the hall) west
--     along z -292.5..-302 (where the playground stood; park_playground_1114 moves it north)
--   - two switchback lanes as wide as the corridor (9.5, D-1409) by the hall: in at the south
--     end of the east lane, north, back south in the west lane to the
--     boarding gap in the hall's east rail at z -304..-300 (clear of the hall's corner post)
--   - EXIT: a gap in the hall's east rail at z -392..-388 (clear of the corner post), out east
--     along the playground's south
--   - stainless posts and two tube rails, an invisible 7-stud wall on every fence line; the
--     hall's east rail is split for the two gaps; invisible ramps over the hall floor's step
-- Model: Workspace.Hongdae_Layout.BumperCarQueue (rebuilt on every run). Chain step: after
-- park_playground_1114 (last).

local layout = workspace:WaitForChild("Hongdae_Layout")
local old = layout:FindFirstChild("BumperCarQueue")
if old then old:Destroy() end
local M = Instance.new("Model")
M.Name = "BumperCarQueue"
M.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local G = 16.2 -- ground top here
local STEEL = Color3.fromRGB(200, 204, 210)

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
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.collide == true
	p.CanTouch = false
	p.CastShadow = false
	if opts.shape then (p :: Part).Shape = opts.shape end
	if opts.t then p.Transparency = opts.t end
	p.Parent = M
	return p
end

-- a fence line from a to b (on the ground plane), posts every ~6 studs
local function fence(ax: number, az: number, bx: number, bz: number)
	local a, b = Vector3.new(ax, 0, az), Vector3.new(bx, 0, bz)
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	local along = CFrame.lookAt(mid, b) -- LookVector along the line
	for _, h in ipairs({ 1.6, 3.3 }) do
		part("QueueRail", Vector3.new(len, 0.2, 0.2), (along + Vector3.new(0, G + h, 0)) * CFrame.Angles(0, math.rad(90), 0), STEEL, { mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	end
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		local p = a + d * (i / n)
		part("QueuePost", Vector3.new(3.4, 0.28, 0.28), CFrame.new(p.X, G + 1.7, p.Z) * CFrame.Angles(0, 0, math.rad(90)), STEEL, { mat = Enum.Material.Metal, shape = Enum.PartType.Cylinder })
	end
	part("QueueBlocker", Vector3.new(0.4, 7, len), along + Vector3.new(0, G + 3.5, 0), STEEL, { collide = true, t = 1 })
end

-- (D-1409, user: "웨이팅 줄 간격 입구 간격이랑 동일하게") every lane as wide as the corridor
-- (9.5): west lane x -205.15..-195.7 (from the hall rail's face), east lane x -195.7..-186.2,
-- the turn at the north end 9.5 too
local W = 9.5
local XD, XO = -205.15 + W, -205.15 + 2 * W -- the divider and the east lane's outer side
fence(-206.2, -292.5, -128, -292.5) -- the lanes' south ends + the corridor's south side
fence(XO, -292.5 - W, -128, -292.5 - W) -- the corridor's north side
fence(XD, -292.5, XD, -376 + W) -- between the lanes (turn at the north end)
fence(XO, -292.5 - W, XO, -376) -- the east lane's outer side
fence(-206.2, -376, XO, -376) -- north end

------------------------------------------------------------------ the hall's east rail: two gaps
local blockout = layout:FindFirstChild("ParkBlockout")
local hall = blockout and blockout:FindFirstChild("04_BumperCars")
if hall then
	local proto: BasePart? = nil
	for _, r in ipairs(hall:GetChildren()) do
		if r:IsA("BasePart") and r.Name == "Rail" and math.abs(r.Position.X + 206.5) < 0.6 then
			proto = proto or r:Clone()
			r:Destroy()
		end
	end
	if proto then
		for _, seg in ipairs({ { -399, -392 }, { -388, -304 }, { -300, -292.4 } }) do
			local p = (proto :: BasePart):Clone()
			p.Size = Vector3.new(2.7, p.Size.Y, seg[2] - seg[1])
			p.CFrame = CFrame.new(-206.5, p.Position.Y, (seg[1] + seg[2]) / 2)
			p.Parent = hall
		end
	end
end
-- ramps over the hall floor's step (floor top 18) at both gaps
for _, zc in ipairs({ -302, -390 }) do
	local w = Instance.new("WedgePart")
	w.Name = "GapRamp"
	w.Anchored, w.Transparency = true, 1
	w.Size = Vector3.new(4, 1.8, 3.5)
	w.CFrame = CFrame.new(-204.7, G + 0.9, zc) * CFrame.Angles(0, math.rad(90), 0)
	w.Parent = M
end

M.Parent = layout
local n = 0
for _, d in ipairs(M:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print("[park_bumper_queue_1114] parts:", n)
return n
