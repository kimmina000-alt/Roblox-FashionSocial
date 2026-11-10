-- 오후네컷 shop signs in a real font (D-1184, user 2026-11-10: "간판 폰트 다른 걸로 후보
-- 줘. 색상 연핑크로 변경" → picked candidate 8, 강원교육튼튼).
-- The three channel-letter signs build_hongdae_layout makes (Sign_OhuNeCut on the
-- cut corner, Sign_OHU4cuts on the north and south bands) are parked in
-- ServerStorage.ParkedOhuSigns and replaced, at the same spot and length, by the
-- sign in that font (tools/art: docs/04_ART/references/ohucuts_sign_fonts.png has
-- the candidates).
-- (D-1261, user 2026-11-10: "오후네컷 간판 입체감 줘. 기존의 두께 있는 텍스트로. 폰트는
-- 지금 걸로.") as thick letters like the old channel letters (0.4 deep): the
-- face (light pink #FFB6CE) in front, LAYERS copies of the same glyphs in a
-- darker pink (#E280A0) behind it down to the wall, so from the side the letters
-- have a solid edge. Each layer is a thin board with the glyphs as an image
-- (transparent around them).
-- Chain step 3-21 (tools/graybox/LAYOUT.md). Runs again without doubling.

local ServerStorage = game:GetService("ServerStorage")

local IMAGES = {
	-- face / side images: the same canvas, so the layers line up
	Sign_OhuNeCut = { face = "rbxassetid://110718121919044", side = "rbxassetid://115487475276629", aspect = 4.6689 }, -- ◎ 오후네컷
	Sign_OHU4cuts = { face = "rbxassetid://126504515176604", side = "rbxassetid://75321385896933", aspect = 6.338 }, -- ◎ OHU4cuts
}
local DEPTH = 0.4 -- the old channel letters' depth
local LAYERS = 10 -- side copies between the wall and the face

local layout = workspace:FindFirstChild("Hongdae_Layout")
local shop = layout and layout:FindFirstChild("OhuFourCuts")
assert(shop, "Hongdae_Layout.OhuFourCuts not found: run build_hongdae_layout first")

local parked = ServerStorage:FindFirstChild("ParkedOhuSigns")
if not parked then
	parked = Instance.new("Folder")
	parked.Name = "ParkedOhuSigns"
	parked.Parent = ServerStorage
end

-- the boards made by an earlier run go first
for _, c in ipairs(shop:GetChildren()) do
	if c:GetAttribute("OhuSignImage") then c:Destroy() end
end

-- the signs a fresh build_hongdae_layout made (then older parked copies go);
-- run again without a rebuild: the parked ones give the spots
local list = {}
for _, m in ipairs(shop:GetChildren()) do
	if m:IsA("Model") and IMAGES[m.Name] then table.insert(list, m) end
end
if #list > 0 then
	parked:ClearAllChildren()
else
	for _, m in ipairs(parked:GetChildren()) do
		if m:IsA("Model") and IMAGES[m.Name] then table.insert(list, m) end
	end
end

local function layer(parent: Instance, name: string, cf: CFrame, w: number, h: number, image: string, light: number)
	local board = Instance.new("Part")
	board.Name = name
	board.Size = Vector3.new(w, h, 0.02)
	board.CFrame = cf
	board.Transparency = 1
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.CastShadow = false
	board.Locked = true
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- (the board's look vector = out of the wall)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = light
	gui.MaxDistance = 400
	gui.Parent = board
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = gui
	board.Parent = parent
end

local made = 0
for _, m in ipairs(list) do
	local spec = IMAGES[m.Name]
	local letters = m:FindFirstChild("Letters")
	local cf, size = m:GetBoundingBox()
	-- the letters' faces point out of the wall (sign3d: each stroke's Y axis)
	local out = if letters and letters:IsA("BasePart") then letters.CFrame.UpVector else cf.UpVector
	out = Vector3.new(out.X, 0, out.Z).Unit
	local right = Vector3.yAxis:Cross(out)
	local length = math.max(size.X, size.Y, size.Z) -- the sign's run along the wall
	local height = length / spec.aspect
	local wall = cf.Position - out * (DEPTH / 2) -- (the old letters' back, on the wall)
	local sign = Instance.new("Model")
	sign.Name = m.Name .. "_3D"
	sign:SetAttribute("OhuSignImage", true)
	-- the right vector to the left of someone reading it, so the SurfaceGui reads
	-- left to right from the street
	local function at(d: number): CFrame
		return CFrame.fromMatrix(wall + out * d, -right, Vector3.yAxis, -out)
	end
	for k = 0, LAYERS - 1 do
		layer(sign, "SignSide", at(0.02 + (DEPTH - 0.05) * k / (LAYERS - 1)), length, height, spec.side, 0.6)
	end
	layer(sign, "SignFace", at(DEPTH), length, height, spec.face, 0.35)
	sign.Parent = shop
	m:SetAttribute("ParkedBy", "ohucuts_sign_1110")
	m.Parent = parked
	made += 1
end
return string.format("ohucuts_sign_1110: %d thick signs, %d layers each (old channel letters parked in ServerStorage.ParkedOhuSigns)", made, LAYERS + 1)
