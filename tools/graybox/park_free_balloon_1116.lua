--!nocheck
-- 놀이공원 개장 기념 풍선 무료 (D-1531, user 2026-11-16: "놀이공원 문은 닫아 놓고 Vantablack_Dev만 막힌 문
-- 통과할 수 있게 해 줘. 풍선은 무료로 나눠 줘. 입구 앞 매표소 옆에 표지판 세워 놔. ★ 놀이공원 개장 기념
-- 풍선 무료 ★"). The balloon shop stands inside the closed park, so the two ticket booths outside the
-- gate hand balloons out too:
--   * an invisible counter in front of each booth window (tag SnackShop, Shop = "BalloonShop": the
--     same menu, 0 coins, SnackService gives the balloon) and a bunch of balloons tied by the window;
--   * a standing sign on the landing just left of the west booth: "★ 놀이공원 개장 기념 ★ / 풍선 무료 /
--     매표소에서 받아 가세요", sunset colours of the logo, balloons tied to its top corners.
-- Model Workspace.무료풍선 (rebuilt each run). The booths themselves are in Hongdae_Layout (chain).

local CS = game:GetService("CollectionService")
local G = 16.08
local BOOTHS = { Vector3.new(-136, 0, -268.05), Vector3.new(-61, 0, -268.05) } -- (sill fronts)
local SIGN_AT = Vector3.new(-147.2, G, -262)
local COLORS = { Color3.fromRGB(235, 60, 75), Color3.fromRGB(255, 140, 190), Color3.fromRGB(255, 210, 60), Color3.fromRGB(110, 225, 190), Color3.fromRGB(80, 150, 255), Color3.fromRGB(165, 110, 235) }

local old = workspace:FindFirstChild("무료풍선")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "무료풍선"

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a balloon: the shop's balloon mesh when the place has it, else a ball; a thin string down to `tie`
local shopBalloon = workspace:FindFirstChild("BalloonShop") and workspace.BalloonShop:FindFirstChild("Balloon1")
local function balloon(parent: Instance, at: Vector3, tie: Vector3, color: Color3)
	local b
	if shopBalloon and shopBalloon:IsA("MeshPart") then
		b = shopBalloon:Clone()
		b.Name = "Balloon"
		b.Size = shopBalloon.Size * 0.8
		b.CFrame = CFrame.new(at) * CFrame.Angles(0, math.rad(at.X * 37 % 360), 0)
		b.Color = color
		b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery = true, false, false, false
		for _, c in ipairs(b:GetChildren()) do c:Destroy() end
		b.Parent = parent
	else
		b = part(parent, "Balloon", Vector3.new(2.4, 2.9, 2.4), CFrame.new(at), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	local low = at - Vector3.new(0, b.Size.Y / 2, 0)
	part(parent, "BalloonString", Vector3.new(0.05, 0.05, (low - tie).Magnitude), CFrame.lookAt((low + tie) / 2, tie), Color3.fromRGB(245, 245, 245))
end

---------------------------------------------------------------- the booths
for i, at in ipairs(BOOTHS) do
	local m = Instance.new("Model")
	m.Name = "BoothBalloons" .. i
	m.Parent = root
	-- the counter the prompt hangs on (invisible, in front of the window, at hand height)
	local counter = part(m, "BalloonCounter", Vector3.new(7, 3, 2), CFrame.new(at.X, 19.6, at.Z + 0.6), Color3.new(1, 1, 1))
	counter.Transparency = 1
	counter:SetAttribute("Shop", "BalloonShop")
	CS:AddTag(counter, "SnackShop")
	-- a bunch tied to the sill's outer corner
	local side = if i == 1 then -1 else 1
	local tie = Vector3.new(at.X + side * 3.6, 19.0, at.Z + 0.6)
	for k = 1, 5 do
		local a = (k / 5) * math.pi * 2
		local up = Vector3.new(at.X + side * 4.6 + math.cos(a) * 1.4, 26.2 + (k % 2) * 1.3, at.Z + 0.6 + math.sin(a) * 1.4)
		balloon(m, up, tie, COLORS[(k + i * 2) % #COLORS + 1])
	end
end

---------------------------------------------------------------- the sign
local sign = Instance.new("Model")
sign.Name = "FreeBalloonSign"
sign.Parent = root
local base = CFrame.lookAt(SIGN_AT, SIGN_AT + Vector3.new(0, 0, 1)) -- facing the way in (+Z)
local W, H, BOTTOM = 8.2, 5.4, 2.6
local POST = Color3.fromRGB(250, 248, 242)
for _, sx in ipairs({ -1, 1 }) do
	part(sign, "Post", Vector3.new(0.35, BOTTOM + H + 0.4, 0.35), base * CFrame.new(sx * (W / 2 - 0.4), (BOTTOM + H + 0.4) / 2, 0.05), POST, Enum.Material.Metal)
	part(sign, "Foot", Vector3.new(0.9, 0.25, 1.4), base * CFrame.new(sx * (W / 2 - 0.4), 0.12, 0.05), POST, Enum.Material.Metal)
end
part(sign, "Frame", Vector3.new(W + 0.3, H + 0.3, 0.22), base * CFrame.new(0, BOTTOM + H / 2, 0), POST)
local board = part(sign, "Board", Vector3.new(W, H, 0.3), base * CFrame.new(0, BOTTOM + H / 2, 0), Color3.new(1, 1, 1))
board.CanCollide, board.CanQuery = true, true
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local g = Instance.new("SurfaceGui")
	g.Name = "FreeBalloonText"
	g.Face, g.LightInfluence = face, 0.15
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(W * 40, H * 40) -- (TextScaled stops at 100 px: a small canvas lets the words fill the board)
	g.Parent = board
	local bg = Instance.new("Frame")
	bg.Size, bg.BorderSizePixel, bg.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 179, 107)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 111, 145)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(122, 92, 255)),
	})
	grad.Rotation = 20
	grad.Parent = bg
	local function label(text: string, y: number, h: number, weight: Enum.FontWeight, color: Color3)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size, t.Position = UDim2.new(0.9, 0, h, 0), UDim2.new(0.05, 0, y, 0)
		t.Text, t.TextScaled, t.TextColor3 = text, true, color
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
		t.Parent = bg
		local s = Instance.new("UIStroke")
		s.Thickness, s.Color, s.Transparency = 2, Color3.fromRGB(120, 40, 90), 0.35
		s.Parent = t
		return t
	end
	label("★ 놀이공원 개장 기념 ★", 0.06, 0.25, Enum.FontWeight.Heavy, Color3.fromRGB(255, 245, 190))
	label("풍선 무료", 0.32, 0.42, Enum.FontWeight.Heavy, Color3.new(1, 1, 1))
	label("매표소에서 받아 가세요", 0.76, 0.17, Enum.FontWeight.Bold, Color3.new(1, 1, 1))
end
-- balloons tied to the top corners
for _, sx in ipairs({ -1, 1 }) do
	local tie = (base * CFrame.new(sx * (W / 2 - 0.4), BOTTOM + H + 0.4, 0.05)).Position
	for k = 1, 3 do
		local up = tie + Vector3.new(sx * (0.6 + (k - 1) * 0.9), 3.4 + (k % 2) * 1.2, (k - 2) * 1.0)
		balloon(sign, up, tie, COLORS[(k + (sx + 1) * 2) % #COLORS + 1])
	end
end

root.Parent = workspace
print("[park_free_balloon_1116] built")
return "built"
