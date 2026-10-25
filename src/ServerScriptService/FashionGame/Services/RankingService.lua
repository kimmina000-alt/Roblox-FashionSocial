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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationService = require(script.Parent.MonetizationService)

local RankingService = {}

local TOP = 10
local REFRESH_SECONDS = 60
local PLAY_FLUSH_MINUTES = 5

type Board = "support" | "spend" | "today" | "playtime"
local BOARDS: {Board} = { "support", "spend", "today", "playtime" }

local function kstDay(): string
	return os.date("!%Y%m%d", os.time() + 9 * 3600) :: string
end

local function storeName(board: Board): string
	if board == "support" then return "RankSupport" end
	if board == "spend" then return "RankSpend" end
	if board == "today" then return "RankSpend_" .. kstDay() end
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

-- live totals of players seen in this server: board → userId → value
local live: {[string]: {[number]: number}} = { support = {}, spend = {}, today = {}, playtime = {} }
local liveDay = kstDay()
local names: {[number]: string} = {}
local hidden: {[number]: boolean} = {}
local pendingMinutes: {[number]: number} = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then return cached end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = if ok and typeof(name) == "string" then name else "?"
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
	if not store then return end
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

local function top(board: Board): {{ name: string, value: number }}
	local merged: {[number]: number} = {}
	local store = ordered(board)
	if store then
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, TOP + 5)
		end)
		if ok and pages then
			for _, entry in ipairs((pages :: DataStorePages):GetCurrentPage()) do
				local id = tonumber(entry.key)
				if id then merged[id] = entry.value end
			end
		end
	end
	for id, value in pairs(live[board]) do
		merged[id] = math.max(merged[id] or 0, value)
	end
	local list = {}
	for id, value in pairs(merged) do
		if value > 0 and not hidden[id] then table.insert(list, { id = id, value = value }) end
	end
	table.sort(list, function(a, b) return a.value > b.value end)
	local out = {}
	for i = 1, math.min(TOP, #list) do
		table.insert(out, { name = nameOf(list[i].id), value = list[i].value })
	end
	return out
end

local function publish()
	local data = {}
	for _, board in ipairs(BOARDS) do
		data[board] = top(board)
	end
	-- amounts are only shown for support and play time
	for _, board in ipairs({ "spend", "today" }) do
		for _, row in ipairs(data[board]) do row.value = nil :: any end
	end
	FashionGame:SetAttribute("Rankings", HttpService:JSONEncode(data))
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

function RankingService.Start()
	MonetizationService.OnPurchase(function(player, key, robux)
		if robux <= 0 then return end
		add("spend", player.UserId, robux)
		add("today", player.UserId, robux)
		if string.sub(key, 1, 8) == "Support_" then add("support", player.UserId, robux) end
		task.defer(publish)
	end)
	Players.PlayerAdded:Connect(loadTotals)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadTotals, player) end
	Players.PlayerRemoving:Connect(function(player)
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
	-- play time: one minute per minute online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				add("playtime", player.UserId, 1)
			end
		end
	end)
	task.spawn(function()
		while true do
			publish()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return RankingService
