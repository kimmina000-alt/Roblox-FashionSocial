--!strict
-- Roblox analytics for OHU (D-1124, user 2026-11-10: the instrument-analytics
-- plan, reviewed: "자유로운 소셜 활동을 순차적인 온보딩 퍼널에 억지로 넣지 않기 /
-- 반복 퍼널에 촬영·구매 세션 ID 적용하기 / 장소 입장과 실제 활동을 구분해서 기록하기").
-- Every AnalyticsService call of the game goes through here (ZoneMinute stays in
-- ZoneAnalyticsService). Server only; Studio play tests are not recorded by
-- Roblox, so in Studio each event is printed instead ("[Analytics] ...").
-- A failed analytics call never changes the game (every call in a pcall).
--
-- Who: "New" on the player's first visit (EconomyService sets the player
-- attribute FirstVisit), else "Back". With a friend: a Roblox friend in this
-- server within 40 studs ("Friends"), else "Solo".
--
-- 1. Onboarding funnel (new players only, once): 1 접속 → 2 첫 상호작용.
-- 2. Custom events (field 1 / 2 / 3):
--    PlaceEnter        place / New|Back / Solo|Friends        each entry (not within 60 s of the last one there)
--    Interact          activity / place / New·Solo ...        doing something (dance, eat, photo ...), once per
--                                                             activity and place per 5 minutes
--    FirstAction       action / order 1..6 / time bucket      new players: the first 6 different first things done
--    FirstInteractSecs (value = seconds)                      new players: join → first interaction
--    FirstSession      3분 | 10분                              new players: stayed that long in the first visit
-- 3. Recurring funnels (a session id per run):
--    PhotoBooth  1 부스 입장 → 2 촬영 시작 → 3 컷·프레임 고름 → 4 저장   (PhotoBoothService, its session id)
--    ClubVisit   1 입장 → 2 첫 춤                                     (each entry into the club)
--    ClubShop    1 메뉴 열기 → 2 상품 선택 → 3 구매 성공               (each time the drink menu opens; 1 and 2
--                                                                    come from the client, AnalyticsStep)
-- 4. Economy, currency "Coins": Source TimedReward (time online, sent per 5
--    minutes, the rest when leaving) / Onboarding (opening gift) / Gameplay
--    (cafe job, feedback reward, bonuses) / Refund; Sink Shop with an item code
--    (Snack_<shop>_<item>, Drink_<key>, Frame_<key>, Cafe_<item>, Photo_ExtraCopy).
--    Logged after the coins really moved, with the balance after.
-- Budget: 3 funnels + onboarding (cap 10), 1 currency (cap 10), 5 new event
-- names + ZoneMinute (cap 100), 3 fields at most, small value sets only.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Analytics = {}

local STUDIO = RunService:IsStudio()
local F1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local F2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local F3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local COINS = "Coins"
local FRIEND_RANGE = 40
local INTERACT_EVERY = 300
local PLAYTIME_EVERY = 300
local FIRST_ACTIONS = 6

local zoneOf: (Player) -> string? = function() return nil end

local function fields(a: string?, b: string?, c: string?): {[string]: string}?
	if not a then return nil end
	local t = { [F1] = a }
	if b then t[F2] = b end
	if c then t[F3] = c end
	return t
end

local function log(kind: string, fn: () -> (), text: string)
	if STUDIO then
		print("[Analytics] " .. kind .. " " .. text)
		return
	end
	local ok, err = pcall(fn)
	if not ok then warn("[Analytics] " .. kind .. " failed: " .. tostring(err)) end
end

-- who ----------------------------------------------------------------------

type State = {
	joined: number, new: boolean, interacted: boolean, firstActions: {[string]: boolean}, firstCount: number,
	lastInteract: {[string]: number}, place: string?, placeSince: number, lastEnter: {[string]: number},
	clubSession: string?, clubDanced: boolean, clubVisits: number,
	shopSession: string?, shopStep: number, shopOpens: number,
	playtime: number, dwell3: boolean, dwell10: boolean,
}
local states: {[Player]: State} = {}
local friends: {[number]: {[number]: boolean}} = {}

local function stateOf(player: Player): State?
	return states[player]
end

local function visitor(player: Player): string
	local s = states[player]
	return if s and s.new then "New" else "Back"
end

local function company(player: Player): string
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mine = friends[player.UserId]
	if not root or not mine then return "Solo" end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and mine[other.UserId] then
			local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and (r.Position - root.Position).Magnitude <= FRIEND_RANGE then return "Friends" end
		end
	end
	return "Solo"
