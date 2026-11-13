-- (D-1389, user 2026-11-13: "원통형 전광판 삭제하고 네모판을 살짝 사선으로 틀어서 넣어 봐" with a
-- sketch: the two boards at the ends of the DJ's LED wall, turned in towards the room)
-- The two round LED pillars of 02_Club (build_main_social_graybox: 12 panels each, so the
-- shown dancer was copied 24 times and posed on every update: heavy on phones, D-1388)
-- become flat LED boards on the same spots, turned TURN degrees in towards the middle of
-- the room. A board is still a Model named "LEDPillar" tagged "LEDPillar" (ClubScreenService
-- picks who is shown, ClubLightsController draws the live copy) with attribute Flat = true
-- and one "Panel" (Slice 0): one copy per board, no travelling picture.
-- Board = black frame + panel + a thin pink neon edge (ClubBeat) on two black legs.
-- Chain step after club_vip_bar_1107 (tools/graybox/LAYOUT.md); idempotent: pillars that are
-- still round are replaced, flat boards are rebuilt the same.

local CS = game:GetService("CollectionService")
local club = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("02_Club")

local FLOOR = -24 -- the dance floor's top here
local W, H = 20, 36 -- the panel (the DJ's LED wall is 36 high, y -14..22)
local BOTTOM = -14 -- the panel's lower edge, level with the LED wall
local TURN = math.rad(35) -- in towards the room
local ROOM_X = 126.5 -- the DJ's middle: boards west of it turn east and the other way
local SPOTS = { Vector3.new(82.5, 0, -140), Vector3.new(171, 0, -140) } -- (the pillars' centres)

local BLACK = Color3.fromRGB(12, 10, 18)
local PINK = Color3.fromRGB(255, 70, 170)

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

-- where the boards go: the round pillars' spots (after a chain rebuild) or the known ones
local spots = {}
for _, m in ipairs(club:GetChildren()) do
	if m:IsA("Model") and m.Name == "LEDPillar" then
		if m:GetAttribute("Flat") ~= true then
			local core = m:FindFirstChild("Core")
			if core and core:IsA("BasePart") then table.insert(spots, Vector3.new(core.Position.X, 0, core.Position.Z)) end
		end
		m:Destroy()
	end
end
if #spots == 0 then spots = SPOTS end

for _, spot in ipairs(spots) do
	local side = if spot.X < ROOM_X then 1 else -1
	-- the board faces the room (-Z), turned towards the middle
	local normal = Vector3.new(side * math.sin(TURN), 0, -math.cos(TURN))
	local mid = Vector3.new(spot.X, BOTTOM + H / 2, spot.Z)
	local face = CFrame.lookAt(mid, mid + normal) -- LookVector = normal, so the Front face shows
	local m = Instance.new("Model")
	m.Name = "LEDPillar"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("Flat", true)
	part(m, "Core", Vector3.new(W + 1.2, H + 1.2, 1), face * CFrame.new(0, 0, 0.6), BLACK, false, true)
	local panel = part(m, "Panel", Vector3.new(W, H, 0.2), face * CFrame.new(0, 0, -0.05), Color3.fromRGB(20, 10, 40))
	panel:SetAttribute("Slice", 0)
	-- the neon edge round the panel
	for _, e in ipairs({
		{ Vector3.new(W + 1.2, 0.35, 0.3), CFrame.new(0, H / 2 + 0.6, -0.1) },
		{ Vector3.new(W + 1.2, 0.35, 0.3), CFrame.new(0, -H / 2 - 0.6, -0.1) },
		{ Vector3.new(0.35, H + 1.2, 0.3), CFrame.new(W / 2 + 0.6, 0, -0.1) },
		{ Vector3.new(0.35, H + 1.2, 0.3), CFrame.new(-W / 2 - 0.6, 0, -0.1) },
	}) do
		local edge = part(m, "Edge", e[1], face * e[2], PINK, true)
		CS:AddTag(edge, "ClubBeat")
	end
	-- two legs from the floor to the frame
	local legH = BOTTOM - 0.6 - FLOOR
	for _, x in ipairs({ -W / 2 + 3, W / 2 - 3 }) do
		local foot = (face * CFrame.new(x, 0, 0.6)).Position
		part(m, "Leg", Vector3.new(1, legH, 1), CFrame.new(foot.X, FLOOR + legH / 2, foot.Z) * face.Rotation, BLACK, false, true)
	end
	local anchor = part(m, "NameAnchor", Vector3.new(1, 1, 1), CFrame.new(spot.X, FLOOR + 14, spot.Z), BLACK)
	anchor.Transparency = 1
	m.Parent = club
	CS:AddTag(m, "LEDPillar")
end
print("[club_flat_screens_1113] flat LED boards:", #spots)
return #spots
