--!strict
-- Per-player persistent data: in-game Favorites and SavedOutfits (Wardrobe).
-- D-019/D-020/D-023: Favorites and SavedOutfits persist (SavedOutfits capped at
-- 50 per user); Recent is session-only and never stored here.
--
-- Outfit save/delete are written immediately and only reported as successful
-- after the write is confirmed (or, when the DataStore is unavailable, with an
-- explicit "this session only" note). A failed write rolls the change back.
--
-- Writes use UpdateAsync and only replace the fields this session owns, so data
-- written by other servers/fields is preserved. If the DataStore is unavailable
-- (for example Studio without API access, or a load failure) the session keeps
-- working in memory and the client is told that changes will not be saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local PlayerDataService = {}

local STORE_NAME = "FashionGamePlayerData"
local SCHEMA_VERSION = 1
PlayerDataService.MaxFavorites = 200
PlayerDataService.MaxOutfits = 50
PlayerDataService.MaxOutfitNameLength = 30
local MAX_RECORD_BYTES = 3_500_000 -- DataStore value limit is 4 MB
local WRITE_ATTEMPTS = 3
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
type Outfit = { id: string, name: string, createdAt: number, snapshot: any }
type Session = {
	favorites: {Favorite},
	outfits: {Outfit},
	writing: boolean,
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

local function sanitizeOutfits(list: any): {Outfit}
	local result = {}
	local seen = {}
	if typeof(list) ~= "table" then return result end
	for _, entry in ipairs(list) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and not seen[entry.id]
			and typeof(entry.name) == "string" and typeof(entry.snapshot) == "table" then
			seen[entry.id] = true
			table.insert(result, {
				id = entry.id,
				name = entry.name,
				createdAt = if typeof(entry.createdAt) == "number" then entry.createdAt else 0,
				snapshot = entry.snapshot,
			})
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

	local session: Session = { favorites = {}, outfits = {}, writing = false, persistent = false, dirty = false, note = nil }
	if store then
		local lastError: any = nil
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, data = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(userId))
			end)
			if ok then
				if typeof(data) == "table" then
					session.favorites = sanitizeFavorites(data.favorites)
					session.outfits = sanitizeOutfits(data.outfits)
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
	local outfits = table.clone(session.outfits)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player.UserId), function(old)
			local data = if typeof(old) == "table" then old else {}
			data.version = SCHEMA_VERSION
			data.favorites = favorites
			data.outfits = outfits
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

--------------------------------------------------
-- WARDROBE (SavedOutfits)
--------------------------------------------------

local function publicOutfits(session: Session)
	return {
		outfits = session.outfits,
		persistent = session.persistent,
		note = session.note,
		max = PlayerDataService.MaxOutfits,
	}
end

-- Writes the session now with bounded retries. When a write call errors the
-- result is ambiguous, so a follow-up read checks whether the change landed.
local function writeNow(player: Player, session: Session, landed: (any) -> boolean): (boolean, string?)
	if not session.persistent or not store then
		return true, nil
	end
	local favorites = table.clone(session.favorites)
	local outfits = table.clone(session.outfits)
	local encodedOk, encoded = pcall(HttpService.JSONEncode, HttpService, { favorites = favorites, outfits = outfits })
	if not encodedOk then
		return false, "저장할 수 없는 데이터입니다."
	end
	if #encoded > MAX_RECORD_BYTES then
		return false, "저장 데이터가 너무 큽니다."
	end
	local lastError: any = nil
	for attempt = 1, WRITE_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player.UserId), function(old)
				local data = if typeof(old) == "table" then old else {}
				data.version = SCHEMA_VERSION
				data.favorites = favorites
				data.outfits = outfits
				return data
			end)
		end)
		if ok then
			session.dirty = false
			return true, nil
		end
		lastError = err
		local readOk, data = pcall(function()
			return (store :: DataStore):GetAsync(keyFor(player.UserId))
		end)
		if readOk and landed(data) then
			session.dirty = false
			return true, nil
		end
		task.wait(attempt)
	end
	warn("[PlayerDataService] Outfit write failed:", lastError)
	return false, "저장소에 기록하지 못했습니다. 잠시 후 다시 시도하세요."
end

function PlayerDataService.GetOutfits(player: Player)
	return true, publicOutfits(load(player))
end

