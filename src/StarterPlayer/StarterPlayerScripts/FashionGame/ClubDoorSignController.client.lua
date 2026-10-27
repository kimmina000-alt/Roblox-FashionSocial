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
label.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
label.BackgroundTransparency = 0.15
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

while true do
	local closed = DayNightConfig.isFlowing() and not ClubConfig.isNightOpen(DayNightConfig.clockNow())
	sign.Enabled = closed
	if closed then
		local minutes = math.max(1, math.ceil(DayNightConfig.secondsUntil(night.OpenHour) / 60))
		label.Text = string.format("🌙 클럽은 밤에 열려요\n오픈까지 약 %d분", minutes)
	end
	task.wait(1)
end
