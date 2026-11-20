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
-- 1. Onboarding funnel (new players only, once; D-1524 renumbered it, before 11-16
--    step 2 was 첫 상호작용): 1 접속 → 2 로딩 끝 (the loading screen closed, client
--    "Loaded") → 3 첫 이동 (20 studs from where they appeared) → 4 첫 상호작용 →
--    5 3분 머묾 → 6 10분 머묾. A step reached before the server knows whether the
--    player is new (wallet still loading) is sent once it knows.
--    (D-1524, user 2026-11-16, after the ad of 11-12..15: 829 new players on 11-13,
--    1.08 % back the next day — where do new players leave?)
--    FirstLeave (value = seconds) new players, when leaving the first visit:
--               time (0-30초 / 30초-1분 / 1-3분 / 3-10분 / 10분+) / place /
--               how far (로딩 중 | 가만히 | 걷기만 | the last activity done)
--    LoadSecs   (value = seconds the loading screen was up) New | Back
--    TourEnd    (value = the tour card reached, 1..18) 끝까지 | 건너뜀 / New | Back
--    FirstCard  (value = seconds the first-visit card was up; D-1980) 클럽 | 사진 | 놀이공원 | 닫기 |
--               다른 창 / 낮 | 밤 / New | Back. The card holds three places (FirstCardController);
--               the tour starts only from the guide NPC since then.
-- 2. Custom events (field 1 / 2 / 3):
--    PlaceEnter        place / New|Back / Solo|Friends        each entry (not within 60 s of the last one there)
--    Interact          activity / place / New·Solo ...        doing something (dance, eat, photo ...), once per
--                                                             activity and place per 5 minutes
--    FirstAction       action / order 1..6 / time bucket      new players: the first 6 different first things done
--    FirstInteractSecs (value = seconds)                      new players: join → first interaction
--    FirstSession      3분 | 10분 / spawn spot                 new players: stayed that long in the first visit
--                                                             (field 2 since D-1982: SpawnSpot, "-" before)
--    SpawnAt           spawn spot / 낮 | 밤 / New | Back      (D-1982) where the player appeared on joining
--                                                             (SpawnService: beach, park, photo, club, friend)
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
	-- (D-1125) photos: the last save (time, booth session), whether that run was opened again
	lastSaveAt: number?, lastBooth: string?, recheckedBooth: string?, lastAlbum: number,
	-- (D-1524) onboarding steps reached (sent once `newKnown`), first leave
	newKnown: boolean, reached: {[number]: string}, loaded: boolean, moved: boolean,
	spawnAt: Vector3?, lastAction: string?, tourEnded: boolean, cardEnded: boolean,
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

local function sendOnboarding(player: Player, step: number, stepName: string)
	log("Onboarding", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end, string.format("#%d %s (%s)", step, stepName, player.Name))
end

-- (D-1524) each step once; held until the server knows whether the player is new
local function onboarding(player: Player, step: number, stepName: string)
	local s = states[player]
	if not s or s.reached[step] then return end
	s.reached[step] = stepName
	if s.newKnown and s.new then sendOnboarding(player, step, stepName) end
end