function PlayerDataService.SaveOutfit(player: Player, name: any, snapshot: any)
	if typeof(name) ~= "string" then
		return false, "이름을 입력하세요."
	end
	local trimmed = (string.gsub(name, "%c", ""))
	trimmed = (string.gsub(trimmed, "^%s+", ""))
	trimmed = (string.gsub(trimmed, "%s+$", ""))
	if trimmed == "" then
		return false, "이름을 입력하세요."
	end
	local length = utf8.len(trimmed)
	if not length or length > PlayerDataService.MaxOutfitNameLength then
		return false, "이름은 " .. PlayerDataService.MaxOutfitNameLength .. "자 이하로 입력하세요."
	end
	if typeof(snapshot) ~= "table" then
		return false, "현재 외형을 읽지 못했습니다."
	end
	local session = load(player)
	if session.writing then
		return false, "이전 저장이 아직 진행 중입니다."
	end
	if #session.outfits >= PlayerDataService.MaxOutfits then
		return false, "옷장이 가득 찼습니다 (" .. PlayerDataService.MaxOutfits .. "개). 기존 코디를 삭제하세요."
	end
	local outfit: Outfit = {
		id = HttpService:GenerateGUID(false),
		name = trimmed,
		createdAt = os.time(),
		snapshot = snapshot,
	}
	session.writing = true
	table.insert(session.outfits, 1, outfit)
	session.dirty = true
	local ok, message = writeNow(player, session, function(data)
		if typeof(data) ~= "table" or typeof(data.outfits) ~= "table" then return false end
		for _, entry in ipairs(data.outfits) do
			if typeof(entry) == "table" and entry.id == outfit.id then return true end
		end
		return false
	end)
	if not ok then
		local index = table.find(session.outfits, outfit)
		if index then table.remove(session.outfits, index) end
	end
	session.writing = false
	if not ok then
		return false, message
	end
	local result: any = publicOutfits(session)
	result.savedId = outfit.id
	return true, result
end

function PlayerDataService.DeleteOutfit(player: Player, id: any)
	if typeof(id) ~= "string" then
		return false, "Invalid outfit."
	end
	local session = load(player)
	if session.writing then
		return false, "이전 저장이 아직 진행 중입니다."
	end
	local index: number? = nil
	for i, entry in ipairs(session.outfits) do
		if entry.id == id then index = i end
	end
	if not index then
		return false, "이미 삭제된 코디입니다."
	end
	session.writing = true
	local removed = table.remove(session.outfits, index)
	session.dirty = true
	local ok, message = writeNow(player, session, function(data)
		if typeof(data) ~= "table" or typeof(data.outfits) ~= "table" then return false end
		for _, entry in ipairs(data.outfits) do
			if typeof(entry) == "table" and entry.id == id then return false end
		end
		return true
	end)
	if not ok then
		table.insert(session.outfits, index :: number, removed)
	end
	session.writing = false
	if not ok then
		return false, message
	end
	return true, publicOutfits(session)
end

local function validName(name: any): (string?, string?)
	if typeof(name) ~= "string" then
		return nil, "이름을 입력하세요."
	end
	local trimmed = (string.gsub(name, "%c", ""))
	trimmed = (string.gsub(trimmed, "^%s+", ""))
	trimmed = (string.gsub(trimmed, "%s+$", ""))
	if trimmed == "" then
		return nil, "이름을 입력하세요."
	end
	local length = utf8.len(trimmed)
	if not length or length > PlayerDataService.MaxOutfitNameLength then
		return nil, "이름은 " .. PlayerDataService.MaxOutfitNameLength .. "자 이하로 입력하세요."
	end
	return trimmed, nil
end

-- Rename keeps the outfit id, snapshot and date; only the name changes.
function PlayerDataService.RenameOutfit(player: Player, id: any, name: any)
	if typeof(id) ~= "string" then
		return false, "Invalid outfit."
	end
	local trimmed, problem = validName(name)
	if not trimmed then
		return false, problem
	end
	local session = load(player)
	if session.writing then
		return false, "이전 저장이 아직 진행 중입니다."
	end
	local target: Outfit? = nil
	for _, entry in ipairs(session.outfits) do
		if entry.id == id then target = entry end
	end
	if not target then
		return false, "이미 삭제된 코디입니다."
	end
	local outfit = target :: Outfit
	local previous = outfit.name
	session.writing = true
	outfit.name = trimmed :: string
	session.dirty = true
	local ok, message = writeNow(player, session, function(data)
		if typeof(data) ~= "table" or typeof(data.outfits) ~= "table" then return false end
		for _, entry in ipairs(data.outfits) do
			if typeof(entry) == "table" and entry.id == id then return entry.name == trimmed end
		end
		return false
	end)
	if not ok then
		outfit.name = previous
	end
	session.writing = false
	if not ok then
		return false, message
	end
	return true, publicOutfits(session)
end

-- Snapshot of one saved outfit (the server-side restore reads it from here).
function PlayerDataService.GetOutfitSnapshot(player: Player, id: any): any
	if typeof(id) ~= "string" then return nil end
	for _, entry in ipairs(load(player).outfits) do
		if entry.id == id then return entry.snapshot end
	end
	return nil
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
	if action == "GetOutfits" then
		return PlayerDataService.GetOutfits(player)
	end
	if action == "RenameOutfit" then
		if typeof(payload) ~= "table" then
			return false, "Invalid request."
		end
		return PlayerDataService.RenameOutfit(player, payload.id, payload.name)
	end
	if action == "DeleteOutfit" then
		return PlayerDataService.DeleteOutfit(player, if typeof(payload) == "table" then payload.id else nil)
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
