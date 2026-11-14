--!strict
-- (D-1366) The opening attendance event (Shared/OpeningEventConfig). Once per event day (KST)
-- the 받기 tap on today's card (D-1401) counts the attendance (wallet.opening.n, the day in
-- wallet.opening.last) and Rewards[n] is given: coins (EconomyService.Gift), the limited
-- photo frame (wallet.frames, like a bought one), the FOUNDING MEMBER title
-- (wallet.opening.title: kept for good, shown on the name tag by NameTagService).
-- Player attributes for the window: OpeningCount (attendances so far), OpeningClaimedDay
-- (the event day the last one was on), OpeningCanClaim (today's 받기 waits: the window opens
-- by itself), OpeningJustClaimed (the attendance counted on this visit), Title_Founding (the
-- title, also after the event).
-- A Studio test never counts (it would use up the real days).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OpeningEventConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("OpeningEventConfig"))

local OpeningEventService = {}

local data: any = nil
local economy: any = nil

-- (D-1401, user 2026-11-14: "출석 이벤트에 받기 완료 < 받기 버튼이었다가 눌러야 받기 완료로 뜨고 출석
-- 인정하는 걸로 수정") A visit no longer counts by itself: today's card shows 받기, and only
-- the tap (remote OpeningEvent "Claim") counts the attendance and gives the reward. Player
-- attribute OpeningCanClaim = true while today's 받기 is waiting.
local function openingOf(wallet: any): any
	local o = wallet.opening
	if typeof(o) ~= "table" then
		o = { n = 0, last = 0, title = false }
		wallet.opening = o
	end
	return o
end

local function canClaim(o: any): boolean
	local day = OpeningEventConfig.dayNow()
	-- (a Studio test never counts: it would use up the real days; attribute OpeningStudioCount
	-- on ReplicatedStorage.FashionGame lets one through)
	local studio = RunService:IsStudio() and not ReplicatedStorage.FashionGame:GetAttribute("OpeningStudioCount")
	return day ~= nil and o.last ~= day and o.n < OpeningEventConfig.Goal and not studio
end

local function publish(player: Player, o: any)
	player:SetAttribute("OpeningCount", o.n)
	player:SetAttribute("OpeningClaimedDay", o.last)
	player:SetAttribute("OpeningCanClaim", if canClaim(o) then true else nil)
	player:SetAttribute("Title_Founding", if o.title then true else nil)
end

local function refresh(player: Player)
	local wallet = data.Wallet(player) -- (waits for the player's data)
	if not player.Parent then return end
	publish(player, openingOf(wallet))
end

local function claim(player: Player): (boolean, string?)
	local wallet = data.Wallet(player)
	if not player.Parent then return false, nil end
	local o = openingOf(wallet)
	if not canClaim(o) then
		publish(player, o)
		return false, "오늘은 이미 받았어요."
	end
	o.n += 1
	o.last = OpeningEventConfig.dayNow()
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
	publish(player, o)
	return true, nil
end

function OpeningEventService.Start(playerData: any, economyService: any)
	data = playerData
	economy = economyService
	local remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("OpeningEvent") :: RemoteFunction?
	if not remote then
		local r = Instance.new("RemoteFunction")
		r.Name = "OpeningEvent"
		r.Parent = remotes
		remote = r
	end
	local busy: {[Player]: boolean} = {};
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any)
		if action ~= "Claim" or busy[player] then return false, nil end
		busy[player] = true
		local ok, done, message = pcall(claim, player)
		busy[player] = nil
		if not ok then return false, nil end
		return done, message
	end
	local function onPlayer(player: Player)
		task.spawn(refresh, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player) busy[player] = nil end)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	-- a player who stays past midnight: the next day's 받기 shows too (checked every minute)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do task.spawn(refresh, player) end
		end
	end)
end

return OpeningEventService
