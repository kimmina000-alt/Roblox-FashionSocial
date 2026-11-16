--!nocheck
-- 범퍼카장을 부지 폭에 맞게 키우기 (D-1512, user 2026-11-16 + a top view with a red box under the hall's
-- south half, as wide as the park, and an arrow south: "범퍼카 놀이공원 부지에 거의 딱 맞게 범퍼카 장소 사이즈
-- 키우기. 출입구 방향은 화살표 방향으로. 범퍼카 이미지 들어간 벽은 북쪽으로"; asked: the box is the new place,
-- the picture twice side by side).
-- The arena (Workspace["범퍼"]["04_BumperCars"]) gets the box: floor x X0..X1, z Z0..Z1 (the park's walls'
-- beds are just outside the roof's eaves). The rails (invisible walls) are laid again on the floor's edges,
-- with an 11-stud gap in the middle of the south rail; the entrance (ramp, sign posts, sign) turns from the
-- east side to that gap and is renamed SouthEntrance, so park_bumper_dress_1115 puts the marquee over the
-- south eave. The six cylinders keep their place from the floor's north-west corner. Things of 놀이공원길
-- under the new hall are set aside in ServerStorage.ParkMoveRemoved_1116 (attribute FromPath).
-- Run park_bumper_dress_1115 right after (it rebuilds ArenaDress from the floor). Idempotent.

local X0, X1, Z0, Z1 = -253, -65, -760, -645
local GAP = 11
local ENT_X = -95 -- (D-1516, user: "범퍼카 출입구 동쪽으로 옮기기": the gap east of the middle, -159)
local G = 16.06

local hall = workspace:FindFirstChild("범퍼")
local area = hall and hall:FindFirstChild("04_BumperCars")
local floor = area and area:FindFirstChild("Floor")
assert(floor, "no 범퍼.04_BumperCars.Floor")

local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local function bb(m: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	local list = if m:IsA("BasePart") then { m } else m:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") then
			local a, b = ext(p)
			lo, hi = lo:Min(a), hi:Max(b)
		end
	end
	return lo, hi
end

local flo, fhi = ext(floor)
local oldX0, oldZ0 = flo.X, flo.Z
local FY = fhi.Y
local done = {}
if math.abs(oldX0 - X0) > 0.05 or math.abs(oldZ0 - Z0) > 0.05 or math.abs(fhi.X - X1) > 0.05 or math.abs(fhi.Z - Z1) > 0.05 then
	local d = Vector3.new(X0 - oldX0, 0, Z0 - oldZ0)
	-- the floor
	floor.Size = Vector3.new(X1 - X0, floor.Size.Y, Z1 - Z0)
	floor.CFrame = CFrame.new((X0 + X1) / 2, floor.Position.Y, (Z0 + Z1) / 2)
	-- the rails again: one proto, then north / west / east whole and the south in two
	local proto
	for _, r in ipairs(area:GetChildren()) do
		if r:IsA("BasePart") and r.Name == "Rail" then
			proto = proto or r:Clone()
			r:Destroy()
		end
	end
	local RY, RH, T = proto.Position.Y, proto.Size.Y, 2.7
	local function rail(x0: number, x1: number, z0: number, z1: number)
		local p = proto:Clone()
		p.Size = Vector3.new(x1 - x0, RH, z1 - z0)
		p.CFrame = CFrame.new((x0 + x1) / 2, RY, (z0 + z1) / 2)
		p.Parent = area
	end
	local CX = (X0 + X1) / 2
	rail(X0 - T / 2, X1 + T / 2, Z0 - T / 2, Z0 + T / 2)
	rail(X0 - T / 2, X0 + T / 2, Z0, Z1)
	rail(X1 - T / 2, X1 + T / 2, Z0, Z1)
	rail(X0 + T / 2, ENT_X - GAP / 2, Z1 - T / 2, Z1 + T / 2)
	rail(ENT_X + GAP / 2, X1 - T / 2, Z1 - T / 2, Z1 + T / 2)
	-- the old hidden roof and posts on the new corners
	local k = 0
	for _, p in ipairs(area:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Post" then
			k += 1
			local x = if k <= 2 then X1 - 1.6 else X0 + 1.6
			local z = if k % 2 == 1 then Z1 - 1.6 else Z0 + 1.6
			p.CFrame = CFrame.new(x, p.Position.Y, z)
		elseif p:IsA("BasePart") and p.Name == "Roof" then
			p.Size = Vector3.new(X1 - X0 + 4.4, p.Size.Y, Z1 - Z0 + 4.4)
			p.CFrame = CFrame.new(CX, p.Position.Y, (Z0 + Z1) / 2)
		end
	end
	-- the cylinders keep their place from the north-west corner
	for _, c in ipairs(hall:GetChildren()) do
		if c:IsA("BasePart") and c.Name == "Cylinder" then c.CFrame += d end
	end
	-- the entrance: turned from the east (+x out) to the south (+z out), in the south rail's gap
	local ent = hall:FindFirstChild("EastEntrance") or hall:FindFirstChild("SouthEntrance")
	local ramp = ent and ent:FindFirstChild("EntranceRamp")
	if ramp then
		local run = ramp.Size.Z
		local rise = FY - G
		local newC = Vector3.new(ENT_X, G + rise / 2, Z1 + run / 2)
		-- the ramp's look vector points out of the hall; its frame without the ramp's own turn
		local out = ramp.CFrame.LookVector
		local oldFrame = CFrame.lookAt(ramp.Position, ramp.Position + Vector3.new(out.X, 0, out.Z))
		local newFrame = CFrame.lookAt(newC, newC + Vector3.zAxis)
		for _, p in ipairs(ent:GetDescendants()) do
			if p:IsA("BasePart") then p.CFrame = newFrame * oldFrame:ToObjectSpace(p.CFrame) end
		end
		ramp.Size = Vector3.new(GAP, rise, run)
		ramp.CFrame = CFrame.lookAt(newC, newC + Vector3.zAxis)
		ent.Name = "SouthEntrance"
	end
	table.insert(done, ("floor x %.1f..%.1f z %.1f..%.1f"):format(X0, X1, Z0, Z1))
end

-- 놀이공원길 under the new hall (with its eaves and the ramp) set aside; the long wall beds stay
local keep = game.ServerStorage:FindFirstChild("ParkMoveRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkMoveRemoved_1116"
keep.Parent = game.ServerStorage
local paths = workspace:FindFirstChild("놀이공원길")
local aside = 0
for _, folder in ipairs(paths and paths:GetChildren() or {}) do
	if folder.Name ~= "Ground" then
		for _, c in ipairs(folder:GetChildren()) do
			local l, h = bb(c)
			if l.X < X1 + 3 and h.X > X0 - 3 and l.Z < Z1 + 6 and h.Z > Z0 - 5 and h.X - l.X < 120 and h.Z - l.Z < 200 then
				c:SetAttribute("FromPath", c.Parent:GetFullName())
				c.Parent = keep
				aside += 1
			end
		end
	end
end
table.insert(done, ("set aside %d"):format(aside))
print("[park_bumper_big_1116] " .. table.concat(done, "; "))
return #done
