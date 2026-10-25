--!strict
-- 좋아요 / 싫어요 on avatar pictures shown in the city (user 2026-10-25,
-- D-281): bus stop ads and the "오늘의 큰손" cards on the OH24 roof block.
--
--   * A picture is hidden (only the @username is shown) when it has at least
--     HIDE_DISLIKES dislikes AND more dislikes than likes.
--   * One vote per person per picture (like or dislike, can be changed or
--     taken back); not on your own picture; only players with at least
--     MIN_PLAY_MINUTES of play time (any player in Studio).
--   * Votes belong to one version of the picture (outfit + pose): when the
--     owner retakes it the votes start again from 0.
--   * Votes are shared by all servers (DataStore "LookVotes").
--   * When a picture becomes hidden, its owner is told (if online).
--
-- Kinds register a resolver: id → owner userId and the picture's version.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")

local VoteService = {}

local HIDE_DISLIKES = 5
local MIN_PLAY_MINUTES = 30

type Record = { v: string, likes: {[string]: boolean}, dislikes: {[string]: boolean} }
type Resolver = (id: string) -> (number?, string?)

local store: DataStore? = nil
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore("LookVotes") end)
	if ok then store = s end
end

local records: {[string]: Record} = {}
local loading: {[string]: boolean} = {}
local resolvers: {[string]: Resolver} = {}
local hiddenMessages: {[string]: string} = {}
local changeListeners: {() -> ()} = {}
local playMinutes: (userId: number) -> number = function() return 0 end

-- Short stable hash of any data (the picture's version).
function VoteService.Version(data: any): string
	local ok, text = pcall(function() return HttpService:JSONEncode(data) end)
	text = if ok then text else tostring(data)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function count(set: {[string]: boolean}): number
	local n = 0
	for _ in pairs(set) do n += 1 end
	return n
end

local function isHidden(likes: number, dislikes: number): boolean
	return dislikes >= HIDE_DISLIKES and dislikes > likes
end

-- Loads the record from the data store once (in the background).
local function load(target: string)
	if records[target] or loading[target] or not store then return end
	loading[target] = true
	task.spawn(function()
		local ok, value = pcall(function() return (store :: DataStore):GetAsync(target) end)
		if ok and typeof(value) == "table" and typeof(value.v) == "string" then
			records[target] = { v = value.v, likes = value.likes or {}, dislikes = value.dislikes or {} }
			for _, listener in ipairs(changeListeners) do task.spawn(listener) end
		end
		loading[target] = nil
	end)
end

-- { likes, dislikes, hidden } of a picture version (0 / false for a new version).
function VoteService.State(kind: string, id: string, version: string): { likes: number, dislikes: number, hidden: boolean }
	local target = kind .. ":" .. id
	local record = records[target]
	if not record then
		load(target)
		return { likes = 0, dislikes = 0, hidden = false }
	end
	if record.v ~= version then return { likes = 0, dislikes = 0, hidden = false } end
	local likes, dislikes = count(record.likes), count(record.dislikes)
	return { likes = likes, dislikes = dislikes, hidden = isHidden(likes, dislikes) }
end

-- This player's vote on a picture: "like", "dislike" or nil.
function VoteService.MyVote(player: Player, kind: string, id: string, version: string): string?
	local record = records[kind .. ":" .. id]
	if not record or record.v ~= version then return nil end
	local key = tostring(player.UserId)
	if record.likes[key] then return "like" end
	if record.dislikes[key] then return "dislike" end
	return nil
end

function VoteService.Register(kind: string, resolver: Resolver, hiddenMessage: string)
	resolvers[kind] = resolver
	hiddenMessages[kind] = hiddenMessage
end

function VoteService.OnChange(listener: () -> ())
	table.insert(changeListeners, listener)
end

function VoteService.SetPlayMinutes(reader: (userId: number) -> number)
	playMinutes = reader
end

local function apply(record: Record, voter: string, value: string?)
	record.likes[voter] = nil
	record.dislikes[voter] = nil
	if value == "like" then record.likes[voter] = true end
	if value == "dislike" then record.dislikes[voter] = true end
end

-- ClubShop "Vote": payload = { kind, id, value = "like" | "dislike" | nil }
function VoteService.Vote(player: Player, payload: any): (boolean, any)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" or typeof(payload.id) ~= "string" then
		return false, "잘못된 요청입니다."
	end
	local resolver = resolvers[payload.kind]
	if not resolver then return false, "잘못된 요청입니다." end
	local value = if payload.value == "like" or payload.value == "dislike" then payload.value else nil
	local owner, version = resolver(payload.id)
	if not owner or not version then return false, "지금은 투표할 수 없어요." end
	if owner == player.UserId then return false, "내 사진에는 투표할 수 없어요." end
	if not RunService:IsStudio() and playMinutes(player.UserId) < MIN_PLAY_MINUTES then
		return false, string.format("플레이 시간 %d분이 지나면 투표할 수 있어요.", MIN_PLAY_MINUTES)
	end
	local target = payload.kind .. ":" .. payload.id
	local voter = tostring(player.UserId)
	local before = VoteService.State(payload.kind, payload.id, version).hidden
	local function change(old: any): Record
		local record: Record = if typeof(old) == "table" and old.v == version
			then { v = version, likes = old.likes or {}, dislikes = old.dislikes or {} }
			else { v = version, likes = {}, dislikes = {} }
		apply(record, voter, value)
		return record
	end
	local saved: Record? = nil
	if store then
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(target, change)
		end)
		if ok and typeof(result) == "table" then saved = result end
	end
	records[target] = saved or change(records[target])
	local state = VoteService.State(payload.kind, payload.id, version)
	if state.hidden and not before then
		local ownerPlayer = Players:GetPlayerByUserId(owner)
		local notify = FashionGame:FindFirstChild("Remotes") and FashionGame.Remotes:FindFirstChild("ClubNotify")
		if ownerPlayer and notify and notify:IsA("RemoteEvent") then
			notify:FireClient(ownerPlayer, "Toast", hiddenMessages[payload.kind] or "")
		end
	end
	for _, listener in ipairs(changeListeners) do task.spawn(listener) end
	return true, { likes = state.likes, dislikes = state.dislikes, hidden = state.hidden, mine = value }
end

-- Forget pictures that are gone (keeps memory small on long servers).
function VoteService.Forget(kind: string, id: string)
	records[kind .. ":" .. id] = nil
end

return VoteService
