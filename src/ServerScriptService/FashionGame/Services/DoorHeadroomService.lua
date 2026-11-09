--!strict
-- (D-1111, user 2026-11-09: "키 큰 사람도 건물 안에 들어갈 수 있게 모든 건물들 문
-- 윗공간에 벽은 그대로 두되 통과할 수 있도록 수정해. 양옆 벽은 유지." then
-- "오후네컷 막히더라 다 19로 맞추자.")
-- Over every building's doorway the space is free up to 19 studs above the
-- doorway's floor (the OH24 entrance): the parts there (the lintel, the
-- transom, the fascia or sign band, the wall above) are kept as they look but
-- stop colliding. A part that starts lower than 6 studs over the floor is a
-- side of the doorway (a jamb, a post, the wall beside it) and keeps colliding.
-- Done on the server when it starts, so a rebuilt map gets it too (the
-- layout scripts are not changed). Parts made passable carry the attribute
-- DoorHeadroom.
-- Doorways: every AutoDoor (OH24, 오후네컷, beach cafe, club, locker room), the
-- 국밥집 door (its two DoorLeaf), the beach cafe's StaffDoor, and the three
-- photo booth rooms in 오후네컷 (RoomFrontCollider, the wall over each arch).

local CollectionService = game:GetService("CollectionService")

local DoorHeadroomService = {}

local CLEAR = 19 -- studs over the doorway floor
local SIDE = 6 -- a part starting below this is a side of the doorway
local DEPTH = 3 -- studs through the wall

-- lowest point of a part, turned or not
local function bottomOf(p: BasePart): number
	local cf, s = p.CFrame, p.Size
	local _, _, _, _, _, _, r10, r11, r12 = cf:GetComponents()
	local halfY = (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) / 2
	return cf.Position.Y - halfY
end

local cleared = 0
local function passable(p: BasePart)
	if not p.CanCollide then return end
	p.CanCollide = false
	p:SetAttribute("DoorHeadroom", true)
	cleared += 1
end

-- the doorway: its floor, middle, width direction and width
local function clearOver(floorY: number, middle: Vector3, across: Vector3, width: number, skip: {Instance})
	local right = Vector3.new(across.X, 0, across.Z)
	if right.Magnitude < 0.01 then return end
	right = right.Unit
	local box = CFrame.fromMatrix(Vector3.new(middle.X, floorY + (SIDE + CLEAR) / 2, middle.Z), right, Vector3.yAxis)
	local ov = OverlapParams.new()
	ov.FilterType = Enum.RaycastFilterType.Exclude
	ov.FilterDescendantsInstances = skip
	for _, p in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(math.max(0.5, width - 0.4), CLEAR - SIDE, DEPTH), ov)) do
		if p.CanCollide and not p:IsA("Terrain") then
			local b = bottomOf(p)
			if b >= floorY + SIDE - 0.05 and b < floorY + CLEAR then passable(p) end
		end
	end
end

-- a doorway from a box (a model's or a few parts' bounding box)
local function fromBox(cf: CFrame, size: Vector3, skip: {Instance})
	local wideX = size.X >= size.Z
	clearOver(cf.Position.Y - size.Y / 2, cf.Position, if wideX then cf.RightVector else cf.LookVector, if wideX then size.X else size.Z, skip)
end

local function floorUnder(at: Vector3, skip: {Instance}): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	local hit = workspace:Raycast(at, Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else nil
end

function DoorHeadroomService.Start()
	-- auto doors
	for _, door in ipairs(CollectionService:GetTagged("AutoDoor")) do
		if door:IsA("Model") and door:IsDescendantOf(workspace) then
			-- (boxed the way its panel faces: the 오후네컷 door stands at 45°)
			local panel = door:FindFirstChild("DoorPanel")
			local pivot = door.WorldPivot
			if panel and panel:IsA("BasePart") then door.WorldPivot = CFrame.new(pivot.Position) * panel.CFrame.Rotation end
			local cf, size = door:GetBoundingBox()
			door.WorldPivot = pivot
			fromBox(cf, size, { door })
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Gukbap" then
			-- 국밥집: the two swinging leaves
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			local leaves = {}
			for _, c in ipairs(d:GetChildren()) do
				if c:IsA("BasePart") and c.Name == "DoorLeaf" then
					table.insert(leaves, c)
					lo, hi = lo:Min(c.Position - c.Size / 2), hi:Max(c.Position + c.Size / 2)
				end
			end
			if #leaves > 0 then fromBox(CFrame.new((lo + hi) / 2), hi - lo, leaves) end
		elseif d:IsA("BasePart") and d.Name == "StaffDoor" then
			-- the beach cafe's staff door
			fromBox(d.CFrame, d.Size, { d })
		elseif d:IsA("BasePart") and d.Name == "RoomFrontCollider" then
			-- 오후네컷 photo booth rooms: the wall over the arch (and the arch's
			-- rim strips), along the whole room front
			local skip: {Instance} = { d }
			for _, s in ipairs((d.Parent :: Instance):GetChildren()) do
				if s.Name == "ArchRim" then table.insert(skip, s) end
			end
			local floorY = floorUnder(d.Position - Vector3.new(0, d.Size.Y / 2 + 0.1, 0), skip)
			if floorY then
				local wideX = d.Size.X >= d.Size.Z
				clearOver(floorY, d.Position, if wideX then d.CFrame.RightVector else d.CFrame.LookVector, if wideX then d.Size.X else d.Size.Z, {})
			end
		end
	end
	print(string.format("[DoorHeadroom] %d parts over doorways made passable", cleared))
end

return DoorHeadroomService
