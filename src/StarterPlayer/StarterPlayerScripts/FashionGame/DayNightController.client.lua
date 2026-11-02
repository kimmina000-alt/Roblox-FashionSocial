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

-- (D-783, user: "밤에 바다에 다리 안 보임") the place's Atmosphere hid the lit
-- 광안대교 out at sea after dark: its haze thins at night (the day's own
-- density as set in the place, NIGHT_DENSITY from 20:00 to 05:00, eased over
-- an hour at dusk and dawn)
local NIGHT_DENSITY = 0 -- (0.08, even 0.02, still hid the towers' tops)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local dayDensity = if atmosphere then atmosphere.Density else 0
local function nightness(clock: number): number
	if clock >= 20 or clock < 5 then return 1 end
	if clock >= 19 then return clock - 19 end
	if clock < 6 then return 6 - clock end
	return 0
end

RunService.RenderStepped:Connect(function()
	-- a fixed hour while comparing looks (Lighting attribute HoldClockTime,
	-- set by tools/graybox/art_sample_street.lua)
	local hold = Lighting:GetAttribute("HoldClockTime")
	if typeof(hold) == "number" then
		Lighting.ClockTime = hold
	else
		-- (the shared clock: FixedClockTime, the Studio ClockOverride, or the
		-- flowing day; (t / period) % 1 keeps the value small before turning it into hours)
		Lighting.ClockTime = DayNightConfig.clockNow()
	end
	if atmosphere then
		local k = nightness(Lighting.ClockTime)
		atmosphere.Density = dayDensity + (NIGHT_DENSITY - dayDensity) * k
	end
end)
