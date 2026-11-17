--!strict
-- 가드 · VIP · DJ권 선물 (D-1768, user 2026-11-18: "가드, vip, dj 권 남한테 선물할 수 있게 해 줘 / 다른 플레이어
-- 눌렀을 때 따라추기 아이템 주기처럼 가드권 주기 vip권 주기 dj권 주기 추가").
-- A game pass cannot be handed over in Roblox, so a gift is its own Developer Product (GiftGuard /
-- GiftVIP / GiftDJ, MonetizationConfig.Products) that the giver buys:
--   1. the player card (GiftPassCard) asks "GiftTarget" { key, to } first: who gets it; checked here
--      (in this server, not the giver, a pass they do not have yet) and kept for the giver for 10 min;
--   2. the giver buys the product; its handler gives the gift to that player:
--      Guard / VIP → a gifted pass, kept in the receiver's wallet.gifted and counted as owning the pass
--      (MonetizationService.GrantGiftedPass); DJ → 30 min of DJ time (DjService.AddTime), as a DJ buy.
--   A receiver who left before the purchase finished gets it on the next visit (DataStore PassGifts_v1,
--   never written in Studio). Without a kept target (a server restart) the buyer keeps it themselves.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local GiftPassService = {}

GiftPassService.Kinds = {
	Guard = { product = "GiftGuard", name = "가드 패스" },
	VIP = { product = "GiftVIP", name = "VIP 패스" },
	DJ = { product = "GiftDJ", name = "DJ 30분" },
}

local data: any = nil
local monetization: any = nil
local dj: any = nil
local notify: RemoteEvent? = nil
local pending: {[Player]: { key: string, to: number, name: string, t: number }} = {}

local inbox: DataStore? = nil
do
	local ok, store = pcall(function() return DataStoreService:GetDataStore("PassGifts_v1") end)
	if ok then inbox = store end
end

local function toast(player: Player?, message: string)
	if player and player.Parent and notify then notify:FireClient(player, "Toast", message) end
end

local function owns(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

-- gives one gift to a player in this server
local function give(receiver: Player, key: string, fromName: string): (boolean, string?)
	if key == "Guard" or key == "VIP" then
		local wallet = data.Wallet(receiver)
		wallet.gifted = wallet.gifted or {}
		wallet.gifted[key] = true
		data.MarkDirty(receiver)
		monetization.GrantGiftedPass(receiver, key)
		toast(receiver, string.format("🎁 %s님이 %s를 선물했어요!", fromName, GiftPassService.Kinds[key].name))
		return true, nil
	elseif key == "DJ" then
		local ok, message = dj.AddTime(receiver)
		if not ok then return false, message end
		toast(receiver, string.format("🎁 %s님이 DJ 30분을 선물했어요! %s", fromName, message or ""))
		return true, nil
	end
	return false, nil
end

-- "GiftTarget": who the next gift of this kind goes to
function GiftPassService.Target(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.key) ~= "string" or typeof(payload.to) ~= "number" then return false, nil end
	local kind = GiftPassService.Kinds[payload.key]
	if not kind then return false, nil end
	local target = Players:GetPlayerByUserId(payload.to)
	if not target or target == player then
		toast(player, "선물할 사람을 찾을 수 없어요.")
		return false, nil
	end
	if payload.key ~= "DJ" and owns(target, payload.key) then
		toast(player, string.format("%s님은 이미 %s가 있어요.", target.DisplayName, kind.name))
		return false, nil
	end
	pending[player] = { key = payload.key, to = target.UserId, name = target.DisplayName, t = os.clock() }
	return true, nil
end

local function handler(key: string)
	return function(player: Player): (boolean, string?)
		local p = pending[player]
		local fresh = p ~= nil and p.key == key and os.clock() - p.t < 600
		if not fresh then
			-- (no target kept: a restart between the tap and the receipt) the buyer keeps it
			return give(player, key, player.DisplayName)
		end
		pending[player] = nil
		local receiver = Players:GetPlayerByUserId(p.to)
		if receiver then
			if key ~= "DJ" and owns(receiver, key) then
				-- (got it meanwhile) the buyer keeps it instead
				toast(player, string.format("%s님이 그새 %s를 갖게 되어 내가 받았어요.", receiver.DisplayName, GiftPassService.Kinds[key].name))
				return give(player, key, player.DisplayName)
			end
			local ok, message = give(receiver, key, player.DisplayName)
			if ok then toast(player, string.format("🎁 %s님에게 %s를 선물했어요!", receiver.DisplayName, GiftPassService.Kinds[key].name)) end
			return ok, message
		end
		-- left the server: kept for their next visit
		if RunService:IsStudio() or not inbox then return false, "받는 사람이 나갔어요." end
		local ok = pcall(function()
			(inbox :: DataStore):UpdateAsync(tostring(p.to), function(old)
				local list = if typeof(old) == "table" then old else {}
				table.insert(list, { k = key, f = player.DisplayName })
				return list
			end)
		end)
		if ok then toast(player, string.format("🎁 %s님이 다음에 들어오면 %s를 받아요.", p.name, GiftPassService.Kinds[key].name)) end
		return ok, nil
	end
end

local function onJoin(player: Player)
	task.spawn(function()
		local wallet = data.Wallet(player) -- (waits for the player's data)
		if not player.Parent or not wallet then return end
		for key in pairs(wallet.gifted or {}) do
			if key == "Guard" or key == "VIP" then monetization.GrantGiftedPass(player, key) end
		end
		if RunService:IsStudio() or not inbox then return end
		local got: {any} = {}
		pcall(function()
			(inbox :: DataStore):UpdateAsync(tostring(player.UserId), function(old)
				if typeof(old) ~= "table" or #old == 0 then return nil end
				got = old
				return {}
			end)
		end)
		for _, g in ipairs(got) do
			if typeof(g) == "table" and typeof(g.k) == "string" then
				give(player, g.k, if typeof(g.f) == "string" then g.f else "누군가")
			end
		end
	end)
end

function GiftPassService.Start(playerData: any, monetizationService: any, djService: any)
	data, monetization, dj = playerData, monetizationService, djService
	notify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent
	for key, kind in pairs(GiftPassService.Kinds) do
		if MonetizationConfig.Products[kind.product] then
			monetizationService.RegisterProduct(kind.product, handler(key))
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do onJoin(p) end
	Players.PlayerRemoving:Connect(function(p) pending[p] = nil end)
end

return GiftPassService
