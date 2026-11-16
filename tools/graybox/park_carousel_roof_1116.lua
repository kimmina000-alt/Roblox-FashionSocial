--!nocheck
-- 회전목마 새 지붕 + 조명 (D-1548, user 2026-11-16: "회전목마 지붕 교체해 줘 / 두번째 사진 속 그림처럼 조명 추가",
-- the user's 회전목마 지붕.glb (red / white cone, a crown of rose panels with points, a finial) and a
-- picture of a carousel at night with warm bulbs along the crown and up the roof).
--   * the roof: ServerStorage.ArtAssets.CarouselRoof2 (the user's import, place-only: save the place) as the
--     carousel's RoofMesh in its Rotor, as wide as the old roof (48.5) and its lower edge where the old
--     one's was; the old RoofMesh is kept in ServerStorage.ArtAssets.CarouselRoofOld;
--   * the lights (Rotor.RoofLights, turning with the roof): warm Neon bulbs on the crown's lines only (the
--     user's sky-blue marks): along its top edge, up and down the points, and down the seams where two
--     panels meet, found by rays onto the new mesh. Bulbs are CanCollide / CanQuery / CastShadow off.
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

-- (D-1548, user 2026-11-16 with the roof marked in sky blue: "지붕에 조명 하늘색 선 안쪽으로만 넣어 봐") bulbs
-- only on the crown's lines: along its top edge (up and down the points) and down the seams where two
-- panels meet (the dips of the top edge); just inside the lines, on the panel faces. Not up the cone, not
-- along the lower edge, no finial glow (the first try had those).
-- The crown at 360 angles: a ray in from outside at falling heights; the first height that hits near the rim
-- is the top edge there, the last one the lower edge.
local STEPS = 360
local topAt, topY, lowY = {}, {}, {}
for i = 0, STEPS - 1 do
	local a = i / STEPS * 2 * math.pi
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	for y = top, BOTTOM - 1, -0.1 do
		local hit = workspace:Raycast(Vector3.new(centre.X, y, centre.Z) + dir * (R + 4), -dir * 8, rp)
		if hit and (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(centre.X, 0, centre.Z)).Magnitude > R - 2.5 then
			if not topY[i] then topY[i], topAt[i] = y, hit.Position end
			lowY[i] = y
		end
	end
end
local function dirAt(i: number): Vector3
	local a = i / STEPS * 2 * math.pi
	return Vector3.new(math.cos(a), 0, math.sin(a))
end
-- along the top edge, a bulb every SPACING studs of edge
local SPACING = 1.25
local walked = SPACING
local prev: Vector3? = nil
for i = 0, STEPS do
	local j = i % STEPS
	local p = topAt[j]
	if p then
		local inside = p + dirAt(j) * 0.3 - Vector3.new(0, 0.45, 0)
		if prev then walked += (inside - prev).Magnitude end
		if walked >= SPACING and i < STEPS then
			bulb(inside, 0.5)
			walked = 0
		end
		prev = inside
	end
end
-- down the seams: the crown has 8 big panels (their points 45 degrees apart) and a small panel between
-- each two; the sky-blue seams are the small panels' two sides, 7 degrees either side of their middle
-- (measured on the user's mesh: the top edge dips there). The first big point = the highest sample in the
-- first 45 degrees.
local SEAM_HALF = 7
local peak, peakY = 0, -math.huge
for i = 0, 44 do
	if topY[i] and topY[i] > peakY then peak, peakY = i, topY[i] end
end
local seams = 0
for k = 0, 7 do
	for _, side in ipairs({ -1, 1 }) do
		local i = math.floor(peak + 22.5 + k * 45 + side * SEAM_HALF + 0.5) % STEPS
		local y, low = topY[i], lowY[i]
		if y and low then
			seams += 1
			local dir = dirAt(i)
			for h = y - 1.1, low + 0.4, -1.2 do
				local hit = workspace:Raycast(Vector3.new(centre.X, h, centre.Z) + dir * (R + 4), -dir * 8, rp)
				if hit then bulb(hit.Position + dir * 0.3, 0.5) end
			end
		end
	end
end

roof.CanQuery = false
lights.Parent = rotor
print(("[park_carousel_roof_1116] new roof %.1f x %.1f, %d bulbs"):format(roof.Size.X, roof.Size.Y, n))
return ("roof %.1f x %.1f, %d bulbs"):format(roof.Size.X, roof.Size.Y, n)
