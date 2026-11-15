--!nocheck
-- 범퍼카 ↔ 관람차 자리 바꾸기 (D-1476, user 2026-11-16, an aerial mock-up with the two swapped: "범퍼카랑
-- 관람차 위치 바꿔 줘. 관람차 아래 대기하는 단상 크기 키우고 범퍼카 입구는 동쪽으로").
--   * the bumper car hall (Workspace["범퍼"], place-only: the bumper car session's hall + D-1462's
--     dress) goes west, where the wheel stood: its floor's middle to BUMPER (the west rail just inside
--     the park's west wall, the east rail by the promenade). The user's yellow queue fence north of it
--     (Workspace.Folder["범 퍼 펜 "]) goes with it, the same shift.
--   * its entrance is now on its east side, facing the promenade: an 11-wide gap in the east rail
--     with a ramp up to the floor (2 up) and an arched "범퍼카 BUMPER CARS" sign. The old south front
--     is closed: the two gaps in the south rail filled, their invisible ramps and the invisible queue
--     walls in front of it (FenceWall, the queue's yellow panels had already been moved north by hand)
--     removed.
--   * the ferris wheel (Graybox_MainSocial.06_Park_Playground["관 람 차 "], wheel + station) goes
--     east, where the hall stood: its hub to WHEEL (the rim, 52 round, inside the east wall). Its
--     station grows (park_wheel_frame_1115 D-1476): run park_wheel_frame_1115 and
--     park_wheel_cabins_1115 after this.
-- Absolute targets: a second run moves nothing. Edit mode; after the park ride scripts, before
-- park_bumper_dress_1115 (run it again after this: its rail caps follow the split rails), the wheel
-- frame / cabins and park_paths_1116 (its paths follow the new places).

local BUMPER = Vector3.new(-241.95, 0, -829.8) -- (the hall floor's middle, x z)
local WHEEL = Vector3.new(-110, 0, -830) -- (the hub, x z)
local G = 16.06

local moved = {}

---------------------------------------------------------------- the bumper car hall
local hall = workspace:FindFirstChild("범퍼")
local arena = hall and hall:FindFirstChild("04_BumperCars")
local floor = arena and arena:FindFirstChild("Floor") :: BasePart?
if floor then
	local d = Vector3.new(BUMPER.X - floor.Position.X, 0, BUMPER.Z - floor.Position.Z)
	if d.Magnitude > 0.01 then
		local function shift(c: Instance)
			if c:IsA("Model") then
				c:PivotTo(c:GetPivot() + d)
			elseif c:IsA("BasePart") then
				c.CFrame = c.CFrame + d
			else
				for _, k in ipairs(c:GetChildren()) do shift(k) end
			end
		end
		shift(hall)
		for _, f in ipairs(workspace:GetChildren()) do
			local q = f:IsA("Folder") and f:FindFirstChild("범 퍼 펜 ")
			if q then shift(q) end
		end
		table.insert(moved, ("bumper hall by %s"):format(tostring(d)))
	end
	local fx, fz = floor.Position.X, floor.Position.Z
	local hx, hz = floor.Size.X / 2, floor.Size.Z / 2
	local floorTop = floor.Position.Y + floor.Size.Y / 2
	-- the old south front: invisible queue walls, ramps and the divider in front of the south rail
	for _, c in ipairs(hall:GetChildren()) do
		if c:IsA("BasePart") and (c.Name == "FenceWall" or c.Name == "GapRamp" or c.Name == "Part") and c.Position.Z > fz + hz - 1 then
			c:Destroy()
		end
	end
	-- the south rail's gaps filled (pieces along x at the floor's south edge)
	local southZ, southY, proto
	local covered = {}
	for _, r in ipairs(arena:GetChildren()) do
		if r:IsA("BasePart") and r.Name == "Rail" then
			local e = (r.CFrame.RightVector * r.Size.X):Abs() + (r.CFrame.LookVector * r.Size.Z):Abs()
			if math.abs(r.Position.Z - (fz + hz)) < 3 and e.X > e.Z then
				southZ, southY, proto = r.Position.Z, r.Position.Y, r
				table.insert(covered, { r.Position.X - e.X / 2, r.Position.X + e.X / 2 })
			end
		end
	end
	if proto then
		table.sort(covered, function(a, b) return a[1] < b[1] end)
		local x = fx - hx + 1.35 -- (from the west rail's inner face to the east rail's: no overlap with them)
		for _, c in ipairs(covered) do
			if c[1] - x > 0.2 then
				local p = proto:Clone()
				p.Name = "Rail"
				p.Size = Vector3.new(c[1] - x, proto.Size.Y, 2.7)
				p.CFrame = CFrame.new((x + c[1]) / 2, southY, southZ)
				p.Parent = arena
			end
			x = math.max(x, c[2])
		end
		if fx + hx - 1.35 - x > 0.2 then
			local p = proto:Clone()
			p.Name = "Rail"
			p.Size = Vector3.new(fx + hx - 1.35 - x, proto.Size.Y, 2.7)
			p.CFrame = CFrame.new((x + fx + hx - 1.35) / 2, southY, southZ)
			p.Parent = arena
		end
	end
	-- the entrance in the east rail
	local GAP = 11
	local east
	for _, r in ipairs(arena:GetChildren()) do
		if r:IsA("BasePart") and r.Name == "Rail" and math.abs(r.Position.X - (fx + hx)) < 1.5 and r.Size.Z > 60 then east = r end
	end
	if east and not hall:FindFirstChild("EastEntrance") then
		local z0, z1 = east.Position.Z - east.Size.Z / 2, east.Position.Z + east.Size.Z / 2
		local g0, g1 = fz - GAP / 2, fz + GAP / 2
		local south = east:Clone()
		east.Size = Vector3.new(east.Size.X, east.Size.Y, g0 - z0)
		east.CFrame = CFrame.new(east.Position.X, east.Position.Y, (z0 + g0) / 2)
		south.Size = Vector3.new(south.Size.X, south.Size.Y, z1 - g1)
		south.CFrame = CFrame.new(south.Position.X, south.Position.Y, (g1 + z1) / 2)
		south.Parent = arena
		local ent = Instance.new("Model")
		ent.Name = "EastEntrance"
		local rise = floorTop - G
		local run = 4.5
		local ramp = Instance.new("WedgePart") -- (a wedge rises to its +Z side: turned so +Z points west, into the hall)
		ramp.Name = "EntranceRamp"
		ramp.Size = Vector3.new(GAP, rise, run)
		local c = Vector3.new(fx + hx + run / 2, G + rise / 2, fz)
		ramp.CFrame = CFrame.lookAt(c, c + Vector3.xAxis)
		ramp.Color = Color3.fromRGB(170, 176, 186)
		ramp.Material = Enum.Material.DiamondPlate
		ramp.Anchored = true
		ramp.CanTouch = false
		ramp.Parent = ent
		local function p(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
			local q = Instance.new("Part")
			q.Name = name
			if shape then q.Shape = shape end
			q.Size = size
			q.CFrame = cf
			q.Color = color
			q.Material = mat or Enum.Material.SmoothPlastic
			q.Anchored = true
			q.CanCollide = collide == true
			q.CanTouch = false
			q.CanQuery = collide == true
			q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			q.Parent = ent
			return q
		end
		-- an arched sign over the ramp's foot (red posts, a yellow board with the name both ways)
		local ax = fx + hx + run + 0.6
		for _, s in ipairs({ -1, 1 }) do
			p("SignPost", Vector3.new(0.8, 10, 0.8), CFrame.new(ax, G + 5, fz + s * (GAP / 2 + 0.6)), Color3.fromRGB(214, 36, 44), Enum.Material.Metal, nil, true)
			p("SignPostCap", Vector3.one * 1.2, CFrame.new(ax, G + 10.3, fz + s * (GAP / 2 + 0.6)), Color3.fromRGB(250, 200, 40), Enum.Material.Metal, Enum.PartType.Ball)
		end
		local board = p("SignBoard", Vector3.new(0.5, 2.6, GAP + 2.4), CFrame.new(ax, G + 9, fz), Color3.fromRGB(250, 200, 40))
		for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.CanvasSize = Vector2.new(560, 110)
			g.LightInfluence = 0.2
			g.Parent = board
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.LuckiestGuy
			t.TextScaled = true
			t.Text = "범퍼카 BUMPER CARS"
			t.TextColor3 = Color3.fromRGB(214, 36, 44)
			t.Parent = g
		end
		ent.Parent = hall
		table.insert(moved, "bumper east entrance")
	end
end

---------------------------------------------------------------- the ferris wheel
local zone = workspace:FindFirstChild("Graybox_MainSocial") and workspace.Graybox_MainSocial:FindFirstChild("06_Park_Playground")
local wheelGroup = zone and zone:FindFirstChild("관 람 차 ")
local hub = wheelGroup and wheelGroup:FindFirstChild("Hub", true) :: BasePart?
if hub then
	local d = Vector3.new(WHEEL.X - hub.Position.X, 0, WHEEL.Z - hub.Position.Z)
	if d.Magnitude > 0.01 then
		wheelGroup:PivotTo(wheelGroup:GetPivot() + d)
		table.insert(moved, ("wheel by %s"):format(tostring(d)))
	end
end

print("[park_swap_1116] " .. (if #moved > 0 then table.concat(moved, "; ") else "nothing to move"))
return #moved
