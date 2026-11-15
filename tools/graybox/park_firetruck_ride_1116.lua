--!nocheck
-- 소방차 놀이기구 (D-1477, user 2026-11-16: "소방차 만든 에셋 사용해서 마지막 사진에 firetruk 놀이기구 만들어",
-- the photo: the fire truck blockout's round track and lawn by the gate).
-- Workspace["소방차"], built anew each run, where Hongdae_Layout.ParkBlockout["23_FireTruck"] stood (the
-- blockout is removed): a round track with a lawn in the middle (a red hydrant and a little fire
-- station sign), three small fire trucks driving round it, a yellow panel fence round it open to
-- the west (the yellow fence everywhere, D-1470) with a "소방차 FIRE TRUCK" sign.
--   * it runs on the carousel's code: tag ParkCarousel, "Center" part, trucks "Horse1".."Horse3" (pivot =
--     the rider's seat, facing the way it drives), attributes Period / Radius / SaddleY / Bob /
--     SeatBack / SeatDrop and RideText (the prompt: "🚒 소방차 타기", ParkRidesController D-1477)
--   * the trucks: the user's truck (ServerStorage.ArtAssets.FireTruck, place-only, from 23_FireTruck.glb;
--     taken from Workspace.Scene["23_FireTruck"] when the user imports it again) scaled to TRUCK_L, a
--     seat on its back; without it a red block truck stands in (cab, ladder, wheels, seat)
-- Edit mode, after park_layout_1111 (which builds the blockout).

local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local art = SS:WaitForChild("ArtAssets")

