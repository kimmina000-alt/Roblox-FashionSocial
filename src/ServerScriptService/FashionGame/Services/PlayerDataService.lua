--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local PlayerDataService = {}

local STORE_NAME = "FashionGame_PlayerData_v1"
local MAX_OUTFITS = 10
local MAX_FAVORITES = 80
local MAX_RECENTS = 40
local MAX_NAME_LENGTH = 32

local store = DataStoreService:GetDataStore(STORE_NAME)
local cache: {[number]: any} = {}

local function blankData()
	return {
		version = 1,
		outfits = {},
		favorites = {},
		recents = {},
	}
end

local function clone(value)
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

local function load(player: Player)
	local userId = player.UserId
	if cache[userId] then
		return cache[userId]
	end
	local ok, result = pcall(function()
		return store:GetAsync("u_" .. tostring(userId))
	end)
	if ok and typeof(result) == "table" then
		if typeof(result.outfits) ~= "table" then result.outfits = {} end
		if typeof(result.favorites) ~= "table" then result.favorites = {} end
		if typeof(result.recents) ~= "table" then result.recents = {} end
		cache[userId] = result
	else
		if not ok then
			warn("[PlayerDataService] GetAsync failed:", result)
		end
		cache[userId] = blankData()
	end
	return cache[userId]
end

local function persist(player: Player): (boolean, string)
	local data = cache[player.UserId]
	if not data then
		return false, "No player data loaded."
	end
	local ok, err = pcall(function()
		store:SetAsync("u_" .. tostring(player.UserId), data)
	end)
	if not ok then
		warn("[PlayerDataService] SetAsync failed:", err)
		return false, "Could not save player data."
	end
	return true, "Saved."
end

local function itemKey(itemType: string, assetId: number): string
	return tostring(itemType) .. ":" .. tostring(assetId)
end

function PlayerDataService.GetPublic(player: Player)
	local data = clone(load(player))
	return true, data
end

function PlayerDataService.SaveOutfit(player: Player, name: string, appearance: any): (boolean, any)
	if typeof(name) ~= "string" then
		return false, "Enter an outfit name."
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" then
		return false, "Enter an outfit name."
	end
	if utf8.len(name) and utf8.len(name) > MAX_NAME_LENGTH then
		name = string.sub(name, 1, MAX_NAME_LENGTH)
	end
	if typeof(appearance) ~= "table" then
		return false, "Outfit appearance is missing."
	end

	local data = load(player)
	if #data.outfits >= MAX_OUTFITS then
		return false, "Outfit limit reached (" .. tostring(MAX_OUTFITS) .. ")."
	end

	local outfit = {
		id = HttpService:GenerateGUID(false),
		name = name,
		createdAt = os.time(),
		appearance = appearance,
	}
	table.insert(data.outfits, 1, outfit)
	local ok, message = persist(player)
	if not ok then
		table.remove(data.outfits, 1)
		return false, message
	end
	return true, clone(outfit)
end

function PlayerDataService.GetOutfit(player: Player, outfitId: string)
	local data = load(player)
	for _, outfit in ipairs(data.outfits) do
		if outfit.id == outfitId then
			return true, clone(outfit)
		end
	end
	return false, "Outfit not found."
end

function PlayerDataService.ToggleFavorite(player: Player, assetId: number, itemType: string): (boolean, any)
	if typeof(assetId) ~= "number" or assetId <= 0 then
		return false, "Invalid item."
	end
	if typeof(itemType) ~= "string" or itemType == "" then
		itemType = "Asset"
	end
	local data = load(player)
	local key = itemKey(itemType, assetId)
	for index, entry in ipairs(data.favorites) do
		if itemKey(entry.itemType, entry.id) == key then
			table.remove(data.favorites, index)
			local ok, message = persist(player)
			if not ok then
				table.insert(data.favorites, index, entry)
				return false, message
			end
			return true, { favorited = false, favorites = clone(data.favorites) }
		end
	end
	if #data.favorites >= MAX_FAVORITES then
		table.remove(data.favorites)
	end
	table.insert(data.favorites, 1, {
		id = assetId,
		itemType = itemType,
		addedAt = os.time(),
	})
	local ok, message = persist(player)
	if not ok then
		table.remove(data.favorites, 1)
		return false, message
	end
	return true, { favorited = true, favorites = clone(data.favorites) }
end

function PlayerDataService.AddRecent(player: Player, assetId: number, itemType: string): (boolean, any)
	if typeof(assetId) ~= "number" or assetId <= 0 then
		return false, "Invalid item."
	end
	if typeof(itemType) ~= "string" or itemType == "" then
		itemType = "Asset"
	end
	local data = load(player)
	local key = itemKey(itemType, assetId)
	for index, entry in ipairs(data.recents) do
		if itemKey(entry.itemType, entry.id) == key then
			table.remove(data.recents, index)
			break
		end
	end
	table.insert(data.recents, 1, {
		id = assetId,
		itemType = itemType,
		viewedAt = os.time(),
	})
	while #data.recents > MAX_RECENTS do
		table.remove(data.recents)
	end
	local ok, message = persist(player)
	if not ok then
		return false, message
	end
	return true, clone(data.recents)
end

function PlayerDataService.Handle(player: Player, action: string, payload: any)
	if action == "Get" then
		return PlayerDataService.GetPublic(player)
	end
	if action == "SaveOutfit" then
		if typeof(payload) ~= "table" then
			return false, "Invalid save request."
		end
		return PlayerDataService.SaveOutfit(player, payload.name, payload.appearance)
	end
	if action == "GetOutfit" then
		if typeof(payload) ~= "table" or typeof(payload.id) ~= "string" then
			return false, "Invalid outfit id."
		end
		return PlayerDataService.GetOutfit(player, payload.id)
	end
	if action == "ToggleFavorite" then
		if typeof(payload) ~= "table" then
			return false, "Invalid favorite request."
		end
		return PlayerDataService.ToggleFavorite(player, payload.id, payload.itemType)
	end
	if action == "AddRecent" then
		if typeof(payload) ~= "table" then
			return false, "Invalid recent request."
		end
		return PlayerDataService.AddRecent(player, payload.id, payload.itemType)
	end
	return false, "Invalid data action."
end

function PlayerDataService.PlayerRemoving(player: Player)
	if cache[player.UserId] then
		pcall(persist, player)
		cache[player.UserId] = nil
	end
end

PlayerDataService.MaxOutfits = MAX_OUTFITS
PlayerDataService.MaxNameLength = MAX_NAME_LENGTH

return PlayerDataService
