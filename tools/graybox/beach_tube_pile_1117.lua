--!nocheck
-- 해변 튜브 더미 (D-1576, user 2026-11-17 with a photo of a heap of yellow / blue rubber rings on the sand
-- under a white tent: "해변 종합안내도 옆에 튜브 쌓아 놓고 들고 갈 수 있도록 수정").
-- Workspace.Hongdae_Layout.BeachTubePile (tag "TubePile"): about 18 rings (ServerStorage.ArtAssets.TubeMint,
-- yellow and a few blue) heaped on the sand just north of the beach guide map (BeachMapSign, x -212
-- z -152, 21 north of it), a small sign "튜브 무료 대여", and an invisible PromptPart where TubeRentService puts the
-- "튜브 들기" prompt. Run after build_beach_signs (it finds the map sign). Safe to run again.

local CS = game:GetService("CollectionService")
local T = workspace:FindFirstChild("Hongdae_Layout")
assert(T, "Hongdae_Layout missing")
local sign = T:FindFirstChild("BeachMapSign", true)
assert(sign, "BeachMapSign missing")
local ring = game:GetService("ServerStorage").ArtAssets:FindFirstChild("TubeMint")
assert(ring, "ArtAssets.TubeMint missing")
local ringPart = if ring:IsA("BasePart") then ring else ring:FindFirstChildWhichIsA("BasePart", true)

local old = T:FindFirstChild("BeachTubePile")
if old then old:Destroy() end
local pile = Instance.new("Model")
pile.Name = "BeachTubePile"

local SAND_Y = -1.8
local signCf = sign:GetBoundingBox()
-- beside the board on its north side (+z), a little towards the sea (-x), clear of the palm (PalmTreeP4,
-- its trunk about 10 north of the board)
local C = Vector3.new(signCf.Position.X - 5, SAND_Y, signCf.Position.Z + 21)
local YELLOW = Color3.fromRGB(255, 205, 20)
local BLUE = Color3.fromRGB(40, 130, 230)
local rng = Random.new(1117)

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = true
end

-- rings: a bottom layer lying flat, a second layer on it, and a few leaning against the heap
local spots = {
	-- x, z, height, tilt (deg), blue?
	{ -3.0, -2.2, 0, 0, false }, { 1.4, -2.6, 0, 0, false }, { -1.0, 1.2, 0, 0, true }, { 3.2, 1.0, 0, 0, false },
	{ -4.2, 2.0, 0, 0, false }, { 0.6, 4.0, 0, 0, false }, { -2.0, -5.0, 0, 0, false }, { 3.8, -4.6, 0, 0, true },
	{ -1.2, -1.0, 0.9, 12, false }, { 2.0, -0.6, 0.9, 10, false }, { -2.6, 2.6, 0.9, 14, false }, { 1.8, 2.8, 0.9, 8, true },
	{ 0.2, 0.6, 1.8, 18, false }, { -0.4, -3.2, 1.6, 16, false },
	{ -6.4, -0.4, 1.6, 70, false }, { 5.8, 0.2, 1.6, 68, false }, { 0.4, 6.8, 1.6, 72, true }, { -0.8, -7.4, 1.6, 66, false },
}
for i, s in ipairs(spots) do
	local p = ringPart:Clone()
	p.Name = "PileTube"
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("ModuleScript") then c:Destroy() end
	end
	p.Color = if s[5] then BLUE else YELLOW
	p.Material = Enum.Material.SmoothPlastic
	local yaw = rng:NextNumber(0, math.pi * 2)
	local out = Vector3.new(s[1], 0, s[2])
	local tiltAxis = if out.Magnitude > 0.1 then out.Unit else Vector3.new(1, 0, 0)
	-- leaning rings tip away from the heap's middle
	local cf = CFrame.new(C + Vector3.new(s[1], s[3] + p.Size.Y / 2, s[2]))
		* CFrame.fromAxisAngle(Vector3.new(-tiltAxis.Z, 0, tiltAxis.X), math.rad(s[4]))
		* CFrame.Angles(0, yaw, 0)
	p.CFrame = cf
	p.CanCollide = s[4] < 30
	quiet(p)
	p.Parent = pile
end

-- the sign
local post = Instance.new("Part")
post.Name = "PileSignPost"
post.Size = Vector3.new(0.3, 4.2, 0.3)
post.Color = Color3.fromRGB(70, 44, 32)
post.Material = Enum.Material.Wood
post.CFrame = CFrame.new(C + Vector3.new(5.4, 2.1, -6.2))
quiet(post)
post.Parent = pile
local board = Instance.new("Part")
board.Name = "PileSign"
board.Size = Vector3.new(0.2, 1.6, 4.2)
board.Color = YELLOW
board.Material = Enum.Material.SmoothPlastic
board.CFrame = CFrame.new(C + Vector3.new(5.5, 4.0, -6.2))
quiet(board)
board.Parent = pile
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Right -- (+x: the promenade side)
gui.CanvasSize = Vector2.new(420, 160)
gui.LightInfluence = 0.6
gui.Parent = board
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "튜브 무료 대여" -- (no emoji: the sign font has none)
label.TextColor3 = Color3.fromRGB(30, 60, 150)
label.Font = Enum.Font.GothamBlack
label.TextScaled = true
label.Parent = gui

-- where the prompt goes
local prompt = Instance.new("Part")
prompt.Name = "PromptPart"
prompt.Size = Vector3.new(1, 1, 1)
prompt.Transparency = 1
prompt.CanCollide, prompt.CanQuery = false, false
prompt.CFrame = CFrame.new(C + Vector3.new(0, 2.6, 0))
quiet(prompt)
prompt.Parent = pile

pile.PrimaryPart = prompt
CS:AddTag(pile, "TubePile")
pile.Parent = T
print(("[beach_tube_pile_1117] %d rings by the beach map at %s"):format(#spots, tostring(C)))
return #spots
