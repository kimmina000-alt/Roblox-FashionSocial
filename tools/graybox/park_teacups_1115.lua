--!nocheck
-- 회전컵 (D-1432, user 2026-11-15: the user's cup.glb + teapot.glb and a photo of a tea cup ride:
-- a grey turntable, a big teapot in the middle, five white cups with coloured drips on saucers,
-- a steering wheel in each cup).
--
-- Workspace["회전컵"] (outside Hongdae_Layout: a chain run cannot wipe it; park_layout_1111 no
-- longer builds the 07_TeaCups blockout when it is there):
--   "Base"  the round platform (the blockout's Platform)
--   "Ride"  tag ParkTeaCups, pivot = the turntable's middle on the deck (ParkConfig.teacup*):
--     "Rotor"   the deck and its rings (turns with the table)
--     "Teapot"  the user's teapot in the middle (stands still)
--     "Cup1".."Cup5"  saucer + the user's cup + steering wheel + 4 benches; each turns with the
--                     table and spins itself the other way; riders sit on the benches facing the
--                     wheel (Rider1..Rider20, picked like the viking's seats)
-- Meshes: ServerStorage.ArtAssets.TeaCupTex / TeapotTex (the re-UV'd, painted glbs,
-- docs/04_ART/park/teacups_tex) when imported, else TeaCup / Teapot (the user's plain meshes).
-- The cups' colours: CUP_TEXTURES (ids of the CupTex_<colour>.png uploads) or, plain, CUP_COLORS.
-- Run in Edit mode (chain step after park_layout_1111). Idempotent: "Ride" is built anew.

local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local art = SS:WaitForChild("ArtAssets")

local CENTER = Vector3.new(-111, 0, -535)
local CUPS, PER = 5, 4
local CUP_R = 19.5 -- (cups' middles from the table's middle)
local CUP_D = 10 -- (a cup across)
local TEAPOT_H = 43.875 -- (D-1467, user: "크기 1.5배 키우기": was 13; D-1474, the Y post: again 1.5x, was 19.5; D-1477 again 1.5x, was 29.25)
local CUP_COLORS = { Color3.fromRGB(70, 150, 95), Color3.fromRGB(214, 60, 58), Color3.fromRGB(244, 196, 52), Color3.fromRGB(88, 176, 228), Color3.fromRGB(52, 84, 58) }
-- (D-1435: the user's drip picture, CupDrip_<colour>.png from tools/art/teacups_drip_v2.py:
-- green, red, yellow, blue, dark green; D-1432's own drips were 101010709181927 / 110353989323099 / ...)
local CUP_TEXTURES = { "rbxassetid://96347537548381", "rbxassetid://127637303435065", "rbxassetid://137053123416662", "rbxassetid://126801391100567", "rbxassetid://93907123130946" }
-- (D-1466, user 2026-11-16: "cup 3d 아이템 가져오기 했어 이미지 이걸로 다섯 개 써서 수정해": the user's new
-- octagonal cup without the middle post or wheel, ArtAssets.TeaCupTex4, UV'd for these drip pictures
-- (docs/04_ART/park/teacups4): yellow, pink, purple, green, cyan)
local CUP4_TEXTURES = { "rbxassetid://88415588841309", "rbxassetid://80021590554183", "rbxassetid://117944709363119", "rbxassetid://131642548427433", "rbxassetid://80782978424076" }

local function quiet(p: BasePart, collide: boolean?)
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
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

local function disc(parent: Instance, name: string, at: Vector3, y0: number, h: number, d: number, color: Color3, mat: Enum.Material?): Part
	return part(parent, name, Vector3.new(h, d, d), CFrame.new(at.X, y0 + h / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

-- a copy of a mesh template (a Model), scaled evenly, its bounding box's bottom middle on `at`
local function placeMesh(template: Model, parent: Instance, name: string, at: CFrame, scaleTo: (Vector3) -> number): Model
	local m = template:Clone()
	m.Name = name
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * scaleTo(size))
	local cf, size2 = m:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, size2.Y / 2, 0)
	m:PivotTo(m:GetPivot() + (at.Position - bottom))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then quiet(d) end
	end
	m.Parent = parent
	return m
end

local function template(names: {string}): (Model?, string?)
	for _, n in ipairs(names) do
		local t = art:FindFirstChild(n)
		if t and t:IsA("Model") then return t, n end
	end
	return nil, nil
end

-- the model, its base and deck (taken over from the blockout the first time)
local owner = workspace:FindFirstChild("회전컵")
local blockout = workspace.Hongdae_Layout:FindFirstChild("ParkBlockout") and workspace.Hongdae_Layout.ParkBlockout:FindFirstChild("07_TeaCups")
if not owner then
	assert(blockout, "no 회전컵 and no 07_TeaCups blockout")
	owner = Instance.new("Model")
	owner.Name = "회전컵"
	local base = blockout:FindFirstChild("Platform")
	base.Name = "Base"
	base.Parent = owner
	local deck = blockout:FindFirstChild("Deck")
	deck.Name = "Deck"
	deck.Parent = owner
	owner.Parent = workspace
end
if blockout then blockout:Destroy() end
local base = owner:FindFirstChild("Base") :: BasePart
local deck = owner:FindFirstChild("Deck") or (owner:FindFirstChild("Ride") and owner.Ride.Rotor:FindFirstChild("Deck"))
deck.Parent = owner -- (out of the old Ride before it goes)
local old = owner:FindFirstChild("Ride")
if old then old:Destroy() end

base.Color = Color3.fromRGB(150, 156, 164)
base.Material = Enum.Material.Concrete
local deckTop = deck.Position.Y + deck.Size.X / 2 -- (a cylinder: X is its height)
local C = Vector3.new(CENTER.X, deckTop, CENTER.Z)

local ride = Instance.new("Model")
ride.Name = "Ride"
local rotor = Instance.new("Model")
rotor.Name = "Rotor"
rotor.Parent = ride
deck.Parent = rotor
-- (D-1477, user: "회전컵 바닥 잔디 심은 땅으로 수정") the turntable is a lawn: grass with a pale stone ring
-- near its edge and a stone circle under the middle piece
local LAWN = Color3.fromRGB(92, 150, 66)
deck.Color = LAWN
deck.Material = Enum.Material.Grass
quiet(deck, true)
disc(rotor, "DeckRing", C, deckTop, 0.06, deck.Size.Y - 3, Color3.fromRGB(226, 220, 204), Enum.Material.Slate)
disc(rotor, "DeckInner", C, deckTop, 0.08, deck.Size.Y - 4.6, LAWN, Enum.Material.Grass)
disc(rotor, "DeckCentre", C, deckTop, 0.1, 16, Color3.fromRGB(226, 220, 204), Enum.Material.Slate)

-- the teapot (stands still in the middle)
-- (D-1467, user 2026-11-16: "회전컵 가운데 주전자 수정": the user's new teapot.glb, ArtAssets.TeapotTex2)
-- (D-1473, user 2026-11-16: "TeapotTex 수정" + teacups_tex/v2/TeapotTex.glb, answered "주전자 교체": the
-- middle piece is now that model, a pink Y-shaped post with crowned ends, ArtAssets.TeapotTex3,
-- stood TEAPOT_H high like the teapot)
local pot = template({ "TeapotTex3", "TeapotTex2", "TeapotTex", "Teapot" })
if pot then
	local potModel = placeMesh(pot, ride, "Teapot", CFrame.new(C + Vector3.new(0, 0.1, 0)), function(size) return TEAPOT_H / size.Y end)
	-- (D-1477, user: "가운데 세워 놓은 조형물에 흰색 뿔들 조명처럼 불 들어오게") the Y post's white spikes (3 on
	-- each side of each crowned end: 12) light up: a warm neon rod along each spike and a bulb on its
	-- tip, inside the Teapot model (they turn with it). Tips and bases in the glb's own units
	-- (TeapotTex.glb, read from its white texels); its box is MESH_MIN..MESH_MAX.
	local mesh = potModel:FindFirstChildWhichIsA("MeshPart", true)
	if mesh and pot.Name == "TeapotTex3" then
		local MESH_MIN, MESH_MAX = Vector3.new(5.6545, -5.8965, -0.27), Vector3.new(8.8324, 1.3715, 0.27)
		local mid, msize = (MESH_MIN + MESH_MAX) / 2, MESH_MAX - MESH_MIN
		local k = mesh.Size / msize
		local TIPS = { -- (tip, the arm's middle line x it grows from)
			{ Vector3.new(5.655, -0.03, 0), 6.25 }, { Vector3.new(5.709, 0.37, 0), 6.3 }, { Vector3.new(5.828, 0.707, 0), 6.35 },
			{ Vector3.new(6.627, -0.05, 0), 6.25 }, { Vector3.new(6.691, 0.244, 0), 6.3 }, { Vector3.new(6.771, 0.522, 0), 6.35 },
			{ Vector3.new(8.832, -0.03, 0), 8.24 }, { Vector3.new(8.778, 0.37, 0), 8.19 }, { Vector3.new(8.659, 0.707, 0), 8.14 },
			{ Vector3.new(7.86, -0.05, 0), 8.24 }, { Vector3.new(7.796, 0.244, 0), 8.19 }, { Vector3.new(7.716, 0.522, 0), 8.14 },
		}
		local GLOW = Color3.fromRGB(255, 246, 214)
		local function at(v: Vector3): Vector3 return mesh.CFrame:PointToWorldSpace((v - mid) * k) end
		for i, t in ipairs(TIPS) do
			local tip = at(t[1])
			local base = at(Vector3.new(t[1].X + (t[2] - t[1].X) * 0.75, t[1].Y, 0))
			local rod = part(potModel, "SpikeGlow", Vector3.new(0.09 * k.X, 0.09 * k.X, (tip - base).Magnitude), CFrame.lookAt((tip + base) / 2, tip), GLOW, Enum.Material.Neon)
			rod.CastShadow = false
			local bulb = part(potModel, "SpikeTip", Vector3.one * 0.14 * k.X, CFrame.new(tip), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
			bulb.CastShadow = false
			if i % 3 == 2 then
				local light = Instance.new("PointLight")
				light.Range = 14
				light.Brightness = 1.4
				light.Color = Color3.fromRGB(255, 236, 190)
				light.Shadows = false
				light.Parent = bulb
			end
		end
	end
end

-- the cups
-- (D-1438: TeaCupTex2 / 3 = the user's new cup, a post in the middle, 3 = the picture inside too)
local cupT = template({ "TeaCupTex4", "TeaCupTex3", "TeaCupTex2", "TeaCupTex", "TeaCup" })
local ownPost = cupT ~= nil and (cupT.Name == "TeaCupTex3" or cupT.Name == "TeaCupTex2")
local cup4 = cupT ~= nil and cupT.Name == "TeaCupTex4"
if cup4 then CUP_TEXTURES = CUP4_TEXTURES end
-- (D-1472, user 2026-11-16: "회전컵 디자인 변경 가져오기 했음": cup2-1..5.glb, five cups with animal ears,
-- each its own mesh and painted texture (cream, green, sky, orange, pink), kept place-only as
-- ServerStorage.ArtAssets.TeaCup5.Cup1..Cup5. Like Tex4 their floor is at the foot (0.04 of the
-- height, measured), so they take Tex4's leg benches and post; scaled by the bowl's width (Z, the
-- handle sticks out along X); the ears stand over the rim, so the seat height comes from the bowl
-- (0.669 of its width), not from the whole height)
local cupSet = art:FindFirstChild("TeaCup5")
local cup5 = cupSet ~= nil and cupSet:FindFirstChild("Cup1") ~= nil
local flat = cup4 or cup5
local BOWL5 = 0.669
-- (Tex4: its floor is near the bottom (0.046 of its height, measured), so the benches stand on legs
-- up to BENCH4 of its height, riders' shoulders over the rim; the post and wheel are built here)
local BENCH4 = 0.42
local seatRel = {}
for k = 1, CUPS do
	local a = (k - 1) / CUPS * 2 * math.pi
	local at = Vector3.new(C.X + CUP_R * math.cos(a), deckTop, C.Z + CUP_R * math.sin(a))
	local cup = Instance.new("Model")
	cup.Name = "Cup" .. k
	disc(cup, "SaucerRim", at, deckTop + 0.05, 0.3, CUP_D + 2.9, Color3.fromRGB(70, 150, 215))
	local saucer = disc(cup, "Saucer", at, deckTop + 0.1, 0.55, CUP_D + 2.6, Color3.fromRGB(248, 248, 246))
	local sTop = deckTop + 0.65
	local pivot = CFrame.new(at.X, sTop, at.Z)
	local floorY = sTop + 0.6
	local cupH = 0
	local tk = if cup5 then cupSet:FindFirstChild("Cup" .. ((k - 1) % #cupSet:GetChildren() + 1)) else cupT
	if tk then
		local m = placeMesh(tk, cup, "CupMesh", pivot, function(size) return CUP_D / (if cup5 then size.Z else math.max(size.X, size.Z)) end)
		local cf, size = m:GetBoundingBox()
		floorY = sTop + size.Y * (if cup5 then 0.04 elseif cup4 then 0.046 else 0.374) -- (the cup's floor: 0.43 of its 1.15 height in the glb)
		cupH = if cup5 then CUP_D * BOWL5 else size.Y
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("MeshPart") and not cup5 then
				if CUP_TEXTURES[k] ~= "" then
					d.TextureID = CUP_TEXTURES[k]
				elseif d.TextureID == "" then
					d.Color = CUP_COLORS[k]
				end
			end
		end
	end
	-- steering wheel in the middle, benches round it
	local benchTop = if flat then sTop + cupH * BENCH4 else floorY + 1.3
	local wheelY = floorY + 2.2
	if ownPost and not cup5 then
		wheelY = sTop + cupH * 0.885 -- (the top of the user's post: 0.885 of the cup's height)
	elseif flat then
		wheelY = benchTop + 1.5
		disc(cup, "WheelPost", at, floorY, wheelY - floorY, 0.55, Color3.fromRGB(150, 155, 160)).Material = Enum.Material.Metal
	else
		disc(cup, "WheelPost", at, floorY, 2.2, 0.5, Color3.fromRGB(150, 155, 160)).Material = Enum.Material.Metal
	end
	disc(cup, "Wheel", at, wheelY, 0.22, 2.6, Color3.fromRGB(60, 64, 72))
	disc(cup, "WheelHub", at, wheelY + 0.22, 0.2, 0.8, Color3.fromRGB(230, 190, 70))
	for s = 1, PER do
		local b = (s - 0.5) / PER * 2 * math.pi
		local br = if cup5 then 2.4 else 2.9 -- (TeaCup5: its wall leans in lower down: measured, the seats sit closer in)
		local p = Vector3.new(at.X + br * math.cos(b), 0, at.Z + br * math.sin(b))
		local face = CFrame.lookAt(Vector3.new(p.X, benchTop, p.Z), Vector3.new(at.X, benchTop, at.Z))
		local bh = benchTop - floorY -- (the bench from the cup's floor up to its seat)
		if flat then
			-- (the Tex4 bowl narrows to its foot: a seat on one thin leg, set inwards, stays inside it)
			part(cup, "Bench", if cup5 then Vector3.new(1.8, 0.4, 1.2) else Vector3.new(2.0, 0.4, 1.4), face * CFrame.new(0, -0.2, if cup5 then 0 else 0.1), Color3.fromRGB(248, 248, 246))
			part(cup, "BenchLeg", Vector3.new(0.45, bh - 0.4, 0.45), face * CFrame.new(0, -0.4 - (bh - 0.4) / 2, if cup5 then -1.2 else -1.0), Color3.fromRGB(200, 204, 210), Enum.Material.Metal) -- (leg 1.9 from the middle: the foot is 2.7 across at 0.4 up)
		else
			part(cup, "Bench", Vector3.new(2.0, bh, 1.6), face * CFrame.new(0, -bh / 2, 0.2), Color3.fromRGB(248, 248, 246))
		end
		if k == 1 then seatRel[s] = pivot:ToObjectSpace(face) end
	end
	cup.WorldPivot = pivot
	cup.Parent = ride
	ride:SetAttribute("Cup" .. k, CFrame.new(C):ToObjectSpace(pivot))
end
for s = 1, PER do ride:SetAttribute("SeatRel" .. s, seatRel[s]) end

ride:SetAttribute("Cups", CUPS)
ride:SetAttribute("SeatsPerCup", PER)
ride:SetAttribute("TurnPeriod", 14) -- (Ramp + Hold = 28 s at full speed: 2 table turns, 7 cup spins)
ride:SetAttribute("CupPeriod", 4)
ride:SetAttribute("PotPeriod", 24) -- (D-1474, user: "제자리에서 천천히 회전하기": the middle piece, one turn in 24 s, always)
ride:SetAttribute("Board", 15)
ride:SetAttribute("Ramp", 4)
ride:SetAttribute("Hold", 24)
ride:SetAttribute("Reach", base.Size.Y / 2 + 4)
ride:SetAttribute("Exit", Vector3.new(C.X + base.Size.Y / 2 + 2, base.Position.Y + base.Size.X / 2 + 3, C.Z))
for _, d in ipairs(ride:GetDescendants()) do -- (everything here moves on each screen: no shoving)
	if d:IsA("BasePart") then
		d.CanCollide = false
		d.CanQuery = false
	end
end
ride.WorldPivot = CFrame.new(C)
rotor.WorldPivot = CFrame.new(C)
CollectionService:AddTag(ride, "ParkTeaCups")
ride.Parent = owner
quiet(base, true)
-- the turning deck does not collide (it moves on each screen): an invisible still floor in its place
local floor = owner:FindFirstChild("DeckFloor") or Instance.new("Part")
floor.Name = "DeckFloor"
floor.Shape = Enum.PartType.Cylinder
floor.Size = deck.Size
floor.CFrame = deck.CFrame
floor.Transparency = 1
quiet(floor, true)
floor.Parent = owner
print(("[park_teacups_1115] cups %d (%s), teapot %s"):format(CUPS, if cup5 then "TeaCup5" elseif cupT then cupT.Name else "none", pot and pot.Name or "none"))
return CUPS
