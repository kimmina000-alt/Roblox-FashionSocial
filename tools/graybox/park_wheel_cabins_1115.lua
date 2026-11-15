--!nocheck
-- 관람차 칸 = 사용자 칸 (D-1463, user 2026-11-16: "관람차 3d 에셋 첨부" D:\Roblox\오후\3D 물\ferris wheel-2.glb,
-- "ferris wheel door로 문은 따로 저장했음. 바닥에 닿을 때 문 열리게 하고 공중에 뜨면서 닫히게 해 줘. 색상
-- 파스텔 컬러로 다양하게.")
--   * the import (Workspace.Scene "ferris wheel" = the body, "ferris wheel door" = its door, one
--     texture) is kept place-only as ServerStorage.ArtAssets.FerrisCabin2 (Body + Door, as imported)
--   * every Cabin<k> of the wheel (tag ParkWheel) loses its old mesh, floor and benches and gets a
--     copy scaled evenly to HEIGHT, its door side facing the front (+axle: the boarding deck), so
--     riders step from the deck through the door; a floor and two benches inside facing each
--     other across the wheel (ParkConfig.CabinSeats matches: across ±2.6, seat top 7.05 under the
--     hang point)
--   * colours: the glb's pink, then pastel copies of its texture (mint, sky, lavender, lemon,
--     peach; the pink areas recoloured, the cream window frames kept; docs/04_ART/park/ferris_cabin2)
--   * the door is "CabinDoor": attribute OwnMove (ParkRidesController moves it itself, not with the
--     cabin), HingeRel (its hinge from the cabin's pivot), DoorRel (the door from its hinge),
--     OpenYaw (the turn when open, swinging out). The client opens it near the bottom and closes it
--     as the cabin rises; here (the wheel standing still) the bottom cabin's door is left open.
-- Run in Edit mode after park_wheel_dress_1115 and park_wheel_frame_1115. Idempotent.

local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local art = SS:WaitForChild("ArtAssets")

local HEIGHT = 8 -- (the cabin's height; the deck of park_wheel_frame is built for it)
local TOP = -1.6 -- (the cabin's top under the hang point)
local TEXTURES = { "", "rbxassetid://117952286273315", "rbxassetid://79137646241567", "rbxassetid://115322900398824",
	"rbxassetid://83623174764833", "rbxassetid://78663253468483" } -- (pink as imported, mint, sky, lavender, lemon, peach)
local OPEN = 1.65 -- (the door's turn when open, radians: about 95°; times the door side, so it swings out)
local BOARD_ANGLE = math.rad(9) -- (ParkConfig.WheelBoardAngle)

-- the template (first run: from the import)
local tmpl = art:FindFirstChild("FerrisCabin2")
if not tmpl then
	local body, door
	for _, s in ipairs(workspace:GetChildren()) do
		if s.Name == "Scene" then
			body = body or s:FindFirstChild("ferris wheel")
			door = door or s:FindFirstChild("ferris wheel door")
		end
	end
	assert(body and door, "no ArtAssets.FerrisCabin2 and no imported 'ferris wheel' / 'ferris wheel door'")
	tmpl = Instance.new("Model")
	tmpl.Name = "FerrisCabin2"
	local b = body:FindFirstChildWhichIsA("MeshPart", true)
	local d = door:FindFirstChildWhichIsA("MeshPart", true)
	b.Name, d.Name = "Body", "Door"
	b.Parent, d.Parent = tmpl, tmpl
	tmpl.PrimaryPart = b
	tmpl.Parent = art
	for _, m in ipairs({ body, door }) do
		local scene = m.Parent
		m:Destroy()
		if scene and #scene:GetChildren() == 0 then scene:Destroy() end
	end
end
local body0 = tmpl:FindFirstChild("Body") :: MeshPart
local door0 = tmpl:FindFirstChild("Door") :: MeshPart
local doorRel0 = body0.CFrame:ToObjectSpace(door0.CFrame)
local S = HEIGHT / body0.Size.Y
-- the door is on the body's -X side (as imported); its hinge on its -Z edge
local doorSide = if doorRel0.Position.X < 0 then -1 else 1

local wheel
for _, m in ipairs(CollectionService:GetTagged("ParkWheel")) do
	if m:IsDescendantOf(workspace) then wheel = m end
end
assert(wheel, "no ParkWheel in Workspace")
local hub = wheel:FindFirstChild("Hub") :: BasePart
local H = hub.CFrame

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
end
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = parent
	return p
end

local KEEP = { Hanger = true, HangRod = true }
local n = 0
for k = 1, 64 do
	local cabin = wheel:FindFirstChild("Cabin" .. k)
	if not cabin then break end
	local F = H.Rotation + cabin:GetPivot().Position -- (upright, the hang point; X = the axle, +X = the front)
	cabin.WorldPivot = F
	for _, c in ipairs(cabin:GetChildren()) do
		if not KEEP[c.Name] then c:Destroy() end
	end
	-- the body turned so its door side faces +X of F (the front): the body's door side is its
	-- doorSide·X, so turn it half round when that is -X
	local turn = if doorSide < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local bodyCF = F * CFrame.new(0, TOP - HEIGHT / 2, 0) * turn
	local tex = TEXTURES[(k - 1) % #TEXTURES + 1]
	local b = body0:Clone()
	b.Name = "CabinMesh"
	b.Size = body0.Size * S
	b.CFrame = bodyCF
	if tex ~= "" then b.TextureID = tex end
	quiet(b)
	b.Parent = cabin
	local d = door0:Clone()
	d.Name = "CabinDoor"
	d.Size = door0.Size * S
	local doorCF = bodyCF * (doorRel0 - doorRel0.Position) + bodyCF:VectorToWorldSpace(doorRel0.Position * S)
	-- (pushed out a hair so it never shares the body's face)
	doorCF = doorCF + bodyCF:VectorToWorldSpace(Vector3.new(doorSide * 0.03, 0, 0))
	if tex ~= "" then d.TextureID = tex end
	quiet(d)
	-- the hinge on the door's -Z edge, vertical
	local hingeCF = doorCF * CFrame.new(0, 0, -d.Size.Z / 2)
	d:SetAttribute("OwnMove", true)
	d:SetAttribute("HingeRel", F:ToObjectSpace(hingeCF))
	d:SetAttribute("DoorRel", hingeCF:ToObjectSpace(doorCF))
	d:SetAttribute("OpenYaw", OPEN * doorSide)
	d.CFrame = doorCF
	d.Parent = cabin
	-- standing still at the bottom: its door open
	local v = F.Position - H.Position
	local fromBottom = math.acos(math.clamp(-v.Y / v.Magnitude, -1, 1))
	if fromBottom < BOARD_ANGLE * 1.2 then
		d.CFrame = hingeCF * CFrame.Angles(0, OPEN * doorSide, 0) * hingeCF:ToObjectSpace(doorCF)
	end
	-- the floor and two benches across, facing each other (F's Z = across the wheel)
	local depth = body0.Size.X * S -- (along the axle)
	local across = body0.Size.Z * S
	local floorY = TOP - HEIGHT + 0.55
	part(cabin, "Floor", Vector3.new(depth - 0.9, 0.3, across - 1.4), F * CFrame.new(0, floorY, 0), Color3.fromRGB(120, 92, 70))
	for _, sz in ipairs({ -1, 1 }) do
		part(cabin, "Bench", Vector3.new(depth - 1.4, 2.0, 1.3), F * CFrame.new(0, floorY + 1.0, sz * 3.15), Color3.fromRGB(246, 238, 226))
	end
	n += 1
end
print(("[park_wheel_cabins_1115] %d cabins, scale %.2f (body %s)"):format(n, S, tostring(body0.Size * S)))
return n
