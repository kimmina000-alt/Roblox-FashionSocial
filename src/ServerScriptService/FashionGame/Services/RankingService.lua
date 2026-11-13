--!strict
-- Rankings shown on the boards (CLUB_SHOP_PRICING.md §13.4, D-277):
--   support   all-time supporter gifts (R$ amounts shown)
--   spend     all-time Robux spent in this game (names only, no amounts)
--   today     today's (KST) Robux spent → "오늘의 큰손" (names only)
--   playtime  all-time minutes played
--
-- Totals live in OrderedDataStores (all servers share them). Every minute
-- the top 10 of each is read and sent to every client as the FashionGame
-- attribute "Rankings" (JSON). Players in this server count right away (their
-- live totals are merged in), so the boards also work in Studio, where data
-- stores are off. A player can hide their name ("순위에 내 이름 숨기기",
-- saved in the RankPrefs data store).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationService = require(script.Parent.MonetizationService)
local AvatarService = require(script.Parent.AvatarService)
local VoteService = require(script.Parent.VoteService)

local RankingService = {}

-- (user 2026-10-30) the park boards are 레벨 순위표 (XP) and 기부 순위표
-- (supporter gifts), top 50 each; 큰손 and play time are no longer shown
-- (still counted: play time gates voting)
local TOP = 100 -- (50 until D-1376, user 2026-11-13: "순위표 100명까지 표기")
local REFRESH_SECONDS = 60
local PLAY_FLUSH_MINUTES = 5

type Board = "support" | "spend" | "today" | "playtime" | "level"
local BOARDS: {Board} = { "support", "spend", "today", "playtime", "level" }
local PUBLISHED: {Board} = { "support", "today", "level" }

local function kstDay(): string
	return os.date("!%Y%m%d", os.time() + 9 * 3600) :: string
end

local function storeName(board: Board): string
	if board == "support" then return "RankSupport" end
	if board == "spend" then return "RankSpend" end
	if board == "today" then return "RankSpend_" .. kstDay() end
	if board == "level" then return "RankXP" end
	return "RankPlayMinutes"
end

local function ordered(board: Board): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName(board))
	end)
	return if ok then store else nil
end

local prefs: DataStore? = nil
do
	local ok, store = pcall(function() return DataStoreService:GetDataStore("RankPrefs") end)
	if ok then prefs = store end
end
-- Outfit snapshots of buyers (the "오늘의 큰손" screen on OH24 shows the top 3
-- avatars, D-280): taken at each purchase. (Until D-708 they were refreshed
-- from the live avatar while the player was online; user 2026-11-01: the look
-- from the moment they got onto the board, not the live one.)
local lookStore: DataStore? = nil
do
	local ok, store = pcall(function() return DataStoreService:GetDataStore("RankLooks") end)
	if ok then lookStore = store end
end
local looks: {[number]: any} = {}

local saveLook: (player: Player) -> ()

-- The saved look; someone on a board with none saved yet (the level board
-- needs no purchase) is snapped once, now, and keeps that look.
local function lookOf(userId: number): any
	if looks[userId] == nil and lookStore then
		local ok, value = pcall(function() return (lookStore :: DataStore):GetAsync("look_" .. userId) end)
		looks[userId] = if ok and value ~= nil then value else false
	end
	if not looks[userId] then
		local player = Players:GetPlayerByUserId(userId)
		if player then saveLook(player) end
	end
	return if looks[userId] then looks[userId] else nil
end

saveLook = function(player: Player)
	local ok, snapshot = AvatarService.CaptureSnapshot(player)
	if not ok then return end
	looks[player.UserId] = snapshot
	if lookStore then
		task.spawn(function()
			pcall(function() (lookStore :: DataStore):SetAsync("look_" .. player.UserId, snapshot) end)
		end)
	end
end

