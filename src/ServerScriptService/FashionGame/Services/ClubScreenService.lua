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

-- (D-1112, user 2026-11-09: "클럽 dj 뒤 전광판에 dj 없을 때는 춤추고 있는 플레이어
-- 랜덤으로 띄우자. 계속 띄우지 말고 여기는 간헐적으로. 사이에 안 뜰 때도 있음")
-- the big LED wall behind the DJ: with no DJ, now and then one player who is
-- dancing in the club (character attribute DanceKey) is shown on it for a
-- while, then the club visuals again for a longer while; some turns show
-- nobody. ReplicatedStorage.FashionGame attribute ClubWallShow = their UserId
-- (0 = nobody); DJScreenController draws them like the DJ.
local WALL_GAP = { 25, 60 } -- seconds of visuals between two
local WALL_SHOW = { 12, 18 } -- seconds on the wall
local WALL_SKIP = 0.3 -- a turn that shows nobody
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")

local function hasDJ(): boolean
	local id = FashionGame:GetAttribute("ClubDJ")
	local untilTime = FashionGame:GetAttribute("ClubDJUntil")
	return typeof(id) == "number" and id ~= 0 and typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function dancers(): {Player}
	local list = {}
	for _, player in ipairs(clubPlayers()) do
		local character = player.Character
		if character and character:GetAttribute("DanceKey") ~= nil then table.insert(list, player) end
	end
	return list
end

local function wallLoop()
	local last = 0
	FashionGame:SetAttribute("ClubWallShow", 0)
	while true do
		task.wait(math.random(WALL_GAP[1], WALL_GAP[2]))
		local list = dancers()
		if not hasDJ() and #list > 0 and math.random() >= WALL_SKIP then
			-- not the same one twice in a row when there is a choice
			if #list > 1 then
				for i, p in ipairs(list) do
					if p.UserId == last then table.remove(list, i) break end
				end
			end
			local pick = list[math.random(1, #list)]
			last = pick.UserId
			FashionGame:SetAttribute("ClubWallShow", pick.UserId)
			local stop = os.clock() + math.random(WALL_SHOW[1], WALL_SHOW[2])
			-- off early when they leave the club or a DJ starts
			while os.clock() < stop do
				task.wait(1)
				local root = pick.Character and pick.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not pick.Parent or not root or not ClubConfig.isInClub(root.Position) or hasDJ() then break end
			end
			FashionGame:SetAttribute("ClubWallShow", 0)
		end
	end
end

function ClubScreenService.Start()
	-- (D-1369, user 2026-11-13: "dj 전광판에 플레이어 뜨는 것 삭제. dj만 뜨게") the LED wall
	-- behind the DJ no longer shows dancers by turns: only the DJ (DJScreenController)
	FashionGame:SetAttribute("ClubWallShow", 0)
	local _ = wallLoop
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
