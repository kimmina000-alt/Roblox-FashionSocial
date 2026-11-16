--!nocheck
-- 놀이공원 피드백 (D-1545 / D-1546, user 2026-11-16, phone screenshots). A post-pass after the park scripts (before
-- park_perf_1116); safe to run again:
--   * 소방차: the rider sits 1.2 studs further forward, nearer the truck's middle (SeatBack -1.2; the
--     body's middle is 1.7 ahead of the old seat point);
--   * 회전목마: thinner glow lines (the mirror frames 0.08 round the mirror, was 0.3; the pole foot discs
--     1.2 across, were 1.9), white horse ears (HorseHorn);
--   * 점핑스타: you get off just outside the fence's opening (east side), not inside the fence;
--   * 관람차: the cabins' Bench blocks go (the user's cabin mesh has its own seats; the riders sit a
--     little lower, ParkConfig.CabinSeats);
--   * 범퍼카: the fence panels no longer overlap (each panel as long as the gap to its neighbour less
--     0.15: they were 8.1 long on 7.63 centres); 12 cars in two rows of six on the right (east) half
--     along the back wall (the six placed cars plus a copy of each); the back wall's picture is ONE
--     image, centred and cropped (was two side by side).
-- (Place-only: the cars and their copies are in Workspace.Scene; save the place.)

local CS = game:GetService("CollectionService")
local out = {}

---------------------------------------------------------------- 소방차
local truck = workspace:FindFirstChild("소방차")
if truck then
	truck:SetAttribute("SeatBack", -1.2)
	table.insert(out, "firetruck seat forward")
end

