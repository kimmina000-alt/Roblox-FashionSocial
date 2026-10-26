--!strict
-- Day/night cycle (DayNightController). Lighting.ClockTime keeps flowing:
-- every frame the clock moves on a little, so the sun and moon pass smoothly.
-- The time comes from the server clock, so every player sees the same sky.

local DayNightConfig = {}

DayNightConfig.Enabled = true
-- One full day (24 h) in real seconds on live servers.
DayNightConfig.DayLengthSeconds = 20 * 60
-- Studio play tests: one day = 1 minute, to see sunset/sunrise quickly
-- (user, 2026-10-22). Off since the clock flows for real (2026-10-26): with a
-- 1-minute day the night-only club opened and shut every 30 s in tests.
DayNightConfig.TestInStudio = false
DayNightConfig.TestDayLengthSeconds = 60
-- Clock time at server time 0 (only shifts which hour the cycle starts on).
DayNightConfig.StartClockTime = 14.5
-- While the game was being built the sky stayed at 2 pm (user, 2026-10-23).
-- nil = the day flows (user 2026-10-26); this also turns on the night-only
-- club entry (D-320).
DayNightConfig.FixedClockTime = nil :: number?

local RunService = game:GetService("RunService")

-- Real seconds in one game day here (Studio tests run faster).
function DayNightConfig.dayLength(): number
	return if RunService:IsStudio() and DayNightConfig.TestInStudio
		then DayNightConfig.TestDayLengthSeconds
		else DayNightConfig.DayLengthSeconds
end

-- The game clock (0..24) now, the same on the server and every client.
-- Studio only: ReplicatedStorage.FashionGame attribute ClockOverride (a
-- number) pins it, to test the night-only club entry (D-320).
function DayNightConfig.clockNow(): number
	if RunService:IsStudio() then
		local fg = game:GetService("ReplicatedStorage"):FindFirstChild("FashionGame")
		local o = fg and fg:GetAttribute("ClockOverride")
		if typeof(o) == "number" then return o % 24 end
	end
	if DayNightConfig.FixedClockTime then return DayNightConfig.FixedClockTime end
	local dayFraction = (workspace:GetServerTimeNow() / DayNightConfig.dayLength()) % 1
	return (DayNightConfig.StartClockTime + dayFraction * 24) % 24
end

-- Whether the clock is running (not pinned by FixedClockTime / an override).
function DayNightConfig.isFlowing(): boolean
	if RunService:IsStudio() then
		local fg = game:GetService("ReplicatedStorage"):FindFirstChild("FashionGame")
		if fg and typeof(fg:GetAttribute("ClockOverride")) == "number" then return true end
	end
	return DayNightConfig.FixedClockTime == nil
end

-- Real seconds until the clock reaches `hour` next.
function DayNightConfig.secondsUntil(hour: number): number
	local hours = (hour - DayNightConfig.clockNow()) % 24
	return hours / 24 * DayNightConfig.dayLength()
end

return DayNightConfig
