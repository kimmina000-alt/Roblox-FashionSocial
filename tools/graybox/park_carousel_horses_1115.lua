-- (D-1420, user 2026-11-15, a screenshot with the user's carousel horse circled: "회전목마 노란색
-- 표시한 에셋 사용하여 회전목마 말 교체해서 기능까지 구현") The carousel's 12 block horses
-- (Graybox_MainSocial["06_Park_Playground"]["회전목"].Carousel.Horse1..12) become the user's
-- carousel horse.
-- (D-1423, user 2026-11-15: "회전목마 막대기 너무 두꺼움. 3d 파일에 기둥 포함한 걸로 줄게. 얘 길이만
-- 조절해서 넣어" + "회전목마 지붕") v2: the user's horse.glb (white horse "Cylinder2" + gold horn
-- "Cylinder" + its own thin pole "Cylinder.001") and CarouselRoof.glb, imported by the user and kept
-- place-only in ServerStorage.ArtAssets.CarouselHorsePole (Body / Horn / Pole) and
-- ServerStorage.ArtAssets.CarouselRoof (Roof).
--   * each horse keeps its old pivot (the saddle top on the pole, LookVector = the way it rides), so
--     ParkConfig.horseCFrame and the riders' seats stay right. Body and horn are scaled to SCALE
--     (about 7 studs long) and placed so the pole line runs through the saddle (SADDLE, measured on
--     the glb: the pole axis is 0.153 in front of the body's middle, the back there 0.216 above it).
--   * the pole: only its length changes (from the carousel floor to the canopy), its thickness
--     follows SCALE. It stands in the Rotor (it turns, it does not bob with the horse) in place of the
--     thick yellow "Pole" boxes, which are removed.
--   * the roof: the user's roof mesh, scaled evenly to ROOF_D across, in the Rotor (it turns too),
--     its lower edge a little under the canopy; the old CanopyTop / CanopyCrown under it are removed
--     (the flat Canopy stays as the ceiling seen from below, with its bulbs).
--   * the carousel's Radius / SaddleY / Bob attributes are set to its real size.
--   * (D-1427, user 2026-11-15: "회전목마 말 너무 아래에서 움직임. 전체적으로 위로 올리고 위아래로
--     움직이는 범위 넓히기") the saddles stand SADDLE_Y above the carousel's Center (was 5.54: the
--     hooves nearly on the floor) and bob BOB up and down (was 1.1).
-- Idempotent (horses holding "HorseMesh" with a "PoleV2" attribute, a "HorsePole" in the Rotor and a
-- "RoofMesh" are left). Chain step: after the graybox zones, with park_playground_1114.

local SS = game:GetService("ServerStorage")
local zone = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("06_Park_Playground")
local carousel = zone:WaitForChild("회전목"):WaitForChild("Carousel")
local rotor = carousel:WaitForChild("Rotor")
local art = SS:WaitForChild("ArtAssets")
local template = art:WaitForChild("CarouselHorsePole")
local roofTemplate = art:WaitForChild("CarouselRoof")

local SCALE = 3.75
local SADDLE = Vector3.new(0.153, 0.216 + 0.03, 0) -- (from the body's middle, size 1 = as imported)
local ROOF_D = 48.5
local SADDLE_Y = 8.6 -- (saddle top above the Center part; hooves about 3 studs over the floor)
local BOB = 2.3
local ROOF_DROP = 0.5 -- (the roof's lower edge under the canopy's underside)

local body0 = template:FindFirstChild("Body") :: MeshPart
local horn0 = template:FindFirstChild("Horn") :: MeshPart
local pole0 = template:FindFirstChild("Pole") :: MeshPart
local roof0 = roofTemplate:FindFirstChild("Roof") :: MeshPart
local hornRel = body0.CFrame:ToObjectSpace(horn0.CFrame) -- (as imported)

local center = carousel:FindFirstChild("Center") :: BasePart
local canopy = rotor:FindFirstChild("Canopy") :: BasePart
local base = zone["회전목"]:FindFirstChild("CarouselBase") :: BasePart
local floorY = base.Position.Y + base.Size.X / 2 -- (a cylinder: X is its height)
local ceilY = canopy.Position.Y - canopy.Size.X / 2

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
end

for _, c in ipairs(rotor:GetChildren()) do
	if c.Name == "Pole" or c.Name == "CanopyTop" or c.Name == "CanopyCrown" then c:Destroy() end
end

local count = 0
local radius, saddleY = 0, 0
for i = 1, 64 do
	local horse = carousel:FindFirstChild("Horse" .. i)
	if not horse or not horse:IsA("Model") then break end
	local pivot = horse:GetPivot() -- (saddle top on the pole, facing the way it rides)
	pivot = (pivot - pivot.Position) + Vector3.new(pivot.X, center.Position.Y + SADDLE_Y, pivot.Z)
	if horse:GetAttribute("PoleV2") then horse:PivotTo(pivot) end
	radius = Vector2.new(pivot.X - center.Position.X, pivot.Z - center.Position.Z).Magnitude
	saddleY = pivot.Y - center.Position.Y
	if not horse:GetAttribute("PoleV2") then
		for _, c in ipairs(horse:GetChildren()) do c:Destroy() end
		-- mesh +X (the head) = the pivot's LookVector: turn by +90° about Y
		local bodyCF = pivot * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-SADDLE * SCALE)
		local body = body0:Clone()
		body.Name = "HorseMesh"
		body.Size = body0.Size * SCALE
		body.CFrame = bodyCF
		local horn = horn0:Clone()
		horn.Name = "HorseHorn"
		horn.Size = horn0.Size * SCALE
		horn.CFrame = bodyCF * (hornRel - hornRel.Position) + bodyCF:VectorToWorldSpace(hornRel.Position * SCALE)
		for _, p in ipairs({ body, horn }) do
			quiet(p)
			p.Parent = horse
		end
		horse.WorldPivot = pivot
		horse:SetAttribute("PoleV2", true)
	end
	local poleName = "HorsePole" .. i
	local pole = rotor:FindFirstChild(poleName) :: MeshPart?
	if not pole then
		pole = pole0:Clone()
		pole.Name = poleName
		pole.Parent = rotor
	end
	local p = pole :: MeshPart
	p.Size = Vector3.new(pole0.Size.X * SCALE, ceilY - floorY, pole0.Size.Z * SCALE)
	p.CFrame = CFrame.new(pivot.X, (floorY + ceilY) / 2, pivot.Z)
	quiet(p)
	count += 1
end

local roof = rotor:FindFirstChild("RoofMesh") :: MeshPart?
if not roof then
	roof = roof0:Clone()
	roof.Name = "RoofMesh"
	roof.Parent = rotor
end
local r = roof :: MeshPart
r.Size = roof0.Size * (ROOF_D / roof0.Size.X)
r.CFrame = CFrame.new(center.Position.X, ceilY - ROOF_DROP + r.Size.Y / 2, center.Position.Z)
quiet(r)

carousel:SetAttribute("Radius", math.floor(radius * 100 + 0.5) / 100)
carousel:SetAttribute("SaddleY", math.floor(saddleY * 100 + 0.5) / 100)
carousel:SetAttribute("Bob", BOB)
print(("[park_carousel_horses_1115] horses %d, radius %.2f, saddle %.2f, poles %.2f long, roof %.1f high")
	:format(count, radius, saddleY, ceilY - floorY, r.Size.Y))
return count