local function leaveBucket(seconds: number): string
	if seconds < 30 then return "0-30초" end
	if seconds < 60 then return "30초-1분" end
	return bucket(seconds)
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
	s.lastAction = activity -- (D-1524: FirstLeave's "how far")
	if not s.interacted then
		s.interacted = true
		player:SetAttribute("Interacted", true) -- (D-1981: the opening attendance window waits for it)
		onboarding(player, 4, "첫 상호작용") -- (D-1524: was step 2)
		if s.new then
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

-- photos (D-1125, user 2026-11-10: "빠진 사진 지표 지금 넣어" — GROWTH_DIRECTION.md §1)
-- PhotoSaved   every save (not throttled): people in the photo (1명 / 2명 / 3-4명)
--              / a Roblox friend in it (Friends | Solo) / New | Back
--              → photos per player, share of group / friend photos
-- PhotoBooth funnel step 5 "다시 확인": the album opened after that save
-- AlbumOpen    the album opened: 저장 후 (a photo saved this visit) | 저장 전 / New | Back
-- AfterPhotoMins (value = minutes) when leaving after a save: how long they
--              stayed after their last photo
function Analytics.photoSaved(player: Player, boothSession: string, people: {number})
	local s = states[player]
	if not s then return end
	local n = math.max(1, #people)
	local mine = friends[player.UserId] or {}
	local withFriend = false
	for _, userId in ipairs(people) do
		if userId ~= player.UserId and mine[userId] then withFriend = true end
	end
	s.lastSaveAt = os.clock()
	s.lastBooth = boothSession
	custom(player, "PhotoSaved", 1, fields(if n == 1 then "1명" elseif n == 2 then "2명" else "3-4명",
		if withFriend then "Friends" else "Solo", visitor(player)))
end

function Analytics.albumOpen(player: Player)
	local s = states[player]
	if not s then return end
	local now = os.clock()
	-- the album's "다시 확인" for the last booth run, once
	if s.lastBooth and s.recheckedBooth ~= s.lastBooth then
		s.recheckedBooth = s.lastBooth
		Analytics.funnel(player, "PhotoBooth", s.lastBooth, 5, "다시 확인")
	end
	if now - s.lastAlbum < 60 then return end
	s.lastAlbum = now
	custom(player, "AlbumOpen", 1, fields(if s.lastSaveAt then "저장 후" else "저장 전", visitor(player)))
end

local function afterPhoto(player: Player)
	local s = states[player]
	if not s or not s.lastSaveAt then return end
	custom(player, "AfterPhotoMins", math.floor((os.clock() - s.lastSaveAt) / 60), fields(visitor(player)))
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
		lastSaveAt = nil, lastBooth = nil, recheckedBooth = nil, lastAlbum = -math.huge,
		newKnown = false, reached = {}, loaded = false, moved = false,
		spawnAt = nil, lastAction = nil, tourEnded = false, cardEnded = false,
	}
	states[player] = s
	onboarding(player, 1, "접속")
	task.spawn(function()
		local waited = 0
		while player.Parent and player:GetAttribute("FirstVisit") == nil and waited < 30 do
			task.wait(0.5)
			waited += 0.5
		end
		if states[player] ~= s or player:GetAttribute("FirstVisit") == nil then return end
		s.new = player:GetAttribute("FirstVisit") == true
		s.newKnown = true
		-- (D-1524) the steps reached while the wallet was loading, in order
		if s.new then
			for step = 1, 6 do
				local name = s.reached[step]
				if name then sendOnboarding(player, step, name) end
			end
		end
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
	-- (D-1982) the join spawn spot (SpawnService): the first move counts from there, and SpawnAt once
	-- New | Back is known (30 s, as LoadSecs)
	player:GetAttributeChangedSignal("SpawnSpot"):Connect(function()
		local st = states[player]
		if not st then return end
		if not st.moved then st.spawnAt = nil end
		local spot = player:GetAttribute("SpawnSpot")
		local night = player:GetAttribute("SpawnNight") == true
		task.delay(30, function()
			if states[player] == st and typeof(spot) == "string" then
				custom(player, "SpawnAt", 1, fields(spot, if night then "밤" else "낮", visitor(player)))
			end
		end)
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
		-- (D-1524) where and when a new player left the first visit
		local s = states[player]
		if s and s.newKnown and s.new then
			local secs = os.clock() - s.joined
			local stage = if not s.loaded then "로딩 중"
				elseif s.interacted and s.lastAction then s.lastAction
				elseif s.moved then "걷기만"
				else "가만히"
			custom(player, "FirstLeave", math.floor(secs + 0.5), fields(leaveBucket(secs), s.place or "거리", stage))
		end
		flushPlaytime(player)
		afterPhoto(player) -- (D-1125)
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
	(gate :: RemoteEvent).OnServerEvent:Connect(function(player, step, arg)
		local s = states[player]
		-- (D-1524) once per visit each, not behind the 1 s gate
		if step == "Loaded" then
			if not s or s.loaded then return end
			s.loaded = true
			onboarding(player, 2, "로딩 끝")
			local secs = if typeof(arg) == "number" and arg == arg then math.clamp(math.floor(arg + 0.5), 0, 600) else 0
			task.delay(30, function() -- (New | Back is known by then)
				if states[player] == s then custom(player, "LoadSecs", secs, fields(visitor(player))) end
			end)
			return
		elseif step == "FirstCard" then -- (D-1980) the first-visit card: which place, or closed
			if not s or s.cardEnded or typeof(arg) ~= "table" then return end
			s.cardEnded = true
			local CHOICES = { ["클럽"] = true, ["사진"] = true, ["놀이공원"] = true, ["닫기"] = true, ["다른 창"] = true }
			local choice = if typeof(arg.choice) == "string" and CHOICES[arg.choice] then arg.choice else "닫기"
			local secs = if typeof(arg.secs) == "number" and arg.secs == arg.secs then math.clamp(math.floor(arg.secs + 0.5), 0, 600) else 0
			custom(player, "FirstCard", secs, fields(choice, if arg.night == true then "밤" else "낮", visitor(player)))
			return
		elseif step == "TourSkip" or step == "TourDone" then
			if not s or s.tourEnded then return end
			s.tourEnded = true
			local card = if typeof(arg) == "number" and arg == arg then math.clamp(math.floor(arg), 1, 30) else 1
			custom(player, "TourEnd", card, fields(if step == "TourDone" then "끝까지" else "건너뜀", visitor(player)))
			return
		end
		local now = os.clock()
		if lastStep[player] and now - lastStep[player] < 1 then return end
		lastStep[player] = now
		if step == "ClubShopOpen" then Analytics.clubShop(player, 1)
		elseif step == "ClubShopPick" then Analytics.clubShop(player, 2)
		elseif step == "AlbumOpen" then Analytics.albumOpen(player) end -- (D-1125)
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
				-- (D-1524) first move: 20 studs from where the character first stood
				if not s.moved then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						if not s.spawnAt then
							s.spawnAt = root.Position
						elseif (root.Position - (s.spawnAt :: Vector3)).Magnitude > 20 then
							s.moved = true
							player:SetAttribute("Moved", true) -- (D-1981)
							onboarding(player, 3, "첫 이동")
						end
					end
				end
				if s.new then
					local stayed = now - s.joined
					if not s.dwell3 and stayed >= 180 then
						s.dwell3 = true
						custom(player, "FirstSession", 1, fields("3분", player:GetAttribute("SpawnSpot") or "-"))
						onboarding(player, 5, "3분 머묾")
					end
					if not s.dwell10 and stayed >= 600 then
						s.dwell10 = true
						custom(player, "FirstSession", 1, fields("10분", player:GetAttribute("SpawnSpot") or "-"))
						onboarding(player, 6, "10분 머묾")
					end
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