end

local function bucket(seconds: number): string
	if seconds < 60 then return "0-1분" end
	if seconds < 180 then return "1-3분" end
	if seconds < 600 then return "3-10분" end
	return "10분+"
end

-- funnels --------------------------------------------------------------------

function Analytics.funnel(player: Player, name: string, sessionId: string, step: number, stepName: string)
	if not player.Parent then return end
	log("Funnel", function()
		AnalyticsService:LogFunnelStepEvent(player, name, sessionId, step, stepName)
	end, string.format("%s %s #%d %s (%s)", name, sessionId, step, stepName, player.Name))
end

local function onboarding(player: Player, step: number, stepName: string)
	local s = states[player]
	if not s or not s.new then return end
	log("Onboarding", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end, string.format("#%d %s (%s)", step, stepName, player.Name))
end

local function custom(player: Player, name: string, value: number?, f: {[string]: string}?)
	log("Custom", function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, f)
	end, string.format("%s %s %s", name, tostring(value or 1),
		if f then (f[F1] or "") .. " / " .. (f[F2] or "") .. " / " .. (f[F3] or "") else ""))
end

-- first things a new player does, in order (any kind of action)
local function firstAction(player: Player, action: string)
	local s = states[player]
	if not s or not s.new or s.firstActions[action] or s.firstCount >= FIRST_ACTIONS then return end
	s.firstActions[action] = true
	s.firstCount += 1
	custom(player, "FirstAction", 1, fields(action, tostring(s.firstCount), bucket(os.clock() - s.joined)))
end

-- something the player DID (not just being somewhere)
function Analytics.interact(player: Player, activity: string)
	local s = states[player]
	if not s or player:GetAttribute("Spectating") then return end
	local place = zoneOf(player) or "거리"
	if not s.interacted then
		s.interacted = true
		if s.new then
			onboarding(player, 2, "첫 상호작용")
			custom(player, "FirstInteractSecs", math.floor(os.clock() - s.joined + 0.5), nil)
		end
	end
	firstAction(player, activity)
	-- the club visit's "first dance"
	if activity == "Dance" and place == "클럽" and s.clubSession and not s.clubDanced then
		s.clubDanced = true
		Analytics.funnel(player, "ClubVisit", s.clubSession, 2, "첫 춤")
	end
	local key = activity .. "|" .. place
	local now = os.clock()
	if s.lastInteract[key] and now - s.lastInteract[key] < INTERACT_EVERY then return end
	s.lastInteract[key] = now
	custom(player, "Interact", 1, fields(activity, place, (if s.new then "New·" else "Back·") .. company(player)))
end

-- the club drink menu: 1 opened (client), 2 a drink picked (client), 3 bought (server)
function Analytics.clubShop(player: Player, step: number)
	local s = states[player]
	if not s then return end
	if step == 1 then
		s.shopOpens += 1
		s.shopSession = string.format("%d-%d-%d", player.UserId, math.floor(s.joined), s.shopOpens)
		s.shopStep = 1
		Analytics.funnel(player, "ClubShop", s.shopSession, 1, "메뉴 열기")
	elseif s.shopSession and step == 2 and s.shopStep < 2 then
		s.shopStep = 2
		Analytics.funnel(player, "ClubShop", s.shopSession, 2, "상품 선택")
	elseif s.shopSession and step == 3 and s.shopStep < 3 then
		s.shopStep = 3
		Analytics.funnel(player, "ClubShop", s.shopSession, 3, "구매 성공")
	end
end

-- economy ----------------------------------------------------------------------

-- coins that really moved (amount > 0), with the balance after
function Analytics.coins(player: Player, flow: string, amount: number, balance: number, transactionType: string, sku: string?)
	if amount <= 0 or not player.Parent then return end
	local flowType = if flow == "Sink" then Enum.AnalyticsEconomyFlowType.Sink else Enum.AnalyticsEconomyFlowType.Source
	log("Economy", function()
		AnalyticsService:LogEconomyEvent(player, flowType, COINS, math.floor(amount), math.floor(balance), transactionType, sku)
	end, string.format("%s %d → %d %s %s (%s)", flow, amount, balance, transactionType, tostring(sku), player.Name))
	if flow == "Sink" then firstAction(player, "Purchase") end
end

-- time-online coins: summed, sent every 5 minutes and when leaving
function Analytics.playtimeCoins(player: Player, amount: number)
	local s = states[player]
	if s then s.playtime += amount end
