--!strict
-- Where people spend their time (D-1096, user 2026-11-09: "사람들이 어느 장소에서
-- 많이 머무르는지 알 수 있는 방법" → "둘 다 만들어 줘").
-- Once a minute, for every player in the game, one Roblox analytics custom
-- event "ZoneMinute" (value 1) with the place they are in as custom field 1
-- (클럽, 오후네컷, OH24 편의점, 국밥집, 해변 카페, 해변, 광화문·한옥, 포켓 공원,
-- 놀이공원, 거리). On the Creator Dashboard (애널리틱스 → 커스텀 이벤트, shown
-- once events have come in; a few hours to a day late) the sum per place =
-- player-minutes spent there. Live servers only: Studio tests are not counted
-- by Roblox. The owner watching in 관전 mode (SpectateService) is left out.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

local ZoneAnalyticsService = {}

local EVENT = "ZoneMinute"
local EVERY = 60 -- seconds

-- places by their ground outline (world x / z, studs), first match wins
type Box = { name: string, x0: number, x1: number, z0: number, z1: number }
local BOXES: {Box} = {
	{ name = "오후네컷", x0 = 44, x1 = 182, z0 = -116, z1 = -43 },
	{ name = "OH24 편의점", x0 = -100, x1 = -56, z0 = 55, z1 = 142 },
	{ name = "국밥집", x0 = 40, x1 = 135, z0 = -376, z1 = -292 },
	{ name = "해변 카페", x0 = -376, x1 = -198, z0 = 175, z1 = 377 },
	{ name = "놀이공원", x0 = -156, x1 = -44, z0 = -471, z1 = -305 },
	{ name = "포켓 공원", x0 = -150, x1 = -46, z0 = -229, z1 = -47 },
	{ name = "광화문·한옥", x0 = 60, x1 = 1000, z0 = 100, z1 = 1000 },
}

function ZoneAnalyticsService.ZoneOf(player: Player): string?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local p = root.Position
	if player:GetAttribute("ClubInside") or ClubConfig.isInClub(p) then return "클럽" end
	for _, b in ipairs(BOXES) do
		if p.X >= b.x0 and p.X <= b.x1 and p.Z >= b.z0 and p.Z <= b.z1 then return b.name end
	end
	if p.X < -198 then return "해변" end
	return "거리"
end

function ZoneAnalyticsService.Start()
	task.spawn(function()
		while true do
			task.wait(EVERY)
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("Spectating") then continue end
				local zone = ZoneAnalyticsService.ZoneOf(player)
				if zone and not RunService:IsStudio() then
					pcall(function()
						AnalyticsService:LogCustomEvent(player, EVENT, 1, {
							[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = zone,
						})
					end)
				end
			end
		end
	end)
end

return ZoneAnalyticsService
