--!strict
-- Day/night cycle (DayNightConfig): moves Lighting.ClockTime a little every
-- frame so the sun sets in the west over the sea and rises in the east.
-- The clock is derived from the shared server time each frame, so it flows
-- smoothly and stays the same for every player (no drift, no jumps).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNightConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("DayNightConfig"))

if not DayNightConfig.Enabled then return end

RunService.RenderStepped:Connect(function()
	-- a fixed hour while comparing looks (Lighting attribute HoldClockTime,
	-- set by tools/graybox/art_sample_street.lua)
	local hold = Lighting:GetAttribute("HoldClockTime")
	if typeof(hold) == "number" then
		Lighting.ClockTime = hold
		return
	end
	-- (the shared clock: FixedClockTime, the Studio ClockOverride, or the
	-- flowing day; (t / period) % 1 keeps the value small before turning it into hours)
	Lighting.ClockTime = DayNightConfig.clockNow()
end)
