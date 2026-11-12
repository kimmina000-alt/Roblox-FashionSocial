-- (D-1334, user 2026-11-13: "편의점 이거여야 함. 지금 수정 전 편의점 내부로 돌아갔어" /
-- "광화문 고치면서 다른 공간들은 바뀐 거 없는지 확인해") The user's hand edits in Studio
-- inside the chain's folders were lost when the layout chain ran again (2026-11-12 / -13).
-- The published version 317 (2026-11-12 02:21) still had them; its Hongdae_Layout was
-- compared part by part with the rebuilt one and the user's state was put back:
--   whole models: OH24Store, BigSpenderLED, ClubAnnex, Gukbap, OhuFourCuts, AmusementParkGate
--   (OpenSea, gone in 317, is kept since D-1335: the user wants the far sea; RemoveModels = "")
--   single parts: Ground / Sidewalk / BeachStep pieces, Promenade / BeachStepEdge strips,
--   ParkRaise.ParkPlatform (ParkPlatformNorth keeps the later edit, D-1327)
-- The copies live in ServerStorage.UserMapSnapshot (Models, AddParts, RemoveSigs,
-- attribute RemoveModels); this step puts them back after every chain run, so the
-- scripts' versions of these places are not used any more: change them by hand in
-- Studio and refresh the snapshot (see LAYOUT.md 3-25).
-- LAST step of the layout chain (after oh24_cold_off_1113). Idempotent.

local SS = game:GetService("ServerStorage")
local snap = SS:FindFirstChild("UserMapSnapshot")
assert(snap, "ServerStorage.UserMapSnapshot is missing")
local HL = workspace:WaitForChild("Hongdae_Layout")

-- the part signature the snapshot was made with (rotation ±180 / ±0 folded)
local function sig(p: BasePart): string
	local pos, sz, c = p.Position, p.Size, p.Color
	local _, ry = p.CFrame:ToOrientation()
	local y = math.deg(ry)
	if math.abs(math.abs(y) - 180) < 0.5 then y = 180 end
	if math.abs(y) < 0.5 then y = 0 end
	return string.format("%s|%.1f,%.1f,%.1f|%.1f,%.1f,%.1f|%d,%d,%d|%s|%.0f|%.2f", p.Name, pos.X, pos.Y, pos.Z,
		sz.X, sz.Y, sz.Z, c.R * 255, c.G * 255, c.B * 255, p.Material.Name, y, p.Transparency)
end

local log = {}
-- 1) whole models
for _, m in ipairs(snap.Models:GetChildren()) do
	for _, c in ipairs(HL:GetChildren()) do
		if c.Name == m.Name then c:Destroy() end
	end
	m:Clone().Parent = HL
	task.wait()
	table.insert(log, m.Name)
end
-- 2) models the user deleted
for _, name in ipairs(string.split(snap:GetAttribute("RemoveModels") or "", ",")) do
	local m = name ~= "" and HL:FindFirstChild(name)
	if m then m:Destroy() table.insert(log, "-" .. name) end
end
-- 3) single parts the user removed or changed (their script versions)
local want: { [string]: number } = {}
for _, s in ipairs(string.split(snap.RemoveSigs.Value, "\n")) do
	if s ~= "" then want[s] = (want[s] or 0) + 1 end
end
local removed = 0
local function sweep(parent: Instance)
	for _, p in ipairs(parent:GetChildren()) do
		if p:IsA("BasePart") then
			local s = sig(p)
			if (want[s] or 0) > 0 then
				want[s] -= 1
				p:Destroy()
				removed += 1
			end
		end
	end
end
sweep(HL)
if HL:FindFirstChild("ParkRaise") then sweep(HL.ParkRaise) end
-- 4) the user's versions of those parts (skipped when one is already there)
local added = 0
for _, p in ipairs(snap.AddParts:GetChildren()) do
	local parentName = p:GetAttribute("SnapshotParent")
	local parent = if parentName then HL:FindFirstChild(parentName) else HL
	if parent then
		local s = sig(p)
		local have = false
		for _, q in ipairs(parent:GetChildren()) do
			if q:IsA("BasePart") and q.Name == p.Name and sig(q) == s then have = true break end
		end
		if not have then
			local c = p:Clone()
			c:SetAttribute("SnapshotParent", nil)
			c.Parent = parent
			added += 1
		end
	end
end
local msg = string.format("[user_map_snapshot_1113] models %s | parts -%d +%d", table.concat(log, " "), removed, added)
print(msg)
return msg