-- live totals of players seen in this server: board → userId → value
local live: {[string]: {[number]: number}} = { support = {}, spend = {}, today = {}, playtime = {}, level = {} }
local liveDay = kstDay()
local names: {[number]: string} = {}
local hidden: {[number]: boolean} = {}
-- (D-836, user) left off every board, matched by account name or nickname
-- (lower case); their account ids are looked up once at start
-- (D-1098, user 2026-11-09: "kr_ohu, arallll 이 둘만 감추고 다른 사람들은 보여 줘.
-- 이 둘은 물음표로도 두지 말고") arallll added (arrrrall was a misspelling, kept);
-- their account ids written down too, so a failed name look-up can never show
-- them as a "?" row
-- (D-1376, user 2026-11-13: "순위표에서 Vantablack_Dev 삭제") the game's own account too
local EXCLUDED_NAMES = { kr_ohu = true, arallll = true, arrrrall = true, vantablack_dev = true }
local excluded: {[number]: boolean} = { [11886390086] = true, [438214973] = true, [11931560912] = true, [11887382096] = true }
task.spawn(function()
	for name in pairs(EXCLUDED_NAMES) do
		local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
		if ok and typeof(id) == "number" then excluded[id] = true end
	end
end)
local pendingMinutes: {[number]: number} = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then return cached end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	-- (D-797, user: nicknames, not ids) players not in this server: their display name
	local ok, infos = pcall(function() return UserService:GetUserInfosByUserIdsAsync({ userId }) end)
	local info = if ok and typeof(infos) == "table" then infos[1] else nil
	if info and typeof(info.DisplayName) == "string" and info.DisplayName ~= "" then
		names[userId] = info.DisplayName
	else
		local ok2, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		names[userId] = if ok2 and typeof(name) == "string" then name else "?"
	end
	return names[userId]
end

local function add(board: Board, userId: number, amount: number)
	if board == "today" and liveDay ~= kstDay() then
		live.today = {}
		liveDay = kstDay()
	end
	live[board][userId] = (live[board][userId] or 0) + amount
	if board == "playtime" then
		-- (minutes are written in batches: PLAY_FLUSH_MINUTES)
		pendingMinutes[userId] = (pendingMinutes[userId] or 0) + amount
		if pendingMinutes[userId] < PLAY_FLUSH_MINUTES then return end
		amount = pendingMinutes[userId]
		pendingMinutes[userId] = 0
	end
	local store = ordered(board)
	if not store or userId <= 0 or excluded[userId] then return end -- (D-1086: no Studio test players; D-1098: nor the hidden accounts)
	task.spawn(function()
		local ok, total = pcall(function()
			return (store :: OrderedDataStore):IncrementAsync(tostring(userId), math.floor(amount))
		end)
		-- keep the live value at least the stored total
		if ok and typeof(total) == "number" and board ~= "playtime" then
			live[board][userId] = math.max(live[board][userId] or 0, total)
		end
	end)
end

-- Loads a joining player's stored totals so the live merge is complete.
local function loadTotals(player: Player)
	names[player.UserId] = player.DisplayName
	for _, board in ipairs(BOARDS) do
		local store = ordered(board)
		if store then
			local ok, value = pcall(function()
				return (store :: OrderedDataStore):GetAsync(tostring(player.UserId))
			end)
			if ok and typeof(value) == "number" then
				live[board][player.UserId] = math.max(live[board][player.UserId] or 0, value)
			end
		end
	end
	if prefs then
		local ok, value = pcall(function()
			return (prefs :: DataStore):GetAsync("hide_" .. player.UserId)
		end)
		if ok and value == true then hidden[player.UserId] = true end
	end
	player:SetAttribute("RankHidden", hidden[player.UserId] == true)
end

local function top(board: Board): {{ name: string, value: number, id: number }}
	local merged: {[number]: number} = {}
	local store = ordered(board)
	if store then
		-- (D-1376) a page holds at most 100: the next page too, so the hidden accounts
		-- left out still leave 100 rows
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, 100)
		end)
		if ok and pages then
			for _, entry in ipairs((pages :: DataStorePages):GetCurrentPage()) do
				local id = tonumber(entry.key)
				if id then merged[id] = entry.value end
			end
			if not (pages :: DataStorePages).IsFinished then
				local more = pcall(function() (pages :: DataStorePages):AdvanceToNextPageAsync() end)
				if more then
					for _, entry in ipairs((pages :: DataStorePages):GetCurrentPage()) do
						local id = tonumber(entry.key)
						if id then merged[id] = entry.value end
					end
				end
			end
		end
	end
	for id, value in pairs(live[board]) do
		merged[id] = math.max(merged[id] or 0, value)
	end
	local list = {}
	for id, value in pairs(merged) do
		-- (D-1086, user 2026-11-09: "물음표는 뭐야?") the two "?" rows were the
		-- Studio test players (UserId -1 / -2, no name to look up), saved to the
		-- shared store by 2-player tests: never a real player, left out
		if value > 0 and id > 0 and not hidden[id] then table.insert(list, { id = id, value = value }) end
	end
	table.sort(list, function(a, b) return a.value > b.value end)
	local out = {}
	for _, row in ipairs(list) do
		if #out >= TOP then break end
		local name = nameOf(row.id)
		if not excluded[row.id] and not EXCLUDED_NAMES[string.lower(name)] then
			table.insert(out, { name = name, value = row.value, id = row.id })
		end
	end
	return out