local SITE = Vector3.new(-86.9, 0, -386) -- (the blockout's middle)
local G = 16.06
local TRACK_R, LAWN_R = 13, 7.5
local RADIUS = 10.2 -- (the trucks' path)
local TRUCK_L = 6.6
local N = 3
local FRONT_SIGN = -1 -- (which end of the user's mesh is its cab along its long axis: -1 = its -Z; flip if it drives backwards)

local RED = Color3.fromRGB(214, 36, 40)
local YELLOW = Color3.fromRGB(250, 200, 30)
local WHITE = Color3.fromRGB(240, 240, 240)
local DARK = Color3.fromRGB(34, 34, 38)

-- the template: kept in ArtAssets, or taken from a new import
local tmpl = art:FindFirstChild("FireTruck")
if not tmpl then
	for _, d in ipairs(workspace:GetChildren()) do
		local m = d.Name == "Scene" and d:FindFirstChild("23_FireTruck")
		if m and m:IsA("Model") then
			m.Name = "FireTruck"
			m.Parent = art
			tmpl = m
			if #d:GetChildren() == 0 then d:Destroy() end
			break
		end
	end
end

local bo = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ParkBlockout")
local blockout = bo and bo:FindFirstChild("23_FireTruck")
if blockout then blockout:Destroy() end
local old = workspace:FindFirstChild("소방차")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "소방차"

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
local function disc(parent: Instance, name: string, r: number, top: number, h: number, color: Color3, mat: Enum.Material?, collide: boolean?): Part
	return part(parent, name, Vector3.new(h, r * 2, r * 2), CFrame.new(SITE.X, top - h / 2, SITE.Z) * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder, collide)
end

-- the track and the lawn
local TRACK_TOP = G + 0.35
disc(root, "Track", TRACK_R, TRACK_TOP, 0.6, Color3.fromRGB(120, 124, 132), Enum.Material.Asphalt, true)
disc(root, "TrackEdge", TRACK_R + 0.6, TRACK_TOP - 0.05, 0.5, WHITE, Enum.Material.SmoothPlastic, true)
-- (a white line round the trucks' path: a white disc and a track-coloured one just inside it, each at
-- its own height)
disc(root, "TrackLine", RADIUS + 0.12, TRACK_TOP + 0.04, 0.1, Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic)
disc(root, "TrackLineIn", RADIUS - 0.12, TRACK_TOP + 0.09, 0.1, Color3.fromRGB(120, 124, 132), Enum.Material.Asphalt)
disc(root, "Lawn", LAWN_R, TRACK_TOP + 0.2, 0.4, Color3.fromRGB(80, 150, 70), Enum.Material.Grass, true)
-- a red hydrant in the middle
do
	local c = Vector3.new(SITE.X, TRACK_TOP + 0.2, SITE.Z)
	part(root, "Hydrant", Vector3.new(2.4, 1.3, 1.3), CFrame.new(c + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), RED, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, true)
	part(root, "HydrantCap", Vector3.one * 1.3, CFrame.new(c + Vector3.new(0, 2.4, 0)), RED, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for _, s in ipairs({ -1, 1 }) do
		part(root, "HydrantNozzle", Vector3.new(0.7, 0.6, 0.6), CFrame.new(c + Vector3.new(s * 0.9, 1.5, 0)), YELLOW, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

local center = part(root, "Center", Vector3.one, CFrame.new(SITE.X, TRACK_TOP, SITE.Z), WHITE)
center.Transparency = 1

-- one truck model at the origin: pivot = the seat top, looking along -Z (its front)
local function blockTruck(): (Model, number)
	local m = Instance.new("Model")
	local L, W = TRUCK_L, 3.0
	local wheelR = 0.65
	local bodyY = wheelR + 0.9
	part(m, "Body", Vector3.new(W, 1.6, L * 0.62), CFrame.new(0, bodyY, L * 0.17), RED)
	part(m, "Cab", Vector3.new(W, 2.2, L * 0.34), CFrame.new(0, bodyY + 0.3, -L * 0.31), RED)
	part(m, "Windshield", Vector3.new(W - 0.4, 0.9, 0.08), CFrame.new(0, bodyY + 0.85, -L * 0.48), Color3.fromRGB(150, 200, 240), Enum.Material.Glass)
	part(m, "Bumper", Vector3.new(W + 0.1, 0.35, 0.3), CFrame.new(0, wheelR, -L / 2), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	part(m, "Light", Vector3.new(1.2, 0.35, 0.5), CFrame.new(0, bodyY + 1.55, -L * 0.31), Color3.fromRGB(60, 120, 255), Enum.Material.Neon)
	for _, s in ipairs({ -1, 1 }) do
		part(m, "LadderRail", Vector3.new(0.18, 0.18, L * 0.6), CFrame.new(s * 0.7, bodyY + 1.0, L * 0.17), WHITE, Enum.Material.Metal)
		for _, z in ipairs({ -L * 0.33, L * 0.33 }) do
			part(m, "Wheel", Vector3.new(0.5, wheelR * 2, wheelR * 2), CFrame.new(s * (W / 2 - 0.15), wheelR, z), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	for k = 0, 4 do
		part(m, "LadderRung", Vector3.new(1.4, 0.12, 0.12), CFrame.new(0, bodyY + 1.0, L * 0.17 - L * 0.25 + k * L * 0.125), WHITE, Enum.Material.Metal)
	end
	return m, bodyY + 0.8
end
local function meshTruck(): (Model, number)
	local m = tmpl:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then d:Destroy() end
	end
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * (TRUCK_L / math.max(size.X, size.Z)))
	local cf, size2 = m:GetBoundingBox()
	-- the long side along Z, the cab at -Z, its bottom middle at the origin
	local turn = if size2.X > size2.Z then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
	if FRONT_SIGN > 0 then turn = turn * CFrame.Angles(0, math.pi, 0) end
	local rel = cf:ToObjectSpace(m:GetPivot())
	m:PivotTo(turn * CFrame.new(0, size2.Y / 2, 0) * rel)
	return m, size2.Y * 0.62
end

local saddle = 0
for k = 1, N do
	local truck, seatY
	if tmpl then truck, seatY = meshTruck() else truck, seatY = blockTruck() end
	truck.Name = "Horse" .. k
	-- an open seat on its back: the pivot is the seat's top, facing the front
	part(truck, "Seat", Vector3.new(1.8, 0.4, 1.6), CFrame.new(0, seatY - 0.2, TRUCK_L * 0.2), YELLOW)
	part(truck, "SeatBack", Vector3.new(1.8, 1.2, 0.3), CFrame.new(0, seatY + 0.4, TRUCK_L * 0.2 + 0.95), YELLOW)
	for _, d in ipairs(truck:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	truck.WorldPivot = CFrame.new(0, seatY, TRUCK_L * 0.2)
	saddle = seatY
	-- where horseCFrame puts it at time 0 (the code moves it from there)
	local theta = (k - 1) * 2 * math.pi / N
	local place = center.CFrame * CFrame.Angles(0, theta, 0) * CFrame.new(0, seatY, -RADIUS) * CFrame.Angles(0, math.pi / 2, 0)
	truck:PivotTo(place)
	truck.Parent = root
end
root:SetAttribute("Period", 18)
root:SetAttribute("Radius", RADIUS)
root:SetAttribute("SaddleY", saddle) -- (the seat's top over the track)
root:SetAttribute("Bob", 0)
root:SetAttribute("SeatBack", 0)
root:SetAttribute("SeatDrop", 0)
root:SetAttribute("RideText", "🚒 소방차 타기")

-- the yellow panel fence round it, open to the west (-x)
do
	local PANEL = art:FindFirstChild("YellowFencePanel") :: BasePart?
	if PANEL then
		local PL = PANEL.Size.Z
		local NP = 12
		local RR = PL / (2 * math.sin(math.pi / NP))
		local OPEN_A = math.pi -- (the opening's middle: -x)
		local step = 2 * math.pi / NP
		for k = 1, NP - 1 do
			local a0, a1 = OPEN_A + (k - 0.5) * step, OPEN_A + (k + 0.5) * step
			local p0 = Vector3.new(SITE.X + RR * math.cos(a0), G, SITE.Z + RR * math.sin(a0))
			local p1 = Vector3.new(SITE.X + RR * math.cos(a1), G, SITE.Z + RR * math.sin(a1))
			local m = (p0 + p1) / 2
			local cf = CFrame.lookAt(m, m + (p1 - p0)) * CFrame.new(0, PANEL.Size.Y / 2, 0)
			local p = PANEL:Clone()
			p.Name = "FencePanel"
			p.CFrame = cf
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			p.Parent = root
			local w = part(root, "FenceWall", Vector3.new(0.6, 7, PL), cf * CFrame.new(0, 7 / 2 - PANEL.Size.Y / 2, 0), WHITE, nil, nil, true)
			w.Transparency = 1
			w.CanQuery = false
		end
		-- the sign by the opening
		local sx = SITE.X - RR - 1.5
		for _, s in ipairs({ -1, 1 }) do
			part(root, "SignPost", Vector3.new(0.4, 6, 0.4), CFrame.new(sx, G + 3, SITE.Z + s * 3.2), DARK, Enum.Material.Metal, nil, true)
		end
		local board = part(root, "SignBoard", Vector3.new(0.3, 1.8, 7), CFrame.new(sx, G + 5.4, SITE.Z), RED)
		for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.CanvasSize = Vector2.new(400, 100)
			g.LightInfluence = 0.2
			g.Parent = board
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.LuckiestGuy
			t.TextScaled = true
			t.Text = "소방차 FIRE TRUCK"
			t.TextColor3 = Color3.fromRGB(255, 240, 200)
			t.Parent = g
		end
	end
end

-- (streamed whole, like the carousel: ParkRidesController registers it a second after it arrives and
-- needs its Center and trucks there by then)
root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
CollectionService:AddTag(root, "ParkCarousel")
root.WorldPivot = center.CFrame
root.Parent = workspace
print(("[park_firetruck_ride_1116] %d trucks (%s)"):format(N, if tmpl then "the user's mesh" else "block trucks: import 23_FireTruck.glb again"))
return N
