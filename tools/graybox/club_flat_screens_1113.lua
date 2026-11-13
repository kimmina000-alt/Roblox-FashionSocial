-- (D-1389, user 2026-11-13: "원통형 전광판 삭제하고 네모판을 살짝 사선으로 틀어서 넣어 봐" with a
-- sketch: the two boards at the ends of the DJ's LED wall, turned in towards the room)
-- The two round LED pillars of 02_Club (build_main_social_graybox: 12 panels each, so the
-- shown dancer was copied 24 times and posed on every update: heavy on phones, D-1388)
-- become flat LED boards on the same spots, turned TURN degrees in towards the middle of
-- the room. A board is still a Model named "LEDPillar" tagged "LEDPillar" (ClubScreenService
-- picks who is shown, ClubLightsController draws the live copy) with attribute Flat = true
-- and one "Panel" (Slice 0): one copy per board, no travelling picture.
-- Board = black frame + panel + a thin white neon edge.
-- (D-1391, user 2026-11-13: "전광판 내가 살짝 수정했거든 다리 지우고 크기 키우고 조금 더 회전했음 반대쪽
-- 것도 대칭되게 수정해 줘") Sizes and spot from the user's own edit of the east board (no legs,
-- x1.52, moved): the west board is its mirror image across the DJ's LED wall middle (x 126.5).
-- Chain step after club_vip_bar_1107 (tools/graybox/LAYOUT.md); idempotent: every LEDPillar
-- model in 02_Club (round or flat) is replaced by the two boards.

local CS = game:GetService("CollectionService")
local club = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("02_Club")

local S = 1.5197 -- (the user's scale of the first boards)
local W, H = 20 * S, 36 * S -- the panel: 30.39 x 54.71
local MIDDLE_X = 126.5 -- the DJ's LED wall middle: the boards are mirror images across it
-- the east board's panel middle and turn (the user's edit); the west one is mirrored
local EAST = Vector3.new(172.075, 6.397, -146.833)
local TURN = math.rad(35)

local BLACK = Color3.fromRGB(12, 10, 18)
-- (D-1392, user 2026-11-13: "프레임 조명선 분홍에서 하얀색으로") white neon edge, not tagged
-- ClubBeat (that tag would tint it with the DJ's colour pick)
local EDGE = Color3.fromRGB(255, 255, 255)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean?, solid: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

for _, m in ipairs(club:GetChildren()) do
	if m:IsA("Model") and m.Name == "LEDPillar" then m:Destroy() end
end

local boards = {
	{ mid = EAST, side = -1 }, -- east of the DJ: faces the room turned west
	{ mid = Vector3.new(2 * MIDDLE_X - EAST.X, EAST.Y, EAST.Z), side = 1 },
}
for _, b in ipairs(boards) do
	-- the board faces the room (-Z), turned towards the middle
	local normal = Vector3.new(b.side * math.sin(TURN), 0, -math.cos(TURN))
	local face = CFrame.lookAt(b.mid, b.mid + normal) -- LookVector = normal, so the Front face shows
	local m = Instance.new("Model")
	m.Name = "LEDPillar"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("Flat", true)
	part(m, "Core", Vector3.new(W + 1.2 * S, H + 1.2 * S, S), face * CFrame.new(0, 0, 0.65 * S), BLACK, false, true)
	local panel = part(m, "Panel", Vector3.new(W, H, 0.2 * S), face, Color3.fromRGB(20, 10, 40))
	panel:SetAttribute("Slice", 0)
	-- the neon edge round the panel
	local eW, eH, eT, eD = W + 1.2 * S, H + 1.2 * S, 0.35 * S, 0.3 * S
	for _, e in ipairs({
		{ Vector3.new(eW, eT, eD), CFrame.new(0, H / 2 + 0.6 * S, -0.05 * S) },
		{ Vector3.new(eW, eT, eD), CFrame.new(0, -H / 2 - 0.6 * S, -0.05 * S) },
		{ Vector3.new(eT, eH, eD), CFrame.new(W / 2 + 0.6 * S, 0, -0.05 * S) },
		{ Vector3.new(eT, eH, eD), CFrame.new(-W / 2 - 0.6 * S, 0, -0.05 * S) },
	}) do
		part(m, "Edge", e[1], face * e[2], EDGE, true)
	end
	local anchor = part(m, "NameAnchor", Vector3.new(1, 1, 1) * S, CFrame.new((face * CFrame.new(0, -14 * S, 0.05 * S)).Position), BLACK)
	anchor.Transparency = 1
	m.Parent = club
	CS:AddTag(m, "LEDPillar")
end
print("[club_flat_screens_1113] flat LED boards:", #boards)
return #boards
