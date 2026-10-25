-- Run in Edit mode right after rebuilding ONLY zone 04_Beach_Aquarium
-- (without build_hongdae_layout). The zone build brings back the blocky graybox
-- palms and the old Dream Aquarium parts; build_hongdae_layout normally parks
-- them in ServerStorage.Hongdae_v1_HiddenParts (the realistic palms stay in
-- Hongdae_Layout). This parks them the same way and drops the stale copies the
-- earlier apply left there, so a later revert does not restore them twice.
local SS = game:GetService("ServerStorage")
local hidden = SS:FindFirstChild("Hongdae_v1_HiddenParts")
local zone = workspace.Graybox_MainSocial:FindFirstChild("04_Beach_Aquarium")
if not (hidden and zone) then return "nothing to do" end
local HOME = "04_Beach_Aquarium"
local undo = CFrame.new(0, 2.4, 0) -- inverse of the zone move (BEACH_DROP)
for _, p in ipairs(hidden:GetChildren()) do
	if p:GetAttribute("HomeZone") == HOME then p:Destroy() end
end
local moved = 0
for _, c in ipairs(zone:GetChildren()) do
	local hide = c:IsA("Model") and c.Name == "PalmTree"
	if c:IsA("BasePart") then
		local p = c.Position
		local nearDome = math.abs(p.X + 368) < 50 and math.abs(p.Z + 150) < 50
		hide = c.Name == "DreamAquarium_Dome" or c.Name == "DomeFloor" or c.Name == "DomePier"
			or (nearDome and (c.Name == "PhotoSpot" or c.Name == "Label"))
	end
	if hide then
		if c:IsA("Model") then c:PivotTo(undo * c:GetPivot()) else c.CFrame = undo * c.CFrame end
		c:SetAttribute("HomeZone", HOME)
		c.Parent = hidden
		moved += 1
	end
end
return "parked " .. moved
