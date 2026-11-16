--!nocheck
-- 회전목마 새 지붕 + 조명 (D-1548, user 2026-11-16: "회전목마 지붕 교체해 줘 / 두번째 사진 속 그림처럼 조명 추가",
-- the user's 회전목마 지붕.glb (red / white cone, a crown of rose panels with points, a finial) and a
-- picture of a carousel at night with warm bulbs along the crown and up the roof).
--   * the roof: ServerStorage.ArtAssets.CarouselRoof2 (the user's import, place-only: save the place) as the
--     carousel's RoofMesh in its Rotor, as wide as the old roof (48.5) and its lower edge where the old
--     one's was; the old RoofMesh is kept in ServerStorage.ArtAssets.CarouselRoofOld;
--   * the lights (Rotor.RoofLights, turning with the roof): warm Neon bulbs along the crown's top edge (it
--     goes up and down with the points) and its lower edge, and up 16 lines of the cone to the top, found by
--     rays onto the new mesh; a gold glow at the finial. Bulbs are CanCollide / CanQuery / CastShadow off.
-- Safe to run again.

local art = game:GetService("ServerStorage"):WaitForChild("ArtAssets")
local carousel = workspace:FindFirstChild("Carousel", true)
assert(carousel and carousel:FindFirstChild("Rotor"), "no carousel")
local rotor = carousel.Rotor
local centre = carousel.Center.Position

local WIDTH = 48.5
local BOTTOM = 35.16 -- (the old roof's lower edge)
local WARM = Color3.fromRGB(255, 226, 150)

-- the roof
local current = rotor:FindFirstChild("RoofMesh")
if current and current:GetAttribute("NewRoof") ~= true then
	local keep = art:FindFirstChild("CarouselRoofOld")
	if keep then keep:Destroy() end
	current.Name = "CarouselRoofOld"
	current.Parent = art
	current = nil
end
if current then current:Destroy() end
local roof = art.CarouselRoof2:Clone()
roof.Name = "RoofMesh"
roof:SetAttribute("NewRoof", true)
local k = WIDTH / roof.Size.X
roof.Size = roof.Size * k
roof.CFrame = CFrame.new(centre.X, BOTTOM + roof.Size.Y / 2, centre.Z)
roof.Anchored, roof.CanCollide, roof.CanTouch, roof.CastShadow = true, false, false, true
roof.Parent = rotor

-- rays onto the new roof only
roof.CanQuery = true
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { roof }
local R = WIDTH / 2
local top = roof.Position.Y + roof.Size.Y / 2

local old = rotor:FindFirstChild("RoofLights")
if old then old:Destroy() end
local lights = Instance.new("Model")
lights.Name = "RoofLights"
local n = 0
local function bulb(at: Vector3, d: number)
	local b = Instance.new("Part")
	b.Name = "RoofBulb"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(d, d, d)
	b.Material = Enum.Material.Neon
	b.Color = WARM
	b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery, b.CastShadow = true, false, false, false, false
	b.Position = at
	b.Parent = lights
	n += 1
end

-- the crown: at each angle a ray in from outside at falling heights; the first height that hits near the
-- rim is the crown's top there, the last one its lower edge
local ANGLES = 64
for i = 0, ANGLES - 1 do
	local a = i / ANGLES * 2 * math.pi
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local first, last, firstHit, lastHit = nil, nil, nil, nil
	for y = top, BOTTOM - 1, -0.25 do
		local from = Vector3.new(centre.X, y, centre.Z) + dir * (R + 4)
		local hit = workspace:Raycast(from, -dir * 8, rp)
		if hit and (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(centre.X, 0, centre.Z)).Magnitude > R - 2.5 then
			if not first then first, firstHit = y, hit.Position end
			last, lastHit = y, hit.Position
		end
	end
	if firstHit then bulb(firstHit + dir * 0.35 - Vector3.new(0, 0.2, 0), 0.55) end
	if lastHit and last and first and first - last > 1 then bulb(lastHit + dir * 0.35 + Vector3.new(0, 0.2, 0), 0.55) end
end

-- up the cone: 16 lines from the crown to the top, a bulb every ~2.2 studs, laid on the surface (rays down)
local LINES = 16
for i = 0, LINES - 1 do
	local a = (i + 0.5) / LINES * 2 * math.pi
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	for r = R - 2.5, 1.5, -2.2 do
		local from = Vector3.new(centre.X, top + 5, centre.Z) + dir * r
		local hit = workspace:Raycast(from, Vector3.new(0, -(top - BOTTOM + 10), 0), rp)
		if hit then bulb(hit.Position + hit.Normal * 0.3, 0.5) end
	end
end

-- the finial's glow
local tip = workspace:Raycast(Vector3.new(centre.X, top + 5, centre.Z), Vector3.new(0, -10, 0), rp)
local glow = Instance.new("Part")
glow.Name = "FinialGlow"
glow.Shape = Enum.PartType.Ball
glow.Size = Vector3.new(1.4, 1.4, 1.4)
glow.Material = Enum.Material.Neon
glow.Color = Color3.fromRGB(255, 205, 90)
glow.Anchored, glow.CanCollide, glow.CanTouch, glow.CanQuery, glow.CastShadow = true, false, false, false, false
glow.Position = (if tip then tip.Position else Vector3.new(centre.X, top, centre.Z)) + Vector3.new(0, 0.6, 0)
local light = Instance.new("PointLight")
light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 210, 120), 16, 1.5
light.Parent = glow
glow.Parent = lights

roof.CanQuery = false
lights.Parent = rotor
print(("[park_carousel_roof_1116] new roof %.1f x %.1f, %d bulbs"):format(roof.Size.X, roof.Size.Y, n))
return ("roof %.1f x %.1f, %d bulbs"):format(roof.Size.X, roof.Size.Y, n)
