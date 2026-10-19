--!strict
-- Per-player persistent data. Currently: in-game Favorites (D-019/D-020/D-023 apply:
-- Favorites persist; Recent is session-only and never stored here; SavedOutfits
-- will be added in Stage 2 with a 50-outfit cap).
--
-- Writes use UpdateAsync and only replace the fields this session owns, so data
-- written by other servers/fields is preserved. If the DataStore is unavailable
-- (for example Studio without API access, or a load failure) the session keeps
-- working in memory and the client is told that changes will not be saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataService = {}

local STORE_NAME = "FashionGamePlayerData"
local SCHEMA_VERSION = 1
PlayerDataService.MaxFavorites = 200
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 3

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerDataService] DataStore unavailable:", result)
	end
end

type Favorite = { id: number, itemType: string, addedAt: number }
type Session = {
	favorites: {Favorite},
	persistent: boolean,
	dirty: boolean,
	note: string?,
}

local sessions: {[number]: Session} = {}
local loading: {[number]: boolean} = {}

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function sanitizeFavorites(list: any): {Favorite}
	local result = {}
	local seen = {}
	if typeof(list) ~= "table" then return result end
	for _, entry in ipairs(list) do
		if typeof(entry) == "table" and typeof(entry.id) == "number" and entry.id > 0
			and (entry.itemType == "Asset" or entry.itemType == "Bundle") then
			local key = entry.itemType .. ":" .. tostring(entry.id)
			if not seen[key] and #result < PlayerDataService.MaxFavorites then
				seen[key] = true
				table.insert(result, {
					id = entry.id,
					itemType = entry.itemType,
					addedAt = if typeof(entry.addedAt) == "number" then entry.addedAt else 0,
				})
			end
		end
	end
	return result
end

local function load(player: Player): Session
	local userId = player.UserId
	local existing = sessions[userId]
	if existing then return existing end
	while loading[userId] do task.wait(0.1) end
	if sessions[userId] then return sessions[userId] end
	loading[userId] = true

	local session: Session = { favorites = {}, persistent = false, dirty = false, note = nil }
	if store then
		local lastError: any = nil
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, data = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(userId))
			end)
			if ok then
				if typeof(data) == "table" then
					session.favorites = sanitizeFavorites(data.favorites)
				end
				session.persistent = true
				lastError = nil
				break
			end
			lastError = data
			if string.find(tostring(data), "403", 1, true) or string.find(tostring(data), "Studio access", 1, true) then break end
			task.wait(attempt)
		end
		if lastError then
			warn("[PlayerDataService] Load failed, using session-only data:", lastError)
			local studioOff = string.find(tostring(lastError), "403", 1, true) or string.find(tostring(lastError), "Studio access", 1, true)
			session.note = if studioOff
				then "Studio API 접근이 꺼져 있어 이번 접속 동안만 유지됩니다."
				else "저장 데이터를 불러오지 못해 이번 접속 동안만 유지됩니다."
		end
	else
		session.note = "저장소를 쓸 수 없어 이번 접속 동안만 유지됩니다."
	end

	sessions[userId] = session
	loading[userId] = nil
	return session
end

local function save(player: Player): boolean
	local session = sessions[player.UserId]
	if not session or not session.persistent or not session.dirty or not store then
		return true
	end
	local favorites = table.clone(session.favorites)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player.UserId), function(old)
			local data = if typeof(old) == "table" then old else {}
			data.version = SCHEMA_VERSION
			data.favorites = favorites
			return data
		end)
	end)
	if ok then
		session.dirty = false
	else
		warn("[PlayerDataService] Save failed:", err)
	end
	return ok
end

local function publicFavorites(session: Session)
	return {
		favorites = session.favorites,
		persistent = session.persistent,
		note = session.note,
		max = PlayerDataService.MaxFavorites,
	}
end

function PlayerDataService.GetFavorites(player: Player)
	return true, publicFavorites(load(player))
end

function PlayerDataService.ToggleFavorite(player: Player, id: any, itemType: any)
	if typeof(id) ~= "number" or id <= 0 or id % 1 ~= 0 then
		return false, "Invalid item."
	end
	if itemType ~= "Asset" and itemType ~= "Bundle" then
		return false, "Invalid item type."
	end
	local session = load(player)
	for index, entry in ipairs(session.favorites) do
		if entry.id == id and entry.itemType == itemType then
			table.remove(session.favorites, index)
			session.dirty = true
			local result = publicFavorites(session)
			result.favorited = false
			return true, result
		end
	end
	if #session.favorites >= PlayerDataService.MaxFavorites then
		return false, "Favorites are full (" .. tostring(PlayerDataService.MaxFavorites) .. ")."
	end
	table.insert(session.favorites, 1, { id = id, itemType = itemType, addedAt = os.time() })
	session.dirty = true
	local result = publicFavorites(session)
	result.favorited = true
	return true, result
end

function PlayerDataService.Handle(player: Player, action: string, payload: any)
	if action == "GetFavorites" then
		return PlayerDataService.GetFavorites(player)
	end
	if action == "ToggleFavorite" then
		if typeof(payload) ~= "table" then
			return false, "Invalid request."
		end
		return PlayerDataService.ToggleFavorite(player, payload.id, payload.itemType)
	end
	return false, "Invalid data action."
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		sessions[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end)
end

return PlayerDataService
