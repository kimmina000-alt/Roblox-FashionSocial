--!strict
-- 💬 의견 보내기 (D-725, Shared/FeedbackConfig). Remote Feedback (RemoteFunction):
--   "Send", { kind, text }  → true / false, message
--   "List"                  → the newest messages (the game's owner only)
--   "Done", key             → the owner marks one handled (hidden from the list)
--   "Reward", key           → (D-1013) the owner gives the sender FeedbackConfig.RewardCoins,
--                             once per message (value.r); offline senders get them on
--                             their next visit (DataStore "FeedbackRewards_v1", u_<userId>)
-- Each message is one key in the DataStore "Feedback_v1" (u, n, k, t, at,
-- x, z, done); the OrderedDataStore "FeedbackTimes" keeps key → time for the
-- newest-first list. Every message is printed in the server output too.
-- The owner = the user who owns the experience (game.CreatorId), or anyone in
-- Studio. Player attribute FeedbackAdmin = true shows them the 📥 tab.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local FeedbackConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("FeedbackConfig"))
local EconomyService = require(script.Parent.EconomyService)

local FeedbackService = {}

local store: DataStore? = nil
local times: OrderedDataStore? = nil
local pending: DataStore? = nil -- (D-1013) coins waiting for a sender who was offline
pcall(function()
	store = DataStoreService:GetDataStore("Feedback_v1")
	times = DataStoreService:GetOrderedDataStore("FeedbackTimes")
	pending = DataStoreService:GetDataStore("FeedbackRewards_v1")
end)

local lastSent: {[Player]: number} = {}
-- (Studio has no DataStore access here: kept for the session so the window can be tested)
local session: {{ key: string, value: any }} = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function validKind(kind: any): boolean
	for _, k in ipairs(FeedbackConfig.Kinds) do
		if k.key == kind then return true end
	end
	return false
end

local function send(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" or not validKind(payload.kind) or typeof(payload.text) ~= "string" then
		return false, "잘못된 요청이에요."
	end
	local text = string.gsub(payload.text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if #text < 2 then return false, "내용을 적어 주세요." end
	if utf8.len(text) == nil then return false, "잘못된 글자가 있어요." end
	if (utf8.len(text) :: number) > FeedbackConfig.MaxLength then return false, string.format("%d자까지 쓸 수 있어요.", FeedbackConfig.MaxLength) end
	local t = os.clock()
	if lastSent[player] and t - lastSent[player] < FeedbackConfig.CooldownSeconds then
		return false, string.format("%d초 뒤에 다시 보낼 수 있어요.", math.ceil(FeedbackConfig.CooldownSeconds - (t - lastSent[player])))
	end
	lastSent[player] = t
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = os.time()
	local key = string.format("f_%d_%d", at, player.UserId)
	local value = {
		u = player.UserId, n = player.Name, k = payload.kind, t = text, at = at,
		x = if root then math.floor(root.Position.X) else nil,
		z = if root then math.floor(root.Position.Z) else nil,
	}
	print(string.format("[Feedback] %s (%d) %s: %s", player.Name, player.UserId, payload.kind, text))
	local ok = pcall(function()
		(store :: DataStore):SetAsync(key, value, { player.UserId })
		;(times :: OrderedDataStore):SetAsync(key, at)
	end)
	if not ok then
		if RunService:IsStudio() then
			table.insert(session, 1, { key = key, value = value })
		else
			lastSent[player] = nil
			return false, "지금은 보낼 수 없어요. 잠시 뒤에 다시 해 주세요."
		end
	end
	-- (D-769, user: shown for 1 s over the form, Feedback.lua)
	return true, "소중한 의견이 잘 접수되었어요. 고마워요! 💛"
end

-- the owner reads them in the game: filtered for the owner (Roblox text rules)
local function filtered(text: string, from: number, to: Player): string
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, from):GetNonChatStringForUserAsync(to.UserId)
	end)
	return if ok and typeof(result) == "string" then result else "(필터를 거치지 못한 글)"
end