---------------------------------------------------------------- 회전목마
local horns, glows, feet = 0, 0, 0
for _, carousel in ipairs(CS:GetTagged("ParkCarousel")) do
	if carousel:IsDescendantOf(workspace) then -- (the 소방차 is a carousel too: it has none of these parts)
		for _, d in ipairs(carousel:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "HorseHorn" then
					d.Color = Color3.fromRGB(248, 248, 246)
					if d:IsA("MeshPart") then d.TextureID = "" end
					horns += 1
				elseif d.Name == "MirrorGlow" then
					local mirror = d.Parent and d.Parent:FindFirstChild("Mirror")
					local base = if mirror and mirror:IsA("BasePart") then mirror.Size else Vector3.new(2.4, 3.8, 0.12)
					d.Size = Vector3.new(base.X + 0.16, base.Y + 0.16, d.Size.Z)
					glows += 1
				elseif d.Name == "PoleFootLight" then
					d.Size = Vector3.new(d.Size.X, 1.2, 1.2)
					feet += 1
				end
			end
		end
	end
end
table.insert(out, ("carousel: %d ears white, %d mirror frames, %d foot discs"):format(horns, glows, feet))

---------------------------------------------------------------- 점핑스타
for _, ride in ipairs(CS:GetTagged("ParkJumpStar")) do
	if ride:IsDescendantOf(workspace) then
		-- the fence is an octagon round the tower with its east side open: just outside that opening
		local pivot = ride:GetPivot().Position
		ride:SetAttribute("Exit", Vector3.new(pivot.X + 14.2, pivot.Y + 3, pivot.Z))
		table.insert(out, "jumpstar exit at the opening")
	end
end

---------------------------------------------------------------- 관람차
local benches = 0
for _, wheel in ipairs(CS:GetTagged("ParkWheel")) do
	if wheel:IsDescendantOf(workspace) then
		for _, d in ipairs(wheel:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Bench" and d.Parent and d.Parent.Name:match("^Cabin%d+$") then
				d:Destroy()
				benches += 1
			end
		end
	end
end
table.insert(out, benches .. " cabin benches removed")

---------------------------------------------------------------- 회전컵 (D-1546)
-- (user: "회전컵 의자 블록 삭제 앉는 모션 기능은 유지 / 회전컵 내릴 때 위치 확인") the cups' Bench / BenchLeg
-- blocks go (the riders keep their seats: the Seat CFrames are attributes of the ride); getting off put
-- you east of the deck 7.8 studs up in the air: now at the foot of the NW steps, facing away from the cups
local cupBenches = 0
for _, ride in ipairs(CS:GetTagged("ParkTeaCups")) do
	if ride:IsDescendantOf(workspace) then
		for _, d in ipairs(ride:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "Bench" or d.Name == "BenchLeg") then
				d:Destroy()
				cupBenches += 1
			end
		end
		-- the lowest step of the flight nearest the gate (north-west), a little past it on the ground
		local centre = ride:GetPivot().Position
		local best, bestZ = nil, -math.huge
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Step" and d.Parent and d.Parent.Name == "Stairs" then
				local p = d.Position
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(centre.X, 0, centre.Z)).Magnitude < 40 and p.Z > centre.Z and d.Size.Y < 2 and p.Z > bestZ then
					best, bestZ = d, p.Z
				end
			end
		end
		if best then
			local out = Vector3.new(best.Position.X - centre.X, 0, best.Position.Z - centre.Z).Unit
			local foot = best.Position + out * 3.5
			ride:SetAttribute("Exit", Vector3.new(foot.X, 16.11 + 3, foot.Z))
		end
	end
end
table.insert(out, cupBenches .. " tea cup bench parts removed, exit at the NW steps")

---------------------------------------------------------------- 범퍼카 fences
local hall = { x0 = -262, x1 = -55, z0 = -775, z1 = -620 }
local panels = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "FencePanel" then
		local p = d.Position
		if p.X > hall.x0 and p.X < hall.x1 and p.Z > hall.z0 and p.Z < hall.z1 then table.insert(panels, d) end
	end
end
local function along(d: BasePart): string
	local l = d.CFrame.LookVector
	return if math.abs(l.X) > math.abs(l.Z) then "X" else "Z"
end
local shortened = 0
local newLength = {}
for _, a in ipairs(panels) do
	local ax = along(a)
	local across = if ax == "X" then "Z" else "X"
	local nearest = math.huge
	for _, b in ipairs(panels) do
		if b ~= a and along(b) == ax and math.abs(a.Position[across] - b.Position[across]) < 0.8 then
			nearest = math.min(nearest, math.abs(a.Position[ax] - b.Position[ax]))
		end
	end
	if nearest < a.Size.Z + 0.15 then newLength[a] = nearest - 0.15 end
end
for a, len in pairs(newLength) do
	a.Size = Vector3.new(a.Size.X, a.Size.Y, len)
	shortened += 1
end
table.insert(out, shortened .. " fence panels shortened")

---------------------------------------------------------------- 범퍼카 cars
local cars = {}
for _, m in ipairs(CS:GetTagged("BumperCar")) do
	if m:IsA("Model") and m:IsDescendantOf(workspace) then table.insert(cars, m) end
end
table.sort(cars, function(a, b) return a.Name < b.Name end)
if #cars > 0 and #cars < 12 then
	local originals = table.clone(cars)
	local k = 1
	while #cars < 12 do
		local src = originals[(k - 1) % #originals + 1]
		local copy = src:Clone()
		copy.Name = src.Name .. "_2"
		copy.Parent = src.Parent
		table.insert(cars, copy)
		k += 1
	end
end
-- two rows of six, nose to tail as placed (facing +X), on the right half by the back wall
local ROWS = { -751.2, -740.2 }
local X0, DX = -150, 12.5
for i, m in ipairs(cars) do
	if i > 12 then break end
	local row = math.floor((i - 1) / 6) + 1
	local col = (i - 1) % 6
	local pivot = m:GetPivot()
	local cf = m:GetBoundingBox()
	local offset = cf.Position - pivot.Position -- (the pivot sits away from the box's middle)
	local at = Vector3.new(X0 + col * DX, cf.Position.Y, ROWS[row])
	m:PivotTo(pivot.Rotation + (at - offset))
end
table.insert(out, #cars .. " bumper cars in two rows")

---------------------------------------------------------------- 범퍼카 back wall picture
local dress = workspace:FindFirstChild("범퍼") and workspace["범퍼"]:FindFirstChild("ArenaDress", true)
local wall = dress and dress:FindFirstChild("BackWall")
local mural = wall and wall:FindFirstChild("Mural")
if mural and mural:IsA("SurfaceGui") then
	local first: ImageLabel? = nil
	for _, c in ipairs(mural:GetChildren()) do
		if c:IsA("ImageLabel") then
			if not first then first = c else c:Destroy() end
		end
	end
	if first then
		first.Position = UDim2.fromScale(0, 0)
		first.Size = UDim2.fromScale(1, 1)
		first.ScaleType = Enum.ScaleType.Crop -- (fills the wall, the middle kept, the top / bottom cut)
		table.insert(out, "one centred picture on the back wall")
	end
end

print("[park_fixes3_1116] " .. table.concat(out, "; "))
return table.concat(out, "; ")
