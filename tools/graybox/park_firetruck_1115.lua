--!nocheck
-- 소방차 교체 (D-1454, user 2026-11-15: "FireTruck 3d 에셋 보냄 교체", D:\Roblox\오후\3D 물\23_FireTruck.glb,
-- imported by the user into Workspace.Scene as "23_FireTruck": three MeshParts, one texture).
--   * the import is kept place-only as ServerStorage.ArtAssets.FireTruck (moved there the first
--     time, anchored, no collisions on the details)
--   * in the park's blockout (Hongdae_Layout.ParkBlockout["23_FireTruck"]) the grey Truck block and
--     its Ladder go; a copy of the user's truck, scaled evenly to the block's length (8.9) and
--     standing on the block's bottom, faces the same way (its long side along the block's).
--     The Track and the Lawn stay.
-- Chain step after park_layout_1111 (which builds the blockout). Idempotent.

local SS = game:GetService("ServerStorage")
local art = SS:WaitForChild("ArtAssets")

local tmpl = art:FindFirstChild("FireTruck")
if not tmpl then
	for _, d in ipairs(workspace:GetChildren()) do
		local m = d:FindFirstChild("23_FireTruck")
		if d.Name == "Scene" and m and m:IsA("Model") then
			m.Name = "FireTruck"
			m.Parent = art
			tmpl = m
			if #d:GetChildren() == 0 then d:Destroy() end
			break
		end
	end
end
assert(tmpl, "no ArtAssets.FireTruck and no Workspace.Scene.23_FireTruck")
for _, p in ipairs(tmpl:GetDescendants()) do
	if p:IsA("BasePart") then p.Anchored = true end
end

local site = workspace:WaitForChild("Hongdae_Layout"):WaitForChild("ParkBlockout"):WaitForChild("23_FireTruck")
local truck = site:FindFirstChild("Truck") :: BasePart?
local old = site:FindFirstChild("FireTruckMesh")
local at: CFrame, length: number
if truck then
	at = truck.CFrame * CFrame.new(0, -truck.Size.Y / 2, 0) -- (the block's bottom middle)
	length = math.max(truck.Size.X, truck.Size.Z)
	if truck.Size.X > truck.Size.Z then at = at * CFrame.Angles(0, math.pi / 2, 0) end
	site:SetAttribute("TruckAt", at) -- (for a rerun, once the block is gone)
	site:SetAttribute("TruckLength", length)
	truck:Destroy()
	local ladder = site:FindFirstChild("Ladder")
	if ladder then ladder:Destroy() end
else
	at = site:GetAttribute("TruckAt")
	length = site:GetAttribute("TruckLength") or 8.9
	assert(typeof(at) == "CFrame", "no Truck block and no TruckAt")
end
if old then old:Destroy() end

local m = tmpl:Clone()
m.Name = "FireTruckMesh"
local _, size = m:GetBoundingBox()
m:ScaleTo(m:GetScale() * (length / math.max(size.X, size.Z)))
local cf, size2 = m:GetBoundingBox()
-- turn so its long side runs along the block's local Z, then stand it on the block's bottom
local turn = if size2.X > size2.Z then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
local pivot = m:GetPivot()
local rel = cf:ToObjectSpace(pivot) -- (pivot from the box's middle)
local newBox = at * turn * CFrame.new(0, size2.Y / 2, 0)
m:PivotTo(newBox * rel)
for _, p in ipairs(m:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanTouch = false
	end
end
m.Parent = site
print(("[park_firetruck_1115] truck %.1f long at %s"):format(length, tostring(at.Position)))
return true
