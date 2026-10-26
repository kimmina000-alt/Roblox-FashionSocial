--!nocheck
-- Beach signs after the user's 광안리 photo (D-321, 2026-10-26): a big brown
-- guide map board on two posts ("2026년 오후 해변 종합안내도": map, legend,
-- opening times, prohibited-item icons, sea rules) and a brown surfboard
-- board with the sea rules and a bridge drawing. The faces are images drawn
-- by scratchpad beach_sign.ps1 (docs/04_ART/textures/beach_*_board.png).
-- Run in Edit mode after build_hongdae_layout (tools/graybox/LAYOUT.md step
-- 3-3); idempotent: it replaces BeachMapSign / BeachRulesSign.

local T = workspace:FindFirstChild("Hongdae_Layout")
assert(T, "Hongdae_Layout missing")

local MAP_IMAGE = "rbxassetid://86960782637506" -- v2: the real layout, north up (user 2026-10-26)
local RULES_IMAGE = "rbxassetid://129295787028454"
local SAND_Y = -1.8 -- the beach's sand top (CURB 0.6 - BEACH_DROP 2.4)
local X = -212 -- the boards stand on the sand by the promenade steps, facing +X (the promenade)
local BROWN = Color3.fromRGB(92, 52, 40)
local POST = Color3.fromRGB(70, 44, 32)

for _, name in ipairs({ "BeachMapSign", "BeachRulesSign" }) do
	for _, old in ipairs(T:GetDescendants()) do
		if old.Name == name and old:IsA("Model") then old:Destroy() end
	end
end

local function part(parent, name, size, cf, color, opt)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opt and opt.material) or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt and opt.shape then p.Shape = opt.shape end
	if opt and opt.nocol then
		p.CanCollide = false
		p.CanQuery = false
	end
	p.Parent = parent
	return p
end
local function face(p, image)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Right -- +X, toward the promenade
	d.Texture = image
	d.Parent = p
end

-- guide map board: 10.4 wide (along Z), 7.9 tall, on two posts
do
	local m = Instance.new("Model")
	m.Name = "BeachMapSign"
	local z, W, H = -152, 10.4, 7.9
	local y0 = SAND_Y + 1.6
	for _, dz in ipairs({ -W / 2 + 0.4, W / 2 - 0.4 }) do
		part(m, "SignPost", Vector3.new(0.5, y0 + H - SAND_Y + 0.2, 0.5), CFrame.new(X - 0.25, (SAND_Y + y0 + H + 0.2) / 2, z + dz), POST, { material = Enum.Material.Wood })
	end
	part(m, "SignFrame", Vector3.new(0.35, H, W), CFrame.new(X, y0 + H / 2, z), BROWN, { material = Enum.Material.Wood })
	local content = part(m, "SignContent", Vector3.new(0.05, H - 0.6, W - 0.6), CFrame.new(X + 0.2, y0 + H / 2, z), Color3.new(1, 1, 1), { nocol = true })
	face(content, MAP_IMAGE)
	m.Parent = T
end

-- surfboard rules board: 3.6 wide, 8.4 + round ends, on two short legs
do
	local m = Instance.new("Model")
	m.Name = "BeachRulesSign"
	local z, W, H = -166, 3.6, 8.4
	local bottom = SAND_Y + 1.8
	local mid = bottom + W / 2 + H / 2
	part(m, "SignBoard", Vector3.new(0.3, H, W), CFrame.new(X, mid, z), BROWN)
	for _, y in ipairs({ bottom + W / 2, bottom + W / 2 + H }) do
		part(m, "SignBoardEnd", Vector3.new(0.3, W, W), CFrame.new(X, y, z), BROWN, { shape = Enum.PartType.Cylinder })
	end
	local content = part(m, "SignContent", Vector3.new(0.05, H - 0.4, W - 0.5), CFrame.new(X + 0.18, mid, z), Color3.new(1, 1, 1), { nocol = true })
	face(content, RULES_IMAGE)
	for _, dz in ipairs({ -0.9, 0.9 }) do
		part(m, "SignLeg", Vector3.new(0.25, 2.1, 0.25), CFrame.new(X, SAND_Y + 1.05, z + dz), POST)
	end
	m.Parent = T
end
return "beach signs built"
