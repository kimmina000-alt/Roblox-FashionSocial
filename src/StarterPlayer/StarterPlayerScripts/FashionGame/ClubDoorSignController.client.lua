--!strict
-- The club door sign while the club is closed by day (CLUB.md §20, D-320):
-- "🌙 클럽은 밤에 열려요 · 오픈까지 n분", worked out from the shared game clock.
-- Hidden at night and while the clock is pinned for building.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))

local night = ClubConfig.NightEntry
if not night.Enabled then return end

local anchor = Instance.new("Part")
anchor.Name = "ClubDoorSignAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Transparency = 1
anchor.Size = Vector3.new(0.2, 0.2, 0.2)
anchor.CFrame = CFrame.new(night.DoorPosition)
anchor.Parent = workspace

local sign = Instance.new("BillboardGui")
sign.Name = "ClubClosedSign"
sign.Size = UDim2.fromOffset(120, 28) -- (half the size, white text: user 2026-10-27)
sign.MaxDistance = 60
sign.LightInfluence = 0
sign.Adornee = anchor
sign.Enabled = false
sign.Parent = anchor
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1 -- (no box, white letters only: user 2026-10-27)
label.TextColor3 = Color3.new(1, 1, 1)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Parent = sign
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 4)
pad.Parent = label

-- (user 2026-10-31) while the club is open the doorway glows from inside:
-- a pink-violet haze a few studs in (seen through the open door), a light
-- filling the foyer and one spilling out over the sidewalk
local DOOR = night.DoorPosition -- (x 46.5: the door is in the wall at x 49, the club east of it)
local glow = Instance.new("Model")
glow.Name = "ClubDoorGlow"
local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency
	p.Parent = glow
	return p
end
local haze = piece("Haze", Vector3.new(0.2, 16, 14), CFrame.new(DOOR.X + 12, DOOR.Y + 1, DOOR.Z), Color3.fromRGB(190, 80, 255), 0.82)
local inside = Instance.new("PointLight")
inside.Color, inside.Range, inside.Brightness, inside.Shadows = Color3.fromRGB(200, 100, 255), 18, 2, false
inside.Parent = haze
local spill = piece("Spill", Vector3.new(0.2, 0.2, 0.2), CFrame.new(DOOR.X + 2, DOOR.Y + 7, DOOR.Z), Color3.new(1, 1, 1), 1)
local out = Instance.new("SpotLight")
out.Face = Enum.NormalId.Left -- (-X: out of the door, onto the sidewalk)
out.Angle, out.Range, out.Brightness, out.Shadows = 60, 16, 1.2, false
out.Color = Color3.fromRGB(230, 170, 255)
out.Parent = spill
spill.CFrame = CFrame.new(spill.Position) * CFrame.Angles(0, 0, math.rad(-25)) -- (tilted down a little)
glow.Parent = workspace

while true do
	local closed = DayNightConfig.isFlowing() and not ClubConfig.isNightOpen(DayNightConfig.clockNow())
	sign.Enabled = closed
	-- the glow while open, breathing slowly with the beat of the place
	local on = not closed
	-- (0.5 read as a flat pink board: a faint haze)
	haze.Transparency = if on then 0.82 + 0.06 * math.sin(os.clock() * 2) else 1
	inside.Enabled, out.Enabled = on, on
	if closed then
		local minutes = math.max(1, math.ceil(DayNightConfig.secondsUntil(night.OpenHour) / 60))
		label.Text = string.format("🌙 클럽은 밤에 열려요\n오픈까지 약 %d분", minutes)
	end
	task.wait(1)
end
