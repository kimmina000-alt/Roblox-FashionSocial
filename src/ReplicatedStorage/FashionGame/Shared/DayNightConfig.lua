--!strict
-- Day/night cycle (DayNightController). Lighting.ClockTime keeps flowing:
-- every frame the clock moves on a little, so the sun and moon pass smoothly.
-- The time comes from the server clock, so every player sees the same sky.

local DayNightConfig = {}

DayNightConfig.Enabled = true
-- One full day (24 h) in real seconds on live servers.
DayNightConfig.DayLengthSeconds = 20 * 60
-- Studio play tests: one day = 1 minute, to see sunset/sunrise quickly
-- (user, 2026-10-22). Set TestInStudio = false to check the live speed.
DayNightConfig.TestInStudio = true
DayNightConfig.TestDayLengthSeconds = 60
-- Clock time at server time 0 (only shifts which hour the cycle starts on).
DayNightConfig.StartClockTime = 14.5

return DayNightConfig
