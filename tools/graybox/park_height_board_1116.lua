--!nocheck
-- 놀이공원 입구 키 재기 판 (D-1529, user 2026-11-16 + an amusement park height board photo (a giraffe with a
-- ruler): "놀이공원 입구 초입에 키재는 판 만들어놔 소방차 옆에 두자"). Our own giraffe, built from parts:
-- a yellow board (the neck) with brown spots, a white ruler strip 0..300 cm (1 stud = 28 cm, the usual
-- Roblox scale: ticks every 5 cm, round numbers every 20 cm in orange / brown), the giraffe's head on
-- top (horns, ears, eyes, cheeks, snout) looking at the walk, a green "키 재기" plate low on the neck.
-- At x -124, z -298 (east of the fire truck, by the way in from the gate), facing east. Only the board
-- collides. Model Workspace.키재기판 (rebuilt each run).

local G = 16.11
local CM = 1 / 28
local TOPCM = 300
local H = TOPCM * CM
local AT, FACE = Vector3.new(-124, G, -298), Vector3.new(1, 0, 0)
local YEL, BROWN, ORANGE = Color3.fromRGB(255, 206, 48), Color3.fromRGB(150, 85, 35), Color3.fromRGB(240, 150, 40)

local old = workspace:FindFirstChild("키재기판")
if old then old:Destroy() end
local m = Instance.new("Model")
m.Name = "키재기판"
local base = CFrame.lookAt(AT, AT + FACE)
local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local W = 2.6
local board = part("Board", Vector3.new(W, H + 0.6, 0.35), base * CFrame.new(0, (H + 0.6) / 2, 0), YEL)
board.CanCollide, board.CanQuery = true, true
part("Foot", Vector3.new(W + 0.8, 0.4, 1.4), base * CFrame.new(0, 0.2, 0.2), Color3.fromRGB(235, 180, 40))
local rng = Random.new(1529)
for k = 1, 9 do
	local y = 1.2 + k * 1.05
	if y > 2 then
		local x = -W / 2 + 0.35 + rng:NextNumber(0, 0.3)
		part("Spot", Vector3.new(0.1, rng:NextNumber(0.45, 0.7), rng:NextNumber(0.45, 0.7)), base * CFrame.new(x, y, -0.19) * CFrame.Angles(0, math.pi / 2, 0), BROWN, nil, Enum.PartType.Cylinder)
	end
end

-- the ruler
local strip = part("Ruler", Vector3.new(1.35, H, 0.06), base * CFrame.new(0.45, H / 2, -0.2), Color3.fromRGB(255, 255, 255))
for _, faceId in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local g = Instance.new("SurfaceGui")
	g.Face, g.LightInfluence = faceId, 0.2
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(1.35 * 60, H * 60)
	g.Parent = strip
	local hpx, wpx = H * 60, 1.35 * 60
	for cm = 0, TOPCM, 5 do
		local y = hpx - cm * CM * 60
		local long = cm % 10 == 0
		local t = Instance.new("Frame")
		t.BorderSizePixel, t.BackgroundColor3 = 0, Color3.fromRGB(70, 45, 25)
		t.Size = UDim2.fromOffset(if long then 26 else 14, if long then 3 else 2)
		t.Position = UDim2.fromOffset(0, y - 1)
		t.Parent = g
		if cm % 20 == 0 and cm > 0 then
			local c = Instance.new("TextLabel")
			c.Size, c.Position = UDim2.fromOffset(46, 46), UDim2.fromOffset(wpx - 50, y - 23)
			c.BackgroundColor3 = if (cm / 20) % 2 == 0 then ORANGE else BROWN
			c.Text, c.Font, c.TextScaled, c.TextColor3 = tostring(cm), Enum.Font.GothamBlack, true, Color3.new(1, 1, 1)
			c.Parent = g
			Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
			local pad = Instance.new("UIPadding", c)
			pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0), UDim.new(0.2, 0), UDim.new(0.2, 0)
		end
	end
	local z = Instance.new("TextLabel")
	z.Size, z.Position, z.BackgroundTransparency = UDim2.fromOffset(40, 20), UDim2.fromOffset(wpx - 44, hpx - 24), 1
	z.Text, z.Font, z.TextScaled, z.TextColor3 = "0cm", Enum.Font.GothamBold, true, Color3.fromRGB(70, 45, 25)
	z.Parent = g
end

-- the head
local top = base * CFrame.new(0, H + 0.6, 0)
part("Head", Vector3.new(2.6, 2.2, 2.4), top * CFrame.new(0, 1.3, 0.1), YEL, nil, Enum.PartType.Ball)
part("Snout", Vector3.new(1.8, 1.2, 1.4), top * CFrame.new(0, 0.9, -1.05), Color3.fromRGB(255, 225, 120), nil, Enum.PartType.Ball)
for _, sx in ipairs({ -1, 1 }) do
	part("Eye", Vector3.new(0.42, 0.42, 0.42), top * CFrame.new(sx * 0.62, 1.75, -0.95), Color3.fromRGB(30, 25, 25), nil, Enum.PartType.Ball)
	part("EyeShine", Vector3.new(0.14, 0.14, 0.14), top * CFrame.new(sx * 0.62 + 0.08, 1.86, -1.13), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
	part("Cheek", Vector3.new(0.5, 0.32, 0.2), top * CFrame.new(sx * 0.95, 1.15, -0.95), Color3.fromRGB(255, 140, 150), nil, Enum.PartType.Ball)
	part("Nostril", Vector3.new(0.16, 0.16, 0.16), top * CFrame.new(sx * 0.28, 1.05, -1.72), Color3.fromRGB(120, 70, 30), nil, Enum.PartType.Ball)
	part("Horn", Vector3.new(0.9, 0.22, 0.22), top * CFrame.new(sx * 0.55, 2.75, 0.2) * CFrame.Angles(0, 0, math.rad(90 + sx * 12)), YEL, nil, Enum.PartType.Cylinder)
	part("HornTip", Vector3.new(0.42, 0.42, 0.42), top * CFrame.new(sx * 0.65, 3.2, 0.2), BROWN, nil, Enum.PartType.Ball)
	part("Ear", Vector3.new(0.9, 0.35, 0.55), top * CFrame.new(sx * 1.45, 2.0, 0.25) * CFrame.Angles(0, 0, math.rad(sx * 25)), YEL, nil, Enum.PartType.Ball)
end
part("HeadSpot", Vector3.new(0.6, 0.5, 0.15), top * CFrame.new(0.5, 2.05, -0.75) * CFrame.Angles(math.rad(-30), 0, 0), ORANGE, nil, Enum.PartType.Ball)

-- the plate low on the neck, beside the ruler
local plate = part("Plate", Vector3.new(1.0, 0.8, 0.1), base * CFrame.new(-0.75, 1.4, -0.23), Color3.fromRGB(95, 190, 80))
for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local sg = Instance.new("SurfaceGui")
	sg.Face, sg.CanvasSize, sg.LightInfluence = f, Vector2.new(100, 80), 0.2
	sg.Parent = plate
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Font, t.TextScaled, t.TextColor3, t.Text = UDim2.fromScale(1, 1), 1, Enum.Font.GothamBlack, true, Color3.new(1, 1, 1), "키 재기"
	t.Parent = sg
	local pad = Instance.new("UIPadding", t)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.15, 0), UDim.new(0.15, 0)
end
m.PrimaryPart = board
m.Parent = workspace
print("[park_height_board_1116] built")
return "built"