end
local balanceOf: (Player) -> number = function() return 0 end
local function flushPlaytime(player: Player)
	local s = states[player]
	if not s or s.playtime <= 0 then return end
	local amount = s.playtime
	s.playtime = 0
	Analytics.coins(player, "Source", amount, balanceOf(player), Enum.AnalyticsEconomyTransactionType.TimedReward.Name, "Playtime")
end

-- start ------------------------------------------------------------------------

local function onPlayer(player: Player)
	-- (FirstVisit is set by EconomyService once the wallet has loaded)
	local s: State = {
		joined = os.clock(), new = false, interacted = false, firstActions = {}, firstCount = 0,
		lastInteract = {}, place = nil, placeSince = 0, lastEnter = {},
		clubSession = nil, clubDanced = false, clubVisits = 0,
		shopSession = nil, shopStep = 0, shopOpens = 0,
		playtime = 0, dwell3 = false, dwell10 = false,
	}
	states[player] = s
	task.spawn(function()
		local waited = 0
		while player.Parent and player:GetAttribute("FirstVisit") == nil and waited < 30 do
			task.wait(0.5)
			waited += 0.5
		end
		s.new = player:GetAttribute("FirstVisit") == true
		onboarding(player, 1, "접속")
	end)
	-- friends in this server, both ways
	task.spawn(function()
		friends[player.UserId] = friends[player.UserId] or {}
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local ok, yes = pcall(function() return player:IsFriendsWith(other.UserId) end)
				if ok and yes then
					friends[player.UserId][other.UserId] = true
					friends[other.UserId] = friends[other.UserId] or {}
					friends[other.UserId][player.UserId] = true
				end
			end
		end
	end)
	-- sitting anywhere (benches, stools, chairs) counts as doing something
	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Seated:Connect(function(active)
				if active then Analytics.interact(player, "Sit") end
			end)
		end
	end
	if player.Character then task.spawn(watch, player.Character) end
	player.CharacterAdded:Connect(watch)
end

function Analytics.Start(zoneFn: (Player) -> string?, balanceFn: (Player) -> number)
	zoneOf = zoneFn
	balanceOf = balanceFn
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(player)
		flushPlaytime(player)
		states[player] = nil
		friends[player.UserId] = nil
		for _, list in pairs(friends) do list[player.UserId] = nil end
	end)
	-- the client's steps of the club drink menu (only these two, 1 per second)
	local remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
	local gate = remotes:FindFirstChild("AnalyticsStep")
	if not gate then
		gate = Instance.new("RemoteEvent")
		gate.Name = "AnalyticsStep"
		gate.Parent = remotes
	end
	local lastStep: {[Player]: number} = {}
	(gate :: RemoteEvent).OnServerEvent:Connect(function(player, step)
		local now = os.clock()
		if lastStep[player] and now - lastStep[player] < 1 then return end
		lastStep[player] = now
		if step == "ClubShopOpen" then Analytics.clubShop(player, 1)
		elseif step == "ClubShopPick" then Analytics.clubShop(player, 2) end
	end)
	-- places entered (2 s), first-visit time, time-online coins (5 min)
	task.spawn(function()
		local sincePlaytime = 0
		while true do
			task.wait(2)
			sincePlaytime += 2
			local now = os.clock()
			for player, s in pairs(states) do
				if not player.Parent or player:GetAttribute("Spectating") then continue end
				local place = zoneOf(player)
				if place and place ~= s.place then
					s.place = place
					if place ~= "거리" and (not s.lastEnter[place] or now - s.lastEnter[place] > 60) then
						s.lastEnter[place] = now
						custom(player, "PlaceEnter", 1, fields(place, visitor(player), company(player)))
						firstAction(player, "장소:" .. place)
						if place == "클럽" then
							s.clubVisits += 1
							s.clubSession = string.format("%d-%d-%d", player.UserId, math.floor(s.joined), s.clubVisits)
							s.clubDanced = false
							Analytics.funnel(player, "ClubVisit", s.clubSession, 1, "입장")
						end
					end
				end
				if s.new then
					local stayed = now - s.joined
					if not s.dwell3 and stayed >= 180 then s.dwell3 = true custom(player, "FirstSession", 1, fields("3분")) end
					if not s.dwell10 and stayed >= 600 then s.dwell10 = true custom(player, "FirstSession", 1, fields("10분")) end
				end
			end
			if sincePlaytime >= PLAYTIME_EVERY then
				sincePlaytime = 0
				for player in pairs(states) do flushPlaytime(player) end
			end
		end
	end)
end

Analytics.visitor = visitor
Analytics.stateOf = stateOf

return Analytics
