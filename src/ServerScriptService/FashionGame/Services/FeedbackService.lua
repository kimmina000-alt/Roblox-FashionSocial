--!strict
-- 💬 의견 보내기 (D-725, Shared/FeedbackConfig). Remote Feedback (RemoteFunction):
--   "Send", { kind, text }  → true / false, message
--   "List"                  → the newest messages (the game's owner only)
--   "Done", key             → the owner marks one handled (hidden from the list)
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

local FeedbackService = {}

local store: DataStore? = nil
local times: OrderedDataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("Feedback_v1")
	times = DataStoreService:GetOrderedDataStore("FeedbackTimes")
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
	return true, "고마워요! 의견이 잘 전해졌어요. 💛"
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
			table.insert(out, { key = entry.key, n = entry.value.n, k = entry.value.k, at = entry.value.at, t = entry.value.t, x = entry.value.x, z = entry.value.z })
		end
	end
	pcall(function()
		local page = (times :: OrderedDataStore):GetSortedAsync(false, FeedbackConfig.ListSize):GetCurrentPage()
		for _, row in ipairs(page) do
			local value = (store :: DataStore):GetAsync(row.key)
			if typeof(value) == "table" and not value.done then
				table.insert(out, { key = row.key, n = value.n, k = value.k, at = value.at, t = filtered(value.t, value.u, player), x = value.x, z = value.z })
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

function FeedbackService.Start()
	local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Feedback") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, payload: any)
		if action == "Send" then return send(player, payload)
		elseif action == "List" then return list(player)
		elseif action == "Done" then return done(player, payload)
		end
		return false
	end
	local function tell(player: Player)
		if isAdmin(player) then player:SetAttribute("FeedbackAdmin", true) end
	end
	Players.PlayerAdded:Connect(tell)
	for _, player in ipairs(Players:GetPlayers()) do tell(player) end
	Players.PlayerRemoving:Connect(function(player) lastSent[player] = nil end)
end

return FeedbackService
