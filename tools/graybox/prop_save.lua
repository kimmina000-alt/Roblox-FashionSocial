-- Save hand edits of street props (D-105, user 2026-10-22: "풀·나무·가로등을
-- 하나 선택해서 지우거나 조금 옮기고 싶다").
-- Every generated prop (tree, shrub, grass, planter bed, car, street light,
-- utility pole, traffic light, bus shelter) carries attributes PropId and
-- PropBase (where the script put it). Run this in Edit mode after moving or
-- deleting props by hand: it writes the differences to
-- ServerStorage.PropOverrides (JSON). hongdae_v1_temp.lua and street_dress.lua
-- apply them again on every rebuild. The JSON is also returned, so it can be
-- kept in git as tools/graybox/prop_overrides.json.
--   MODE "save" (default) | "clear" (forget every hand edit) | "restore <id>"
local arg = ... or "save"
local SS = game:GetService("ServerStorage")
local HS = game:GetService("HttpService")

local function jsonValue(name: string): {[string]: any}
	local v = SS:FindFirstChild(name)
	if v and v:IsA("StringValue") and v.Value ~= "" then
		local ok, t = pcall(function() return HS:JSONDecode(v.Value) end)
		if ok and typeof(t) == "table" then return t end
	end
	return {}
end
local function write(t)
	local v = SS:FindFirstChild("PropOverrides") or Instance.new("StringValue")
	v.Name = "PropOverrides"
	v.Value = HS:JSONEncode(t)
	v.Parent = SS
	return v.Value
end

local overrides = jsonValue("PropOverrides")
if arg == "clear" then
	write({})
	return "all hand edits forgotten (re-run the street scripts to see the generated layout)"
end
local restoreId = string.match(arg, "^restore (.+)$")
if restoreId then
	overrides[restoreId] = nil
	write(overrides)
	return restoreId .. " restored (re-run the street scripts to bring it back)"
end

local registry = jsonValue("PropRegistry")
local present: {[string]: Instance} = {}
for _, d in ipairs(workspace:GetDescendants()) do
	local id = d:GetAttribute("PropId")
	if typeof(id) == "string" then present[id] = d end
end
-- only judge props whose script output is in the world right now
local live = {
	temp = workspace:FindFirstChild("Hongdae_v1_Temp") ~= nil,
	dress = workspace:FindFirstChild("StreetDress") ~= nil,
}

local moved, deleted, kept = 0, 0, 0
for id, owner in pairs(registry) do
	if live[owner] then
		local d = present[id]
		if not d then
			overrides[id] = "delete"
			deleted += 1
		else
			local base = d:GetAttribute("PropBase")
			local cur = if d:IsA("Model") then d:GetPivot() else (d :: BasePart).CFrame
			if typeof(base) == "CFrame" and ((cur.Position - base.Position).Magnitude > 0.05
				or cur.LookVector:Dot(base.LookVector) < 0.9999 or cur.UpVector:Dot(base.UpVector) < 0.9999) then
				overrides[id] = { cur:GetComponents() }
				moved += 1
			elseif overrides[id] ~= nil and typeof(overrides[id]) == "table" then
				-- moved back to where the script puts it: no override needed
				if typeof(base) == "CFrame" and (cur.Position - base.Position).Magnitude <= 0.05 then overrides[id] = nil end
			end
			if overrides[id] ~= nil then kept += 1 end
		end
	end
end
local json = write(overrides)
local total = 0
for _ in pairs(overrides) do total += 1 end
return string.format("saved: %d moved, %d deleted (%d overrides in total)\n%s", moved, deleted, total, json)
