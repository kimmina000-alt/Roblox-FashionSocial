--!strict
-- (D-1366) The opening attendance event (Shared/OpeningEventConfig). On a player's first
-- visit of an event day (KST) the attendance counts once (wallet.opening.n, the day in
-- wallet.opening.last) and Rewards[n] is given: coins (EconomyService.Gift), the limited
-- photo frame (wallet.frames, like a bought one), the FOUNDING MEMBER title
-- (wallet.opening.title: kept for good, shown on the name tag by NameTagService).
-- Player attributes for the window: OpeningCount (attendances so far), OpeningClaimedDay
-- (the event day the last one was on), OpeningJustClaimed (set when one was counted on this
-- visit: the window opens by itself), Title_Founding (the title, also after the event).
-- A Studio test never counts (it would use up the real days).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OpeningEventConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("OpeningEventConfig"))

local OpeningEventService = {}

local data: any = nil
local economy: any = nil

local function attend(player: Player)
	local wallet = data.Wallet(player) -- (waits for the player's data)
	if not player.Parent then return end
	local o = wallet.opening
	if typeof(o) ~= "table" then
		o = { n = 0, last = 0, title = false }
		wallet.opening = o
	end
	local day = OpeningEventConfig.dayNow()
	local studio = RunService:IsStudio() and not ReplicatedStorage.FashionGame:GetAttribute("OpeningStudioCount")
	if day and o.last ~= day and o.n < OpeningEventConfig.Goal and not studio then
		o.n += 1
		o.last = day
		local reward = OpeningEventConfig.Rewards[o.n]
		if reward then
			if reward.coins then
				economy.Gift(player, reward.coins, string.format("오픈 출석 %d일차", o.n), "OpeningEvent")
			elseif reward.frame then
				if not table.find(wallet.frames, OpeningEventConfig.FrameKey) then
					table.insert(wallet.frames, OpeningEventConfig.FrameKey)
				end
				economy.Republish(player) -- (OwnedFrames for the photo booth)
			elseif reward.title then
				o.title = true
			end
		end
		data.MarkDirty(player)
		player:SetAttribute("OpeningJustClaimed", o.n)
	end
	player:SetAttribute("OpeningCount", o.n)
	player:SetAttribute("OpeningClaimedDay", o.last)
	player:SetAttribute("Title_Founding", if o.title then true else nil)
end

function OpeningEventService.Start(playerData: any, economyService: any)
	data = playerData
	economy = economyService
	local function onPlayer(player: Player)
		task.spawn(attend, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	-- a player who stays past midnight: the next day counts too (checked every minute)
	task.spawn(function()
		while true do
			task.wait(60)
			local day = OpeningEventConfig.dayNow()
			if day then
				for _, player in ipairs(Players:GetPlayers()) do
					if player:GetAttribute("OpeningClaimedDay") ~= day then task.spawn(attend, player) end
				end
			end
		end
	end)
end

return OpeningEventService
