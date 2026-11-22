--!strict
-- (D-COMMUNITY, user 2026-11-22: "오후 카탈로그에 사람들이 캐릭터 꾸며서 올릴 수 있는 카테고리 추가하자")
-- 코디 = players post the look they wear now; everyone browses the posts in the catalog's 코디 tab,
-- tries a look on (입기, free like every try-on) and buys its items (사기, Roblox's one window).
-- User picks 2026-11-22: a grid like 추천 with [최신] [인기] and 📤 올리기; no limit on the number of
-- posts (only POST_EVERY seconds between two); 🚩 by 3 different players hides a post at once; the
-- poster deletes their own (🗑), the owner deletes / un-hides any; 인기 = 👍 count (one per player).
--
-- Stores (Studio uses "_Studio" stores of its own, so test posts never reach the live list):
--   DataStore CommunityLooks_v1: "p<id>" = post { id, by, name, title, s (OutfitSnapshot), items
--     ({ kind, id, price }), price, at, likes, reports, hidden }; "next" = the id counter;
--     "u<userId>" = { [postKey] = true } the posts that player liked; "r<id>" = { [userId] = true }
--   OrderedDataStores CommunityLooksNew_v1 (key → time), CommunityLooksTop_v1 (key → likes),
--     CommunityLooksHidden_v1 (key → time hidden; the owner's [숨김] list)
-- Card pictures: a rig built from the snapshot on the server (kept in ServerStorage, MAX_RIGS),
-- copied into the asking player's PlayerGui.CommunityRigs only (nobody else downloads it).

local AssetService = game:GetService("AssetService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local OutfitSnapshot = require(FashionGame.Shared.OutfitSnapshot)

local Service = {}

local POST_EVERY = 60 -- seconds between two posts of one player
local ACT_EVERY = 1 -- likes / reports / deletes
local LIST_EVERY = 1.5
local LIST_TTL = 30 -- seconds a sorted list is kept before it is read again
local POST_TTL = 60
local LIST_MAX = 100 -- posts a sorted list shows
local PAGE = 17 -- cards per page (the first cell of the grid is the control card)
local REPORTS_TO_HIDE = 3
local TITLE_MAX = 20
local ITEMS_MAX = 30
local MAX_RIGS = 40

local SUFFIX = if RunService:IsStudio() then "_Studio_v1" else "_v1"
local stores: {[string]: any} = {}
local function storeOf(name: string, ordered: boolean): any
	local key = name .. (if ordered then "#o" else "")
	if stores[key] then return stores[key] end
	local ok, s = pcall(function()
		if ordered then return DataStoreService:GetOrderedDataStore(name .. SUFFIX) end
		return DataStoreService:GetDataStore(name .. SUFFIX)
	end)
	if ok then stores[key] = s end
	return stores[key]
end
local function main(): DataStore? return storeOf("CommunityLooks", false) end
local SORTS = { New = "CommunityLooksNew", Top = "CommunityLooksTop", Hidden = "CommunityLooksHidden" }

local function isOwner(player: Player): boolean
	if RunService:IsStudio() then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local postCache: {[string]: { post: any, t: number }} = {}
local listCache: {[string]: { keys: {string}, t: number }} = {}
local likedCache: {[number]: {[string]: boolean}} = {}
local last: {[string]: number} = {}

local function cooldown(player: Player, what: string, every: number): number?
	local k = what .. player.UserId
	local now = os.clock()
	if last[k] and now - last[k] < every then return every - (now - last[k]) end
	last[k] = now
	return nil
end

local function readPost(key: string, fresh: boolean?): any
	local cached = postCache[key]
	if cached and not fresh and os.clock() - cached.t < POST_TTL then return cached.post end
	local ds = main()
	if not ds then return cached and cached.post end
	local ok, data = pcall(function() return (ds :: DataStore):GetAsync(key) end)
	if not ok then return cached and cached.post end
	if typeof(data) ~= "table" then postCache[key] = nil return nil end
	postCache[key] = { post = data, t = os.clock() }
	return data
end

local function readList(sort: string, fresh: boolean?): {string}
	local cached = listCache[sort]
	if cached and not fresh and os.clock() - cached.t < LIST_TTL then return cached.keys end
	local ods = storeOf(SORTS[sort], true)
	local keys = {}
	if ods then
		local ok, pages = pcall(function() return ods:GetSortedAsync(false, LIST_MAX) end)
		if ok and pages then
			for _, entry in ipairs(pages:GetCurrentPage()) do table.insert(keys, entry.key) end
		elseif cached then
			return cached.keys
		end
	end
	listCache[sort] = { keys = keys, t = os.clock() }
	return keys
end

local function forget(key: string)
	for _, entry in pairs(listCache) do
		local i = table.find(entry.keys, key)
		if i then table.remove(entry.keys, i) end
	end
end

local function likedBy(player: Player): {[string]: boolean}
	if likedCache[player.UserId] then return likedCache[player.UserId] end
	local ds = main()
	local set = {}
	if ds then
		local ok, data = pcall(function() return (ds :: DataStore):GetAsync("u" .. player.UserId) end)
		if ok and typeof(data) == "table" then set = data end
	end
	likedCache[player.UserId] = set
	return set
end

-- what a card needs (no snapshot)
local function card(post: any, player: Player, liked: {[string]: boolean}): any
	local key = "p" .. post.id
	return {
		key = key, title = post.title, name = post.name, likes = post.likes or 0, price = post.price or 0,
		items = post.items or {}, liked = liked[key] == true, mine = post.by == player.UserId,
		hidden = post.hidden == true, at = post.at,
	}
end

--------------------------------------------------
-- card pictures
--------------------------------------------------
local rigFolder: Folder? = nil
local rigOrder: {string} = {}
local building: {[string]: boolean} = {}
local function rigs(): Folder
	if rigFolder then return rigFolder end
	local f = Instance.new("Folder")
	f.Name = "CommunityRigs"
	f.Parent = ServerStorage
	rigFolder = f
	return f
end

local function buildRig(key: string, snapshot: any): Model?
	local folder = rigs()
	local have = folder:FindFirstChild(key)
	if have then
		local i = table.find(rigOrder, key)
		if i then table.remove(rigOrder, i) end
		table.insert(rigOrder, key)
		return have :: Model
	end
	while building[key] do task.wait(0.1) end
	if folder:FindFirstChild(key) then return folder:FindFirstChild(key) :: Model end
	building[key] = true
	local rig: Model? = nil
	local ok, err = pcall(function()
		local description = OutfitSnapshot.decode(snapshot)
		if not description then return end
		local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then d:Destroy() end
		end
		-- joints and layered clothing are only solved in Workspace: a moment far under the map
		model.Name = key
		model:PivotTo(CFrame.new(0, -5000, 0))
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then root.Anchored = true end
		model.Parent = workspace
		for _ = 1, 10 do RunService.Heartbeat:Wait() end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true end
		end
		model:PivotTo(CFrame.new())
		model.Parent = folder
		rig = model
	end)
	building[key] = nil
	if not ok then warn("[CommunityLooks] rig failed:", key, err) return nil end
	if rig then
		table.insert(rigOrder, key)
		while #rigOrder > MAX_RIGS do
			local old = table.remove(rigOrder, 1)
			local m = folder:FindFirstChild(old :: string)
			if m then m:Destroy() end
		end
	end
	return rig
end

local function playerRigs(player: Player): Folder?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then return nil end
	local f = gui:FindFirstChild("CommunityRigs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "CommunityRigs"
		f.Parent = gui
	end
	return f :: Folder
end

-- copies of the cards' rigs for this player only (a new list's first page clears the old copies;
-- the client keeps clones of its own)
local function sendRigs(player: Player, keys: {string}, clear: boolean)
	local f = playerRigs(player)
	if not f then return end
	if clear then f:ClearAllChildren() end
	task.spawn(function()
		for _, key in ipairs(keys) do
			local post = readPost(key)
			if post and typeof(post.s) == "table" then
				local rig = buildRig(key, post.s)
				if rig and f.Parent and player.Parent then rig:Clone().Parent = f end
			end
		end
	end)
end

--------------------------------------------------
-- actions
--------------------------------------------------
local function list(player: Player, sort: any, page: any): (boolean, any)
	if typeof(sort) ~= "string" or not SORTS[sort] then return false, "Invalid sort." end
	if sort == "Hidden" and not isOwner(player) then return false, "Invalid sort." end
	local w = cooldown(player, "list", LIST_EVERY)
	if w then task.wait(w) end
	page = if typeof(page) == "number" then math.clamp(math.floor(page), 1, 50) else 1
	local keys = readList(sort)
	local liked = likedBy(player)
	local out, shownKeys = {}, {}
	local from = (page - 1) * PAGE + 1
	local reads = {}
	for i = from, math.min(#keys, from + PAGE - 1) do table.insert(reads, keys[i]) end
	local posts: {[number]: any} = {}
	local pending = #reads
	for i, key in ipairs(reads) do
		task.spawn(function()
			posts[i] = readPost(key)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 10 do waited += task.wait(0.05) end
	for i, key in ipairs(reads) do
		local post = posts[i]
		if post and (sort == "Hidden" or not post.hidden) then
			table.insert(out, card(post, player, liked))
			table.insert(shownKeys, key)
		end
	end
	sendRigs(player, shownKeys, page == 1)
	return true, { cards = out, more = #keys >= from + PAGE, owner = isOwner(player) }
end

local function filterTitle(player: Player, text: string): (boolean, string)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		if RunService:IsStudio() then return true, text end -- (test players: negative ids)
		return false, "지금은 글을 확인할 수 없어요. 잠시 후 다시 시도하세요."
	end
	if result ~= text then return false, "쓸 수 없는 말이 들어 있어요. 제목을 바꿔 주세요." end
	return true, result
end

-- the items a post shows for 사기: only what the player wears now (assets) or a bundle that has
-- a worn part; with prices (0 = not for sale)
local function checkItems(entries: any, description: HumanoidDescription): {any}
	local present = OutfitSnapshot.presentAssetIds(description)
	local out, seen = {}, {}
	if typeof(entries) ~= "table" then return out end
	local checks = {}
	for _, e in ipairs(entries) do
		if #checks >= ITEMS_MAX then break end
		if typeof(e) == "table" and typeof(e.id) == "number" and e.id > 0 and (e.itemType == "Asset" or e.itemType == "Bundle") then
			local k = e.itemType .. e.id
			if not seen[k] then
				seen[k] = true
				table.insert(checks, { kind = e.itemType, id = e.id })
			end
		end
	end
	local results: {[number]: any} = {}
	local pending = #checks
	for i, e in ipairs(checks) do
		task.spawn(function()
			local good = false
			if e.kind == "Asset" then
				good = present[e.id] == true
			else
				local ok, details = pcall(function() return AssetService:GetBundleDetailsAsync(e.id) end)
				if ok and typeof(details) == "table" then
					for _, item in ipairs(details.Items or {}) do
						if item.Type == "Asset" and present[item.Id] then good = true break end
					end
				end
			end
			if good then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(e.id, if e.kind == "Bundle" then Enum.InfoType.Bundle else Enum.InfoType.Asset)
				end)
				local price = 0
				if ok and typeof(info) == "table" and info.IsForSale and typeof(info.PriceInRobux) == "number" then price = info.PriceInRobux end
				results[i] = { kind = e.kind, id = e.id, price = price }
			end
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 15 do waited += task.wait(0.05) end
	for i = 1, #checks do
		if results[i] then table.insert(out, results[i]) end
	end
	return out
end

-- (ok, card | message); snapshot = AvatarService.CaptureSnapshot, description = the applied one
function Service.post(player: Player, payload: any, snapshot: any, description: HumanoidDescription): (boolean, any)
	if typeof(payload) ~= "table" then return false, "Invalid post." end
	local title = if typeof(payload.title) == "string" then string.gsub(string.gsub(payload.title, "[%c]", " "), "^%s*(.-)%s*$", "%1") else ""
	if title == "" then title = player.DisplayName .. "의 코디" end
	local len = utf8.len(title)
	if not len then return false, "제목을 다시 써 주세요." end
	if len > TITLE_MAX then return false, string.format("제목은 %d자까지예요.", TITLE_MAX) end
	local w = cooldown(player, "post", POST_EVERY)
	if w then return false, string.format("%d초 뒤에 다시 올릴 수 있어요.", math.ceil(w)) end
	local ds = main()
	if not ds then last["post" .. player.UserId] = nil return false, "지금은 올릴 수 없어요. 잠시 후 다시 시도하세요." end
	local okTitle, filtered = filterTitle(player, title)
	if not okTitle then last["post" .. player.UserId] = nil return false, filtered end
	local items = checkItems(payload.entries, description)
	local total = 0
	for _, item in ipairs(items) do total += item.price end
	local okId, id = pcall(function()
		return (ds :: DataStore):UpdateAsync("next", function(old) return (if typeof(old) == "number" then old else 0) + 1 end)
	end)
	if not okId or typeof(id) ~= "number" then last["post" .. player.UserId] = nil return false, "올리지 못했어요. 잠시 후 다시 시도하세요." end
	local now = os.time()
	local post = {
		id = id, by = player.UserId, name = player.DisplayName, title = filtered, s = snapshot,
		items = items, price = total, at = now, likes = 0, reports = 0, hidden = false,
	}
	local key = "p" .. id
	local okSet = pcall(function() (ds :: DataStore):SetAsync(key, post, { player.UserId }) end)
	if not okSet then last["post" .. player.UserId] = nil return false, "올리지 못했어요. 잠시 후 다시 시도하세요." end
	pcall(function() storeOf(SORTS.New, true):SetAsync(key, now) end)
	pcall(function() storeOf(SORTS.Top, true):SetAsync(key, 0) end)
	postCache[key] = { post = post, t = os.clock() }
	local newest = listCache.New
	if newest then table.insert(newest.keys, 1, key) end
	local top = listCache.Top
	if top then table.insert(top.keys, key) end
	return true, card(post, player, likedBy(player))
end

local function validKey(key: any): boolean
	return typeof(key) == "string" and #key <= 20 and string.match(key, "^p%d+$") ~= nil
end

function Service.snapshotOf(key: any): any
	if not validKey(key) then return nil end
	local post = readPost(key)
	if not post or post.hidden then return nil end
	return post.s
end

local function like(player: Player, key: any): (boolean, any)
	if not validKey(key) then return false, "Invalid post." end
	if cooldown(player, "act", ACT_EVERY) then return false, "잠시 후 다시 시도하세요." end
	local ds = main()
	if not ds then return false, "지금은 할 수 없어요." end
	local post = readPost(key)
	if not post or post.hidden then return false, "없는 코디예요." end
	local delta = 0
	local ok = pcall(function()
		(ds :: DataStore):UpdateAsync("u" .. player.UserId, function(old)
			local set = if typeof(old) == "table" then old else {}
			if set[key] then set[key] = nil delta = -1 else set[key] = true delta = 1 end
			likedCache[player.UserId] = set
			return set
		end)
	end)
	if not ok then return false, "지금은 할 수 없어요." end
	local likes = post.likes or 0
	pcall(function()
		(ds :: DataStore):UpdateAsync(key, function(old)
			if typeof(old) ~= "table" then return nil end
			old.likes = math.max(0, (old.likes or 0) + delta)
			likes = old.likes
			postCache[key] = { post = old, t = os.clock() }
			return old
		end)
	end)
	if not post.hidden then pcall(function() storeOf(SORTS.Top, true):SetAsync(key, likes) end) end
	return true, { liked = delta > 0, likes = likes }
end

local function hide(key: string, hidden: boolean)
	pcall(function()
		if hidden then
			storeOf(SORTS.New, true):RemoveAsync(key)
			storeOf(SORTS.Top, true):RemoveAsync(key)
			storeOf(SORTS.Hidden, true):SetAsync(key, os.time())
		else
			local post = readPost(key, true)
			storeOf(SORTS.Hidden, true):RemoveAsync(key)
			if post then
				storeOf(SORTS.New, true):SetAsync(key, post.at or os.time())
				storeOf(SORTS.Top, true):SetAsync(key, post.likes or 0)
			end
		end
	end)
	listCache = {}
end

local function report(player: Player, key: any): (boolean, any)
	if not validKey(key) then return false, "Invalid post." end
	if cooldown(player, "act", ACT_EVERY) then return false, "잠시 후 다시 시도하세요." end
	local ds = main()
	if not ds then return false, "지금은 할 수 없어요." end
	local post = readPost(key)
	if not post then return false, "없는 코디예요." end
	if post.by == player.UserId then return false, "내 코디는 신고할 수 없어요." end
	local added, count = false, 0
	local ok = pcall(function()
		(ds :: DataStore):UpdateAsync("r" .. string.sub(key, 2), function(old)
			local set = if typeof(old) == "table" then old else {}
			local k = tostring(player.UserId)
			if set[k] then added = false else set[k] = true added = true end
			count = 0
			for _ in pairs(set) do count += 1 end
			return set
		end)
	end)
	if not ok then return false, "지금은 할 수 없어요." end
	if not added then return true, { already = true } end
	local nowHidden = false
	pcall(function()
		(ds :: DataStore):UpdateAsync(key, function(old)
			if typeof(old) ~= "table" then return nil end
			old.reports = count
			if count >= REPORTS_TO_HIDE and not old.hidden then old.hidden = true nowHidden = true end
			postCache[key] = { post = old, t = os.clock() }
			return old
		end)
	end)
	if nowHidden then hide(key, true) else forget(key) end
	print(string.format("[CommunityLooks] report %s by %d (%d)%s", key, player.UserId, count, if nowHidden then " → hidden" else ""))
	return true, { hidden = nowHidden }
end

local function remove(player: Player, key: any): (boolean, any)
	if not validKey(key) then return false, "Invalid post." end
	if cooldown(player, "act", ACT_EVERY) then return false, "잠시 후 다시 시도하세요." end
	local ds = main()
	if not ds then return false, "지금은 할 수 없어요." end
	local post = readPost(key, true)
	if not post then forget(key) return true end
	if post.by ~= player.UserId and not isOwner(player) then return false, "내 코디만 지울 수 있어요." end
	local ok = pcall(function() (ds :: DataStore):RemoveAsync(key) end)
	if not ok then return false, "지우지 못했어요. 잠시 후 다시 시도하세요." end
	pcall(function() (ds :: DataStore):RemoveAsync("r" .. string.sub(key, 2)) end)
	for _, name in pairs(SORTS) do pcall(function() storeOf(name, true):RemoveAsync(key) end) end
	postCache[key] = nil
	forget(key)
	return true
end

local function unhide(player: Player, key: any): (boolean, any)
	if not validKey(key) or not isOwner(player) then return false, "Invalid post." end
	local ds = main()
	if not ds then return false, "지금은 할 수 없어요." end
	local ok = pcall(function()
		(ds :: DataStore):UpdateAsync(key, function(old)
			if typeof(old) ~= "table" then return nil end
			old.hidden = false
			postCache[key] = { post = old, t = os.clock() }
			return old
		end);
		(ds :: DataStore):RemoveAsync("r" .. string.sub(key, 2))
	end)
	if not ok then return false, "지금은 할 수 없어요." end
	hide(key, false)
	return true
end

function Service.Start()
	local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("CommunityLooks") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
		if action == "List" then return list(player, a, b) end
		if action == "Like" then return like(player, a) end
		if action == "Report" then return report(player, a) end
		if action == "Delete" then return remove(player, a) end
		if action == "Unhide" then return unhide(player, a) end
		return false, "Invalid action."
	end
	Players.PlayerRemoving:Connect(function(player)
		likedCache[player.UserId] = nil
		for _, what in ipairs({ "list", "post", "act" }) do last[what .. player.UserId] = nil end
	end)
end

return Service
