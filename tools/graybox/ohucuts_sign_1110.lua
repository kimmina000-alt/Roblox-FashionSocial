-- 오후네컷 shop signs in a real font (D-1184, user 2026-11-10: "간판 폰트 다른 걸로 후보
-- 줘. 색상 연핑크로 변경" → picked candidate 8, 강원교육튼튼).
-- The three channel-letter signs build_hongdae_layout makes (Sign_OhuNeCut on the
-- cut corner, Sign_OHU4cuts on the north and south bands) are parked in
-- ServerStorage.ParkedOhuSigns and replaced, at the same spot and length, by a
-- thin board with the sign as an image (light pink #FFB6CE with a darker pink
-- edge for depth, transparent around it; tools/art: docs/04_ART/references/
-- ohucuts_sign_fonts.png has the candidates).
-- Chain step 3-21 (tools/graybox/LAYOUT.md), last. Runs again without doubling.

local ServerStorage = game:GetService("ServerStorage")

local IMAGES = {
	Sign_OhuNeCut = { id = "rbxassetid://86726202724660", aspect = 1024 / 226 }, -- ◎ 오후네컷
	Sign_OHU4cuts = { id = "rbxassetid://78065484134233", aspect = 1024 / 167 }, -- ◎ OHU4cuts
}

local layout = workspace:FindFirstChild("Hongdae_Layout")
local shop = layout and layout:FindFirstChild("OhuFourCuts")
assert(shop, "Hongdae_Layout.OhuFourCuts not found: run build_hongdae_layout first")

local parked = ServerStorage:FindFirstChild("ParkedOhuSigns")
if not parked then
	parked = Instance.new("Folder")
	parked.Name = "ParkedOhuSigns"
	parked.Parent = ServerStorage
end

-- the image boards made by an earlier run go first
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

local made = 0
for _, m in ipairs(list) do
	local spec = IMAGES[m.Name]
	do
		local letters = m:FindFirstChild("Letters")
		local cf, size = m:GetBoundingBox()
		-- the letters' faces point out of the wall (sign3d: each stroke's Y axis)
		local out = if letters and letters:IsA("BasePart") then letters.CFrame.UpVector else cf.UpVector
		out = Vector3.new(out.X, 0, out.Z).Unit
		local right = Vector3.yAxis:Cross(out)
		local length = math.max(size.X, size.Y, size.Z) -- the sign's run along the wall
		local height = length / spec.aspect
		local board = Instance.new("Part")
		board.Name = m.Name .. "_Image"
		board:SetAttribute("OhuSignImage", true)
		board.Size = Vector3.new(length, height, 0.05)
		-- flat on the wall where the letters stood (their back 0.2 behind the middle);
		-- the front face looks out, its right vector to the left of someone reading
		-- it, so the SurfaceGui reads left to right from the street
		board.CFrame = CFrame.fromMatrix(cf.Position - out * 0.17, -right, Vector3.yAxis, -out)
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
		gui.LightInfluence = 0.4
		gui.MaxDistance = 400
		gui.Parent = board
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = spec.id
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = gui
		board.Parent = shop
		m:SetAttribute("ParkedBy", "ohucuts_sign_1110")
		m.Parent = parked
		made += 1
	end
end
print(string.format("ohucuts_sign_1110: %d image signs (old channel letters parked in ServerStorage.ParkedOhuSigns)", made))
