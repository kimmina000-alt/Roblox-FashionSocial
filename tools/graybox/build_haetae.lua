--!nocheck
-- 광화문 해태 pair, carved from parts (D-315, user 2026-10-26: the AI meshes
-- kept coming out as upright Chinese lions, and the old AI mesh belongs to the
-- old account). Run in Edit mode after build_hongdae_layout (tools/graybox/LAYOUT.md);
-- idempotent: it replaces every "Haetae*" piece under Hongdae_Layout.Gwanghwamun.
--
-- What the photos show (docs/04_ART/references/haetae_ref_01..11):
--  * the body lies low along the pedestal, parallel to the gate front; its
--    forward end (front legs) points toward the central approach path;
--  * only the head is turned 90°, looking out at the people coming (the street);
--  * thick pillar-like front legs with big round paws and toes, hind legs
--    folded with the paws forward; a big rounded rump;
--  * a large round spiral disc on each haunch and smaller swirls on the chest;
--  * a curly tail lying flat up the back; the whole body in round scales;
--  * a big head: bulging eyes, broad nose, wide grin with rows of teeth, a
--    ring of tight curls (mane) round the face and down the neck, a small bump
--    on the crown; pale grey-beige granite;
--  * a tall pedestal: base slab, two block courses, a moulded tier, a frieze of
--    round medallions, a top slab with a lotus band (kept from D-157/D-158).

local CS = game:GetService("CollectionService")
local T = workspace:FindFirstChild("Hongdae_Layout")
assert(T, "Hongdae_Layout missing")
local G = T:FindFirstChild("Gwanghwamun")
assert(G, "Gwanghwamun missing")

local SCALES = "rbxassetid://75270171413664" -- docs/04_ART/textures/haetae_scales.png (kr_ohu)
-- the round shapes are MeshParts of the classic sphere mesh (stretched to any
-- size): a SpecialMesh Sphere loses its shape when it has a texture (it turns
-- into an empty FileMesh = a box when the game runs)
local SPHERE = game:GetService("AssetService"):CreateMeshPartAsync("rbxassetid://1185246")
local STONE = Color3.fromRGB(206, 200, 186)
local GROOVE = Color3.fromRGB(150, 144, 132)
local DARK = Color3.fromRGB(96, 92, 84)

-- where the old monuments stood (footing centres), or the layout defaults
local spots = {}
for _, c in ipairs(G:GetChildren()) do
	if c.Name == "HaetaeFooting" and c:IsA("BasePart") then
		table.insert(spots, Vector3.new(c.Position.X, c.Position.Y + c.Size.Y / 2, c.Position.Z))
	end
