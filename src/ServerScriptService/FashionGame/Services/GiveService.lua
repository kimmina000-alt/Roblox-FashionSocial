--!strict
-- (D-1396, user 2026-11-14: "다른 사람한테 아이템 주는 기능" → picked: hold the item and tap the
-- person, the other one has to accept, every carried item) A player holding an item taps
-- another player near them: 🎁 주기 (GiveController) → Offer; the other one gets
-- "OO님이 OO을 주려고 해요 [받기] [괜찮아요]" for OFFER_SECONDS; 받기 → Accept.
-- The item is handed over the way the bag keeps items across a rejoin (BagService, D-790):
-- the giver's list is written down with and without the tool, the one entry that went is
-- made again for the receiver by its own service (bites left, cups left, sparkler count
-- stay), and the giver's tool goes. When the receiver's copy cannot be made, the giver gets
-- it back.
-- Giveable: snacks, plates (cake / 수육), club bottles and cups, sparklers, sparkler bucket
-- sets, hand sparklers. Not: 알바 order cups (CafeOrder), a lit sparkler, a cup while
-- drinking, the glowstick (a pass), photos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local BagService = require(script.Parent:WaitForChild("BagService"))

local GiveService = {}

local REACH = 16 -- studs: tap someone this near to give
local ACCEPT_REACH = 40 -- still this near when they accept
local OFFER_SECONDS = 15

local KINDS = { "Snack", "Plate", "Bottle", "Cup", "Sparkler", "SparklerSet", "HandSparkler" }

function GiveService.giveable(tool: Instance?): boolean
	if not tool or not tool:IsA("Tool") then return false end
	if tool:GetAttribute("CafeOrder") or tool:GetAttribute("Lit") or tool:GetAttribute("Drinking") then return false end
	local bites = tool:GetAttribute("Bites")
	if typeof(bites) == "number" and bites <= 0 then return false end
	for _, k in ipairs(KINDS) do
		if tool:GetAttribute(k) ~= nil then return true end
	end
	return false
end

type Offer = { id: string, giver: Player, target: Player, tool: Tool, name: string, at: number }
local byGiver: {[Player]: Offer} = {}
local byId: {[string]: Offer} = {}
local event: RemoteEvent? = nil
local lastCall: {[Player]: number} = {}

local function tell(player: Player, kind: string, ...: any)
	if event and player.Parent then (event :: RemoteEvent):FireClient(player, kind, ...) end
end

local function rootOf(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end
local function distance(a: Player, b: Player): number
	local ra, rb = rootOf(a), rootOf(b)
	return if ra and rb then (ra.Position - rb.Position).Magnitude else math.huge
end

local function drop(offer: Offer)
	if byGiver[offer.giver] == offer then byGiver[offer.giver] = nil end
	byId[offer.id] = nil
end

-- an entry as one string (the keys in order), to tell two lists apart
local function canon(e: any): string
	if typeof(e) ~= "table" then return tostring(e) end
	local keys = {}
	for k in pairs(e) do table.insert(keys, tostring(k)) end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do table.insert(parts, k .. "=" .. tostring(e[k])) end
	return table.concat(parts, ";")
end

-- the bag entry of this one tool: the giver's list with it minus the list without it
local function takeEntry(giver: Player, tool: Tool): any?
	local before = BagService.collect(giver)
	local parent = tool.Parent
	tool.Parent = nil
	local after = BagService.collect(giver)
	local left: {[string]: number} = {}
	for _, e in ipairs(after) do local c = canon(e) left[c] = (left[c] or 0) + 1 end
	local gone = {}
	for _, e in ipairs(before) do
		local c = canon(e)
		if (left[c] or 0) > 0 then left[c] -= 1 else table.insert(gone, e) end
	end
	if #gone ~= 1 then
		tool.Parent = parent
		return nil
	end
	return gone[1]
end

local function offer(giver: Player, target: any): (boolean, string?)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == giver or target.Parent ~= Players then
		return false, nil
	end
	local character = giver.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or not GiveService.giveable(tool) then return false, "줄 수 있는 아이템을 손에 들어 주세요." end
	if distance(giver, target) > REACH then return false, "더 가까이 가서 눌러 주세요." end
	local old = byGiver[giver]
	if old then
		drop(old)
		tell(old.target, "Withdrawn", old.id)
	end
	local o: Offer = { id = HttpService:GenerateGUID(false), giver = giver, target = target, tool = tool :: Tool, name = (tool :: Tool).Name, at = os.clock() }
	byGiver[giver] = o
	byId[o.id] = o
	tell(target, "Offer", o.id, giver.DisplayName, o.name, OFFER_SECONDS)
	task.delay(OFFER_SECONDS + 0.5, function()
		if byId[o.id] == o then
			drop(o)
			tell(target, "Withdrawn", o.id)
			tell(giver, "Result", "no", target.DisplayName, o.name)
		end
	end)
	return true, nil
end

local function respond(target: Player, id: any, accept: any): (boolean, string?)
	local o = if typeof(id) == "string" then byId[id] else nil
	if not o or o.target ~= target then return false, "이미 끝난 선물이에요." end
	drop(o)
	local giver = o.giver
	if accept ~= true then
		tell(giver, "Result", "no", target.DisplayName, o.name)
		return true, nil
	end
	local tool = o.tool
	local held = giver.Parent == Players and tool.Parent ~= nil
		and (tool.Parent == giver.Character or tool.Parent == giver:FindFirstChildOfClass("Backpack"))
	if not held or not GiveService.giveable(tool) then
		tell(giver, "Result", "gone", target.DisplayName, o.name)
		return false, "아이템이 이미 없어졌어요."
	end
	if distance(giver, target) > ACCEPT_REACH then return false, "너무 멀어졌어요. 가까이 가서 다시 받아 주세요." end
	local entry = takeEntry(giver, tool)
	if entry == nil then return false, "지금은 받을 수 없어요." end
	local count = #BagService.collect(target)
	tool:Destroy()
	BagService.give(target, { entry })
	if #BagService.collect(target) <= count then
		-- (could not be made for the receiver: back to the giver)
		BagService.give(giver, { entry })
		tell(giver, "Result", "fail", target.DisplayName, o.name)
		return false, "받지 못했어요. 아이템은 그대로 있어요."
	end
	tell(giver, "Result", "yes", target.DisplayName, o.name)
	return true, nil
end

function GiveService.Start()
	local remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("Give") :: RemoteFunction?
	if not remote then
		local r = Instance.new("RemoteFunction")
		r.Name = "Give"
		r.Parent = remotes
		remote = r
	end
	local ev = remotes:FindFirstChild("GiveEvent") :: RemoteEvent?
	if not ev then
		local e = Instance.new("RemoteEvent")
		e.Name = "GiveEvent"
		e.Parent = remotes
		ev = e
	end
	event = ev;
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, a: any, b: any)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.4 then return false, nil end
		lastCall[player] = now
		if action == "Offer" then return offer(player, a) end
		if action == "Respond" then return respond(player, a, b) end
		return false, nil
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
		for _, o in pairs(byId) do
			if o.giver == player or o.target == player then
				drop(o)
				if o.giver == player then tell(o.target, "Withdrawn", o.id) end
			end
		end
	end)
end

return GiveService
