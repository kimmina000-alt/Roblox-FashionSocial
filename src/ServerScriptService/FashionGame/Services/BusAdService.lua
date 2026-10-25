--!strict
-- Bus stop ad boards (user 2026-10-25, D-279, CLUB_SHOP_PRICING.md §13.6):
-- the 4 bus stops have 2 ad panels each (tag "BusAd", attribute Slot). A
-- player buys a panel for 24 hours (49 R$) or 3 days (99 R$); it then shows
-- their @username and their avatar in the outfit they wear, in a pose they
-- pick (like one shot of the photo booth: outfit + dance clip + time, drawn
-- on each client, never an uploaded image).
--
--   * One ad per panel; buying a panel that is taken puts the buyer in its
--     queue (their time starts when the current ad ends). Buying your own
--     running ad again adds the time.
--   * The ads are shared by all servers (DataStore "BusAds", one document),
--     re-read every minute and sent to clients as the FashionGame attribute
--     "BusAds" (JSON).
--   * The owner may retake the photo (outfit + pose) while the ad runs.
--   * The game's owner (and anyone in Studio) can take an ad down.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local MonetizationService = require(script.Parent.MonetizationService)
local AvatarService = require(script.Parent.AvatarService)
local VoteService = require(script.Parent.VoteService)

local BusAdService = {}

local DAY = 24 * 3600
local PRODUCTS = { BusAd1D = 1, BusAd3D = 3 } -- product key → days
local REFRESH_SECONDS = 60

type Ad = { u: number, n: string, o: any, k: string?, t: number?, untilTime: number }
type Queued = { u: number, n: string, o: any, days: number }
type Slot = { ad: Ad?, q: {Queued} }

local store: DataStore? = nil
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore("BusAds") end)
	if ok then store = s end
end

local slots: {[string]: Slot} = {}
local pendingSlot: {[number]: string} = {}
local notify: RemoteEvent? = nil

local function toast(player: Player, message: string)
	if notify then notify:FireClient(player, "Toast", message) end
end

local function validSlot(id: any): boolean
	if typeof(id) ~= "string" then return false end
	for _, panel in ipairs(CollectionService:GetTagged("BusAd")) do
		if panel:GetAttribute("Slot") == id then return true end
	end
	return false
end

-- Ends finished ads and starts the next one in each queue.
local function advance(all: {[string]: Slot}): boolean
	local now = os.time()
	local changed = false
	for _, slot in pairs(all) do
		if slot.ad and slot.ad.untilTime <= now then
			slot.ad = nil
			changed = true
		end
		if not slot.ad and #slot.q > 0 then
			local nextOne = table.remove(slot.q, 1) :: Queued
			slot.ad = { u = nextOne.u, n = nextOne.n, o = nextOne.o, untilTime = now + nextOne.days * DAY }
			changed = true
		end
	end
	return changed
end

-- the picture's version for 좋아요 / 싫어요 (a retaken photo starts at 0, D-281)
local function adVersion(ad: Ad): string
	return VoteService.Version({ ad.u, ad.o, ad.k, ad.t })
end

local function publish()
	local shown = {}
	for id, slot in pairs(slots) do
		if slot.ad then
			local votes = VoteService.State("busad", id, adVersion(slot.ad))
			shown[id] = { u = slot.ad.u, n = slot.ad.n, o = slot.ad.o, k = slot.ad.k, t = slot.ad.t,
				untilTime = slot.ad.untilTime, queue = #slot.q,
				likes = votes.likes, dislikes = votes.dislikes, hidden = votes.hidden }
		elseif #slot.q > 0 then
			shown[id] = { queue = #slot.q }
		end
	end
	FashionGame:SetAttribute("BusAds", HttpService:JSONEncode(shown))
end

-- Applies `change` to the shared document (UpdateAsync) and to this server.
local function update(change: (all: {[string]: Slot}) -> ())
	if store then
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync("slots", function(old)
				local all: {[string]: Slot} = if typeof(old) == "table" then old else {}
				for id in pairs(slots) do all[id] = all[id] or { q = {} } end
				for _, slot in pairs(all) do slot.q = slot.q or {} end
				advance(all)
				change(all)
				return all
			end)
		end)
		if ok and typeof(result) == "table" then
			slots = result
			publish()
			return
		end
	end
	-- no data store (Studio): this server only
	advance(slots)
	change(slots)
	publish()
end

local function refresh()
	if store then
		local ok, value = pcall(function() return (store :: DataStore):GetAsync("slots") end)
		if ok and typeof(value) == "table" then
			for id, slot in pairs(value) do
				slot.q = slot.q or {}
				slots[id] = slot
			end
		end
	end
	advance(slots)
	publish()
end