end
if #spots == 0 then spots = { Vector3.new(52.5, 0.45, 135), Vector3.new(52.5, 0.45, 201) } end
table.sort(spots, function(a, b) return a.Z < b.Z end)
local PATH_Z = (spots[1].Z + spots[#spots].Z) / 2 -- the approach path runs between them
local FACING = Vector3.new(-1, 0, 0) -- out to the street

for _, c in ipairs(G:GetChildren()) do
	if string.sub(c.Name, 1, 6) == "Haetae" then c:Destroy() end
end

local function newPart(parent, name, size, cf, color, opt)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.Granite
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt and opt.shape then p.Shape = opt.shape end
	if opt and opt.nocol then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if opt and opt.t then p.Transparency = opt.t end
	p.Parent = parent
	return p
end

------------------------------------------------------------------ pedestal
-- (moved from build_hongdae_layout, now turned so it is long along the body)
local function pedestal(pos: Vector3, inward: Vector3)
	newPart(G, "HaetaeFooting", Vector3.new(6.6, pos.Y + 2.4, 8.6), CFrame.lookAt(Vector3.new(pos.X, (pos.Y - 2.4) / 2, pos.Z), Vector3.new(pos.X, (pos.Y - 2.4) / 2, pos.Z) + inward), STONE)
	local cf = CFrame.lookAt(pos, pos + inward) -- local Z runs along the statue
	local function slab(name, w, y0, y1, l)
		return newPart(G, name, Vector3.new(w, y1 - y0, l), cf * CFrame.new(0, (y0 + y1) / 2, 0), STONE)
	end
	slab("HaetaeBaseSlab", 6.6, 0, 0.5, 8.6)
	slab("HaetaeBlocks", 5.4, 0.5, 2.9, 7.4)
	slab("HaetaeTierLower", 6.0, 2.9, 3.8, 8.0)
	slab("HaetaeTierLip", 6.25, 3.25, 3.45, 8.25)
	slab("HaetaeFrieze", 5.2, 3.8, 4.5, 7.2)
	slab("HaetaeTopSlab", 6.0, 4.5, 5.4, 8.0)
	slab("HaetaeTopLip", 6.25, 4.6, 4.8, 8.25)
	local function line(size, at) newPart(G, "HaetaeJoint", size, cf * at, GROOVE, { nocol = true }) end
	line(Vector3.new(5.46, 0.06, 7.46), CFrame.new(0, 1.7, 0))
	for _, s in ipairs({ -1, 1 }) do
		line(Vector3.new(0.06, 1.2, 0.06), CFrame.new(s * 2.71, 1.1, -1.2))
		line(Vector3.new(0.06, 1.2, 0.06), CFrame.new(s * 2.71, 2.3, 1.6))
		line(Vector3.new(0.06, 1.2, 0.06), CFrame.new(0.6, 1.1, s * 3.71))
		line(Vector3.new(0.06, 1.2, 0.06), CFrame.new(-0.9, 2.3, s * 3.71))
	end
	local function row(y, depthX, depthZ, step, d, name)
		for _, s in ipairs({ -1, 1 }) do
			for z = -depthZ + step / 2, depthZ - step / 2 + 0.01, step do
				newPart(G, name, Vector3.new(0.08, d, d), cf * CFrame.new(s * depthX, y, z), STONE, { nocol = true, shape = Enum.PartType.Cylinder })
			end
			for x = -depthX + step / 2, depthX - step / 2 + 0.01, step do
				newPart(G, name, Vector3.new(0.08, d, d), cf * CFrame.new(x, y, s * depthZ) * CFrame.Angles(0, math.rad(90), 0), STONE, { nocol = true, shape = Enum.PartType.Cylinder })
			end
		end
	end
	row(4.15, 2.62, 3.62, 0.9, 0.5, "HaetaeMedallion")
	row(5.05, 3.02, 4.02, 0.8, 0.42, "HaetaeLotus")
end

------------------------------------------------------------------ statue
-- Local frame S: origin on the pedestal top, -Z = the beast's forward (to the
-- path), +X*fs = the side its head turns to (the street).
local function statue(top: Vector3, inward: Vector3)
	local M = Instance.new("Model")
	M.Name = "Haetae"
	local S = CFrame.lookAt(top, top + inward)
	local fs = if FACING:Dot(S.RightVector) > 0 then 1 else -1

	-- an ellipsoid: the sphere mesh stretched to `size`. Scaled parts get the
	-- scale texture; the rest the same Granite material as the pedestal
	-- (tint = another colour, for the drilled pupils)
	local function ell(name, size: Vector3, cf: CFrame, tex: string?, tint: Color3?)
		local p = SPHERE:Clone()
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Material = Enum.Material.Granite
		p.Color = tint or STONE
		if tex then p.TextureID = tex end
		p.Parent = M
		return p
	end
	local function at(x, y, z) return S * CFrame.new(x, y, z) end
	local function disc(name, d, cf, color)
		return newPart(M, name, Vector3.new(0.12, d, d), cf, color, { nocol = true, shape = Enum.PartType.Cylinder })
	end
	local function swirl(cf, d) -- a carved round spiral: rings of light and groove
		disc("SwirlBase", d, cf, STONE)
		local k = 1
		for _, f in ipairs({ 0.78, 0.5, 0.24 }) do
			disc("SwirlRing", d * f, cf * CFrame.new(0.02 * k, 0, 0), if k % 2 == 1 then GROOVE else STONE)
			k += 1
		end
	end

	-- body (scaled stone)
	ell("Rump", Vector3.new(3.0, 2.9, 3.0), at(0, 1.45, 1.9), SCALES)
	ell("Belly", Vector3.new(2.8, 2.5, 3.6), at(0, 1.3, 0.4), SCALES)
	ell("Chest", Vector3.new(2.7, 3.2, 2.3), at(0, 2.0, -1.3), SCALES)
	ell("Withers", Vector3.new(2.6, 1.6, 2.2), at(0, 2.95, -0.8), SCALES)
	ell("Neck", Vector3.new(2.1, 2.1, 1.9), at(0.3 * fs, 3.45, -1.55), SCALES)
	-- front legs: thick pillars, big paws with three toes
	for _, s in ipairs({ -1, 1 }) do
		ell("FrontLeg", Vector3.new(1.3, 2.7, 1.35), at(s * 0.95, 1.3, -2.05), SCALES) -- thick, straight pillars
		ell("FrontPaw", Vector3.new(1.5, 0.85, 1.8), at(s * 0.95, 0.42, -2.95))
		for k = -1, 1 do
			ell("Toe", Vector3.new(0.46, 0.46, 0.55), at(s * 0.95 + k * 0.42, 0.3, -3.78))
		end
		-- hind legs folded, paws forward under the belly
		ell("Thigh", Vector3.new(1.15, 2.3, 2.7), at(s * 1.25, 1.25, 1.75), SCALES)
		ell("Hock", Vector3.new(0.8, 0.9, 1.2), at(s * 1.35, 0.5, 2.75))
		ell("HindPaw", Vector3.new(1.0, 0.7, 1.5), at(s * 1.35, 0.35, 0.55))
		for k = -1, 1 do
			ell("Toe", Vector3.new(0.36, 0.36, 0.45), at(s * 1.35 + k * 0.3, 0.27, -0.15))
		end
		-- the big spiral disc on each haunch, a smaller swirl on each side of the chest
		local out = Vector3.new(s, 0, 0)
		local hip = at(s * 1.78, 1.6, 1.85)
		swirl(CFrame.lookAt(hip.Position, hip.Position + S:VectorToWorldSpace(out)) * CFrame.Angles(0, math.rad(90), 0), 1.8)
		local sh = at(s * 1.36, 2.3, -1.35)
		swirl(CFrame.lookAt(sh.Position, sh.Position + S:VectorToWorldSpace(out)) * CFrame.Angles(0, math.rad(90), 0), 1.05)
	end
	-- the tail: tight curls lying flat up the back from the rump
	local tail = {
		{ 0, 1.6, 3.35, 0.7 }, { 0, 2.25, 3.2, 0.68 }, { 0, 2.75, 2.85, 0.66 }, { 0, 3.0, 2.35, 0.62 },
		{ 0, 3.05, 1.8, 0.58 }, { 0, 3.0, 1.3, 0.54 },
	}
	for i, t in ipairs(tail) do
		ell("TailCurl", Vector3.new(t[4] * 1.2, t[4] * 0.8, t[4]), at(t[1], t[2], t[3]))
		if i > 1 then
			for _, s in ipairs({ -1, 1 }) do
				ell("TailTuft", Vector3.new(0.38, 0.32, 0.42), at(s * 0.42, t[2] - 0.05, t[3] + 0.08))
			end
		end
	end
	-- mane curls down the back of the neck
	for i = 0, 4 do
		for _, s in ipairs({ -1, 0, 1 }) do
			ell("NeckCurl", Vector3.new(0.5, 0.45, 0.5), at(s * 0.55 + 0.25 * fs, 3.75 - i * 0.22, -0.95 + i * 0.32))
		end
	end

	-- head, turned 90° to look out (its own frame H: -Z = where it looks)
	local hc = at(0.7 * fs, 4.55, -1.85).Position
	local H = CFrame.lookAt(hc, hc + S:VectorToWorldSpace(Vector3.new(fs, 0, 0))) * CFrame.Angles(math.rad(-6), 0, 0)
	local function hat(x, y, z) return H * CFrame.new(x, y, z) end
	ell("Cranium", Vector3.new(2.9, 2.4, 2.3), hat(0, 0, 0)) -- broad, flat-faced head
	for _, s in ipairs({ -1, 1 }) do
		ell("Cheek", Vector3.new(1.1, 1.05, 1.0), hat(s * 1.12, -0.35, -0.55))
		ell("Eye", Vector3.new(0.72, 0.68, 0.62), hat(s * 0.66, 0.45, -1.02)) -- bulging stone eyes
		ell("Pupil", Vector3.new(0.24, 0.24, 0.1), hat(s * 0.66, 0.47, -1.32), nil, GROOVE) -- a shallow drilled dot, not a dark ball
		ell("Brow", Vector3.new(0.95, 0.3, 0.5), hat(s * 0.62, 0.85, -0.9) * CFrame.Angles(0, 0, math.rad(14 * s)))
		ell("Ear", Vector3.new(0.45, 0.6, 0.35), hat(s * 1.15, 0.55, 0.15))
		ell("Nostril", Vector3.new(0.22, 0.18, 0.12), hat(s * 0.3, -0.2, -1.74), nil, DARK)
	end
	ell("Muzzle", Vector3.new(2.3, 1.0, 1.25), hat(0, -0.45, -1.0))
	ell("Nose", Vector3.new(1.15, 0.6, 0.55), hat(0, -0.08, -1.5))
	ell("Jaw", Vector3.new(2.0, 0.6, 1.05), hat(0, -1.02, -0.9))
	-- the wide grin: a dark groove with an upper and a lower row of teeth
	-- (the mouth corners turn up into a grin; the teeth are broad stone blocks)
	local MOUTH = Color3.fromRGB(120, 114, 104)
	newPart(M, "Mouth", Vector3.new(1.3, 0.18, 0.2), hat(0, -0.76, -1.45), MOUTH, { nocol = true })
	for _, s in ipairs({ -1, 1 }) do
		newPart(M, "MouthCorner", Vector3.new(0.55, 0.16, 0.2), hat(s * 0.86, -0.66, -1.36) * CFrame.Angles(0, 0, math.rad(24 * s)), MOUTH, { nocol = true })
	end
	for k = -2, 2 do
		newPart(M, "Tooth", Vector3.new(0.24, 0.24, 0.12), hat(k * 0.26, -0.66, -1.53), STONE, { nocol = true })
	end
	for k = -1.5, 1.5 do
		newPart(M, "Tooth", Vector3.new(0.22, 0.2, 0.12), hat(k * 0.26, -0.87, -1.5), STONE, { nocol = true })
	end
	-- the mane: two rings of tight curls round the face, a bump on the crown, a short beard
	for i = 0, 12 do
		local t = math.rad(-35 + i * 20)
		ell("ManeCurl", Vector3.new(0.62, 0.62, 0.56), hat(1.5 * math.cos(t), 1.05 * math.sin(t) + 0.05, 0.3))
	end
	for i = 0, 9 do
		local t = math.rad(-20 + i * 22)
		ell("ManeCurl", Vector3.new(0.56, 0.56, 0.5), hat(1.3 * math.cos(t), 0.95 * math.sin(t) + 0.1, 0.8))
	end
	ell("CrownBump", Vector3.new(0.6, 0.55, 0.6), hat(0, 1.25, 0.1))
	for k = -1, 1 do
		ell("BeardCurl", Vector3.new(0.45, 0.45, 0.4), hat(k * 0.4, -1.35, -0.55))
	end

	-- one invisible box so nobody walks through it
	newPart(M, "HaetaeCollision", Vector3.new(3.4, 4.0, 7.2), at(0, 2.0, 0), STONE, { t = 1 })
	M.PrimaryPart = M:FindFirstChild("HaetaeCollision")
	M:SetAttribute("FaceSide", fs)
	M.Parent = G
	return M
end

local n = 0
for _, pos in ipairs(spots) do
	local inward = Vector3.new(0, 0, if PATH_Z > pos.Z then 1 else -1)
	pedestal(pos, inward)
	local m = statue(pos + Vector3.new(0, 5.4, 0), inward)
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
end
_ = CS
return string.format("haetae built: %d statues, %d statue parts", #spots, n)
