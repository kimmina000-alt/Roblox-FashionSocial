--!nocheck
-- 관람차 디자인 (D-1433, user 2026-11-15: "관람차 디자인" + photos: a white rim on red-pink lattice
-- spokes, white legs, round cabins in pink / blue / yellow with big windows; inside, benches by the
-- windows) + the user's cabin mesh ("ferris wheel.glb").
--   * the wheel (tag ParkWheel, …["관 람 차 "]): two rings like the real wheel — the rim, spokes
--     and rim lights moved TWIN_X to one side of the axle's middle and copied to the other side, so
--     the cabins swing between the two rings and never through a spoke (once: attribute TwinX);
--     spokes red-pink, a lattice of chords and a diagonal between neighbouring spokes on both rings
--     (Rotor/Dress, turns with it), a red plate each side of the hub, the rim white, the legs
--     white-grey, each cabin's hanger bar spanning the two rings
--   * every Cabin<k>: the old roof / floor / posts / rails / benches go; the user's cabin (scaled
--     6 deep along the axle, 8 high, 8.4 across) hangs under the hanger, a floor and two benches
--     with backrests inside facing each other along the axle (ParkConfig.CabinSeats matches:
--     x ±2, seat top 7.25 under the hang point). Colours cycle pink, blue, yellow, sky, red.
-- Mesh: ServerStorage.ArtAssets.FerrisCabinTex (the re-UV'd, painted glb with see-through windows,
-- docs/04_ART/park/ferris_tex) when imported, else FerrisCabin (the user's plain mesh, tinted).
-- Run in Edit mode after the graybox zones. Idempotent.

local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local art = SS:WaitForChild("ArtAssets")

local wheel
for _, m in ipairs(CollectionService:GetTagged("ParkWheel")) do
	if m:IsDescendantOf(workspace) then wheel = m end
end
assert(wheel, "no ParkWheel in Workspace")
local hub = wheel:FindFirstChild("Hub") :: BasePart
local rotor = wheel:FindFirstChild("Rotor") :: Model
local H = hub.CFrame
local R = wheel:GetAttribute("Radius") or 52

local PINKRED = Color3.fromRGB(210, 72, 100)
local WHITE = Color3.fromRGB(242, 240, 242)
local LEG = Color3.fromRGB(222, 226, 232)
local CABIN_COLORS = { Color3.fromRGB(232, 120, 160), Color3.fromRGB(62, 112, 200), Color3.fromRGB(242, 200, 62), Color3.fromRGB(96, 184, 224), Color3.fromRGB(210, 70, 100) }
-- (pink = the glb's own 128369625673591, then the FerrisCabinTex_<colour>.png uploads: blue, yellow, sky, red)
local CABIN_TEXTURES = { "", "rbxassetid://85623645387555", "rbxassetid://99084509303848", "rbxassetid://79850105325162", "rbxassetid://81213501938454" }
local CABIN_SIZE = Vector3.new(6, 8, 8.4) -- (along the axle, up, across)
local TOP = -1.6 -- (the cabin's top under the hang point)
local TWIN_X = 3.9 -- (each ring this far from the axle's middle)

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = parent
	return p
end

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, t: number, color: Color3): Part
	return part(parent, name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Metal)
end

---------------------------------------------------------------- the wheel
local dress = rotor:FindFirstChild("Dress")
if dress then dress:Destroy() end
dress = Instance.new("Folder")
dress.Name = "Dress"
dress.Parent = rotor

if not wheel:GetAttribute("TwinX") then
	for _, p in ipairs(rotor:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Rim" or p.Name == "Spoke" or p.Name == "RimLight") then
			local x = H.RightVector * TWIN_X
			local copy = p:Clone()
			p.CFrame = p.CFrame + x
			copy.CFrame = copy.CFrame - x
			copy.Parent = rotor
		end
	end
	wheel:SetAttribute("TwinX", TWIN_X)
end

local dirs = {}
for _, p in ipairs(rotor:GetChildren()) do
	if p:IsA("BasePart") then
		if p.Name == "Spoke" then
			p.Color = PINKRED
			p.Material = Enum.Material.Metal
			local d = H:VectorToObjectSpace(p.Position - H.Position)
			if d.X > 0 then table.insert(dirs, math.atan2(d.Z, d.Y)) end -- (one ring's spokes)
		elseif p.Name == "Rim" then
			p.Color = WHITE
		elseif p.Name == "Axle" then
			p.Color = Color3.fromRGB(190, 192, 198)
		end
	end
end
table.sort(dirs)
local function at(angle: number, r: number, side: number?): Vector3
	return (H * CFrame.new(side or 0, r * math.cos(angle), r * math.sin(angle))).Position
end
for _, side in ipairs({ -TWIN_X, TWIN_X }) do
	for k, a in ipairs(dirs) do
		local b = dirs[k % #dirs + 1]
		if b < a then b += 2 * math.pi end
		beam(dress, "Chord", at(a, R * 0.42, side), at(b, R * 0.42, side), 0.55, PINKRED)
		beam(dress, "Chord", at(a, R * 0.74, side), at(b, R * 0.74, side), 0.55, PINKRED)
		beam(dress, "Diagonal", at(a, R * 0.42, side), at(b, R * 0.74, side), 0.45, PINKRED)
	end
end
for _, side in ipairs({ -1, 1 }) do -- red plates each side of the hub
	part(dress, "HubPlate", Vector3.new(1, 15, 15), H * CFrame.new(side * (TWIN_X + 0.8), 0, 0), PINKRED, Enum.Material.Metal, Enum.PartType.Cylinder)
end
hub.Color = PINKRED
for _, s in ipairs(wheel:GetChildren()) do
	if s:IsA("BasePart") and s.Name == "Support" then
		s.Color = LEG
		s.Material = Enum.Material.Metal
	end
end

---------------------------------------------------------------- the cabins
local tmpl
for _, n in ipairs({ "FerrisCabinTex", "FerrisCabin" }) do
	local t = art:FindFirstChild(n)
	local m = t and t:FindFirstChildWhichIsA("MeshPart", true)
	if m then tmpl = m break end
end
local KEEP = { Hanger = true, HangRod = true }
for k = 1, 64 do
	local cabin = wheel:FindFirstChild("Cabin" .. k)
	if not cabin then break end
	local F = H.Rotation + cabin:GetPivot().Position -- (upright, hang point)
	for _, c in ipairs(cabin:GetChildren()) do
		if not KEEP[c.Name] then c:Destroy() end
		if c.Name == "Hanger" and c:IsA("BasePart") then -- (spans the two rings)
			c.Size = Vector3.new(TWIN_X * 2 + 0.8, c.Size.Y, c.Size.Z)
			c.CFrame = F * CFrame.new(0, 0, 0)
		end
	end
	local col = CABIN_COLORS[(k - 1) % #CABIN_COLORS + 1]
	local mid = F * CFrame.new(0, TOP - CABIN_SIZE.Y / 2, 0)
	if tmpl then
		local m = tmpl:Clone()
		m.Name = "CabinMesh"
		m.Size = CABIN_SIZE
		m.CFrame = mid
		local tex = CABIN_TEXTURES[(k - 1) % #CABIN_TEXTURES + 1]
		if m.TextureID ~= "" and tex ~= "" then m.TextureID = tex elseif m.TextureID == "" then m.Color = col end
		-- (the windows' see-through pixels only show when the part is a little transparent itself)
		if m.TextureID ~= "" then m.Transparency = 0.02 end
		quiet(m)
		m.Parent = cabin
	end
	local floorY = TOP - CABIN_SIZE.Y + 0.55
	part(cabin, "Floor", Vector3.new(CABIN_SIZE.X - 0.8, 0.3, CABIN_SIZE.Z - 2.2), F * CFrame.new(0, floorY, 0), Color3.fromRGB(120, 92, 70))
	for _, sx in ipairs({ -1, 1 }) do
		local benchTop = floorY + 2.0
		part(cabin, "Bench", Vector3.new(1.5, 2.0, 4.6), F * CFrame.new(sx * 2.05, floorY + 1.0, 0), Color3.fromRGB(150, 110, 82))
		part(cabin, "BenchBack", Vector3.new(0.3, 2.0, 4.6), F * CFrame.new(sx * 2.7, benchTop + 1.0, 0), Color3.fromRGB(150, 110, 82))
	end
	part(cabin, "HandRail", Vector3.new(0.18, 0.18, 4.2), F * CFrame.new(0, floorY + 3.6, 0), Color3.fromRGB(200, 202, 208), Enum.Material.Metal)
	for _, c in ipairs(cabin:GetDescendants()) do
		if c:IsA("BasePart") then quiet(c) end
	end
end
print("[park_wheel_dress_1115] spokes " .. #dirs .. ", cabin mesh " .. (tmpl and tmpl.Parent.Name or "none"))
return #dirs