end

-- looks on the "오늘의 큰손" cards right now (userId → outfit), for votes
local todayLooks: {[number]: any} = {}

-- Live supporters (user 2026-10-25, D-294): the screen on the tower over OH24
-- shows the latest supporter gifts, newest first, shared by all servers.
local RECENT_MAX = 6
-- (D-1067, user 2026-11-09: "건물 전광판에 지금 뜨는 테스트로 한 기부자 지우고 광고
-- 이미지만 띄워. 이후에 기부자 생기면 기부자 띄워.") the three gifts on the list were
-- the owner's Studio tests (2026-11-01 / 11-04): gifts before this time are not
-- shown (2026-11-05 00:00 KST, after the last test), and a gift made in Studio is never saved for
-- the live servers
local RECENT_FROM = 1793804400
local recentStore: DataStore? = nil
do
	local ok, store = pcall(function() return DataStoreService:GetDataStore("RecentSupport") end)
	if ok then recentStore = store end
end
local recent: {{ u: number, n: string, a: number, m: string, at: number }} = {}
local recentLooks: {[number]: any} = {}

local function readRecent()
	if not recentStore then return end
	local ok, value = pcall(function() return (recentStore :: DataStore):GetAsync("list") end)
	if ok and typeof(value) == "table" then recent = value end
end

-- XP is a total, not a sum of gifts (EconomyService keeps it on the player
-- attribute "XP"): the board keeps the latest value and saves it now and then
local function saveLevel(player: Player)
	local xp = player:GetAttribute("XP")
	if typeof(xp) ~= "number" or xp <= 0 or player.UserId <= 0 or excluded[player.UserId] then return end -- (D-1086, D-1098)
	local store = ordered("level")
	if not store then return end
	task.spawn(function()
		pcall(function() (store :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(xp)) end)
	end)
end
local function noteLevel(player: Player)
	local xp = player:GetAttribute("XP")
	if typeof(xp) == "number" then live.level[player.UserId] = math.floor(xp) end
end

local function publish()
	local data = {}
	for _, board in ipairs(PUBLISHED) do
		data[board] = top(board)
	end
	-- amounts are not shown for today's spending
	for _, row in ipairs(data.today) do row.value = nil :: any end
	-- the boards show each player's avatar picture
	for _, board in ipairs({ "support", "level" }) do
		for _, row in ipairs(data[board]) do row.u = row.id end
		-- the 1st place stands on the left of the board in their look (user 2026-10-30)
		local first = data[board][1]
		if first and not hidden[first.id] then first.o = lookOf(first.id) end
	end
	-- today's top 3 also carry their look for the avatar screen, and their
	-- 좋아요 / 싫어요 (a hidden card shows the name only, D-281)
	todayLooks = {}
	for i, row in ipairs(data.today) do
		if i <= 3 then
			row.u = row.id
			row.o = lookOf(row.id)
			todayLooks[row.id] = row.o
			local votes = VoteService.State("today", kstDay() .. ":" .. row.id, VoteService.Version(row.o))
			row.likes, row.dislikes, row.hidden = votes.likes, votes.dislikes, votes.hidden
			if votes.hidden then row.o = nil end
		end
	end
	for _, board in ipairs(PUBLISHED) do
		for _, row in ipairs(data[board]) do row.id = nil :: any end
	end
	-- live supporters with their look and 좋아요 / 싫어요
	data.recent = {}
	recentLooks = {}
	for _, entry in ipairs(recent) do
		-- (D-1119, user 2026-11-09: "건물 전광판에 내 캐릭터 뜨는 거 지우고 광고용 이미지만
		-- 띄워 이후 후원자는 기존 기획대로 띄워") the game owner's own gifts (tests on
		-- the live game, 2026-11-05) are never on the screen: with no other gifts it
		-- shows the ads only
		if (entry.at or 0) >= RECENT_FROM and entry.u ~= game.CreatorId and not hidden[entry.u] and not excluded[entry.u] and not EXCLUDED_NAMES[string.lower(tostring(entry.n))] then
			local look = lookOf(entry.u)
			recentLooks[entry.u] = look
			local votes = VoteService.State("supporter", tostring(entry.u), VoteService.Version(look))
			table.insert(data.recent, { u = entry.u, name = entry.n, amount = entry.a, message = entry.m,
				o = if votes.hidden then nil else look, likes = votes.likes, dislikes = votes.dislikes, hidden = votes.hidden })
		end
	end
	FashionGame:SetAttribute("Rankings", HttpService:JSONEncode(data))
end

-- (D-1097) the owner in 관전 mode: off the boards for now (not saved)
local spectating: {[number]: boolean} = {}
function RankingService.SetSpectating(player: Player, on: boolean)
	spectating[player.UserId] = if on then true else nil
	if on then hidden[player.UserId] = true
	elseif player:GetAttribute("RankHidden") ~= true then hidden[player.UserId] = nil end
	task.spawn(publish)
end

function RankingService.SetHidden(player: Player, hide: boolean)
	hidden[player.UserId] = hide or nil
	player:SetAttribute("RankHidden", hide)
	if prefs then
		task.spawn(function()
			pcall(function() (prefs :: DataStore):SetAsync("hide_" .. player.UserId, hide) end)
		end)
	end
	task.spawn(publish)
end

-- This player's vote on a live supporter card (userId).
function RankingService.MyVote(player: Player, userId: any): string?
	if typeof(userId) ~= "number" or recentLooks[userId] == nil then return nil end
	return VoteService.MyVote(player, "supporter", tostring(userId), VoteService.Version(recentLooks[userId]))
end

-- A supporter gift (SparkleService): newest first on the live screen.
function RankingService.NoteSupport(player: Player, amount: number, message: string)
	saveLook(player)
	local entry = { u = player.UserId, n = player.DisplayName, a = amount, m = message, at = os.time() }
	local function push(list: any): any
		list = if typeof(list) == "table" then list else {}
		table.insert(list, 1, entry)
		while #list > RECENT_MAX do table.remove(list) end
		return list
	end
	recent = push(recent)
	task.spawn(function()
		if recentStore and not game:GetService("RunService"):IsStudio() then
			local ok, result = pcall(function()
				return (recentStore :: DataStore):UpdateAsync("list", function(old) return push(old) end)
			end)
			if ok and typeof(result) == "table" then recent = result end
		end
		publish()
	end)
end

function RankingService.Start()
	VoteService.Register("today", function(id)
		local day, user = string.match(id, "^(%d+):(%-?%d+)$") -- (Studio test players have negative ids)
		local userId = tonumber(user)
		if day ~= kstDay() or not userId or todayLooks[userId] == nil then return nil, nil end
		return userId, VoteService.Version(todayLooks[userId])
	end, "👑 싫어요가 많아 오늘의 큰손 전광판에서 내 아바타가 가려지고 이름만 보여요. 코디를 바꾸면 표가 새로 시작돼요.")
	VoteService.Register("supporter", function(id)
		local userId = tonumber(id)
		if not userId or recentLooks[userId] == nil then return nil, nil end
		return userId, VoteService.Version(recentLooks[userId])
	end, "💝 싫어요가 많아 실시간 후원 전광판에서 내 아바타가 가려지고 이름만 보여요. 코디를 바꾸면 표가 새로 시작돼요.")
	VoteService.SetPlayMinutes(function(userId) return live.playtime[userId] or 0 end)
	VoteService.OnChange(function() task.spawn(publish) end)
	MonetizationService.OnPurchase(function(player, key, robux)
		if robux <= 0 then return end
		saveLook(player)
		add("spend", player.UserId, robux)
		add("today", player.UserId, robux)
		if string.sub(key, 1, 8) == "Support_" then add("support", player.UserId, robux) end
		task.defer(publish)
	end)
	Players.PlayerAdded:Connect(loadTotals)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadTotals, player) end
	Players.PlayerRemoving:Connect(function(player)
		saveLevel(player)
		local minutes = pendingMinutes[player.UserId] or 0
		pendingMinutes[player.UserId] = 0
		if minutes > 0 then
			local store = ordered("playtime")
			if store then
				task.spawn(function()
					pcall(function() (store :: OrderedDataStore):IncrementAsync(tostring(player.UserId), minutes) end)
				end)
			end
		end
	end)
	-- play time: one minute per minute online; XP read at the same time and
	-- saved every PLAY_FLUSH_MINUTES
	task.spawn(function()
		local minute = 0
		while true do
			task.wait(60)
			minute += 1
			for _, player in ipairs(Players:GetPlayers()) do
				add("playtime", player.UserId, 1)
				noteLevel(player)
				if minute % PLAY_FLUSH_MINUTES == 0 then saveLevel(player) end
			end
		end
	end)
	-- (the XP shows on the board right away, also in Studio)
	local function watchXP(player: Player)
		noteLevel(player)
		player:GetAttributeChangedSignal("XP"):Connect(function() noteLevel(player) end)
	end
	Players.PlayerAdded:Connect(watchXP)
	for _, player in ipairs(Players:GetPlayers()) do watchXP(player) end
	task.spawn(function()
		while true do
			readRecent()
			publish()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return RankingService
