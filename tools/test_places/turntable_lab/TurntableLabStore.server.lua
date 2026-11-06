-- Turntable sound lab (user 2026-11-01): the mixer values saved per track,
-- so they are back on the next Play. One shared table for the place (it is
-- a one-person test lab), DataStore "TurntableLabSettings" key "v1":
-- { ["<soundId>"] = { speed = .., tempo = .., ..., engine = "sound" } }.
-- Needs Game Settings → Security → Enable Studio Access to API Services.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KEYS = { "speed", "tempo", "volume", "boost", "boost2", "boost3", "boost4", "octave", "low", "mid", "high", "humHz", "hissHz", "gate" }
local store = DataStoreService:GetDataStore("TurntableLabSettings")

local remote = Instance.new("RemoteFunction")
remote.Name = "TurntableLabStore"
remote.Parent = ReplicatedStorage

local function clean(data: any): {[string]: any}?
	if typeof(data) ~= "table" then return nil end
	local out = {}
	for _, k in ipairs(KEYS) do
		local v = data[k]
		if typeof(v) == "number" and v == v and math.abs(v) < 1e6 then out[k] = v end
	end
	out.engine = if data.engine == "audio" then "audio" else "sound"
	return out
end

remote.OnServerInvoke = function(_player, action: any, id: any, data: any)
	if action == "load" then
		local ok, all = pcall(store.GetAsync, store, "v1")
		if not ok then return false, tostring(all) end
		return true, all or {}
	end
	if (action == "save" or action == "clear") and typeof(id) == "number" and id > 0 then
		local entry = if action == "save" then clean(data) else nil
		if action == "save" and not entry then return false, "bad data" end
		local ok, err = pcall(store.UpdateAsync, store, "v1", function(all)
			all = all or {}
			all[tostring(id)] = entry
			return all
		end)
		if not ok then return false, tostring(err) end
		return true
	end
	return false, "bad request"
end
