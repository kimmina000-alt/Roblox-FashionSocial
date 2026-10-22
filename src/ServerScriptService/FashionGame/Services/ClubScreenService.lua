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

-- 30 s per player (user, 2026-10-22). The people in the club are put in a
-- random order; every 30 s the pillars move on to the next person in that
-- order so everyone gets a turn. All pillars show the SAME person (user,
-- 2026-10-22: two pillars showing two different people looked wrong). The
-- order is shuffled again when someone enters or leaves.
local SECONDS_PER_PLAYER = 30
local order: {number} = {}
local offset = 0

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

-- Re-shuffles when the set of people changed. Returns true if it did.
local function refreshOrder(inClub: {Player}): boolean
	local same = #inClub == #order
	if same then
		for _, player in ipairs(inClub) do
			if not table.find(order, player.UserId) then same = false break end
		end
	end
	if same then return false end
	table.clear(order)
	for _, player in ipairs(inClub) do table.insert(order, player.UserId) end
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	offset = 0
	return true
end

function ClubScreenService.Start()
	task.spawn(function()
		local since = os.clock()
		while true do
			local inClub = clubPlayers()
			local changed = refreshOrder(inClub)
			local due = os.clock() - since >= SECONDS_PER_PLAYER
			if changed or due then
				since = os.clock()
				if due and not changed then offset += 1 end
				local target: Player? = nil
				if #order > 0 then
					target = Players:GetPlayerByUserId(order[(offset % #order) + 1])
				end
				for _, model in ipairs(CollectionService:GetTagged("LEDPillar")) do
					if model:IsDescendantOf(workspace) then show(model, target) end
				end
			end
			task.wait(1)
		end
	end)
end
return ClubScreenService
