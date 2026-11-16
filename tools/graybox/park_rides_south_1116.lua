--!nocheck
-- 회전컵 · 슈퍼바이킹 · 관람차를 입구 쪽으로 (D-1500, user 2026-11-16 + a top view with the three boxed
-- and an arrow down to a line just above the shops; asked: the arrow's way, toward the gate (south),
-- about 120).
-- The three move DZ (+z, south) together so the tea cups' south edge is 15 north of the 콜팝 stand
-- (z -376.3); the tea cups also move DX_CUPS east to keep 3 from the carousel. World-space
-- attributes go with them. Beds, hedges, trees, lamps and benches of 놀이공원길 under the new places
-- are set aside in ServerStorage.ParkMoveRemoved_1116 (attribute FromPath). Run after park_shops_1116.
-- Idempotent: a ride already at its new place (the tea cups' south edge near -376.3) is not moved.

local DZ = 123.5
local DX_CUPS = 6.4

local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local function bb(m: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	local list = if m:IsA("BasePart") then { m } else m:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local a, b = ext(p)
			lo, hi = lo:Min(a), hi:Max(b)
		end
	end
	return lo, hi
end
local function shiftAttrs(root: Instance, d: Vector3)
	for _, x in ipairs({ root, unpack(root:GetDescendants()) }) do
		for k, v in pairs(x:GetAttributes()) do
			if typeof(v) == "Vector3" and v.Magnitude > 150 then x:SetAttribute(k, v + d)
			elseif typeof(v) == "CFrame" and v.Position.Magnitude > 150 then x:SetAttribute(k, v + d) end
		end
	end
end
local function shift(m: Instance, d: Vector3)
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.CFrame += d end end
	if m:IsA("Model") then m.WorldPivot += d end
	for _, x in ipairs(m:GetDescendants()) do if x:IsA("Model") then x.WorldPivot += d end end
	shiftAttrs(m, d)
end

local cups = workspace:FindFirstChild("회전컵")
local viking = workspace:FindFirstChild("슈퍼바이킹")
local g6 = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("06_Park_Playground")
local wheel = g6 and g6:FindFirstChild("관 람 차 ")
assert(cups and viking and wheel, "a ride is missing")
local _, cupsHi = bb(cups)
if math.abs(cupsHi.Z - (-376.3)) < 1 then
	print("[park_rides_south_1116] already moved")
	return 0
end
shift(cups, Vector3.new(DX_CUPS, 0, DZ))
shift(viking, Vector3.new(0, 0, DZ))
shift(wheel, Vector3.new(0, 0, DZ))

local keep = game.ServerStorage:FindFirstChild("ParkMoveRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkMoveRemoved_1116"
keep.Parent = game.ServerStorage
local paths = workspace:FindFirstChild("놀이공원길")
local aside = 0
if paths then
	for _, r in ipairs({ cups, viking, wheel }) do
		local lo, hi = bb(r)
		for _, folder in ipairs(paths:GetChildren()) do
			if folder.Name ~= "Ground" then
				for _, c in ipairs(folder:GetChildren()) do
					if not c.Name:find("^Lawn") then
						local l, h = bb(c)
						if l.X < hi.X and h.X > lo.X and l.Z < hi.Z and h.Z > lo.Z and l.Y < lo.Y + 12 then
							c:SetAttribute("FromPath", c.Parent:GetFullName())
							c.Parent = keep
							aside += 1
						end
					end
				end
			end
		end
	end
end
print(("[park_rides_south_1116] moved 3 rides, set aside %d"):format(aside))
return 3
