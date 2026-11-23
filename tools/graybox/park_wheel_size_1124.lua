--!nocheck
-- 관람차 칸 크게 (D-1807, user 2026-11-24 after a player's note "관람차 너무 작아서 저 머리가 껴요 관람차
-- 크기늘려달라": "관람차 범퍼카 크기 수정")
--   * every Cabin<k> of the wheel (tag ParkWheel): the cabin mesh, its door and its floor grow by
--     K in the cabin's frame (X = the axle, Y = up, Z = across the wheel), from the cabin's bottom,
--     so the floor stays just over the boarding deck and the roof goes up (1.1 studs more head
--     room; the roof stays under the hanger bar at the hang point)
--   * the door's hinge attributes (HingeRel, DoorRel) are worked out again from the grown door, the
--     bottom cabin's door left open as park_wheel_cabins_1115 does
--   * ParkConfig.CabinSeats has the seats for this size (offset y -7.04, z ±3.25)
--   * the sizes the parts had before the first run are kept as attributes (Base*), so running it
--     again gives the same result; after park_wheel_cabins_1115 / park_fixes4_1117 rebuild the
--     cabins, run this again
-- Run in Edit mode, after park_fixes4_1117 (anywhere near the end of the chain). Idempotent.

local CollectionService = game:GetService("CollectionService")

local K = Vector3.new(1.25, 1.14, 1.25)
local BOTTOM = -9.6 -- (the cabin's bottom under the hang point: TOP -1.6 - HEIGHT 8, park_wheel_cabins_1115)
local OPEN = 1.65
local BOARD_ANGLE = math.rad(9)

local wheel
for _, m in ipairs(CollectionService:GetTagged("ParkWheel")) do
	if m:IsDescendantOf(workspace) then wheel = m end
end
assert(wheel, "no ParkWheel in Workspace")
local H = (wheel:FindFirstChild("Hub") :: BasePart).CFrame

-- a point / size of the cabin frame F grown from the bottom
local function growPoint(p: Vector3): Vector3
	return Vector3.new(p.X * K.X, BOTTOM + (p.Y - BOTTOM) * K.Y, p.Z * K.Z)
end
-- a part's size grown along F's axes (the part's axes are F's axes, up to their sign and order)
local function growSize(rel: CFrame, size: Vector3): Vector3
	local out = {}
	for i, axis in ipairs({ rel.RightVector, rel.UpVector, -rel.LookVector }) do
		local a = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
		local k = a.X * K.X + a.Y * K.Y + a.Z * K.Z
		out[i] = ({ size.X, size.Y, size.Z })[i] * k
	end
	return Vector3.new(out[1], out[2], out[3])
end

local n = 0
for k = 1, 64 do
	local cabin = wheel:FindFirstChild("Cabin" .. k)
	if not cabin then break end
	local F = H.Rotation + cabin:GetPivot().Position
	local mesh = cabin:FindFirstChild("CabinMesh") :: BasePart
	local door = cabin:FindFirstChild("CabinDoor") :: BasePart
	local floor = cabin:FindFirstChild("Floor") :: BasePart
	-- the parts as they were before the first run (the door closed)
	for _, p in ipairs({ mesh, floor }) do
		if p and p:GetAttribute("BaseSize") == nil then
			p:SetAttribute("BaseSize", p.Size)
			p:SetAttribute("BaseRel", F:ToObjectSpace(p.CFrame))
		end
	end
	if door and door:GetAttribute("BaseSize") == nil then
		local closed = F * (door:GetAttribute("HingeRel") :: CFrame) * (door:GetAttribute("DoorRel") :: CFrame)
		door:SetAttribute("BaseSize", door.Size)
		door:SetAttribute("BaseRel", F:ToObjectSpace(closed))
	end
	for _, p in ipairs({ mesh, floor }) do
		if p then
			local rel = p:GetAttribute("BaseRel") :: CFrame
			p.Size = growSize(rel, p:GetAttribute("BaseSize"))
			p.CFrame = F * (CFrame.new(growPoint(rel.Position)) * rel.Rotation)
		end
	end
	if floor then
		-- (the floor keeps its thickness)
		local base = floor:GetAttribute("BaseSize") :: Vector3
		floor.Size = Vector3.new(floor.Size.X, base.Y, floor.Size.Z)
	end
	if door then
		local rel = door:GetAttribute("BaseRel") :: CFrame
		local size = growSize(rel, door:GetAttribute("BaseSize"))
		size = Vector3.new(door:GetAttribute("BaseSize").X, size.Y, size.Z) -- (its thickness kept)
		door.Size = size
		local doorCF = F * (CFrame.new(growPoint(rel.Position)) * rel.Rotation)
		local hingeCF = doorCF * CFrame.new(0, 0, -size.Z / 2)
		door:SetAttribute("HingeRel", F:ToObjectSpace(hingeCF))
		door:SetAttribute("DoorRel", hingeCF:ToObjectSpace(doorCF))
		local openYaw = door:GetAttribute("OpenYaw") or OPEN
		local v = F.Position - H.Position
		local fromBottom = math.acos(math.clamp(-v.Y / v.Magnitude, -1, 1))
		door.CFrame = if fromBottom < BOARD_ANGLE * 1.2
			then hingeCF * CFrame.Angles(0, openYaw, 0) * hingeCF:ToObjectSpace(doorCF)
			else doorCF
	end
	cabin:SetAttribute("SizeK", K)
	n += 1
end
print(("[park_wheel_size_1124] %d cabins grown by %s"):format(n, tostring(K)))
return n
