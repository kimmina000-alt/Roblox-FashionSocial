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
-- (D-1805, user 2026-11-18: "받은 의견 뜨는데 오래 걸리네. 새로운 의견 올라오면 n 띄워 줘") the newest
-- messages are read all at once and kept (valueCache; a message only changes by done / reward,
-- which update it too), read ahead when the owner joins; player attribute FeedbackNew = true
-- (a red N on 💬 and 📥) while a message newer than the last one the owner saw is waiting: checked
-- at join, every NewCheckSeconds, and at once when someone in this server sends one; opening the
-- inbox marks everything listed as seen (DataStore "FeedbackSeen_v1", u_<userId> = newest time).

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
local valueCache: {[string]: any} = {} -- (D-1805) key → the stored message (filtered text in .tf)
local seenStore: DataStore? = nil
pcall(function()
	seenStore = DataStoreService:GetDataStore(if RunService:IsStudio() then "FeedbackSeen_Studio_v1" else "FeedbackSeen_v1")
end)
local NEW_CHECK_SECONDS = 60
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
	-- (D-1325) filtered now, while the sender is in this server: the owner reads it
	-- later, when the sender has usually left (filtering then failed, so the inbox
	-- showed "(필터를 거치지 못한 글)" for every message)
	local tf: string? = nil
	pcall(function()
		tf = TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	local value = {
		u = player.UserId, n = player.Name, k = payload.kind, t = text, tf = tf, at = at,
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
	-- (D-1805) the owner, if here, sees the N at once
	for _, other in ipairs(Players:GetPlayers()) do
		if other:GetAttribute("FeedbackAdmin") then other:SetAttribute("FeedbackNew", true) end
	end
	-- (D-769, user: shown for 1 s over the form, Feedback.lua)
	return true, "소중한 의견이 잘 접수되었어요. 고마워요! 💛"
end

-- the owner reads them in the game: filtered for the owner (Roblox text rules).
-- (D-1325, user 2026-11-12: "받은 의견 ... 눌러도 내용 안 보임") FilterStringAsync fails
-- for a sender who is not in this server, which is nearly always, so every message
-- read "(필터를 거치지 못한 글)". Now: the text filtered when it was sent (value.tf);
-- for older messages the sender's id, else the owner's own id as the author.
local function filtered(value: any, to: Player): string
	if typeof(value.tf) == "string" and value.tf ~= "" then return value.tf end
	local text = tostring(value.t)
	for _, from in ipairs({ value.u, to.UserId }) do
		if typeof(from) == "number" then
			local ok, result = pcall(function()
				return TextService:FilterStringAsync(text, from):GetNonChatStringForUserAsync(to.UserId)
			end)
			if ok and typeof(result) == "string" then return result end
		end
	end
	return "(필터를 거치지 못한 글)"
end

-- (D-1805) the owner's newest seen time (0 when never)
local function seenAt(player: Player): number
	local seen = 0
	if seenStore then
		pcall(function() seen = tonumber((seenStore :: DataStore):GetAsync("u_" .. player.UserId)) or 0 end)
	end
	return seen
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
		-- (D-1805) every message read at the same time (one after another took seconds), and kept
		local rows: {any} = {}
		local left = #page
		for i, row in ipairs(page) do
			task.spawn(function()
				local value = valueCache[row.key]
				if value == nil then
					pcall(function() value = (store :: DataStore):GetAsync(row.key) end)
					if typeof(value) == "table" then
						value.tf = filtered(value, player) -- (filtered once, then kept)
						valueCache[row.key] = value
					end
				end
				rows[i] = value
				left -= 1
			end)
		end
		local t0 = os.clock()
		while left > 0 and os.clock() - t0 < 15 do task.wait() end
		for i, row in ipairs(page) do
			local value = rows[i]
			if typeof(value) == "table" and not value.done then
				table.insert(out, { key = row.key, n = value.n, k = value.k, at = value.at, t = value.tf or tostring(value.t), x = value.x, z = value.z, r = value.r })
			end
		end
	end)
	-- (D-1805) everything listed now counts as seen
	local newest = 0
	for _, row in ipairs(out) do
		if typeof(row.at) == "number" and row.at > newest then newest = row.at end
	end
	if newest > 0 and seenStore then
		task.spawn(pcall, function() (seenStore :: DataStore):SetAsync("u_" .. player.UserId, newest) end)
	end
	player:SetAttribute("FeedbackSeenAt", math.max(newest, (player:GetAttribute("FeedbackSeenAt") :: number?) or 0))
	player:SetAttribute("FeedbackNew", false)
	return out
end

-- (D-1805) is there a message newer than the owner's last look?
local function checkNew(player: Player)
	if not times or not player.Parent then return end
	local seen = (player:GetAttribute("FeedbackSeenAt") :: number?) or 0
	pcall(function()
		local page = (times :: OrderedDataStore):GetSortedAsync(false, 1, seen + 1):GetCurrentPage()
		if #page > 0 then player:SetAttribute("FeedbackNew", true) end
	end)
end

local function done(player: Player, key: any): boolean
	if not isAdmin(player) or typeof(key) ~= "string" or #key > 64 then return false end
	for _, entry in ipairs(session) do
		if entry.key == key then entry.value.done = true return true end
	end
	if valueCache[key] then valueCache[key].done = true end -- (D-1805)
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
	if valueCache[key] then valueCache[key].r = true end -- (D-1805)
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
		if isAdmin(player) then
			player:SetAttribute("FeedbackAdmin", true)
			-- (D-1805) the N, then a check every minute; the inbox read ahead so it opens at once
			task.spawn(function()
				player:SetAttribute("FeedbackSeenAt", seenAt(player))
				checkNew(player)
				task.spawn(function()
					pcall(function()
						local page = (times :: OrderedDataStore):GetSortedAsync(false, FeedbackConfig.ListSize):GetCurrentPage()
						for _, row in ipairs(page) do
							if valueCache[row.key] == nil then
								task.spawn(function()
									local value
									pcall(function() value = (store :: DataStore):GetAsync(row.key) end)
									if typeof(value) == "table" and valueCache[row.key] == nil then
										value.tf = filtered(value, player)
										valueCache[row.key] = value
									end
								end)
							end
						end
					end)
				end)
				while player.Parent do
					task.wait(NEW_CHECK_SECONDS)
					if not player:GetAttribute("FeedbackNew") then checkNew(player) end
				end
			end)
		end
		task.spawn(claim, player)
	end
	Players.PlayerAdded:Connect(tell)
	for _, player in ipairs(Players:GetPlayers()) do tell(player) end
	Players.PlayerRemoving:Connect(function(player) lastSent[player] = nil end)
end

return FeedbackService
