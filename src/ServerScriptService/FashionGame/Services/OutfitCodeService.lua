--!strict
-- (D-1137, user 2026-11-10: "우리 게임 안 코디 공유 구현됐는지 확인" → "응 코드 공유 만들자")
-- 코디 코드: the look worn now (AvatarService.CaptureSnapshot, the same snapshot
-- the 옷장 saves) is stored under a short code anyone can type in the 옷장's
-- 🔗 코디 코드 window to put that look on (AvatarService.RestoreSnapshot, like
-- a saved outfit: items they do not own are tried on, as in the catalog).
-- Codes: 6 letters / digits without look-alikes (no I, O, 0, 1), in every
-- server (DataStore). Studio writes to a store of its own, so test codes never
-- mix with the live ones.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local OutfitCodeService = {}

local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
OutfitCodeService.Length = 6
local MAKE_EVERY = 15 -- seconds between two codes of one player
local WEAR_EVERY = 3

local store: DataStore? = nil
local function storeOf(): DataStore?
	if store then return store end
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(if RunService:IsStudio() then "OutfitCodes_Studio_v1" else "OutfitCodes_v1")
	end)
	if ok then store = s end
	return store
end

local cache: {[string]: any} = {}
local lastMake: {[number]: number} = {}
local lastWear: {[number]: number} = {}

-- "ab 12-cd" → "AB12CD"; nil when it cannot be a code
function OutfitCodeService.normalize(text: any): string?
	if typeof(text) ~= "string" or #text > 40 then return nil end
	local s = string.upper((string.gsub(text, "[%s%-#_]", "")))
	if #s ~= OutfitCodeService.Length then return nil end
	for i = 1, #s do
		if not string.find(ALPHABET, string.sub(s, i, i), 1, true) then return nil end
	end
	return s
end

local function newCode(): string
	local t = {}
	for i = 1, OutfitCodeService.Length do
		local k = math.random(1, #ALPHABET)
		t[i] = string.sub(ALPHABET, k, k)
	end
	return table.concat(t)
end

-- a code for this look (ok, code | message)
function OutfitCodeService.make(player: Player, snapshot: any): (boolean, string)
	local now = os.clock()
	if lastMake[player.UserId] and now - lastMake[player.UserId] < MAKE_EVERY then
		return false, string.format("%d초 뒤에 다시 만들 수 있어요.", math.ceil(MAKE_EVERY - (now - lastMake[player.UserId])))
	end
	local ds = storeOf()
	if not ds then return false, "지금은 코드를 만들 수 없어요. 잠시 후 다시 시도하세요." end
	lastMake[player.UserId] = now
	local entry = { s = snapshot, by = player.UserId, at = os.time() }
	for _ = 1, 6 do
		local code = newCode()
		local taken = false
		local ok = pcall(function()
			ds:UpdateAsync(code, function(old)
				if old ~= nil then taken = true return nil end
				return entry
			end)
		end)
		if ok and not taken then
			cache[code] = snapshot
			return true, code
		end
		if not ok then break end
	end
	lastMake[player.UserId] = nil
	return false, "코드를 만들지 못했어요. 잠시 후 다시 시도하세요."
end

-- the look under a code (ok, snapshot | message)
function OutfitCodeService.find(player: Player, text: any): (boolean, any)
	local code = OutfitCodeService.normalize(text)
	if not code then return false, string.format("코드는 %d자리예요 (영어 대문자와 숫자).", OutfitCodeService.Length) end
	local now = os.clock()
	if lastWear[player.UserId] and now - lastWear[player.UserId] < WEAR_EVERY then
		return false, "잠시 후 다시 시도하세요."
	end
	lastWear[player.UserId] = now
	if cache[code] then return true, cache[code] end
	local ds = storeOf()
	if not ds then return false, "지금은 코드를 불러올 수 없어요." end
	local ok, data = pcall(function() return ds:GetAsync(code) end)
	if not ok then return false, "코드를 불러오지 못했어요. 잠시 후 다시 시도하세요." end
	if typeof(data) ~= "table" or typeof(data.s) ~= "table" then return false, "없는 코드예요. 다시 확인해 주세요." end
	cache[code] = data.s
	return true, data.s
end

return OutfitCodeService
