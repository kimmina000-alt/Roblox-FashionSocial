--!strict
-- Round LED pillars at the corners of the club atrium (user, 2026-10-20: huge
-- round LED pillars with player photos turning 360°). Each pillar shows one
-- player who is inside the club, changing every few seconds in a shuffled
-- order so everyone gets a turn. With nobody in the club it shows the club
-- name.
--
-- The server only decides who is shown: Model attributes ShowUserId (0 =
-- idle) and ShowName. ClubLightsController (client) draws the avatar
-- portrait on the Panel parts all around the pillar and turns it slowly.
--
-- Map (tools/graybox, 02_Club): a Model tagged "LEDPillar" with Parts named
-- "Panel" (attribute Slice = 0..N-1 around the pillar) and "NameAnchor".

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

local ClubScreenService = {}

-- 30 s per player, random order (user, 2026-10-22)
local SECONDS_PER_PLAYER = 30
local order: {number} = {}

local function show(model: Instance, target: Player?)
	model:SetAttribute("ShowUserId", if target then target.UserId else 0)
	model:SetAttribute("ShowName", if target then target.DisplayName else "")
end

local function clubPlayers(): {Player}
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and ClubConfig.isInClub(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

-- Next player in a shuffled round, skipping anyone no longer in the club.
local function nextPlayer(inClub: {Player}, avoid: {[number]: boolean}): Player?
	for _ = 1, 2 do
		while #order > 0 do
			local userId = table.remove(order, 1) :: number
			for _, player in ipairs(inClub) do
				if player.UserId == userId and not avoid[userId] then return player end
			end
		end
		-- New round: shuffle everyone currently in the club.
		for _, player in ipairs(inClub) do table.insert(order, player.UserId) end
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
	end
	return nil
end

function ClubScreenService.Start()
	task.spawn(function()
		local since = -math.huge
		while true do
			local inClub = clubPlayers()
			-- Change every SECONDS_PER_PLAYER, or at once when a shown player left
			-- the club or the pillars are idle while someone is inside.
			local stale = false
			for _, model in ipairs(CollectionService:GetTagged("LEDPillar")) do
				local shown = model:GetAttribute("ShowUserId")
				local present = false
				for _, player in ipairs(inClub) do
					if player.UserId == shown then present = true end
				end
				if (shown ~= 0 and shown ~= nil and not present) or ((shown == 0 or shown == nil) and #inClub > 0) then stale = true end
			end
			if stale or os.clock() - since >= SECONDS_PER_PLAYER then
				since = os.clock()
				local used: {[number]: boolean} = {}
				for _, model in ipairs(CollectionService:GetTagged("LEDPillar")) do
					-- Pillars show different people when possible.
					local target = nextPlayer(inClub, used) or inClub[1]
					if target then used[target.UserId] = true end
					show(model, target)
				end
			end
			task.wait(1)
		end
	end)
end

return ClubScreenService
