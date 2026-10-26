--!nocheck
-- Whole-map backup and restore in the place itself (2026-10-27, before the
-- layout v8 rework). Run in Edit mode.
--   MODE "backup"  (default) copies Workspace.Graybox_MainSocial, Hongdae_Layout,
--                  StreetDress and the layout's ServerStorage folders into
--                  ServerStorage.MapBackup_<name>; CollectionService tags of the
--                  copies are parked in the attribute BackupTags (copies in
--                  ServerStorage with live tags confuse services, D-094).
--   MODE "restore" puts that copy back (the current map is moved aside into
--                  ServerStorage.MapBroken_<time> first, never deleted).
--   MODE "list"    names the backups.
-- The code side is a git tag (backup/pre-layout-v8); rebuilding from that tag's
-- scripts gives the same map too.
local MODE, NAME = ...
MODE = MODE or "backup"
NAME = NAME or "pre_layout_v8"
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local WS_FOLDERS = { "Graybox_MainSocial", "Hongdae_Layout", "StreetDress" }
local SS_FOLDERS = { "Hongdae_v1_HiddenParts", "PropOverrides", "PropRegistry" }

local function parkTags(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		local tags = CS:GetTags(d)
		if #tags > 0 then
			d:SetAttribute("BackupTags", table.concat(tags, ","))
			for _, t in ipairs(tags) do CS:RemoveTag(d, t) end
		end
	end
end
local function unparkTags(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		local s = d:GetAttribute("BackupTags")
		if typeof(s) == "string" then
			for t in string.gmatch(s, "[^,]+") do CS:AddTag(d, t) end
			d:SetAttribute("BackupTags", nil)
		end
	end
end

if MODE == "list" then
	local names = {}
	for _, c in ipairs(SS:GetChildren()) do
		if string.match(c.Name, "^MapBackup_") or string.match(c.Name, "^MapBroken_") then table.insert(names, c.Name) end
	end
	return table.concat(names, ", ")
end

local folderName = "MapBackup_" .. NAME
if MODE == "backup" then
	local old = SS:FindFirstChild(folderName)
	if old then old:Destroy() end
	local b = Instance.new("Folder")
	b.Name = folderName
	b:SetAttribute("SavedAt", os.date("%Y-%m-%d %H:%M"))
	local ws, ss = Instance.new("Folder"), Instance.new("Folder")
	ws.Name, ss.Name = "Workspace", "ServerStorage"
	ws.Parent, ss.Parent = b, b
	local n = 0
	for _, name in ipairs(WS_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then
			local c = f:Clone()
			parkTags(c)
			c.Parent = ws
			n += #c:GetDescendants()
			task.wait()
		end
	end
	for _, name in ipairs(SS_FOLDERS) do
		local f = SS:FindFirstChild(name)
		if f then
			local c = f:Clone()
			parkTags(c)
			c.Parent = ss
		end
	end
	b.Parent = SS
	return "backed up " .. n .. " instances into ServerStorage." .. folderName
elseif MODE == "restore" then
	local b = SS:FindFirstChild(folderName)
	if not b then return "no backup " .. folderName end
	local broken = Instance.new("Folder")
	broken.Name = "MapBroken_" .. os.date("%H%M%S")
	broken.Parent = SS
	for _, name in ipairs(WS_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then parkTags(f) f.Parent = broken end
		local c = b.Workspace:FindFirstChild(name)
		if c then
			c = c:Clone()
			unparkTags(c)
			c.Parent = workspace
			task.wait()
		end
	end
	for _, name in ipairs(SS_FOLDERS) do
		local f = SS:FindFirstChild(name)
		if f then f.Parent = broken end
		local c = b.ServerStorage:FindFirstChild(name)
		if c then
			c = c:Clone()
			unparkTags(c)
			c.Parent = SS
		end
	end
	return "restored " .. folderName .. " (the replaced map is in ServerStorage." .. broken.Name .. ")"
end
return "unknown mode"