local function snapshotOf(player: Player): any
	local ok, snapshot = AvatarService.CaptureSnapshot(player)
	return if ok then snapshot else nil
end

local function grant(player: Player, days: number): (boolean, string?)
	local id = pendingSlot[player.UserId]
	if not id then return false, "광고 자리를 다시 골라 주세요." end
	local outfit = snapshotOf(player)
	local message = ""
	local live = false -- (the photo can be taken right away only when the ad is up)
	update(function(all)
		local slot = all[id] or { q = {} }
		all[id] = slot
		if slot.ad and slot.ad.u == player.UserId then
			slot.ad.untilTime += days * DAY
			message = "📰 내 광고 시간이 늘어났어요!"
			live = true
		elseif slot.ad then
			table.insert(slot.q, { u = player.UserId, n = player.Name, o = outfit, days = days })
			message = string.format("📰 지금 광고가 끝나면 내 광고가 걸려요 (대기 %d번째).", #slot.q)
		else
			slot.ad = { u = player.UserId, n = player.Name, o = outfit, untilTime = os.time() + days * DAY }
			message = "📰 광고가 걸렸어요! 포즈를 골라 사진을 찍어 주세요."
			live = true
		end
	end)
	toast(player, message)
	if notify and live then notify:FireClient(player, "BusAdBought", id) end
	return true, nil
end

local function isAdmin(player: Player): boolean
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

-- This player's vote on a slot's current ad ("like" / "dislike" / nil).
function BusAdService.MyVote(player: Player, id: any): string?
	local slot = typeof(id) == "string" and slots[id]
	if not slot or not slot.ad then return nil end
	return VoteService.MyVote(player, "busad", id, adVersion(slot.ad))
end

-- ClubShop actions. Returns ok, result, handled.
function BusAdService.Handle(player: Player, action: string, payload: any): (boolean, any, boolean)
	if action == "BusAdSelect" then
		if not validSlot(payload) then return false, "광고 자리를 찾을 수 없어요.", true end
		pendingSlot[player.UserId] = payload
		return true, nil, true
	elseif action == "BusAdPose" then
		-- payload = { slot, k = dance key or nil, t = time in the clip }
		if typeof(payload) ~= "table" or not validSlot(payload.slot) then return false, "광고 자리를 찾을 수 없어요.", true end
		local slot = slots[payload.slot]
		if not slot or not slot.ad or slot.ad.u ~= player.UserId then return false, "내 광고가 아니에요.", true end
		local key = if typeof(payload.k) == "string" and ClubConfig.findDance(payload.k) then payload.k else nil
		local t = if typeof(payload.t) == "number" and payload.t == payload.t then math.clamp(payload.t, 0, 60) else 0
		local outfit = snapshotOf(player)
		update(function(all)
			local s = all[payload.slot]
			if s and s.ad and s.ad.u == player.UserId then
				s.ad.k = key
				s.ad.t = t
				if outfit then s.ad.o = outfit end
			end
		end)
		return true, "📸 광고 사진을 바꿨어요!", true
	elseif action == "BusAdRemove" then
		if not isAdmin(player) or not validSlot(payload) then return false, "내릴 수 없어요.", true end
		update(function(all)
			if all[payload] then all[payload].ad = nil end
		end)
		return true, "광고를 내렸어요.", true
	end
	return false, nil, false
end

function BusAdService.Start()
	notify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent
	local function addPanel(panel: Instance)
		if not panel:IsA("BasePart") or not panel:IsDescendantOf(workspace) then return end
		local id = panel:GetAttribute("Slot")
		if typeof(id) ~= "string" then return end
		slots[id] = slots[id] or { q = {} }
		if not panel:FindFirstChild("BusAdPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BusAdPrompt"
			prompt.ActionText = "광고판"
			prompt.ObjectText = tostring(panel:GetAttribute("StopName") or "버스 정류장")
			prompt.KeyboardKeyCode = Enum.KeyCode.G
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = panel
		end
	end
	for _, panel in ipairs(CollectionService:GetTagged("BusAd")) do addPanel(panel) end
	CollectionService:GetInstanceAddedSignal("BusAd"):Connect(addPanel)
	for key, days in pairs(PRODUCTS) do
		MonetizationService.RegisterProduct(key, function(player)
			return grant(player, days)
		end)
	end
	VoteService.Register("busad", function(id)
		local slot = slots[id]
		if not slot or not slot.ad then return nil, nil end
		return slot.ad.u, adVersion(slot.ad)
	end, "📰 싫어요가 많아 광고 사진이 가려지고 아이디만 보여요. 광고판에서 포즈나 코디를 바꿔 다시 찍으면 표가 새로 시작돼요.")
	VoteService.OnChange(publish)
	Players.PlayerRemoving:Connect(function(player) pendingSlot[player.UserId] = nil end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return BusAdService