local function list(player: Player): {any}
	if not isAdmin(player) then return {} end
	local out = {}
	for _, entry in ipairs(session) do
		if not entry.value.done then
			table.insert(out, { key = entry.key, n = entry.value.n, k = entry.value.k, at = entry.value.at, t = entry.value.t, x = entry.value.x, z = entry.value.z, r = entry.value.r })
		end
	end
	pcall(function()
		local page = (times :: OrderedDataStore):GetSortedAsync(false, FeedbackConfig.ListSize):GetCurrentPage()
		for _, row in ipairs(page) do
			local value = (store :: DataStore):GetAsync(row.key)
			if typeof(value) == "table" and not value.done then
				table.insert(out, { key = row.key, n = value.n, k = value.k, at = value.at, t = filtered(value.t, value.u, player), x = value.x, z = value.z, r = value.r })
			end
		end
	end)
	return out
end

local function done(player: Player, key: any): boolean
	if not isAdmin(player) or typeof(key) ~= "string" or #key > 64 then return false end
	for _, entry in ipairs(session) do
		if entry.key == key then entry.value.done = true return true end
	end
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(value)
			if typeof(value) ~= "table" then return nil end
			value.done = true
			return value
		end)
		;(times :: OrderedDataStore):RemoveAsync(key)
	end)
	return ok
end

-- (D-1013) the sender's coins: now when they are in this server with their data
-- loaded (the Coins attribute is set then), else kept for their next visit
local THANKS = "의견 고마워요!"
local function give(userId: number, amount: number): string
	local target = Players:GetPlayerByUserId(userId)
	if target and target:GetAttribute("Coins") ~= nil then
		EconomyService.Gift(target, amount, THANKS)
		return string.format("🎁 %s 님에게 %d코인을 보냈어요.", target.DisplayName, amount)
	end
	local ok = pcall(function()
		(pending :: DataStore):UpdateAsync("u_" .. userId, function(old)
			return (if typeof(old) == "number" then old else 0) + amount
		end)
	end)
	return if ok then string.format("🎁 %d코인을 다음 접속 때 받아요.", amount) else "지금은 보낼 수 없어요. 잠시 뒤에 다시 해 주세요."
end

local function reward(player: Player, key: any): (boolean, string?)
	if not isAdmin(player) or typeof(key) ~= "string" or #key > 64 then return false, nil end
	local amount = FeedbackConfig.RewardCoins or 0
	if amount <= 0 then return false, nil end
	for _, entry in ipairs(session) do
		if entry.key == key then
			if entry.value.r then return false, "이미 코인을 보냈어요." end
			entry.value.r = true
			return true, give(entry.value.u, amount)
		end
	end
	-- (once per message: the flag is set in the same update that finds it unset)
	local sender: number? = nil
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(value)
			if typeof(value) ~= "table" or value.r then return nil end
			value.r = true
			sender = value.u
			return value
		end)
	end)
	if not ok then return false, "지금은 보낼 수 없어요. 잠시 뒤에 다시 해 주세요." end
	if typeof(sender) ~= "number" then return false, "이미 코인을 보냈어요." end
	return true, give(sender :: number, amount)
end

-- coins kept for someone who was offline when the owner gave them
local function claim(player: Player)
	if not pending then return end
	local t0 = os.clock()
	while player.Parent and player:GetAttribute("Coins") == nil and os.clock() - t0 < 30 do task.wait(0.5) end
	if not player.Parent or player:GetAttribute("Coins") == nil then return end
	local amount = 0
	pcall(function()
		(pending :: DataStore):UpdateAsync("u_" .. player.UserId, function(old)
			if typeof(old) ~= "number" or old <= 0 then return nil end
			amount = old
			return 0
		end)
	end)
	if amount > 0 then EconomyService.Gift(player, amount, THANKS) end
end

function FeedbackService.Start()
	local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Feedback") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, payload: any)
		if action == "Send" then return send(player, payload)
		elseif action == "List" then return list(player)
		elseif action == "Done" then return done(player, payload)
		elseif action == "Reward" then return reward(player, payload)
		end
		return false
	end
	local function tell(player: Player)
		if isAdmin(player) then player:SetAttribute("FeedbackAdmin", true) end
		task.spawn(claim, player)
	end
	Players.PlayerAdded:Connect(tell)
	for _, player in ipairs(Players:GetPlayers()) do tell(player) end
	Players.PlayerRemoving:Connect(function(player) lastSent[player] = nil end)
end

return FeedbackService
