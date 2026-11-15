--!nocheck
-- 피스 트레인 (D-1481, user 2026-11-16: "01_PeaceTrain 첨부한 사진 참고해서 저 위치에 레일 만들고 그냥 박스로 트레인
-- 만들어서 테스트. 3d 만들어서 줄게.", with a photo of a kiddie train on a green track raised on yellow posts and a
-- red line drawn round its place: a closed loop up the west side, round the top, and back down in an S).
-- Workspace["피스트레인"] (tag ParkTrain, Hongdae_Layout's ParkBlockout["01_PeaceTrain"] removed):
--   * the track: a closed Catmull-Rom loop through PTS (x, z), two green tube rails on green ties, raised
--     RAIL_Y on yellow posts;
--   * the train: Car1 (engine) .. Car5, plain boxes for now (the user's 3D comes later: swap the Car
--     models, pivot = the bottom middle on the rail top, facing -z of its pivot... CFrame.lookAt forward);
--   * the path for ParkRidesController: attribute PathData "x,y,z;…" (rail-top middle every ~1.5),
--     Period (one lap, s), CarGap (between car pivots). Model streaming Atomic.
-- No boarding yet (a test ride). Rebuilt each run. Edit mode; after park_compact_1116, before park_paths_1116.

local CollectionService = game:GetService("CollectionService")
local G = 16.06
local RAIL_Y = 2.4 -- (rail top over the paving)
local GAUGE = 1.7
local SPEED = 7 -- (studs a second)
local CAR_L, CAR_W, CAR_H = 3.6, 2.6, 1.9
local CAR_GAP = 4.3
-- the loop, traced from the user's red line: (u, v) = west → east, south → north inside the plot
-- x -282 .. -227, z -514 .. -719 (the track's middle line; the posts keep inside)
local X0, X1, ZS, ZN = -282, -227, -514, -719
local UV = {
	{ 0.05, 0.30 }, { 0.17, 0.60 }, { 0.36, 0.86 }, { 0.62, 0.98 }, { 0.90, 0.90 }, { 0.99, 0.70 },
	{ 0.80, 0.57 }, { 0.74, 0.44 }, { 0.77, 0.30 }, { 0.64, 0.24 }, { 0.58, 0.40 }, { 0.42, 0.44 },
	{ 0.38, 0.27 }, { 0.55, 0.13 }, { 0.50, 0.02 }, { 0.33, 0.03 }, { 0.17, 0.14 },
}
local GREEN = Color3.fromRGB(46, 160, 60)
local YELLOW = Color3.fromRGB(250, 200, 30)

local bo = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ParkBlockout")
local blockout = bo and bo:FindFirstChild("01_PeaceTrain")
if blockout then blockout:Destroy() end
local old = workspace:FindFirstChild("피스트레인")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "피스트레인"
local fTrack = Instance.new("Model")
fTrack.Name = "Track"
fTrack.Parent = root

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function tube(parent: Instance, name: string, a: Vector3, b: Vector3, d: number, color: Color3)
	local L = (b - a).Magnitude
	if L < 0.05 then return end
	part(parent, name, Vector3.new(L + 0.05, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

-- the closed spline, sampled densely, then resampled every STEP along its length
local ctrl = {}
for _, uv in ipairs(UV) do table.insert(ctrl, Vector3.new(X0 + (X1 - X0) * uv[1], 0, ZS + (ZN - ZS) * uv[2])) end
local n = #ctrl
local dense = {}
for i = 1, n do
	local p0, p1, p2, p3 = ctrl[(i - 2) % n + 1], ctrl[i], ctrl[i % n + 1], ctrl[(i + 1) % n + 1]
	for k = 0, 19 do
		local t = k / 20
		local t2, t3 = t * t, t * t * t
		table.insert(dense, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
	end
end
local STEP = 1.5
local pts = { dense[1] }
local carry = 0
for i = 2, #dense + 1 do
	local a, b = dense[i - 1], dense[(i - 1) % #dense + 1]
	local seg = (b - a).Magnitude
	local s = STEP - carry
	while s <= seg do
		table.insert(pts, a:Lerp(b, s / seg))
		s += STEP
	end
	carry = seg - (s - STEP)
end
if (pts[#pts] - pts[1]).Magnitude < STEP * 0.5 then table.remove(pts) end
local railTop = G + RAIL_Y
local length = 0
for i = 1, #pts do
	pts[i] = Vector3.new(pts[i].X, railTop, pts[i].Z)
end
for i = 1, #pts do length += (pts[i % #pts + 1] - pts[i]).Magnitude end

-- rails every 3 samples (4.5 studs), ties every 2, posts every 6
local np = #pts
local function at(i: number): Vector3 return pts[(i - 1) % np + 1] end
local function side(i: number): Vector3
	local f = (at(i + 1) - at(i - 1))
	return Vector3.new(-f.Z, 0, f.X).Unit
end
local R = 0.32
for i = 1, np, 3 do
	local j = i + 3
	for _, s in ipairs({ -1, 1 }) do
		tube(fTrack, "Rail", at(i) + side(i) * s * GAUGE / 2 - Vector3.new(0, R, 0), at(j) + side(j) * s * GAUGE / 2 - Vector3.new(0, R, 0), R * 2, GREEN)
	end
	tube(fTrack, "Spine", at(i) - Vector3.new(0, 0.9, 0), at(j) - Vector3.new(0, 0.9, 0), 0.5, GREEN)
end
for i = 1, np, 2 do
	local c = at(i) - Vector3.new(0, 0.9 - 0.05, 0)
	local f = at(i + 1) - at(i - 1)
	part(fTrack, "Tie", Vector3.new(GAUGE + 0.5, 0.18, 0.3), CFrame.lookAt(c, c + Vector3.new(f.X, 0, f.Z)) + Vector3.new(0, 0.4, 0), GREEN, Enum.Material.Metal)
end
for i = 1, np, 6 do
	local c = at(i)
	part(fTrack, "Post", Vector3.new(0.45, RAIL_Y - 0.9, 0.45), CFrame.new(c.X, G + (RAIL_Y - 0.9) / 2, c.Z), YELLOW, Enum.Material.Metal)
	part(fTrack, "PostFoot", Vector3.new(1.1, 0.12, 1.1), CFrame.new(c.X, G + 0.06, c.Z), YELLOW, Enum.Material.Metal)
end

-- the train: an engine and four boxes in bright colours (test cars)
local COLORS = { Color3.fromRGB(214, 36, 40), Color3.fromRGB(70, 180, 70), Color3.fromRGB(250, 200, 30), Color3.fromRGB(60, 120, 230), Color3.fromRGB(230, 90, 180) }
local acc = { 0 }
for i = 2, np + 1 do acc[i] = acc[i - 1] + (at(i) - at(i - 1)).Magnitude end
local function along(s: number): Vector3
	s %= length
	for i = 2, #acc do
		if acc[i] >= s then
			local span = acc[i] - acc[i - 1]
			return at(i - 1):Lerp(at(i), if span > 0 then (s - acc[i - 1]) / span else 0)
		end
	end
	return at(1)
end
for k = 1, #COLORS do
	local car = Instance.new("Model")
	car.Name = "Car" .. k
	local col = COLORS[k]
	part(car, "Chassis", Vector3.new(CAR_W, 0.35, CAR_L), CFrame.new(0, 0.35 / 2 + 0.05, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	if k == 1 then
		part(car, "Body", Vector3.new(CAR_W - 0.2, 1.3, CAR_L * 0.55), CFrame.new(0, 0.4 + 0.65, -CAR_L * 0.2), col)
		part(car, "Cab", Vector3.new(CAR_W - 0.2, CAR_H, CAR_L * 0.4), CFrame.new(0, 0.4 + CAR_H / 2, CAR_L * 0.28), col)
		part(car, "CabRoof", Vector3.new(CAR_W + 0.2, 0.2, CAR_L * 0.5), CFrame.new(0, 0.4 + CAR_H + 0.1, CAR_L * 0.28), YELLOW)
		part(car, "Chimney", Vector3.new(0.9, 0.7, 0.7), CFrame.new(0, 0.4 + 1.3 + 0.45, -CAR_L * 0.32) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(car, "Lamp", Vector3.new(0.6, 0.6, 0.2), CFrame.new(0, 0.4 + 0.9, -CAR_L / 2 + 0.1), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	else
		part(car, "Tub", Vector3.new(CAR_W, 1.1, CAR_L - 0.2), CFrame.new(0, 0.4 + 0.55, 0), col)
		part(car, "Seat", Vector3.new(CAR_W - 0.6, 0.3, 1.1), CFrame.new(0, 0.4 + 0.9, 0.5), Color3.fromRGB(245, 245, 245))
		part(car, "Rim", Vector3.new(CAR_W + 0.15, 0.2, CAR_L - 0.05), CFrame.new(0, 0.4 + 1.15, 0), Color3.fromRGB(245, 245, 245))
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -CAR_L * 0.3, CAR_L * 0.3 }) do
			part(car, "Wheel", Vector3.new(0.3, 0.7, 0.7), CFrame.new(s * (GAUGE / 2), -0.05, z), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	-- pivot = the bottom middle (on the rail top), forward = -z (CFrame.lookAt)
	car.WorldPivot = CFrame.new()
	local s = -(k - 1) * CAR_GAP
	local m, f, b = along(s), along(s + 1.4), along(s - 1.4)
	car:PivotTo(CFrame.lookAt(m, m + (f - b)))
	car.Parent = root
end

local data = table.create(np)
for i = 1, np do data[i] = ("%.2f,%.2f,%.2f"):format(pts[i].X, pts[i].Y, pts[i].Z) end
root:SetAttribute("PathData", table.concat(data, ";"))
root:SetAttribute("Period", math.floor(length / SPEED + 0.5))
root:SetAttribute("CarGap", CAR_GAP)
root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
root.WorldPivot = CFrame.new((X0 + X1) / 2, G, (ZS + ZN) / 2)
CollectionService:AddTag(root, "ParkTrain")
root.Parent = workspace
local count = 0
for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
print(("[park_peace_train_1116] track %.0f studs, lap %d s, %d parts"):format(length, root:GetAttribute("Period"), count))
return count
